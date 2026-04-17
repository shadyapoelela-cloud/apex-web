"""
APEX Platform — IFRS 9 Expected Credit Loss (ECL)
═══════════════════════════════════════════════════════════════
Simplified ECL model for trade receivables using provision matrix:

  ECL = EAD × PD × LGD

Where:
  EAD  = Exposure at Default (amount outstanding)
  PD   = Probability of Default (by aging bucket)
  LGD  = Loss Given Default (1 − recovery rate)

Aging buckets + default PDs (industry averages — override as needed):
  Current (0-30d):     0.5%
  31-60 days:          2%
  61-90 days:          5%
  91-180 days:         15%
  181-365 days:        40%
  >365 days:           80%

Three-stage model (for financial instruments):
  Stage 1: 12-month ECL (performing)
  Stage 2: Lifetime ECL (significant increase in credit risk)
  Stage 3: Lifetime ECL + credit-impaired
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Dict, List, Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


DEFAULT_PD_MATRIX = {
    "current":      Decimal("0.5"),
    "30_60":        Decimal("2"),
    "61_90":        Decimal("5"),
    "91_180":       Decimal("15"),
    "181_365":      Decimal("40"),
    "over_365":     Decimal("80"),
}
AGING_BUCKETS = sorted(DEFAULT_PD_MATRIX.keys())


@dataclass
class ReceivableBucket:
    bucket: str                          # one of AGING_BUCKETS
    exposure: Decimal                    # total receivable in this bucket
    # Optional overrides
    pd_override_pct: Optional[Decimal] = None
    lgd_pct: Decimal = Decimal("50")     # default 50% recovery assumption


@dataclass
class EclInput:
    entity_name: str
    period_label: str
    currency: str = "SAR"
    custom_pd_matrix: Optional[Dict[str, Decimal]] = None
    buckets: List[ReceivableBucket] = field(default_factory=list)


@dataclass
class BucketResult:
    bucket: str
    exposure: Decimal
    pd_pct: Decimal
    lgd_pct: Decimal
    ecl_amount: Decimal
    coverage_pct: Decimal                # ecl / exposure


@dataclass
class EclResult:
    entity_name: str
    period_label: str
    total_exposure: Decimal
    total_ecl: Decimal
    overall_coverage_pct: Decimal
    buckets: List[BucketResult]
    currency: str
    warnings: list[str] = field(default_factory=list)


def compute_ecl(inp: EclInput) -> EclResult:
    if not inp.buckets:
        raise ValueError("buckets is required")

    warnings: list[str] = []
    matrix = dict(DEFAULT_PD_MATRIX)
    if inp.custom_pd_matrix:
        for k, v in inp.custom_pd_matrix.items():
            if k not in DEFAULT_PD_MATRIX:
                raise ValueError(f"Unknown aging bucket {k!r}")
            matrix[k] = Decimal(str(v))

    seen = set()
    total_exp = Decimal("0")
    total_ecl = Decimal("0")
    results: List[BucketResult] = []

    for i, b in enumerate(inp.buckets, start=1):
        if b.bucket not in DEFAULT_PD_MATRIX:
            raise ValueError(f"bucket {i}: unknown aging {b.bucket!r}")
        if b.bucket in seen:
            raise ValueError(f"bucket {i}: duplicate {b.bucket!r}")
        seen.add(b.bucket)
        exp = Decimal(str(b.exposure))
        if exp < 0:
            raise ValueError(f"bucket {i}: exposure cannot be negative")

        pd_pct = Decimal(str(b.pd_override_pct)) if b.pd_override_pct is not None \
            else matrix[b.bucket]
        lgd = Decimal(str(b.lgd_pct))
        if pd_pct < 0 or pd_pct > 100:
            raise ValueError(f"bucket {i}: PD must be 0-100")
        if lgd < 0 or lgd > 100:
            raise ValueError(f"bucket {i}: LGD must be 0-100")

        ecl = exp * pd_pct / Decimal("100") * lgd / Decimal("100")
        coverage = Decimal("0") if exp == 0 else (ecl / exp * Decimal("100"))

        results.append(BucketResult(
            bucket=b.bucket,
            exposure=_q(exp),
            pd_pct=_q(pd_pct),
            lgd_pct=_q(lgd),
            ecl_amount=_q(ecl),
            coverage_pct=_q(coverage),
        ))
        total_exp += exp
        total_ecl += ecl

    overall = Decimal("0") if total_exp == 0 else (total_ecl / total_exp * Decimal("100"))

    if overall > Decimal("25"):
        warnings.append(
            f"تغطية ECL مرتفعة ({_q(overall)}%) — راجع جودة المحفظة الائتمانية."
        )

    # Highlight aged buckets
    aged = Decimal("0")
    for r in results:
        if r.bucket in ("181_365", "over_365"):
            aged += r.exposure
    if total_exp > 0 and aged / total_exp > Decimal("0.2"):
        warnings.append(
            f"أكثر من 20% من الذمم أقدم من 180 يوماً — تعزيز الجباية مطلوب."
        )

    return EclResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        total_exposure=_q(total_exp),
        total_ecl=_q(total_ecl),
        overall_coverage_pct=_q(overall),
        buckets=results,
        currency=inp.currency,
        warnings=warnings,
    )


def to_dict(r: EclResult) -> dict:
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "total_exposure": f"{r.total_exposure}",
        "total_ecl": f"{r.total_ecl}",
        "overall_coverage_pct": f"{r.overall_coverage_pct}",
        "buckets": [
            {
                "bucket": b.bucket,
                "exposure": f"{b.exposure}",
                "pd_pct": f"{b.pd_pct}",
                "lgd_pct": f"{b.lgd_pct}",
                "ecl_amount": f"{b.ecl_amount}",
                "coverage_pct": f"{b.coverage_pct}",
            }
            for b in r.buckets
        ],
        "currency": r.currency,
        "warnings": r.warnings,
    }
