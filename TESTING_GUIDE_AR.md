# 🧪 دليل الاختبار الشامل — APEX Pilot

**من التعريف الأول للعميل حتى إتمام دورة البيع والشراء الكاملة.**

اللغة: عربية — كل خطوة مع الطلب الدقيق، الاستجابة المتوقعة، ومكان التحقق في الواجهة.

---

## 📋 المتطلبات الأساسية

### القسم 0/أ — إعداد البيئة

```bash
# محلياً (الأسرع للاختبار):
cd C:\apex_app\.claude\worktrees\priceless-lamarr

# 1) تأكد من المكتبات
pip install 'pydantic[email]' email-validator

# 2) شغّل الباك-إند
uvicorn app.main:app --reload --port 8000
```

تحقق: افتح `http://localhost:8000/pilot/health` → يجب أن ترى:
```json
{"status": "ok", "module": "pilot", "version": "1.0.0"}
```

### القسم 0/ب — متغيرات البيئة

```bash
# Windows PowerShell
$BASE = "http://localhost:8000"
$ADMIN_SECRET = "apex-seed-admin"
```

أو إذا تستخدم curl:
```bash
# في كل الأمثلة سنستخدم:
BASE=http://localhost:8000
ADMIN=apex-seed-admin
```

---

## 🏢 الخطوة 1: بذر الصلاحيات (مرة واحدة)

**ما نفعله**: نُنشئ 159 صلاحية أساسية (استعراض/إنشاء/تعديل/اعتماد... لكل مورد).

**الطلب:**
```bash
curl -X POST "$BASE/admin/pilot/seed-permissions" \
  -H "X-Admin-Secret: $ADMIN"
```

**الاستجابة المتوقعة:**
```json
{"success": true, "result": {"total_permissions": 159, "added": 159, "existing": 0}}
```

**إذا أعدت التشغيل:** ستصبح `added: 0, existing: 159` — وهذا طبيعي (idempotent).

**✅ تحقق:**
```bash
curl "$BASE/pilot/permissions?category=finance" | head -c 500
```

---

## 🏛 الخطوة 2: إنشاء المستأجر (الشركة الأم)

**ما نفعله**: تعريف المجموعة القابضة — هذا هو جذر البيانات.

**الطلب:**
```bash
curl -X POST "$BASE/pilot/tenants" \
  -H "Content-Type: application/json" \
  -d '{
    "slug": "my-fashion-co",
    "legal_name_ar": "شركة الأزياء الراقية",
    "legal_name_en": "Premium Fashion Co.",
    "trade_name": "PFC",
    "primary_cr_number": "1010111222",
    "primary_vat_number": "310111222000003",
    "primary_country": "SA",
    "primary_email": "admin@premiumfashion.sa",
    "primary_phone": "+966501112222",
    "tier": "enterprise"
  }'
```

**الاستجابة المتوقعة:**
```json
{
  "id": "aaaa-bbbb-cccc-...",    ← احفظ هذا في متغير TID
  "slug": "my-fashion-co",
  "legal_name_ar": "شركة الأزياء الراقية",
  ...
  "status": "trial",
  "trial_ends_at": "2026-05-20T...",
  "features": {"zatca": true, "gosi": true, "wps": true, "uae_ct": true, "ai": true}
}
```

**💾 احفظ:** 
```bash
TID="aaaa-bbbb-cccc-..."   # الـ id من الاستجابة
```

**✅ تحقق:**
```bash
# استعرض الإعدادات التي بُذرت تلقائياً
curl "$BASE/pilot/tenants/$TID/settings"
# يجب أن ترى: base_currency=SAR, default_vat_rate=15, 4 مستويات approval_thresholds

# استعرض العملات المُفعَّلة تلقائياً (10 عملات)
curl "$BASE/pilot/tenants/$TID/currencies"

# استعرض الأدوار المُبذرة تلقائياً (12 دور: cfo, cashier, branch_manager...)
curl "$BASE/pilot/tenants/$TID/roles"
```

**Flutter:**
افتح `/#/pilot` → زر "اختر مستأجراً" → الصق `TID` → يجب أن يظهر اسم المستأجر في الأعلى.

---

## 🌍 الخطوة 3: إنشاء الكيانات (شركة لكل دولة)

**ما نفعله**: إنشاء 6 كيانات قانونية منفصلة (لأن كل دولة = شركة مستقلة).

**للسعودية (الأساسية):**
```bash
curl -X POST "$BASE/pilot/tenants/$TID/entities" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "SA",
    "name_ar": "الأزياء الراقية السعودية",
    "name_en": "Premium Fashion SA",
    "country": "SA",
    "type": "subsidiary",
    "functional_currency": "SAR",
    "cr_number": "1010111223",
    "vat_number": "310111223000003",
    "fiscal_year_start_month": 1
  }'
# احفظ id → EID_SA
```

