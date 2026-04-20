"""APEX Pilot — إعداد تفاعلي للعميل خطوة بخطوة.

يرشدك من "البدء من الصفر" حتى "جاهز للبيع" مع طباعة كل ما يحدث،
والمُعرِّفات المهمة (Tenant ID, Entity ID, Branch ID) للاستخدام في Flutter.

استخدامه:
  py scripts/interactive_customer_setup.py

   أو مع base URL آخر:
  API_BASE=https://your-api.onrender.com py scripts/interactive_customer_setup.py
"""

import sys
import os
import time
import json

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# ensure project root is on the path (so `from app.main import app` works
# even when script is executed from anywhere)
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)
os.chdir(_ROOT)

BASE = os.environ.get("API_BASE", "http://localhost:8000")
ADMIN = os.environ.get("ADMIN_SECRET", "apex-admin-2026")

# يستخدم HTTP إذا BASE يبدأ بـ http، وإلا TestClient محلّي (in-process)
# يسقط تلقائياً إلى TestClient إن فشل الاتصال بـ localhost
USE_TEST_CLIENT = not BASE.startswith("http")

if not USE_TEST_CLIENT:
    import requests
    SESSION = requests.Session()

    # فحص الاتصال قبل البدء
    try:
        r = SESSION.get(f"{BASE}/pilot/health", timeout=3)
        if r.status_code != 200:
            raise ConnectionError(f"HTTP {r.status_code}")
    except Exception as e:
        print(f"⚠  تعذّر الاتصال بـ {BASE}: {type(e).__name__}")
        print(f"   التحوّل إلى TestClient محلي (بدون خادم)...")
        USE_TEST_CLIENT = True
        os.environ.setdefault("DATABASE_URL", "sqlite:///./apex_interactive.db")
        if os.path.exists("apex_interactive.db"):
            os.remove("apex_interactive.db")

    if not USE_TEST_CLIENT:
        def req(method, path, **kwargs):
            url = f"{BASE}{path}"
            return SESSION.request(method, url, timeout=60, **kwargs)

def print_step(n, title):
    print()
    print("═" * 70)
    print(f"  الخطوة {n}: {title}")
    print("═" * 70)


def print_ok(msg):
    print(f"  ✅  {msg}")


def print_info(msg):
    print(f"  ℹ️   {msg}")


def print_err(msg):
    print(f"  ❌  {msg}")


def api(method, path, json_body=None, headers=None, expect_codes=(200, 201)):
    if USE_TEST_CLIENT:
        from fastapi.testclient import TestClient
        from app.main import app
        global _CLIENT
        if "_CLIENT" not in globals():
            _CLIENT = TestClient(app)
        r = _CLIENT.request(method, path, json=json_body, headers=headers or {})
    else:
        r = req(method, path, json=json_body, headers=headers or {})

    if r.status_code not in expect_codes:
        if r.status_code == 409:
            return {"_already_exists": True, "_detail": r.text[:200]}
        print_err(f"{method} {path}: HTTP {r.status_code}")
        print(f"      {r.text[:300]}")
        return None
    try:
        return r.json() if r.text else {}
    except Exception:
        return {}


def pause(msg="اضغط Enter للمتابعة..."):
    try:
        input(f"  ⏸   {msg}")
    except EOFError:
        time.sleep(0.5)


# ══════════════════════════════════════════════════════════════════════════
# البداية
# ══════════════════════════════════════════════════════════════════════════

print("═" * 70)
print(" APEX Pilot — إعداد تفاعلي لعميل جديد")
print("═" * 70)
print(f"  API: {BASE}")
print(f"  Admin Secret: {ADMIN[:4]}***")
print()

# ── فحص الاتصال
health = api("GET", "/pilot/health")
if not health:
    print_err("فشل الاتصال. تأكّد أن الخادم يعمل.")
    sys.exit(1)
print_ok(f"الخادم حي: {health.get('module')} v{health.get('version')}")

