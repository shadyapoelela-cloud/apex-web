/// APEX Platform — Hybrid Navigation Sidebar
/// Pennylane + QuickBooks inspired: collapsible RTL, 9 modules, max 2-click depth
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'session.dart' show S;

// ═══════════════════════════════════════════════════════════════
// Data model for sidebar items
// ═══════════════════════════════════════════════════════════════

class SidebarItem {
  final String id;
  final String label;
  final IconData icon;
  final String? route;
  final Map<String, dynamic>? extra;
  final VoidCallback? onTap;
  final bool isGold;

  const SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    this.route,
    this.extra,
    this.onTap,
    this.isGold = false,
  });
}

class SidebarGroup {
  final String id;
  final String label;
  final IconData icon;
  final List<SidebarItem> items;
  final bool initiallyExpanded;

  const SidebarGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
    this.initiallyExpanded = false,
  });
}

// ═══════════════════════════════════════════════════════════════
// Sidebar configuration — 9 module groups + settings pinned
// ═══════════════════════════════════════════════════════════════

List<SidebarGroup> buildSidebarGroups() => [
  SidebarGroup(
    id: 'home', label: '\u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629', icon: Icons.dashboard_rounded,
    initiallyExpanded: true,
    items: [
      SidebarItem(id: 'dashboard', label: '\u0644\u0648\u062d\u0629 \u0627\u0644\u062a\u062d\u0643\u0645', icon: Icons.space_dashboard_rounded, route: '/home'),
      SidebarItem(id: 'copilot', label: 'Apex Copilot', icon: Icons.smart_toy, route: '/copilot', isGold: true),
      SidebarItem(id: 'clients', label: '\u0627\u0644\u0639\u0645\u0644\u0627\u0621', icon: Icons.business_rounded, route: '/clients'),
    ],
  ),
  SidebarGroup(
    id: 'accounting', label: '\u0627\u0644\u0645\u062d\u0627\u0633\u0628\u0629', icon: Icons.account_balance_rounded,
    items: [
      SidebarItem(id: 'coa', label: '\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', icon: Icons.account_tree, route: '/coa-tree'),
      SidebarItem(id: 'tb', label: '\u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', icon: Icons.table_chart, route: '/financial-ops'),
      SidebarItem(id: 'statements', label: '\u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', icon: Icons.receipt_long, route: '/financial-ops'),
      SidebarItem(id: 'analysis', label: '\u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a', icon: Icons.analytics_rounded, route: '/home'),
      SidebarItem(id: 'budget', label: '\u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0648\u0627\u0644\u0641\u0639\u0644\u064a', icon: Icons.compare_arrows, route: '/compliance/budget-actual'),
    ],
  ),
  SidebarGroup(
    id: 'sales', label: '\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a', icon: Icons.point_of_sale_rounded,
    items: [
      SidebarItem(id: 'invoices', label: '\u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631', icon: Icons.description_rounded, route: '/home'),
      SidebarItem(id: 'so', label: '\u0623\u0648\u0627\u0645\u0631 \u0627\u0644\u0628\u064a\u0639', icon: Icons.shopping_cart_checkout, route: '/home'),
      SidebarItem(id: 'service-catalog', label: '\u0643\u062a\u0627\u0644\u0648\u062c \u0627\u0644\u062e\u062f\u0645\u0627\u062a', icon: Icons.storefront, route: '/service-catalog'),
    ],
  ),
  SidebarGroup(
    id: 'purchases', label: '\u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a', icon: Icons.shopping_bag_rounded,
    items: [
      SidebarItem(id: 'po', label: '\u0623\u0648\u0627\u0645\u0631 \u0627\u0644\u0634\u0631\u0627\u0621', icon: Icons.receipt_rounded, route: '/home'),
      SidebarItem(id: 'providers', label: '\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', icon: Icons.work_rounded, route: '/provider-kanban'),
      SidebarItem(id: 'marketplace', label: '\u0633\u0648\u0642 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', icon: Icons.store_rounded, route: '/home'),
    ],
  ),
  SidebarGroup(
    id: 'inventory', label: '\u0627\u0644\u0645\u062e\u0632\u0648\u0646', icon: Icons.inventory_2_rounded,
    items: [
      SidebarItem(id: 'warehouse', label: '\u0627\u0644\u0645\u0633\u062a\u0648\u062f\u0639\u0627\u062a', icon: Icons.warehouse_rounded, route: '/home'),
      SidebarItem(id: 'stock', label: '\u062d\u0631\u0643\u0629 \u0627\u0644\u0645\u062e\u0632\u0648\u0646', icon: Icons.swap_horiz_rounded, route: '/home'),
    ],
  ),
  SidebarGroup(
    id: 'projects', label: '\u0627\u0644\u0645\u0634\u0627\u0631\u064a\u0639', icon: Icons.engineering_rounded,
    items: [
      SidebarItem(id: 'project-list', label: '\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0634\u0627\u0631\u064a\u0639', icon: Icons.folder_special_rounded, route: '/home'),
      SidebarItem(id: 'evm', label: '\u0645\u0624\u0634\u0631\u0627\u062a \u0627\u0644\u0623\u062f\u0627\u0621', icon: Icons.trending_up_rounded, route: '/home'),
    ],
  ),
  SidebarGroup(
    id: 'compliance', label: '\u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644', icon: Icons.verified_user_rounded,
    items: [
      SidebarItem(id: 'tp', label: '\u0627\u0644\u062a\u0633\u0639\u064a\u0631 \u0627\u0644\u062a\u062d\u0648\u064a\u0644\u064a', icon: Icons.compare_arrows_rounded, route: '/compliance/transfer-pricing'),
      SidebarItem(id: 'audit', label: '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0629', icon: Icons.gavel_rounded, route: '/audit-workflow'),
      SidebarItem(id: 'readiness', label: '\u0627\u0644\u062c\u0627\u0647\u0632\u064a\u0629 \u0627\u0644\u062a\u0645\u0648\u064a\u0644\u064a\u0629', icon: Icons.shield_rounded, route: '/home'),
      SidebarItem(id: 'legal', label: '\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a\u0629', icon: Icons.policy_rounded, route: '/legal'),
    ],
  ),
  SidebarGroup(
    id: 'ai', label: '\u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a', icon: Icons.psychology_rounded,
    items: [
      SidebarItem(id: 'kb', label: '\u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', icon: Icons.psychology, route: '/knowledge-brain'),
      SidebarItem(id: 'copilot-ai', label: 'Apex Copilot', icon: Icons.smart_toy, route: '/copilot', isGold: true),
    ],
  ),
  SidebarGroup(
    id: 'reports', label: '\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631', icon: Icons.bar_chart_rounded,
    items: [
      SidebarItem(id: 'reports-main', label: '\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', icon: Icons.assessment_rounded, route: '/home'),
      SidebarItem(id: 'archive', label: '\u0627\u0644\u0623\u0631\u0634\u064a\u0641', icon: Icons.folder_outlined, route: '/archive'),
      SidebarItem(id: 'audit-log', label: '\u0633\u062c\u0644 \u0627\u0644\u0623\u062d\u062f\u0627\u062b', icon: Icons.history_rounded, route: '/admin/audit'),
    ],
  ),
];

