"""APEX Platform -- app/core/notification_digest.py unit tests.

Coverage target: ≥90% of 90 statements (G-T1.7b.3, Sprint 10).

DB-backed digest aggregator + email send. We exercise:

  * `_utcnow`, `_window_start` (daily/weekly).
  * `build_digest_for_user` — count=0 short-circuit + happy path with
    mocked `SessionLocal` returning fake NotificationV2 rows.
  * `build_digest_for_user` — `since=None` defaulting branch.
  * `send_digest_for_user` — invalid frequency, MIN_DIGEST_ITEMS skip,
    no-email user, email_service unavailable, send success/failure.
  * `process_all_due_digests` — invalid frequency, normal aggregate
    with mixed sent/skipped/error outcomes, opted-out filter.

Mocks: `SessionLocal` is monkeypatched to return a `MagicMock` whose
query chain produces controlled rows. `app.core.email_service` is
stubbed via `sys.modules` (G-T1.7b.1 Stripe pattern).
"""

from __future__ import annotations

import sys
import types
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest

from app.core import notification_digest as nd


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


def _fake_notification(
    *,
    id="n-1",
    title_ar="عنوان",
    title_en=None,
    body_ar="جسم",
    body_en=None,
    notification_type="task_assigned",
    created_at=None,
):
    """Lightweight stand-in for the NotificationV2 ORM row."""
    n = MagicMock()
    n.id = id
    n.title_ar = title_ar
    n.title_en = title_en
    n.body_ar = body_ar
    n.body_en = body_en
    n.notification_type = notification_type
    n.created_at = created_at or datetime.now(timezone.utc)
    return n


@pytest.fixture
def db_session_factory(monkeypatch):
    """Factory: configure a MagicMock SessionLocal then return it.

    Usage:
        sess = db_session_factory(notifications=[...], user_email="a@b.com",
                                  user_ids=[...], opted_out=[...])
    """
    def _make(
        *,
        notifications=None,
        user_email="user@example.com",
        user_present=True,
        user_ids=None,
        opted_out=None,
    ):
        notifications = notifications or []
        user_ids = user_ids or []
        opted_out = opted_out or []

        # The function calls SessionLocal() at least twice:
        # 1) build_digest_for_user — db.query(NotificationV2).filter().filter().filter().order_by()
        # 2) send_digest_for_user — db.query(User).filter().first()
        # 3) process_all_due_digests — db.query(User.id).all() AND db.query(NotificationPreference.user_id).filter().distinct().all()
        #
        # We use a single MagicMock per session and route by call order.

        def _new_session():
            sess = MagicMock()
            # ── build_digest_for_user query chain ──
            digest_q = MagicMock()
            digest_q.filter.return_value = digest_q
            digest_q.order_by.return_value = digest_q
            digest_q.count.return_value = len(notifications)
            digest_q.limit.return_value.all.return_value = notifications

            # ── send_digest_for_user user query chain ──
            user_q = MagicMock()
            if user_present:
                user_obj = MagicMock()
                user_obj.email = user_email
                user_q.filter.return_value.first.return_value = user_obj
            else:
                user_q.filter.return_value.first.return_value = None

            # ── process_all_due_digests user_ids query chain ──
            uids_q = MagicMock()
            uids_q.all.return_value = [(u,) for u in user_ids]

            # ── process_all_due_digests opted_out query chain ──
            opted_q = MagicMock()
            opted_q.filter.return_value.distinct.return_value.all.return_value = [
                (u,) for u in opted_out
            ]

            # Route .query() by call order: digest_q → user_q → uids_q → opted_q.
            # process_all_due_digests calls SessionLocal() FIRST, then for each
            # candidate calls send_digest_for_user which itself calls SessionLocal()
            # twice (build_digest then user lookup).
            sess.query.side_effect = [
                digest_q, user_q, uids_q, opted_q,
                # Per-user iterations (digest_q + user_q each):
                digest_q, user_q, digest_q, user_q,
                digest_q, user_q, digest_q, user_q,
            ]
            return sess

        monkeypatch.setattr(nd, "SessionLocal", _new_session)

    return _make


