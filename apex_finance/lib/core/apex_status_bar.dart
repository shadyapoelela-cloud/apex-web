/// APEX Status Bar — horizontal workflow pipeline visualiser.
///
/// Source: Odoo 19 status bar ("Draft → Pending → Approved → Paid" chain
/// at top of every form). Makes workflow state obvious and navigable.
///
/// Usage:
/// ```dart
/// ApexStatusBar(
///   steps: [
///     ApexStatusStep(id: 'draft',    label: 'مسودة',    state: ApexStepState.done),
///     ApexStatusStep(id: 'sent',     label: 'مُرسلة',    state: ApexStepState.done),
///     ApexStatusStep(id: 'paid',     label: 'مدفوعة',   state: ApexStepState.current),
///     ApexStatusStep(id: 'archived', label: 'مؤرشفة',   state: ApexStepState.upcoming),
///   ],
///   onStepTap: (step) => _advanceTo(step),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

enum ApexStepState { done, current, upcoming, error }

class ApexStatusStep {
  final String id;
  final String label;
  final ApexStepState state;
  final IconData? icon;

  const ApexStatusStep({
    required this.id,
    required this.label,
    required this.state,
    this.icon,
  });
}

class ApexStatusBar extends StatelessWidget {
  final List<ApexStatusStep> steps;
  final void Function(ApexStatusStep)? onStepTap;

  const ApexStatusBar({
    super.key,
    required this.steps,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.navy4)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isEven) {
            final step = steps[i ~/ 2];
            return _StepPill(
              step: step,
              onTap: onStepTap != null ? () => onStepTap!(step) : null,
            );
          }
          // Connector between pills
          final before = steps[(i - 1) ~/ 2];
          final after = steps[(i + 1) ~/ 2];
          return _Connector(
            active: before.state == ApexStepState.done ||
                after.state == ApexStepState.current ||
                after.state == ApexStepState.done,
          );
        }),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final ApexStatusStep step;
  final VoidCallback? onTap;

  const _StepPill({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();
    final icon = step.icon ?? _defaultIcon();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Text(
              step.label,
              style: TextStyle(
                color: fg,
                fontSize: AppFontSize.md,
                fontWeight: step.state == ApexStepState.current
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _defaultIcon() => switch (step.state) {
        ApexStepState.done => Icons.check_circle,
        ApexStepState.current => Icons.radio_button_checked,
        ApexStepState.upcoming => Icons.radio_button_unchecked,
        ApexStepState.error => Icons.error,
      };

  (Color, Color, Color) _colors() {
    switch (step.state) {
      case ApexStepState.done:
        return (AC.ok.withValues(alpha: 0.15), AC.ok, AC.ok.withValues(alpha: 0.5));
      case ApexStepState.current:
        return (AC.gold.withValues(alpha: 0.2), AC.gold, AC.gold);
      case ApexStepState.upcoming:
        return (AC.navy3, AC.td, AC.navy4);
      case ApexStepState.error:
        return (AC.err.withValues(alpha: 0.15), AC.err, AC.err.withValues(alpha: 0.5));
    }
  }
}

class _Connector extends StatelessWidget {
  final bool active;
  const _Connector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        color: active ? AC.ok.withValues(alpha: 0.5) : AC.navy4,
      ),
    );
  }
}
