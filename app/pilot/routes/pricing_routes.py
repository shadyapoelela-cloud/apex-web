"""Price list routes (Day 5).

Endpoints:
  GET/POST            /pilot/tenants/{tid}/price-lists
  GET/PATCH/DELETE    /pilot/price-lists/{plid}
  POST                /pilot/price-lists/{plid}/activate   — approval + go-live
  POST                /pilot/price-lists/{plid}/archive
  GET/POST            /pilot/price-lists/{plid}/items
  PATCH/DELETE        /pilot/price-list-items/{iid}
  POST                /pilot/price-lists/{plid}/items/bulk  — CSV-like upload
  GET                 /pilot/price-lookup?tenant_id=&variant_id=&branch_id=&qty=
                                         &at_time=            — POS resolver
"""

from datetime import datetime, timezone, date
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from app.phase1.models.platform_models import get_db
from app.pilot.models import (
    Tenant, Entity, Branch, ProductVariant, Currency,
    PriceList, PriceListItem, PriceListBranch,
    PriceListScope, PriceListStatus,
)
from app.pilot.schemas.pricing import (
    PriceListCreate, PriceListRead, PriceListDetail, PriceListUpdate,
    PriceListItemCreate, PriceListItemRead, PriceListItemUpdate,
    PriceListActivate, PriceListBulkItems,
    PriceLookupResponse,
)

router = APIRouter(prefix="/pilot", tags=["pilot-pricing"])


# ──────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────

def _tenant_or_404(db: Session, tid: str) -> Tenant:
    t = db.query(Tenant).filter(Tenant.id == tid).first()
    if not t:
        raise HTTPException(404, f"Tenant {tid} not found")
    return t


def _pricelist_or_404(db: Session, plid: str) -> PriceList:
    pl = db.query(PriceList).filter(PriceList.id == plid, PriceList.is_deleted == False).first()  # noqa: E712
    if not pl:
        raise HTTPException(404, f"Price list {plid} not found")
    return pl


def _compute_margin(price: Decimal, cost: Optional[Decimal]) -> Optional[Decimal]:
    if cost is None or price == 0:
        return None
    return ((price - cost) / price * Decimal("100")).quantize(Decimal("0.0001"))


def _item_dict(it: PriceListItem) -> dict:
    d = PriceListItemRead.model_validate(it).model_dump()
    return d


# ──────────────────────────────────────────────────────────────────────────
# Price Lists (headers)
# ──────────────────────────────────────────────────────────────────────────

