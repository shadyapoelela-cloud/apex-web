/// APEX V5.1 — Cmd+K Command Palette (Phase 7).
///
/// Universal search + action launcher — the horizontal layer entry point.
/// Triggered by:
///   - Click on the ⌘K hint in the top bar
///   - Keyboard shortcut Ctrl+K (Cmd+K on Mac)
///
/// Search targets:
///   - Apps (V5MainModules across all services)
///   - Chips (specific screens within apps)
///   - Actions (invoke Copilot, open settings, create record)
///   - Recent items (last visited chips)
///
/// Also hosts the **AI Copilot** input — typing a question routes to the
/// AI Copilot screen with the query pre-filled. Replaces the old Copilot
/// chip in Finance.
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'v5_data.dart';

class CmdKPalette extends StatefulWidget {
  const CmdKPalette({super.key});

  static void show(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: core_theme.AC.ts,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const CmdKPalette(),
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CmdKPalette> createState() => _CmdKPaletteState();
}

class _CmdKPaletteState extends State<CmdKPalette> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  int _highlighted = 0;

  List<_PaletteItem> get _items {
    final query = _ctrl.text.trim().toLowerCase();
    final items = <_PaletteItem>[];

    // 1. Ask AI action (always first when there's text)
    if (query.isNotEmpty) {
      items.add(_PaletteItem(
        kind: _ItemKind.ai,
        label: 'اسأل المساعد الذكي: "${_ctrl.text}"',
        sub: 'يذهب إلى المساعد الذكي مع سؤالك',
        icon: Icons.auto_awesome,
        color: core_theme.AC.gold,
        onSelect: (ctx) {
          Navigator.of(ctx).pop();
          ctx.go('/app/platform/ai/copilot');
        },
      ));
    }

    // 2. Apps (main modules)
    for (final svc in v5Services) {
      for (final app in svc.mainModules) {
        final match = query.isEmpty ||
            app.labelAr.toLowerCase().contains(query) ||
            app.labelEn.toLowerCase().contains(query) ||
            app.id.toLowerCase().contains(query);
        if (match) {
          items.add(_PaletteItem(
            kind: _ItemKind.app,
            label: '${svc.labelAr} › ${app.labelAr}',
            sub: '${app.chips.length} شاشة · ${app.labelEn}',
            icon: app.icon,
            color: svc.color,
            onSelect: (ctx) {
              Navigator.of(ctx).pop();
              ctx.go('/app/${svc.id}/${app.id}');
            },
          ));
        }
      }
    }

    // 3. Chips
    for (final svc in v5Services) {
      for (final app in svc.mainModules) {
        for (final chip in app.chips) {
          if (chip.isDashboard) continue;
          final match = query.isNotEmpty &&
              (chip.labelAr.toLowerCase().contains(query) ||
                  chip.labelEn.toLowerCase().contains(query));
          if (match) {
            items.add(_PaletteItem(
              kind: _ItemKind.chip,
              label: '${app.labelAr} › ${chip.labelAr}',
              sub: chip.labelEn,
              icon: chip.icon,
              color: svc.color,
              onSelect: (ctx) {
                Navigator.of(ctx).pop();
                ctx.go('/app/${svc.id}/${app.id}/${chip.id}');
              },
            ));
          }
        }
      }
    }

    // 4. Global actions (always visible when query is empty)
    if (query.isEmpty) {
      items.addAll([
        _PaletteItem(
          kind: _ItemKind.action,
          label: 'قاعدة المعرفة',
          sub: 'استعرض الأدلة والمراجع',
          icon: Icons.menu_book,
          color: core_theme.AC.info,
          onSelect: (ctx) {
            Navigator.of(ctx).pop();
            ctx.go('/app/erp/reports-bi/knowledge');
          },
        ),
        _PaletteItem(
          kind: _ItemKind.action,
          label: 'التنبيهات',
          sub: 'مركز التنبيهات العام',
          icon: Icons.notifications,
          color: core_theme.AC.warn,
          onSelect: (ctx) {
            Navigator.of(ctx).pop();
            ctx.go('/app/platform/notifications/center');
          },
        ),
        _PaletteItem(
          kind: _ItemKind.action,
          label: 'لوحة وكلاء الذكاء',
          sub: 'AI Agents Gallery',
          icon: Icons.smart_toy,
          color: core_theme.AC.purple,
          onSelect: (ctx) {
            Navigator.of(ctx).pop();
            ctx.go('/app/platform/ai/agents');
          },
        ),
        _PaletteItem(
          kind: _ItemKind.action,
          label: 'إعدادات المنصّة',
          sub: 'Admin Panel',
          icon: Icons.settings,
          color: core_theme.AC.td,
          onSelect: (ctx) {
            Navigator.of(ctx).pop();
            ctx.go('/app/platform/admin/settings');
          },
        ),
      ]);
    }

    return items.take(30).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final items = _items;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlighted = (_highlighted + 1) % items.length);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlighted = (_highlighted - 1 + items.length) % items.length);
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (items.isNotEmpty) {
        items[_highlighted].onSelect(context);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_highlighted >= items.length) _highlighted = 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: const Alignment(0, -0.5),
        child: Material(
          color: Colors.transparent,
          child: KeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKeyEvent: _handleKey,
            child: Container(
              width: 640,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: core_theme.AC.tp.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: core_theme.AC.bdr)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: core_theme.AC.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'اكتب للبحث أو اسأل المساعد الذكي...',
                              hintStyle: TextStyle(color: core_theme.AC.td),
                            ),
                            style: const TextStyle(fontSize: 16),
                            onChanged: (_) => setState(() => _highlighted = 0),
                            onSubmitted: (_) {
                              if (items.isNotEmpty) items[_highlighted].onSelect(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: core_theme.AC.navy3,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: core_theme.AC.bdr),
                          ),
                          child: Text('ESC',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: core_theme.AC.ts)),
                        ),
                      ],
                    ),
                  ),
                  // Items
                  Flexible(
                    child: items.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا توجد نتائج', style: TextStyle(color: core_theme.AC.td)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (ctx, i) {
                              final item = items[i];
                              final highlighted = i == _highlighted;
                              return MouseRegion(
                                onEnter: (_) => setState(() => _highlighted = i),
                                child: InkWell(
                                  onTap: () => item.onSelect(context),
                                  child: Container(
                                    color: highlighted
                                        ? core_theme.AC.gold.withOpacity(0.08)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: item.color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(item.icon, size: 16, color: item.color),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.label,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                              Text(item.sub,
                                                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.color.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _kindLabel(item.kind),
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: item.color),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: core_theme.AC.navy3,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      border: Border(top: BorderSide(color: core_theme.AC.bdr)),
                    ),
                    child: Row(
                      children: [
                        _KeyHint(keys: ['↑', '↓'], label: 'تنقّل'),
                        SizedBox(width: 14),
                        _KeyHint(keys: ['Enter'], label: 'فتح'),
                        SizedBox(width: 14),
                        _KeyHint(keys: ['Esc'], label: 'إغلاق'),
                        Spacer(),
                        Text('APEX Command Palette',
                            style: TextStyle(fontSize: 10, color: core_theme.AC.td, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(_ItemKind kind) {
    switch (kind) {
      case _ItemKind.ai:
        return 'AI';
      case _ItemKind.app:
        return 'تطبيق';
      case _ItemKind.chip:
        return 'شاشة';
      case _ItemKind.action:
        return 'إجراء';
    }
  }
}

enum _ItemKind { ai, app, chip, action }

class _PaletteItem {
  final _ItemKind kind;
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final void Function(BuildContext) onSelect;
  const _PaletteItem({
    required this.kind,
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onSelect,
  });
}

class _KeyHint extends StatelessWidget {
  final List<String> keys;
  final String label;
  const _KeyHint({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: core_theme.AC.bdr),
            ),
            child: Text(k, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: core_theme.AC.ts)),
          ),
          const SizedBox(width: 2),
        ],
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ],
    );
  }
}
