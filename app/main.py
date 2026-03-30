"""
APEX Financial Platform — FastAPI Backend v3.3
Phases 1-4: Identity + Clients + Knowledge + Providers
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import os, traceback
from app.services.orchestrator import AnalysisOrchestrator

try:
    from app.knowledge_brain.api.routes.knowledge_routes import router as kb_router
    from app.knowledge_brain.models.db_models import init_db as init_kb_db
    KB = True
except: KB = False

try:
    from app.phase1.models.platform_models import init_platform_db
    from app.phase1.routes.phase1_routes import router as p1_router
    from app.phase1.services.seed_data import seed_all as seed_p1
    P1 = True
except Exception as e: P1 = False; print(f"P1: {e}")

try:
    from app.phase2.models.phase2_models import *
    from app.phase2.routes.phase2_routes import router as p2_router
    from app.phase2.services.seed_phase2 import seed_client_types
    P2 = True
except Exception as e: P2 = False; print(f"P2: {e}")

try:
    from app.phase3.models.phase3_models import *
    from app.phase3.routes.phase3_routes import router as p3_router
    P3 = True
except Exception as e: P3 = False; print(f"P3: {e}")

try:
    from app.phase4.models.phase4_models import *
    from app.phase4.routes.phase4_routes import router as p4_router
    P4 = True
except Exception as e: P4 = False; print(f"P4: {e}")

app = FastAPI(title="APEX Financial Platform API", version="3.3.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
orchestrator = AnalysisOrchestrator()

@app.on_event("startup")
def startup():
    if KB:
        try: init_kb_db()
        except: pass
    if P1:
        try: t = init_platform_db(); print(f"APEX: {len(t)} tables"); print(f"Seed: {seed_p1()}")
        except Exception as e: print(f"P1 err: {e}")
    if P2:
        try: print(f"P2 seed: {seed_client_types()}")
        except Exception as e: print(f"P2 err: {e}")

if KB: app.include_router(kb_router)
if P1: app.include_router(p1_router)
if P2: app.include_router(p2_router)
if P3: app.include_router(p3_router)
if P4: app.include_router(p4_router)

@app.get("/")
def root():
    return {"name": "APEX Financial Platform API", "version": "3.3.0", "status": "running",
            "modules": {k: "active" if v else "disabled" for k, v in
                        {"financial_engine": True, "knowledge_brain": KB, "platform_core": P1,
                         "clients_coa": P2, "knowledge_governance": P3, "providers": P4}.items()}}

@app.get("/health")
def health():
    return {"status": "ok", "version": "3.3.0", "phases": {"p1": P1, "p2": P2, "p3": P3, "p4": P4}}

@app.post("/analyze")
async def analyze(file: UploadFile = File(...), industry: str = Query("general"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    try:
        content = await file.read()
        return orchestrator.analyze_bytes(file_bytes=content, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
    except Exception as e: raise HTTPException(500, f"{e}\n{traceback.format_exc()}")

@app.post("/analyze/full")
async def analyze_full(file: UploadFile = File(...), industry: str = Query("general"), language: str = Query("ar"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    content = await file.read()
    try:
        from app.services.ai.narrative_service import NarrativeService
        result = orchestrator.analyze_bytes(file_bytes=content, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
        if not result.get("success"): return result
        narrator = NarrativeService()
        bc = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            bc = KnowledgeBrainService().get_context_for_narrative(result, result.get("knowledge_brain", {}))
        except: pass
        result["narrative"] = await narrator.generate(result, language=language, brain_context=bc)
        return result
    except Exception as e: raise HTTPException(500, f"{e}\n{traceback.format_exc()}")

@app.post("/classify")
async def classify(file: UploadFile = File(...)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    try:
        content = await file.read()
        import tempfile
        suffix = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp: tmp.write(content); tmp_path = tmp.name
        try: rr = orchestrator.reader.read(tmp_path)
        finally:
            try: os.unlink(tmp_path)
            except: pass
        rows = rr["rows"]
        if not rows: return {"success": False, "error": "No data"}
        cl = orchestrator.classifier.classify_rows(rows)
        return {"success": True, "filename": file.filename, "total_accounts": len(rows),
                "classification_summary": orchestrator.classifier.get_summary(cl),
                "classified_accounts": [{"name": r.get("account_name", r.get("name", "")), "tab_raw": r.get("tab_raw", ""),
                    "normalized_class": r.get("normalized_class"), "confidence": r.get("confidence", 0),
                    "source": r.get("source", ""), "section": r.get("section", "")} for r in cl]}
    except Exception as e: raise HTTPException(500, f"{e}\n{traceback.format_exc()}")

if __name__ == "__main__":
    import uvicorn; uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
