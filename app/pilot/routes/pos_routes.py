"""POS (Point-of-Sale) routes — Week 2.

Endpoints:

  Sessions:
    POST   /pilot/branches/{bid}/pos-sessions           — فتح وردية
    GET    /pilot/branches/{bid}/pos-sessions           — قائمة
    GET    /pilot/pos-sessions/{sid}                    — تفاصيل
    POST   /pilot/pos-sessions/{sid}/close              — إقفال + Z-report
    GET    /pilot/pos-sessions/{sid}/z-report           — تقرير Z

  Transactions:
    POST   /pilot/pos-transactions                      — بيع / مرتجع
    GET    /pilot/pos-sessions/{sid}/transactions
    GET    /pilot/pos-transactions/{tid}                — تفاصيل مع البنود والدفعات
    POST   /pilot/pos-transactions/{tid}/void           — إلغاء
    POST   /pilot/pos-transactions/{tid}/refund         — مرتجع

  Cash drawer:
    POST   /pilot/pos-sessions/{sid}/cash-movements     — paid_in / paid_out
    GET    /pilot/pos-sessions/{sid}/cash-movements
"""

from datetime import datetime, timezone, date
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.phase1.models.platform_models import get_db
from app.phase1.routes.phase1_routes import get_current_user
from app.pilot.models import (
    Tenant, Branch, Entity, Warehouse, ProductVariant, Product, StockLevel, StockMovement,
    PriceList, PriceListItem, PriceListScope,
    PosSession, PosSessionStatus,
    PosTransaction, PosTransactionKind, PosTransactionStatus,
    PosTransactionLine, PosPayment, PaymentMethod,
    CashMovement, CashMovementKind,
    CompanySettings,
)
from app.pilot.schemas.pos import (
    PosSessionOpen, PosSessionClose, PosSessionRead,
    PosTransactionCreate, PosTransactionRead, PosTransactionDetail,
    PosLineRead, PosLineInput,
    PosPaymentRead, PosPaymentInput,
    PosVoidRequest, PosRefundRequest,
    CashMovementCreate, CashMovementRead,
    ZReportResponse,
)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot-pos"],
    dependencies=[Depends(get_current_user)],
)


Q2 = Decimal("0.01")
Q4 = Decimal("0.0001")


def q2(x: Decimal) -> Decimal:
    """دوّر إلى خانتين عشريتين."""
    return (x if x is not None else Decimal("0")).quantize(Q2, rounding=ROUND_HALF_UP)


# ──────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────

def _branch_or_404(db: Session, bid: str) -> Branch:
    b = db.query(Branch).filter(Branch.id == bid, Branch.is_deleted == False).first()  # noqa: E712
    if not b:
        raise HTTPException(404, f"Branch {bid} not found")
    return b


def _session_or_404(db: Session, sid: str) -> PosSession:
    s = db.query(PosSession).filter(PosSession.id == sid).first()
    if not s:
        raise HTTPException(404, f"Session {sid} not found")
    return s


def _open_session_or_409(db: Session, sid: str) -> PosSession:
    s = _session_or_404(db, sid)
    if s.status != PosSessionStatus.open.value:
        raise HTTPException(409, f"Session is {s.status} (must be open)")
    return s


def _txn_or_404(db: Session, tid: str) -> PosTransaction:
    t = db.query(PosTransaction).filter(PosTransaction.id == tid).first()
    if not t:
        raise HTTPException(404, f"Transaction {tid} not found")
    return t


