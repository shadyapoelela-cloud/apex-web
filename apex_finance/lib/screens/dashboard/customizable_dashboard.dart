/// CustomizableDashboard — DASH-1.1 host screen.
///
/// Pulls /widgets + /layout + /data/batch in parallel on first paint,
/// re-uses [ApexDashboardBuilder] for the drag/drop UX, and renders
/// each block via the matching renderer in lib/widgets/dashboard/.
///
/// Edit Mode is gated on `customize:dashboard`. The "Role Layouts"
/// nav button is gated on `manage:dashboard_role`.
///
/// SSE updates from /api/v1/dashboard/stream mutate `_data[code]`
/// only — granular setState keeps the rest of the dashboard intact
/// (no full rebuild on every event).
library;

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_dashboard_builder.dart' as adb;
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/dashboard/_base.dart';
import '../../widgets/dashboard/action_widget_renderer.dart';
import '../../widgets/dashboard/ai_widget_renderer.dart';
import '../../widgets/dashboard/chart_widget_renderer.dart';
import '../../widgets/dashboard/kpi_widget_renderer.dart';
import '../../widgets/dashboard/list_widget_renderer.dart';
import '../../widgets/dashboard/table_widget_renderer.dart';

/// Layer mode — user vs role-admin. Same screen, different write target.
enum DashboardEditTarget {
  /// Writes go to PUT /layout (user's personal layout).
  user,

  /// Writes go to PUT /role-layouts/{roleId} (admin editing a role default).
  role,
}

/// Result of a /layout fetch — exposed publicly so tests + admin
/// callers can construct it directly.
class DashboardLayoutFetchResult {
  final String? id;
  final String scope;
  final bool isLocked;
  final List<DashboardBlockSpec> blocks;

  const DashboardLayoutFetchResult({
    required this.id,
    required this.scope,
    required this.isLocked,
    required this.blocks,
  });

