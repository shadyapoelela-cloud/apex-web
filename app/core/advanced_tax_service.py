"""
APEX Platform — Advanced Tax Calculators
═══════════════════════════════════════════════════════════════
• RETT — Real Estate Transaction Tax (KSA 5%)
• BEPS 2.0 Pillar Two — Global Minimum Tax 15%
• VAT Group — consolidated VAT registration calculator
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
# RETT — Real Estate Transaction Tax (KSA)
# ═══════════════════════════════════════════════════════════════


PROPERTY_TYPES = {"residential", "commercial", "industrial", "agricultural", "land"}
TRANSACTION_MODES = {"sale", "lease_finance", "donation", "inheritance"}


@dataclass
class RettInput:
    property_type: str
    transaction_mode: str
    sale_value: Decimal
    sale_date: str
    is_first_home: bool = False               # 1M SAR exemption for citizens
    is_family_transfer: bool = False          # exempt
    is_sharia_compliant_finance: bool = False
    buyer_is_saudi_citizen: bool = False
    currency: str = "SAR"


@dataclass
class RettResult:
    property_type: str
    sale_value: Decimal
    rett_rate_pct: Decimal                     # effective rate applied
    taxable_value: Decimal                     # after exemptions
    rett_amount: Decimal
    exemption_applied: str                     # 'first_home' / 'family' / etc
    vat_applicable: bool                        # commercial: 15% VAT
    vat_amount: Decimal
    net_seller_proceeds: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def compute_rett(inp: RettInput) -> RettResult:
    if inp.property_type not in PROPERTY_TYPES:
        raise ValueError(f"property_type must be one of {sorted(PROPERTY_TYPES)}")
    if inp.transaction_mode not in TRANSACTION_MODES:
        raise ValueError(f"transaction_mode must be one of {sorted(TRANSACTION_MODES)}")
    if Decimal(str(inp.sale_value)) < 0:
        raise ValueError("sale_value cannot be negative")

    warnings: list[str] = []
    value = Decimal(str(inp.sale_value))
    exemption = "none"

    # Determine rate: RETT rate is 5% (KSA default)
    rate = Decimal("5")

    # Exemptions
    if inp.is_family_transfer:
        rate = Decimal("0")
        exemption = "family_transfer"
        warnings.append("تحويل بين أقارب — معفى من الضريبة العقارية.")
    elif inp.transaction_mode == "inheritance":
        rate = Decimal("0")
        exemption = "inheritance"
        warnings.append("نقل عن طريق الإرث — معفى.")
    elif inp.is_first_home and inp.buyer_is_saudi_citizen \
            and inp.property_type == "residential":
        # First home up to 1M SAR exempt
        if value <= Decimal("1000000"):
            rate = Decimal("0")
            exemption = "first_home_full"
            warnings.append("منزل العمر الأول ≤ 1M ريال — إعفاء كامل.")
        else:
            # Only first 1M exempt
            exemption = "first_home_partial"
            warnings.append("منزل العمر الأول — إعفاء أول مليون فقط.")

    # Taxable value
    if exemption == "first_home_partial":
        taxable = value - Decimal("1000000")
    elif rate == 0:
        taxable = Decimal("0")
    else:
        taxable = value

    rett_amt = taxable * rate / Decimal("100")

    # VAT: commercial properties subject to 15% VAT (not residential)
    vat_applicable = inp.property_type in ("commercial", "industrial") \
        and inp.transaction_mode == "sale"
    vat_amt = value * Decimal("15") / Decimal("100") if vat_applicable else Decimal("0")
    if vat_applicable:
        warnings.append("عقار تجاري/صناعي — يُطبّق VAT 15%.")

    # Net proceeds for seller (RETT usually paid by buyer in KSA)
    net_seller = value

    if rett_amt > Decimal("500000"):
        warnings.append("ضريبة كبيرة — يجب التقديم خلال 30 يوماً من التوثيق.")

    return RettResult(
        property_type=inp.property_type,
        sale_value=_q(value),
        rett_rate_pct=rate,
        taxable_value=_q(taxable),
        rett_amount=_q(rett_amt),
        exemption_applied=exemption,
        vat_applicable=vat_applicable,
        vat_amount=_q(vat_amt),
        net_seller_proceeds=_q(net_seller),
        currency=inp.currency,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Pillar Two — Global Minimum Tax (15%)
# ═══════════════════════════════════════════════════════════════


@dataclass
class PillarTwoJurisdiction:
    jurisdiction: str                         # country code
    gloBE_income: Decimal                     # adjusted accounting profit
    covered_taxes: Decimal                    # current + deferred corp tax
    payroll: Decimal                          # for Substance-Based Income Exclusion
    tangible_assets: Decimal                  # for SBIE


@dataclass
class PillarTwoInput:
    group_name: str
    fiscal_year: str
    group_consolidated_revenue: Decimal        # must be ≥ 750M EUR
    jurisdictions: List[PillarTwoJurisdiction] = field(default_factory=list)


@dataclass
class JurisdictionResult:
    jurisdiction: str
    gloBE_income: Decimal
    covered_taxes: Decimal
    effective_tax_rate_pct: Decimal
    sbie: Decimal                              # payroll 5% + tangible 5%
    gloBE_income_after_sbie: Decimal
    top_up_rate_pct: Decimal                   # max(0, 15 - ETR)
    top_up_tax: Decimal
    status: str                                # 'above_minimum' | 'top_up_required'


@dataclass
class PillarTwoResult:
    group_name: str
    fiscal_year: str
    threshold_met: bool                        # revenue ≥ 750M EUR
    jurisdictions: List[JurisdictionResult]
    total_top_up_tax: Decimal
    warnings: list[str] = field(default_factory=list)


def compute_pillar_two(inp: PillarTwoInput) -> PillarTwoResult:
    warnings: list[str] = []
    # Threshold: 750M EUR ≈ 3.2B SAR
    threshold = Decimal("3200000000")
    threshold_met = Decimal(str(inp.group_consolidated_revenue)) >= threshold

    if not threshold_met:
        warnings.append(
            "إيرادات المجموعة تحت حد 750M EUR — Pillar Two غير مُلزِم."
        )

    results: List[JurisdictionResult] = []
    total_top_up = Decimal("0")
    min_rate = Decimal("15")

    for j in inp.jurisdictions:
        income = Decimal(str(j.gloBE_income))
        taxes = Decimal(str(j.covered_taxes))

        etr = Decimal("0") if income <= 0 else (taxes / income * Decimal("100"))

        # Substance-Based Income Exclusion: 5% payroll + 5% tangible
        sbie = (Decimal(str(j.payroll)) * Decimal("5") / Decimal("100")) + \
               (Decimal(str(j.tangible_assets)) * Decimal("5") / Decimal("100"))

        excess_income = max(Decimal("0"), income - sbie)
        top_up_rate = max(Decimal("0"), min_rate - etr)
        top_up = excess_income * top_up_rate / Decimal("100") if threshold_met else Decimal("0")

        status = "above_minimum" if etr >= min_rate else "top_up_required"
        results.append(JurisdictionResult(
            jurisdiction=j.jurisdiction,
            gloBE_income=_q(income),
            covered_taxes=_q(taxes),
            effective_tax_rate_pct=_q(etr),
            sbie=_q(sbie),
            gloBE_income_after_sbie=_q(excess_income),
            top_up_rate_pct=_q(top_up_rate),
            top_up_tax=_q(top_up),
            status=status,
        ))
        total_top_up += top_up

    if total_top_up > 0:
        warnings.append(
            f"ضريبة تكميلية مستحقة: {_q(total_top_up)} — يجب تسجيل GIR خلال 15 شهراً من نهاية السنة."
        )

    return PillarTwoResult(
        group_name=inp.group_name,
        fiscal_year=inp.fiscal_year,
        threshold_met=threshold_met,
        jurisdictions=results,
        total_top_up_tax=_q(total_top_up),
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# VAT Group registration
# ═══════════════════════════════════════════════════════════════


@dataclass
class VatGroupMember:
    entity_name: str
    vat_registration: str
    annual_taxable_supplies: Decimal
    vat_collected: Decimal
    vat_paid: Decimal
    intra_group_supplies: Decimal = Decimal("0")   # eliminated


@dataclass
class VatGroupInput:
    group_name: str
    fiscal_period: str
    representative_member: str
    members: List[VatGroupMember] = field(default_factory=list)


@dataclass
class VatGroupResult:
    group_name: str
    fiscal_period: str
    total_taxable_supplies: Decimal
    total_vat_collected: Decimal
    total_vat_paid: Decimal
    intra_group_eliminated: Decimal
    net_vat_payable: Decimal                   # collected - paid
    is_above_threshold: bool                   # >375k SAR required registration
    members_count: int
    warnings: list[str] = field(default_factory=list)


def compute_vat_group(inp: VatGroupInput) -> VatGroupResult:
    if not inp.members:
        raise ValueError("members is required (at least one)")

    warnings: list[str] = []
    total_supplies = Decimal("0")
    total_collected = Decimal("0")
    total_paid = Decimal("0")
    total_intra = Decimal("0")

    for m in inp.members:
        total_supplies += Decimal(str(m.annual_taxable_supplies))
        total_collected += Decimal(str(m.vat_collected))
        total_paid += Decimal(str(m.vat_paid))
        total_intra += Decimal(str(m.intra_group_supplies))

    net = total_collected - total_paid
    above = total_supplies >= Decimal("375000")

    if above:
        warnings.append(
            f"إجمالي التوريدات {_q(total_supplies)} فوق 375k — "
            "التسجيل الإلزامي في VAT."
        )
    if total_intra > 0:
        warnings.append(
            f"معاملات داخلية مُلغاة: {_q(total_intra)} (لا VAT على المعاملات بين أفراد المجموعة)."
        )

    if net > Decimal("1000000"):
        warnings.append("صافي VAT كبير — راجع دقة احتساب المدخلات.")

    return VatGroupResult(
        group_name=inp.group_name,
        fiscal_period=inp.fiscal_period,
        total_taxable_supplies=_q(total_supplies),
        total_vat_collected=_q(total_collected),
        total_vat_paid=_q(total_paid),
        intra_group_eliminated=_q(total_intra),
        net_vat_payable=_q(net),
        is_above_threshold=above,
        members_count=len(inp.members),
        warnings=warnings,
    )


# Serialisers
def rett_to_dict(r: RettResult) -> dict:
    return {
        "property_type": r.property_type,
        "sale_value": f"{r.sale_value}",
        "rett_rate_pct": f"{r.rett_rate_pct}",
        "taxable_value": f"{r.taxable_value}",
        "rett_amount": f"{r.rett_amount}",
        "exemption_applied": r.exemption_applied,
        "vat_applicable": r.vat_applicable,
        "vat_amount": f"{r.vat_amount}",
        "net_seller_proceeds": f"{r.net_seller_proceeds}",
        "currency": r.currency,
        "warnings": r.warnings,
    }


def p2_to_dict(r: PillarTwoResult) -> dict:
    return {
        "group_name": r.group_name,
        "fiscal_year": r.fiscal_year,
        "threshold_met": r.threshold_met,
        "jurisdictions": [
            {
                "jurisdiction": j.jurisdiction,
                "gloBE_income": f"{j.gloBE_income}",
                "covered_taxes": f"{j.covered_taxes}",
                "effective_tax_rate_pct": f"{j.effective_tax_rate_pct}",
                "sbie": f"{j.sbie}",
                "gloBE_income_after_sbie": f"{j.gloBE_income_after_sbie}",
                "top_up_rate_pct": f"{j.top_up_rate_pct}",
                "top_up_tax": f"{j.top_up_tax}",
                "status": j.status,
            }
            for j in r.jurisdictions
        ],
        "total_top_up_tax": f"{r.total_top_up_tax}",
        "warnings": r.warnings,
    }


def vg_to_dict(r: VatGroupResult) -> dict:
    return {
        "group_name": r.group_name,
        "fiscal_period": r.fiscal_period,
        "total_taxable_supplies": f"{r.total_taxable_supplies}",
        "total_vat_collected": f"{r.total_vat_collected}",
        "total_vat_paid": f"{r.total_vat_paid}",
        "intra_group_eliminated": f"{r.intra_group_eliminated}",
        "net_vat_payable": f"{r.net_vat_payable}",
        "is_above_threshold": r.is_above_threshold,
        "members_count": r.members_count,
        "warnings": r.warnings,
    }
