# خريطة Redirects (Old → New)

> جدول كل الـ redirects النشطة للحفاظ على bookmarks وlinks الخارجية. أي راوت قديم سيستمر في العمل لمدة **30 يوم على الأقل** بعد التهجير.

## مفتاح الحالة

- 🟢 **Active**: redirect شغّال + سيستمر
- 🟡 **Soft-deprecated**: شغّال + يظهر banner "هذه الشاشة منقولة"
- 🔴 **Removed**: redirect محذوف (مرحلة 6 فقط، بعد 90 يوم)

---

## Compliance → Analytics (8)

| Old Path | New Path | الحالة | تاريخ الإزالة المقترح |
|----------|----------|--------|------------------------|
| `/compliance/budget-variance` | `/analytics/budget-variance-v2` | 🟡 | 2026-05-29 |
| `/compliance/health-score` | `/analytics/health-score-v2` | 🟡 | 2026-05-29 |
| `/compliance/cost-variance` | `/analytics/cost-variance-v2` | 🟡 | 2026-05-29 |
| `/compliance/multi-currency` | `/analytics/multi-currency-v2` | 🟡 | 2026-05-29 |

## Compliance → Operations (3)

| Old Path | New Path | الحالة | تاريخ الإزالة |
|----------|----------|--------|----------------|
| `/compliance/inventory` | `/operations/inventory-v2` | 🟡 | 2026-05-29 |
| `/compliance/fixed-assets` | `/operations/fixed-assets-v2` | 🟡 | 2026-05-29 |

## Compliance → Sales (1)

| Old Path | New Path | الحالة | تاريخ الإزالة |
|----------|----------|--------|----------------|
| `/compliance/aging` | `/sales/aging` | 🟡 | 2026-05-29 |

## Compliance v1 → v2 (4)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/compliance/wht` | `/compliance/wht-v2` | 🟡 |
| `/compliance/consolidation` | `/compliance/consolidation-v2` | 🟡 |
| `/compliance/lease` | `/compliance/lease-v2` | 🟡 |
| `/compliance/depreciation-ai` | `/compliance/depreciation` | 🟡 |
| `/compliance/bank-rec-ai` | `/accounting/bank-rec-v2` | 🟡 |
| `/compliance/bank-rec` | `/accounting/bank-rec-v2` | 🟡 |

## Compliance → Accounting / V5 JE Builder (3)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/compliance/journal-entries` | `/accounting/je-list` | 🟡 |
| `/compliance/journal-entry/:id` | `/app/erp/finance/je-builder/:id` | 🟡 |
| `/accounting/journal-entries` | `/compliance/journal-entries` → `/accounting/je-list` (chain) | ⚠️ تبسيط مطلوب |

## Accounting → COA / Other (3)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/accounting/coa` | `/coa-tree` → `/accounting/coa-v2` (يحتاج تبسيط) | ⚠️ |
| `/accounting/trial-balance` | `/compliance/financial-statements` (chain) | ⚠️ |
| `/accounting/period-close` | `/operations/period-close` | 🟢 |

## Operations → Compliance (3)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/operations/hub` | `/financial-ops` | 🟢 |
| `/operations/je-creator` | `/compliance/journal-entry-builder` | 🟡 |
| `/operations/financial-statements` | `/compliance/financial-statements` | 🟡 |
| `/operations/financial-analysis` | `/compliance/ratios` | 🟢 |

## Settings / Account (5)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/account` | `/settings/unified` | 🟡 |
| `/integrations` | `/settings/unified` | 🟡 |
| `/setup` | `/settings/entities` | 🟡 |
| `/setup/entity` | `/settings/entities` | 🟡 |

## Onboarding / Clients (4)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/onboarding` | `/app/erp/finance/onboarding` | 🟢 |
| `/onboarding/wizard` | `/app/erp/finance/onboarding` | 🟡 |
| `/clients/onboarding` | `/settings/entities?action=new-company` | 🟡 |
| `/clients/new` | `/settings/entities?action=new-company` | 🟡 |
| `/clients/create` | `/settings/entities?action=new-company` | 🟡 |

## Top-Level Aliases (4)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/` | `/app` | 🟢 (root) |
| `/launchpad` | `/app` | 🟢 |
| `/apps` | `/app` | 🟢 |
| `/all` | `/app` | 🟢 |
| `/reports/hub` | `/reports` | 🟢 |
| `/home` | `/app` (legacy MainNav) | 🟡 — قد تكون شاشة |

## Audit Engagement Aliases (proposed consolidation)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/audit/engagement-workspace` | `/audit/engagements` | جديد 🟡 |
| `/audit/benford` | `/audit/engagements?tab=benford` | جديد 🟡 |
| `/audit/sampling` | `/audit/engagements?tab=sampling` | جديد 🟡 |
| `/audit/workpapers` | `/audit/engagements?tab=workpapers` | جديد 🟡 |

## Admin AI Suggestions (proposed)

| Old Path | New Path | الحالة |
|----------|----------|--------|
| `/admin/ai-suggestions` | `/admin/ai-suggestions-v2` | جديد 🟡 |

---

## السلوك المقترح في الـ Frontend

### Stage 2 (الآن — Active)

```dart
// router.dart
GoRoute(
  path: '/compliance/budget-variance',
  redirect: (ctx, state) => '/analytics/budget-variance-v2',
),
```

### Stage 3 (Soft-deprecated — مع banner)

```dart
GoRoute(
  path: '/compliance/budget-variance',
  builder: (ctx, state) => DeprecationBanner(
    canonicalPath: '/analytics/budget-variance-v2',
    removalDate: DateTime(2026, 5, 29),
    child: BudgetVarianceV2Screen(),  // عرض الشاشة الجديدة جواه
  ),
),
```

`DeprecationBanner` هو widget جديد يعرض شريط فوق الشاشة:
> 🟡 **هذه الشاشة منقولة لـ `/analytics/budget-variance-v2`** — ستُحذف بعد 30 يوم. حدّث الـ bookmarks.

### Stage 6 (بعد 90 يوم)

```dart
// الـ GoRoute بيتشال تماماً
// يحلّ محله 404 default + رسالة:
// "هذه الشاشة لم تعد موجودة. ابحث عنها في /apex-map"
```

---

## مقاييس النجاح للحذف النهائي

قبل ما نحذف أي redirect نهائياً، نتأكد:

| الشرط | الحد الأدنى |
|-------|--------------|
| لا visits آخر 30 يوم | < 5 visits/يوم |
| لا inbound links فعلية | grep لا يجد `context.go('<old>')` |
| لا external bookmarks (analytics) | معدل < 1/أسبوع |
| الإصدار الجديد stable في الإنتاج | ≥ 60 يوم |

أداة المراقبة المقترحة: استخدم `/admin/audit` route hits + Google Analytics.