def _resolve_price_for_line(
    db: Session, *, tenant_id: str, variant: ProductVariant, branch: Branch,
    qty: Decimal, at_time: datetime, customer_group_code: Optional[str],
) -> tuple[Decimal, Optional[str], Optional[str], bool]:
    """أعد (unit_price, price_list_id, promo_badge, prices_include_vat).

    نسخة مبسّطة من price_lookup داخل معاملة واحدة لتجنّب الشبكة.
    """
    today = at_time.date()

    # القوائم المرشّحة
    base = db.query(PriceList).filter(
        PriceList.tenant_id == tenant_id,
        PriceList.is_active == True,  # noqa: E712
        PriceList.is_deleted == False,  # noqa: E712
        PriceList.valid_from <= today,
    )
    # valid_to null OR valid_to >= today
    from sqlalchemy import or_
    base = base.filter(or_(PriceList.valid_to.is_(None), PriceList.valid_to >= today))

    candidates: list[PriceList] = []
    for pl in base.order_by(PriceList.priority.desc(), PriceList.valid_from.desc()).all():
        if pl.scope == PriceListScope.tenant.value:
            candidates.append(pl)
        elif pl.scope == PriceListScope.entity.value:
            if branch.entity_id == pl.entity_id:
                candidates.append(pl)
        elif pl.scope == PriceListScope.branch.value:
            from app.pilot.models import PriceListBranch
            if db.query(PriceListBranch).filter(
                PriceListBranch.price_list_id == pl.id,
                PriceListBranch.branch_id == branch.id,
            ).first():
                candidates.append(pl)
        elif pl.scope == PriceListScope.customer_group.value:
            if customer_group_code and pl.customer_group_code == customer_group_code:
                candidates.append(pl)

    for pl in candidates:
        item = db.query(PriceListItem).filter(
            PriceListItem.price_list_id == pl.id,
            PriceListItem.variant_id == variant.id,
            PriceListItem.min_qty <= abs(qty),
            PriceListItem.is_active == True,  # noqa: E712
        ).order_by(PriceListItem.min_qty.desc()).first()
        if not item:
            continue

        # خصم عرض
        final_price = item.unit_price
        if item.promo_discount_pct and (
            not item.promo_starts_at or item.promo_starts_at <= at_time
        ) and (
            not item.promo_ends_at or item.promo_ends_at >= at_time
        ):
            final_price = (item.unit_price *
                           (Decimal("100") - item.promo_discount_pct) /
                           Decimal("100")).quantize(Q2)

        return (final_price, pl.id, pl.promo_badge_text_ar, pl.prices_include_vat)

    # fallback → السعر الافتراضي للمتغيّر
    if variant.list_price is not None:
        return (variant.list_price, None, None, True)

    return (Decimal("0"), None, None, True)


def _next_session_code(db: Session, branch: Branch) -> str:
    """e.g., RIY-01-2026-04-20-01"""
    today = datetime.now(timezone.utc).date()
    prefix = f"{branch.code}-{today.isoformat()}"
    count = db.query(PosSession).filter(
        PosSession.branch_id == branch.id,
        PosSession.code.like(f"{prefix}%"),
    ).count()
    return f"{prefix}-{count+1:02d}"


def _next_receipt_number(db: Session, session: PosSession) -> str:
    """e.g., RIY-01-2026-04-20-01-0001"""
    count = db.query(PosTransaction).filter(
        PosTransaction.session_id == session.id
    ).count()
    return f"{session.code}-{count+1:04d}"


def _current_cash_balance(db: Session, session: PosSession) -> Decimal:
    """رصيد الدرج الحالي = مجموع كل الحركات."""
    total = db.query(func.coalesce(func.sum(CashMovement.amount), 0)).filter(
        CashMovement.session_id == session.id
    ).scalar()
    return Decimal(str(total or 0))


# ══════════════════════════════════════════════════════════════════════════
# Sessions
# ══════════════════════════════════════════════════════════════════════════

@router.post("/branches/{branch_id}/pos-sessions", response_model=PosSessionRead, status_code=201)
def open_session(branch_id: str, payload: PosSessionOpen, db: Session = Depends(get_db)):
    """فتح وردية جديدة في فرع + محطة.

    Rules:
      - يُسمح بوردية واحدة مفتوحة لكل (branch, station_id).
      - opening_cash يُسجَّل كأول CashMovement.
    """
    branch = _branch_or_404(db, branch_id)

    # تحقق من عدم وجود وردية مفتوحة لنفس المحطة
    q = db.query(PosSession).filter(
        PosSession.branch_id == branch_id,
        PosSession.status == PosSessionStatus.open.value,
    )
    if payload.station_id:
        q = q.filter(PosSession.station_id == payload.station_id)
    existing = q.first()
    if existing:
        raise HTTPException(
            409,
            f"Already have an open session ({existing.code}) "
            f"for this {'station' if payload.station_id else 'branch'}"
        )

    # تحقق أن المستودع ينتمي للفرع
    wh = db.query(Warehouse).filter(
        Warehouse.id == payload.warehouse_id,
        Warehouse.branch_id == branch_id,
        Warehouse.is_deleted == False,  # noqa: E712
    ).first()
    if not wh:
        raise HTTPException(400, "Warehouse not found for this branch")
    if not wh.is_sellable_from:
        raise HTTPException(400, f"Warehouse {wh.code} is not flagged sellable_from")

    # العملة الوظيفية من الكيان
    entity = db.query(Entity).filter(Entity.id == branch.entity_id).first()
    currency = entity.functional_currency if entity else "SAR"

    code = _next_session_code(db, branch)
    now = datetime.now(timezone.utc)

    session = PosSession(
        tenant_id=branch.tenant_id,
        branch_id=branch_id,
        warehouse_id=payload.warehouse_id,
        code=code,
        station_id=payload.station_id,
        station_label=payload.station_label,
        status=PosSessionStatus.open.value,
        currency=currency,
        opened_at=now,
        opened_by_user_id=payload.opened_by_user_id,
        opening_cash=payload.opening_cash,
        opening_notes=payload.opening_notes,
    )
    db.add(session)
    db.flush()

    # حركة الافتتاح على الدرج
    if payload.opening_cash > 0:
        db.add(CashMovement(
            tenant_id=branch.tenant_id,
            session_id=session.id,
            kind=CashMovementKind.opening.value,
            amount=payload.opening_cash,
            currency=currency,
            reason="رصيد افتتاحي",
            performed_at=now,
            performed_by_user_id=payload.opened_by_user_id,
            balance_after=payload.opening_cash,
        ))

    db.commit()
    db.refresh(session)
    return session