**للإمارات:**
```bash
curl -X POST "$BASE/pilot/tenants/$TID/entities" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "AE",
    "name_ar": "الأزياء الراقية الإمارات",
    "name_en": "Premium Fashion UAE",
    "country": "AE",
    "type": "subsidiary",
    "functional_currency": "AED",
    "cr_number": "CN-111222",
    "vat_number": "100111222000003"
  }'
# احفظ id → EID_AE
```

**كرّر لقطر/كويت/بحرين/مصر** بنفس الأسلوب مع تغيير `code, country, functional_currency`.

| الدولة | code | country | العملة |
|---|---|---|---|
| السعودية | SA | SA | SAR |
| الإمارات | AE | AE | AED |
| قطر | QA | QA | QAR |
| الكويت | KW | KW | KWD |
| البحرين | BH | BH | BHD |
| مصر | EG | EG | EGP |

**✅ تحقق:**
```bash
curl "$BASE/pilot/tenants/$TID/entities"
# يجب أن تعود 6 كيانات
```

**Flutter:** في الـ picker ستظهر chips لكل كيان — اختر "SA".

---

## 🏪 الخطوة 4: إنشاء الفروع

**ما نفعله**: كل كيان فيه فرع واحد أو أكثر (متجر/معرض/مستودع).

### 4/أ — فرع الرياض
```bash
curl -X POST "$BASE/pilot/entities/$EID_SA/branches" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "SA-RIY-PANORAMA",
    "name_ar": "الرياض — بانوراما مول",
    "name_en": "Riyadh Panorama Mall",
    "country": "SA",
    "city": "Riyadh",
    "district": "العليا",
    "type": "retail_store",
    "pos_station_count": 2,
    "accepts_returns": true,
    "supports_delivery": true,
    "allowed_payment_methods": ["cash", "mada", "visa", "mastercard", "stc_pay", "apple_pay"]
  }'
# احفظ id → BID_RIY
```

### 4/ب — فرع جدة
```bash
curl -X POST "$BASE/pilot/entities/$EID_SA/branches" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "SA-JED-REDSEA",
    "name_ar": "جدة — ريد سي مول",
    "country": "SA",
    "city": "Jeddah",
    "type": "retail_store"
  }'
# احفظ id → BID_JED
```

**✅ تحقق:**
```bash
curl "$BASE/pilot/entities/$EID_SA/branches"
```

---

## 📦 الخطوة 5: إنشاء المستودعات

**ما نفعله**: كل فرع يحتاج مستودعاً واحداً على الأقل (ويمكن إضافة stockroom منفصل).

### 5/أ — المستودع الرئيسي لفرع الرياض
```bash
curl -X POST "$BASE/pilot/branches/$BID_RIY/warehouses" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "RIY-MAIN",
    "name_ar": "الرياض — رئيسي",
    "type": "main",
    "is_default": true,
    "is_sellable_from": true,
    "is_receivable_to": true,
    "allow_negative_stock": false
  }'
# احفظ id → WID_RIY_MAIN
```

### 5/ب — مستودع خلفي (اختياري)
```bash
curl -X POST "$BASE/pilot/branches/$BID_RIY/warehouses" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "RIY-STOCK",
    "name_ar": "الرياض — خلفي",
    "type": "stockroom",
    "is_default": false,
    "is_sellable_from": false
  }'
```

---

## 🎨 الخطوة 6: إعداد الكاتالوج

### 6/أ — شجرة التصنيفات

```bash
# الجذر
curl -X POST "$BASE/pilot/tenants/$TID/categories" \
  -H "Content-Type: application/json" \
  -d '{"code":"CLOTHING","name_ar":"ملابس","name_en":"Clothing","icon":"checkroom","sort_order":1}'
# احفظ id → CAT_ROOT

# فرع رجالي
curl -X POST "$BASE/pilot/tenants/$TID/categories" \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"MEN\",\"name_ar\":\"رجالي\",\"parent_id\":\"$CAT_ROOT\",\"sort_order\":1}"
# احفظ id → CAT_MEN

# فرع قمصان رجالي
curl -X POST "$BASE/pilot/tenants/$TID/categories" \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"MEN-SHIRTS\",\"name_ar\":\"قمصان رجالي\",\"parent_id\":\"$CAT_MEN\",\"default_vat_code\":\"standard\"}"
# احفظ id → CAT_SHIRTS
```

### 6/ب — العلامة التجارية
```bash
curl -X POST "$BASE/pilot/tenants/$TID/brands" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "APEX",
    "name_ar": "أبيكس فاشن",
    "name_en": "APEX Fashion",
    "country_of_origin": "SA"
  }'
# احفظ id → BRAND_APEX
```

### 6/ج — السمات (المقاس + اللون)

