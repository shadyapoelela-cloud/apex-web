"""RBAC (Role-Based Access Control) models.

Design:
  - Role is a collection of Permissions.
  - Permission is a tuple (resource, action) like ("journal_entry", "approve").
  - Users are granted Roles at two levels:
      * Entity level (access to ALL branches within the legal company)
      * Branch level (access only to specific branches)

Example role assignments for the clothing customer:
  • "المدير المالي" → Role `CFO` at Tenant level (sees all 6 entities)
  • "مدير الشركة السعودية" → Role `Country Manager` at Entity "SA" level
  • "مدير فرع دبي مول" → Role `Branch Manager` at Branch "DXB-DUBAI-MALL"
  • "كاشير الدمام" → Role `POS Cashier` at Branch "SA-DAMMAM" only

Permissions resources include:
  tenant_settings, entity, branch, user, role, currency, fx_rate,
  journal_entry, gl_account, cost_center, profit_center,
  product, variant, warehouse, stock, barcode, price_list,
  pos_session, pos_transaction,
  purchase_order, purchase_invoice, vendor,
  sale_order, invoice, customer, credit_note,
  payroll, employee, leave, payment,
  report, dashboard, document,
  zatca, gosi, wps, vat_return
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class RoleScope(str, enum.Enum):
    """Scope at which a role can be assigned."""
    tenant = "tenant"    # tenant-wide (e.g., Super Admin, CFO)
    entity = "entity"    # one legal company (e.g., Country Manager SA)
    branch = "branch"    # one physical branch (e.g., Store Manager, Cashier)


class Role(Base):
    """A named collection of permissions."""
    __tablename__ = "pilot_roles"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(50), nullable=False)  # super_admin, cfo, cashier, ...
    name_ar = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=True)
    description_ar = Column(String(500), nullable=True)

    # Which scope is this role designed for
    scope = Column(String(20), nullable=False, default=RoleScope.branch.value)

    # System roles cannot be deleted / renamed
    is_system = Column(Boolean, nullable=False, default=False)
    is_active = Column(Boolean, nullable=False, default=True)

    # Approval limits for this role (when it's approving JEs, POs, etc.)
    # Example: {"je_limit": 500000, "po_limit": 100000, "currency": "SAR"}
    approval_limits = Column(JSON, nullable=False, default=dict)

    # Display
    color_hex = Column(String(7), nullable=True)  # UI badge color
    icon = Column(String(50), nullable=True)      # icon name
    sort_order = Column(Integer, nullable=False, default=0)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    permissions = relationship("RolePermission", back_populates="role", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_role_tenant_code"),
        Index("ix_pilot_roles_tenant_active", "tenant_id", "is_active"),
    )


class Permission(Base):
    """Master list of possible (resource, action) pairs. Seeded, not user-created."""
    __tablename__ = "pilot_permissions"

    id = Column(String(36), primary_key=True, default=gen_uuid)

    # resource = entity type, action = verb
    resource = Column(String(50), nullable=False)  # journal_entry, product, ...
    action = Column(String(30), nullable=False)    # view, create, edit, delete, approve, post, reverse

    # Human-readable
    name_ar = Column(String(100), nullable=False)  # "اعتماد قيد يومية"
    name_en = Column(String(100), nullable=False)
    description_ar = Column(String(500), nullable=True)

    # Grouping for UI
    category = Column(String(50), nullable=False, default="general")  # finance, sales, hr, ...

    # Risk level (for sensitive actions)
    risk_level = Column(String(20), nullable=False, default="normal")  # normal | sensitive | critical

    __table_args__ = (
        UniqueConstraint("resource", "action", name="uq_pilot_permission_resource_action"),
        Index("ix_pilot_permissions_category", "category"),
    )


class RolePermission(Base):
    """Join table: which permissions does a role include."""
    __tablename__ = "pilot_role_permissions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    role_id = Column(String(36), ForeignKey("pilot_roles.id", ondelete="CASCADE"), nullable=False)
    permission_id = Column(String(36), ForeignKey("pilot_permissions.id", ondelete="CASCADE"), nullable=False)

    # Extra constraints per assignment (optional)
    # e.g., this role can approve JEs but only up to 500K SAR
    constraint_json = Column(JSON, nullable=False, default=dict)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    role = relationship("Role", back_populates="permissions")
    permission = relationship("Permission")

    __table_args__ = (
        UniqueConstraint("role_id", "permission_id", name="uq_pilot_role_permission"),
    )


class UserEntityAccess(Base):
    """Grants a user access to a specific Entity (legal company) with a Role.

    If a user has entity-level access, they automatically have access to
    ALL branches within that entity (unless explicitly denied).
    """
    __tablename__ = "pilot_user_entity_access"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), nullable=False, index=True)  # references phase1 User.id
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False)
    role_id = Column(String(36), ForeignKey("pilot_roles.id", ondelete="RESTRICT"), nullable=False)

    # Access can be time-limited
    granted_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    granted_by_user_id = Column(String(36), nullable=True)

    # Can this user further grant this role to others
    can_delegate = Column(Boolean, nullable=False, default=False)

    is_active = Column(Boolean, nullable=False, default=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    revoked_by_user_id = Column(String(36), nullable=True)
    revoke_reason = Column(String(500), nullable=True)

    __table_args__ = (
        UniqueConstraint("user_id", "entity_id", "role_id", name="uq_pilot_user_entity_role"),
        Index("ix_pilot_user_entity_access_lookup", "user_id", "is_active"),
    )


class UserBranchAccess(Base):
    """Grants a user access to a specific Branch with a Role.

    Used when a user should only access certain branches within an entity,
    not the whole entity. Example: a cashier at one specific store.
    """
    __tablename__ = "pilot_user_branch_access"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), nullable=False, index=True)
    branch_id = Column(String(36), ForeignKey("pilot_branches.id", ondelete="CASCADE"), nullable=False)
    role_id = Column(String(36), ForeignKey("pilot_roles.id", ondelete="RESTRICT"), nullable=False)

    granted_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    granted_by_user_id = Column(String(36), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    revoked_by_user_id = Column(String(36), nullable=True)

    __table_args__ = (
        UniqueConstraint("user_id", "branch_id", "role_id", name="uq_pilot_user_branch_role"),
        Index("ix_pilot_user_branch_access_lookup", "user_id", "is_active"),
    )
