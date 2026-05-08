/// G-TB-DISPLAY-1 — wiring + plumbing tests for the trial-balance
/// surface. Validates the four pieces that have to line up between
/// data, routing, and the chip-route handler:
///
///   1. v5_data.dart declares a `V5Chip(id: 'trial-balance')` in the
///      finance main module.
///   2. v5_wired_screens.dart wires the `erp/finance/trial-balance`
///      key to a real builder (i.e. the validator's chip-reachability
///      check is satisfied).
///   3. v5_pin_routes.dart points the `tb` pin at
///      `/app/erp/finance/trial-balance` (post-G-TB-DISPLAY-1; was
///      `/app/erp/finance/statements` under HOTFIX-Routing's
///      workaround).
///   4. The new screen file (`screens/finance/trial_balance_screen.dart`)
///      is imported by `v5_wired_screens.dart` so dart2js doesn't
///      tree-shake the State class on a release build (the same
///      class of bug G-TREESHAKE-FIX-2 closed).
///
/// Why this file doesn't drive the widget directly
/// -----------------------------------------------
/// `TrialBalanceScreen` imports `session.dart`, which imports
/// `dart:html`, which transitively pulls in `package:web` 1.1.1 —
/// the same SDK mismatch (G-T1.1) that blocks
/// `ask_panel_test.dart`. Until G-T1.1 is closed, full widget tests
/// of the screen can't load on the Dart VM. This file holds the
/// regression contracts that DO compile — they're the parts a
/// future contributor most likely breaks accidentally (renaming a
/// chip id, deleting a route, forgetting the offstage instance) —
/// and the deeper UAT runs out of band against the deployed app.
library;

import 'package:apex_finance/core/v5/v5_data.dart';
import 'package:apex_finance/core/v5/v5_pin_routes.dart';
import 'package:apex_finance/core/v5/v5_wired_keys.dart';
import 'package:apex_finance/core/v5/v5_routing_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TB chip declaration', () {
    test(
      'v5_data finance main has a chip with id trial-balance',
      () {
        final svc = v5ServiceById('erp');
        expect(svc, isNotNull, reason: 'erp service must exist');
        final main = svc!.mainModuleById('finance');
        expect(main, isNotNull, reason: 'erp/finance must exist');
        final chip = main!.chipById('trial-balance');
        expect(
          chip,
          isNotNull,
          reason:
              'V5Chip(id: "trial-balance") must be declared in '
              'v5_data finance main module — without it the validator '
              'fails the broken-pin baseline and the parametric '
              '/app/:service/:main/:chip route 404s.',
        );
        // The label is the user-visible Arabic chip label; if a
        // refactor renames it, this test surfaces the regression.
        expect(chip!.labelAr, 'ميزان المراجعة');
        expect(chip.labelEn, 'Trial Balance');
      },
    );
  });

  group('TB wired-screens registration', () {
    test(
      'erp/finance/trial-balance is in v5WiredKeys',
      () {
        expect(
          v5WiredKeys.contains('erp/finance/trial-balance'),
          isTrue,
          reason:
              'wired-keys generator must have re-run after the new '
              'TrialBalanceScreen import was added',
        );
      },
    );

    test(
      'chip reachability for erp/finance/trial-balance is wired',
      () {
        // The chip-reachability validator returns one
        // ChipValidationStatus per (service, main, chip). Find ours
        // and assert it's marked wired (not just dashboard / sub-
        // module / switch fallback).
        final all = validateAllChips();
        final hit = all.firstWhere(
          (s) => s.key == 'erp/finance/trial-balance',
          orElse: () => throw StateError(
            'no validator entry for erp/finance/trial-balance — chip '
            'must be declared in v5_data first',
          ),
        );
        expect(
          hit.wired,
          isTrue,
          reason:
              'wired flag must come from v5WiredScreens entry, not '
              'a switch fallback — the trial-balance route is in the '
              'Map directly.',
        );
        expect(hit.isReachable, isTrue);
      },
    );
  });

  group('TB pin route', () {
    test(
      'tb pin points at /app/erp/finance/trial-balance',
      () {
        final tb = kAllPinsForValidation.firstWhere(
          (p) => p.id == 'tb',
          orElse: () => throw StateError(
            'tb pin missing from kAllPinsForValidation — both this '
            'list and apex_v5_service_shell.dart\'s _kAllPins must '
            'be updated together (manual mirror; see comments in '
            'v5_pin_routes.dart).',
          ),
        );
        expect(
          tb.route,
          '/app/erp/finance/trial-balance',
          reason:
              'pin route must match the GoRoute path added in '
              'v5_routes.dart so the user lands on the real TB screen '
              'instead of the prior /statements fallback.',
        );
      },
    );

    test(
      'no pin still uses HOTFIX-Routing\'s /statements detour for tb',
      () {
        // Belt-and-braces — directly assert the obsolete detour
        // is gone. A regression here would mean someone reverted
        // G-TB-DISPLAY-1 and forgot the pin.
        final tbRoutes = kAllPinsForValidation
            .where((p) => p.id == 'tb')
            .map((p) => p.route)
            .toList();
        expect(
          tbRoutes,
          isNot(contains('/app/erp/finance/statements')),
          reason: 'the HOTFIX-Routing workaround is retired',
        );
      },
    );
  });

  group('TB pin contract — routing validator stays green', () {
    test(
      'no pin in kAllPinsForValidation has a chip mismatch on tb',
      () {
        // Re-run the same `validatePins` the v5_routing_test gates
        // on, but spotlight any errors that mention `tb`. This is a
        // tighter assertion than the broader broken-pin baseline —
        // if `tb` resolves but some other pin has unrelated drift,
        // we still pass here.
        final errors = validatePins();
        final tbProblems =
            errors.where((e) => e.pinId == 'tb').toList();
        expect(
          tbProblems,
          isEmpty,
          reason:
              'tb pin must validate cleanly against v5_data + the '
              'wired-screens map after G-TB-DISPLAY-1.',
        );
      },
    );
  });
}
