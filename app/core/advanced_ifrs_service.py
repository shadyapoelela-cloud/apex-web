"""
APEX Platform — Advanced IFRS standards (2 / 40 / 41)
═══════════════════════════════════════════════════════════════
• IFRS 2 Share-Based Payments (stock options, RSUs)
    - Grant-date fair value × vested portion
    - Graded vs cliff vesting
    - Forfeiture estimation
• IAS 40 Investment Property
    - Cost vs Fair-Value model
    - Rental yield + revaluation gain/loss
• IAS 41 Agriculture
    - Biological asset = FV - costs to sell at point of harvest
    - Gain/loss on initial recognition + subsequent changes
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


# ═══════════════════════════════════════════════════════════════
# IFRS 2 — Share-Based Payments
# ═══════════════════════════════════════════════════════════════


VESTING_PATTERNS = {"cliff", "graded"}
INSTRUMENT_TYPES = {"stock_option", "rsu", "phantom_stock", "sar"}


@dataclass
class SbpInput:
    plan_name: str
    instrument_type: str                  # one of INSTRUMENT_TYPES
    grant_date: str
    grant_date_fair_value_per_unit: Decimal
    units_granted: int
    vesting_period_years: int
    vesting_pattern: str = "cliff"         # cliff or graded
    forfeiture_rate_pct: Decimal = Decimal("5")
    years_elapsed: int = 0
    currency: str = "SAR"


@dataclass
class SbpResult:
    plan_name: str
    instrument_type: str
    total_grant_date_fair_value: Decimal
    expected_forfeitures: int
    expected_vesting_units: int
    expense_to_date: Decimal                 # cumulative expense
    expense_current_period: Decimal          # in the most recent year
    remaining_expense: Decimal
    vesting_progress_pct: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def compute_sbp(inp: SbpInput) -> SbpResult:
    if inp.instrument_type not in INSTRUMENT_TYPES:
        raise ValueError(f"instrument_type must be one of {sorted(INSTRUMENT_TYPES)}")
    if inp.vesting_pattern not in VESTING_PATTERNS:
        raise ValueError(f"vesting_pattern must be one of {sorted(VESTING_PATTERNS)}")
    if inp.vesting_period_years <= 0:
        raise ValueError("vesting_period_years must be positive")
    if inp.units_granted <= 0:
        raise ValueError("units_granted must be positive")
    if Decimal(str(inp.grant_date_fair_value_per_unit)) < 0:
        raise ValueError("grant_date_fair_value_per_unit cannot be negative")
    if Decimal(str(inp.forfeiture_rate_pct)) < 0 or Decimal(str(inp.forfeiture_rate_pct)) > 100:
        raise ValueError("forfeiture_rate_pct must be 0-100")

    warnings: list[str] = []
    years_elapsed = max(0, min(inp.years_elapsed, inp.vesting_period_years))

    forfeiture = Decimal(str(inp.forfeiture_rate_pct)) / Decimal("100")
    expected_forfeitures = int(Decimal(inp.units_granted) * forfeiture)
    expected_vested = inp.units_granted - expected_forfeitures

    total_fv = Decimal(str(inp.grant_date_fair_value_per_unit)) * Decimal(expected_vested)

    # Expense allocation
    if inp.vesting_pattern == "cliff":
        # Straight-line over vesting period
        per_year = total_fv / Decimal(inp.vesting_period_years)
        cumulative = per_year * Decimal(years_elapsed)
        current = per_year if years_elapsed > 0 else Decimal("0")
    else:  # graded
        # Each tranche vests evenly, each expensed over period for that tranche
        # Simplified: graded = accelerated, first year takes more
        # Use a weighted approach: sum of factors / total factors
        total_weight = Decimal(inp.vesting_period_years * (inp.vesting_period_years + 1)) / Decimal(2)
        # Year 1 gets N factor, year 2 gets (N-1)... (reverse-engineered)
        weight_to_date = sum(
            (Decimal(inp.vesting_period_years - i)
             for i in range(years_elapsed)),
            Decimal("0"),
        )
        cumulative = total_fv * weight_to_date / total_weight
        if years_elapsed > 0:
            prior_weight = sum(
                (Decimal(inp.vesting_period_years - i)
                 for i in range(max(0, years_elapsed - 1))),
                Decimal("0"),
            )
            current = total_fv * (weight_to_date - prior_weight) / total_weight
        else:
            current = Decimal("0")
        per_year = Decimal("0")

    remaining = _q(total_fv - cumulative)
    progress = Decimal("100") if inp.vesting_period_years == 0 \
        else (Decimal(years_elapsed) / Decimal(inp.vesting_period_years) * Decimal("100"))

    if years_elapsed >= inp.vesting_period_years:
        warnings.append("فترة الاستحقاق اكتملت — تم إثبات كامل المصروف.")
    elif inp.forfeiture_rate_pct > Decimal("20"):
        warnings.append("معدل السقوط أكبر من 20% — راجع سياسة المكافآت.")

    return SbpResult(
        plan_name=inp.plan_name,
        instrument_type=inp.instrument_type,
        total_grant_date_fair_value=_q(total_fv),
        expected_forfeitures=expected_forfeitures,
        expected_vesting_units=expected_vested,
        expense_to_date=_q(cumulative),
        expense_current_period=_q(current),
        remaining_expense=remaining,
        vesting_progress_pct=_q(progress),
        currency=inp.currency,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# IAS 40 — Investment Property
# ═══════════════════════════════════════════════════════════════


PROPERTY_MODELS = {"cost", "fair_value"}


@dataclass
class InvPropertyInput:
    property_name: str
    acquisition_cost: Decimal
    useful_life_years: int = 40
    residual_value: Decimal = Decimal("0")
    model: str = "fair_value"              # or 'cost'
    current_fair_value: Optional[Decimal] = None
    years_elapsed: int = 0
    rental_income_annual: Decimal = Decimal("0")
    operating_costs_annual: Decimal = Decimal("0")
    currency: str = "SAR"


@dataclass
class InvPropertyResult:
    property_name: str
    model: str
    acquisition_cost: Decimal
    accumulated_depreciation: Decimal        # cost model only
    current_carrying_amount: Decimal
    fair_value_adjustment: Decimal            # FV - CA (FV model)
    net_rental_income: Decimal
    gross_rental_yield_pct: Decimal
    net_rental_yield_pct: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def compute_investment_property(inp: InvPropertyInput) -> InvPropertyResult:
    if inp.model not in PROPERTY_MODELS:
        raise ValueError(f"model must be one of {sorted(PROPERTY_MODELS)}")
    if inp.useful_life_years <= 0 and inp.model == "cost":
        raise ValueError("useful_life_years must be positive")
    if Decimal(str(inp.acquisition_cost)) <= 0:
        raise ValueError("acquisition_cost must be positive")

    warnings: list[str] = []
    cost = Decimal(str(inp.acquisition_cost))
    residual = Decimal(str(inp.residual_value))
    years = min(max(0, inp.years_elapsed), inp.useful_life_years)

    # Cost model: depreciate straight-line
    accum = Decimal("0")
    if inp.model == "cost":
        depreciable = cost - residual
        annual = depreciable / Decimal(inp.useful_life_years)
        accum = annual * Decimal(years)
        if accum > depreciable:
            accum = depreciable
        ca = cost - accum
        fv_adj = Decimal("0")
    else:
        # FV model: no depreciation; CA = current FV
        ca = Decimal(str(inp.current_fair_value)) if inp.current_fair_value is not None else cost
        fv_adj = ca - cost
        if fv_adj != 0:
            if fv_adj > 0:
                warnings.append(f"ربح إعادة تقييم: {_q(fv_adj)} يُدرج في قائمة الدخل (IAS 40.35).")
            else:
                warnings.append(f"خسارة إعادة تقييم: {_q(-fv_adj)} تُحمّل على قائمة الدخل.")

    rental = Decimal(str(inp.rental_income_annual))
    op_costs = Decimal(str(inp.operating_costs_annual))
    net_rental = rental - op_costs

    gross_yield = Decimal("0") if cost == 0 else (rental / cost * Decimal("100"))
    net_yield = Decimal("0") if cost == 0 else (net_rental / cost * Decimal("100"))

    if net_yield < Decimal("5") and net_yield > 0:
        warnings.append("عائد صافي منخفض — راجع استراتيجية الإيجار.")

    return InvPropertyResult(
        property_name=inp.property_name,
        model=inp.model,
        acquisition_cost=_q(cost),
        accumulated_depreciation=_q(accum),
        current_carrying_amount=_q(ca),
        fair_value_adjustment=_q(fv_adj),
        net_rental_income=_q(net_rental),
        gross_rental_yield_pct=_q(gross_yield),
        net_rental_yield_pct=_q(net_yield),
        currency=inp.currency,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# IAS 41 — Agriculture (Biological Assets)
# ═══════════════════════════════════════════════════════════════


BIOLOGICAL_TYPES = {"livestock", "crops", "trees", "fish", "other"}


@dataclass
class AgricultureInput:
    asset_name: str
    biological_type: str
    units: Decimal
    fair_value_per_unit_beginning: Decimal
    fair_value_per_unit_end: Decimal
    costs_to_sell_pct: Decimal = Decimal("3")     # % of FV
    costs_incurred: Decimal = Decimal("0")
    new_units_born_or_planted: Decimal = Decimal("0")
    units_harvested_or_sold: Decimal = Decimal("0")
    currency: str = "SAR"


@dataclass
class AgricultureResult:
    asset_name: str
    biological_type: str
    fair_value_beginning: Decimal             # opening FV - CtS
    fair_value_end: Decimal                    # closing FV - CtS
    change_from_price: Decimal                 # FV change ex-units
    change_from_physical: Decimal              # growth/birth/death
    total_gain_loss: Decimal                    # recognised in P&L
    net_change: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def compute_agriculture(inp: AgricultureInput) -> AgricultureResult:
    if inp.biological_type not in BIOLOGICAL_TYPES:
        raise ValueError(f"biological_type must be one of {sorted(BIOLOGICAL_TYPES)}")
    if Decimal(str(inp.units)) < 0:
        raise ValueError("units cannot be negative")

    warnings: list[str] = []

    units = Decimal(str(inp.units))
    fv_begin_per = Decimal(str(inp.fair_value_per_unit_beginning))
    fv_end_per = Decimal(str(inp.fair_value_per_unit_end))
    cts = Decimal(str(inp.costs_to_sell_pct)) / Decimal("100")

    # FV less costs to sell
    fv_begin = units * fv_begin_per * (Decimal("1") - cts)
    fv_end = units * fv_end_per * (Decimal("1") - cts)

    # Price change effect (same units, new price)
    change_price = units * (fv_end_per - fv_begin_per) * (Decimal("1") - cts)

    # Physical change (births, growth, harvest)
    new_units = Decimal(str(inp.new_units_born_or_planted))
    harvested = Decimal(str(inp.units_harvested_or_sold))
    change_physical = (new_units - harvested) * fv_end_per * (Decimal("1") - cts)

    total = change_price + change_physical
    net = fv_end - fv_begin

    if total < 0:
        warnings.append("خسارة على القيمة العادلة للأصول البيولوجية — تُحمّل على قائمة الدخل.")
    if inp.biological_type == "livestock" and new_units == 0 and harvested == 0:
        warnings.append("لم يتم تسجيل تغيرات فعلية في قطعان الماشية — راجع الدقة.")

    return AgricultureResult(
        asset_name=inp.asset_name,
        biological_type=inp.biological_type,
        fair_value_beginning=_q(fv_begin),
        fair_value_end=_q(fv_end),
        change_from_price=_q(change_price),
        change_from_physical=_q(change_physical),
        total_gain_loss=_q(total),
        net_change=_q(net),
        currency=inp.currency,
        warnings=warnings,
    )


# Serialisers
def sbp_to_dict(r: SbpResult) -> dict:
    return {
        "plan_name": r.plan_name,
        "instrument_type": r.instrument_type,
        "total_grant_date_fair_value": f"{r.total_grant_date_fair_value}",
        "expected_forfeitures": r.expected_forfeitures,
        "expected_vesting_units": r.expected_vesting_units,
        "expense_to_date": f"{r.expense_to_date}",
        "expense_current_period": f"{r.expense_current_period}",
        "remaining_expense": f"{r.remaining_expense}",
        "vesting_progress_pct": f"{r.vesting_progress_pct}",
        "currency": r.currency,
        "warnings": r.warnings,
    }


def ip_to_dict(r: InvPropertyResult) -> dict:
    return {
        "property_name": r.property_name,
        "model": r.model,
        "acquisition_cost": f"{r.acquisition_cost}",
        "accumulated_depreciation": f"{r.accumulated_depreciation}",
        "current_carrying_amount": f"{r.current_carrying_amount}",
        "fair_value_adjustment": f"{r.fair_value_adjustment}",
        "net_rental_income": f"{r.net_rental_income}",
        "gross_rental_yield_pct": f"{r.gross_rental_yield_pct}",
        "net_rental_yield_pct": f"{r.net_rental_yield_pct}",
        "currency": r.currency,
        "warnings": r.warnings,
    }


def ag_to_dict(r: AgricultureResult) -> dict:
    return {
        "asset_name": r.asset_name,
        "biological_type": r.biological_type,
        "fair_value_beginning": f"{r.fair_value_beginning}",
        "fair_value_end": f"{r.fair_value_end}",
        "change_from_price": f"{r.change_from_price}",
        "change_from_physical": f"{r.change_from_physical}",
        "total_gain_loss": f"{r.total_gain_loss}",
        "net_change": f"{r.net_change}",
        "currency": r.currency,
        "warnings": r.warnings,
    }
