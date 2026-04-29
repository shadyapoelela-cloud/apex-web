# APEX Flow Diagrams

مخططات تدفّق المستخدم لمنصة APEX المالية، مرسومة بـ **Mermaid** (تظهر تلقائياً في GitHub).

## الملفات

| الملف | الوصف |
|------|-------|
| [`01-current-state.md`](01-current-state.md) | **الواقع الحالي** — كل ما هو منفّذ فعلياً في الكود اليوم (10 أدوار، 11 Phase، 6 Sprint، 37+ راوت) |
| [`02-target-state.md`](02-target-state.md) | **الحالة المثالية** — APEX المحسّن والمكتمل، بناءً على 10 موجات بحث على أفضل المنصات العالمية |
| [`03-research-findings.md`](03-research-findings.md) | **خلاصة البحث** — الدروس المستخلصة من QuickBooks, Xero, Zoho, Wave, FreshBooks, NetSuite, Odoo, SAP, Stripe + معايير SaaS B2B 2026 |
| [`04-gap-analysis.md`](04-gap-analysis.md) | **تحليل الفجوة** — قائمة عملية بالتحسينات المطلوبة، مرتّبة حسب الأولوية |
| [`rendered/`](rendered/README.md) | **الصور (PNG)** — كل المخططات كرسومات جاهزة للعرض/التضمين (21 صورة) |

## كيف تقرأ المخطط

- **🟧 Diamond (معيّن)** = نقطة قرار (Decision)
- **🟦 Rectangle (مستطيل)** = خطوة/شاشة (Process / Screen)
- **🟩 Stadium (بيضاوي)** = نقطة بداية أو نهاية (Start / End)
- **🟪 Subroutine (مستطيل بجانبين)** = عملية فرعية معرَّفة في مكان آخر
- **Swimlanes (subgraphs)** = خطوط أفقية حسب الدور

## الأدوات

- **عرض**: GitHub يرسم Mermaid تلقائياً، أو [Mermaid Live Editor](https://mermaid.live/)
- **تصدير لصورة**: انسخ الكود من الملفات إلى Mermaid Live → Actions → Export PNG/SVG
- **تعديل**: عدّل الـ Markdown مباشرة، الرسم يحدّث نفسه

## سياق المشروع

APEX = منصة مالية متعددة الأدوار (10 أدوار: من Guest لـ Super Admin) مبنية على:

- **Backend**: FastAPI + PostgreSQL، 11 Phase + 6 Sprint
- **Frontend**: Flutter Web + GoRouter + Riverpod (37 راوت رئيسي + 134 راوت ثانوي/تجريبي)
- **AI**: Anthropic Claude (Knowledge Brain + Copilot)
- **Payments**: Stripe (مع mock backend)
- **Storage**: S3 / Local
- **اللغة الأساسية**: العربية (RTL)
