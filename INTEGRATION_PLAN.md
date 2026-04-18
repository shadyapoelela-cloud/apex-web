# APEX — خطة الدمج التنفيذية الموحّدة

> **التاريخ:** 2026-04-18
> **النطاق:** دمج فرعي `brave-yonath` + `priceless-lamarr` + إعادة تنظيم الشاشات لـ V4
> **الغرض:** خطة خطوة-بخطوة، قابلة للتنفيذ، مع verification + rollback لكل مرحلة
> **الهدف النهائي:** فرع `main` موحّد يحتوي على:
> - 17 wave من brave-yonath (Security + ZATCA + Bank Feeds + AI Guardrails)
> - 50 commit من priceless-lamarr (Apex Layer + 159 Python file + ERP modules)
> - شاشات معاد تنظيمها على هيكل V4 (6 groups → 46 sub-modules → 240 screens)

---

## 0 · الواقع الحالي (Baseline)

### حالة الفروع

| الفرع | العدد | الحالة |
|---|---|---|
| `main` | baseline | نظيف، آخر commit قبل التفرّع |
| `claude/brave-yonath-wave-{0..15}` | 17 PR معلّق | مدفوعين، stacked (كل واحد base على السابق) |
| `claude/priceless-lamarr` | 50 commit ahead | مدفوع، branch موازٍ مستقل |

### الإحصائيات الدقيقة

| المقياس | brave-yonath | priceless-lamarr |
|---|---|---|
| commits ahead of main | 17 | 50 |
| ملفات Python جديدة | ~15 | **159** |
| ملفات test جديدة | ~200 اختبار جديد | **63 ملف test** |
| routers جديدة | 6 | **27** |
| Flutter components (lib/core/) | ~15 (v4_*.dart) | **46 (apex_*.dart)** |
| شاشات جديدة | 6 | **16** |
| main.py إضافات | +150 سطر | +727 سطر |

### مواضع التعارض المتوقعة (3 ملفات أساسية)

1. **`app/main.py`** — كلا الفرعين يضيف `include_router` لكنهم يضيفوا routers مختلفة (صفر overlap حقيقي)
2. **`apex_finance/lib/core/router.dart`** — priceless-lamarr يضيف 20+ import، brave-yonath يستخدم ملف `v4_routes.dart` منفصل (overlap محدود)
3. **`apex_finance/lib/app/apex_app.dart`** — كلاهما قد يضيف theme/routes

### تبعيات جديدة
- **requirements.txt**: لا إضافات كبيرة من priceless-lamarr (معظمها سابق)
- **pubspec.yaml**: `qr_flutter: ^4.1.0`, `syncfusion_flutter_datagrid: ^29.1.38`

---

## 1 · المبادئ الحاكمة للخطة

1. **الصغير قبل الكبير** — كل مرحلة PR صغير قابل للمراجعة والـ rollback
2. **Defensive قبل Feature** — الأمان والـ foundation قبل الميزات
3. **Backend قبل UI** — عشان UI يعرف يستدعي APIs صح
4. **Preserve tests** — ما نمرق مرحلة إلا لما ≥95% من الاختبارات تمر
5. **Atomic commits** — كل PR له غرض واحد قابل للوصف في سطر
6. **Rollback-friendly** — كل مرحلة لها fallback معروف

---

## 2 · الخطة — 10 مراحل

### المرحلة 1: دمج PRs brave-yonath المعلّقة (1-2 يوم)

**الهدف:** تفريغ الـ 17 PR المعلّقين على main → main يصبح فيه كل شغل waves 0-15.

**Prerequisites:**
- [ ] تأكد إن كل branch مدفوع: `git ls-remote origin | grep wave-`
- [ ] تأكد إن PR_INSTRUCTIONS.md يحوي نصوص 17 PR كاملة

**الخطوات (عبر GitHub UI):**

```
1. افتح: https://github.com/shadyapoelela-cloud/apex-web/pulls
2. لكل wave من 0 إلى 15 (بالترتيب):
   a. ادخل compare URL من PR_INSTRUCTIONS.md
   b. غيّر الـ base إلى "main" (لأنها stacked، default بيكون الـ wave اللي قبل)
   c. انسخ Title و Body من PR_INSTRUCTIONS.md
   d. اضغط "Create pull request"
   e. اضغط "Merge pull request" (بعد passing CI)
3. بعد دمج wave N، الـ wave N+1 هيـauto-update بتاعه الـ base إلى main
```

