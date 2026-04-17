"""
APEX Platform — Invoice OCR Extraction
═══════════════════════════════════════════════════════════════
Pattern-based text extraction from uploaded invoice content.

Accepts plain text (from the caller who already ran OCR — e.g.
client-side Tesseract.js, or a manual paste). Matches common
invoice patterns:
  - invoice number
  - dates (multiple Arabic/English formats)
  - amounts (total, subtotal, VAT)
  - seller / buyer VAT numbers (15-digit KSA)
  - line items (heuristic — qty × price → total)

For true image→text OCR, callers should integrate Google Vision /
AWS Textract / Tesseract. The extraction layer here is deterministic
and auditable (no ML hallucinations), making it safe for
accounting use.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from typing import List, Optional


_VAT_RE = re.compile(r"\b(3\d{13}3)\b")
# Invoice number: common prefixes (INV, فاتورة, رقم) followed by id.
# We prefer identifiers that include a letter prefix ("INV-...").
_INVOICE_PREFIXED_RE = re.compile(
    r"\b(INV[-_ ]?\d[\w\-/]{0,28}|فاتورة[\s#:\-]*[A-Z0-9]{2,}[\w\-/]{0,28})",
    re.IGNORECASE,
)
_INVOICE_FALLBACK_RE = re.compile(
    r"(?:فاتورة رقم|Invoice\s*(?:#|No\.?|Number)?)[\s:\-]*"
    r"([A-Za-z0-9][A-Za-z0-9\-/_]{2,30})",
    re.IGNORECASE,
)
# YYYY-MM-DD | DD/MM/YYYY | DD-MM-YYYY
_DATE_RE = re.compile(
    r"(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})"
)
# Line-based amount detection: we scan lines for label + amount pair
_AMOUNT_LINE_RE = re.compile(
    r"(?P<amount>[\d,]+(?:\.\d{1,2})?)\s*(?:SAR|ريال|\u0631\.\u0633)?\s*$"
)


@dataclass
class OcrExtractionInput:
    text: str = ""
    # Optional locale hints
    jurisdiction: str = "SA"


@dataclass
class OcrField:
    label_ar: str
    label_en: str
    value: str
    confidence: str          # 'high' | 'medium' | 'low'


@dataclass
class OcrExtraction:
    raw_text_length: int
    invoice_number: Optional[str]
    invoice_date: Optional[str]
    total_amount: Optional[Decimal]
    subtotal: Optional[Decimal]
    vat_amount: Optional[Decimal]
    seller_vat: Optional[str]
    seller_vat_valid: Optional[bool]
    buyer_vat: Optional[str]
    buyer_vat_valid: Optional[bool]
    fields: List[OcrField] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════


_AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def _normalise(text: str) -> str:
    return text.translate(_AR_DIGITS)


def _to_decimal(s: str) -> Optional[Decimal]:
    try:
        return Decimal(s.replace(",", "").strip())
    except (InvalidOperation, ValueError, TypeError):
        return None


def _validate_vat(vat: str) -> bool:
    return bool(_VAT_RE.fullmatch(vat or ""))


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════


def extract_invoice(inp: OcrExtractionInput) -> OcrExtraction:
    text = _normalise(inp.text or "")
    warnings: list[str] = []
    fields: List[OcrField] = []

    if not text.strip():
        raise ValueError("text is empty — provide OCR output as input")

    # ── VAT numbers ────────────────────────────────────────────
    vats = _VAT_RE.findall(text)
    seller_vat = vats[0] if vats else None
    buyer_vat = vats[1] if len(vats) > 1 else None

    if seller_vat:
        fields.append(OcrField(
            "الرقم الضريبي للبائع", "Seller VAT", seller_vat, "high"
        ))
    if buyer_vat:
        fields.append(OcrField(
            "الرقم الضريبي للمشتري", "Buyer VAT", buyer_vat, "high"
        ))

    # ── Invoice number ─────────────────────────────────────────
    # Try prefixed pattern first (captures "INV-..." in one piece),
    # then fall back to "Invoice #..." extraction.
    inv_num = None
    m = _INVOICE_PREFIXED_RE.search(text)
    if m:
        inv_num = m.group(1).strip().rstrip(".,:;")
    else:
        m = _INVOICE_FALLBACK_RE.search(text)
        if m:
            inv_num = m.group(1).strip().rstrip(".,:;")
    if inv_num:
        fields.append(OcrField("رقم الفاتورة", "Invoice #", inv_num, "medium"))

    # ── Date ───────────────────────────────────────────────────
    m2 = _DATE_RE.search(text)
    inv_date = None
    if m2:
        inv_date = m2.group(1).strip()
        fields.append(OcrField("تاريخ الفاتورة", "Invoice date", inv_date, "medium"))

    # ── Amounts (scan line-by-line for label + amount) ─────────
    total_amount = None
    subtotal = None
    vat_amount = None
    for line in text.splitlines():
        line_lower = line.lower()
        m3 = _AMOUNT_LINE_RE.search(line)
        if not m3:
            continue
        amt = _to_decimal(m3.group("amount"))
        if amt is None:
            continue
        is_subtotal = (
            "قبل الضريبة" in line or "بدون الضريبة" in line or "صافي" in line
            or "subtotal" in line_lower or "sub-total" in line_lower
            or "net amount" in line_lower
        )
        is_vat = (
            "ضريبة" in line or "vat" in line_lower or "tax" in line_lower
        ) and not is_subtotal
        is_total = (
            ("إجمالي" in line or "مجموع" in line
             or "total" in line_lower or "grand" in line_lower)
            and not is_subtotal and not is_vat
        )
        if is_subtotal:
            subtotal = amt
        elif is_vat and vat_amount is None:
            vat_amount = amt
        elif is_total:
            if total_amount is None or amt > total_amount:
                total_amount = amt

    if total_amount is not None:
        fields.append(OcrField(
            "الإجمالي", "Total",
            f"{total_amount:.2f}", "medium"
        ))
    if vat_amount is not None:
        fields.append(OcrField(
            "الضريبة", "VAT",
            f"{vat_amount:.2f}", "medium"
        ))
    if subtotal is not None:
        fields.append(OcrField(
            "المجموع قبل الضريبة", "Subtotal",
            f"{subtotal:.2f}", "medium"
        ))

    # ── Validations / warnings ─────────────────────────────────
    if not seller_vat:
        warnings.append(
            "لم يُعثَر على الرقم الضريبي للبائع (15 رقم). "
            "تأكد من وضوح صورة الفاتورة."
        )
    elif not _validate_vat(seller_vat):
        warnings.append(
            f"الرقم الضريبي {seller_vat} لا يطابق صيغة ZATCA (يبدأ وينتهي بـ 3)."
        )

    if total_amount is None:
        warnings.append("لم يُعثَر على إجمالي الفاتورة.")

    # Consistency check
    if total_amount and subtotal and vat_amount:
        expected_total = subtotal + vat_amount
        if abs(expected_total - total_amount) > Decimal("0.10"):
            warnings.append(
                f"عدم اتساق: subtotal ({subtotal}) + vat ({vat_amount}) = {expected_total} "
                f"≠ total ({total_amount}). راجع الصورة."
            )

    return OcrExtraction(
        raw_text_length=len(text),
        invoice_number=inv_num,
        invoice_date=inv_date,
        total_amount=total_amount,
        subtotal=subtotal,
        vat_amount=vat_amount,
        seller_vat=seller_vat,
        seller_vat_valid=_validate_vat(seller_vat) if seller_vat else None,
        buyer_vat=buyer_vat,
        buyer_vat_valid=_validate_vat(buyer_vat) if buyer_vat else None,
        fields=fields,
        warnings=warnings,
    )


def result_to_dict(r: OcrExtraction) -> dict:
    def _s(v):
        return None if v is None else (f"{v}" if hasattr(v, "quantize") else str(v))
    return {
        "raw_text_length": r.raw_text_length,
        "invoice_number": r.invoice_number,
        "invoice_date": r.invoice_date,
        "total_amount": _s(r.total_amount),
        "subtotal": _s(r.subtotal),
        "vat_amount": _s(r.vat_amount),
        "seller_vat": r.seller_vat,
        "seller_vat_valid": r.seller_vat_valid,
        "buyer_vat": r.buyer_vat,
        "buyer_vat_valid": r.buyer_vat_valid,
        "fields": [
            {
                "label_ar": f.label_ar,
                "label_en": f.label_en,
                "value": f.value,
                "confidence": f.confidence,
            }
            for f in r.fields
        ],
        "warnings": r.warnings,
    }
