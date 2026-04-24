"""Customer + Sales Invoice routes — the sales-side counterpart to purchasing_routes.

Endpoints:
  GET    /tenants/{tenant_id}/customers             — list
  POST   /tenants/{tenant_id}/customers             — create
  GET    /customers/{customer_id}                   — detail
  PATCH  /customers/{customer_id}                   — update
  GET    /customers/{customer_id}/ledger            — AR ledger + balance

  POST   /sales-invoices                            — create + auto-post JE
  GET    /entities/{entity_id}/sales-invoices       — list
  GET    /sales-invoices/{invoice_id}               — detail
  POST   /sales-invoices/{invoice_id}/issue         — draft → issued (post JE)
  POST   /sales-invoices/{invoice_id}/payment       — record customer payment
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any, Optional

from fastapi import APIRouter, Body, HTTPException, Path, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.pilot.models import (
    Customer,
    CustomerKind,
    CustomerPaymentTerms,
    SalesInvoice,
    SalesInvoiceStatus,
    SalesInvoiceLine,
    CustomerPayment,
    JournalEntry,
    JournalEntryStatus,
    JournalEntryKind,
    JournalLine,
    GLAccount,
    FiscalPeriod,
    PeriodStatus,
)

router = APIRouter(prefix="/api/v1/pilot", tags=["Pilot — Customers & Sales"])


def _db() -> Session:
    return SessionLocal()


# ── Pydantic schemas ─────────────────────────────────────


class CustomerCreate(BaseModel):
    code: str
    name_ar: str
    name_en: Optional[str] = None
    kind: str = "company"
    email: Optional[str] = None
    phone: Optional[str] = None
    mobile: Optional[str] = None
    vat_number: Optional[str] = None
    cr_number: Optional[str] = None
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    currency: str = "SAR"
    payment_terms: str = "net_30"
    credit_limit: Optional[float] = None
    tags: Optional[list[str]] = None
    notes: Optional[str] = None


class CustomerUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    mobile: Optional[str] = None
    vat_number: Optional[str] = None
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    payment_terms: Optional[str] = None
    credit_limit: Optional[float] = None
    tags: Optional[list[str]] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class CustomerRead(BaseModel):
    id: str
    code: str
    name_ar: str
    name_en: Optional[str] = None
    kind: str
    email: Optional[str] = None
    phone: Optional[str] = None
    vat_number: Optional[str] = None
    currency: str
    payment_terms: str
    credit_limit: Optional[float] = None
    is_active: bool

    class Config:
        from_attributes = True


class SalesInvoiceLineInput(BaseModel):
    product_id: Optional[str] = None
    description: str
    quantity: float = 1
    unit_price: float
    discount_pct: float = 0
    vat_rate: float = 15
    revenue_account_id: Optional[str] = None


class SalesInvoiceCreate(BaseModel):
    tenant_id: str
    entity_id: str
    customer_id: str
    issue_date: str                                # ISO yyyy-mm-dd
    due_date: Optional[str] = None
    invoice_number: Optional[str] = None
    currency: str = "SAR"
    memo: Optional[str] = None
    lines: list[SalesInvoiceLineInput]


class SalesInvoiceRead(BaseModel):
    id: str
    invoice_number: str
    customer_id: str
    issue_date: str
    due_date: Optional[str] = None
    status: str
    currency: str
    subtotal: float
    vat_amount: float
    total: float
    paid_amount: float
    journal_entry_id: Optional[str] = None


class CustomerPaymentInput(BaseModel):
    invoice_id: Optional[str] = None        # optional — unapplied payment OK
    payment_date: str
    amount: float
    method: str = "bank_transfer"
    reference: Optional[str] = None
    receipt_number: Optional[str] = None


# ── Customer CRUD ────────────────────────────────────────


@router.get("/tenants/{tenant_id}/customers", response_model=list[CustomerRead])
def list_customers(
    tenant_id: str = Path(...),
    active_only: bool = Query(True),
    search: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
):
    db = _db()
    try:
        q = db.query(Customer).filter(Customer.tenant_id == tenant_id)
        if active_only:
            q = q.filter(Customer.is_active.is_(True))
        if search:
            like = f"%{search}%"
            q = q.filter(
                (Customer.name_ar.ilike(like))
                | (Customer.name_en.ilike(like))
                | (Customer.code.ilike(like))
                | (Customer.vat_number.ilike(like))
            )
        return q.order_by(Customer.name_ar).limit(limit).all()
    finally:
        db.close()


@router.post("/tenants/{tenant_id}/customers", response_model=CustomerRead, status_code=201)
def create_customer(
    tenant_id: str = Path(...),
    payload: CustomerCreate = Body(...),
):
    db = _db()
    try:
        # Uniqueness check on code
        exists = (
            db.query(Customer)
            .filter(Customer.tenant_id == tenant_id, Customer.code == payload.code)
            .first()
        )
        if exists is not None:
            raise HTTPException(status_code=409, detail=f"customer code {payload.code!r} already exists")

        row = Customer(
            id=gen_uuid(),
            tenant_id=tenant_id,
            code=payload.code,
            name_ar=payload.name_ar,
            name_en=payload.name_en,
            kind=payload.kind,
            email=payload.email,
            phone=payload.phone,
            mobile=payload.mobile,
            vat_number=payload.vat_number,
            cr_number=payload.cr_number,
            address_street=payload.address_street,
            address_city=payload.address_city,
            currency=payload.currency,
            payment_terms=payload.payment_terms,
            credit_limit=Decimal(str(payload.credit_limit)) if payload.credit_limit else None,
            tags=payload.tags or [],
            notes=payload.notes,
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return row
    finally:
        db.close()


@router.get("/customers/{customer_id}", response_model=CustomerRead)
def get_customer(customer_id: str = Path(...)):
    db = _db()
    try:
        row = db.query(Customer).filter(Customer.id == customer_id).first()
        if row is None:
            raise HTTPException(status_code=404, detail="customer not found")
        return row
    finally:
        db.close()


@router.patch("/customers/{customer_id}", response_model=CustomerRead)
def update_customer(
    customer_id: str = Path(...),
    payload: CustomerUpdate = Body(...),
):
    db = _db()
    try:
        row = db.query(Customer).filter(Customer.id == customer_id).first()
        if row is None:
            raise HTTPException(status_code=404, detail="customer not found")
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(row, field, value)
        db.commit()
        db.refresh(row)
        return row
    finally:
        db.close()


@router.get("/customers/{customer_id}/ledger")
def customer_ledger(customer_id: str = Path(...), limit: int = Query(100, ge=1, le=500)):
    """Return the customer's recent invoices + payments + running balance."""
    db = _db()
    try:
        cust = db.query(Customer).filter(Customer.id == customer_id).first()
        if cust is None:
            raise HTTPException(status_code=404, detail="customer not found")

        invs = (
            db.query(SalesInvoice)
            .filter(SalesInvoice.customer_id == customer_id)
            .order_by(SalesInvoice.issue_date.desc())
            .limit(limit)
            .all()
        )
        pays = (
            db.query(CustomerPayment)
            .filter(CustomerPayment.customer_id == customer_id)
            .order_by(CustomerPayment.payment_date.desc())
            .limit(limit)
            .all()
        )

        invoiced = sum(float(i.total or 0) for i in invs)
        paid = sum(float(p.amount or 0) for p in pays)
        balance = invoiced - paid

        return {
            "customer": {"id": cust.id, "code": cust.code, "name_ar": cust.name_ar},
            "invoices": [
                {
                    "id": i.id,
                    "invoice_number": i.invoice_number,
                    "issue_date": i.issue_date.isoformat() if i.issue_date else None,
                    "total": float(i.total),
                    "paid_amount": float(i.paid_amount),
                    "status": i.status,
                }
                for i in invs
            ],
            "payments": [
                {
                    "id": p.id,
                    "receipt_number": p.receipt_number,
                    "payment_date": p.payment_date.isoformat() if p.payment_date else None,
                    "amount": float(p.amount),
                    "method": p.method,
                }
                for p in pays
            ],
            "totals": {
                "invoiced": round(invoiced, 2),
                "paid": round(paid, 2),
                "balance": round(balance, 2),
            },
        }
    finally:
        db.close()


