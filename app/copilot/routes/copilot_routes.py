import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.copilot.services.copilot_service import CopilotService
from app.copilot.services.intent_router import detect_intent
from app.phase1.routes.phase1_routes import get_current_user
from app.phase1.models.platform_models import SessionLocal
from app.copilot.models.copilot_models import CopilotEscalation

router = APIRouter(prefix='/copilot', tags=['Copilot AI'])


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    client_id: Optional[str] = None


class SessionRequest(BaseModel):
    client_id: Optional[str] = None
    session_type: str = 'general'


@router.post('/sessions')
async def create_session(req: SessionRequest, user: dict = Depends(get_current_user)):
    try:
        session = CopilotService.create_session(
            user_id=user['sub'],
            client_id=req.client_id,
            session_type=req.session_type
        )
        return {'success': True, 'data': session}
    except Exception as e:
        logging.error("Copilot create_session route error", exc_info=True)
        raise HTTPException(status_code=500, detail="فشل إنشاء الجلسة")


@router.get('/sessions')
async def list_sessions(user: dict = Depends(get_current_user)):
    sessions = CopilotService.list_sessions(user['sub'])
    return {'success': True, 'data': sessions}


@router.get('/sessions/{session_id}')
async def get_session(session_id: str, user: dict = Depends(get_current_user)):
    session = CopilotService.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail='الجلسة غير موجودة')
    if session.get('user_id') != user['sub']:
        raise HTTPException(status_code=403, detail='غير مصرح بالوصول لهذه الجلسة')
    return {'success': True, 'data': session}


@router.post('/chat')
async def chat(req: ChatRequest, user: dict = Depends(get_current_user)):
    try:
        if not req.session_id:
            session = CopilotService.create_session(
                user_id=user['sub'],
                client_id=req.client_id
            )
            session_id = session['id']
        else:
            session_id = req.session_id

        result = CopilotService.process_message(
            session_id=session_id,
            user_message=req.message,
            client_id=req.client_id
        )

        if 'error' in result:
            raise HTTPException(status_code=404, detail=result['error'])

        return {'success': True, 'data': result}
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Copilot chat error", exc_info=True)
        raise HTTPException(status_code=500, detail="فشل معالجة الرسالة")


@router.get('/sessions/{session_id}/messages')
async def get_messages(session_id: str, user: dict = Depends(get_current_user)):
    messages = CopilotService.get_messages(session_id)
    return {'success': True, 'data': messages}


@router.post('/detect-intent')
async def detect_intent_endpoint(req: ChatRequest, user: dict = Depends(get_current_user)):
    result = detect_intent(req.message)
    return {'success': True, 'data': result}


@router.get('/sessions/{session_id}/summary')
async def get_session_summary(session_id: str, user: dict = Depends(get_current_user)):
    """Get session summary with topic distribution and stats."""
    summary = CopilotService.get_session_summary(session_id)
    if not summary:
        raise HTTPException(status_code=404, detail='الجلسة غير موجودة')
    return {'success': True, 'data': summary}


@router.post('/sessions/{session_id}/close')
async def close_session(session_id: str, user: dict = Depends(get_current_user)):
    success = CopilotService.close_session(session_id)
    if not success:
        raise HTTPException(status_code=404, detail='الجلسة غير موجودة')
    return {'success': True, 'data': {'status': 'closed'}}


@router.get('/sessions/{session_id}/escalations')
async def get_session_escalations(session_id: str, limit: int = 50, offset: int = 0, user: dict = Depends(get_current_user)):
    """Get escalations for a specific copilot session."""
    db = SessionLocal()
    try:
        escalations = db.query(CopilotEscalation).filter(
            CopilotEscalation.session_id == session_id
        ).order_by(CopilotEscalation.created_at.desc()).limit(min(limit, 100)).offset(offset).all()
        return {'success': True, 'data': [{
            'id': e.id, 'session_id': e.session_id, 'message_id': e.message_id,
            'reason': e.reason, 'severity': e.severity, 'status': e.status,
            'assigned_to': e.assigned_to, 'resolution': e.resolution,
            'created_at': e.created_at.isoformat() if e.created_at else None,
            'resolved_at': e.resolved_at.isoformat() if e.resolved_at else None,
        } for e in escalations]}
    finally:
        db.close()


@router.get('/escalations')
async def list_all_escalations(status: str = "pending", user: dict = Depends(get_current_user)):
    """List all escalations (for admin/reviewer dashboard)."""
    db = SessionLocal()
    try:
        query = db.query(CopilotEscalation)
        if status:
            query = query.filter(CopilotEscalation.status == status)
        escalations = query.order_by(CopilotEscalation.created_at.desc()).limit(50).all()
        return {'success': True, 'data': [{
            'id': e.id, 'session_id': e.session_id, 'message_id': e.message_id,
            'reason': e.reason, 'severity': e.severity, 'status': e.status,
            'assigned_to': e.assigned_to, 'resolution': e.resolution,
            'created_at': e.created_at.isoformat() if e.created_at else None,
            'resolved_at': e.resolved_at.isoformat() if e.resolved_at else None,
        } for e in escalations]}
    finally:
        db.close()
