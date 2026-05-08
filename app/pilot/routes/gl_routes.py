"""GL routes — Chart of Accounts, Fiscal Periods, Journal Entries, Reports."""

from datetime import date as _date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.phase1.routes.phase1_routes import get_current_user
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
    compute_cash_flow, compute_account_ledger, compute_comparative_report,
    auto_post_pos_sale,
)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot-gl"],
    dependencies=[Depends(get_current_user)],
)


def _entity_or_404(
    db: Session,
    eid: str,
    *,
    current_user: Optional[dict] = None,
) -> Entity:
    """Resolve an entity, enforcing tenant isolation when a user is given.

    G-TB-REAL-DATA-AUDIT (2026-05-08): the previous form filtered only
    on `Entity.id == eid`, which let user A pull tenant B's GL reports
    just by knowing or guessing B's entity id. The pilot models don't
    inherit from `TenantMixin`, so the application-layer
    `attach_tenant_guard` auto-filter doesn't apply to these queries —
    isolation has to live in the route handler. Now:

      * Without `current_user` (legacy callers / internal tooling),
        the function behaves as before: 404 if the entity doesn't
        exist; no tenant check.
      * With `current_user` (any user-facing route — and that's the
        whole pilot GL surface), the function additionally verifies
        the entity's tenant_id matches the JWT's `tenant_id` claim.
        Mismatch → 403, never 404, so an attacker can't probe
        existence by interpreting status codes.

    Legacy users whose JWT predates ERR-2 Phase 3 (no `tenant_id`
    claim) can't access the pilot GL surface — their token resolves
    to `None` and any entity row returns 403. The fix is to migrate
    them via /admin/migrate-legacy-tenants (PR #170) and re-issue
    their token on next login (PR #169 handles this automatically).
    """
    e = db.query(Entity).filter(
        Entity.id == eid,
        Entity.is_deleted == False,  # noqa: E712
    ).first()
    if not e:
        raise HTTPException(404, f"Entity {eid} not found")
    if current_user is not None:
        user_tenant = current_user.get("tenant_id") or current_user.get("tid")
        if not user_tenant or str(e.tenant_id) != str(user_tenant):
            # Forbidden, not 404 — explicit 403 lets the frontend
            # show "this isn't your entity" rather than retrying as
            # if it just doesn't exist.
            raise HTTPException(
                403,
                "Access denied — entity belongs to a different tenant",
            )
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
def seed_coa(
    entity_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """بذر شجرة الحسابات الافتراضية (SOCPA) لكيان."""
    e = _entity_or_404(db, entity_id, current_user=current_user)
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
    current_user: dict = Depends(get_current_user),
):
    _entity_or_404(db, entity_id, current_user=current_user)
    q = db.query(GLAccount).filter(GLAccount.entity_id == entity_id)
    if category:
        q = q.filter(GLAccount.category == category)
    if type:
        q = q.filter(GLAccount.type == type)
    if not include_inactive:
        q = q.filter(GLAccount.is_active == True)  # noqa: E712
    return q.order_by(GLAccount.code).all()


