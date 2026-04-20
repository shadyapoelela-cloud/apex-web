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

from app.phase1.models.platform_models import get_db
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

router = APIRouter(prefix="/pilot", tags=["pilot"])


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
    """List tenants (admin only). Requires X-Admin-Secret header in production."""
    import os
    required = os.environ.get("ADMIN_SECRET")
    if required and admin_secret != required:
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
# Health
# ═══════════════════════════════════════════════════════════════

@router.get("/health")
def pilot_health():
    """Pilot module health check."""
    return {
        "status": "ok",
        "module": "pilot",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
