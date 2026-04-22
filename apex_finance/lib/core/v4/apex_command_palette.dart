/// APEX V4 — Command Palette (Wave 2 PR#1).
///
/// Ctrl+K / Cmd+K opens a full-screen overlay that lets the user jump
/// to any V4 screen by typing part of its Arabic or English label.
/// Inspired by Linear, Raycast, and the Pennylane command-first UX.
///
/// Design rules:
/// - Fuzzy match is diacritic-insensitive Arabic (e.g. "فواتير" matches
///   "ٱلفواتير") and case-insensitive English.
/// - Up to 10 results shown; ↑↓ navigates, Enter selects, Esc closes.
/// - "Recent" section shows the last 5 palette picks (in-memory per
///   session for now; per-user persistence is a future follow-up).
/// - Results are grouped by module group with a colored chip so users
///   always see context ("ERP · Sales → Invoices").
///
/// The palette is attached via `ApexCommandPaletteHost` at the top of
/// the V4 shell so every /app/... route inherits the shortcut.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design_tokens.dart';
import '../theme.dart';
import '../theme.dart' as core_theme;
import 'v4_groups.dart';

// ── Session-scoped recent list ────────────────────────────────────────

class _PaletteHistory {
  static final List<ScreenId> _recent = [];
  static const int _cap = 5;

  static void push(ScreenId id) {
    _recent.remove(id);
    _recent.insert(0, id);
    if (_recent.length > _cap) _recent.removeRange(_cap, _recent.length);
  }

  static List<ScreenId> get entries => List.unmodifiable(_recent);
}

// ── Diacritic-insensitive Arabic fold ─────────────────────────────────

String _fold(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    // Strip common Arabic diacritics (Tashkeel + Tatweel).
    if (r >= 0x064B && r <= 0x065F) continue; // harakat
    if (r == 0x0670) continue; // superscript alef
    if (r == 0x0640) continue; // tatweel
    // Normalize alef variants to bare alef.
    if (r == 0x0622 || r == 0x0623 || r == 0x0625) {
      sb.writeCharCode(0x0627);
      continue;
    }
    // Normalize yeh variants.
    if (r == 0x0649) {
      sb.writeCharCode(0x064A);
      continue;
    }
    // Normalize teh marbuta → heh for search comparison.
    if (r == 0x0629) {
      sb.writeCharCode(0x0647);
      continue;
    }
    sb.writeCharCode(r);
  }
  return sb.toString().toLowerCase();
}

// ── Indexed command view ──────────────────────────────────────────────

class _Command {
  final V4ModuleGroup group;
  final V4SubModule subModule;
  final V4Screen screen;
  _Command(this.group, this.subModule, this.screen);

  String get path =>
      '/app/${group.id}/${subModule.id}/${_slug(screen.id)}';

  static String _slug(ScreenId id) {
    final parts = id.split('-');
    return parts.length > 2 ? parts.sublist(2).join('-') : id;
  }
}

List<_Command> _allCommands() {
  final list = <_Command>[];
  for (final g in v4ModuleGroups) {
    for (final s in g.subModules) {
      for (final scr in s.allScreens) {
        list.add(_Command(g, s, scr));
      }
    }
  }
  return list;
}

// ── Host: wraps children + listens for Ctrl+K / Cmd+K ─────────────────

class ApexCommandPaletteHost extends StatefulWidget {
  final Widget child;
  const ApexCommandPaletteHost({super.key, required this.child});

  @override
  State<ApexCommandPaletteHost> createState() =>
      _ApexCommandPaletteHostState();
}

class _ApexCommandPaletteHostState extends State<ApexCommandPaletteHost> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'CommandPaletteHost');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isMetaK = (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        event.logicalKey == LogicalKeyboardKey.keyK;
    if (!isMetaK) return KeyEventResult.ignored;
    showApexCommandPalette(context);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: widget.child,
      );
}

