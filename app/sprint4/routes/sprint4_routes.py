# -*- coding: utf-8 -*-
"""
Sprint 4 — Knowledge Brain Foundation Routes
18 APIs covering: Concepts, Aliases, Rules, Conflicts,
Source Systems, Reviewer Queues, Brain Status.

ALL raw SQL uses _exec(db, sql, params) — SQLAlchemy 2.x compat.
Does NOT touch any table from Phases 1-11 or Sprints 1-3.
"""
import uuid, json, logging
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import text as _t
from typing import Optional

router = APIRouter()


# ── SQL helper (same pattern as Sprint 2) ─────────────────
def _exec(db, sql, params=None):
    if params:
        return db.execute(_t(sql), params)
    return db.execute(_t(sql))


def _db():
    from app.phase1.models.platform_models import SessionLocal
    return SessionLocal()


def _now():
    return datetime.utcnow().isoformat()


# ══════════════════════════════════════════════════════════
# CONCEPTS
# ══════════════════════════════════════════════════════════

@router.post("/knowledge/concepts")
def create_concept(body: dict):
    """Create a new canonical concept."""
    db = _db()
    try:
        cid = str(uuid.uuid4())
        now = _now()
        _exec(db,
            """INSERT INTO knowledge_concepts
               (id, canonical_name_ar, canonical_name_en, domain_pack,
                sector_scope, jurisdiction_scope, authority_level,
                description_ar, description_en,
                effective_from, effective_to, last_verified_at,
                validity_status, created_at)
               VALUES
               (:id,:name_ar,:name_en,:domain,
                :sector,:jurisdiction,:authority,
                :desc_ar,:desc_en,
                :eff_from,:eff_to,:verified,
                'active',:now)""",
            {
                "id": cid,
                "name_ar":      body.get("canonical_name_ar", ""),
                "name_en":      body.get("canonical_name_en"),
                "domain":       body.get("domain_pack", "accounting"),
                "sector":       body.get("sector_scope"),
                "jurisdiction": body.get("jurisdiction_scope"),
                "authority":    body.get("authority_level", "platform"),
                "desc_ar":      body.get("description_ar"),
                "desc_en":      body.get("description_en"),
                "eff_from":     body.get("effective_from"),
                "eff_to":       body.get("effective_to"),
                "verified":     now,
                "now":          now,
            }
        )
        db.commit()
        return {"success": True, "data": {"id": cid, "status": "created", "canonical_name_ar": body.get("canonical_name_ar")}}
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/concepts")
def list_concepts(
    domain_pack: Optional[str] = None,
    authority_level: Optional[str] = None,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
):
    """List concepts with optional filters."""
    db = _db()
    try:
        where = ["validity_status = 'active'"]
        params = {}
        if domain_pack:
            where.append("domain_pack = :domain")
            params["domain"] = domain_pack
        if authority_level:
            where.append("authority_level = :auth")
            params["auth"] = authority_level
        if search:
            where.append("(canonical_name_ar LIKE :s OR canonical_name_en LIKE :s)")
            params["s"] = f"%{search}%"

        where_sql = " AND ".join(where)
        total = _exec(db, f"SELECT COUNT(*) FROM knowledge_concepts WHERE {where_sql}", params).fetchone()[0]
        offset = (page - 1) * page_size
        params["limit"] = page_size
        params["offset"] = offset

        rows = _exec(db,
            f"""SELECT id, canonical_name_ar, canonical_name_en, domain_pack,
                       authority_level, sector_scope, jurisdiction_scope,
                       validity_status, effective_from, effective_to, last_verified_at
                FROM knowledge_concepts
                WHERE {where_sql}
                ORDER BY canonical_name_ar
                LIMIT :limit OFFSET :offset""",
            params
        ).fetchall()

        keys = ["id","canonical_name_ar","canonical_name_en","domain_pack",
                "authority_level","sector_scope","jurisdiction_scope",
                "validity_status","effective_from","effective_to","last_verified_at"]
        return {"success": True, "data": {
            "total": total, "page": page, "page_size": page_size,
            "concepts": [dict(zip(keys, r)) for r in rows],
        }}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/concepts/{concept_id}")
