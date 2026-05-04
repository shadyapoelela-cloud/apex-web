#!/usr/bin/env python3
"""G-S9 exposure check — READ-ONLY count queries against apex-db.

Sprint 14 / 2026-05-04. Companion to the G-S9 investigation that
confirmed the entire /pilot/* backend (164 endpoints, 11 router
files) has zero ``Depends(get_current_user)`` and is anonymously
reachable on https://apex-api-ootk.onrender.com.

This script estimates the *scale* of exposure by reading row counts
on every pilot_* table and the count of distinct tenants per table.
It does NOT read actual rows — only aggregate counts. It does NOT
write anything.

Operator workflow (matches G-A3.1 Phase 2b runbook):
    PowerShell:
        $env:DATABASE_URL = '<paste apex-db External URL — never commit>'
        py scripts/g-s9/exposure_check.py
        Remove-Item Env:DATABASE_URL    # when done
    bash:
        export DATABASE_URL='<paste apex-db External URL — never commit>'
        py scripts/g-s9/exposure_check.py
        unset DATABASE_URL

Output (paste-ready for the G-S9 PR):
    Table                                Row count  Distinct tenants
    -------------------------------------------------------------------
    pilot_journal_entries                       N                 K
    ...

Exit codes:
    0 = all tables queried (whether 0 or non-zero rows)
    1 = DATABASE_URL unset / connection failure / fatal error
    2 = unsafe URL detected (e.g., points at localhost or test.db)

Cross-references:
  - APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md § 20.1 G-S9 (full
    diagnosis, evidence chain, locked-in registry status)
  - scripts/g-a3-1/ — pattern this script mirrors (env-var URL,
    no commits, paste-ready output)
"""

from __future__ import annotations

import os
import sys
from urllib.parse import urlparse


# Full list of pilot_* tables, generated 2026-05-04 from
# `grep __tablename__ app/pilot/models/`. 54 entries.
PILOT_TABLES = [
    "pilot_attachments",
    "pilot_barcodes",
    "pilot_branches",
    "pilot_brands",
    "pilot_cash_movements",
    "pilot_company_settings",
    "pilot_currencies",
    "pilot_customer_payments",
    "pilot_customers",
    "pilot_entities",
    "pilot_fiscal_periods",
    "pilot_fx_rates",
    "pilot_gl_accounts",
    "pilot_gl_postings",
    "pilot_goods_receipt_lines",
    "pilot_goods_receipts",
    "pilot_gosi_contributions",
    "pilot_gosi_registrations",
    "pilot_journal_entries",
    "pilot_journal_lines",
    "pilot_permissions",
    "pilot_pos_payments",
    "pilot_pos_sessions",
    "pilot_pos_transaction_lines",
    "pilot_pos_transactions",
    "pilot_price_list_branches",
    "pilot_price_list_items",
    "pilot_price_lists",
    "pilot_product_attribute_values",
    "pilot_product_attributes",
    "pilot_product_categories",
    "pilot_product_variants",
    "pilot_products",
    "pilot_purchase_invoice_lines",
    "pilot_purchase_invoices",
    "pilot_purchase_order_lines",
    "pilot_purchase_orders",
    "pilot_role_permissions",
    "pilot_roles",
    "pilot_sales_invoice_lines",
    "pilot_sales_invoices",
    "pilot_stock_levels",
    "pilot_stock_movements",
    "pilot_tenants",
    "pilot_uae_ct_filings",
    "pilot_user_branch_access",
    "pilot_user_entity_access",
    "pilot_vat_returns",
    "pilot_vendor_payments",
    "pilot_vendors",
    "pilot_warehouses",
    "pilot_wps_batches",
    "pilot_wps_sif_records",
    "pilot_zatca_onboarding",
    "pilot_zatca_submissions",
]


def _validate_url(url: str) -> tuple[bool, str]:
    """Refuse to query localhost/sqlite/dev URLs — this is a prod-only tool."""
    if url.startswith("sqlite"):
        return False, "URL is sqlite — this script is for production apex-db only."
    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()
    if host in ("", "localhost", "127.0.0.1") or host.endswith(".local"):
        return False, f"URL host {host!r} looks local — refuse to run on dev DB."
    if "test" in host:
        return False, f"URL host {host!r} contains 'test' — refuse defensively."
    return True, ""


def _column_exists(cur, table: str, column: str) -> bool:
    cur.execute(
        """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = %s AND column_name = %s
        )
        """,
        (table, column),
    )
    return bool(cur.fetchone()[0])


def main() -> int:
    url = os.environ.get("DATABASE_URL")
    if not url:
        print("ERROR: DATABASE_URL not set in env.", file=sys.stderr)
        print("       Operator must paste the apex-db URL into env first:", file=sys.stderr)
        print("         PowerShell: $env:DATABASE_URL = '<paste URL>'", file=sys.stderr)
        print("         bash:       export DATABASE_URL='<paste URL>'", file=sys.stderr)
        return 1

    ok, reason = _validate_url(url)
    if not ok:
        print(f"REFUSED: {reason}", file=sys.stderr)
        return 2

    try:
        import psycopg2
    except ImportError:
        print(
            "ERROR: psycopg2 not installed. Run scripts/g-a3-1/install_prereqs.ps1",
            file=sys.stderr,
        )
        return 1

    parsed = urlparse(url)
    host = parsed.hostname or "<unknown>"
    print("G-S9 exposure check (READ-ONLY count queries)")
    print("=" * 75)
    print(f"  Target host: {host}")
    print(f"  Tables checked: {len(PILOT_TABLES)} pilot_* tables")
    print(f"  Operation: SELECT COUNT(*) only — no row reads, no writes")
    print()

    try:
        conn = psycopg2.connect(url, connect_timeout=15)
    except Exception as e:
        print(f"ERROR: could not connect: {e.__class__.__name__}: {e}", file=sys.stderr)
        return 1

    cur = conn.cursor()

    print(f"  {'Table':<36}{'Rows':>10}  {'Distinct tenants':>18}")
    print("  " + "-" * 70)

    total_rows = 0
    tables_with_rows = 0
    missing_tables = 0
    error_tables = 0

    for t in PILOT_TABLES:
        try:
            cur.execute(
                "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = %s)",
                (t,),
            )
            if not cur.fetchone()[0]:
                print(f"  {t:<36}{'(missing)':>10}")
                missing_tables += 1
                continue

            cur.execute(f'SELECT COUNT(*) FROM "{t}"')
            rows = cur.fetchone()[0]

            if _column_exists(cur, t, "tenant_id"):
                cur.execute(f'SELECT COUNT(DISTINCT tenant_id) FROM "{t}"')
                tenants_repr = str(cur.fetchone()[0])
            else:
                tenants_repr = "n/a"

            print(f"  {t:<36}{rows:>10}  {tenants_repr:>18}")
            total_rows += rows
            if rows > 0:
                tables_with_rows += 1

        except Exception as e:
            print(f"  {t:<36}{'ERR':>10}  {e.__class__.__name__}")
            error_tables += 1
            conn.rollback()

    print("  " + "-" * 70)
    print(f"  {'TOTAL ROWS':<36}{total_rows:>10}")
    print()
    print("Summary:")
    print(f"  Tables with rows:   {tables_with_rows} / {len(PILOT_TABLES)}")
    print(f"  Missing tables:     {missing_tables}")
    print(f"  Errored tables:     {error_tables}")
    print(f"  Total rows across pilot_*: {total_rows}")

    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
