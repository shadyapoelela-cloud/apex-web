/// V5.2 — Journal Entries list using MultiViewTemplate.
///
/// Mirrors `invoices_v52_screen.dart` exactly so the toolbar, header,
/// view switcher, filter chips, and saved-views row look identical
/// across the two flagship list screens.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/templates/multi_view_template.dart';

class JournalEntriesV52Screen extends StatefulWidget {
  const JournalEntriesV52Screen({super.key});

  @override
  State<JournalEntriesV52Screen> createState() =>
      _JournalEntriesV52ScreenState();
}

class _JournalEntriesV52ScreenState extends State<JournalEntriesV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _activeFilter = '';

  static const _entries = <_JeEntry>[
    _JeEntry(id: 'JE-2026-4218', memo: 'قيد تسويات نهاية الفترة', amount: 450000, status: _JeStatus.posted, date: '2026-04-28'),
    _JeEntry(id: 'JE-2026-4220', memo: 'قيد استحقاق رواتب أبريل',  amount: 85000,  status: _JeStatus.pending, date: '2026-04-26'),
    _JeEntry(id: 'JE-2026-4215', memo: 'قيد عكسي لتسوية سابقة',     amount: 13000,  status: _JeStatus.reversed, date: '2026-04-22'),
    _JeEntry(id: 'JE-2026-4214', memo: 'إثبات إيراد فاتورة INV-1042', amount: 45000, status: _JeStatus.posted, date: '2026-04-21'),
    _JeEntry(id: 'JE-2026-4213', memo: 'مصاريف تسويق Q2',            amount: 12300,  status: _JeStatus.posted, date: '2026-04-20'),
    _JeEntry(id: 'JE-2026-4211', memo: 'قيد إغلاق الإهلاك',          amount: 67500,  status: _JeStatus.draft,   date: '2026-04-18'),
    _JeEntry(id: 'JE-2026-4209', memo: 'تسوية الفروقات البنكية',     amount: 5400,   status: _JeStatus.pending, date: '2026-04-17'),
    _JeEntry(id: 'JE-2026-4208', memo: 'قيد توريد عقد CTR-042',       amount: 280000, status: _JeStatus.posted, date: '2026-04-15'),
    _JeEntry(id: 'JE-2026-4205', memo: 'مصاريف صيانة وإصلاح',         amount: 8200,   status: _JeStatus.draft,   date: '2026-04-12'),
    _JeEntry(id: 'JE-2026-4204', memo: 'قيد افتتاح فرع جدة',          amount: 950000, status: _JeStatus.posted, date: '2026-04-10'),
  ];

  List<_JeEntry> get _filtered {
    if (_activeFilter.isEmpty) return _entries;
    if (_activeFilter == 'posted') return _entries.where((e) => e.status == _JeStatus.posted).toList();
    if (_activeFilter == 'pending') return _entries.where((e) => e.status == _JeStatus.pending).toList();
    if (_activeFilter == 'draft') return _entries.where((e) => e.status == _JeStatus.draft).toList();
    if (_activeFilter == 'reversed') return _entries.where((e) => e.status == _JeStatus.reversed).toList();
    return _entries;
  }

  int _countOf(_JeStatus s) => _entries.where((e) => e.status == s).length;

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'القيود اليومية',
      subtitleAr: 'سنة 2026 · جميع الكيانات',
      enabledViews: const {
        ViewMode.list,
        ViewMode.kanban,
        ViewMode.calendar,
        ViewMode.chart,
      },
      savedViews: const [
        SavedView(id: 'mine',     labelAr: 'قيودي هذا الشهر',      icon: Icons.person,        defaultViewMode: ViewMode.list),
        SavedView(id: 'manual',   labelAr: 'قيود يدوية كبيرة',      icon: Icons.edit_note,      defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'pending',  labelAr: 'قيد المراجعة',          icon: Icons.hourglass_top,  defaultViewMode: ViewMode.kanban, isShared: true),
        SavedView(id: 'closing',  labelAr: 'قيود الإقفال',          icon: Icons.lock_clock,     defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'posted',   labelAr: 'مرحّل',         icon: Icons.verified,            color: core_theme.AC.ok,   count: _countOf(_JeStatus.posted),   active: _activeFilter == 'posted'),
        FilterChipDef(id: 'pending',  labelAr: 'قيد المراجعة',  icon: Icons.hourglass_top,       color: core_theme.AC.info, count: _countOf(_JeStatus.pending),  active: _activeFilter == 'pending'),
        FilterChipDef(id: 'draft',    labelAr: 'مسودة',         icon: Icons.edit,                color: core_theme.AC.td,   count: _countOf(_JeStatus.draft),    active: _activeFilter == 'draft'),
        FilterChipDef(id: 'reversed', labelAr: 'معكوس',         icon: Icons.undo,                color: core_theme.AC.err,  count: _countOf(_JeStatus.reversed), active: _activeFilter == 'reversed'),
      ],
      onFilterToggle: (id) {
        setState(() => _activeFilter = _activeFilter == id ? '' : id);
      },
      onCreateNew: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('افتتاح قيد يومية جديد')),
        );
      },
      createLabelAr: 'قيد جديد',
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
        final je = items[i];
        final (color, label) = _statusMeta(je.status);
        return Card(
          elevation: 0.5,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(width: 4, height: 44, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(je.id,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: core_theme.AC.ts)),
                        Text(je.memo,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${je.amount.toStringAsFixed(0)} ر.س',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: _navy),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('تاريخ',
                          style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text(je.date, style: const TextStyle(fontSize: 12)),
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
      _JeStatus.draft: ('مسودة', core_theme.AC.td, _entries.where((e) => e.status == _JeStatus.draft).toList()),
      _JeStatus.pending: ('قيد المراجعة', core_theme.AC.info, _entries.where((e) => e.status == _JeStatus.pending).toList()),
      _JeStatus.posted: ('مرحّل', core_theme.AC.ok, _entries.where((e) => e.status == _JeStatus.posted).toList()),
      _JeStatus.reversed: ('معكوس', core_theme.AC.err, _entries.where((e) => e.status == _JeStatus.reversed).toList()),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.entries.map((entry) {
          final (label, color, items) = entry.value;
          final total = items.fold<double>(0, (s, e) => s + e.amount);
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
                ...items.map((je) => Container(
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
                          Text(je.id,
                              style: TextStyle(
                                  fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
                          Text(je.memo,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${je.amount.toStringAsFixed(0)} ر.س',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                              const Spacer(),
                              Text(je.date, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
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
    final sorted = [..._filtered]..sort((a, b) => a.date.compareTo(b.date));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('قيود اليومية حسب التاريخ — أبريل 2026',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final je in sorted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: je.status == _JeStatus.reversed ? core_theme.AC.err : core_theme.AC.bdr,
                      ),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(je.date.substring(8), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _gold)),
                            Text(je.date.substring(5, 7), style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(je.memo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${je.id} · ${je.amount.toStringAsFixed(0)} ر.س',
                                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                            ],
                          ),
                        ),
                        Icon(_statusIcon(je.status), color: _statusMeta(je.status).$1),
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
      'مرحّل':         _entries.where((e) => e.status == _JeStatus.posted).fold<double>(0, (s, e) => s + e.amount),
      'قيد المراجعة':  _entries.where((e) => e.status == _JeStatus.pending).fold<double>(0, (s, e) => s + e.amount),
      'مسودة':         _entries.where((e) => e.status == _JeStatus.draft).fold<double>(0, (s, e) => s + e.amount),
      'معكوس':         _entries.where((e) => e.status == _JeStatus.reversed).fold<double>(0, (s, e) => s + e.amount),
    };
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    final colors = [core_theme.AC.ok, core_theme.AC.info, core_theme.AC.td, core_theme.AC.err];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('توزّع القيود حسب الحالة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 4),
          Text('الإجمالي: ${_entries.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0)} ر.س',
              style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          const SizedBox(height: 24),
          ...totals.entries.toList().asMap().entries.map((e) {
            final idx = e.key;
            final label = e.value.key;
            final value = e.value.value;
            final pct = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
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

  (Color, String) _statusMeta(_JeStatus s) {
    switch (s) {
      case _JeStatus.posted:
        return (core_theme.AC.ok, 'مرحّل');
      case _JeStatus.pending:
        return (core_theme.AC.info, 'قيد المراجعة');
      case _JeStatus.draft:
        return (core_theme.AC.td, 'مسودة');
      case _JeStatus.reversed:
        return (core_theme.AC.err, 'معكوس');
    }
  }

  IconData _statusIcon(_JeStatus s) {
    switch (s) {
      case _JeStatus.posted:
        return Icons.verified;
      case _JeStatus.pending:
        return Icons.hourglass_top;
      case _JeStatus.draft:
        return Icons.edit;
      case _JeStatus.reversed:
        return Icons.undo;
    }
  }
}

enum _JeStatus { posted, pending, draft, reversed }

class _JeEntry {
  final String id;
  final String memo;
  final double amount;
  final _JeStatus status;
  final String date;
  const _JeEntry({
    required this.id,
    required this.memo,
    required this.amount,
    required this.status,
    required this.date,
  });
}
