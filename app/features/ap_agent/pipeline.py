"""Autonomous AP pipeline orchestrator.

The pipeline is a sequence of pluggable processors. Each processor
receives the invoice + current context and returns a result describing
the next status + any extracted fields.

Key design: processors are pure functions of (invoice_dict, context) →
(result_dict, next_status). This keeps them trivially testable with
mocks and lets us swap OCR vendors, approval policies, etc. without
touching the orchestrator.

Status transitions:
  received -> ocr_done -> coded -> awaiting_approval -> approved ->
    scheduled -> paid

A processor can short-circuit to REJECTED or ERROR at any step.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Callable, Optional

from app.features.ap_agent.models import APInvoiceStatus

logger = logging.getLogger(__name__)


@dataclass
class APProcessorResult:
    """Returned by each processor — describes what happened at this step."""

    next_status: APInvoiceStatus
    extracted: dict[str, Any] = field(default_factory=dict)
    log_entry: str = ""
    exception: Optional[dict] = None  # {"code": str, "message": str}


# Processor signature: (invoice_dict, context) -> APProcessorResult
Processor = Callable[[dict, dict], APProcessorResult]


# ── Default processor chain ──────────────────────────────────

# Each processor is called in order whenever the invoice is in the
# matching source status. They advance the status toward 'paid'.
# Real implementations swap in Claude Vision OCR, live 3-way match, etc.


def processor_ocr(invoice: dict, ctx: dict) -> APProcessorResult:
    """Stub: real impl calls Claude Vision on raw_file_url.

    For now, simply mark the step done so downstream tests can run without
    an OCR dependency. Returns ocr_confidence = 0 (caller should treat as
    'needs manual review').
    """
    return APProcessorResult(
        next_status=APInvoiceStatus.OCR_DONE,
        extracted={"ocr_confidence": 0},
        log_entry="OCR placeholder (no real extraction performed)",
    )


def processor_gl_coding(invoice: dict, ctx: dict) -> APProcessorResult:
    """Suggest a GL account using the COA Engine (v4.3) if available.

    Inputs: invoice.vendor_name, invoice.total, line_items.descriptions
    Output: suggested_account_id + coding_confidence.
    """
    return APProcessorResult(
        next_status=APInvoiceStatus.CODED,
        extracted={"coding_confidence": 0},
        log_entry="GL coding placeholder (wire to app.coa_engine)",
    )


def processor_approval_routing(invoice: dict, ctx: dict) -> APProcessorResult:
    """Decide whether auto-approve, manager approval, or CFO approval.

    Policy (dev default):
      total ≤  1,000 SAR → auto-approve
      total ≤ 10,000 SAR → manager
      total >  10,000 SAR → CFO
    Overridable via ctx['policy'] = {'auto_max':…, 'manager_max':…}
    """
    total = float(invoice.get("total") or 0)
    policy = ctx.get("policy", {})
    auto_max = policy.get("auto_max", 1000)
    manager_max = policy.get("manager_max", 10000)

    if total <= auto_max:
        return APProcessorResult(
            next_status=APInvoiceStatus.APPROVED,
            extracted={"approval_policy": "auto_under_threshold"},
            log_entry=f"Auto-approved (total {total} ≤ {auto_max})",
        )
    if total <= manager_max:
        return APProcessorResult(
            next_status=APInvoiceStatus.AWAITING_APPROVAL,
            extracted={"approval_policy": "manager"},
            log_entry=f"Manager approval required (total {total})",
        )
    return APProcessorResult(
        next_status=APInvoiceStatus.AWAITING_APPROVAL,
        extracted={"approval_policy": "cfo"},
        log_entry=f"CFO approval required (total {total})",
    )


def processor_schedule_payment(invoice: dict, ctx: dict) -> APProcessorResult:
    """Schedule payment — uses due_date and cash-flow buffer if provided.

    Simple default: schedule on due_date if present, else today + 14 days.
    """
    from datetime import date, timedelta

    due = invoice.get("due_date")
    if isinstance(due, str):
        try:
            from datetime import datetime as _dt

            due = _dt.fromisoformat(due).date()
        except ValueError:
            due = None
    scheduled = due or (date.today() + timedelta(days=14))
    return APProcessorResult(
        next_status=APInvoiceStatus.SCHEDULED,
        extracted={"scheduled_payment_date": scheduled.isoformat()},
        log_entry=f"Payment scheduled for {scheduled.isoformat()}",
    )


_DEFAULT_CHAIN: dict[APInvoiceStatus, Processor] = {
    APInvoiceStatus.RECEIVED: processor_ocr,
    APInvoiceStatus.OCR_DONE: processor_gl_coding,
    APInvoiceStatus.CODED: processor_approval_routing,
    APInvoiceStatus.APPROVED: processor_schedule_payment,
}


class APPipeline:
    """Drive an invoice through the processor chain until a terminal state."""

    def __init__(self, chain: Optional[dict[APInvoiceStatus, Processor]] = None):
        self.chain = chain or dict(_DEFAULT_CHAIN)

    def step(self, invoice: dict, ctx: Optional[dict] = None) -> APProcessorResult:
        """Execute exactly one processor based on current status."""
        ctx = ctx or {}
        status = APInvoiceStatus(invoice.get("status") or APInvoiceStatus.RECEIVED.value)
        processor = self.chain.get(status)
        if processor is None:
            return APProcessorResult(
                next_status=status,
                log_entry=f"No processor registered for status={status.value}",
            )
        return processor(invoice, ctx)

    def run_until_blocked(
        self,
        invoice: dict,
        ctx: Optional[dict] = None,
        max_steps: int = 10,
    ) -> list[APProcessorResult]:
        """Drive the invoice forward until it hits a status we can't auto-advance.

        Terminal states:
          AWAITING_APPROVAL, REJECTED, SCHEDULED, PAID, ERROR
        Returns the full trace so callers can persist it to pipeline_log.
        """
        ctx = ctx or {}
        trace: list[APProcessorResult] = []
        for _ in range(max_steps):
            result = self.step(invoice, ctx)
            trace.append(result)
            invoice.update(result.extracted)
            invoice["status"] = result.next_status.value
            if result.next_status in (
                APInvoiceStatus.AWAITING_APPROVAL,
                APInvoiceStatus.REJECTED,
                APInvoiceStatus.SCHEDULED,
                APInvoiceStatus.PAID,
                APInvoiceStatus.ERROR,
            ):
                break
        return trace
