# تصنيف كل الشاشات

> 4 فئات لكل شاشة — وفق ما اكتشفنا من 237 راوت + 351 ملف شاشة.

## مفتاح الفئات

| الرمز | الفئة | الإجراء |
|-------|------|---------|
| 🟢 | **KEEP** | احتفظ كما هو — Canonical + شغّال |
| 🔵 | **REFACTOR** | احتفظ لكن طوّر للحالة المثالية |
| 🟣 | **MERGE** | ادمج مع canonical (نفس الوظيفة، راوت مختلف) |
| 🟡 | **DEPRECATE** | redirect مؤقت — أرشفة بعد 30 يوم |
| 🔴 | **ARCHIVE** | للنقل لـ `_archive/` (يحتاج موافقتك) |
| ⚪ | **REVIEW** | يحتاج قرار منك (Demo/Experimental) |

---

## 🟢 KEEP — Canonical Routes (165 راوت)

### 1.1 Service Hubs (13 — كلها KEEP)

كل الـ hubs بتشغل نفس الـ `ApexServiceHubScreen` لكن بـ context مختلف. هي العمود الفقري للتنقّل.

| Path | Status |
|------|--------|
| `/sales`, `/purchase`, `/accounting`, `/operations`, `/compliance-hub`, `/audit-hub`, `/audit`, `/analytics`, `/hr`, `/hr-hub`, `/workflow`, `/workflow-hub`, `/settings-hub` | 🟢 KEEP all |

### 1.2 Main Entry Points

| Path | Screen | Status |
|------|--------|--------|
| `/app` | V5Launchpad | 🟢 KEEP — main entry |
| `/` | → `/app` | 🟢 KEEP — root redirect |
| `/services` | ApexServicesScreen | 🟢 KEEP |
| `/today` | TodayDashboardScreen | 🟢 KEEP |
| `/reports` | ReportsHubScreen | 🟢 KEEP |
| `/launchpad/full` | ApexLaunchpadScreen | 🔵 REFACTOR — power-user mode، يدمج مع `/app` بـ ?mode=full |

### 1.3 Authentication (3 — كلها KEEP)

| Path | Screen | Status |
|------|--------|--------|
| `/login` | SlideAuthScreen | 🟢 KEEP |
| `/register` | RegScreen | 🔵 REFACTOR — أضف AI Onboarding wizard |
| `/forgot-password` | ForgotPasswordScreen | 🟢 KEEP |

### 1.4 Compliance Suite — Canonical (23)

كلها 🟢 KEEP، ما عدا اللي هنذكره في القسم MERGE:

`/compliance`, `/compliance/audit-trail`, `/compliance/zatca-invoice`, `/compliance/zatca-invoice/:id`, `/compliance/zatca-status`, `/compliance/zakat`, `/compliance/vat-return`, `/compliance/ratios`, `/compliance/depreciation`, `/compliance/cashflow`, `/compliance/cashflow-statement`, `/compliance/amortization`, `/compliance/payroll`, `/compliance/breakeven`, `/compliance/investment`, `/compliance/working-capital`, `/compliance/executive`, `/compliance/ocr`, `/compliance/dscr`, `/compliance/valuation`, `/compliance/fx-converter`, `/compliance/financial-statements`, `/compliance/deferred-tax`, `/compliance/ifrs-tools`, `/compliance/transfer-pricing`, `/compliance/extras-tools`, `/compliance/tax-calendar`, `/compliance/tax-timeline`, `/compliance/audit-workflow-ai`, `/compliance/islamic-finance`, `/compliance/wht-v2`, `/compliance/consolidation-v2`, `/compliance/lease-v2`, `/compliance/activity-log-v2`, `/compliance/kyc-aml`, `/compliance/risk-register`

### 1.5 Accounting (4 — KEEP) + COA Workflow (8)

| Path | Status |
|------|--------|
| `/accounting/je-list` | 🟢 KEEP — canonical |
| `/accounting/coa-v2` | 🟢 KEEP — canonical |
| `/accounting/bank-rec-v2` | 🟢 KEEP — canonical |
| `/accounting/coa/edit` | 🟢 KEEP |
| `/coa/upload`, `/coa/mapping`, `/coa/quality`, `/coa/review`, `/coa/journey`, `/coa/financial-simulation`, `/coa/compliance-check`, `/coa/roadmap`, `/coa/trial-balance-check` | 🟢 KEEP all (COA pipeline) |
| `/tb/binding` | 🟢 KEEP |

### 1.6 Operations (12 — KEEP)

