"""
APEX Platform — Phase 5 API Routes
═══════════════════════════════════════════════════════════════
Marketplace, Task Compliance, Suspension Engine.
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional

from app.phase1.routes.phase1_routes import get_current_user
from app.phase5.services.marketplace_service import MarketplaceService

router = APIRouter()
mkt = MarketplaceService()


class CreateRequestReq(BaseModel):
    client_id: str
    title: str = Field(..., min_length=5)
    description: str = Field(..., min_length=10)
    scope_code: Optional[str] = None
    category_required: Optional[str] = None
    urgency: str = "normal"
    budget_sar: Optional[float] = None
    deadline_days: Optional[int] = None


class AssignProviderReq(BaseModel):
    provider_id: str
    agreed_price: float


class UpdateStatusReq(BaseModel):
    new_status: str
    message: Optional[str] = None


class RateReq(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    review: Optional[str] = None
    is_client: bool = True


class SuspendReq(BaseModel):
    target_type: str
    target_id: str
    reason: str
    reason_details: Optional[str] = None
    duration_days: Optional[int] = None


class AppealReq(BaseModel):
    appeal_text: str = Field(..., min_length=20)


# ─── Marketplace Requests ────────────────────────────────────


@router.post("/marketplace/requests", tags=["Marketplace"])
async def create_request(req: CreateRequestReq, user: dict = Depends(get_current_user)):
    result = mkt.create_request(
        req.client_id,
        user["sub"],
        req.title,
        req.description,
        req.scope_code,
        req.category_required,
        req.urgency,
        req.budget_sar,
        req.deadline_days,
    )
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.post("/marketplace/requests/{rid}/assign", tags=["Marketplace"])
async def assign_provider(rid: str, req: AssignProviderReq, user: dict = Depends(get_current_user)):
    result = mkt.assign_provider(rid, req.provider_id, req.agreed_price, user["sub"])
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.post("/marketplace/requests/{rid}/status", tags=["Marketplace"])
async def update_status(rid: str, req: UpdateStatusReq, user: dict = Depends(get_current_user)):
    result = mkt.update_status(rid, req.new_status, user["sub"], req.message)
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.post("/marketplace/requests/{rid}/rate", tags=["Marketplace"])
async def rate_request(rid: str, req: RateReq, user: dict = Depends(get_current_user)):
    result = mkt.rate_request(rid, user["sub"], req.rating, req.review, req.is_client)
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.get("/marketplace/requests", tags=["Marketplace"])
async def list_requests(
    client_id: Optional[str] = None,
    provider_id: Optional[str] = None,
    status: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    result = mkt.list_requests(client_id=client_id, provider_id=provider_id, status=status)
    return {"success": True, "data": result}


@router.get("/marketplace/requests/{rid}", tags=["Marketplace"])
async def get_request_detail(rid: str, user: dict = Depends(get_current_user)):
    result = mkt.get_request_detail(rid)
    if not result.get("success"):
        raise HTTPException(404, result.get("error"))
    return result


# ─── Compliance ──────────────────────────────────────────────


@router.post("/compliance/check/{rid}", tags=["Compliance"])
async def check_compliance(rid: str, user: dict = Depends(get_current_user)):
    result = mkt.check_compliance(rid)
    return {"success": True, "data": result}


# ─── Suspension Engine ───────────────────────────────────────


@router.post("/admin/suspend", tags=["Suspension"])
async def suspend_entity(req: SuspendReq, user: dict = Depends(get_current_user)):
    allowed = {"platform_admin", "super_admin"}
    if not set(user.get("roles", [])) & allowed:
        raise HTTPException(403, "ليس لديك صلاحية")
    result = mkt.suspend(req.target_type, req.target_id, req.reason, req.reason_details, user["sub"], req.duration_days)
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.post("/admin/suspend/{sid}/lift", tags=["Suspension"])
async def lift_suspension(sid: str, user: dict = Depends(get_current_user)):
    allowed = {"platform_admin", "super_admin"}
    if not set(user.get("roles", [])) & allowed:
        raise HTTPException(403, "ليس لديك صلاحية")
    result = mkt.lift_suspension(sid, user["sub"])
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.post("/suspensions/{sid}/appeal", tags=["Suspension"])
async def submit_appeal(sid: str, req: AppealReq, user: dict = Depends(get_current_user)):
    result = mkt.submit_appeal(sid, user["sub"], req.appeal_text)
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result


@router.get("/admin/suspensions", tags=["Suspension"])
async def list_suspensions(active_only: bool = True, user: dict = Depends(get_current_user)):
    result = mkt.list_suspensions(active_only=active_only)
    return {"success": True, "data": result}
