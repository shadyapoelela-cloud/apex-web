/// APEX Command Palette (Ctrl+K / Cmd+K)
///
/// Linear-grade universal launcher.
///
/// Features:
///   - Fuzzy search (Arabic-aware: strips diacritics, unifies hamza)
///   - Grouped sections: Navigation, Actions, Recent
///   - Keyboard navigation: ↑ ↓ Enter Escape
///   - Recent items persisted via SharedPreferences (last 5)
///   - Opens with scale+fade animation (180ms)
///
/// Usage:
/// ```dart
/// ApexCommandPaletteOverlay.of(context).open([
///   ApexCommand.action(id: 'new_invoice', label: 'فاتورة جديدة', onRun: …),
///   ApexCommand.navigation(id: 'dashboard', label: 'لوحة التحكم', path: '/'),
/// ]);
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_tokens.dart';
import 'theme.dart';

enum ApexCommandKind { action, navigation, search }

class ApexCommand {
  final String id;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final ApexCommandKind kind;
  final String? shortcut;
  final void Function(BuildContext) onRun;

  const ApexCommand({
    required this.id,
    required this.label,
    required this.onRun,
    this.subtitle,
    this.icon,
    this.kind = ApexCommandKind.action,
    this.shortcut,
  });

  factory ApexCommand.action({
    required String id,
    required String label,
    required void Function(BuildContext) onRun,
    IconData? icon,
    String? shortcut,
    String? subtitle,
  }) =>
      ApexCommand(
        id: id,
        label: label,
        onRun: onRun,
        icon: icon ?? Icons.bolt,
        shortcut: shortcut,
        subtitle: subtitle,
      );

  factory ApexCommand.navigation({
    required String id,
    required String label,
    required String path,
    IconData? icon,
    String? shortcut,
  }) =>
      ApexCommand(
        id: id,
        label: label,
        onRun: (ctx) => Navigator.of(ctx).pushNamed(path),
        icon: icon ?? Icons.arrow_forward,
        shortcut: shortcut,
        kind: ApexCommandKind.navigation,
      );
}

/// Strips Arabic diacritics and unifies hamza/alif variants for fuzzy matching.
String normalizeArabic(String s) {
  var out = s.toLowerCase();
  // Strip diacritics (Tashkeel)
  out = out.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
  // Unify alif forms
  out = out.replaceAll(RegExp(r'[\u0622\u0623\u0625]'), '\u0627');
  // Unify ya/alif maqsura
  out = out.replaceAll('\u0649', '\u064A');
  // Unify ta marbuta → ha
  out = out.replaceAll('\u0629', '\u0647');
  return out.trim();
}

/// Simple substring + prefix fuzzy score. Higher = better match.
int _fuzzyScore(String needle, String haystack) {
  final n = normalizeArabic(needle);
  final h = normalizeArabic(haystack);
  if (n.isEmpty) return 1;
  if (h == n) return 1000;
  if (h.startsWith(n)) return 500 + (100 - h.length).clamp(0, 100);
  final idx = h.indexOf(n);
  if (idx >= 0) return 200 - idx;
  // Last resort: every character of needle appears in order
  var hi = 0;
  for (final ch in n.runes) {
    final pos = h.indexOf(String.fromCharCode(ch), hi);
    if (pos < 0) return 0;
    hi = pos + 1;
  }
  return 50;
}

class ApexCommandPalette extends StatefulWidget {
  final List<ApexCommand> commands;

  const ApexCommandPalette({super.key, required this.commands});

  @override
  State<ApexCommandPalette> createState() => _ApexCommandPaletteState();
}

