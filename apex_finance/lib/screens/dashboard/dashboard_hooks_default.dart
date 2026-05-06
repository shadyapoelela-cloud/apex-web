/// Live network adapter for [DashboardApiHooks].
///
/// Lives in its own file so the test suite can import the screen +
/// renderers without dragging `api_service.dart` (and its transitive
/// `package:http/browser_client.dart` ⇒ `package:web` chain) into
/// the compile graph. Production callers (router.dart) get the
/// adapter via [defaultDashboardHooks].
library;

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../api_service.dart';
import '../../core/session.dart';
import '../../widgets/dashboard/_base.dart';
import 'customizable_dashboard.dart';

DashboardApiHooks defaultDashboardHooks({
  required DashboardEditTarget target,
  String roleId = '',
}) {
  return DashboardApiHooks(
    fetchWidgets: () async {
      final res = await ApiService.dashboardWidgets();
      if (!res.success || res.data is! List) return const [];
      return (res.data as List)
          .whereType<Map>()
          .map((m) => DashboardCatalogEntry.fromJson(m.cast<String, dynamic>()))
          .toList();
    },
    fetchLayout: () async {
      final res = await ApiService.dashboardLayout();
      if (!res.success || res.data == null) return null;
      return DashboardLayoutFetchResult.fromJson(
          (res.data as Map).cast<String, dynamic>());
    },
    fetchBatch: (codes) async {
      final res = await ApiService.dashboardBatch(widgetCodes: codes);
      if (!res.success || res.data is! Map) return const {};
      return (res.data as Map).cast<String, dynamic>();
    },
    saveLayout: (blocks, {String name = 'default'}) async {
      final payload = blocks.map((b) => b.toJson()).toList();
      if (target == DashboardEditTarget.role) {
        final res = await ApiService.dashboardSaveRoleLayout(
            roleId, payload, name: name);
        return res.success;
      }
      final res = await ApiService.saveDashboardLayout(payload, name: name);
      return res.success;
    },
    resetLayout: () async {
      await ApiService.resetDashboardLayout();
    },
    openStream: () => _defaultStream(),
    refreshWidget: (code) async {
      final res = await ApiService.dashboardWidgetData(code);
      if (res.success && res.data is Map) {
        return (res.data as Map).cast<String, dynamic>();
      }
      return null;
    },
    hasPerm: (perm) => S.hasPerm(perm),
  );
}

/// EventSource-based SSE adapter (web only — same constraint as the
/// rest of the codebase via session.dart's dart:html cookie reads).
Stream<Map<String, dynamic>> _defaultStream() {
  final url = ApiService.dashboardStreamUrl();
  final src = html.EventSource(url, withCredentials: true);
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  void emit(html.MessageEvent ev, String type) {
    try {
      final raw = ev.data;
      if (raw is String && raw.isNotEmpty) {
        final m = jsonDecode(raw);
        if (m is Map) {
          final out = m.cast<String, dynamic>();
          out['_event_type'] = type;
          controller.add(out);
        }
      }
    } catch (_) {/* ignore malformed frames */}
  }

  src.addEventListener('hello', (e) => emit(e as html.MessageEvent, 'hello'));
  src.addEventListener('ping', (e) => emit(e as html.MessageEvent, 'ping'));
  src.addEventListener(
      'invalidate', (e) => emit(e as html.MessageEvent, 'invalidate'));
  src.addEventListener(
      'update', (e) => emit(e as html.MessageEvent, 'update'));

  controller.onCancel = () {
    src.close();
  };
  return controller.stream;
}
