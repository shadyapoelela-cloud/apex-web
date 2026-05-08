"""G-FIN-CF-1 — Cash Flow Statement real-data + reconciliation audit.

Three non-negotiable contracts pinned here:

1. **Real data.** Every value sourced from `pilot_gl_postings`. No
   mocks, fallbacks, defaults, demo seeds. The prior implementation
   had a `try/except: Decimal("0")` fallback that silently swallowed
   exceptions; the new one propagates failures so a broken data path
   is visible.

2. **Reconciliation invariant.** `opening_cash + (CFO + CFI + CFF)`
   must equal `closing_cash` within Q2 (0.01) tolerance. When the
   equation breaks (data integrity issue or unmapped subcategory),
   `is_reconciled=False` is returned and a structured warning is
   logged — never silenced.

3. **Subcategory coverage.** Every asset/liability/equity subcategory
   in the entity's CoA must map to a CF section. Custom subcategories
   not in `_CF_SECTION_MAP` surface in `unmapped_subcategories` so
   admins can either map them or document the exclusion. The
   anti-mock tests pin both the surface and the no-bypass behavior.

Fixtures shortcut JE → GLPosting via direct row inserts (same pattern
as test_balance_sheet_real_data.py / test_income_statement_real_data.py
/ test_tb_real_data_flow.py).
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Optional

import pytest

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.phase1.services.auth_service import create_access_token
from app.pilot.models.entity import Entity
from app.pilot.models.gl import (
    AccountType,
    FiscalPeriod,
    GLAccount,
    GLPosting,
    JournalEntry,
    JournalEntryStatus,
    JournalLine,
    NormalBalance,
    PeriodStatus,
)
from app.pilot.models.tenant import Tenant


# ────────────────────────────────────────────────────────────────────
# Fixtures
# ────────────────────────────────────────────────────────────────────


def _mk_tenant(s, suffix: str) -> Tenant:
    t = Tenant(
        id=gen_uuid(),
        slug=f"cf-{suffix}-{uuid.uuid4().hex[:6]}",
        legal_name_ar=f"اختبار CF {suffix}",
        primary_email=f"cf_{suffix}_{uuid.uuid4().hex[:4]}@example.test",
        primary_country="SA",
    )
    s.add(t)
    s.flush()
    return t


def _mk_entity(s, tenant: Tenant, suffix: str) -> Entity:
    e = Entity(
        id=gen_uuid(),
        tenant_id=tenant.id,
        code=f"E-CF-{suffix}-{uuid.uuid4().hex[:4]}",
        name_ar=f"كيان {suffix}",
        country="SA",
        functional_currency="SAR",
    )
    s.add(e)
    s.flush()
    return e


def _mk_period(s, tenant: Tenant, entity: Entity, when: date) -> FiscalPeriod:
    p = FiscalPeriod(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        code=f"FP-{when.year}-{when.month:02d}-{uuid.uuid4().hex[:4]}",
        name_ar=f"الفترة {when.year}-{when.month:02d}",
        year=when.year,
        month=when.month,
        start_date=when.replace(day=1),
        end_date=when.replace(day=28),
        status=PeriodStatus.open.value,
    )
    s.add(p)
    s.flush()
    return p


def _mk_account(
    s,
    tenant: Tenant,
    entity: Entity,
    *,
    code: str,
    name_ar: str,
    category: str,
    subcategory: Optional[str] = None,
    normal: Optional[str] = None,
) -> GLAccount:
    if normal is None:
        normal = (
            NormalBalance.credit.value
            if category in ("liability", "equity", "revenue")
            else NormalBalance.debit.value
        )
    a = GLAccount(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        code=code,
        name_ar=name_ar,
        category=category,
        subcategory=subcategory,
        type=AccountType.detail.value,
        normal_balance=normal,
        is_active=True,
    )
    s.add(a)
    s.flush()
    return a


def _mk_posted_je(
    s,
    tenant: Tenant,
    entity: Entity,
    period: FiscalPeriod,
    *,
    debit_account: GLAccount,
    credit_account: GLAccount,
    amount: Decimal,
    je_date: date,
) -> JournalEntry:
    je = JournalEntry(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        fiscal_period_id=period.id,
        je_number=f"JE-CF-{uuid.uuid4().hex[:8]}",
        kind="manual",
        status=JournalEntryStatus.posted.value,
        memo_ar="اختبار CF",
        je_date=je_date,
        posting_date=je_date,
        currency="SAR",
        total_debit=amount,
        total_credit=amount,
        posted_at=datetime.now(timezone.utc),
    )
    s.add(je)
    s.flush()

    line1 = JournalLine(
        id=gen_uuid(),
        tenant_id=tenant.id,
        journal_entry_id=je.id,
        line_number=1,
        account_id=debit_account.id,
        currency="SAR",
        debit_amount=amount,
        credit_amount=Decimal("0"),
        functional_debit=amount,
        functional_credit=Decimal("0"),
    )
    line2 = JournalLine(
        id=gen_uuid(),
        tenant_id=tenant.id,
        journal_entry_id=je.id,
        line_number=2,
        account_id=credit_account.id,
        currency="SAR",
        debit_amount=Decimal("0"),
        credit_amount=amount,
        functional_debit=Decimal("0"),
        functional_credit=amount,
    )
    s.add(line1)
    s.add(line2)
    s.flush()

    s.add(
        GLPosting(
            id=gen_uuid(),
            tenant_id=tenant.id,
            entity_id=entity.id,
            fiscal_period_id=period.id,
            account_id=debit_account.id,
            journal_entry_id=je.id,
            journal_line_id=line1.id,
            debit_amount=amount,
            credit_amount=Decimal("0"),
            currency="SAR",
            posting_date=je_date,
        )
    )
    s.add(
        GLPosting(
            id=gen_uuid(),
            tenant_id=tenant.id,
            entity_id=entity.id,
            fiscal_period_id=period.id,
            account_id=credit_account.id,
            journal_entry_id=je.id,
            journal_line_id=line2.id,
            debit_amount=Decimal("0"),
            credit_amount=amount,
            currency="SAR",
            posting_date=je_date,
        )
    )
    s.flush()
    return je


def _user_token(tenant_id: Optional[str]) -> str:
    return create_access_token(
        f"cf-{uuid.uuid4().hex[:8]}",
        "cf_test",
        ["registered_user"],
        tenant_id=tenant_id,
    )


def _cleanup(*ids: str) -> None:
    if not ids:
        return
    s = SessionLocal()
    try:
        s.query(GLPosting).filter(GLPosting.entity_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(JournalLine).filter(JournalLine.tenant_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(JournalEntry).filter(JournalEntry.entity_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(GLAccount).filter(GLAccount.entity_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(FiscalPeriod).filter(FiscalPeriod.entity_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(Entity).filter(Entity.id.in_(ids)).delete(synchronize_session=False)
        s.query(Tenant).filter(Tenant.id.in_(ids)).delete(synchronize_session=False)
        s.commit()
    except Exception:
        s.rollback()
    finally:
        s.close()


def _cf_url(entity_id: str, **q) -> str:
    base = f"/pilot/entities/{entity_id}/reports/cash-flow"
    parts = "&".join(f"{k}={v}" for k, v in q.items())
    return f"{base}?{parts}" if parts else base


def _make_standard_coa(s, tenant, entity):
    """Build a canonical CoA covering every CF section so each test
    can pick the accounts it needs without re-declaring them."""
    return {
        "cash": _mk_account(s, tenant, entity, code="1101",
                             name_ar="نقدية", category="asset",
                             subcategory="cash"),
        "bank": _mk_account(s, tenant, entity, code="1102",
                             name_ar="بنوك", category="asset",
                             subcategory="bank"),
        "ar": _mk_account(s, tenant, entity, code="1130",
                           name_ar="ذمم مدينة", category="asset",
                           subcategory="receivables"),
        "inventory": _mk_account(s, tenant, entity, code="1140",
                                  name_ar="المخزون", category="asset",
                                  subcategory="inventory"),
        "fixed": _mk_account(s, tenant, entity, code="1210",
                              name_ar="أراضي", category="asset",
                              subcategory="fixed_assets"),
        "ap": _mk_account(s, tenant, entity, code="2110",
                           name_ar="ذمم دائنة", category="liability",
                           subcategory="payables"),
        "loan": _mk_account(s, tenant, entity, code="2210",
                             name_ar="قرض طويل الأجل",
                             category="liability",
                             subcategory="loans"),
        "capital": _mk_account(s, tenant, entity, code="3101",
                                name_ar="رأس المال", category="equity",
                                subcategory="capital"),
        "sales": _mk_account(s, tenant, entity, code="4101",
                              name_ar="مبيعات", category="revenue",
                              subcategory="sales"),
        "rent_exp": _mk_account(s, tenant, entity, code="5210",
                                 name_ar="إيجار", category="expense",
                                 subcategory="rent"),
        "depr_exp": _mk_account(s, tenant, entity, code="5810",
                                 name_ar="إهلاك", category="expense",
                                 subcategory="depreciation"),
    }


# ────────────────────────────────────────────────────────────────────
# Real Data Flow (10)
# ────────────────────────────────────────────────────────────────────


class TestRealDataFlow:
    def test_happy_path_full_cycle(self, client):
        """Full lifecycle: capital + sale + AR + AP + fixed-asset purchase + loan."""
        s = SessionLocal()
        t = _mk_tenant(s, "happy")
        e = _mk_entity(s, t, "happy")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        # Capital injection: cash 100,000 / capital 100,000
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["capital"],
                      amount=Decimal("100000"), je_date=today)
        # Sale on credit: AR 50,000 / sales 50,000
        _mk_posted_je(s, t, e, p, debit_account=coa["ar"],
                      credit_account=coa["sales"],
                      amount=Decimal("50000"), je_date=today)
        # Loan received: cash 30,000 / loan 30,000
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["loan"],
                      amount=Decimal("30000"), je_date=today)
        # Fixed asset purchase: land 20,000 / cash 20,000
        _mk_posted_je(s, t, e, p, debit_account=coa["fixed"],
                      credit_account=coa["cash"],
                      amount=Decimal("20000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            t_block = body["current_period"]["totals"]
            # Net Income = 50,000 (revenue, no expenses)
            assert body["current_period"]["operating_activities"]["net_income"] == 50000.0
            # AR went from 0 to 50,000 → asset increase = -50,000 CF
            # CFO = 50,000 (NI) + 0 (depr) - 50,000 (AR) = 0
            assert t_block["total_cfo"] == 0.0
            # CFI = -20,000 (fixed asset purchase)
            assert t_block["total_cfi"] == -20000.0
            # CFF = +100,000 (capital) + 30,000 (loan) = 130,000
            assert t_block["total_cff"] == 130000.0
            # Net change = 0 - 20,000 + 130,000 = 110,000
            assert t_block["net_change_in_cash"] == 110000.0
            # Cash actually went from 0 to 100k+30k-20k = 110,000
            assert t_block["closing_cash"] == 110000.0
            assert t_block["opening_cash"] == 0.0
            assert t_block["is_reconciled"] is True
            assert resp.headers.get("x-data-source") == "real-time-from-postings"
        finally:
            s.close()
            _cleanup(*ids)

    def test_empty_period_zeros_reconciled(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "empty")
        e = _mk_entity(s, t, "empty")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["total_cfo"] == 0
            assert t_block["total_cfi"] == 0
            assert t_block["total_cff"] == 0
            assert t_block["net_change_in_cash"] == 0
            assert t_block["opening_cash"] == 0
            assert t_block["closing_cash"] == 0
            assert t_block["is_reconciled"] is True
            assert body["posted_je_count"] == 0
            assert body["unmapped_subcategories"] == []
        finally:
            s.close()
            _cleanup(*ids)

    def test_only_operating_activities(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "op")
        e = _mk_entity(s, t, "op")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["sales"],
                      amount=Decimal("5000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["total_cfi"] == 0
            assert t_block["total_cff"] == 0
            assert t_block["total_cfo"] == 5000.0
            assert t_block["is_reconciled"] is True
        finally:
            s.close()
            _cleanup(*ids)

    def test_ar_increase_reduces_cfo(self, client):
        """AR up → cash tied up → CFO < NI."""
        s = SessionLocal()
        t = _mk_tenant(s, "ar-up")
        e = _mk_entity(s, t, "ar-up")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        # All sales on credit — cash never receives
        _mk_posted_je(s, t, e, p, debit_account=coa["ar"],
                      credit_account=coa["sales"],
                      amount=Decimal("8000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            op = body["current_period"]["operating_activities"]
            assert op["net_income"] == 8000.0
            # AR up 8000 → -8000 CF impact
            ar_row = next(i for i in op["working_capital_changes"]
                           if i["subcategory"] == "receivables")
            assert ar_row["change"] == 8000.0
            assert ar_row["cf_impact"] == -8000.0
            # CFO = 8000 - 8000 = 0
            assert op["subtotal_cfo"] == 0.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_ar_decrease_increases_cfo(self, client):
        """Open period with AR balance, then collect → CFO > NI in second period."""
        s = SessionLocal()
        t = _mk_tenant(s, "ar-dn")
        e = _mk_entity(s, t, "ar-dn")
        coa = _make_standard_coa(s, t, e)
        # Period 1: build up AR
        early = date(2026, 3, 5)
        late = date(2026, 4, 25)
        p1 = _mk_period(s, t, e, early)
        p2 = _mk_period(s, t, e, late)
        _mk_posted_je(s, t, e, p1, debit_account=coa["ar"],
                      credit_account=coa["sales"],
                      amount=Decimal("10000"), je_date=early)
        # Period 2: collect AR (no new sales)
        _mk_posted_je(s, t, e, p2, debit_account=coa["cash"],
                      credit_account=coa["ar"],
                      amount=Decimal("6000"), je_date=late)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            # CF for period 2 only — opening AR=10000, closing AR=4000
            resp = client.get(
                _cf_url(e.id,
                        start_date=date(2026, 4, 1).isoformat(),
                        end_date=date(2026, 4, 30).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            op = body["current_period"]["operating_activities"]
            # NI for period 2 = 0 (no revenue/expense in this window)
            assert op["net_income"] == 0.0
            ar_row = next(i for i in op["working_capital_changes"]
                           if i["subcategory"] == "receivables")
            assert ar_row["change"] == -6000.0
            assert ar_row["cf_impact"] == 6000.0  # decrease = +CF
            assert op["subtotal_cfo"] == 6000.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_ap_increase_increases_cfo(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "ap-up")
        e = _mk_entity(s, t, "ap-up")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        # Receive vendor invoice: rent_exp 3000 / AP 3000
        _mk_posted_je(s, t, e, p, debit_account=coa["rent_exp"],
                      credit_account=coa["ap"],
                      amount=Decimal("3000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            op = body["current_period"]["operating_activities"]
            # NI = -3000 (rent expense)
            assert op["net_income"] == -3000.0
            ap_row = next(i for i in op["working_capital_changes"]
                           if i["subcategory"] == "payables")
            # AP went 0 → 3000 → +CF
            assert ap_row["change"] == 3000.0
            assert ap_row["cf_impact"] == 3000.0
            # CFO = -3000 + 3000 = 0 (recognized expense, not yet paid)
            assert op["subtotal_cfo"] == 0.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_inventory_increase_reduces_cfo(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "inv-up")
        e = _mk_entity(s, t, "inv-up")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        # Buy inventory: inventory 5000 / cash 5000
        _mk_posted_je(s, t, e, p, debit_account=coa["inventory"],
                      credit_account=coa["cash"],
                      amount=Decimal("5000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            op = body["current_period"]["operating_activities"]
            inv_row = next(i for i in op["working_capital_changes"]
                            if i["subcategory"] == "inventory")
            assert inv_row["cf_impact"] == -5000.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_depreciation_added_back_to_cfo(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "depr")
        e = _mk_entity(s, t, "depr")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        accum_dep = _mk_account(
            s, t, e, code="1290", name_ar="مجمع الإهلاك",
            category="asset", subcategory="accumulated_dep",
            normal=NormalBalance.credit.value,
        )
        # Sale 10,000 cash; depreciation expense 2,000 (paired with accum_dep)
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["sales"],
                      amount=Decimal("10000"), je_date=today)
        _mk_posted_je(s, t, e, p, debit_account=coa["depr_exp"],
                      credit_account=accum_dep,
                      amount=Decimal("2000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            op = body["current_period"]["operating_activities"]
            # NI = 10000 - 2000 (depr) = 8000
            assert op["net_income"] == 8000.0
            # Depreciation added back as non-cash adjustment
            assert len(op["noncash_adjustments"]) == 1
            assert op["noncash_adjustments"][0]["amount"] == 2000.0
            # CFO = 8000 + 2000 = 10000 (matches actual cash inflow)
            assert op["subtotal_cfo"] == 10000.0
            # Cash actually went 0 → 10000
            assert body["current_period"]["totals"]["closing_cash"] == 10000.0
            assert body["current_period"]["totals"]["is_reconciled"] is True
        finally:
            s.close()
            _cleanup(*ids)

    def test_fixed_asset_purchase_reduces_cfi(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "fa")
        e = _mk_entity(s, t, "fa")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        # Capital injection first to fund the purchase
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["capital"],
                      amount=Decimal("50000"), je_date=today)
        # Buy fixed asset
        _mk_posted_je(s, t, e, p, debit_account=coa["fixed"],
                      credit_account=coa["cash"],
                      amount=Decimal("20000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["total_cfi"] == -20000.0
            inv = body["current_period"]["investing_activities"]
            assert len(inv["items"]) == 1
            assert inv["items"][0]["cf_impact"] == -20000.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_loan_received_increases_cff(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "loan")
        e = _mk_entity(s, t, "loan")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["loan"],
                      amount=Decimal("25000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["total_cff"] == 25000.0
            fin = body["current_period"]["financing_activities"]
            assert any(i["subcategory"] == "loans" for i in fin["items"])
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Reconciliation (3)
# ────────────────────────────────────────────────────────────────────


class TestReconciliation:
    def test_complex_10_je_reconciles_exactly(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "complex")
        e = _mk_entity(s, t, "complex")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        accum_dep = _mk_account(
            s, t, e, code="1290", name_ar="مجمع الإهلاك",
            category="asset", subcategory="accumulated_dep",
            normal=NormalBalance.credit.value,
        )
        # Diverse 10-JE scenario covering all sections
        scenarios = [
            (coa["cash"], coa["capital"], "100000"),    # capital injection
            (coa["bank"], coa["cash"], "60000"),        # cash → bank
            (coa["fixed"], coa["bank"], "30000"),       # asset purchase
            (coa["cash"], coa["loan"], "20000"),        # loan received
            (coa["ar"], coa["sales"], "40000"),         # sale on credit
            (coa["cash"], coa["ar"], "15000"),          # collect part of AR
            (coa["inventory"], coa["ap"], "8000"),      # inventory bought on credit
            (coa["rent_exp"], coa["cash"], "3000"),     # cash expense
            (coa["depr_exp"], accum_dep, "1500"),       # depreciation
            (coa["ap"], coa["bank"], "4000"),           # pay AP
        ]
        for db_acc, cr_acc, amt in scenarios:
            _mk_posted_je(s, t, e, p, debit_account=db_acc,
                          credit_account=cr_acc,
                          amount=Decimal(amt), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["is_reconciled"] is True, (
                f"reconciliation failed: opening={t_block['opening_cash']} "
                f"closing={t_block['closing_cash']} "
                f"net_change={t_block['net_change_in_cash']} "
                f"diff={t_block['reconciliation_difference']}"
            )
            # closing - opening must equal net_change exactly
            actual = t_block["closing_cash"] - t_block["opening_cash"]
            assert abs(actual - t_block["net_change_in_cash"]) < 0.01
        finally:
            s.close()
            _cleanup(*ids)

    def test_opening_plus_change_equals_closing(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "rec2")
        e = _mk_entity(s, t, "rec2")
        coa = _make_standard_coa(s, t, e)
        early = date(2026, 3, 10)
        late = date(2026, 4, 20)
        p1 = _mk_period(s, t, e, early)
        p2 = _mk_period(s, t, e, late)
        # Pre-period: build up cash
        _mk_posted_je(s, t, e, p1, debit_account=coa["cash"],
                      credit_account=coa["capital"],
                      amount=Decimal("75000"), je_date=early)
        # Reporting period
        _mk_posted_je(s, t, e, p2, debit_account=coa["cash"],
                      credit_account=coa["sales"],
                      amount=Decimal("20000"), je_date=late)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=date(2026, 4, 1).isoformat(),
                        end_date=date(2026, 4, 30).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["opening_cash"] == 75000.0
            assert t_block["closing_cash"] == 95000.0
            assert t_block["reconciliation_check"] == 95000.0
            assert t_block["is_reconciled"] is True
        finally:
            s.close()
            _cleanup(*ids)

    def test_unmapped_subcategory_surfaces_in_warnings(self, client):
        """Custom subcategory not in _CF_SECTION_MAP must surface in
        unmapped_subcategories so admins can map it. The reconciliation
        breaks when such items are excluded — pinned by the warning
        list, not silenced."""
        s = SessionLocal()
        t = _mk_tenant(s, "unmap")
        e = _mk_entity(s, t, "unmap")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        weird_asset = _mk_account(
            s, t, e, code="1801", name_ar="حساب مبهم",
            category="asset", subcategory="unknown_xyz",
        )
        _mk_posted_je(s, t, e, p, debit_account=weird_asset,
                      credit_account=coa["cash"],
                      amount=Decimal("1000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert "unknown_xyz" in body["unmapped_subcategories"]
            assert len(body["warnings"]) >= 1
            # Reconciliation will also be off because the unmapped row
            # affected cash but didn't make it into a CF section.
            t_block = body["current_period"]["totals"]
            assert t_block["is_reconciled"] is False
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Tenant + validation (3)
# ────────────────────────────────────────────────────────────────────


class TestTenantAndValidation:
    def test_cross_tenant_returns_404(self, client):
        s = SessionLocal()
        ta = _mk_tenant(s, "iso-a")
        tb = _mk_tenant(s, "iso-b")
        ea = _mk_entity(s, ta, "iso-a")
        eb = _mk_entity(s, tb, "iso-b")
        s.commit()
        ids = (ta.id, tb.id, ea.id, eb.id)
        try:
            token_a = _user_token(tenant_id=ta.id)
            today = date.today()
            resp = client.get(
                _cf_url(eb.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token_a}"},
            )
            assert resp.status_code == 404
            assert "entity not found" in resp.text.lower()
        finally:
            s.close()
            _cleanup(*ids)

    def test_period_start_after_end_returns_400(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "inv")
        e = _mk_entity(s, t, "inv")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id, start_date="2026-04-30", end_date="2026-04-01"),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 400
            assert "end_date" in resp.text
        finally:
            s.close()
            _cleanup(*ids)

    def test_invalid_method_returns_422(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "method")
        e = _mk_entity(s, t, "method")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            # invalid value
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat(),
                        method="fancy"),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 400  # ValueError → 400
            # direct method explicitly returns 422 + "قريباً" message
            resp_direct = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat(),
                        method="direct"),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp_direct.status_code == 422
            assert "Direct method" in resp_direct.text
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Anti-Mock (4)
# ────────────────────────────────────────────────────────────────────


class TestAntiMock:
    def test_no_hardcoded_values_in_response(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "anti1")
        e = _mk_entity(s, t, "anti1")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            cp = body["current_period"]
            t_block = cp["totals"]
            for key in (
                "total_cfo", "total_cfi", "total_cff", "net_change_in_cash",
                "opening_cash", "closing_cash", "reconciliation_check",
                "reconciliation_difference",
            ):
                assert t_block[key] == 0, (
                    f"{key} should be 0 (got {t_block[key]!r})")
            assert t_block["is_reconciled"] is True
            assert cp["operating_activities"]["net_income"] == 0
            assert cp["operating_activities"]["noncash_adjustments"] == []
            assert cp["operating_activities"]["working_capital_changes"] == []
            assert cp["investing_activities"]["items"] == []
            assert cp["financing_activities"]["items"] == []
            assert body["unmapped_subcategories"] == []
            assert body["warnings"] == []
            assert body["posted_je_count"] == 0
        finally:
            s.close()
            _cleanup(*ids)

    def test_response_reflects_actual_postings_exactly(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "anti2")
        e = _mk_entity(s, t, "anti2")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        SPECIFIC = Decimal("12345.67")
        # Sale paid in cash → CFO = NI = 12345.67
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=coa["sales"],
                      amount=SPECIFIC, je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            t_block = body["current_period"]["totals"]
            assert t_block["total_cfo"] == 12345.67
            assert t_block["net_change_in_cash"] == 12345.67
            assert t_block["closing_cash"] == 12345.67
            assert t_block["is_reconciled"] is True
        finally:
            s.close()
            _cleanup(*ids)

    def test_unmapped_subcategory_detection(self, client):
        """A custom asset with subcategory='unknown_xyz' must appear
        in unmapped_subcategories — pinning the contract that custom
        CoAs surface a warning rather than silently breaking the
        reconciliation."""
        s = SessionLocal()
        t = _mk_tenant(s, "unmapd")
        e = _mk_entity(s, t, "unmapd")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        weird = _mk_account(
            s, t, e, code="1990", name_ar="غريب", category="asset",
            subcategory="weird_subcat",
        )
        _mk_posted_je(s, t, e, p, debit_account=weird,
                      credit_account=coa["cash"],
                      amount=Decimal("100"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert "weird_subcat" in body["unmapped_subcategories"]
            assert any("subcategories غير مصنّفة" in w for w in body["warnings"])
        finally:
            s.close()
            _cleanup(*ids)

    def test_no_reconciliation_bypass(self, client):
        """A scenario that breaks reconciliation must surface
        is_reconciled=False — the response must NOT silently force it
        to True. This pins the integrity invariant: we never massage
        the result to look balanced when the data isn't."""
        s = SessionLocal()
        t = _mk_tenant(s, "norec")
        e = _mk_entity(s, t, "norec")
        today = date.today()
        p = _mk_period(s, t, e, today)
        coa = _make_standard_coa(s, t, e)
        # Use an unmapped subcategory to deliberately break reconciliation:
        # the cash side is captured, but the other side falls outside
        # any CF section, so net_change won't match closing-opening.
        weird = _mk_account(
            s, t, e, code="2901", name_ar="التزام مبهم",
            category="liability", subcategory="ambiguous_liability",
        )
        _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                      credit_account=weird,
                      amount=Decimal("5000"), je_date=today)
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            t_block = body["current_period"]["totals"]
            # Cash actually went up by 5000
            assert t_block["closing_cash"] == 5000.0
            # but the matching side (ambiguous_liability) didn't make
            # it into any CF section, so net_change=0
            assert t_block["net_change_in_cash"] == 0.0
            # ⇒ must report as NOT reconciled (NOT silenced to true)
            assert t_block["is_reconciled"] is False
            assert t_block["reconciliation_difference"] != 0
            # ⇒ a warning surfaces
            assert any("غير متطابقة" in w for w in body["warnings"])
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Reconciliation logging — structured warning on cross-tenant breakage
# ────────────────────────────────────────────────────────────────────


def test_reconciliation_failure_emits_structured_log(client, caplog):
    s = SessionLocal()
    t = _mk_tenant(s, "log")
    e = _mk_entity(s, t, "log")
    today = date.today()
    p = _mk_period(s, t, e, today)
    coa = _make_standard_coa(s, t, e)
    # Same setup as test_no_reconciliation_bypass — break reconciliation
    weird = _mk_account(
        s, t, e, code="2901", name_ar="مبهم", category="liability",
        subcategory="ambiguous_lib2",
    )
    _mk_posted_je(s, t, e, p, debit_account=coa["cash"],
                  credit_account=weird,
                  amount=Decimal("777"), je_date=today)
    s.commit()
    ids = (t.id, e.id)
    try:
        token = _user_token(tenant_id=t.id)
        with caplog.at_level(logging.WARNING, logger="app.pilot.routes.gl_routes"):
            client.get(
                _cf_url(e.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
        matches = [r for r in caplog.records
                    if "CF_RECONCILIATION_FAILURE" in r.getMessage()]
        assert matches, "expected CF_RECONCILIATION_FAILURE log line"
    finally:
        s.close()
        _cleanup(*ids)
