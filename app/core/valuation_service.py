"""
APEX Platform — WACC + DCF Business Valuation
═══════════════════════════════════════════════════════════════
Two core valuation primitives:

  WACC (Weighted Average Cost of Capital):
    WACC = (E/V × Re) + (D/V × Rd × (1 − T))
    where:
      E = market value of equity
      D = market value of debt
      V = E + D
      Re = cost of equity (CAPM: Rf + β × ERP)
      Rd = cost of debt (interest rate)
      T  = tax rate

  DCF (Discounted Cash Flow):
    EV = Σ FCF_t / (1+WACC)^t  +  TV / (1+WACC)^n
    TV = FCF_n+1 / (WACC − g)    (Gordon growth)
    Equity value = EV − Net debt
    Per-share = Equity / shares outstanding

Produces the full intermediate table (PV per year, TV, EV, etc.)
so every number on the valuation is auditable.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


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


# ═══════════════════════════════════════════════════════════════
# WACC
# ═══════════════════════════════════════════════════════════════


@dataclass
class WaccInput:
    equity_value: Decimal = Decimal("0")        # market cap
    debt_value: Decimal = Decimal("0")
    # Cost of equity components (CAPM)
    risk_free_rate: Decimal = Decimal("0.04")    # Rf (decimal: 0.04 = 4%)
    beta: Decimal = Decimal("1.0")
    equity_risk_premium: Decimal = Decimal("0.06")
    cost_of_equity_override: Optional[Decimal] = None  # skip CAPM if given
    # Cost of debt
    cost_of_debt: Decimal = Decimal("0.06")      # gross interest rate
    tax_rate: Decimal = Decimal("0.20")          # corporate tax


@dataclass
class WaccResult:
    equity_value: Decimal
    debt_value: Decimal
    total_capital: Decimal
    weight_equity_pct: Decimal                  # e.g. 60.00
    weight_debt_pct: Decimal
    cost_of_equity_pct: Decimal                 # Re
    cost_of_debt_pretax_pct: Decimal
    cost_of_debt_after_tax_pct: Decimal
    tax_rate_pct: Decimal
    wacc_pct: Decimal                           # the answer
    warnings: list[str] = field(default_factory=list)


def compute_wacc(inp: WaccInput) -> WaccResult:
    warnings: list[str] = []

    E = _q(inp.equity_value)
    D = _q(inp.debt_value)
    V = _q(E + D)

    if E < 0 or D < 0:
        raise ValueError("equity_value and debt_value must be non-negative")
    if V == 0:
        raise ValueError("Total capital (equity + debt) must be positive")
    if inp.tax_rate < 0 or inp.tax_rate >= 1:
        raise ValueError("tax_rate must be in [0, 1)")

    # Cost of equity
    if inp.cost_of_equity_override is not None:
        Re = Decimal(str(inp.cost_of_equity_override))
    else:
        Re = inp.risk_free_rate + inp.beta * inp.equity_risk_premium

    Rd = Decimal(str(inp.cost_of_debt))
    T = Decimal(str(inp.tax_rate))

    we = E / V
    wd = D / V
    Rd_after_tax = Rd * (Decimal("1") - T)
    wacc = we * Re + wd * Rd_after_tax

    # Warnings
    if Re < inp.risk_free_rate:
        warnings.append("تكلفة حقوق الملكية أقل من المعدل الخالي من المخاطر — تحقق من المدخلات.")
    if Rd > Decimal("0.50"):
        warnings.append(f"تكلفة الدين {Rd*100:.1f}% مرتفعة جداً — هل أدخلت نسبة صحيحة؟")

    return WaccResult(
        equity_value=E,
        debt_value=D,
        total_capital=V,
        weight_equity_pct=_q(we * Decimal("100")),
        weight_debt_pct=_q(wd * Decimal("100")),
        cost_of_equity_pct=_q(Re * Decimal("100")),
        cost_of_debt_pretax_pct=_q(Rd * Decimal("100")),
        cost_of_debt_after_tax_pct=_q(Rd_after_tax * Decimal("100")),
        tax_rate_pct=_q(T * Decimal("100")),
        wacc_pct=_q(wacc * Decimal("100")),
        warnings=warnings,
    )


def wacc_result_to_dict(r: WaccResult) -> dict:
    return {
        "equity_value": f"{r.equity_value}",
        "debt_value": f"{r.debt_value}",
        "total_capital": f"{r.total_capital}",
        "weight_equity_pct": f"{r.weight_equity_pct}",
        "weight_debt_pct": f"{r.weight_debt_pct}",
        "cost_of_equity_pct": f"{r.cost_of_equity_pct}",
        "cost_of_debt_pretax_pct": f"{r.cost_of_debt_pretax_pct}",
        "cost_of_debt_after_tax_pct": f"{r.cost_of_debt_after_tax_pct}",
        "tax_rate_pct": f"{r.tax_rate_pct}",
        "wacc_pct": f"{r.wacc_pct}",
        "warnings": r.warnings,
    }


# ═══════════════════════════════════════════════════════════════
# DCF Valuation
# ═══════════════════════════════════════════════════════════════


@dataclass
class DcfInput:
    # Projected Free Cash Flows for years 1..n (in order)
    free_cash_flows: List[Decimal] = field(default_factory=list)
    wacc_pct: Decimal = Decimal("10")         # discount rate (%)
    terminal_growth_pct: Decimal = Decimal("2.5")  # g in Gordon growth (%)
    # For equity-value bridge:
    net_debt: Decimal = Decimal("0")          # + debt − cash
    shares_outstanding: Optional[Decimal] = None
    # Informational
    company_name: str = ""


@dataclass
class DcfYear:
    year: int
    fcf: Decimal
    discount_factor: Decimal
    present_value: Decimal


@dataclass
class DcfResult:
    company_name: str
    wacc_pct: Decimal
    terminal_growth_pct: Decimal
    # Per-year breakdown
    years: List[DcfYear]
    # Terminal
    terminal_fcf: Decimal                      # FCF_n+1
    terminal_value: Decimal                    # at year n
    terminal_pv: Decimal                        # discounted back
    # Totals
    pv_explicit_sum: Decimal                   # Σ of explicit-period PVs
    enterprise_value: Decimal                  # EV = PV_explicit + TV_pv
    net_debt: Decimal
    equity_value: Decimal                      # EV − Net debt
    value_per_share: Optional[Decimal]
    warnings: list[str] = field(default_factory=list)


def compute_dcf(inp: DcfInput) -> DcfResult:
    warnings: list[str] = []

    if not inp.free_cash_flows:
        raise ValueError("free_cash_flows is required (at least 1 year)")
    wacc = Decimal(str(inp.wacc_pct)) / Decimal("100")
    g = Decimal(str(inp.terminal_growth_pct)) / Decimal("100")

    if wacc <= 0 or wacc >= 1:
        raise ValueError("wacc_pct must be in (0, 100)")
    if g >= wacc:
        raise ValueError(
            f"terminal_growth ({inp.terminal_growth_pct}%) must be < WACC "
            f"({inp.wacc_pct}%). Otherwise terminal value → infinity."
        )

    cfs = [_q(cf) for cf in inp.free_cash_flows]
    years: List[DcfYear] = []
    one_plus_w = Decimal("1") + wacc
    factor = one_plus_w
    pv_sum = Decimal("0")
    for i, cf in enumerate(cfs, start=1):
        df = Decimal("1") / factor
        pv = cf * df
        pv_sum += pv
        years.append(DcfYear(
            year=i, fcf=cf, discount_factor=_q4(df), present_value=_q(pv),
        ))
        factor *= one_plus_w

    # Terminal value: Gordon growth formula
    last_fcf = cfs[-1]
    terminal_fcf = last_fcf * (Decimal("1") + g)
    terminal_value = terminal_fcf / (wacc - g)
    # PV of TV: discount by (1+wacc)^n where n = len(cfs)
    n = len(cfs)
    tv_discount_factor = Decimal("1") / (one_plus_w ** n)
    terminal_pv = terminal_value * tv_discount_factor

    enterprise_value = _q(pv_sum + terminal_pv)
    net_debt = _q(inp.net_debt)
    equity_value = _q(enterprise_value - net_debt)

    value_per_share = None
    if inp.shares_outstanding is not None:
        shares = Decimal(str(inp.shares_outstanding))
        if shares > 0:
            value_per_share = _q(equity_value / shares)

    # Warnings
    if equity_value < 0:
        warnings.append(
            "قيمة حقوق الملكية سالبة — دين الشركة يتجاوز قيمتها المؤسسية."
        )
    # Terminal value often dominates — flag if > 75%
    if pv_sum > 0:
        tv_share = terminal_pv / enterprise_value
        if tv_share > Decimal("0.75"):
            warnings.append(
                f"القيمة النهائية تمثّل {tv_share*100:.1f}% من EV — "
                f"تقييم شديد الحساسية لافتراضات النمو."
            )

    return DcfResult(
        company_name=inp.company_name,
        wacc_pct=_q(wacc * Decimal("100")),
        terminal_growth_pct=_q(g * Decimal("100")),
        years=years,
        terminal_fcf=_q(terminal_fcf),
        terminal_value=_q(terminal_value),
        terminal_pv=_q(terminal_pv),
        pv_explicit_sum=_q(pv_sum),
        enterprise_value=enterprise_value,
        net_debt=net_debt,
        equity_value=equity_value,
        value_per_share=value_per_share,
        warnings=warnings,
    )


def dcf_result_to_dict(r: DcfResult) -> dict:
    return {
        "company_name": r.company_name,
        "wacc_pct": f"{r.wacc_pct}",
        "terminal_growth_pct": f"{r.terminal_growth_pct}",
        "years": [
            {
                "year": y.year,
                "fcf": f"{y.fcf}",
                "discount_factor": f"{y.discount_factor}",
                "present_value": f"{y.present_value}",
            }
            for y in r.years
        ],
        "terminal_fcf": f"{r.terminal_fcf}",
        "terminal_value": f"{r.terminal_value}",
        "terminal_pv": f"{r.terminal_pv}",
        "pv_explicit_sum": f"{r.pv_explicit_sum}",
        "enterprise_value": f"{r.enterprise_value}",
        "net_debt": f"{r.net_debt}",
        "equity_value": f"{r.equity_value}",
        "value_per_share": None if r.value_per_share is None else f"{r.value_per_share}",
        "warnings": r.warnings,
    }
