"""
APEX Platform — Bank Reconciliation
═══════════════════════════════════════════════════════════════
Reconciles the company's book (cashbook) balance to the bank's
statement balance using the standard formula:

  Adjusted Book Balance = Book balance
                          + bank credits not yet in books
                          + interest / direct deposits
                          - bank charges / NSF / auto-debits

  Adjusted Bank Balance = Bank statement balance
                          + deposits in transit (books but not bank)
                          - outstanding checks (books but not bank)

  Reconciled when Adjusted Book = Adjusted Bank.

The service accepts raw adjustment entries and produces a clean
reconciliation report with:
  - adjusted book balance
  - adjusted bank balance
  - difference (zero = reconciled)
  - line-by-line breakdown per side
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List


_TWO = Decimal("0.01")


def _q(v: Decimal | int | float | str) -> Decimal:
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class RecItem:
    """One adjustment entry.
    side: 'book' or 'bank'
    kind: 'add' or 'subtract'"""
    description: str
    amount: Decimal
    side: str            # 'book' | 'bank'
    kind: str            # 'add' | 'subtract'


@dataclass
class BankRecInput:
    period_label: str = "FY"
    book_balance: Decimal = Decimal("0")
    bank_balance: Decimal = Decimal("0")
    items: List[RecItem] = field(default_factory=list)


@dataclass
class RecLine:
    description: str
    amount: Decimal
    kind: str            # 'add' | 'subtract'
    signed_amount: Decimal


@dataclass
class BankRecResult:
    period_label: str
    book_balance: Decimal
    bank_balance: Decimal
    book_adjustments: List[RecLine]
    bank_adjustments: List[RecLine]
    adjusted_book: Decimal
    adjusted_bank: Decimal
    difference: Decimal
    reconciled: bool
    warnings: list[str] = field(default_factory=list)


_VALID_SIDES = ("book", "bank")
_VALID_KINDS = ("add", "subtract")


def compute_bank_rec(inp: BankRecInput) -> BankRecResult:
    warnings: list[str] = []

    book_bal = _q(inp.book_balance)
    bank_bal = _q(inp.bank_balance)

    book_lines: List[RecLine] = []
    bank_lines: List[RecLine] = []
    book_net = Decimal("0")
    bank_net = Decimal("0")

    for item in inp.items:
        side = (item.side or "").lower()
        kind = (item.kind or "").lower()
        if side not in _VALID_SIDES:
            raise ValueError(f"item {item.description!r}: side must be one of {_VALID_SIDES}")
        if kind not in _VALID_KINDS:
            raise ValueError(f"item {item.description!r}: kind must be one of {_VALID_KINDS}")
        amt = _q(item.amount)
        if amt < 0:
            raise ValueError(f"item {item.description!r}: amount must be non-negative (use kind='subtract')")

        signed = amt if kind == "add" else -amt
        line = RecLine(
            description=item.description,
            amount=amt, kind=kind, signed_amount=signed,
        )
        if side == "book":
            book_lines.append(line)
            book_net += signed
        else:
            bank_lines.append(line)
            bank_net += signed

    adjusted_book = _q(book_bal + book_net)
    adjusted_bank = _q(bank_bal + bank_net)
    difference = _q(adjusted_book - adjusted_bank)
    reconciled = difference == 0

    if not reconciled:
        warnings.append(
            f"فرق غير معلّم قدره {difference} بين الدفاتر والبنك. "
            f"راجع الإيداعات والشيكات المعلّقة."
        )
    if book_bal < 0:
        warnings.append("الرصيد الدفتري سالب — تأكد من صحة الإدخال.")
    if len(inp.items) == 0:
        warnings.append("لا توجد تسويات — إذا كان الرصيدان متطابقين فهذا طبيعي.")

    return BankRecResult(
        period_label=inp.period_label,
        book_balance=book_bal,
        bank_balance=bank_bal,
        book_adjustments=book_lines,
        bank_adjustments=bank_lines,
        adjusted_book=adjusted_book,
        adjusted_bank=adjusted_bank,
        difference=difference,
        reconciled=reconciled,
        warnings=warnings,
    )


def result_to_dict(r: BankRecResult) -> dict:
    def line(ln: RecLine) -> dict:
        return {
            "description": ln.description,
            "amount": f"{ln.amount}",
            "kind": ln.kind,
            "signed_amount": f"{ln.signed_amount}",
        }
    return {
        "period_label": r.period_label,
        "book_balance": f"{r.book_balance}",
        "bank_balance": f"{r.bank_balance}",
        "book_adjustments": [line(ln) for ln in r.book_adjustments],
        "bank_adjustments": [line(ln) for ln in r.bank_adjustments],
        "adjusted_book": f"{r.adjusted_book}",
        "adjusted_bank": f"{r.adjusted_bank}",
        "difference": f"{r.difference}",
        "reconciled": r.reconciled,
        "warnings": r.warnings,
    }
