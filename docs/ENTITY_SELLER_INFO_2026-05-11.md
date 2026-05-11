# G-ENTITY-SELLER-INFO — Real ZATCA seller identity per Entity

**Date:** 2026-05-11
**Severity:** medium (ZATCA accuracy)
**Branch:** `feat/g-entity-seller-info`

## Problem

ZATCA Phase-1 QR codes are generated correctly by `core/zatca_tlv.dart`, but the seller-identity fields fed into the helper were hardcoded literals:

- `'APEX'` and `'APEX UAT'` for the seller's Arabic legal name
- `'300000000000003'` for the seller's VAT registration number

These appeared in two places:

1. `apex_finance/lib/screens/operations/pos_quick_sale_screen.dart` (`_lastReceipt` map written on POS sale success)
2. `apex_finance/lib/screens/operations/sales_invoice_details_screen.dart` (`_buildQrCode` method)

Any ZATCA scanner reading the QR would therefore see the wrong selling entity — a real compliance gap once the pilot tenant has multiple entities (SA, AE, QA, KW, BH, EG) each with its own VAT registration.

In `sales_invoice_details_screen.dart`, the pre-fix code also used `inv['customer_vat_number']` as the fallback for `vatNumber`, which is doubly wrong: ZATCA tag 2 expects the **seller's** VAT, not the buyer's.

## Solution

Persist real seller info on the Entity model, read it through a session cache, and have both screens consume the cache with the placeholder strings retained as fallbacks.

### Backend — `app/pilot/`

**Model (`models/entity.py`)**

Added three nullable columns to `Entity`:

| Column                | Type           | Notes                                                                  |
| --------------------- | -------------- | ---------------------------------------------------------------------- |
| `seller_vat_number`   | `String(20)`   | 15-digit ZATCA VAT registration. No format validation enforced (UI handles masking). |
| `seller_name_ar`      | `String(255)`  | Arabic legal name shown on the receipt. Falls back to `name_ar` on the frontend if null. |
| `seller_address_ar`   | `String(512)`  | Arabic legal address — Phase-2 readiness. Not rendered in Phase-1 QR. |

Nullable so existing entities load cleanly. The repo uses SQLAlchemy `create_all` (no alembic migration needed) so the new columns appear automatically on next boot.

**Schema (`schemas/entity.py`)**

- `EntityRead` surfaces the three fields (so GET `/pilot/entities/{id}` returns them and the frontend cache can read them).
- `EntityUpdate` accepts the three fields as optional patches (so a settings UI can persist them via PATCH `/pilot/entities/{id}`).

**Routes (`routes/pilot_routes.py`)**

`GET /pilot/entities/{entity_id}` and `PATCH /pilot/entities/{entity_id}` already existed — no route changes needed. The new fields surface automatically because the response_model is `EntityRead`.

### Frontend — `apex_finance/`

**api_service (`lib/api_service.dart`)**

```dart
static Future<ApiResult> pilotGetEntity(String entityId) =>
    _get('/pilot/entities/$entityId');

static Future<ApiResult> pilotUpdateEntitySellerInfo(
  String entityId,
  Map<String, dynamic> payload,
) =>
    _patch('/pilot/entities/$entityId', payload);
```

**session.dart (`lib/core/session.dart`)**

Added three in-memory caches with localStorage backing:

- `S.savedSellerVatNumber` — `String?` getter/setter; backed by `pilot.seller_vat`
- `S.savedSellerNameAr` — backed by `pilot.seller_name_ar`
- `S.savedSellerAddressAr` — backed by `pilot.seller_address_ar`

Added `S.fetchEntitySellerInfo()` — an async helper that calls `pilotGetEntity(S.savedEntityId)` and populates the three caches. Silent on failure (the placeholder fallback keeps the QR rendering).

`S.clear()` now wipes the three localStorage keys so the next user logging in on the same browser does not inherit the previous tenant's ZATCA identity (same defense-in-depth as G-LEGACY-KEY-AUDIT).

**POS receipt (`pos_quick_sale_screen.dart`)**

- Added `initState()` calling `S.fetchEntitySellerInfo()` (fire-and-forget).
- `_lastReceipt` now reads `S.savedSellerVatNumber ?? '300000000000003'` and `S.savedSellerNameAr ?? 'APEX'` instead of the bare literals.

**Sales details QR (`sales_invoice_details_screen.dart`)**

