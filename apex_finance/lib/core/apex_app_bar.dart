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

  const ApexAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(_kBarHeight);

  @override
  Widget build(BuildContext context) {
    return ApexStickyToolbar(
      title: title,
      actions: actions,
      leading: leading,
      height: _kBarHeight,
    );
  }
}

const double _kBarHeight = 56;
