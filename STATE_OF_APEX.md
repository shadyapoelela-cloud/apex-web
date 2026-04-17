# STATE_OF_APEX — الوضع الفعلي للكود

> تقرير تدقيق صادق يحلّ محلّ §2 في `APEX_UNIFIED_BLUEPRINT_V3.md` و§1 في `APEX_MASTER_BLUEPRINT.md`.
>
> **المصدر:** فحص مباشر للشجرة `brave-yonath` (`claude/brave-yonath` off `main` @ d3215a9).
> **التاريخ:** 2026-04-18
> **الطريقة:** grep + pytest --collect-only + ls على المسارات المدعاة.

---

## 1) الأرقام الفعلية vs المدعاة

| القياس | V3 يدّعي | Master يدّعي | الواقع | فرق |
|---|---:|---:|---:|---|
| Flutter routes | 61 | 63 | **99** | **+38 عن V3** |
| Flutter `.dart` files | — | — | **99** | — |
| FastAPI endpoints | 22 | 80+ | **368** | **أعلى بكثير — مسارات موزّعة على Phases/Sprints** |
| `APIRouter()` instances | — | — | **49** | — |
| `include_router(...)` calls | — | — | **43** | 6 موديولات معرّفة لكن غير مُضمّنة |
| Python files في `app/` | — | — | **294** | — |
| ملفات اختبار | — | — | **34** | — |
| اختبارات تُجمع | — | 705+ | **844** | — |
| اختبارات تنجح | 1,200+ | — | **842 pass · 2 skip · 0 fail** | V3 مبالغ |
| زمن تشغيل السويت | — | — | **~79 ثانية** | — |
| Alembic migrations | 2 | 1 | **1** (`2b92f970a8f9_initial_schema_74_models`) | Master أدق |

---

## 2) ملفات مدّعاة في V3 **غير موجودة فعلاً**

كل هذه مذكورة في `APEX_UNIFIED_BLUEPRINT_V3.md §2.1` كأنها مكتوبة:

| الملف | موجود؟ | ملاحظة |
|---|:---:|---|
| `app/core/activity_log.py` | ❌ | "Chatter timeline (4 routes)" — لا أثر |
| `app/core/auto_log.py` | ❌ | "SQLAlchemy event listener" — لا أثر |
| `app/core/tenant_guard.py` | ❌ | "SQLAlchemy event listeners + RLS" — لا أثر |
| `app/core/rls_session.py` | ❌ | "PostgreSQL RLS session GUC" — لا أثر |
| `app/core/notifications_api.py` | ❌ | لا |
| `app/core/offline_sync.py` | ❌ | لا |
| `app/core/tenant_branding.py` | ❌ | لا |
| `app/core/reports_download.py` | ❌ | لا |
| `app/core/system_health.py` | ❌ | لا |
| `app/core/zatca_submit_e2e.py` | ❌ | لا — يوجد `services/zatca_service` غير مفحوص |
| `app/ai/proactive.py` + `scheduler.py` + `routes.py` | ❌ | "6-hourly AI scans" — لا أثر |
| `app/integrations/zatca/invoice_pdf.py` | ❌ | لا — دليل `integrations/` غير موجود |
| Alembic migration ثانية `d3a1e9b4f201` (RLS) | ❌ | فقط migration واحدة |

**الخلاصة**: V3 §14 "Wiring Map" يعرض 🟢 على حلقات (Chatter live، bell، auto-log، proactive AI، ZATCA E2E) **لم تُبنَ أصلاً**.

---

## 3) ملفات Flutter مدّعاة **غير موجودة**

V3 §2.1 يدّعي 28 shared widget في `lib/core/apex_*.dart`. الواقع: **9 ملفات فقط** في `apex_finance/lib/core/`:

```
api_config.dart · api_retry.dart · design_tokens.dart · helpers.dart
router.dart · session.dart · shared_constants.dart · theme.dart · ui_components.dart
```

**كل** هذه مفقودة:
`ApexAppBar, ApexStickyToolbar, ApexBottomNav, ApexResponsive, ApexFlexibleColumns, ApexDataTable, ApexSyncfusionGrid, ApexFilterBar, ApexSavedViewsBar, ApexInlineEditable, ApexFormField, ApexSemanticField, ApexDashboardBuilder, ApexReportBuilder, ApexForecastChart, ApexBomTree, ApexKanban, ApexWorkOrderCard, ApexThreeWayMatch, ApexBarcodeInput, ApexVoiceInput, ApexCommandPalette, ApexCommandsRegistry, ApexAppSwitcher, ApexEntityBreadcrumb, ApexRecentItems, ApexNotificationBell, ApexShimmer, ApexStatusBar, ApexChatter, ApexChatterConnected, ApexWsClient, ApexWhiteLabel, ApexThemeGenerator, ApexContextualToolbar, ApexWorkflowRules, ApexAutoSave, ApexPreviewPanel, ApexIntegrationCard, ApexOfflineQueue, ApexA11y`

كذلك لا أثر لـ `WebSocket` في backend (`grep -r "WebSocket" app/` = 0 نتائج).

