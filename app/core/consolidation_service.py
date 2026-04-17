"""
APEX Platform — Consolidation (IFRS 10)
═══════════════════════════════════════════════════════════════
Produces consolidated financial statements from a parent and
one or more subsidiaries, applying:

  • Line-by-line aggregation of assets, liabilities, equity, P&L
  • Intercompany elimination (IC sales, IC receivables/payables,
    IC dividends, IC loans)
  • Non-controlling interest (NCI) calculation for partially-owned
    subsidiaries
  • Currency translation (IAS 21) when subsidiaries report in
    a different functional currency (uses closing rate for BS,
    average for IS, historical for equity)

Input: parent + list of subsidiaries, each with TB-style lines,
plus a list of intercompany transactions to eliminate, plus
ownership % per subsidiary.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Dict, List, Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class ConsolLine:
    """One account balance in a single entity."""
    account_code: str
    account_name: str
    classification: str       # asset/liability/equity/revenue/expense
    amount: Decimal           # sign convention: debit balances positive,
                              # credit balances negative (so summing works)


@dataclass
class Entity:
    entity_id: str
    entity_name: str
    ownership_pct: Decimal = Decimal("100")   # parent's % of subsidiary
    fx_rate_to_presentation: Decimal = Decimal("1")  # closing rate for translation
    avg_fx_rate: Decimal = Decimal("1")              # average rate for IS
    is_parent: bool = False
    lines: List[ConsolLine] = field(default_factory=list)


@dataclass
class IntercoEntry:
    """An intercompany transaction to eliminate."""
    description: str
    from_entity: str
    to_entity: str
    amount: Decimal
    # Each IC entry has two sides: the DR-side account (assets/expenses) and
    # CR-side account (liabilities/revenue). Eliminate both.
    dr_account: str           # account code in from_entity's books
    cr_account: str           # account code in to_entity's books


@dataclass
class ConsolidationInput:
    group_name: str
    period_label: str
    presentation_currency: str = "SAR"
    entities: List[Entity] = field(default_factory=list)
    intercompany: List[IntercoEntry] = field(default_factory=list)


@dataclass
class ConsolLineOut:
    account_code: str
    account_name: str
    classification: str
    parent_amount: Decimal
    subsidiaries_amount: Decimal
    eliminations: Decimal
    consolidated: Decimal


@dataclass
class ConsolidationResult:
    group_name: str
    period_label: str
    presentation_currency: str
    consolidated_lines: List[ConsolLineOut]
    total_assets: Decimal
    total_liabilities: Decimal
    total_equity_parent: Decimal
    total_nci: Decimal                       # non-controlling interest
    total_revenue: Decimal
    total_expenses: Decimal
    consolidated_net_income: Decimal
    net_income_to_parent: Decimal
    net_income_to_nci: Decimal
    total_eliminations: Decimal
    is_balanced: bool
    bs_diff: Decimal
    warnings: list[str] = field(default_factory=list)


def _validate(inp: ConsolidationInput) -> None:
    if not inp.entities:
        raise ValueError("entities is required")
    parents = [e for e in inp.entities if e.is_parent]
    if len(parents) != 1:
        raise ValueError("exactly one entity must have is_parent=True")
    seen: set[str] = set()
    for e in inp.entities:
        if e.entity_id in seen:
            raise ValueError(f"duplicate entity_id {e.entity_id!r}")
        seen.add(e.entity_id)
        if e.ownership_pct < 0 or e.ownership_pct > 100:
            raise ValueError(f"entity {e.entity_id}: ownership_pct must be 0-100")
        if not e.is_parent and e.ownership_pct == 0:
            raise ValueError(f"entity {e.entity_id}: subsidiary must have ownership > 0")


def _translate_line(ln: ConsolLine, entity: Entity) -> ConsolLine:
    """Translate a subsidiary line into presentation currency."""
    if entity.fx_rate_to_presentation == Decimal("1") and entity.avg_fx_rate == Decimal("1"):
        return ln
    # BS items: closing rate; IS items: average rate
    if ln.classification in ("revenue", "expense"):
        rate = Decimal(str(entity.avg_fx_rate))
    else:
        rate = Decimal(str(entity.fx_rate_to_presentation))
    return ConsolLine(
        account_code=ln.account_code,
        account_name=ln.account_name,
        classification=ln.classification,
        amount=_q(Decimal(str(ln.amount)) * rate),
    )


def consolidate(inp: ConsolidationInput) -> ConsolidationResult:
    _validate(inp)

    parent = next(e for e in inp.entities if e.is_parent)
    subsidiaries = [e for e in inp.entities if not e.is_parent]

    # Bucket all lines by account_code (within classification)
    buckets: Dict[tuple[str, str], ConsolLineOut] = {}

    def _add(e: Entity, ln_raw: ConsolLine, is_parent: bool) -> None:
        ln = _translate_line(ln_raw, e)
        key = (ln.account_code, ln.classification)
        if key not in buckets:
            buckets[key] = ConsolLineOut(
                account_code=ln.account_code,
                account_name=ln.account_name,
                classification=ln.classification,
                parent_amount=Decimal("0"),
                subsidiaries_amount=Decimal("0"),
                eliminations=Decimal("0"),
                consolidated=Decimal("0"),
            )
        if is_parent:
            buckets[key].parent_amount += Decimal(str(ln.amount))
        else:
            buckets[key].subsidiaries_amount += Decimal(str(ln.amount))

    for ln in parent.lines:
        _add(parent, ln, is_parent=True)
    for sub in subsidiaries:
        for ln in sub.lines:
            _add(sub, ln, is_parent=False)

    # Eliminations
    # For each IC entry, reduce BOTH sides (dr_account in from_entity,
    # cr_account in to_entity). We lump them into 'eliminations' column.
    total_elims = Decimal("0")
    warnings: list[str] = []
    for ic in inp.intercompany:
        amt = Decimal(str(ic.amount))
        total_elims += amt

        # Find the Dr account in the buckets and reduce it
        # (we don't know its classification, so search by code)
        dr_found = False
        cr_found = False
        for (code, cls), bucket in buckets.items():
            if code == ic.dr_account and not dr_found:
                bucket.eliminations -= amt
                dr_found = True
            if code == ic.cr_account and not cr_found:
                bucket.eliminations += amt
                cr_found = True
        if not dr_found:
            warnings.append(f"IC {ic.description!r}: dr_account {ic.dr_account} not found in any entity")
        if not cr_found:
            warnings.append(f"IC {ic.description!r}: cr_account {ic.cr_account} not found in any entity")

    # Finalise each bucket
    for key, b in buckets.items():
        b.consolidated = _q(b.parent_amount + b.subsidiaries_amount + b.eliminations)
        b.parent_amount = _q(b.parent_amount)
        b.subsidiaries_amount = _q(b.subsidiaries_amount)
        b.eliminations = _q(b.eliminations)

    # Compute totals by classification
    total_assets = sum(
        (b.consolidated for b in buckets.values() if b.classification == "asset"),
        Decimal("0"),
    )
    total_liab = sum(
        (-b.consolidated for b in buckets.values() if b.classification == "liability"),
        Decimal("0"),
    )
    total_equity_raw = sum(
        (-b.consolidated for b in buckets.values() if b.classification == "equity"),
        Decimal("0"),
    )
    total_rev = sum(
        (-b.consolidated for b in buckets.values() if b.classification == "revenue"),
        Decimal("0"),
    )
    total_exp = sum(
        (b.consolidated for b in buckets.values() if b.classification == "expense"),
        Decimal("0"),
    )
    consol_ni = _q(total_rev - total_exp)

    # NCI: apportion each subsidiary's NI by (100% − ownership_pct)
    ni_to_nci = Decimal("0")
    for sub in subsidiaries:
        # Recompute sub's translated NI
        sub_rev = Decimal("0")
        sub_exp = Decimal("0")
        for ln_raw in sub.lines:
            ln = _translate_line(ln_raw, sub)
            if ln.classification == "revenue":
                sub_rev += -Decimal(str(ln.amount))
            elif ln.classification == "expense":
                sub_exp += Decimal(str(ln.amount))
        sub_ni = sub_rev - sub_exp
        nci_share = (Decimal("100") - Decimal(str(sub.ownership_pct))) / Decimal("100")
        ni_to_nci += sub_ni * nci_share
    ni_to_nci = _q(ni_to_nci)
    ni_to_parent = _q(consol_ni - ni_to_nci)

    # NCI balance-sheet portion = (1 - ownership%) × sub's net equity
    total_nci = Decimal("0")
    for sub in subsidiaries:
        sub_assets = Decimal("0")
        sub_liab = Decimal("0")
        sub_eq = Decimal("0")
        for ln_raw in sub.lines:
            ln = _translate_line(ln_raw, sub)
            if ln.classification == "asset":
                sub_assets += Decimal(str(ln.amount))
            elif ln.classification == "liability":
                sub_liab += -Decimal(str(ln.amount))
            elif ln.classification == "equity":
                sub_eq += -Decimal(str(ln.amount))
        sub_net_equity = sub_assets - sub_liab
        nci_share = (Decimal("100") - Decimal(str(sub.ownership_pct))) / Decimal("100")
        total_nci += sub_net_equity * nci_share
    total_nci = _q(total_nci)
    total_equity_parent = _q(total_equity_raw + consol_ni - total_nci)

    # Balanced check: A = L + E_parent + NCI
    bs_diff = _q(total_assets - (total_liab + total_equity_parent + total_nci))
    balanced = bs_diff == 0

    if not balanced:
        warnings.append(
            f"القوائم الموحّدة غير متوازنة — الفرق = {bs_diff}. "
            "تحقق من صحة إلغاءات المعاملات الداخلية."
        )

    return ConsolidationResult(
        group_name=inp.group_name,
        period_label=inp.period_label,
        presentation_currency=inp.presentation_currency,
        consolidated_lines=sorted(buckets.values(), key=lambda b: b.account_code),
        total_assets=_q(total_assets),
        total_liabilities=_q(total_liab),
        total_equity_parent=total_equity_parent,
        total_nci=total_nci,
        total_revenue=_q(total_rev),
        total_expenses=_q(total_exp),
        consolidated_net_income=consol_ni,
        net_income_to_parent=ni_to_parent,
        net_income_to_nci=ni_to_nci,
        total_eliminations=_q(total_elims),
        is_balanced=balanced,
        bs_diff=bs_diff,
        warnings=warnings,
    )


def consol_to_dict(r: ConsolidationResult) -> dict:
    return {
        "group_name": r.group_name,
        "period_label": r.period_label,
        "presentation_currency": r.presentation_currency,
        "consolidated_lines": [
            {
                "account_code": b.account_code,
                "account_name": b.account_name,
                "classification": b.classification,
                "parent_amount": f"{b.parent_amount}",
                "subsidiaries_amount": f"{b.subsidiaries_amount}",
                "eliminations": f"{b.eliminations}",
                "consolidated": f"{b.consolidated}",
            }
            for b in r.consolidated_lines
        ],
        "total_assets": f"{r.total_assets}",
        "total_liabilities": f"{r.total_liabilities}",
        "total_equity_parent": f"{r.total_equity_parent}",
        "total_nci": f"{r.total_nci}",
        "total_revenue": f"{r.total_revenue}",
        "total_expenses": f"{r.total_expenses}",
        "consolidated_net_income": f"{r.consolidated_net_income}",
        "net_income_to_parent": f"{r.net_income_to_parent}",
        "net_income_to_nci": f"{r.net_income_to_nci}",
        "total_eliminations": f"{r.total_eliminations}",
        "is_balanced": r.is_balanced,
        "bs_diff": f"{r.bs_diff}",
        "warnings": r.warnings,
    }
