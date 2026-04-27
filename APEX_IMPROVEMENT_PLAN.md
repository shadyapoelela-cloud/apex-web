# خطة تحسين وتطوير منصة APEX المالية

> الإصدار: ٢٠٢٦-٠٤-٢٧ — موحَّدة من خطة العميل + إضافات Claude Copilot
> الحالة: قيد التنفيذ — موجة ١ بدأت

## نطاق الخطة

تحسين شامل لمنصة APEX يشمل تجربة المستخدم، تكامل الذكاء الاصطناعي، البنية الخلفية، والاختبار. تُنفَّذ على ٤ موجات متتالية — كل موجة تعتمد على ما قبلها.

---

## ١. تحسينات واجهة المستخدم (UI/UX)

### ١.١ من خطة العميل
- [ ] إضافة زر ذكاء اصطناعي (AI) واضح في جميع شاشات القوائم (فواتير، عملاء، موردين…)
- [ ] توحيد تصميم AppBar في كل الشاشات مع دعم `headerActions`
- [ ] تحسين تجربة المستخدم في الشاشات الفارغة (Empty State) بإضافة اقتراحات ذكية
- [ ] مراجعة ألوان النظام وتباين النصوص لزيادة الوضوح
- [ ] دعم أفضل للغات (RTL/LTR) وتوسيع الترجمة

### ١.٢ إضافات Copilot
- [ ] **A1 — حفظ المفضلات (saved searches) في localStorage** — حالياً in-memory، تُفقد عند reload
- [ ] **A2 — Bulk-select infrastructure** — checkbox عمود + select-all + bulk delete/export/status-change
- [ ] **A3 — Persistence للتفضيلات الشخصية** (آخر فلتر/تجميع/وضع عرض) لكل مستخدم/شاشة
- [ ] **A4 — A11y** — `Semantics` widgets + keyboard navigation + ARIA labels (متطلب KSA Universal Design)
- [ ] **A5 — Responsive breakpoints** — تخطيط مختلف للموبايل (<600px) والتابلت (600-1024px)
- [ ] **A10 — محتوى مفيد لـ help dialog** — حالياً اختصارات لوحة فقط؛ يحتاج خطوات إرشادية + روابط

---

## ٢. تكامل الذكاء الاصطناعي

### ٢.١ من خطة العميل
- [ ] ربط زر AI في كل شاشة بقسم التحليل الذكي (Ask APEX)
- [ ] تفعيل اقتراحات AI تلقائية بناءً على البيانات الظاهرة
- [ ] دعم موافقة/رفض الاقتراحات من داخل الشاشات مباشرة
- [ ] تحسين سرعة استجابة واجهة AI وتقليل زمن الانتظار

### ٢.٢ تفاصيل التطبيق
- زر "ذكاء" يفتح **Right-side Drawer** يحوي AI Copilot مع context الشاشة الحالية
- **context يُرسَل تلقائياً:** اسم الشاشة + الفلاتر النشطة + أعمدة البيانات الظاهرة + إحصاءات
- **اقتراحات Inline** تظهر كـ banner علوي في الـ body مع زرّي "تطبيق" و"تجاهل"
- **streaming response** للـ AI من Anthropic API عبر backend (متوفر `ANTHROPIC_API_KEY`)
- **تخزين تاريخ المحادثة** في localStorage لكل شاشة (الموجة ٤)

---

## ٣. تحسينات البنية الخلفية (Backend)

### ٣.١ من خطة العميل
- [ ] مراجعة جميع نقاط النهاية (API) وتوحيد الاستجابات `{success, data}` / `{success, error}`
- [ ] إضافة اختبارات تكاملية جديدة لكل ميزة تم تطويرها
- [ ] تحسين إدارة الأخطاء وعدم إظهار أي Traceback للمستخدم النهائي
- [ ] مراجعة صلاحيات الوصول لكل Endpoint

