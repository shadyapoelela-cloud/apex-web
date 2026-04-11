"""
APEX — Copilot service layer for session management and AI-powered chat
خدمة المساعد الذكي لإدارة الجلسات والمحادثة المدعومة بالذكاء الاصطناعي

Powered by Claude (Anthropic) — configured as APEX's intelligent financial assistant
"""

import os
import logging
from datetime import datetime, timezone
from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.copilot.models.copilot_models import CopilotSession, CopilotMessage, CopilotEscalation
from app.copilot.services.intent_router import detect_intent, build_context, suggest_next_actions

# Maximum recent messages to include as conversation memory
MAX_MEMORY_MESSAGES = 20

# AI API key for real responses
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")

# ═══════════════════════════════════════════════════════════════
# APEX COPILOT — SYSTEM PROMPT (Claude Identity as APEX Assistant)
# ═══════════════════════════════════════════════════════════════

COPILOT_SYSTEM_PROMPT = """أنت "Apex Copilot" — المساعد الذكي المدمج في منصة APEX، وهي منصة سعودية متقدمة للتحليل المالي والحوكمة المعرفية مصممة خصيصاً للسوق السعودي.

═══════════════════════════════════════
🏢 هوية المنصة
═══════════════════════════════════════

APEX هي منصة مالية سعودية شاملة تخدم:
- المحاسبين القانونيين والمالكين
- مكاتب المراجعة والتدقيق
- المنشآت الصغيرة والمتوسطة (SMEs)
- المستشارين الماليين والضريبيين
- الشركات التي تسعى للتمويل البنكي أو الاستثماري

═══════════════════════════════════════
🎯 خدمات المنصة التي تدعمها
═══════════════════════════════════════

1. **شجرة الحسابات (COA)**
   - رفع ملفات CSV/Excel تحتوي على دليل الحسابات
   - تصنيف تلقائي ذكي (أصول، خصوم، حقوق ملكية، إيرادات، مصروفات)
   - 70+ قاعدة تصنيف عربية و33+ إنجليزية و16 قاعدة لرموز الحسابات
   - تقييم جودة بخمسة أبعاد: التغطية، الاتساق، العمق، التوازن، الاكتمال
   - مراجعة واعتماد مع بوابات ثقة (85% للاعتماد التلقائي)

2. **ميزان المراجعة (Trial Balance)**
   - رفع الميزان بصيغة Excel
   - ربط تلقائي بشجرة الحسابات المعتمدة
   - كشف المطابقات الدقيقة والتقريبية
   - تقرير نسب الربط والحسابات غير المطابقة

3. **التحليل المالي**
   - حساب 20+ نسبة مالية (ربحية، سيولة، كفاءة، رفع مالي)
   - مقارنة بمعايير القطاع (Benchmarking)
   - إنشاء القوائم المالية: الدخل، المركز المالي، التدفقات النقدية
   - توليد تقارير PDF وExcel

4. **الجاهزية التمويلية**
   - تقييم شامل لجاهزية المنشأة للحصول على تمويل
   - تحديد الفجوات والمتطلبات المفقودة
   - درجة جاهزية من 0 إلى 100

5. **الامتثال والحوكمة**
   - فحص التزام بمتطلبات ZATCA (هيئة الزكاة والضريبة والجمارك)
   - ضريبة القيمة المضافة (VAT 15%)
   - الفوترة الإلكترونية (FATOORAH)
   - نظام الشركات السعودي الجديد (2023)

6. **المراجعة والتدقيق**
   - 7 مراحل: من تعريف الشجرة حتى المخرجات النهائية
   - برامج مراجعة ذكية
   - اختيار عينات وتنفيذ إجراءات
   - أوراق عمل وملاحظات

7. **سوق الخدمات المهنية (Marketplace)**
   - طلب خدمات: مسك دفاتر، إعداد قوائم، مراجعة ضريبية
   - ربط بمكاتب محاسبة ومراجعة معتمدة
   - تتبع الطلبات والتقييمات

8. **قاعدة المعرفة المهنية (Knowledge Brain)**
   - معايير SOCPA (الهيئة السعودية للمراجعين والمحاسبين)
   - معايير IFRS الدولية
   - معايير المراجعة ISA
   - أنظمة ولوائح ZATCA
   - نظام الشركات ولوائحه التنفيذية

═══════════════════════════════════════
🎨 شخصيتك وأسلوبك
═══════════════════════════════════════

- أنت مساعد مهني ذكي، ودود لكن محترف — لست روبوت خدمة عملاء عادي
- تتحدث بالعربية الفصحى البسيطة (لا عامية ولا تعقيد لغوي)
- أجب بالإنجليزية فقط إذا طلب المستخدم ذلك صراحة
- استخدم الأرقام والنقاط والتنسيق لتسهيل القراءة
- كن مباشراً — لا تكرر الترحيب في كل رد، ركز على الإجابة
- إذا كان السؤال خارج نطاق المنصة، وجّه المستخدم بلطف
- لا تقل "أنا مجرد ذكاء اصطناعي" — أنت Apex Copilot وهذه هويتك

═══════════════════════════════════════
⚠️ قواعد حتمية
═══════════════════════════════════════

1. **لا تختلق بيانات مالية**: إذا لم تكن لديك أرقام فعلية، قل ذلك بوضوح
2. **الامتثال والضرائب**: دائماً أضف تحذير "النتائج استرشادية وتحتاج مراجعة مختص معتمد"
3. **التصعيد**: إذا كان الموضوع يحتاج خبير بشري (مثل فتوى ضريبية أو رأي قانوني)، اقترح التصعيد
4. **الخصوصية**: لا تطلب من المستخدم مشاركة بيانات حساسة (كلمات مرور، أرقام حسابات بنكية)
5. **المعايير والأنظمة**: عند الاستشهاد بنظام أو معيار، اذكر المصدر والرقم إن أمكن
6. **الردود المختصرة**: لا تزيد عن 400 كلمة إلا إذا طلب المستخدم تفصيلاً
7. **التوجيه العملي**: دائماً قدم الخطوة التالية — لا تترك المستخدم بدون إجراء واضح
8. **السياق**: استخدم بيانات العميل المرفقة في السياق لتخصيص إجاباتك"""

