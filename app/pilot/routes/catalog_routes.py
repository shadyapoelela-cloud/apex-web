"""Catalog + Inventory routes (Day 3-4).

All endpoints are prefixed /pilot/ and tagged "pilot-catalog" / "pilot-inventory".
They compose with the main pilot_router via app.include_router().

Endpoints:

  Categories
    GET/POST        /pilot/tenants/{tid}/categories
    GET/PATCH/DELETE /pilot/categories/{id}
  Brands
    GET/POST        /pilot/tenants/{tid}/brands
  Attributes
    GET/POST        /pilot/tenants/{tid}/attributes
    POST            /pilot/attributes/{aid}/values
  Products
    GET/POST        /pilot/tenants/{tid}/products           — list + create
    GET             /pilot/products/{pid}                   — detail (+ variants)
    PATCH/DELETE    /pilot/products/{pid}
    GET/POST        /pilot/products/{pid}/variants          — inline variants
    PATCH           /pilot/variants/{vid}
  Barcodes
    GET/POST        /pilot/variants/{vid}/barcodes
    GET             /pilot/tenants/{tid}/barcode/{value}    — scanner lookup
  Warehouses
    GET/POST        /pilot/branches/{bid}/warehouses
    GET/PATCH/DELETE /pilot/warehouses/{wid}
  Stock
    GET             /pilot/warehouses/{wid}/stock           — per-warehouse
    GET             /pilot/variants/{vid}/stock             — per-variant across WHs
    POST            /pilot/stock/movements                  — record movement
    GET             /pilot/warehouses/{wid}/movements       — history
"""

from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.phase1.routes.phase1_routes import get_current_user
from app.pilot.models import (
    Tenant, Entity, Branch,
    Product, ProductVariant, ProductCategory, Brand,
    ProductAttribute, ProductAttributeValue,
    Barcode, validate_ean13, compute_ean13_checksum,
    Warehouse, StockLevel, StockMovement,
    ProductStatus, WarehouseStatus,
)
from app.pilot.schemas.catalog import (
    ProductCategoryCreate, ProductCategoryRead, ProductCategoryUpdate,
    BrandCreate, BrandRead,
    ProductAttributeCreate, ProductAttributeRead,
    AttributeValueCreate, AttributeValueRead,
    ProductCreate, ProductRead, ProductDetail, ProductUpdate,
    ProductVariantCreate, ProductVariantRead,
    BarcodeCreate, BarcodeRead,
    WarehouseCreate, WarehouseRead, WarehouseUpdate,
    StockLevelRead, StockMovementCreate, StockMovementRead,
)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot-catalog"],
    dependencies=[Depends(get_current_user)],
)


# ──────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────

def _tenant_or_404(db: Session, tid: str) -> Tenant:
    t = db.query(Tenant).filter(Tenant.id == tid).first()
    if not t:
        raise HTTPException(404, f"Tenant {tid} not found")
    return t


def _branch_or_404(db: Session, bid: str) -> Branch:
    b = db.query(Branch).filter(Branch.id == bid, Branch.is_deleted == False).first()  # noqa: E712
    if not b:
        raise HTTPException(404, f"Branch {bid} not found")
    return b


def _product_or_404(db: Session, pid: str) -> Product:
    p = db.query(Product).filter(Product.id == pid, Product.is_deleted == False).first()  # noqa: E712
    if not p:
        raise HTTPException(404, f"Product {pid} not found")
    return p


def _variant_or_404(db: Session, vid: str) -> ProductVariant:
    v = db.query(ProductVariant).filter(ProductVariant.id == vid, ProductVariant.is_deleted == False).first()  # noqa: E712
    if not v:
        raise HTTPException(404, f"Variant {vid} not found")
    return v


def _warehouse_or_404(db: Session, wid: str) -> Warehouse:
    w = db.query(Warehouse).filter(Warehouse.id == wid, Warehouse.is_deleted == False).first()  # noqa: E712
    if not w:
        raise HTTPException(404, f"Warehouse {wid} not found")
    return w


