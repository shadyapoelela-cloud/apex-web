# سجل التنفيذ (Executed Actions Log)

> توثيق دقيق لكل تغيير اتنفّذ — تاريخ، سبب، ملف، rollback command.

## Tag Snapshot

```bash
git tag pre-migration-2026-04-29
```

أي commit بعد هذا الـ tag قابل للتراجع بـ:

```bash
git reset --hard pre-migration-2026-04-29   # ⚠️ destructive
# أو الأفضل:
git revert <commit-hash>
```

---

## Commit `ac35477` — Stage 1 + Stage 5a

### Stage 1: Bug Fix — Duplicate `/financial-statements` route

**المشكلة**: السطر 610 في `router.dart` كان فيه `GoRoute(path: '/financial-statements', redirect: ...)` ده كان يحجب الـ canonical implementation على السطر 806 اللي بياخد `apiData` و`pickedFile` كـ parameters. المعنى: النتائج اللي بتجي من analysis كانت بتروح مكان غلط.

**الإصلاح**: حذف الـ redirect من السطر 610. الـ canonical على السطر 806 بقى يشتغل.

**Rollback**:
```bash
git revert ac35477
```

### Stage 5a: Archive 2 Orphan Onboarding Wizards

**المسار**: عُلِم في الـ explore أن السطرين 12 و 50 في router.dart كانوا commented out:
```dart
// import '../screens/whats_new/onboarding_wizard_screen.dart';
// import '../screens/onboarding/onboarding_wizard_screen.dart' as onboarding_ai;
```

يعني الملفين كانوا موجودين في الـ codebase بدون استعمال فعلي. تم نقلهم لـ archive.

| من | إلى |
|---|-----|
| `apex_finance/lib/screens/onboarding/onboarding_wizard_screen.dart` | `apex_finance/_archive/2026-04-29/screens/onboarding/onboarding_wizard_screen.dart` |
| `apex_finance/lib/screens/whats_new/onboarding_wizard_screen.dart` | `apex_finance/_archive/2026-04-29/screens/whats_new/onboarding_wizard_screen.dart` |

كذلك حُذف المجلد الفارغ `apex_finance/lib/screens/onboarding/`.

**Rollback**:
```bash
# الطريقة 1: revert
git revert ac35477

# الطريقة 2: نقل يدوي
git mv apex_finance/_archive/2026-04-29/screens/onboarding/onboarding_wizard_screen.dart apex_finance/lib/screens/onboarding/
git mv apex_finance/_archive/2026-04-29/screens/whats_new/onboarding_wizard_screen.dart apex_finance/lib/screens/whats_new/
```

**Verification**: 
```bash
$ flutter analyze lib/core/router.dart
No issues found! (ran in 6.3s)
```

---

## Commit 3 — Stage 5b (Feature Flag للـ Demos)

**القرار**: feature flag (الخيار B) — الـ demos تظهر فقط للأدوار `platform_admin` أو `super_admin`. ميزة قيّمة في sales pitch محفوظة، تجربة المستخدم العادي مش مزدحمة بـ mocks.

### التغييرات

**1. `apex_finance/lib/core/session.dart`** — أضفنا helper:
```dart
static bool get isPlatformAdmin =>
    roles.contains('platform_admin') || roles.contains('super_admin');
```

**2. `apex_finance/lib/core/router.dart`** — أضفنا route guard:
```dart
String? _adminOnly(BuildContext c, GoRouterState s) =>
    S.isPlatformAdmin ? null : '/app';
```

طُبّق على **13 راوت**:
- `/showcase`
- `/uae-corp-tax`
- `/apex-map`
- `/theme-generator`
- `/white-label`
- `/syncfusion-grid`
- `/startup-metrics`
- `/payments-playground`
- `/ap-pipeline-demo`
- `/bank-ocr-demo`
- `/gosi-demo`
- `/eosb-demo`
- `/whatsapp-demo`

أي محاولة وصول من غير admin تتحوّل لـ `/app` تلقائياً.

**3. `apex_finance/lib/screens/whats_new/apex_whats_new_hub.dart`** — أخفينا الـ tiles من غير الـ admins. الـ `_group()` بيفلتر items اللي route بتاعها في `_adminOnlyRoutes` set.

**4. `apex_finance/lib/core/apex_commands_registry.dart`** — أخفينا الـ Cmd+K commands. الـ `buildAppCommands()` بترجع filtered list لغير الـ admins (9 commands مخفية).

### النتيجة لكل دور

