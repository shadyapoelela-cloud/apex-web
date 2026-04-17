/// APEX Recently Visited — Odoo-style "last 5 items" rail.
///
/// The router doesn't know what entity you just opened, so screens opt in
/// by calling `ApexRecentItems.record(...)` on mount. Entries are deduped
/// by route+id and capped at [_maxItems]. Persisted to localStorage so
/// they survive refreshes.
///
/// Renders as a compact vertical list (fits in a 250px sidebar) or a
/// horizontal chip row (for headers). The icon and label are whatever
/// the caller recorded.
library;

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';
import 'theme.dart';

const String _kStoreKey = 'apex_recent_items_v1';
const int _kMaxItems = 5;

class ApexRecentItem {
  final String route;          // GoRouter path to navigate to
  final String label;
  final int iconCodePoint;     // Store IconData as code point for JSON round-trip
  final DateTime openedAt;

  ApexRecentItem({
    required this.route,
    required this.label,
    required this.iconCodePoint,
    required this.openedAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {
        'route': route,
        'label': label,
        'icon': iconCodePoint,
        'at': openedAt.toIso8601String(),
      };

  factory ApexRecentItem.fromJson(Map<String, dynamic> m) => ApexRecentItem(
        route: m['route'] as String,
        label: m['label'] as String,
        iconCodePoint: m['icon'] as int,
        openedAt: DateTime.tryParse(m['at'] as String? ?? '') ??
            DateTime.now().toUtc(),
      );
}

class ApexRecentItems {
  static final ValueNotifier<List<ApexRecentItem>> notifier =
      ValueNotifier(_load());

  /// Call this whenever an entity screen opens (e.g. in `initState`).
  /// Dedupes by route — reopening an item moves it to the top.
  static void record({
    required String route,
    required String label,
    required IconData icon,
  }) {
    final list = List<ApexRecentItem>.from(notifier.value);
    list.removeWhere((e) => e.route == route);
    list.insert(
        0,
        ApexRecentItem(
          route: route,
          label: label,
          iconCodePoint: icon.codePoint,
          openedAt: DateTime.now().toUtc(),
        ));
    final trimmed = list.take(_kMaxItems).toList();
    notifier.value = trimmed;
    _persist(trimmed);
  }

  static void clear() {
    notifier.value = const [];
    html.window.localStorage.remove(_kStoreKey);
  }

  static List<ApexRecentItem> _load() {
    final raw = html.window.localStorage[_kStoreKey];
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(ApexRecentItem.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  static void _persist(List<ApexRecentItem> list) {
    html.window.localStorage[_kStoreKey] =
        jsonEncode(list.map((e) => e.toJson()).toList());
  }
}

/// Compact sidebar widget: title row + up to 5 recent items + "clear".
class ApexRecentRail extends StatelessWidget {
  /// If true, render chips horizontally (for header strips) rather than a
  /// vertical list (sidebar default).
  final bool horizontal;

  const ApexRecentRail({super.key, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ApexRecentItem>>(
      valueListenable: ApexRecentItems.notifier,
      builder: (ctx, items, _) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'سيظهر هنا آخر 5 عناصر فتحتَها',
              style: TextStyle(color: AC.td, fontSize: AppFontSize.xs),
              textAlign: TextAlign.start,
            ),
          );
        }
        if (horizontal) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final it in items) ...[
                  _chip(ctx, it),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: AC.ts),
                  const SizedBox(width: 6),
                  Text('الزيارات الأخيرة',
                      style: TextStyle(
                          color: AC.ts,
                          fontSize: AppFontSize.xs,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  InkWell(
                    onTap: ApexRecentItems.clear,
                    child: Text('مسح',
                        style: TextStyle(
                            color: AC.td, fontSize: AppFontSize.xs)),
                  ),
                ],
              ),
            ),
            for (final it in items) _tile(ctx, it),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext ctx, ApexRecentItem it) {
    return Semantics(
      button: true,
      label: 'فتح ${it.label}',
      child: InkWell(
        onTap: () => GoRouter.of(ctx).go(it.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
          child: Row(
            children: [
              Icon(it.icon, size: 16, color: AC.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(it.label,
                    style:
                        TextStyle(color: AC.tp, fontSize: AppFontSize.sm),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext ctx, ApexRecentItem it) {
    return InkWell(
      onTap: () => GoRouter.of(ctx).go(it.route),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(it.icon, size: 14, color: AC.gold),
          const SizedBox(width: 6),
          Text(it.label,
              style: TextStyle(color: AC.tp, fontSize: AppFontSize.xs)),
        ]),
      ),
    );
  }
}
