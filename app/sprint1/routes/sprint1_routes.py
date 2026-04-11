"""
APEX Sprint 1 — COA First Workflow Routes
═══════════════════════════════════════════════════════════════
APIs per Sprint 1 Build Spec §15:
  POST /clients/{client_id}/coa/upload
  GET  /coa/uploads/{upload_id}
  POST /coa/uploads/{upload_id}/parse
  GET  /coa/uploads/{upload_id}/accounts
  POST /knowledge-feedback
  GET  /knowledge-feedback
"""
import os
import logging
from fastapi import APIRouter, File, UploadFile, HTTPException, Query, Depends
from pydantic import BaseModel, Field
from typing import Any, Dict, Optional


# ── Request Models ──

class ParseCoaRequest(BaseModel):
    column_mapping: Optional[Dict[str, str]] = Field(None, description="Column mapping overrides")
    header_row_index: Optional[int] = Field(None, description="Header row index override")
    sheet_name: Optional[str] = Field(None, description="Sheet name override")


class KnowledgeFeedbackRequest(BaseModel):
    client_id: str = Field(..., description="Client ID")
    feedback_category: str = Field(..., description="Feedback category")
    feedback_text: str = Field(..., description="Feedback text content")
    coa_upload_id: Optional[str] = Field(None, description="Related COA upload ID")
    coa_account_id: Optional[str] = Field(None, description="Related COA account ID")
    feedback_source_type: str = Field("privileged_client", description="Source type of feedback")
    submitted_by: Optional[str] = Field(None, description="User who submitted the feedback")
    feedback_severity: Optional[str] = Field(None, description="Severity level of feedback")
    suggested_correction_json: Optional[Any] = Field(None, description="Suggested correction data")
    reference_context_json: Optional[Any] = Field(None, description="Reference context data")

router = APIRouter(tags=["Sprint 1 — COA Workflow"])

SUPPORTED_EXTENSIONS = {".csv", ".xlsx", ".xls"}
MAX_FILE_SIZE = 15 * 1024 * 1024  # 15MB


# ── Auth dependency (reuse Phase 1) ──

def get_current_user(authorization: str = None):
    """Extract user from JWT."""
    if not authorization:
        return None
    from app.core.auth_utils import JWT_SECRET, JWT_ALGORITHM
    import jwt
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except Exception:
        raise HTTPException(401, "Invalid token")


# ══════════════════════════════════════════════════════════════
# POST /clients/{client_id}/coa/upload
# ══════════════════════════════════════════════════════════════

@router.post("/clients/{client_id}/coa/upload")
async def upload_coa(
    client_id: str,
    file: UploadFile = File(...),
    sheet_name: Optional[str] = Query(None),
    header_row_index: Optional[int] = Query(None),
):
    """Upload COA file → detect columns → return suggested mapping."""
    # Validate extension
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(400, {
            "error_code": "unsupported_file_type",
            "message": f"Unsupported file type: {ext}. Supported: csv, xlsx, xls",
        })
    
    content = await file.read()

    MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10MB
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(413, "حجم الملف يتجاوز الحد المسموح 10MB")

    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(400, {
            "error_code": "file_too_large",
            "message": f"File too large ({len(content)} bytes). Max: {MAX_FILE_SIZE}",
        })
    
    if len(content) == 0:
        raise HTTPException(400, {"error_code": "empty_file", "message": "File is empty"})
    
    try:
        from app.sprint1.services.coa.coa_upload_service import save_uploaded_file, create_upload_record, update_upload_detection
        from app.sprint1.services.coa.coa_file_reader import detect_header_and_columns, list_sheets
        
        # Save file
        stored_path = save_uploaded_file(content, file.filename)
        
        # Create upload record
        upload_id = create_upload_record(
            client_id=client_id,
            file_name=file.filename,
            stored_path=stored_path,
            file_extension=ext,
            file_size=len(content),
        )
        
        # Detect columns
        detection = detect_header_and_columns(stored_path, sheet_name, header_row_index)
        sheets = list_sheets(stored_path)
        
        # Update record
        update_upload_detection(
            upload_id=upload_id,
            detected_columns=detection["detected_columns"],
            suggested_mapping=detection["suggested_mapping"],
            header_row_index=detection["header_row_index"],
            sheet_name=sheet_name,
            warnings=detection["warnings"],
        )
        
        return {"success": True, "data": {
            "upload_id": upload_id,
            "client_id": client_id,
            "file_name": file.filename,
            "upload_status": "column_mapping_pending",
            "detected_columns": detection["detected_columns"],
            "suggested_column_mapping": detection["suggested_mapping"],
            "sample_rows": detection["sample_rows"],
            "sheets": sheets,
            "warnings": detection["warnings"],
        }}
    
    except HTTPException:
        raise
    except Exception as e:
        logging.error("COA upload failed", exc_info=True)
        raise HTTPException(500, "Upload processing failed")


