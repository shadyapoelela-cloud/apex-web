"""
APEX Platform — Phase 6 API Routes
═══════════════════════════════════════════════════════════════
Admin Dashboard, User Management, Audit Log.
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from typing import Optional

from app.phase1.routes.phase1_routes import get_current_user
from app.phase6.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["Admin"])
admin = AdminService()

ADMIN_ROLES = {"platform_admin", "super_admin"}


def require_admin(user: dict = Depends(get_current_user)):
    if not set(user.get("roles", [])) & ADMIN_ROLES:
        raise HTTPException(403, "ليس لديك صلاحية الإدارة")
    return user


class UpdateUserStatusReq(BaseModel):
    new_status: str

class AssignRoleReq(BaseModel):
    role_code: str


# ─── Dashboard ───────────────────────────────────────────────

@router.get("/stats")
async def platform_stats(user: dict = Depends(require_admin)):
    """Full platform statistics."""
    return admin.get_platform_stats()


# ─── User Management ─────────────────────────────────────────

@router.get("/users")
async def list_users(status: Optional[str] = None, search: Optional[str] = None,
                     limit: int = Query(50, le=200), user: dict = Depends(require_admin)):
    return admin.list_users(status=status, search=search, limit=limit)


@router.post("/users/{uid}/status")
async def update_user_status(uid: str, req: UpdateUserStatusReq, user: dict = Depends(require_admin)):
    result = admin.update_user_status(uid, req.new_status, user["sub"])
    if not result["success"]: raise HTTPException(400, result["error"])
    return result


@router.post("/users/{uid}/roles/assign")
async def assign_role(uid: str, req: AssignRoleReq, user: dict = Depends(require_admin)):
    result = admin.assign_role(uid, req.role_code, user["sub"])
    if not result["success"]: raise HTTPException(400, result["error"])
    return result


@router.post("/users/{uid}/roles/remove")
async def remove_role(uid: str, req: AssignRoleReq, user: dict = Depends(require_admin)):
    result = admin.remove_role(uid, req.role_code, user["sub"])
    if not result["success"]: raise HTTPException(400, result["error"])
    return result


# ─── Audit Log ───────────────────────────────────────────────

@router.get("/audit-log")
async def get_audit_log(user_id: Optional[str] = None, action: Optional[str] = None,
                        limit: int = Query(100, le=500), user: dict = Depends(require_admin)):
    return admin.get_audit_log(user_id=user_id, action=action, limit=limit)


# ─── Notifications Stats ────────────────────────────────────

@router.get("/notifications/stats")
async def notification_stats(user: dict = Depends(require_admin)):
    return admin.get_notification_stats()
