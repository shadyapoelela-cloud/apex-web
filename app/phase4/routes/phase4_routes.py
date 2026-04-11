"""
APEX Platform — Phase 4 API Routes
═══════════════════════════════════════════════════════════════
Provider Registration, Documents, Verification, Marketplace.
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional

from app.phase1.routes.phase1_routes import get_current_user
from app.phase4.services.provider_service import ProviderService

router = APIRouter()
provider_service = ProviderService()


class RegisterProviderRequest(BaseModel):
    category: str
    bio_ar: Optional[str] = None
    years_experience: Optional[int] = None
    city: Optional[str] = None


class UploadDocRequest(BaseModel):
    document_type: str
    filename: str
    file_size: int = 0


class ReviewProviderRequest(BaseModel):
    decision: str  # approved, rejected
    reviewer_notes: Optional[str] = None
    verification_score: Optional[int] = Field(None, ge=0, le=100)


# ─── Provider Self-Service ───────────────────────────────────


@router.post("/service-providers/register", tags=["Providers"])
async def register_provider(req: RegisterProviderRequest, user: dict = Depends(get_current_user)):
    result = provider_service.register_provider(user["sub"], req.category, req.bio_ar, req.years_experience, req.city)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.post("/service-providers/documents", tags=["Providers"])
async def upload_document(req: UploadDocRequest, user: dict = Depends(get_current_user)):
    result = provider_service.upload_document(user["sub"], req.document_type, req.filename, req.file_size)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/service-providers/me", tags=["Providers"])
async def get_my_provider_profile(user: dict = Depends(get_current_user)):
    result = provider_service.get_my_provider_profile(user["sub"])
    if not result.get("success"):
        raise HTTPException(status_code=404, detail=result.get("error"))
    return result


# ─── Marketplace ─────────────────────────────────────────────


@router.get("/marketplace/providers", tags=["Marketplace"])
async def list_marketplace_providers(category: Optional[str] = None):
    result = provider_service.list_providers(category=category)
    return {"success": True, "data": result}


# ─── Admin: Verification ─────────────────────────────────────


@router.get("/service-providers/verification-queue", tags=["Provider Admin"])
async def verification_queue(user: dict = Depends(get_current_user)):
    allowed = {"reviewer", "platform_admin", "super_admin"}
    if not set(user.get("roles", [])) & allowed:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية")
    result = provider_service.list_pending_verification()
    return {"success": True, "data": result}


@router.post("/service-providers/{provider_id}/review", tags=["Provider Admin"])
async def review_provider(provider_id: str, req: ReviewProviderRequest, user: dict = Depends(get_current_user)):
    allowed = {"reviewer", "platform_admin", "super_admin"}
    if not set(user.get("roles", [])) & allowed:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية")
    result = provider_service.review_provider(
        provider_id, user["sub"], req.decision, req.reviewer_notes, req.verification_score
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result
