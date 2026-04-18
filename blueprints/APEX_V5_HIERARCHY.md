# APEX V5 — التسلسل الهرمي الكامل

> **التاريخ:** 2026-04-18
> **المستوى:** 4 مستويات هرمية
> **الخدمات:** 5 · **الـ Main Modules:** 15 · **الـ Sub-Module Chips:** 70 · **الـ Screens:** ~280
>
> **رموز الحالة:**
> - ✅ موجود في الكود (أحد الفرعين)
> - 🟡 موجود جزئياً / backend فقط
> - ❌ فجوة — يُبنى لاحقاً

---

## المستويات

| Level | المسمى | UI Pattern |
|---|---|---|
| 0 | Service (الخدمة) | Service Switcher / 9-dots |
| 1 | Main Module | Sidebar icons (4-5 في كل service) |
| 2 | Sub-Module (Chip) | Horizontal chips — الأول دائماً Dashboard |
| 3 | Screen | Top Tabs (3-5 visible) |
| 4 | Action | More ▾ dropdown / sub-tabs |

---

# 1 · 💼 APEX ERP

> **الهدف:** العمليات اليومية لشركة — محاسبة، عمليات، خزينة، موظفين.
> **المستخدم:** محاسب، مدير عمليات، Controller

## 🏠 ERP Home
**Widgets:** Cash Position · AR/AP Aging · Headcount · Stock Alerts · Compliance Score · Recent Activity · Alerts Feed

## 📊 1.1 Finance

### Chip: [📊 لوحة المالية] (Dashboard)
**Widgets:**
- DSO (Days Sales Outstanding) — gauge
- Cash position — line chart 90 days
- AR Aging breakdown — stacked bar
- P&L snapshot (month vs. last month) — compact
- Recent JEs — list (5 items, click to drill)
- Top 5 customers by balance
- Overdue invoices count
- Budget utilization %

### Chip: GL (General Ledger)
**Visible Tabs:** CoA Tree ✅ · Journals ✅ · Trial Balance ✅ · Financial Statements ✅ · Period Close ❌
**More ▾:** Recurring JE · Reversing Entries · Adjusting Entries · Consolidation ✅ · Audit Trail ✅ · GL Settings · Templates · Import Entries

### Chip: AR (Accounts Receivable)
**Visible Tabs:** Customers ✅ · Invoices ❌ · Payments ❌ · Statements ❌ · Quotes ❌
**More ▾:** Credit Notes · Recurring Invoices · Price Lists · Aging Report ✅ · Sales Orders · Import Customers · AR Settings

### Chip: AP (Accounts Payable)
**Visible Tabs:** Vendors ❌ · Purchase Orders ❌ · Bills ❌ · Payments ❌ · Goods Receipts ❌
**More ▾:** RFQs · Expense Claims · Vendor Scorecards · Aging AP · Batch Payment Run · 3-Way Match 🟡 (sprint41) · AP Settings

### Chip: Budgets
**Visible Tabs:** Budget Entry ❌ · Variance ✅ · Forecast ❌ · Rolling Budget ❌ · Scenarios ❌
**More ▾:** Templates · Import · Approval Workflow · Version History · Budget Settings

### Chip: Reports
**Visible Tabs:** Financial Statements ✅ · Operational ❌ · Custom Builder ❌ · Scheduled ❌ · Templates ❌
**More ▾:** Saved Views · Report History · Subscriptions · Export Center · Report Settings · IFRS Tools ✅ · Extras Tools ✅

### Chip: Consolidation
**Visible Tabs:** Entities ❌ · Elimination Rules ❌ · Consolidated P&L ❌ · Consolidated BS ❌ · Minority Interest ❌
**More ▾:** Intercompany 🟡 · FX Translation · Segment Reporting · Consolidation History · Settings

---

## 👥 1.2 HR & Payroll

### Chip: [👥 لوحة الموارد البشرية]
**Widgets:** Headcount · Monthly Payroll Total · Pending Leaves · GOSI Status · EOSB Liability · Upcoming Birthdays · Attrition Rate · Recent Hires

