"""
APEX Core — Payment Gateway Service
Supports multiple backends: stripe, mock (default)

Environment Variables:
- PAYMENT_BACKEND: "stripe" or "mock" (default "mock")
- STRIPE_SECRET_KEY: Stripe API secret key
- STRIPE_WEBHOOK_SECRET: Stripe webhook signing secret
- PAYMENT_CURRENCY: default "SAR"
"""
import os
import logging
import uuid
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# ─── Configuration ────────────────────────────────────────────
PAYMENT_BACKEND = os.getenv("PAYMENT_BACKEND", "mock")
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")
PAYMENT_CURRENCY = os.getenv("PAYMENT_CURRENCY", "SAR")


# ─── Stripe Backend ──────────────────────────────────────────
class StripeBackend:
    """Real Stripe API integration."""

    def __init__(self):
        try:
            import stripe
            stripe.api_key = STRIPE_SECRET_KEY
            self._stripe = stripe
            logger.info("Stripe payment backend initialized")
        except ImportError:
            logger.error("stripe package not installed — run: pip install stripe")
            raise RuntimeError("stripe package is required for Stripe backend")

    def create_checkout_session(
        self, user_id: str, plan_code: str, plan_name: str,
        amount_sar: float, period: str = "monthly"
    ) -> dict:
        """Create a Stripe Checkout session."""
        try:
            # Stripe expects amounts in smallest currency unit (halalas for SAR)
            amount_units = int(amount_sar * 100)

            line_items = [{
                "price_data": {
                    "currency": PAYMENT_CURRENCY.lower(),
                    "product_data": {
                        "name": f"APEX {plan_name} — {period}",
                        "description": f"APEX Financial Platform — {plan_name} Plan ({period})",
                    },
                    "unit_amount": amount_units,
                    "recurring": {"interval": "month" if period == "monthly" else "year"},
                },
                "quantity": 1,
            }]

            session = self._stripe.checkout.Session.create(
                payment_method_types=["card"],
                line_items=line_items,
                mode="subscription",
                metadata={
                    "user_id": user_id,
                    "plan_code": plan_code,
                    "period": period,
                },
                success_url=os.getenv("PLATFORM_URL", "https://apex-app.com") + "/payment/success?session_id={CHECKOUT_SESSION_ID}",
                cancel_url=os.getenv("PLATFORM_URL", "https://apex-app.com") + "/payment/cancel",
            )

            return {
                "success": True,
                "checkout_url": session.url,
                "session_id": session.id,
            }
        except Exception as e:
            logger.error("Stripe checkout session creation failed: %s", e)
            return {"success": False, "error": "فشل إنشاء جلسة الدفع"}

    def verify_payment(self, session_id: str) -> dict:
        """Verify a Stripe Checkout session completed."""
        try:
            session = self._stripe.checkout.Session.retrieve(session_id)
            paid = session.payment_status == "paid"
            return {
                "success": True,
                "paid": paid,
                "plan_code": session.metadata.get("plan_code", ""),
                "period": session.metadata.get("period", "monthly"),
                "stripe_subscription_id": session.subscription,
            }
        except Exception as e:
            logger.error("Stripe payment verification failed: %s", e)
            return {"success": False, "error": "فشل التحقق من الدفع"}

    def cancel_subscription(self, user_id: str, subscription_id: str = None) -> dict:
        """Cancel a Stripe subscription."""
        try:
            if not subscription_id:
                return {"success": False, "error": "معرّف الاشتراك مطلوب"}
            self._stripe.Subscription.modify(
                subscription_id, cancel_at_period_end=True
            )
            return {"success": True}
        except Exception as e:
            logger.error("Stripe subscription cancellation failed: %s", e)
            return {"success": False, "error": "فشل إلغاء الاشتراك"}


# ─── Mock Backend ─────────────────────────────────────────────
class MockBackend:
    """Mock payment backend for development and testing."""

    def create_checkout_session(
        self, user_id: str, plan_code: str, plan_name: str,
        amount_sar: float, period: str = "monthly"
    ) -> dict:
        """Create a fake checkout session."""
        session_id = f"mock_sess_{uuid.uuid4().hex[:16]}"
        checkout_url = f"/payment/mock-checkout?session_id={session_id}"
        logger.info(
            "MOCK PAYMENT: user=%s plan=%s amount=%.2f %s period=%s session=%s",
            user_id, plan_code, amount_sar, PAYMENT_CURRENCY, period, session_id,
        )
        return {
            "success": True,
            "checkout_url": checkout_url,
            "session_id": session_id,
        }

    def verify_payment(self, session_id: str) -> dict:
        """Mock always returns paid=True."""
        logger.info("MOCK VERIFY: session=%s — auto-approved", session_id)
        return {
            "success": True,
            "paid": True,
            "plan_code": "",  # will be looked up from PaymentRecord
            "period": "monthly",
        }

    def cancel_subscription(self, user_id: str, subscription_id: str = None) -> dict:
        """Mock cancellation always succeeds."""
        logger.info("MOCK CANCEL: user=%s", user_id)
        return {"success": True}


# ─── Backend Singleton ────────────────────────────────────────
_backend = None


def _get_backend():
    """Lazily initialize and return the payment backend."""
    global _backend
    if _backend is None:
        if PAYMENT_BACKEND == "stripe":
            _backend = StripeBackend()
        else:
            _backend = MockBackend()
            logger.info("Using MOCK payment backend (set PAYMENT_BACKEND=stripe for production)")
    return _backend


# ─── Public API ───────────────────────────────────────────────

def create_checkout_session(
    user_id: str, plan_code: str, plan_name: str,
    amount_sar: float, period: str = "monthly"
) -> dict:
    """
    Create a payment checkout session.
    Returns {"success": True, "checkout_url": "...", "session_id": "..."} or error.
    """
    if amount_sar <= 0:
        return {
            "success": True,
            "checkout_url": "",
            "session_id": f"free_{uuid.uuid4().hex[:12]}",
            "note": "الخطة المجانية لا تحتاج دفع",
        }
    return _get_backend().create_checkout_session(
        user_id, plan_code, plan_name, amount_sar, period
    )


def verify_payment(session_id: str) -> dict:
    """
    Verify a payment session completed.
    Returns {"success": True, "paid": True/False, "plan_code": "..."}
    """
    return _get_backend().verify_payment(session_id)


def cancel_subscription(user_id: str, subscription_id: str = None) -> dict:
    """
    Cancel recurring subscription.
    Returns {"success": True}
    """
    return _get_backend().cancel_subscription(user_id, subscription_id)


def get_payment_history(user_id: str) -> list:
    """Get user's payment history from DB."""
    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.phase8.models.phase8_models import PaymentRecord
        db = SessionLocal()
        try:
            records = (
                db.query(PaymentRecord)
                .filter(PaymentRecord.user_id == user_id)
                .order_by(PaymentRecord.created_at.desc())
                .all()
            )
            return [
                {
                    "id": r.id,
                    "plan_code": r.plan_code,
                    "amount": r.amount,
                    "currency": r.currency,
                    "payment_method": r.payment_method,
                    "status": r.status,
                    "session_id": r.session_id,
                    "created_at": r.created_at.isoformat() if r.created_at else None,
                    "completed_at": r.completed_at.isoformat() if r.completed_at else None,
                }
                for r in records
            ]
        finally:
            db.close()
    except Exception as e:
        logger.error("Failed to fetch payment history: %s", e)
        return []
