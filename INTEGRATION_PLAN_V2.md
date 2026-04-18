# APEX — خطة الدمج والتوزيع التنفيذية V2

> **التاريخ:** 2026-04-18 · **نسخة مصحّحة بعد جرد دقيق**
> **يستبدل:** INTEGRATION_PLAN.md (V1)
> **الغرض:** خطة تنفيذية بدقة متناهية تدمج الفرعين + توزّع الـ 683 ملف backend + 120+ شاشة على V4 الصحيح

---

## 1 · تصحيح الفهم — V4 الحقيقي

### 1.1 الستة Module Groups (من blueprints/APEX_V4_Module_Hierarchy.txt)

| # | المجموعة | Sub-Modules | الشاشات المستهدفة |
|---|---|---|---|
| **1** | ERP System | 11 | ~121 |
| **2** | Audit & Review | 7 | ~70 |
| **3** | **Feasibility Studies** ⬅ جديد | 8 | ~72 |
| **4** | **External Financial Analysis** ⬅ جديد | 7 | ~63 |
| **5** | **Professional Service Providers** (يضم Marketplace + Legal & Contracts) | 6 | ~54 |
| **6** | **Eligibility & Compliance** (يضم ZATCA/GOSI/WPS/AML/Governance) | 7 | ~63 |
| | **المجموع** | **46** | **~443** |

### 1.2 الطبقة الأفقية (Horizontal Layer)

> **قرار V4 الصريح:** AI & Copilot + Knowledge Brain + Smart Reports **ليست module group منفصل**. هي تظهر:
> 1. `apex_chatter_rail` — tab "AI" على كل record screen
> 2. `apex_command_palette` — ⌘K في كل مكان
> 3. Field-level "Explain ?" tooltips
> 4. Settings → AI Agents gallery (5 agents)
> 5. Knowledge Brain search icon في الـ top bar

### 1.3 "Account" وSettings وInfrastructure — خارج V4

- Profile / Auth / Legal / Subscriptions → top-bar avatar menu، مش V4 group
- Admin / Rate Limiting / Cache / WebSocket / RLS / Multi-tenant → Shared Infrastructure

---

## 2 · الواقع الحالي — جرد دقيق

### 2.1 حالة الفرعين

| الفرع | commits vs main | Python الجديد | Test الجديد | Apex components | شاشات جديدة |
|---|---|---|---|---|---|
| **brave-yonath** | 17 PR (waves 0-15) | ~15 ملف | ~200 اختبار | 9 (`v4/apex_*.dart`) | 6 (`v4_*/`) |
| **priceless-lamarr** | 50 commit | **159 ملف** | **63 ملف** | **46 (`core/apex_*.dart`)** | 16 (`whats_new/` + `showcase/`) |

### 2.2 جرد الـ 683 ملف Python (backend)

| الفئة | brave-yonath | priceless-lamarr | مجموع |
|---|---|---|---|
| Core services (`core/*_service.py`) | 43 | 42 | 85 |
| Core routes (`core/*_routes.py`) | 29 | 24 | 53 |
| Infrastructure (auth, cache, WS, RLS) | 16 | 25 | 41 |
| COA Engine (governance) | 14 | — | 14 |
| Copilot | 8 | — | 8 |
| Knowledge Brain | 19 | — | 19 |
| HR module | — | 6 | 6 |
| AI Proactive (scheduler + scan) | — | 4 | 4 |
| Integrations (ZATCA/Banks/UAE/WhatsApp/Payments) | — | 29 | 29 |
| Services (financial/classification) | 17 | 19 | 36 |
| Features (ap_agent, startup_metrics) | — | 7 | 7 |
| Industry packs | — | 2 | 2 |
| **TOTAL** | **146** | **158** | **304 غير متكرّر** |

### 2.3 الـ Apex Layer الحقيقي — اكتشاف مهم

الـ 46 ملف `apex_*.dart` في priceless-lamarr **مش مكوّنات مكرّرة** مع الـ 9 ملف `v4/apex_*.dart` في brave-yonath:

- **priceless-lamarr/core/apex_*** = مكوّنات tactical (data_table, filter_bar, form_field, command_palette, chatter, notification_bell, إلخ)
- **brave-yonath/core/v4/apex_*** = مكوّنات architectural (screen_host, sub_module_shell, tab_bar, launchpad) — V4 structure

**بالإضافة:** `ui_components.dart` موجود في الـ main بالفعل بـ 44 مكوّن تصميمي قديم (apexPill, apexPrimaryButton, ApexIconButton، إلخ) — دول الأساس الحالي ومعظم الشاشات بتستخدمهم.

**التوزيع النهائي للطبقات:**

```
┌─────────────────────────────────────────────────┐
│  Layer 1 (Foundation): ui_components.dart       │
│  → 44 مكوّن old-school (pills, buttons, cards) │
│  → موجود في main، كل الشاشات تستخدمه            │
├─────────────────────────────────────────────────┤
│  Layer 2 (Tactical): core/apex_*.dart           │
│  → 46 مكوّن من priceless-lamarr                │
│  → data_table, filter_bar, command_palette...   │
│  → لم يُدمج بعد                                 │
├─────────────────────────────────────────────────┤
│  Layer 3 (Architectural): core/v4/apex_*.dart   │
│  → 9 مكوّن من brave-yonath (Wave 1.5-3)         │
│  → screen_host, sub_module_shell, tab_bar       │
│  → مُدمج في brave-yonath، لم يصل main          │
└─────────────────────────────────────────────────┘
```

---

## 3 · الـ Mapping الصحيح — backend → V4

### 3.1 ERP System (مجموعة 1)

#### 2.1 Dashboard
- **Backend:** `core/analytics_routes.py` + `services/financial/readiness_engine.py` (P-L)
- **Frontend:** `dashboard/enhanced_dashboard.dart` + `compliance/executive_dashboard_screen.dart`

#### 2.2 General Ledger
- **Backend:**
  - `core/journal_entry_service.py` + `core/accounting_routes.py` (P-L)
  - `core/ledger_routes.py` (P-L)
  - `core/fin_statements_routes.py` + `fin_statements_service.py` (P-L)
  - `core/consolidation_routes.py` + `consolidation_service.py` + `consolidation_intercompany.py` (P-L)
  - `coa_engine/*` (14 ملف موجود) — governance
