"""Pilot models package."""

from .tenant import Tenant, CompanySettings, TenantStatus, TenantTier
from .entity import Entity, EntityType, EntityStatus, Branch, BranchType, BranchStatus
from .currency import Currency, FxRate
from .rbac import PilotRole, PilotPermission, PilotRolePermission, UserEntityAccess, UserBranchAccess, RoleScope
from .product import (
    Product, ProductStatus, ProductKind, VatCode,
    ProductVariant,
    ProductCategory,
    Brand,
    ProductAttribute, ProductAttributeValue, AttributeType,
)
from .barcode import Barcode, BarcodeType, BarcodeScope, compute_ean13_checksum, validate_ean13
from .warehouse import (
    Warehouse, WarehouseType, WarehouseStatus,
    StockLevel, StockMovement, MovementReason,
)
from .pricing import (
    PriceList, PriceListItem, PriceListBranch,
    PriceListScope, PriceListKind, PriceListStatus, Season,
)

# Backward-compat aliases (used by early route code)
Role = PilotRole
Permission = PilotPermission
RolePermission = PilotRolePermission

__all__ = [
    # Tenant / Entity / Branch
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
    # Currency / FX
    "Currency",
    "FxRate",
    # RBAC
    "PilotRole",
    "PilotPermission",
    "PilotRolePermission",
    "UserEntityAccess",
    "UserBranchAccess",
    "RoleScope",
    # Product
    "Product",
    "ProductStatus",
    "ProductKind",
    "VatCode",
    "ProductVariant",
    "ProductCategory",
    "Brand",
    "ProductAttribute",
    "ProductAttributeValue",
    "AttributeType",
    # Barcode
    "Barcode",
    "BarcodeType",
    "BarcodeScope",
    "compute_ean13_checksum",
    "validate_ean13",
    # Warehouse / Stock
    "Warehouse",
    "WarehouseType",
    "WarehouseStatus",
    "StockLevel",
    "StockMovement",
    "MovementReason",
    # Pricing
    "PriceList",
    "PriceListItem",
    "PriceListBranch",
    "PriceListScope",
    "PriceListKind",
    "PriceListStatus",
    "Season",
    # aliases
    "Role",
    "Permission",
    "RolePermission",
]
