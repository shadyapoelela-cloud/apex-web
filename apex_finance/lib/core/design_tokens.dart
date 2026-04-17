/// APEX Design Tokens
/// ═══════════════════════════════════════════════════════════════
/// Centralized spacing, radius, and font sizes.
/// Use instead of hardcoded numbers across the app.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

/// Spacing scale (multiples of 4)
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Border radius scale
class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

/// Font sizes
class AppFontSize {
  static const double xs = 10;
  static const double sm = 11;
  static const double md = 12;
  static const double base = 13;
  static const double lg = 14;
  static const double xl = 16;
  static const double h3 = 18;
  static const double h2 = 22;
  static const double h1 = 28;
  static const double display = 34;
}

/// Elevations (shadow depth)
class AppElevation {
  static const double flat = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 6;
  static const double modal = 12;
}

/// Animation durations
class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

// ═══════════════════════════════════════════════════════════════
// Shared widgets built on tokens
// ═══════════════════════════════════════════════════════════════

/// Empty state placeholder with icon + title + subtitle + optional action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AC.ts.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AC.ts, size: 40),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title,
          style: TextStyle(color: AC.tp, fontSize: AppFontSize.xl,
            fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle!,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.md, height: 1.6),
            textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpacing.xl),
          action!,
        ],
      ],
    ),
  );
}

/// Skeleton loader (pulsing placeholder).
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctl,
    builder: (ctx, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AC.navy3.withValues(alpha: 0.4 + _ctl.value * 0.3),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Compact skeleton list (for tables loading).
class AppSkeletonList extends StatelessWidget {
  final int rows;
  final double rowHeight;
  const AppSkeletonList({super.key, this.rows = 5, this.rowHeight = 20});

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(rows, (i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(children: [
        AppSkeleton(width: 40, height: rowHeight),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: AppSkeleton(height: rowHeight)),
        const SizedBox(width: AppSpacing.sm),
        AppSkeleton(width: 80, height: rowHeight),
      ]),
    )),
  );
}

/// Standardized toast (success/error/info/warning).
enum ToastType { success, error, info, warning }

class AppToast {
  static void show(BuildContext ctx, String message, {ToastType type = ToastType.info}) {
    final colors = {
      ToastType.success: AC.ok,
      ToastType.error: AC.err,
      ToastType.info: AC.info,
      ToastType.warning: AC.warn,
    };
    final icons = {
      ToastType.success: Icons.check_circle,
      ToastType.error: Icons.error,
      ToastType.info: Icons.info,
      ToastType.warning: Icons.warning_amber_rounded,
    };
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icons[type], color: Colors.white, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: colors[type],
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ));
  }

  static void success(BuildContext ctx, String msg) =>
    show(ctx, msg, type: ToastType.success);
  static void error(BuildContext ctx, String msg) =>
    show(ctx, msg, type: ToastType.error);
  static void info(BuildContext ctx, String msg) =>
    show(ctx, msg, type: ToastType.info);
  static void warning(BuildContext ctx, String msg) =>
    show(ctx, msg, type: ToastType.warning);
}

/// Confirmation dialog helper.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'تأكيد',
  String cancelText = 'إلغاء',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AC.navy2,
      title: Text(title, style: TextStyle(color: AC.tp)),
      content: Text(message,
        style: TextStyle(color: AC.ts, fontSize: AppFontSize.base, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelText, style: TextStyle(color: AC.ts)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AC.err : AC.gold,
            foregroundColor: destructive ? Colors.white : AC.navy,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  ) ?? false;
}
