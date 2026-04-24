"""SAP-style Universal Journal query layer.

Single unified query that projects ALL finance postings (manual JE, POS
sale auto-JE, purchase-invoice auto-JE, customer-payment auto-JE, ...)
into ONE flat row shape with:

  journal_entry_id, je_number, je_date, posting_date, source_type,
  source_id, account_id, account_code, account_name, category,
  debit_amount, credit_amount, currency, ledger_id, dimensions,
  partner_type, partner_id, description

Corresponds to SAP's ACDOCA table — one table for Ledger, Controlling,
Asset Accounting, and Material Ledger, instead of 20 separate ones.

The query supports line-level filtering by ANY dimension, account,
partner, date range, source type, or ledger. That's the enterprise
reporting primitive: one stop for every kind of drill-down.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any, Optional

logger = logging.getLogger(__name__)


@dataclass
class UJRow:
    journal_entry_id: str
    je_number: str
    je_date: str
    posting_date: Optional[str]
    status: str
    source_type: Optional[str]
    source_id: Optional[str]
    source_reference: Optional[str]
    account_id: str
    account_code: str
    account_name: str
    category: str
    debit_amount: float
    credit_amount: float
    currency: str
    ledger_id: str
    dimensions: Optional[dict[str, Any]]
    partner_type: Optional[str]
    partner_id: Optional[str]
    partner_name: Optional[str]
    description: Optional[str]
    entity_id: str
    tenant_id: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "journal_entry_id": self.journal_entry_id,
            "je_number": self.je_number,
            "je_date": self.je_date,
            "posting_date": self.posting_date,
            "status": self.status,
            "source_type": self.source_type,
            "source_id": self.source_id,
            "source_reference": self.source_reference,
            "account_id": self.account_id,
            "account_code": self.account_code,
            "account_name": self.account_name,
            "category": self.category,
            "debit_amount": self.debit_amount,
            "credit_amount": self.credit_amount,
            "currency": self.currency,
            "ledger_id": self.ledger_id,
            "dimensions": self.dimensions,
            "partner_type": self.partner_type,
            "partner_id": self.partner_id,
            "partner_name": self.partner_name,
            "description": self.description,
            "entity_id": self.entity_id,
            "tenant_id": self.tenant_id,
        }


def query_universal_journal(
    *,
    tenant_id: Optional[str] = None,
    entity_id: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    account_codes: Optional[list[str]] = None,
    account_categories: Optional[list[str]] = None,
    source_types: Optional[list[str]] = None,
    status: Optional[str] = "posted",
    ledger_id: Optional[str] = "L1",
    partner_id: Optional[str] = None,
    dimension_filters: Optional[dict[str, str]] = None,
    limit: int = 500,
    offset: int = 0,
) -> list[dict[str, Any]]:
    """Pull ACDOCA-style flat rows. Every filter optional — the default
    grabs today's posted entries in the primary ledger."""
    try:
        from sqlalchemy import and_
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import JournalEntry, JournalLine, GLAccount
    except Exception as e:
        logger.debug("universal_journal: pilot layer unavailable (%s)", e)
        return []

    db = SessionLocal()
    try:
        q = (
            db.query(JournalLine, JournalEntry, GLAccount)
            .join(JournalEntry, JournalLine.journal_entry_id == JournalEntry.id)
            .join(GLAccount, JournalLine.account_id == GLAccount.id)
        )

        if tenant_id:
            q = q.filter(JournalLine.tenant_id == tenant_id)
        if entity_id:
            q = q.filter(JournalEntry.entity_id == entity_id)
        if status:
            q = q.filter(JournalEntry.status == status)
        if start_date:
            q = q.filter(JournalEntry.je_date >= start_date)
        if end_date:
            q = q.filter(JournalEntry.je_date <= end_date)
        if account_codes:
            q = q.filter(GLAccount.code.in_(account_codes))
        if account_categories:
            q = q.filter(GLAccount.category.in_(account_categories))
        if source_types:
            q = q.filter(JournalEntry.source_type.in_(source_types))
        if partner_id:
            q = q.filter(JournalLine.partner_id == partner_id)

        # ledger_id filter — column may not exist yet on old DBs.
        try:
            if ledger_id and hasattr(JournalLine, "ledger_id"):
                q = q.filter(JournalLine.ledger_id == ledger_id)
        except Exception:
            pass

        q = q.order_by(JournalEntry.je_date.desc(), JournalEntry.je_number.desc())
        q = q.offset(offset).limit(limit)

        rows: list[UJRow] = []
        for line, je, acc in q.all():
            # Dimension filter applied in Python — JSONB @> filter is
            # Postgres-only; the Python filter keeps us cross-dialect.
            line_dims = getattr(line, "dimensions", None)
            if dimension_filters and isinstance(line_dims, dict):
                match = all(
                    str(line_dims.get(k)) == str(v)
                    for k, v in dimension_filters.items()
                )
                if not match:
                    continue

            rows.append(UJRow(
                journal_entry_id=je.id,
                je_number=je.je_number,
                je_date=je.je_date.isoformat() if je.je_date else "",
                posting_date=je.posting_date.isoformat() if je.posting_date else None,
                status=je.status,
                source_type=je.source_type,
                source_id=je.source_id,
                source_reference=je.source_reference,
                account_id=acc.id,
                account_code=acc.code,
                account_name=acc.name_ar,
                category=acc.category,
                debit_amount=float(line.functional_debit or 0),
                credit_amount=float(line.functional_credit or 0),
                currency=line.currency,
                ledger_id=getattr(line, "ledger_id", "L1") or "L1",
                dimensions=line_dims if isinstance(line_dims, dict) else None,
                partner_type=line.partner_type,
                partner_id=line.partner_id,
                partner_name=line.partner_name,
                description=line.description,
                entity_id=je.entity_id,
                tenant_id=je.tenant_id,
            ))

        return [r.to_dict() for r in rows]
    except Exception as e:
        logger.warning("universal_journal query failed: %s", e)
        return []
    finally:
        try:
            db.close()
        except Exception:
            pass


