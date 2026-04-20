"""GL routes — Chart of Accounts, Fiscal Periods, Journal Entries, Reports."""

from datetime import date as _date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.pilot.models import (
    Entity, GLAccount, AccountType,
    FiscalPeriod, PeriodStatus,
    JournalEntry, JournalLine, GLPosting,
    JournalEntryStatus,
    PosTransaction,
)
from app.pilot.schemas.gl import (
    GLAccountCreate, GLAccountRead,
    FiscalPeriodRead, FiscalPeriodSeed, FiscalPeriodClose,
    JournalEntryCreate, JournalEntryRead, JournalEntryDetail,
    JournalLineRead, JEReverse,
    TrialBalanceResponse, TrialBalanceRow,
    IncomeStatementResponse, BalanceSheetResponse,
)
from app.pilot.services.gl_engine import (
    seed_default_coa, seed_fiscal_periods,
    build_journal_entry, post_journal_entry, reverse_journal_entry,
    compute_trial_balance, compute_income_statement, compute_balance_sheet,
    auto_post_pos_sale,
)

router = APIRouter(prefix="/pilot", tags=["pilot-gl"])


def _entity_or_404(db: Session, eid: str) -> Entity:
    e = db.query(Entity).filter(Entity.id == eid, Entity.is_deleted == False).first()  # noqa: E712
    if not e:
        raise HTTPException(404, f"Entity {eid} not found")
    return e


def _je_or_404(db: Session, jid: str) -> JournalEntry:
    j = db.query(JournalEntry).filter(JournalEntry.id == jid).first()
    if not j:
        raise HTTPException(404, f"JournalEntry {jid} not found")
    return j


# ══════════════════════════════════════════════════════════════════════════
# CoA
# ══════════════════════════════════════════════════════════════════════════

@router.post("/entities/{entity_id}/coa/seed")
def seed_coa(entity_id: str, db: Session = Depends(get_db)):
    """بذر شجرة الحسابات الافتراضية (SOCPA) لكيان."""
    e = _entity_or_404(db, entity_id)
    res = seed_default_coa(db, e)
    db.commit()
    return {"success": True, "entity_id": entity_id, **res}


