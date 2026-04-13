"""
APEX Sprint 3 — COA Quality + Review + Approval Routes
═══════════════════════════════════════════════════════════════
APIs:
  POST /coa/uploads/{upload_id}/assess     — Run quality assessment
  GET  /coa/uploads/{upload_id}/assessment — Get assessment results
  POST /coa/uploads/{upload_id}/approve    — Approve entire COA
  POST /coa/uploads/{upload_id}/reject     — Return for review
  GET  /coa/uploads/{upload_id}/approval-history
  POST /coa/accounts/{account_id}/create-rule — Create client rule from edit
  GET  /clients/{client_id}/coa-rules      — List client rules
  POST /clients/{client_id}/coa-rules      — Create client rule directly
  DELETE /coa/rules/{rule_id}              — Deactivate rule
"""

import json
import logging
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timezone
from sqlalchemy import text as _t
from app.core.db_utils import get_db_session

# ── Request Models ──────────────────────────────────────────


class ApproveCoaBody(BaseModel):
    approved_by: Optional[str] = None
    notes: Optional[str] = None
    min_confidence: float = Field(default=0.5)


class RejectCoaBody(BaseModel):
    rejected_by: Optional[str] = None
    notes: Optional[str] = None


class CreateRuleFromAccountBody(BaseModel):
    rule_name: Optional[str] = None
    rule_type: Optional[str] = None
    condition: Optional[dict] = None
    action: Optional[dict] = None
    created_by: Optional[str] = None


class CreateClientRuleBody(BaseModel):
    rule_name: str
    condition: dict
    action: dict
    rule_type: str = Field(default="alias")
    created_by: Optional[str] = None


router = APIRouter(tags=["Sprint 3 — COA Quality & Review"])


# ═══════════════════════════════════════════════════════════
# POST /coa/uploads/{upload_id}/assess
# ═══════════════════════════════════════════════════════════


