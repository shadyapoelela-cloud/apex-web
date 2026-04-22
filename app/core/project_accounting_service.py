"""
APEX Platform — Project Accounting Service
═══════════════════════════════════════════════════════════════
Full project costing with:
  • WBS (Work Breakdown Structure) tracking
  • Time & expense booking per project/task
  • Budget vs actual per project phase
  • Revenue recognition (IFRS 15 — % completion)
  • Profitability analysis per project
  • Earned Value Management (EVM): CPI, SPI, EAC, ETC
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")


def _q(v) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class ProjectPhase:
    phase_name: str
    budget: Decimal
    actual_cost: Decimal
    earned_value: Decimal    # budgeted cost of work performed
    planned_value: Decimal   # budgeted cost of work scheduled
    hours_budget: Decimal = Decimal("0")
    hours_actual: Decimal = Decimal("0")


@dataclass
class ProjectInput:
    project_name: str
    client_name: str
    contract_value: Decimal
    start_date: str
    end_date: str
    currency: str = "SAR"
    phases: List[ProjectPhase] = field(default_factory=list)


@dataclass
class PhaseResult:
    phase_name: str
    budget: Decimal
    actual_cost: Decimal
    variance: Decimal
    variance_pct: Decimal
    earned_value: Decimal
    planned_value: Decimal
    schedule_variance: Decimal
    cost_variance: Decimal
    cpi: Decimal   # cost performance index
    spi: Decimal   # schedule performance index
    hours_budget: Decimal
    hours_actual: Decimal
    hours_variance: Decimal
    status: str    # under_budget | over_budget | on_track


@dataclass
class ProjectResult:
    project_name: str
    client_name: str
    contract_value: Decimal
    currency: str
    start_date: str
    end_date: str

    total_budget: Decimal
    total_actual: Decimal
    total_variance: Decimal
    total_ev: Decimal
    total_pv: Decimal

    # EVM metrics
    cpi: Decimal            # EV / AC
    spi: Decimal            # EV / PV
    eac: Decimal            # estimate at completion: BAC / CPI
    etc: Decimal            # estimate to complete: EAC - AC
    vac: Decimal            # variance at completion: BAC - EAC

    pct_complete: Decimal
    revenue_to_recognize: Decimal   # IFRS 15 % completion
    gross_margin: Decimal
    gross_margin_pct: Decimal

    phases: List[PhaseResult]
    overall_status: str     # profitable | break_even | loss
    warnings: List[str] = field(default_factory=list)


def analyse_project(inp: ProjectInput) -> ProjectResult:
    if not inp.phases:
        raise ValueError("phases is required")

    warnings: List[str] = []
    phase_results: List[PhaseResult] = []

    total_budget = Decimal("0")
    total_actual = Decimal("0")
    total_ev = Decimal("0")
    total_pv = Decimal("0")

    for p in inp.phases:
        b = Decimal(str(p.budget))
        a = Decimal(str(p.actual_cost))
        ev = Decimal(str(p.earned_value))
        pv = Decimal(str(p.planned_value))
        hb = Decimal(str(p.hours_budget))
        ha = Decimal(str(p.hours_actual))

        var_amt = b - a
        var_pct = _q((var_amt / b * 100) if b != 0 else Decimal("0"))

        sv = ev - pv       # schedule variance
        cv = ev - a         # cost variance

        cpi = _q(ev / a) if a != 0 else Decimal("0")
        spi = _q(ev / pv) if pv != 0 else Decimal("0")

        status = "on_track"
        if a > b * Decimal("1.05"):
            status = "over_budget"
        elif a < b * Decimal("0.90"):
            status = "under_budget"

        phase_results.append(PhaseResult(
            phase_name=p.phase_name,
            budget=_q(b), actual_cost=_q(a),
            variance=_q(var_amt), variance_pct=var_pct,
            earned_value=_q(ev), planned_value=_q(pv),
            schedule_variance=_q(sv), cost_variance=_q(cv),
            cpi=cpi, spi=spi,
            hours_budget=_q(hb), hours_actual=_q(ha),
            hours_variance=_q(hb - ha),
            status=status,
        ))

        total_budget += b
        total_actual += a
        total_ev += ev
        total_pv += pv

    total_var = total_budget - total_actual
    contract = Decimal(str(inp.contract_value))

    # EVM
    g_cpi = _q(total_ev / total_actual) if total_actual != 0 else Decimal("0")
    g_spi = _q(total_ev / total_pv) if total_pv != 0 else Decimal("0")
    eac = _q(total_budget / g_cpi) if g_cpi != 0 else _q(total_budget)
    etc = _q(eac - total_actual)
    vac = _q(total_budget - eac)

    # % complete (EV / BAC)
    pct_complete = _q((total_ev / total_budget * 100) if total_budget != 0 else Decimal("0"))

    # IFRS 15 revenue to recognize
    rev_rec = _q(contract * pct_complete / 100)

    # Margin
    margin = _q(rev_rec - total_actual)
    margin_pct = _q((margin / rev_rec * 100) if rev_rec != 0 else Decimal("0"))

    overall = "profitable"
    if margin < 0:
        overall = "loss"
        warnings.append("المشروع يسجل خسارة — راجع التكاليف والجدول الزمني")
    elif margin == 0:
        overall = "break_even"

    if g_cpi < Decimal("0.9"):
        warnings.append(f"CPI = {g_cpi} (أقل من 0.90) — تجاوز تكاليف جوهري")
    if g_spi < Decimal("0.9"):
        warnings.append(f"SPI = {g_spi} (أقل من 0.90) — تأخر في الجدول الزمني")
    if pct_complete > Decimal("100"):
        warnings.append("نسبة الإنجاز تتجاوز 100% — راجع القيم المكتسبة")

    return ProjectResult(
        project_name=inp.project_name,
        client_name=inp.client_name,
        contract_value=_q(contract),
        currency=inp.currency,
        start_date=inp.start_date,
        end_date=inp.end_date,
        total_budget=_q(total_budget),
        total_actual=_q(total_actual),
        total_variance=_q(total_var),
        total_ev=_q(total_ev),
        total_pv=_q(total_pv),
        cpi=g_cpi, spi=g_spi,
        eac=eac, etc=etc, vac=vac,
        pct_complete=pct_complete,
        revenue_to_recognize=rev_rec,
        gross_margin=margin,
        gross_margin_pct=margin_pct,
        phases=phase_results,
        overall_status=overall,
        warnings=warnings,
    )


def to_dict(r: ProjectResult) -> dict:
    return {
        "project_name": r.project_name,
        "client_name": r.client_name,
        "contract_value": f"{r.contract_value}",
        "currency": r.currency,
        "start_date": r.start_date,
        "end_date": r.end_date,
        "total_budget": f"{r.total_budget}",
        "total_actual": f"{r.total_actual}",
        "total_variance": f"{r.total_variance}",
        "evm": {
            "earned_value": f"{r.total_ev}",
            "planned_value": f"{r.total_pv}",
            "cpi": f"{r.cpi}", "spi": f"{r.spi}",
            "eac": f"{r.eac}", "etc": f"{r.etc}", "vac": f"{r.vac}",
        },
        "pct_complete": f"{r.pct_complete}",
        "revenue_to_recognize": f"{r.revenue_to_recognize}",
        "gross_margin": f"{r.gross_margin}",
        "gross_margin_pct": f"{r.gross_margin_pct}",
        "overall_status": r.overall_status,
        "phases": [
            {
                "name": p.phase_name,
                "budget": f"{p.budget}", "actual": f"{p.actual_cost}",
                "variance": f"{p.variance}", "variance_pct": f"{p.variance_pct}",
                "ev": f"{p.earned_value}", "pv": f"{p.planned_value}",
                "sv": f"{p.schedule_variance}", "cv": f"{p.cost_variance}",
                "cpi": f"{p.cpi}", "spi": f"{p.spi}",
                "hours_budget": f"{p.hours_budget}",
                "hours_actual": f"{p.hours_actual}",
                "hours_variance": f"{p.hours_variance}",
                "status": p.status,
            }
            for p in r.phases
        ],
        "warnings": r.warnings,
    }