# ═══════════════════════════════════════════════════════════════
# Dynamic context builder — pulls real client data for Claude
# ═══════════════════════════════════════════════════════════════


def _fetch_client_context(db, client_id: str) -> str:
    """Fetch real client data to enrich Claude's context."""
    if not client_id:
        return ""

    context_parts = []

    try:
        from app.phase2.models.phase2_models import Client

        client = db.query(Client).filter(Client.id == client_id).first()
        if client:
            context_parts.append(f"اسم العميل: {client.name_ar or client.name or '—'}")
            if hasattr(client, "sector") and client.sector:
                context_parts.append(f"القطاع: {client.sector}")
            if hasattr(client, "legal_entity_type") and client.legal_entity_type:
                context_parts.append(f"الكيان القانوني: {client.legal_entity_type}")
            if hasattr(client, "coa_status") and client.coa_status:
                context_parts.append(f"حالة شجرة الحسابات: {client.coa_status}")
            if hasattr(client, "tb_status") and client.tb_status:
                context_parts.append(f"حالة ميزان المراجعة: {client.tb_status}")
    except Exception:
        logging.debug("Could not fetch client data for copilot context", exc_info=True)

    # Try to get latest COA upload info
    try:
        from app.sprint1.models.sprint1_models import CoaUpload

        coa = (
            db.query(CoaUpload)
            .filter(CoaUpload.client_id == client_id)
            .order_by(CoaUpload.created_at.desc())
            .first()
        )
        if coa:
            context_parts.append(f"آخر رفع COA: {coa.status or '—'}")
            if hasattr(coa, "total_accounts"):
                context_parts.append(f"عدد الحسابات: {coa.total_accounts or 0}")
            if hasattr(coa, "classification_confidence"):
                conf = coa.classification_confidence
                if conf:
                    context_parts.append(f"ثقة التصنيف: {conf}%")
    except Exception:
        pass

    # Try to get latest analysis
    try:
        from app.phase3.models.phase3_models import AnalysisResult

        analysis = (
            db.query(AnalysisResult)
            .filter(AnalysisResult.client_id == client_id)
            .order_by(AnalysisResult.created_at.desc())
            .first()
        )
        if analysis:
            context_parts.append(f"آخر تحليل مالي: متوفر")
            if hasattr(analysis, "readiness_score") and analysis.readiness_score:
                context_parts.append(f"درجة الجاهزية: {analysis.readiness_score}/100")
    except Exception:
        pass

    if context_parts:
        return "\n\n📋 بيانات العميل الحالي:\n" + "\n".join(f"- {p}" for p in context_parts)
    return ""


