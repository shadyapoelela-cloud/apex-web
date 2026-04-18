/// APEX V4 — Numeral utilities (Wave 2 PR#2).
///
/// Dual numeral toggle — lets each user choose between Western (0-9)
/// and Eastern Arabic-Indic (٠-٩) digits across all financial output.
///
/// Default is Western. Pattern #203 from APEX_GLOBAL_RESEARCH_210:
/// "Western default للمحاسبة" — accountants consistently prefer Western
/// digits for tabular figures but content and timestamps sometimes
/// look better in Eastern. This component is the toggle + conversion
/// helpers; screens opt in via `ApexNumeral.format()` when rendering.
library;

import 'package:flutter/material.dart';

enum NumeralMode { western, eastern }

class ApexNumerals extends InheritedWidget {
  final NumeralMode mode;
  final VoidCallback? toggle;

  const ApexNumerals({
    super.key,
    required this.mode,
    required super.child,
    this.toggle,
  });

  static NumeralMode modeOf(BuildContext ctx) {
    final w = ctx.dependOnInheritedWidgetOfExactType<ApexNumerals>();
    return w?.mode ?? NumeralMode.western;
  }

  @override
  bool updateShouldNotify(ApexNumerals oldWidget) =>
      oldWidget.mode != mode;
}

// Maps between Western and Eastern-Arabic digits. Non-digit characters
// pass through untouched so numbers like "SAR 12,345.67" stay intact.
const _westernToEastern = {
  '0': '٠',
  '1': '١',
  '2': '٢',
  '3': '٣',
  '4': '٤',
  '5': '٥',
  '6': '٦',
  '7': '٧',
  '8': '٨',
  '9': '٩',
};

const _easternToWestern = {
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};

String toEasternDigits(String s) {
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    sb.write(_westernToEastern[ch] ?? ch);
  }
  return sb.toString();
}

String toWesternDigits(String s) {
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    sb.write(_easternToWestern[ch] ?? ch);
  }
  return sb.toString();
}

class ApexNumeral {
  /// Convert according to the nearest ApexNumerals ancestor.
  /// Falls back to Western when the widget tree has no ApexNumerals host.
  static String format(BuildContext ctx, Object value) {
    final s = value.toString();
    return ApexNumerals.modeOf(ctx) == NumeralMode.eastern
        ? toEasternDigits(s)
        : toWesternDigits(s);
  }
}

/// Stateful host widget that owns the current mode + persists it to
/// SharedPreferences (the caller passes prefs to avoid this module
/// depending on the plugin directly). Intended for the app root.
class ApexNumeralScope extends StatefulWidget {
  final Widget child;
  final NumeralMode initial;
  final ValueChanged<NumeralMode>? onChanged;

  const ApexNumeralScope({
    super.key,
    required this.child,
    this.initial = NumeralMode.western,
    this.onChanged,
  });

  @override
  State<ApexNumeralScope> createState() => _ApexNumeralScopeState();

  /// Flip the numeral mode of the nearest ApexNumeralScope ancestor.
  /// No-op if no scope is in the widget tree (e.g. legacy screens).
  static void toggle(BuildContext ctx) {
    ctx.findAncestorStateOfType<_ApexNumeralScopeState>()?.toggle();
  }
}

class _ApexNumeralScopeState extends State<ApexNumeralScope> {
  late NumeralMode _mode = widget.initial;

  void setMode(NumeralMode m) {
    if (m == _mode) return;
    setState(() => _mode = m);
    widget.onChanged?.call(m);
  }

  void toggle() {
    setMode(_mode == NumeralMode.western
        ? NumeralMode.eastern
        : NumeralMode.western);
  }

  @override
  Widget build(BuildContext context) => ApexNumerals(
        mode: _mode,
        toggle: toggle,
        child: widget.child,
      );
}

/// Small button that flips the numeral mode. Drop into app-bar actions
/// or into a settings screen. Shows the *current* digit variant on the
/// label so the user sees what clicking will switch AWAY from.
class ApexNumeralToggleButton extends StatelessWidget {
  const ApexNumeralToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = ApexNumerals.modeOf(context);
    final isEast = mode == NumeralMode.eastern;
    return Tooltip(
      message: isEast
          ? 'التحويل إلى الأرقام الإنجليزية (0-9)'
          : 'التحويل إلى الأرقام العربية (٠-٩)',
      child: TextButton(
        onPressed: () => ApexNumeralScope.toggle(context),
        child: Text(
          isEast ? '٠١٢٣ → 0123' : '0123 → ٠١٢٣',
          style: const TextStyle(fontSize: 12, letterSpacing: 0.4),
        ),
      ),
    );
  }
}
