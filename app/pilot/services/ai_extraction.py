"""AI-powered document extraction service.

يقرأ مستنداً (فاتورة/إيصال/كشف حساب بنكي) بالصورة أو PDF عبر Claude Vision،
ثم يُرجِع اقتراح قيد يومية متوازن مع مطابقة الحسابات من شجرة الحسابات (CoA).

الاستخدام:
    from app.pilot.services.ai_extraction import extract_je_from_document
    result = extract_je_from_document(
        db, entity=e, file_base64="...", media_type="image/jpeg",
    )

المخرجات:
    {
        "success": True,
        "document_type": "invoice|receipt|bank_statement|unknown",
        "confidence": 0.0-1.0,
        "suggested_kind": "manual|adjusting|...",
        "suggested_memo_ar": "...",
        "suggested_date": "YYYY-MM-DD",
        "suggested_lines": [
            {
                "account_id": "...",         # matched
                "account_hint": "...",        # what AI said
                "match_confidence": 0.0-1.0,
                "debit": "100.00",
                "credit": "0.00",
                "description": "...",
            },
            ...
        ],
        "warnings": ["..."],
        "raw_extraction": {...},              # what Claude returned, unfiltered
    }
"""

from __future__ import annotations

import json
import logging
import logging.handlers
import os
import re
import tempfile
import traceback
from decimal import Decimal, InvalidOperation
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.pilot.models import Entity, GLAccount

logger = logging.getLogger(__name__)

# Debug log file لتشخيص أخطاء استخراج الـ AI
_DEBUG_LOG = os.path.join(tempfile.gettempdir(), "apex_ai_extraction.log")
if not any(
    isinstance(h, logging.FileHandler) and getattr(h, "baseFilename", "") == _DEBUG_LOG
    for h in logger.handlers
):
    try:
        _fh = logging.handlers.RotatingFileHandler(
            _DEBUG_LOG, maxBytes=2_000_000, backupCount=2, encoding="utf-8"
        )
        _fh.setLevel(logging.DEBUG)
        _fh.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
        )
        logger.addHandler(_fh)
        logger.setLevel(logging.DEBUG)
        logger.info("AI extraction debug log initialized at %s", _DEBUG_LOG)
    except Exception:  # noqa: BLE001
        pass

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
AI_MODEL = os.environ.get("APEX_AI_MODEL", "claude-sonnet-4-20250514")

SUPPORTED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
SUPPORTED_PDF_TYPES = {"application/pdf"}
ALL_SUPPORTED = SUPPORTED_IMAGE_TYPES | SUPPORTED_PDF_TYPES

# Max payload: ~10MB base64 ≈ 7.5MB raw
MAX_B64_LENGTH = 10 * 1024 * 1024


EXTRACTION_SYSTEM_PROMPT = """أنت محاسب معتمد خبير يعمل داخل منصة APEX السعودية للمحاسبة.
مهمتك: قراءة مستند مالي (فاتورة/إيصال/كشف بنكي/سند قبض أو صرف) واستخراج قيد يومية متوازن بدقة.

قواعد حتمية:
1. التواريخ بصيغة YYYY-MM-DD فقط. إذا غير معروف، استخدم تاريخ اليوم.
2. المبالغ بصيغة رقمية عشرية (100.00) بدون فواصل آلاف وبدون رموز عملة.
3. كل قيد يجب أن يكون متوازناً: مجموع المدين = مجموع الدائن (بتسامح ± 0.01).
4. فرّق بين شامل الضريبة وغير شامل. احسب VAT 15% إذا كانت الفاتورة تظهر قيمة الضريبة.
5. لكل سطر اكتب `account_hint` بالعربية مصنّفاً بدقة (مثال: "مشتريات بضاعة"، "مصروف رسوم بنكية"، "الصندوق"، "الموردون - تحت الحساب"، "ضريبة قيمة مضافة مدخلة").
6. استخدم فقط أنواع الحسابات المعيارية السعودية (SOCPA).
7. إذا لم يكن المستند فاتورة/إيصال/معاملة مالية واضحة → أرجع `success: false` مع سبب.
8. لا تُضِف تعليقات خارج JSON. أول حرف في ردك يجب أن يكون `{` وآخره `}`.

الإخراج: JSON فقط بالصيغة التالية (بدون markdown fences):
{
  "success": true,
  "document_type": "invoice" | "receipt" | "bank_statement" | "payment_voucher" | "expense" | "unknown",
  "confidence": 0.85,
  "suggested_kind": "manual",
  "suggested_memo_ar": "فاتورة مشتريات من مورد X — رقم 123",
  "suggested_date": "2026-04-22",
  "currency": "SAR",
  "total_amount": "1150.00",
  "vat_amount": "150.00",
  "vendor_or_customer": "اسم المورد أو العميل إن وُجد",
  "document_number": "رقم الفاتورة/الإيصال إن وُجد",
  "suggested_lines": [
    {
      "account_hint": "مشتريات بضاعة",
      "debit": "1000.00",
      "credit": "0.00",
      "description": "قيمة البضاعة"
    },
    {
      "account_hint": "ضريبة قيمة مضافة مدخلة",
      "debit": "150.00",
      "credit": "0.00",
      "description": "VAT 15%"
    },
    {
      "account_hint": "الموردون",
      "debit": "0.00",
      "credit": "1150.00",
      "description": "الرصيد المستحق"
    }
  ],
  "warnings": ["قائمة بأي غموض أو نقص في المستند"]
}

إذا المستند غير قابل للاستخراج:
{"success": false, "reason": "...وصف دقيق للسبب..."}"""


