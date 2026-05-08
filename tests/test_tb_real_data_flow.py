"""G-TB-REAL-DATA-AUDIT — end-to-end tests proving the trial-balance
endpoint reflects real GL data (and no shared sentinel / mock).

Two layers of coverage:

1. **Cross-tenant isolation** (the critical bug closed in this PR).
   Before G-TB-REAL-DATA-AUDIT, `_entity_or_404` checked only
   `Entity.id == eid` — any authenticated user could pull any
   entity's TB by guessing its id. These tests assert the new
   contract: JWTs carrying tenant A get **403** when probing tenant
   B's entity, and **404** for genuinely missing ids (status code
   carries no existence-leak signal).

2. **Real data flow.** A JE in `draft` does NOT appear in the TB; a
   posted JE does. Totals match the sums of the underlying
   `pilot_journal_lines`. `posted_je_count` in the response equals
   the number of `pilot_journal_entries` with `status='posted'` and
   `je_date <= as_of` for the queried entity. No mocked / hardcoded
   numbers.

The tests use the existing FastAPI `client` fixture (real DB,
SQLite test.db). JWTs are minted via the same pattern ERR-2 +
G-DEMO-DATA-SEEDER tests use — `create_access_token(...,
tenant_id=…)` — so the JWT carries the same `tenant_id` claim that
production tokens do post-PR #169.
"""

from __future__ import annotations

import os
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import jwt as _jwt
import pytest

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.phase1.services.auth_service import (
    JWT_ALGORITHM,
    JWT_SECRET,
    create_access_token,
)
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
# Fixtures — minimal Tenant / Entity / Period / Account / JE factories
# ────────────────────────────────────────────────────────────────────


def _mk_tenant(s, suffix: str | None = None) -> Tenant:
    suffix = suffix or uuid.uuid4().hex[:8]
    t = Tenant(
        id=gen_uuid(),
        slug=f"tb-aud-{suffix}",
        legal_name_ar=f"اختبار TB {suffix}",
        primary_email=f"tb_{suffix}@example.test",
        primary_country="SA",
    )
    s.add(t)
    s.flush()
    return t


def _mk_entity(s, tenant: Tenant, suffix: str | None = None) -> Entity:
    suffix = suffix or uuid.uuid4().hex[:6]
    e = Entity(
        id=gen_uuid(),
        tenant_id=tenant.id,
        code=f"E-{suffix}",
        name_ar=f"كيان {suffix}",
        country="SA",
        functional_currency="SAR",
    )
    s.add(e)
    s.flush()
    return e


def _mk_period(s, tenant: Tenant, entity: Entity) -> FiscalPeriod:
    """A current-month fiscal period in OPEN status — needed because
    `post_journal_entry` refuses to post into a non-open period."""
    today = date.today()
    p = FiscalPeriod(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        code=f"FP-{today.year}-{today.month:02d}",
        name_ar=f"الفترة {today.year}-{today.month:02d}",
        year=today.year,
        month=today.month,
        start_date=today.replace(day=1),
        end_date=today.replace(day=28),
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
    normal_balance: str,
) -> GLAccount:
    a = GLAccount(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        code=code,
        name_ar=name_ar,
        category=category,
        type=AccountType.detail.value,
        normal_balance=normal_balance,
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
    je_date: date | None = None,
    je_number: str | None = None,
) -> JournalEntry:
    """Create + post a 2-line balanced JE. Inserts the GLPosting rows
    directly (rather than going through `post_journal_entry`) so the
    test fixtures don't depend on the full posting service contract
    — which would force us to set up sequences, period stats, and
    auth side-effects we don't need here."""
    je_date = je_date or date.today()
    je_number = je_number or f"JE-{uuid.uuid4().hex[:8]}"
    je = JournalEntry(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        fiscal_period_id=period.id,
        je_number=je_number,
        kind="manual",
        status=JournalEntryStatus.posted.value,
        memo_ar="اختبار TB — قيد متوازن",
        je_date=je_date,
        posting_date=je_date,
        currency="SAR",
        total_debit=amount,
        total_credit=amount,
        posted_at=datetime.now(timezone.utc),
    )
    s.add(je)
    s.flush()

    # Two lines, balanced.
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

    # And the matching GLPosting rows — that's what compute_trial_balance
    # actually reads from. `post_journal_entry()` is the production
    # path that creates these; here we shortcut to avoid setting up
    # the full posting machinery (sequences, period stats, auth).
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
    """A draft (un-posted) JE — has lines but NO GLPostings. Should
    NOT show up in TB."""
    je = JournalEntry(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        fiscal_period_id=period.id,
        je_number=f"JE-D-{uuid.uuid4().hex[:8]}",
        kind="manual",
        status=JournalEntryStatus.draft.value,  # draft, not posted
        memo_ar="مسودة — يجب ألا تظهر في TB",
        je_date=date.today(),
        currency="SAR",
        total_debit=amount,
        total_credit=amount,
    )
    s.add(je)
    s.flush()
    return je


