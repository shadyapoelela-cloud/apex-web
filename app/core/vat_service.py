"""
APEX Platform — VAT Return Calculator (KSA 15% / UAE 5%)
═══════════════════════════════════════════════════════════════
Produces a quarterly/monthly VAT return summary:

    Net VAT = Output VAT (on sales)  −  Input VAT (on purchases)

With breakdowns by rate category:
  • Standard-rated (15% KSA / 5% UAE)
  • Zero-rated (0%) — exports, international transport, medicine
  • Exempt — no VAT, no input credit
  • Out-of-scope — not reportable

A positive Net VAT means payable to ZATCA; negative = refund claim
(carried forward or refunded per ZATCA's 60-day processing).

References:
  • ZATCA VAT Implementing Regulations (Royal Decree M/113)
  • UAE FTA VAT Law
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")


def _q(value: Decimal | int | float | str | None) -> Decimal:
    if value is None:
        return Decimal("0")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


# ═══════════════════════════════════════════════════════════════
# Jurisdictions
# ═══════════════════════════════════════════════════════════════

# Standard VAT rates by jurisdiction (as of 2026).
_STANDARD_RATES: dict[str, Decimal] = {
    "SA": Decimal("0.15"),
    "AE": Decimal("0.05"),
    "BH": Decimal("0.10"),
    "OM": Decimal("0.05"),
    # EG, QA, KW: no VAT or different systems — caller must supply explicitly.
}


def standard_rate_for(jurisdiction: str) -> Decimal:
    r = _STANDARD_RATES.get((jurisdiction or "").upper())
    if r is None:
        raise ValueError(
            f"No default VAT rate for jurisdiction {jurisdiction!r}. "
            f"Supported: {sorted(_STANDARD_RATES)}. Pass rate explicitly."
        )
    return r


# ═══════════════════════════════════════════════════════════════
# Inputs
# ═══════════════════════════════════════════════════════════════


@dataclass
class VatSales:
    """Output side (VAT charged TO customers)."""
    # Amounts are NET (excl VAT). VAT is computed as net * rate.
    standard_rated_net: Decimal = Decimal("0")
    zero_rated_net: Decimal = Decimal("0")           # exports, int'l transport, etc.
    exempt_net: Decimal = Decimal("0")               # healthcare, education (KSA)
    out_of_scope_net: Decimal = Decimal("0")         # informational only


@dataclass
class VatPurchases:
    """Input side (VAT paid to suppliers — potentially reclaimable)."""
    standard_rated_net: Decimal = Decimal("0")
    zero_rated_net: Decimal = Decimal("0")
    exempt_net: Decimal = Decimal("0")
    non_reclaimable_vat: Decimal = Decimal("0")      # e.g. entertainment,
                                                     # personal use — VAT paid
                                                     # but NOT deductible.


@dataclass
class VatReturnInput:
    jurisdiction: str = "SA"                          # ISO country code
    period_label: str = "Q1"                          # "2026-Q1", "2026-01", ...
    sales: VatSales = field(default_factory=VatSales)
    purchases: VatPurchases = field(default_factory=VatPurchases)
    # If None, we look up the standard rate for the jurisdiction.
    standard_rate_override: Optional[Decimal] = None
    # Prior period credit carried forward (positive reduces amount payable).
    prior_period_credit: Decimal = Decimal("0")


# ═══════════════════════════════════════════════════════════════
# Result
# ═══════════════════════════════════════════════════════════════


@dataclass
class VatBucket:
    label_ar: str
    label_en: str
    net: Decimal
    rate_pct: Decimal          # 15.00 / 5.00 / 0.00
    vat: Decimal


@dataclass
class VatReturnResult:
    jurisdiction: str
    period_label: str
    standard_rate_pct: Decimal
    # Output (sales)
    sales_buckets: list[VatBucket]
    output_vat_total: Decimal
    sales_net_total: Decimal
    # Input (purchases)
    purchase_buckets: list[VatBucket]
    input_vat_reclaimable: Decimal
    purchases_net_total: Decimal
    # Non-reclaimable (for disclosure only — NOT netted)
    non_reclaimable_vat: Decimal
    # Settlement
    prior_period_credit: Decimal
    net_vat_due: Decimal            # > 0 payable / < 0 refund/carry-forward
    status: str                     # "payable" | "refund" | "nil"
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Core calculation
# ═══════════════════════════════════════════════════════════════


def compute_vat_return(inp: VatReturnInput) -> VatReturnResult:
    """Compute a VAT return. Pure function — deterministic, testable."""
    warnings: list[str] = []

    std_rate = inp.standard_rate_override
    if std_rate is None:
        std_rate = standard_rate_for(inp.jurisdiction)
    if std_rate <= 0 or std_rate >= 1:
        raise ValueError(
            f"Invalid VAT rate {std_rate}. Must be 0 < rate < 1 (e.g. Decimal('0.15'))."
        )
    std_rate_pct = (std_rate * 100).quantize(_TWO, rounding=ROUND_HALF_UP)

    # ── Sales ────────────────────────────────────────────────────
    s = inp.sales
    s_std_net = _q(s.standard_rated_net)
    s_zero_net = _q(s.zero_rated_net)
    s_exempt_net = _q(s.exempt_net)
    s_oos_net = _q(s.out_of_scope_net)

    s_std_vat = _q(s_std_net * std_rate)
    sales_buckets = [
        VatBucket("مبيعات بالسعر الأساسي", "Standard-rated sales", s_std_net, std_rate_pct, s_std_vat),
        VatBucket("مبيعات بسعر صفر", "Zero-rated sales", s_zero_net, Decimal("0.00"), Decimal("0.00")),
        VatBucket("مبيعات معفاة", "Exempt sales", s_exempt_net, Decimal("0.00"), Decimal("0.00")),
        VatBucket("مبيعات خارج النطاق", "Out-of-scope sales", s_oos_net, Decimal("0.00"), Decimal("0.00")),
    ]
    output_vat_total = s_std_vat
    sales_net_total = _q(s_std_net + s_zero_net + s_exempt_net + s_oos_net)

    # ── Purchases ────────────────────────────────────────────────
    p = inp.purchases
    p_std_net = _q(p.standard_rated_net)
    p_zero_net = _q(p.zero_rated_net)
    p_exempt_net = _q(p.exempt_net)
    non_reclaim = _q(p.non_reclaimable_vat)

    p_std_vat = _q(p_std_net * std_rate)
    purchase_buckets = [
        VatBucket("مشتريات بالسعر الأساسي", "Standard-rated purchases", p_std_net, std_rate_pct, p_std_vat),
        VatBucket("مشتريات بسعر صفر", "Zero-rated purchases", p_zero_net, Decimal("0.00"), Decimal("0.00")),
        VatBucket("مشتريات معفاة", "Exempt purchases", p_exempt_net, Decimal("0.00"), Decimal("0.00")),
    ]
    input_vat_reclaimable = p_std_vat
    purchases_net_total = _q(p_std_net + p_zero_net + p_exempt_net)

    # ── Settlement ──────────────────────────────────────────────
    prior_credit = _q(inp.prior_period_credit)
    if prior_credit < 0:
        warnings.append("رصيد الفترة السابقة سالب — تم التعامل معه كصفر.")
        prior_credit = Decimal("0")

    net_vat = _q(output_vat_total - input_vat_reclaimable - prior_credit)

    if net_vat > 0:
        status = "payable"
    elif net_vat < 0:
        status = "refund"
    else:
        status = "nil"

    # Sanity warnings
    if input_vat_reclaimable > output_vat_total * Decimal("5"):
        warnings.append(
            "ضريبة المدخلات أعلى بكثير من المخرجات — راجع فئات المشتريات قبل التقديم."
        )
    if non_reclaim > 0 and p_std_net == 0:
        warnings.append(
            "توجد ضريبة غير قابلة للاسترداد لكن لا توجد مشتريات بالسعر الأساسي — "
            "تأكد من التصنيف."
        )

    return VatReturnResult(
        jurisdiction=inp.jurisdiction.upper(),
        period_label=inp.period_label,
        standard_rate_pct=std_rate_pct,
        sales_buckets=sales_buckets,
        output_vat_total=output_vat_total,
        sales_net_total=sales_net_total,
        purchase_buckets=purchase_buckets,
        input_vat_reclaimable=input_vat_reclaimable,
        purchases_net_total=purchases_net_total,
        non_reclaimable_vat=non_reclaim,
        prior_period_credit=prior_credit,
        net_vat_due=net_vat,
        status=status,
        warnings=warnings,
    )


def result_to_dict(r: VatReturnResult) -> dict:
    """JSON-ready view of a VatReturnResult (Decimals as strings)."""
    def bucket(b: VatBucket) -> dict:
        return {
            "label_ar": b.label_ar,
            "label_en": b.label_en,
            "net": f"{b.net}",
            "rate_pct": f"{b.rate_pct}",
            "vat": f"{b.vat}",
        }
    return {
        "jurisdiction": r.jurisdiction,
        "period_label": r.period_label,
        "standard_rate_pct": f"{r.standard_rate_pct}",
        "sales": {
            "buckets": [bucket(b) for b in r.sales_buckets],
            "output_vat_total": f"{r.output_vat_total}",
            "net_total": f"{r.sales_net_total}",
        },
        "purchases": {
            "buckets": [bucket(b) for b in r.purchase_buckets],
            "input_vat_reclaimable": f"{r.input_vat_reclaimable}",
            "net_total": f"{r.purchases_net_total}",
        },
        "non_reclaimable_vat": f"{r.non_reclaimable_vat}",
        "prior_period_credit": f"{r.prior_period_credit}",
        "net_vat_due": f"{r.net_vat_due}",
        "status": r.status,
        "warnings": r.warnings,
    }
