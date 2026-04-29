# قائمة المراجعة قبل الأرشفة

> **هذه قائمة مراجعة. لن يحدث أي حذف أو نقل قبل موافقتك على كل عنصر.**

## كيفية الاستخدام

1. اقرأ كل عنصر — لكل واحد: السبب، البديل، إلى أين تذهب الـ inbound links
2. علّم بأحد الرموز:
   - ✅ **موافق على الأرشفة**
   - ⏸️ **انتظر — لسه محتاج**
   - 🔄 **REFACTOR — احتفظ لكن طوّر**
   - ❌ **رفض — ابقَ كما هو**
3. أرسل لي القائمة المعتمدة → أنفّذ المرحلة 5 (نقل لـ `lib/screens/_archive/`)

---

## الفئة A: Legacy Redirects (34 راوت — أمان عالي للأرشفة)

### A1. COA Legacy (3 paths)

| Path | Screen File | Inbound Links | البديل | Notes |
|------|------------|---------------|--------|-------|
| `/coa-tree` | `lib/screens/coa_tree_screen.dart` | لا توجد links مباشرة (redirected only) | `/accounting/coa-v2` | ⏸️ موافق ☐ |
| `/accounting/coa` | redirect (no file) | redirected from compliance hub | `/accounting/coa-v2` | ⏸️ موافق ☐ |

**الإجراء المقترح**: امسح الـ redirect مع redirect HTTP 301 من الـ frontend router.

---

### A2. Bank Reconciliation Legacy (2 paths)

| Path | Screen File | Inbound Links | البديل | Notes |
|------|------------|---------------|--------|-------|
| `/compliance/bank-rec` | redirect (no file) | sidebar في compliance hub | `/accounting/bank-rec-v2` | موافق ☐ |
| `/compliance/bank-rec-ai` | `lib/screens/compliance/bank_rec_ai_screen.dart` | غير موصول حالياً | `/accounting/bank-rec-v2` | موافق ☐ |

---

### A3. Audit Engagement Aliases (4 paths → 1 with ?tab=)

| Path | Screen | الإجراء |
|------|-------|--------|
| `/audit/engagements` | AuditEngagementWorkspaceScreen | 🟢 KEEP |
| `/audit/engagement-workspace` | نفس الشاشة | 🟣 redirect → `/audit/engagements` |
| `/audit/benford` | نفس الشاشة | 🟣 redirect → `/audit/engagements?tab=benford` |
| `/audit/sampling` | نفس الشاشة | 🟣 redirect → `/audit/engagements?tab=sampling` |
| `/audit/workpapers` | نفس الشاشة | 🟣 redirect → `/audit/engagements?tab=workpapers` |

**ملاحظة**: ده consolidation مش archive — الشاشة واحدة، الراوتس بس بتتجمع.

---

### A4. Financial Statements Bug + Aliases (5 paths)

| Path | المشكلة | الحل |
|------|---------|------|
| `/financial-statements` (router.dart:610) | 🐛 معرّف مرتين (Bug!) | احذف الـ definition الأقدم |
| `/financial-statements` (router.dart:806) | معرّف مرة ثانية مع params | 🟢 KEEP — Canonical |
| `/compliance/financial-statements` | duplicate | 🟣 redirect → `/financial-statements` |
| `/accounting/trial-balance` | redirect قديم | 🟣 redirect → `/financial-statements?view=tb` |
| `/operations/financial-statements` | redirect قديم | 🟣 redirect → `/financial-statements` |

**الإجراء**: تصليح الـ bug أولاً (Stage 1)، ثم consolidation.

---

### A5. JE Legacy (3 paths)

| Path | الحالة | الإجراء |
|------|-------|---------|
| `/compliance/journal-entries` | redirect → `/accounting/je-list` | 🟡 احتفظ بالـ redirect لـ 30 يوم |
| `/compliance/journal-entry/:id` | redirect → `/app/erp/finance/je-builder/:id` | 🟡 احتفظ بالـ redirect لـ 30 يوم |
| `/compliance/journal-entry-builder` | شاشة منفصلة `JournalEntryBuilderScreen` | 🔵 REFACTOR — هاجر للـ V5 builder ثم archive |

موافق على أرشفة `/compliance/journal-entry-builder` بعد التهجير؟ ☐

---

### A6. v1→v2 Compliance Migrations (8 paths — كلها safe)

كل اللي تحت دلوقتي **redirect فقط** — مفيش screen file:

