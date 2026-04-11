"""
APEX Sprint 6 — Official Source Registry + Eligibility Engines Routes
15 APIs: Reference management, Regulatory monitoring, Funding/Support/License eligibility.
"""

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field
from typing import Optional
import uuid
from app.core.db_utils import get_db_session as _db, exec_sql as _exec, utc_now_iso as _now


class CreateAuthorityRequest(BaseModel):
    name_ar: str = Field("", description="Arabic name of the authority")
    name_en: Optional[str] = Field(None, description="English name of the authority")
    authority_type: str = Field("regulatory", description="Type of authority")
    jurisdiction: str = Field("SA", description="Jurisdiction code")
    domain_pack: str = Field("accounting", description="Domain pack")
    website_url: Optional[str] = Field(None, description="Website URL")
    authority_level: str = Field("regulatory", description="Authority level")
    review_cycle_days: int = Field(90, description="Review cycle in days")


class CreateDocumentRequest(BaseModel):
    authority_id: Optional[str] = Field(None, description="Reference authority ID")
    title_ar: str = Field("", description="Arabic title")
    title_en: Optional[str] = Field(None, description="English title")
    document_type: str = Field("guide", description="Document type")
    version: Optional[str] = Field(None, description="Document version")
    source_url: Optional[str] = Field(None, description="Source URL")


class ReviewUpdateRequest(BaseModel):
    decision: str = Field("reviewed", description="Review decision (approve/dismiss)")
    reviewer_id: Optional[str] = Field(None, description="Reviewer user ID")
    impact_assessment: Optional[str] = Field(None, description="Impact assessment text")


class FundingAssessmentRequest(BaseModel):
    program_id: Optional[str] = Field(None, description="Specific funding program ID to assess")


class SupportAssessmentRequest(BaseModel):
    program_id: Optional[str] = Field(None, description="Specific support program ID to assess")


class LicensingAssessmentRequest(BaseModel):
    license_id: Optional[str] = Field(None, description="Specific license ID to assess")


router = APIRouter()


# ══════════════════════════════════════════════════════════════
# REFERENCE AUTHORITIES
# ══════════════════════════════════════════════════════════════


@router.get("/references/authorities", tags=["Official Sources"])
def list_authorities(
    domain: Optional[str] = None, jurisdiction: Optional[str] = None, limit: int = 50, offset: int = 0
):
    """List official reference authorities."""
    db = _db()
    try:
        where = "WHERE is_active = true"
        params = {"lim": min(limit, 100), "off": offset}
        if domain:
            where += " AND domain_pack = :dom"
            params["dom"] = domain
        if jurisdiction:
            where += " AND jurisdiction = :jur"
            params["jur"] = jurisdiction
        rows = _exec(
            db,
            f"""SELECT id, name_ar, name_en, authority_type, jurisdiction,
                       domain_pack, website_url, authority_level, review_cycle_days,
                       last_checked_at, created_at
                FROM reference_authorities {where} ORDER BY name_ar
                LIMIT :lim OFFSET :off""",
            params,
        ).fetchall()
        return {
            "success": True,
            "data": {
                "authorities": [
                    {
                        "id": r[0],
                        "name_ar": r[1],
                        "name_en": r[2],
                        "authority_type": r[3],
                        "jurisdiction": r[4],
                        "domain_pack": r[5],
                        "website_url": r[6],
                        "authority_level": r[7],
                        "review_cycle_days": r[8],
                        "last_checked_at": r[9],
                        "created_at": r[10],
                    }
                    for r in rows
                ],
                "total": len(rows),
            },
        }
    finally:
        db.close()


