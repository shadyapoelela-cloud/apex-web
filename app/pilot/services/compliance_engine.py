"""محرّك الامتثال — GOSI + WPS SIF + UAE CT + VAT Return."""

from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
from calendar import monthrange

from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from app.pilot.models import (
    Entity,
    GosiRegistration, GosiContribution, GosiEmployeeType,
    WpsBatch, WpsSifRecord, WpsStatus,
    UaeCtFiling, UaeCtClassification,
    VatReturn, VatReturnStatus,
    GLAccount, GLPosting,
)


Q2 = Decimal("0.01")


def q2(x) -> Decimal:
    if x is None:
        return Decimal("0")
    return Decimal(str(x)).quantize(Q2, rounding=ROUND_HALF_UP)


# ══════════════════════════════════════════════════════════════════════════
# GOSI
# ══════════════════════════════════════════════════════════════════════════

# نسب GOSI السعودية 2026
GOSI_RATES = {
    "saudi": {
        "employee_pct": Decimal("9.75"),          # الموظف
        "employer_pct": Decimal("11.75"),         # صاحب العمل (بدون إصابات عمل)
        "occupational_hazards_pct": Decimal("0"),  # مشمول بالـ 11.75
        # الحدود: 1500 ≤ الأساس ≤ 45000
        "min_wage": Decimal("1500"),
        "max_wage": Decimal("45000"),
    },
    "non_saudi": {
        "employee_pct": Decimal("0"),
        "employer_pct": Decimal("0"),
        "occupational_hazards_pct": Decimal("2"),
        "min_wage": Decimal("400"),
        "max_wage": Decimal("45000"),
    },
}


def calculate_gosi_contribution(
    registration: GosiRegistration, wage: Decimal,
) -> dict:
    """يحسب اشتراك GOSI الشهري."""
    rates = GOSI_RATES.get(
        "saudi" if registration.is_saudi else "non_saudi",
        GOSI_RATES["non_saudi"],
    )
    capped_wage = max(rates["min_wage"], min(wage, rates["max_wage"]))

    employee = q2(capped_wage * rates["employee_pct"] / Decimal("100"))
    employer = q2(capped_wage * rates["employer_pct"] / Decimal("100"))
    hazards = q2(capped_wage * rates["occupational_hazards_pct"] / Decimal("100"))
    total = employee + employer + hazards

    return {
        "contribution_wage": capped_wage,
        "employee_contribution": employee,
        "employer_contribution": employer,
        "occupational_hazards": hazards,
        "total_contribution": total,
    }


def record_gosi_contribution(
    db: Session, *, registration_id: str, year: int, month: int, wage: Decimal,
) -> GosiContribution:
    """يسجّل اشتراك شهري — idempotent."""
    reg = db.query(GosiRegistration).filter(GosiRegistration.id == registration_id).first()
    if not reg:
        raise ValueError("تسجيل GOSI غير موجود")
    existing = db.query(GosiContribution).filter(
        GosiContribution.registration_id == registration_id,
        GosiContribution.year == year,
        GosiContribution.month == month,
    ).first()
    if existing:
        return existing

    calc = calculate_gosi_contribution(reg, wage)
    contrib = GosiContribution(
        tenant_id=reg.tenant_id,
        registration_id=registration_id,
        year=year,
        month=month,
        **calc,
        status="calculated",
    )
    db.add(contrib)
    db.flush()
    return contrib


# ══════════════════════════════════════════════════════════════════════════
# WPS SIF file generation
# ══════════════════════════════════════════════════════════════════════════

