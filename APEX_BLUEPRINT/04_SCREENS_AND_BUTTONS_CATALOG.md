# 04 — Screens & Buttons Catalog / فهرس الشاشات والأزرار

> Reference: continues from `03_NAVIGATION_MAP.md`. Next: `05_API_ENDPOINTS_MASTER.md`.
> **Format:** For each major screen — purpose, fields, every button/CTA (Arabic + English), what each button does (navigation/API call/dialog), permission, plan tier.

---

## How to Read This Document / كيفية قراءة هذه الوثيقة

Each screen entry follows this structure:

```
### Screen Name (Arabic / English)
- Path: /path/here
- Class: ScreenWidgetName
- File: lib/screens/x/y.dart
- Purpose: ...
- Required role: ...
- Min plan: ...
- Fields shown: ...
- Buttons:
  | EN Label | AR Label | Action | API/Route | Permission |
```

---

## A. Auth Screens / شاشات التحقق

### A1. Login Screen / شاشة تسجيل الدخول
- **Path:** `/login`
- **Class:** `SlideAuthScreen` (was `LoginScreen`)
- **File:** `lib/screens/auth/slide_auth_screen.dart`
- **Purpose:** User authentication entry point.
- **Required role:** None (public)
- **Min plan:** N/A
- **Fields:**
  - Username/email (`_u` controller)
  - Password (`_p` controller, with visibility toggle)
- **Buttons:**

| EN | AR | Action | API/Route |
|----|----|--------|-----------|
| Login | تسجيل الدخول | Submit credentials | `POST /auth/login` |
| Register | إنشاء حساب | Navigate | → `/register` |
| Forgot password | نسيت كلمة المرور | Navigate | → `/forgot-password` |
| Demo (URL `?demo=1`) | تجربة | Auto-fill `shady`/`Aa@123456` then login | `POST /auth/login` |
| Sign in with Google | تسجيل بحساب جوجل | OAuth flow | `POST /auth/social/google` |
| Sign in with Apple | تسجيل بحساب آبل | OAuth flow | `POST /auth/social/apple` |
| Toggle Arabic/English | عربي / English | Toggle UI language | `appSettingsProvider.setLanguage()` |

### A2. Register Screen / شاشة التسجيل
- **Path:** `/register`
- **Class:** `RegScreen`
- **File:** `lib/main.dart` (TODO: extract to `lib/screens/auth/register_screen.dart`)
- **Fields:** username (`_un`), email (`_em`), display name (`_dn`), password (`_pw`)
- **Buttons:**

| EN | AR | Action | API/Route |
|----|----|--------|-----------|
| Create account | إنشاء حساب | Submit | `POST /auth/register` then auto-login |
| Already have account? | لديك حساب؟ | Navigate | → `/login` |
| I accept Terms | أوافق على الشروط | Required checkbox | Sets `accepted=true` flag |

### A3. Forgot Password Screen
- **Path:** `/forgot-password`
- **Class:** `ForgotPasswordScreen`
- **File:** `lib/screens/auth/forgot_password_flow.dart`
- **Buttons:**

| EN | AR | Action | API/Route |
|----|----|--------|-----------|
| Send reset link | إرسال رابط إعادة التعيين | Submit | `POST /auth/forgot-password` |
| Back to login | عودة لتسجيل الدخول | Navigate | → `/login` |

---

## B. Onboarding & Setup / الإعداد والتهيئة

### B1. Onboarding Wizard / معالج الإعداد
- **Path:** `/onboarding/wizard`
- **Class:** `OnboardingWizardScreen`
- **File:** `lib/screens/onboarding/onboarding_wizard_screen.dart`
- **6 steps with persistent draft (`POST /onboarding/draft`).**

**Step buttons (each step):**

| EN | AR | Action |
|----|----|--------|
| Next | التالي | Save step + advance |
| Back | السابق | Go back |
| Save & exit | حفظ ومتابعة لاحقاً | Save draft + navigate to `/app` |
| Skip (where allowed) | تخطي | Mark step skipped |

**Final step (Confirm):**

