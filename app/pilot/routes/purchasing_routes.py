"""مسارات الشراء — Vendors + PO + GRN + PI + Payments + Ledger."""

from datetime import date as _date
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.phase1.routes.phase1_routes import get_current_user
from app.pilot.models import (
    Tenant, Entity, Branch, Warehouse, ProductVariant,
    Vendor,
    PurchaseOrder, PurchaseOrderLine, PoStatus,
    GoodsReceipt, GoodsReceiptLine,
    PurchaseInvoice, PurchaseInvoiceLine, PurchaseInvoiceStatus,
    VendorPayment,
)
from app.pilot.schemas.purchasing import (
    VendorCreate, VendorRead, VendorUpdate, VendorLedgerResponse,
    PoCreate, PoRead, PoDetail, PoLineRead, PoApprove,
    GrnCreate, GrnRead, GrnDetail, GrnLineRead,
    PiCreate, PiRead, PiDetail, PiLineRead,
    VendorPaymentCreate, VendorPaymentRead,
)
from app.pilot.services.purchasing_engine import (
    create_purchase_order, approve_po, issue_po,
    receive_goods,
    create_purchase_invoice, post_purchase_invoice_to_gl,
    create_vendor_payment,
    vendor_ledger,
)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot-purchasing"],
    dependencies=[Depends(get_current_user)],
)


def _tenant_or_404(db, tid):
    t = db.query(Tenant).filter(Tenant.id == tid).first()
    if not t:
        raise HTTPException(404, f"Tenant {tid} not found")
    return t


def _entity_or_404(db, eid):
    e = db.query(Entity).filter(Entity.id == eid, Entity.is_deleted == False).first()  # noqa: E712
    if not e:
        raise HTTPException(404, f"Entity {eid} not found")
    return e


def _vendor_or_404(db, vid):
    v = db.query(Vendor).filter(Vendor.id == vid, Vendor.is_deleted == False).first()  # noqa: E712
    if not v:
        raise HTTPException(404, f"Vendor {vid} not found")
    return v


# ══════════════════════════════════════════════════════════════════════════
# Vendors
# ══════════════════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/vendors", response_model=list[VendorRead])
def list_vendors(
    tenant_id: str,
    active_only: bool = Query(True),
    kind: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    _tenant_or_404(db, tenant_id)
    q = db.query(Vendor).filter(
        Vendor.tenant_id == tenant_id,
        Vendor.is_deleted == False,  # noqa: E712
    )
    if active_only:
        q = q.filter(Vendor.is_active == True)  # noqa: E712
    if kind:
        q = q.filter(Vendor.kind == kind)
    if search:
        term = f"%{search}%"
        q = q.filter(
            (Vendor.code.ilike(term)) | (Vendor.legal_name_ar.ilike(term))
            | (Vendor.legal_name_en.ilike(term))
        )
    return q.order_by(Vendor.legal_name_ar).all()


@router.post("/tenants/{tenant_id}/vendors", response_model=VendorRead, status_code=201)
def create_vendor(tenant_id: str, payload: VendorCreate, db: Session = Depends(get_db)):
    _tenant_or_404(db, tenant_id)
    if db.query(Vendor).filter(Vendor.tenant_id == tenant_id, Vendor.code == payload.code).first():
        raise HTTPException(409, f"المورد بكود '{payload.code}' موجود مسبقاً")
    v = Vendor(tenant_id=tenant_id, **payload.model_dump())
    db.add(v)
    db.commit()
    db.refresh(v)
    return v


@router.get("/vendors/{vendor_id}", response_model=VendorRead)
def get_vendor(vendor_id: str, db: Session = Depends(get_db)):
    return _vendor_or_404(db, vendor_id)


@router.patch("/vendors/{vendor_id}", response_model=VendorRead)
def update_vendor(vendor_id: str, payload: VendorUpdate, db: Session = Depends(get_db)):
    v = _vendor_or_404(db, vendor_id)
    for k, val in payload.model_dump(exclude_unset=True).items():
        setattr(v, k, val)
    db.commit()
    db.refresh(v)
    return v


@router.get("/vendors/{vendor_id}/ledger", response_model=VendorLedgerResponse)
def get_vendor_ledger(vendor_id: str, db: Session = Depends(get_db)):
    _vendor_or_404(db, vendor_id)
    try:
        return vendor_ledger(db, vendor_id=vendor_id)
    except ValueError as ex:
        raise HTTPException(400, str(ex))


# ══════════════════════════════════════════════════════════════════════════
# Purchase Orders
# ══════════════════════════════════════════════════════════════════════════

@router.post("/purchase-orders", response_model=PoDetail, status_code=201)
def create_po_endpoint(payload: PoCreate, db: Session = Depends(get_db)):
    entity = _entity_or_404(db, payload.entity_id)
    vendor = _vendor_or_404(db, payload.vendor_id)
    try:
        po = create_purchase_order(
            db, entity=entity, vendor=vendor,
            order_date=payload.order_date,
            lines_input=[ln.model_dump() for ln in payload.lines],
            branch_id=payload.branch_id,
            destination_warehouse_id=payload.destination_warehouse_id,
            expected_delivery_date=payload.expected_delivery_date,
            payment_terms=payload.payment_terms,
            notes_to_vendor=payload.notes_to_vendor,
            created_by_user_id=payload.created_by_user_id,
        )
        db.commit()
        db.refresh(po)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))

    lines = db.query(PurchaseOrderLine).filter(
        PurchaseOrderLine.po_id == po.id
    ).order_by(PurchaseOrderLine.line_number).all()
    return PoDetail(
        **PoRead.model_validate(po).model_dump(),
        lines=[PoLineRead.model_validate(l) for l in lines],
        notes_to_vendor=po.notes_to_vendor, internal_notes=po.internal_notes,
    )


