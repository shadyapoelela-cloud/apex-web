"""Alembic environment — rewritten for Wave 10 (closes Wave 0 debt).

The prior version did `from app.phase1.models.platform_models import Base`
then wildcard-imported ~18 model modules. Because `app.knowledge_brain.
models.db_models` declares its OWN `Base = declarative_base()`, the
last `import *` shadowed the name and `target_metadata = Base.metadata`
wound up pointing at the Knowledge-Brain base (14 tables) instead of
the ~95-table phase1 base. Any `alembic revision --autogenerate` would
then generate a migration that dropped the `users` table.

Fix:
1. Import each Base under a distinct alias so `*` imports can't shadow.
2. Import model modules explicitly — the side effect registers each
   mapped class with its respective Base.
3. Target ONLY the phase1 metadata. Knowledge-Brain runs against a
   SEPARATE engine (KB_DATABASE_URL, typically a different database),
   so including its tables in Alembic would produce false drift every
   time — "these KB tables are in metadata but not in the phase1 DB".
   KB tables are still maintained by `create_all` during startup.
"""

from logging.config import fileConfig
import importlib
import os
import sys

from sqlalchemy import engine_from_config, pool

from alembic import context

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ── Import each Base under a distinct alias so wildcard-style model
# imports elsewhere in the codebase can never shadow it again.
from app.phase1.models.platform_models import Base as PhaseBase, DB_URL

# Importing KB Base is NOT required for autogenerate (it's a separate
# DB). We keep the explicit import + alias only to document the
# relationship and to make sure the KB models module is loaded in
# case phase1 models reference it in any relationship.
from app.knowledge_brain.models.db_models import Base as _KnowledgeBrainBase  # noqa: F401

# ── Register every phase/sprint model module with PhaseBase ──────────
# Importing the module triggers the class-definition side effect that
# registers the mapped class with its Base. Optional modules (sprint2)
# may be missing from a given checkout — handle ImportError gracefully.
_MODEL_MODULES = (
    "app.phase1.models.platform_models",
    "app.phase2.models.phase2_models",
    "app.phase2.models.onboarding_models",
    "app.phase2.models.archive_models",
    "app.phase2.models.service_catalog_models",
    "app.phase3.models.phase3_models",
    "app.phase4.models.phase4_models",
    "app.phase5.models.phase5_models",
    "app.phase7.models.phase7_models",
    "app.phase8.models.phase8_models",
    "app.phase9.models.phase9_models",
    "app.phase10.models.phase10_models",
    "app.phase11.models.phase11_models",
    "app.sprint1.models.sprint1_models",
    "app.sprint2.models.sprint2_models",  # optional
    "app.sprint3.models.sprint3_models",
    "app.sprint4_tb.models.tb_models",
    "app.sprint5_analysis.models.analysis_models",
    "app.sprint6_registry.models.registry_models",
    # Wave 5 + 7 additions that declare tables on PhaseBase.
    "app.core.compliance_models",
)


def _import_model_modules() -> None:
    for name in _MODEL_MODULES:
        try:
            importlib.import_module(name)
        except ImportError:
            # Optional modules (e.g. sprint2) may not exist.
            continue


_import_model_modules()

# New modules (HR, AP Agent) — added 2026-04-17 as part of Q1-Q2 scaffolds.
# These must be registered so `alembic revision --autogenerate` detects them.
from app.hr.models import *  # noqa: F401,F403
from app.features.ap_agent.models import *  # noqa: F401,F403

# Newer infra modules — register so migrations include them.
# Added 2026-04-17 (PWA sync, ZATCA retry, branding, activity log).
from app.core.offline_sync import SyncOperation  # noqa: F401
from app.integrations.zatca.retry_queue import ZatcaSubmission  # noqa: F401
from app.core.tenant_branding import TenantBranding  # noqa: F401
from app.core.activity_log import ActivityLog  # noqa: F401

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = PhaseBase.metadata


def get_url() -> str:
    return DB_URL


def run_migrations_offline() -> None:
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    configuration = config.get_section(config.config_ini_section)
    configuration["sqlalchemy.url"] = get_url()
    connectable = engine_from_config(
        configuration, prefix="sqlalchemy.", poolclass=pool.NullPool
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
