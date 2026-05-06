"""Invoicing ORM models (INV-1, Sprint 18).

Four tables:

    credit_notes                  — credit / debit notes against an existing invoice
    credit_note_lines             — line items for the above
    recurring_invoice_templates   — periodic invoice schedules (daily/weekly/monthly/...)
    invoice_attachments           — file attachments for any invoice type

All four live on `PhaseBase` from app.phase1.models.platform_models so
alembic autogenerate picks them up via `_MODEL_MODULES` in
alembic/env.py.

These tables sit alongside (NOT replace) the existing
`pilot_sales_invoices` + `pilot_purchase_invoices`. See
`app/invoicing/GAP_ANALYSIS.md` for the why.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base


# ── Enum-like string constants ────────────────────────────


class CreditNoteType:
    CREDIT = "credit"  # reduces AR / AP balance
    DEBIT = "debit"    # increases AR / AP balance (rare — vendor over-billed correction)
    ALL = (CREDIT, DEBIT)


class CreditNoteStatus:
    DRAFT = "draft"
    ISSUED = "issued"
    APPLIED = "applied"
    CANCELLED = "cancelled"
    ALL = (DRAFT, ISSUED, APPLIED, CANCELLED)


class CreditNoteReason:
    """ZATCA-required reason codes for credit/debit notes."""

    RETURN = "return"
    DISCOUNT = "discount"
    CORRECTION = "correction"
    WRITE_OFF = "writeoff"
    PRICE_ADJUSTMENT = "price_adjustment"
    QUANTITY_ADJUSTMENT = "quantity_adjustment"
    ALL = (RETURN, DISCOUNT, CORRECTION, WRITE_OFF, PRICE_ADJUSTMENT, QUANTITY_ADJUSTMENT)


class RecurrenceFrequency:
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    QUARTERLY = "quarterly"
    YEARLY = "yearly"
    ALL = (DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY)


class InvoiceType:
    SALES = "sales"
    PURCHASE = "purchase"
    CREDIT_NOTE = "credit_note"
    ALL = (SALES, PURCHASE, CREDIT_NOTE)


# ── Credit Note ───────────────────────────────────────────


class CreditNote(Base, TenantMixin):
    """Credit / debit note against an existing sales or purchase invoice.

    `cn_type='credit'` reduces the receivable (sales) or payable
    (purchase). `cn_type='debit'` is the rarer correction-upward
    variant.

    `original_invoice_id` references either `pilot_sales_invoices.id`
    or `pilot_purchase_invoices.id` — `original_invoice_type`
    disambiguates. We don't add a hard FK because the FK target
    depends on the discriminator column.

    `reason_code` is mandatory for ZATCA compliance.
    """

    __tablename__ = "credit_notes"
    __table_args__ = (
        UniqueConstraint("tenant_id", "entity_id", "cn_number", name="uq_cn_number"),
        Index("ix_cn_original", "original_invoice_id"),
        Index("ix_cn_status", "status"),
        Index("ix_cn_customer", "customer_id"),
        Index("ix_cn_vendor", "vendor_id"),
        Index("ix_cn_issue_date", "issue_date"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    entity_id = Column(String(36), nullable=False, index=True)

    cn_type = Column(String(20), nullable=False, default=CreditNoteType.CREDIT)
    cn_number = Column(String(40), nullable=False)
    issue_date = Column(Date, nullable=False)

    # Reference to the original invoice
    original_invoice_id = Column(String(36), nullable=True)
    original_invoice_type = Column(String(20), nullable=True)
    original_invoice_number = Column(String(50), nullable=True)

    # Counterparty
    customer_id = Column(String(36), nullable=True)
    vendor_id = Column(String(36), nullable=True)

    # Amounts
    subtotal = Column(Numeric(20, 2), nullable=False, default=0)
    tax_total = Column(Numeric(20, 2), nullable=False, default=0)
    grand_total = Column(Numeric(20, 2), nullable=False, default=0)
    currency_code = Column(String(3), nullable=False, default="SAR")

    # Reason (required by ZATCA)
    reason_code = Column(String(40), nullable=False)
    reason_text = Column(String(400), nullable=True)

    # Status
    status = Column(String(20), nullable=False, default=CreditNoteStatus.DRAFT)
    applied_at = Column(DateTime(timezone=True), nullable=True)
    applied_amount = Column(Numeric(20, 2), nullable=False, default=0)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)

    # Journal entry + ZATCA
    journal_entry_id = Column(String(36), nullable=True)
    zatca_uuid = Column(String(36), nullable=True)
    zatca_qr = Column(Text, nullable=True)
    zatca_status = Column(String(20), nullable=True)

    # Audit
    notes = Column(String(800), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    created_by = Column(String(36), nullable=True)

    lines = relationship(
        "CreditNoteLine",
        back_populates="credit_note",
        cascade="all, delete-orphan",
    )


class CreditNoteLine(Base):
    """Line item on a credit note."""

    __tablename__ = "credit_note_lines"
    __table_args__ = (
        Index("ix_cn_line_cn", "cn_id"),
        UniqueConstraint("cn_id", "line_no", name="uq_cn_line_no"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cn_id = Column(
        String(36),
        ForeignKey("credit_notes.id", ondelete="CASCADE"),
        nullable=False,
    )
    line_no = Column(Integer, nullable=False)
    description = Column(String(400), nullable=False)
    quantity = Column(Numeric(14, 4), nullable=False, default=1)
    unit_price = Column(Numeric(18, 4), nullable=False, default=0)
    line_total = Column(Numeric(18, 2), nullable=False, default=0)
    tax_rate = Column(String(20), nullable=True)
    tax_amount = Column(Numeric(18, 2), nullable=False, default=0)

    # CoA-1 link (optional — falls back to original invoice's account)
    account_id = Column(String(36), nullable=True)

    credit_note = relationship("CreditNote", back_populates="lines")


# ── Recurring Invoice Template ────────────────────────────


class RecurringInvoiceTemplate(Base, TenantMixin):
    """Periodic invoice schedule.

    A daily scheduler (`app/invoicing/scheduler.py`) walks templates
    where `next_run_date <= today AND is_active=True` and calls
    `service.run_recurring_template(...)` for each.
    """

    __tablename__ = "recurring_invoice_templates"
    __table_args__ = (
        Index("ix_recurring_next_run", "next_run_date", "is_active"),
        Index("ix_recurring_entity", "entity_id"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    entity_id = Column(String(36), nullable=False)

    template_name = Column(String(160), nullable=False)
    invoice_type = Column(String(20), nullable=False)  # sales | purchase
    customer_id = Column(String(36), nullable=True)
    vendor_id = Column(String(36), nullable=True)

    # Schedule
    frequency = Column(String(20), nullable=False)
    interval_n = Column(Integer, nullable=False, default=1)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    next_run_date = Column(Date, nullable=False)
    runs_count = Column(Integer, nullable=False, default=0)
    max_runs = Column(Integer, nullable=True)

    # Template payload — list of line dicts:
    #   [{"description": "...", "quantity": 1, "unit_price": 100.0,
    #     "tax_rate": "VAT_15", "account_id": "..."}]
    lines_json = Column(JSON, nullable=False, default=list)
    notes = Column(String(800), nullable=True)
    currency_code = Column(String(3), nullable=False, default="SAR")

    # Auto-issue / send
    auto_issue = Column(Boolean, nullable=False, default=False)
    auto_send_email = Column(Boolean, nullable=False, default=False)

    is_active = Column(Boolean, nullable=False, default=True)
    last_run_at = Column(DateTime(timezone=True), nullable=True)
    last_invoice_id = Column(String(36), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    created_by = Column(String(36), nullable=True)


# ── Invoice Attachment ────────────────────────────────────


class InvoiceAttachment(Base, TenantMixin):
    """File attachment for any invoice type.

    `invoice_id` is a logical reference — `invoice_type` discriminates
    (sales / purchase / credit_note) which table to look up.
    `storage_key` is opaque to this module — the storage backend
    (`app.core.storage`) maps it to S3 / local FS.
    """

    __tablename__ = "invoice_attachments"
    __table_args__ = (
        Index("ix_attachment_invoice", "invoice_id", "invoice_type"),
        Index("ix_attachment_uploaded_at", "uploaded_at"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    invoice_id = Column(String(36), nullable=False)
    invoice_type = Column(String(20), nullable=False)

    filename = Column(String(200), nullable=False)
    file_size = Column(Integer, nullable=False)
    mime_type = Column(String(80), nullable=False)
    storage_key = Column(String(400), nullable=False)
    uploaded_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    uploaded_by = Column(String(36), nullable=True)


__all__ = [
    "CreditNoteType",
    "CreditNoteStatus",
    "CreditNoteReason",
    "RecurrenceFrequency",
    "InvoiceType",
    "CreditNote",
    "CreditNoteLine",
    "RecurringInvoiceTemplate",
    "InvoiceAttachment",
]
