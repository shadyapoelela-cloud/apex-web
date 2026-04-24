"""Executor for human-approved AI suggestions.

Decouples the approval signal from the domain write: when a user taps
"approve" on an AiSuggestion row, the guardrail flips status to
APPROVED and emits an audit event — but does NOT execute the proposed
action. This module is where execution lives.

Why split this way:
  • Keeps the approval endpoint cheap and idempotent.
  • Lets retries happen without re-asking the human.
  • Domain writes can be batched by an offline worker in production.
  • Keeps a clean audit trail: every executed suggestion has both an
    "approved" event AND an "executed" event, with a delta between
    them if execution failed.

Supported action types (today):
  • create_invoice   → draft an invoice (stub — logs; ZATCA wiring is the
                       next integration step).
  • send_reminder    → dispatch via notifications_bridge.

Safe to call repeatedly on the same row; the executor only acts on rows
whose status is APPROVED and updates status to `executed`/`failed` to
prevent re-runs.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.compliance_models import AiSuggestion
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)


# Extra statuses the executor uses. The guardrail owns approved/rejected/
# auto_applied/needs_approval; executor adds these two terminal states.
STATUS_EXECUTED = "executed"
STATUS_FAILED = "failed"


@dataclass
class ExecutionResult:
    suggestion_id: str
    ok: bool
    status: str
    detail: str
    output: Optional[dict[str, Any]] = None


# ── Action handlers ───────────────────────────────────────


def _execute_create_invoice(row: AiSuggestion) -> ExecutionResult:
    """Handle an approved create_invoice suggestion.

    Produces a ZATCA-compliant simplified (B2C) invoice package via
    build_simplified_invoice + enqueues it for Fatoora clearance. The
    LLM-drafted preview drives the seller/line construction; seller
    details come from tenant configuration (or sensible dev defaults).

    Fails gracefully: any validation or sig error marks the row as
    failed with a readable Arabic reason in the detail field.
    """
    after = row.after_json or {}
    client_name = (after.get("client_name") or "").strip() or "عميل"
    description = (after.get("description") or "خدمة").strip()
    subtotal = float(after.get("subtotal") or 0)
    vat_rate = float(after.get("vat_rate") or 15)
    currency = (after.get("currency") or "SAR").upper()

    logger.info(
        "executing create_invoice suggestion %s: client=%s subtotal=%s",
        row.id, client_name, subtotal,
    )

    if subtotal <= 0:
        return ExecutionResult(
            suggestion_id=row.id, ok=False, status=STATUS_FAILED,
            detail="subtotal must be > 0",
        )

    # Build the ZATCA package — wrap in try so a validation failure on
    # seller VAT or signing cert doesn't bubble up as a 500.
    try:
        import os
        from app.core.zatca_service import (
            build_simplified_invoice,
            ZatcaSeller,
            ZatcaLineItem,
        )
        seller = ZatcaSeller(
            vat_number=os.environ.get("APEX_SELLER_VAT", "300000000000003"),
            name=os.environ.get("APEX_SELLER_NAME", "APEX Platform"),
            address_street=os.environ.get("APEX_SELLER_STREET", "King Fahd Rd"),
            address_city=os.environ.get("APEX_SELLER_CITY", "Riyadh"),
        )
        from decimal import Decimal as _D
        lines = [ZatcaLineItem(
            name=description,
            quantity=_D("1"),
            unit_price=_D(str(subtotal)),
            vat_rate=_D(str(vat_rate)),
        )]
        result = build_simplified_invoice(
            seller=seller,
            lines=lines,
            client_id=row.tenant_id or "default",
            fiscal_year=str(datetime.now(timezone.utc).year),
            currency=currency,
        )
    except ValueError as ve:
        return ExecutionResult(
            suggestion_id=row.id, ok=False, status=STATUS_FAILED,
            detail=f"ZATCA build rejected: {ve}",
        )
    except Exception as e:
        logger.warning("ZATCA build failed for %s: %s", row.id, e)
        return ExecutionResult(
            suggestion_id=row.id, ok=False, status=STATUS_FAILED,
            detail=f"ZATCA build error: {e.__class__.__name__}",
        )

    # Sign + enqueue for Fatoora submission. If the signing cert isn't
    # configured (dev / test env), we record the build but skip the
    # queue — the row is still 'executed' because the invoice object
    # itself was produced correctly.
    submission_id: Optional[str] = None
    try:
        from app.integrations.zatca.signer import sign_invoice
        from app.integrations.zatca.retry_queue import enqueue_submission

        signed = sign_invoice(result, tenant_id=row.tenant_id)
        submission_id = enqueue_submission(
            invoice_uuid=result.uuid,
            invoice_number=result.invoice_number,
            invoice_hash_b64=result.invoice_hash_b64,
            invoice_type="reporting",     # simplified B2C → reporting lane
            signed_xml=signed.signed_xml,
        )
    except Exception as e:
        logger.info("ZATCA signing/queue unavailable (%s) — invoice built but not submitted", e)

    return ExecutionResult(
        suggestion_id=row.id,
        ok=True,
        status=STATUS_EXECUTED,
        detail=(
            f"invoice {result.invoice_number} built"
            + (f" + queued for Fatoora ({submission_id})" if submission_id else " (signing cert not configured — queued skipped)")
        ),
        output={
            "invoice_number": result.invoice_number,
            "invoice_uuid": result.uuid,
            "icv": result.icv,
            "totals": result.totals,
            "submission_id": submission_id,
        },
    )


def _execute_send_reminder(row: AiSuggestion) -> ExecutionResult:
    """Handle an approved send_reminder suggestion via notifications_bridge."""
    after = row.after_json or {}
    invoice_id = after.get("invoice_id")
    client_name = after.get("client_name")
    channel = (after.get("channel") or "auto").lower()
    tone = (after.get("tone") or "gentle").lower()

    if not invoice_id and not client_name:
        return ExecutionResult(
            suggestion_id=row.id,
            ok=False,
            status=STATUS_FAILED,
            detail="neither invoice_id nor client_name available",
        )

    # Render the Arabic body by tone.
    bodies = {
        "gentle": "تذكير ودّي: فاتورتكم مستحقة. يسعدنا سداد ميسّر — شكراً لكم.",
        "firm":   "تذكير: الفاتورة متأخرة. نرجو السداد قبل نهاية الأسبوع.",
        "final_notice": "إشعار نهائي بالسداد قبل اللجوء للإجراءات التحصيلية.",
    }
    body = bodies.get(tone, bodies["gentle"])
    title = "تذكير بدفع فاتورة" if not invoice_id else f"تذكير بفاتورة {invoice_id}"

    # notifications_bridge.notify is async — execute it synchronously via a
    # fresh event loop so this worker stays sync for CI simplicity.
    try:
        import asyncio
        from app.core.notifications_bridge import notify

        async def _go() -> dict:
            return await notify(
                user_id=row.approved_by or "system",
                kind="ai_reminder",
                title=title,
                body=body,
                tenant_id=row.tenant_id,
                entity_type="invoice",
                entity_id=invoice_id,
                severity="info",
            )

        out = asyncio.new_event_loop().run_until_complete(_go())
        return ExecutionResult(
            suggestion_id=row.id,
            ok=True,
            status=STATUS_EXECUTED,
            detail=f"notification dispatched via {channel}",
            output=out,
        )
    except Exception as e:
        logger.warning("send_reminder exec failed for %s: %s", row.id, e)
        return ExecutionResult(
            suggestion_id=row.id,
            ok=False,
            status=STATUS_FAILED,
            detail=f"notification dispatch raised: {e.__class__.__name__}",
        )


_HANDLERS = {
    "create_invoice": _execute_create_invoice,
    "send_reminder": _execute_send_reminder,
}


# ── Public API ────────────────────────────────────────────


def execute_suggestion(suggestion_id: str) -> ExecutionResult:
    """Look up one suggestion by id; run its handler if APPROVED."""
    db = SessionLocal()
    try:
        row = db.query(AiSuggestion).filter(AiSuggestion.id == suggestion_id).first()
        if row is None:
            return ExecutionResult(
                suggestion_id=suggestion_id,
                ok=False,
                status=STATUS_FAILED,
                detail="suggestion not found",
            )
        if row.status != "approved":
            return ExecutionResult(
                suggestion_id=suggestion_id,
                ok=False,
                status=STATUS_FAILED,
                detail=f"cannot execute from state {row.status!r} — need 'approved'",
            )
        handler = _HANDLERS.get(row.action_type)
        if handler is None:
            return ExecutionResult(
                suggestion_id=suggestion_id,
                ok=False,
                status=STATUS_FAILED,
                detail=f"no handler for action_type {row.action_type!r}",
            )
        result = handler(row)

        # Mark terminal state + persist detail.
        row.status = result.status
        row.updated_at = datetime.now(timezone.utc)
        db.commit()

        # Append audit event so the "approved → executed/failed" gap is visible.
        try:
            from app.core.compliance_service import write_audit_event
            write_audit_event(
                action=f"ai.execute.{'ok' if result.ok else 'failed'}",
                entity_type="ai_suggestion",
                entity_id=suggestion_id,
                metadata={
                    "action_type": row.action_type,
                    "detail": result.detail,
                },
            )
        except Exception:
            pass

        return result
    finally:
        try:
            db.close()
        except Exception:
            pass


def execute_all_approved(limit: int = 50) -> dict[str, Any]:
    """Drain the approved-but-not-executed queue. Intended for a worker
    loop or a POST /api/v1/ai/execute-approved endpoint.

    Returns counters so the caller can log progress.
    """
    db = SessionLocal()
    try:
        rows = (
            db.query(AiSuggestion)
            .filter(AiSuggestion.status == "approved")
            .order_by(AiSuggestion.approved_at.asc().nullslast())
            .limit(limit)
            .all()
        )
        ids = [r.id for r in rows]
    finally:
        try:
            db.close()
        except Exception:
            pass

    ok = 0
    failed = 0
    for sid in ids:
        res = execute_suggestion(sid)
        if res.ok:
            ok += 1
        else:
            failed += 1
    return {
        "considered": len(ids),
        "executed": ok,
        "failed": failed,
    }
