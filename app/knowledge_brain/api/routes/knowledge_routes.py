"""
Apex Knowledge Brain — API Routes
═══════════════════════════════════

Endpoints per implementation plan:
- /knowledge/stats
- /knowledge/sources (CRUD)
- /knowledge/entries (CRUD + search)
- /knowledge/rules (CRUD + activate/deactivate)
- /knowledge/updates (CRUD + impact)
- /knowledge/search
- /knowledge/review-queue
- /knowledge/audit-log
- /knowledge/seed
"""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime, timezone
from app.knowledge_brain.models.db_models import (
    get_db,
    init_db,
    get_table_stats,
    Source,
    Entry,
    Rule,
    Update,
    Authority,
    ReviewQueueItem,
    AuditLog,
)

router = APIRouter(prefix="/knowledge", tags=["Knowledge Brain"])


# ═══ Stats ═══
@router.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    """Dashboard stats — عدد المصادر والمعرفة والقواعد."""
    init_db()
    return {
        "success": True,
        "data": {
            "tables": get_table_stats(db),
        },
    }


# ═══ Seed ═══
@router.post("/seed")
def seed_knowledge(db: Session = Depends(get_db)):
    """Seed the knowledge database with initial data."""
    init_db()
    from app.knowledge_brain.services.seed_service import seed_all

    stats = seed_all(db)
    return {"success": True, "data": {"status": "seeded", "created": stats}}


# ═══════════════════════════════
#  Sources — المصادر الرسمية
# ═══════════════════════════════


@router.get("/sources")
def list_sources(
    domain: Optional[str] = None,
    authority: Optional[str] = None,
    status: Optional[str] = "active",
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
):
    q = db.query(Source)
    if domain:
        q = q.filter(Source.domain == domain)
    if authority:
        q = q.filter(Source.authority_code == authority)
    if status:
        q = q.filter(Source.status == status)
    sources = q.order_by(Source.created_at.desc()).limit(limit).all()
    return {"success": True, "data": {"count": len(sources), "sources": [_source_dict(s) for s in sources]}}


@router.post("/sources")
def create_source(data: dict, db: Session = Depends(get_db)):
    src = Source(**{k: v for k, v in data.items() if hasattr(Source, k)})
    db.add(src)
    db.commit()
    db.refresh(src)
    _audit(db, "source", src.id, "create")
    return {"success": True, "data": _source_dict(src)}


@router.get("/sources/{source_id}")
def get_source(source_id: str, db: Session = Depends(get_db)):
    src = db.query(Source).filter_by(id=source_id).first()
    if not src:
        raise HTTPException(404, "Source not found")
    entries = db.query(Entry).filter_by(source_id=source_id).all()
    return {"success": True, "data": {"source": _source_dict(src), "entries": [_entry_dict(e) for e in entries]}}


@router.put("/sources/{source_id}")
def update_source(source_id: str, data: dict, db: Session = Depends(get_db)):
    src = db.query(Source).filter_by(id=source_id).first()
    if not src:
        raise HTTPException(404, "Source not found")
    for k, v in data.items():
        if hasattr(src, k) and k != "id":
            setattr(src, k, v)
    db.commit()
    _audit(db, "source", source_id, "update")
    return {"success": True, "data": {"status": "updated"}}


@router.post("/sources/{source_id}/archive")
def archive_source(source_id: str, db: Session = Depends(get_db)):
    src = db.query(Source).filter_by(id=source_id).first()
    if not src:
        raise HTTPException(404, "Source not found")
    src.status = "archived"
    db.commit()
    _audit(db, "source", source_id, "archive")
    return {"success": True, "data": {"status": "archived"}}


# ═══════════════════════════════
#  Entries — المعرفة المنظمة
# ═══════════════════════════════


@router.get("/entries")
def list_entries(
    domain: Optional[str] = None,
    status: Optional[str] = "approved",
    source_id: Optional[str] = None,
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
):
    q = db.query(Entry)
    if domain:
        q = q.filter(Entry.domain == domain)
    if status:
        q = q.filter(Entry.status == status)
    if source_id:
        q = q.filter(Entry.source_id == source_id)
    entries = q.order_by(Entry.created_at.desc()).limit(limit).all()
    return {"success": True, "data": {"count": len(entries), "entries": [_entry_dict(e) for e in entries]}}


@router.post("/entries")
def create_entry(data: dict, db: Session = Depends(get_db)):
    entry = Entry(**{k: v for k, v in data.items() if hasattr(Entry, k)})
    db.add(entry)
    db.commit()
    db.refresh(entry)
    _audit(db, "entry", entry.id, "create")
    return {"success": True, "data": _entry_dict(entry)}


@router.get("/entries/{entry_id}")
def get_entry(entry_id: str, db: Session = Depends(get_db)):
    e = db.query(Entry).filter_by(id=entry_id).first()
    if not e:
        raise HTTPException(404, "Entry not found")
    return {"success": True, "data": _entry_dict(e)}


