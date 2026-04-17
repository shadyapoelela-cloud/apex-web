"""
APEX Platform — IAS 36 Impairment of Assets
═══════════════════════════════════════════════════════════════
Tests whether the carrying amount of an asset (or CGU) exceeds
its recoverable amount:

  Recoverable = max(Value in Use, Fair Value − Costs to Sell)

  If CA > Recoverable  →  Impairment loss = CA − Recoverable

Indicators of impairment:
  External: market value decline, interest rate rise, market cap < NAV
  Internal: obsolescence, physical damage, restructuring plans,
            economic performance worse than expected

Value-in-use = PV of future cash flows discounted at pre-tax rate.
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


@dataclass
class ImpairmentInput:
    asset_name: str
    asset_class: str                      # 'goodwill' | 'ppe' | 'intangible' | 'cgu'
    carrying_amount: Decimal
    # Either supply fair_value_less_costs OR future_cash_flows+discount_rate
    fair_value_less_costs_to_sell: Optional[Decimal] = None
    future_cash_flows: List[Decimal] = field(default_factory=list)
    discount_rate_pct: Decimal = Decimal("10")
    terminal_value: Decimal = Decimal("0")
    currency: str = "SAR"
    accumulated_impairment: Decimal = Decimal("0")


@dataclass
class ImpairmentResult:
    asset_name: str
    asset_class: str
    carrying_amount: Decimal
    fair_value_less_costs: Decimal
    value_in_use: Decimal
    recoverable_amount: Decimal           # max(FV, VIU)
    impairment_loss: Decimal              # 0 if no impairment
    recoverable_method: str               # 'fair_value' | 'value_in_use'
    is_impaired: bool
    post_impairment_ca: Decimal           # carrying - loss
    currency: str
    warnings: list[str] = field(default_factory=list)


def test_impairment(inp: ImpairmentInput) -> ImpairmentResult:
    ca = Decimal(str(inp.carrying_amount))
    if ca < 0:
        raise ValueError("carrying_amount cannot be negative")

    warnings: list[str] = []

    # Value in Use (VIU) = PV of future cash flows + terminal
    viu = Decimal("0")
    if inp.future_cash_flows:
        rate = Decimal(str(inp.discount_rate_pct)) / Decimal("100")
        if rate <= 0:
            raise ValueError("discount_rate_pct must be positive when computing VIU")
        for t, cf in enumerate(inp.future_cash_flows, start=1):
            cfd = Decimal(str(cf))
            viu += cfd / ((Decimal("1") + rate) ** t)
        # Terminal value discounted at last period
        tv = Decimal(str(inp.terminal_value))
        if tv > 0:
            viu += tv / ((Decimal("1") + rate) ** len(inp.future_cash_flows))

    fv = Decimal(str(inp.fair_value_less_costs_to_sell)) \
        if inp.fair_value_less_costs_to_sell is not None else Decimal("0")

    if fv == 0 and viu == 0:
        raise ValueError(
            "must supply either fair_value_less_costs_to_sell or future_cash_flows"
        )

    recoverable = max(fv, viu)
    method = "fair_value" if fv >= viu else "value_in_use"

    loss = Decimal("0")
    impaired = False
    if ca > recoverable:
        loss = ca - recoverable
        impaired = True

    # Goodwill — cannot reverse impairment
    if inp.asset_class == "goodwill" and impaired:
        warnings.append(
            "انخفاض في الشهرة (Goodwill) — لا يمكن عكسه وفق IAS 36.124."
        )
    elif impaired:
        warnings.append(
            f"الأصل غير قابل للاسترداد — خسارة انخفاض القيمة {_q(loss)} {inp.currency}."
        )
    else:
        warnings.append(
            "لا توجد مؤشرات على انخفاض القيمة — القيمة الدفترية < قيمة الاسترداد."
        )

    return ImpairmentResult(
        asset_name=inp.asset_name,
        asset_class=inp.asset_class,
        carrying_amount=_q(ca),
        fair_value_less_costs=_q(fv),
        value_in_use=_q(viu),
        recoverable_amount=_q(recoverable),
        impairment_loss=_q(loss),
        recoverable_method=method,
        is_impaired=impaired,
        post_impairment_ca=_q(ca - loss),
        currency=inp.currency,
        warnings=warnings,
    )


def to_dict(r: ImpairmentResult) -> dict:
    return {
        "asset_name": r.asset_name,
        "asset_class": r.asset_class,
        "carrying_amount": f"{r.carrying_amount}",
        "fair_value_less_costs": f"{r.fair_value_less_costs}",
        "value_in_use": f"{r.value_in_use}",
        "recoverable_amount": f"{r.recoverable_amount}",
        "impairment_loss": f"{r.impairment_loss}",
        "recoverable_method": r.recoverable_method,
        "is_impaired": r.is_impaired,
        "post_impairment_ca": f"{r.post_impairment_ca}",
        "currency": r.currency,
        "warnings": r.warnings,
    }
