"""
APEX Platform — Transfer Pricing (KSA + BEPS Action 13)
═══════════════════════════════════════════════════════════════
Tests whether related-party transactions comply with the
arm's length principle (OECD Guidelines + KSA TP Bylaws):

  • CUP (Comparable Uncontrolled Price)
  • Resale Price
  • Cost Plus
  • TNMM (Transactional Net Margin)
  • Profit Split

Plus documentation requirements:
  • Master File (group-level)
  • Local File (KSA entity-level)
  • CbCR (Country-by-Country Reporting) — threshold 3.2B SAR

Local thresholds (KSA ZATCA):
  • TP Disclosure Form required if related-party txn > 6M SAR
  • Local File required if ≥ 100M SAR
  • CbCR required if group revenue ≥ 3.2B SAR (~750M EUR)
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


TP_METHODS = {
    "CUP", "resale_price", "cost_plus", "TNMM", "profit_split",
}
TRANSACTION_TYPES = {
    "goods", "services", "royalties", "interest", "cost_sharing",
}


@dataclass
class TPTransaction:
    description: str
    transaction_type: str                 # one of TRANSACTION_TYPES
    related_party_name: str
    related_party_jurisdiction: str       # 'KSA' | 'UAE' | 'KWT' | ...
    method: str                           # one of TP_METHODS
    controlled_price: Decimal             # what the RP charges/pays us
    # Arm's-length benchmark range
    arm_length_lower: Decimal
    arm_length_upper: Decimal
    arm_length_median: Decimal
    currency: str = "SAR"


@dataclass
class TPInput:
    group_name: str
    local_entity_name: str
    fiscal_year: str
    group_consolidated_revenue: Decimal    # for CbCR trigger
    local_entity_revenue: Decimal
    transactions: List[TPTransaction] = field(default_factory=list)


@dataclass
class TPTransactionResult:
    description: str
    transaction_type: str
    related_party: str
    method: str
    controlled_price: Decimal
    arm_length_lower: Decimal
    arm_length_upper: Decimal
    within_range: bool
    adjustment_required: Decimal          # if outside range
    direction: str                        # 'upward' | 'downward' | 'none'
    materiality: str                      # 'low' | 'medium' | 'high'
    currency: str


@dataclass
class TPResult:
    group_name: str
    local_entity_name: str
    fiscal_year: str
    transactions: List[TPTransactionResult]
    total_controlled_volume: Decimal
    disclosure_form_required: bool       # > 6M SAR
    local_file_required: bool            # ≥ 100M SAR
    cbcr_required: bool                   # ≥ 3.2B SAR global
    master_file_required: bool           # same threshold
    total_adjustments: Decimal
    compliance_status: str               # 'compliant' | 'adjustments_needed'
    warnings: list[str] = field(default_factory=list)


def analyse_transfer_pricing(inp: TPInput) -> TPResult:
    if not inp.transactions:
        raise ValueError("transactions is required")

    warnings: list[str] = []
    results: List[TPTransactionResult] = []
    total_volume = Decimal("0")
    total_adj = Decimal("0")

    for i, t in enumerate(inp.transactions, start=1):
        if t.transaction_type not in TRANSACTION_TYPES:
            raise ValueError(
                f"txn {i}: transaction_type must be one of {sorted(TRANSACTION_TYPES)}"
            )
        if t.method not in TP_METHODS:
            raise ValueError(
                f"txn {i}: method must be one of {sorted(TP_METHODS)}"
            )

        cp = Decimal(str(t.controlled_price))
        lo = Decimal(str(t.arm_length_lower))
        hi = Decimal(str(t.arm_length_upper))
        if lo > hi:
            raise ValueError(f"txn {i}: arm_length_lower > arm_length_upper")

        within = lo <= cp <= hi
        adj = Decimal("0")
        direction = "none"
        if not within:
            if cp < lo:
                # Under-charging → adjustment to lift to lower bound
                adj = lo - cp
                direction = "upward"
            else:
                adj = cp - hi
                direction = "downward"
            total_adj += abs(adj)

        # Materiality based on absolute value
        if cp >= Decimal("10000000"):
            mat = "high"
        elif cp >= Decimal("1000000"):
            mat = "medium"
        else:
            mat = "low"

        results.append(TPTransactionResult(
            description=t.description,
            transaction_type=t.transaction_type,
            related_party=f"{t.related_party_name} ({t.related_party_jurisdiction})",
            method=t.method,
            controlled_price=_q(cp),
            arm_length_lower=_q(lo),
            arm_length_upper=_q(hi),
            within_range=within,
            adjustment_required=_q(adj),
            direction=direction,
            materiality=mat,
            currency=t.currency,
        ))
        total_volume += abs(cp)

    # KSA thresholds
    disclosure = total_volume > Decimal("6000000")
    local_file = total_volume >= Decimal("100000000")
    group_rev = Decimal(str(inp.group_consolidated_revenue))
    cbcr = group_rev >= Decimal("3200000000")
    master_file = cbcr

    if disclosure:
        warnings.append(
            "إجمالي المعاملات مع الأطراف ذات العلاقة > 6 مليون ريال — "
            "نموذج الإفصاح عن الأطراف ذات العلاقة مطلوب مع الإقرار الضريبي."
        )
    if local_file:
        warnings.append(
            "إجمالي المعاملات ≥ 100 مليون ريال — "
            "Local File مطلوب وفق لوائح ZATCA TP."
        )
    if cbcr:
        warnings.append(
            f"إيرادات المجموعة ({_q(group_rev)}) ≥ 3.2 مليار ريال — "
            "CbCR + Master File مطلوبان (BEPS Action 13)."
        )

    status = "compliant" if total_adj == 0 else "adjustments_needed"
    if total_adj > 0:
        warnings.append(
            f"إجمالي تعديلات مطلوبة: {_q(total_adj)} — راجع النطاقات السعرية."
        )

    return TPResult(
        group_name=inp.group_name,
        local_entity_name=inp.local_entity_name,
        fiscal_year=inp.fiscal_year,
        transactions=results,
        total_controlled_volume=_q(total_volume),
        disclosure_form_required=disclosure,
        local_file_required=local_file,
        cbcr_required=cbcr,
        master_file_required=master_file,
        total_adjustments=_q(total_adj),
        compliance_status=status,
        warnings=warnings,
    )


def to_dict(r: TPResult) -> dict:
    return {
        "group_name": r.group_name,
        "local_entity_name": r.local_entity_name,
        "fiscal_year": r.fiscal_year,
        "transactions": [
            {
                "description": t.description,
                "transaction_type": t.transaction_type,
                "related_party": t.related_party,
                "method": t.method,
                "controlled_price": f"{t.controlled_price}",
                "arm_length_lower": f"{t.arm_length_lower}",
                "arm_length_upper": f"{t.arm_length_upper}",
                "within_range": t.within_range,
                "adjustment_required": f"{t.adjustment_required}",
                "direction": t.direction,
                "materiality": t.materiality,
                "currency": t.currency,
            }
            for t in r.transactions
        ],
        "total_controlled_volume": f"{r.total_controlled_volume}",
        "disclosure_form_required": r.disclosure_form_required,
        "local_file_required": r.local_file_required,
        "cbcr_required": r.cbcr_required,
        "master_file_required": r.master_file_required,
        "total_adjustments": f"{r.total_adjustments}",
        "compliance_status": r.compliance_status,
        "warnings": r.warnings,
    }
