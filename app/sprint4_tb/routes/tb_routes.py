"""
APEX Sprint 4 — Trial Balance Upload + Binding Routes
═══════════════════════════════════════════════════════════════
APIs:
  POST /clients/{client_id}/tb/upload              — Upload TB file
  GET  /tb/uploads/{tb_upload_id}                  — Get upload status
  POST /tb/uploads/{tb_upload_id}/bind             — Run binding engine
  GET  /tb/uploads/{tb_upload_id}/binding-results  — View binding results
  POST /tb/binding/{binding_id}/match              — Manually match a row
  POST /tb/uploads/{tb_upload_id}/approve-binding  — Approve binding
  GET  /tb/uploads/{tb_upload_id}/binding-summary  — Binding stats
"""

import os, logging, json
from fastapi import APIRouter, File, UploadFile, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional
from sqlalchemy import text as _t
from app.core.db_utils import get_db_session

# ── Request Models ────────────────────────────────────────


class BindTBRequest(BaseModel):
    coa_upload_id: Optional[str] = Field(
        None, description="COA upload ID to bind against (overrides the one from upload)"
    )
    fuzzy_threshold: float = Field(0.80, ge=0.0, le=1.0, description="Minimum fuzzy-match confidence threshold")


class ManualMatchRequest(BaseModel):
    coa_account_id: str = Field(..., description="COA account ID to match this TB row to")
    matched_by: Optional[str] = Field(None, description="User/system that performed the match")


class ApproveBindingRequest(BaseModel):
    approved_by: Optional[str] = Field(None, description="User/system that approved the binding")


router = APIRouter(tags=["Sprint 4 — TB Upload & Binding"])

SUPPORTED_EXTENSIONS = {".xlsx", ".xls"}
MAX_FILE_SIZE = 15 * 1024 * 1024


# ═══════════════════════════════════════════════════════════
# POST /clients/{client_id}/tb/upload
# ═══════════════════════════════════════════════════════════


