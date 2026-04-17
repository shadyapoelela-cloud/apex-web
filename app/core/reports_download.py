"""Report download endpoint that materialises the URL the Copilot
`generate_report` tool hands out.

The tool returns a URL shaped like:
    /api/v1/reports/download/<report_type>_<period>_<format>

This module parses that slug, invokes the right report writer, and
streams bytes back to the client with the right content-type. Today's
writers are deterministic placeholders so the loop is testable; a real
deployment swaps them for queries against journal_entries.

Formats supported: pdf / excel / csv.
"""
from __future__ import annotations

import csv
import io
import logging
import re
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.core.api_version import v1_prefix

logger = logging.getLogger(__name__)

router = APIRouter(prefix=v1_prefix("/reports"), tags=["Reports"])

_ALLOWED_TYPES = {
    "profit_and_loss",
    "balance_sheet",
    "cash_flow",
    "trial_balance",
    "aging_report",
    "vat_return",
    "zakat_return",
}
_ALLOWED_FORMATS = {"pdf", "excel", "csv"}


def _parse_slug(slug: str) -> tuple[str, str, str]:
    """Turn '<type>_<period>_<fmt>' back into (type, period, fmt).

    Period may itself contain underscores if it was encoded from an ISO
    range (e.g. '2026-04-01_2026-04-30'), so we split from the right.
    """
    if not slug:
        raise HTTPException(status_code=400, detail="slug required")
    parts = slug.rsplit("_", 1)
    if len(parts) != 2:
        raise HTTPException(status_code=400, detail="malformed slug")
    head, fmt = parts
    if fmt not in _ALLOWED_FORMATS:
        raise HTTPException(status_code=400, detail=f"unsupported format: {fmt}")
    # Split the head once more: type is the left token that matches our
    # allowed types. Period is whatever follows.
    for t in sorted(_ALLOWED_TYPES, key=len, reverse=True):
        prefix = f"{t}_"
        if head.startswith(prefix):
            return t, head[len(prefix):], fmt
    raise HTTPException(status_code=400, detail="unknown report type")


def _sample_rows(report_type: str) -> list[dict[str, Any]]:
    """Deterministic sample data so the bytes are meaningful in tests."""
    if report_type == "profit_and_loss":
        return [
            {"account": "4001 — Revenue",      "debit": 0,    "credit": 520000},
            {"account": "5001 — Payroll",      "debit": 180000, "credit": 0},
            {"account": "5201 — Rent",         "debit": 24000,  "credit": 0},
            {"account": "5301 — Marketing",    "debit": 42000,  "credit": 0},
            {"account": "5502 — Cloud / AWS",  "debit": 18000,  "credit": 0},
            {"account": "Net income",          "debit": 256000, "credit": 0},
        ]
    if report_type == "trial_balance":
        return [
            {"account": "1001 — Cash",         "debit": 450000, "credit": 0},
            {"account": "1201 — AR",           "debit": 82000,  "credit": 0},
            {"account": "2101 — AP",           "debit": 0,      "credit": 38000},
            {"account": "2401 — VAT payable",  "debit": 0,      "credit": 12600},
            {"account": "3001 — Equity",       "debit": 0,      "credit": 481400},
        ]
    if report_type == "aging_report":
        return [
            {"bucket": "0-30 days",  "count": 12, "amount": 145000},
            {"bucket": "31-60 days", "count": 5,  "amount":  62000},
            {"bucket": "61-90 days", "count": 2,  "amount":  18500},
            {"bucket": "> 90 days",  "count": 1,  "amount":   4200},
        ]
    # Every other type: empty for now
    return [{"_note": f"{report_type} writer not yet implemented"}]


def _csv_bytes(rows: list[dict]) -> bytes:
    if not rows:
        return b""
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()))
    writer.writeheader()
    writer.writerows(rows)
    # Prepend BOM so Excel opens UTF-8 Arabic correctly.
    return "\ufeff".encode("utf-8") + buf.getvalue().encode("utf-8")


def _excel_bytes(rows: list[dict], sheet_name: str) -> bytes:
    """Produces a minimal xlsx using openpyxl. Falls back to CSV bytes
    with Excel-friendly BOM if openpyxl isn't available."""
    try:
        from openpyxl import Workbook
    except ImportError:
        logger.info("openpyxl not available, falling back to CSV bytes")
        return _csv_bytes(rows)
    wb = Workbook()
    ws = wb.active
    ws.title = sheet_name[:31] or "Report"
    if rows:
        headers = list(rows[0].keys())
        ws.append(headers)
        for r in rows:
            ws.append([r.get(h) for h in headers])
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _pdf_bytes(rows: list[dict], report_type: str, period: str) -> bytes:
    """Very small reportlab table PDF. Re-uses the style dict from the
    invoice PDF so the look matches."""
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import cm
    from reportlab.platypus import (
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )
    from reportlab.lib.styles import getSampleStyleSheet

    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4, leftMargin=1.5 * cm,
                            rightMargin=1.5 * cm, topMargin=1.5 * cm,
                            bottomMargin=1.5 * cm)
    styles = getSampleStyleSheet()
    flow: list[Any] = [
        Paragraph(f"<b>{report_type}</b> — {period}", styles["Heading1"]),
        Spacer(1, 0.5 * cm),
    ]
    if rows:
        headers = list(rows[0].keys())
        data = [headers] + [[r.get(h, "") for h in headers] for r in rows]
        t = Table(data, repeatRows=1)
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0A2540")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("ALIGN", (0, 0), (-1, 0), "CENTER"),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        flow.append(t)
    else:
        flow.append(Paragraph("No data.", styles["Normal"]))

    flow.append(Spacer(1, 1 * cm))
    flow.append(Paragraph(
        f"<font size=8 color='#64748B'>"
        f"Generated by APEX at {datetime.now(timezone.utc).isoformat()}</font>",
        styles["Normal"],
    ))
    doc.build(flow)
    return buf.getvalue()


@router.get("/download/{slug}")
def download_report(slug: str):
    """Materialise a report URL handed out by the Copilot generate_report tool.

    Returns the file as a Response with the correct content-type and
    inline Content-Disposition so browsers open it in a new tab.
    """
    # Whitelist characters to avoid path / injection surprises.
    if not re.match(r"^[A-Za-z0-9_\-:.]+$", slug):
        raise HTTPException(status_code=400, detail="bad slug")
    report_type, period, fmt = _parse_slug(slug)

    rows = _sample_rows(report_type)
    filename = f"{report_type}_{period}.{fmt if fmt != 'excel' else 'xlsx'}"

    if fmt == "csv":
        return Response(
            content=_csv_bytes(rows),
            media_type="text/csv; charset=utf-8",
            headers={"Content-Disposition": f'inline; filename="{filename}"'},
        )
    if fmt == "excel":
        return Response(
            content=_excel_bytes(rows, report_type),
            media_type=(
                "application/vnd.openxmlformats-officedocument."
                "spreadsheetml.sheet"
            ),
            headers={"Content-Disposition": f'inline; filename="{filename}"'},
        )
    # pdf
    return Response(
        content=_pdf_bytes(rows, report_type, period),
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )
