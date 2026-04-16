"""
APEX Platform — Working Capital & Cash Conversion Cycle
═══════════════════════════════════════════════════════════════
Computes the three main operating-cycle metrics + CCC:

  DSO (Days Sales Outstanding)     = AR / Revenue × 365
                                     — how long it takes to collect a sale
  DIO (Days Inventory Outstanding) = Inventory / COGS × 365
                                     — how long inventory sits before sold
  DPO (Days Payable Outstanding)   = AP / COGS × 365
                                     — how long we delay paying suppliers

  CCC = DSO + DIO − DPO
        → days of working capital needed to fund the operating cycle.
        Lower is better (less cash tied up).

Also reports working-capital components, ratios, and provides
actionable recommendations (extend DPO, reduce DSO, trim DIO).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


def _safe_div(num: Decimal, den: Decimal, dp: int = 2) -> Optional[Decimal]:
    if den == 0:
        return None
    q = Decimal("1").scaleb(-dp)
    return (num / den).quantize(q, rounding=ROUND_HALF_UP)


@dataclass
class WorkingCapitalInput:
    period_label: str = "FY"
    period_days: int = 365

    # Income-statement inputs
    revenue: Decimal = Decimal("0")
    cogs: Decimal = Decimal("0")

    # Balance-sheet snapshot (end of period)
    current_assets: Decimal = Decimal("0")
    current_liabilities: Decimal = Decimal("0")
    accounts_receivable: Decimal = Decimal("0")
    inventory: Decimal = Decimal("0")
    accounts_payable: Decimal = Decimal("0")
    cash: Decimal = Decimal("0")


@dataclass
class WorkingCapitalResult:
    period_label: str
    period_days: int
    revenue: Decimal
    cogs: Decimal

    # Balances
    current_assets: Decimal
    current_liabilities: Decimal
    working_capital: Decimal           # CA − CL
    net_working_capital: Decimal       # CA − Cash − CL  (operating WC)

    # Cycle (days)
    dso: Optional[Decimal]
    dio: Optional[Decimal]
    dpo: Optional[Decimal]
    ccc: Optional[Decimal]             # DSO + DIO − DPO

    # Ratios
    current_ratio: Optional[Decimal]
    quick_ratio: Optional[Decimal]

    # Assessment
    health: str                        # 'healthy' | 'watch' | 'risk'
    recommendations: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def compute_working_capital(inp: WorkingCapitalInput) -> WorkingCapitalResult:
    warnings: list[str] = []
    recs: list[str] = []

    period_days = inp.period_days if inp.period_days > 0 else 365

    rev = _q(inp.revenue)
    cogs = _q(inp.cogs)
    ca = _q(inp.current_assets)
    cl = _q(inp.current_liabilities)
    ar = _q(inp.accounts_receivable)
    inv = _q(inp.inventory)
    ap = _q(inp.accounts_payable)
    cash = _q(inp.cash)

    if rev < 0:
        warnings.append("الإيرادات سالبة — تأكد من الإدخال.")
    if cogs < 0:
        warnings.append("تكلفة البضاعة المباعة سالبة — تأكد من الإدخال.")

    # DSO = AR / Revenue × days
    dso = None
    if rev > 0 and ar >= 0:
        dso = _safe_div(ar * Decimal(period_days), rev)
    # DIO = Inventory / COGS × days
    dio = None
    if cogs > 0 and inv >= 0:
        dio = _safe_div(inv * Decimal(period_days), cogs)
    # DPO = AP / COGS × days
    dpo = None
    if cogs > 0 and ap >= 0:
        dpo = _safe_div(ap * Decimal(period_days), cogs)

    # CCC
    ccc = None
    if dso is not None and dio is not None and dpo is not None:
        ccc = _q(dso + dio - dpo)

    # Working capital
    wc = _q(ca - cl)
    nwc = _q(ca - cash - cl)   # operating WC (excl cash)

    # Ratios
    current_ratio = _safe_div(ca, cl, dp=4) if cl > 0 else None
    quick_ratio = _safe_div(ca - inv, cl, dp=4) if cl > 0 else None

    # Health assessment
    health = "watch"
    if ccc is not None:
        if ccc <= Decimal("30"):
            health = "healthy"
        elif ccc <= Decimal("75"):
            health = "watch"
        else:
            health = "risk"

    # Downgrade if current ratio is weak
    if current_ratio is not None and current_ratio < Decimal("1.0"):
        health = "risk"
        recs.append(
            "نسبة التداول أقل من 1 — السيولة قصيرة الأجل مُجهَدة. "
            "قلّل المخزون أو التفاوض لتمديد شروط السداد مع المورّدين."
        )

    # Recommendations
    if dso is not None and dso > Decimal("60"):
        recs.append(
            f"DSO = {dso} يوم. حسّن سياسة التحصيل — اعتمد خصم دفع مبكر، "
            f"تحصيل إلكتروني، مراجعة ائتمان العملاء."
        )
    if dio is not None and dio > Decimal("90"):
        recs.append(
            f"DIO = {dio} يوم. المخزون بطيء — راجع تصنيف ABC، "
            f"قلّل نقاط إعادة الطلب، بع المخزون الراكد."
        )
    if dpo is not None and dpo < Decimal("30") and cogs > 0:
        recs.append(
            f"DPO = {dpo} يوم. تفاوض مع المورّدين لتمديد السداد إلى 45-60 يوم — "
            f"هذا يحرّر نقد التشغيل دون تكلفة."
        )
    if ccc is not None and ccc > Decimal("90"):
        recs.append(
            f"دورة التحويل النقدي طويلة ({ccc} يوم). كل يوم اختزال يوفّر "
            f"نقداً مساوياً للإيرادات اليومية."
        )

    if not recs and health == "healthy":
        recs.append("رأس المال العامل في حالة جيدة — استمر في المراقبة.")

    return WorkingCapitalResult(
        period_label=inp.period_label,
        period_days=period_days,
        revenue=rev,
        cogs=cogs,
        current_assets=ca,
        current_liabilities=cl,
        working_capital=wc,
        net_working_capital=nwc,
        dso=dso,
        dio=dio,
        dpo=dpo,
        ccc=ccc,
        current_ratio=current_ratio,
        quick_ratio=quick_ratio,
        health=health,
        recommendations=recs,
        warnings=warnings,
    )


def result_to_dict(r: WorkingCapitalResult) -> dict:
    def _s(v):
        return None if v is None else f"{v}"
    return {
        "period_label": r.period_label,
        "period_days": r.period_days,
        "revenue": f"{r.revenue}",
        "cogs": f"{r.cogs}",
        "current_assets": f"{r.current_assets}",
        "current_liabilities": f"{r.current_liabilities}",
        "working_capital": f"{r.working_capital}",
        "net_working_capital": f"{r.net_working_capital}",
        "dso": _s(r.dso),
        "dio": _s(r.dio),
        "dpo": _s(r.dpo),
        "ccc": _s(r.ccc),
        "current_ratio": _s(r.current_ratio),
        "quick_ratio": _s(r.quick_ratio),
        "health": r.health,
        "recommendations": r.recommendations,
        "warnings": r.warnings,
    }