- **Frontend:**
  - `compliance/journal_entries_screen.dart`
  - `compliance/journal_entry_builder_screen.dart`
  - `coa/coa_tree_screen.dart` + `coa_v2/coa_journey_screen.dart`
  - `simulation/trial_balance_screen.dart`
  - `compliance/fin_statements_screen.dart`
  - `compliance/consolidation_screen.dart`

#### 2.3 Sales & AR
- **Backend:**
  - `core/aging_service.py` (P-L) — AR aging buckets
  - `core/revenue_service.py` (P-L) — IFRS 15
  - `core/ecl_service.py` (P-L) — Expected Credit Loss
  - `core/payment_service.py` (P-L)
- **Frontend:**
  - `v4_erp/sales_customers_screen.dart` (B-Y Wave 2)
  - `clients/client_detail_screen.dart`
  - `clients/client_onboarding_wizard.dart`
  - `compliance/aging_screen.dart`

#### 2.4 Purchasing & AP
- **Backend:**
  - `features/ap_agent/*.py` (P-L) — autonomous AP
    - `pipeline.py` — 3-way match
    - `real_processors.py` — autopilot
  - `core/payment_service.py` (مشترك مع 2.3)
- **Frontend:**
  - `whats_new/sprint41_procurement_screen.dart` (P-L)
  - **فجوة:** Vendors list, PO list, Bills, Expense Claims screens (مفقودين — Wave 17+)

#### 2.5 Inventory
- **Backend:**
  - `core/inventory_service.py` (P-L) — FIFO/LIFO/WAC
  - `core/cost_accounting_routes.py` + `cost_accounting_service.py` (P-L)
  - `core/job_costing_service.py` (P-L)
  - `core/dimensional_accounting.py` (P-L) — cost centers
- **Frontend:**
  - `compliance/inventory_screen.dart`
  - `whats_new/sprint44_operations_screen.dart` (BOM parts)

#### 2.6 Treasury & Banking
- **Backend:**
  - `core/bank_feeds.py` + `bank_feeds_routes.py` (B-Y Wave 13)
  - `core/bank_reconciliation.py` + `bank_reconciliation_routes.py` (B-Y Wave 15)
  - `core/bank_rec_service.py` (P-L قديم — يُستبدل)
  - `core/cashflow_service.py` + `cashflow_routes.py` (P-L)
  - `core/cashflow_statement_routes.py` + `service.py` (P-L) — IAS 7
  - `core/fx_service.py` (P-L)
  - `integrations/bank_ocr/*.py` (P-L) — statement OCR
  - `integrations/open_banking/consent.py` (P-L)
- **Frontend:**
  - `v4_erp/bank_feeds_screen.dart` (B-Y Wave 14)
  - `compliance/bank_rec_screen.dart`
  - `compliance/fx_converter_screen.dart`
  - `compliance/cashflow_screen.dart`
  - **Wave 16 سيضيف:** `ai_bank_reconciliation_screen.dart`

#### 2.7 HR & Payroll
- **Backend:**
  - `hr/routes.py` (P-L) — `/hr/employees`, `/hr/leave-requests`, `/hr/payroll`
  - `hr/models.py` (P-L) — Employee, Leave, Payroll, Payslip
  - `hr/eosb_calculator.py` (P-L) — KSA/UAE EOSB
  - `hr/gosi_calculator.py` (P-L) — GOSI KSA
  - `hr/wps_generator.py` (P-L) — WPS SIF
  - `core/payroll_service.py` (قديم — سيُدمج أو يُستبدل)
- **Frontend:**
  - `compliance/payroll_screen.dart`
  - `whats_new/sprint40_payroll_reports_screen.dart` (P-L)
  - `whats_new/sprint39_erp_screen.dart` (P-L) — HR Kanban
  - **فجوة:** Org Chart, Contracts, Leaves, Attendance screens

#### 2.8 Projects
- **Backend:**
  - `core/job_costing_service.py` (P-L — مشترك مع 2.5)
  - **فجوة:** Tasks, Timesheets, Budgets, Resource Allocation models
- **Frontend:**
  - `whats_new/sprint44_operations_screen.dart` (P-L) — Work Orders + Gantt
  - `tasks/audit_service_screen.dart`
  - **فجوة:** Project list, Timesheet, Milestones

#### 2.9 CRM
- **Backend:**
  - **فجوة كاملة:** لا models, لا routes, لا services لـ leads/opportunities
- **Frontend:**
  - `providers/provider_kanban_screen.dart` (غير مخصّصة لـ CRM أصلاً)
  - `whats_new/sprint39_erp_screen.dart` (P-L) — CRM Kanban placeholder
  - **فجوة:** Leads, Opportunities, Activities, Email Sync

#### 2.10 ZATCA & Tax (ERP side — للمحاسبين)
- **Backend:**
  - `core/zatca_service.py` (موجود) — UBL 2.1, TLV QR, ICV
  - `core/zatca_routes.py` (موجود + P-L E2E)
  - `core/zatca_csid.py` + `zatca_csid_routes.py` (B-Y Wave 11)
  - `core/zatca_queue_routes.py` + `zatca_queue_worker.py` (B-Y Wave 9)
  - `core/zatca_retry_queue.py` (B-Y Wave 5)
  - `core/zatca_error_translator.py` (B-Y Wave 2)
  - `integrations/zatca/signer.py` + `fatoora_client.py` + `cert_store.py` + `invoice_pdf.py` (P-L)
  - `core/tax_routes.py` + `advanced_tax_service.py` (P-L)
  - `core/vat_service.py` (P-L)
  - `core/wht_routes.py` + `wht_service.py` (P-L)
  - `core/zakat_service.py` (P-L)
  - `core/deferred_tax_routes.py` + `service.py` (P-L)
  - `core/transfer_pricing_routes.py` + `service.py` (P-L)
- **Frontend:**
  - `compliance/zatca_invoice_builder_screen.dart`
  - `v4_compliance/zatca_csid_screen.dart` (B-Y Wave 12)
  - `v4_compliance/zatca_queue_screen.dart` (B-Y Wave 6)
  - `compliance/zakat_calculator_screen.dart`
  - `compliance/vat_return_screen.dart`
  - `compliance/wht_screen.dart`
  - `whats_new/uae_corp_tax_screen.dart` (P-L)
  - `compliance/transfer_pricing_screen.dart`
  - `compliance/deferred_tax_screen.dart`

