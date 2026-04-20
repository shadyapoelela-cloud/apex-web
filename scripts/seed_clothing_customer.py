"""APEX Pilot — Seed script للعميل الفعلي (مجموعة الأزياء).

يبني بيئة تجريبية كاملة وقابلة للاستخدام فوراً:

  المستأجر: "Advanced Fashion Group" (مجموعة الأزياء المتطورة)
  6 كيانات (شركة لكل دولة):
    • SA — سعودية (SAR)
    • AE — إمارات (AED)
    • QA — قطر (QAR)
    • KW — كويت (KWD)
    • BH — بحرين (BHD)
    • EG — مصر (EGP)
  8 فروع (مُوزّعة):
    • SA-RIY-PANORAMA (الرياض)
    • SA-JED-REDSEA (جدة)
    • SA-JED-MALL (جدة)
    • SA-DMM-WAHA (الدمام)
    • AE-DXB-MALL (دبي)
    • AE-AUH-CITY (أبوظبي)
    • QA-DOH-FESTIVAL (الدوحة)
    • KW-KWT-AVENUES (الكويت)
  شجرة تصنيفات 4 مستويات (Clothing → Men/Women → Shirts/Dresses/…)
  3 علامات تجارية
  2 سمة (مقاس + لون) مع قيمها
  10 منتجات × 6-8 متغيّرات = 60-80 SKU
  EAN-13 لكل متغيّر
  4 قوائم أسعار (default retail + summer promo + VIP + Dubai special)
  CoA SOCPA + فترات 2026
  قيد افتتاحي 2,000,000 SAR
  3 مستخدمين (CFO، Country Manager SA، Cashier Riyadh)
  GOSI registrations لـ 2 موظفين

Run:
  py scripts/seed_clothing_customer.py

After seed:
  Tenant ID is printed. Use it to log into /pilot in Flutter.
"""

import sys
import os

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# ensure we can import app/*
sys.path.insert(0, os.path.dirname(os.path.abspath(os.path.join(__file__, ".."))))

os.environ.setdefault("DATABASE_URL", "sqlite:///./apex_pilot_seed.db")
os.environ.setdefault("ADMIN_SECRET", "apex-seed-admin")

from fastapi.testclient import TestClient
from app.main import app
from app.pilot.models import compute_ean13_checksum

client = TestClient(app)


def post(path, body=None, expect=(200, 201)):
    r = client.post(path, json=body or {})
    if r.status_code not in expect:
        # Tolerate 409 (already exists) as success when re-running
        if r.status_code == 409:
            return {"_already_exists": True, "_detail": r.text[:200]}
        raise SystemExit(f"!!! {path}: HTTP {r.status_code}: {r.text[:300]}")
    return r.json()


def get(path, expect=(200,)):
    r = client.get(path)
    if r.status_code not in expect:
        raise SystemExit(f"!!! {path}: HTTP {r.status_code}: {r.text[:300]}")
    return r.json()


def ean13(prefix12: str) -> str:
    return prefix12 + str(compute_ean13_checksum(prefix12))


print("=" * 70)
print("APEX Pilot — Seed Clothing Customer")
print("=" * 70)

# ──────────────────────────────────────────────────────────────
# 1) Seed master permissions
# ──────────────────────────────────────────────────────────────
print("\n[1/10] Seed permissions...")
r = client.post("/admin/pilot/seed-permissions",
                headers={"X-Admin-Secret": "apex-seed-admin"})
if r.status_code == 200:
    print(f"       {r.json()}")

