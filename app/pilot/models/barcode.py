"""Barcode (GTIN/EAN-13/UPC-A/Code-128) model.

A Variant can have MULTIPLE barcodes:
  • primary barcode  — the factory-printed EAN-13 on the label
  • carton barcode   — GTIN-14 for a master case
  • inner barcode    — GTIN-8 for smaller packs
  • legacy barcodes  — old barcodes after re-labeling

All are unique per tenant (two products can't share a barcode in the same
tenant), but the same EAN-13 can appear in different tenants (different
clothing companies can sell the same product line).

Validation for EAN-13:
  • 13 digits total
  • Last digit = check digit computed via mod-10 weights (3,1,3,1,...)

ZATCA compliance note: The B2B e-invoice line-item must include the
product GTIN (if the product has one). We store the primary barcode here
and reference it from invoice lines.
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Index, UniqueConstraint
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class BarcodeType(str, enum.Enum):
    ean13 = "ean13"        # GTIN-13 — 13 digits — most retail
    upc_a = "upc_a"        # UPC-A — 12 digits — US-origin
    ean8 = "ean8"          # GTIN-8 — 8 digits — small items
    gtin14 = "gtin14"      # GTIN-14 — 14 digits — outer carton
    code128 = "code128"    # Code-128 — variable length — internal use
    qr = "qr"              # QR code — for ZATCA simplified invoices + promos
    custom = "custom"      # internal vendor code


class BarcodeScope(str, enum.Enum):
    primary = "primary"          # main retail barcode (one per variant)
    carton = "carton"            # outer shipping box
    inner = "inner"              # inner pack / 6-pack
    legacy = "legacy"            # old barcode kept for reference
    promotional = "promotional"  # temporary promo code


class Barcode(Base):
    """A barcode value that scans to a variant."""
    __tablename__ = "pilot_barcodes"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="CASCADE"), nullable=False, index=True)

    # The barcode value (digits or alphanumeric for Code-128)
    value = Column(String(50), nullable=False)

    # Barcode symbology / format
    type = Column(String(20), nullable=False, default=BarcodeType.ean13.value)

    # What this barcode represents (primary, carton, etc.)
    scope = Column(String(20), nullable=False, default=BarcodeScope.primary.value)

    # Pack size represented — for carton codes, this is "how many units scan as one"
    # Example: carton barcode for a 24-pack → units_per_scan = 24
    units_per_scan = Column(Integer, nullable=False, default=1)

    # Optional: who printed the label (manufacturer code)
    manufacturer_code = Column(String(20), nullable=True)

    # Has this been validated (checksum verified for EAN-13 / UPC-A)?
    is_validated = Column(Boolean, nullable=False, default=False)
    validated_at = Column(DateTime(timezone=True), nullable=True)

    is_active = Column(Boolean, nullable=False, default=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    variant = relationship("ProductVariant", back_populates="barcodes")

    __table_args__ = (
        # Same barcode value cannot appear twice in the same tenant
        # (different tenants CAN share — e.g., two shops selling the same
        #  factory product)
        UniqueConstraint("tenant_id", "value", name="uq_pilot_barcode_tenant_value"),
        # Only one PRIMARY barcode per variant
        Index("ix_pilot_barcode_variant_scope", "variant_id", "scope"),
        Index("ix_pilot_barcode_tenant_value", "tenant_id", "value"),
    )


def compute_ean13_checksum(first_12_digits: str) -> int:
    """Compute EAN-13 check digit for the given 12-digit prefix.

    Algorithm: multiply each digit alternately by 1 and 3, sum,
    then the check digit = (10 - (sum mod 10)) mod 10.

    Example: 629012345678? → checksum = ?
      digits = 6,2,9,0,1,2,3,4,5,6,7,8
      weights = 1,3,1,3,1,3,1,3,1,3,1,3
      products = 6,6,9,0,1,6,3,12,5,18,7,24 → sum=97
      checksum = (10 - (97 mod 10)) mod 10 = (10-7) mod 10 = 3
      → full EAN-13: 6290123456783
    """
    if len(first_12_digits) != 12 or not first_12_digits.isdigit():
        raise ValueError("EAN-13 prefix must be exactly 12 digits")
    total = 0
    for i, ch in enumerate(first_12_digits):
        weight = 3 if i % 2 else 1
        total += int(ch) * weight
    return (10 - (total % 10)) % 10


def validate_ean13(barcode: str) -> bool:
    """Validate a 13-digit EAN-13 barcode by recomputing the checksum."""
    if len(barcode) != 13 or not barcode.isdigit():
        return False
    return compute_ean13_checksum(barcode[:12]) == int(barcode[12])
