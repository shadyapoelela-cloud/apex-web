"""APEX Platform -- app/core/payment_service.py unit tests.

Coverage target: ≥80% of 84 statements (G-T1.7b.1, Sprint 9).

Two backends to cover:
  * MockBackend — pure-Python, hit directly.
  * StripeBackend — covered with a `sys.modules['stripe']` stub so we
    exercise the orchestration code WITHOUT making real API calls.

Plus the public-API layer (`create_checkout_session`,
`verify_payment`, `cancel_subscription`, `get_payment_history`) and
the `_get_backend()` factory.

Module-level singleton ``_backend`` is reset between tests via the
``_reset_backend`` fixture so ``_get_backend()``'s init branch fires.
"""

from __future__ import annotations

import sys
import types
from unittest.mock import MagicMock, patch

import pytest

from app.core import payment_service as ps


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture(autouse=True)
def _reset_backend():
    """Force `_get_backend()` re-init so each test sees a clean factory."""
    saved = ps._backend
    ps._backend = None
    yield
    ps._backend = saved


@pytest.fixture
def stripe_stub(monkeypatch):
    """Install a minimal `stripe` module stub so StripeBackend can boot
    without the real SDK on the import path."""
    stub = types.ModuleType("stripe")
    stub.api_key = None

    # checkout.Session.create / .retrieve are accessed as attributes.
    session_obj = MagicMock()
    session_obj.url = "https://stripe.test/checkout/sess_abc"
    session_obj.id = "sess_abc"
    session_obj.payment_status = "paid"
    session_obj.subscription = "sub_xyz"
    session_obj.metadata = {"plan_code": "pro", "period": "monthly"}

    checkout_module = types.SimpleNamespace(
        Session=types.SimpleNamespace(
            create=MagicMock(return_value=session_obj),
            retrieve=MagicMock(return_value=session_obj),
        )
    )
    stub.checkout = checkout_module
    stub.Subscription = types.SimpleNamespace(modify=MagicMock(return_value=None))

    monkeypatch.setitem(sys.modules, "stripe", stub)
    return stub


# ══════════════════════════════════════════════════════════════
# MockBackend
# ══════════════════════════════════════════════════════════════


class TestMockBackend:
    def test_create_checkout_session_returns_mock_url_and_id(self):
        be = ps.MockBackend()
        out = be.create_checkout_session(
            user_id="u1",
            plan_code="pro",
            plan_name="Pro",
            amount_sar=99.0,
            period="monthly",
        )
        assert out["success"] is True
        assert out["session_id"].startswith("mock_sess_")
        assert "/payment/mock-checkout?session_id=" in out["checkout_url"]

    def test_verify_payment_always_paid_true(self):
        be = ps.MockBackend()
        out = be.verify_payment("mock_sess_abc")
        assert out == {
            "success": True,
            "paid": True,
            "plan_code": "",
            "period": "monthly",
        }

    def test_cancel_subscription_returns_success(self):
        be = ps.MockBackend()
        out = be.cancel_subscription("u1", subscription_id="sub_x")
        assert out == {"success": True}

    def test_cancel_subscription_no_subscription_id_still_succeeds(self):
        # Mock backend does not require a subscription_id.
        be = ps.MockBackend()
        assert be.cancel_subscription("u1") == {"success": True}


# ══════════════════════════════════════════════════════════════
# StripeBackend — orchestration only, no real API
# ══════════════════════════════════════════════════════════════


class TestStripeBackendInit:
    def test_init_succeeds_when_stripe_installed(self, stripe_stub):
        be = ps.StripeBackend()
        assert be._stripe is stripe_stub
        # api_key was set from STRIPE_SECRET_KEY.
        assert hasattr(stripe_stub, "api_key")

    def test_init_raises_runtime_error_when_stripe_missing(self, monkeypatch):
        # Force the `import stripe` inside __init__ to fail.
        monkeypatch.setitem(sys.modules, "stripe", None)
        with pytest.raises(RuntimeError, match="stripe package is required"):
            ps.StripeBackend()


class TestStripeBackendCheckout:
    def test_create_checkout_session_returns_url_and_id(self, stripe_stub):
        be = ps.StripeBackend()
        out = be.create_checkout_session(
            user_id="u1",
            plan_code="pro",
            plan_name="Pro",
            amount_sar=99.0,
            period="monthly",
        )
        assert out["success"] is True
        assert out["checkout_url"] == "https://stripe.test/checkout/sess_abc"
        assert out["session_id"] == "sess_abc"
        # Yearly period also exercised.
        out_y = be.create_checkout_session(
            user_id="u1",
            plan_code="pro",
            plan_name="Pro",
            amount_sar=999.0,
            period="yearly",
        )
        assert out_y["success"] is True

    def test_create_checkout_session_handles_stripe_error(self, stripe_stub):
        stripe_stub.checkout.Session.create.side_effect = RuntimeError("boom")
        be = ps.StripeBackend()
        out = be.create_checkout_session("u1", "pro", "Pro", 99.0)
        assert out == {"success": False, "error": "فشل إنشاء جلسة الدفع"}


