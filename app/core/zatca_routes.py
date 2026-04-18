"""
APEX Platform — ZATCA (Fatoora) API routes.

Endpoints:
  POST /zatca/validate-vat      -> validate 15-digit KSA VAT number
  POST /zatca/qr                -> build TLV QR payload only (no XML)
  POST /zatca/invoice/build     -> build full simplified e-invoice package
                                   (UBL XML + hash + QR + ICV allocation)
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.zatca_error_translator import (
    explain_code,
    translate_rejection,
)
from app.core.zatca_service import (
    ZatcaBuyer,
    ZatcaLineItem,
    ZatcaSeller,
    build_simplified_invoice,
    build_tlv_qr,
    validate_vat_number,
)

router = APIRouter(prefix="/zatca", tags=["ZATCA"])


# ══════════════════════════════════════════════════════════════
# Auth helper (same pattern as compliance_routes)
# ══════════════════════════════════════════════════════════════


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


# ══════════════════════════════════════════════════════════════
# Pydantic request models
# ══════════════════════════════════════════════════════════════


class VatValidateRequest(BaseModel):
    vat_number: str = Field(..., min_length=1, max_length=20)


class QrRequest(BaseModel):
    seller_name: str = Field(..., min_length=1, max_length=200)
    vat_number: str = Field(..., min_length=15, max_length=15)
    issue_datetime: datetime
    total_with_vat: str = Field(..., description="Decimal as string, e.g. '115.00'")
    vat_total: str = Field(..., description="Decimal as string, e.g. '15.00'")


class InvoiceLineRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=300)
    quantity: str = Field(..., description="Decimal as string")
    unit_price: str = Field(..., description="Decimal as string, excl VAT")
    vat_rate: str = Field(default="15.00")
    discount: str = Field(default="0")


class SellerRequest(BaseModel):
    name: str = Field(..., min_length=1)
    vat_number: str = Field(..., min_length=15, max_length=15)
    cr_number: Optional[str] = None
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    address_postal: Optional[str] = None
    country_code: str = "SA"


class BuyerRequest(BaseModel):
    name: Optional[str] = None
    vat_number: Optional[str] = None
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    country_code: str = "SA"


class InvoiceBuildRequest(BaseModel):
    seller: SellerRequest
    buyer: Optional[BuyerRequest] = None
    lines: list[InvoiceLineRequest] = Field(..., min_length=1)
    client_id: str = Field(..., min_length=1)
    fiscal_year: str = Field(..., pattern=r"^\d{4}$")
    invoice_number: Optional[str] = None
    previous_invoice_hash_b64: Optional[str] = None
    currency: str = Field(default="SAR", max_length=3)


def _decimal(value: str, field_name: str) -> Decimal:
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {field_name}: {value!r}")


# ══════════════════════════════════════════════════════════════
# Endpoints
# ══════════════════════════════════════════════════════════════


@router.post("/validate-vat")
async def validate_vat(body: VatValidateRequest, user_id: str = Depends(_auth)):
    ok = validate_vat_number(body.vat_number)
    return {
        "success": True,
        "data": {
            "vat_number": body.vat_number,
            "valid": ok,
            "reason": None if ok else (
                "رقم التسجيل الضريبي يجب أن يكون 15 رقمًا يبدأ وينتهي بالرقم 3"
            ),
        },
    }


@router.post("/qr")
async def build_qr(body: QrRequest, user_id: str = Depends(_auth)):
    if not validate_vat_number(body.vat_number):
        raise HTTPException(status_code=422, detail="Invalid KSA VAT number")
    total = _decimal(body.total_with_vat, "total_with_vat")
    vat = _decimal(body.vat_total, "vat_total")
    qr = build_tlv_qr(
        seller_name=body.seller_name,
        vat_number=body.vat_number,
        issue_datetime=body.issue_datetime,
        total_with_vat=total,
        vat_total=vat,
    )
    return {"success": True, "data": {"qr_base64": qr}}


@router.post("/invoice/build")
async def build_invoice(
    body: InvoiceBuildRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    # Decimalize lines
    lines: list[ZatcaLineItem] = []
    for idx, ln in enumerate(body.lines, start=1):
        lines.append(ZatcaLineItem(
            name=ln.name,
            quantity=_decimal(ln.quantity, f"lines[{idx}].quantity"),
            unit_price=_decimal(ln.unit_price, f"lines[{idx}].unit_price"),
            vat_rate=_decimal(ln.vat_rate, f"lines[{idx}].vat_rate"),
            discount=_decimal(ln.discount, f"lines[{idx}].discount"),
        ))

    seller = ZatcaSeller(
        name=body.seller.name,
        vat_number=body.seller.vat_number,
        cr_number=body.seller.cr_number,
        address_street=body.seller.address_street,
        address_city=body.seller.address_city,
        address_postal=body.seller.address_postal,
        country_code=body.seller.country_code,
    )
    buyer: Optional[ZatcaBuyer] = None
    if body.buyer is not None:
        buyer = ZatcaBuyer(
            name=body.buyer.name,
            vat_number=body.buyer.vat_number,
            address_street=body.buyer.address_street,
            address_city=body.buyer.address_city,
            country_code=body.buyer.country_code,
        )

    try:
        result = build_simplified_invoice(
            seller=seller,
            buyer=buyer,
            lines=lines,
            client_id=body.client_id,
            fiscal_year=body.fiscal_year,
            invoice_number=body.invoice_number,
            previous_invoice_hash_b64=body.previous_invoice_hash_b64,
            currency=body.currency,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    # Audit event (fire-and-forget)
    write_audit_event(
        action="zatca.invoice.build",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="zatca_invoice",
        entity_id=result.uuid,
        after={
            "invoice_number": result.invoice_number,
            "icv": result.icv,
            "totals": result.totals,
            "hash": result.invoice_hash_b64,
        },
    )

    return {
        "success": True,
        "data": {
            "uuid": result.uuid,
            "invoice_number": result.invoice_number,
            "icv": result.icv,
            "invoice_hash_b64": result.invoice_hash_b64,
            "qr_base64": result.qr_b64,
            "totals": result.totals,
            "warnings": result.warnings,
            "xml": result.xml,
        },
    }


# ══════════════════════════════════════════════════════════════
# Error translator — Arabic, human-readable ZATCA rejection explainer.
# Pattern #184 from APEX_GLOBAL_RESEARCH_210.
# ══════════════════════════════════════════════════════════════


@router.get("/errors/explain")
async def explain_error_code(
    code: str,
    _user_id: str = Depends(_auth),
):
    """Look up an Arabic explanation for a ZATCA error code.

    Called by the UI when an accountant clicks "ما معنى هذا الرمز؟"
    on a rejected invoice. Returns a known=False stub with a
    support-handoff message when the code is not yet translated.
    """
    return {"success": True, "data": explain_code(code)}


class TranslateRejectionRequest(BaseModel):
    payload: dict = Field(..., description="The raw ZATCA rejection JSON")


@router.post("/errors/translate")
async def translate_rejection_payload(
    body: TranslateRejectionRequest,
    _user_id: str = Depends(_auth),
):
    """Translate a full ZATCA rejection response to an Arabic summary."""
    summary = translate_rejection(body.payload)
    return {"success": True, "data": summary.to_dict()}
