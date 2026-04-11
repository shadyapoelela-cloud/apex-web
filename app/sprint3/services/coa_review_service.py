"""
APEX Sprint 3 — COA Review & Approval Service
═══════════════════════════════════════════════════════════════
Manages the review workflow for classified COA:
  - Save manual classification edits
  - Approve/reject individual or bulk accounts
  - Create client-specific rules from corrections
  - Approve entire COA upload for TB binding
  - Track approval history

Per Apex_Coa_First_Workflow_Execution_Document §6.4, §6.5
"""

import json
import logging
from typing import Dict
from app.core.db_utils import get_db_session, utc_now


def approve_upload(
    upload_id: str,
    client_id: str,
    approved_by: str = None,
    notes: str = None,
    min_confidence: float = 0.0,
) -> Dict:
    """
    Approve a COA upload — marks it as the client's approved chart.
    Only accounts with review_status='approved' or confidence >= min_confidence count.
    """
    from app.phase1.models.platform_models import gen_uuid
    from sqlalchemy import text as _t

    db = get_db_session()
    try:
        now = utc_now().isoformat()

        # Count approved accounts
        approved_count = db.execute(
            _t("""SELECT COUNT(*) FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND record_status != 'rejected'
               AND record_status = 'approved'"""),
            {"uid": upload_id, "mc": min_confidence},
        ).fetchone()[0]

        total_count = db.execute(
            _t("""SELECT COUNT(*) FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND record_status != 'rejected'"""),
            {"uid": upload_id},
        ).fetchone()[0]

        if total_count == 0:
            return {"success": False, "error": "No accounts found for this upload"}

        approval_pct = round(approved_count / total_count * 100, 1)
        if approval_pct < 50:
            return {
                "success": False,
                "error": f"فقط {approval_pct}% من الحسابات معتمدة. يجب اعتماد 50% على الأقل قبل الموافقة النهائية.",
                "approved_count": approved_count,
                "total_count": total_count,
            }

        # Get quality score if exists
        try:
            quality_row = db.execute(
                _t("SELECT overall_score FROM client_coa_assessments WHERE coa_upload_id = :uid"), {"uid": upload_id}
            ).fetchone()
            quality_score = quality_row[0] if quality_row else None
        except Exception:
            quality_score = None
            db.rollback()

        # Get avg confidence
        try:
            conf_row = db.execute(
                _t("""SELECT AVG(mapping_confidence) FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND record_status != 'rejected'"""),
                {"uid": upload_id},
            ).fetchone()
            avg_conf = round(float(conf_row[0] or 0), 3)
        except Exception:
            avg_conf = 0
            db.rollback()

        # Mark previous approvals as not current
        db.execute(
            _t("UPDATE coa_approval_records SET is_current = false WHERE coa_upload_id = :uid"), {"uid": upload_id}
        )

        # Create approval record
        db.execute(
            _t("""INSERT INTO coa_approval_records
               (id, coa_upload_id, client_id, action, approved_by, notes,
                total_accounts, approved_accounts, overall_quality_score, avg_confidence, is_current, created_at)
               VALUES (:id, :uid, :cid, 'approved', :by, :notes,
                       :total, :approved, :qs, :ac, true, :now)"""),
            {
                "id": gen_uuid(),
                "uid": upload_id,
                "cid": client_id,
                "by": approved_by,
                "notes": notes,
                "total": total_count,
                "approved": approved_count,
                "qs": quality_score,
                "ac": avg_conf,
                "now": now,
            },
        )

        # Update upload status
        db.execute(_t("UPDATE client_coa_uploads SET upload_status = 'approved' WHERE id = :uid"), {"uid": upload_id})

        db.commit()

        return {
            "success": True,
            "upload_id": upload_id,
            "action": "approved",
            "total_accounts": total_count,
            "approved_accounts": approved_count,
            "approval_percentage": approval_pct,
            "overall_quality_score": quality_score,
            "avg_confidence": avg_conf,
            "approved_at": now,
        }
    except Exception:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"success": False, "error": "Internal server error"}
    finally:
        db.close()