#### 2.11 Reports & Analytics
- **Backend:**
  - `core/ratios_routes.py` + ratio_engine (P-L) — 18 ratio
  - `core/extras_routes.py` (P-L) — 35-tool hub
  - `core/ifrs_extras_routes.py` (P-L) — IFRS 2/40/41, RETT, Pillar Two, VAT Group, Job Costing
  - `core/health_score_service.py` (P-L)
  - `core/working_capital_service.py` (P-L)
  - `core/reports_download.py` (P-L)
- **Frontend:**
  - `whats_new/startup_metrics_screen.dart` (P-L)
  - `compliance/health_score_screen.dart`
  - `compliance/financial_ratios_screen.dart`
  - `compliance/budget_variance_screen.dart`
  - `compliance/cost_variance_screen.dart`
  - `compliance/extras_tools_screen.dart`
  - `compliance/ifrs_tools_screen.dart`

### 3.2 Audit & Review (مجموعة 2)

#### 3.1 Audit Dashboard
- **Backend:** `core/compliance_routes.py` + `compliance_service.py` (P-L)
- **Frontend:** `compliance/compliance_hub_screen.dart` + `compliance_health_widget.dart`

#### 3.2 Engagement Planning
- **Backend:** **فجوة** (audit engagement lifecycle غير مبني)
- **Frontend:** `audit/audit_workflow_screen.dart` + `simulation/roadmap_screen.dart`

#### 3.3 Risk Assessment
- **Backend:**
  - `core/anomaly_detector.py` + `anomaly_routes.py` (B-Y Wave 3)
- **Frontend:**
  - `v4_compliance/compliance_status_screen.dart` (B-Y Wave 4)
  - `simulation/compliance_check_screen.dart`

#### 3.4 Workpapers
- **Backend:**
  - `core/audit_log.py` + `activity_log.py` + `auto_log.py` (P-L)
  - `core/schema_drift.py` (موجود)
- **Frontend:** `compliance/audit_trail_screen.dart`

#### 3.5 Control Testing — **فجوة**

#### 3.6 Report Issuance — **فجوة**

#### 3.7 Quality Control — **فجوة**

### 3.3 Feasibility Studies (مجموعة 3) ⬅ جديدة

#### 4.1 Feasibility Dashboard — **فجوة**

#### 4.2 Project Setup — **فجوة**

#### 4.3 Market Analysis — **فجوة**

#### 4.4 Cost & Revenue Model
- **Backend:** `core/breakeven_service.py` (P-L)
- **Frontend:** `compliance/breakeven_screen.dart`

#### 4.5 Pro-Forma Financials
- **Backend:** `core/investment_service.py` + `investment_routes.py` (P-L) — NPV/IRR
- **Frontend:** `compliance/investment_screen.dart`

#### 4.6 Valuation & Decision Metrics
- **Backend:**
  - `core/valuation_routes.py` + `valuation_service.py` (P-L) — DCF, WACC
  - `core/dscr_service.py` (P-L)
- **Frontend:**
  - `compliance/dscr_screen.dart`
  - `compliance/valuation_screen.dart`
  - `simulation/financial_simulation_screen.dart`

#### 4.7 Sensitivity & Risk — **فجوة**

#### 4.8 Final Report
- **Backend:** `services/ai/narrative_service.py` (P-L)
- **Frontend:** **فجوة** (UI مش مبني)

### 3.4 External Financial Analysis (مجموعة 4) ⬅ جديدة

#### 5.1 Analysis Dashboard — **فجوة**

#### 5.2 Upload Statements
- **Backend:** `core/ocr_routes.py` + `ocr_service.py` (P-L)
- **Frontend:** `compliance/ocr_screen.dart`

#### 5.3 Ratio Analysis
- **Backend:** `core/ratios_routes.py` + ratio_engine (P-L) — 18 ratio
- **Frontend:** `compliance/financial_ratios_screen.dart` + `working_capital_screen.dart`

#### 5.4 Industry Benchmarking — **فجوة**

#### 5.5 Valuation Models
- **Frontend:** `compliance/valuation_screen.dart` (مشترك مع 4.6)

#### 5.6 Credit Analysis
- **Backend:** `core/dscr_service.py` (مشترك)
- **Frontend:** **فجوة** (Z-Score, Altman، الخ)

#### 5.7 Analytical Reports — **فجوة**

### 3.5 Professional Service Providers (مجموعة 5)

#### 6.1 Provider Dashboard
- **Frontend:** `providers/provider_profile_screen.dart`

#### 6.2 Marketplace
- **Backend:**
  - `core/marketplace_enhanced.py` (P-L)
  - `industry_packs/registry.py` (P-L)
- **Frontend:**
  - `marketplace/service_catalog_screen.dart`
  - `marketplace/service_request_detail.dart`
  - `whats_new/industry_packs_screen.dart` (P-L)

#### 6.3 Legal & Contracts
- **Frontend:** `legal/legal_acceptance_screen.dart` + `extracted/legal_screens_v2.dart`

#### 6.4 Tasks & Deliverables
- **Frontend:** `providers/provider_kanban_screen.dart` + `tasks/audit_service_screen.dart`

#### 6.5 Billing & Payments
- **Backend:** `integrations/payments/*.py` (P-L) — Tabby, STC Pay, Mada, Apple Pay

#### 6.6 Ratings & Reviews — **فجوة**

### 3.6 Eligibility & Compliance (مجموعة 6)

#### 7.1 Compliance Dashboard
- **Frontend:** `compliance/compliance_hub_screen.dart` (مشترك مع Audit 3.1)

#### 7.2 Eligibility Check — **فجوة** (SME, IPO, Tadawul)

#### 7.3 ZATCA Compliance (للمراجعين)
- نفس Backend ERP 2.10 لكن **بـ views مختلفة** للـ compliance team

#### 7.4 GOSI & WPS
- **Backend:** `hr/gosi_calculator.py` + `wps_generator.py` (P-L)
- **Frontend:** **فجوة UI**

#### 7.5 AML & KYC — **فجوة**

#### 7.6 Governance & Board — **فجوة**

#### 7.7 Compliance Reports — **فجوة**

### 3.7 طبقة أفقية (AI & Copilot)

