"""
APEX Platform - Service Catalog + Audit Service APIs
Per Architecture Doc v5 Sections 7, 8, 15
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timezone
import logging

from app.phase1.routes.phase1_routes import get_current_user
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow
from app.phase2.models.service_catalog_models import (
    ServiceCatalog, ServiceWorkflowStage, ServiceCase,
    AuditProgramTemplate, AuditSample, AuditWorkpaper, AuditFinding,
)

router = APIRouter()


# ── Schemas ──

class CreateServiceCaseRequest(BaseModel):
    client_id: str
    service_code: str
    notes: Optional[str] = None

class CreateSampleRequest(BaseModel):
    area: str
    sampling_method: str = "random"
    population_ref: Optional[str] = None
    population_size: Optional[int] = None
    selected_count: int
    selection_rationale: Optional[str] = None

class CreateWorkpaperRequest(BaseModel):
    procedure_code: str
    area: str
    title_ar: Optional[str] = None
    description: Optional[str] = None
    evidence_ref: Optional[str] = None
    evidence_type: Optional[str] = None
    result: Optional[str] = None
    finding_description: Optional[str] = None
    severity: Optional[str] = None

class ReviewWorkpaperRequest(BaseModel):
    reviewer_status: str  # approved, rejected, needs_revision
    reviewer_notes: Optional[str] = None

class CreateFindingRequest(BaseModel):
    area: str
    title_ar: str
    description_ar: str
    severity: str = "medium"
    materiality: Optional[float] = None
    proposed_adjustment: Optional[dict] = None
    impact_on_report: Optional[str] = None


# ═══ Service Catalog ═══

@router.get("/services/catalog", tags=["Service Catalog"])
async def list_services(category: Optional[str] = None):
    db = SessionLocal()
    try:
        q = db.query(ServiceCatalog).filter(ServiceCatalog.is_active == True)
        if category:
            q = q.filter(ServiceCatalog.category == category)
        items = q.order_by(ServiceCatalog.sort_order).all()
        return {"success": True, "data": [
            {"id": s.id, "service_code": s.service_code, "title_ar": s.title_ar,
             "title_en": s.title_en, "category": s.category, "icon": s.icon,
             "requires_coa": s.requires_coa, "requires_tb": s.requires_tb,
             "min_plan": s.min_plan,
             "stages_count": len(s.stages) if s.stages else 0}
            for s in items
        ]}
    finally:
        db.close()


@router.get("/services/catalog/{service_code}", tags=["Service Catalog"])
async def get_service_detail(service_code: str):
    db = SessionLocal()
    try:
        svc = db.query(ServiceCatalog).filter(ServiceCatalog.service_code == service_code).first()
        if not svc:
            raise HTTPException(status_code=404, detail="Service not found")
        return {"success": True, "data": {
            "id": svc.id, "service_code": svc.service_code,
            "title_ar": svc.title_ar, "title_en": svc.title_en,
            "description_ar": svc.description_ar, "category": svc.category,
            "requires_coa": svc.requires_coa, "requires_tb": svc.requires_tb,
            "stages": [{"stage_code": st.stage_code, "stage_order": st.stage_order,
                        "title_ar": st.title_ar, "is_mandatory": st.is_mandatory,
                        "input_requirements": st.input_requirements,
                        "output_deliverables": st.output_deliverables,
                        "help_text_ar": st.help_text_ar}
                       for st in (svc.stages or [])]
        }}
    finally:
        db.close()


# ═══ Service Cases ═══

@router.post("/services/cases", tags=["Service Cases"])
async def create_service_case(req: CreateServiceCaseRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        svc = db.query(ServiceCatalog).filter(ServiceCatalog.service_code == req.service_code, ServiceCatalog.is_active == True).first()
        if not svc:
            raise HTTPException(status_code=404, detail="Service not found or inactive")
        first_stage = db.query(ServiceWorkflowStage).filter(
            ServiceWorkflowStage.service_id == svc.id
        ).order_by(ServiceWorkflowStage.stage_order).first()

        case = ServiceCase(
            client_id=req.client_id, service_id=svc.id,
            service_code=req.service_code, current_stage=first_stage.stage_code if first_stage else None,
            notes=req.notes, created_by=user["sub"],
            started_at=datetime.now(timezone.utc),
        )
        db.add(case)
        db.commit()
        db.refresh(case)
        return {"success": True, "case_id": case.id, "current_stage": case.current_stage}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Failed to create service case", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to create service case")
    finally:
        db.close()


@router.get("/services/cases", tags=["Service Cases"])
async def list_my_cases(client_id: Optional[str] = None, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        q = db.query(ServiceCase).filter(ServiceCase.created_by == user["sub"])
        if client_id:
            q = q.filter(ServiceCase.client_id == client_id)
        cases = q.order_by(ServiceCase.created_at.desc()).all()
        return {"success": True, "data": [
            {"id": c.id, "service_code": c.service_code, "client_id": c.client_id,
             "status": c.status, "current_stage": c.current_stage,
             "progress_percent": c.progress_percent,
             "started_at": str(c.started_at) if c.started_at else None}
            for c in cases
        ]}
    finally:
        db.close()


@router.get("/services/cases/{case_id}", tags=["Service Cases"])
async def get_case_detail(case_id: str):
    db = SessionLocal()
    try:
        case = db.query(ServiceCase).filter(ServiceCase.id == case_id).first()
        if not case:
            raise HTTPException(status_code=404, detail="Case not found")
        return {"success": True, "data": {
            "id": case.id, "service_code": case.service_code, "client_id": case.client_id,
            "status": case.status, "current_stage": case.current_stage,
            "progress_percent": case.progress_percent, "notes": case.notes,
        }}
    finally:
        db.close()


# ═══ Audit Program Templates ═══

@router.get("/audit/templates", tags=["Audit Service"])
async def list_audit_templates(area: Optional[str] = None):
    db = SessionLocal()
    try:
        q = db.query(AuditProgramTemplate).filter(AuditProgramTemplate.is_active == True)
        if area:
            q = q.filter(AuditProgramTemplate.area == area)
        items = q.order_by(AuditProgramTemplate.area).all()
        return {"success": True, "data": [
            {"id": t.id, "procedure_code": t.procedure_code, "area": t.area,
             "title_ar": t.title_ar, "risk_level": t.risk_level,
             "local_std_ref": t.local_std_ref, "international_ref": t.international_ref}
            for t in items
        ]}
    finally:
        db.close()


# ═══ Audit Samples ═══

@router.post("/audit/cases/{case_id}/samples", tags=["Audit Service"])
async def create_sample(case_id: str, req: CreateSampleRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        sample = AuditSample(
            service_case_id=case_id, area=req.area,
            sampling_method=req.sampling_method, population_ref=req.population_ref,
            population_size=req.population_size, selected_count=req.selected_count,
            selection_rationale=req.selection_rationale, created_by=user["sub"],
        )
        db.add(sample)
        db.commit()
        db.refresh(sample)
        return {"success": True, "sample_id": sample.id}
    except Exception as e:
        db.rollback()
        logging.error("Failed to create audit sample", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to create audit sample")
    finally:
        db.close()


@router.get("/audit/cases/{case_id}/samples", tags=["Audit Service"])
async def list_samples(case_id: str):
    db = SessionLocal()
    try:
        items = db.query(AuditSample).filter(AuditSample.service_case_id == case_id).all()
        return {"success": True, "data": [
            {"id": s.id, "area": s.area, "sampling_method": s.sampling_method,
             "selected_count": s.selected_count, "status": s.status}
            for s in items
        ]}
    finally:
        db.close()


# ═══ Audit Workpapers ═══

@router.post("/audit/cases/{case_id}/workpapers", tags=["Audit Service"])
async def create_workpaper(case_id: str, req: CreateWorkpaperRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        wp = AuditWorkpaper(
            service_case_id=case_id, procedure_code=req.procedure_code,
            area=req.area, title_ar=req.title_ar, description=req.description,
            evidence_ref=req.evidence_ref, evidence_type=req.evidence_type,
            result=req.result, finding_description=req.finding_description,
            severity=req.severity, created_by=user["sub"],
        )
        db.add(wp)
        db.commit()
        db.refresh(wp)
        return {"success": True, "workpaper_id": wp.id}
    except Exception as e:
        db.rollback()
        logging.error("Failed to create workpaper", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to create workpaper")
    finally:
        db.close()


@router.get("/audit/cases/{case_id}/workpapers", tags=["Audit Service"])
async def list_workpapers(case_id: str, area: Optional[str] = None):
    db = SessionLocal()
    try:
        q = db.query(AuditWorkpaper).filter(AuditWorkpaper.service_case_id == case_id)
        if area:
            q = q.filter(AuditWorkpaper.area == area)
        items = q.order_by(AuditWorkpaper.created_at).all()
        return {"success": True, "data": [
            {"id": w.id, "procedure_code": w.procedure_code, "area": w.area,
             "result": w.result, "severity": w.severity,
             "reviewer_status": w.reviewer_status}
            for w in items
        ]}
    finally:
        db.close()


@router.post("/audit/workpapers/{wp_id}/review", tags=["Audit Service"])
async def review_workpaper(wp_id: str, req: ReviewWorkpaperRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        wp = db.query(AuditWorkpaper).filter(AuditWorkpaper.id == wp_id).first()
        if not wp:
            raise HTTPException(status_code=404, detail="Workpaper not found")
        wp.reviewer_status = req.reviewer_status
        wp.reviewer_notes = req.reviewer_notes
        wp.reviewer_id = user["sub"]
        wp.reviewed_at = datetime.now(timezone.utc)
        db.commit()
        return {"success": True, "status": wp.reviewer_status}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Failed to review workpaper", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to review workpaper")
    finally:
        db.close()


# ═══ Audit Findings ═══

@router.post("/audit/cases/{case_id}/findings", tags=["Audit Service"])
async def create_finding(case_id: str, req: CreateFindingRequest, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        finding = AuditFinding(
            service_case_id=case_id, finding_code=f"F-{gen_uuid()[:8].upper()}",
            area=req.area, title_ar=req.title_ar, description_ar=req.description_ar,
            severity=req.severity, materiality=req.materiality,
            proposed_adjustment=req.proposed_adjustment,
            impact_on_report=req.impact_on_report,
        )
        db.add(finding)
        db.commit()
        db.refresh(finding)
        return {"success": True, "finding_id": finding.id, "finding_code": finding.finding_code}
    except Exception as e:
        db.rollback()
        logging.error("Failed to create audit finding", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to create audit finding")
    finally:
        db.close()


@router.get("/audit/cases/{case_id}/findings", tags=["Audit Service"])
async def list_findings(case_id: str):
    db = SessionLocal()
    try:
        items = db.query(AuditFinding).filter(AuditFinding.service_case_id == case_id).order_by(AuditFinding.severity.desc()).all()
        return {"success": True, "data": [
            {"id": f.id, "finding_code": f.finding_code, "area": f.area,
             "title_ar": f.title_ar, "severity": f.severity,
             "status": f.status, "impact_on_report": f.impact_on_report}
            for f in items
        ]}
    finally:
        db.close()
