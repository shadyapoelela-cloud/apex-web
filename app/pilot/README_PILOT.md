# APEX Pilot — Multi-tenant Retail ERP

وحدة Pilot هي الإصدار الإنتاجي لمنصّة APEX المُصمَّمة خصيصاً لمجموعات التجزئة في الخليج + مصر. هذه الوحدة مستقلّة عن Phases 1-11 القديمة.

---

## 📦 المكونات

| الطبقة | العدد | الموقع |
|---|---|---|
| جداول قاعدة البيانات | **42** | `app/pilot/models/` |
| مسارات REST | **121** | `app/pilot/routes/` |
| Pydantic schemas | **10+ ملفات** | `app/pilot/schemas/` |
| محرّكات خلفية | **3** (GL, ZATCA, Compliance) | `app/pilot/services/` |
| شاشات Flutter | **6 مباشرة + PilotClient** | `apex_finance/lib/pilot/` |

---

## 🗺️ الهيكلية

```
Tenant (المستأجر = مجموعة الشركات)
  └── Entity (كيان قانوني = شركة لكل دولة)
        └── Branch (فرع مادي = مدينة/حي)
              └── Warehouse (مستودع: رئيسي/خلفي/DC)
                    └── StockLevel (رصيد لكل variant)
              └── PosSession (وردية كاشير)
                    └── PosTransaction (فاتورة)
                          └── PosTransactionLine (بند)
                          └── PosPayment (دفعة — متعدد)
```

### الدومينات التسعة
1. **Tenant/Entity/Branch** — هيكل القابضة + الكيانات + الفروع
2. **Currency/FX** — متعدد العملات + فروق صرف
3. **RBAC** — Role + Permission + UserEntityAccess + UserBranchAccess
4. **Catalog** — Category/Brand/Attribute/Product/Variant/Barcode
5. **Warehouse/Stock** — مستودعات + أرصدة + حركات + transfers
6. **Pricing** — قوائم أسعار متعددة النطاقات + resolver
7. **POS** — ورديات + فواتير + دفعات + درج نقدية
8. **GL** — CoA + periods + JE + postings + auto-POS + TB/IS/BS
9. **Compliance** — ZATCA + GOSI + WPS + UAE CT + VAT Return

---

## 🚀 البدء السريع

### 1) تشغيل الباك-إند
```bash
# من مجلد المشروع الجذر
uvicorn app.main:app --reload --port 8000
```

### 2) بذر بيانات تجريبية كاملة للعميل
```bash
py scripts/seed_clothing_customer.py
```

يُنشئ:
- 1 مستأجر (مجموعة الأزياء المتطورة)
- 6 كيانات (SA, AE, QA, KW, BH, EG)
- 8 فروع + 8 مستودعات
- 10 منتجات × 77 متغيّر + 77 باركود EAN-13
- 3 قوائم أسعار
- قيد افتتاحي 2 مليون SAR
- ZATCA onboarding (simulated)
- موظف GOSI واحد

اكتب الـ `Tenant ID` الذي يظهر في آخر السكربت.

### 3) تشغيل Flutter
```bash
cd apex_finance
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

افتح `http://localhost:PORT/#/pilot` → انقر "اختر مستأجراً" → الصق `Tenant ID` → اختر كياناً ثم فرعاً.

---

## 📊 سيناريو العمل اليومي

### الكاشير
1. فتح وردية مع رصيد افتتاحي نقدي
2. مسح الباركود → إضافة للسلة تلقائياً (السعر يُحسَب من قائمة الأسعار)
3. الزبون يختار طريقة الدفع (نقد، مدى، تقسيط…)
4. إتمام البيع → النظام تلقائياً:
   - يسجّل `StockMovement` (سالب)
   - يُنشئ `JournalEntry` بترحيل كامل (نقد/مبيعات/VAT/COGS/مخزون)
   - يُولّد ZATCA QR + hash + يضيف للسلسلة (للكيانات السعودية)
5. في نهاية الوردية → Z-report يُظهر:
   - الفرق بين الرصيد الفعلي والمحسوب
   - تفصيل طرق الدفع
   - أفضل المنتجات مبيعاً

### المدير المالي
- يفتح Dashboard → يرى KPIs لحظية
- يشغّل ميزان المراجعة / قائمة الدخل / المركز المالي
- يراجع الإرساليات الضريبية (ZATCA + VAT Return)
- يُقفل الفترة الشهرية بعد اكتمال كل القيود

---

## 🇸🇦 الامتثال السعودي

### ZATCA المرحلة الثانية
- كل فاتورة POS تحصل على:
  - `UUID` فريد
  - `ICV` تسلسلي بلا فجوات
  - `invoice_hash` SHA-256
  - `previous_invoice_hash` (سلسلة محكمة)
  - `QR TLV` Base64 (Tags 1-6)
