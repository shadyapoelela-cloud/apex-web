/// Pilot Session — حفظ سياق المستأجر/الكيان/الفرع في localStorage.
///
/// بديل بسيط ومباشر لـ PilotBridge. بدون ChangeNotifier، بدون Singleton
/// Listener — فقط قراءة/كتابة localStorage عند الحاجة.
///
/// كل شاشة تقرأ القيم عند البناء، تعمل مباشرة مع الباك-إند.

library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PilotSession {
  static const _tenantKey = 'pilot.tenant_id';
  static const _entityKey = 'pilot.entity_id';
  static const _branchKey = 'pilot.branch_id';
  static const _historyKey = 'pilot.tenant_history';
  static const int _historyMax = 8;

  // Mirror keys — kept in sync with the older `S` session (core/session.dart)
  // so screens reading either system see the same active scope.
  static const _legacyTenantKey = 'apex_tenant_id';
  static const _legacyEntityKey = 'apex_entity_id';

  // G-LEGACY-KEY-AUDIT (2026-05-09): the migration helper has run
  // at least once this session. Lazy + once — the first call
  // (typically via the `tenantId` getter) reconciles any drift
  // between `pilot.tenant_id` and `apex_tenant_id` left over from
  // earlier sessions. Subsequent reads skip the work.
  static bool _legacyMigrated = false;

  /// G-LEGACY-KEY-AUDIT (2026-05-09): one-shot reconciliation of the
  /// pilot ↔ legacy localStorage keys.
  ///
  /// Three scenarios this helper handles when the session loads:
  ///
  ///   * **Both keys exist and agree** — no-op.
  ///   * **Both exist but differ** — trust `pilot.tenant_id`
  ///     (the canonical, written by the post-PR-#182 setter chain).
  ///     Sync the legacy key so any pre-pilot reader (e.g. the
  ///     20+ screens still calling `S.tenantId`) sees the right
  ///     value. Console-warn so the drift is visible during dev.
  ///   * **Only legacy exists** (a session from before the pilot
  ///     keys existed) — copy it to `pilot.tenant_id` so
  ///     `PilotSession.hasTenant` returns true and the wizard's
  ///     `if (PilotSession.hasTenant)` branch fires.
  ///
  /// Idempotent: subsequent calls in the same session are no-ops
  /// thanks to the `_legacyMigrated` guard.
  static void migrateLegacyKey() {
    if (_legacyMigrated) return;
    _legacyMigrated = true;
    try {
      final pilot = html.window.localStorage[_tenantKey];
      final legacy = html.window.localStorage[_legacyTenantKey];

      if (pilot != null && pilot.isNotEmpty) {
        // Pilot is canonical; sync the legacy key if it's missing
        // or drifted.
        if (legacy != pilot) {
          html.window.localStorage[_legacyTenantKey] = pilot;
          if (legacy != null && legacy.isNotEmpty) {
            // Both existed and differed → drift. Visible in console
            // so devs notice during pre-prod testing.
            // ignore: avoid_print
            print(
              '[APEX][G-LEGACY-KEY-AUDIT] tenant_id drift detected '
              '(pilot=$pilot, legacy=$legacy). Synced legacy → pilot.',
            );
          }
        }
      } else if (legacy != null && legacy.isNotEmpty) {
        // Only legacy exists (a very old session). Migrate up to
        // pilot so post-PR-#182 readers see hasTenant=true.
        html.window.localStorage[_tenantKey] = legacy;
      }
      // Else: both missing → nothing to migrate. Genuine logged-out
      // / fresh-browser state.
    } catch (_) {
      // localStorage unavailable (incognito quota exceeded /
      // sandboxed iframe / similar). Bail silently — the app
      // continues without the migration; no value lost.
    }
  }

  // ── Tenant ──────────────────────────────────────────────────
  static String? get tenantId {
    // First read of the session triggers the legacy reconciliation.
    if (!_legacyMigrated) migrateLegacyKey();
    return _get(_tenantKey);
  }
  static set tenantId(String? v) {
    _set(_tenantKey, v);
    _set(_legacyTenantKey, v); // keep S.savedTenantId in sync
    if (v != null && v.isNotEmpty) _pushHistory(v);
  }
  static bool get hasTenant => tenantId != null && tenantId!.isNotEmpty;

  // ── Tenant history (recently-bound tenants) ─────────────────
  /// Returns list of {id, name} for recently-bound tenants (most-recent first).
  static List<Map<String, String>> get tenantHistory {
    try {
      final raw = html.window.localStorage[_historyKey] ?? '';
      if (raw.isEmpty) return [];
      return raw
          .split('|')
          .where((s) => s.isNotEmpty)
          .map((s) {
            final parts = s.split('::');
            return {
              'id': parts.isNotEmpty ? parts[0] : '',
              'name': parts.length > 1 ? parts[1] : '',
            };
          })
          .where((m) => (m['id'] ?? '').isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Update the cached display name for a tenant in the history.
  static void rememberTenantName(String tenantId, String name) {
    if (tenantId.isEmpty) return;
    final hist = tenantHistory;
    for (final h in hist) {
      if (h['id'] == tenantId) h['name'] = name;
    }
    _writeHistory(hist);
  }

  /// Drop a tenant from the history.
  static void forgetTenant(String tenantId) {
    final hist = tenantHistory.where((h) => h['id'] != tenantId).toList();
    _writeHistory(hist);
  }

  static void _pushHistory(String id) {
    final hist = tenantHistory;
    // Keep existing name if any
    final existingName =
        hist.firstWhere((h) => h['id'] == id, orElse: () => {})['name'] ?? '';
    hist.removeWhere((h) => h['id'] == id);
    hist.insert(0, {'id': id, 'name': existingName});
    while (hist.length > _historyMax) {
      hist.removeLast();
    }
    _writeHistory(hist);
  }

  static void _writeHistory(List<Map<String, String>> hist) {
    try {
      final encoded =
          hist.map((h) => '${h['id']}::${h['name'] ?? ''}').join('|');
      html.window.localStorage[_historyKey] = encoded;
    } catch (_) {}
  }

  // ── Entity ──────────────────────────────────────────────────
  static String? get entityId => _get(_entityKey);
  static set entityId(String? v) {
    _set(_entityKey, v);
    _set(_legacyEntityKey, v); // keep S.savedEntityId in sync
  }
  static bool get hasEntity => entityId != null && entityId!.isNotEmpty;

  // ── Branch ──────────────────────────────────────────────────
  static String? get branchId => _get(_branchKey);
  static set branchId(String? v) => _set(_branchKey, v);
  static bool get hasBranch => branchId != null && branchId!.isNotEmpty;

  // ── Reset ──────────────────────────────────────────────────
  static void clear() {
    for (final k in [_tenantKey, _entityKey, _branchKey, _legacyTenantKey, _legacyEntityKey]) {
      _set(k, null);
    }
  }

  static void clearEntityAndBranch() {
    _set(_entityKey, null);
    _set(_branchKey, null);
    _set(_legacyEntityKey, null);
  }

  static void clearBranch() => _set(_branchKey, null);

  // ── Internal storage ───────────────────────────────────────
  static String? _get(String key) {
    try {
      final v = html.window.localStorage[key];
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  static void _set(String key, String? value) {
    try {
      if (value == null || value.isEmpty) {
        html.window.localStorage.remove(key);
      } else {
        html.window.localStorage[key] = value;
      }
    } catch (_) {}
  }
}
