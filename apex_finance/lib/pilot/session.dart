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

  // ── Tenant ──────────────────────────────────────────────────
  static String? get tenantId => _get(_tenantKey);
  static set tenantId(String? v) {
    _set(_tenantKey, v);
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
  static set entityId(String? v) => _set(_entityKey, v);
  static bool get hasEntity => entityId != null && entityId!.isNotEmpty;

  // ── Branch ──────────────────────────────────────────────────
  static String? get branchId => _get(_branchKey);
  static set branchId(String? v) => _set(_branchKey, v);
  static bool get hasBranch => branchId != null && branchId!.isNotEmpty;

  // ── Reset ──────────────────────────────────────────────────
  static void clear() {
    for (final k in [_tenantKey, _entityKey, _branchKey]) {
      _set(k, null);
    }
  }

  static void clearEntityAndBranch() {
    _set(_entityKey, null);
    _set(_branchKey, null);
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
