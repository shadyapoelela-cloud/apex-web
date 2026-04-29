# Orphan Detection Report — 2026-04-29

> فحص دقيق لـ **399 شاشة** (`Screen | Page | Hub` widget classes) في `apex_finance/lib/`. النتائج معتمدة على معيار: **عدد الملفات التي تُنشئ الـ class عبر `ClassName(`** (instantiation count من ملفات أخرى).

## النتائج

| التصنيف | العدد | المعنى |
|--------|------|--------|
| ✅ Active (1+ external instantiations) | **364** | Canonical screens، wired في GoRouter أو widget hierarchy |
| 🔴 **Orphan candidates** (0 external instantiations) | **35** | تحت الفحص أدناه |

التوزيع التفصيلي:

| Instantiations | عدد الكلاسات |
|----------------|--------------|
| 5+ | 4 |
| 3-4 | 21 |
| 2 | 18 |
| 1 (router-only) | **324** ← الحالة الصحية |
| **0** | **35** |

## 🔴 الفئة A: Safe Archive (دار مخصص + 0 استخدام خارجي = 25 ملف)

كل ملف في الجدول التالي:
- يحتوي على class واحد رئيسي فقط (file = class)
- الـ class غير مُنشأ في أي ملف آخر (تم التحقق بـ `grep -rn "ClsName("`)
- الـ import موجود في v5_wired_screens.dart لكن مايتم استخدامه (dead import)

### V4 ERP — 12 ملف

| الملف | الـ Class | dead import في |
|------|---------|----------------|
| `screens/v4_erp/ai_financial_analyst_screen.dart` | `AiFinancialAnalystScreen` | v5_wired:49 |
| `screens/v4_erp/anomaly_detector_screen.dart` | `AnomalyDetectorScreen` | v5_wired:136 |
| `screens/v4_erp/approval_workflows_screen.dart` | `ApprovalWorkflowsScreen` | — |
| `screens/v4_erp/budget_planning_screen.dart` | `BudgetPlanningScreen` | v5_wired:54 |
| `screens/v4_erp/budget_vs_actual_screen.dart` | `BudgetVsActualScreen` | — |
| `screens/v4_erp/connected_planning_screen.dart` | `ConnectedPlanningScreen` | — |
| `screens/v4_erp/cost_centers_screen.dart` | `CostCentersScreen` | v5_wired:125 |
| `screens/v4_erp/document_vault_screen.dart` | `DocumentVaultScreen` | — |
| `screens/v4_erp/general_ledger_screen.dart` | `GeneralLedgerScreen` | v5_wired:154 |
| `screens/v4_erp/integrations_hub_screen.dart` | `IntegrationsHubScreen` | v5_wired:121 |
| `screens/v4_erp/invoices_multi_view_screen.dart` | `InvoicesMultiViewScreen` | v5_wired:164 |
| `screens/v4_erp/scenario_planning_screen.dart` | `ScenarioPlanningScreen` | — |

> **لاحظ**: 6 من أصل 12 لها dead imports في `v5_wired_screens.dart` — لازم نحذف الـ import مع الملف.

### V5.2 (Drafts غير مكتملة) — 10 ملف

| الملف | الـ Class | البديل المتاح |
|------|---------|----------------|
| `screens/v5_2/advanced_settings_v52_screen.dart` | `AdvancedSettingsV52Screen` | `/settings/unified` |
| `screens/v5_2/coa_editor_v52_screen.dart` | `CoaEditorV52Screen` | `/accounting/coa-v2` |
| `screens/v5_2/financial_statements_fsv_v52_screen.dart` | `FinancialStatementsFsvV52Screen` | `/compliance/financial-statements` |
| `screens/v5_2/financial_statements_v52_screen.dart` | `FinancialStatementsV52Screen` | نفسه |
| `screens/v5_2/je_builder_v52_screen.dart` | `JeBuilderV52Screen` | **`JeBuilderLiveV52Screen`** (ملف مختلف، شغّال) |
| `screens/v5_2/onboarding_v52_screen.dart` | `OnboardingV52Screen` | `/app/erp/finance/onboarding` |
| `screens/v5_2/period_close_v52_screen.dart` | `PeriodCloseV52Screen` | `/operations/period-close` |
| `screens/v5_2/purchasing_ap_v52_screen.dart` | `PurchasingApV52Screen` | `/purchase/bills` |
| `screens/v5_2/supplier_360_v52_screen.dart` | `Supplier360V52Screen` | `/operations/vendor-360/:id` |
| `screens/v5_2/universal_gl_v52_screen.dart` | `UniversalGlV52Screen` | `/operations/universal-journal` |

