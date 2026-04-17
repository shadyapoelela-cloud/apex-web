"""Autonomous AP Agent — data models.

Tables:
  ap_invoices       — one inbound vendor invoice
  ap_line_items     — invoice line detail (qty/price/vat per line)
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum

from sqlalchemy import (
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class APInvoiceStatus(str, Enum):
    RECEIVED = "received"
    OCR_DONE = "ocr_done"
    CODED = "coded"
    AWAITING_APPROVAL = "awaiting_approval"
    APPROVED = "approved"
    SCHEDULED = "scheduled"
    PAID = "paid"
    REJECTED = "rejected"
    ERROR = "error"


class APInvoice(Base):
    """One inbound vendor invoice travelling through the AP pipeline."""

    __tablename__ = "ap_invoices"

    id = Column(String(36), primary_key=True, default=_uuid)
    tenant_id = Column(String(36), index=True, nullable=True)

    # Ingestion
    source = Column(String(16), nullable=False)  # 'email' | 'whatsapp' | 'upload'
    source_ref = Column(String(200), nullable=True)  # message-id, wa-id, filename
    received_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    raw_file_url = Column(String(500), nullable=True)

    # OCR extraction (filled by processor_ocr)
    vendor_id = Column(String(36), nullable=True, index=True)
    vendor_name = Column(String(200), nullable=True)
    invoice_number = Column(String(64), nullable=True)
    invoice_date = Column(Date, nullable=True)
    due_date = Column(Date, nullable=True)
    currency = Column(String(3), nullable=False, default="SAR")
    subtotal = Column(Numeric(18, 2), nullable=True)
    vat_amount = Column(Numeric(18, 2), nullable=True)
    total = Column(Numeric(18, 2), nullable=True)
    vendor_iban = Column(String(40), nullable=True)
    ocr_confidence = Column(Numeric(5, 4), nullable=True)  # 0..1

    # 3-way match
    matched_po_id = Column(String(36), nullable=True, index=True)
    matched_receipt_id = Column(String(36), nullable=True, index=True)
    match_variance = Column(Numeric(18, 2), nullable=True)

    # GL coding
    suggested_account_id = Column(String(36), nullable=True)
    coding_confidence = Column(Numeric(5, 4), nullable=True)

    # Workflow
    status = Column(String(24), nullable=False, default=APInvoiceStatus.RECEIVED.value, index=True)
    approval_policy = Column(String(32), nullable=True)
    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)

    # Payment
    scheduled_payment_date = Column(Date, nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    payment_reference = Column(String(64), nullable=True)

    # Audit / exceptions
    exceptions = Column(JSON, nullable=True)        # list of {code, message}
    pipeline_log = Column(JSON, nullable=True)      # step-by-step trace
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow)

    line_items = relationship(
        "APLineItem", back_populates="invoice", cascade="all, delete-orphan"
    )


class APLineItem(Base):
    """One line on the inbound AP invoice."""

    __tablename__ = "ap_line_items"

    id = Column(String(36), primary_key=True, default=_uuid)
    invoice_id = Column(
        String(36),
        ForeignKey("ap_invoices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    line_number = Column(Integer, nullable=False)
    description = Column(String(500), nullable=False)
    quantity = Column(Numeric(18, 4), nullable=False, default=Decimal("1"))
    unit_price = Column(Numeric(18, 2), nullable=False)
    vat_rate = Column(Numeric(5, 2), nullable=False, default=Decimal("15.00"))
    line_net = Column(Numeric(18, 2), nullable=False)
    line_vat = Column(Numeric(18, 2), nullable=False)
    line_total = Column(Numeric(18, 2), nullable=False)

    matched_po_line_id = Column(String(36), nullable=True)
    suggested_account_id = Column(String(36), nullable=True)

    invoice = relationship("APInvoice", back_populates="line_items")
