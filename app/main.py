"""
APEX Financial Platform -- FastAPI Backend v10.2
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

from contextlib import asynccontextmanager
from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import os
import logging
from app.services.orchestrator import AnalysisOrchestrator

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


# ═══════════════════════════════════════════════════════════════
# Pydantic Request Models (input validation)
# ═══════════════════════════════════════════════════════════════


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=6)
    confirm_password: str = Field(..., min_length=6)


class AcceptLegalRequest(BaseModel):
    document_id: str = Field(..., min_length=1)


class AccountClosureRequest(BaseModel):
    type: str = Field(default="temporary", pattern="^(temporary|permanent)$")
    reason: str = Field(default="")


ENVIRONMENT = os.environ.get("ENVIRONMENT", "development").lower()
IS_PRODUCTION = ENVIRONMENT in ("production", "prod")

ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
if not ADMIN_SECRET:
    if IS_PRODUCTION:
        raise RuntimeError(
            "ADMIN_SECRET env var is REQUIRED in production. Refusing to start with insecure default."
        )
    ADMIN_SECRET = "apex-admin-dev-only"
    logging.warning("ADMIN_SECRET not set — using development-only fallback. Set it before production.")

# JWT secret hard-check: refuse to boot in production with a weak/missing secret.
_jwt_env = os.environ.get("JWT_SECRET")
if IS_PRODUCTION:
    if not _jwt_env or len(_jwt_env) < 32:
        raise RuntimeError(
            "JWT_SECRET env var is REQUIRED in production and must be >=32 chars. Refusing to start."
        )


def _verify_admin(secret: str = None, x_admin_secret: str = Header(None, alias="X-Admin-Secret")):
    """Verify admin secret.
    Header 'X-Admin-Secret' is the preferred and only secure transport.
    Query-parameter 'secret' is accepted in DEV ONLY for backward compatibility
    (it leaks into server access logs and is refused in production)."""
    if IS_PRODUCTION and secret and not x_admin_secret:
        raise HTTPException(
            403,
            "Admin secret via query parameter is forbidden in production — use X-Admin-Secret header.",
        )
    token = x_admin_secret or secret
    if not token or token != ADMIN_SECRET:
        raise HTTPException(403, "Invalid admin secret")
    if secret and not x_admin_secret:
        logging.warning(
            "DEPRECATED: admin secret via query parameter. Migrate to X-Admin-Secret header."
        )
    return token


# Import compliance models EARLY so their tables register with Base.metadata
# before any create_all() call (tests in particular rely on this).
try:
    from app.core import compliance_models as _compliance_models  # noqa: F401
except Exception as e:
    logging.warning(f"Compliance models import failed: {e}")

# HR + AP Agent models — added 2026-04-17. Import here (side-effect) so the
# tables register with Base.metadata and `create_all()` / Alembic pick them up.
try:
    from app.hr import models as _hr_models  # noqa: F401
except Exception as e:
    logging.warning(f"HR models import failed: {e}")
try:
    from app.features.ap_agent import models as _ap_models  # noqa: F401
except Exception as e:
    logging.warning(f"AP Agent models import failed: {e}")

# Self-registering model modules (tables auto-added to Base.metadata)
for _mod in [
    "app.core.governed_ai",
    "app.core.webhooks",
    "app.core.saved_views",
    "app.services.copilot_memory",
    "app.core.dimensional_accounting",
    "app.core.consolidation_intercompany",
    "app.core.marketplace_enhanced",
    "app.core.offline_sync",
    "app.core.tenant_branding",
    "app.core.activity_log",
    "app.integrations.zatca.retry_queue",
]:
    try:
        __import__(_mod)
    except Exception as _e:
        logging.warning(f"{_mod} models not registered: {_e}")

try:
    from app.knowledge_brain.api.routes.knowledge_routes import router as kb_r
    from app.knowledge_brain.models.db_models import init_db as init_kb

    KB = True
except Exception as e:
    KB = False
    logging.warning(f"Knowledge Brain disabled: {e}")
try:
    from app.phase1.models.platform_models import init_platform_db
    from app.phase1.routes.phase1_routes import router as p1r
    from app.phase1.services.seed_data import seed_all as seed1

    P1 = True
except Exception as e:
    P1 = False
    logging.warning(f"Phase 1 disabled: {e}")
try:
    from app.phase2.routes.phase2_routes import router as p2r
    from app.phase2.services.seed_phase2 import seed_client_types

    P2 = True
except Exception as e:
    P2 = False
    logging.warning(f"Phase 2 disabled: {e}")
try:
    from app.phase3.routes.phase3_routes import router as p3r

    P3 = True
except Exception as e:
    P3 = False
    logging.warning(f"Phase 3 disabled: {e}")
try:
    from app.phase4.models.phase4_models import init_phase4_db
    from app.phase4.routes.phase4_routes import router as p4r

    P4 = True
except Exception as e:
    P4 = False
    logging.warning(f"Phase 4 disabled: {e}")
try:
    from app.phase5.models.phase5_models import init_phase5_db
    from app.phase5.routes.phase5_routes import router as p5r

    P5 = True
except Exception as e:
    P5 = False
    logging.warning(f"Phase 5 disabled: {e}")
try:
    from app.phase6.routes.phase6_routes import router as p6r

    P6 = True
except Exception as e:
    P6 = False
    logging.warning(f"Phase 6 disabled: {e}")
# Phase 7 â€" Task Documents + Suspension + Result Details + Audit
try:
    from app.phase7.models.phase7_models import init_phase7_db
    from app.phase7.routes.phase7_routes import router as p7r
    from app.phase7.services.seed_phase7 import seed_task_types

    HAS_P7 = True
except Exception as e:
    logging.warning(f"Phase 7 disabled: {e}")
    HAS_P7 = False
# Phase 8 â€" Entitlements Engine + Subscription Management
try:
    from app.phase8.models.phase8_models import init_phase8_db
    from app.phase8.routes.phase8_routes import router as p8r
    from app.phase8.services.seed_phase8 import seed_plan_limits

    HAS_P8 = True
except Exception as e:
    logging.warning(f"Phase 8 disabled: {e}")
    HAS_P8 = False
# Phase 9 â€" Account Center
try:
    from app.phase9.models.phase9_models import init_phase9_db
    from app.phase9.routes.phase9_routes import router as p9r

    HAS_P9 = True
except Exception as e:
    HAS_P9 = False
    logging.warning(f"Phase 9 disabled: {e}")
# Phase 10 â€" Notification System
try:
    from app.phase10.models.phase10_models import init_phase10_db
    from app.phase10.routes.phase10_routes import router as p10r
    from app.phase10.services.notification_service import seed_welcome_notification

    HAS_P10 = True
except Exception as e:
    HAS_P10 = False
    logging.warning(f"Phase 10 disabled: {e}")
# Sprint 1 â€" COA First Workflow
try:
    from app.sprint1.models.sprint1_models import init_sprint1_db
    from app.sprint1.routes.sprint1_routes import router as s1r

    HAS_S1 = True
except Exception as e:
    HAS_S1 = False
    logging.warning(f"Sprint 1 disabled: {e}")
# Sprint 2 â€" COA Classification Engine
try:
    from app.sprint2.routes.sprint2_routes import router as s2r

    HAS_S2 = True
except Exception as e:
    HAS_S2 = False
    logging.warning(f"Sprint 2 disabled: {e}")
# Sprint 4 â€" Knowledge Brain
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
# Phase 11 â€" Legal Acceptance
try:
    from app.phase11.models.phase11_models import init_phase11_db
    from app.phase11.routes.phase11_routes import router as p11r
    from app.phase11.services.legal_service import seed_legal_documents

    HAS_P11 = True
except Exception as e:
    HAS_P11 = False
    logging.warning(f"Phase 11 disabled: {e}")
# --- COA Engine v4.3 ---
HAS_COA_ENGINE = False
try:
    from app.coa_engine.api_routes import router as coa_engine_router, init_coa_engine

    HAS_COA_ENGINE = True
except Exception as e:
    logging.warning(f"COA Engine v4.3 disabled: {e}")


def _run_startup():
    """Initialize all phase databases and seed data.

    Order:
      1. Run Alembic migrations if enabled (production by default).
         In dev, fall through to init_*_db() / create_all().
    """
    # 1) Alembic upgrade head — production path. In dev this is a no-op
    #    unless RUN_MIGRATIONS_ON_STARTUP=true is set explicitly.
    try:
        from app.core.db_migrations import run_migrations_on_startup

        run_migrations_on_startup()
    except RuntimeError:
        # Production migration failure — refuse to continue silently.
        raise
    except Exception:
        logging.error("Migration runner crashed", exc_info=True)

    if KB:
        try:
            init_kb()
        except Exception:
            logging.error("Knowledge Brain init error", exc_info=True)
    if P1:
        try:
            t = init_platform_db()
            logging.info(f"APEX: {len(t)} tables")
            seed1()
        except Exception:
            logging.error("Phase 1 startup error", exc_info=True)

        # ── Schema-drift auto-repair on startup ──
        try:
            from app.core.schema_drift import apply_drift_fixes_on_startup
            from app.phase1.models.platform_models import SessionLocal as _SL
            apply_drift_fixes_on_startup(_SL)
        except Exception as _sdr:
            logging.warning(f"Schema drift repair skipped: {_sdr}")
    if P2:
        try:
            seed_client_types()
        except Exception:
            logging.error("Phase 2 startup error", exc_info=True)
    if P4:
        try:
            init_phase4_db()
        except Exception:
            logging.error("Phase 4 init error", exc_info=True)
    if P5:
        try:
            init_phase5_db()
        except Exception:
            logging.error("Phase 5 init error", exc_info=True)
    if HAS_P7:
        try:
            init_phase7_db()
            seed_task_types()
        except Exception:
            logging.error("Phase 7 init error", exc_info=True)
    if HAS_P8:
        try:
            init_phase8_db()
            seed_plan_limits()
        except Exception:
            logging.error("Phase 8 init error", exc_info=True)
    if HAS_P9:
        try:
            init_phase9_db()
        except Exception:
            logging.error("Phase 9 init error", exc_info=True)
    if HAS_P10:
        try:
            init_phase10_db()
            # seed_welcome_notification requires a user_id — skipped at startup
            # Called per-user after registration instead.
        except Exception:
            logging.error("Phase 10 init error", exc_info=True)
    if HAS_P11:
        try:
            init_phase11_db()
            seed_legal_documents()
        except Exception:
            logging.error("Phase 11 init error", exc_info=True)
    if HAS_S1:
        try:
            init_sprint1_db()
        except Exception:
            logging.error("Sprint 1 init error", exc_info=True)
    try:
        from app.copilot.models.copilot_models import init_copilot_db

        init_copilot_db()
    except Exception:
        logging.error("Copilot init error", exc_info=True)
    # Compliance core: journal entry sequence + immutable audit trail.
    # Required by ZATCA Phase 2 (gap-free JE numbers) and IFRS/SOCPA.
    try:
        from app.core.compliance_models import init_compliance_db

        tables = init_compliance_db()
        logging.info(f"Compliance core tables ready: {tables}")
    except Exception:
        logging.error("Compliance core init error", exc_info=True)


_PROD_INSECURE_DEFAULTS = {
    "JWT_SECRET": {"apex-dev-secret-CHANGE-IN-PRODUCTION", "test-secret", ""},
    "ADMIN_SECRET": {"apex-admin-2026", "apex-admin-dev-only", "test-admin", ""},
}

# Backend env vars that, when selected, require secrets/config to be present.
# Format: { BACKEND_VAR: { active_value: [required_secret_vars] } }
_BACKEND_REQUIREMENTS = {
    "EMAIL_BACKEND": {
        "smtp": ["SMTP_USER", "SMTP_PASSWORD"],
        "sendgrid": ["SENDGRID_API_KEY", "SENDGRID_FROM"],
    },
    "SMS_BACKEND": {
        "unifonic": ["UNIFONIC_APP_SID"],
        "twilio": ["TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_FROM_NUMBER"],
    },
    "PAYMENT_BACKEND": {
        "stripe": ["STRIPE_SECRET_KEY"],
    },
    "STORAGE_BACKEND": {
        "s3": ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "S3_BUCKET"],
    },
}


def _validate_env():
    """Strict environment validation.

    In production, fails fast if any critical variable is missing or is still
    a known insecure default. The list of failures is logged in full so ops
    can fix them all in one round-trip.

    In development, emits warnings without blocking startup.
    """
    env = os.environ.get("ENVIRONMENT", "development").lower()
    is_prod = env in ("production", "prod")
    problems: list[str] = []
    warnings_list: list[str] = []

    def _bad(var: str) -> bool:
        val = os.environ.get(var, "")
        insecure = _PROD_INSECURE_DEFAULTS.get(var, set())
        if not val or val in insecure:
            return True
        if var == "JWT_SECRET" and len(val) < 32:
            return True
        return False

    # Always-critical vars
    for var in ("JWT_SECRET", "ADMIN_SECRET"):
        if _bad(var):
            (problems if is_prod else warnings_list).append(
                f"{var} is missing or using an insecure default"
            )

    # DB is critical in prod only — dev falls back to SQLite.
    if is_prod and not os.environ.get("DATABASE_URL"):
        problems.append("DATABASE_URL is required in production")

    # CORS must not be wildcard in prod.
    if is_prod:
        cors = os.environ.get("CORS_ORIGINS", "")
        if not cors or cors.strip() == "*":
            problems.append("CORS_ORIGINS must be an explicit allowlist (not '*') in production")

    # Backend-specific secret checks.
    for backend_var, configs in _BACKEND_REQUIREMENTS.items():
        active = os.environ.get(backend_var, "").lower()
        required = configs.get(active, [])
        for req in required:
            if not os.environ.get(req):
                msg = f"{backend_var}={active} requires {req}"
                (problems if is_prod else warnings_list).append(msg)

    for w in warnings_list:
        logging.warning("⚠ env: %s", w)

    if problems:
        message = "PRODUCTION env validation failed:\n  - " + "\n  - ".join(problems)
        if is_prod:
            raise RuntimeError(message)
        logging.warning(message)


_validate_env()


@asynccontextmanager
async def lifespan(app):
    _run_startup()
    if HAS_COA_ENGINE:
        try:
            await init_coa_engine()
        except Exception:
            logging.error("COA Engine init error", exc_info=True)
    yield


app = FastAPI(
    title="APEX Financial Platform API",
    description="APEX Financial Analysis Platform - All 11 Phases + 6 Sprints",
    version="12.0.0",
    lifespan=lifespan,
)

# Unified error response shape ({success:false, error:{code, message_ar, ...}})
try:
    from app.core.error_handlers import register_error_handlers
    register_error_handlers(app)
    logging.info("Unified error handlers registered")
except Exception as _e:
    logging.error(f"Error handlers registration failed: {_e}", exc_info=True)
_cors_env = os.environ.get("CORS_ORIGINS", "")
_cors_origins = [o.strip() for o in _cors_env.split(",") if o.strip()] if _cors_env else ["*"]
_allow_creds = "*" not in _cors_origins  # credentials forbidden with wildcard
if not _allow_creds:
    if IS_PRODUCTION:
        raise RuntimeError("CORS_ORIGINS must be an explicit allowlist in production, not '*'.")
    logging.warning("CORS allows all origins — set CORS_ORIGINS env var in production")

# Explicit method + header allowlists — narrower than "*" per security best practice.
_ALLOWED_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
_ALLOWED_HEADERS = [
    "Content-Type",
    "Authorization",
    "Accept",
    "Origin",
    "X-Requested-With",
    "X-Admin-Secret",
    "X-Idempotency-Key",
    "X-Client-Version",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=_allow_creds,
    allow_methods=_ALLOWED_METHODS,
    allow_headers=_ALLOWED_HEADERS,
    expose_headers=["Content-Disposition", "X-RateLimit-Remaining", "X-RateLimit-Reset"],
    max_age=600,
)

# Multi-tenant ContextVar middleware — binds tenant_id from JWT/header/query
# for the duration of each request. Non-breaking: skipped endpoints listed
# in TenantContextMiddleware._TENANT_FREE_PREFIXES bypass it. Enforcement
# of "tenant required" is opt-in via TENANT_STRICT=true.
try:
    from app.core.tenant_context import TenantContextMiddleware
    app.add_middleware(TenantContextMiddleware)
    logging.info("Tenant context middleware registered")
except Exception as _e:
    logging.warning(f"Tenant context middleware not registered: {_e}")

# Tenant query guard — auto-filters SELECTs on TenantMixin tables by
# current_tenant() and auto-populates tenant_id on inserts. Non-breaking:
# tables that don't inherit TenantMixin are unaffected.
try:
    from app.core.tenant_guard import attach_tenant_guard
    from app.phase1.models.platform_models import engine as _tenant_engine
    attach_tenant_guard(_tenant_engine)
    logging.info("Tenant query guard attached")
except Exception as _e:
    logging.warning(f"Tenant query guard not attached: {_e}")

# Audit log — captures every state-changing request with redacted body preview.
# Required for SOC 2 Type II + PDPL compliance. Disable via AUDIT_LOG_ENABLED=false.
try:
    from app.core.audit_log import AuditLogMiddleware
    app.add_middleware(AuditLogMiddleware)
    logging.info("Audit log middleware registered")
except Exception as _e:
    logging.warning(f"Audit log middleware not registered: {_e}")

# WebSocket notifications router — real-time feed for user / tenant / entity channels.
try:
    from app.core.websocket_hub import router as ws_router
    app.include_router(ws_router)
    logging.info("WebSocket notifications router mounted at /ws/*")
except Exception as _e:
    logging.warning(f"WebSocket router not mounted: {_e}")

# HR routes — Employee CRUD + Leave + Payroll.
try:
    from app.hr.routes import router as hr_router
    app.include_router(hr_router)
    logging.info("HR routes mounted at /hr/*")
except Exception as _e:
    logging.warning(f"HR routes not mounted: {_e}")

# API versioning — stamps X-API-Version on every response.
try:
    from app.core.api_version import ApiVersionHeaderMiddleware
    app.add_middleware(ApiVersionHeaderMiddleware)
    logging.info("API version middleware registered (X-API-Version header)")
except Exception as _e:
    logging.warning(f"API version middleware not registered: {_e}")

# Saved filter views (mounted at /api/v1/saved-views/*).
try:
    from app.core.saved_views import router as saved_views_router
    app.include_router(saved_views_router)
    logging.info("Saved views router mounted at /api/v1/saved-views/*")
except Exception as _e:
    logging.warning(f"Saved views router not mounted: {_e}")

# Tenant branding / white-label (mounted at /api/v1/tenant/branding).
try:
    from app.core.tenant_branding import router as tenant_branding_router
    app.include_router(tenant_branding_router)
    logging.info("Tenant branding router mounted at /api/v1/tenant/branding")
except Exception as _e:
    logging.warning(f"Tenant branding router not mounted: {_e}")

# Activity log / Chatter timeline (mounted at /api/v1/activity).
try:
    from app.core.activity_log import router as activity_log_router
    app.include_router(activity_log_router)
    logging.info("Activity log router mounted at /api/v1/activity")
except Exception as _e:
    logging.warning(f"Activity log router not mounted: {_e}")

# Webhooks (Developer Platform) mounted at /api/v1/webhooks/*.
try:
    from app.core.webhooks import router as webhooks_router
    app.include_router(webhooks_router)
    logging.info("Webhooks router mounted at /api/v1/webhooks/*")
except Exception as _e:
    logging.warning(f"Webhooks router not mounted: {_e}")

# Dimensional accounting router at /api/v1/dimensions/*.
try:
    from app.core.dimensional_accounting import router as dim_router
    app.include_router(dim_router)
    logging.info("Dimensions router mounted at /api/v1/dimensions/*")
except Exception as _e:
    logging.warning(f"Dimensions router not mounted: {_e}")

# Governed AI model registration (no routes yet — consumed by AI modules).
try:
    from app.core import governed_ai as _governed_ai  # noqa: F401
    logging.info("Governed AI model registered")
except Exception as _e:
    logging.warning(f"Governed AI not registered: {_e}")

# WhatsApp Business Cloud webhook (verification handshake + inbound events).
# Only mounted if the module imports cleanly — optional integration.
try:
    from app.integrations.whatsapp.webhook import router as wa_webhook_router
    app.include_router(wa_webhook_router)
    logging.info("WhatsApp webhook router mounted at /integrations/whatsapp/*")
except Exception as _e:
    logging.warning(f"WhatsApp webhook router not mounted: {_e}")

orch = AnalysisOrchestrator()
from fastapi.responses import JSONResponse
from collections import defaultdict
import time


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logging.error(f"Unhandled: {exc}", exc_info=True)
    return JSONResponse(status_code=500, content={"success": False, "error": "Internal server error"})


# ======================================================================
# Rate limiter — tiered per-path limits, per-IP, proxy-aware.
# Backend is pluggable: RATE_LIMIT_BACKEND=memory (default, per-process) or
# RATE_LIMIT_BACKEND=redis (shared across instances via REDIS_URL).
# See app/core/rate_limit_backend.py.
# ======================================================================
from app.core.rate_limit_backend import (
    MemoryBackend,
    get_backend as _get_rate_backend,
)

# Expose the memory backend's internal store as _rate_limits so that
# existing tests that call `_rate_limits.clear()` between test cases
# continue to work without modification. For Redis backends, this is a
# dummy dict (tests targeting per-process counters don't apply there).
_rate_backend_instance = _get_rate_backend()
if isinstance(_rate_backend_instance, MemoryBackend):
    _rate_limits = _rate_backend_instance._store
else:
    _rate_limits = defaultdict(list)

_RATE_LIMIT_MAX_KEYS = 20000  # kept for backward compatibility; enforced in MemoryBackend

# Legacy module-level aliases (retained so older tests / external tooling keep working).
# The active limits are in _RATE_TIERS below — these just mirror the default bucket.
RATE_LIMIT_WINDOW = 60  # seconds (default bucket window)
RATE_LIMIT_MAX = 120  # requests per window (default bucket)

# Tiers: (path_prefix, window_seconds, max_requests, bucket_name)
# More specific prefixes MUST come first (longest prefix wins).
# Production values are strict (brute-force protection); development values
# are relaxed so the local workflow doesn't trip every few minutes.
if IS_PRODUCTION:
    _RATE_TIERS = [
        ("/admin/reset-postgres", 3600, 2, "admin_reset"),    # 2/hour — destructive
        ("/admin/reinit", 3600, 5, "admin_reinit"),
        ("/admin/", 60, 20, "admin"),                         # 20/min
        ("/auth/login", 300, 10, "auth_login"),               # 10 per 5min — brute-force guard
        ("/auth/register", 3600, 5, "auth_register"),         # 5/hour
        ("/auth/forgot-password", 3600, 3, "auth_forgot"),    # 3/hour
        ("/auth/", 60, 30, "auth"),
        ("/", 60, 120, "default"),                            # 120/min global
    ]
else:
    _RATE_TIERS = [
        ("/admin/reset-postgres", 60, 10, "admin_reset"),
        ("/admin/reinit", 60, 20, "admin_reinit"),
        ("/admin/", 60, 120, "admin"),
        ("/auth/login", 60, 60, "auth_login"),                # 60/min in dev
        ("/auth/register", 60, 30, "auth_register"),
        ("/auth/forgot-password", 60, 20, "auth_forgot"),
        ("/auth/", 60, 120, "auth"),
        ("/", 60, 600, "default"),                            # very permissive
    ]


def _get_client_ip(request) -> str:
    """Extract real client IP, handling proxied deployments (Render, Cloudflare, nginx)."""
    for header in ("cf-connecting-ip", "x-real-ip", "x-forwarded-for"):
        val = request.headers.get(header)
        if val:
            return val.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _pick_tier(path: str):
    for prefix, window, limit, bucket in _RATE_TIERS:
        if path.startswith(prefix):
            return window, limit, bucket
    return _RATE_TIERS[-1][1], _RATE_TIERS[-1][2], _RATE_TIERS[-1][3]


@app.middleware("http")
async def rate_limit_middleware(request, call_next):
    # CORS preflight and health probes MUST bypass rate limiting — they are
    # not user-initiated traffic and must never be throttled.
    if request.method == "OPTIONS":
        return await call_next(request)
    path_raw = request.url.path or "/"
    if path_raw in ("/health", "/", "/docs", "/openapi.json", "/redoc"):
        return await call_next(request)
    client_ip = _get_client_ip(request)
    window, limit, bucket = _pick_tier(path_raw)
    key = f"{client_ip}:{bucket}"

    backend = _get_rate_backend()
    count, reset_in = backend.hit(key, window)
    now = time.time()

    if count > limit:
        return JSONResponse(
            status_code=429,
            headers={
                "Retry-After": str(reset_in),
                "X-RateLimit-Limit": str(limit),
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": str(int(now + reset_in)),
            },
            content={
                "success": False,
                "error": "طلبات كثيرة جداً. الرجاء الانتظار.",
                "retry_after": reset_in,
            },
        )

    response = await call_next(request)
    # Expose remaining quota to clients
    response.headers["X-RateLimit-Limit"] = str(limit)
    response.headers["X-RateLimit-Remaining"] = str(max(0, limit - count))
    response.headers["X-RateLimit-Reset"] = str(int(now + reset_in))
    return response


_request_logger = logging.getLogger("apex.requests")


@app.middleware("http")
async def request_logging_middleware(request, call_next):
    path = request.url.path
    if path == "/health":
        return await call_next(request)
    start = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000, 1)
    _request_logger.info("%s %s %s %.1fms", request.method, path, response.status_code, duration_ms)
    return response


@app.middleware("http")
async def security_headers_middleware(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Cache-Control"] = "no-store"
    return response


# Startup logic moved to lifespan context manager (see above)

for flag, r in [
    (KB, kb_r if KB else None),
    (P1, p1r if P1 else None),
    (P2, p2r if P2 else None),
    (P3, p3r if P3 else None),
    (P4, p4r if P4 else None),
    (P5, p5r if P5 else None),
    (P6, p6r if P6 else None),
]:
    if flag and r:
        app.include_router(r)

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
if HAS_COA_ENGINE:
    app.include_router(coa_engine_router, tags=["COA Engine v4.3"])

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

# ── Compliance Core: Journal Entry Sequence + immutable Audit Trail
# ── (ZATCA Phase 2 / IFRS / SOCPA requirements)
try:
    from app.core.compliance_routes import router as compliance_router

    app.include_router(compliance_router)
    logging.info("Compliance routes mounted at /compliance/*")
except Exception as e:
    logging.error(f"Compliance routes not mounted: {e}", exc_info=True)

# ── ZATCA Phase 2 (Fatoora) e-invoice routes
try:
    from app.core.zatca_routes import router as zatca_router

    app.include_router(zatca_router)
    logging.info("ZATCA routes mounted at /zatca/*")
except Exception as e:
    logging.error(f"ZATCA routes not mounted: {e}", exc_info=True)

# ── Zakat + VAT calculators (KSA + GCC)
try:
    from app.core.tax_routes import router as tax_router

    app.include_router(tax_router)
    logging.info("Tax routes mounted at /tax/*")
except Exception as e:
    logging.error(f"Tax routes not mounted: {e}", exc_info=True)

# ── Financial Ratios (18 ratios across 5 categories)
try:
    from app.core.ratios_routes import router as ratios_router

    app.include_router(ratios_router)
    logging.info("Ratios routes mounted at /ratios/*")
except Exception as e:
    logging.error(f"Ratios routes not mounted: {e}", exc_info=True)

# ── Depreciation calculator (SL / DDB / SYD)
try:
    from app.core.depreciation_routes import router as depr_router

    app.include_router(depr_router)
    logging.info("Depreciation routes mounted at /depreciation/*")
except Exception as e:
    logging.error(f"Depreciation routes not mounted: {e}", exc_info=True)

# ── Cash Flow Statement + Loan Amortization
try:
    from app.core.cashflow_routes import router as cashflow_router

    app.include_router(cashflow_router)
    logging.info("Cash flow / amortization routes mounted")
except Exception as e:
    logging.error(f"Cash flow routes not mounted: {e}", exc_info=True)

# ── Payroll (GOSI + WPS) + Break-even analysis
try:
    from app.core.payroll_routes import router as payroll_router

    app.include_router(payroll_router)
    logging.info("Payroll / break-even routes mounted")
except Exception as e:
    logging.error(f"Payroll routes not mounted: {e}", exc_info=True)

# ── Investment appraisal (NPV/IRR) + Budget variance
try:
    from app.core.investment_routes import router as investment_router

    app.include_router(investment_router)
    logging.info("Investment / budget routes mounted")
except Exception as e:
    logging.error(f"Investment routes not mounted: {e}", exc_info=True)

# ── Bank Reconciliation + Inventory + Aging
try:
    from app.core.accounting_routes import router as acct_router

    app.include_router(acct_router)
    logging.info("Accounting-ops routes mounted (bank-rec, inventory, aging)")
except Exception as e:
    logging.error(f"Accounting routes not mounted: {e}", exc_info=True)

# ── Working Capital + Composite Health Score
try:
    from app.core.analytics_routes import router as analytics_router

    app.include_router(analytics_router)
    logging.info("Analytics routes mounted (working-capital, health-score)")
except Exception as e:
    logging.error(f"Analytics routes not mounted: {e}", exc_info=True)

# ── Invoice OCR extraction
try:
    from app.core.ocr_routes import router as ocr_router

    app.include_router(ocr_router)
    logging.info("OCR routes mounted at /ocr/*")
except Exception as e:
    logging.error(f"OCR routes not mounted: {e}", exc_info=True)

# ── DSCR + WACC + DCF valuation
try:
    from app.core.valuation_routes import router as valuation_router

    app.include_router(valuation_router)
    logging.info("Valuation routes mounted (dscr, wacc, dcf)")
except Exception as e:
    logging.error(f"Valuation routes not mounted: {e}", exc_info=True)

# ── Journal Entry builder + Multi-currency FX
try:
    from app.core.ledger_routes import router as ledger_router

    app.include_router(ledger_router)
    logging.info("Ledger routes mounted (je/build, fx/convert, fx/batch, fx/revalue)")
except Exception as e:
    logging.error(f"Ledger routes not mounted: {e}", exc_info=True)

# ── Cost Accounting / Variance Analysis
try:
    from app.core.cost_accounting_routes import router as cost_router

    app.include_router(cost_router)
    logging.info("Cost accounting routes mounted (variance: material/labour/overhead/comprehensive)")
except Exception as e:
    logging.error(f"Cost accounting routes not mounted: {e}", exc_info=True)

# ── Financial Statements (TB / IS / BS / Close)
try:
    from app.core.fin_statements_routes import router as fs_router

    app.include_router(fs_router)
    logging.info("Financial statements routes mounted (TB / IS / BS / closing)")
except Exception as e:
    logging.error(f"Financial statements routes not mounted: {e}", exc_info=True)

# ── Full Cash Flow Statement (IAS 7)
try:
    from app.core.cashflow_statement_routes import router as cfs_router

    app.include_router(cfs_router)
    logging.info("Cash flow statement routes mounted (IAS 7 indirect)")
except Exception as e:
    logging.error(f"Cash flow statement routes not mounted: {e}", exc_info=True)

# ── Withholding Tax (WHT) KSA
try:
    from app.core.wht_routes import router as wht_router

    app.include_router(wht_router)
    logging.info("WHT routes mounted (compute / batch / categories / rates)")
except Exception as e:
    logging.error(f"WHT routes not mounted: {e}", exc_info=True)

# ── Consolidation (IFRS 10)
try:
    from app.core.consolidation_routes import router as consol_router

    app.include_router(consol_router)
    logging.info("Consolidation routes mounted (build)")
except Exception as e:
    logging.error(f"Consolidation routes not mounted: {e}", exc_info=True)

# ── Deferred Tax (IAS 12)
try:
    from app.core.deferred_tax_routes import router as dt_router

    app.include_router(dt_router)
    logging.info("Deferred tax routes mounted (compute / categories)")
except Exception as e:
    logging.error(f"Deferred tax routes not mounted: {e}", exc_info=True)

# ── Lease Accounting (IFRS 16)
try:
    from app.core.lease_routes import router as lease_router

    app.include_router(lease_router)
    logging.info("Lease routes mounted (IFRS 16 build)")
except Exception as e:
    logging.error(f"Lease routes not mounted: {e}", exc_info=True)

# ── IFRS extras: Revenue 15, EOSB 19, Impairment 36, ECL 9, Provisions 37
try:
    from app.core.ifrs_extras_routes import router as ifrs_router

    app.include_router(ifrs_router)
    logging.info("IFRS extras routes mounted (revenue / eosb / impairment / ecl / provisions)")
except Exception as e:
    logging.error(f"IFRS extras routes not mounted: {e}", exc_info=True)

# ── Fixed Assets Register
try:
    from app.core.fixed_assets_routes import router as fa_router

    app.include_router(fa_router)
    logging.info("Fixed assets routes mounted (lifecycle: cap/dep/reval/imp/dispose)")
except Exception as e:
    logging.error(f"Fixed assets routes not mounted: {e}", exc_info=True)

# ── Transfer Pricing (BEPS Action 13 + KSA ZATCA TP)
try:
    from app.core.transfer_pricing_routes import router as tp_router

    app.include_router(tp_router)
    logging.info("Transfer pricing routes mounted (analyse / methods)")
except Exception as e:
    logging.error(f"Transfer pricing routes not mounted: {e}", exc_info=True)

# ── Advanced IFRS + Tax + Job Costing (SBP/IAS40/IAS41/RETT/P2/VATG/Job)
try:
    from app.core.extras_routes import router as extras_router

    app.include_router(extras_router)
    logging.info("Extras routes mounted (sbp/ip/agri/rett/p2/vatg/job)")
except Exception as e:
    logging.error(f"Extras routes not mounted: {e}", exc_info=True)



@app.get("/")
def root():
    phases = [P1, P2, P3, P4, P5, P6, HAS_P7, HAS_P8, HAS_P9, HAS_P10, HAS_P11]
    return {
        "name": "APEX Financial Platform API",
        "version": "12.0.0",
        "status": "running",
        "phases_active": sum(phases),
        "phases_total": 11,
        "modules": {
            k: "active" if v else "disabled"
            for k, v in {
                "engine": True,
                "kb": KB,
                "p1_identity": P1,
                "p2_clients": P2,
                "p3_knowledge": P3,
                "p4_providers": P4,
                "p5_marketplace": P5,
                "p6_admin": P6,
                "p7_tasks": HAS_P7,
                "p8_entitlements": HAS_P8,
                "p9_account": HAS_P9,
                "p10_notifications": HAS_P10,
                "p11_legal": HAS_P11,
            }.items()
        },
    }


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# ADMIN ENDPOINTS
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ


@app.post("/admin/reinit-db", tags=["Admin"])
def reinit_db(secret: str = Query(None), x_admin_secret: str = Header(None, alias="X-Admin-Secret")):
    _verify_admin(secret, x_admin_secret)
    results = {}

    # Phase 1 â€" Core tables
    try:
        from app.phase1.models.platform_models import Base, engine

        Base.metadata.create_all(bind=engine, checkfirst=True)
        results["phase1"] = "OK"
    except Exception:
        results["phase1"] = "error"

    # Seed data
    try:
        from app.phase1.services.seed_data import seed_all

        results["seed1"] = seed_all()
    except Exception:
        results["seed1"] = "error"

    # Phase 7 seed
    if HAS_P7:
        try:
            from app.phase7.services.seed_phase7 import seed_task_types

            results["phase7_seed"] = seed_task_types()
        except Exception:
            results["phase7"] = "error"

    # Phase 9-11 init
    try:
        if HAS_P9:
            init_phase9_db()
            results["phase9"] = "OK"
    except Exception:
        results["phase9"] = "error"
    try:
        if HAS_P10:
            init_phase10_db()
            results["phase10"] = "OK"
    except Exception:
        results["phase10"] = "error"
    try:
        if HAS_P11:
            init_phase11_db()
            from app.phase11.services.legal_service import seed_legal_documents

            seed_result = seed_legal_documents()
            results["phase11"] = f"OK - {seed_result}"
    except Exception:
        results["phase11"] = "error"

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
        _cols = [
            ("normalized_class", "VARCHAR(100)"),
            ("statement_section", "VARCHAR(100)"),
            ("subcategory", "VARCHAR(200)"),
            ("current_noncurrent", "VARCHAR(20)"),
            ("cashflow_role", "VARCHAR(50)"),
            ("sign_rule", "VARCHAR(20)"),
            ("mapping_confidence", "REAL DEFAULT 0.0"),
            ("mapping_source", "VARCHAR(50)"),
            ("review_status", "VARCHAR(50) DEFAULT 'draft'"),
            ("approved_by", "VARCHAR(255)"),
            ("approved_at", "TIMESTAMP"),
            ("classification_issues_json", "TEXT DEFAULT '[]'"),
        ]
        # Defensive allowlist — ALL values must be simple identifiers.
        import re
        _IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
        _TYPE_WHITELIST = {"VARCHAR", "REAL", "INTEGER", "TEXT", "TIMESTAMP", "BOOLEAN"}
        db = SessionLocal()
        added = 0
        for _cn, _ct in _cols:
            # Validate column name is a safe identifier
            if not _IDENT.match(_cn):
                continue
            # Validate column type starts with an allowed type
            _type_head = _ct.split(" ")[0].split("(")[0].upper()
            if _type_head not in _TYPE_WHITELIST:
                continue
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
        results["s2_cols"] = "error"

    # ── Schema drift repair via shared module ──
    try:
        from app.core.schema_drift import apply_drift_fixes
        _r = apply_drift_fixes(SessionLocal)
        results["schema_drift"] = (
            f"OK - {_r['added']} added, {_r['errors']} errors, {_r['skipped']} skipped"
        )
    except Exception as _e3:
        results["schema_drift"] = f"error: {type(_e3).__name__}"

    # Sprint 3 tables
    try:
        from app.sprint3.models.sprint3_models import init_sprint3_db

        results["sprint3"] = init_sprint3_db()
    except Exception:
        results["sprint3"] = "error"

    # Sprint 4 TB tables
    try:
        from app.sprint4_tb.models.tb_models import init_sprint4_tb_db

        results["sprint4_tb"] = init_sprint4_tb_db()
    except Exception:
        results["sprint4_tb"] = "error"

    # Sprint 5 Analysis tables
    try:
        from app.sprint5_analysis.models.analysis_models import init_sprint5_analysis_db

        results["sprint5_analysis"] = init_sprint5_analysis_db()
    except Exception:
        results["sprint5_analysis"] = "error"

    # Sprint 6 Registry + Eligibility tables
    try:
        from app.sprint6_registry.models.registry_models import init_sprint6_db

        results["sprint6_registry"] = init_sprint6_db()
    except Exception:
        results["sprint6_registry"] = "error"

    # Sprint 4 â€" Knowledge Brain tables (PostgreSQL compatible)
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


@app.get("/admin/stats", tags=["Admin"])
def admin_stats(secret: str = Query(None), x_admin_secret: str = Header(None, alias="X-Admin-Secret")):
    """Platform statistics for admin dashboard."""
    _verify_admin(secret, x_admin_secret)
    from app.phase1.models.platform_models import SessionLocal, User, UserSubscription
    from datetime import datetime, timezone, timedelta

    stats = {}
    db = SessionLocal()
    try:
        # Total users
        try:
            stats["total_users"] = db.query(User).filter(User.is_deleted == False).count()
        except Exception:
            stats["total_users"] = None

        # Total clients
        try:
            from app.phase2.models.phase2_models import Client

            stats["total_clients"] = db.query(Client).count()
        except Exception:
            stats["total_clients"] = None

        # Active subscriptions
        try:
            stats["active_subscriptions"] = (
                db.query(UserSubscription).filter(UserSubscription.status == "active").count()
            )
        except Exception:
            stats["active_subscriptions"] = None

        # Total COA uploads
        try:
            from app.sprint1.models.sprint1_models import ClientCoaUpload

            stats["total_coa_uploads"] = db.query(ClientCoaUpload).count()
        except Exception:
            stats["total_coa_uploads"] = None

        # Total analyses
        try:
            from app.phase2.models.phase2_models import AnalysisResult

            stats["total_analyses"] = db.query(AnalysisResult).count()
        except Exception:
            stats["total_analyses"] = None

        # Plans breakdown
        try:
            from app.phase1.models.platform_models import Plan
            from sqlalchemy import func

            rows = (
                db.query(Plan.name_en, func.count(UserSubscription.id))
                .join(UserSubscription, UserSubscription.plan_id == Plan.id)
                .filter(UserSubscription.status == "active")
                .group_by(Plan.name_en)
                .all()
            )
            stats["plans_breakdown"] = {name: count for name, count in rows}
        except Exception:
            stats["plans_breakdown"] = None

        # Recent registrations (last 7 days)
        try:
            seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
            stats["recent_registrations"] = (
                db.query(User)
                .filter(
                    User.created_at >= seven_days_ago,
                    User.is_deleted == False,
                )
                .count()
            )
        except Exception:
            stats["recent_registrations"] = None

    finally:
        db.close()

    return {"success": True, "data": stats}


@app.get("/admin/users", tags=["Admin"])
def admin_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    secret: str = Query(None),
    x_admin_secret: str = Header(None, alias="X-Admin-Secret"),
):
    """Paginated list of platform users for admin dashboard."""
    _verify_admin(secret, x_admin_secret)
    from app.phase1.models.platform_models import SessionLocal, User, UserRole, Role

    db = SessionLocal()
    try:
        total = db.query(User).filter(User.is_deleted == False).count()
        offset = (page - 1) * page_size
        users_q = (
            db.query(User)
            .filter(User.is_deleted == False)
            .order_by(User.created_at.desc())
            .offset(offset)
            .limit(page_size)
            .all()
        )

        # Pre-fetch all roles in ONE query (fixes N+1)
        user_ids = [u.id for u in users_q]
        role_map = {}  # user_id -> [role_codes]
        if user_ids:
            try:
                role_rows = (
                    db.query(UserRole.user_id, Role.code)
                    .join(Role, Role.id == UserRole.role_id)
                    .filter(UserRole.user_id.in_(user_ids))
                    .all()
                )
                for uid, code in role_rows:
                    role_map.setdefault(uid, []).append(code)
            except Exception:
                logging.warning("Failed to batch-fetch roles", exc_info=True)

        users_list = []
        for u in users_q:
            users_list.append(
                {
                    "id": u.id,
                    "username": u.username,
                    "email": u.email,
                    "display_name": u.display_name,
                    "status": u.status,
                    "created_at": u.created_at.isoformat() if u.created_at else None,
                    "roles": role_map.get(u.id, []),
                }
            )

        return {
            "success": True,
            "data": {
                "users": users_list,
                "total": total,
                "page": page,
                "page_size": page_size,
                "total_pages": (total + page_size - 1) // page_size,
            },
        }
    except Exception:
        logging.error("admin_users failed", exc_info=True)
        raise HTTPException(500, "Failed to fetch users")
    finally:
        db.close()


@app.post("/admin/seed-all", tags=["Admin"])
def seed_all_data(secret: str = Query(None), x_admin_secret: str = Header(None, alias="X-Admin-Secret")):
    _verify_admin(secret, x_admin_secret)
    from app.seed_runner import seed_all

    seed_all()
    return {"success": True, "data": {"message": "All seed data loaded"}}


@app.get("/health")
def health():
    db_ok = False
    try:
        from app.phase1.models.platform_models import SessionLocal
        from sqlalchemy import text as _txt

        db = SessionLocal()
        try:
            db.execute(_txt("SELECT 1"))
            db_ok = True
        finally:
            db.close()
    except Exception:
        pass
    status = "ok" if db_ok else "degraded"
    return {
        "status": status,
        "version": "12.0.0",
        "database": db_ok,
        "phases": {
            "p1": P1,
            "p2": P2,
            "p3": P3,
            "p4": P4,
            "p5": P5,
            "p6": P6,
            "p7": HAS_P7,
            "p8": HAS_P8,
            "p9": HAS_P9,
            "p10": HAS_P10,
            "p11": HAS_P11,
        },
        "sprints": {
            "s1": HAS_S1,
            "s2": HAS_S2,
            "s3": HAS_S3,
            "s4": HAS_S4,
            "s4_tb": HAS_S4_TB,
            "s5": HAS_S5,
            "s6": HAS_S6,
        },
        "engines": {"coa_engine_v4.3": HAS_COA_ENGINE},
        "all_phases_active": all([P1, P2, P3, P4, P5, P6, HAS_P7, HAS_P8]),
    }


# ======================================================================
# RESET POSTGRES â€" Clean drop and recreate all tables
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ


@app.post("/admin/reset-postgres", tags=["Admin"])
def reset_postgres(secret: str = Query(None), x_admin_secret: str = Header(None, alias="X-Admin-Secret")):
    _verify_admin(secret, x_admin_secret)
    from app.phase1.models.platform_models import Base, engine
    from sqlalchemy import text as _txt
    import os

    db_url = os.environ.get("DATABASE_URL", "")
    if "postgres" not in db_url:
        return {"success": False, "error": "Not a PostgreSQL database -- use reinit-db instead"}
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
        return {"success": True, "data": {"message": "All tables dropped and recreated on PostgreSQL"}}
    except Exception:
        logging.error("Database reset failed", exc_info=True)
        return {"success": False, "error": "Database reset failed"}


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# PROMOTE USER â€" Add admin role
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ


@app.post("/admin/promote-user", tags=["Admin"])
def promote_user(
    username: str = Query(...),
    role: str = Query("platform_admin"),
    secret: str = Query(None),
    x_admin_secret: str = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(secret, x_admin_secret)
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
        existing = db.execute(
            _t("SELECT id FROM user_roles WHERE user_id = :uid AND role_id = :rid"), {"uid": uid, "rid": rid}
        ).fetchone()
        if not existing:
            db.execute(
                _t("INSERT INTO user_roles (id, user_id, role_id) VALUES (:id, :uid, :rid)"),
                {"id": str(uuid.uuid4()), "uid": uid, "rid": rid},
            )
            db.commit()
        return {"success": True, "username": username, "role": role}
    finally:
        db.close()


@app.post("/admin/promote/{username}", tags=["Admin"])
async def promote_to_admin(
    username: str, secret: str = Query(None), x_admin_secret: str = Header(None, alias="X-Admin-Secret")
):
    _verify_admin(secret, x_admin_secret)
    try:
        from app.phase1.models.platform_models import SessionLocal, User, UserRole, Role

        db = SessionLocal()
        try:
            user = db.query(User).filter(User.username == username).first()
            if not user:
                raise HTTPException(404, f"User {username} not found")
            admin_role = db.query(Role).filter(Role.code == "platform_admin").first()
            if admin_role:
                existing = (
                    db.query(UserRole).filter(UserRole.user_id == user.id, UserRole.role_id == admin_role.id).first()
                )
                if not existing:
                    db.add(UserRole(user_id=user.id, role_id=admin_role.id))
                    db.commit()
            return {"message": f"{username} promoted to admin", "user_id": str(user.id)}
        finally:
            db.close()
    except HTTPException:
        raise
    except Exception:
        logging.error("Promote user failed", exc_info=True)
        return {"success": False, "error": "Promotion failed"}


# ======================================================================
# ANALYSIS ENDPOINTS
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ


@app.post("/analyze")
async def analyze(
    file: UploadFile = File(...), industry: str = Query("general"), closing_inventory: float = Query(None)
):
    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(400, "Excel only")
    try:
        c = await file.read()
        return orch.analyze_bytes(
            file_bytes=c, filename=file.filename, industry=industry, closing_inventory=closing_inventory
        )
    except Exception:
        logging.error("Analysis error", exc_info=True)
        raise HTTPException(500, "Analysis failed")


@app.post("/analyze/full")
async def analyze_full(
    file: UploadFile = File(...),
    industry: str = Query("general"),
    language: str = Query("ar"),
    closing_inventory: float = Query(None),
):
    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(400, "Excel only")
    c = await file.read()
    try:
        from app.services.ai.narrative_service import NarrativeService

        r = orch.analyze_bytes(
            file_bytes=c, filename=file.filename, industry=industry, closing_inventory=closing_inventory
        )
        if not r.get("success"):
            return r
        n = NarrativeService()
        bc = ""
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService

            bc = KnowledgeBrainService().get_context_for_narrative(r, r.get("knowledge_brain", {}))
        except Exception:
            logging.warning("Failed to get knowledge brain context for narrative", exc_info=True)
        r["narrative"] = await n.generate(r, language=language, brain_context=bc)
        return r
    except Exception:
        logging.error("Full analysis error", exc_info=True)
        raise HTTPException(500, "Analysis failed")


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

    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(400, "Excel files only (.xlsx, .xls)")
    try:
        contents = await file.read()
        result = orch.analyze_bytes(
            file_bytes=contents, filename=file.filename, industry=industry, closing_inventory=closing_inventory
        )
        pdf_bytes = generate_pdf_report(result, client_name=client_name)
        from datetime import datetime as _dt

        fname = f"APEX_Report_{_dt.now().strftime('%Y%m%d_%H%M')}.pdf"
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={fname}",
                "Access-Control-Expose-Headers": "Content-Disposition",
            },
        )
    except Exception:
        logging.error("Report generation error", exc_info=True)
        raise HTTPException(500, "Report generation failed")


@app.post("/classify")
async def classify(file: UploadFile = File(...)):
    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(400, "Excel only")
    try:
        c = await file.read()
        import tempfile

        s = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=s) as tmp:
            tmp.write(c)
            tp = tmp.name
        try:
            rr = orch.reader.read(tp)
        finally:
            try:
                os.unlink(tp)
            except Exception:
                logging.warning("Failed to delete temporary file: %s", tp, exc_info=True)
        rows = rr["rows"]
        if not rows:
            return {"success": False, "error": "No data"}
        cl = orch.classifier.classify_rows(rows)
        return {
            "success": True,
            "filename": file.filename,
            "total": len(rows),
            "summary": orch.classifier.get_summary(cl),
            "accounts": [
                {
                    "name": r.get("account_name", ""),
                    "class": r.get("normalized_class"),
                    "confidence": r.get("confidence", 0),
                }
                for r in cl
            ],
        }
    except Exception:
        logging.error("Classification error", exc_info=True)
        raise HTTPException(500, "Classification failed")


# =â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# STATIC API ENDPOINTS (Phase 7 compliance)
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

# --- User Security ---
# GET /users/me/security is served by phase1_routes (AccountService.get_security_info)


@app.put("/users/me/security/password", tags=["Account"])
async def change_password(body: ChangePasswordRequest, authorization: str = Header(None)):
    from app.phase1.routes.phase1_routes import get_current_user

    user = await get_current_user(authorization)
    if body.new_password != body.confirm_password:
        raise HTTPException(400, "Passwords do not match")
    current = body.current_password
    new_pw = body.new_password
    from app.phase1.services.auth_service import AuthService

    result = AuthService().change_password(user["sub"], current, new_pw)
    if not result.get("success"):
        raise HTTPException(400, result.get("error", "Failed"))
    return {"success": True, "data": {"message": result.get("message", "Password changed successfully")}}


# --- Plans ---
@app.get("/plans", tags=["Subscriptions"])
async def list_plans():
    return {
        "success": True,
        "data": [
            {
                "id": "free",
                "name": "Free",
                "name_ar": "مجاني",
                "price": 0,
                "currency": "SAR",
                "features": {
                    "coa_uploads": 2,
                    "analysis_runs": 5,
                    "result_details": "basic",
                    "marketplace": "browse",
                    "knowledge_mode": False,
                    "exports": "limited",
                },
            },
            {
                "id": "pro",
                "name": "Pro",
                "name_ar": "احترافي",
                "price": 99,
                "currency": "SAR",
                "features": {
                    "coa_uploads": 20,
                    "analysis_runs": 50,
                    "result_details": "full",
                    "marketplace": "request",
                    "knowledge_mode": "if_eligible",
                    "exports": "full",
                },
            },
            {
                "id": "business",
                "name": "Business",
                "name_ar": "أعمال",
                "price": 299,
                "currency": "SAR",
                "features": {
                    "coa_uploads": 100,
                    "analysis_runs": 200,
                    "result_details": "full+export",
                    "marketplace": "request+manage",
                    "knowledge_mode": "if_eligible",
                    "exports": "full",
                    "team_members": 5,
                },
            },
            {
                "id": "expert",
                "name": "Expert",
                "name_ar": "خبير",
                "price": 499,
                "currency": "SAR",
                "features": {
                    "coa_uploads": "unlimited",
                    "analysis_runs": "unlimited",
                    "result_details": "full",
                    "marketplace": "provide",
                    "knowledge_mode": False,
                    "provider_priority": True,
                },
            },
            {
                "id": "enterprise",
                "name": "Enterprise",
                "name_ar": "مؤسسي",
                "price": "custom",
                "currency": "SAR",
                "features": {
                    "coa_uploads": "unlimited",
                    "analysis_runs": "unlimited",
                    "result_details": "full+admin",
                    "marketplace": "custom",
                    "knowledge_mode": "full+governance",
                    "exports": "full",
                    "team_members": "unlimited",
                    "api_access": True,
                },
            },
        ],
    }


# --- Legal ---
@app.get("/legal/terms", tags=["Legal"])
async def get_current_terms():
    return {
        "success": True,
        "data": {
            "version": "1.0",
            "effective_date": "2026-01-01",
            "content_ar": "شروط وأحكام منصة APEX للتحليل المالي المعرفي...",
            "content_en": "APEX Platform Terms and Conditions...",
            "requires_acceptance": True,
        },
    }


@app.get("/legal/privacy", tags=["Legal"])
async def get_privacy_policy():
    return {
        "success": True,
        "data": {
            "version": "1.0",
            "effective_date": "2026-01-01",
            "content_ar": "سياسة الخصوصية لمنصة APEX...",
            "content_en": "APEX Platform Privacy Policy...",
        },
    }


@app.get("/legal/provider-policy", tags=["Legal"])
async def get_provider_policy():
    return {
        "success": True,
        "data": {
            "version": "1.0",
            "effective_date": "2026-01-01",
            "content_ar": "سياسة مقدمي الخدمات...",
            "obligations": [
                "رفع مستندات التحقق",
                "رفع مدخلات المهمة",
                "رفع مخرجات المهمة",
                "العمل ضمن النطاق المعتمد",
                "قبول عمولة المنصة",
            ],
            "suspension_triggers": [
                "عدم رفع المدخلات",
                "عدم رفع المخرجات",
                "تجاوز الموعد",
                "مخالفة جودة العمل",
            ],
        },
    }


@app.get("/legal/acceptable-use", tags=["Legal"])
async def get_acceptable_use():
    return {
        "success": True,
        "data": {
            "version": "1.0",
            "effective_date": "2026-01-01",
            "content_ar": "سياسة الاستخدام المقبول لمنصة APEX...",
        },
    }


@app.post("/legal/accept", tags=["Legal"])
async def accept_legal(body: AcceptLegalRequest, authorization: str = Header(None)):
    from app.phase1.routes.phase1_routes import get_current_user

    user = await get_current_user(authorization)
    doc_id = body.document_id
    from app.phase11.services.legal_service import accept_document

    result = accept_document(user["sub"], doc_id)
    if not result.get("success", True):
        raise HTTPException(400, result.get("error", "فشل العملية"))
    return result


# --- Account Closure ---
@app.post("/account/closure", tags=["Account"])
async def request_closure(body: AccountClosureRequest):
    closure_type = body.type
    return {
        "success": True,
        "data": {
            "message": f"{'Temporary deactivation' if closure_type == 'temporary' else 'Permanent closure'} request submitted",
            "type": closure_type,
            "status": "pending",
            "retention_notice": "Data will be retained per legal requirements" if closure_type == "permanent" else None,
        },
    }


# ═══════════════════════════════════════════════════════════════
# Route Ownership Registry (single source of truth — do NOT duplicate)
# ═══════════════════════════════════════════════════════════════
# Each URL prefix is owned by exactly one phase/sprint router. Any change
# requires updating this table AND the corresponding router. Duplication
# causes FastAPI "route shadowing" where behaviour depends on include order.
#
# Prefix/Path                         Owner
# ──────────────────────────────────  ────────────────────────────
#   /auth/*                           Phase 1 (phase1_routes.py)
#   /users/me, /users/me/security,    Phase 1
#     /users/me/sessions
#   /account/profile, /account/       Phase 9 (phase9_routes.py)
#     sessions, /account/activity,
#     /account/closure
#   /plans, /subscriptions, /legal    Phase 1
#   /clients, /client-types           Phase 2 (phase2_routes.py)
#   /coa/*, /coa-uploads              Phase 2 / Sprint 2-3
#   /knowledge-feedback/*             Phase 3 ONLY
#   /service-providers/*              Phase 4 ONLY
#   /services/catalog, /services/     Phase 2 (service_catalog_routes)
#     cases
#   /audit/*                          Phase 2 (audit service)
#   /providers/compliance/*           Phase 7 ONLY
#   /task-types                       Phase 7 ONLY
#   /entitlements/*                   Phase 8
#   /notifications/*                  Phase 10
#   /admin/*                          main.py + Phase 6
#   /kb/*                             Knowledge Brain
#   /copilot/*                        Copilot service
# ═══════════════════════════════════════════════════════════════


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)