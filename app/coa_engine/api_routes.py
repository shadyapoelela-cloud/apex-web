"""
APEX COA Engine v4.3 — API Routes
===================================
9 endpoints integrated as a sub-router of the main APEX FastAPI app.
"""
from __future__ import annotations

import datetime
import json
import logging
from enum import Enum
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel, Field, field_validator

from .config import (
    ALLOWED_EXTENSIONS, MAX_FILE_SIZE,
    QUALITY_MIN_APPROVAL, CONFIDENCE_REVIEW,
)
from .db import get_db, init_db
from .engine import COAEngine, ProcessedAccount, PipelineResult
from .error_checks import COAError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/coa", tags=["COA Engine"])

# ── Engine singleton ──────────────────────────────────────────
_engine: Optional[COAEngine] = None


def get_engine() -> COAEngine:
    global _engine
    if _engine is None:
        _engine = COAEngine()
    return _engine


async def init_coa_engine():
    """Called from main app lifespan to initialize DB and engine."""
    try:
        await init_db("coa_engine.db")
        get_engine()
        logger.info("COA Engine v4.3 initialized successfully")
    except Exception as e:
        logger.warning(f"COA Engine DB init failed (engine still works without DB): {e}")
        get_engine()


# ─────────────────────────────────────────────────────────────
# Pydantic Models
# ─────────────────────────────────────────────────────────────
class ReviewStatusEnum(str, Enum):
    AUTO_APPROVED = "auto_approved"
    PENDING = "pending"
    REJECTED = "rejected"
    RESOLVED = "resolved"


class SeverityEnum(str, Enum):
    CRITICAL = "Critical"
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"


class ErrorItem(BaseModel):
    error_code: str
    severity: str
    category: str
    account_code: Optional[str] = None
    account_name: Optional[str] = None
    description_ar: str = ""
    cause_ar: str = ""
    suggestion_ar: str = ""
    auto_fixable: bool = False
    auto_fix_applied: bool = False
    references: List[str] = Field(default_factory=list)


class AccountResult(BaseModel):
    code: str
    name_raw: str
    name_normalized: str
    parent_code: Optional[str] = None
    level_num: Optional[int] = None
    concept_id: Optional[str] = None
    section: Optional[str] = None
    nature: Optional[str] = None
    account_level: Optional[str] = None
    confidence: float = 0.0
    classification_method: Optional[str] = None
    review_status: str = "pending"
    errors: List[str] = Field(default_factory=list)


class ReviewQueueItem(BaseModel):
    account_code: str
    account_name: str
    confidence: float
    reason: str = ""
    error_codes: List[str] = Field(default_factory=list)
    suggested_fix: Optional[str] = None


class COAAnalysisResponse(BaseModel):
    upload_id: str
    client_id: Optional[str] = None
    processed_at: str = ""
    processing_ms: int = 0
    file_pattern: str = "UNKNOWN"
    erp_system: Optional[str] = None
    encoding_detected: str = "utf-8"
    status: str = "processing"
    quality_score: float = 0.0
    quality_grade: str = "F"
    confidence_avg: float = 0.0
    sector_detected: Optional[str] = None
    quality_dimensions: Dict[str, float] = Field(default_factory=dict)
    errors: List[ErrorItem] = Field(default_factory=list)
    errors_summary: Dict[str, int] = Field(default_factory=dict)
    accounts: List[AccountResult] = Field(default_factory=list)
    total_accounts: int = 0
    auto_approved: int = 0
    pending_review: int = 0
    review_queue: List[ReviewQueueItem] = Field(default_factory=list)
    session_health: Dict[str, float] = Field(default_factory=dict)
    recommendations: List[str] = Field(default_factory=list)


class OverrideRequest(BaseModel):
    error_code: str
    override_reason: str = Field(..., min_length=10)
    overridden_by: str

    @field_validator("override_reason")
    @classmethod
    def reason_long_enough(cls, v: str) -> str:
        if len(v.strip()) < 10:
            raise ValueError("السبب يجب أن يكون 10 أحرف على الأقل")
        return v.strip()


class ReviewResolutionRequest(BaseModel):
    resolution: str
    concept_id: Optional[str] = None
    reviewer_comment: Optional[str] = None


class UndoRequest(BaseModel):
    undo_token: str
    reason: Optional[str] = None


# ─────────────────────────────────────────────────────────────
# Helper: PipelineResult → Response
# ─────────────────────────────────────────────────────────────
def _build_response(result: PipelineResult, upload_id: str, client_id: Optional[str]) -> COAAnalysisResponse:
    errors_out = [
        ErrorItem(
            error_code=e.error_code, severity=e.severity, category=e.category,
            account_code=e.account_code, account_name=e.account_name,
            description_ar=e.description_ar, cause_ar=e.cause_ar,
            suggestion_ar=e.suggestion_ar, auto_fixable=e.auto_fixable,
            auto_fix_applied=e.auto_fix_applied, references=e.references,
        )
        for e in result.errors
    ]
    accounts_out = [
        AccountResult(
            code=a.code, name_raw=a.name_raw, name_normalized=a.name_normalized,
            parent_code=a.parent_code, level_num=a.level_num,
            concept_id=a.concept_id, section=a.section, nature=a.nature,
            account_level=a.account_level, confidence=a.confidence,
            classification_method=a.classification_method,
            review_status=a.review_status, errors=a.errors,
        )
        for a in result.accounts
    ]
    queue_out = [
        ReviewQueueItem(
            account_code=q.get("account_code", ""),
            account_name=q.get("account_name", ""),
            confidence=q.get("confidence", 0),
            reason=q.get("reason", ""),
            error_codes=q.get("error_codes", []),
            suggested_fix=q.get("suggested_fix"),
        )
        for q in result.review_queue
    ]

    return COAAnalysisResponse(
        upload_id=upload_id,
        client_id=client_id,
        processed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        processing_ms=result.processing_ms,
        file_pattern=result.file_pattern,
        erp_system=result.erp_system,
        encoding_detected=result.encoding_detected,
        status=result.status,
        quality_score=result.quality_score,
        quality_grade=result.quality_grade,
        confidence_avg=result.confidence_avg,
        sector_detected=result.sector_detected,
        quality_dimensions=result.quality_dimensions,
        errors=errors_out,
        errors_summary=result.errors_summary,
        accounts=accounts_out,
        total_accounts=len(result.accounts),
        auto_approved=result.auto_approved,
        pending_review=result.pending_review,
        review_queue=queue_out,
        session_health=result.session_health,
        recommendations=result.recommendations,
    )