- `apex_command_palette.dart` (P-L) — ⌘K عالمي
- `apex_chatter.dart` + `chatter_connected.dart` (P-L) — AI rail
- `apex_notification_bell_live.dart` (P-L) — live bell
- `knowledge/knowledge_brain_screen.dart` — Settings → AI Agents
- `copilot/copilot_screen.dart` — dedicated Copilot hub
- `v4_ai/ai_guardrails_screen.dart` (B-Y Wave 8) — Settings → AI Agents
- **Backend:** `ai/proactive.py` + `ai/scheduler.py` + `ai/routes.py` (P-L)
- **Backend:** `core/ai_guardrails.py` + `ai_guardrails_routes.py` (B-Y Wave 7)
- **Backend:** `copilot/routes/copilot_routes.py` + services (موجود)

### 3.8 Shared Infrastructure (خارج V4)

- `core/auth_utils.py`, `totp_service.py`, `social_auth_verify.py`
- `core/rate_limit_backend.py` (B-Y Wave 1)
- `core/tenant_context.py` + `tenant_guard.py` + `rls_session.py` (P-L)
- `core/cache.py`, `webhooks.py`, `websocket_hub.py`, `offline_sync.py`, `pagination.py` (P-L)
- `core/api_version.py`, `system_health.py` (P-L)
- `core/observability.py` (B-Y Wave 1)
- `core/env_validator.py`, `schema_drift.py`, `error_messages.py`
- `core/notifications_api.py`, `notifications_bridge.py`, `sms_backend.py`, `email_service.py`, `storage_service.py`

---

## 4 · Mapping الشاشات الكامل (كل شاشة → V4 module)

### 4.1 جدول التوزيع

| المجموعة V4 | Sub-Module | الشاشات المنقولة | المسار الجديد |
|---|---|---|---|
| ERP | 2.1 Dashboard | enhanced_dashboard, executive_dashboard | `erp/dashboard/` |
| ERP | 2.2 General Ledger | journal_entries, journal_entry_builder, coa_tree, coa_journey, trial_balance, fin_statements, cashflow_statement, consolidation | `erp/general_ledger/` |
| ERP | 2.3 Sales & AR | sales_customers, client_detail, client_onboarding_wizard, aging | `erp/sales_ar/` |
| ERP | 2.4 Purchasing & AP | sprint41_procurement | `erp/purchasing_ap/` |
| ERP | 2.5 Inventory | inventory, sprint44_operations (BOM) | `erp/inventory/` |
| ERP | 2.6 Treasury | bank_feeds, bank_rec, fx_converter, cashflow, **ai_bank_rec (Wave 16)** | `erp/treasury/` |
| ERP | 2.7 HR & Payroll | payroll, sprint40_payroll_reports, sprint39_erp_hr | `erp/hr_payroll/` |
| ERP | 2.8 Projects | sprint44_operations (WO), audit_service | `erp/projects/` |
| ERP | 2.9 CRM | provider_kanban, sprint39_erp_crm | `erp/crm/` |
| ERP | 2.10 ZATCA & Tax | zatca_invoice_builder, zatca_csid, zatca_queue, zakat, vat_return, wht, uae_corp_tax, transfer_pricing, deferred_tax | `erp/zatca_tax/` |
| ERP | 2.11 Reports | startup_metrics, health_score, financial_ratios, budget_variance, cost_variance, extras_tools, ifrs_tools | `erp/reports/` |
| Audit | 3.1 Audit Dashboard | compliance_hub, compliance_health_widget | `audit/dashboard/` |
| Audit | 3.2 Engagement Planning | audit_workflow, roadmap | `audit/planning/` |
| Audit | 3.3 Risk Assessment | compliance_status, compliance_check | `audit/risk/` |
| Audit | 3.4 Workpapers | audit_trail | `audit/workpapers/` |
| Feasibility | 4.4 Cost & Revenue | breakeven | `feasibility/cost_revenue/` |
| Feasibility | 4.5 Pro-Forma | investment (NPV/IRR) | `feasibility/pro_forma/` |
| Feasibility | 4.6 Valuation | dscr, valuation, financial_simulation | `feasibility/valuation/` |
| Feasibility | 4.7 Sensitivity | fixed_assets, depreciation, amortization, lease, ocr | `feasibility/sensitivity/` |
| External | 5.2 Upload Statements | ocr | `external/upload/` |
| External | 5.3 Ratio Analysis | financial_ratios, working_capital | `external/ratios/` |
| External | 5.5 Valuation Models | valuation (مشترك) | `external/valuation/` |
| Providers | 6.1 Provider Dashboard | provider_profile | `providers/dashboard/` |
| Providers | 6.2 Marketplace | service_catalog, service_request_detail, industry_packs | `providers/marketplace/` |
| Providers | 6.3 Legal | legal_acceptance, legal_screens_v2 | `providers/legal/` |
| Providers | 6.4 Tasks | provider_kanban, audit_service | `providers/tasks/` |
| Compliance | 7.1 Compliance Dashboard | compliance_hub (مشترك) | `compliance/dashboard/` |
| Compliance | 7.3 ZATCA (review view) | *placeholder* | `compliance/zatca/` |
| AI Layer | ⌘K / Chatter / Bell | (components only) | `core/apex_*.dart` |
| AI Settings | AI Agents | ai_guardrails, copilot, knowledge_brain | `ai_settings/` |
| Account | top-bar | account_sub, archive, slide_auth, forgot_password | `account/` |
| Platform | Admin | admin_sub, enhanced_settings | `platform/admin/` |
| Platform | Notifications | notification_detail, notification_screens_v2 | `platform/notifications/` |
| Platform | White-Label | white_label_settings, theme_generator, apex_map | `platform/white_label/` |
| Dev Only | Demos | apex_whats_new_hub, feature_demos, syncfusion_grid_demo, sprint35/37/38/42/43, onboarding_wizard, apex_showcase | `_dev/` |

### 4.2 الفجوات — ما يحتاج بناء جديد

