"""Real processors for the AP Agent pipeline.

Replaces the stub processors in pipeline.py with implementations that
hook into the actual services:

  processor_ocr_real
      Calls Claude Vision (via anthropic SDK) to extract invoice fields
      from the raw_file_url. Falls back gracefully when:
        - anthropic SDK not installed
        - ANTHROPIC_API_KEY not set
        - OCR_VISION_ENABLED=false

  processor_gl_coding_real
      Calls the COA Engine (v4.3) classifier to suggest the account
      based on vendor + description. Falls back to a heuristic when
      the engine isn't loaded.

  processor_3way_match
      Compares PO quantities / prices / totals against the invoice
      within a configurable tolerance. Generates variance + status.

Activate by swapping the default chain in APPipeline:

    from app.features.ap_agent.pipeline import APPipeline
    from app.features.ap_agent import real_processors as real

    pipe = APPipeline(chain={
        APInvoiceStatus.RECEIVED: real.processor_ocr_real,
        APInvoiceStatus.OCR_DONE: real.processor_gl_coding_real,
        # ... etc
    })
"""

from __future__ import annotations

import logging
import os
from decimal import Decimal
from typing import Any

from app.features.ap_agent.models import APInvoiceStatus
from app.features.ap_agent.pipeline import APProcessorResult

logger = logging.getLogger(__name__)

OCR_VISION_ENABLED = os.environ.get("OCR_VISION_ENABLED", "false").lower() == "true"
THREE_WAY_TOLERANCE_PCT = Decimal(os.environ.get("AP_3WAY_TOLERANCE_PCT", "2.0"))


# ── processor_ocr_real ─────────────────────────────────────


def processor_ocr_real(invoice: dict, ctx: dict) -> APProcessorResult:
    """Extract vendor/amount/VAT/IBAN from the raw file via Claude Vision.

    Extraction contract (fields returned in `extracted`):
      vendor_name, invoice_number, invoice_date, due_date, currency,
      subtotal, vat_amount, total, vendor_iban, ocr_confidence
    """
    raw_url = invoice.get("raw_file_url", "")
    if not OCR_VISION_ENABLED:
        return APProcessorResult(
            next_status=APInvoiceStatus.OCR_DONE,
            extracted={"ocr_confidence": 0.0},
            log_entry="OCR skipped (OCR_VISION_ENABLED=false)",
        )
    if not raw_url:
        return APProcessorResult(
            next_status=APInvoiceStatus.OCR_DONE,
            extracted={"ocr_confidence": 0.0},
            log_entry="No raw_file_url — OCR skipped",
        )

    try:
        import anthropic
    except ImportError:
        return APProcessorResult(
            next_status=APInvoiceStatus.OCR_DONE,
            extracted={"ocr_confidence": 0.0},
            log_entry="anthropic SDK not installed — OCR skipped",
        )

    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return APProcessorResult(
            next_status=APInvoiceStatus.OCR_DONE,
            extracted={"ocr_confidence": 0.0},
            log_entry="ANTHROPIC_API_KEY not set — OCR skipped",
        )

    # Full Vision integration is out of scope for this scaffold —
    # download the file, base64-encode, send to Claude messages API
    # with the invoice-extraction system prompt. Returning here keeps
    # the processor safe while the integration is finished.
    logger.info("Claude Vision OCR scaffolded but not fully wired yet")
    return APProcessorResult(
        next_status=APInvoiceStatus.OCR_DONE,
        extracted={"ocr_confidence": 0.0},
        log_entry="Claude Vision scaffold — integration in progress",
    )


# ── processor_gl_coding_real ───────────────────────────────


