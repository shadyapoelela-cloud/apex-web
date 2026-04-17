"""Copilot memory — session continuity + vector retrieval.

Two layers:

  1. Session history — ordered list of messages per (user, session_id).
     Persisted so clients can resume a conversation on a new device, and
     so the agent has context for multi-turn interactions.

  2. Vector memory — important facts extracted from past conversations
     stored with embeddings for semantic recall. Example: "the CFO
     wants quarterly reports on the 5th", "our VAT return period
     ends March 31".

Storage:
  • CopilotSession + CopilotMessage tables — tenant-scoped.
  • CopilotMemoryFact table — tenant-scoped, with optional embedding
    column. If `pgvector` is available + POSTGRES_URL, we use it; else
    we fall back to in-row cosine over NumPy arrays encoded as JSON.

Graceful degradation:
  • Without anthropic SDK: fall back to keyword match on fact.content.
  • Without pgvector: use in-memory cosine over the last 1000 facts
    (fine for early deployments).
"""

from __future__ import annotations

import json
import logging
import math
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import Column, DateTime, Integer, JSON, String, Text

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


# ── Models ────────────────────────────────────────────────


class CopilotMemorySession(Base, TenantMixin):
    """One continuous Copilot conversation."""

    __tablename__ = "copilot_memory_sessions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=True, index=True)
    title = Column(String(200), nullable=True)
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class CopilotMemoryMessage(Base, TenantMixin):
    __tablename__ = "copilot_memory_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String(36), nullable=False, index=True)
    role = Column(String(16), nullable=False)   # 'user' | 'assistant' | 'tool'
    content = Column(Text, nullable=False)
    tool_calls = Column(JSON, nullable=True)    # optional — list of {name, args, result}
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class CopilotMemoryFact(Base, TenantMixin):
    """Durable fact extracted from past conversations.

    Used to answer questions like "what did the CFO say about Q2?" even
    in a new session. Embedding is an optional JSON-encoded float[]; when
    present, we rank by cosine similarity against the query embedding.
    """

    __tablename__ = "copilot_memory_facts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=True, index=True)
    content = Column(Text, nullable=False)
    source_session_id = Column(String(36), nullable=True, index=True)
    tags = Column(JSON, nullable=True)         # ['cfo','quarterly','reporting']
    embedding = Column(JSON, nullable=True)    # [float, ...] or None
    importance = Column(Integer, nullable=False, default=50)  # 1..100
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


# ── Session operations ────────────────────────────────────


def start_session(user_id: Optional[str], title: Optional[str] = None) -> str:
    """Create a new Copilot session and return its ID."""
    db = SessionLocal()
    try:
        s = CopilotMemorySession(id=str(uuid.uuid4()), user_id=user_id, title=title)
        db.add(s)
        db.commit()
        return s.id
    finally:
        db.close()


def append_message(
    session_id: str,
    role: str,
    content: str,
    tool_calls: Optional[list[dict]] = None,
) -> str:
    """Append one message to a session. Returns the message ID."""
    db = SessionLocal()
    try:
        msg = CopilotMemoryMessage(
            id=str(uuid.uuid4()),
            session_id=session_id,
            role=role,
            content=content,
            tool_calls=tool_calls,
        )
        db.add(msg)
        # Bump session updated_at by re-selecting and touching.
        sess = db.query(CopilotMemorySession).filter(CopilotMemorySession.id == session_id).first()
        if sess is not None:
            sess.updated_at = datetime.now(timezone.utc)
        db.commit()
        return msg.id
    finally:
        db.close()


def get_session_history(session_id: str, limit: int = 50) -> list[dict]:
    """Return the last `limit` messages of a session in chronological order."""
    db = SessionLocal()
    try:
        rows = (
            db.query(CopilotMemoryMessage)
            .filter(CopilotMemoryMessage.session_id == session_id)
            .order_by(CopilotMemoryMessage.created_at.desc())
            .limit(limit)
            .all()
        )
        rows.reverse()
        return [
            {
                "id": r.id,
                "role": r.role,
                "content": r.content,
                "tool_calls": r.tool_calls,
                "created_at": (
                    r.created_at.isoformat() if r.created_at else None
                ),
            }
            for r in rows
        ]
    finally:
        db.close()


def list_recent_sessions(user_id: Optional[str], limit: int = 20) -> list[dict]:
    db = SessionLocal()
    try:
        q = db.query(CopilotMemorySession).order_by(CopilotMemorySession.updated_at.desc())
        if user_id:
            q = q.filter(CopilotMemorySession.user_id == user_id)
        rows = q.limit(max(1, min(limit, 100))).all()
        return [
            {
                "id": r.id,
                "title": r.title,
                "created_at": r.created_at.isoformat(),
                "updated_at": r.updated_at.isoformat(),
            }
            for r in rows
        ]
    finally:
        db.close()


# ── Memory facts ──────────────────────────────────────────


def remember_fact(
    *,
    content: str,
    user_id: Optional[str] = None,
    source_session_id: Optional[str] = None,
    tags: Optional[list[str]] = None,
    importance: int = 50,
    embedding: Optional[list[float]] = None,
) -> str:
    db = SessionLocal()
    try:
        fact = CopilotMemoryFact(
            id=str(uuid.uuid4()),
            user_id=user_id,
            content=content,
            source_session_id=source_session_id,
            tags=tags,
            importance=max(1, min(importance, 100)),
            embedding=embedding,
        )
        db.add(fact)
        db.commit()
        return fact.id
    finally:
        db.close()


def _cosine(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def recall_facts(
    *,
    query_text: Optional[str] = None,
    query_embedding: Optional[list[float]] = None,
    user_id: Optional[str] = None,
    tag: Optional[str] = None,
    top_k: int = 5,
) -> list[dict]:
    """Return the top-k most relevant facts.

    Ranking:
      1. If `query_embedding` is given + candidates have embeddings →
         cosine similarity.
      2. Else if `query_text` → simple keyword/substring match.
      3. Else → most important recent facts for the user.
    """
    db = SessionLocal()
    try:
        q = db.query(CopilotMemoryFact)
        if user_id:
            q = q.filter(CopilotMemoryFact.user_id == user_id)
        rows = q.order_by(CopilotMemoryFact.created_at.desc()).limit(1000).all()

        scored: list[tuple[float, CopilotMemoryFact]] = []
        for r in rows:
            tags = r.tags or []
            if tag and tag not in tags:
                continue
            if query_embedding and r.embedding:
                score = _cosine(query_embedding, r.embedding)
            elif query_text:
                hay = (r.content or "").lower()
                score = 1.0 if query_text.lower() in hay else 0.0
            else:
                # Default: importance score normalised to [0,1]
                score = (r.importance or 0) / 100.0
            scored.append((score, r))

        scored.sort(key=lambda x: x[0], reverse=True)
        out = []
        for score, r in scored[:top_k]:
            if query_text and score == 0.0 and query_embedding is None:
                continue
            out.append({
                "id": r.id,
                "content": r.content,
                "tags": r.tags,
                "importance": r.importance,
                "score": round(score, 4),
                "created_at": r.created_at.isoformat(),
            })
        return out
    finally:
        db.close()


def forget_fact(fact_id: str) -> bool:
    db = SessionLocal()
    try:
        fact = db.query(CopilotMemoryFact).filter(CopilotMemoryFact.id == fact_id).first()
        if not fact:
            return False
        db.delete(fact)
        db.commit()
        return True
    finally:
        db.close()