# ──────────────────────────────────────────────────────────────
# 2) Tenant
# ──────────────────────────────────────────────────────────────
print("\n[2/10] Tenant...")
tenant = post("/pilot/tenants", {
    "slug": "advanced-fashion-group",
    "legal_name_ar": "مجموعة الأزياء المتطورة",
    "legal_name_en": "Advanced Fashion Group",
    "trade_name": "AFG",
    "primary_cr_number": "1010234567",
    "primary_vat_number": "310234567890003",
    "primary_country": "SA",
    "primary_email": "info@advancedfashion.sa",
    "primary_phone": "+966500000001",
    "tier": "enterprise",
})
if "_already_exists" in tenant:
    # look it up via slug by listing (admin required)
    lst = client.get("/pilot/tenants", headers={"X-Admin-Secret": "apex-seed-admin"})
    tenants = lst.json() if lst.status_code == 200 else []
    tenant = next((t for t in tenants if t["slug"] == "advanced-fashion-group"), None)
    if not tenant:
        raise SystemExit("Tenant exists but could not re-fetch")
TID = tenant["id"]
print(f"       ✓ tenant_id = {TID}")

# ──────────────────────────────────────────────────────────────
# 3) Entities — 6 countries
# ──────────────────────────────────────────────────────────────
print("\n[3/10] Entities (6 countries)...")
ENTITIES_DATA = [
    ("SA", "شركة الأزياء السعودية", "AFG Saudi", "SAR", "1010234567", "310234567890003"),
    ("AE", "شركة الأزياء الإمارات", "AFG UAE", "AED", "CN-1234567", "100234567890003"),
    ("QA", "شركة الأزياء قطر", "AFG Qatar", "QAR", "QA-123456", "QT-234567"),
    ("KW", "شركة الأزياء الكويت", "AFG Kuwait", "KWD", "KW-234567", None),
    ("BH", "شركة الأزياء البحرين", "AFG Bahrain", "BHD", "BH-234567", None),
    ("EG", "شركة الأزياء مصر", "AFG Egypt", "EGP", "EG-234567", "EG-VAT-234567"),
]
entities = {}
for code, name_ar, name_en, ccy, cr, vat in ENTITIES_DATA:
    e = post(f"/pilot/tenants/{TID}/entities", {
        "code": code,
        "name_ar": name_ar,
        "name_en": name_en,
        "country": code if code != "AE" else "AE",
        "type": "subsidiary",
        "functional_currency": ccy,
        "cr_number": cr,
        "vat_number": vat,
    })
    entities[code] = e
    print(f"       ✓ {code} — {ccy}")

# ──────────────────────────────────────────────────────────────
# 4) Branches
# ──────────────────────────────────────────────────────────────
print("\n[4/10] Branches (8 total)...")
BRANCHES_DATA = [
    # (entity_code, branch_code, name_ar, city, country)
    ("SA", "SA-RIY-PANORAMA", "الرياض بانوراما", "Riyadh", "SA"),
    ("SA", "SA-JED-REDSEA",   "جدة ريد سي",     "Jeddah", "SA"),
    ("SA", "SA-JED-MALL",     "جدة مول",        "Jeddah", "SA"),
    ("SA", "SA-DMM-WAHA",     "الدمام الواحة",   "Dammam", "SA"),
    ("AE", "AE-DXB-MALL",     "دبي مول",        "Dubai",  "AE"),
    ("AE", "AE-AUH-CITY",     "أبوظبي سيتي",    "Abu Dhabi", "AE"),
    ("QA", "QA-DOH-FESTIVAL", "الدوحة فستيفال", "Doha",   "QA"),
    ("KW", "KW-KWT-AVENUES",  "الأفنيوز",       "Kuwait City", "KW"),
]
branches = {}
warehouses = {}
for ecode, bcode, name_ar, city, country in BRANCHES_DATA:
    eid = entities[ecode]["id"]
    b = post(f"/pilot/entities/{eid}/branches", {
        "code": bcode, "name_ar": name_ar, "country": country, "city": city,
        "type": "retail_store",
        "pos_station_count": 2,
        "accepts_returns": True,
        "supports_delivery": True,
    })
    branches[bcode] = b

    # Main warehouse
    w = post(f"/pilot/branches/{b['id']}/warehouses", {
        "code": f"{bcode}-MAIN", "name_ar": f"{name_ar} — رئيسي",
        "type": "main", "is_default": True,
        "is_sellable_from": True, "is_receivable_to": True,
    })
    warehouses[bcode] = w
    print(f"       ✓ {bcode} + warehouse")