| EN | AR | Action | API |
|----|----|--------|-----|
| Create company | إنشاء الشركة | Submit | `POST /clients` |
| Use demo data | استخدام بيانات تجريبية | Seed sample | `POST /api/v1/ai/onboarding/seed-demo` |

### B2. Entity Setup Screen / إعداد الكيان
- **Path:** `/settings/entities`
- **Class:** `EntitySetupScreen`
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + New company | + شركة جديدة | Open new company form | (modal) → `POST /clients` |
| Edit | تعديل | Edit selected | `PUT /clients/{id}` |
| Switch active entity | تبديل الكيان النشط | Set `S.entityId` | (local) |
| Archive | أرشفة | Archive entity | `POST /archive/upload` |
| Upload COA | رفع دليل الحسابات | Navigate | → `/coa/upload` |

---

## C. Launchpad & Service Hubs / لوحة الإطلاق ومراكز الخدمات

### C1. V5 Launchpad / لوحة الإطلاق V5
- **Path:** `/app`
- **Class:** `V5Launchpad` / `ApexLaunchpadScreen`
- **File:** `lib/screens/home/apex_launchpad_screen.dart`
- **Sections:**
  1. **Copilot hero card** — "What do you want to do today?" + chat input
  2. **Service tiles** (10): Sales, Purchase, Accounting, Operations, Compliance, Audit, Analytics, HR, Workflow, Settings
  3. **Recent activity** — last 5 actions
  4. **Today's tasks** — period-close tasks if active
  5. **News ticker** — `apex_news_ticker.dart`
  6. **Notifications bell** (top-right)
- **Buttons (top bar):**

| EN | AR | Action |
|----|----|--------|
| 🔔 Bell | الإشعارات | Open `/notifications/panel` |
| 👤 Avatar | الحساب | Menu: Profile, Settings, Logout |
| 🔍 Search | بحث | Cmd/Ctrl-K → showcase / search |
| 🌐 Language | اللغة | Toggle ar/en |
| 🌓 Theme | السمة | Cycle 12 themes |

**Service tile click:** → `/app/{service}` or direct hub path.

### C2. Service Hub Pattern / نمط مركز الخدمة
- **Path pattern:** `/sales`, `/purchase`, `/accounting`, etc.
- **Class:** `ApexServiceHubScreen(serviceId)`
- **Buttons (header):**

| EN | AR | Action |
|----|----|--------|
| ← Back | عودة | Pop |
| Apps | التطبيقات | Open `/app/{service}/apps` (Odoo-style grid) |
| KPI cards | بطاقات الأداء | Click to drill-down |

**Each tile in hub:** click → corresponding screen (see navigation map).

---

## D. Sales Service / خدمة المبيعات

### D1. Customers List / قائمة العملاء
- **Path:** `/sales/customers`
- **Class:** `CustomersListScreen`
- **Columns:** Name, VAT #, Email, Balance, Last Activity
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + New customer | + عميل جديد | Open modal | `POST /api/v1/pilot/customers` |
| Filter | تصفية | Show filter drawer | (local) |
| Export CSV | تصدير CSV | Download | (local) |
| Sync from accounting | مزامنة | Pull from GL | `GET /api/v1/pilot/entities/{id}/customers` |
| Click row | — | Navigate | → `/operations/customer-360/{id}` |

### D2. Invoices List / قائمة الفواتير
- **Path:** `/sales/invoices`
- **Class:** `InvoicesListScreen`
- **Columns:** Invoice #, Customer, Date, Total, VAT, Status, ZATCA
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + New invoice | + فاتورة جديدة | Open builder | `POST /api/v1/pilot/sales-invoices` |
| Issue | إصدار | Mark as issued | `POST /.../issue` |
| Submit to ZATCA | إرسال لـ ZATCA | Build + clear | `POST /zatca/invoice/build` |
| Record payment | تسجيل دفعة | Navigate | → `/sales/payment/{id}` |
| Cancel | إلغاء | Set cancelled | `POST /.../cancel` |
| Print PDF | طباعة | Generate PDF | (local) |
| Download XML | تنزيل XML | Download UBL XML | (local) |
| Filter by status | تصفية حسب الحالة | Filter | (local) |

