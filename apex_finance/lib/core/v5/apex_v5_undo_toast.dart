/// APEX V5.1 — Undo Everywhere (Enhancement #7).
///
/// Inspired by Superhuman + Linear.
/// Global toast service — any action can show "تم · [تراجع]"
/// with Ctrl+Z / Cmd+Z keyboard shortcut.
///
/// Usage in production:
///   ApexUndoToast.show(
///     context,
///     messageAr: 'تم ترحيل القيد JE-4521',
///     onUndo: () => await api.reverseJournalEntry('JE-4521'),
///   );
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;
import 'package:flutter/services.dart';

class ApexV5UndoToast {
  /// Show a toast with an optional undo action. Auto-dismisses after
  /// [duration]. Returns the ScaffoldMessengerState for chaining.
  static void show(
    BuildContext context, {
    required String messageAr,
    VoidCallback? onUndo,
    Duration duration = const Duration(seconds: 6),
    IconData icon = Icons.check_circle_outline,
    Color? color,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final snackColor = color ?? const Color(0xFF1F2937);

    // Track the undo callback so Cmd+Z can invoke it.
    _currentUndo = onUndo;
    Timer(duration, () => _currentUndo = null);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: snackColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                messageAr,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        action: onUndo != null
            ? SnackBarAction(
                label: 'تراجع',
                textColor: core_theme.AC.warn,
                onPressed: () {
                  _currentUndo = null;
                  onUndo();
                },
              )
            : null,
      ),
    );
  }

  /// The currently-active undo callback (invoked by Cmd+Z/Ctrl+Z).
  static VoidCallback? _currentUndo;
  static VoidCallback? get currentUndo => _currentUndo;

  /// Trigger the current undo (called by the global keyboard shortcut).
  /// Returns true if an undo was available and was invoked.
  static bool triggerUndo() {
    final cb = _currentUndo;
    if (cb == null) return false;
    _currentUndo = null;
    cb();
    return true;
  }
}

/// Global keyboard listener that maps Cmd+Z / Ctrl+Z → ApexV5UndoToast.
/// Wrap your MaterialApp body with this widget.
class ApexV5UndoShortcutListener extends StatelessWidget {
  final Widget child;

  const ApexV5UndoShortcutListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Ctrl+Z (Windows/Linux)
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          _handleUndo(context);
        },
        // Cmd+Z (macOS)
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
          _handleUndo(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  void _handleUndo(BuildContext context) {
    final invoked = ApexV5UndoToast.triggerUndo();
    if (!invoked) {
      // Optional: show subtle "nothing to undo" feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 2),
          content: Text('لا توجد عملية قابلة للتراجع'),
          backgroundColor: core_theme.AC.ts,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