class _ApexCommandPaletteState extends State<ApexCommandPalette>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final AnimationController _anim;

  int _selectedIndex = 0;
  List<ApexCommand> _recent = [];
  static const String _recentKey = 'apex_command_palette_recent';
  static const int _maxRecent = 5;

  List<ApexCommand> get _filtered {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      // Show recent first, then everything
      final recentIds = _recent.map((c) => c.id).toSet();
      final rest = widget.commands.where((c) => !recentIds.contains(c.id));
      return [..._recent, ...rest];
    }
    final scored = widget.commands
        .map((c) => (c, _fuzzyScore(q, c.label) + _fuzzyScore(q, c.subtitle ?? '') ~/ 2))
        .where((e) => e.$2 > 0)
        .toList();
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _loadRecent();
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null) return;
    try {
      final ids = (jsonDecode(raw) as List).cast<String>();
      final byId = {for (final c in widget.commands) c.id: c};
      setState(() {
        _recent = ids.map((id) => byId[id]).whereType<ApexCommand>().toList();
      });
    } catch (_) {
      // corrupt — ignore
    }
  }

  Future<void> _pushRecent(ApexCommand c) async {
    final ids = [c.id, ..._recent.where((r) => r.id != c.id).map((r) => r.id)]
        .take(_maxRecent)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentKey, jsonEncode(ids));
  }

  void _run(ApexCommand c) {
    _pushRecent(c);
    Navigator.of(context).pop();
    c.onRun(context);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final results = _filtered;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < results.length) {
        _run(results[_selectedIndex]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    if (_selectedIndex >= results.length) _selectedIndex = 0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.4),
          child: ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: _anim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 640,
                  constraints: const BoxConstraints(maxHeight: 480),
                  decoration: BoxDecoration(
                    color: AC.navy2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AC.navy4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Focus(
                          focusNode: _focus,
                          onKeyEvent: _handleKey,
                          child: TextField(
                            controller: _ctrl,
                            autofocus: true,
                            style: TextStyle(color: AC.tp, fontSize: AppFontSize.lg),
                            onChanged: (_) => setState(() => _selectedIndex = 0),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن إجراء أو انتقل إلى…',
                              hintStyle: TextStyle(color: AC.td),
                              prefixIcon: Icon(Icons.search, color: AC.td),
                              border: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: results.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Text(
                                  'لا توجد نتائج',
                                  style: TextStyle(color: AC.td),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: results.length,
                                itemBuilder: (_, i) {
                                  final c = results[i];
                                  final isRecent = _ctrl.text.isEmpty &&
                                      i < _recent.length;
                                  return _CommandRow(
                                    command: c,
                                    selected: i == _selectedIndex,
                                    recent: isRecent,
                                    onTap: () => _run(c),
                                    onHover: () =>
                                        setState(() => _selectedIndex = i),
                                  );
                                },
                              ),
                      ),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AC.navy3,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(AppRadius.md),
                            bottomRight: Radius.circular(AppRadius.md),
                          ),
                        ),
                        child: Row(
                          children: [
                            _KeyHint(keyLabel: '↑↓', caption: 'تنقّل'),
                            const SizedBox(width: AppSpacing.md),
                            _KeyHint(keyLabel: '↵', caption: 'تنفيذ'),
                            const SizedBox(width: AppSpacing.md),
                            _KeyHint(keyLabel: 'Esc', caption: 'إغلاق'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommandRow extends StatelessWidget {
  final ApexCommand command;
  final bool selected;
  final bool recent;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _CommandRow({
    required this.command,
    required this.selected,
    required this.recent,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          color: selected ? AC.gold.withValues(alpha: 0.15) : null,
          child: Row(
            children: [
              Icon(command.icon ?? Icons.circle_outlined, size: 18, color: AC.ts),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command.label,
                      style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                      ),
                    ),
                    if (command.subtitle != null)
                      Text(
                        command.subtitle!,
                        style: TextStyle(
                          color: AC.td,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                  ],
                ),
              ),
              if (recent)
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AC.navy3,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    'حديث',
                    style: TextStyle(color: AC.td, fontSize: AppFontSize.xs),
                  ),
                ),
              if (command.shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AC.navy3,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: AC.navy4),
                  ),
                  child: Text(
                    command.shortcut!,
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.xs,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String keyLabel;
  final String caption;

  const _KeyHint({required this.keyLabel, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: AC.navy,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: AC.navy4),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              color: AC.ts,
              fontSize: AppFontSize.xs,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(caption, style: TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
      ],
    );
  }
}

/// Opens the command palette as a modal route.
///
/// Typical wiring: listen for Ctrl+K / Cmd+K in main.dart's key handler and
/// call this.
Future<void> showApexCommandPalette(
  BuildContext context, {
  required List<ApexCommand> commands,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => ApexCommandPalette(commands: commands),
    ),
  );
}
