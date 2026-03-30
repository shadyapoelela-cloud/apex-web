"""
APEX Financial Platform — FastAPI Backend v3.2
═══════════════════════════════════════════════════════════════
Phase 1: Identity + Account + Plans + Entitlements + Legal
Phase 2: Clients + COA + Analysis Results + Explanations (! icon)
Phase 3: Knowledge Feedback + Review Queue + Candidate Rules
+ Existing: Financial Engine v2 + Knowledge Brain
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Query
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

# ─── Phase 1 ───
try:
    from app.phase1.models.platform_models import init_platform_db
    from app.phase1.routes.phase1_routes import router as phase1_router
    from app.phase1.services.seed_data import seed_all as seed_phase1
    PHASE1_AVAILABLE = True
except Exception as e:
    PHASE1_AVAILABLE = False
    print(f"Phase 1 error: {e}")

# ─── Phase 2 ───
try:
    from app.phase2.models.phase2_models import *
    from app.phase2.routes.phase2_routes import router as phase2_router
    from app.phase2.services.seed_phase2 import seed_client_types
    PHASE2_AVAILABLE = True
except Exception as e:
    PHASE2_AVAILABLE = False
    print(f"Phase 2 error: {e}")

# ─── Phase 3 ───
try:
    from app.phase3.models.phase3_models import *
    from app.phase3.routes.phase3_routes import router as phase3_router
    PHASE3_AVAILABLE = True
except Exception as e:
    PHASE3_AVAILABLE = False
    print(f"Phase 3 error: {e}")

# ═══════════════════════════════════════════════════════════════
app = FastAPI(
    title="APEX Financial Platform API",
    description="منصة أبكس — تحليل مالي + ذكاء اصطناعي + عقل معرفي + حوكمة معرفية",
    version="3.2.0",
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
orchestrator = AnalysisOrchestrator()

@app.on_event("startup")
def startup():
    if KB_AVAILABLE:
        try: init_kb_db()
        except: pass
    if PHASE1_AVAILABLE:
        try:
            tables = init_platform_db()
            print(f"APEX: {len(tables)} tables")
            print(f"Seed P1: {seed_phase1()}")
        except Exception as e: print(f"P1 err: {e}")
    if PHASE2_AVAILABLE:
        try: print(f"Seed P2: {seed_client_types()} types")
        except Exception as e: print(f"P2 err: {e}")

if KB_AVAILABLE: app.include_router(kb_router)
if PHASE1_AVAILABLE: app.include_router(phase1_router)
if PHASE2_AVAILABLE: app.include_router(phase2_router)
if PHASE3_AVAILABLE: app.include_router(phase3_router)

@app.get("/")
def root():
    return {
        "name": "APEX Financial Platform API", "version": "3.2.0", "status": "running",
        "modules": {
            "financial_engine": "active",
            "knowledge_brain": "active" if KB_AVAILABLE else "disabled",
            "platform_core": "active" if PHASE1_AVAILABLE else "disabled",
            "clients_coa": "active" if PHASE2_AVAILABLE else "disabled",
            "knowledge_governance": "active" if PHASE3_AVAILABLE else "disabled",
        },
    }

@app.get("/health")
def health():
    return {"status": "ok", "version": "3.2.0", "phases": {"p1": PHASE1_AVAILABLE, "p2": PHASE2_AVAILABLE, "p3": PHASE3_AVAILABLE}}

# ═══════════════════════════════════════════════════════════════
# Financial Analysis (preserved)
# ═══════════════════════════════════════════════════════════════
@app.post("/analyze")
async def analyze_trial_balance(file: UploadFile = File(...), industry: str = Query("general"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "يُقبل فقط Excel")
    try:
        content = await file.read()
        return orchestrator.analyze_bytes(file_bytes=content, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
    except Exception as e: raise HTTPException(500, f"خطأ: {e}\n{traceback.format_exc()}")

@app.post("/analyze/full")
async def analyze_with_narrative(file: UploadFile = File(...), industry: str = Query("general"), language: str = Query("ar"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "يُقبل فقط Excel")
    content = await file.read()
    try:
        from app.services.ai.narrative_service import NarrativeService
        result = orchestrator.analyze_bytes(file_bytes=content, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
        if not result.get("success"): return result
        narrator = NarrativeService()
        brain_context = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            brain = KnowledgeBrainService()
            brain_context = brain.get_context_for_narrative(result, result.get("knowledge_brain", {}))
        except: pass
        result["narrative"] = await narrator.generate(result, language=language, brain_context=brain_context)
        return result
    except Exception as e: raise HTTPException(500, f"خطأ: {e}\n{traceback.format_exc()}")

@app.post("/classify")
async def classify_accounts(file: UploadFile = File(...)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "يُقبل فقط Excel")
    try:
        content = await file.read()
        import tempfile
        suffix = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp: tmp.write(content); tmp_path = tmp.name
        try: read_result = orchestrator.reader.read(tmp_path)
        finally:
            try: os.unlink(tmp_path)
            except: pass
        raw_rows = read_result["rows"]
        if not raw_rows: return {"success": False, "error": "لم يتم العثور على بيانات"}
        classified = orchestrator.classifier.classify_rows(raw_rows)
        return {"success": True, "filename": file.filename, "total_accounts": len(raw_rows),
                "classification_summary": orchestrator.classifier.get_summary(classified),
                "classified_accounts": [{"name": r.get("account_name", r.get("name", "")), "tab_raw": r.get("tab_raw", ""),
                    "normalized_class": r.get("normalized_class"), "confidence": r.get("confidence", 0),
                    "source": r.get("source", ""), "section": r.get("section", "")} for r in classified]}
    except Exception as e: raise HTTPException(500, f"خطأ: {e}\n{traceback.format_exc()}")

@app.get("/templates/ar")
async def download_template_ar():
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_AR.xlsx")
    if not os.path.exists(path): raise HTTPException(404, "غير متاح")
    return FileResponse(path, filename="APEX_نموذج.xlsx")

@app.get("/templates/en")
async def download_template_en():
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_EN.xlsx")
    if not os.path.exists(path): raise HTTPException(404, "Not available")
    return FileResponse(path, filename="APEX_Template.xlsx")

if __name__ == "__main__":
    import uvicorn; uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