```bash
# سمة المقاس
curl -X POST "$BASE/pilot/tenants/$TID/attributes" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "size",
    "name_ar": "المقاس",
    "name_en": "Size",
    "type": "size",
    "is_required_for_variant": true,
    "values": [
      {"code": "XS", "name_ar": "صغير جداً", "sort_order": 1},
      {"code": "S",  "name_ar": "صغير",       "sort_order": 2},
      {"code": "M",  "name_ar": "وسط",        "sort_order": 3},
      {"code": "L",  "name_ar": "كبير",       "sort_order": 4},
      {"code": "XL", "name_ar": "كبير جداً", "sort_order": 5}
    ]
  }'

# سمة اللون
curl -X POST "$BASE/pilot/tenants/$TID/attributes" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "color",
    "name_ar": "اللون",
    "name_en": "Color",
    "type": "color",
    "is_required_for_variant": true,
    "input_type": "swatch",
    "values": [
      {"code": "WHITE", "name_ar": "أبيض",  "hex_color": "#FFFFFF"},
      {"code": "BLACK", "name_ar": "أسود",  "hex_color": "#000000"},
      {"code": "NAVY",  "name_ar": "كحلي", "hex_color": "#000080"}
    ]
  }'
```

### 6/د — منتج مع متغيّرات

قميص بولو بـ 4 مقاسات × 3 ألوان = 12 متغيّر في عملية واحدة:
```bash
curl -X POST "$BASE/pilot/tenants/$TID/products" \
  -H "Content-Type: application/json" \
  -d "{
    \"code\": \"PS-001\",
    \"name_ar\": \"قميص بولو كلاسيك\",
    \"name_en\": \"Classic Polo Shirt\",
    \"description_ar\": \"قميص بولو قطن 100%\",
    \"category_id\": \"$CAT_SHIRTS\",
    \"brand_id\": \"$BRAND_APEX\",
    \"kind\": \"goods\",
    \"vat_code\": \"standard\",
    \"default_uom\": \"piece\",
    \"tags\": [\"bestseller\", \"summer\"],
    \"variant_attribute_codes\": [\"size\", \"color\"],
    \"variants\": [
      {\"sku\":\"PS-001-S-WHITE\", \"attribute_values\":{\"size\":\"S\",\"color\":\"WHITE\"}, \"default_cost\":\"45.00\",\"list_price\":\"129.00\",\"currency\":\"SAR\",\"reorder_point\":\"10\"},
      {\"sku\":\"PS-001-M-WHITE\", \"attribute_values\":{\"size\":\"M\",\"color\":\"WHITE\"}, \"default_cost\":\"45.00\",\"list_price\":\"129.00\",\"currency\":\"SAR\"},
      {\"sku\":\"PS-001-L-WHITE\", \"attribute_values\":{\"size\":\"L\",\"color\":\"WHITE\"}, \"default_cost\":\"45.00\",\"list_price\":\"129.00\",\"currency\":\"SAR\"},
      {\"sku\":\"PS-001-XL-WHITE\",\"attribute_values\":{\"size\":\"XL\",\"color\":\"WHITE\"},\"default_cost\":\"45.00\",\"list_price\":\"129.00\",\"currency\":\"SAR\"},
      {\"sku\":\"PS-001-M-BLACK\", \"attribute_values\":{\"size\":\"M\",\"color\":\"BLACK\"}, \"default_cost\":\"45.00\",\"list_price\":\"129.00\",\"currency\":\"SAR\"},
      {\"sku\":\"PS-001-L-BLACK\", \"attribute_values\":{\"size\":\"L\",\"color\":\"BLACK\"}, \"default_cost\":\"45.00\",\"list_price\":\"129.00\",\"currency\":\"SAR\"}
    ]
  }"
```

**الاستجابة ستحتوي على:**
- `id` → PID
- `variants[].id` → احفظ VID_M_WHITE على الأقل

**✅ تحقق:**
```bash
curl "$BASE/pilot/tenants/$TID/products"
# يجب أن يعود 1 منتج مع active_variant_count=6
```

### 6/هـ — باركود EAN-13 لكل متغيّر

استخدم prefix سعودي `628` + 9 أرقام + رقم تحقق. **مهم:** رقم التحقق محسوب بدقة.

في Python:
```python
from app.pilot.models import compute_ean13_checksum
prefix = "628012345001"   # 12 رقم
checksum = compute_ean13_checksum(prefix)
ean = prefix + str(checksum)
print(ean)  # الباركود الكامل
```

**أو استعمل هذه القيم الجاهزة** (بعد تأكّد أن `compute_ean13_checksum("628012345001") == 9` → `6280123450019`):

```bash
# قميص M أبيض
curl -X POST "$BASE/pilot/variants/$VID_M_WHITE/barcodes" \
  -H "Content-Type: application/json" \
  -d '{"value":"6280123450019","type":"ean13","scope":"primary"}'
```

**✅ تحقق (scanner):**
```bash
curl "$BASE/pilot/tenants/$TID/barcode/6280123450019"
# يجب أن تعود variant + product + stock_levels
```

---

## 📥 الخطوة 7: المخزون الافتتاحي

**ما نفعله**: إدخال المخزون الموجود فعلياً في المستودع (قبل بدء البيع).

