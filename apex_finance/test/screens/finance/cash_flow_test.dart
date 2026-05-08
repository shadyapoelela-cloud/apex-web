/// G-FIN-CF-1 — wiring + plumbing tests for the Cash Flow surface.
///
/// Same pattern as IS-1/BS-1:
///   1. v5_data declares the chip with the right labels.
///   2. v5_wired_screens registers the key as wired.
///   3. The validator marks the chip as reachable.
///   4. The screen file contains no mock/hardcoded markers (source-grep
///      after stripping doc comments).
///   5. ApiService accepts the new method + comparePeriod + includeZero
///      kwargs.
///   6. The reconciliation banner renders BEFORE the summary cards
///      and statement table — an integrity issue buried below the
///      table is easy to miss.
///   7. The screen exposes an unmapped-subcategories warning when
///      the response carries them — pinned via source-grep on the
///      `_buildUnmappedWarning` method.
///
/// Why no widget-driven tests
/// --------------------------
/// `CashFlowScreen` imports `session.dart → dart:html`, which pulls
/// `package:web` 1.1.1 — the same SDK mismatch (G-T1.1) that blocks
/// `ask_panel_test.dart` from loading on the Dart VM. Until G-T1.1 is
/// closed, deep widget tests of the screen run out of band against
/// the deployed app.
library;

import 'dart:io';