# ─────────────────────────────────────────────────────────────
# Endpoint 1: Upload COA file
# ─────────────────────────────────────────────────────────────
@router.post(
    "/upload",
    response_model=COAAnalysisResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="رفع ملف شجرة الحسابات وتحليله",
)
async def upload_coa(
    file: UploadFile = File(...),
    erp_system: Optional[str] = Form(None),
    client_id: Optional[str] = Form(None),
    sector: Optional[str] = Form(None),
) -> COAAnalysisResponse:
    ext = "." + (file.filename or "").rsplit(".", 1)[-1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, f"نوع الملف {ext} غير مدعوم. المسموح: {ALLOWED_EXTENSIONS}")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(413, f"الملف {len(contents):,} بايت يتجاوز الحد {MAX_FILE_SIZE:,}")

    import uuid
    upload_id = str(uuid.uuid4())

    db = get_db()
    if db and db.is_connected:
        upload_id = await db.create_upload(
            original_filename=file.filename or "upload",
            file_size_bytes=len(contents),
            erp_system=erp_system,
            client_id=client_id,
        )

    try:
        result = await get_engine().process(
            file_bytes=contents,
            erp_system=erp_system,
            filename=file.filename or "upload.xlsx",
            upload_id=upload_id,
        )
    except ValueError as e:
        if db and db.is_connected:
            await db.update_upload_status(upload_id, "rejected")
        raise HTTPException(422, str(e))

    # Save to DB if connected
    if db and db.is_connected:
        await db.update_upload_status(
            upload_id=upload_id, status=result.status,
            pattern=result.file_pattern, encoding=result.encoding_detected,
            col_mapping={}, total_accounts=len(result.accounts),
            auto_approved=result.auto_approved, pending_review=result.pending_review,
            processing_ms=result.processing_ms, session_health=result.session_health,
        )
        if result.accounts:
            await db.save_accounts(upload_id, [a.to_dict() for a in result.accounts])
        if result.errors:
            await db.save_errors(upload_id, [e.to_dict() for e in result.errors])
        await db.save_assessment(
            upload_id=upload_id, overall_score=result.quality_score,
            quality_grade=result.quality_grade,
            quality_dimensions=result.quality_dimensions,
            errors_summary=result.errors_summary,
            confidence_avg=result.confidence_avg,
            sector_detected=result.sector_detected,
            recommendations=result.recommendations,
        )

    return _build_response(result, upload_id, client_id)


# ─────────────────────────────────────────────────────────────
# Endpoint 24-28: Governance System (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.post(
    "/governance/rules",
    summary="اقتراح قاعدة جديدة",
    tags=["Governance"],
)
async def propose_rule_endpoint(body: Dict[str, Any] = {}) -> Dict[str, Any]:
    from .governance import propose_rule
    rule_name = body.get("rule_name")
    if not rule_name:
        raise HTTPException(400, "اسم القاعدة مطلوب (rule_name)")
    rule = propose_rule(
        rule_name=rule_name,
        description_ar=body.get("description_ar", ""),
        rule_type=body.get("rule_type", "error_check"),
        condition=body.get("condition"),
        action=body.get("action"),
        severity=body.get("severity", "Medium"),
        proposed_by=body.get("proposed_by", "system"),
    )
    db = get_db()
    if db and db.is_connected:
        await db.save_rule(rule)
    return {"success": True, "data": rule}


@router.get(
    "/governance/rules",
    summary="قائمة القواعد",
    tags=["Governance"],
)
async def list_rules_endpoint(status: Optional[str] = None) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rules = await db.get_rules(status=status)
    return {"success": True, "data": rules, "count": len(rules)}


@router.put(
    "/governance/rules/{rule_id}/approve",
    summary="اعتماد قاعدة",
    tags=["Governance"],
)
async def approve_rule_endpoint(rule_id: str, body: Dict[str, Any] = {}) -> Dict[str, Any]:
    from .governance import approve_rule
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rule = await db.get_rule(rule_id)
    if not rule:
        raise HTTPException(404, f"القاعدة {rule_id!r} غير موجودة")
    result = approve_rule(rule, approved_by=body.get("approved_by", "admin"))
    if not result["success"]:
        raise HTTPException(400, result["error"])
    await db.update_rule_status(rule_id, "active", by=body.get("approved_by", "admin"))
    return {"success": True, "data": result}