// Settings group pinned at bottom
SidebarGroup settingsGroup() => SidebarGroup(
  id: 'settings', label: '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a', icon: Icons.settings_rounded,
  items: [
    SidebarItem(id: 'settings-main', label: '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a', icon: Icons.settings, route: '/settings'),
    SidebarItem(id: 'subscription', label: '\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643', icon: Icons.diamond_outlined, route: '/subscription'),
    SidebarItem(id: 'admin', label: '\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0645\u0646\u0635\u0629', icon: Icons.admin_panel_settings, route: '/admin/reviewer'),
  ],
);

// ═══════════════════════════════════════════════════════════════
// ApexSidebar — Collapsible RTL sidebar widget
// ═══════════════════════════════════════════════════════════════

class ApexSidebar extends StatefulWidget {
  final String? activeItemId;
  final ValueChanged<String>? onItemSelected;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  const ApexSidebar({
    super.key,
    this.activeItemId,
    this.onItemSelected,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<ApexSidebar> createState() => _ApexSidebarState();
}

class _ApexSidebarState extends State<ApexSidebar> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _widthAnim;
  final Set<String> _expanded = {'home'};
  int _hoveredIdx = -1;
  String _hoveredGroupId = '';

  static const double _expandedW = 250;
  static const double _collapsedW = 62;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.collapsed ? 0.0 : 1.0,
    );
    _widthAnim = Tween<double>(begin: _collapsedW, end: _expandedW).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant ApexSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed) {
      widget.collapsed ? _animCtrl.reverse() : _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = buildSidebarGroups();
    final settings = settingsGroup();

    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (ctx, _) {
        final w = _widthAnim.value;
        final isExpanded = w > _collapsedW + 20;

        return Container(
          width: w,
          decoration: BoxDecoration(
            color: AC.navy2,
            border: Border(left: BorderSide(color: AC.bdr.withValues(alpha: 0.2), width: 0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(-2, 0)),
            ],
          ),
          child: Column(children: [
            // ── Collapse toggle ──
            _buildToggleButton(isExpanded),
            Divider(color: AC.bdr.withValues(alpha: 0.3), height: 1),

            // ── Main groups (scrollable) ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  for (final g in groups) ...[
                    if (isExpanded)
                      _buildExpandableGroup(g)
                    else
                      _buildCollapsedGroup(g),
                  ],
                ],
              ),
            ),

            // ── Settings pinned at bottom ──
            Divider(color: AC.bdr.withValues(alpha: 0.3), height: 1),
            if (isExpanded)
              _buildExpandableGroup(settings, pinned: true)
            else
              _buildCollapsedGroup(settings),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  // ── Toggle button ──
  Widget _buildToggleButton(bool isExpanded) {
    return InkWell(
      onTap: widget.onToggleCollapse,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
          children: [
            if (isExpanded) ...[
              Text('APEX', style: TextStyle(
                color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5,
              )),
            ],
            AnimatedRotation(
              turns: isExpanded ? 0.0 : 0.5,
              duration: const Duration(milliseconds: 250),
              child: Icon(Icons.chevron_right_rounded, color: AC.ts, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expanded group with items ──
  Widget _buildExpandableGroup(SidebarGroup group, {bool pinned = false}) {
    final isOpen = _expanded.contains(group.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group header
        InkWell(
          onTap: () => setState(() {
            isOpen ? _expanded.remove(group.id) : _expanded.add(group.id);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: AC.ts, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(group.label, textAlign: TextAlign.right, style: TextStyle(
                  color: AC.gold.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                )),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(group.icon, color: AC.gold.withValues(alpha: 0.6), size: 16),
              ),
            ]),
          ),
        ),

        // Items
        AnimatedCrossFade(
          firstChild: Column(
            children: group.items.map((item) => _buildSidebarItem(item, group.id)).toList(),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  // ── Collapsed group (icon only with tooltip) ──
  Widget _buildCollapsedGroup(SidebarGroup group) {
    final isHovered = _hoveredGroupId == group.id;
    final hasActiveChild = group.items.any((i) => i.id == widget.activeItemId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredGroupId = group.id),
      onExit: (_) => setState(() => _hoveredGroupId = ''),
      child: Tooltip(
        message: group.label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: () {
            // On tap in collapsed mode, expand sidebar and open this group
            widget.onToggleCollapse?.call();
            setState(() => _expanded.add(group.id));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: hasActiveChild
                  ? AC.gold.withValues(alpha: 0.12)
                  : isHovered
                      ? AC.gold.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveChild
                    ? AC.gold.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              group.icon,
              color: hasActiveChild ? AC.gold : (isHovered ? AC.goldLight : AC.ts),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ── Individual sidebar item ──
  Widget _buildSidebarItem(SidebarItem item, String groupId) {
    final isActive = item.id == widget.activeItemId;
    final key = '${groupId}_${item.id}';
    final idx = key.hashCode;
    final isHovered = _hoveredIdx == idx;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIdx = idx),
      onExit: (_) => setState(() => _hoveredIdx = -1),
      child: GestureDetector(
        onTap: () {
          widget.onItemSelected?.call(item.id);
          if (item.route != null) {
            context.go(item.route!, extra: item.extra);
          }
          item.onTap?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? AC.gold.withValues(alpha: 0.10)
                : isHovered
                    ? AC.gold.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? AC.gold.withValues(alpha: 0.25)
                  : isHovered
                      ? AC.gold.withValues(alpha: 0.10)
                      : Colors.transparent,
            ),
          ),
          child: Row(children: [
            // Active indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3, height: 18,
              decoration: BoxDecoration(
                color: isActive ? AC.gold : (isHovered ? AC.gold.withValues(alpha: 0.3) : Colors.transparent),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.label, textAlign: TextAlign.right, style: TextStyle(
                color: item.isGold || isActive ? AC.gold : (isHovered ? AC.goldLight : AC.tp),
                fontSize: 12.5,
                fontWeight: isActive || item.isGold ? FontWeight.w600 : FontWeight.normal,
              )),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: (isActive || isHovered || item.isGold) ? AC.gold.withValues(alpha: 0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(item.icon, color: item.isGold || isActive ? AC.gold : (isHovered ? AC.goldLight : AC.ts), size: 16),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Global Search Overlay (Cmd+K / Ctrl+K)
// ═══════════════════════════════════════════════════════════════

class ApexCommandPalette extends StatefulWidget {
  const ApexCommandPalette({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const ApexCommandPalette(),
    );
  }

  @override
  State<ApexCommandPalette> createState() => _ApexCommandPaletteState();
}

class _ApexCommandPaletteState extends State<ApexCommandPalette> {
  final _ctrl = TextEditingController();
  List<SidebarItem> _results = [];

  List<SidebarItem> get _allItems {
    final all = <SidebarItem>[];
    for (final g in buildSidebarGroups()) {
      all.addAll(g.items);
    }
    all.addAll(settingsGroup().items);
    return all;
  }

  void _search(String q) {
    if (q.isEmpty) {
      setState(() => _results = _allItems.take(8).toList());
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      _results = _allItems
          .where((i) => i.label.toLowerCase().contains(lower) || i.id.toLowerCase().contains(lower))
          .take(10)
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AC.navy2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AC.gold.withValues(alpha: 0.2)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 420),
        child: Column(children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textAlign: TextAlign.right,
              style: TextStyle(color: AC.tp, fontSize: 15),
              decoration: InputDecoration(
                hintText: '\u0628\u062d\u062b \u0633\u0631\u064a\u0639... (Ctrl+K)',
                hintStyle: TextStyle(color: AC.td),
                prefixIcon: Icon(Icons.search, color: AC.gold),
                filled: true, fillColor: AC.navy3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.gold)),
              ),
              onChanged: _search,
            ),
          ),
          Divider(color: AC.bdr, height: 1),
          // Results
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final item = _results[i];
                return ListTile(
                  dense: true,
                  leading: Icon(item.icon, color: item.isGold ? AC.gold : AC.ts, size: 20),
                  title: Text(item.label, textAlign: TextAlign.right, style: TextStyle(color: AC.tp, fontSize: 13)),
                  hoverColor: AC.gold.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    Navigator.pop(context);
                    if (item.route != null) {
                      context.go(item.route!, extra: item.extra);
                    }
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Quick Action FAB ("+ جديد")
// ═══════════════════════════════════════════════════════════════

class ApexQuickActionButton extends StatelessWidget {
  const ApexQuickActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'client': context.push('/clients/create');
          case 'invoice': context.push('/home');
          case 'request': context.push('/marketplace/new-request');
          case 'upload': context.push('/upload');
        }
      },
      offset: const Offset(0, -200),
      color: AC.navy2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AC.gold.withValues(alpha: 0.2))),
      itemBuilder: (_) => [
        _quickItem('client', Icons.person_add_rounded, '\u0639\u0645\u064a\u0644 \u062c\u062f\u064a\u062f'),
        _quickItem('invoice', Icons.receipt_long_rounded, '\u0641\u0627\u062a\u0648\u0631\u0629 \u062c\u062f\u064a\u062f\u0629'),
        _quickItem('request', Icons.add_task_rounded, '\u0637\u0644\u0628 \u062e\u062f\u0645\u0629'),
        _quickItem('upload', Icons.upload_file_rounded, '\u0631\u0641\u0639 \u0645\u0644\u0641'),
      ],
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AC.gold, AC.goldLight]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AC.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.add_rounded, color: AC.btnFg, size: 28),
      ),
    );
  }

  PopupMenuItem<String> _quickItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(label, style: TextStyle(color: AC.tp, fontSize: 13)),
        const SizedBox(width: 10),
        Icon(icon, color: AC.gold, size: 18),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Breadcrumb bar
// ═══════════════════════════════════════════════════════════════

class ApexBreadcrumb extends StatelessWidget {
  final List<String> path;
  const ApexBreadcrumb({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (int i = 0; i < path.length; i++) ...[
            if (i > 0) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_left, color: AC.td, size: 16),
            ),
            Text(path[i], style: TextStyle(
              color: i == path.length - 1 ? AC.gold : AC.ts,
              fontSize: 12,
              fontWeight: i == path.length - 1 ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ],
      ),
    );
  }
}
