# APEX — تقرير فجوات شامل (Gap Audit)

> **التاريخ:** 2026-04-17
> **النطاق:** مقارنة الوضع الفعلي للـ repo مقابل:
> - Master Blueprint v2.0 (18 قسم، 30 ميزة قاتلة)
> - Hybrid V2 Execution File (160+ مهمة)
> - Roadmap to #1 (20 ميزة، Foundation Fixes)
> **الفرع:** `claude/priceless-lamarr`
> **الغرض:** خارطة قرارات لاختيار ما يُنفَّذ ومتى

---

## 1. الملخص التنفيذي

| المقياس | الحالي | المستهدف v2 |
|---------|--------|-------------|
| شاشات Flutter | **69** | ~150 |
| ملفات Python | ~294 | — |
| اختبارات | **34 ملف / 204 اختبار** | ≥80% coverage |
| Phases / Sprints | 11 Phase + 6 Sprint | + HR + Purchase + CRM + Inventory |
| اكتمال ERP | ~30% | 90% |
| مكوّنات Apex المشتركة | **1 من 9** (design_tokens فقط) | 9/9 |
| الأساسات الحرجة | 2/5 منجزة جزئياً | 5/5 |

**الخلاصة:** الأساس المحاسبي قوي (phases 1-11 + COA Engine v4.3 + Copilot)، لكن **طبقة المكونات المشتركة مفقودة تقريباً**، و**5 وحدات ERP كبرى غائبة كلياً** (HR, Purchase, CRM, Inventory, Integrations).

---

## 2. المرحلة صفر — إصلاح الأساسات (Foundation Fixes)

من `APEX_ROADMAP_TO_NUMBER_ONE.md`

| # | المهمة | الحالة | الدليل |
|---|--------|--------|--------|
| 0.1 | Alembic Migrations | **⚠️ مفعّلة جزئياً** | `alembic/versions/2b92f970a8f9_initial_schema_74_models.py` موجود، لكن `main.py` لا يزال يستدعي `Base.metadata.create_all()` + `reinit_db` endpoint |
| 0.2 | Social Auth حقيقي (Google/Apple) | **⚠️ STUB** | `phase1/routes/social_auth_routes.py` يحتوي تعليق صريح: "Production requires google-auth library" + "SMS verify called (STUB) — no real verification" |
| 0.3 | SMS Verification حقيقي | **❌ STUB فقط** | لا يوجد `app/core/sms_backend.py`، لا Unifonic، لا Twilio |
| 0.4 | Environment Validation صارم | **⚠️ جزئي** | `validate_production_env` موجود في `main.py` لكن لم يُوثَّق نطاقه |
| 0.5 | Rate Limiting عالمي | **⚠️ In-memory فقط** | موجود في `main.py` لكن: لا `slowapi`، لا Redis، "Replace with Redis-backed slowapi for multi-instance prod" بتعليق صريح |

**توصية:** هذه الخمس (1-2 أسبوع عمل) تحجب الإنتاج الآمن. ابدأ هنا.

---

## 3. طبقة المكونات المشتركة (Apex Reusable Layer)

من V2 Enhanced — Sprint 35 Foundation. هذه **الاستثمار الأعلى عائداً**: مكوّن واحد يُطبَّق في 7+ شاشات.

| المكوّن | الملف المتوقع | الحالة | التطبيق المطلوب |
|---------|---------------|--------|------------------|
| ApexDesignTokens | `core/design_tokens.dart` | **✅ موجود** | — |
| ApexDataTable | `core/apex_data_table.dart` | **❌ مفقود** | Clients, Invoices, COA, JEs, Providers, Audit, Subscriptions |
| ApexFilterBar | `core/apex_filter_bar.dart` | **❌ مفقود** | كل القوائم أعلاه |
| ApexStickyToolbar | `core/apex_sticky_toolbar.dart` | **❌ مفقود** | كل الشاشات (قوائم + نماذج) |
| ApexAutoSaveMixin | `core/apex_auto_save.dart` | **❌ مفقود** | Invoice, Client Wizard, JE |
| ApexFormField | `core/apex_form_field.dart` | **❌ مفقود** | كل النماذج |
| ApexPreviewPanel | `core/apex_preview_panel.dart` | **❌ مفقود** | Invoice/Client preview |
| ApexShimmer | `core/apex_shimmer.dart` | **❌ مفقود** | كل FutureBuilder |
| ApexStatusBar | `core/apex_status_bar.dart` | **❌ مفقود** | Workflows (Draft→Posted) |