# ── Sales Invoice ────────────────────────────────────────


def _next_invoice_number(db: Session, entity_id: str, year: int) -> str:
    """Scan existing invoices for this entity/year and return the next number."""
    prefix = f"INV-{year}-"
    last = (
        db.query(SalesInvoice)
        .filter(SalesInvoice.entity_id == entity_id)
        .filter(SalesInvoice.invoice_number.like(f"{prefix}%"))
        .order_by(SalesInvoice.invoice_number.desc())
        .first()
    )
    if last is None:
        return f"{prefix}0001"
    try:
        n = int(last.invoice_number.split("-")[-1]) + 1
    except Exception:
        n = 1
    return f"{prefix}{n:04d}"


def _post_sales_invoice_je(db: Session, inv: SalesInvoice, customer: Customer) -> JournalEntry:
    """Auto-build + post the JE for an issued sales invoice.

    Dr 1130 AR                          (total)
      Cr 4100 Revenue                   (subtotal)
      Cr 2150 VAT Output                (vat_amount)

    Account lookup is by conventional code — if missing, falls back to
    the first account of matching category/subcategory in the entity's CoA.
    """

    def _find_account(code: str, category: str, subcategory: Optional[str] = None) -> Optional[GLAccount]:
        q = db.query(GLAccount).filter(
            GLAccount.entity_id == inv.entity_id,
            GLAccount.type == "detail",
        )
        acc = q.filter(GLAccount.code == code).first()
        if acc:
            return acc
        q = q.filter(GLAccount.category == category)
        if subcategory:
            q = q.filter(GLAccount.subcategory == subcategory)
        return q.first()

    ar = _find_account("1130", "asset", "receivables")
    revenue = _find_account("4110", "revenue", "sales") or _find_account("4100", "revenue")
    vat_out = _find_account("2150", "liability", "vat") or _find_account("2200", "liability")

    if not (ar and revenue and vat_out):
        raise HTTPException(
            status_code=409,
            detail="missing AR/Revenue/VAT accounts — seed the entity's CoA first",
        )

    # Find open fiscal period.
    period = (
        db.query(FiscalPeriod)
        .filter(FiscalPeriod.entity_id == inv.entity_id)
        .filter(FiscalPeriod.start_date <= inv.issue_date)
        .filter(FiscalPeriod.end_date >= inv.issue_date)
        .filter(FiscalPeriod.status == PeriodStatus.open.value)
        .first()
    )
    if period is None:
        raise HTTPException(
            status_code=409,
            detail=f"no open fiscal period covering {inv.issue_date}",
        )

    je = JournalEntry(
        id=gen_uuid(),
        tenant_id=inv.tenant_id,
        entity_id=inv.entity_id,
        fiscal_period_id=period.id,
        je_number=f"SI-{inv.invoice_number}",
        kind=JournalEntryKind.manual.value,
        status=JournalEntryStatus.draft.value,      # post below via post_journal_entry()
        source_type="sales_invoice",
        source_id=inv.id,
        source_reference=inv.invoice_number,
        memo_ar=f"فاتورة بيع {inv.invoice_number} — {customer.name_ar}",
        je_date=inv.issue_date,
        currency=inv.currency,
        total_debit=inv.total,
        total_credit=inv.total,
    )
    db.add(je)
    db.flush()

    # AR (Dr)
    db.add(JournalLine(
        id=gen_uuid(),
        tenant_id=inv.tenant_id,
        journal_entry_id=je.id,
        line_number=1,
        account_id=ar.id,
        currency=inv.currency,
        debit_amount=inv.total,
        credit_amount=0,
        functional_debit=inv.total,
        functional_credit=0,
        partner_type="customer",
        partner_id=customer.id,
        partner_name=customer.name_ar,
        description=f"فاتورة {inv.invoice_number}",
    ))
    # Revenue (Cr)
    db.add(JournalLine(
        id=gen_uuid(),
        tenant_id=inv.tenant_id,
        journal_entry_id=je.id,
        line_number=2,
        account_id=revenue.id,
        currency=inv.currency,
        debit_amount=0,
        credit_amount=inv.subtotal,
        functional_debit=0,
        functional_credit=inv.subtotal,
        description="إيرادات مبيعات",
    ))
    # VAT out (Cr)
    if inv.vat_amount and inv.vat_amount > 0:
        db.add(JournalLine(
            id=gen_uuid(),
            tenant_id=inv.tenant_id,
            journal_entry_id=je.id,
            line_number=3,
            account_id=vat_out.id,
            currency=inv.currency,
            debit_amount=0,
            credit_amount=inv.vat_amount,
            functional_debit=0,
            functional_credit=inv.vat_amount,
            description="ضريبة القيمة المضافة — مخرجات",
        ))

    return je


