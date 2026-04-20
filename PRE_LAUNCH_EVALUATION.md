# تقييم ما قبل إطلاق العميل الأول — APEX Pilot

**التاريخ:** 2026-04-20
**النسخة:** 10 شاشات حيّة مكتملة (بعد إزالة PilotBridge)

> مقارنة مع: SAP S/4HANA · Oracle NetSuite · MS Dynamics 365 BC · Odoo 17 · Zoho Books · QuickBooks · Xero · Wafeq · Rewaa · Foodics · Qoyod · Shopify POS · Square · Lightspeed · Clover · Loyverse

---

## 🎯 التموضع الاستراتيجي الفريد

> **الثغرة السوقية المؤكدة:**
> لا توجد منصة سعودية واحدة تجمع بين 4 عناصر: POS قوي للتجزئة/المطاعم + محاسبة كاملة + Multi-tenant لمكاتب المحاسبة + B2B Tax Invoices أصلي.

| المنصة | POS قوي | محاسبة كاملة | Multi-tenant | B2B أصلي |
|---|---|---|---|---|
| **Wafeq** | ❌ | ✅ | ✅ الأقوى | ✅ |
| **Rewaa** | ✅ | ⚠️ قيود آلية فقط | ❌ | ✅ |
| **Foodics** | ✅✅ | ⚠️ منفصل | ❌ | ❌ (B2C فقط) |
| **Qoyod** | ⚠️ بسيط | ✅ | ✅ | ✅ |
| **APEX Pilot** | ✅ | ✅ | ✅ | ✅ | ← **الوحيد الذي يجمع الكل**

---

## 🏆 نقاط قوة موجودة — احتفظ بها في التسويق

1. ✅ **Multi-tenant 3 مستويات** (Tenant→Entity→Branch) — لا Wafeq (entity واحد)، ولا Qoyod بهذا العمق
2. ✅ **ZATCA Phase 2 مدمج في POS** — فقط Foodics/Rewaa يفعلون ذلك
3. ✅ **9 طرق دفع محلية + BNPL** (mada/stc_pay/Apple Pay/Tamara/Tabby)
4. ✅ **14 reason code لحركات المخزون + transfer pair atomic**
5. ✅ **B2B + B2C tax invoices في نفس POS** — Foodics لا يفعلها

---

## 📋 القائمة النهائية الموحّدة (22 عنصر 🔴 + 8 عناصر 🟠)

### 🔴 حرج مطلق — لا إطلاق بدونها (5 أسابيع لفريق 3)

| # | العمل | الجولة | السبب |
|---|---|---|---|
| 1 | Logo + Invoice header/footer | ج1 | شكل احترافي |
| 2 | CoA: PATCH + حماية من تعديل حساب فيه حركات | ج2 | Rewaa/Qoyod |
| 3 | Import Excel (CoA + Products + Vendors) | ج2-4 | Wafeq |
| 4 | Vendor Documents (CR/VAT/IBAN) attachments | ج3 | KSA due diligence |
| 5 | **Batch/Lot/Expiry tracking** | ج4 | Rewaa — معيار السوق |
| 6 | Multi-UOM groups (كرتون↔حبة) | ج4 | Rewaa |
| 7 | Full Stocktake workflow | ج5 | كلهم |
| 8 | PO PDF template + Email | ج6 | لا PO بدون PDF |
| 9 | **3-way matching automation** | ج6 | Qoyod — فجوة تنافسية |
| 10 | Approval limits per PO value | ج6 | Wafeq (OTP على الدفعات) |
| 11 | Attachments per JE (مستندات المصدر) | ج7 | ZATCA requirement |
| 12 | Immutable lock بعد post/clearance | ج7 | Qoyod |
| 13 | Cash Flow Statement | ج8 | كلهم |
| 14 | **Consolidated reports عبر الكيانات** | ج8 | Wafeq — ميزة تنافسية |
| 15 | PDF + Excel export كل التقارير | ج8 | كلهم |
| 16 | General Ledger detail + Drill-down | ج8 | كلهم |
| 17 | POS Returns/Refunds | ج9 | أهم عملية بعد البيع |
| 18 | POS Offline mode + sync queue | ج9 | Loyverse/Foodics/Rewaa |
| 19 | Thermal printer + Receipt email | ج9 | كلهم |
| 20 | Manual card tender (mada POS منفصل) | ج9 | Loyverse — fallback سريع |
| 21 | Email backend حقيقي (SendGrid) | ج10 | الدعوات + reset password |
| 22 | 2FA + Password reset flow | ج10 | أمن أساسي |

### 🟠 مهم — أسبوعان بعد العميل الأول

| # | العمل | السبب |
|---|---|---|
| A1 | **🆕 OCR لفواتير المشتريات الواردة** (Claude API موجود!) — رفع PDF/صورة + استخراج تلقائي لرقم المورد، التاريخ، الأصناف، VAT | Wafeq — توفير 90% وقت. طلب المستخدم 2026-04-20 |
| A2 | **🆕 توليد Barcode تلقائي (EAN-13)** للأصناف — زر في شاشة المنتج يولّد ويُلصق على الصنف + طباعة ملصقات | طلب المستخدم 2026-04-20. Rewaa يفعلها |
| A3 | Recurring JE (إهلاك شهري) | كلهم |
| A4 | Bulk import فواتير مشتريات (50 فاتورة دفعة) | Wafeq |
| A5 | WHT automation على المدفوعات | Wafeq/Qoyod |
| A6 | Customer aging report | كلهم |
| A7 | Landed cost allocation | NetSuite/Odoo |
| A8 | Shift handover بين الكاشيرات | Rewaa/Foodics |
| A9 | Receipt customer email/SMS | كلهم |
| A10 | **🆕 Upload فاتورة كملف أصل** في كل شاشة (PO/PI/JE/Payment) كـ audit trail | طلب المستخدم 2026-04-20 |

