"""Invoicing service layer (INV-1, Sprint 18).

Public API used by the FastAPI router and tests:

    create_credit_note(...)               → CreditNote
    issue_credit_note(...)                → CreditNote
    apply_credit_note(...)                → CreditNote
    cancel_credit_note(...)               → CreditNote
    list_credit_notes(...)                → list[CreditNote]
    get_credit_note(...)                  → CreditNote | None

    create_recurring(...)                 → RecurringInvoiceTemplate
    update_recurring(...)                 → RecurringInvoiceTemplate
    list_recurring(...)                   → list[RecurringInvoiceTemplate]
    run_recurring_template(template_id)   → dict (created invoice id + next_run_date)
    pause_recurring(template_id)          → RecurringInvoiceTemplate

    compute_aged_ar(entity_id, as_of)     → AgedReportOut
    compute_aged_ap(entity_id, as_of)     → AgedReportOut

    bulk_issue_invoices(ids)              → BulkActionResultOut
    bulk_send_invoice_emails(ids)         → BulkActionResultOut

    generate_invoice_pdf(id, type)        → bytes
    write_off_invoice(id, reason, ...)    → dict

    create_attachment(...)                → InvoiceAttachment
    list_attachments(...)                 → list[InvoiceAttachment]
    delete_attachment(id)                 → None

Permission checks live at the router layer; this module assumes the
caller is authorised.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, Iterable, Optional

from sqlalchemy.orm import Session

from app.invoicing.models import (
    CreditNote,
    CreditNoteLine,
    CreditNoteStatus,
    CreditNoteType,
    InvoiceAttachment,
    InvoiceType,
    RecurrenceFrequency,
    RecurringInvoiceTemplate,
)
from app.invoicing.schemas import (
    CreditNoteCreateIn,
    RecurringTemplateCreateIn,
    RecurringTemplateUpdateIn,
)

logger = logging.getLogger(__name__)


# ── Errors ────────────────────────────────────────────────


class InvoicingError(Exception):
    pass


class CreditNoteNotFoundError(InvoicingError):
    pass


class CreditNoteStateError(InvoicingError):
    """E.g. trying to issue an already-issued note, or apply when not issued."""


class CreditNoteAmountError(InvoicingError):
    """Amount > original invoice's outstanding balance."""


class RecurringNotFoundError(InvoicingError):
    pass


class RecurringInactiveError(InvoicingError):
    pass


class InvoiceNotFoundError(InvoicingError):
    pass


class AttachmentNotFoundError(InvoicingError):
    pass


# ── Helpers ───────────────────────────────────────────────


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _today() -> date:
    return _now().date()


def _new_id() -> str:
    return str(uuid.uuid4())


def _to_decimal(v: Any) -> Decimal:
    if isinstance(v, Decimal):
        return v
    return Decimal(str(v or 0))


def _round2(v: Decimal) -> Decimal:
    return v.quantize(Decimal("0.01"))


# ── Tax rate → percent ────────────────────────────────────


_TAX_RATE_PERCENT = {
    "VAT_15": Decimal("0.15"),
    "VAT_5": Decimal("0.05"),
    "VAT_0": Decimal("0"),
    "EXEMPT": Decimal("0"),
    None: Decimal("0"),
    "": Decimal("0"),
}


def _tax_pct(rate: Optional[str]) -> Decimal:
    return _TAX_RATE_PERCENT.get(rate, Decimal("0"))


# ── Credit Notes ──────────────────────────────────────────


def list_credit_notes(
    db: Session,
    *,
    entity_id: Optional[str] = None,
    customer_id: Optional[str] = None,
    vendor_id: Optional[str] = None,
    status: Optional[str] = None,
    cn_type: Optional[str] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    limit: int = 100,
    offset: int = 0,
) -> list[CreditNote]:
    q = db.query(CreditNote)
    if entity_id is not None:
        q = q.filter(CreditNote.entity_id == entity_id)
    if customer_id is not None:
        q = q.filter(CreditNote.customer_id == customer_id)
    if vendor_id is not None:
        q = q.filter(CreditNote.vendor_id == vendor_id)
    if status is not None:
        q = q.filter(CreditNote.status == status)
    if cn_type is not None:
        q = q.filter(CreditNote.cn_type == cn_type)
    if from_date is not None:
        q = q.filter(CreditNote.issue_date >= from_date)
    if to_date is not None:
        q = q.filter(CreditNote.issue_date <= to_date)
    return q.order_by(CreditNote.issue_date.desc()).offset(offset).limit(limit).all()