> **ملاحظة**: الـ V5.2 ده كان draft sprint للـ ObjectPage pattern. واحد فقط (`JeBuilderLiveV52Screen` — ملف مختلف) تم تفعيله. الباقي drafts معلّقة.

### غير ذلك — 3 ملف

| الملف | الـ Class | السبب |
|------|---------|--------|
| `screens/compliance/journal_entry_detail_screen.dart` | `JournalEntryDetailScreen` | استُبدل بـ V5 JE builder |
| `screens/v4_compliance/vat_return_builder_screen.dart` | `VatReturnBuilderScreen` | استُبدل بـ `VatReturnScreen` |
| `pilot/screens/setup/vendors_screen.dart` | `VendorsScreen` | استُبدل بـ `VendorsListScreen` |

**Total Safe-Archive: 25 ملف**

---

## 🟠 الفئة B: Multi-Class Files — تنظيف داخلي فقط (4 موضع)

ملفات تحتوي على عدة classes؛ بعض الـ classes مستخدم وبعضها orphan. **لا نأرشف الملف**، فقط نحذف الـ class الـ orphan.

### `apex_finance/lib/main.dart` (3500 سطر)
- 🔴 `NewClientScreen` (line 1659) — never instantiated
- 🔴 `NotificationsScreen` (multiple lines) — never instantiated
- ✅ بقية الـ classes (LoginScreen, RegScreen, إلخ) شغّالة

### `apex_finance/lib/screens/admin/admin_sub_screens.dart`
- 🔴 `ClientTypeSelectionScreen`
- 🔴 `LegalAcceptanceScreen`
- 🔴 `TaskDocumentManagementScreen`
- 🔴 `TaskDocumentScreen`
- ✅ بقية: `ReviewerConsoleScreen`, `ProviderVerificationScreen`, إلخ شغّالة

### `apex_finance/lib/core/apex_loading_states.dart`
- 🔴 `ApexErrorPage` — never instantiated
- ✅ Loading widgets الباقية شغّالة

### `apex_finance/lib/screens/extracted/client_screens.dart`
- 🔴 `ClientCreateScreen` — never instantiated
- ✅ بقية: `ClientListScreen`, إلخ شغّالة

**الإجراء**: حذف الـ class blocks المعنيّة من داخل الملفات. **ليست أرشفة ملف** — تنظيف class-level.

---

## 🟡 الفئة C: False Positives — Internal-Flow Screens (لا نلمسها)

`screens/auth/forgot_password_flow.dart` فيه:
- `NewPasswordScreen`
- `VerifyResetCodeScreen`

ظهرتا في القائمة لأن الـ instantiation داخلي (نفس الملف، في خطوات الـ flow). **هذه استخدامات شرعية** — لا نلمسها.

---

## ملخص الإجراءات المقترحة

| الإجراء | عدد الملفات/Classes | المخاطر |
|---------|----------------------|----------|
| 🔴 Archive 25 ملف orphan | 25 ملف | 🟢 آمن (verified 0 external uses) |
| 🟠 حذف 8 classes من 4 ملفات multi-class | 8 classes | 🟡 يحتاج care في main.dart الكبير |
| 🟡 ترك 2 false positives | 0 changes | 🟢 |

## التحقق المسبق قبل الأرشفة

لكل ملف في الـ Safe Archive، السكريبت أكد:
1. ✅ الـ class الرئيسي في الملف لا يُنشأ في أي ملف آخر
2. ⚠️ بعضها له dead `import` في v5_wired_screens.dart — لازم يُحذف مع الأرشفة

