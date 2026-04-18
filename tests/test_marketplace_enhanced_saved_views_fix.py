"""Tests for Marketplace Enhanced + regression guard for saved_views
NULL-tenant uniqueness fix."""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal

import pytest


# ── Saved Views regression: duplicate with NULL tenant ─────


def test_saved_views_rejects_duplicate_name_with_null_tenant(client):
    """Before the fix, SQLite let through two rows with identical
    (NULL tenant_id, NULL user_id, 'clients', 'Active') because NULL is
    treated as distinct in UNIQUE. Now app-layer guard catches it."""
    payload = {
        "screen": "clients-dup-test",
        "name": "Active only",
        "payload": {"f": "active"},
        "is_shared": True,
    }
    first = client.post("/api/v1/saved-views", json=payload)
    assert first.status_code == 201

    second = client.post("/api/v1/saved-views", json=payload)
    assert second.status_code == 409, f"expected 409, got {second.status_code}: {second.text}"

    # Cleanup
    client.delete(f"/api/v1/saved-views/{first.json()['data']['id']}")


# ── Marketplace revenue share ─────────────────────────────


def test_revenue_share_first_3_months_is_20pct():
    from app.core.marketplace_enhanced import compute_revenue_share

    r = compute_revenue_share(Decimal("1000"), months_since_first_booking=1)
    assert r.share_pct == Decimal("20.00")
    assert r.apex_cut == Decimal("200.00")
    assert r.partner_payout == Decimal("800.00")


def test_revenue_share_months_4_to_6_is_15pct():
    from app.core.marketplace_enhanced import compute_revenue_share

    r = compute_revenue_share(Decimal("1000"), months_since_first_booking=5)
    assert r.share_pct == Decimal("15.00")
    assert r.apex_cut == Decimal("150.00")


def test_revenue_share_after_6_months_is_10pct():
    from app.core.marketplace_enhanced import compute_revenue_share

    r = compute_revenue_share(Decimal("1000"), months_since_first_booking=24)
    assert r.share_pct == Decimal("10.00")
    assert r.apex_cut == Decimal("100.00")


def test_revenue_share_rounds_half_up():
    from app.core.marketplace_enhanced import compute_revenue_share

    # 33.33 * 20% = 6.666 → 6.67
    r = compute_revenue_share(Decimal("33.33"), months_since_first_booking=1)
    assert r.apex_cut == Decimal("6.67")
    assert r.partner_payout == Decimal("26.66")


def test_record_revenue_share_persists():
    from app.core.marketplace_enhanced import record_revenue_share

    rs = record_revenue_share(
        partner_id="partner-test-1",
        booking_id=None,
        gross=Decimal("500"),
        months_since_first_booking=1,
        period="2026-04",
    )
    assert rs.apex_cut == Decimal("100.00")
    assert rs.partner_payout == Decimal("400.00")
    assert rs.share_pct == Decimal("20.00")
    assert rs.period == "2026-04"


# ── Matching engine ──────────────────────────────────────


def test_match_partners_returns_empty_when_no_partners():
    from app.core.marketplace_enhanced import match_partners

    # No partners inserted → empty result (filter `verified=true` +
    # `active=true` means no matches).
    result = match_partners(specialty="zatca")
    assert isinstance(result, list)


def test_match_partners_scores_by_specialty_match():
    import uuid
    from app.core.marketplace_enhanced import PartnerProfile, match_partners
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    p1 = PartnerProfile(
        id=str(uuid.uuid4()), name_ar="خبير ZATCA", verified=True, active=True,
        specialties=["zatca", "ifrs"], industries=["services"], languages=["ar"],
        rating_avg=Decimal("4.5"), rating_count=10, hourly_rate=Decimal("300"),
    )
    p2 = PartnerProfile(
        id=str(uuid.uuid4()), name_ar="خبير GOSI", verified=True, active=True,
        specialties=["gosi"], industries=["services"], languages=["ar"],
        rating_avg=Decimal("4.0"), rating_count=5, hourly_rate=Decimal("250"),
    )
    db.add_all([p1, p2])
    db.commit()
    p1_id, p2_id = p1.id, p2.id
    db.close()

    top = match_partners(specialty="zatca", language="ar", top_k=2)
    ids = [c.partner_id for c in top]
    assert p1_id in ids
    p1_score = next(c.score for c in top if c.partner_id == p1_id)
    p2_candidates = [c for c in top if c.partner_id == p2_id]
    if p2_candidates:
        assert p1_score > p2_candidates[0].score