def _b64_without_prefix(b64: str) -> str:
    """إزالة prefix مثل `data:image/jpeg;base64,` إن وُجد."""
    if "," in b64[:64]:
        return b64.split(",", 1)[1]
    return b64


def _safe_json_parse(text: str) -> Optional[dict[str, Any]]:
    """يحاول استخراج JSON من رد Claude (قد يحيط بـ markdown fences رغم التعليمات)."""
    t = text.strip()
    # إزالة ```json ... ``` إن وُجدت
    if t.startswith("```"):
        t = re.sub(r"^```(?:json)?\s*", "", t)
        t = re.sub(r"\s*```\s*$", "", t)
    # محاولة استخراج أول كتلة { ... } متوازنة
    start = t.find("{")
    if start == -1:
        return None
    depth = 0
    for i, ch in enumerate(t[start:], start=start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                candidate = t[start : i + 1]
                try:
                    return json.loads(candidate)
                except json.JSONDecodeError:
                    return None
    return None


def _call_claude_extraction(file_base64: str, media_type: str) -> dict[str, Any]:
    """يستدعي Claude API ويُرجِع استجابة JSON أوليّة."""
    if not ANTHROPIC_API_KEY:
        raise RuntimeError("ANTHROPIC_API_KEY غير مُعدّ — لا يمكن استخدام ميزة الذكاء الاصطناعي")

    try:
        import anthropic  # type: ignore
    except ImportError as ex:  # pragma: no cover — السدّ حماية
        raise RuntimeError("مكتبة anthropic غير مُثبّتة في البيئة") from ex

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    if media_type in SUPPORTED_IMAGE_TYPES:
        content_block: dict[str, Any] = {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": file_base64,
            },
        }
    elif media_type in SUPPORTED_PDF_TYPES:
        content_block = {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": file_base64,
            },
        }
    else:
        raise ValueError(f"نوع الملف غير مدعوم: {media_type}")

    user_message = {
        "role": "user",
        "content": [
            content_block,
            {
                "type": "text",
                "text": (
                    "اقرأ هذا المستند واستخرج قيد يومية متوازن بصيغة JSON فقط "
                    "وفق المخطط في system prompt. لا تُضِف أي نص خارج JSON."
                ),
            },
        ],
    }

    logger.info(
        "Calling Claude: model=%s, media=%s, b64_len=%d",
        AI_MODEL, media_type, len(file_base64),
    )
    try:
        response = client.messages.create(
            model=AI_MODEL,
            max_tokens=2000,
            temperature=0.1,  # دقّة عالية، لا إبداع
            system=EXTRACTION_SYSTEM_PROMPT,
            messages=[user_message],
        )
    except Exception as call_ex:  # noqa: BLE001
        logger.error(
            "Claude API call failed: %s: %s\n%s",
            type(call_ex).__name__, call_ex, traceback.format_exc(),
        )
        raise

    ai_text = response.content[0].text.strip() if response.content else ""
    logger.info("Claude returned %d chars (first 200: %r)", len(ai_text), ai_text[:200])
    parsed = _safe_json_parse(ai_text)
    if parsed is None:
        logger.error("AI extraction returned non-JSON: %r", ai_text[:500])
        raise ValueError("الذكاء الاصطناعي لم يُرجِع JSON صحيحاً")
    return parsed


def _normalize_amount(raw: Any) -> Decimal:
    """تحويل أي تمثيل رقمي إلى Decimal بدقة 2 — يتعامل مع السلاسل والفواصل."""
    if raw is None or raw == "":
        return Decimal("0.00")
    if isinstance(raw, (int, float, Decimal)):
        return Decimal(str(raw)).quantize(Decimal("0.01"))
    s = str(raw).strip().replace(",", "").replace(" ", "")
    # إزالة رموز العملات الشائعة
    for sym in ("ر.س", "SAR", "ريال", "﷼", "$", "USD", "AED", "درهم"):
        s = s.replace(sym, "")
    s = s.strip()
    if s == "" or s == "-":
        return Decimal("0.00")
    try:
        return Decimal(s).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        return Decimal("0.00")