```bash
curl -X POST "$BASE/pilot/stock/movements" \
  -H "Content-Type: application/json" \
  -d "{
    \"warehouse_id\": \"$WID_RIY_MAIN\",
    \"variant_id\": \"$VID_M_WHITE\",
    \"qty\": \"50\",
    \"unit_cost\": \"45.00\",
    \"reason\": \"initial\",
    \"reference_number\": \"OPENING-2026\"
  }"
```

**كرّر** لكل متغيّر. أو استخدم loop في Python:
```python
import requests
for vid in [V1, V2, V3, V4, V5, V6]:
    r = requests.post(f"{BASE}/pilot/stock/movements", json={
        "warehouse_id": WID, "variant_id": vid, "qty": "50",
        "unit_cost": "45.00", "reason": "initial",
        "reference_number": "OPENING-2026",
    })
```

**✅ تحقق:**
```bash
curl "$BASE/pilot/warehouses/$WID_RIY_MAIN/stock"
# يجب أن ترى 6 SKUs × 50 = 300 قطعة
```

---

## 💰 الخطوة 8: قوائم الأسعار

### 8/أ — قائمة التجزئة الافتراضية (كل الفروع)
```bash
curl -X POST "$BASE/pilot/tenants/$TID/price-lists" \
  -H "Content-Type: application/json" \
  -d "{
    \"code\": \"SA-RETAIL\",
    \"name_ar\": \"التجزئة السعودية\",
    \"kind\": \"retail\",
    \"season\": \"year_round\",
    \"currency\": \"SAR\",
    \"scope\": \"tenant\",
    \"valid_from\": \"2026-01-01\",
    \"priority\": 100,
    \"prices_include_vat\": true,
    \"items\": [
      {\"variant_id\": \"$VID_M_WHITE\", \"unit_price\": \"129.00\"},
      {\"variant_id\": \"$VID_M_BLACK\", \"unit_price\": \"129.00\"}
    ]
  }"
# احفظ id → PLID_RETAIL
```

### 8/ب — فعِّل القائمة
```bash
curl -X POST "$BASE/pilot/price-lists/$PLID_RETAIL/activate" \
  -H "Content-Type: application/json" -d '{}'
```

### 8/ج — عرض صيفي (اختياري، خصم 20%)
```bash
curl -X POST "$BASE/pilot/tenants/$TID/price-lists" \
  -H "Content-Type: application/json" \
  -d "{
    \"code\": \"SUMMER-2026\",
    \"name_ar\": \"عرض الصيف 2026\",
    \"kind\": \"promo\",
    \"season\": \"summer\",
    \"currency\": \"SAR\",
    \"scope\": \"entity\",
    \"entity_id\": \"$EID_SA\",
    \"valid_from\": \"2026-04-01\",
    \"valid_to\": \"2026-09-30\",
    \"priority\": 200,
    \"is_promo\": true,
    \"promo_badge_text_ar\": \"صيف -20%\",
    \"promo_color_hex\": \"#FFD700\",
    \"items\": [
      {\"variant_id\": \"$VID_M_WHITE\", \"unit_price\": \"103.20\", \"original_price\": \"129.00\"}
    ]
  }"
# فعّل كما سبق
```

**✅ تحقق السعر (resolver):**
```bash
curl "$BASE/pilot/price-lookup?tenant_id=$TID&variant_id=$VID_M_WHITE&branch_id=$BID_RIY&qty=1"
# للعرض الصيفي يجب أن يعيد 103.20 SAR + badge صيف -20%
```

---

## 📚 الخطوة 9: إعداد الحسابات (GL)

### 9/أ — بذر شجرة حسابات SOCPA (37 حساب)
```bash
curl -X POST "$BASE/pilot/entities/$EID_SA/coa/seed"
# seeded=true, accounts_added=37
```

### 9/ب — بذر 12 فترة شهرية
```bash
curl -X POST "$BASE/pilot/entities/$EID_SA/fiscal-periods/seed" \
  -H "Content-Type: application/json" \
  -d '{"year": 2026}'
```

### 9/ج — القيد الافتتاحي
قيد موازن: نقد 100K + مخزون 300 قطعة × 45 = 13,500 + بنك 500K = رأسمال 613,500

```bash
curl -X POST "$BASE/pilot/journal-entries" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"kind\": \"opening\",
    \"je_date\": \"2026-01-01\",
    \"memo_ar\": \"الرصيد الافتتاحي لسنة 2026\",
    \"lines\": [
      {\"account_code\": \"1110\", \"debit\": \"100000.00\", \"description\": \"نقد في الصندوق\"},
      {\"account_code\": \"1120\", \"debit\": \"500000.00\", \"description\": \"البنك الأهلي\"},
      {\"account_code\": \"1140\", \"debit\": \"13500.00\", \"description\": \"مخزون افتتاحي\"},
      {\"account_code\": \"3100\", \"credit\": \"613500.00\", \"description\": \"رأس المال\"}
    ],
    \"auto_post\": true,
    \"created_by_user_id\": \"owner\"
  }"
```

**✅ تحقق:**
```bash
curl "$BASE/pilot/entities/$EID_SA/reports/trial-balance?as_of=2026-01-31"
# balanced=true, total_debit=613500, total_credit=613500
```

