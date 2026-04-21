"""AI routes — قراءة المستندات بالذكاء الاصطناعي لبناء قيود اليومية.

Endpoints:
    POST /pilot/entities/{entity_id}/ai/extract-je
        Body: {"file_base64": "...", "media_type": "image/jpeg|image/png|application/pdf"}
        Returns: اقتراح قيد كامل مع مطابقة الحسابات.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.pilot.models import Entity
from app.pilot.services.ai_extraction import (
    ALL_SUPPORTED,
    ANTHROPIC_API_KEY,
    extract_je_from_document,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pilot", tags=["pilot-ai"])


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
        model=os.environ.get("APEX_AI_MODEL", "claude-sonnet-4-20250514"),
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
