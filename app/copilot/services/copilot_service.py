from typing import Optional
from datetime import datetime
import uuid

from app.copilot.services.intent_router import detect_intent, build_context, suggest_next_actions


class CopilotService:
    _sessions = {}
    _messages = {}

    @classmethod
    def create_session(cls, user_id, client_id=None, session_type="general"):
        sid = str(uuid.uuid4())
        session = {
            "id": sid, "user_id": user_id, "client_id": client_id,
            "session_type": session_type, "context": {},
            "status": "active", "created_at": datetime.utcnow().isoformat(),
            "messages": []
        }
        cls._sessions[sid] = session
        cls._messages[sid] = []
        return session

    @classmethod
    def get_session(cls, session_id):
        return cls._sessions.get(session_id)

    @classmethod
    def list_sessions(cls, user_id):
        return [s for s in cls._sessions.values() if s["user_id"] == user_id and s["status"] == "active"]

    @classmethod
    def process_message(cls, session_id, user_message, client_id=None):
        session = cls._sessions.get(session_id)
        if not session:
            return {"error": "Session not found"}
        intent_result = detect_intent(user_message)
        intent = intent_result["intent"]
        confidence = intent_result["confidence"]
        ctx = build_context(session.get("user_id", ""), client_id or session.get("client_id"), intent)
        risk_level = "low"
        if intent in ["compliance", "audit_review"]:
            risk_level = "high" if confidence < 0.6 else "medium"
        elif intent in ["funding_readiness"]:
            risk_level = "medium"
        needs_escalation = confidence < 0.45 or (risk_level == "high" and confidence < 0.7)
        response_text = cls._generate_response(intent, confidence, ctx, user_message)
        next_actions = suggest_next_actions(intent, ctx)
        references = cls._get_references(intent)
        user_msg = {"id": str(uuid.uuid4()), "role": "user", "content": user_message, "created_at": datetime.utcnow().isoformat()}
        msg_id = str(uuid.uuid4())
        assistant_msg = {
            "id": msg_id, "role": "assistant", "content": response_text,
            "intent": intent, "confidence": confidence, "risk_level": risk_level,
            "tools_used": [intent], "references": references,
            "next_actions": next_actions,
            "escalation": {"needed": needs_escalation, "reason": "Low confidence or high risk"} if needs_escalation else None,
            "created_at": datetime.utcnow().isoformat()
        }
        if session_id not in cls._messages:
            cls._messages[session_id] = []
        cls._messages[session_id].extend([user_msg, assistant_msg])
        session["context"] = ctx
        session["context"]["last_intent"] = intent
        return {"message": assistant_msg, "session_id": session_id, "intent": intent_result, "context": ctx, "needs_escalation": needs_escalation}

    @classmethod
    def get_messages(cls, session_id):
        return cls._messages.get(session_id, [])

    @classmethod
    def _generate_response(cls, intent, confidence, ctx, user_message):
        responses = {
            "financial_analysis": "يمكنني مساعدتك في التحليل المالي. هل تريد رفع ميزان المراجعة؟",
            "coa_workflow": "لنبدأ بشجرة الحسابات. يمكنك رفع الملف وسأقوم بتحليله. CSV و Excel.",
            "tb_binding": "سأساعدك في ربط الميزان بشجرة الحسابات. هل لديك شجرة معتمدة؟",
            "funding_readiness": "سأقيّم جاهزية المنشأة للتمويل. سأحتاج بيانات العميل.",
            "compliance": "سأفحص الامتثال. النتائج استرشادية وتحتاج مراجعة مختص.",
            "audit_review": "سأساعدك في المراجعة عبر 7 مراحل. من أين نبدأ؟",
            "knowledge_lookup": "سأبحث في قاعدة المعرفة: SOCPA, ZATCA, نظام الشركات, ISA.",
            "service_request": "يمكنني مساعدتك في طلب خدمة مهنية. ما نوع الخدمة؟",
            "explain_result": "سأشرح النتيجة مع الأدلة والمراجع.",
            "account_management": "يمكنني مساعدتك في إدارة حسابك.",
            "general": "مرحبا! أنا مساعد Apex الذكي. كيف أساعدك؟"
        }
        base = responses.get(intent, responses["general"])
        if confidence < 0.5:
            base += "\n\n⚠️ لم أتمكن من فهم طلبك بدقة. وضح أكثر."
        if ctx.get("requires_client") and not ctx.get("client_id"):
            base += "\n\n📋 يرجى اختيار العميل أولا."
        return base

    @classmethod
    def _get_references(cls, intent):
        ref_map = {
            "compliance": [{"source": "ZATCA", "type": "regulatory", "note": "هيئة الزكاة"}, {"source": "VAT", "type": "law", "note": "ضريبة القيمة المضافة"}],
            "audit_review": [{"source": "ISA", "type": "standard", "note": "معايير المراجعة"}, {"source": "SOCPA", "type": "standard", "note": "المعايير السعودية"}],
            "financial_analysis": [{"source": "SOCPA", "type": "standard", "note": "معايير المحاسبة"}, {"source": "IFRS", "type": "standard", "note": "المعايير الدولية"}],
            "knowledge_lookup": [{"source": "MoC", "type": "regulatory", "note": "نظام الشركات"}, {"source": "SOCPA", "type": "standard", "note": "الهيئة السعودية"}]
        }
        return ref_map.get(intent, [])

    @classmethod
    def close_session(cls, session_id):
        if session_id in cls._sessions:
            cls._sessions[session_id]["status"] = "closed"
            return True
        return False