### ٣.٢ إضافات Copilot
- [ ] **A6 — Error boundary + Sentry-compatible structured logging** — لا monitoring حالياً
- [ ] **A9 — Optimistic updates + offline queue** — الـ pilot عنده queue، نعمّمه على باقي الـ writes
- [ ] **سكربت audit يدويّ** (`tools/api_audit.py`) يفحص: response shape، traceback leaks، permissions decorators، rate-limit headers

---

## ٤. الأداء والـ build

### ٤.١ إضافات Copilot
- [ ] **A7 — Code-splitting + deferred imports** للشاشات الكبيرة — bundle حالياً 9.5MB يمكن تقليله 30-40%
- [ ] **Image optimization** — WebP بدل PNG، lazy loading
- [ ] **Service Worker network-only** (تم في 25 أبريل) — مراجعة بعد ٣٠ يوماً
- [ ] قياس **Time-to-Interactive** و**Largest Contentful Paint**

---

## ٥. خطة التحقق والاختبار

### ٥.١ من خطة العميل
- [ ] التقاط صور شاشة (Screenshots) لكل تعديل قبل وبعد التنفيذ
- [ ] اختبار كل شاشة على جميع المتصفحات والأجهزة
- [ ] مراجعة التعديلات مع فريق QA قبل الإطلاق

### ٥.٢ إضافات Copilot
- [ ] **flutter widget tests** للـ `ApexListToolbar` و الـ chips logic
- [ ] **integration tests** بـ Patrol أو Flutter Driver لكل سيناريو رئيسي
- [ ] **A8 — Bulk export فعلي** (Excel + PDF، استبدال SnackBar الحالي)
- [ ] **Visual regression** بـ golden tests لكل screen + theme + breakpoint

---

## ٦. الموجات (Waves) — الترتيب التنفيذي

### 🌊 موجة ١ — توحيد الـ Toolbar + الـ wins السريعة (٣-٥ أيام) — **شبه مكتملة**

**الهدف:** كل شاشة قائمة تستخدم `ApexListToolbar` بسلوك متّسق، مع المفضلات المحفوظة، وbulk actions.

- [x] ١-١. حفظ هذه الخطة كـ `APEX_IMPROVEMENT_PLAN.md` ✅
- [x] ١-٢. **A1**: localStorage persistence للمفضلات في `ApexListToolbar` ✅ — commit `8617bdb`
- [x] ١-٣. **A2**: Bulk-select infrastructure ✅ — commit `8ea1857`
- [x] ١-٤. ربط زر "ذكاء" → drawer `ApexCopilotDrawer` مع `screenContext` ✅ — commit `637fac1`
- [ ] ١-٥. تطبيق `ApexListToolbar` على شاشة العملاء (مؤجَّل لموجة ٢)
- [ ] ١-٦. تطبيق `ApexListToolbar` على شاشة الموردين (مؤجَّل لموجة ٢)
- [x] ١-٧. Build + push + verify live ✅ — commit `c51637b`

### 🌊 موجة ٢ — تكامل AI الحقيقي + شاشات مستهدفة (٤-٦ أيام)

- [ ] ربط AI Copilot بـ Anthropic API streaming من backend
- [ ] **اقتراحات AI inline** للشاشات (banner + apply/dismiss)
- [x] تطبيق `ApexListToolbar` على شاشة العملاء ✅ — commit `7d6e104`
- [x] تطبيق `ApexListToolbar` على شاشة الموردين ✅ — commit `7d6e104`
- [ ] تطبيق `ApexListToolbar` على ٥ شاشات إضافية: المنتجات، GL، COA، JE Builder، المخزون
- [ ] **A3** — تخزين التفضيلات (آخر فلتر/تجميع/عرض) في localStorage لكل شاشة

### 🌊 موجة ٣ — Backend audit + Tests (٣ أيام)

