"""ZATCA end-to-end submission route.

Takes a built (or fresh) simplified e-invoice and runs the full
production pipeline:

  1. Build UBL 2.1 XML + TLV QR + SHA-256 hash   (via zatca_service)
  2. Sign the hash with ECDSA                    (via signer)
  3. Submit to Fatoora reporting endpoint        (via fatoora_client)
  4. On transient error → enqueue to retry queue (via retry_queue)
  5. Return the submission id + current status

This is the one route a front-end needs to call to "send the invoice
to ZATCA". Everything else (retry timing, certificate rotation,
eventual clearance) happens server-side.

Route: POST /api/v1/zatca/submit-e2e
Body : reuses InvoiceBuildRequest from zatca_routes.
Returns: { success, data: { submission_id, status, invoice_number,
          qr_base64, invoice_hash_b64, terminal, errors } }
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.api_version import v1_prefix
from app.core.zatca_service import (
    ZatcaBuyer,
    ZatcaLineItem,
    ZatcaSeller,
    build_simplified_invoice,
)
from app.integrations.zatca.retry_queue import (
    ZatcaSubmission,
    ZatcaSubmissionStatus,
    attempt_next,
    enqueue_submission,
)
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)

# ── Pydantic schemas (light, non-strict — we validate deeper in service) ─


class LineIn(BaseModel):
    name: str
    quantity: str
    unit_price: str
    vat_rate: str = "15.00"
    discount: str = "0"


class SellerIn(BaseModel):
    name: str
    vat_number: str = Field(..., min_length=15, max_length=15)
    cr_number: Optional[str] = None
    address_street: str
    address_city: str
    address_postal: str
    country_code: str = "SA"


class BuyerIn(BaseModel):
    name: str
    vat_number: Optional[str] = None
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    country_code: str = "SA"


class SubmitE2ERequest(BaseModel):
    client_id: int = Field(..., ge=1)
    fiscal_year: int = Field(..., ge=2020, le=2099)
    invoice_number: Optional[str] = None
    seller: SellerIn
    buyer: Optional[BuyerIn] = None
    lines: list[LineIn]
    currency: str = "SAR"
    previous_invoice_hash_b64: Optional[str] = None
    retry_on_transient: bool = True


# ── Router ────────────────────────────────────────────────


router = APIRouter(prefix=v1_prefix("/zatca"), tags=["ZATCA E2E"])


def _decimal_from(raw: str, field: str):
    from decimal import Decimal, InvalidOperation
    try:
        return Decimal(str(raw))
    except (InvalidOperation, ValueError):
        raise HTTPException(status_code=422, detail=f"{field} must be numeric")


@router.post("/submit-e2e")
def submit_e2e(body: SubmitE2ERequest) -> dict[str, Any]:
    """Build + submit a ZATCA simplified e-invoice in one call."""
    # 1. Build UBL XML + QR + hash
    lines = [
        ZatcaLineItem(
            name=ln.name,
            quantity=_decimal_from(ln.quantity, f"lines[{i}].quantity"),
            unit_price=_decimal_from(ln.unit_price, f"lines[{i}].unit_price"),
            vat_rate=_decimal_from(ln.vat_rate, f"lines[{i}].vat_rate"),
            discount=_decimal_from(ln.discount, f"lines[{i}].discount"),
        )
        for i, ln in enumerate(body.lines)
    ]
    seller = ZatcaSeller(
        name=body.seller.name,
        vat_number=body.seller.vat_number,
        cr_number=body.seller.cr_number,
        address_street=body.seller.address_street,
        address_city=body.seller.address_city,
        address_postal=body.seller.address_postal,
        country_code=body.seller.country_code,
    )
    buyer = None
    if body.buyer is not None:
        buyer = ZatcaBuyer(
            name=body.buyer.name,
            vat_number=body.buyer.vat_number,
            address_street=body.buyer.address_street,
            address_city=body.buyer.address_city,
            country_code=body.buyer.country_code,
        )
    try:
        built = build_simplified_invoice(
            seller=seller,
            buyer=buyer,
            lines=lines,
            # compliance_service.next_journal_entry_number expects
            # client_id + fiscal_year as *strings* — be permissive at
            # the route boundary.
            client_id=str(body.client_id),
            fiscal_year=str(body.fiscal_year),
            invoice_number=body.invoice_number,
            previous_invoice_hash_b64=body.previous_invoice_hash_b64,
            currency=body.currency,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    # 2. Enqueue + first attempt
    submission_id = enqueue_submission(
        invoice_uuid=built.uuid,
        invoice_number=built.invoice_number,
        invoice_hash_b64=built.invoice_hash_b64,
        invoice_type="reporting",
        signed_xml=built.xml,
    )

    # 3. Kick off the first attempt (sync, best-effort)
    try:
        result = attempt_next(submission_id)
    except Exception as e:
        # Retry worker will try again later via the scheduler.
        logger.warning("ZATCA first attempt crashed: %s", e)
        result = {"success": False, "status": "error", "error": str(e)}

    # 4. Read back the submission row for full context
    db = SessionLocal()
    try:
        sub = (
            db.query(ZatcaSubmission)
            .filter(ZatcaSubmission.id == submission_id)
            .first()
        )
    finally:
        db.close()

    terminal = result.get("terminal") or (
        sub.status in (
            ZatcaSubmissionStatus.CLEARED.value,
            ZatcaSubmissionStatus.REPORTED.value,
            ZatcaSubmissionStatus.REJECTED.value,
            ZatcaSubmissionStatus.DEAD.value,
        )
        if sub else False
    )

    return {
        "success": True,
        "data": {
            "submission_id": submission_id,
            "status": sub.status if sub else "unknown",
            "attempts": sub.attempts if sub else 0,
            "invoice_uuid": built.uuid,
            "invoice_number": built.invoice_number,
            "invoice_hash_b64": built.invoice_hash_b64,
            "qr_base64": built.qr_b64,
            "totals": built.totals,
            "terminal": terminal,
            "errors": sub.errors if sub else None,
            "next_attempt_at": (
                sub.next_attempt_at.isoformat()
                if sub and sub.next_attempt_at else None
            ),
        },
    }


@router.get("/submission/{submission_id}")
def get_submission(submission_id: str) -> dict[str, Any]:
    """Poll current status of a previously-submitted invoice."""
    db = SessionLocal()
    try:
        sub = (
            db.query(ZatcaSubmission)
            .filter(ZatcaSubmission.id == submission_id)
            .first()
        )
        if sub is None:
            raise HTTPException(status_code=404, detail="submission not found")
        return {
            "success": True,
            "data": {
                "submission_id": sub.id,
                "invoice_number": sub.invoice_number,
                "invoice_uuid": sub.invoice_uuid,
                "status": sub.status,
                "attempts": sub.attempts,
                "last_http_status": sub.last_http_status,
                "last_error": sub.last_error,
                "last_attempt_at": (
                    sub.last_attempt_at.isoformat()
                    if sub.last_attempt_at else None
                ),
                "next_attempt_at": (
                    sub.next_attempt_at.isoformat()
                    if sub.next_attempt_at else None
                ),
                "completed_at": (
                    sub.completed_at.isoformat()
                    if sub.completed_at else None
                ),
                "errors": sub.errors,
                "warnings": sub.warnings,
                "terminal": sub.status in (
                    ZatcaSubmissionStatus.CLEARED.value,
                    ZatcaSubmissionStatus.REPORTED.value,
                    ZatcaSubmissionStatus.REJECTED.value,
                    ZatcaSubmissionStatus.DEAD.value,
                ),
            },
        }
    finally:
        db.close()
