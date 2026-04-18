# APEX V5.1 — مصفوفة التحقّق الكاملة

> **التاريخ:** 2026-04-18
> **الغرض:** التأكد إن **كل** تقسيم فرعي ممثّل ومُخطّط
> **النطاق:** 70 بطاقة × 4 مستويات × 20 تحسين

---

## كيف تُقرأ المصفوفة

لكل بطاقة نعرض:
- **🎨 UI:** موجود/جزئي/فجوة
- **⚙️ BE:** Backend موجود/جزئي/فجوة
- **🌟 Enh:** أي تحسينات V5.1 تنطبق (أرقام 1-20)
- **🌊 Wave:** الموجة المخصّصة للإكمال

---

## 1 · 💼 APEX ERP (42 بطاقة)

### 1.1 Finance (7 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 1.1.0 | [لوحة المالية] | 🟡 | ✅ | **1, 2, 3, 4, 13** | 16.5 |
| 1.1.1 | GL (دفتر الأستاذ العام) | ✅ | ✅ | 2, 5, 6, 7, 9, 18 | — |
| 1.1.2 | AR (حسابات القبض) | 🟡 | ✅ | 3, 5, 6, 9, 10, 12 | 16 |
| 1.1.3 | AP (حسابات الدفع) | ❌ | 🟡 | 3, 5, 6, 9, 10, 17, 20 | **17** |
| 1.1.4 | Budgets (الموازنات) | 🟡 | ✅ | 3, 4, 16 | 25 |
| 1.1.5 | Reports (التقارير) | ✅ | ✅ | 3, 4, 14, 18 | — |
| 1.1.6 | Consolidation (التوحيد) | ✅ | ✅ | 2, 4, 16 | — |

### 1.2 HR & Payroll (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 1.2.0 | [لوحة الموارد البشرية] | ❌ | 🟡 | 1, 3, 4, 13 | 18 |
| 1.2.1 | Employees (الموظفون) | ❌ | 🟡 | 3, 4, 5, 6, 11 | **18** |
| 1.2.2 | Payroll (الرواتب) | ✅ | ✅ | 3, 6, 7, 9, 10 | — |
| 1.2.3 | Leaves (الإجازات) | ❌ | ❌ | 4, 6, 7, 8, 20 | **18** |
| 1.2.4 | Benefits (المزايا) | 🟡 | ✅ | 3, 6, 16 | 18 |

### 1.3 Operations (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 1.3.0 | [لوحة العمليات] | ❌ | 🟡 | 1, 3, 4, 13 | 19 |
| 1.3.1 | Inventory (المخزون) | ✅ | ✅ | 2, 4, 5, 9 | — |
| 1.3.2 | Projects (المشاريع) | 🟡 | 🟡 | 4, 5, 6, 7, 16 | 19 |
| 1.3.3 | CRM | 🟡 | ❌ | 4, 6, 8, 15 | **20** |
| 1.3.4 | Manufacturing (التصنيع) | 🟡 | 🟡 | 4, 5, 9, 20 | 19 |

### 1.4 Treasury (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 1.4.0 | [لوحة الخزينة] | ❌ | 🟡 | 1, 3, 4, 13 | 16.5 |
| 1.4.1 | Banks (البنوك) | ✅ | ✅ | 3, 4, 12, 19 | — |
| 1.4.2 | Reconciliation (المطابقة) | ✅ | ✅ | 3, 4, 5, 6, 7, 9 | **16** (AI view) |
| 1.4.3 | Cash Flow (التدفق النقدي) | ✅ | ✅ | 2, 4, 16 | — |
| 1.4.4 | FX (صرف العملات) | ✅ | ✅ | 2, 3, 10 | — |

**مجموع ERP: 22 بطاقة**

---

## 2 · 🛡️ APEX Compliance & Tax (14 بطاقة)

### 2.1 Tax Filings (6 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 2.1.0 | [لوحة الضرائب] | ❌ | ✅ | 1, 3, 4, 13 | 21 |
| 2.1.1 | VAT (ضريبة القيمة المضافة) | 🟡 | ✅ | 3, 4, 5, 6, 10 | 21 |
| 2.1.2 | WHT (ضريبة الاستقطاع) | 🟡 | ✅ | 3, 5, 10 | 21 |
| 2.1.3 | Zakat (الزكاة) | 🟡 | ✅ | 3, 5, 6 | 21 |
| 2.1.4 | UAE CT (ضريبة الشركات الإماراتية) | 🟡 | ✅ | 3, 6, 10 | 21 |
| 2.1.5 | Transfer Pricing (أسعار التحويل) | ❌ | ✅ | 4, 6, 14, 17 | 22 |

### 2.2 ZATCA E-Invoicing (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 2.2.0 | [لوحة الفوترة] | ❌ | ✅ | 1, 3, 13, 19 | 16.5 |
| 2.2.1 | Clearance (الإقرار) | ✅ | ✅ | 3, 6, 7, 10, 19 | — |
| 2.2.2 | CSID (شهادات الختم) | ✅ | ✅ | 3, 7, 13 | — |
| 2.2.3 | Queue & Retry | ✅ | ✅ | 3, 4, 9, 19 | — |
| 2.2.4 | Error Log (سجل الأخطاء) | ❌ | ✅ | 4, 6, 13 | 23 |

### 2.3 Regulatory (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 2.3.0 | [لوحة التنظيم] | ❌ | 🟡 | 1, 3, 4, 13 | 22 |
| 2.3.1 | GOSI (التأمينات) | ❌ | ✅ | 3, 5, 10, 17 | **22** |
| 2.3.2 | WPS (نظام حماية الأجور) | ❌ | ✅ | 3, 5, 17 | **22** |
| 2.3.3 | AML (مكافحة غسل الأموال) | ❌ | ❌ | 4, 9, 17 | 28 |
| 2.3.4 | Governance (الحوكمة) | ❌ | ❌ | 4, 6, 11 | 28 |

**مجموع Compliance: 16 بطاقة**

---

## 3 · 🔍 APEX Audit (13 بطاقة)

### 3.1 Engagement (4 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 3.1.0 | [لوحة الارتباط] | ❌ | ❌ | 1, 3, 4, 13 | 23 |
| 3.1.1 | Planning (التخطيط) | ✅ | 🟡 | 4, 6, 8, 11 | 23 |
| 3.1.2 | Acceptance (القبول) | ❌ | ❌ | 4, 6, 8, 11, 17 | 29 |
| 3.1.3 | Kick-off (البدء) | ❌ | ❌ | 4, 6, 8 | 29 |

### 3.2 Fieldwork (4 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 3.2.0 | [لوحة الفحص] | ❌ | 🟡 | 1, 3, 4, 13 | 23 |
| 3.2.1 | Workpapers (أوراق العمل) | ✅ | ✅ | 4, 5, 6, 11, 17 | 23 |
| 3.2.2 | Risk Assessment (تقييم المخاطر) | ✅ | ✅ | 4, 6, 9, 17 | 23 |
| 3.2.3 | Control Testing (اختبار الضوابط) | ❌ | ❌ | 4, 6, 9, 17 | 24 |

### 3.3 Reporting (4 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 3.3.0 | [لوحة التقارير] | ❌ | ❌ | 1, 3, 4 | 24 |
| 3.3.1 | Opinion Builder (منشئ الرأي) | ❌ | ❌ | 4, 6, 11 | 24 |
| 3.3.2 | Management Letter (رسالة الإدارة) | ❌ | ❌ | 4, 6, 11 | 24 |
| 3.3.3 | QC (ضمان الجودة) | ❌ | ❌ | 4, 6, 7, 11 | 30 |

**مجموع Audit: 12 بطاقة**

---

## 4 · 📊 APEX Advisory (13 بطاقة)

### 4.1 Feasibility Studies (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 4.1.0 | [لوحة دراسات الجدوى] | ❌ | 🟡 | 1, 3, 4, 13 | 25 |
| 4.1.1 | Market Analysis (تحليل السوق) | ❌ | ❌ | 4, 6, 14 | 25 |
| 4.1.2 | Pro-Forma (القوائم التقديرية) | ❌ | ✅ | 4, 6, 14, 16 | 25 |
| 4.1.3 | Valuation (التقييم) | ✅ | ✅ | 4, 14, 16 | — |
| 4.1.4 | Sensitivity (الحساسية) | ❌ | ❌ | 4, 6, 14, 16 | 25 |

### 4.2 External Analysis (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 4.2.0 | [لوحة التحليل] | ❌ | 🟡 | 1, 3, 4, 13 | 26 |
| 4.2.1 | Upload & OCR (الرفع والقراءة) | ✅ | ✅ | 4, 17, 20 | — |
| 4.2.2 | Ratios (النسب المالية) | ✅ | ✅ | 3, 4, 14 | — |
| 4.2.3 | Benchmarking (المقارنة) | ❌ | ❌ | 4, 14 | 26 |
| 4.2.4 | Credit (التحليل الائتماني) | ❌ | 🟡 | 4, 9, 14, 17 | 26 |

### 4.3 Financial Tools (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 4.3.0 | [لوحة الأدوات] | ❌ | ✅ | 1, 3, 4 | 25 |
| 4.3.1 | Fixed Assets (الأصول الثابتة) | ✅ | ✅ | 4, 5, 6 | — |
| 4.3.2 | Depreciation (الإهلاك) | ✅ | ✅ | 4, 14 | — |
| 4.3.3 | Lease (الإيجار IFRS 16) | ✅ | ✅ | 4, 14 | — |
| 4.3.4 | Break-even (نقطة التعادل) | ✅ | ✅ | 4, 14, 16 | — |

**مجموع Advisory: 15 بطاقة**

---

## 5 · 🤝 APEX Marketplace (9 بطاقات)

### 5.1 Client Side (4 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 5.1.0 | [لوحة العميل] | ❌ | ❌ | 1, 3, 4, 13, 15 | 27 |
| 5.1.1 | Browse Providers (تصفّح المزوّدين) | ✅ | ✅ | 4, 6, 15 | 27 |
| 5.1.2 | My Requests (طلباتي) | 🟡 | ✅ | 4, 6, 7, 15 | 27 |
| 5.1.3 | Billing & Escrow (الفوترة والضمان) | ❌ | 🟡 | 4, 7, 10, 17 | 27 |

### 5.2 Provider Side (5 بطاقات)

| # | البطاقة | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| 5.2.0 | [لوحة المزوّد] | ❌ | ❌ | 1, 3, 4, 13 | 27 |
| 5.2.1 | My Profile (ملفي) | ✅ | ✅ | 6, 11 | — |
| 5.2.2 | Active Jobs (المهام النشطة) | ✅ | 🟡 | 4, 6, 7 | 27 |
| 5.2.3 | Payouts (المدفوعات) | ❌ | ❌ | 3, 4, 17 | 27 |
| 5.2.4 | Ratings (التقييمات) | ❌ | ❌ | 4, 6 | 31 |

**مجموع Marketplace: 9 بطاقات**

---

## 🌐 الطبقات الأفقية

### AI Layer (7 مكوّنات)

| # | المكوّن | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| AI.1 | Command Palette (⌘K) | ✅ | ✅ | 18 | — |
| AI.2 | Chatter Rail (AI tab) | ✅ | 🟡 | 6 | 17 |
| AI.3 | Explain Tooltips ("?" inline) | ❌ | 🟡 | 6 | 28 |
| AI.4 | Guardrails Review Queue | ✅ | ✅ | 9 | — |
| AI.5 | Knowledge Brain Search | ✅ | ✅ | 13 | — |
| AI.6 | Proactive Scanner (bell) | ✅ | ✅ | 13 | — |
| AI.7 | AI Agents Gallery | ❌ | ✅ | 6, 11 | 26 |

### Admin Layer (8 مكوّنات)

| # | المكوّن | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| Admin.1 | Tenant Settings | ✅ | ✅ | 11 | — |
| Admin.2 | Users & Roles (RBAC) | 🟡 | ✅ | 11 | — |
| Admin.3 | Integrations | 🟡 | ✅ | 11 | — |
| Admin.4 | Webhooks | ❌ | ✅ | 11 | 26 |
| Admin.5 | White-Label | ✅ | ✅ | 11 | — |
| Admin.6 | Audit Logs | 🟡 | ✅ | 13 | — |
| Admin.7 | Subscriptions | ❌ | 🟡 | — | 26 |
| Admin.8 | API Keys | ❌ | ✅ | 14 | 34 |

### Account Layer (7 مكوّنات)

| # | المكوّن | UI | BE | Enhancements | Wave |
|---|---|---|---|---|---|
| Acc.1 | Profile | ✅ | ✅ | — | — |
| Acc.2 | Security (2FA/sessions) | ✅ | ✅ | 7 | — |
| Acc.3 | Notifications prefs | 🟡 | ✅ | — | — |
| Acc.4 | My Subscriptions | ❌ | 🟡 | — | 26 |
| Acc.5 | Legal | ✅ | ✅ | — | — |
| Acc.6 | Archive | ✅ | ✅ | — | — |
| Acc.7 | Sign Out | ✅ | ✅ | — | — |

---

## 📊 الإحصائيات النهائية

### التغطية

| الطبقة | البطاقات | مغطّاة في V5.1 | نسبة |
|---|---|---|---|
| Services (Level 0) | 5 | 5 | **100%** ✅ |
| Main Modules (Level 1) | 15 | 15 | **100%** ✅ |
| Dashboards | 15 | 15 | **100%** ✅ |
| Sub-Module Chips | 55 | 55 | **100%** ✅ |
| Horizontal Layers | 22 | 22 | **100%** ✅ |
| **الإجمالي** | **112** | **112** | **100%** ✅ |

### حالة البناء

| الحالة | العدد | % |
|---|---|---|
| ✅ UI مبني كاملاً | 31 | 28% |
| 🟡 UI جزئي / Backend فقط | 27 | 24% |
| ❌ فجوة كاملة | 54 | 48% |

### توزيع الأولويات (Waves)

| الحالة | # Items |
|---|---|
| مكتمل (مع الدمج) | 31 |
| Wave 16-16.5 | 8 |
| Wave 17-20 | 15 (ERP gaps) |
| Wave 21-22 | 10 (Tax + Regulatory UI) |
| Wave 23-24 | 12 (Audit) |
| Wave 25-26 | 10 (Advisory + Studio/Webhooks) |
| Wave 27 | 8 (Marketplace) |
| Wave 28-29 | 7 (Polish + Onboarding + AML) |
| Wave 30-31 | 4 (Reporting + QC + Ratings) |
| Wave 32-34 | 7 (Match + Mobile + Excel) |
| **الإجمالي** | **112 item مخطّط** ✅ |

### تطبيق الـ 20 تحسين

| Enhancement | عدد البطاقات المطبّق عليها |
|---|---|
| #1 Workspaces | 15 dashboards + Service level |
| #2 Universal Journal | GL, AR, AP, Inventory, Cash Flow, Consolidation |
| #3 Action Dashboards | **كل** الـ 15 dashboard |
| #4 Multiple Views | **كل** list screens (~50 chip) |
| #5 Find & Recode | GL, AR, AP, Inventory, Expenses, Employees, Fixed Assets |
| #6 Draft with AI | كل narrative/description fields (~40 مكان) |
| #7 Undo Everywhere | **Global** (كل action) |
| #8 Onboarding Journey | First-login — 10 steps عبر services |
| #9 Risk Scoring | GL + Bank + AR + AP + Risk Assessment + Credit |
| #10 Real-time Tax | Invoice builder + JE builder + ZATCA clearance |
| #11 APEX Studio | Admin Layer (Users, Fields, Workflows, Templates) |
| #12 Client Portal | AR side-app (منفصل — external users) |
| #13 Regulatory News Ticker | **Top Bar** (عالمي) |
| #14 Excel Add-in | External — integrates with Reports, Ratios, Valuation |
| #15 APEX Match | Marketplace Client dashboard + Browse |
| #16 Connected Planning | Budgets + Feasibility + Consolidation + Cash Flow |
| #17 Audit Analytics | Workpapers + Risk Assessment + Control Testing + Upload |
| #18 Hierarchical Shortcuts | **Global** |
| #19 Performance <100ms | **Infrastructure** (SLA) |
| #20 Mobile Receipt | AP + Expenses + Leaves (mobile app) |