def get_concept(concept_id: str):
    """Get a single concept with its aliases."""
    db = _db()
    try:
        row = _exec(db,
            """SELECT id, canonical_name_ar, canonical_name_en, domain_pack,
                      authority_level, sector_scope, jurisdiction_scope,
                      description_ar, description_en,
                      validity_status, effective_from, effective_to, last_verified_at
               FROM knowledge_concepts WHERE id = :id""",
            {"id": concept_id}
        ).fetchone()

        if not row:
            raise HTTPException(404, f"Concept {concept_id} not found")

        keys = ["id","canonical_name_ar","canonical_name_en","domain_pack",
                "authority_level","sector_scope","jurisdiction_scope",
                "description_ar","description_en",
                "validity_status","effective_from","effective_to","last_verified_at"]
        concept = dict(zip(keys, row))

        aliases = _exec(db,
            """SELECT id, alias_text, language_code, alias_type,
                      source_system, sector_scope, confidence_weight, is_approved
               FROM knowledge_concept_aliases
               WHERE concept_id = :id ORDER BY confidence_weight DESC""",
            {"id": concept_id}
        ).fetchall()
        alias_keys = ["id","alias_text","language_code","alias_type",
                      "source_system","sector_scope","confidence_weight","is_approved"]
        concept["aliases"] = [dict(zip(alias_keys, a)) for a in aliases]
        concept["alias_count"] = len(concept["aliases"])

        return {"success": True, "data": concept}
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.put("/knowledge/concepts/{concept_id}")
def update_concept(concept_id: str, body: dict):
    """Update concept metadata."""
    db = _db()
    try:
        _exec(db,
            """UPDATE knowledge_concepts SET
               canonical_name_ar  = COALESCE(:name_ar, canonical_name_ar),
               canonical_name_en  = COALESCE(:name_en, canonical_name_en),
               description_ar     = COALESCE(:desc_ar, description_ar),
               description_en     = COALESCE(:desc_en, description_en),
               authority_level    = COALESCE(:auth, authority_level),
               effective_from     = COALESCE(:eff_from, effective_from),
               effective_to       = COALESCE(:eff_to, effective_to),
               last_verified_at   = :now
               WHERE id = :id""",
            {
                "name_ar":  body.get("canonical_name_ar"),
                "name_en":  body.get("canonical_name_en"),
                "desc_ar":  body.get("description_ar"),
                "desc_en":  body.get("description_en"),
                "auth":     body.get("authority_level"),
                "eff_from": body.get("effective_from"),
                "eff_to":   body.get("effective_to"),
                "now":      _now(),
                "id":       concept_id,
            }
        )
        db.commit()
        return {"success": True, "data": {"id": concept_id, "status": "updated"}}
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════
# ALIASES
# ══════════════════════════════════════════════════════════

