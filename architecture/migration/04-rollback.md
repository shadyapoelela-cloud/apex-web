# خطة التراجع (Rollback)

> أي خطوة في الهجرة قابلة للتراجع. التفاصيل أدناه لكل مرحلة.

## الفلسفة

1. **مفيش حذف نهائي** قبل المرحلة 6 (بعد 90 يوم من الإنتاج الناجح)
2. **كل تعديل في commit منفصل** — git revert يكفي للرجوع
3. **`lib/screens/_archive/` بدلاً من delete** — الملفات هناك، مش نقطة
4. **Git tags قبل كل مرحلة كبيرة** — checkpoint جاهز للرجوع

---

## Git Tags المقترحة

```bash
# قبل بدء أي تعديل
git tag -a pre-migration-2026-04-29 -m "Snapshot before migration"

# قبل كل مرحلة:
git tag -a pre-stage-1-bugfix
git tag -a pre-stage-2-consolidate
git tag -a pre-stage-3-deprecate
git tag -a pre-stage-5-archive
git tag -a pre-stage-6-final-delete  # خصوصاً قبل دي!
```

للرجوع لأي tag:

```bash
git checkout pre-stage-2-consolidate
# أو لو محتاج undo بدون فقد commits لاحقة:
git revert --no-commit <commit-hash>..<commit-hash>
```

---

## Rollback لكل مرحلة

### Stage 1: Bug Fix (راوت `/financial-statements` المكرر)

**التغيير**: حذف `GoRoute` المكرر في `router.dart:610`

**Rollback**:
```bash
git revert <bugfix-commit-hash>
```

**زمن الاسترجاع**: < 1 دقيقة
**خطر**: 🟢 منعدم — تصليح bug صريح

---

### Stage 2: Consolidation (دمج Duplicates)

**التغيير**: 
- استبدال نسخ متعددة بـ canonical واحد
- إضافة redirects للـ legacy paths

**Rollback**:
```bash
# إعادة الـ canonical paths (ما تأثرتش)
# الـ redirects لو فشلت: ارجعها لـ direct routes:
git revert <consolidation-commits>
```

**زمن الاسترجاع**: 5-15 دقيقة (يحتاج build + deploy)
**خطر**: 🟡 منخفض — كل شاشة لسه موجودة

---

### Stage 3: Soft Deprecation (Banners)

**التغيير**: إضافة `DeprecationBanner` widget على الـ legacy routes

**Rollback**:
```dart
// router.dart - شيل الـ DeprecationBanner wrapper:
GoRoute(
  path: '/compliance/budget-variance',
  redirect: (ctx, state) => '/analytics/budget-variance-v2',  // ارجع للـ redirect المباشر
),
```

**زمن الاسترجاع**: 5 دقائق
**خطر**: 🟢 منعدم — UI banner فقط

---

### Stage 4: User Review

**التغيير**: 0 (فقط مراجعة قائمة)

**Rollback**: غير مطلوب — لم يحدث تغيير

---

### Stage 5: Archive (نقل لـ `_archive/`)

**التغيير**:
```bash
# مثال: أرشفة /syncfusion-grid
mkdir -p apex_finance/lib/screens/_archive/2026-04-29/showcase/
git mv apex_finance/lib/screens/showcase/syncfusion_grid_demo_screen.dart \
       apex_finance/lib/screens/_archive/2026-04-29/showcase/

# تحديث router.dart - إزالة الـ GoRoute و الـ import
```

**Rollback**:
```bash
# الطريقة 1: git revert
git revert <archive-commit>

# الطريقة 2: نقل يدوي للأصل
git mv apex_finance/lib/screens/_archive/2026-04-29/showcase/syncfusion_grid_demo_screen.dart \
       apex_finance/lib/screens/showcase/syncfusion_grid_demo_screen.dart
# + إعادة الـ GoRoute في router.dart
```

**زمن الاسترجاع**: 10-30 دقيقة (نقل + build + deploy)
**خطر**: 🟡 منخفض — الملف موجود في git history + `_archive/`

---

### Stage 6: Final Deletion (بعد 90 يوم)

**التغيير**:
```bash
rm -rf apex_finance/lib/screens/_archive/2026-04-29/
git commit -m "Final cleanup: remove archived screens after 90-day grace period"
```

**Rollback**:
```bash
# الـ git history لسه فيها كل الملفات!
git checkout pre-stage-6-final-delete -- apex_finance/lib/screens/_archive/
```

**زمن الاسترجاع**: < 5 دقائق (من git history)
**خطر**: 🔴 لا يوجد — git يحفظ كل شيء

> **ملاحظة**: حتى بعد المرحلة 6، git history لسه فيها كل ملف. الـ recovery دائماً ممكن طول ما الـ repo موجود.

---

## Recovery Scripts جاهزة

### Script 1: استرجاع شاشة من `_archive`

```bash
#!/bin/bash
# scripts/restore-archived-screen.sh

ARCHIVE_DATE=$1
SCREEN_PATH=$2  # e.g. showcase/syncfusion_grid_demo_screen.dart

if [ -z "$ARCHIVE_DATE" ] || [ -z "$SCREEN_PATH" ]; then
  echo "Usage: $0 <date> <screen-path>"
  echo "Example: $0 2026-04-29 showcase/syncfusion_grid_demo_screen.dart"
  exit 1
fi

ARCHIVE="apex_finance/lib/screens/_archive/$ARCHIVE_DATE/$SCREEN_PATH"
ORIGINAL="apex_finance/lib/screens/$SCREEN_PATH"

if [ ! -f "$ARCHIVE" ]; then
  echo "❌ Archive not found: $ARCHIVE"
  exit 1
fi

git mv "$ARCHIVE" "$ORIGINAL"
echo "✅ Restored: $ORIGINAL"
echo "⚠️  Manual step: re-add GoRoute in apex_finance/lib/core/router.dart"
```

### Script 2: استرجاع بـ git revert

```bash
#!/bin/bash
# scripts/rollback-stage.sh

STAGE=$1  # e.g. stage-5-archive

git revert --no-commit "pre-$STAGE..HEAD"
git commit -m "Rollback: revert $STAGE"
echo "✅ Rolled back $STAGE"
echo "Run: flutter build web && deploy"
```

---

## Communication Plan

في حالة rollback غير مخطط:

1. **خبّر الفريق فوراً** عبر Slack/Email
2. **سجّل السبب** في `architecture/migration/INCIDENTS.md`
3. **حلّل**: ليه فشلت الخطوة؟ توعية قبل المحاولة الثانية
4. **اختبر في staging** قبل إعادة المحاولة

---

## ملخص ضمانات السلامة

| المرحلة | Reversibility | Time to Rollback | Risk |
|---------|----------------|-------------------|------|
| 1. Bug Fix | ✅ git revert | 1 min | 🟢 |
| 2. Consolidate | ✅ git revert | 15 min | 🟡 |
| 3. Soft Deprecate | ✅ git revert | 5 min | 🟢 |
| 4. User Review | N/A | N/A | 🟢 |
| 5. Archive | ✅ git mv من `_archive/` | 30 min | 🟡 |
| 6. Final Delete | ✅ git checkout from history | 5 min | 🟢 (git remembers) |

🛡️ **في كل المراحل، git history هي شبكة الأمان النهائية.**