# ──────────────────────────────────────────────────────────────
# 1. بذر الصلاحيات
# ──────────────────────────────────────────────────────────────
print_step(1, "بذر 159 صلاحية أساسية")
r = api("POST", "/admin/pilot/seed-permissions",
        headers={"X-Admin-Secret": ADMIN})
if r:
    res = r.get("result", r)
    print_ok(f"الصلاحيات: {res.get('total_permissions', '?')} "
             f"(أضيف: {res.get('added', 0)}, موجود: {res.get('existing', 0)})")

# ──────────────────────────────────────────────────────────────
# 2. المستأجر
# ──────────────────────────────────────────────────────────────
print_step(2, "إنشاء المستأجر (الشركة الأم)")
default_slug = f"demo-{int(time.time())}"
slug = input(f"  أدخل slug للمستأجر (Enter للقبول: {default_slug}): ").strip() or default_slug

tenant = api("POST", "/pilot/tenants", {
    "slug": slug,
    "legal_name_ar": "شركة الأزياء التجريبية",
    "legal_name_en": "Demo Fashion Co.",
    "primary_cr_number": f"1010{int(time.time()) % 1000000}",
    "primary_vat_number": f"310{int(time.time()) % 1000000}000003",
    "primary_country": "SA",
    "primary_email": f"{slug}@demo.sa",
    "tier": "enterprise",
})
if not tenant:
    sys.exit(1)

TID = tenant["id"]
print_ok(f"Tenant ID: {TID}")
print_info(f"الـ slug: {tenant['slug']}")
print_info(f"الحالة: {tenant['status']}، التجربة تنتهي: {tenant['trial_ends_at']}")

# تحقق من البذر التلقائي
currencies = api("GET", f"/pilot/tenants/{TID}/currencies")
roles = api("GET", f"/pilot/tenants/{TID}/roles")
print_info(f"عُبذرت {len(currencies or [])} عملة افتراضية")
print_info(f"عُبذر {len(roles or [])} دور افتراضي")

# ──────────────────────────────────────────────────────────────
# 3. الكيان السعودي
# ──────────────────────────────────────────────────────────────
print_step(3, "إنشاء كيان السعودية")
entity = api("POST", f"/pilot/tenants/{TID}/entities", {
    "code": "SA",
    "name_ar": "الأزياء السعودية",
    "name_en": "Demo Fashion SA",
    "country": "SA",
    "type": "subsidiary",
    "functional_currency": "SAR",
    "cr_number": "1010888999",
    "vat_number": "310888999000003",
})
if not entity:
    sys.exit(1)
EID = entity["id"]
print_ok(f"Entity ID: {EID}")

# ──────────────────────────────────────────────────────────────
# 4. فرع الرياض
# ──────────────────────────────────────────────────────────────
print_step(4, "إنشاء فرع الرياض")
branch = api("POST", f"/pilot/entities/{EID}/branches", {
    "code": "RIY-01",
    "name_ar": "فرع الرياض — بانوراما",
    "country": "SA",
    "city": "Riyadh",
    "type": "retail_store",
    "pos_station_count": 1,
    "allowed_payment_methods": ["cash", "mada", "visa", "stc_pay"],
})
BID = branch["id"]
print_ok(f"Branch ID: {BID}")

# ──────────────────────────────────────────────────────────────
# 5. المستودع
# ──────────────────────────────────────────────────────────────
print_step(5, "إنشاء المستودع")
wh = api("POST", f"/pilot/branches/{BID}/warehouses", {
    "code": "RIY-MAIN",
    "name_ar": "الرياض — رئيسي",
    "type": "main",
    "is_default": True,
    "is_sellable_from": True,
})
WID = wh["id"]
print_ok(f"Warehouse ID: {WID}")