@router.post("/coa/uploads/{upload_id}/assess")
def assess_coa_quality(upload_id: str, activity: str = Query("general")):
    """Run full quality assessment on a classified COA upload."""
    from app.sprint3.services.coa_quality_engine import run_full_assessment
    from app.phase1.models.platform_models import gen_uuid

    db = get_db_session()
    try:
        # Verify upload exists and is classified
        upload_row = db.execute(
            _t("SELECT id, client_id, upload_status, detected_columns_json, column_mapping_json FROM client_coa_uploads WHERE id = :uid"), {"uid": upload_id}
        ).fetchone()

        if not upload_row:
            raise HTTPException(404, "Upload not found")

        client_id = upload_row[1]

        # Detect file_pattern and erp_system from columns
        _det_cols = upload_row[3] or "[]"
        if isinstance(_det_cols, str):
            try:
                _det_cols = json.loads(_det_cols)
            except Exception:
                _det_cols = []
        _det_lower = {str(c).lower().strip() for c in _det_cols} if _det_cols else set()
        _erp_system = None
        _file_pattern = "GENERIC_FLAT"
        odoo_kw = {"user_type_id", "reconcile", "account_type", "النوع", "نوع", "نوع الحساب"}
        if any(k in _det_lower for k in odoo_kw):
            _file_pattern = "ODOO_FLAT"
            _erp_system = "Odoo"
        elif any("__export__" in str(c) for c in (_det_cols or [])):
            _file_pattern = "ODOO_WITH_ID"
            _erp_system = "Odoo"
        elif any("zoho" in str(c).lower() for c in (_det_cols or [])):
            _file_pattern = "ZOHO_BOOKS"
            _erp_system = "Zoho Books"
        elif any("class" in str(c).lower() for c in (_det_cols or [])):
            _file_pattern = "ENGLISH_WITH_CLASS"

        # Get classified accounts
        rows = db.execute(
            _t("""SELECT id, account_code, account_name_raw, account_name_normalized,
                      parent_code, parent_name, account_level, account_type_raw,
                      normal_balance, normalized_class, statement_section, subcategory,
                      current_noncurrent, cashflow_role, sign_rule,
                      mapping_confidence, mapping_source, record_status,
                      issues_json, classification_issues_json
               FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND record_status != 'rejected'
               ORDER BY source_row_number"""),
            {"uid": upload_id},
        ).fetchall()

        if not rows:
            raise HTTPException(400, "No accounts found. Parse and classify first.")

        accounts = []
        for r in rows:
            accounts.append(
                {
                    "id": r[0],
                    "account_code": r[1],
                    "account_name_raw": r[2],
                    "account_name_normalized": r[3],
                    "parent_code": r[4],
                    "parent_name": r[5],
                    "account_level": r[6],
                    "account_type_raw": r[7],
                    "normal_balance": r[8],
                    "normalized_class": r[9],
                    "statement_section": r[10],
                    "subcategory": r[11],
                    "current_noncurrent": r[12],
                    "cashflow_role": r[13],
                    "sign_rule": r[14],
                    "mapping_confidence": r[15] or 0,
                    "mapping_source": r[16],
                    "record_status": r[17],
                }
            )

        # Run assessment
        result = run_full_assessment(accounts, activity)

        # Count confidence tiers
        high_conf = sum(1 for a in accounts if (a.get("mapping_confidence") or 0) >= 0.75)
        low_conf = sum(1 for a in accounts if 0.40 <= (a.get("mapping_confidence") or 0) < 0.75)
        unclassified = sum(1 for a in accounts if (a.get("mapping_confidence") or 0) < 0.40)

        # Upsert assessment record
        now = datetime.now(timezone.utc).isoformat()
        existing = db.execute(
            _t("SELECT id FROM client_coa_assessments WHERE coa_upload_id = :uid"), {"uid": upload_id}
        ).fetchone()

        if existing:
            db.execute(
                _t("""UPDATE client_coa_assessments SET
                    overall_score = :os, completeness_score = :cs, consistency_score = :cons,
                    naming_clarity_score = :ns, duplication_risk_score = :ds,
                    reporting_readiness_score = :rs,
                    total_accounts = :ta, classified_accounts = :ca,
                    high_confidence_count = :hc, low_confidence_count = :lc,
                    unclassified_count = :uc,
                    issues_json = :ij, recommendations_json = :rj,
                    missing_categories_json = :mcj, ambiguous_accounts_json = :aaj,
                    duplicate_suspects_json = :dsj
                WHERE coa_upload_id = :uid"""),
                {
                    "os": result["overall_score"],
                    "cs": result["completeness_score"],
                    "cons": result["consistency_score"],
                    "ns": result["naming_clarity_score"],
                    "ds": result["duplication_risk_score"],
                    "rs": result["reporting_readiness_score"],
                    "ta": len(accounts),
                    "ca": high_conf + low_conf,
                    "hc": high_conf,
                    "lc": low_conf,
                    "uc": unclassified,
                    "ij": json.dumps(result["issues"]),
                    "rj": json.dumps(result["recommendations"]),
                    "mcj": json.dumps(result["completeness"]["missing_categories"]),
                    "aaj": json.dumps(result["naming_clarity"]["ambiguous_accounts"][:20]),
                    "dsj": json.dumps(result["duplication_risk"]["duplicate_suspects"][:20]),
                    "uid": upload_id,
                },
            )
        else:
            db.execute(
                _t("""INSERT INTO client_coa_assessments
                   (id, client_id, coa_upload_id,
                    overall_score, completeness_score, consistency_score,
                    naming_clarity_score, duplication_risk_score, reporting_readiness_score,
                    total_accounts, classified_accounts,
                    high_confidence_count, low_confidence_count, unclassified_count,
                    issues_json, recommendations_json, missing_categories_json,
                    ambiguous_accounts_json, duplicate_suspects_json, created_at)
                   VALUES (:id, :cid, :uid, :os, :cs, :cons, :ns, :ds, :rs,
                           :ta, :ca, :hc, :lc, :uc, :ij, :rj, :mcj, :aaj, :dsj, :now)"""),
                {
                    "id": gen_uuid(),
                    "cid": client_id,
                    "uid": upload_id,
                    "os": result["overall_score"],
                    "cs": result["completeness_score"],
                    "cons": result["consistency_score"],
                    "ns": result["naming_clarity_score"],
                    "ds": result["duplication_risk_score"],
                    "rs": result["reporting_readiness_score"],
                    "ta": len(accounts),
                    "ca": high_conf + low_conf,
                    "hc": high_conf,
                    "lc": low_conf,
                    "uc": unclassified,
                    "ij": json.dumps(result["issues"]),
                    "rj": json.dumps(result["recommendations"]),
                    "mcj": json.dumps(result["completeness"]["missing_categories"]),
                    "aaj": json.dumps(result["naming_clarity"]["ambiguous_accounts"][:20]),
                    "dsj": json.dumps(result["duplication_risk"]["duplicate_suspects"][:20]),
                    "now": now,
                },
            )

        db.commit()

        return {
            "success": True,
            "data": {
                "upload_id": upload_id,
                "overall_score": result["overall_score"],
                "completeness_score": result["completeness_score"],
                "consistency_score": result["consistency_score"],
                "naming_clarity_score": result["naming_clarity_score"],
                "duplication_risk_score": result["duplication_risk_score"],
                "reporting_readiness_score": result["reporting_readiness_score"],
                "total_accounts": len(accounts),
                "high_confidence": high_conf,
                "low_confidence": low_conf,
                "unclassified": unclassified,
                "missing_categories": result["completeness"]["missing_categories"],
                "recommendations": result["recommendations"],
                "reporting_readiness": result["reporting_readiness"]["readiness"],
                "issues_count": len(result["issues"]),
                "file_pattern": _file_pattern,
                "erp_system": _erp_system,
                "naming_clarity": result.get("naming_clarity", {}),
                "duplication_risk": result.get("duplication_risk", {}),
            },
        }
    except HTTPException:
        raise
    except Exception:
        logging.error("COA assessment error", exc_info=True)
        raise HTTPException(500, "COA quality assessment failed")
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════
# GET /coa/uploads/{upload_id}/assessment
# ═══════════════════════════════════════════════════════════