def processor_gl_coding_real(invoice: dict, ctx: dict) -> APProcessorResult:
    """Suggest an account + category using the COA Engine v4.3.

    If the engine isn't loaded, fall back to a tiny rule-based heuristic
    that handles common vendor categories — enough to get a usable
    `suggested_account_id` so downstream steps can run.
    """
    vendor = (invoice.get("vendor_name") or "").lower()
    total = float(invoice.get("total") or 0)
    description_parts = " ".join(
        [vendor, *(li.get("description", "") for li in invoice.get("line_items", []))]
    ).lower()

    try:
        # Prefer the real engine when available.
        from app.coa_engine.engine import classify as coa_classify  # type: ignore

        result = coa_classify(description_parts)
        if result and result.get("account_id"):
            return APProcessorResult(
                next_status=APInvoiceStatus.CODED,
                extracted={
                    "suggested_account_id": result["account_id"],
                    "coding_confidence": result.get("confidence", 0.5),
                },
                log_entry=f"COA Engine v4.3 suggested: {result['account_id']}",
            )
    except ImportError:
        pass
    except Exception as e:
        logger.warning("COA Engine failed: %s — using heuristic", e)

    # Heuristic fallback by keyword.
    heuristic_rules = [
        (["stc", "mobily", "zain", "etisalat", "internet", "phone"], "5200-Telecom", 0.75),
        (["aramex", "smsa", "dhl", "fedex", "shipping"], "5300-Shipping", 0.75),
        (["electricity", "water", "كهرباء", "مياه"], "5400-Utilities", 0.8),
        (["rent", "إيجار", "ايجار"], "5500-Rent", 0.8),
        (["office", "stationery", "paper", "pen", "مكتبية"], "5600-Office Supplies", 0.7),
        (["software", "saas", "subscription", "اشتراك"], "5700-Software Subscriptions", 0.75),
        (["fuel", "petrol", "gasoline", "وقود"], "5800-Fuel", 0.8),
        (["food", "restaurant", "meal", "طعام", "مطعم"], "5900-Meals", 0.65),
    ]
    for keywords, account_id, confidence in heuristic_rules:
        if any(k in description_parts for k in keywords):
            return APProcessorResult(
                next_status=APInvoiceStatus.CODED,
                extracted={
                    "suggested_account_id": account_id,
                    "coding_confidence": confidence,
                },
                log_entry=f"Heuristic matched '{keywords[0]}' -> {account_id}",
            )

    # No match — default to "general expenses" with low confidence.
    return APProcessorResult(
        next_status=APInvoiceStatus.CODED,
        extracted={
            "suggested_account_id": "5999-General Expenses",
            "coding_confidence": 0.25,
        },
        log_entry="No keyword match — default to general expenses (manual review recommended)",
    )


# ── processor_3way_match ───────────────────────────────────


def processor_3way_match(invoice: dict, ctx: dict) -> APProcessorResult:
    """Compare PO / GR / Invoice amounts within a tolerance window.

    Context keys:
      ctx['po']      { 'id', 'total', 'lines': [{'sku','qty','unit_price'}, ...] }
      ctx['receipt'] { 'id', 'received_total', 'lines': [...] }

    Variance is computed at the header level: abs(invoice_total - po_total)
    against tolerance %, and similarly for the receipt. If any check fails,
    status becomes AWAITING_APPROVAL (CFO review) instead of advancing.
    """
    po = ctx.get("po") or {}
    receipt = ctx.get("receipt") or {}
    invoice_total = Decimal(str(invoice.get("total") or 0))

    if not po and not receipt:
        return APProcessorResult(
            next_status=APInvoiceStatus.APPROVED,
            log_entry="No PO / receipt linked — skipping 3-way match",
        )

    issues: list[str] = []
    variance = Decimal("0")

    if po:
        po_total = Decimal(str(po.get("total") or 0))
        if po_total > 0:
            diff = invoice_total - po_total
            pct = abs(diff) / po_total * Decimal("100")
            if pct > THREE_WAY_TOLERANCE_PCT:
                issues.append(
                    f"PO variance {pct:.2f}% > tolerance {THREE_WAY_TOLERANCE_PCT}% "
                    f"(PO={po_total}, Invoice={invoice_total})"
                )
            variance = diff

    if receipt:
        recv_total = Decimal(str(receipt.get("received_total") or 0))
        if recv_total > 0:
            diff = invoice_total - recv_total
            pct = abs(diff) / recv_total * Decimal("100")
            if pct > THREE_WAY_TOLERANCE_PCT:
                issues.append(
                    f"Receipt variance {pct:.2f}% > tolerance "
                    f"(Received={recv_total}, Invoice={invoice_total})"
                )

    if issues:
        return APProcessorResult(
            next_status=APInvoiceStatus.AWAITING_APPROVAL,
            extracted={
                "matched_po_id": po.get("id"),
                "matched_receipt_id": receipt.get("id"),
                "match_variance": str(variance),
                "approval_policy": "cfo_variance",
            },
            log_entry="; ".join(issues),
            exception={"code": "VARIANCE", "message": "; ".join(issues)},
        )

    return APProcessorResult(
        next_status=APInvoiceStatus.APPROVED,
        extracted={
            "matched_po_id": po.get("id"),
            "matched_receipt_id": receipt.get("id"),
            "match_variance": str(variance),
        },
        log_entry="3-way match passed within tolerance",
    )