### Chip: Employees
**Visible Tabs:** Directory ❌ · New Hire ❌ · Org Chart ❌ · Contracts ❌ · Onboarding ❌
**More ▾:** Offboarding · Document Library · Performance Reviews · Training · Employee Settings

### Chip: Payroll
**Visible Tabs:** Current Run ✅ (payroll_screen) · Payslips ❌ · GOSI Submission 🟡 · WPS File 🟡 · History ❌
**More ▾:** Tax Tables · Overtime Rules · Loan Deductions · Bonus Runs · Payroll Settings

### Chip: Leaves
**Visible Tabs:** Requests ❌ · Calendar ❌ · Balances ❌ · Approvals ❌ · Policies ❌
**More ▾:** Holidays Calendar · Absence Report · Carry Forward Rules · Leave Settings

### Chip: Benefits
**Visible Tabs:** GOSI 🟡 · WPS/Mudad 🟡 · EOSB 🟡 · Medical Insurance ❌ · Allowances ❌
**More ▾:** Retirement Plans · Expense Reimbursements · Benefit Enrollment · Benefits Settings

---

## 📦 1.3 Operations

### Chip: [📦 لوحة العمليات]
**Widgets:** Stock Alerts · Open POs · Project Progress · Pipeline Value · Inventory Turnover · Overdue Deliveries · Manufacturing Output · Quality Issues

### Chip: Inventory
**Visible Tabs:** Items ✅ (inventory_screen) · Stock On-Hand ❌ · Stock Moves ❌ · Warehouses ❌ · Cycle Counts ❌
**More ▾:** Variants Matrix · Bills of Material 🟡 (sprint44) · Reorder Rules · Stock Valuation (FIFO/LIFO/WAC) ✅ · Serial/Lot Tracking · Inventory Settings

### Chip: Projects
**Visible Tabs:** Projects ❌ · Tasks ❌ · Timesheets ❌ · Gantt 🟡 (sprint44) · Billing ❌
**More ▾:** Budgets vs. Actual · Resource Allocation · Milestones · Deliverables · Project Settings

### Chip: CRM
**Visible Tabs:** Leads ❌ · Opportunities ❌ · Pipeline ✅ (kanban) · Activities ❌ · Contacts ❌
**More ▾:** Campaigns · Email Sync · Lead Scoring AI · Win/Loss Analysis · CRM Settings

### Chip: Manufacturing
**Visible Tabs:** Work Orders ✅ (sprint44) · BOM 🟡 · Routings ❌ · Production Schedule ❌ · Quality Control ❌
**More ▾:** Machine Loading · Operators · Downtime · Scrap Tracking · Manufacturing Settings

---

## 🏦 1.4 Treasury

### Chip: [🏦 لوحة الخزينة]
**Widgets:** Bank Balances Summary · Pending Reconciliations · 13-Week Cash Forecast · FX Exposure · Outstanding Receivables Impact · Next 7-Day Cash Need

### Chip: Banks
**Visible Tabs:** Accounts ✅ (bank_feeds) · Transactions ✅ · Statements ❌ · Transfers ❌ · Loans & Facilities ❌
**More ▾:** Investments · Bank Fees · Signatories · Account Settings · Connect New (Lean/Tarabut/Salt Edge) ✅

### Chip: Reconciliation
**Visible Tabs:** Manual Match ✅ (bank_rec) · **AI Suggestions ✅** (Wave 15-16) · Unmatched ❌ · History ❌ · Rules ❌
**More ▾:** Auto-Match Rules · Exception Queue · Reconciliation Reports · Rec Settings · Bulk Import

### Chip: Cash Flow
**Visible Tabs:** Statement (IAS 7) ✅ · Forecast ❌ · Historical ❌ · Scenarios ❌ · Categories ❌
**More ▾:** Direct Method · Indirect Method · Supplemental · Cash Flow Settings

### Chip: FX
**Visible Tabs:** Rates ✅ · Conversions ✅ (fx_converter) · Exposure ❌ · Hedges ❌ · History ❌
**More ▾:** Rate Sources · Revaluation · FX G/L Postings · FX Settings

---

# 2 · 🛡️ APEX Compliance & Tax

