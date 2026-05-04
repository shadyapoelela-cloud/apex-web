"""Pilot module FastAPI routes — multi-tenant retail ERP.

Endpoints:
  Tenants:
    POST   /pilot/tenants              Create a new tenant (onboarding)
    GET    /pilot/tenants              List tenants (admin only)
    GET    /pilot/tenants/{id}         Get tenant details
    PATCH  /pilot/tenants/{id}         Update tenant
    GET    /pilot/tenants/{id}/settings
    PATCH  /pilot/tenants/{id}/settings

  Entities (per tenant):
    GET    /pilot/tenants/{tid}/entities
    POST   /pilot/tenants/{tid}/entities
    GET    /pilot/entities/{id}
    PATCH  /pilot/entities/{id}

  Branches (per entity):
    GET    /pilot/entities/{eid}/branches
    POST   /pilot/entities/{eid}/branches
    GET    /pilot/branches/{id}
    PATCH  /pilot/branches/{id}

  Currencies (per tenant):
    GET    /pilot/tenants/{tid}/currencies
    POST   /pilot/tenants/{tid}/currencies

  FX Rates (per tenant):
    GET    /pilot/tenants/{tid}/fx-rates
    POST   /pilot/tenants/{tid}/fx-rates
    GET    /pilot/tenants/{tid}/fx-rates/latest?from=SAR&to=AED

  Roles + Permissions (per tenant):
    GET    /pilot/permissions          List all system permissions
    GET    /pilot/tenants/{tid}/roles
    POST   /pilot/tenants/{tid}/roles
    GET    /pilot/roles/{id}
    PATCH  /pilot/roles/{id}
"""

from datetime import datetime, timezone, timedelta, date
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Query, Header, Path
from sqlalchemy.orm import Session
from sqlalchemy import select, and_

from app.phase1.models.platform_models import get_db, User, UserStatus
from app.phase1.routes.phase1_routes import get_current_user
from app.pilot.models import (
    Tenant, CompanySettings, TenantStatus, TenantTier,
    Entity, EntityType, EntityStatus,
    Branch, BranchType, BranchStatus,
    Currency, FxRate,
    PilotRole, PilotPermission, PilotRolePermission, UserEntityAccess, UserBranchAccess,
)
from app.pilot.schemas.tenant import (
    TenantCreate, TenantRead, TenantUpdate,
    CompanySettingsRead, CompanySettingsUpdate,
)
from app.pilot.schemas.entity import (
    EntityCreate, EntityRead, EntityUpdate,
    BranchCreate, BranchRead, BranchUpdate,
)
from app.pilot.schemas.currency import (
    CurrencyCreate, CurrencyRead, FxRateCreate, FxRateRead,
)
from app.pilot.schemas.rbac import (
    RoleCreate, RoleRead, RoleUpdate, PermissionRead,
)
from app.pilot.schemas.member import (
    MemberInvite, MemberRead, MemberDetail, MemberUpdate,
    AccessGrantRead, GrantEntityAccess, GrantBranchAccess, RevokeAccess,
    EffectivePermission, EffectivePermissionsResponse,
)
from app.phase1.services.auth_service import hash_password

import os
import secrets
import string
import logging

logger = logging.getLogger(__name__)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot"],
    dependencies=[Depends(get_current_user)],
)


# ═══════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════

def _get_tenant_or_404(db: Session, tenant_id: str) -> Tenant:
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail=f"Tenant {tenant_id} not found")
    return tenant


def _get_entity_or_404(db: Session, entity_id: str) -> Entity:
    entity = db.query(Entity).filter(Entity.id == entity_id, Entity.is_deleted == False).first()  # noqa: E712
    if not entity:
        raise HTTPException(status_code=404, detail=f"Entity {entity_id} not found")
    return entity


def _get_branch_or_404(db: Session, branch_id: str) -> Branch:
    branch = db.query(Branch).filter(Branch.id == branch_id, Branch.is_deleted == False).first()  # noqa: E712
    if not branch:
        raise HTTPException(status_code=404, detail=f"Branch {branch_id} not found")
    return branch


def _get_role_or_404(db: Session, role_id: str) -> PilotRole:
    role = db.query(PilotRole).filter(PilotRole.id == role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail=f"Role {role_id} not found")
    return role


# ═══════════════════════════════════════════════════════════════
# TENANT endpoints
# ═══════════════════════════════════════════════════════════════

@router.post("/tenants", response_model=TenantRead, status_code=201)
def create_tenant(payload: TenantCreate, db: Session = Depends(get_db)):
    """Onboard a new tenant.

    Creates:
      - Tenant row with 30-day trial
      - CompanySettings with defaults from payload
      - Seeds default currencies (SAR + primary_country's currency)
      - Seeds 12 system roles (super_admin, cfo, accountant, ...)
    """
    # Check slug unique
    existing = db.query(Tenant).filter(Tenant.slug == payload.slug).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"Tenant slug '{payload.slug}' already exists")

    # Check email not already used
    if db.query(Tenant).filter(Tenant.primary_email == payload.primary_email).first():
        raise HTTPException(status_code=409, detail="Email already registered for another tenant")

    now = datetime.now(timezone.utc)
    tenant = Tenant(
        slug=payload.slug,
        legal_name_ar=payload.legal_name_ar,
        legal_name_en=payload.legal_name_en,
        trade_name=payload.trade_name,
        primary_cr_number=payload.primary_cr_number,
        primary_vat_number=payload.primary_vat_number,
        primary_country=payload.primary_country.upper(),
        primary_email=payload.primary_email,
        primary_phone=payload.primary_phone,
        status=TenantStatus.trial.value,
        tier=payload.tier,
        trial_ends_at=now + timedelta(days=30),
        features={"zatca": True, "gosi": True, "wps": True, "uae_ct": True, "ai": True},
    )
    db.add(tenant)
    db.flush()

    # Create company settings
    settings = CompanySettings(
        tenant_id=tenant.id,
        base_currency=payload.base_currency,
        fiscal_year_start_month=payload.fiscal_year_start_month,
        default_timezone=payload.default_timezone,
    )
    db.add(settings)

    # Seed default currencies for the tenant
    _seed_default_currencies(db, tenant.id, payload.base_currency)

    # Seed system roles
    _seed_default_roles(db, tenant.id)

    db.commit()
    db.refresh(tenant)
    return tenant


