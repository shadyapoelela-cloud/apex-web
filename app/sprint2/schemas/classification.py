from pydantic import BaseModel
from typing import Optional, List

class ClassificationResult(BaseModel):
    normalized_class: Optional[str] = None
    statement_section: Optional[str] = None
    subcategory: Optional[str] = None
    current_noncurrent: Optional[str] = None
    cashflow_role: Optional[str] = None
    sign_rule: Optional[str] = None
    mapping_confidence: float = 0.0
    mapping_source: Optional[str] = None
    classification_issues: List[str] = []
    review_status: str = "draft"

class ClassifySummary(BaseModel):
    upload_id: str
    total_accounts: int
    classified: int
    high_confidence: int
    low_confidence: int
    unclassified: int
    avg_confidence: float
    class_distribution: dict
    section_distribution: dict

class AccountMappingPreview(BaseModel):
    id: str
    source_row_number: int
    account_code: Optional[str] = None
    account_name_raw: str
    parent_code: Optional[str] = None
    account_level: Optional[int] = None
    account_type_raw: Optional[str] = None
    normal_balance: Optional[str] = None
    normalized_class: Optional[str] = None
    statement_section: Optional[str] = None
    subcategory: Optional[str] = None
    current_noncurrent: Optional[str] = None
    cashflow_role: Optional[str] = None
    sign_rule: Optional[str] = None
    mapping_confidence: float = 0.0
    mapping_source: Optional[str] = None
    review_status: str = "draft"
    issues: List[str] = []
    classification_issues: List[str] = []

class AccountEditRequest(BaseModel):
    normalized_class: Optional[str] = None
    statement_section: Optional[str] = None
    subcategory: Optional[str] = None
    current_noncurrent: Optional[str] = None
    cashflow_role: Optional[str] = None
    sign_rule: Optional[str] = None

class BulkApproveRequest(BaseModel):
    account_ids: List[str] = []
    min_confidence: Optional[float] = None
    approve_all_above: Optional[float] = None
