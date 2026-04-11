"""
APEX Platform — Phase 2 API Routes
═══════════════════════════════════════════════════════════════
Clients, COA Upload, Analysis, Result Details (! icon).
Per execution document sections 5, 6, 12.
"""

from fastapi import APIRouter, HTTPException, Depends, File, UploadFile, Query
from pydantic import BaseModel, Field
from typing import Optional
import os, logging

from app.phase1.routes.phase1_routes import get_current_user
from app.phase2.services.client_service import ClientService
from app.phase2.services.analysis_service import AnalysisService
from app.core.storage_service import upload_file as storage_upload

# ── Phase 1 Integration ──
from app.phase2.services.readiness_service import compute_readiness, get_missing_for_coa
from app.phase2.services.document_service import can_transition, transition_document

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


class UpdateDocumentStatusRequest(BaseModel):
    status: Optional[str] = Field(None, description="New document status")
    reason: Optional[str] = Field(None, description="Reason for status change")


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
    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")

    content = await file.read()

    MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10MB
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="حجم الملف يتجاوز الحد المسموح 10MB")

    # Persist file via storage service
    store_result = storage_upload(content, file.filename, folder="trial_balance")
    if not store_result.get("success"):
        logging.error("File storage failed: %s", store_result.get("error"))
        raise HTTPException(status_code=500, detail="File storage failed")

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
        return {"success": True, "data": engine_result}

    except Exception as e:
        logging.error("Analysis error", exc_info=True)
        raise HTTPException(status_code=500, detail="Analysis failed")


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
    results = analysis_service.list_results(client_id)
    return {"success": True, "data": results}


# ═══════════════════════════════════════════════════════════════
# Phase 1: Client Readiness + Document Lifecycle Endpoints
# ═══════════════════════════════════════════════════════════════


@router.get("/clients/{client_id}/readiness", tags=["Phase1-Readiness"])
async def get_client_readiness(client_id: str, user: dict = Depends(get_current_user)):
    """Compute and return client readiness status with blockers."""
    from app.phase1.models.platform_models import SessionLocal
    from sqlalchemy import text as _t

    db = SessionLocal()
    try:
        row = db.execute(
            _t(
                "SELECT name_ar, client_type_code, sector, city, country, registration_status, "
                "readiness_status, coa_stage FROM clients WHERE id = :cid"
            ),
            {"cid": client_id},
        ).fetchone()
        if not row:
            raise HTTPException(404, "Client not found")

        client_data = {
            "name_ar": row[0],
            "client_type": row[1],
            "main_sector": row[2],
            "city": row[3],
            "region": row[4],
            "status": row[5],
            "coa_stage": row[7],
        }

        # Get documents
        docs = db.execute(
            _t("SELECT document_type, name_ar, required, status FROM client_documents WHERE client_id = :cid"),
            {"cid": client_id},
        ).fetchall()
        doc_list = [{"id": d[0], "name_ar": d[1], "required": d[2], "status": d[3]} for d in docs]

        readiness = compute_readiness(client_data, doc_list)
        blockers = get_missing_for_coa(client_data, doc_list)

        # Update stored readiness
        db.execute(_t("UPDATE clients SET readiness_status = :rs WHERE id = :cid"), {"rs": readiness, "cid": client_id})
        db.commit()

        return {
            "success": True,
            "data": {
                "client_id": client_id,
                "readiness_status": readiness,
                "blockers": blockers,
                "documents_summary": {
                    "total": len(doc_list),
                    "required": len([d for d in doc_list if d["required"]]),
                    "accepted": len([d for d in doc_list if d["status"] == "accepted"]),
                    "missing": len([d for d in doc_list if d["status"] == "missing"]),
                },
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Readiness check failed", exc_info=True)
        raise HTTPException(500, "Readiness check failed")
    finally:
        db.close()


@router.patch("/clients/{client_id}/documents/{doc_type}/status", tags=["Phase1-Documents"])
async def update_document_status(
    client_id: str,
    doc_type: str,
    body: UpdateDocumentStatusRequest = UpdateDocumentStatusRequest(),
    user: dict = Depends(get_current_user),
):
    """Update document status following lifecycle rules."""
    from app.phase1.models.platform_models import SessionLocal
    from sqlalchemy import text as _t

    db = SessionLocal()
    try:
        row = db.execute(
            _t(
                "SELECT id, status, document_type, name_ar, required FROM client_documents "
                "WHERE client_id = :cid AND document_type = :dt"
            ),
            {"cid": client_id, "dt": doc_type},
        ).fetchone()
        if not row:
            raise HTTPException(404, "Document not found")

        current_doc = {"id": row[0], "status": row[1], "document_type": row[2], "name_ar": row[3], "required": row[4]}
        new_status = body.status
        reason = body.reason

        if not new_status:
            raise HTTPException(400, "Missing 'status' in body")

        if not can_transition(current_doc["status"], new_status):
            raise HTTPException(400, f"Invalid transition: {current_doc['status']} -> {new_status}")

        updated = transition_document(current_doc, new_status, reason)

        # Update in DB
        db.execute(
            _t(
                "UPDATE client_documents SET status = :s, uploaded_at = :ua, "
                "accepted_at = :aa, rejected_at = :ra, reject_reason = :rr, replaced_at = :repa "
                "WHERE client_id = :cid AND document_type = :dt"
            ),
            {
                "s": updated["status"],
                "ua": updated.get("uploaded_at"),
                "aa": updated.get("accepted_at"),
                "ra": updated.get("rejected_at"),
                "rr": updated.get("reject_reason"),
                "repa": updated.get("replaced_at"),
                "cid": client_id,
                "dt": doc_type,
            },
        )
        db.commit()

        return {
            "success": True,
            "data": {
                "client_id": client_id,
                "document_type": doc_type,
                "old_status": current_doc["status"],
                "new_status": new_status,
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Document update failed", exc_info=True)
        raise HTTPException(500, "Document update failed")
    finally:
        db.close()


@router.get("/clients/{client_id}/documents", tags=["Phase1-Documents"])
async def list_client_documents(client_id: str, user: dict = Depends(get_current_user)):
    """List all documents for a client with their current status."""
    from app.phase1.models.platform_models import SessionLocal
    from sqlalchemy import text as _t

    db = SessionLocal()
    try:
        rows = db.execute(
            _t(
                "SELECT document_type, name_ar, name_en, required, status, "
                "uploaded_at, accepted_at, rejected_at, reject_reason, expires_at "
                "FROM client_documents WHERE client_id = :cid ORDER BY required DESC, document_type"
            ),
            {"cid": client_id},
        ).fetchall()
        return {
            "success": True,
            "data": {
                "client_id": client_id,
                "documents": [
                    {
                        "type": r[0],
                        "name_ar": r[1],
                        "name_en": r[2],
                        "required": r[3],
                        "status": r[4],
                        "uploaded_at": str(r[5]) if r[5] else None,
                        "accepted_at": str(r[6]) if r[6] else None,
                        "rejected_at": str(r[7]) if r[7] else None,
                        "reject_reason": r[8],
                        "expires_at": str(r[9]) if r[9] else None,
                    }
                    for r in rows
                ],
                "total": len(rows),
                "required_count": len([r for r in rows if r[3]]),
                "accepted_count": len([r for r in rows if r[4] == "accepted"]),
            },
        }
    finally:
        db.close()
