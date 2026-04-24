"""Regulatory news feed — Bloomberg-style ticker of ZATCA / SAMA /
FTA / ETA announcements that affect the tenant's books.

The feed is seeded with the known wave deadlines, circulars, and
"effective as of" dates relevant to APEX's target markets (KSA / UAE /
Egypt). Each item has:

  • kind        — "wave" | "circular" | "rate_change" | "deadline"
  • authority   — "ZATCA" | "SAMA" | "FTA_AE" | "ETA_EG" | "CBB" | ...
  • title_ar    — Arabic headline
  • body_ar     — 1-3 line summary
  • effective_date — when it takes effect (ISO)
  • impact_ar   — one-line Arabic "what this means for your books"
  • link        — official source URL

When connected to a live scraper (future work), this module becomes the
caching layer. For now it's a static curated list so the UI has
something real to render — the Bloomberg ticker at the bottom of every
admin screen can't be empty on day one.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from datetime import date
from typing import Any


@dataclass
class NewsItem:
    id: str
    kind: str
    authority: str
    jurisdiction: str       # "sa" | "ae" | "eg" | "om" | "bh" | "qa" | "kw"
    title_ar: str
    body_ar: str
    effective_date: str     # ISO date
    impact_ar: str
    severity: str           # "info" | "warning" | "error"
    link: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


# ── Curated seed feed ─────────────────────────────────────


_SEED: list[NewsItem] = [
    # ZATCA e-invoicing waves
    NewsItem(
        id="zatca_wave_23",
        kind="wave",
        authority="ZATCA",
        jurisdiction="sa",
        title_ar="ZATCA: الموجة 23 — مكلفون إيراداتهم > 750K ريال",
        body_ar="يدخل حيّز التنفيذ 31 مارس 2026 — أي منشأة تجاوزت إيراداتها 750 ألف ريال في أي من أعوام 2022-2024 ملزمة بربط نظام الفوترة الإلكترونية مع Fatoora.",
        effective_date="2026-03-31",
        impact_ar="إن كانت إيراداتك تتجاوز 750K ريال — تأكد من اكتمال ربط CSID قبل التاريخ.",
        severity="warning",
        link="https://zatca.gov.sa/en/E-Invoicing/Pages/default.aspx",
    ),
    NewsItem(
        id="zatca_wave_24",
        kind="wave",
        authority="ZATCA",
        jurisdiction="sa",
        title_ar="ZATCA: الموجة 24 — مكلفون 375K–750K ريال",
        body_ar="تبدأ 30 يونيو 2026 — المنشآت ضمن هذه الشريحة ملزمة بالمرحلة الثانية للفوترة.",
        effective_date="2026-06-30",
        impact_ar="اختر مزود حلول معتمد أو فعّل نظام APEX للفوترة قبل الاستحقاق بشهر على الأقل.",
        severity="info",
        link="https://zatca.gov.sa/en/E-Invoicing/Pages/default.aspx",
    ),
    # UAE
    NewsItem(
        id="uae_einvoice_2027",
        kind="deadline",
        authority="FTA_AE",
        jurisdiction="ae",
        title_ar="الإمارات: الفوترة الإلكترونية الإلزامية 1 يناير 2027",
        body_ar="تجريبي في يوليو 2026، ثم إلزامي للشركات ≥ 50 مليون درهم بداية 2027، وجميع الشركات بحلول يوليو 2027.",
        effective_date="2027-01-01",
        impact_ar="التكامل مع Peppol PINT-AE عبر مزود خدمة معتمد (ASP) — ابدأ التحضير الآن.",
        severity="info",
        link="https://mof.gov.ae/",
    ),
    NewsItem(
        id="uae_ct_2023",
        kind="rate_change",
        authority="FTA_AE",
        jurisdiction="ae",
        title_ar="ضريبة الشركات الإماراتية — 9% فوق 375K درهم",
        body_ar="سارية منذ 1 يونيو 2023. الإقرار خلال 9 أشهر من نهاية السنة المالية.",
        effective_date="2023-06-01",
        impact_ar="راجع توصيف النفقات (ترفيه 50%، فوائد مُقيّدة) قبل إعداد الإقرار.",
        severity="info",
        link="https://mof.gov.ae/corporate-tax/",
    ),
    # Egypt
    NewsItem(
        id="eg_vat_threshold_2026",
        kind="rate_change",
        authority="ETA_EG",
        jurisdiction="eg",
        title_ar="مصر: خفض حد تسجيل القيمة المضافة إلى 250K جنيه",
        body_ar="حد تسجيل VAT ينخفض إلى 250,000 جنيه خلال 2026 — سيضم آلاف المنشآت الصغيرة للنظام.",
        effective_date="2026-01-01",
        impact_ar="إذا تجاوزت إيراداتك 250K جنيه في أي 12 شهر متتالٍ — سجّل قبل فرض الغرامات.",
        severity="warning",
        link="https://www.eta.gov.eg/",
    ),
    NewsItem(
        id="eg_b2c_receipts_2025",
        kind="wave",
        authority="ETA_EG",
        jurisdiction="eg",
        title_ar="مصر: إلزامية الإيصال الإلكتروني B2C",
        body_ar="توسيع نظام الإيصال الإلكتروني ليشمل مبيعات التجزئة تدريجياً خلال 2025-2026.",
        effective_date="2026-01-01",
        impact_ar="كل نقاط البيع ملزمة بإصدار إيصال إلكتروني مُوقّع — التحقق من جاهزية POS.",
        severity="info",
        link="https://www.eta.gov.eg/",
    ),
    # Oman
    NewsItem(
        id="om_einvoice_2026",
        kind="wave",
        authority="OTA_OM",
        jurisdiction="om",
        title_ar="عُمان: بدء نظام الفوترة الإلكترونية Q3 2026",
        body_ar="هيئة الضرائب العُمانية تُطلق الفوترة الإلكترونية بعد مرحلة اختبار في Q2.",
        effective_date="2026-07-01",
        impact_ar="إذا كان لديك كيان في عُمان — تواصل مع مزود حلول معتمد لدى OTA.",
        severity="info",
        link="https://tms.taxoman.gov.om/",
    ),
    # SAMA
    NewsItem(
        id="sama_open_banking_2025",
        kind="circular",
        authority="SAMA",
        jurisdiction="sa",
        title_ar="SAMA: تعميم تفعيل الخدمات المصرفية المفتوحة (AISP)",
        body_ar="ساما تُتيح مزودي تجميع البيانات المصرفية AISP بترخيص — Tarabut / Lean من أوائل المرخّصين.",
        effective_date="2025-01-01",
        impact_ar="يمكن الآن ربط حسابات البنوك مباشرة بـ APEX عبر مزودين مرخّصين — لا مزيد من رفع CSV.",
        severity="info",
        link="https://www.sama.gov.sa/ar-sa/OpenBanking/Pages/default.aspx",
    ),
    # Bahrain / Qatar / Kuwait
    NewsItem(
        id="bh_vat_2019",
        kind="rate_change",
        authority="NBR_BH",
        jurisdiction="bh",
        title_ar="البحرين: ضريبة القيمة المضافة 10%",
        body_ar="سارية منذ يناير 2019 (زِيدت من 5% إلى 10% منذ يناير 2022).",
        effective_date="2022-01-01",
        impact_ar="كيانات البحرين تُقدّم إقرار ربع سنوي عبر بوابة NBR.",
        severity="info",
        link="https://www.nbr.gov.bh/",
    ),
]


# ── Public API ───────────────────────────────────────────


def list_news(
    *,
    jurisdiction: str | None = None,
    limit: int = 20,
    only_future: bool = False,
) -> list[dict[str, Any]]:
    """Return news items sorted by effective date (newest/soonest first).

    `only_future=True` filters to items whose effective date is today
    or later — useful for the "upcoming deadlines" widget.
    """
    today = date.today()
    items = list(_SEED)
    if jurisdiction:
        items = [i for i in items if i.jurisdiction == jurisdiction]
    if only_future:
        items = [i for i in items if date.fromisoformat(i.effective_date) >= today]
    items.sort(key=lambda i: i.effective_date, reverse=not only_future)
    return [i.to_dict() for i in items[:limit]]


def get_news(item_id: str) -> dict[str, Any] | None:
    for i in _SEED:
        if i.id == item_id:
            return i.to_dict()
    return None