@router.put(
    "/governance/rules/{rule_id}/deprecate",
    summary="إيقاف قاعدة",
    tags=["Governance"],
)
async def deprecate_rule_endpoint(rule_id: str, body: Dict[str, Any] = {}) -> Dict[str, Any]:
    from .governance import deprecate_rule
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rule = await db.get_rule(rule_id)
    if not rule:
        raise HTTPException(404, f"القاعدة {rule_id!r} غير موجودة")
    result = deprecate_rule(rule, deprecated_by=body.get("deprecated_by", "admin"),
                            reason=body.get("reason", ""))
    if not result["success"]:
        raise HTTPException(400, result["error"])
    await db.update_rule_status(rule_id, "deprecated", by=body.get("deprecated_by", "admin"))
    return {"success": True, "data": result}


@router.get(
    "/governance/stats",
    summary="إحصائيات الحوكمة",
    tags=["Governance"],
)
async def governance_stats_endpoint() -> Dict[str, Any]:
    from .governance import get_governance_stats
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rules = await db.get_rules()
    stats = get_governance_stats(rules)
    return {"success": True, "data": stats}


# ─────────────────────────────────────────────────────────────
# Endpoint 29-30: A/B Testing + Auto-Rollback (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.post(
    "/governance/ab-test",
    summary="اختبار A/B بين قاعدتين",
    tags=["Governance"],
)
async def ab_test_endpoint(body: Dict[str, Any] = {}) -> Dict[str, Any]:
    from .governance import run_ab_test
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rule_id_a = body.get("rule_id_a")
    rule_id_b = body.get("rule_id_b")
    if not rule_id_a or not rule_id_b:
        raise HTTPException(400, "مطلوب rule_id_a و rule_id_b")
    rule_a = await db.get_rule(rule_id_a)
    rule_b = await db.get_rule(rule_id_b)
    if not rule_a:
        raise HTTPException(404, f"القاعدة {rule_id_a!r} غير موجودة")
    if not rule_b:
        raise HTTPException(404, f"القاعدة {rule_id_b!r} غير موجودة")
    test_accounts = body.get("test_accounts", [])
    result = run_ab_test(rule_a, rule_b, test_accounts)
    return {"success": True, "data": result}


@router.post(
    "/governance/auto-rollback",
    summary="فحص التراجع التلقائي",
    tags=["Governance"],
)
async def auto_rollback_endpoint(body: Dict[str, Any] = {}) -> Dict[str, Any]:
    from .governance import check_auto_rollback, notify_governance_alert
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rule_id = body.get("rule_id")
    if not rule_id:
        raise HTTPException(400, "مطلوب rule_id")
    rule = await db.get_rule(rule_id)
    if not rule:
        raise HTTPException(404, f"القاعدة {rule_id!r} غير موجودة")
    result = check_auto_rollback(
        rule,
        min_executions=body.get("min_executions", 10),
        min_success_rate=body.get("min_success_rate", 0.7),
    )
    if result["should_rollback"]:
        alert = notify_governance_alert(
            rule_id=rule_id,
            alert_type="auto_rollback",
            message=result["reason"],
            severity="Critical",
            details=result,
        )
        await db.save_governance_alert(alert)
        await db.update_rule_status(rule_id, "deprecated", by="auto_rollback")
        result["alert"] = alert
    return {"success": True, "data": result}


@router.get(
    "/governance/alerts",
    summary="تنبيهات الحوكمة",
    tags=["Governance"],
)
async def governance_alerts_endpoint(resolved: Optional[bool] = None) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    alerts = await db.get_governance_alerts(resolved=resolved)
    return {"success": True, "data": alerts, "count": len(alerts)}


# ─────────────────────────────────────────────────────────────
# Endpoint 19: Knowledge Graph Context (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.get(
    "/graph/{concept_id}",
    summary="سياق الشبكة المعرفية لحساب",
    tags=["Knowledge Graph"],
)
async def get_graph_context_endpoint(concept_id: str, depth: int = 2) -> Dict[str, Any]:
    from .knowledge_graph import get_graph_context, KNOWLEDGE_GRAPH
    if concept_id not in KNOWLEDGE_GRAPH:
        raise HTTPException(404, f"المفهوم {concept_id!r} غير موجود في الشبكة المعرفية")
    ctx = get_graph_context(concept_id, depth=min(depth, 3))
    return {"success": True, "data": ctx}


# ─────────────────────────────────────────────────────────────
# Endpoint 13: Sector Benchmarks (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.get(
    "/benchmarks/{sector_code}",
    summary="بيانات المقارنة القطاعية",
    tags=["Benchmarks"],
)
async def get_sector_benchmark(sector_code: str) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    benchmark = await db.get_sector_benchmark(sector_code)
    if not benchmark:
        raise HTTPException(404, f"القطاع {sector_code!r} غير موجود في قاعدة المقارنة")
    return {"success": True, "data": benchmark}


@router.get(
    "/benchmarks",
    summary="جميع بيانات المقارنة القطاعية",
    tags=["Benchmarks"],
)
async def list_sector_benchmarks() -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    benchmarks = await db.get_all_sector_benchmarks()
    return {"success": True, "data": benchmarks, "count": len(benchmarks)}


# ─────────────────────────────────────────────────────────────
# Endpoint 14: COA Versioning (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.get(
    "/clients/{client_id}/versions",
    summary="سجل إصدارات شجرة الحسابات",
    tags=["Versioning"],
)
async def get_coa_versions(client_id: str) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    versions = await db.get_coa_versions(client_id)
    return {"success": True, "data": versions, "count": len(versions)}


