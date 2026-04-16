"""
APEX Platform — Payroll Calculator (KSA + GCC)
═══════════════════════════════════════════════════════════════
Computes monthly payroll per employee with full GOSI split, housing
allowance, transport, overtime, leaves, and net-pay breakdown.

Saudi payroll baseline (rates as of 2026):

  GOSI (Saudi nationals):
    - Employee deduction:  10%  of (basic + housing cap)
    - Employer share:      12%  (9% OAI + 2% SANID + 1% occupational)
      Note: SANID (unemployment insurance) applies to Saudis only.
    - Contribution base cap: SAR 45,000/month (ZATCA updates this
      periodically — exposed as a parameter).

  GOSI (expatriates):
    - Employee deduction:  0%
    - Employer share:      2%  (occupational hazard only)

  Income Tax: KSA does not impose personal income tax on salaries
  (zero rate). This module exposes `income_tax_rate` as a parameter
  so callers in UAE / Egypt / other jurisdictions can supply one.

  Minimum wage for Saudis (Saudization calculation):
  SAR 4,000/month as of 2024 policy — informational warning only,
  not enforced in the math.

All math is Decimal. Negative salaries / allowances are rejected.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")


def _q(value: Optional[Decimal | int | float | str]) -> Decimal:
    if value is None:
        return Decimal("0")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class PayrollInput:
    # Identity
    employee_name: str = ""
    nationality: str = "SA"                # SA = Saudi, other = expat
    period_label: str = ""                 # e.g. "2026-01"

    # Earnings
    basic_salary: Decimal = Decimal("0")
    housing_allowance: Decimal = Decimal("0")
    transport_allowance: Decimal = Decimal("0")
    other_allowances: Decimal = Decimal("0")
    overtime: Decimal = Decimal("0")
    bonus: Decimal = Decimal("0")

    # Deductions (before GOSI)
    absence_deduction: Decimal = Decimal("0")
    loan_deduction: Decimal = Decimal("0")
    other_deductions: Decimal = Decimal("0")

    # GOSI config (KSA defaults)
    gosi_base_cap: Decimal = Decimal("45000")
    gosi_employee_rate: Optional[Decimal] = None    # defaults by nationality
    gosi_employer_rate: Optional[Decimal] = None

    # Optional income tax (non-KSA jurisdictions)
    income_tax_rate: Decimal = Decimal("0")          # e.g. 0.05 for 5%

    # Currency (informational)
    currency: str = "SAR"


# ═══════════════════════════════════════════════════════════════
# Result
# ═══════════════════════════════════════════════════════════════


@dataclass
class PayrollLine:
    kind: str               # 'earning' | 'deduction'
    label_ar: str
    label_en: str
    amount: Decimal


@dataclass
class PayrollResult:
    employee_name: str
    nationality: str
    period_label: str
    currency: str

    # Earnings
    gross_earnings: Decimal
    earning_lines: list[PayrollLine]

    # GOSI
    gosi_base: Decimal                   # capped base used for calc
    gosi_employee_rate_pct: Decimal       # informational, e.g. 10.00
    gosi_employer_rate_pct: Decimal       # e.g. 12.00
    gosi_employee_share: Decimal          # from employee's net
    gosi_employer_share: Decimal          # employer's cost, NOT deducted
    gosi_total_cost_to_employer: Decimal  # gross + employer GOSI share

    # Tax
    income_tax_rate_pct: Decimal
    income_tax: Decimal

    # Deductions
    total_deductions: Decimal             # absence + loan + other + GOSI emp + tax
    deduction_lines: list[PayrollLine]

    # Bottom line
    net_pay: Decimal
    total_cost_to_employer: Decimal

    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Calculation
# ═══════════════════════════════════════════════════════════════


def compute_payroll(inp: PayrollInput) -> PayrollResult:
    warnings: list[str] = []

    # Validation
    for name, v in [
        ("basic_salary", inp.basic_salary),
        ("housing_allowance", inp.housing_allowance),
        ("transport_allowance", inp.transport_allowance),
        ("other_allowances", inp.other_allowances),
        ("overtime", inp.overtime),
        ("bonus", inp.bonus),
    ]:
        if v < 0:
            raise ValueError(f"{name} cannot be negative")
    for name, v in [
        ("absence_deduction", inp.absence_deduction),
        ("loan_deduction", inp.loan_deduction),
        ("other_deductions", inp.other_deductions),
    ]:
        if v < 0:
            raise ValueError(f"{name} cannot be negative")
    if inp.income_tax_rate < 0 or inp.income_tax_rate >= 1:
        raise ValueError("income_tax_rate must be in [0, 1)")

    basic = _q(inp.basic_salary)
    housing = _q(inp.housing_allowance)
    transport = _q(inp.transport_allowance)
    other_earn = _q(inp.other_allowances)
    overtime = _q(inp.overtime)
    bonus = _q(inp.bonus)

    earning_lines = [
        PayrollLine("earning", "الراتب الأساسي",       "Basic salary",        basic),
        PayrollLine("earning", "بدل السكن",            "Housing allowance",   housing),
        PayrollLine("earning", "بدل النقل",            "Transport allowance", transport),
        PayrollLine("earning", "بدلات أخرى",           "Other allowances",    other_earn),
        PayrollLine("earning", "الساعات الإضافية",     "Overtime",            overtime),
        PayrollLine("earning", "مكافآت",               "Bonus",               bonus),
    ]
    gross = _q(basic + housing + transport + other_earn + overtime + bonus)

    # ── GOSI ────────────────────────────────────────────────────
    is_saudi = (inp.nationality or "").upper() == "SA"
    # Default rates (KSA 2026)
    default_employee_rate = Decimal("0.10") if is_saudi else Decimal("0")
    default_employer_rate = Decimal("0.12") if is_saudi else Decimal("0.02")
    emp_rate = inp.gosi_employee_rate if inp.gosi_employee_rate is not None else default_employee_rate
    er_rate = inp.gosi_employer_rate if inp.gosi_employer_rate is not None else default_employer_rate

    if emp_rate < 0 or emp_rate >= 1 or er_rate < 0 or er_rate >= 1:
        raise ValueError("GOSI rates must be in [0, 1)")

    # GOSI base = basic + housing, capped
    raw_base = basic + housing
    cap = _q(inp.gosi_base_cap)
    if cap > 0 and raw_base > cap:
        gosi_base = cap
        warnings.append(
            f"تم تطبيق سقف اشتراك التأمينات ({cap} SAR) — "
            f"القاعدة غير المحدودة كانت {raw_base} SAR."
        )
    else:
        gosi_base = _q(raw_base)

    gosi_emp_share = _q(gosi_base * emp_rate)
    gosi_er_share = _q(gosi_base * er_rate)

    # ── Income Tax (non-KSA) ───────────────────────────────────
    tax_rate = inp.income_tax_rate
    # Tax applies on gross earnings less GOSI employee share (common
    # structure — callers can override via the rate if their regime
    # differs).
    taxable = _q(gross - gosi_emp_share)
    if taxable < 0:
        taxable = Decimal("0")
    income_tax = _q(taxable * tax_rate)

    # ── Deductions ─────────────────────────────────────────────
    absence = _q(inp.absence_deduction)
    loan = _q(inp.loan_deduction)
    other_ded = _q(inp.other_deductions)

    deduction_lines = [
        PayrollLine("deduction", "الغياب",                 "Absence",                absence),
        PayrollLine("deduction", "خصم السلفة",             "Loan repayment",         loan),
        PayrollLine("deduction", "خصومات أخرى",            "Other deductions",       other_ded),
        PayrollLine(
            "deduction",
            "حصة الموظف من التأمينات",
            "GOSI (employee share)",
            gosi_emp_share,
        ),
    ]
    if income_tax > 0:
        deduction_lines.append(
            PayrollLine("deduction", "ضريبة الدخل", "Income tax", income_tax)
        )

    total_deductions = _q(
        absence + loan + other_ded + gosi_emp_share + income_tax
    )

    # ── Bottom line ────────────────────────────────────────────
    net_pay = _q(gross - total_deductions)
    total_cost_to_employer = _q(gross + gosi_er_share)

    # Sanity warnings
    if is_saudi and basic > 0 and basic < Decimal("4000"):
        warnings.append(
            "الراتب الأساسي للموظف السعودي أقل من 4,000 SAR — "
            "قد لا يُحتسب ضمن نسبة السعودة."
        )
    if net_pay < 0:
        warnings.append(
            "صافي الراتب سالب — الخصومات أعلى من الاستحقاقات. راجع المدخلات."
        )
    if housing > basic * Decimal("0.25") and basic > 0:
        # Informational: housing allowance by Labor Law is typically 25% of basic
        if housing > basic * Decimal("0.30"):
            warnings.append(
                "بدل السكن يتجاوز 30% من الراتب الأساسي — تأكد من المطابقة لعقد العمل."
            )

    return PayrollResult(
        employee_name=inp.employee_name,
        nationality=inp.nationality,
        period_label=inp.period_label,
        currency=inp.currency,
        gross_earnings=gross,
        earning_lines=earning_lines,
        gosi_base=gosi_base,
        gosi_employee_rate_pct=_q(emp_rate * Decimal("100")),
        gosi_employer_rate_pct=_q(er_rate * Decimal("100")),
        gosi_employee_share=gosi_emp_share,
        gosi_employer_share=gosi_er_share,
        gosi_total_cost_to_employer=_q(gosi_er_share),
        income_tax_rate_pct=_q(tax_rate * Decimal("100")),
        income_tax=income_tax,
        total_deductions=total_deductions,
        deduction_lines=deduction_lines,
        net_pay=net_pay,
        total_cost_to_employer=total_cost_to_employer,
        warnings=warnings,
    )


def result_to_dict(r: PayrollResult) -> dict:
    return {
        "employee_name": r.employee_name,
        "nationality": r.nationality,
        "period_label": r.period_label,
        "currency": r.currency,
        "gross_earnings": f"{r.gross_earnings}",
        "earning_lines": [
            {
                "kind": ln.kind,
                "label_ar": ln.label_ar,
                "label_en": ln.label_en,
                "amount": f"{ln.amount}",
            }
            for ln in r.earning_lines
        ],
        "gosi": {
            "base": f"{r.gosi_base}",
            "employee_rate_pct": f"{r.gosi_employee_rate_pct}",
            "employer_rate_pct": f"{r.gosi_employer_rate_pct}",
            "employee_share": f"{r.gosi_employee_share}",
            "employer_share": f"{r.gosi_employer_share}",
        },
        "income_tax": {
            "rate_pct": f"{r.income_tax_rate_pct}",
            "amount": f"{r.income_tax}",
        },
        "total_deductions": f"{r.total_deductions}",
        "deduction_lines": [
            {
                "kind": ln.kind,
                "label_ar": ln.label_ar,
                "label_en": ln.label_en,
                "amount": f"{ln.amount}",
            }
            for ln in r.deduction_lines
        ],
        "net_pay": f"{r.net_pay}",
        "total_cost_to_employer": f"{r.total_cost_to_employer}",
        "warnings": r.warnings,
    }
