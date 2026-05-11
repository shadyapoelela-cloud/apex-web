/// G-ENTITY-SELLER-INFO — regression tests for ZATCA seller identity.
///
/// Pre-fix: POS receipts and the sales-invoice details QR rendered the
/// hardcoded placeholders `'APEX'` / `'APEX UAT'` and the static VAT
/// number `'300000000000003'`. That made every Phase-1 QR show the
/// wrong selling entity once scanned. This contract suite pins the
/// real-data wiring: backend model + schema + GET endpoint, frontend
/// api_service helpers, session cache, and the two screens reading
/// from the cache with placeholder fallbacks.
///
/// Source-grep style (no widget/HTTP mocks) so the tests run on a
/// vanilla Flutter checkout in <10s. CRITICAL: every multi-line
/// assertion uses `RegExp` (not literal `\n`) to survive the Windows
/// CRLF vs Unix LF source-checkout split.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String entityModelSrc;
  late String entitySchemaSrc;
  late String pilotRoutesSrc;
  late String apiServiceSrc;
  late String sessionSrc;
  late String posSrc;
  late String salesDetailsSrc;

  setUpAll(() {
    String read(String p) {
      // The test runner sets cwd to `apex_finance/`. Backend files
      // live one directory up under `app/pilot/...` so we walk out.
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    entityModelSrc = read('../app/pilot/models/entity.py');
    entitySchemaSrc = read('../app/pilot/schemas/entity.py');
    pilotRoutesSrc = read('../app/pilot/routes/pilot_routes.py');
    apiServiceSrc = read('lib/api_service.dart');
    sessionSrc = read('lib/core/session.dart');
    posSrc = read('lib/screens/operations/pos_quick_sale_screen.dart');
    salesDetailsSrc =
        read('lib/screens/operations/sales_invoice_details_screen.dart');
  });

  group('G-ENTITY-SELLER-INFO — Backend model + schema', () {
    test('test_entity_model_declares_three_seller_info_columns', () {
      // SQLAlchemy auto-create handles the migration since columns are
      // nullable; the model file is the single source of truth.
      expect(
        RegExp(r'seller_vat_number\s*=\s*Column\(').hasMatch(entityModelSrc),
        isTrue,
        reason: 'Entity model must declare seller_vat_number column',
      );
      expect(
        RegExp(r'seller_name_ar\s*=\s*Column\(').hasMatch(entityModelSrc),
        isTrue,
        reason: 'Entity model must declare seller_name_ar column',
      );
      expect(
        RegExp(r'seller_address_ar\s*=\s*Column\(').hasMatch(entityModelSrc),
        isTrue,
        reason: 'Entity model must declare seller_address_ar column',
      );
    });

    test('test_entity_read_schema_surfaces_seller_info', () {
      // GET /pilot/entities/{id} returns EntityRead — the new fields
      // MUST appear there or the frontend cache never populates.
      // NOTE on regex: Dart's RegExp treats `\Z` as a literal Z, so
      // a naive `(?=class\s+\w+|\Z)` lookahead silently stops at the
      // first uppercase Z (e.g. inside a "ZATCA" comment). We instead
      // split EntityRead from EntityUpdate using a single anchor
      // (`class EntityUpdate`) which is unambiguous.
      final readBlock = RegExp(
        r'class\s+EntityRead\b[\s\S]*?(?=class\s+EntityUpdate\b)',
      ).firstMatch(entitySchemaSrc);
      expect(readBlock, isNotNull, reason: 'EntityRead class must exist');
      final body = readBlock!.group(0)!;
      expect(body.contains('seller_vat_number'), isTrue);
      expect(body.contains('seller_name_ar'), isTrue);
      expect(body.contains('seller_address_ar'), isTrue);
    });

    test('test_entity_update_schema_accepts_seller_info_patch', () {
      // PATCH /pilot/entities/{id} accepts EntityUpdate — required for
      // the settings UI (or pilotUpdateEntitySellerInfo callers) to
      // persist real values. Same `\Z`-avoidance pattern as above —
      // bound to the next class name (`BranchCreate`).
      final updateBlock = RegExp(
        r'class\s+EntityUpdate\b[\s\S]*?(?=class\s+BranchCreate\b)',
      ).firstMatch(entitySchemaSrc);
      expect(updateBlock, isNotNull, reason: 'EntityUpdate class must exist');
      final body = updateBlock!.group(0)!;
      expect(body.contains('seller_vat_number'), isTrue);
      expect(body.contains('seller_name_ar'), isTrue);
      expect(body.contains('seller_address_ar'), isTrue);
    });

    test('test_pilot_routes_expose_get_and_patch_entity', () {
      // The endpoints existed before this sprint but pin them so a
      // future refactor doesn't relocate them and silently break the
      // frontend cache.
      expect(
        RegExp(r'@router\.get\("/entities/\{entity_id\}"').hasMatch(
            pilotRoutesSrc),
        isTrue,
        reason: 'GET /pilot/entities/{entity_id} must be registered',
      );
      expect(
        RegExp(r'@router\.patch\("/entities/\{entity_id\}"').hasMatch(
            pilotRoutesSrc),
        isTrue,
        reason: 'PATCH /pilot/entities/{entity_id} must be registered',
      );
    });
  });

  group('G-ENTITY-SELLER-INFO — Frontend api_service', () {
    test('test_api_service_exposes_pilotGetEntity', () {
      expect(
        RegExp(r'pilotGetEntity\s*\(\s*String\s+entityId\s*\)').hasMatch(
            apiServiceSrc),
        isTrue,
        reason: 'api_service must declare pilotGetEntity(String entityId)',
      );
      // Hits the right URL (pilot_routes mounts at /pilot, no /api/v1).
      expect(
        apiServiceSrc.contains("/pilot/entities/\$entityId'"),
        isTrue,
        reason: 'pilotGetEntity must hit /pilot/entities/\$entityId',
      );
    });

    test('test_api_service_exposes_pilotUpdateEntitySellerInfo', () {
      expect(
        RegExp(r'pilotUpdateEntitySellerInfo\s*\(').hasMatch(apiServiceSrc),
        isTrue,
        reason:
            'api_service must declare pilotUpdateEntitySellerInfo for the '
            'settings UI / batch update',
      );
      // Must PATCH (not POST/PUT) since EntityUpdate is partial.
      expect(
        RegExp(r'pilotUpdateEntitySellerInfo[\s\S]{0,400}_patch\(').hasMatch(
            apiServiceSrc),
        isTrue,
        reason: 'pilotUpdateEntitySellerInfo must use _patch (partial update)',
      );
    });
  });

  group('G-ENTITY-SELLER-INFO — Session cache', () {
    test('test_session_exposes_savedSellerVatNumber_getter', () {
      expect(
        RegExp(r'static\s+String\?\s+get\s+savedSellerVatNumber').hasMatch(
            sessionSrc),
        isTrue,
        reason: 'S.savedSellerVatNumber getter must exist',
      );
      // Backed by localStorage so a refresh persists the value.
      expect(
        sessionSrc.contains("'pilot.seller_vat'"),
        isTrue,
        reason: 'savedSellerVatNumber must back to pilot.seller_vat in storage',
      );
    });

    test('test_session_exposes_savedSellerNameAr_getter', () {
      expect(
        RegExp(r'static\s+String\?\s+get\s+savedSellerNameAr').hasMatch(
            sessionSrc),
        isTrue,
        reason: 'S.savedSellerNameAr getter must exist',
      );
      expect(
        sessionSrc.contains("'pilot.seller_name_ar'"),
        isTrue,
        reason: 'savedSellerNameAr must back to pilot.seller_name_ar',
      );
    });

    test('test_session_declares_fetchEntitySellerInfo_helper', () {
      // The async helper the POS + sales-details screens fire-and-forget
      // in initState. Must call pilotGetEntity (not some other endpoint)
      // and persist the three fields.
      expect(
        RegExp(r'static\s+Future<void>\s+fetchEntitySellerInfo\s*\(').hasMatch(
            sessionSrc),
        isTrue,
        reason: 'S.fetchEntitySellerInfo must exist',
      );
      expect(
        sessionSrc.contains('ApiService.pilotGetEntity('),
        isTrue,
        reason: 'fetchEntitySellerInfo must call ApiService.pilotGetEntity',
      );
    });

    test('test_session_clear_wipes_seller_info_keys', () {
      // Critical: without this, the next user logging in on the same
      // browser inherits the previous tenant's ZATCA identity (the
      // exact bug G-LEGACY-KEY-AUDIT pinned for tenant/entity IDs).
      final clearBlock = RegExp(
        r'static\s+void\s+clear\(\)\s*\{[\s\S]*?\}',
      ).firstMatch(sessionSrc);
      expect(clearBlock, isNotNull, reason: 'S.clear() must exist');
      final body = clearBlock!.group(0)!;
      expect(body.contains("'pilot.seller_vat'"), isTrue);
      expect(body.contains("'pilot.seller_name_ar'"), isTrue);
    });
  });

  group('G-ENTITY-SELLER-INFO — POS receipt reads from cache', () {
    test('test_pos_receipt_reads_savedSellerVatNumber_not_literal', () {
      // The hardcoded VAT must no longer appear as a bare value — it
      // may still appear as a fallback after `??`. Pin both shapes.
      expect(
        posSrc.contains('S.savedSellerVatNumber'),
        isTrue,
        reason: 'POS receipt must read S.savedSellerVatNumber',
      );
      // Confirm we did NOT leave a bare assignment like:
      //   'seller_vat_number': '300000000000003'
      // (matching `?? '300000000000003'` is fine — placeholder fallback).
      expect(
        RegExp(r"'seller_vat_number'\s*:\s*'300000000000003'").hasMatch(posSrc),
        isFalse,
        reason: 'POS must not hardcode 300000000000003 as the primary value',
      );
    });

    test('test_pos_receipt_reads_savedSellerNameAr_not_literal', () {
      expect(
        posSrc.contains('S.savedSellerNameAr'),
        isTrue,
        reason: 'POS receipt must read S.savedSellerNameAr',
      );
      expect(
        RegExp(r"'seller_name'\s*:\s*'APEX'").hasMatch(posSrc),
        isFalse,
        reason: "POS must not hardcode 'APEX' as the primary value",
      );
    });

    test('test_pos_initState_triggers_fetchEntitySellerInfo', () {
      // Fire-and-forget refresh — the cashier opening POS shouldn't
      // wait for the network, but the next sale picks up real values.
      final initStateBlock = RegExp(
        r'void\s+initState\(\)\s*\{[\s\S]*?\}',
      ).firstMatch(posSrc);
      expect(initStateBlock, isNotNull,
          reason: 'POS must declare initState() to trigger the fetch');
      expect(
        initStateBlock!.group(0)!.contains('S.fetchEntitySellerInfo'),
        isTrue,
        reason: 'POS initState must call S.fetchEntitySellerInfo()',
      );
    });
  });

  group('G-ENTITY-SELLER-INFO — Sales details QR reads from cache', () {
    test('test_sales_details_reads_seller_identity_from_session', () {
      // Both fields read from the session cache with placeholder
      // fallback. Pin the pattern so a future refactor doesn't drop
      // the cache lookup and re-introduce the hardcoded bug.
      expect(
        salesDetailsSrc.contains('S.savedSellerNameAr'),
        isTrue,
        reason: 'Sales QR must read S.savedSellerNameAr',
      );
      expect(
        salesDetailsSrc.contains('S.savedSellerVatNumber'),
        isTrue,
        reason: 'Sales QR must read S.savedSellerVatNumber',
      );
      // The bare 'APEX UAT' literal should no longer be the primary
      // sellerName argument — only the fallback after `??`.
      expect(
        RegExp(r"sellerName:\s*'APEX UAT'").hasMatch(salesDetailsSrc),
        isFalse,
        reason: "Sales QR must not pass 'APEX UAT' as the primary sellerName",
      );
    });

    test('test_sales_details_initState_triggers_fetchEntitySellerInfo', () {
      // The QR renders only after issuance — by then the fetch fired
      // in initState should have populated the cache.
      final initStateBlock = RegExp(
        r'void\s+initState\(\)\s*\{[\s\S]*?\}',
      ).firstMatch(salesDetailsSrc);
      expect(initStateBlock, isNotNull);
      expect(
        initStateBlock!.group(0)!.contains('S.fetchEntitySellerInfo'),
        isTrue,
        reason: 'Sales details initState must call S.fetchEntitySellerInfo()',
      );
    });
  });
}
