/// V5.2 — Expense Claims using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class ExpenseClaimsV52Screen extends StatefulWidget {
  const ExpenseClaimsV52Screen({super.key});

  @override
  State<ExpenseClaimsV52Screen> createState() => _ExpenseClaimsV52ScreenState();
}

class _ExpenseClaimsV52ScreenState extends State<ExpenseClaimsV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _claims = <_Claim>[
    _Claim('EC-2026-142', 'أحمد محمد', 'ضيافة عميل', 'غداء عمل مع شركة الراجحي', 380, '2026-04-18', _S.submitted, 'ضيافة'),
    _Claim('EC-2026-141', 'سارة علي', 'سفر', 'رحلة دبي لحضور مؤتمر', 4200, '2026-04-17', _S.approved, 'سفر'),
    _Claim('EC-2026-140', 'عمر حسن', 'نقل', 'Uber من المطار', 85, '2026-04-17', _S.reimbursed, 'نقل'),
    _Claim('EC-2026-139', 'ليلى أحمد', 'مكتبية', 'شراء أقلام ودفاتر', 145, '2026-04-16', _S.policyViolation, 'مكتبية'),
    _Claim('EC-2026-138', 'خالد إبراهيم', 'اشتراكات', 'اشتراك LinkedIn Premium', 890, '2026-04-15', _S.submitted, 'تدريب'),
    _Claim('EC-2026-137', 'يوسف عمر', 'ضيافة', 'عشاء عمل', 620, '2026-04-14', _S.approved, 'ضيافة'),
    _Claim('EC-2026-136', 'دينا حسام', 'سفر', 'فندق الرياض - ليلتين', 1800, '2026-04-12', _S.reimbursed, 'سفر'),
    _Claim('EC-2026-135', 'سامي طارق', 'معدات', 'ماوس ولوحة مفاتيح', 680, '2026-04-10', _S.approved, 'معدات'),
    _Claim('EC-2026-134', 'نورة الدوسري', 'اتصالات', 'شحن بطاقة الهاتف', 300, '2026-04-08', _S.reimbursed, 'اتصالات'),
    _Claim('EC-2026-133', 'فهد الزهراني', 'ضيافة', 'قهوة واجتماعات', 420, '2026-04-05', _S.submitted, 'ضيافة'),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _claims.fold<double>(0, (s, c) => s + c.amount);
    final pending = _claims.where((c) => c.status == _S.submitted).length;
    return MultiViewTemplate(
      titleAr: 'مطالبات المصروفات',
      subtitleAr: '${_claims.length} مطالبة · $pending بانتظار الاعتماد · إجمالي ${(total / 1000).toStringAsFixed(1)}K ر.س',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.kanban,
      savedViews: const [
        SavedView(id: 'mine', labelAr: 'مطالباتي', icon: Icons.person, defaultViewMode: ViewMode.list),
        SavedView(id: 'pending', labelAr: 'بانتظار اعتمادي', icon: Icons.pending_actions, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'policy', labelAr: 'خارج السياسة', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'travel', labelAr: 'سفر فقط', icon: Icons.flight, defaultViewMode: ViewMode.kanban),
      ],
      filterChips: [
        FilterChipDef(id: 'submitted', labelAr: 'قيد الاعتماد', color: Colors.orange, count: _count(_S.submitted), active: _filter == 'submitted'),
        FilterChipDef(id: 'approved', labelAr: 'معتمدة', color: Colors.blue, count: _count(_S.approved), active: _filter == 'approved'),
        FilterChipDef(id: 'reimbursed', labelAr: 'مُسدَّدة', color: Colors.green, count: _count(_S.reimbursed), active: _filter == 'reimbursed'),
        FilterChipDef(id: 'policyViolation', labelAr: 'خارج السياسة', color: Colors.red, count: _count(_S.policyViolation), active: _filter == 'policyViolation'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'مطالبة جديدة',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _count(_S s) => _claims.where((c) => c.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _claims : _claims.where((c) => c.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final c = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 4, height: 46, color: c.status.color),
            const SizedBox(width: 12),
            CircleAvatar(radius: 16, backgroundColor: _gold.withOpacity(0.15), child: Text(c.employee[0], style: const TextStyle(color: _gold, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(c.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text(c.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black54))),
              ]),
              Text('${c.employee} · ${c.reason}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(c.note, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ])),
            Text('${c.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(width: 16),
            Text(c.date, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(c.status.icon, size: 12, color: c.status.color), const SizedBox(width: 4), Text(c.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.status.color))])),
          ])),
        );
      },
    );
  }

  Widget _kanban() {
    final statuses = [_S.submitted, _S.approved, _S.reimbursed, _S.policyViolation];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: statuses.map((s) {
        final items = _claims.where((c) => c.status == s).toList();
        final total = items.fold<double>(0, (sum, c) => sum + c.amount);
        return Container(
          width: 290,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Icon(s.icon, size: 16, color: s.color),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color)),
                Text('${total.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
            ])),
            ...items.map((c) => Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 10, backgroundColor: _gold.withOpacity(0.15), child: Text(c.employee[0], style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.employee, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text(c.reason, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(c.note, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${c.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)), child: Text(c.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black54))),
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
    // Group by category instead of status
    final categories = {'ضيافة': 0.0, 'سفر': 0.0, 'نقل': 0.0, 'مكتبية': 0.0, 'تدريب': 0.0, 'معدات': 0.0, 'اتصالات': 0.0};
    for (final c in _claims) {
      categories[c.category] = (categories[c.category] ?? 0) + c.amount;
    }
    final max = categories.values.reduce((a, b) => a > b ? a : b);
    final colors = [_gold, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('توزّع المصروفات حسب الفئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...categories.entries.toList().asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          final pct = max > 0 ? entry.value / max : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Text('${entry.value.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors[idx]))]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 18, backgroundColor: Colors.grey.shade100, color: colors[idx])),
          ]));
        }),
      ]),
    );
  }
}

enum _S { submitted, approved, reimbursed, policyViolation }

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.submitted => 'قيد الاعتماد',
        _S.approved => 'معتمدة',
        _S.reimbursed => 'مُسدَّدة',
        _S.policyViolation => 'خارج السياسة',
      };
  Color get color => switch (this) {
        _S.submitted => Colors.orange,
        _S.approved => Colors.blue,
        _S.reimbursed => Colors.green,
        _S.policyViolation => Colors.red,
      };
  IconData get icon => switch (this) {
        _S.submitted => Icons.pending_actions,
        _S.approved => Icons.check,
        _S.reimbursed => Icons.payments,
        _S.policyViolation => Icons.warning,
      };
}

class _Claim {
  final String id, employee, reason, note, date, category;
  final double amount;
  final _S status;
  const _Claim(this.id, this.employee, this.reason, this.note, this.amount, this.date, this.status, this.category);
}
