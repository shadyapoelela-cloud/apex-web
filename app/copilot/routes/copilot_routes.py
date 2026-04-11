"""
APEX — Copilot API routes for chat, sessions, and escalation management
مسارات API للمساعد الذكي: المحادثة، الجلسات، وإدارة التصعيدات
"""

import logging
import os
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.copilot.services.copilot_service import CopilotService, COPILOT_SYSTEM_PROMPT, ANTHROPIC_API_KEY
from app.copilot.services.intent_router import detect_intent, build_context, suggest_next_actions
from app.phase1.routes.phase1_routes import get_current_user

router = APIRouter(prefix="/copilot", tags=["Copilot AI"])


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    client_id: Optional[str] = None


class SessionRequest(BaseModel):
    client_id: Optional[str] = None
    session_type: str = "general"


# ═══════════════════════════════════════════════════════════════
# Stateless Claude call — works without DB
# ═══════════════════════════════════════════════════════════════


def _stateless_claude_chat(user_message: str, user: dict, client_id: Optional[str] = None) -> dict:
    """Call Claude directly without any DB dependency. Used as ultimate fallback."""
    from app.phase1.models.platform_models import gen_uuid

    intent_result = detect_intent(user_message)
    intent = intent_result["intent"]
    confidence = intent_result["confidence"]
    ctx = build_context(user.get("sub", ""), client_id, intent)
    next_actions = suggest_next_actions(intent, ctx)

    intent_labels = {
        "financial_analysis": "التحليل المالي",
        "coa_workflow": "شجرة الحسابات",
        "tb_binding": "ربط ميزان المراجعة",
        "funding_readiness": "الجاهزية التمويلية",
        "compliance": "الامتثال والضرائب",
        "audit_review": "المراجعة والتدقيق",
        "knowledge_lookup": "البحث في المعايير",
        "service_request": "طلب خدمة مهنية",
        "explain_result": "شرح النتائج",
        "account_management": "إدارة الحساب",
        "general": "استفسار عام",
    }
    intent_label = intent_labels.get(intent, intent)

    # Try Claude API first
    response_text = None
    if ANTHROPIC_API_KEY:
        try:
            import anthropic

            client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

            system_prompt = (
                COPILOT_SYSTEM_PROMPT
                + f"\n\n═══ السياق ═══\n- نية المستخدم: {intent_label} (ثقة: {confidence})"
            )
            if ctx.get("requires_client") and not client_id:
                system_prompt += "\n⚠️ لم يتم اختيار عميل"
            if ctx.get("may_escalate"):
                system_prompt += "\n🔴 موضوع حساس — قد يحتاج تصعيد لمختص"

            # Get user display name
            user_name = user.get("display_name") or user.get("username") or ""
            if user_name:
                system_prompt += f"\n👤 اسم المستخدم: {user_name}"

            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1500,
                temperature=0.6,
                system=system_prompt,
                messages=[{"role": "user", "content": user_message}],
            )
            response_text = response.content[0].text.strip()
        except Exception as e:
            logging.error("Stateless Claude call failed: %s", e)

    # Fallback if Claude failed
    if not response_text:
        response_text = CopilotService._generate_fallback_response(intent, confidence, ctx, user_message)

    msg_id = gen_uuid()
    return {
        "message": {
            "id": msg_id,
            "role": "assistant",
            "content": response_text,
            "intent": intent,
            "confidence": confidence,
            "risk_level": "medium" if intent in ["compliance", "audit_review"] else "low",
            "tools_used": [intent],
            "references": CopilotService._get_references(intent),
            "escalation": None,
            "next_actions": next_actions,
            "created_at": None,
        },
        "session_id": None,
        "intent": intent_result,
        "context": ctx,
        "needs_escalation": False,
    }


# ═══════════════════════════════════════════════════════════════
# Routes
# ═══════════════════════════════════════════════════════════════


@router.post("/sessions")
async def create_session(req: SessionRequest, user: dict = Depends(get_current_user)):
    try:
        session = CopilotService.create_session(
            user_id=user["sub"], client_id=req.client_id, session_type=req.session_type
        )
        return {"success": True, "data": session}
    except Exception:
        logging.error("Copilot create_session route error", exc_info=True)
        raise HTTPException(status_code=500, detail="فشل إنشاء الجلسة")


@router.get("/sessions")
async def list_sessions(user: dict = Depends(get_current_user)):
    try:
        sessions = CopilotService.list_sessions(user["sub"])
        return {"success": True, "data": sessions}
    except Exception:
        return {"success": True, "data": []}


@router.get("/sessions/{session_id}")
async def get_session(session_id: str, user: dict = Depends(get_current_user)):
    session = CopilotService.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="الجلسة غير موجودة")
    if session.get("user_id") != user["sub"]:
        raise HTTPException(status_code=403, detail="غير مصرح بالوصول لهذه الجلسة")
    return {"success": True, "data": session}


