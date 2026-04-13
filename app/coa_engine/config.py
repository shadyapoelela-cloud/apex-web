"""
APEX COA Engine v4.3 — Configuration
مستخرجة مباشرة من الوثيقة
"""
from __future__ import annotations
import os

# ── قاعدة البيانات ──────────────────────────────────────────
DATABASE_URL = os.getenv("COA_DATABASE_URL", os.getenv("DATABASE_URL", ""))

# ── حدود الملفات (القسم 3 — خطوة 0) ──────────────────────────
MAX_FILE_SIZE_MB  = 10
MAX_FILE_SIZE     = MAX_FILE_SIZE_MB * 1024 * 1024
MAX_ROWS          = 5_000
ALLOWED_EXTENSIONS = {".xlsx", ".xls", ".csv"}

# ── عتبات الثقة — 4 شرائح (القسم 8 + Table 57) ────────────────
CONFIDENCE_AUTO_APPROVE  = 0.90   # ≥ 90% → auto_approved
CONFIDENCE_AUTO_CLASSIFY = 0.70   # 70-89% → auto_classified (عرض للمراجعة)
CONFIDENCE_PENDING_REVIEW= 0.50   # 50-69% → pending_review
CONFIDENCE_LLM_FALLBACK  = 0.50   # < 50% → الطبقة 5 (Claude API) + rejected_pending
# الحفاظ على التوافق مع الكود القائم
CONFIDENCE_REVIEW        = 0.70   # < 70% → review_queue إجباري

# ── درجة الجودة (القسم 8 — QUALITY_WEIGHTS) ──────────────────
QUALITY_WEIGHTS = {
    "classification_accuracy": 0.30,
    "error_severity":          0.35,
    "completeness":            0.20,
    "naming_quality":          0.10,
    "code_consistency":        0.05,
}
QUALITY_MIN_APPROVAL = 65        # الحد الأدنى للاعتماد

# خصومات الأخطاء
ERROR_DEDUCTIONS = {"Critical": -15, "High": -8, "Medium": -3, "Low": -1}

# ── Claude API (ملحق ح) ──────────────────────────────────────
ANTHROPIC_API_KEY   = os.getenv("ANTHROPIC_API_KEY", "")
LLM_MODEL           = "claude-sonnet-4-20250514"
LLM_MAX_TOKENS      = 200
LLM_TEMPERATURE     = 0.0
LLM_TIMEOUT_SECONDS = 15
LLM_RETRY_COUNT     = 2
LLM_RETRY_DELAY     = 2.0
LLM_FALLBACK_STATUS = "pending_review"

# ── Undo tokens (ملحق ذ.7) ────────────────────────────────────
UNDO_TOKEN_TTL_HOURS = 72
UNDO_SECRET_KEY      = os.getenv("UNDO_SECRET_KEY", "change-me-in-production")

# ── الترميز (ملحق ب) ─────────────────────────────────────────
ARABIC_ENCODINGS = ["utf-8-sig", "utf-8", "windows-1256", "cp1256", "iso-8859-6"]

# ── API ──────────────────────────────────────────────────────
API_PREFIX   = "/api/v1"
CORS_ORIGINS = ["*"]