@router.get(
    "/clients/{client_id}/versions/{v1}/compare/{v2}",
    summary="مقارنة إصدارين من شجرة الحسابات",
    tags=["Versioning"],
)
async def compare_coa_versions_endpoint(
    client_id: str, v1: int, v2: int,
) -> Dict[str, Any]:
    from .advanced_checks import compare_coa_versions

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    ver1 = await db.get_coa_version(client_id, v1)
    ver2 = await db.get_coa_version(client_id, v2)
    if not ver1:
        raise HTTPException(404, f"الإصدار {v1} غير موجود للعميل {client_id!r}")
    if not ver2:
        raise HTTPException(404, f"الإصدار {v2} غير موجود للعميل {client_id!r}")

    # Get accounts for each version
    accounts_v1 = await db.get_accounts(ver1["upload_id"])
    accounts_v2 = await db.get_accounts(ver2["upload_id"])

    report = compare_coa_versions(accounts_v1, accounts_v2)
    report["version_old"] = v1
    report["version_new"] = v2
    report["client_id"] = client_id
    report["score_old"] = ver1.get("quality_score", 0)
    report["score_new"] = ver2.get("quality_score", 0)

    return {"success": True, "data": report}


# ─────────────────────────────────────────────────────────────
# Endpoint 15: Migration Map (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
class MigrationMapRequest(BaseModel):
    from_version: int
    to_version: int


@router.post(
    "/clients/{client_id}/migration-map",
    summary="بناء خريطة هجرة بين نسختين",
    tags=["Migration"],
)
async def build_migration_map_endpoint(
    client_id: str, body: MigrationMapRequest,
) -> Dict[str, Any]:
    from .migration_bridge import build_migration_map

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    ver1 = await db.get_coa_version(client_id, body.from_version)
    ver2 = await db.get_coa_version(client_id, body.to_version)
    if not ver1:
        raise HTTPException(404, f"الإصدار {body.from_version} غير موجود")
    if not ver2:
        raise HTTPException(404, f"الإصدار {body.to_version} غير موجود")

    accounts_old = await db.get_accounts(ver1["upload_id"])
    accounts_new = await db.get_accounts(ver2["upload_id"])

    mappings = build_migration_map(accounts_old, accounts_new)
    saved = await db.save_migration_map(client_id, body.from_version, body.to_version, mappings)

    # Summary stats
    type_counts: Dict[str, int] = {}
    for m in mappings:
        t = m.get("map_type", "UNKNOWN")
        type_counts[t] = type_counts.get(t, 0) + 1

    return {
        "success": True,
        "data": {
            "client_id": client_id,
            "from_version": body.from_version,
            "to_version": body.to_version,
            "total_mappings": saved,
            "type_summary": type_counts,
            "mappings": mappings,
        },
    }


@router.get(
    "/clients/{client_id}/migration-map",
    summary="جلب خريطة الهجرة المحفوظة",
    tags=["Migration"],
)
async def get_migration_map_endpoint(
    client_id: str, from_version: int = 1, to_version: int = 2,
) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    mappings = await db.get_migration_map(client_id, from_version, to_version)
    return {"success": True, "data": mappings, "count": len(mappings)}


# ─────────────────────────────────────────────────────────────
# Endpoint 16: TB Linkage Breaks (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.post(
    "/clients/{client_id}/tb-breaks",
    summary="كشف كسور ربط ميزان المراجعة",
    tags=["Migration"],
)
async def detect_tb_breaks_endpoint(
    client_id: str, body: MigrationMapRequest,
) -> Dict[str, Any]:
    from .migration_bridge import build_migration_map, detect_tb_linkage_breaks

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    # Try to get existing migration map, or build one
    mappings = await db.get_migration_map(client_id, body.from_version, body.to_version)
    if not mappings:
        ver1 = await db.get_coa_version(client_id, body.from_version)
        ver2 = await db.get_coa_version(client_id, body.to_version)
        if not ver1 or not ver2:
            raise HTTPException(404, "الإصدارات غير موجودة")
        accounts_old = await db.get_accounts(ver1["upload_id"])
        accounts_new = await db.get_accounts(ver2["upload_id"])
        mappings = build_migration_map(accounts_old, accounts_new)

    breaks = detect_tb_linkage_breaks(mappings)

    # Summary
    sev_counts: Dict[str, int] = {}
    for b in breaks:
        s = b.get("severity", "Low")
        sev_counts[s] = sev_counts.get(s, 0) + 1

    return {
        "success": True,
        "data": {
            "client_id": client_id,
            "from_version": body.from_version,
            "to_version": body.to_version,
            "total_breaks": len(breaks),
            "severity_summary": sev_counts,
            "requires_journal_entries": sum(1 for b in breaks if b.get("requires_journal_entry")),
            "breaks": breaks,
        },
    }


# ─────────────────────────────────────────────────────────────
# Endpoint 17: Version Impact (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.get(
    "/clients/{client_id}/versions/{v1}/impact/{v2}",
    summary="أثر التغييرات على درجة الجودة",
    tags=["Versioning"],
)
async def get_version_impact_endpoint(
    client_id: str, v1: int, v2: int,
) -> Dict[str, Any]:
    from .advanced_checks import compare_coa_versions, compute_version_impact

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    ver1 = await db.get_coa_version(client_id, v1)
    ver2 = await db.get_coa_version(client_id, v2)
    if not ver1:
        raise HTTPException(404, f"الإصدار {v1} غير موجود")
    if not ver2:
        raise HTTPException(404, f"الإصدار {v2} غير موجود")

    # Get assessments for score context
    assess1 = await db.get_assessment(ver1["upload_id"]) or {}
    assess2 = await db.get_assessment(ver2["upload_id"]) or {}

    old_report = {
        "quality_score": float(assess1.get("overall_score", 0) or ver1.get("quality_score", 0)),
        "quality_grade": assess1.get("quality_grade", "F"),
    }
    new_report = {
        "quality_score": float(assess2.get("overall_score", 0) or ver2.get("quality_score", 0)),
        "quality_grade": assess2.get("quality_grade", "F"),
    }

    accounts_v1 = await db.get_accounts(ver1["upload_id"])
    accounts_v2 = await db.get_accounts(ver2["upload_id"])
    evolution = compare_coa_versions(accounts_v1, accounts_v2)

    impact = compute_version_impact(old_report, new_report, evolution)
    return {"success": True, "data": impact}


