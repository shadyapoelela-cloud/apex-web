"""
APEX Platform - Archive APIs
Per Architecture Doc v5 Section 25-26
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta, timezone
import logging

from app.phase1.routes.phase1_routes import get_current_user
from app.phase1.models.platform_models import SessionLocal
from app.phase2.models.archive_models import (
    ArchiveItem,
    ArchiveLink,
    ArchiveRetentionEvent,
    ArchivePolicy,
)

router = APIRouter()


# ── Schemas ──


class ArchiveUploadRequest(BaseModel):
    client_id: Optional[str] = None
    source_type: str = "manual"
    source_id: Optional[str] = None
    file_name: str
    storage_key: str
    size_bytes: Optional[int] = None
    mime_type: Optional[str] = None


class AttachFromArchiveRequest(BaseModel):
    target_process_type: str
    target_process_id: str


# ── User Archive ──


@router.get("/account/archive", tags=["Archive"])
async def get_user_archive(
    user: dict = Depends(get_current_user),
    status: str = Query("active"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    db = SessionLocal()
    try:
        q = (
            db.query(ArchiveItem)
            .filter(
                ArchiveItem.owner_user_id == user["sub"],
                ArchiveItem.status == status,
            )
            .order_by(ArchiveItem.archived_at.desc())
        )
        total = q.count()
        items = q.offset((page - 1) * page_size).limit(page_size).all()
        now = datetime.now(timezone.utc)
        return {
            "success": True,
            "total": total,
            "page": page,
            "data": [
                {
                    "id": i.id,
                    "file_name": i.file_name,
                    "source_type": i.source_type,
                    "client_id": i.client_id,
                    "size_bytes": i.size_bytes,
                    "status": i.status,
                    "archived_at": str(i.archived_at),
                    "expires_at": str(i.expires_at),
                    "days_remaining": (
                        max(0, (i.expires_at.replace(tzinfo=timezone.utc) - now).days) if i.expires_at else None
                    ),
                }
                for i in items
            ],
        }
    finally:
        db.close()


# ── Client Archive ──


@router.get("/clients/{client_id}/archive", tags=["Archive"])
async def get_client_archive(
    client_id: str,
    user: dict = Depends(get_current_user),
    status: str = Query("active"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    db = SessionLocal()
    try:
        q = (
            db.query(ArchiveItem)
            .filter(
                ArchiveItem.client_id == client_id,
                ArchiveItem.status == status,
            )
            .order_by(ArchiveItem.archived_at.desc())
        )
        total = q.count()
        items = q.offset((page - 1) * page_size).limit(page_size).all()
        now = datetime.now(timezone.utc)
        return {
            "success": True,
            "total": total,
            "page": page,
            "data": [
                {
                    "id": i.id,
                    "file_name": i.file_name,
                    "source_type": i.source_type,
                    "size_bytes": i.size_bytes,
                    "status": i.status,
                    "archived_at": str(i.archived_at),
                    "expires_at": str(i.expires_at),
                    "days_remaining": (
                        max(0, (i.expires_at.replace(tzinfo=timezone.utc) - now).days) if i.expires_at else None
                    ),
                }
                for i in items
            ],
        }
    finally:
        db.close()


# ── Upload to Archive ──


@router.post("/archive/upload", tags=["Archive"])
async def upload_to_archive(req: ArchiveUploadRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        policy = (
            db.query(ArchivePolicy)
            .filter(ArchivePolicy.is_active == True, ArchivePolicy.scope_type == "global")
            .first()
        )
        retention_days = policy.retention_days if policy else 30

        now = datetime.now(timezone.utc)
        item = ArchiveItem(
            owner_user_id=user["sub"],
            client_id=req.client_id,
            source_type=req.source_type,
            source_id=req.source_id,
            file_name=req.file_name,
            file_ext=req.file_name.rsplit(".", 1)[-1] if "." in req.file_name else None,
            mime_type=req.mime_type,
            storage_key=req.storage_key,
            size_bytes=req.size_bytes,
            archived_at=now,
            expires_at=now + timedelta(days=retention_days),
        )
        db.add(item)
        db.commit()
        db.refresh(item)
        return {"success": True, "archive_item_id": item.id, "expires_at": str(item.expires_at)}
    except Exception:
        db.rollback()
        logging.error("Failed to upload to archive", exc_info=True)
        raise HTTPException(status_code=500, detail="Archive upload failed")
    finally:
        db.close()


# ── Attach from Archive ──


@router.post("/archive/items/{archive_item_id}/attach", tags=["Archive"])
async def attach_from_archive(
    archive_item_id: str,
    req: AttachFromArchiveRequest,
    user: dict = Depends(get_current_user),
):
    db = SessionLocal()
    try:
        item = db.query(ArchiveItem).filter(ArchiveItem.id == archive_item_id).first()
        if not item:
            raise HTTPException(status_code=404, detail="Archive item not found")
        if item.status in ("deleted", "purged"):
            raise HTTPException(status_code=410, detail="Archive item expired or deleted")

        link = ArchiveLink(
            archive_item_id=archive_item_id,
            target_process_type=req.target_process_type,
            target_process_id=req.target_process_id,
            attached_by=user["sub"],
        )
        db.add(link)
        db.commit()
        return {"success": True, "link_id": link.id}
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logging.error("Failed to attach archive item", exc_info=True)
        raise HTTPException(status_code=500, detail="Archive attach failed")
    finally:
        db.close()


# ── Delete Archive Item ──


@router.delete("/archive/items/{archive_item_id}", tags=["Archive"])
async def delete_archive_item(archive_item_id: str, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        item = (
            db.query(ArchiveItem)
            .filter(
                ArchiveItem.id == archive_item_id,
                ArchiveItem.owner_user_id == user["sub"],
            )
            .first()
        )
        if not item:
            raise HTTPException(status_code=404, detail="Archive item not found or not yours")
        if item.status == "locked_by_process":
            raise HTTPException(status_code=409, detail="Item locked by active process")

        item.status = "deleted"
        item.deleted_at = datetime.now(timezone.utc)

        db.add(
            ArchiveRetentionEvent(
                archive_item_id=archive_item_id,
                event_type="deleted",
                actor_id=user["sub"],
                notes="Manual deletion by user",
            )
        )
        db.commit()
        return {"success": True, "message": "Item marked as deleted"}
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logging.error("Failed to delete archive item", exc_info=True)
        raise HTTPException(status_code=500, detail="Archive deletion failed")
    finally:
        db.close()
