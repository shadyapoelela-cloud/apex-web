"""Pydantic schemas for Compliance (ZATCA, UAE CT, GOSI, WPS, VAT Return)."""

from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


# ──────────────────────────────────────────────────────────────────────────
# ZATCA
# ──────────────────────────────────────────────────────────────────────────

class ZatcaOnboardingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    environment: str
    csid: Optional[str]
    csid_issued_at: Optional[datetime]
    csid_expires_at: Optional[datetime]
    invoice_counter: int
    previous_invoice_hash: Optional[str]
    vat_registration_number: Optional[str]
    cr_number: Optional[str]
    status: str


class ZatcaSubmissionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    source_type: str
    source_id: str
    source_reference: str
    invoice_kind: str
    invoice_uuid: str
    invoice_counter: int
    invoice_hash: str
    previous_invoice_hash: Optional[str]
    qr_tlv_base64: str
    total_excl_vat: Decimal
    total_vat: Decimal
    total_incl_vat: Decimal
    status: str
    submitted_at: Optional[datetime]
    zatca_uuid_ack: Optional[str]
    retry_count: int


class QrDecodeResponse(BaseModel):
    seller_name: Optional[str]
    vat_number: Optional[str]
    invoice_datetime: Optional[str]
    total_with_vat: Optional[str]
    vat_amount: Optional[str]
    invoice_hash: Optional[str]


# ──────────────────────────────────────────────────────────────────────────
# GOSI
# ──────────────────────────────────────────────────────────────────────────

class GosiRegistrationCreate(BaseModel):
    entity_id: str
    employee_user_id: str
    employee_number: str
    national_id: str = Field(..., min_length=10, max_length=20)
    employee_name_ar: str
    is_saudi: bool
    contribution_wage: Decimal = Field(..., gt=0)
    registered_at: date
    gosi_subscriber_number: Optional[str] = None


class GosiRegistrationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    employee_user_id: str
    employee_number: str
    national_id: str
    employee_name_ar: str
    employee_type: str
    is_saudi: bool
    gosi_subscriber_number: Optional[str]
    registered_at: date
    deregistered_at: Optional[date]
    contribution_wage: Decimal
    employee_rate_pct: Decimal
    employer_rate_pct: Decimal
    occupational_hazards_rate_pct: Decimal
    is_active: bool


class GosiContributionCalc(BaseModel):
    year: int = Field(..., ge=2020)
    month: int = Field(..., ge=1, le=12)
    wage: Decimal = Field(..., gt=0)


class GosiContributionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    registration_id: str
    year: int
    month: int
    contribution_wage: Decimal
    employee_contribution: Decimal
    employer_contribution: Decimal
    occupational_hazards: Decimal
    total_contribution: Decimal
    status: str
    submitted_at: Optional[datetime]
    paid_at: Optional[datetime]


# ──────────────────────────────────────────────────────────────────────────
# WPS
# ──────────────────────────────────────────────────────────────────────────

class WpsEmployeeInput(BaseModel):
    employee_user_id: str
    employee_name_ar: str
    national_id: str
    employee_bank_code: str
    employee_account_iban: str
    basic_salary: Decimal = Field(default=Decimal("0"), ge=0)
    housing_allowance: Decimal = Field(default=Decimal("0"), ge=0)
    transport_allowance: Decimal = Field(default=Decimal("0"), ge=0)
    other_allowances: Decimal = Field(default=Decimal("0"), ge=0)
    gosi_deduction: Decimal = Field(default=Decimal("0"), ge=0)
    other_deductions: Decimal = Field(default=Decimal("0"), ge=0)


class WpsBatchCreate(BaseModel):
    entity_id: str
    year: int = Field(..., ge=2020)
    month: int = Field(..., ge=1, le=12)
    employer_bank_code: str
    employer_account_iban: str = Field(..., min_length=15, max_length=34)
    employer_establishment_id: str
    employees: list[WpsEmployeeInput] = Field(..., min_length=1)


class WpsBatchRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    year: int
    month: int
    employer_bank_code: str
    employer_account_iban: str
    employer_establishment_id: str
    employee_count: int
    total_basic: Decimal
    total_housing: Decimal
    total_transport: Decimal
    total_other: Decimal
    total_deductions: Decimal
    total_net: Decimal
    status: str
    sif_file_name: Optional[str]
    sif_generated_at: Optional[datetime]


class WpsSifRecordRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    batch_id: str
    employee_user_id: str
    employee_name_ar: str
    national_id: str
    basic_salary: Decimal
    gross_salary: Decimal
    gosi_deduction: Decimal
    net_salary: Decimal
    status: str


class WpsBatchDetail(WpsBatchRead):
    sif_file_content: Optional[str]
    records: list[WpsSifRecordRead] = Field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────
# UAE CT
# ──────────────────────────────────────────────────────────────────────────

class UaeCtFilingCreate(BaseModel):
    entity_id: str
    fiscal_year: int = Field(..., ge=2023)
    gross_revenue: Decimal = Field(..., ge=0)
    exempt_revenue: Decimal = Field(default=Decimal("0"), ge=0)
    qualifying_fz_revenue: Decimal = Field(default=Decimal("0"), ge=0)
    deductible_expenses: Decimal = Field(default=Decimal("0"), ge=0)
    non_deductible_expenses: Decimal = Field(default=Decimal("0"), ge=0)
    withholding_tax_credit: Decimal = Field(default=Decimal("0"), ge=0)


class UaeCtFilingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    fiscal_year: int
    period_start: date
    period_end: date
    gross_revenue: Decimal
    taxable_revenue: Decimal
    exempt_revenue: Decimal
    qualifying_fz_revenue: Decimal
    deductible_expenses: Decimal
    non_deductible_expenses: Decimal
    taxable_income_before_limits: Decimal
    exempt_amount: Decimal
    taxable_income_after_exempt: Decimal
    ct_rate_pct: Decimal
    ct_amount: Decimal
    withholding_tax_credit: Decimal
    net_ct_payable: Decimal
    status: str
    submitted_at: Optional[datetime]
    fta_reference: Optional[str]


# ──────────────────────────────────────────────────────────────────────────
# VAT Return
# ──────────────────────────────────────────────────────────────────────────

class VatReturnGenerate(BaseModel):
    entity_id: str
    year: int = Field(..., ge=2020)
    period_number: int = Field(..., ge=1, le=12)
    period_type: str = Field("quarterly", pattern="^(monthly|quarterly)$")


class VatReturnRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    country: str
    period_type: str
    year: int
    period_number: int
    period_start: date
    period_end: date
    standard_rated_sales: Decimal
    zero_rated_sales: Decimal
    exempt_sales: Decimal
    output_vat: Decimal
    standard_rated_purchases: Decimal
    imports: Decimal
    input_vat: Decimal
    net_vat_payable: Decimal
    status: str
    submitted_at: Optional[datetime]
    authority_reference: Optional[str]
