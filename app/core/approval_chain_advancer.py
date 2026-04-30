"""APEX — Approval Chain Stage Advancer.

Wave 1V Phase CCC introduced template apply that creates the FIRST
stage as an approval and stores remaining_stages in approval.meta.
Without an advancer those remaining stages would never fire — the
template chain would stop after stage 1.

This module registers a listener on `approval.approved` that:

  1. Reads `meta.template_id` and `meta.remaining_stages` from the
     approval payload.
  2. If `remaining_stages` is non-empty, pops the first one and
     creates a new approval for that stage, copying down:
       - title_ar (prefixed with stage number for context)
       - object_type / object_id from the original
       - tenant_id
       - meta.template_id (so chain can be traced)
       - meta.remaining_stages with the rest
       - meta.previous_approval_id for audit linkage
       - meta.stage_sequence
  3. Emits `approval_template.stage_advanced` for observability.

If the approval is rejected, the chain stops — no advancer fires
(this is by design: the listener only listens for `approval.approved`).

Wave 1W Phase DDD. Closes Wave 1V's chain so multi-stage templates
actually run end-to-end.
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.event_bus import emit, register_listener

logger = logging.getLogger(__name__)


@register_listener("approval.approved")
def _on_approval_approved(event_name: str, payload: dict) -> None:
    """Advance the chain if there are remaining template stages."""
    try:
        meta = payload.get("meta") or {}
        template_id = meta.get("template_id")
        remaining = list(meta.get("remaining_stages") or [])
        if not template_id or not remaining:
            # Not a template-driven approval, or final stage — done.
            return

        next_stage = remaining[0]
        rest = remaining[1:]
        approver_user_ids = list(next_stage.get("approver_user_ids") or [])
        # Drop unresolved {placeholder} entries to avoid blocking.
        approver_user_ids = [
            u for u in approver_user_ids
            if not (isinstance(u, str) and u.startswith("{") and u.endswith("}"))
        ]
        if not approver_user_ids:
            logger.warning(
                "approval chain advancer: next stage has no resolvable approvers; chain halted",
            )
            emit(
                "approval_template.chain_halted",
                {
                    "template_id": template_id,
                    "previous_approval_id": payload.get("approval_id"),
                    "reason": "next_stage_no_approvers",
                },
                source="approval_chain_advancer",
            )
            return

        try:
            from app.core.approvals import create_approval
        except Exception as e:  # noqa: BLE001
            logger.error("approval chain advancer: approvals service unavailable: %s", e)
            return

        seq = next_stage.get("sequence")
        title_ar = (
            f"[المرحلة {seq}] {next_stage.get('title_ar') or ''}"
            if seq
            else (next_stage.get("title_ar") or "Stage")
        )
        new_meta: dict[str, Any] = {
            "template_id": template_id,
            "stage_sequence": seq,
            "stage_kind": next_stage.get("kind"),
            "previous_approval_id": payload.get("approval_id"),
            "remaining_stages": rest,
            "stages_total": meta.get("stages_total"),
        }

        try:
            approval = create_approval(
                title_ar=title_ar,
                body=next_stage.get("notes_ar"),
                object_type=payload.get("object_type"),
                object_id=str(payload.get("object_id")) if payload.get("object_id") else None,
                approver_user_ids=approver_user_ids,
                requested_by=payload.get("decided_by"),
                tenant_id=payload.get("tenant_id"),
                meta=new_meta,
            )
        except Exception as e:  # noqa: BLE001
            logger.exception("approval chain advancer: create_approval failed: %s", e)
            return

        new_id = (
            getattr(approval, "id", None)
            or (approval.get("id") if isinstance(approval, dict) else None)
        )
        emit(
            "approval_template.stage_advanced",
            {
                "template_id": template_id,
                "previous_approval_id": payload.get("approval_id"),
                "new_approval_id": new_id,
                "stage_sequence": seq,
                "remaining_after": len(rest),
                "tenant_id": payload.get("tenant_id"),
            },
            source="approval_chain_advancer",
        )
        logger.info(
            "approval chain advancer: advanced template=%s prev=%s new=%s seq=%s remaining=%d",
            template_id,
            payload.get("approval_id"),
            new_id,
            seq,
            len(rest),
        )
    except Exception:  # noqa: BLE001
        logger.exception("approval chain advancer crashed (non-fatal)")
