"""
APEX Platform — IFRS 15 Revenue Recognition
═══════════════════════════════════════════════════════════════
The 5-step model:
  1. Identify the contract with a customer
  2. Identify the performance obligations in the contract
  3. Determine the transaction price
  4. Allocate the transaction price to the performance obligations
  5. Recognise revenue when (or as) a performance obligation is satisfied

Allocation uses standalone selling prices (SSP) — each obligation
gets its pro-rata share of any discount or variable consideration.

Recognition timing:
  • point_in_time  — entire amount on completion
  • over_time       — straight-line across the service period
                      (percentage-of-completion if progress given)
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


RECOGNITION_PATTERNS = {"point_in_time", "over_time"}


@dataclass
class PerformanceObligation:
    description: str
    standalone_selling_price: Decimal
    recognition_pattern: str = "point_in_time"
    period_months: int = 0              # for over_time
    progress_pct: Optional[Decimal] = None  # 0-100, if explicit progress
    satisfied: bool = False             # for point_in_time


@dataclass
class ContractInput:
    contract_id: str
    customer: str
    contract_date: str
    transaction_price: Decimal           # invoice total (ex-VAT)
    variable_consideration: Decimal = Decimal("0")  # e.g. volume discount
    months_elapsed: int = 0              # as of reporting date
    currency: str = "SAR"
    obligations: List[PerformanceObligation] = field(default_factory=list)


@dataclass
class AllocatedObligation:
    description: str
    ssp: Decimal
    allocated_price: Decimal
    recognition_pattern: str
    period_months: int
    progress_pct: Decimal
    revenue_recognised: Decimal
    revenue_deferred: Decimal
    status: str                          # 'recognised' | 'partial' | 'deferred'
    note: str = ""


@dataclass
class ContractResult:
    contract_id: str
    customer: str
    transaction_price: Decimal
    variable_consideration: Decimal
    net_price: Decimal                   # transaction_price - variable
    total_ssp: Decimal
    obligations: List[AllocatedObligation]
    total_revenue_recognised: Decimal
    total_deferred_revenue: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def _validate(inp: ContractInput) -> None:
    if not inp.obligations:
        raise ValueError("at least one performance obligation is required")
    if Decimal(str(inp.transaction_price)) < 0:
        raise ValueError("transaction_price cannot be negative")
    for i, o in enumerate(inp.obligations, start=1):
        if o.recognition_pattern not in RECOGNITION_PATTERNS:
            raise ValueError(
                f"obligation {i}: recognition_pattern must be one of {sorted(RECOGNITION_PATTERNS)}"
            )
        if Decimal(str(o.standalone_selling_price)) < 0:
            raise ValueError(f"obligation {i}: SSP cannot be negative")
        if o.period_months < 0:
            raise ValueError(f"obligation {i}: period_months cannot be negative")


def recognise_revenue(inp: ContractInput) -> ContractResult:
    _validate(inp)

    warnings: list[str] = []

    net_price = _q(
        Decimal(str(inp.transaction_price)) - Decimal(str(inp.variable_consideration))
    )
    total_ssp = sum(
        (Decimal(str(o.standalone_selling_price)) for o in inp.obligations),
        Decimal("0"),
    )

    if total_ssp == 0:
        raise ValueError("total SSP is zero — cannot allocate")

    allocated: List[AllocatedObligation] = []
    total_recognised = Decimal("0")
    total_deferred = Decimal("0")

    for o in inp.obligations:
        ssp = Decimal(str(o.standalone_selling_price))
        # Allocate pro-rata
        allocation = _q(net_price * ssp / total_ssp)

        # Compute progress
        if o.recognition_pattern == "point_in_time":
            pct = Decimal("100") if o.satisfied else Decimal("0")
        else:  # over_time
            if o.progress_pct is not None:
                pct = Decimal(str(o.progress_pct))
            elif o.period_months > 0:
                pct = min(Decimal("100"),
                    Decimal(inp.months_elapsed) / Decimal(o.period_months) * Decimal("100"))
            else:
                pct = Decimal("0")
                warnings.append(
                    f"{o.description}: over_time obligation with no period_months — using 0%"
                )

        if pct < 0:
            pct = Decimal("0")
        if pct > 100:
            pct = Decimal("100")

        recognised = _q(allocation * pct / Decimal("100"))
        deferred = _q(allocation - recognised)

        status = "recognised" if pct == 100 else ("partial" if pct > 0 else "deferred")
        note = ""
        if o.recognition_pattern == "over_time" and o.progress_pct is None:
            note = f"elapsed {inp.months_elapsed}/{o.period_months} months"
        elif o.recognition_pattern == "over_time" and o.progress_pct is not None:
            note = f"explicit progress {pct}%"

        allocated.append(AllocatedObligation(
            description=o.description,
            ssp=_q(ssp),
            allocated_price=allocation,
            recognition_pattern=o.recognition_pattern,
            period_months=o.period_months,
            progress_pct=_q(pct),
            revenue_recognised=recognised,
            revenue_deferred=deferred,
            status=status,
            note=note,
        ))
        total_recognised += recognised
        total_deferred += deferred

    if Decimal(str(inp.variable_consideration)) != 0:
        warnings.append(
            f"اعتبار متغير مُطبَّق — قيمة {_q(inp.variable_consideration)} "
            "راجع تقديرات خصم الحجم أو المكافآت وفق IFRS 15.50-51."
        )

    return ContractResult(
        contract_id=inp.contract_id,
        customer=inp.customer,
        transaction_price=_q(inp.transaction_price),
        variable_consideration=_q(inp.variable_consideration),
        net_price=net_price,
        total_ssp=_q(total_ssp),
        obligations=allocated,
        total_revenue_recognised=_q(total_recognised),
        total_deferred_revenue=_q(total_deferred),
        currency=inp.currency,
        warnings=warnings,
    )


def to_dict(r: ContractResult) -> dict:
    return {
        "contract_id": r.contract_id,
        "customer": r.customer,
        "transaction_price": f"{r.transaction_price}",
        "variable_consideration": f"{r.variable_consideration}",
        "net_price": f"{r.net_price}",
        "total_ssp": f"{r.total_ssp}",
        "obligations": [
            {
                "description": o.description,
                "ssp": f"{o.ssp}",
                "allocated_price": f"{o.allocated_price}",
                "recognition_pattern": o.recognition_pattern,
                "period_months": o.period_months,
                "progress_pct": f"{o.progress_pct}",
                "revenue_recognised": f"{o.revenue_recognised}",
                "revenue_deferred": f"{o.revenue_deferred}",
                "status": o.status,
                "note": o.note,
            }
            for o in r.obligations
        ],
        "total_revenue_recognised": f"{r.total_revenue_recognised}",
        "total_deferred_revenue": f"{r.total_deferred_revenue}",
        "currency": r.currency,
        "warnings": r.warnings,
    }
