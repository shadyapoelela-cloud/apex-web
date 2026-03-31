"""
APEX Phase 11 — Legal Acceptance Service
"""
from datetime import datetime
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow
from app.phase11.models.phase11_models import LegalDocumentV2, AcceptanceLogV2, LEGAL_DOC_TYPES

def seed_legal_documents():
    """Seed initial policy documents."""
    db = SessionLocal()
    try:
        existing = db.query(LegalDocumentV2).count()
        if existing > 0:
            return {"status": "already_seeded", "count": existing}

        docs = [
            {
                "doc_type": "terms_of_service",
                "version": "1.0",
                "title_ar": "\u0627\u0644\u0634\u0631\u0648\u0637 \u0648\u0627\u0644\u0623\u062d\u0643\u0627\u0645",
                "title_en": "Terms of Service",
                "content_ar": "\u0628\u0627\u0633\u062a\u062e\u062f\u0627\u0645\u0643 \u0644\u0645\u0646\u0635\u0629 \u0623\u0628\u0643\u0633\u060c \u0641\u0625\u0646\u0643 \u062a\u0648\u0627\u0641\u0642 \u0639\u0644\u0649 \u0627\u0644\u0634\u0631\u0648\u0637 \u0627\u0644\u062a\u0627\u0644\u064a\u0629:\n\n1. \u064a\u062c\u0628 \u062a\u0642\u062f\u064a\u0645 \u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0635\u062d\u064a\u062d\u0629 \u0648\u062f\u0642\u064a\u0642\u0629 \u0639\u0646\u062f \u0627\u0644\u062a\u0633\u062c\u064a\u0644.\n2. \u064a\u062c\u0628 \u0627\u0644\u062d\u0641\u0627\u0638 \u0639\u0644\u0649 \u0633\u0631\u064a\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644.\n3. \u0631\u0641\u0639 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0648\u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a \u0648\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629 \u062c\u0632\u0621 \u062c\u0648\u0647\u0631\u064a \u0645\u0646 \u0627\u0633\u062a\u062d\u0642\u0627\u0642 \u0627\u0633\u062a\u0645\u0631\u0627\u0631 \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629.\n4. \u0644\u0644\u0645\u0646\u0635\u0629 \u062d\u0642 \u062a\u0639\u0644\u064a\u0642 \u0627\u0644\u062d\u0633\u0627\u0628 \u0639\u0646\u062f \u0648\u062c\u0648\u062f \u0645\u062e\u0627\u0644\u0641\u0629 \u062c\u0648\u0647\u0631\u064a\u0629.",
            },
            {
                "doc_type": "privacy_policy",
                "version": "1.0",
                "title_ar": "\u0633\u064a\u0627\u0633\u0629 \u0627\u0644\u062e\u0635\u0648\u0635\u064a\u0629",
                "title_en": "Privacy Policy",
                "content_ar": "\u0646\u062d\u0646 \u0646\u062d\u062a\u0631\u0645 \u062e\u0635\u0648\u0635\u064a\u062a\u0643:\n\n1. \u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0627\u0644\u0645\u0627\u0644\u064a\u0629 \u0645\u0634\u0641\u0631\u0629 \u0648\u0645\u062d\u0645\u064a\u0629.\n2. \u0644\u0627 \u0646\u0634\u0627\u0631\u0643 \u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0645\u0639 \u0623\u0637\u0631\u0627\u0641 \u062e\u0627\u0631\u062c\u064a\u0629.\n3. \u064a\u0645\u0643\u0646\u0643 \u0637\u0644\u0628 \u062d\u0630\u0641 \u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0641\u064a \u0623\u064a \u0648\u0642\u062a.",
            },
            {
                "doc_type": "acceptable_use_policy",
                "version": "1.0",
                "title_ar": "\u0633\u064a\u0627\u0633\u0629 \u0627\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u0642\u0628\u0648\u0644",
                "title_en": "Acceptable Use Policy",
                "content_ar": "\u064a\u062c\u0628 \u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u0646\u0635\u0629 \u0644\u0623\u063a\u0631\u0627\u0636 \u0645\u0647\u0646\u064a\u0629 \u0645\u0634\u0631\u0648\u0639\u0629 \u0641\u0642\u0637.\n\n1. \u0644\u0627 \u064a\u062c\u0648\u0632 \u0631\u0641\u0639 \u0628\u064a\u0627\u0646\u0627\u062a \u0645\u0632\u064a\u0641\u0629.\n2. \u0644\u0627 \u064a\u062c\u0648\u0632 \u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u0646\u0635\u0629 \u0644\u063a\u0633\u064a\u0644 \u0627\u0644\u0623\u0645\u0648\u0627\u0644.\n3. \u064a\u062c\u0628 \u0627\u0644\u0627\u0644\u062a\u0632\u0627\u0645 \u0628\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0629 \u0627\u0644\u0633\u0639\u0648\u062f\u064a\u0629.",
            },
            {
                "doc_type": "provider_policy",
                "version": "1.0",
                "title_ar": "\u0633\u064a\u0627\u0633\u0629 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a",
                "title_en": "Service Provider Policy",
                "content_ar": "\u0639\u0646\u062f \u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0643\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629:\n\n1. \u064a\u062c\u0628 \u0631\u0641\u0639 \u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u062a\u062d\u0642\u0642 \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629.\n2. \u064a\u062c\u0628 \u0631\u0641\u0639 \u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a \u0648\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a \u0644\u0643\u0644 \u0645\u0647\u0645\u0629.\n3. \u0639\u062f\u0645 \u0627\u0644\u0627\u0644\u062a\u0632\u0627\u0645 \u064a\u0624\u062f\u064a \u0644\u062a\u0639\u0644\u064a\u0642 \u0627\u0644\u062d\u0633\u0627\u0628.\n4. \u0646\u0633\u0628\u0629 \u0627\u0644\u0645\u0646\u0635\u0629 %20 \u0648\u0646\u0633\u0628\u0629 \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629 %80.",
            },
        ]

        created = 0
        for d in docs:
            doc = LegalDocumentV2(
                id=gen_uuid(),
                doc_type=d["doc_type"],
                version=d["version"],
                title_ar=d["title_ar"],
                title_en=d.get("title_en"),
                content_ar=d["content_ar"],
                is_current=True,
                is_mandatory=True,
            )
            db.add(doc)
            created += 1

        db.commit()
        return {"status": "seeded", "created": created}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

