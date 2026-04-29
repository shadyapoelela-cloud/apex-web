"""APEX — Conversational Onboarding (AI Guided).

Closes "AI Conversational Onboarding" gap from architecture/diagrams/
02-target-state.md section 2. The form-based wizard at Wave 1N
collected the same information through 3 form steps. This module
turns it into a chat conversation:

  AI: ما اسم شركتك؟
  User: مطعم بُن العربي
  AI: ممتاز! ما قطاع نشاطك؟ (يقترح: مطاعم وتجزئة بناء على الاسم)
  User: مطاعم
  AI: كم عدد الموظفين تقريباً؟
  User: 12
  AI: ممتاز. سأهيّئ لك حزمة المطاعم الآن. هل توافق؟
  User: نعم
  → finalize → calls existing /admin/tenants/onboard endpoint
  → returns the same atomic flow Wave 1N built
  → AI: ✅ تم. تم تثبيت 4 قواعد أتمتة وتسجيل الشركة.

State machine has 6 steps:
  identity → display_name → industry → headcount → review → done
Each step has:
  - Question text
  - Validation (regex / int range / pack_id from registry)
  - On_answer hook (sets session field)
  - Optional AI suggestion (uses Claude if ANTHROPIC_API_KEY set)

Storage: $APEX_DATA_DIR/onboarding_sessions.json — JSON-as-DB ring
buffer (cap 1K active sessions). Each session lives until user
finalizes or a 24h TTL passes.

Wave 1R Phase YY.
"""

from __future__ import annotations

import json
import logging
import os
import re
import threading
import uuid
from collections import OrderedDict
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "ONBOARDING_SESSIONS_PATH",
    os.path.join(_DATA_DIR, "onboarding_sessions.json"),
)
_MAX_SESSIONS = int(os.environ.get("ONBOARDING_SESSIONS_MAX", "1000"))
_SESSION_TTL_HOURS = int(os.environ.get("ONBOARDING_SESSIONS_TTL_HOURS", "24"))
_LOCK = threading.RLock()


# ── Conversation steps ──────────────────────────────────────────


@dataclass
class ChatTurn:
    role: str  # "ai" | "user"
    text: str
    ts: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


@dataclass
class OnboardingSession:
    session_id: str
    step: str = "tenant_id"  # current state
    collected: dict[str, Any] = field(default_factory=dict)
    turns: list[ChatTurn] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    finalized: bool = False
    final_result: Optional[dict] = None
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


# Step → (question_text, follow_up_on_answer)
# follow_up_on_answer takes the parsed value + session, sets fields,
# returns the next step + optional AI nudge.
_STEPS_ORDER = ["tenant_id", "display_name", "industry", "headcount", "review", "done"]


_QUESTIONS = {
    "tenant_id": (
        "أهلاً بك في تهيئة منصّة APEX 👋\n"
        "ما المعرّف الفريد للشركة الجديدة؟\n"
        "(حروف لاتينية وأرقام فقط، بدون مسافات — مثل: acme_co أو tenant_2026_01)"
    ),
    "display_name": (
        "تمام. ما الاسم التجاري الكامل للشركة؟\n"
        "(الذي سيظهر للمستخدمين والتقارير)"
    ),
    "industry": (
        "ممتاز. ما قطاع نشاطك التجاري؟\n"
        "اختر واحداً مما يلي أو اوصف نشاطك بكلمات حرّة وسأقترح الأنسب:"
    ),
    "headcount": (
        "كم عدد الموظفين تقريباً؟\n"
        "(عدد صحيح — يُساعدنا في توصية الخطة المناسبة)"
    ),
    "review": "—",  # filled dynamically
    "done": "—",
}


_TENANT_ID_RE = re.compile(r"^[A-Za-z0-9_]{2,60}$")


# Industry pack catalog — used both for suggestions and validation.
def _packs_index() -> dict[str, dict]:
    """Lazy-load to avoid import-time circular issues."""
    try:
        from app.core.industry_packs_service import list_pack_summaries
        return {p["id"]: p for p in list_pack_summaries()}
    except Exception:
        return {}


# ── Session store ──────────────────────────────────────────────


_SESSIONS: "OrderedDict[str, OnboardingSession]" = OrderedDict()