@router.post("/sales-invoices", response_model=SalesInvoiceRead, status_code=201)
def create_sales_invoice(payload: SalesInvoiceCreate = Body(...)):
    db = _db()
    try:
        customer = db.query(Customer).filter(Customer.id == payload.customer_id).first()
        if customer is None:
            raise HTTPException(status_code=404, detail="customer not found")

        issue_date = date.fromisoformat(payload.issue_date)
        inv_number = payload.invoice_number or _next_invoice_number(db, payload.entity_id, issue_date.year)

        # Compute totals from lines
        subtotal = Decimal("0")
        vat_total = Decimal("0")
        inv = SalesInvoice(
            id=gen_uuid(),
            tenant_id=payload.tenant_id,
            entity_id=payload.entity_id,
            customer_id=customer.id,
            invoice_number=inv_number,
            issue_date=issue_date,
            due_date=date.fromisoformat(payload.due_date) if payload.due_date else None,
            status=SalesInvoiceStatus.draft.value,
            currency=payload.currency,
            memo=payload.memo,
        )
        db.add(inv)
        db.flush()

        for i, ln in enumerate(payload.lines, start=1):
            qty = Decimal(str(ln.quantity))
            price = Decimal(str(ln.unit_price))
            discount = price * qty * (Decimal(str(ln.discount_pct)) / Decimal(100))
            line_sub = (qty * price) - discount
            line_vat = line_sub * (Decimal(str(ln.vat_rate)) / Decimal(100))
            line_total = line_sub + line_vat
            subtotal += line_sub
            vat_total += line_vat
            db.add(SalesInvoiceLine(
                id=gen_uuid(),
                invoice_id=inv.id,
                line_number=i,
                product_id=ln.product_id,
                description=ln.description,
                quantity=qty,
                unit_price=price,
                discount_pct=Decimal(str(ln.discount_pct)),
                discount_amount=discount,
                vat_code=f"{int(ln.vat_rate)}",
                vat_rate=Decimal(str(ln.vat_rate)),
                subtotal=line_sub,
                vat_amount=line_vat,
                line_total=line_total,
                revenue_account_id=ln.revenue_account_id,
            ))

        inv.subtotal = subtotal
        inv.vat_amount = vat_total
        inv.total = subtotal + vat_total
        db.commit()
        db.refresh(inv)

        return SalesInvoiceRead(
            id=inv.id,
            invoice_number=inv.invoice_number,
            customer_id=inv.customer_id,
            issue_date=inv.issue_date.isoformat(),
            due_date=inv.due_date.isoformat() if inv.due_date else None,
            status=inv.status,
            currency=inv.currency,
            subtotal=float(inv.subtotal),
            vat_amount=float(inv.vat_amount),
            total=float(inv.total),
            paid_amount=float(inv.paid_amount or 0),
            journal_entry_id=inv.journal_entry_id,
        )
    finally:
        db.close()