> **الهدف:** الامتثال التنظيمي، الضرائب، ZATCA، GOSI/WPS، AML.
> **المستخدم:** Compliance Officer، Tax Accountant، CFO

## 🏠 Compliance Home
**Widgets:** Compliance Score · Filing Calendar · Certificate Expiry · Recent Submissions · Alerts Feed

## 💰 2.1 Tax Filings

### Chip: [💰 لوحة الضرائب]
**Widgets:** Next Filing Deadlines · Refund Status · Total Liability Snapshot · Filing History (30 days) · Reminders · Tax Authority Alerts

### Chip: VAT
**Visible Tabs:** Return Builder ✅ (vat_return) · Input VAT ❌ · Output VAT ❌ · Submission ❌ · History ❌
**More ▾:** VAT Reconciliation · Adjustments · Refund Requests · VAT Settings

### Chip: WHT
**Visible Tabs:** Calculator ✅ (wht_screen) · Certificates ❌ · Monthly ❌ · Annual ❌ · History ❌
**More ▾:** Treaty Rates · Exemptions · Batch Processing · WHT Settings

### Chip: Zakat
**Visible Tabs:** Calculator ✅ · Adjustments ❌ · Submission ❌ · History ❌ · Rulings ❌
**More ▾:** Equity Method · Adjustments Library · Multi-Entity · Zakat Settings

### Chip: UAE CT
**Visible Tabs:** Calculator ✅ (uae_corp_tax) · Pillar Two ❌ · Small Business Relief ❌ · History ❌
**More ▾:** Transfer Pricing Link · Deferred Tax Link · CT Settings

### Chip: Transfer Pricing
**Visible Tabs:** Master File ❌ · Local File ❌ · CbCR ❌ · Benchmarking ❌ · Methods ❌
**Backend:** ✅ (transfer_pricing_service)
**More ▾:** Related Parties · Intercompany Agreements · Documentation Archive · TP Settings

---

## 📄 2.2 ZATCA E-Invoicing

### Chip: [📄 لوحة الفوترة]
**Widgets:** Cleared Today · Pending Clearance · Failed (Awaiting Retry) · CSID Days-to-Expiry · Sandbox/Production Status · Fatoora API Health

### Chip: Clearance
**Visible Tabs:** Invoice Builder ✅ · Validation ❌ · Submission ❌ · QR Generator ❌ · Status Log ❌
**More ▾:** Bulk Resubmit · Test Environment · Clearance Rules · Invoice Settings · PDF with TLV QR ✅ (e85afb1)

### Chip: CSID
**Visible Tabs:** Certificates ✅ · Issue New ❌ · Renew ❌ · Revoke ✅ · Expiring Soon ✅
**More ▾:** Sandbox CSIDs · Production CSIDs · Audit Trail · Sweep Expired ✅ · CSID Settings

### Chip: Queue & Retry
**Visible Tabs:** All ✅ · Pending ✅ · Cleared ✅ · Giveup ✅ · Draft ✅
**More ▾:** Retry Rules · Backoff Config (1m→5m→30m→2h→12h→24h→48h) ✅ · Worker Status · Queue Settings

### Chip: Error Log
**Visible Tabs:** Recent Errors ❌ · By Code 🟡 · Translations ✅ (14 BR-KSA codes) · Resolution Guide ❌ · History ❌
**More ▾:** Error Pattern Library · Escalation Rules · Error Settings

---

## ⚖️ 2.3 Regulatory

### Chip: [⚖️ لوحة التنظيم]
**Widgets:** Monthly Submissions Due · Roster Changes Alerts · Compliance Calendar · Certificate Health · Upcoming Audits · AML Case Load

### Chip: GOSI
**Visible Tabs:** Roster ❌ · Monthly Submission 🟡 · Contribution Rates ❌ · Variance ❌ · History ❌
**Backend:** ✅ (gosi_calculator)
**More ▾:** New Hire Flow · Termination Flow · Exemption Requests · GOSI Settings

### Chip: WPS
**Visible Tabs:** SIF Generator 🟡 · Submission ❌ · Mudad Sync ❌ · Rejections ❌ · History ❌
**Backend:** ✅ (wps_generator)
**More ▾:** Bank Mapping · Salary Components · WPS Settings

