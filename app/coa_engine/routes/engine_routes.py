"""
APEX COA Engine v4.2 -- API Routes
Endpoints for COA processing, analysis, and management.
"""

import os
import logging
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Query, Header
from typing import Optional

from app.core.auth_utils import extract_user_id
from app.coa_engine.services.pipeline import process_file, PipelineError
from app.coa_engine.services.pattern_detector import PATTERNS
from app.coa_engine.data.canonical_accounts import CANONICAL_ACCOUNTS
from app.coa_engine.data.sectors import SECTORS

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/coa-engine", tags=["COA Engine v4.2"])

SUPPORTED_EXTENSIONS = {".xlsx", ".xls", ".csv"}
SUPPORTED_CONTENT_TYPES = {
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-excel",
    "text/csv",
    "application/csv",
    "application/octet-stream",
}

# Pattern descriptions for the /patterns endpoint
_PATTERN_DESCRIPTIONS = {
    "OPERATIONAL_INTEGRATED": "Mixed operational data (14+ columns) -- rejected with EC5",
    "ZOHO_BOOKS": "Zoho Books export with 19-digit Account ID and parent-by-name",
    "MIGRATION_FILE": "Migration file with old and new code columns",
    "ACCOUNTS_WITH_JOURNALS": "Chart of Accounts mixed with journal entries",
    "HORIZONTAL_HIERARCHY": "Each hierarchy level in a separate column with NaN-heavy layout",
    "SPARSE_COLUMNAR_HIERARCHY": "Levels in columns with NaN > 50%",
    "HIERARCHICAL_TEXT_PARENT": "Parent reference as text (e.g. '1101 - Cash')",
    "HIERARCHICAL_NUMERIC_PARENT": "Numeric parent_code column for hierarchy",
    "ODOO_WITH_ID": "Odoo export with __export__.account_account_XXX identifiers",
    "ENGLISH_WITH_CLASS": "English COA with Account Number and Class field",
    "ODOO_FLAT": "Flat Odoo export with code/name/type columns",
    "GENERIC_FLAT": "Simple flat file with code and name only",
}


# ── Auth dependency ──


def _require_auth(authorization: Optional[str] = Header(None)) -> str:
    """Extract and validate JWT user_id from Authorization header."""
    user_id = extract_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    return user_id


# ══════════════════════════════════════════════════════════════
# POST /api/coa-engine/upload — Upload and process a COA file
# ══════════════════════════════════════════════════════════════


@router.post("/upload")
async def upload_coa(
    file: UploadFile = File(...),
    client_id: Optional[int] = Query(None, description="Client ID for tracking"),
    user_id: str = Depends(_require_auth),
):
    """Upload a COA file and run the full 8-step processing pipeline.

    Accepts XLSX, XLS, or CSV files up to 10 MB.
    Returns the complete PipelineResult including quality assessment,
    classification results, and review status.
    """
    # Validate file extension
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        return {
            "success": False,
            "error": f"Unsupported file type '{ext}'. Allowed: {', '.join(sorted(SUPPORTED_EXTENSIONS))}",
        }

    try:
        file_bytes = await file.read()
    except Exception as e:
        logger.error("Failed to read uploaded file: %s", e)
        raise HTTPException(status_code=400, detail="Failed to read uploaded file")

    if len(file_bytes) == 0:
        return {"success": False, "error": "Uploaded file is empty"}

    try:
        result = process_file(file_bytes, file.filename or "upload" + ext, client_id)
        logger.info(
            "COA upload processed — user=%s client=%s status=%s quality=%.2f",
            user_id,
            client_id,
            result.status,
            result.quality_score,
        )
        return {"success": True, "data": result.to_dict()}

    except PipelineError as e:
        logger.warning("Pipeline validation error: step=%d msg=%s", e.step, e.message)
        return {"success": False, "error": e.message}
    except Exception as e:
        logger.error("COA upload processing failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Internal processing error")


# ══════════════════════════════════════════════════════════════
# POST /api/coa-engine/analyze — Analyze without saving (preview)
# ══════════════════════════════════════════════════════════════


