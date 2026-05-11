/// G-POS-SESSION-HARDENING — source-grep regression tests for the
/// three hardening fixes carried forward from the 4-tester Finance
/// Module final audit:
///
///   * Fix #1: `POST /pilot/pos-transactions` now enforces
///     `payload.cashier_user_id == session.opened_by_user_id` (was
///     silently accepted — Z-Report attribution bug).
///   * Fix #2: new alembic migration `l5b8c1f4a3e7` adds a partial
///     unique index on `pilot_pos_sessions(branch_id) WHERE
///     status='open'` to close the list-then-create race in
///     `_ensureOpenSession` at the DB layer.
///   * Fix #3: duplicate `/onboarding/wizard` GoRoute registration
///     in `lib/core/router.dart` was removed (go-router only matches
///     the first registration; the second was dead code).
///
/// Source-grep contracts (read files as strings + assert
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
  late String posRoutesSrc;
  late String migrationSrc;
  late String routerSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    // flutter_test runs from `apex_finance/`. The backend files live
    // outside the dart package, so we walk up two levels.
    posRoutesSrc = read('../app/pilot/routes/pos_routes.py');
    migrationSrc =
        read('../alembic/versions/l5b8c1f4a3e7_pos_session_open_unique.py');
    routerSrc = read('lib/core/router.dart');
  });

  group('G-POS-SESSION-HARDENING — fix #1 (cashier == session owner)', () {
    test('test_create_transaction_has_cashier_vs_session_check', () {
      // The new guard is anchored on the comparison between the
      // payload field and the session-owner field. RegExp matches
      // either ordering of the operands so a future stylistic
      // refactor doesn't false-fail the test.
      final hasCheck = RegExp(
        r'payload\.cashier_user_id\s*!=\s*session\.opened_by_user_id',
      ).hasMatch(posRoutesSrc);
      final hasCheckReversed = RegExp(
        r'session\.opened_by_user_id\s*!=\s*payload\.cashier_user_id',
      ).hasMatch(posRoutesSrc);
      expect(
        hasCheck || hasCheckReversed,
        isTrue,
        reason:
            'create_transaction must compare payload.cashier_user_id against session.opened_by_user_id',
      );
    });

    test('test_cashier_mismatch_raises_403_not_400_or_409', () {
      // Z-Report attribution is an authorization concern, not a
      // validation or a state-conflict concern — so 403 is the
      // correct HTTP code. RegExp ties the 403 to the cashier-vs-
      // session block to defend against a stray 403 elsewhere in
      // the file passing this assertion accidentally.
      final pattern = RegExp(
        r'payload\.cashier_user_id\s*!=\s*session\.opened_by_user_id[\s\S]{0,200}?HTTPException\(\s*403',
      );
      expect(
        pattern.hasMatch(posRoutesSrc),
        isTrue,
        reason:
            'cashier-vs-session mismatch must raise HTTPException(403), not 400/409',
      );
    });

    test('test_create_transaction_check_lives_after_open_session_lookup', () {
      // Defense-in-depth: the cashier check needs the session row,
      // so it MUST come after `_open_session_or_409`. If the check
      // were re-ordered before the session lookup, `session` would
      // be undefined.
      final pattern = RegExp(
        r'_open_session_or_409\([\s\S]{0,400}?payload\.cashier_user_id\s*!=\s*session\.opened_by_user_id',
      );
      expect(
        pattern.hasMatch(posRoutesSrc),
        isTrue,
        reason:
            'cashier-vs-session check must come after _open_session_or_409 (needs the session row)',
      );
    });
  });

  group('G-POS-SESSION-HARDENING — fix #2 (partial unique index)', () {
    test('test_migration_file_exists_with_correct_revision_chain', () {
      // Revision id pins the filename → revision wiring. down_revision
      // ties to the immediately-prior k9a1b3d5e7f2 POS migration so
      // alembic's linear-history check passes.
      expect(
        RegExp(r'''revision\s*:\s*str\s*=\s*["']l5b8c1f4a3e7["']''')
            .hasMatch(migrationSrc),
        isTrue,
        reason: 'migration must declare revision = "l5b8c1f4a3e7"',
      );
      expect(
        RegExp(r'''down_revision[^=]*=\s*["']k9a1b3d5e7f2["']''')
            .hasMatch(migrationSrc),
        isTrue,
        reason: 'migration must chain off down_revision = "k9a1b3d5e7f2"',
      );
    });

    test('test_migration_uses_partial_index_postgres_and_sqlite', () {
      // The two `*_where=` kwargs are how alembic emits the
      // `WHERE status = 'open'` clause for both dialects. Without
      // both, one of the two dialects would get a full unique
      // index (incorrectly blocking ALL same-branch sessions).
      expect(
        migrationSrc.contains('postgresql_where='),
        isTrue,
        reason: 'migration must use postgresql_where for the partial index',
      );
      expect(
        migrationSrc.contains('sqlite_where='),
        isTrue,
        reason: 'migration must use sqlite_where for the partial index',
      );
      // Pin the predicate value so a typo (e.g. 'OPEN' vs 'open')
      // doesn't silently produce a never-matching partial index.
      expect(
        RegExp(r'''status\s*=\s*['"]open['"]''').hasMatch(migrationSrc),
        isTrue,
        reason:
            "partial-index predicate must be status = 'open' (lower-case literal)",
      );
    });

    test('test_migration_is_idempotent_via_try_except', () {
      // Bootstrap path: a fresh DB created via `create_all() →
      // alembic-stamp` may already have the index. Re-running the
      // migration must not crash on a duplicate-index error. The
      // sibling k9a1 migration uses the same pattern.
      final upgradeTryExcept = RegExp(
        r'def\s+upgrade\(\)[\s\S]{0,500}?try:[\s\S]{0,400}?except\s+Exception',
      );
      expect(
        upgradeTryExcept.hasMatch(migrationSrc),
        isTrue,
        reason: 'upgrade() must wrap create_index in try/except for idempotency',
      );
      final downgradeTryExcept = RegExp(
        r'def\s+downgrade\(\)[\s\S]{0,500}?try:[\s\S]{0,400}?except\s+Exception',
      );
      expect(
        downgradeTryExcept.hasMatch(migrationSrc),
        isTrue,
        reason: 'downgrade() must wrap drop_index in try/except for idempotency',
      );
    });

    test('test_migration_targets_correct_table_and_column', () {
      // Pin the table name + column. The race is per-branch (not
      // per-tenant), so the index must key on branch_id specifically.
      expect(
        migrationSrc.contains('pilot_pos_sessions'),
        isTrue,
        reason: 'index must target the pilot_pos_sessions table',
      );
      expect(
        RegExp(r'''\[\s*['"]branch_id['"]\s*\]''').hasMatch(migrationSrc),
        isTrue,
        reason: 'index must key on the branch_id column',
      );
      expect(
        migrationSrc.contains('unique=True'),
        isTrue,
        reason: 'index must be declared unique=True',
      );
    });
  });

  group('G-POS-SESSION-HARDENING — fix #3 (router dedup)', () {
    test('test_onboarding_wizard_route_registered_exactly_once', () {
      // go-router uses first-match semantics, so two GoRoute(path:
      // '/onboarding/wizard', ...) registrations means the second
      // is unreachable dead code. Source-grep on the literal path
      // assignment to avoid false-positives from comments / strings.
      final matches = RegExp(
        r'''path\s*:\s*['"]/onboarding/wizard['"]''',
      ).allMatches(routerSrc);
      expect(
        matches.length,
        equals(1),
        reason:
            "/onboarding/wizard must be registered exactly once in router.dart (was 2; second was dead code)",
      );
    });
  });

  group('G-POS-SESSION-HARDENING — sanity (pre-existing POS tests intact)', () {
    test('test_pre_existing_pos_v2_hotfix_test_still_present', () {
      // The audit relied on a clean 242+ screen-test suite. Pin
      // the most-relevant pre-existing POS test file as a smoke
      // marker so a future merge that accidentally deletes it
      // fails this contract first.
      final f = File('test/screens/pos_v2_hotfix_test.dart');
      expect(
        f.existsSync(),
        isTrue,
        reason:
            'pos_v2_hotfix_test.dart must continue to exist alongside the new hardening test',
      );
    });
  });
}
