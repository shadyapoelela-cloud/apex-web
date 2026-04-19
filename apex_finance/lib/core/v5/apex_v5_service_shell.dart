/// APEX V5.1 — Service Shell (main layout).
///
/// This is the top-level wrapper when the user is inside a service.
/// Structure:
///   ┌────────────────────────────────────────────────────────────┐
///   │ [9-dots] APEX • ERP > Finance    [News Ticker]   [🔔 👤]  │ ← top bar
///   ├───────────┬────────────────────────────────────────────────┤
///   │ ⓘ CFO ▼   │ Chips: [📊 لوحة] | GL | AR | AP | Budgets | ...│ ← chip row
///   │           ├────────────────────────────────────────────────┤
///   │ 📊 Finance│                                                │
///   │ 👥 HR     │                                                │
///   │ 📦 Ops    │   Dashboard widgets / Tabs content             │
///   │ 🏦 Treas. │                                                │
///   └───────────┴────────────────────────────────────────────────┘
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'apex_v5_action_dashboard.dart';
import 'apex_v5_news_ticker.dart';
import 'apex_v5_service_switcher.dart';
import 'apex_v5_workspace_selector.dart';
import 'cmd_k_palette.dart';
import 'entity_scope_selector.dart';
import 'templates/quick_create.dart';
import 'templates/unified_inbox.dart';
import 'v5_models.dart';

class ApexV5ServiceShell extends StatelessWidget {
  final V5Service service;
  final V5MainModule mainModule;
  final V5Chip activeChip;

  /// Body builder for non-dashboard chips. If null and chip has a
  /// V4SubModule, defaults to ApexSubModuleShell. If null and no
  /// sub-module, shows "coming soon" host.
  final Widget Function(BuildContext ctx, V5Chip chip)? chipBodyBuilder;

