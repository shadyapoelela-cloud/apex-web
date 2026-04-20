"""Pydantic schemas for Tenant Members (users with access to a tenant).

A "member" is a phase1 User who has been granted at least one UserEntityAccess
or UserBranchAccess row within this tenant. The pilot module doesn't own the
User table — it owns the access grants that link User.id to this tenant's
Entities/Branches with a Role.
"""

from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field, EmailStr, ConfigDict


# ──────────────────────────────────────────────────────────────────────────
# Invite / Create
# ──────────────────────────────────────────────────────────────────────────

class MemberInvite(BaseModel):
    """Invite a user into a tenant.

    If a User with this email already exists in phase1, we reuse their
    account and just add the access grant. Otherwise we create a new
    phase1 User with a random temp password (sent via email; the
    invitee must reset it on first login).

    The invite MUST include at least one initial access grant
    (either entity_id OR branch_id, with a role_id).
    """
    email: EmailStr
    display_name: str = Field(..., min_length=2, max_length=100)
    mobile: Optional[str] = Field(None, max_length=20)
    language: str = Field("ar", pattern="^(ar|en)$")

    # Initial access grant (at least one scope is required)
    role_id: str = Field(..., description="Role to assign")
    scope: Literal["entity", "branch"] = Field(..., description="Grant scope")
    entity_id: Optional[str] = Field(None, description="Required when scope=entity")
    branch_id: Optional[str] = Field(None, description="Required when scope=branch")

    can_delegate: bool = False
    expires_at: Optional[datetime] = None


# ──────────────────────────────────────────────────────────────────────────
# Read
# ──────────────────────────────────────────────────────────────────────────

class MemberRead(BaseModel):
    """Condensed member row for list views."""
    model_config = ConfigDict(from_attributes=True)

    user_id: str
    email: str
    display_name: str
    mobile: Optional[str] = None
    language: Optional[str] = None
    status: str
    last_login_at: Optional[datetime] = None

    # Aggregated access summary
    entity_grants: int = 0
    branch_grants: int = 0
    primary_role_code: Optional[str] = None  # highest-scope role for display


class AccessGrantRead(BaseModel):
    """A single access grant (entity or branch) with resolved labels."""
    model_config = ConfigDict(from_attributes=True)

    grant_id: str
    grant_type: Literal["entity", "branch"]
    scope_id: str           # entity_id or branch_id
    scope_code: str          # "SA" or "SA-DMM-WAHA"
    scope_label: str         # "Advanced Fashion SA" or "Dammam Waha"
    role_id: str
    role_code: str
    role_name_ar: str
    granted_at: datetime
    expires_at: Optional[datetime] = None
    can_delegate: bool = False
    is_active: bool


class MemberDetail(BaseModel):
    """Full member profile with all access grants."""
    model_config = ConfigDict(from_attributes=True)

    user_id: str
    email: str
    display_name: str
    mobile: Optional[str] = None
    language: Optional[str] = None
    status: str
    last_login_at: Optional[datetime] = None
    grants: list[AccessGrantRead] = Field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────
# Update
# ──────────────────────────────────────────────────────────────────────────

class MemberUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=2, max_length=100)
    mobile: Optional[str] = None
    language: Optional[str] = Field(None, pattern="^(ar|en)$")
    status: Optional[str] = Field(None, pattern="^(active|suspended|disabled)$")


# ──────────────────────────────────────────────────────────────────────────
# Access grant payloads (for direct grant endpoints)
# ──────────────────────────────────────────────────────────────────────────

class GrantEntityAccess(BaseModel):
    entity_id: str
    role_id: str
    can_delegate: bool = False
    expires_at: Optional[datetime] = None


class GrantBranchAccess(BaseModel):
    branch_id: str
    role_id: str
    expires_at: Optional[datetime] = None


class RevokeAccess(BaseModel):
    reason: Optional[str] = Field(None, max_length=500)


# ──────────────────────────────────────────────────────────────────────────
# Effective permissions resolver
# ──────────────────────────────────────────────────────────────────────────

class EffectivePermission(BaseModel):
    resource: str
    action: str
    category: str
    risk_level: str
    # Where this permission came from
    via_grant_id: str
    via_role_code: str
    scope_type: Literal["entity", "branch"]
    scope_id: str


class EffectivePermissionsResponse(BaseModel):
    user_id: str
    tenant_id: str
    total: int
    permissions: list[EffectivePermission]
    # Quick lookup helpers
    resources: list[str]           # distinct resources user can touch
    role_codes: list[str]          # distinct role codes held by user
    is_tenant_admin: bool = False  # true if any role has scope=tenant