### Chip: AML
**Visible Tabs:** Screening ❌ · Cases ❌ · Monitoring Rules ❌ · SAR Filings ❌ · Watchlist ❌
**More ▾:** PEP Lists · Sanctions Lists · Structuring Alerts · KYC Library · AML Settings

### Chip: Governance
**Visible Tabs:** Board Pack ❌ · Meetings ❌ · Minutes ❌ · Resolutions ❌ · Policies ❌
**More ▾:** Committees · Conflicts Register · Voting Records · Governance Settings

---

# 3 · 🔍 APEX Audit

> **الهدف:** Workflow مراجعة خارجية على كتب العميل — Planning → Fieldwork → Reporting.
> **المستخدم:** External Auditor، Senior Auditor، Partner

## 🏠 Audit Home
**Widgets:** Active Engagements · Team Utilization · Risk Heatmap · Deadline Calendar · Recent Approvals

## 📋 3.1 Engagement

### Chip: [📋 لوحة الارتباط]
**Widgets:** Open Engagements · Stage Funnel · Team Utilization · Deadline Calendar · Risk Heatmap · Budget vs. Actual Hours

### Chip: Planning
**Visible Tabs:** Client Info ✅ (audit_workflow) · Scope ❌ · Materiality ❌ · Team & Budget ❌ · Timeline ❌
**More ▾:** Engagement Letter · Independence · Prior Year Carryforward · Planning Meeting · Planning Settings

### Chip: Acceptance
**Visible Tabs:** Questionnaire ❌ · Risk Screening ❌ · Conflict Check ❌ · Approval ❌ · Archive ❌
**More ▾:** Letter Templates · Fee Arrangement · AML Check · Acceptance Settings

### Chip: Kick-off
**Visible Tabs:** Meeting Agenda ❌ · Team Intro ❌ · Client Intro ❌ · Schedule ❌ · Deliverables ❌
**More ▾:** Kick-off Templates · Attendance · Minutes · Kick-off Settings

---

## 🔬 3.2 Fieldwork

### Chip: [🔬 لوحة الفحص]
**Widgets:** WP Completion % · Risk Findings · Test Progress · Days to Report · Open Review Notes · Partner Queue

### Chip: Workpapers
**Visible Tabs:** Index Tree ❌ · Lead Sheets ❌ · Trial Balance ✅ · Tick Marks ❌ · References ❌
**More ▾:** Import TB · Evidence Library · Analytics · Roll-Forward · WP Settings · Audit Trail ✅

### Chip: Risk Assessment
**Visible Tabs:** Risk Register ❌ · Assertions ❌ · Controls ❌ · RoMM Matrix ❌ · Fraud Risks ❌
**More ▾:** ITGC Assessment · Process Narratives · Walkthroughs · Risk Linkage · Risk Settings · Anomaly Feed ✅

### Chip: Control Testing
**Visible Tabs:** Test Plans ❌ · Samples ❌ · Results ❌ · Exceptions ❌ · Conclusion ❌
**More ▾:** Sample Size Calc · Random Selection · MUS · Deficiency Log · Test Settings

---

## 📑 3.3 Reporting

### Chip: [📑 لوحة التقارير]
**Widgets:** Draft Status · Review Notes Count · Signoff Queue · Partners Pending · Issuance Calendar

### Chip: Opinion Builder
**Visible Tabs:** Opinion Type ❌ · Basis ❌ · Emphasis ❌ · KAMs ❌ · Other Matter ❌
**More ▾:** Going Concern · Qualification Templates · Peer Review · Opinion Settings

### Chip: Management Letter
**Visible Tabs:** Findings ❌ · Recommendations ❌ · Management Response ❌ · Status ❌ · Follow-up ❌
**More ▾:** Templates · Tone Rules · Distribution · ML Settings

### Chip: QC
**Visible Tabs:** Review Notes ❌ · Assignments ❌ · Signoff ❌ · EQCR ❌ · Archive ❌
**More ▾:** Consultation Log · Monitoring File · Independence Declarations · QC Settings

---

# 4 · 📊 APEX Advisory

