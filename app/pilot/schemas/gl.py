"""Pydantic schemas for GL."""

from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


# ──────────────────────────────────────────────────────────────────────────
# CoA
# ──────────────────────────────────────────────────────────────────────────

class GLAccountCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=20)
    name_ar: str
    name_en: Optional[str] = None
    parent_account_id: Optional[str] = None
    category: str = Field(..., pattern="^(asset|liability|equity|revenue|expense)$")
    subcategory: Optional[str] = None
    type: str = Field("detail", pattern="^(header|detail)$")
    normal_balance: str = Field(..., pattern="^(debit|credit)$")
    currency: Optional[str] = Field(None, min_length=3, max_length=3)
    is_control: bool = False
    require_cost_center: bool = False
    require_profit_center: bool = False
    default_vat_code: Optional[str] = None


class GLAccountRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    parent_account_id: Optional[str]
    code: str
    name_ar: str
    name_en: Optional[str]
    category: str
    subcategory: Optional[str]
    type: str
    normal_balance: str
    level: int
    is_system: bool
    is_active: bool
    is_control: bool
    currency: Optional[str]
    require_cost_center: bool
    require_profit_center: bool


# ──────────────────────────────────────────────────────────────────────────
# Fiscal Period
# ──────────────────────────────────────────────────────────────────────────

class FiscalPeriodRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    code: str
    name_ar: str
    year: int
    month: Optional[int]
    quarter: Optional[int]
    start_date: date
    end_date: date
    status: str
    je_count: int
    total_debits: Decimal
    total_credits: Decimal


class FiscalPeriodSeed(BaseModel):
    year: int = Field(..., ge=2000, le=2100)


class FiscalPeriodClose(BaseModel):
    closed_by_user_id: str


# ──────────────────────────────────────────────────────────────────────────
# Journal Entry
# ──────────────────────────────────────────────────────────────────────────

class JournalLineInput(BaseModel):
    account_code: Optional[str] = None
    account_id: Optional[str] = None
    debit: Decimal = Field(default=Decimal("0"), ge=0)
    credit: Decimal = Field(default=Decimal("0"), ge=0)
    currency: Optional[str] = None
    description: Optional[str] = None
    reference: Optional[str] = None
    cost_center_id: Optional[str] = None
    profit_center_id: Optional[str] = None
    project_id: Optional[str] = None
    branch_id: Optional[str] = None
    partner_type: Optional[str] = None
    partner_id: Optional[str] = None
    partner_name: Optional[str] = None
    vat_code: Optional[str] = None
    vat_amount: Optional[Decimal] = None


class JournalLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    line_number: int
    account_id: str
    currency: str
    debit_amount: Decimal
    credit_amount: Decimal
    exchange_rate: Decimal
    functional_debit: Decimal
    functional_credit: Decimal
    cost_center_id: Optional[str]
    profit_center_id: Optional[str]
    branch_id: Optional[str]
    partner_type: Optional[str]
    partner_id: Optional[str]
    partner_name: Optional[str]
    description: Optional[str]
    reference: Optional[str]
    vat_code: Optional[str]
    vat_amount: Optional[Decimal]


class JournalEntryCreate(BaseModel):
    entity_id: str
    kind: str = Field("manual", pattern="^(manual|auto_pos|auto_po|auto_payroll|auto_depreciation|auto_fx_reval|adjusting|closing|reversal|opening)$")
    je_date: date
    memo_ar: str = Field(..., min_length=3, max_length=500)
    memo_en: Optional[str] = None
    lines: list[JournalLineInput] = Field(..., min_length=2)
    source_type: Optional[str] = None
    source_id: Optional[str] = None
    source_reference: Optional[str] = None
    created_by_user_id: Optional[str] = None
    auto_post: bool = False


class JournalEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    fiscal_period_id: str
    je_number: str
    kind: str
    status: str
    source_type: Optional[str]
    source_id: Optional[str]
    source_reference: Optional[str]
    memo_ar: str
    memo_en: Optional[str]
    je_date: date
    posting_date: Optional[date]
    currency: str
    total_debit: Decimal
    total_credit: Decimal
    reversal_of_je_id: Optional[str]
    reversed_by_je_id: Optional[str]
    created_by_user_id: Optional[str]
    created_at: datetime
    submitted_at: Optional[datetime]
    approved_at: Optional[datetime]
    posted_at: Optional[datetime]


class JournalEntryDetail(JournalEntryRead):
    lines: list[JournalLineRead] = Field(default_factory=list)


class JEReverse(BaseModel):
    reversal_date: date
    memo_ar: str = Field(..., min_length=3, max_length=500)
    user_id: Optional[str] = None


# ──────────────────────────────────────────────────────────────────────────
# Reports
# ──────────────────────────────────────────────────────────────────────────

class TrialBalanceRow(BaseModel):
    account_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    category: str
    subcategory: Optional[str]
    normal_balance: str
    total_debit: Decimal
    total_credit: Decimal
    balance: Decimal


class TrialBalanceResponse(BaseModel):
    entity_id: str
    as_of_date: date
    rows: list[TrialBalanceRow]
    total_debit: Decimal
    total_credit: Decimal
    balanced: bool
    # G-TB-REAL-DATA-AUDIT (2026-05-08): count of posted JEs whose
    # je_date <= as_of_date. Lets the frontend render the
    # "المصدر: pilot_journal_lines — N قيد مرحّل" footer without a
    # second roundtrip. Defaults to 0 so older callers / fixtures
    # that don't compute it still satisfy the schema.
    posted_je_count: int = 0


class IncomeStatementResponse(BaseModel):
    entity_id: str
    start_date: date
    end_date: date
    revenue_total: float
    expense_total: float
    net_income: float
    revenue_by_subcat: dict
    expense_by_subcat: dict


class BalanceSheetResponse(BaseModel):
    entity_id: str
    as_of_date: date
    assets: float
    liabilities: float
    equity: float
    current_earnings: float
    total_equity: float
    balanced: bool
    difference: float
