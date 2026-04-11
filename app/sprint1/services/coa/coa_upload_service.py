"""
APEX Sprint 1 — COA Upload Service
═══════════════════════════════════════════════════════════════
Manages upload records, file storage, status transitions.
"""

import logging
from typing import Optional, Dict, Any
from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.sprint1.models.sprint1_models import (
    ClientCoaUpload,
    ClientChartOfAccount,
    RejectedCoaRow,
    CoaUploadStatus,
)
from app.core.storage_service import upload_file

logger = logging.getLogger(__name__)


def save_uploaded_file(content: bytes, filename: str) -> str:
    """Save file via storage service and return stored path."""
    result = upload_file(content, filename, folder="coa_uploads")
    if not result.get("success"):
        raise RuntimeError(f"File upload failed: {result.get('error', 'unknown')}")
    return result["stored_path"]


def create_upload_record(
    client_id: str,
    file_name: str,
    stored_path: str,
    file_extension: str,
    file_size: int,
    user_id: Optional[str] = None,
) -> str:
    """Create upload record in DB. Returns upload_id."""
    db = SessionLocal()
    try:
        upload = ClientCoaUpload(
            id=gen_uuid(),
            client_id=client_id,
            file_name=file_name,
            stored_file_path=stored_path,
            file_extension=file_extension,
            file_size_bytes=file_size,
            upload_status=CoaUploadStatus.uploaded.value,
            uploaded_by=user_id,
        )
        db.add(upload)
        db.commit()
        return upload.id
    finally:
        db.close()


def update_upload_detection(
    upload_id: str,
    detected_columns: list,
    suggested_mapping: dict,
    header_row_index: int,
    sheet_name: Optional[str] = None,
    warnings: list = None,
):
    """Update upload with detection results."""
    db = SessionLocal()
    try:
        upload = db.query(ClientCoaUpload).filter(ClientCoaUpload.id == upload_id).first()
        if upload:
            upload.upload_status = CoaUploadStatus.column_mapping_pending.value
            upload.detected_columns_json = detected_columns
            upload.column_mapping_json = suggested_mapping
            upload.header_row_index = header_row_index
            upload.sheet_name = sheet_name
            upload.warnings_json = warnings or []
            db.commit()
    finally:
        db.close()


def save_parse_results(upload_id: str, client_id: str, parse_result, column_mapping: dict):
    """Save parsed accounts and rejected rows to DB."""
    db = SessionLocal()
    try:
        upload = db.query(ClientCoaUpload).filter(ClientCoaUpload.id == upload_id).first()
        if not upload:
            return

        upload.upload_status = CoaUploadStatus.parsing.value
        upload.column_mapping_json = column_mapping
        db.commit()

        # Save parsed accounts
        for pr in parse_result.parsed_rows:
            account = ClientChartOfAccount(
                id=gen_uuid(),
                client_id=client_id,
                coa_upload_id=upload_id,
                source_row_number=pr.source_row_number,
                account_code=pr.account_code,
                account_name_raw=pr.account_name_raw or "",
                account_name_normalized=pr.account_name_normalized or "",
                parent_code=pr.parent_code,
                parent_name=pr.parent_name,
                account_level=pr.account_level,
                account_type_raw=pr.account_type_raw,
                normal_balance=pr.normal_balance,
                active_flag=pr.active_flag,
                notes=pr.notes,
                record_status=pr.record_status,
                issues_json=pr.issues,
            )
            db.add(account)

        # Save rejected rows
        for rr in parse_result.rejected_rows:
            rejected = RejectedCoaRow(
                id=gen_uuid(),
                coa_upload_id=upload_id,
                source_row_number=rr["source_row_number"],
                raw_row_json=rr["raw_row"],
                rejection_reasons_json=rr["reasons"],
            )
            db.add(rejected)

        # Update upload summary
        has_warnings = parse_result.total_rejected > 0 or any(pr.issues for pr in parse_result.parsed_rows)
        upload.upload_status = (
            CoaUploadStatus.parsed_with_warnings.value if has_warnings else CoaUploadStatus.parsed.value
        )
        upload.total_rows_detected = parse_result.total_detected
        upload.total_rows_parsed = parse_result.total_parsed
        upload.total_rows_rejected = parse_result.total_rejected
        upload.warnings_json = parse_result.warnings

        db.commit()
    except Exception:
        db.rollback()
        # Mark as failed
        try:
            upload = db.query(ClientCoaUpload).filter(ClientCoaUpload.id == upload_id).first()
            if upload:
                upload.upload_status = CoaUploadStatus.failed.value
                db.commit()
        except Exception:
            pass
        raise
    finally:
        db.close()


def get_upload(upload_id: str) -> Optional[Dict[str, Any]]:
    """Get upload record."""
    db = SessionLocal()
    try:
        u = db.query(ClientCoaUpload).filter(ClientCoaUpload.id == upload_id).first()
        if not u:
            return None
        return {
            "id": u.id,
            "client_id": u.client_id,
            "file_name": u.file_name,
            "file_extension": u.file_extension,
            "file_size_bytes": u.file_size_bytes,
            "upload_status": u.upload_status,
            "header_row_index": u.header_row_index,
            "sheet_name": u.sheet_name,
            "column_mapping": u.column_mapping_json,
            "detected_columns": u.detected_columns_json,
            "total_rows_detected": u.total_rows_detected,
            "total_rows_parsed": u.total_rows_parsed,
            "total_rows_rejected": u.total_rows_rejected,
            "warnings": u.warnings_json or [],
            "created_at": str(u.created_at),
        }
    finally:
        db.close()


def get_parsed_accounts(
    upload_id: str,
    page: int = 1,
    page_size: int = 50,
    record_status: Optional[str] = None,
    has_issues: Optional[bool] = None,
    search: Optional[str] = None,
):
    """Get parsed accounts with pagination and filters."""
    db = SessionLocal()
    try:
        q = db.query(ClientChartOfAccount).filter(ClientChartOfAccount.coa_upload_id == upload_id)

        if record_status:
            q = q.filter(ClientChartOfAccount.record_status == record_status)
        if has_issues is True:
            q = q.filter(ClientChartOfAccount.issues_json != "[]")
        if search:
            q = q.filter(ClientChartOfAccount.account_name_normalized.contains(search.lower()))

        total = q.count()
        accounts = (
            q.order_by(ClientChartOfAccount.source_row_number).offset((page - 1) * page_size).limit(page_size).all()
        )

        return {
            "accounts": [
                {
                    "id": a.id,
                    "source_row_number": a.source_row_number,
                    "account_code": a.account_code,
                    "account_name_raw": a.account_name_raw,
                    "account_name_normalized": a.account_name_normalized,
                    "parent_code": a.parent_code,
                    "parent_name": a.parent_name,
                    "account_level": a.account_level,
                    "account_type_raw": a.account_type_raw,
                    "normal_balance": a.normal_balance,
                    "active_flag": a.active_flag,
                    "notes": a.notes,
                    "record_status": a.record_status,
                    "issues": a.issues_json or [],
                }
                for a in accounts
            ],
            "total": total,
            "page": page,
            "page_size": page_size,
        }
    finally:
        db.close()
