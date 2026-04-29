# دليل الاختبار + ما المتبقي من الـ Target

> هذا الدليل يجاوب على سؤالين:
> 1. **ما المتبقي** من الحالة المثالية (To-Be) بعد جلسة 2026-04-29
> 2. **كيف نرى النتائج ونختبر** التغييرات اللي حصلت

---

## القسم 1 — ما المتبقي من الـ Target

### 🔴 P0 — حرجة (لازم لـ Production)

| # | البند | الحالة الحالية | الجهد التقديري |
|---|------|----------------|-----------------|
| 1 | **Real Google OAuth verification** | stub في `app/core/social_auth_verify.py` — التوكن مش متحقق منه | 3 أيام |
| 2 | **Real Apple Sign-In verification** | stub | 3 أيام |
| 3 | **Real AML check** | stub في `app/phase4/routes/...` | يحتاج اشتراك ComplyAdvantage/WorldCheck — 1-2 أسبوع |
| 4 | **JWT_SECRET fail-fast in prod** | dev fallback شغّال في prod لو env var غير محدد | يوم |
| 5 | **CORS_ORIGINS tightening** | `*` (مفتوح للكل) — CSRF risk | يوم |

### 🟠 P1 — عالية (تحسن جوهري للـ UX)

| # | البند | الحالة الحالية | الجهد |
|---|------|----------------|-------|
| 6 | **AI Onboarding Wizard** (QuickBooks-style conversational) | static form في `/app/erp/finance/onboarding` | أسبوعين |
| 7 | **Bank Feeds** (Yodlee/Plaid) | stub في `app/integrations/bank_ocr/` | 4 أسابيع |
| 8 | **Workflow Automation Engine** (Zoho-style rules) | غير موجود | 3 أسابيع |
| 9 | **Accountant Firm Hub** (FreshBooks-style multi-client SSO) | غير موجود | أسبوعين |
| 10 | **Receipt OCR Pipeline** (Wave-style snap-to-fill) | stub | أسبوعين |
| 11 | **Real Twilio SMS** | stub في `app/core/totp_service.py` | يومين |
| 12 | **Real WhatsApp Business API** | stub في `app/integrations/whatsapp/` | 3 أيام |
| 13 | **Period Close Lock enforcement** | partial في `app/core/period_close.py` | أسبوع |
| 14 | **Industry COA Templates** (Saudi/UAE/Kuwait/Egypt) | غير موجود | أسبوع |

### 🟡 P2 — متوسطة

| # | البند | الجهد |
|---|------|-------|
| 15 | Module Marketplace (Odoo-style enable/disable) | 3 أسابيع |
| 16 | Email-to-Invoice parsing | أسبوعين |
| 17 | Stripe Connect 3-Mode Onboarding (Hosted/Embedded/API) | أسبوعين |
| 18 | Bank OCR L4 (vendor matching ML) | 4 أسابيع |
| 19 | AP Agent Real Processors (تفعيل `app/features/ap_agent/real_processors.py`) | أسبوعين |
| 20 | Tax Calendar Auto-Population | أسبوع |
| 21 | **Adaptive Navigation الكامل** (مش بس demos، حسب الـ role + plan + onboarding state) | أسبوعين |

### 🔵 P3 — مستقبلية

Real-time Collab (Y.js)، GraphQL API، Voice Copilot، Mobile Native، Slack/Teams webhooks.

### ⚫ P4 — Roadmap طويل الأجل

Embedded Banking، Working Capital Loans، Corporate Cards، Investment Mgmt، Crypto Accounting.

### الخلاصة

- **الـ Target Diagrams فيها 10 مخططات محسّنة** — معظمها لسه غير منفّذ
- **جلسة 2026-04-29 ركزت على Cleanup + Governance** (RBAC للـ demos، أرشفة، orphan removal)
- **الـ Backend Hardening (P0)** = الأولوية القادمة قبل أي إطلاق فعلي
- **الجهد الإجمالي للـ Target الكامل**: ~6-9 أشهر مع فريق 3-4 مطورين (راجع [`diagrams/04-gap-analysis.md`](diagrams/04-gap-analysis.md) Gantt)

---

## القسم 2 — كيف نرى النتائج ونختبر

### 🚀 تشغيل محلي سريع (Flutter Web)

```bash
# من جذر المشروع
cd apex_finance
flutter pub get
flutter run -d chrome
```

أو بدون متصفح (server only):

```bash
flutter run -d web-server --web-port 8080
# ثم افتح http://localhost:8080
```

> **الـ Hot Reload شغّال**: عدّل ملف، احفظ، التطبيق يحدّث في الثانية بدون restart.

### 🏗️ Build لـ Production (statics)

```bash
flutter build web --release
# الـ output في build/web/
# سيرفه:
cd build/web && python3 -m http.server 8080
```

### 🐍 تشغيل الـ Backend محلياً (FastAPI)

```bash
# في تيرمنال منفصل (من جذر الريبو)
pip install -r requirements.txt
cp .env.example .env
# عدّل .env بقيم محلية (sqlite للـ DB، console للـ email)
uvicorn app.main:app --reload --port 8000
```