### D3. AR Aging / تقادم الذمم
- **Path:** `/sales/aging`
- **Class:** `ArAgingScreen`
- **Columns:** Customer, Current, 1-30, 31-60, 61-90, 91+, Total
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| Refresh | تحديث | Recompute | `POST /aging/report` |
| Export | تصدير | Download | (local) |
| Send reminder | إرسال تذكير | Email customer | `POST /notifications/...` |
| Click customer | — | Drill-down | → `/operations/customer-360/{id}` |

### D4. Recurring Invoices / الفواتير المتكررة
- **Path:** `/sales/recurring`
- **Buttons:** + New recurring (frequency: weekly/monthly/quarterly), Pause, Resume, Edit, Delete.

### D5. Customer Payment / دفعة عميل
- **Path:** `/sales/payment/:invoiceId`
- **Class:** `CustomerPaymentScreen`
- **Fields:** Amount, Method (cash/bank/card), Bank account, Reference
- **Buttons:** Save (`POST /api/v1/pilot/customer-payments`), Cancel, Print receipt.

---

## E. Purchase Service / خدمة المشتريات

(Similar structure to Sales, mirrored for vendors/bills.)

### E1. Vendors List / قائمة الموردين
- **Path:** `/purchase/vendors`
- **Buttons:** + New vendor, Filter, Click → `/operations/vendor-360/{id}`.

### E2. Bills List / قائمة فواتير الشراء
- **Path:** `/purchase/bills`
- **Buttons:** + New bill, Receive (link to PO receipt), Pay (→ `/purchase/payment/{id}`), Match-3-way (PO/receipt/bill).

### E3. AP Aging / تقادم الذمم الدائنة
- **Path:** `/purchase/aging`
- **Buttons:** Refresh, Export, Schedule payment.

---

## F. Accounting Service / خدمة المحاسبة

### F1. Journal Entries List / قائمة قيود اليومية
- **Path:** `/accounting/je-list`
- **Class:** `JeListScreen`
- **Columns:** Date, Reference, Description, Total Debit, Total Credit, Status (Draft/Posted)
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + New JE | + قيد جديد | Navigate | → `/compliance/journal-entry-builder` |
| Click row | — | View detail | → `/compliance/journal-entry/{id}` |
| Post | ترحيل | Post draft | `POST /api/v1/pilot/journal-entries/{id}/post` |
| Reverse | عكس | Reversal entry | (local) |

### F2. Journal Entry Builder / منشئ القيد
- **Path:** `/compliance/journal-entry-builder`
- **Class:** `JournalEntryBuilderScreen`
- **Fields:** Date, Memo, Lines (Account, Debit, Credit, Description) — must balance!
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + Add line | + إضافة سطر | Add row | (local) |
| Save Draft | حفظ مسودة | Save | `POST /je/build` |
| Post | ترحيل | Save + post | `POST /api/v1/pilot/journal-entries` |
| AI Suggest | اقتراح بالذكاء | Anthropic suggests entry from description | `POST /copilot/...` |
| Cancel | إلغاء | Discard | (local) |

### F3. COA Tree v2 / شجرة الدليل v2
- **Path:** `/accounting/coa-v2`
- **Class:** `CoaTreeV2Screen`
- **Display:** Hierarchical tree of accounts with balances
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + New account | + حساب جديد | Open editor | → `/accounting/coa/edit` |
| Edit | تعديل | Open editor | → `/accounting/coa/edit?id=...` |
| Expand all | توسيع الكل | Expand tree | (local) |
| Export | تصدير | Download as Excel | (local) |
| Re-classify with AI | إعادة تصنيف بالذكاء | AI re-categorize | `POST /coa/classify/{uploadId}` |

### F4. Bank Reconciliation v2 / مطابقة البنك v2
- **Path:** `/accounting/bank-rec-v2`
- **Class:** `BankRecV2Screen`
- **Buttons:** Upload statement, Auto-match, Manual match, Mark cleared, Add JE for unmatched, Approve.

---

## G. Operations / العمليات