| المجموعة | Sub-Modules بدون شاشات | الأولوية |
|---|---|---|
| ERP | 2.4 (Vendors/PO/Bills) · 2.7 (Org/Contracts/Leaves) · 2.8 (Tasks/Timesheets) · 2.9 (Leads/Opp) | عالية |
| Audit | 3.5 Control Testing · 3.6 Report Issuance · 3.7 QC | متوسطة |
| Feasibility | 4.1/4.2/4.3/4.8 | متوسطة |
| External | 5.1/5.4/5.6/5.7 | متوسطة |
| Providers | 6.5 Billing · 6.6 Ratings | منخفضة |
| Compliance | 7.2/7.4/7.5/7.6/7.7 | عالية (ZATCA urgent) |

**الإجمالي: ~28 sub-module بدون شاشات** → تبني بعد الدمج في waves 17-35.

---

## 5 · الخطة التنفيذية — 6 مراحل مُنقّحة

### مبدأ الخطة

**بدل 10 مراحل تسلسلية (V1)، خطة V2 تستخدم 6 مراحل فيها مراحل متوازية مع فترات verification صارمة:**

### مرحلة 1 — تأسيس main (3-4 أيام)

**الهدف:** دمج PRs brave-yonath المتراكمة على main.

**المهام:**
1.1. دمج 17 PR (waves 0-15) بالترتيب عبر GitHub UI
1.2. كل PR: change base to main → CI pass → merge
1.3. بعد كل merge: `git pull origin main && pytest tests/`

**Gates:**
- [ ] 17 merge commits على main
- [ ] `pytest tests/` = 1133 pass
- [ ] `flutter analyze` = clean
- [ ] `flutter build web` = success

**Output:** main يحتوي على:
- 9 apex v4 components
- 6 new screens (v4_ai, v4_compliance, v4_erp)
- Security hardening + ZATCA pipeline + AI Guardrails + Bank Feeds + Bank Rec

---

### مرحلة 2 — فرع التكامل + Shared Infrastructure (1 يوم)

**الهدف:** إنشاء `integration/unified` + دمج الـ infrastructure من priceless-lamarr.

**Commits to cherry-pick (12 commit):**
```bash
# Foundation fixes
git cherry-pick 134ccd1  # Foundation fixes 0.1 + 0.4 + 0.5
git cherry-pick 0e012ad  # Production hard-checks + tiered rate limiting
git cherry-pick d477923  # Foundation test lock-in

# Multi-tenancy + RLS
git cherry-pick c170e06  # Multi-tenant query guard
git cherry-pick 69e483d  # Tenant RLS + cursor pagination + audit + WS
git cherry-pick fcc253b  # PostgreSQL RLS policies

# Infrastructure
git cherry-pick 64e5aaa  # Auto_log SQLAlchemy listener
git cherry-pick f37ef3c  # Alembic q1_2026 migration
git cherry-pick ea82ed6  # Cache + API v1 + saved views + Peppol + responsive
git cherry-pick 67aeba6  # Realtime WebSocket push
git cherry-pick e1cda40  # Reports download + system health
git cherry-pick 2e92515  # Notifications list API + Bell bootstrap
```

**توقع تعارضات:**
- `app/main.py` → union merge
- `app/core/auth_utils.py` → خد brave-yonath (أعمق من waves 1-2)
- Alembic migration — append جديدة بدل replace

**Gates:**
- [ ] `pytest tests/test_tenant_guard.py tests/test_rls_session_hook.py tests/test_websocket_hub.py` = pass
- [ ] `pytest tests/` ≥ 1200 pass

---

### مرحلة 3 — Apex Tactical Layer + UI الموحّد (3-4 أيام)

**الهدف:** دمج الـ 46 apex component + تطبيقهم.

**Commits to cherry-pick (18 commit):**
```bash
# Apex components
git cherry-pick d0a73c9  # 8 shared components + Saudi validators (BASE)
git cherry-pick 9c762d7  # Copilot memory + Notifications bridge + A11y + Bell + Voice
git cherry-pick 9f9a685  # Sprint 37-38 — app switcher + contextual toolbar + breadcrumbs

# Apex application to screens
git cherry-pick 572d64f  # Apply to Clients + Showcase
git cherry-pick be01c9f  # Wire Apex Layer into production screens
git cherry-pick 7417753  # ApexStickyToolbar on 5 compliance screens
git cherry-pick 5ce64d5  # ApexAppBar on 12 compliance screens
git cherry-pick 2db30e3  # Mass-convert 45 screens to ApexAppBar

# Advanced components
git cherry-pick b892575  # Governed AI + Webhooks + Dashboard Builder + Bottom Nav
git cherry-pick 5bef1d8  # Composable dashboard + notification center
git cherry-pick d368be8  # Theme generator

# Real-time Flutter
git cherry-pick 186a670  # Flutter WebSocket client + live Chatter + Bell
git cherry-pick 072d76c  # Global live bell + proactive scanner
git cherry-pick a4b233c  # Background scheduler (6h proactive scans)

# Mobile + Syncfusion
git cherry-pick 6a71b9a  # Syncfusion DataGrid + fastlane

# Copilot enhancements
git cherry-pick 69f7d08  # 4 new Copilot tools
git cherry-pick 83b934f  # Dimensional Accounting + Intercompany + FCL + Node SDK

# UX polish
git cherry-pick f1505c9  # Saved views + recent items + live validation
git cherry-pick 59c9523  # Alt+1..9 + inline edit + PWA sync
```

**توقع تعارضات:**
- `apex_finance/lib/core/router.dart` → احتفظ بـ v4_routes.dart من brave-yonath + أضف الـ legacy routes من priceless-lamarr
- `apex_app.dart` → union (theme + routes + providers)
- `pubspec.yaml` → union dependencies

**Gates:**
- [ ] `flutter analyze` = clean
- [ ] `flutter build web --release` = success
- [ ] الـ 46 apex component موجودين: `ls apex_finance/lib/core/apex_*.dart | wc -l` ≥ 46
- [ ] Command Palette (Ctrl+K) يعمل
- [ ] Live bell يعمل بعد backend WebSocket

---

### مرحلة 4 — Backend Features الموحّدة (4-5 أيام)

**الهدف:** دمج 159 ملف Python (financial tools + IFRS + tax + HR + integrations).

**Commits to cherry-pick مقسّمة لـ 4 دفعات (batches) مع اختبار بعد كل واحدة:**

**Batch 4A — Financial Calculators (15 commit):**
```bash
git cherry-pick 3b5caa9 db175fb e8e8235 029ad81 5cb53f0 \
               1f41afd 235c652 97a0330 16173da a520f7e \
               7bc31eb 8f2f913 a9a06a6 0bd02a9 f906585
```