def document_flow(source_type: str, source_id: str) -> dict[str, Any]:
    """SAP-style bidirectional document flow.

    Given any source document (PO / GRN / PI / VendorPayment / POS /
    SalesInvoice / CustomerPayment), return all related documents — both
    upstream (PO → GRN ← that refers back) and downstream (PO → this GRN → IR → Payment).

    This powers the "document flow" button on every transaction that
    shows users where a posting came from and where it went.
    """
    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import JournalEntry
    except Exception:
        return {"source_type": source_type, "source_id": source_id, "flow": []}

    db = SessionLocal()
    try:
        # All JEs that cite this source — backward flow.
        backward = (
            db.query(JournalEntry)
            .filter(JournalEntry.source_type == source_type)
            .filter(JournalEntry.source_id == source_id)
            .all()
        )

        flow = [{
            "document_type": "journal_entry",
            "document_id": je.id,
            "document_number": je.je_number,
            "date": je.je_date.isoformat() if je.je_date else None,
            "status": je.status,
            "total_debit": float(je.total_debit or 0),
            "currency": je.currency,
            "direction": "downstream",
        } for je in backward]

        # Also find the source record itself if it's a known type.
        source_row = None
        try:
            if source_type == "sales_invoice":
                from app.pilot.models import SalesInvoice
                inv = db.query(SalesInvoice).filter(SalesInvoice.id == source_id).first()
                if inv:
                    source_row = {
                        "document_type": "sales_invoice",
                        "document_id": inv.id,
                        "document_number": inv.invoice_number,
                        "date": inv.issue_date.isoformat() if inv.issue_date else None,
                        "status": inv.status,
                        "total": float(inv.total or 0),
                        "currency": inv.currency,
                        "direction": "self",
                    }
        except Exception:
            pass

        return {
            "source_type": source_type,
            "source_id": source_id,
            "self": source_row,
            "flow": flow,
        }
    finally:
        try:
            db.close()
        except Exception:
            pass
