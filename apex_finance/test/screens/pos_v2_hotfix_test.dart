/// G-POS-V2-HOTFIX — source-grep regression tests for the 3
/// production-blocking bugs found by the tester on the V2 branch
/// (`feat/g-pos-backend-integration-v2`):
///
///   * Bug #1: POS session creation 422'd because the payload omitted
///     warehouse_id + opened_by_user_id (PosSessionOpen requires both).
///   * Bug #2: cashier_user_id was set to S.savedTenantId — leaking the
///     tenant id into the cashier audit field.
///   * Bug #3: _ensureCashCustomer minted a fresh `CASH-${timestamp}`
///     code per retry, creating duplicate cash-customer rows.
///
/// 7 contracts pinned. Source-grep (read files as strings + assert
/// substrings / RegExps) — same gate as the prior POS sprints because
/// pos_quick_sale_screen.dart transitively imports `dart:html` via
/// session.dart which fails the SDK gate under flutter_test (G-T1.1).
///
/// IMPORTANT (Windows CRLF safety): multi-line patterns MUST use
/// RegExp with character classes (e.g. `[\s\S]`), NOT literal `\n`,
/// because the source file may be checked out with either LF or CRLF
/// endings depending on git's autocrlf config.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String posSrc;
  late String apiSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    // flutter_test runs from `apex_finance/`.
    posSrc = read('lib/screens/operations/pos_quick_sale_screen.dart');
    apiSrc = read('lib/api_service.dart');
  });

  group('G-POS-V2-HOTFIX — bug #1 (session payload)', () {
    test('test_ensureOpenSession_payload_includes_warehouse_id', () {
      // PosSessionOpen schema (app/pilot/schemas/pos.py:14-23) declares
      // warehouse_id as a required str. Pre-hotfix the payload omitted
      // it, so the first cash sale of the day 422'd. RegExp scopes the
      // assertion to the create-session call body so we don't false-
      // positive on unrelated `warehouse_id` mentions in comments.
      expect(
        RegExp(
                r"pilotCreatePosSession\([\s\S]{0,400}?'warehouse_id'\s*:")
            .hasMatch(posSrc),
        isTrue,
        reason: "pilotCreatePosSession payload must include 'warehouse_id'",
      );
    });

    test('test_ensureOpenSession_payload_includes_opened_by_user_id', () {
      // The other required field on PosSessionOpen. Backend can't
      // default this from the JWT because the schema validates the
      // request body before any auth-aware code runs.
      expect(
        RegExp(
                r"pilotCreatePosSession\([\s\S]{0,400}?'opened_by_user_id'\s*:")
            .hasMatch(posSrc),
        isTrue,
        reason:
            "pilotCreatePosSession payload must include 'opened_by_user_id'",
      );
    });

    test('test_ensureOpenSession_resolves_warehouse_via_branch_endpoint', () {
      // The warehouse_id has to come from somewhere — we look it up
      // via the new pilotListBranchWarehouses helper. Pin that this
      // is the resolver (not, e.g., a hardcoded constant).
      expect(
        posSrc.contains('pilotListBranchWarehouses'),
        isTrue,
        reason:
            '_ensureOpenSession must resolve warehouse_id via pilotListBranchWarehouses',
      );
    });
  });

  group('G-POS-V2-HOTFIX — bug #2 (cashier_user_id)', () {
    test('test_submit_cashier_user_id_uses_S_uid_not_tenant_id', () {
      // Pin the corrected value: `'cashier_user_id': cashierUid` or
      // `: S.uid` — NOT the broken `S.savedTenantId ?? custId`.
      // RegExp anchors on the literal key so a future refactor that
      // moves the assignment around stays caught.
      expect(
        RegExp(r"'cashier_user_id'\s*:\s*cashierUid").hasMatch(posSrc) ||
            RegExp(r"'cashier_user_id'\s*:\s*S\.uid").hasMatch(posSrc),
        isTrue,
        reason:
            "cashier_user_id must be sourced from S.uid (via the local cashierUid binding)",
      );
      // The OLD broken expression must be gone — otherwise even if the
      // new line lands, a stray fallback could re-introduce the bug.
      expect(
        RegExp(r"'cashier_user_id'\s*:\s*S\.savedTenantId").hasMatch(posSrc),
        isFalse,
        reason:
            'cashier_user_id must NOT fall back to S.savedTenantId (that is the tenant id, not a user id)',
      );
    });

    test('test_submit_guards_on_S_uid_with_arabic_snackbar', () {
      // Pre-flight gate so the cashier sees ONE clear error instead
      // of two cryptic backend 4xx's back-to-back.
      expect(
        posSrc.contains('لا يوجد مستخدم مسجّل دخول'),
        isTrue,
        reason:
            '_submit must show the Arabic "no user logged in" snackbar when S.uid is null/empty',
      );
    });
  });

  group('G-POS-V2-HOTFIX — bug #3 (cash-customer dedup)', () {
    test('test_cash_customer_code_is_stable_CASH_DEFAULT_constant', () {
      // Pre-hotfix code was `CASH-${DateTime.now().millisecondsSinceEpoch}`
      // → fresh customer per retry. The fix uses a stable canonical
      // constant. Pin the constant name AND the literal value.
      expect(
        posSrc.contains('_kCashCustomerCode'),
        isTrue,
        reason: 'must declare a _kCashCustomerCode constant',
      );
      expect(
        RegExp(r"_kCashCustomerCode\s*=\s*'CASH-DEFAULT'").hasMatch(posSrc),
        isTrue,
        reason: '_kCashCustomerCode must equal the literal string CASH-DEFAULT',
      );
      // The OLD timestamp-based code generation must be gone.
      expect(
        posSrc.contains('CASH-\${DateTime.now().millisecondsSinceEpoch}'),
        isFalse,
        reason: 'timestamp-based code generation must be removed',
      );
    });

    test('test_cash_customer_409_retry_path_via_get_by_code', () {
      // Race-loser path: a concurrent cashier may have just created
      // the canonical row, in which case our POST returns 409 and we
      // need to retry the GET. Pin both the retry call (second
      // pilotGetCustomerByCode invocation) and the 409 sniff.
      expect(
        posSrc.contains('pilotGetCustomerByCode'),
        isTrue,
        reason:
            '_ensureCashCustomer must call pilotGetCustomerByCode (the GET-by-code helper)',
      );
      // 409 detection — we sniff the error string for the literal
      // "already exists" (customer_routes.py:268).
      expect(
        RegExp(r"already exists").hasMatch(posSrc),
        isTrue,
        reason:
            '_ensureCashCustomer must detect the 409 "already exists" path',
      );
      // The retry pattern itself: two distinct calls to the lookup
      // helper, separated by the POST create.
      final occurrences =
          RegExp(r'pilotGetCustomerByCode').allMatches(posSrc).length;
      expect(
        occurrences,
        greaterThanOrEqualTo(2),
        reason:
            'pilotGetCustomerByCode must be invoked at least twice (initial lookup + 409 retry)',
      );
    });
  });

  group('G-POS-V2-HOTFIX — api_service helpers', () {
    test('test_api_service_declares_pilotListBranchWarehouses', () {
      expect(
        apiSrc.contains('pilotListBranchWarehouses'),
        isTrue,
        reason: 'api_service must declare pilotListBranchWarehouses',
      );
      // Path must match the existing catalog_routes.py endpoint.
      expect(
        RegExp(r"pilotListBranchWarehouses[\s\S]{0,200}?'/pilot/branches/[^']+/warehouses'")
            .hasMatch(apiSrc),
        isTrue,
        reason:
            "pilotListBranchWarehouses must GET /pilot/branches/{branchId}/warehouses",
      );
    });

    test('test_api_service_declares_pilotGetCustomerByCode', () {
      expect(
        apiSrc.contains('pilotGetCustomerByCode'),
        isTrue,
        reason: 'api_service must declare pilotGetCustomerByCode',
      );
      // The implementation rides on customer_routes.py's `search=`
      // query parameter (ILIKE across code + name + vat); pin that
      // we're sending the search param, not inventing a new endpoint.
      expect(
        RegExp(r"pilotGetCustomerByCode[\s\S]{0,300}?search=")
            .hasMatch(apiSrc),
        isTrue,
        reason:
            'pilotGetCustomerByCode must reuse the existing /customers?search= query',
      );
    });
  });
}
