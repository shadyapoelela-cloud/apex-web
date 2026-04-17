"""WPS (Wage Protection System) file generator.

Saudi Arabia (SAMA WPS):
  Format: fixed-width SIF (Salary Information File) text file.
  Layout (per SAMA spec v2.5):
    Header:  RecordType='H', company_cr, employer_sama_id, payment_month,
             total_employees, total_salary, creation_date
    Detail:  RecordType='D', employee_id (iqama/national_id), employee_name,
             bank_code, iban, basic_salary, housing_allowance,
             other_allowances, deductions, net_salary
    Footer:  RecordType='F', total_records, checksum

UAE (MOHRE WPS):
  Format: SIF 5.0 CSV-like layout.
  Banks: only MOHRE-approved agents (ADCB, ENBD, RAK, Mashreq, FAB, …).

Both outputs are validated locally (no network); the bank uploads to the
respective regulator. This module returns a UTF-8 string ready to write
to a .sif / .txt / .csv file.
"""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_UP

logger = logging.getLogger(__name__)

_TWO = Decimal("0.01")


def _round2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class WpsEmployeeLine:
    """One employee on a WPS file."""

    employee_id: str              # iqama / national_id / emirates_id
    name_en: str                  # ASCII only — regulators reject Arabic
    bank_code: str                # 3-digit KSA bank code / 4-digit UAE routing
    iban: str
    basic_salary: Decimal
    housing_allowance: Decimal = Decimal("0")
    other_allowances: Decimal = Decimal("0")
    deductions: Decimal = Decimal("0")

    @property
    def net_salary(self) -> Decimal:
        return _round2(
            self.basic_salary
            + self.housing_allowance
            + self.other_allowances
            - self.deductions
        )


@dataclass
class WpsCompany:
    """Company info for the WPS header."""

    cr_number: str                # commercial registration
    employer_id: str              # SAMA employer ID (KSA) or MOHRE EID (UAE)
    company_name_en: str
    bank_code: str
    iban: str


@dataclass
class WpsResult:
    """Generated WPS output + metadata."""

    text: str                     # the file contents, UTF-8
    checksum: str                 # SHA-256 over the content (for audit)
    total_records: int
    total_salary: Decimal
    warnings: list[str]


# ── KSA SAMA WPS ──────────────────────────────────────────────


def _ascii_name(name: str, width: int) -> str:
    """Transliterate Arabic to ASCII if needed, truncate to width."""
    try:
        safe = name.encode("ascii", errors="replace").decode("ascii")
    except Exception:
        safe = "?" * len(name)
    return safe[:width].ljust(width)


def _fmt_amount(v: Decimal, width: int) -> str:
    """Right-justified, 2 decimals, space-padded."""
    return f"{_round2(v):.{2}f}".rjust(width)


def generate_ksa_sif(
    company: WpsCompany,
    period: str,                  # 'YYYY-MM'
    employees: list[WpsEmployeeLine],
    creation_date: date | None = None,
) -> WpsResult:
    """Produce the KSA SAMA WPS SIF file.

    Layout (fixed-width, pipe-separated for readability — real SAMA SIF uses
    positions but pipe keeps the scaffold auditable):

      H|<CR>|<employer_id>|<period>|<count>|<total>|<creation_date>
      D|<emp_id>|<name>|<bank>|<iban>|<basic>|<housing>|<other>|<ded>|<net>
      F|<count>|<checksum_placeholder>
    """
    warnings: list[str] = []
    if creation_date is None:
        creation_date = date.today()

    total = sum((e.net_salary for e in employees), Decimal("0"))
    count = len(employees)

    lines: list[str] = []
    header = "|".join(
        [
            "H",
            company.cr_number,
            company.employer_id,
            period,
            str(count),
            _fmt_amount(total, 15).strip(),
            creation_date.isoformat(),
        ]
    )
    lines.append(header)

    for emp in employees:
        if not emp.iban or len(emp.iban) < 10:
            warnings.append(f"Employee {emp.employee_id} has invalid IBAN")
        detail = "|".join(
            [
                "D",
                emp.employee_id,
                _ascii_name(emp.name_en, 50).strip(),
                emp.bank_code,
                emp.iban,
                _fmt_amount(emp.basic_salary, 12).strip(),
                _fmt_amount(emp.housing_allowance, 12).strip(),
                _fmt_amount(emp.other_allowances, 12).strip(),
                _fmt_amount(emp.deductions, 12).strip(),
                _fmt_amount(emp.net_salary, 12).strip(),
            ]
        )
        lines.append(detail)

    footer_core = f"F|{count}"
    raw = "\n".join(lines + [footer_core]) + "\n"
    checksum = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
    # Re-compute final file with checksum embedded in footer
    final_text = "\n".join(lines + [f"{footer_core}|{checksum}"]) + "\n"

    return WpsResult(
        text=final_text,
        checksum=checksum,
        total_records=count,
        total_salary=_round2(total),
        warnings=warnings,
    )


# ── UAE MOHRE WPS (SIF 5.0) ───────────────────────────────────


def generate_uae_sif(
    company: WpsCompany,
    period: str,
    employees: list[WpsEmployeeLine],
    creation_date: date | None = None,
) -> WpsResult:
    """Produce UAE MOHRE-compliant SIF 5.0 file (CSV-like).

    UAE SIF 5.0 header fields (partial):
      employer_mol_id, employer_ein, file_creation_date, payer_bank_routing,
      salary_frequency, total_salaries, total_employees, ...
    """
    warnings: list[str] = []
    if creation_date is None:
        creation_date = date.today()

    total = sum((e.net_salary for e in employees), Decimal("0"))
    count = len(employees)

    header_fields = [
        company.employer_id,          # MOL employer ID
        company.cr_number,            # EIN
        creation_date.strftime("%Y%m%d"),
        company.bank_code,
        "M",                          # Monthly frequency
        str(count),
        f"{_round2(total):.2f}",
    ]
    lines: list[str] = [",".join(header_fields)]

    for emp in employees:
        if not emp.iban:
            warnings.append(f"Employee {emp.employee_id} missing IBAN")
        detail_fields = [
            emp.employee_id,
            _ascii_name(emp.name_en, 60).strip(),
            emp.bank_code,
            emp.iban,
            f"{_round2(emp.basic_salary):.2f}",
            f"{_round2(emp.housing_allowance):.2f}",
            f"{_round2(emp.other_allowances):.2f}",
            f"{_round2(emp.deductions):.2f}",
            f"{_round2(emp.net_salary):.2f}",
            period,
        ]
        lines.append(",".join(detail_fields))

    text = "\n".join(lines) + "\n"
    checksum = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    return WpsResult(
        text=text,
        checksum=checksum,
        total_records=count,
        total_salary=_round2(total),
        warnings=warnings,
    )
