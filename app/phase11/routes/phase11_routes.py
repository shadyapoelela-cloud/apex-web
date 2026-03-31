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
import jwt, os

router = APIRouter(prefix="/legal", tags=["Legal Acceptance"])

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")

def extract_user_id(authorization: str = None):
    if not authorization:
        raise HTTPException(status_code=401, detail="\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload.get("sub") or payload.get("user_id")
    except Exception:
        raise HTTPException(status_code=401, detail="\u0631\u0645\u0632 \u063a\u064a\u0631 \u0635\u0627\u0644\u062d")

@router.get("/documents")
def get_documents():
    from app.phase11.services.legal_service import get_current_documents
    return {"documents": get_current_documents()}

@router.get("/pending")
def get_pending(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase11.services.legal_service import check_pending_acceptances
    pending = check_pending_acceptances(user_id)
    return {"pending": pending, "count": len(pending)}

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
    return {"acceptances": get_user_acceptances(user_id)}
