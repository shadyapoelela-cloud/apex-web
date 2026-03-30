"""
APEX Financial Platform — FastAPI Backend v3
═══════════════════════════════════════════════════════════════

Phase 1: Identity + Account + Plans + Entitlements + Legal
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

# ═══════════════════════════════════════════════════════════════
# App Setup
# ═══════════════════════════════════════════════════════════════

app = FastAPI(
    title="APEX Financial Platform API",
    description="منصة أبكس للتحليل المالي — محرك مالي محاسبي + ذكاء اصطناعي + عقل معرفي + نظام حسابات",
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

orchestrator = AnalysisOrchestrator()


# ═══════════════════════════════════════════════════════════════
# Startup: Initialize DBs + Seed
# ═══════════════════════════════════════════════════════════════

@app.on_event("startup")
def startup():
    # Knowledge Brain DB
    if KB_AVAILABLE:
        try:
            init_kb_db()
        except Exception:
            pass

    # Phase 1 Platform DB
    if PHASE1_AVAILABLE:
        try:
            tables = init_platform_db()
            print(f"APEX Phase 1: {len(tables)} tables created")
            # Auto-seed on first startup
            result = seed_phase1()
            print(f"APEX Seed: {result}")
        except Exception as e:
            print(f"Phase 1 init error: {e}")


# ═══════════════════════════════════════════════════════════════
# Include Routers
# ═══════════════════════════════════════════════════════════════

if KB_AVAILABLE:
    app.include_router(kb_router)

if PHASE1_AVAILABLE:
    app.include_router(phase1_router)


# ═══════════════════════════════════════════════════════════════
# Root / Health
# ═══════════════════════════════════════════════════════════════

@app.get("/")
def root():
    return {
        "name": "APEX Financial Platform API",
        "version": "3.0.0",
        "status": "running",
        "modules": {
            "financial_engine": "active",
            "knowledge_brain": "active" if KB_AVAILABLE else "disabled",
            "platform_core": "active" if PHASE1_AVAILABLE else "disabled",
        },
        "endpoints": {
            "تحليل ميزان المراجعة": "POST /analyze",
            "تصنيف الحسابات": "POST /classify",
            "التسجيل": "POST /auth/register",
            "الدخول": "POST /auth/login",
            "الخطط": "GET /plans",
            "حسابي": "GET /users/me",
            "العقل المعرفي": "GET /knowledge/stats",
            "التوثيق": "GET /docs",
        },
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "version": "3.0.0",
        "knowledge_brain": KB_AVAILABLE,
        "platform_core": PHASE1_AVAILABLE,
    }


# ═══════════════════════════════════════════════════════════════
# Financial Analysis Endpoints (existing — preserved as-is)
# ═══════════════════════════════════════════════════════════════

@app.post("/analyze")
async def analyze_trial_balance(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    closing_inventory: float = Query(None),
):
    """تحليل شامل لميزان المراجعة."""
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")

    try:
        content = await file.read()
        result = orchestrator.analyze_bytes(
            file_bytes=content,
            filename=file.filename,
            industry=industry,
            closing_inventory=closing_inventory,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ في التحليل: {str(e)}\n{traceback.format_exc()}")


@app.post("/analyze/full")
async def analyze_with_narrative(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    language: str = Query("ar"),
    closing_inventory: float = Query(None),
):
    """تحليل شامل + تقرير AI."""
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")

    content = await file.read()
    print(f"APEX: ci={closing_inventory}, file_size={len(content)}, filename={file.filename}")

    try:
        from app.services.ai.narrative_service import NarrativeService

        result = orchestrator.analyze_bytes(
            file_bytes=content,
            filename=file.filename,
            industry=industry,
            closing_inventory=closing_inventory,
        )

        if not result.get("success"):
            return result

        narrator = NarrativeService()

        brain_context = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            brain = KnowledgeBrainService()
            brain_result = result.get("knowledge_brain", {})
            brain_context = brain.get_context_for_narrative(result, brain_result)
        except Exception:
            pass

        narrative = await narrator.generate(result, language=language, brain_context=brain_context)
        result["narrative"] = narrative
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ: {str(e)}\n{traceback.format_exc()}")


@app.post("/classify")
async def classify_accounts(file: UploadFile = File(...)):
    """تصنيف حسابات ميزان المراجعة فقط."""
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="يُقبل فقط ملفات Excel (.xlsx)")

    try:
        content = await file.read()
        import tempfile
        suffix = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(content)
            tmp_path = tmp.name

        try:
            read_result = orchestrator.reader.read(tmp_path)
        finally:
            try: os.unlink(tmp_path)
            except: pass

        raw_rows = read_result["rows"]
        if not raw_rows:
            return {"success": False, "error": "لم يتم العثور على بيانات"}

        classified = orchestrator.classifier.classify_rows(raw_rows)
        summary = orchestrator.classifier.get_summary(classified)

        return {
            "success": True,
            "filename": file.filename,
            "total_accounts": len(raw_rows),
            "classification_summary": summary,
            "classified_accounts": [
                {
                    "name": r.get("account_name", r.get("name", "")),
                    "tab_raw": r.get("tab_raw", r.get("tab", "")),
                    "normalized_class": r.get("normalized_class"),
                    "confidence": r.get("confidence", 0),
                    "source": r.get("source", ""),
                    "ar_label": r.get("ar_label", ""),
                    "en_label": r.get("en_label", ""),
                    "section": r.get("section", ""),
                    "warnings": r.get("warnings", []),
                }
                for r in classified
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ: {str(e)}\n{traceback.format_exc()}")


# ═══════════════════════════════════════════════════════════════
# Template Downloads (existing)
# ═══════════════════════════════════════════════════════════════

@app.get("/templates/ar")
async def download_template_ar():
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_AR.xlsx")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="النموذج غير متاح")
    return FileResponse(path, filename="APEX_نموذج_ميزان_المراجعة.xlsx")


@app.get("/templates/en")
async def download_template_en():
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_EN.xlsx")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Template not available")
    return FileResponse(path, filename="APEX_Trial_Balance_Template.xlsx")


# ═══════════════════════════════════════════════════════════════
# Run
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
