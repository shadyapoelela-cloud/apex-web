from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import os, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.phase1.models.platform_models import Base, DB_URL

# Import ALL model modules so their classes register with Base.metadata.
# Wildcard imports are used here intentionally (exception to project rule)
# because we only need the side-effect of model class registration.
from app.phase1.models.platform_models import *  # noqa: F403
from app.phase2.models.phase2_models import *
from app.phase2.models.onboarding_models import *
from app.phase2.models.archive_models import *
from app.phase2.models.service_catalog_models import *
from app.phase3.models.phase3_models import *
from app.phase4.models.phase4_models import *
from app.phase5.models.phase5_models import *
from app.phase7.models.phase7_models import *
from app.phase8.models.phase8_models import *
from app.phase9.models.phase9_models import *
from app.phase10.models.phase10_models import *
from app.phase11.models.phase11_models import *
from app.sprint1.models.sprint1_models import *
try:
    from app.sprint2.models.sprint2_models import *
except ImportError:
    pass
from app.sprint3.models.sprint3_models import *
from app.sprint4_tb.models.tb_models import *
from app.sprint5_analysis.models.analysis_models import *
from app.sprint6_registry.models.registry_models import *
from app.knowledge_brain.models.db_models import *

# New modules (HR, AP Agent) — added 2026-04-17 as part of Q1-Q2 scaffolds.
# These must be registered so `alembic revision --autogenerate` detects them.
from app.hr.models import *  # noqa: F401,F403
from app.features.ap_agent.models import *  # noqa: F401,F403

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def get_url():
    return DB_URL


def run_migrations_offline():
    url = get_url()
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True, dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    configuration = config.get_section(config.config_ini_section)
    configuration["sqlalchemy.url"] = get_url()
    connectable = engine_from_config(configuration, prefix="sqlalchemy.", poolclass=pool.NullPool)
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()


