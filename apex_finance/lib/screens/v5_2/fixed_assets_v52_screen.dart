/// V5.2 — Fixed Assets Register using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class FixedAssetsV52Screen extends StatefulWidget {
  const FixedAssetsV52Screen({super.key});

  @override
  State<FixedAssetsV52Screen> createState() => _FixedAssetsV52ScreenState();
}

class _FixedAssetsV52ScreenState extends State<FixedAssetsV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _assets = <_Asset>[
    _Asset('FA-2024-001', 'مبنى المقر الرئيسي - الرياض', 'عقارات', 18500000, 0.15, '2024-03-01', 40, _S.active, 'الرياض'),
    _Asset('FA-2024-002', 'سيارات الإدارة (8 سيارات)', 'مركبات', 1200000, 0.35, '2024-05-15', 5, _S.active, 'الرياض'),
    _Asset('FA-2024-003', 'أثاث مكتبي', 'أثاث', 340000, 0.42, '2024-02-10', 10, _S.active, 'الرياض'),
    _Asset('FA-2024-004', 'خادم رئيسي + Storage', 'تقنية', 680000, 0.58, '2024-06-20', 5, _S.active, 'الرياض'),
    _Asset('FA-2024-005', 'أجهزة كمبيوتر (120)', 'تقنية', 420000, 0.65, '2024-07-01', 4, _S.active, 'الرياض'),
    _Asset('FA-2024-006', 'معدات تكييف مركزي', 'معدات', 580000, 0.22, '2023-11-15', 15, _S.active, 'الرياض'),
    _Asset('FA-2024-007', 'مولد كهربائي احتياطي', 'معدات', 240000, 0.18, '2024-01-20', 20, _S.active, 'الرياض'),
    _Asset('FA-2024-008', 'فرع جدة - مبنى مستأجر', 'عقارات (إيجار)', 0, 0, '2024-08-01', 10, _S.active, 'جدة'),
    _Asset('FA-2024-009', 'معرض الرياض - تجهيزات', 'أثاث', 180000, 0.28, '2024-04-10', 7, _S.active, 'الرياض'),
    _Asset('FA-2023-042', 'طابعات ليزر (16)', 'تقنية', 85000, 0.82, '2022-03-15', 5, _S.fullyDepreciated, 'متعدد'),
    _Asset('FA-2024-010', 'أجهزة أمن ومراقبة', 'أمن', 220000, 0.15, '2024-09-01', 8, _S.active, 'متعدد'),
    _Asset('FA-2023-038', 'سيارة مبيعات', 'مركبات', 95000, 1.0, '2020-05-01', 5, _S.disposed, 'بيعت'),
  ];

  @override
  Widget build(BuildContext context) {
    final totalCost = _assets.fold<double>(0, (s, a) => s + a.cost);
    final totalDep = _assets.fold<double>(0, (s, a) => s + (a.cost * a.depPct));
    final netBook = totalCost - totalDep;
    return MultiViewTemplate(
      titleAr: 'سجل الأصول الثابتة',
      subtitleAr: '${_assets.length} أصل · قيمة دفترية ${(netBook / 1e6).toStringAsFixed(1)}M ر.س · مُهلك ${(totalDep / 1e6).toStringAsFixed(1)}M',
      enabledViews: const {ViewMode.list, ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'all', labelAr: 'الكل', icon: Icons.list, defaultViewMode: ViewMode.list),
        SavedView(id: 'near-dep', labelAr: 'قرب الإهلاك الكامل >80%', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'real-estate', labelAr: 'عقارات فقط', icon: Icons.apartment, defaultViewMode: ViewMode.list),
        SavedView(id: 'tech', labelAr: 'تقنية فقط', icon: Icons.computer, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'active', labelAr: 'نشطة', color: core_theme.AC.ok, count: _count(_S.active), active: _filter == 'active'),
        FilterChipDef(id: 'fullyDepreciated', labelAr: 'مهلك كاملاً', color: core_theme.AC.warn, count: _count(_S.fullyDepreciated), active: _filter == 'fullyDepreciated'),
        FilterChipDef(id: 'disposed', labelAr: 'مُبيعة/متخلّص منها', color: core_theme.AC.td, count: _count(_S.disposed), active: _filter == 'disposed'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'أصل جديد',
      listBuilder: (_) => _list(),
      pivotBuilder: (_) => _byCategory(),
      chartBuilder: (_) => _depChart(),
    );
  }

  int _count(_S s) => _assets.where((a) => a.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _assets : _assets.where((a) => a.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final a = items[i];
        final netBook = a.cost * (1 - a.depPct);
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 4, height: 56, color: a.status.color),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(a.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(4)), child: Text(a.category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: core_theme.AC.ts))),
              ]),
              Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('📍 ${a.location} · شراء ${a.purchaseDate} · عمر ${a.lifeYears} سنة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('التكلفة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${a.cost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ])),
            const SizedBox(width: 16),
            SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('القيمة الدفترية', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text(netBook.toStringAsFixed(0), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: a.status == _S.disposed ? core_theme.AC.td : _gold)),
            ])),
            const SizedBox(width: 16),
            SizedBox(width: 100, child: Column(children: [
              Row(children: [Text('إهلاك', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)), const Spacer(), Text('${(a.depPct * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 2),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: a.depPct, minHeight: 6, backgroundColor: core_theme.AC.bdr, color: a.depPct > 0.8 ? core_theme.AC.warn : _navy)),
            ])),
          ])),
        );
      },
    );
  }

  Widget _byCategory() {
    final cats = <String, (double, double, int)>{};
    for (final a in _assets) {
      final cur = cats[a.category] ?? (0.0, 0.0, 0);
      cats[a.category] = (cur.$1 + a.cost, cur.$2 + (a.cost * a.depPct), cur.$3 + 1);
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('توزيع الأصول حسب الفئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: _navy,
                child: const Row(children: [
                  Expanded(flex: 2, child: Text('الفئة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                  Expanded(child: Text('العدد', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                  Expanded(child: Text('التكلفة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                  Expanded(child: Text('الإهلاك', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                  Expanded(child: Text('القيمة الدفترية', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                ]),
              ),
              ...cats.entries.map((e) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.bdr))),
                    child: Row(children: [
                      Expanded(flex: 2, child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('${e.value.$3}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(child: Text(e.value.$1.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                      Expanded(child: Text(e.value.$2.toStringAsFixed(0), style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.warn), textAlign: TextAlign.end)),
                      Expanded(child: Text((e.value.$1 - e.value.$2).toStringAsFixed(0), style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: _gold), textAlign: TextAlign.end)),
                    ]),
                  )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _depChart() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('توقّع الإهلاك لـ 5 سنوات قادمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...[
          ('2026', 1840, 0.8),
          ('2027', 1840, 0.85),
          ('2028', 1680, 0.78),
          ('2029', 1560, 0.72),
          ('2030', 1420, 0.65),
        ].map((y) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 60, child: Text(y.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: y.$3, minHeight: 22, backgroundColor: core_theme.AC.navy3, color: _gold))),
                const SizedBox(width: 10),
                SizedBox(width: 120, child: Text('${y.$2}K ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold), textAlign: TextAlign.end)),
              ]),
            ]))),
      ]),
    );
  }
}

enum _S { active, fullyDepreciated, disposed }

extension _SX on _S {
  Color get color => switch (this) {
        _S.active => core_theme.AC.ok,
        _S.fullyDepreciated => core_theme.AC.warn,
        _S.disposed => core_theme.AC.td,
      };
}

class _Asset {
  final String id, name, category, purchaseDate, location;
  final double cost, depPct;
  final int lifeYears;
  final _S status;
  const _Asset(this.id, this.name, this.category, this.cost, this.depPct, this.purchaseDate, this.lifeYears, this.status, this.location);
}
