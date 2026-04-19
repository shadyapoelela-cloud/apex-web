/// V5.2 — Sales Pipeline using MultiViewTemplate (Kanban-first).
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class SalesPipelineV52Screen extends StatefulWidget {
  const SalesPipelineV52Screen({super.key});

  @override
  State<SalesPipelineV52Screen> createState() => _SalesPipelineV52ScreenState();
}

class _SalesPipelineV52ScreenState extends State<SalesPipelineV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _deals = <_Deal>[
    _Deal('D-1042', 'تطبيق ERP للبنك السعودي', 'البنك الأهلي', 2800000, _Stg.contacted, 30, 'محمد العمري', 45),
    _Deal('D-1041', 'نظام محاسبي متكامل', 'مستشفيات المملكة', 1450000, _Stg.demo, 55, 'سارة الزهراني', 28),
    _Deal('D-1040', 'تدريب فرق مالية', 'شركة الراجحي المالية', 380000, _Stg.proposal, 65, 'أحمد السعيد', 20),
    _Deal('D-1039', 'ترخيص 200 مستخدم', 'مجموعة الفيصلية', 890000, _Stg.negotiation, 85, 'نورة الدوسري', 12),
    _Deal('D-1038', 'استشارات ZATCA', 'مطاعم البيك', 145000, _Stg.new_, 15, 'خالد الشمراني', 55),
    _Deal('D-1037', 'نظام POS للمطاعم', 'فنادق موفنبيك', 670000, _Stg.demo, 50, 'ريم القحطاني', 30),
    _Deal('D-1036', 'ترحيل من SAP', 'أرامكو للخدمات', 4500000, _Stg.proposal, 70, 'محمد العمري', 18),
    _Deal('D-1035', 'تطبيق الرواتب', 'شركة سابك', 340000, _Stg.closedWon, 100, 'سارة الزهراني', 0),
    _Deal('D-1034', 'نظام المشاريع', 'مقاولات البناء الحديث', 560000, _Stg.negotiation, 80, 'أحمد السعيد', 8),
    _Deal('D-1033', 'استشارات مالية', 'مجموعة النفط والغاز', 780000, _Stg.new_, 20, 'نورة الدوسري', 60),
    _Deal('D-1032', 'أدوات تحليل BI', 'بنك الرياض', 1200000, _Stg.contacted, 40, 'خالد الشمراني', 35),
    _Deal('D-1031', 'تحديث ZATCA Phase 2', 'متاجر الدانوب', 420000, _Stg.demo, 60, 'ريم القحطاني', 22),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'خط أنابيب المبيعات',
      subtitleAr: '${_deals.length} صفقة · قيمة إجمالية ${(_deals.fold<double>(0, (s, d) => s + d.value) / 1e6).toStringAsFixed(1)}M ر.س',
      enabledViews: const {ViewMode.kanban, ViewMode.list, ViewMode.chart},
      initialView: ViewMode.kanban,
      savedViews: const [
        SavedView(id: 'mine', labelAr: 'صفقاتي', icon: Icons.person, defaultViewMode: ViewMode.kanban),
        SavedView(id: 'hot', labelAr: 'صفقات ساخنة >70%', icon: Icons.whatshot, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'mega', labelAr: 'صفقات كبرى >1M', icon: Icons.star, defaultViewMode: ViewMode.kanban, isShared: true),
        SavedView(id: 'stalled', labelAr: 'متوقفة >30 يوم', icon: Icons.warning, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'new', labelAr: 'جديدة', color: Colors.grey, count: _count(_Stg.new_), active: _filter == 'new'),
        FilterChipDef(id: 'contacted', labelAr: 'تم التواصل', color: Colors.blue, count: _count(_Stg.contacted), active: _filter == 'contacted'),
        FilterChipDef(id: 'demo', labelAr: 'عرض تقني', color: Colors.cyan, count: _count(_Stg.demo), active: _filter == 'demo'),
        FilterChipDef(id: 'proposal', labelAr: 'عرض سعر', color: Colors.orange, count: _count(_Stg.proposal), active: _filter == 'proposal'),
        FilterChipDef(id: 'negotiation', labelAr: 'تفاوض', color: _gold, count: _count(_Stg.negotiation), active: _filter == 'negotiation'),
        FilterChipDef(id: 'won', labelAr: 'مكسوب', color: Colors.green, count: _count(_Stg.closedWon), active: _filter == 'won'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'صفقة جديدة',
      kanbanBuilder: (_) => _kanban(),
      listBuilder: (_) => _list(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _count(_Stg s) => _deals.where((d) => d.stage == s).length;

  Widget _kanban() {
    final stages = [_Stg.new_, _Stg.contacted, _Stg.demo, _Stg.proposal, _Stg.negotiation, _Stg.closedWon];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stages.map((s) {
          final items = _deals.where((d) => d.stage == s).toList();
          final total = items.fold<double>(0, (sum, d) => sum + d.value);
          return Container(
            width: 290,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                child: Row(children: [
                  Container(width: 4, height: 20, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.labelAr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.color)),
                    Text('${(total / 1e6).toStringAsFixed(2)}M ر.س', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
                ]),
              ),
              ...items.map((d) => Container(
                    margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(d.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                        const Spacer(),
                        if (d.daysStale > 30) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(3)), child: const Text('راكدة', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.red))),
                      ]),
                      Text(d.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(d.company, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${(d.value / 1e3).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold)),
                        const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)), child: Text('${d.probability}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: s.color))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        CircleAvatar(radius: 9, backgroundColor: _navy.withOpacity(0.1), child: Text(d.owner[0], style: const TextStyle(color: _navy, fontSize: 9, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 4),
                        Expanded(child: Text(d.owner, style: const TextStyle(fontSize: 9, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ]),
                  )),
              const SizedBox(height: 8),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _list() {
    final items = _filter.isEmpty ? _deals : _deals.where((d) {
      if (_filter == 'new') return d.stage == _Stg.new_;
      if (_filter == 'contacted') return d.stage == _Stg.contacted;
      if (_filter == 'demo') return d.stage == _Stg.demo;
      if (_filter == 'proposal') return d.stage == _Stg.proposal;
      if (_filter == 'negotiation') return d.stage == _Stg.negotiation;
      if (_filter == 'won') return d.stage == _Stg.closedWon;
      return true;
    }).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final d = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 4, height: 56, color: d.stage.color),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54)),
                Text(d.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(d.company, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ])),
              Expanded(child: Text('${d.value.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy), textAlign: TextAlign.end)),
              const SizedBox(width: 16),
              SizedBox(width: 90, child: Column(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: d.probability / 100, minHeight: 8, backgroundColor: Colors.grey.shade200, color: d.stage.color)),
                const SizedBox(height: 2),
                Text('${d.probability}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: d.stage.color)),
              ])),
              const SizedBox(width: 16),
              SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                CircleAvatar(radius: 12, backgroundColor: _gold.withOpacity(0.15), child: Text(d.owner[0], style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800))),
                Text(d.owner, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: d.stage.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Text(d.stage.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: d.stage.color))),
            ]),
          ),
        );
      },
    );
  }

  Widget _chart() {
    final stages = [_Stg.new_, _Stg.contacted, _Stg.demo, _Stg.proposal, _Stg.negotiation, _Stg.closedWon];
    final totals = {for (final s in stages) s: _deals.where((d) => d.stage == s).fold<double>(0, (sum, d) => sum + d.value)};
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('قمع المبيعات (Sales Funnel)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...stages.map((s) {
          final value = totals[s]!;
          final pct = max > 0 ? value / max : 0.0;
          final count = _deals.where((d) => d.stage == s).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s.labelAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('($count صفقة)', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                const Spacer(),
                Text('${value.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.color)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 24, backgroundColor: Colors.grey.shade100, color: s.color))),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

enum _Stg { new_, contacted, demo, proposal, negotiation, closedWon }

extension _StgX on _Stg {
  String get labelAr => switch (this) {
        _Stg.new_ => 'جديدة',
        _Stg.contacted => 'تم التواصل',
        _Stg.demo => 'عرض تقني',
        _Stg.proposal => 'عرض سعر',
        _Stg.negotiation => 'تفاوض',
        _Stg.closedWon => 'مكسوبة ✓',
      };
  Color get color => switch (this) {
        _Stg.new_ => Colors.grey,
        _Stg.contacted => Colors.blue,
        _Stg.demo => Colors.cyan,
        _Stg.proposal => Colors.orange,
        _Stg.negotiation => const Color(0xFFD4AF37),
        _Stg.closedWon => Colors.green,
      };
}

class _Deal {
  final String id, title, company, owner;
  final double value;
  final _Stg stage;
  final int probability, daysStale;
  const _Deal(this.id, this.title, this.company, this.value, this.stage, this.probability, this.owner, this.daysStale);
}
