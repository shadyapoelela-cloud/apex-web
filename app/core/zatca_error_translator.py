"""
APEX — ZATCA Fatoora error translator (Wave 2 PR#4).

Pattern #184 from APEX_GLOBAL_RESEARCH_210:
"Human-readable rejection translator (map schema 301 → 'Seller VAT missing'
بالعربية) — أكبر UX win للمحاسبين".

ZATCA Clearance and Reporting endpoints return rejection payloads shaped
roughly like:

    {
      "validationResults": {
        "errorMessages": [
          {"code": "BR-KSA-01", "message": "Seller VAT Number is missing"},
          ...
        ],
        "warningMessages": [...]
      },
      "clearanceStatus": "NOT_CLEARED"
    }

The error messages are English-only and often reference XSD rule ids
that don't mean anything to a Saudi accountant. This module:

- Maintains a curated catalog of Arabic translations for the most
  common BR-KSA-* codes + a handful of generic codes.
- Falls back to a rule-based heuristic when the exact code is unknown,
  pulling keywords out of the English message.
- Provides `translate_rejection(payload)` that returns a canonical,
  bilingual, actionable summary the Flutter UI can render directly.

No side effects. Pure function on pure dicts.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

# Curated map of ZATCA BR-KSA-* rule ids to Arabic explanations.
# Keep this list short and actionable — prefer "what the accountant
# must do" over "which XSD rule failed". Coverage is the top 30-40
# rules that account for >90% of real-world rejections.
_KNOWN_CODES: Dict[str, Dict[str, str]] = {
    # ── Seller identity ──
    "BR-KSA-01": {
        "category": "seller_identity",
        "title_ar": "رقم الضريبة للبائع مفقود أو غير صحيح",
        "action_ar": "تحقّق من رقم الضريبة للمنشأة في الإعدادات (15 رقمًا يبدأ بـ 3).",
    },
    "BR-KSA-02": {
        "category": "seller_identity",
        "title_ar": "اسم المنشأة البائعة غير متطابق مع سجل الهيئة",
        "action_ar": "حدّث اسم المنشأة في شاشة الإعدادات ليطابق الاسم المسجل في ZATCA.",
    },
    "BR-KSA-03": {
        "category": "seller_identity",
        "title_ar": "عنوان المنشأة البائعة مفقود أو ناقص",
        "action_ar": "أضف المدينة، الحي، ورقم المبنى في بيانات المنشأة.",
    },
    # ── Buyer identity ──
    "BR-KSA-24": {
        "category": "buyer_identity",
        "title_ar": "رقم الضريبة للمشتري مفقود (مطلوب للفاتورة الضريبية B2B)",
        "action_ar": "أدخل رقم الضريبة للعميل، أو حوّل الفاتورة إلى مبسّطة (B2C) إن كانت قيمتها دون 1,000 ر.س.",
    },
    "BR-KSA-25": {
        "category": "buyer_identity",
        "title_ar": "عنوان المشتري مفقود في فاتورة B2B",
        "action_ar": "حدّث بيانات العنوان في بطاقة العميل قبل إعادة الإرسال.",
    },
    # ── Invoice totals / math ──
    "BR-KSA-30": {
        "category": "math",
        "title_ar": "مجموع الفاتورة لا يطابق مجاميع البنود",
        "action_ar": "راجع أسعار البنود، الخصومات، والشحن — هناك فارق في التدوير غالبًا.",
    },
    "BR-KSA-31": {
        "category": "math",
        "title_ar": "مبلغ الضريبة المحتسب لا يطابق نسبة الضريبة × الصافي",
        "action_ar": "أعد حساب الضريبة أو تأكد أن نسبة VAT الصحيحة مطبقة (15% للسلع العادية، 0% للصحة/التعليم).",
    },
    # ── Timing / dates ──
    "BR-KSA-15": {
        "category": "timing",
        "title_ar": "تاريخ الإصدار خارج المدى المسموح",
        "action_ar": "تاريخ الفاتورة يجب أن يكون اليوم أو أمس (لا فواتير مؤرخة في المستقبل أو قبل أكثر من 24 ساعة).",
    },
    # ── Line items ──
    "BR-KSA-40": {
        "category": "line_item",
        "title_ar": "وصف أحد البنود فارغ",
        "action_ar": "أضف وصفًا معنويًا لكل بند — 'خدمات' أو 'بند 1' غير كافٍ.",
    },
    "BR-KSA-41": {
        "category": "line_item",
        "title_ar": "كمية أو سعر أحد البنود صفر أو سالب",
        "action_ar": "راجع البنود — الكمية والسعر يجب أن يكونا أكبر من صفر.",
    },
    # ── QR / signature ──
    "BR-KSA-50": {
        "category": "cryptography",
        "title_ar": "رمز QR مفقود أو غير صالح",
        "action_ar": "هذا خلل فني في توليد الـ QR — تواصل مع الدعم الفني لـ APEX.",
    },
    "BR-KSA-51": {
        "category": "cryptography",
        "title_ar": "الختم الرقمي (cryptographic stamp) مفقود",
        "action_ar": "تحقّق من صلاحية شهادة CSID في صفحة الإعدادات → ZATCA.",
    },
    # ── Previous Invoice Hash (PIH) chain ──
    "BR-KSA-61": {
        "category": "chain",
        "title_ar": "تسلسل الفواتير (PIH) منكسر",
        "action_ar": "فاتورة سابقة رُفضت أو حُذفت — تحقق من آخر فاتورة ناجحة في سجل الإرسال.",
    },
    # ── Generic HTTP / transport ──
    "UNAUTHORIZED": {
        "category": "auth",
        "title_ar": "الشهادة (CSID) غير مقبولة من ZATCA",
        "action_ar": "تحقّق من تاريخ انتهاء الشهادة — قد تحتاج إلى تجديد CSID في بوابة Fatoora.",
    },
    "RATE_LIMIT": {
        "category": "transport",
        "title_ar": "تم تجاوز عدد المحاولات المسموح خلال دقيقة",
        "action_ar": "سيعيد APEX المحاولة تلقائيًا خلال دقيقة — لا تتصرف.",
    },
    "TIMEOUT": {
        "category": "transport",
        "title_ar": "تأخر رد بوابة Fatoora",
        "action_ar": "الفاتورة محفوظة في قائمة الإعادة، سيتم إرسالها تلقائيًا عند استقرار البوابة.",
    },
}

# Keyword-based heuristic for codes we haven't curated yet.
# Each tuple: (regex, Arabic title, Arabic action). Order matters —
# first match wins. Matching is case-insensitive on the English message.
_HEURISTIC: List[tuple] = [
    (
        re.compile(r"seller.*vat", re.I),
        "حقل ضريبي خاص بالبائع يحتاج مراجعة",
        "افتح بيانات المنشأة وتحقّق من رقم الضريبة + العنوان الكامل.",
    ),
    (
        re.compile(r"buyer.*vat", re.I),
        "حقل ضريبي خاص بالمشتري يحتاج مراجعة",
        "حدّث بطاقة العميل ثم أعد إرسال الفاتورة.",
    ),
    (
        re.compile(r"invoice.*total|total.*invoice|sum.*mismatch", re.I),
        "عدم تطابق في مجموع الفاتورة",
        "راجع البنود/الخصومات — فارق تدوير محتمل.",
    ),
    (
        re.compile(r"certificate|csid|stamp|signature", re.I),
        "مشكلة في الشهادة أو التوقيع الرقمي",
        "انتقل إلى الإعدادات → ZATCA وتحقّق من صلاحية الـ CSID.",
    ),
    (
        re.compile(r"date|timing", re.I),
        "التاريخ خارج المدى المسموح",
        "تاريخ الفاتورة يجب أن يكون اليوم أو أمس.",
    ),
    (
        re.compile(r"qr", re.I),
        "رمز QR غير صالح",
        "خلل فني — تواصل مع الدعم.",
    ),
]


@dataclass
class TranslatedRejection:
    """Canonical form the UI renders. Always bilingual."""

    code: str
    category: str
    title_ar: str
    action_ar: str
    original_message: str
    severity: str = "error"  # "error" | "warning"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "code": self.code,
            "category": self.category,
            "title_ar": self.title_ar,
            "action_ar": self.action_ar,
            "original_message": self.original_message,
            "severity": self.severity,
        }


@dataclass
class RejectionSummary:
    cleared: bool
    errors: List[TranslatedRejection] = field(default_factory=list)
    warnings: List[TranslatedRejection] = field(default_factory=list)
    # Short one-line Arabic status for list views.
    headline_ar: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "cleared": self.cleared,
            "errors": [e.to_dict() for e in self.errors],
            "warnings": [w.to_dict() for w in self.warnings],
            "headline_ar": self.headline_ar,
        }


def translate_error(
    code: Optional[str], message: Optional[str], *, severity: str = "error"
) -> TranslatedRejection:
    """Translate a single ZATCA error entry to its Arabic form."""
    normalized_code = (code or "UNKNOWN").strip().upper()
    msg = (message or "").strip()

    curated = _KNOWN_CODES.get(normalized_code)
    if curated:
        return TranslatedRejection(
            code=normalized_code,
            category=curated["category"],
            title_ar=curated["title_ar"],
            action_ar=curated["action_ar"],
            original_message=msg,
            severity=severity,
        )

    # Heuristic path — try to help even when the code is unknown.
    for pattern, title, action in _HEURISTIC:
        if pattern.search(msg):
            return TranslatedRejection(
                code=normalized_code,
                category="heuristic",
                title_ar=title,
                action_ar=action,
                original_message=msg,
                severity=severity,
            )

    # Last resort: generic message that at least tells the user to
    # copy the English text to the support team.
    return TranslatedRejection(
        code=normalized_code,
        category="unknown",
        title_ar="رفض غير معروف من ZATCA",
        action_ar="انسخ رسالة الخطأ الإنجليزية أدناه وأرسلها للدعم الفني — لم نضف ترجمة لهذا الرمز بعد.",
        original_message=msg,
        severity=severity,
    )


def translate_rejection(payload: Dict[str, Any]) -> RejectionSummary:
    """Translate a full ZATCA rejection payload to the UI-ready summary.

    Accepts several shapes:
      {"validationResults": {"errorMessages": [...], "warningMessages": [...]}}
      {"errors": [...], "warnings": [...]}
      {"errorCode": "...", "errorMessage": "..."}  (single-error shape)

    Silently ignores unknown fields rather than raising — this runs in
    the hot path of every ZATCA submission response.
    """
    errors: List[TranslatedRejection] = []
    warnings: List[TranslatedRejection] = []

    vr = payload.get("validationResults") or {}
    for entry in (vr.get("errorMessages") or payload.get("errors") or []):
        if isinstance(entry, dict):
            errors.append(
                translate_error(
                    entry.get("code") or entry.get("errorCode"),
                    entry.get("message") or entry.get("errorMessage"),
                    severity="error",
                )
            )
    for entry in (vr.get("warningMessages") or payload.get("warnings") or []):
        if isinstance(entry, dict):
            warnings.append(
                translate_error(
                    entry.get("code") or entry.get("errorCode"),
                    entry.get("message") or entry.get("errorMessage"),
                    severity="warning",
                )
            )

    # Single-error flat shape fallback.
    if not errors and not warnings:
        code = payload.get("errorCode") or payload.get("code")
        msg = payload.get("errorMessage") or payload.get("message")
        if code or msg:
            errors.append(translate_error(code, msg, severity="error"))

    cleared = str(payload.get("clearanceStatus") or "").upper() in ("CLEARED", "OK")
    cleared = cleared and not errors  # errors always block clearance

    if cleared and not errors and not warnings:
        headline = "تم قبول الفاتورة من ZATCA بدون ملاحظات."
    elif cleared and warnings:
        headline = f"تم القبول مع {len(warnings)} ملاحظة/تحذير."
    elif errors:
        headline = f"رُفضت الفاتورة — {len(errors)} خطأ يحتاج إصلاح."
    else:
        headline = "حالة الإرسال غير واضحة — راجع السجل الكامل."

    return RejectionSummary(
        cleared=cleared,
        errors=errors,
        warnings=warnings,
        headline_ar=headline,
    )


def explain_code(code: str) -> Dict[str, Any]:
    """Look up a code in the curated catalog. Used by the
    /compliance/zatca/explain-error?code=... endpoint the UI calls
    when a user clicks "ما معنى هذا الرمز؟" on a rejection."""
    normalized = code.strip().upper()
    entry = _KNOWN_CODES.get(normalized)
    if entry:
        return {
            "code": normalized,
            "known": True,
            "category": entry["category"],
            "title_ar": entry["title_ar"],
            "action_ar": entry["action_ar"],
        }
    return {
        "code": normalized,
        "known": False,
        "category": "unknown",
        "title_ar": "رمز غير مُترجم بعد",
        "action_ar": "الرجاء مشاركة هذا الرمز مع الدعم الفني لإضافته إلى قاموس APEX.",
    }
