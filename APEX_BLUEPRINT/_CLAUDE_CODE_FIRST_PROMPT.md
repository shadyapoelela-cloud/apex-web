# 🎯 الأمر التنفيذي الكامل لـ Claude Code — مرحلة Q1 2026 الكاملة

> **هذا الأمر يجعل Claude Code يُنفذ مرحلة كاملة (~10 أسابيع عمل في 30+ مهمة) بدون توقفات وسطية.**
> **يعود فقط بتقرير نهائي واحد عند انتهاء المرحلة بالكامل.**

---

## 📋 طريقة الاستخدام

1. افتح Claude Code جديد في `C:\apex_app\`
2. انسخ كل النص بين السطرين `═══` أدناه
3. ألصقه كأول رسالة
4. اضغط Enter
5. **لا تتدخل** حتى يأتيك تقرير "**PHASE 1 COMPLETE — Q1 2026**"

═══════════════════════════════════════════════════════════════

# المهمة: تنفيذ مرحلة Q1 2026 الكاملة بدون توقفات

## ⚠️ القاعدة الذهبية الأهم — اقرأها 3 مرات قبل أن تبدأ

> **أنت لن تتوقف ولن تطلب تأكيداً ولن تُقدّم تقريراً وسطياً حتى تنهي المرحلة كاملة (4 sprints · 30+ مهمة · ~10 أسابيع عمل مكثّف).**
>
> **You will NOT stop, NOT ask for confirmation, NOT provide intermediate reports until the ENTIRE phase is complete (4 sprints · 30+ tasks · ~10 weeks of intensive work).**

### التوقفات الوحيدة المسموحة (ثلاثة فقط):

| ✅ مسموح | ❌ ممنوع |
|---------|---------|
| ✅ بعد إكمال **كل** Sprint 7+8+9+10 | ❌ "هل تريد أن أكمل المهمة التالية؟" |
| ✅ blocker قاتل لا يمكن تجاوزه (مفتاح API لا يوجد لـ ALL أعمال البقية) | ❌ "أنجزت الجزء X، هل أكمل؟" |
| ✅ خطر أمني كارثي يحتاج قرار من المستخدم | ❌ "هذا تعديل كبير، هل تأكدت؟" |
| | ❌ "النص أصبح طويلاً" |
| | ❌ "أحتاج توضيحاً عن X" — اقرأ الوثائق وأكمل بأفضل اجتهاد |
| | ❌ "أعتقد أن هذا يكفي لجلسة واحدة" |
| | ❌ "هل تريد سبرنت 8 الآن أم لاحقاً؟" |

### عقوبة المخالفة:
إذا توقفت لأي سبب غير الثلاثة المسموحة → **عُد فوراً وأكمل** بنفس الجلسة دون انتظار رد.

---

## 1. الهوية والسياق

أنت **Lead Senior Software Engineer** متخصص في Python (FastAPI) و Dart (Flutter) و PostgreSQL، تعمل على منصة **APEX** — منصة سعودية مالية/مراجعة/ERP باللغة العربية أساساً، منشورة على Render.com.

**الموقع الجذر:** `C:\apex_app\`

**التقنيات:**
- Backend: FastAPI 0.115 · Python 3.11 · SQLAlchemy 2 · PostgreSQL · JWT HS256 · bcrypt · Alembic
- Frontend: Flutter Web · Riverpod · GoRouter · IBM Plex Sans Arabic
- AI: Anthropic Claude (Copilot, Knowledge Brain, classification)
- External: Stripe · ZATCA Phase 2 · SAMA Open Banking · Twilio · Unifonic · SendGrid · S3
- Tests: pytest (204 baseline) · flutter_test · Black 120ch · Ruff · Bandit
- DevOps: GitHub Actions · Render.com · Docker

---

## 2. النطاق الكامل لهذه الجلسة (Phase 1: Q1 2026 Foundation)

```
Sprint 7 (الأسبوع 1-2):   8 مهام  — Foundation
Sprint 8 (الأسبوع 3-4):   7 مهام  — Quality & Compliance
Sprint 9 (الأسبوع 5-8):   8 مهام  — Multi-Country E-invoicing
Sprint 10 (الأسبوع 9-10): 7 مهام  — UX Polish + i18n
═══════════════════════════════════════════════
الإجمالي: 30 مهمة في مرحلة واحدة
```

**هذا هو "المرحلة الكاملة" التي يجب إنجازها قبل أن تتوقف.**

---

## 3. خطة القراءة الإلزامية (40 دقيقة فقط)

اقرأ هذه الـ 5 وثائق بالترتيب الدقيق:

```
1. C:\apex_app\APEX_BLUEPRINT\_BOOTSTRAP_FOR_CLAUDE_CODE.md         (15 KB · 10 د)
2. C:\apex_app\APEX_BLUEPRINT\00_MASTER_INDEX.md                    (12 KB · 5 د)
3. C:\apex_app\APEX_BLUEPRINT\09_GAPS_AND_REWORK_PLAN.md            (23 KB · 10 د)
4. C:\apex_app\APEX_BLUEPRINT\10_CLAUDE_CODE_INSTRUCTIONS.md        (27 KB · 10 د)
5. C:\apex_app\APEX_BLUEPRINT\11_INTEGRATION_GUIDE.md               (22 KB · 5 د)
```

**بعد القراءة:** أعطني تأكيداً قصيراً (3 جمل فقط) ثم **ابدأ فوراً Sprint 7 المهمة 1 (G-A1)**.

**لا تنتظر رداً مني.** لا تسأل "هل أبدأ؟". ابدأ.

---

## 4. مراجع للقراءة عند الحاجة (لا تقرأها كلها مسبقاً)

ارجع إليها فقط عند الحاجة لسياق معين:

| الموضوع | الملف |
|---------|-------|
| المعمارية | `C:\apex_app\APEX_BLUEPRINT\01_ARCHITECTURE_OVERVIEW.md` |
| رحلات المستخدم | `C:\apex_app\APEX_BLUEPRINT\02_USER_JOURNEYS_FLOWCHART.md` |
| المسارات | `C:\apex_app\APEX_BLUEPRINT\03_NAVIGATION_MAP.md` |
| الشاشات والأزرار | `C:\apex_app\APEX_BLUEPRINT\04_SCREENS_AND_BUTTONS_CATALOG.md` |
| نقاط API | `C:\apex_app\APEX_BLUEPRINT\05_API_ENDPOINTS_MASTER.md` |
| الصلاحيات والخطط | `C:\apex_app\APEX_BLUEPRINT\06_PERMISSIONS_AND_PLANS_MATRIX.md` |
| ER ونموذج البيانات | `C:\apex_app\APEX_BLUEPRINT\07_DATA_MODEL_ER.md` |
| المعايير العالمية | `C:\apex_app\APEX_BLUEPRINT\08_GLOBAL_BENCHMARKS.md` |
| SAP Deep | `C:\apex_app\APEX_BLUEPRINT\12_SAP_DEEP_DIVE.md` |
| Odoo Deep | `C:\apex_app\APEX_BLUEPRINT\13_ODOO_DEEP_DIVE.md` |
| Frappe Deep | `C:\apex_app\APEX_BLUEPRINT\14_FRAPPE_DEEP_DIVE.md` |
| DDD Bounded Contexts | `C:\apex_app\APEX_BLUEPRINT\15_DDD_BOUNDED_CONTEXTS.md` |
| Business Processes | `C:\apex_app\APEX_BLUEPRINT\16_BUSINESS_PROCESSES.md` |
| State Machines | `C:\apex_app\APEX_BLUEPRINT\17_STATE_MACHINES.md` |
| الأمان والتهديدات | `C:\apex_app\APEX_BLUEPRINT\18_SECURITY_AND_THREAT_MODEL.md` |
| النشر | `C:\apex_app\APEX_BLUEPRINT\19_DEPLOYMENT_TOPOLOGY.md` |
| منظومة التكامل | `C:\apex_app\APEX_BLUEPRINT\20_INTEGRATION_ECOSYSTEM.md` |
| قوالب الصناعات | `C:\apex_app\APEX_BLUEPRINT\21_INDUSTRY_TEMPLATES.md` |
| التسويق | `C:\apex_app\APEX_BLUEPRINT\22_MARKETING_AND_GTM.md` |
| معايير المراجعة | `C:\apex_app\APEX_BLUEPRINT\23_AUDIT_DEEP.md` |
| CRM | `C:\apex_app\APEX_BLUEPRINT\24_CRM_MODULE_DESIGN.md` |
| Project Management | `C:\apex_app\APEX_BLUEPRINT\25_PROJECT_MANAGEMENT.md` |
| DMS | `C:\apex_app\APEX_BLUEPRINT\26_DOCUMENT_MANAGEMENT_SYSTEM.md` |
| HR/Payroll السعودي | `C:\apex_app\APEX_BLUEPRINT\27_HR_PAYROLL_SAUDI_DEEP.md` |
| Business Intelligence | `C:\apex_app\APEX_BLUEPRINT\28_BUSINESS_INTELLIGENCE.md` |
| Customer Success | `C:\apex_app\APEX_BLUEPRINT\29_CUSTOMER_SUCCESS_OPS.md` |
| Helpdesk | `C:\apex_app\APEX_BLUEPRINT\30_HELPDESK_AND_SUPPORT.md` |
| Roadmap (Path to Excellence) | `C:\apex_app\APEX_BLUEPRINT\31_PATH_TO_EXCELLENCE.md` |
| Visual UI | `C:\apex_app\APEX_BLUEPRINT\32_VISUAL_UI_LIBRARY.md` |
| Templates | `C:\apex_app\APEX_BLUEPRINT\33_OUTPUT_SAMPLES_AND_TEMPLATES.md` |
| Diagrams Catalog | `C:\apex_app\APEX_BLUEPRINT\34_COMPLETE_DIAGRAMS_CATALOG.md` |
| Migration Cookbook | `C:\apex_app\APEX_BLUEPRINT\35_DATA_MIGRATION_COOKBOOK.md` |
| A11y & i18n | `C:\apex_app\APEX_BLUEPRINT\36_ACCESSIBILITY_AND_I18N.md` |
| Performance | `C:\apex_app\APEX_BLUEPRINT\37_PERFORMANCE_ENGINEERING.md` |
| Parallel Execution | `C:\apex_app\APEX_BLUEPRINT\_PARALLEL_EXECUTION_GUIDE.md` |

---

## 5. مجلدات العمل / Working Directories

```
الكود الموجود (تعدّل):
  C:\apex_app\app\                    ← Backend FastAPI (11 phases + 6 sprints + pilot + zatca + copilot)
  C:\apex_app\lib\                    ← Frontend Flutter
  C:\apex_app\tests\                  ← Backend tests (204 موجودة)
  C:\apex_app\alembic\                ← Migrations (فارغ — أنشئ baseline)
  C:\apex_app\requirements.txt
  C:\apex_app\pubspec.yaml            ← (إن لم يوجد، أنشئه)
  C:\apex_app\pyproject.toml
  C:\apex_app\render.yaml
  C:\apex_app\.env.example
  C:\apex_app\.github\workflows\ci.yml

