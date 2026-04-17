"""Auto-log: SQLAlchemy event listener that turns status transitions
into ActivityLog entries automatically.

When any registered model has its `status` column mutated via an
UPDATE, we detect the transition in `before_flush` and queue an
ActivityLog row (also flushed in the same transaction). The host
doesn't have to call log_status_change manually from every endpoint.

Usage:
    from app.core.auto_log import register_auto_log
    register_auto_log(Invoice, entity_type="invoice")
    register_auto_log(PurchaseOrder, entity_type="po")
    register_auto_log(JournalEntry, entity_type="journal_entry")

One-time initialisation; subsequent commits are handled automatically.

Opt-in by design — we don't want to scan every table in the schema and
accidentally log events for internal config tables.
"""
from __future__ import annotations

import logging
from typing import Callable, Iterable

from sqlalchemy import event
from sqlalchemy.orm import Session, attributes

from app.core.activity_log import log_activity

logger = logging.getLogger(__name__)

# ── Registry ─────────────────────────────────────────────
# We keep a module-level map of model class → entity_type so the
# before_flush listener can look up the right entity_type without
# polluting each model with an __activity_type__ attribute.

_REGISTRY: dict[type, dict] = {}


def register_auto_log(
    model: type,
    *,
    entity_type: str,
    entity_id_attr: str = "id",
    status_attr: str = "status",
    summary_builder: Callable[[object, str, str], str] | None = None,
) -> None:
    """Register a model for auto-logging of status-column transitions.

    Safe to call multiple times with the same args — idempotent.
    """
    _REGISTRY[model] = {
        "entity_type": entity_type,
        "entity_id_attr": entity_id_attr,
        "status_attr": status_attr,
        "summary_builder": summary_builder
        or (lambda obj, old, new: f"{old} → {new}"),
    }


def _iter_dirty_registered(session: Session) -> Iterable[tuple[object, dict]]:
    for inst in session.dirty:
        spec = _REGISTRY.get(type(inst))
        if spec is None:
            continue
        yield inst, spec


@event.listens_for(Session, "before_flush")
def _before_flush_autolog(session: Session, flush_context, instances) -> None:
    """Detect status changes on registered models and enqueue
    ActivityLog rows before the flush completes.
    """
    for inst, spec in _iter_dirty_registered(session):
        status_attr = spec["status_attr"]
        history = attributes.get_history(inst, status_attr)
        if not history.has_changes():
            continue
        # added: new value(s); deleted: old value(s)
        new_val = history.added[0] if history.added else None
        old_val = history.deleted[0] if history.deleted else None
        if new_val is None or old_val is None or new_val == old_val:
            continue

        entity_id = getattr(inst, spec["entity_id_attr"], None)
        if entity_id is None:
            continue
        summary = spec["summary_builder"](inst, str(old_val), str(new_val))
        try:
            log_activity(
                entity_type=spec["entity_type"],
                entity_id=str(entity_id),
                action="status_changed",
                summary=summary,
                details={"from": str(old_val), "to": str(new_val)},
                db=session,
            )
        except Exception as e:  # pragma: no cover
            logger.warning("auto_log failed for %s: %s", spec["entity_type"], e)


# ── Helpers for other modules ─────────────────────────────


def auto_log_field_change(
    *,
    entity_type: str,
    entity_id: str,
    field: str,
    old: object,
    new: object,
    user_id: str | None = None,
    user_name: str | None = None,
    db=None,
) -> str | None:
    """Manual helper for field changes that aren't a status column.

    Returns the new activity_log id, or None if old == new.
    """
    if old == new:
        return None
    return log_activity(
        entity_type=entity_type,
        entity_id=entity_id,
        action="updated",
        summary=f"{field}: {old} → {new}",
        details={"field": field, "from": str(old), "to": str(new)},
        user_id=user_id,
        user_name=user_name,
        db=db,
    )
