/// AI Pulse renderer — narrated headline + per-widget refresh button.
///
/// Payload (from app/dashboard/resolvers.widget_ai_pulse):
/// ```
/// {
///   "headline_ar": "كل شيء جيد — لا يوجد تنبيهات حرجة.",
///   "headline_en": "All clear — no critical alerts.",
///   "alerts": [],                  // optional
///   "confidence": 0.85,            // optional, 0.0-1.0
///   "generated_at": "..."          // optional ISO timestamp
/// }
/// ```
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';
import '_base.dart';

/// Hook the host screen passes when it wants per-widget refresh
/// without going through the SSE / batch path. Defaults to calling
/// `ApiService.dashboardWidgetData` and returning the unwrapped payload.
typedef WidgetRefresher = Future<Map<String, dynamic>?> Function(String code);

class AiWidgetRenderer implements DashboardWidgetRenderer {
  final WidgetRefresher? refresher;
  final void Function(String code, Map<String, dynamic> payload)? onRefreshed;

  const AiWidgetRenderer({this.refresher, this.onRefreshed});

  @override
  Widget render(
    BuildContext context,
    DashboardCatalogEntry def,
    Map<String, dynamic>? payload, {
    VoidCallback? onRetry,
  }) {
    if (payload == null) {
      return renderErrorState(
        context: context,
        titleAr: 'جارٍ توليد نبضة الذكاء…',
        onRetry: onRetry,
      );
    }
    if (payload.containsKey('error') && payload['error'] != null) {
      return renderErrorState(
        context: context,
        titleAr: def.titleAr,
        message: payload['error']?.toString(),
        onRetry: onRetry,
      );
    }

    final headline = (payload['headline_ar'] ??
            payload['headline_en'] ??
            payload['pulse_text'] ??
            'لا توجد رسالة بعد.')
        .toString();
    final num? confidence = payload['confidence'] as num?;
    final generatedAt = payload['generated_at'] as String?;
    final alerts = ((payload['alerts'] ?? const []) as List).whereType<Map>().toList();

    final highConfidence = (confidence ?? 0) >= 0.7;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AC.navy3, AC.navy4],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AC.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                def.titleAr,
                style: TextStyle(
                  color: AC.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (confidence != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: highConfidence ? AC.ok : AC.warn,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: TextStyle(
              color: AC.tp,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            textDirection: TextDirection.rtl,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final a in alerts.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 14, color: AC.warn),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (a['title_ar'] ?? a['message'] ?? '').toString(),
                        style: TextStyle(color: AC.ts, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (generatedAt != null)
                Text(
                  generatedAt,
                  style: TextStyle(color: AC.td, fontSize: 10),
                ),
              const Spacer(),
              _RefreshAction(
                code: def.code,
                refresher: refresher,
                onRefreshed: onRefreshed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefreshAction extends StatefulWidget {
  final String code;
  final WidgetRefresher? refresher;
  final void Function(String code, Map<String, dynamic> payload)? onRefreshed;

  const _RefreshAction({
    required this.code,
    required this.refresher,
    required this.onRefreshed,
  });

  @override
  State<_RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends State<_RefreshAction> {
  bool _busy = false;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      Map<String, dynamic>? payload;
      if (widget.refresher != null) {
        payload = await widget.refresher!(widget.code);
      } else {
        final res = await ApiService.dashboardWidgetData(widget.code);
        if (res.success && res.data is Map) {
          payload = (res.data as Map).cast<String, dynamic>();
        }
      }
      if (payload != null && widget.onRefreshed != null) {
        widget.onRefreshed!(widget.code, payload);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _refresh,
      icon: _busy
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AC.gold),
            )
          : Icon(Icons.refresh, size: 14, color: AC.gold),
      label: Text(
        _busy ? 'جارٍ التحديث…' : 'تحديث',
        style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