# ─────────────────────────────────────────────────────────────
# Endpoint 18: Health Trend (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.get(
    "/clients/{client_id}/health-trend",
    summary="تطور درجة الجودة عبر الإصدارات",
    tags=["Versioning"],
)
async def get_health_trend(client_id: str) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    trend = await db.get_quality_trend(client_id)
    # Compute direction
    direction = "neutral"
    if len(trend) >= 2:
        if trend[-1]["score"] > trend[-2]["score"]:
            direction = "improving"
        elif trend[-1]["score"] < trend[-2]["score"]:
            direction = "declining"
    return {
        "success": True,
        "data": {
            "client_id": client_id,
            "versions_count": len(trend),
            "direction": direction,
            "trend": trend,
        },
    }


# ─────────────────────────────────────────────────────────────
# Endpoint 12: Health check (MUST be before /{upload_id})
# ─────────────────────────────────────────────────────────────
@router.get("/health", summary="حالة محرك COA", tags=["Health"])
async def coa_health() -> Dict[str, Any]:
    db = get_db()
    db_ok = db is not None and db.is_connected
    return {
        "status": "healthy" if db_ok else "degraded",
        "version": "4.3.0",
        "components": {
            "engine": "ready",
            "database": "connected" if db_ok else "not_connected",
            "lexicon": "loaded",
        },
    }


# ─────────────────────────────────────────────────────────────
# Endpoint 2: Get analysis result
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}",
    response_model=COAAnalysisResponse,
    summary="نتيجة تحليل جلسة سابقة",
)
async def get_analysis(upload_id: str) -> COAAnalysisResponse:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    assessment = await db.get_assessment(upload_id) or {}
    accounts = await db.get_accounts(upload_id)
    errors = await db.get_errors(upload_id)

    dims = assessment.get("quality_dimensions_json") or "{}"
    if isinstance(dims, str):
        dims = json.loads(dims)
    err_sum = assessment.get("errors_summary_json") or "{}"
    if isinstance(err_sum, str):
        err_sum = json.loads(err_sum)
    recs = assessment.get("recommendations_json") or "[]"
    if isinstance(recs, str):
        recs = json.loads(recs)
    sh = upload.get("session_health_json") or "{}"
    if isinstance(sh, str):
        sh = json.loads(sh)

    return COAAnalysisResponse(
        upload_id=upload_id,
        client_id=str(upload.get("client_id", "") or ""),
        processing_ms=upload.get("processing_ms", 0) or 0,
        file_pattern=upload.get("pattern_detected", "UNKNOWN") or "UNKNOWN",
        erp_system=upload.get("erp_system"),
        encoding_detected=upload.get("encoding_detected", "utf-8"),
        status=upload.get("upload_status", "processing"),
        quality_score=float(assessment.get("overall_score", 0) or 0),
        quality_grade=assessment.get("quality_grade", "F") or "F",
        confidence_avg=float(assessment.get("confidence_avg", 0) or 0),
        sector_detected=assessment.get("sector_detected"),
        quality_dimensions=dims,
        errors=[ErrorItem(
            error_code=e.get("error_code", ""), severity=e.get("severity", "Low"),
            category=e.get("category", ""), account_code=e.get("account_code"),
            description_ar=e.get("description_ar", ""),
            cause_ar=e.get("cause_ar", ""), suggestion_ar=e.get("suggestion_ar", ""),
            auto_fixable=bool(e.get("auto_fixable")),
        ) for e in errors],
        errors_summary=err_sum,
        accounts=[AccountResult(
            code=a.get("account_code", ""), name_raw=a.get("name_raw", ""),
            name_normalized=a.get("name_normalized", ""),
            parent_code=a.get("parent_code"), level_num=a.get("level_num"),
            concept_id=a.get("concept_id"), section=a.get("section"),
            nature=a.get("nature"), account_level=a.get("account_level"),
            confidence=float(a.get("confidence", 0)),
            classification_method=a.get("classification_method"),
            review_status=a.get("review_status", "pending"),
        ) for a in accounts],
        total_accounts=upload.get("total_accounts", 0) or 0,
        auto_approved=upload.get("auto_approved", 0) or 0,
        pending_review=upload.get("pending_review", 0) or 0,
        session_health=sh,
        recommendations=recs,
    )


# ─────────────────────────────────────────────────────────────
# Endpoint 3: List accounts
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}/accounts",
    response_model=List[AccountResult],
    summary="قائمة الحسابات المحللة",
)
async def list_accounts(
    upload_id: str,
    review_status: Optional[str] = None,
    min_confidence: Optional[float] = None,
    section: Optional[str] = None,
) -> List[AccountResult]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rows = await db.get_accounts(upload_id, review_status, min_confidence, section)
    return [AccountResult(
        code=r.get("account_code", ""), name_raw=r.get("name_raw", ""),
        name_normalized=r.get("name_normalized", ""),
        parent_code=r.get("parent_code"), level_num=r.get("level_num"),
        concept_id=r.get("concept_id"), section=r.get("section"),
        nature=r.get("nature"), account_level=r.get("account_level"),
        confidence=float(r.get("confidence", 0)),
        classification_method=r.get("classification_method"),
        review_status=r.get("review_status", "pending"),
    ) for r in rows]


