"""Product + Variant + Attribute models for retail.

Design (clothing / fashion retail):

  Product                — the "style" or SKU family
  │                        e.g., "Classic White T-Shirt" (code: TS-001)
  │
  ├── attribute_values   — per-product attribute picklist
  │                        e.g., sizes = [S, M, L, XL]
  │                              colors = [white, black, navy]
  │
  └── Variant            — one concrete (size × color) combination
                           e.g., TS-001-M-WHITE
                           each variant gets:
                             • its own SKU code
                             • its own GTIN/EAN-13 barcode
                             • its own cost + price (via PriceList)
                             • its own stock balance per warehouse

Categories (Category tree):
  "ملابس رجالي → قمصان → قمصان بولو"
  "ملابس نسائي → فساتين → فساتين سهرة"
  Used for:
    - default GL account routing (CoA category)
    - hierarchical P&L / margin reports
    - filter trees in search

Brands & suppliers kept separate (many-to-one on Product).
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ──────────────────────────────────────────────────────────────────────────
# Enums
# ──────────────────────────────────────────────────────────────────────────

class ProductStatus(str, enum.Enum):
    draft = "draft"                  # مسودة — غير نشط
    active = "active"                # نشط
    discontinued = "discontinued"    # متوقف — لا يتم شراؤه بعد الآن
    archived = "archived"            # مؤرشف


class ProductKind(str, enum.Enum):
    goods = "goods"                  # بضاعة (معظم المنتجات)
    service = "service"              # خدمة (غير مخزنية)
    composite = "composite"          # مجموعة/بندل
    raw = "raw"                      # مواد خام


class VatCode(str, enum.Enum):
    standard = "standard"            # 15% (SA) / 5% (AE) — default
    zero_rated = "zero_rated"        # 0% (exports, basic goods)
    exempt = "exempt"                # معفى
    out_of_scope = "out_of_scope"    # خارج النطاق


# ──────────────────────────────────────────────────────────────────────────
# Category tree
# ──────────────────────────────────────────────────────────────────────────

class ProductCategory(Base):
    """Hierarchical category tree per tenant.

    Example (clothing):
      Root: "ملابس"
        ├── "رجالي"
        │     ├── "قمصان"
        │     └── "سراويل"
        └── "نسائي"
              ├── "فساتين"
              └── "حقائب"
    """
    __tablename__ = "pilot_product_categories"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    parent_id = Column(String(36), ForeignKey("pilot_product_categories.id", ondelete="CASCADE"), nullable=True)

    code = Column(String(50), nullable=False)              # MEN-SHIRTS, WOMEN-DRESSES
    name_ar = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=True)

    # Default accounting overrides (inherit from parent → CoA default)
    default_income_account_id = Column(String(36), nullable=True)
    default_cogs_account_id = Column(String(36), nullable=True)
    default_inventory_account_id = Column(String(36), nullable=True)
    default_vat_code = Column(String(20), nullable=True)  # inherit from tenant default if null

    # Display
    icon = Column(String(50), nullable=True)
    color_hex = Column(String(7), nullable=True)
    sort_order = Column(Integer, nullable=False, default=0)

    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    parent = relationship("ProductCategory", remote_side=[id], backref="children")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_prod_cat_tenant_code"),
        Index("ix_pilot_prod_cat_tenant_parent", "tenant_id", "parent_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Brands
# ──────────────────────────────────────────────────────────────────────────

class Brand(Base):
    """Product brand (manufacturer or house brand)."""
    __tablename__ = "pilot_brands"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(50), nullable=False)     # NIKE, ADIDAS, HM, ZARA
    name_ar = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=True)
    logo_url = Column(String(500), nullable=True)
    country_of_origin = Column(String(2), nullable=True)  # US, DE, ES, ...

    # Default supplier (optional shortcut)
    default_supplier_name = Column(String(255), nullable=True)

    is_active = Column(Boolean, nullable=False, default=True)
    sort_order = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_brand_tenant_code"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Attributes (for variant generation)
# ──────────────────────────────────────────────────────────────────────────

class AttributeType(str, enum.Enum):
    size = "size"
    color = "color"
    material = "material"
    style = "style"
    custom = "custom"


class ProductAttribute(Base):
    """An attribute DEFINITION per tenant (reusable).

    Example rows:
      • size      — "المقاس" — type=size     — values ~ XS/S/M/L/XL/XXL
      • color     — "اللون"  — type=color    — values ~ white/black/navy/...
      • material  — "الخامة" — type=material — values ~ cotton/silk/wool
    """
    __tablename__ = "pilot_product_attributes"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(50), nullable=False)             # size, color, material, ...
    name_ar = Column(String(100), nullable=False)         # المقاس
    name_en = Column(String(100), nullable=True)
    type = Column(String(30), nullable=False, default=AttributeType.custom.value)

    # Is this attribute required to create a variant?
    # e.g., "size" might be required for clothing but not books
    is_required_for_variant = Column(Boolean, nullable=False, default=False)

    # Display input hint — picklist | swatch | free_text
    input_type = Column(String(20), nullable=False, default="picklist")

    sort_order = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    values = relationship("ProductAttributeValue", back_populates="attribute", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_attr_tenant_code"),
    )


class ProductAttributeValue(Base):
    """An allowed value for an attribute.

    Example:
      attribute=size  → values: XS, S, M, L, XL, XXL (sort_order 1..6)
      attribute=color → values: white (#FFFFFF), black (#000000),
                                navy (#000080), red (#FF0000)
    """
    __tablename__ = "pilot_product_attribute_values"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    attribute_id = Column(String(36), ForeignKey("pilot_product_attributes.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(30), nullable=False)       # XS, S, M, WHITE, BLACK, ...
    name_ar = Column(String(100), nullable=False)   # صغير جداً, أبيض, ...
    name_en = Column(String(100), nullable=True)

    # Visual (for color swatches, etc.)
    hex_color = Column(String(7), nullable=True)    # #FFFFFF for color values
    swatch_url = Column(String(500), nullable=True)

    sort_order = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)

    attribute = relationship("ProductAttribute", back_populates="values")

    __table_args__ = (
        UniqueConstraint("attribute_id", "code", name="uq_pilot_attr_val_attr_code"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Product (the style / SKU family)
# ──────────────────────────────────────────────────────────────────────────

class Product(Base):
    """A product — the "style" / parent SKU that groups variants.

    Clothing example:
      Product: "Classic Polo Shirt" (code PS-001)
        Variants:
          PS-001-S-WHITE   (Small, White)
          PS-001-M-WHITE   (Medium, White)
          PS-001-L-WHITE   ...
          PS-001-S-BLACK
          PS-001-M-BLACK
          ...
        Total = sizes × colors (4 × 3 = 12 variants typical)
    """
    __tablename__ = "pilot_products"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    # Identification
    code = Column(String(50), nullable=False)              # PS-001, TS-042, ...
    name_ar = Column(String(255), nullable=False)
    name_en = Column(String(255), nullable=True)
    description_ar = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)

    # Classification
    category_id = Column(String(36), ForeignKey("pilot_product_categories.id", ondelete="SET NULL"), nullable=True, index=True)
    brand_id = Column(String(36), ForeignKey("pilot_brands.id", ondelete="SET NULL"), nullable=True, index=True)
    kind = Column(String(20), nullable=False, default=ProductKind.goods.value)

    # Tax
    vat_code = Column(String(20), nullable=False, default=VatCode.standard.value)
    hs_code = Column(String(20), nullable=True)  # Harmonized System (import/export)

    # Accounting overrides (inherit from category → tenant default)
    income_account_id = Column(String(36), nullable=True)
    cogs_account_id = Column(String(36), nullable=True)
    inventory_account_id = Column(String(36), nullable=True)

    # Status
    status = Column(String(20), nullable=False, default=ProductStatus.draft.value)

    # Commercial
    default_uom = Column(String(20), nullable=False, default="piece")  # piece | kg | m | box
    min_order_qty = Column(Numeric(18, 3), nullable=False, default=1)
    is_sellable = Column(Boolean, nullable=False, default=True)
    is_purchasable = Column(Boolean, nullable=False, default=True)
    is_stockable = Column(Boolean, nullable=False, default=True)

    # Images (JSON list of URLs for cover, gallery)
    images = Column(JSON, nullable=False, default=list)

    # Searchable attributes — tags (e.g., "summer", "sale", "new-arrival")
    tags = Column(JSON, nullable=False, default=list)

    # Which attribute codes generate variants
    # e.g., ["size", "color"] → variants are size×color combos
    variant_attribute_codes = Column(JSON, nullable=False, default=list)

    # Commercial metrics cached for reports (refreshed by job)
    total_stock_on_hand = Column(Numeric(18, 3), nullable=False, default=0)
    active_variant_count = Column(Integer, nullable=False, default=0)

    # Extras for custom fields
    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    category = relationship("ProductCategory")
    brand = relationship("Brand")
    variants = relationship("ProductVariant", back_populates="product", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_product_tenant_code"),
        Index("ix_pilot_products_tenant_status", "tenant_id", "status"),
        Index("ix_pilot_products_tenant_category", "tenant_id", "category_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Variant (the real SKU stocked & sold)
# ──────────────────────────────────────────────────────────────────────────

class ProductVariant(Base):
    """A concrete SKU variant — a (product × attribute-combo) tuple.

    This is what actually gets:
      - a GTIN/EAN-13 barcode
      - a stock balance per warehouse
      - a cost + selling price
      - scanned at POS

    attribute_values is a JSON dict mapping attribute_code → value_code:
      {"size": "M", "color": "WHITE"}
    """
    __tablename__ = "pilot_product_variants"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(String(36), ForeignKey("pilot_products.id", ondelete="CASCADE"), nullable=False, index=True)

    # SKU = product.code + "-" + attribute codes (e.g., "PS-001-M-WHITE")
    sku = Column(String(80), nullable=False)

    # Variant's label in UI (e.g., "Classic Polo Shirt — Medium — White")
    display_name_ar = Column(String(255), nullable=True)
    display_name_en = Column(String(255), nullable=True)

    # The attribute combination that makes this variant unique
    # {"size": "M", "color": "WHITE", "material": "cotton"}
    attribute_values = Column(JSON, nullable=False, default=dict)

    # Pricing (list price — can be overridden by PriceList per branch/season)
    default_cost = Column(Numeric(18, 4), nullable=True)          # weighted-avg cost
    standard_cost = Column(Numeric(18, 4), nullable=True)         # budgeted / target
    list_price = Column(Numeric(18, 4), nullable=True)            # default MSRP
    currency = Column(String(3), nullable=False, default="SAR")

    # Dimensions (for shipping / shelf planning)
    weight_grams = Column(Numeric(10, 2), nullable=True)
    length_cm = Column(Numeric(8, 2), nullable=True)
    width_cm = Column(Numeric(8, 2), nullable=True)
    height_cm = Column(Numeric(8, 2), nullable=True)

    # Inventory flags
    track_stock = Column(Boolean, nullable=False, default=True)
    allow_negative_stock = Column(Boolean, nullable=False, default=False)
    reorder_point = Column(Numeric(18, 3), nullable=True)         # alert threshold
    reorder_qty = Column(Numeric(18, 3), nullable=True)           # suggested PO qty

    # Status — can deactivate one variant (e.g., out-of-fashion) without killing parent
    is_active = Column(Boolean, nullable=False, default=True)

    # Cached rollup (across all warehouses)
    total_on_hand = Column(Numeric(18, 3), nullable=False, default=0)
    total_reserved = Column(Numeric(18, 3), nullable=False, default=0)
    total_available = Column(Numeric(18, 3), nullable=False, default=0)

    # Images (variant-specific, e.g., white-color shot)
    image_url = Column(String(500), nullable=True)

    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    product = relationship("Product", back_populates="variants")
    barcodes = relationship("Barcode", back_populates="variant", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "sku", name="uq_pilot_variant_tenant_sku"),
        Index("ix_pilot_variants_product", "product_id"),
        Index("ix_pilot_variants_tenant_active", "tenant_id", "is_active"),
    )