## التنفيذ المقترح

### Stage 5d-1: Archive 25 V4/V5.2 Orphan Files
```bash
mkdir -p apex_finance/_archive/2026-04-29/orphans/v4_erp
mkdir -p apex_finance/_archive/2026-04-29/orphans/v5_2
mkdir -p apex_finance/_archive/2026-04-29/orphans/misc

# v4_erp (12 files)
git mv apex_finance/lib/screens/v4_erp/ai_financial_analyst_screen.dart \
       apex_finance/_archive/2026-04-29/orphans/v4_erp/
# ... (repeat for 11 more)

# v5_2 (10 files)
git mv apex_finance/lib/screens/v5_2/advanced_settings_v52_screen.dart \
       apex_finance/_archive/2026-04-29/orphans/v5_2/
# ... (repeat for 9 more)

# misc (3 files)
git mv apex_finance/lib/screens/compliance/journal_entry_detail_screen.dart \
       apex_finance/_archive/2026-04-29/orphans/misc/
git mv apex_finance/lib/screens/v4_compliance/vat_return_builder_screen.dart \
       apex_finance/_archive/2026-04-29/orphans/misc/
git mv apex_finance/lib/pilot/screens/setup/vendors_screen.dart \
       apex_finance/_archive/2026-04-29/orphans/misc/
```

### Stage 5d-2: Clean Dead Imports

في `apex_finance/lib/core/v5/v5_wired_screens.dart` — حذف الـ imports اللي ما فيش لها instantiation:
- Line 49: `ai_financial_analyst_screen.dart`
- Line 54: `budget_planning_screen.dart`
- Line 121: `integrations_hub_screen.dart`
- Line 125: `cost_centers_screen.dart`
- Line 136: `anomaly_detector_screen.dart`
- Line 154: `general_ledger_screen.dart`
- Line 164: `invoices_multi_view_screen.dart`
- Line 193: `period_close_v52_screen.dart`
- (وأي imports ثانية لو موجودة)

### Stage 5d-3 (لاحقاً، يحتاج care): Multi-Class Cleanup
- main.dart: حذف `NewClientScreen` و `NotificationsScreen` blocks (need careful manual edit — main.dart 3500 سطر)
- admin_sub_screens.dart: حذف 4 classes
- apex_loading_states.dart: حذف `ApexErrorPage` block
- extracted/client_screens.dart: حذف `ClientCreateScreen` block

## Rollback لأي خطوة

```bash
# للأرشفة فقط:
git mv apex_finance/_archive/2026-04-29/orphans/<path>/<file> \
       apex_finance/lib/screens/<path>/<file>
git checkout HEAD~1 -- apex_finance/lib/core/v5/v5_wired_screens.dart  # restore imports

# أو git revert كامل:
git revert <orphan-commit>
```

## السكربتات

كلهم في `architecture/migration/`:
- `find_orphans.sh` — عد المراجع الكلي
- `find_orphans_strict.sh` — عد الـ instantiations فقط (الأكثر دقة)

أعد التشغيل في أي وقت بـ:
```bash
bash architecture/migration/find_orphans_strict.sh > /tmp/orphan_strict.tsv
awk -F'\t' '$1=="0"' /tmp/orphan_strict.tsv  # = orphan candidates
```

---

## 🚦 القرار المطلوب منك

**أوصي بـ Stage 5d-1 + 5d-2 (الأكثر أماناً):**
- 25 ملف orphan → أرشفة فورية
- 8 dead imports في v5_wired → حذف معاها
- التحقق بعدها بـ `flutter analyze`

**Stage 5d-3 (multi-class cleanup) أتركها لجولة قادمة** — main.dart خصوصاً يحتاج فحص أعمق قبل تعديل.

موافق على Stage 5d-1 + 5d-2؟ ☐

أو تحب أبدأ بـ subset أصغر (V5.2 فقط = 10 ملف، أو V4_erp فقط = 12 ملف)؟
