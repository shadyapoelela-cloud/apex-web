"""
APEX Platform — Full Cash Flow Statement (IAS 7)
═══════════════════════════════════════════════════════════════
Produces a complete CFS from two comparative trial balances
(opening + closing) plus Net Income:

  • Operating activities (indirect method, default)
    Net Income
    + Non-cash charges (depreciation, amortisation)
    ± Working-capital changes (AR, Inventory, AP, accruals)
    = Cash from Operating

  • Investing activities
    − Additions to PP&E (increase in gross)
    + Proceeds from disposals
    ± Other investment in intangibles / LT assets

  • Financing activities
    ± Change in LT debt
    ± Share issues / buybacks
    − Dividends paid

  • Reconciliation
    Opening cash + net change = Closing cash

Each account line carries a classification:
  op_addback    — non-cash expense (depreciation, amort)
  op_wc         — working-capital item (AR, INV, AP, …)
  investing     — PP&E / intangibles / investments
  financing     — debt / equity / dividends
  cash          — actual cash & equivalents
  (other / ignored: revenue, expense — feed NI directly)

Sign rule for working-capital: an increase in an asset consumes
cash (negative); an increase in a liability generates cash (positive).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


CFS_CLASSES = {
    "cash", "op_addback", "op_wc_asset", "op_wc_liability",
    "investing", "financing",
}


@dataclass
class CFSLine:
    account_code: str
    account_name: str
    cfs_class: str                 # one of CFS_CLASSES
    opening_balance: Decimal       # balance at start of period
    closing_balance: Decimal       # balance at end of period
    # optional: flow (override the balance-delta derivation if
    # caller has an explicit cash-flow figure, e.g. dividends paid)
    explicit_flow: Optional[Decimal] = None


@dataclass
class CFSInput:
    entity_name: str
    period_label: str
    currency: str = "SAR"
    net_income: Decimal = Decimal("0")
    lines: List[CFSLine] = field(default_factory=list)


@dataclass
class CFSSectionLine:
    account_code: str
    account_name: str
    amount: Decimal
    note: str = ""


@dataclass
class CashFlowStatementResult:
    entity_name: str
    period_label: str
    currency: str
    net_income: Decimal
    operating_lines: List[CFSSectionLine]
    investing_lines: List[CFSSectionLine]
    financing_lines: List[CFSSectionLine]
    cash_from_operating: Decimal
    cash_from_investing: Decimal
    cash_from_financing: Decimal
    net_change_in_cash: Decimal         # sum of the three
    opening_cash: Decimal
    closing_cash: Decimal
    cash_check: Decimal                 # closing − (opening + net_change); should be 0
    reconciles: bool
    warnings: list[str] = field(default_factory=list)


def _validate(inp: CFSInput) -> None:
    if not inp.lines:
        raise ValueError("lines is required")
    if len(inp.lines) > 10000:
        raise ValueError("too many lines (max 10000)")
    seen: set[str] = set()
    for i, ln in enumerate(inp.lines, start=1):
        if not ln.account_code:
            raise ValueError(f"line {i}: account_code is required")
        if not ln.account_name:
            raise ValueError(f"line {i}: account_name is required")
        if ln.cfs_class not in CFS_CLASSES:
            raise ValueError(
                f"line {i}: cfs_class {ln.cfs_class!r} is invalid; "
                f"must be one of {sorted(CFS_CLASSES)}"
            )
        if ln.account_code in seen:
            raise ValueError(f"line {i}: duplicate account_code {ln.account_code!r}")
        seen.add(ln.account_code)


def build_cash_flow_statement(inp: CFSInput) -> CashFlowStatementResult:
    _validate(inp)

    operating: List[CFSSectionLine] = []
    investing: List[CFSSectionLine] = []
    financing: List[CFSSectionLine] = []
    opening_cash = Decimal("0")
    closing_cash = Decimal("0")

    ni = _q(inp.net_income)
    # Start operating section with NI
    operating.append(CFSSectionLine(
        account_code="NI", account_name="صافي الدخل",
        amount=ni, note="starting point",
    ))

    for ln in inp.lines:
        opening = Decimal(str(ln.opening_balance))
        closing = Decimal(str(ln.closing_balance))
        delta = closing - opening
        flow = Decimal(str(ln.explicit_flow)) if ln.explicit_flow is not None else delta

        if ln.cfs_class == "cash":
            opening_cash += opening
            closing_cash += closing
            continue

        if ln.cfs_class == "op_addback":
            # Non-cash expense like depreciation: add to NI
            # The closing balance - opening balance of accum. depreciation
            # is the depreciation expense for the period.
            operating.append(CFSSectionLine(
                account_code=ln.account_code,
                account_name=ln.account_name,
                amount=_q(delta),
                note="add-back (non-cash)",
            ))
            continue

        if ln.cfs_class == "op_wc_asset":
            # Increase in operating asset consumes cash (negative flow)
            operating.append(CFSSectionLine(
                account_code=ln.account_code,
                account_name=ln.account_name,
                amount=_q(-delta),
                note="working-capital change (asset)",
            ))
            continue

        if ln.cfs_class == "op_wc_liability":
            # Increase in operating liability generates cash (positive flow)
            operating.append(CFSSectionLine(
                account_code=ln.account_code,
                account_name=ln.account_name,
                amount=_q(delta),
                note="working-capital change (liability)",
            ))
            continue

        if ln.cfs_class == "investing":
            # For PP&E, an increase in gross is a purchase (cash out).
            # Use explicit_flow if caller passed it; else assume delta
            # represents the net change and sign it as outflow for asset
            # increase. (Convention: report the actual cash direction.)
            amt = flow if ln.explicit_flow is not None else _q(-delta)
            investing.append(CFSSectionLine(
                account_code=ln.account_code,
                account_name=ln.account_name,
                amount=_q(amt),
                note="investing activity",
            ))
            continue

        if ln.cfs_class == "financing":
            # For liabilities/equity, an increase generates cash (+delta).
            # For dividends, caller should use explicit_flow (negative).
            amt = flow if ln.explicit_flow is not None else _q(delta)
            financing.append(CFSSectionLine(
                account_code=ln.account_code,
                account_name=ln.account_name,
                amount=_q(amt),
                note="financing activity",
            ))
            continue

    cfo = sum((l.amount for l in operating), Decimal("0"))
    cfi = sum((l.amount for l in investing), Decimal("0"))
    cff = sum((l.amount for l in financing), Decimal("0"))
    net_change = _q(cfo + cfi + cff)

    expected_closing = _q(opening_cash + net_change)
    diff = _q(closing_cash - expected_closing)
    reconciles = diff == 0

    warnings: list[str] = []
    if not reconciles:
        warnings.append(
            f"التدفق النقدي لا يُطابق التغيّر الفعلي في النقد — "
            f"الفرق = {diff}. راجع تصنيفات البنود."
        )

    return CashFlowStatementResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        currency=inp.currency,
        net_income=ni,
        operating_lines=operating,
        investing_lines=investing,
        financing_lines=financing,
        cash_from_operating=_q(cfo),
        cash_from_investing=_q(cfi),
        cash_from_financing=_q(cff),
        net_change_in_cash=net_change,
        opening_cash=_q(opening_cash),
        closing_cash=_q(closing_cash),
        cash_check=diff,
        reconciles=reconciles,
        warnings=warnings,
    )


def cfs_to_dict(r: CashFlowStatementResult) -> dict:
    def _ln(l: CFSSectionLine) -> dict:
        return {
            "account_code": l.account_code,
            "account_name": l.account_name,
            "amount": f"{l.amount}",
            "note": l.note,
        }
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "currency": r.currency,
        "net_income": f"{r.net_income}",
        "operating_lines": [_ln(l) for l in r.operating_lines],
        "investing_lines": [_ln(l) for l in r.investing_lines],
        "financing_lines": [_ln(l) for l in r.financing_lines],
        "cash_from_operating": f"{r.cash_from_operating}",
        "cash_from_investing": f"{r.cash_from_investing}",
        "cash_from_financing": f"{r.cash_from_financing}",
        "net_change_in_cash": f"{r.net_change_in_cash}",
        "opening_cash": f"{r.opening_cash}",
        "closing_cash": f"{r.closing_cash}",
        "cash_check": f"{r.cash_check}",
        "reconciles": r.reconciles,
        "warnings": r.warnings,
    }