---

## 4) الحالة الفعلية للفجوات الأمنية (§2.1 من Master)

| الفجوة | Master يعطيها P0 | الواقع |
|---|---|---|
| Social auth stubs | نعم | **مؤكّد**: `app/phase1/routes/social_auth_routes.py` يحوي `⚠ WARNING: id_token is NOT validated` و `logging.warning("Google sign-in: id_token NOT verified")` |
| SMS 2FA stub | نعم | **مؤكّد**: لا أثر لـ `unifonic` أو `twilio` في الكود |
| Rate limiter in-memory | نعم | **مؤكّد**: `app/main.py:458-549` يستخدم `defaultdict(list)` في الذاكرة — لا `redis` في `requirements.txt` |
| JWT secret قصير | نعم | **مؤكّد**: تشغيل السويت يطبع `InsecureKeyLengthWarning: HMAC key is 11 bytes long` — fallback dev يطبّق في الاختبارات |
| Alembic بدون migrations | Master نعم | **مؤكّد جزئياً**: migration واحدة فقط (baseline للـ 74 model). أي تعديل schema بعد ذلك = drift يدوي |
| لا Sentry / observability | — | **مؤكّد**: `grep sentry app/` = 0 |

---

## 5) ما **موجود فعلاً** (الجانب الإيجابي)

### Backend
- **FastAPI app** تشتغل وتجمع **368 endpoint** موزّعة على `phase1..11` + `sprint1..6` + `core/*_routes.py`.
- **Phases 1-11 + Sprints 1-6** مُسجّلة في `app/main.py` خلف flags (HAS_P7، HAS_P8، ...).
- **`app/core/auth_utils.py`** فعلاً source-of-truth للـ JWT (لكن مع fallback dev).
- **Rate limiter** موجود ويعمل — فقط in-memory، ليس Redis.
- **CORS origins middleware** + **error_handlers** + **env validation `_validate_env`**.
- **Copilot AI** في `app/copilot/` + **Knowledge Brain** في `app/knowledge_brain/`.
- **COA Engine** في `app/coa_engine/`.
- **Compliance/ZATCA/Tax/IFRS/Payroll services** كاملة في `app/core/*_service.py`.

### Frontend
- **GoRouter** بـ 99 route في `apex_finance/lib/core/router.dart`.
- **`api_config.dart`** مركزي (جيد).
- **`api_retry.dart`** منطق إعادة المحاولة.
- **`theme.dart`** = `AC` theme singleton.
- **`session.dart`** = `S` session/localStorage.
- **Dart files 99** (أغلبها شاشات، بعضها helpers).

### Tests
- **842 pass · 2 skip · 0 fail** في ~79 ثانية.
- تغطية جيدة لـ: `coa_engine` (118)، `integration_v10` (93)، `copilot_notifications` (38)، `zatca` (28).
- تغطية ضعيفة: `admin` (4)، `auth` (6).

### Infra
- **Alembic** مُهيّأ مع `env.py` يستورد كل Phase models.
- **`pyproject.toml`**، **`pytest.ini`**، **`requirements.txt`**، **Render config** كلها موجودة.
- **GitHub Actions CI** في `.github/workflows/`.

---

## 6) التوصيات المنبثقة من التدقيق

1. **لا تعتمد على V3 كمرجع** — أرقامه وملفاته خيالية. `MASTER_BLUEPRINT` أقرب للواقع.
2. **الوثائق الثلاث تصف حالة مستهدَفة** لا حالة حالية — يجب ترقيم كل بند: "مبني / جزئي / غير مبني".
3. **قبل أي ميزة جديدة**، نغلق:
   - Wave 1 (أمن): JWT 32-byte enforce + social auth validation + TOTP حقيقي + Redis limiter + Sentry.
   - Wave 1.5 (V4 Shell) — بعد Wave 1 مباشرة، لأن بناء `apex_*.dart` widgets المزعومة = نفس كود Shell V4 الجديد. لا نبنيهم مرتين.
4. **Alembic**: migration واحدة لا تكفي — لكن `create_all` يعمل، لا نضيف الآن migrations جديدة حتى نلتقط أي drift عبر `alembic revision --autogenerate`.
5. **احذف من V3** كل ادعاء عن ملفات غير موجودة، أو ضع علامة `🟡 planned` بدل `🟢 live`.
6. **كلّ `apex_*.dart` widget مدّعى** = ticket في backlog V4. V4 Shell يشمل معظمها تلقائياً.

---

## 7) ما التالي

Wave 0 انتهت. المتابعة بـ **Wave 1 — Security Hardening**:

1. JWT_SECRET enforcement (fail-fast if <32 bytes)
2. Google/Apple token verification (google-auth + jose)
3. TOTP 2FA (`pyotp` + QR provisioning)
4. Redis-backed rate limiter (slowapi + redis)
5. Audit trail hash chain
6. Sentry + structured JSON logging
7. Strict env validation في production mode

كل بند = PR منفصل صغير، لا تجميع.

---

*Generated by Wave 0 audit · 2026-04-18 · claude/brave-yonath*
