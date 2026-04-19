/// V5.2 — Universal GL (SAP ACDOCA-inspired) using MultiViewTemplate.
///
/// Unified line-item inquiry across FI + CO with multi-dimensional filters.
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class UniversalGlV52Screen extends StatefulWidget {
  const UniversalGlV52Screen({super.key});

  @override
  State<UniversalGlV52Screen> createState() => _UniversalGlV52ScreenState();
}

class _UniversalGlV52ScreenState extends State<UniversalGlV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _dim = 'account';

  static const _lines = <_Line>[
    _Line('2026-04-18', 'JE-2026-4218', '1110', 'النقدية', 'PC-1100', 'CC-1200', 'D-product.food', 45000, 0, 'تحصيل فاتورة SABIC'),
    _Line('2026-04-18', 'JE-2026-4218', '1210', 'الذمم المدينة', 'PC-1100', 'CC-1200', 'D-product.food', 0, 45000, 'إنقاص رصيد العميل'),
    _Line('2026-04-17', 'JE-2026-4217', '5210', 'الرواتب', 'PC-1200', 'CC-1210', 'D-region.ksa', 120000, 0, 'راتب مارس - قسم المحاسبة'),
    _Line('2026-04-17', 'JE-2026-4217', '1110', 'النقدية', 'PC-1200', 'CC-1210', 'D-region.ksa', 0, 120000, 'دفع من بنك الرياض'),
    _Line('2026-04-17', 'JE-2026-4216', '2210', 'ضريبة VAT', 'PC-1000', null, null, 0, 18000, 'احتساب VAT على المبيعات'),
    _Line('2026-04-17', 'JE-2026-4216', '4110', 'مبيعات', 'PC-1100', 'CC-1600', 'D-product.food', 0, 120000, 'مبيعات أبريل'),
    _Line('2026-04-16', 'JE-2026-4215', '5230', 'تسويق', 'PC-1100', 'CC-1500', 'D-channel.online', 18000, 0, 'حملة Google Ads'),
    _Line('2026-04-16', 'JE-2026-4215', '2110', 'ذمم دائنة', 'PC-1100', 'CC-1500', 'D-channel.online', 0, 18000, 'فاتورة Google Ads'),
    _Line('2026-04-15', 'JE-2026-4214', '1410', 'مباني', 'PC-1000', 'CC-1000', null, 3400000, 0, 'شراء مبنى جديد - الدمام'),
    _Line('2026-04-15', 'JE-2026-4214', '1110', 'النقدية', 'PC-1000', 'CC-1000', null, 0, 3400000, 'دفع من البنك الأهلي'),
    _Line('2026-04-14', 'JE-2026-4213', '5240', 'إهلاك', 'PC-1000', 'CC-1000', null, 85000, 0, 'إهلاك شهري'),
    _Line('2026-04-14', 'JE-2026-4213', '1490', 'مجمّع الإهلاك', 'PC-1000', 'CC-1000', null, 0, 85000, 'مجمّع إهلاك المباني'),
    _Line('2026-04-13', 'JE-2026-4212', '5210', 'رواتب', 'PC-1300', 'CC-1800', 'D-region.ksa.jeddah', 320000, 0, 'رواتب فرع جدة'),
    _Line('2026-04-13', 'JE-2026-4212', '1110', 'نقدية', 'PC-1300', 'CC-1800', 'D-region.ksa.jeddah', 0, 320000, 'تحويل WPS'),
    _Line('2026-04-12', 'JE-2026-4211', '1310', 'مخزون', 'PC-1100', 'CC-1700', 'D-product.electronics', 180000, 0, 'استلام بضاعة'),
    _Line('2026-04-12', 'JE-2026-4211', '2110', 'ذمم دائنة', 'PC-1100', 'CC-1700', 'D-product.electronics', 0, 180000, 'فاتورة مورد IT'),
  ];

  @override
  Widget build(BuildContext context) {
    final totalDebit = _lines.fold<double>(0, (s, l) => s + l.debit);
    final totalCredit = _lines.fold<double>(0, (s, l) => s + l.credit);
    return MultiViewTemplate(
      titleAr: 'الأستاذ الشامل (Universal GL)',
      subtitleAr: 'SAP ACDOCA-inspired · متعدّد الأبعاد · ${_lines.length} بند · ${(totalDebit / 1e6).toStringAsFixed(2)}M ر.س',
      enabledViews: const {ViewMode.list, ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'today', labelAr: 'اليوم', icon: Icons.today, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'cash', labelAr: 'حركة النقدية', icon: Icons.account_balance, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'largest', labelAr: 'الأعلى قيمة >100K', icon: Icons.star, defaultViewMode: ViewMode.list),
        SavedView(id: 'by-cc', labelAr: 'حسب مركز التكلفة', icon: Icons.pie_chart, defaultViewMode: ViewMode.pivot, isShared: true),
      ],
      filterChips: [
        FilterChipDef(id: 'account', labelAr: 'حسب الحساب', icon: Icons.account_tree, color: _gold, active: _dim == 'account'),
        FilterChipDef(id: 'profit', labelAr: 'حسب مركز الربحية', icon: Icons.donut_small, color: Colors.blue, active: _dim == 'profit'),
        FilterChipDef(id: 'cost', labelAr: 'حسب مركز التكلفة', icon: Icons.pie_chart, color: Colors.orange, active: _dim == 'cost'),
        FilterChipDef(id: 'dim', labelAr: 'حسب الأبعاد', icon: Icons.view_in_ar, color: Colors.purple, active: _dim == 'dim'),
      ],
      onFilterToggle: (id) => setState(() => _dim = id),
      onCreateNew: () {},
      createLabelAr: 'قيد جديد',
      headerActions: const [
        _MiniPill(label: 'الفترة: أبريل 2026', icon: Icons.event),
        SizedBox(width: 6),
        _MiniPill(label: 'الكيان: السعودية', icon: Icons.flag),
        SizedBox(width: 6),
        _MiniPill(label: 'العملة: SAR', icon: Icons.currency_exchange),
      ],
      listBuilder: (_) => _list(),
      pivotBuilder: (_) => _pivot(),
      chartBuilder: (_) => _chart(),
    );
  }

  Widget _list() {
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: _navy, child: const Row(children: [
        SizedBox(width: 90, child: Text('التاريخ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        SizedBox(width: 110, child: Text('القيد', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        SizedBox(width: 160, child: Text('الحساب', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        Expanded(child: Text('الوصف', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        SizedBox(width: 90, child: Text('PC', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        SizedBox(width: 90, child: Text('CC', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        SizedBox(width: 110, child: Text('مدين', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
        SizedBox(width: 110, child: Text('دائن', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
      ])),
      Expanded(child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _lines.length,
        separatorBuilder: (_, __) => Container(height: 1, color: Colors.grey.shade200),
        itemBuilder: (_, i) {
          final l = _lines[i];
          return InkWell(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: i % 2 == 0 ? Colors.white : Colors.grey.shade50,
              child: Row(children: [
                SizedBox(width: 90, child: Text(l.date, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                SizedBox(width: 110, child: Text(l.jeId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blue, decoration: TextDecoration.underline))),
                SizedBox(width: 160, child: Row(children: [
                  Text(l.accountId, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.accountName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
                Expanded(child: Text(l.description, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                SizedBox(width: 90, child: Text(l.profitCenter ?? '—', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blue.shade700))),
                SizedBox(width: 90, child: Text(l.costCenter ?? '—', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.orange.shade700))),
                SizedBox(width: 110, child: Text(l.debit > 0 ? l.debit.toStringAsFixed(0) : '—', style: TextStyle(fontSize: 12, fontWeight: l.debit > 0 ? FontWeight.w800 : FontWeight.w400, color: l.debit > 0 ? Colors.green : Colors.black38, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                SizedBox(width: 110, child: Text(l.credit > 0 ? l.credit.toStringAsFixed(0) : '—', style: TextStyle(fontSize: 12, fontWeight: l.credit > 0 ? FontWeight.w800 : FontWeight.w400, color: l.credit > 0 ? _gold : Colors.black38, fontFamily: 'monospace'), textAlign: TextAlign.end)),
              ]),
            ),
          );
        },
      )),
      Container(
        padding: const EdgeInsets.all(12),
        color: _gold.withOpacity(0.08),
        child: Row(children: [
          const Text('الإجماليات:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
          const Spacer(),
          Text('مدين: ${_lines.fold<double>(0, (s, l) => s + l.debit).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.green, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          Text('دائن: ${_lines.fold<double>(0, (s, l) => s + l.credit).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          const Text('متوازن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green)),
        ]),
      ),
    ]);
  }

  Widget _pivot() {
    // Group by current dimension
    final groups = <String, List<_Line>>{};
    for (final l in _lines) {
      String? key;
      if (_dim == 'account') key = '${l.accountId} ${l.accountName}';
      else if (_dim == 'profit') key = l.profitCenter;
      else if (_dim == 'cost') key = l.costCenter;
      else key = l.dimension;
      if (key != null) groups.putIfAbsent(key, () => []).add(l);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final key = groups.keys.elementAt(i);
        final lines = groups[key]!;
        final totalD = lines.fold<double>(0, (s, l) => s + l.debit);
        final totalC = lines.fold<double>(0, (s, l) => s + l.credit);
        final net = totalD - totalC;
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _gold.withOpacity(0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              const Icon(Icons.folder, color: _gold, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy))),
              Text('${lines.length} بند', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(width: 16),
              Text('صافي: ${net.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: net >= 0 ? Colors.green : Colors.red)),
            ])),
            ...lines.map((l) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                  child: Row(children: [
                    SizedBox(width: 90, child: Text(l.date, style: const TextStyle(fontSize: 11))),
                    SizedBox(width: 110, child: Text(l.jeId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blue))),
                    Expanded(child: Text(l.description, style: const TextStyle(fontSize: 11))),
                    SizedBox(width: 100, child: Text(l.debit > 0 ? l.debit.toStringAsFixed(0) : '—', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: l.debit > 0 ? Colors.green : Colors.black38), textAlign: TextAlign.end)),
                    SizedBox(width: 100, child: Text(l.credit > 0 ? l.credit.toStringAsFixed(0) : '—', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: l.credit > 0 ? _gold : Colors.black38), textAlign: TextAlign.end)),
                  ]),
                )),
          ]),
        );
      },
    );
  }

  Widget _chart() {
    final groups = <String, double>{};
    for (final l in _lines) {
      final key = '${l.accountId}';
      groups[key] = (groups[key] ?? 0) + l.debit.abs() + l.credit.abs();
    }
    final sorted = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('حركة الحسابات — الأكثر نشاطاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        Expanded(child: ListView(children: sorted.map((e) {
          final pct = e.value / max;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 20, backgroundColor: Colors.grey.shade100, color: _gold))),
            const SizedBox(width: 10),
            SizedBox(width: 140, child: Text('${(e.value / 1000).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold), textAlign: TextAlign.end)),
          ]));
        }).toList())),
      ]),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MiniPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFF1A237E).withOpacity(0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: const Color(0xFF1A237E)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
      ]),
    );
  }
}

class _Line {
  final String date, jeId, accountId, accountName, description;
  final String? profitCenter, costCenter, dimension;
  final double debit, credit;
  const _Line(this.date, this.jeId, this.accountId, this.accountName, this.profitCenter, this.costCenter, this.dimension, this.debit, this.credit, this.description);
}