الـ Frontend بيكلّم الـ Backend عبر `lib/core/api_config.dart` — افتراضياً بيشاور على Render.com production. للتطوير المحلي، عدّل `apiBase` لـ `http://localhost:8000`.

---

## قائمة الاختبار (Smoke Tests) — تحقق من تغييرات الـ migration

### ✅ Test 1 — Bug Fix: `/financial-statements` route

**التغيير**: السطر 610 في router.dart كان يحجب الـ canonical implementation.

**اختبار يدوي**:
1. شغّل التطبيق
2. في الـ URL bar اكتب: `http://localhost:8080/#/financial-statements`
3. **المتوقّع**: تفتح شاشة `FinancialStatementsScreen` (مش redirect لـ `/compliance/financial-statements`)

**اختبار آلي** (lib/core/router.dart):
```bash
grep -c "path: '/financial-statements'" apex_finance/lib/core/router.dart
# المتوقّع: 1 (مش 2 كما كان قبل الإصلاح)
```

---

### ✅ Test 2 — RBAC: Demos Hidden from Non-Admin Users

**التغيير**: 13 demo route gated behind `S.isPlatformAdmin`.

**اختبار يدوي** كـ regular user:
1. سجّل دخول بحساب `client_user` أو `registered_user` (بدون admin role)
2. افتح `/whats-new` → **المتوقّع**: قسم "الواجهة المشتركة (Apex Layer)" + قسم "الموارد البشرية" + قسم "النظام البيئي" تظهر **بدون** tiles الـ demos (theme-generator, apex-map, syncfusion-grid, إلخ)
3. اضغط `Ctrl+K` (Cmd+K على Mac) → **المتوقّع**: مفيش commands بـ `nav_apex_showcase`, `nav_uae_corp_tax`, `nav_payments_playground`, إلخ
4. اكتب URL مباشر: `/payments-playground` → **المتوقّع**: redirect لـ `/app`

**اختبار يدوي** كـ admin:
1. سجّل دخول بحساب فيه role `platform_admin` أو `super_admin`
2. افتح `/whats-new` → **المتوقّع**: كل الـ tiles تظهر
3. `Ctrl+K` → **المتوقّع**: كل الـ demo commands ظاهرة
4. `/payments-playground` → **المتوقّع**: تفتح الشاشة

---

### ✅ Test 3 — GOSI + EOSB Promoted to Production

**التغيير**: `/gosi-demo` + `/eosb-demo` → graduated to `/hr/gosi` + `/hr/eosb`.

**اختبار يدوي** كـ regular user:
1. افتح `/hr/gosi` → **المتوقّع**: تفتح حاسبة GOSI/GPSSA مباشرة (مش redirect لـ `/app`)
2. افتح `/hr/eosb` → **المتوقّع**: تفتح حاسبة EOSB
3. افتح `/gosi-demo` → **المتوقّع**: redirect تلقائي لـ `/hr/gosi` (الـ URL في الـ bar يتغير)
4. افتح `/eosb-demo` → **المتوقّع**: redirect لـ `/hr/eosb`
5. افتح `/hr` → **المتوقّع**: في قسم "المخرجات — رواتب + GOSI" تشوف 4 tiles: تشغيل الرواتب، حاسبة GOSI، مكافأة نهاية الخدمة، قائمة القيود
6. اضغط `Ctrl+K` → اكتب "GOSI" → **المتوقّع**: command "حاسبة GOSI / GPSSA" ظاهر للجميع (مش admin only بعد الترقية)

---

### ✅ Test 4 — Sprint 40 + 42 Redirected to Production

**التغيير**: ميزات Sprint 40 + 42 كلها في إنتاج، الـ sprint screens اتأرشفوا.

**اختبار يدوي**:
1. `/sprint40-payroll` → **المتوقّع**: redirect لـ `/app/erp/hr/payroll` (تفتح Payroll V5.2)
2. `/sprint42-longterm` → **المتوقّع**: redirect لـ `/app/erp/treasury/cashflow` (تفتح Cashflow Forecast)
3. افتح `/whats-new` كـ admin → **المتوقّع**: الـ tile مكتوب فيه "graduated" — اضغطه يفتح المنتج مباشرة

---

### ✅ Test 5 — Orphan Files Excluded from Build

**التغيير**: 30 ملف orphan في `apex_finance/_archive/2026-04-29/` + `analysis_options.yaml` يستبعدهم.

**اختبار آلي**:
```bash
cd apex_finance
flutter analyze
# المتوقّع: 0 errors (300 issues مقبولة، كلها pre-existing infos/warnings)

# Verify _archive folder is excluded:
flutter analyze _archive/ 2>&1 | head -3
# المتوقّع: مش يحلل (excluded)
```

```bash
flutter build web --release 2>&1 | tail -3
# المتوقّع: build ناجح بدون أخطاء
```

---

### ✅ Test 6 — Working Routes Still Resolve (No Regressions)

تأكد إن كل الـ routes الشغّالة لسه تشتغل. عيّنة من URLs مهمة:

