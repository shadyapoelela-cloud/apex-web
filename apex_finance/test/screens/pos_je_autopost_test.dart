/// G-FIN-POS-JE-AUTOPOST — source-grep regression tests for the
/// Sprint 7 PosDailyReportScreen.
///
/// Backend already auto-posts sales+COGS JEs on every completed POS
/// transaction (gl_engine.py auto_post_pos_sale). This sprint adds
/// the verification surface — a daily-report screen that shows the
/// Z-report breakdown alongside the list of auto-posted JEs.
///
/// 6 contracts pinned.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;
  late String wiredSrc;
  late String wiredKeysSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    src = read('lib/screens/operations/pos_daily_report_screen.dart');
    wiredSrc = read('lib/core/v5/v5_wired_screens.dart');
    wiredKeysSrc = read('lib/core/v5/v5_wired_keys.dart');
  });

  group('G-FIN-POS-JE-AUTOPOST — endpoints used', () {
    test('test_screen_calls_z_report_and_transactions', () {
      // The Z-report endpoint gives totals + payment breakdown; the
      // transactions list gives the per-receipt JE link. Both are
      // user-visible. Pin both calls so a refactor can't silently
      // drop one.
      expect(src.contains('pilotZReport'), isTrue,
          reason: 'must call /pilot/pos-sessions/{sid}/z-report');
      expect(src.contains('pilotListPosTransactions'), isTrue,
          reason: 'must call /pilot/pos-sessions/{sid}/transactions');
      expect(src.contains('pilotListPosSessions'), isTrue,
          reason: 'must list sessions for the active branch');
    });
  });

  group('G-FIN-POS-JE-AUTOPOST — UI ratchet', () {
    test('test_kpi_cards_cover_sales_vat_net_count_variance', () {
      // The 4 top-row KPIs are the "did the day work?" signal at a
      // glance. Pin each label so the user-visible promise survives.
      const required = [
        'إجمالي المبيعات',
        'إجمالي VAT',
        'صافي',
        'عدد الفواتير',
        'الكاش المتوقّع',
        'الكاش الفعلي',
        'الفرق',
      ];
      for (final label in required) {
        expect(src.contains(label), isTrue,
            reason: 'KPI label "$label" must remain on the screen');
      }
    });

    test('test_payment_breakdown_section_present', () {
      expect(src.contains('payment_breakdown'), isTrue,
          reason: 'must read payment_breakdown from Z-report response');
      expect(src.contains('توزيع طرق الدفع'), isTrue,
          reason: 'must surface a "توزيع طرق الدفع" section header');
    });

    test('test_transactions_list_surfaces_je_link', () {
      // The whole point of this screen is to verify the JE auto-post
      // landed. Each transaction row must show its JE id and link to
      // the JE list when clicked.
      expect(src.contains("t['journal_entry_id']"), isTrue,
          reason:
              'transactions must surface their journal_entry_id from the txn payload');
      expect(src.contains("'/app/erp/finance/je-builder'"), isTrue,
          reason: 'JE-link button must navigate to the JE list');
      // Section header for the transactions block must mention "قيود يومية"
      // so the user sees this is the verification surface, not just a
      // raw transaction log.
      expect(src.contains('قيود يومية'), isTrue,
          reason:
              'transactions section header must mention قيود يومية تلقائية');
    });
  });

  group('G-FIN-POS-JE-AUTOPOST — wiring', () {
    test('test_chip_pos_report_wired', () {
      // The chip is reachable via the V5 chip catalog. If a future
      // refactor drops the chip mapping or the key-set entry, this
      // test fires before the routing-validator broader chip-count
      // test does.
      expect(wiredSrc.contains("'erp/finance/pos-report'"), isTrue,
          reason: 'chip key must be wired in v5_wired_screens.dart');
      expect(wiredSrc.contains('PosDailyReportScreen()'), isTrue,
          reason: 'chip must build PosDailyReportScreen');
      expect(wiredKeysSrc.contains("'erp/finance/pos-report'"), isTrue,
          reason: 'chip key must be in v5_wired_keys.dart inventory');
    });
  });
}