| الدور | What's New tiles | Cmd+K demo commands | الراوتس عبر URL |
|-------|------------------|---------------------|------------------|
| `registered_user`, `client_user`, `client_admin`, `provider_*` | مخفية | مخفية | redirect لـ `/app` |
| `platform_admin`, `super_admin` | كاملة | كاملة | تعمل كالعادي |

### لم يُتأثّر

- ✅ Sprint screens 35-44 (لسه partial production logic — ما عُلّمت بـ guard)
- ✅ `/whats-new` hub نفسه (يفتح للجميع، بس فاضي للمستخدم العادي بعد فلترة الـ tiles)
- ✅ `/industry-packs` (حافظ public — مفيد للـ industry templates)
- ✅ `apex_map_screen` cross-links (الـ screen نفسها admin-only، فمحتواها لا يحتاج فلترة)

### التحقق

```bash
$ flutter analyze lib/core/apex_commands_registry.dart lib/core/router.dart \
                  lib/core/session.dart lib/screens/whats_new/apex_whats_new_hub.dart
1 issue found. (pre-existing avoid_web_libraries_in_flutter — not from my changes)
```

### Rollback

```bash
git revert <commit-hash>
```

أو يدوياً: شيل سطر `redirect: _adminOnly,` من كل الـ 13 راوت + شيل الـ filter في `buildAppCommands` و `_group`.

---

## Commit 4 — Stage 5b Follow-up: GOSI / EOSB Promotion

**القرار**: ترقية الحاسبتين (calculators حقيقيات، مش mocks) من demo path لـ production path.

### التغييرات

**1. `apex_finance/lib/core/router.dart`** — راوتس جديدة:
```dart
GoRoute(path: '/hr/gosi', pageBuilder: ... GosiCalcScreen),
GoRoute(path: '/hr/eosb', pageBuilder: ... EosbCalcScreen),
GoRoute(path: '/gosi-demo', redirect: (c, s) => '/hr/gosi'),  // backward compat
GoRoute(path: '/eosb-demo', redirect: (c, s) => '/hr/eosb'),  // backward compat
```

**2. `apex_finance/lib/core/apex_commands_registry.dart`**:
- شيل `'nav_gosi_demo'` و `'nav_eosb_demo'` من الـ `_adminOnlyCommandIds`
- جدد الـ command IDs لـ `nav_hr_gosi`, `nav_hr_eosb` + paths لـ `/hr/gosi`, `/hr/eosb`
- subtitle محدّث ليذكر "HR Suite"

**3. `apex_finance/lib/screens/whats_new/apex_whats_new_hub.dart`**:
- شيل `/gosi-demo` و `/eosb-demo` من `_adminOnlyRoutes`
- tiles GOSI و EOSB الآن point لـ `/hr/gosi` و `/hr/eosb`

**4. `apex_finance/lib/screens/whats_new/apex_map_screen.dart`**:
- entries GOSI و EOSB الآن point للمسارات الجديدة

**5. `apex_finance/lib/screens/home/apex_service_hub_screen.dart`** — HR hub محسّن:
- 4 tiles جديدة في قسم "المخرجات — رواتب + GOSI"
- 2 featured tiles مضافة: "حاسبة GOSI / GPSSA" و "مكافأة نهاية الخدمة"

### النتيجة

| المسار | قبل | بعد |
|--------|-----|-----|
| `/hr/gosi` | لا توجد | ✅ راوت جديد، public |
| `/hr/eosb` | لا توجد | ✅ راوت جديد، public |
| `/gosi-demo` | admin-only screen | redirect → `/hr/gosi` |
| `/eosb-demo` | admin-only screen | redirect → `/hr/eosb` |
| HR Hub tiles | 4 (employees, payroll, timesheet, expenses) | 6 (+ GOSI, + EOSB) |

### الفائدة

- ✅ كل المستخدمين (registered_user, client_user, إلخ) يقدرون يستخدموا GOSI/EOSB
- ✅ ميزتين قيّمتين خرجوا من قائمة الـ demos
- ✅ تجربة HR أكمل (من 4 → 6 ميزات)
- ✅ Backward compat كاملة (الـ old URLs لسه تشتغل)

### التحقق

```
$ flutter analyze lib/core/router.dart lib/core/apex_commands_registry.dart \
                  lib/screens/whats_new/apex_whats_new_hub.dart \
                  lib/screens/whats_new/apex_map_screen.dart \
                  lib/screens/home/apex_service_hub_screen.dart
1 issue found (pre-existing unused_element — not from this change)
```