- Imported `'../../core/session.dart'`.
- Added `S.fetchEntitySellerInfo()` to `initState()`.
- `_buildQrCode()` now reads `sellerName: S.savedSellerNameAr ?? 'APEX UAT'` and `vatNumber: S.savedSellerVatNumber ?? '300000000000003'`. The pre-fix code's wrong fallback to `inv['customer_vat_number']` (buyer VAT) is now dropped.

## Caching strategy

```
┌────────────────────┐
│ POS screen opens   │
│ sales-details opens│──┐
└────────────────────┘  │
                        ▼
              initState() fires
              S.fetchEntitySellerInfo()  (fire-and-forget)
                        │
                        ▼
        GET /pilot/entities/{savedEntityId}
                        │
                        ▼
            Cache: S._cachedSellerVat
                   S._cachedSellerNameAr
                   S._cachedSellerAddressAr
            LocalStorage:
                   pilot.seller_vat
                   pilot.seller_name_ar
                   pilot.seller_address_ar
                        │
                        ▼
         Receipt / QR render reads cache
         (placeholder fallback when null)
```

The fire-and-forget pattern means the *first* POS sale or sales-details view after page load may still see the placeholder if the network is slow — every subsequent render uses real values. Page refresh keeps the values via localStorage.

## Optional: Entity setup UI

`entity_setup_screen.dart` is 2,100 lines and complex; this sprint skips wiring the three new fields into a form. The `pilotUpdateEntitySellerInfo` helper is ready to be called once the UI is added in a follow-up sprint. For UAT, the values can be seeded via the API directly:

```bash
curl -X PATCH https://api.example.com/pilot/entities/{ENTITY_ID} \
  -H 'Authorization: Bearer ...' \
  -H 'Content-Type: application/json' \
  -d '{
    "seller_vat_number": "310123456700003",
    "seller_name_ar": "شركة أبكس للتجارة",
    "seller_address_ar": "الرياض، طريق الملك فهد"
  }'
```

## Tests

`apex_finance/test/screens/entity_seller_info_test.dart` — 15 source-grep contracts across six groups:

1. **Backend model + schema (4 tests)** — three columns declared; `EntityRead` surfaces them; `EntityUpdate` accepts them; GET + PATCH endpoints registered.
2. **api_service (2 tests)** — `pilotGetEntity` + `pilotUpdateEntitySellerInfo` exist, hit the right URLs, use the right HTTP verbs.
3. **Session cache (4 tests)** — `savedSellerVatNumber` + `savedSellerNameAr` getters; `fetchEntitySellerInfo` helper; `S.clear()` wipes the new localStorage keys.
4. **POS receipt (3 tests)** — reads from session, no longer hardcodes `'APEX'` / `'300000000000003'` as primary values, `initState` triggers the fetch.
5. **Sales details QR (2 tests)** — reads from session, no longer hardcodes `'APEX UAT'` as primary value, `initState` triggers the fetch.

CRLF safety: every multi-line regex uses `[\s\S]*?` and avoids both literal `\n` and the Dart-unsupported `\Z` anchor (Dart treats `\Z` as a literal `Z`, which silently matched inside "ZATCA" comments during development).

## UAT steps

1. Boot the dev backend so SQLAlchemy `create_all` adds the three columns to `pilot_entities`.
2. As the pilot tenant admin, PATCH `/pilot/entities/{savedEntityId}` with real seller info (see curl example above).
3. Open `/pos/quick-sale` — `initState` fires the GET; on the next sale, scan the QR with a ZATCA-Phase-1 reader and verify the seller name + VAT number match the PATCH payload.
4. Issue a sales invoice via `/app/erp/finance/sales-invoices/{id}` and scan the QR on the issued page — same expected behaviour.
5. Without filling the entity (fresh tenant), confirm the placeholder QR (`APEX` / `300000000000003`) still renders — i.e. the fallback works.
6. Sign out and sign in as a different tenant — confirm the previous tenant's seller info is not leaked (S.clear wipes the three localStorage keys).

## Out of scope

- `pilotCreatePosTransaction` and POS-session-creation code (sibling task G-POS-BACKEND-INTEGRATION).
- Validation of the 15-digit ZATCA VAT format on the backend.
- An entity-settings UI to edit the three fields (future sprint — the API is ready).
- ZATCA Phase-2 cryptographic-stamp signing (the existing `zatca_csid_id` column is unchanged).
