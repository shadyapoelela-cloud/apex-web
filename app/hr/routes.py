"""HR REST routes — Employee + Leave + Payroll CRUD.

Mounted at /hr/*. All endpoints are tenant-scoped via TenantContextMiddleware
+ tenant_guard (models inherit TenantMixin, so filtering is automatic).

Endpoints:
  Employees
    GET    /hr/employees                     list (paginated)
    POST   /hr/employees                     create
    GET    /hr/employees/{id}                read
    PUT    /hr/employees/{id}                update
    DELETE /hr/employees/{id}                terminate (soft)

  Leave
    GET    /hr/leave-requests                list
    POST   /hr/leave-requests                create (pending)
    POST   /hr/leave-requests/{id}/approve   approve
    POST   /hr/leave-requests/{id}/reject    reject with reason

  Payroll
    POST   /hr/payroll/run                   create a run for a period
    GET    /hr/payroll/{period}              fetch run + payslips
    POST   /hr/payroll/{period}/approve      approve a run
    GET    /hr/payroll/{period}/wps.sif      download WPS SIF file

  Calculators (helpers — reuse from UI too)
    POST   /hr/calc/gosi                     KSA or UAE GOSI
    POST   /hr/calc/eosb                     KSA or UAE EOSB
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError

from app.core.pagination import paginate, parse_pagination_query
from app.core.tenant_context import current_tenant
from app.hr.eosb_calculator import calculate_ksa_eosb, calculate_uae_eosb
from app.hr.gosi_calculator import calculate_ksa_gosi, calculate_uae_gpssa
from app.hr.models import Employee, LeaveRequest, Payslip, PayrollRun
from app.hr.wps_generator import (
    WpsCompany,
    WpsEmployeeLine,
    generate_ksa_sif,
    generate_uae_sif,
)
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/hr", tags=["HR"])


# ── Request / Response schemas ──────────────────────────────


class EmployeeIn(BaseModel):
    employee_number: str = Field(..., min_length=1, max_length=32)
    name_ar: str = Field(..., min_length=1, max_length=200)
    name_en: Optional[str] = None
    national_id: Optional[str] = None
    iqama_number: Optional[str] = None
    emirates_id: Optional[str] = None
    nationality: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    hire_date: date
    basic_salary: Decimal
    housing_allowance: Decimal = Decimal("0")
    transport_allowance: Decimal = Decimal("0")
    other_allowances: Decimal = Decimal("0")
    bank_iban: Optional[str] = None
    bank_name: Optional[str] = None
    gosi_number: Optional[str] = None
    gosi_applicable: bool = True
    notes: Optional[str] = None


class EmployeeOut(EmployeeIn):
    id: str
    status: str
    tenant_id: Optional[str]
    created_at: datetime

    @classmethod
    def from_model(cls, m: Employee) -> "EmployeeOut":
        return cls(
            id=m.id,
            employee_number=m.employee_number,
            name_ar=m.name_ar,
            name_en=m.name_en,
            national_id=m.national_id,
            iqama_number=m.iqama_number,
            emirates_id=m.emirates_id,
            nationality=m.nationality,
            department=m.department,
            job_title=m.job_title,
            hire_date=m.hire_date,
            basic_salary=m.basic_salary,
            housing_allowance=m.housing_allowance,
            transport_allowance=m.transport_allowance,
            other_allowances=m.other_allowances,
            bank_iban=m.bank_iban,
            bank_name=m.bank_name,
            gosi_number=m.gosi_number,
            gosi_applicable=m.gosi_applicable,
            notes=m.notes,
            status=m.status,
            tenant_id=m.tenant_id,
            created_at=m.created_at,
        )


class LeaveRequestIn(BaseModel):
    employee_id: str
    leave_type: str = Field(..., pattern="^(annual|sick|unpaid|hajj|maternity|bereavement)$")
    start_date: date
    end_date: date
    reason: Optional[str] = None

    @property
    def days(self) -> int:
        return (self.end_date - self.start_date).days + 1


class LeaveRequestOut(BaseModel):
    id: str
    employee_id: str
    leave_type: str
    start_date: date
    end_date: date
    days: int
    status: str
    reason: Optional[str]
    rejection_reason: Optional[str]
    approved_by: Optional[str]
    approved_at: Optional[datetime]
    created_at: datetime


class PayrollRunIn(BaseModel):
    period: str = Field(..., pattern=r"^\d{4}-(0[1-9]|1[012])$")


class PayrollRunOut(BaseModel):
    id: str
    period: str
    status: str
    total_gross: Decimal
    total_deductions: Decimal
    total_net: Decimal
    employee_count: int
    created_at: datetime


class GosiCalcIn(BaseModel):
    country: str = Field(..., pattern="^(ksa|uae)$")
    basic_salary: Decimal
    housing_allowance: Decimal = Decimal("0")
    other_fixed: Decimal = Decimal("0")
    is_national: bool = True


class EosbCalcIn(BaseModel):
    country: str = Field(..., pattern="^(ksa|uae)$")
    monthly_wage: Decimal
    years_of_service: Decimal
    resigned: bool = False


# ── Employee CRUD ───────────────────────────────────────────


@router.get("/employees")
def list_employees(
    cursor: Optional[str] = Query(None),
    limit: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
):
    cursor, limit = parse_pagination_query(cursor, limit)
    db = SessionLocal()
    try:
        q = db.query(Employee)
        if status:
            q = q.filter(Employee.status == status)
        page = paginate(
            q, order_field=Employee.created_at, direction="desc",
            limit=limit, cursor=cursor,
        )
        return {
            "success": True,
            "data": [EmployeeOut.from_model(e).model_dump(mode="json") for e in page.items],
            "next_cursor": page.next_cursor,
            "has_more": page.has_more,
            "limit": page.limit,
        }
    finally:
        db.close()


@router.post("/employees", status_code=201)
def create_employee(payload: EmployeeIn):
    db = SessionLocal()
    try:
        emp = Employee(
            id=str(uuid.uuid4()),
            employee_number=payload.employee_number,
            name_ar=payload.name_ar,
            name_en=payload.name_en,
            national_id=payload.national_id,
            iqama_number=payload.iqama_number,
            emirates_id=payload.emirates_id,
            nationality=payload.nationality,
            department=payload.department,
            job_title=payload.job_title,
            hire_date=payload.hire_date,
            basic_salary=payload.basic_salary,
            housing_allowance=payload.housing_allowance,
            transport_allowance=payload.transport_allowance,
            other_allowances=payload.other_allowances,
            bank_iban=payload.bank_iban,
            bank_name=payload.bank_name,
            gosi_number=payload.gosi_number,
            gosi_applicable=payload.gosi_applicable,
            gosi_employee_rate=Decimal("0.10"),
            gosi_employer_rate=Decimal("0.12"),
            status="active",
            notes=payload.notes,
        )
        db.add(emp)
        try:
            db.commit()
        except IntegrityError as e:
            db.rollback()
            raise HTTPException(status_code=409, detail="Employee number already exists for this tenant") from e
        db.refresh(emp)
        return {"success": True, "data": EmployeeOut.from_model(emp).model_dump(mode="json")}
    finally:
        db.close()


@router.get("/employees/{emp_id}")
def get_employee(emp_id: str):
    db = SessionLocal()
    try:
        emp = db.query(Employee).filter(Employee.id == emp_id).first()
        if not emp:
            raise HTTPException(status_code=404, detail="Employee not found")
        return {"success": True, "data": EmployeeOut.from_model(emp).model_dump(mode="json")}
    finally:
        db.close()


@router.put("/employees/{emp_id}")
def update_employee(emp_id: str, payload: EmployeeIn):
    db = SessionLocal()
    try:
        emp = db.query(Employee).filter(Employee.id == emp_id).first()
        if not emp:
            raise HTTPException(status_code=404, detail="Employee not found")
        for key, value in payload.model_dump().items():
            setattr(emp, key, value)
        db.commit()
        db.refresh(emp)
        return {"success": True, "data": EmployeeOut.from_model(emp).model_dump(mode="json")}
    finally:
        db.close()


@router.delete("/employees/{emp_id}")
def terminate_employee(emp_id: str):
    db = SessionLocal()
    try:
        emp = db.query(Employee).filter(Employee.id == emp_id).first()
        if not emp:
            raise HTTPException(status_code=404, detail="Employee not found")
        emp.status = "terminated"
        emp.termination_date = date.today()
        db.commit()
        return {"success": True, "data": {"id": emp_id, "status": "terminated"}}
    finally:
        db.close()


# ── Leave ──────────────────────────────────────────────────


@router.post("/leave-requests", status_code=201)
def create_leave_request(payload: LeaveRequestIn):
    if payload.end_date < payload.start_date:
        raise HTTPException(status_code=400, detail="end_date < start_date")
    db = SessionLocal()
    try:
        emp = db.query(Employee).filter(Employee.id == payload.employee_id).first()
        if not emp:
            raise HTTPException(status_code=404, detail="Employee not found")
        req = LeaveRequest(
            id=str(uuid.uuid4()),
            employee_id=payload.employee_id,
            leave_type=payload.leave_type,
            start_date=payload.start_date,
            end_date=payload.end_date,
            days=payload.days,
            status="pending",
            reason=payload.reason,
        )
        db.add(req)
        db.commit()
        db.refresh(req)
        return {
            "success": True,
            "data": LeaveRequestOut.model_validate(req, from_attributes=True).model_dump(mode="json"),
        }
    finally:
        db.close()


@router.get("/leave-requests")
def list_leave_requests(status: Optional[str] = Query(None)):
    db = SessionLocal()
    try:
        q = db.query(LeaveRequest).order_by(LeaveRequest.created_at.desc())
        if status:
            q = q.filter(LeaveRequest.status == status)
        rows = q.limit(100).all()
        return {
            "success": True,
            "data": [
                LeaveRequestOut.model_validate(r, from_attributes=True).model_dump(mode="json")
                for r in rows
            ],
        }
    finally:
        db.close()


@router.post("/leave-requests/{req_id}/approve")
def approve_leave(req_id: str):
    db = SessionLocal()
    try:
        req = db.query(LeaveRequest).filter(LeaveRequest.id == req_id).first()
        if not req:
            raise HTTPException(status_code=404, detail="Leave request not found")
        if req.status != "pending":
            raise HTTPException(status_code=409, detail=f"Already {req.status}")
        req.status = "approved"
        req.approved_at = datetime.now(timezone.utc)
        db.commit()
        return {"success": True, "data": {"id": req_id, "status": "approved"}}
    finally:
        db.close()


@router.post("/leave-requests/{req_id}/reject")
def reject_leave(req_id: str, reason: str = Query(...)):
    db = SessionLocal()
    try:
        req = db.query(LeaveRequest).filter(LeaveRequest.id == req_id).first()
        if not req:
            raise HTTPException(status_code=404, detail="Leave request not found")
        if req.status != "pending":
            raise HTTPException(status_code=409, detail=f"Already {req.status}")
        req.status = "rejected"
        req.rejection_reason = reason
        db.commit()
        return {"success": True, "data": {"id": req_id, "status": "rejected"}}
    finally:
        db.close()


# ── Payroll ────────────────────────────────────────────────


@router.post("/payroll/run", status_code=201)
def create_payroll_run(payload: PayrollRunIn):
    """Generate a payroll run for all active employees for a given period.

    Calculates gross = basic + housing + transport + other,
    deductions = GOSI (Saudi employees only),
    net = gross - deductions.
    """
    db = SessionLocal()
    try:
        # Check if a run already exists for this period
        existing = db.query(PayrollRun).filter(PayrollRun.period == payload.period).first()
        if existing:
            raise HTTPException(
                status_code=409,
                detail=f"Payroll run for {payload.period} already exists (status={existing.status})",
            )

        run = PayrollRun(
            id=str(uuid.uuid4()),
            period=payload.period,
            status="draft",
        )
        db.add(run)
        db.flush()

        active_employees = db.query(Employee).filter(Employee.status == "active").all()
        total_gross = Decimal("0")
        total_ded = Decimal("0")
        total_net = Decimal("0")

        for emp in active_employees:
            gosi = calculate_ksa_gosi(
                basic_salary=emp.basic_salary,
                housing_allowance=emp.housing_allowance,
                is_saudi=(emp.nationality == "SAU" or emp.nationality is None) and emp.gosi_applicable,
            )
            gross = emp.basic_salary + emp.housing_allowance + emp.transport_allowance + emp.other_allowances
            deductions = gosi.employee_contribution
            net = gross - deductions

            slip = Payslip(
                id=str(uuid.uuid4()),
                payroll_run_id=run.id,
                employee_id=emp.id,
                basic_salary=emp.basic_salary,
                housing_allowance=emp.housing_allowance,
                transport_allowance=emp.transport_allowance,
                other_allowances=emp.other_allowances,
                gosi_deduction=deductions,
                absence_deduction=Decimal("0"),
                other_deductions=Decimal("0"),
                gross=gross,
                net=net,
            )
            db.add(slip)
            total_gross += gross
            total_ded += deductions
            total_net += net

        run.total_gross = total_gross
        run.total_deductions = total_ded
        run.total_net = total_net
        run.employee_count = len(active_employees)
        db.commit()
        db.refresh(run)
        return {
            "success": True,
            "data": PayrollRunOut.model_validate(run, from_attributes=True).model_dump(mode="json"),
        }
    finally:
        db.close()


@router.get("/payroll/{period}")
def get_payroll_run(period: str):
    db = SessionLocal()
    try:
        run = db.query(PayrollRun).filter(PayrollRun.period == period).first()
        if not run:
            raise HTTPException(status_code=404, detail="Payroll run not found")
        payslips = [
            {
                "id": p.id,
                "employee_id": p.employee_id,
                "gross": str(p.gross),
                "gosi": str(p.gosi_deduction),
                "net": str(p.net),
            }
            for p in run.payslips
        ]
        return {
            "success": True,
            "data": {
                **PayrollRunOut.model_validate(run, from_attributes=True).model_dump(mode="json"),
                "payslips": payslips,
            },
        }
    finally:
        db.close()


@router.post("/payroll/{period}/approve")
def approve_payroll_run(period: str):
    db = SessionLocal()
    try:
        run = db.query(PayrollRun).filter(PayrollRun.period == period).first()
        if not run:
            raise HTTPException(status_code=404, detail="Payroll run not found")
        if run.status != "draft":
            raise HTTPException(status_code=409, detail=f"Cannot approve (status={run.status})")
        run.status = "approved"
        run.approved_at = datetime.now(timezone.utc)
        db.commit()
        return {"success": True, "data": {"period": period, "status": "approved"}}
    finally:
        db.close()


@router.get("/payroll/{period}/wps.sif")
def download_wps_sif(period: str, country: str = Query("ksa", pattern="^(ksa|uae)$")):
    """Generate a WPS SIF file for the given period.

    Callers must supply ?country=ksa or ?country=uae. Company info is
    pulled from env vars for now (WPS_COMPANY_CR, WPS_EMPLOYER_ID, ...).
    """
    import os
    db = SessionLocal()
    try:
        run = db.query(PayrollRun).filter(PayrollRun.period == period).first()
        if not run or not run.payslips:
            raise HTTPException(status_code=404, detail="No payroll data for period")

        company = WpsCompany(
            cr_number=os.environ.get("WPS_COMPANY_CR", "UNKNOWN"),
            employer_id=os.environ.get("WPS_EMPLOYER_ID", "UNKNOWN"),
            company_name_en=os.environ.get("WPS_COMPANY_NAME_EN", "APEX"),
            bank_code=os.environ.get("WPS_COMPANY_BANK", "000"),
            iban=os.environ.get("WPS_COMPANY_IBAN", ""),
        )
        lines: list[WpsEmployeeLine] = []
        for slip in run.payslips:
            emp = slip.employee
            lines.append(
                WpsEmployeeLine(
                    employee_id=(emp.iqama_number or emp.national_id or emp.emirates_id or emp.id),
                    name_en=emp.name_en or emp.name_ar,
                    bank_code="000",
                    iban=emp.bank_iban or "",
                    basic_salary=slip.basic_salary,
                    housing_allowance=slip.housing_allowance,
                    other_allowances=slip.other_allowances + slip.transport_allowance,
                    deductions=slip.gosi_deduction + slip.absence_deduction + slip.other_deductions,
                )
            )
        result = (
            generate_ksa_sif(company=company, period=period, employees=lines)
            if country == "ksa"
            else generate_uae_sif(company=company, period=period, employees=lines)
        )

        return Response(
            content=result.text,
            media_type="text/plain; charset=utf-8",
            headers={
                "Content-Disposition": f'attachment; filename="wps_{period}_{country}.sif"',
                "X-WPS-Checksum": result.checksum,
                "X-WPS-Record-Count": str(result.total_records),
                "X-WPS-Total": str(result.total_salary),
            },
        )
    finally:
        db.close()


# ── Calculators ────────────────────────────────────────────


@router.post("/calc/gosi")
def calc_gosi(payload: GosiCalcIn):
    if payload.country == "ksa":
        r = calculate_ksa_gosi(
            basic_salary=payload.basic_salary,
            housing_allowance=payload.housing_allowance,
            is_saudi=payload.is_national,
        )
    else:
        r = calculate_uae_gpssa(
            basic_salary=payload.basic_salary,
            housing_allowance=payload.housing_allowance,
            other_fixed=payload.other_fixed,
            is_gcc_national=payload.is_national,
        )
    return {
        "success": True,
        "data": {
            "applicable": r.applicable,
            "reason": r.reason,
            "salary_base": str(r.salary_base),
            "employee_contribution": str(r.employee_contribution),
            "employer_contribution": str(r.employer_contribution),
        },
    }


@router.post("/calc/eosb")
def calc_eosb(payload: EosbCalcIn):
    r = (
        calculate_ksa_eosb(
            monthly_wage=payload.monthly_wage,
            years_of_service=payload.years_of_service,
            resigned=payload.resigned,
        )
        if payload.country == "ksa"
        else calculate_uae_eosb(
            basic_monthly_wage=payload.monthly_wage,
            years_of_service=payload.years_of_service,
        )
    )
    return {
        "success": True,
        "data": {
            "full_eosb": str(r.full_eosb),
            "payable": str(r.payable),
            "years_first_tier": str(r.years_first_tier),
            "years_second_tier": str(r.years_second_tier),
            "first_tier_amount": str(r.first_tier_amount),
            "second_tier_amount": str(r.second_tier_amount),
            "reduction_factor": str(r.reduction_factor),
            "notes": r.notes,
        },
    }
