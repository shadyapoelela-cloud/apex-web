"""
APEX — PDF report generation service using ReportLab with Arabic font support
خدمة إنشاء تقارير PDF باستخدام ReportLab مع دعم الخطوط العربية
"""

import os
import io
import tempfile
import urllib.request
from datetime import datetime

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm, cm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# --- Font Setup ---
FONT_DIR = os.path.join(tempfile.gettempdir(), "apex_fonts")
os.makedirs(FONT_DIR, exist_ok=True)

AMIRI_URL = os.environ.get("AMIRI_FONT_URL", "https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Regular.ttf")
AMIRI_BOLD_URL = os.environ.get(
    "AMIRI_BOLD_FONT_URL", "https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Bold.ttf"
)
AMIRI_PATH = os.path.join(FONT_DIR, "Amiri-Regular.ttf")
AMIRI_BOLD_PATH = os.path.join(FONT_DIR, "Amiri-Bold.ttf")

_font_registered = False


def _ensure_fonts():
    global _font_registered
    if _font_registered:
        return True
    try:
        for url, path in [(AMIRI_URL, AMIRI_PATH), (AMIRI_BOLD_URL, AMIRI_BOLD_PATH)]:
            if not os.path.exists(path):
                urllib.request.urlretrieve(url, path)
        pdfmetrics.registerFont(TTFont("Amiri", AMIRI_PATH))
        pdfmetrics.registerFont(TTFont("Amiri-Bold", AMIRI_BOLD_PATH))
        _font_registered = True
        return True
    except Exception as e:
        import logging

        logging.warning(f"Font download failed: {e}")
        return False


def _ar(text):
    """Reshape Arabic text for RTL PDF rendering."""
    if not text:
        return ""
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display

        reshaped = arabic_reshaper.reshape(str(text))
        return get_display(reshaped)
    except ImportError:
        return str(text)


# --- Colors ---
NAVY = colors.HexColor("#1B2A4A")
GOLD = colors.HexColor("#D4A843")
LIGHT_GOLD = colors.HexColor("#FFF8E7")
WHITE = colors.white
GREEN = colors.HexColor("#2ECC8A")
RED = colors.HexColor("#E74C3C")
GRAY = colors.HexColor("#F5F5F5")