def _user_token(tenant_id: str | None) -> str:
    return create_access_token(
        f"tb-aud-{uuid.uuid4().hex[:8]}",
        "tb_audit_test",
        ["registered_user"],
        tenant_id=tenant_id,
    )


def _cleanup(*ids: str) -> None:
    """Delete by id from each pilot table. Best-effort; swallows
    errors so a partial cleanup never fails the next test."""
    if not ids:
        return
    s = SessionLocal()
    try:
        s.query(GLPosting).filter(GLPosting.entity_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(JournalLine).filter(
            JournalLine.tenant_id.in_(ids)
        ).delete(synchronize_session=False)
        s.query(JournalEntry).filter(
            JournalEntry.entity_id.in_(ids)
        ).delete(synchronize_session=False)
        s.query(GLAccount).filter(GLAccount.entity_id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(FiscalPeriod).filter(
            FiscalPeriod.entity_id.in_(ids)
        ).delete(synchronize_session=False)
        s.query(Entity).filter(Entity.id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(Tenant).filter(Tenant.id.in_(ids)).delete(
            synchronize_session=False
        )
        s.commit()
    except Exception:
        s.rollback()
    finally:
        s.close()


# ────────────────────────────────────────────────────────────────────
# Cross-tenant isolation
# ────────────────────────────────────────────────────────────────────


class TestCrossTenantIsolation:
    def test_user_a_cannot_read_user_b_entity_tb(self, client):
        """Closes the L6 audit finding. Before this PR, this request
        returned 200 with tenant B's TB rows. Now it must 403."""
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
                f"/pilot/entities/{eb.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token_a}"},
            )
            assert resp.status_code == 403, resp.text
            assert "different tenant" in resp.text.lower()
        finally:
            s.close()
            _cleanup(*ids)

    def test_user_a_can_read_user_a_entity_tb(self, client):
        s = SessionLocal()
        ta = _mk_tenant(s, "ok-a")
        ea = _mk_entity(s, ta, "ok-a")
        s.commit()
        ids = (ta.id, ea.id)
        try:
            token_a = _user_token(tenant_id=ta.id)
            resp = client.get(
                f"/pilot/entities/{ea.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token_a}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["entity_id"] == ea.id
            assert body["rows"] == []  # empty entity
        finally:
            s.close()
            _cleanup(*ids)

    def test_token_without_tenant_claim_is_forbidden(self, client):
        """A JWT issued before ERR-2 Phase 3 (no `tenant_id` claim)
        cannot access the pilot GL surface. It must 403, not silently
        leak data via the legacy permissive fallback. The fix is to
        run the legacy migration (PR #170) and re-issue the token."""
        s = SessionLocal()
        t = _mk_tenant(s, "nocl")
        e = _mk_entity(s, t, "nocl")
        s.commit()
        ids = (t.id, e.id)
        try:
            token_no_claim = _user_token(tenant_id=None)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token_no_claim}"},
            )
            assert resp.status_code == 403, resp.text
        finally:
            s.close()
            _cleanup(*ids)

    def test_404_for_genuinely_missing_entity_no_info_leak(self, client):
        """A non-existent entity id must 404, not 403 — and 404 must
        not depend on the JWT's tenant. Otherwise an attacker could
        probe entity-id existence by interpreting status codes."""
        token = _user_token(tenant_id=str(uuid.uuid4()))
        resp = client.get(
            f"/pilot/entities/does-not-exist-{uuid.uuid4()}/reports/"
            "trial-balance",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404

    def test_user_b_can_read_user_b_entity_tb(self, client):
        """Symmetric to test 1 — assert no over-correction blocked
        the legitimate path."""
        s = SessionLocal()
        ta = _mk_tenant(s, "sym-a")
        tb = _mk_tenant(s, "sym-b")
        ea = _mk_entity(s, ta, "sym-a")
        eb = _mk_entity(s, tb, "sym-b")
        s.commit()
        ids = (ta.id, tb.id, ea.id, eb.id)
        try:
            token_b = _user_token(tenant_id=tb.id)
            resp = client.get(
                f"/pilot/entities/{eb.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token_b}"},
            )
            assert resp.status_code == 200, resp.text
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Real data flow
# ────────────────────────────────────────────────────────────────────