def generate_sif_content(batch: WpsBatch, records: list[WpsSifRecord]) -> str:
    """يولّد محتوى ملف SIF بصيغة البنك المركزي السعودي (SAMA).

    الصيغة: pipe-separated لكل سطر
      Header (EDR): عدد السجلات، الإجمالي، ...
      Employee records (EDR): سطر لكل موظف
      Trailer (TLR): ختم

    مبسّطة للأغراض التجريبية — الصيغة الفعلية تتبع مواصفات SAMA/البنك.
    """
    lines = []

    # Header
    lines.append("|".join([
        "SCR",  # Salary Credit Record (header)
        batch.employer_establishment_id,
        batch.employer_bank_code,
        batch.employer_account_iban,
        f"{batch.year}{batch.month:02d}",
        f"{len(records):05d}",
        f"{float(batch.total_net):.2f}",
        "SAR",
    ]))

    # Employee records
    for i, rec in enumerate(records, start=1):
        lines.append("|".join([
            "EDR",  # Employee Detail Record
            f"{i:05d}",
            rec.national_id,
            rec.employee_name_ar[:50],  # قص إلى 50 حرف
            rec.employee_bank_code,
            rec.employee_account_iban,
            f"{float(rec.basic_salary):.2f}",
            f"{float(rec.housing_allowance):.2f}",
            f"{float(rec.transport_allowance):.2f}",
            f"{float(rec.other_allowances):.2f}",
            f"{float(rec.gross_salary):.2f}",
            f"{float(rec.gosi_deduction):.2f}",
            f"{float(rec.other_deductions):.2f}",
            f"{float(rec.net_salary):.2f}",
        ]))

    # Trailer
    lines.append("|".join([
        "TLR",
        f"{len(records):05d}",
        f"{float(batch.total_basic):.2f}",
        f"{float(batch.total_net):.2f}",
    ]))

    return "\r\n".join(lines)


def create_wps_batch(
    db: Session, *, entity: Entity, year: int, month: int,
    employer_bank_code: str, employer_account_iban: str,
    employer_establishment_id: str,
    employees: list[dict],
) -> WpsBatch:
    """ينشئ دفعة WPS + السجلات + يولّد SIF."""
    if entity.country != "SA":
        raise ValueError("WPS خاص بالسعودية فقط")

    # idempotency
    existing = db.query(WpsBatch).filter(
        WpsBatch.entity_id == entity.id,
        WpsBatch.year == year,
        WpsBatch.month == month,
    ).first()
    if existing:
        raise ValueError(f"توجد دفعة مسبقاً لـ {year}-{month:02d}")

    batch = WpsBatch(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        year=year,
        month=month,
        employer_bank_code=employer_bank_code,
        employer_account_iban=employer_account_iban,
        employer_establishment_id=employer_establishment_id,
        employee_count=len(employees),
        status=WpsStatus.draft.value,
    )
    db.add(batch)
    db.flush()

    total_basic = Decimal("0")
    total_housing = Decimal("0")
    total_transport = Decimal("0")
    total_other = Decimal("0")
    total_deductions = Decimal("0")
    total_net = Decimal("0")

    records: list[WpsSifRecord] = []
    for emp in employees:
        basic = q2(emp.get("basic_salary", 0))
        housing = q2(emp.get("housing_allowance", 0))
        transport = q2(emp.get("transport_allowance", 0))
        other = q2(emp.get("other_allowances", 0))
        gross = basic + housing + transport + other
        gosi = q2(emp.get("gosi_deduction", 0))
        other_ded = q2(emp.get("other_deductions", 0))
        net = gross - gosi - other_ded

        rec = WpsSifRecord(
            tenant_id=entity.tenant_id,
            batch_id=batch.id,
            employee_user_id=emp["employee_user_id"],
            employee_name_ar=emp["employee_name_ar"],
            national_id=emp["national_id"],
            employee_bank_code=emp["employee_bank_code"],
            employee_account_iban=emp["employee_account_iban"],
            basic_salary=basic,
            housing_allowance=housing,
            transport_allowance=transport,
            other_allowances=other,
            gross_salary=gross,
            gosi_deduction=gosi,
            other_deductions=other_ded,
            net_salary=net,
        )
        db.add(rec)
        records.append(rec)

        total_basic += basic
        total_housing += housing
        total_transport += transport
        total_other += other
        total_deductions += (gosi + other_ded)
        total_net += net

    batch.total_basic = total_basic
    batch.total_housing = total_housing
    batch.total_transport = total_transport
    batch.total_other = total_other
    batch.total_deductions = total_deductions
    batch.total_net = total_net

    # توليد SIF
    db.flush()
    batch.sif_file_content = generate_sif_content(batch, records)
    batch.sif_file_name = f"WPS_{entity.code}_{year}{month:02d}.sif"
    batch.sif_generated_at = datetime.now(timezone.utc)
    batch.status = WpsStatus.generated.value

    db.flush()
    return batch