@router.post("/chat")
async def chat(req: ChatRequest, user: dict = Depends(get_current_user)):
    """Main chat endpoint — tries DB-backed sessions first, falls back to stateless Claude."""
    try:
        # Try the full DB-backed flow first
        if not req.session_id:
            session = CopilotService.create_session(user_id=user["sub"], client_id=req.client_id)
            session_id = session["id"]
        else:
            session_id = req.session_id

        result = CopilotService.process_message(
            session_id=session_id, user_message=req.message, client_id=req.client_id
        )

        # Check if process_message returned our error fallback
        if result.get("intent", {}).get("intent") == "error":
            # DB-backed flow failed, try stateless
            logging.warning("DB-backed copilot failed, trying stateless mode")
            result = _stateless_claude_chat(req.message, user, req.client_id)

        if "error" in result and "message" not in result:
            raise HTTPException(status_code=404, detail=result["error"])

        return {"success": True, "data": result}

    except HTTPException:
        raise
    except Exception:
        # Ultimate fallback: stateless Claude call
        logging.error("Copilot chat DB error, falling back to stateless", exc_info=True)
        try:
            result = _stateless_claude_chat(req.message, user, req.client_id)
            return {"success": True, "data": result}
        except Exception:
            logging.error("Stateless copilot also failed", exc_info=True)
            raise HTTPException(status_code=500, detail="فشل معالجة الرسالة")


@router.get("/sessions/{session_id}/messages")
async def get_messages(session_id: str, user: dict = Depends(get_current_user)):
    try:
        messages = CopilotService.get_messages(session_id)
        return {"success": True, "data": messages}
    except Exception:
        return {"success": True, "data": []}


@router.post("/detect-intent")
async def detect_intent_endpoint(req: ChatRequest, user: dict = Depends(get_current_user)):
    result = detect_intent(req.message)
    return {"success": True, "data": result}


@router.get("/sessions/{session_id}/summary")
async def get_session_summary(session_id: str, user: dict = Depends(get_current_user)):
    """Get session summary with topic distribution and stats."""
    summary = CopilotService.get_session_summary(session_id)
    if not summary:
        raise HTTPException(status_code=404, detail="الجلسة غير موجودة")
    return {"success": True, "data": summary}


@router.post("/sessions/{session_id}/close")
async def close_session(session_id: str, user: dict = Depends(get_current_user)):
    success = CopilotService.close_session(session_id)
    if not success:
        raise HTTPException(status_code=404, detail="الجلسة غير موجودة")
    return {"success": True, "data": {"status": "closed"}}


@router.get("/sessions/{session_id}/escalations")
async def get_session_escalations(
    session_id: str, limit: int = 50, offset: int = 0, user: dict = Depends(get_current_user)
):
    """Get escalations for a specific copilot session."""
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        from app.copilot.models.copilot_models import CopilotEscalation

        escalations = (
            db.query(CopilotEscalation)
            .filter(CopilotEscalation.session_id == session_id)
            .order_by(CopilotEscalation.created_at.desc())
            .limit(min(limit, 100))
            .offset(offset)
            .all()
        )
        return {
            "success": True,
            "data": [
                {
                    "id": e.id,
                    "session_id": e.session_id,
                    "message_id": e.message_id,
                    "reason": e.reason,
                    "severity": e.severity,
                    "status": e.status,
                    "assigned_to": e.assigned_to,
                    "resolution": e.resolution,
                    "created_at": e.created_at.isoformat() if e.created_at else None,
                    "resolved_at": e.resolved_at.isoformat() if e.resolved_at else None,
                }
                for e in escalations
            ],
        }
    finally:
        db.close()


@router.get("/escalations")
async def list_all_escalations(status: str = "pending", user: dict = Depends(get_current_user)):
    """List all escalations (admin/reviewer only)."""
    user_roles = user.get("roles", [])
    if "admin" not in user_roles and "reviewer" not in user_roles:
        raise HTTPException(403, "هذه الخدمة متاحة للمسؤولين فقط")

    from app.phase1.models.platform_models import SessionLocal
    from app.copilot.models.copilot_models import CopilotEscalation

    db = SessionLocal()
    try:
        query = db.query(CopilotEscalation)
        if status:
            query = query.filter(CopilotEscalation.status == status)
        escalations = query.order_by(CopilotEscalation.created_at.desc()).limit(50).all()
        return {
            "success": True,
            "data": [
                {
                    "id": e.id,
                    "session_id": e.session_id,
                    "message_id": e.message_id,
                    "reason": e.reason,
                    "severity": e.severity,
                    "status": e.status,
                    "assigned_to": e.assigned_to,
                    "resolution": e.resolution,
                    "created_at": e.created_at.isoformat() if e.created_at else None,
                    "resolved_at": e.resolved_at.isoformat() if e.resolved_at else None,
                }
                for e in escalations
            ],
        }
    finally:
        db.close()