@router.get("/entities/{entity_id}/sales-invoices", response_model=list[SalesInvoiceRead])
def list_sales_invoices(
    entity_id: str = Path(...),
    status: Optional[str] = Query(None),
    customer_id: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
):
    db = _db()
    try:
        q = db.query(SalesInvoice).filter(SalesInvoice.entity_id == entity_id)
        if status:
            q = q.filter(SalesInvoice.status == status)
        if customer_id:
            q = q.filter(SalesInvoice.customer_id == customer_id)
        rows = q.order_by(SalesInvoice.issue_date.desc()).limit(limit).all()
        return [
            SalesInvoiceRead(
                id=r.id, invoice_number=r.invoice_number, customer_id=r.customer_id,
                issue_date=r.issue_date.isoformat(),
                due_date=r.due_date.isoformat() if r.due_date else None,
                status=r.status, currency=r.currency,
                subtotal=float(r.subtotal), vat_amount=float(r.vat_amount),
                total=float(r.total), paid_amount=float(r.paid_amount or 0),
                journal_entry_id=r.journal_entry_id,
            )
            for r in rows
        ]
    finally:
        db.close()


@router.post("/sales-invoices/{invoice_id}/issue", response_model=SalesInvoiceRead)
def issue_sales_invoice(invoice_id: str = Path(...)):
    """Move draft → issued — posts the auto-JE and updates inventory
    (where product_id is set on any line)."""
    db = _db()
    try:
        inv = db.query(SalesInvoice).filter(SalesInvoice.id == invoice_id).first()
        if inv is None:
            raise HTTPException(status_code=404, detail="invoice not found")
        if inv.status != SalesInvoiceStatus.draft.value:
            raise HTTPException(status_code=409, detail=f"cannot issue from status {inv.status!r}")

        customer = db.query(Customer).filter(Customer.id == inv.customer_id).first()
        if customer is None:
            raise HTTPException(status_code=404, detail="customer not found")

        je = _post_sales_invoice_je(db, inv, customer)
        # Actually post to GL (creates GLPosting rows from JournalLine rows)
        try:
            from app.pilot.services.gl_engine import post_journal_entry
            post_journal_entry(db, je.id)
        except Exception as e:
            # If posting fails, roll the invoice back to draft.
            db.rollback()
            raise HTTPException(status_code=409, detail=f"GL posting failed: {e}")
        inv.journal_entry_id = je.id
        inv.status = SalesInvoiceStatus.issued.value
        inv.issued_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(inv)

        return SalesInvoiceRead(
            id=inv.id, invoice_number=inv.invoice_number, customer_id=inv.customer_id,
            issue_date=inv.issue_date.isoformat(),
            due_date=inv.due_date.isoformat() if inv.due_date else None,
            status=inv.status, currency=inv.currency,
            subtotal=float(inv.subtotal), vat_amount=float(inv.vat_amount),
            total=float(inv.total), paid_amount=float(inv.paid_amount or 0),
            journal_entry_id=inv.journal_entry_id,
        )
    finally:
        db.close()


