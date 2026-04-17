/// APEX Entity Breadcrumb — Odoo 18 trail with real record names.
///
/// Unlike a plain path-based crumb ("Home > Clients > Detail"), this one
/// shows the actual entity being viewed ("Home > Clients > شركة الرياض").
/// The screen passes the crumbs it has — the widget handles truncation
/// (with a … overflow menu) on narrow viewports.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';
import 'theme.dart';

class ApexCrumb {
  final String label;
  final String? route;
  final IconData? icon;

  const ApexCrumb({required this.label, this.route, this.icon});
}

class ApexEntityBreadcrumb extends StatelessWidget {
  final List<ApexCrumb> crumbs;

  /// Above this width we show all crumbs; below, we collapse middle ones.
  final double collapseBelow;

  const ApexEntityBreadcrumb({
    super.key,
    required this.crumbs,
    this.collapseBelow = 720,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final collapsed = w < collapseBelow && crumbs.length > 3;
    final displayed = collapsed
        ? [crumbs.first, const ApexCrumb(label: '…'), crumbs.last]
        : crumbs;

    return Semantics(
      container: true,
      label: 'مسار التنقل',
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            for (var i = 0; i < displayed.length; i++) ...[
              _crumb(context, displayed[i], last: i == displayed.length - 1),
              if (i < displayed.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    // Icon flips on RTL thanks to the built-in flip.
                    Icons.chevron_left,
                    size: 16,
                    color: AC.ts,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _crumb(BuildContext ctx, ApexCrumb c, {required bool last}) {
    final color = last ? AC.tp : AC.ts;
    final weight = last ? FontWeight.w700 : FontWeight.w400;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (c.icon != null) ...[
          Icon(c.icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(c.label,
            style: TextStyle(
                color: color, fontSize: AppFontSize.sm, fontWeight: weight),
            overflow: TextOverflow.ellipsis),
      ],
    );

    if (c.route == null || last) return child;
    return InkWell(
      onTap: () => GoRouter.of(ctx).go(c.route!),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: child,
      ),
    );
  }
}