# ══════════════════════════════════════════════════════════════
# GET /coa/uploads/{upload_id}
# ══════════════════════════════════════════════════════════════

@router.get("/coa/uploads/{upload_id}")
async def get_upload_status(upload_id: str):
    """Get upload metadata and current status."""
    from app.sprint1.services.coa.coa_upload_service import get_upload
    upload = get_upload(upload_id)
    if not upload:
        raise HTTPException(404, "Upload not found")
    return {"success": True, "data": upload}


# ══════════════════════════════════════════════════════════════
# POST /coa/uploads/{upload_id}/parse
# ══════════════════════════════════════════════════════════════

@router.post("/coa/uploads/{upload_id}/parse")
async def parse_coa(upload_id: str, body: ParseCoaRequest = None):
    """Execute full parse after confirming column mapping."""
    from app.sprint1.services.coa.coa_upload_service import get_upload, save_parse_results
    from app.sprint1.services.coa.coa_file_reader import stream_rows
    from app.sprint1.services.coa.coa_parser import parse_upload

    upload = get_upload(upload_id)
    if not upload:
        raise HTTPException(404, "Upload not found")

    # Get mapping from request body or stored mapping
    body = body or ParseCoaRequest()
    column_mapping = body.column_mapping or upload.get("column_mapping") or {}
    header_row_index = body.header_row_index
    if header_row_index is None:
        header_row_index = upload.get("header_row_index", 0)
    sheet_name = body.sheet_name or upload.get("sheet_name")
    
    # Validate: account_name mapping required
    if "account_name" not in column_mapping or not column_mapping["account_name"]:
        raise HTTPException(422, {
            "error_code": "required_column_missing",
            "message": "Column mapping for account_name is required.",
            "details": {"required_field": "account_name"},
        })
    
    # Check for duplicate mapping
    mapped_cols = [v for v in column_mapping.values() if v]
    if len(mapped_cols) != len(set(mapped_cols)):
        raise HTTPException(422, {
            "error_code": "duplicate_column_mapping",
            "message": "Same raw column mapped to multiple standard fields.",
        })
    
    try:
        # Get stored file path
        from app.phase1.models.platform_models import SessionLocal
        from app.sprint1.models.sprint1_models import ClientCoaUpload
        db = SessionLocal()
        try:
            u = db.query(ClientCoaUpload).filter(ClientCoaUpload.id == upload_id).first()
            file_path = u.stored_file_path if u else None
        finally:
            db.close()
        
        if not file_path or not os.path.exists(file_path):
            raise HTTPException(404, "Upload file not found on disk")
        
        # Stream rows and parse
        rows = stream_rows(file_path, sheet_name, header_row_index)
        parse_result = parse_upload(rows, column_mapping)
        
        # Save to DB
        save_parse_results(upload_id, upload["client_id"], parse_result, column_mapping)
        
        # Build preview (first 20 rows)
        preview = []
        for pr in parse_result.parsed_rows[:20]:
            preview.append({
                "source_row_number": pr.source_row_number,
                "account_code": pr.account_code,
                "account_name_raw": pr.account_name_raw,
                "parent_code": pr.parent_code,
                "parent_name": pr.parent_name,
                "account_level": pr.account_level,
                "account_type_raw": pr.account_type_raw,
                "normal_balance": pr.normal_balance,
                "active_flag": pr.active_flag,
                "issues": pr.issues,
                "record_status": pr.record_status,
            })
        
        has_warnings = parse_result.total_rejected > 0 or parse_result.warnings
        return {"success": True, "data": {
            "upload_id": upload_id,
            "upload_status": "parsed_with_warnings" if has_warnings else "parsed",
            "total_rows_detected": parse_result.total_detected,
            "total_rows_parsed": parse_result.total_parsed,
            "total_rows_rejected": parse_result.total_rejected,
            "warnings": parse_result.warnings,
            "preview_rows": preview,
        }}
    
    except HTTPException:
        raise
    except Exception as e:
        logging.error("COA parse error", exc_info=True)
        raise HTTPException(500, "COA file parsing failed")