# ──────────────────────────────────────────────────────────────
# 5) Categories tree
# ──────────────────────────────────────────────────────────────
print("\n[5/10] Categories tree (4 levels)...")
cat_root = post(f"/pilot/tenants/{TID}/categories", {
    "code": "CLOTHING", "name_ar": "ملابس", "name_en": "Clothing",
    "icon": "checkroom", "sort_order": 1,
})
cat_men = post(f"/pilot/tenants/{TID}/categories", {
    "code": "MEN", "name_ar": "رجالي", "name_en": "Men",
    "parent_id": cat_root["id"], "sort_order": 1,
})
cat_women = post(f"/pilot/tenants/{TID}/categories", {
    "code": "WOMEN", "name_ar": "نسائي", "name_en": "Women",
    "parent_id": cat_root["id"], "sort_order": 2,
})
cat_men_shirts = post(f"/pilot/tenants/{TID}/categories", {
    "code": "MEN-SHIRTS", "name_ar": "قمصان رجالي",
    "parent_id": cat_men["id"], "default_vat_code": "standard",
})
cat_men_pants = post(f"/pilot/tenants/{TID}/categories", {
    "code": "MEN-PANTS", "name_ar": "سراويل رجالي",
    "parent_id": cat_men["id"],
})
cat_women_dress = post(f"/pilot/tenants/{TID}/categories", {
    "code": "WOMEN-DRESSES", "name_ar": "فساتين",
    "parent_id": cat_women["id"],
})
print(f"       ✓ {len(get(f'/pilot/tenants/{TID}/categories?include_inactive=true'))} تصنيف")

# ──────────────────────────────────────────────────────────────
# 6) Brands
# ──────────────────────────────────────────────────────────────
print("\n[6/10] Brands (3)...")
brands = {}
for bcode, name_ar, name_en, origin in [
    ("APEX", "أبيكس", "APEX Fashion", "SA"),
    ("ORIENT", "أورينت", "Orient Classic", "AE"),
    ("ZENITH", "زينيث", "Zenith", "FR"),
]:
    br = post(f"/pilot/tenants/{TID}/brands", {
        "code": bcode, "name_ar": name_ar, "name_en": name_en,
        "country_of_origin": origin,
    })
    brands[bcode] = br
    print(f"       ✓ {bcode}")

# ──────────────────────────────────────────────────────────────
# 7) Attributes
# ──────────────────────────────────────────────────────────────
print("\n[7/10] Attributes (size + color)...")
post(f"/pilot/tenants/{TID}/attributes", {
    "code": "size", "name_ar": "المقاس", "name_en": "Size",
    "type": "size", "is_required_for_variant": True,
    "values": [
        {"code": "XS", "name_ar": "صغير جداً", "sort_order": 1},
        {"code": "S",  "name_ar": "صغير",       "sort_order": 2},
        {"code": "M",  "name_ar": "وسط",        "sort_order": 3},
        {"code": "L",  "name_ar": "كبير",       "sort_order": 4},
        {"code": "XL", "name_ar": "كبير جداً", "sort_order": 5},
    ],
})
post(f"/pilot/tenants/{TID}/attributes", {
    "code": "color", "name_ar": "اللون", "name_en": "Color",
    "type": "color", "is_required_for_variant": True, "input_type": "swatch",
    "values": [
        {"code": "WHITE", "name_ar": "أبيض",   "hex_color": "#FFFFFF"},
        {"code": "BLACK", "name_ar": "أسود",   "hex_color": "#000000"},
        {"code": "NAVY",  "name_ar": "كحلي",  "hex_color": "#000080"},
        {"code": "RED",   "name_ar": "أحمر",  "hex_color": "#FF0000"},
    ],
})
print(f"       ✓ size (5 قيم) + color (4 قيم)")