**Batch 4B — IFRS + Advanced Tax (5 commit):**
```bash
git cherry-pick a0d6a84 8367501 4815162 d597a76 09b172a
```

**Batch 4C — ERP Integrations (5 commit):**
```bash
git cherry-pick f065939 af3b5cd 9256c37 ea1c3cd 32f430e
```

**Batch 4D — ZATCA production + PDF (3 commit):**
```bash
git cherry-pick e85afb1  # Printable invoice PDF with TLV QR
git cherry-pick f5ebf1a  # Production-grade E2E submit route
git cherry-pick fcc253b  # (already in Phase 2)
```

**Gates بعد كل batch:**
- [ ] `pytest tests/` مش أقل من السابق
- [ ] `curl http://localhost:8000/api/docs` يعرض الـ endpoints الجديدة

**Gate نهائي المرحلة:**
- [ ] `pytest tests/` ≥ 1350 pass
- [ ] `cd app && python -c "from main import app; print(len(app.routes))"` = ≥350 route

---

### مرحلة 5 — توزيع الشاشات على V4 الهيكل (3 أيام)

**الهدف:** إعادة تنظيم 120+ شاشة إلى V4.

**الخطوة 5.1 — إنشاء الهيكل:**
```bash
cd apex_finance/lib/screens
mkdir -p erp/{dashboard,general_ledger,sales_ar,purchasing_ap,inventory,treasury,hr_payroll,projects,crm,zatca_tax,reports}
mkdir -p audit/{dashboard,planning,risk,workpapers,control_testing,report_issuance,quality_control}
mkdir -p feasibility/{dashboard,setup,market,cost_revenue,pro_forma,valuation,sensitivity,final_report}
mkdir -p external/{dashboard,upload,ratios,benchmarking,valuation,credit,reports}
mkdir -p providers/{dashboard,marketplace,legal,tasks,billing,ratings}
mkdir -p compliance/{dashboard,eligibility,zatca,gosi_wps,aml_kyc,governance,reports}
mkdir -p ai_settings/{agents,guardrails,knowledge,copilot}
mkdir -p platform/{admin,notifications,white_label,webhooks}
mkdir -p account/{profile,legal,subscriptions}
mkdir -p _dev
```

**الخطوة 5.2 — نقل الشاشات عبر script `scripts/v4_reorganize.sh`:**

> Script كامل موجود في قسم 6 من الوثيقة.

**الخطوة 5.3 — تحديث imports:**
```bash
# تلقائياً عبر regex
find apex_finance/lib -name "*.dart" -exec \
  sed -i 's|screens/compliance/journal_entries|screens/erp/general_ledger/journal_entries|g' {} +
# (أكثر من 40 regex لكل transfer)
```

**الخطوة 5.4 — تحديث v4_routes.dart:**
- نقل الـ wired screens إلى المسارات الجديدة
- إضافة routes لكل شاشة منقولة

**Gates:**
- [ ] `flutter analyze` = 0 errors, ≤ 5 info
- [ ] `flutter test` = كل الاختبارات تمر
- [ ] `flutter build web --release` = success
- [ ] Manual QA: افتح 10 شاشات عشوائية من V4 → كلهم يلودوا
- [ ] Ctrl+K يشتغل ويبحث في كل الـ 46 sub-module

---

### مرحلة 6 — دمج نهائي على main + تنظيف (1 يوم)

**الهدف:** PR واحد كبير من `integration/unified` إلى main + تنظيف الفرعين.

**الخطوات:**
```bash
# 1. تأكّد integration branch مستقر
pytest tests/ && cd apex_finance && flutter test && flutter build web --release

# 2. ادفع
git push origin integration/unified

# 3. افتح PR لـ main
gh pr create --base main --head integration/unified \
  --title "Unified Integration: waves 0-15 + 50 features + V4 reorganization" \
  --body-file INTEGRATION_PR_BODY.md

# 4. بعد merge، تنظيف
git worktree remove C:/apex_app/.claude/worktrees/priceless-lamarr
# (احتفظ بالـ remote branch أسبوع كـ archive)

# 5. تحديث docs
# - blueprints/APEX_V4_Module_Hierarchy.txt: أضف Implementation Notes لكل screen
# - STATE_OF_APEX.md: حدّث الأرقام
# - CLAUDE.md: أضف conventions الجديدة
```

**Gates نهائية:**
- [ ] `main` فيه كل commits
- [ ] `pytest` ≥ 1400 pass
- [ ] `flutter build web` success
- [ ] كل الـ 6 V4 groups متاحة في /app/launchpad
- [ ] جاهز لبدء Wave 16+ لسد الفجوات

---

## 6 · سكربت إعادة التنظيم (5.2) — الكامل

