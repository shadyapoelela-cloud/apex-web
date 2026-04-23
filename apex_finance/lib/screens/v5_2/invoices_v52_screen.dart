/// V5.2 Reference Implementation — Invoices screen using MultiViewTemplate.
///
/// Demonstrates the unified T1 (Multi-View) template with:
///   - List view (default)
///   - Kanban view (by status)
///   - Calendar view (by due date)
///   - Chart view (aged buckets)
///   - Saved views + filter chips
///   - Search + sort + group + export
///   - + New invoice button
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/templates/multi_view_template.dart';

class InvoicesV52Screen extends StatefulWidget {
  const InvoicesV52Screen({super.key});

  @override
  State<InvoicesV52Screen> createState() => _InvoicesV52ScreenState();
}

class _InvoicesV52ScreenState extends State<InvoicesV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _activeFilter = '';

  static const _invoices = <_Invoice>[
    _Invoice(id: 'INV-2026-1042', client: 'شركة الراجحي للتجارة', amount: 45000, status: _Status.paid, due: '2026-03-15', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1043', client: 'مؤسسة الخليج للمقاولات', amount: 28500, status: _Status.pending, due: '2026-04-25', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1044', client: 'شركة النخيل للتجارة', amount: 12400, status: _Status.overdue, due: '2026-03-20', daysOverdue: 31),
    _Invoice(id: 'INV-2026-1045', client: 'مطاعم الواحة', amount: 8900, status: _Status.draft, due: '2026-05-01', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1046', client: 'شركة الأسطول للنقل', amount: 67800, status: _Status.paid, due: '2026-04-10', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1047', client: 'عيادات الصحة المتكاملة', amount: 34200, status: _Status.pending, due: '2026-04-28', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1048', client: 'مدرسة المستقبل الأهلية', amount: 15600, status: _Status.overdue, due: '2026-04-05', daysOverdue: 15),
    _Invoice(id: 'INV-2026-1049', client: 'شركة البناء الحديث', amount: 92000, status: _Status.draft, due: '2026-05-10', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1050', client: 'مجموعة التجارة الذكية', amount: 23100, status: _Status.paid, due: '2026-04-12', daysOverdue: 0),
    _Invoice(id: 'INV-2026-1051', client: 'فندق القصر الملكي', amount: 56700, status: _Status.pending, due: '2026-05-05', daysOverdue: 0),
  ];

  List<_Invoice> get _filtered {
    if (_activeFilter.isEmpty) return _invoices;
    if (_activeFilter == 'overdue') return _invoices.where((i) => i.status == _Status.overdue).toList();
    if (_activeFilter == 'pending') return _invoices.where((i) => i.status == _Status.pending).toList();
    if (_activeFilter == 'paid') return _invoices.where((i) => i.status == _Status.paid).toList();
    if (_activeFilter == 'draft') return _invoices.where((i) => i.status == _Status.draft).toList();
    return _invoices;
  }

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'الفواتير',
      subtitleAr: 'سنة 2026 · جميع الكيانات',
      enabledViews: const {
        ViewMode.list,
        ViewMode.kanban,
        ViewMode.calendar,
        ViewMode.chart,
      },
      savedViews: const [
        SavedView(id: 'mine', labelAr: 'فواتيري هذا الشهر', icon: Icons.person, defaultViewMode: ViewMode.list),
        SavedView(id: 'overdue', labelAr: 'المتأخرة > 30 يوم', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'large', labelAr: 'كبيرة > 50,000 ر.س', icon: Icons.star, defaultViewMode: ViewMode.kanban, isShared: true),
        SavedView(id: 'vip', labelAr: 'عملاء VIP', icon: Icons.diamond, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'paid', labelAr: 'مدفوعة', icon: Icons.check_circle, color: core_theme.AC.ok, count: 3, active: _activeFilter == 'paid'),
        FilterChipDef(id: 'pending', labelAr: 'قيد الاستحقاق', icon: Icons.schedule, color: core_theme.AC.info, count: 3, active: _activeFilter == 'pending'),
        FilterChipDef(id: 'overdue', labelAr: 'متأخرة', icon: Icons.warning, color: core_theme.AC.err, count: 2, active: _activeFilter == 'overdue'),
        FilterChipDef(id: 'draft', labelAr: 'مسودة', icon: Icons.edit, color: core_theme.AC.td, count: 2, active: _activeFilter == 'draft'),
      ],
      onFilterToggle: (id) {
        setState(() => _activeFilter = _activeFilter == id ? '' : id);
      },
      onCreateNew: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('افتتاح فاتورة جديدة — معالج الإنشاء')),
        );
      },
      createLabelAr: 'فاتورة جديدة',
      listBuilder: (ctx) => _buildListView(),
      kanbanBuilder: (ctx) => _buildKanbanView(),
      calendarBuilder: (ctx) => _buildCalendarView(),
      chartBuilder: (ctx) => _buildChartView(),
    );
  }

  // ── List View ──────────────────────────────────────────────────
  Widget _buildListView() {
    final items = _filtered;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final inv = items[i];
        final (color, label) = _statusMeta(inv.status);
        return Card(
          elevation: 0.5,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.id,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: core_theme.AC.ts)),
                        Text(inv.client,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${inv.amount.toStringAsFixed(0)} ر.س',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: _navy),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('استحقاق',
                          style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text(inv.due, style: const TextStyle(fontSize: 12)),
                      if (inv.daysOverdue > 0)
                        Text('متأخرة ${inv.daysOverdue} يوم',
                            style: TextStyle(fontSize: 10, color: core_theme.AC.err, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Kanban View ────────────────────────────────────────────────
  Widget _buildKanbanView() {
    final columns = {
      _Status.draft: ('مسودة', core_theme.AC.td, _invoices.where((i) => i.status == _Status.draft).toList()),
      _Status.pending: ('قيد الاستحقاق', core_theme.AC.info, _invoices.where((i) => i.status == _Status.pending).toList()),
      _Status.overdue: ('متأخرة', core_theme.AC.err, _invoices.where((i) => i.status == _Status.overdue).toList()),
      _Status.paid: ('مدفوعة', core_theme.AC.ok, _invoices.where((i) => i.status == _Status.paid).toList()),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.entries.map((e) {
          final (label, color, items) = e.value;
          final total = items.fold<double>(0, (s, i) => s + i.amount);
          return Container(
            width: 280,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: core_theme.AC.navy3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.bdr),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${items.length}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('الإجمالي: ${total.toStringAsFixed(0)} ر.س',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ),
                ...items.map((inv) => Container(
                      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: core_theme.AC.bdr),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.id,
                              style: TextStyle(
                                  fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
                          Text(inv.client,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${inv.amount.toStringAsFixed(0)} ر.س',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                              const Spacer(),
                              Text(inv.due, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                            ],
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Calendar View ──────────────────────────────────────────────
  Widget _buildCalendarView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('استحقاقات الفواتير — أبريل 2026',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final inv in _filtered..sort((a, b) => a.due.compareTo(b.due)))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: inv.status == _Status.overdue ? core_theme.AC.err : core_theme.AC.bdr,
                      ),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(inv.due.substring(8), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _gold)),
                            Text(inv.due.substring(5, 7), style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv.client, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${inv.id} · ${inv.amount.toStringAsFixed(0)} ر.س',
                                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                            ],
                          ),
                        ),
                        Icon(
                          _statusMeta(inv.status).$1 == core_theme.AC.err ? Icons.warning : Icons.schedule,
                          color: _statusMeta(inv.status).$1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart View ──────────────────────────────────────────────
  Widget _buildChartView() {
    final totals = {
      'مدفوعة': _invoices.where((i) => i.status == _Status.paid).fold<double>(0, (s, i) => s + i.amount),
      'قيد الاستحقاق': _invoices.where((i) => i.status == _Status.pending).fold<double>(0, (s, i) => s + i.amount),
      'متأخرة': _invoices.where((i) => i.status == _Status.overdue).fold<double>(0, (s, i) => s + i.amount),
      'مسودة': _invoices.where((i) => i.status == _Status.draft).fold<double>(0, (s, i) => s + i.amount),
    };
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    final colors = [core_theme.AC.ok, core_theme.AC.info, core_theme.AC.err, core_theme.AC.td];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('توزّع الفواتير حسب الحالة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 4),
          Text('الإجمالي: ${_invoices.fold<double>(0, (s, i) => s + i.amount).toStringAsFixed(0)} ر.س',
              style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          const SizedBox(height: 24),
          ...totals.entries.toList().asMap().entries.map((e) {
            final idx = e.key;
            final label = e.value.key;
            final value = e.value.value;
            final pct = (value / max).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${value.toStringAsFixed(0)} ر.س',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors[idx])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 20,
                      backgroundColor: core_theme.AC.navy3,
                      color: colors[idx],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  (Color, String) _statusMeta(_Status s) {
    switch (s) {
      case _Status.paid:
        return (core_theme.AC.ok, 'مدفوعة');
      case _Status.pending:
        return (core_theme.AC.info, 'قيد الاستحقاق');
      case _Status.overdue:
        return (core_theme.AC.err, 'متأخرة');
      case _Status.draft:
        return (core_theme.AC.td, 'مسودة');
    }
  }
}

enum _Status { paid, pending, overdue, draft }

class _Invoice {
  final String id;
  final String client;
  final double amount;
  final _Status status;
  final String due;
  final int daysOverdue;
  const _Invoice({
    required this.id,
    required this.client,
    required this.amount,
    required this.status,
    required this.due,
    required this.daysOverdue,
  });
}
