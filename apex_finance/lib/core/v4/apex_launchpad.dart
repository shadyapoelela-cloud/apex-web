/// APEX V4 — Launchpad (Wave 1.5).
///
/// Entry point into the 6 module groups. Inspired by SAP Fiori Spaces
/// and Microsoft 365 Launcher. Clicking a card takes the user to that
/// group's sidebar shell (`/app/{group}`).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_tokens.dart';
import '../theme.dart';
import 'v4_groups.dart';

class ApexLaunchpad extends StatelessWidget {
  const ApexLaunchpad({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy,
        elevation: 0,
        title: Text(
          'مرحبًا بك في APEX',
          style: TextStyle(
            color: AC.tp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'اختر مجموعة للبدء',
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.h1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'ست مجموعات وحدات — كل واحدة عالم قائم بذاته.',
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.base,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      // Responsive grid: 3 wide on desktop, 2 on tablet,
                      // 1 on phone.
                      final crossAxis = constraints.maxWidth > 1000
                          ? 3
                          : constraints.maxWidth > 640
                              ? 2
                              : 1;
                      return GridView.count(
                        crossAxisCount: crossAxis,
                        crossAxisSpacing: AppSpacing.lg,
                        mainAxisSpacing: AppSpacing.lg,
                        childAspectRatio: 1.4,
                        children: v4ModuleGroups
                            .map((g) => _GroupCard(group: g))
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final V4ModuleGroup group;
  const _GroupCard({required this.group});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final isEmpty = g.subModules.isEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: isEmpty
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _hovered && !isEmpty
                ? g.color.withValues(alpha: 0.5)
                : AC.navy3,
            width: _hovered && !isEmpty ? 2 : 1,
          ),
          boxShadow: _hovered && !isEmpty
              ? [
                  BoxShadow(
                    color: g.color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: isEmpty
              ? () => _showComingSoon(context, g)
              : () => context.go('/app/${g.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: g.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(g.icon, color: g.color, size: 28),
                    ),
                    const Spacer(),
                    if (isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AC.ts.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          'قريبًا',
                          style: TextStyle(
                            color: AC.ts,
                            fontSize: AppFontSize.xs,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  g.labelAr,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.h3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  g.labelEn,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  g.descriptionAr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.md,
                    height: 1.6,
                  ),
                ),
                if (!isEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        '${g.subModules.length} وحدة فرعية',
                        style: TextStyle(
                          color: g.color,
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_back, color: g.color, size: 18),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, V4ModuleGroup g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text(g.labelAr, style: TextStyle(color: AC.tp)),
        content: Text(
          'هذه المجموعة قيد البناء. الـ sub-modules ستُضاف في موجات لاحقة من الخارطة.',
          style: TextStyle(color: AC.ts, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('موافق', style: TextStyle(color: AC.gold)),
          ),
        ],
      ),
    );
  }
}