class TestRealDataFlow:
    def test_empty_entity_returns_empty_rows_and_zero_count(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "rd-empty")
        e = _mk_entity(s, t, "rd-empty")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["rows"] == []
            assert Decimal(str(body["total_debit"])) == Decimal("0")
            assert Decimal(str(body["total_credit"])) == Decimal("0")
            assert body["balanced"] is True
            assert body["posted_je_count"] == 0
        finally:
            s.close()
            _cleanup(*ids)

    def test_posted_je_appears_in_tb_with_correct_totals(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "rd-post")
        e = _mk_entity(s, t, "rd-post")
        p = _mk_period(s, t, e)
        cash = _mk_account(
            s, t, e, code="1101", name_ar="نقدية",
            category="asset",
            normal_balance=NormalBalance.debit.value,
        )
        rev = _mk_account(
            s, t, e, code="4101", name_ar="إيرادات",
            category="revenue",
            normal_balance=NormalBalance.credit.value,
        )
        _mk_posted_je(
            s, t, e, p,
            debit_account=cash,
            credit_account=rev,
            amount=Decimal("1000.00"),
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance"
                "?include_zero=false",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            # Two account rows in the TB — cash debited, revenue
            # credited — both 1000.00.
            assert len(body["rows"]) == 2
            row_codes = {r["code"] for r in body["rows"]}
            assert row_codes == {"1101", "4101"}
            assert Decimal(str(body["total_debit"])) == Decimal("1000.00")
            assert Decimal(str(body["total_credit"])) == Decimal(
                "1000.00"
            )
            assert body["balanced"] is True
            assert body["posted_je_count"] == 1
        finally:
            s.close()
            _cleanup(*ids)

    def test_draft_je_does_not_appear_in_tb(self, client):
        """Drafts have JournalLines but no GLPostings. The TB query
        reads from `pilot_gl_postings` only — so drafts must NOT
        leak into the rendered TB."""
        s = SessionLocal()
        t = _mk_tenant(s, "rd-draft")
        e = _mk_entity(s, t, "rd-draft")
        p = _mk_period(s, t, e)
        a = _mk_account(
            s, t, e, code="1102", name_ar="حساب درافت",
            category="asset",
            normal_balance=NormalBalance.debit.value,
        )
        b = _mk_account(
            s, t, e, code="4102", name_ar="إيرادات درافت",
            category="revenue",
            normal_balance=NormalBalance.credit.value,
        )
        _mk_draft_je(
            s, t, e, p,
            debit_account=a,
            credit_account=b,
            amount=Decimal("500.00"),
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            body = resp.json()
            assert body["rows"] == [], (
                "drafts must not surface in the TB — only posted "
                "entries feed pilot_gl_postings"
            )
            assert body["posted_je_count"] == 0
        finally:
            s.close()
            _cleanup(*ids)

    def test_posted_je_count_is_count_of_posted_only(self, client):
        """Mix posted + draft. `posted_je_count` must equal the
        posted subset, not the total."""
        s = SessionLocal()
        t = _mk_tenant(s, "rd-mix")
        e = _mk_entity(s, t, "rd-mix")
        p = _mk_period(s, t, e)
        a = _mk_account(
            s, t, e, code="1103", name_ar="نقدية",
            category="asset",
            normal_balance=NormalBalance.debit.value,
        )
        b = _mk_account(
            s, t, e, code="4103", name_ar="إيرادات",
            category="revenue",
            normal_balance=NormalBalance.credit.value,
        )
        # 2 posted + 1 draft
        _mk_posted_je(
            s, t, e, p, debit_account=a, credit_account=b,
            amount=Decimal("100"),
        )
        _mk_posted_je(
            s, t, e, p, debit_account=a, credit_account=b,
            amount=Decimal("200"),
        )
        _mk_draft_je(
            s, t, e, p, debit_account=a, credit_account=b,
            amount=Decimal("999"),
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["posted_je_count"] == 2
            # Totals reflect only the posted JEs (100 + 200 = 300).
            assert Decimal(str(body["total_debit"])) == Decimal("300")
            assert Decimal(str(body["total_credit"])) == Decimal("300")
        finally:
            s.close()
            _cleanup(*ids)

    def test_as_of_date_filters_je_count(self, client):
        """A JE dated AFTER `as_of` must NOT count in
        `posted_je_count` and must NOT show up in the TB."""
        s = SessionLocal()
        t = _mk_tenant(s, "rd-aof")
        e = _mk_entity(s, t, "rd-aof")
        p = _mk_period(s, t, e)
        a = _mk_account(
            s, t, e, code="1104", name_ar="نقدية",
            category="asset",
            normal_balance=NormalBalance.debit.value,
        )
        b = _mk_account(
            s, t, e, code="4104", name_ar="إيرادات",
            category="revenue",
            normal_balance=NormalBalance.credit.value,
        )
        # One in the past (visible), one in the future (hidden by as_of).
        yesterday = date.today() - timedelta(days=1)
        tomorrow = date.today() + timedelta(days=1)
        _mk_posted_je(
            s, t, e, p, debit_account=a, credit_account=b,
            amount=Decimal("100"),
            je_date=yesterday,
        )
        _mk_posted_je(
            s, t, e, p, debit_account=a, credit_account=b,
            amount=Decimal("999"),
            je_date=tomorrow,
        )
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance"
                f"?as_of={date.today().isoformat()}",
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert body["posted_je_count"] == 1
            assert Decimal(str(body["total_debit"])) == Decimal("100")
        finally:
            s.close()
            _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Schema sanity — the new field must be present on every response
# ────────────────────────────────────────────────────────────────────


class TestResponseShape:
    def test_response_carries_posted_je_count_field(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, "shp")
        e = _mk_entity(s, t, "shp")
        s.commit()
        ids = (t.id, e.id)
        try:
            token = _user_token(tenant_id=t.id)
            resp = client.get(
                f"/pilot/entities/{e.id}/reports/trial-balance",
                headers={"Authorization": f"Bearer {token}"},
            )
            body = resp.json()
            assert "posted_je_count" in body, (
                "frontend footer expects this field — schema "
                "regression would break the UI silently"
            )
            assert isinstance(body["posted_je_count"], int)
        finally:
            s.close()
            _cleanup(*ids)