| Path | Status |
|------|--------|
| `/operations/universal-journal`, `/operations/period-close`, `/operations/pos-sessions`, `/operations/purchase-cycle`, `/operations/consolidation-ui`, `/operations/live-sales-cycle` | 🟢 KEEP |
| `/operations/customer-360/:id`, `/operations/vendor-360/:id` | 🟢 KEEP — parameterized |
| `/operations/inventory-v2`, `/operations/fixed-assets-v2` | 🟢 KEEP — canonical v2 |
| `/operations/petty-cash` | 🟢 KEEP |
| `/operations/stock-card`, `/operations/stock-card/:sku` | 🟢 KEEP — both (parameterized variant) |

### 1.7 Analytics (8 — كلها KEEP — كلها v2 canonical)

`/analytics/cash-flow-forecast`, `/analytics/budget-variance-v2`, `/analytics/multi-currency-v2`, `/analytics/health-score-v2`, `/analytics/investment-portfolio-v2`, `/analytics/project-profitability`, `/analytics/cost-variance-v2`, `/analytics/budget-builder` — 🟢 KEEP all

### 1.8 Sales (8 — KEEP) + Purchase (4 — KEEP) + HR (4 — KEEP)

كلها canonical، بدون مشاكل.

### 1.9 Admin (10) + Workflow (1)

| Path | Status |
|------|--------|
| `/admin/reviewer`, `/admin/providers/verify`, `/admin/providers/documents`, `/admin/providers/compliance`, `/admin/policies`, `/admin/audit`, `/admin/ai-console`, `/admin/audit-chain`, `/provider-kanban`, `/workflow/approvals` | 🟢 KEEP |
| `/admin/ai-suggestions` (v1) | 🟣 MERGE → `/admin/ai-suggestions-v2` |
| `/admin/ai-suggestions-v2` | 🟢 KEEP — canonical |

### 1.10 Account / Profile / Settings

| Path | Status |
|------|--------|
| `/profile/edit`, `/password/change`, `/account/close`, `/account/sessions`, `/account/mfa`, `/account/activity` | 🟢 KEEP |
| `/account` → `/settings/unified` | 🟡 DEPRECATE — keep redirect 30 days |
| `/settings/unified` | 🟢 KEEP — canonical |
| `/settings` (EnhancedSettingsScreen) | 🟣 MERGE → `/settings/unified` |
| `/settings/entities`, `/settings/bank-feeds` | 🟢 KEEP |

### 1.11 Notifications + Knowledge + Audit + Marketplace

كلها 🟢 KEEP:
- `/notifications`, `/notifications/prefs`, `/notifications/panel`
- `/knowledge-brain`, `/knowledge/feedback`, `/knowledge/console`, `/knowledge/search`, `/knowledge/feedback-form`
- `/audit/engagements`, `/audit/anomaly/:id`, `/audit-workflow`
- `/service-catalog`, `/marketplace/new-request`, `/clients`, `/client-detail`
- `/legal`, `/legal-acceptance`, `/compliance-detail`
- `/subscription`, `/plans/compare`, `/upgrade-plan`
- `/financial-ops`, `/financial-statements`, `/copilot`, `/dashboard`, `/archive`
- `/receipt/capture`, `/pos/quick-sale`, `/tasks/types`

---

## 🟣 MERGE — Duplicates (نفس الوظيفة، راوت مختلف)

### 18 مجموعة Duplicate

#### 1. Chart of Accounts (3 → 1)
- 🟢 **Canonical**: `/accounting/coa-v2`
- 🟣 MERGE: `/coa-tree`, `/accounting/coa`

#### 2. Bank Reconciliation (3 → 1)
- 🟢 **Canonical**: `/accounting/bank-rec-v2`
- 🟣 MERGE: `/compliance/bank-rec`, `/compliance/bank-rec-ai`

#### 3. Audit Engagement (5 → 1)
- 🟢 **Canonical**: `/audit/engagements`
- 🟣 MERGE: `/audit/engagement-workspace`, `/audit/benford`, `/audit/sampling`, `/audit/workpapers` → استخدم `?tab=` query param

#### 4. Financial Statements (BUG — معرّف مرتين!)
- 🐛 `/financial-statements` معرّف في **router.dart:610** و **router.dart:806**
- 🔴 **حلّه**: امسح الـ definition الأقدم، احتفظ بالـ parameterized version
- 🟣 MERGE: `/compliance/financial-statements`, `/accounting/trial-balance`, `/operations/financial-statements`

#### 5. Journal Entries (5 → 2)
- 🟢 **Canonical List**: `/accounting/je-list`
- 🟢 **Canonical Builder**: `/app/erp/finance/je-builder/new` و `/app/erp/finance/je-builder/:id`
- 🟣 MERGE: `/compliance/journal-entries`, `/compliance/journal-entry/:id`
- 🔵 REFACTOR: `/compliance/journal-entry-builder` — اعمل migrate لـ V5 builder

