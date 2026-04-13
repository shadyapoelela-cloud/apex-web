"""
APEX COA Engine v4.3 — Database Layer
======================================
Supports PostgreSQL (asyncpg) and SQLite (aiosqlite) fallback.
When no database is configured, operates in memory-only mode.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from .config import UNDO_TOKEN_TTL_HOURS, UNDO_SECRET_KEY

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────
# DDL — SQLite-compatible schema
# ─────────────────────────────────────────────────────────────
SQLITE_DDL = """
CREATE TABLE IF NOT EXISTS coa_error_registry (
    error_code        TEXT PRIMARY KEY,
    name_ar           TEXT NOT NULL,
    severity          TEXT NOT NULL,
    category          TEXT NOT NULL,
    description_ar    TEXT,
    cause_ar          TEXT,
    suggestion_ar     TEXT,
    auto_fixable      INTEGER DEFAULT 0,
    references_list   TEXT DEFAULT '[]',
    wave              INTEGER DEFAULT 1,
    created_at        TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS client_coa_uploads (
    id                  TEXT PRIMARY KEY,
    client_id           TEXT,
    original_filename   TEXT NOT NULL,
    file_size_bytes     INTEGER,
    erp_system          TEXT,
    upload_status       TEXT NOT NULL DEFAULT 'processing',
    pattern_detected    TEXT,
    encoding_detected   TEXT DEFAULT 'utf-8',
    column_mapping_json TEXT DEFAULT '{}',
    total_accounts      INTEGER DEFAULT 0,
    auto_approved       INTEGER DEFAULT 0,
    pending_review      INTEGER DEFAULT 0,
    processing_ms       INTEGER,
    session_health_json TEXT DEFAULT '{}',
    created_at          TEXT DEFAULT (datetime('now')),
    updated_at          TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS client_chart_of_accounts (
    id                    TEXT PRIMARY KEY,
    upload_id             TEXT NOT NULL,
    account_code          TEXT NOT NULL,
    name_raw              TEXT,
    name_normalized       TEXT,
    parent_code           TEXT,
    level_num             INTEGER,
    concept_id            TEXT,
    section               TEXT,
    nature                TEXT DEFAULT 'unknown',
    account_level         TEXT DEFAULT 'unknown',
    confidence            REAL DEFAULT 0.0,
    classification_method TEXT,
    review_status         TEXT NOT NULL DEFAULT 'pending',
    auto_fix_applied      INTEGER DEFAULT 0,
    auto_fix_id           TEXT,
    created_at            TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (upload_id) REFERENCES client_coa_uploads(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_coa_upload ON client_chart_of_accounts(upload_id);
CREATE INDEX IF NOT EXISTS idx_coa_review ON client_chart_of_accounts(upload_id, review_status);

CREATE TABLE IF NOT EXISTS coa_account_errors (
    id                TEXT PRIMARY KEY,
    upload_id         TEXT NOT NULL,
    account_code      TEXT,
    account_name      TEXT,
    error_code        TEXT NOT NULL,
    severity          TEXT NOT NULL,
    description_ar    TEXT,
    cause_ar          TEXT,
    suggestion_ar     TEXT,
    auto_fixable      INTEGER DEFAULT 0,
    auto_fix_applied  INTEGER DEFAULT 0,
    references_list   TEXT DEFAULT '[]',
    resolved          INTEGER DEFAULT 0,
    resolved_at       TEXT,
    resolved_by       TEXT,
    created_at        TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (upload_id) REFERENCES client_coa_uploads(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_errors_upload ON coa_account_errors(upload_id);

CREATE TABLE IF NOT EXISTS client_coa_assessments (
    id                      TEXT PRIMARY KEY,
    upload_id               TEXT NOT NULL UNIQUE,
    overall_score           REAL DEFAULT 0,
    quality_grade           TEXT,
    quality_dimensions_json TEXT DEFAULT '{}',
    errors_summary_json     TEXT DEFAULT '{}',
    confidence_avg          REAL,
    sector_detected         TEXT,
    sector_similarity       REAL,
    recommendations_json    TEXT DEFAULT '[]',
    created_at              TEXT DEFAULT (datetime('now')),
    updated_at              TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (upload_id) REFERENCES client_coa_uploads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS coa_approval_records (
    id                  TEXT PRIMARY KEY,
    upload_id           TEXT NOT NULL,
    action              TEXT NOT NULL,
    approved_by         TEXT NOT NULL,
    quality_score       REAL,
    blocked_by_errors   TEXT DEFAULT '[]',
    override_reason     TEXT,
    override_error_code TEXT,
    notes               TEXT,
    created_at          TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (upload_id) REFERENCES client_coa_uploads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS auto_fix_log (
    id               TEXT PRIMARY KEY,
    upload_id        TEXT NOT NULL,
    account_code     TEXT NOT NULL,
    fix_type         TEXT NOT NULL,
    before_value     TEXT NOT NULL,
    after_value      TEXT NOT NULL,
    fix_confidence   REAL,
    fix_reason_ar    TEXT,
    undo_token       TEXT UNIQUE,
    undo_token_exp   TEXT,
    undone_at        TEXT,
    undone_by        TEXT,
    created_at       TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (upload_id) REFERENCES client_coa_uploads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS coa_versions (
    id             TEXT PRIMARY KEY,
    client_id      TEXT,
    version_number INTEGER NOT NULL,
    upload_id      TEXT,
    approved_by    TEXT,
    quality_score  REAL,
    total_accounts INTEGER DEFAULT 0,
    label          TEXT,
    approved_at    TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sector_benchmarks (
    sector_code             TEXT PRIMARY KEY,
    sector_name_ar          TEXT NOT NULL,
    avg_score               REAL DEFAULT 0,
    avg_accounts            INTEGER DEFAULT 0,
    common_errors           TEXT DEFAULT '[]',
    mandatory_coverage_avg  REAL DEFAULT 0,
    sample_size             INTEGER DEFAULT 0,
    updated_at              TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS coa_migration_map (
    id                      TEXT PRIMARY KEY,
    client_id               TEXT NOT NULL,
    from_version            INTEGER NOT NULL,
    to_version              INTEGER NOT NULL,
    old_code                TEXT NOT NULL,
    new_code                TEXT,
    canonical_id            TEXT,
    map_type                TEXT NOT NULL,
    confidence              REAL,
    source_natures_conflict INTEGER DEFAULT 0,
    split_targets           TEXT DEFAULT '[]',
    old_name                TEXT,
    new_name                TEXT,
    old_section             TEXT,
    new_section             TEXT,
    old_nature              TEXT,
    new_nature              TEXT,
    auto_matched            INTEGER DEFAULT 1,
    reviewed_by             TEXT,
    created_at              TEXT DEFAULT (datetime('now')),
    UNIQUE(client_id, from_version, to_version, old_code)
);

CREATE INDEX IF NOT EXISTS idx_migration_client_ver
    ON coa_migration_map(client_id, from_version, to_version);

CREATE TABLE IF NOT EXISTS canonical_accounts (
    concept_id          TEXT PRIMARY KEY,
    code_pattern        TEXT NOT NULL,
    name_ar             TEXT NOT NULL,
    name_en             TEXT,
    section             TEXT NOT NULL,
    nature              TEXT NOT NULL DEFAULT 'debit',
    level               TEXT NOT NULL DEFAULT 'detail',
    definition_ar       TEXT,
    mandatory_sectors   TEXT DEFAULT '[]',
    created_at          TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS coa_evolution_log (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id           TEXT NOT NULL,
    from_version        INTEGER NOT NULL,
    to_version          INTEGER NOT NULL,
    change_type         TEXT NOT NULL,
    account_code        TEXT,
    old_value           TEXT,
    new_value           TEXT,
    risk_level          TEXT DEFAULT 'low',
    created_at          TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_evolution_client
    ON coa_evolution_log(client_id, from_version, to_version);

CREATE TABLE IF NOT EXISTS engine_rules (
    rule_id             TEXT PRIMARY KEY,
    rule_name           TEXT NOT NULL,
    description_ar      TEXT,
    rule_type           TEXT NOT NULL DEFAULT 'error_check',
    condition_json      TEXT NOT NULL DEFAULT '{}',
    action_json         TEXT NOT NULL DEFAULT '{}',
    severity            TEXT NOT NULL DEFAULT 'Medium',
    status              TEXT NOT NULL DEFAULT 'draft',
    version             INTEGER NOT NULL DEFAULT 1,
    proposed_by         TEXT,
    approved_by         TEXT,
    deprecated_by       TEXT,
    proposed_at         TEXT DEFAULT (datetime('now')),
    approved_at         TEXT,
    deprecated_at       TEXT,
    ab_test_group       TEXT,
    success_rate        REAL DEFAULT 0.0,
    execution_count     INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS governance_alerts (
    alert_id            TEXT PRIMARY KEY,
    rule_id             TEXT NOT NULL,
    alert_type          TEXT NOT NULL DEFAULT 'auto_rollback',
    message             TEXT NOT NULL,
    severity            TEXT NOT NULL DEFAULT 'High',
    details_json        TEXT DEFAULT '{}',
    resolved            INTEGER DEFAULT 0,
    resolved_by         TEXT,
    created_at          TEXT DEFAULT (datetime('now')),
    resolved_at         TEXT
);
"""

SECTOR_BENCHMARKS_SEED = [
    ("RETAIL",        "التجزئة والجملة",       72.0, 145, 0.68, 25),
    ("CONSTRUCTION",  "المقاولات",             68.0, 180, 0.62, 18),
    ("MANUFACTURING", "الصناعة والتصنيع",       75.0, 220, 0.71, 22),
    ("HEALTHCARE",    "الرعاية الصحية",        71.0, 160, 0.65, 15),
    ("BANKING",       "البنوك والتمويل الإسلامي", 82.0, 300, 0.78, 12),
    ("REAL_ESTATE",   "العقارات والتطوير",      70.0, 170, 0.64, 20),
    ("HAJJ_UMRAH",    "الحج والعمرة",           65.0, 120, 0.58, 10),
    ("AGRICULTURE",   "الزراعة والألبان",       63.0, 130, 0.55, 8),
    ("FOOD_BEVERAGE", "الأغذية والمشروبات",     70.0, 150, 0.66, 14),
    ("HOSPITALITY",   "الضيافة والفنادق",       69.0, 140, 0.63, 11),
    ("EDUCATION",     "التعليم والتدريب",       72.0, 130, 0.67, 16),
    ("INSURANCE",     "التأمين",               78.0, 250, 0.74, 9),
    ("TELECOM",       "الاتصالات وتقنية المعلومات", 76.0, 200, 0.72, 7),
    ("TRANSPORT",     "النقل",                 66.0, 120, 0.60, 12),
    ("LOGISTICS",     "الخدمات اللوجستية",      67.0, 135, 0.61, 10),
    ("ENERGY",        "الطاقة والكهرباء",       74.0, 190, 0.70, 6),
    ("OIL_GAS",       "النفط والغاز",           80.0, 280, 0.76, 5),
    ("MINING",        "التعدين",               73.0, 175, 0.69, 4),
    ("GOVERNMENT",    "الجهات الحكومية",        68.0, 160, 0.62, 8),
    ("NGO",           "المنظمات غير الربحية",   64.0, 100, 0.56, 6),
    ("PROFESSIONAL_SERVICES", "الخدمات المهنية", 71.0, 110, 0.65, 20),
    ("ECOMMERCE",     "التجارة الإلكترونية",    69.0, 130, 0.63, 15),
    ("CONTRACTING",   "المقاولات العامة",       67.0, 170, 0.61, 14),
    ("TRADING",       "التجارة العامة",         70.0, 140, 0.65, 22),
    ("IT_SERVICES",   "خدمات تقنية المعلومات",   73.0, 115, 0.68, 12),
]


# ─────────────────────────────────────────────────────────────
# Undo Token
# ─────────────────────────────────────────────────────────────
def generate_undo_token(fix_id: str) -> tuple:
    exp = datetime.now(timezone.utc) + timedelta(hours=UNDO_TOKEN_TTL_HOURS)
    payload = f"{fix_id}:{exp.isoformat()}"
    sig = hmac.new(UNDO_SECRET_KEY.encode(), payload.encode(), hashlib.sha256).hexdigest()
    token = f"undo_{fix_id[:8]}_{sig[:16]}"
    return token, exp.isoformat()


# ─────────────────────────────────────────────────────────────
# Database Class — SQLite with aiosqlite
# ─────────────────────────────────────────────────────────────
class Database:
    def __init__(self, db_path: str = "coa_engine.db") -> None:
        self._db_path = db_path
        self._conn = None

    async def connect(self) -> None:
        try:
            import aiosqlite
            self._conn = await aiosqlite.connect(self._db_path)
            self._conn.row_factory = aiosqlite.Row
            await self._conn.execute("PRAGMA journal_mode=WAL")
            await self._conn.execute("PRAGMA foreign_keys=ON")
        except ImportError:
            import sqlite3
            self._conn = None
            conn = sqlite3.connect(self._db_path)
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA foreign_keys=ON")
            for stmt in SQLITE_DDL.split(";"):
                stmt = stmt.strip()
                if stmt:
                    conn.execute(stmt)
            conn.commit()
            conn.close()
            logger.warning("aiosqlite not installed; schema created with sync sqlite3. DB operations will be limited.")

    async def disconnect(self) -> None:
        if self._conn:
            await self._conn.close()

    async def initialize_schema(self) -> None:
        if self._conn:
            for stmt in SQLITE_DDL.split(";"):
                stmt = stmt.strip()
                if stmt:
                    await self._conn.execute(stmt)
            await self._conn.commit()
            # Seed sector benchmarks (idempotent)
            await self._seed_sector_benchmarks()

    async def _seed_sector_benchmarks(self) -> None:
        if not self._conn:
            return
        for code, name_ar, avg_score, avg_accounts, mandatory_cov, sample_size in SECTOR_BENCHMARKS_SEED:
            await self._conn.execute(
                """INSERT OR IGNORE INTO sector_benchmarks
                   (sector_code, sector_name_ar, avg_score, avg_accounts,
                    mandatory_coverage_avg, sample_size)
                   VALUES (?,?,?,?,?,?)""",
                (code, name_ar, avg_score, avg_accounts, mandatory_cov, sample_size),
            )
        await self._conn.commit()
        logger.info(f"Sector benchmarks seeded: {len(SECTOR_BENCHMARKS_SEED)} entries")

    @property
    def is_connected(self) -> bool:
        return self._conn is not None

    def _uid(self) -> str:
        return str(uuid.uuid4())

    async def create_upload(
        self, original_filename: str, file_size_bytes: int,
        erp_system: Optional[str] = None, client_id: Optional[str] = None,
    ) -> str:
        if not self._conn:
            return self._uid()
        uid = self._uid()
        await self._conn.execute(
            "INSERT INTO client_coa_uploads (id, client_id, original_filename, file_size_bytes, erp_system) VALUES (?,?,?,?,?)",
            (uid, client_id, original_filename, file_size_bytes, erp_system),
        )
        await self._conn.commit()
        return uid

    async def update_upload_status(
        self, upload_id: str, status: str, pattern: Optional[str] = None,
        encoding: Optional[str] = None, col_mapping: Optional[Dict] = None,
        total_accounts: Optional[int] = None, auto_approved: Optional[int] = None,
        pending_review: Optional[int] = None, processing_ms: Optional[int] = None,
        session_health: Optional[Dict] = None,
    ) -> None:
        if not self._conn:
            return
        sets = ["upload_status=?", "updated_at=datetime('now')"]
        params: list = [status]
        for col, val in [
            ("pattern_detected", pattern),
            ("encoding_detected", encoding),
            ("column_mapping_json", json.dumps(col_mapping) if col_mapping else None),
            ("total_accounts", total_accounts),
            ("auto_approved", auto_approved),
            ("pending_review", pending_review),
            ("processing_ms", processing_ms),
            ("session_health_json", json.dumps(session_health) if session_health else None),
        ]:
            if val is not None:
                sets.append(f"{col}=?")
                params.append(val)
        params.append(upload_id)
        await self._conn.execute(
            f"UPDATE client_coa_uploads SET {', '.join(sets)} WHERE id=?", params,
        )
        await self._conn.commit()

    async def get_upload(self, upload_id: str) -> Optional[Dict]:
        if not self._conn:
            return None
        async with self._conn.execute("SELECT * FROM client_coa_uploads WHERE id=?", (upload_id,)) as cursor:
            row = await cursor.fetchone()
        return dict(row) if row else None

    async def save_accounts(self, upload_id: str, accounts: List[Dict]) -> None:
        if not self._conn:
            return
        for a in accounts:
            await self._conn.execute(
                """INSERT OR IGNORE INTO client_chart_of_accounts
                   (id,upload_id,account_code,name_raw,name_normalized,parent_code,
                    level_num,concept_id,section,nature,account_level,confidence,
                    classification_method,review_status,auto_fix_applied)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    self._uid(), upload_id,
                    str(a.get("code", "") or ""),
                    a.get("name_raw", ""),
                    a.get("name_normalized", ""),
                    a.get("parent_code"),
                    a.get("level_num"),
                    a.get("concept_id"),
                    a.get("section"),
                    a.get("nature", "unknown"),
                    a.get("account_level", "unknown"),
                    float(a.get("confidence", 0.0)),
                    a.get("classification_method"),
                    a.get("review_status", "pending"),
                    1 if a.get("auto_fix_applied") else 0,
                ),
            )
        await self._conn.commit()

    async def get_accounts(
        self, upload_id: str, review_status: Optional[str] = None,
        min_confidence: Optional[float] = None, section: Optional[str] = None,
    ) -> List[Dict]:
        if not self._conn:
            return []
        conds = ["upload_id=?"]
        params: list = [upload_id]
        if review_status:
            conds.append("review_status=?"); params.append(review_status)
        if min_confidence is not None:
            conds.append("confidence>=?"); params.append(min_confidence)
        if section:
            conds.append("section=?"); params.append(section)
        async with self._conn.execute(
            f"SELECT * FROM client_chart_of_accounts WHERE {' AND '.join(conds)} ORDER BY account_code",
            params,
        ) as cursor:
            rows = await cursor.fetchall()
        return [dict(r) for r in rows]

    async def update_account_review(
        self, upload_id: str, account_id: str,
        resolution: str, concept_id: Optional[str] = None,
    ) -> None:
        if not self._conn:
            return
        sets = ["review_status=?"]
        params: list = [resolution]
        if concept_id:
            sets.append("concept_id=?")
            params.append(concept_id)
        params.extend([account_id, upload_id])
        await self._conn.execute(
            f"UPDATE client_chart_of_accounts SET {', '.join(sets)} WHERE id=? AND upload_id=?",
            params,
        )
        await self._conn.commit()

    async def save_errors(self, upload_id: str, errors: List[Dict]) -> None:
        if not self._conn:
            return
        for e in errors:
            await self._conn.execute(
                """INSERT INTO coa_account_errors
                   (id,upload_id,account_code,account_name,error_code,severity,
                    description_ar,cause_ar,suggestion_ar,auto_fixable,
                    auto_fix_applied,references_list)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    self._uid(), upload_id,
                    e.get("account_code"), e.get("account_name"),
                    e.get("error_code", ""), e.get("severity", "Low"),
                    e.get("description_ar", ""), e.get("cause_ar", ""),
                    e.get("suggestion_ar", ""),
                    1 if e.get("auto_fixable") else 0,
                    1 if e.get("auto_fix_applied") else 0,
                    json.dumps(e.get("references", [])),
                ),
            )
        await self._conn.commit()

    async def get_errors(
        self, upload_id: str, severity: Optional[str] = None, resolved: Optional[bool] = None,
    ) -> List[Dict]:
        if not self._conn:
            return []
        conds = ["upload_id=?"]
        params: list = [upload_id]
        if severity:
            conds.append("severity=?"); params.append(severity)
        if resolved is not None:
            conds.append("resolved=?"); params.append(1 if resolved else 0)
        async with self._conn.execute(
            f"""SELECT * FROM coa_account_errors WHERE {' AND '.join(conds)}
                ORDER BY CASE severity WHEN 'Critical' THEN 1 WHEN 'High' THEN 2
                WHEN 'Medium' THEN 3 ELSE 4 END, account_code""",
            params,
        ) as cursor:
            rows = await cursor.fetchall()
        return [dict(r) for r in rows]

    async def get_review_queue(self, upload_id: str) -> List[Dict]:
        if not self._conn:
            return []
        async with self._conn.execute(
            """SELECT a.id, a.account_code, a.name_raw, a.confidence,
                      a.concept_id, a.section, a.review_status
               FROM client_chart_of_accounts a
               WHERE a.upload_id=?
                 AND (a.confidence < 0.70
                      OR EXISTS (SELECT 1 FROM coa_account_errors ec
                                 WHERE ec.upload_id=? AND ec.account_code=a.account_code
                                   AND ec.severity='Critical' AND ec.resolved=0))
               ORDER BY a.confidence ASC, a.account_code""",
            (upload_id, upload_id),
        ) as cursor:
            rows = await cursor.fetchall()
        result = []
        for r in rows:
            d = dict(r)
            # Get error codes for this account
            async with self._conn.execute(
                "SELECT error_code FROM coa_account_errors WHERE upload_id=? AND account_code=? AND resolved=0",
                (upload_id, d["account_code"]),
            ) as ecur:
                ecodes = [row["error_code"] for row in await ecur.fetchall()]
            d["error_codes"] = ecodes
            result.append(d)
        return result

    async def count_open_criticals(self, upload_id: str) -> int:
        if not self._conn:
            return 0
        async with self._conn.execute(
            "SELECT COUNT(*) as cnt FROM coa_account_errors WHERE upload_id=? AND severity='Critical' AND resolved=0",
            (upload_id,),
        ) as cursor:
            row = await cursor.fetchone()
        return row["cnt"] if row else 0

    async def count_open_review(self, upload_id: str) -> int:
        if not self._conn:
            return 0
        async with self._conn.execute(
            "SELECT COUNT(*) as cnt FROM client_chart_of_accounts WHERE upload_id=? AND review_status='pending'",
            (upload_id,),
        ) as cursor:
            row = await cursor.fetchone()
        return row["cnt"] if row else 0

    async def save_assessment(
        self, upload_id: str, overall_score: float, quality_grade: str,
        quality_dimensions: Dict, errors_summary: Dict, confidence_avg: float,
        sector_detected: Optional[str] = None, sector_similarity: Optional[float] = None,
        recommendations: Optional[List] = None,
    ) -> None:
        if not self._conn:
            return
        uid = self._uid()
        await self._conn.execute(
            """INSERT OR REPLACE INTO client_coa_assessments
               (id,upload_id,overall_score,quality_grade,quality_dimensions_json,
                errors_summary_json,confidence_avg,sector_detected,sector_similarity,
                recommendations_json)
               VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (
                uid, upload_id, overall_score, quality_grade,
                json.dumps(quality_dimensions), json.dumps(errors_summary),
                confidence_avg, sector_detected, sector_similarity,
                json.dumps(recommendations or []),
            ),
        )
        await self._conn.commit()

    async def get_assessment(self, upload_id: str) -> Optional[Dict]:
        if not self._conn:
            return None
        async with self._conn.execute(
            "SELECT * FROM client_coa_assessments WHERE upload_id=?", (upload_id,),
        ) as cursor:
            row = await cursor.fetchone()
        return dict(row) if row else None

    async def approve_coa(self, upload_id: str, approved_by: str, quality_score: float) -> None:
        if not self._conn:
            return
        await self._conn.execute(
            "INSERT INTO coa_approval_records (id,upload_id,action,approved_by,quality_score) VALUES (?,'approved',?,?)",
            (self._uid(), upload_id, approved_by, quality_score),
        )
        await self._conn.execute(
            "UPDATE client_coa_uploads SET upload_status='approved',updated_at=datetime('now') WHERE id=?",
            (upload_id,),
        )
        await self._conn.commit()

    async def record_override(
        self, upload_id: str, approved_by: str, error_code: str, override_reason: str,
    ) -> None:
        if not self._conn:
            return
        await self._conn.execute(
            """INSERT INTO coa_approval_records
               (id,upload_id,action,approved_by,override_reason,override_error_code)
               VALUES (?,?,?,?,?,?)""",
            (self._uid(), upload_id, "override_critical", approved_by, override_reason, error_code),
        )
        await self._conn.execute(
            """UPDATE coa_account_errors SET resolved=1,resolved_at=datetime('now'),resolved_by=?
               WHERE upload_id=? AND error_code=? AND resolved=0""",
            (approved_by, upload_id, error_code),
        )
        await self._conn.commit()

    async def save_auto_fix(
        self, upload_id: str, account_code: str, fix_type: str,
        before_value: Dict, after_value: Dict,
        fix_confidence: float, fix_reason_ar: str,
    ) -> str:
        fix_id = self._uid()
        token, exp = generate_undo_token(fix_id)
        if self._conn:
            await self._conn.execute(
                """INSERT INTO auto_fix_log
                   (id,upload_id,account_code,fix_type,before_value,after_value,
                    fix_confidence,fix_reason_ar,undo_token,undo_token_exp)
                   VALUES (?,?,?,?,?,?,?,?,?,?)""",
                (
                    fix_id, upload_id, account_code, fix_type,
                    json.dumps(before_value), json.dumps(after_value),
                    fix_confidence, fix_reason_ar, token, exp,
                ),
            )
            await self._conn.commit()
        return token

    async def undo_auto_fix(self, undo_token: str, undone_by: str) -> Optional[Dict]:
        if not self._conn:
            return None
        async with self._conn.execute(
            """SELECT * FROM auto_fix_log
               WHERE undo_token=? AND undone_at IS NULL AND undo_token_exp > datetime('now')""",
            (undo_token,),
        ) as cursor:
            row = await cursor.fetchone()
        if not row:
            return None
        await self._conn.execute(
            "UPDATE auto_fix_log SET undone_at=datetime('now'),undone_by=? WHERE id=?",
            (undone_by, row["id"]),
        )
        await self._conn.commit()
        return json.loads(row["before_value"])

    # ── Sector Benchmarks ────────────────────────────────────────

    async def get_sector_benchmark(self, sector_code: str) -> Optional[Dict]:
        if not self._conn:
            return None
        async with self._conn.execute(
            "SELECT * FROM sector_benchmarks WHERE sector_code=?", (sector_code,),
        ) as cursor:
            row = await cursor.fetchone()
        if not row:
            return None
        d = dict(row)
        # Parse common_errors JSON
        ce = d.get("common_errors") or "[]"
        if isinstance(ce, str):
            try:
                d["common_errors"] = json.loads(ce)
            except (json.JSONDecodeError, TypeError):
                d["common_errors"] = []
        return d

    async def get_all_sector_benchmarks(self) -> List[Dict]:
        if not self._conn:
            return []
        async with self._conn.execute(
            "SELECT * FROM sector_benchmarks ORDER BY sector_code",
        ) as cursor:
            rows = await cursor.fetchall()
        result = []
        for row in rows:
            d = dict(row)
            ce = d.get("common_errors") or "[]"
            if isinstance(ce, str):
                try:
                    d["common_errors"] = json.loads(ce)
                except (json.JSONDecodeError, TypeError):
                    d["common_errors"] = []
            result.append(d)
        return result

    # ── COA Versioning ───────────────────────────────────────────

    async def save_coa_version(
        self, client_id: str, upload_id: str,
        quality_score: float, total_accounts: int = 0,
        label: Optional[str] = None, approved_by: Optional[str] = None,
    ) -> int:
        """Save a new COA version for client. Returns the new version_number."""
        if not self._conn:
            return 1
        # Get current max version for this client
        async with self._conn.execute(
            "SELECT MAX(version_number) as max_v FROM coa_versions WHERE client_id=?",
            (client_id,),
        ) as cursor:
            row = await cursor.fetchone()
        max_v = row["max_v"] if row and row["max_v"] else 0
        new_version = max_v + 1

        await self._conn.execute(
            """INSERT INTO coa_versions
               (id, client_id, version_number, upload_id, approved_by,
                quality_score, total_accounts, label)
               VALUES (?,?,?,?,?,?,?,?)""",
            (
                self._uid(), client_id, new_version, upload_id,
                approved_by, quality_score, total_accounts,
                label or f"v{new_version}",
            ),
        )
        await self._conn.commit()
        logger.info(f"COA version {new_version} saved for client {client_id}")
        return new_version

    async def get_coa_versions(self, client_id: str) -> List[Dict]:
        """Get all COA versions for a client, ordered by version_number desc."""
        if not self._conn:
            return []
        async with self._conn.execute(
            "SELECT * FROM coa_versions WHERE client_id=? ORDER BY version_number DESC",
            (client_id,),
        ) as cursor:
            rows = await cursor.fetchall()
        return [dict(r) for r in rows]

    async def get_coa_version(self, client_id: str, version_number: int) -> Optional[Dict]:
        """Get a specific COA version."""
        if not self._conn:
            return None
        async with self._conn.execute(
            "SELECT * FROM coa_versions WHERE client_id=? AND version_number=?",
            (client_id, version_number),
        ) as cursor:
            row = await cursor.fetchone()
        return dict(row) if row else None

    async def get_quality_trend(self, client_id: str) -> List[Dict]:
        """تطور درجة الجودة عبر كل الإصدارات."""
        if not self._conn:
            return []
        async with self._conn.execute(
            """SELECT version_number, quality_score, approved_at, total_accounts
               FROM coa_versions WHERE client_id=? ORDER BY version_number ASC""",
            (client_id,),
        ) as cursor:
            rows = await cursor.fetchall()
        return [
            {
                "version": r["version_number"],
                "score": r["quality_score"],
                "approved_at": r["approved_at"],
                "total_accounts": r["total_accounts"],
            }
            for r in rows
        ]

    # ── Migration Map ────────────────────────────────────────────

    async def save_migration_map(
        self, client_id: str, from_v: int, to_v: int, mappings: List[Dict],
    ) -> int:
        """Save migration map entries. Returns count of entries saved."""
        if not self._conn:
            return 0
        # Delete old map for this version pair (idempotent rebuild)
        await self._conn.execute(
            "DELETE FROM coa_migration_map WHERE client_id=? AND from_version=? AND to_version=?",
            (client_id, from_v, to_v),
        )
        count = 0
        for m in mappings:
            await self._conn.execute(
                """INSERT OR REPLACE INTO coa_migration_map
                   (id, client_id, from_version, to_version, old_code, new_code,
                    canonical_id, map_type, confidence, source_natures_conflict,
                    split_targets, old_name, new_name, old_section, new_section,
                    old_nature, new_nature, auto_matched)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    self._uid(), client_id, from_v, to_v,
                    m.get("old_code", ""),
                    m.get("new_code"),
                    m.get("canonical_id"),
                    m.get("map_type", "SAME"),
                    m.get("confidence", 0.0),
                    1 if m.get("source_natures_conflict") else 0,
                    json.dumps(m.get("split_targets", [])),
                    m.get("old_name"),
                    m.get("new_name"),
                    m.get("old_section"),
                    m.get("new_section"),
                    m.get("old_nature"),
                    m.get("new_nature"),
                    1 if m.get("auto_matched", True) else 0,
                ),
            )
            count += 1
        await self._conn.commit()
        return count

    async def get_migration_map(
        self, client_id: str, from_v: int, to_v: int,
    ) -> List[Dict]:
        """Get migration map between two versions."""
        if not self._conn:
            return []
        async with self._conn.execute(
            """SELECT * FROM coa_migration_map
               WHERE client_id=? AND from_version=? AND to_version=?
               ORDER BY old_code""",
            (client_id, from_v, to_v),
        ) as cursor:
            rows = await cursor.fetchall()
        result = []
        for row in rows:
            d = dict(row)
            st = d.get("split_targets") or "[]"
            if isinstance(st, str):
                try:
                    d["split_targets"] = json.loads(st)
                except (json.JSONDecodeError, TypeError):
                    d["split_targets"] = []
            d["source_natures_conflict"] = bool(d.get("source_natures_conflict"))
            d["auto_matched"] = bool(d.get("auto_matched"))
            result.append(d)
        return result

    # ── Engine Rules (Governance) ────────────────────────────────

    async def save_rule(self, rule: Dict) -> bool:
        if not self._conn:
            return False
        try:
            await self._conn.execute(
                """INSERT INTO engine_rules
                   (rule_id, rule_name, description_ar, rule_type, condition_json,
                    action_json, severity, status, version, proposed_by, proposed_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,datetime('now'))""",
                (rule["rule_id"], rule["rule_name"], rule.get("description_ar",""),
                 rule.get("rule_type","error_check"), json.dumps(rule.get("condition",{})),
                 json.dumps(rule.get("action",{})), rule.get("severity","Medium"),
                 rule.get("status","draft"), rule.get("version",1),
                 rule.get("proposed_by","")),
            )
            await self._conn.commit()
            return True
        except Exception as e:
            logger.error("save_rule error: %s", e)
            return False

    async def update_rule_status(self, rule_id: str, status: str, by: str = "") -> bool:
        if not self._conn:
            return False
        try:
            ts_field = {"active": "approved_at", "deprecated": "deprecated_at"}.get(status)
            by_field = {"active": "approved_by", "deprecated": "deprecated_by"}.get(status)
            parts = ["status = ?"]
            params = [status]
            if ts_field:
                parts.append(f"{ts_field} = datetime('now')")
            if by_field and by:
                parts.append(f"{by_field} = ?")
                params.append(by)
            params.append(rule_id)
            await self._conn.execute(
                f"UPDATE engine_rules SET {', '.join(parts)} WHERE rule_id = ?", params
            )
            await self._conn.commit()
            return True
        except Exception as e:
            logger.error("update_rule_status error: %s", e)
            return False

    async def get_rules(self, status: Optional[str] = None) -> List[Dict]:
        if not self._conn:
            return []
        try:
            if status:
                cursor = await self._conn.execute(
                    "SELECT * FROM engine_rules WHERE status = ? ORDER BY proposed_at DESC", (status,)
                )
            else:
                cursor = await self._conn.execute(
                    "SELECT * FROM engine_rules ORDER BY proposed_at DESC"
                )
            rows = await cursor.fetchall()
            result = []
            for row in rows:
                d = dict(row)
                for jf in ("condition_json", "action_json"):
                    if isinstance(d.get(jf), str):
                        try:
                            d[jf] = json.loads(d[jf])
                        except (json.JSONDecodeError, TypeError):
                            pass
                result.append(d)
            return result
        except Exception as e:
            logger.error("get_rules error: %s", e)
            return []

    async def get_rule(self, rule_id: str) -> Optional[Dict]:
        if not self._conn:
            return None
        try:
            cursor = await self._conn.execute(
                "SELECT * FROM engine_rules WHERE rule_id = ?", (rule_id,)
            )
            row = await cursor.fetchone()
            if not row:
                return None
            d = dict(row)
            for jf in ("condition_json", "action_json"):
                if isinstance(d.get(jf), str):
                    try:
                        d[jf] = json.loads(d[jf])
                    except (json.JSONDecodeError, TypeError):
                        pass
            return d
        except Exception:
            return None

    async def increment_rule_execution(self, rule_id: str, success: bool) -> bool:
        if not self._conn:
            return False
        try:
            await self._conn.execute(
                """UPDATE engine_rules
                   SET execution_count = execution_count + 1,
                       success_rate = CASE
                           WHEN ? THEN (success_rate * execution_count + 1.0) / (execution_count + 1)
                           ELSE (success_rate * execution_count) / (execution_count + 1)
                       END
                   WHERE rule_id = ?""",
                (1 if success else 0, rule_id),
            )
            await self._conn.commit()
            return True
        except Exception as e:
            logger.error("increment_rule_execution error: %s", e)
            return False

    # ── Governance Alerts ────────────────────────────────────────

    async def save_governance_alert(self, alert: Dict) -> bool:
        if not self._conn:
            return False
        try:
            await self._conn.execute(
                """INSERT INTO governance_alerts
                   (alert_id, rule_id, alert_type, message, severity, details_json, created_at)
                   VALUES (?,?,?,?,?,?,datetime('now'))""",
                (alert["alert_id"], alert["rule_id"], alert.get("alert_type","auto_rollback"),
                 alert["message"], alert.get("severity","High"),
                 json.dumps(alert.get("details",{}))),
            )
            await self._conn.commit()
            return True
        except Exception as e:
            logger.error("save_governance_alert error: %s", e)
            return False

    async def get_governance_alerts(self, resolved: Optional[bool] = None) -> List[Dict]:
        if not self._conn:
            return []
        try:
            if resolved is not None:
                cursor = await self._conn.execute(
                    "SELECT * FROM governance_alerts WHERE resolved = ? ORDER BY created_at DESC",
                    (1 if resolved else 0,),
                )
            else:
                cursor = await self._conn.execute(
                    "SELECT * FROM governance_alerts ORDER BY created_at DESC"
                )
            rows = await cursor.fetchall()
            result = []
            for row in rows:
                d = dict(row)
                dj = d.get("details_json") or "{}"
                if isinstance(dj, str):
                    try:
                        d["details_json"] = json.loads(dj)
                    except (json.JSONDecodeError, TypeError):
                        pass
                result.append(d)
            return result
        except Exception as e:
            logger.error("get_governance_alerts error: %s", e)
            return []


# ── Singleton ─────────────────────────────────────────────────
_DB: Optional[Database] = None


def get_db() -> Optional[Database]:
    return _DB


async def init_db(db_path: str = "coa_engine.db") -> Database:
    global _DB
    _DB = Database(db_path)
    await _DB.connect()
    if _DB.is_connected:
        await _DB.initialize_schema()
    return _DB