@router.post("/clients/{client_id}/tb/upload")
async def upload_tb(
    client_id: str,
    file: UploadFile = File(...),
    coa_upload_id: Optional[str] = Query(None, description="Approved COA upload to bind against"),
    period_label: Optional[str] = Query(None),
):
    """Upload a trial balance file, parse it, and store rows."""
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(400, f"Unsupported file type: {ext}. Supported: xlsx, xls")

    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(400, f"File too large ({len(content)} bytes). Max: {MAX_FILE_SIZE}")
    if len(content) == 0:
        raise HTTPException(400, "File is empty")

    try:
        from app.phase1.models.platform_models import gen_uuid

        # Save file to disk
        upload_dir = os.environ.get("UPLOAD_DIR", "uploads")
        os.makedirs(upload_dir, exist_ok=True)
        stored_name = f"tb_{gen_uuid()[:8]}_{file.filename}"
        stored_path = os.path.join(upload_dir, stored_name)
        with open(stored_path, "wb") as f:
            f.write(content)

        # If no COA specified, find latest approved for this client
        db = get_db_session()
        try:
            if not coa_upload_id:
                coa_row = db.execute(
                    _t("""SELECT id FROM client_coa_uploads
                       WHERE client_id = :cid AND upload_status = 'approved'
                       ORDER BY created_at DESC LIMIT 1"""),
                    {"cid": client_id},
                ).fetchone()
                if coa_row:
                    coa_upload_id = coa_row[0]

            # Create upload record
            tb_id = gen_uuid()
            db.execute(
                _t("""INSERT INTO trial_balance_uploads
                   (id, client_id, coa_upload_id, file_name, stored_file_path,
                    file_extension, file_size_bytes, period_label,
                    upload_status, created_at, updated_at)
                   VALUES (:id, :cid, :coa, :fname, :path, :ext, :size, :period,
                           'uploaded', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"""),
                {
                    "id": tb_id,
                    "cid": client_id,
                    "coa": coa_upload_id,
                    "fname": file.filename,
                    "path": stored_path,
                    "ext": ext,
                    "size": len(content),
                    "period": period_label,
                },
            )
            db.commit()
        finally:
            db.close()

        # Parse the file
        from app.sprint4_tb.services.tb_file_service import read_and_save_tb

        parse_result = read_and_save_tb(content, file.filename, tb_id, stored_path)

        return {
            "success": True,
            "data": {
                "tb_upload_id": tb_id,
                "client_id": client_id,
                "coa_upload_id": coa_upload_id,
                "file_name": file.filename,
                "status": "parsed_with_warnings" if parse_result.get("warnings") else "parsed",
                "total_rows_parsed": parse_result["total_rows_parsed"],
                "total_rows_skipped": parse_result["total_rows_skipped"],
                "file_format": parse_result["file_format"],
                "company_name": parse_result["company_name"],
                "period": parse_result["period"],
                "warnings": parse_result["warnings"],
                "next_step": (
                    "POST /tb/uploads/{tb_upload_id}/bind" if coa_upload_id else "Specify coa_upload_id to bind"
                ),
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error("TB upload error", exc_info=True)
        raise HTTPException(500, "TB upload failed")


# ═══════════════════════════════════════════════════════════
# GET /tb/uploads/{tb_upload_id}
# ═══════════════════════════════════════════════════════════


@router.get("/tb/uploads/{tb_upload_id}")
def get_tb_upload(tb_upload_id: str):
    """Get TB upload metadata and status."""
    db = get_db_session()
    try:
        row = db.execute(
            _t("""SELECT id, client_id, coa_upload_id, file_name, file_format,
                      upload_status, period_label, total_rows_detected,
                      total_rows_parsed, total_rows_skipped,
                      company_name_detected, total_matched, total_unmatched,
                      binding_confidence_avg, binding_approved, created_at
               FROM trial_balance_uploads WHERE id = :uid"""),
            {"uid": tb_upload_id},
        ).fetchone()

        if not row:
            raise HTTPException(404, "TB upload not found")

        return {
            "success": True,
            "data": {
                "id": row[0],
                "client_id": row[1],
                "coa_upload_id": row[2],
                "file_name": row[3],
                "file_format": row[4],
                "upload_status": row[5],
                "period_label": row[6],
                "total_rows_detected": row[7],
                "total_rows_parsed": row[8],
                "total_rows_skipped": row[9],
                "company_name": row[10],
                "total_matched": row[11],
                "total_unmatched": row[12],
                "binding_confidence_avg": row[13],
                "binding_approved": bool(row[14]) if row[14] is not None else False,
                "created_at": str(row[15]) if row[15] else None,
            },
        }
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════
# POST /tb/uploads/{tb_upload_id}/bind
# ═══════════════════════════════════════════════════════════


@router.post("/tb/uploads/{tb_upload_id}/bind")
def bind_tb(tb_upload_id: str, body: BindTBRequest = BindTBRequest()):
    """Run binding engine — match TB rows to approved COA accounts."""
    from app.sprint4_tb.services.tb_binding_engine import bind_tb_to_coa

    db = get_db_session()
    try:
        row = db.execute(
            _t("SELECT client_id, coa_upload_id, upload_status FROM trial_balance_uploads WHERE id = :uid"),
            {"uid": tb_upload_id},
        ).fetchone()

        if not row:
            raise HTTPException(404, "TB upload not found")

        client_id = row[0]
        coa_upload_id = body.coa_upload_id or row[1]

        if not coa_upload_id:
            raise HTTPException(400, "coa_upload_id is required. Specify in body or upload with it.")

        status = row[2]
        if status not in ("parsed", "parsed_with_warnings", "bound", "bound_with_issues"):
            raise HTTPException(400, f"TB must be parsed first. Current status: {status}")
    finally:
        db.close()

    try:
        result = bind_tb_to_coa(
            tb_upload_id=tb_upload_id,
            coa_upload_id=coa_upload_id,
            client_id=client_id,
            fuzzy_threshold=body.fuzzy_threshold,
        )
        if not result.get("success"):
            raise HTTPException(400, result.get("error", "Binding failed"))
        return result
    except HTTPException:
        raise
    except Exception as e:
        logging.error("TB binding error", exc_info=True)
        raise HTTPException(500, "TB binding failed")


# ═══════════════════════════════════════════════════════════
# GET /tb/uploads/{tb_upload_id}/binding-results
# ═══════════════════════════════════════════════════════════


@router.get("/tb/uploads/{tb_upload_id}/binding-results")
def get_binding_results(
    tb_upload_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    matched_only: Optional[bool] = Query(None),
    requires_review: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
):
    """View binding results with filters and pagination."""
    db = get_db_session()
    try:
        where = ["tb_upload_id = :uid"]
        params = {"uid": tb_upload_id}

        if matched_only is True:
            where.append("matched = true")
        elif matched_only is False:
            where.append("matched = false")

        if requires_review is True:
            where.append("requires_review = true")
        elif requires_review is False:
            where.append("requires_review = false")

        if search:
            where.append("(tb_account_name_raw LIKE :srch OR tb_account_code LIKE :srch)")
            params["srch"] = f"%{search}%"

        where_sql = " AND ".join(where)

        total = db.execute(_t(f"SELECT COUNT(*) FROM tb_binding_results WHERE {where_sql}"), params).fetchone()[0]

        offset = (page - 1) * page_size
        rows = db.execute(
            _t(f"""SELECT id, tb_row_id, coa_account_id,
                       tb_account_code, tb_account_name_raw,
                       tb_amount_debit, tb_amount_credit, tb_net_balance,
                       matched, match_type, binding_confidence, mismatch_reason,
                       requires_review, coa_normalized_class, coa_statement_section,
                       coa_cashflow_role, review_status
                FROM tb_binding_results WHERE {where_sql}
                ORDER BY matched ASC, binding_confidence ASC
                LIMIT :lim OFFSET :off"""),
            {**params, "lim": page_size, "off": offset},
        ).fetchall()

        items = []
        for r in rows:
            items.append(
                {
                    "id": r[0],
                    "tb_row_id": r[1],
                    "coa_account_id": r[2],
                    "tb_account_code": r[3],
                    "tb_account_name": r[4],
                    "tb_debit": r[5],
                    "tb_credit": r[6],
                    "tb_net": r[7],
                    "matched": bool(r[8]),
                    "match_type": r[9],
                    "confidence": r[10],
                    "mismatch_reason": r[11],
                    "requires_review": bool(r[12]),
                    "coa_class": r[13],
                    "coa_section": r[14],
                    "coa_cashflow": r[15],
                    "review_status": r[16],
                }
            )

        return {
            "success": True,
            "data": {
                "tb_upload_id": tb_upload_id,
                "total": total,
                "page": page,
                "page_size": page_size,
                "results": items,
            },
        }
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════
# POST /tb/binding/{binding_id}/match
# ═══════════════════════════════════════════════════════════


@router.post("/tb/binding/{binding_id}/match")
def manual_match(binding_id: str, body: ManualMatchRequest):
    """Manually match a TB row to a COA account."""
    from app.sprint4_tb.services.tb_binding_engine import manually_match_tb_row

    result = manually_match_tb_row(binding_id, body.coa_account_id, body.matched_by)
    if not result.get("success"):
        raise HTTPException(400, result.get("error"))
    return result


# ═══════════════════════════════════════════════════════════
# POST /tb/uploads/{tb_upload_id}/approve-binding
# ═══════════════════════════════════════════════════════════


@router.post("/tb/uploads/{tb_upload_id}/approve-binding")
def approve_tb_binding(tb_upload_id: str, body: ApproveBindingRequest = ApproveBindingRequest()):
    """Approve TB binding — marks ready for analysis."""
    from app.sprint4_tb.services.tb_binding_engine import approve_binding

    result = approve_binding(tb_upload_id, body.approved_by)
    if not result.get("success"):
        raise HTTPException(400, result.get("error"))
    return result


# ═══════════════════════════════════════════════════════════
# GET /tb/uploads/{tb_upload_id}/binding-summary
# ═══════════════════════════════════════════════════════════


@router.get("/tb/uploads/{tb_upload_id}/binding-summary")
def binding_summary(tb_upload_id: str):
    """Get binding summary statistics."""
    db = get_db_session()
    try:
        rows = db.execute(
            _t("""SELECT matched, match_type, binding_confidence, requires_review,
                      coa_normalized_class, tb_net_balance
               FROM tb_binding_results WHERE tb_upload_id = :uid"""),
            {"uid": tb_upload_id},
        ).fetchall()

        if not rows:
            raise HTTPException(404, "No binding results found")

        total = len(rows)
        matched = sum(1 for r in rows if r[0])
        unmatched = total - matched
        review_needed = sum(1 for r in rows if r[3])
        avg_conf = round(sum(r[2] or 0 for r in rows if r[0]) / max(matched, 1), 3)

        match_dist = {}
        class_dist = {}
        total_debit = 0.0
        total_credit = 0.0

        for r in rows:
            mt = r[1] or "unknown"
            match_dist[mt] = match_dist.get(mt, 0) + 1
            if r[4]:
                class_dist[r[4]] = class_dist.get(r[4], 0) + 1
            nb = r[5] or 0
            if nb > 0:
                total_debit += nb
            else:
                total_credit += abs(nb)

        return {
            "success": True,
            "data": {
                "tb_upload_id": tb_upload_id,
                "total_rows": total,
                "matched": matched,
                "unmatched": unmatched,
                "requires_review": review_needed,
                "avg_confidence": avg_conf,
                "match_percentage": round(matched / max(total, 1) * 100, 1),
                "match_type_distribution": match_dist,
                "class_distribution": class_dist,
                "total_debit": round(total_debit, 2),
                "total_credit": round(total_credit, 2),
                "balance_diff": round(total_debit - total_credit, 2),
            },
        }
    finally:
        db.close()