#### 6. Budget Variance (2 → 1)
- 🟢 **Canonical**: `/analytics/budget-variance-v2`
- 🟣 MERGE: `/compliance/budget-variance`

#### 7. Health Score (2 → 1)
- 🟢 **Canonical**: `/analytics/health-score-v2`
- 🟣 MERGE: `/compliance/health-score`

#### 8. Cost Variance (2 → 1)
- 🟢 **Canonical**: `/analytics/cost-variance-v2`
- 🟣 MERGE: `/compliance/cost-variance`

#### 9. Withholding Tax (2 → 1)
- 🟢 **Canonical**: `/compliance/wht-v2`
- 🟣 MERGE: `/compliance/wht`

#### 10. Consolidation (2 → 1)
- 🟢 **Canonical**: `/compliance/consolidation-v2`
- 🟣 MERGE: `/compliance/consolidation`

#### 11. Lease Schedule (2 → 1)
- 🟢 **Canonical**: `/compliance/lease-v2`
- 🟣 MERGE: `/compliance/lease`

#### 12. Inventory (2 → 1)
- 🟢 **Canonical**: `/operations/inventory-v2`
- 🟣 MERGE: `/compliance/inventory`

#### 13. Fixed Assets (2 → 1)
- 🟢 **Canonical**: `/operations/fixed-assets-v2`
- 🟣 MERGE: `/compliance/fixed-assets`

#### 14. AR Aging (2 → 1)
- 🟢 **Canonical**: `/sales/aging`
- 🟣 MERGE: `/compliance/aging`

#### 15. AI Suggestions (2 → 1)
- 🟢 **Canonical**: `/admin/ai-suggestions-v2`
- 🟣 MERGE: `/admin/ai-suggestions`

#### 16. Multi-Currency (2 → 1)
- 🟢 **Canonical**: `/analytics/multi-currency-v2`
- 🟣 MERGE: `/compliance/multi-currency`

#### 17. Settings (2 → 1)
- 🟢 **Canonical**: `/settings/unified`
- 🟣 MERGE: `/settings` (EnhancedSettingsScreen), `/account`, `/integrations`

#### 18. Entity Setup (4 → 1)
- 🟢 **Canonical**: `/settings/entities`
- 🟣 MERGE: `/clients/onboarding`, `/clients/new`, `/clients/create`, `/setup`, `/setup/entity`

---

## 🟡 DEPRECATE — Soft Deprecation

### 34 Redirect routes (موجودين بالفعل، نحوّلهم لـ deprecation)

كل الـ redirects دلوقتي بتشتغل بدون رسالة. الخطة:
1. أضف banner أعلى الصفحة المُعاد توجيهها: "🟡 هذه الشاشة منقولة لـ X — هتُحذف بعد 30 يوم"
2. سجّل كل زيارة في metrics
3. بعد 30 يوم بدون استخدام → 🔴 ARCHIVE

التفاصيل في [`02-archive-candidates.md`](02-archive-candidates.md).

---

## ⚪ REVIEW — Demo / Sprint / Experimental (27 شاشة)

دي محتاجة **قرارك** على كل واحدة:

### Sprint Demo Routes (9)

| Path | الحالة | الاقتراح |
|------|-------|----------|
| `/sprint35-foundation` | partial backend + UI | ⚪ راجع: لو الميزة في V5 shell → 🔴 ARCHIVE |
| `/sprint37-experience` | UI + mock | ⚪ راجع: مهم/جذاب للمبيعات؟ |
| `/sprint38-composable` | UI + backend | ⚪ راجع |
| `/sprint39-erp` | UI + backend | ⚪ راجع: هل في V5؟ |
| `/sprint40-payroll` | UI + mock | ⚪ راجع |
| `/sprint41-procurement` | UI + backend | ⚪ راجع |
| `/sprint42-longterm` | UI + mock | ⚪ راجع |
| `/sprint43-platform` | UI + backend | ⚪ راجع |
| `/sprint44-operations` | UI + backend | ⚪ راجع |

> **القاعدة المقترحة**: لو الميزة هاجرت لـ V5 shell → 🔴 ARCHIVE الـ sprint route. لو لسه مش متهجرة → 🟢 KEEP في `/whats-new`.

### Specialized Demos (15)

