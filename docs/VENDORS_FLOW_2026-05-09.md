# Vendors Flow — G-FIN-VENDORS-COMPLETE

**Status:** in force as of 2026-05-09 (Sprint 3 of the Finance Module
7-sprint plan).
**Closes:** Sprint 1 audit Gap §3 row 3 ("Vendor creation form
missing"). Mirror of [Sprint 2's customer flow](CUSTOMERS_FLOW_2026-05-09.md).

---

## Vendor-specific differences from customers

| Aspect | Customer | Vendor |
|---|---|---|
| Required name field | `name_ar` | `legal_name_ar` |
| Default payment terms | `net_30` | `net_60` (working-capital asymmetry) |
| Bank fields | none | `bank_name`, `bank_iban`, `bank_swift` |
| Bank validation | n/a | KSA IBAN: SA + 22 digits = 24 chars total when `country == 'SA'` |
| Code prefix | `CUST-NNN` | `VEND-NNN` |
| Kind enum | `company` / `individual` | `goods` / `services` / `both` / `employee` / `government` |
| `is_preferred` | n/a | toggle for preferred-supplier flag |
| Details tab 3 | sales invoices | purchase invoices (filtered by `vendor_id`) |
| Currency field | `currency` | `default_currency` |

## Files

| File | Purpose |
|---|---|
| [vendor_create_modal.dart](../apex_finance/lib/screens/operations/vendor_create_modal.dart) | 19-field modal with KSA IBAN validator + 15-digit VAT validator. |
| [vendor_details_screen.dart](../apex_finance/lib/screens/operations/vendor_details_screen.dart) | 3-tab details (تفاصيل / السجل المالي / فواتير المشتريات). |
| [vendor_picker_or_create.dart](../apex_finance/lib/widgets/forms/vendor_picker_or_create.dart) | Autocomplete picker + inline `+ مورد جديد`. Used by Sprint 6's Purchase Invoice line picker. |
| [vendors_list_screen.dart](../apex_finance/lib/screens/operations/vendors_list_screen.dart) | `_onCreate` rewritten + row tap routes to new path. |
| [router.dart](../apex_finance/lib/core/router.dart) | New GoRoute `/app/erp/finance/vendors/:vendorId`. |
| [api_service.dart](../apex_finance/lib/api_service.dart) | New methods: `pilotGetVendor`, `pilotUpdateVendor`, `pilotVendorLedger`. |

## Test coverage

[vendors_complete_test.dart](../apex_finance/test/screens/vendors_complete_test.dart) — 9 source-grep contracts. Verified: 9/9 pass.

## API endpoints (all pre-existing)

- `GET /pilot/tenants/{tid}/vendors`
- `POST /pilot/tenants/{tid}/vendors`
- `GET /pilot/vendors/{id}`
- `GET /pilot/vendors/{id}/ledger`
- `GET /pilot/entities/{eid}/purchase-invoices` (filtered client-side by `vendor_id`)