# ─────────────────────────────────────────────────────────────
# Endpoint 4: Approve COA
# ─────────────────────────────────────────────────────────────
@router.post(
    "/{upload_id}/approve",
    summary="اعتماد شجرة الحسابات نهائياً",
    tags=["Approval"],
)
async def approve_coa(upload_id: str, approved_by: str = Form(...)) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    open_criticals = await db.count_open_criticals(upload_id)
    if open_criticals > 0:
        raise HTTPException(409, f"لا يمكن الاعتماد: يوجد {open_criticals} خطأ Critical مفتوح")

    open_review = await db.count_open_review(upload_id)
    if open_review > 0:
        raise HTTPException(409, f"لا يمكن الاعتماد: يوجد {open_review} حساب في طابور المراجعة")

    assessment = await db.get_assessment(upload_id)
    score = float(assessment.get("overall_score", 0) if assessment else 0)
    if score < QUALITY_MIN_APPROVAL:
        raise HTTPException(409, f"درجة الجودة {score:.1f} أقل من الحد الأدنى {QUALITY_MIN_APPROVAL}")

    await db.approve_coa(upload_id, approved_by, score)

    # Save COA version if client_id is available
    client_id = str(upload.get("client_id") or "")
    version_number = None
    if client_id:
        total_accounts = upload.get("total_accounts", 0) or 0
        version_number = await db.save_coa_version(
            client_id=client_id, upload_id=upload_id,
            quality_score=score, total_accounts=total_accounts,
            approved_by=approved_by,
        )

    return {
        "upload_id": upload_id, "status": "approved",
        "approved_by": approved_by, "quality_score": score,
        "version_number": version_number,
    }


# ─────────────────────────────────────────────────────────────
# Endpoint 5: Override critical error
# ─────────────────────────────────────────────────────────────
@router.post(
    "/{upload_id}/override",
    summary="تجاوز خطأ Critical مع توثيق السبب",
    tags=["Approval"],
)
async def override_critical(upload_id: str, body: OverrideRequest) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    if not await db.get_upload(upload_id):
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    errors = await db.get_errors(upload_id, severity="Critical", resolved=False)
    target = next((e for e in errors if e.get("error_code") == body.error_code), None)
    if not target:
        raise HTTPException(404, f"الخطأ {body.error_code!r} غير موجود أو غير Critical أو محلول مسبقاً")

    await db.record_override(upload_id, body.overridden_by, body.error_code, body.override_reason)
    return {"upload_id": upload_id, "error_code": body.error_code, "override_recorded": True}


# ─────────────────────────────────────────────────────────────
# Endpoint 6: Review queue
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}/review-queue",
    response_model=List[ReviewQueueItem],
    summary="طابور المراجعة البشرية",
    tags=["Review"],
)
async def get_review_queue(upload_id: str) -> List[ReviewQueueItem]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    rows = await db.get_review_queue(upload_id)
    return [ReviewQueueItem(
        account_code=r.get("account_code", ""),
        account_name=r.get("name_raw", ""),
        confidence=float(r.get("confidence", 0)),
        error_codes=list(r.get("error_codes") or []),
    ) for r in rows]


# ─────────────────────────────────────────────────────────────
# Endpoint 7: Resolve review item
# ─────────────────────────────────────────────────────────────
@router.patch(
    "/accounts/{account_id}/review",
    summary="حل حساب من طابور المراجعة",
    tags=["Review"],
)
async def resolve_review_item(
    account_id: str,
    body: ReviewResolutionRequest,
    upload_id: str = Form(...),
) -> Dict[str, Any]:
    if body.resolution == "reclassify" and not body.concept_id:
        raise HTTPException(422, "إعادة التصنيف تتطلب concept_id")
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    await db.update_account_review(upload_id, account_id, body.resolution, body.concept_id)
    return {"account_id": account_id, "resolution": body.resolution, "resolved": True}


# ─────────────────────────────────────────────────────────────
# Endpoint 8: Undo auto-fix
# ─────────────────────────────────────────────────────────────
@router.post(
    "/auto-fix/undo",
    summary="التراجع عن إصلاح تلقائي (صالح 72 ساعة)",
    tags=["AutoFix"],
)
async def undo_auto_fix(body: UndoRequest) -> Dict[str, Any]:
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    before = await db.undo_auto_fix(body.undo_token, undone_by=body.reason or "user")
    if before is None:
        raise HTTPException(410, "الـ token غير موجود أو منتهي أو تم التراجع مسبقاً")
    return {"undone": True, "before_value": before}


