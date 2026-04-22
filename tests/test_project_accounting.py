"""Tests for Project Accounting service."""

import pytest
from decimal import Decimal
from app.core.project_accounting_service import (
    ProjectPhase, ProjectInput, analyse_project, to_dict, _q,
)


def _phase(name="Phase 1", budget=100000, actual=90000, ev=85000, pv=90000,
           hrs_b=500, hrs_a=480):
    return ProjectPhase(
        phase_name=name,
        budget=Decimal(str(budget)), actual_cost=Decimal(str(actual)),
        earned_value=Decimal(str(ev)), planned_value=Decimal(str(pv)),
        hours_budget=Decimal(str(hrs_b)), hours_actual=Decimal(str(hrs_a)),
    )


def _proj(phases, contract=500000, name="مشروع ERP"):
    return ProjectInput(
        project_name=name, client_name="عميل اختبار",
        contract_value=Decimal(str(contract)),
        start_date="2026-01-01", end_date="2026-12-31",
        phases=phases,
    )


class TestBasicProject:
    def test_single_phase_profitable(self):
        r = analyse_project(_proj([_phase()]))
        assert r.overall_status == "profitable"
        assert r.total_budget == Decimal("100000.00")
        assert r.total_actual == Decimal("90000.00")
        assert r.total_variance == Decimal("10000.00")

    def test_pct_complete(self):
        r = analyse_project(_proj([_phase(budget=100000, ev=85000)]))
        assert r.pct_complete == Decimal("85.00")

    def test_revenue_recognition(self):
        r = analyse_project(_proj([_phase(budget=100000, ev=85000)], contract=500000))
        assert r.revenue_to_recognize == Decimal("425000.00")  # 500K * 85%

    def test_multi_phase(self):
        phases = [
            _phase("التصميم", 200000, 190000, 180000, 200000),
            _phase("التطوير", 300000, 280000, 260000, 290000),
            _phase("الاختبار", 100000, 50000, 40000, 80000),
        ]
        r = analyse_project(_proj(phases, contract=1000000))
        assert r.total_budget == Decimal("600000.00")
        assert len(r.phases) == 3


class TestEVM:
    def test_cpi_above_one(self):
        # EV=100K, AC=90K → CPI=1.11
        r = analyse_project(_proj([_phase(budget=100000, actual=90000, ev=100000, pv=100000)]))
        assert r.cpi == Decimal("1.11")

    def test_cpi_below_one(self):
        # EV=80K, AC=100K → CPI=0.80
        r = analyse_project(_proj([_phase(budget=100000, actual=100000, ev=80000, pv=100000)]))
        assert r.cpi == Decimal("0.80")
        assert len(r.warnings) >= 1  # CPI warning

    def test_spi_below_one(self):
        # EV=70K, PV=100K → SPI=0.70
        r = analyse_project(_proj([_phase(budget=100000, actual=80000, ev=70000, pv=100000)]))
        assert r.spi == Decimal("0.70")
        assert any("SPI" in w for w in r.warnings)

    def test_eac_calculation(self):
        # BAC=100K, CPI=0.80 → EAC=125K
        r = analyse_project(_proj([_phase(budget=100000, actual=100000, ev=80000, pv=100000)]))
        assert r.eac == Decimal("125000.00")  # 100K / 0.80
        assert r.etc == Decimal("25000.00")   # EAC - AC
        assert r.vac == Decimal("-25000.00")  # BAC - EAC


class TestMargin:
    def test_profitable(self):
        r = analyse_project(_proj([_phase(budget=100000, actual=50000, ev=100000)], contract=200000))
        assert r.gross_margin > 0
        assert r.overall_status == "profitable"

    def test_loss(self):
        # 100% complete, actual > revenue
        r = analyse_project(_proj(
            [_phase(budget=100000, actual=250000, ev=100000, pv=100000)],
            contract=200000,
        ))
        # Rev rec = 200K * 100% = 200K, actual = 250K → loss
        assert r.overall_status == "loss"
        assert r.gross_margin < 0

    def test_break_even(self):
        r = analyse_project(_proj(
            [_phase(budget=100000, actual=200000, ev=100000, pv=100000)],
            contract=200000,
        ))
        # Rev rec = 200K * 100% = 200K, actual = 200K → break even
        assert r.overall_status == "break_even"
        assert r.gross_margin == Decimal("0.00")


class TestPhaseStatus:
    def test_over_budget_phase(self):
        r = analyse_project(_proj([_phase(budget=100000, actual=110000, ev=90000, pv=100000)]))
        assert r.phases[0].status == "over_budget"

    def test_under_budget_phase(self):
        r = analyse_project(_proj([_phase(budget=100000, actual=80000, ev=80000, pv=90000)]))
        assert r.phases[0].status == "under_budget"

    def test_on_track_phase(self):
        r = analyse_project(_proj([_phase(budget=100000, actual=97000, ev=95000, pv=100000)]))
        assert r.phases[0].status == "on_track"


class TestValidation:
    def test_empty_phases_raises(self):
        with pytest.raises(ValueError, match="phases"):
            analyse_project(_proj([]))


class TestToDict:
    def test_dict_structure(self):
        r = analyse_project(_proj([_phase()]))
        d = to_dict(r)
        assert "project_name" in d
        assert "evm" in d
        assert "cpi" in d["evm"]
        assert "phases" in d
        assert len(d["phases"]) == 1
        assert "pct_complete" in d
        assert "revenue_to_recognize" in d
        assert "gross_margin" in d
