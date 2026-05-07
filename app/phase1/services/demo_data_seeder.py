"""G-DEMO-DATA-SEEDER (2026-05-08) — master-data tier.

After ERR-2 Phase 3 (PR #169) + Legacy Migration (PR #170), every
tenant starts empty. The frontend chips wired in PR #161 work, but
they have no data to render — stakeholder demos show blank screens.
This module seeds a tenant with realistic Saudi-retail master data
so the customer / vendor / product chips have something to look at.

Scope (v1 — master data only)
-----------------------------
This PR seeds three tables:
    pilot_customers        — 5 rows (Arabic name + Saudi-style code)
    pilot_vendors          — 5 rows
    pilot_products         — 15 rows (mixed office + IT goods)

That's ~25 records, all tenant-scoped (the existing
`TenantContextMiddleware` + `attach_tenant_guard` honor tenant_id on
every row), so calling the seeder for tenant A never leaks into
tenant B.

Out of scope for v1 (deferred to G-DEMO-DATA-SEEDER-V2)
-------------------------------------------------------
The original spec asked for journal entries, sales/purchase invoices,
and payments. Those need a curated FK chain — Entity, FiscalPeriod,
~8 `pilot_gl_accounts` rows for the JE side, AR/AP control accounts,
running invoice numbers, etc. — that the codebase doesn't yet have a
packaged seeder for. Bundling all of that into one PR would create a
high-regression-risk migration. Better to ship the master-data tier
now (closes the "blank chips" UX) and queue the GL+invoice extension
as its own focused PR.

Idempotency
-----------
The sentinel is "any `pilot_customers` row owned by this tenant". On
second invocation we return `{"skipped": true, ...}` without touching
the DB. `force=True` overrides — but does NOT delete; it just appends
another batch (with fresh codes generated to avoid the
`uq_pilot_customers_tenant_code` collision).
"""

from __future__ import annotations

import logging
from decimal import Decimal
from typing import Any

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────────
# Seed payloads — kept as data so the test suite can assert on counts
# without re-importing the constants from inside the function bodies.
# ────────────────────────────────────────────────────────────────────


# (name_ar, code_suffix)
_CUSTOMER_SEED: list[tuple[str, str]] = [
    ("شركة الراجحي للتجارة", "RTC-001"),
    ("مؤسسة النمر للمقاولات", "NMR-002"),
    ("شركة العنود للتسويق", "ANW-003"),
    ("متجر الفجر الإلكتروني", "FJR-004"),
    ("شركة المثلث للخدمات", "MTH-005"),
]


# (legal_name_ar, code_suffix)
_VENDOR_SEED: list[tuple[str, str]] = [
    ("شركة المعدن للأدوات الصناعية", "MTL-001"),
    ("مؤسسة الفهد للنظافة والصيانة", "FHD-002"),
    ("شركة النجم للقرطاسية", "NJM-003"),
    ("مؤسسة البركة للمواد الغذائية", "BRK-004"),
    ("شركة السحاب للحوسبة السحابية", "SHB-005"),
]


# (name_ar, code_suffix, default_uom)
_PRODUCT_SEED: list[tuple[str, str, str]] = [
    ("ورق طباعة A4 — 80 جم", "PAP-A4-80", "ream"),
    ("لابتوب ديل لاتيتيود 14", "LAP-DELL-LAT", "piece"),
    ("ماوس لاسلكي لوجيتك", "MOU-LOG-WL", "piece"),
    ("شاشة LG 24 بوصة", "MON-LG-24", "piece"),
    ("كرسي مكتبي إرغونومي", "CHR-ERG-1", "piece"),
    ("مكتب خشبي مودرن", "DSK-MOD-1", "piece"),
    ("طابعة ليزر ملوّنة", "PRT-LSR-CL", "piece"),
    ("مكنسة كهربائية صناعية", "VAC-IND-1", "piece"),
    ("كرتون قهوة عربية", "COF-AR-CTN", "carton"),
    ("علبة شاي أحمر", "TEA-RED-BOX", "box"),
    ("مكيّف هواء سبليت 18000 وحدة", "AC-SPL-18K", "piece"),
    ("حقيبة لابتوب جلدية", "BAG-LTH-1", "piece"),
    ("سجل دفتر يومية A5", "BOK-JRN-A5", "piece"),
    ("مجموعة أقلام كروية (10 قطع)", "PEN-BAL-10", "pack"),
    ("منظف زجاج (5 لتر)", "CLN-GLS-5L", "bottle"),
]


def is_already_seeded(db: Session, tenant_id: str) -> bool:
    """True if this tenant already has seeded master data.

    Sentinel: any `pilot_customers` row owned by the tenant. Cheaper
    than a Tenant.demo_seeded boolean column (no schema change), and
    accurate enough — the seeder always inserts customers as the
    first batch, so a tenant with customers has been (at least
    partially) seeded.
    """
    from app.pilot.models.customer import Customer

    return (
        db.query(Customer.id)
        .filter(Customer.tenant_id == tenant_id)
        .first()
        is not None
    )