@router.get("/branches/{branch_id}/pos-sessions", response_model=list[PosSessionRead])
def list_sessions(
    branch_id: str,
    status: Optional[str] = Query(None),
    limit: int = Query(50, le=500),
    db: Session = Depends(get_db),
):
    _branch_or_404(db, branch_id)
    q = db.query(PosSession).filter(PosSession.branch_id == branch_id)
    if status:
        q = q.filter(PosSession.status == status)
    return q.order_by(PosSession.opened_at.desc()).limit(limit).all()


@router.get("/pos-sessions/{session_id}", response_model=PosSessionRead)
def get_session(session_id: str, db: Session = Depends(get_db)):
    return _session_or_404(db, session_id)


@router.post("/pos-sessions/{session_id}/close", response_model=ZReportResponse)
def close_session(session_id: str, payload: PosSessionClose, db: Session = Depends(get_db)):
    """إقفال الوردية + توليد Z-report.

    يحسب:
      - expected_cash = opening + sales_cash - refunds_cash + paid_in - paid_out
      - variance = closing - expected (موجب = زيادة، سالب = عجز)
    """
    session = _open_session_or_409(db, session_id)
    now = datetime.now(timezone.utc)

    # المحسوب من الحركات
    expected = _current_cash_balance(db, session)
    variance = payload.closing_cash - expected
    variance_pct = None
    if expected > 0:
        variance_pct = (variance / expected * Decimal("100")).quantize(Q2)

    session.status = PosSessionStatus.closed.value
    session.closed_at = now
    session.closed_by_user_id = payload.closed_by_user_id
    session.closing_cash = payload.closing_cash
    session.expected_cash = expected
    session.variance = variance
    session.closing_notes = payload.closing_notes

    # حركة الإقفال — ليست تغيير رصيد، مجرد ختم
    db.add(CashMovement(
        tenant_id=session.tenant_id,
        session_id=session.id,
        kind=CashMovementKind.closing.value,
        amount=Decimal("0"),  # لا تؤثر على الرصيد
        currency=session.currency,
        reason=f"إقفال الوردية — counted={payload.closing_cash}, expected={expected}, variance={variance}",
        performed_at=now,
        performed_by_user_id=payload.closed_by_user_id,
        balance_after=expected,
    ))

    # تحليل الدفعات
    payments = (
        db.query(PosPayment.method, func.sum(PosPayment.amount))
        .join(PosTransaction, PosTransaction.id == PosPayment.transaction_id)
        .filter(
            PosTransaction.session_id == session.id,
            PosTransaction.status == PosTransactionStatus.completed.value,
        )
        .group_by(PosPayment.method)
        .all()
    )
    breakdown = {m: Decimal(str(amt or 0)) for m, amt in payments}
    session.payment_breakdown = {m: float(v) for m, v in breakdown.items()}

    # أفضل SKUs
    top = (
        db.query(
            PosTransactionLine.sku,
            PosTransactionLine.description,
            func.sum(PosTransactionLine.qty).label("total_qty"),
            func.sum(PosTransactionLine.line_total).label("total_sales"),
        )
        .join(PosTransaction, PosTransaction.id == PosTransactionLine.transaction_id)
        .filter(
            PosTransaction.session_id == session.id,
            PosTransaction.status == PosTransactionStatus.completed.value,
        )
        .group_by(PosTransactionLine.sku, PosTransactionLine.description)
        .order_by(func.sum(PosTransactionLine.line_total).desc())
        .limit(10)
        .all()
    )
    top_skus = [
        {"sku": r[0], "description": r[1], "qty": float(r[2] or 0), "total": float(r[3] or 0)}
        for r in top
    ]

    db.commit()
    db.refresh(session)

    return ZReportResponse(
        session=PosSessionRead.model_validate(session),
        expected_cash=expected,
        closing_cash=payload.closing_cash,
        variance=variance,
        variance_pct=variance_pct,
        transaction_count=session.transaction_count,
        total_sales_gross=session.gross_sales,
        total_refunds=Decimal("0"),  # TODO احسب من kind=return
        total_vat=session.vat_total,
        total_net=session.net_sales,
        payment_breakdown={k: Decimal(str(v)) for k, v in session.payment_breakdown.items()},
        top_skus=top_skus,
    )


