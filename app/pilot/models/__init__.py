"""Pilot models package."""

from .tenant import Tenant, CompanySettings, TenantStatus, TenantTier
from .entity import Entity, EntityType, EntityStatus, Branch, BranchType, BranchStatus
from .currency import Currency, FxRate
from .rbac import PilotRole, PilotPermission, PilotRolePermission, UserEntityAccess, UserBranchAccess, RoleScope

# Backward-compat aliases (used by early route code)
Role = PilotRole
Permission = PilotPermission
RolePermission = PilotRolePermission

__all__ = [
    "Tenant",
    "CompanySettings",
    "TenantStatus",
    "TenantTier",
    "Entity",
    "EntityType",
    "EntityStatus",
    "Branch",
    "BranchType",
    "BranchStatus",
    "Currency",
    "FxRate",
    "PilotRole",
    "PilotPermission",
    "PilotRolePermission",
    "UserEntityAccess",
    "UserBranchAccess",
    "RoleScope",
    # aliases
    "Role",
    "Permission",
    "RolePermission",
]
