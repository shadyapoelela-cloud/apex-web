"""Pydantic schemas for RBAC."""

from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field, ConfigDict


class PermissionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    resource: str
    action: str
    name_ar: str
    name_en: str
    description_ar: Optional[str]
    category: str
    risk_level: str


class RoleCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=50)
    name_ar: str
    name_en: Optional[str] = None
    description_ar: Optional[str] = None
    scope: str = Field("branch", pattern="^(tenant|entity|branch)$")
    approval_limits: dict[str, Any] = Field(default_factory=dict)
    color_hex: Optional[str] = None
    icon: Optional[str] = None
    sort_order: int = 0
    permission_ids: list[str] = Field(default_factory=list)


class RoleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    description_ar: Optional[str]
    scope: str
    is_system: bool
    is_active: bool
    approval_limits: dict[str, Any]
    color_hex: Optional[str]
    icon: Optional[str]
    sort_order: int


class RoleUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    description_ar: Optional[str] = None
    scope: Optional[str] = None
    is_active: Optional[bool] = None
    approval_limits: Optional[dict[str, Any]] = None
    color_hex: Optional[str] = None
    icon: Optional[str] = None
    sort_order: Optional[int] = None
    permission_ids: Optional[list[str]] = None


class UserEntityAccessCreate(BaseModel):
    user_id: str
    entity_id: str
    role_id: str
    expires_at: Optional[datetime] = None
    can_delegate: bool = False


class UserBranchAccessCreate(BaseModel):
    user_id: str
    branch_id: str
    role_id: str
    expires_at: Optional[datetime] = None


class UserAccessRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    user_id: str
    entity_id: Optional[str] = None
    branch_id: Optional[str] = None
    role_id: str
    granted_at: datetime
    expires_at: Optional[datetime]
    is_active: bool