| من | إلى |
|---|-----|
| `/compliance/budget-variance` | `/analytics/budget-variance-v2` |
| `/compliance/health-score` | `/analytics/health-score-v2` |
| `/compliance/cost-variance` | `/analytics/cost-variance-v2` |
| `/compliance/wht` | `/compliance/wht-v2` |
| `/compliance/consolidation` | `/compliance/consolidation-v2` |
| `/compliance/lease` | `/compliance/lease-v2` |
| `/compliance/inventory` | `/operations/inventory-v2` |
| `/compliance/fixed-assets` | `/operations/fixed-assets-v2` |
| `/compliance/aging` | `/sales/aging` |
| `/compliance/multi-currency` | `/analytics/multi-currency-v2` |
| `/compliance/depreciation-ai` | `/compliance/depreciation` |

**الإجراء**: احتفظ بالـ redirects 30 يوم (للـ external bookmarks)، ثم احذفهم.

موافق على المسار ده؟ ☐

---

### A7. Settings Legacy (5 paths)

| Path | الحالة | الإجراء |
|------|-------|---------|
| `/settings` | EnhancedSettingsScreen — قديم | 🟣 MERGE في `/settings/unified` ثم 🔴 ARCHIVE |
| `/account` | redirect → `/settings/unified` | 🟡 احتفظ 30 يوم |
| `/integrations` | redirect → `/settings/unified` | 🟡 احتفظ 30 يوم |
| `/setup` | redirect → `/settings/entities` | 🟡 احتفظ 30 يوم |
| `/setup/entity` | redirect → `/settings/entities` | 🟡 احتفظ 30 يوم |

**`/settings` (EnhancedSettingsScreen)** هي الوحيدة فيها شاشة منفصلة — موافق على أرشفتها بعد التأكد إن `/settings/unified` فيها كل اللي فيها؟ ☐

---

### A8. Client Onboarding Legacy (3 paths — كلها redirects)

| Path | إلى |
|------|-----|
| `/clients/onboarding` | `/settings/entities?action=new-company` |
| `/clients/new` | `/settings/entities?action=new-company` |
| `/clients/create` | `/settings/entities?action=new-company` |

كلها redirects بدون screen files. موافق على أرشفتها بعد 30 يوم؟ ☐

---

## الفئة B: Demo Screens (15 شاشة — تحتاج قراراتك)

### B1. Old Demos (مرشّحة قوياً للأرشفة)

| Path | الملف | الحالة | الاقتراح | موافق؟ |
|------|------|-------|----------|--------|
| `/syncfusion-grid` | SyncfusionGridDemoScreen | Internal dev demo | 🔴 ARCHIVE — مش للمستخدم النهائي | ☐ |
| `/payments-playground` | PaymentsPlaygroundScreen | Mock payments | 🔴 ARCHIVE — استبدل بحقيقي | ☐ |
| `/ap-pipeline-demo` | ApPipelineScreen | Mock pipeline | 🔴 ARCHIVE — استبدل بحقيقي | ☐ |
| `/bank-ocr-demo` | BankOcrDemoScreen | Mock OCR | 🔴 ARCHIVE — استبدل بـ real OCR | ☐ |
| `/whatsapp-demo` | WhatsAppDemoScreen | Mock integration | 🔴 ARCHIVE — استبدل بـ real WhatsApp | ☐ |
| `/apex-map` | ApexMapScreen | Map visualization demo | 🔴 ARCHIVE — مش متطلَب أساسي | ☐ |
| `/uae-corp-tax` | UaeCorpTaxScreen | Mock tax demo | 🔴 ARCHIVE — لو في compliance بديل | ☐ |
| `/startup-metrics` | StartupMetricsScreen | Mock KPI dashboard | 🔴 ARCHIVE — مكرّر مع `/today` | ☐ |

### B2. Demos with Refactor Path

| Path | الملف | الاقتراح | موافق؟ |
|------|------|----------|--------|
| `/gosi-demo` | GosiCalcScreen | 🔵 REFACTOR — انقل لـ `/hr/gosi` (production) | ☐ REFACTOR |
| `/eosb-demo` | EosbCalcScreen | 🔵 REFACTOR — انقل لـ `/hr/eosb` (production) | ☐ REFACTOR |
| `/industry-packs` | IndustryPacksScreen | 🔵 REFACTOR — اربط بـ Module Marketplace | ☐ REFACTOR |

### B3. Demos to Keep (Internal Tools)

| Path | الملف | السبب |
|------|------|--------|
| `/showcase` | ApexShowcaseScreen | 🟢 KEEP — Component library للمطورين |
| `/theme-generator` | ThemeGeneratorScreen | 🟢 KEEP — Internal admin tool |
| `/white-label` | WhiteLabelSettingsScreen | 🟢 KEEP — Internal admin tool |
| `/whats-new` | ApexWhatsNewHub | 🟢 KEEP — مفيد للمستخدمين |

