"""Fixed-asset depreciation schedules — IAS 16 aligned.

Four methods covered, each returning a period-by-period schedule the UI
can render as a table + chart:

  • straight_line      — (cost − salvage) / useful_life_periods
  • declining_balance  — fixed rate applied to NBV each period
  • double_declining   — 2× the SL rate, applied to NBV
  • units_of_production — depreciation tracks actual usage

Each row reports opening_nbv, depreciation, accumulated_depreciation,
closing_nbv — so the audit trail maps straight onto ledger postings.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Optional

_Q = Decimal("0.01")


def _q(v) -> Decimal:
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_Q, rounding=ROUND_HALF_UP)


@dataclass
class DepreciationPeriod:
    seq: int
    opening_nbv: float
    depreciation: float
    accumulated_depreciation: float
    closing_nbv: float


def straight_line(
    *, cost: float, salvage: float, useful_life_periods: int
) -> dict[str, Any]:
    """Straight-line: equal depreciation each period."""
    if useful_life_periods <= 0 or cost <= 0:
        return {"error": "cost and useful_life_periods must be > 0"}
    depreciable = _q(cost) - _q(salvage)
    per_period = _q(depreciable / useful_life_periods)
    schedule: list[DepreciationPeriod] = []
    nbv = _q(cost)
    acc = Decimal("0")
    for i in range(1, useful_life_periods + 1):
        dep = per_period if i < useful_life_periods else (depreciable - acc)
        opening = nbv
        nbv -= dep
        acc += dep
        schedule.append(DepreciationPeriod(
            seq=i,
            opening_nbv=float(opening),
            depreciation=float(dep),
            accumulated_depreciation=float(acc),
            closing_nbv=float(nbv if nbv >= 0 else Decimal("0")),
        ))
    return {
        "method": "straight_line",
        "cost": float(cost), "salvage": float(salvage),
        "useful_life_periods": useful_life_periods,
        "total_depreciation": float(depreciable),
        "schedule": [asdict(r) for r in schedule],
    }


def declining_balance(
    *, cost: float, salvage: float, useful_life_periods: int,
    rate_pct: Optional[float] = None,
) -> dict[str, Any]:
    """Fixed declining-balance. `rate_pct` defaults to 1 / useful_life_periods
    (single-declining). Depreciation stops when NBV hits salvage."""
    if useful_life_periods <= 0 or cost <= 0:
        return {"error": "cost and useful_life_periods must be > 0"}
    rate = Decimal(str(rate_pct / 100 if rate_pct is not None else 1 / useful_life_periods))
    floor = _q(salvage)
    schedule: list[DepreciationPeriod] = []
    nbv = _q(cost)
    acc = Decimal("0")
    for i in range(1, useful_life_periods + 1):
        opening = nbv
        dep = _q(nbv * rate)
        if nbv - dep < floor:
            dep = nbv - floor
        if dep < 0:
            dep = Decimal("0")
        nbv -= dep
        acc += dep
        schedule.append(DepreciationPeriod(
            seq=i,
            opening_nbv=float(opening),
            depreciation=float(dep),
            accumulated_depreciation=float(acc),
            closing_nbv=float(nbv),
        ))
    return {
        "method": "declining_balance",
        "cost": float(cost), "salvage": float(salvage),
        "useful_life_periods": useful_life_periods,
        "rate_pct": float(rate * 100),
        "total_depreciation": float(acc),
        "schedule": [asdict(r) for r in schedule],
    }


def double_declining(
    *, cost: float, salvage: float, useful_life_periods: int,
) -> dict[str, Any]:
    """Double-declining-balance: 2× the SL rate."""
    rate = 2.0 / useful_life_periods * 100
    r = declining_balance(
        cost=cost, salvage=salvage,
        useful_life_periods=useful_life_periods, rate_pct=rate,
    )
    if "method" in r:
        r["method"] = "double_declining"
    return r


def units_of_production(
    *, cost: float, salvage: float,
    total_units_lifetime: float, units_per_period: list[float],
) -> dict[str, Any]:
    """Depreciation = (cost − salvage) / total_units × units_this_period."""
    if total_units_lifetime <= 0 or cost <= 0 or not units_per_period:
        return {"error": "units must be > 0 and periods non-empty"}
    depreciable = _q(cost) - _q(salvage)
    rate_per_unit = depreciable / Decimal(str(total_units_lifetime))
    schedule: list[DepreciationPeriod] = []
    nbv = _q(cost)
    acc = Decimal("0")
    for i, units in enumerate(units_per_period, 1):
        opening = nbv
        dep = _q(Decimal(str(units)) * rate_per_unit)
        if nbv - dep < _q(salvage):
            dep = nbv - _q(salvage)
        if dep < 0:
            dep = Decimal("0")
        nbv -= dep
        acc += dep
        schedule.append(DepreciationPeriod(
            seq=i,
            opening_nbv=float(opening),
            depreciation=float(dep),
            accumulated_depreciation=float(acc),
            closing_nbv=float(nbv),
        ))
    return {
        "method": "units_of_production",
        "cost": float(cost), "salvage": float(salvage),
        "total_units_lifetime": float(total_units_lifetime),
        "rate_per_unit": float(rate_per_unit),
        "total_depreciation": float(acc),
        "schedule": [asdict(r) for r in schedule],
    }
