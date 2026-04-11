"""
APEX Sprint 4 — TB File Reader Service
═══════════════════════════════════════════════════════════════
Reads TB files using existing TrialBalanceReader, normalizes rows,
and saves to tb_parsed_rows table.

Reuses: app.services.ingestion.trial_balance_reader.TrialBalanceReader
"""

import os, re, json
from typing import Dict, List, Any, Optional


def _norm_name(text: str) -> str:
    """Normalize account name for matching."""
    if not text:
        return ""
    t = text.strip().lower()
    t = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670]", "", t)
    t = t.replace("\u0623", "\u0627").replace("\u0625", "\u0627").replace("\u0622", "\u0627")
    t = t.replace("\u0649", "\u064a").replace("\u0629", "\u0647")
    return re.sub(r"\s+", " ", t)


def read_and_save_tb(
    file_content: bytes,
    filename: str,
    tb_upload_id: str,
    stored_path: str,
) -> Dict:
    """
    Read TB file, parse rows, save to tb_parsed_rows.
    Returns parse summary.
    """
    from app.services.ingestion.trial_balance_reader import TrialBalanceReader
    from app.phase1.models.platform_models import SessionLocal, gen_uuid
    from sqlalchemy import text as _t

    reader = TrialBalanceReader()
    result = reader.read(stored_path)

    rows = result.get("rows", [])
    meta = result.get("meta", {})
    file_format = result.get("format", "unknown")
    warnings = result.get("warnings", [])

    db = SessionLocal()
    try:
        # Save parsed rows
        parsed_count = 0
        skipped_count = 0

        for i, row in enumerate(rows):
            name = row.get("name", "").strip()
            if not name:
                skipped_count += 1
                continue

            row_id = gen_uuid()
            db.execute(
                _t("""INSERT INTO tb_parsed_rows
                   (id, tb_upload_id, source_row_number,
                    account_code, account_name_raw, account_name_normalized,
                    tab_raw, sub_tab,
                    open_debit, open_credit, movement_debit, movement_credit,
                    close_debit, close_credit, net_balance,
                    is_summary_row, issues_json, created_at)
                   VALUES (:id, :uid, :rn, :code, :name, :norm,
                           :tab, :sub, :od, :oc, :md, :mc, :cd, :cc, :nb,
                           :summary, :issues, CURRENT_TIMESTAMP)"""),
                {
                    "id": row_id,
                    "uid": tb_upload_id,
                    "rn": i + 1,
                    "code": row.get("code", ""),
                    "name": name,
                    "norm": _norm_name(name),
                    "tab": row.get("tab", ""),
                    "sub": row.get("sub_tab", ""),
                    "od": row.get("open_debit", 0.0),
                    "oc": row.get("open_credit", 0.0),
                    "md": row.get("movement_debit", 0.0),
                    "mc": row.get("movement_credit", 0.0),
                    "cd": row.get("close_debit", 0.0),
                    "cc": row.get("close_credit", 0.0),
                    "nb": row.get("net_balance", 0.0),
                    "summary": False,
                    "issues": json.dumps([]),
                },
            )
            parsed_count += 1

        # Update upload record
        db.execute(
            _t("""UPDATE trial_balance_uploads SET
                upload_status = :status,
                file_format = :fmt,
                total_rows_detected = :detected,
                total_rows_parsed = :parsed,
                total_rows_skipped = :skipped,
                company_name_detected = :company
            WHERE id = :uid"""),
            {
                "status": "parsed_with_warnings" if warnings else "parsed",
                "fmt": file_format,
                "detected": len(rows) + skipped_count,
                "parsed": parsed_count,
                "skipped": skipped_count,
                "company": meta.get("company_name", ""),
                "uid": tb_upload_id,
            },
        )

        db.commit()

        return {
            "tb_upload_id": tb_upload_id,
            "file_format": file_format,
            "total_rows_detected": len(rows) + skipped_count,
            "total_rows_parsed": parsed_count,
            "total_rows_skipped": skipped_count,
            "company_name": meta.get("company_name", ""),
            "period": meta.get("period", ""),
            "warnings": warnings,
        }
    except Exception as e:
        db.rollback()
        # Mark as failed
        try:
            db.execute(
                _t("UPDATE trial_balance_uploads SET upload_status = 'failed' WHERE id = :uid"), {"uid": tb_upload_id}
            )
            db.commit()
        except Exception:
            pass
        raise e
    finally:
        db.close()