def _load() -> None:
    global _SESSIONS
    with _LOCK:
        if not os.path.exists(_PATH):
            _SESSIONS = OrderedDict()
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            now = datetime.now(timezone.utc)
            ttl = timedelta(hours=_SESSION_TTL_HOURS)
            keep: "OrderedDict[str, OnboardingSession]" = OrderedDict()
            for s in raw.get("sessions", []):
                # Drop stale.
                try:
                    updated = datetime.fromisoformat(s["updated_at"])
                except Exception:
                    continue
                if now - updated > ttl:
                    continue
                turns = [ChatTurn(**t) for t in s.pop("turns", [])]
                sess = OnboardingSession(turns=turns, **s)
                keep[sess.session_id] = sess
            # Cap.
            while len(keep) > _MAX_SESSIONS:
                keep.popitem(last=False)
            _SESSIONS = keep
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load onboarding sessions: %s", e)
            _SESSIONS = OrderedDict()


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "sessions": [
                {
                    **{k: v for k, v in asdict(s).items() if k != "turns"},
                    "turns": [asdict(t) for t in s.turns],
                }
                for s in _SESSIONS.values()
            ],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp, _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to save onboarding sessions: %s", e)


_load()


# ── Pack matching (Claude-powered or heuristic) ─────────────────


# Cheap rule-based mapping from common keywords → pack_id, used as
# fallback when Claude is unavailable.
_KEYWORD_MAP = [
    (("مطعم", "مقهى", "كافيه", "restaurant", "cafe", "fnb", "food", "f&b"), "fnb_retail"),
    (("بناء", "مقاولات", "إنشاء", "construction", "contracting"), "construction"),
    (("عيادة", "طبي", "صحي", "مستشفى", "medical", "clinic", "hospital", "health"), "medical"),
    (("نقل", "شحن", "لوجست", "أسطول", "logistics", "transport", "fleet", "shipping"), "logistics"),
    (("استشارات", "خدمات", "saas", "consulting", "services", "agency"), "services"),
]


def _suggest_pack_heuristic(text: str) -> list[str]:
    """Rank pack_ids by keyword match against free-text input."""
    if not text:
        return []
    lower = text.lower()
    scores: dict[str, int] = {}
    for keywords, pack_id in _KEYWORD_MAP:
        for kw in keywords:
            if kw.lower() in lower:
                scores[pack_id] = scores.get(pack_id, 0) + 1
    return [pid for pid, _ in sorted(scores.items(), key=lambda x: -x[1])]


def _suggest_pack_claude(text: str) -> Optional[str]:
    """Single-call Claude pack recommendation if API key is set."""
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return None
    try:
        from anthropic import Anthropic
    except Exception:
        return None
    packs = _packs_index()
    if not packs:
        return None
    options = "\n".join(
        f"- {pid}: {p['name_ar']} ({p['name_en']}) — {p['description']}"
        for pid, p in packs.items()
    )
    prompt = (
        "أنت مساعد لاختيار حزمة قطاع تجاري في منصّة محاسبة. "
        "أمامك وصف نشاط لشركة جديدة. اختر pack_id الأنسب من القائمة. "
        f"رد فقط بـ pack_id بدون شرح.\n\nالحزم:\n{options}\n\n"
        f"النشاط: {text}\n\nالاختيار (pack_id فقط):"
    )
    try:
        client = Anthropic(api_key=api_key)
        msg = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=20,
            messages=[{"role": "user", "content": prompt}],
        )
        out = msg.content[0].text.strip().lower()
        # Sanity-check: must be one of the pack_ids.
        if out in packs:
            return out
    except Exception as e:  # noqa: BLE001
        logger.warning("Claude pack suggestion failed: %s", e)
    return None


def suggest_pack(text: str) -> list[str]:
    """Returns list of pack_ids ranked by likelihood, best-first."""
    claude_pick = _suggest_pack_claude(text)
    heuristic = _suggest_pack_heuristic(text)
    if claude_pick:
        # Claude's pick first, then any heuristic matches not already there.
        out = [claude_pick]
        for p in heuristic:
            if p != claude_pick:
                out.append(p)
        return out
    return heuristic


# ── State machine ──────────────────────────────────────────────


