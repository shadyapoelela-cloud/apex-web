/// APEX Platform — Company Local Store
/// ════════════════════════════════════════════════════════════════════
/// Guest-mode companies persistence layer.
///
/// Decouples "create/list my companies" from the backend auth layer
/// when `S.token` is null (login is currently disabled in this build).
/// Persists a JSON list of company records to `window.localStorage`
/// under the key `apex_companies_v1` so guests can create companies
/// and see them between sessions without a backend call.
///
/// When a real auth token arrives later, the backend `/clients` API
/// response is merged on top: remote items win on `id` collision, local
/// items that don't exist remotely remain (eventually-consistent
/// offline-first pattern).
/// ════════════════════════════════════════════════════════════════════
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

class CompanyLocalStore {
  CompanyLocalStore._();
  static const _key = 'apex_companies_v1';

  /// Load all locally-persisted companies.
  static List<Map<String, dynamic>> list() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist the given list, overwriting previous state.
  static void _save(List<Map<String, dynamic>> items) {
    try {
      html.window.localStorage[_key] = jsonEncode(items);
    } catch (_) {}
  }

  /// Append a new company with an auto-generated ID if missing.
  /// Returns the stored record (with its final `id`).
  static Map<String, dynamic> add(Map<String, dynamic> company) {
    final items = list();
    final now = DateTime.now().toIso8601String();
    final id = company['id']?.toString().isNotEmpty == true
        ? company['id'].toString()
        : 'local_${DateTime.now().microsecondsSinceEpoch}';
    final record = <String, dynamic>{
      ...company,
      'id': id,
      'created_at': company['created_at'] ?? now,
      'updated_at': now,
      // Mark as local-origin so UI can badge it if desired.
      '_local': true,
    };
    // Upsert by id.
    final idx = items.indexWhere((c) => c['id'] == id);
    if (idx >= 0) {
      items[idx] = {...items[idx], ...record};
    } else {
      items.add(record);
    }
    _save(items);
    return record;
  }

  /// Patch-update a company by id. Silently ignores unknown ids.
  static Map<String, dynamic>? update(String id, Map<String, dynamic> patch) {
    final items = list();
    final idx = items.indexWhere((c) => c['id'] == id);
    if (idx < 0) return null;
    items[idx] = {
      ...items[idx],
      ...patch,
      'updated_at': DateTime.now().toIso8601String(),
    };
    _save(items);
    return items[idx];
  }

  /// Soft-remove by id.
  static void remove(String id) {
    final items = list()..removeWhere((c) => c['id'] == id);
    _save(items);
  }

  /// Merge a remote list with the local one. Remote wins on id collision;
  /// local-only records are preserved. Returns the merged list (not
  /// persisted — caller decides whether to write back).
  static List<Map<String, dynamic>> mergeWithRemote(
      List<Map<String, dynamic>> remote) {
    final local = list();
    final byId = <String, Map<String, dynamic>>{};
    for (final l in local) {
      final id = l['id']?.toString();
      if (id != null) byId[id] = l;
    }
    for (final r in remote) {
      final id = r['id']?.toString();
      if (id != null) byId[id] = r; // remote wins
    }
    return byId.values.toList();
  }

  /// Clear all local records (used on explicit user "reset" action).
  static void clear() {
    try {
      html.window.localStorage.remove(_key);
    } catch (_) {}
  }
}
