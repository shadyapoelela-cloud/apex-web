"""
APEX Platform — Withholding Tax (WHT) Calculator — Saudi Arabia
═══════════════════════════════════════════════════════════════
Computes KSA WHT per ZATCA / Income Tax Law:

Default rates for payments to non-residents:
  • Management fees                 20%
  • Royalties                        15%
  • International telecom            15%
  • Technical / consulting services   5%
  • Rent (movable)                    5%
  • Dividends                         5%
  • Interest / financing charges      5%
  • International insurance/reins.    5%
  • Air tickets / freight             5%
  • Other services                   15%

Features:
  • Gross-up (net payment → gross base including tax)
  • Direct deduction (gross → tax to withhold)
  • DTT override: caller can supply a treaty rate if lower
  • Batch: many payments through one rate table
  • Compliance: flags payments ≥ SAR 1M requiring reporting within 120d

All math uses Decimal, 2dp for amounts, 4dp for rates.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Dict, List, Optional


_TWO = Decimal("0.01")
_FOUR = Decimal("0.0001")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


def _q4(v: Decimal) -> Decimal:
    return v.quantize(_FOUR, rounding=ROUND_HALF_UP)


# KSA default WHT rates (percent)
_DEFAULT_RATES_KSA: Dict[str, Decimal] = {
    "management_fees":       Decimal("20"),
    "royalties":             Decimal("15"),
    "international_telecom": Decimal("15"),
    "technical_services":    Decimal("5"),
    "rent_movable":          Decimal("5"),
    "dividends":             Decimal("5"),
    "interest":              Decimal("5"),
    "insurance_reinsurance": Decimal("5"),
    "air_freight":           Decimal("5"),
    "other_services":        Decimal("15"),
}


PAYMENT_CATEGORIES = sorted(_DEFAULT_RATES_KSA.keys())


def default_rates() -> Dict[str, Decimal]:
    return dict(_DEFAULT_RATES_KSA)


# ═══════════════════════════════════════════════════════════════
# Single calculation
# ═══════════════════════════════════════════════════════════════


@dataclass
class WHTInput:
    payment_category: str
    amount: Decimal                          # either gross or net (see is_gross)
    is_gross: bool = True                    # True: amount already includes pre-tax base
    treaty_rate_pct: Optional[Decimal] = None  # DTT rate override (e.g. 5% instead of 15%)
    rate_override_pct: Optional[Decimal] = None  # explicit override
    currency: str = "SAR"
    vendor_name: str = ""
    reference: str = ""


@dataclass
class WHTResult:
    payment_category: str
    rate_applied_pct: Decimal
    base_gross: Decimal                       # pre-tax base
    tax_withheld: Decimal
    net_to_pay: Decimal                       # what the vendor receives
    currency: str
    vendor_name: str
    reference: str
    rate_source: str                          # 'default' | 'treaty' | 'override'
    warnings: list[str] = field(default_factory=list)


def compute_wht(inp: WHTInput,
                custom_rates: Optional[Dict[str, Decimal]] = None) -> WHTResult:
    warnings: list[str] = []

    if inp.payment_category not in _DEFAULT_RATES_KSA and inp.rate_override_pct is None:
        raise ValueError(
            f"Unknown payment_category {inp.payment_category!r}; "
            f"must be one of {PAYMENT_CATEGORIES} or supply rate_override_pct"
        )

    amount = Decimal(str(inp.amount))
    if amount < 0:
        raise ValueError("amount cannot be negative")

    # Resolve rate — precedence: override > treaty > default
    if inp.rate_override_pct is not None:
        rate = Decimal(str(inp.rate_override_pct))
        source = "override"
    elif inp.treaty_rate_pct is not None:
        rate = Decimal(str(inp.treaty_rate_pct))
        source = "treaty"
    elif custom_rates and inp.payment_category in custom_rates:
        rate = Decimal(str(custom_rates[inp.payment_category]))
        source = "custom"
    else:
        rate = _DEFAULT_RATES_KSA[inp.payment_category]
        source = "default"

    if rate < 0 or rate > 100:
        raise ValueError(f"rate must be between 0 and 100, got {rate}")

    if inp.is_gross:
        # amount is the pre-tax base
        base = amount
        tax = base * rate / Decimal("100")
        net = base - tax
    else:
        # amount is net (what vendor wants to receive); gross it up
        # net = base × (1 − rate/100) ⇒ base = net / (1 − rate/100)
        factor = Decimal("1") - (rate / Decimal("100"))
        if factor <= 0:
            raise ValueError(f"Gross-up impossible: rate {rate}% >= 100%")
        base = amount / factor
        tax = base - amount
        net = amount

    # Compliance flag
    if base >= Decimal("1000000"):
        warnings.append(
            "دفعة تتجاوز 1,000,000 ريال — يجب إبلاغ الزكاة خلال 120 يوماً "
            "من تاريخ الاستحقاق وفق المادة 68 من نظام ضريبة الدخل."
        )
    if rate == 0:
        warnings.append("معدل الضريبة صفر — تأكد من سريان اتفاقية تجنب الازدواج الضريبي.")

    return WHTResult(
        payment_category=inp.payment_category,
        rate_applied_pct=_q4(rate),
        base_gross=_q(base),
        tax_withheld=_q(tax),
        net_to_pay=_q(net),
        currency=inp.currency,
        vendor_name=inp.vendor_name,
        reference=inp.reference,
        rate_source=source,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Batch
# ═══════════════════════════════════════════════════════════════


@dataclass
class WHTBatchItem:
    payment_category: str
    amount: Decimal
    vendor_name: str = ""
    reference: str = ""
    is_gross: bool = True
    treaty_rate_pct: Optional[Decimal] = None
    rate_override_pct: Optional[Decimal] = None


@dataclass
class WHTBatchInput:
    currency: str = "SAR"
    period_label: str = ""
    custom_rates: Optional[Dict[str, Decimal]] = None
    items: List[WHTBatchItem] = field(default_factory=list)


@dataclass
class WHTBatchResult:
    currency: str
    period_label: str
    items: List[WHTResult]
    total_base: Decimal
    total_tax: Decimal
    total_net: Decimal
    by_category: Dict[str, Decimal]           # tax totals per category
    warnings: list[str] = field(default_factory=list)


def compute_wht_batch(inp: WHTBatchInput) -> WHTBatchResult:
    if not inp.items:
        raise ValueError("items is required (at least one)")

    results: List[WHTResult] = []
    tot_base = Decimal("0")
    tot_tax = Decimal("0")
    tot_net = Decimal("0")
    by_cat: Dict[str, Decimal] = {}
    warnings: list[str] = []

    for i, it in enumerate(inp.items, start=1):
        try:
            r = compute_wht(
                WHTInput(
                    payment_category=it.payment_category,
                    amount=Decimal(str(it.amount)),
                    is_gross=it.is_gross,
                    treaty_rate_pct=it.treaty_rate_pct,
                    rate_override_pct=it.rate_override_pct,
                    currency=inp.currency,
                    vendor_name=it.vendor_name,
                    reference=it.reference,
                ),
                custom_rates=inp.custom_rates,
            )
        except ValueError as e:
            raise ValueError(f"item {i}: {e}")
        results.append(r)
        tot_base += r.base_gross
        tot_tax += r.tax_withheld
        tot_net += r.net_to_pay
        by_cat[r.payment_category] = by_cat.get(r.payment_category, Decimal("0")) + r.tax_withheld
        warnings.extend(r.warnings)

    return WHTBatchResult(
        currency=inp.currency,
        period_label=inp.period_label,
        items=results,
        total_base=_q(tot_base),
        total_tax=_q(tot_tax),
        total_net=_q(tot_net),
        by_category={k: _q(v) for k, v in by_cat.items()},
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Dict serialisers
# ═══════════════════════════════════════════════════════════════


def wht_to_dict(r: WHTResult) -> dict:
    return {
        "payment_category": r.payment_category,
        "rate_applied_pct": f"{r.rate_applied_pct}",
        "base_gross": f"{r.base_gross}",
        "tax_withheld": f"{r.tax_withheld}",
        "net_to_pay": f"{r.net_to_pay}",
        "currency": r.currency,
        "vendor_name": r.vendor_name,
        "reference": r.reference,
        "rate_source": r.rate_source,
        "warnings": r.warnings,
    }


def batch_to_dict(r: WHTBatchResult) -> dict:
    return {
        "currency": r.currency,
        "period_label": r.period_label,
        "items": [wht_to_dict(it) for it in r.items],
        "total_base": f"{r.total_base}",
        "total_tax": f"{r.total_tax}",
        "total_net": f"{r.total_net}",
        "by_category": {k: f"{v}" for k, v in r.by_category.items()},
        "warnings": r.warnings,
    }
