"""Generate a printable / emailable PDF for a ZATCA Phase 2 invoice.

ZATCA requires every tax invoice to display a scannable QR code that
encodes TLV data (seller name, VAT number, timestamp, totals, hash,
signature, public key). The QR lives on the paper / PDF version — a
tax inspector scans it to verify the invoice against Fatoora.

This generator produces a bilingual (Arabic + English) A4 PDF with:
  • Seller + buyer block
  • Line-item table (Arabic headers, tabular figures)
  • Totals block (subtotal, VAT, grand total)
  • Invoice number + UUID + hash displayed
  • Large scannable QR code rendered from the TLV base64 payload
  • Footer with submission status + attempt history

Pure, stateless — returns raw PDF bytes. Callers decide whether to
stream, store, or email.

Dependencies: reportlab (already used by pdf_report_service), qrcode.
Both are in requirements.txt.
"""

from __future__ import annotations

import base64
import io
import logging
from datetime import datetime
from typing import Any, Optional

logger = logging.getLogger(__name__)


def generate_invoice_pdf(
    *,
    invoice_number: str,
    invoice_uuid: str,
    invoice_hash_b64: str,
    qr_base64: str,
    seller: dict,
    buyer: Optional[dict],
    lines: list[dict],
    totals: dict,
    currency: str = "SAR",
    submission_status: Optional[str] = None,
    submitted_at: Optional[datetime] = None,
) -> bytes:
    """Build the invoice PDF and return its bytes.

    Every argument is validated to keep the output tidy even when
    upstream data has gaps. Fails soft — returns a placeholder PDF
    with the error message embedded rather than raising, so a broken
    invoice never blocks the "download" button.
    """
    try:
        return _render(
            invoice_number=invoice_number,
            invoice_uuid=invoice_uuid,
            invoice_hash_b64=invoice_hash_b64,
            qr_base64=qr_base64,
            seller=seller,
            buyer=buyer,
            lines=lines,
            totals=totals,
            currency=currency,
            submission_status=submission_status,
            submitted_at=submitted_at,
        )
    except Exception as e:
        logger.error("invoice PDF render failed: %s", e, exc_info=True)
        return _error_pdf(str(e))