@pytest.fixture
def email_service_stub(monkeypatch):
    """Install a stub `app.core.email_service.send_email`."""
    stub = types.ModuleType("app.core.email_service")
    calls = []

    def fake_send(**kw):
        calls.append(kw)
        return {"success": True}

    stub.send_email = fake_send
    stub._calls = calls
    monkeypatch.setitem(sys.modules, "app.core.email_service", stub)
    return stub


# ══════════════════════════════════════════════════════════════
# Window helpers
# ══════════════════════════════════════════════════════════════


class TestWindowHelpers:
    def test_utcnow_returns_aware_datetime(self):
        now = nd._utcnow()
        assert now.tzinfo is not None
        # Should be very close to "right now".
        delta = abs((datetime.now(timezone.utc) - now).total_seconds())
        assert delta < 5

    def test_window_start_daily(self):
        start = nd._window_start("daily")
        delta = nd._utcnow() - start
        # Window is ~1 day (allow generous 0.5..1.5 day tolerance).
        assert timedelta(hours=23) < delta < timedelta(hours=25)

    def test_window_start_weekly(self):
        start = nd._window_start("weekly")
        delta = nd._utcnow() - start
        assert timedelta(days=6, hours=23) < delta < timedelta(days=7, hours=1)

    def test_window_start_unknown_falls_back_to_daily(self):
        # Spec: anything that isn't "weekly" → daily.
        start = nd._window_start("monthly")
        delta = nd._utcnow() - start
        assert timedelta(hours=23) < delta < timedelta(hours=25)


# ══════════════════════════════════════════════════════════════
# build_digest_for_user
# ══════════════════════════════════════════════════════════════


class TestBuildDigest:
    def test_zero_unread_returns_empty_dict(self, db_session_factory):
        db_session_factory(notifications=[])
        out = nd.build_digest_for_user("u1")
        assert out == {
            "count": 0, "items": [], "more": 0,
            "subject": "", "text": "", "html": "",
        }

    def test_full_digest_with_items_and_more(self, db_session_factory, monkeypatch):
        # 5 unread + cap=3 inline → "more = 2"
        notifs = [
            _fake_notification(
                id=f"n-{i}", title_ar=f"عنوان {i}", body_ar=f"جسم {i}",
            )
            for i in range(3)
        ]
        # Total count is 5 even though we only return 3 inline.
        # Patch query count separately.
        sess = MagicMock()
        q = MagicMock()
        q.filter.return_value = q
        q.order_by.return_value = q
        q.count.return_value = 5
        q.limit.return_value.all.return_value = notifs
        sess.query.return_value = q
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        out = nd.build_digest_for_user("u1", frequency="daily")
        assert out["count"] == 5
        assert len(out["items"]) == 3
        assert out["more"] == 2
        assert "5 تنبيه جديد" in out["subject"]
        # HTML body mentions "more" tail.
        assert "2 إضافي" in out["html"]
        # Plain-text body lists each item.
        for i in range(3):
            assert f"عنوان {i}" in out["text"]

    def test_weekly_subject_uses_weekly_label(self, db_session_factory):
        db_session_factory(notifications=[_fake_notification()])
        out = nd.build_digest_for_user("u1", frequency="weekly")
        assert "أسبوعك" in out["subject"]

    def test_explicit_since_overrides_default_window(self, db_session_factory):
        db_session_factory(notifications=[_fake_notification()])
        # Pass explicit since; if it doesn't blow up the default-window
        # branch is skipped (line 81-82).
        explicit = datetime.now(timezone.utc) - timedelta(days=2)
        out = nd.build_digest_for_user("u1", since=explicit)
        assert out["count"] == 1

    def test_falls_back_to_english_when_arabic_missing(self, monkeypatch):
        """Notification with only English title/body still renders."""
        sess = MagicMock()
        q = MagicMock()
        q.filter.return_value = q
        q.order_by.return_value = q
        q.count.return_value = 1
        q.limit.return_value.all.return_value = [
            _fake_notification(
                title_ar=None, title_en="English Title",
                body_ar=None, body_en="English Body",
            )
        ]
        sess.query.return_value = q
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        out = nd.build_digest_for_user("u1")
        assert "English Title" in out["text"]
        assert "English Body" in out["text"]


