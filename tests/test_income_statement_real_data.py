"""G-FIN-IS-1 — Income Statement real-data audit.

The non-negotiable contract this suite pins down:

* **Every value the endpoint returns came from `pilot_gl_postings`.**
  Drafts (lines without GLPosting rows) are inherently excluded by
  the SQL. There is no in-memory fallback, no cache, no demo seed —
  `G-DEMO-DATA-SEEDER` writes master data only and explicitly skips
  journal entries.
* **Cross-tenant probes return 404 + generic body** (anti-enumeration,
  the contract `assert_entity_in_tenant` already enforces) and emit
  the structured `TENANT_GUARD_VIOLATION` log.
* **Anti-mock guarantees:**
  - An entity with zero JEs returns `revenue_total=0`, `expense_total=0`,
    `net_income=0`, `accounts=[]`, `posted_je_count=0` — no defaults
    or seeded values.
  - A JE posted with an exact decimal amount (12345.67) round-trips
    *exactly* through the response.

The fixtures shortcut the JE → GLPosting path the same way
`tests/test_tb_real_data_flow.py` does — direct row inserts, since the
production posting service has unrelated dependencies (sequences,
period stat updates, auth) that don't matter for the data path test.
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
# Fixtures (mirrored from test_tb_real_data_flow.py for consistency)
# ────────────────────────────────────────────────────────────────────


def _mk_tenant(s, suffix: str) -> Tenant:
    t = Tenant(
        id=gen_uuid(),
        slug=f"is-{suffix}-{uuid.uuid4().hex[:6]}",
        legal_name_ar=f"اختبار IS {suffix}",
        primary_email=f"is_{suffix}_{uuid.uuid4().hex[:4]}@example.test",
        primary_country="SA",
    )
    s.add(t)
    s.flush()
    return t


def _mk_entity(s, tenant: Tenant, suffix: str) -> Entity:
    e = Entity(
        id=gen_uuid(),
        tenant_id=tenant.id,
        code=f"E-IS-{suffix}-{uuid.uuid4().hex[:4]}",
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
) -> GLAccount:
    normal = (
        NormalBalance.credit.value
        if category == "revenue"
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
    """Insert a 2-line balanced posted JE + the matching GLPosting rows.

    Mirrors the production `post_journal_entry` end state without the
    sequence / stat-update dependencies — what `compute_income_statement`
    sees in the database is identical to the production path.
    """
    je = JournalEntry(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        fiscal_period_id=period.id,
        je_number=f"JE-IS-{uuid.uuid4().hex[:8]}",
        kind="manual",
        status=JournalEntryStatus.posted.value,
        memo_ar="اختبار IS — قيد متوازن",
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


def _mk_draft_je(
    s,
    tenant: Tenant,
    entity: Entity,
    period: FiscalPeriod,
    *,
    debit_account: GLAccount,
    credit_account: GLAccount,
    amount: Decimal,
) -> JournalEntry:
    """Draft JE — has lines but no GLPostings. Must NOT show up in IS."""
    je = JournalEntry(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        fiscal_period_id=period.id,
        je_number=f"JE-D-{uuid.uuid4().hex[:8]}",
        kind="manual",
        status=JournalEntryStatus.draft.value,
        memo_ar="مسودة",
        je_date=date.today(),
        currency="SAR",
        total_debit=amount,
        total_credit=amount,
    )
    s.add(je)
    s.flush()
    return je


def _user_token(tenant_id: Optional[str]) -> str:
    return create_access_token(
        f"is-{uuid.uuid4().hex[:8]}",
        "is_test",
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


def _is_url(entity_id: str, **q) -> str:
    base = f"/pilot/entities/{entity_id}/reports/income-statement"
    parts = "&".join(f"{k}={v}" for k, v in q.items())
    return f"{base}?{parts}" if parts else base


# ────────────────────────────────────────────────────────────────────
# Real data flow (10)
# ────────────────────────────────────────────────────────────────────


class TestRealDataFlow:
    def test_happy_path_revenue_cogs_opex(self, client):
        """3 posted JEs (revenue + COGS + opex) → IS matches manual sum."""
        s = SessionLocal()
        t = _mk_tenant(s, "happy")
        e = _mk_entity(s, t, "happy")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        rev = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        cogs = _mk_account(
            s, t, e, code="5101", name_ar="تكلفة بضاعة",
            category="expense", subcategory="cogs",
        )
        opex = _mk_account(
            s, t, e, code="5201", name_ar="إيجار",
            category="expense", subcategory="rent",
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=Decimal("10000.00"), je_date=today,
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cogs, credit_account=cash,
            amount=Decimal("4000.00"), je_date=today,
        )
        _mk_posted_je(
            s, t, e, p, debit_account=opex, credit_account=cash,
            amount=Decimal("1500.00"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["revenue_total"] == 10000.00
            assert body["expense_total"] == 5500.00
            assert body["net_income"] == 4500.00
            assert body["posted_je_count"] == 3
            codes = sorted(a["code"] for a in body["accounts"])
            assert codes == ["4101", "5101", "5201"]
            # X-Data-Source response header
            assert resp.headers.get("x-data-source") == "real-time-from-postings"
        finally:
            s.close()
            _cleanup(*ids)

    def test_empty_period_zero_totals_no_seed(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "empty")
        e = _mk_entity(s, t, "empty")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["revenue_total"] == 0
            assert body["expense_total"] == 0
            assert body["net_income"] == 0
            assert body["accounts"] == []
            assert body["posted_je_count"] == 0
        finally:
            s.close()
            _cleanup(*ids)

    def test_only_posted_je_counted(self, client):
        """Mix of posted + draft → IS reflects only posted."""
        s = SessionLocal()
        t = _mk_tenant(s, "mix")
        e = _mk_entity(s, t, "mix")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        rev = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=Decimal("3000"), je_date=today,
        )
        _mk_draft_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=Decimal("9999999"),
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 3000.0
            assert body["posted_je_count"] == 1  # not 2
        finally:
            s.close()
            _cleanup(*ids)

    def test_include_zero_toggles_zero_accounts(self, client):
        """A revenue account with no postings appears only when
        include_zero=true."""
        s = SessionLocal()
        t = _mk_tenant(s, "incz")
        e = _mk_entity(s, t, "incz")
        today = date.today()
        # CoA exists but no JEs → all zero
        _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        _mk_account(
            s, t, e, code="5101", name_ar="تكلفة",
            category="expense", subcategory="cogs",
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            url = _is_url(
                e.id,
                start_date=today.replace(day=1).isoformat(),
                end_date=today.replace(day=28).isoformat(),
                include_zero="false",
            )
            resp_zoff = client.get(
                url, headers={"Authorization": f"Bearer {token}"}
            )
            assert resp_zoff.json()["accounts"] == []

            url = _is_url(
                e.id,
                start_date=today.replace(day=1).isoformat(),
                end_date=today.replace(day=28).isoformat(),
                include_zero="true",
            )
            resp_zon = client.get(
                url, headers={"Authorization": f"Bearer {token}"}
            )
            codes = sorted(a["code"] for a in resp_zon.json()["accounts"])
            assert codes == ["4101", "5101"]
        finally:
            s.close()
            _cleanup(*ids)

    def test_compare_period_previous_year(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "py")
        e = _mk_entity(s, t, "py")
        today = date.today()
        # Use March of current year + March of prior year so we don't
        # cross a leap-day boundary in this fixture.
        cur_start = date(today.year, 3, 1)
        cur_end = date(today.year, 3, 28)
        prior_start = cur_start.replace(year=cur_start.year - 1)
        p_cur = _mk_period(s, t, e, cur_start)
        p_prior = _mk_period(s, t, e, prior_start)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        rev = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        _mk_posted_je(
            s, t, e, p_cur, debit_account=cash, credit_account=rev,
            amount=Decimal("6000"), je_date=cur_start,
        )
        _mk_posted_je(
            s, t, e, p_prior, debit_account=cash, credit_account=rev,
            amount=Decimal("4000"), je_date=prior_start,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=cur_start.isoformat(),
                    end_date=cur_end.isoformat(),
                    compare_period="previous_year",
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 6000.0
            cmp_block = body["comparison"]
            assert cmp_block is not None
            assert cmp_block["kind"] == "previous_year"
            assert cmp_block["revenue_total"] == 4000.0
            # variance = (6000 - 4000) / 4000 * 100 = 50.0
            assert cmp_block["revenue_variance_pct"] == 50.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_compare_period_previous_period(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "pp")
        e = _mk_entity(s, t, "pp")
        # Two consecutive 7-day windows, well outside any leap edge.
        cur_start = date(2026, 3, 8)
        cur_end = date(2026, 3, 14)
        prior_start = date(2026, 3, 1)
        prior_end = date(2026, 3, 7)
        p = _mk_period(s, t, e, cur_start)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        rev = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=Decimal("2000"), je_date=cur_start,
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=Decimal("1000"), je_date=prior_start,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=cur_start.isoformat(),
                    end_date=cur_end.isoformat(),
                    compare_period="previous_period",
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 2000.0
            cmp_block = body["comparison"]
            assert cmp_block is not None
            assert cmp_block["kind"] == "previous_period"
            assert cmp_block["start_date"] == prior_start.isoformat()
            assert cmp_block["end_date"] == prior_end.isoformat()
            assert cmp_block["revenue_total"] == 1000.0
            assert cmp_block["revenue_variance_pct"] == 100.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_compare_none_no_comparison_block(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "no")
        e = _mk_entity(s, t, "no")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["compare_period"] == "none"
            assert body["comparison"] is None
        finally:
            s.close()
            _cleanup(*ids)

    def test_invalid_period_returns_400(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "inv")
        e = _mk_entity(s, t, "inv")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date="2026-03-31",
                    end_date="2026-03-01",  # < start_date
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 400
            assert "end_date" in resp.text
        finally:
            s.close()
            _cleanup(*ids)

    def test_only_revenue_no_expenses(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "rev")
        e = _mk_entity(s, t, "rev")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        rev = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=Decimal("777"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 777.0
            assert body["expense_total"] == 0
            assert body["net_income"] == 777.0
        finally:
            s.close()
            _cleanup(*ids)

    def test_only_expenses_no_revenue(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "exp")
        e = _mk_entity(s, t, "exp")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        opex = _mk_account(
            s, t, e, code="5201", name_ar="إيجار",
            category="expense", subcategory="rent",
        )
        _mk_posted_je(
            s, t, e, p, debit_account=opex, credit_account=cash,
            amount=Decimal("250"), je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 0
            assert body["expense_total"] == 250.0
            assert body["net_income"] == -250.0
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Tenant isolation (3) — pin G-PILOT-REPORTS-TENANT-AUDIT contract
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
            today = date.today()
            resp = client.get(
                _is_url(
                    eb.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
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
            today = date.today()
            with caplog.at_level(
                logging.WARNING, logger="app.pilot.security.tenant_guards"
            ):
                client.get(
                    _is_url(
                        eb.id,
                        start_date=today.replace(day=1).isoformat(),
                        end_date=today.replace(day=28).isoformat(),
                    ),
                    headers={"Authorization": f"Bearer {token_a}"},
                )
            matches = [
                r for r in caplog.records
                if "TENANT_GUARD_VIOLATION" in r.getMessage()
            ]
            assert matches, (
                "expected TENANT_GUARD_VIOLATION on cross-tenant IS probe"
            )
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
            s, ta, ea, code="1101", name_ar="نقدية A", category="asset"
        )
        rev_a = _mk_account(
            s, ta, ea, code="4101", name_ar="مبيعات A",
            category="revenue", subcategory="sales",
        )
        cash_b = _mk_account(
            s, tb, eb, code="1101", name_ar="نقدية B", category="asset"
        )
        rev_b = _mk_account(
            s, tb, eb, code="4101", name_ar="مبيعات B",
            category="revenue", subcategory="sales",
        )
        _mk_posted_je(
            s, ta, ea, pa, debit_account=cash_a, credit_account=rev_a,
            amount=Decimal("100"), je_date=today,
        )
        _mk_posted_je(
            s, tb, eb, pb, debit_account=cash_b, credit_account=rev_b,
            amount=Decimal("999"), je_date=today,
        )
        s.commit()
        ids = (ta.id, tb.id, ea.id, eb.id)
        try:
            token_a = _user_token(tenant_id=ta.id)
            resp = client.get(
                _is_url(
                    ea.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token_a}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 100.0  # not 999
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Anti-mock guarantees (2) — the most important tests in this file
# ────────────────────────────────────────────────────────────────────


class TestAntiMock:
    def test_no_hardcoded_values_in_response(self, client):
        """Empty entity → response is genuinely zero everywhere.

        If any default seed / cached fallback / mock pre-fill existed,
        this would surface non-zero totals. It doesn't, so this test
        pins the guarantee.
        """
        s = SessionLocal()
        t = _mk_tenant(s, "anti1")
        e = _mk_entity(s, t, "anti1")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            today = date.today()
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            assert body["revenue_total"] == 0
            assert body["expense_total"] == 0
            assert body["net_income"] == 0
            assert body["accounts"] == []
            assert body["posted_je_count"] == 0
            assert body["revenue_by_subcat"] == {}
            assert body["expense_by_subcat"] == {}
        finally:
            s.close()
            _cleanup(*ids)

    def test_response_reflects_actual_postings_exactly(self, client):
        """Post a JE with a specific decimal amount and confirm the
        response returns the same amount byte-for-byte.

        If any rounding mock / caching layer / fallback existed, the
        12345.67 wouldn't round-trip exactly. It does, so this test
        pins it.
        """
        s = SessionLocal()
        t = _mk_tenant(s, "anti2")
        e = _mk_entity(s, t, "anti2")
        today = date.today()
        p = _mk_period(s, t, e, today)
        cash = _mk_account(s, t, e, code="1101", name_ar="نقدية", category="asset")
        rev = _mk_account(
            s, t, e, code="4101", name_ar="مبيعات",
            category="revenue", subcategory="sales",
        )
        SPECIFIC = Decimal("12345.67")
        _mk_posted_je(
            s, t, e, p, debit_account=cash, credit_account=rev,
            amount=SPECIFIC, je_date=today,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                _is_url(
                    e.id,
                    start_date=today.replace(day=1).isoformat(),
                    end_date=today.replace(day=28).isoformat(),
                ),
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["revenue_total"] == 12345.67
            assert body["net_income"] == 12345.67
            row = next(a for a in body["accounts"] if a["code"] == "4101")
            assert row["amount"] == 12345.67
            assert row["total_credit"] == 12345.67
            assert row["total_debit"] == 0.0
        finally:
            s.close()
            _cleanup(*ids)
