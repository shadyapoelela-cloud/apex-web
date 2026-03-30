"""
APEX Financial Platform — FastAPI Backend v3.1
═══════════════════════════════════════════════════════════════

Phase 1: Identity + Account + Plans + Entitlements + Legal
Phase 2: Clients + COA + Analysis Results + Explanations (! icon)
+ Existing: Financial Engine v2 + Knowledge Brain

AI does NOT modify any numbers.
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
import os, traceback

from app.services.orchestrator import AnalysisOrchestrator

# ─── Knowledge Brain (existing) ───
try:
    from app.knowledge_brain.api.routes.knowledge_routes import router as kb_router
    from app.knowledge_brain.models.db_models import init_db as init_kb_db
    KB_AVAILABLE = True
except Exception:
    KB_AVAILABLE = False

# ─── Phase 1: Platform Core ───
try:
    from app.phase1.models.platform_models import init_platform_db
    from app.phase1.routes.phase1_routes import router as phase1_router
    from app.phase1.services.seed_data import seed_all as seed_phase1
    PHASE1_AVAILABLE = True
except Exception as e:
    PHASE1_AVAILABLE = False
    print(f"Phase 1 load error: {e}")

# ─── Phase 2: Clients + COA + Results ───
try:
    from app.phase2.models.phase2_models import *  # Register models with Base
    from app.phase2.routes.phase2_routes import router as phase2_router
    from app.phase2.services.seed_phase2 import seed_client_types
    PHASE2_AVAILABLE = True
except Exception as e:
    PHASE2_AVAILABLE = False
    print(f"Phase 2 load error: {e}")

# ═══════════════════════════════════════════════════════════════
# App Setup
# ═══════════════════════════════════════════════════════════════

app = FastAPI(
    title="APEX Financial Platform API",
    description="منصة أبكس للتحليل المالي — محرك مالي + ذكاء اصطناعي + عقل معرفي + نظام حسابات + عملاء",
    version="3.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

orchestrator = AnalysisOrchestrator()


# ═══════════════════════════════════════════════════════════════
# Startup
# ═══════════════════════════════════════════════════════════════

@app.on_event("startup")
def startup():
    if KB_AVAILABLE:
        try: init_kb_db()
        except: pass

    if PHASE1_AVAILABLE:
        try:
            tables = init_platform_db()
            print(f"APEX Platform: {len(tables)} tables")
            result = seed_phase1()
            print(f"APEX Seed Phase 1: {result}")
        except Exception as e:
            print(f"Phase 1 init error: {e}")

    if PHASE2_AVAILABLE:
        try:
            count = seed_client_types()
            print(f"APEX Seed Phase 2: {count} client types")
        except Exception as e:
            print(f"Phase 2 seed error: {e}")


# ═══════════════════════════════════════════════════════════════
# Routers
# ═══════════════════════════════════════════════════════════════

if KB_AVAILABLE:
    app.include_router(kb_router)
if PHASE1_AVAILABLE:
    app.include_router(phase1_router)
if PHASE2_AVAILABLE:
    app.include_router(phase2_router)


# ═══════════════════════════════════════════════════════════════
# Root / Health
# ═══════════════════════════════════════════════════════════════

@app.get("/")
def root():
    return {
        "name": "APEX Financial Platform API",
        "version": "3.1.0",
        "status": "running",
        "modules": {
            "financial_engine": "active",
            "knowledge_brain": "active" if KB_AVAILABLE else "disabled",
            "platform_core": "active" if PHASE1_AVAILABLE else "disabled",
            "clients_coa": "active" if PHASE2_AVAILABLE else "disabled",
        },
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "version": "3.1.0",
        "knowledge_brain": KB_AVAILABLE,
        "platform_core": PHASE1_AVAILABLE,
        "clients_coa": PHASE2_AVAILABLE,
    }


# ═══════════════════════════════════════════════════════════════
# Financial Analysis (existing — preserved)
# ═══════════════════════════════════════════════════════════════

@app.post("/analyze")
async def analyze_trial_balance(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    closing_inventory: float = Query(None),
):
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")
    try:
        content = await file.read()
        return orchestrator.analyze_bytes(file_bytes=content, filename=file.filename,
                                         industry=industry, closing_inventory=closing_inventory)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ: {str(e)}\n{traceback.format_exc()}")


@app.post("/analyze/full")
async def analyze_with_narrative(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    language: str = Query("ar"),
    closing_inventory: float = Query(None),
):
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")
    content = await file.read()
    try:
        from app.services.ai.narrative_service import NarrativeService
        result = orchestrator.analyze_bytes(file_bytes=content, filename=file.filename,
                                           industry=industry, closing_inventory=closing_inventory)
        if not result.get("success"): return result
        narrator = NarrativeService()
        brain_context = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            brain = KnowledgeBrainService()
            brain_context = brain.get_context_for_narrative(result, result.get("knowledge_brain", {}))
        except: pass
        narrative = await narrator.generate(result, language=language, brain_context=brain_context)
        result["narrative"] = narrative
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ: {str(e)}\n{traceback.format_exc()}")


@app.post("/classify")
async def classify_accounts(file: UploadFile = File(...)):
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")
    try:
        content = await file.read()
        import tempfile
        suffix = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(content); tmp_path = tmp.name
        try: read_result = orchestrator.reader.read(tmp_path)
        finally:
            try: os.unlink(tmp_path)
            except: pass
        raw_rows = read_result["rows"]
        if not raw_rows: return {"success": False, "error": "لم يتم العثور على بيانات"}
        classified = orchestrator.classifier.classify_rows(raw_rows)
        summary = orchestrator.classifier.get_summary(classified)
        return {
            "success": True, "filename": file.filename,
            "total_accounts": len(raw_rows),
            "classification_summary": summary,
            "classified_accounts": [{
                "name": r.get("account_name", r.get("name", "")),
                "tab_raw": r.get("tab_raw", r.get("tab", "")),
                "normalized_class": r.get("normalized_class"),
                "confidence": r.get("confidence", 0),
                "source": r.get("source", ""),
                "section": r.get("section", ""),
                "warnings": r.get("warnings", []),
            } for r in classified],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ: {str(e)}\n{traceback.format_exc()}")


@app.get("/templates/ar")
async def download_template_ar():
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_AR.xlsx")
    if not os.path.exists(path): raise HTTPException(status_code=404, detail="النموذج غير متاح")
    return FileResponse(path, filename="APEX_نموذج_ميزان_المراجعة.xlsx")


@app.get("/templates/en")
async def download_template_en():
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_EN.xlsx")
    if not os.path.exists(path): raise HTTPException(status_code=404, detail="Template not available")
    return FileResponse(path, filename="APEX_Trial_Balance_Template.xlsx")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
