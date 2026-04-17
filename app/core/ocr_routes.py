"""OCR extraction endpoint."""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.ocr_service import (
    OcrExtractionInput,
    extract_invoice,
    result_to_dict,
)

router = APIRouter(prefix="/ocr", tags=["OCR"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


class OcrRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=50000,
                       description="OCR'd text from client-side (Tesseract.js, Vision API, etc.)")
    jurisdiction: str = Field(default="SA", pattern=r"^[A-Z]{2}$")


@router.post("/invoice/extract")
async def extract_invoice_route(
    body: OcrRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    try:
        result = extract_invoice(OcrExtractionInput(
            text=body.text, jurisdiction=body.jurisdiction,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    write_audit_event(
        action="ocr.invoice.extract",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="ocr_extraction",
        entity_id=result.invoice_number or "unknown",
        metadata={
            "text_len": result.raw_text_length,
            "found_fields": len(result.fields),
            "has_total": result.total_amount is not None,
            "has_vat": result.vat_amount is not None,
        },
    )
    return {"success": True, "data": result_to_dict(result)}
