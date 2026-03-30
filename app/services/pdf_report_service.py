"""
APEX Platform — PDF Financial Report Generator
═══════════════════════════════════════════════════
Generates professional Arabic PDF reports from analysis results.
Uses ReportLab with arabic_reshaper + python-bidi for RTL support.
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm, mm
from reportlab.pdfgen import canvas
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.enums import TA_RIGHT, TA_CENTER, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import arabic_reshaper
from bidi.algorithm import get_display
from io import BytesIO
import urllib.request

# Register Arabic font (Amiri)
FONT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "fonts")
FONT_REGISTERED = False

def ensure_arabic_font():
    global FONT_REGISTERED
    if FONT_REGISTERED:
        return
    os.makedirs(FONT_DIR, exist_ok=True)
    font_path = os.path.join(FONT_DIR, "Amiri-Regular.ttf")
    font_bold_path = os.path.join(FONT_DIR, "Amiri-Bold.ttf")
    
    if not os.path.exists(font_path):
        try:
            urllib.request.urlretrieve(
                "https://github.com/aliftype/amiri/releases/download/1.000/Amiri-Regular.ttf",
                font_path)
        except:
            # Fallback: use without custom font
            FONT_REGISTERED = True
            return
    
    if not os.path.exists(font_bold_path):
        try:
            urllib.request.urlretrieve(
                "https://github.com/aliftype/amiri/releases/download/1.000/Amiri-Bold.ttf",
                font_bold_path)
        except:
            pass
    
    try:
        pdfmetrics.registerFont(TTFont('Amiri', font_path))
        if os.path.exists(font_bold_path):
            pdfmetrics.registerFont(TTFont('Amiri-Bold', font_bold_path))
        else:
            pdfmetrics.registerFont(TTFont('Amiri-Bold', font_path))
        FONT_REGISTERED = True
    except:
        FONT_REGISTERED = True
from datetime import datetime
import os


def ar(text):
    """Reshape and reorder Arabic text for PDF rendering."""
    if not text:
        return ""
    try:
        reshaped = arabic_reshaper.reshape(str(text))
        return get_display(reshaped)
    except:
        return str(text)


def fmt(v):
    """Format number with commas."""
    if v is None:
        return "-"
    try:
        d = float(v)
        if abs(d) >= 1e6:
            return f"{d/1e6:,.2f}M"
        return f"{d:,.2f}"
    except:
        return str(v)


# Gold/Navy color scheme matching Flutter app
NAVY = colors.HexColor("#050D1A")
NAVY2 = colors.HexColor("#0D1829")
GOLD = colors.HexColor("#C9A84C")
CYAN = colors.HexColor("#00C2E0")
WHITE = colors.HexColor("#F0EDE6")
GRAY = colors.HexColor("#8A8880")
GREEN = colors.HexColor("#2ECC8A")
RED = colors.HexColor("#E05050")
WARN = colors.HexColor("#F0A500")


def generate_pdf_report(result: dict, client_name: str = "", user_name: str = "") -> bytes:
    """Generate a professional Arabic PDF financial report."""
    ensure_arabic_font()
    FONT = "Amiri" if FONT_REGISTERED else "Helvetica"
    FONT_B = "Amiri-Bold" if FONT_REGISTERED else "Helvetica-Bold"
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4,
        rightMargin=1.5*cm, leftMargin=1.5*cm,
        topMargin=2*cm, bottomMargin=2*cm)

    story = []
    w, h = A4

    # ─── Styles ───
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle('ATitle', parent=styles['Title'],
        fontName=FONT_B, fontSize=22, alignment=TA_CENTER,
        textColor=GOLD, spaceAfter=6)

    subtitle_style = ParagraphStyle('ASub', parent=styles['Normal'],
        fontName=FONT, fontSize=11, alignment=TA_CENTER,
        textColor=GRAY, spaceAfter=20)

    heading_style = ParagraphStyle('AHead', parent=styles['Heading2'],
        fontName=FONT_B, fontSize=14, alignment=TA_RIGHT,
        textColor=GOLD, spaceBefore=16, spaceAfter=8,
        borderWidth=0, borderPadding=0)

    normal_r = ParagraphStyle('NR', parent=styles['Normal'],
        fontName=FONT, fontSize=10, alignment=TA_RIGHT,
        textColor=colors.black)

    # ─── Header ───
    story.append(Paragraph("APEX", title_style))
    story.append(Paragraph(ar("تقرير التحليل المالي"), ParagraphStyle('x',
        fontName=FONT_B, fontSize=16, alignment=TA_CENTER, textColor=colors.HexColor("#333333"))))
    story.append(Spacer(1, 4))

    meta_data = []
    if client_name:
        meta_data.append(f"{ar('العميل')}: {ar(client_name)}")
    if user_name:
        meta_data.append(f"{ar('المحلل')}: {ar(user_name)}")
    meta_data.append(f"{ar('التاريخ')}: {datetime.now().strftime('%Y-%m-%d %H:%M')}")

    story.append(Paragraph(" | ".join(meta_data), subtitle_style))
    story.append(Spacer(1, 10))

    # ─── Confidence ───
    conf = result.get("confidence", {})
    overall = conf.get("overall", 0)
    label = conf.get("label", "")
    pct = f"{overall * 100:.1f}%" if isinstance(overall, (int, float)) else str(overall)

    conf_color = GREEN if overall >= 0.85 else WARN if overall >= 0.65 else RED

    story.append(Paragraph(ar("مستوى الثقة"), heading_style))

    conf_table = Table([
        [ar("النسبة"), pct],
        [ar("التقييم"), ar(label)],
    ], colWidths=[10*cm, 7*cm])
    conf_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F8F6F0")),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0DDD5")),
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('TEXTCOLOR', (1, 0), (1, 0), conf_color),
        ('FONTNAME', (1, 0), (1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (1, 0), (1, 0), 14),
        ('PADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(conf_table)
    story.append(Spacer(1, 12))

    # ─── Income Statement ───
    inc = result.get("income_statement", {})
    story.append(Paragraph(ar("قائمة الدخل"), heading_style))

    inc_rows = [
        [ar("البند"), ar("المبلغ (ر.س)")],
        [ar("صافي الإيرادات"), fmt(inc.get("net_revenue"))],
        [ar("تكلفة المبيعات"), fmt(inc.get("cogs"))],
        [ar("مجمل الربح"), fmt(inc.get("gross_profit"))],
        [ar("المصروفات التشغيلية"), fmt(inc.get("total_operating_expenses"))],
        [ar("الربح التشغيلي"), fmt(inc.get("operating_profit"))],
        [ar("صافي الربح"), fmt(inc.get("net_profit"))],
    ]

    inc_table = Table(inc_rows, colWidths=[10*cm, 7*cm])
    inc_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), GOLD),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0DDD5")),
        ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor("#FAFAF8")),
        ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('PADDING', (0, 0), (-1, -1), 7),
        ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor("#F0EDE6")),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
    ]))
    story.append(inc_table)
    story.append(Spacer(1, 12))

    # ─── Balance Sheet ───
    bs = result.get("balance_sheet", {})
    story.append(Paragraph(ar("الميزانية العمومية"), heading_style))

    balanced = bs.get("is_balanced", False)
    balanced_text = ar("نعم") if balanced else ar("لا")
    balanced_color = GREEN if balanced else RED

    bs_rows = [
        [ar("البند"), ar("المبلغ (ر.س)")],
        [ar("إجمالي الأصول"), fmt(bs.get("total_assets"))],
        [ar("إجمالي الالتزامات"), fmt(bs.get("total_liabilities"))],
        [ar("حقوق الملكية"), fmt(bs.get("total_equity"))],
        [ar("متوازنة"), balanced_text],
    ]

    bs_table = Table(bs_rows, colWidths=[10*cm, 7*cm])
    bs_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0D1829")),
        ('TEXTCOLOR', (0, 0), (-1, 0), GOLD),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0DDD5")),
        ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor("#FAFAF8")),
        ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('PADDING', (0, 0), (-1, -1), 7),
        ('TEXTCOLOR', (1, -1), (1, -1), balanced_color),
        ('FONTNAME', (1, -1), (1, -1), 'Helvetica-Bold'),
    ]))
    story.append(bs_table)
    story.append(Spacer(1, 12))

    # ─── Financial Ratios ───
    ratios = result.get("ratios", {})
    if ratios:
        story.append(Paragraph(ar("النسب المالية"), heading_style))
        ratio_rows = [[ar("النسبة"), ar("القيمة")]]
        ratio_names = {
            "current_ratio": "النسبة الجارية",
            "quick_ratio": "النسبة السريعة",
            "debt_to_equity": "الدين إلى حقوق الملكية",
            "gross_margin": "هامش الربح الإجمالي",
            "net_margin": "هامش صافي الربح",
            "roa": "العائد على الأصول",
            "roe": "العائد على حقوق الملكية",
        }
        for k, v in ratios.items():
            name = ratio_names.get(k, k)
            val = f"{v:.2%}" if isinstance(v, float) and abs(v) < 100 else fmt(v)
            ratio_rows.append([ar(name), val])

        ratio_table = Table(ratio_rows, colWidths=[10*cm, 7*cm])
        ratio_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), CYAN),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0DDD5")),
            ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor("#FAFAF8")),
            ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
            ('ALIGN', (1, 0), (1, -1), 'LEFT'),
            ('PADDING', (0, 0), (-1, -1), 7),
        ]))
        story.append(ratio_table)
        story.append(Spacer(1, 12))

    # ─── Knowledge Brain ───
    kb = result.get("knowledge_brain", {})
    if kb:
        story.append(Paragraph(ar("العقل المعرفي"), heading_style))
        kb_rows = [
            [ar("القواعد المُقيّمة"), str(kb.get("rules_evaluated", 0))],
            [ar("القواعد المُفعّلة"), str(kb.get("rules_triggered", 0))],
        ]
        kb_table = Table(kb_rows, colWidths=[10*cm, 7*cm])
        kb_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F0F8FF")),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#D0E8F0")),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
            ('ALIGN', (1, 0), (1, -1), 'LEFT'),
            ('PADDING', (0, 0), (-1, -1), 7),
        ]))
        story.append(kb_table)
        story.append(Spacer(1, 12))

    # ─── Footer ───
    story.append(Spacer(1, 20))
    footer_style = ParagraphStyle('Footer', fontName=FONT,
        fontSize=8, alignment=TA_CENTER, textColor=GRAY)
    story.append(Paragraph(
        f"APEX Financial Platform | Generated {datetime.now().strftime('%Y-%m-%d %H:%M')} | "
        f"{ar('هذا التقرير للأغراض التحليلية فقط')}",
        footer_style))

    # Build
    doc.build(story)
    return buffer.getvalue()

# v2