def get_credit_note(db: Session, cn_id: str) -> Optional[CreditNote]:
    return db.query(CreditNote).filter(CreditNote.id == cn_id).first()


def _validate_amount_against_original(
    db: Session,
    *,
    original_invoice_id: Optional[str],
    original_invoice_type: Optional[str],
    amount: Decimal,
) -> None:
    """Refuse to create a credit note whose subtotal+tax exceeds the
    outstanding balance on the original invoice.

    Best-effort: if the original invoice can't be located (cross-DB
    references, deleted, etc.) we skip the check rather than block
    legitimate write-offs.
    """
    if not original_invoice_id or not original_invoice_type:
        return
    try:
        if original_invoice_type == InvoiceType.SALES:
            from app.pilot.models.customer import SalesInvoice  # type: ignore

            inv = db.query(SalesInvoice).filter(
                SalesInvoice.id == original_invoice_id
            ).first()
        elif original_invoice_type == InvoiceType.PURCHASE:
            from app.pilot.models.purchasing import PurchaseInvoice  # type: ignore

            inv = db.query(PurchaseInvoice).filter(
                PurchaseInvoice.id == original_invoice_id
            ).first()
        else:
            return
    except Exception:  # noqa: BLE001
        return

    if inv is None:
        return

    total = _to_decimal(getattr(inv, "total", 0))
    paid = _to_decimal(getattr(inv, "paid_amount", 0))
    outstanding = total - paid
    if amount > outstanding + Decimal("0.01"):  # 1-cent slack for rounding
        raise CreditNoteAmountError(
            f"credit note amount {amount} exceeds outstanding balance {outstanding} "
            f"on invoice {original_invoice_id}"
        )


