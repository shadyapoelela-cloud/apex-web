"""نماذج الامتثال الضريبي والتنظيمي — ZATCA, UAE CT, GOSI, WPS.

الهيكل:

  ZATCA (هيئة الزكاة والضريبة والجمارك — السعودية)
    • ZatcaOnboarding     — تسجيل CSID/CSR للكيان في بيئة portal أو production
    • ZatcaInvoiceSubmission — سجل كل فاتورة وُلّد لها QR/hash (من POS أو sales)

  UAE CT (الضريبة على الشركات الإماراتية — 9%)
    • UaeCtFiling         — إقرار ضريبة شركات سنوي
    • UaeCtTransaction    — تصنيف كل معاملة (taxable / exempt / qualifying free zone)

  GOSI (التأمينات الاجتماعية السعودية)
    • GosiRegistration    — تسجيل الموظف (سعودي / غير سعودي)
    • GosiContribution    — الاشتراك الشهري لكل موظف

  WPS (نظام حماية الأجور — السعودية)
    • WpsBatch            — دفعة رواتب شهرية
    • WpsSifRecord        — سجل في ملف SIF (Standard Interchange File)

VAT Return:
    • VatReturn           — إقرار VAT ربع سنوي (جميع الدول الخليجية)
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, Date, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ──────────────────────────────────────────────────────────────────────────
# Enums
# ──────────────────────────────────────────────────────────────────────────

class ZatcaEnvironment(str, enum.Enum):
    developer_portal = "developer_portal"   # المطوّرين (تجريبي)
    simulation = "simulation"                # محاكاة (قبل الإنتاج)
    production = "production"                # الإنتاج الفعلي


class ZatcaInvoiceKind(str, enum.Enum):
    standard = "standard"        # فاتورة ضريبية (B2B)
    simplified = "simplified"    # فاتورة مبسطة (B2C من POS)


class ZatcaSubmissionStatus(str, enum.Enum):
    pending = "pending"          # لم تُرسل بعد
    submitted = "submitted"      # أُرسلت للـ ZATCA
    accepted = "accepted"        # قُبلت
    rejected = "rejected"        # رُفضت — تحتاج مراجعة
    reported = "reported"        # بلَّغ عنها (simplified mode)
    cleared = "cleared"          # مُخلَّصة (standard mode — قبل الإرسال للعميل)
    failed = "failed"            # فشل تقني


class UaeCtClassification(str, enum.Enum):
    taxable = "taxable"
    exempt = "exempt"
    qualifying_free_zone = "qualifying_free_zone"
    out_of_scope = "out_of_scope"


class GosiEmployeeType(str, enum.Enum):
    saudi = "saudi"                    # سعودي — 9.75% موظف + 12% صاحب عمل
    non_saudi = "non_saudi"            # غير سعودي — 2% صاحب عمل (إصابات عمل)
    saudi_high_risk = "saudi_high_risk"  # مهن خطرة — معدلات أعلى


class WpsStatus(str, enum.Enum):
    draft = "draft"
    generated = "generated"       # ملف SIF وُلّد
    submitted = "submitted"       # أُرسل للبنك
    processed = "processed"       # البنك عالج الدفعات
    rejected = "rejected"
    partially_paid = "partially_paid"


class VatReturnStatus(str, enum.Enum):
    draft = "draft"
    submitted = "submitted"
    accepted = "accepted"
    amended = "amended"


# ──────────────────────────────────────────────────────────────────────────
# ZATCA
# ──────────────────────────────────────────────────────────────────────────

class ZatcaOnboarding(Base):
    """تسجيل CSID/CSR لكل كيان سعودي في بيئة ZATCA."""
    __tablename__ = "pilot_zatca_onboarding"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    environment = Column(String(30), nullable=False, default=ZatcaEnvironment.developer_portal.value)

    # CSR (Certificate Signing Request)
    csr_pem = Column(Text, nullable=True)
    csr_otp = Column(String(50), nullable=True)          # OTP من Fatoora portal
    csr_submitted_at = Column(DateTime(timezone=True), nullable=True)

    # CSID (Cryptographic Stamp Identifier)
    csid = Column(String(64), nullable=True, index=True)
    csid_certificate_pem = Column(Text, nullable=True)
    csid_private_key_encrypted = Column(Text, nullable=True)  # Fernet-encrypted
    csid_issued_at = Column(DateTime(timezone=True), nullable=True)
    csid_expires_at = Column(DateTime(timezone=True), nullable=True)

    # Invoice Counter (ICV) — يجب أن يكون تسلسلياً متصاعداً بلا فجوات
    invoice_counter = Column(Integer, nullable=False, default=0)

    # PIH = Previous Invoice Hash — لسلسلة التجزئة
    previous_invoice_hash = Column(String(128), nullable=True)

    # Compliance config
    vat_registration_number = Column(String(50), nullable=True)  # 15-digit
    cr_number = Column(String(50), nullable=True)

    status = Column(String(30), nullable=False, default="pending")  # pending|onboarded|active|expired|revoked

    last_status_check_at = Column(DateTime(timezone=True), nullable=True)
    last_error = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("entity_id", "environment", name="uq_pilot_zatca_onb_entity_env"),
        Index("ix_pilot_zatca_onb_status", "status"),
    )


class ZatcaInvoiceSubmission(Base):
    """سجل كل فاتورة وُلّد لها QR + hash + تم إرسالها (أو ستُرسل) لـ ZATCA."""
    __tablename__ = "pilot_zatca_submissions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    onboarding_id = Column(String(36), ForeignKey("pilot_zatca_onboarding.id", ondelete="RESTRICT"), nullable=False)

    # الربط العكسي
    source_type = Column(String(40), nullable=False)   # pos_txn | sales_invoice | credit_note
    source_id = Column(String(36), nullable=False)
    source_reference = Column(String(100), nullable=False)  # receipt_number / invoice_number

    # ZATCA identifiers
    invoice_kind = Column(String(20), nullable=False)   # standard | simplified
    invoice_uuid = Column(String(64), nullable=False, unique=True)   # UUIDv4
    invoice_counter = Column(Integer, nullable=False)                # ICV
    invoice_hash = Column(String(128), nullable=False)               # base64 SHA-256
    previous_invoice_hash = Column(String(128), nullable=True)       # PIH

    # QR code (Base64 TLV per ZATCA spec)
    qr_tlv_base64 = Column(Text, nullable=False)

    # XML (for standard invoices — UBL 2.1)
    xml_signed = Column(Text, nullable=True)

    # Amounts (denormalized for reporting without joins)
    total_excl_vat = Column(Numeric(18, 2), nullable=False, default=0)
    total_vat = Column(Numeric(18, 2), nullable=False, default=0)
    total_incl_vat = Column(Numeric(18, 2), nullable=False, default=0)

    # Submission
    status = Column(String(30), nullable=False, default=ZatcaSubmissionStatus.pending.value)
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    response_json = Column(JSON, nullable=True)
    zatca_uuid_ack = Column(String(64), nullable=True)    # UUID من ZATCA (عادة = invoice_uuid)

    # Warnings / errors
    warnings = Column(JSON, nullable=True)
    errors = Column(JSON, nullable=True)
    retry_count = Column(Integer, nullable=False, default=0)
    last_retry_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("entity_id", "invoice_counter", name="uq_pilot_zatca_entity_icv"),
        Index("ix_pilot_zatca_sub_source", "source_type", "source_id"),
        Index("ix_pilot_zatca_sub_status", "status"),
    )


# ──────────────────────────────────────────────────────────────────────────
# UAE Corporate Tax
# ──────────────────────────────────────────────────────────────────────────

class UaeCtFiling(Base):
    """إقرار ضريبة شركات إماراتية سنوي."""
    __tablename__ = "pilot_uae_ct_filings"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    fiscal_year = Column(Integer, nullable=False)
    period_start = Column(Date, nullable=False)
    period_end = Column(Date, nullable=False)

    # الإيرادات والخصومات
    gross_revenue = Column(Numeric(18, 2), nullable=False, default=0)
    taxable_revenue = Column(Numeric(18, 2), nullable=False, default=0)
    exempt_revenue = Column(Numeric(18, 2), nullable=False, default=0)  # e.g., dividends
    qualifying_fz_revenue = Column(Numeric(18, 2), nullable=False, default=0)

    # المصروفات القابلة للخصم
    deductible_expenses = Column(Numeric(18, 2), nullable=False, default=0)
    non_deductible_expenses = Column(Numeric(18, 2), nullable=False, default=0)

    # الدخل الخاضع
    taxable_income_before_limits = Column(Numeric(18, 2), nullable=False, default=0)

    # الإعفاء — أول 375,000 AED @ 0% ثم 9% على الباقي
    exempt_amount = Column(Numeric(18, 2), nullable=False, default=375000)
    taxable_income_after_exempt = Column(Numeric(18, 2), nullable=False, default=0)

    # الضريبة المستحقة
    ct_rate_pct = Column(Numeric(6, 3), nullable=False, default=9)
    ct_amount = Column(Numeric(18, 2), nullable=False, default=0)

    # خصومات ضريبية (إن وُجدت)
    withholding_tax_credit = Column(Numeric(18, 2), nullable=False, default=0)
    net_ct_payable = Column(Numeric(18, 2), nullable=False, default=0)

    status = Column(String(20), nullable=False, default="draft")  # draft|submitted|accepted|amended
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    submitted_by_user_id = Column(String(36), nullable=True)
    fta_reference = Column(String(100), nullable=True)   # FTA submission reference

    notes = Column(Text, nullable=True)
    extras = Column(JSON, nullable=False, default=dict)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("entity_id", "fiscal_year", name="uq_pilot_uae_ct_entity_year"),
    )


# ──────────────────────────────────────────────────────────────────────────
# GOSI (Saudi social insurance)
# ──────────────────────────────────────────────────────────────────────────

class GosiRegistration(Base):
    """تسجيل موظف في التأمينات الاجتماعية."""
    __tablename__ = "pilot_gosi_registrations"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    # هوية الموظف
    employee_user_id = Column(String(36), nullable=False, index=True)
    employee_number = Column(String(50), nullable=False)
    national_id = Column(String(20), nullable=False)          # رقم الهوية/الإقامة
    employee_name_ar = Column(String(255), nullable=False)

    # التصنيف
    employee_type = Column(String(30), nullable=False)        # see GosiEmployeeType
    is_saudi = Column(Boolean, nullable=False, default=False)

    # التسجيل
    gosi_subscriber_number = Column(String(50), nullable=True, index=True)  # رقم الاشتراك
    registered_at = Column(Date, nullable=False)
    deregistered_at = Column(Date, nullable=True)

    # الأساس التأميني
    contribution_wage = Column(Numeric(18, 2), nullable=False)  # أساس الاشتراك

    # النسب
    employee_rate_pct = Column(Numeric(6, 3), nullable=False, default=0)   # 9.75 للسعودي
    employer_rate_pct = Column(Numeric(6, 3), nullable=False, default=0)   # 12 للسعودي
    occupational_hazards_rate_pct = Column(Numeric(6, 3), nullable=False, default=2)  # لغير السعودي

    is_active = Column(Boolean, nullable=False, default=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("entity_id", "employee_user_id", name="uq_pilot_gosi_entity_employee"),
        Index("ix_pilot_gosi_subscriber", "gosi_subscriber_number"),
    )


class GosiContribution(Base):
    """اشتراك GOSI شهري لموظف."""
    __tablename__ = "pilot_gosi_contributions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    registration_id = Column(String(36), ForeignKey("pilot_gosi_registrations.id", ondelete="CASCADE"), nullable=False, index=True)

    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)

    contribution_wage = Column(Numeric(18, 2), nullable=False)
    employee_contribution = Column(Numeric(18, 2), nullable=False, default=0)
    employer_contribution = Column(Numeric(18, 2), nullable=False, default=0)
    occupational_hazards = Column(Numeric(18, 2), nullable=False, default=0)
    total_contribution = Column(Numeric(18, 2), nullable=False, default=0)

    status = Column(String(20), nullable=False, default="calculated")  # calculated|submitted|paid
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    payment_reference = Column(String(100), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("registration_id", "year", "month", name="uq_pilot_gosi_contrib_unique"),
        Index("ix_pilot_gosi_contrib_period", "year", "month"),
    )


# ──────────────────────────────────────────────────────────────────────────
# WPS (Wage Protection System)
# ──────────────────────────────────────────────────────────────────────────

class WpsBatch(Base):
    """دفعة رواتب شهرية ترسل عبر WPS."""
    __tablename__ = "pilot_wps_batches"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)

    # تفاصيل الحساب البنكي للمرسل
    employer_bank_code = Column(String(20), nullable=False)
    employer_account_iban = Column(String(34), nullable=False)
    employer_establishment_id = Column(String(50), nullable=False)  # الرقم الموحد للمنشأة

    # الإجماليات
    employee_count = Column(Integer, nullable=False, default=0)
    total_basic = Column(Numeric(18, 2), nullable=False, default=0)
    total_housing = Column(Numeric(18, 2), nullable=False, default=0)
    total_transport = Column(Numeric(18, 2), nullable=False, default=0)
    total_other = Column(Numeric(18, 2), nullable=False, default=0)
    total_deductions = Column(Numeric(18, 2), nullable=False, default=0)
    total_net = Column(Numeric(18, 2), nullable=False, default=0)

    # حالة الدفعة
    status = Column(String(20), nullable=False, default=WpsStatus.draft.value)
    sif_file_content = Column(Text, nullable=True)        # ملف SIF كامل
    sif_file_name = Column(String(100), nullable=True)    # WPS_YYYYMM.sif
    sif_generated_at = Column(DateTime(timezone=True), nullable=True)

    submitted_at = Column(DateTime(timezone=True), nullable=True)
    processed_at = Column(DateTime(timezone=True), nullable=True)
    bank_reference = Column(String(100), nullable=True)
    rejection_reason = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    records = relationship("WpsSifRecord", back_populates="batch", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("entity_id", "year", "month", name="uq_pilot_wps_entity_period"),
    )


class WpsSifRecord(Base):
    """سطر موظف واحد في ملف SIF."""
    __tablename__ = "pilot_wps_sif_records"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    batch_id = Column(String(36), ForeignKey("pilot_wps_batches.id", ondelete="CASCADE"), nullable=False, index=True)

    employee_user_id = Column(String(36), nullable=False)
    employee_name_ar = Column(String(255), nullable=False)
    national_id = Column(String(20), nullable=False)

    # حساب الموظف
    employee_bank_code = Column(String(20), nullable=False)
    employee_account_iban = Column(String(34), nullable=False)

    # مكوّنات الراتب
    basic_salary = Column(Numeric(18, 2), nullable=False, default=0)
    housing_allowance = Column(Numeric(18, 2), nullable=False, default=0)
    transport_allowance = Column(Numeric(18, 2), nullable=False, default=0)
    other_allowances = Column(Numeric(18, 2), nullable=False, default=0)
    gross_salary = Column(Numeric(18, 2), nullable=False, default=0)

    # استقطاعات
    gosi_deduction = Column(Numeric(18, 2), nullable=False, default=0)
    other_deductions = Column(Numeric(18, 2), nullable=False, default=0)
    net_salary = Column(Numeric(18, 2), nullable=False, default=0)

    # حالة الدفع
    status = Column(String(20), nullable=False, default="pending")  # pending|paid|rejected
    paid_at = Column(DateTime(timezone=True), nullable=True)
    rejection_code = Column(String(20), nullable=True)
    rejection_reason = Column(String(255), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    batch = relationship("WpsBatch", back_populates="records")

    __table_args__ = (
        Index("ix_pilot_wps_sif_batch_employee", "batch_id", "employee_user_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# VAT Return (quarterly — SA/AE/BH/OM)
# ──────────────────────────────────────────────────────────────────────────

class VatReturn(Base):
    """إقرار VAT ربع سنوي (أو شهري لبعض الدول)."""
    __tablename__ = "pilot_vat_returns"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    country = Column(String(2), nullable=False)           # SA, AE, BH, OM
    period_type = Column(String(20), nullable=False, default="quarterly")  # monthly|quarterly
    year = Column(Integer, nullable=False)
    period_number = Column(Integer, nullable=False)       # Q1..Q4 أو 1..12
    period_start = Column(Date, nullable=False)
    period_end = Column(Date, nullable=False)

    # Output VAT (من المبيعات)
    standard_rated_sales = Column(Numeric(18, 2), nullable=False, default=0)
    zero_rated_sales = Column(Numeric(18, 2), nullable=False, default=0)
    exempt_sales = Column(Numeric(18, 2), nullable=False, default=0)
    output_vat = Column(Numeric(18, 2), nullable=False, default=0)

    # Input VAT (من المشتريات)
    standard_rated_purchases = Column(Numeric(18, 2), nullable=False, default=0)
    imports = Column(Numeric(18, 2), nullable=False, default=0)
    input_vat = Column(Numeric(18, 2), nullable=False, default=0)

    # الناتج
    net_vat_payable = Column(Numeric(18, 2), nullable=False, default=0)  # إن كان موجب → دفع، سالب → استرداد

    status = Column(String(20), nullable=False, default=VatReturnStatus.draft.value)
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    submitted_by_user_id = Column(String(36), nullable=True)
    authority_reference = Column(String(100), nullable=True)  # ZATCA/FTA reference

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("entity_id", "year", "period_number", name="uq_pilot_vat_entity_period"),
    )
