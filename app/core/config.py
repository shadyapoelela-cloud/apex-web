"""
APEX Platform - Centralized Configuration (Pydantic BaseSettings)
================================================================
Single source of truth for all environment variables.
Replaces scattered os.getenv() calls throughout the codebase.

Usage:
    from app.core.config import settings
    print(settings.database_url)
"""

from __future__ import annotations

from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import field_validator

# Populate os.environ from .env so legacy os.getenv() calls (still in main.py
# and several modules) see the same values that Settings does. This is a
# backward-compat bridge during the gradual migration to settings.xyz.
try:
    from dotenv import load_dotenv as _load_dotenv
    _load_dotenv()
except ImportError:
    pass


class Settings(BaseSettings):
    """All APEX platform configuration loaded from environment / .env file."""

    # -- Environment
    environment: str = "development"

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in ("production", "prod")

    # -- Database
    database_url: str = "sqlite:///apex_platform.db"
    kb_database_url: Optional[str] = None

    @field_validator("database_url", mode="before")
    @classmethod
    def fix_postgres_url(cls, v: str) -> str:
        """Render PostgreSQL fix: postgres:// -> postgresql://"""
        if v and v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    @field_validator("kb_database_url", mode="before")
    @classmethod
    def fix_kb_postgres_url(cls, v: Optional[str]) -> Optional[str]:
        if v and v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    # -- Authentication
    jwt_secret: str = "apex-dev-secret-CHANGE-IN-PRODUCTION"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    # -- Admin
    admin_secret: str = "apex-admin-dev-only"

    # -- CORS
    cors_origins: str = "*"

    @property
    def cors_origins_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    # -- AI Services
    anthropic_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None
    google_api_key: Optional[str] = None

    # -- Email
    email_backend: str = "console"
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "noreply@apex-app.com"
    sendgrid_api_key: Optional[str] = None
    sendgrid_from: str = "noreply@apex-app.com"
    platform_url: str = "https://apex-app.com"

    # -- Payment
    payment_backend: str = "mock"
    stripe_secret_key: Optional[str] = None
    stripe_webhook_secret: Optional[str] = None
    payment_currency: str = "SAR"

    # -- Storage
    storage_backend: str = "local"
    storage_local_dir: str = "uploads"
    s3_bucket: Optional[str] = None
    s3_region: str = "us-east-1"
    s3_access_key: Optional[str] = None
    s3_secret_key: Optional[str] = None
    s3_endpoint_url: Optional[str] = None

    # -- Observability
    sentry_dsn: Optional[str] = None
    sentry_environment: str = "production"
    sentry_traces_sample_rate: float = 0.05
    sentry_release: Optional[str] = None
    log_format: str = "text"
    log_level: str = "INFO"

    # -- Security
    csrf_enabled: bool = False
    tenant_strict: bool = True
    audit_log_enabled: bool = True
    totp_encryption_key: Optional[str] = None
    zatca_cert_encryption_key: Optional[str] = None
    bank_feeds_encryption_key: Optional[str] = None

    # -- SMS / OTP
    sms_backend: str = "console"
    otp_backend: str = "memory"
    unifonic_app_sid: Optional[str] = None
    unifonic_sender_id: str = "APEX"
    twilio_account_sid: Optional[str] = None
    twilio_auth_token: Optional[str] = None
    twilio_from_number: Optional[str] = None

    # -- Social Auth
    google_oauth_client_id: Optional[str] = None
    apple_client_id: Optional[str] = None

    # -- Multi-tenancy
    run_migrations_on_startup: bool = False

    # -- Redis
    redis_url: Optional[str] = None

    # -- ZATCA Worker
    zatca_worker_enabled: bool = False

    # -- Backup
    backup_s3_bucket: Optional[str] = None
    backup_s3_region: str = "us-east-1"
    backup_retention_days: int = 30

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
        "case_sensitive": False,
    }


# Singleton instance - import this everywhere
settings = Settings()
