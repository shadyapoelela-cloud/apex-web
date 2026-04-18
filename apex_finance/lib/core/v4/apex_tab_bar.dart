/// APEX V4 — Tab bar with overflow popover (Wave 1.5).
///
/// Renders up to five "visible" tabs and funnels the rest into a
/// "More ▾" button. A PopupMenu houses the overflow entries; users
/// can right-click any tab → "Pin to tabs" to promote it (future PR).
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../theme.dart';
import 'v4_groups.dart';

class ApexTabBar extends StatelessWidget {
  final List<V4Screen> screens;
  final List<V4Screen> overflow;
  final ScreenId activeScreenId;
  final Color accentColor;
  final void Function(V4Screen screen) onSelect;

  const ApexTabBar({
    super.key,
    required this.screens,
    required this.overflow,
    required this.activeScreenId,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: AC.navy2,
      border: Border(bottom: BorderSide(color: AC.navy3)),
    ),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: screens
                  .map((s) => _TabItem(
                        screen: s,
                        active: s.id == activeScreenId,
                        accent: accentColor,
                        onTap: () => onSelect(s),
                      ))
                  .toList(),
            ),
          ),
        ),
        if (overflow.isNotEmpty)
          _OverflowButton(
            overflow: overflow,
            accent: accentColor,
            onSelect: onSelect,
            activeScreenId: activeScreenId,
          ),
      ],
    ),
  );
}

class _TabItem extends StatelessWidget {
  final V4Screen screen;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _TabItem({
    required this.screen,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? accent : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Center(
        child: Row(
          children: [
            Icon(
              screen.icon,
              color: active ? accent : AC.ts,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              screen.labelAr,
              style: TextStyle(
                color: active ? AC.tp : AC.ts,
                fontSize: AppFontSize.base,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverflowButton extends StatelessWidget {
  final List<V4Screen> overflow;
  final Color accent;
  final ScreenId activeScreenId;
  final void Function(V4Screen) onSelect;

  const _OverflowButton({
    required this.overflow,
    required this.accent,
    required this.activeScreenId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final activeInOverflow =
        overflow.any((s) => s.id == activeScreenId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: PopupMenuButton<V4Screen>(
        tooltip: 'المزيد من الشاشات',
        color: AC.navy2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AC.navy3),
        ),
        onSelected: onSelect,
        itemBuilder: (ctx) => overflow.map((s) {
          final isActive = s.id == activeScreenId;
          return PopupMenuItem<V4Screen>(
            value: s,
            child: Row(
              children: [
                Icon(
                  s.icon,
                  color: isActive ? accent : AC.ts,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  s.labelAr,
                  style: TextStyle(
                    color: isActive ? AC.tp : AC.ts,
                    fontWeight: isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 4,
          ),
          decoration: BoxDecoration(
            color: activeInOverflow
                ? accent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Text(
                'المزيد',
                style: TextStyle(
                  color: activeInOverflow ? AC.tp : AC.ts,
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.expand_more,
                color: activeInOverflow ? accent : AC.ts,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