# ══════════════════════════════════════════════════════════════════════════
# UAE Corporate Tax calculation
# ══════════════════════════════════════════════════════════════════════════

UAE_CT_EXEMPT_THRESHOLD = Decimal("375000")
UAE_CT_RATE = Decimal("9")


def calculate_uae_ct(
    *, gross_revenue: Decimal, exempt_revenue: Decimal = Decimal("0"),
    qualifying_fz_revenue: Decimal = Decimal("0"),
    deductible_expenses: Decimal = Decimal("0"),
    withholding_credit: Decimal = Decimal("0"),
) -> dict:
    """يحسب ضريبة الشركات الإماراتية وفق قانون 2023."""
    taxable_revenue = gross_revenue - exempt_revenue - qualifying_fz_revenue
    taxable_income_before = taxable_revenue - deductible_expenses
    if taxable_income_before < 0:
        taxable_income_before = Decimal("0")

    taxable_after_exempt = max(Decimal("0"), taxable_income_before - UAE_CT_EXEMPT_THRESHOLD)
    ct_amount = q2(taxable_after_exempt * UAE_CT_RATE / Decimal("100"))
    net_payable = max(Decimal("0"), ct_amount - withholding_credit)

    return {
        "gross_revenue": q2(gross_revenue),
        "taxable_revenue": q2(taxable_revenue),
        "exempt_revenue": q2(exempt_revenue),
        "qualifying_fz_revenue": q2(qualifying_fz_revenue),
        "deductible_expenses": q2(deductible_expenses),
        "taxable_income_before_limits": q2(taxable_income_before),
        "exempt_amount": UAE_CT_EXEMPT_THRESHOLD,
        "taxable_income_after_exempt": q2(taxable_after_exempt),
        "ct_rate_pct": UAE_CT_RATE,
        "ct_amount": ct_amount,
        "withholding_tax_credit": q2(withholding_credit),
        "net_ct_payable": q2(net_payable),
    }


def create_uae_ct_filing(
    db: Session, *, entity: Entity, fiscal_year: int,
    inputs: dict, submitted_by_user_id: Optional[str] = None,
) -> UaeCtFiling:
    """ينشئ إقرار UAE CT لسنة مالية."""
    if entity.country != "AE":
        raise ValueError("UAE CT خاص بالإمارات فقط")
    existing = db.query(UaeCtFiling).filter(
        UaeCtFiling.entity_id == entity.id,
        UaeCtFiling.fiscal_year == fiscal_year,
    ).first()
    if existing:
        raise ValueError(f"توجد إقرار مسبق للسنة {fiscal_year}")

    calc = calculate_uae_ct(
        gross_revenue=Decimal(str(inputs.get("gross_revenue", 0))),
        exempt_revenue=Decimal(str(inputs.get("exempt_revenue", 0))),
        qualifying_fz_revenue=Decimal(str(inputs.get("qualifying_fz_revenue", 0))),
        deductible_expenses=Decimal(str(inputs.get("deductible_expenses", 0))),
        withholding_credit=Decimal(str(inputs.get("withholding_tax_credit", 0))),
    )

    filing = UaeCtFiling(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        fiscal_year=fiscal_year,
        period_start=date(fiscal_year, 1, 1),
        period_end=date(fiscal_year, 12, 31),
        non_deductible_expenses=Decimal(str(inputs.get("non_deductible_expenses", 0))),
        **calc,
        status="draft",
    )
    db.add(filing)
    db.flush()
    return filing