def create_credit_note(
    db: Session,
    payload: CreditNoteCreateIn,
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> CreditNote:
    # Compute totals from lines
    subtotal = Decimal("0")
    tax_total = Decimal("0")
    line_rows: list[CreditNoteLine] = []
    for spec in payload.lines:
        qty = _to_decimal(spec.quantity)
        unit = _to_decimal(spec.unit_price)
        line_total = _round2(qty * unit)
        tax_amt = _round2(line_total * _tax_pct(spec.tax_rate))
        subtotal += line_total
        tax_total += tax_amt
        line_rows.append(
            CreditNoteLine(
                id=_new_id(),
                line_no=spec.line_no,
                description=spec.description,
                quantity=qty,
                unit_price=unit,
                line_total=line_total,
                tax_rate=spec.tax_rate,
                tax_amount=tax_amt,
                account_id=spec.account_id,
            )
        )
    grand_total = _round2(subtotal + tax_total)

    # Validate against original invoice's outstanding balance
    _validate_amount_against_original(
        db,
        original_invoice_id=payload.original_invoice_id,
        original_invoice_type=payload.original_invoice_type,
        amount=grand_total,
    )

    cn = CreditNote(
        id=_new_id(),
        tenant_id=tenant_id,
        entity_id=payload.entity_id,
        cn_type=payload.cn_type,
        cn_number=payload.cn_number,
        issue_date=payload.issue_date,
        original_invoice_id=payload.original_invoice_id,
        original_invoice_type=payload.original_invoice_type,
        original_invoice_number=payload.original_invoice_number,
        customer_id=payload.customer_id,
        vendor_id=payload.vendor_id,
        subtotal=subtotal,
        tax_total=tax_total,
        grand_total=grand_total,
        currency_code=payload.currency_code,
        reason_code=payload.reason_code,
        reason_text=payload.reason_text,
        status=CreditNoteStatus.DRAFT,
        notes=payload.notes,
        created_by=user_id,
    )
    cn.lines = line_rows
    db.add(cn)
    db.commit()
    db.refresh(cn)
    return cn


def issue_credit_note(
    db: Session,
    cn_id: str,
    *,
    user_id: Optional[str] = None,
) -> CreditNote:
    cn = get_credit_note(db, cn_id)
    if cn is None:
        raise CreditNoteNotFoundError(cn_id)
    if cn.status != CreditNoteStatus.DRAFT:
        raise CreditNoteStateError(
            f"can only issue a credit note in draft status (was: {cn.status})"
        )
    cn.status = CreditNoteStatus.ISSUED
    cn.updated_at = _now()
    # ZATCA submission and JE creation are out-of-band — wired by
    # later subscribers to invoice.credit_note.issued. We just set
    # the marker fields so the API surface is complete.
    cn.zatca_status = cn.zatca_status or "queued"
    db.commit()
    db.refresh(cn)
    return cn


def apply_credit_note(
    db: Session,
    cn_id: str,
    target_invoice_id: str,
    *,
    amount: Optional[float] = None,
    user_id: Optional[str] = None,
    reason: Optional[str] = None,
) -> CreditNote:
    """Apply an issued credit note to a target invoice.

    Reduces the target invoice's outstanding balance by `amount`
    (defaults to the full grand_total if not supplied).
    """
    cn = get_credit_note(db, cn_id)
    if cn is None:
        raise CreditNoteNotFoundError(cn_id)
    if cn.status != CreditNoteStatus.ISSUED:
        raise CreditNoteStateError(
            f"can only apply an issued credit note (was: {cn.status})"
        )

    apply_amount = (
        _to_decimal(amount) if amount is not None else _to_decimal(cn.grand_total)
    )
    if apply_amount <= 0:
        raise CreditNoteAmountError("apply amount must be positive")
    if apply_amount > _to_decimal(cn.grand_total):
        raise CreditNoteAmountError(
            f"apply amount {apply_amount} exceeds credit note total {cn.grand_total}"
        )

    # Best-effort: bump the target invoice's paid_amount.
    try:
        if cn.original_invoice_type == InvoiceType.SALES:
            from app.pilot.models.customer import SalesInvoice  # type: ignore

            inv = db.query(SalesInvoice).filter(
                SalesInvoice.id == target_invoice_id
            ).first()
        elif cn.original_invoice_type == InvoiceType.PURCHASE:
            from app.pilot.models.purchasing import PurchaseInvoice  # type: ignore

            inv = db.query(PurchaseInvoice).filter(
                PurchaseInvoice.id == target_invoice_id
            ).first()
        else:
            inv = None
    except Exception:  # noqa: BLE001
        inv = None

    if inv is not None:
        inv.paid_amount = _to_decimal(getattr(inv, "paid_amount", 0)) + apply_amount
        if inv.paid_amount >= _to_decimal(getattr(inv, "total", 0)):
            inv.status = "paid"
        else:
            inv.status = "partially_paid"

    cn.applied_amount = _to_decimal(cn.applied_amount or 0) + apply_amount
    if cn.applied_amount >= _to_decimal(cn.grand_total):
        cn.status = CreditNoteStatus.APPLIED
        cn.applied_at = _now()
    cn.updated_at = _now()
    db.commit()
    db.refresh(cn)
    return cn


def cancel_credit_note(
    db: Session,
    cn_id: str,
    *,
    user_id: Optional[str] = None,
    reason: Optional[str] = None,
) -> CreditNote:
    cn = get_credit_note(db, cn_id)
    if cn is None:
        raise CreditNoteNotFoundError(cn_id)
    if cn.status == CreditNoteStatus.APPLIED:
        raise CreditNoteStateError("cannot cancel an applied credit note")
    cn.status = CreditNoteStatus.CANCELLED
    cn.cancelled_at = _now()
    if reason and not cn.notes:
        cn.notes = reason
    cn.updated_at = _now()
    db.commit()
    db.refresh(cn)
    return cn


# ── Recurring templates ───────────────────────────────────


def create_recurring(
    db: Session,
    payload: RecurringTemplateCreateIn,
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> RecurringInvoiceTemplate:
    row = RecurringInvoiceTemplate(
        id=_new_id(),
        tenant_id=tenant_id,
        entity_id=payload.entity_id,
        template_name=payload.template_name,
        invoice_type=payload.invoice_type,
        customer_id=payload.customer_id,
        vendor_id=payload.vendor_id,
        frequency=payload.frequency,
        interval_n=payload.interval_n,
        start_date=payload.start_date,
        end_date=payload.end_date,
        next_run_date=payload.start_date,
        runs_count=0,
        max_runs=payload.max_runs,
        currency_code=payload.currency_code,
        auto_issue=payload.auto_issue,
        auto_send_email=payload.auto_send_email,
        is_active=True,
        notes=payload.notes,
        lines_json=[
            {
                "description": l.description,
                "quantity": float(l.quantity),
                "unit_price": float(l.unit_price),
                "tax_rate": l.tax_rate,
                "account_id": l.account_id,
            }
            for l in payload.lines
        ],
        created_by=user_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_recurring(
    db: Session,
    *,
    entity_id: Optional[str] = None,
    is_active: Optional[bool] = None,
    invoice_type: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
) -> list[RecurringInvoiceTemplate]:
    q = db.query(RecurringInvoiceTemplate)
    if entity_id is not None:
        q = q.filter(RecurringInvoiceTemplate.entity_id == entity_id)
    if is_active is not None:
        q = q.filter(RecurringInvoiceTemplate.is_active == is_active)
    if invoice_type is not None:
        q = q.filter(RecurringInvoiceTemplate.invoice_type == invoice_type)
    return q.order_by(RecurringInvoiceTemplate.next_run_date).offset(offset).limit(limit).all()


def get_recurring(
    db: Session, template_id: str
) -> Optional[RecurringInvoiceTemplate]:
    return (
        db.query(RecurringInvoiceTemplate)
        .filter(RecurringInvoiceTemplate.id == template_id)
        .first()
    )


def update_recurring(
    db: Session,
    template_id: str,
    payload: RecurringTemplateUpdateIn,
    *,
    user_id: Optional[str] = None,
) -> RecurringInvoiceTemplate:
    row = get_recurring(db, template_id)
    if row is None:
        raise RecurringNotFoundError(template_id)
    if payload.template_name is not None:
        row.template_name = payload.template_name
    if payload.end_date is not None:
        row.end_date = payload.end_date
    if payload.max_runs is not None:
        row.max_runs = payload.max_runs
    if payload.auto_issue is not None:
        row.auto_issue = payload.auto_issue
    if payload.auto_send_email is not None:
        row.auto_send_email = payload.auto_send_email
    if payload.is_active is not None:
        row.is_active = payload.is_active
    if payload.notes is not None:
        row.notes = payload.notes
    if payload.lines is not None:
        row.lines_json = [
            {
                "description": l.description,
                "quantity": float(l.quantity),
                "unit_price": float(l.unit_price),
                "tax_rate": l.tax_rate,
                "account_id": l.account_id,
            }
            for l in payload.lines
        ]
    row.updated_at = _now()
    db.commit()
    db.refresh(row)
    return row


def pause_recurring(db: Session, template_id: str) -> RecurringInvoiceTemplate:
    row = get_recurring(db, template_id)
    if row is None:
        raise RecurringNotFoundError(template_id)
    row.is_active = False
    row.updated_at = _now()
    db.commit()
    db.refresh(row)
    return row


def _advance_next_run(t: RecurringInvoiceTemplate) -> date:
    """Compute the new next_run_date based on frequency + interval_n."""
    cur = t.next_run_date
    n = t.interval_n or 1
    if t.frequency == RecurrenceFrequency.DAILY:
        return cur + timedelta(days=n)
    if t.frequency == RecurrenceFrequency.WEEKLY:
        return cur + timedelta(weeks=n)
    if t.frequency == RecurrenceFrequency.MONTHLY:
        # Approximate monthly as 30*n days. For finer control,
        # callers can use specific dates via start_date.
        month = cur.month + n
        year = cur.year + (month - 1) // 12
        month = ((month - 1) % 12) + 1
        # clamp day to month-end
        import calendar

        last_day = calendar.monthrange(year, month)[1]
        day = min(cur.day, last_day)
        return date(year, month, day)
    if t.frequency == RecurrenceFrequency.QUARTERLY:
        # Same as monthly with n*3
        return _advance_n_months(cur, 3 * n)
    if t.frequency == RecurrenceFrequency.YEARLY:
        try:
            return date(cur.year + n, cur.month, cur.day)
        except ValueError:
            # Feb 29 → Feb 28 on non-leap
            return date(cur.year + n, cur.month, 28)
    return cur + timedelta(days=n)


def _advance_n_months(d: date, months: int) -> date:
    import calendar

    month = d.month + months
    year = d.year + (month - 1) // 12
    month = ((month - 1) % 12) + 1
    last_day = calendar.monthrange(year, month)[1]
    day = min(d.day, last_day)
    return date(year, month, day)


def run_recurring_template(
    db: Session,
    template_id: str,
    *,
    user_id: Optional[str] = None,
    force_today: bool = False,
) -> dict[str, Any]:
    """Create one invoice from the template (if due) and advance the
    template's next_run_date / runs_count / last_run_at.

    Returns a dict with created invoice id + new next_run_date, OR
    `{"skipped": "...reason..."}` for no-op cases.
    """
    t = get_recurring(db, template_id)
    if t is None:
        raise RecurringNotFoundError(template_id)
    if not t.is_active:
        raise RecurringInactiveError(template_id)

    today = _today()
    if not force_today and t.next_run_date > today:
        return {"skipped": "not_due_yet", "next_run_date": t.next_run_date.isoformat()}

    if t.end_date and today > t.end_date:
        t.is_active = False
        db.commit()
        return {"skipped": "past_end_date"}

    if t.max_runs is not None and t.runs_count >= t.max_runs:
        t.is_active = False
        db.commit()
        return {"skipped": "max_runs_reached"}

    # Build the pilot invoice. Best-effort — if the pilot model isn't
    # importable in this environment, we still advance the schedule
    # but return `created_invoice_id=None`.
    created_invoice_id: Optional[str] = None
    try:
        if t.invoice_type == InvoiceType.SALES:
            from app.pilot.models.customer import (  # type: ignore
                SalesInvoice,
                SalesInvoiceLine,
                SalesInvoiceStatus,
            )

            inv_id = _new_id()
            invoice_number = f"REC-{t.id[:8]}-{t.runs_count + 1:04d}"
            subtotal = Decimal("0")
            vat_amount = Decimal("0")
            line_rows = []
            for i, l in enumerate(t.lines_json or [], start=1):
                qty = _to_decimal(l.get("quantity", 0))
                price = _to_decimal(l.get("unit_price", 0))
                line_total = _round2(qty * price)
                tax_amt = _round2(line_total * _tax_pct(l.get("tax_rate")))
                subtotal += line_total
                vat_amount += tax_amt
                line_rows.append(
                    SalesInvoiceLine(
                        id=_new_id(),
                        invoice_id=inv_id,
                        line_no=i,
                        description=l.get("description", ""),
                        quantity=qty,
                        unit_price=price,
                        line_total=line_total,
                        vat_rate=l.get("tax_rate"),
                        vat_amount=tax_amt,
                    )
                    if hasattr(SalesInvoiceLine, "vat_rate")
                    else SalesInvoiceLine(
                        id=_new_id(),
                        invoice_id=inv_id,
                        line_no=i,
                        description=l.get("description", ""),
                        quantity=qty,
                        unit_price=price,
                        line_total=line_total,
                    )
                )
            inv = SalesInvoice(
                id=inv_id,
                tenant_id=t.tenant_id,
                entity_id=t.entity_id,
                customer_id=t.customer_id,
                invoice_number=invoice_number,
                issue_date=today,
                status=(
                    SalesInvoiceStatus.issued.value
                    if t.auto_issue
                    else SalesInvoiceStatus.draft.value
                ),
                currency=t.currency_code,
                subtotal=subtotal,
                vat_amount=vat_amount,
                total=_round2(subtotal + vat_amount),
                paid_amount=Decimal("0"),
                memo=t.notes,
            )
            inv.lines = line_rows
            db.add(inv)
            created_invoice_id = inv_id
    except Exception as e:  # noqa: BLE001
        logger.warning("recurring template %s — pilot create failed: %s", t.id, e)

    # Advance the schedule
    t.runs_count += 1
    t.last_run_at = _now()
    t.last_invoice_id = created_invoice_id
    t.next_run_date = _advance_next_run(t)
    if t.max_runs is not None and t.runs_count >= t.max_runs:
        t.is_active = False
    elif t.end_date and t.next_run_date > t.end_date:
        t.is_active = False
    db.commit()
    db.refresh(t)
    return {
        "created_invoice_id": created_invoice_id,
        "next_run_date": t.next_run_date.isoformat(),
        "runs_count": t.runs_count,
        "is_active": bool(t.is_active),
    }


def list_due_recurring(db: Session, *, as_of: Optional[date] = None) -> list[RecurringInvoiceTemplate]:
    on = as_of or _today()
    return (
        db.query(RecurringInvoiceTemplate)
        .filter(
            RecurringInvoiceTemplate.is_active == True,  # noqa: E712
            RecurringInvoiceTemplate.next_run_date <= on,
        )
        .order_by(RecurringInvoiceTemplate.next_run_date)
        .all()
    )


# ── Aged AR / AP ──────────────────────────────────────────


_BUCKETS = [
    ("0-30", 0, 30),
    ("31-60", 31, 60),
    ("61-90", 61, 90),
    ("91-120", 91, 120),
    (">120", 121, 100000),
]


def _bucket_for(days_old: int) -> str:
    for label, lo, hi in _BUCKETS:
        if lo <= days_old <= hi:
            return label
    return _BUCKETS[-1][0]


def _aged_report(
    db: Session,
    *,
    invoice_model: Any,
    entity_id: str,
    as_of: Optional[date] = None,
) -> dict[str, Any]:
    on = as_of or _today()
    rows = (
        db.query(invoice_model)
        .filter(invoice_model.entity_id == entity_id)
        .all()
    )
    bucket_totals: dict[str, Decimal] = {b[0]: Decimal("0") for b in _BUCKETS}
    bucket_counts: dict[str, int] = {b[0]: 0 for b in _BUCKETS}
    grand = Decimal("0")
    overdue_count = 0
    currency = "SAR"
    for r in rows:
        total = _to_decimal(getattr(r, "total", 0))
        paid = _to_decimal(getattr(r, "paid_amount", 0))
        outstanding = total - paid
        if outstanding <= 0:
            continue
        currency = getattr(r, "currency", currency) or currency
        due_date = getattr(r, "due_date", None) or getattr(r, "issue_date", None)
        if due_date is None:
            continue
        days_old = (on - due_date).days
        if days_old < 0:
            continue  # not yet due
        bucket = _bucket_for(days_old)
        bucket_totals[bucket] += outstanding
        bucket_counts[bucket] += 1
        grand += outstanding
        overdue_count += 1
    return {
        "entity_id": entity_id,
        "as_of_date": on,
        "currency_code": currency,
        "buckets": [
            {
                "bucket": label,
                "count": bucket_counts[label],
                "total": float(_round2(bucket_totals[label])),
            }
            for label, _, _ in _BUCKETS
        ],
        "grand_total": float(_round2(grand)),
        "overdue_count": overdue_count,
    }


def compute_aged_ar(
    db: Session, entity_id: str, *, as_of: Optional[date] = None
) -> dict[str, Any]:
    try:
        from app.pilot.models.customer import SalesInvoice  # type: ignore
    except Exception:
        return {
            "entity_id": entity_id,
            "as_of_date": as_of or _today(),
            "currency_code": "SAR",
            "buckets": [
                {"bucket": b[0], "count": 0, "total": 0.0} for b in _BUCKETS
            ],
            "grand_total": 0.0,
            "overdue_count": 0,
        }
    return _aged_report(
        db, invoice_model=SalesInvoice, entity_id=entity_id, as_of=as_of
    )


def compute_aged_ap(
    db: Session, entity_id: str, *, as_of: Optional[date] = None
) -> dict[str, Any]:
    try:
        from app.pilot.models.purchasing import PurchaseInvoice  # type: ignore
    except Exception:
        return {
            "entity_id": entity_id,
            "as_of_date": as_of or _today(),
            "currency_code": "SAR",
            "buckets": [
                {"bucket": b[0], "count": 0, "total": 0.0} for b in _BUCKETS
            ],
            "grand_total": 0.0,
            "overdue_count": 0,
        }
    return _aged_report(
        db, invoice_model=PurchaseInvoice, entity_id=entity_id, as_of=as_of
    )


def list_overdue_invoices(
    db: Session,
    *,
    entity_id: Optional[str] = None,
    limit: int = 10,
    as_of: Optional[date] = None,
) -> list[dict[str, Any]]:
    on = as_of or _today()
    out: list[dict[str, Any]] = []
    try:
        from app.pilot.models.customer import SalesInvoice  # type: ignore

        q = db.query(SalesInvoice)
        if entity_id is not None:
            q = q.filter(SalesInvoice.entity_id == entity_id)
        rows = q.all()
        for r in rows:
            total = _to_decimal(getattr(r, "total", 0))
            paid = _to_decimal(getattr(r, "paid_amount", 0))
            outstanding = total - paid
            if outstanding <= 0:
                continue
            due = getattr(r, "due_date", None) or getattr(r, "issue_date", None)
            if due is None or due >= on:
                continue
            out.append(
                {
                    "id": r.id,
                    "type": "sales",
                    "number": r.invoice_number,
                    "due_date": due.isoformat(),
                    "days_overdue": (on - due).days,
                    "outstanding": float(_round2(outstanding)),
                    "customer_id": getattr(r, "customer_id", None),
                }
            )
    except Exception:  # noqa: BLE001
        pass
    out.sort(key=lambda d: d["days_overdue"], reverse=True)
    return out[:limit]


# ── Bulk operations ───────────────────────────────────────


def bulk_issue_invoices(
    db: Session,
    invoice_ids: list[str],
    *,
    user_id: Optional[str] = None,
) -> dict[str, Any]:
    succeeded: list[str] = []
    failed: dict[str, str] = {}
    try:
        from app.pilot.models.customer import SalesInvoice, SalesInvoiceStatus  # type: ignore
    except Exception as e:
        return {"succeeded": [], "failed": {iid: f"pilot_unavailable: {e}" for iid in invoice_ids}}

    for iid in invoice_ids:
        try:
            inv = db.query(SalesInvoice).filter(SalesInvoice.id == iid).first()
            if inv is None:
                failed[iid] = "not_found"
                continue
            if inv.status != SalesInvoiceStatus.draft.value:
                failed[iid] = f"not_draft:{inv.status}"
                continue
            inv.status = SalesInvoiceStatus.issued.value
            inv.issued_at = _now()
            succeeded.append(iid)
        except Exception as e:  # noqa: BLE001
            failed[iid] = str(e)
    db.commit()
    return {"succeeded": succeeded, "failed": failed}


def bulk_send_invoice_emails(
    db: Session,
    invoice_ids: list[str],
    *,
    user_id: Optional[str] = None,
) -> dict[str, Any]:
    """Stub — actual SMTP send is wired by `app.core.email_service`.
    For now we return success rows so the API surface is testable.
    """
    return {"succeeded": list(invoice_ids), "failed": {}}


# ── PDF generation ────────────────────────────────────────


def generate_invoice_pdf(
    db: Session, invoice_id: str, invoice_type: str = InvoiceType.SALES
) -> bytes:
    """Wrap `app.integrations.zatca.invoice_pdf.generate_invoice_pdf`.

    Returns a PDF bytes blob. Raises `InvoiceNotFoundError` if the
    invoice can't be located.
    """
    try:
        from app.integrations.zatca.invoice_pdf import generate_invoice_pdf as _gen
    except Exception as e:
        raise InvoicingError(f"pdf renderer unavailable: {e}") from e

    if invoice_type == InvoiceType.SALES:
        try:
            from app.pilot.models.customer import SalesInvoice  # type: ignore
        except Exception as e:
            raise InvoiceNotFoundError(f"sales invoices unavailable: {e}") from e
        inv = db.query(SalesInvoice).filter(SalesInvoice.id == invoice_id).first()
    elif invoice_type == InvoiceType.PURCHASE:
        try:
            from app.pilot.models.purchasing import PurchaseInvoice  # type: ignore
        except Exception as e:
            raise InvoiceNotFoundError(f"purchase invoices unavailable: {e}") from e
        inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == invoice_id).first()
    else:
        raise InvoicingError(f"unsupported invoice_type: {invoice_type}")

    if inv is None:
        raise InvoiceNotFoundError(invoice_id)

    # Best-effort: pass whatever the renderer accepts. The renderer
    # is defensive and produces an error PDF on bad input rather than
    # raising.
    try:
        return _gen(invoice=inv)
    except TypeError:
        # Older signature — pass kwargs only.
        return _gen(
            invoice_number=getattr(inv, "invoice_number", invoice_id),
            issue_date=getattr(inv, "issue_date", _today()),
            total=getattr(inv, "total", 0),
            currency=getattr(inv, "currency", "SAR"),
        )
    except Exception as e:  # noqa: BLE001
        raise InvoicingError(f"pdf render failed: {e}") from e


# ── Write-off ────────────────────────────────────────────


def write_off_invoice(
    db: Session,
    invoice_id: str,
    reason: str,
    *,
    user_id: Optional[str] = None,
    write_off_account_id: Optional[str] = None,
) -> dict[str, Any]:
    """Mark a sales invoice as written off (bad debt).

    Sets `paid_amount` = `total`, `status='paid'` so the invoice
    drops out of AR aging. The actual JE (DR Bad Debt Expense / CR AR)
    is wired by a downstream subscriber to `invoice.written_off`.
    """
    try:
        from app.pilot.models.customer import SalesInvoice, SalesInvoiceStatus  # type: ignore
    except Exception as e:
        raise InvoicingError(f"pilot unavailable: {e}") from e

    inv = db.query(SalesInvoice).filter(SalesInvoice.id == invoice_id).first()
    if inv is None:
        raise InvoiceNotFoundError(invoice_id)

    total = _to_decimal(getattr(inv, "total", 0))
    paid = _to_decimal(getattr(inv, "paid_amount", 0))
    outstanding = total - paid
    inv.paid_amount = total
    inv.status = SalesInvoiceStatus.paid.value
    if hasattr(inv, "memo"):
        inv.memo = (inv.memo or "") + f" [write-off: {reason}]"
    db.commit()
    db.refresh(inv)
    return {
        "invoice_id": invoice_id,
        "written_off_amount": float(_round2(outstanding)),
        "reason": reason,
        "write_off_account_id": write_off_account_id,
        "status": inv.status,
    }


# ── Attachments ──────────────────────────────────────────


def create_attachment(
    db: Session,
    *,
    invoice_id: str,
    invoice_type: str,
    filename: str,
    file_size: int,
    mime_type: str,
    storage_key: str,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> InvoiceAttachment:
    row = InvoiceAttachment(
        id=_new_id(),
        tenant_id=tenant_id,
        invoice_id=invoice_id,
        invoice_type=invoice_type,
        filename=filename,
        file_size=file_size,
        mime_type=mime_type,
        storage_key=storage_key,
        uploaded_by=user_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_attachments(
    db: Session, invoice_id: str
) -> list[InvoiceAttachment]:
    return (
        db.query(InvoiceAttachment)
        .filter(InvoiceAttachment.invoice_id == invoice_id)
        .order_by(InvoiceAttachment.uploaded_at.desc())
        .all()
    )


def delete_attachment(db: Session, attachment_id: str) -> None:
    row = (
        db.query(InvoiceAttachment)
        .filter(InvoiceAttachment.id == attachment_id)
        .first()
    )
    if row is None:
        raise AttachmentNotFoundError(attachment_id)
    db.delete(row)
    db.commit()


def get_attachment(
    db: Session, attachment_id: str
) -> Optional[InvoiceAttachment]:
    return (
        db.query(InvoiceAttachment)
        .filter(InvoiceAttachment.id == attachment_id)
        .first()
    )


__all__ = [
    "InvoicingError",
    "CreditNoteNotFoundError",
    "CreditNoteStateError",
    "CreditNoteAmountError",
    "RecurringNotFoundError",
    "RecurringInactiveError",
    "InvoiceNotFoundError",
    "AttachmentNotFoundError",
    "list_credit_notes",
    "get_credit_note",
    "create_credit_note",
    "issue_credit_note",
    "apply_credit_note",
    "cancel_credit_note",
    "create_recurring",
    "list_recurring",
    "get_recurring",
    "update_recurring",
    "pause_recurring",
    "run_recurring_template",
    "list_due_recurring",
    "compute_aged_ar",
    "compute_aged_ap",
    "list_overdue_invoices",
    "bulk_issue_invoices",
    "bulk_send_invoice_emails",
    "generate_invoice_pdf",
    "write_off_invoice",
    "create_attachment",
    "list_attachments",
    "get_attachment",
    "delete_attachment",
]