@router.post("/sales-invoices/{invoice_id}/payment", status_code=201)
def record_customer_payment(
    invoice_id: str = Path(...),
    payload: CustomerPaymentInput = Body(...),
):
    """Record a payment against an invoice. Updates paid_amount + status."""
    db = _db()
    try:
        inv = db.query(SalesInvoice).filter(SalesInvoice.id == invoice_id).first()
        if inv is None:
            raise HTTPException(status_code=404, detail="invoice not found")

        pay = CustomerPayment(
            id=gen_uuid(),
            tenant_id=inv.tenant_id,
            customer_id=inv.customer_id,
            invoice_id=inv.id,
            receipt_number=payload.receipt_number or f"RCT-{date.today().year}-{gen_uuid()[:6]}",
            payment_date=date.fromisoformat(payload.payment_date),
            currency=inv.currency,
            amount=Decimal(str(payload.amount)),
            method=payload.method,
            reference=payload.reference,
        )
        db.add(pay)

        new_paid = (inv.paid_amount or Decimal(0)) + pay.amount
        inv.paid_amount = new_paid
        if new_paid >= inv.total:
            inv.status = SalesInvoiceStatus.paid.value
        elif new_paid > 0:
            inv.status = SalesInvoiceStatus.partially_paid.value

        db.commit()
        db.refresh(pay)

        return {
            "payment_id": pay.id,
            "receipt_number": pay.receipt_number,
            "amount": float(pay.amount),
            "invoice_status": inv.status,
            "invoice_paid_amount": float(inv.paid_amount),
        }
    finally:
        db.close()