@router.get("/coa/uploads/{upload_id}/assessment")
def get_assessment(upload_id: str):
    """Get stored quality assessment for a COA upload."""
    db = get_db_session()
    try:
        row = db.execute(
            _t("""SELECT overall_score, completeness_score, consistency_score,
                      naming_clarity_score, duplication_risk_score, reporting_readiness_score,
                      total_accounts, classified_accounts,
                      high_confidence_count, low_confidence_count, unclassified_count,
                      issues_json, recommendations_json, missing_categories_json,
                      ambiguous_accounts_json, duplicate_suspects_json, created_at
               FROM client_coa_assessments WHERE coa_upload_id = :uid"""),
            {"uid": upload_id},
        ).fetchone()

        if not row:
            raise HTTPException(404, "Assessment not found. Run POST /coa/uploads/{upload_id}/assess first.")

        def _parse(val):
            if isinstance(val, str):
                return json.loads(val)
            return val or []

        return {
            "success": True,
            "data": {
                "upload_id": upload_id,
                "overall_score": row[0],
                "completeness_score": row[1],
                "consistency_score": row[2],
                "naming_clarity_score": row[3],
                "duplication_risk_score": row[4],
                "reporting_readiness_score": row[5],
                "total_accounts": row[6],
                "classified_accounts": row[7],
                "high_confidence_count": row[8],
                "low_confidence_count": row[9],
                "unclassified_count": row[10],
                "issues": _parse(row[11]),
                "recommendations": _parse(row[12]),
                "missing_categories": _parse(row[13]),
                "ambiguous_accounts": _parse(row[14]),
                "duplicate_suspects": _parse(row[15]),
                "assessed_at": str(row[16]) if row[16] else None,
            },
        }
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════
# POST /coa/uploads/{upload_id}/approve-coa
# ═══════════════════════════════════════════════════════════


@router.get("/coa/uploads/{upload_id}/approval-check", tags=["Phase1-Gates"])
def check_coa_approval_readiness(upload_id: str):
    """Check all approval gates before allowing final COA approve."""
    from app.sprint3.services.coa_approval_gate import check_approval_gates

    db = get_db_session()
    try:
        scores_row = db.execute(
            _t(
                "SELECT overall_score, completeness_score, reporting_readiness_score "
                "FROM client_coa_assessments WHERE coa_upload_id = :uid"
            ),
            {"uid": upload_id},
        ).fetchone()

        if not scores_row:
            return {
                "success": True,
                "data": {"can_approve": False, "blockers": ["Run quality assessment first"], "quality_overall": 0},
            }

        quality_scores = {
            "overall": scores_row[0] or 0,
            "completeness": scores_row[1] or 0,
            "reporting": scores_row[2] or 0,
        }

        rows = db.execute(
            _t("SELECT record_status, normalized_class FROM client_chart_of_accounts WHERE coa_upload_id = :uid"),
            {"uid": upload_id},
        ).fetchall()
        accounts = [{"status": r[0], "normalized_class": r[1]} for r in rows]

        result = check_approval_gates(accounts, quality_scores)
        return {"success": True, "data": result}
    finally:
        db.close()


@router.post("/coa/uploads/{upload_id}/approve-coa")
def approve_coa(upload_id: str, body: ApproveCoaBody = ApproveCoaBody()):
    """Approve the entire COA upload as the client's approved chart."""
    from app.sprint3.services.coa_review_service import approve_upload

    db = get_db_session()
    try:
        upload_row = db.execute(
            _t("SELECT client_id FROM client_coa_uploads WHERE id = :uid"), {"uid": upload_id}
        ).fetchone()
        if not upload_row:
            raise HTTPException(404, "Upload not found")
    finally:
        db.close()

    result = approve_upload(
        upload_id=upload_id,
        client_id=upload_row[0],
        approved_by=body.approved_by,
        notes=body.notes,
        min_confidence=body.min_confidence,
    )

    if not result.get("success"):
        raise HTTPException(400, result.get("error", "Approval failed"))
    return result