# ──────────────────────────────────────────────────────────────
# 8) Products + Variants + Barcodes
# ──────────────────────────────────────────────────────────────
print("\n[8/10] Products (10 × ~6 variants each)...")
PRODUCTS = [
    # (code, name_ar, name_en, cat_id, brand_id, sizes, colors, cost, price)
    ("PS-001", "قميص بولو كلاسيك",  "Classic Polo Shirt",    cat_men_shirts["id"], brands["APEX"]["id"],   ["S","M","L","XL"], ["WHITE","BLACK","NAVY"], "45.00",  "129.00"),
    ("SH-002", "قميص رسمي أبيض",     "Formal White Shirt",    cat_men_shirts["id"], brands["ORIENT"]["id"], ["S","M","L","XL"], ["WHITE"],                  "70.00",  "199.00"),
    ("SH-003", "قميص كاروه",         "Checkered Shirt",       cat_men_shirts["id"], brands["APEX"]["id"],   ["M","L","XL"],     ["RED","NAVY"],             "55.00",  "149.00"),
    ("PN-001", "سروال جينز",         "Jeans Straight",        cat_men_pants["id"],  brands["ZENITH"]["id"], ["S","M","L","XL"], ["NAVY","BLACK"],           "90.00",  "249.00"),
    ("PN-002", "سروال قماش",         "Chino Pants",           cat_men_pants["id"],  brands["APEX"]["id"],   ["M","L","XL"],     ["BLACK","NAVY"],           "75.00",  "199.00"),
    ("DR-001", "فستان سهرة أسود",    "Black Evening Dress",   cat_women_dress["id"],brands["ORIENT"]["id"], ["XS","S","M","L"], ["BLACK"],                  "120.00", "399.00"),
    ("DR-002", "فستان كاجوال",       "Casual Midi Dress",     cat_women_dress["id"],brands["APEX"]["id"],   ["S","M","L"],      ["WHITE","RED","NAVY"],     "80.00",  "229.00"),
    ("DR-003", "فستان ماكسي",        "Maxi Dress",            cat_women_dress["id"],brands["ZENITH"]["id"], ["S","M","L","XL"], ["WHITE","BLACK"],          "100.00", "299.00"),
    ("PS-002", "بولو قطن",           "Cotton Polo",           cat_men_shirts["id"], brands["APEX"]["id"],   ["M","L","XL"],     ["WHITE","BLACK","NAVY","RED"], "40.00", "119.00"),
    ("SH-004", "تي شيرت بسيط",      "Basic T-Shirt",         cat_men_shirts["id"], brands["APEX"]["id"],   ["S","M","L","XL"], ["WHITE","BLACK"],          "25.00",  "79.00"),
]

ean_prefix_base = 628012300   # Saudi GS1 prefix 9 digits — will append 3-digit seq
ean_seq = 0

total_variants = 0
for code, name_ar, name_en, cat_id, brand_id, sizes, colors, cost, price in PRODUCTS:
    variants_in = []
    for sz in sizes:
        for col in colors:
            variants_in.append({
                "sku": f"{code}-{sz}-{col}",
                "display_name_ar": f"{name_ar} — {sz} — {col}",
                "attribute_values": {"size": sz, "color": col},
                "default_cost": cost, "list_price": price, "currency": "SAR",
                "track_stock": True, "reorder_point": "10", "reorder_qty": "50",
            })
    prod = post(f"/pilot/tenants/{TID}/products", {
        "code": code, "name_ar": name_ar, "name_en": name_en,
        "category_id": cat_id, "brand_id": brand_id,
        "kind": "goods", "vat_code": "standard",
        "tags": ["bestseller" if code.startswith("PS") else "seasonal"],
        "variant_attribute_codes": ["size", "color"],
        "variants": variants_in,
    })
    # Barcodes
    for v in prod["variants"]:
        ean_seq += 1
        prefix12 = f"{ean_prefix_base}{ean_seq:03d}"
        bc = ean13(prefix12)
        post(f"/pilot/variants/{v['id']}/barcodes", {
            "value": bc, "type": "ean13", "scope": "primary",
        })
        total_variants += 1
    print(f"       ✓ {code}: {len(prod['variants'])} متغيّر")

