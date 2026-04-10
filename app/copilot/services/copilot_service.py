import logging
from datetime import datetime
from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.copilot.models.copilot_models import CopilotSession, CopilotMessage, CopilotEscalation
from app.copilot.services.intent_router import detect_intent, build_context, suggest_next_actions


class CopilotService:

    @classmethod
    def create_session(cls, user_id, client_id=None, session_type="general"):
        db = SessionLocal()
        try:
            session = CopilotSession(
                id=gen_uuid(), user_id=user_id, client_id=client_id,
                session_type=session_type, context={}, status="active"
            )
            db.add(session)
            db.commit()
            return cls._session_to_dict(session)
        except Exception as e:
            db.rollback()
            logging.error(f"Copilot create_session error: {e}")
            raise
        finally:
            db.close()

    @classmethod
    def get_session(cls, session_id):
        db = SessionLocal()
        try:
            session = db.query(CopilotSession).filter(CopilotSession.id == session_id).first()
            return cls._session_to_dict(session) if session else None
        finally:
            db.close()

    @classmethod
    def list_sessions(cls, user_id):
        db = SessionLocal()
        try:
            sessions = db.query(CopilotSession).filter(
                CopilotSession.user_id == user_id,
                CopilotSession.status == "active"
            ).order_by(CopilotSession.created_at.desc()).all()
            return [cls._session_to_dict(s) for s in sessions]
        finally:
            db.close()

    @classmethod
    def process_message(cls, session_id, user_message, client_id=None):
        db = SessionLocal()
        try:
            session = db.query(CopilotSession).filter(CopilotSession.id == session_id).first()
            if not session:
                return {"error": "Session not found"}

            intent_result = detect_intent(user_message)
            intent = intent_result["intent"]
            confidence = intent_result["confidence"]
            ctx = build_context(session.user_id, client_id or session.client_id, intent)

            risk_level = "low"
            if intent in ["compliance", "audit_review"]:
                risk_level = "high" if confidence < 0.6 else "medium"
            elif intent in ["funding_readiness"]:
                risk_level = "medium"

            needs_escalation = confidence < 0.45 or (risk_level == "high" and confidence < 0.7)
            response_text = cls._generate_response(intent, confidence, ctx, user_message)
            next_actions = suggest_next_actions(intent, ctx)
            references = cls._get_references(intent)

            # Save user message
            user_msg = CopilotMessage(
                id=gen_uuid(), session_id=session_id, role="user",
                content=user_message
            )
            db.add(user_msg)

            # Save assistant message
            msg_id = gen_uuid()
            escalation_data = {"needed": needs_escalation, "reason": "Low confidence or high risk"} if needs_escalation else None
            assistant_msg = CopilotMessage(
                id=msg_id, session_id=session_id, role="assistant",
                content=response_text, intent=intent, confidence=confidence,
                risk_level=risk_level, tools_used=[intent],
                references=references, escalation=escalation_data
            )
            db.add(assistant_msg)

            # Save escalation if needed
            if needs_escalation:
                esc = CopilotEscalation(
                    id=gen_uuid(), session_id=session_id, message_id=msg_id,
                    reason=f"Low confidence ({confidence}) or high risk ({risk_level})",
                    severity="high" if risk_level == "high" else "medium"
                )
                db.add(esc)

            # Update session context
            session.context = {**ctx, "last_intent": intent}
            session.updated_at = datetime.utcnow()
            db.commit()

            return {
                "message": cls._message_to_dict(assistant_msg, next_actions),
                "session_id": session_id,
                "intent": intent_result,
                "context": ctx,
                "needs_escalation": needs_escalation
            }
        except Exception as e:
            db.rollback()
            logging.error(f"Copilot process_message error: {e}")
            raise
        finally:
            db.close()

    @classmethod
    def get_messages(cls, session_id):
        db = SessionLocal()
        try:
            messages = db.query(CopilotMessage).filter(
                CopilotMessage.session_id == session_id
            ).order_by(CopilotMessage.created_at).all()
            return [cls._message_to_dict(m) for m in messages]
        finally:
            db.close()

    @classmethod
    def close_session(cls, session_id):
        db = SessionLocal()
        try:
            session = db.query(CopilotSession).filter(CopilotSession.id == session_id).first()
            if not session:
                return False
            session.status = "closed"
            session.updated_at = datetime.utcnow()
            db.commit()
            return True
        except Exception as e:
            db.rollback()
            logging.error(f"Copilot close_session error: {e}")
            return False
        finally:
            db.close()

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

    @staticmethod
    def _session_to_dict(session):
        return {
            "id": session.id, "user_id": session.user_id,
            "client_id": session.client_id, "session_type": session.session_type,
            "context": session.context or {}, "status": session.status,
            "created_at": session.created_at.isoformat() if session.created_at else None
        }

    @staticmethod
    def _message_to_dict(msg, next_actions=None):
        d = {
            "id": msg.id, "role": msg.role, "content": msg.content,
            "intent": msg.intent, "confidence": msg.confidence,
            "risk_level": msg.risk_level, "tools_used": msg.tools_used,
            "references": msg.references, "escalation": msg.escalation,
            "created_at": msg.created_at.isoformat() if msg.created_at else None
        }
        if next_actions:
            d["next_actions"] = next_actions
        return d
