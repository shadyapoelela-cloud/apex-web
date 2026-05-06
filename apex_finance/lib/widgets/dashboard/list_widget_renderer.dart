/// List renderer — vertical ListTiles with optional tap routes.
///
/// Payload shapes accepted:
/// ```
/// {
///   "items": [
///     {"title": "...", "subtitle": "...", "trailing": "...",
///      "icon": "approval", "route": "/app/...", "id": "..."},
///   ]
/// }
/// // or the simpler `rows` shape used by list_pending_approvals etc.:
/// {"rows": [{"title": ..., ...}]}
/// ```
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '_base.dart';

class ListWidgetRenderer implements DashboardWidgetRenderer {
  const ListWidgetRenderer();

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
        titleAr: 'جارٍ تحميل القائمة…',
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

    final raw = (payload['items'] ?? payload['rows'] ?? const []) as List;
    final items = raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    if (items.isEmpty) {
      return renderErrorState(
        context: context,
        titleAr: def.titleAr,
        message: 'لا توجد عناصر',
        onRetry: onRetry,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      padding: const EdgeInsets.all(12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              def.titleAr,
              style: TextStyle(
                color: AC.tp,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AC.bdr.withValues(alpha: 0.4)),
                itemBuilder: (context, i) {
                  final it = items[i];
                  final route = it['route'] as String?;
                  final title = (it['title'] ??
                          it['number'] ??
                          it['name'] ??
                          it['id'] ??
                          '—')
                      .toString();
                  final subtitle = it['subtitle'] != null
                      ? Text(
                          it['subtitle'].toString(),
                          style: TextStyle(color: AC.ts, fontSize: 12),
                        )
                      : null;
                  final trailingValue = it['trailing'] ?? it['total'];
                  final trailing = trailingValue == null
                      ? null
                      : Text(
                          trailingValue.toString(),
                          style: TextStyle(
                            color: AC.gold,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    dense: true,
                    leading: Icon(
                      _resolveIcon(it['icon'] as String?),
                      color: AC.iconAccent,
                      size: 18,
                    ),
                    title: Text(
                      title,
                      style: TextStyle(color: AC.tp, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: subtitle,
                    trailing: trailing,
                    onTap: route == null ? null : () => context.go(route),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _resolveIcon(String? key) {
    switch (key) {
      case 'approval':
        return Icons.fact_check_outlined;
      case 'invoice':
        return Icons.receipt_long;
      case 'customer':
        return Icons.person_outline;
      case 'vendor':
        return Icons.storefront_outlined;
      case 'payment':
        return Icons.payments_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
