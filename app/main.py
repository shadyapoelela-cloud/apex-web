"""
APEX Financial Platform -- FastAPI Backend v9.0
================================================================
All 11 Phases + 6 Sprints:
  P1: Identity + Auth + Plans + Legal
  P2: Clients + COA + Results + Explanations
  P3: Knowledge Governance + Review Queue
  P4: Provider Onboarding + Verification
  P5: Marketplace + Compliance + Suspension
  P6: Admin Dashboard + Reviewer Tooling
  P7: Task Documents + Suspension + Audit
  P8: Entitlements Engine + Subscriptions
  P9: Account Center
  P10: Notification System
  P11: Legal Acceptance
+ Financial Engine v2 + Knowledge Brain + Copilot AI
+ Sprints 1-6: COA Workflow, Classification, Quality, KB, TB, Registry
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Header
from fastapi.middleware.cors import CORSMiddleware
import os, traceback, logging
from app.services.orchestrator import AnalysisOrchestrator

ADMIN_SECRET = os.environ.get("ADMIN_SECRET", "apex-admin-2026")
if ADMIN_SECRET == "apex-admin-2026":
    logging.warning("ADMIN_SECRET is using default value! Set ADMIN_SECRET env var in production.")
from fastapi.responses import Response as PDFResponse
try:
    from app.knowledge_brain.api.routes.knowledge_routes import router as kb_r
    from app.knowledge_brain.models.db_models import init_db as init_kb
    KB = True
except Exception as e: KB = False; logging.warning(f"Knowledge Brain disabled: {e}")
try:
    from app.phase1.models.platform_models import init_platform_db
    from app.phase1.routes.phase1_routes import router as p1r
    from app.phase1.services.seed_data import seed_all as seed1
    P1 = True
except Exception as e: P1 = False; logging.warning(f"Phase 1 disabled: {e}")
try:
    from app.phase2.routes.phase2_routes import router as p2r
    from app.phase2.services.seed_phase2 import seed_client_types
    P2 = True
except Exception as e: P2 = False; logging.warning(f"Phase 2 disabled: {e}")
try:
    from app.phase3.routes.phase3_routes import router as p3r
    P3 = True
except Exception as e: P3 = False; logging.warning(f"Phase 3 disabled: {e}")
try:
    from app.phase4.models.phase4_models import init_phase4_db
    from app.phase4.routes.phase4_routes import router as p4r
    P4 = True
except Exception as e: P4 = False; logging.warning(f"Phase 4 disabled: {e}")
try:
    from app.phase5.models.phase5_models import init_phase5_db
    from app.phase5.routes.phase5_routes import router as p5r
    P5 = True
except Exception as e: P5 = False; logging.warning(f"Phase 5 disabled: {e}")
try:
    from app.phase6.routes.phase6_routes import router as p6r
    P6 = True
except Exception as e: P6 = False; logging.warning(f"Phase 6 disabled: {e}")
# Phase 7 â€” Task Documents + Suspension + Result Details + Audit
try:
    from app.phase7.models.phase7_models import init_phase7_db, P7ResultExplanation
    from app.phase7.routes.phase7_routes import router as p7r
    from app.phase7.services.seed_phase7 import seed_task_types
    HAS_P7 = True
except Exception as e:
    logging.warning(f"Phase 7 disabled: {e}")
    HAS_P7 = False
# Phase 8 â€” Entitlements Engine + Subscription Management
try:
    from app.phase8.models.phase8_models import init_phase8_db
    from app.phase8.routes.phase8_routes import router as p8r
    from app.phase8.services.seed_phase8 import seed_plan_limits, create_user_subscription
    HAS_P8 = True
except Exception as e:
    logging.warning(f"Phase 8 disabled: {e}")
    HAS_P8 = False
# Phase 9 â€” Account Center
try:
    from app.phase9.models.phase9_models import init_phase9_db
    from app.phase9.routes.phase9_routes import router as p9r
    HAS_P9 = True
except Exception as e:
    HAS_P9 = False
    logging.warning(f"Phase 9 disabled: {e}")
# Phase 10 â€” Notification System
try:
    from app.phase10.models.phase10_models import init_phase10_db
    from app.phase10.routes.phase10_routes import router as p10r
    from app.phase10.services.notification_service import seed_welcome_notification
    HAS_P10 = True
except Exception as e:
    HAS_P10 = False
    logging.warning(f"Phase 10 disabled: {e}")
# Sprint 1 â€” COA First Workflow
try:
    from app.sprint1.models.sprint1_models import init_sprint1_db
    from app.sprint1.routes.sprint1_routes import router as s1r
    HAS_S1 = True
except Exception as e:
    HAS_S1 = False
    logging.warning(f"Sprint 1 disabled: {e}")
# Sprint 2 â€” COA Classification Engine
try:
    from app.sprint2.routes.sprint2_routes import router as s2r
    HAS_S2 = True
except Exception as e:
    HAS_S2 = False
    logging.warning(f"Sprint 2 disabled: {e}")
# Sprint 4 â€” Knowledge Brain
try:
    from app.sprint4.routes.sprint4_routes import router as s4r
    HAS_S4 = True
except Exception as e:
    HAS_S4 = False
    logging.warning(f"Sprint 4 disabled: {e}")
# --- Sprint 3: COA Quality + Review ---
HAS_S3 = False
try:
    from app.sprint3.routes.sprint3_routes import router as s3r
    HAS_S3 = True
except Exception as e:
    logging.warning(f"Sprint 3 disabled: {e}")
# --- Sprint 4 TB: Trial Balance + Binding ---
HAS_S4_TB = False
try:
    from app.sprint4_tb.routes.tb_routes import router as s4_tb_r
    HAS_S4_TB = True
except Exception as e:
    logging.warning(f"Sprint 4 TB disabled: {e}")
# --- Sprint 5: Analysis Trigger ---
HAS_S5 = False
try:
    from app.sprint5_analysis.routes.analysis_routes import router as s5r
    HAS_S5 = True
except Exception as e:
    logging.warning(f"Sprint 5 disabled: {e}")
# --- Sprint 6: Official Source Registry + Eligibility ---
HAS_S6 = False
try:
    from app.sprint6_registry.routes.registry_routes import router as s6r
    HAS_S6 = True
except Exception as e:
    logging.warning(f"Sprint 6 disabled: {e}")
# Phase 11 â€” Legal Acceptance
try:
    from app.phase11.models.phase11_models import init_phase11_db
    from app.phase11.routes.phase11_routes import router as p11r
    from app.phase11.services.legal_service import seed_legal_documents
    HAS_P11 = True
except Exception as e:
    HAS_P11 = False
    logging.warning(f"Phase 11 disabled: {e}")


app = FastAPI(title=”APEX Financial Platform API”, description=”APEX Financial Analysis Platform - All 11 Phases + 6 Sprints”, version=”9.0.0”)
_cors_origins = os.environ.get("CORS_ORIGINS", "").split(",") if os.environ.get("CORS_ORIGINS") else ["*"]
app.add_middleware(CORSMiddleware, allow_origins=_cors_origins, allow_credentials=True, allow_methods=["*"], allow_headers=["*"], expose_headers=["Content-Disposition"])
orch = AnalysisOrchestrator()
from fastapi.responses import JSONResponse
import traceback as _tb

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    import logging
    logging.error(f"Unhandled: {exc}")
    import traceback; logging.error(traceback.format_exc()); return JSONResponse(status_code=500, content={"detail": "Internal server error"})


@app.on_event("startup")
def startup():
    if KB:
        try: init_kb()
        except Exception as e: logging.error(f"Knowledge Brain init error: {e}")
    if P1:
        try: t = init_platform_db(); logging.info(f"APEX: {len(t)} tables"); seed1()
        except Exception as e: logging.error(f"Phase 1 startup error: {e}")
    if P2:
        try: seed_client_types()
        except Exception as e: logging.error(f"Phase 2 startup error: {e}")
    if P4:
        try: init_phase4_db()
        except Exception as e: logging.error(f"Phase 4 init error: {e}")
    if P5:
        try: init_phase5_db()
        except Exception as e: logging.error(f"Phase 5 init error: {e}")
    if HAS_P7:
        try: init_phase7_db(); seed_task_types()
        except Exception as e: logging.error(f"Phase 7 init error: {e}")
    if HAS_P8:
        try: init_phase8_db(); seed_plan_limits()
        except Exception as e: logging.error(f"Phase 8 init error: {e}")
    if HAS_P9:
        try: init_phase9_db()
        except Exception as e: logging.error(f"Phase 9 init error: {e}")
    if HAS_P10:
        try: init_phase10_db(); seed_welcome_notification()
        except Exception as e: logging.error(f"Phase 10 init error: {e}")
    if HAS_P11:
        try: init_phase11_db(); seed_legal_documents()
        except Exception as e: logging.error(f"Phase 11 init error: {e}")
    if HAS_S1:
        try: init_sprint1_db()
        except Exception as e: logging.error(f"Sprint 1 init error: {e}")
    try:
        from app.copilot.models.copilot_models import init_copilot_db
        init_copilot_db()
    except Exception as e: logging.error(f"Copilot init error: {e}")

for flag, r in [(KB, kb_r if KB else None), (P1, p1r if P1 else None), (P2, p2r if P2 else None),
                (P3, p3r if P3 else None), (P4, p4r if P4 else None), (P5, p5r if P5 else None),
                (P6, p6r if P6 else None)]:
    if flag and r: app.include_router(r)

# Phase 7-11 routers
if HAS_P7:
    app.include_router(p7r, prefix="", tags=["Phase 7"])
if HAS_P8:
    app.include_router(p8r, prefix="", tags=["Phase 8"])
if HAS_P9:
    app.include_router(p9r, tags=["Phase 9"])
if HAS_P10:
    app.include_router(p10r, tags=["Phase 10"])
if HAS_P11:
    app.include_router(p11r, tags=["Phase 11"])
if HAS_S1:
    app.include_router(s1r, tags=["Sprint 1 COA"])
if HAS_S2:
    app.include_router(s2r, tags=["Sprint 2 Classification"])
if HAS_S4:
    app.include_router(s4r, tags=["Sprint 4 Knowledge Brain"])
if HAS_S3:
    app.include_router(s3r, tags=["Sprint 3 COA Quality"])
if HAS_S4_TB:
    app.include_router(s4_tb_r, tags=["Sprint 4 TB Binding"])
if HAS_S5:
    app.include_router(s5r, tags=["Sprint 5 Analysis Trigger"])
if HAS_S6:
    app.include_router(s6r, tags=["Sprint 6 Registry + Eligibility"])

# ── New Routes (P0-P4) ──
from app.phase2.routes.onboarding_routes import router as onboarding_r
from app.phase2.routes.archive_routes import router as archive_r
from app.phase2.routes.service_catalog_routes import router as catalog_r
from app.phase1.routes.social_auth_routes import router as social_auth_r
from app.copilot.routes.copilot_routes import router as copilot_router
app.include_router(onboarding_r, tags=["Onboarding"])
app.include_router(archive_r, tags=["Archive"])
app.include_router(catalog_r, tags=["Service Catalog"])
app.include_router(social_auth_r, tags=["Social Auth"])
app.include_router(copilot_router)

@app.get("/")
def root():
    phases = [P1, P2, P3, P4, P5, P6, HAS_P7, HAS_P8, HAS_P9, HAS_P10, HAS_P11]
    return {"name": "APEX Financial Platform API", "version": "9.0.0", "status": "running",
            "phases_active": sum(phases), "phases_total": 11,
            "modules": {k: "active" if v else "disabled" for k, v in
                {"engine": True, "kb": KB, "p1_identity": P1, "p2_clients": P2, "p3_knowledge": P3,
                 "p4_providers": P4, "p5_marketplace": P5, "p6_admin": P6,
                 "p7_tasks": HAS_P7, "p8_entitlements": HAS_P8, "p9_account": HAS_P9,
                 "p10_notifications": HAS_P10, "p11_legal": HAS_P11}.items()}}


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# ADMIN ENDPOINTS
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

@app.get("/admin/reinit-db")
def reinit_db(secret: str = Query(...)):
    if secret != ADMIN_SECRET:
        raise HTTPException(403, "Invalid secret")
    results = {}

    # Phase 1 â€” Core tables
    try:
        from app.phase1.models.platform_models import Base, engine
        Base.metadata.create_all(bind=engine, checkfirst=True)
        results["phase1"] = "OK"
    except Exception as e:
        results["phase1"] = str(e)[:200]

    # Seed data
    try:
        from app.phase1.services.seed_data import seed_all
        results["seed1"] = seed_all()
    except Exception as e:
        results["seed1"] = str(e)[:200]

    # Phase 7 seed
    if HAS_P7:
        try:
            from app.phase7.services.seed_phase7 import seed_task_types
            results["phase7_seed"] = seed_task_types()
        except Exception as e:
            results["phase7"] = str(e)[:200]

    # Phase 9-11 init
    try:
        if HAS_P9:
            init_phase9_db()
            results["phase9"] = "OK"
    except Exception as e:
        results["phase9"] = str(e)[:80]
    try:
        if HAS_P10:
            init_phase10_db()
            results["phase10"] = "OK"
    except Exception as e:
        results["phase10"] = str(e)[:80]
    try:
        if HAS_P11:
            init_phase11_db()
            from app.phase11.services.legal_service import seed_legal_documents
            seed_result = seed_legal_documents()
            results["phase11"] = f"OK - {seed_result}"
    except Exception as e:
        results["phase11"] = str(e)[:80]

    # Sprint 2 classification columns
    try:
        from app.phase1.models.platform_models import SessionLocal, engine as _eng
        from sqlalchemy import text as _t2, inspect as _insp2
        inspector = _insp2(_eng)
        existing_cols = []
        try:
            existing_cols = [c["name"] for c in inspector.get_columns("client_chart_of_accounts")]
        except Exception:
            pass
        _cols = [("normalized_class","VARCHAR(100)"),("statement_section","VARCHAR(100)"),("subcategory","VARCHAR(200)"),("current_noncurrent","VARCHAR(20)"),("cashflow_role","VARCHAR(50)"),("sign_rule","VARCHAR(20)"),("mapping_confidence","REAL DEFAULT 0.0"),("mapping_source","VARCHAR(50)"),("review_status","VARCHAR(50) DEFAULT 'draft'"),("approved_by","VARCHAR(255)"),("approved_at","TIMESTAMP"),("classification_issues_json","TEXT DEFAULT '[]'")]
        db = SessionLocal()
        added = 0
        for _cn, _ct in _cols:
            if _cn not in existing_cols:
                try:
                    db.execute(_t2(f"ALTER TABLE client_chart_of_accounts ADD COLUMN {_cn} {_ct}"))
                    db.commit()
                    added += 1
                except Exception:
                    db.rollback()
        db.close()
        results["s2_cols"] = f"OK - {added} cols added"
    except Exception as _e2:
        results["s2_cols"] = str(_e2)[:200]

    # Sprint 3 tables
    try:
        from app.sprint3.models.sprint3_models import init_sprint3_db
        results["sprint3"] = init_sprint3_db()
    except Exception as e:
        results["sprint3"] = str(e)[:200]

    # Sprint 4 TB tables
    try:
        from app.sprint4_tb.models.tb_models import init_sprint4_tb_db
        results["sprint4_tb"] = init_sprint4_tb_db()
    except Exception as e:
        results["sprint4_tb"] = str(e)[:200]

    # Sprint 5 Analysis tables
    try:
        from app.sprint5_analysis.models.analysis_models import init_sprint5_analysis_db
        results["sprint5_analysis"] = init_sprint5_analysis_db()
    except Exception as e:
        results["sprint5_analysis"] = str(e)[:200]

    # Sprint 6 Registry + Eligibility tables
    try:
        from app.sprint6_registry.models.registry_models import init_sprint6_db
        results["sprint6_registry"] = init_sprint6_db()
    except Exception as e:
        results["sprint6_registry"] = str(e)[:200]

    # Sprint 4 â€” Knowledge Brain tables (PostgreSQL compatible)
    try:
        from app.phase1.models.platform_models import SessionLocal as _SL4
        from sqlalchemy import text as _t4
        _db4 = _SL4()
        _s4_tables = [
            """CREATE TABLE IF NOT EXISTS knowledge_concepts (
                id TEXT PRIMARY KEY,
                canonical_name_ar TEXT NOT NULL,
                canonical_name_en TEXT,
                domain_pack TEXT NOT NULL DEFAULT 'accounting',
                sector_scope TEXT,
                jurisdiction_scope TEXT,
                authority_level TEXT DEFAULT 'platform',
                description_ar TEXT,
                description_en TEXT,
                effective_from TEXT,
                effective_to TEXT,
                last_verified_at TEXT,
                validity_status TEXT DEFAULT 'active',
                superseded_by TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS knowledge_concept_aliases (
                id TEXT PRIMARY KEY,
                concept_id TEXT,
                alias_text TEXT NOT NULL,
                language_code TEXT DEFAULT 'ar',
                alias_type TEXT DEFAULT 'synonym',
                source_system TEXT,
                client_scope TEXT,
                sector_scope TEXT,
                confidence_weight REAL DEFAULT 1.0,
                is_approved INTEGER DEFAULT 0,
                review_status TEXT DEFAULT 'pending_review',
                reviewed_at TEXT,
                reviewer_notes TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS knowledge_alias_conflicts (
                id TEXT PRIMARY KEY,
                alias_text TEXT,
                concept_id_1 TEXT,
                concept_id_2 TEXT,
                conflict_type TEXT,
                conflict_status TEXT DEFAULT 'pending',
                resolution_notes TEXT,
                resolved_by TEXT,
                resolved_at TEXT,
                detected_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS knowledge_candidate_rules (
                id TEXT PRIMARY KEY,
                rule_name TEXT NOT NULL,
                domain_pack TEXT NOT NULL,
                rule_logic_json TEXT DEFAULT '{}',
                authority_level TEXT DEFAULT 'ai',
                source_type TEXT DEFAULT 'ai_suggestion',
                description_ar TEXT,
                submission_status TEXT DEFAULT 'pending_review',
                reviewer_notes TEXT,
                reviewed_at TEXT,
                submitted_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS active_knowledge_rules (
                id TEXT PRIMARY KEY,
                rule_name TEXT NOT NULL,
                domain_pack TEXT NOT NULL,
                rule_logic_json TEXT DEFAULT '{}',
                authority_level TEXT DEFAULT 'platform',
                description_ar TEXT,
                validity_status TEXT DEFAULT 'active',
                effective_from TEXT,
                effective_to TEXT,
                superseded_by TEXT,
                promoted_from_candidate_id TEXT,
                promoted_at TEXT,
                last_verified_at TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS knowledge_feedback_reviews (
                id TEXT PRIMARY KEY,
                feedback_event_id TEXT,
                review_decision TEXT,
                review_notes TEXT,
                reviewer_id TEXT,
                reviewed_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS source_system_profiles (
                id TEXT PRIMARY KEY,
                system_name TEXT NOT NULL,
                system_version TEXT,
                description_ar TEXT,
                supported_languages TEXT DEFAULT '["ar","en"]',
                known_labels_json TEXT DEFAULT '{}',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS result_explanations (
                id TEXT PRIMARY KEY,
                result_type TEXT NOT NULL,
                result_id TEXT NOT NULL,
                upload_id TEXT,
                account_id TEXT,
                explanation_ar TEXT,
                confidence REAL,
                risk_severity TEXT DEFAULT 'low',
                boundary_status TEXT DEFAULT 'advisory',
                source_rows_json TEXT DEFAULT '[]',
                applied_rules_json TEXT DEFAULT '[]',
                references_json TEXT DEFAULT '[]',
                requires_human_review INTEGER DEFAULT 0,
                human_review_reason TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS decision_accountability_ledger (
                id TEXT PRIMARY KEY,
                entity_type TEXT,
                entity_id TEXT,
                decision_type TEXT,
                decision_by TEXT,
                decision_at TEXT,
                rationale TEXT,
                authority_level TEXT,
                audit_trail_json TEXT DEFAULT '{}',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
        ]
        for stmt in _s4_tables:
            try:
                _db4.execute(_t4(stmt))
                _db4.commit()
            except Exception:
                _db4.rollback()
        results["s4_tables"] = "OK - 9 tables"
    except Exception as _e4:
        results["s4_tables"] = str(_e4)[:200]

    return results



@app.get("/admin/seed-all", tags=["Admin"])
def seed_all_data(secret: str = Query(...)):
    if secret != ADMIN_SECRET:
        raise HTTPException(status_code=403, detail="Invalid secret")
    from app.seed_runner import seed_all
    seed_all()
    return {"status": "OK", "message": "All seed data loaded"}

@app.get("/health")
def health():
    return {"status": "ok", "version": "9.0.0",
            "phases": {"p1": P1, "p2": P2, "p3": P3, "p4": P4, "p5": P5, "p6": P6,
                       "p7": HAS_P7, "p8": HAS_P8, "p9": HAS_P9, "p10": HAS_P10, "p11": HAS_P11},
            "sprints": {"s1": HAS_S1, "s2": HAS_S2, "s3": HAS_S3, "s4": HAS_S4,
                        "s4_tb": HAS_S4_TB, "s4_tb_error": str(getattr(__import__("sys"), "exc_info", lambda: (None,None,None))()), "s5": HAS_S5, "s6": HAS_S6},
            "all_phases_active": all([P1, P2, P3, P4, P5, P6, HAS_P7, HAS_P8])}


@app.get("/debug/flags")
def debug_flags():
    flags = {}
    for name in ["HAS_S1", "HAS_S2", "HAS_S3", "HAS_S4", "HAS_S4_TB", "HAS_S5", "HAS_S6",
                  "HAS_P7", "HAS_P8", "HAS_P9", "HAS_P10", "HAS_P11"]:
        flags[name] = globals().get(name, "NOT_DEFINED")
    try:
        from app.sprint2.routes.sprint2_routes import router as _test
        flags["s2_import_now"] = f"OK: {len(_test.routes)} routes"
    except Exception as e:
        flags["s2_import_now"] = f"FAIL: {e}"
    return flags


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# RESET POSTGRES â€” Clean drop and recreate all tables
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

@app.get("/admin/reset-postgres")
def reset_postgres(secret: str = Query(...)):
    if secret != ADMIN_SECRET:
        raise HTTPException(403, "Invalid secret")
    from app.phase1.models.platform_models import Base, engine
    from sqlalchemy import text as _txt
    import os
    db_url = os.environ.get("DATABASE_URL", "")
    if "postgres" not in db_url:
        return {"status": "error", "message": "Not a PostgreSQL database â€” use reinit-db instead"}
    try:
        with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as conn:
            # Drop all tables in public schema
            conn.execute(_txt("""
                DO $$ DECLARE r RECORD;
                BEGIN
                    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
                        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
                    END LOOP;
                END $$;
            """))
        # Recreate all tables
        Base.metadata.create_all(bind=engine)
        return {"status": "OK", "message": "All tables dropped and recreated on PostgreSQL"}
    except Exception as e:
        return {"status": "error", "message": str(e)[:500]}


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# PROMOTE USER â€” Add admin role
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

@app.get("/admin/promote-user")
def promote_user(secret: str = Query(...), username: str = Query(...), role: str = Query("platform_admin")):
    if secret != ADMIN_SECRET:
        raise HTTPException(403, "Invalid secret")
    from app.phase1.models.platform_models import SessionLocal
    from sqlalchemy import text as _t
    import uuid
    db = SessionLocal()
    try:
        user = db.execute(_t("SELECT id FROM users WHERE username = :u"), {"u": username}).fetchone()
        if not user:
            raise HTTPException(404, f"User {username} not found")
        uid = user[0]
        role_row = db.execute(_t("SELECT id FROM roles WHERE name = :r"), {"r": role}).fetchone()
        if not role_row:
            raise HTTPException(404, f"Role {role} not found")
        rid = role_row[0]
        # Check if already has role
        existing = db.execute(_t("SELECT id FROM user_roles WHERE user_id = :uid AND role_id = :rid"),
                              {"uid": uid, "rid": rid}).fetchone()
        if not existing:
            db.execute(_t("INSERT INTO user_roles (id, user_id, role_id) VALUES (:id, :uid, :rid)"),
                       {"id": str(uuid.uuid4()), "uid": uid, "rid": rid})
            db.commit()
        return {"success": True, "username": username, "role": role}
    finally:
        db.close()


@app.post("/admin/promote/{username}", tags=["Admin"])
async def promote_to_admin(username: str, secret: str = Query(...)):
    if secret != ADMIN_SECRET:
        raise HTTPException(403, "Invalid secret")
    try:
        from app.phase1.models.platform_models import SessionLocal, User, UserRole, Role
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.username == username).first()
            if not user:
                raise HTTPException(404, f"User {username} not found")
            admin_role = db.query(Role).filter(Role.code == 'platform_admin').first()
            if admin_role:
                existing = db.query(UserRole).filter(UserRole.user_id == user.id, UserRole.role_id == admin_role.id).first()
                if not existing:
                    db.add(UserRole(user_id=user.id, role_id=admin_role.id))
                    db.commit()
            return {"message": f"{username} promoted to admin", "user_id": str(user.id)}
        finally:
            db.close()
    except HTTPException:
        raise
    except Exception as e:
        return {"message": f"Error: {e}"}


@app.get("/debug/s2")
def debug_s2():
    try:
        from app.sprint2.routes.sprint2_routes import router as _s2r
        routes = [{"method": list(r.methods), "path": r.path} for r in _s2r.routes]
        return {"s2_loaded": True, "routes": routes, "count": len(routes)}
    except Exception as e:
        import traceback
        import logging; logging.error(traceback.format_exc())
        return {"s2_loaded": False, "error": str(e)}


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# ANALYSIS ENDPOINTS
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

@app.post("/analyze")
async def analyze(file: UploadFile = File(...), industry: str = Query("general"), closing_inventory: float = Query(None)):
    if not file.filename.endswith(('.xlsx', '.xls')): raise HTTPException(400, "Excel only")
    try:
        c = await file.read()
        return orch.analyze_bytes(file_bytes=c, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
    except Exception as e: import logging; logging.error(traceback.format_exc()); raise HTTPException(500, str(e))

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
        except Exception: pass
        r["narrative"] = await n.generate(r, language=language, brain_context=bc)
        return r
    except Exception as e: import logging; logging.error(traceback.format_exc()); raise HTTPException(500, str(e))


@app.post("/analyze/report", tags=["Analysis"])
async def analyze_report(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    closing_inventory: float = Query(0),
    client_name: str = Query(""),
):
    """Analyze trial balance and return PDF report."""
    from app.services.pdf_report_service import generate_pdf_report
    from starlette.responses import Response
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(400, "Excel files only (.xlsx, .xls)")
    try:
        contents = await file.read()
        result = orch.analyze_bytes(file_bytes=contents, filename=file.filename, industry=industry, closing_inventory=closing_inventory)
        pdf_bytes = generate_pdf_report(result, client_name=client_name)
        from datetime import datetime as _dt
        fname = f"APEX_Report_{_dt.now().strftime('%Y%m%d_%H%M')}.pdf"
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={fname}",
                "Access-Control-Expose-Headers": "Content-Disposition",
            }
        )
    except Exception as e:
        import traceback
        import logging; logging.error(traceback.format_exc()); raise HTTPException(500, str(e))

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
            except Exception: pass
        rows = rr["rows"]
        if not rows: return {"success": False, "error": "No data"}
        cl = orch.classifier.classify_rows(rows)
        return {"success": True, "filename": file.filename, "total": len(rows),
                "summary": orch.classifier.get_summary(cl),
                "accounts": [{"name": r.get("account_name", ""), "class": r.get("normalized_class"),
                    "confidence": r.get("confidence", 0)} for r in cl]}
    except Exception as e: import logging; logging.error(traceback.format_exc()); raise HTTPException(500, str(e))


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# STATIC API ENDPOINTS (Phase 7 compliance)
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

# --- User Security ---
# GET /users/me/security is served by phase1_routes (AccountService.get_security_info)

@app.put("/users/me/security/password", tags=["Account"])
async def change_password(body: dict, authorization: str = Header(None)):
    from app.phase1.routes.phase1_routes import get_current_user
    user = await get_current_user(authorization)
    current = body.get("current_password", "")
    new_pw = body.get("new_password", "")
    confirm = body.get("confirm_password", "")
    if not all([current, new_pw, confirm]):
        raise HTTPException(400, "All password fields required")
    if new_pw != confirm:
        raise HTTPException(400, "Passwords do not match")
    from app.phase1.services.auth_service import AuthService
    result = AuthService().change_password(user["sub"], current, new_pw)
    if not result.get("success"):
        raise HTTPException(400, result.get("error", "Failed"))
    return {"message": result.get("message", "Password changed successfully")}

# --- Plans ---
@app.get("/plans", tags=["Subscriptions"])
async def list_plans():
    return {"plans": [
        {"id": "free", "name": "Free", "name_ar": "ظ…ط¬ط§ظ†ظٹ", "price": 0, "currency": "SAR",
         "features": {"coa_uploads": 2, "analysis_runs": 5, "result_details": "basic",
                      "marketplace": "browse", "knowledge_mode": False, "exports": "limited"}},
        {"id": "pro", "name": "Pro", "name_ar": "ط§ط­طھط±ط§ظپظٹ", "price": 99, "currency": "SAR",
         "features": {"coa_uploads": 20, "analysis_runs": 50, "result_details": "full",
                      "marketplace": "request", "knowledge_mode": "if_eligible", "exports": "full"}},
        {"id": "business", "name": "Business", "name_ar": "ط£ط¹ظ…ط§ظ„", "price": 299, "currency": "SAR",
         "features": {"coa_uploads": 100, "analysis_runs": 200, "result_details": "full+export",
                      "marketplace": "request+manage", "knowledge_mode": "if_eligible", "exports": "full",
                      "team_members": 5}},
        {"id": "expert", "name": "Expert", "name_ar": "ط®ط¨ظٹط±", "price": 499, "currency": "SAR",
         "features": {"coa_uploads": "unlimited", "analysis_runs": "unlimited", "result_details": "full",
                      "marketplace": "provide", "knowledge_mode": False, "provider_priority": True}},
        {"id": "enterprise", "name": "Enterprise", "name_ar": "ظ…ط¤ط³ط³ظٹ", "price": "custom", "currency": "SAR",
         "features": {"coa_uploads": "unlimited", "analysis_runs": "unlimited", "result_details": "full+admin",
                      "marketplace": "custom", "knowledge_mode": "full+governance", "exports": "full",
                      "team_members": "unlimited", "api_access": True}}
    ]}

# --- Legal ---
@app.get("/legal/terms", tags=["Legal"])
async def get_current_terms():
    return {
        "version": "1.0",
        "effective_date": "2026-01-01",
        "content_ar": "ط´ط±ظˆط· ظˆط£ط­ظƒط§ظ… ظ…ظ†طµط© APEX ظ„ظ„طھط­ظ„ظٹظ„ ط§ظ„ظ…ط§ظ„ظٹ ط§ظ„ظ…ط¹ط±ظپظٹ...",
        "content_en": "APEX Platform Terms and Conditions...",
        "requires_acceptance": True
    }

@app.get("/legal/privacy", tags=["Legal"])
async def get_privacy_policy():
    return {
        "version": "1.0",
        "effective_date": "2026-01-01",
        "content_ar": "ط³ظٹط§ط³ط© ط§ظ„ط®طµظˆطµظٹط© ظ„ظ…ظ†طµط© APEX...",
        "content_en": "APEX Platform Privacy Policy..."
    }

@app.get("/legal/provider-policy", tags=["Legal"])
async def get_provider_policy():
    return {
        "version": "1.0",
        "effective_date": "2026-01-01",
        "content_ar": "ط³ظٹط§ط³ط© ظ…ظ‚ط¯ظ…ظٹ ط§ظ„ط®ط¯ظ…ط§طھ...",
        "obligations": ["ط±ظپط¹ ظ…ط³طھظ†ط¯ط§طھ ط§ظ„طھط­ظ‚ظ‚", "ط±ظپط¹ ظ…ط¯ط®ظ„ط§طھ ط§ظ„ظ…ظ‡ظ…ط©", "ط±ظپط¹ ظ…ط®ط±ط¬ط§طھ ط§ظ„ظ…ظ‡ظ…ط©", "ط§ظ„ط¹ظ…ظ„ ط¶ظ…ظ† ط§ظ„ظ†ط·ط§ظ‚ ط§ظ„ظ…ط¹طھظ…ط¯", "ظ‚ط¨ظˆظ„ ط¹ظ…ظˆظ„ط© ط§ظ„ظ…ظ†طµط©"],
        "suspension_triggers": ["ط¹ط¯ظ… ط±ظپط¹ ط§ظ„ظ…ط¯ط®ظ„ط§طھ", "ط¹ط¯ظ… ط±ظپط¹ ط§ظ„ظ…ط®ط±ط¬ط§طھ", "طھط¬ط§ظˆط² ط§ظ„ظ…ظˆط¹ط¯", "ظ…ط®ط§ظ„ظپط© ط¬ظˆط¯ط© ط§ظ„ط¹ظ…ظ„"]
    }

@app.get("/legal/acceptable-use", tags=["Legal"])
async def get_acceptable_use():
    return {"version": "1.0", "effective_date": "2026-01-01", "content_ar": "ط³ظٹط§ط³ط© ط§ظ„ط§ط³طھط®ط¯ط§ظ… ط§ظ„ظ…ظ‚ط¨ظˆظ„ ظ„ظ…ظ†طµط© APEX..."}

@app.post("/legal/accept", tags=["Legal"])
async def accept_legal(body: dict, authorization: str = Header(None)):
    from app.phase1.routes.phase1_routes import get_current_user
    user = await get_current_user(authorization)
    doc_id = body.get("document_id", "")
    if not doc_id:
        raise HTTPException(400, "document_id required")
    from app.phase11.services.legal_service import accept_document
    result = accept_document(user["sub"], doc_id)
    if result.get("status") == "error":
        raise HTTPException(400, result.get("detail", "Failed"))
    return result

# --- Account Closure ---
@app.post("/account/closure", tags=["Account"])
async def request_closure(body: dict):
    closure_type = body.get("type", "temporary")
    reason = body.get("reason", "")
    if closure_type not in ("temporary", "permanent"):
        raise HTTPException(400, "type must be 'temporary' or 'permanent'")
    return {
        "message": f"{'Temporary deactivation' if closure_type == 'temporary' else 'Permanent closure'} request submitted",
        "type": closure_type, "status": "pending",
        "retention_notice": "Data will be retained per legal requirements" if closure_type == "permanent" else None
    }

# --- Knowledge Feedback Review Queue ---
@app.get("/knowledge-feedback/review-queue", tags=["Knowledge"])
async def get_review_queue(status: str = Query("submitted")):
    valid_statuses = ["submitted", "under_review", "accepted", "rejected", "needs_refinement", "queued_for_rule_design"]
    if status not in valid_statuses:
        raise HTTPException(400, f"Invalid status. Valid: {valid_statuses}")
    return {"items": [], "total": 0, "status_filter": status}

@app.put("/knowledge-feedback/{feedback_id}/review", tags=["Knowledge"])
async def review_feedback(feedback_id: str, body: dict):
    decision = body.get("decision", "")
    if decision not in ("accepted", "rejected", "needs_refinement", "queued_for_rule_design"):
        raise HTTPException(400, "Invalid decision")
    return {"message": f"Feedback {feedback_id} marked as {decision}", "id": feedback_id, "decision": decision}

# --- Service Provider Documents ---
@app.get("/service-providers/{provider_id}/documents", tags=["Providers"])
async def get_provider_documents(provider_id: str):
    return {"provider_id": provider_id, "documents": [], "verification_status": "pending"}

@app.post("/service-providers/{provider_id}/documents", tags=["Providers"])
async def upload_provider_document(provider_id: str, file: UploadFile = File(...), doc_type: str = Query("identity")):
    valid_types = ["identity", "professional_license", "academic_certificate", "experience_letter", "portfolio"]
    if doc_type not in valid_types:
        raise HTTPException(400, f"Invalid doc_type. Valid: {valid_types}")
    return {"message": "Document uploaded", "provider_id": provider_id, "doc_type": doc_type, "filename": file.filename, "status": "pending_review"}

@app.put("/service-providers/{provider_id}/verify", tags=["Providers"])
async def verify_provider(provider_id: str, body: dict):
    decision = body.get("decision", "")
    if decision not in ("approved", "rejected", "pending"):
        raise HTTPException(400, "Decision must be approved, rejected, or pending")
    return {"message": f"Provider {provider_id} {decision}", "verification_status": decision, "approved_scopes": body.get("scopes", [])}

# --- Task Document Requirements ---
@app.get("/task-types", tags=["Tasks"])
async def list_task_types():
    return {"task_types": [
        {"id": "bookkeeping", "name_ar": "ظ…ط³ظƒ ط§ظ„ط¯ظپط§طھط±", "input_documents": ["ظ…طµط§ط¯ط± ط§ظ„ظ‚ظٹظˆط¯", "ظƒط´ظپ ط­ط³ط§ط¨ ط¨ظ†ظƒظٹ", "ظپظˆط§طھظٹط±", "ط´ط¬ط±ط© ط­ط³ط§ط¨ط§طھ"], "output_documents": ["ظ…ظ„ظپ ظ‚ظٹظˆط¯ ظ…ظ†ط¸ظ…", "ظ…ظ„ط§ط­ط¸ط§طھ ط§ظ„طھط³ظˆظٹط©"], "deadline_days": 14},
        {"id": "financial_statement_preparation", "name_ar": "ط¥ط¹ط¯ط§ط¯ ط§ظ„ظ‚ظˆط§ط¦ظ… ط§ظ„ظ…ط§ظ„ظٹط©", "input_documents": ["ظ…ظٹط²ط§ظ† ظ…ط±ط§ط¬ط¹ط©", "ط³ظٹط§ط³ط§طھ ظ…ط­ط§ط³ط¨ظٹط©", "ط£ط±طµط¯ط© ط§ظپطھطھط§ط­ظٹط©"], "output_documents": ["ظ‚ظˆط§ط¦ظ… ظ…ط§ظ„ظٹط©", "ط¥ظٹط¶ط§ط­ط§طھ", "ظ…ظ„ط®طµ"], "deadline_days": 21},
        {"id": "vat_review", "name_ar": "ظ…ط±ط§ط¬ط¹ط© ط¶ط±ظٹط¨ط© ط§ظ„ظ‚ظٹظ…ط© ط§ظ„ظ…ط¶ط§ظپط©", "input_documents": ["ظ…ظ„ظپط§طھ ط¶ط±ظٹط¨ظٹط©", "ظپظˆط§طھظٹط±", "ط¥ظ‚ط±ط§ط±ط§طھ ط³ط§ط¨ظ‚ط©"], "output_documents": ["ظ…ط°ظƒط±ط© ط§ظ„ظ…ط±ط§ط¬ط¹ط©", "ط§ظ„ظ†طھط§ط¦ط¬", "ظ‚ط§ط¦ظ…ط© ط§ظ„ط¥ط¬ط±ط§ط،ط§طھ"], "deadline_days": 10},
        {"id": "hr_policy_review", "name_ar": "ظ…ط±ط§ط¬ط¹ط© ط³ظٹط§ط³ط§طھ ط§ظ„ظ…ظˆط§ط±ط¯ ط§ظ„ط¨ط´ط±ظٹط©", "input_documents": ["ط³ظٹط§ط³ط§طھ ط­ط§ظ„ظٹط©", "ط§ظ„ظ‡ظٹظƒظ„ ط§ظ„طھظ†ط¸ظٹظ…ظٹ", "ط§ظ„ط¹ظ‚ظˆط¯"], "output_documents": ["طھظ‚ط±ظٹط± ط§ظ„ظ…ط±ط§ط¬ط¹ط©", "ظ‚ط§ط¦ظ…ط© ط§ظ„ظپط¬ظˆط§طھ"], "deadline_days": 14},
        {"id": "audit_support", "name_ar": "ط¯ط¹ظ… ط§ظ„طھط¯ظ‚ظٹظ‚", "input_documents": ["ظ‚ظˆط§ط¦ظ… ظ…ط§ظ„ظٹط©", "ظ…ظٹط²ط§ظ† ظ…ط±ط§ط¬ط¹ط©", "ظ…ط³طھظ†ط¯ط§طھ ط¯ط§ط¹ظ…ط©"], "output_documents": ["طھظ‚ط±ظٹط± ط§ظ„طھط¯ظ‚ظٹظ‚", "ظ…ظ„ط§ط­ط¸ط§طھ", "ط®ط·ط§ط¨ ط§ظ„ط¥ط¯ط§ط±ط©"], "deadline_days": 30}
    ]}

@app.get("/service-requests/{request_id}/documents", tags=["Tasks"])
async def get_task_documents(request_id: str):
    return {"request_id": request_id, "task_type": "bookkeeping", "required_inputs": ["ظ…طµط§ط¯ط± ط§ظ„ظ‚ظٹظˆط¯", "ظƒط´ظپ ط­ط³ط§ط¨ ط¨ظ†ظƒظٹ"], "submitted_inputs": [], "required_outputs": ["ظ…ظ„ظپ ظ‚ظٹظˆط¯ ظ…ظ†ط¸ظ…"], "submitted_outputs": [], "compliance_status": "pending", "deadline": "2026-04-15"}

@app.post("/service-requests/{request_id}/documents/upload", tags=["Tasks"])
async def upload_task_document(request_id: str, file: UploadFile = File(...), doc_category: str = Query("input"), doc_name: str = Query("")):
    if doc_category not in ("input", "output"):
        raise HTTPException(400, "doc_category must be 'input' or 'output'")
    return {"message": "Document uploaded", "request_id": request_id, "category": doc_category, "filename": file.filename, "doc_name": doc_name}

# --- Provider Compliance & Suspension ---
@app.get("/providers/compliance/{provider_id}", tags=["Compliance"])
async def get_compliance_status(provider_id: str):
    return {"provider_id": provider_id, "status": "active", "flags": [], "missing_documents": [], "overdue_tasks": [], "suspension_history": []}

@app.post("/providers/compliance/{provider_id}/suspend", tags=["Compliance"])
async def suspend_provider(provider_id: str, body: dict):
    severity = body.get("severity", "soft")
    reason = body.get("reason", "")
    if severity not in ("soft", "hard"):
        raise HTTPException(400, "severity must be 'soft' or 'hard'")
    return {"message": f"Provider {provider_id} suspended ({severity})", "severity": severity, "reason": reason, "status": "suspended", "can_receive_new_tasks": False}

@app.post("/providers/compliance/{provider_id}/unsuspend", tags=["Compliance"])
async def unsuspend_provider(provider_id: str, body: dict):
    return {"message": f"Provider {provider_id} unsuspended", "status": "active", "can_receive_new_tasks": True}

# --- Client Types ---
@app.get("/client-types", tags=["Clients"])
async def list_client_types():
    return {"client_types": [
        {"id": "standard_business", "name_ar": "ظ…ظ†ط´ط£ط© طھط¬ط§ط±ظٹط©", "knowledge_mode": False},
        {"id": "financial_entity", "name_ar": "ط¬ظ‡ط© ظ…ط§ظ„ظٹط©", "knowledge_mode": True},
        {"id": "financing_entity", "name_ar": "ط¬ظ‡ط© طھظ…ظˆظٹظ„ظٹط©", "knowledge_mode": True},
        {"id": "accounting_firm", "name_ar": "ظ…ظƒطھط¨ ظ…ط­ط§ط³ط¨ط©", "knowledge_mode": True},
        {"id": "audit_firm", "name_ar": "ظ…ظƒطھط¨ طھط¯ظ‚ظٹظ‚", "knowledge_mode": True},
        {"id": "investment_entity", "name_ar": "ط¬ظ‡ط© ط§ط³طھط«ظ…ط§ط±ظٹط©", "knowledge_mode": True},
        {"id": "sector_consulting_entity", "name_ar": "ط§ط³طھط´ط§ط±ط§طھ ظ‚ط·ط§ط¹ظٹط©", "knowledge_mode": True},
        {"id": "government_entity", "name_ar": "ط¬ظ‡ط© ط­ظƒظˆظ…ظٹط©", "knowledge_mode": True},
        {"id": "legal_regulatory_entity", "name_ar": "ط¬ظ‡ط© ظ‚ط§ظ†ظˆظ†ظٹط©/طھظ†ط¸ظٹظ…ظٹط©", "knowledge_mode": True}
    ]}

# --- Profile Update (alias for /users/me PUT) ---
@app.put("/users/me/profile", tags=["Account"])
async def update_profile(body: dict, authorization: str = Header(None)):
    from app.phase1.routes.phase1_routes import get_current_user
    user = await get_current_user(authorization)
    from app.phase1.services.account_service import AccountService
    return AccountService().update_profile(user["sub"], body)

# --- User Activity History ---
@app.get("/users/me/activity", tags=["Account"])
async def get_activity_history(limit: int = Query(20), authorization: str = Header(None)):
    from app.phase1.routes.phase1_routes import get_current_user
    user = await get_current_user(authorization)
    from app.phase1.models.platform_models import SessionLocal, UserSecurityEvent
    db = SessionLocal()
    try:
        events = db.query(UserSecurityEvent).filter(
            UserSecurityEvent.user_id == user["sub"]
        ).order_by(UserSecurityEvent.created_at.desc()).limit(limit).all()
        return {"activities": [
            {"type": e.event_type, "ip": e.ip_address, "created_at": str(e.created_at)}
            for e in events
        ], "total": len(events)}
    finally:
        db.close()



if __name__ == "__main__":
    import uvicorn; uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)







