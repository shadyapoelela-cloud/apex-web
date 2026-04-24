"""Audit workflow primitives — Benford's Law, JE sampling, workpapers.

Three forensic/audit tools that own the "Saudi Big-4 accountant" seat
that existing Arabic platforms don't offer:

  • Benford's Law analysis — first-digit frequency test over journal
    amounts. Deviations flag possible fabrication or data quality issues.
  • JE sample puller — pulls a statistically-defensible sample of
    journal entries for SOX-style walkthrough testing. Deterministic
    seed so the same sample can be re-pulled for auditor re-performance.
  • Workpaper template generator — renders the IFRS/SOCPA-standard
    KAM workpaper skeleton (objective, risk, procedure, conclusion).

Each helper is a pure function. HTTP endpoints wrap them in app/ai/routes.
"""

from __future__ import annotations

import hashlib
import logging
import math
from dataclasses import dataclass, asdict
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Optional

logger = logging.getLogger(__name__)


# ── Benford's Law ────────────────────────────────────────


# Expected first-digit frequencies per Benford.
BENFORD_EXPECTED: dict[int, float] = {d: math.log10(1 + 1/d) for d in range(1, 10)}


def _first_digit(amount: float) -> Optional[int]:
    """Leading non-zero digit. 0, None, or negatives → None."""
    if amount is None:
        return None
    a = abs(float(amount))
    if a == 0 or math.isnan(a) or math.isinf(a):
        return None
    while a < 1:
        a *= 10
    while a >= 10:
        a /= 10
    d = int(a)
    if d < 1 or d > 9:
        return None
    return d


@dataclass
class BenfordRow:
    digit: int
    expected_pct: float     # Benford's expected frequency (%)
    observed_pct: float     # Observed frequency in the sample (%)
    expected_count: float
    observed_count: int
    deviation_pct: float    # observed - expected (%)


@dataclass
class BenfordResult:
    sample_size: int
    chi_squared: float
    chi_squared_critical_95: float   # 15.51 for 8 df
    passes_95: bool                   # True = consistent with Benford
    rows: list[BenfordRow]
    flagged_digits: list[int]         # digits with |deviation| > 2 pct pts

    def to_dict(self) -> dict[str, Any]:
        return {
            "sample_size": self.sample_size,
            "chi_squared": round(self.chi_squared, 3),
            "chi_squared_critical_95": self.chi_squared_critical_95,
            "passes_95": self.passes_95,
            "rows": [asdict(r) for r in self.rows],
            "flagged_digits": self.flagged_digits,
        }


def benford_analyze(amounts: list[float]) -> BenfordResult:
    """Run first-digit Benford test on a list of amounts.

    Skips zeros / negatives / non-numeric. Produces chi-squared against
    Benford's theoretical distribution + flags digits where observed
    frequency deviates > 2 percentage points from expected.
    """
    observed: dict[int, int] = {d: 0 for d in range(1, 10)}
    n = 0
    for a in amounts:
        d = _first_digit(a)
        if d is None:
            continue
        observed[d] += 1
        n += 1

    rows: list[BenfordRow] = []
    chi_sq = 0.0
    flagged: list[int] = []
    for d in range(1, 10):
        exp_pct = BENFORD_EXPECTED[d] * 100
        exp_count = BENFORD_EXPECTED[d] * n
        obs_pct = (observed[d] / n * 100) if n else 0
        dev = obs_pct - exp_pct
        if abs(dev) > 2:
            flagged.append(d)
        if exp_count > 0:
            chi_sq += ((observed[d] - exp_count) ** 2) / exp_count
        rows.append(BenfordRow(
            digit=d,
            expected_pct=round(exp_pct, 2),
            observed_pct=round(obs_pct, 2),
            expected_count=round(exp_count, 1),
            observed_count=observed[d],
            deviation_pct=round(dev, 2),
        ))

    return BenfordResult(
        sample_size=n,
        chi_squared=chi_sq,
        chi_squared_critical_95=15.51,   # 8 df, 95% confidence
        passes_95=chi_sq < 15.51,
        rows=rows,
        flagged_digits=flagged,
    )


def benford_on_journal_entries(
    tenant_id: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
) -> BenfordResult:
    """Pull journal-line amounts within a window and run Benford on them.

    Defensive: returns an empty result when the pilot tables aren't
    loaded or nothing matches the window.
    """
    amounts: list[float] = []
    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import JournalLine, JournalEntry
        db = SessionLocal()
        try:
            q = db.query(JournalLine.functional_debit, JournalLine.functional_credit)
            if start_date or end_date or tenant_id:
                q = q.join(JournalEntry, JournalLine.journal_entry_id == JournalEntry.id)
                if start_date:
                    q = q.filter(JournalEntry.je_date >= start_date)
                if end_date:
                    q = q.filter(JournalEntry.je_date <= end_date)
                if tenant_id:
                    q = q.filter(JournalLine.tenant_id == tenant_id)
            for d, c in q.limit(50_000).all():
                if d and float(d) > 0:
                    amounts.append(float(d))
                elif c and float(c) > 0:
                    amounts.append(float(c))
        finally:
            db.close()
    except Exception as e:
        logger.debug("benford_on_journal_entries: ledger unavailable (%s)", e)

    return benford_analyze(amounts)


# ── JE sampling ──────────────────────────────────────────