print(f"       إجمالي: {total_variants} متغيّر + {total_variants} باركود EAN-13")

# ──────────────────────────────────────────────────────────────
# 9) Initial stock — لكل متغيّر، توزيع على المستودعات الـ 4 السعودية
# ──────────────────────────────────────────────────────────────
print("\n[9/10] Initial stock receipts (PO) for SA warehouses...")
prods_lst = get(f"/pilot/tenants/{TID}/products?limit=500")
for p in prods_lst:
    variants = get(f"/pilot/products/{p['id']}/variants")
    for v in variants:
        for bcode in ["SA-RIY-PANORAMA", "SA-JED-REDSEA", "SA-JED-MALL", "SA-DMM-WAHA"]:
            wh = warehouses[bcode]
            post("/pilot/stock/movements", {
                "warehouse_id": wh["id"],
                "variant_id": v["id"],
                "qty": "25",
                "unit_cost": v["default_cost"] or "45",
                "reason": "po_receipt",
                "reference_number": "PO-SEED-001",
            }, expect=(201,))
print(f"       ✓ {total_variants} × 4 WH × 25 = {total_variants*100} قطعة")

# ──────────────────────────────────────────────────────────────
# 10) Price Lists + GL seed + ZATCA
# ──────────────────────────────────────────────────────────────
print("\n[10/10] Price Lists + GL + ZATCA...")

# Default retail (tenant-wide SAR)
pl = post(f"/pilot/tenants/{TID}/price-lists", {
    "code": "SA-RETAIL-DEFAULT",
    "name_ar": "قائمة التجزئة الافتراضية SAR",
    "kind": "retail", "season": "year_round", "currency": "SAR",
    "scope": "tenant", "valid_from": "2026-01-01", "priority": 100,
    "prices_include_vat": True,
    "items": [
        {"variant_id": v["id"], "unit_price": v["list_price"] or "129.00"}
        for p in prods_lst for v in get(f"/pilot/products/{p['id']}/variants")
    ],
})
post(f"/pilot/price-lists/{pl['id']}/activate", {})
print(f"       ✓ قائمة التجزئة الافتراضية SAR ({len(pl.get('items', []))} بند)")

# Summer promo (entity=SA, priority 200)
pl2 = post(f"/pilot/tenants/{TID}/price-lists", {
    "code": "SA-SUMMER-2026",
    "name_ar": "عروض الصيف 2026",
    "kind": "promo", "season": "summer", "currency": "SAR",
    "scope": "entity", "entity_id": entities["SA"]["id"],
    "valid_from": "2026-04-01", "valid_to": "2026-09-30",
    "priority": 200, "is_promo": True,
    "promo_badge_text_ar": "صيف 2026", "promo_color_hex": "#FFD700",
    "items": [
        {"variant_id": v["id"],
         "unit_price": f"{float(v['list_price'] or 129) * 0.80:.2f}",
         "original_price": v["list_price"] or "129.00",
         "promo_discount_pct": "20.000"}
        for p in prods_lst for v in get(f"/pilot/products/{p['id']}/variants")
    ],
})
post(f"/pilot/price-lists/{pl2['id']}/activate", {})
print(f"       ✓ عروض الصيف 2026 (20% خصم) SAR")

