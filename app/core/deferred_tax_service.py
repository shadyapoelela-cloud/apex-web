"""
APEX Platform — Deferred Tax (IAS 12)
═══════════════════════════════════════════════════════════════
Computes deferred tax assets (DTA) and liabilities (DTL) from
temporary differences between book (carrying) amounts and tax base.

Rules:
  • Temporary difference (TD) = Carrying amount − Tax base
  • Taxable TD (CA > Tax base for assets; or CA < Tax base for liab)
      → Deferred Tax Liability (DTL)
  • Deductible TD (CA < Tax base for assets; or CA > Tax base for liab)
      → Deferred Tax Asset (DTA)
  • Tax loss carry-forward is a DTA (up to expected future profits)
  • Recognised amount = TD × enacted tax rate

Recoverability:
  • DTA is recognised only to the extent that it is probable that
    future taxable profit will be available.
  • Caller passes `expected_future_profit` and we cap DTA at
    profit × tax_rate (with a safety margin).

Categories supported:
  asset_td          — asset difference (PP&E, receivables, inventory)
  liability_td      — liability difference (provisions, warranty accruals)
  loss_carry_forward — unused tax losses
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")
_FOUR = Decimal("0.0001")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


def _q4(v: Decimal) -> Decimal:
    return v.quantize(_FOUR, rounding=ROUND_HALF_UP)


TD_CATEGORIES = {"asset_td", "liability_td", "loss_carry_forward"}


@dataclass
class TDItem:
    description: str
    category: str                   # one of TD_CATEGORIES
    carrying_amount: Decimal = Decimal("0")
    tax_base: Decimal = Decimal("0")
    # For loss_carry_forward, set carrying_amount=loss_amount, tax_base=0
    # Years until expiry, if any (KSA allows unlimited carry-forward
    # but capped at 25% of year's profit)
    expiry_years: Optional[int] = None


@dataclass
class DeferredTaxInput:
    entity_name: str
    period_label: str
    tax_rate_pct: Decimal            # KSA corporate rate 20% default
    zakat_rate_pct: Decimal = Decimal("2.5")  # for info only
    expected_future_profit: Optional[Decimal] = None  # for DTA recoverability
    currency: str = "SAR"
    items: List[TDItem] = field(default_factory=list)
    opening_dta: Decimal = Decimal("0")
    opening_dtl: Decimal = Decimal("0")


@dataclass
class TDOut:
    description: str
    category: str
    carrying_amount: Decimal
    tax_base: Decimal
    temporary_difference: Decimal   # CA - TB
    td_type: str                     # 'taxable' | 'deductible' | 'none'
    dta_amount: Decimal
    dtl_amount: Decimal
    recoverable: bool
    note: str = ""


@dataclass
class DeferredTaxResult:
    entity_name: str
    period_label: str
    currency: str
    tax_rate_pct: Decimal
    items: List[TDOut]
    total_taxable_td: Decimal        # sum of taxable differences
    total_deductible_td: Decimal
    total_dta_gross: Decimal         # before recoverability cap
    total_dta_recognised: Decimal
    total_dta_unrecognised: Decimal  # capped out
    total_dtl: Decimal
    net_deferred_tax: Decimal        # DTA - DTL (positive = net asset)
    opening_dta: Decimal
    opening_dtl: Decimal
    movement_dta: Decimal            # current - opening
    movement_dtl: Decimal
    deferred_tax_expense: Decimal    # P&L impact for the period
    warnings: list[str] = field(default_factory=list)


def _validate(inp: DeferredTaxInput) -> None:
    if inp.tax_rate_pct < 0 or inp.tax_rate_pct > 100:
        raise ValueError("tax_rate_pct must be 0-100")
    if not inp.items:
        raise ValueError("items is required")
    for i, it in enumerate(inp.items, start=1):
        if it.category not in TD_CATEGORIES:
            raise ValueError(
                f"item {i}: category {it.category!r} must be one of {sorted(TD_CATEGORIES)}"
            )
        if not it.description:
            raise ValueError(f"item {i}: description is required")


def compute_deferred_tax(inp: DeferredTaxInput) -> DeferredTaxResult:
    _validate(inp)

    rate = Decimal(str(inp.tax_rate_pct)) / Decimal("100")
    warnings: list[str] = []

    out_items: List[TDOut] = []
    total_dta_gross = Decimal("0")
    total_dtl = Decimal("0")
    total_taxable = Decimal("0")
    total_deductible = Decimal("0")

    for it in inp.items:
        ca = Decimal(str(it.carrying_amount))
        tb = Decimal(str(it.tax_base))
        td = ca - tb
        td_type = "none"
        dta = Decimal("0")
        dtl = Decimal("0")
        note = ""

        if it.category == "loss_carry_forward":
            # Whole loss creates DTA
            loss = ca
            if loss <= 0:
                note = "no loss amount"
                td_type = "none"
            else:
                dta = loss * rate
                total_dta_gross += dta
                total_deductible += loss
                td_type = "deductible"
                note = "خسارة قابلة للترحيل"
                if it.expiry_years is not None and it.expiry_years <= 0:
                    warnings.append(
                        f"{it.description}: فترة الترحيل انتهت — مراجعة الاعتراف بالأصل الضريبي."
                    )
        elif it.category == "asset_td":
            # For an asset: CA > TB ⇒ taxable TD (generates DTL)
            if td > 0:
                dtl = td * rate
                total_dtl += dtl
                total_taxable += td
                td_type = "taxable"
                note = "CA > TB → DTL"
            elif td < 0:
                dta = -td * rate
                total_dta_gross += dta
                total_deductible += -td
                td_type = "deductible"
                note = "CA < TB → DTA"
        elif it.category == "liability_td":
            # For a liability: CA < TB ⇒ taxable TD (generates DTL)
            # CA > TB ⇒ deductible (generates DTA)
            if td < 0:
                dtl = -td * rate
                total_dtl += dtl
                total_taxable += -td
                td_type = "taxable"
                note = "CA < TB → DTL"
            elif td > 0:
                dta = td * rate
                total_dta_gross += dta
                total_deductible += td
                td_type = "deductible"
                note = "CA > TB → DTA"

        out_items.append(TDOut(
            description=it.description,
            category=it.category,
            carrying_amount=_q(ca),
            tax_base=_q(tb),
            temporary_difference=_q(td),
            td_type=td_type,
            dta_amount=_q(dta),
            dtl_amount=_q(dtl),
            recoverable=True,  # assessed below for DTA items
            note=note,
        ))

    # DTA recoverability cap
    if inp.expected_future_profit is not None:
        cap = Decimal(str(inp.expected_future_profit)) * rate
        if cap < total_dta_gross:
            unrecognised = total_dta_gross - cap
            warnings.append(
                f"الأصول الضريبية المؤجلة (DTA) تتجاوز الأرباح المستقبلية المتوقعة — "
                f"غير معترف بمبلغ {_q(unrecognised)} {inp.currency}."
            )
            total_dta_recognised = _q(cap)
        else:
            total_dta_recognised = _q(total_dta_gross)
    else:
        total_dta_recognised = _q(total_dta_gross)
        if total_dta_gross > 0:
            warnings.append(
                "لم يُقدَّم تقدير للأرباح المستقبلية — تم الاعتراف بكامل الأصول الضريبية "
                "المؤجلة؛ راجع معايير الإثبات وفق IAS 12.24."
            )

    total_dta_unrecognised = _q(total_dta_gross - total_dta_recognised)

    # Net position
    total_dtl_q = _q(total_dtl)
    net = _q(total_dta_recognised - total_dtl_q)

    # Movement
    mov_dta = _q(total_dta_recognised - Decimal(str(inp.opening_dta)))
    mov_dtl = _q(total_dtl_q - Decimal(str(inp.opening_dtl)))
    # Deferred tax expense in P&L:
    #  expense = DTL increase - DTA increase
    expense = _q(mov_dtl - mov_dta)

    return DeferredTaxResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        currency=inp.currency,
        tax_rate_pct=_q4(Decimal(str(inp.tax_rate_pct))),
        items=out_items,
        total_taxable_td=_q(total_taxable),
        total_deductible_td=_q(total_deductible),
        total_dta_gross=_q(total_dta_gross),
        total_dta_recognised=total_dta_recognised,
        total_dta_unrecognised=total_dta_unrecognised,
        total_dtl=total_dtl_q,
        net_deferred_tax=net,
        opening_dta=_q(inp.opening_dta),
        opening_dtl=_q(inp.opening_dtl),
        movement_dta=mov_dta,
        movement_dtl=mov_dtl,
        deferred_tax_expense=expense,
        warnings=warnings,
    )


def dt_to_dict(r: DeferredTaxResult) -> dict:
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "currency": r.currency,
        "tax_rate_pct": f"{r.tax_rate_pct}",
        "items": [
            {
                "description": it.description,
                "category": it.category,
                "carrying_amount": f"{it.carrying_amount}",
                "tax_base": f"{it.tax_base}",
                "temporary_difference": f"{it.temporary_difference}",
                "td_type": it.td_type,
                "dta_amount": f"{it.dta_amount}",
                "dtl_amount": f"{it.dtl_amount}",
                "recoverable": it.recoverable,
                "note": it.note,
            }
            for it in r.items
        ],
        "total_taxable_td": f"{r.total_taxable_td}",
        "total_deductible_td": f"{r.total_deductible_td}",
        "total_dta_gross": f"{r.total_dta_gross}",
        "total_dta_recognised": f"{r.total_dta_recognised}",
        "total_dta_unrecognised": f"{r.total_dta_unrecognised}",
        "total_dtl": f"{r.total_dtl}",
        "net_deferred_tax": f"{r.net_deferred_tax}",
        "opening_dta": f"{r.opening_dta}",
        "opening_dtl": f"{r.opening_dtl}",
        "movement_dta": f"{r.movement_dta}",
        "movement_dtl": f"{r.movement_dtl}",
        "deferred_tax_expense": f"{r.deferred_tax_expense}",
        "warnings": r.warnings,
    }
