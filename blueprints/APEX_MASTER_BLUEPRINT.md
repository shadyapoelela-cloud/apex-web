# 🏆 APEX Master Blueprint — خارطة الطريق لتصدّر سوق الشرق الأوسط

> وثيقة شاملة لبناء منصة APEX المالية — مبنية على فحص دقيق للوضع الراهن + دراسة معيارية لأفضل 10 منصات عالمية (Xero, QuickBooks, Sage Intacct, Zoho, NetSuite, FreshBooks, Odoo, Wave, MS Dynamics BC) + القادة الإقليميين (Wafeq, Qoyod, Daftra, Foodics, Rewaa).
>
> **الهدف:** أن تصبح APEX الرقم 1 في الشرق الأوسط خلال 12–18 شهر.
> **التاريخ:** 2026-04-18
> **النسخة:** v1.0

---

## 📑 فهرس الوثيقة

1. [الوضع الراهن — ما تم بناؤه](#الفصل-1--الوضع-الراهن)
2. [الفجوات الحرجة — ما ينقص لنكون رقم 1](#الفصل-2--الفجوات-الحرجة)
3. [هندسة المعلومات (IA) — خريطة التنقل الكاملة](#الفصل-3--هندسة-المعلومات)
4. [دليل الشاشات والأزرار ووسائل التحكم](#الفصل-4--دليل-الشاشات-والأزرار)
5. [طبقة الحوكمة والتحكم العالي (Control Layer)](#الفصل-5--طبقة-الحوكمة-والتحكم)
6. [متطلبات الامتثال الإقليمية (MENA Compliance)](#الفصل-6--الامتثال-الإقليمي)
7. [ميزات الذكاء الاصطناعي (AI Layer)](#الفصل-7--طبقة-الذكاء-الاصطناعي)
8. [نظام التصاريح والأدوار (RBAC Matrix)](#الفصل-8--التصاريح-والأدوار)
9. [مصفوفة الفجوات (يوجد/ينقص/يحتاج تحسين)](#الفصل-9--مصفوفة-الفجوات)
10. [خارطة التنفيذ المرحلية (Roadmap)](#الفصل-10--خارطة-التنفيذ)

---

## الفصل 1 — الوضع الراهن

### 1.1 الملخص التنفيذي للبنية الحالية

| المكون | الحالة | التفاصيل |
|---|---|---|
| Backend (FastAPI) | ✅ جاهز | 11 Phase + 6 Sprint + COA Engine + Knowledge Brain + Copilot |
| Database | ✅ جاهز | ~120 جدول، PostgreSQL + SQLite fallback |
| Frontend (Flutter Web) | ⚠️ يحتاج تنظيم | 63 GoRoute، 90+ شاشة، `main.dart` 3500 سطر (monolith) |
| API Endpoints | ✅ جاهز | 80+ مسار أساسي + 50+ مسار امتثال |
| Tests | ✅ ممتاز | 705+ اختبار عبر 35 ملف |
| Migrations | ⚠️ ناقص | Alembic migration واحد فقط (للـ KB) — البقية `create_all` |
| Rate Limiter | ⚠️ production-not-ready | In-memory فقط — يحتاج Redis |
| Auth الاجتماعي (Google/Apple) | ❌ stub | لا يتم التحقق من التوكنز |
| SMS Verification | ❌ stub | يرجع success دائماً |

### 1.2 خريطة الـ Phases والـ Sprints (بنظرة واحدة)

```
Phase 1  → Identity & Auth & Plans & Legal
Phase 2  → Clients, COA Uploads, Analysis Results
Phase 3  → Knowledge Governance, Review Queue
Phase 4  → Provider Onboarding & Verification
Phase 5  → Marketplace, Compliance, Suspension
Phase 6  → Admin Dashboard & Reviewer Tooling
Phase 7  → Task Documents, Audit, Result Details
Phase 8  → Entitlements Engine & Subscriptions
Phase 9  → Account Center (profile/sessions/closure)
Phase 10 → Notification System (V2)
Phase 11 → Legal Acceptance (V2)

Sprint 1 → COA First Workflow (Upload)
Sprint 2 → COA Classification
Sprint 3 → COA Quality + Approval
Sprint 4 → Knowledge Brain (+ TB binding in S4_TB)
Sprint 5 → Analysis Trigger
Sprint 6 → Registry (Authorities, Funding, Licenses, Eligibility)

+ COA Engine (14 ملف)
+ Knowledge Brain (4 rulebooks + services)
+ Copilot (AI assistant)
+ 30+ core service/routes pairs (Compliance, ZATCA, Tax, IFRS, Payroll, ...)
```

### 1.3 الموديولات التخصصية الجاهزة في `app/core/`

**محاسبية متقدمة:**
Compliance, ZATCA, Tax (VAT/WHT/Zakat), IFRS, Journal entries, Ledger, Audit trail, Aging, Amortization, Depreciation, Bank reconciliation, Budget variance, Breakeven, Cashflow, Cost accounting, Consolidation, Deferred tax, Fixed assets, Impairment, Inventory, Investment, Job costing, Lease (IFRS 16), OCR, Payroll, Provisions, Revenue recognition, Valuation, Working capital, Transfer pricing.

**تحليلية:**
Analytics, Financial Statements (IS/BS), Cashflow Statement, Ratios (30+), Health Score, EOSB, ECL (IFRS 9), DSCR.

**بنية تحتية:**
Email service (console/smtp/sendgrid), Payment (mock/stripe), Storage (local/s3), Auth utils, Error handlers, DB utils, Schema drift auto-repair, Saudi knowledge base.

### 1.4 قائمة المسارات في الـ Frontend (الحالية — 63 route)

```
Auth:         /login, /register, /forgot-password
Core:         /home, /dashboard, /settings, /copilot, /knowledge-brain
Account:      /profile/edit, /password/change, /account/close,
              /account/sessions, /account/activity, /subscription,
              /plans/compare, /notifications, /notifications/prefs
Clients:      /clients, /clients/new, /clients/create, /clients/onboarding,
              /client-detail, /onboarding/wizard
COA:          /coa/upload, /coa/mapping, /coa/quality, /coa/review,
              /coa/journey, /coa/financial-simulation, /coa/compliance-check,
              /coa/roadmap, /coa/trial-balance-check
Analysis:     /analysis/full, /analysis/result, /financial-statements,
              /tb/binding, /compliance (hub)
Compliance:   /compliance/journal-entries, /compliance/audit-trail,
              /compliance/zatca-invoice, /compliance/zakat, /compliance/vat-return,
              /compliance/ratios, /compliance/depreciation, /compliance/cashflow,
              /compliance/amortization, /compliance/payroll, /compliance/breakeven,
              /compliance/investment, /compliance/budget-variance,
              /compliance/bank-rec, /compliance/inventory, /compliance/aging,
              /compliance/working-capital, /compliance/health-score,
              /compliance/executive-dashboard, /compliance/ocr,
              /compliance/dscr, /compliance/valuation,
              /compliance/journal-entry-builder, /compliance/fx-converter,
              /compliance/cost-variance, /compliance/fin-statements,
              /compliance/cashflow-statement, /compliance/wht,
              /compliance/consolidation, /compliance/deferred-tax,
              /compliance/lease, /compliance/ifrs-tools,
              /compliance/fixed-assets, /compliance/transfer-pricing,
              /compliance/extras-tools
Admin:        /admin/reviewer, /admin/providers/verify, /admin/providers/documents,
              /admin/providers/compliance, /admin/policies, /admin/audit,
              /knowledge/console, /tasks/types, /provider-kanban
Marketplace:  /service-catalog, /marketplace/new-request, /service-request/detail
Legal:        /legal, /legal-acceptance, /compliance-detail,
              /provider/profile, /notification/detail, /archive,
              /upgrade-plan, /knowledge/feedback, /knowledge/feedback-form
```

### 1.5 الاختبارات الموجودة (705+ اختبار)

أفضل تغطية: `test_coa_engine.py` (118)، `test_integration_v10.py` (93)، `test_copilot_notifications.py` (38).
تغطية ضعيفة: `test_admin.py` (4 فقط)، `test_auth.py` (5).
لا يوجد: اختبارات Flutter في الـ CI.

---

## الفصل 2 — الفجوات الحرجة

### 2.1 فجوات حرجة (High-severity — يجب سدّها قبل التوسع)

| # | الفجوة | الأثر | الأولوية |
|---|---|---|---|
| 1 | **Social auth (Google/Apple) stubs** — لا تحقق من التوكنز | ثغرة أمنية — أي شخص يمكنه انتحال الشخصية | P0 |
| 2 | **SMS verification stub** — يرجع success دائماً | التحقق الثنائي 2FA غير فعلي | P0 |
| 3 | **Rate limiter in-memory** — لا يعمل في multi-instance | DDoS ممكن، مشاكل انتشار | P0 |
| 4 | **CORS wildcard في dev** قد يتسرّب للإنتاج | Leak للـ APIs | P1 |
| 5 | **Alembic بدون migrations** — كل schema يُبنى من `create_all` | مخاطرة عالية عند ترقية قواعد بيانات production | P1 |
| 6 | **Main.dart 3500 سطر** — 60+ class مترابطة | صعوبة التطوير والبق فيها | P1 |
| 7 | **JWT_SECRET fallback** قد يسرّب في dev | Token forgery | P0 |
| 8 | **Phase init_db() silent failures** — لا تُوقف startup | شاشات بلا بيانات دون إخطار | P1 |

### 2.2 ميزات مفقودة تمنعنا من التنافس عالمياً

| الميزة | لدى من | الأثر الاستراتيجي |
|---|---|---|
| **Bank Feeds المباشرة** (1000+ بنك) | Xero, QBO, Zoho | ❌ بدونها، المحاسبة تعني رفع CSV يدوي — المنافسون يستقبلون حركات البنك تلقائياً |
| **AI Auto-Reconciliation** (مثل Xero JAX) | Xero, QBO, Sage | ❌ المحاسبون يقضون 40% من وقتهم في المطابقة — AI يوفر هذا |
| **Dimensional Accounting** (مشاريع/أقسام/مواقع) | Sage Intacct, NetSuite | ❌ COA تضخم مع سنوات الاستخدام بدونه |
| **Approval Workflows** متعدد المستويات بشرط ديناميكي | Sage, NetSuite, Zoho | ❌ العملاء الكبار لن يشتروا بدونها |
| **Client Portal** (بوابة العميل) | FreshBooks, Xero, Zoho | ❌ عميلك يريد بوابة لمشاهدة فواتيره والدفع |
| **Cheque Register / PDC** (الشيكات المؤجلة) | Wafeq, Qoyod | ❌ ممارسة أساسية في KSA/UAE |
| **WhatsApp Invoicing** | الحقل الأزرق للمنافسين الإقليميين | ❌ 90% من SMBs في MENA يعيشون على WhatsApp |
| **Receipt OCR** (تصوير بصورة → فاتورة) | QBO, Zoho, Wave | ❌ بدونه، إدخال الفواتير يدوي بالكامل |
| **Multi-Entity Consolidation** (دمج الكيانات) | Sage, NetSuite | ❌ الشركات القابضة لن تلمسنا |
| **Embedded Lending** (تمويل مدمج) | ميزة القادمة في MENA | ⚡ 37% من SMBs مستعدة للتحول لمن يقدم هذا |
| **Natural-Language Analytics** ("ما الذي يسبب انخفاض الربح؟") | QBO, Sage Copilot | ⚡ ميزة تميّز |
| **SAML 2.0 / OIDC SSO** | كل المنصات الـ enterprise | ❌ بدونه، الشركات الكبرى مستحيلة |

---

## الفصل 3 — هندسة المعلومات

### 3.1 الخريطة المقترحة (الهيكل المستهدف)

منظم بطبقات، من الخارج للداخل:

```
┌─────────────────────────────────────────────────────────────┐
│  🌐 Public Layer (غير مسجل)                                 │
│  Landing → Plans → Signup → Login → Forgot PW → About      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  🏠 Workspace Layer (بعد الدخول)                            │
│  Top Nav  │  Left Sidebar  │  Main Content  │  Right Panel  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 بنية القائمة الرئيسية (Left Sidebar)

متأثر بـ QBO + Xero + Zoho — ترتيب منطقي حسب **تواتر الاستخدام**:

```
┌─ 🏠 الرئيسية (Dashboard)                  [/dashboard]
│
├─ 💰 المبيعات (Sales)
│   ├─ العملاء (Customers)
│   ├─ الفواتير (Invoices)
│   ├─ عروض الأسعار (Quotes/Estimates)
│   ├─ المدفوعات المستلمة (Payments)
│   ├─ إشعارات دائنة (Credit Notes)
│   └─ الإيرادات المتكررة (Recurring)
│
├─ 💸 المشتريات (Purchases)
│   ├─ الموردون (Vendors)
│   ├─ أوامر شراء (Purchase Orders)
│   ├─ الفواتير الواردة (Bills)
│   ├─ المصاريف (Expenses)
│   ├─ الشيكات المؤجلة (PDC Register) 🆕
│   └─ المدفوعات الصادرة (Payments Out)
│
├─ 🏦 البنوك والمالية (Banking)
│   ├─ الحسابات البنكية (Bank Accounts)
│   ├─ التدفقات (Feeds) 🆕 [1000+ بنك]
│   ├─ المطابقة (Reconciliation) 🆕 [AI JAX]
│   ├─ قواعد البنك (Bank Rules) 🆕
│   └─ كشف البنك (Statements)
│
├─ 📊 المحاسبة (Accounting)
│   ├─ شجرة الحسابات (CoA)
│   ├─ دليل الحسابات v4.3 (COA Engine)
│   ├─ القيود اليومية (Journal Entries)
│   ├─ دفتر الأستاذ (Ledger)
│   ├─ ميزان المراجعة (Trial Balance)
│   ├─ الإقفال الدوري (Period Close) 🆕
│   └─ إعادة التقييم بالعملات (FX Revaluation)
│
├─ 📦 المخزون والأصول (Inventory & Assets)
│   ├─ المخزون (Items/Stock)
│   ├─ الأصول الثابتة (Fixed Assets)
│   ├─ الإهلاك (Depreciation)
│   └─ العدّ الفعلي (Stock Count)
│
├─ 👥 الموارد البشرية والرواتب (HR & Payroll)
│   ├─ الموظفون (Employees)
│   ├─ الرواتب (Payroll Runs)
│   ├─ GOSI / التأمينات 🆕 [Saudi]
│   ├─ WPS / حماية الأجور 🆕 [UAE]
│   ├─ مكافأة نهاية الخدمة (EOSB)
│   ├─ الإجازات (Leaves)
│   └─ بطاقات الدوام (Timesheets)
│
├─ 🧾 الضرائب والامتثال (Tax & Compliance)
│   ├─ فواتير ZATCA (Fatoora Phase 2) 🆕
│   ├─ إقرار ضريبة القيمة المضافة (VAT Return)
│   ├─ ضريبة الاستقطاع (WHT)
│   ├─ الزكاة (Zakat)
│   ├─ IFRS Tools (9, 15, 16)
│   ├─ الضريبة المؤجلة (Deferred Tax)
│   └─ ضريبة الأسعار (Transfer Pricing)
│
├─ 📈 التقارير (Reports)
│   ├─ القوائم المالية (P&L, BS, CF, TB)
│   ├─ النسب المالية (Ratios) [30+]
│   ├─ تقارير مخصصة (Custom Reports)
│   ├─ المقارنات الدورية (Period Comparison)
│   ├─ حوكمة الأداء (KPIs Dashboard)
│   └─ تقارير الأبعاد (Dimensions Reports) 🆕
│
├─ 🤖 الذكاء المالي (AI Copilot) 🆕
│   ├─ المساعد الذكي (Chat)
│   ├─ تحليل متقدم (Natural Language Analytics)
│   ├─ كشف الشذوذ (Anomaly Detection)
│   ├─ التنبؤ بالتدفق النقدي (Cash Flow Forecast)
│   └─ Knowledge Brain (قاعدة المعرفة)
│
├─ 🛒 السوق والخدمات (Marketplace)
│   ├─ طلب خدمة (Request a Service)
│   ├─ طلباتي (My Requests)
│   ├─ مقدمو الخدمات (Service Providers)
│   └─ كتالوج الخدمات (Service Catalog)
│
├─ 📁 المشاريع والأقسام (Projects & Dimensions) 🆕
│   ├─ المشاريع (Projects)
│   ├─ الأقسام (Departments)
│   ├─ الفروع/المواقع (Locations)
│   ├─ مراكز التكلفة (Cost Centers)
│   └─ أبعاد مخصصة (Custom Dimensions)
│
└─ ⚙️ الإدارة (Admin)
    ├─ الأدوار والتصاريح (Roles & Permissions)
    ├─ سير الموافقات (Approval Workflows) 🆕
    ├─ إغلاق الفترات (Lock Dates)
    ├─ سجل التدقيق (Audit Log)
    ├─ الاشتراك والفواتير (Billing)
    ├─ التكاملات (Integrations)
    └─ الإعدادات العامة (Settings)
```

### 3.3 Top Nav (الشريط العلوي)

```
[☰ menu]  [🔍 بحث عام Ctrl+K]  [+ إنشاء]  [🤖 AI]  [🔔 إشعارات]  [👤 حسابي]
```

- **الشعار (Logo)** — يعود للـ Dashboard
- **شريط السياق (Context Bar)** — يعرض: المنشأة الحالية، الفترة المحاسبية، العملة، القفل
- **مبدّل المنشأة** — Dropdown للشركات الفرعية (Multi-entity)
- **البحث العام** — Cmd/Ctrl+K يفتح universal search عبر جميع السجلات
- **زر (+ إنشاء) العائم** — قائمة منبثقة لإنشاء أي سجل (فاتورة/عميل/قيد...)
- **الإشعارات** — Badge بعدد، قائمة نازلة، زر "قراءة الكل"
- **حسابي** — Dropdown يعرض: Profile, Subscription, Sign out
- **مساعد AI العائم** — زر بلون مميز بأسفل يمين الشاشة (مثل Intercom) لفتح الـ Copilot في أي وقت

### 3.4 Right Panel (القائمة الجانبية الديناميكية)

تظهر حسب السياق — مثل Odoo Discuss:

- في السجل (Record): شريط المناقشة + المرفقات + سجل التغييرات
- في التقرير: فلاتر + مقارنات + تصدير
- في الـ Dashboard: KPIs مخصصة

### 3.5 Dashboard (الشاشة الرئيسية)

متأثر بـ Xero + QBO + Role-based home pages من NetSuite:

**لكل دور Home Page مختلف:**

| الدور | الـ Widgets الافتراضية |
|---|---|
| المالك / CFO | Cash balance, MTD Revenue, Burn rate, Top 5 customers/vendors, Overdue invoices count, Close status |
| المحاسب | Bills to pay, Bank lines to reconcile, Journals to review, Period-close checklist |
| مدير المشاريع | Project profitability, Budget vs Actual per project, Timesheet status |
| مسؤول AP | Bills due this week, Payment runs, 3-way match exceptions |
| مسؤول AR | Overdue invoices, Aging bucket chart, Customer statements due |

**مميزات Dashboard:**
- Drag-and-drop widgets (مثل Xero)
- إضافة/إخفاء widget من مكتبة
- تصدير PDF للإدارة
- جدولة إرسال بالبريد أسبوعياً

---

## الفصل 4 — دليل الشاشات والأزرار

> هذا القسم هو **التفاصيل الدقيقة للأزرار ووسائل التحكم**. لكل شاشة رئيسية: الأزرار، الفلاتر، الحقول، الاختصارات، صلاحيات الوصول.

### 4.1 شاشة الفواتير (Invoices)

**الصفحة الرئيسية (`/sales/invoices`):**

```
┌─────────────────────────────────────────────────────────────┐
│ الفواتير                             [+ فاتورة جديدة] [↻]  │
├─────────────────────────────────────────────────────────────┤
│ الحالة: [الكل ▼] [مسودة] [مُرسلة] [مدفوعة] [متأخرة]        │
│ التاريخ: [من]—[إلى]  العميل: [كل العملاء ▼]  [🔍 بحث]      │
├─────────────────────────────────────────────────────────────┤
│ ☑ | رقم     | العميل    | التاريخ  | المبلغ | الحالة | ⋯  │
│ ☐ | INV-001 | مؤسسة...  | 2026-04  | 5,750 | مدفوعة | ⋯  │
│ ☐ | INV-002 | شركة...   | 2026-04  | 12,000| متأخرة | ⋯  │
│                                                              │
│ [تصدير Excel] [إرسال للـ ZATCA] [طباعة]  [حذف المحدد]      │
└─────────────────────────────────────────────────────────────┘
```

**الأزرار العلوية:**
| الزر | الوظيفة | الاختصار | الصلاحية |
|---|---|---|---|
| + فاتورة جديدة | ينشئ فاتورة جديدة ويفتح المحرر | `N` | `invoice.create` |
| استيراد (Import) | استيراد من Excel/CSV | - | `invoice.create` |
| تصدير (Export) | Excel/PDF/XML للـ ZATCA | - | `invoice.read` |
| طباعة مجمّعة | طباعة دفعة فواتير | - | `invoice.read` |
| جدولة متكررة | Recurring invoices | - | `invoice.create` |
| ↻ تحديث | تحديث القائمة | `R` | - |

**الفلاتر:**
- الحالة (Draft/Sent/Viewed/Paid/Partially paid/Overdue/Cancelled/Voided)
- التاريخ (من-إلى) مع أزرار سريعة: This week, This month, This quarter, YTD, Custom
- العميل (بحث ذكي)
- المشروع (Dimension)
- القسم (Dimension)
- العملة
- المبلغ (من-إلى)
- مُنشئ الفاتورة (User)

**الأعمدة القابلة للإخفاء/إظهار:**
UUID, رقم داخلي, رقم ZATCA, اسم العميل, الرقم الضريبي للعميل, تاريخ الإصدار, تاريخ الاستحقاق, المبلغ قبل الضريبة, الضريبة, المبلغ الكلي, العملة, المشروع, القسم, الحالة, حالة ZATCA, تاريخ آخر تعديل.

**الإجراءات المجمّعة (Bulk Actions):**
عند تحديد checkbox يظهر شريط سفلي:
- إرسال للعملاء (Send)
- طباعة (Print)
- تصدير (Export Excel/PDF/ZIP)
- إرسال لـ ZATCA
- تعليم كمدفوع (Mark as Paid)
- تعليم كملغاة (Cancel)
- حذف (Delete — مسودات فقط)
- تغيير المسؤول (Assign)

**محرر الفاتورة (`/sales/invoices/new`):**

```
┌─── الهيدر ────────────────────────────────────┐
│ العميل: [بحث...▼]  [+ عميل جديد]              │
│ رقم: INV-001  تاريخ: 2026-04-18  مدة: [▼] 30  │
│ عملة: [SAR ▼]  سعر الصرف: 1.0000              │
│ نوع الفاتورة: [● قياسية (B2B)] [○ مبسّطة (B2C)]│
│ المشروع: [بحث...▼]  القسم: [بحث...▼]           │
└────────────────────────────────────────────────┘

┌─── البنود ────────────────────────────────────┐
│ # | الصنف | الوصف | الكمية | السعر | الضريبة | الإجمالي │
│ 1 | [▼]   | ...   | 1      | 100   | 15% VAT | 115       │
│ [+ إضافة بند]  [استيراد من Excel]              │
└────────────────────────────────────────────────┘

┌─── الحسابات ──────────────────────────────────┐
│ المجموع الفرعي:               10,000 SAR       │
│ الخصم: [%] [٥] = (500)                         │
│ الشحن: 50                                      │
│ ضريبة القيمة المضافة (15%):    1,432.50        │
│ الإجمالي:                      10,982.50 SAR   │
└────────────────────────────────────────────────┘

┌─── الإرفاقات والملاحظات ─────────────────────┐
│ ملاحظات للعميل: [ ... ]                        │
│ شروط الدفع: [ 30 يوم صافي ]                    │
│ ملاحظات داخلية: [ ... ]  (لا تظهر للعميل)       │
│ 📎 مرفقات: [اسحب الملفات]                      │
└────────────────────────────────────────────────┘

[حفظ كمسودة] [معاينة] [حفظ وإرسال]
[حفظ وإنشاء جديد] [حفظ وتكرار] [إلغاء]
```

**وسائل التحكم الذكية في المحرر:**
- **تلقائي:** ملء بيانات العميل (عنوان، VAT#، عملة افتراضية)
- **تحقق فوري:** رقم الضريبة للعميل صحيح (VIES/ZATCA lookup)
- **تنبيه ذكي:** إذا العميل متجاوز الحد الائتماني → ⚠️ تنبيه
- **اقتراح AI:** "العميل اعتاد شراء هذه الأصناف → أضفها" (بناءً على التاريخ)
- **مطابقة PO:** إذا مرتبطة بـ PO → يظهر أيقونة 3-way match
- **رسم الفاتورة (Live Preview):** عرض مباشر على اليمين (Arabic/English bilingual)

**اختصارات لوحة المفاتيح داخل المحرر:**
- `Tab` — التنقل بين الحقول
- `Alt+N` — إضافة بند جديد
- `Ctrl+S` — حفظ كمسودة
- `Ctrl+Shift+S` — حفظ وإرسال
- `Esc` — إلغاء مع تأكيد

### 4.2 شاشة المطابقة البنكية (Bank Reconciliation)

مستوحاة من Xero "Find & Match":

```
┌──────────────────────────────────────────────────────────┐
│ المطابقة البنكية — حساب الراجحي *1234                    │
│ الرصيد البنكي: 1,250,000  |  في APEX: 1,245,500  | فرق: 4,500 │
├──────────────────────────────────────────────────────────┤
│ الحركات البنكية (بدون مطابقة)  │  السجلات في APEX        │
├──────────────────────────────────────────────────────────┤
│ 2026-04-15 | -500.00           │  🤖 مُقترح: فاتورة #INV-023 │
│   "HANI CHAIR STORE"           │    500.00 — 2026-04-14  │
│   [موافق ✓] [تقسيم] [تجاهل]    │    ثقة 95%             │
│                                │    [استخدم قاعدة جديدة]  │
├──────────────────────────────────────────────────────────┤
│ 2026-04-16 | -1,200.00         │  🔍 ابحث يدوياً...      │
│   "STC BILL"                   │    [+ إضافة قيد يدوي]   │
│   [موافق ✓] [تقسيم] [تجاهل]    │                        │
└──────────────────────────────────────────────────────────┘

[مطابقة متعددة ذكية (AI Match All)]  [تطبيق قواعد]  [نهاية الجلسة]
```

**وسائل التحكم:**
- **AI Match All** — يطبق AI على كل الحركات ويقترح matches مع مستوى ثقة
- **Rule Creator** — اضغط "إنشاء قاعدة" → "كل حركة تحتوي 'STC BILL' → صنّفها كـ 'اتصالات' بحساب 5420"
- **Split Transaction** — قسّم حركة واحدة على عدة حسابات/مشاريع
- **Transfer** — هذه الحركة هي تحويل بين حسابين داخليين
- **Undo** — إلغاء مطابقة (قابلة خلال اليوم)
- **Lock Reconciliation** — إقفال المطابقة عند الانتهاء (لا يتغير تاريخها)

### 4.3 شاشة الإشعارات المركزية (Notifications Center)

```
┌──────────────────────────────────────────────────────┐
│ الإشعارات                    [قراءة الكل] [الإعدادات] │
│ [الكل] [غير مقروءة] [حرجة] [موافقات] [نظام]         │
├──────────────────────────────────────────────────────┤
│ 🔴 فاتورة متأخرة | INV-045 متأخرة 15 يوم | قبل 5د   │
│ ⚠️ موافقة مطلوبة | PO-012 ينتظر موافقتك | قبل 1س    │
│ 🔔 ZATCA | تم قبول INV-023 | قبل 2س                 │
│ 💬 تعليق جديد | أحمد علّق على JE-019 | قبل 3س       │
│ 📊 تقرير | كشف حركة شهري جاهز | أمس                 │
└──────────────────────────────────────────────────────┘
```

**فئات الإشعارات (يمكن التحكم في كل فئة):**
- حرجة (Critical) — فواتير متأخرة، فشل دفع، تجاوز اعتمادات
- موافقات (Approvals) — طلبات تنتظر موافقتك
- نظام (System) — ترقيات، صيانة
- تنبيهات ذكية (AI Insights) — "المصاريف تجاوزت المعتاد بـ 30%"
- نشاط الفريق (Team Activity) — ما يفعله زملاؤك
- ZATCA — حالة إرسال الفواتير

**إعدادات الإشعارات (لكل فئة):**
- داخل التطبيق ✅/❌
- إيميل ✅/❌
- SMS ✅/❌
- WhatsApp ✅/❌ 🆕
- ملخص يومي/أسبوعي ✅/❌
- أوقات الهدوء (Quiet Hours) — من 22:00 إلى 07:00

### 4.4 شاشة سجل التدقيق (Audit Log)

```
┌─────────────────────────────────────────────────────────┐
│ سجل التدقيق                        [تصدير CSV] [↻]      │
├─────────────────────────────────────────────────────────┤
│ المستخدم: [▼]  الإجراء: [▼]  السجل: [▼]  التاريخ:[من-إلى]│
├─────────────────────────────────────────────────────────┤
│ الوقت        | المستخدم  | الإجراء | السجل     | IP      │
│ 2026-04-18 10:15 | أحمد | UPDATE | INV-023   | 1.1.1.1 │
│   ⚏ التفاصيل: المبلغ من 1,000 → 1,500                   │
│                                                           │
│ 2026-04-18 10:10 | سارة | DELETE | JE-019    | 2.2.2.2 │
│   ⚏ التفاصيل: تم حذف قيد بقيمة 5,000                    │
└─────────────────────────────────────────────────────────┘
```

**الأعمدة:**
الوقت (UTC+local)، المستخدم، الإجراء (CREATE/UPDATE/DELETE/LOGIN/EXPORT)، نوع السجل، معرف السجل، IP، جهاز، قبل/بعد (JSON diff)، سياق (request ID).

**الفلاتر:**
- المستخدم (مع اقتراح ذكي)
- الإجراء (مع أيقونات: 🆕 CREATE, ✏️ UPDATE, 🗑️ DELETE, 🔐 AUTH, 📤 EXPORT)
- نوع السجل (Invoice, JE, Client, User, Permission...)
- التاريخ + الوقت
- IP
- Request ID (للتبع الكامل)

**ميزات حاسمة:**
- **غير قابل للحذف:** السجل append-only — لا يوجد زر حذف
- **توقيع رقمي:** كل سجل له hash يربطه بالسابق (blockchain-style)
- **Export للمدقق الخارجي:** تصدير PDF موقع رقمياً
- **تنبيه شذوذ:** AI يكتشف أنماط غير طبيعية (تعديلات بعد ساعات الدوام، تحويلات كبيرة مفاجئة)

### 4.5 شاشة الإعدادات العامة (Settings Hub)

منظمة كـ **Sections قابلة للطي** مثل Zoho:

```
⚙️ الإعدادات
├─ 🏢 المنشأة
│   ├─ معلومات المنشأة (الاسم، العنوان، الشعار)
│   ├─ الشهادات الضريبية (الرقم الضريبي، CR، GOSI)
│   ├─ الفروع والكيانات (Multi-entity)
│   ├─ العملات المعتمدة + أسعار الصرف
│   ├─ الفترات المحاسبية + السنة المالية
│   └─ التقويم (Hijri/Gregorian toggle)
│
├─ 🎨 التخصيص
│   ├─ القوالب (فاتورة/إيصال/عرض سعر) — Brand kit
│   ├─ الحقول المخصصة (Custom Fields)
│   ├─ الترقيم التسلسلي (Numbering sequences)
│   ├─ اللغة الافتراضية + RTL
│   └─ الموضوع (Light/Dark/Auto)
│
├─ 👥 المستخدمون والفريق
│   ├─ المستخدمون (دعوة/إلغاء/تعطيل)
│   ├─ الأدوار (Presets + Custom)
│   ├─ التصاريح الدقيقة (Permission Matrix)
│   ├─ SSO (SAML/OIDC) 🆕
│   ├─ 2FA إلزامي (Org-level)
│   └─ سياسة كلمات السر
│
├─ ✅ سير الموافقات 🆕
│   ├─ قواعد الموافقة (Approval Rules)
│   ├─ سلسلة التصعيد
│   ├─ التفويض (Delegation)
│   └─ سجل الموافقات
│
├─ 🔐 الأمان والحوكمة
│   ├─ إقفال الفترات (Lock Dates)
│   ├─ فصل المهام (SoD Matrix)
│   ├─ سجل الجلسات
│   ├─ أجهزة موثوقة
│   ├─ IP Whitelist 🆕
│   └─ مدة الجلسة الافتراضية
│
├─ 🔗 التكاملات
│   ├─ البنوك (Bank Feeds) 🆕
│   ├─ بوابات الدفع (Stripe, HyperPay, Paytabs)
│   ├─ ZATCA (Fatoora)
│   ├─ GOSI / Mudad 🆕
│   ├─ WhatsApp Business 🆕
│   ├─ Zapier / Make
│   ├─ Google Drive / Dropbox / OneDrive
│   ├─ Slack / Teams
│   └─ API Keys (للمطورين)
│
├─ 📧 قوالب البريد والإشعارات
│   ├─ قوالب إيميل (فاتورة، تذكير، شكر)
│   ├─ قوالب SMS
│   ├─ قوالب WhatsApp
│   └─ تذكيرات تلقائية (Payment Reminders)
│
├─ 🧾 الاشتراك والفواتير
│   ├─ الخطة الحالية (Current Plan)
│   ├─ الاستخدام (Usage: Users, Invoices, Storage)
│   ├─ طرق الدفع
│   ├─ سجل الفواتير
│   └─ ترقية/تخفيض الخطة
│
└─ 📜 قانوني
    ├─ الشروط والأحكام
    ├─ سياسة الخصوصية
    ├─ اتفاقيات معالجة البيانات (DPA)
    └─ تصدير بيانات الحساب (GDPR-style)
```

### 4.6 المفاتيح الاختصارية العامة (Keyboard Shortcuts)

مستوحاة من Xero + QBO — يجب أن تكون **متطابقة** لكل APEX:

| الاختصار | الوظيفة |
|---|---|
| `Ctrl/Cmd + K` | البحث العام (Command palette) |
| `G` ثم `D` | اذهب إلى Dashboard |
| `G` ثم `I` | اذهب إلى Invoices |
| `G` ثم `B` | اذهب إلى Banking |
| `G` ثم `C` | اذهب إلى Contacts |
| `G` ثم `R` | اذهب إلى Reports |
| `N` | إنشاء جديد (حسب الصفحة) |
| `/` | التركيز على شريط البحث |
| `?` | عرض قائمة الاختصارات |
| `Ctrl + S` | حفظ |
| `Ctrl + Shift + S` | حفظ وإرسال |
| `Esc` | إلغاء/إغلاق |
| `↑↓` | التنقل بين السجلات |
| `Enter` | فتح السجل المحدد |

### 4.7 زر الإنشاء الشامل (Global + Menu)

المبدأ: من أي شاشة، زر `+` يفتح قائمة بكل ما يمكن إنشاؤه — لا حاجة للتنقل:

```
+ إنشاء جديد
├─ المبيعات
│   ├─ فاتورة (N → I)
│   ├─ عرض سعر
│   ├─ إشعار دائن
│   └─ دفعة مستلمة
├─ المشتريات
│   ├─ فاتورة واردة
│   ├─ أمر شراء
│   └─ مصاريف
├─ المحاسبة
│   ├─ قيد يومية (N → J)
│   ├─ حركة بنكية
│   └─ تحويل بين حسابات
├─ جهات الاتصال
│   ├─ عميل
│   ├─ مورد
│   └─ موظف
├─ المخزون
│   └─ صنف جديد
└─ متقدم
    ├─ مشروع
    ├─ قسم
    └─ بند ضريبي
```

---

## الفصل 5 — طبقة الحوكمة والتحكم

### 5.1 نظام سير الموافقات (Approval Workflows Engine)

**الموديولات التي تحتاج موافقات:**
- الفواتير (Invoices) — قبل الإرسال
- فواتير المشتريات (Bills) — قبل الدفع
- القيود اليومية (Journal Entries) — قبل الترحيل
- أوامر الشراء (POs)
- كشف الرواتب (Payroll Runs)
- تعديل شجرة الحسابات
- إقفال الفترة
- تصدير البيانات الكبيرة

**شكل القاعدة (Approval Rule):**

```json
{
  "name": "موافقة فواتير شراء > 10,000 ريال",
  "module": "bill",
  "conditions": [
    {"field": "total_amount", "op": ">=", "value": 10000},
    {"field": "currency", "op": "==", "value": "SAR"}
  ],
  "steps": [
    {
      "order": 1,
      "approver_type": "role",
      "approver": "finance_manager",
      "sla_hours": 24,
      "on_timeout": "escalate"
    },
    {
      "order": 2,
      "approver_type": "user",
      "approver": "cfo@example.com",
      "sla_hours": 48,
      "required_comment": true
    }
  ],
  "parallel": false,
  "can_delegate": true,
  "notify_on": ["submitted", "approved", "rejected", "timeout"]
}
```

**ميزات متقدمة:**
- ✅ **موافقة متوازية** (parallel approvals — إما اثنين أو اتفاق جميعهم)
- ✅ **شرط ديناميكي على Dimension** (مثال: مشاريع المصرف الأهلي → يوافق أحمد)
- ✅ **تفويض** (Delegation: "أحمد في إجازة، تسير موافقاته لسارة من X إلى Y")
- ✅ **تصعيد تلقائي** عند تجاوز SLA
- ✅ **إعادة فتح** (Re-open) بعد الرفض
- ✅ **محادثة داخل الموافقة** (Comments thread)
- ✅ **تذكيرات ذكية** (WhatsApp/Email/In-app)

**شاشة قائمة الموافقات:**
```
┌────────────────────────────────────────────────┐
│ طلباتي للموافقة   |   طلبات أرسلتها            │
├────────────────────────────────────────────────┤
│ [الكل] [عاجلة] [متأخرة] [معلقة]                │
├────────────────────────────────────────────────┤
│ ⏰ BILL-089 | 15,000 SAR | أحمد السبحاني      │
│    Step 1/2 | SLA: 18س متبقية                  │
│    [موافق] [رفض] [تفويض] [عرض التفاصيل]       │
└────────────────────────────────────────────────┘
```

### 5.2 إقفال الفترات (Period Close / Lock Dates)

**Lock Dates Table:**
| الوحدة (Module) | Lock Date | الموقّع | يمكن التجاوز |
|---|---|---|---|
| جميع الوحدات | 2026-03-31 | سارة (Controller) | لا |
| الفواتير فقط | 2026-04-30 | أحمد (Manager) | نعم — بموافقة |

**وسائل التحكم:**
- **Two-lock system:**
  - **Soft lock** (تنبيه عند المحاولة، يتطلب justification)
  - **Hard lock** (مستحيل التعديل، حتى للإدمن)
- **Audit trail:** كل override يُسجل كاملاً
- **Closing checklist:** قائمة مهام إقفال (Trial balance balanced, reconciled, depreciation posted...)
- **Variance analysis:** AI يولّد تفسيرات للتغيرات المهمة (flux commentary)

### 5.3 فصل المهام (SoD Matrix)

Segregation of Duties — شرط SOC 2 و ISO 27001:

| الوظيفة | لا يمكن الجمع مع |
|---|---|
| إنشاء مورد | دفع فاتورة |
| إنشاء فاتورة شراء | الموافقة على فاتورة شراء |
| إدخال راتب | الموافقة على كشف الرواتب |
| إنشاء قيد | مراجعة قيد |
| إدارة البنك | المطابقة البنكية (للرقابة) |

عند إسناد دور لمستخدم، النظام يكتشف التعارض ويمنع/يحذر.

### 5.4 IP Whitelisting + Device Trust

- **IP Allowlist** على مستوى المنظمة/الدور
- **Device fingerprinting** مع "تذكر هذا الجهاز 30 يوم"
- **إشعار تسجيل دخول** من جهاز/IP جديد (Email + SMS)
- **زر Revoke All Sessions** للقلق/الاختراق

### 5.5 Data Residency & Retention

- **اختيار الإقليم:** KSA (Riyadh) / UAE (Dubai) / EU / US
- **Retention Policies:**
  - Audit logs: 7 سنوات (ZATCA يطلب 5 سنوات)
  - Invoices: 10 سنوات
  - User data: حتى طلب الحذف (GDPR-style)
- **Legal Hold:** منع حذف سجلات محددة أثناء تحقيق

### 5.6 الشهادات المستهدفة

| الشهادة | الأولوية | التوقيت |
|---|---|---|
| SOC 2 Type II | P0 | Q2 2026 |
| ISO 27001 | P0 | Q3 2026 |
| ZATCA Compliant Vendor Certification | P0 | Q1 2026 |
| NCA Compliance (KSA) | P1 | Q3 2026 |
| GDPR + CCPA alignment | P1 | Q2 2026 |
| PCI DSS (إذا تعاملنا بالبطاقات) | P1 | Q4 2026 |

---

## الفصل 6 — الامتثال الإقليمي

### 6.1 ZATCA Phase 2 (أولوية قصوى — KSA)

**المكونات المطلوبة:**

| المكون | الحالة الحالية | المطلوب |
|---|---|---|
| XML UBL 2.1 generator | ⚠️ جزئي (core/zatca_service.py) | يحتاج توسع وتدقيق |
| Cryptographic stamp (PKI) | ❌ | توقيع بشهادة CSID |
| TLV Base64 QR code | ⚠️ جزئي | تحقق من الأنماط |
| CSID onboarding flow | ❌ | UI لتسجيل كل POS/billing unit |
| Clearance API client | ❌ | realtime لـ B2B |
| Reporting API client | ❌ | خلال 24س لـ B2C |
| Invoice status lifecycle | ⚠️ جزئي | Draft → Submitted → Cleared/Rejected |
| 5-year signed archive | ❌ | مع hash verification |
| Wave assignment tracking | ❌ | نعرف الموجة للعميل (23/24) |
| Offline queue | ❌ | إذا ZATCA API down |

**الشاشة المستحقة (`/compliance/zatca-dashboard`):**

```
┌─────────────────────────────────────────────────┐
│ لوحة ZATCA                                      │
├─────────────────────────────────────────────────┤
│ الشهادة: ✅ نشطة | انتهاء: 2027-03-15           │
│ الموجة: 23 (إلزامي منذ 2026-03-31)             │
├─────────────────────────────────────────────────┤
│ اليوم: 45 فاتورة مُرسلة | 3 مرفوضة | 1 معلّقة  │
│ هذا الأسبوع: 312 | الشهر: 1,244                 │
├─────────────────────────────────────────────────┤
│ ⚠️ الفواتير المرفوضة (3):                      │
│   INV-045 | BR-KSA-2-234 | "Invalid VAT Number"│
│   [إصلاح] [عرض XML] [إعادة إرسال]              │
│                                                  │
│ 📊 [تقارير الامتثال] [سجل التقديم]             │
└─────────────────────────────────────────────────┘
```

### 6.2 UAE WPS (Wages Protection System)

**الميزات المطلوبة:**
- **SIF Generator** — إنشاء ملف SIF بصيغة UAE Central Bank
- **Bank Agent Configuration** — اختيار البنك الوسيط
- **Salary Cycle Tracking** — دورات الرواتب الشهرية
- **Employee onboarding to WPS** — خلال 30 يوم من التعيين
- **Status Tracking** — paid/pending/rejected per employee
- **24h Updates** — تحديث المستحقات عند التعديل

**Schema المقترح:**
```python
class WPSFile(Base):
    id, payroll_run_id, bank_agent_code, file_hash,
    generated_at, submitted_at, status,
    employee_count, total_amount, currency="AED"

class WPSEmployeeRecord(Base):
    id, wps_file_id, employee_id, mol_id,
    basic_salary, variable_wages, fixed_deductions,
    status, rejection_reason
```

### 6.3 KSA Mudad / WPS + GOSI

**Mudad Integration:**
- إرسال كشف الرواتب الشهري إلى SIMAH/SAMA
- قائمة البنوك المعتمدة
- استقبال confirmation

**GOSI Integration:**
- تسجيل موظف جديد خلال 15 يوم
- حساب الاشتراك (Saudi vs Non-Saudi rate tables)
- EOSB tracking
- Nitaqat (Saudization) reporting
- Qiwa sync (MoL)

### 6.4 Multi-Jurisdiction Tax Returns

| الإقرار | الدولة | الدورية | الحالة |
|---|---|---|---|
| VAT Return (ZATCA) | KSA | شهري/ربع سنوي | ⚠️ جزئي |
| VAT Return (FTA) | UAE | ربع سنوي | ❌ |
| WHT Return | KSA, UAE, EG | شهري | ⚠️ جزئي |
| Zakat Declaration | KSA | سنوي | ⚠️ جزئي |
| Corporate Income Tax | KSA, UAE, EG | سنوي | ⚠️ جزئي |
| FAF (Audit File) | UAE | عند الطلب | ❌ |
| ETA (Egypt E-invoicing) | EG | realtime | ❌ |

### 6.5 Localization (التعريب)

**ما يجب أن يكون first-class:**
- ✅ Arabic RTL (موجود جزئياً — يحتاج audit شامل)
- ❌ Hijri calendar (Umm al-Qura) — dual date picker
- ❌ Eastern Arabic digits toggle (٠١٢٣٤٥٦٧٨٩)
- ❌ Bilingual invoice templates (Arabic + English stacked)
- ⚠️ Arabic-first font (Cairo, IBM Plex Arabic, Readex)
- ❌ Ramadan working hours (للـ timesheets)
- ❌ Saudi holidays calendar
- ❌ Arabic number-to-text (للشيكات: "فقط خمسة آلاف ريال لا غير")

### 6.6 Cheque Register (الشيكات)

ممارسة أساسية في KSA/UAE — لا يوجد في Xero/QBO:

**الحقول:**
```
رقم الشيك، البنك المسحوب عليه، المستفيد، المبلغ،
تاريخ الاستحقاق (PDC)، الحالة (مُصدر/مقدم/مُصرّف/مُرتجع)،
السبب (للمرتجع)، مرفقات
```

**الأزرار:**
- طباعة شيك (بتنسيق البنك — MICR line)
- تسجيل شيك PDC (post-dated)
- تسجيل شيك وارد
- تحويل شيك لـ bill
- تنبيه 3 أيام قبل الاستحقاق

---

## الفصل 7 — طبقة الذكاء الاصطناعي

### 7.1 الـ Copilot — المساعد المالي الذكي

**الحالة:** أساس موجود (`app/copilot/`). يحتاج توسع.

**القدرات المستهدفة:**

| القدرة | المثال | مستوى الجاهزية |
|---|---|---|
| Q&A محاسبي عام | "ما هو IFRS 16؟" | ✅ جاهز |
| Q&A على بياناتي | "كم إيرادي في مارس؟" | ⚠️ جزئي — يحتاج RAG على البيانات |
| تحليل مدفوع بالسياق | "لماذا انخفض الربح؟" | ❌ |
| تنفيذ أوامر (Agentic) | "أنشئ فاتورة لعميل X بـ 5000" | ❌ |
| شرح القيود | "فسّر لي هذا القيد" | ✅ جاهز |
| اقتراح COA mapping | موجود في COA Engine | ✅ جاهز |
| كشف الشذوذ | "هذه المصاريف غير طبيعية" | ❌ |

### 7.2 AI Reconciliation (مثل Xero JAX)

**الخوارزمية:**
1. استخرج patterns من المطابقات السابقة للعميل (payee name, amount range, account)
2. لكل حركة بنكية جديدة:
   - ابحث عن match exact first
   - ثم fuzzy match (Levenshtein على اسم المستفيد)
   - ثم rule-based match (قواعد البنك)
   - ثم AI suggestion مع confidence score
3. إذا confidence > 90% → auto-apply (configurable)
4. إذا 70-90% → suggestion مع "موافق"
5. أقل من 70% → يبقى للمراجعة اليدوية

**البيانات المستخدمة (anonymized cross-tenant learning — اختياري):**
"كل العملاء يصنفون 'STC' كـ 'اتصالات' → اقترح تلقائياً"

### 7.3 Cash Flow Forecasting (ML)

**Input:**
- AR aging (فواتير مستحقة)
- AP aging (دفعات مستحقة)
- Recurring transactions
- Historical patterns (seasonality)
- Open POs

**Output:**
- توقع 90 يوم قادم (iso-weekly buckets)
- Scenarios: Best / Base / Worst
- What-if: "ماذا لو تأخر 3 عملاء كبار؟"
- Cash runway (أسابيع متبقية من النقد الحالي)

### 7.4 Anomaly Detection

**الأنماط المستهدفة:**
- **Round-number fraud** (5,000 / 10,000 / 50,000 نمط مشبوه)
- **Off-hours entries** (قيود بعد منتصف الليل)
- **Duplicate invoices** (نفس المبلغ + نفس المورد خلال 24س)
- **Vendor name typo attack** (“Micro5oft” بدل Microsoft)
- **Expense category spike** (+300% فجأة)
- **New vendor large amount** (مورد أول معاملة > 50K)

لكل نمط: Severity (🔴/🟡/🟢) + شرح + إجراء مقترح.

### 7.5 Natural Language Analytics

**الاستعلامات الذكية:**
- "أعلى 10 عملاء بالإيرادات في Q1"
- "قارن الربح هذا الشهر بالشهر الماضي"
- "ما المصاريف التي تجاوزت الميزانية؟"
- "لماذا انخفض الهامش في مشروع Alpha؟"

النتيجة: **جدول/رسم + سرد نصي مفسّر + مصادر (drill-down إلى القيود)**.

### 7.6 Agentic AI (المستقبل)

**Agents مخطط لها:**

| Agent | الدور | الأمثلة |
|---|---|---|
| **Invoice Agent** | ينشئ فواتير تلقائياً | "عميل X طلب 5 وحدات → فاتورة جاهزة" |
| **Bill Agent** | يعالج فواتير موردين | "PDF وصل → OCR → match مع PO → ready to approve" |
| **Payroll Agent** | يجمع ساعات العمل | "اسأل الموظفين عبر WhatsApp → كشف جاهز" |
| **Reminder Agent** | يلاحق المدفوعات المتأخرة | "INV-045 متأخرة → أرسل reminder مخصص" |
| **Close Agent** | يساعد في إقفال الشهر | "شغّل checklist، اكتب flux commentary" |

**مبدأ الأمان:** كل agent يقترح فقط — الإنسان يوافق قبل التنفيذ (Human in the loop).

---

## الفصل 8 — التصاريح والأدوار

### 8.1 الأدوار الافتراضية (Preset Roles)

| الدور | الوصف | المسموح |
|---|---|---|
| **Owner (مالك)** | صاحب الحساب | كل شيء بما في ذلك الحذف |
| **Admin (مدير)** | مدير النظام | كل شيء عدا البيلنغ وحذف المنشأة |
| **Finance Manager** | مدير مالي | كل المبيعات/المشتريات/المحاسبة + approvals |
| **Accountant** | محاسب | إدخال/تعديل + قراءة التقارير — لا يوافق على دفعات |
| **Bookkeeper** | مُمسك دفاتر | إدخال فقط — لا تعديل بعد الإرسال |
| **AP Clerk** | محاسب مدفوعات | Bills فقط — read + draft |
| **AR Clerk** | محاسب مقبوضات | Invoices فقط — read + draft |
| **Payroll Officer** | موظف رواتب | Payroll + HR فقط |
| **Auditor (مدقق)** | مدقق خارجي | Read-only على كل شيء + Audit trail |
| **Executive / CFO** | تنفيذي | Dashboards + Reports فقط |
| **Invoice-Only User** | (مثل Xero) | ينشئ فواتير فقط — لا يرى التقارير |
| **Time Tracker** | موظف يسجل وقته | Timesheets فقط |

### 8.2 مصفوفة التصاريح (Permission Matrix — sample)

```
Module: Invoices
├─ invoice.read        ✅ Auditor, AR, Accountant, Admin
├─ invoice.create      ✅ AR, Accountant, Admin
├─ invoice.update      ✅ AR (draft only), Accountant, Admin
├─ invoice.delete      ✅ Admin (draft only)
├─ invoice.void        ✅ Admin, Finance Manager
├─ invoice.send        ✅ AR, Admin, Finance Manager
├─ invoice.approve     ✅ Finance Manager, CFO
└─ invoice.bulk_export ✅ Admin, Auditor
```

### 8.3 نطاق التصريح (Permission Scope)

كل تصريح يمكن أن يكون مقيداً بـ:
- **Entity** (الفرع/الكيان)
- **Dimension** (مشروع/قسم)
- **Amount threshold** ("فقط invoices < 10,000")
- **Time window** ("فقط الشهر الحالي")
- **Customer/Vendor segment** ("فقط عملاء المنطقة الشرقية")

### 8.4 SAML 2.0 / OIDC SSO

**Providers مستهدفة:**
- Microsoft Entra ID (Azure AD)
- Okta
- OneLogin
- Google Workspace
- Centrify
- Custom OIDC

**الميزات:**
- SCIM 2.0 للـ auto-provisioning
- Just-In-Time (JIT) user creation
- Role mapping from IdP groups
- Forced SSO (no password fallback for SAML users)

---

## الفصل 9 — مصفوفة الفجوات

### 9.1 الـ Backend

| الميزة | الحالة | الأولوية | الجهد |
|---|---|---|---|
| Core auth + JWT | ✅ موجود | — | — |
| 2FA (real TOTP, not stub) | ❌ | P0 | أسبوع |
| Social auth (real validation) | ❌ | P0 | أسبوع |
| SAML/OIDC SSO | ❌ | P1 | 3 أسابيع |
| Role engine | ✅ موجود (Phase 1) | — | — |
| Fine-grained permissions (scope) | ⚠️ يحتاج توسيع | P1 | أسبوعين |
| Approval workflow engine | ❌ | P0 | 3 أسابيع |
| Lock dates + period close | ⚠️ جزئي | P1 | أسبوعين |
| Audit trail (immutable) | ⚠️ موجود لكن لا hash chain | P1 | أسبوع |
| Rate limiter (Redis-backed) | ❌ | P0 | 3 أيام |
| Alembic migrations (per-phase) | ❌ | P1 | 3 أيام + تكلفة تشغيل |
| ZATCA Phase 2 full | ⚠️ جزئي | P0 | 6 أسابيع |
| Bank feeds integration | ❌ | P0 | 8 أسابيع (يحتاج vendor) |
| AI reconciliation | ❌ | P0 | 4 أسابيع |
| OCR pipeline (Claude vision) | ❌ | P0 | أسبوعين |
| WhatsApp Business API | ❌ | P1 | أسبوعين |
| Cheque register | ❌ | P1 | أسبوعين |
| Multi-entity consolidation | ⚠️ موجود جزئي في core/ | P1 | 4 أسابيع |
| Dimensional accounting | ❌ | P0 | 3 أسابيع |
| UAE WPS SIF | ❌ | P1 | أسبوعين |
| KSA Mudad integration | ❌ | P1 | 3 أسابيع |
| GOSI integration | ❌ | P1 | 3 أسابيع |
| Bilingual invoice PDF | ⚠️ جزئي | P0 | أسبوع |
| Hijri calendar support | ❌ | P1 | أسبوع |
| Cash flow forecasting ML | ❌ | P2 | 4 أسابيع |
| Anomaly detection | ❌ | P2 | 3 أسابيع |
| Agentic AI (bill/invoice agents) | ❌ | P2 | 8 أسابيع |

### 9.2 الـ Frontend

| الميزة | الحالة | الأولوية | الجهد |
|---|---|---|---|
| GoRouter setup | ✅ 63 route | — | — |
| Riverpod state | ✅ موجود | — | — |
| **main.dart refactor** (3500 → modules) | ⚠️ ضروري | P0 | 3 أسابيع |
| Global `Cmd+K` search | ❌ | P0 | أسبوعين |
| Keyboard shortcuts library | ❌ | P1 | أسبوع |
| Role-based dashboards | ❌ | P1 | 3 أسابيع |
| Drag-drop dashboard widgets | ❌ | P2 | 3 أسابيع |
| Bulk actions bar | ❌ | P1 | أسبوعين |
| Command palette | ❌ | P1 | أسبوعين |
| Right-panel contextual | ❌ | P2 | أسبوعين |
| Dark mode | ❌ | P1 | أسبوع |
| Mobile-first tablet responsive | ⚠️ جزئي | P1 | 4 أسابيع |
| Flutter mobile app (iOS/Android) | ❌ | P2 | 10 أسابيع |
| Deep RTL audit (bidi perfection) | ⚠️ يحتاج مراجعة | P0 | أسبوعين |
| Eastern Arabic digits toggle | ❌ | P1 | 3 أيام |
| Customizable report builder UI | ❌ | P2 | 4 أسابيع |
| Inline help tooltips | ⚠️ جزئي | P2 | أسبوعين |
| Onboarding tour (Intro.js style) | ❌ | P1 | أسبوع |

### 9.3 الـ DevOps / Infrastructure

| البند | الحالة | الأولوية |
|---|---|---|
| Production-ready rate limiting (Redis) | ❌ | P0 |
| CI: Flutter build + tests | ❌ | P1 |
| CI: load tests | ❌ | P2 |
| Staging environment | ⚠️ غير واضح | P1 |
| Blue-green deployment | ❌ | P2 |
| Observability (Sentry, Datadog) | ❌ | P0 |
| Log aggregation | ❌ | P0 |
| Daily backups + point-in-time restore | ⚠️ Render? | P0 |
| DR plan (Disaster Recovery) | ❌ | P1 |
| KSA/UAE data residency | ❌ | P0 للـ enterprise |

---

## الفصل 10 — خارطة التنفيذ

### 10.1 المراحل الأربع (4-Phase Roadmap)

#### 🔴 Phase A — Foundation Hardening (الشهرين 1-2)
**الهدف:** إغلاق الفجوات الأمنية + تأسيس البنية التحتية الإنتاجية.

- [ ] إصلاح Social auth stubs (Google/Apple token validation)
- [ ] TOTP 2FA حقيقي (replace SMS stub)
- [ ] Redis-backed rate limiter
- [ ] Sentry + log aggregation (Datadog/CloudWatch)
- [ ] Alembic migrations لكل Phase موجود
- [ ] Flutter CI pipeline (build + widget tests)
- [ ] `main.dart` refactor — تقسيم لـ modules
- [ ] RTL audit شامل + Eastern Arabic digits
- [ ] Bilingual invoice PDF templates
- [ ] Immutable audit trail (hash chain)
- [ ] Staging environment + Blue-green deployment
- [ ] KSA data residency (Render/AWS me-south-1)

#### 🟡 Phase B — Competitive Parity (الشهور 3-5)
**الهدف:** الوصول لمستوى Wafeq/Qoyod + إضافة ميزات Xero الأساسية.

- [ ] **ZATCA Phase 2 Full Stack** (XML, stamp, QR, CSID, clearance, archive)
- [ ] **Approval Workflows Engine** (multi-step, conditional, delegation)
- [ ] **Lock Dates + Period Close** مع checklist
- [ ] **Dimensional Accounting** (Project, Department, Location, Custom)
- [ ] **Cheque Register + PDC**
- [ ] **Client Portal** (العميل يشاهد فواتيره ويدفع)
- [ ] **Receipt OCR** (Claude Vision) + Email-in inbox
- [ ] **Cmd+K Global Search**
- [ ] **Bulk Actions** across major entities
- [ ] **Role-Based Dashboards** (CFO/Accountant/AR/AP views)
- [ ] **UAE WPS SIF** generator
- [ ] **Hijri Calendar** dual picker
- [ ] **Customizable Numbering Sequences**
- [ ] **WhatsApp Business** invoice sending

#### 🟢 Phase C — Differentiation (الشهور 6-9)
**الهدف:** ميزات تفوقنا على Zoho MENA + تلائم enterprise.

- [ ] **AI Auto-Reconciliation** (Xero JAX-class) + Bank Rules
- [ ] **Natural Language Analytics** ("لماذا انخفض الربح؟")
- [ ] **Anomaly Detection** (6+ patterns)
- [ ] **Cash Flow Forecasting ML** (90-day, scenarios)
- [ ] **Multi-Entity Consolidation** (real-time, auto-elimination)
- [ ] **SAML 2.0 / OIDC SSO** (Azure AD, Okta, Google)
- [ ] **SCIM 2.0** auto-provisioning
- [ ] **Bank Feeds** (partner with Lean / Tarabut / Fintech Saudi sandbox)
- [ ] **KSA Mudad + GOSI** integrations
- [ ] **Qiwa sync** (MoL)
- [ ] **Deep SoD Matrix** + conflict detection
- [ ] **Drag-drop Dashboard Widgets**
- [ ] **Custom Report Builder** (no-code)
- [ ] **Flutter Mobile Apps** (iOS + Android)
- [ ] **SOC 2 Type II** certification
- [ ] **ISO 27001** certification

#### 🔵 Phase D — Market Leadership (الشهور 10-18)
**الهدف:** ميزات تصنع الفارق — "لهذا APEX هي الرقم 1".

- [ ] **Agentic AI** (Invoice, Bill, Payroll, Reminder, Close agents)
- [ ] **Embedded Lending** (شراكة مع Lendo/Funding Souq/بنك محلي)
- [ ] **Embedded Insurance** (شراكة مع Tawuniya/ADNIC)
- [ ] **Voice Input** (اطلب من جوالك: "أنشئ فاتورة 5000 لشركة الأهلي")
- [ ] **App Marketplace** (API-first + partner onboarding)
- [ ] **White-label** للـ accounting firms
- [ ] **Industry verticals** (Restaurant/Retail/Contracting/Education)
- [ ] **Egypt ETA e-invoicing** integration
- [ ] **Oman/Bahrain/Qatar** localizations
- [ ] **Arabic LLM fine-tuning** (دقة أعلى في Claude responses)
- [ ] **AR/VR Financial Planning** (experimental)

### 10.2 مؤشرات النجاح (Success Metrics)

| KPI | Baseline (الآن) | هدف 6 أشهر | هدف 12 شهر |
|---|---|---|---|
| Active tenants | ? | 500 | 5,000 |
| MAU | ? | 2,000 | 25,000 |
| MRR (SAR) | ? | 250K | 2.5M |
| Time-to-first-invoice (min) | ? | < 10 | < 5 |
| Invoice cycle time (avg) | - | -20% vs manual | -50% |
| AI reconciliation accuracy | - | 80% | 92% |
| ZATCA clearance success rate | - | 98% | 99.9% |
| NPS | - | 35 | 55 |
| Churn (monthly) | - | < 5% | < 2% |
| SOC 2 / ISO 27001 | ❌ | In progress | ✅ |

### 10.3 الفريق المقترح

| الدور | العدد الحالي | العدد المطلوب | أولوية |
|---|---|---|---|
| Backend (Python/FastAPI) | ? | 4-6 | P0 |
| Frontend (Flutter) | ? | 3-4 | P0 |
| AI/ML Engineer | ? | 2 | P1 |
| DevOps/SRE | ? | 2 | P0 |
| QA/Test Automation | ? | 2 | P1 |
| UX/UI Designer (Arabic-first) | ? | 2 | P0 |
| Product Manager | ? | 2 | P0 |
| Tax/Compliance Specialist (Saudi CPA) | ? | 1 | P0 |
| Security/Compliance Officer | ? | 1 | P1 |
| Customer Success | ? | 3+ | P1 |

### 10.4 الشراكات الاستراتيجية (Must-have)

| الشراكة | القيمة | الحالة |
|---|---|---|
| ZATCA accredited vendor | امتثال قانوني كامل | P0 |
| SAMA/Central Bank UAE for WPS | دخول Payroll | P1 |
| Bank aggregator (Lean, Tarabut, Fintech Saudi) | Bank Feeds | P0 |
| Payment gateway MENA (HyperPay, Paytabs, Checkout) | Payments | ✅ جزئي |
| Anthropic (Claude API Enterprise) | AI scale | ✅ جزئي |
| WhatsApp Business Solution Provider | WhatsApp | P1 |
| Lending partner (Lendo/Funding Souq/Tamam) | Embedded finance | P2 |
| Accountant association (SOCPA, ICAEW) | Distribution | P1 |

---

## 📌 خلاصة تنفيذية

### الثلاث حقائق الأساسية

1. **نحن أمام منصة ضخمة مبنية جيداً تقنياً** — 11 Phase + 6 Sprint + 705 اختبار — لكنها تحتاج **إحكام Governance + إكمال ZATCA + إصلاح الفجوات الأمنية الثلاث** قبل أي توسع.

2. **الفارق بيننا وبين Zoho/Wafeq ليس في العمق المحاسبي** (نحن نتفوق في IFRS tools). الفارق في: **AI reconciliation، Bank feeds، Approval workflows، Client portal، WhatsApp، ومستوى الـ UX الاحترافي (Cmd+K، keyboard shortcuts، role-based dashboards)**.

3. **السوق المستهدف (MENA SMB + Mid-market) يشترون على 3 محاور:** الامتثال المحلي (ZATCA/WPS/GOSI) + السعر (أقل من Zoho per-user) + الذكاء الاصطناعي بالعربية. إذا أتقنّا الثلاثة → رقم 1 حقيقي.

### الخطوة التالية الفورية

اختيار واحد من هذه كـ sprint لأسبوعين قادمين (بالترتيب المقترح):

1. **Security hardening sprint** — إغلاق الفجوات الثلاث الحرجة (social auth, SMS stub, rate limiter) + audit trail hash chain.
2. **ZATCA Phase 2 closure sprint** — إكمال XML + stamp + clearance.
3. **main.dart refactor sprint** — تقسيم الـ monolith.
4. **Approval workflow engine** — البنية الأساسية قبل المزيد من الميزات.

---

**نهاية الوثيقة — v1.0**

> للتحديث، اتصل بقسم المنتج. ستتم مراجعة هذه الوثيقة كل ربع سنة.