def _fetch_user_context(db, user_id: str) -> str:
    """Fetch user profile info for personalization."""
    try:
        from app.phase1.models.platform_models import User

        user = db.query(User).filter(User.id == user_id).first()
        if user:
            parts = []
            if user.display_name:
                parts.append(f"اسم المستخدم: {user.display_name}")
            if hasattr(user, "plan") and user.plan:
                plan_labels = {
                    "free": "مجاني",
                    "starter": "أساسي",
                    "professional": "احترافي",
                    "enterprise": "مؤسسي",
                }
                parts.append(f"الخطة: {plan_labels.get(user.plan, user.plan)}")
            if parts:
                return "\n👤 " + " | ".join(parts)
    except Exception:
        pass
    return ""


class CopilotService:

    @classmethod
    def create_session(cls, user_id, client_id=None, session_type="general"):
        db = SessionLocal()
        try:
            session = CopilotSession(
                id=gen_uuid(),
                user_id=user_id,
                client_id=client_id,
                session_type=session_type,
                context={},
                status="active",
            )
            db.add(session)
            db.commit()
            return cls._session_to_dict(session)
        except Exception:
            db.rollback()
            logging.error("Copilot create_session error", exc_info=True)
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
            sessions = (
                db.query(CopilotSession)
                .filter(CopilotSession.user_id == user_id, CopilotSession.status == "active")
                .order_by(CopilotSession.created_at.desc())
                .all()
            )
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

            # Load conversation memory (recent messages for context)
            recent_messages = (
                db.query(CopilotMessage)
                .filter(CopilotMessage.session_id == session_id)
                .order_by(CopilotMessage.created_at.desc())
                .limit(MAX_MEMORY_MESSAGES)
                .all()
            )
            recent_messages.reverse()  # chronological order
            conversation_history = [{"role": m.role, "content": m.content, "intent": m.intent} for m in recent_messages]

            # Use session context for intent boosting
            last_intent = (session.context or {}).get("last_intent")
            intent_result = detect_intent(user_message)
            intent = intent_result["intent"]
            confidence = intent_result["confidence"]

            # Continuity boost: if user seems to continue same topic
            if last_intent and intent == "general" and confidence < 0.5 and conversation_history:
                intent = last_intent
                confidence = 0.5
                intent_result = {
                    "intent": intent,
                    "confidence": confidence,
                    "all_scores": intent_result.get("all_scores", {}),
                    "continued_from": last_intent,
                }

            ctx = build_context(session.user_id, client_id or session.client_id, intent)

            risk_level = "low"
            if intent in ["compliance", "audit_review"]:
                risk_level = "high" if confidence < 0.6 else "medium"
            elif intent in ["funding_readiness"]:
                risk_level = "medium"

            needs_escalation = confidence < 0.45 or (risk_level == "high" and confidence < 0.7)

            # Fetch real client + user context for AI enrichment
            effective_client_id = client_id or session.client_id
            client_context = _fetch_client_context(db, effective_client_id) if effective_client_id else ""
            user_context = _fetch_user_context(db, session.user_id)

            response_text = cls._generate_response(
                intent, confidence, ctx, user_message, conversation_history,
                client_context=client_context, user_context=user_context,
            )
            next_actions = suggest_next_actions(intent, ctx)
            references = cls._get_references(intent)

            # Save user message
            user_msg = CopilotMessage(id=gen_uuid(), session_id=session_id, role="user", content=user_message)
            db.add(user_msg)

            # Save assistant message
            msg_id = gen_uuid()
            escalation_data = (
                {"needed": needs_escalation, "reason": "Low confidence or high risk"} if needs_escalation else None
            )
            assistant_msg = CopilotMessage(
                id=msg_id,
                session_id=session_id,
                role="assistant",
                content=response_text,
                intent=intent,
                confidence=confidence,
                risk_level=risk_level,
                tools_used=[intent],
                references=references,
                escalation=escalation_data,
            )
            db.add(assistant_msg)

            # Save escalation if needed
            if needs_escalation:
                esc = CopilotEscalation(
                    id=gen_uuid(),
                    session_id=session_id,
                    message_id=msg_id,
                    reason=f"Low confidence ({confidence}) or high risk ({risk_level})",
                    severity="high" if risk_level == "high" else "medium",
                )
                db.add(esc)

            # Update session context with history
            intent_history = (session.context or {}).get("intent_history", [])
            intent_history.append(intent)
            if len(intent_history) > 20:
                intent_history = intent_history[-20:]
            session.context = {
                **ctx,
                "last_intent": intent,
                "intent_history": intent_history,
                "message_count": len(conversation_history) + 2,
                "last_confidence": confidence,
            }
            session.updated_at = datetime.now(timezone.utc)
            db.commit()

            return {
                "message": cls._message_to_dict(assistant_msg, next_actions),
                "session_id": session_id,
                "intent": intent_result,
                "context": ctx,
                "needs_escalation": needs_escalation,
            }
        except Exception:
            db.rollback()
            logging.error("Copilot process_message error", exc_info=True)
            # Return a graceful fallback instead of crashing
            return {
                "message": {
                    "id": gen_uuid(),
                    "role": "assistant",
                    "content": "عذرًا، حدث خطأ تقني مؤقت. يرجى المحاولة مرة أخرى بعد قليل.\n\nإذا استمرت المشكلة، يرجى التواصل مع فريق الدعم الفني.",
                    "intent": "error",
                    "confidence": 0,
                    "risk_level": "low",
                    "tools_used": [],
                    "references": [],
                    "next_actions": [
                        {"label": "إعادة المحاولة", "action": "retry"},
                        {"label": "بدء محادثة جديدة", "action": "new_session"},
                    ],
                },
                "session_id": session_id,
                "intent": {"intent": "error", "confidence": 0},
                "context": {},
                "needs_escalation": True,
            }
        finally:
            db.close()

    @classmethod
    def get_messages(cls, session_id):
        db = SessionLocal()
        try:
            messages = (
                db.query(CopilotMessage)
                .filter(CopilotMessage.session_id == session_id)
                .order_by(CopilotMessage.created_at)
                .all()
            )
            return [cls._message_to_dict(m) for m in messages]
        finally:
            db.close()

    @classmethod
    def get_session_summary(cls, session_id):
        """Get a summary of the session including topic distribution and escalations."""
        db = SessionLocal()
        try:
            session = db.query(CopilotSession).filter(CopilotSession.id == session_id).first()
            if not session:
                return None
            messages = (
                db.query(CopilotMessage)
                .filter(CopilotMessage.session_id == session_id)
                .order_by(CopilotMessage.created_at)
                .all()
            )
            escalations = db.query(CopilotEscalation).filter(CopilotEscalation.session_id == session_id).all()

            intents = [m.intent for m in messages if m.intent and m.role == "assistant"]
            topic_counts = {}
            for i in intents:
                topic_counts[i] = topic_counts.get(i, 0) + 1

            confidences = [m.confidence for m in messages if m.confidence is not None]
            avg_confidence = round(sum(confidences) / len(confidences), 2) if confidences else 0

            return {
                "session_id": session_id,
                "status": session.status,
                "total_messages": len(messages),
                "user_messages": sum(1 for m in messages if m.role == "user"),
                "assistant_messages": sum(1 for m in messages if m.role == "assistant"),
                "topics": topic_counts,
                "primary_topic": max(topic_counts, key=topic_counts.get) if topic_counts else "general",
                "avg_confidence": avg_confidence,
                "escalation_count": len(escalations),
                "created_at": session.created_at.isoformat() if session.created_at else None,
                "updated_at": session.updated_at.isoformat() if session.updated_at else None,
            }
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
            session.updated_at = datetime.now(timezone.utc)
            db.commit()
            return True
        except Exception:
            db.rollback()
            logging.error("Copilot close_session error", exc_info=True)
            return False
        finally:
            db.close()

    # ═══════════════════════════════════════════════════════════════
    # AI Response Generation (Claude API + Fallback)
    # ═══════════════════════════════════════════════════════════════

    @classmethod
    def _generate_response(cls, intent, confidence, ctx, user_message, conversation_history=None,
                           client_context="", user_context=""):
        """Generate AI response using Claude API, with fallback to hardcoded responses."""
        if not ANTHROPIC_API_KEY:
            return cls._generate_fallback_response(intent, confidence, ctx, user_message, conversation_history)

        try:
            import anthropic

            client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

            # Build conversation messages for Claude
            messages = []

            # Include conversation history for context
            if conversation_history:
                for msg in conversation_history:
                    role = msg.get("role", "user")
                    content = msg.get("content", "")
                    if role in ("user", "assistant") and content:
                        messages.append({"role": role, "content": content})

            # Add the current user message
            messages.append({"role": "user", "content": user_message})

            # Build the full system prompt with dynamic context
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

            # Build dynamic context section
            dynamic_context = f"\n\n═══ السياق الحالي ═══\n- نية المستخدم: {intent_label} (ثقة: {confidence})"

            if user_context:
                dynamic_context += user_context
            if client_context:
                dynamic_context += client_context

            if ctx.get("requires_client") and not ctx.get("client_id"):
                dynamic_context += "\n⚠️ لم يتم اختيار عميل — ذكّر المستخدم باختيار العميل"
            if ctx.get("requires_file"):
                dynamic_context += "\n📎 هذه العملية تتطلب رفع ملف — وجّه المستخدم لذلك"
            if ctx.get("may_escalate"):
                dynamic_context += "\n🔴 موضوع حساس — قد يحتاج تصعيد لمختص"

            # Conversation summary for long conversations
            msg_count = len(conversation_history) if conversation_history else 0
            if msg_count > 6:
                dynamic_context += f"\n💬 عدد الرسائل السابقة: {msg_count} — ركز على آخر التطورات"

            system_prompt = COPILOT_SYSTEM_PROMPT + dynamic_context

            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1500,
                temperature=0.6,
                system=system_prompt,
                messages=messages,
            )

            ai_text = response.content[0].text.strip()

            # Append low-confidence warning only for very low confidence
            if confidence < 0.4:
                ai_text += "\n\n⚠️ لم أتمكن من فهم طلبك بدقة. يرجى إعادة صياغة سؤالك."

            return ai_text

        except Exception as e:
            logging.error("Copilot Claude API call failed, falling back to hardcoded responses: %s", e)
            return cls._generate_fallback_response(intent, confidence, ctx, user_message, conversation_history)

    @classmethod
    def _generate_fallback_response(cls, intent, confidence, ctx, user_message, conversation_history=None):
        """Fallback hardcoded responses when AI API is unavailable."""
        responses = {
            "financial_analysis": {
                "first": "يمكنني مساعدتك في التحليل المالي. الخطوات:\n1. رفع ميزان المراجعة (Excel)\n2. تحديد القطاع والفترة\n3. استعراض النسب والقوائم المالية\n\nهل تريد رفع ميزان المراجعة الآن؟",
                "follow_up": "نكمل التحليل المالي. هل تريد عرض النسب المالية أم القوائم؟",
            },
            "coa_workflow": {
                "first": "لنبدأ بشجرة الحسابات:\n1. ارفع الملف (CSV أو Excel)\n2. سأقوم بتحليل وتصنيف الحسابات تلقائياً\n3. راجع التصنيف واعتمده\n\nالملفات المدعومة: CSV, XLSX, XLS",
                "follow_up": "نكمل العمل على شجرة الحسابات. هل تريد رفع ملف جديد أم مراجعة التصنيف؟",
            },
            "tb_binding": {
                "first": "سأساعدك في ربط ميزان المراجعة بشجرة الحسابات.\n\nالمتطلبات:\n- شجرة حسابات معتمدة\n- ملف ميزان مراجعة (Excel)\n\nهل لديك شجرة حسابات معتمدة؟",
                "follow_up": "نكمل ربط الميزان. هل تريد عرض نتائج الربط أم تعديل المطابقة؟",
            },
            "funding_readiness": {
                "first": "سأقيّم جاهزية المنشأة للتمويل:\n- تحليل القوائم المالية\n- فحص النسب المطلوبة من جهات التمويل\n- تحديد الفجوات والتوصيات\n\n⚠️ النتائج استرشادية وليست ضماناً للحصول على تمويل.",
                "follow_up": "نكمل تقييم الجاهزية التمويلية. هل تريد عرض الفجوات أم تجهيز المستندات؟",
            },
            "compliance": {
                "first": "سأفحص الامتثال للأنظمة واللوائح:\n- ضريبة القيمة المضافة (VAT)\n- الزكاة (ZATCA)\n- نظام الشركات\n\n⚠️ النتائج استرشادية وتحتاج مراجعة مختص معتمد.",
                "follow_up": "نكمل فحص الامتثال. أي جانب تريد التركيز عليه؟",
            },
            "audit_review": {
                "first": "سأساعدك في المراجعة عبر 7 مراحل:\n1. تعريف شجرة الحسابات\n2. رفع ميزان المراجعة\n3. بناء برنامج المراجعة\n4. اختيار العينات\n5. تنفيذ الإجراءات\n6. التجميع والتقييم\n7. المخرجات النهائية\n\nمن أي مرحلة تريد البدء؟",
                "follow_up": "نكمل المراجعة. أي مرحلة تريد العمل عليها؟",
            },
            "knowledge_lookup": {
                "first": "سأبحث في قاعدة المعرفة المهنية:\n- معايير SOCPA السعودية\n- معايير IFRS الدولية\n- أنظمة ZATCA\n- نظام الشركات ولوائحه\n- معايير المراجعة ISA\n\nما الموضوع الذي تبحث عنه؟",
                "follow_up": "سأبحث لك. ما المعلومة التي تحتاجها؟",
            },
            "service_request": {
                "first": "يمكنني مساعدتك في طلب خدمة مهنية من سوق الخدمات:\n- مسك دفاتر\n- إعداد قوائم مالية\n- مراجعة ضريبية\n- دعم تدقيق\n\nما نوع الخدمة المطلوبة؟",
                "follow_up": "هل تريد طلب خدمة جديدة أم متابعة طلب قائم؟",
            },
            "explain_result": {
                "first": "سأشرح النتيجة بالتفصيل مع:\n- الأدلة والمستندات المستخدمة\n- القواعد والمعايير المطبقة\n- مستوى الثقة\n\nأي نتيجة تريد شرحها؟",
                "follow_up": "هل تريد تفسير نتيجة أخرى أم طلب مراجعة بشرية؟",
            },
            "account_management": {
                "first": "يمكنني مساعدتك في إدارة حسابك:\n- عرض/تعديل الملف الشخصي\n- إدارة الاشتراك والخطة\n- عرض سجل النشاط\n- تغيير كلمة المرور\n\nماذا تحتاج؟",
                "follow_up": "هل تحتاج مساعدة أخرى في حسابك؟",
            },
            "general": {
                "first": "مرحباً! أنا Apex Copilot — مساعدك الذكي في المنصة.\n\nيمكنني مساعدتك في:\n📊 التحليل المالي والنسب\n📋 شجرة الحسابات والتصنيف\n⚖️ الامتثال والزكاة والضريبة\n🔍 المراجعة والتدقيق\n💰 الجاهزية التمويلية\n📚 البحث في المعايير والأنظمة\n🛒 طلب خدمات مهنية\n\nكيف أساعدك اليوم؟",
                "follow_up": "هل تحتاج مساعدة في شيء آخر؟",
            },
        }

        is_follow_up = False
        if conversation_history:
            for msg in conversation_history:
                if msg.get("intent") == intent and msg.get("role") == "assistant":
                    is_follow_up = True
                    break

        intent_data = responses.get(intent, responses["general"])
        base = intent_data["follow_up"] if is_follow_up else intent_data["first"]

        if confidence < 0.5:
            base += "\n\n⚠️ لم أتمكن من فهم طلبك بدقة. يرجى توضيح ما تحتاجه."
        if ctx.get("requires_client") and not ctx.get("client_id"):
            base += "\n\n📋 لإكمال هذه العملية، يرجى اختيار العميل أولاً من قائمة العملاء."
        if ctx.get("requires_file"):
            base += "\n\n📎 ستحتاج لرفع ملف لإكمال هذه العملية."
        return base

    @classmethod
    def _get_references(cls, intent):
        ref_map = {
            "compliance": [
                {"source": "ZATCA", "type": "regulatory", "note": "هيئة الزكاة والضريبة والجمارك"},
                {"source": "VAT", "type": "law", "note": "نظام ضريبة القيمة المضافة"},
            ],
            "audit_review": [
                {"source": "ISA", "type": "standard", "note": "معايير المراجعة الدولية"},
                {"source": "SOCPA", "type": "standard", "note": "الهيئة السعودية للمراجعين والمحاسبين"},
            ],
            "financial_analysis": [
                {"source": "SOCPA", "type": "standard", "note": "معايير المحاسبة السعودية"},
                {"source": "IFRS", "type": "standard", "note": "المعايير الدولية لإعداد التقارير المالية"},
            ],
            "knowledge_lookup": [
                {"source": "MoC", "type": "regulatory", "note": "نظام الشركات - وزارة التجارة"},
                {"source": "SOCPA", "type": "standard", "note": "الهيئة السعودية للمراجعين والمحاسبين"},
            ],
            "funding_readiness": [
                {"source": "SAMA", "type": "regulatory", "note": "البنك المركزي السعودي"},
                {"source": "IFRS", "type": "standard", "note": "معايير العرض والإفصاح"},
            ],
        }
        return ref_map.get(intent, [])

    @staticmethod
    def _session_to_dict(session):
        return {
            "id": session.id,
            "user_id": session.user_id,
            "client_id": session.client_id,
            "session_type": session.session_type,
            "context": session.context or {},
            "status": session.status,
            "created_at": session.created_at.isoformat() if session.created_at else None,
        }

    @staticmethod
    def _message_to_dict(msg, next_actions=None):
        d = {
            "id": msg.id,
            "role": msg.role,
            "content": msg.content,
            "intent": msg.intent,
            "confidence": msg.confidence,
            "risk_level": msg.risk_level,
            "tools_used": msg.tools_used,
            "references": msg.references,
            "escalation": msg.escalation,
            "created_at": msg.created_at.isoformat() if msg.created_at else None,
        }
        if next_actions:
            d["next_actions"] = next_actions
        return d
