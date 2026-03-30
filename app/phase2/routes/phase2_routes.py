"""
APEX Platform — Phase 2 API Routes
═══════════════════════════════════════════════════════════════
Clients, COA Upload, Analysis, Result Details (! icon).
Per execution document sections 5, 6, 12.
"""

from fastapi import APIRouter, HTTPException, Depends, File, UploadFile, Query
from pydantic import BaseModel, Field
from typing import Optional
import os, traceback

from app.phase1.routes.phase1_routes import get_current_user
from app.phase2.services.client_service import ClientService
from app.phase2.services.analysis_service import AnalysisService

router = APIRouter()
client_service = ClientService()
analysis_service = AnalysisService()


# ═══════════════════════════════════════════════════════════════
# Schemas
# ═══════════════════════════════════════════════════════════════

class CreateClientRequest(BaseModel):
    name_ar: str = Field(..., min_length=2)
    name_en: Optional[str] = None
    client_type_code: str
    cr_number: Optional[str] = None
    tax_number: Optional[str] = None
    sector: Optional[str] = None
    city: Optional[str] = None
    inventory_system: Optional[str] = None

class UpdateClientRequest(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    sector: Optional[str] = None
    city: Optional[str] = None
    fiscal_year_end: Optional[str] = None
    inventory_system: Optional[str] = None
    cr_number: Optional[str] = None
    tax_number: Optional[str] = None

class AddMemberRequest(BaseModel):
    user_id: str
    role: str = "member"


# ═══════════════════════════════════════════════════════════════
# Client APIs
# ═══════════════════════════════════════════════════════════════

@router.get("/client-types", tags=["Clients"])
async def list_client_types():
    """List available client types with knowledge mode eligibility."""
    return client_service.get_client_types()


@router.post("/clients", tags=["Clients"])
async def create_client(req: CreateClientRequest, user: dict = Depends(get_current_user)):
    result = client_service.create_client(
        user_id=user["sub"],
        name_ar=req.name_ar,
        client_type_code=req.client_type_code,
        name_en=req.name_en,
        cr_number=req.cr_number,
        tax_number=req.tax_number,
        sector=req.sector,
        city=req.city,
        inventory_system=req.inventory_system,
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/clients", tags=["Clients"])
async def list_my_clients(user: dict = Depends(get_current_user)):
    return client_service.list_my_clients(user["sub"])


@router.get("/clients/{client_id}", tags=["Clients"])
async def get_client(client_id: str, user: dict = Depends(get_current_user)):
    result = client_service.get_client(client_id, user["sub"])
    if not result.get("success"):
        raise HTTPException(status_code=403, detail=result.get("error"))
    return result


@router.put("/clients/{client_id}", tags=["Clients"])
async def update_client(client_id: str, req: UpdateClientRequest, user: dict = Depends(get_current_user)):
    result = client_service.update_client(client_id, user["sub"], req.dict(exclude_none=True))
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.post("/clients/{client_id}/members", tags=["Clients"])
async def add_member(client_id: str, req: AddMemberRequest, user: dict = Depends(get_current_user)):
    result = client_service.add_member(client_id, req.user_id, req.role, user["sub"])
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


# ═══════════════════════════════════════════════════════════════
# COA Upload + Analysis APIs
# ═══════════════════════════════════════════════════════════════

@router.post("/clients/{client_id}/upload", tags=["COA"])
async def upload_and_analyze(
    client_id: str,
    file: UploadFile = File(...),
    industry: str = Query("general"),
    closing_inventory: float = Query(None),
    with_ai: bool = Query(False),
    language: str = Query("ar"),
    user: dict = Depends(get_current_user),
):
    """
    Upload trial balance → analyze → store results with explanations.
    Set with_ai=true for AI narrative.
    """
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")

    content = await file.read()

    # Store upload record
    upload_id = analysis_service.store_upload(
        client_id=client_id,
        user_id=user["sub"],
        filename=file.filename,
        file_size=len(content),
        industry=industry,
        closing_inventory=closing_inventory,
    )

    try:
        # Run financial engine
        from app.services.orchestrator import AnalysisOrchestrator
        orchestrator = AnalysisOrchestrator()
        engine_result = orchestrator.analyze_bytes(
            file_bytes=content,
            filename=file.filename,
            industry=industry,
            closing_inventory=closing_inventory,
        )

        if not engine_result.get("success"):
            return {"success": False, "upload_id": upload_id, "error": engine_result.get("error")}

        # AI Narrative (optional)
        if with_ai:
            try:
                from app.services.ai.narrative_service import NarrativeService
                narrator = NarrativeService()
                brain_context = ""
                try:
                    from app.knowledge_brain.services.brain_service import KnowledgeBrainService
                    brain = KnowledgeBrainService()
                    brain_result = engine_result.get("knowledge_brain", {})
                    brain_context = brain.get_context_for_narrative(engine_result, brain_result)
                except Exception:
                    pass
                narrative = await narrator.generate(engine_result, language=language, brain_context=brain_context)
                engine_result["narrative"] = narrative
            except Exception:
                pass

        # Store in DB with explanations
        result_id = analysis_service.store_analysis_result(
            upload_id=upload_id,
            client_id=client_id,
            user_id=user["sub"],
            engine_result=engine_result,
        )

        # Return engine result + metadata
        engine_result["upload_id"] = upload_id
        engine_result["result_id"] = result_id
        return engine_result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ في التحليل: {str(e)}\n{traceback.format_exc()}")


# ═══════════════════════════════════════════════════════════════
# Result Details APIs (! icon — per document section 6)
# ═══════════════════════════════════════════════════════════════

@router.get("/results/{result_id}/details", tags=["Results"])
async def get_result_details(result_id: str, user: dict = Depends(get_current_user)):
    """
    Get full explanation panel for a result.
    Each metric has: how it was built, source rows, rules, confidence, warnings.
    This is what opens when user clicks the ! icon.
    """
    result = analysis_service.get_result_details(result_id)
    if not result.get("success"):
        raise HTTPException(status_code=404, detail=result.get("error"))
    return result


@router.get("/clients/{client_id}/results", tags=["Results"])
async def list_client_results(client_id: str, user: dict = Depends(get_current_user)):
    """List all analysis results for a client."""
    return analysis_service.list_results(client_id)