@router.get("/tenants", response_model=list[TenantRead])
def list_tenants(
    limit: int = Query(50, le=200),
    offset: int = 0,
    status: Optional[str] = None,
    country: Optional[str] = None,
    db: Session = Depends(get_db),
    admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """List tenants (admin only). Requires X-Admin-Secret header.

    Fail-closed: if ADMIN_SECRET is unset on the server, the endpoint
    refuses every request instead of silently opening to the world.
    The previous inline check `if required and admin_secret != required:`
    skipped the comparison entirely when `required` was None, which
    meant any dev/staging environment missing the env var exposed
    the full tenant list publicly. (Prod was safe because main.py:58
    raises at startup if ADMIN_SECRET is missing in production.)
    """
    import os
    import secrets as _secrets
    required = os.environ.get("ADMIN_SECRET")
    if not required:
        raise HTTPException(
            status_code=500,
            detail="ADMIN_SECRET not configured on server",
        )
    # Constant-time compare — plain `!=` leaks the secret bytes via
    # response-time side channels to any attacker who can replay the
    # endpoint enough times.
    if not admin_secret or not _secrets.compare_digest(admin_secret, required):
        raise HTTPException(status_code=401, detail="admin secret required")

    q = db.query(Tenant)
    if status:
        q = q.filter(Tenant.status == status)
    if country:
        q = q.filter(Tenant.primary_country == country.upper())
    return q.order_by(Tenant.created_at.desc()).offset(offset).limit(limit).all()


@router.get("/tenants/{tenant_id}", response_model=TenantRead)
def get_tenant(tenant_id: str, db: Session = Depends(get_db)):
    return _get_tenant_or_404(db, tenant_id)


@router.patch("/tenants/{tenant_id}", response_model=TenantRead)
def update_tenant(tenant_id: str, payload: TenantUpdate, db: Session = Depends(get_db)):
    tenant = _get_tenant_or_404(db, tenant_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(tenant, field, value)
    db.commit()
    db.refresh(tenant)
    return tenant


@router.get("/tenants/{tenant_id}/settings", response_model=CompanySettingsRead)
def get_company_settings(tenant_id: str, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    s = db.query(CompanySettings).filter(CompanySettings.tenant_id == tenant_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="settings not found")
    return s


@router.patch("/tenants/{tenant_id}/settings", response_model=CompanySettingsRead)
def update_company_settings(tenant_id: str, payload: CompanySettingsUpdate, db: Session = Depends(get_db)):
    s = db.query(CompanySettings).filter(CompanySettings.tenant_id == tenant_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="settings not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(s, field, value)
    db.commit()
    db.refresh(s)
    return s


# ═══════════════════════════════════════════════════════════════
# ENTITY endpoints
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/entities", response_model=list[EntityRead])
def list_entities(tenant_id: str, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    return db.query(Entity).filter(
        Entity.tenant_id == tenant_id, Entity.is_deleted == False  # noqa: E712
    ).order_by(Entity.sort_order, Entity.code).all()


@router.post("/tenants/{tenant_id}/entities", response_model=EntityRead, status_code=201)
def create_entity(tenant_id: str, payload: EntityCreate, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)

    existing = db.query(Entity).filter(
        Entity.tenant_id == tenant_id, Entity.code == payload.code, Entity.is_deleted == False  # noqa: E712
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"entity code '{payload.code}' already used")

    entity = Entity(
        tenant_id=tenant_id,
        **payload.model_dump(exclude={"country"}),
        country=payload.country.upper(),
    )
    db.add(entity)
    db.commit()
    db.refresh(entity)
    return entity


@router.get("/entities/{entity_id}", response_model=EntityRead)
def get_entity(entity_id: str, db: Session = Depends(get_db)):
    return _get_entity_or_404(db, entity_id)


@router.patch("/entities/{entity_id}", response_model=EntityRead)
def update_entity(entity_id: str, payload: EntityUpdate, db: Session = Depends(get_db)):
    entity = _get_entity_or_404(db, entity_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(entity, field, value)
    db.commit()
    db.refresh(entity)
    return entity


@router.delete("/entities/{entity_id}", status_code=204)
def delete_entity(entity_id: str, db: Session = Depends(get_db)):
    entity = _get_entity_or_404(db, entity_id)
    entity.is_deleted = True
    entity.deleted_at = datetime.now(timezone.utc)
    db.commit()


# ═══════════════════════════════════════════════════════════════
# BRANCH endpoints
# ═══════════════════════════════════════════════════════════════

@router.get("/entities/{entity_id}/branches", response_model=list[BranchRead])
def list_branches(entity_id: str, db: Session = Depends(get_db)):
    _get_entity_or_404(db, entity_id)
    return db.query(Branch).filter(
        Branch.entity_id == entity_id, Branch.is_deleted == False  # noqa: E712
    ).order_by(Branch.sort_order, Branch.code).all()


@router.post("/entities/{entity_id}/branches", response_model=BranchRead, status_code=201)
def create_branch(entity_id: str, payload: BranchCreate, db: Session = Depends(get_db)):
    entity = _get_entity_or_404(db, entity_id)

    existing = db.query(Branch).filter(
        Branch.tenant_id == entity.tenant_id, Branch.code == payload.code, Branch.is_deleted == False  # noqa: E712
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"branch code '{payload.code}' already used")

    branch = Branch(
        tenant_id=entity.tenant_id,
        entity_id=entity_id,
        country=entity.country,  # inherits from entity
        **payload.model_dump(),
    )
    db.add(branch)
    db.commit()
    db.refresh(branch)
    return branch


@router.get("/branches/{branch_id}", response_model=BranchRead)
def get_branch(branch_id: str, db: Session = Depends(get_db)):
    return _get_branch_or_404(db, branch_id)


@router.patch("/branches/{branch_id}", response_model=BranchRead)
def update_branch(branch_id: str, payload: BranchUpdate, db: Session = Depends(get_db)):
    branch = _get_branch_or_404(db, branch_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(branch, field, value)
    db.commit()
    db.refresh(branch)
    return branch


@router.delete("/branches/{branch_id}", status_code=204)
def delete_branch(branch_id: str, db: Session = Depends(get_db)):
    branch = _get_branch_or_404(db, branch_id)
    branch.is_deleted = True
    branch.deleted_at = datetime.now(timezone.utc)
    db.commit()


# ═══════════════════════════════════════════════════════════════
# CURRENCY endpoints
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/currencies", response_model=list[CurrencyRead])
def list_currencies(tenant_id: str, active_only: bool = True, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    q = db.query(Currency).filter(Currency.tenant_id == tenant_id)
    if active_only:
        q = q.filter(Currency.is_active == True)  # noqa: E712
    return q.order_by(Currency.sort_order, Currency.code).all()


@router.post("/tenants/{tenant_id}/currencies", response_model=CurrencyRead, status_code=201)
def create_currency(tenant_id: str, payload: CurrencyCreate, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    existing = db.query(Currency).filter(
        Currency.tenant_id == tenant_id, Currency.code == payload.code.upper()
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"currency {payload.code} already exists")

    currency = Currency(tenant_id=tenant_id, **payload.model_dump(exclude={"code"}), code=payload.code.upper())
    db.add(currency)
    db.commit()
    db.refresh(currency)
    return currency


# ═══════════════════════════════════════════════════════════════
# FX RATE endpoints
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/fx-rates", response_model=list[FxRateRead])
def list_fx_rates(
    tenant_id: str,
    from_code: Optional[str] = Query(None, alias="from"),
    to_code: Optional[str] = Query(None, alias="to"),
    rate_type: Optional[str] = None,
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    _get_tenant_or_404(db, tenant_id)
    q = db.query(FxRate).filter(FxRate.tenant_id == tenant_id)
    if from_code:
        q = q.filter(FxRate.from_currency == from_code.upper())
    if to_code:
        q = q.filter(FxRate.to_currency == to_code.upper())
    if rate_type:
        q = q.filter(FxRate.rate_type == rate_type)
    return q.order_by(FxRate.effective_date.desc()).limit(limit).all()


@router.post("/tenants/{tenant_id}/fx-rates", response_model=FxRateRead, status_code=201)
def create_fx_rate(tenant_id: str, payload: FxRateCreate, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    rate = FxRate(
        tenant_id=tenant_id,
        **payload.model_dump(exclude={"from_currency", "to_currency"}),
        from_currency=payload.from_currency.upper(),
        to_currency=payload.to_currency.upper(),
    )
    db.add(rate)
    db.commit()
    db.refresh(rate)
    return rate


@router.get("/tenants/{tenant_id}/fx-rates/latest", response_model=FxRateRead)
def get_latest_fx_rate(
    tenant_id: str,
    from_code: str = Query(..., alias="from"),
    to_code: str = Query(..., alias="to"),
    rate_type: str = Query("spot"),
    db: Session = Depends(get_db),
):
    rate = db.query(FxRate).filter(
        FxRate.tenant_id == tenant_id,
        FxRate.from_currency == from_code.upper(),
        FxRate.to_currency == to_code.upper(),
        FxRate.rate_type == rate_type,
    ).order_by(FxRate.effective_date.desc()).first()
    if not rate:
        raise HTTPException(status_code=404, detail=f"no {rate_type} rate found for {from_code}→{to_code}")
    return rate


# ═══════════════════════════════════════════════════════════════
# PERMISSION + ROLE endpoints
# ═══════════════════════════════════════════════════════════════

@router.get("/permissions", response_model=list[PermissionRead])
def list_permissions(category: Optional[str] = None, db: Session = Depends(get_db)):
    q = db.query(PilotPermission)
    if category:
        q = q.filter(PilotPermission.category == category)
    return q.order_by(PilotPermission.category, PilotPermission.resource, PilotPermission.action).all()


@router.get("/tenants/{tenant_id}/roles", response_model=list[RoleRead])
def list_roles(tenant_id: str, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    return db.query(PilotRole).filter(
        PilotRole.tenant_id == tenant_id, PilotRole.is_active == True  # noqa: E712
    ).order_by(PilotRole.sort_order, PilotRole.code).all()


@router.post("/tenants/{tenant_id}/roles", response_model=RoleRead, status_code=201)
def create_role(tenant_id: str, payload: RoleCreate, db: Session = Depends(get_db)):
    _get_tenant_or_404(db, tenant_id)
    existing = db.query(PilotRole).filter(
        PilotRole.tenant_id == tenant_id, PilotRole.code == payload.code
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"role code '{payload.code}' already used")

    permission_ids = payload.permission_ids
    role_data = payload.model_dump(exclude={"permission_ids"})
    role = PilotRole(tenant_id=tenant_id, **role_data)
    db.add(role)
    db.flush()

    for pid in permission_ids:
        rp = PilotRolePermission(role_id=role.id, permission_id=pid)
        db.add(rp)

    db.commit()
    db.refresh(role)
    return role


@router.get("/roles/{role_id}", response_model=RoleRead)
def get_role(role_id: str, db: Session = Depends(get_db)):
    return _get_role_or_404(db, role_id)


@router.patch("/roles/{role_id}", response_model=RoleRead)
def update_role(role_id: str, payload: RoleUpdate, db: Session = Depends(get_db)):
    role = _get_role_or_404(db, role_id)
    if role.is_system and payload.is_active is False:
        raise HTTPException(status_code=400, detail="cannot deactivate system role")

    data = payload.model_dump(exclude_unset=True)
    permission_ids = data.pop("permission_ids", None)
    for k, v in data.items():
        setattr(role, k, v)

    # Replace permissions if provided
    if permission_ids is not None:
        db.query(PilotRolePermission).filter(PilotRolePermission.role_id == role_id).delete()
        for pid in permission_ids:
            db.add(PilotRolePermission(role_id=role_id, permission_id=pid))

    db.commit()
    db.refresh(role)
    return role


# ═══════════════════════════════════════════════════════════════
# Seed helpers (called during tenant creation)
# ═══════════════════════════════════════════════════════════════

_COMMON_CURRENCIES = [
    ("SAR", "ريال سعودي", "Saudi Riyal", "ر.س", 2, "🇸🇦", 1),
    ("AED", "درهم إماراتي", "UAE Dirham", "د.إ", 2, "🇦🇪", 2),
    ("QAR", "ريال قطري", "Qatari Riyal", "ر.ق", 2, "🇶🇦", 3),
    ("KWD", "دينار كويتي", "Kuwaiti Dinar", "د.ك", 3, "🇰🇼", 4),
    ("BHD", "دينار بحريني", "Bahraini Dinar", ".د.ب", 3, "🇧🇭", 5),
    ("OMR", "ريال عماني", "Omani Rial", "ر.ع", 3, "🇴🇲", 6),
    ("EGP", "جنيه مصري", "Egyptian Pound", "ج.م", 2, "🇪🇬", 7),
    ("USD", "دولار أمريكي", "US Dollar", "$", 2, "🇺🇸", 8),
    ("EUR", "يورو", "Euro", "€", 2, "🇪🇺", 9),
    ("GBP", "جنيه استرليني", "British Pound", "£", 2, "🇬🇧", 10),
]


def _seed_default_currencies(db: Session, tenant_id: str, base_currency: str) -> None:
    for code, name_ar, name_en, symbol, decimals, flag, order in _COMMON_CURRENCIES:
        c = Currency(
            tenant_id=tenant_id,
            code=code,
            name_ar=name_ar,
            name_en=name_en,
            symbol=symbol,
            decimal_places=decimals,
            is_active=True,
            is_base_currency=(code == base_currency.upper()),
            sort_order=order,
            emoji_flag=flag,
        )
        db.add(c)


_DEFAULT_ROLES = [
    ("super_admin", "المدير العام", "Super Admin", "tenant", {"all": True}, "#D4AF37", "admin_panel_settings", 1, True),
    ("cfo", "المدير المالي", "CFO", "tenant", {"je_limit": None, "po_limit": None}, "#1A237E", "account_balance", 2, True),
    ("accounting_manager", "مدير المحاسبة", "Accounting Manager", "tenant",
     {"je_limit": 500000, "po_limit": 100000, "currency": "SAR"}, "#4A148C", "bar_chart", 3, True),
    ("accountant", "محاسب", "Accountant", "entity",
     {"je_limit": 50000, "currency": "SAR"}, "#2E7D5B", "calculate", 4, True),
    ("country_manager", "مدير دولة", "Country Manager", "entity", {"full_entity": True}, "#1565C0", "flag", 5, True),
    ("branch_manager", "مدير فرع", "Branch Manager", "branch", {"full_branch": True}, "#D4AF37", "store", 6, True),
    ("pos_cashier", "كاشير", "POS Cashier", "branch", {"pos_only": True}, "#2E7D5B", "point_of_sale", 7, True),
    ("hr_manager", "مدير الموارد البشرية", "HR Manager", "tenant", {}, "#4A148C", "people", 8, True),
    ("warehouse_manager", "مدير المخزون", "Warehouse Manager", "entity", {}, "#E65100", "warehouse", 9, True),
    ("purchasing_manager", "مدير المشتريات", "Purchasing Manager", "entity", {"po_limit": 250000, "currency": "SAR"}, "#0277BD", "shopping_cart", 10, True),
    ("auditor", "مدقق", "Auditor", "tenant", {"read_only": True}, "#4A148C", "fact_check", 11, True),
    ("viewer", "مشاهد", "Viewer", "branch", {"read_only": True}, "#607D8B", "visibility", 12, True),
]


def _seed_default_roles(db: Session, tenant_id: str) -> None:
    for code, name_ar, name_en, scope, approval_limits, color, icon, order, is_system in _DEFAULT_ROLES:
        r = PilotRole(
            tenant_id=tenant_id,
            code=code,
            name_ar=name_ar,
            name_en=name_en,
            scope=scope,
            approval_limits=approval_limits,
            color_hex=color,
            icon=icon,
            sort_order=order,
            is_system=is_system,
            is_active=True,
        )
        db.add(r)


# ═══════════════════════════════════════════════════════════════
# MEMBERS (users with access to a tenant) — Day 2
# ═══════════════════════════════════════════════════════════════

def _gen_temp_password(length: int = 16) -> str:
    """Generate a cryptographically-random temp password for invites.

    Includes upper/lower/digit/symbol so it passes auth_service.validate_password_strength.
    The invitee must reset it on first login.
    """
    alphabet = string.ascii_letters + string.digits + "!@#$%&*"
    while True:
        pw = "".join(secrets.choice(alphabet) for _ in range(length))
        if (any(c.islower() for c in pw)
                and any(c.isupper() for c in pw)
                and any(c.isdigit() for c in pw)):
            return pw


def _collect_user_ids_for_tenant(db: Session, tenant_id: str) -> set[str]:
    """All distinct user_ids with any (active or inactive) grant in this tenant."""
    ent_ids = db.query(UserEntityAccess.user_id).filter(
        UserEntityAccess.tenant_id == tenant_id
    ).distinct().all()
    br_ids = db.query(UserBranchAccess.user_id).filter(
        UserBranchAccess.tenant_id == tenant_id
    ).distinct().all()
    return {row[0] for row in ent_ids} | {row[0] for row in br_ids}


def _member_row(db: Session, tenant_id: str, user: User) -> MemberRead:
    """Build a MemberRead with aggregated grant counts + primary role."""
    ent_count = db.query(UserEntityAccess).filter(
        UserEntityAccess.tenant_id == tenant_id,
        UserEntityAccess.user_id == user.id,
        UserEntityAccess.is_active == True,  # noqa: E712
    ).count()
    br_count = db.query(UserBranchAccess).filter(
        UserBranchAccess.tenant_id == tenant_id,
        UserBranchAccess.user_id == user.id,
        UserBranchAccess.is_active == True,  # noqa: E712
    ).count()

    # Primary role = first active grant's role, preferring tenant > entity > branch scope
    primary_role_code: Optional[str] = None
    grants = (
        db.query(UserEntityAccess, PilotRole)
        .join(PilotRole, PilotRole.id == UserEntityAccess.role_id)
        .filter(UserEntityAccess.tenant_id == tenant_id,
                UserEntityAccess.user_id == user.id,
                UserEntityAccess.is_active == True)  # noqa: E712
        .all()
    )
    if grants:
        # prefer tenant-scoped, then entity-scoped
        grants.sort(key=lambda g: {"tenant": 0, "entity": 1, "branch": 2}.get(g[1].scope, 9))
        primary_role_code = grants[0][1].code
    else:
        brgrants = (
            db.query(UserBranchAccess, PilotRole)
            .join(PilotRole, PilotRole.id == UserBranchAccess.role_id)
            .filter(UserBranchAccess.tenant_id == tenant_id,
                    UserBranchAccess.user_id == user.id,
                    UserBranchAccess.is_active == True)  # noqa: E712
            .first()
        )
        if brgrants:
            primary_role_code = brgrants[1].code

    return MemberRead(
        user_id=user.id,
        email=user.email,
        display_name=user.display_name,
        mobile=user.mobile,
        language=user.language,
        status=user.status,
        last_login_at=user.last_login_at,
        entity_grants=ent_count,
        branch_grants=br_count,
        primary_role_code=primary_role_code,
    )


@router.get("/tenants/{tenant_id}/members", response_model=list[MemberRead])
def list_members(
    tenant_id: str,
    active_only: bool = Query(True),
    db: Session = Depends(get_db),
):
    """List all users who have at least one access grant in this tenant."""
    _get_tenant_or_404(db, tenant_id)
    user_ids = _collect_user_ids_for_tenant(db, tenant_id)
    if not user_ids:
        return []
    q = db.query(User).filter(User.id.in_(list(user_ids)))
    if active_only:
        q = q.filter(User.is_deleted == False)  # noqa: E712
    users = q.order_by(User.display_name).all()
    return [_member_row(db, tenant_id, u) for u in users]


@router.post("/tenants/{tenant_id}/members", response_model=MemberDetail, status_code=201)
def invite_member(
    tenant_id: str,
    payload: MemberInvite,
    db: Session = Depends(get_db),
):
    """Invite a user to the tenant.

    - If email already exists in phase1 User table → reuse account.
    - Otherwise → create a new User with a random temp password.
      (TODO: email the invite link + require password reset on first login.)
    - Always creates the initial access grant.
    """
    tenant = _get_tenant_or_404(db, tenant_id)

    # Validate role belongs to this tenant
    role = db.query(PilotRole).filter(
        PilotRole.id == payload.role_id,
        PilotRole.tenant_id == tenant_id,
    ).first()
    if not role:
        raise HTTPException(status_code=400, detail="Role not found in this tenant")

    # Validate scope target
    if payload.scope == "entity":
        if not payload.entity_id:
            raise HTTPException(status_code=400, detail="entity_id is required when scope=entity")
        entity = db.query(Entity).filter(
            Entity.id == payload.entity_id,
            Entity.tenant_id == tenant_id,
            Entity.is_deleted == False,  # noqa: E712
        ).first()
        if not entity:
            raise HTTPException(status_code=400, detail="Entity not found in this tenant")
    else:  # branch
        if not payload.branch_id:
            raise HTTPException(status_code=400, detail="branch_id is required when scope=branch")
        branch = db.query(Branch).filter(
            Branch.id == payload.branch_id,
            Branch.tenant_id == tenant_id,
            Branch.is_deleted == False,  # noqa: E712
        ).first()
        if not branch:
            raise HTTPException(status_code=400, detail="Branch not found in this tenant")

    # Find or create User
    email_str = str(payload.email).lower()
    user = db.query(User).filter(User.email == email_str).first()
    created_new = False
    if not user:
        # Generate username from email local-part + short suffix
        local = email_str.split("@")[0]
        base_username = "".join(ch for ch in local if ch.isalnum())[:20] or "user"
        username = base_username
        i = 1
        while db.query(User).filter(User.username == username).first():
            i += 1
            username = f"{base_username}{i}"

        temp_pw = _gen_temp_password()
        user = User(
            username=username,
            email=email_str,
            mobile=payload.mobile,
            display_name=payload.display_name,
            password_hash=hash_password(temp_pw),
            status=UserStatus.pending_verification.value,
            language=payload.language,
            timezone="Asia/Riyadh",
        )
        db.add(user)
        db.flush()
        created_new = True
        # NOTE: in production, email temp_pw via invite link (not logged).

    # Create initial access grant
    if payload.scope == "entity":
        # Idempotency check
        existing = db.query(UserEntityAccess).filter(
            UserEntityAccess.user_id == user.id,
            UserEntityAccess.entity_id == payload.entity_id,
            UserEntityAccess.role_id == payload.role_id,
        ).first()
        if existing:
            if not existing.is_active:
                existing.is_active = True
                existing.revoked_at = None
                existing.revoke_reason = None
        else:
            db.add(UserEntityAccess(
                tenant_id=tenant_id,
                user_id=user.id,
                entity_id=payload.entity_id,
                role_id=payload.role_id,
                can_delegate=payload.can_delegate,
                expires_at=payload.expires_at,
            ))
    else:
        existing = db.query(UserBranchAccess).filter(
            UserBranchAccess.user_id == user.id,
            UserBranchAccess.branch_id == payload.branch_id,
            UserBranchAccess.role_id == payload.role_id,
        ).first()
        if existing:
            if not existing.is_active:
                existing.is_active = True
                existing.revoked_at = None
        else:
            db.add(UserBranchAccess(
                tenant_id=tenant_id,
                user_id=user.id,
                branch_id=payload.branch_id,
                role_id=payload.role_id,
                expires_at=payload.expires_at,
            ))
    db.commit()
    db.refresh(user)

    # إرسال بريد دعوة فعلي — يعمل مع أي EMAIL_BACKEND (console/smtp/sendgrid)
    try:
        from app.core.email_service import send_email
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        tenant_name = tenant.legal_name_ar if tenant else 'APEX Pilot'
        login_url = os.environ.get(
            'APP_LOGIN_URL',
            'https://shadyapoelela-cloud.github.io/apex-web/#/login',
        )
        subject_ar = f'دعوة للانضمام إلى {tenant_name}'
        body_html = f'''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head><meta charset="UTF-8"><title>{subject_ar}</title></head>
<body style="font-family: Tahoma, Arial; background: #f5f5f5; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px;">
    <h2 style="color: #D4AF37; border-bottom: 2px solid #D4AF37; padding-bottom: 10px;">
      مرحباً {payload.display_name} 👋
    </h2>
    <p style="color: #333; font-size: 14px; line-height: 1.7;">
      تمّت دعوتك للانضمام إلى <strong>{tenant_name}</strong> على منصة APEX Pilot
      — نظام إدارة الأعمال والمحاسبة الذكي.
    </p>
    <div style="background: #f9f9f9; border-right: 3px solid #D4AF37; padding: 15px; margin: 20px 0;">
      <p style="margin: 5px 0;"><strong>بريدك:</strong> {payload.email}</p>
      <p style="margin: 5px 0;"><strong>كلمة المرور المؤقتة:</strong>
        <code style="background: #fff3cd; padding: 4px 8px; border-radius: 4px; font-family: monospace;">{temp_pw if created_new else "(استخدم كلمة مرورك الحالية)"}</code>
      </p>
    </div>
    <p style="color: #666; font-size: 13px;">
      {"⚠ يُرجى تغيير كلمة المرور عند أول تسجيل دخول." if created_new else ""}
    </p>
    <p style="text-align: center; margin: 30px 0;">
      <a href="{login_url}" style="background: #D4AF37; color: black; padding: 12px 30px;
         border-radius: 6px; text-decoration: none; font-weight: bold; display: inline-block;">
        🔓 تسجيل الدخول الآن
      </a>
    </p>
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #999; font-size: 11px; text-align: center;">
      هذه رسالة تلقائية من APEX Pilot · لا تردّ عليها.
    </p>
  </div>
</body>
</html>
'''
        body_text = (
            f"مرحباً {payload.display_name},\n\n"
            f"تمّت دعوتك للانضمام إلى {tenant_name} على APEX Pilot.\n\n"
            f"البريد: {payload.email}\n"
            f"كلمة المرور المؤقتة: {temp_pw if created_new else '(استخدم كلمة مرورك الحالية)'}\n\n"
            f"سجّل دخولك هنا: {login_url}\n\n"
            f"{'⚠ يُرجى تغيير كلمة المرور عند أول تسجيل دخول.' if created_new else ''}\n"
        )
        email_result = send_email(
            payload.email, subject_ar, body_html, body_text,
        )
        logger.info(
            "Invite email sent to %s (backend=%s, result=%s)",
            payload.email, email_result.get("backend"), email_result.get("status"),
        )
    except Exception as e:
        # لا نفشل الـ invite لو البريد فشل — الحساب أُنشئ، المستخدم يأخذ الباس يدوياً
        logger.error("Failed to send invite email to %s: %s", payload.email, e)

    return _build_member_detail(db, tenant_id, user)


def _build_member_detail(db: Session, tenant_id: str, user: User) -> MemberDetail:
    """Compose a MemberDetail with all grants resolved to labels."""
    grants: list[AccessGrantRead] = []

    ent_rows = (
        db.query(UserEntityAccess, Entity, PilotRole)
        .join(Entity, Entity.id == UserEntityAccess.entity_id)
        .join(PilotRole, PilotRole.id == UserEntityAccess.role_id)
        .filter(UserEntityAccess.tenant_id == tenant_id,
                UserEntityAccess.user_id == user.id)
        .all()
    )
    for ua, entity, role in ent_rows:
        grants.append(AccessGrantRead(
            grant_id=ua.id,
            grant_type="entity",
            scope_id=entity.id,
            scope_code=entity.code,
            scope_label=entity.name_en or entity.name_ar,
            role_id=role.id,
            role_code=role.code,
            role_name_ar=role.name_ar,
            granted_at=ua.granted_at,
            expires_at=ua.expires_at,
            can_delegate=ua.can_delegate,
            is_active=ua.is_active,
        ))

    br_rows = (
        db.query(UserBranchAccess, Branch, PilotRole)
        .join(Branch, Branch.id == UserBranchAccess.branch_id)
        .join(PilotRole, PilotRole.id == UserBranchAccess.role_id)
        .filter(UserBranchAccess.tenant_id == tenant_id,
                UserBranchAccess.user_id == user.id)
        .all()
    )
    for ba, branch, role in br_rows:
        grants.append(AccessGrantRead(
            grant_id=ba.id,
            grant_type="branch",
            scope_id=branch.id,
            scope_code=branch.code,
            scope_label=branch.name_en or branch.name_ar,
            role_id=role.id,
            role_code=role.code,
            role_name_ar=role.name_ar,
            granted_at=ba.granted_at,
            expires_at=ba.expires_at,
            can_delegate=False,
            is_active=ba.is_active,
        ))

    # Sort: active first, then by granted_at desc
    grants.sort(key=lambda g: (not g.is_active, -g.granted_at.timestamp()))

    return MemberDetail(
        user_id=user.id,
        email=user.email,
        display_name=user.display_name,
        mobile=user.mobile,
        language=user.language,
        status=user.status,
        last_login_at=user.last_login_at,
        grants=grants,
    )


@router.get("/tenants/{tenant_id}/members/{user_id}", response_model=MemberDetail)
def get_member(tenant_id: str, user_id: str, db: Session = Depends(get_db)):
    """Get a single member with all their access grants resolved."""
    _get_tenant_or_404(db, tenant_id)
    # Verify user has at least one grant here (tenant-isolation check)
    has_grant = (
        db.query(UserEntityAccess).filter(
            UserEntityAccess.tenant_id == tenant_id,
            UserEntityAccess.user_id == user_id,
        ).first()
        or db.query(UserBranchAccess).filter(
            UserBranchAccess.tenant_id == tenant_id,
            UserBranchAccess.user_id == user_id,
        ).first()
    )
    if not has_grant:
        raise HTTPException(status_code=404, detail="Member not found in this tenant")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()  # noqa: E712
    if not user:
        raise HTTPException(status_code=404, detail="User account not found")
    return _build_member_detail(db, tenant_id, user)


@router.patch("/tenants/{tenant_id}/members/{user_id}", response_model=MemberDetail)
def update_member(
    tenant_id: str,
    user_id: str,
    payload: MemberUpdate,
    db: Session = Depends(get_db),
):
    """Update display_name / mobile / language / status on the phase1 User.

    Only allowed for users who are members of this tenant (isolation).
    """
    _get_tenant_or_404(db, tenant_id)
    if user_id not in _collect_user_ids_for_tenant(db, tenant_id):
        raise HTTPException(status_code=404, detail="Member not found in this tenant")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()  # noqa: E712
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.display_name is not None:
        user.display_name = payload.display_name
    if payload.mobile is not None:
        user.mobile = payload.mobile
    if payload.language is not None:
        user.language = payload.language
    if payload.status is not None:
        user.status = payload.status

    db.commit()
    db.refresh(user)
    return _build_member_detail(db, tenant_id, user)


@router.delete("/tenants/{tenant_id}/members/{user_id}", status_code=204)
def remove_member(
    tenant_id: str,
    user_id: str,
    reason: Optional[str] = Query(None, max_length=500),
    db: Session = Depends(get_db),
):
    """Revoke ALL access grants for a user in this tenant (soft).

    Does NOT delete the phase1 User — they may still belong to other tenants
    or have a platform-level account. Sets is_active=False on every grant
    and records revoke_at + reason.
    """
    _get_tenant_or_404(db, tenant_id)
    now = datetime.now(timezone.utc)

    count = 0
    for grant in db.query(UserEntityAccess).filter(
        UserEntityAccess.tenant_id == tenant_id,
        UserEntityAccess.user_id == user_id,
        UserEntityAccess.is_active == True,  # noqa: E712
    ).all():
        grant.is_active = False
        grant.revoked_at = now
        grant.revoke_reason = reason
        count += 1
    for grant in db.query(UserBranchAccess).filter(
        UserBranchAccess.tenant_id == tenant_id,
        UserBranchAccess.user_id == user_id,
        UserBranchAccess.is_active == True,  # noqa: E712
    ).all():
        grant.is_active = False
        grant.revoked_at = now
        count += 1

    if count == 0:
        raise HTTPException(status_code=404, detail="No active grants found for this user in this tenant")

    db.commit()
    return None


# ═══════════════════════════════════════════════════════════════
# RBAC GRANTS — direct assignment endpoints
# ═══════════════════════════════════════════════════════════════

@router.post("/tenants/{tenant_id}/members/{user_id}/entity-access", response_model=AccessGrantRead, status_code=201)
def grant_entity_access(
    tenant_id: str,
    user_id: str,
    payload: GrantEntityAccess,
    db: Session = Depends(get_db),
):
    """Grant a user access to an Entity with a Role (entity-level = all branches in it)."""
    _get_tenant_or_404(db, tenant_id)

    entity = db.query(Entity).filter(
        Entity.id == payload.entity_id,
        Entity.tenant_id == tenant_id,
        Entity.is_deleted == False,  # noqa: E712
    ).first()
    if not entity:
        raise HTTPException(status_code=400, detail="Entity not found in this tenant")

    role = db.query(PilotRole).filter(
        PilotRole.id == payload.role_id,
        PilotRole.tenant_id == tenant_id,
    ).first()
    if not role:
        raise HTTPException(status_code=400, detail="Role not found in this tenant")

    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()  # noqa: E712
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Upsert — reactivate if exists
    existing = db.query(UserEntityAccess).filter(
        UserEntityAccess.user_id == user_id,
        UserEntityAccess.entity_id == payload.entity_id,
        UserEntityAccess.role_id == payload.role_id,
    ).first()
    if existing:
        existing.is_active = True
        existing.revoked_at = None
        existing.revoke_reason = None
        existing.can_delegate = payload.can_delegate
        existing.expires_at = payload.expires_at
        grant = existing
    else:
        grant = UserEntityAccess(
            tenant_id=tenant_id,
            user_id=user_id,
            entity_id=payload.entity_id,
            role_id=payload.role_id,
            can_delegate=payload.can_delegate,
            expires_at=payload.expires_at,
        )
        db.add(grant)
    db.commit()
    db.refresh(grant)

    return AccessGrantRead(
        grant_id=grant.id,
        grant_type="entity",
        scope_id=entity.id,
        scope_code=entity.code,
        scope_label=entity.name_en or entity.name_ar,
        role_id=role.id,
        role_code=role.code,
        role_name_ar=role.name_ar,
        granted_at=grant.granted_at,
        expires_at=grant.expires_at,
        can_delegate=grant.can_delegate,
        is_active=grant.is_active,
    )


@router.post("/tenants/{tenant_id}/members/{user_id}/branch-access", response_model=AccessGrantRead, status_code=201)
def grant_branch_access(
    tenant_id: str,
    user_id: str,
    payload: GrantBranchAccess,
    db: Session = Depends(get_db),
):
    """Grant a user access to a single Branch with a Role."""
    _get_tenant_or_404(db, tenant_id)

    branch = db.query(Branch).filter(
        Branch.id == payload.branch_id,
        Branch.tenant_id == tenant_id,
        Branch.is_deleted == False,  # noqa: E712
    ).first()
    if not branch:
        raise HTTPException(status_code=400, detail="Branch not found in this tenant")

    role = db.query(PilotRole).filter(
        PilotRole.id == payload.role_id,
        PilotRole.tenant_id == tenant_id,
    ).first()
    if not role:
        raise HTTPException(status_code=400, detail="Role not found in this tenant")

    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()  # noqa: E712
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    existing = db.query(UserBranchAccess).filter(
        UserBranchAccess.user_id == user_id,
        UserBranchAccess.branch_id == payload.branch_id,
        UserBranchAccess.role_id == payload.role_id,
    ).first()
    if existing:
        existing.is_active = True
        existing.revoked_at = None
        existing.expires_at = payload.expires_at
        grant = existing
    else:
        grant = UserBranchAccess(
            tenant_id=tenant_id,
            user_id=user_id,
            branch_id=payload.branch_id,
            role_id=payload.role_id,
            expires_at=payload.expires_at,
        )
        db.add(grant)
    db.commit()
    db.refresh(grant)

    return AccessGrantRead(
        grant_id=grant.id,
        grant_type="branch",
        scope_id=branch.id,
        scope_code=branch.code,
        scope_label=branch.name_en or branch.name_ar,
        role_id=role.id,
        role_code=role.code,
        role_name_ar=role.name_ar,
        granted_at=grant.granted_at,
        expires_at=grant.expires_at,
        can_delegate=False,
        is_active=grant.is_active,
    )


@router.delete("/tenants/{tenant_id}/entity-access/{grant_id}", status_code=204)
def revoke_entity_access(
    tenant_id: str,
    grant_id: str,
    reason: Optional[str] = Query(None, max_length=500),
    db: Session = Depends(get_db),
):
    """Revoke a specific entity-level access grant (soft)."""
    _get_tenant_or_404(db, tenant_id)
    grant = db.query(UserEntityAccess).filter(
        UserEntityAccess.id == grant_id,
        UserEntityAccess.tenant_id == tenant_id,
    ).first()
    if not grant:
        raise HTTPException(status_code=404, detail="Entity access grant not found")
    if not grant.is_active:
        return None  # idempotent
    grant.is_active = False
    grant.revoked_at = datetime.now(timezone.utc)
    grant.revoke_reason = reason
    db.commit()
    return None


@router.delete("/tenants/{tenant_id}/branch-access/{grant_id}", status_code=204)
def revoke_branch_access(
    tenant_id: str,
    grant_id: str,
    db: Session = Depends(get_db),
):
    """Revoke a specific branch-level access grant (soft)."""
    _get_tenant_or_404(db, tenant_id)
    grant = db.query(UserBranchAccess).filter(
        UserBranchAccess.id == grant_id,
        UserBranchAccess.tenant_id == tenant_id,
    ).first()
    if not grant:
        raise HTTPException(status_code=404, detail="Branch access grant not found")
    if not grant.is_active:
        return None
    grant.is_active = False
    grant.revoked_at = datetime.now(timezone.utc)
    db.commit()
    return None


# ═══════════════════════════════════════════════════════════════
# EFFECTIVE PERMISSIONS — resolver
# ═══════════════════════════════════════════════════════════════

@router.get(
    "/tenants/{tenant_id}/members/{user_id}/effective-permissions",
    response_model=EffectivePermissionsResponse,
)
def get_effective_permissions(
    tenant_id: str,
    user_id: str,
    db: Session = Depends(get_db),
):
    """Resolve the full set of permissions a user effectively holds in this tenant.

    Walks every active, non-expired access grant (both entity and branch),
    flattens each grant's role → permissions, and de-duplicates while
    preserving provenance (which grant/role brought which permission).

    Expired grants (expires_at < now) are treated as inactive.
    """
    _get_tenant_or_404(db, tenant_id)

    now = datetime.now(timezone.utc)
    results: list[EffectivePermission] = []
    seen: set[tuple[str, str]] = set()  # (resource, action) dedup
    role_codes: set[str] = set()
    is_tenant_admin = False

    # Entity-scoped grants
    ent_grants = (
        db.query(UserEntityAccess, PilotRole)
        .join(PilotRole, PilotRole.id == UserEntityAccess.role_id)
        .filter(
            UserEntityAccess.tenant_id == tenant_id,
            UserEntityAccess.user_id == user_id,
            UserEntityAccess.is_active == True,  # noqa: E712
        )
        .all()
    )
    for ua, role in ent_grants:
        if ua.expires_at and ua.expires_at < now:
            continue
        role_codes.add(role.code)
        if role.scope == "tenant":
            is_tenant_admin = True
        perms = (
            db.query(PilotPermission)
            .join(PilotRolePermission, PilotRolePermission.permission_id == PilotPermission.id)
            .filter(PilotRolePermission.role_id == role.id)
            .all()
        )
        for p in perms:
            key = (p.resource, p.action)
            if key in seen:
                continue
            seen.add(key)
            results.append(EffectivePermission(
                resource=p.resource,
                action=p.action,
                category=p.category,
                risk_level=p.risk_level,
                via_grant_id=ua.id,
                via_role_code=role.code,
                scope_type="entity",
                scope_id=ua.entity_id,
            ))

    # Branch-scoped grants
    br_grants = (
        db.query(UserBranchAccess, PilotRole)
        .join(PilotRole, PilotRole.id == UserBranchAccess.role_id)
        .filter(
            UserBranchAccess.tenant_id == tenant_id,
            UserBranchAccess.user_id == user_id,
            UserBranchAccess.is_active == True,  # noqa: E712
        )
        .all()
    )
    for ba, role in br_grants:
        if ba.expires_at and ba.expires_at < now:
            continue
        role_codes.add(role.code)
        perms = (
            db.query(PilotPermission)
            .join(PilotRolePermission, PilotRolePermission.permission_id == PilotPermission.id)
            .filter(PilotRolePermission.role_id == role.id)
            .all()
        )
        for p in perms:
            key = (p.resource, p.action)
            if key in seen:
                continue
            seen.add(key)
            results.append(EffectivePermission(
                resource=p.resource,
                action=p.action,
                category=p.category,
                risk_level=p.risk_level,
                via_grant_id=ba.id,
                via_role_code=role.code,
                scope_type="branch",
                scope_id=ba.branch_id,
            ))

    resources = sorted({p.resource for p in results})

    return EffectivePermissionsResponse(
        user_id=user_id,
        tenant_id=tenant_id,
        total=len(results),
        permissions=results,
        resources=resources,
        role_codes=sorted(role_codes),
        is_tenant_admin=is_tenant_admin,
    )


# ═══════════════════════════════════════════════════════════════
# Health
# ═══════════════════════════════════════════════════════════════

@router.get("/health")
def pilot_health(db: Session = Depends(get_db)):
    """Pilot module health check — الآن مع DB + counts.

    يُستخدم للـ uptime monitoring و dashboards. يُرجع:
        • حالة الـ DB
        • عدد tenants/entities/posts (للإحصاء)
        • النسخة والوقت
    """
    checks = {
        "status": "ok",
        "module": "pilot",
        "version": "1.1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    try:
        from sqlalchemy import text
        # Simple query لفحص الاتصال
        db.execute(text("SELECT 1"))
        checks["database"] = "ok"
        # إحصاءات سريعة (cheap queries على الـ indexes)
        try:
            checks["stats"] = {
                "tenants": db.query(Tenant).filter(
                    Tenant.is_deleted == False  # noqa: E712
                ).count(),
                "entities": db.query(Entity).filter(
                    Entity.is_deleted == False  # noqa: E712
                ).count(),
            }
        except Exception:
            # الإحصاءات اختيارية — الأهم الـ DB check
            pass
    except Exception as e:
        checks["status"] = "degraded"
        checks["database"] = f"error: {type(e).__name__}"
    return checks
