"""
APEX Platform — Debt Service Coverage & Debt Capacity
═══════════════════════════════════════════════════════════════
Bank-grade analysis used by lenders to assess loan viability:

  DSCR        = Net Operating Income / Total Debt Service
  EBITDA/DS   = EBITDA / Total Debt Service
  Leverage    = Total Debt / EBITDA
  Coverage    = EBITDA / Interest Expense (Interest Coverage)
  Max Loan    = (Available cash flow / DSCR_target) × annuity factor

Banks typically require DSCR ≥ 1.25 for SME lending in KSA
(1.20 minimum by SAMA guidelines, 1.25+ for confidence).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")
_FOUR = Decimal("0.0001")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


def _safe_div(num: Decimal, den: Decimal, dp: int = 4) -> Optional[Decimal]:
    if den == 0:
        return None
    q = Decimal("1").scaleb(-dp)
    return (num / den).quantize(q, rounding=ROUND_HALF_UP)


@dataclass
class DscrInput:
    period_label: str = "FY"
    # Income items
    ebitda: Decimal = Decimal("0")                     # or compute from parts
    net_operating_income: Optional[Decimal] = None      # NOI (for real estate)
    interest_expense: Decimal = Decimal("0")
    # Debt service (current period)
    current_principal_payments: Decimal = Decimal("0")  # principal due this period
    # Balance-sheet debt
    total_debt: Decimal = Decimal("0")
    # For max-loan sizing
    target_dscr: Decimal = Decimal("1.25")              # bank's required DSCR
    proposed_rate_pct: Decimal = Decimal("6")           # for new loan
    proposed_term_years: int = 5


@dataclass
class DscrResult:
    period_label: str
    total_debt_service: Decimal
    dscr: Optional[Decimal]
    dscr_benchmark: str                       # 'excellent' | 'good' | 'watch' | 'risk'
    dscr_decision: str                        # 'approve' | 'conditional' | 'decline'
    ebitda_coverage: Optional[Decimal]
    interest_coverage: Optional[Decimal]
    leverage_ratio: Optional[Decimal]         # debt / EBITDA
    # Debt capacity
    max_additional_annual_ds: Decimal
    max_loan_amount: Optional[Decimal]
    recommendations: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def _pmt_annuity_factor(rate: Decimal, n_years: int, periods_per_year: int = 12) -> Decimal:
    """Annuity factor — present value of 1 unit of annual payment at rate.
    Uses monthly compounding by default."""
    r = rate / Decimal(periods_per_year)
    n = n_years * periods_per_year
    if r == 0:
        return Decimal(n)
    # PV = PMT × (1 − (1+r)^−n) / r
    one_plus_r = Decimal("1") + r
    factor = (Decimal("1") - one_plus_r ** -n) / r
    # To size a LOAN from annual debt service, we convert annual → monthly DS
    # then apply PV factor. For simplicity: we use the annualised equivalent.
    # annual_pmt_per_loan_unit = loan × (r × (1+r)^n / ((1+r)^n − 1))
    # So loan_max = DS_available_annual / annual_pmt_factor
    # annual_pmt_factor = (r × (1+r)^n / ((1+r)^n − 1)) × periods_per_year
    # Instead, directly: max_loan = monthly_DS × PV_factor
    return factor


def compute_dscr(inp: DscrInput) -> DscrResult:
    warnings: list[str] = []
    recs: list[str] = []

    ebitda = _q(inp.ebitda)
    noi = _q(inp.net_operating_income) if inp.net_operating_income is not None else ebitda
    interest = _q(inp.interest_expense)
    principal = _q(inp.current_principal_payments)
    total_debt = _q(inp.total_debt)

    if inp.target_dscr <= 0:
        raise ValueError("target_dscr must be positive")
    if inp.proposed_rate_pct < 0:
        raise ValueError("proposed_rate_pct cannot be negative")
    if inp.proposed_term_years <= 0:
        raise ValueError("proposed_term_years must be positive")

    total_ds = _q(interest + principal)

    # DSCR = NOI / DS
    dscr = _safe_div(noi, total_ds, dp=4)
    ebitda_cov = _safe_div(ebitda, total_ds, dp=4) if total_ds > 0 else None
    int_cov = _safe_div(ebitda, interest, dp=4) if interest > 0 else None
    leverage = _safe_div(total_debt, ebitda, dp=4) if ebitda > 0 else None

    # Benchmark + decision
    benchmark = "risk"
    decision = "decline"
    if dscr is not None:
        if dscr >= Decimal("1.50"):
            benchmark, decision = "excellent", "approve"
        elif dscr >= Decimal("1.25"):
            benchmark, decision = "good", "approve"
        elif dscr >= Decimal("1.10"):
            benchmark, decision = "watch", "conditional"
        else:
            benchmark, decision = "risk", "decline"
    else:
        warnings.append("لا يمكن حساب DSCR — إجمالي خدمة الدين صفر.")

    # Debt capacity: how much more annual DS can the business absorb
    # while maintaining target DSCR?
    # Target DS = NOI / target_DSCR
    # Current DS = interest + principal
    # Available = max(0, Target_DS − Current_DS)
    max_additional_ds = Decimal("0")
    if inp.target_dscr > 0 and noi > 0:
        target_total_ds = noi / inp.target_dscr
        max_additional_ds = _q(max(Decimal("0"), target_total_ds - total_ds))

    # Size a loan whose annual DS = max_additional_ds at proposed rate/term
    max_loan: Optional[Decimal] = None
    if max_additional_ds > 0 and inp.proposed_rate_pct > 0:
        r_annual = inp.proposed_rate_pct / Decimal("100")
        # Annual equivalent annuity:
        # loan × [r/(1-(1+r)^-n)] = annual DS
        # loan = DS / [r/(1-(1+r)^-n)] = DS × (1-(1+r)^-n) / r
        one_plus_r = Decimal("1") + r_annual
        pv_factor = (Decimal("1") - one_plus_r ** -inp.proposed_term_years) / r_annual
        max_loan = _q(max_additional_ds * pv_factor)
    elif max_additional_ds > 0 and inp.proposed_rate_pct == 0:
        max_loan = _q(max_additional_ds * Decimal(inp.proposed_term_years))

    # Recommendations
    if dscr is not None:
        if dscr < Decimal("1.25"):
            recs.append(
                f"DSCR = {dscr} أقل من 1.25 (معيار البنوك السعودية). "
                f"قلّل التزامات الدين أو زد EBITDA."
            )
        elif dscr >= Decimal("2.0"):
            recs.append(
                f"DSCR = {dscr} عالٍ جداً — لديك قدرة استيعاب لتمويل إضافي "
                f"بشروط أفضل."
            )
    if leverage is not None and leverage > Decimal("4.0"):
        recs.append(
            f"الرفع المالي = {leverage}× (Debt/EBITDA). أغلب البنوك "
            f"تُفضّل ≤ 3.5×. خفّض الدين أو ارفع التدفق النقدي."
        )
    if int_cov is not None and int_cov < Decimal("3.0"):
        recs.append(
            f"تغطية الفائدة = {int_cov}×. عتبة الأمان 3× — خطر تعثر السداد."
        )
    if max_loan and max_loan > 0:
        recs.append(
            f"الحد الأقصى للقرض الإضافي بـ DSCR {inp.target_dscr}: "
            f"{max_loan:,.2f} SAR ({inp.proposed_term_years} سنوات @ "
            f"{inp.proposed_rate_pct}%)."
        )

    if ebitda <= 0:
        warnings.append("EBITDA صفر أو سالب — البنوك لا تمنح قروضاً في هذه الحالة.")

    return DscrResult(
        period_label=inp.period_label,
        total_debt_service=total_ds,
        dscr=dscr,
        dscr_benchmark=benchmark,
        dscr_decision=decision,
        ebitda_coverage=ebitda_cov,
        interest_coverage=int_cov,
        leverage_ratio=leverage,
        max_additional_annual_ds=max_additional_ds,
        max_loan_amount=max_loan,
        recommendations=recs,
        warnings=warnings,
    )


def result_to_dict(r: DscrResult) -> dict:
    def _s(v):
        return None if v is None else f"{v}"
    return {
        "period_label": r.period_label,
        "total_debt_service": f"{r.total_debt_service}",
        "dscr": _s(r.dscr),
        "dscr_benchmark": r.dscr_benchmark,
        "dscr_decision": r.dscr_decision,
        "ebitda_coverage": _s(r.ebitda_coverage),
        "interest_coverage": _s(r.interest_coverage),
        "leverage_ratio": _s(r.leverage_ratio),
        "max_additional_annual_ds": f"{r.max_additional_annual_ds}",
        "max_loan_amount": _s(r.max_loan_amount),
        "recommendations": r.recommendations,
        "warnings": r.warnings,
    }