**النتيجة:** `1 / 9` = **11%**. كل مهمة V2 تقريباً تعتمد على هذه الطبقة.

---

## 4. الميزات القاتلة (Killer Features) — الحالة لكل ربع

### الربع الأول (Q1) — الامتثال الإقليمي

| # | الميزة | الحالة | التفاصيل |
|---|--------|--------|----------|
| 1 | **ZATCA Phase 2** | **⚠️ جزئي (40%)** | `core/zatca_service.py` (440 سطر) + `zatca_routes.py` (218 سطر) + شاشة `zatca_invoice_builder_screen.dart`. ينقص: XAdES signing، CSID، TLV QR، Fatoora API، ICV/PIH chain (لا ذكر لها في الكود) |
| 2 | **UAE FTA + Corporate Tax** | **❌ مفقود** | لا `app/integrations/uae_fta/` |
| 3 | **Bank Statement OCR + Auto-Rec** | **⚠️ جزئي** | `ocr_service.py` + `bank_rec_service.py` موجودان، لكن لا parsers لبنوك سعودية/إماراتية، لا Matching engine بـ 4 طبقات |
| 4 | **WhatsApp Business** | **❌ مفقود كلياً** | لا `app/integrations/whatsapp/`، لا webhook |

### الربع الثاني (Q2) — الذكاء والأتمتة

| # | الميزة | الحالة | التفاصيل |
|---|--------|--------|----------|
| 5 | **Open Banking (SAMA + UAE)** | **❌ مفقود** | لا consent flow |
| 6 | **Arabic AI Copilot (NL→SQL)** | **⚠️ Copilot موجود، لا function calling** | `copilot_service.py` موجود لكن بدون tools / memory / voice |
| 7 | **Autonomous AP Agent** | **❌ مفقود** | لا inbox، لا 3-way match، لا payment scheduling |
| 8 | **GOSI + WPS Payroll** | **⚠️ EOSB فقط** | `core/eosb_service.py` + `core/payroll_service.py` + `core/payroll_routes.py` موجودة، لكن لا GOSI calculator، لا WPS file generator، لا leave management |
| 9 | **Mada + Apple Pay + STC Pay** | **❌ مفقود** | `payment_service.py` يدعم Stripe/Mock فقط |

### الربع الثالث (Q3) — التجربة الاحترافية

| # | الميزة | الحالة | التفاصيل |
|---|--------|--------|----------|
| 10 | **Dimensional Accounting** | **❌ مفقود** | لا branch/project/cost_center dimensions في JE |
| 11 | **Multi-Entity Consolidation** | **⚠️ service exists** | `consolidation_service.py` + `consolidation_routes.py` موجودة، لكن لا intercompany elimination، لا minority interest، لا FX translation |
| 12 | **Corporate Cards** | **❌ مفقود** | لا تكامل مع Yuze/NymCard |
| 13 | **Command Palette (Cmd+K)** | **❌ مفقود كلياً** | لا ذكر في أي ملف (`hybrid_sidebar.dart` ليس فيه Cmd+K — مخالف للـ blueprint) |
| 14 | **Composable Dashboards** | **⚠️ fixed layout** | `enhanced_dashboard.dart` موجود لكن بلا drag-drop، بلا block library |
| 15 | **Client Portal** | **❌ مفقود** | لا `apex-portal/` مستقل |

### الربع الرابع (Q4) — النظام البيئي