- في الإنتاج: استبدل `simulate_csid_issuance` في `zatca_engine.py` بـ REST call حقيقي إلى Fatoora portal

### GOSI
- نسب 2026 الفعلية: سعودي 9.75% موظف + 11.75% صاحب عمل
- حساب شهري + حفظ في `GosiContribution`
- Cap على الأجر: 1,500 - 45,000 SAR

### WPS (نظام حماية الأجور)
- توليد ملف SIF بصيغة SAMA:
  - `SCR` header (establishment, bank, IBAN, period, count, total)
  - `EDR` سطر لكل موظف
  - `TLR` trailer
- تحميل الملف عبر `/pilot/wps/batches/{id}/sif`

---

## 🇦🇪 الامتثال الإماراتي

### UAE Corporate Tax
- أول 375,000 AED معفى
- 9% على ما يتجاوز
- دعم خصم الضريبة المستقطعة (WHT credit)

### VAT Return (5%)
- محسوب تلقائياً من GL postings
- ربع سنوي افتراضياً

---

## 🛠️ تخصيص لعميل جديد

1. عدّل `scripts/seed_clothing_customer.py`:
   - غيّر بيانات `tenant` (slug، أسماء، CR، VAT)
   - عدّل `ENTITIES_DATA` حسب الدول المطلوبة
   - عدّل `BRANCHES_DATA` حسب الفروع
   - عدّل `PRODUCTS` حسب الكاتالوج
2. شغّل السكربت
3. استخدم الـ `Tenant ID` الجديد في Flutter

---

## 🔐 الصلاحيات (RBAC)

12 دور مُعد مسبقاً:
- super_admin, cfo, accounting_manager, accountant
- country_manager, branch_manager, pos_cashier
- hr_manager, warehouse_manager, purchasing_manager
- auditor, viewer

159 صلاحية عبر 14 فئة (admin, structure, security, finance, inventory, sales, pos, purchasing, hr, reports, docs, compliance, audit, ai).

مستويات النطاق:
- **tenant** — كل الكيانات (CFO، Super Admin)
- **entity** — شركة واحدة (Country Manager)
- **branch** — فرع واحد (Cashier، Branch Manager)

---

## 📈 التقارير المُتاحة

### من API:
- `GET /pilot/entities/{eid}/reports/trial-balance?as_of=YYYY-MM-DD`
- `GET /pilot/entities/{eid}/reports/income-statement?start_date=&end_date=`
- `GET /pilot/entities/{eid}/reports/balance-sheet?as_of=`
- `GET /pilot/vat-returns/preview?entity_id=&year=&period_number=&period_type=`
- `GET /pilot/pos-sessions/{sid}/z-report`

### من Flutter:
- لوحة المؤشرات (`/pilot` tab 1)
- تقارير GL بـ 3 علامات تبويب (`/pilot` tab 4)
- شاشة الامتثال بـ 4 بطاقات (`/pilot` tab 5)

---

## 🧪 الاختبارات E2E

الوحدة تحتوي على اختبارات E2E شاملة (خارج الـ commit، تُكتَب حسب الحاجة):

| اختبار | فحوصات | الحالة |
|---|---|---|
| Day 1 — Foundation | 8 | ✅ |
| Day 2 — Members + RBAC | 14 | ✅ |
| Day 3-4 — Catalog + Inventory | 15 | ✅ |
| Day 5 — Pricing resolver | 12 | ✅ |
| Week 2 — POS E2E | 11 | ✅ |
| Week 3 — GL (TB + IS + BS) | 13 | ✅ |
| Week 4 — Compliance | 9 | ✅ |

---

## 📝 معرفات `environment`

| Variable | للاستخدام |
|---|---|
| `DATABASE_URL` | `postgresql://...` للإنتاج، `sqlite:///./pilot.db` للتطوير |
| `ADMIN_SECRET` | مطلوب لـ `/admin/pilot/*` + `GET /pilot/tenants` |
| `API_BASE` (Flutter) | عنوان الباك-إند — `--dart-define=API_BASE=...` |

---

## 🤝 قائمة الكوميتس

| الكوميت | المرحلة |
|---|---|
| `1085654` | Day 1 foundation models |
| `d92e576` | Day 1b-e schemas + routes |
| `eb2e1e2` | Day 2 members + RBAC |
| `4f54f73` | Day 3-4 catalog + inventory |
| `b185ed0` | Day 5 price lists |
| `62c6b1e` | Week 2 POS |
| `70c02b7` | Week 3 GL |
| `bd9242d` | Week 4 compliance |
| `8e2c40f` | Week 5 Flutter UI |

---

**جاهز للإنتاج** ✅ — بحاجة فقط لـ:
1. ربط CSID حقيقي مع ZATCA Fatoora portal (استبدال simulate_csid_issuance)
2. دمج بوابة دفع حقيقية (بدل `PaymentMethod` placeholders في POS)
3. دمج طباعة الإيصال (Thermal printer driver)