### G1. Customer 360 / عرض العميل الشامل
- **Path:** `/operations/customer-360/:id`
- **Class:** `Customer360Screen`
- **Sections:** Profile, Open invoices, Payment history, Aging, Notes, Documents, Activity timeline
- **Buttons:** Edit profile, Email, Call (deep link), New invoice, Statement of account, Archive.

### G2. Vendor 360 / عرض المورد الشامل
- **Path:** `/operations/vendor-360/:id` — similar structure for vendors.

### G3. Universal Journal / دفتر الأستاذ العام
- **Path:** `/operations/universal-journal`
- **Class:** `UniversalJournalScreen` — SAP-style document flow viewer.
- **Buttons:** Filter by source type, Document flow drill-down, Click line → source document.

### G4. Period Close / إقفال الفترة
- **Path:** `/operations/period-close`
- **Class:** `PeriodCloseScreen`
- **Sections:** Active period, Task checklist, Blockers, Sign-off requirements
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| Start period close | بدء إقفال الفترة | Initialize tasks | `POST /api/v1/ai/period-close/start` |
| Mark task done | إنهاء المهمة | Complete task | `POST /api/v1/ai/period-close/tasks/{id}/complete` |
| Reopen task | إعادة فتح المهمة | Revert | (local) |
| Lock period | قفل الفترة | Lock GL | (final POST) |
| Generate FS | إصدار القوائم | Navigate | → `/compliance/financial-statements` |

### G5. POS Sessions / جلسات نقطة البيع
- **Path:** `/operations/pos-sessions`
- **Buttons:** Open session, Close session (Z-Report), View tickets.

### G6. POS Quick Sale / بيع سريع
- **Path:** `/operations/pos-quick-sale`
- **Buttons:** Add item, Discount, Apply VAT, Tender (cash/card/transfer), Print receipt.

### G7. Receipt Capture / التقاط الإيصالات
- **Path:** `/operations/receipt-capture`
- **Buttons:** Take photo, Upload file, OCR extract (TODO: real OCR endpoint), Save as expense.

### G8. Inventory v2 / المخزون v2
- **Path:** `/operations/inventory-v2`
- **Buttons:** + Item, Adjust quantity, Transfer between locations, Stock take, Valuation method.

### G9. Fixed Assets v2 / الأصول الثابتة v2
- **Path:** `/operations/fixed-assets-v2`
- **Buttons:** + Asset, Depreciate (manual run), Dispose, Print register, Compute schedule.

### G10. Purchase Cycle / دورة الشراء
- **Path:** `/operations/purchase-cycle`
- **Steps:** PR → PO → Receipt → Bill → Payment.
- **Buttons:** Create PR, Approve, Convert to PO, Receive goods, Match invoice.

---

## H. Compliance / الامتثال

### H1. ZATCA Invoice Builder / منشئ فاتورة ZATCA
- **Path:** `/compliance/zatca-invoice`
- **Class:** `ZatcaInvoiceBuilderScreen`
- **Fields:** Seller (auto from entity), Buyer (CR, VAT, name, address), Lines (item, qty, price, VAT 15%), Currency, Invoice type (standard/simplified)
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| Build & Clear | بناء وإصدار | Build UBL + send to ZATCA | `POST /zatca/invoice/build` |
| Print PDF | طباعة | Generate A4 with QR | (local) |
| Save Draft | حفظ مسودة | Save without sending | (local) |
| Validate | تحقق | Validate fields | (local) |
| Cancel | إلغاء | Discard | (local) |

### H2. ZATCA Status Center / مركز حالة ZATCA
- **Path:** `/compliance/zatca-status`
- **Class:** `ZatcaStatusCenterScreen`
- **Sections:** Devices (CSID/PCSID), Queue, Failed items, Compliance score
- **Buttons:** Onboard new device (OTP flow), Retry failed, View queue detail, Renew CSID.

### H3. Zakat Calculator / حاسبة الزكاة
- **Path:** `/compliance/zakat`
- **Buttons:** Compute (`POST /tax/zakat/compute`), Export, File to ZATCA, Save draft.