> **الهدف:** تحليل مالي + دراسات جدوى + تقييمات — مشاريع استشارية.
> **المستخدم:** Financial Analyst، Advisor، Valuation Specialist

## 🏠 Advisory Home
**Widgets:** Active Projects · Pipeline Value · Team Load · Alerts · Archive Access

## 📈 4.1 Feasibility Studies

### Chip: [📈 لوحة الجدوى]
**Widgets:** Active Projects · Stage Funnel · Decision Outcomes · Team Load · Archive Access · Peer NPV Distribution

### Chip: Market Analysis
**Visible Tabs:** TAM/SAM/SOM ❌ · Competitors ❌ · Demand Model ❌ · Pricing ❌ · Sources ❌
**More ▾:** Survey Results · PESTEL · Porter Five Forces · Market Settings

### Chip: Pro-Forma
**Visible Tabs:** P&L ❌ · Balance Sheet ❌ · Cash Flow ❌ · Funding Plan ❌ · Covenants ❌
**Backend:** ✅ (investment_service NPV/IRR)
**More ▾:** Ratios · Sources & Uses · Working Capital Detail · Projection Settings

### Chip: Valuation
**Visible Tabs:** NPV / IRR ✅ · Payback ❌ · DSCR / LLCR ✅ · WACC ✅ (valuation) · Summary ❌
**More ▾:** Unlevered vs. Levered · Residual Value · Real Options · Valuation Settings · Financial Simulation ✅

### Chip: Sensitivity
**Visible Tabs:** 1-Way Sensitivity ❌ · 2-Way Grid ❌ · Monte Carlo ❌ · Scenarios ❌ · Tornado ❌
**More ▾:** Risk Register · Mitigation Plan · Stress Tests · Simulation Settings

---

## 🔍 4.2 External Analysis

### Chip: [🔍 لوحة التحليل]
**Widgets:** Projects Under Analysis · Ratios vs. Peers · Credit Score Distribution · Alerts · Recent Uploads

### Chip: Upload & OCR
**Visible Tabs:** File Drop ✅ (ocr) · Parse & OCR ✅ · Mapping ❌ · Validation ❌ · History ❌
**More ▾:** Template Library · Multi-Period Bulk · Mapping Presets · Upload Settings

### Chip: Ratios
**Visible Tabs:** Liquidity ✅ (ratios) · Leverage ✅ · Profitability ✅ · Activity ✅ · Market ✅
**Backend:** ✅ 18 ratios
**More ▾:** Custom Ratios · Trend Analysis · DuPont · Formula Transparency · Working Capital ✅ · Ratio Settings

### Chip: Benchmarking
**Visible Tabs:** Sector ❌ · Peer Set ❌ · Quartile Chart ❌ · Radar ❌ · Time Series ❌
**More ▾:** Data Sources · Custom Peers · Regional Filters · Benchmark Settings

### Chip: Credit
**Visible Tabs:** Credit Score ❌ · Risk Rating ❌ · Covenants ❌ · Cash Flow Coverage ❌ · Early Warning ❌
**Backend:** 🟡 (DSCR موجود)
**More ▾:** Z-Score / Altman · Rating Migration · Stress Scenarios · Credit Settings

---

## 🧮 4.3 Financial Tools

### Chip: [🧮 لوحة الأدوات]
**Widgets:** Asset Register Total · Depreciation This Period · Lease Liabilities · Upcoming Disposals · Recent Calculations

### Chip: Fixed Assets
**Visible Tabs:** Register ✅ · Add Asset ❌ · Depreciation Schedule ✅ · Disposal ❌ · Impairment ✅
**More ▾:** Revaluation · Parent-Child Assets · Insurance · FA Settings

### Chip: Depreciation
**Visible Tabs:** Calculator ✅ · SL Method ✅ · DDB Method ✅ · SYD Method ✅ · Schedule ✅
**More ▾:** Component Depreciation · Bulk Calculate · History · Depreciation Settings

### Chip: Lease (IFRS 16)
**Visible Tabs:** ROU Asset ✅ · Lease Liability ✅ · Amortization ✅ · Modifications ❌ · Journal Entries ❌
**More ▾:** Short-Term · Low-Value · Variable Lease Payments · Lease Settings