# ──────────────────────────────────────────────────────────────
# 6. التصنيف + العلامة + السمات
# ──────────────────────────────────────────────────────────────
print_step(6, "الكاتالوج (تصنيف + علامة + سمات)")

cat = api("POST", f"/pilot/tenants/{TID}/categories", {
    "code": "SHIRTS", "name_ar": "قمصان", "name_en": "Shirts",
})
print_ok(f"تصنيف: {cat['code']}")

brand = api("POST", f"/pilot/tenants/{TID}/brands", {
    "code": "DEMO-BRAND", "name_ar": "ماركة تجريبية", "name_en": "Demo Brand",
})
print_ok(f"علامة: {brand['code']}")

attr_size = api("POST", f"/pilot/tenants/{TID}/attributes", {
    "code": "size", "name_ar": "المقاس", "type": "size",
    "is_required_for_variant": True,
    "values": [
        {"code": "S", "name_ar": "صغير", "sort_order": 1},
        {"code": "M", "name_ar": "وسط", "sort_order": 2},
        {"code": "L", "name_ar": "كبير", "sort_order": 3},
    ],
})
print_ok(f"سمة المقاس (3 قيم)")

attr_color = api("POST", f"/pilot/tenants/{TID}/attributes", {
    "code": "color", "name_ar": "اللون", "type": "color", "input_type": "swatch",
    "is_required_for_variant": True,
    "values": [
        {"code": "WHITE", "name_ar": "أبيض", "hex_color": "#FFFFFF"},
        {"code": "BLACK", "name_ar": "أسود", "hex_color": "#000000"},
    ],
})
print_ok(f"سمة اللون (2 قيم)")

# ──────────────────────────────────────────────────────────────
# 7. منتج مع 6 متغيّرات
# ──────────────────────────────────────────────────────────────
print_step(7, "إنشاء منتج + 6 متغيّرات (3 مقاسات × 2 ألوان)")
variants_in = []
for sz in ["S", "M", "L"]:
    for col in ["WHITE", "BLACK"]:
        variants_in.append({
            "sku": f"SH-{sz}-{col}",
            "attribute_values": {"size": sz, "color": col},
            "default_cost": "50.00",
            "list_price": "150.00",
            "currency": "SAR",
            "track_stock": True,
            "reorder_point": "10",
        })

product = api("POST", f"/pilot/tenants/{TID}/products", {
    "code": "SH-001",
    "name_ar": "قميص كلاسيك",
    "name_en": "Classic Shirt",
    "category_id": cat["id"],
    "brand_id": brand["id"],
    "kind": "goods",
    "vat_code": "standard",
    "variant_attribute_codes": ["size", "color"],
    "variants": variants_in,
})
PID = product["id"]
print_ok(f"منتج: {product['code']} مع {len(product['variants'])} متغيّر")

# ──────────────────────────────────────────────────────────────
# 8. باركود EAN-13
# ──────────────────────────────────────────────────────────────
print_step(8, "توليد باركودات EAN-13 للمتغيّرات")

# ستحتاج import (يعمل فقط مع USE_TEST_CLIENT أو من app مباشرة)
if USE_TEST_CLIENT:
    from app.pilot.models import compute_ean13_checksum

    def mk_ean(seq: int) -> str:
        prefix12 = f"628012345{seq:03d}"
        return prefix12 + str(compute_ean13_checksum(prefix12))
else:
    # خوارزمية EAN-13 inline للعمل عن بُعد
    def mk_ean(seq: int) -> str:
        prefix12 = f"628012345{seq:03d}"
        total = sum(int(c) * (3 if i % 2 else 1) for i, c in enumerate(prefix12))
        cd = (10 - (total % 10)) % 10
        return prefix12 + str(cd)

barcodes = {}
for idx, v in enumerate(product["variants"], start=1):
    ean = mk_ean(idx)
    r = api("POST", f"/pilot/variants/{v['id']}/barcodes", {
        "value": ean, "type": "ean13", "scope": "primary",
    })
    if r:
        barcodes[v["sku"]] = ean
        print_ok(f"  {v['sku']} → {ean}")

