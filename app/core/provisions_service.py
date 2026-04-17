"""
APEX Platform — IAS 37 Provisions & Contingent Liabilities
═══════════════════════════════════════════════════════════════
Classification rules:
  • Provision: probable (>50%) outflow + reliable estimate
    → Recognise on balance sheet
  • Contingent liability: possible but not probable, OR probable
    but cannot estimate reliably → disclosure only
  • Contingent asset: probable inflow → disclosure if virtually certain → recognise

Measurement:
  • Best estimate (most likely or weighted probability)
  • Discounted if material (>1 year) using pre-tax rate
  • Expected value for large populations (warranty claims)
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


PROBABILITY_LEVELS = {"virtually_certain", "probable", "possible", "remote"}
ITEM_TYPES = {"liability", "asset"}


@dataclass
class ProvisionItem:
    description: str
    item_type: str                        # 'liability' or 'asset'
    probability: str                      # one of PROBABILITY_LEVELS
    best_estimate: Decimal                # SAR amount
    can_estimate_reliably: bool = True
    years_to_settlement: Decimal = Decimal("0")
    discount_rate_pct: Decimal = Decimal("5")


@dataclass
class ProvisionResult:
    description: str
    item_type: str
    probability: str
    best_estimate: Decimal
    discounted_estimate: Decimal          # PV if > 1 year
    classification: str                   # 'provision' | 'contingent_liability' |
                                          # 'contingent_asset' | 'disclosure_only' | 'ignore'
    recognise: bool                       # True if on BS
    disclose: bool                        # True if in notes
    rationale: str


def _classify(it: ProvisionItem) -> ProvisionResult:
    best = Decimal(str(it.best_estimate))
    yrs = Decimal(str(it.years_to_settlement))
    rate = Decimal(str(it.discount_rate_pct)) / Decimal("100")

    # Discounting
    if yrs > 1 and rate > 0:
        discounted = best / ((Decimal("1") + rate) ** int(yrs))
    else:
        discounted = best

    # Classification per IAS 37
    if it.item_type == "liability":
        if it.probability == "remote":
            cls = "ignore"
            recog, disc = False, False
            rat = "احتمالية ضئيلة — لا يُفصَح"
        elif it.probability == "probable" and it.can_estimate_reliably:
            cls = "provision"
            recog, disc = True, True
            rat = "التزام مرجّح + تقدير موثوق → يُعترف في الميزانية"
        elif it.probability == "probable" and not it.can_estimate_reliably:
            cls = "contingent_liability"
            recog, disc = False, True
            rat = "مرجّح لكن يتعذّر تقديره — إفصاح فقط"
        elif it.probability == "possible":
            cls = "contingent_liability"
            recog, disc = False, True
            rat = "محتمل (غير مرجّح) — إفصاح فقط في الإيضاحات"
        else:  # virtually_certain
            cls = "provision"
            recog, disc = True, True
            rat = "شبه مؤكد + تقدير موثوق → يُعترف كالتزام"
    else:  # asset
        if it.probability == "virtually_certain":
            cls = "asset"
            recog, disc = True, True
            rat = "دخول مؤكد عملياً → يُعترف كأصل"
        elif it.probability == "probable":
            cls = "contingent_asset"
            recog, disc = False, True
            rat = "دخول مرجّح — إفصاح فقط"
        else:
            cls = "ignore"
            recog, disc = False, False
            rat = "احتمالية منخفضة — لا يُفصَح"

    return ProvisionResult(
        description=it.description,
        item_type=it.item_type,
        probability=it.probability,
        best_estimate=_q(best),
        discounted_estimate=_q(discounted),
        classification=cls,
        recognise=recog,
        disclose=disc,
        rationale=rat,
    )


@dataclass
class ProvisionsInput:
    entity_name: str
    period_label: str
    currency: str = "SAR"
    items: List[ProvisionItem] = field(default_factory=list)


@dataclass
class ProvisionsResult:
    entity_name: str
    period_label: str
    items: List[ProvisionResult]
    total_provisions_liability: Decimal   # sum of recognised liabilities
    total_recognised_asset: Decimal
    total_contingent_disclosure: Decimal  # contingent L + A
    currency: str
    warnings: list[str] = field(default_factory=list)


def classify_provisions(inp: ProvisionsInput) -> ProvisionsResult:
    if not inp.items:
        raise ValueError("items is required")

    warnings: list[str] = []
    results: List[ProvisionResult] = []
    prov_total = Decimal("0")
    asset_total = Decimal("0")
    cont_total = Decimal("0")

    for i, it in enumerate(inp.items, start=1):
        if it.item_type not in ITEM_TYPES:
            raise ValueError(f"item {i}: item_type must be 'liability' or 'asset'")
        if it.probability not in PROBABILITY_LEVELS:
            raise ValueError(
                f"item {i}: probability must be one of {sorted(PROBABILITY_LEVELS)}"
            )
        if Decimal(str(it.best_estimate)) < 0:
            raise ValueError(f"item {i}: best_estimate cannot be negative")
        r = _classify(it)
        results.append(r)
        if r.recognise and r.item_type == "liability":
            prov_total += r.discounted_estimate
        elif r.recognise and r.item_type == "asset":
            asset_total += r.discounted_estimate
        elif r.disclose:
            cont_total += r.discounted_estimate

    if prov_total > 0:
        warnings.append(
            f"إجمالي المخصصات المعترف بها: {_q(prov_total)} — سيظهر في الميزانية."
        )
    if cont_total > 0:
        warnings.append(
            f"التزامات/أصول محتملة تحتاج إفصاحاً في الإيضاحات: {_q(cont_total)}."
        )

    return ProvisionsResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        items=results,
        total_provisions_liability=_q(prov_total),
        total_recognised_asset=_q(asset_total),
        total_contingent_disclosure=_q(cont_total),
        currency=inp.currency,
        warnings=warnings,
    )


def to_dict(r: ProvisionsResult) -> dict:
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "items": [
            {
                "description": it.description,
                "item_type": it.item_type,
                "probability": it.probability,
                "best_estimate": f"{it.best_estimate}",
                "discounted_estimate": f"{it.discounted_estimate}",
                "classification": it.classification,
                "recognise": it.recognise,
                "disclose": it.disclose,
                "rationale": it.rationale,
            }
            for it in r.items
        ],
        "total_provisions_liability": f"{r.total_provisions_liability}",
        "total_recognised_asset": f"{r.total_recognised_asset}",
        "total_contingent_disclosure": f"{r.total_contingent_disclosure}",
        "currency": r.currency,
        "warnings": r.warnings,
    }
