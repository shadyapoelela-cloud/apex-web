"""Tests for HR: WPS file generator + EOSB calculator."""

from __future__ import annotations

from datetime import date
from decimal import Decimal


# ── WPS KSA ─────────────────────────────────────────────────


def _ksa_company():
    from app.hr.wps_generator import WpsCompany

    return WpsCompany(
        cr_number="1010000000",
        employer_id="EMP-001",
        company_name_en="APEX Test",
        bank_code="080",
        iban="SA0380000000608010167519",
    )


def _ksa_employee(name="Ahmed", basic=Decimal("8000")):
    from app.hr.wps_generator import WpsEmployeeLine

    return WpsEmployeeLine(
        employee_id="1234567890",
        name_en=name,
        bank_code="080",
        iban="SA0380000000608010167519",
        basic_salary=basic,
        housing_allowance=Decimal("2000"),
    )


def test_ksa_sif_produces_header_detail_footer():
    from app.hr.wps_generator import generate_ksa_sif

    result = generate_ksa_sif(
        company=_ksa_company(),
        period="2026-04",
        employees=[_ksa_employee(), _ksa_employee(name="Sara", basic=Decimal("6000"))],
        creation_date=date(2026, 4, 17),
    )
    # H, 2×D, F
    lines = result.text.strip().split("\n")
    assert len(lines) == 4
    assert lines[0].startswith("H|")
    assert lines[1].startswith("D|")
    assert lines[2].startswith("D|")
    assert lines[3].startswith("F|2|")
    assert result.total_records == 2
    # Two employees: 10,000 + 8,000 net (basic+housing, no deductions)
    assert result.total_salary == Decimal("18000.00")


def test_ksa_sif_warns_on_invalid_iban():
    from app.hr.wps_generator import generate_ksa_sif, WpsEmployeeLine

    bad = WpsEmployeeLine(
        employee_id="9",
        name_en="Bad",
        bank_code="080",
        iban="SA1",  # way too short
        basic_salary=Decimal("1000"),
    )
    result = generate_ksa_sif(company=_ksa_company(), period="2026-04", employees=[bad])
    assert any("invalid IBAN" in w for w in result.warnings)


def test_ksa_sif_checksum_is_stable():
    from app.hr.wps_generator import generate_ksa_sif

    r1 = generate_ksa_sif(
        company=_ksa_company(),
        period="2026-04",
        employees=[_ksa_employee()],
        creation_date=date(2026, 4, 17),
    )
    r2 = generate_ksa_sif(
        company=_ksa_company(),
        period="2026-04",
        employees=[_ksa_employee()],
        creation_date=date(2026, 4, 17),
    )
    assert r1.checksum == r2.checksum


# ── UAE SIF ─────────────────────────────────────────────────


def test_uae_sif_generates_csv_like():
    from app.hr.wps_generator import generate_uae_sif, WpsCompany, WpsEmployeeLine

    company = WpsCompany(
        cr_number="EIN-123",
        employer_id="MOL-555",
        company_name_en="APEX UAE",
        bank_code="BYNA",
        iban="AE070331234567890123456",
    )
    emp = WpsEmployeeLine(
        employee_id="784-1990-0000000-1",
        name_en="Mohammed",
        bank_code="BYNA",
        iban="AE070331234567890123456",
        basic_salary=Decimal("12000"),
        housing_allowance=Decimal("3000"),
    )
    result = generate_uae_sif(
        company=company, period="2026-04", employees=[emp], creation_date=date(2026, 4, 17)
    )
    rows = [r for r in result.text.strip().split("\n") if r]
    assert len(rows) == 2
    assert "MOL-555" in rows[0]
    assert rows[0].startswith("MOL-555,")
    assert rows[1].startswith("784-1990-0000000-1,")


# ── EOSB KSA ────────────────────────────────────────────────


def test_ksa_eosb_under_5_years_termination():
    from app.hr.eosb_calculator import calculate_ksa_eosb

    r = calculate_ksa_eosb(
        monthly_wage=Decimal("10000"),
        years_of_service=Decimal("3"),
        resigned=False,
    )
    # 3 yrs × 0.5 × 10,000 = 15,000
    assert r.full_eosb == Decimal("15000.00")
    assert r.payable == Decimal("15000.00")


def test_ksa_eosb_over_5_years_termination():
    from app.hr.eosb_calculator import calculate_ksa_eosb

    r = calculate_ksa_eosb(
        monthly_wage=Decimal("10000"),
        years_of_service=Decimal("8"),
        resigned=False,
    )
    # 5×0.5×10K + 3×1×10K = 25K + 30K = 55K
    assert r.full_eosb == Decimal("55000.00")
    assert r.payable == Decimal("55000.00")


def test_ksa_eosb_resignation_under_2_years():
    from app.hr.eosb_calculator import calculate_ksa_eosb

    r = calculate_ksa_eosb(
        monthly_wage=Decimal("10000"),
        years_of_service=Decimal("1.5"),
        resigned=True,
    )
    assert r.payable == Decimal("0.00")
    assert any("<2 years" in n for n in r.notes)


def test_ksa_eosb_resignation_2_to_5_years():
    from app.hr.eosb_calculator import calculate_ksa_eosb

    r = calculate_ksa_eosb(
        monthly_wage=Decimal("10000"),
        years_of_service=Decimal("4"),
        resigned=True,
    )
    # Full = 4 × 0.5 × 10K = 20K; reduction 1/3 → 6,666.67
    assert r.full_eosb == Decimal("20000.00")
    assert r.payable == Decimal("6666.67")


def test_ksa_eosb_resignation_over_10_years():
    from app.hr.eosb_calculator import calculate_ksa_eosb

    r = calculate_ksa_eosb(
        monthly_wage=Decimal("10000"),
        years_of_service=Decimal("12"),
        resigned=True,
    )
    # Full = 25K + 7×10K = 95K; full reduction = 95K
    assert r.full_eosb == Decimal("95000.00")
    assert r.payable == Decimal("95000.00")


# ── EOSB UAE ────────────────────────────────────────────────


def test_uae_eosb_under_5_years():
    from app.hr.eosb_calculator import calculate_uae_eosb

    r = calculate_uae_eosb(
        basic_monthly_wage=Decimal("10000"),
        years_of_service=Decimal("3"),
    )
    # 3 × 21/30 × 10K = 21,000
    assert r.payable == Decimal("21000.00")


def test_uae_eosb_over_5_years():
    from app.hr.eosb_calculator import calculate_uae_eosb

    r = calculate_uae_eosb(
        basic_monthly_wage=Decimal("10000"),
        years_of_service=Decimal("8"),
    )
    # 5×21/30×10K + 3×1×10K = 35K + 30K = 65K
    assert r.payable == Decimal("65000.00")


def test_uae_eosb_caps_at_2_years_wage():
    from app.hr.eosb_calculator import calculate_uae_eosb

    r = calculate_uae_eosb(
        basic_monthly_wage=Decimal("10000"),
        years_of_service=Decimal("30"),
    )
    # Naive would be 35K + 25×10K = 285K; cap = 24×10K = 240K
    assert r.payable == Decimal("240000.00")
    assert any("capped" in n for n in r.notes)