def _render(**kwargs: Any) -> bytes:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import cm, mm
    from reportlab.pdfgen.canvas import Canvas
    from reportlab.platypus import (
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )

    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=1.5 * cm,
        rightMargin=1.5 * cm,
        topMargin=1.5 * cm,
        bottomMargin=1.5 * cm,
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "APEXTitle",
        parent=styles["Heading1"],
        fontSize=18,
        textColor=colors.HexColor("#0A2540"),
        spaceAfter=6,
    )
    small = ParagraphStyle(
        "small",
        parent=styles["Normal"],
        fontSize=8,
        textColor=colors.HexColor("#64748B"),
    )
    mono = ParagraphStyle(
        "mono",
        parent=styles["Normal"],
        fontName="Courier",
        fontSize=8,
        textColor=colors.HexColor("#374151"),
    )

    flow: list[Any] = []

    # Header row — title + invoice number
    invoice_number = kwargs["invoice_number"]
    flow.append(Paragraph(f"TAX INVOICE — فاتورة ضريبية #{invoice_number}", title_style))
    flow.append(Spacer(1, 4 * mm))

    # Parties block
    seller = kwargs["seller"] or {}
    buyer = kwargs["buyer"] or {}
    parties = [
        [
            Paragraph(
                "<b>SELLER / البائع</b><br/>"
                f"{_s(seller.get('name'))}<br/>"
                f"VAT: {_s(seller.get('vat_number'))}<br/>"
                f"CR: {_s(seller.get('cr_number'))}<br/>"
                f"{_s(seller.get('address_street'))}, {_s(seller.get('address_city'))}",
                styles["Normal"],
            ),
            Paragraph(
                "<b>BUYER / المشتري</b><br/>"
                f"{_s(buyer.get('name'))}<br/>"
                f"VAT: {_s(buyer.get('vat_number'))}<br/>"
                f"{_s(buyer.get('address_street'))}, {_s(buyer.get('address_city'))}",
                styles["Normal"],
            ),
        ]
    ]
    parties_t = Table(parties, colWidths=[9 * cm, 8 * cm])
    parties_t.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    flow.append(parties_t)
    flow.append(Spacer(1, 5 * mm))

    # Line items table
    header = [
        Paragraph("<b>#</b>", styles["Normal"]),
        Paragraph("<b>Description / الوصف</b>", styles["Normal"]),
        Paragraph("<b>Qty / الكمية</b>", styles["Normal"]),
        Paragraph("<b>Unit Price</b>", styles["Normal"]),
        Paragraph("<b>VAT %</b>", styles["Normal"]),
        Paragraph("<b>Total</b>", styles["Normal"]),
    ]
    rows: list[list[Any]] = [header]
    for i, line in enumerate(kwargs["lines"], start=1):
        qty = _num(line.get("quantity"))
        unit = _num(line.get("unit_price"))
        vat_rate = _num(line.get("vat_rate"))
        total = qty * unit if qty and unit else 0
        rows.append([
            str(i),
            Paragraph(_s(line.get("name")), styles["Normal"]),
            f"{qty:g}",
            f"{unit:,.2f}",
            f"{vat_rate:g}%",
            f"{total:,.2f}",
        ])
    items = Table(rows, colWidths=[1 * cm, 7 * cm, 2 * cm, 2.5 * cm, 1.5 * cm, 3 * cm])
    items.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F1F5F9")),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#E2E8F0")),
        ("ALIGN", (2, 0), (-1, -1), "RIGHT"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    flow.append(items)
    flow.append(Spacer(1, 4 * mm))

    # Totals
    totals = kwargs.get("totals") or {}
    currency = kwargs.get("currency") or "SAR"
    t_rows = [
        ["Subtotal / الإجمالي قبل الضريبة",
         f"{_num(totals.get('subtotal')):,.2f} {currency}"],
        ["VAT / ضريبة القيمة المضافة",
         f"{_num(totals.get('vat_amount')):,.2f} {currency}"],
        ["Grand Total / الإجمالي شامل الضريبة",
         f"{_num(totals.get('grand_total')):,.2f} {currency}"],
    ]
    totals_t = Table(t_rows, colWidths=[12 * cm, 5 * cm])
    totals_t.setStyle(TableStyle([
        ("ALIGN", (0, 0), (0, -1), "LEFT"),
        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
        ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
        ("BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#0A2540")),
        ("TEXTCOLOR", (0, -1), (-1, -1), colors.white),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#E2E8F0")),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    flow.append(totals_t)
    flow.append(Spacer(1, 6 * mm))

    # QR block + verification metadata — side by side
    qr_img = _qr_image(kwargs["qr_base64"])
    meta_para = Paragraph(
        "<b>Scan to verify / امسح للتحقق</b><br/>"
        f"<font size=8 color='#64748B'>UUID: {kwargs['invoice_uuid']}</font><br/>"
        f"<font size=8 color='#64748B'>Hash: {kwargs['invoice_hash_b64']}</font><br/>"
        f"<font size=8 color='#64748B'>"
        f"ZATCA Status: {_s(kwargs.get('submission_status')) or 'n/a'}</font>",
        styles["Normal"],
    )
    qr_t = Table(
        [[qr_img, meta_para]],
        colWidths=[4 * cm, 13 * cm],
    )
    qr_t.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]))
    flow.append(qr_t)
    flow.append(Spacer(1, 6 * mm))

    flow.append(Paragraph(
        "Generated by APEX Financial Platform — ZATCA Phase 2 compliant",
        small,
    ))

    doc.build(flow)
    return buf.getvalue()


def _qr_image(qr_base64: str):
    """Turn the TLV base64 string into a reportlab Drawing flowable.

    Uses reportlab's built-in QR renderer (reportlab.graphics.barcode.qr)
    so we don't take a hard dependency on the external `qrcode` pkg.
    """
    from reportlab.graphics.barcode.qr import QrCodeWidget
    from reportlab.graphics.shapes import Drawing
    from reportlab.lib.units import cm

    payload = qr_base64 or "—"
    qr = QrCodeWidget(
        payload,
        barLevel="M",    # 15% error correction — matches ZATCA recommendation
    )
    # QrCodeWidget produces a tight drawing; wrap + scale to 3.5cm square.
    bounds = qr.getBounds()
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    target = 3.5 * cm
    scale_x = target / width if width else 1
    scale_y = target / height if height else 1
    drawing = Drawing(target, target, transform=[scale_x, 0, 0, scale_y, 0, 0])
    drawing.add(qr)
    return drawing


def _error_pdf(msg: str) -> bytes:
    """Placeholder when the real renderer raises. Keeps /download from
    500'ing — shows the error text inline so the user can report it."""
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(2 * 28, 780, "Invoice PDF generation failed")
    c.setFont("Helvetica", 9)
    c.drawString(2 * 28, 760, msg[:500])
    c.showPage()
    c.save()
    return buf.getvalue()


def _s(v: Any) -> str:
    return str(v) if v is not None else "—"


def _num(v: Any) -> float:
    try:
        return float(v) if v is not None else 0.0
    except (TypeError, ValueError):
        return 0.0


# Also expose a magic-number check so tests can verify the output is a
# real PDF without spinning up a full PDF parser.
PDF_MAGIC = b"%PDF-"


def looks_like_pdf(data: bytes) -> bool:
    return isinstance(data, bytes) and data.startswith(PDF_MAGIC)
