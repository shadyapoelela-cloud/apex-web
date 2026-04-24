"""Per-tier AI rate limits.

Soft-caps Claude usage per subscription plan per month. Implementation
is advisory (returns a decision object callers check BEFORE calling the
Anthropic API) — not a middleware, because rate-limiting Claude with a
middleware is too blunt (each agent turn can call 3-5 tools and each
tool might not actually call Claude).

Tiers and monthly ceilings (can be overridden via env or DB):

  free       → 50 calls / month, $1 cap
  pro        → 500 / month, $10 cap
  business   → 2,000 / month, $40 cap
  expert     → 10,000 / month, $200 cap
  enterprise → unlimited (monitored, not capped)

Called from `/api/v1/ai/ask` handler and surfaced in the AI Console
"usage" widget so the tenant sees "you've used 42/500 calls".
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


# Per-tier defaults — env overrides allow ops tuning without a deploy.
_DEFAULTS = {
    "free":       {"max_calls": 50,     "max_cost_usd": 1.0},
    "pro":        {"max_calls": 500,    "max_cost_usd": 10.0},
    "business":   {"max_calls": 2_000,  "max_cost_usd": 40.0},
    "expert":     {"max_calls": 10_000, "max_cost_usd": 200.0},
    "enterprise": {"max_calls": 0,      "max_cost_usd": 0.0},    # 0 = unlimited
}


def _tier_limits(tier: str) -> dict[str, float]:
    env_calls = os.environ.get(f"AI_QUOTA_{tier.upper()}_CALLS")
    env_cost = os.environ.get(f"AI_QUOTA_{tier.upper()}_COST_USD")
    base = _DEFAULTS.get(tier, _DEFAULTS["free"])
    return {
        "max_calls": float(env_calls) if env_calls else base["max_calls"],
        "max_cost_usd": float(env_cost) if env_cost else base["max_cost_usd"],
    }


@dataclass
class QuotaDecision:
    allowed: bool
    tier: str
    calls_used: int
    max_calls: float
    cost_used: float
    max_cost_usd: float
    reason: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "allowed": self.allowed,
            "tier": self.tier,
            "calls_used": self.calls_used,
            "max_calls": self.max_calls,
            "cost_used": round(self.cost_used, 4),
            "max_cost_usd": self.max_cost_usd,
            "reason": self.reason,
        }


def _resolve_tenant_tier(tenant_id: str) -> str:
    """Look up the tenant's current plan tier. Defaults to 'free' if the
    subscription layer isn't loaded or the tenant has no active plan."""
    try:
        from app.phase1.models.platform_models import (
            SessionLocal, UserSubscription, Plan, SubscriptionStatus,
        )
        db = SessionLocal()
        try:
            row = (
                db.query(UserSubscription, Plan)
                .join(Plan, UserSubscription.plan_id == Plan.id)
                .filter(UserSubscription.tenant_id == tenant_id)
                .filter(UserSubscription.status == SubscriptionStatus.active.value)
                .order_by(UserSubscription.created_at.desc())
                .first()
            )
            if row and row[1].code:
                return row[1].code
        finally:
            db.close()
    except Exception as e:
        logger.debug("tier lookup failed for %s: %s", tenant_id, e)
    return os.environ.get("AI_DEFAULT_TIER", "free")


def check_quota(tenant_id: Optional[str]) -> QuotaDecision:
    """Decide whether this tenant is allowed to make another Claude call.

    Resolves the tier, pulls this month's tenant_usage_summary, and
    compares against the tier limits. Never blocks on lookup failures
    — degrades to "allowed" so telemetry bugs don't break AI features.
    """
    if not tenant_id:
        # Anonymous / internal calls: allowed. The server-side
        # audit_trail still records who made the call.
        return QuotaDecision(
            allowed=True, tier="internal", calls_used=0,
            max_calls=0, cost_used=0.0, max_cost_usd=0.0,
            reason="internal / no tenant",
        )

    tier = _resolve_tenant_tier(tenant_id)
    limits = _tier_limits(tier)

    # Unlimited tier (enterprise)
    if limits["max_calls"] == 0 and limits["max_cost_usd"] == 0:
        return QuotaDecision(
            allowed=True, tier=tier, calls_used=0,
            max_calls=0, cost_used=0.0, max_cost_usd=0.0,
            reason="unlimited tier",
        )

    try:
        from app.core.ai_usage_log import tenant_usage_summary
        now = datetime.now(timezone.utc).replace(day=1, hour=0, minute=0, second=0, microsecond=0, tzinfo=None)
        s = tenant_usage_summary(tenant_id, since=now)
    except Exception as e:
        logger.debug("usage lookup failed: %s — allowing", e)
        return QuotaDecision(
            allowed=True, tier=tier, calls_used=0,
            max_calls=limits["max_calls"], cost_used=0.0,
            max_cost_usd=limits["max_cost_usd"],
            reason="usage lookup failed",
        )

    calls = int(s.get("calls", 0))
    cost = float(s.get("cost_usd", 0))
    if limits["max_calls"] and calls >= limits["max_calls"]:
        return QuotaDecision(
            allowed=False, tier=tier, calls_used=calls,
            max_calls=limits["max_calls"], cost_used=cost,
            max_cost_usd=limits["max_cost_usd"],
            reason=f"monthly call quota exhausted ({calls}/{int(limits['max_calls'])})",
        )
    if limits["max_cost_usd"] and cost >= limits["max_cost_usd"]:
        return QuotaDecision(
            allowed=False, tier=tier, calls_used=calls,
            max_calls=limits["max_calls"], cost_used=cost,
            max_cost_usd=limits["max_cost_usd"],
            reason=f"monthly cost cap reached (${cost:.2f}/${limits['max_cost_usd']:.2f})",
        )

    return QuotaDecision(
        allowed=True, tier=tier, calls_used=calls,
        max_calls=limits["max_calls"], cost_used=cost,
        max_cost_usd=limits["max_cost_usd"],
    )
