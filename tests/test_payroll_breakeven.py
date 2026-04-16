"""Payroll (GOSI) + Break-even tests."""

from decimal import Decimal

import pytest

from app.core.payroll_service import PayrollInput, compute_payroll
from app.core.breakeven_service import BreakevenInput, compute_breakeven


# ══════════════════════════════════════════════════════════════
# Payroll — Saudi nationals
# ══════════════════════════════════════════════════════════════


class TestPayrollSaudi:
    def test_simple_saudi_payroll(self):
        r = compute_payroll(PayrollInput(
            nationality="SA",
            basic_salary=Decimal("10000"),
            housing_allowance=Decimal("2500"),
            transport_allowance=Decimal("500"),
        ))
        # Gross = 13000
        assert r.gross_earnings == Decimal("13000.00")
        # GOSI base = basic + housing = 12500
        assert r.gosi_base == Decimal("12500.00")
        # Employee 10% = 1250
        assert r.gosi_employee_share == Decimal("1250.00")
        # Employer 12% = 1500
        assert r.gosi_employer_share == Decimal("1500.00")
        # Net = 13000 - 1250 = 11750
        assert r.net_pay == Decimal("11750.00")
        # Cost to employer = 13000 + 1500 = 14500
        assert r.total_cost_to_employer == Decimal("14500.00")

    def test_gosi_base_capped(self):
        r = compute_payroll(PayrollInput(
            nationality="SA",
            basic_salary=Decimal("50000"),   # exceeds cap 45k
            housing_allowance=Decimal("10000"),
        ))
        # base capped at 45000 (default), GOSI 10% = 4500
        assert r.gosi_base == Decimal("45000.00")
        assert r.gosi_employee_share == Decimal("4500.00")
        assert any("سقف" in w for w in r.warnings)

    def test_deductions_subtract_from_net(self):
        r = compute_payroll(PayrollInput(
            nationality="SA",
            basic_salary=Decimal("10000"),
            housing_allowance=Decimal("2500"),
            absence_deduction=Decimal("500"),
            loan_deduction=Decimal("300"),
        ))
        # GOSI 1250 + 500 + 300 = 2050 total ded
        assert r.total_deductions == Decimal("2050.00")
        assert r.net_pay == Decimal("10450.00")

    def test_minimum_wage_warning(self):
        r = compute_payroll(PayrollInput(
            nationality="SA",
            basic_salary=Decimal("3500"),   # below SAR 4000
        ))
        assert any("السعودة" in w for w in r.warnings)


# ══════════════════════════════════════════════════════════════
# Payroll — Expatriates
# ══════════════════════════════════════════════════════════════


class TestPayrollExpat:
    def test_expat_no_employee_gosi(self):
        r = compute_payroll(PayrollInput(
            nationality="EG",
            basic_salary=Decimal("10000"),
            housing_allowance=Decimal("2500"),
        ))
        # Expat: employee share = 0, employer 2%
        assert r.gosi_employee_share == Decimal("0.00")
        # Employer 2% * 12500 = 250
        assert r.gosi_employer_share == Decimal("250.00")
        assert r.net_pay == Decimal("12500.00")

    def test_income_tax_for_non_ksa(self):
        r = compute_payroll(PayrollInput(
            nationality="EG",
            basic_salary=Decimal("10000"),
            income_tax_rate=Decimal("0.15"),  # hypothetical 15%
        ))
        # No GOSI employee; taxable = 10000; tax = 1500
        assert r.income_tax == Decimal("1500.00")
        assert r.net_pay == Decimal("8500.00")


# ══════════════════════════════════════════════════════════════
# Payroll — Validation
# ══════════════════════════════════════════════════════════════


class TestPayrollValidation:
    def test_negative_salary_rejected(self):
        with pytest.raises(ValueError):
            compute_payroll(PayrollInput(basic_salary=Decimal("-100")))

    def test_bad_tax_rate_rejected(self):
        with pytest.raises(ValueError):
            compute_payroll(PayrollInput(
                basic_salary=Decimal("100"), income_tax_rate=Decimal("1.5"),
            ))

    def test_bad_gosi_rate_rejected(self):
        with pytest.raises(ValueError):
            compute_payroll(PayrollInput(
                basic_salary=Decimal("100"),
                gosi_employee_rate=Decimal("1.5"),
            ))


# ══════════════════════════════════════════════════════════════
# Break-even
# ══════════════════════════════════════════════════════════════