```bash
#!/bin/bash
# scripts/v4_reorganize.sh — نقل 120+ شاشة إلى V4 structure
set -e
cd apex_finance/lib/screens

echo "=== ERP Group ==="
# 2.1 Dashboard
git mv dashboard/enhanced_dashboard.dart erp/dashboard/
git mv compliance/executive_dashboard_screen.dart erp/dashboard/

# 2.2 General Ledger
git mv compliance/journal_entries_screen.dart erp/general_ledger/
git mv compliance/journal_entry_builder_screen.dart erp/general_ledger/
git mv coa/coa_tree_screen.dart erp/general_ledger/
git mv coa_v2/coa_journey_screen.dart erp/general_ledger/
git mv simulation/trial_balance_screen.dart erp/general_ledger/
git mv compliance/fin_statements_screen.dart erp/general_ledger/
git mv compliance/cashflow_statement_screen.dart erp/general_ledger/
git mv compliance/consolidation_screen.dart erp/general_ledger/

# 2.3 Sales & AR
git mv v4_erp/sales_customers_screen.dart erp/sales_ar/
git mv clients/client_detail_screen.dart erp/sales_ar/
git mv clients/client_onboarding_wizard.dart erp/sales_ar/
git mv compliance/aging_screen.dart erp/sales_ar/

# 2.4 Purchasing & AP
git mv whats_new/sprint41_procurement_screen.dart erp/purchasing_ap/

# 2.5 Inventory
git mv compliance/inventory_screen.dart erp/inventory/

# 2.6 Treasury
git mv v4_erp/bank_feeds_screen.dart erp/treasury/
git mv compliance/bank_rec_screen.dart erp/treasury/
git mv compliance/fx_converter_screen.dart erp/treasury/
git mv compliance/cashflow_screen.dart erp/treasury/

# 2.7 HR & Payroll
git mv compliance/payroll_screen.dart erp/hr_payroll/
git mv whats_new/sprint40_payroll_reports_screen.dart erp/hr_payroll/
git mv whats_new/sprint39_erp_screen.dart erp/hr_payroll/

# 2.8 Projects
git mv whats_new/sprint44_operations_screen.dart erp/projects/
git mv tasks/audit_service_screen.dart erp/projects/

# 2.9 CRM
git mv providers/provider_kanban_screen.dart erp/crm/

# 2.10 ZATCA & Tax
git mv compliance/zatca_invoice_builder_screen.dart erp/zatca_tax/
git mv v4_compliance/zatca_csid_screen.dart erp/zatca_tax/
git mv v4_compliance/zatca_queue_screen.dart erp/zatca_tax/
git mv compliance/zakat_calculator_screen.dart erp/zatca_tax/
git mv compliance/vat_return_screen.dart erp/zatca_tax/
git mv compliance/wht_screen.dart erp/zatca_tax/
git mv whats_new/uae_corp_tax_screen.dart erp/zatca_tax/
git mv compliance/transfer_pricing_screen.dart erp/zatca_tax/
git mv compliance/deferred_tax_screen.dart erp/zatca_tax/

# 2.11 Reports
git mv whats_new/startup_metrics_screen.dart erp/reports/
git mv compliance/health_score_screen.dart erp/reports/
git mv compliance/budget_variance_screen.dart erp/reports/
git mv compliance/cost_variance_screen.dart erp/reports/
git mv compliance/extras_tools_screen.dart erp/reports/
git mv compliance/ifrs_tools_screen.dart erp/reports/

echo "=== Audit & Review Group ==="
git mv compliance/compliance_hub_screen.dart audit/dashboard/
git mv compliance/compliance_health_widget.dart audit/dashboard/
git mv audit/audit_workflow_screen.dart audit/planning/
git mv simulation/roadmap_screen.dart audit/planning/
git mv v4_compliance/compliance_status_screen.dart audit/risk/
git mv simulation/compliance_check_screen.dart audit/risk/
git mv compliance/audit_trail_screen.dart audit/workpapers/

echo "=== Feasibility Studies Group ==="
git mv compliance/breakeven_screen.dart feasibility/cost_revenue/
git mv compliance/investment_screen.dart feasibility/pro_forma/
git mv compliance/dscr_screen.dart feasibility/valuation/
git mv compliance/valuation_screen.dart feasibility/valuation/  # مشترك مع external
git mv simulation/financial_simulation_screen.dart feasibility/valuation/
git mv compliance/fixed_assets_screen.dart feasibility/sensitivity/
git mv compliance/depreciation_screen.dart feasibility/sensitivity/
git mv compliance/amortization_screen.dart feasibility/sensitivity/
git mv compliance/lease_screen.dart feasibility/sensitivity/

echo "=== External Financial Analysis Group ==="
git mv compliance/ocr_screen.dart external/upload/
git mv compliance/financial_ratios_screen.dart external/ratios/
git mv compliance/working_capital_screen.dart external/ratios/

echo "=== Professional Service Providers Group ==="
git mv providers/provider_profile_screen.dart providers/dashboard/
git mv marketplace/service_catalog_screen.dart providers/marketplace/
git mv marketplace/service_request_detail.dart providers/marketplace/
git mv whats_new/industry_packs_screen.dart providers/marketplace/
git mv legal/legal_acceptance_screen.dart providers/legal/
git mv extracted/legal_screens_v2.dart providers/legal/

echo "=== Eligibility & Compliance Group ==="
# (معظمها إما مشترك مع Audit أو فجوة)

echo "=== AI Settings (layer أفقي) ==="
git mv copilot/copilot_screen.dart ai_settings/copilot/
git mv v4_ai/ai_guardrails_screen.dart ai_settings/guardrails/
git mv knowledge/knowledge_brain_screen.dart ai_settings/knowledge/

echo "=== Platform ==="
git mv admin/admin_sub_screens.dart platform/admin/
git mv settings/enhanced_settings_screen.dart platform/admin/
git mv notifications/notification_detail_screen.dart platform/notifications/
git mv extracted/notification_screens_v2.dart platform/notifications/
git mv whats_new/white_label_settings_screen.dart platform/white_label/
git mv whats_new/theme_generator_screen.dart platform/white_label/
git mv whats_new/apex_map_screen.dart platform/white_label/

echo "=== Account ==="
git mv account/account_sub_screens.dart account/profile/
git mv account/archive_screen.dart account/profile/
git mv auth/slide_auth_screen.dart account/profile/
git mv auth/forgot_password_flow.dart account/profile/
git mv extracted/subscription_screens.dart account/subscriptions/
git mv extracted/client_screens.dart erp/sales_ar/  # hub screens

echo "=== Dev Only (demos, not in V4) ==="
git mv whats_new/apex_whats_new_hub.dart _dev/
git mv whats_new/feature_demos_screen.dart _dev/
git mv whats_new/syncfusion_grid_demo_screen.dart _dev/
git mv whats_new/sprint35_foundation_screen.dart _dev/
git mv whats_new/sprint37_experience_screen.dart _dev/
git mv whats_new/sprint38_composable_screen.dart _dev/
git mv whats_new/sprint42_longterm_screen.dart _dev/
git mv whats_new/sprint43_platform_screen.dart _dev/
git mv whats_new/onboarding_wizard_screen.dart _dev/
git mv showcase/apex_showcase_screen.dart _dev/

echo "=== Cleanup empty dirs ==="
rmdir --ignore-fail-on-non-empty \
  compliance/ audit/ simulation/ clients/ coa/ coa_v2/ \
  marketplace/ providers/ legal/ extracted/ admin/ settings/ \
  notifications/ whats_new/ showcase/ copilot/ knowledge/ \
  v4_erp/ v4_compliance/ v4_ai/ account/ auth/ tasks/ dashboard/ 2>/dev/null || true

echo "✓ Screen reorganization complete"
echo "  Total screens moved: ~85"
echo "  Run: flutter analyze"
```