@router.get("/entities/{entity_id}/purchase-orders", response_model=list[PoRead])
def list_pos(
    entity_id: str,
    vendor_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    q = db.query(PurchaseOrder).filter(
        PurchaseOrder.entity_id == entity_id,
        PurchaseOrder.is_deleted == False,  # noqa: E712
    )
    if vendor_id:
        q = q.filter(PurchaseOrder.vendor_id == vendor_id)
    if status:
        q = q.filter(PurchaseOrder.status == status)
    return q.order_by(PurchaseOrder.order_date.desc()).limit(limit).all()


@router.get("/purchase-orders/{po_id}", response_model=PoDetail)
def get_po(po_id: str, db: Session = Depends(get_db)):
    po = db.query(PurchaseOrder).filter(PurchaseOrder.id == po_id).first()
    if not po:
        raise HTTPException(404, "PO not found")
    lines = db.query(PurchaseOrderLine).filter(
        PurchaseOrderLine.po_id == po_id
    ).order_by(PurchaseOrderLine.line_number).all()
    return PoDetail(
        **PoRead.model_validate(po).model_dump(),
        lines=[PoLineRead.model_validate(l) for l in lines],
        notes_to_vendor=po.notes_to_vendor, internal_notes=po.internal_notes,
    )


def _get_approval_limit(db: Session, tenant_id: str, doc_type: str) -> dict:
    """جلب حدود الاعتماد من CompanySettings.

    doc_type: "po" | "je" | "payment"
    يُرجع list من thresholds: [{max, role, level, ...}]
    """
    from app.pilot.models import CompanySettings
    cs = db.query(CompanySettings).filter(
        CompanySettings.tenant_id == tenant_id
    ).first()
    if not cs or not cs.approval_thresholds:
        return {"thresholds": []}
    return {"thresholds": cs.approval_thresholds.get(doc_type, [])}


@router.post("/purchase-orders/{po_id}/approve", response_model=PoRead)
def approve_po_endpoint(po_id: str, payload: PoApprove, db: Session = Depends(get_db)):
    # جلب الـ PO أولاً للتحقق من مستوى الاعتماد المطلوب
    po_check = db.query(PurchaseOrder).filter(PurchaseOrder.id == po_id).first()
    if not po_check:
        raise HTTPException(404, "PO not found")
    # فحص approval limits — إنذار فقط (لا نمنع، لكن نُسجِّل warning في response)
    approval_warnings = []
    limits = _get_approval_limit(db, po_check.tenant_id, "po")["thresholds"]
    if limits:
        po_total = float(po_check.grand_total or 0)
        required_level = None
        for threshold in limits:
            max_amt = threshold.get("max")
            # max = None => unlimited
            if max_amt is None or po_total <= float(max_amt):
                required_level = threshold
                break
        if required_level:
            required_role = required_level.get("role", "accountant")
            approval_warnings.append(
                f"قيمة الأمر {po_total} — يتطلب اعتماد دور '{required_role}' "
                f"(level {required_level.get('level', 1)})"
            )

    try:
        po = approve_po(db, po_id, payload.user_id)
        db.commit()
        db.refresh(po)
        # نعلّق التحذيرات على الـ response object
        if approval_warnings:
            po._approval_warnings = approval_warnings  # type: ignore
        return po
    except ValueError as ex:
        db.rollback()
        raise HTTPException(409, str(ex))


@router.post("/purchase-orders/{po_id}/issue", response_model=PoRead)
def issue_po_endpoint(po_id: str, db: Session = Depends(get_db)):
    try:
        po = issue_po(db, po_id)
        db.commit()
        db.refresh(po)
        return po
    except ValueError as ex:
        db.rollback()
        raise HTTPException(409, str(ex))


# ══════════════════════════════════════════════════════════════════════════
# GRN
# ══════════════════════════════════════════════════════════════════════════

@router.post("/goods-receipts", response_model=GrnDetail, status_code=201)
def receive_grn(payload: GrnCreate, db: Session = Depends(get_db)):
    import logging
    import traceback
    po = db.query(PurchaseOrder).filter(PurchaseOrder.id == payload.po_id).first()
    if not po:
        raise HTTPException(404, "PO not found")
    warehouse = db.query(Warehouse).filter(
        Warehouse.id == payload.warehouse_id, Warehouse.is_deleted == False  # noqa: E712
    ).first()
    if not warehouse:
        raise HTTPException(404, "Warehouse not found")
    try:
        grn = receive_goods(
            db, po=po, warehouse=warehouse,
            received_at=payload.received_at,
            lines_input=[ln.model_dump() for ln in payload.lines],
            delivery_note_number=payload.delivery_note_number,
            notes=payload.notes,
            received_by_user_id=payload.received_by_user_id,
        )
        db.commit()
        db.refresh(grn)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))
    except HTTPException:
        # تمرير HTTPException الصريحة كما هي (404, 400, إلخ)
        db.rollback()
        raise
    except Exception as ex:
        # أي استثناء آخر نرجّعه كـ 400 مع الرسالة الكاملة بدل 500 صامت
        # (500 بدون CORS headers يسبب "CORS error" مُضلّل في المتصفح)
        db.rollback()
        tb = traceback.format_exc()
        logging.error(f"receive_grn failed: {ex}\n{tb}")
        raise HTTPException(
            400,
            f"فشل استلام البضاعة: {type(ex).__name__}: {str(ex)[:200]}"
        )

    lines = db.query(GoodsReceiptLine).filter(
        GoodsReceiptLine.grn_id == grn.id
    ).order_by(GoodsReceiptLine.line_number).all()
    return GrnDetail(
        **GrnRead.model_validate(grn).model_dump(),
        lines=[GrnLineRead.model_validate(l) for l in lines],
    )