---

## الفئة C: Sprint Routes (9 شاشة — قرارات حالة بحالة)

| Path | Status في الكود | السؤال |
|------|----------------|---------|
| `/sprint35-foundation` | partial backend + UI | هل الميزة منقولة لـ V5 shell؟ |
| `/sprint37-experience` | UI + mock | هل لسه نستخدمها للـ pitch؟ |
| `/sprint38-composable` | UI + backend | هل في V5؟ |
| `/sprint39-erp` | UI + backend | هل في V5؟ |
| `/sprint40-payroll` | UI + mock | هل اتهاجرت لـ `/hr/payroll-run`؟ |
| `/sprint41-procurement` | UI + backend | هل اتهاجرت لـ `/purchase/*`؟ |
| `/sprint42-longterm` | UI + mock | هل لها بديل؟ |
| `/sprint43-platform` | UI + backend | هل اتهاجرت؟ |
| `/sprint44-operations` | UI + backend | هل اتهاجرت لـ `/operations/*`؟ |

**القاعدة المقترحة**:
- لو الميزة في V5 shell بالكامل → 🔴 ARCHIVE الـ sprint route + الشاشة
- لو لسه مش متهجرة بالكامل → 🟢 KEEP لحد التهجير
- في كل الحالات: راجع `/whats-new` لإزالة الـ link المكسور لو حذفت

موافق على القاعدة دي؟ ☐

---

## الفئة D: Orphaned Screen Files (TBD — يحتاج فحص أعمق)

ملفات في `lib/screens/` بدون GoRoute. الوكيل أشار لاحتمال orphans في:

- `lib/screens/operations/financial_ops_hub_screen.dart` (commented out في router)
- `lib/screens/operations/je_creator_screen.dart` (commented out)
- `lib/screens/operations/financial_statements_formatted_screen.dart` (commented out)
- `lib/screens/operations/financial_analysis_screen.dart` (commented out)
- `lib/screens/onboarding/onboarding_wizard_screen.dart` (replaced by V5 onboarding)
- `lib/screens/compliance/bank_rec_ai_screen.dart` (redirected)
- `lib/screens/compliance/depreciation_ai_screen.dart` (redirected)
- `lib/screens/compliance/multi_currency_screen.dart` (redirected)
- `lib/screens/compliance/journal_entries_screen.dart` (redirected)
- `lib/screens/compliance/budget_variance_screen.dart` (legacy file، unused)

**الاقتراح**: لما توافق على المرحلة، أعمل فحص دقيق بـ:

```bash
# 1. اطلع كل الـ Screen classes
grep -rn "^class.*Screen extends" apex_finance/lib/screens/

# 2. اطلع كل الـ imports في router files  
grep -rn "import.*screens" apex_finance/lib/core/router.dart

# 3. اعمل diff: ملفات لا router لا v4_wired لا v5_wired
```

ينتج لي قائمة 100% precise للـ orphans، أرسلها لك للموافقة.

---

## الإجمالي المقترح للأرشفة

### Auto-archive (آمن، مفيش قرارات):
- 🟡 11 redirect routes للـ v1→v2 (بعد 30 يوم)
- 🐛 1 duplicate route (Bug fix فوري)

### تحتاج موافقة منك:
- ⚪ 8 demos (الفئة B1)
- ⚪ 3 demos للـ refactor (الفئة B2)
- ⚪ 9 sprint routes (الفئة C — حسب القاعدة)
- ⚪ Orphaned files (الفئة D — بعد الفحص)

**Total**: ~30 شاشة للأرشفة + ~10 redirects للحذف بعد 30 يوم

---

## ضمانات السلامة

🛡️ **قبل أي archive، هنفّذ التالي:**

1. ✅ **Git tag**: `pre-archive-2026-04-29` — يقدر يرجّع أي شيء
2. ✅ **Git branch**: `archive/[screen-name]` لكل شاشة (نقل، مش حذف)
3. ✅ **Move، not delete**: الملفات تروح `lib/screens/_archive/[date]/[original-path]/`
4. ✅ **Inbound link check**: قبل النقل، grep لكل `context.go('<path>')` و `GoRouter.go('<path>')` — لو في links، نحدّثها أولاً
5. ✅ **Test build**: `flutter build web` يجب يمر قبل الـ commit

🔄 **Rollback في أي وقت:**
- التفاصيل في [`04-rollback.md`](04-rollback.md)
- أساساً: `git revert` أو نقل من `_archive/` لمكانه الأصلي
