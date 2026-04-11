"""
APEX — Sprint 2 models for COA account classification and review workflow
نماذج السبرنت الثاني لتصنيف الحسابات ومراجعة شجرة الحسابات
"""

import enum
from sqlalchemy import Column, String, Float, Text, DateTime, Boolean, Integer, Enum as SAEnum, func
from sqlalchemy.ext.declarative import declarative_base

# We'll add classification columns to the existing ClientChartOfAccount
# via ALTER TABLE in init_sprint2_db()


class ReviewStatus(str, enum.Enum):
    draft = "draft"
    auto_classified = "auto_classified"
    manually_edited = "manually_edited"
    approved = "approved"
    rejected = "rejected"


class MappingSource(str, enum.Enum):
    auto_rule = "auto_rule"
    exact_match = "exact_match"
    alias_match = "alias_match"
    parent_context = "parent_context"
    code_prefix = "code_prefix"
    manual = "manual"
    bulk_approve = "bulk_approve"


# Classification columns to add to client_chart_of_accounts
CLASSIFICATION_COLUMNS = {
    "normalized_class": "VARCHAR(100)",
    "statement_section": "VARCHAR(100)",
    "subcategory": "VARCHAR(200)",
    "current_noncurrent": "VARCHAR(20)",
    "cashflow_role": "VARCHAR(50)",
    "sign_rule": "VARCHAR(20)",
    "mapping_confidence": "REAL DEFAULT 0.0",
    "mapping_source": "VARCHAR(50)",
    "review_status": "VARCHAR(50) DEFAULT 'draft'",
    "approved_by": "VARCHAR(255)",
    "approved_at": "TIMESTAMP",
    "classification_issues_json": "TEXT DEFAULT '[]'",
}


def init_sprint2_db(engine=None):
    """Add classification columns to existing client_chart_of_accounts table."""
    if engine is None:
        try:
            from app.phase1.models.platform_models import engine as eng

            engine = eng
        except Exception:
            from app.phase1.models.platform_models import SessionLocal

            db = SessionLocal()
            engine = db.bind
            db.close()
    import sqlite3

    conn = engine.raw_connection()
    cursor = conn.cursor()

    added = []
    skipped = []

    for col_name, col_type in CLASSIFICATION_COLUMNS.items():
        try:
            cursor.execute(f"ALTER TABLE client_chart_of_accounts ADD COLUMN {col_name} {col_type}")
            added.append(col_name)
        except Exception:
            skipped.append(col_name)

    conn.commit()
    conn.close()
    return f"Sprint 2 init: added {len(added)} columns, skipped {len(skipped)} (already exist)"