import 'package:apex_finance/core/v5/v5_data.dart';
import 'package:apex_finance/core/v5/v5_wired_keys.dart';
import 'package:apex_finance/core/v5/v5_routing_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CF chip declaration', () {
    test(
      'v5_data finance main has a chip with id cash-flow',
      () {
        final svc = v5ServiceById('erp');
        expect(svc, isNotNull, reason: 'erp service must exist');
        final main = svc!.mainModuleById('finance');
        expect(main, isNotNull, reason: 'erp/finance must exist');
        final chip = main!.chipById('cash-flow');
        expect(
          chip,
          isNotNull,
          reason:
              'V5Chip(id: "cash-flow") must be declared in v5_data '
              'finance main module so the parametric chip route + '
              'validator both resolve it.',
        );
        expect(chip!.labelAr, 'قائمة التدفقات النقدية');
        expect(chip.labelEn, 'Cash Flow');
      },
    );
  });

  group('CF wired-screens registration', () {
    test(
      'erp/finance/cash-flow is in v5WiredKeys',
      () {
        expect(
          v5WiredKeys.contains('erp/finance/cash-flow'),
          isTrue,
          reason:
              'wired-keys generator must have re-run after the new '
              'CashFlowScreen import was added',
        );
      },
    );

    test(
      'chip reachability for erp/finance/cash-flow is wired',
      () {
        final all = validateAllChips();
        final hit = all.firstWhere(
          (s) => s.key == 'erp/finance/cash-flow',
          orElse: () => throw StateError(
            'no validator entry for erp/finance/cash-flow — chip '
            'must be declared in v5_data first',
          ),
        );
        expect(
          hit.wired,
          isTrue,
          reason:
              'wired flag must come from v5WiredScreens entry — the '
              'cash-flow route is in the Map directly post G-FIN-CF-1.',
        );
        expect(hit.isReachable, isTrue);
      },
    );
  });

  group('CF source — anti-mock + reconciliation contracts', () {
    /// 🔴 The non-negotiable: the CF screen MUST NOT contain any
    /// hardcoded / mock / placeholder values, AND must honor the
    /// `is_reconciled` flag from the backend without locally
    /// massaging it (the operator needs to see breaks to fix them).
    test(
      'cash_flow_screen.dart contains no mock/hardcoded markers',
      () {
        final f = File('lib/screens/finance/cash_flow_screen.dart');
        expect(
          f.existsSync(),
          isTrue,
          reason: 'screen file missing — was it deleted?',
        );
        final rawSrc = f.readAsStringSync();

        // Strip doc/line comments before scanning so the contract
        // block at the top doesn't trigger on its own forbidden-token
        // list.
        final code = rawSrc
            .split('\n')
            .where((line) {
              final trimmed = line.trim();
              if (trimmed.startsWith('///')) return false;
              if (trimmed.startsWith('//')) return false;
              return true;
            })
            .join('\n');

        // Tokens that would signal a regression in actual code.
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
          // CF-specific: silencing the reconciliation flag would
          // surface here.
          'forceReconciled',
          'overrideReconciled',
          'silentReconciliation',
        ];
        for (final tok in forbidden) {
          expect(
            code.toLowerCase().contains(tok.toLowerCase()),
            isFalse,
            reason:
                'cash_flow_screen.dart code (excluding doc comments) '
                'contains the forbidden marker "$tok" — the real-data + '
                'reconciliation guarantees from G-FIN-CF-1 forbid it.',
          );
        }

        // Both banners must remain in the screen — they are the only
        // on-screen indicators when reconciliation breaks or
        // unmapped subcategories are detected.
        expect(
          rawSrc.contains('_buildReconciliationBanner'),
          isTrue,
          reason:
              'CashFlowScreen must keep the _buildReconciliationBanner '
              'method — it is the only on-screen indicator that the '
              'opening_cash + net_change == closing_cash equation is '
              'broken.',
        );
        expect(
          rawSrc.contains('_buildUnmappedWarning'),
          isTrue,
          reason:
              'CashFlowScreen must keep the _buildUnmappedWarning '
              'method — it surfaces custom subcategories that fall '
              'outside the CF section map so admins can map them.',
        );
        expect(
          rawSrc.contains('Real-data guarantee'),
          isTrue,
          reason:
              'cash_flow_screen.dart must keep the "Real-data '
              'guarantee" doc-block at the top.',
        );
      },
    );

    test(
      'ApiService.pilotCashFlow accepts the new kwargs',
      () {
        final api = File('lib/api_service.dart');
        final apiSrc = api.readAsStringSync();
        expect(
          apiSrc.contains('pilotCashFlow'),
          isTrue,
          reason: 'ApiService.pilotCashFlow must exist',
        );
        expect(
          apiSrc.contains('method'),
          isTrue,
          reason:
              'ApiService.pilotCashFlow must accept the method '
              'parameter (G-FIN-CF-1 contract)',
        );
        expect(
          apiSrc.contains('comparePeriod'),
          isTrue,
          reason:
              'ApiService.pilotCashFlow must accept the comparePeriod '
              'parameter',
        );
        expect(
          apiSrc.contains('includeZero'),
          isTrue,
          reason:
              'ApiService.pilotCashFlow must accept the includeZero '
              'parameter',
        );
      },
    );

    test(
      'reconciliation banner renders before summary + table',
      () {
        // Belt-and-braces: assert the screen invokes
        // _buildReconciliationBanner() *before* _buildSummaryCards()
        // and _buildStatementTable() in build(). A reconciliation
        // failure buried below the table is easy to miss; this test
        // regression-proofs the visual contract.
        final f = File('lib/screens/finance/cash_flow_screen.dart');
        final src = f.readAsStringSync();
        final bannerIdx = src.indexOf('_buildReconciliationBanner()');
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
              'reconciliation banner must render BEFORE summary cards — '
              'a reconciliation-failure message buried below the table '
              'is easy to miss',
        );
        expect(
          bannerIdx < tableIdx,
          isTrue,
          reason:
              'reconciliation banner must render BEFORE the statement '
              'table',
        );
      },
    );

    test(
      'unmapped-subcategories warning is rendered when present',
      () {
        // The screen reads `unmapped_subcategories` from the response
        // and renders an orange warning bar via _buildUnmappedWarning.
        // Pin both: the data wiring (`_unmapped` getter) AND the
        // conditional render in build().
        final f = File('lib/screens/finance/cash_flow_screen.dart');
        final src = f.readAsStringSync();
        expect(
          src.contains("'unmapped_subcategories'"),
          isTrue,
          reason:
              'screen must read the unmapped_subcategories field from '
              'the response to surface custom-CoA warnings',
        );
        expect(
          src.contains('if (_unmapped.isNotEmpty)'),
          isTrue,
          reason:
              'build() must conditionally render the orange warning '
              'bar when unmapped_subcategories is non-empty',
        );
      },
    );
  });
}