@dataclass
class SampledJournalEntry:
    je_id: str
    je_number: str
    je_date: str
    total: float
    memo: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def sample_journal_entries(
    *,
    tenant_id: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    sample_size: int = 25,
    threshold_amount: float = 10_000,
    seed: str = "apex-audit-2026",
) -> list[dict[str, Any]]:
    """Pull a deterministic sample for auditor walkthrough testing.

    Strategy (SOX-standard stratified):
      • ALL entries above `threshold_amount` (key items)
      • Plus a random subset up to `sample_size` of below-threshold
        entries — random is seeded so re-running gives the same sample
        (lets the auditor re-perform the work deterministically).
    """
    sampled: list[SampledJournalEntry] = []
    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import JournalEntry
        db = SessionLocal()
        try:
            q = db.query(JournalEntry)
            if start_date:
                q = q.filter(JournalEntry.je_date >= start_date)
            if end_date:
                q = q.filter(JournalEntry.je_date <= end_date)
            if tenant_id:
                q = q.filter(JournalEntry.tenant_id == tenant_id)
            rows = q.limit(20_000).all()
        finally:
            db.close()
    except Exception as e:
        logger.debug("sample_journal_entries: ledger unavailable (%s)", e)
        return []

    # Key items.
    above: list = []
    below: list = []
    for r in rows:
        total = float(r.total_debit or 0)
        if total >= threshold_amount:
            above.append(r)
        else:
            below.append(r)

    # Seeded pseudo-random pick from `below`.
    below_sorted = sorted(below, key=lambda r: hashlib.md5(f"{seed}:{r.id}".encode()).hexdigest())
    random_pick = below_sorted[: max(0, sample_size - len(above))]

    for r in above + random_pick:
        je_date = r.je_date
        if hasattr(je_date, "isoformat"):
            je_date = je_date.isoformat()
        sampled.append(SampledJournalEntry(
            je_id=r.id,
            je_number=r.je_number,
            je_date=str(je_date),
            total=float(r.total_debit or 0),
            memo=r.memo_ar or "",
        ))
    return [s.to_dict() for s in sampled]


# ── Workpaper template ───────────────────────────────────


WORKPAPER_TEMPLATES: dict[str, dict[str, Any]] = {
    "revenue_recognition": {
        "id": "revenue_recognition",
        "name_ar": "الاعتراف بالإيراد (IFRS 15)",
        "objective_ar": "التأكد من تطبيق الـ 5-step model لإيرادات الفترة",
        "risks_ar": [
            "تسجيل إيراد قبل نقل السيطرة",
            "أسعار معاملات متغيّرة غير مُحتسبة",
            "عقود متعددة الأداء دون تخصيص ثمن",
        ],
        "procedures_ar": [
            "اختيار عينة إيرادات الربع (>25 قيد)",
            "مطابقة كل إيراد بالعقد الأصلي + أمر البيع",
            "التحقق من توقيت نقل السيطرة (تسليم / قبول)",
            "إعادة حساب تخصيص الثمن للأداءات المتعددة",
        ],
    },
    "cutoff_testing": {
        "id": "cutoff_testing",
        "name_ar": "اختبار القطع الشهري / السنوي",
        "objective_ar": "التأكد من تسجيل المعاملات في الفترة الصحيحة",
        "risks_ar": [
            "تحريك إيراد ديسمبر إلى يناير",
            "تأخير تسجيل مصروفات يناير ليناير تالي",
        ],
        "procedures_ar": [
            "آخر 10 فواتير قبل نهاية الفترة + أول 10 بعدها",
            "مطابقة تاريخ الفاتورة بتاريخ تسليم البضاعة",
            "فحص قيود اليومية اليدوية في آخر 3 أيام من الفترة",
        ],
    },
    "je_testing": {
        "id": "je_testing",
        "name_ar": "اختبار قيود اليومية (SAS 99 / ISA 240)",
        "objective_ar": "كشف قيود غير مشروعة قد تشير إلى احتيال إداري",
        "risks_ar": [
            "قيود يدوية في نهاية الفترة",
            "قيود تتجاوز حسابات الرقابة (AR / AP control)",
            "قيود توصل إلى أرقام دائرية (Round numbers)",
        ],
        "procedures_ar": [
            "تصفية قيود >=100,000 ريال خلال آخر 5 أيام",
            "تصفية قيود بأرقام مدورة إلى الآلاف",
            "Benford's Law على مجموع القيود",
            "تصفية قيود تسجّل عكس الـ normal balance للحساب",
        ],
    },
    "bank_reconciliation_review": {
        "id": "bank_reconciliation_review",
        "name_ar": "مراجعة التسويات البنكية",
        "objective_ar": "التأكد من صحة أرصدة البنوك ووجود دورة مراجعة شهرية",
        "risks_ar": [
            "تسويات قديمة لم تُختتم",
            "عناصر مُسوّاة متكررة بنفس القيمة",
        ],
        "procedures_ar": [
            "سحب آخر 3 تسويات شهرية لكل حساب بنكي",
            "التحقق من اعتماد مسؤول غير مُعدّ التسوية",
            "فحص عناصر خارج الفترة (>30 يوم)",
        ],
    },
}


def list_workpapers() -> list[dict[str, Any]]:
    return [
        {"id": t["id"], "name_ar": t["name_ar"], "objective_ar": t["objective_ar"]}
        for t in WORKPAPER_TEMPLATES.values()
    ]


def get_workpaper(template_id: str) -> Optional[dict[str, Any]]:
    return WORKPAPER_TEMPLATES.get(template_id)
