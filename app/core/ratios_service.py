"""
APEX Platform — Financial Ratios Calculator
═══════════════════════════════════════════════════════════════
Computes 18 standard financial ratios from balance-sheet + income-
statement + cash-flow inputs, grouped into 5 categories:

  1. Liquidity      (3 ratios)
  2. Solvency       (3 ratios)
  3. Profitability  (5 ratios)
  4. Efficiency     (4 ratios)
  5. Valuation      (3 ratios, need market data)

Each ratio returns:
  - value (Decimal)
  - formula (ar / en)
  - category
  - healthy_range + health_status (low / normal / high / n/a)
  - interpretation_ar (short diagnostic text)

All math is Decimal. Division-by-zero is mapped to None + a warning,
not an exception, so a partially-filled balance sheet can still
produce a partial report.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, DivisionByZero, InvalidOperation, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")


def _q(value: Optional[Decimal | int | float | str]) -> Decimal:
    if value is None:
        return Decimal("0")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value


def _safe_div(num: Decimal, den: Decimal, dp: int = 4) -> Optional[Decimal]:
    try:
        if den == 0:
            return None
        q = Decimal("1").scaleb(-dp)
        return (num / den).quantize(q, rounding=ROUND_HALF_UP)
    except (DivisionByZero, InvalidOperation):
        return None


# ═══════════════════════════════════════════════════════════════
# Inputs
# ═══════════════════════════════════════════════════════════════


@dataclass
class RatiosInput:
    """All amounts in homogeneous currency. Supply only what you have —
    the calculator gracefully reports None for missing inputs."""

    # Balance Sheet
    current_assets: Optional[Decimal] = None
    cash_and_equivalents: Optional[Decimal] = None
    inventory: Optional[Decimal] = None
    receivables: Optional[Decimal] = None
    current_liabilities: Optional[Decimal] = None
    total_assets: Optional[Decimal] = None
    total_liabilities: Optional[Decimal] = None
    total_equity: Optional[Decimal] = None
    long_term_debt: Optional[Decimal] = None

    # Income Statement
    revenue: Optional[Decimal] = None
    cogs: Optional[Decimal] = None
    gross_profit: Optional[Decimal] = None
    operating_income: Optional[Decimal] = None          # EBIT
    interest_expense: Optional[Decimal] = None
    net_income: Optional[Decimal] = None

    # Cash flow (subset — optional)
    operating_cash_flow: Optional[Decimal] = None

    # Market (optional; needed for valuation ratios)
    market_cap: Optional[Decimal] = None
    shares_outstanding: Optional[Decimal] = None
    share_price: Optional[Decimal] = None
    dividends_per_share: Optional[Decimal] = None

    # Meta
    period_label: str = "FY"


# ═══════════════════════════════════════════════════════════════
# Result
# ═══════════════════════════════════════════════════════════════


_CATEGORIES = ("liquidity", "solvency", "profitability", "efficiency", "valuation")


@dataclass
class Ratio:
    code: str
    category: str
    name_ar: str
    name_en: str
    formula_ar: str
    value: Optional[Decimal]
    unit: str                   # 'ratio', 'percent', 'days', 'times', 'sar'
    health: str                 # 'healthy', 'watch', 'risk', 'n/a'
    healthy_range: Optional[str] = None  # e.g. ">= 1.5"
    interpretation_ar: str = ""


@dataclass
class RatiosResult:
    period_label: str
    ratios: list[Ratio] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def by_category(self) -> dict[str, list[Ratio]]:
        out: dict[str, list[Ratio]] = {c: [] for c in _CATEGORIES}
        for r in self.ratios:
            out.setdefault(r.category, []).append(r)
        return out


# ═══════════════════════════════════════════════════════════════
# Ratio definitions — one function per ratio
# ═══════════════════════════════════════════════════════════════


def _r(code, cat, name_ar, name_en, formula, value, unit, health, healthy_range=None, interp=""):
    return Ratio(
        code=code, category=cat, name_ar=name_ar, name_en=name_en,
        formula_ar=formula, value=value, unit=unit, health=health,
        healthy_range=healthy_range, interpretation_ar=interp,
    )


def _health_range(val: Optional[Decimal], low: Decimal, high: Decimal,
                  bigger_is_better: bool = True) -> str:
    """Classify a value into healthy/watch/risk buckets."""
    if val is None:
        return "n/a"
    if bigger_is_better:
        if val >= high:
            return "healthy"
        if val >= low:
            return "watch"
        return "risk"
    else:
        if val <= low:
            return "healthy"
        if val <= high:
            return "watch"
        return "risk"


# ═══════════════════════════════════════════════════════════════
# Main computation
# ═══════════════════════════════════════════════════════════════


def compute_ratios(inp: RatiosInput) -> RatiosResult:
    warnings: list[str] = []
    ratios: list[Ratio] = []

    ca = _q(inp.current_assets) if inp.current_assets is not None else None
    cash = _q(inp.cash_and_equivalents) if inp.cash_and_equivalents is not None else None
    inv = _q(inp.inventory) if inp.inventory is not None else None
    cl = _q(inp.current_liabilities) if inp.current_liabilities is not None else None
    ta = _q(inp.total_assets) if inp.total_assets is not None else None
    tl = _q(inp.total_liabilities) if inp.total_liabilities is not None else None
    te = _q(inp.total_equity) if inp.total_equity is not None else None
    ltd = _q(inp.long_term_debt) if inp.long_term_debt is not None else None

    rev = _q(inp.revenue) if inp.revenue is not None else None
    cogs = _q(inp.cogs) if inp.cogs is not None else None
    gp = _q(inp.gross_profit) if inp.gross_profit is not None else None
    op = _q(inp.operating_income) if inp.operating_income is not None else None
    intr = _q(inp.interest_expense) if inp.interest_expense is not None else None
    ni = _q(inp.net_income) if inp.net_income is not None else None

    rec = _q(inp.receivables) if inp.receivables is not None else None
    ocf = _q(inp.operating_cash_flow) if inp.operating_cash_flow is not None else None

    mc = _q(inp.market_cap) if inp.market_cap is not None else None
    sp = _q(inp.share_price) if inp.share_price is not None else None
    so = _q(inp.shares_outstanding) if inp.shares_outstanding is not None else None
    dps = _q(inp.dividends_per_share) if inp.dividends_per_share is not None else None

    if rev is not None and rev < 0:
        warnings.append("الإيرادات سالبة — يُوصى بفحص البيانات.")
    if te is not None and te < 0:
        warnings.append("حقوق الملكية سالبة — عجز رأس المال.")

    # ── LIQUIDITY ───────────────────────────────────────────────
    # Current Ratio = CA / CL   (>= 1.5 healthy, >= 1.0 watch)
    if ca is not None and cl is not None:
        v = _safe_div(ca, cl)
        ratios.append(_r("current_ratio", "liquidity",
            "نسبة التداول", "Current Ratio",
            "الأصول المتداولة ÷ الخصوم المتداولة",
            v, "times",
            _health_range(v, Decimal("1.0"), Decimal("1.5")),
            ">= 1.5",
            "يقيس قدرة الشركة على سداد التزاماتها قصيرة الأجل من أصولها المتداولة.",
        ))
    # Quick Ratio = (CA - Inv) / CL   (>= 1.0 healthy)
    if ca is not None and inv is not None and cl is not None:
        v = _safe_div(ca - inv, cl)
        ratios.append(_r("quick_ratio", "liquidity",
            "النسبة السريعة", "Quick Ratio",
            "(الأصول المتداولة − المخزون) ÷ الخصوم المتداولة",
            v, "times",
            _health_range(v, Decimal("0.5"), Decimal("1.0")),
            ">= 1.0",
            "أدق من نسبة التداول — يستبعد المخزون (أقل أصول قابلة للتسييل بسرعة).",
        ))
    # Cash Ratio = Cash / CL   (>= 0.5 healthy)
    if cash is not None and cl is not None:
        v = _safe_div(cash, cl)
        ratios.append(_r("cash_ratio", "liquidity",
            "نسبة النقد", "Cash Ratio",
            "النقد وما يعادله ÷ الخصوم المتداولة",
            v, "times",
            _health_range(v, Decimal("0.2"), Decimal("0.5")),
            ">= 0.5",
            "أشد اختبارات السيولة — نقد متوفر فوراً لسداد الخصوم.",
        ))

    # ── SOLVENCY ────────────────────────────────────────────────
    # Debt / Equity = TL / TE   (<= 1.0 healthy, <= 2.0 watch)
    if tl is not None and te is not None:
        v = _safe_div(tl, te)
        ratios.append(_r("debt_to_equity", "solvency",
            "الدين إلى حقوق الملكية", "Debt-to-Equity",
            "إجمالي الخصوم ÷ حقوق الملكية",
            v, "times",
            _health_range(v, Decimal("1.0"), Decimal("2.0"), bigger_is_better=False),
            "<= 1.0",
            "كلما ارتفعت دلّت على اعتماد أكبر على الديون وارتفاع المخاطر المالية.",
        ))
    # Debt Ratio = TL / TA   (<= 0.5 healthy)
    if tl is not None and ta is not None:
        v = _safe_div(tl, ta)
        ratios.append(_r("debt_ratio", "solvency",
            "نسبة الدين", "Debt Ratio",
            "إجمالي الخصوم ÷ إجمالي الأصول",
            v, "ratio",
            _health_range(v, Decimal("0.5"), Decimal("0.7"), bigger_is_better=False),
            "<= 0.5",
            "نسبة أصول الشركة الممولة عبر الديون.",
        ))
    # Interest Coverage = EBIT / Interest   (>= 3 healthy)
    if op is not None and intr is not None and intr > 0:
        v = _safe_div(op, intr)
        ratios.append(_r("interest_coverage", "solvency",
            "تغطية الفائدة", "Interest Coverage",
            "الأرباح التشغيلية ÷ مصروف الفائدة",
            v, "times",
            _health_range(v, Decimal("1.5"), Decimal("3.0")),
            ">= 3.0",
            "كم مرة يغطي الربح التشغيلي مصروف الفوائد — حماية من تعثر السداد.",
        ))

    # ── PROFITABILITY ───────────────────────────────────────────
    # Gross Margin = GP / Rev   (>= 40% healthy generic)
    if gp is not None and rev is not None:
        v = _safe_div(gp, rev)
        pct = (v * 100).quantize(_TWO) if v is not None else None
        ratios.append(_r("gross_margin", "profitability",
            "هامش الربح الإجمالي", "Gross Margin",
            "الربح الإجمالي ÷ الإيرادات × 100",
            pct, "percent",
            _health_range(v, Decimal("0.20"), Decimal("0.40")),
            ">= 40%",
            "هامش الربح بعد تكلفة البضاعة المباعة — مقياس قوة تسعير المنتج.",
        ))
    # Operating Margin = EBIT / Rev   (>= 15% healthy)
    if op is not None and rev is not None:
        v = _safe_div(op, rev)
        pct = (v * 100).quantize(_TWO) if v is not None else None
        ratios.append(_r("operating_margin", "profitability",
            "هامش الربح التشغيلي", "Operating Margin",
            "الربح التشغيلي ÷ الإيرادات × 100",
            pct, "percent",
            _health_range(v, Decimal("0.08"), Decimal("0.15")),
            ">= 15%",
            "الربحية بعد تكاليف التشغيل الرئيسية — مقياس الكفاءة التشغيلية.",
        ))
    # Net Margin = NI / Rev   (>= 10% healthy)
    if ni is not None and rev is not None:
        v = _safe_div(ni, rev)
        pct = (v * 100).quantize(_TWO) if v is not None else None
        ratios.append(_r("net_margin", "profitability",
            "هامش صافي الربح", "Net Profit Margin",
            "صافي الربح ÷ الإيرادات × 100",
            pct, "percent",
            _health_range(v, Decimal("0.05"), Decimal("0.10")),
            ">= 10%",
            "الربحية النهائية بعد كل المصروفات والضرائب.",
        ))
    # ROE = NI / Equity   (>= 15% healthy)
    if ni is not None and te is not None and te > 0:
        v = _safe_div(ni, te)
        pct = (v * 100).quantize(_TWO) if v is not None else None
        ratios.append(_r("roe", "profitability",
            "العائد على حقوق الملكية", "Return on Equity (ROE)",
            "صافي الربح ÷ حقوق الملكية × 100",
            pct, "percent",
            _health_range(v, Decimal("0.08"), Decimal("0.15")),
            ">= 15%",
            "كفاءة توظيف أموال المساهمين — معيار أساسي لتقييم المستثمر.",
        ))
    # ROA = NI / TA   (>= 5% healthy)
    if ni is not None and ta is not None:
        v = _safe_div(ni, ta)
        pct = (v * 100).quantize(_TWO) if v is not None else None
        ratios.append(_r("roa", "profitability",
            "العائد على الأصول", "Return on Assets (ROA)",
            "صافي الربح ÷ إجمالي الأصول × 100",
            pct, "percent",
            _health_range(v, Decimal("0.02"), Decimal("0.05")),
            ">= 5%",
            "كفاءة الشركة في توليد الأرباح من أصولها.",
        ))

    # ── EFFICIENCY ──────────────────────────────────────────────
    # Asset Turnover = Rev / TA   (>= 1.0 generic)
    if rev is not None and ta is not None:
        v = _safe_div(rev, ta)
        ratios.append(_r("asset_turnover", "efficiency",
            "دوران الأصول", "Asset Turnover",
            "الإيرادات ÷ إجمالي الأصول",
            v, "times",
            _health_range(v, Decimal("0.5"), Decimal("1.0")),
            ">= 1.0",
            "كل ريال من الأصول يولّد كم من الإيرادات.",
        ))
    # Inventory Turnover = COGS / Inv
    if cogs is not None and inv is not None and inv > 0:
        v = _safe_div(cogs, inv)
        ratios.append(_r("inventory_turnover", "efficiency",
            "دوران المخزون", "Inventory Turnover",
            "تكلفة البضاعة المباعة ÷ المخزون",
            v, "times",
            _health_range(v, Decimal("4"), Decimal("8")),
            ">= 8",
            "عدد مرات تدوير المخزون سنوياً — كلما زاد كان أفضل.",
        ))
    # Days Sales Outstanding = (Rec / Rev) * 365
    if rec is not None and rev is not None and rev > 0:
        quotient = _safe_div(rec, rev, dp=6)
        v = (quotient * Decimal("365")).quantize(_TWO) if quotient is not None else None
        ratios.append(_r("dso", "efficiency",
            "متوسط فترة التحصيل", "Days Sales Outstanding",
            "(المدينون ÷ الإيرادات) × 365",
            v, "days",
            _health_range(v, Decimal("30"), Decimal("60"), bigger_is_better=False),
            "<= 30 يوم",
            "متوسط عدد الأيام لتحصيل المبيعات — كلما قلّ كان أفضل.",
        ))
    # Operating Cash Flow Ratio = OCF / CL
    if ocf is not None and cl is not None and cl > 0:
        v = _safe_div(ocf, cl)
        ratios.append(_r("ocf_ratio", "efficiency",
            "نسبة التدفق النقدي التشغيلي", "Operating Cash Flow Ratio",
            "التدفق النقدي التشغيلي ÷ الخصوم المتداولة",
            v, "times",
            _health_range(v, Decimal("0.4"), Decimal("1.0")),
            ">= 1.0",
            "قدرة التدفق النقدي من التشغيل على تغطية الالتزامات قصيرة الأجل.",
        ))

    # ── VALUATION (optional — needs market data) ───────────────
    # EPS = NI / shares outstanding
    eps = None
    if ni is not None and so is not None and so > 0:
        eps = _safe_div(ni, so, dp=4)
        ratios.append(_r("eps", "valuation",
            "ربحية السهم", "Earnings Per Share (EPS)",
            "صافي الربح ÷ عدد الأسهم",
            eps, "sar",
            "n/a",
            None,
            "الربح المنسوب لكل سهم.",
        ))
    # P/E = Price / EPS
    if sp is not None and eps is not None and eps > 0:
        v = _safe_div(sp, eps, dp=2)
        ratios.append(_r("pe_ratio", "valuation",
            "مكرر الربحية", "Price / Earnings (P/E)",
            "سعر السهم ÷ ربحية السهم",
            v, "times",
            _health_range(v, Decimal("15"), Decimal("25"), bigger_is_better=False),
            "<= 25x",
            "سعر السهم نسبةً لأرباحه — مقياس تقييم المستثمرين.",
        ))
    # Dividend Yield = DPS / Price
    if dps is not None and sp is not None and sp > 0:
        v = _safe_div(dps, sp, dp=4)
        pct = (v * 100).quantize(_TWO) if v is not None else None
        ratios.append(_r("dividend_yield", "valuation",
            "عائد التوزيعات", "Dividend Yield",
            "توزيعات السهم ÷ سعر السهم × 100",
            pct, "percent",
            _health_range(v, Decimal("0.02"), Decimal("0.04")),
            ">= 4%",
            "العائد النقدي السنوي للمساهم كنسبة من سعر السهم.",
        ))

    return RatiosResult(period_label=inp.period_label, ratios=ratios, warnings=warnings)


def result_to_dict(r: RatiosResult) -> dict:
    by_cat = r.by_category()
    return {
        "period_label": r.period_label,
        "warnings": r.warnings,
        "categories": {
            cat: [
                {
                    "code": rat.code,
                    "category": rat.category,
                    "name_ar": rat.name_ar,
                    "name_en": rat.name_en,
                    "formula_ar": rat.formula_ar,
                    "value": None if rat.value is None else f"{rat.value}",
                    "unit": rat.unit,
                    "health": rat.health,
                    "healthy_range": rat.healthy_range,
                    "interpretation_ar": rat.interpretation_ar,
                }
                for rat in by_cat.get(cat, [])
            ]
            for cat in _CATEGORIES
        },
        "total_ratios": len(r.ratios),
    }