# ══════════════════════════════════════════════════════════════
# send_digest_for_user
# ══════════════════════════════════════════════════════════════


class TestSendDigest:
    def test_invalid_frequency_returns_error(self):
        out = nd.send_digest_for_user("u1", frequency="hourly")
        assert out == {"sent": False, "error": "invalid_frequency"}

    def test_below_threshold_skipped(self, monkeypatch):
        # Force build_digest_for_user to return a low count.
        monkeypatch.setattr(
            nd, "build_digest_for_user",
            lambda uid, frequency: {
                "count": 1, "items": [], "more": 0,
                "subject": "s", "text": "t", "html": "h",
            },
        )
        # MIN_DIGEST_ITEMS defaults to 3.
        out = nd.send_digest_for_user("u1")
        assert out == {"sent": False, "skipped": True, "count": 1}

    def test_no_email_user_returns_error(self, monkeypatch):
        monkeypatch.setattr(
            nd, "build_digest_for_user",
            lambda uid, frequency: {
                "count": 5, "items": [], "more": 0,
                "subject": "s", "text": "t", "html": "h",
            },
        )

        sess = MagicMock()
        sess.query.return_value.filter.return_value.first.return_value = None
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        out = nd.send_digest_for_user("u1")
        assert out["sent"] is False
        assert out["error"] == "no_email"
        assert out["count"] == 5

    def test_email_service_unavailable(self, monkeypatch):
        monkeypatch.setattr(
            nd, "build_digest_for_user",
            lambda uid, frequency: {
                "count": 5, "items": [], "more": 0,
                "subject": "s", "text": "t", "html": "h",
            },
        )
        # User with email present.
        sess = MagicMock()
        u = MagicMock()
        u.email = "a@b.com"
        sess.query.return_value.filter.return_value.first.return_value = u
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)
        # Force the inner `from app.core.email_service import send_email` to fail.
        import builtins
        real_import = builtins.__import__

        def boom(name, *a, **kw):
            if name == "app.core.email_service":
                raise ImportError("offline")
            return real_import(name, *a, **kw)

        monkeypatch.setattr(builtins, "__import__", boom)
        out = nd.send_digest_for_user("u1")
        assert out["sent"] is False
        assert out["error"] == "email_service_unavailable"

    def test_send_success_returns_to_field(self, monkeypatch, email_service_stub):
        monkeypatch.setattr(
            nd, "build_digest_for_user",
            lambda uid, frequency: {
                "count": 5, "items": [], "more": 0,
                "subject": "S", "text": "T", "html": "H",
            },
        )
        sess = MagicMock()
        u = MagicMock()
        u.email = "x@y.com"
        sess.query.return_value.filter.return_value.first.return_value = u
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        out = nd.send_digest_for_user("u1")
        assert out["sent"] is True
        assert out["to"] == "x@y.com"
        assert out["count"] == 5
        # send_email actually called.
        assert len(email_service_stub._calls) == 1
        assert email_service_stub._calls[0]["to"] == "x@y.com"

    def test_send_failure_propagates_error(self, monkeypatch):
        monkeypatch.setattr(
            nd, "build_digest_for_user",
            lambda uid, frequency: {
                "count": 5, "items": [], "more": 0,
                "subject": "S", "text": "T", "html": "H",
            },
        )
        sess = MagicMock()
        u = MagicMock()
        u.email = "x@y.com"
        sess.query.return_value.filter.return_value.first.return_value = u
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        # Stub email_service that returns failure.
        stub = types.ModuleType("app.core.email_service")
        stub.send_email = lambda **kw: {"success": False, "error": "smtp_dead"}
        import sys as _sys
        monkeypatch.setitem(_sys.modules, "app.core.email_service", stub)

        out = nd.send_digest_for_user("u1")
        assert out["sent"] is False
        assert out["error"] == "smtp_dead"
        assert out["count"] == 5


