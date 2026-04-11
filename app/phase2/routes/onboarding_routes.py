"""
APEX Platform - Client Onboarding Extension Routes
Legal Entity Types + Sectors + Documents + Draft + Stage Notes
Per Architecture Doc v5 Sections 23, 26, 29
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional, List
import logging

from app.phase1.routes.phase1_routes import get_current_user
from app.phase1.models.platform_models import SessionLocal
from app.phase2.models.onboarding_models import (
    LegalEntityType,
    SectorMain,
    SectorSub,
    ClientRequiredDocument,
    ClientOnboardingDraft,
    StageNote,
)

router = APIRouter()


# ── Schemas ──


class DraftSaveRequest(BaseModel):
    step_completed: int = Field(..., ge=0, le=7)
    draft_data: dict


class DocumentStatusUpdate(BaseModel):
    status: str  # uploaded, verified, rejected
    rejection_reason: Optional[str] = None


# ── Legal Entity Types ──


@router.get("/legal-entity-types", tags=["Client Onboarding"])
async def list_legal_entity_types():
    db = SessionLocal()
    try:
        items = (
            db.query(LegalEntityType)
            .filter(LegalEntityType.is_active == True)
            .order_by(LegalEntityType.sort_order)
            .all()
        )
        return {
            "success": True,
            "data": [
                {
                    "code": i.code,
                    "name_ar": i.name_ar,
                    "name_en": i.name_en,
                    "description_ar": i.description_ar,
                    "description_en": i.description_en,
                    "required_documents_profile": i.required_documents_profile,
                    "additional_fields": i.additional_fields,
                }
                for i in items
            ],
        }
    finally:
        db.close()


# ── Sectors ──


@router.get("/sectors", tags=["Client Onboarding"])
async def list_sectors_main():
    db = SessionLocal()
    try:
        items = db.query(SectorMain).filter(SectorMain.is_active == True).order_by(SectorMain.sort_order).all()
        return {
            "success": True,
            "data": [{"code": i.code, "name_ar": i.name_ar, "name_en": i.name_en, "icon": i.icon} for i in items],
        }
    finally:
        db.close()


@router.get("/sectors/{main_code}/sub", tags=["Client Onboarding"])
async def list_sub_sectors(main_code: str):
    db = SessionLocal()
    try:
        items = (
            db.query(SectorSub)
            .filter(SectorSub.sector_main_code == main_code, SectorSub.is_active == True)
            .order_by(SectorSub.sort_order)
            .all()
        )
        return {
            "success": True,
            "data": [
                {
                    "code": i.code,
                    "name_ar": i.name_ar,
                    "name_en": i.name_en,
                    "requires_license": i.requires_license,
                    "license_type": i.license_type,
                }
                for i in items
            ],
        }
    finally:
        db.close()


# ── Onboarding Draft ──


@router.get("/onboarding/draft", tags=["Client Onboarding"])
async def get_my_draft(user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        draft = (
            db.query(ClientOnboardingDraft)
            .filter(ClientOnboardingDraft.user_id == user["sub"], ClientOnboardingDraft.is_converted == False)
            .first()
        )
        if not draft:
            return {"success": True, "data": None}
        return {
            "success": True,
            "data": {
                "id": draft.id,
                "step_completed": draft.step_completed,
                "draft_data": draft.draft_data,
                "updated_at": str(draft.updated_at),
            },
        }
    finally:
        db.close()


@router.post("/onboarding/draft", tags=["Client Onboarding"])
async def save_draft(req: DraftSaveRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        draft = (
            db.query(ClientOnboardingDraft)
            .filter(ClientOnboardingDraft.user_id == user["sub"], ClientOnboardingDraft.is_converted == False)
            .first()
        )
        if not draft:
            draft = ClientOnboardingDraft(user_id=user["sub"])
            db.add(draft)
        draft.step_completed = req.step_completed
        draft.draft_data = req.draft_data
        db.commit()
        db.refresh(draft)
        return {"success": True, "draft_id": draft.id, "step_completed": draft.step_completed}
    except Exception as e:
        db.rollback()
        logging.error("Failed to save onboarding draft", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to save draft")
    finally:
        db.close()


# ── Required Documents for Client ──


@router.get("/clients/{client_id}/required-documents", tags=["Client Onboarding"])
async def get_client_documents(client_id: str, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        docs = (
            db.query(ClientRequiredDocument)
            .filter(ClientRequiredDocument.client_id == client_id)
            .order_by(ClientRequiredDocument.is_mandatory.desc())
            .all()
        )
        return {
            "success": True,
            "data": [
                {
                    "id": d.id,
                    "document_code": d.document_code,
                    "document_name_ar": d.document_name_ar,
                    "is_mandatory": d.is_mandatory,
                    "source_rule": d.source_rule,
                    "status": d.status,
                    "file_name": d.file_name,
                    "uploaded_at": str(d.uploaded_at) if d.uploaded_at else None,
                }
                for d in docs
            ],
        }
    finally:
        db.close()


# ── Stage Notes ──


@router.get("/stage-notes/{service_key}/{stage_key}", tags=["Stage Notes"])
async def get_stage_notes(service_key: str, stage_key: str, role: str = Query("all")):
    db = SessionLocal()
    try:
        note = (
            db.query(StageNote)
            .filter(
                StageNote.service_key == service_key,
                StageNote.stage_key == stage_key,
                StageNote.is_active == True,
                StageNote.role_scope.in_([role, "all"]),
            )
            .first()
        )
        if not note:
            return {"success": True, "data": None}
        return {
            "success": True,
            "data": {
                "title_ar": note.title_ar,
                "title_en": note.title_en,
                "body_ar": note.body_ar,
                "body_en": note.body_en,
                "common_errors_ar": note.common_errors_ar,
                "impact_ar": note.impact_ar,
                "required_documents": note.required_documents,
            },
        }
    finally:
        db.close()
