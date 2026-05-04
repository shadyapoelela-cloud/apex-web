"""AI routes — قراءة المستندات بالذكاء الاصطناعي لبناء قيود اليومية.

Endpoints:
    POST /pilot/entities/{entity_id}/ai/extract-je
        Body: JSON {"file_base64": "...", "media_type": "image/jpeg|..."}
        Returns: اقتراح قيد كامل (base64-first client).

    POST /pilot/entities/{entity_id}/ai/read-document
        Body: multipart/form-data with `file` field
        Returns: {"success": true, "data": {extracted, proposed_je, confidence}}
        Compatible wrapper لواجهة dazzling-nash / أي upload مباشر للملف.
"""

from __future__ import annotations

import base64
import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.phase1.routes.phase1_routes import get_current_user
from app.pilot.models import Entity, GLAccount
from app.pilot.services.ai_extraction import (
    ALL_SUPPORTED,
    ANTHROPIC_API_KEY,
    extract_je_from_document,
)

logger = logging.getLogger(__name__)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot-ai"],
    dependencies=[Depends(get_current_user)],
)


# ──────────────────────────────────────────────────────────────────────────
# Schemas
# ──────────────────────────────────────────────────────────────────────────


class ExtractJeRequest(BaseModel):
    file_base64: str = Field(
        ...,
        min_length=100,
        description=("المستند مُرمَّز base64. يُقبل مع/بدون prefix " "`data:image/jpeg;base64,`"),
    )
    media_type: str = Field(
        ...,
        description=("نوع MIME للملف — image/jpeg | image/png | image/gif | " "image/webp | application/pdf"),
    )
    filename: Optional[str] = Field(None, max_length=255)


class AiHealthResponse(BaseModel):
    ai_enabled: bool
    model: str
    supported_media_types: list[str]


# ──────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────


def _entity_or_404(db: Session, eid: str) -> Entity:
    e = db.query(Entity).filter(Entity.id == eid, Entity.is_deleted == False).first()  # noqa: E712
    if not e:
        raise HTTPException(404, f"Entity {eid} not found")
    return e


# ──────────────────────────────────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────────────────────────────────


@router.get("/ai/health", response_model=AiHealthResponse)
def ai_health():
    """فحص حالة خدمات الذكاء الاصطناعي."""
    import os

    return AiHealthResponse(
        ai_enabled=bool(ANTHROPIC_API_KEY),
        model=os.environ.get("APEX_AI_MODEL", "claude-sonnet-4-5-20250929"),
        supported_media_types=sorted(ALL_SUPPORTED),
    )


@router.post("/entities/{entity_id}/ai/extract-je")
def extract_je(
    entity_id: str,
    payload: ExtractJeRequest,
    db: Session = Depends(get_db),
):
    """قراءة مستند مالي واستخراج اقتراح قيد يومية متوازن.

    يُستخدم من شاشة قيود اليومية: المستخدم يرفع صورة فاتورة/إيصال،
    والنظام يُولّد اقتراح قيد يُعرَض للمراجعة والتعديل قبل الحفظ.
    """
    entity = _entity_or_404(db, entity_id)

    if not ANTHROPIC_API_KEY:
        raise HTTPException(
            503,
            "ميزة الذكاء الاصطناعي غير مُفعَّلة. " "يلزم تعيين ANTHROPIC_API_KEY في متغيرات البيئة.",
        )

    media = payload.media_type.lower().strip()
    if media not in ALL_SUPPORTED:
        raise HTTPException(
            400,
            f"نوع ملف غير مدعوم: {media}. " f"المدعوم: {', '.join(sorted(ALL_SUPPORTED))}",
        )

    try:
        result = extract_je_from_document(
            db,
            entity=entity,
            file_base64=payload.file_base64,
            media_type=media,
        )
    except ValueError as ex:
        raise HTTPException(400, str(ex))
    except RuntimeError as ex:
        logger.error("AI extraction runtime error: %s", ex)
        raise HTTPException(503, str(ex))
    except Exception as ex:  # noqa: BLE001
        logger.error("AI extraction failed: %s", ex, exc_info=True)
        raise HTTPException(500, "فشل استخراج القيد من المستند")

    return result


