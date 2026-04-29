"""
APEX — Universal Comments HTTP routes
======================================
Public endpoints (authed via JWT in production; user_id in body for v1):

    GET  /api/v1/comments?object_type=...&object_id=...
    POST /api/v1/comments
    PATCH /api/v1/comments/{id}        — edit (author only)
    DELETE /api/v1/comments/{id}       — soft-delete (author only)
    POST /api/v1/comments/{id}/react   — toggle emoji reaction
    GET  /admin/comments/stats         — admin stats
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.comments import (
    add_comment,
    delete_comment,
    edit_comment,
    list_comments,
    react,
    stats,
)

router = APIRouter(tags=["comments"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x or not secrets.compare_digest(x, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


def _serialize(c) -> dict:
    return {
        "id": c.id,
        "object_type": c.object_type,
        "object_id": c.object_id,
        "author_user_id": c.author_user_id,
        "body": c.body,
        "mentioned_user_ids": c.mentioned_user_ids,
        "parent_id": c.parent_id,
        "tenant_id": c.tenant_id,
        "reactions": c.reactions,
        "is_deleted": c.is_deleted,
        "created_at": c.created_at,
        "edited_at": c.edited_at,
    }


# ── Public routes ────────────────────────────────────────────────


@router.get("/api/v1/comments")
def list_route(
    object_type: str = Query(..., min_length=1),
    object_id: str = Query(..., min_length=1),
    tenant_id: Optional[str] = Query(None),
    include_deleted: bool = Query(False),
):
    rows = list_comments(
        object_type=object_type,
        object_id=object_id,
        tenant_id=tenant_id,
        include_deleted=include_deleted,
    )
    return {
        "success": True,
        "comments": [_serialize(c) for c in rows],
        "count": len(rows),
    }


class AddCommentRequest(BaseModel):
    object_type: str = Field(..., min_length=1, max_length=50)
    object_id: str = Field(..., min_length=1, max_length=100)
    author_user_id: str = Field(..., min_length=1)
    body: str = Field(..., min_length=1, max_length=5000)
    parent_id: Optional[str] = None
    tenant_id: Optional[str] = None
    extra_mentions: Optional[list[str]] = None


@router.post("/api/v1/comments", status_code=201)
def add_route(payload: AddCommentRequest):
    try:
        c = add_comment(
            object_type=payload.object_type,
            object_id=payload.object_id,
            author_user_id=payload.author_user_id,
            body=payload.body,
            parent_id=payload.parent_id,
            tenant_id=payload.tenant_id,
            extra_mentions=payload.extra_mentions,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "comment": _serialize(c)}


class EditCommentRequest(BaseModel):
    by_user_id: str = Field(..., min_length=1)
    body: str = Field(..., min_length=1, max_length=5000)


@router.patch("/api/v1/comments/{comment_id}")
def edit_route(comment_id: str, payload: EditCommentRequest):
    try:
        c = edit_comment(comment_id, payload.by_user_id, payload.body)
    except ValueError as e:
        raise HTTPException(400, str(e))
    if not c:
        raise HTTPException(403, "Not author or not found")
    return {"success": True, "comment": _serialize(c)}


class DeleteCommentRequest(BaseModel):
    by_user_id: str = Field(..., min_length=1)


@router.delete("/api/v1/comments/{comment_id}")
def delete_route(comment_id: str, payload: DeleteCommentRequest):
    if not delete_comment(comment_id, payload.by_user_id):
        raise HTTPException(403, "Not author or not found or already deleted")
    return {"success": True}


class ReactRequest(BaseModel):
    user_id: str = Field(..., min_length=1)
    emoji: str = Field(..., min_length=1, max_length=16)


@router.post("/api/v1/comments/{comment_id}/react")
def react_route(comment_id: str, payload: ReactRequest):
    try:
        c = react(comment_id, payload.user_id, payload.emoji)
    except ValueError as e:
        raise HTTPException(400, str(e))
    if not c:
        raise HTTPException(404, "Comment not found")
    return {"success": True, "comment": _serialize(c)}


# ── Admin ────────────────────────────────────────────────────────


@router.get("/admin/comments/stats")
def stats_route(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}
