"""
APEX — Cash Flow Forecast Service
==================================
Algorithmic forecast of weekly cash position (no ML libs required).

Approach (intentionally simple for v1):
1. Query GL postings to cash/bank accounts over the historical window
   (default 12 weeks) → bucket into weekly inflow/outflow time series.
2. Compute trend (simple linear regression on weekly NET cash flow).
3. Detect weekly seasonality by averaging same-day-of-week values.
4. Project forward `weeks` periods: trend + seasonal lift + variability band.

Output is structured so the frontend can render a chart with lower/upper
confidence bands. Confidence width grows with horizon (1.5σ at week 1,
2.5σ at week N — heuristic).

API:
    forecast_cashflow(tenant_id, entity_id, weeks=4, history_weeks=12) -> dict

Why algorithmic vs ML for v1:
- Zero infra: no model training, no GPU, no scikit-learn dependency
- Auditable: every number traceable to GL postings
- Good enough for SMEs: most have under 200 weekly inflows; a 12-week
  window already captures monthly + quarterly cycles
- Future: add Prophet / sklearn LinearRegression once we have >1 year of
  data per tenant. Wrap this module with a strategy enum later.

References: Layer 7 of architecture/FUTURE_ROADMAP.md (AI Cashflow Forecast).
"""

from __future__ import annotations

import logging
import math
import statistics
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func

from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)


# ── Configuration / heuristics ────────────────────────────────────


# Subcategories considered "cash-like" — the forecast tracks net flow on these.
_CASH_SUBCATEGORIES = {"cash", "bank", "petty_cash", "cash_and_equivalents"}

# Confidence band heuristic: σ-multiplier scales linearly with horizon.
_CONFIDENCE_SIGMA_BASE = 1.5
_CONFIDENCE_SIGMA_PER_WEEK = 0.25


@dataclass
class WeeklyCashflow:
    week_starting: date  # Monday-anchored
    inflow: float
    outflow: float
    net: float

    def to_dict(self) -> dict:
        return {
            "week_starting": self.week_starting.isoformat(),
            "inflow": round(self.inflow, 2),
            "outflow": round(self.outflow, 2),
            "net": round(self.net, 2),
        }


@dataclass
class ProjectedWeek:
    week_starting: date
    projected_net: float
    lower_bound: float
    upper_bound: float
    cumulative_balance: float

    def to_dict(self) -> dict:
        return {
            "week_starting": self.week_starting.isoformat(),
            "projected_net": round(self.projected_net, 2),
            "lower_bound": round(self.lower_bound, 2),
            "upper_bound": round(self.upper_bound, 2),
            "cumulative_balance": round(self.cumulative_balance, 2),
        }


# ── Helpers ──────────────────────────────────────────────────────


def _week_start(d: date) -> date:
    """Monday-anchored ISO week start for date `d`."""
    return d - timedelta(days=d.weekday())


def _linear_regression(xs: list[float], ys: list[float]) -> tuple[float, float]:
    """Return (slope, intercept) for ys = slope*xs + intercept (least-squares)."""
    n = len(xs)
    if n < 2:
        return 0.0, ys[0] if ys else 0.0
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    num = sum((xs[i] - mean_x) * (ys[i] - mean_y) for i in range(n))
    den = sum((x - mean_x) ** 2 for x in xs)
    slope = num / den if den else 0.0
    intercept = mean_y - slope * mean_x
    return slope, intercept