def generate_pdf_report(analysis_result: dict, client_name: str = "", user_name: str = "") -> bytes:
    """Generate professional Arabic PDF report from analysis results."""
    has_arabic = _ensure_fonts()
    font_name = "Amiri" if has_arabic else "Helvetica"
    font_bold = "Amiri-Bold" if has_arabic else "Helvetica-Bold"

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer, pagesize=A4, topMargin=2 * cm, bottomMargin=2 * cm, leftMargin=2 * cm, rightMargin=2 * cm
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "TitleAR",
        parent=styles["Title"],
        fontName=font_bold,
        fontSize=22,
        textColor=NAVY,
        alignment=TA_CENTER,
        spaceAfter=10,
    )
    subtitle_style = ParagraphStyle(
        "SubtitleAR",
        parent=styles["Normal"],
        fontName=font_name,
        fontSize=12,
        textColor=GOLD,
        alignment=TA_CENTER,
        spaceAfter=20,
    )
    heading_style = ParagraphStyle(
        "HeadingAR",
        parent=styles["Heading2"],
        fontName=font_bold,
        fontSize=14,
        textColor=NAVY,
        alignment=TA_RIGHT,
        spaceAfter=8,
        spaceBefore=16,
    )
    body_style = ParagraphStyle(
        "BodyAR", parent=styles["Normal"], fontName=font_name, fontSize=10, alignment=TA_RIGHT, leading=16
    )
    ParagraphStyle("CellR", parent=styles["Normal"], fontName=font_name, fontSize=9, alignment=TA_RIGHT)
    ParagraphStyle("CellL", parent=styles["Normal"], fontName=font_name, fontSize=9, alignment=TA_LEFT)

    elements = []

    # --- Header ---
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    elements.append(Paragraph(_ar("APEX"), title_style))
    elements.append(Paragraph(_ar("تقرير التحليل المالي"), subtitle_style))
    elements.append(Spacer(1, 5 * mm))

    # Info table
    info_data = []
    if client_name:
        info_data.append([_ar(client_name), _ar("العميل")])
    if user_name:
        info_data.append([_ar(user_name), _ar("المحلل")])
    info_data.append([now, _ar("التاريخ")])

    confidence = analysis_result.get("confidence", 0)
    info_data.append([f"{confidence:.1f}%", _ar("مستوى الثقة")])

    if info_data:
        info_table = Table(info_data, colWidths=[300, 150])
        info_table.setStyle(
            TableStyle(
                [
                    ("FONTNAME", (0, 0), (-1, -1), font_name),
                    ("FONTSIZE", (0, 0), (-1, -1), 10),
                    ("TEXTCOLOR", (0, 0), (-1, -1), NAVY),
                    ("ALIGN", (0, 0), (0, -1), "LEFT"),
                    ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                    ("TOPPADDING", (0, 0), (-1, -1), 6),
                    ("LINEBELOW", (0, 0), (-1, -2), 0.5, colors.HexColor("#E0E0E0")),
                ]
            )
        )
        elements.append(info_table)
        elements.append(Spacer(1, 10 * mm))

    # --- Financial Statements ---
    statements = analysis_result.get("statements", {})

    for stmt_key, stmt_title in [
        ("income_statement", "قائمة الدخل"),
        ("balance_sheet", "الميزانية العمومية"),
    ]:
        stmt = statements.get(stmt_key, {})
        if not stmt:
            continue

        elements.append(Paragraph(_ar(stmt_title), heading_style))

        items = stmt.get("items", [])
        if items:
            header = [_ar("المبلغ"), _ar("البند")]
            table_data = [header]
            for item in items:
                label = item.get("label", item.get("name", ""))
                value = item.get("value", item.get("amount", 0))
                if isinstance(value, (int, float)):
                    formatted = f"{value:,.2f}"
                else:
                    formatted = str(value)
                table_data.append([formatted, _ar(str(label))])

            t = Table(table_data, colWidths=[150, 300])
            t.setStyle(
                TableStyle(
                    [
                        ("FONTNAME", (0, 0), (-1, -1), font_name),
                        ("FONTSIZE", (0, 0), (-1, -1), 9),
                        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                        ("TEXTCOLOR", (0, 0), (-1, 0), GOLD),
                        ("FONTNAME", (0, 0), (-1, 0), font_bold),
                        ("ALIGN", (0, 0), (0, -1), "LEFT"),
                        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, LIGHT_GOLD]),
                        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#D0D0D0")),
                        ("TOPPADDING", (0, 0), (-1, -1), 5),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                        ("LEFTPADDING", (0, 0), (-1, -1), 8),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                    ]
                )
            )
            elements.append(t)
            elements.append(Spacer(1, 8 * mm))

        # Totals
        totals = {k: v for k, v in stmt.items() if k != "items" and isinstance(v, (int, float))}
        if totals:
            total_data = [[f"{v:,.2f}", _ar(str(k))] for k, v in totals.items()]
            tt = Table(total_data, colWidths=[150, 300])
            tt.setStyle(
                TableStyle(
                    [
                        ("FONTNAME", (0, 0), (-1, -1), font_bold),
                        ("FONTSIZE", (0, 0), (-1, -1), 10),
                        ("TEXTCOLOR", (0, 0), (-1, -1), NAVY),
                        ("ALIGN", (0, 0), (0, -1), "LEFT"),
                        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                        ("LINEABOVE", (0, 0), (-1, 0), 1, GOLD),
                        ("TOPPADDING", (0, 0), (-1, -1), 4),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                    ]
                )
            )
            elements.append(tt)
            elements.append(Spacer(1, 5 * mm))

    # --- Financial Ratios ---
    ratios = analysis_result.get("ratios", analysis_result.get("financial_ratios", {}))
    if ratios:
        elements.append(Paragraph(_ar("النسب المالية"), heading_style))
        ratio_data = [[_ar("القيمة"), _ar("النسبة")]]
        for k, v in ratios.items():
            if isinstance(v, (int, float)):
                ratio_data.append([f"{v:.2f}", _ar(str(k))])
        if len(ratio_data) > 1:
            rt = Table(ratio_data, colWidths=[150, 300])
            rt.setStyle(
                TableStyle(
                    [
                        ("FONTNAME", (0, 0), (-1, -1), font_name),
                        ("FONTSIZE", (0, 0), (-1, -1), 9),
                        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                        ("TEXTCOLOR", (0, 0), (-1, 0), GOLD),
                        ("FONTNAME", (0, 0), (-1, 0), font_bold),
                        ("ALIGN", (0, 0), (0, -1), "LEFT"),
                        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, GRAY]),
                        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#D0D0D0")),
                        ("TOPPADDING", (0, 0), (-1, -1), 5),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                    ]
                )
            )
            elements.append(rt)
            elements.append(Spacer(1, 8 * mm))

    # --- Knowledge Brain ---
    kb = analysis_result.get("knowledge_brain", analysis_result.get("kb", {}))
    if kb:
        elements.append(Paragraph(_ar("العقل المعرفي"), heading_style))
        kb_items = []
        rules_applied = kb.get("rules_applied", kb.get("matched", 0))
        rules_total = kb.get("rules_total", kb.get("total", 0))
        kb_items.append([f"{rules_applied} / {rules_total}", _ar("القواعد المطبقة")])
        if kb.get("suggestions"):
            for s in kb["suggestions"][:5]:
                kb_items.append([_ar(str(s)), _ar("اقتراح")])
        if kb_items:
            kbt = Table(kb_items, colWidths=[250, 200])
            kbt.setStyle(
                TableStyle(
                    [
                        ("FONTNAME", (0, 0), (-1, -1), font_name),
                        ("FONTSIZE", (0, 0), (-1, -1), 9),
                        ("TEXTCOLOR", (0, 0), (-1, -1), NAVY),
                        ("ALIGN", (0, 0), (0, -1), "LEFT"),
                        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                        ("TOPPADDING", (0, 0), (-1, -1), 4),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                        ("LINEBELOW", (0, 0), (-1, -2), 0.5, colors.HexColor("#E0E0E0")),
                    ]
                )
            )
            elements.append(kbt)

    # --- Warnings ---
    warnings = analysis_result.get("warnings", [])
    if warnings:
        elements.append(Spacer(1, 8 * mm))
        elements.append(Paragraph(_ar("التحذيرات"), heading_style))
        for w in warnings[:10]:
            elements.append(Paragraph(f"• {_ar(str(w))}", body_style))

    # --- Footer ---
    elements.append(Spacer(1, 15 * mm))
    footer_style = ParagraphStyle(
        "Footer",
        parent=styles["Normal"],
        fontName=font_name,
        fontSize=8,
        textColor=colors.HexColor("#999999"),
        alignment=TA_CENTER,
    )
    elements.append(Paragraph(_ar("تم إنشاء هذا التقرير بواسطة منصة APEX للتحليل المالي المعرفي"), footer_style))
    elements.append(Paragraph(f"Generated: {now}", footer_style))

    doc.build(elements)
    return buffer.getvalue()