@router.post("/knowledge/aliases")
def create_alias(body: dict):
    """Add an alias to a concept — goes to review queue if not pre-approved."""
    db = _db()
    try:
        concept_id = body.get("concept_id")
        if not concept_id:
            raise HTTPException(422, "concept_id required")

        exists = _exec(db, "SELECT id FROM knowledge_concepts WHERE id = :id", {"id": concept_id}).fetchone()
        if not exists:
            raise HTTPException(404, f"Concept {concept_id} not found")

        # Check for conflict (same alias text + same scope)
        dup = _exec(db,
            """SELECT id FROM knowledge_concept_aliases
               WHERE alias_text = :text AND concept_id != :cid
               AND (source_system = :sys OR source_system IS NULL)
               LIMIT 1""",
            {"text": body.get("alias_text",""), "cid": concept_id, "sys": body.get("source_system")}
        ).fetchone()

        if dup:
            # Log conflict
            conflict_id = str(uuid.uuid4())
            _exec(db,
                """INSERT INTO knowledge_alias_conflicts
                   (id, alias_text, concept_id_1, concept_id_2, conflict_type,
                    conflict_status, detected_at)
                   VALUES (:id,:text,:c1,:c2,'duplicate_alias','pending',:now)""",
                {"id": conflict_id, "text": body.get("alias_text",""),
                 "c1": concept_id, "c2": None, "now": _now()}
            )

        aid = str(uuid.uuid4())
        is_approved = body.get("is_approved", False)
        _exec(db,
            """INSERT INTO knowledge_concept_aliases
               (id, concept_id, alias_text, language_code, alias_type,
                source_system, client_scope, sector_scope,
                confidence_weight, is_approved, review_status, created_at)
               VALUES
               (:id,:cid,:text,:lang,:type,
                :sys,:client,:sector,
                :conf,:approved,:rstatus,:now)""",
            {
                "id":       aid,
                "cid":      concept_id,
                "text":     body.get("alias_text",""),
                "lang":     body.get("language_code","ar"),
                "type":     body.get("alias_type","synonym"),
                "sys":      body.get("source_system"),
                "client":   body.get("client_scope"),
                "sector":   body.get("sector_scope"),
                "conf":     body.get("confidence_weight", 1.0),
                "approved": 1 if is_approved else 0,
                "rstatus":  "approved" if is_approved else "pending_review",
                "now":      _now(),
            }
        )
        db.commit()
        return {"success": True, "data": {
            "id": aid,
            "status": "created",
            "review_status": "approved" if is_approved else "pending_review",
            "conflict_detected": bool(dup),
        }}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/aliases/pending")
def list_pending_aliases(page: int = 1, page_size: int = 20):
    """Terminology review queue — aliases awaiting approval."""
    db = _db()
    try:
        total = _exec(db,
            "SELECT COUNT(*) FROM knowledge_concept_aliases WHERE review_status = 'pending_review'"
        ).fetchone()[0]

        rows = _exec(db,
            """SELECT a.id, a.alias_text, a.language_code, a.alias_type,
                      a.source_system, a.sector_scope, a.confidence_weight,
                      a.created_at,
                      c.canonical_name_ar, c.domain_pack
               FROM knowledge_concept_aliases a
               JOIN knowledge_concepts c ON a.concept_id = c.id
               WHERE a.review_status = 'pending_review'
               ORDER BY a.created_at DESC
               LIMIT :limit OFFSET :offset""",
            {"limit": page_size, "offset": (page-1)*page_size}
        ).fetchall()

        keys = ["id","alias_text","language_code","alias_type",
                "source_system","sector_scope","confidence_weight","created_at",
                "concept_canonical_ar","concept_domain"]
        return {"success": True, "data": {
            "total": total, "page": page, "page_size": page_size,
            "pending_aliases": [dict(zip(keys, r)) for r in rows],
        }}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.post("/knowledge/aliases/{alias_id}/review")
def review_alias(alias_id: str, body: dict):
    """Reviewer approves or rejects an alias."""
    db = _db()
    try:
        decision = body.get("decision")
        if decision not in ("approve", "reject", "escalate"):
            raise HTTPException(422, "decision must be: approve / reject / escalate")

        status_map = {"approve": "approved", "reject": "rejected", "escalate": "escalated"}
        new_status = status_map[decision]

        _exec(db,
            """UPDATE knowledge_concept_aliases
               SET review_status = :status,
                   is_approved = :approved,
                   reviewed_at = :now,
                   reviewer_notes = :notes
               WHERE id = :id""",
            {
                "status":   new_status,
                "approved": 1 if decision == "approve" else 0,
                "now":      _now(),
                "notes":    body.get("reviewer_notes"),
                "id":       alias_id,
            }
        )
        db.commit()
        return {"success": True, "data": {"alias_id": alias_id, "decision": decision, "new_status": new_status}}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════
# CONCEPT RESOLUTION (Brain Core)
# ══════════════════════════════════════════════════════════