# ══════════════════════════════════════════════════════════════════════════
# VAT Return — يُحسب من GL Postings تلقائياً
# ══════════════════════════════════════════════════════════════════════════

def compute_vat_return(
    db: Session, *, entity: Entity, year: int, period_number: int,
    period_type: str = "quarterly",
) -> dict:
    """يحسب إقرار VAT من GL Postings لفترة محدّدة.

    يبحث عن:
      • 4100 Sales           → standard_rated_sales
      • 2120 VAT Output      → output_vat
      • 1150 VAT Input       → input_vat
    """
    if period_type == "quarterly":
        start_month = (period_number - 1) * 3 + 1
        end_month = start_month + 2
        period_start = date(year, start_month, 1)
        _, last_day = monthrange(year, end_month)
        period_end = date(year, end_month, last_day)
    else:  # monthly
        period_start = date(year, period_number, 1)
        _, last_day = monthrange(year, period_number)
        period_end = date(year, period_number, last_day)

    def _account_total(code: str) -> dict:
        acc = db.query(GLAccount).filter(
            GLAccount.entity_id == entity.id, GLAccount.code == code
        ).first()
        if not acc:
            return {"debit": Decimal("0"), "credit": Decimal("0")}
        row = db.query(
            func.coalesce(func.sum(GLPosting.debit_amount), 0),
            func.coalesce(func.sum(GLPosting.credit_amount), 0),
        ).filter(
            GLPosting.account_id == acc.id,
            GLPosting.posting_date >= period_start,
            GLPosting.posting_date <= period_end,
        ).one()
        return {
            "debit": Decimal(str(row[0] or 0)),
            "credit": Decimal(str(row[1] or 0)),
        }

    # المبيعات — الرصيد الدائن
    sales = _account_total("4100")
    standard_rated_sales = sales["credit"] - sales["debit"]

    # VAT Output — رصيد دائن
    vat_out = _account_total("2120")
    output_vat = vat_out["credit"] - vat_out["debit"]

    # VAT Input — رصيد مدين
    vat_in = _account_total("1150")
    input_vat = vat_in["debit"] - vat_in["credit"]

    # zero-rated (نفترض نصيب من 4300 أو account آخر إن وُجد)
    zero_rated = Decimal("0")
    exempt_sales = Decimal("0")

    # المشتريات (لو كان هناك حساب مستقل، نستخدمه — الآن نفترض صفر لأن POS لا يلمس المشتريات)
    standard_rated_purchases = Decimal("0")

    net_payable = output_vat - input_vat

    return {
        "country": entity.country,
        "year": year,
        "period_number": period_number,
        "period_type": period_type,
        "period_start": period_start,
        "period_end": period_end,
        "standard_rated_sales": q2(standard_rated_sales),
        "zero_rated_sales": q2(zero_rated),
        "exempt_sales": q2(exempt_sales),
        "output_vat": q2(output_vat),
        "standard_rated_purchases": q2(standard_rated_purchases),
        "imports": Decimal("0"),
        "input_vat": q2(input_vat),
        "net_vat_payable": q2(net_payable),
    }


def create_vat_return(
    db: Session, *, entity: Entity, year: int, period_number: int,
    period_type: str = "quarterly",
) -> VatReturn:
    """يُنشئ إقرار VAT — idempotent."""
    existing = db.query(VatReturn).filter(
        VatReturn.entity_id == entity.id,
        VatReturn.year == year,
        VatReturn.period_number == period_number,
    ).first()
    if existing:
        return existing

    calc = compute_vat_return(db, entity=entity, year=year,
                              period_number=period_number, period_type=period_type)
    vr = VatReturn(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        **calc,
        status=VatReturnStatus.draft.value,
    )
    db.add(vr)
    db.flush()
    return vr