### Chip: Break-even
**Visible Tabs:** Single Product ✅ · Multi-Product ❌ · Margin of Safety ❌ · Sensitivity ❌ · Chart ✅
**More ▾:** Operating Leverage · DOL · Fixed/Variable Split · Break-even Settings

---

# 5 · 🤝 APEX Marketplace

> **الهدف:** سوق ذو وجهين — عملاء يطلبون خدمات، مزوّدون يقدّموها.
> **المستخدم:** Client (شركة تحتاج خدمة) أو Provider (مكتب خدمات)

## 🏠 Marketplace Home
**Widgets:** حسب الـ role (Client أو Provider). يتبدل تلقائياً بناءً على user_type في JWT.

## 👤 5.1 Client Side

### Chip: [👤 لوحة العميل]
**Widgets:** Active Requests · Pending Quotes · Spent YTD · Top Providers · Expiring Contracts · Service Recommendations

### Chip: Browse Providers
**Visible Tabs:** Browse ✅ (service_catalog) · Saved Searches ❌ · Compare ❌ · Map View ❌ · Recently Viewed ❌
**More ▾:** Featured · Top Rated · Verified Only · Near Me · Filter Presets

### Chip: My Requests
**Visible Tabs:** Active ✅ (service_request_detail) · Quoted ❌ · Awarded ❌ · Completed ❌ · Disputed ❌
**More ▾:** Templates · Cloning · Request Settings

### Chip: Billing & Escrow
**Visible Tabs:** Invoices ❌ · Escrow ❌ · Payouts ❌ · Disputes ❌ · Statements ❌
**More ▾:** Tax Certificates · Currency Conversion · Fee Breakdown · Billing Settings

---

## 🏢 5.2 Provider Side

### Chip: [🏢 لوحة المزوّد]
**Widgets:** Earnings (MTD/YTD) · Active Jobs · Rating Average · Pipeline · Upcoming Deadlines · Profile Health Score

### Chip: My Profile
**Visible Tabs:** Overview ✅ (provider_profile) · Services Offered ❌ · Portfolio ❌ · Credentials ❌ · Reviews ❌
**More ▾:** Pricing Rules · Availability · Provider Settings

### Chip: Active Jobs
**Visible Tabs:** Kanban ✅ (provider_kanban) · List ❌ · Timeline ❌ · Files ❌ · Chat ❌
**More ▾:** Time Tracking · Approvals · Version History · Task Settings

### Chip: Payouts
**Visible Tabs:** Pending ❌ · History ❌ · Tax Docs ❌ · Methods ❌ · Statements ❌
**More ▾:** Escrow Release · Withholding · Payout Schedule · Payout Settings

### Chip: Ratings
**Visible Tabs:** My Reviews ❌ · Give Review ❌ · Responses ❌ · Analytics ❌ · Disputes ❌
**More ▾:** Public Profile Preview · Flag Abuse · Review Settings

---

# 🌐 الطبقات الأفقية (تظهر في كل الخدمات)

## 🧠 AI Layer

**وصف V4:** AI **ليست خدمة منفصلة** — هي طبقة أفقية.

| المكوّن | الموقع | الوظيفة |
|---|---|---|
| Command Palette (⌘K) | طبقة عائمة في كل شاشة | البحث في كل الخدمات والـ sub-modules |
| Chatter Rail | الحافة اليمنى في كل record screen | tab "AI" يعطي تفسير/توصيات |
| Explain Tooltips | بجانب الحقول | "?" icon يشرح الحقل بـ AI |
| AI Guardrails Review | Settings → AI Agents | مراجعة AI decisions قبل الـ post |
| Knowledge Brain | Top-bar search icon | بحث عالمي في اللوائح والأنظمة |
| Proactive Scanner | Notification Bell | تنبيهات دورية (كل 6 ساعات) |

## ⚙️ Admin Layer

**الوصول:** Top-bar gear icon → Admin Panel (مخصص لـ tenant_admin role فقط)