- [x] `tools/api_audit.py` — فحص شامل ✅ — يفحص ٤٦٠ ملف، يطبع تقرير Markdown
  - **النتائج (الإصدار الأول):** 222 ملاحظة
    - 🔴 8 endpoints إدارية بدون `verify_admin`
    - 🔴 72 traceback leak (HTTPException يحوي str(e))
    - 🟡 10 endpoints بشكل response غير معياري
    - 🟡 132 silent except (لا يوجد `logging.error`)
  - تقرير حيّ في `docs/audit/api_audit.md`
- [ ] إصلاح الـ 🔴 errors (admin-unprotected + traceback-leak)
- [ ] إضافة pytests للـ POS / Sales Invoices / Purchase Invoices / ApexListToolbar
- [ ] flutter widget tests للـ chips + accordion logic
- [ ] تطبيق structured logging (A6)

### 🌊 موجة ٤ — صقل + a11y + responsive (٢-٣ أيام)

- [x] **A4 جزئي** — `Semantics` على زر المساعدة + أزرار bulk-action (مع `hint` على الـ destructive) ✅ — commit `8527f70`
- [ ] **A4 كامل** — Semantics على باقي العناصر + keyboard navigation
- [ ] **A5** — Responsive breakpoints
- [ ] **A7** — Code-splitting (الباندل ٩.٥MB يحتاج تخفيض)
- [ ] **A8** — Bulk export فعلي (Excel + PDF بدل SnackBar)
- [ ] **A9** — Optimistic updates + offline queue
- [x] **A10** — محتوى help dialog (نصائح مع شرح + الاختصارات) ✅ — commit `8527f70`
  - مطبَّق على فواتير المبيعات بـ ٤ نصائح كاملة
  - بقية الشاشات تحتاج إضافة `tips: [...]` في الـ build
- [ ] مراجعة كل theme + dark/light + screenshots للتحقق

---

## ٧. تتبّع التقدّم

| الموجة | الحالة | عدد المهام | المُنجَز |
|---------|--------|--------------|---------|
| ١ — Toolbar + wins | ✅ شبه مكتملة | ٧ | ٥ |
| ٢ — AI + شاشات | 🟡 ٢ من ٧ | ٧ | ٢ (عملاء + موردين) |
| ٣ — Backend + tests | 🟡 audit script | ٤ | ١ |
| ٤ — Polish + a11y | 🟡 a11y + help dialog | ٧ | ٢ |

**التحديث الأخير:** بعد commit `d98f7ed` (Wave 4 a11y + help dialog).

### Commits الجلسة الحالية

| Commit | الموجة | البند |
|--------|--------|-------|
| `8617bdb` | ١ | A1 — favorites localStorage |
| `8ea1857` | ١ | A2 — bulk-select + sales/purchase rows |
| `637fac1` | ١ | AI Copilot drawer wiring |
| `c51637b` | ١ | Wave 1 build |
| `9c3a90c` | ١ | Plan progress تحديث |
| `7d6e104` | ٢ | Customers + Vendors migrated |
| `bcf69e9` | ٢ | Wave 2 build |
| `5818110` | ٣ | Backend audit script + first report |
| `8527f70` | ٤ | A4 Semantics + A10 enhanced help |
| `d98f7ed` | ٤ | Wave 4 build |

---

## ٨. إرشادات التنفيذ لـ Claude Copilot

- اعتمد `apex_finance/lib/widgets/apex_list_toolbar.dart` كأساس لكل toolbar
- اعتمد `AC.*` tokens فقط للألوان (لا hex values مباشرة)
- اعتمد `Directionality.rtl` صراحةً في كل widget جديد لضمان RTL
- اكتب tests قبل الـ commit متى أمكن
- صور قبل/بعد لكل شاشة
- commit واحد لكل موجة فرعية، رسالة بالعربي + Co-Authored-By: Claude
- ادفع المصدر أولاً ثم البناء (race-safe pattern)

---

*هذه الوثيقة مخصصة لفريق Claude Copilot لتنفيذ خطة التحسينات بشكل دقيق ومنهجي على آخر نسخة من الكود.*
