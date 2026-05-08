/// G-FIN-IS-1 — wiring + plumbing tests for the Income Statement
/// (P&L) surface.
///
/// Mirrors the structure of `trial_balance_test.dart` — same four
/// pieces have to line up between data, routing, and the wired-
/// screens map; widget tests of the screen itself can't run on the
/// Dart VM because the screen imports `session.dart → dart:html`
/// (the G-T1.1 `package:web` SDK mismatch).
///
/// Plus one source-grep test that pins the real-data guarantee:
/// the screen file MUST NOT contain any tokens that would indicate
/// mock / hardcoded / placeholder state.
library;

import 'dart:io';

import 'package:apex_finance/core/v5/v5_data.dart';
import 'package:apex_finance/core/v5/v5_wired_keys.dart';
import 'package:apex_finance/core/v5/v5_routing_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IS chip declaration', () {
    test(
      'v5_data finance main has a chip with id income-statement',
      () {
        final svc = v5ServiceById('erp');
        expect(svc, isNotNull, reason: 'erp service must exist');
        final main = svc!.mainModuleById('finance');
        expect(main, isNotNull, reason: 'erp/finance must exist');
        final chip = main!.chipById('income-statement');
        expect(
          chip,
          isNotNull,
          reason:
              'V5Chip(id: "income-statement") must be declared in '
              'v5_data finance main module — without it the validator '
              'fails the broken-pin baseline.',
        );
        expect(chip!.labelAr, 'قائمة الدخل');
        expect(chip.labelEn, 'Income Statement');
      },
    );
  });

  group('IS wired-screens registration', () {
    test(
      'erp/finance/income-statement is in v5WiredKeys',
      () {
        expect(
          v5WiredKeys.contains('erp/finance/income-statement'),
          isTrue,
          reason:
              'wired-keys generator must have re-run after the new '
              'IncomeStatementScreen import was added',
        );
      },
    );

    test(
      'chip reachability for erp/finance/income-statement is wired',
      () {
        final all = validateAllChips();
        final hit = all.firstWhere(
          (s) => s.key == 'erp/finance/income-statement',
          orElse: () => throw StateError(
            'no validator entry for erp/finance/income-statement — '
            'chip must be declared in v5_data first',
          ),
        );
        expect(
          hit.wired,
          isTrue,
          reason:
              'wired flag must come from v5WiredScreens entry — the '
              'income-statement route is in the Map directly post '
              'G-FIN-IS-1.',
        );
        expect(hit.isReachable, isTrue);
      },
    );
  });

  group('IS source — anti-mock guarantee', () {
    /// 🔴 The non-negotiable: the IS screen MUST NOT contain any
    /// hardcoded / mock / placeholder values. Real data is the only
    /// data; the empty-period state is genuinely empty (CTA → JE
    /// Builder, never seeded rows). This test source-greps the
    /// screen for tokens a regression would introduce.
    test(
      'income_statement_screen.dart contains no mock/hardcoded markers',
      () {
        final f = File('lib/screens/finance/income_statement_screen.dart');
        expect(
          f.existsSync(),
          isTrue,
          reason: 'screen file missing — was it deleted?',
        );
        final rawSrc = f.readAsStringSync();

        // The doc-block at the top legitimately contains the words
        // "mock", "fake", "hardcoded" — it's literally the contract
        // forbidding them. We need to strip doc comments + line
        // comments before scanning so the test doesn't trigger on
        // its own warning.
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
        //   * `mockData` / `fakeData` / `stubData` — explicit mock
        //     infrastructure
        //   * `hardcoded` — a developer note marking a temporary value
        //   * `_demoRows` / `_seedRows` / `_defaultRows` — common
        //     names for pre-populated state
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
        ];
        for (final tok in forbidden) {
          expect(
            code.toLowerCase().contains(tok.toLowerCase()),
            isFalse,
            reason:
                'income_statement_screen.dart code (excluding doc '
                'comments) contains the forbidden marker "$tok" — '
                'the real-data guarantee from G-FIN-IS-1 forbids it.',
          );
        }

        // Belt-and-braces: assert the doc-block at the top mentions
        // the guarantee so a future contributor can't quietly drop it.
        expect(
          rawSrc.contains('Real-data guarantee'),
          isTrue,
          reason:
              'income_statement_screen.dart must keep the '
              '"Real-data guarantee" doc-block at the top — that '
              'block is the human contract pinned by this test.',
        );

        // And make sure the API method exists in api_service.dart
        // and accepts the new params we wire here.
        final api = File('lib/api_service.dart');
        final apiSrc = api.readAsStringSync();
        expect(
          apiSrc.contains('pilotIncomeStatement'),
          isTrue,
          reason: 'ApiService.pilotIncomeStatement must exist',
        );
        expect(
          apiSrc.contains('comparePeriod'),
          isTrue,
          reason:
              'ApiService.pilotIncomeStatement must accept the '
              'comparePeriod parameter (G-FIN-IS-1 contract)',
        );
        expect(
          apiSrc.contains('includeZero'),
          isTrue,
          reason:
              'ApiService.pilotIncomeStatement must accept the '
              'includeZero parameter (G-FIN-IS-1 contract)',
        );
      },
    );
  });
}