@router.get("/pos-sessions/{session_id}/z-report", response_model=ZReportResponse)
def z_report(session_id: str, db: Session = Depends(get_db)):
    """تقرير Z — متاح أيضاً بعد الإقفال أو للمعاينة قبله."""
    session = _session_or_404(db, session_id)
    expected = _current_cash_balance(db, session)
    closing = session.closing_cash or expected
    variance = closing - expected
    variance_pct = None
    if expected > 0:
        variance_pct = (variance / expected * Decimal("100")).quantize(Q2)
    return ZReportResponse(
        session=PosSessionRead.model_validate(session),
        expected_cash=expected,
        closing_cash=closing,
        variance=variance,
        variance_pct=variance_pct,
        transaction_count=session.transaction_count,
        total_sales_gross=session.gross_sales,
        total_refunds=Decimal("0"),
        total_vat=session.vat_total,
        total_net=session.net_sales,
        payment_breakdown={k: Decimal(str(v)) for k, v in (session.payment_breakdown or {}).items()},
        top_skus=[],
    )


# ══════════════════════════════════════════════════════════════════════════
# Transactions — البيع والمرتجع
# ══════════════════════════════════════════════════════════════════════════

def _apply_stock_movement(
    db: Session, *, session: PosSession, variant: ProductVariant, warehouse: Warehouse,
    qty_signed: Decimal, unit_cost: Decimal, reason: str, reference_number: str,
    cashier_user_id: str,
) -> StockMovement:
    """ينشئ StockMovement ويحدّث StockLevel — نفس منطق catalog_routes.record_stock_movement.

    qty_signed: +inbound, -outbound (من منظور المستودع).
    للبيع: qty_signed سالب. للمرتجع: موجب.
    """
    level = db.query(StockLevel).filter(
        StockLevel.warehouse_id == warehouse.id,
        StockLevel.variant_id == variant.id,
    ).first()
    if not level:
        level = StockLevel(
            tenant_id=session.tenant_id,
            warehouse_id=warehouse.id,
            variant_id=variant.id,
            on_hand=Decimal("0"),
            reserved=Decimal("0"),
            available=Decimal("0"),
        )
        db.add(level)
        db.flush()

    new_on_hand = level.on_hand + qty_signed
    if new_on_hand < 0 and not (warehouse.allow_negative_stock or variant.allow_negative_stock):
        raise HTTPException(
            409,
            f"مخزون غير كافٍ — {variant.sku}: متوفر {level.on_hand}، المطلوب {abs(qty_signed)}"
        )

    # weighted avg cost — للمرتجع نستخدم نفس التكلفة (بدون إعادة حساب)
    total_cost = qty_signed * unit_cost if unit_cost else Decimal("0")
    level.on_hand = new_on_hand
    level.available = level.on_hand - level.reserved
    level.last_movement_at = datetime.now(timezone.utc)

    mv = StockMovement(
        tenant_id=session.tenant_id,
        warehouse_id=warehouse.id,
        variant_id=variant.id,
        qty=qty_signed,
        unit_cost=unit_cost,
        total_cost=total_cost,
        reason=reason,
        reference_type="pos_txn",
        reference_number=reference_number,
        balance_after=level.on_hand,
        performed_at=datetime.now(timezone.utc),
        performed_by_user_id=cashier_user_id,
        branch_id=warehouse.branch_id,
    )
    db.add(mv)
    db.flush()

    # تحديث رول-اب المتغيّر
    all_levels = db.query(StockLevel).filter(StockLevel.variant_id == variant.id).all()
    variant.total_on_hand = sum((lv.on_hand for lv in all_levels), Decimal("0"))
    variant.total_reserved = sum((lv.reserved for lv in all_levels), Decimal("0"))
    variant.total_available = variant.total_on_hand - variant.total_reserved

    return mv