---

## 7 · Risk Register (مع quantified mitigation)

| خطر | احتمال | أثر | Mitigation |
|---|---|---|---|
| تعارض في `app/main.py` على 50+ sطر | **عالي** | متوسط | Scripted union merge + manual review |
| `apex_app.dart` يفقد routes | متوسط | عالي | قبل cherry-pick: backup + smoke tests |
| 159 ملف يكسر الـ imports | متوسط | عالي | Batch-wise (4 batches) مع pytest بعد كل batch |
| Flutter build يفشل بعد reorganize | **عالي** | عالي | Git tags قبل كل subsection + fast rollback |
| الاختبارات تتعطّل بسبب model conflicts | متوسط | عالي | Consolidate models في Phase 2 (قبل الـ features) |
| الأداء يتدهور مع RLS على Postgres | منخفض | متوسط | Load test before Phase 5 |
| Apex components يكسرون ui_components القديمة | متوسط | متوسط | حافظ على ui_components.dart — مش استبدال |
| Wave 16 يبني على أساس غلط | منخفض (بعد الخطة) | عالي | لا تبدأ Wave 16 قبل مرحلة 6 تخلص |

---

## 8 · معايير النجاح (Success Criteria)

في نهاية تنفيذ V2:

### Backend
- [ ] `main` فيه 683 Python file منظّمين
- [ ] `pytest tests/` = ≥1400 pass, 0 fail
- [ ] كل V4 module له على الأقل backend service واحد
- [ ] ZATCA module موحّد (B-Y + P-L مدموجين)
- [ ] Multi-tenant RLS فعّال على كل الـ models
- [ ] AI Guardrails يحمي كل AI suggestion

### Frontend
- [ ] 46 apex component + 9 v4 component + ui_components.dart كلهم موجودين
- [ ] `flutter analyze` = 0 errors
- [ ] `flutter build web --release` = success تحت 60 ثانية
- [ ] الـ 6 V4 groups ظاهرين في `/app/launchpad`
- [ ] Ctrl+K يبحث في كل الـ 46 sub-module
- [ ] Live bell + Chatter يشتغلوا عبر WebSocket

### Architecture
- [ ] `lib/screens/` منظّم بالـ 6 V4 groups + layer أفقي
- [ ] `v4_routes.dart` فيه routes لكل شاشة wired
- [ ] الـ 120+ شاشة موزّعين حسب الخطة
- [ ] الفجوات موثّقة في backlog waves 17+

### Documentation
- [ ] `STATE_OF_APEX.md` محدّث بالأرقام الجديدة
- [ ] `CLAUDE.md` محدّث بالـ conventions
- [ ] `blueprints/APEX_V4_Module_Hierarchy.txt` فيه screen IDs موثّقة
- [ ] `INTEGRATION_PR_BODY.md` يلخّص الدمج

---

## 9 · Backlog بعد الدمج (Waves 17-35)

**الأولوية العالية** (4-6 waves):
- Wave 17: Purchasing & AP UI (RFQs/POs/Bills/Expense Claims)
- Wave 18: HR Complete (Org Chart/Contracts/Leaves/Attendance)
- Wave 19: CRM (Leads/Opportunities/Email Sync)
- Wave 20: Projects (Tasks/Timesheets/Milestones)
- Wave 21: Compliance — GOSI & WPS UI
- Wave 22: Compliance — Eligibility Check (SME/IPO/Tadawul)

**الأولوية المتوسطة** (6-8 waves):
- Wave 23-26: Feasibility Studies — 4 dashboards + Market/Setup/Risk/Final Report
- Wave 27-29: External Financial Analysis — Benchmarking/Credit/Reports
- Wave 30: Audit — Control Testing + Report Issuance + QC

**الأولوية المنخفضة** (5 waves):
- Wave 31-33: AML & KYC + Governance + Compliance Reports
- Wave 34: Provider Billing & Ratings
- Wave 35: 3 dashboard polish (Feasibility + External + Compliance)

---

## 10 · جدول التنفيذ المُنقّح

| اليوم | المرحلة | النتيجة المتوقعة |
|---|---|---|
| 1-4 | Phase 1 | main يحوي Wave 0-15 (merged) |
| 5 | Phase 2 | Integration branch + infrastructure |
| 6-9 | Phase 3 | Apex Layer + UI components (46) |
| 10-14 | Phase 4 | 159 backend files (4 batches) |
| 15-17 | Phase 5 | Screens reorganized (V4) |
| 18 | Phase 6 | Final PR + merge to main |

**المجموع: 18 يوم عمل** (≈ 4 أسابيع مع QA)

بعدها مباشرة Wave 16 ثم backlog.

---

## 11 · الخلاصة — ما الذي يتغيّر من V1 إلى V2

| الجانب | V1 (الخطة الأولى) | V2 (المنقّحة) |
|---|---|---|
| V4 module groups | 6 (ERP/Audit/AI/Marketplace/Platform/Account) ❌ | 6 (ERP/Audit/**Feasibility/External**/**Providers**/**Compliance**) ✅ |
| AI layer | module group منفصل ❌ | layer أفقي (⌘K/Chatter/Explain) ✅ |
| Apex components | 9 ❌ | 46 tactical + 9 v4 + 44 old ui ✅ |
| Backend modules | ~150 ❌ | 304 غير مكرّر (683 مع brave-yonath) ✅ |
| الفجوات | vague ❌ | 28 sub-module محدّدة + waves 17-35 ✅ |
| المسارات | 7 أدلّة ❌ | 10 أدلّة (6 V4 + AI + Platform + Account + Dev) ✅ |
| Feasibility/External | مدمجين في ERP ❌ | مجموعات مستقلّة (15 sub-module) ✅ |
| Multi-tenant + RLS | مرحلة 6 ❌ | مرحلة 2 (قبل الـ features) ✅ |
| عدد المراحل | 10 | 6 (مع batches) |
| مدة التنفيذ | 17 يوم | 18 يوم (+ 1 buffer) |

---

*هذه الخطة دقيقة حتى مستوى الـ commit SHA والـ file path. تُنفَّذ مرحلياً مع gates صارمة. كل مرحلة لها rollback مستقل.*

*Next step: ابدأ Phase 1 (دمج PRs brave-yonath) من GitHub UI.*
