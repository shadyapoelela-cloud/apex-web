"""Pydantic v2 DTOs for the invoicing API."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator

from app.invoicing.models import (
    CreditNoteReason,
    CreditNoteStatus,
    CreditNoteType,
    InvoiceType,
    RecurrenceFrequency,
)


# ── Credit Note DTOs ──────────────────────────────────────


class CreditNoteLineIn(BaseModel):
    line_no: int = Field(..., ge=1)
    description: str = Field(..., min_length=1, max_length=400)
    quantity: float = Field(..., gt=0)
    unit_price: float = Field(..., ge=0)
    tax_rate: Optional[str] = None
    account_id: Optional[str] = None


class CreditNoteCreateIn(BaseModel):
    entity_id: str = Field(..., min_length=1, max_length=36)
    cn_type: str = Field(default=CreditNoteType.CREDIT)
    cn_number: str = Field(..., min_length=1, max_length=40)
    issue_date: date
    original_invoice_id: Optional[str] = None
    original_invoice_type: Optional[str] = None
    original_invoice_number: Optional[str] = None
    customer_id: Optional[str] = None
    vendor_id: Optional[str] = None
    currency_code: str = Field(default="SAR", min_length=3, max_length=3)
    reason_code: str = Field(..., min_length=1, max_length=40)
    reason_text: Optional[str] = Field(default=None, max_length=400)
    notes: Optional[str] = Field(default=None, max_length=800)
    lines: list[CreditNoteLineIn] = Field(..., min_length=1)

    @field_validator("cn_type")
    @classmethod
    def _valid_cn_type(cls, v: str) -> str:
        if v not in CreditNoteType.ALL:
            raise ValueError(f"invalid cn_type: {v}")
        return v

    @field_validator("reason_code")
    @classmethod
    def _valid_reason(cls, v: str) -> str:
        if v not in CreditNoteReason.ALL:
            raise ValueError(f"invalid reason_code: {v}")
        return v


class CreditNoteOut(BaseModel):
    id: str
    entity_id: str
    cn_type: str
    cn_number: str
    issue_date: date
    original_invoice_id: Optional[str] = None
    original_invoice_type: Optional[str] = None
    original_invoice_number: Optional[str] = None
    customer_id: Optional[str] = None
    vendor_id: Optional[str] = None
    subtotal: float
    tax_total: float
    grand_total: float
    currency_code: str
    reason_code: str
    reason_text: Optional[str] = None
    status: str
    applied_amount: float
    journal_entry_id: Optional[str] = None
    zatca_uuid: Optional[str] = None
    zatca_status: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    lines: list[dict[str, Any]] = Field(default_factory=list)


class ApplyCreditNoteIn(BaseModel):
    target_invoice_id: str
    amount: Optional[float] = None
    reason: Optional[str] = Field(default=None, max_length=400)


# ── Recurring template DTOs ───────────────────────────────


class RecurringTemplateLineIn(BaseModel):
    description: str = Field(..., min_length=1, max_length=400)
    quantity: float = Field(..., gt=0)
    unit_price: float = Field(..., ge=0)
    tax_rate: Optional[str] = None
    account_id: Optional[str] = None


class RecurringTemplateCreateIn(BaseModel):
    entity_id: str = Field(..., min_length=1, max_length=36)
    template_name: str = Field(..., min_length=1, max_length=160)
    invoice_type: str
    customer_id: Optional[str] = None
    vendor_id: Optional[str] = None
    frequency: str
    interval_n: int = Field(default=1, ge=1, le=365)
    start_date: date
    end_date: Optional[date] = None
    max_runs: Optional[int] = Field(default=None, ge=1)
    currency_code: str = Field(default="SAR", min_length=3, max_length=3)
    auto_issue: bool = False
    auto_send_email: bool = False
    notes: Optional[str] = Field(default=None, max_length=800)
    lines: list[RecurringTemplateLineIn] = Field(..., min_length=1)

    @field_validator("invoice_type")
    @classmethod
    def _valid_invoice_type(cls, v: str) -> str:
        if v not in (InvoiceType.SALES, InvoiceType.PURCHASE):
            raise ValueError(f"invoice_type must be 'sales' or 'purchase'")
        return v

    @field_validator("frequency")
    @classmethod
    def _valid_frequency(cls, v: str) -> str:
        if v not in RecurrenceFrequency.ALL:
            raise ValueError(f"invalid frequency: {v}")
        return v


class RecurringTemplateUpdateIn(BaseModel):
    template_name: Optional[str] = Field(default=None, max_length=160)
    end_date: Optional[date] = None
    max_runs: Optional[int] = Field(default=None, ge=1)
    auto_issue: Optional[bool] = None
    auto_send_email: Optional[bool] = None
    is_active: Optional[bool] = None
    notes: Optional[str] = Field(default=None, max_length=800)
    lines: Optional[list[RecurringTemplateLineIn]] = None


class RecurringTemplateOut(BaseModel):
    id: str
    entity_id: str
    template_name: str
    invoice_type: str
    customer_id: Optional[str] = None
    vendor_id: Optional[str] = None
    frequency: str
    interval_n: int
    start_date: date
    end_date: Optional[date] = None
    next_run_date: date
    runs_count: int
    max_runs: Optional[int] = None
    currency_code: str
    auto_issue: bool
    auto_send_email: bool
    is_active: bool
    last_run_at: Optional[datetime] = None
    last_invoice_id: Optional[str] = None
    lines_json: list[dict[str, Any]] = Field(default_factory=list)
    notes: Optional[str] = None
    created_at: datetime


# ── Aged AR/AP ────────────────────────────────────────────


class AgedBucketOut(BaseModel):
    bucket: str  # "0-30", "31-60", "61-90", "91-120", ">120"
    count: int
    total: float


class AgedReportOut(BaseModel):
    entity_id: str
    as_of_date: date
    currency_code: str
    buckets: list[AgedBucketOut]
    grand_total: float
    overdue_count: int


# ── Bulk operations ───────────────────────────────────────


class BulkInvoiceIdsIn(BaseModel):
    invoice_ids: list[str] = Field(..., min_length=1, max_length=100)
    reason: Optional[str] = Field(default=None, max_length=400)


class BulkActionResultOut(BaseModel):
    succeeded: list[str]
    failed: dict[str, str]  # id → error message


# ── Attachments ───────────────────────────────────────────


class AttachmentOut(BaseModel):
    id: str
    invoice_id: str
    invoice_type: str
    filename: str
    file_size: int
    mime_type: str
    uploaded_at: datetime
    uploaded_by: Optional[str] = None


# ── Write-off ─────────────────────────────────────────────


class WriteOffIn(BaseModel):
    reason: str = Field(..., min_length=1, max_length=400)
    write_off_account_id: Optional[str] = None


__all__ = [
    "CreditNoteLineIn",
    "CreditNoteCreateIn",
    "CreditNoteOut",
    "ApplyCreditNoteIn",
    "RecurringTemplateLineIn",
    "RecurringTemplateCreateIn",
    "RecurringTemplateUpdateIn",
    "RecurringTemplateOut",
    "AgedBucketOut",
    "AgedReportOut",
    "BulkInvoiceIdsIn",
    "BulkActionResultOut",
    "AttachmentOut",
    "WriteOffIn",
]