| # | الميزة | الحالة |
|---|--------|--------|
| 16 | Developer Platform (Public API + SDKs) | **❌ مفقود** |
| 17 | Industry Packs (F&B/مقاولات/عيادات/لوجستيك) | **❌ مفقود** |
| 18 | Startup Metrics Live (Burn/Runway/MRR) | **❌ مفقود** |
| 19 | Marketplace Enhanced (Revenue Share) | **⚠️ marketplace أساسي** | `service_catalog_screen.dart` + `provider_*` موجودة |
| 20 | Governed AI (Audit + Undo) | **❌ مفقود** | لا audit trail لـ AI actions |

---

## 5. وحدات ERP الجديدة (V2 Section 10)

| الوحدة | المسار المتوقع | الحالة | ملاحظات |
|--------|-----------------|--------|---------|
| HR & Payroll | `app/hr/` | **❌ مفقود** | يوجد `core/payroll_service.py` كبداية فقط |
| Enhanced Inventory | `app/inventory/` | **❌ مفقود** | يوجد `core/inventory_service.py` + شاشة فقط |
| Purchase Workflow | `app/purchasing/` | **❌ مفقود** | لا PO/Vendor Bill/3-way match |
| CRM Pipeline | `app/crm/` | **❌ مفقود** | لا leads/opportunities/Kanban |
| Integrations Hub | `app/integrations/` | **❌ مفقود** | لا ZATCA/UAE/WA/Open Banking كـ modules منفصلة |

---

## 6. Backend Architecture (V2 Section 11)

| # | المهمة | الحالة |
|---|--------|--------|
| 11.1 | Cursor-based Pagination | ❌ offset/limit حالياً |
| 11.2 | API Response Envelope | ✅ `{success, data, error}` مطبّق |
| 11.3 | Alembic Migrations | ⚠️ migration واحدة موجودة، startup لا يستخدمها |
| 11.4 | Redis Caching | ❌ مفقود |
| 11.5 | WebSocket Notifications | **❌ مفقود** (grep: 0 matches) |
| 11.6 | Background Task Queue | ⚠️ FastAPI BackgroundTasks فقط |
| 11.7 | Audit Log Middleware | ⚠️ `audit_trail_screen.dart` موجود، unclear backend depth |
| 11.8 | API Versioning `/api/v1/` | ❌ لا prefix |
| 11.9 | Request/Response Logging | ⚠️ logging عام فقط |
| 11.10 | Input Sanitization | ⚠️ Pydantic فقط |

---

## 7. الوحدات الجديدة في V2 (لم تكن في V1)

| القسم | الحالة |
|-------|--------|
| 13. Chatter & Activity Log Widget | **❌ مفقود كلياً** |
| 14. Flexible Column Layout (FCL) | **❌ مفقود** |
| 15. ZATCA Phase 2 Module | **⚠️ 40%** (في `core/` لا `integrations/`) |
| 16. Multi-Tenant SaaS Architecture | **❌ مفقود** (tenant_id، RLS، schema isolation) |
| 17. PWA & Offline-First | **⚠️ manifest.json موجود، flutter_service_worker.js مُولَّد، لكن لا IndexedDB offline logic** |
| 18. Enhanced Notification System | **⚠️ in-app + email فقط** (لا WebSocket، لا push) |

---

## 8. Accessibility & Responsive

| البند | الحالة |
|-------|--------|
| Responsive breakpoints | **⚠️ جزئي** — 38 occurrence لـ `LayoutBuilder/MediaQuery` في 31 ملف (غير منتظم) |
| WCAG 2.1 AA Semantics | **❌ غير مُوَثَّق** — لا `Semantics(label: ...)` منتشر |
| Focus indicators | **❌ غير مُوَثَّق** |
| Bottom nav للموبايل | **❌ مفقود** |
| Pull-to-refresh | **❌ مفقود** (لا `RefreshIndicator` في القوائم الرئيسية) |

---

## 9. Nice-to-haves ناقصة من النظام (غير مذكورة أعلاه)

- ❌ Keyboard shortcuts (Alt+1..9)
- ❌ Recent Items في الشريط الجانبي
- ❌ Favorites / Pinned Items
- ❌ Module Badge Counters
- ❌ Saved Filter Views
- ❌ Inline Editing في DataTables
- ❌ Arabic validators (IBAN/CR/VAT ZATCA/SAR)
- ❌ Draft auto-save store

