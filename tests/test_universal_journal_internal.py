"""APEX Platform -- app/core/universal_journal.py internal-coverage tests.

Coverage target: ≥80% of 106 statements (G-T1.7b.1, Sprint 9).

universal_journal.py is at ~75.5% from G-T1.7a's `test_ai_routes_extras.py`
indirect coverage; this module covers the internal branches that the
HTTP-route tests cannot reach without DB seed data:

  * `UJRow.to_dict()` — direct dataclass round-trip.
  * Import-failure short-circuits in both public functions.
  * Filter-branch coverage on `query_universal_journal` (no DB rows
    needed — the filters compile into the query before `.all()` runs).
  * `document_flow`'s `source_type == "sales_invoice"` enrichment branch.
"""

from __future__ import annotations

import sys
from datetime import date

import pytest

from app.core import universal_journal as uj


# ══════════════════════════════════════════════════════════════
# UJRow dataclass
# ══════════════════════════════════════════════════════════════


class TestUJRowToDict:
    def test_to_dict_round_trip(self):
        row = uj.UJRow(
            journal_entry_id="je-1",
            je_number="JE-001",
            je_date="2026-05-01",
            posting_date="2026-05-01",
            status="posted",
            source_type="manual",
            source_id="src-1",
            source_reference="ref",
            account_id="acc-1",
            account_code="1000",
            account_name="Cash",
            category="asset",
            debit_amount=100.0,
            credit_amount=0.0,
            currency="SAR",
            ledger_id="L1",
            dimensions={"cost_center": "CC1"},
            partner_type="customer",
            partner_id="cust-1",
            partner_name="Acme",
            description="opening balance",
            entity_id="ent-1",
            tenant_id="t-1",
        )
        d = row.to_dict()
        # All 23 fields must round-trip exactly.
        assert d["journal_entry_id"] == "je-1"
        assert d["je_number"] == "JE-001"
        assert d["debit_amount"] == 100.0
        assert d["credit_amount"] == 0.0
        assert d["dimensions"] == {"cost_center": "CC1"}
        assert d["partner_name"] == "Acme"
        assert d["entity_id"] == "ent-1"
        assert d["tenant_id"] == "t-1"
        # 23 documented fields per the dataclass header.
        assert len(d) == 23


# ══════════════════════════════════════════════════════════════
# query_universal_journal — import-failure short-circuit + filter branches
# ══════════════════════════════════════════════════════════════


class TestQueryImportFailure:
    def test_returns_empty_when_pilot_layer_unavailable(self, monkeypatch):
        """If `app.pilot.models` cannot be imported, the function logs
        and returns [] without touching the DB."""
        import builtins

        real_import = builtins.__import__

        def boom(name, *args, **kwargs):
            if name == "app.pilot.models":
                raise ImportError("pilot models gone")
            return real_import(name, *args, **kwargs)

        monkeypatch.setattr(builtins, "__import__", boom)
        out = uj.query_universal_journal(tenant_id="t-1")
        assert out == []


class TestQueryFilterBranches:
    """Exercises each `if filter:` branch with an empty DB.

    The query filters compile into the SQL before `.all()` runs, so
    every conditional fires even when the result set is empty. We are
    NOT asserting on the rows here — only that the branches execute
    without raising.
    """

    def test_all_filters_supplied_empty_result(self):
        # Passing every filter — covers lines 119-141 in one shot.
        out = uj.query_universal_journal(
            tenant_id="t-nonexistent-zzz",
            entity_id="e-nonexistent-zzz",
            start_date=date(2020, 1, 1),
            end_date=date(2030, 12, 31),
            account_codes=["1000", "2000"],
            account_categories=["asset", "liability"],
            source_types=["manual", "sales_invoice"],
            status="posted",
            ledger_id="L1",
            partner_id="p-zzz",
            dimension_filters={"cost_center": "CC1"},
            limit=10,
            offset=0,
        )
        assert isinstance(out, list)
        # Empty fixture DB → no rows.
        assert out == []


# ══════════════════════════════════════════════════════════════
# document_flow — import failure + sales_invoice branch + missing inv
# ══════════════════════════════════════════════════════════════


class TestDocumentFlow:
    def test_returns_empty_flow_when_pilot_unavailable(self, monkeypatch):
        """Same import-fallback contract as the query helper — no DB."""
        import builtins

        real_import = builtins.__import__

        def boom(name, *args, **kwargs):
            if name == "app.pilot.models":
                raise ImportError("pilot models gone")
            return real_import(name, *args, **kwargs)

        monkeypatch.setattr(builtins, "__import__", boom)
        out = uj.document_flow("sales_invoice", "inv-zzz")
        assert out == {
            "source_type": "sales_invoice",
            "source_id": "inv-zzz",
            "flow": [],
        }

    def test_sales_invoice_branch_with_no_match(self):
        """source_type == 'sales_invoice' enters the enrichment block.
        With no DB row the inner `inv` is None and `source_row` stays None."""
        out = uj.document_flow("sales_invoice", "inv-zzz-no-match")
        assert out["source_type"] == "sales_invoice"
        assert out["source_id"] == "inv-zzz-no-match"
        # No matching invoice → self stays None.
        assert out.get("self") is None
        # No JEs cite that source_id either.
        assert out["flow"] == []

    def test_other_source_type_skips_enrichment_block(self):
        """source_type != 'sales_invoice' returns flow without `self` lookup."""
        out = uj.document_flow("manual", "src-zzz")
        assert out["source_type"] == "manual"
        assert out["source_id"] == "src-zzz"
        assert out["flow"] == []