الملفات الجديدة (أنشئها):
  C:\apex_app\PROGRESS.md                    ← أنشئه واحفظ التقدم بعد كل مهمة
  C:\apex_app\ACTIVE_SESSIONS.md             ← أنشئه (لمتابعة الجلسات)
  C:\apex_app\lib\screens\auth\               ← مجلد جديد
  C:\apex_app\lib\widgets\                    ← مجلد جديد
  C:\apex_app\lib\widgets\forms\              ← مجلد جديد
  C:\apex_app\lib\l10n\                       ← Sprint 10 — i18n
  C:\apex_app\app\uae_einvoicing\             ← Sprint 9 — UAE FTA
  C:\apex_app\app\egypt_einvoicing\           ← Sprint 9 — Egypt ETA
  C:\apex_app\app\core\encryption.py          ← Sprint 7 — ZATCA encryption
  C:\apex_app\app\core\middleware\rate_limit.py    ← Sprint 8
  C:\apex_app\app\core\idempotency.py         ← Sprint 8
  C:\apex_app\test\widget\                    ← Flutter widget tests
  C:\apex_app\alembic\versions\               ← migrations files

تحديث بعد كل مهمة:
  C:\apex_app\APEX_BLUEPRINT\09_GAPS_AND_REWORK_PLAN.md  ← شطب ✓
  C:\apex_app\PROGRESS.md                                ← Sprint progress