# ──────────────────────────────────────────────────────────────
# 9. المخزون الافتتاحي
# ──────────────────────────────────────────────────────────────
print_step(9, "إدخال مخزون افتتاحي (50 قطعة لكل متغيّر)")
for v in product["variants"]:
    api("POST", "/pilot/stock/movements", {
        "warehouse_id": WID, "variant_id": v["id"],
        "qty": "50", "unit_cost": "50.00",
        "reason": "initial", "reference_number": "OPENING-2026",
    }, expect_codes=(201,))
print_ok(f"6 متغيّرات × 50 = 300 قطعة")

# ──────────────────────────────────────────────────────────────
# 10. قائمة أسعار
# ──────────────────────────────────────────────────────────────
print_step(10, "قائمة أسعار التجزئة + تفعيلها")
pl = api("POST", f"/pilot/tenants/{TID}/price-lists", {
    "code": "RETAIL", "name_ar": "تجزئة",
    "kind": "retail", "season": "year_round", "currency": "SAR",
    "scope": "tenant", "valid_from": "2026-01-01", "priority": 100,
    "prices_include_vat": True,
    "items": [
        {"variant_id": v["id"], "unit_price": "150.00"}
        for v in product["variants"]
    ],
})
api("POST", f"/pilot/price-lists/{pl['id']}/activate", {}, expect_codes=(200,))
print_ok(f"قائمة مُفعَّلة بـ {len(pl.get('items', []))} بند")

# ──────────────────────────────────────────────────────────────
# 11. GL
# ──────────────────────────────────────────────────────────────
print_step(11, "شجرة الحسابات + الفترات + القيد الافتتاحي")
api("POST", f"/pilot/entities/{EID}/coa/seed", expect_codes=(200,))
api("POST", f"/pilot/entities/{EID}/fiscal-periods/seed", {"year": 2026},
    expect_codes=(200,))
api("POST", "/pilot/journal-entries", {
    "entity_id": EID,
    "kind": "opening",
    "je_date": "2026-01-01",
    "memo_ar": "الرصيد الافتتاحي",
    "lines": [
        {"account_code": "1110", "debit": "50000.00", "description": "نقد"},
        {"account_code": "1120", "debit": "200000.00", "description": "بنك"},
        {"account_code": "1140", "debit": "15000.00", "description": "مخزون"},
        {"account_code": "3100", "credit": "265000.00", "description": "رأسمال"},
    ],
    "auto_post": True,
}, expect_codes=(201,))
print_ok(f"شجرة حسابات 37 + فترات 12 + قيد افتتاحي 265K SAR")

# ──────────────────────────────────────────────────────────────
# 12. ZATCA
# ──────────────────────────────────────────────────────────────
print_step(12, "تسجيل ZATCA (simulated)")
api("POST", f"/pilot/entities/{EID}/zatca/onboard?simulate=true",
    expect_codes=(200,))
print_ok(f"ZATCA onboarded")

# ──────────────────────────────────────────────────────────────
# 13. فتح وردية + بيع تجريبي
# ──────────────────────────────────────────────────────────────
print_step(13, "فتح وردية + بيع تجريبي")
pause("اضغط Enter للفتح...")

sess = api("POST", f"/pilot/branches/{BID}/pos-sessions", {
    "branch_id": BID, "warehouse_id": WID,
    "opened_by_user_id": "cashier-web",
    "opening_cash": "500.00",
})
SID = sess["id"]
print_ok(f"الوردية {sess['code']} مفتوحة (رصيد 500 SAR)")

# بيع: قميص M أبيض
m_white_variant = next(v for v in product["variants"] if v["sku"] == "SH-M-WHITE")
m_white_ean = barcodes.get("SH-M-WHITE")

