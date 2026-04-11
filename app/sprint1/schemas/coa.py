"""
APEX Sprint 1 — Pydantic Schemas for COA Workflow
"""

from pydantic import BaseModel
from typing import Optional, List, Dict, Any

# ── Upload & Detection ──


class CoaUploadInitResponse(BaseModel):
    upload_id: str
    client_id: str
    file_name: str
    upload_status: str
    detected_columns: List[str]
    suggested_column_mapping: Dict[str, Optional[str]]
    sample_rows: List[Dict[str, Any]]
    sheets: List[str] = []
    warnings: List[str] = []


# ── Column Mapping ──


class CoaColumnMappingRequest(BaseModel):
    header_row_index: Optional[int] = 0
    sheet_name: Optional[str] = None
    column_mapping: Dict[str, str]  # standard_field -> raw_column_name


# ── Parse Results ──


class CoaAccountPreview(BaseModel):
    source_row_number: int
    account_code: Optional[str] = None
    account_name_raw: str
    parent_code: Optional[str] = None
    parent_name: Optional[str] = None
    account_level: Optional[int] = None
    account_type_raw: Optional[str] = None
    normal_balance: Optional[str] = None
    active_flag: bool = True
    issues: List[str] = []
    record_status: str = "parsed"


class CoaParseSummary(BaseModel):
    upload_id: str
    upload_status: str
    total_rows_detected: int
    total_rows_parsed: int
    total_rows_rejected: int
    warnings: List[str] = []
    preview_rows: List[CoaAccountPreview] = []


# ── Knowledge Feedback ──


class KnowledgeFeedbackCreate(BaseModel):
    client_id: str
    coa_upload_id: Optional[str] = None
    coa_account_id: Optional[str] = None
    feedback_source_type: str = "privileged_client"
    feedback_category: str
    feedback_severity: Optional[str] = None
    feedback_text: str
    suggested_correction_json: Optional[Dict[str, Any]] = None
    reference_context_json: Optional[Dict[str, Any]] = None


class KnowledgeFeedbackRead(BaseModel):
    id: str
    client_id: str
    feedback_category: str
    feedback_text: str
    status: str
    created_at: str
