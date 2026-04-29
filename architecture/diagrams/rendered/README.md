# المخططات كصور (Rendered PNGs)

تم رندر كل المخططات تلقائياً باستخدام `@mermaid-js/mermaid-cli`. الصور حجم عالي (PNG) جاهزة للعرض المباشر أو التضمين.

> **لإعادة الرندر بعد أي تعديل**: شغّل `npx -y -p @mermaid-js/mermaid-cli mmdc -i 01-current-state.md -o rendered/01-current-state.md -e png -p .puppeteer-config.json --backgroundColor white` من مجلد `architecture/diagrams/`.

---

## 📂 الواقع الحالي (As-Is) — 9 مخططات

| # | المخطط | الصورة |
|---|--------|--------|
| 1 | النظرة العامة — كل الأدوار | ![](01-current-state-1.png) |
| 2 | تدفق المصادقة | ![](01-current-state-2.png) |
| 3 | Onboarding للعميل (SME) | ![](01-current-state-3.png) |
| 4 | Marketplace (Provider + Client) | ![](01-current-state-4.png) |
| 5 | Knowledge Brain + Copilot | ![](01-current-state-5.png) |
| 6 | تدفق الإدارة | ![](01-current-state-6.png) |
| 7 | هيكل الـ Backend (Phases + Sprints) | ![](01-current-state-7.png) |
| 8 | خريطة الراوتس (Mind Map) | ![](01-current-state-8.png) |
| 9 | الفجوات والـ Stubs | ![](01-current-state-9.png) |

---

## 🎯 الحالة المثالية (To-Be) — 10 مخططات

| # | المخطط | الصورة |
|---|--------|--------|
| 1 | النظرة الكلية المحسّنة | ![](02-target-state-1.png) |
| 2 | Onboarding المحسّن (AI Guided) | ![](02-target-state-2.png) |
| 3 | COA + TB Workflow Engine | ![](02-target-state-3.png) |
| 4 | Marketplace (Stripe Connect Style) | ![](02-target-state-4.png) |
| 5 | Adaptive Navigation حسب الدور | ![](02-target-state-5.png) |
| 6 | Workflow Automation Engine | ![](02-target-state-6.png) |
| 7 | Multi-Channel Notifications | ![](02-target-state-7.png) |
| 8 | Module Marketplace (Odoo Style) | ![](02-target-state-8.png) |
| 9 | AI-First Copilot | ![](02-target-state-9.png) |
| 10 | الفجوات المُسدّة | ![](02-target-state-10.png) |

---

## 📊 تحليل الفجوة (Gap Analysis) — مخططان

| # | المخطط | الصورة |
|---|--------|--------|
| 1 | Priority Matrix (Effort vs Impact) | ![](04-gap-analysis-1.png) |
| 2 | Roadmap Gantt — 12 شهر | ![](04-gap-analysis-2.png) |

---

## كيف تستخدم الصور

- **عرض مباشر**: انقر على أي صورة، GitHub أو VS Code يفتحها بحجم كامل
- **تضمين في عرض تقديمي**: انسخ ملف PNG وألصقه في PowerPoint / Keynote / Google Slides
- **تصدير بصيغ ثانية**: لو محتاج SVG (vector، يكبر بدون فقد جودة) أو PDF، شغّل:
  ```bash
  npx -y -p @mermaid-js/mermaid-cli mmdc -i 01-current-state.md -o rendered/01-current-state.md -e svg
  ```
  استبدل `-e png` بـ `-e svg` أو `-e pdf`.

## الملاحظات

- الصور مولّدة بخلفية بيضاء (`--backgroundColor white`) لتظهر جيداً في أي ثيم
- بعض النصوص العربية قد تظهر معكوسة في Mermaid (محدودية الـ RTL في الأداة) — في النص الأصلي بـ `.md` تظهر صح
- المخططات في `03-research-findings.md` نصية فقط (مصادر وجداول)، فمفيش صور لها