---

## 🔐 الخطوة 10: المستخدمون والصلاحيات

### 10/أ — اسحب القواعد الافتراضية
```bash
curl "$BASE/pilot/tenants/$TID/roles"
# 12 دور: super_admin, cfo, accounting_manager, accountant,
#         country_manager, branch_manager, pos_cashier,
#         hr_manager, warehouse_manager, purchasing_manager, auditor, viewer
# احفظ role_id لـ cfo → RID_CFO
# احفظ role_id لـ pos_cashier → RID_CASHIER
```

### 10/ب — أضف الصلاحيات للدور CFO
```bash
curl "$BASE/pilot/permissions?category=finance"
# احفظ كل الـ ids في مصفوفة PERM_IDS_FINANCE

curl -X PATCH "$BASE/pilot/roles/$RID_CFO" \
  -H "Content-Type: application/json" \
  -d "{\"permission_ids\": $PERM_IDS_FINANCE}"
```

### 10/ج — دعوة CFO بصلاحية على كل كيان SA
```bash
curl -X POST "$BASE/pilot/tenants/$TID/members" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"cfo@premiumfashion.sa\",
    \"display_name\": \"المدير المالي\",
    \"language\": \"ar\",
    \"role_id\": \"$RID_CFO\",
    \"scope\": \"entity\",
    \"entity_id\": \"$EID_SA\",
    \"can_delegate\": true
  }"
# احفظ user_id → UID_CFO
```

### 10/د — دعوة كاشير للرياض فقط (branch-scoped)
```bash
curl -X POST "$BASE/pilot/tenants/$TID/members" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"cashier@premiumfashion.sa\",
    \"display_name\": \"كاشير الرياض\",
    \"role_id\": \"$RID_CASHIER\",
    \"scope\": \"branch\",
    \"branch_id\": \"$BID_RIY\"
  }"
# احفظ user_id → UID_CASHIER
```

### 10/هـ — فحص الصلاحيات الفعلية
```bash
curl "$BASE/pilot/tenants/$TID/members/$UID_CFO/effective-permissions"
# يجب أن يعيد كل صلاحيات finance + is_tenant_admin=false (لأنه entity-scoped)
```

---

## 🇸🇦 الخطوة 11: الامتثال السعودي

### 11/أ — ZATCA Onboarding (تسجيل الكيان)
```bash
curl -X POST "$BASE/pilot/entities/$EID_SA/zatca/onboard?simulate=true"
# يعيد CSID placeholder + status=onboarded
# في الإنتاج: استبدل simulate=true برفع CSR حقيقي
```

### 11/ب — تسجيل GOSI لموظف
```bash
curl -X POST "$BASE/pilot/gosi/registrations" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"employee_user_id\": \"emp-001\",
    \"employee_number\": \"E001\",
    \"national_id\": \"1010111222\",
    \"employee_name_ar\": \"أحمد المطيري\",
    \"is_saudi\": true,
    \"contribution_wage\": \"10000.00\",
    \"registered_at\": \"2026-01-01\"
  }"
# احفظ id → GOSI_REG
```

### 11/ج — حاسبة GOSI للتأكد من النسب
```bash
curl -X POST "$BASE/pilot/gosi/calculate?is_saudi=true&wage=10000"
# يجب أن يعيد:
# employee_contribution: 975.00  (9.75%)
# employer_contribution: 1175.00 (11.75%)
# total_contribution:    2150.00
```

---

## 🛒 الخطوة 12: سيناريو البيع الكامل

### 12/أ — فتح وردية
```bash
curl -X POST "$BASE/pilot/branches/$BID_RIY/pos-sessions" \
  -H "Content-Type: application/json" \
  -d "{
    \"branch_id\": \"$BID_RIY\",
    \"warehouse_id\": \"$WID_RIY_MAIN\",
    \"opened_by_user_id\": \"$UID_CASHIER\",
    \"opening_cash\": \"500.00\",
    \"station_id\": \"POS-01\",
    \"station_label\": \"كاشير 1\"
  }"
# احفظ id → SID
# الحالة: status=open
```

### 12/ب — مسح باركود (محاكاة POS)
```bash
# أولاً اكتشف الباركود → variant
curl "$BASE/pilot/tenants/$TID/barcode/6280123450019"
# يعيد: variant=PS-001-M-WHITE، product=قميص بولو، stock_levels=[{on_hand:50}]

# ثانياً: احسب السعر
curl "$BASE/pilot/price-lookup?tenant_id=$TID&variant_id=$VID_M_WHITE&branch_id=$BID_RIY&qty=1"
# يعيد: unit_price=103.20 (عرض صيف) أو 129.00 (عادي)
```