# Dubai-specific AED price list
dxb_b = branches.get("AE-DXB-MALL")
if dxb_b:
    pl3 = post(f"/pilot/tenants/{TID}/price-lists", {
        "code": "AE-DXB-RETAIL",
        "name_ar": "أسعار دبي مول",
        "kind": "retail", "season": "year_round", "currency": "AED",
        "scope": "branch", "branch_ids": [dxb_b["id"]],
        "valid_from": "2026-01-01", "priority": 300,
        "prices_include_vat": True,
        "items": [
            {"variant_id": v["id"],
             "unit_price": f"{float(v['list_price'] or 129) * 1.05:.2f}"}
            for p in prods_lst for v in get(f"/pilot/products/{p['id']}/variants")
        ],
    })
    post(f"/pilot/price-lists/{pl3['id']}/activate", {})
    print(f"       ✓ أسعار دبي مول AED (+5% حسب العملة)")

# GL seed — فقط للكيان السعودي (أمثلة)
for ecode in ["SA"]:
    eid = entities[ecode]["id"]
    post(f"/pilot/entities/{eid}/coa/seed", expect=(200,))
    post(f"/pilot/entities/{eid}/fiscal-periods/seed", {"year": 2026}, expect=(200,))
    post("/pilot/journal-entries", {
        "entity_id": eid,
        "kind": "opening",
        "je_date": "2026-01-01",
        "memo_ar": "الرصيد الافتتاحي 2026",
        "lines": [
            {"account_code": "1110", "debit": "500000.00", "description": "نقد افتتاحي"},
            {"account_code": "1140", "debit": "1500000.00", "description": "مخزون افتتاحي"},
            {"account_code": "3100", "credit": "2000000.00", "description": "رأسمال"},
        ],
        "auto_post": True,
        "created_by_user_id": "owner-001",
    }, expect=(201,))
    # ZATCA onboard (simulated)
    post(f"/pilot/entities/{eid}/zatca/onboard?simulate=true", expect=(200,))
print(f"       ✓ GL + ZATCA onboard للكيان SA")

# GOSI sample employee
g = post("/pilot/gosi/registrations", {
    "entity_id": entities["SA"]["id"],
    "employee_user_id": "emp-sa-001",
    "employee_number": "E001",
    "national_id": "1010234567",
    "employee_name_ar": "أحمد المطيري",
    "is_saudi": True,
    "contribution_wage": "12000.00",
    "registered_at": "2026-01-01",
    "gosi_subscriber_number": "SBR-001",
})
print(f"       ✓ موظف GOSI واحد")


# ──────────────────────────────────────────────────────────────
# الخلاصة
# ──────────────────────────────────────────────────────────────
print("\n" + "=" * 70)
print("✅ Seed مُكتمل بنجاح!")
print("=" * 70)
print(f"""
 Tenant ID:      {TID}
 Tenant slug:    advanced-fashion-group
 Tenant name:    مجموعة الأزياء المتطورة

 Entities:       6 ({'SA AE QA KW BH EG'})
 Branches:       8
 Warehouses:     8 (main per branch)
 Categories:     6 (شجرة 3 مستويات)
 Brands:         3
 Products:       10
 Variants:       {total_variants}
 Barcodes:       {total_variants} (EAN-13 معتمدة)
 Initial Stock:  {total_variants*100} قطعة (SA فقط — 25/SKU/WH × 4 WH)
 Price Lists:    3 (SA-RETAIL-DEFAULT + SA-SUMMER-2026 + AE-DXB-RETAIL)
 GL:             37 حساب SOCPA + 12 فترة 2026 + قيد افتتاحي 2M SAR (SA)
 ZATCA:          Onboarded (simulated) للكيان SA
 GOSI:           1 موظف مُسجّل

 استخدم Tenant ID أعلاه في:
   Flutter:  http://localhost:port/#/pilot → انقر "اختر مستأجراً" → الصق ID
   أو API مباشرة:  GET /pilot/tenants/{TID}
""")