@router.get("/purchase-orders/{po_id}/receipts", response_model=list[GrnRead])
def list_grns_for_po(po_id: str, db: Session = Depends(get_db)):
    return db.query(GoodsReceipt).filter(
        GoodsReceipt.po_id == po_id
    ).order_by(GoodsReceipt.received_at.desc()).all()


@router.get("/goods-receipts/{grn_id}", response_model=GrnDetail)
def get_grn(grn_id: str, db: Session = Depends(get_db)):
    grn = db.query(GoodsReceipt).filter(GoodsReceipt.id == grn_id).first()
    if not grn:
        raise HTTPException(404, "GRN not found")
    lines = db.query(GoodsReceiptLine).filter(
        GoodsReceiptLine.grn_id == grn_id
    ).order_by(GoodsReceiptLine.line_number).all()
    return GrnDetail(
        **GrnRead.model_validate(grn).model_dump(),
        lines=[GrnLineRead.model_validate(l) for l in lines],
    )


# ══════════════════════════════════════════════════════════════════════════
# Purchase Invoices
# ══════════════════════════════════════════════════════════════════════════

@router.post("/purchase-invoices", response_model=PiDetail, status_code=201)
def create_pi_endpoint(payload: PiCreate, db: Session = Depends(get_db)):
    entity = _entity_or_404(db, payload.entity_id)
    vendor = _vendor_or_404(db, payload.vendor_id)
    po = None
    if payload.po_id:
        po = db.query(PurchaseOrder).filter(PurchaseOrder.id == payload.po_id).first()
        if not po:
            raise HTTPException(400, "po_id not found")
    try:
        inv = create_purchase_invoice(
            db, entity=entity, vendor=vendor,
            invoice_date=payload.invoice_date,
            lines_input=[ln.model_dump() for ln in payload.lines],
            po=po,
            vendor_invoice_number=payload.vendor_invoice_number,
            due_date=payload.due_date,
            shipping=payload.shipping,
            notes=payload.notes,
            created_by_user_id=payload.created_by_user_id,
        )
        db.commit()
        db.refresh(inv)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))

    lines = db.query(PurchaseInvoiceLine).filter(
        PurchaseInvoiceLine.invoice_id == inv.id
    ).order_by(PurchaseInvoiceLine.line_number).all()
    return PiDetail(
        **PiRead.model_validate(inv).model_dump(),
        lines=[PiLineRead.model_validate(l) for l in lines],
    )