# ──────────────────────────────────────────────────────────────────────────
# Account matching (hint → CoA account_id)
# ──────────────────────────────────────────────────────────────────────────

# قاموس مرادفات شائعة → مفاتيح بحث في name_ar
_ACCOUNT_SYNONYMS: dict[str, list[str]] = {
    "الصندوق": ["صندوق", "نقدية", "خزينة", "كاش"],
    "البنك": ["بنك", "حساب بنكي", "حسابات بنكية"],
    "المدينون": ["مدينون", "عملاء", "ذمم مدينة", "ذمم تجارية"],
    "الموردون": ["موردون", "موردين", "ذمم دائنة", "ذمم موردون"],
    "ضريبة قيمة مضافة مدخلة": [
        "ضريبة مدخلة",
        "vat مدخل",
        "ضريبة قيمة مضافة مدخلة",
        "مشتريات ضريبة",
    ],
    "ضريبة قيمة مضافة مخرجة": [
        "ضريبة مخرجة",
        "vat مخرج",
        "ضريبة قيمة مضافة مخرجة",
        "مبيعات ضريبة",
    ],
    "مشتريات بضاعة": ["مشتريات", "مشتريات بضاعة", "تكلفة بضاعة", "مخزون"],
    "إيرادات المبيعات": ["مبيعات", "إيرادات مبيعات", "إيرادات"],
    "مصروفات عمومية": ["مصروفات", "مصروفات عامة", "مصروفات عمومية وإدارية"],
    "رواتب وأجور": ["رواتب", "أجور", "مرتبات", "مصروف رواتب"],
    "إيجار": ["إيجار", "مصروف إيجار", "إيجارات"],
    "كهرباء وماء": ["كهرباء", "ماء", "مياه", "فواتير مرافق"],
    "اتصالات وإنترنت": ["اتصالات", "إنترنت", "هاتف"],
    "رسوم بنكية": ["رسوم بنكية", "عمولات بنكية", "مصاريف بنكية"],
    "وقود": ["وقود", "بنزين", "محروقات", "ديزل"],
    "صيانة": ["صيانة", "إصلاح"],
    "دعاية وإعلان": ["دعاية", "إعلان", "تسويق"],
    "أثاث ومعدات": ["أثاث", "معدات", "تجهيزات"],
    "إهلاك": ["إهلاك", "استهلاك"],
}


def _strip_ar(s: str) -> str:
    """تطبيع نص عربي للمقارنة: إزالة التشكيل + توحيد الألف + lowercasing."""
    if not s:
        return ""
    t = s.strip().lower()
    # إزالة التشكيل
    t = re.sub(r"[\u064B-\u0652\u0670]", "", t)
    # توحيد الألف والياء والتاء المربوطة
    t = t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    t = t.replace("ى", "ي").replace("ة", "ه")
    return t


def _match_account(hint: str, accounts: list[GLAccount]) -> tuple[Optional[str], float]:
    """يُطابق account_hint مع شجرة الحسابات.

    يُرجِع (account_id, confidence).
    """
    if not hint or not accounts:
        return None, 0.0
    hint_norm = _strip_ar(hint)
    # عدّاد نقاط: 10 تطابق تام، 5 substring، 2 كلمة مشتركة
    best_id: Optional[str] = None
    best_score: float = 0.0

    # توسيع الـ hint بالمرادفات
    expanded = {hint_norm}
    for canonical, syns in _ACCOUNT_SYNONYMS.items():
        if _strip_ar(canonical) in hint_norm or any(_strip_ar(s) in hint_norm for s in syns):
            expanded.add(_strip_ar(canonical))
            for s in syns:
                expanded.add(_strip_ar(s))

    for acc in accounts:
        if acc.type != "detail":
            continue  # الترحيل لا يتم إلا على detail accounts
        if not acc.is_active:
            continue
        name_norm = _strip_ar(acc.name_ar or "")
        if not name_norm:
            continue
        score = 0.0
        # تطابق تام
        if hint_norm == name_norm:
            score = 1.0
        else:
            # substring
            for exp in expanded:
                if not exp:
                    continue
                if exp == name_norm:
                    score = max(score, 0.95)
                elif exp in name_norm or name_norm in exp:
                    score = max(score, 0.75)
                else:
                    # كلمات مشتركة
                    exp_words = set(exp.split())
                    name_words = set(name_norm.split())
                    common = exp_words & name_words
                    if common:
                        ratio = len(common) / max(len(exp_words), 1)
                        score = max(score, 0.3 + 0.4 * ratio)
        if score > best_score:
            best_score = score
            best_id = acc.id

    # Threshold منخفض — نُرجِع أفضل مطابقة حتى لو 0.3 ليقرِّرها المستخدم
    if best_score < 0.3:
        return None, 0.0
    return best_id, round(best_score, 2)