@router.post("/entries/{entry_id}/approve")
def approve_entry(entry_id: str, db: Session = Depends(get_db)):
    e = db.query(Entry).filter_by(id=entry_id).first()
    if not e:
        raise HTTPException(404, "Entry not found")
    e.status = "approved"
    e.review_status = "approved"
    db.commit()
    _audit(db, "entry", entry_id, "approve")
    return {"success": True, "data": {"status": "approved"}}


# ═══════════════════════════════
#  Rules — القواعد التنفيذية
# ═══════════════════════════════


@router.get("/rules")
def list_rules(
    domain: Optional[str] = None,
    active: Optional[bool] = True,
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    q = db.query(Rule)
    if domain:
        q = q.filter(Rule.domain == domain)
    if active is not None:
        q = q.filter(Rule.active == active)
    rules = q.order_by(Rule.rule_code).limit(limit).all()
    return {"success": True, "data": {"count": len(rules), "rules": [_rule_dict(r) for r in rules]}}


@router.post("/rules")
def create_rule(data: dict, db: Session = Depends(get_db)):
    rule = Rule(**{k: v for k, v in data.items() if hasattr(Rule, k)})
    db.add(rule)
    db.commit()
    db.refresh(rule)
    _audit(db, "rule", rule.id, "create")
    return {"success": True, "data": _rule_dict(rule)}


@router.post("/rules/{rule_code}/activate")
def activate_rule(rule_code: str, db: Session = Depends(get_db)):
    r = db.query(Rule).filter_by(rule_code=rule_code).first()
    if not r:
        raise HTTPException(404, "Rule not found")
    r.active = True
    db.commit()
    _audit(db, "rule", r.id, "activate")
    return {"success": True, "data": {"status": "activated"}}


@router.post("/rules/{rule_code}/deactivate")
def deactivate_rule(rule_code: str, db: Session = Depends(get_db)):
    r = db.query(Rule).filter_by(rule_code=rule_code).first()
    if not r:
        raise HTTPException(404, "Rule not found")
    r.active = False
    db.commit()
    _audit(db, "rule", r.id, "deactivate")
    return {"success": True, "data": {"status": "deactivated"}}


# ═══════════════════════════════
#  Updates — التحديثات
# ═══════════════════════════════


@router.get("/updates")
def list_updates(status: Optional[str] = None, limit: int = 50, db: Session = Depends(get_db)):
    q = db.query(Update)
    if status:
        q = q.filter(Update.status == status)
    updates = q.order_by(Update.created_at.desc()).limit(limit).all()
    return {"success": True, "data": {"count": len(updates), "updates": [_update_dict(u) for u in updates]}}


@router.post("/updates")
def create_update(data: dict, db: Session = Depends(get_db)):
    upd = Update(**{k: v for k, v in data.items() if hasattr(Update, k)})
    db.add(upd)
    db.commit()
    _audit(db, "update", upd.id, "create")
    return {"success": True, "data": {"id": upd.id}}


@router.post("/updates/{update_id}/apply")
def apply_update(update_id: str, db: Session = Depends(get_db)):
    u = db.query(Update).filter_by(id=update_id).first()
    if not u:
        raise HTTPException(404, "Update not found")
    u.status = "applied"
    u.applied_at = datetime.now(timezone.utc)
    db.commit()
    _audit(db, "update", update_id, "apply")
    return {"success": True, "data": {"status": "applied"}}


# ═══════════════════════════════
#  Search — بحث شامل
# ═══════════════════════════════


@router.get("/search")
def search_knowledge(
    q: str = Query(..., min_length=1),
    domain: Optional[str] = None,
    source_type: Optional[str] = None,
    official_only: bool = False,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    """Search across sources, entries, and rules."""
    results = []

    # Search sources
    sq = db.query(Source).filter(Source.title.contains(q) | Source.official_reference.contains(q))
    if domain:
        sq = sq.filter(Source.domain == domain)
    if official_only:
        sq = sq.filter(Source.legal_force.in_(["binding_law", "implementing_regulation", "professional_standard"]))
    for s in sq.limit(limit).all():
        results.append(
            {
                "type": "source",
                "id": s.id,
                "title": s.title,
                "domain": s.domain,
                "authority": s.authority_code,
                "status": s.status,
                "legal_force": s.legal_force,
            }
        )

    # Search entries
    eq = db.query(Entry).filter(Entry.title.contains(q) | Entry.summary.contains(q))
    if domain:
        eq = eq.filter(Entry.domain == domain)
    for e in eq.limit(limit).all():
        results.append(
            {
                "type": "entry",
                "id": e.id,
                "title": e.title,
                "domain": e.domain,
                "confidence": e.confidence_level,
                "status": e.status,
            }
        )

    # Search rules
    rq = db.query(Rule).filter(Rule.rule_name_ar.contains(q) | Rule.rule_code.contains(q) | Rule.reference.contains(q))
    if domain:
        rq = rq.filter(Rule.domain == domain)
    for r in rq.limit(limit).all():
        results.append(
            {
                "type": "rule",
                "id": r.id,
                "code": r.rule_code,
                "title": r.rule_name_ar,
                "domain": r.domain,
                "active": r.active,
                "authority": r.authority_code,
            }
        )

    return {"success": True, "data": {"query": q, "total": len(results), "results": results}}


# ═══════════════════════════════
#  Authorities — الجهات
# ═══════════════════════════════


@router.get("/authorities")
def list_authorities(limit: int = 50, offset: int = 0, db: Session = Depends(get_db)):
    auths = (
        db.query(Authority)
        .filter_by(active=True)
        .order_by(Authority.source_priority)
        .limit(min(limit, 100))
        .offset(offset)
        .all()
    )
    return {
        "success": True,
        "data": {
            "count": len(auths),
            "authorities": [
                {
                    "code": a.code,
                    "name_ar": a.name_ar,
                    "name_en": a.name_en,
                    "jurisdiction": a.jurisdiction,
                    "domain_scope": a.domain_scope,
                    "priority": a.source_priority,
                }
                for a in auths
            ],
        },
    }


# ═══════════════════════════════
#  Review Queue — طابور المراجعة
# ═══════════════════════════════


@router.get("/review-queue")
def list_review_queue(status: str = "pending", limit: int = 50, offset: int = 0, db: Session = Depends(get_db)):
    items = (
        db.query(ReviewQueueItem)
        .filter_by(status=status)
        .order_by(ReviewQueueItem.created_at.desc())
        .limit(min(limit, 100))
        .offset(offset)
        .all()
    )
    return {
        "success": True,
        "data": {
            "count": len(items),
            "items": [
                {
                    "id": i.id,
                    "entity_type": i.entity_type,
                    "entity_id": i.entity_id,
                    "action": i.action,
                    "status": i.status,
                    "created_at": str(i.created_at),
                }
                for i in items
            ],
        },
    }


@router.post("/review/{entity_type}/{entity_id}/approve")
def approve_review(entity_type: str, entity_id: str, db: Session = Depends(get_db)):
    item = db.query(ReviewQueueItem).filter_by(entity_type=entity_type, entity_id=entity_id, status="pending").first()
    if item:
        item.status = "approved"
        item.resolved_at = datetime.now(timezone.utc)
        db.commit()
    _audit(db, entity_type, entity_id, "approve")
    return {"success": True, "data": {"status": "approved"}}


# ═══════════════════════════════
#  Audit Log — سجل التعديلات
# ═══════════════════════════════


@router.get("/audit-log")
def list_audit_log(entity_type: Optional[str] = None, limit: int = 50, db: Session = Depends(get_db)):
    q = db.query(AuditLog)
    if entity_type:
        q = q.filter(AuditLog.entity_type == entity_type)
    logs = q.order_by(AuditLog.timestamp.desc()).limit(limit).all()
    return {
        "success": True,
        "data": {
            "count": len(logs),
            "logs": [
                {
                    "id": l.id,
                    "entity_type": l.entity_type,
                    "entity_id": l.entity_id,
                    "action": l.action,
                    "user": l.user,
                    "timestamp": str(l.timestamp),
                }
                for l in logs
            ],
        },
    }


# ═══ Helpers ═══


def _audit(db, entity_type, entity_id, action, user="system"):
    db.add(AuditLog(entity_type=entity_type, entity_id=entity_id, action=action, user=user))
    db.commit()


def _source_dict(s):
    return {
        "id": s.id,
        "title": s.title,
        "domain": s.domain,
        "subdomain": s.subdomain,
        "authority": s.authority_code,
        "source_type": s.source_type,
        "legal_force": s.legal_force,
        "reference": s.official_reference,
        "url": s.source_url,
        "status": s.status,
        "version": s.version_label,
        "effective_date": str(s.effective_date) if s.effective_date else None,
    }


def _entry_dict(e):
    return {
        "id": e.id,
        "entry_code": e.entry_code,
        "title": e.title,
        "domain": e.domain,
        "summary": e.summary,
        "confidence": e.confidence_level,
        "obligation": e.obligation_level,
        "status": e.status,
        "source_id": e.source_id,
    }


def _rule_dict(r):
    return {
        "id": r.id,
        "code": r.rule_code,
        "name_ar": r.rule_name_ar,
        "domain": r.domain,
        "authority": r.authority_code,
        "reference": r.reference,
        "obligation": r.obligation_level,
        "active": r.active,
        "version": r.version,
    }


def _update_dict(u):
    return {
        "id": u.id,
        "type": u.update_type,
        "title": u.title,
        "authority": u.authority_code,
        "summary": u.change_summary,
        "status": u.status,
        "effective_date": str(u.effective_date) if u.effective_date else None,
    }