### H4. VAT Return / إقرار ضريبة القيمة المضافة
- **Path:** `/compliance/vat-return`
- **Buttons:** Compute return (`POST /tax/vat/return`), Submit, Print, Schedule.

### H5. Financial Ratios / النسب المالية
- **Path:** `/compliance/ratios`
- **Class:** `FinancialRatiosScreen`
- **Buttons:** Compute (`POST /ratios/compute`), Period selector, Compare periods, Export.

### H6. Depreciation / الاستهلاك
- **Path:** `/compliance/depreciation`
- **Buttons:** Compute (`POST /depreciation/compute`), Method (SLM/DDB/Units), Export.

### H7. Cash Flow / التدفق النقدي
- **Path:** `/compliance/cashflow` and `/compliance/cashflow-statement`
- **Buttons:** Compute, Direct/Indirect method, Period, Export.

### H8. Amortization / الإطفاء
- **Path:** `/compliance/amortization`
- **Buttons:** Add asset, Compute schedule, Print.

### H9. Lease v2 (IFRS-16) / الإيجار v2
- **Path:** `/compliance/lease-v2`
- **Buttons:** + New lease, ROU asset compute, Liability schedule, Print.

### H10. Financial Statements / القوائم المالية
- **Path:** `/compliance/financial-statements`
- **Class:** `FinStatementsScreen`
- **Tabs:** Income Statement | Balance Sheet | Cash Flow | Trial Balance | Equity Changes
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| Period | الفترة | Date range picker | (local) |
| Refresh | تحديث | Recompute | `GET /api/v1/pilot/entities/{id}/income-statement` etc. |
| Compare | مقارنة | Add prior period | (local) |
| Export PDF | تصدير PDF | Download | (local) |
| Export Excel | تصدير Excel | Download | (local) |
| Sign-off | اعتماد | Submit for approval | `POST /workflow/...` |
| Lock | قفل | Lock period | (local) |

### H11. Executive Dashboard / لوحة تنفيذية
- **Path:** `/compliance/executive`
- **Class:** `ExecutiveDashboardScreen`
- **Widgets:** Revenue, COGS, GP%, OpEx, Net Income, Cash on hand, AR/AP days, Top customers, Key alerts.
- **Buttons:** Refresh, Drill-down, Period selector, Export to slides.

### H12. IFRS Tools / أدوات IFRS
- **Path:** `/compliance/ifrs-tools`
- **Buttons:** Lease (IFRS-16), Revenue (IFRS-15), Impairment (IAS-36), Foreign currency (IAS-21).

### H13. Audit Trail / سجل التدقيق
- **Path:** `/compliance/audit-trail`
- **Buttons:** Filter (date/user/action), Export, Drill into event, View hash chain.

### H14. KYC / AML / اعرف عميلك
- **Path:** `/compliance/kyc-aml`
- **Buttons:** Run KYC check, Sanctions screening, PEP check, Save report.

(Other compliance screens: depreciation, breakeven, investment, working-capital, dscr, valuation, fx-converter, deferred-tax, transfer-pricing, payroll, islamic-finance — all follow Compute → Render → Export pattern.)

---

## I. Audit Service / خدمة المراجعة

### I1. Engagement Workspace / مساحة عمل المهمة
- **Path:** `/audit/engagements` (and aliases `/audit/engagement-workspace`, `/audit/workpapers`, `/audit/sampling`, `/audit/benford`)
- **Class:** `AuditEngagementWorkspaceScreen`
- **Sections:** Engagement header (client, year, scope), Tabs (Planning | Fieldwork | Review | Findings | Reporting)
- **Buttons:**

| EN | AR | Action | API |
|----|----|--------|-----|
| + New engagement | + مهمة جديدة | Create | `POST /audit/cases` |
| Switch engagement | تبديل المهمة | List | `GET /audit/cases` |
| Start fieldwork | بدء العمل الميداني | Mark phase | (local) |
| + Sample | + عينة | Sampling tool | `POST /audit/cases/{id}/samples` |
| + Workpaper | + ورقة عمل | New WP | `POST /audit/cases/{id}/workpapers` |
| Submit for review | تقديم للمراجعة | Sign off | `POST /audit/workpapers/{id}/review` |
| Run Benford | تشغيل بنفورد | AI analysis | `POST /ai/benford/analyze` |
| + Finding | + ملاحظة | Add finding | `POST /audit/cases/{id}/findings` |
| Generate report | إصدار التقرير | Compose audit report | (local + template `GET /audit/templates`) |
| Archive engagement | أرشفة المهمة | Archive | `POST /archive/upload` |

