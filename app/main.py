"""
APEX Financial Platform — FastAPI Backend v3.4
Phases 1-5: Identity + Clients + Knowledge + Providers + Marketplace
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
    from app.phase1.routes.phase1_routes import router as p1r
    from app.phase1.services.seed_data import seed_all as seed_p1
    P1 = True
except Exception as e: P1 = False; print(f"P1: {e}")
try:
    from app.phase2.models.phase2_models import *
    from app.phase2.routes.phase2_routes import router as p2r
    from app.phase2.services.seed_phase2 import seed_client_types
    P2 = True
except Exception as e: P2 = False; print(f"P2: {e}")
try:
    from app.phase3.models.phase3_models import *
    from app.phase3.routes.phase3_routes import router as p3r
    P3 = True
except Exception as e: P3 = False; print(f"P3: {e}")
try:
    from app.phase4.models.phase4_models import *
    from app.phase4.routes.phase4_routes import router as p4r
    P4 = True
except Exception as e: P4 = False; print(f"P4: {e}")
try:
    from app.phase5.models.phase5_models import *
    from app.phase5.routes.phase5_routes import router as p5r
    P5 = True
except Exception as e: P5 = False; print(f"P5: {e}")

app = FastAPI(title="APEX Financial Platform API", version="3.4.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
orch = AnalysisOrchestrator()

@app.on_event("startup")
def startup():
    if KB:
        try: init_kb_db()
        except: pass
    if P1:
        try: t = init_platform_db(); print(f"APEX: {len(t)} tables"); print(f"Seed: {seed_p1()}")
        except Exception as e: print(f"P1 err: {e}")
    if P2:
        try: print(f"P2: {seed_client_types()}")
        except Exception as e: print(f"P2 err: {e}")

if KB: app.include_router(kb_router)
if P1: app.include_router(p1r)
if P2: app.include_router(p2r)
if P3: app.include_router(p3r)
if P4: app.include_router(p4r)
if P5: app.include_router(p5r)

@app.get("/")
def root():
    return {"name": "APEX Financial Platform API", "version": "3.4.0", "status": "running",
            "modules": {k: "active" if v else "disabled" for k, v in
                {"engine": True, "kb": KB, "p1": P1, "p2": P2, "p3": P3, "p4": P4, "p5": P5}.items()}}

@app.get("/health")
def health():
    return {"status": "ok", "version": "3.4.0", "phases": {"p1": P1, "p2": P2, "p3": P3, "p4": P4, "p5": P5}}

@app.post("/analyze")
async def analyze(file: UploadFile = File(...), industry: str = Query("general"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    try:
        c = await file.read()
        return orch.analyze_bytes(file_bytes=c, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
    except Exception as e: raise HTTPException(500, f"{e}\n{traceback.format_exc()}")

@app.post("/analyze/full")
async def analyze_full(file: UploadFile = File(...), industry: str = Query("general"), language: str = Query("ar"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    c = await file.read()
    try:
        from app.services.ai.narrative_service import NarrativeService
        r = orch.analyze_bytes(file_bytes=c, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
        if not r.get("success"): return r
        n = NarrativeService(); bc = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            bc = KnowledgeBrainService().get_context_for_narrative(r, r.get("knowledge_brain", {}))
        except: pass
        r["narrative"] = await n.generate(r, language=language, brain_context=bc)
        return r
    except Exception as e: raise HTTPException(500, f"{e}\n{traceback.format_exc()}")

@app.post("/classify")
async def classify(file: UploadFile = File(...)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    try:
        c = await file.read()
        import tempfile
        s = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=s) as tmp: tmp.write(c); tp = tmp.name
        try: rr = orch.reader.read(tp)
        finally:
            try: os.unlink(tp)
            except: pass
        rows = rr["rows"]
        if not rows: return {"success": False, "error": "No data"}
        cl = orch.classifier.classify_rows(rows)
        return {"success": True, "filename": file.filename, "total": len(rows),
                "summary": orch.classifier.get_summary(cl),
                "accounts": [{"name": r.get("account_name", ""), "class": r.get("normalized_class"),
                    "confidence": r.get("confidence", 0)} for r in cl]}
    except Exception as e: raise HTTPException(500, f"{e}\n{traceback.format_exc()}")

if __name__ == "__main__":
    import uvicorn; uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
