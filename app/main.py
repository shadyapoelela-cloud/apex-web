"""
APEX Financial Platform — FastAPI Backend v3.5 (FINAL)
═══════════════════════════════════════════════════════════════
All 6 Phases Complete:
  P1: Identity + Auth + Plans + Legal
  P2: Clients + COA + Results + Explanations
  P3: Knowledge Governance + Review Queue
  P4: Provider Onboarding + Verification
  P5: Marketplace + Compliance + Suspension
  P6: Admin Dashboard + Reviewer Tooling
+ Financial Engine v2 + Knowledge Brain
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import os, traceback
from app.services.orchestrator import AnalysisOrchestrator
from fastapi.responses import Response as PDFResponse

try:
    from app.knowledge_brain.api.routes.knowledge_routes import router as kb_r
    from app.knowledge_brain.models.db_models import init_db as init_kb
    KB = True
except: KB = False
try:
    from app.phase1.models.platform_models import init_platform_db
    from app.phase1.routes.phase1_routes import router as p1r
    from app.phase1.services.seed_data import seed_all as seed1
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
try:
    from app.phase6.routes.phase6_routes import router as p6r
    P6 = True
except Exception as e: P6 = False; print(f"P6: {e}")

app = FastAPI(title="APEX Financial Platform API", description="منصة أبكس للتحليل المالي — النسخة النهائية", version="3.5.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
orch = AnalysisOrchestrator()
from fastapi.responses import JSONResponse
import traceback as _tb

@app.exception_handler(Exception)
async def debug_exception_handler(request, exc):
    return JSONResponse(status_code=500, content={"error": str(exc), "traceback": _tb.format_exc()})


@app.on_event("startup")
def startup():
    if KB:
        try: init_kb()
        except: pass
    if P1:
        try: t = init_platform_db(); print(f"APEX: {len(t)} tables"); print(f"Seed: {seed1()}")
        except Exception as e: print(f"P1 err: {e}")
    if P2:
        try: print(f"P2: {seed_client_types()}")
        except Exception as e: print(f"P2 err: {e}")

for flag, r in [(KB, kb_r if KB else None), (P1, p1r if P1 else None), (P2, p2r if P2 else None),
                (P3, p3r if P3 else None), (P4, p4r if P4 else None), (P5, p5r if P5 else None),
                (P6, p6r if P6 else None)]:
    if flag and r: app.include_router(r)

@app.get("/")
def root():
    return {"name": "APEX Financial Platform API", "version": "3.5.0", "status": "running",
            "phases_active": sum([P1, P2, P3, P4, P5, P6]),
            "modules": {k: "active" if v else "disabled" for k, v in
                {"engine": True, "kb": KB, "p1_identity": P1, "p2_clients": P2, "p3_knowledge": P3,
                 "p4_providers": P4, "p5_marketplace": P5, "p6_admin": P6}.items()}}

@app.get("/health")
def health():
    return {"status": "ok", "version": "3.5.0",
            "phases": {"p1": P1, "p2": P2, "p3": P3, "p4": P4, "p5": P5, "p6": P6},
            "all_phases_active": all([P1, P2, P3, P4, P5, P6])}

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


@app.post("/analyze/report", tags=["Analysis"])
async def analyze_report(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    closing_inventory: float = Query(0),
    client_name: str = Query(""),
    authorization: str = Header(None),
):
    """Analyze trial balance and return PDF report."""
    from app.services.pdf_report_service import generate_pdf_report
    contents = await file.read()
    result = orch.analyze(contents, file.filename, industry, closing_inventory)
    user_name = ""
    if authorization and authorization.startswith("Bearer "):
        try:
            import jwt as _jwt
            payload = _jwt.decode(authorization.split(" ")[1],
                os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION"),
                algorithms=["HS256"])
            user_name = payload.get("username", "")
        except: pass
    from datetime import datetime as _dt
    pdf_bytes = generate_pdf_report(result, client_name=client_name, user_name=user_name)
    return PDFResponse(content=pdf_bytes, media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=APEX_Report_{_dt.now().strftime('%Y%m%d_%H%M')}.pdf"})

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