class TestBreakeven:
    def test_simple_breakeven(self):
        r = compute_breakeven(BreakevenInput(
            fixed_costs=Decimal("100000"),
            unit_price=Decimal("100"),
            variable_cost_per_unit=Decimal("60"),
        ))
        # CM = 40, CM ratio = 40%
        assert r.contribution_margin_per_unit == Decimal("40.00")
        assert r.contribution_margin_ratio_pct == Decimal("40.00")
        # BE units = 100000 / 40 = 2500
        assert r.break_even_units == 2500
        # BE revenue = 2500 * 100 = 250,000
        assert r.break_even_revenue == Decimal("250000.00")

    def test_target_profit(self):
        r = compute_breakeven(BreakevenInput(
            fixed_costs=Decimal("100000"),
            unit_price=Decimal("100"),
            variable_cost_per_unit=Decimal("60"),
            target_profit=Decimal("40000"),
        ))
        # Target units = (100k + 40k) / 40 = 3500
        assert r.target_units == 3500
        assert r.target_revenue == Decimal("350000.00")

    def test_margin_of_safety(self):
        r = compute_breakeven(BreakevenInput(
            fixed_costs=Decimal("100000"),
            unit_price=Decimal("100"),
            variable_cost_per_unit=Decimal("60"),
            actual_units_sold=Decimal("3000"),
        ))
        # BE 2500, actual 3000 → MoS = 500 units
        assert r.margin_of_safety_units == 500
        # MoS % = 500 / 3000 = 16.67%
        assert r.margin_of_safety_pct == Decimal("16.67")

    def test_negative_contribution_margin_warning(self):
        r = compute_breakeven(BreakevenInput(
            fixed_costs=Decimal("100000"),
            unit_price=Decimal("100"),
            variable_cost_per_unit=Decimal("120"),   # variable > price
        ))
        # CM = -20, no break-even
        assert r.break_even_units is None
        assert any("الهامش سالب" in w for w in r.warnings)

    def test_rounds_up_to_whole_units(self):
        r = compute_breakeven(BreakevenInput(
            fixed_costs=Decimal("1000"),
            unit_price=Decimal("30"),
            variable_cost_per_unit=Decimal("10"),
        ))
        # 1000 / 20 = 50 → exactly 50 units
        assert r.break_even_units == 50

    def test_fractional_rounded_up(self):
        r = compute_breakeven(BreakevenInput(
            fixed_costs=Decimal("1001"),
            unit_price=Decimal("30"),
            variable_cost_per_unit=Decimal("10"),
        ))
        # 1001 / 20 = 50.05 → 51
        assert r.break_even_units == 51

    def test_negative_fixed_costs_rejected(self):
        with pytest.raises(ValueError):
            compute_breakeven(BreakevenInput(fixed_costs=Decimal("-1")))


# ══════════════════════════════════════════════════════════════
# HTTP
# ══════════════════════════════════════════════════════════════


class TestRoutes:
    def test_payroll_requires_auth(self, client):
        r = client.post("/payroll/compute", json={})
        assert r.status_code == 401

    def test_payroll_http_saudi(self, client, auth_header):
        r = client.post(
            "/payroll/compute",
            json={
                "employee_name": "محمد",
                "nationality": "SA",
                "basic_salary": "10000",
                "housing_allowance": "2500",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["net_pay"] == "11250.00"
        assert d["total_cost_to_employer"] == "14000.00"
        assert d["gosi"]["employee_rate_pct"] == "10.00"

    def test_payroll_http_expat(self, client, auth_header):
        r = client.post(
            "/payroll/compute",
            json={
                "nationality": "IN",
                "basic_salary": "8000",
                "housing_allowance": "2000",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["gosi"]["employee_rate_pct"] == "0.00"
        assert d["gosi"]["employer_rate_pct"] == "2.00"
        # 10000 * 2% = 200 employer; net = 10000 (no employee GOSI, no tax)
        assert d["net_pay"] == "10000.00"
        assert d["total_cost_to_employer"] == "10200.00"

    def test_breakeven_requires_auth(self, client):
        r = client.post("/breakeven/compute", json={})
        assert r.status_code == 401

    def test_breakeven_http(self, client, auth_header):
        r = client.post(
            "/breakeven/compute",
            json={
                "fixed_costs": "50000",
                "unit_price": "100",
                "variable_cost_per_unit": "60",
                "target_profit": "20000",
                "actual_units_sold": "2000",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        # CM=40, BE units = 50000/40 = 1250
        assert d["break_even_units"] == 1250
        # Target units = 70000/40 = 1750
        assert d["target_units"] == 1750
        # MoS = 2000 - 1250 = 750
        assert d["margin_of_safety_units"] == 750
