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
      // The HOTFIX repaired BUG-1..4 from UAT_FORENSIC_FULL_2026-05-06.md.
      // The runtime validator (which knows about main-module scope —
      // unlike the regex-only `scripts/dev/repro_routing_bugs.py`) also
      // surfaces a pre-existing 5th bug: pin `vat` points to
      // `/app/erp/finance/vat`, but the chip with id `vat` lives in
      // `compliance/tax`, not in `erp/finance`. Out of scope for this
      // PR — tracked separately. See the "Out of scope" section in the
      // PR description.
      //
      // This number must only DECREASE over time. Lower the baseline
      // when fixing a pin to ratchet the gate tighter.
      const allowedBrokenPins = 1;
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
    test('reports broken chips count within baseline', () {
      final all = validateAllChips();
      final unreachable = all.where((s) => !s.isReachable).toList();

      // Per UAT_FORENSIC_FULL_2026-05-06.md, the audit estimated 39
      // unreachable chips. The actual count from the runtime validator
      // is 56 — the audit was a manual sample; the validator is
      // exhaustive. Most are unwired service-/module-level dashboards
      // (`*/dashboard` chips) waiting for their dashboards to be wired
      // in `v5_wired_screens.dart`.
      //
      // This number must only DECREASE over time as chips get wired up.
      // If it grows, a regression has been introduced. Tighten the
      // baseline when wiring a chip to ratchet the gate.
      const allowedUnreachable = 56;
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