# ═══════════════════════════════════════════════════════════════
# CATEGORIES
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/categories", response_model=list[ProductCategoryRead])
def list_categories(
    tenant_id: str,
    parent_id: Optional[str] = Query(None, description="If set, only children of this parent"),
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
):
    _tenant_or_404(db, tenant_id)
    q = db.query(ProductCategory).filter(ProductCategory.tenant_id == tenant_id)
    if parent_id is not None:
        q = q.filter(ProductCategory.parent_id == parent_id)
    if not include_inactive:
        q = q.filter(ProductCategory.is_active == True)  # noqa: E712
    return q.order_by(ProductCategory.sort_order, ProductCategory.code).all()


@router.post("/tenants/{tenant_id}/categories", response_model=ProductCategoryRead, status_code=201)
def create_category(tenant_id: str, payload: ProductCategoryCreate, db: Session = Depends(get_db)):
    _tenant_or_404(db, tenant_id)
    if db.query(ProductCategory).filter(
        ProductCategory.tenant_id == tenant_id,
        ProductCategory.code == payload.code,
    ).first():
        raise HTTPException(409, f"Category code '{payload.code}' already exists")
    if payload.parent_id:
        parent = db.query(ProductCategory).filter(
            ProductCategory.id == payload.parent_id,
            ProductCategory.tenant_id == tenant_id,
        ).first()
        if not parent:
            raise HTTPException(400, "parent_id not found in this tenant")
    cat = ProductCategory(
        tenant_id=tenant_id,
        parent_id=payload.parent_id,
        code=payload.code,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        default_vat_code=payload.default_vat_code,
        icon=payload.icon,
        color_hex=payload.color_hex,
        sort_order=payload.sort_order,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat


@router.patch("/categories/{category_id}", response_model=ProductCategoryRead)
def update_category(category_id: str, payload: ProductCategoryUpdate, db: Session = Depends(get_db)):
    cat = db.query(ProductCategory).filter(ProductCategory.id == category_id).first()
    if not cat:
        raise HTTPException(404, "Category not found")
    for field, val in payload.model_dump(exclude_unset=True).items():
        setattr(cat, field, val)
    db.commit()
    db.refresh(cat)
    return cat


# ═══════════════════════════════════════════════════════════════
# BRANDS
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/brands", response_model=list[BrandRead])
def list_brands(tenant_id: str, db: Session = Depends(get_db)):
    _tenant_or_404(db, tenant_id)
    return db.query(Brand).filter(
        Brand.tenant_id == tenant_id, Brand.is_active == True  # noqa: E712
    ).order_by(Brand.sort_order, Brand.code).all()


@router.post("/tenants/{tenant_id}/brands", response_model=BrandRead, status_code=201)
def create_brand(tenant_id: str, payload: BrandCreate, db: Session = Depends(get_db)):
    _tenant_or_404(db, tenant_id)
    if db.query(Brand).filter(Brand.tenant_id == tenant_id, Brand.code == payload.code).first():
        raise HTTPException(409, f"Brand code '{payload.code}' already exists")
    b = Brand(tenant_id=tenant_id, **payload.model_dump())
    db.add(b)
    db.commit()
    db.refresh(b)
    return b


# ═══════════════════════════════════════════════════════════════
# ATTRIBUTES (size / color / material / ...)
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/attributes", response_model=list[ProductAttributeRead])
def list_attributes(tenant_id: str, db: Session = Depends(get_db)):
    _tenant_or_404(db, tenant_id)
    attrs = db.query(ProductAttribute).filter(
        ProductAttribute.tenant_id == tenant_id
    ).order_by(ProductAttribute.sort_order, ProductAttribute.code).all()
    # Eager-load values
    results = []
    for a in attrs:
        values = db.query(ProductAttributeValue).filter(
            ProductAttributeValue.attribute_id == a.id
        ).order_by(ProductAttributeValue.sort_order).all()
        d = ProductAttributeRead.model_validate(a).model_dump()
        d["values"] = [AttributeValueRead.model_validate(v).model_dump() for v in values]
        results.append(d)
    return results


@router.post("/tenants/{tenant_id}/attributes", response_model=ProductAttributeRead, status_code=201)
def create_attribute(tenant_id: str, payload: ProductAttributeCreate, db: Session = Depends(get_db)):
    _tenant_or_404(db, tenant_id)
    if db.query(ProductAttribute).filter(
        ProductAttribute.tenant_id == tenant_id,
        ProductAttribute.code == payload.code,
    ).first():
        raise HTTPException(409, f"Attribute '{payload.code}' already exists")
    attr = ProductAttribute(
        tenant_id=tenant_id,
        code=payload.code,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        type=payload.type,
        is_required_for_variant=payload.is_required_for_variant,
        input_type=payload.input_type,
        sort_order=payload.sort_order,
    )
    db.add(attr)
    db.flush()
    for v in payload.values:
        db.add(ProductAttributeValue(
            attribute_id=attr.id,
            code=v.code,
            name_ar=v.name_ar,
            name_en=v.name_en,
            hex_color=v.hex_color,
            swatch_url=v.swatch_url,
            sort_order=v.sort_order,
        ))
    db.commit()
    db.refresh(attr)
    # Build read response
    values = db.query(ProductAttributeValue).filter(ProductAttributeValue.attribute_id == attr.id).all()
    d = ProductAttributeRead.model_validate(attr).model_dump()
    d["values"] = [AttributeValueRead.model_validate(v).model_dump() for v in values]
    return d


@router.post("/attributes/{attribute_id}/values", response_model=AttributeValueRead, status_code=201)
def add_attribute_value(attribute_id: str, payload: AttributeValueCreate, db: Session = Depends(get_db)):
    attr = db.query(ProductAttribute).filter(ProductAttribute.id == attribute_id).first()
    if not attr:
        raise HTTPException(404, "Attribute not found")
    if db.query(ProductAttributeValue).filter(
        ProductAttributeValue.attribute_id == attribute_id,
        ProductAttributeValue.code == payload.code,
    ).first():
        raise HTTPException(409, f"Value '{payload.code}' already exists for this attribute")
    v = ProductAttributeValue(attribute_id=attribute_id, **payload.model_dump())
    db.add(v)
    db.commit()
    db.refresh(v)
    return v


# ═══════════════════════════════════════════════════════════════
# PRODUCTS
# ═══════════════════════════════════════════════════════════════

@router.get("/tenants/{tenant_id}/products", response_model=list[ProductRead])
def list_products(
    tenant_id: str,
    status: Optional[str] = Query(None),
    category_id: Optional[str] = Query(None),
    brand_id: Optional[str] = Query(None),
    q: Optional[str] = Query(None, description="Search code/name"),
    limit: int = Query(100, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    _tenant_or_404(db, tenant_id)
    query = db.query(Product).filter(
        Product.tenant_id == tenant_id, Product.is_deleted == False  # noqa: E712
    )
    if status:
        query = query.filter(Product.status == status)
    if category_id:
        query = query.filter(Product.category_id == category_id)
    if brand_id:
        query = query.filter(Product.brand_id == brand_id)
    if q:
        term = f"%{q}%"
        query = query.filter(
            (Product.code.ilike(term)) | (Product.name_ar.ilike(term)) | (Product.name_en.ilike(term))
        )
    return query.order_by(Product.code).limit(limit).offset(offset).all()


@router.post("/tenants/{tenant_id}/products", response_model=ProductDetail, status_code=201)
def create_product(tenant_id: str, payload: ProductCreate, db: Session = Depends(get_db)):
    """Create a product — optionally with N variants in a single call."""
    _tenant_or_404(db, tenant_id)
    if db.query(Product).filter(Product.tenant_id == tenant_id, Product.code == payload.code).first():
        raise HTTPException(409, f"Product code '{payload.code}' already exists")

    if payload.category_id:
        if not db.query(ProductCategory).filter(
            ProductCategory.id == payload.category_id,
            ProductCategory.tenant_id == tenant_id,
        ).first():
            raise HTTPException(400, "category_id not found in this tenant")
    if payload.brand_id:
        if not db.query(Brand).filter(
            Brand.id == payload.brand_id,
            Brand.tenant_id == tenant_id,
        ).first():
            raise HTTPException(400, "brand_id not found in this tenant")

    product = Product(
        tenant_id=tenant_id,
        code=payload.code,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        description_ar=payload.description_ar,
        description_en=payload.description_en,
        category_id=payload.category_id,
        brand_id=payload.brand_id,
        kind=payload.kind,
        vat_code=payload.vat_code,
        hs_code=payload.hs_code,
        status=ProductStatus.active.value if payload.variants else ProductStatus.draft.value,
        default_uom=payload.default_uom,
        min_order_qty=payload.min_order_qty,
        is_sellable=payload.is_sellable,
        is_purchasable=payload.is_purchasable,
        is_stockable=payload.is_stockable,
        images=payload.images,
        tags=payload.tags,
        variant_attribute_codes=payload.variant_attribute_codes,
    )
    db.add(product)
    db.flush()

    # Inline variants
    for v in payload.variants:
        if db.query(ProductVariant).filter(
            ProductVariant.tenant_id == tenant_id, ProductVariant.sku == v.sku
        ).first():
            raise HTTPException(409, f"Variant SKU '{v.sku}' already exists")
        variant = ProductVariant(
            tenant_id=tenant_id,
            product_id=product.id,
            **v.model_dump(),
        )
        db.add(variant)

    db.flush()
    # Update variant count
    product.active_variant_count = db.query(ProductVariant).filter(
        ProductVariant.product_id == product.id,
        ProductVariant.is_active == True,  # noqa: E712
    ).count()

    db.commit()
    db.refresh(product)

    variants = db.query(ProductVariant).filter(ProductVariant.product_id == product.id).all()
    return ProductDetail(
        **ProductRead.model_validate(product).model_dump(),
        variants=[ProductVariantRead.model_validate(v) for v in variants],
    )


@router.get("/products/{product_id}", response_model=ProductDetail)
def get_product(product_id: str, db: Session = Depends(get_db)):
    p = _product_or_404(db, product_id)
    variants = db.query(ProductVariant).filter(
        ProductVariant.product_id == product_id,
        ProductVariant.is_deleted == False,  # noqa: E712
    ).all()
    return ProductDetail(
        **ProductRead.model_validate(p).model_dump(),
        variants=[ProductVariantRead.model_validate(v) for v in variants],
    )


@router.patch("/products/{product_id}", response_model=ProductRead)
def update_product(product_id: str, payload: ProductUpdate, db: Session = Depends(get_db)):
    p = _product_or_404(db, product_id)
    for field, val in payload.model_dump(exclude_unset=True).items():
        setattr(p, field, val)
    db.commit()
    db.refresh(p)
    return p


@router.delete("/products/{product_id}", status_code=204)
def delete_product(product_id: str, db: Session = Depends(get_db)):
    p = _product_or_404(db, product_id)
    p.is_deleted = True
    p.deleted_at = datetime.now(timezone.utc)
    p.status = ProductStatus.archived.value
    db.commit()
    return None


# ═══════════════════════════════════════════════════════════════
# VARIANTS
# ═══════════════════════════════════════════════════════════════

@router.get("/products/{product_id}/variants", response_model=list[ProductVariantRead])
def list_variants(product_id: str, db: Session = Depends(get_db)):
    _product_or_404(db, product_id)
    return db.query(ProductVariant).filter(
        ProductVariant.product_id == product_id,
        ProductVariant.is_deleted == False,  # noqa: E712
    ).order_by(ProductVariant.sku).all()


@router.post("/products/{product_id}/variants", response_model=ProductVariantRead, status_code=201)
def create_variant(product_id: str, payload: ProductVariantCreate, db: Session = Depends(get_db)):
    p = _product_or_404(db, product_id)
    if db.query(ProductVariant).filter(
        ProductVariant.tenant_id == p.tenant_id, ProductVariant.sku == payload.sku
    ).first():
        raise HTTPException(409, f"Variant SKU '{payload.sku}' already exists")
    v = ProductVariant(
        tenant_id=p.tenant_id,
        product_id=product_id,
        **payload.model_dump(),
    )
    db.add(v)
    db.flush()
    p.active_variant_count = db.query(ProductVariant).filter(
        ProductVariant.product_id == product_id,
        ProductVariant.is_active == True,  # noqa: E712
    ).count()
    db.commit()
    db.refresh(v)
    return v


# ═══════════════════════════════════════════════════════════════
# BARCODES
# ═══════════════════════════════════════════════════════════════

@router.get("/variants/{variant_id}/barcodes", response_model=list[BarcodeRead])
def list_barcodes(variant_id: str, db: Session = Depends(get_db)):
    _variant_or_404(db, variant_id)
    return db.query(Barcode).filter(
        Barcode.variant_id == variant_id, Barcode.is_active == True  # noqa: E712
    ).all()


@router.post("/variants/{variant_id}/barcodes", response_model=BarcodeRead, status_code=201)
def create_barcode(variant_id: str, payload: BarcodeCreate, db: Session = Depends(get_db)):
    v = _variant_or_404(db, variant_id)
    # Tenant-wide uniqueness
    if db.query(Barcode).filter(
        Barcode.tenant_id == v.tenant_id,
        Barcode.value == payload.value,
        Barcode.is_active == True,  # noqa: E712
    ).first():
        raise HTTPException(409, f"Barcode '{payload.value}' already in use in this tenant")

    # Validate EAN-13 / UPC-A
    is_validated = False
    if payload.type == "ean13":
        if not validate_ean13(payload.value):
            raise HTTPException(400, "Invalid EAN-13 checksum")
        is_validated = True
    elif payload.type == "upc_a":
        # UPC-A = 12 digits, checksum algorithm
        val = payload.value
        if len(val) != 12 or not val.isdigit():
            raise HTTPException(400, "UPC-A must be exactly 12 digits")
        total = 0
        for i, ch in enumerate(val[:11]):
            weight = 3 if i % 2 == 0 else 1
            total += int(ch) * weight
        expected = (10 - (total % 10)) % 10
        if expected != int(val[11]):
            raise HTTPException(400, "Invalid UPC-A checksum")
        is_validated = True

    b = Barcode(
        tenant_id=v.tenant_id,
        variant_id=variant_id,
        value=payload.value,
        type=payload.type,
        scope=payload.scope,
        units_per_scan=payload.units_per_scan,
        manufacturer_code=payload.manufacturer_code,
        is_validated=is_validated,
        validated_at=datetime.now(timezone.utc) if is_validated else None,
    )
    db.add(b)
    db.commit()
    db.refresh(b)
    return b


@router.get("/tenants/{tenant_id}/barcode/{value}")
def scan_barcode(tenant_id: str, value: str, db: Session = Depends(get_db)):
    """Scanner lookup — returns variant + product + active stock across all warehouses.

    Used by the POS at checkout when the clerk scans a barcode.
    """
    _tenant_or_404(db, tenant_id)
    bc = db.query(Barcode).filter(
        Barcode.tenant_id == tenant_id,
        Barcode.value == value,
        Barcode.is_active == True,  # noqa: E712
    ).first()
    if not bc:
        raise HTTPException(404, f"Barcode '{value}' not found in this tenant")
    variant = _variant_or_404(db, bc.variant_id)
    product = _product_or_404(db, variant.product_id)

    # Stock across all warehouses
    levels = db.query(StockLevel).filter(StockLevel.variant_id == variant.id).all()

    return {
        "barcode": BarcodeRead.model_validate(bc),
        "variant": ProductVariantRead.model_validate(variant),
        "product": {
            "id": product.id, "code": product.code,
            "name_ar": product.name_ar, "name_en": product.name_en,
        },
        "units_per_scan": bc.units_per_scan,
        "stock_levels": [
            {
                "warehouse_id": lv.warehouse_id,
                "on_hand": float(lv.on_hand),
                "available": float(lv.available),
            }
            for lv in levels
        ],
    }


# ═══════════════════════════════════════════════════════════════
# WAREHOUSES
# ═══════════════════════════════════════════════════════════════

@router.get("/branches/{branch_id}/warehouses", response_model=list[WarehouseRead])
def list_warehouses(branch_id: str, db: Session = Depends(get_db)):
    _branch_or_404(db, branch_id)
    return db.query(Warehouse).filter(
        Warehouse.branch_id == branch_id,
        Warehouse.is_deleted == False,  # noqa: E712
    ).order_by(Warehouse.sort_order, Warehouse.code).all()


@router.post("/branches/{branch_id}/warehouses", response_model=WarehouseRead, status_code=201)
def create_warehouse(branch_id: str, payload: WarehouseCreate, db: Session = Depends(get_db)):
    b = _branch_or_404(db, branch_id)
    if db.query(Warehouse).filter(
        Warehouse.tenant_id == b.tenant_id, Warehouse.code == payload.code
    ).first():
        raise HTTPException(409, f"Warehouse code '{payload.code}' already exists in tenant")

    # If is_default=True, un-default any existing default for this branch
    if payload.is_default:
        db.query(Warehouse).filter(
            Warehouse.branch_id == branch_id, Warehouse.is_default == True  # noqa: E712
        ).update({"is_default": False})

    w = Warehouse(tenant_id=b.tenant_id, branch_id=branch_id, **payload.model_dump())
    db.add(w)
    db.commit()
    db.refresh(w)
    return w


@router.patch("/warehouses/{warehouse_id}", response_model=WarehouseRead)
def update_warehouse(warehouse_id: str, payload: WarehouseUpdate, db: Session = Depends(get_db)):
    w = _warehouse_or_404(db, warehouse_id)
    for field, val in payload.model_dump(exclude_unset=True).items():
        setattr(w, field, val)
    db.commit()
    db.refresh(w)
    return w


@router.delete("/warehouses/{warehouse_id}", status_code=204)
def delete_warehouse(warehouse_id: str, db: Session = Depends(get_db)):
    w = _warehouse_or_404(db, warehouse_id)
    # Prevent delete if stock exists
    has_stock = db.query(StockLevel).filter(
        StockLevel.warehouse_id == warehouse_id,
        StockLevel.on_hand > 0,
    ).first()
    if has_stock:
        raise HTTPException(409, "Cannot delete warehouse with non-zero stock. Transfer stock first.")
    w.is_deleted = True
    w.deleted_at = datetime.now(timezone.utc)
    w.status = WarehouseStatus.closed.value
    db.commit()
    return None


# ═══════════════════════════════════════════════════════════════
# STOCK LEVELS + MOVEMENTS
# ═══════════════════════════════════════════════════════════════

@router.get("/warehouses/{warehouse_id}/stock", response_model=list[StockLevelRead])
def get_warehouse_stock(warehouse_id: str, db: Session = Depends(get_db)):
    """All stock levels in one warehouse."""
    _warehouse_or_404(db, warehouse_id)
    return db.query(StockLevel).filter(StockLevel.warehouse_id == warehouse_id).all()


@router.get("/variants/{variant_id}/stock", response_model=list[StockLevelRead])
def get_variant_stock(variant_id: str, db: Session = Depends(get_db)):
    """Stock levels for one variant across all warehouses."""
    _variant_or_404(db, variant_id)
    return db.query(StockLevel).filter(StockLevel.variant_id == variant_id).all()


@router.post("/stock/movements", response_model=StockMovementRead, status_code=201)
def record_stock_movement(payload: StockMovementCreate, db: Session = Depends(get_db)):
    """Record an inventory movement and update StockLevel + variant totals atomically.

    This is the ONLY way to change stock. Sales, PO receipts, transfers,
    stocktakes, damages — all must go through here.

    qty sign convention: + inbound, - outbound. Absolute value is used
    for the unit_cost * |qty| total_cost calculation.
    """
    w = _warehouse_or_404(db, payload.warehouse_id)
    v = _variant_or_404(db, payload.variant_id)
    if w.tenant_id != v.tenant_id:
        raise HTTPException(400, "Warehouse and variant belong to different tenants")

    # Get or create StockLevel
    level = db.query(StockLevel).filter(
        StockLevel.warehouse_id == w.id,
        StockLevel.variant_id == v.id,
    ).first()
    if not level:
        level = StockLevel(
            tenant_id=w.tenant_id,
            warehouse_id=w.id,
            variant_id=v.id,
            on_hand=Decimal("0"),
            reserved=Decimal("0"),
            available=Decimal("0"),
        )
        db.add(level)
        db.flush()

    qty = payload.qty
    new_on_hand = level.on_hand + qty

    # Check negative stock
    if new_on_hand < 0:
        allow_neg = w.allow_negative_stock or v.allow_negative_stock
        if not allow_neg:
            raise HTTPException(
                409,
                f"Would drive stock negative ({level.on_hand} + {qty} = {new_on_hand}). "
                f"Enable allow_negative_stock on warehouse or variant to override."
            )

    # Compute weighted avg cost on inbound positive movements only
    unit_cost = payload.unit_cost
    if qty > 0 and unit_cost > 0:
        # new_avg = (old_on_hand * old_avg + qty * unit_cost) / (old_on_hand + qty)
        if new_on_hand > 0:
            numerator = (level.on_hand * level.weighted_avg_cost) + (qty * unit_cost)
            level.weighted_avg_cost = numerator / new_on_hand
        level.last_cost = unit_cost
    total_cost = qty * unit_cost if unit_cost else Decimal("0")

    level.on_hand = new_on_hand
    level.available = level.on_hand - level.reserved
    now = datetime.now(timezone.utc)
    level.last_movement_at = now

    # Record the immutable movement
    mvmt = StockMovement(
        tenant_id=w.tenant_id,
        warehouse_id=w.id,
        variant_id=v.id,
        qty=qty,
        unit_cost=unit_cost,
        total_cost=total_cost,
        reason=payload.reason,
        reference_type=payload.reference_type,
        reference_id=payload.reference_id,
        reference_number=payload.reference_number,
        balance_after=level.on_hand,
        performed_at=now,
        performed_by_user_id=payload.performed_by_user_id,
        branch_id=w.branch_id,
        notes=payload.notes,
    )
    db.add(mvmt)

    # Update variant rollup
    all_levels = db.query(StockLevel).filter(StockLevel.variant_id == v.id).all()
    v.total_on_hand = sum((lv.on_hand for lv in all_levels), Decimal("0")) + (qty if level not in all_levels else Decimal("0"))
    v.total_reserved = sum((lv.reserved for lv in all_levels), Decimal("0"))
    v.total_available = v.total_on_hand - v.total_reserved

    db.commit()
    db.refresh(mvmt)
    return mvmt


@router.get("/warehouses/{warehouse_id}/movements", response_model=list[StockMovementRead])
def list_warehouse_movements(
    warehouse_id: str,
    variant_id: Optional[str] = Query(None),
    limit: int = Query(100, le=1000),
    db: Session = Depends(get_db),
):
    _warehouse_or_404(db, warehouse_id)
    q = db.query(StockMovement).filter(StockMovement.warehouse_id == warehouse_id)
    if variant_id:
        q = q.filter(StockMovement.variant_id == variant_id)
    return q.order_by(StockMovement.performed_at.desc()).limit(limit).all()