**Verification Gates:**
- [ ] بعد كل merge: `git pull origin main && pytest tests/ -x` → يمر
- [ ] بعد آخر merge: `pytest tests/` = 1133 pass / 2 skip / 0 fail
- [ ] `main` branch = 17 commits ahead of baseline

**Rollback:**
- لكل PR: `gh pr close {number}` + ما تعمل merge
- في الحالات القصوى: `git revert {merge-commit}` على main

**Output:**
- `main` فيه: Security hardening + 5 V4 screens + ZATCA pipeline + Bank Feeds + AI Guardrails + AI Bank Recon

---

### المرحلة 2: فرع التكامل الموحّد (نصف يوم)

**الهدف:** إنشاء فرع جديد `integration/unified-platform` كـ base للمراحل 3-9.

```bash
# في الـ repo الأصلي (مش worktree)
cd C:/apex_app
git checkout main
git pull origin main
git checkout -b integration/unified-platform
git push -u origin integration/unified-platform
```

**Verification:**
- [ ] `git log --oneline | head -5` = آخر 5 commits من main (Wave 15 + قبلها)
- [ ] `pytest tests/` = 1133 pass
- [ ] `cd apex_finance && flutter analyze` = clean

**Output:** فرع `integration/unified-platform` نظيف جاهز للـ cherry-picks.

---

### المرحلة 3: Foundation Fixes من priceless-lamarr (1 يوم)

**الهدف:** إضافة fixes 0.1 + 0.4 + 0.5 من Roadmap (Alembic صارم + env hard-checks + rate limit إنتاج).

**Commits to cherry-pick (بالترتيب):**
```bash
git cherry-pick 134ccd1  # Foundation fixes 0.1 + 0.4 + 0.5
git cherry-pick 2f906f2  # Replace social auth + SMS stubs (MAY CONFLICT with Wave 1)
git cherry-pick 0e012ad  # Production hard-checks + tiered rate limiting
git cherry-pick d477923  # Test lock-in for foundation fixes (15 passing)
```

**Expected conflicts:**
- `2f906f2` سيتعارض مع Wave 1 من brave-yonath (كلاهما يستبدل stubs) → **خد brave-yonath** (أعمق + أكثر اختباراً)
- `0e012ad` قد يتعارض جزئياً مع Wave 1 rate_limit_backend.py → **ادمج**: خد الـ Redis backend من brave-yonath + الـ tiered logic من priceless-lamarr

**Verification:**
- [ ] `pytest tests/test_auth.py tests/test_rate_limit*.py tests/test_env*.py` → pass
- [ ] `pytest tests/` ≥ 1145 pass (15 جديد)

**Rollback:**
```bash
git reset --hard integration/unified-platform~4  # يرجع الـ 4 cherry-picks
```

---

### المرحلة 4: Apex Shared Layer من priceless-lamarr (2-3 يوم)

**الهدف:** إضافة طبقة المكوّنات المشتركة (46 مكوّن apex_*.dart) وتطبيقها على الشاشات.

**Commits to cherry-pick:**
```bash
git cherry-pick d0a73c9  # 8 shared Flutter components + Saudi validators (BASE)
git cherry-pick 9c762d7  # Copilot memory + Notifications bridge + A11y + Bell + Voice
git cherry-pick b892575  # Governed AI + Webhooks + Dashboard Builder + Mobile Bottom Nav
git cherry-pick ea82ed6  # Cache + API v1 + saved views + Peppol + responsive + chatter
git cherry-pick 9f9a685  # Sprint 37-38 — app switcher + contextual toolbar + breadcrumbs
git cherry-pick 5bef1d8  # Sprint 38 — composable dashboard + notification center
git cherry-pick d368be8  # Theme generator (Linear-style)
git cherry-pick 7417753  # Wire ApexStickyToolbar onto 5 compliance screens
git cherry-pick 5ce64d5  # ApexAppBar adapter + convert 12 compliance screens
git cherry-pick 2db30e3  # Mass-convert 45 screens to ApexAppBar
git cherry-pick be01c9f  # Start wiring Apex Layer into real production screens
git cherry-pick 572d64f  # Apply Apex shared layer to Clients list + Showcase
```

