"""مسارات الامتثال — ZATCA + UAE CT + GOSI + WPS + VAT Return."""

from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import PlainTextResponse
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.phase1.routes.phase1_routes import get_current_user
from app.pilot.security import assert_entity_in_tenant
from app.pilot.models import (
    Entity, PosTransaction,
    ZatcaOnboarding, ZatcaInvoiceSubmission,
    GosiRegistration, GosiContribution,
    WpsBatch, WpsSifRecord,
    UaeCtFiling, VatReturn,
)
from app.pilot.schemas.compliance import (
    ZatcaOnboardingRead, ZatcaSubmissionRead, QrDecodeResponse,
    GosiRegistrationCreate, GosiRegistrationRead,
    GosiContributionCalc, GosiContributionRead,
    WpsBatchCreate, WpsBatchRead, WpsBatchDetail, WpsSifRecordRead,
    UaeCtFilingCreate, UaeCtFilingRead,
    VatReturnGenerate, VatReturnRead,
)
from app.pilot.services.zatca_engine import (
    create_or_get_onboarding, simulate_csid_issuance,
    submit_pos_invoice, decode_qr_tlv,
)
from app.pilot.services.compliance_engine import (
    calculate_gosi_contribution, record_gosi_contribution,
    GOSI_RATES,
    create_wps_batch,
    calculate_uae_ct, create_uae_ct_filing,
    compute_vat_return, create_vat_return,
)

# G-S9 (Sprint 14): router-level auth dependency. See 09 § 20.1 G-S9.
router = APIRouter(
    prefix="/pilot",
    tags=["pilot-compliance"],
    dependencies=[Depends(get_current_user)],
)


def _entity_or_404(db: Session, eid: str, current_user: Optional[dict] = None) -> Entity:
    """Backward-compatible shim — delegates to ``assert_entity_in_tenant``.

    Pre-G-PILOT-REPORTS-TENANT-AUDIT this helper had **no** tenant
    check, leaving every route below it cross-tenant readable /
    writable. The helper now requires a ``current_user`` context for
    enforcement; callers pass the ``Depends(get_current_user)`` value
    through.
    """
    return assert_entity_in_tenant(db, eid, current_user)


# ══════════════════════════════════════════════════════════════════════════
# ZATCA
# ══════════════════════════════════════════════════════════════════════════

