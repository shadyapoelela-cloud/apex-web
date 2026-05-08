/// G-FIN-BS-1 — wiring + plumbing tests for the Balance Sheet
/// surface.
///
/// Same pattern as `income_statement_test.dart`:
///   1. v5_data declares the chip with the right labels.
///   2. v5_wired_screens registers the key as wired.
///   3. The validator marks the chip as reachable.
///   4. The screen file contains no mock/hardcoded markers (source-grep
///      after stripping doc comments).
///   5. ApiService accepts the new compareAsOf + includeZero kwargs.
///   6. The unbalanced-banner contract is documented in the screen
///      source so a regression that silently bypasses the equation
///      would be visible to a code reviewer.
///
/// Why no widget-driven tests
/// --------------------------
/// `BalanceSheetScreen` imports `session.dart → dart:html`, which
/// pulls `package:web` 1.1.1 — the same SDK mismatch (G-T1.1) that
/// blocks `ask_panel_test.dart` from loading on the Dart VM. Until
/// G-T1.1 is closed, deep widget tests of the screen run out of
/// band against the deployed app.
library;

import 'dart:io';

import 'package:apex_finance/core/v5/v5_data.dart';
import 'package:apex_finance/core/v5/v5_wired_keys.dart';
import 'package:apex_finance/core/v5/v5_routing_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BS chip declaration', () {
    test(
      'v5_data finance main has a chip with id balance-sheet',
      () {
        final svc = v5ServiceById('erp');
        expect(svc, isNotNull, reason: 'erp service must exist');
        final main = svc!.mainModuleById('finance');
        expect(main, isNotNull, reason: 'erp/finance must exist');
        final chip = main!.chipById('balance-sheet');
        expect(
          chip,
          isNotNull,
          reason:
              'V5Chip(id: "balance-sheet") must be declared in '
              'v5_data finance main module so the parametric chip '
              'route + validator both resolve it.',
        );
        expect(chip!.labelAr, 'الميزانية العمومية');
        expect(chip.labelEn, 'Balance Sheet');
      },
    );
  });

  group('BS wired-screens registration', () {
    test(
      'erp/finance/balance-sheet is in v5WiredKeys',
      () {
        expect(
          v5WiredKeys.contains('erp/finance/balance-sheet'),
          isTrue,
          reason:
              'wired-keys generator must have re-run after the new '
              'BalanceSheetScreen import was added',
        );
      },
    );

    test(
      'chip reachability for erp/finance/balance-sheet is wired',
      () {
        final all = validateAllChips();
        final hit = all.firstWhere(
          (s) => s.key == 'erp/finance/balance-sheet',
          orElse: () => throw StateError(
            'no validator entry for erp/finance/balance-sheet — '
            'chip must be declared in v5_data first',
          ),
        );
        expect(
          hit.wired,
          isTrue,
          reason:
              'wired flag must come from v5WiredScreens entry — the '
              'balance-sheet route is in the Map directly post '
              'G-FIN-BS-1.',
        );
        expect(hit.isReachable, isTrue);
      },
    );
  });

  group('BS source — anti-mock + balance-equation contracts', () {
    /// 🔴 The non-negotiable: the BS screen MUST NOT contain any
    /// hardcoded / mock / placeholder values, AND the screen must
    /// honor `is_balanced` from the backend without locally massaging
    /// it (the operator needs to see imbalances to fix them).
    test(
      'balance_sheet_screen.dart contains no mock/hardcoded markers',
      () {
        final f = File('lib/screens/finance/balance_sheet_screen.dart');
        expect(
          f.existsSync(),
          isTrue,
          reason: 'screen file missing — was it deleted?',
        );
        final rawSrc = f.readAsStringSync();

        // Strip doc comments + line comments before scanning so the
        // contract block at the top doesn't trigger on its own
        // forbidden-token list.
        final code = rawSrc
            .split('\n')
            .where((line) {
              final trimmed = line.trim();
              if (trimmed.startsWith('///')) return false;
              if (trimmed.startsWith('//')) return false;
              return true;
            })
            .join('\n');

        // Tokens that would signal a regression in actual code:
        final forbidden = <String>[
          'mockData',
          'mockRows',
          'fakeData',
          'fakeRows',
          'stubData',
          'hardcoded',
          '_demoRows',
          '_seedRows',
          '_defaultRows',
          'placeholderAmount',
          // BS-specific: a dev silencing the imbalance to avoid the
          // red banner would surface here.
          'forceBalanced',
          'overrideBalanced',
        ];
        for (final tok in forbidden) {
          expect(
            code.toLowerCase().contains(tok.toLowerCase()),
            isFalse,
            reason:
                'balance_sheet_screen.dart code (excluding doc '
                'comments) contains the forbidden marker "$tok" — '
                'the real-data + balance-equation guarantees from '
                'G-FIN-BS-1 forbid it.',
          );
        }

        // The banner must remain in the screen — that's the visual
        // guarantee the operator gets when an imbalance happens.
        expect(
          rawSrc.contains('_buildBalanceBanner'),
          isTrue,
          reason:
              'BalanceSheetScreen must keep the _buildBalanceBanner '
              'method — it is the only on-screen indicator that the '
              'accounting equation is broken.',
        );
        expect(
          rawSrc.contains('Real-data guarantee'),
          isTrue,
          reason:
              'balance_sheet_screen.dart must keep the '
              '"Real-data guarantee" doc-block at the top.',
        );
      },
    );

    test(
      'ApiService.pilotBalanceSheet accepts the new kwargs',
      () {
        final api = File('lib/api_service.dart');
        final apiSrc = api.readAsStringSync();
        expect(
          apiSrc.contains('pilotBalanceSheet'),
          isTrue,
          reason: 'ApiService.pilotBalanceSheet must exist',
        );
        expect(
          apiSrc.contains('compareAsOf'),
          isTrue,
          reason:
              'ApiService.pilotBalanceSheet must accept the '
              'compareAsOf parameter (G-FIN-BS-1 contract)',
        );
        expect(
          apiSrc.contains('includeZero'),
          isTrue,
          reason:
              'ApiService.pilotBalanceSheet must accept the '
              'includeZero parameter (G-FIN-BS-1 contract)',
        );
      },
    );

    test(
      'unbalanced response triggers a visible warning in the screen',
      () {
        // Belt-and-braces — assert the screen calls _buildBalanceBanner
        // *before* the table builds. That's the visual contract: even
        // if the rows render correctly, the operator sees the red
        // strip first if the equation breaks.
        final f = File('lib/screens/finance/balance_sheet_screen.dart');
        final src = f.readAsStringSync();
        final bannerIdx = src.indexOf('_buildBalanceBanner()');
        final summaryIdx = src.indexOf('_buildSummaryCards()');
        final tableIdx = src.indexOf('_buildStatementTable()');
        expect(bannerIdx, greaterThan(0),
            reason: 'banner must be invoked in build()');
        expect(summaryIdx, greaterThan(0));
        expect(tableIdx, greaterThan(0));
        expect(
          bannerIdx < summaryIdx,
          isTrue,
          reason:
              'balance banner must render BEFORE summary cards — '
              'an imbalance message buried below the table is easy '
              'to miss',
        );
        expect(
          bannerIdx < tableIdx,
          isTrue,
          reason: 'balance banner must render BEFORE the statement table',
        );
      },
    );
  });
}