  factory DashboardLayoutFetchResult.fromJson(Map<String, dynamic> j) {
    final raw = (j['blocks'] as List?) ?? const [];
    return DashboardLayoutFetchResult(
      id: j['id'] as String?,
      scope: (j['scope'] ?? 'system') as String,
      isLocked: (j['is_locked'] ?? false) as bool,
      blocks: raw
          .whereType<Map>()
          .map((m) => DashboardBlockSpec.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Override hooks the test suite uses to pin network + SSE without
/// pulling in mockito. Defaults call the real ApiService / EventSource.
class DashboardApiHooks {
  final Future<List<DashboardCatalogEntry>> Function() fetchWidgets;
  final Future<DashboardLayoutFetchResult?> Function() fetchLayout;
  final Future<Map<String, dynamic>> Function(List<String> codes) fetchBatch;
  final Future<bool> Function(List<DashboardBlockSpec> blocks, {String name}) saveLayout;
  final Future<void> Function() resetLayout;
  final Stream<Map<String, dynamic>> Function()? openStream;

  const DashboardApiHooks({
    required this.fetchWidgets,
    required this.fetchLayout,
    required this.fetchBatch,
    required this.saveLayout,
    required this.resetLayout,
    this.openStream,
  });

  static DashboardApiHooks defaults({
    required String roleId,
    required DashboardEditTarget target,
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
    );
  }
}

/// Default SSE adapter — uses the browser's EventSource so the
/// connection survives tab visibility changes the way Dart's http
/// stream wouldn't.
Stream<Map<String, dynamic>> _defaultStream() {
  final url = ApiService.dashboardStreamUrl();
  // Cookie auth — the apex_token HttpOnly cookie carries the token
  // the same way the rest of the app authenticates.
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

/// Public widget. The constructor accepts `target` + `roleId` so the
/// admin route can mount the same screen pointed at PUT /role-layouts/.
class CustomizableDashboard extends StatefulWidget {
  final DashboardEditTarget target;
  final String? roleId;
  final DashboardApiHooks? hooks;
  final String? title;

  const CustomizableDashboard({
    super.key,
    this.target = DashboardEditTarget.user,
    this.roleId,
    this.hooks,
    this.title,
  });

  @override
  State<CustomizableDashboard> createState() => _CustomizableDashboardState();
}

class _CustomizableDashboardState extends State<CustomizableDashboard> {
  late DashboardApiHooks _hooks;

  List<DashboardCatalogEntry> _availableWidgets = const [];
  List<DashboardBlockSpec> _layout = const [];
  Map<String, Map<String, dynamic>> _data = {};
  bool _editMode = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _isLocked = false;

  StreamSubscription<Map<String, dynamic>>? _sseSub;

  bool get _canCustomize {
    if (widget.target == DashboardEditTarget.role) {
      return S.hasPerm('manage:dashboard_role');
    }
    return S.hasPerm('customize:dashboard');
  }

  bool get _canManageRoles => S.hasPerm('manage:dashboard_role');

  @override
  void initState() {
    super.initState();
    _hooks = widget.hooks ??
        DashboardApiHooks.defaults(
          roleId: widget.roleId ?? '',
          target: widget.target,
        );
    _bootstrap();
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _hooks.fetchWidgets(),
        _hooks.fetchLayout(),
      ]);
      final widgets = results[0] as List<DashboardCatalogEntry>;
      final layout = results[1] as DashboardLayoutFetchResult?;

      _availableWidgets = widgets;
      _layout = layout?.blocks ?? const [];
      _isLocked = layout?.isLocked ?? false;

      if (_layout.isNotEmpty) {
        final codes = _layout.map((b) => b.widgetCode).toSet().toList();
        final batch = await _hooks.fetchBatch(codes);
        final data = (batch['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        _data = data.map(
          (k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()),
        );
      }

      _openStream();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _openStream() {
    final opener = _hooks.openStream;
    if (opener == null) return;
    _sseSub?.cancel();
    _sseSub = opener().listen(
      _onStreamRecord,
      onError: (_) {/* swallow — reconnect handled by EventSource */},
    );
  }

  void _onStreamRecord(Map<String, dynamic> record) {
    final type = (record['_event_type'] ?? record['type'] ?? '') as String;
    switch (type) {
      case 'update':
        final code = record['widget_code'] as String?;
        final payload = (record['payload'] as Map?)?.cast<String, dynamic>();
        if (code != null && payload != null) {
          setState(() {
            _data = {..._data, code: payload};
          });
        }
        break;
      case 'invalidate':
        // Re-fetch only the widgets the event invalidated.
        final raw = record['widget_codes'];
        final codes = raw is List
            ? raw.whereType<String>().toList()
            : const <String>[];
        if (codes.isNotEmpty) {
          _hooks.fetchBatch(codes).then((batch) {
            final data = (batch['data'] as Map?)?.cast<String, dynamic>() ?? const {};
            if (!mounted) return;
            setState(() {
              for (final c in codes) {
                if (data.containsKey(c)) {
                  _data = {
                    ..._data,
                    c: (data[c] as Map).cast<String, dynamic>(),
                  };
                }
              }
            });
          }).catchError((_) {/* swallow */});
        }
        break;
      default:
        // ping / hello — nothing to do.
        break;
    }
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    try {
      final ok = await _hooks.saveLayout(_layout);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _editMode = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التخطيط')),
        );
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحفظ — تحقق من الصلاحيات')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
    }
  }

  Future<void> _onCancel() async {
    setState(() => _editMode = false);
    await _bootstrap();
  }

  Future<void> _onReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة افتراضي'),
        content: const Text(
          'سيتم حذف تخطيطك المخصص والعودة إلى تخطيط دورك أو افتراضي النظام. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            child: const Text('إعادة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _hooks.resetLayout();
      await _bootstrap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإعادة: $e')),
      );
    }
  }

  // ── Build helpers ───────────────────────────────────────

  /// Translate the catalog into the format `ApexDashboardBuilder` expects.
  List<adb.DashboardWidgetDef> _buildRegistry() {
    return [
      for (final w in _availableWidgets)
        adb.DashboardWidgetDef(
          id: w.code,
          title: w.titleAr,
          subtitle: w.titleEn,
          icon: _iconForCategory(w.category),
          defaultSpan: w.defaultSpan,
          builder: (ctx) => _renderBlock(ctx, w),
        ),
    ];
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'analytics':
        return Icons.bar_chart;
      case 'sales':
        return Icons.point_of_sale;
      case 'platform':
        return Icons.fact_check_outlined;
      case 'compliance':
        return Icons.gavel;
      case 'ai':
        return Icons.auto_awesome;
      case 'actions':
        return Icons.bolt;
      default:
        return Icons.dashboard_outlined;
    }
  }

  Widget _renderBlock(BuildContext ctx, DashboardCatalogEntry w) {
    final payload = _data[w.code];
    void retry() {
      _hooks.fetchBatch([w.code]).then((batch) {
        final data = (batch['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        if (!mounted) return;
        if (data[w.code] is Map) {
          setState(() {
            _data = {
              ..._data,
              w.code: (data[w.code] as Map).cast<String, dynamic>(),
            };
          });
        }
      });
    }

    switch (w.widgetType) {
      case 'kpi':
        return const KpiWidgetRenderer().render(ctx, w, payload, onRetry: retry);
      case 'chart':
        return const ChartWidgetRenderer().render(ctx, w, payload, onRetry: retry);
      case 'table':
        return const TableWidgetRenderer().render(ctx, w, payload, onRetry: retry);
      case 'list':
        return const ListWidgetRenderer().render(ctx, w, payload, onRetry: retry);
      case 'ai':
        return AiWidgetRenderer(
          onRefreshed: (code, fresh) {
            if (!mounted) return;
            setState(() {
              _data = {..._data, code: fresh};
            });
          },
        ).render(ctx, w, payload, onRetry: retry);
      case 'action':
        return const ActionWidgetRenderer().render(ctx, w, payload, onRetry: retry);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Adapter — DashboardBlockSpec ↔ adb.DashboardBlock for the builder.
  List<adb.DashboardBlock> _toBuilderBlocks() => [
        for (final b in _layout)
          adb.DashboardBlock(id: b.id, widgetId: b.widgetCode, span: b.span),
      ];

  void _onLayoutChanged(List<adb.DashboardBlock> next) {
    // Preserve x/y/config from the existing layout where possible.
    final byId = {for (final b in _layout) b.id: b};
    setState(() {
      _layout = [
        for (var i = 0; i < next.length; i++)
          DashboardBlockSpec(
            id: next[i].id,
            widgetCode: next[i].widgetId,
            span: next[i].span,
            x: byId[next[i].id]?.x ?? 0,
            y: i,
            config: byId[next[i].id]?.config ?? const {},
          ),
      ];
    });
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text(widget.title ?? 'لوحة التحكم'),
        actions: [
          if (!_editMode && _canManageRoles && widget.target == DashboardEditTarget.user)
            IconButton(
              tooltip: 'إعداد افتراضي للأدوار',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.go('/dashboard/admin/role-layouts'),
            ),
          if (!_editMode && _canCustomize && !_isLocked)
            IconButton(
              tooltip: 'تخصيص',
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editMode = true),
            ),
          if (_isLocked && !_editMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 16, color: AC.warn),
                  const SizedBox(width: 4),
                  Text('مقفول', style: TextStyle(color: AC.warn, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _editMode ? _buildEditBar() : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AC.gold),
            const SizedBox(height: 12),
            Text('جارٍ تحميل لوحة التحكم…',
                style: TextStyle(color: AC.ts)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: renderErrorState(
            context: context,
            titleAr: 'فشل تحميل لوحة التحكم',
            message: _error,
            onRetry: _bootstrap,
          ),
        ),
      );
    }
    if (_layout.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize_outlined,
                  size: 48, color: AC.gold),
              const SizedBox(height: 12),
              Text(
                'لا توجد عناصر في لوحة التحكم بعد',
                style: TextStyle(color: AC.tp, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (_canCustomize)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _editMode = true),
                  icon: const Icon(Icons.add),
                  label: const Text('بدء التخصيص'),
                ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: adb.ApexDashboardBuilder(
          blocks: _toBuilderBlocks(),
          widgetRegistry: _buildRegistry(),
          editable: _editMode,
          onLayoutChanged: _onLayoutChanged,
        ),
      ),
    );
  }

  Widget _buildEditBar() {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(top: BorderSide(color: AC.bdr)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: _saving ? null : _onCancel,
              child: const Text('إلغاء'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _saving ? null : _onReset,
              icon: const Icon(Icons.restore),
              label: const Text('إعادة افتراضي'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : _onSave,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