/// Programmatic opener — call from buttons or shortcuts elsewhere.
Future<void> showApexCommandPalette(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: core_theme.AC.tp.withValues(alpha: 0.6),
    transitionDuration: AppDuration.fast,
    pageBuilder: (_, __, ___) => const _CommandPaletteModal(),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

// ── Modal ─────────────────────────────────────────────────────────────

class _CommandPaletteModal extends StatefulWidget {
  const _CommandPaletteModal();

  @override
  State<_CommandPaletteModal> createState() => _CommandPaletteModalState();
}

class _CommandPaletteModalState extends State<_CommandPaletteModal> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _keyFocus = FocusNode();
  late final List<_Command> _all;
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    _all = _allCommands();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  List<_Command> get _filtered {
    final q = _fold(_query.text.trim());
    if (q.isEmpty) {
      // Show recent first, then the first 10 commands overall.
      final recent = _PaletteHistory.entries
          .map((id) => _all.firstWhere(
                (c) => c.screen.id == id,
                orElse: () => _all.first,
              ))
          .toList();
      if (recent.isNotEmpty) return recent;
      return _all.take(10).toList();
    }
    final matches = <_Command>[];
    for (final c in _all) {
      final hay = '${_fold(c.screen.labelAr)} '
          '${c.screen.labelEn.toLowerCase()} '
          '${_fold(c.subModule.labelAr)} '
          '${c.subModule.labelEn.toLowerCase()} '
          '${_fold(c.group.labelAr)} '
          '${c.group.labelEn.toLowerCase()}';
      if (hay.contains(q)) matches.add(c);
      if (matches.length >= 10) break;
    }
    return matches;
  }

  void _runCommand(_Command c) {
    _PaletteHistory.push(c.screen.id);
    Navigator.of(context).pop();
    context.go(c.path);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final results = _filtered;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlight = (_highlight + 1).clamp(0, results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlight = (_highlight - 1).clamp(0, results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (results.isNotEmpty) {
        _runCommand(results[_highlight.clamp(0, results.length - 1)]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    if (_highlight >= results.length) _highlight = 0;

    return Align(
      alignment: const Alignment(0, -0.4),
      child: Focus(
        focusNode: _keyFocus,
        onKeyEvent: _onKey,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 520),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AC.navy2,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AC.navy3, width: 1),
              boxShadow: [
                BoxShadow(
                  color: core_theme.AC.tp.withValues(alpha: 0.45),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QueryField(
                  controller: _query,
                  focusNode: _queryFocus,
                  onChanged: (_) => setState(() => _highlight = 0),
                ),
                const Divider(height: 1, thickness: 1),
                if (results.isEmpty)
                  const _NoResults()
                else
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (ctx, i) => _ResultRow(
                        command: results[i],
                        highlighted: i == _highlight,
                        showRecentBadge: _query.text.isEmpty &&
                            _PaletteHistory.entries.isNotEmpty,
                        onHover: () => setState(() => _highlight = i),
                        onTap: () => _runCommand(results[i]),
                      ),
                    ),
                  ),
                _FooterHints(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueryField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _QueryField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AC.ts, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.lg,
                ),
                cursorColor: AC.gold,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'اكتب للبحث عن شاشة، وحدة، أو إجراء...',
                  hintStyle: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.lg,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                'Esc',
                style: TextStyle(
                  color: AC.ts,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
}

class _ResultRow extends StatelessWidget {
  final _Command command;
  final bool highlighted;
  final bool showRecentBadge;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _ResultRow({
    required this.command,
    required this.highlighted,
    required this.showRecentBadge,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = command;
    return MouseRegion(
      onEnter: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          color: highlighted
              ? c.group.color.withValues(alpha: 0.14)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.group.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(c.screen.icon, color: c.group.color, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.screen.labelAr,
                      style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.group.labelAr} · ${c.subModule.labelAr}',
                      style: TextStyle(
                        color: AC.ts,
                        fontSize: AppFontSize.sm,
                      ),
                    ),
                  ],
                ),
              ),
              if (showRecentBadge)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AC.navy3,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    'حديثًا',
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.xs,
                    ),
                  ),
                ),
              if (highlighted) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.keyboard_return, color: AC.ts, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Icon(Icons.search_off, color: AC.ts, size: 42),
            const SizedBox(height: AppSpacing.md),
            Text(
              'لا نتائج مطابقة',
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.base,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'جرّب كلمات أقل تخصصًا أو بالإنجليزية.',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
          ],
        ),
      );
}

class _FooterHints extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AC.navy3)),
          color: AC.navy,
        ),
        child: Row(
          children: [
            _kbdHint('↑↓', 'تنقل'),
            const SizedBox(width: AppSpacing.lg),
            _kbdHint('Enter', 'فتح'),
            const Spacer(),
            _kbdHint('Ctrl+K', 'فتح القائمة'),
          ],
        ),
      );

  Widget _kbdHint(String key, String label) => Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              key,
              style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.xs,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
        ],
      );
}