# ──────────────────────────────────────────────────────────────────────────
# Multipart/form-data endpoint — compatible مع dazzling-nash UI
# ──────────────────────────────────────────────────────────────────────────


_EXT_TO_MIME = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "gif": "image/gif",
    "webp": "image/webp",
    "pdf": "application/pdf",
}


def _guess_mime(upload: UploadFile) -> str:
    """استنتاج media type من content_type أو الامتداد."""
    ct = (upload.content_type or "").lower().strip()
    if ct in ALL_SUPPORTED:
        return ct
    name = (upload.filename or "").lower()
    if "." in name:
        ext = name.rsplit(".", 1)[-1]
        if ext in _EXT_TO_MIME:
            return _EXT_TO_MIME[ext]
    return ct or "application/octet-stream"


def _shape_for_read_document(db: Session, entity: Entity, raw: dict[str, Any]) -> dict[str, Any]:
    """يحوّل خرج extract_je_from_document إلى الشكل المتوقّع من dazzling UI.

    الشكل الناتج:
        {
          "success": true,
          "data": {
            "confidence": 0.85,
            "extracted": {vendor, date, document_number, description, amount, currency, tax_amount},
            "proposed_je": {
              "kind": "manual", "memo_ar": "...",
              "lines": [{account_id, account_code, account_name_resolved, debit, credit, description}]
            },
            "warnings": [...]
          }
        }
    """
    if not raw.get("success"):
        return {
            "success": False,
            "error": raw.get("reason", "تعذّر استخراج القيد من المستند"),
        }

    # بناء خريطة الحسابات للبحث السريع
    accounts = {
        acc.id: acc
        for acc in db.query(GLAccount)
        .filter(
            GLAccount.entity_id == entity.id,
            GLAccount.is_active == True,  # noqa: E712
        )
        .all()
    }

    out_lines = []
    for ln in raw.get("suggested_lines", []):
        acc_id = ln.get("account_id")
        acc = accounts.get(acc_id) if acc_id else None
        out_lines.append(
            {
                "account_id": acc_id,
                "account_code": getattr(acc, "code", None) if acc else None,
                "account_name_resolved": (getattr(acc, "name_ar", None) if acc else None),
                "account_name": ln.get("account_hint", ""),
                "debit": float(ln.get("debit", 0) or 0),
                "credit": float(ln.get("credit", 0) or 0),
                "description": ln.get("description", ""),
                "match_confidence": ln.get("match_confidence", 0.0),
            }
        )

    # المبالغ الرقمية للـ extracted block
    def _to_num(v: Any) -> float:
        try:
            return float(v)
        except (TypeError, ValueError):
            return 0.0

    extracted_block = {
        "vendor": raw.get("vendor_or_customer", ""),
        "date": raw.get("suggested_date", ""),
        "document_number": raw.get("document_number", ""),
        "description": raw.get("suggested_memo_ar", ""),
        "amount": _to_num(raw.get("total_amount", 0)),
        "currency": raw.get("currency", "SAR"),
        "tax_amount": _to_num(raw.get("vat_amount", 0)),
        "document_type": raw.get("document_type", "unknown"),
    }

    return {
        "success": True,
        "data": {
            "confidence": float(raw.get("confidence", 0) or 0),
            "extracted": extracted_block,
            "proposed_je": {
                "kind": raw.get("suggested_kind", "manual"),
                "memo_ar": raw.get("suggested_memo_ar", ""),
                "lines": out_lines,
            },
            "warnings": raw.get("warnings", []),
            "is_balanced": raw.get("is_balanced", False),
            "total_debit": _to_num(raw.get("total_debit", 0)),
            "total_credit": _to_num(raw.get("total_credit", 0)),
        },
    }