def get_current_documents():
    """Get all current legal documents."""
    db = SessionLocal()
    try:
        docs = db.query(LegalDocumentV2).filter(
            LegalDocumentV2.is_current == True
        ).all()
        return [{
            "id": d.id,
            "type": d.doc_type,
            "version": d.version,
            "title_ar": d.title_ar,
            "title_en": d.title_en,
            "content_ar": d.content_ar,
            "is_mandatory": d.is_mandatory,
        } for d in docs]
    finally:
        db.close()

def get_user_acceptances(user_id):
    """Get all acceptances for a user."""
    db = SessionLocal()
    try:
        logs = db.query(AcceptanceLogV2).filter(
            AcceptanceLogV2.user_id == user_id
        ).order_by(AcceptanceLogV2.accepted_at.desc()).all()
        return [{
            "doc_type": l.doc_type,
            "doc_version": l.doc_version,
            "accepted_at": str(l.accepted_at) if l.accepted_at else None,
        } for l in logs]
    finally:
        db.close()

def check_pending_acceptances(user_id):
    """Check which mandatory documents the user hasn't accepted yet."""
    db = SessionLocal()
    try:
        current_docs = db.query(LegalDocumentV2).filter(
            LegalDocumentV2.is_current == True,
            LegalDocumentV2.is_mandatory == True,
        ).all()

        user_logs = db.query(AcceptanceLogV2).filter(
            AcceptanceLogV2.user_id == user_id
        ).all()

        accepted = {(l.doc_type, l.doc_version) for l in user_logs}
        pending = []
        for doc in current_docs:
            if (doc.doc_type, doc.version) not in accepted:
                pending.append({
                    "id": doc.id,
                    "type": doc.doc_type,
                    "version": doc.version,
                    "title_ar": doc.title_ar,
                    "content_ar": doc.content_ar,
                    "is_mandatory": doc.is_mandatory,
                })
        return pending
    finally:
        db.close()

def accept_document(user_id, document_id, ip_address=None):
    """Record user acceptance of a document."""
    db = SessionLocal()
    try:
        doc = db.query(LegalDocumentV2).filter(
            LegalDocumentV2.id == document_id
        ).first()
        if not doc:
            return {"status": "error", "detail": "\u0627\u0644\u0648\u062b\u064a\u0642\u0629 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f\u0629"}

        existing = db.query(AcceptanceLogV2).filter(
            AcceptanceLogV2.user_id == user_id,
            AcceptanceLogV2.document_id == document_id,
        ).first()
        if existing:
            return {"status": "already_accepted"}

        log = AcceptanceLogV2(
            id=gen_uuid(),
            user_id=user_id,
            document_id=document_id,
            doc_type=doc.doc_type,
            doc_version=doc.version,
            ip_address=ip_address,
        )
        db.add(log)
        db.commit()
        return {"status": "ok", "doc_type": doc.doc_type, "version": doc.version}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

def accept_all_current(user_id, ip_address=None):
    """Accept all current mandatory documents at once (for registration)."""
    db = SessionLocal()
    try:
        docs = db.query(LegalDocumentV2).filter(
            LegalDocumentV2.is_current == True,
            LegalDocumentV2.is_mandatory == True,
        ).all()

        count = 0
        for doc in docs:
            existing = db.query(AcceptanceLogV2).filter(
                AcceptanceLogV2.user_id == user_id,
                AcceptanceLogV2.document_id == doc.id,
            ).first()
            if not existing:
                log = AcceptanceLogV2(
                    id=gen_uuid(),
                    user_id=user_id,
                    document_id=doc.id,
                    doc_type=doc.doc_type,
                    doc_version=doc.version,
                    ip_address=ip_address,
                )
                db.add(log)
                count += 1

        db.commit()
        return {"status": "ok", "accepted": count}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()
