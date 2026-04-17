/// APEX Preview Panel — right-side drawer for record previews.
///
/// Source: Xero right-hand preview panel + Gmail reading pane + SAP Fiori
/// flexible column layout. Lets users click a row in a list and see the
/// full record inline, without navigating away.
///
/// Usage:
/// ```dart
/// Row(children: [
///   Expanded(child: MyListView(onRowTap: (row) {
///     setState(() => _previewed = row);
///   })),
///   if (_previewed != null)
///     ApexPreviewPanel(
///       title: _previewed!.title,
///       subtitle: _previewed!.number,
///       actions: [
///         ApexToolbarAction(label: 'فتح', icon: Icons.open_in_new, onPressed: ...),
///         ApexToolbarAction(label: 'إغلاق', icon: Icons.close,
///                           onPressed: () => setState(() => _previewed = null)),
///       ],
///       children: [...],
///     ),
/// ])
/// ```
library;

import 'package:flutter/material.dart';

import 'apex_sticky_toolbar.dart';
import 'design_tokens.dart';
import 'theme.dart';

class ApexPreviewPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? statusBadge;
  final List<ApexToolbarAction> actions;
  final List<Widget> children;
  final double width;
  final VoidCallback? onClose;

  const ApexPreviewPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.statusBadge,
    this.actions = const [],
    required this.children,
    this.width = 400,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.medium,
      width: width,
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(left: BorderSide(color: AC.navy4, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const Divider(height: 1),
          if (actions.isNotEmpty) _actionStrip(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
                  ),
                ],
                if (statusBadge != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  statusBadge!,
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AC.ts),
            onPressed: onClose,
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  Widget _actionStrip(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border(bottom: BorderSide(color: AC.navy4)),
      ),
      child: Row(
        children: actions
            .expand<Widget>((a) => [
                  TextButton.icon(
                    icon: Icon(a.icon, size: 16),
                    label: Text(a.label),
                    style: TextButton.styleFrom(
                      foregroundColor: a.destructive
                          ? AC.err
                          : a.primary
                              ? AC.gold
                              : AC.tp,
                    ),
                    onPressed: a.onPressed,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

/// Simple row for a preview panel — label on the right (RTL), value on left.
class ApexPreviewRow extends StatelessWidget {
  final String label;
  final Widget value;
  const ApexPreviewRow({super.key, required this.label, required this.value});

  factory ApexPreviewRow.text(String label, String value) {
    return ApexPreviewRow(
      label: label,
      value: Text(value, style: TextStyle(color: AC.tp)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}
