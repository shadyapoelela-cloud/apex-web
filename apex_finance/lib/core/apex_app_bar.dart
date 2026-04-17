/// APEX App Bar — drop-in replacement for Material `AppBar`.
///
/// Wraps `ApexStickyToolbar` in a `PreferredSize` so screens can swap
/// `appBar: AppBar(...)` → `appBar: ApexAppBar(title: '...')` without
/// restructuring their body. That single-line swap gives the screen
/// the APEX look (gold title, action chips, proper RTL) while
/// preserving all existing behaviour underneath.
///
/// Intentionally minimal — for screens that need the full sticky-on-
/// scroll behaviour, fall through to Column + ApexStickyToolbar
/// directly.
library;

import 'package:flutter/material.dart';

import 'apex_sticky_toolbar.dart';

class ApexAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<ApexToolbarAction> actions;

  /// Optional leading widget (e.g. back button). If null, the default
  /// Navigator leading behaviour still works because we extend
  /// PreferredSizeWidget — Flutter auto-injects it.
  final Widget? leading;

  /// Optional secondary bar under the toolbar — typically a TabBar.
  /// Modelled on Material AppBar.bottom to support screens that use
  /// tabs under the header without rebuilding the whole Scaffold.
  final PreferredSizeWidget? bottom;

  const ApexAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize {
    final bottomH = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(_kBarHeight + bottomH);
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = ApexStickyToolbar(
      title: title,
      actions: actions,
      leading: leading,
      height: _kBarHeight,
    );
    if (bottom == null) return toolbar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [toolbar, bottom!],
    );
  }
}

const double _kBarHeight = 56;