@router.post("/pos-transactions", response_model=PosTransactionDetail, status_code=201)
def create_transaction(payload: PosTransactionCreate, db: Session = Depends(get_db)):
    """إنشاء فاتورة بيع أو مرتجع.

    العملية الذرّية:
      1. Lock الوردية (مفتوحة + من نفس الكاشير مفروضاً)
      2. لكل بند: ابحث عن السعر → احسب VAT → StockMovement
      3. طبّق الخصم على مستوى الفاتورة (إن وُجد)
      4. سجّل الدفعات (يجب أن ≥ الإجمالي)
      5. حدّث رصيد الدرج للدفعات النقدية
      6. حدّث إحصائيات الوردية
      7. ولّد receipt_number
    """
    session = _open_session_or_409(db, payload.session_id)
    branch = _branch_or_404(db, session.branch_id)
    warehouse = db.query(Warehouse).filter(Warehouse.id == session.warehouse_id).first()
    if not warehouse:
        raise HTTPException(500, "Session's warehouse missing")

    kind = payload.kind
    is_return = kind == "return"
    is_sale = kind == "sale"

    # التحقق من المرتجع
    if is_return:
        if not payload.original_transaction_id:
            raise HTTPException(400, "المرتجع يتطلب original_transaction_id")
        orig = db.query(PosTransaction).filter(
            PosTransaction.id == payload.original_transaction_id,
            PosTransaction.tenant_id == session.tenant_id,
        ).first()
        if not orig:
            raise HTTPException(400, "الفاتورة الأصلية غير موجودة")
        if orig.status == PosTransactionStatus.refunded.value:
            raise HTTPException(409, "الفاتورة الأصلية مُرتجعة بالكامل مسبقاً")

    now = datetime.now(timezone.utc)
    receipt_number = _next_receipt_number(db, session)

    # تحميل إعدادات الشركة (للـ VAT الافتراضي)
    settings = db.query(CompanySettings).filter(
        CompanySettings.tenant_id == session.tenant_id
    ).first()
    default_vat = Decimal(str(settings.default_vat_rate if settings else 15))

    # إنشاء الفاتورة
    txn = PosTransaction(
        tenant_id=session.tenant_id,
        session_id=session.id,
        branch_id=session.branch_id,
        receipt_number=receipt_number,
        kind=kind,
        status=PosTransactionStatus.draft.value,
        customer_id=payload.customer_id,
        customer_name=payload.customer_name,
        customer_phone=payload.customer_phone,
        customer_vat_number=payload.customer_vat_number,
        currency=session.currency,
        cashier_user_id=payload.cashier_user_id,
        cashier_name=payload.cashier_name,
        original_transaction_id=payload.original_transaction_id,
        reason_text=payload.reason_text,
        transacted_at=now,
        notes=payload.notes,
    )
    db.add(txn)
    db.flush()

    # بنود الفاتورة
    subtotal = Decimal("0")
    total_line_discount = Decimal("0")
    total_taxable = Decimal("0")
    total_vat = Decimal("0")
    grand_line_total = Decimal("0")

    for idx, line_in in enumerate(payload.lines, start=1):
        variant = db.query(ProductVariant).filter(
            ProductVariant.id == line_in.variant_id,
            ProductVariant.tenant_id == session.tenant_id,
        ).first()
        if not variant:
            raise HTTPException(400, f"Variant {line_in.variant_id} not found")
        product = db.query(Product).filter(Product.id == variant.product_id).first()

        qty = line_in.qty
        if qty == 0:
            raise HTTPException(400, f"Line {idx}: qty=0 غير مسموح")
        # للمرتجع: qty في payload موجب، لكنه خروج من الزبون → دخول للمستودع (موجب)
        # للبيع: qty في payload موجب → خروج من المستودع (سالب)
        stock_qty_signed = qty if is_return else -qty

        # السعر
        if line_in.unit_price_override is not None:
            unit_price = line_in.unit_price_override
            price_list_id = None
            promo_badge = None
            prices_incl_vat = True  # assume inclusive by default
        else:
            unit_price, price_list_id, promo_badge, prices_incl_vat = _resolve_price_for_line(
                db, tenant_id=session.tenant_id, variant=variant, branch=branch,
                qty=qty, at_time=now, customer_group_code=payload.customer_group_code,
            )
        if unit_price is None or unit_price == 0:
            # للمرتجع يُسمح بسعر 0 إذا كان استرداد كامل
            if is_sale:
                raise HTTPException(400, f"Line {idx}: لا يوجد سعر محدّد للمنتج {variant.sku}")

        # الضريبة
        vat_code = product.vat_code if product else "standard"
        if vat_code == "zero_rated":
            vat_rate = Decimal("0")
        elif vat_code == "exempt":
            vat_rate = Decimal("0")
        else:
            vat_rate = default_vat

        # الخصم على مستوى البند
        line_subtotal = (unit_price * qty).quantize(Q2)
        line_discount = Decimal("0")
        if line_in.discount_amount:
            line_discount = line_in.discount_amount.quantize(Q2)
        elif line_in.discount_pct:
            line_discount = (line_subtotal * line_in.discount_pct / Decimal("100")).quantize(Q2)
        line_taxable_before_vat = line_subtotal - line_discount

        # VAT
        if prices_incl_vat and vat_rate > 0:
            # السعر شامل — استخرج VAT
            vat_fraction = vat_rate / (Decimal("100") + vat_rate)
            line_vat = (line_taxable_before_vat * vat_fraction).quantize(Q2)
            line_taxable = (line_taxable_before_vat - line_vat).quantize(Q2)
        else:
            line_taxable = line_taxable_before_vat
            line_vat = (line_taxable * vat_rate / Decimal("100")).quantize(Q2)

        line_total = (line_taxable + line_vat).quantize(Q2)

        # إن كان مرتجع، البنود سالبة في الإجمالي
        if is_return:
            line_subtotal = -line_subtotal
            line_discount = -line_discount
            line_taxable = -line_taxable
            line_vat = -line_vat
            line_total = -line_total

        # StockMovement
        movement = _apply_stock_movement(
            db, session=session, variant=variant, warehouse=warehouse,
            qty_signed=stock_qty_signed,
            unit_cost=variant.default_cost or Decimal("0"),
            reason="pos_return" if is_return else "pos_sale",
            reference_number=receipt_number,
            cashier_user_id=payload.cashier_user_id,
        )

        line = PosTransactionLine(
            tenant_id=session.tenant_id,
            transaction_id=txn.id,
            line_number=idx,
            variant_id=variant.id,
            sku=variant.sku,
            description=(product.name_ar if product else variant.sku),
            barcode_scanned=line_in.barcode_scanned,
            qty=qty if is_sale else qty,   # نخزّن كما أدخله الكاشير
            uom=(product.default_uom if product else "piece"),
            unit_price=unit_price,
            unit_cost=variant.default_cost,
            prices_include_vat=prices_incl_vat,
            discount_pct=line_in.discount_pct,
            discount_amount=abs(line_discount),
            discount_reason=line_in.discount_reason,
            vat_code=vat_code,
            vat_rate_pct=vat_rate,
            line_subtotal=abs(line_subtotal) * (-1 if is_return else 1),
            line_discount=abs(line_discount) * (-1 if is_return else 1),
            line_taxable=line_taxable,
            line_vat=line_vat,
            line_total=line_total,
            price_list_id=price_list_id,
            promo_badge=promo_badge,
            warehouse_id=warehouse.id,
            stock_movement_id=movement.id,
            salesperson_user_id=line_in.salesperson_user_id,
        )
        db.add(line)

        subtotal += line_subtotal
        total_line_discount += line_discount
        total_taxable += line_taxable
        total_vat += line_vat
        grand_line_total += line_total

    db.flush()

    # الخصم على الفاتورة ككل (بعد خصومات البنود)
    invoice_discount = Decimal("0")
    if payload.discount_pct and payload.discount_pct > 0:
        invoice_discount = (grand_line_total * payload.discount_pct / Decimal("100")).quantize(Q2)
        # نطرح بالتناسب من VAT و taxable
        ratio = (grand_line_total - invoice_discount) / grand_line_total if grand_line_total else Decimal("1")
        total_taxable = (total_taxable * ratio).quantize(Q2)
        total_vat = (total_vat * ratio).quantize(Q2)
        grand_line_total = (grand_line_total - invoice_discount).quantize(Q2)

    txn.subtotal = abs(subtotal) if is_sale else -abs(subtotal)
    txn.discount_total = (abs(total_line_discount) + invoice_discount) * (-1 if is_return else 1)
    txn.discount_pct = payload.discount_pct
    txn.taxable_amount = total_taxable
    txn.vat_total = total_vat
    txn.grand_total = grand_line_total

    # الدفعات
    tendered_total = Decimal("0")
    for idx, p in enumerate(payload.payments, start=1):
        pay = PosPayment(
            tenant_id=session.tenant_id,
            transaction_id=txn.id,
            sequence=idx,
            method=p.method,
            amount=p.amount,
            currency=session.currency,
            reference_number=p.reference_number,
            approval_code=p.approval_code,
            terminal_id=p.terminal_id,
            card_last4=p.card_last4,
            card_scheme=p.card_scheme,
            status="captured",
            captured_at=now,
            notes=p.notes,
        )
        db.add(pay)
        tendered_total += p.amount

        # حركة درج نقدية للدفعات النقدية
        if p.method == "cash":
            current_bal = _current_cash_balance(db, session)
            cash_delta = p.amount if is_sale else -p.amount  # مرتجع = رد نقدي (خروج)
            new_bal = current_bal + cash_delta
            db.add(CashMovement(
                tenant_id=session.tenant_id,
                session_id=session.id,
                kind=(CashMovementKind.sale_cash.value if is_sale
                      else CashMovementKind.refund_cash.value),
                amount=cash_delta,
                currency=session.currency,
                transaction_id=txn.id,
                performed_at=now,
                performed_by_user_id=payload.cashier_user_id,
                balance_after=new_bal,
            ))
            db.flush()

    # للبيع: المطلوب أن tendered ≥ grand_total
    if is_sale and tendered_total < grand_line_total:
        db.rollback()
        raise HTTPException(
            400,
            f"الدفعة أقل من المطلوب: المدفوع {tendered_total}, المطلوب {grand_line_total}"
        )

    change = Decimal("0")
    if is_sale:
        change = (tendered_total - grand_line_total).quantize(Q2)
        # إذا كان هناك باقي وتم الدفع نقداً، سجّل خروج صرف باقي
        cash_paid = sum((p.amount for p in payload.payments if p.method == "cash"), Decimal("0"))
        if change > 0 and cash_paid > 0:
            bal = _current_cash_balance(db, session)
            new_bal = bal - change
            db.add(CashMovement(
                tenant_id=session.tenant_id,
                session_id=session.id,
                kind=CashMovementKind.change_given.value,
                amount=-change,
                currency=session.currency,
                transaction_id=txn.id,
                reason="صرف باقي للزبون",
                performed_at=now,
                performed_by_user_id=payload.cashier_user_id,
                balance_after=new_bal,
            ))

    txn.tendered_total = tendered_total
    txn.change_given = change
    txn.status = PosTransactionStatus.completed.value
    txn.completed_at = now

    # ZATCA placeholder (يُملأ لاحقاً في الأسبوع 4)
    txn.zatca_status = "pending"
    # TODO: توليد QR TLV + invoice hash

    # تحديث إحصائيات الوردية
    session.transaction_count = (session.transaction_count or 0) + 1
    if is_sale:
        session.sale_count = (session.sale_count or 0) + 1
        session.gross_sales = (session.gross_sales or Decimal("0")) + abs(subtotal)
        session.discount_total = (session.discount_total or Decimal("0")) + abs(total_line_discount) + invoice_discount
        session.vat_total = (session.vat_total or Decimal("0")) + total_vat
        session.net_sales = (session.net_sales or Decimal("0")) + grand_line_total
    elif is_return:
        session.return_count = (session.return_count or 0) + 1
        session.gross_sales = (session.gross_sales or Decimal("0")) - abs(subtotal)
        session.net_sales = (session.net_sales or Decimal("0")) + grand_line_total  # سالب
        session.vat_total = (session.vat_total or Decimal("0")) + total_vat  # سالب

    # إذا مرتجع كامل للفاتورة الأصلية، علّمها
    if is_return and payload.original_transaction_id:
        orig = db.query(PosTransaction).filter(
            PosTransaction.id == payload.original_transaction_id
        ).first()
        if orig:
            # تقريبي: إذا المبلغ المرتجع ≥ الأصلي → refunded كامل
            if abs(grand_line_total) >= orig.grand_total * Decimal("0.99"):
                orig.status = PosTransactionStatus.refunded.value
            else:
                orig.status = PosTransactionStatus.partial_refund.value

    db.commit()
    db.refresh(txn)

    # بناء الاستجابة
    lines = db.query(PosTransactionLine).filter(
        PosTransactionLine.transaction_id == txn.id
    ).order_by(PosTransactionLine.line_number).all()
    payments = db.query(PosPayment).filter(
        PosPayment.transaction_id == txn.id
    ).order_by(PosPayment.sequence).all()

    return PosTransactionDetail(
        **PosTransactionRead.model_validate(txn).model_dump(),
        lines=[PosLineRead.model_validate(lv) for lv in lines],
        payments=[PosPaymentRead.model_validate(p) for p in payments],
    )


