/// V5.2 — Purchasing AP (Vendor Bills) using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class PurchasingApV52Screen extends StatefulWidget {
  const PurchasingApV52Screen({super.key});

  @override
  State<PurchasingApV52Screen> createState() => _PurchasingApV52ScreenState();
}

class _PurchasingApV52ScreenState extends State<PurchasingApV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _bills = <_Bill>[
    _Bill('VB-2026-142', 'مجموعة الخليج للتوريدات', 'PO-2026-124', 140000, '2026-04-15', '2026-05-15', _S.approved),
    _Bill('VB-2026-141', 'AWS Cloud Services', 'PO-2026-120', 4200, '2026-04-12', '2026-05-12', _S.approved),
    _Bill('VB-2026-140', 'شركة النقل السريع', 'PO-2026-118', 8900, '2026-04-10', '2026-04-25', _S.paid),
    _Bill('VB-2026-139', 'مطبعة الوفاء', 'PO-2026-115', 3400, '2026-04-08', '2026-05-08', _S.pendingApproval),
    _Bill('VB-2026-138', 'شركة الصيانة المتكاملة', 'PO-2026-112', 22000, '2026-04-05', '2026-05-05', _S.pendingApproval),
    _Bill('VB-2026-137', 'موبايلي — خدمات اتصالات', 'PO-2026-110', 15600, '2026-04-01', '2026-05-01', _S.approved),
    _Bill('VB-2026-136', 'شركة البناء المعماري', 'PO-2026-108', 340000, '2026-03-28', '2026-04-28', _S.disputed),
    _Bill('VB-2026-135', 'مكتب المحاماة المتحد', 'PO-2026-105', 45000, '2026-03-25', '2026-04-25', _S.paid),
    _Bill('VB-2026-134', 'شركة التسويق الرقمي', 'PO-2026-102', 18000, '2026-03-22', '2026-04-22', _S.pendingApproval),
    _Bill('VB-2026-133', 'أنظمة الأمن والمراقبة', 'PO-2026-098', 85000, '2026-03-15', '2026-04-15', _S.overdue),
    _Bill('VB-2026-132', 'شركة التأمين الوطني', 'PO-2026-095', 67000, '2026-03-10', '2026-04-10', _S.overdue),
    _Bill('VB-2026-131', 'شركة الأثاث المكتبي', 'PO-2026-090', 34000, '2026-03-05', '2026-04-05', _S.paid),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _bills.fold<double>(0, (s, b) => s + b.amount);
    final overdue = _bills.where((b) => b.status == _S.overdue).fold<double>(0, (s, b) => s + b.amount);
    return MultiViewTemplate(
      titleAr: 'فواتير الموردين (AP)',
      subtitleAr: '${_bills.length} فاتورة · إجمالي ${(total / 1e6).toStringAsFixed(2)}M ر.س · متأخرة ${(overdue / 1e3).toStringAsFixed(0)}K',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'overdue', labelAr: 'المتأخرة للدفع', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'pending', labelAr: 'بانتظار الاعتماد', icon: Icons.pending_actions, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'large', labelAr: 'فواتير كبرى >100K', icon: Icons.star, defaultViewMode: ViewMode.kanban),
        SavedView(id: 'disputed', labelAr: 'نزاعات', icon: Icons.gavel, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'pendingApproval', labelAr: 'قيد الاعتماد', color: Colors.orange, count: _count(_S.pendingApproval), active: _filter == 'pendingApproval'),
        FilterChipDef(id: 'approved', labelAr: 'معتمد', color: Colors.blue, count: _count(_S.approved), active: _filter == 'approved'),
        FilterChipDef(id: 'paid', labelAr: 'مدفوع', color: Colors.green, count: _count(_S.paid), active: _filter == 'paid'),
        FilterChipDef(id: 'overdue', labelAr: 'متأخّر', color: Colors.red, count: _count(_S.overdue), active: _filter == 'overdue'),
        FilterChipDef(id: 'disputed', labelAr: 'متنازع', color: Colors.purple, count: _count(_S.disputed), active: _filter == 'disputed'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'فاتورة جديدة',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _count(_S s) => _bills.where((b) => b.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _bills : _bills.where((b) => b.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final b = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 4, height: 46, color: b.status.color),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(b.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54)),
                  const SizedBox(width: 8),
                  Text('← ${b.po}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black38)),
                ]),
                Text(b.vendor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ])),
              Expanded(child: Text('${b.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy), textAlign: TextAlign.end)),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('تاريخ الاستحقاق', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(b.dueDate, style: const TextStyle(fontSize: 11)),
              ]),
              const SizedBox(width: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: b.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Text(b.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.status.color))),
              IconButton(icon: const Icon(Icons.more_vert, size: 18), onPressed: () {}),
            ]),
          ),
        );
      },
    );
  }

  Widget _kanban() {
    final statuses = [_S.pendingApproval, _S.approved, _S.overdue, _S.paid];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: statuses.map((s) {
        final items = _bills.where((b) => b.status == s).toList();
        final total = items.fold<double>(0, (sum, b) => sum + b.amount);
        return Container(
          width: 290,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color)),
                Text('${(total / 1e3).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
            ])),
            ...items.map((b) => Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                Text(b.vendor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${(b.amount / 1e3).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                  const Spacer(),
                  Text(b.dueDate, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ]),
              ]),
            )),
            const SizedBox(height: 8),
          ]),
        );
      }).toList()),
    );
  }

  Widget _chart() {
    final statuses = _S.values;
    final totals = {for (final s in statuses) s: _bills.where((b) => b.status == s).fold<double>(0, (sum, b) => sum + b.amount)};
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('توزّع فواتير الموردين حسب الحالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...statuses.map((s) {
          final value = totals[s]!;
          final pct = max > 0 ? value / max : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(s.labelAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Text('${value.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.color))]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 20, backgroundColor: Colors.grey.shade100, color: s.color)),
          ]));
        }),
      ]),
    );
  }
}

enum _S { pendingApproval, approved, paid, overdue, disputed }

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.pendingApproval => 'قيد الاعتماد',
        _S.approved => 'معتمد',
        _S.paid => 'مدفوع',
        _S.overdue => 'متأخر',
        _S.disputed => 'متنازع',
      };
  Color get color => switch (this) {
        _S.pendingApproval => Colors.orange,
        _S.approved => Colors.blue,
        _S.paid => Colors.green,
        _S.overdue => Colors.red,
        _S.disputed => Colors.purple,
      };
}

class _Bill {
  final String id, vendor, po, issueDate, dueDate;
  final double amount;
  final _S status;
  const _Bill(this.id, this.vendor, this.po, this.amount, this.issueDate, this.dueDate, this.status);
}