# ══════════════════════════════════════════════════════════════
# GET /coa/uploads/{upload_id}/accounts
# ══════════════════════════════════════════════════════════════

@router.get("/coa/uploads/{upload_id}/accounts")
async def list_parsed_accounts(
    upload_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    record_status: Optional[str] = Query(None),
    has_issues: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
):
    """List parsed accounts with pagination and filters."""
    from app.sprint1.services.coa.coa_upload_service import get_parsed_accounts
    result = get_parsed_accounts(upload_id, page, page_size, record_status, has_issues, search)
    return {"success": True, "data": result}


# ══════════════════════════════════════════════════════════════
# POST /knowledge-feedback (Sprint 1 Spec §28)
# ══════════════════════════════════════════════════════════════

@router.post("/coa/knowledge-feedback")
async def create_knowledge_feedback(body: KnowledgeFeedbackRequest):
    """Save structured knowledge feedback from eligible client."""
    from app.phase1.models.platform_models import SessionLocal, gen_uuid
    from app.sprint1.models.sprint1_models import CoaKnowledgeFeedback

    db = SessionLocal()
    try:
        fb = CoaKnowledgeFeedback(
            id=gen_uuid(),
            client_id=body.client_id,
            coa_upload_id=body.coa_upload_id,
            coa_account_id=body.coa_account_id,
            feedback_source_type=body.feedback_source_type,
            submitted_by=body.submitted_by,
            feedback_category=body.feedback_category,
            feedback_severity=body.feedback_severity,
            feedback_text=body.feedback_text,
            suggested_correction_json=body.suggested_correction_json,
            reference_context_json=body.reference_context_json,
        )
        db.add(fb)
        db.commit()
        return {"success": True, "data": {"id": fb.id, "status": "submitted", "message": "تم حفظ الملاحظة بنجاح"}}
    except Exception as e:
        db.rollback()
        logging.error("Knowledge feedback submission failed", exc_info=True)
        raise HTTPException(500, "Failed to submit feedback")
    finally:
        db.close()


@router.get("/coa/knowledge-feedback")
async def list_knowledge_feedback(
    client_id: Optional[str] = Query(None),
    coa_upload_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List knowledge feedback events with filters."""
    from app.phase1.models.platform_models import SessionLocal
    from app.sprint1.models.sprint1_models import CoaKnowledgeFeedback
    
    db = SessionLocal()
    try:
        q = db.query(CoaKnowledgeFeedback)
        if client_id:
            q = q.filter(CoaKnowledgeFeedback.client_id == client_id)
        if coa_upload_id:
            q = q.filter(CoaKnowledgeFeedback.coa_upload_id == coa_upload_id)
        if status:
            q = q.filter(CoaKnowledgeFeedback.status == status)
        
        total = q.count()
        items = q.order_by(CoaKnowledgeFeedback.created_at.desc())\
            .offset((page - 1) * page_size).limit(page_size).all()
        
        return {"success": True, "data": {
            "feedback": [{
                "id": f.id,
                "client_id": f.client_id,
                "coa_upload_id": f.coa_upload_id,
                "feedback_category": f.feedback_category,
                "feedback_severity": f.feedback_severity,
                "feedback_text": f.feedback_text,
                "status": f.status,
                "created_at": str(f.created_at),
            } for f in items],
            "total": total,
            "page": page,
            "page_size": page_size,
        }}
    finally:
        db.close()
