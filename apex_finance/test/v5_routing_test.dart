/// V5 routing validation tests (HOTFIX-Routing Sprint 16, 2026-05-06).
///
/// Three guard tests, each tied to a specific failure mode caught in
/// `UAT_FORENSIC_FULL_2026-05-06.md`:
///
///   1. The number of broken Quick Access pins never grows above the
///      current baseline (post-HOTFIX of BUG-1..4 + 1 known pre-existing
///      bug — see PR description).
///   2. No pin uses the `/app/erp/app/erp/...` double-prefix pattern
///      (BUG-3 + BUG-4 of the audit).
///   3. The number of unreachable chips never grows above the current
///      baseline — chips can only get more wired over time.
library;

import 'package:apex_finance/core/v5/v5_routing_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V5 Quick Access pin validation', () {
    test('broken pins count stays within baseline', () {
      // HOTFIX-Routing repaired BUG-1..4 from UAT_FORENSIC_FULL_2026-05-06.md
      // and surfaced a 5th pre-existing bug (pin `vat` → wrong main
      // module). G-CHIPS-WIRE-FIN-1 (this PR) fixed pin `vat` by
      // routing it at the canonical `vat-return` chip in finance —
      // dropping the broken-pin baseline from 1 to 0.
      //
      // This number must only DECREASE over time. Lower the baseline
      // when fixing a pin to ratchet the gate tighter.
      const allowedBrokenPins = 0;
      final errors = validatePins();
      expect(errors.length, lessThanOrEqualTo(allowedBrokenPins),
          reason:
              'Broken pin count grew above baseline ($allowedBrokenPins). '
              'A pin route regression has been introduced.\n'
              'Errors:\n${errors.map((e) => '  - $e').join('\n')}');
    });

    test('no pin uses the double /app/erp/ prefix pattern', () {
      final errors = validatePins();
      final doublePrefixErrors =
          errors.where((e) => e.reason.contains('double')).toList();
      expect(doublePrefixErrors, isEmpty,
          reason: 'Pins must use /app/{service}/{main}/{chip} shape');
    });
  });

  group('V5 chip reachability inventory', () {
    test('chip vat-return is wired (G-CHIPS-WIRE-FIN-1 ratchet)', () {
      // Pin `vat` depends on this chip remaining wired. If the pin
      // route changes, OR the chip wiring is removed, this test catches
      // it before the validator's broader chip-count test does.
      final all = validateAllChips();
      final vat =
          all.firstWhere((s) => s.key == 'erp/finance/vat-return');
      expect(vat.isReachable, isTrue,
          reason:
              'vat-return must remain wired — pin vat depends on it');
    });

    // G-FIN-AUDIT-CLEANUP (Sprint 1, 2026-05-09):
    // The five financial-statement chips (`gl`, `trial-balance`,
    // `income-statement`, `balance-sheet`, `cash-flow`) were unified
    // on 2026-05-08 to point at dedicated screens. This test pins
    // them so a future refactor can't silently re-collapse them back
    // into the FinancialReportsScreen hub. See
    // docs/FINANCE_MODULE_AUDIT_2026-05-09.md Table 2 Group A.
    test('financial-statement chips remain wired (G-FIN-AUDIT pin)', () {
      final all = validateAllChips();
      const required = [
        'erp/finance/gl',
        'erp/finance/trial-balance',
        'erp/finance/income-statement',
        'erp/finance/balance-sheet',
        'erp/finance/cash-flow',
        'erp/finance/statements',
      ];
      for (final key in required) {
        final chip = all.firstWhere(
          (s) => s.key == key,
          orElse: () => throw Exception('chip $key not found in inventory'),
        );
        expect(chip.isReachable, isTrue,
            reason: '$key must stay wired — financial-statement '
                'audit pin (G-FIN-AUDIT-CLEANUP, Sprint 1).');
      }
    });

    test('reports broken chips count within baseline', () {
      final all = validateAllChips();
      final unreachable = all.where((s) => !s.isReachable).toList();

      // HOTFIX-Routing established the baseline at 56. G-CHIPS-WIRE-FIN-1
      // (this PR) wired 12 finance chips — 10 of them previously
      // unreachable, 2 already-reachable via the shell switch fallback —
      // dropping the baseline to 46. Most of what remains are unwired
      // service-/module-level dashboards (`*/dashboard` chips) waiting
      // for their dashboards to be wired in `v5_wired_screens.dart`.
      //
      // This number must only DECREASE over time as chips get wired up.
      // If it grows, a regression has been introduced. Tighten the
      // baseline when wiring a chip to ratchet the gate.
      const allowedUnreachable = 46;
      expect(unreachable.length, lessThanOrEqualTo(allowedUnreachable),
          reason:
              'Unreachable chips count grew above baseline ($allowedUnreachable). '
              'New chips need wiring (in v5_wired_screens.dart) before merge.\n'
              'See UAT_FORENSIC_FULL_2026-05-06.md.\n'
              'Unreachable now:\n  - '
              '${unreachable.map((s) => s.key).join('\n  - ')}');
    });
  });
}