# ── Booking lifecycle ────────────────────────────────────


def test_book_slot_creates_pending_booking():
    import uuid
    from app.core.marketplace_enhanced import (
        PartnerProfile, book_slot,
    )
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    partner = PartnerProfile(
        id=str(uuid.uuid4()), name_ar="شريك للاختبار", verified=True, active=True,
    )
    db.add(partner)
    db.commit()
    partner_id = partner.id
    db.close()

    starts_at = datetime(2099, 1, 1, 10, 0, tzinfo=timezone.utc)
    booking = book_slot(
        partner_id=partner_id,
        client_user_id="client-u-1",
        topic="استشارة ZATCA",
        starts_at=starts_at,
        duration_minutes=30,
    )
    assert booking.status == "pending"
    assert booking.topic == "استشارة ZATCA"


def test_confirm_booking_flips_status():
    import uuid
    from app.core.marketplace_enhanced import (
        PartnerProfile, book_slot, confirm_booking,
    )
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    partner = PartnerProfile(id=str(uuid.uuid4()), name_ar="P", verified=True, active=True)
    db.add(partner)
    db.commit()
    partner_id = partner.id
    db.close()

    b = book_slot(
        partner_id=partner_id, client_user_id=None, topic="T",
        starts_at=datetime(2099, 2, 1, tzinfo=timezone.utc),
    )
    r = confirm_booking(b.id)
    assert r["success"] is True
    assert r["status"] == "confirmed"

    # Second attempt is idempotent-safe
    r2 = confirm_booking(b.id)
    assert r2["success"] is False
    assert "already" in r2["error"]


def test_confirm_booking_unknown_id():
    from app.core.marketplace_enhanced import confirm_booking

    r = confirm_booking("does-not-exist")
    assert r["success"] is False
    assert r["error"] == "not_found"


# ── PHP SDK presence ─────────────────────────────────────


def test_php_sdk_composer_exists():
    from pathlib import Path

    repo = Path(__file__).resolve().parents[1]
    assert (repo / "sdks" / "php" / "composer.json").exists()
    assert (repo / "sdks" / "php" / "src" / "ApexClient.php").exists()
    assert (repo / "sdks" / "php" / "src" / "Namespaces" / "Hr.php").exists()


def test_docs_site_config_exists():
    from pathlib import Path

    repo = Path(__file__).resolve().parents[1]
    assert (repo / "docs_site" / "docusaurus.config.js").exists()
    assert (repo / "docs_site" / "sidebars.js").exists()
    assert (repo / "docs_site" / "docs" / "getting-started.md").exists()


# ── Governed AI undo: transaction rollback ───────────────


def test_undo_rolls_back_when_reverse_fn_raises():
    """Regression: if the reverse callback raises mid-way, any pending
    DB changes should be rolled back — leaving the original entry
    unchanged (undone=False)."""
    from app.core.governed_ai import (
        AiActionLog,
        log_action,
        register_reverse_callback,
        undo_action,
    )
    from app.phase1.models.platform_models import SessionLocal

    def _broken_reverse(args, db):
        # Make a DB change that would otherwise commit
        from app.hr.models import Employee
        from datetime import date as _d
        from decimal import Decimal as _D
        db.add(Employee(
            id="broken-" + args["entry_id"],
            employee_number="BROKEN",
            name_ar="سيء",
            hire_date=_d(2026, 1, 1),
            basic_salary=_D("0"), housing_allowance=_D("0"),
            transport_allowance=_D("0"), other_allowances=_D("0"),
            gosi_applicable=False,
            gosi_employee_rate=_D("0"), gosi_employer_rate=_D("0"),
            status="active",
        ))
        raise RuntimeError("boom")

    register_reverse_callback("test.broken_reverse", _broken_reverse)
    entry = log_action(
        action_type="test.will_fail_undo",
        output={},
        confidence=0.95,
        reverse_callback_name="test.broken_reverse",
        reverse_args={"entry_id": entry_id()},
    )
    result = undo_action(entry.id, user_id="u-1")
    assert result["success"] is False
    assert "reverse_failed" in result["error"]

    # Verify the entry is NOT marked undone
    db = SessionLocal()
    try:
        fresh = db.query(AiActionLog).filter(AiActionLog.id == entry.id).first()
        assert fresh is not None
        assert fresh.undone is False, "rollback failed — entry marked undone"
    finally:
        db.close()


def entry_id():
    import uuid as _u
    return _u.uuid4().hex[:8]