| URL | المتوقّع |
|-----|---------|
| `/login` | شاشة Slide Auth |
| `/app` | V5 Launchpad |
| `/today` | Today Dashboard |
| `/sales/customers` | Customers list |
| `/sales/invoices` | Invoices list |
| `/purchase/vendors` | Vendors list |
| `/accounting/je-list` | JE list |
| `/accounting/coa-v2` | COA tree v2 |
| `/accounting/bank-rec-v2` | Bank reconciliation |
| `/compliance/zatca-invoice` | ZATCA builder |
| `/compliance/zakat` | Zakat calculator |
| `/compliance/financial-statements` | Financial statements (canonical) |
| `/financial-statements` | FinancialStatementsScreen (with optional apiData) |
| `/operations/inventory-v2` | Inventory v2 |
| `/operations/fixed-assets-v2` | Fixed Assets v2 |
| `/analytics/cash-flow-forecast` | Cash Flow Forecast |
| `/analytics/budget-variance-v2` | Budget variance v2 |
| `/notifications` | Notification Center v2 |
| `/admin/dashboard` (admin only) | Admin dashboard |

---

### ✅ Test 7 — Backward Compat Redirects Still Work

كل الـ legacy redirects لسه شغّالة:

| URL القديم | يحوّل لـ |
|-----------|-----|
| `/coa-tree` (legacy) | `/accounting/coa-v2` (eventually) |
| `/compliance/budget-variance` | `/analytics/budget-variance-v2` |
| `/compliance/health-score` | `/analytics/health-score-v2` |
| `/compliance/inventory` | `/operations/inventory-v2` |
| `/compliance/fixed-assets` | `/operations/fixed-assets-v2` |
| `/compliance/aging` | `/sales/aging` |
| `/clients/onboarding` | `/settings/entities?action=new-company` |
| `/setup` | `/settings/entities` |
| `/onboarding` | `/app/erp/finance/onboarding` |

---

## كيف ترى المخططات (Mermaid)

### الطريقة 1 — رسومات PNG جاهزة
```bash
ls architecture/diagrams/rendered/
# 21 PNG file جاهزة للعرض
```
افتح [`architecture/diagrams/rendered/README.md`](diagrams/rendered/README.md) — كل الرسومات في table واحد.

### الطريقة 2 — VS Code
1. ثبّت extension: **Markdown Preview Mermaid Support** (id: `bierner.markdown-mermaid`)
2. افتح أي ملف `.md` تحت `architecture/diagrams/`
3. `Ctrl+Shift+V` → الـ Mermaid يترسم تلقائياً

### الطريقة 3 — GitHub
الـ branch مرفوع على origin. أي ملف `.md` فيه Mermaid يترسم تلقائياً في صفحة الـ repo.

### الطريقة 4 — Mermaid Live Editor
[https://mermaid.live](https://mermaid.live) — نسخ كود من `.md` → الصق → render فوري + export PNG/SVG/PDF.

---

## CI/CD Verification

### قبل الـ merge

```bash
# 1. Lint Python (backend)
black --check app/
ruff check app/

# 2. Tests Python
pytest tests/ -v --cov=app

# 3. Flutter analyze (frontend)
cd apex_finance && flutter analyze
# المتوقّع: 0 errors

# 4. Flutter build
flutter build web --release
# المتوقّع: ناجح
```

GitHub Actions workflow في `.github/workflows/ci.yml` بيشغّل دي تلقائياً على كل push.

### بعد الـ merge — Deploy

- **Backend**: Auto-deploy لـ Render.com من الـ remote `render` (اللي عملنا fetch منه)
- **Frontend**: Auto-deploy لـ GitHub Pages من الـ branch `main`

---

## في حالة المشاكل

### Rollback كامل للجلسة
```bash
git reset --hard pre-migration-2026-04-29
git push --force origin claude/gracious-heyrovsky-4c71bf  # ⚠️ destructive
```

### Rollback لـ commit واحد
```bash
git revert <commit-hash>
git push origin claude/gracious-heyrovsky-4c71bf
```

### استعادة شاشة من الأرشيف
```bash
git mv apex_finance/_archive/2026-04-29/orphans/v4_erp/X_screen.dart \
       apex_finance/lib/screens/v4_erp/X_screen.dart
# + أعد import + GoRoute في router.dart يدوياً
flutter analyze  # تحقق
```

التفاصيل في [`migration/04-rollback.md`](migration/04-rollback.md).

---

## ملخص

| السؤال | الجواب |
|--------|--------|
| ما المتبقي من الـ Target؟ | معظمه (P0 backend hardening + P1/P2/P3 features). جلسة 2026-04-29 ركزت على cleanup + governance، مش feature work |
| كيف أرى النتائج؟ | `flutter run -d chrome` من `apex_finance/` — التطبيق يفتح في المتصفح |
| كيف أختبر التغييرات؟ | اتبع Tests 1-7 أعلاه — كلها يدوية + بعضها له اختبار آلي |
| كيف أرى المخططات؟ | `architecture/diagrams/rendered/` فيها 21 PNG، أو افتح `.md` في GitHub/VS Code |
| كيف أرجع لو حاجة كسرت؟ | `git revert <hash>` أو tag `pre-migration-2026-04-29` |
