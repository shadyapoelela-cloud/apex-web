"""Warehouse + Stock (inventory) models.

Hierarchy:
  Branch (physical location)
    └── Warehouse (storage zone within a branch)
          └── Bin (optional — shelf / rack / aisle)
                └── StockLevel (balance per variant)

Examples:
  Branch "SA-RIY-PANORAMA" (retail store)
    ├── Warehouse "MAIN"   — the sales floor
    └── Warehouse "STOCK"  — the back-of-house stockroom

  Branch "SA-CENTRAL-DC" (distribution center)
    ├── Warehouse "BULK"   — pallets
    ├── Warehouse "PICK"   — pick-face shelves
    └── Warehouse "RETURNS"

Every stock movement (sale, PO receipt, transfer, adjustment) goes
through StockMovement → updates StockLevel (no direct writes).
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ──────────────────────────────────────────────────────────────────────────
# Warehouse
# ──────────────────────────────────────────────────────────────────────────

class WarehouseType(str, enum.Enum):
    main = "main"                   # سطح البيع / المتجر الرئيسي
    stockroom = "stockroom"         # مخزن خلفي في المتجر
    central_dc = "central_dc"       # مستودع مركزي
    transit = "transit"              # أثناء النقل (ظاهري)
    returns = "returns"              # بضاعة مرتجعة
    damaged = "damaged"              # بضاعة تالفة
    quarantine = "quarantine"        # حجر جمركي / فحص جودة


class WarehouseStatus(str, enum.Enum):
    active = "active"
    stocktake = "stocktake"          # مقفل مؤقتاً للجرد
    maintenance = "maintenance"
    closed = "closed"


class Warehouse(Base):
    """A storage zone belonging to a Branch.

    Every Variant's stock balance is tracked PER WAREHOUSE (not per branch).
    This lets us separate sales-floor stock from stockroom stock in the same
    retail store.
    """
    __tablename__ = "pilot_warehouses"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    branch_id = Column(String(36), ForeignKey("pilot_branches.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(30), nullable=False)              # MAIN, STOCK, DC-BULK, DC-PICK
    name_ar = Column(String(150), nullable=False)          # المخزن الرئيسي
    name_en = Column(String(150), nullable=True)

    type = Column(String(20), nullable=False, default=WarehouseType.main.value)
    status = Column(String(20), nullable=False, default=WarehouseStatus.active.value)

    # Physical attributes
    area_sqm = Column(Integer, nullable=True)
    capacity_skus = Column(Integer, nullable=True)

    # Manager
    manager_user_id = Column(String(36), nullable=True)

    # Commercial flags
    allow_negative_stock = Column(Boolean, nullable=False, default=False)
    is_sellable_from = Column(Boolean, nullable=False, default=True)      # can POS sell from this WH?
    is_receivable_to = Column(Boolean, nullable=False, default=True)      # can POs receive to this WH?

    # GL — inventory sub-ledger account override
    inventory_account_id = Column(String(36), nullable=True)

    is_default = Column(Boolean, nullable=False, default=False)          # default for this branch
    sort_order = Column(Integer, nullable=False, default=0)

    notes = Column(Text, nullable=True)
    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    branch = relationship("Branch", backref="warehouses")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_wh_tenant_code"),
        Index("ix_pilot_wh_branch_status", "branch_id", "status"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Stock level (one row per (warehouse × variant))
# ──────────────────────────────────────────────────────────────────────────

class StockLevel(Base):
    """Current on-hand balance for a (warehouse × variant) pair.

    Mutations come ONLY from StockMovement records — this table is a
    real-time projection that can be rebuilt from movements if needed.

    available = on_hand - reserved
    """
    __tablename__ = "pilot_stock_levels"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    warehouse_id = Column(String(36), ForeignKey("pilot_warehouses.id", ondelete="CASCADE"), nullable=False, index=True)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="CASCADE"), nullable=False, index=True)

    on_hand = Column(Numeric(18, 3), nullable=False, default=0)        # physical qty
    reserved = Column(Numeric(18, 3), nullable=False, default=0)       # allocated to open orders
    available = Column(Numeric(18, 3), nullable=False, default=0)      # on_hand - reserved (cached)
    in_transit = Column(Numeric(18, 3), nullable=False, default=0)     # inbound from transfers/POs

    # Weighted-average cost at this warehouse (may differ from variant.default_cost
    # if multiple warehouses have different purchase histories)
    weighted_avg_cost = Column(Numeric(18, 4), nullable=False, default=0)
    last_cost = Column(Numeric(18, 4), nullable=False, default=0)

    last_counted_at = Column(DateTime(timezone=True), nullable=True)  # last stocktake
    last_movement_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    warehouse = relationship("Warehouse")
    variant = relationship("ProductVariant")

    __table_args__ = (
        UniqueConstraint("warehouse_id", "variant_id", name="uq_pilot_stock_wh_variant"),
        Index("ix_pilot_stock_tenant_wh", "tenant_id", "warehouse_id"),
        Index("ix_pilot_stock_variant", "variant_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Stock movement (every inventory change)
# ──────────────────────────────────────────────────────────────────────────

class MovementReason(str, enum.Enum):
    po_receipt = "po_receipt"           # استلام شراء
    pos_sale = "pos_sale"               # بيع نقطة بيع
    pos_return = "pos_return"           # مرتجع بيع
    transfer_out = "transfer_out"       # تحويل صادر
    transfer_in = "transfer_in"         # تحويل وارد
    adjustment_plus = "adjustment_plus"  # تسوية موجبة
    adjustment_minus = "adjustment_minus"  # تسوية سالبة
    stocktake = "stocktake"             # جرد
    damage = "damage"                   # تلف
    theft = "theft"                     # سرقة
    expiry = "expiry"                   # انتهاء صلاحية
    initial = "initial"                 # رصيد افتتاحي
    reservation = "reservation"         # حجز
    release = "release"                 # فك حجز


class StockMovement(Base):
    """An immutable ledger of every stock change.

    Movements come in pairs for transfers (out from source, in to dest),
    and singles for sales / receipts / adjustments.

    qty can be positive (inbound) or negative (outbound).
    """
    __tablename__ = "pilot_stock_movements"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    warehouse_id = Column(String(36), ForeignKey("pilot_warehouses.id", ondelete="CASCADE"), nullable=False, index=True)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="CASCADE"), nullable=False, index=True)

    # Direction & qty (signed: + inbound, - outbound)
    qty = Column(Numeric(18, 3), nullable=False)
    unit_cost = Column(Numeric(18, 4), nullable=False, default=0)      # cost at time of movement
    total_cost = Column(Numeric(18, 4), nullable=False, default=0)     # qty * unit_cost (signed)

    # Classification
    reason = Column(String(30), nullable=False)                         # see MovementReason
    reference_type = Column(String(40), nullable=True)                  # "purchase_invoice", "pos_sale", "transfer", ...
    reference_id = Column(String(36), nullable=True)                    # UUID of the source doc
    reference_number = Column(String(40), nullable=True)                # human-readable "PO-2026-00042"

    # For transfers: the paired movement
    paired_movement_id = Column(String(36), ForeignKey("pilot_stock_movements.id", ondelete="SET NULL"), nullable=True)

    # Balance snapshot AFTER this movement (for audit trail)
    balance_after = Column(Numeric(18, 3), nullable=False, default=0)

    # Lot/Batch/Expiry — مطلوب إذا track_batch/expiry/serial على الـ variant
    batch_number = Column(String(50), nullable=True, index=True)
    batch_date = Column(DateTime(timezone=True), nullable=True)
    expiry_date = Column(DateTime(timezone=True), nullable=True, index=True)
    serial_number = Column(String(100), nullable=True)  # للـ single-unit items
    supplier_lot_ref = Column(String(100), nullable=True)  # مرجع المورد

    # Who/when
    performed_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    performed_by_user_id = Column(String(36), nullable=True)
    branch_id = Column(String(36), nullable=True, index=True)           # denormalized for reports

    notes = Column(Text, nullable=True)

    # This row is immutable — no updated_at, no is_deleted.
    # Corrections are done with NEW compensating movements.

    __table_args__ = (
        Index("ix_pilot_mvmt_wh_variant_time", "warehouse_id", "variant_id", "performed_at"),
        Index("ix_pilot_mvmt_tenant_time", "tenant_id", "performed_at"),
        Index("ix_pilot_mvmt_reason", "reason"),
        Index("ix_pilot_mvmt_reference", "reference_type", "reference_id"),
    )
