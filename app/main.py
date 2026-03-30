"""
APEX Financial Platform — FastAPI Backend v2
═════════════════════════════════════════════

Clean API with modular financial engine.
AI does NOT modify any numbers.
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import os

from app.services.orchestrator import AnalysisOrchestrator

# ─── Knowledge Brain ───
try:
    from app.knowledge_brain.api.routes.knowledge_routes import router as kb_router
    from app.knowledge_brain.models.db_models import init_db
    KB_AVAILABLE = True
except Exception:
    KB_AVAILABLE = False

# ─── App Setup ───────────────────────────────────────────────────────────────

app = FastAPI(
    title="APEX Financial Platform API",
    description="منصة أبكس للتحليل المالي — محرك مالي محاسبي مع ذكاء اصطناعي",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

orchestrator = AnalysisOrchestrator()


# ─── Health ──────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {
        "name": "APEX Financial Platform API",
        "version": "2.0.0",
        "status": "running",
        "engine": "Financial Engine v2 — modular architecture",
        "knowledge_brain": "active" if KB_AVAILABLE else "disabled",
        "endpoints": {
            "تحليل ميزان المراجعة": "POST /analyze",
            "تصنيف الحسابات فقط": "POST /classify",
            "العقل المعرفي": "GET /knowledge/stats",
            "التوثيق": "GET /docs",
        },
    }

# Include Knowledge Brain routes
if KB_AVAILABLE:
    app.include_router(kb_router)
    # Initialize DB on startup
    @app.on_event("startup")
    def startup_init_kb():
        try:
            init_db()
        except Exception:
            pass


@app.get("/health")
def health():
    return {"status": "ok", "version": "2.0.0"}


# ─── Main Analysis ──────────────────────────────────────────────────────────

@app.post("/analyze")
async def analyze_trial_balance(
    file: UploadFile = File(...),
    industry: str = Query("general", description="القطاع: general, retail, manufacturing, services, construction, food_beverage"),
    closing_inventory: float = Query(None, description="مخزون آخر المدة الفعلي (من الجرد) — مطلوب للجرد الدوري"),
):
    """
    تحليل شامل لميزان المراجعة.

    يشمل: قائمة الدخل + الميزانية + التدفقات + النسب + الجاهزية + التحققات + مراجعة التبويب.
    المحرك المالي يحسب كل شي — AI لا يغيّر أي رقم.

    للشركات التي تستخدم الجرد الدوري: أرسل closing_inventory مع قيمة المخزون الفعلي في نهاية الفترة.
    """
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
        import traceback
        raise HTTPException(
            status_code=500,
            detail=f"خطأ في التحليل: {str(e)}\n{traceback.format_exc()}"
        )


# ─── Full Analysis with AI Narrative ─────────────────────────────────────

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
    print(f"APEX: ci={closing_inventory}, file_size={len(content)}")

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

        # Step 2: AI Narrative with Brain context (does NOT modify numbers)
        narrator = NarrativeService()

        # Get brain context for AI
        brain_context = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            brain = KnowledgeBrainService()
            brain_result = result.get("knowledge_brain", {})
            brain_context = brain.get_context_for_narrative(result, brain_result)
        except Exception:
            pass

        narrative = await narrator.generate(result, language=language, brain_context=brain_context)

        # Merge narrative into result
        result["narrative"] = narrative

        return result

    except Exception as e:
        import traceback
        raise HTTPException(
            status_code=500,
            detail=f"خطأ: {str(e)}\n{traceback.format_exc()}"
        )


# ─── Classification Only ────────────────────────────────────────────────────

@app.post("/classify")
async def classify_accounts(file: UploadFile = File(...)):
    """
    تصنيف حسابات ميزان المراجعة فقط — بدون بناء القوائم.
    مفيد لمراجعة التبويب قبل التحليل الكامل.
    """
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
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

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
        import traceback
        raise HTTPException(status_code=500, detail=f"خطأ: {str(e)}\n{traceback.format_exc()}")


# ─── Template Downloads ─────────────────────────────────────────────────────

@app.get("/templates/ar")
async def download_template_ar():
    """تحميل نموذج ميزان المراجعة المعتمد — عربي"""
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_AR.xlsx")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="النموذج غير متاح")
    return FileResponse(path, filename="APEX_نموذج_ميزان_المراجعة_المعتمد.xlsx")


@app.get("/templates/en")
async def download_template_en():
    """Download approved trial balance template — English"""
    from starlette.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), "data", "templates", "APEX_Template_EN.xlsx")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Template not available")
    return FileResponse(path, filename="APEX_Trial_Balance_Template.xlsx")


# ─── Run ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
