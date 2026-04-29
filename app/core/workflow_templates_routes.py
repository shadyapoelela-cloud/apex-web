"""
APEX — Workflow Templates HTTP routes.
=======================================
Browse the templates catalog + install a chosen template as an actual rule.

Endpoints:
    GET  /admin/workflow/templates                  — list all templates
    GET  /admin/workflow/templates?category=alerts  — filter by category
    GET  /admin/workflow/templates/{id}             — get one (with params)
    POST /admin/workflow/templates/{id}/install     — instantiate as a rule
        body: {"parameter_values": {"cfo_user_id": "uid_xxx", "threshold": 75000}}
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.workflow_engine import create_rule
from app.core.workflow_templates import (
    WorkflowTemplate,
    get_template,
    list_templates,
    materialize,
)

router = APIRouter(prefix="/admin/workflow/templates", tags=["admin", "workflow", "templates"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify(x: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x or not secrets.compare_digest(x, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


def _serialize(t: WorkflowTemplate) -> dict:
    return {
        "id": t.id,
        "name_ar": t.name_ar,
        "name_en": t.name_en,
        "category": t.category,
        "description_ar": t.description_ar,
        "icon": t.icon,
        "event_pattern": t.event_pattern,
        "conditions": t.conditions,
        "actions": t.actions,
        "parameters": t.parameters,
    }


@router.get("")
def list_route(
    category: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    items = list_templates(category=category)
    return {"success": True, "templates": [_serialize(t) for t in items], "count": len(items)}


@router.get("/{template_id}")
def get_route(
    template_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    t = get_template(template_id)
    if not t:
        raise HTTPException(404, "Template not found")
    return {"success": True, "template": _serialize(t)}


class InstallRequest(BaseModel):
    parameter_values: dict[str, Any] = Field(default_factory=dict)
    tenant_id: Optional[str] = None
    enabled: bool = True


@router.post("/{template_id}/install", status_code=201)
def install_route(
    template_id: str,
    payload: InstallRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    t = get_template(template_id)
    if not t:
        raise HTTPException(404, "Template not found")

    # Validate that all required parameters were supplied (those without defaults).
    missing = [
        p["name"]
        for p in t.parameters
        if p.get("default") is None and p.get("name") not in payload.parameter_values
    ]
    if missing:
        raise HTTPException(
            400,
            f"Missing required parameter(s): {', '.join(missing)}. "
            f"Supply via parameter_values.",
        )

    rule_dict = materialize(t, payload.parameter_values)
    rule = create_rule(
        name=rule_dict["name"],
        event_pattern=rule_dict["event_pattern"],
        conditions=rule_dict.get("conditions", []),
        actions=rule_dict.get("actions", []),
        description_ar=rule_dict.get("description_ar"),
        tenant_id=payload.tenant_id,
        enabled=payload.enabled,
    )
    return {
        "success": True,
        "rule_id": rule.id,
        "rule_name": rule.name,
        "template_id": t.id,
    }