### 12/ج — إتمام البيع (قميصان)
```bash
curl -X POST "$BASE/pilot/pos-transactions" \
  -H "Content-Type: application/json" \
  -d "{
    \"session_id\": \"$SID\",
    \"kind\": \"sale\",
    \"cashier_user_id\": \"$UID_CASHIER\",
    \"cashier_name\": \"كاشير الرياض\",
    \"customer_name\": \"عميل نقدي\",
    \"lines\": [
      {\"variant_id\": \"$VID_M_WHITE\", \"qty\": \"2\", \"barcode_scanned\": \"6280123450019\"}
    ],
    \"payments\": [
      {\"method\": \"cash\", \"amount\": \"200.00\"},
      {\"method\": \"mada\", \"amount\": \"10.00\", \"reference_number\": \"RRN-12345\", \"card_last4\": \"1234\"}
    ]
  }"
# يعيد:
# receipt_number: RIY-01-2026-04-20-01-0001
# grand_total: 206.40  (2 × 103.20 عرض صيف)
# vat_total: ~26.92
# change_given: 3.60
# احفظ id → POS_TXN
```

### 12/د — ترحيل البيع تلقائياً إلى GL
```bash
curl -X POST "$BASE/pilot/pos-transactions/$POS_TXN/post-to-gl"
# يعيد JE مع 5 بنود متوازنة:
# Dr 1110 النقد        200
# Dr 1120 بنك (مدى)     10
# Dr 5100 COGS          90
# Cr 4100 مبيعات       179.48
# Cr 2120 VAT Output    26.92 (مُدمج بالدفعتين)
# Cr 1140 مخزون         90
```

### 12/هـ — إرسال إلى ZATCA (توليد QR)
```bash
curl -X POST "$BASE/pilot/pos-transactions/$POS_TXN/zatca/submit?simulate=true"
# يعيد:
# invoice_counter: 1 (أول فاتورة)
# invoice_uuid
# invoice_hash
# qr_tlv_base64  ← هذا QR يُطبع على الإيصال
```

### 12/و — تحقق من QR
```bash
QR="<القيمة من الخطوة السابقة>"
curl "$BASE/pilot/zatca/decode-qr?qr=$QR"
# يفك التشفير: اسم البائع، الرقم الضريبي، التاريخ، الإجمالي، VAT
```

### 12/ز — إقفال الوردية + Z-report
```bash
curl -X POST "$BASE/pilot/pos-sessions/$SID/close" \
  -H "Content-Type: application/json" \
  -d "{
    \"closed_by_user_id\": \"$UID_CASHIER\",
    \"closing_cash\": \"696.40\",
    \"closing_notes\": \"نهاية الوردية\"
  }"
# expected_cash: 696.40  (500 + 200 - 3.60)
# variance: 0.00
```

**Flutter:** tab "نقطة البيع" → كل هذا يتم تلقائياً عند ضغط "إتمام البيع".

---

## 🛍 الخطوة 13: دورة الشراء الكاملة

### 13/أ — إنشاء مورد
```bash
curl -X POST "$BASE/pilot/tenants/$TID/vendors" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "ACME-001",
    "legal_name_ar": "شركة أكمي للأقمشة",
    "legal_name_en": "ACME Textiles",
    "kind": "goods",
    "country": "SA",
    "cr_number": "1010555000",
    "vat_number": "310555000000003",
    "default_currency": "SAR",
    "payment_terms": "net_30",
    "contact_name": "أحمد المورد",
    "email": "ahmed@acme.sa",
    "phone": "+966501234567",
    "bank_iban": "SA0380000000608010167519"
  }'
# احفظ id → VID_ACME
```

### 13/ب — إنشاء Purchase Order
```bash
curl -X POST "$BASE/pilot/purchase-orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"vendor_id\": \"$VID_ACME\",
    \"branch_id\": \"$BID_RIY\",
    \"destination_warehouse_id\": \"$WID_RIY_MAIN\",
    \"order_date\": \"2026-04-20\",
    \"expected_delivery_date\": \"2026-04-25\",
    \"payment_terms\": \"net_30\",
    \"lines\": [
      {
        \"variant_id\": \"$VID_M_WHITE\",
        \"sku\": \"PS-001-M-WHITE\",
        \"description\": \"قميص بولو أبيض M\",
        \"qty_ordered\": \"100\",
        \"unit_price\": \"40.00\",
        \"vat_code\": \"standard\"
      }
    ]
  }"
# احفظ id → POID
# subtotal=4000, vat=600, total=4600
```

### 13/ج — اعتماد + إصدار الـ PO
```bash
curl -X POST "$BASE/pilot/purchase-orders/$POID/approve" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "manager-001"}'

curl -X POST "$BASE/pilot/purchase-orders/$POID/issue"
# status: draft → approved → issued
```

### 13/د — استلام البضاعة (GRN)
```bash
# جلب po_line_id من
curl "$BASE/pilot/purchase-orders/$POID"
# انظر lines[0].id → POL_ID

curl -X POST "$BASE/pilot/goods-receipts" \
  -H "Content-Type: application/json" \
  -d "{
    \"po_id\": \"$POID\",
    \"warehouse_id\": \"$WID_RIY_MAIN\",
    \"received_at\": \"2026-04-25\",
    \"delivery_note_number\": \"DN-ACME-999\",
    \"lines\": [
      {\"po_line_id\": \"$POL_ID\", \"qty_received\": \"100\", \"qty_accepted\": \"100\"}
    ]
  }"
# تلقائياً:
#  - StockMovement +100 في WID_RIY_MAIN
#  - PO status = fully_received
```

