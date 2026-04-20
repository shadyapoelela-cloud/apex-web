"""Pydantic schemas for product catalog (product, variant, category, brand,
attribute, barcode)."""

from datetime import datetime
from decimal import Decimal
from typing import Optional, Literal, Any
from pydantic import BaseModel, Field, ConfigDict, field_validator


# ──────────────────────────────────────────────────────────────────────────
# Category
# ──────────────────────────────────────────────────────────────────────────

class ProductCategoryCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=50)
    name_ar: str = Field(..., min_length=1, max_length=150)
    name_en: Optional[str] = None
    parent_id: Optional[str] = None
    default_vat_code: Optional[str] = Field(None, pattern="^(standard|zero_rated|exempt|out_of_scope)$")
    icon: Optional[str] = None
    color_hex: Optional[str] = Field(None, pattern="^#[0-9A-Fa-f]{6}$")
    sort_order: int = 0


class ProductCategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    parent_id: Optional[str]
    code: str
    name_ar: str
    name_en: Optional[str]
    default_vat_code: Optional[str]
    icon: Optional[str]
    color_hex: Optional[str]
    sort_order: int
    is_active: bool


class ProductCategoryUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    parent_id: Optional[str] = None
    default_vat_code: Optional[str] = None
    icon: Optional[str] = None
    color_hex: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


# ──────────────────────────────────────────────────────────────────────────
# Brand
# ──────────────────────────────────────────────────────────────────────────

class BrandCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=50)
    name_ar: str
    name_en: Optional[str] = None
    logo_url: Optional[str] = None
    country_of_origin: Optional[str] = Field(None, min_length=2, max_length=2)
    default_supplier_name: Optional[str] = None
    sort_order: int = 0


class BrandRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    logo_url: Optional[str]
    country_of_origin: Optional[str]
    is_active: bool
    sort_order: int


# ──────────────────────────────────────────────────────────────────────────
# Attribute + Value
# ──────────────────────────────────────────────────────────────────────────

class AttributeValueCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=30)
    name_ar: str
    name_en: Optional[str] = None
    hex_color: Optional[str] = Field(None, pattern="^#[0-9A-Fa-f]{6}$")
    swatch_url: Optional[str] = None
    sort_order: int = 0


class AttributeValueRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    attribute_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    hex_color: Optional[str]
    swatch_url: Optional[str]
    sort_order: int
    is_active: bool


class ProductAttributeCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=50)
    name_ar: str
    name_en: Optional[str] = None
    type: str = Field("custom", pattern="^(size|color|material|style|custom)$")
    is_required_for_variant: bool = False
    input_type: str = Field("picklist", pattern="^(picklist|swatch|free_text)$")
    sort_order: int = 0
    values: list[AttributeValueCreate] = Field(default_factory=list)


class ProductAttributeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    type: str
    is_required_for_variant: bool
    input_type: str
    sort_order: int
    is_active: bool
    values: list[AttributeValueRead] = Field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────
# Product + Variant
# ──────────────────────────────────────────────────────────────────────────

class ProductVariantCreate(BaseModel):
    """Used both standalone (POST .../variants) and inline from product create."""
    sku: str = Field(..., min_length=2, max_length=80)
    display_name_ar: Optional[str] = None
    display_name_en: Optional[str] = None
    attribute_values: dict[str, str] = Field(default_factory=dict)
    default_cost: Optional[Decimal] = None
    standard_cost: Optional[Decimal] = None
    list_price: Optional[Decimal] = None
    currency: str = Field("SAR", min_length=3, max_length=3)
    weight_grams: Optional[Decimal] = None
    length_cm: Optional[Decimal] = None
    width_cm: Optional[Decimal] = None
    height_cm: Optional[Decimal] = None
    track_stock: bool = True
    allow_negative_stock: bool = False
    reorder_point: Optional[Decimal] = None
    reorder_qty: Optional[Decimal] = None
    image_url: Optional[str] = None


class ProductVariantRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    product_id: str
    sku: str
    display_name_ar: Optional[str]
    display_name_en: Optional[str]
    attribute_values: dict[str, str]
    default_cost: Optional[Decimal]
    standard_cost: Optional[Decimal]
    list_price: Optional[Decimal]
    currency: str
    weight_grams: Optional[Decimal]
    track_stock: bool
    reorder_point: Optional[Decimal]
    reorder_qty: Optional[Decimal]
    is_active: bool
    total_on_hand: Decimal
    total_reserved: Decimal
    total_available: Decimal
    image_url: Optional[str]


class ProductCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=50)
    name_ar: str = Field(..., min_length=1, max_length=255)
    name_en: Optional[str] = None
    description_ar: Optional[str] = None
    description_en: Optional[str] = None
    category_id: Optional[str] = None
    brand_id: Optional[str] = None
    kind: str = Field("goods", pattern="^(goods|service|composite|raw)$")
    vat_code: str = Field("standard", pattern="^(standard|zero_rated|exempt|out_of_scope)$")
    hs_code: Optional[str] = None
    default_uom: str = "piece"
    min_order_qty: Decimal = Decimal("1")
    is_sellable: bool = True
    is_purchasable: bool = True
    is_stockable: bool = True
    images: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    variant_attribute_codes: list[str] = Field(default_factory=list)
    # Optional inline variants — create product + N variants in one call
    variants: list[ProductVariantCreate] = Field(default_factory=list)


class ProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    description_ar: Optional[str]
    description_en: Optional[str]
    category_id: Optional[str]
    brand_id: Optional[str]
    kind: str
    vat_code: str
    hs_code: Optional[str]
    status: str
    default_uom: str
    min_order_qty: Decimal
    is_sellable: bool
    is_purchasable: bool
    is_stockable: bool
    images: list[str]
    tags: list[str]
    variant_attribute_codes: list[str]
    total_stock_on_hand: Decimal
    active_variant_count: int


class ProductDetail(ProductRead):
    """Product + embedded variants (for detail view)."""
    variants: list[ProductVariantRead] = Field(default_factory=list)


class ProductUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    description_ar: Optional[str] = None
    description_en: Optional[str] = None
    category_id: Optional[str] = None
    brand_id: Optional[str] = None
    vat_code: Optional[str] = None
    hs_code: Optional[str] = None
    status: Optional[str] = Field(None, pattern="^(draft|active|discontinued|archived)$")
    default_uom: Optional[str] = None
    is_sellable: Optional[bool] = None
    is_purchasable: Optional[bool] = None
    is_stockable: Optional[bool] = None
    images: Optional[list[str]] = None
    tags: Optional[list[str]] = None


# ──────────────────────────────────────────────────────────────────────────
# Barcode
# ──────────────────────────────────────────────────────────────────────────

class BarcodeCreate(BaseModel):
    value: str = Field(..., min_length=4, max_length=50)
    type: str = Field("ean13", pattern="^(ean13|upc_a|ean8|gtin14|code128|qr|custom)$")
    scope: str = Field("primary", pattern="^(primary|carton|inner|legacy|promotional)$")
    units_per_scan: int = 1
    manufacturer_code: Optional[str] = None

    @field_validator("value")
    @classmethod
    def _digits_only_for_ean_upc(cls, v: str, info) -> str:
        # We can't easily access 'type' here due to validation order; we do the
        # checksum validation server-side after model creation.
        return v.strip()


class BarcodeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    variant_id: str
    value: str
    type: str
    scope: str
    units_per_scan: int
    manufacturer_code: Optional[str]
    is_validated: bool
    is_active: bool


# ──────────────────────────────────────────────────────────────────────────
# Warehouse + Stock
# ──────────────────────────────────────────────────────────────────────────

class WarehouseCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=30)
    name_ar: str
    name_en: Optional[str] = None
    type: str = Field("main", pattern="^(main|stockroom|central_dc|transit|returns|damaged|quarantine)$")
    area_sqm: Optional[int] = None
    capacity_skus: Optional[int] = None
    manager_user_id: Optional[str] = None
    allow_negative_stock: bool = False
    is_sellable_from: bool = True
    is_receivable_to: bool = True
    is_default: bool = False
    sort_order: int = 0
    notes: Optional[str] = None


class WarehouseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    branch_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    type: str
    status: str
    area_sqm: Optional[int]
    capacity_skus: Optional[int]
    manager_user_id: Optional[str]
    allow_negative_stock: bool
    is_sellable_from: bool
    is_receivable_to: bool
    is_default: bool
    sort_order: int


class WarehouseUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    type: Optional[str] = None
    status: Optional[str] = Field(None, pattern="^(active|stocktake|maintenance|closed)$")
    manager_user_id: Optional[str] = None
    allow_negative_stock: Optional[bool] = None
    is_sellable_from: Optional[bool] = None
    is_receivable_to: Optional[bool] = None
    is_default: Optional[bool] = None
    notes: Optional[str] = None


class StockLevelRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    warehouse_id: str
    variant_id: str
    on_hand: Decimal
    reserved: Decimal
    available: Decimal
    in_transit: Decimal
    weighted_avg_cost: Decimal
    last_cost: Decimal
    last_counted_at: Optional[datetime]
    last_movement_at: Optional[datetime]


class StockMovementCreate(BaseModel):
    warehouse_id: str
    variant_id: str
    qty: Decimal = Field(..., description="Signed qty: + inbound, - outbound")
    unit_cost: Decimal = Decimal("0")
    reason: str = Field(..., pattern="^(po_receipt|pos_sale|pos_return|transfer_out|transfer_in|adjustment_plus|adjustment_minus|stocktake|damage|theft|expiry|initial|reservation|release)$")
    reference_type: Optional[str] = None
    reference_id: Optional[str] = None
    reference_number: Optional[str] = None
    notes: Optional[str] = None
    performed_by_user_id: Optional[str] = None


class StockMovementRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    warehouse_id: str
    variant_id: str
    qty: Decimal
    unit_cost: Decimal
    total_cost: Decimal
    reason: str
    reference_type: Optional[str]
    reference_id: Optional[str]
    reference_number: Optional[str]
    balance_after: Decimal
    performed_at: datetime
    performed_by_user_id: Optional[str]
    notes: Optional[str]