| Sub-Module | المحتوى |
|---|---|
| Tenant Settings | اسم الشركة، الشعار، العنوان، التخصيصات |
| Users & Roles | إدارة المستخدمين، RBAC (`{service}.{module}.{screen}.{action}`) |
| Integrations | Fatoora credentials · Lean/Tarabut tokens · WhatsApp Business · Slack/Teams |
| Webhooks | إنشاء webhook endpoints للأحداث (journal.posted, invoice.cleared) |
| White-Label | Custom domain, email templates, theme ✅ (theme_generator) |
| Audit Logs | من فعل ماذا ومتى — hash-chain protected |
| Subscriptions | اشتراكات المستخدم في الخدمات الـ5 |
| API Keys | مفاتيح للـ SDKs (Python/Node/PHP) |

## 👤 Account Layer

**الوصول:** Avatar menu في top-bar

| Sub-Module | المحتوى |
|---|---|
| Profile | الصورة، الاسم، البيانات الشخصية، اللغة المفضّلة |
| Security | كلمة المرور، 2FA TOTP ✅، جلسات نشطة، recovery codes ✅ |
| Notifications | تفضيلات الإشعارات (email/SMS/push/in-app) |
| My Subscriptions | مراجعة اشتراكاتي في APEX services |
| Legal | الشروط، الخصوصية، DPA، موافقات سابقة ✅ |
| Archive | سجل العمليات المؤرشفة ✅ |
| Sign Out | الخروج |

---

# 📐 ملخّص الأرقام

| المقياس | العدد |
|---|---|
| **Services (Level 0)** | 5 |
| Service Homes | 5 |
| **Main Modules (Level 1)** | 15 |
| Main Module Dashboards | 15 |
| **Sub-Module Chips (Level 2)** | 55 + 15 dashboards = **70** |
| **Screens/Tabs (Level 3)** | ~280 visible + ~180 overflow = **~460** |
| Horizontal Layers | 3 (AI + Admin + Account) |
| **المجموع الكامل** | **~550 شاشة/tab** |

---

# 🎯 حالة البناء الحالي

| الخدمة | ✅ مبني | 🟡 جزئي | ❌ فجوة | % |
|---|---|---|---|---|
| ERP | 18 | 4 | 20 | **43%** |
| Compliance & Tax | 15 | 5 | 20 | **40%** |
| Audit | 5 | 2 | 25 | **16%** |
| Advisory | 12 | 2 | 18 | **38%** |
| Marketplace | 4 | 0 | 15 | **21%** |
| **الإجمالي** | **54** | **13** | **98** | **33%** |

**33% مبني · 67% فجوات** — واضح أين تتجه الـ waves القادمة.

---

# 🛣️ Roadmap Waves 17+

بعد الدمج، الأولويات حسب الخدمة:

### الأولوية العالية (6 أشهر)
| Wave | الخدمة | Sub-Module |
|---|---|---|
| 17 | ERP | AP: Vendors · POs · Bills · Expense Claims |
| 18 | ERP | HR: Employees · Org Chart · Leaves · Onboarding |
| 19 | ERP | Projects: Tasks · Timesheets · Gantt |
| 20 | ERP | CRM: Leads · Opportunities · Pipeline |
| 21 | Compliance | GOSI · WPS · Mudad UI (backend موجود) |
| 22 | Compliance | AML & KYC screening |

### الأولوية المتوسطة (12 شهر)
| Wave | الخدمة | Sub-Module |
|---|---|---|
| 23 | Audit | Workpapers · Risk Register · Control Testing |
| 24 | Audit | Reporting: Opinion · Management Letter · QC |
| 25 | Advisory | Feasibility: Market · Sensitivity |
| 26 | Advisory | External: Benchmarking · Credit |
| 27 | Marketplace | Billing & Escrow · Payouts · Ratings |

### الأولوية المنخفضة (18 شهر)
| Wave | الخدمة | Sub-Module |
|---|---|---|
| 28 | Compliance | Governance · Board Pack |
| 29 | Audit | Engagement Acceptance · Kick-off |
| 30 | Advisory | Valuation: Monte Carlo · Tornado |

---

*هذه الوثيقة تُحدَّث بعد كل wave — ✅ بجانب الـ chip المكتملة.*
*استبدال: `blueprints/APEX_V4_Module_Hierarchy.txt` (archived كـ V4).*