**Expected conflicts:**
- `router.dart` و `apex_app.dart` — الإضافات تتراكم، حلها بالـ union
- أي تعديل على شاشة موجودة (compliance/*) — خد priceless-lamarr (الشاشات هي اللي متحوّلة)

**Verification:**
- [ ] `cd apex_finance && flutter analyze` → clean
- [ ] `flutter build web --release` → success
- [ ] تأكّد إن الـ 46 component موجودة: `ls apex_finance/lib/core/apex_*.dart | wc -l` = 46+
- [ ] Command Palette (Ctrl+K) يشتغل: `flutter run -d chrome` → الاختبار اليدوي

**Rollback:**
```bash
git reset --hard HEAD~12  # يرجع الـ 12 cherry-picks
```

---

### المرحلة 5: Backend Features من priceless-lamarr (2-3 يوم)

**الهدف:** إضافة 159 ملف Python backend (financial tools + IFRS + tax).

**Commits to cherry-pick (groups من commits):**

**5A. Financial calculators (15 يوم → 15 commits):**
```bash
git cherry-pick 3b5caa9  # Zakat + VAT (KSA/UAE/BH/OM)
git cherry-pick db175fb  # 18 financial ratios
git cherry-pick e8e8235  # Depreciation (SL/DDB/SYD)
git cherry-pick 029ad81  # Cash Flow (IAS 7) + Amortization
git cherry-pick 5cb53f0  # Payroll GOSI + Break-even
git cherry-pick 1f41afd  # NPV/IRR + Budget variance
git cherry-pick 235c652  # Bank Rec + Inventory + Aging
git cherry-pick 97a0330  # Working Capital + Health Score
git cherry-pick 16173da  # OCR invoice extraction
git cherry-pick a520f7e  # DSCR + WACC + DCF
git cherry-pick 7bc31eb  # JE Builder + Multi-currency FX
git cherry-pick 8f2f913  # Variance Analysis (Material/Labour/Overhead)
git cherry-pick a9a06a6  # Financial Statements + period close
git cherry-pick 0bd02a9  # Full Cash Flow Statement (IAS 7 indirect)
git cherry-pick f906585  # WHT calculator + batch
```

**5B. IFRS & Advanced Tax (5 commits):**
```bash
git cherry-pick a0d6a84  # IFRS 10/12/16 (Consolidation + DT + Lease)
git cherry-pick 8367501  # IFRS 15/19/36/9/37 + Fixed Assets
git cherry-pick 4815162  # Transfer Pricing (BEPS 13 + KSA TP Bylaws)
git cherry-pick d597a76  # IFRS 2/40/41 + RETT + Pillar Two + VAT Group + Job Costing
git cherry-pick 09b172a  # Extras Tools Suite (35-tool hub)
```

**5C. Integrations (5 commits):**
```bash
git cherry-pick f065939  # Q1 regional (ZATCA + WhatsApp + UAE FTA + HR + Cmd+K)
git cherry-pick af3b5cd  # Bank OCR + multi-tenant + AP agent scaffolds
git cherry-pick 9256c37  # WPS/EOSB + GCC payments + Open Banking + Industry Packs
git cherry-pick ea1c3cd  # Wire HR/AP models, tenant middleware, WhatsApp webhook
git cherry-pick 32f430e  # HR REST routes + PDF parser + AP processors + Copilot Agent
```

**Expected conflicts:**
- `app/main.py` كل cherry-pick → ادمج بالـ union (add include_router بدون حذف)
- `app/core/compliance_models.py` — قد يتعارض مع brave-yonath's Wave 11 CSID models → **ادمج** (أضف الجداول لكل فرع)
- `app/core/zatca_routes.py` — تعارض محتمل مع Wave 8 error translator و Wave 11 CSID → **الأفضل: خد من priceless-lamarr + ضيف endpoints الخاصة بـ brave-yonath**

**Verification:**
- [ ] `pytest tests/` ≥ 1250 pass
- [ ] `curl http://localhost:8000/health` → 200
- [ ] `curl http://localhost:8000/api/docs` → يعرض الـ endpoints الجديدة

**Rollback:**
```bash
git tag backup-before-5  # قبل البدء
git reset --hard backup-before-5  # لو فشل
```

---

### المرحلة 6: Backend Infrastructure من priceless-lamarr (1-2 يوم)

**الهدف:** Multi-tenant + RLS + WebSocket + Cache + Cursor pagination.

**Commits to cherry-pick:**
```bash
git cherry-pick c170e06  # Multi-tenant query guard
git cherry-pick 69e483d  # Tenant RLS + cursor pagination + audit + WS
git cherry-pick fcc253b  # PostgreSQL Row-Level Security policies
git cherry-pick f37ef3c  # Alembic migration for q1_2026 tables
git cherry-pick 67aeba6  # Realtime WebSocket push from activity_log
git cherry-pick 186a670  # Flutter WebSocket client + live Chatter + Bell
git cherry-pick 64e5aaa  # Auto_log SQLAlchemy listener
git cherry-pick 072d76c  # Global live bell in toolbar + proactive scanner
git cherry-pick a4b233c  # Background scheduler (proactive scans every 6h)
git cherry-pick 2e92515  # Notifications list API + bootstrap Bell
git cherry-pick e1cda40  # Reports download + system health endpoints
```

**Expected conflicts:**
- `app/core/auth_utils.py` (من cherry-pick سابق) + `app/core/tenant_*.py` جديد → ادمج
- Alembic migration — قد تتعارض مع Wave 10's fix → خد الفكس من brave-yonath + ضيف migration جديدة من priceless-lamarr

**Verification:**
- [ ] `pytest tests/test_tenant_guard.py tests/test_rls_session_hook.py tests/test_websocket_hub.py` → pass
- [ ] الـ multi-tenant isolation: `pytest tests/ -k "tenant"` → ≥20 pass
- [ ] WebSocket: افتح Flutter + backend، تأكّد الـ live bell يشتغل

---

### المرحلة 7: AI Copilot Enhancements (1 يوم)

**الهدف:** Copilot memory + voice + 4 new tools + governed AI.

```bash
git cherry-pick 9c762d7  # Copilot memory + Notifications bridge + Python SDK + A11y + Bell + Voice (قد يكون اتعمل في مرحلة 4)
git cherry-pick 69f7d08  # 4 new Copilot tools (invoice/reminder/report/categorize)
git cherry-pick 83b934f  # Dimensional Accounting + Intercompany + Corporate Cards + FCL + Node SDK
```

**Verification:**
- [ ] `pytest tests/test_new_integrations.py` → pass
- [ ] `curl -X POST http://localhost:8000/copilot/tools/create_invoice -d '{...}'` → works

---

### المرحلة 8: Sprints 35-44 Screens (1-2 يوم)

**الهدف:** إضافة 16 شاشة `whats_new/*` + خريطة APEX.

**Commits to cherry-pick:**
```bash
git cherry-pick 59c9523  # Sprint 35-36 foundation — Alt+1..9 + inline edit + PWA
git cherry-pick f1505c9  # Sprint 35-36 — saved views + recent items + live validation
git cherry-pick 9f9a685  # Sprint 37-38 (قد يكون اتعمل في مرحلة 4)
git cherry-pick 5bef1d8  # Sprint 38 composable dashboard (قد يكون اتعمل)
git cherry-pick c5dc459  # Sprint 39-40 — HR + CRM Kanban + Workflow automation
git cherry-pick 076dbd5  # Sprint 40 — Payroll (GOSI+WPS) + Custom Report Builder
git cherry-pick afc4eb2  # Sprint 41 — Barcode Inventory + 3-Way Match
git cherry-pick 0877b95  # Sprint 42 — AI Cashflow + Consolidation + BOM
git cherry-pick 8bb6aa6  # Sprint 43 — Marketplace + White-Label + WCAG AA
git cherry-pick 44755c5  # Sprint 44 — Manufacturing Work Orders + Gantt
git cherry-pick f2bf7f1  # Mobile polish + /apex-map + MOBILE_BUILD guide
```

**Expected conflicts:**
- `router.dart` — الإضافات الجديدة → union
- `apex_whats_new_hub.dart` — ملف جديد، zero conflict

**Verification:**
- [ ] `flutter run -d chrome` → افتح `/#/whats-new` → تظهر كل الشاشات
- [ ] `flutter build web` → success
- [ ] `flutter analyze` → clean

---

### المرحلة 9: إعادة تنظيم الشاشات لـ V4 (2-3 يوم)

**الهدف:** نقل كل الـ 96 شاشة إلى هيكل V4 الجديد.

### 9A. إنشاء الهيكل الجديد

```bash
cd apex_finance/lib/screens
mkdir -p erp/{dashboard,general_ledger,sales_ar,purchasing_ap,inventory,treasury,hr_payroll,projects,crm,zatca_tax,reports}
mkdir -p audit_review/{dashboard,planning,risk,workpapers,analytics,fixed_assets,simulation}
mkdir -p ai_copilot/{copilot,guardrails,knowledge}
mkdir -p marketplace_group/{catalog,providers,industry_packs}
mkdir -p platform/{white_label,admin,notifications}
mkdir -p account_group/{profile,legal,subscriptions}
mkdir -p _dev  # للـ demos فقط
```

### 9B. نقل الشاشات (script)

أنشئ `scripts/reorganize_screens.sh`:

```bash
#!/bin/bash
set -e

# ERP — General Ledger
git mv screens/compliance/journal_entries_screen.dart screens/erp/general_ledger/
git mv screens/compliance/journal_entry_builder_screen.dart screens/erp/general_ledger/
git mv screens/coa/coa_tree_screen.dart screens/erp/general_ledger/
git mv screens/coa_v2/coa_journey_screen.dart screens/erp/general_ledger/
git mv screens/simulation/trial_balance_screen.dart screens/erp/general_ledger/
git mv screens/compliance/fin_statements_screen.dart screens/erp/general_ledger/
git mv screens/compliance/cashflow_statement_screen.dart screens/erp/general_ledger/
git mv screens/compliance/consolidation_screen.dart screens/erp/general_ledger/

# ERP — Sales & AR
git mv screens/v4_erp/sales_customers_screen.dart screens/erp/sales_ar/
git mv screens/clients/client_detail_screen.dart screens/erp/sales_ar/
git mv screens/clients/client_onboarding_wizard.dart screens/erp/sales_ar/
git mv screens/compliance/aging_screen.dart screens/erp/sales_ar/

# ERP — Purchasing & AP
git mv screens/whats_new/sprint41_procurement_screen.dart screens/erp/purchasing_ap/

# ERP — Inventory
git mv screens/compliance/inventory_screen.dart screens/erp/inventory/

# ERP — Treasury
git mv screens/v4_erp/bank_feeds_screen.dart screens/erp/treasury/
git mv screens/compliance/bank_rec_screen.dart screens/erp/treasury/
git mv screens/compliance/fx_converter_screen.dart screens/erp/treasury/
git mv screens/compliance/cashflow_screen.dart screens/erp/treasury/
# ai_bank_reconciliation_screen (Wave 16) سينضاف هنا

# ERP — HR & Payroll
git mv screens/compliance/payroll_screen.dart screens/erp/hr_payroll/
git mv screens/whats_new/sprint40_payroll_reports_screen.dart screens/erp/hr_payroll/
git mv screens/whats_new/sprint39_erp_screen.dart screens/erp/hr_payroll/

# ERP — Projects
git mv screens/whats_new/sprint44_operations_screen.dart screens/erp/projects/
git mv screens/tasks/audit_service_screen.dart screens/erp/projects/

# ERP — CRM
git mv screens/providers/provider_kanban_screen.dart screens/erp/crm/
git mv screens/marketplace/service_catalog_screen.dart screens/marketplace_group/catalog/

# ERP — ZATCA & Tax
git mv screens/compliance/zatca_invoice_builder_screen.dart screens/erp/zatca_tax/
git mv screens/v4_compliance/zatca_csid_screen.dart screens/erp/zatca_tax/
git mv screens/v4_compliance/zatca_queue_screen.dart screens/erp/zatca_tax/
git mv screens/compliance/zakat_calculator_screen.dart screens/erp/zatca_tax/
git mv screens/compliance/vat_return_screen.dart screens/erp/zatca_tax/
git mv screens/compliance/wht_screen.dart screens/erp/zatca_tax/
git mv screens/whats_new/uae_corp_tax_screen.dart screens/erp/zatca_tax/
git mv screens/compliance/transfer_pricing_screen.dart screens/erp/zatca_tax/
git mv screens/compliance/deferred_tax_screen.dart screens/erp/zatca_tax/

# ERP — Reports
git mv screens/dashboard/enhanced_dashboard.dart screens/erp/reports/
git mv screens/compliance/executive_dashboard_screen.dart screens/erp/reports/
git mv screens/whats_new/startup_metrics_screen.dart screens/erp/reports/
git mv screens/compliance/health_score_screen.dart screens/erp/reports/
git mv screens/compliance/financial_ratios_screen.dart screens/erp/reports/
git mv screens/compliance/budget_variance_screen.dart screens/erp/reports/
git mv screens/compliance/cost_variance_screen.dart screens/erp/reports/
git mv screens/compliance/extras_tools_screen.dart screens/erp/reports/
git mv screens/compliance/ifrs_tools_screen.dart screens/erp/reports/

# Audit & Review
git mv screens/compliance/compliance_hub_screen.dart screens/audit_review/dashboard/
git mv screens/compliance/compliance_health_widget.dart screens/audit_review/dashboard/
git mv screens/audit/audit_workflow_screen.dart screens/audit_review/planning/
git mv screens/simulation/roadmap_screen.dart screens/audit_review/planning/
git mv screens/v4_compliance/compliance_status_screen.dart screens/audit_review/risk/
git mv screens/simulation/compliance_check_screen.dart screens/audit_review/risk/
git mv screens/compliance/audit_trail_screen.dart screens/audit_review/workpapers/
git mv screens/compliance/working_capital_screen.dart screens/audit_review/analytics/
git mv screens/compliance/dscr_screen.dart screens/audit_review/analytics/
git mv screens/compliance/valuation_screen.dart screens/audit_review/analytics/
git mv screens/compliance/investment_screen.dart screens/audit_review/analytics/
git mv screens/compliance/fixed_assets_screen.dart screens/audit_review/fixed_assets/
git mv screens/compliance/depreciation_screen.dart screens/audit_review/fixed_assets/
git mv screens/compliance/amortization_screen.dart screens/audit_review/fixed_assets/
git mv screens/compliance/lease_screen.dart screens/audit_review/fixed_assets/
git mv screens/compliance/breakeven_screen.dart screens/audit_review/fixed_assets/
git mv screens/compliance/ocr_screen.dart screens/audit_review/fixed_assets/
git mv screens/simulation/financial_simulation_screen.dart screens/audit_review/simulation/

# AI & Copilot
git mv screens/copilot/copilot_screen.dart screens/ai_copilot/copilot/
git mv screens/v4_ai/ai_guardrails_screen.dart screens/ai_copilot/guardrails/
git mv screens/knowledge/knowledge_brain_screen.dart screens/ai_copilot/knowledge/

# Marketplace
git mv screens/marketplace/service_request_detail.dart screens/marketplace_group/catalog/
git mv screens/providers/provider_profile_screen.dart screens/marketplace_group/providers/
git mv screens/whats_new/industry_packs_screen.dart screens/marketplace_group/industry_packs/

# Platform
git mv screens/whats_new/white_label_settings_screen.dart screens/platform/white_label/
git mv screens/whats_new/theme_generator_screen.dart screens/platform/white_label/
git mv screens/whats_new/apex_map_screen.dart screens/platform/white_label/
git mv screens/admin/admin_sub_screens.dart screens/platform/admin/
git mv screens/settings/enhanced_settings_screen.dart screens/platform/admin/
git mv screens/notifications/notification_detail_screen.dart screens/platform/notifications/
git mv screens/extracted/notification_screens_v2.dart screens/platform/notifications/

# Account
git mv screens/account/account_sub_screens.dart screens/account_group/profile/
git mv screens/account/archive_screen.dart screens/account_group/profile/
git mv screens/auth/slide_auth_screen.dart screens/account_group/profile/
git mv screens/auth/forgot_password_flow.dart screens/account_group/profile/
git mv screens/legal/legal_acceptance_screen.dart screens/account_group/legal/
git mv screens/extracted/legal_screens_v2.dart screens/account_group/legal/
git mv screens/extracted/subscription_screens.dart screens/account_group/subscriptions/
git mv screens/extracted/client_screens.dart screens/erp/sales_ar/

# Dev only (not in V4)
git mv screens/whats_new/apex_whats_new_hub.dart screens/_dev/
git mv screens/whats_new/feature_demos_screen.dart screens/_dev/
git mv screens/whats_new/syncfusion_grid_demo_screen.dart screens/_dev/
git mv screens/whats_new/sprint35_foundation_screen.dart screens/_dev/
git mv screens/whats_new/sprint37_experience_screen.dart screens/_dev/
git mv screens/whats_new/sprint38_composable_screen.dart screens/_dev/
git mv screens/whats_new/sprint42_longterm_screen.dart screens/_dev/
git mv screens/whats_new/sprint43_platform_screen.dart screens/_dev/
git mv screens/whats_new/onboarding_wizard_screen.dart screens/_dev/
git mv screens/showcase/apex_showcase_screen.dart screens/_dev/

# Shared stays
# screens/shared/ — no move

echo "✓ Screen reorganization complete"
```

### 9C. تحديث imports

```bash
# أداة auto-fix للـ imports بعد النقل
cd apex_finance
dart run tool/fix_imports.dart  # سنكتب الأداة لو احتاج

# أو يدوياً:
grep -rn "import.*screens/compliance" lib/ | awk -F: '{print $1}' | sort -u | \
  xargs sed -i 's|screens/compliance/|screens/audit_review/analytics/|g'
# (على حسب الملف)
```

### 9D. تحديث router.dart + v4_routes.dart

```dart
// apex_finance/lib/core/router.dart
// استبدل الـ imports القديمة بالمسارات الجديدة
import '../screens/erp/treasury/bank_feeds_screen.dart';
// إلخ...
```

**Verification:**
- [ ] `flutter analyze` → clean (0 errors)
- [ ] `flutter test` → all pass
- [ ] `flutter build web` → success
- [ ] Manual QA: افتح كل V4 group → كل screen تفتح
- [ ] كل شاشة تـload بدون errors في الـ console

**Rollback:**
```bash
git reset --hard HEAD~1  # قبل الـ reorganize
```

---

### المرحلة 10: الاختبار الشامل + الدمج على main (يوم)

**الهدف:** التأكد إن الـ integration branch مستقر ثم دمجه.

**Checks:**
```bash
# Backend
pytest tests/ -v --tb=short
# Target: ≥1400 pass, 0 fail

# Flutter
cd apex_finance
flutter analyze
flutter test
flutter build web --release

# Manual QA checklist
# [ ] login
# [ ] كل V4 group يفتح
# [ ] الـ launchpad يظهر صح
# [ ] Command Palette (Ctrl+K) يشتغل
# [ ] Bank Feeds UI تـload transactions
# [ ] AI Guardrails UI تـload suggestions
# [ ] Theme generator يشتغل
# [ ] Sprint screens تـload من /whats-new/*
```

**الدمج:**
```bash
git push origin integration/unified-platform
gh pr create --base main --head integration/unified-platform \
  --title "Unified Platform Integration — brave-yonath + priceless-lamarr + V4 reorganization" \
  --body-file INTEGRATION_PR_BODY.md

# بعد CI pass:
# merge via GitHub UI (squash مش موصى به - preserve history)
```

---

## 3 · الفجوات (بعد الدمج) — Gaps to Fill

هذه أقسام V4 لا تزال بدون شاشات كاملة وستحتاج waves جديدة:

| V4 Sub-Module | الفجوة | اقتراح Wave |
|---|---|---|
| 2.4 Purchasing & AP | RFQs, POs, Vendor Bills, Expense Claims | Wave 16-18 |
| 2.7 HR & Payroll | Org Chart, Contracts, Leaves, GOSI Submissions, Mudad | Wave 19-22 |
| 2.8 Projects | Tasks, Timesheets, Budgets, Resource Allocation | Wave 23-25 |
| 2.9 CRM | Leads, Opportunities, Email Sync, Lead Scoring AI | Wave 26-28 |
| 2.10 ZATCA & Tax | Fatoora Submissions, Credit/Debit Notes (UI) | Wave 29 |
| 3.x Audit | Risk Linkage, Analytics, Roll-Forward | Wave 30-32 |

---

## 4 · Risk Register

| خطر | احتمال | أثر | تخفيف |
|---|---|---|---|
| تعارض كبير في main.py | عالي | متوسط | المراحل الصغيرة + union merges |
| Flutter build يفشل بعد reorganize | متوسط | عالي | Commit قبل كل dir move + rollback سريع |
| الاختبارات تفشل بسبب تعارض في models | متوسط | عالي | تشغيل pytest بعد كل cherry-pick |
| أداء backend يتدهور مع RLS | منخفض | متوسط | Benchmarking قبل الدمج النهائي |
| Router.dart يصبح فوضوي (60+ route) | عالي | منخفض | حله عبر V4 registry (موجود) |
| Cherry-pick يكسر trees | متوسط | متوسط | `git tag` قبل كل مرحلة + clean branch |

---

## 5 · جدول التنفيذ المقترح

| اليوم | المرحلة | النتيجة |
|---|---|---|
| 1 | 1 | 17 PR merged إلى main |
| 2 | 2 + 3 | Integration branch + Foundation fixes |
| 3-5 | 4 | Apex Shared Layer (46 component) |
| 6-8 | 5 | Backend features (159 file) |
| 9-10 | 6 | Multi-tenant + RLS + WebSocket |
| 11 | 7 | Copilot enhancements |
| 12-13 | 8 | Sprints 35-44 screens |
| 14-16 | 9 | Screens reorganization |
| 17 | 10 | Final testing + merge to main |

**المجموع: 17 يوم عمل (≈ 3.5 أسبوع)**

---

## 6 · Wave 16 — ما بعد الدمج

بعد ما الدمج يكتمل، `main` يحتوي على:
- كل security/ZATCA/AI من brave-yonath
- كل الـ 46 Apex component + 159 backend file من priceless-lamarr
- الشاشات في هيكل V4 جديد

**Wave 16 يبني AI Bank Reconciliation UI** على الأساس الموحّد:
- يستخدم ApexDataTable من priceless-lamarr
- يستدعي `/bank-rec/propose` من brave-yonath Wave 15
- يظهر تحت `screens/erp/treasury/ai_bank_reconciliation_screen.dart`

**ثم Wave 17+** يبدأ ملء الفجوات (HR → Purchasing → CRM → Projects).

---

## 7 · ملاحظات عملية

1. **Worktree management:** بعد الدمج، امسح الـ worktrees الـ orphaned:
   ```bash
   git worktree list
   git worktree remove C:/apex_app/.claude/worktrees/priceless-lamarr
   # لكن احتفظ بالـ branch في origin حتى ينجح الدمج
   ```

2. **Documentation:** خلال مراحل 3-9 حدّث:
   - `CLAUDE.md` — إضافة conventions جديدة من priceless-lamarr
   - `blueprints/APEX_V4_Module_Hierarchy.txt` — توثيق الـ screens المتنقّلة
   - `STATE_OF_APEX.md` — تحديث الأرقام (screens, tests, modules)

3. **Git hygiene:** لكل cherry-pick استخدم `-x` للحفاظ على reference:
   ```bash
   git cherry-pick -x {commit}
   ```

4. **Testing cadence:** شغّل `pytest` بعد كل commit group (مش كل commit) عشان السرعة.

5. **Build artifacts:** لا تـcommit `apex_finance/build/` — تأكّد إنها في `.gitignore`.

---

## 8 · معايير النجاح (Success Criteria)

في نهاية تنفيذ الخطة، لازم يكون:

- [ ] `main` يحتوي على كل شغل الفرعين (67 commit تقريباً)
- [ ] `pytest tests/` = ≥1400 pass، 0 fail
- [ ] `flutter analyze` = clean
- [ ] `flutter build web` = success
- [ ] كل V4 sub-module له على الأقل شاشة واحدة wired
- [ ] الشاشات الـ96 موجودة في الهيكل الجديد
- [ ] `git worktree list` = فقط brave-yonath و main (priceless-lamarr مؤرشف)
- [ ] جاهز لبدء Wave 16 على أساس موحّد

---

*هذه الوثيقة تُحدَّث بعد كل مرحلة — ضع ✓ بجانب المراحل المكتملة.*
