# POS ZATCA QR — Phase 1 Compliance on Receipt

**Status:** in force as of 2026-05-11.
**Closes:** GAP-4 from the post-PR-#189 QA audit (carried through PR #190
and the post-#190 audit).

---

## Why this PR exists

ZATCA Phase 1 requires every B2C simplified-tax invoice — including POS
receipts — to display a TLV-encoded QR code containing seller name +
VAT registration + invoice timestamp + invoice total + VAT total.

The pure-Dart helper [`core/zatca_tlv.dart`](../apex_finance/lib/core/zatca_tlv.dart)
has shipped since PR #187 and is already used on the sales-invoice
details screen. But the POS Quick Sale receipt card — the surface where
the cashier shows the receipt to the customer — was never wired to use
it. Every POS receipt shipped to date was missing the QR.

## What this PR ships

### 🟢 QR on the POS receipt card

The success card on `pos_quick_sale_screen.dart` now renders a Phase-1
TLV QR alongside the WhatsApp share + JE link.

Layout: QR on the left (96×96 white-bg), share + JE buttons on the right,
small "ZATCA QR (Phase 1)" label above the buttons so a cashier knows
what they're showing the customer.

### 🟢 Receipt captures the inputs

`_lastReceipt` now records the four extra fields the helper needs:

```dart
'issued_at_utc': DateTime.now().toUtc().toIso8601String(),
'seller_vat_number': '300000000000003',  // placeholder until entity API exposes it
'seller_name': 'APEX',                    // same — see below
// Already captured pre-fix:
'vat': _vatAmount,
'total': _total,
```

`seller_name` and `seller_vat_number` use the same hardcoded placeholders
as the sales-details screen — the entity-setup API doesn't persist them
yet. When entity setup exposes VAT + Arabic name fields, swap these for
the real values via a one-line change.

### 🟢 Defensive rendering

`zatcaQrBase64()` throws when a TLV value exceeds 255 bytes (Phase 1 uses
1-byte length encoding). The QR build is wrapped in `try / catch` —
on error the QR is hidden but the rest of the receipt still renders so
the cashier can complete the sale.

---

## Files changed

| File | Change |
|---|---|
| [`apex_finance/lib/screens/operations/pos_quick_sale_screen.dart`](../apex_finance/lib/screens/operations/pos_quick_sale_screen.dart) | Import `zatca_tlv.dart` + `qr_flutter`, capture timestamp/seller in `_lastReceipt`, render `QrImageView` in `_receiptCard` defensively |
| [`apex_finance/test/screens/pos_zatca_qr_test.dart`](../apex_finance/test/screens/pos_zatca_qr_test.dart) | 6 source-grep contracts |

## Test coverage

6 tests in [`pos_zatca_qr_test.dart`](../apex_finance/test/screens/pos_zatca_qr_test.dart):

| Group | Tests |
|---|---|
| QR helper wired | 3 (imports, all 5 Phase-1 tags passed, QrImageView rendered) |
| Receipt captures QR inputs | 2 (5 keys present on `_lastReceipt`, TLV tag schedule unchanged) |
| Defensive rendering | 1 (try/catch + null-fallback + render guard) |

All 6 pass. `flutter analyze` clean on the touched file.

## Manual UAT (after deploy)

1. Open POS Quick Sale (`/pos/quick-sale`).
2. Enter amount = 100, VAT = 15%, method = نقد.
3. Click "سجّل البيع".
4. **Expect**: success snackbar + receipt card appears.
5. **Expect on the receipt card**: a clean white-bg QR (96×96) on the left,
   WhatsApp share button + "عرض القيد" outline button on the right,
   "ZATCA QR (Phase 1)" label above the buttons.
6. Scan the QR with any ZATCA-compatible scanner — should decode to a
   TLV payload containing all 5 fields (seller=APEX, VAT=300000000000003,
   timestamp ISO-8601 UTC, total=115.00, vat=15.00).

## Remaining gaps (next sprint)

| Gap | Status |
|---|---|
| POS Quick Sale multi-line | **Not in this PR** — bookmarked for G-POS-MULTILINE |
| ProductPickerOrCreate on POS | bundled with G-POS-MULTILINE |
| Real seller name + VAT from entity settings | needs entity-settings persistence API (separate sprint) |
| Camera barcode scanner / CODE128 internal barcode | hardware sprint |

The QR uses placeholder seller name/VAT that match what the sales-details
screen already uses. Replacing them with real entity-level values is a
one-line change once the entity-settings API persists the fields.
