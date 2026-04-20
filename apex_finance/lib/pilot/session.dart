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

  // ── Tenant ──────────────────────────────────────────────────
  static String? get tenantId => _get(_tenantKey);
  static set tenantId(String? v) => _set(_tenantKey, v);
  static bool get hasTenant => tenantId != null && tenantId!.isNotEmpty;

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
