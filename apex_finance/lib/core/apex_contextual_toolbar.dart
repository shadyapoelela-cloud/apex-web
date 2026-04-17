/// APEX Contextual Toolbar — SAP Fiori-style action bar that adapts to
/// selection state.
///
/// When the user selects 0 rows the toolbar shows "primary" actions
/// (Create, Import, Export). When N>0 rows are selected it swaps into a
/// bulk-action mode with a selection count, deselect-all, and the
/// bulk actions the caller provided (Delete, Assign, Change status...).
///
/// Designed to sit directly under a page header — use alongside
/// `ApexStickyToolbar` for the sticky-on-scroll behaviour.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

class ApexAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool destructive;

  const ApexAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.destructive = false,
  });
}

class ApexContextualToolbar extends StatelessWidget {
  /// Number of items currently selected. 0 → idle mode.
  final int selectedCount;

  /// Actions shown in idle mode (no selection).
  final List<ApexAction> idleActions;

  /// Actions shown when selectedCount > 0.
  final List<ApexAction> bulkActions;

  /// Called when the user taps "deselect all".
  final VoidCallback? onClearSelection;

  /// Optional leading widget (usually the screen title).
  final Widget? leading;

  const ApexContextualToolbar({
    super.key,
    required this.selectedCount,
    this.idleActions = const [],
    this.bulkActions = const [],
    this.onClearSelection,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final inBulk = selectedCount > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: inBulk ? AC.gold.withValues(alpha: 0.12) : AC.navy2,
        border: Border(
          bottom: BorderSide(
              color: inBulk ? AC.gold : AC.bdr, width: inBulk ? 1.5 : 1),
        ),
      ),
      child: Row(
        children: [
          if (inBulk) ...[
            Semantics(
              button: true,
              label: 'إلغاء التحديد',
              child: IconButton(
                icon: Icon(Icons.close, color: AC.gold, size: 20),
                tooltip: 'إلغاء التحديد',
                onPressed: onClearSelection,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('$selectedCount محدّد',
                style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSize.base)),
          ] else ...[
            if (leading != null) leading!,
          ],
          const Spacer(),
          for (final a in (inBulk ? bulkActions : idleActions)) ...[
            _actionButton(a),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(ApexAction a) {
    final fg = a.destructive ? AC.err : (a.color ?? AC.gold);
    return Semantics(
      button: true,
      label: a.label,
      enabled: a.onPressed != null,
      child: TextButton.icon(
        icon: Icon(a.icon, size: 18, color: fg),
        label: Text(a.label, style: TextStyle(color: fg)),
        onPressed: a.onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: fg.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}