### I2. Anomaly Detail / تفاصيل الشذوذ
- **Path:** `/audit/anomaly/:id`
- **Buttons:** Investigate, Mark cleared, Escalate, Add to workpaper.

### I3. AI Audit Workflow / تدفق المراجعة بالذكاء
- **Path:** `/compliance/audit-workflow-ai`
- **Buttons:** Run AI assessment, Review suggestions, Accept/reject each.

---

## J. Analytics / التحليلات

### J1. Budget Variance v2 / انحراف الموازنة v2
- **Path:** `/analytics/budget-variance-v2`
- **Buttons:** Period, Compute (`POST /budget/variance`), Drill-down by GL, Export.

### J2. Cash Flow Forecast / توقع التدفق النقدي
- **Path:** `/analytics/cash-flow-forecast`
- **Buttons:** Period (3/6/12 mo), Recompute, Scenario (best/expected/worst), Export.

### J3. Health Score v2 / نقاط الصحة المالية v2
- **Path:** `/analytics/health-score-v2`
- **Buttons:** Compute (`POST /health-score/compute`), Drill into each KPI, Compare benchmark.

### J4. Multi-Currency v2 / متعدد العملات v2
- **Path:** `/analytics/multi-currency-v2`
- **Buttons:** Currency picker, Revaluation, FX gain/loss compute.

### J5. Investment Portfolio v2 / المحفظة الاستثمارية v2
- **Path:** `/analytics/investment-portfolio-v2`
- **Buttons:** + Investment, Compute returns, Allocation chart.

### J6. Cost Variance v2 / انحراف التكلفة v2
- **Path:** `/analytics/cost-variance-v2`
- **Buttons:** Standard vs actual, Drill by cost center.

### J7. Project Profitability / ربحية المشروع
- **Path:** `/analytics/project-profitability`
- **Buttons:** + Project, Allocate revenue/cost, Margin report.

### J8. Budget Builder / منشئ الموازنة
- **Path:** `/analytics/budget-builder`
- **Buttons:** Copy from prior year, Adjust by %, Save scenario, Lock budget.

---

## K. HR / الموارد البشرية

### K1. Employees List / قائمة الموظفين
- **Path:** `/hr/employees`
- **Buttons:** + Employee (`POST /api/v1/employees`), Click row → profile, GOSI calc, EOSB calc.

### K2. Payroll Run / تشغيل الرواتب
- **Path:** `/hr/payroll-run`
- **Buttons:** Create cycle, Compute (`POST /payroll/compute`), Review, Approve, Process payments, Export WPS file.

### K3. Timesheet / الجدول الزمني
- **Path:** `/hr/timesheet`
- **Buttons:** Submit hours, Approve, Reject, Period summary.

### K4. Expense Reports / تقارير المصروفات
- **Path:** `/hr/expense-reports`
- **Buttons:** + Report, Add line, Attach receipt, Submit, Approve, Reimburse.

---

## L. Account & Settings / الحساب والإعدادات

### L1. Profile Edit / تعديل الملف الشخصي
- **Path:** `/profile/edit`
- **Buttons:** Save (`PUT /users/me/profile`), Upload avatar, Cancel.

### L2. Change Password / تغيير كلمة المرور
- **Path:** `/password/change`
- **Buttons:** Update (`PUT /users/me/security/password`), Cancel.

### L3. Sessions / الجلسات النشطة
- **Path:** `/account/sessions`
- **Buttons:** Revoke session, Revoke all (`POST /auth/logout-all`).

### L4. MFA / المصادقة الثنائية
- **Path:** `/account/mfa`
- **Buttons:** Enable TOTP (`POST /auth/totp/setup`), Verify code (`POST /auth/totp/verify`), Disable (`POST /auth/totp/disable`).

