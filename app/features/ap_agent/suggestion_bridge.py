"""Bridge AP-agent approval requests to the AiSuggestion inbox.

The AP pipeline has its own APInvoiceStatus machine (awaiting_approval →
approved). This module mirrors each "awaiting_approval" transition into
an AiSuggestion row so the admin can review all AI-originated decisions
— AP invoices, send_reminder, create_invoice — in one inbox.

When a human approves the AiSuggestion, the mirror is detected and the
matching AP invoice status flips to APPROVED. The AP pipeline picks it
up on its next tick and proceeds to schedule_payment.

Call `request_ap_approval(invoice, policy)` from the AP pipeline when
a row enters AWAITING_APPROVAL; call `on_suggestion_approved(sid)`
from the approval-executor drain loop.
"""

from __future__ import annotations

import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)


def request_ap_approval(
    invoice: dict[str, Any],
    policy: str,
    tenant_id: Optional[str] = None,
) -> Optional[str]:
    """Mirror an AWAITING_APPROVAL AP invoice into AiSuggestion.

    Returns the suggestion row id, or None if the guardrail layer isn't
    loaded (tests / minimal env).
    """
    try:
        from app.core.ai_guardrails import guard, Suggestion
        decision = guard(Suggestion(
            source="ap_agent",
            action_type="ap_invoice_approval",
            target_type="ap_invoice",
            target_id=str(invoice.get("id") or invoice.get("invoice_number") or "unknown"),
            after={
                "vendor_name": invoice.get("vendor_name"),
                "invoice_number": invoice.get("invoice_number"),
                "total": invoice.get("total"),
                "currency": invoice.get("currency", "SAR"),
                "due_date": invoice.get("due_date"),
                "gl_coding": invoice.get("gl_coding"),
                "approval_policy": policy,
            },
            confidence=0.90,
            destructive=True,         # payment authorization — always manual
            reasoning=(
                f"AP invoice from {invoice.get('vendor_name')} for "
                f"{invoice.get('total')} {invoice.get('currency', 'SAR')} — "
                f"policy={policy}"
            ),
            tenant_id=tenant_id,
        ))
        return decision.row_id
    except Exception as e:
        logger.debug("request_ap_approval: guardrail unavailable (%s)", e)
        return None


def on_suggestion_approved(suggestion_id: str) -> dict[str, Any]:
    """Called when a user approves an AP suggestion — flip the matching
    AP invoice to APPROVED so the pipeline proceeds to scheduling.

    Returns the update result dict.
    """
    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.core.compliance_models import AiSuggestion
        from app.features.ap_agent.models import APInvoice, APInvoiceStatus
    except Exception as e:
        return {"ok": False, "detail": f"dependencies missing: {e}"}

    db = SessionLocal()
    try:
        sug = db.query(AiSuggestion).filter(AiSuggestion.id == suggestion_id).first()
        if sug is None or sug.action_type != "ap_invoice_approval":
            return {"ok": False, "detail": "not an AP approval suggestion"}
        target = sug.target_id
        inv = (
            db.query(APInvoice)
            .filter((APInvoice.id == target) | (APInvoice.invoice_number == target))
            .first()
        )
        if inv is None:
            return {"ok": False, "detail": f"AP invoice {target} not found"}
        inv.status = APInvoiceStatus.APPROVED.value
        db.commit()
        return {"ok": True, "ap_invoice_id": inv.id, "new_status": inv.status}
    except Exception as e:
        logger.warning("on_suggestion_approved failed for %s: %s", suggestion_id, e)
        try:
            db.rollback()
        except Exception:
            pass
        return {"ok": False, "detail": f"error: {e.__class__.__name__}"}
    finally:
        try:
            db.close()
        except Exception:
            pass