@router.get("/entities/{entity_id}/accounts", response_model=list[GLAccountRead])
def list_accounts(
    entity_id: str,
    category: Optional[str] = Query(None),
    type: Optional[str] = Query(None, description="header | detail"),
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    q = db.query(GLAccount).filter(GLAccount.entity_id == entity_id)
    if category:
        q = q.filter(GLAccount.category == category)
    if type:
        q = q.filter(GLAccount.type == type)
    if not include_inactive:
        q = q.filter(GLAccount.is_active == True)  # noqa: E712
    return q.order_by(GLAccount.code).all()


@router.post("/entities/{entity_id}/accounts", response_model=GLAccountRead, status_code=201)
def create_account(entity_id: str, payload: GLAccountCreate, db: Session = Depends(get_db)):
    e = _entity_or_404(db, entity_id)
    if db.query(GLAccount).filter(GLAccount.entity_id == entity_id, GLAccount.code == payload.code).first():
        raise HTTPException(409, f"الحساب {payload.code} موجود مسبقاً")
    parent_level = 1
    if payload.parent_account_id:
        parent = db.query(GLAccount).filter(
            GLAccount.id == payload.parent_account_id, GLAccount.entity_id == entity_id
        ).first()
        if not parent:
            raise HTTPException(400, "الحساب الأب غير موجود")
        parent_level = parent.level + 1
    a = GLAccount(
        tenant_id=e.tenant_id, entity_id=entity_id, level=parent_level,
        **payload.model_dump(),
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    return a


# ══════════════════════════════════════════════════════════════════════════
# Fiscal Periods
# ══════════════════════════════════════════════════════════════════════════

@router.post("/entities/{entity_id}/fiscal-periods/seed")
def seed_periods(entity_id: str, payload: FiscalPeriodSeed, db: Session = Depends(get_db)):
    e = _entity_or_404(db, entity_id)
    res = seed_fiscal_periods(db, e, payload.year)
    db.commit()
    return {"success": True, "entity_id": entity_id, **res}


@router.get("/entities/{entity_id}/fiscal-periods", response_model=list[FiscalPeriodRead])
def list_periods(
    entity_id: str,
    year: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    q = db.query(FiscalPeriod).filter(FiscalPeriod.entity_id == entity_id)
    if year:
        q = q.filter(FiscalPeriod.year == year)
    if status:
        q = q.filter(FiscalPeriod.status == status)
    return q.order_by(FiscalPeriod.start_date).all()


@router.post("/fiscal-periods/{period_id}/close", response_model=FiscalPeriodRead)
def close_period(period_id: str, payload: FiscalPeriodClose, db: Session = Depends(get_db)):
    p = db.query(FiscalPeriod).filter(FiscalPeriod.id == period_id).first()
    if not p:
        raise HTTPException(404, "الفترة غير موجودة")
    if p.status == PeriodStatus.closed.value:
        raise HTTPException(409, "الفترة مُقفلة مسبقاً")
    # تحقق لا يوجد قيود في حالة draft/submitted/approved
    open_jes = db.query(JournalEntry).filter(
        JournalEntry.fiscal_period_id == period_id,
        JournalEntry.status.in_([
            JournalEntryStatus.draft.value,
            JournalEntryStatus.submitted.value,
            JournalEntryStatus.approved.value,
        ]),
    ).count()
    if open_jes > 0:
        raise HTTPException(409, f"لا يمكن الإقفال — يوجد {open_jes} قيد غير مُرحَّل")
    p.status = PeriodStatus.closed.value
    p.closed_at = datetime.now(timezone.utc)
    p.closed_by_user_id = payload.closed_by_user_id
    db.commit()
    db.refresh(p)
    return p


# ══════════════════════════════════════════════════════════════════════════
# Journal Entries
# ══════════════════════════════════════════════════════════════════════════

@router.post("/journal-entries", response_model=JournalEntryDetail, status_code=201)
def create_je(payload: JournalEntryCreate, db: Session = Depends(get_db)):
    e = _entity_or_404(db, payload.entity_id)
    try:
        je = build_journal_entry(
            db, entity=e,
            kind=payload.kind,
            je_date=payload.je_date,
            memo_ar=payload.memo_ar,
            memo_en=payload.memo_en,
            lines_input=[ln.model_dump() for ln in payload.lines],
            source_type=payload.source_type,
            source_id=payload.source_id,
            source_reference=payload.source_reference,
            created_by_user_id=payload.created_by_user_id,
            auto_post=payload.auto_post,
        )
        db.commit()
        db.refresh(je)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))

    lines = db.query(JournalLine).filter(
        JournalLine.journal_entry_id == je.id
    ).order_by(JournalLine.line_number).all()
    return JournalEntryDetail(
        **JournalEntryRead.model_validate(je).model_dump(),
        lines=[JournalLineRead.model_validate(lv) for lv in lines],
    )


@router.get("/entities/{entity_id}/journal-entries", response_model=list[JournalEntryRead])
def list_jes(
    entity_id: str,
    status: Optional[str] = Query(None),
    kind: Optional[str] = Query(None),
    period_id: Optional[str] = Query(None),
    source_type: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    q = db.query(JournalEntry).filter(JournalEntry.entity_id == entity_id)
    if status:
        q = q.filter(JournalEntry.status == status)
    if kind:
        q = q.filter(JournalEntry.kind == kind)
    if period_id:
        q = q.filter(JournalEntry.fiscal_period_id == period_id)
    if source_type:
        q = q.filter(JournalEntry.source_type == source_type)
    return q.order_by(JournalEntry.je_date.desc(), JournalEntry.je_number.desc()).limit(limit).all()


@router.get("/journal-entries/{je_id}", response_model=JournalEntryDetail)
def get_je(je_id: str, db: Session = Depends(get_db)):
    je = _je_or_404(db, je_id)
    lines = db.query(JournalLine).filter(
        JournalLine.journal_entry_id == je.id
    ).order_by(JournalLine.line_number).all()
    return JournalEntryDetail(
        **JournalEntryRead.model_validate(je).model_dump(),
        lines=[JournalLineRead.model_validate(lv) for lv in lines],
    )


@router.post("/journal-entries/{je_id}/post", response_model=JournalEntryRead)
def post_je(je_id: str, db: Session = Depends(get_db)):
    try:
        je = post_journal_entry(db, je_id)
        db.commit()
        db.refresh(je)
        return je
    except ValueError as ex:
        db.rollback()
        raise HTTPException(409, str(ex))


@router.post("/journal-entries/{je_id}/reverse", response_model=JournalEntryDetail)
def reverse_je(je_id: str, payload: JEReverse, db: Session = Depends(get_db)):
    try:
        rev = reverse_journal_entry(db, je_id, payload.reversal_date, payload.memo_ar, payload.user_id)
        db.commit()
        db.refresh(rev)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(409, str(ex))
    lines = db.query(JournalLine).filter(
        JournalLine.journal_entry_id == rev.id
    ).order_by(JournalLine.line_number).all()
    return JournalEntryDetail(
        **JournalEntryRead.model_validate(rev).model_dump(),
        lines=[JournalLineRead.model_validate(lv) for lv in lines],
    )


# ══════════════════════════════════════════════════════════════════════════
# Auto-posting from POS
# ══════════════════════════════════════════════════════════════════════════

@router.post("/pos-transactions/{pos_txn_id}/post-to-gl", response_model=JournalEntryDetail)
def post_pos_to_gl(pos_txn_id: str, db: Session = Depends(get_db)):
    """ترحيل معاملة POS تلقائياً إلى الأستاذ العام."""
    try:
        je = auto_post_pos_sale(db, pos_txn_id, auto_post=True)
        db.commit()
        db.refresh(je)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(409, str(ex))
    lines = db.query(JournalLine).filter(
        JournalLine.journal_entry_id == je.id
    ).order_by(JournalLine.line_number).all()
    return JournalEntryDetail(
        **JournalEntryRead.model_validate(je).model_dump(),
        lines=[JournalLineRead.model_validate(lv) for lv in lines],
    )


# ══════════════════════════════════════════════════════════════════════════
# Reports
# ══════════════════════════════════════════════════════════════════════════

@router.get("/entities/{entity_id}/reports/trial-balance", response_model=TrialBalanceResponse)
def trial_balance(
    entity_id: str,
    as_of: Optional[_date] = Query(None, description="افتراضياً اليوم"),
    include_zero: bool = Query(False),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    as_of_date = as_of or datetime.now(timezone.utc).date()
    rows = compute_trial_balance(db, entity_id=entity_id, as_of_date=as_of_date, include_zero=include_zero)
    total_debit = sum((r["total_debit"] for r in rows), Decimal("0"))
    total_credit = sum((r["total_credit"] for r in rows), Decimal("0"))
    return TrialBalanceResponse(
        entity_id=entity_id,
        as_of_date=as_of_date,
        rows=[TrialBalanceRow(**r) for r in rows],
        total_debit=total_debit,
        total_credit=total_credit,
        balanced=(total_debit == total_credit),
    )


@router.get("/entities/{entity_id}/reports/income-statement", response_model=IncomeStatementResponse)
def income_statement(
    entity_id: str,
    start_date: _date = Query(...),
    end_date: _date = Query(...),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    if end_date < start_date:
        raise HTTPException(400, "end_date يجب أن يكون ≥ start_date")
    result = compute_income_statement(db, entity_id=entity_id, start_date=start_date, end_date=end_date)
    return IncomeStatementResponse(**result)


@router.get("/entities/{entity_id}/reports/balance-sheet", response_model=BalanceSheetResponse)
def balance_sheet(
    entity_id: str,
    as_of: Optional[_date] = Query(None),
    db: Session = Depends(get_db),
):
    _entity_or_404(db, entity_id)
    as_of_date = as_of or datetime.now(timezone.utc).date()
    result = compute_balance_sheet(db, entity_id=entity_id, as_of_date=as_of_date)
    return BalanceSheetResponse(**result)