### L5. Subscription / الاشتراك
- **Path:** `/subscription`
- **Buttons:** View current (`GET /subscriptions/me`), Upgrade (→ `/upgrade-plan`), Compare (→ `/plans/compare`), Cancel.

### L6. Plan Comparison / مقارنة الخطط
- **Path:** `/plans/compare`
- **Buttons:** Choose plan → upgrade flow.

### L7. Upgrade Plan / ترقية الخطة
- **Path:** `/upgrade-plan`
- **Buttons:** Pay with card (Stripe Checkout), Pay with bank transfer (mock), Confirm.

### L8. Notifications Center / مركز الإشعارات
- **Path:** `/notifications`
- **Buttons:** Mark all read, Filter (type), Click to view detail.

### L9. Notification Preferences / تفضيلات الإشعارات
- **Path:** `/notifications/prefs`
- **Buttons:** Toggle in-app/email/SMS per notification type, Save.

### L10. Legal Documents / الوثائق القانونية
- **Path:** `/legal`
- **Buttons:** Read each, Accept (`POST /legal/accept`), Accept all (`POST /legal/accept-all`).

### L11. Account Closure / إغلاق الحساب
- **Path:** `/account/close`
- **Buttons:** Submit closure (`POST /account/closure`), Cancel request, Reactivate (within grace period).

### L12. Unified Settings / الإعدادات الموحدة
- **Path:** `/settings/unified`
- **Sections:** Company, Tax, Bank feeds, Theme, Language, Integrations, Notifications, MFA.

### L13. Bank Feed Setup / إعداد التغذية البنكية
- **Path:** `/settings/bank-feeds`
- **Buttons:** Connect bank (Plaid/Lean equivalent), Map accounts, Set sync frequency.

### L14. Theme Generator / مولد السمات
- **Path:** `/theme-generator`
- **Buttons:** Pick palette, Preview, Save as theme, Apply.

### L15. White Label / العلامة المخصصة
- **Path:** `/white-label`
- **Buttons:** Upload logo, Set brand colors, Custom domain config (Enterprise only).

---

## M. Admin Area / منطقة الإدارة

### M1. Policy Management / إدارة السياسات
- **Path:** `/admin/policies`
- **Buttons:** + New version (terms/privacy/AUP), Activate, View acceptance logs.

### M2. Audit Log Viewer / عارض سجل التدقيق
- **Path:** `/admin/audit`
- **Buttons:** Filter, Export CSV, Drill, Verify hash chain.

### M3. Audit Chain Viewer / عارض سلسلة التدقيق
- **Path:** `/admin/audit-chain`
- **Buttons:** Verify (`GET /compliance/audit/verify`), Export proof.

### M4. AI Suggestions Inbox / صندوق اقتراحات الذكاء
- **Path:** `/admin/ai-suggestions` and `/admin/ai-suggestions-v2`
- **Buttons:** Approve, Reject, Promote to rule (`POST /knowledge-feedback/{id}/promote-rule`).

### M5. AI Console / لوحة الذكاء
- **Path:** `/admin/ai-console`
- **Buttons:** View metrics, Token usage, Errors, Model selector.

### M6. Provider Verification / التحقق من المقدم
- **Path:** `/admin/providers/verify`
- **Buttons:** Approve (`POST /service-providers/{id}/approve`), Reject (`POST /.../reject`), Request more docs.

### M7. Provider Compliance / امتثال المقدم
- **Path:** `/admin/providers/compliance`
- **Buttons:** Run compliance check, Suspend, Lift suspension.

### M8. Reviewer Console / لوحة المراجع
- **Path:** `/admin/reviewer`
- **Buttons:** Review feedback, Promote rule, Reject.

---

## N. Knowledge Brain / دماغ المعرفة

### N1. Knowledge Brain / دماغ المعرفة
- **Path:** `/knowledge/brain`
- **Buttons:** Search concept graph, Add concept, Add rule, Run inference.

### N2. Knowledge Search v2 / بحث المعرفة v2
- **Path:** `/knowledge/search`
- **Buttons:** Search (`GET /knowledge/...`), Filter, Save query.

