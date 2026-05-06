/// Shared types + base class for the 6 widget renderers.
///
/// Each concrete renderer (kpi_widget_renderer.dart, chart_*, etc.)
/// implements [DashboardWidgetRenderer.render] and is selected by the
/// host screen based on the catalog's `widget_type` string.
///
/// Cross-references:
///   - app/dashboard/seeds.py — the 12 system widget definitions.
///   - app/dashboard/router.py — the /data/* endpoints these consume.
///   - lib/screens/dashboard/customizable_dashboard.dart — the host
///     screen that picks a renderer per block.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A widget catalog entry as returned by `GET /api/v1/dashboard/widgets`.
///
/// Mirrors `app.dashboard.schemas.WidgetOut`. Defensive-typed because
/// the wire is JSON; we use `dynamic` for `config_schema` so per-widget
/// extras flow through untouched.
class DashboardCatalogEntry {
  final String code;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String category;
  final String widgetType;
  final String? dataSource;
  final int defaultSpan;
  final int minSpan;
  final int maxSpan;
  final List<String> requiredPerms;
  final Map<String, dynamic>? configSchema;
  final int refreshSecs;
  final bool isSystem;

  const DashboardCatalogEntry({
    required this.code,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.category,
    required this.widgetType,
    this.dataSource,
    this.defaultSpan = 4,
    this.minSpan = 2,
    this.maxSpan = 12,
    this.requiredPerms = const [],
    this.configSchema,
    this.refreshSecs = 60,
    this.isSystem = true,
  });

  factory DashboardCatalogEntry.fromJson(Map<String, dynamic> j) =>
      DashboardCatalogEntry(
        code: j['code'] as String,
        titleAr: (j['title_ar'] ?? '') as String,
        titleEn: (j['title_en'] ?? '') as String,
        descriptionAr: j['description_ar'] as String?,
        descriptionEn: j['description_en'] as String?,
        category: (j['category'] ?? 'general') as String,
        widgetType: (j['widget_type'] ?? 'custom') as String,
        dataSource: j['data_source'] as String?,
        defaultSpan: (j['default_span'] ?? 4) as int,
        minSpan: (j['min_span'] ?? 2) as int,
        maxSpan: (j['max_span'] ?? 12) as int,
        requiredPerms:
            ((j['required_perms'] ?? const []) as List).cast<String>(),
        configSchema: j['config_schema'] as Map<String, dynamic>?,
        refreshSecs: (j['refresh_secs'] ?? 60) as int,
        isSystem: (j['is_system'] ?? true) as bool,
      );
}

/// One placed instance of a widget — what the host stores per layout.
///
/// `config` is the per-block override of catalog defaults
/// (e.g. accent colour, route on tap, chart_type).
class DashboardBlockSpec {
  final String id;
  final String widgetCode;
  final int span;
  final int x;
  final int y;
  final Map<String, dynamic> config;

  const DashboardBlockSpec({
    required this.id,
    required this.widgetCode,
    this.span = 4,
    this.x = 0,
    this.y = 0,
    this.config = const {},
  });

  factory DashboardBlockSpec.fromJson(Map<String, dynamic> j) =>
      DashboardBlockSpec(
        id: j['id'] as String,
        widgetCode: j['widget_code'] as String,
        span: (j['span'] ?? 4) as int,
        x: (j['x'] ?? 0) as int,
        y: (j['y'] ?? 0) as int,
        config:
            (j['config'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'widget_code': widgetCode,
        'span': span,
        'x': x,
        'y': y,
        'config': config,
      };

  DashboardBlockSpec copyWith({int? span, int? x, int? y, Map<String, dynamic>? config}) =>
      DashboardBlockSpec(
        id: id,
        widgetCode: widgetCode,
        span: span ?? this.span,
        x: x ?? this.x,
        y: y ?? this.y,
        config: config ?? this.config,
      );
}

/// Common error/empty-state painter every renderer reuses.
///
/// Three shapes: backend explicitly returned `error`, payload is null
/// (still loading or denied), or compute returned an empty record.
Widget renderErrorState({
  required BuildContext context,
  required String titleAr,
  String? message,
  VoidCallback? onRetry,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AC.navy3,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 32, color: AC.warn),
        const SizedBox(height: 8),
        Text(
          titleAr,
          style: TextStyle(color: AC.tp, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(color: AC.ts, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ],
    ),
  );
}

/// Renderer contract.
///
/// Keep `render` cheap — it runs on every rebuild.
abstract class DashboardWidgetRenderer {
  Widget render(
    BuildContext context,
    DashboardCatalogEntry def,
    Map<String, dynamic>? payload, {
    VoidCallback? onRetry,
  });
}

/// Helper for renderers that want to extract a known field from
/// `def.config` falling back to `def.configSchema['default']`.
T? readBlockConfig<T>(DashboardCatalogEntry def, Map<String, dynamic>? blockConfig, String key) {
  if (blockConfig != null && blockConfig.containsKey(key)) {
    final v = blockConfig[key];
    if (v is T) return v;
  }
  final schema = def.configSchema;
  if (schema != null && schema.containsKey(key)) {
    final spec = schema[key];
    if (spec is Map && spec.containsKey('default')) {
      final v = spec['default'];
      if (v is T) return v;
    } else if (spec is T) {
      return spec;
    }
  }
  return null;
}