@router.post("/knowledge/resolve")
def resolve_term(body: dict):
    """
    Resolve a raw term to a canonical concept.
    Core brain function — used by all sprint engines.
    """
    from app.sprint4.services.brain_engine import resolve_concept
    db = _db()
    try:
        raw_term      = body.get("term", "")
        source_system = body.get("source_system")
        sector        = body.get("sector")
        language      = body.get("language", "ar")

        if not raw_term:
            raise HTTPException(422, "term is required")

        concepts = [dict(zip(
            ["id","canonical_name_ar","canonical_name_en","domain_pack","authority_level"],
            r
        )) for r in _exec(db,
            """SELECT id, canonical_name_ar, canonical_name_en, domain_pack, authority_level
               FROM knowledge_concepts WHERE validity_status = 'active'"""
        ).fetchall()]

        aliases = [dict(zip(
            ["id","concept_id","alias_text","language_code","alias_type",
             "source_system","sector_scope","confidence_weight","is_approved"],
            r
        )) for r in _exec(db,
            """SELECT id, concept_id, alias_text, language_code, alias_type,
                      source_system, sector_scope, confidence_weight, is_approved
               FROM knowledge_concept_aliases WHERE review_status = 'approved'"""
        ).fetchall()]

        result = resolve_concept(raw_term, concepts, aliases, source_system, sector, language)

        # If no match, auto-queue for terminology review
        if result["match_type"] == "no_match":
            _exec(db,
                """INSERT OR IGNORE INTO knowledge_concept_aliases
                   (id, concept_id, alias_text, language_code, alias_type,
                    source_system, confidence_weight, is_approved, review_status, created_at)
                   VALUES
                   (:id, NULL, :text, :lang, 'unresolved',
                    :sys, 0.0, 0, 'pending_review', :now)""",
                {"id": str(uuid.uuid4()), "text": raw_term,
                 "lang": language, "sys": source_system, "now": _now()}
            )
            db.commit()

        return {"success": True, "data": {
            "raw_term":        raw_term,
            "source_system":   source_system,
            "sector":          sector,
            "resolution":      result,
            "queued_for_review": result["match_type"] == "no_match",
        }}
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.post("/knowledge/resolve/batch")
def resolve_batch(body: dict):
    """Resolve multiple terms at once — used by COA pipeline."""
    from app.sprint4.services.brain_engine import resolve_concept
    db = _db()
    try:
        terms = body.get("terms", [])
        source_system = body.get("source_system")
        sector        = body.get("sector")

        if not terms:
            raise HTTPException(422, "terms list is required")

        concepts = [dict(zip(
            ["id","canonical_name_ar","canonical_name_en","domain_pack","authority_level"],
            r
        )) for r in _exec(db,
            "SELECT id, canonical_name_ar, canonical_name_en, domain_pack, authority_level FROM knowledge_concepts WHERE validity_status = 'active'"
        ).fetchall()]

        aliases = [dict(zip(
            ["id","concept_id","alias_text","language_code","alias_type",
             "source_system","sector_scope","confidence_weight","is_approved"],
            r
        )) for r in _exec(db,
            "SELECT id, concept_id, alias_text, language_code, alias_type, source_system, sector_scope, confidence_weight, is_approved FROM knowledge_concept_aliases WHERE review_status = 'approved'"
        ).fetchall()]

        results = []
        unresolved = []
        for term in terms[:100]:  # cap at 100
            res = resolve_concept(str(term), concepts, aliases, source_system, sector)
            results.append({"term": term, "resolution": res})
            if res["match_type"] == "no_match":
                unresolved.append(term)

        return {"success": True, "data": {
            "total": len(terms),
            "resolved": sum(1 for r in results if r["resolution"]["match_type"] != "no_match"),
            "unresolved": len(unresolved),
            "unresolved_terms": unresolved,
            "results": results,
        }}
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════
# KNOWLEDGE RULES
# ══════════════════════════════════════════════════════════