@router.get("/pos-sessions/{session_id}/transactions", response_model=list[PosTransactionRead])
def list_session_transactions(
    session_id: str,
    kind: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    _session_or_404(db, session_id)
    q = db.query(PosTransaction).filter(PosTransaction.session_id == session_id)
    if kind:
        q = q.filter(PosTransaction.kind == kind)
    if status:
        q = q.filter(PosTransaction.status == status)
    return q.order_by(PosTransaction.transacted_at.desc()).limit(limit).all()


@router.get("/pos-transactions/{transaction_id}", response_model=PosTransactionDetail)
def get_transaction(transaction_id: str, db: Session = Depends(get_db)):
    txn = _txn_or_404(db, transaction_id)
    lines = db.query(PosTransactionLine).filter(
        PosTransactionLine.transaction_id == txn.id
    ).order_by(PosTransactionLine.line_number).all()
    payments = db.query(PosPayment).filter(
        PosPayment.transaction_id == txn.id
    ).order_by(PosPayment.sequence).all()
    return PosTransactionDetail(
        **PosTransactionRead.model_validate(txn).model_dump(),
        lines=[PosLineRead.model_validate(lv) for lv in lines],
        payments=[PosPaymentRead.model_validate(p) for p in payments],
    )


@router.post("/pos-transactions/{transaction_id}/void", response_model=PosTransactionRead)
def void_transaction(transaction_id: str, payload: PosVoidRequest, db: Session = Depends(get_db)):
    """إلغاء فاتورة — يعكس المخزون والنقد."""
    txn = _txn_or_404(db, transaction_id)
    if txn.status == PosTransactionStatus.voided.value:
        raise HTTPException(409, "الفاتورة مُلغاة مسبقاً")
    if txn.status not in (PosTransactionStatus.completed.value, PosTransactionStatus.draft.value):
        raise HTTPException(409, f"لا يمكن إلغاء فاتورة بحالة {txn.status}")

    session = _session_or_404(db, txn.session_id)
    if session.status != PosSessionStatus.open.value:
        raise HTTPException(409, "الإلغاء يتطلب وردية مفتوحة")

    now = datetime.now(timezone.utc)

    # عكس المخزون
    lines = db.query(PosTransactionLine).filter(
        PosTransactionLine.transaction_id == txn.id
    ).all()
    for line in lines:
        if line.stock_movement_id:
            orig_mv = db.query(StockMovement).filter(
                StockMovement.id == line.stock_movement_id
            ).first()
            if orig_mv:
                variant = db.query(ProductVariant).filter(
                    ProductVariant.id == line.variant_id
                ).first()
                warehouse = db.query(Warehouse).filter(
                    Warehouse.id == line.warehouse_id
                ).first()
                _apply_stock_movement(
                    db, session=session, variant=variant, warehouse=warehouse,
                    qty_signed=-orig_mv.qty,
                    unit_cost=orig_mv.unit_cost or Decimal("0"),
                    reason="void_reversal",
                    reference_number=f"VOID-{txn.receipt_number}",
                    cashier_user_id=payload.voided_by_user_id,
                )

    # عكس الدفعات النقدية — صافي الأثر على الدرج = cash payments - change_given
    # مثال: دُفع 100 نقد وأُعيد 1 باقي → الدرج زاد 99 فعلاً → عند الإلغاء نرد 99
    cash_payments = db.query(PosPayment).filter(
        PosPayment.transaction_id == txn.id,
        PosPayment.method == "cash",
    ).all()
    total_cash_paid = sum((cp.amount for cp in cash_payments), Decimal("0"))
    if total_cash_paid > 0:
        net_cash_impact = total_cash_paid - (txn.change_given or Decimal("0"))
        bal = _current_cash_balance(db, session)
        new_bal = bal - net_cash_impact
        db.add(CashMovement(
            tenant_id=session.tenant_id,
            session_id=session.id,
            kind=CashMovementKind.refund_cash.value,
            amount=-net_cash_impact,
            currency=session.currency,
            transaction_id=txn.id,
            reason=f"إلغاء فاتورة {txn.receipt_number}",
            performed_at=now,
            performed_by_user_id=payload.voided_by_user_id,
            balance_after=new_bal,
        ))
    for cp in cash_payments:
        cp.status = "reversed"
        cp.refunded_at = now
    # الدفعات غير النقدية (مدى/فيزا) تُعلَّم reversed أيضاً — الاسترداد يتم عبر البوابة
    non_cash = db.query(PosPayment).filter(
        PosPayment.transaction_id == txn.id,
        PosPayment.method != "cash",
    ).all()
    for ncp in non_cash:
        ncp.status = "reversed"
        ncp.refunded_at = now

    txn.status = PosTransactionStatus.voided.value
    txn.voided_at = now
    txn.reason_text = payload.reason_text

    # تحديث إحصائيات الوردية
    session.void_count = (session.void_count or 0) + 1
    session.net_sales = (session.net_sales or Decimal("0")) - txn.grand_total
    session.vat_total = (session.vat_total or Decimal("0")) - txn.vat_total
    session.gross_sales = (session.gross_sales or Decimal("0")) - abs(txn.subtotal)

    db.commit()
    db.refresh(txn)
    return txn


# ══════════════════════════════════════════════════════════════════════════
# Cash drawer
# ══════════════════════════════════════════════════════════════════════════

@router.post("/pos-sessions/{session_id}/cash-movements", response_model=CashMovementRead, status_code=201)
def add_cash_movement(session_id: str, payload: CashMovementCreate, db: Session = Depends(get_db)):
    """إيداع/سحب من الدرج — paid_in / paid_out فقط."""
    session = _open_session_or_409(db, session_id)
    now = datetime.now(timezone.utc)
    current_bal = _current_cash_balance(db, session)
    delta = payload.amount if payload.kind == "paid_in" else -payload.amount
    new_bal = current_bal + delta
    if new_bal < 0:
        raise HTTPException(409, f"رصيد غير كافٍ: {current_bal}, المطلوب سحبه {payload.amount}")

    mv = CashMovement(
        tenant_id=session.tenant_id,
        session_id=session.id,
        kind=payload.kind,
        amount=delta,
        currency=session.currency,
        reason=payload.reason,
        reference_number=payload.reference_number,
        performed_at=now,
        performed_by_user_id=payload.performed_by_user_id,
        approved_by_user_id=payload.approved_by_user_id,
        balance_after=new_bal,
    )
    db.add(mv)
    db.commit()
    db.refresh(mv)
    return mv


@router.get("/pos-sessions/{session_id}/cash-movements", response_model=list[CashMovementRead])
def list_cash_movements(session_id: str, db: Session = Depends(get_db)):
    _session_or_404(db, session_id)
    return db.query(CashMovement).filter(
        CashMovement.session_id == session_id
    ).order_by(CashMovement.performed_at.asc()).all()
