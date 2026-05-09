/// G-FIN-PILOT-API-PREFIX — source-grep regression test pinning the
/// correct `/api/v1/pilot/` vs `/pilot/` split in api_service.dart.
///
/// **Why this exists**
///
/// The FastAPI backend mounts pilot routers under TWO different
/// prefixes (asymmetry pre-dates Sprint 1):
///
///   * `customer_routes.py` → `/api/v1/pilot` (customer + sales-invoice
///     endpoints)
///   * everything else (`purchasing_routes`, `catalog_routes`,
///     `pos_routes`, `gl_routes`, `pilot_routes`) → `/pilot`
///
/// Pre-hotfix, the `ApiService.pilot*` methods all used
/// `/api/v1/pilot/` which 404'd in production for everything except
/// customer + sales-invoice. The bug surfaced when Sprint 3's
/// VendorCreateModal tried to POST and got "Not Found" live.
///
/// This test pins the split so a future copy-paste of a customer
/// method into the vendor/product/POS sections doesn't silently bring
/// back the wrong prefix.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    final f = File('lib/api_service.dart');
    expect(f.existsSync(), isTrue, reason: 'api_service.dart missing');
    src = f.readAsStringSync();
  });

  group('G-FIN-PILOT-API-PREFIX — non-customer pilot paths', () {
    // Methods that call non-customer pilot endpoints. These MUST use
    // `/pilot/...` (no /api/v1 prefix). If any of them appears with
    // `/api/v1/pilot/` instead, the hotfix has regressed.
    const mustBePilotOnly = <String>[
      'pilotListVendors',
      'pilotCreateVendor',
      'pilotGetVendor',
      'pilotUpdateVendor',
      'pilotVendorLedger',
      'pilotListProducts',
      'pilotCreateProduct',
      'pilotGetProduct',
      'pilotListProductVariants',
      'pilotCreateProductVariant',
      'pilotBarcodeLookup',
      'pilotListCategories',
      'pilotListBrands',
      'pilotListJournalEntries',
      'pilotCreateJournalEntry',
      'pilotPostJournalEntry',
      'pilotGetJournalEntry',
      'pilotListPOs',
      'pilotCreatePO',
      'pilotApprovePO',
      'pilotIssuePO',
      'pilotPOReceipts',
      'pilotListPurchaseInvoices',
      'pilotPostPurchaseInvoice',
      'pilotCreatePurchaseInvoice',
      'pilotCreateVendorPayment',
      'pilotListPosSessions',
      'pilotCreatePosSession',
      'pilotClosePosSession',
      'pilotZReport',
      'pilotListPosTransactions',
      'pilotPostPosToGL',
      'pilotListBranches',
      'pilotEntityBranches',
      'pilotGoodsReceiptCreate',
    ];

    for (final method in mustBePilotOnly) {
      test('test_${method}_uses_pilot_prefix_not_api_v1_pilot', () {
        final methodIdx = src.indexOf('pilot$method'.replaceFirst('pilot', '$method'));
        final realIdx = src.indexOf(method);
        expect(realIdx, greaterThan(0),
            reason: '$method must exist on ApiService');
        // Look at the next ~250 chars after the method name to find
        // the path string. Reject any /api/v1/pilot/ in that window.
        final body = src.substring(realIdx, realIdx + 250);
        expect(body.contains('/api/v1/pilot/'), isFalse,
            reason: '$method must use /pilot/... NOT /api/v1/pilot/. '
                'See G-FIN-PILOT-API-PREFIX hotfix '
                '(2026-05-09) — the backend mounts purchasing_routes, '
                'catalog_routes, pos_routes, gl_routes, and pilot_routes '
                'at prefix=/pilot, NOT /api/v1/pilot.');
      });
    }
  });

  group('G-FIN-PILOT-API-PREFIX — customer + sales-invoice MUST stay /api/v1/pilot/', () {
    // Customer + sales-invoice endpoints live in customer_routes.py
    // which mounts at /api/v1/pilot. These methods MUST keep that
    // prefix; removing it would break live customer flows.
    const mustBeApiV1Pilot = <String>[
      'pilotListCustomers',
      'pilotCreateCustomer',
      'pilotGetCustomer',
      'pilotUpdateCustomer',
      'pilotCustomerLedger',
      'pilotCreateSalesInvoice',
      'pilotIssueSalesInvoice',
      'pilotListSalesInvoices',
      'pilotRecordCustomerPayment',
    ];

    for (final method in mustBeApiV1Pilot) {
      test('test_${method}_keeps_api_v1_pilot_prefix', () {
        final realIdx = src.indexOf(method);
        expect(realIdx, greaterThan(0),
            reason: '$method must exist on ApiService');
        final body = src.substring(realIdx, realIdx + 250);
        expect(body.contains('/api/v1/pilot/'), isTrue,
            reason: '$method must use /api/v1/pilot/ — its backend route '
                'is in customer_routes.py with prefix=/api/v1/pilot. '
                'Removing the /api/v1 segment would 404 in production.');
      });
    }
  });
}