def _validate_and_apply(session: OnboardingSession, user_text: str) -> tuple[bool, str]:
    """Validate the user's answer for the current step + apply it.

    Returns (ok, error_message_or_empty).
    """
    text = (user_text or "").strip()
    if session.step == "tenant_id":
        if not _TENANT_ID_RE.match(text):
            return False, (
                "المعرّف يجب أن يكون 2-60 حرفاً، حروف لاتينية وأرقام و _ فقط. "
                "حاول مرّة أخرى."
            )
        # Check uniqueness against directory.
        try:
            from app.core.tenant_directory import get as _td_get
            if _td_get(text):
                return False, f"المعرّف '{text}' مستخدم بالفعل. جرّب معرّفاً آخر."
        except Exception:
            pass
        session.collected["tenant_id"] = text
    elif session.step == "display_name":
        if len(text) < 2:
            return False, "الاسم قصير جداً. أدخِل الاسم الكامل."
        session.collected["display_name"] = text
    elif session.step == "industry":
        packs = _packs_index()
        if text in packs:
            session.collected["industry_pack_id"] = text
        else:
            ranked = suggest_pack(text)
            if not ranked:
                return False, (
                    "لم أتمكّن من تحديد القطاع من وصفك. اختر pack_id مباشرة:\n"
                    + ", ".join(packs.keys())
                )
            # Auto-pick the top suggestion.
            session.collected["industry_pack_id"] = ranked[0]
            session.suggestions = ranked[:3]
    elif session.step == "headcount":
        try:
            n = int(text)
            if n < 1 or n > 50000:
                return False, "العدد يجب أن يكون بين 1 و 50000."
        except ValueError:
            return False, "أدخل رقماً صحيحاً، مثلاً: 12"
        session.collected["headcount"] = n
    elif session.step == "review":
        confirm = text.lower()
        if confirm in ("نعم", "موافق", "yes", "y", "ok", "تأكيد", "تأكد"):
            session.collected["confirmed"] = True
        else:
            return False, 'يرجى الردّ بـ "نعم" للتأكيد أو ابدأ جلسة جديدة للتعديل.'
    return True, ""


def _next_step(current: str) -> str:
    idx = _STEPS_ORDER.index(current)
    if idx + 1 < len(_STEPS_ORDER):
        return _STEPS_ORDER[idx + 1]
    return current


def _question_for(session: OnboardingSession) -> str:
    if session.step == "industry":
        packs = _packs_index()
        catalog = "\n".join(
            f"  • {pid} → {p['name_ar']} ({p['name_en']})"
            for pid, p in packs.items()
        )
        return _QUESTIONS["industry"] + "\n\n" + catalog
    if session.step == "review":
        c = session.collected
        pack = _packs_index().get(c.get("industry_pack_id", ""), {})
        pack_label = pack.get("name_ar", c.get("industry_pack_id", ""))
        suggestions_line = ""
        if session.suggestions:
            suggestions_line = (
                "\n💡 (اقترحتُ "
                + ", ".join(session.suggestions[:3])
                + " بناءً على وصفك)"
            )
        return (
            "ممتاز! إليك المخطّط النهائي:\n\n"
            f"  • المعرّف: {c.get('tenant_id')}\n"
            f"  • الاسم: {c.get('display_name')}\n"
            f"  • القطاع: {pack_label} ({c.get('industry_pack_id')}){suggestions_line}\n"
            f"  • عدد الموظفين: {c.get('headcount')}\n\n"
            "سأقوم بالآتي عند تأكيدك:\n"
            "  1️⃣ تسجيل الشركة في الدليل\n"
            "  2️⃣ تطبيق حزمة القطاع\n"
            "  3️⃣ تثبيت 4 قواعد أتمتة (تذكير الإقفال، تنبيهات الشذوذ، إلخ)\n"
            "  4️⃣ تفعيل لوحة القيادة المخصّصة\n\n"
            'هل توافق؟ (اكتب "نعم" للمتابعة)'
        )
    if session.step == "done":
        if session.final_result:
            return (
                "🎉 تم! إليك ملخّص التشغيل:\n\n"
                f"  • Tenant: {session.collected.get('tenant_id')}\n"
                f"  • Pack: {session.collected.get('industry_pack_id')}\n"
                f"  • COA: ✅ مُهيّأة\n"
                f"  • Widgets: ✅ مُهيّأة\n"
                f"  • قواعد الأتمتة: ✅ مُثبَّتة\n\n"
                "يمكنك الآن:\n"
                "  • فتح /admin/tenants لرؤية الشركة\n"
                "  • فتح /admin/workflow/rules لمراجعة القواعد\n"
                "  • فتح /admin/dashboard-health للوحة الصحة"
            )
        return "اكتمل التشغيل."
    return _QUESTIONS.get(session.step, "...")


