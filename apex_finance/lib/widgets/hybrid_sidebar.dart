/// APEX Platform — Hybrid Navigation Sidebar
/// ═══════════════════════════════════════════════════════════════
/// Pennylane + QuickBooks style sidebar with:
///   • Collapsible groups (RTL)
///   • Keyboard shortcut Cmd+K for quick search
///   • "+ New" FAB for quick create
///   • Max 2 clicks deep
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

class HybridSidebar extends StatefulWidget {
  final Widget child;
  final bool showSearch;
  const HybridSidebar({super.key, required this.child, this.showSearch = true});

  @override
  State<HybridSidebar> createState() => _HybridSidebarState();
}

class _NavGroup {
  final String label;
  final IconData icon;
  final List<_NavItem> items;
  bool expanded;
  _NavGroup(this.label, this.icon, this.items, {this.expanded = false});
}

class _NavItem {
  final String label;
  final String route;
  final IconData icon;
  const _NavItem(this.label, this.route, this.icon);
}

class _HybridSidebarState extends State<HybridSidebar> {
  bool _collapsed = false;
  final FocusNode _searchFocus = FocusNode();

  // 9 groups matching CoWork's hybrid nav spec
  final List<_NavGroup> _groups = [
    _NavGroup('لوحات القيادة', Icons.dashboard, [
      _NavItem('الرئيسية', '/dashboard', Icons.home),
      _NavItem('لوحة CFO', '/compliance/executive', Icons.admin_panel_settings),
      _NavItem('مركز الامتثال', '/compliance', Icons.shield),
    ], expanded: true),
    _NavGroup('العملاء والعقود', Icons.people, [
      _NavItem('العملاء', '/clients', Icons.person),
      _NavItem('خدمات العملاء', '/marketplace', Icons.store),
    ]),
    _NavGroup('القوائم المالية', Icons.auto_graph, [
      _NavItem('القوائم (TB/IS/BS)', '/compliance/financial-statements', Icons.auto_graph),
      _NavItem('قائمة التدفقات', '/compliance/cashflow-statement', Icons.water_drop),
      _NavItem('التوحيد', '/compliance/consolidation', Icons.merge_type),
      _NavItem('المؤشرات المالية', '/compliance/ratios', Icons.analytics),
    ]),
    _NavGroup('القيود والتدقيق', Icons.edit_note, [
      _NavItem('بنّاء القيود', '/compliance/journal-entry-builder', Icons.edit_note),
      _NavItem('أرقام القيود', '/compliance/journal-entries', Icons.confirmation_number),
      _NavItem('سجل التدقيق', '/compliance/audit-trail', Icons.lock_outline),
    ]),
    _NavGroup('الضرائب والامتثال', Icons.receipt_long, [
      _NavItem('فاتورة ZATCA', '/compliance/zatca-invoice', Icons.receipt_long),
      _NavItem('الزكاة', '/compliance/zakat', Icons.savings),
      _NavItem('إقرار VAT', '/compliance/vat-return', Icons.receipt),
      _NavItem('ضريبة الاستقطاع', '/compliance/wht', Icons.gavel),
      _NavItem('الضرائب المؤجّلة', '/compliance/deferred-tax', Icons.schedule_send),
      _NavItem('تسعير التحويل', '/compliance/transfer-pricing', Icons.compare),
    ]),
    _NavGroup('الأصول والإيجار', Icons.inventory, [
      _NavItem('سجل الأصول', '/compliance/fixed-assets', Icons.inventory),
      _NavItem('محاسبة الإيجار', '/compliance/lease', Icons.timeline),
      _NavItem('الإهلاك', '/compliance/depreciation', Icons.auto_graph),
    ]),
    _NavGroup('العمليات', Icons.settings, [
      _NavItem('الرواتب + GOSI', '/compliance/payroll', Icons.badge),
      _NavItem('التسوية البنكية', '/compliance/bank-rec', Icons.account_balance),
      _NavItem('المخزون', '/compliance/inventory', Icons.inventory_2),
      _NavItem('أعمار الذمم', '/compliance/aging', Icons.bar_chart),
      _NavItem('الأقساط', '/compliance/amortization', Icons.schedule),
    ]),
    _NavGroup('التقييم والتمويل', Icons.trending_up, [
      _NavItem('تغطية الدين (DSCR)', '/compliance/dscr', Icons.account_balance),
      _NavItem('التقييم (WACC/DCF)', '/compliance/valuation', Icons.query_stats),
      _NavItem('NPV/IRR', '/compliance/investment', Icons.insights),
      _NavItem('نقطة التعادل', '/compliance/breakeven', Icons.balance),
    ]),
    _NavGroup('أدوات متقدمة', Icons.all_inclusive, [
      _NavItem('IFRS (5-in-1)', '/compliance/ifrs-tools', Icons.style),
      _NavItem('Extras (7-in-1)', '/compliance/extras-tools', Icons.all_inclusive),
      _NavItem('انحرافات التكاليف', '/compliance/cost-variance', Icons.analytics_outlined),
      _NavItem('محوّل العملات', '/compliance/fx-converter', Icons.swap_horiz),
      _NavItem('OCR الفواتير', '/compliance/ocr', Icons.document_scanner),
    ]),
  ];

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _showQuickSearch() {
    final allItems = <_NavItem>[];
    for (final g in _groups) { allItems.addAll(g.items); }
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _QuickSearchDialog(items: allItems),
    );
  }

  void _showNewMenu() {
    showDialog(
      context: context,
      builder: (ctx) => _NewMenuDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;
    final width = isNarrow || _collapsed ? 72.0 : 260.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _showQuickSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _showQuickSearch,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AC.navy,
          body: Row(children: [
            // Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              decoration: BoxDecoration(
                color: AC.navy2,
                border: Border(left: BorderSide(color: AC.bdr)),
              ),
              child: Column(children: [
                // Logo + Collapse
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.apartment, color: AC.gold, size: 28),
                    if (!isNarrow && !_collapsed) ...[
                      const SizedBox(width: 8),
                      Expanded(child: Text('APEX',
                        style: TextStyle(color: AC.gold, fontSize: 22,
                          fontWeight: FontWeight.w900))),
                      IconButton(
                        icon: Icon(Icons.menu_open, color: AC.ts, size: 18),
                        onPressed: () => setState(() => _collapsed = !_collapsed),
                        tooltip: 'طيّ الشريط',
                      ),
                    ] else IconButton(
                      icon: Icon(Icons.menu, color: AC.ts, size: 18),
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                    ),
                  ]),
                ),
                // Quick actions
                if (!isNarrow && !_collapsed) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      ElevatedButton.icon(
                        onPressed: _showNewMenu,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ جديد'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          backgroundColor: AC.gold,
                          foregroundColor: AC.navy,
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _showQuickSearch,
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Cmd+K بحث'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(38),
                          side: BorderSide(color: AC.bdr),
                          foregroundColor: AC.tp,
                        ),
                      ),
                    ]),
                  ),
                  Divider(color: AC.bdr, height: 20),
                ] else Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(children: [
                    IconButton(
                      icon: Icon(Icons.add, color: AC.gold),
                      tooltip: 'جديد',
                      onPressed: _showNewMenu,
                    ),
                    IconButton(
                      icon: Icon(Icons.search, color: AC.ts),
                      tooltip: 'بحث (Cmd+K)',
                      onPressed: _showQuickSearch,
                    ),
                  ]),
                ),
                // Groups
                Expanded(child: ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) => _buildGroup(_groups[i], isNarrow || _collapsed),
                )),
                // Pinned: Settings + Account
                Divider(color: AC.bdr, height: 1),
                _buildBottomItem(Icons.person, 'الحساب', '/account/sessions', isNarrow || _collapsed),
                _buildBottomItem(Icons.settings, 'الإعدادات', '/admin/policies', isNarrow || _collapsed),
              ]),
            ),
            // Content
            Expanded(child: widget.child),
          ]),
        ),
      ),
    );
  }

  Widget _buildGroup(_NavGroup g, bool isCollapsed) {
    if (isCollapsed) {
      // Just show icons
      return Column(children: g.items.map((it) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: IconButton(
            icon: Icon(it.icon, color: AC.ts, size: 20),
            tooltip: it.label,
            onPressed: () => context.go(it.route),
          ),
        ),
      ).toList());
    }
    return Column(children: [
      InkWell(
        onTap: () => setState(() => g.expanded = !g.expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Icon(g.icon, color: AC.gold, size: 17),
            const SizedBox(width: 10),
            Expanded(child: Text(g.label, style: TextStyle(
              color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700))),
            Icon(g.expanded ? Icons.expand_less : Icons.expand_more,
              color: AC.ts, size: 18),
          ]),
        ),
      ),
      if (g.expanded) ...g.items.map((it) =>
        InkWell(
          onTap: () => context.go(it.route),
          child: Padding(
            padding: const EdgeInsets.only(right: 24, left: 12, top: 6, bottom: 6),
            child: Row(children: [
              Icon(it.icon, color: AC.ts, size: 15),
              const SizedBox(width: 10),
              Expanded(child: Text(it.label, style: TextStyle(
                color: AC.tp.withValues(alpha: 0.85), fontSize: 12))),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildBottomItem(IconData icon, String label, String route, bool isCollapsed) =>
    InkWell(
      onTap: () => context.go(route),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 8 : 12,
          vertical: isCollapsed ? 8 : 10,
        ),
        child: isCollapsed
          ? Icon(icon, color: AC.ts, size: 20)
          : Row(children: [
              Icon(icon, color: AC.ts, size: 17),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: AC.tp, fontSize: 12)),
            ]),
      ),
    );
}