@router.post("/knowledge/rules/candidate")
def submit_candidate_rule(body: dict):
    """Submit a candidate rule for review (from AI or expert feedback)."""
    db = _db()
    try:
        rid = str(uuid.uuid4())
        _exec(db,
            """INSERT INTO knowledge_candidate_rules
               (id, rule_name, domain_pack, rule_logic_json,
                authority_level, source_type, description_ar,
                submission_status, submitted_at)
               VALUES
               (:id,:name,:domain,:logic,
                :auth,:source,:desc_ar,
                'pending_review',:now)""",
            {
                "id":     rid,
                "name":   body.get("rule_name",""),
                "domain": body.get("domain_pack","accounting"),
                "logic":  json.dumps(body.get("rule_logic_json",{}), ensure_ascii=False),
                "auth":   body.get("authority_level","ai"),
                "source": body.get("source_type","ai_suggestion"),
                "desc_ar":body.get("description_ar"),
                "now":    _now(),
            }
        )
        db.commit()
        return {"success": True, "data": {"id": rid, "status": "pending_review", "rule_name": body.get("rule_name")}}
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/rules/candidates")
def list_candidate_rules(domain_pack: Optional[str] = None, page: int = 1, page_size: int = 20):
    """Rule Candidate Queue — for Knowledge Reviewer."""
    db = _db()
    try:
        where = ["submission_status = 'pending_review'"]
        params = {}
        if domain_pack:
            where.append("domain_pack = :domain")
            params["domain"] = domain_pack
        where_sql = " AND ".join(where)

        total = _exec(db, f"SELECT COUNT(*) FROM knowledge_candidate_rules WHERE {where_sql}", params).fetchone()[0]
        params.update({"limit": page_size, "offset": (page-1)*page_size})

        rows = _exec(db,
            f"""SELECT id, rule_name, domain_pack, authority_level,
                       source_type, description_ar, submission_status, submitted_at
                FROM knowledge_candidate_rules
                WHERE {where_sql}
                ORDER BY submitted_at DESC
                LIMIT :limit OFFSET :offset""",
            params
        ).fetchall()
        keys = ["id","rule_name","domain_pack","authority_level",
                "source_type","description_ar","submission_status","submitted_at"]
        return {"success": True, "data": {"total": total, "page": page, "candidates": [dict(zip(keys,r)) for r in rows]}}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.post("/knowledge/rules/candidates/{rule_id}/promote")
def promote_candidate_rule(rule_id: str, body: dict):
    """Reviewer promotes a candidate rule to active_knowledge_rules."""
    db = _db()
    try:
        decision = body.get("decision")
        if decision not in ("approve", "reject"):
            raise HTTPException(422, "decision must be: approve / reject")

        candidate = _exec(db,
            "SELECT id, rule_name, domain_pack, rule_logic_json, authority_level, description_ar FROM knowledge_candidate_rules WHERE id = :id",
            {"id": rule_id}
        ).fetchone()
        if not candidate:
            raise HTTPException(404, "Candidate rule not found")

        if decision == "approve":
            active_id = str(uuid.uuid4())
            eff_from = body.get("effective_from", _now()[:10])
            _exec(db,
                """INSERT INTO active_knowledge_rules
                   (id, rule_name, domain_pack, rule_logic_json,
                    authority_level, description_ar,
                    validity_status, effective_from,
                    promoted_from_candidate_id, promoted_at)
                   VALUES
                   (:id,:name,:domain,:logic,
                    :auth,:desc_ar,
                    'active',:eff_from,
                    :cid,:now)""",
                {
                    "id":      active_id,
                    "name":    candidate[1],
                    "domain":  candidate[2],
                    "logic":   candidate[3],
                    "auth":    candidate[4],
                    "desc_ar": candidate[5],
                    "eff_from":eff_from,
                    "cid":     rule_id,
                    "now":     _now(),
                }
            )

        _exec(db,
            """UPDATE knowledge_candidate_rules
               SET submission_status = :status,
                   reviewer_notes = :notes,
                   reviewed_at = :now
               WHERE id = :id""",
            {"status": "approved" if decision=="approve" else "rejected",
             "notes": body.get("reviewer_notes"), "now": _now(), "id": rule_id}
        )
        db.commit()
        return {"success": True, "data": {
            "rule_id": rule_id,
            "decision": decision,
            "active_rule_id": active_id if decision=="approve" else None,
        }}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/rules/active")