# ══════════════════════════════════════════════════════════════
# process_all_due_digests
# ══════════════════════════════════════════════════════════════


class TestProcessAllDueDigests:
    def test_invalid_frequency_returns_error(self):
        out = nd.process_all_due_digests("hourly")
        assert out == {"processed": 0, "error": "invalid_frequency"}

    def test_aggregates_sent_skipped_errors(self, monkeypatch):
        # 4 candidate users, 1 opted-out → 3 actually processed.
        sess = MagicMock()
        uids_q = MagicMock()
        uids_q.all.return_value = [("u1",), ("u2",), ("u3",), ("u4",)]
        opted_q = MagicMock()
        opted_q.filter.return_value.distinct.return_value.all.return_value = [("u4",)]
        # First two .query() calls get user_ids and opted_out.
        sess.query.side_effect = [uids_q, opted_q]
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        # Stub send_digest_for_user with deterministic outcomes per user.
        outcomes = {
            "u1": {"sent": True, "count": 5, "to": "x@y.com"},
            "u2": {"sent": False, "skipped": True, "count": 1},
            "u3": {"sent": False, "error": "weird_error", "count": 5},
        }

        def fake_send(uid, frequency="daily"):
            if uid not in outcomes:
                raise RuntimeError("explosion")
            return outcomes[uid]

        monkeypatch.setattr(nd, "send_digest_for_user", fake_send)

        out = nd.process_all_due_digests("daily")
        assert out["processed"] == 3  # u4 opted out
        assert out["sent"] == 1
        assert out["skipped"] == 2
        # 1 weird_error (u3 → not no_email/send_failed → recorded).
        assert any(e.get("error") == "weird_error" for e in out["errors"])

    def test_aggregates_with_exception_path(self, monkeypatch):
        sess = MagicMock()
        uids_q = MagicMock()
        uids_q.all.return_value = [("u1",)]
        opted_q = MagicMock()
        opted_q.filter.return_value.distinct.return_value.all.return_value = []
        sess.query.side_effect = [uids_q, opted_q]
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)

        def boom(uid, frequency="daily"):
            raise RuntimeError("kapow")

        monkeypatch.setattr(nd, "send_digest_for_user", boom)
        out = nd.process_all_due_digests("daily")
        assert out["processed"] == 1
        assert any("kapow" in e.get("error", "") for e in out["errors"])

    def test_no_email_skipped_silently(self, monkeypatch):
        """Errors `no_email` and `send_failed` must NOT pollute errors list."""
        sess = MagicMock()
        uids_q = MagicMock()
        uids_q.all.return_value = [("u1",), ("u2",)]
        opted_q = MagicMock()
        opted_q.filter.return_value.distinct.return_value.all.return_value = []
        sess.query.side_effect = [uids_q, opted_q]
        monkeypatch.setattr(nd, "SessionLocal", lambda: sess)
        monkeypatch.setattr(
            nd, "send_digest_for_user",
            lambda uid, frequency: {"sent": False, "error": "no_email", "count": 0}
            if uid == "u1"
            else {"sent": False, "error": "send_failed", "count": 5},
        )
        out = nd.process_all_due_digests("daily")
        assert out["processed"] == 2
        assert out["skipped"] == 2
        assert out["errors"] == []  # silent skip for no_email + send_failed