def _seed_customers(
    db: Session, tenant_id: str, code_suffix: str = ""
) -> int:
    """Insert the 5 demo customers. Returns count inserted."""
    from app.pilot.models.customer import Customer

    inserted = 0
    for name_ar, code in _CUSTOMER_SEED:
        db.add(
            Customer(
                tenant_id=tenant_id,
                code=f"{code}{code_suffix}",
                name_ar=name_ar,
                # Other fields fall back to model defaults:
                #   kind=CustomerKind.company.value
                #   currency="SAR"
                #   payment_terms=CustomerPaymentTerms.net_30.value
                address_country="SA",
                is_active=True,
            )
        )
        inserted += 1
    db.flush()
    return inserted


def _seed_vendors(
    db: Session, tenant_id: str, code_suffix: str = ""
) -> int:
    """Insert the 5 demo vendors. Returns count inserted."""
    from app.pilot.models.purchasing import Vendor

    inserted = 0
    for legal_name_ar, code in _VENDOR_SEED:
        db.add(
            Vendor(
                tenant_id=tenant_id,
                code=f"{code}{code_suffix}",
                legal_name_ar=legal_name_ar,
                # Defaults:
                #   kind=VendorKind.goods.value
                #   country="SA"
                #   default_currency="SAR"
                #   payment_terms=PaymentTerms.net_30.value
                is_active=True,
            )
        )
        inserted += 1
    db.flush()
    return inserted


def _seed_products(
    db: Session, tenant_id: str, code_suffix: str = ""
) -> int:
    """Insert the 15 demo products. Returns count inserted."""
    from app.pilot.models.product import Product, ProductStatus

    inserted = 0
    for name_ar, code, default_uom in _PRODUCT_SEED:
        db.add(
            Product(
                tenant_id=tenant_id,
                code=f"{code}{code_suffix}",
                name_ar=name_ar,
                default_uom=default_uom,
                status=ProductStatus.active.value,
                # Defaults pick up:
                #   kind=ProductKind.goods.value
                #   vat_code=VatCode.standard.value
                #   is_sellable / is_purchasable / is_stockable=True
            )
        )
        inserted += 1
    db.flush()
    return inserted


def seed_demo_data(
    db: Session,
    tenant_id: str,
    *,
    force: bool = False,
) -> dict[str, Any]:
    """Seed master data for a tenant. Idempotent unless `force=True`.

    Args:
        db: open SQLAlchemy session — caller closes it.
        tenant_id: target tenant. Must exist in `pilot_tenants`.
        force: when True, append another batch even if data already
            exists. Codes are de-duplicated by adding a short suffix
            so the unique constraint doesn't fire.

    Returns the JSON-friendly summary dict the admin / user
    endpoints surface to the caller.
    """
    # 1. Validate tenant exists. We refuse rather than silently
    #    seeding for a tenant that wasn't created — the caller
    #    most likely passed a wrong id.
    from app.pilot.models.tenant import Tenant

    tenant = (
        db.query(Tenant).filter(Tenant.id == tenant_id).one_or_none()
    )
    if tenant is None:
        raise ValueError(f"Tenant {tenant_id!r} not found")

    # 2. Idempotency check.
    if not force and is_already_seeded(db, tenant_id):
        return {
            "success": True,
            "skipped": True,
            "tenant_id": tenant_id,
            "reason": (
                "Tenant already has seeded master data. Pass "
                "force=true to append another batch."
            ),
        }

    # 3. Force-append needs a unique suffix on the codes so the
    #    `uq_pilot_customers_tenant_code` (and vendor / product
    #    equivalents) don't collide. Use a short hex from time-uuid.
    suffix = ""
    if force:
        from uuid import uuid4

        suffix = f"-{uuid4().hex[:6]}"

    # 4. Seed in dependency order (master data has no inter-row FKs
    #    among these three so order is just for the human reading
    #    the summary).
    customers = _seed_customers(db, tenant_id, code_suffix=suffix)
    vendors = _seed_vendors(db, tenant_id, code_suffix=suffix)
    products = _seed_products(db, tenant_id, code_suffix=suffix)

    db.commit()

    summary = {
        "success": True,
        "skipped": False,
        "tenant_id": tenant_id,
        "summary": {
            "master_data": {
                "customers": customers,
                "vendors": vendors,
                "products": products,
            },
            "deferred": {
                "journal_entries": 0,
                "sales_invoices": 0,
                "purchase_invoices": 0,
                "payments": 0,
                "_note": (
                    "GL + invoice + payment seeding is deferred to "
                    "G-DEMO-DATA-SEEDER-V2 — see service docstring."
                ),
            },
        },
    }
    logger.info(
        "G-DEMO-DATA-SEEDER: seeded tenant=%s customers=%d vendors=%d products=%d",
        tenant_id,
        customers,
        vendors,
        products,
    )
    return summary
