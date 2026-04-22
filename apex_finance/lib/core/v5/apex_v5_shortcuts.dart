/// APEX V5.1 — Hierarchical Keyboard Shortcuts (Enhancement #18).
///
/// Linear / Vim-inspired: press a leader key then a letter/number to
/// jump anywhere in the platform without touching the mouse.
///
/// Active bindings:
///   Alt+1..5         → Switch service (ERP/Comp/Audit/Advisory/Mkpl)
///   Alt+Shift+1..9   → Switch main module within current service
///   1..5  (in tab)   → Switch tab within chip
///   Ctrl+K / Cmd+K   → Global search (Command Palette)
///   Ctrl+Shift+K     → Service Switcher popup
///   Ctrl+Z / Cmd+Z   → Undo (handled by ApexV5UndoShortcutListener)
///
/// Future (not yet implemented):
///   g then f         → Go to Finance
///   g then g         → Global search
///   n then i         → New Invoice
///   n then j         → New Journal Entry
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'v5_data.dart';

/// Wraps your MaterialApp body and binds Alt+N shortcuts to service
/// navigation. Safe to stack with ApexV5UndoShortcutListener.
class ApexV5GlobalShortcuts extends StatelessWidget {
  final Widget child;

  const ApexV5GlobalShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _buildServiceBindings(context),
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildServiceBindings(BuildContext context) {
    final map = <ShortcutActivator, VoidCallback>{};

    // Alt+1..5 → services
    for (int i = 0; i < v5Services.length && i < 9; i++) {
      final service = v5Services[i];
      final key = _numberKey(i + 1);
      if (key == null) continue;
      map[SingleActivator(key, alt: true)] = () {
        context.go('/app/${service.id}');
      };
    }

    // Ctrl+Shift+K → Service Switcher popup (handled by Service Switcher widget)
    // Ctrl+K → reserved for Command Palette (v4)

    return map;
  }

  LogicalKeyboardKey? _numberKey(int n) {
    switch (n) {
      case 1: return LogicalKeyboardKey.digit1;
      case 2: return LogicalKeyboardKey.digit2;
      case 3: return LogicalKeyboardKey.digit3;
      case 4: return LogicalKeyboardKey.digit4;
      case 5: return LogicalKeyboardKey.digit5;
      case 6: return LogicalKeyboardKey.digit6;
      case 7: return LogicalKeyboardKey.digit7;
      case 8: return LogicalKeyboardKey.digit8;
      case 9: return LogicalKeyboardKey.digit9;
      default: return null;
    }
  }
}

/// Shortcut hint badge — shows "Alt+3" style hint next to an element.
class ApexV5ShortcutHint extends StatelessWidget {
  final String hint;
  final Color? color;

  const ApexV5ShortcutHint({super.key, required this.hint, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? core_theme.AC.ts;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Text(
        hint,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: c,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