def list_active_rules(domain_pack: Optional[str] = None, page: int = 1, page_size: int = 20):
    """List active (promoted) knowledge rules."""
    db = _db()
    try:
        where = ["validity_status = 'active'"]
        params = {}
        if domain_pack:
            where.append("domain_pack = :domain")
            params["domain"] = domain_pack
        where_sql = " AND ".join(where)

        total = _exec(db, f"SELECT COUNT(*) FROM active_knowledge_rules WHERE {where_sql}", params).fetchone()[0]
        params.update({"limit": page_size, "offset": (page-1)*page_size})

        rows = _exec(db,
            f"""SELECT id, rule_name, domain_pack, authority_level,
                       description_ar, validity_status, effective_from, effective_to
                FROM active_knowledge_rules WHERE {where_sql}
                ORDER BY effective_from DESC LIMIT :limit OFFSET :offset""",
            params
        ).fetchall()
        keys = ["id","rule_name","domain_pack","authority_level",
                "description_ar","validity_status","effective_from","effective_to"]
        return {"success": True, "data": {"total": total, "page": page, "rules": [dict(zip(keys,r)) for r in rows]}}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════
# CONFLICT DETECTION
# ══════════════════════════════════════════════════════════

@router.post("/knowledge/conflicts/detect")
def detect_rule_conflicts(body: dict):
    """Run conflict detection across active rules in a domain."""
    from app.sprint4.services.brain_engine import detect_conflicts
    db = _db()
    try:
        domain_pack = body.get("domain_pack")
        where = "validity_status = 'active'"
        params = {}
        if domain_pack:
            where += " AND domain_pack = :domain"
            params["domain"] = domain_pack

        rows = _exec(db,
            f"SELECT id, rule_name, domain_pack, rule_logic_json, authority_level FROM active_knowledge_rules WHERE {where}",
            params
        ).fetchall()

        rules = []
        for r in rows:
            try:
                logic = json.loads(r[3]) if r[3] else {}
            except Exception:
                logic = {}
            rules.append({"id":r[0],"rule_name":r[1],"domain_pack":r[2],"rule_logic_json":logic,"authority_level":r[4]})

        conflicts = detect_conflicts(rules)

        # Store detected conflicts
        for c in conflicts:
            cid = str(uuid.uuid4())
            try:
                _exec(db,
                    """INSERT OR IGNORE INTO knowledge_alias_conflicts
                       (id, alias_text, concept_id_1, concept_id_2,
                        conflict_type, conflict_status, resolution_notes, detected_at)
                       VALUES (:id,:text,:c1,:c2,:type,'pending',:notes,:now)""",
                    {"id": cid, "text": f"rule_conflict:{c['rule_1_id'][:8]}_vs_{c['rule_2_id'][:8]}",
                     "c1": c["rule_1_id"], "c2": c["rule_2_id"],
                     "type": "rule_conflict",
                     "notes": f"winner:{c.get('winner_rule_id','?')}",
                     "now": _now()}
                )
            except Exception:
                pass

        db.commit()
        return {"success": True, "data": {
            "domain_pack":       domain_pack,
            "rules_checked":     len(rules),
            "conflicts_found":   len(conflicts),
            "conflicts":         conflicts,
            "requires_review":   [c for c in conflicts if c.get("requires_review")],
        }}
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/conflicts")
def list_conflicts(status: str = "pending", page: int = 1, page_size: int = 20):
    """List alias/rule conflicts for reviewer."""
    db = _db()
    try:
        total = _exec(db,
            "SELECT COUNT(*) FROM knowledge_alias_conflicts WHERE conflict_status = :s",
            {"s": status}
        ).fetchone()[0]

        rows = _exec(db,
            """SELECT id, alias_text, concept_id_1, concept_id_2,
                      conflict_type, conflict_status, resolution_notes, detected_at
               FROM knowledge_alias_conflicts
               WHERE conflict_status = :s
               ORDER BY detected_at DESC
               LIMIT :limit OFFSET :offset""",
            {"s": status, "limit": page_size, "offset": (page-1)*page_size}
        ).fetchall()
        keys = ["id","alias_text","concept_id_1","concept_id_2",
                "conflict_type","conflict_status","resolution_notes","detected_at"]
        return {"success": True, "data": {"total": total, "conflicts": [dict(zip(keys,r)) for r in rows]}}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════
