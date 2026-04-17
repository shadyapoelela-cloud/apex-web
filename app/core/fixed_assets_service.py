"""
APEX Platform — Fixed Assets Register (full lifecycle)
═══════════════════════════════════════════════════════════════
Tracks the life of a fixed asset from acquisition through
disposal:

  1. Capitalise (acquisition cost + IDC + transport + install)
  2. Depreciate each period (SL / DDB / SYD / UOP)
  3. Revalue (IAS 16 revaluation model) if elected
  4. Impair per IAS 36 if recoverable < CA
  5. Dispose (sale, scrap, trade-in) — compute gain/loss

All monetary values are Decimal(2dp).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


DEPRECIATION_METHODS = {"straight_line", "double_declining", "sum_of_years", "units_of_production"}
DISPOSAL_METHODS = {"sale", "scrap", "trade_in", "donation"}


@dataclass
class AssetInput:
    asset_code: str
    asset_name: str
    asset_class: str                      # ppe / intangible / vehicle / it_equipment
    acquisition_date: str
    acquisition_cost: Decimal
    initial_direct_costs: Decimal = Decimal("0")
    useful_life_years: int = 5
    residual_value: Decimal = Decimal("0")
    depreciation_method: str = "straight_line"
    currency: str = "SAR"
    # For units-of-production
    total_units_expected: Optional[Decimal] = None
    units_produced: Optional[Decimal] = None
    # Revaluation
    revaluation_amount: Optional[Decimal] = None  # new FV at revaluation date
    revaluation_years_elapsed: Optional[int] = None
    # Impairment
    impairment_loss: Decimal = Decimal("0")
    # Disposal
    disposal_method: Optional[str] = None
    disposal_date: Optional[str] = None
    disposal_proceeds: Decimal = Decimal("0")
    years_elapsed_at_disposal: Optional[int] = None


@dataclass
class YearRow:
    year: int
    opening_book_value: Decimal
    depreciation_expense: Decimal
    accumulated_depreciation: Decimal
    closing_book_value: Decimal
    event: str = ""                       # "revaluation" | "impairment" | "disposal" | ""


@dataclass
class AssetResult:
    asset_code: str
    asset_name: str
    asset_class: str
    capitalised_cost: Decimal            # acquisition + IDC
    depreciable_base: Decimal            # cost - residual
    useful_life_years: int
    depreciation_method: str
    annual_depreciation: Decimal         # for SL, constant; else first-year
    schedule: List[YearRow]
    total_depreciation: Decimal
    current_book_value: Decimal
    is_disposed: bool
    gain_loss_on_disposal: Decimal       # positive=gain, negative=loss
    currency: str
    warnings: list[str] = field(default_factory=list)


def _sl(cost: Decimal, residual: Decimal, life: int) -> Decimal:
    return (cost - residual) / Decimal(life)


def _ddb_rate(life: int) -> Decimal:
    return Decimal("2") / Decimal(life)


def _syd_factor(year: int, life: int) -> Decimal:
    # year 1 gets life/SYD, year 2 gets (life-1)/SYD, ...
    syd = Decimal(life * (life + 1)) / Decimal("2")
    return Decimal(life - year + 1) / syd


def build_asset(inp: AssetInput) -> AssetResult:
    if Decimal(str(inp.acquisition_cost)) <= 0:
        raise ValueError("acquisition_cost must be positive")
    if inp.useful_life_years <= 0:
        raise ValueError("useful_life_years must be positive")
    if inp.depreciation_method not in DEPRECIATION_METHODS:
        raise ValueError(
            f"depreciation_method must be one of {sorted(DEPRECIATION_METHODS)}"
        )
    if inp.disposal_method is not None and inp.disposal_method not in DISPOSAL_METHODS:
        raise ValueError(
            f"disposal_method must be one of {sorted(DISPOSAL_METHODS)}"
        )
    if Decimal(str(inp.residual_value)) < 0:
        raise ValueError("residual_value cannot be negative")

    warnings: list[str] = []

    cost = Decimal(str(inp.acquisition_cost)) + Decimal(str(inp.initial_direct_costs))
    residual = Decimal(str(inp.residual_value))
    depreciable = cost - residual
    if depreciable < 0:
        raise ValueError("residual_value exceeds capitalised cost")

    life = int(inp.useful_life_years)
    method = inp.depreciation_method

    # Build schedule
    schedule: List[YearRow] = []
    book_value = cost
    accum = Decimal("0")

    for yr in range(1, life + 1):
        opening = book_value

        if method == "straight_line":
            dep = _sl(cost, residual, life)
        elif method == "double_declining":
            # DDB: 2/life × book_value; cap at (book - residual)
            dep = book_value * _ddb_rate(life)
            # Don't depreciate below residual
            if book_value - dep < residual:
                dep = book_value - residual
        elif method == "sum_of_years":
            dep = depreciable * _syd_factor(yr, life)
        elif method == "units_of_production":
            if not inp.total_units_expected or inp.total_units_expected == 0:
                raise ValueError("units_of_production requires total_units_expected > 0")
            units_this = Decimal(str(inp.units_produced)) / Decimal(life) \
                if inp.units_produced is not None else \
                Decimal(str(inp.total_units_expected)) / Decimal(life)
            dep = depreciable * units_this / Decimal(str(inp.total_units_expected))
        else:
            dep = Decimal("0")

        dep = _q(dep)
        # Never depreciate below residual
        if book_value - dep < residual:
            dep = max(Decimal("0"), book_value - residual)
            dep = _q(dep)

        accum += dep
        book_value -= dep
        event = ""

        # Apply revaluation at specified year
        if inp.revaluation_amount is not None and inp.revaluation_years_elapsed == yr:
            new_fv = Decimal(str(inp.revaluation_amount))
            revaluation_delta = new_fv - book_value
            book_value = new_fv
            event = f"revaluation Δ={_q(revaluation_delta)}"
            warnings.append(
                f"السنة {yr}: إعادة تقييم إلى {_q(new_fv)} (فارق {_q(revaluation_delta)})"
            )

        # Apply impairment
        if inp.impairment_loss > 0 and yr == life // 2:
            loss = Decimal(str(inp.impairment_loss))
            book_value -= loss
            event = (event + " + " if event else "") + f"impairment -{_q(loss)}"

        # Apply disposal
        if inp.years_elapsed_at_disposal == yr and inp.disposal_method:
            event = (event + " + " if event else "") + f"disposal ({inp.disposal_method})"

        schedule.append(YearRow(
            year=yr,
            opening_book_value=_q(opening),
            depreciation_expense=_q(dep),
            accumulated_depreciation=_q(accum),
            closing_book_value=_q(book_value),
            event=event,
        ))

        # Stop if disposed
        if inp.years_elapsed_at_disposal == yr:
            break

    # Disposal gain/loss
    is_disposed = inp.disposal_method is not None
    gain_loss = Decimal("0")
    if is_disposed:
        disposal_bv = book_value
        proceeds = Decimal(str(inp.disposal_proceeds))
        gain_loss = proceeds - disposal_bv
        if gain_loss > 0:
            warnings.append(
                f"ربح تخلص: {_q(gain_loss)} {inp.currency} — "
                "يُدرج في الإيرادات الأخرى."
            )
        elif gain_loss < 0:
            warnings.append(
                f"خسارة تخلص: {_q(-gain_loss)} {inp.currency} — "
                "تُدرج في المصروفات."
            )

    # First-year depreciation (for summary)
    first_dep = schedule[0].depreciation_expense if schedule else Decimal("0")

    return AssetResult(
        asset_code=inp.asset_code,
        asset_name=inp.asset_name,
        asset_class=inp.asset_class,
        capitalised_cost=_q(cost),
        depreciable_base=_q(depreciable),
        useful_life_years=life,
        depreciation_method=method,
        annual_depreciation=first_dep,
        schedule=schedule,
        total_depreciation=_q(accum),
        current_book_value=_q(book_value),
        is_disposed=is_disposed,
        gain_loss_on_disposal=_q(gain_loss),
        currency=inp.currency,
        warnings=warnings,
    )


def to_dict(r: AssetResult) -> dict:
    return {
        "asset_code": r.asset_code,
        "asset_name": r.asset_name,
        "asset_class": r.asset_class,
        "capitalised_cost": f"{r.capitalised_cost}",
        "depreciable_base": f"{r.depreciable_base}",
        "useful_life_years": r.useful_life_years,
        "depreciation_method": r.depreciation_method,
        "annual_depreciation": f"{r.annual_depreciation}",
        "schedule": [
            {
                "year": row.year,
                "opening_book_value": f"{row.opening_book_value}",
                "depreciation_expense": f"{row.depreciation_expense}",
                "accumulated_depreciation": f"{row.accumulated_depreciation}",
                "closing_book_value": f"{row.closing_book_value}",
                "event": row.event,
            } for row in r.schedule
        ],
        "total_depreciation": f"{r.total_depreciation}",
        "current_book_value": f"{r.current_book_value}",
        "is_disposed": r.is_disposed,
        "gain_loss_on_disposal": f"{r.gain_loss_on_disposal}",
        "currency": r.currency,
        "warnings": r.warnings,
    }
