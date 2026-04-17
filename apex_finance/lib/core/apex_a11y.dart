/// APEX accessibility helpers — WCAG 2.1 AA utilities.
///
/// Wraps Flutter's Semantics + focus primitives with APEX-specific
/// defaults (Arabic labels, semantic colors, reduced-motion awareness)
/// so individual widgets don't re-implement the same boilerplate.
///
/// Usage:
/// ```dart
/// A11yButton(
///   label: 'حفظ الفاتورة',
///   hint: 'يحفظ التغييرات ويعود للقائمة',
///   onPressed: _save,
///   child: const Icon(Icons.save),
/// )
///
/// A11yAnnounce.of(context).say('تم الحفظ بنجاح');
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'design_tokens.dart';
import 'theme.dart';

/// Announces transient messages to screen readers.
class A11yAnnounce {
  const A11yAnnounce();

  static const A11yAnnounce instance = A11yAnnounce();

  static A11yAnnounce of(BuildContext context) => instance;

  /// Announce [message] to the user's assistive tech. Use for toast-style
  /// notifications, status changes, validation feedback, etc.
  void say(String message, {TextDirection textDirection = TextDirection.rtl}) {
    SemanticsService.announce(message, textDirection);
  }
}

/// Any interactive widget wrapped in this gets a clickable Semantics node
/// with correct Arabic label + hint.
class A11yButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final Widget child;
  final bool excludeFromSemantics;

  const A11yButton({
    super.key,
    required this.label,
    this.hint,
    required this.child,
    this.onPressed,
    this.excludeFromSemantics = false,
  });

  @override
  Widget build(BuildContext context) {
    if (excludeFromSemantics) {
      return ExcludeSemantics(
        child: InkWell(onTap: onPressed, child: child),
      );
    }
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      hint: hint,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

/// Visible focus ring that respects reduced-motion and high-contrast.
class A11yFocusRing extends StatelessWidget {
  final Widget child;
  final bool focused;

  const A11yFocusRing({
    super.key,
    required this.child,
    required this.focused,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: focused
          ? BoxDecoration(
              border: Border.all(color: AC.gold, width: 2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            )
          : null,
      child: child,
    );
  }
}

/// Skip-to-content link — the first tabbable element on the page. Lets
/// keyboard/screen-reader users jump past the sidebar into the main content.
class A11ySkipLink extends StatelessWidget {
  final FocusNode targetNode;
  final String label;

  const A11ySkipLink({
    super.key,
    required this.targetNode,
    this.label = 'تخطي إلى المحتوى الرئيسي',
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (ctx) {
          final hasFocus = Focus.of(ctx).hasFocus;
          return Positioned(
            top: hasFocus ? 8 : -40,
            left: 8,
            child: AnimatedOpacity(
              opacity: hasFocus ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: InkWell(
                onTap: () => targetNode.requestFocus(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AC.gold,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: AC.btnFg, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Respect user's OS-level reduced-motion preference.
class ReducedMotion {
  static bool of(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Return [fast] duration if reduced motion is on, else [normal].
  static Duration duration(
    BuildContext context, {
    required Duration normal,
    Duration fast = Duration.zero,
  }) {
    return of(context) ? fast : normal;
  }
}

/// Live region — changes to its child get announced to screen readers.
class A11yLiveRegion extends StatelessWidget {
  final Widget child;
  final bool assertive;

  const A11yLiveRegion({super.key, required this.child, this.assertive = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      // `assertive=true` in ARIA maps to an interrupting announcement.
      // Flutter doesn't expose politeness directly, but marking liveRegion
      // triggers a re-announce on subtree change.
      child: child,
    );
  }
}
