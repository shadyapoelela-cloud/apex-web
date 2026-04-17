"""
APEX Platform — Journal Entry Builder
═══════════════════════════════════════════════════════════════
The fundamental accounting primitive: a multi-line journal entry
that debits and credits accounts in balance.

Every line has:
  • account_code (e.g. "1100" for Cash, "4000" for Sales)
  • account_name (display label)
  • debit / credit (one must be > 0, the other = 0)
  • description (optional line narration)

A valid entry:
  • has ≥ 2 lines
  • Σ debits = Σ credits (must balance exactly — Decimal)
  • every line has either debit > 0 OR credit > 0, never both nor neither
  • account codes are consistent (digit format)

On success, the service:
  1. Allocates a gap-free JE number via JournalEntrySequence
  2. Logs the event to the immutable audit_trail

Templates accelerate common entries (sale, purchase, payroll, etc.).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional

from app.core.compliance_service import next_journal_entry_number, write_audit_event


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class JELineInput:
    account_code: str
    account_name: str
    debit: Decimal = Decimal("0")
    credit: Decimal = Decimal("0")
    description: str = ""


@dataclass
class JournalEntryInput:
    client_id: str
    fiscal_year: str            # "YYYY"
    date: str                    # ISO "YYYY-MM-DD"
    memo: str = ""
    reference: str = ""
    lines: List[JELineInput] = field(default_factory=list)
    prefix: str = "JE"           # e.g. "JE", "ADJ", "CLR"
    currency: str = "SAR"
    # If True, reserve a number and write audit event.
    # If False, just validate + return structure (dry run / preview).
    commit: bool = True


@dataclass
class JELine:
    account_code: str
    account_name: str
    debit: Decimal
    credit: Decimal
    description: str


@dataclass
class JournalEntryResult:
    entry_number: Optional[str]       # None if not committed
    sequence: Optional[int]
    prefix: str
    fiscal_year: str
    client_id: str
    date: str
    memo: str
    reference: str
    currency: str
    lines: List[JELine]
    total_debits: Decimal
    total_credits: Decimal
    is_balanced: bool
    difference: Decimal                # debits − credits
    committed: bool
    audit_hash: Optional[str] = None
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Templates (pre-built common entries)
# ═══════════════════════════════════════════════════════════════


# Each template returns a list of line "skeletons" that the caller
# can fill in with actual amounts.
_TEMPLATES: dict[str, dict] = {
    "cash_sale": {
        "name_ar": "مبيعات نقدية",
        "name_en": "Cash Sale",
        "lines": [
            {"account_code": "1100", "account_name": "النقد", "side": "debit"},
            {"account_code": "4000", "account_name": "المبيعات", "side": "credit"},
            {"account_code": "2300", "account_name": "ضريبة القيمة المضافة (مخرجات)", "side": "credit"},
        ],
    },
    "credit_sale": {
        "name_ar": "مبيعات آجلة",
        "name_en": "Credit Sale",
        "lines": [
            {"account_code": "1200", "account_name": "الذمم المدينة", "side": "debit"},
            {"account_code": "4000", "account_name": "المبيعات", "side": "credit"},
            {"account_code": "2300", "account_name": "ضريبة القيمة المضافة (مخرجات)", "side": "credit"},
        ],
    },
    "cash_purchase": {
        "name_ar": "مشتريات نقدية",
        "name_en": "Cash Purchase",
        "lines": [
            {"account_code": "5000", "account_name": "المشتريات / تكلفة المبيعات", "side": "debit"},
            {"account_code": "2310", "account_name": "ضريبة القيمة المضافة (مدخلات)", "side": "debit"},
            {"account_code": "1100", "account_name": "النقد", "side": "credit"},
        ],
    },
    "credit_purchase": {
        "name_ar": "مشتريات آجلة",
        "name_en": "Credit Purchase",
        "lines": [
            {"account_code": "5000", "account_name": "المشتريات / تكلفة المبيعات", "side": "debit"},
            {"account_code": "2310", "account_name": "ضريبة القيمة المضافة (مدخلات)", "side": "debit"},
            {"account_code": "2100", "account_name": "الذمم الدائنة", "side": "credit"},
        ],
    },
    "payroll": {
        "name_ar": "رواتب الموظفين",
        "name_en": "Payroll",
        "lines": [
            {"account_code": "6100", "account_name": "مصروف الرواتب", "side": "debit"},
            {"account_code": "6110", "account_name": "حصة صاحب العمل في التأمينات", "side": "debit"},
            {"account_code": "2200", "account_name": "رواتب مستحقة", "side": "credit"},
            {"account_code": "2210", "account_name": "تأمينات مستحقة (الموظف + صاحب العمل)", "side": "credit"},
        ],
    },
    "loan_payment": {
        "name_ar": "سداد قسط قرض",
        "name_en": "Loan Payment",
        "lines": [
            {"account_code": "2500", "account_name": "القروض (أصل)", "side": "debit"},
            {"account_code": "6200", "account_name": "مصروف الفائدة", "side": "debit"},
            {"account_code": "1100", "account_name": "النقد", "side": "credit"},
        ],
    },
    "depreciation": {
        "name_ar": "قيد الإهلاك",
        "name_en": "Depreciation",
        "lines": [
            {"account_code": "6300", "account_name": "مصروف الإهلاك", "side": "debit"},
            {"account_code": "1510", "account_name": "مجمع الإهلاك", "side": "credit"},
        ],
    },
    "rent_prepaid": {
        "name_ar": "إيجار مدفوع مقدّماً",
        "name_en": "Prepaid Rent",
        "lines": [
            {"account_code": "1300", "account_name": "مصروفات مدفوعة مقدماً", "side": "debit"},
            {"account_code": "1100", "account_name": "النقد", "side": "credit"},
        ],
    },
    "dividend_declared": {
        "name_ar": "إعلان توزيع أرباح",
        "name_en": "Dividend Declared",
        "lines": [
            {"account_code": "3200", "account_name": "الأرباح المرحلة", "side": "debit"},
            {"account_code": "2400", "account_name": "توزيعات مستحقة", "side": "credit"},
        ],
    },
    "customer_payment": {
        "name_ar": "استلام دفعة من عميل",
        "name_en": "Customer Payment",
        "lines": [
            {"account_code": "1100", "account_name": "النقد", "side": "debit"},
            {"account_code": "1200", "account_name": "الذمم المدينة", "side": "credit"},
        ],
    },
}


def list_templates() -> List[dict]:
    """Public: list all available templates with their skeleton."""
    return [
        {"code": code, **tmpl} for code, tmpl in _TEMPLATES.items()
    ]


def get_template(code: str) -> Optional[dict]:
    tmpl = _TEMPLATES.get(code)
    if tmpl is None:
        return None
    return {"code": code, **tmpl}


# ═══════════════════════════════════════════════════════════════
# Build / validate
# ═══════════════════════════════════════════════════════════════


def build_journal_entry(inp: JournalEntryInput) -> JournalEntryResult:
    warnings: list[str] = []

    # Input validation
    if not inp.client_id:
        raise ValueError("client_id is required")
    if len(inp.fiscal_year) != 4 or not inp.fiscal_year.isdigit():
        raise ValueError("fiscal_year must be 4 digits")
    if not inp.lines or len(inp.lines) < 2:
        raise ValueError("Journal entry must have at least 2 lines")
    if len(inp.lines) > 1000:
        raise ValueError("Too many lines (max 1000)")

    # Per-line validation
    lines: List[JELine] = []
    total_debit = Decimal("0")
    total_credit = Decimal("0")

    for i, ln in enumerate(inp.lines, start=1):
        if not ln.account_code:
            raise ValueError(f"Line {i}: account_code is required")
        if not ln.account_name:
            raise ValueError(f"Line {i}: account_name is required")
        d = _q(ln.debit)
        c = _q(ln.credit)
        if d < 0 or c < 0:
            raise ValueError(f"Line {i}: debit and credit cannot be negative")
        if d > 0 and c > 0:
            raise ValueError(f"Line {i}: cannot have both debit and credit > 0")
        if d == 0 and c == 0:
            raise ValueError(f"Line {i}: must have either debit or credit > 0")
        lines.append(JELine(
            account_code=ln.account_code,
            account_name=ln.account_name,
            debit=d, credit=c, description=ln.description or "",
        ))
        total_debit += d
        total_credit += c

    total_debit = _q(total_debit)
    total_credit = _q(total_credit)
    difference = _q(total_debit - total_credit)
    is_balanced = difference == 0

    if not is_balanced:
        raise ValueError(
            f"Entry not balanced: debits ({total_debit}) ≠ credits ({total_credit}). "
            f"Difference = {difference}"
        )

    # Preview-only? Return without reserving a number.
    if not inp.commit:
        return JournalEntryResult(
            entry_number=None, sequence=None,
            prefix=inp.prefix, fiscal_year=inp.fiscal_year,
            client_id=inp.client_id, date=inp.date,
            memo=inp.memo, reference=inp.reference, currency=inp.currency,
            lines=lines,
            total_debits=total_debit, total_credits=total_credit,
            is_balanced=is_balanced, difference=difference,
            committed=False, warnings=warnings,
        )

    # Commit: reserve a number, write audit trail
    num_info = next_journal_entry_number(inp.client_id, inp.fiscal_year, inp.prefix)
    audit_hash = write_audit_event(
        action="je.post",
        entity_type="journal_entry",
        entity_id=num_info["number"],
        after={
            "number": num_info["number"],
            "total_debit": f"{total_debit}",
            "total_credit": f"{total_credit}",
            "lines_count": len(lines),
            "memo": inp.memo,
            "reference": inp.reference,
        },
    )

    return JournalEntryResult(
        entry_number=num_info["number"],
        sequence=num_info["sequence"],
        prefix=num_info["prefix"],
        fiscal_year=num_info["fiscal_year"],
        client_id=inp.client_id, date=inp.date,
        memo=inp.memo, reference=inp.reference, currency=inp.currency,
        lines=lines,
        total_debits=total_debit, total_credits=total_credit,
        is_balanced=is_balanced, difference=difference,
        committed=True, audit_hash=audit_hash, warnings=warnings,
    )


def result_to_dict(r: JournalEntryResult) -> dict:
    return {
        "entry_number": r.entry_number,
        "sequence": r.sequence,
        "prefix": r.prefix,
        "fiscal_year": r.fiscal_year,
        "client_id": r.client_id,
        "date": r.date,
        "memo": r.memo,
        "reference": r.reference,
        "currency": r.currency,
        "lines": [
            {
                "account_code": ln.account_code,
                "account_name": ln.account_name,
                "debit": f"{ln.debit}",
                "credit": f"{ln.credit}",
                "description": ln.description,
            }
            for ln in r.lines
        ],
        "total_debits": f"{r.total_debits}",
        "total_credits": f"{r.total_credits}",
        "is_balanced": r.is_balanced,
        "difference": f"{r.difference}",
        "committed": r.committed,
        "audit_hash": r.audit_hash,
        "warnings": r.warnings,
    }
