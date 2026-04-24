"""AI usage logging — track Claude token consumption per tenant/agent call.

Every Anthropic API call the Copilot agent makes lands a row here with
input/output token counts, estimated USD cost, latency, model id, and
tenant id. Two consumers:

  • Product: per-tenant quotas + pricing. A tenant on the "Lite" plan
    gets N Copilot turns/month; this log is the meter.
  • Ops:    cost alerting. A runaway prompt loop that calls tools 40×
    will show up as a spike here before the bill does.

The model is append-only (no updates). A nightly job rolls the log into
`ai_usage_daily_summary` for billing; the raw rows age out after 90 days.

Defensive design: `record_usage()` never raises. If the DB is down or the
table hasn't been migrated yet, we log to stderr and continue — the agent
must never fail because telemetry failed.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import Column, String, Integer, Float, DateTime, JSON, Index
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

logger = logging.getLogger(__name__)


# ── Pricing table (USD per 1M tokens — Anthropic public pricing) ─────
# Keep this in one place so a price change is one edit. Updated periodically.
_CLAUDE_PRICING_USD_PER_MTOK: dict[str, tuple[float, float]] = {
    # (input_per_million, output_per_million)
    "claude-opus-4-7":          (15.0, 75.0),
    "claude-opus-4-6":          (15.0, 75.0),
    "claude-opus-4-5":          (15.0, 75.0),
    "claude-sonnet-4-6":        (3.0, 15.0),
    "claude-sonnet-4-5":        (3.0, 15.0),
    "claude-haiku-4-5":         (1.0, 5.0),
    "claude-haiku-4-5-20251001": (1.0, 5.0),
}


def estimate_cost_usd(model: str, input_tokens: int, output_tokens: int) -> float:
    """Approximate USD cost using Anthropic public rates.

    Unknown models fall back to Sonnet pricing — a conservative choice
    so we surface *something* on the dashboard even for new model IDs.
    """
    if not model:
        return 0.0
    # normalize by stripping date suffixes like -20260101
    base = model
    for known in _CLAUDE_PRICING_USD_PER_MTOK:
        if model.startswith(known):
            base = known
            break
    rates = _CLAUDE_PRICING_USD_PER_MTOK.get(base) or _CLAUDE_PRICING_USD_PER_MTOK["claude-sonnet-4-6"]
    in_rate, out_rate = rates
    return round(
        (input_tokens / 1_000_000.0) * in_rate
        + (output_tokens / 1_000_000.0) * out_rate,
        6,
    )


# ── Model ─────────────────────────────────────────────────


class AIUsageLog(Base):
    """Append-only record of one Claude API call.

    One row per `client.messages.create(...)` invocation — not one row
    per agent turn. A single agent run with 3 tool-use turns produces 4
    rows (initial + 3 continuations).
    """

    __tablename__ = "ai_usage_log"
    __table_args__ = (
        Index("ix_ai_usage_tenant_time", "tenant_id", "created_at"),
        Index("ix_ai_usage_surface", "surface"),
        Index("ix_ai_usage_model", "model"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=True, index=True)
    user_id = Column(String(36), nullable=True)

    surface = Column(String(40), nullable=False)  # "copilot_agent" | "coa_engine" | "ap_agent" | ...
    model = Column(String(60), nullable=False)

    input_tokens = Column(Integer, nullable=False, default=0)
    output_tokens = Column(Integer, nullable=False, default=0)
    cache_read_tokens = Column(Integer, nullable=False, default=0)
    cache_creation_tokens = Column(Integer, nullable=False, default=0)

    cost_usd = Column(Float, nullable=False, default=0.0)
    latency_ms = Column(Integer, nullable=True)

    # Optional agent correlation — groups the 4 rows from one agent run.
    agent_run_id = Column(String(36), nullable=True, index=True)
    turn_index = Column(Integer, nullable=True)
    stop_reason = Column(String(40), nullable=True)  # "end_turn" | "tool_use" | "max_tokens"

    # Outcome flags (0/1) so ops dashboards can chart error rates.
    error = Column(Integer, nullable=False, default=0)
    error_kind = Column(String(60), nullable=True)

    # Freeform extras — tool names called, request id, anything else.
    extras = Column(JSON, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)


@dataclass
class UsageRecord:
    """Transport struct for record_usage — decouples callers from SQLAlchemy."""
    surface: str
    model: str
    input_tokens: int
    output_tokens: int
    tenant_id: Optional[str] = None
    user_id: Optional[str] = None
    cache_read_tokens: int = 0
    cache_creation_tokens: int = 0
    latency_ms: Optional[int] = None
    agent_run_id: Optional[str] = None
    turn_index: Optional[int] = None
    stop_reason: Optional[str] = None
    error: bool = False
    error_kind: Optional[str] = None
    extras: Optional[dict[str, Any]] = None


def record_usage(rec: UsageRecord) -> Optional[str]:
    """Persist one usage row. Never raises.

    Returns the new row's id on success, None on any failure (logged).
    """
    try:
        from app.phase1.models.platform_models import SessionLocal
    except Exception as e:
        logger.debug("record_usage: SessionLocal unavailable (%s)", e)
        return None

    db = SessionLocal()
    try:
        # Skip the write if the table hasn't been created — stops the
        # agent from 500-ing in a fresh test DB before migrations run.
        try:
            from sqlalchemy import inspect as _inspect
            insp = _inspect(db.get_bind())
            if "ai_usage_log" not in set(insp.get_table_names()):
                logger.debug("record_usage: ai_usage_log table not present")
                return None
        except Exception:
            pass

        cost = estimate_cost_usd(rec.model, rec.input_tokens, rec.output_tokens)
        row = AIUsageLog(
            tenant_id=rec.tenant_id,
            user_id=rec.user_id,
            surface=rec.surface,
            model=rec.model,
            input_tokens=rec.input_tokens,
            output_tokens=rec.output_tokens,
            cache_read_tokens=rec.cache_read_tokens,
            cache_creation_tokens=rec.cache_creation_tokens,
            cost_usd=cost,
            latency_ms=rec.latency_ms,
            agent_run_id=rec.agent_run_id,
            turn_index=rec.turn_index,
            stop_reason=rec.stop_reason,
            error=1 if rec.error else 0,
            error_kind=rec.error_kind,
            extras=rec.extras,
        )
        db.add(row)
        db.commit()
        return row.id
    except Exception as e:
        logger.warning("record_usage failed: %s", e)
        try:
            db.rollback()
        except Exception:
            pass
        return None
    finally:
        try:
            db.close()
        except Exception:
            pass


def tenant_usage_summary(
    tenant_id: str,
    since: Optional[datetime] = None,
) -> dict[str, Any]:
    """Roll-up for a tenant: total tokens + cost since `since` (default: month start).

    Used by the entitlements layer to enforce per-plan AI quotas.
    """
    try:
        from sqlalchemy import func
        from app.phase1.models.platform_models import SessionLocal
    except Exception:
        return {"tenant_id": tenant_id, "input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0, "calls": 0}

    if since is None:
        now = datetime.now(timezone.utc)
        since = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0, tzinfo=None)

    db = SessionLocal()
    try:
        try:
            from sqlalchemy import inspect as _inspect
            insp = _inspect(db.get_bind())
            if "ai_usage_log" not in set(insp.get_table_names()):
                return {"tenant_id": tenant_id, "input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0, "calls": 0}
        except Exception:
            pass

        row = (
            db.query(
                func.coalesce(func.sum(AIUsageLog.input_tokens), 0).label("i"),
                func.coalesce(func.sum(AIUsageLog.output_tokens), 0).label("o"),
                func.coalesce(func.sum(AIUsageLog.cost_usd), 0.0).label("c"),
                func.count(AIUsageLog.id).label("n"),
            )
            .filter(AIUsageLog.tenant_id == tenant_id)
            .filter(AIUsageLog.created_at >= since)
            .first()
        )
        return {
            "tenant_id": tenant_id,
            "since": since.isoformat(),
            "input_tokens": int(row.i or 0),
            "output_tokens": int(row.o or 0),
            "cost_usd": float(row.c or 0.0),
            "calls": int(row.n or 0),
        }
    except Exception as e:
        logger.warning("tenant_usage_summary failed: %s", e)
        return {"tenant_id": tenant_id, "input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0, "calls": 0}
    finally:
        try:
            db.close()
        except Exception:
            pass