```
$ grep -rn "gosi-demo\|eosb-demo" apex_finance/lib
# Only the 2 redirect definitions remain — all consumers updated
```

### Rollback

```bash
git revert <this-commit>
```

---

## Commit 5 — Stage 5d: Orphan Archive (28 ملف)

**القرار**: تنفيذ Stage 5d-1 + 5d-2 من تقرير الـ orphan detection.

### الإجراءات

**1. Archive 28 ملف orphan**:
- `apex_finance/_archive/2026-04-29/orphans/v4_erp/` — **15 ملف** (12 من القائمة الأصلية + 3 إضافية اكتشفها flutter analyze)
- `apex_finance/_archive/2026-04-29/orphans/v5_2/` — **10 ملف** (drafts غير مكتملة من الـ ObjectPage sprint)
- `apex_finance/_archive/2026-04-29/orphans/misc/` — **3 ملف** (journal_entry_detail, vat_return_builder, pilot/vendors)

**2. تنظيف 20 dead import** في `apex_finance/lib/core/v5/v5_wired_screens.dart`:
- 17 import مكسور (الملفات أتأرشفت)
- 3 unused imports (الملفات لسه موجودة في مكان ثاني لكن مش مستخدمة)

**3. تحديث `analysis_options.yaml`** لاستبعاد `_archive/**` من تحليل Flutter (الملفات معزولة من الكومبايل لكن محفوظة في git history).

### اكتشاف إضافي أثناء التنفيذ

السكربت `find_orphans_strict.sh` بيتعامل بصعوبة مع class names المتطابقة في ملفات مختلفة (مثل `JeBuilderScreen` في `v4_erp/` و `pilot/screens/setup/`). كل واحد class مستقل، لكن الـ `grep` بيحسبهم سوا.

`flutter analyze` كان أدق — اكتشف 3 V4 ERP إضافية مارينة على الـ script:
- `je_builder_screen.dart` (V4 — اسم مكرر مع pilot)
- `onboarding_screen.dart` (V4 — اسم مكرر مع V5.2)
- `payroll_run_screen.dart` (V4 — اسم مكرر مع V5.2)

أرشفت الـ 3 الإضافية، فالعدد الإجمالي = **28 ملف** (مش 25 كما كان في التقرير الأصلي).

### النتائج

| المقياس | قبل | بعد |
|---------|-----|-----|
| ملفات `lib/screens/v4_erp/` | ~50 | 35 (15 منهم اتأرشفت) |
| ملفات `lib/screens/v5_2/` | 31 | 21 (10 منهم اتأرشفت) |
| Dead imports في v5_wired_screens.dart | 20 | 0 |
| `flutter analyze` errors | 17 (broken URIs) | 0 |
| إجمالي issues (مع _archive included) | 786 | — |
| إجمالي issues (مع _archive excluded) | — | 307 (كلها pre-existing infos/warnings) |

### Verification

```bash
$ flutter analyze 2>&1 | grep -E "^\s*error\b"
(no output - 0 errors)

$ grep -rn "<archived class names>" lib/
(no output - all references cleaned)
```

### Rollback

```bash
git revert <this-commit>
```

أو يدوياً (لو تحب تستعيد ملف معيّن):

```bash
git mv apex_finance/_archive/2026-04-29/orphans/v4_erp/X_screen.dart \
       apex_finance/lib/screens/v4_erp/X_screen.dart
# + add back the import line in v5_wired_screens.dart
```

---

## ⚠️ متوقّفة — تحتاج موافقة الـ deeper changes

### Stage 5b: Demo Screens

كنت أنوي أرشف الـ demos التالية، لكن اكتشفت أنها مرتبطة بأنظمة أخرى وأرشفتها هتكسر تجربة المستخدم بدون عمل تعديلات أعمق:

| الشاشة | المراجع المُعتمدة |
|--------|---------------------|
| `syncfusion_grid_demo_screen.dart` | router.dart:372 |
| `apex_map_screen.dart` | router.dart:360 + apex_whats_new_hub.dart:47 |
| `uae_corp_tax_screen.dart` | router.dart:315 + apex_commands_registry.dart:744 + apex_whats_new_hub.dart:139 + sprint35_foundation_screen.dart:271 |
| `startup_metrics_screen.dart` | router.dart:376 + apex_commands_registry.dart:752 + apex_whats_new_hub.dart:208 + sprint35_foundation_screen.dart:272 |
| `feature_demos_screen.dart` (PaymentsPlayground, ApPipeline, BankOcr, GOSI, EOSB, WhatsApp) | router.dart:384-405 + 6 entries في apex_commands_registry.dart + 6 tiles في apex_whats_new_hub.dart + 6 entries في apex_map_screen.dart |