@router.post("/entities/{entity_id}/ai/read-document")
async def read_document(
    entity_id: str,
    file: UploadFile = File(..., description="صورة أو PDF للمستند"),
    db: Session = Depends(get_db),
):
    """نسخة multipart/form-data من /extract-je — تقبل رفع الملف مباشرةً.

    response shape مختلف (مُغلَّف بـ `{success, data}`) لتوافق dazzling-nash UI.
    """
    entity = _entity_or_404(db, entity_id)

    if not ANTHROPIC_API_KEY:
        raise HTTPException(
            503,
            "ميزة الذكاء الاصطناعي غير مُفعَّلة. " "يلزم تعيين ANTHROPIC_API_KEY في متغيرات البيئة.",
        )

    media = _guess_mime(file)
    if media not in ALL_SUPPORTED:
        raise HTTPException(
            400,
            f"نوع ملف غير مدعوم: {media}. " f"المدعوم: {', '.join(sorted(ALL_SUPPORTED))}",
        )

    raw_bytes = await file.read()
    if not raw_bytes:
        raise HTTPException(400, "الملف فارغ")
    if len(raw_bytes) > 10 * 1024 * 1024:
        raise HTTPException(400, "حجم الملف كبير جداً — الحدّ الأقصى 10MB")

    file_b64 = base64.b64encode(raw_bytes).decode("ascii")

    try:
        raw = extract_je_from_document(
            db,
            entity=entity,
            file_base64=file_b64,
            media_type=media,
        )
    except ValueError as ex:
        raise HTTPException(400, str(ex))
    except RuntimeError as ex:
        logger.error("AI extraction runtime error: %s", ex)
        raise HTTPException(503, str(ex))
    except Exception as ex:  # noqa: BLE001
        logger.error("AI extraction failed: %s", ex, exc_info=True)
        # نُرجِع تفاصيل الخطأ مع نوعه لتسهيل التشخيص
        raise HTTPException(
            500,
            f"فشل استخراج القيد من المستند — {type(ex).__name__}: {str(ex)[:400]}",
        )

    # لو الـ AI رفض الاستخراج (مثلاً: المستند ليس فاتورة، أو متعدد)
    # نُرجِع HTTP 400 بدل 200 حتى يلتقطها frontend كـ error
    if not raw.get("success"):
        reason = raw.get(
            "reason",
            "تعذّر استخراج القيد — قد يكون المستند غير واضح أو يحوي أكثر من فاتورة",
        )
        logger.info("AI refused extraction: %s", reason)
        raise HTTPException(400, reason)

    return _shape_for_read_document(db, entity, raw)


# ──────────────────────────────────────────────────────────────────────────
# Narration Generator — يقترح البيان من سطور القيد الحالية
# ──────────────────────────────────────────────────────────────────────────


class SuggestMemoLine(BaseModel):
    account_id: Optional[str] = None
    account_code: Optional[str] = None
    account_name: Optional[str] = None
    debit: float = 0.0
    credit: float = 0.0
    description: Optional[str] = None


class SuggestMemoRequest(BaseModel):
    lines: list[SuggestMemoLine] = Field(default_factory=list)
    kind: Optional[str] = "manual"
    date: Optional[str] = None
    reference: Optional[str] = None
    language: str = "ar"


class SuggestMemoResponse(BaseModel):
    suggested_memo: str
    confidence: float


_MEMO_SYSTEM_PROMPT = """أنت محاسب سعودي خبير. مهمتك: قراءة سطور قيد يومية
واقتراح "بيان" (memo) احترافي مختصر بالعربية يصف الغرض من القيد.

قواعد:
1. البيان يجب أن يكون **جملة واحدة** موجزة (10-25 كلمة).
2. يصف الغرض التجاري، ليس مجرد تكرار للحسابات.
3. لا تُضِف تواريخ أو أرقام مستندات — فقط وصف الطبيعة.
4. مثال جيد: "إثبات فاتورة مشتريات مكتبية من مكتبة جرير — آجل"
5. مثال سيء: "حساب المشتريات مدين، حساب الموردون دائن"
6. إن كان القيد غامضاً، اقترح بياناً عاماً دقيقاً.
7. الإخراج: JSON فقط بهذه الصيغة {"suggested_memo": "...", "confidence": 0.85}

لا تُضِف أي شرح خارج JSON."""