| Path | الحالة | الاقتراح |
|------|-------|----------|
| `/showcase` | Component demos | 🔵 REFACTOR — internal dev tool فقط |
| `/whats-new` | Hub للإطلاقات | 🟢 KEEP — مفيد للمستخدمين |
| `/uae-corp-tax` | Demo (mock) | 🔴 ARCHIVE لو في `/compliance/...` بديل |
| `/startup-metrics` | Demo (mock) | 🔴 ARCHIVE — لو غير مستخدم |
| `/industry-packs` | Demo (mock) | 🔵 REFACTOR — اربطه بـ Module Marketplace |
| `/apex-map` | Demo (map UI) | 🔴 ARCHIVE لو غير مستخدم |
| `/theme-generator` | Dev tool | 🔵 KEEP — internal admin only |
| `/white-label` | Dev tool | 🔵 KEEP — internal admin only |
| `/syncfusion-grid` | Component demo | 🔴 ARCHIVE — internal dev only |
| `/payments-playground` | Demo (mock) | 🔴 ARCHIVE — استبدل بحقيقي |
| `/ap-pipeline-demo` | Demo (mock) | 🔴 ARCHIVE |
| `/bank-ocr-demo` | Demo (mock) | 🔴 ARCHIVE — استبدل بحقيقي |
| `/gosi-demo` | Calculator demo | 🔵 REFACTOR — انقله لـ `/hr/gosi` |
| `/eosb-demo` | Calculator demo | 🔵 REFACTOR — انقله لـ `/hr/eosb` |
| `/whatsapp-demo` | Integration demo | 🔴 ARCHIVE — استبدل بـ `/admin/integrations/whatsapp` |

### Legacy Screens

| Path | الحالة | الاقتراح |
|------|-------|----------|
| `/home` (MainNav) | Legacy nav | 🔴 ARCHIVE — لو مفيش inbound links فعلية |
| `/dashboard` (EnhancedDashboard) | Legacy | 🔵 REFACTOR — ادمجه مع `/today` |

---

## 🔴 ARCHIVE Candidates — جاهزة للنقل (بعد موافقتك)

> القائمة الكاملة في [`02-archive-candidates.md`](02-archive-candidates.md) — كل عنصر مع السبب، البديل، الـ rollback.

**Quick summary:**

| الفئة | عدد الشاشات للأرشفة |
|------|---------------------|
| Duplicate v1 (legacy redirects) | 34 |
| Demo routes غير المستخدمة | 9-12 (حسب قرارك) |
| Sprint routes اللي اتهاجرت | 5-9 (حسب قرارك) |
| Orphaned screen files | TBD (يحتاج فحص متعمّق) |
| **Total مقترح** | **48-55 شاشة** |

---

## 🔵 REFACTOR — للحالة المثالية (16 شاشة)

شاشات شغّالة لكن محتاجة تطوير لتطابق الحالة المثالية:

| الشاشة | التطوير المقترح | المرجع |
|--------|------------------|--------|
| `/register` (RegScreen) | إضافة AI Onboarding Wizard | `02-target-state.md` §2 |
| `/launchpad/full` (ApexLaunchpadScreen) | دمج مع `/app` بـ ?mode=full | — |
| `/settings` (EnhancedSettingsScreen) | دمج في `/settings/unified` | — |
| `/dashboard` (EnhancedDashboard) | دمج في `/today` | — |
| `/showcase` | تقييد على Admin فقط | — |
| `/industry-packs` | ربط بـ Module Marketplace | `02-target-state.md` §8 |
| `/gosi-demo` → `/hr/gosi` | نقل لـ HR | — |
| `/eosb-demo` → `/hr/eosb` | نقل لـ HR | — |
| `/whatsapp-demo` → `/admin/integrations/whatsapp` | نقل لـ Admin | — |
| `/onboarding` (الحالي) | استبدل بـ AI Conversational Wizard | `02-target-state.md` §2 |
| `/marketplace/new-request` | إضافة Stripe Connect 3-mode | `02-target-state.md` §4 |
| `/admin/providers/verify` | ربط بـ ComplyAdvantage AML | `04-gap-analysis.md` P0 #2 |
| `/notifications` | إضافة قنوات: WhatsApp, Slack, Teams | `02-target-state.md` §7 |
| `/copilot` | إضافة Voice + Vision + Tool Calling | `02-target-state.md` §9 |
| `/coa/upload` | إضافة Migration Tool (QB/Xero/Zoho) | `02-target-state.md` §3 |
| `/settings/bank-feeds` | استبدل stub بـ Yodlee/Plaid | `04-gap-analysis.md` P1 #6 |

---

## مرجع أخير

- **🟢 KEEP**: 165 راوت (canonical, working)
- **🔵 REFACTOR**: 16 شاشة (تطوير، مش حذف)
- **🟣 MERGE**: 18 مجموعة → 18 canonical (إجمالي ~30 راوت يندمج)
- **🟡 DEPRECATE**: 34 redirect (يحوّل لـ banner لمدة 30 يوم)
- **🔴 ARCHIVE**: 48-55 شاشة (يحتاج موافقتك)
- **⚪ REVIEW**: 27 demo route (يحتاج قراراتك واحد واحد)