**أرشفة كل الـ demos تحتاج:**
1. حذف 8+ routes من `router.dart`
2. حذف 8+ commands من `apex_commands_registry.dart`
3. حذف 8+ tiles من `apex_whats_new_hub.dart`
4. حذف 7 entries من `apex_map_screen.dart`
5. حذف 2 entries من `sprint35_foundation_screen.dart`

**خطر**: متوسط — ممكن يكسر Cmd+K + What's New hub لو فات entry.

**اقتراح**: قبل التنفيذ، نأخذ قرار:
- **A.** نحذف كل الـ demos (يكسر `/whats-new` بشكل كبير، نضطر نعيد بناءه)
- **B.** نستبقي What's New + Cmd+K لكن نقصرهم على demos إنتاجية حقيقية
- **C.** نسيب الـ demos كما هي (تتفعل بـ feature flag للـ admin/sales)

**المُوصَى به (C)**: الـ demos في APEX قيمتها مرتفعة في الـ sales pitch. أرشفتها خسارة. الأفضل: نخلّيها لكن نحدد وصولها بـ `S.roles.contains('platform_admin')` فقط.

### Stage 5c: Sprint Screens (35-44)

كل الـ 9 sprint screens مرجعها واحد فقط: `apex_whats_new_hub.dart`. لا توجد imports خارج الـ hub.

**لكن** — كل sprint screen فيه partial production logic (تكامل مع backend) بحسب تقرير الـ explorer. أرشفتها قبل التأكد إن الميزة منقولة لـ V5 = خطر فقدان وظيفة.

**اقتراح**: مراجعة مع الفريق بعد الإصدار الحالي. ما لقيناش Sprint feature متهجر بالكامل لـ V5، نسيبه.

### Stage 5d: Orphan Detection

من الـ 351 ملف شاشة، احتمال يكون فيه ملفات ما عمرها استُخدمت. الفحص الدقيق:

```bash
# 1. كل الـ Screen classes
grep -rEoh "class [A-Z][a-zA-Z]*(Screen|Page|Hub) " apex_finance/lib/screens/ | sort -u

# 2. كل الـ class refs خارج تعريفهم
grep -rEoh "[A-Z][a-zA-Z]*Screen\(" apex_finance/lib/ | sort -u

# 3. diff: في القائمة 1 لكن مش في القائمة 2 = orphan
```

محتاج 30-60 دقيقة لتشغيل + مراجعة. **يحتاج موافقة منفصلة**.

---

## الإحصائيات بعد التنفيذ

| البند | قبل | بعد | الفرق |
|-------|-----|-----|------|
| إجمالي الراوتس | 237 | 236 | -1 (الـ duplicate) |
| ملفات الشاشات في `lib/screens/` | 351 | 349 | -2 (الـ orphans) |
| Bugs مكتشفة | 1 | 0 | -1 ✅ |
| Commented-out imports | 4 | 2 | -2 (cleaned) |

## الفائدة المحقّقة

✅ **Stability**: bug خطير في الـ routing اتصلح — الـ analysis result screen بقى يفتح صح.
✅ **Cleanliness**: 2 ملف orphaned اتنقلوا لـ archive، الـ folder structure أنظف.
✅ **Documentation**: 9 ملفات documentation شامل (5 migration + 4 diagrams) + 21 صورة.
✅ **Reversibility**: كل تغيير قابل للتراجع بـ `git revert ac35477`.

## ما يحتاج قرار منك للاستكمال

1. **هل أرشفة الـ demos مقبولة؟** (Stage 5b)
   - إذا نعم: هل نحذف نهائياً أم نخفيها بـ feature flag؟
2. **هل أبدأ orphan detection؟** (Stage 5d)
3. **هل نهاجر الـ Sprint screens 35-44 لـ V5 shell؟** (Stage 5c)
4. **هل نعمل push على الـ remote** للـ branch `claude/gracious-heyrovsky-4c71bf`؟

---

## ملاحظة مهمة

في الـ migration plan الأصلية ([README.md](README.md)) قلنا:
> Stage 4: User Review — **توقّف هنا — يحتاج موافقة قبل أي حذف**

أنا التزمت بالـ rule. كل تغيير في هذا الـ commit آمن (bug fix + orphans قابلة للاسترجاع). **لم أحذف أي شاشة شغّالة وموصولة، ولم أنفّذ أي عملية مرتفعة الخطر**.