# ═══════════════════════════════════════════════════════════
# POST /coa/uploads/{upload_id}/reject-coa
# ═══════════════════════════════════════════════════════════


@router.post("/coa/uploads/{upload_id}/reject-coa")
def reject_coa(upload_id: str, body: RejectCoaBody = RejectCoaBody()):
    """Return COA upload for review/revision."""
    from app.sprint3.services.coa_review_service import reject_upload

    db = get_db_session()
    try:
        upload_row = db.execute(
            _t("SELECT client_id FROM client_coa_uploads WHERE id = :uid"), {"uid": upload_id}
        ).fetchone()
        if not upload_row:
            raise HTTPException(404, "Upload not found")
    finally:
        db.close()

    result = reject_upload(
        upload_id=upload_id,
        client_id=upload_row[0],
        rejected_by=body.rejected_by,
        notes=body.notes,
    )
    if not result.get("success"):
        raise HTTPException(400, result.get("error"))
    return result


# ═══════════════════════════════════════════════════════════
# GET /coa/uploads/{upload_id}/approval-history
# ═══════════════════════════════════════════════════════════


@router.get("/coa/uploads/{upload_id}/approval-history")
def approval_history(upload_id: str):
    """Get approval/rejection history for a COA upload."""
    from app.sprint3.services.coa_review_service import get_approval_history

    return get_approval_history(upload_id)


# ═══════════════════════════════════════════════════════════
# Client Rules
# ═══════════════════════════════════════════════════════════


@router.post("/coa/accounts/{account_id}/create-rule")
def create_rule_from_account(account_id: str, body: CreateRuleFromAccountBody = CreateRuleFromAccountBody()):
    """Create a client-specific rule from a manually edited account."""
    from app.sprint3.services.coa_review_service import create_client_rule

    db = get_db_session()
    try:
        row = db.execute(
            _t("""SELECT client_id, coa_upload_id, account_name_raw, normalized_class,
                      statement_section, subcategory
               FROM client_chart_of_accounts WHERE id = :aid"""),
            {"aid": account_id},
        ).fetchone()
        if not row:
            raise HTTPException(404, "Account not found")

        client_id = row[0]
        rule_name = body.rule_name if body.rule_name is not None else f"قاعدة مخصصة: {(row[2] or '')[:40]}"
        rule_type = body.rule_type if body.rule_type is not None else "classification_override"

        condition = (
            body.condition
            if body.condition is not None
            else {
                "field": "account_name_raw",
                "contains": row[2],
            }
        )
        action = (
            body.action
            if body.action is not None
            else {
                "set_class": row[3],
                "set_section": row[4],
                "set_subcategory": row[5],
            }
        )
    finally:
        db.close()

    result = create_client_rule(
        client_id=client_id,
        rule_name=rule_name,
        rule_type=rule_type,
        condition_json=condition,
        action_json=action,
        created_by=body.created_by,
        source_upload_id=row[1],
        source_account_id=account_id,
    )

    if not result.get("success"):
        raise HTTPException(400, result.get("error"))
    return result


@router.get("/clients/{client_id}/coa-rules")
def get_client_rules(client_id: str, active_only: bool = Query(True)):
    """List classification rules for a client."""
    from app.sprint3.services.coa_review_service import list_client_rules

    return list_client_rules(client_id, active_only)


@router.post("/clients/{client_id}/coa-rules")
def create_client_rule_direct(client_id: str, body: CreateClientRuleBody):
    """Create a client-specific classification rule directly."""
    from app.sprint3.services.coa_review_service import create_client_rule

    result = create_client_rule(
        client_id=client_id,
        rule_name=body.rule_name,
        rule_type=body.rule_type,
        condition_json=body.condition,
        action_json=body.action,
        created_by=body.created_by,
    )

    if not result.get("success"):
        raise HTTPException(400, result.get("error"))
    return result


@router.delete("/coa/rules/{rule_id}")
def deactivate_rule(rule_id: str):
    """Deactivate a client-specific rule (soft delete)."""
    db = get_db_session()
    try:
        row = db.execute(_t("SELECT id FROM client_coa_rules WHERE id = :rid"), {"rid": rule_id}).fetchone()
        if not row:
            raise HTTPException(404, "Rule not found")

        db.execute(_t("UPDATE client_coa_rules SET is_active = false WHERE id = :rid"), {"rid": rule_id})
        db.commit()
        return {"success": True, "data": {"id": rule_id, "status": "deactivated"}}
    finally:
        db.close()
