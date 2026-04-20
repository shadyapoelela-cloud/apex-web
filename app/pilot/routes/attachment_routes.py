"""Attachment routes — polymorphic upload/list/delete لأي كيان pilot."""

from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from datetime import datetime, timezone

from app.phase1.models.platform_models import get_db
from app.pilot.models import Attachment, AttachmentKind, Tenant


router = APIRouter(prefix="/pilot", tags=["pilot-attachments"])


# ──────────────────────────────────────────────────────────────────────────
# Schemas
# ──────────────────────────────────────────────────────────────────────────

class AttachmentCreate(BaseModel):
    """إنشاء مرفق. الملف نفسه يجب أن يكون مرفوعاً مسبقاً (S3/local)
    وتمرير الـ storage_url هنا. للملفات الصغيرة يمكن استخدام data: URI."""
    tenant_id: str
    parent_type: str = Field(
        ..., description="نوع الكيان: journal_entries|purchase_orders|vendors|...",
    )
    parent_id: str
    kind: str = AttachmentKind.other.value
    filename: str = Field(..., max_length=255)
    content_type: Optional[str] = None
    size_bytes: Optional[int] = None
    description: Optional[str] = None
    storage_url: str = Field(..., max_length=2000)
    uploaded_by_user_id: Optional[str] = None


class AttachmentRead(BaseModel):
    """Read schema."""
    model_config = {"from_attributes": True}

    id: str
    tenant_id: str
    parent_type: str
    parent_id: str
    kind: str
    filename: str
    content_type: Optional[str]
    size_bytes: Optional[int]
    description: Optional[str]
    storage_url: str
    uploaded_by_user_id: Optional[str]
    uploaded_at: datetime
    is_locked: bool
    locked_reason: Optional[str]


# ──────────────────────────────────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────────────────────────────────

@router.post("/attachments", response_model=AttachmentRead, status_code=201)
def create_attachment(
    payload: AttachmentCreate, db: Session = Depends(get_db),
):
    """إنشاء مرفق. Client يرفع الملف أولاً لـ storage ثم يرسل metadata هنا."""
    # فحص tenant
    if not db.query(Tenant).filter(Tenant.id == payload.tenant_id).first():
        raise HTTPException(404, "Tenant not found")

    att = Attachment(
        tenant_id=payload.tenant_id,
        parent_type=payload.parent_type,
        parent_id=payload.parent_id,
        kind=payload.kind,
        filename=payload.filename,
        content_type=payload.content_type,
        size_bytes=payload.size_bytes,
        description=payload.description,
        storage_url=payload.storage_url,
        uploaded_by_user_id=payload.uploaded_by_user_id,
    )
    db.add(att)
    db.commit()
    db.refresh(att)
    return att


@router.get(
    "/attachments",
    response_model=list[AttachmentRead],
)
def list_attachments(
    parent_type: str = Query(..., description="نوع الكيان الأب"),
    parent_id: str = Query(..., description="ID الكيان الأب"),
    db: Session = Depends(get_db),
):
    """جلب كل المرفقات لكيان محدد."""
    return (
        db.query(Attachment)
        .filter(
            Attachment.parent_type == parent_type,
            Attachment.parent_id == parent_id,
        )
        .order_by(Attachment.uploaded_at.desc())
        .all()
    )


@router.delete("/attachments/{attachment_id}", status_code=204)
def delete_attachment(attachment_id: str, db: Session = Depends(get_db)):
    """حذف مرفق — مسموح فقط لو غير مقفل."""
    att = db.query(Attachment).filter(Attachment.id == attachment_id).first()
    if not att:
        raise HTTPException(404, "المرفق غير موجود")
    if att.is_locked:
        raise HTTPException(
            403,
            f"المرفق مقفل: {att.locked_reason or 'بعد ترحيل أو ZATCA clearance'}",
        )
    db.delete(att)
    db.commit()


@router.post("/attachments/{attachment_id}/lock", response_model=AttachmentRead)
def lock_attachment(
    attachment_id: str,
    reason: str = Query(..., min_length=3, max_length=255),
    db: Session = Depends(get_db),
):
    """قفل مرفق (immutability) — بعد ZATCA clearance أو period close."""
    att = db.query(Attachment).filter(Attachment.id == attachment_id).first()
    if not att:
        raise HTTPException(404, "المرفق غير موجود")
    att.is_locked = True
    att.locked_reason = reason
    db.commit()
    db.refresh(att)
    return att