@router.post("/purchase-invoices/{pi_id}/post", response_model=PiRead)
def post_pi_endpoint(pi_id: str, db: Session = Depends(get_db)):
    try:
        post_purchase_invoice_to_gl(db, pi_id)
        db.commit()
        inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == pi_id).first()
        return inv
    except ValueError as ex:
        db.rollback()
        raise HTTPException(409, str(ex))


@router.get("/entities/{entity_id}/purchase-invoices", response_model=list[PiRead])
def list_pis(
    entity_id: str,
    vendor_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    q = db.query(PurchaseInvoice).filter(
        PurchaseInvoice.entity_id == entity_id,
        PurchaseInvoice.is_deleted == False,  # noqa: E712
    )
    if vendor_id:
        q = q.filter(PurchaseInvoice.vendor_id == vendor_id)
    if status:
        q = q.filter(PurchaseInvoice.status == status)
    return q.order_by(PurchaseInvoice.invoice_date.desc()).limit(limit).all()


@router.get("/purchase-invoices/{pi_id}", response_model=PiDetail)
def get_pi(pi_id: str, db: Session = Depends(get_db)):
    inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == pi_id).first()
    if not inv:
        raise HTTPException(404, "Invoice not found")
    lines = db.query(PurchaseInvoiceLine).filter(
        PurchaseInvoiceLine.invoice_id == pi_id
    ).order_by(PurchaseInvoiceLine.line_number).all()
    return PiDetail(
        **PiRead.model_validate(inv).model_dump(),
        lines=[PiLineRead.model_validate(l) for l in lines],
    )


# ══════════════════════════════════════════════════════════════════════════
# Vendor Payments
# ══════════════════════════════════════════════════════════════════════════

@router.post("/vendor-payments", response_model=VendorPaymentRead, status_code=201)
def create_vp_endpoint(payload: VendorPaymentCreate, db: Session = Depends(get_db)):
    entity = _entity_or_404(db, payload.entity_id)
    vendor = _vendor_or_404(db, payload.vendor_id)
    inv = None
    if payload.invoice_id:
        inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == payload.invoice_id).first()
        if not inv:
            raise HTTPException(400, "invoice_id not found")
    try:
        vp = create_vendor_payment(
            db, entity=entity, vendor=vendor,
            amount=payload.amount, payment_date=payload.payment_date,
            method=payload.method, invoice=inv,
            paid_from_account_code=payload.paid_from_account_code,
            reference_number=payload.reference_number, notes=payload.notes,
            created_by_user_id=payload.created_by_user_id,
        )
        db.commit()
        db.refresh(vp)
        return vp
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))


@router.get("/entities/{entity_id}/vendor-payments", response_model=list[VendorPaymentRead])
def list_vps(
    entity_id: str,
    vendor_id: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    q = db.query(VendorPayment).filter(VendorPayment.entity_id == entity_id)
    if vendor_id:
        q = q.filter(VendorPayment.vendor_id == vendor_id)
    return q.order_by(VendorPayment.payment_date.desc()).limit(limit).all()
