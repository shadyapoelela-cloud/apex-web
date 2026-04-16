"""
APEX Platform — Depreciation Calculator
═══════════════════════════════════════════════════════════════
Computes a per-year depreciation schedule under 3 common methods:

  1. Straight-Line (SL)            — (cost − salvage) / life
  2. Declining Balance (DDB)       — 2 × SL_rate × opening_book_value
                                     (stops at salvage floor)
  3. Sum-of-Years-Digits (SYD)     — (cost − salvage) × remaining_life / sum_of_years

All math is Decimal. Rounding is 2dp via ROUND_HALF_UP.

Accepted under both IFRS (IAS 16) and SOCPA. DDB is the Saudi
tax-preferred method for heavy machinery per ZATCA corporate
income tax guidelines (informational — not tax advice).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List


_TWO = Decimal("0.01")


def _q(value: Decimal | int | float | str) -> Decimal:
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


METHODS = ("straight_line", "declining_balance", "sum_of_years_digits")


@dataclass
class DepreciationInput:
    cost: Decimal
    salvage_value: Decimal = Decimal("0")
    useful_life_years: int = 5
    method: str = "straight_line"
    asset_name: str = ""
    # Optional: partial-year proration in the first year (months in service / 12)
    first_year_months: int = 12


@dataclass
class DepreciationYear:
    year: int
    opening_book_value: Decimal
    depreciation: Decimal
    accumulated: Decimal
    closing_book_value: Decimal


@dataclass
class DepreciationResult:
    asset_name: str
    method: str
    cost: Decimal
    salvage_value: Decimal
    depreciable_base: Decimal            # cost − salvage
    useful_life_years: int
    annual_rate_pct: Decimal              # informational
    schedule: List[DepreciationYear] = field(default_factory=list)
    total_depreciation: Decimal = Decimal("0")
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════


def compute_depreciation(inp: DepreciationInput) -> DepreciationResult:
    method = (inp.method or "straight_line").lower()
    if method not in METHODS:
        raise ValueError(f"Unknown method {inp.method!r}. Expected one of {METHODS}")

    cost = _q(inp.cost)
    salvage = _q(inp.salvage_value)
    life = int(inp.useful_life_years)

    if cost <= 0:
        raise ValueError("cost must be positive")
    if life <= 0:
        raise ValueError("useful_life_years must be positive")
    if salvage < 0:
        raise ValueError("salvage_value cannot be negative")
    if salvage >= cost:
        raise ValueError("salvage_value must be less than cost")
    if inp.first_year_months < 1 or inp.first_year_months > 12:
        raise ValueError("first_year_months must be 1..12")

    depreciable_base = _q(cost - salvage)

    if method == "straight_line":
        schedule, rate_pct, warnings = _straight_line(cost, salvage, life, depreciable_base, inp.first_year_months)
    elif method == "declining_balance":
        schedule, rate_pct, warnings = _declining_balance(cost, salvage, life, inp.first_year_months)
    else:  # sum_of_years_digits
        schedule, rate_pct, warnings = _sum_of_years_digits(cost, salvage, life, depreciable_base, inp.first_year_months)

    total = sum((y.depreciation for y in schedule), Decimal("0"))

    return DepreciationResult(
        asset_name=inp.asset_name,
        method=method,
        cost=cost,
        salvage_value=salvage,
        depreciable_base=depreciable_base,
        useful_life_years=life,
        annual_rate_pct=rate_pct,
        schedule=schedule,
        total_depreciation=_q(total),
        warnings=warnings,
    )


def _straight_line(cost, salvage, life, base, first_months):
    annual = _q(base / Decimal(life))
    rate_pct = _q((Decimal("1") / Decimal(life)) * Decimal("100"))
    schedule: List[DepreciationYear] = []
    book = cost
    accum = Decimal("0")
    warnings: list[str] = []
    for y in range(1, life + 1):
        dep = annual
        if y == 1 and first_months < 12:
            dep = _q(annual * Decimal(first_months) / Decimal("12"))
        if book - dep < salvage:
            dep = _q(book - salvage)
        accum = _q(accum + dep)
        new_book = _q(book - dep)
        schedule.append(DepreciationYear(
            year=y, opening_book_value=book, depreciation=dep,
            accumulated=accum, closing_book_value=new_book,
        ))
        book = new_book
    # Final top-up to exactly salvage if rounding left a tiny residue
    residue = _q(schedule[-1].closing_book_value - salvage)
    if residue != 0 and abs(residue) < Decimal("0.05"):
        schedule[-1] = DepreciationYear(
            year=schedule[-1].year,
            opening_book_value=schedule[-1].opening_book_value,
            depreciation=_q(schedule[-1].depreciation + residue),
            accumulated=_q(schedule[-1].accumulated + residue),
            closing_book_value=salvage,
        )
    return schedule, rate_pct, warnings


def _declining_balance(cost, salvage, life, first_months):
    # Double-declining balance
    sl_rate = Decimal("1") / Decimal(life)
    ddb_rate = sl_rate * Decimal("2")
    rate_pct = _q(ddb_rate * Decimal("100"))
    schedule: List[DepreciationYear] = []
    book = cost
    accum = Decimal("0")
    warnings: list[str] = []
    for y in range(1, life + 1):
        dep = _q(book * ddb_rate)
        if y == 1 and first_months < 12:
            dep = _q(dep * Decimal(first_months) / Decimal("12"))
        # Don't depreciate below salvage
        if book - dep < salvage:
            dep = _q(book - salvage)
        if dep < 0:
            dep = Decimal("0")
        accum = _q(accum + dep)
        new_book = _q(book - dep)
        schedule.append(DepreciationYear(
            year=y, opening_book_value=book, depreciation=dep,
            accumulated=accum, closing_book_value=new_book,
        ))
        book = new_book
        if book <= salvage:
            if y < life:
                warnings.append(
                    f"تم الوصول لقيمة الخردة في السنة {y} قبل نهاية العمر الإنتاجي — "
                    f"السنوات المتبقية قيمة إهلاكها صفر."
                )
    return schedule, rate_pct, warnings


def _sum_of_years_digits(cost, salvage, life, base, first_months):
    syd = Decimal(life * (life + 1)) / Decimal("2")
    rate_pct_first = _q((Decimal(life) / syd) * Decimal("100"))
    schedule: List[DepreciationYear] = []
    book = cost
    accum = Decimal("0")
    warnings: list[str] = []
    for y in range(1, life + 1):
        remaining = Decimal(life - y + 1)
        dep = _q(base * remaining / syd)
        if y == 1 and first_months < 12:
            dep = _q(dep * Decimal(first_months) / Decimal("12"))
        if book - dep < salvage:
            dep = _q(book - salvage)
        accum = _q(accum + dep)
        new_book = _q(book - dep)
        schedule.append(DepreciationYear(
            year=y, opening_book_value=book, depreciation=dep,
            accumulated=accum, closing_book_value=new_book,
        ))
        book = new_book
    residue = _q(schedule[-1].closing_book_value - salvage)
    if residue != 0 and abs(residue) < Decimal("0.05"):
        schedule[-1] = DepreciationYear(
            year=schedule[-1].year,
            opening_book_value=schedule[-1].opening_book_value,
            depreciation=_q(schedule[-1].depreciation + residue),
            accumulated=_q(schedule[-1].accumulated + residue),
            closing_book_value=salvage,
        )
    return schedule, rate_pct_first, warnings


def result_to_dict(r: DepreciationResult) -> dict:
    return {
        "asset_name": r.asset_name,
        "method": r.method,
        "cost": f"{r.cost}",
        "salvage_value": f"{r.salvage_value}",
        "depreciable_base": f"{r.depreciable_base}",
        "useful_life_years": r.useful_life_years,
        "annual_rate_pct": f"{r.annual_rate_pct}",
        "total_depreciation": f"{r.total_depreciation}",
        "schedule": [
            {
                "year": y.year,
                "opening_book_value": f"{y.opening_book_value}",
                "depreciation": f"{y.depreciation}",
                "accumulated": f"{y.accumulated}",
                "closing_book_value": f"{y.closing_book_value}",
            }
            for y in r.schedule
        ],
        "warnings": r.warnings,
    }
