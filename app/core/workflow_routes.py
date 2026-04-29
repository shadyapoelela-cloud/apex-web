"""
APEX — Workflow Rules Engine HTTP routes.
==========================================
CRUD for workflow rules + manual trigger endpoint.

Endpoints (all admin-secret-gated):
    GET    /admin/workflow/rules                  — list
    GET    /admin/workflow/rules/{rule_id}        — get one
    POST   /admin/workflow/rules                  — create
    PATCH  /admin/workflow/rules/{rule_id}        — update
    DELETE /admin/workflow/rules/{rule_id}        — delete
    POST   /admin/workflow/rules/{rule_id}/run    — manual run with payload
    GET    /admin/workflow/stats                  — counts
    POST   /admin/workflow/validate-event         — event-name lookup

The Workflow Rule Builder UI uses these endpoints + the Event Catalog at
/api/v1/events/list (see app/core/event_routes.py).
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.workflow_engine import (
    create_rule,
    delete_rule,
    evaluate_conditions,
    execute_action,
    get_rule,
    list_rules,
    process_event,
    stats,
    update_rule,
    validate_event_name,
)

router = APIRouter(prefix="/admin/workflow", tags=["admin", "workflow"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x_admin_secret: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x_admin_secret or not secrets.compare_digest(x_admin_secret, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


class ConditionPayload(BaseModel):
    field: str
    operator: str
    value: Any
    case_sensitive: bool = True


class ActionPayload(BaseModel):
    type: str
    params: dict[str, Any] = Field(default_factory=dict)


class CreateRuleRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    event_pattern: str = Field(..., min_length=1)
    conditions: list[ConditionPayload] = Field(default_factory=list)
    actions: list[ActionPayload] = Field(default_factory=list)
    description_ar: Optional[str] = None
    owner_user_id: Optional[str] = None
    tenant_id: Optional[str] = None
    enabled: bool = True


class UpdateRuleRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    event_pattern: Optional[str] = None
    conditions: Optional[list[ConditionPayload]] = None
    actions: Optional[list[ActionPayload]] = None
    description_ar: Optional[str] = None
    enabled: Optional[bool] = None


class RunRuleRequest(BaseModel):
    payload: dict[str, Any] = Field(default_factory=dict)
    dry_run: bool = False  # if True, only evaluate conditions, don't execute actions


def _serialize(rule) -> dict:
    return {
        "id": rule.id,
        "name": rule.name,
        "event_pattern": rule.event_pattern,
        "conditions": [
            {
                "field": c.field,
                "operator": c.operator,
                "value": c.value,
                "case_sensitive": c.case_sensitive,
            }
            for c in rule.conditions
        ],
        "actions": [{"type": a.type, "params": a.params} for a in rule.actions],
        "enabled": rule.enabled,
        "description_ar": rule.description_ar,
        "owner_user_id": rule.owner_user_id,
        "tenant_id": rule.tenant_id,
        "created_at": rule.created_at,
        "updated_at": rule.updated_at,
        "run_count": rule.run_count,
        "last_run_at": rule.last_run_at,
        "last_error": rule.last_error,
    }


@router.get("/rules")
def list_rules_route(
    tenant_id: Optional[str] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rules = list_rules(tenant_id=tenant_id)
    return {"success": True, "rules": [_serialize(r) for r in rules], "count": len(rules)}


@router.get("/rules/{rule_id}")
def get_rule_route(
    rule_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    r = get_rule(rule_id)
    if not r:
        raise HTTPException(404, "Rule not found")
    return {"success": True, "rule": _serialize(r)}


@router.post("/rules", status_code=201)
def create_rule_route(
    payload: CreateRuleRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rule = create_rule(
        name=payload.name,
        event_pattern=payload.event_pattern,
        conditions=[c.model_dump() for c in payload.conditions],
        actions=[a.model_dump() for a in payload.actions],
        description_ar=payload.description_ar,
        owner_user_id=payload.owner_user_id,
        tenant_id=payload.tenant_id,
        enabled=payload.enabled,
    )
    return {"success": True, "rule": _serialize(rule)}


@router.patch("/rules/{rule_id}")
def update_rule_route(
    rule_id: str,
    payload: UpdateRuleRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    changes = {k: v for k, v in payload.model_dump(exclude_unset=True).items()}
    # Convert nested objects into dicts the engine expects.
    if "conditions" in changes and changes["conditions"] is not None:
        changes["conditions"] = [c for c in changes["conditions"]]  # already dicts
    if "actions" in changes and changes["actions"] is not None:
        changes["actions"] = [a for a in changes["actions"]]
    rule = update_rule(rule_id, **changes)
    if not rule:
        raise HTTPException(404, "Rule not found")
    return {"success": True, "rule": _serialize(rule)}


@router.delete("/rules/{rule_id}")
def delete_rule_route(
    rule_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    ok = delete_rule(rule_id)
    if not ok:
        raise HTTPException(404, "Rule not found")
    return {"success": True}


@router.post("/rules/{rule_id}/run")
def run_rule_route(
    rule_id: str,
    payload: RunRuleRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Manually run a single rule against a hypothetical payload. Useful for testing."""
    _verify_admin(x_admin_secret)
    rule = get_rule(rule_id)
    if not rule:
        raise HTTPException(404, "Rule not found")
    matched = evaluate_conditions(rule, payload.payload)
    response: dict[str, Any] = {
        "success": True,
        "matched": matched,
        "dry_run": payload.dry_run,
    }
    if matched and not payload.dry_run:
        response["action_results"] = [
            execute_action(a, payload.payload, rule) for a in rule.actions
        ]
    return response


@router.post("/process-event")
def process_event_route(
    payload: dict[str, Any],
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Process a synthetic event through the engine. Equivalent to emit() but bypasses event bus."""
    _verify_admin(x_admin_secret)
    name = payload.get("name")
    body = payload.get("payload") or {}
    if not name:
        raise HTTPException(400, "Missing 'name'")
    return {"success": True, "results": process_event(name, body)}


@router.get("/stats")
def stats_route(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.post("/validate-event")
def validate_event_route(
    payload: dict,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    name = payload.get("name") or ""
    return {"success": True, **validate_event_name(name)}
