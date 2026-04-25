/// APEX — Unified Page Header
/// ═══════════════════════════════════════════════════════════════════════
/// Per blueprint §2: every page has the same header anatomy:
///   [back] Title (H1)        [filter][⋮][primaryCta]
///         Subtitle/breadcrumb
///   ───────────────────────────────────────
///   [Tab1] [Tab2] [Tab3]
///
/// Replaces ad-hoc AppBar implementations across 80+ screens.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'apex_list_shell.dart' show ApexCta;
import 'theme.dart';

class ApexPageTab {
  final String label;
  final IconData? icon;
  final int? count;
  const ApexPageTab({required this.label, this.icon, this.count});
}

class ApexPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;
  final ApexCta? primaryCta;
  final List<ApexPageTab>? tabs;
  final TabController? tabController;
  final IconData? leadingIcon;

  const ApexPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.actions = const [],
    this.primaryCta,
    this.tabs,
    this.tabController,
    this.leadingIcon,
  });

  @override
  Size get preferredSize => Size.fromHeight(tabs != null ? 110 : 56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AC.navy2,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_forward, color: AC.gold),
              onPressed: () => Navigator.of(context).maybePop()
                  .then((didPop) {
                if (!didPop && context.mounted) {
                  GoRouter.of(context).go('/today');
                }
              }),
            )
          : (leadingIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Icon(leadingIcon, color: AC.gold),
                )),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: TextStyle(
                  color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(color: AC.ts, fontSize: 11.5)),
        ],
      ),
      actions: [
        ...actions,
        if (primaryCta != null) _ctaButton(primaryCta!),
        const SizedBox(width: 8),
      ],
      bottom: tabs == null
          ? null
          : TabBar(
              controller: tabController,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              isScrollable: tabs!.length > 4,
              tabs: tabs!.map((t) {
                return Tab(
                  icon: t.icon == null ? null : Icon(t.icon, size: 16),
                  text: t.count == null ? t.label : '${t.label} · ${t.count}',
                );
              }).toList(),
            ),
    );
  }

  Widget _ctaButton(ApexCta cta) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: cta.loading
          ? Container(
              width: 36,
              alignment: Alignment.center,
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AC.gold)),
            )
          : ElevatedButton.icon(
              onPressed: cta.onPressed,
              icon: cta.icon == null ? const SizedBox.shrink() : Icon(cta.icon, size: 16),
              label: Text(cta.label),
              style: ElevatedButton.styleFrom(
                backgroundColor: cta.destructive ? AC.err : AC.gold,
                foregroundColor: cta.destructive ? Colors.white : AC.navy,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
    );
  }
}