### 13/هـ — فاتورة المورد + ترحيل GL
```bash
curl -X POST "$BASE/pilot/purchase-invoices" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"vendor_id\": \"$VID_ACME\",
    \"po_id\": \"$POID\",
    \"invoice_date\": \"2026-04-26\",
    \"vendor_invoice_number\": \"ACME-INV-5001\",
    \"due_date\": \"2026-05-26\",
    \"lines\": [
      {
        \"po_line_id\": \"$POL_ID\",
        \"variant_id\": \"$VID_M_WHITE\",
        \"description\": \"قميص بولو أبيض M\",
        \"qty\": \"100\",
        \"unit_cost\": \"40.00\"
      }
    ]
  }"
# احفظ id → PIID
# grand_total: 4600

curl -X POST "$BASE/pilot/purchase-invoices/$PIID/post"
# auto-JE:
# Dr 1140 مخزون       4000
# Dr 1150 VAT Input    600
# Cr 2110 AP (ACME)   4600
```

### 13/و — دفع المورد
```bash
curl -X POST "$BASE/pilot/vendor-payments" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"vendor_id\": \"$VID_ACME\",
    \"invoice_id\": \"$PIID\",
    \"amount\": \"4600.00\",
    \"payment_date\": \"2026-05-26\",
    \"method\": \"bank_transfer\",
    \"paid_from_account_code\": \"1120\",
    \"reference_number\": \"TRF-BANK-9988\"
  }"
# auto-JE:
# Dr 2110 AP    4600
# Cr 1120 بنك   4600
# الفاتورة status: paid
```

### 13/ز — كشف حساب المورد
```bash
curl "$BASE/pilot/vendors/$VID_ACME/ledger"
# يعيد:
# total_invoiced: 4600
# total_paid: 4600
# outstanding_balance: 0
# aging: {current: 0, 1-30: 0, ...}
```

---

## 📊 الخطوة 14: التقارير المالية

### 14/أ — ميزان المراجعة
```bash
curl "$BASE/pilot/entities/$EID_SA/reports/trial-balance?as_of=2026-04-30"
# يجب أن يكون balanced=true مع كل الأرصدة
```

### 14/ب — قائمة الدخل
```bash
curl "$BASE/pilot/entities/$EID_SA/reports/income-statement?start_date=2026-04-01&end_date=2026-04-30"
# revenue_total: (من POS)
# expense_total: (COGS من POS)
# net_income: الفرق
```

### 14/ج — قائمة المركز المالي
```bash
curl "$BASE/pilot/entities/$EID_SA/reports/balance-sheet?as_of=2026-04-30"
# assets = liabilities + total_equity
# balanced=true
```

**Flutter:** tab "التقارير" → 3 علامات تبويب لجميع التقارير.

---

## 🧾 الخطوة 15: إقرار VAT

### 15/أ — معاينة (بدون حفظ)
```bash
curl "$BASE/pilot/vat-returns/preview?entity_id=$EID_SA&year=2026&period_number=2&period_type=quarterly"
# Q2 = أبريل-يونيو
# standard_rated_sales: (المبيعات الخاضعة)
# output_vat: (VAT على المبيعات)
# input_vat: (VAT على المشتريات)
# net_vat_payable: الفرق
```

### 15/ب — توليد الإقرار + حفظه
```bash
curl -X POST "$BASE/pilot/vat-returns/generate" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"year\": 2026,
    \"period_number\": 2,
    \"period_type\": \"quarterly\"
  }"
```

### 15/ج — قائمة كل الإقرارات
```bash
curl "$BASE/pilot/entities/$EID_SA/vat-returns"
```

---

## 🇦🇪 الخطوة 16: إقرار ضريبة الشركات الإماراتية (للكيان AE)

### 16/أ — حاسبة (بدون حفظ)
```bash
curl -X POST "$BASE/pilot/uae-ct/calculate?gross_revenue=1000000&deductible_expenses=200000"
# taxable_income: 800,000
# بعد إعفاء 375K: 425,000 × 9% = 38,250 AED
```

### 16/ب — إقرار للسنة المالية
```bash
curl -X POST "$BASE/pilot/uae-ct/filings" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_AE\",
    \"fiscal_year\": 2026,
    \"gross_revenue\": \"1000000\",
    \"deductible_expenses\": \"200000\"
  }"
```

---

## 💼 الخطوة 17: دفعة رواتب WPS (سعودي)