# ─────────────────────────────────────────────────────────────
# Endpoint 9: KPIs & SLAs (القسم 8.2 — Table 59)
# ─────────────────────────────────────────────────────────────
@router.get(
    "/kpis",
    summary="مؤشرات الأداء التشغيلية — KPIs & SLAs",
    tags=["KPIs"],
)
async def get_kpis() -> Dict[str, Any]:
    """
    يحسب 8 مؤشرات أداء من قاعدة البيانات:
    1. نسبة الاعتماد الآلي (≥ 75%)
    2. زمن المعالجة p95 (≤ 60 ث)
    3. نسبة confidence < 70% (≤ 15%)
    4. عدد Critical لكل 1000 حساب (≤ 5%)
    5. SLA طابور المراجعة (≤ 48 ساعة)
    6. Session Health — pass_one rate (≥ 85%)
    7. نسبة auto_fix ناجح
    8. إجمالي الجلسات
    """
    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة — KPIs تحتاج DB")

    try:
        conn = db._conn

        # 1. نسبة الاعتماد الآلي
        row = await conn.execute_fetchall(
            "SELECT COUNT(*) as total, "
            "SUM(CASE WHEN review_status='auto_approved' THEN 1 ELSE 0 END) as approved "
            "FROM client_chart_of_accounts"
        ) if hasattr(conn, 'execute_fetchall') else []

        # Fallback: use execute + fetchall
        if not row:
            cursor = await conn.execute(
                "SELECT COUNT(*) as total, "
                "SUM(CASE WHEN review_status='auto_approved' THEN 1 ELSE 0 END) as approved "
                "FROM client_chart_of_accounts"
            )
            row = await cursor.fetchall()

        total_accounts = row[0][0] if row else 0
        auto_approved = row[0][1] if row else 0
        auto_approve_rate = round(auto_approved / max(total_accounts, 1), 3)

        # 2. زمن المعالجة p95
        cursor = await conn.execute(
            "SELECT processing_ms FROM client_coa_uploads "
            "WHERE processing_ms IS NOT NULL ORDER BY processing_ms DESC"
        )
        times = [r[0] for r in await cursor.fetchall()]
        p95_ms = 0
        if times:
            idx = max(0, int(len(times) * 0.05))
            p95_ms = times[idx] if idx < len(times) else times[0]

        # 3. نسبة confidence < 70%
        cursor = await conn.execute(
            "SELECT COUNT(*) FROM client_chart_of_accounts WHERE confidence < 0.70"
        )
        low_conf_count = (await cursor.fetchone())[0]
        low_conf_rate = round(low_conf_count / max(total_accounts, 1), 3)

        # 4. عدد Critical لكل 1000 حساب
        cursor = await conn.execute(
            "SELECT COUNT(*) FROM coa_account_errors WHERE severity='Critical' AND resolved=0"
        )
        critical_count = (await cursor.fetchone())[0]
        critical_per_1000 = round(critical_count / max(total_accounts, 1) * 1000, 1)

        # 5. إجمالي الجلسات
        cursor = await conn.execute("SELECT COUNT(*) FROM client_coa_uploads")
        total_sessions = (await cursor.fetchone())[0]

        # 6. Session Health — average pass_one_rate
        cursor = await conn.execute(
            "SELECT session_health_json FROM client_coa_uploads WHERE session_health_json != '{}'"
        )
        health_rows = await cursor.fetchall()
        pass_one_rates = []
        for hr in health_rows:
            try:
                sh = json.loads(hr[0]) if isinstance(hr[0], str) else hr[0]
                if "pass_one_rate" in sh:
                    pass_one_rates.append(float(sh["pass_one_rate"]))
            except (json.JSONDecodeError, TypeError, KeyError):
                pass
        avg_pass_one = round(sum(pass_one_rates) / max(len(pass_one_rates), 1), 3)

        # 7. نسبة auto_fix ناجح
        cursor = await conn.execute(
            "SELECT COUNT(*) as total, "
            "SUM(CASE WHEN undone_at IS NULL THEN 1 ELSE 0 END) as successful "
            "FROM auto_fix_log"
        )
        fix_row = await cursor.fetchone()
        total_fixes = fix_row[0] if fix_row else 0
        successful_fixes = fix_row[1] if fix_row else 0
        auto_fix_success_rate = round(successful_fixes / max(total_fixes, 1), 3)

        # KPI targets from spec (Table 59)
        TARGETS = {
            "auto_approve_rate": {"target": 0.75, "ideal": 0.80},
            "p95_processing_ms": {"target": 60000, "ideal": 45000},
            "low_confidence_rate": {"target": 0.15, "ideal": 0.12},
            "critical_per_1000": {"target": 50, "ideal": 30},
            "pass_one_rate": {"target": 0.85, "ideal": 0.90},
            "auto_fix_success": {"target": 0.80, "ideal": 0.90},
        }

        kpis = {
            "auto_approve_rate": auto_approve_rate,
            "p95_processing_ms": p95_ms,
            "low_confidence_rate": low_conf_rate,
            "critical_per_1000": critical_per_1000,
            "total_sessions": total_sessions,
            "total_accounts": total_accounts,
            "avg_pass_one_rate": avg_pass_one,
            "auto_fix_success_rate": auto_fix_success_rate,
            "targets": TARGETS,
        }

        # تقييم: هل نستوفي الحد الأدنى؟
        met_targets = 0
        total_targets = 6
        if auto_approve_rate >= 0.75: met_targets += 1
        if p95_ms <= 60000: met_targets += 1
        if low_conf_rate <= 0.15: met_targets += 1
        if critical_per_1000 <= 50: met_targets += 1
        if avg_pass_one >= 0.85: met_targets += 1
        if auto_fix_success_rate >= 0.80: met_targets += 1

        kpis["targets_met"] = f"{met_targets}/{total_targets}"
        kpis["go_no_go"] = "GO" if met_targets == total_targets else "NO_GO"

        return {"success": True, "kpis": kpis}

    except Exception as e:
        logger.error(f"KPIs calculation error: {e}")
        raise HTTPException(500, f"خطأ في حساب المؤشرات: {str(e)}")


