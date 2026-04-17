/// APEX Sticky Toolbar — pinned action bar for list and form screens.
///
/// Sources: Odoo 19 sticky status bar, SAP Fiori footer bar in edit mode,
/// Pennylane top action toolbar.
///
/// Two primary usages:
///   1. ApexStickyToolbar([...actions...]) — inside a Column.
///   2. Wrapped in SliverPersistentHeader to stick on scroll (see
///      ApexStickyToolbarSliver below).
library;

import 'package:flutter/material.dart';
import 'apex_notification_bell_live.dart';
import 'design_tokens.dart';
import 'session.dart';
import 'theme.dart';

/// Primary action button descriptor for the toolbar.
class ApexToolbarAction {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  const ApexToolbarAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.destructive = false,
  });
}

class ApexStickyToolbar extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final List<ApexToolbarAction> actions;
  final List<Widget>? breadcrumb;
  final double height;

  /// Show the global ApexNotificationBellLive before the action list.
  /// Defaults to true — every screen gets the live bell for free.
  /// Opt out by passing `showBell: false` on admin / onboarding
  /// screens where the bell would be visual noise.
  final bool showBell;

  const ApexStickyToolbar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.breadcrumb,
    this.height = 56,
    this.showBell = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.navy4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
          if (breadcrumb != null && breadcrumb!.isNotEmpty)
            _BreadcrumbRow(items: breadcrumb!)
          else if (title != null)
            Text(
              title!,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          if (showBell) ...[
            _GlobalBell(),
            const SizedBox(width: AppSpacing.sm),
          ],
          for (final a in actions) ...[
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(action: a),
          ],
        ],
      ),
    );
  }
}

/// Inlined here (not a separate import) to avoid a circular dependency
/// between apex_sticky_toolbar ↔ apex_notification_bell_live. Just a
/// lookup of the current user + a passthrough to the live bell.
class _GlobalBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Resolve the user id lazily from Session so unauthenticated
    // screens (login, register) still render the toolbar without
    // crashing on a null user.
    final uid = S.uid;
    if (uid == null || uid.isEmpty) {
      return const SizedBox.shrink();
    }
    return ApexNotificationBellLive(userId: uid);
  }
}

class _ActionButton extends StatelessWidget {
  final ApexToolbarAction action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final bg = action.destructive
        ? AC.err
        : action.primary
            ? AC.gold
            : Colors.transparent;
    final fg = action.destructive || action.primary
        ? AC.navy
        : AC.tp;
    final border = (!action.primary && !action.destructive)
        ? Border.all(color: AC.navy4)
        : null;

    return InkWell(
      onTap: action.onPressed,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              action.label,
              style: TextStyle(
                color: fg,
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbRow extends StatelessWidget {
  final List<Widget> items;
  const _BreadcrumbRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(Icons.chevron_left, size: 14, color: AC.td),
        ));
      }
      children.add(items[i]);
    }
    return Row(children: children);
  }
}

/// Slim contextual bar that appears when items are selected in a list.
class ApexContextualActions extends StatelessWidget {
  final int count;
  final List<ApexToolbarAction> actions;
  final VoidCallback? onCancel;

  const ApexContextualActions({
    super.key,
    required this.count,
    required this.actions,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.fast,
      height: 48,
      color: AC.gold.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Text(
            '$count عنصر محدد',
            style: TextStyle(
              color: AC.tp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          for (final a in actions) ...[
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(action: a),
          ],
          if (onCancel != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(
              action: ApexToolbarAction(
                label: 'إلغاء',
                icon: Icons.close,
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
