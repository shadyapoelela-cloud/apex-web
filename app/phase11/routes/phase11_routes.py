"""
APEX Phase 11 — Legal Acceptance Routes
Endpoints:
  GET  /legal/documents         — current documents
  GET  /legal/pending           — pending acceptances for user
  POST /legal/accept/{doc_id}   — accept a document
  POST /legal/accept-all        — accept all mandatory (registration)
  GET  /legal/my-acceptances    — user's acceptance history
"""
from fastapi import APIRouter, HTTPException, Header

from app.core.auth_utils import extract_user_id

router = APIRouter(prefix="/legal", tags=["Legal Acceptance"])

@router.get("/documents")
def get_documents():
    from app.phase11.services.legal_service import get_current_documents
    return {"success": True, "data": get_current_documents()}

@router.get("/pending")
def get_pending(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase11.services.legal_service import check_pending_acceptances
    pending = check_pending_acceptances(user_id)
    return {"success": True, "data": {"pending": pending, "count": len(pending)}}

@router.post("/accept/{doc_id}")
def accept_doc(doc_id: str, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase11.services.legal_service import accept_document
    result = accept_document(user_id, doc_id)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.post("/accept-all")
def accept_all(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase11.services.legal_service import accept_all_current
    result = accept_all_current(user_id)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.get("/my-acceptances")
def my_acceptances(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase11.services.legal_service import get_user_acceptances
    return {"success": True, "data": get_user_acceptances(user_id)}
