/// APEX V4 — Screen state host (Wave 1.5).
///
/// Every V4 screen wraps its content in ApexScreenHost. The host owns
/// the five canonical states from the V4 improvement list so no screen
/// has to reinvent loading/empty/error/unauthorized UI:
///
///   loading        → skeleton or spinner
///   empty (first)  → first-action CTA with sample-data button
///   empty (filter) → "no results match your filter" with clear button
///   error          → message + retry action
///   unauthorized   → permission explainer + "request access" mailto
///   ready          → renders the passed child
///
/// Using one component for all of them guarantees consistent spacing,
/// typography, and motion across every tab in every sub-module.
library;

import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../theme.dart';

enum ApexScreenState {
  loading,
  emptyFirstTime,
  emptyAfterFilter,
  error,
  unauthorized,
  ready,
}

class ApexScreenHost extends StatelessWidget {
  final ApexScreenState state;

  /// Required when [state] is [ApexScreenState.ready].
  final Widget? child;

  /// Title shown on every non-ready state. Defaults to the screen label
  /// provided by the parent TabBar.
  final String? title;

  /// Short Arabic description shown under the title for all non-ready
  /// states. Should explain WHY the screen is in this state.
  final String? description;

  /// Primary action on the non-ready state. On empty-first-time this
  /// is typically "Create first X"; on error it is "Retry"; on
  /// unauthorized it is "Request access".
  final Widget? primaryAction;

  /// Optional secondary action, e.g. "Clear filters" on empty-filter.
  final Widget? secondaryAction;

  /// Error message body when [state] is error. Separate from
  /// [description] so the description can stay stable ("حدث خطأ") while
  /// the details vary.
  final String? errorDetail;

  const ApexScreenHost({
    super.key,
    required this.state,
    this.child,
    this.title,
    this.description,
    this.primaryAction,
    this.secondaryAction,
    this.errorDetail,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ApexScreenState.ready:
        assert(child != null,
          'ApexScreenHost(state: ready) requires a child.');
        return child!;
      case ApexScreenState.loading:
        return _LoadingShell();
      case ApexScreenState.emptyFirstTime:
        return _EmptyShell(
          icon: Icons.auto_awesome_outlined,
          title: title ?? 'ابدأ من هنا',
          description: description ?? 'لا توجد بيانات بعد — أنشئ أول سجل لتبدأ.',
          primaryAction: primaryAction,
          secondaryAction: secondaryAction,
        );
      case ApexScreenState.emptyAfterFilter:
        return _EmptyShell(
          icon: Icons.filter_alt_off_outlined,
          title: title ?? 'لا نتائج مطابقة',
          description: description ?? 'جرّب توسيع الفلاتر أو تصفيتها.',
          primaryAction: secondaryAction, // "clear filters" is primary here
          secondaryAction: primaryAction,
        );
      case ApexScreenState.error:
        return _ErrorShell(
          title: title ?? 'تعذّر تحميل الشاشة',
          description: description ?? 'حدث خطأ غير متوقع.',
          detail: errorDetail,
          primaryAction: primaryAction,
        );
      case ApexScreenState.unauthorized:
        return _UnauthorizedShell(
          title: title ?? 'لا تملك صلاحية عرض هذه الشاشة',
          description: description ??
            'تواصل مع مدير المنشأة لطلب الصلاحية المناسبة.',
          primaryAction: primaryAction,
        );
    }
  }
}

class _LoadingShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        AppSkeleton(height: 28),
        SizedBox(height: AppSpacing.lg),
        AppSkeleton(height: 16, width: 240),
        SizedBox(height: AppSpacing.xxl),
        AppSkeletonList(rows: 8),
      ],
    ),
  );
}

class _EmptyShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  const _EmptyShell({
    required this.icon,
    required this.title,
    required this.description,
    this.primaryAction,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AC.gold, size: 44),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.h2,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              description,
              style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.base,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
            if (primaryAction != null || secondaryAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (secondaryAction != null) ...[
                    secondaryAction!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (primaryAction != null) primaryAction!,
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ErrorShell extends StatelessWidget {
  final String title;
  final String description;
  final String? detail;
  final Widget? primaryAction;

  const _ErrorShell({
    required this.title,
    required this.description,
    this.detail,
    this.primaryAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AC.err, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.h3,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.base),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AC.err.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AC.err.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  detail!,
                  style: TextStyle(
                    color: AC.ts,
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (primaryAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              primaryAction!,
            ],
          ],
        ),
      ),
    ),
  );
}

class _UnauthorizedShell extends StatelessWidget {
  final String title;
  final String description;
  final Widget? primaryAction;

  const _UnauthorizedShell({
    required this.title,
    required this.description,
    this.primaryAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: AC.ts, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.h3,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              description,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.base, height: 1.7),
              textAlign: TextAlign.center,
            ),
            if (primaryAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              primaryAction!,
            ],
          ],
        ),
      ),
    ),
  );
}