### N3. Knowledge Feedback / ملاحظات على المعرفة
- **Path:** `/knowledge/feedback`
- **Buttons:** Submit feedback (`POST /knowledge-feedback`), Attach context.

### N4. Knowledge Developer Console / وحدة تحكم المطور
- **Path:** `/knowledge/console`
- **Buttons:** Concept editor, Rule editor, Test rule, Export rule pack.

---

## O. Marketplace / السوق

### O1. Service Catalog / قائمة الخدمات
- **Path:** `/service-catalog`
- **Buttons:** Filter category, Click service → detail.

### O2. New Service Request / طلب خدمة جديد
- **Path:** `/marketplace/new-request`
- **Fields:** Title, Description, Budget
- **Buttons:** Submit (`POST /marketplace/requests`), Cancel.

### O3. Service Request Detail / تفاصيل طلب الخدمة
- **Path:** `/service-request/detail`
- **Buttons:** Accept (provider), Send message, Mark milestone, Rate (client).

### O4. Provider Kanban / لوحة المقدم
- **Path:** `/provider-kanban`
- **Buttons:** Drag card between columns (Pending/Active/Done), Click for detail.

---

## P. Copilot & Misc / المساعد والمتنوعات

### P1. Copilot Screen / شاشة المساعد
- **Path:** `/copilot`
- **Class:** `CopilotScreen`
- **Buttons:** Send message (`POST /copilot/chat`), New session (`POST /copilot/sessions`), Attach context (entity/period), Voice input (TODO).

### P2. Reports Hub / مركز التقارير
- **Path:** `/reports`
- **Buttons:** Pick category (Financial / Tax / Operational / Audit), Generate, Schedule, Email.

### P3. Today Dashboard / لوحة اليوم
- **Path:** `/today`
- **Widgets:** Today's tasks, Pending approvals, Cash position, KPI summary.
- **Buttons:** Click each widget → drill-down.

### P4. Showcase / معرض المكونات
- **Path:** `/showcase`
- **Trigger:** Cmd/Ctrl-K
- **Buttons:** Browse components, Copy code, Theme switcher.

---

## Q. Common UI Patterns / أنماط واجهة شائعة

### Q1. Top Bar (visible on all authenticated screens)
- Logo (left, click → `/app`)
- Breadcrumbs / current path
- Search (Cmd-K → `/showcase`)
- Notifications bell → `/notifications/panel`
- Avatar menu → Profile / Settings / Logout
- Theme toggle / Language toggle

### Q2. Bottom Navigation (mobile, auto-shown on most routes)
- Home (`/app`)
- Search
- + (FAB: New transaction)
- Inbox (notifications)
- Account

### Q3. Hybrid Sidebar (compliance routes)
- Auto-injected for `/compliance/*`
- Categorized menu (Tax / FS / Schedules / Audit / Tools)

### Q4. Copilot Ask Panel
- Floating button (bottom-right)
- Click → opens `apex_ask_panel.dart`
- Sends message → `POST /copilot/chat`

### Q5. Common Form Patterns
- All forms use `Form` widget with `GlobalKey<FormState>`
- Required fields marked with `*` (Arabic: `*` after label)
- Submit button shows loading spinner
- Errors shown via SnackBar (red bg, Arabic+English message)
- Success → SnackBar (green) + navigate or close

---

## R. Total Counts / الإجمالي

| Category | Screens |
|----------|---------|
| Auth | 4 |
| Onboarding/Setup | 3 |
| Launchpad/Hubs | 11 |
| Sales | 7 |
| Purchase | 4 |
| Accounting | 5 |
| Operations | 14 |
| Compliance | 38 |
| Audit | 6 |
| Analytics | 8 |
| HR | 4 |
| Account & Settings | 15 |
| Admin | 8 |
| Knowledge | 4 |
| Marketplace | 4 |
| Copilot/Misc | 6 |
| **Total unique screens** | **141** |

(Aliases and demo routes excluded.)

---

**Continue → `05_API_ENDPOINTS_MASTER.md`**
