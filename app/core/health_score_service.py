"""
APEX Platform — Financial Health Score (Composite)
═══════════════════════════════════════════════════════════════
Weighted 0-100 score aggregating five dimensions:

  • Liquidity         (20%) — current ratio, quick ratio
  • Solvency          (20%) — debt/equity, interest coverage
  • Profitability     (25%) — net margin, ROE
  • Efficiency        (20%) — asset turnover, CCC
  • Cash Quality      (15%) — OCF / Net income, OCF ratio

Each dimension scores 0-100, weighted to produce the composite.
Grades: A (85+), B (70-84), C (55-69), D (40-54), F (<40).

Also produces a "red-flag" list — the 3 weakest sub-metrics —
so the user knows exactly what to work on.
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


@dataclass
class HealthScoreInput:
    # Liquidity
    current_ratio: Optional[Decimal] = None
    quick_ratio: Optional[Decimal] = None
    # Solvency
    debt_to_equity: Optional[Decimal] = None
    interest_coverage: Optional[Decimal] = None
    # Profitability
    net_margin_pct: Optional[Decimal] = None
    roe_pct: Optional[Decimal] = None
    # Efficiency
    asset_turnover: Optional[Decimal] = None
    ccc_days: Optional[Decimal] = None              # lower is better
    # Cash quality
    ocf_to_ni_ratio: Optional[Decimal] = None        # OCF / NI, ≥1 healthy
    ocf_ratio: Optional[Decimal] = None              # OCF / CL
    period_label: str = "FY"


@dataclass
class MetricScore:
    name_ar: str
    name_en: str
    value: Optional[Decimal]
    score: int                  # 0-100
    weight_pct: Decimal
    dimension: str


@dataclass
class DimensionScore:
    name_ar: str
    name_en: str
    score: int                  # 0-100 weighted within dimension
    weight_pct: Decimal         # contribution to composite
    metrics: List[MetricScore]


@dataclass
class HealthScoreResult:
    period_label: str
    composite_score: int
    grade: str                  # A/B/C/D/F
    grade_label_ar: str
    dimensions: List[DimensionScore]
    all_metrics: List[MetricScore]
    red_flags: List[MetricScore]   # weakest 3
    strengths: List[MetricScore]   # strongest 3
    warnings: list[str] = field(default_factory=list)


# Each metric: scoring function (value -> 0-100)
def _score_current_ratio(v: Optional[Decimal]) -> int:
    if v is None: return -1
    # 2.0+ = 100, 1.5 = 85, 1.0 = 60, 0.5 = 20, 0 = 0
    if v >= Decimal("2.0"): return 100
    if v >= Decimal("1.5"): return 85
    if v >= Decimal("1.2"): return 70
    if v >= Decimal("1.0"): return 60
    if v >= Decimal("0.8"): return 40
    if v >= Decimal("0.5"): return 20
    return 0


def _score_quick_ratio(v: Optional[Decimal]) -> int:
    if v is None: return -1
    if v >= Decimal("1.5"): return 100
    if v >= Decimal("1.0"): return 85
    if v >= Decimal("0.7"): return 65
    if v >= Decimal("0.5"): return 45
    return 20


def _score_debt_to_equity(v: Optional[Decimal]) -> int:
    if v is None: return -1
    # Lower is better
    if v <= Decimal("0.5"): return 100
    if v <= Decimal("1.0"): return 85
    if v <= Decimal("1.5"): return 70
    if v <= Decimal("2.0"): return 50
    if v <= Decimal("3.0"): return 25
    return 10


def _score_interest_coverage(v: Optional[Decimal]) -> int:
    if v is None: return -1
    if v >= Decimal("10"): return 100
    if v >= Decimal("5"): return 85
    if v >= Decimal("3"): return 70
    if v >= Decimal("1.5"): return 45
    if v >= Decimal("1"): return 20
    return 0


def _score_net_margin(v: Optional[Decimal]) -> int:
    # value in %
    if v is None: return -1
    if v >= Decimal("20"): return 100
    if v >= Decimal("15"): return 90
    if v >= Decimal("10"): return 80
    if v >= Decimal("5"): return 60
    if v >= Decimal("0"): return 40
    return 10


def _score_roe(v: Optional[Decimal]) -> int:
    if v is None: return -1
    if v >= Decimal("20"): return 100
    if v >= Decimal("15"): return 90
    if v >= Decimal("10"): return 75
    if v >= Decimal("5"): return 55
    if v >= Decimal("0"): return 35
    return 10


def _score_asset_turnover(v: Optional[Decimal]) -> int:
    if v is None: return -1
    if v >= Decimal("2.0"): return 100
    if v >= Decimal("1.0"): return 80
    if v >= Decimal("0.7"): return 60
    if v >= Decimal("0.4"): return 40
    return 20


def _score_ccc(v: Optional[Decimal]) -> int:
    # lower is better
    if v is None: return -1
    if v <= Decimal("0"): return 100
    if v <= Decimal("30"): return 90
    if v <= Decimal("60"): return 70
    if v <= Decimal("90"): return 50
    if v <= Decimal("150"): return 30
    return 15


def _score_ocf_to_ni(v: Optional[Decimal]) -> int:
    if v is None: return -1
    if v >= Decimal("1.2"): return 100
    if v >= Decimal("1.0"): return 85
    if v >= Decimal("0.7"): return 60
    if v >= Decimal("0.3"): return 35
    return 15


def _score_ocf_ratio(v: Optional[Decimal]) -> int:
    if v is None: return -1
    if v >= Decimal("1.0"): return 100
    if v >= Decimal("0.5"): return 75
    if v >= Decimal("0.3"): return 55
    if v >= Decimal("0.1"): return 35
    return 15


# ═══════════════════════════════════════════════════════════════
# Dimension definitions
# ═══════════════════════════════════════════════════════════════

# Each dimension: weight_pct + list of (metric_name_ar, name_en, scorer, getter)
_DIMENSIONS = [
    {
        "code": "liquidity",
        "name_ar": "السيولة", "name_en": "Liquidity", "weight": Decimal("20"),
        "metrics": [
            ("نسبة التداول", "Current ratio", _score_current_ratio, "current_ratio"),
            ("النسبة السريعة", "Quick ratio", _score_quick_ratio, "quick_ratio"),
        ],
    },
    {
        "code": "solvency",
        "name_ar": "الملاءة", "name_en": "Solvency", "weight": Decimal("20"),
        "metrics": [
            ("الدين/حقوق الملكية", "Debt-to-Equity", _score_debt_to_equity, "debt_to_equity"),
            ("تغطية الفائدة", "Interest coverage", _score_interest_coverage, "interest_coverage"),
        ],
    },
    {
        "code": "profitability",
        "name_ar": "الربحية", "name_en": "Profitability", "weight": Decimal("25"),
        "metrics": [
            ("صافي الهامش %", "Net margin %", _score_net_margin, "net_margin_pct"),
            ("العائد على حقوق الملكية %", "ROE %", _score_roe, "roe_pct"),
        ],
    },
    {
        "code": "efficiency",
        "name_ar": "الكفاءة", "name_en": "Efficiency", "weight": Decimal("20"),
        "metrics": [
            ("دوران الأصول", "Asset turnover", _score_asset_turnover, "asset_turnover"),
            ("دورة التحويل النقدي", "CCC (days)", _score_ccc, "ccc_days"),
        ],
    },
    {
        "code": "cash_quality",
        "name_ar": "جودة النقد", "name_en": "Cash quality", "weight": Decimal("15"),
        "metrics": [
            ("OCF/صافي الربح", "OCF/NI ratio", _score_ocf_to_ni, "ocf_to_ni_ratio"),
            ("OCF/الخصوم المتداولة", "OCF ratio", _score_ocf_ratio, "ocf_ratio"),
        ],
    },
]


def _grade(score: int) -> tuple[str, str]:
    if score >= 85: return "A", "ممتاز"
    if score >= 70: return "B", "جيد جداً"
    if score >= 55: return "C", "مقبول"
    if score >= 40: return "D", "ضعيف"
    return "F", "خطر"


def compute_health_score(inp: HealthScoreInput) -> HealthScoreResult:
    warnings: list[str] = []
    all_metrics: List[MetricScore] = []
    dims_out: List[DimensionScore] = []

    composite = Decimal("0")
    composite_weight_used = Decimal("0")

    for dim in _DIMENSIONS:
        metric_scores: List[MetricScore] = []
        dim_total = 0
        dim_count = 0
        # equal weight within dimension
        for name_ar, name_en, scorer, attr in dim["metrics"]:
            value = getattr(inp, attr)
            s = scorer(value)
            ms = MetricScore(
                name_ar=name_ar,
                name_en=name_en,
                value=_q(value) if value is not None else None,
                score=s if s >= 0 else 0,
                weight_pct=dim["weight"] / Decimal(len(dim["metrics"])),
                dimension=dim["code"],
            )
            all_metrics.append(ms)
            metric_scores.append(ms)
            if s >= 0:
                dim_total += s
                dim_count += 1

        if dim_count == 0:
            dim_score = 0
            warnings.append(
                f"بعد '{dim['name_ar']}': لا توجد بيانات — تم احتساب صفر."
            )
        else:
            dim_score = dim_total // dim_count

        dims_out.append(DimensionScore(
            name_ar=dim["name_ar"], name_en=dim["name_en"],
            score=dim_score, weight_pct=dim["weight"],
            metrics=metric_scores,
        ))

        composite += Decimal(dim_score) * dim["weight"] / Decimal("100")
        composite_weight_used += dim["weight"]

    # Re-normalize if some dimensions had no data
    if composite_weight_used > 0 and composite_weight_used < Decimal("100"):
        composite = composite * Decimal("100") / composite_weight_used
        warnings.append(
            f"تم احتساب الدرجة على {composite_weight_used}% فقط من الأبعاد لوجود بيانات ناقصة."
        )

    composite_int = int(composite.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    grade, grade_label = _grade(composite_int)

    # Red flags: weakest metrics with value != None, sorted ascending
    scored = [m for m in all_metrics if m.value is not None]
    scored_sorted = sorted(scored, key=lambda m: m.score)
    red_flags = scored_sorted[:3]
    strengths = list(reversed(scored_sorted[-3:]))

    return HealthScoreResult(
        period_label=inp.period_label,
        composite_score=composite_int,
        grade=grade,
        grade_label_ar=grade_label,
        dimensions=dims_out,
        all_metrics=all_metrics,
        red_flags=red_flags,
        strengths=strengths,
        warnings=warnings,
    )


def result_to_dict(r: HealthScoreResult) -> dict:
    def metric_dict(m: MetricScore) -> dict:
        return {
            "name_ar": m.name_ar,
            "name_en": m.name_en,
            "value": None if m.value is None else f"{m.value}",
            "score": m.score,
            "weight_pct": f"{m.weight_pct}",
            "dimension": m.dimension,
        }
    return {
        "period_label": r.period_label,
        "composite_score": r.composite_score,
        "grade": r.grade,
        "grade_label_ar": r.grade_label_ar,
        "dimensions": [
            {
                "name_ar": d.name_ar,
                "name_en": d.name_en,
                "score": d.score,
                "weight_pct": f"{d.weight_pct}",
                "metrics": [metric_dict(m) for m in d.metrics],
            }
            for d in r.dimensions
        ],
        "red_flags": [metric_dict(m) for m in r.red_flags],
        "strengths": [metric_dict(m) for m in r.strengths],
        "warnings": r.warnings,
    }
