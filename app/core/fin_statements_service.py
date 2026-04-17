"""
APEX Platform — Financial Statements & Period Close
═══════════════════════════════════════════════════════════════
Takes a trial-balance (list of accounts with dr/cr balances and
IFRS classification) and produces:

  • Validated Trial Balance (totals + imbalance detection)
  • Income Statement (IS) = Revenue − Expenses = Net Income
  • Balance Sheet (BS) with post-close retained earnings
  • Closing entries (revenue/expense → Retained Earnings)
  • Post-close TB (P&L accounts zeroed)

Account classification follows IFRS:
  • asset          → debit normal, on BS
  • liability      → credit normal, on BS
  • equity         → credit normal, on BS
  • revenue        → credit normal, on IS (closed to RE)
  • expense        → debit normal, on IS (closed to RE)
  • contra_asset   → credit normal, on BS (e.g. accum. depr.)
  • contra_equity  → debit normal, on BS (e.g. treasury stock)
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


# Valid IFRS classifications
VALID_CLASSES = {
    "asset", "liability", "equity", "revenue", "expense",
    "contra_asset", "contra_equity",
}

# Which classes appear on the Income Statement
IS_CLASSES = {"revenue", "expense"}
BS_CLASSES = {"asset", "liability", "equity", "contra_asset", "contra_equity"}

# Natural side for each class
DEBIT_NATURAL = {"asset", "expense", "contra_equity"}
CREDIT_NATURAL = {"liability", "equity", "revenue", "contra_asset"}


@dataclass
class TBLine:
    """One line in the trial balance."""
    account_code: str
    account_name: str
    classification: str        # one of VALID_CLASSES
    debit: Decimal = Decimal("0")
    credit: Decimal = Decimal("0")


@dataclass
class TBInput:
    entity_name: str
    period_label: str          # "Q1 2026" / "FY 2025" etc.
    currency: str = "SAR"
    lines: List[TBLine] = field(default_factory=list)
    opening_retained_earnings: Decimal = Decimal("0")


@dataclass
class TBLineOut:
    account_code: str
    account_name: str
    classification: str
    debit: Decimal
    credit: Decimal
    net_balance: Decimal       # debit − credit (positive = debit balance)


@dataclass
class TrialBalanceResult:
    entity_name: str
    period_label: str
    currency: str
    lines: List[TBLineOut]
    total_debits: Decimal
    total_credits: Decimal
    is_balanced: bool
    difference: Decimal
    warnings: list[str] = field(default_factory=list)


@dataclass
class ISLineOut:
    account_code: str
    account_name: str
    amount: Decimal            # positive for both revenue & expense
    side: str                  # 'revenue' | 'expense'


@dataclass
class IncomeStatementResult:
    entity_name: str
    period_label: str
    currency: str
    revenue_lines: List[ISLineOut]
    expense_lines: List[ISLineOut]
    total_revenue: Decimal
    total_expenses: Decimal
    net_income: Decimal
    margin_pct: Decimal        # net_income / total_revenue × 100


@dataclass
class BSLineOut:
    account_code: str
    account_name: str
    classification: str
    amount: Decimal


@dataclass
class BalanceSheetResult:
    entity_name: str
    period_label: str
    currency: str
    assets: List[BSLineOut]
    liabilities: List[BSLineOut]
    equity: List[BSLineOut]
    total_assets: Decimal
    total_liabilities: Decimal
    total_equity: Decimal
    net_income_for_period: Decimal
    retained_earnings_end: Decimal     # opening RE + NI
    is_balanced: bool                   # assets == liab + equity
    difference: Decimal
    warnings: list[str] = field(default_factory=list)


@dataclass
class ClosingEntryLine:
    account_code: str
    account_name: str
    debit: Decimal = Decimal("0")
    credit: Decimal = Decimal("0")
    description: str = ""


@dataclass
class ClosingEntriesResult:
    entity_name: str
    period_label: str
    currency: str
    close_revenue_entry: List[ClosingEntryLine]    # Dr Revenue, Cr Income Summary
    close_expense_entry: List[ClosingEntryLine]    # Dr Income Summary, Cr Expense
    close_income_summary: List[ClosingEntryLine]   # Dr/Cr Income Summary, ~RE
    total_revenue_closed: Decimal
    total_expense_closed: Decimal
    net_income: Decimal
    retained_earnings_end: Decimal


# ═══════════════════════════════════════════════════════════════
# Validation + normalisation
# ═══════════════════════════════════════════════════════════════


def _validate_and_normalise(inp: TBInput) -> List[TBLineOut]:
    if not inp.lines:
        raise ValueError("Trial balance must have at least one line")
    if len(inp.lines) > 10000:
        raise ValueError("Too many lines (max 10000)")

    out: List[TBLineOut] = []
    seen_codes: set[str] = set()
    for i, ln in enumerate(inp.lines, start=1):
        if not ln.account_code:
            raise ValueError(f"Line {i}: account_code is required")
        if not ln.account_name:
            raise ValueError(f"Line {i}: account_name is required")
        if ln.classification not in VALID_CLASSES:
            raise ValueError(
                f"Line {i}: classification {ln.classification!r} is invalid; "
                f"must be one of {sorted(VALID_CLASSES)}"
            )
        if ln.account_code in seen_codes:
            raise ValueError(f"Line {i}: duplicate account_code {ln.account_code!r}")
        seen_codes.add(ln.account_code)

        d = _q(ln.debit)
        c = _q(ln.credit)
        if d < 0 or c < 0:
            raise ValueError(f"Line {i}: debit and credit cannot be negative")

        net = d - c
        out.append(TBLineOut(
            account_code=ln.account_code,
            account_name=ln.account_name,
            classification=ln.classification,
            debit=d, credit=c, net_balance=_q(net),
        ))
    return out


# ═══════════════════════════════════════════════════════════════
# Trial Balance
# ═══════════════════════════════════════════════════════════════


def build_trial_balance(inp: TBInput) -> TrialBalanceResult:
    out_lines = _validate_and_normalise(inp)
    total_d = sum((ln.debit for ln in out_lines), Decimal("0"))
    total_c = sum((ln.credit for ln in out_lines), Decimal("0"))
    diff = _q(total_d - total_c)
    balanced = diff == 0

    warnings: list[str] = []
    if not balanced:
        warnings.append(
            f"ميزان المراجعة غير متوازن — الفرق = {diff}. "
            "راجع القيود الناقصة أو المكررة."
        )
    # Sanity checks on natural side
    for ln in out_lines:
        if ln.classification in DEBIT_NATURAL and ln.net_balance < 0:
            warnings.append(
                f"الحساب {ln.account_code} ({ln.account_name}) رصيده دائن "
                f"رغم أنه {ln.classification} — راجع توجيه القيود."
            )
        elif ln.classification in CREDIT_NATURAL and ln.net_balance > 0:
            warnings.append(
                f"الحساب {ln.account_code} ({ln.account_name}) رصيده مدين "
                f"رغم أنه {ln.classification} — راجع توجيه القيود."
            )

    return TrialBalanceResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        currency=inp.currency,
        lines=out_lines,
        total_debits=_q(total_d),
        total_credits=_q(total_c),
        is_balanced=balanced,
        difference=diff,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Income Statement
# ═══════════════════════════════════════════════════════════════


def build_income_statement(inp: TBInput) -> IncomeStatementResult:
    out_lines = _validate_and_normalise(inp)
    revenue: List[ISLineOut] = []
    expense: List[ISLineOut] = []
    for ln in out_lines:
        if ln.classification == "revenue":
            # Revenue normal credit — net balance negative means credit balance.
            # Display as positive amount (magnitude of credit).
            amt = _q(-ln.net_balance)
            revenue.append(ISLineOut(ln.account_code, ln.account_name, amt, "revenue"))
        elif ln.classification == "expense":
            # Expense normal debit — net balance positive means debit balance
            amt = _q(ln.net_balance)
            expense.append(ISLineOut(ln.account_code, ln.account_name, amt, "expense"))

    total_rev = sum((r.amount for r in revenue), Decimal("0"))
    total_exp = sum((e.amount for e in expense), Decimal("0"))
    ni = _q(total_rev - total_exp)
    margin = Decimal("0") if total_rev == 0 else _q((ni / total_rev) * Decimal("100"))

    return IncomeStatementResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        currency=inp.currency,
        revenue_lines=revenue,
        expense_lines=expense,
        total_revenue=_q(total_rev),
        total_expenses=_q(total_exp),
        net_income=ni,
        margin_pct=margin,
    )


# ═══════════════════════════════════════════════════════════════
# Balance Sheet (with auto-calculated end-of-period RE)
# ═══════════════════════════════════════════════════════════════


def build_balance_sheet(inp: TBInput) -> BalanceSheetResult:
    out_lines = _validate_and_normalise(inp)
    is_res = build_income_statement(inp)
    ni = is_res.net_income

    assets: List[BSLineOut] = []
    liab: List[BSLineOut] = []
    eq: List[BSLineOut] = []
    for ln in out_lines:
        if ln.classification == "asset":
            assets.append(BSLineOut(ln.account_code, ln.account_name,
                "asset", _q(ln.net_balance)))
        elif ln.classification == "contra_asset":
            # Contra-asset (credit normal, e.g. accum. depreciation):
            # net_balance is negative for credit balances; show as-is so
            # it subtracts from total_assets.
            assets.append(BSLineOut(ln.account_code, ln.account_name,
                "contra_asset", _q(ln.net_balance)))
        elif ln.classification == "liability":
            liab.append(BSLineOut(ln.account_code, ln.account_name,
                "liability", _q(-ln.net_balance)))
        elif ln.classification == "equity":
            eq.append(BSLineOut(ln.account_code, ln.account_name,
                "equity", _q(-ln.net_balance)))
        elif ln.classification == "contra_equity":
            eq.append(BSLineOut(ln.account_code, ln.account_name,
                "contra_equity", _q(-ln.net_balance)))
        # revenue/expense skipped — they're on IS

    re_end = _q(Decimal(str(inp.opening_retained_earnings)) + ni)

    # Add a derived Retained-Earnings-End line to equity so BS balances
    eq.append(BSLineOut(
        account_code="RE-END", account_name="الأرباح المرحّلة (نهاية الفترة)",
        classification="equity", amount=re_end,
    ))

    total_assets = sum((a.amount for a in assets), Decimal("0"))
    total_liab = sum((l.amount for l in liab), Decimal("0"))
    total_eq = sum((e.amount for e in eq), Decimal("0"))

    diff = _q(total_assets - (total_liab + total_eq))
    balanced = diff == 0

    warnings: list[str] = []
    if not balanced:
        warnings.append(
            f"الميزانية غير متوازنة — الأصول ≠ الخصوم + حقوق الملكية، "
            f"الفرق = {diff}. راجع ميزان المراجعة."
        )

    return BalanceSheetResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        currency=inp.currency,
        assets=assets, liabilities=liab, equity=eq,
        total_assets=_q(total_assets),
        total_liabilities=_q(total_liab),
        total_equity=_q(total_eq),
        net_income_for_period=ni,
        retained_earnings_end=re_end,
        is_balanced=balanced,
        difference=diff,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Closing entries
# ═══════════════════════════════════════════════════════════════


def generate_closing_entries(inp: TBInput) -> ClosingEntriesResult:
    out_lines = _validate_and_normalise(inp)
    is_res = build_income_statement(inp)

    close_rev: List[ClosingEntryLine] = []
    close_exp: List[ClosingEntryLine] = []

    total_rev = Decimal("0")
    total_exp = Decimal("0")

    # Close revenue: Dr each revenue account, Cr Income Summary
    for ln in out_lines:
        if ln.classification == "revenue":
            credit_bal = -ln.net_balance  # positive = the credit sum
            if credit_bal > 0:
                close_rev.append(ClosingEntryLine(
                    account_code=ln.account_code,
                    account_name=ln.account_name,
                    debit=_q(credit_bal),
                    description="Close revenue to Income Summary",
                ))
                total_rev += credit_bal
    if total_rev > 0:
        close_rev.append(ClosingEntryLine(
            account_code="3900", account_name="ملخص الدخل",
            credit=_q(total_rev),
            description="Total revenue closed",
        ))

    # Close expense: Dr Income Summary, Cr each expense
    for ln in out_lines:
        if ln.classification == "expense":
            debit_bal = ln.net_balance
            if debit_bal > 0:
                close_exp.append(ClosingEntryLine(
                    account_code=ln.account_code,
                    account_name=ln.account_name,
                    credit=_q(debit_bal),
                    description="Close expense to Income Summary",
                ))
                total_exp += debit_bal
    if total_exp > 0:
        close_exp.insert(0, ClosingEntryLine(
            account_code="3900", account_name="ملخص الدخل",
            debit=_q(total_exp),
            description="Total expenses closed",
        ))

    # Close Income Summary → Retained Earnings
    ni = _q(total_rev - total_exp)
    close_is: List[ClosingEntryLine] = []
    if ni > 0:
        close_is.append(ClosingEntryLine(
            account_code="3900", account_name="ملخص الدخل",
            debit=ni, description="Close Income Summary to RE",
        ))
        close_is.append(ClosingEntryLine(
            account_code="3200", account_name="الأرباح المرحّلة",
            credit=ni, description="Net income to retained earnings",
        ))
    elif ni < 0:
        close_is.append(ClosingEntryLine(
            account_code="3200", account_name="الأرباح المرحّلة",
            debit=-ni, description="Net loss from retained earnings",
        ))
        close_is.append(ClosingEntryLine(
            account_code="3900", account_name="ملخص الدخل",
            credit=-ni, description="Close Income Summary (loss)",
        ))

    re_end = _q(Decimal(str(inp.opening_retained_earnings)) + ni)

    return ClosingEntriesResult(
        entity_name=inp.entity_name,
        period_label=inp.period_label,
        currency=inp.currency,
        close_revenue_entry=close_rev,
        close_expense_entry=close_exp,
        close_income_summary=close_is,
        total_revenue_closed=_q(total_rev),
        total_expense_closed=_q(total_exp),
        net_income=ni,
        retained_earnings_end=re_end,
    )


# ═══════════════════════════════════════════════════════════════
# Dict serialisers
# ═══════════════════════════════════════════════════════════════


def tb_to_dict(r: TrialBalanceResult) -> dict:
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "currency": r.currency,
        "lines": [
            {
                "account_code": ln.account_code,
                "account_name": ln.account_name,
                "classification": ln.classification,
                "debit": f"{ln.debit}",
                "credit": f"{ln.credit}",
                "net_balance": f"{ln.net_balance}",
            } for ln in r.lines
        ],
        "total_debits": f"{r.total_debits}",
        "total_credits": f"{r.total_credits}",
        "is_balanced": r.is_balanced,
        "difference": f"{r.difference}",
        "warnings": r.warnings,
    }


def is_to_dict(r: IncomeStatementResult) -> dict:
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "currency": r.currency,
        "revenue_lines": [
            {"account_code": ln.account_code, "account_name": ln.account_name,
             "amount": f"{ln.amount}"} for ln in r.revenue_lines
        ],
        "expense_lines": [
            {"account_code": ln.account_code, "account_name": ln.account_name,
             "amount": f"{ln.amount}"} for ln in r.expense_lines
        ],
        "total_revenue": f"{r.total_revenue}",
        "total_expenses": f"{r.total_expenses}",
        "net_income": f"{r.net_income}",
        "margin_pct": f"{r.margin_pct}",
    }


def bs_to_dict(r: BalanceSheetResult) -> dict:
    def _bl(ln: BSLineOut) -> dict:
        return {
            "account_code": ln.account_code,
            "account_name": ln.account_name,
            "classification": ln.classification,
            "amount": f"{ln.amount}",
        }
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "currency": r.currency,
        "assets": [_bl(x) for x in r.assets],
        "liabilities": [_bl(x) for x in r.liabilities],
        "equity": [_bl(x) for x in r.equity],
        "total_assets": f"{r.total_assets}",
        "total_liabilities": f"{r.total_liabilities}",
        "total_equity": f"{r.total_equity}",
        "net_income_for_period": f"{r.net_income_for_period}",
        "retained_earnings_end": f"{r.retained_earnings_end}",
        "is_balanced": r.is_balanced,
        "difference": f"{r.difference}",
        "warnings": r.warnings,
    }


def closing_to_dict(r: ClosingEntriesResult) -> dict:
    def _cl(ln: ClosingEntryLine) -> dict:
        return {
            "account_code": ln.account_code,
            "account_name": ln.account_name,
            "debit": f"{ln.debit}",
            "credit": f"{ln.credit}",
            "description": ln.description,
        }
    return {
        "entity_name": r.entity_name,
        "period_label": r.period_label,
        "currency": r.currency,
        "close_revenue_entry": [_cl(x) for x in r.close_revenue_entry],
        "close_expense_entry": [_cl(x) for x in r.close_expense_entry],
        "close_income_summary": [_cl(x) for x in r.close_income_summary],
        "total_revenue_closed": f"{r.total_revenue_closed}",
        "total_expense_closed": f"{r.total_expense_closed}",
        "net_income": f"{r.net_income}",
        "retained_earnings_end": f"{r.retained_earnings_end}",
    }
