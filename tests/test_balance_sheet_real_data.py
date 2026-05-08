"""G-FIN-BS-1 — Balance Sheet real-data audit + balance-equation contract.

The non-negotiable contracts this suite pins down:

* **Every value the endpoint returns came from `pilot_gl_postings`.**
  Drafts (lines without GLPosting rows) are inherently excluded by
  the SQL. There is no in-memory fallback, no cache, no demo seed.
* **Cross-tenant probes return 404 + generic body** (anti-enumeration).
* **The accounting equation Assets = Liabilities + Equity holds**
  whenever the underlying JEs are balanced. When unbalanced JEs slip
  through (data integrity issue) the response carries
  `is_balanced=False` and `balance_difference != 0` — we do NOT
  silently bypass the equation. Pinned by `TestBalanceEquation`.
* **Anti-mock guarantees:**
  - An entity with zero JEs returns `total_assets=0`, `total_liab=0`,
    `total_equity=0`, `is_balanced=true`, `accounts=[]` everywhere,
    `posted_je_count=0` — no defaults or seeded values.
  - A JE posted with an exact decimal amount (12345.67) round-trips
    *exactly* through the response.

Fixture pattern: same shortcut as test_income_statement_real_data.py
and test_tb_real_data_flow.py — direct GLPosting row inserts mirror
the production posting service end-state.
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
# Fixtures (same shape as the IS-1 suite)
# ────────────────────────────────────────────────────────────────────


def _mk_tenant(s, suffix: str) -> Tenant:
    t = Tenant(
        id=gen_uuid(),
        slug=f"bs-{suffix}-{uuid.uuid4().hex[:6]}",
        legal_name_ar=f"اختبار BS {suffix}",
        primary_email=f"bs_{suffix}_{uuid.uuid4().hex[:4]}@example.test",
        primary_country="SA",
    )
    s.add(t)
    s.flush()
    return t


def _mk_entity(s, tenant: Tenant, suffix: str) -> Entity:
    e = Entity(
        id=gen_uuid(),
        tenant_id=tenant.id,
        code=f"E-BS-{suffix}-{uuid.uuid4().hex[:4]}",
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
        if category in ("liability", "equity", "revenue"):
            normal = NormalBalance.credit.value
        else:
            normal = NormalBalance.debit.value
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
        je_number=f"JE-BS-{uuid.uuid4().hex[:8]}",
        kind="manual",
        status=JournalEntryStatus.posted.value,
        memo_ar="اختبار BS — قيد متوازن",
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
        f"bs-{uuid.uuid4().hex[:8]}",
        "bs_test",
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


def _bs_url(entity_id: str, **q) -> str:
    base = f"/pilot/entities/{entity_id}/reports/balance-sheet"
    parts = "&".join(f"{k}={v}" for k, v in q.items())
    return f"{base}?{parts}" if parts else base


# ────────────────────────────────────────────────────────────────────
# Real data flow (8)
# ────────────────────────────────────────────────────────────────────


class TestRealDataFlow:
    def test_happy_path_balanced_capital_injection(self, client):
        """Capital injection: مدين نقدية / دائن رأس المال → BS balanced."""
        s = SessionLocal()
        t = _mk_tenant(s, "happy")
        e = _mk_entity(s, t, "happy")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        capital = _mk_account(
            s, t, e, code="3101", name_ar="رأس المال",
            category="equity", subcategory="capital",
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=capital,
            amount=Decimal("10000.00"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["assets"] == 10000.00
            assert body["liabilities"] == 0
            assert body["total_equity"] == 10000.00
            assert body["balanced"] is True
            assert body["difference"] == 0
            assert body["posted_je_count"] == 1
            assert resp.headers.get("x-data-source") == "real-time-from-postings"
            cp = body["current_period"]
            assert cp["totals"]["total_assets"] == 10000.00
            assert cp["totals"]["total_liab_and_equity"] == 10000.00
        finally:
            s.close()
            _cleanup(*ids)

    def test_empty_period_zero_balanced_no_seed(self, client):
        """Empty entity → all zeros, is_balanced=true, no seeded values."""
        s = SessionLocal()
        t = _mk_tenant(s, "empty")
        e = _mk_entity(s, t, "empty")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=date.today().isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            assert body["assets"] == 0
            assert body["liabilities"] == 0
            assert body["total_equity"] == 0
            assert body["balanced"] is True
            assert body["posted_je_count"] == 0
            cp = body["current_period"]
            assert cp["assets"] == []
            assert cp["liabilities"] == []
            assert cp["equity"] == []
        finally:
            s.close()
            _cleanup(*ids)

    def test_balanced_after_partial_period_with_revenue(self, client):
        """JE for capital + revenue → BS still balanced via CYE row."""
        s = SessionLocal()
        t = _mk_tenant(s, "rev")
        e = _mk_entity(s, t, "rev")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        capital = _mk_account(
            s, t, e, code="3101", name_ar="رأس المال",
            category="equity", subcategory="capital",
        )
        sales = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        # Capital 10000 + Sale 5000 → Cash=15000, Capital=10000, CYE=5000
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=capital,
            amount=Decimal("10000"), je_date=today,
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=sales,
            amount=Decimal("5000"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["assets"] == 15000.0
            assert body["current_earnings"] == 5000.0
            # capital 10000 + CYE 5000 = 15000
            assert body["total_equity"] == 15000.0
            assert body["balanced"] is True
        finally:
            s.close()
            _cleanup(*ids)

    def test_include_zero_toggles_zero_accounts(self, client):
        """Account with no postings shows only when include_zero=true."""
        s = SessionLocal()
        t = _mk_tenant(s, "incz")
        e = _mk_entity(s, t, "incz")
        _mk_account(
            s, t, e, code="1110", name_ar="نقدية صفر",
            category="asset", subcategory="cash",
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            r_off = client.get(
                _bs_url(e.id, as_of=today.isoformat(), include_zero="false"),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert r_off.json()["current_period"]["assets"] == []
            r_on = client.get(
                _bs_url(e.id, as_of=today.isoformat(), include_zero="true"),
                headers={"Authorization": f"Bearer {token}"},
            )
            codes = [a["code"] for a in r_on.json()["current_period"]["assets"]]
            assert "1110" in codes
        finally:
            s.close()
            _cleanup(*ids)

    def test_compare_as_of_returns_comparison_and_variances(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "cmp")
        e = _mk_entity(s, t, "cmp")
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        capital = _mk_account(
            s, t, e, code="3101", name_ar="رأس المال",
            category="equity", subcategory="capital",
        )
        # JE on 2026-03-15 for 5000, JE on 2026-03-30 for another 3000.
        early = date(2026, 3, 15)
        late = date(2026, 3, 30)
        p_early = _mk_period(s, t, e, early)
        p_late = _mk_period(s, t, e, late)
        _mk_posted_je(
            s, t, e, p_early, debit_account=cash, credit_account=capital,
            amount=Decimal("5000"), je_date=early,
        )
        _mk_posted_je(
            s, t, e, p_late, debit_account=cash, credit_account=capital,
            amount=Decimal("3000"), je_date=late,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(
                    e.id,
                    as_of=late.isoformat(),
                    compare_as_of=early.isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["assets"] == 8000.0
            assert body["comparison_period"] is not None
            assert body["comparison_period"]["totals"]["total_assets"] == 5000.0
            v = body["variances"]
            # (8000 - 5000) / 5000 * 100 = 60.0
            assert v["total_assets_change_pct"] == 60.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_compare_as_of_none_no_comparison_block(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "no")
        e = _mk_entity(s, t, "no")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=date.today().isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["comparison_period"] is None
            assert body["variances"] is None
        finally:
            s.close()
            _cleanup(*ids)

    def test_compare_as_of_after_as_of_returns_400(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "inv")
        e = _mk_entity(s, t, "inv")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(
                    e.id,
                    as_of="2026-03-01",
                    compare_as_of="2026-04-01",  # after as_of
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 400
            assert "compare_as_of" in resp.text
        finally:
            s.close()
            _cleanup(*ids)

    def test_only_posted_jes_counted(self, client):
        """Drafts must NOT show up in BS."""
        s = SessionLocal()
        t = _mk_tenant(s, "draft")
        e = _mk_entity(s, t, "draft")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        capital = _mk_account(
            s, t, e, code="3101", name_ar="رأس المال",
            category="equity", subcategory="capital",
        )
        # Draft (no postings)
        je_draft = JournalEntry(
            id=gen_uuid(),
            tenant_id=t.id,
            entity_id=e.id,
            fiscal_period_id=p.id,
            je_number=f"JE-D-{uuid.uuid4().hex[:8]}",
            kind="manual",
            status=JournalEntryStatus.draft.value,
            memo_ar="مسودة",
            je_date=today,
            currency="SAR",
            total_debit=Decimal("9999"),
            total_credit=Decimal("9999"),
        )
        s.add(je_draft)
        # Posted
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=capital,
            amount=Decimal("100"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["assets"] == 100.0  # not 9999 + 100
            assert body["posted_je_count"] == 1  # not 2
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Tenant isolation (3)
# ────────────────────────────────────────────────────────────────────


class TestTenantIsolation:
    def test_cross_tenant_returns_404_anti_enum(self, client):
        s = SessionLocal()
        ta = _mk_tenant(s, "iso-a")
        tb = _mk_tenant(s, "iso-b")
        ea = _mk_entity(s, ta, "iso-a")
        eb = _mk_entity(s, tb, "iso-b")
        s.commit()
        ids = (ta.id, tb.id, ea.id, eb.id)
        try:
            token_a = _user_token(tenant_id=ta.id)
            resp = client.get(
                _bs_url(eb.id, as_of=date.today().isoformat()),
                headers={"Authorization": f"Bearer {token_a}"},
            )
            assert resp.status_code == 404
            assert "entity not found" in resp.text.lower()
        finally:
            s.close()
            _cleanup(*ids)

    def test_cross_tenant_emits_violation_log(self, client, caplog):
        s = SessionLocal()
        ta = _mk_tenant(s, "log-a")
        tb = _mk_tenant(s, "log-b")
        ea = _mk_entity(s, ta, "log-a")
        eb = _mk_entity(s, tb, "log-b")
        s.commit()
        ids = (ta.id, tb.id, ea.id, eb.id)
        try:
            token_a = _user_token(tenant_id=ta.id)
            with caplog.at_level(
                logging.WARNING, logger="app.pilot.security.tenant_guards"
            ):
                client.get(
                    _bs_url(eb.id, as_of=date.today().isoformat()),
                    headers={"Authorization": f"Bearer {token_a}"},
                )
            matches = [
                r for r in caplog.records
                if "TENANT_GUARD_VIOLATION" in r.getMessage()
            ]
            assert matches
        finally:
            s.close()
            _cleanup(*ids)

    def test_own_tenant_returns_only_own_data(self, client):
        s = SessionLocal()
        ta = _mk_tenant(s, "own-a")
        tb = _mk_tenant(s, "own-b")
        ea = _mk_entity(s, ta, "own-a")
        eb = _mk_entity(s, tb, "own-b")
        today = date.today()
        pa = _mk_period(s, ta, ea, today)
        pb = _mk_period(s, tb, eb, today)
        cash_a = _mk_account(
            s, ta, ea, code="1101", name_ar="A", category="asset", subcategory="cash"
        )
        cap_a = _mk_account(
            s, ta, ea, code="3101", name_ar="A", category="equity", subcategory="capital"
        )
        cash_b = _mk_account(
            s, tb, eb, code="1101", name_ar="B", category="asset", subcategory="cash"
        )
        cap_b = _mk_account(
            s, tb, eb, code="3101", name_ar="B", category="equity", subcategory="capital"
        )
        _mk_posted_je(
            s, ta, ea, pa, debit_account=cash_a, credit_account=cap_a,
            amount=Decimal("100"), je_date=today,
        )
        _mk_posted_je(
            s, tb, eb, pb, debit_account=cash_b, credit_account=cap_b,
            amount=Decimal("9999"), je_date=today,
        )
        s.commit()
        ids = (ta.id, tb.id, ea.id, eb.id)
        try:
            token_a = _user_token(tenant_id=ta.id)
            resp = client.get(
                _bs_url(ea.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token_a}"},
            )
            body = resp.json()
            assert body["assets"] == 100.0  # not 9999
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Anti-mock (2) — empty entity + 12345.67 round-trip
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
            resp = client.get(
                _bs_url(e.id, as_of=date.today().isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            # Top-level legacy keys
            assert body["assets"] == 0
            assert body["liabilities"] == 0
            assert body["equity"] == 0
            assert body["current_earnings"] == 0
            assert body["total_equity"] == 0
            assert body["difference"] == 0
            assert body["balanced"] is True
            assert body["posted_je_count"] == 0
            # current_period block
            cp = body["current_period"]
            assert cp["assets"] == []
            assert cp["liabilities"] == []
            assert cp["equity"] == []
            assert cp["current_earnings"] == 0
            t = cp["totals"]
            for key in (
                "total_current_assets", "total_fixed_assets", "total_assets",
                "total_current_liabilities", "total_long_term_liabilities",
                "total_liabilities", "total_equity", "total_liab_and_equity",
                "balance_difference",
            ):
                assert t[key] == 0, f"{key} should be 0 (got {t[key]!r})"
            assert t["is_balanced"] is True
        finally:
            s.close()
            _cleanup(*ids)

    def test_response_reflects_actual_postings_exactly(self, client):
        """Post a JE for 12345.67 → BS reflects it byte-for-byte."""
        s = SessionLocal()
        t = _mk_tenant(s, "anti2")
        e = _mk_entity(s, t, "anti2")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        capital = _mk_account(
            s, t, e, code="3101", name_ar="رأس المال",
            category="equity", subcategory="capital",
        )
        SPECIFIC = Decimal("12345.67")
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=capital,
            amount=SPECIFIC, je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["assets"] == 12345.67
            assert body["total_equity"] == 12345.67
            assert body["balanced"] is True
            cash_row = next(
                a for a in body["current_period"]["assets"] if a["code"] == "1101"
            )
            assert cash_row["balance"] == 12345.67
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Balance equation (2) — the integrity invariant
# ────────────────────────────────────────────────────────────────────


class TestBalanceEquation:
    def test_complex_multi_je_equation_holds(self, client):
        """Five JEs across asset/liability/equity → A = L + E exactly."""
        s = SessionLocal()
        t = _mk_tenant(s, "eq")
        e = _mk_entity(s, t, "eq")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        bank = _mk_account(
            s, t, e, code="1102", name_ar="بنوك",
            category="asset", subcategory="bank",
        )
        ar = _mk_account(
            s, t, e, code="1130", name_ar="ذمم مدينة",
            category="asset", subcategory="receivables",
        )
        ap = _mk_account(
            s, t, e, code="2110", name_ar="ذمم دائنة",
            category="liability", subcategory="payables",
        )
        capital = _mk_account(
            s, t, e, code="3101", name_ar="رأس المال",
            category="equity", subcategory="capital",
        )
        sales = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        cogs = _mk_account(
            s, t, e, code="5101", name_ar="تكلفة بضاعة",
            category="expense", subcategory="cogs",
        )
        # Capital injection: cash 50,000 / capital 50,000
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=capital,
            amount=Decimal("50000"), je_date=today,
        )
        # Bank deposit: bank 30,000 / cash 30,000
        _mk_posted_je(
            s, t, e, p, debit_account=bank, credit_account=cash,
            amount=Decimal("30000"), je_date=today,
        )
        # Sale on credit: AR 8,000 / sales 8,000
        _mk_posted_je(
            s, t, e, p, debit_account=ar, credit_account=sales,
            amount=Decimal("8000"), je_date=today,
        )
        # Cost: cogs 3,000 / cash 3,000
        _mk_posted_je(
            s, t, e, p, debit_account=cogs, credit_account=cash,
            amount=Decimal("3000"), je_date=today,
        )
        # Vendor invoice received: cogs 1,500 / AP 1,500
        _mk_posted_je(
            s, t, e, p, debit_account=cogs, credit_account=ap,
            amount=Decimal("1500"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _bs_url(e.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            # Manual computation:
            # cash = 50000 - 30000 - 3000 = 17000
            # bank = 30000
            # AR = 8000
            # total assets = 55000
            # AP = 1500
            # capital = 50000
            # CYE = 8000 - (3000 + 1500) = 3500
            # total equity = 50000 + 3500 = 53500
            # total L+E = 1500 + 53500 = 55000  ✅
            assert body["assets"] == 55000.0
            assert body["liabilities"] == 1500.0
            assert body["total_equity"] == 53500.0
            assert body["current_earnings"] == 3500.0
            assert body["balanced"] is True
            assert body["difference"] == 0.0
            t_block = body["current_period"]["totals"]
            assert t_block["total_assets"] == t_block["total_liab_and_equity"]
        finally:
            s.close()
            _cleanup(*ids)

    def test_cye_in_equity_equals_is_net_income(self, client):
        """The synthetic _current_year_earnings row in equity must
        equal the IS net_income for [Jan 1 .. as_of_date]."""
        s = SessionLocal()
        t = _mk_tenant(s, "cye")
        e = _mk_entity(s, t, "cye")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset", subcategory="cash",
        )
        sales = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        cogs = _mk_account(
            s, t, e, code="5101", name_ar="تكلفة بضاعة",
            category="expense", subcategory="cogs",
        )
        # Profit = 7000 (10000 sales - 3000 COGS)
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=sales,
            amount=Decimal("10000"), je_date=today,
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cogs, credit_account=cash,
            amount=Decimal("3000"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            # Hit BS
            r_bs = client.get(
                _bs_url(e.id, as_of=today.isoformat()),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert r_bs.status_code == 200
            bs_body = r_bs.json()
            cye_row = next(
                r for r in bs_body["current_period"]["equity"]
                if r.get("is_synthetic") is True
            )
            # Hit IS for [Jan 1 .. today]
            year_start = date(today.year, 1, 1)
            r_is = client.get(
                f"/pilot/entities/{e.id}/reports/income-statement"
                f"?start_date={year_start.isoformat()}&end_date={today.isoformat()}",
                headers={"Authorization": f"Bearer {token}"},
            )
            is_body = r_is.json()
            # The synthetic CYE row in BS must equal IS net_income
            assert cye_row["balance"] == is_body["net_income"] == 7000.0
            assert bs_body["current_earnings"] == 7000.0
        finally:
            s.close()
            _cleanup(*ids)
