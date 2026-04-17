"""HR module SQLAlchemy models — Saudi/UAE payroll-aware.

Tables:
  hr_employees
  hr_leave_requests
  hr_payroll_runs
  hr_payslips

Each table is tenant-scoped via tenant_id (nullable until the multi-tenant
layer is wired in — see Master Blueprint §16).
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ── Employee ─────────────────────────────────────────────────


class Employee(Base, TenantMixin):
    """Full employee record.

    Covers the minimum needed for Saudi & UAE payroll + GOSI + WPS:
      - national_id / iqama for KSA, emirates_id for UAE
      - salary broken down per component (Mudad compliance)
      - GOSI / pension details
    """

    __tablename__ = "hr_employees"
    __table_args__ = (
        UniqueConstraint("tenant_id", "employee_number", name="uq_hr_emp_tenant_num"),
    )

    id = Column(String(36), primary_key=True, default=_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    employee_number = Column(String(32), nullable=False, index=True)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)

    # KSA ids
    national_id = Column(String(20), nullable=True, index=True)
    iqama_number = Column(String(20), nullable=True, index=True)
    # UAE
    emirates_id = Column(String(20), nullable=True, index=True)

    nationality = Column(String(3), nullable=True)  # ISO 3166 alpha-3 (e.g. 'SAU')
    department = Column(String(100), nullable=True)
    job_title = Column(String(120), nullable=True)
    hire_date = Column(Date, nullable=False)
    termination_date = Column(Date, nullable=True)

    # Salary breakdown (all monthly, in SAR/AED)
    basic_salary = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    housing_allowance = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    transport_allowance = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    other_allowances = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))

    # Banking (WPS)
    bank_iban = Column(String(40), nullable=True)
    bank_name = Column(String(120), nullable=True)

    # GOSI / pension
    gosi_number = Column(String(32), nullable=True)
    gosi_applicable = Column(Boolean, nullable=False, default=True)
    gosi_employee_rate = Column(Numeric(5, 4), nullable=False, default=Decimal("0.1000"))  # 10%
    gosi_employer_rate = Column(Numeric(5, 4), nullable=False, default=Decimal("0.1200"))  # 12%

    status = Column(String(16), nullable=False, default="active", index=True)
    # active / terminated / on_leave

    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow)

    leave_requests = relationship(
        "LeaveRequest", back_populates="employee", cascade="all, delete-orphan"
    )
    payslips = relationship(
        "Payslip", back_populates="employee", cascade="all, delete-orphan"
    )

    @property
    def gross_salary(self) -> Decimal:
        return (
            self.basic_salary
            + self.housing_allowance
            + self.transport_allowance
            + self.other_allowances
        )


# ── Leave ────────────────────────────────────────────────────


class LeaveRequest(Base, TenantMixin):
    """A single leave request with approval workflow."""

    __tablename__ = "hr_leave_requests"

    id = Column(String(36), primary_key=True, default=_uuid)
    employee_id = Column(
        String(36),
        ForeignKey("hr_employees.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    leave_type = Column(String(20), nullable=False)
    # annual / sick / unpaid / hajj / maternity / bereavement

    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    days = Column(Integer, nullable=False)

    status = Column(String(16), nullable=False, default="pending", index=True)
    # pending / approved / rejected / cancelled

    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)

    reason = Column(Text, nullable=True)
    rejection_reason = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)

    employee = relationship("Employee", back_populates="leave_requests")


# ── Payroll ─────────────────────────────────────────────────


class PayrollRun(Base, TenantMixin):
    """One monthly payroll batch."""

    __tablename__ = "hr_payroll_runs"
    __table_args__ = (
        UniqueConstraint("tenant_id", "period", name="uq_hr_payroll_tenant_period"),
    )

    id = Column(String(36), primary_key=True, default=_uuid)

    period = Column(String(7), nullable=False, index=True)  # 'YYYY-MM'

    status = Column(String(16), nullable=False, default="draft", index=True)
    # draft / approved / paid / cancelled

    total_gross = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    total_deductions = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    total_net = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    employee_count = Column(Integer, nullable=False, default=0)

    wps_reference = Column(String(64), nullable=True)
    wps_file_url = Column(String(500), nullable=True)

    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)

    payslips = relationship(
        "Payslip", back_populates="payroll_run", cascade="all, delete-orphan"
    )


class Payslip(Base, TenantMixin):
    """Per-employee result of a payroll run."""

    __tablename__ = "hr_payslips"
    __table_args__ = (
        UniqueConstraint("payroll_run_id", "employee_id", name="uq_hr_payslip_run_emp"),
    )

    id = Column(String(36), primary_key=True, default=_uuid)

    payroll_run_id = Column(
        String(36), ForeignKey("hr_payroll_runs.id", ondelete="CASCADE"), nullable=False
    )
    employee_id = Column(
        String(36), ForeignKey("hr_employees.id", ondelete="CASCADE"), nullable=False
    )

    basic_salary = Column(Numeric(18, 2), nullable=False)
    housing_allowance = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    transport_allowance = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    other_allowances = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))

    gosi_deduction = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    absence_deduction = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))
    other_deductions = Column(Numeric(18, 2), nullable=False, default=Decimal("0"))

    gross = Column(Numeric(18, 2), nullable=False)
    net = Column(Numeric(18, 2), nullable=False)

    payment_date = Column(Date, nullable=True)
    wps_reference = Column(String(64), nullable=True)

    pdf_url = Column(String(500), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)

    payroll_run = relationship("PayrollRun", back_populates="payslips")
    employee = relationship("Employee", back_populates="payslips")