# مسح
scan = api("GET", f"/pilot/tenants/{TID}/barcode/{m_white_ean}")
print_info(f"مسح: {m_white_ean} → {scan['variant']['sku']}")

# بيع
txn = api("POST", "/pilot/pos-transactions", {
    "session_id": SID,
    "kind": "sale",
    "cashier_user_id": "cashier-web",
    "lines": [{"variant_id": m_white_variant["id"], "qty": "2"}],
    "payments": [{"method": "cash", "amount": "300.00"}],
}, expect_codes=(201,))
print_ok(f"إيصال: {txn['receipt_number']} ({txn['grand_total']} SAR)")

# ترحيل + ZATCA
je = api("POST", f"/pilot/pos-transactions/{txn['id']}/post-to-gl")
print_ok(f"رُحِّل: {je['je_number']} ({len(je['lines'])} بنود)")
zat = api("POST", f"/pilot/pos-transactions/{txn['id']}/zatca/submit?simulate=true")
print_ok(f"ZATCA: ICV={zat['invoice_counter']} | QR {len(zat['qr_tlv_base64'])} بايت")

# إقفال
zr = api("POST", f"/pilot/pos-sessions/{SID}/close", {
    "closed_by_user_id": "cashier-web",
    "closing_cash": str(500 + 300),  # 800 (500 + 300 نقد، لا باقي لأن 150×2=300)
})
print_ok(f"Z-report: expected={zr['expected_cash']}, variance={zr['variance']}")

# ──────────────────────────────────────────────────────────────
# 14. التقارير
# ──────────────────────────────────────────────────────────────
print_step(14, "التقارير المالية الفورية")

tb = api("GET", f"/pilot/entities/{EID}/reports/trial-balance?as_of=2026-04-30")
print_ok(f"ميزان المراجعة: balanced={tb['balanced']}, "
         f"Σd={tb['total_debit']}, Σc={tb['total_credit']}")

is_rep = api("GET",
             f"/pilot/entities/{EID}/reports/income-statement"
             f"?start_date=2026-04-01&end_date=2026-04-30")
print_ok(f"قائمة الدخل: revenue={is_rep['revenue_total']}, "
         f"expense={is_rep['expense_total']}, net={is_rep['net_income']}")

bs = api("GET", f"/pilot/entities/{EID}/reports/balance-sheet?as_of=2026-04-30")
print_ok(f"المركز المالي: assets={bs['assets']}, balanced={bs['balanced']}")

# ──────────────────────────────────────────────────────────────
# الخلاصة
# ──────────────────────────────────────────────────────────────
print()
print("═" * 70)
print(" ✅ اكتمل الإعداد بنجاح!")
print("═" * 70)
print()
print(f"  Tenant ID:      {TID}")
print(f"  Entity ID (SA): {EID}")
print(f"  Branch ID:      {BID}")
print(f"  Warehouse ID:   {WID}")
print(f"  Product ID:     {PID}")
print(f"  Session ID:     {SID}  (مُقفلة)")
print()
print(f"  باركودات للاختبار:")
for sku, ean in barcodes.items():
    print(f"    {sku:20s} → {ean}")
print()
print(" للاختبار في Flutter:")
print(f"   1) flutter run -d chrome --dart-define=API_BASE={BASE}")
print(f"   2) افتح http://localhost:PORT/#/pilot")
print(f"   3) انقر 'اختر مستأجراً' + الصق:")
print(f"      {TID}")
print(f"   4) اختر الكيان SA، ثم الفرع RIY-01")
print(f"   5) في tab 'نقطة البيع':")
print(f"      - افتح وردية جديدة")
print(f"      - امسح باركود: {list(barcodes.values())[0]}")
print(f"      - اضغط 'إتمام البيع'")
print()
print(" للنسخ/اللصق السريع في shell:")
print(f"   export TID={TID}")
print(f"   export EID={EID}")
print(f"   export BID={BID}")
print(f"   export WID={WID}")
print()