```

---

## 6. ⚡ Sprint 7 — Foundation (الأسبوع 1-2 · 8 مهام)

### G-A1 — تقسيم `lib/main.dart` من 3500 إلى < 200 سطر
**Branch:** `sprint-7/g-a1-split-main-dart`
**خطوات:**
1. `grep -nE "^class \w+" lib/main.dart` لجرد classes
2. صنّفها: auth → `lib/screens/auth/`، MainNav → `lib/widgets/main_nav.dart`، forms → `lib/widgets/forms/`
3. انقل **class واحد في كل commit** مع `flutter analyze` و `flutter build web` بين كل خطوتين
4. تحقق: `wc -l lib/main.dart` < 200 ✓

### G-A2 — حذف V4 router القديم
**Branch:** `sprint-7/g-a2-deprecate-v4`
1. `grep -r "core/v4" lib/` لإيجاد الاستخدامات
2. هاجر أي route لـ V5 إن وجد
3. `git rm -r lib/core/v4/`

### G-A3 — Alembic baseline migration
**Branch:** `sprint-7/g-a3-alembic-baseline`
1. `alembic revision --autogenerate -m "baseline_2026_04"`
2. عدّل `app/main.py` lifespan: استبدل `Base.metadata.create_all` بـ `command.upgrade(cfg, "head")`
3. CI test: `pytest tests/`

### G-S1 — bcrypt rounds 10 → 12
**Branch:** `sprint-7/g-s1-bcrypt-12`
1. عدّل `app/phase1/services/password_service.py`: `ROUNDS = 12`
2. أضف rotation في login: re-hash إذا hash bcrypt rounds < 12
3. اختبار: `tests/test_password_rotation.py`

### G-B1 — Real Google + Apple OAuth
**Branch:** `sprint-7/g-b1-oauth-real`
1. أضف `google-auth` و `pyjwt[crypto]` لـ requirements.txt
2. `app/phase1/services/social_auth_service.py`: validate Google ID token + Apple JWT
3. `.env.example`: `GOOGLE_CLIENT_ID=`, `APPLE_TEAM_ID=`, etc.
4. **إذا الـ credentials غير متوفرة** → كَمِّل الكود مع TODO ضمن نفس الـ commit، انتقل للمهمة التالية

### G-B2 — Real SMS via Twilio + Unifonic
**Branch:** `sprint-7/g-b2-sms-real`
1. أضف `twilio` و `httpx` لـ requirements.txt
2. Adapter pattern: `SmsProvider` interface + Twilio + Unifonic + Console
3. `.env.example`: `SMS_BACKEND=`, `TWILIO_*`, `UNIFONIC_*`
4. اختر provider بناءً على `+966` prefix → Unifonic

### G-Z1 — تشفير ZATCA private keys
**Branch:** `sprint-7/g-z1-zatca-encrypt`
1. أنشئ `app/core/encryption.py` باستخدام Fernet
2. SQLAlchemy `EncryptedString` type لـ `zatca_csids.private_key`
3. Migration: encrypt existing rows
4. `.env.example`: `ZATCA_KEY_ENCRYPTION_KEY=`

### G-T1 (start) — أول Flutter widget tests
**Branch:** `sprint-7/g-t1-flutter-tests`
1. أنشئ `test/widget/login_screen_test.dart` و `register_screen_test.dart` و `onboarding_wizard_test.dart`
2. كل test يتحقق: ترسم الشاشة، الحقول موجودة، validation تعمل
3. `flutter test`

**عند انتهاء Sprint 7:** انتقل **فوراً** إلى Sprint 8 بدون توقف.

---

## 7. ⚡ Sprint 8 — Quality & Compliance (الأسبوع 3-4 · 7 مهام)

### G-A4 — توحيد naming الـ endpoints (`/api/v1/*`)
**Branch:** `sprint-8/g-a4-endpoint-naming`
1. أضف aliases من المسارات القديمة لـ `/api/v1/*` (302 redirects)
2. وثّق التحول في `05_API_ENDPOINTS_MASTER.md`

### G-A5 — Tenant isolation audit
**Branch:** `sprint-8/g-a5-tenant-isolation`
1. افحص كل repository: `grep -r "db.query" app/`
2. كل query على tenant-scoped table يجب يفلتر بـ `tenant_id`
3. أضف SQLAlchemy event listener يُلقي exception لو query بدون tenant filter
4. أضف Postgres RLS policies لـ defense-in-depth
5. اختبارات `tests/test_tenant_isolation.py`

### G-A6 — Phase 9 endpoints redirect to Phase 1
**Branch:** `sprint-8/g-a6-phase9-aliases`
1. `/forgot-password`، `/reset-password`، `/profile` → 302 redirect إلى `/api/v1/auth/*`

### G-A7 — Idempotency keys (Stripe-style)
**Branch:** `sprint-8/g-a7-idempotency`
1. أنشئ `app/core/idempotency.py`
2. Middleware يفحص `Idempotency-Key` header
3. Cache نتيجة في Redis لـ 24h
4. طبّق على: `POST /api/v1/pilot/sales-invoices`, `/customer-payments`, `/zatca/invoice/build`

### G-A8 — Per-tenant rate limiting
**Branch:** `sprint-8/g-a8-rate-limit`
1. أنشئ `app/core/middleware/rate_limit.py` باستخدام `slowapi`
2. حدود لكل خطة:
   - Free: 1000/day
   - Pro: 50000/day
   - Business: 500000/day
   - Expert: 1M/day
   - Enterprise: unlimited

### G-S4 (start) — PII encryption
**Branch:** `sprint-8/g-s4-pii-encryption`
1. أنشئ `EncryptedString` type
2. طبّق على `users.email`, `users.phone` (مع migration)

### G-S8 — JWT secret rotation *(was G-S2 before 2026-05-01)*
**Branch:** `sprint-8/g-s8-jwt-rotation`
1. غيّر `JWT_SECRET` إلى `JWT_SECRETS` (list)
2. توقيع بأول واحد، تحقق بكل القائمة
3. وثّق rotation procedure في runbook

**عند انتهاء Sprint 8:** انتقل **فوراً** إلى Sprint 9.

---

## 8. ⚡ Sprint 9 — Multi-Country E-invoicing (الأسبوع 5-8 · 8 مهام)

### G-Z2 — ZATCA CSID auto-renewal
**Branch:** `sprint-9/g-z2-csid-renewal`
1. APScheduler job يومي يفحص CSIDs expiring < 30 days
2. يطلق renewal flow + ينبه admin

### G-E2 — FX revaluation at period end
**Branch:** `sprint-9/g-e2-fx-revaluation`
1. APScheduler job نهاية كل شهر
2. spot rate من API (مثل ECB أو SAMA)
3. revalue all foreign currency balances + post FX gain/loss JE

### G-Z3 (1/2) — UAE FTA e-invoicing module setup
**Branch:** `sprint-9/g-z3-uae-fta-setup`
1. أنشئ `app/uae_einvoicing/` module
2. PINT-AE schema validation
3. ASP integration interface (mock + production)
4. `.env.example`: `UAE_FTA_*`

### G-Z3 (2/2) — UAE FTA Phase 1 (manual submission)
**Branch:** `sprint-9/g-z3-uae-fta-phase1`
1. Build invoice in PINT-AE format
2. Submit to ASP (real or mock)
3. Receive cleared XML

### G-Z4 (1/2) — Egypt ETA e-invoicing module setup
**Branch:** `sprint-9/g-z4-egypt-eta-setup`
1. أنشئ `app/egypt_einvoicing/` module
2. JSON/XML format
3. E-Seal signature integration
4. UUID generation per ETA spec

### G-Z4 (2/2) — Egypt ETA submission
**Branch:** `sprint-9/g-z4-egypt-eta-submission`
1. REST API integration with ETA
2. Sandbox + production toggles

### G-E3 — Recurring invoices auto-issuance
**Branch:** `sprint-9/g-e3-recurring-invoices`
1. APScheduler job daily 8AM
2. يجد recurring invoices المستحقة
3. ينشئ + يصدر + يرسل email

### G-E4 — 3-way match for purchases
**Branch:** `sprint-9/g-e4-three-way-match`
1. عند post bill: تحقق match مع PO + receipt
2. tolerance: price ≤2% أو ≤100 SAR، qty exact
3. exception queue للـ mismatches

**عند انتهاء Sprint 9:** انتقل **فوراً** إلى Sprint 10.

---

## 9. ⚡ Sprint 10 — UX Polish + i18n (الأسبوع 9-10 · 7 مهام)

### G-F1 (start) — l10n / i18n system
**Branch:** `sprint-10/g-f1-l10n-setup`
1. أضف `flutter_localizations` و `intl` لـ pubspec.yaml
2. أنشئ `lib/l10n/app_ar.arb` و `app_en.arb`
3. حرّك أهم 50 string من hardcoded إلى ARB

### G-F2 — TODO implementations
**Branch:** `sprint-10/g-f2-todo-cleanup`
1. `lib/screens/coa_v2/coa_journey_screen.dart:66` — connect to backend
2. `lib/screens/operations/receipt_capture_screen.dart:60,83` — real OCR + expense POST
3. `lib/core/v5/apex_v5_service_shell.dart:212` — wire unread count

### G-F4 — Role-aware bottom nav
**Branch:** `sprint-10/g-f4-role-nav`
1. عدّل `lib/apex_bottom_nav.dart`
2. اقرأ `S.roles`، اظهر tabs مختلفة لكل role

### G-F5 — Skeleton loaders
**Branch:** `sprint-10/g-f5-skeleton`
1. أضف `shimmer` لـ pubspec.yaml
2. أنشئ `LoadingTable` و `LoadingCard` widgets
3. طبّق على كل list screen رئيسي

### G-F6 — Empty states
**Branch:** `sprint-10/g-f6-empty-states`
1. أنشئ `EmptyState` widget بـ illustration + CTA
2. طبّق على: `/sales/customers`, `/sales/invoices`, `/audit/engagements`، إلخ

### G-F7 — Hide demo routes in production
**Branch:** `sprint-10/g-f7-hide-demos`
1. لف `/sprint35-*` إلخ في `if (kDebugMode)`
2. أو حركها لـ `/demo/*` namespace مع role check

### G-F8 — Split api_service.dart
**Branch:** `sprint-10/g-f8-api-split`
1. قسّم `lib/api_service.dart` (1000 سطر) إلى:
   - `lib/api/auth_api.dart`
   - `lib/api/coa_api.dart`
   - `lib/api/pilot_api.dart`
   - `lib/api/zatca_api.dart`
   - `lib/api/copilot_api.dart`

**عند انتهاء Sprint 10:** Phase 1 (Q1 2026) **مكتملة**. اكتب التقرير النهائي.

---

## 10. القواعد الذهبية (تتجاوز كل تناقض)

1. ❌ **لا** classes في `C:\apex_app\lib\main.dart` — استخرج إلى `lib/screens/{service}/`
2. ❌ **لا** base URL ثابت — استورد من `lib/core/api_config.dart`
3. ❌ **لا** HTTP من شاشة — أضف method في `lib/api_service.dart`
4. ❌ **لا** `import 'module' as *;`
5. ❌ **لا** `JWT_SECRET` ثابت — استخدم `app/core/auth_utils.py`
6. ❌ **لا** اختبارات متخطّاة
7. ❌ **لا** tracebacks للعميل — `logging.error()` + generic `HTTPException`
8. ❌ **لا** تجاوز `TenantContextMiddleware` — كل query يفلتر بـ `tenant_id`
9. ❌ **لا** اختراع pattern للـ auth — استخدم `Depends(get_current_user)`
10. ❌ **لا** تتخطى تحديث الوثائق
11. ❌ **لا** push إلى main — دائماً branch + PR
12. ❌ **لا** force push
13. ❌ **لا** secrets أو `.env` في git
14. ❌ **لا** console.log أو print debug في production

---

## 11. أوامر التحقق الإلزامية قبل كل commit

```bash
cd C:\apex_app

# Backend
black app\ tests\ --line-length 120 --check
ruff check app\ tests\ --fix
bandit -r app\ -ll
pytest tests/ -v --cov=app --cov-report=term-missing
# Coverage يجب لا يقل

# Frontend
flutter analyze lib\
flutter test  # widget tests
flutter build web --release  # يجب ينجح
```

---

## 12. تنسيق Commits (Conventional Commits)

```
feat(scope): description (#GAP-ID)        — ميزة جديدة
fix(scope): description (#GAP-ID)         — إصلاح bug
refactor(scope): description (#GAP-ID)    — إعادة تنظيم
test(scope): description (#GAP-ID)        — اختبارات
chore(scope): description (#GAP-ID)       — صيانة
security(scope): description (#GAP-ID)    — أمان
docs(scope): description (#GAP-ID)        — وثائق
```

---

## 13. عند العلق (Blockers) — ماذا تفعل بالضبط

### Blocker حقيقي ≠ توقف

عند مواجهة blocker:
1. ⛔ **لا تتوقف عن الجلسة**
2. ✏️ سجّل في `C:\apex_app\PROGRESS.md`:
   ```markdown
   ## Blockers (Phase 1)
   - G-B1: Google OAuth — كَمّلت الكود، blocker = `GOOGLE_CLIENT_ID` غير موجود في .env
   ```
3. ✅ كمّل الكود بأقصى حد ممكن مع TODO واضح
4. ⏭️ **انتقل فوراً للمهمة التالية**

### مثال realistic:
```
G-B1: Google OAuth code complete، لكن لا أستطيع اختبار end-to-end بدون GOOGLE_CLIENT_ID.
✅ سأكمل الكود + اختبارات mocked
✅ TODO في .env.example
✅ PR مفتوح (في انتظار user يضيف credential)
⏭️ الآن أنتقل لـ G-B2 (SMS)
```

**أبداً** لا تقول "أحتاج هذا قبل أن أكمل". **دائماً** اكمل ما تستطيع وانتقل.

---

## 14. التقرير النهائي (فقط بعد إنهاء الـ 30 مهمة)

عند انتهاء Sprint 10 (آخر مهمة في Phase 1)، اكتب تقرير واحد بهذا الشكل:

```markdown
# 🎉 PHASE 1 COMPLETE — Q1 2026 Foundation

**Duration:** [actual time taken]
**Tasks completed:** 30 of 30 (or 28 of 30 with 2 blocked)
**PRs opened:** 30
**Tests added:** [count]
**Coverage:** 62% → [new %]

---

## Sprint 7 — Foundation ✅
- [x] G-A1: Split main.dart (3500 → 187 lines) — PR #1
- [x] G-A2: V4 router removed — PR #2
- [x] G-A3: Alembic baseline — PR #3
- [x] G-S1: bcrypt 10→12 — PR #4
- [⛔] G-B1: Google OAuth code complete — blocker: credentials needed
- [⛔] G-B2: SMS code complete — blocker: Twilio account needed
- [x] G-Z1: ZATCA encryption — PR #7
- [x] G-T1: Flutter tests — PR #8

## Sprint 8 — Quality & Compliance ✅
- [x] G-A4: Endpoint naming standardization — PR #9
- [x] G-A5: Tenant isolation audit — PR #10
- [x] G-A6: Phase 9 aliases — PR #11
- [x] G-A7: Idempotency keys — PR #12
- [x] G-A8: Rate limiting — PR #13
- [x] G-S4: PII encryption — PR #14
- [x] G-S8: JWT rotation — PR #15  *(was G-S2 before 2026-05-01)*

## Sprint 9 — Multi-Country E-invoicing ✅
- [x] G-Z2: CSID auto-renewal — PR #16
- [x] G-E2: FX revaluation — PR #17
- [x] G-Z3: UAE FTA module — PR #18, #19
- [x] G-Z4: Egypt ETA module — PR #20, #21
- [x] G-E3: Recurring invoices — PR #22
- [x] G-E4: 3-way match — PR #23

## Sprint 10 — UX Polish + i18n ✅
- [x] G-F1: l10n system — PR #24
- [x] G-F2: TODO implementations — PR #25
- [x] G-F4: Role-aware nav — PR #26
- [x] G-F5: Skeleton loaders — PR #27
- [x] G-F6: Empty states — PR #28
- [x] G-F7: Hide demos — PR #29
- [x] G-F8: API split — PR #30

---

## ⛔ Blockers (تحتاج action من User)
1. **G-B1**: لتفعيل Google OAuth، أضف لـ `.env`:
   - `GOOGLE_CLIENT_ID=...`
2. **G-B2**: لتفعيل SMS الفعلي، أضف:
   - `TWILIO_ACCOUNT_SID=...`
   - `TWILIO_AUTH_TOKEN=...`
   - `UNIFONIC_APP_SID=...`

---

## 📊 المقاييس النهائية

| المقياس | قبل | بعد | التحسن |
|---------|-----|-----|--------|
| `lib/main.dart` | 3500 سطر | 187 سطر | -95% |
| Backend tests | 204 | XXX | +XX |
| Flutter tests | 0 | 12+ | +12 |
| Test coverage | 62% | XX% | +X% |
| P0 gaps closed | 0 | 18 | -18 |
| Endpoints standardized | 60% | 100% | +40% |

---

## 📝 Blueprint Updates
- `09_GAPS_AND_REWORK_PLAN.md` updated ✓
- `PROGRESS.md` created with full timeline ✓
- `ACTIVE_SESSIONS.md` created ✓
- `05_API_ENDPOINTS_MASTER.md` updated for v1 prefixes ✓
- `06_PERMISSIONS_AND_PLANS_MATRIX.md` updated for rate limits ✓

---

## 🚀 Sprint 11 Readiness (Q2 2026 — Core Modules)

Foundation complete. Ready to start **Q2 2026 Core Modules**:
- Universal Journal refactor
- DMS module v1
- CRM module v1

**Recommendation:** Use `_PARALLEL_EXECUTION_GUIDE.md` § 7 to spin up 3 parallel sessions.

---

— Claude Code Session, [Date]
**END OF PHASE 1.**
```

---

## 15. نصيحة أخيرة منّي (الـ Architect)

أنت ستعمل ~10 أسابيع كاملة على هذه المهمة. إنه عمل ضخم. لكن:

- 📜 **لديك 41 وثيقة** تجيب على كل سؤال معماري
- 🗺️ **خارطة Q1 2026** واضحة (4 sprints · 30 مهمة)
- 🎯 **كل مهمة لها acceptance criteria**
- ✅ **القواعد الذهبية تحسم الخلافات**
- 🚀 **لا تتوقف ولا تسأل — أكمل**

**أنت لست وحيداً.** الوثائق هي الـ senior engineer الذي يجيبك. الكود الموجود هو الأساس. الـ tests هي الأمان.

**ابدأ الآن. عُد بعد الـ 30 مهمة.**

---

## 16. التزامك معي / Your Commitment

ضع توقيعاً مكتوباً في أول رسالة منك:

```
أتعهد:
✅ سأقرأ الـ 5 وثائق في 40 دقيقة
✅ سأبدأ G-A1 فوراً بعدها
✅ سأنجز كل مهام Sprint 7 (8) بدون توقف
✅ سأنتقل تلقائياً لـ Sprint 8 ثم 9 ثم 10
✅ سأُنفذ 30 مهمة في هذه الجلسة
✅ سأحدّث PROGRESS.md بعد كل مهمة
✅ سأفتح PR لكل branch
✅ سأحترم القواعد الذهبية
✅ لن أتوقف لأسأل "هل أكمل؟"
✅ التقرير الوحيد سيكون "PHASE 1 COMPLETE"

— Claude Code, [Date]
```

ثم ابدأ القراءة.

---

**🎯 ابدأ الآن. لا تتوقف. أكمل المرحلة كاملة.**

═══════════════════════════════════════════════════════════════

## 17. ملاحظة للمستخدم (Shadi) بعد لصق الأمر

**ما عليك فعله:**

1. ⏰ **انتظر** — التنفيذ المتوقع: 5-10 أيام عمل مكثف لـ Claude Code
2. 🔇 **لا تتدخل** حتى يأتيك "PHASE 1 COMPLETE"
3. 📥 **استلم التقرير النهائي** الذي يلخص الـ 30 مهمة + blockers
4. 🔍 **راجع الـ PRs**:
   ```bash
   cd C:\apex_app
   gh pr list
   gh pr view <number>
   ```
5. ✅ **ادمج PRs** بعد المراجعة
6. 🔑 **حُل blockers** (مفاتيح API الخارجية)
7. 🚀 **ابدأ Phase 2** (Q2 2026 Core Modules) بـ 3 محادثات متوازية

---

**هذا أكبر أمر تنفيذي يمكن إعطاؤه لـ Claude Code. استخدمه بحكمة.**