@router.post("/entities/{entity_id}/zatca/onboard", response_model=ZatcaOnboardingRead)
def zatca_onboard(
    entity_id: str,
    environment: str = Query("developer_portal", pattern="^(developer_portal|simulation|production)$"),
    simulate: bool = Query(True, description="إذا true، يُحاكي إصدار CSID"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = assert_entity_in_tenant(db, entity_id, current_user)
    if e.country != "SA":
        raise HTTPException(400, "ZATCA خاص بالسعودية")
    onb = create_or_get_onboarding(db, entity=e, environment=environment)
    if simulate and onb.status == "pending":
        onb = simulate_csid_issuance(db, onb)
    db.commit()
    db.refresh(onb)
    return onb


@router.get("/entities/{entity_id}/zatca/onboarding", response_model=list[ZatcaOnboardingRead])
def list_onboardings(
    entity_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    assert_entity_in_tenant(db, entity_id, current_user)
    return db.query(ZatcaOnboarding).filter(
        ZatcaOnboarding.entity_id == entity_id
    ).order_by(ZatcaOnboarding.created_at.desc()).all()


@router.post("/pos-transactions/{pos_txn_id}/zatca/submit", response_model=ZatcaSubmissionRead)
def submit_to_zatca(
    pos_txn_id: str,
    simulate: bool = Query(True),
    db: Session = Depends(get_db),
):
    """توليد QR + hash + إرسال (أو محاكاة إرسال) لـ ZATCA."""
    try:
        sub = submit_pos_invoice(db, pos_txn_id=pos_txn_id, simulate=simulate)
        db.commit()
        db.refresh(sub)
        return sub
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))


@router.get("/entities/{entity_id}/zatca/submissions", response_model=list[ZatcaSubmissionRead])
def list_zatca_submissions(
    entity_id: str,
    status: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    assert_entity_in_tenant(db, entity_id, current_user)
    q = db.query(ZatcaInvoiceSubmission).filter(
        ZatcaInvoiceSubmission.entity_id == entity_id
    )
    if status:
        q = q.filter(ZatcaInvoiceSubmission.status == status)
    return q.order_by(ZatcaInvoiceSubmission.invoice_counter.desc()).limit(limit).all()


@router.get("/zatca/decode-qr", response_model=QrDecodeResponse)
def decode_qr(qr: str = Query(..., description="QR TLV Base64")):
    """فك ترميز QR TLV (للتحقق من مسح الفاتورة)."""
    try:
        decoded = decode_qr_tlv(qr)
        return QrDecodeResponse(**{k: v for k, v in decoded.items() if k != "raw_tags"})
    except Exception as ex:
        raise HTTPException(400, f"فشل فك الترميز: {ex}")


# ══════════════════════════════════════════════════════════════════════════
# GOSI
# ══════════════════════════════════════════════════════════════════════════

@router.get("/gosi/rates")
def get_gosi_rates():
    """يُعيد نسب GOSI الحالية (للعرض في الواجهة)."""
    return {
        "saudi": {k: float(v) if hasattr(v, "to_integral_value") else v
                  for k, v in GOSI_RATES["saudi"].items()},
        "non_saudi": {k: float(v) if hasattr(v, "to_integral_value") else v
                      for k, v in GOSI_RATES["non_saudi"].items()},
    }


@router.post("/gosi/calculate")
def gosi_calculate(
    is_saudi: bool = Query(...),
    wage: Decimal = Query(..., gt=0),
):
    """حاسبة GOSI — بدون حفظ في قاعدة البيانات."""
    # بناء Registration وهمية للحساب
    fake = type("F", (), {"is_saudi": is_saudi})()
    calc = calculate_gosi_contribution(fake, wage)
    return {k: float(v) for k, v in calc.items()}


@router.post("/gosi/registrations", response_model=GosiRegistrationRead, status_code=201)
def create_gosi_registration(
    payload: GosiRegistrationCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = assert_entity_in_tenant(db, payload.entity_id, current_user)
    if e.country != "SA":
        raise HTTPException(400, "GOSI خاص بالسعودية")
    existing = db.query(GosiRegistration).filter(
        GosiRegistration.entity_id == payload.entity_id,
        GosiRegistration.employee_user_id == payload.employee_user_id,
    ).first()
    if existing:
        raise HTTPException(409, "الموظف مسجّل مسبقاً")

    emp_type = "saudi" if payload.is_saudi else "non_saudi"
    rates = GOSI_RATES[emp_type]
    reg = GosiRegistration(
        tenant_id=e.tenant_id,
        entity_id=payload.entity_id,
        employee_user_id=payload.employee_user_id,
        employee_number=payload.employee_number,
        national_id=payload.national_id,
        employee_name_ar=payload.employee_name_ar,
        employee_type=emp_type,
        is_saudi=payload.is_saudi,
        gosi_subscriber_number=payload.gosi_subscriber_number,
        registered_at=payload.registered_at,
        contribution_wage=payload.contribution_wage,
        employee_rate_pct=rates["employee_pct"],
        employer_rate_pct=rates["employer_pct"],
        occupational_hazards_rate_pct=rates["occupational_hazards_pct"],
    )
    db.add(reg)
    db.commit()
    db.refresh(reg)
    return reg


@router.post("/gosi/registrations/{registration_id}/contributions",
             response_model=GosiContributionRead, status_code=201)
def gosi_contribution(
    registration_id: str,
    payload: GosiContributionCalc,
    db: Session = Depends(get_db),
):
    try:
        c = record_gosi_contribution(
            db, registration_id=registration_id,
            year=payload.year, month=payload.month, wage=payload.wage,
        )
        db.commit()
        db.refresh(c)
        return c
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))


@router.get("/entities/{entity_id}/gosi/registrations", response_model=list[GosiRegistrationRead])
def list_gosi_registrations(
    entity_id: str,
    active_only: bool = Query(True),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    assert_entity_in_tenant(db, entity_id, current_user)
    q = db.query(GosiRegistration).filter(GosiRegistration.entity_id == entity_id)
    if active_only:
        q = q.filter(GosiRegistration.is_active == True)  # noqa: E712
    return q.order_by(GosiRegistration.employee_name_ar).all()


# ══════════════════════════════════════════════════════════════════════════
# WPS
# ══════════════════════════════════════════════════════════════════════════

@router.post("/wps/batches", response_model=WpsBatchDetail, status_code=201)
def create_wps(
    payload: WpsBatchCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = assert_entity_in_tenant(db, payload.entity_id, current_user)
    try:
        batch = create_wps_batch(
            db, entity=e,
            year=payload.year, month=payload.month,
            employer_bank_code=payload.employer_bank_code,
            employer_account_iban=payload.employer_account_iban,
            employer_establishment_id=payload.employer_establishment_id,
            employees=[emp.model_dump() for emp in payload.employees],
        )
        db.commit()
        db.refresh(batch)
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))

    records = db.query(WpsSifRecord).filter(WpsSifRecord.batch_id == batch.id).all()
    return WpsBatchDetail(
        **WpsBatchRead.model_validate(batch).model_dump(),
        sif_file_content=batch.sif_file_content,
        records=[WpsSifRecordRead.model_validate(r) for r in records],
    )


@router.get("/entities/{entity_id}/wps/batches", response_model=list[WpsBatchRead])
def list_wps_batches(
    entity_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    assert_entity_in_tenant(db, entity_id, current_user)
    return db.query(WpsBatch).filter(
        WpsBatch.entity_id == entity_id
    ).order_by(WpsBatch.year.desc(), WpsBatch.month.desc()).all()


@router.get("/wps/batches/{batch_id}/sif", response_class=PlainTextResponse)
def download_sif(batch_id: str, db: Session = Depends(get_db)):
    """تنزيل ملف SIF كـ plain text.

    NOTE: response_class must be PlainTextResponse (not None) — setting
    it to None breaks FastAPI's OpenAPI schema generator with
    `AssertionError: A response class is needed to generate OpenAPI`,
    which 500s /openapi.json across the whole API. Caught by
    scripts/post_deploy_check.sh on 2026-04-24.
    """
    batch = db.query(WpsBatch).filter(WpsBatch.id == batch_id).first()
    if not batch:
        raise HTTPException(404, "الدفعة غير موجودة")
    if not batch.sif_file_content:
        raise HTTPException(409, "لم يتم توليد ملف SIF بعد")
    return PlainTextResponse(
        batch.sif_file_content,
        media_type="text/plain; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{batch.sif_file_name}"'},
    )


# ══════════════════════════════════════════════════════════════════════════
# UAE CT
# ══════════════════════════════════════════════════════════════════════════

@router.post("/uae-ct/calculate")
def uae_ct_calc(
    gross_revenue: Decimal = Query(...),
    exempt_revenue: Decimal = Query(Decimal("0")),
    qualifying_fz_revenue: Decimal = Query(Decimal("0")),
    deductible_expenses: Decimal = Query(Decimal("0")),
    withholding_credit: Decimal = Query(Decimal("0")),
):
    """حاسبة UAE CT بدون حفظ."""
    calc = calculate_uae_ct(
        gross_revenue=gross_revenue,
        exempt_revenue=exempt_revenue,
        qualifying_fz_revenue=qualifying_fz_revenue,
        deductible_expenses=deductible_expenses,
        withholding_credit=withholding_credit,
    )
    return {k: float(v) for k, v in calc.items()}


@router.post("/uae-ct/filings", response_model=UaeCtFilingRead, status_code=201)
def create_ct_filing(
    payload: UaeCtFilingCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    e = assert_entity_in_tenant(db, payload.entity_id, current_user)
    try:
        filing = create_uae_ct_filing(
            db, entity=e, fiscal_year=payload.fiscal_year,
            inputs=payload.model_dump(exclude={"entity_id", "fiscal_year"}),
        )
        db.commit()
        db.refresh(filing)
        return filing
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))


@router.get("/entities/{entity_id}/uae-ct/filings", response_model=list[UaeCtFilingRead])
def list_ct_filings(
    entity_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    assert_entity_in_tenant(db, entity_id, current_user)
    return db.query(UaeCtFiling).filter(
        UaeCtFiling.entity_id == entity_id
    ).order_by(UaeCtFiling.fiscal_year.desc()).all()


# ══════════════════════════════════════════════════════════════════════════
# VAT Return
# ══════════════════════════════════════════════════════════════════════════

@router.post("/vat-returns/generate", response_model=VatReturnRead)
def generate_vat_return(
    payload: VatReturnGenerate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """يحسب إقرار VAT من GL Postings ويحفظه (idempotent)."""
    e = assert_entity_in_tenant(db, payload.entity_id, current_user)
    try:
        vr = create_vat_return(
            db, entity=e, year=payload.year,
            period_number=payload.period_number,
            period_type=payload.period_type,
        )
        db.commit()
        db.refresh(vr)
        return vr
    except ValueError as ex:
        db.rollback()
        raise HTTPException(400, str(ex))


@router.get("/vat-returns/preview")
def preview_vat_return(
    entity_id: str = Query(...),
    year: int = Query(...),
    period_number: int = Query(..., ge=1, le=12),
    period_type: str = Query("quarterly", pattern="^(monthly|quarterly)$"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """معاينة حسابات VAT Return بدون حفظ."""
    e = assert_entity_in_tenant(db, entity_id, current_user)
    result = compute_vat_return(
        db, entity=e, year=year, period_number=period_number, period_type=period_type,
    )
    return {k: (float(v) if isinstance(v, Decimal) else (v.isoformat() if isinstance(v, date) else v))
            for k, v in result.items()}


@router.get("/entities/{entity_id}/vat-returns", response_model=list[VatReturnRead])
def list_vat_returns(
    entity_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    assert_entity_in_tenant(db, entity_id, current_user)
    return db.query(VatReturn).filter(
        VatReturn.entity_id == entity_id
    ).order_by(VatReturn.year.desc(), VatReturn.period_number.desc()).all()