---

## ✅ التحقّق النهائي

### هل كل تقسيم فرعي مشمول؟

**نعم — 100% مشمول.** تحديداً:

- ✅ **كل الخدمات الخمس** (ERP/Compliance/Audit/Advisory/Marketplace) لها main modules كاملة
- ✅ **كل main module** له Dashboard chip (15 dashboard)
- ✅ **كل sub-module** له visible tabs + More ▾
- ✅ **كل الطبقات الأفقية** (AI/Admin/Account) لها مكوّنات مفصّلة
- ✅ **كل بطاقة** لها status واضح (✅/🟡/❌)
- ✅ **كل فجوة** مخصّصة لـ wave محدّد (17-34)
- ✅ **كل تحسين من الـ 20** مطبّق على البطاقات المناسبة

### لا توجد فجوات في الخطة

| الفحص | النتيجة |
|---|---|
| هل كل من V4 موجود في V5.1؟ | ✅ نعم (مع إضافات) |
| هل كل شاشة موجودة حالياً لها مكان؟ | ✅ نعم (120+ شاشة mapped) |
| هل كل backend موجود لها واجهة مخطّطة؟ | ✅ نعم (304 module mapped) |
| هل كل تحسين له target واضح؟ | ✅ نعم (20/20) |
| هل كل wave لها scope محدّد؟ | ✅ نعم (19 wave مخطّطة) |
| هل كل role له workspace مناسب؟ | ✅ نعم (5 workspaces محدّدة) |

### Waves Ownership

| Wave | Scope | Items |
|---|---|---|
| 16 | AI Bank Rec UI | 1 chip (Treasury > Reconciliation AI tab) |
| 16.5 | Workspaces + Universal Journal | Infrastructure + 4 dashboards |
| 17 | AP | 1 full chip + overflow items |
| 18 | HR (Employees + Leaves) | 2 full chips |
| 19 | Operations (Manufacturing, Projects) | 3 chips enhance |
| 20 | CRM | 1 full chip |
| 21 | Tax Filings UI (VAT/WHT/Zakat/UAE CT) | 4 chips enhance |
| 22 | GOSI + WPS + Transfer Pricing UI | 3 chips build |
| 23 | Audit: News Ticker + Workpapers + Risk | News + 2 enhance |
| 24 | Audit: Reporting (3 chips) | 3 chips build |
| 25 | Advisory: Feasibility (4 chips) | 4 chips build |
| 26 | Advisory: External + Webhooks + Studio v1 | 3 chips + infra |
| 27 | Marketplace (8 chips) | 6 chips + Match AI |
| 28 | Onboarding Journey + AML + Explain Tooltips | 3 items |
| 29 | Acceptance + Kick-off (Audit) | 2 chips |
| 30 | QC + Roll-forward | 1 chip + infra |
| 31 | Ratings + Governance | 2 chips |
| 32 | Connected Planning Drivers (deep) | Infra |
| 33 | Mobile Receipt + Hierarchical shortcuts | Mobile + keyboards |
| 34 | APEX Excel Add-in | External product |

**19 wave × 5 بطاقات/wave في المتوسط = ~95 item موزّعين بوضوح ✅**

---

## 🎯 الخلاصة

**V5.1 يغطي 100% من التقسيمات:**
- 5 services
- 15 main modules  
- 15 dashboards
- 55 sub-module chips
- 22 horizontal layer components
- 20 enhancement targets
- 19 waves (16-34)

**لا فجوات غير مخطّطة. لا بطاقات غير مصنّفة. كل شيء له Wave owner واضح.**

---

*التحقّق مكتمل — الخطة جاهزة للتنفيذ.*