# SOURCE SYSTEM AWARENESS
# ══════════════════════════════════════════════════════════

@router.post("/knowledge/source-systems")
def register_source_system(body: dict):
    """Register a source system profile (Odoo, SAP, QuickBooks, etc.)."""
    db = _db()
    try:
        sid = str(uuid.uuid4())
        _exec(db,
            """INSERT INTO source_system_profiles
               (id, system_name, system_version, description_ar,
                supported_languages, known_labels_json, created_at)
               VALUES (:id,:name,:ver,:desc,:langs,:labels,:now)""",
            {
                "id":     sid,
                "name":   body.get("system_name",""),
                "ver":    body.get("system_version"),
                "desc":   body.get("description_ar"),
                "langs":  json.dumps(body.get("supported_languages",["ar","en"]), ensure_ascii=False),
                "labels": json.dumps(body.get("known_labels_json",{}), ensure_ascii=False),
                "now":    _now(),
            }
        )
        db.commit()
        return {"success": True, "data": {"id": sid, "system_name": body.get("system_name"), "status": "registered"}}
    except Exception as e:
        db.rollback()
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


@router.get("/knowledge/source-systems")
def list_source_systems():
    """List all registered source system profiles."""
    db = _db()
    try:
        rows = _exec(db,
            "SELECT id, system_name, system_version, description_ar, supported_languages, created_at FROM source_system_profiles ORDER BY system_name"
        ).fetchall()
        keys = ["id","system_name","system_version","description_ar","supported_languages","created_at"]
        return {"success": True, "data": {"total": len(rows), "source_systems": [dict(zip(keys,r)) for r in rows]}}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════
# BRAIN STATUS & HEALTH
# ══════════════════════════════════════════════════════════

@router.get("/knowledge/brain/status")
def brain_status():
    """Knowledge Brain health — counts, queue sizes, readiness."""
    db = _db()
    try:
        concepts_total   = _exec(db, "SELECT COUNT(*) FROM knowledge_concepts WHERE validity_status='active'").fetchone()[0]
        aliases_approved = _exec(db, "SELECT COUNT(*) FROM knowledge_concept_aliases WHERE is_approved=1").fetchone()[0]
        aliases_pending  = _exec(db, "SELECT COUNT(*) FROM knowledge_concept_aliases WHERE review_status='pending_review'").fetchone()[0]
        rules_active     = _exec(db, "SELECT COUNT(*) FROM active_knowledge_rules WHERE validity_status='active'").fetchone()[0]
        rules_pending    = _exec(db, "SELECT COUNT(*) FROM knowledge_candidate_rules WHERE submission_status='pending_review'").fetchone()[0]
        conflicts_open   = _exec(db, "SELECT COUNT(*) FROM knowledge_alias_conflicts WHERE conflict_status='pending'").fetchone()[0]
        source_systems   = _exec(db, "SELECT COUNT(*) FROM source_system_profiles").fetchone()[0]

        readiness = "operational" if concepts_total >= 10 and aliases_approved >= 20 else                     "partial"     if concepts_total >= 1  else "empty"

        return {"success": True, "data": {
            "brain_status":      readiness,
            "concepts_active":   concepts_total,
            "aliases_approved":  aliases_approved,
            "aliases_pending_review": aliases_pending,
            "rules_active":      rules_active,
            "rules_pending_review": rules_pending,
            "conflicts_open":    conflicts_open,
            "source_systems":    source_systems,
            "queues": {
                "terminology_review": aliases_pending,
                "rule_candidates":    rules_pending,
                "conflict_review":    conflicts_open,
            },
            "version": "6.4.0",
        }}
    except Exception as e:
        logging.error("Knowledge Brain operation failed", exc_info=True)
        raise HTTPException(500, "Internal server error")
    finally:
        db.close()