@router.post("/entities/{entity_id}/accounts", response_model=GLAccountRead, status_code=201)
def create_account(
    entity_id: str,
    payload: GLAccountCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = _entity_or_404(db, entity_id, current_user=current_user)
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


@router.patch("/accounts/{account_id}", response_model=GLAccountRead)
def update_account(account_id: str, payload: dict, db: Session = Depends(get_db)):
    """تعديل حساب — مع حماية: لا يمكن تغيير category/normal_balance
    إذا كانت هناك postings على الحساب (لتجنب كسر TB)."""
    acc = db.query(GLAccount).filter(GLAccount.id == account_id).first()
    if not acc:
        raise HTTPException(404, "الحساب غير موجود")
    # فحص postings
    has_postings = db.query(GLPosting).filter(
        GLPosting.account_id == account_id
    ).first() is not None
    immutable = {"entity_id", "tenant_id", "id"}
    protected = {"category", "normal_balance", "code"}
    allowed = {
        "name_ar", "name_en", "subcategory", "type", "currency",
        "is_active", "is_control", "require_cost_center",
        "require_profit_center", "default_vat_code",
    }
    for key, value in payload.items():
        if key in immutable:
            continue  # لا يُسمح أبداً بتعديل هذه
        if key in protected:
            if has_postings:
                raise HTTPException(
                    409,
                    f"لا يمكن تغيير '{key}' — الحساب فيه حركات محاسبية. "
                    f"أنشئ حساباً جديداً وحوّل الأرصدة."
                )
            # لا postings → السماح بالتعديل (مثل code, category, normal_balance)
        elif key not in allowed:
            continue  # حقل غير معروف — تجاهل
        setattr(acc, key, value)
    db.commit()
    db.refresh(acc)
    return acc


@router.delete("/accounts/{account_id}", status_code=204)
def delete_account(account_id: str, db: Session = Depends(get_db)):
    """حذف حساب — مسموح فقط لو لا توجد postings ولا هو system account."""
    acc = db.query(GLAccount).filter(GLAccount.id == account_id).first()
    if not acc:
        raise HTTPException(404, "الحساب غير موجود")
    if acc.is_system:
        raise HTTPException(403, "حسابات النظام محميّة من الحذف. يمكن تعطيلها (is_active=false).")
    has_postings = db.query(GLPosting).filter(
        GLPosting.account_id == account_id
    ).first() is not None
    if has_postings:
        raise HTTPException(
            409,
            "الحساب فيه حركات محاسبية — لا يمكن حذفه. قم بتعطيله بدلاً من ذلك."
        )
    # فحص الأبناء
    has_children = db.query(GLAccount).filter(
        GLAccount.parent_account_id == account_id
    ).first() is not None
    if has_children:
        raise HTTPException(409, "الحساب فيه حسابات فرعية — احذفها أولاً.")
    db.delete(acc)
    db.commit()


# ══════════════════════════════════════════════════════════════════════════
# Fiscal Periods
# ══════════════════════════════════════════════════════════════════════════

@router.post("/entities/{entity_id}/fiscal-periods/seed")
def seed_periods(
    entity_id: str,
    payload: FiscalPeriodSeed,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = _entity_or_404(db, entity_id, current_user=current_user)
    res = seed_fiscal_periods(db, e, payload.year)
    db.commit()
    return {"success": True, "entity_id": entity_id, **res}


@router.get("/entities/{entity_id}/fiscal-periods", response_model=list[FiscalPeriodRead])
def list_periods(
    entity_id: str,
    year: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    _entity_or_404(db, entity_id, current_user=current_user)
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
def create_je(
    payload: JournalEntryCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = _entity_or_404(db, payload.entity_id, current_user=current_user)
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
    current_user: dict = Depends(get_current_user),
):
    _entity_or_404(db, entity_id, current_user=current_user)
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
    # G-TB-REAL-DATA-AUDIT (2026-05-08): explicit current_user dep so
    # _entity_or_404 can enforce tenant isolation. Without this the
    # router-level dependency authenticates the request but doesn't
    # expose the JWT payload to the handler — and the prior
    # implementation read 0 fields from it, so any authenticated user
    # could pull any entity's TB. Now the handler refuses with 403 if
    # the entity belongs to a different tenant than the JWT claim.
    current_user: dict = Depends(get_current_user),
):
    _entity_or_404(db, entity_id, current_user=current_user)
    as_of_date = as_of or datetime.now(timezone.utc).date()
    rows = compute_trial_balance(db, entity_id=entity_id, as_of_date=as_of_date, include_zero=include_zero)
    total_debit = sum((r["total_debit"] for r in rows), Decimal("0"))
    total_credit = sum((r["total_credit"] for r in rows), Decimal("0"))
    # G-TB-REAL-DATA-AUDIT (2026-05-08): include the count of posted
    # JEs that fed this TB so the frontend can render the
    # "المصدر: pilot_journal_lines — N قيد مرحّل" footer without a
    # second roundtrip. Counts only `status='posted'` to match what
    # `compute_trial_balance` actually queried.
    posted_je_count = (
        db.query(JournalEntry)
        .filter(
            JournalEntry.entity_id == entity_id,
            JournalEntry.status == JournalEntryStatus.posted.value,
            JournalEntry.je_date <= as_of_date,
        )
        .count()
    )
    return TrialBalanceResponse(
        entity_id=entity_id,
        as_of_date=as_of_date,
        rows=[TrialBalanceRow(**r) for r in rows],
        total_debit=total_debit,
        total_credit=total_credit,
        balanced=(total_debit == total_credit),
        posted_je_count=posted_je_count,
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


@router.get("/entities/{entity_id}/reports/cash-flow")
def cash_flow(
    entity_id: str,
    start_date: _date = Query(...),
    end_date: _date = Query(...),
    db: Session = Depends(get_db),
):
    """قائمة التدفقات النقدية (طريقة غير مباشرة).

    Net Income + Depreciation ± Working Capital Changes = Operating CF
    """
    _entity_or_404(db, entity_id)
    if end_date < start_date:
        raise HTTPException(400, "end_date يجب أن يكون ≥ start_date")
    return compute_cash_flow(
        db, entity_id=entity_id, start_date=start_date, end_date=end_date
    )


@router.get("/entities/{entity_id}/reports/comparative")
def comparative_report(
    entity_id: str,
    report_type: str = Query(...,
        pattern="^(income_statement|balance_sheet)$",
        description="income_statement | balance_sheet"),
    current_start: _date = Query(...),
    current_end: _date = Query(...),
    prior_start: Optional[_date] = Query(None, description="افتراضياً نفس الفترة من السنة السابقة"),
    prior_end: Optional[_date] = Query(None),
    db: Session = Depends(get_db),
):
    """تقرير مقارن — الحالي vs سابق (افتراضياً السنة السابقة)."""
    _entity_or_404(db, entity_id)
    try:
        return compute_comparative_report(
            db, entity_id=entity_id, report_type=report_type,
            current_start=current_start, current_end=current_end,
            prior_start=prior_start, prior_end=prior_end,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.get("/_debug/entities/{entity_id}/posting-counts")
def debug_posting_counts(entity_id: str, db: Session = Depends(get_db)):
    """DIAGNOSTIC — raw counts of JEs, lines, postings for an entity.

    Helps catch silent GL-posting failures (e.g., JE.status='posted' but no
    GLPosting rows). Not for production UI.
    """
    from sqlalchemy import func as sqlfunc
    je_total = db.query(JournalEntry).filter(JournalEntry.entity_id == entity_id).count()
    je_posted = db.query(JournalEntry).filter(
        JournalEntry.entity_id == entity_id,
        JournalEntry.status == JournalEntryStatus.posted.value,
    ).count()
    posting_count = db.query(GLPosting).filter(GLPosting.entity_id == entity_id).count()
    posting_sum = db.query(
        sqlfunc.coalesce(sqlfunc.sum(GLPosting.debit_amount), 0).label("d"),
        sqlfunc.coalesce(sqlfunc.sum(GLPosting.credit_amount), 0).label("c"),
    ).filter(GLPosting.entity_id == entity_id).first()
    # Sample: what distinct entity_ids exist on postings? (helps spot mis-assignment)
    distinct_entities = [
        r[0] for r in db.query(GLPosting.entity_id).distinct().limit(20).all()
    ]
    # Latest JE details
    latest_je = db.query(JournalEntry).filter(
        JournalEntry.entity_id == entity_id
    ).order_by(JournalEntry.created_at.desc()).first()
    latest_je_info = None
    if latest_je:
        line_count = db.query(JournalLine).filter(
            JournalLine.journal_entry_id == latest_je.id
        ).count()
        post_count = db.query(GLPosting).filter(
            GLPosting.journal_entry_id == latest_je.id
        ).count()
        latest_je_info = {
            "id": latest_je.id,
            "je_number": latest_je.je_number,
            "status": latest_je.status,
            "posted_at": latest_je.posted_at.isoformat() if latest_je.posted_at else None,
            "posting_date": latest_je.posting_date.isoformat() if latest_je.posting_date else None,
            "total_debit": float(latest_je.total_debit or 0),
            "fiscal_period_id": latest_je.fiscal_period_id,
            "line_count": line_count,
            "gl_posting_count": post_count,
        }
    return {
        "_deploy_marker": "v3-flush-fix",
        "entity_id": entity_id,
        "je_total": je_total,
        "je_posted": je_posted,
        "gl_posting_count": posting_count,
        "gl_posting_sum_debit": float(posting_sum[0] or 0),
        "gl_posting_sum_credit": float(posting_sum[1] or 0),
        "distinct_entity_ids_on_postings": distinct_entities,
        "latest_je": latest_je_info,
    }


@router.get("/accounts/{account_id}/ledger")
def account_ledger(
    account_id: str,
    start_date: Optional[_date] = Query(None, description="افتراضياً بداية السنة"),
    end_date: Optional[_date] = Query(None, description="افتراضياً اليوم"),
    limit: int = Query(500, le=2000),
    db: Session = Depends(get_db),
):
    """دفتر الأستاذ لحساب واحد — تفصيل كل حركاته مع running balance.

    الاستخدام: drill-down من Trial Balance → ضغط على حساب → ترى كل حركاته.
    """
    today = datetime.now(timezone.utc).date()
    sd = start_date or _date(today.year, 1, 1)
    ed = end_date or today
    if ed < sd:
        raise HTTPException(400, "end_date يجب أن يكون ≥ start_date")
    try:
        return compute_account_ledger(
            db, account_id=account_id, start_date=sd, end_date=ed, limit=limit
        )
    except ValueError as e:
        raise HTTPException(404, str(e))