---

## 10. نقاط القوة (يجب الحفاظ عليها)

| العنصر | السبب |
|---------|-------|
| ✅ COA Engine v4.3 | تصنيف 5 طبقات مع Claude — لا مثيل إقليمياً |
| ✅ 204 اختبار آلي | فوق المتوسط لمشروع بهذا الحجم |
| ✅ Backend-agnostic (Payment/Email/Storage) | تصميم ممتاز — يحفظ عند التوسع |
| ✅ Phase flags (HAS_P7..P11) | يمنع فشل startup عند تعطّل phase |
| ✅ Knowledge Brain + Marketplace | Copilot context مقدم على Wafeq/Qoyod |
| ✅ RTL-first + 12 theme | ميزة تنافسية أصلية |
| ✅ 11 Phase + 6 Sprint مكتمل | أساس مالي متين |

---

## 11. الأولويات المقترحة — 4 أسابيع القادمة

### الأسبوع 1: إصلاح الأساسات (Foundation Fixes)
```
[P0] 0.1  تفعيل alembic upgrade head في startup + تعطيل create_all
[P0] 0.2  Social Auth حقيقي (google-auth + apple JWKs)
[P0] 0.3  SMS backend: Unifonic + fallback (app/core/sms_backend.py)
[P0] 0.4  تقوية validate_production_env (كل المتغيرات الحرجة)
[P0] 0.5  ترقية Rate Limiter إلى slowapi + Redis backend
```

### الأسبوع 2: طبقة Apex المشتركة (من 1/9 إلى 7/9)
```
[P0] ApexDataTable           (3 أيام)
[P0] ApexFilterBar           (2 يوم)
[P0] ApexStickyToolbar       (1 يوم)
[P0] ApexAutoSaveMixin       (2 يوم)
[P0] ApexShimmer             (1 يوم)
[P0] ApexFormField           (2 يوم) — مع Arabic validators (IBAN/CR/VAT)
[P0] ApexPreviewPanel        (3 أيام)
```

### الأسبوع 3: تطبيق الطبقة + Command Palette
```
[P0] تطبيق ApexDataTable على Clients/Invoices/COA/JEs
[P0] تطبيق AutoSave على Invoice + Client Wizard + JE
[P0] Command Palette (Cmd+K) — Linear-grade فريد إقليمياً
```

### الأسبوع 4: ZATCA Phase 2 إلى 90%
```
[P0] XAdES-BES signer
[P0] TLV QR generator (VAT/timestamp/total/VAT)
[P0] Fatoora API client (clearance + reporting)
[P0] ICV + PIH chain (cryptographic stamp)
[P0] UI: 'حالة فاتورة ZATCA' مع retry queue
```

---

## 12. القرارات التي تحتاج منك

1. **هل نبدأ بالأساسات (0.1-0.5) أم الطبقة المشتركة؟**
   توصيتي: الأساسات أولاً — تحجب الإنتاج الآمن وتستغرق أسبوعاً فقط.

2. **هل ZATCA الحالي (40%) كافٍ مؤقتاً أم نرفعه فوراً؟**
   توصيتي: رفعه فوراً — الموعد النهائي يونيو 2026.

3. **هل نبني `app/integrations/` كطبقة موحّدة أم نبقي كل تكامل في `core/`؟**
   توصيتي: طبقة موحّدة — V2 Blueprint يتطلبها، وتسهّل الصيانة.

4. **هل نحافظ على `create_all()` كـ fallback للتطوير، أم ننتقل إلى Alembic فقط؟**
   توصيتي: Alembic للإنتاج، create_all للاختبارات.

5. **Priority على وحدات ERP الجديدة:**
   HR → Purchase → Inventory → CRM (بالترتيب حسب تأثير السوق السعودي).

---

*هذا التقرير ينمو — حدّثه بعد كل sprint بوضع ✅ بجانب المهام المكتملة.*
