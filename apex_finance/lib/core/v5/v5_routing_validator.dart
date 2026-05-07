/// V5 Routing Validator (HOTFIX-Routing Sprint 16, 2026-05-06).
///
/// Compile-time-ish guards against broken pin routes and missing chip
/// definitions — added after the UAT forensic audit found 4 broken
/// Quick Access pins that produced 404 pages in production.
///
/// See `UAT_FORENSIC_FULL_2026-05-06.md` for the audit that motivated
/// this layer.
library;

import 'package:flutter/foundation.dart';

import 'apex_v5_service_shell.dart' show kAllPinsForValidation;
import 'v5_data.dart';
import 'v5_wired_screens.dart' show v5WiredScreens;

class PinValidationError {
  final String pinId;
  final String route;
  final String reason;
  const PinValidationError(this.pinId, this.route, this.reason);

  @override
  String toString() => 'Pin $pinId: $reason ($route)';
}

class ChipValidationStatus {
  final String key; // service/main/chip
  final bool wired;
  final bool hasSwitchFallback;
  final bool hasSubModule;
  const ChipValidationStatus(
      this.key, this.wired, this.hasSwitchFallback, this.hasSubModule);

  bool get isReachable => wired || hasSwitchFallback || hasSubModule;
}

/// Mirror of the switch in `apex_v5_service_shell.dart` (~line 227).
/// Update this set if you add cases to that switch.
const _switchFallbackChips = <String>{
  'crm',
  'customers-360',
  'sales-invoices',
  'entity-setup',
  'onboarding',
};

/// Validate every Quick Access pin resolves to a real chip in `v5_data`.
List<PinValidationError> validatePins() {
  final errors = <PinValidationError>[];
  for (final pin in kAllPinsForValidation) {
    if (pin.route.contains('/app/erp/app/')) {
      errors.add(PinValidationError(
          pin.id, pin.route, 'double "/app/erp/" prefix detected'));
      continue;
    }

    final segments =
        pin.route.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.length != 4 || segments[0] != 'app') {
      errors.add(PinValidationError(pin.id, pin.route,
          'invalid shape — expected /app/{service}/{main}/{chip}'));
      continue;
    }

    final service = segments[1];
    final main = segments[2];
    final chip = segments[3];

    final svc = v5ServiceById(service);
    if (svc == null) {
      errors.add(PinValidationError(pin.id, pin.route,
          'service "$service" not registered in v5_data'));
      continue;
    }
    final m = svc.mainModuleById(main);
    if (m == null) {
      errors.add(PinValidationError(pin.id, pin.route,
          'main module "$main" not in service "$service"'));
      continue;
    }
    final c = m.chipById(chip);
    if (c == null) {
      errors.add(PinValidationError(pin.id, pin.route,
          'chip "$chip" not defined in main "$main"'));
    }
  }

  if (kDebugMode && errors.isNotEmpty) {
    debugPrint('⚠️  V5 routing validation: ${errors.length} broken pin(s):');
    for (final e in errors) {
      debugPrint('   - $e');
    }
  }
  return errors;
}

/// Walks every chip in `v5_data` and reports its reachability.
///
/// A chip is "reachable" if at least one of these is true:
///   * it has an entry in [v5WiredScreens]
///   * its id is in the standalone-screen switch (see [_switchFallbackChips])
///   * it carries a `subModule` (V4 sub-module reuse path in shell)
///
/// Anything else falls through to the "coming soon" banner.
List<ChipValidationStatus> validateAllChips() {
  final results = <ChipValidationStatus>[];
  for (final svc in v5Services) {
    for (final m in svc.mainModules) {
      for (final c in m.chips) {
        final key = '${svc.id}/${m.id}/${c.id}';
        final wired = v5WiredScreens.containsKey(key);
        final hasSwitch = _switchFallbackChips.contains(c.id);
        final hasSub = c.subModule != null;
        results.add(ChipValidationStatus(key, wired, hasSwitch, hasSub));
      }
    }
  }
  return results;
}