@router.post("/analyze")
async def analyze_coa(
    file: UploadFile = File(...),
    client_id: Optional[int] = Query(None, description="Client ID for context"),
    user_id: str = Depends(_require_auth),
):
    """Analyze a COA file without persisting results (preview mode).

    Same processing pipeline as /upload but results are not saved
    to the database. Useful for previewing quality before committing.
    """
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        return {
            "success": False,
            "error": f"Unsupported file type '{ext}'. Allowed: {', '.join(sorted(SUPPORTED_EXTENSIONS))}",
        }

    try:
        file_bytes = await file.read()
    except Exception as e:
        logger.error("Failed to read uploaded file: %s", e)
        raise HTTPException(status_code=400, detail="Failed to read uploaded file")

    if len(file_bytes) == 0:
        return {"success": False, "error": "Uploaded file is empty"}

    try:
        result = process_file(file_bytes, file.filename or "analyze" + ext, client_id)
        logger.info(
            "COA analyze (preview) — user=%s client=%s status=%s quality=%.2f",
            user_id,
            client_id,
            result.status,
            result.quality_score,
        )
        return {"success": True, "data": result.to_dict()}

    except PipelineError as e:
        logger.warning("Pipeline validation error (analyze): step=%d msg=%s", e.step, e.message)
        return {"success": False, "error": e.message}
    except Exception as e:
        logger.error("COA analyze processing failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Internal processing error")


# ══════════════════════════════════════════════════════════════
# GET /api/coa-engine/patterns — List supported file patterns
# ══════════════════════════════════════════════════════════════


@router.get("/patterns")
async def list_patterns():
    """Return the 12 supported COA file patterns with descriptions."""
    patterns = []
    for pattern_name in PATTERNS:
        patterns.append({
            "name": pattern_name,
            "description": _PATTERN_DESCRIPTIONS.get(pattern_name, ""),
        })

    return {
        "success": True,
        "data": {
            "count": len(patterns),
            "patterns": patterns,
        },
    }


# ══════════════════════════════════════════════════════════════
# GET /api/coa-engine/canonical-accounts — List canonical accounts
# ══════════════════════════════════════════════════════════════


@router.get("/canonical-accounts")
async def list_canonical_accounts(
    section: Optional[str] = Query(None, description="Filter by section (e.g. current_asset, liability, equity, revenue, expense)"),
):
    """Return canonical accounts from the registry (278+ accounts).

    Optionally filter by section to narrow results.
    """
    accounts = []
    for concept_id, code_pattern, name_ar, name_en, acct_section, nature, level in CANONICAL_ACCOUNTS:
        if section and acct_section != section:
            continue
        accounts.append({
            "concept_id": concept_id,
            "code_pattern": code_pattern,
            "name_ar": name_ar,
            "name_en": name_en,
            "section": acct_section,
            "nature": nature,
            "level": level,
        })

    return {
        "success": True,
        "data": {
            "count": len(accounts),
            "section_filter": section,
            "accounts": accounts,
        },
    }


# ══════════════════════════════════════════════════════════════
# GET /api/coa-engine/sectors — List supported sectors
# ══════════════════════════════════════════════════════════════


@router.get("/sectors")
async def list_sectors():
    """Return the 45+ Saudi sectors with regulatory bodies and mandatory accounts."""
    sectors = []
    for sector in SECTORS:
        sectors.append({
            "code": sector["code"],
            "name_ar": sector["name_ar"],
            "name_en": sector["name_en"],
            "regulatory_body": sector.get("regulatory_body", ""),
            "mandatory_accounts": sector.get("mandatory_accounts", []),
        })

    return {
        "success": True,
        "data": {
            "count": len(sectors),
            "sectors": sectors,
        },
    }


# ══════════════════════════════════════════════════════════════
# GET /api/coa-engine/health — Engine health check
# ══════════════════════════════════════════════════════════════


@router.get("/health")
async def engine_health():
    """Return COA Engine health status, version, and component counts."""
    from app.coa_engine import __version__

    return {
        "success": True,
        "data": {
            "engine": "APEX COA Engine",
            "version": __version__,
            "status": "operational",
            "components": {
                "pattern_detector": {"status": "ok", "patterns_supported": len(PATTERNS)},
                "column_mapper": {"status": "ok"},
                "normalizer": {"status": "ok"},
                "hierarchy_builder": {"status": "ok"},
                "classifier": {"status": "ok"},
                "pipeline": {"status": "ok"},
            },
            "data": {
                "canonical_accounts": len(CANONICAL_ACCOUNTS),
                "sectors": len(SECTORS),
                "patterns": len(PATTERNS),
            },
        },
    }
