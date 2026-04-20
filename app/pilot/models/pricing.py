"""Price List models — multi-currency, per-branch, per-season pricing.

Design:

  PriceList  (header)
    ├── code, currency, season, is_active
    ├── scope: tenant / entity / branch / customer_group
    ├── validity window: valid_from + valid_to
    └── priority: higher number wins if multiple lists cover the same SKU
                  (resolver picks the highest-priority active list at the
                   point-of-sale time)

  PriceListItem (line)
    ├── price_list_id → PriceList
    ├── variant_id → ProductVariant
    ├── unit_price, unit_cost (optional override)
    ├── min_qty for volume tiers
    └── promo flags: promo_name, promo_discount_pct, badge_text_ar

Real-world scenarios the model supports:

  "قائمة أسعار الصيف 2026 — السعودية"        (SA summer prices, SAR)
  "قائمة أسعار الشتاء 2026 — الإمارات"       (UAE winter prices, AED)
  "عروض رمضان — فرع الرياض بانوراما"         (Ramadan promos, 1 branch only)
  "أسعار التجزئة"                              (Default retail list)
  "أسعار الجملة — عميل VIP"                   (Wholesale for VIP customer)

Resolver algorithm (called from POS):
  Given (variant_id, branch_id, at_time=now):
    1. Find all ACTIVE PriceLists whose validity window covers at_time
       AND whose scope includes this branch (branch/entity/tenant level).
    2. Filter to those having a PriceListItem for this variant.
    3. Sort by priority DESC, then valid_from DESC.
    4. Return the first match — that's the active price.
  If no match → fall back to variant.list_price.

POS typically shows a "Summer Promo" badge when the winning price comes
from a list with a promo_discount_pct set.
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, Date, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class PriceListScope(str, enum.Enum):
    tenant = "tenant"                   # applies to all branches in the tenant
    entity = "entity"                   # applies to all branches in one entity
    branch = "branch"                   # applies to specific branches only
    customer_group = "customer_group"   # applies when a certain customer is at POS


class PriceListKind(str, enum.Enum):
    retail = "retail"          # سعر التجزئة الافتراضي
    wholesale = "wholesale"    # أسعار الجملة
    promo = "promo"            # عرض ترويجي محدود بالوقت
    contract = "contract"      # عقد مع عميل معيّن
    staff = "staff"            # خصومات الموظفين


class Season(str, enum.Enum):
    spring = "spring"
    summer = "summer"
    fall = "fall"
    winter = "winter"
    ramadan = "ramadan"
    eid = "eid"
    back_to_school = "back_to_school"
    black_friday = "black_friday"
    year_round = "year_round"


class PriceListStatus(str, enum.Enum):
    draft = "draft"
    active = "active"
    expired = "expired"
    archived = "archived"


class PriceList(Base):
    """A named pricing schedule."""
    __tablename__ = "pilot_price_lists"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(50), nullable=False)              # SA-RETAIL-SUMMER-2026
    name_ar = Column(String(255), nullable=False)          # قائمة أسعار الصيف 2026
    name_en = Column(String(255), nullable=True)
    description_ar = Column(Text, nullable=True)

    # Classification
    kind = Column(String(30), nullable=False, default=PriceListKind.retail.value)
    season = Column(String(30), nullable=False, default=Season.year_round.value)

    # Currency — all lines are in this currency
    currency = Column(String(3), nullable=False)           # SAR, AED, QAR, ...

    # Scope
    scope = Column(String(30), nullable=False, default=PriceListScope.tenant.value)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=True)
    # For branch-scoped: see PriceListBranch join table below
    customer_group_code = Column(String(50), nullable=True)   # for customer_group scope

    # Validity window
    valid_from = Column(Date, nullable=False, index=True)
    valid_to = Column(Date, nullable=True, index=True)      # null = open-ended

    # Resolution priority (higher wins)
    priority = Column(Integer, nullable=False, default=100)

    # Status
    status = Column(String(20), nullable=False, default=PriceListStatus.draft.value)
    is_active = Column(Boolean, nullable=False, default=False)

    # Promo metadata (applies to all items in this list unless item overrides)
    is_promo = Column(Boolean, nullable=False, default=False)
    promo_name_ar = Column(String(100), nullable=True)     # "عرض الصيف 30% خصم"
    promo_badge_text_ar = Column(String(50), nullable=True)  # "SALE", "50% OFF"
    promo_color_hex = Column(String(7), nullable=True)

    # Tax handling
    # Are line prices tax-inclusive (common in SA retail) or tax-exclusive (B2B)?
    prices_include_vat = Column(Boolean, nullable=False, default=True)

    # Rounding policy
    rounding_method = Column(String(20), nullable=False, default="nearest_halala")
    # nearest_halala (0.01), nearest_riyal (1), psychological (.99), none

    # Approval
    approved_by_user_id = Column(String(36), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    extras = Column(JSON, nullable=False, default=dict)

    # Relationships
    items = relationship("PriceListItem", back_populates="price_list", cascade="all, delete-orphan")
    branches = relationship("PriceListBranch", back_populates="price_list", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_price_list_tenant_code"),
        Index("ix_pilot_price_list_tenant_active", "tenant_id", "is_active"),
        Index("ix_pilot_price_list_tenant_validity", "tenant_id", "valid_from", "valid_to"),
    )


class PriceListBranch(Base):
    """Join table — which branches does a branch-scoped list apply to.

    Not needed for tenant/entity-scoped lists (implied coverage).
    """
    __tablename__ = "pilot_price_list_branches"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    price_list_id = Column(String(36), ForeignKey("pilot_price_lists.id", ondelete="CASCADE"), nullable=False, index=True)
    branch_id = Column(String(36), ForeignKey("pilot_branches.id", ondelete="CASCADE"), nullable=False, index=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    price_list = relationship("PriceList", back_populates="branches")
    branch = relationship("Branch")

    __table_args__ = (
        UniqueConstraint("price_list_id", "branch_id", name="uq_pilot_price_list_branch"),
    )


class PriceListItem(Base):
    """One (price_list × variant) row.

    Supports volume pricing via min_qty (different tiers for same SKU can
    exist with different min_qty; resolver picks the highest min_qty ≤
    ordered qty).
    """
    __tablename__ = "pilot_price_list_items"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    price_list_id = Column(String(36), ForeignKey("pilot_price_lists.id", ondelete="CASCADE"), nullable=False, index=True)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="CASCADE"), nullable=False, index=True)

    # Pricing
    unit_price = Column(Numeric(18, 4), nullable=False)    # price in list's currency
    unit_cost = Column(Numeric(18, 4), nullable=True)      # optional cost override
    margin_pct = Column(Numeric(8, 4), nullable=True)      # cached: (price-cost)/price * 100

    # Volume tier
    min_qty = Column(Numeric(18, 3), nullable=False, default=1)  # first tier = 1

    # Per-line promo override (takes precedence over list's promo)
    promo_discount_pct = Column(Numeric(6, 3), nullable=True)   # 15.000 = 15%
    original_price = Column(Numeric(18, 4), nullable=True)      # "was" price for strike-through UI
    promo_starts_at = Column(DateTime(timezone=True), nullable=True)
    promo_ends_at = Column(DateTime(timezone=True), nullable=True)

    # Per-line status
    is_active = Column(Boolean, nullable=False, default=True)

    # Reference to external (e.g., supplier quote, contract PDF)
    reference_note = Column(String(255), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    price_list = relationship("PriceList", back_populates="items")
    variant = relationship("ProductVariant")

    __table_args__ = (
        # Same variant can appear multiple times in one list ONLY with different min_qty
        # (volume tiering). Enforce via (price_list_id, variant_id, min_qty) uniqueness.
        UniqueConstraint("price_list_id", "variant_id", "min_qty", name="uq_pilot_price_item_list_variant_qty"),
        Index("ix_pilot_price_item_variant", "variant_id"),
        Index("ix_pilot_price_item_tenant_list", "tenant_id", "price_list_id"),
    )