# ─────────────────────────────────────────────────────────────
# Endpoint 11: Report Card — ملحق ف
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}/report-card",
    summary="تقرير بطاقة الجودة للعميل",
)
async def get_report_card(upload_id: str) -> Dict[str, Any]:
    from .report_card import generate_report_card

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")

    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    assessment = await db.get_assessment(upload_id) or {}
    errors = await db.get_errors(upload_id)

    dims = assessment.get("quality_dimensions_json") or "{}"
    if isinstance(dims, str):
        dims = json.loads(dims)
    err_sum = assessment.get("errors_summary_json") or "{}"
    if isinstance(err_sum, str):
        err_sum = json.loads(err_sum)
    recs = assessment.get("recommendations_json") or "[]"
    if isinstance(recs, str):
        recs = json.loads(recs)

    result = {
        "quality_score": float(assessment.get("overall_score", 0) or 0),
        "quality_grade": assessment.get("quality_grade", "F"),
        "quality_dimensions": dims,
        "errors_summary": err_sum,
        "errors": [
            {"description_ar": e.get("description_ar", ""), "severity": e.get("severity", "Low")}
            for e in errors
        ],
        "recommendations": recs,
        "total_accounts": upload.get("total_accounts", 0),
        "confidence_avg": float(assessment.get("confidence_avg", 0) or 0),
        "sector_detected": assessment.get("sector_detected"),
    }

    # Sector benchmark (if available)
    sector_benchmark = None
    sector = assessment.get("sector_detected")
    if sector:
        sector_benchmark = await db.get_sector_benchmark(sector)

    card = generate_report_card(result, sector_benchmark)
    return {"success": True, "data": card}


# ─────────────────────────────────────────────────────────────
# Endpoint 20: Financial Simulation — ملحق ن
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}/financial-simulation",
    summary="محاكاة القوائم المالية وكشف الثغرات الهيكلية",
    tags=["Simulation"],
)
async def get_financial_simulation(upload_id: str) -> Dict[str, Any]:
    from .financial_simulation import simulate_financial_statements

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    accounts = await db.get_accounts(upload_id)
    acc_dicts = [dict(a) for a in accounts]
    simulation = simulate_financial_statements(acc_dicts)
    return {"success": True, "data": simulation}


# ─────────────────────────────────────────────────────────────
# Endpoint 21: Compliance Check — ملحق ل2
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}/compliance-check",
    summary="فحص الامتثال التنظيمي",
    tags=["Compliance"],
)
async def get_compliance_check(upload_id: str) -> Dict[str, Any]:
    from .financial_simulation import run_compliance_check

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    assessment = await db.get_assessment(upload_id)
    sector = assessment.get("sector_detected") if assessment else None

    accounts = await db.get_accounts(upload_id)
    acc_dicts = [dict(a) for a in accounts]
    compliance = run_compliance_check(acc_dicts, sector)
    return {"success": True, "data": compliance}


# ─────────────────────────────────────────────────────────────
# Endpoint 22: Implementation Roadmap — ملحق ن2
# ─────────────────────────────────────────────────────────────
@router.get(
    "/{upload_id}/roadmap",
    summary="خارطة طريق الإصلاحات مرتبة بالأولوية",
    tags=["Roadmap"],
)
async def get_roadmap(upload_id: str) -> Dict[str, Any]:
    from .financial_simulation import (
        simulate_financial_statements, run_compliance_check,
        generate_implementation_roadmap,
    )

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    assessment = await db.get_assessment(upload_id)
    sector = assessment.get("sector_detected") if assessment else None

    accounts = await db.get_accounts(upload_id)
    acc_dicts = [dict(a) for a in accounts]
    errors = await db.get_errors(upload_id)

    simulation = simulate_financial_statements(acc_dicts)
    compliance = run_compliance_check(acc_dicts, sector)
    roadmap = generate_implementation_roadmap(errors, simulation, compliance)

    return {"success": True, "data": roadmap, "count": len(roadmap)}


# ─────────────────────────────────────────────────────────────
# Endpoint 23: Trial Balance Check — ملحق ك-2
# ─────────────────────────────────────────────────────────────
@router.post(
    "/{upload_id}/trial-balance-check",
    summary="فحص توازن ميزان المراجعة + كشف سحوبات الشركاء",
    tags=["Trial Balance"],
)
async def trial_balance_check(upload_id: str, body: Dict[str, Any] = {}) -> Dict[str, Any]:
    from .advanced_checks import check_trial_balance, detect_fp08_partner_drawings

    db = get_db()
    if not db or not db.is_connected:
        raise HTTPException(503, "قاعدة البيانات غير متصلة")
    upload = await db.get_upload(upload_id)
    if not upload:
        raise HTTPException(404, f"الجلسة {upload_id!r} غير موجودة")

    trial_balance = body.get("trial_balance", {})
    if not trial_balance:
        raise HTTPException(400, "ميزان المراجعة مطلوب في الطلب (trial_balance)")

    # Check balance
    balance_result = check_trial_balance(trial_balance)

    # Get accounts for FP08 detection
    accounts = await db.get_accounts(upload_id)
    acc_dicts = [dict(a) for a in accounts]

    fp08_alert = detect_fp08_partner_drawings(acc_dicts, trial_balance)

    return {
        "success": True,
        "data": {
            "balance_check": balance_result,
            "fp08_alert": {
                "pattern_id": fp08_alert.pattern_id,
                "risk": fp08_alert.risk,
                "account_code": fp08_alert.account_code,
                "message": fp08_alert.message,
            } if fp08_alert else None,
        },
    }


