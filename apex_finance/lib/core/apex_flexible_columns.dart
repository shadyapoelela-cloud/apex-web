/// APEX Flexible Column Layout — SAP Fiori-style master-detail-detail.
///
/// Three layout modes, switched by the user or auto-collapsed on smaller
/// viewports:
///
///   • BeginExpanded  : only list (33%)
///   • MidExpanded    : list (33%) + detail (67%)
///   • EndExpanded    : list (25%) + detail (25%) + secondary (50%)
///
/// On mobile, forces BeginExpanded — detail pushes a new route.
///
/// Usage:
/// ```dart
/// ApexFlexibleColumnLayout(
///   list: ClientListView(onSelect: _selectClient),
///   detail: _selectedClient == null
///       ? null
///       : ClientDetailView(_selectedClient),
///   secondary: _selectedInvoice == null
///       ? null
///       : InvoicePreviewView(_selectedInvoice),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'apex_responsive.dart';
import 'design_tokens.dart';
import 'theme.dart';

enum FclMode {
  beginExpanded,
  midExpanded,
  endExpanded,
}

class ApexFlexibleColumnLayout extends StatelessWidget {
  final Widget list;
  final Widget? detail;
  final Widget? secondary;
  final FclMode? mode;       // if null, auto from presence of detail/secondary

  const ApexFlexibleColumnLayout({
    super.key,
    required this.list,
    this.detail,
    this.secondary,
    this.mode,
  });

  FclMode _effectiveMode() {
    if (mode != null) return mode!;
    if (secondary != null) return FclMode.endExpanded;
    if (detail != null) return FclMode.midExpanded;
    return FclMode.beginExpanded;
  }

  @override
  Widget build(BuildContext context) {
    // On mobile, force list-only. Detail navigation is the host screen's
    // responsibility (push a route instead of showing a column).
    if (ApexResponsive.isMobile(context)) {
      return list;
    }

    final m = _effectiveMode();
    switch (m) {
      case FclMode.beginExpanded:
        return list;

      case FclMode.midExpanded:
        return Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.33,
              child: list,
            ),
            _divider(),
            Expanded(child: detail ?? _placeholder('تفاصيل')),
          ],
        );

      case FclMode.endExpanded:
        return Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: list,
            ),
            _divider(),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: detail ?? _placeholder('تفاصيل'),
            ),
            _divider(),
            Expanded(child: secondary ?? _placeholder('ثانوي')),
          ],
        );
    }
  }

  Widget _divider() => Container(width: 1, color: AC.navy4);

  Widget _placeholder(String label) {
    return Builder(
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vertical_split, size: 40, color: AC.td),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                style: TextStyle(color: AC.td, fontSize: AppFontSize.lg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toolbar that lets the user toggle FCL modes.
class ApexFclModeToggle extends StatelessWidget {
  final FclMode mode;
  final ValueChanged<FclMode> onChanged;
  final bool showSecondary;  // whether EndExpanded is available

  const ApexFclModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.showSecondary = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FclMode>(
      segments: [
        ButtonSegment(
          value: FclMode.beginExpanded,
          icon: Icon(Icons.view_list, size: 16),
          label: const Text('قائمة'),
        ),
        ButtonSegment(
          value: FclMode.midExpanded,
          icon: Icon(Icons.vertical_split, size: 16),
          label: const Text('تفاصيل'),
        ),
        if (showSecondary)
          ButtonSegment(
            value: FclMode.endExpanded,
            icon: Icon(Icons.grid_view, size: 16),
            label: const Text('3 أعمدة'),
          ),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