### 17/أ — إنشاء دفعة
```bash
curl -X POST "$BASE/pilot/wps/batches" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_id\": \"$EID_SA\",
    \"year\": 2026,
    \"month\": 4,
    \"employer_bank_code\": \"RJHI\",
    \"employer_account_iban\": \"SA0380000000608010167519\",
    \"employer_establishment_id\": \"5000012345\",
    \"employees\": [
      {
        \"employee_user_id\": \"emp-001\",
        \"employee_name_ar\": \"أحمد المطيري\",
        \"national_id\": \"1010111222\",
        \"employee_bank_code\": \"RJHI\",
        \"employee_account_iban\": \"SA4420000000123456789012\",
        \"basic_salary\": \"6000.00\",
        \"housing_allowance\": \"1500.00\",
        \"transport_allowance\": \"500.00\",
        \"gosi_deduction\": \"975.00\"
      }
    ]
  }"
# احفظ id → WPS_BID
```

### 17/ب — تحميل ملف SIF
```bash
curl "$BASE/pilot/wps/batches/$WPS_BID/sif" -o "WPS_SA_202604.sif"
# يحفظ الملف بصيغة SAMA (SCR header + EDR rows + TLR trailer)
```

---

## 🎉 الخلاصة

بعد إكمال هذه الخطوات سيكون لديك:

| العنصر | الحالة |
|---|---|
| مستأجر كامل | ✅ |
| 6 كيانات (دول) — على الأقل 1 | ✅ |
| 2+ فروع في السعودية | ✅ |
| 2+ مستودعات | ✅ |
| شجرة تصنيفات + علامة + سمتان | ✅ |
| منتج مع 6+ متغيّرات + باركودات | ✅ |
| مخزون افتتاحي | ✅ |
| 2 قوائم أسعار (retail + promo) | ✅ |
| CoA SOCPA (37 حساب) + 12 فترة | ✅ |
| قيد افتتاحي 613,500 SAR | ✅ |
| CFO + كاشير مُعيَّنين | ✅ |
| ZATCA onboarded | ✅ |
| GOSI registration | ✅ |
| بيع كامل في POS (مع خصم) | ✅ |
| ترحيل تلقائي إلى GL | ✅ |
| QR ZATCA معتمد | ✅ |
| Z-report متوازن | ✅ |
| دورة شراء كاملة (PO→GRN→PI→Payment) | ✅ |
| كشف حساب المورد | ✅ |
| 3 تقارير مالية (TB/IS/BS) | ✅ |
| إقرار VAT ربعي | ✅ |
| UAE CT filing | ✅ (لو عندك EID_AE) |
| دفعة WPS + SIF | ✅ |

---

## 🛟 مشاكل شائعة وحلول

| المشكلة | السبب | الحل |
|---|---|---|
| `409 Conflict` على tenant slug | موجود مسبقاً | استخدم slug مختلف أو `curl "$BASE/pilot/tenants/$TID"` |
| `400 لا توجد فترة محاسبية مفتوحة` | لم تبذر fiscal periods | Step 9/ب |
| `400 الحساب X header` | تستخدم حساب تجميعي للقيد | استخدم `type=detail` (فرعي) |
| `409 القيد غير متوازن` | Σdebit ≠ Σcredit | راجع الأرقام |
| `409 مخزون غير كافٍ` | تبيع أكثر من المتاح | زد المخزون في Step 7 |
| `400 EAN-13 checksum غير صحيح` | الرقم الأخير خاطئ | استخدم `compute_ean13_checksum()` |
| `409 الفاتورة الأصلية مُرتجعة بالكامل` | تحاول مرتجع على فاتورة مرتجعة | استخدم فاتورة جديدة |
| `ZATCA خاص بالسعودية` | تحاول على كيان غير SA | استخدم EID_SA |
| CORS error في Flutter | API_BASE خاطئ | `--dart-define=API_BASE=...` |

---

## 🧰 أدوات مساعدة

### Postman Collection
احفظ هذه المتغيرات:
- `base_url`: `http://localhost:8000` (أو Render URL)
- `tenant_id`: `<من Step 2>`
- `entity_sa_id`: `<من Step 3>`
- `branch_riy_id`: `<من Step 4>`
- كلها bearer token إذا كان endpoint يتطلبها

### Python Helper
```python
import requests

BASE = "http://localhost:8000"

def api(method, path, json=None, **kwargs):
    r = requests.request(method, f"{BASE}{path}", json=json, **kwargs)
    if r.status_code >= 400:
        print(f"!!! {r.status_code}: {r.text[:300]}")
    return r.json() if r.text else None

# مثال:
t = api("POST", "/pilot/tenants", {"slug": "test", "legal_name_ar": "اختبار", ...})
TID = t["id"]
```

### Flutter (اختبار سريع)
```bash
cd apex_finance
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
# افتح: /#/pilot
# الصق TID من Step 2
# اختر الكيان SA
# اختر الفرع RIY
# جرب POS: امسح الباركود 6280123450019
```

---

بمجرد إتمام جميع الخطوات تكون قد غطّيت **140 مسار** و**50 جدول** في الـ pilot.
إذا واجهت مشكلة في أي خطوة، أخبرني بالرقم والـ response.