# ──────────────────────────────────────────────────────────────────────────
# Public entry point
# ──────────────────────────────────────────────────────────────────────────


def extract_je_from_document(
    db: Session,
    entity: Entity,
    file_base64: str,
    media_type: str,
) -> dict[str, Any]:
    """الواجهة الرئيسية: يقرأ مستنداً ويُرجِع اقتراح قيد يومية."""

    if media_type not in ALL_SUPPORTED:
        raise ValueError(f"نوع الملف غير مدعوم: {media_type}. المدعوم: {', '.join(sorted(ALL_SUPPORTED))}")

    clean_b64 = _b64_without_prefix(file_base64)
    if len(clean_b64) > MAX_B64_LENGTH:
        raise ValueError("حجم الملف كبير جداً — الحدّ الأقصى 10MB")
    if len(clean_b64) < 100:
        raise ValueError("الملف صغير جداً أو فارغ")

    raw = _call_claude_extraction(clean_b64, media_type)

    if not raw.get("success", False):
        return {
            "success": False,
            "reason": raw.get("reason", "المستند غير قابل للاستخراج"),
            "raw_extraction": raw,
        }

    # جلب شجرة الحسابات النشطة
    accounts: list[GLAccount] = (
        db.query(GLAccount)
        .filter(
            GLAccount.entity_id == entity.id,
            GLAccount.is_active == True,  # noqa: E712
        )
        .all()
    )

    suggested_lines_out: list[dict[str, Any]] = []
    warnings: list[str] = list(raw.get("warnings") or [])

    for raw_line in raw.get("suggested_lines", []):
        hint = str(raw_line.get("account_hint", "")).strip()
        debit = _normalize_amount(raw_line.get("debit"))
        credit = _normalize_amount(raw_line.get("credit"))
        desc = str(raw_line.get("description", "")).strip()

        # لا نُضيف سطراً صفرياً
        if debit == 0 and credit == 0:
            continue

        # مدين ودائن معاً — نُصلّح بإعطاء الأولوية للأكبر
        if debit > 0 and credit > 0:
            if debit >= credit:
                debit = debit - credit
                credit = Decimal("0.00")
            else:
                credit = credit - debit
                debit = Decimal("0.00")
            warnings.append(f"السطر '{hint}' كان فيه مدين ودائن معاً — تم تعديله إلى صافي")

        account_id, match_conf = _match_account(hint, accounts)
        if account_id is None:
            warnings.append(f"لم يتم إيجاد حساب مطابق لـ '{hint}' — اختر الحساب يدوياً")

        suggested_lines_out.append(
            {
                "account_id": account_id,
                "account_hint": hint,
                "match_confidence": match_conf,
                "debit": str(debit),
                "credit": str(credit),
                "description": desc,
            }
        )

    # فحص التوازن
    total_debit = sum(Decimal(ln["debit"]) for ln in suggested_lines_out)
    total_credit = sum(Decimal(ln["credit"]) for ln in suggested_lines_out)
    balance_diff = total_debit - total_credit
    if abs(balance_diff) > Decimal("0.01"):
        warnings.append(f"القيد غير متوازن — الفرق: {balance_diff}. راجع السطور قبل الحفظ.")

    suggested_date = str(raw.get("suggested_date", "")).strip()
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", suggested_date):
        from datetime import date as _date

        suggested_date = _date.today().isoformat()
        warnings.append("لم يُستخرج تاريخ صالح — تم استخدام تاريخ اليوم")

    return {
        "success": True,
        "document_type": raw.get("document_type", "unknown"),
        "confidence": float(raw.get("confidence", 0.0) or 0.0),
        "suggested_kind": raw.get("suggested_kind", "manual"),
        "suggested_memo_ar": raw.get("suggested_memo_ar", ""),
        "suggested_date": suggested_date,
        "currency": raw.get("currency", "SAR"),
        "total_amount": str(_normalize_amount(raw.get("total_amount"))),
        "vat_amount": str(_normalize_amount(raw.get("vat_amount"))),
        "vendor_or_customer": raw.get("vendor_or_customer", ""),
        "document_number": raw.get("document_number", ""),
        "suggested_lines": suggested_lines_out,
        "total_debit": str(total_debit),
        "total_credit": str(total_credit),
        "is_balanced": abs(balance_diff) <= Decimal("0.01"),
        "warnings": warnings,
        "raw_extraction": raw,
    }