  const ApexV5ServiceShell({
    super.key,
    required this.service,
    required this.mainModule,
    required this.activeChip,
    this.chipBodyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          CmdKPalette.show(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          CmdKPalette.show(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              // ── Top Bar ──────────────────────────────────────────────
              _TopBar(service: service, mainModule: mainModule, activeChip: activeChip),
          const ApexV5NewsTicker(),
          const Divider(height: 1),
          // ── Body: Sidebar + Content ──────────────────────────────
          Expanded(
            child: Row(
              children: [
                if (!isNarrow)
                  _Sidebar(service: service, activeMainId: mainModule.id),
                if (!isNarrow) const VerticalDivider(width: 1),
                // Content column
                Expanded(
                  child: Column(
                    children: [
                      _ChipRow(
                        service: service,
                        mainModule: mainModule,
                        activeChipId: activeChip.id,
                      ),
                      const Divider(height: 1),
                      Expanded(child: _buildChipBody(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
          drawer: isNarrow
              ? Drawer(
                  child: _Sidebar(service: service, activeMainId: mainModule.id),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildChipBody(BuildContext context) {
    // Dashboard chip — render action dashboard
    if (activeChip.isDashboard) {
      if (activeChip.dashboardWidgets == null ||
          activeChip.dashboardWidgets!.isEmpty) {
        return _ComingSoonBanner(
          titleAr: activeChip.labelAr,
          subtitleAr: 'لوحة المعلومات قيد البناء — سترى KPIs حية قريباً',
          icon: Icons.dashboard,
        );
      }
      return ApexV5ActionDashboard(
        titleAr: activeChip.labelAr,
        subtitleAr: '${service.labelAr} · ${mainModule.labelAr}',
        widgets: activeChip.dashboardWidgets!,
      );
    }

    // Caller-provided builder
    if (chipBodyBuilder != null) {
      return chipBodyBuilder!(context, activeChip);
    }

    // V4 sub-module reuse — if chip has sub-module, render existing tabs
    final sub = activeChip.subModule;
    if (sub != null) {
      final firstScreen = sub.visibleTabs.isNotEmpty
          ? sub.visibleTabs.first
          : (sub.overflow.isNotEmpty ? sub.overflow.first : null);
      if (firstScreen != null) {
        // Find V4 group that contains this sub. Search by matching sub.id.
        return _V4SubModuleHost(
          subModule: sub,
          activeScreen: firstScreen,
        );
      }
    }

    // Fallback — coming soon banner
    return _ComingSoonBanner(
      titleAr: activeChip.labelAr,
      subtitleAr: 'هذه الشاشة قيد التطوير',
      icon: activeChip.icon,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Top Bar
// ──────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final V5Service service;
  final V5MainModule mainModule;
  final V5Chip activeChip;

  const _TopBar({
    required this.service,
    required this.mainModule,
    required this.activeChip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          ApexV5ServiceSwitcher(currentServiceId: service.id),
          // APEX logo + service breadcrumb
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/app'),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 20, color: service.color),
                const SizedBox(width: 6),
                const Text(
                  'APEX',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(height: 24, width: 1, color: Colors.black.withOpacity(0.12)),
          const SizedBox(width: 16),
          // Breadcrumb: Service > Main > Chip
          Flexible(
            child: _Breadcrumb(
              parts: [
                _BreadcrumbPart(label: service.labelAr, route: '/app/${service.id}', icon: service.icon, color: service.color),
                _BreadcrumbPart(label: mainModule.labelAr, route: '/app/${service.id}/${mainModule.id}', icon: mainModule.icon),
                _BreadcrumbPart(label: activeChip.labelAr, route: null, icon: activeChip.icon),
              ],
            ),
          ),
          const Spacer(),
          // Quick Create (+ button) — global create palette
          const QuickCreateButton(),
          const SizedBox(width: 10),
          // Entity Scope Selector (Wave 147) — consolidation across entities
          const EntityScopeSelector(),
          const SizedBox(width: 10),
          // Workspace selector
          const ApexV5WorkspaceSelector(),
          const SizedBox(width: 8),
          // Command Palette hint button (opens on click or Ctrl+K)
          Builder(
            builder: (ctx) => InkWell(
              onTap: () => CmdKPalette.show(ctx),
              borderRadius: BorderRadius.circular(6),
              child: _CmdKHint(),
            ),
          ),
          const SizedBox(width: 4),
          // Knowledge base search (horizontal layer)
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'قاعدة المعرفة',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () => ctx.go('/app/erp/reports-bi/knowledge'),
            ),
          ),
          // Cog icon (per-app settings)
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'إعدادات ${mainModule.labelAr}',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showAppSettings(ctx, service, mainModule),
            ),
          ),
          // Unified Inbox (bell icon — replaces notifications)
          Builder(
            builder: (ctx) => Stack(
              children: [
                IconButton(
                  tooltip: 'صندوق الوارد',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => UnifiedInbox.show(ctx),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      '8',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Avatar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: service.color.withOpacity(0.2),
              child: Icon(Icons.person, color: service.color, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppSettings(BuildContext context, V5Service svc, V5MainModule app) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(app.icon, color: svc.color),
              const SizedBox(width: 10),
              Expanded(child: Text('إعدادات ${app.labelAr}', style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingTile(
                  icon: Icons.tune,
                  title: 'تخصيص الشاشات',
                  sub: 'أظهر/أخفِ الشاشات في هذا التطبيق',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.lock_outline,
                  title: 'الصلاحيات والأدوار',
                  sub: 'من يستطيع الوصول لهذا التطبيق',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'قواعد التنبيه',
                  sub: 'تنبيهات ذكية مبنية على بيانات التطبيق',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.api,
                  title: 'التكامل مع API',
                  sub: 'مفاتيح API وWebhooks للتطبيق',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.import_export,
                  title: 'استيراد / تصدير',
                  sub: 'تصدير البيانات أو استيرادها',
                  onTap: () {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _SettingTile({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15),
        child: Icon(icon, color: const Color(0xFFD4AF37), size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_left, size: 18),
      onTap: onTap,
    );
  }
}

class _CmdKHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          const Text(
            'بحث',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.black.withOpacity(0.15)),
            ),
            child: const Text(
              '⌘K',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbPart {
  final String label;
  final String? route;
  final IconData icon;
  final Color? color;

  _BreadcrumbPart({
    required this.label,
    required this.route,
    required this.icon,
    this.color,
  });
}

class _Breadcrumb extends StatelessWidget {
  final List<_BreadcrumbPart> parts;

  const _Breadcrumb({required this.parts});

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      final p = parts[i];
      widgets.add(
        GestureDetector(
          onTap: p.route != null ? () => context.go(p.route!) : null,
          child: Row(
            children: [
              Icon(p.icon, size: 15, color: p.color ?? Colors.black54),
              const SizedBox(width: 4),
              Text(
                p.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == parts.length - 1 ? FontWeight.w700 : FontWeight.w500,
                  color: i == parts.length - 1
                      ? Colors.black87
                      : p.route != null
                          ? Colors.black54
                          : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
      if (i != parts.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_left, size: 16, color: Colors.black38),
            // RTL: chevron_left = forward
          ),
        );
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Sidebar — main modules within current service
// ──────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final V5Service service;
  final String activeMainId;

  const _Sidebar({required this.service, required this.activeMainId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: service.color.withOpacity(0.03),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: service.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(service.icon, color: service.color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.labelAr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: service.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          ..._buildGroupedItems(context),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedItems(BuildContext context) {
    // If no apps have a group tag, render flat (old behavior)
    final hasGroups = service.mainModules.any((m) => m.group != null);
    if (!hasGroups) {
      return [
        for (int i = 0; i < service.mainModules.length; i++)
          _SidebarItem(
            mainModule: service.mainModules[i],
            isActive: service.mainModules[i].id == activeMainId,
            shortcutNumber: i + 1,
            serviceColor: service.color,
            onTap: () => context.go('/app/${service.id}/${service.mainModules[i].id}'),
          ),
      ];
    }

    // Grouped rendering — preserves data order within each group
    final widgets = <Widget>[];
    final groups = <AppGroup, List<(int, V5MainModule)>>{};
    final ungrouped = <(int, V5MainModule)>[];

    for (int i = 0; i < service.mainModules.length; i++) {
      final m = service.mainModules[i];
      if (m.group != null) {
        groups.putIfAbsent(m.group!, () => []).add((i, m));
      } else {
        ungrouped.add((i, m));
      }
    }

    // Render in AppGroup enum order
    for (final g in AppGroup.values) {
      final items = groups[g];
      if (items == null || items.isEmpty) continue;
      widgets.add(_groupHeader(g));
      for (final (idx, m) in items) {
        widgets.add(_SidebarItem(
          mainModule: m,
          isActive: m.id == activeMainId,
          shortcutNumber: idx + 1,
          serviceColor: service.color,
          onTap: () => context.go('/app/${service.id}/${m.id}'),
        ));
      }
    }

    // Fallback for any ungrouped items
    if (ungrouped.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      for (final (idx, m) in ungrouped) {
        widgets.add(_SidebarItem(
          mainModule: m,
          isActive: m.id == activeMainId,
          shortcutNumber: idx + 1,
          serviceColor: service.color,
          onTap: () => context.go('/app/${service.id}/${m.id}'),
        ));
      }
    }
    return widgets;
  }

  Widget _groupHeader(AppGroup g) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: g.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(g.icon, size: 12, color: g.color.withOpacity(0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              g.labelAr,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: g.color,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final V5MainModule mainModule;
  final bool isActive;
  final int shortcutNumber;
  final Color serviceColor;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.mainModule,
    required this.isActive,
    required this.shortcutNumber,
    required this.serviceColor,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.serviceColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? color.withOpacity(0.12)
                : _hover
                    ? color.withOpacity(0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(color: color.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.mainModule.icon,
                size: 18,
                color: widget.isActive ? color : Colors.black54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.mainModule.labelAr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isActive ? color : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hover || widget.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Alt+⇧+${widget.shortcutNumber}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
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

// ──────────────────────────────────────────────────────────────────────
// Chip Row — dashboard first + specialized chips
// ──────────────────────────────────────────────────────────────────────

class _ChipRow extends StatefulWidget {
  final V5Service service;
  final V5MainModule mainModule;
  final String activeChipId;

  const _ChipRow({
    required this.service,
    required this.mainModule,
    required this.activeChipId,
  });

  @override
  State<_ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<_ChipRow> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollCtrl.hasClients) return;
    final target = (_scrollCtrl.offset + delta)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  List<Widget> _buildChipItems(BuildContext context) {
    final chips = widget.mainModule.chips;
    // If no chips have phase tags, render flat (old behavior)
    final hasPhases = chips.any((c) => c.phase != null);
    if (!hasPhases) {
      return [
        for (final chip in chips)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ChipItem(
              chip: chip,
              isActive: chip.id == widget.activeChipId,
              serviceColor: widget.service.color,
              onTap: () => context.go('/app/${widget.service.id}/${widget.mainModule.id}/${chip.id}'),
            ),
          ),
      ];
    }

    // Phase-aware rendering with dividers
    final widgets = <Widget>[];
    ChipPhase? lastPhase;
    for (final chip in chips) {
      // Dashboard (first chip) gets no phase divider
      if (!chip.isDashboard && chip.phase != null && chip.phase != lastPhase) {
        widgets.add(_phaseDivider(chip.phase!));
        lastPhase = chip.phase;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _ChipItem(
          chip: chip,
          isActive: chip.id == widget.activeChipId,
          serviceColor: widget.service.color,
          onTap: () => context.go('/app/${widget.service.id}/${widget.mainModule.id}/${chip.id}'),
        ),
      ));
    }
    return widgets;
  }

  Widget _phaseDivider(ChipPhase phase) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: phase.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: phase.color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(phase.icon, size: 10, color: phase.color),
                const SizedBox(width: 4),
                Text(
                  phase.labelAr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: phase.color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      height: 48,
      color: surface,
      child: Row(
        children: [
          // Scroll-left arrow (visual order — works in both LTR/RTL).
          _ScrollArrow(
            icon: Icons.chevron_left,
            onTap: () => _scrollBy(-220),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: _buildChipItems(context),
              ),
            ),
          ),
          _ScrollArrow(
            icon: Icons.chevron_right,
            onTap: () => _scrollBy(220),
          ),
          // "All chips" dropdown — guaranteed way to reach any chip.
          _AllChipsMenu(
            service: widget.service,
            mainModule: widget.mainModule,
            activeChipId: widget.activeChipId,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ScrollArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.black54),
      onPressed: onTap,
      tooltip: 'تمرير',
      splashRadius: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _AllChipsMenu extends StatelessWidget {
  final V5Service service;
  final V5MainModule mainModule;
  final String activeChipId;

  const _AllChipsMenu({
    required this.service,
    required this.mainModule,
    required this.activeChipId,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'كل الشاشات',
      position: PopupMenuPosition.under,
      onSelected: (chipId) => context.go(
        '/app/${service.id}/${mainModule.id}/$chipId',
      ),
      itemBuilder: (ctx) => [
        for (final chip in mainModule.chips)
          PopupMenuItem<String>(
            value: chip.id,
            child: Row(
              children: [
                Icon(
                  chip.icon,
                  size: 16,
                  color: chip.id == activeChipId
                      ? service.color
                      : Colors.black54,
                ),
                const SizedBox(width: 10),
                Text(
                  chip.labelAr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: chip.id == activeChipId
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: chip.id == activeChipId
                        ? service.color
                        : Colors.black87,
                  ),
                ),
                if (chip.id == activeChipId) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 14, color: service.color),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: service.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: service.color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps, size: 14, color: service.color),
            const SizedBox(width: 6),
            Text(
              'كل الشاشات (${mainModule.chips.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: service.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: service.color),
          ],
        ),
      ),
    );
  }
}

class _ChipItem extends StatefulWidget {
  final V5Chip chip;
  final bool isActive;
  final Color serviceColor;
  final VoidCallback onTap;

  const _ChipItem({
    required this.chip,
    required this.isActive,
    required this.serviceColor,
    required this.onTap,
  });

  @override
  State<_ChipItem> createState() => _ChipItemState();
}

class _ChipItemState extends State<_ChipItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.serviceColor;
    final isDashboard = widget.chip.isDashboard;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? (isDashboard ? color.withOpacity(0.16) : Colors.transparent)
                : _hover
                    ? color.withOpacity(0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(isDashboard ? 10 : 6),
            border: widget.isActive && isDashboard
                ? Border.all(color: color.withOpacity(0.4))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.chip.icon,
                size: 14,
                color: widget.isActive ? color : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                widget.chip.labelAr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isActive || isDashboard
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isActive ? color : Colors.black87,
                ),
              ),
              if (widget.isActive && !isDashboard) ...[
                const SizedBox(width: 4),
                Container(
                  height: 3,
                  width: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// V4 sub-module host (reuses the existing tab shell)
// ──────────────────────────────────────────────────────────────────────

class _V4SubModuleHost extends StatelessWidget {
  final dynamic subModule; // V4SubModule
  final dynamic activeScreen; // V4Screen

  const _V4SubModuleHost({required this.subModule, required this.activeScreen});

  @override
  Widget build(BuildContext context) {
    // Placeholder — would wire into ApexSubModuleShell with the right
    // V4ModuleGroup context. For POC, show a clear reuse indicator.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            'إعادة استخدام شاشة V4: ${activeScreen.labelAr}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'هذه البطاقة تربط بـ ${subModule.id} من V4 — لا توجد شاشات مُعاد بناؤها',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Coming-soon banner for chips without content yet
// ──────────────────────────────────────────────────────────────────────

class _ComingSoonBanner extends StatelessWidget {
  final String titleAr;
  final String subtitleAr;
  final IconData icon;

  const _ComingSoonBanner({
    required this.titleAr,
    required this.subtitleAr,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            titleAr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitleAr,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: const Text(
              'قيد البناء',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
