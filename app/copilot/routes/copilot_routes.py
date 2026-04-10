from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from app.copilot.services.copilot_service import CopilotService
from app.copilot.services.intent_router import detect_intent
from app.phase1.routes.phase1_routes import get_current_user

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
    session = CopilotService.create_session(
        user_id=user['sub'],
        client_id=req.client_id,
        session_type=req.session_type
    )
    return {'success': True, 'data': session}


@router.get('/sessions')
async def list_sessions(user: dict = Depends(get_current_user)):
    sessions = CopilotService.list_sessions(user['sub'])
    return {'success': True, 'data': sessions}


@router.get('/sessions/{session_id}')
async def get_session(session_id: str):
    session = CopilotService.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail='Session not found')
    return {'success': True, 'data': session}


@router.post('/chat')
async def chat(req: ChatRequest, user: dict = Depends(get_current_user)):
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


@router.get('/sessions/{session_id}/messages')
async def get_messages(session_id: str):
    messages = CopilotService.get_messages(session_id)
    return {'success': True, 'data': messages}


@router.post('/detect-intent')
async def detect_intent_endpoint(req: ChatRequest):
    result = detect_intent(req.message)
    return {'success': True, 'data': result}


@router.post('/sessions/{session_id}/close')
async def close_session(session_id: str):
    success = CopilotService.close_session(session_id)
    if not success:
        raise HTTPException(status_code=404, detail='Session not found')
    return {'success': True, 'data': {'status': 'closed'}}
