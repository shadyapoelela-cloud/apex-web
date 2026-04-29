"""
APEX — Workflow Rules Engine (MVP)
====================================
"If THIS event matches THESE conditions, THEN execute THESE actions."

This is the platform's no-code automation primitive. Rule authors compose
event triggers + conditions + actions through a UI; the engine evaluates
synchronously when matching events fire on the in-process Event Bus.

Architecture:
    Event Bus    →    Rules Engine listener (registered globally)
                       ↓
                       For each enabled rule:
                          1. event_pattern matches?  (e.g. "invoice.*")
                          2. all conditions true?    (AND-by-default)
                          3. execute every action; capture per-action result
                          4. log a WorkflowExecution audit row

Storage: JSON file at $WORKFLOW_RULES_PATH (default workflow_rules.json).
This is intentional MVP — replace with a SQLAlchemy model + Alembic
migration once the rule-builder UI is live (post-Wave 3).

Conditions:
    field           dotted path into payload, e.g. "amount" or "client.name_ar"
    operator        eq | ne | gt | gte | lt | lte | contains | starts_with | in
    value           literal to compare against (numbers cast automatically)
    case_sensitive  default True for string ops; can opt out

Actions (MVP set):
    notify          emit in-app notification to user_id
    slack           send to configured SLACK_WEBHOOK_URL
    teams           send to configured TEAMS_WEBHOOK_URL
    email           send_email() to a literal address (or payload.email)
    webhook         POST a JSON body to an external URL
    log             write a structured log line (testing aid)

References: architecture/diagrams/02-target-state.md §6 (Workflow Engine target).
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.event_bus import register_listener
from app.core.event_registry import is_known_event

logger = logging.getLogger(__name__)

# ── Storage path ──
_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_RULES_FILE = os.environ.get(
    "WORKFLOW_RULES_PATH", os.path.join(_DATA_DIR, "workflow_rules.json")
)

_LOCK = threading.RLock()


# ── Models ────────────────────────────────────────────────────────


@dataclass
class Condition:
    field: str  # dotted path into payload
    operator: str  # eq | ne | gt | gte | lt | lte | contains | starts_with | in
    value: Any
    case_sensitive: bool = True


@dataclass
class Action:
    type: str  # notify | slack | teams | email | webhook | log
    params: dict[str, Any] = field(default_factory=dict)


@dataclass
class WorkflowRule:
    id: str
    name: str
    event_pattern: str  # exact event name OR "namespace.*" OR "*"
    conditions: list[Condition] = field(default_factory=list)
    actions: list[Action] = field(default_factory=list)
    enabled: bool = True
    description_ar: Optional[str] = None
    owner_user_id: Optional[str] = None
    tenant_id: Optional[str] = None  # if set, scopes the rule to one tenant
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    run_count: int = 0
    last_run_at: Optional[str] = None
    last_error: Optional[str] = None


# ── In-memory store + JSON persistence ─────────────────────────────


_RULES: dict[str, WorkflowRule] = {}


def _serialize(r: WorkflowRule) -> dict:
    d = asdict(r)
    return d


def _deserialize(d: dict) -> WorkflowRule:
    conds = [Condition(**c) for c in d.get("conditions", [])]
    acts = [Action(**a) for a in d.get("actions", [])]
    return WorkflowRule(
        id=d["id"],
        name=d["name"],
        event_pattern=d["event_pattern"],
        conditions=conds,
        actions=acts,
        enabled=d.get("enabled", True),
        description_ar=d.get("description_ar"),
        owner_user_id=d.get("owner_user_id"),
        tenant_id=d.get("tenant_id"),
        created_at=d.get("created_at", datetime.now(timezone.utc).isoformat()),
        updated_at=d.get("updated_at", datetime.now(timezone.utc).isoformat()),
        run_count=d.get("run_count", 0),
        last_run_at=d.get("last_run_at"),
        last_error=d.get("last_error"),
    )


def _load() -> None:
    """Load rules from disk into memory. Safe to call multiple times."""
    global _RULES
    with _LOCK:
        if not os.path.exists(_RULES_FILE):
            _RULES = {}
            return
        try:
            with open(_RULES_FILE, encoding="utf-8") as f:
                raw = json.load(f)
            _RULES = {r["id"]: _deserialize(r) for r in raw.get("rules", [])}
            logger.info("Workflow engine loaded %d rules from %s", len(_RULES), _RULES_FILE)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load workflow rules from %s: %s", _RULES_FILE, e)
            _RULES = {}


def _save() -> None:
    """Persist current rules to disk atomically."""
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "rules": [_serialize(r) for r in _RULES.values()],
        }
        tmp = _RULES_FILE + ".tmp"
        os.makedirs(os.path.dirname(_RULES_FILE) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _RULES_FILE)


# ── CRUD ────────────────────────────────────────────────────────


def list_rules(tenant_id: Optional[str] = None) -> list[WorkflowRule]:
    with _LOCK:
        rs = list(_RULES.values())
    if tenant_id is not None:
        rs = [r for r in rs if r.tenant_id is None or r.tenant_id == tenant_id]
    return rs


def get_rule(rule_id: str) -> Optional[WorkflowRule]:
    with _LOCK:
        return _RULES.get(rule_id)


def create_rule(
    name: str,
    event_pattern: str,
    conditions: Optional[list[dict]] = None,
    actions: Optional[list[dict]] = None,
    description_ar: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    enabled: bool = True,
) -> WorkflowRule:
    rule = WorkflowRule(
        id=str(uuid.uuid4()),
        name=name,
        event_pattern=event_pattern,
        conditions=[Condition(**c) for c in (conditions or [])],
        actions=[Action(**a) for a in (actions or [])],
        enabled=enabled,
        description_ar=description_ar,
        owner_user_id=owner_user_id,
        tenant_id=tenant_id,
    )
    with _LOCK:
        _RULES[rule.id] = rule
        _save()
    return rule


def update_rule(rule_id: str, **changes) -> Optional[WorkflowRule]:
    with _LOCK:
        rule = _RULES.get(rule_id)
        if not rule:
            return None
        for k, v in changes.items():
            if k == "conditions" and isinstance(v, list):
                rule.conditions = [Condition(**c) if isinstance(c, dict) else c for c in v]
            elif k == "actions" and isinstance(v, list):
                rule.actions = [Action(**a) if isinstance(a, dict) else a for a in v]
            elif hasattr(rule, k):
                setattr(rule, k, v)
        rule.updated_at = datetime.now(timezone.utc).isoformat()
        _save()
        return rule


def delete_rule(rule_id: str) -> bool:
    with _LOCK:
        if rule_id not in _RULES:
            return False
        del _RULES[rule_id]
        _save()
        return True


# ── Evaluation ────────────────────────────────────────────────────


def _resolve_path(payload: dict, path: str) -> Any:
    """Walk a dotted path; returns None if any segment is missing."""
    cur: Any = payload
    for part in path.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur


def _to_number(v: Any) -> Optional[float]:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def evaluate_condition(cond: Condition, payload: dict) -> bool:
    actual = _resolve_path(payload, cond.field)
    expected = cond.value
    op = cond.operator

    # Equality
    if op == "eq":
        return actual == expected
    if op == "ne":
        return actual != expected

    # Numeric comparisons (cast both sides)
    if op in ("gt", "gte", "lt", "lte"):
        a = _to_number(actual)
        b = _to_number(expected)
        if a is None or b is None:
            return False
        if op == "gt":
            return a > b
        if op == "gte":
            return a >= b
        if op == "lt":
            return a < b
        return a <= b  # lte

    # String ops
    if op in ("contains", "starts_with", "ends_with"):
        a_str = "" if actual is None else str(actual)
        b_str = "" if expected is None else str(expected)
        if not cond.case_sensitive:
            a_str = a_str.lower()
            b_str = b_str.lower()
        if op == "contains":
            return b_str in a_str
        if op == "starts_with":
            return a_str.startswith(b_str)
        return a_str.endswith(b_str)

    # Membership
    if op == "in":
        if isinstance(expected, (list, tuple, set)):
            return actual in expected
        return False

    logger.warning("Unknown condition operator: %s", op)
    return False


def evaluate_conditions(rule: WorkflowRule, payload: dict) -> bool:
    """All conditions must hold (AND). Empty conditions = always true."""
    return all(evaluate_condition(c, payload) for c in rule.conditions)


# ── Action execution ──────────────────────────────────────────────


def _resolve_template(s: str, payload: dict) -> str:
    """Tiny template: replace {payload.field.path} with resolved value."""
    if not isinstance(s, str):
        return s
    out = s
    # Naïve replacement; good enough for MVP. Production should use a real templater.
    import re

    def _repl(m: "re.Match") -> str:
        path = m.group(1)
        if path.startswith("payload."):
            v = _resolve_path(payload, path[len("payload.") :])
        else:
            v = _resolve_path(payload, path)
        return "" if v is None else str(v)

    return re.sub(r"\{([a-zA-Z0-9_.]+)\}", _repl, out)


def execute_action(action: Action, payload: dict, rule: WorkflowRule) -> dict:
    """Run a single action; return a result dict for audit."""
    p = action.params or {}
    typ = action.type

    try:
        if typ == "log":
            msg = _resolve_template(p.get("message", "rule fired"), payload)
            logger.info("[workflow:%s] %s", rule.name, msg)
            return {"action": typ, "ok": True, "message": msg}

        if typ == "slack":
            from app.core.slack_backend import send_slack_notification

            return {
                "action": typ,
                **send_slack_notification(
                    title=_resolve_template(p.get("title", f"Rule: {rule.name}"), payload),
                    body=_resolve_template(p.get("body") or "", payload),
                    url=_resolve_template(p.get("url") or "", payload) or None,
                    severity=p.get("severity", "info"),
                ),
            }

        if typ == "teams":
            from app.core.teams_backend import send_teams_notification

            return {
                "action": typ,
                **send_teams_notification(
                    title=_resolve_template(p.get("title", f"Rule: {rule.name}"), payload),
                    body=_resolve_template(p.get("body") or "", payload),
                    url=_resolve_template(p.get("url") or "", payload) or None,
                    severity=p.get("severity", "info"),
                ),
            }

        if typ == "email":
            from app.core.email_service import send_email

            to = _resolve_template(p.get("to", ""), payload) or ""
            if not to:
                return {"action": typ, "ok": False, "error": "missing_to"}
            res = send_email(
                to=to,
                subject=_resolve_template(p.get("subject", f"APEX: {rule.name}"), payload),
                body_html=_resolve_template(p.get("body_html") or "", payload),
                body_text=_resolve_template(p.get("body_text") or "", payload),
            )
            return {"action": typ, **res}

        if typ == "notify":
            from app.phase10.services.notification_service import emit_notification

            user_id = _resolve_template(p.get("user_id", ""), payload)
            if not user_id:
                return {"action": typ, "ok": False, "error": "missing_user_id"}
            ntype = p.get("notification_type", "task_assigned")
            res = emit_notification(
                user_id=user_id,
                notification_type=ntype,
                body_ar=_resolve_template(p.get("body_ar"), payload) if p.get("body_ar") else None,
                body_en=_resolve_template(p.get("body_en"), payload) if p.get("body_en") else None,
                action_url=_resolve_template(p.get("action_url"), payload) if p.get("action_url") else None,
            )
            return {"action": typ, **res}

        if typ == "webhook":
            try:
                import requests
            except ImportError:
                return {"action": typ, "ok": False, "error": "requests_missing"}
            url = _resolve_template(p.get("url", ""), payload)
            if not url:
                return {"action": typ, "ok": False, "error": "missing_url"}
            try:
                resp = requests.post(
                    url,
                    json={
                        "rule": rule.name,
                        "rule_id": rule.id,
                        "payload": payload,
                    },
                    timeout=p.get("timeout", 10),
                )
                return {
                    "action": typ,
                    "ok": resp.status_code < 400,
                    "status": resp.status_code,
                }
            except Exception as e:  # noqa: BLE001
                return {"action": typ, "ok": False, "error": str(e)}

        if typ == "approval":
            # Multi-level approval chain.
            # params: {
            #   "approver_user_ids": ["uid1","uid2",...],
            #   "title_ar": "...",
            #   "title_en": "...",   (optional)
            #   "body": "...",        (optional, supports {payload.field})
            #   "object_type": "invoice"|"bill"|...,  (optional)
            #   "object_id_field": "invoice_id",       (path into payload)
            # }
            try:
                from app.core.approvals import create_approval
            except Exception as e:
                return {"action": typ, "ok": False, "error": f"approvals_unavailable:{e}"}

            approvers = p.get("approver_user_ids") or []
            # Allow templated single approver: "approver_user_id_field": "..."
            if not approvers and p.get("approver_user_id_field"):
                u = _resolve_path(payload, p["approver_user_id_field"])
                if u:
                    approvers = [u]
            if not approvers:
                return {"action": typ, "ok": False, "error": "missing_approver_user_ids"}

            obj_id_field = p.get("object_id_field")
            obj_id = (
                _resolve_path(payload, obj_id_field) if obj_id_field else None
            )
            try:
                a = create_approval(
                    title_ar=_resolve_template(
                        p.get("title_ar", f"موافقة مطلوبة: {rule.name}"), payload
                    ),
                    title_en=_resolve_template(p.get("title_en") or "", payload) or None,
                    body=_resolve_template(p.get("body") or "", payload) or None,
                    object_type=p.get("object_type"),
                    object_id=str(obj_id) if obj_id else None,
                    requested_by=payload.get("requested_by"),
                    rule_id=rule.id,
                    tenant_id=payload.get("tenant_id"),
                    approver_user_ids=approvers,
                    meta={"trigger_payload": payload},
                )
                return {"action": typ, "ok": True, "approval_id": a.id}
            except Exception as e:  # noqa: BLE001
                return {"action": typ, "ok": False, "error": str(e)}

        logger.warning("Unknown action type: %s (rule %s)", typ, rule.name)
        return {"action": typ, "ok": False, "error": f"unknown_action:{typ}"}

    except Exception as e:  # noqa: BLE001
        logger.exception("Action %s failed in rule %s: %s", typ, rule.name, e)
        return {"action": typ, "ok": False, "error": str(e)}


# ── Engine listener (registered at import) ─────────────────────────


def _matches_pattern(pattern: str, name: str) -> bool:
    if pattern == "*":
        return True
    if pattern == name:
        return True
    if pattern.endswith(".*"):
        return name.startswith(pattern[:-2] + ".")
    return False


def process_event(event_name: str, payload: dict) -> list[dict]:
    """Find every matching enabled rule and execute. Returns audit results."""
    results: list[dict] = []
    with _LOCK:
        rules = list(_RULES.values())

    for rule in rules:
        if not rule.enabled:
            continue
        if not _matches_pattern(rule.event_pattern, event_name):
            continue
        # Tenant scoping (best-effort): if rule is tenant-scoped, payload
        # must carry tenant_id matching it.
        if rule.tenant_id and payload.get("tenant_id") != rule.tenant_id:
            continue

        if not evaluate_conditions(rule, payload):
            continue

        # Execute actions sequentially.
        action_results = [execute_action(a, payload, rule) for a in rule.actions]

        with _LOCK:
            rule.run_count += 1
            rule.last_run_at = datetime.now(timezone.utc).isoformat()
            failed = [r for r in action_results if not r.get("ok") and not r.get("success")]
            rule.last_error = (
                None
                if not failed
                else "; ".join(str(f.get("error", "unknown")) for f in failed[:3])
            )
            _save()

        results.append(
            {
                "rule_id": rule.id,
                "rule_name": rule.name,
                "event": event_name,
                "actions": action_results,
            }
        )

    return results


@register_listener("*")
def _global_listener(event_name: str, payload: dict) -> None:
    """Bridges every event into the rules engine."""
    process_event(event_name, payload)


# Initial load on import.
_load()


# ── Helpers exposed for routes ─────────────────────────────────────


def stats() -> dict:
    with _LOCK:
        active = sum(1 for r in _RULES.values() if r.enabled)
        return {
            "rules_total": len(_RULES),
            "rules_enabled": active,
            "rules_disabled": len(_RULES) - active,
            "storage_path": _RULES_FILE,
        }


def validate_event_name(name: str) -> dict:
    """Return {known: bool, pattern_ok: bool} for UI hints."""
    if name in ("*",) or name.endswith(".*"):
        return {"known": True, "pattern_ok": True, "kind": "wildcard"}
    return {"known": is_known_event(name), "pattern_ok": True, "kind": "exact"}