class TestStripeBackendVerify:
    def test_verify_payment_paid_true(self, stripe_stub):
        be = ps.StripeBackend()
        out = be.verify_payment("sess_abc")
        assert out["success"] is True
        assert out["paid"] is True
        assert out["plan_code"] == "pro"
        assert out["period"] == "monthly"
        assert out["stripe_subscription_id"] == "sub_xyz"

    def test_verify_payment_handles_stripe_error(self, stripe_stub):
        stripe_stub.checkout.Session.retrieve.side_effect = RuntimeError("err")
        be = ps.StripeBackend()
        out = be.verify_payment("sess_abc")
        assert out == {"success": False, "error": "فشل التحقق من الدفع"}


class TestStripeBackendCancel:
    def test_cancel_subscription_success(self, stripe_stub):
        be = ps.StripeBackend()
        out = be.cancel_subscription("u1", subscription_id="sub_xyz")
        assert out == {"success": True}

    def test_cancel_subscription_missing_id_returns_error(self, stripe_stub):
        be = ps.StripeBackend()
        out = be.cancel_subscription("u1")  # no subscription_id
        assert out == {"success": False, "error": "معرّف الاشتراك مطلوب"}

    def test_cancel_subscription_handles_stripe_error(self, stripe_stub):
        stripe_stub.Subscription.modify.side_effect = RuntimeError("api err")
        be = ps.StripeBackend()
        out = be.cancel_subscription("u1", subscription_id="sub_xyz")
        assert out == {"success": False, "error": "فشل إلغاء الاشتراك"}


# ══════════════════════════════════════════════════════════════
# Factory + public API
# ══════════════════════════════════════════════════════════════


class TestBackendFactory:
    def test_get_backend_defaults_to_mock(self, monkeypatch):
        monkeypatch.setattr(ps, "PAYMENT_BACKEND", "mock", raising=False)
        be = ps._get_backend()
        assert isinstance(be, ps.MockBackend)
        # Singleton: same instance on second call.
        assert ps._get_backend() is be

    def test_get_backend_returns_stripe_when_configured(
        self, monkeypatch, stripe_stub
    ):
        monkeypatch.setattr(ps, "PAYMENT_BACKEND", "stripe", raising=False)
        be = ps._get_backend()
        assert isinstance(be, ps.StripeBackend)


class TestPublicAPI:
    def test_create_checkout_session_zero_amount_short_circuits(self, monkeypatch):
        monkeypatch.setattr(ps, "PAYMENT_BACKEND", "mock", raising=False)
        out = ps.create_checkout_session("u1", "free", "Free", 0.0)
        assert out["success"] is True
        assert out["session_id"].startswith("free_")
        assert out["checkout_url"] == ""
        assert "note" in out  # free-plan note set

    def test_create_checkout_session_paid_path_routes_to_backend(self, monkeypatch):
        monkeypatch.setattr(ps, "PAYMENT_BACKEND", "mock", raising=False)
        out = ps.create_checkout_session("u1", "pro", "Pro", 99.0, "monthly")
        # Routes through MockBackend → mock_sess_ prefix.
        assert out["session_id"].startswith("mock_sess_")

    def test_verify_payment_routes_to_backend(self, monkeypatch):
        monkeypatch.setattr(ps, "PAYMENT_BACKEND", "mock", raising=False)
        out = ps.verify_payment("mock_sess_abc")
        assert out["paid"] is True

    def test_cancel_subscription_routes_to_backend(self, monkeypatch):
        monkeypatch.setattr(ps, "PAYMENT_BACKEND", "mock", raising=False)
        assert ps.cancel_subscription("u1") == {"success": True}


class TestPaymentHistory:
    def test_get_payment_history_returns_list(self):
        # Returns [] when DB has no records OR when models not importable.
        out = ps.get_payment_history("nonexistent-user-xyz")
        assert isinstance(out, list)

    def test_get_payment_history_handles_failure_gracefully(self, monkeypatch):
        # Force the DB import inside the function to blow up — should
        # still return [] (defensive try/except).
        import builtins

        real_import = builtins.__import__

        def boom(name, *args, **kwargs):
            if "phase8_models" in name or "phase1.models.platform_models" in name:
                raise RuntimeError("simulated import failure")
            return real_import(name, *args, **kwargs)

        monkeypatch.setattr(builtins, "__import__", boom)
        out = ps.get_payment_history("u1")
        assert out == []