@router.get("/tenants/{tenant_id}/price-lists", response_model=list[PriceListRead])
def list_price_lists(
    tenant_id: str,
    active_only: bool = Query(True),
    kind: Optional[str] = Query(None),
    scope: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    _tenant_or_404(db, tenant_id)
    q = db.query(PriceList).filter(
        PriceList.tenant_id == tenant_id,
        PriceList.is_deleted == False,  # noqa: E712
    )
    if active_only:
        q = q.filter(PriceList.is_active == True)  # noqa: E712
    if kind:
        q = q.filter(PriceList.kind == kind)
    if scope:
        q = q.filter(PriceList.scope == scope)
    return q.order_by(PriceList.priority.desc(), PriceList.code).all()


@router.post("/tenants/{tenant_id}/price-lists", response_model=PriceListDetail, status_code=201)
def create_price_list(tenant_id: str, payload: PriceListCreate, db: Session = Depends(get_db)):
    tenant = _tenant_or_404(db, tenant_id)

    # Code uniqueness
    if db.query(PriceList).filter(
        PriceList.tenant_id == tenant_id, PriceList.code == payload.code
    ).first():
        raise HTTPException(409, f"Price list code '{payload.code}' already exists")

    # Currency must exist for this tenant
    if not db.query(Currency).filter(
        Currency.tenant_id == tenant_id, Currency.code == payload.currency.upper()
    ).first():
        raise HTTPException(400, f"Currency '{payload.currency}' is not enabled for this tenant")

    # Scope-specific validation
    if payload.scope == "entity":
        if not payload.entity_id:
            raise HTTPException(400, "entity_id is required when scope=entity")
        if not db.query(Entity).filter(
            Entity.id == payload.entity_id, Entity.tenant_id == tenant_id
        ).first():
            raise HTTPException(400, "entity_id not found in this tenant")
    elif payload.scope == "branch":
        if not payload.branch_ids:
            raise HTTPException(400, "branch_ids is required when scope=branch")
        found = db.query(Branch).filter(
            Branch.id.in_(payload.branch_ids),
            Branch.tenant_id == tenant_id,
            Branch.is_deleted == False,  # noqa: E712
        ).all()
        if len(found) != len(set(payload.branch_ids)):
            raise HTTPException(400, "One or more branch_ids are invalid for this tenant")

    # Validity check
    if payload.valid_to and payload.valid_to < payload.valid_from:
        raise HTTPException(400, "valid_to must be on or after valid_from")

    pl = PriceList(
        tenant_id=tenant_id,
        code=payload.code,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        description_ar=payload.description_ar,
        kind=payload.kind,
        season=payload.season,
        currency=payload.currency.upper(),
        scope=payload.scope,
        entity_id=payload.entity_id,
        customer_group_code=payload.customer_group_code,
        valid_from=payload.valid_from,
        valid_to=payload.valid_to,
        priority=payload.priority,
        status=PriceListStatus.draft.value,
        is_active=False,
        is_promo=payload.is_promo,
        promo_name_ar=payload.promo_name_ar,
        promo_badge_text_ar=payload.promo_badge_text_ar,
        promo_color_hex=payload.promo_color_hex,
        prices_include_vat=payload.prices_include_vat,
        rounding_method=payload.rounding_method,
    )
    db.add(pl)
    db.flush()

    # Branches
    if payload.scope == "branch":
        for bid in payload.branch_ids:
            db.add(PriceListBranch(price_list_id=pl.id, branch_id=bid))

    # Inline items
    item_rows = []
    for it in payload.items:
        if not db.query(ProductVariant).filter(
            ProductVariant.id == it.variant_id,
            ProductVariant.tenant_id == tenant_id,
        ).first():
            raise HTTPException(400, f"variant_id '{it.variant_id}' not found in this tenant")
        row = PriceListItem(
            tenant_id=tenant_id,
            price_list_id=pl.id,
            variant_id=it.variant_id,
            unit_price=it.unit_price,
            unit_cost=it.unit_cost,
            margin_pct=_compute_margin(it.unit_price, it.unit_cost),
            min_qty=it.min_qty,
            promo_discount_pct=it.promo_discount_pct,
            original_price=it.original_price,
            promo_starts_at=it.promo_starts_at,
            promo_ends_at=it.promo_ends_at,
            reference_note=it.reference_note,
        )
        db.add(row)
        item_rows.append(row)

    db.commit()
    db.refresh(pl)

    items_all = db.query(PriceListItem).filter(PriceListItem.price_list_id == pl.id).all()
    branches = db.query(PriceListBranch).filter(PriceListBranch.price_list_id == pl.id).all()

    return PriceListDetail(
        **PriceListRead.model_validate(pl).model_dump(),
        branch_ids=[b.branch_id for b in branches],
        item_count=len(items_all),
        items=[PriceListItemRead.model_validate(i) for i in items_all],
    )


@router.get("/price-lists/{pl_id}", response_model=PriceListDetail)
def get_price_list(pl_id: str, db: Session = Depends(get_db)):
    pl = _pricelist_or_404(db, pl_id)
    items = db.query(PriceListItem).filter(PriceListItem.price_list_id == pl.id).all()
    branches = db.query(PriceListBranch).filter(PriceListBranch.price_list_id == pl.id).all()
    return PriceListDetail(
        **PriceListRead.model_validate(pl).model_dump(),
        branch_ids=[b.branch_id for b in branches],
        item_count=len(items),
        items=[PriceListItemRead.model_validate(i) for i in items],
    )


@router.patch("/price-lists/{pl_id}", response_model=PriceListRead)
def update_price_list(pl_id: str, payload: PriceListUpdate, db: Session = Depends(get_db)):
    pl = _pricelist_or_404(db, pl_id)
    if pl.status == PriceListStatus.archived.value:
        raise HTTPException(409, "Cannot modify archived price list")
    for field, val in payload.model_dump(exclude_unset=True).items():
        setattr(pl, field, val)
    db.commit()
    db.refresh(pl)
    return pl


@router.delete("/price-lists/{pl_id}", status_code=204)
def delete_price_list(pl_id: str, db: Session = Depends(get_db)):
    pl = _pricelist_or_404(db, pl_id)
    pl.is_deleted = True
    pl.deleted_at = datetime.now(timezone.utc)
    pl.is_active = False
    pl.status = PriceListStatus.archived.value
    db.commit()
    return None


@router.post("/price-lists/{pl_id}/activate", response_model=PriceListRead)
def activate_price_list(pl_id: str, payload: PriceListActivate, db: Session = Depends(get_db)):
    """Move a price list from draft → active (or expired → active if still within window)."""
    pl = _pricelist_or_404(db, pl_id)
    item_count = db.query(PriceListItem).filter(PriceListItem.price_list_id == pl.id).count()
    if item_count == 0:
        raise HTTPException(409, "Cannot activate an empty price list — add items first")

    now = datetime.now(timezone.utc)
    today = now.date()
    if pl.valid_to and pl.valid_to < today:
        raise HTTPException(409, f"Price list validity expired ({pl.valid_to.isoformat()})")

    pl.status = PriceListStatus.active.value
    pl.is_active = True
    pl.approved_at = now
    pl.approved_by_user_id = payload.approved_by_user_id
    db.commit()
    db.refresh(pl)
    return pl


@router.post("/price-lists/{pl_id}/archive", response_model=PriceListRead)
def archive_price_list(pl_id: str, db: Session = Depends(get_db)):
    pl = _pricelist_or_404(db, pl_id)
    pl.status = PriceListStatus.archived.value
    pl.is_active = False
    db.commit()
    db.refresh(pl)
    return pl


# ──────────────────────────────────────────────────────────────────────────
# Price List Items
# ──────────────────────────────────────────────────────────────────────────

@router.get("/price-lists/{pl_id}/items", response_model=list[PriceListItemRead])
def list_items(pl_id: str, db: Session = Depends(get_db)):
    _pricelist_or_404(db, pl_id)
    return db.query(PriceListItem).filter(PriceListItem.price_list_id == pl_id).all()


@router.post("/price-lists/{pl_id}/items", response_model=PriceListItemRead, status_code=201)
def add_item(pl_id: str, payload: PriceListItemCreate, db: Session = Depends(get_db)):
    pl = _pricelist_or_404(db, pl_id)
    if not db.query(ProductVariant).filter(
        ProductVariant.id == payload.variant_id,
        ProductVariant.tenant_id == pl.tenant_id,
    ).first():
        raise HTTPException(400, "variant_id not found in this tenant")
    # Check for duplicate (variant, min_qty) tier
    if db.query(PriceListItem).filter(
        PriceListItem.price_list_id == pl_id,
        PriceListItem.variant_id == payload.variant_id,
        PriceListItem.min_qty == payload.min_qty,
    ).first():
        raise HTTPException(409, "A tier with this variant + min_qty already exists")
    it = PriceListItem(
        tenant_id=pl.tenant_id,
        price_list_id=pl_id,
        variant_id=payload.variant_id,
        unit_price=payload.unit_price,
        unit_cost=payload.unit_cost,
        margin_pct=_compute_margin(payload.unit_price, payload.unit_cost),
        min_qty=payload.min_qty,
        promo_discount_pct=payload.promo_discount_pct,
        original_price=payload.original_price,
        promo_starts_at=payload.promo_starts_at,
        promo_ends_at=payload.promo_ends_at,
        reference_note=payload.reference_note,
    )
    db.add(it)
    db.commit()
    db.refresh(it)
    return it


@router.patch("/price-list-items/{item_id}", response_model=PriceListItemRead)
def update_item(item_id: str, payload: PriceListItemUpdate, db: Session = Depends(get_db)):
    it = db.query(PriceListItem).filter(PriceListItem.id == item_id).first()
    if not it:
        raise HTTPException(404, "Item not found")
    data = payload.model_dump(exclude_unset=True)
    for field, val in data.items():
        setattr(it, field, val)
    # Recompute margin if price or cost changed
    if "unit_price" in data or "unit_cost" in data:
        it.margin_pct = _compute_margin(it.unit_price, it.unit_cost)
    db.commit()
    db.refresh(it)
    return it


@router.delete("/price-list-items/{item_id}", status_code=204)
def delete_item(item_id: str, db: Session = Depends(get_db)):
    it = db.query(PriceListItem).filter(PriceListItem.id == item_id).first()
    if not it:
        raise HTTPException(404, "Item not found")
    db.delete(it)
    db.commit()
    return None


@router.post("/price-lists/{pl_id}/items/bulk")
def bulk_upsert_items(pl_id: str, payload: PriceListBulkItems, db: Session = Depends(get_db)):
    """Upload many items at once. Use for Excel/CSV imports."""
    pl = _pricelist_or_404(db, pl_id)

    if payload.replace_existing:
        db.query(PriceListItem).filter(PriceListItem.price_list_id == pl_id).delete()
        db.flush()

    added, updated = 0, 0
    for it in payload.items:
        if not db.query(ProductVariant).filter(
            ProductVariant.id == it.variant_id,
            ProductVariant.tenant_id == pl.tenant_id,
        ).first():
            raise HTTPException(400, f"variant_id '{it.variant_id}' not found in this tenant")

        existing = db.query(PriceListItem).filter(
            PriceListItem.price_list_id == pl_id,
            PriceListItem.variant_id == it.variant_id,
            PriceListItem.min_qty == it.min_qty,
        ).first()
        if existing:
            existing.unit_price = it.unit_price
            existing.unit_cost = it.unit_cost
            existing.margin_pct = _compute_margin(it.unit_price, it.unit_cost)
            existing.promo_discount_pct = it.promo_discount_pct
            existing.original_price = it.original_price
            existing.promo_starts_at = it.promo_starts_at
            existing.promo_ends_at = it.promo_ends_at
            existing.reference_note = it.reference_note
            updated += 1
        else:
            db.add(PriceListItem(
                tenant_id=pl.tenant_id,
                price_list_id=pl_id,
                variant_id=it.variant_id,
                unit_price=it.unit_price,
                unit_cost=it.unit_cost,
                margin_pct=_compute_margin(it.unit_price, it.unit_cost),
                min_qty=it.min_qty,
                promo_discount_pct=it.promo_discount_pct,
                original_price=it.original_price,
                promo_starts_at=it.promo_starts_at,
                promo_ends_at=it.promo_ends_at,
                reference_note=it.reference_note,
            ))
            added += 1
    db.commit()
    return {"success": True, "added": added, "updated": updated,
            "replaced_all": payload.replace_existing}


# ──────────────────────────────────────────────────────────────────────────
# Price lookup (POS resolver)
# ──────────────────────────────────────────────────────────────────────────

@router.get("/price-lookup", response_model=PriceLookupResponse)
def price_lookup(
    tenant_id: str = Query(...),
    variant_id: str = Query(...),
    branch_id: Optional[str] = Query(None),
    qty: Decimal = Query(Decimal("1")),
    at_time: Optional[datetime] = Query(None),
    customer_group_code: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """Resolve the active price for (variant, branch, qty, time).

    Algorithm:
      1. Collect candidate PriceLists that:
         - belong to this tenant
         - is_active + not deleted + not archived
         - at_time falls within [valid_from, valid_to]
         - scope includes this branch:
            * tenant-scoped → always
            * entity-scoped → branch.entity_id == list.entity_id
            * branch-scoped → list has a PriceListBranch row for branch_id
            * customer_group → customer_group_code matches
      2. For each candidate list, find the item with variant_id and the
         LARGEST min_qty ≤ requested qty.
      3. Sort candidates by priority DESC, valid_from DESC → pick first.
      4. If nothing found, fall back to variant.list_price / variant.currency.
    """
    _tenant_or_404(db, tenant_id)
    now = at_time or datetime.now(timezone.utc)
    today = now.date()

    variant = db.query(ProductVariant).filter(
        ProductVariant.id == variant_id,
        ProductVariant.tenant_id == tenant_id,
    ).first()
    if not variant:
        raise HTTPException(404, "Variant not found")

    branch = None
    if branch_id:
        branch = db.query(Branch).filter(Branch.id == branch_id, Branch.tenant_id == tenant_id).first()
        if not branch:
            raise HTTPException(400, "branch_id invalid for this tenant")

    # Step 1: candidate lists
    base_q = db.query(PriceList).filter(
        PriceList.tenant_id == tenant_id,
        PriceList.is_active == True,  # noqa: E712
        PriceList.is_deleted == False,  # noqa: E712
        PriceList.valid_from <= today,
        or_(PriceList.valid_to.is_(None), PriceList.valid_to >= today),
    )
    candidates: list[PriceList] = []
    for pl in base_q.order_by(PriceList.priority.desc(), PriceList.valid_from.desc()).all():
        if pl.scope == PriceListScope.tenant.value:
            candidates.append(pl)
        elif pl.scope == PriceListScope.entity.value:
            if branch and branch.entity_id == pl.entity_id:
                candidates.append(pl)
        elif pl.scope == PriceListScope.branch.value:
            if branch and db.query(PriceListBranch).filter(
                PriceListBranch.price_list_id == pl.id,
                PriceListBranch.branch_id == branch_id,
            ).first():
                candidates.append(pl)
        elif pl.scope == PriceListScope.customer_group.value:
            if customer_group_code and pl.customer_group_code == customer_group_code:
                candidates.append(pl)

    # Step 2: find matching item (largest min_qty ≤ qty) in each candidate
    best: Optional[tuple[PriceList, PriceListItem]] = None
    for pl in candidates:
        item = db.query(PriceListItem).filter(
            PriceListItem.price_list_id == pl.id,
            PriceListItem.variant_id == variant_id,
            PriceListItem.min_qty <= qty,
            PriceListItem.is_active == True,  # noqa: E712
        ).order_by(PriceListItem.min_qty.desc()).first()
        if item:
            best = (pl, item)
            break  # priority-ordered list → first match wins

    if best:
        pl, item = best
        is_promo = bool(pl.is_promo or item.promo_discount_pct)
        # Apply item-level promo discount if present
        final_price = item.unit_price
        if item.promo_discount_pct and (
            not item.promo_starts_at or item.promo_starts_at <= now
        ) and (
            not item.promo_ends_at or item.promo_ends_at >= now
        ):
            final_price = (item.unit_price *
                           (Decimal("100") - item.promo_discount_pct) /
                           Decimal("100")).quantize(Decimal("0.01"))

        return PriceLookupResponse(
            variant_id=variant_id,
            branch_id=branch_id,
            at_time=now,
            qty=qty,
            unit_price=final_price,
            currency=pl.currency,
            prices_include_vat=pl.prices_include_vat,
            source="price_list",
            price_list_id=pl.id,
            price_list_code=pl.code,
            price_list_name_ar=pl.name_ar,
            item_id=item.id,
            is_promo=is_promo,
            promo_discount_pct=item.promo_discount_pct,
            original_price=item.original_price or (item.unit_price if item.promo_discount_pct else None),
            promo_badge_text_ar=pl.promo_badge_text_ar,
            promo_color_hex=pl.promo_color_hex,
        )

    # Fallback: variant default list_price
    if variant.list_price is not None:
        return PriceLookupResponse(
            variant_id=variant_id,
            branch_id=branch_id,
            at_time=now,
            qty=qty,
            unit_price=variant.list_price,
            currency=variant.currency,
            prices_include_vat=True,
            source="variant_default",
        )

    # No price defined anywhere
    return PriceLookupResponse(
        variant_id=variant_id,
        branch_id=branch_id,
        at_time=now,
        qty=qty,
        unit_price=Decimal("0"),
        currency=variant.currency,
        prices_include_vat=True,
        source="no_price",
    )