### 🟢 بعد 3 أشهر — ميزات التمييز

- White-label portal (مثل Qoyod) — مكاتب المحاسبة
- Marketplace للتطبيقات (مثل Foodics App Store)
- Tamara/Tabby API integration حقيقي
- KDS لشاشة المطبخ (مثل Foodics)
- Customer loyalty program
- Vendor portal
- Field-level permissions
- SSO (Azure AD / Google)
- Custom report builder

---

## 💰 استراتيجية التسعير المقترحة

| المنصة | أدنى سعر |
|---|---|
| Qoyod | 60 SAR/شهر |
| Wafeq | 119 SAR/شهر |
| Rewaa | 247 SAR/شهر |
| Foodics | 392 SAR/شهر |

### خطط APEX المقترحة:

- **Starter: 149 SAR/شهر** — فرع واحد + مستخدمان + كل الشاشات
- **Growth: 399 SAR/شهر** — 3 فروع + 10 مستخدمين + multi-entity
- **Enterprise: 899 SAR/شهر** — غير محدود + consolidated reports + white-label

---

## 🗓️ خطة الـ 5 أسابيع قبل العميل الأول

| الأسبوع | مطور A | مطور B | مطور C |
|---|---|---|---|
| 1 | Import Excel + Batch/Lot/Expiry | POS Returns + Offline | PDF/Excel exports |
| 2 | 3-way match + Approval limits | POS Thermal printer + Receipt email | Cash Flow + Consolidated reports |
| 3 | Attachments (vendor docs + JE) | Full Stocktake workflow | GL detail + Drill-down |
| 4 | Immutable lock + Period close | Email + 2FA + Password reset | Logo/Header + PO PDF |
| 5 | **UAT كامل مع عميل داخلي — Fix bugs** | | |

**بعد الأسبوع 5:** عميل داخلي/تابع لمدة أسبوعين
**بعد الأسبوع 7:** العميل الخارجي الأول (ترتيب مقترح: خدمات → retail صغير → retail كبير)

---

## 📊 تفصيل الجولات العشر

### ج1 — إعدادات الشركة والـ Onboarding
✅ لدينا: 8-step wizard, 7 دول GCC, ZATCA مدمج, timezone per entity
❌ ينقصنا: Logo upload, Invoice header/footer, Digital signature

### ج2 — شجرة الحسابات
✅ لدينا: SOCPA 37 seed, tree view, balance from TB, multi-currency per account
❌ ينقصنا: PATCH/DELETE account, merge, Excel import, balance as-of drill-down

### ج3 — الموردون
✅ لدينا: CRUD, 5 kinds, credit limit, bank details, aging 4 buckets, vendor ledger
❌ ينقصنا: Vendor documents, statement PDF, 1099/WHT, multi-address, vendor portal

### ج4 — الأصناف
✅ لدينا: Product→Variant→Barcode hierarchy, categories, brands, weighted avg cost
❌ ينقصنا: **Batches/Lots/Expiry**, Multi-UOM groups, Serial numbers, Multi-image, Landed cost, Auto-reorder, Excel import

### ج5 — المستودعات والحركات
✅ لدينا: Multi-warehouse, 14 reason codes, transfer atomic pair
❌ ينقصنا: Bin/Location, Pick/Pack/Ship, **Full Stocktake**, Stock valuation report, Barcode scanning

### ج6 — المشتريات
✅ لدينا: PO→GRN→PI→Payment full cycle, partial receipts, approve/issue
❌ ينقصنا: **3-way match auto**, **PO PDF/Email**, Multi-level approval, Landed cost, PO revisions, RFQ, WHT

### ج7 — قيود اليومية
✅ لدينا: Multi-line JE + balance check, post/reverse, auto-post
❌ ينقصنا: **Attachments**, **Recurring JE**, JE templates, Excel import, Multi-currency FX auto

### ج8 — التقارير المالية
✅ لدينا: Trial Balance, P&L, Balance Sheet, balance checks
❌ ينقصنا: **Cash Flow**, **PDF/Excel export**, **GL detail + Drill-down**, Comparative periods, **Consolidated**

### ج9 — POS
✅ لدينا: Multi-tender 9 طرق, ZATCA QR + PIH, session open/close
❌ ينقصنا: **Returns/Refunds**, **Offline mode**, **Thermal printer**, Hold/Park, Customer receipt email, Loyalty

### ج10 — المستخدمون والصلاحيات
✅ لدينا: Members + Roles + Permissions, 3-level scope, invite endpoint
❌ ينقصنا: **Email backend**, **2FA**, **Password reset**, Activity log viewer, SSO, Approval limits enforcement

---

## 🎯 الخلاصة

**النظام أقوى هيكلياً من معظم المنافسين** (multi-tenant + POS + ZATCA + 14 reason codes + B2B/B2C).

**لكن ينقصه 22 عنصر تشغيلي حرج قبل الإطلاق التجاري** — أغلبها "تفاصيل إنجازية" وليست معمارية.

**5 أسابيع عمل منظّم + أسبوعان UAT = جاهز للإطلاق بثقة.**

**الرسالة التسويقية المقترحة:**
> "APEX Pilot — أول نظام سعودي يجمع POS متقدم + محاسبة كاملة + Multi-tenant لمكاتب المحاسبة — بدون وسطاء، بدون add-ons، بسعر موحّد."