@router.post("/references/authorities", tags=["Official Sources"])
def create_authority(body: CreateAuthorityRequest):
    """Register a new reference authority."""
    db = _db()
    try:
        aid = str(uuid.uuid4())
        _exec(
            db,
            """INSERT INTO reference_authorities
               (id, name_ar, name_en, authority_type, jurisdiction,
                domain_pack, website_url, authority_level,
                review_cycle_days, created_at, updated_at)
               VALUES (:id, :nar, :nen, :atype, :jur, :dom, :url,
                       :alevel, :cycle, :now, :now)""",
            {
                "id": aid,
                "nar": body.name_ar,
                "nen": body.name_en,
                "atype": body.authority_type,
                "jur": body.jurisdiction,
                "dom": body.domain_pack,
                "url": body.website_url,
                "alevel": body.authority_level,
                "cycle": body.review_cycle_days,
                "now": _now(),
            },
        )
        db.commit()
        return {"success": True, "data": {"id": aid}}
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# REFERENCE DOCUMENTS
# ══════════════════════════════════════════════════════════════


@router.get("/references/documents", tags=["Official Sources"])
def list_documents(
    authority_id: Optional[str] = None,
    status: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List approved reference documents."""
    db = _db()
    try:
        where = "WHERE 1=1"
        params = {}
        if authority_id:
            where += " AND rd.authority_id = :aid"
            params["aid"] = authority_id
        if status:
            where += " AND rd.validity_status = :st"
            params["st"] = status

        total = _exec(db, f"SELECT count(*) FROM reference_documents rd {where}", params).scalar() or 0

        params["lim"] = page_size
        params["off"] = (page - 1) * page_size
        rows = _exec(
            db,
            f"""SELECT rd.id, rd.title_ar, rd.title_en, rd.document_type,
                       rd.version, rd.validity_status, rd.effective_from,
                       rd.source_url, rd.review_status, rd.last_verified_at,
                       ra.name_ar as authority_name
                FROM reference_documents rd
                LEFT JOIN reference_authorities ra ON ra.id = rd.authority_id
                {where} ORDER BY rd.created_at DESC LIMIT :lim OFFSET :off""",
            params,
        ).fetchall()

        return {
            "success": True,
            "data": {
                "documents": [
                    {
                        "id": r[0],
                        "title_ar": r[1],
                        "title_en": r[2],
                        "document_type": r[3],
                        "version": r[4],
                        "validity_status": r[5],
                        "effective_from": r[6],
                        "source_url": r[7],
                        "review_status": r[8],
                        "last_verified_at": r[9],
                        "authority_name": r[10],
                    }
                    for r in rows
                ],
                "total": total,
                "page": page,
                "page_size": page_size,
            },
        }
    finally:
        db.close()


@router.post("/references/documents", tags=["Official Sources"])
def create_document(body: CreateDocumentRequest):
    """Add a new reference document."""
    db = _db()
    try:
        did = str(uuid.uuid4())
        _exec(
            db,
            """INSERT INTO reference_documents
               (id, authority_id, title_ar, title_en, document_type,
                version, validity_status, source_url,
                review_status, created_at, updated_at)
               VALUES (:id, :aid, :tar, :ten, :dtype, :ver, :vs,
                       :url, :rs, :now, :now)""",
            {
                "id": did,
                "aid": body.authority_id,
                "tar": body.title_ar,
                "ten": body.title_en,
                "dtype": body.document_type,
                "ver": body.version,
                "vs": "active",
                "url": body.source_url,
                "rs": "approved",
                "now": _now(),
            },
        )
        db.commit()
        return {"success": True, "data": {"id": did}}
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# REGULATORY UPDATES
# ══════════════════════════════════════════════════════════════


@router.get("/references/updates", tags=["Official Sources"])
def list_regulatory_updates(
    status: Optional[str] = None, page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100)
):
    """List detected regulatory updates pending review."""
    db = _db()
    try:
        where = "WHERE 1=1"
        params = {}
        if status:
            where += " AND ru.review_status = :st"
            params["st"] = status

        total = _exec(db, f"SELECT count(*) FROM regulatory_update_events ru {where}", params).scalar() or 0
        params["lim"] = page_size
        params["off"] = (page - 1) * page_size

        rows = _exec(
            db,
            f"""SELECT ru.id, ru.change_type, ru.change_summary_ar,
                       ru.review_status, ru.detected_at, ru.reviewed_at,
                       ra.name_ar as authority_name
                FROM regulatory_update_events ru
                LEFT JOIN reference_authorities ra ON ra.id = ru.authority_id
                {where} ORDER BY ru.detected_at DESC LIMIT :lim OFFSET :off""",
            params,
        ).fetchall()

        return {
            "success": True,
            "data": {
                "updates": [
                    {
                        "id": r[0],
                        "change_type": r[1],
                        "summary_ar": r[2],
                        "review_status": r[3],
                        "detected_at": r[4],
                        "reviewed_at": r[5],
                        "authority_name": r[6],
                    }
                    for r in rows
                ],
                "total": total,
                "page": page,
            },
        }
    finally:
        db.close()


@router.post("/references/updates/{update_id}/review", tags=["Official Sources"])
def review_update(update_id: str, body: ReviewUpdateRequest):
    """Review a regulatory update (approve/dismiss)."""
    db = _db()
    try:
        decision = body.decision
        _exec(
            db,
            """UPDATE regulatory_update_events
               SET review_status = :st, reviewed_by = :by,
                   reviewed_at = :now, impact_assessment = :impact
               WHERE id = :id""",
            {"st": decision, "by": body.reviewer_id, "now": _now(), "impact": body.impact_assessment, "id": update_id},
        )
        db.commit()
        return {"success": True, "data": {"id": update_id, "status": decision}}
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# PROGRAM MANAGEMENT (Funding + Support + Licensing)
# ══════════════════════════════════════════════════════════════


@router.get("/programs/funding", tags=["Eligibility"])
def list_funding_programs(active_only: bool = True, limit: int = 50, offset: int = 0):
    """List available funding programs."""
    db = _db()
    try:
        where = "WHERE is_active = true" if active_only else ""
        safe_limit = min(limit, 100)
        rows = _exec(
            db,
            f"""SELECT id, name_ar, name_en, provider_name_ar,
                       program_type, jurisdiction, validity_status,
                       source_url, created_at
                FROM funding_programs {where} ORDER BY name_ar
                LIMIT :lim OFFSET :off""",
            {"lim": safe_limit, "off": offset},
        ).fetchall()
        return {
            "success": True,
            "data": {
                "programs": [
                    {
                        "id": r[0],
                        "name_ar": r[1],
                        "name_en": r[2],
                        "provider_name": r[3],
                        "program_type": r[4],
                        "jurisdiction": r[5],
                        "validity_status": r[6],
                        "source_url": r[7],
                        "created_at": r[8],
                    }
                    for r in rows
                ],
                "total": len(rows),
            },
        }
    finally:
        db.close()


@router.get("/programs/support", tags=["Eligibility"])
def list_support_programs(active_only: bool = True, limit: int = 50, offset: int = 0):
    """List available support programs."""
    db = _db()
    try:
        where = "WHERE is_active = true" if active_only else ""
        safe_limit = min(limit, 100)
        rows = _exec(
            db,
            f"""SELECT id, name_ar, name_en, provider_name_ar,
                       support_type, jurisdiction, validity_status,
                       source_url, created_at
                FROM support_programs {where} ORDER BY name_ar
                LIMIT :lim OFFSET :off""",
            {"lim": safe_limit, "off": offset},
        ).fetchall()
        return {
            "success": True,
            "data": {
                "programs": [
                    {
                        "id": r[0],
                        "name_ar": r[1],
                        "name_en": r[2],
                        "provider_name": r[3],
                        "support_type": r[4],
                        "jurisdiction": r[5],
                        "validity_status": r[6],
                        "source_url": r[7],
                        "created_at": r[8],
                    }
                    for r in rows
                ],
                "total": len(rows),
            },
        }
    finally:
        db.close()


@router.get("/programs/licenses", tags=["Eligibility"])
def list_licenses(active_only: bool = True, limit: int = 50, offset: int = 0):
    """List available license types."""
    db = _db()
    try:
        where = "WHERE is_active = true" if active_only else ""
        safe_limit = min(limit, 100)
        rows = _exec(
            db,
            f"""SELECT id, name_ar, name_en, license_type,
                       issuing_authority_ar, jurisdiction,
                       validity_status, source_url, created_at
                FROM license_registry {where} ORDER BY name_ar
                LIMIT :lim OFFSET :off""",
            {"lim": safe_limit, "off": offset},
        ).fetchall()
        return {
            "success": True,
            "data": {
                "licenses": [
                    {
                        "id": r[0],
                        "name_ar": r[1],
                        "name_en": r[2],
                        "license_type": r[3],
                        "issuing_authority": r[4],
                        "jurisdiction": r[5],
                        "validity_status": r[6],
                        "source_url": r[7],
                        "created_at": r[8],
                    }
                    for r in rows
                ],
                "total": len(rows),
            },
        }
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# ELIGIBILITY ASSESSMENTS
# ══════════════════════════════════════════════════════════════


@router.post("/eligibility/funding/{client_id}", tags=["Eligibility"])
def assess_funding(client_id: str, body: FundingAssessmentRequest = FundingAssessmentRequest()):
    """Assess client eligibility for funding programs."""
    db = _db()
    try:
        from app.sprint6_registry.services.eligibility_engine import assess_funding_eligibility

        result = assess_funding_eligibility(db, client_id, body.program_id)
        return {"success": True, "data": {"assessments": result, "total": len(result)}}
    finally:
        db.close()


@router.post("/eligibility/support/{client_id}", tags=["Eligibility"])
def assess_support(client_id: str, body: SupportAssessmentRequest = SupportAssessmentRequest()):
    """Assess client eligibility for support programs."""
    db = _db()
    try:
        from app.sprint6_registry.services.eligibility_engine import assess_support_eligibility

        result = assess_support_eligibility(db, client_id, body.program_id)
        return {"success": True, "data": {"assessments": result, "total": len(result)}}
    finally:
        db.close()


@router.post("/eligibility/licensing/{client_id}", tags=["Eligibility"])
def assess_licensing(client_id: str, body: LicensingAssessmentRequest = LicensingAssessmentRequest()):
    """Assess client eligibility for licenses."""
    db = _db()
    try:
        from app.sprint6_registry.services.eligibility_engine import assess_license_eligibility

        result = assess_license_eligibility(db, client_id, body.license_id)
        return {"success": True, "data": {"assessments": result, "total": len(result)}}
    finally:
        db.close()


@router.get("/eligibility/client/{client_id}/history", tags=["Eligibility"])
def get_assessment_history(
    client_id: str,
    assessment_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """Get eligibility assessment history for a client."""
    db = _db()
    try:
        where = "WHERE client_id = :cid"
        params = {"cid": client_id}
        if assessment_type:
            where += " AND assessment_type = :atype"
            params["atype"] = assessment_type

        total = _exec(db, f"SELECT count(*) FROM eligibility_assessments {where}", params).scalar() or 0
        params["lim"] = page_size
        params["off"] = (page - 1) * page_size

        rows = _exec(
            db,
            f"""SELECT id, assessment_type, target_program_name,
                       eligibility_status, readiness_score, confidence,
                       boundary_status, requires_human_review, created_at
                FROM eligibility_assessments {where}
                ORDER BY created_at DESC LIMIT :lim OFFSET :off""",
            params,
        ).fetchall()

        return {
            "success": True,
            "data": {
                "assessments": [
                    {
                        "id": r[0],
                        "type": r[1],
                        "program_name": r[2],
                        "status": r[3],
                        "readiness_score": r[4],
                        "confidence": r[5],
                        "boundary": r[6],
                        "requires_review": bool(r[7]),
                        "created_at": r[8],
                    }
                    for r in rows
                ],
                "total": total,
                "page": page,
            },
        }
    finally:
        db.close()
