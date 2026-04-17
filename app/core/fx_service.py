"""
APEX Platform — Multi-Currency / FX Conversion
═══════════════════════════════════════════════════════════════
Currency conversion between SAR / AED / KWD / BHD / QAR / OMR /
EGP / USD / EUR using user-supplied rates (pinned at period-end
per IAS 21 requirements, or spot rate when translating transactions).

Supports:
  • Convert amount A from currency X to currency Y with explicit rate
  • Multi-hop via base (SAR): X → SAR → Y if direct rate not given
  • Rate-sheet batch: apply a rate table to a list of items
  • Re-measurement: revalue a prior-period balance with new rate,
    produce the FX gain/loss line

All math uses Decimal with 6dp precision for rates and 2dp for amounts.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")
_SIX = Decimal("0.000001")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


def _q6(v: Decimal) -> Decimal:
    return v.quantize(_SIX, rounding=ROUND_HALF_UP)


# Indicative default cross-rates against SAR — used when caller
# doesn't supply their own. Numbers are illustrative only; real
# book rates come from the central bank / Bloomberg / Refinitiv.
_DEFAULT_RATES_VS_SAR: dict[str, Decimal] = {
    "SAR": Decimal("1.000000"),
    "USD": Decimal("3.750000"),
    "EUR": Decimal("4.050000"),
    "AED": Decimal("1.020000"),
    "KWD": Decimal("12.200000"),
    "BHD": Decimal("9.940000"),
    "QAR": Decimal("1.030000"),
    "OMR": Decimal("9.740000"),
    "EGP": Decimal("0.077000"),
    "GBP": Decimal("4.700000"),
}


SUPPORTED_CURRENCIES = sorted(_DEFAULT_RATES_VS_SAR.keys())


@dataclass
class FxConvertInput:
    amount: Decimal
    from_currency: str
    to_currency: str
    # Either a direct rate X→Y, OR we use rates_vs_base
    direct_rate: Optional[Decimal] = None
    # Rate table overrides (currency → units per base) if caller has it
    rates_vs_base: Optional[dict[str, Decimal]] = None
    base_currency: str = "SAR"


@dataclass
class FxConvertResult:
    amount_from: Decimal
    from_currency: str
    amount_to: Decimal
    to_currency: str
    rate_applied: Decimal              # from→to effective rate
    via_base: bool                      # True if we hopped through base
    base_currency: str
    warnings: list[str] = field(default_factory=list)


def _rates_vs_base(overrides: Optional[dict[str, Decimal]]) -> dict[str, Decimal]:
    if overrides is None:
        return dict(_DEFAULT_RATES_VS_SAR)
    return {k.upper(): Decimal(str(v)) for k, v in overrides.items()}


def convert_fx(inp: FxConvertInput) -> FxConvertResult:
    warnings: list[str] = []

    amount = _q(inp.amount)
    frm = (inp.from_currency or "").upper()
    to = (inp.to_currency or "").upper()
    base = (inp.base_currency or "SAR").upper()

    if not frm or not to:
        raise ValueError("from_currency and to_currency are required")
    if amount < 0:
        raise ValueError("amount cannot be negative — use a positive value")

    # Trivial case
    if frm == to:
        return FxConvertResult(
            amount_from=amount, from_currency=frm,
            amount_to=amount, to_currency=to,
            rate_applied=Decimal("1.000000"),
            via_base=False, base_currency=base,
            warnings=["نفس العملة — لم يتم تطبيق أي تحويل."],
        )

    # Direct rate provided
    if inp.direct_rate is not None:
        rate = Decimal(str(inp.direct_rate))
        if rate <= 0:
            raise ValueError("direct_rate must be positive")
        converted = _q(amount * rate)
        return FxConvertResult(
            amount_from=amount, from_currency=frm,
            amount_to=converted, to_currency=to,
            rate_applied=_q6(rate),
            via_base=False, base_currency=base,
            warnings=warnings,
        )

    # Cross-rate via base
    rates = _rates_vs_base(inp.rates_vs_base)
    if frm not in rates:
        raise ValueError(f"No rate available for {frm} (provide direct_rate or rates_vs_base)")
    if to not in rates:
        raise ValueError(f"No rate available for {to} (provide direct_rate or rates_vs_base)")

    # rates[X] = units of base (SAR) per 1 unit of X
    # So 1 X = rates[X] base
    # 1 base = 1/rates[to] to_currency
    # amount X × (rates[X] / rates[Y]) = amount in Y
    rate_from_to = rates[frm] / rates[to]
    converted = _q(amount * rate_from_to)

    return FxConvertResult(
        amount_from=amount, from_currency=frm,
        amount_to=converted, to_currency=to,
        rate_applied=_q6(rate_from_to),
        via_base=True, base_currency=base,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Batch conversion
# ═══════════════════════════════════════════════════════════════


@dataclass
class FxBatchItem:
    label: str
    amount: Decimal
    from_currency: str


@dataclass
class FxBatchInput:
    target_currency: str = "SAR"
    rates_vs_base: Optional[dict[str, Decimal]] = None
    base_currency: str = "SAR"
    items: List[FxBatchItem] = field(default_factory=list)


@dataclass
class FxBatchConverted:
    label: str
    original_amount: Decimal
    original_currency: str
    converted_amount: Decimal
    rate_applied: Decimal


@dataclass
class FxBatchResult:
    target_currency: str
    base_currency: str
    items: List[FxBatchConverted]
    total_converted: Decimal
    warnings: list[str] = field(default_factory=list)


def convert_fx_batch(inp: FxBatchInput) -> FxBatchResult:
    warnings: list[str] = []
    if not inp.items:
        raise ValueError("items is required (at least one)")
    target = (inp.target_currency or "SAR").upper()
    base = (inp.base_currency or "SAR").upper()

    converted_items: List[FxBatchConverted] = []
    total = Decimal("0")
    for i, it in enumerate(inp.items, start=1):
        if not it.label:
            raise ValueError(f"item {i}: label is required")
        try:
            sub = convert_fx(FxConvertInput(
                amount=it.amount,
                from_currency=it.from_currency,
                to_currency=target,
                rates_vs_base=inp.rates_vs_base,
                base_currency=base,
            ))
        except ValueError as e:
            raise ValueError(f"item {i} ({it.label!r}): {e}")
        converted_items.append(FxBatchConverted(
            label=it.label,
            original_amount=_q(it.amount),
            original_currency=(it.from_currency or "").upper(),
            converted_amount=sub.amount_to,
            rate_applied=sub.rate_applied,
        ))
        total += sub.amount_to

    return FxBatchResult(
        target_currency=target, base_currency=base,
        items=converted_items, total_converted=_q(total),
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# FX revaluation (IAS 21 period-end re-measurement)
# ═══════════════════════════════════════════════════════════════


@dataclass
class FxRevalInput:
    amount_foreign: Decimal                # original foreign-currency balance
    foreign_currency: str
    reporting_currency: str = "SAR"
    historical_rate: Decimal = Decimal("0")     # at initial booking
    current_rate: Decimal = Decimal("0")        # period-end spot


@dataclass
class FxRevalResult:
    amount_foreign: Decimal
    foreign_currency: str
    reporting_currency: str
    historical_value: Decimal              # amount × historical_rate
    current_value: Decimal                 # amount × current_rate
    unrealised_gain_loss: Decimal          # current − historical
    gain_or_loss: str                      # 'gain' | 'loss' | 'none'
    warnings: list[str] = field(default_factory=list)


def revalue_fx(inp: FxRevalInput) -> FxRevalResult:
    warnings: list[str] = []
    amount = _q(inp.amount_foreign)
    if amount < 0:
        raise ValueError("amount_foreign must be non-negative")
    if inp.historical_rate <= 0 or inp.current_rate <= 0:
        raise ValueError("both rates must be positive")

    h = amount * Decimal(str(inp.historical_rate))
    c = amount * Decimal(str(inp.current_rate))
    diff = _q(c - h)

    if diff > 0:
        label = "gain"
    elif diff < 0:
        label = "loss"
    else:
        label = "none"

    if label == "loss":
        warnings.append(
            "خسارة صرف غير محققة — تُسجَّل في قائمة الدخل حسب IAS 21."
        )

    return FxRevalResult(
        amount_foreign=amount,
        foreign_currency=(inp.foreign_currency or "").upper(),
        reporting_currency=(inp.reporting_currency or "SAR").upper(),
        historical_value=_q(h),
        current_value=_q(c),
        unrealised_gain_loss=diff,
        gain_or_loss=label,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Dict serialisation
# ═══════════════════════════════════════════════════════════════


def convert_to_dict(r: FxConvertResult) -> dict:
    return {
        "amount_from": f"{r.amount_from}",
        "from_currency": r.from_currency,
        "amount_to": f"{r.amount_to}",
        "to_currency": r.to_currency,
        "rate_applied": f"{r.rate_applied}",
        "via_base": r.via_base,
        "base_currency": r.base_currency,
        "warnings": r.warnings,
    }


def batch_to_dict(r: FxBatchResult) -> dict:
    return {
        "target_currency": r.target_currency,
        "base_currency": r.base_currency,
        "items": [
            {
                "label": it.label,
                "original_amount": f"{it.original_amount}",
                "original_currency": it.original_currency,
                "converted_amount": f"{it.converted_amount}",
                "rate_applied": f"{it.rate_applied}",
            }
            for it in r.items
        ],
        "total_converted": f"{r.total_converted}",
        "warnings": r.warnings,
    }


def reval_to_dict(r: FxRevalResult) -> dict:
    return {
        "amount_foreign": f"{r.amount_foreign}",
        "foreign_currency": r.foreign_currency,
        "reporting_currency": r.reporting_currency,
        "historical_value": f"{r.historical_value}",
        "current_value": f"{r.current_value}",
        "unrealised_gain_loss": f"{r.unrealised_gain_loss}",
        "gain_or_loss": r.gain_or_loss,
        "warnings": r.warnings,
    }