@router.post("/ai/suggest-memo", response_model=SuggestMemoResponse)
def suggest_memo(payload: SuggestMemoRequest, db: Session = Depends(get_db)):
    """اقتراح بيان (memo) احترافي من سطور القيد بالذكاء الاصطناعي.

    يُستخدم من حقل "البيان" في نموذج قيد اليومية — زر ✨ trailing.
    """
    if not ANTHROPIC_API_KEY:
        raise HTTPException(
            503,
            "ميزة الذكاء الاصطناعي غير مُفعَّلة. يلزم تعيين ANTHROPIC_API_KEY.",
        )

    if not payload.lines or len(payload.lines) < 2:
        raise HTTPException(
            400,
            "يلزم سطران على الأقل في القيد لاقتراح بيان دقيق.",
        )

    # نُحضر أسماء الحسابات إن لم تكن مرفقة
    account_ids = [
        ln.account_id for ln in payload.lines if ln.account_id
    ]
    accounts_map: dict[str, tuple[str, str]] = {}
    if account_ids:
        rows = (
            db.query(GLAccount)
            .filter(GLAccount.id.in_(account_ids))
            .all()
        )
        accounts_map = {
            acc.id: (acc.code or "", acc.name_ar or "") for acc in rows
        }

    # نبني سياقاً واضحاً
    lines_desc_parts = []
    for i, ln in enumerate(payload.lines, 1):
        code = ln.account_code
        name = ln.account_name
        if ln.account_id and ln.account_id in accounts_map:
            c, n = accounts_map[ln.account_id]
            code = code or c
            name = name or n
        side = "مدين" if ln.debit > 0 else ("دائن" if ln.credit > 0 else "—")
        amount = ln.debit if ln.debit > 0 else ln.credit
        line_txt = f"السطر {i}: [{code or '?'}] {name or '?'} · {side} {amount:.2f}"
        if ln.description:
            line_txt += f' · "{ln.description}"'
        lines_desc_parts.append(line_txt)

    user_message = (
        "اقترح بياناً مختصراً احترافياً للقيد التالي:\n\n"
        + "\n".join(lines_desc_parts)
    )
    if payload.reference:
        user_message += f"\n\nالرقم المرجعي: {payload.reference}"
    if payload.kind and payload.kind != "manual":
        user_message += f"\nنوع القيد: {payload.kind}"

    try:
        import anthropic  # type: ignore

        client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
        import os as _os

        model = _os.environ.get("APEX_AI_MODEL", "claude-sonnet-4-5-20250929")
        response = client.messages.create(
            model=model,
            max_tokens=300,
            temperature=0.2,
            system=_MEMO_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )
        ai_text = response.content[0].text.strip() if response.content else ""
        from app.pilot.services.ai_extraction import _safe_json_parse

        parsed = _safe_json_parse(ai_text)
        if not parsed or "suggested_memo" not in parsed:
            # fallback: just return the raw text as memo
            return SuggestMemoResponse(
                suggested_memo=ai_text[:200] if ai_text else "قيد يومية",
                confidence=0.5,
            )
        return SuggestMemoResponse(
            suggested_memo=str(parsed.get("suggested_memo", ""))[:300],
            confidence=float(parsed.get("confidence", 0.7) or 0.7),
        )
    except Exception as ex:  # noqa: BLE001
        logger.error("AI suggest-memo failed: %s", ex, exc_info=True)
        raise HTTPException(
            500,
            f"فشل اقتراح البيان — {type(ex).__name__}: {str(ex)[:200]}",
        )
