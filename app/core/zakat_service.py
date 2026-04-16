"""
APEX Platform — Zakat Calculator (Saudi Arabia ZATCA)
═══════════════════════════════════════════════════════════════
Computes the Zakat base and liability per KSA ZATCA (Zakat, Tax &
Customs Authority) rules for commercial entities.

NOTE: Zakat in KSA is assessed on the "Zakat base" = the greater of:
  (A) Adjusted net profit, OR
  (B) The "zakatable assets" formula, which broadly is:

      equity + provisions + non-current liabilities (subject)
      MINUS
      non-current & non-zakatable assets (fixed assets, LT investments,
      accumulated losses, intangibles, deferred tax assets, etc.)

The Zakat rate for a full hijri year is 2.5% (Gregorian year: 2.5770%
— but ZATCA practically uses 2.5% on a Gregorian basis for filings).
We expose the rate as a parameter so Shari'a-strict callers can apply
2.5770% if they prefer.

This module intentionally keeps the math as transparent data — callers
supply a ZakatInput dataclass, and we return ZakatResult with an audit
trail of additions/deductions so the output is explainable end-to-end.

References:
  • ZATCA Zakat Implementing Regulations (Royal Decree M/153, 2019)
  • ZATCA Zakat Manual v2.1
  • GAZT Circulars on financial institutions (separate rules apply)
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


@dataclass
class ZakatInput:
    """
    Inputs needed to compute the Zakat base. All amounts in SAR
    (or homogeneous currency — the rate is applied in the same unit).

    Organised as: additions to the base (equity side) minus deductions
    (non-zakatable long-term assets).
    """

    # ── Additions (equity + long-term obligations to be included) ──
    capital: Decimal = Decimal("0")                  # paid-up capital
    retained_earnings: Decimal = Decimal("0")        # accumulated profits
    statutory_reserve: Decimal = Decimal("0")
    other_reserves: Decimal = Decimal("0")
    provisions: Decimal = Decimal("0")               # general provisions
    long_term_liabilities: Decimal = Decimal("0")    # LT loans, lease obligations
    shareholder_loans: Decimal = Decimal("0")        # classed as LT
    adjusted_net_profit: Decimal = Decimal("0")      # for the "floor" test (A)

    # ── Deductions (non-zakatable LT assets — removed from base) ──
    net_fixed_assets: Decimal = Decimal("0")         # property, plant, equipment (net)
    intangible_assets: Decimal = Decimal("0")        # goodwill, patents (net)
    long_term_investments: Decimal = Decimal("0")    # non-trading investments
    accumulated_losses: Decimal = Decimal("0")       # treated as deduction from equity
    deferred_tax_assets: Decimal = Decimal("0")
    capital_work_in_progress: Decimal = Decimal("0")

    # ── Meta ──
    period_label: str = "FY"           # e.g. "2026-FY"
    hijri_year: Optional[str] = None   # e.g. "1447"
    rate: Decimal = Decimal("0.025")   # 2.5% — pass Decimal("0.025770") for Hijri-strict


@dataclass
class ZakatLine:
    """Single line in the audit trail — kind='add' or 'deduct'."""
    kind: str            # 'add' | 'deduct'
    label_ar: str
    label_en: str
    amount: Decimal


@dataclass
class ZakatResult:
    period_label: str
    hijri_year: Optional[str]
    rate_pct: Decimal                        # stored as percent, e.g. 2.50
    additions_total: Decimal
    deductions_total: Decimal
    zakat_base: Decimal                      # max(adjusted_profit, additions - deductions)
    zakat_due: Decimal                       # zakat_base * rate
    lines: list[ZakatLine] = field(default_factory=list)
    used_floor: bool = False                 # True if adjusted_profit was the base
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Core calculation
# ═══════════════════════════════════════════════════════════════


def compute_zakat(inp: ZakatInput) -> ZakatResult:
    """
    Transparent Zakat calculation returning a full audit trail.

    Algorithm (ZATCA general framework):
      1. Sum all additions (equity + reserves + provisions + LT liabilities).
      2. Sum all deductions (non-zakatable LT assets).
      3. Formula-B base = additions - deductions (floor at 0).
      4. Formula-A base = adjusted_net_profit (floor at 0).
      5. Final zakat_base = max(A, B). If A > B we mark used_floor=True.
      6. zakat_due = base * rate.
    """
    lines: list[ZakatLine] = []
    warnings: list[str] = []

    # ── Additions ────────────────────────────────────────────────
    add_pairs = [
        (_q(inp.capital), "رأس المال", "Capital"),
        (_q(inp.retained_earnings), "الأرباح المرحلة", "Retained earnings"),
        (_q(inp.statutory_reserve), "الاحتياطي النظامي", "Statutory reserve"),
        (_q(inp.other_reserves), "احتياطيات أخرى", "Other reserves"),
        (_q(inp.provisions), "المخصصات العامة", "General provisions"),
        (_q(inp.long_term_liabilities), "الالتزامات طويلة الأجل", "Long-term liabilities"),
        (_q(inp.shareholder_loans), "قروض المساهمين", "Shareholder loans"),
    ]
    additions_total = Decimal("0")
    for amt, ar, en in add_pairs:
        if amt != 0:
            lines.append(ZakatLine(kind="add", label_ar=ar, label_en=en, amount=amt))
            additions_total += amt

    # ── Deductions ──────────────────────────────────────────────
    ded_pairs = [
        (_q(inp.net_fixed_assets), "الأصول الثابتة (صافي)", "Net fixed assets"),
        (_q(inp.intangible_assets), "الأصول غير الملموسة", "Intangible assets"),
        (_q(inp.long_term_investments), "استثمارات طويلة الأجل", "Long-term investments"),
        (_q(inp.accumulated_losses), "الخسائر المتراكمة", "Accumulated losses"),
        (_q(inp.deferred_tax_assets), "أصول ضريبية مؤجلة", "Deferred tax assets"),
        (_q(inp.capital_work_in_progress), "مشاريع تحت الإنشاء", "Capital work in progress"),
    ]
    deductions_total = Decimal("0")
    for amt, ar, en in ded_pairs:
        if amt != 0:
            lines.append(ZakatLine(kind="deduct", label_ar=ar, label_en=en, amount=amt))
            deductions_total += amt

    # ── Base via formula B (zakatable assets) ────────────────────
    base_b = additions_total - deductions_total
    if base_b < 0:
        warnings.append(
            "صافي قاعدة الزكاة بالصيغة (ب) سالب — يُحتمل أن الخصومات تتجاوز الإضافات. "
            "سيُعتمد الحد الأدنى (صفر)."
        )
        base_b = Decimal("0")

    # ── Base via formula A (adjusted net profit floor) ───────────
    base_a = _q(inp.adjusted_net_profit)
    if base_a < 0:
        base_a = Decimal("0")

    used_floor = base_a > base_b
    zakat_base = max(base_a, base_b)

    # ── Rate validation ──────────────────────────────────────────
    rate = inp.rate
    if rate <= 0 or rate >= 1:
        raise ValueError(f"Invalid Zakat rate: {rate}. Must be 0 < rate < 1 (e.g. 0.025)")
    rate_pct = (rate * 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

    zakat_due = (zakat_base * rate).quantize(_TWO, rounding=ROUND_HALF_UP)

    return ZakatResult(
        period_label=inp.period_label,
        hijri_year=inp.hijri_year,
        rate_pct=rate_pct,
        additions_total=_q(additions_total),
        deductions_total=_q(deductions_total),
        zakat_base=_q(zakat_base),
        zakat_due=zakat_due,
        lines=lines,
        used_floor=used_floor,
        warnings=warnings,
    )


def result_to_dict(r: ZakatResult) -> dict:
    """JSON-ready view of a ZakatResult (Decimals as strings)."""
    return {
        "period_label": r.period_label,
        "hijri_year": r.hijri_year,
        "rate_pct": f"{r.rate_pct}",
        "additions_total": f"{r.additions_total}",
        "deductions_total": f"{r.deductions_total}",
        "zakat_base": f"{r.zakat_base}",
        "zakat_due": f"{r.zakat_due}",
        "used_floor": r.used_floor,
        "lines": [
            {
                "kind": line.kind,
                "label_ar": line.label_ar,
                "label_en": line.label_en,
                "amount": f"{line.amount}",
            }
            for line in r.lines
        ],
        "warnings": r.warnings,
    }