class _QuickSearchDialog extends StatefulWidget {
  final List<_NavItem> items;
  const _QuickSearchDialog({required this.items});
  @override
  State<_QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<_QuickSearchDialog> {
  final _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
      ? widget.items
      : widget.items.where((it) =>
          it.label.toLowerCase().contains(_q.toLowerCase())).toList();
    return Dialog(
      backgroundColor: AC.navy2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          TextField(
            controller: _ctl,
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim()),
            style: TextStyle(color: AC.tp),
            decoration: InputDecoration(
              hintText: 'ابحث عن أي أداة، شاشة، عميل...',
              hintStyle: TextStyle(color: AC.ts, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: AC.gold),
              filled: true, fillColor: AC.navy3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final it = filtered[i];
              return InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go(it.route);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.3))),
                  ),
                  child: Row(children: [
                    Icon(it.icon, color: AC.gold, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(it.label,
                      style: TextStyle(color: AC.tp, fontSize: 13))),
                    Icon(Icons.arrow_back_ios, color: AC.ts, size: 12),
                  ]),
                ),
              );
            },
          )),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.keyboard, color: AC.ts, size: 14),
            const SizedBox(width: 6),
            Text('Cmd+K للبحث السريع',
              style: TextStyle(color: AC.ts, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

class _NewMenuDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('عميل جديد', Icons.person_add, '/clients/new'),
      ('فاتورة ZATCA', Icons.receipt_long, '/compliance/zatca-invoice'),
      ('قيد محاسبي', Icons.edit_note, '/compliance/journal-entry-builder'),
      ('قائمة مالية', Icons.auto_graph, '/compliance/financial-statements'),
      ('تحويل عملة', Icons.swap_horiz, '/compliance/fx-converter'),
      ('اختبار انخفاض', Icons.heart_broken, '/compliance/ifrs-tools'),
      ('رفع ملف CSV', Icons.upload_file, '/upload'),
    ];
    return Dialog(
      backgroundColor: AC.navy2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.add_circle, color: AC.gold),
            const SizedBox(width: 8),
            Text('إنشاء جديد',
              style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          ...items.map((it) => InkWell(
            onTap: () {
              Navigator.of(context).pop();
              context.go(it.$3);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                Icon(it.$2, color: AC.gold, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(it.$1,
                  style: TextStyle(color: AC.tp, fontSize: 13))),
                Icon(Icons.arrow_back_ios, color: AC.ts, size: 12),
              ]),
            ),
          )),
        ]),
      ),
    );
  }
}