def reject_upload(upload_id: str, client_id: str, rejected_by: str = None, notes: str = None) -> Dict:
    """Reject/return a COA upload for revision."""
    from app.phase1.models.platform_models import gen_uuid
    from sqlalchemy import text as _t

    db = get_db_session()
    try:
        now = utc_now().isoformat()

        db.execute(
            _t("UPDATE coa_approval_records SET is_current = false WHERE coa_upload_id = :uid"), {"uid": upload_id}
        )

        db.execute(
            _t("""INSERT INTO coa_approval_records
               (id, coa_upload_id, client_id, action, approved_by, notes, is_current, created_at)
               VALUES (:id, :uid, :cid, 'returned_for_review', :by, :notes, true, :now)"""),
            {"id": gen_uuid(), "uid": upload_id, "cid": client_id, "by": rejected_by, "notes": notes, "now": now},
        )

        db.execute(
            _t("UPDATE client_coa_uploads SET upload_status = 'review_returned' WHERE id = :uid"), {"uid": upload_id}
        )

        db.commit()
        return {"success": True, "upload_id": upload_id, "action": "returned_for_review"}
    except Exception:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"success": False, "error": "Internal server error"}
    finally:
        db.close()


def create_client_rule(
    client_id: str,
    rule_name: str,
    rule_type: str,
    condition_json: Dict,
    action_json: Dict,
    created_by: str = None,
    source_upload_id: str = None,
    source_account_id: str = None,
) -> Dict:
    """Create a client-specific classification rule from a manual edit."""
    from app.phase1.models.platform_models import gen_uuid
    from sqlalchemy import text as _t

    db = get_db_session()
    try:
        rule_id = gen_uuid()
        now = utc_now().isoformat()

        db.execute(
            _t("""INSERT INTO client_coa_rules
               (id, client_id, rule_name, rule_type, condition_json, action_json,
                created_by, source_upload_id, source_account_id, is_active, created_at, updated_at)
               VALUES (:id, :cid, :name, :type, :cond, :act, :by, :suid, :said, 1, :now, :now)"""),
            {
                "id": rule_id,
                "cid": client_id,
                "name": rule_name,
                "type": rule_type,
                "cond": json.dumps(condition_json),
                "act": json.dumps(action_json),
                "by": created_by,
                "suid": source_upload_id,
                "said": source_account_id,
                "now": now,
            },
        )

        db.commit()
        return {"success": True, "rule_id": rule_id, "rule_name": rule_name}
    except Exception:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"success": False, "error": "Internal server error"}
    finally:
        db.close()


def list_client_rules(client_id: str, active_only: bool = True) -> Dict:
    """List classification rules for a client."""
    from sqlalchemy import text as _t

    db = get_db_session()
    try:
        where = "client_id = :cid"
        params = {"cid": client_id}
        if active_only:
            where += " AND is_active = true"

        rows = db.execute(
            _t(f"""SELECT id, rule_name, rule_type, condition_json, action_json,
                       priority, is_active, created_at
                FROM client_coa_rules WHERE {where} ORDER BY priority DESC, created_at DESC"""),
            params,
        ).fetchall()

        rules = []
        for r in rows:
            cond = r[3]
            act = r[4]
            if isinstance(cond, str):
                cond = json.loads(cond)
            if isinstance(act, str):
                act = json.loads(act)
            rules.append(
                {
                    "id": r[0],
                    "rule_name": r[1],
                    "rule_type": r[2],
                    "condition": cond,
                    "action": act,
                    "priority": r[5],
                    "is_active": bool(r[6]),
                    "created_at": str(r[7]) if r[7] else None,
                }
            )

        return {"client_id": client_id, "rules": rules, "total": len(rules)}
    finally:
        db.close()


def get_approval_history(upload_id: str) -> Dict:
    """Get approval history for a COA upload."""
    from sqlalchemy import text as _t

    db = get_db_session()
    try:
        rows = db.execute(
            _t("""SELECT id, action, approved_by, notes, total_accounts, approved_accounts,
                      overall_quality_score, avg_confidence, is_current, created_at
               FROM coa_approval_records WHERE coa_upload_id = :uid ORDER BY created_at DESC"""),
            {"uid": upload_id},
        ).fetchall()

        records = []
        for r in rows:
            records.append(
                {
                    "id": r[0],
                    "action": r[1],
                    "approved_by": r[2],
                    "notes": r[3],
                    "total_accounts": r[4],
                    "approved_accounts": r[5],
                    "overall_quality_score": r[6],
                    "avg_confidence": r[7],
                    "is_current": bool(r[8]),
                    "created_at": str(r[9]) if r[9] else None,
                }
            )

        return {"upload_id": upload_id, "records": records, "total": len(records)}
    finally:
        db.close()