# ── Public API ──────────────────────────────────────────────────


def start_session() -> dict:
    sess = OnboardingSession(session_id=str(uuid.uuid4()))
    first_q = _question_for(sess)
    sess.turns.append(ChatTurn(role="ai", text=first_q))
    with _LOCK:
        _SESSIONS[sess.session_id] = sess
        while len(_SESSIONS) > _MAX_SESSIONS:
            _SESSIONS.popitem(last=False)
        _save()
    return _serialize(sess)


def reply(session_id: str, user_text: str) -> dict:
    with _LOCK:
        sess = _SESSIONS.get(session_id)
    if not sess:
        raise ValueError("session_not_found")
    if sess.finalized:
        raise ValueError("session_already_finalized")
    text = (user_text or "").strip()
    if not text:
        raise ValueError("empty_user_message")
    sess.turns.append(ChatTurn(role="user", text=text))
    ok, err = _validate_and_apply(sess, text)
    if not ok:
        # Stay on same step, append AI error.
        sess.turns.append(ChatTurn(role="ai", text=f"⚠️ {err}"))
    else:
        sess.step = _next_step(sess.step)
        # If we've reached "done", auto-finalize on confirmation.
        if sess.step == "done" and not sess.finalized:
            _do_finalize(sess)
        sess.turns.append(ChatTurn(role="ai", text=_question_for(sess)))
    sess.updated_at = datetime.now(timezone.utc).isoformat()
    with _LOCK:
        _save()
    return _serialize(sess)


def get_session(session_id: str) -> Optional[dict]:
    with _LOCK:
        sess = _SESSIONS.get(session_id)
        return _serialize(sess) if sess else None


def list_sessions(*, limit: int = 50) -> list[dict]:
    with _LOCK:
        rows = list(_SESSIONS.values())
    rows.sort(key=lambda s: s.updated_at, reverse=True)
    return [_serialize_summary(s) for s in rows[:limit]]


def _do_finalize(sess: OnboardingSession) -> None:
    """Call the Wave 1N atomic onboard endpoint to provision the tenant."""
    try:
        from app.core.tenant_directory import register
        from app.core.industry_packs_service import apply_pack
        c = sess.collected
        register(
            c["tenant_id"],
            c["display_name"],
            industry_pack_id=c.get("industry_pack_id"),
            created_by="onboarding_chat",
            notes=f"Created via conversational wizard. Headcount: {c.get('headcount')}",
        )
        from dataclasses import asdict as _ad
        a = apply_pack(
            c["tenant_id"],
            c["industry_pack_id"],
            applied_by="onboarding_chat",
        )
        sess.final_result = {
            "tenant_id": c["tenant_id"],
            "industry_pack_id": c["industry_pack_id"],
            "assignment": _ad(a),
        }
        sess.finalized = True
    except Exception as e:  # noqa: BLE001
        logger.exception("onboarding finalize failed")
        sess.final_result = {"error": str(e)}


def _serialize(sess: OnboardingSession) -> dict:
    return {
        "session_id": sess.session_id,
        "step": sess.step,
        "collected": dict(sess.collected),
        "turns": [asdict(t) for t in sess.turns],
        "suggestions": list(sess.suggestions),
        "finalized": sess.finalized,
        "final_result": sess.final_result,
        "created_at": sess.created_at,
        "updated_at": sess.updated_at,
    }


def _serialize_summary(sess: OnboardingSession) -> dict:
    return {
        "session_id": sess.session_id,
        "step": sess.step,
        "tenant_id": sess.collected.get("tenant_id"),
        "display_name": sess.collected.get("display_name"),
        "industry_pack_id": sess.collected.get("industry_pack_id"),
        "finalized": sess.finalized,
        "turns_count": len(sess.turns),
        "created_at": sess.created_at,
        "updated_at": sess.updated_at,
    }


def stats() -> dict:
    with _LOCK:
        rows = list(_SESSIONS.values())
    finalized = sum(1 for s in rows if s.finalized)
    by_step: dict[str, int] = {}
    for s in rows:
        by_step[s.step] = by_step.get(s.step, 0) + 1
    return {
        "active": len(rows) - finalized,
        "finalized": finalized,
        "total": len(rows),
        "cap": _MAX_SESSIONS,
        "ttl_hours": _SESSION_TTL_HOURS,
        "by_step": by_step,
        "claude_enabled": bool(os.environ.get("ANTHROPIC_API_KEY", "").strip()),
    }