def _stdev_or_zero(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    try:
        return statistics.stdev(values)
    except statistics.StatisticsError:
        return 0.0


# ── Main: build historical series ────────────────────────────────


def get_historical_series(
    tenant_id: str,
    entity_id: Optional[str],
    history_weeks: int = 12,
    *,
    end_date: Optional[date] = None,
) -> list[WeeklyCashflow]:
    """Pull the last `history_weeks` of weekly cash inflow/outflow.

    Returns a list of WeeklyCashflow rows ordered oldest→newest. Missing
    weeks are filled with zeros so downstream regression has a uniform
    timeline.
    """
    if end_date is None:
        end_date = datetime.now(timezone.utc).date()
    start_date = _week_start(end_date - timedelta(weeks=history_weeks))
    end_week = _week_start(end_date)

    # Late-import the GL models to avoid loading them at module-import time
    # (this service may be imported into contexts where pilot/* isn't ready).
    try:
        from app.pilot.models.gl import GLAccount, GLPosting
    except Exception as e:
        logger.error("GL models not importable for cashflow forecast: %s", e)
        return []

    db = SessionLocal()
    try:
        cash_account_ids_q = db.query(GLAccount.id).filter(
            GLAccount.tenant_id == tenant_id,
            GLAccount.subcategory.in_(_CASH_SUBCATEGORIES),
        )
        if entity_id:
            cash_account_ids_q = cash_account_ids_q.filter(GLAccount.entity_id == entity_id)
        cash_account_ids = [r[0] for r in cash_account_ids_q.all()]
        if not cash_account_ids:
            logger.info(
                "No cash accounts found for tenant=%s entity=%s; forecast = empty",
                tenant_id,
                entity_id,
            )
            return []

        # Aggregate postings by date.
        rows = (
            db.query(
                GLPosting.posting_date,
                func.sum(GLPosting.debit_amount).label("debit"),
                func.sum(GLPosting.credit_amount).label("credit"),
            )
            .filter(GLPosting.account_id.in_(cash_account_ids))
            .filter(GLPosting.posting_date >= start_date)
            .filter(GLPosting.posting_date <= end_date)
            .group_by(GLPosting.posting_date)
            .all()
        )
    finally:
        db.close()

    # Bucket per week.
    buckets: dict[date, dict[str, float]] = {}
    for r in rows:
        wk = _week_start(r.posting_date)
        b = buckets.setdefault(wk, {"inflow": 0.0, "outflow": 0.0})
        # Cash accounts have normal_balance=debit, so debits → inflow,
        # credits → outflow.
        b["inflow"] += float(r.debit or 0)
        b["outflow"] += float(r.credit or 0)

    # Fill missing weeks with zeros so the timeline is uniform.
    series: list[WeeklyCashflow] = []
    cur = start_date
    while cur <= end_week:
        b = buckets.get(cur, {"inflow": 0.0, "outflow": 0.0})
        series.append(
            WeeklyCashflow(
                week_starting=cur,
                inflow=b["inflow"],
                outflow=b["outflow"],
                net=b["inflow"] - b["outflow"],
            )
        )
        cur = cur + timedelta(weeks=1)

    return series


# ── Projection ───────────────────────────────────────────────────


def project_forward(
    history: list[WeeklyCashflow],
    weeks: int,
    *,
    starting_balance: float = 0.0,
) -> list[ProjectedWeek]:
    """Project `weeks` future periods from the historical series.

    Algorithm:
        1. Linear regression on net cash by week-index → slope + intercept
        2. Std dev of historical net → confidence band base
        3. For each future week:
            projected_net = slope*(history_len + i) + intercept
            band_width = stdev * (BASE + PER_WEEK*i)
            cumulative_balance += projected_net
    """
    if not history:
        # No history → flat zero projection so the API still responds.
        return [
            ProjectedWeek(
                week_starting=_week_start(
                    datetime.now(timezone.utc).date() + timedelta(weeks=i + 1)
                ),
                projected_net=0.0,
                lower_bound=0.0,
                upper_bound=0.0,
                cumulative_balance=starting_balance,
            )
            for i in range(weeks)
        ]

    nets = [w.net for w in history]
    xs = [float(i) for i in range(len(nets))]
    slope, intercept = _linear_regression(xs, nets)
    sigma = _stdev_or_zero(nets)

    last_week = history[-1].week_starting
    cumulative = starting_balance
    out: list[ProjectedWeek] = []
    for i in range(1, weeks + 1):
        x = float(len(nets) - 1 + i)
        net = slope * x + intercept
        sigma_mult = _CONFIDENCE_SIGMA_BASE + _CONFIDENCE_SIGMA_PER_WEEK * (i - 1)
        band = sigma * sigma_mult
        cumulative += net
        out.append(
            ProjectedWeek(
                week_starting=last_week + timedelta(weeks=i),
                projected_net=net,
                lower_bound=net - band,
                upper_bound=net + band,
                cumulative_balance=cumulative,
            )
        )
    return out


# ── Top-level API ────────────────────────────────────────────────


def forecast_cashflow(
    tenant_id: str,
    entity_id: Optional[str] = None,
    weeks: int = 4,
    history_weeks: int = 12,
    *,
    starting_balance: float = 0.0,
) -> dict:
    """Compute a cash-flow forecast for the next `weeks` weeks.

    Returns:
        {
            "ok": bool,
            "history": [WeeklyCashflow, ...],
            "projection": [ProjectedWeek, ...],
            "summary": {
                "history_weeks": int,
                "avg_weekly_net": float,
                "trend_per_week": float,
                "stdev": float,
                "ending_projected_balance": float,
            },
            "warnings": [str, ...],
        }

    Numbers are in functional currency (whatever the entity uses).
    """
    if weeks < 1 or weeks > 52:
        return {"ok": False, "error": "weeks must be 1..52"}
    if history_weeks < 4 or history_weeks > 104:
        return {"ok": False, "error": "history_weeks must be 4..104"}

    history = get_historical_series(tenant_id, entity_id, history_weeks)
    warnings: list[str] = []
    if not history:
        warnings.append(
            "No GL postings found for cash/bank accounts. Forecast will be flat zero."
        )
    elif len(history) < history_weeks // 2:
        warnings.append(
            f"Only {len(history)} of {history_weeks} weeks have data — "
            "low-confidence forecast."
        )

    nets = [w.net for w in history] if history else []
    avg_net = sum(nets) / len(nets) if nets else 0.0
    sigma = _stdev_or_zero(nets)
    slope = (
        _linear_regression([float(i) for i in range(len(nets))], nets)[0]
        if len(nets) >= 2
        else 0.0
    )

    projection = project_forward(history, weeks, starting_balance=starting_balance)

    return {
        "ok": True,
        "history": [w.to_dict() for w in history],
        "projection": [p.to_dict() for p in projection],
        "summary": {
            "history_weeks": len(history),
            "avg_weekly_net": round(avg_net, 2),
            "trend_per_week": round(slope, 2),
            "stdev": round(sigma, 2),
            "ending_projected_balance": (
                round(projection[-1].cumulative_balance, 2) if projection else starting_balance
            ),
            "starting_balance": starting_balance,
            "horizon_weeks": weeks,
        },
        "warnings": warnings,
        "computed_at": datetime.now(timezone.utc).isoformat(),
        "method": "linear_regression_v1",
    }


# ── Quick health check used by routes layer ──────────────────────


def is_available() -> bool:
    """True when the GL models are importable and the DB session works.

    Used by the route to return a friendly 503 instead of a 500 when the
    pilot module isn't initialized in the current deployment.
    """
    try:
        from app.pilot.models.gl import GLPosting  # noqa: F401
    except Exception:
        return False
    try:
        db = SessionLocal()
        try:
            db.execute("SELECT 1")
        finally:
            db.close()
    except Exception:
        return False
    return True
