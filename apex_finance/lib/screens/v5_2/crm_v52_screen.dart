/// V5.2 — CRM Leads using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class CrmV52Screen extends StatefulWidget {
  const CrmV52Screen({super.key});

  @override
  State<CrmV52Screen> createState() => _CrmV52ScreenState();
}

class _CrmV52ScreenState extends State<CrmV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _leads = <_Lead>[
    _Lead('L-2026-042', 'شركة البناء الحديث', 'خالد العمري', 340000, _Stage.qualified, 75, '2026-04-28'),
    _Lead('L-2026-041', 'مطاعم الواحة الذهبية', 'سعاد الشمراني', 125000, _Stage.proposal, 60, '2026-04-30'),
    _Lead('L-2026-040', 'كلية التقنية المتقدمة', 'د. فهد الزهراني', 890000, _Stage.negotiation, 85, '2026-05-05'),
    _Lead('L-2026-039', 'مؤسسة النور للتجارة', 'أحمد السعيد', 68000, _Stage.lead, 20, '2026-05-15'),
    _Lead('L-2026-038', 'فندق البحر الأبيض', 'نورة المطيري', 240000, _Stage.qualified, 70, '2026-05-02'),
    _Lead('L-2026-037', 'مستشفى الحياة', 'د. عبدالله الفارس', 560000, _Stage.won, 100, '2026-04-18'),
    _Lead('L-2026-036', 'شركة الأسطول للنقل', 'ياسر الحربي', 180000, _Stage.lost, 0, '2026-04-10'),
    _Lead('L-2026-035', 'مركز الأعمال الذكي', 'ريم القحطاني', 95000, _Stage.proposal, 55, '2026-05-08'),
    _Lead('L-2026-034', 'مجموعة الخير للمقاولات', 'طلال الغامدي', 1200000, _Stage.negotiation, 90, '2026-05-01'),
    _Lead('L-2026-033', 'عيادات الصحة المتكاملة', 'د. سارة الدوسري', 310000, _Stage.qualified, 65, '2026-05-10'),
  ];

  List<_Lead> get _filtered => _filter.isEmpty ? _leads : _leads.where((l) => l.stage.name == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'إدارة العملاء المحتملين',
      subtitleAr: 'خط أنابيب المبيعات · ${_leads.length} فرصة',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.kanban,
      savedViews: const [
        SavedView(id: 'mine', labelAr: 'فرصي هذا الشهر', icon: Icons.person, defaultViewMode: ViewMode.kanban),
        SavedView(id: 'hot', labelAr: 'فرص ساخنة >80%', icon: Icons.whatshot, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'big', labelAr: 'صفقات كبيرة >500K', icon: Icons.star, defaultViewMode: ViewMode.kanban, isShared: true),
      ],
      filterChips: [
        FilterChipDef(id: 'lead', labelAr: 'Lead', color: core_theme.AC.td, count: _countFor(_Stage.lead), active: _filter == 'lead'),
        FilterChipDef(id: 'qualified', labelAr: 'Qualified', color: core_theme.AC.info, count: _countFor(_Stage.qualified), active: _filter == 'qualified'),
        FilterChipDef(id: 'proposal', labelAr: 'Proposal', color: core_theme.AC.warn, count: _countFor(_Stage.proposal), active: _filter == 'proposal'),
        FilterChipDef(id: 'negotiation', labelAr: 'Negotiation', color: _gold, count: _countFor(_Stage.negotiation), active: _filter == 'negotiation'),
        FilterChipDef(id: 'won', labelAr: 'Won', color: core_theme.AC.ok, count: _countFor(_Stage.won), active: _filter == 'won'),
        FilterChipDef(id: 'lost', labelAr: 'Lost', color: core_theme.AC.err, count: _countFor(_Stage.lost), active: _filter == 'lost'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'فرصة جديدة',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _countFor(_Stage s) => _leads.where((l) => l.stage == s).length;

  Widget _list() {
    final items = _filtered;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final l = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(width: 4, height: 50, color: l.stage.color),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                  Text(l.company, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(l.contact, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ])),
                Expanded(child: Text('${l.value.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy), textAlign: TextAlign.end)),
                const SizedBox(width: 20),
                SizedBox(width: 100, child: Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: l.probability / 100, minHeight: 8, backgroundColor: core_theme.AC.bdr, color: l.stage.color)),
                  const SizedBox(height: 2),
                  Text('${l.probability}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: l.stage.color)),
                ])),
                const SizedBox(width: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('متوقع الإغلاق', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(l.close, style: const TextStyle(fontSize: 11)),
                ]),
                const SizedBox(width: 16),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: l.stage.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Text(l.stage.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: l.stage.color))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kanban() {
    final columns = <_Stage, List<_Lead>>{};
    for (final s in [_Stage.lead, _Stage.qualified, _Stage.proposal, _Stage.negotiation, _Stage.won]) {
      columns[s] = _leads.where((l) => l.stage == s).toList();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.entries.map((e) {
          final total = e.value.fold<double>(0, (s, l) => s + l.value);
          return Container(
            width: 280,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: e.key.color.withValues(alpha: 0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: e.key.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: e.key.color))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: e.key.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text('${e.value.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: e.key.color))),
                ]),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text('${(total / 1000).toStringAsFixed(0)}K ر.س', style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
              ...e.value.map((l) => Container(
                    margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.id, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
                      Text(l.company, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(l.contact, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${(l.value / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                        const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: e.key.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text('${l.probability}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: e.key.color))),
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

  Widget _chart() {
    final stages = [_Stage.lead, _Stage.qualified, _Stage.proposal, _Stage.negotiation, _Stage.won, _Stage.lost];
    final totals = {for (final s in stages) s: _leads.where((l) => l.stage == s).fold<double>(0, (sum, l) => sum + l.value)};
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('قيمة خط الأنابيب حسب المرحلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...stages.map((s) {
          final value = totals[s]!;
          final pct = max > 0 ? value / max : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s.labelAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${value.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 20, backgroundColor: core_theme.AC.navy3, color: s.color)),
            ]),
          );
        }),
      ]),
    );
  }
}

enum _Stage { lead, qualified, proposal, negotiation, won, lost }

extension _StageX on _Stage {
  String get labelAr => switch (this) {
        _Stage.lead => 'Lead',
        _Stage.qualified => 'مؤهّل',
        _Stage.proposal => 'عرض',
        _Stage.negotiation => 'تفاوض',
        _Stage.won => 'مكسوب',
        _Stage.lost => 'مفقود',
      };
  Color get color => switch (this) {
        _Stage.lead => core_theme.AC.td,
        _Stage.qualified => core_theme.AC.info,
        _Stage.proposal => core_theme.AC.warn,
        _Stage.negotiation => core_theme.AC.gold,
        _Stage.won => core_theme.AC.ok,
        _Stage.lost => core_theme.AC.err,
      };
}

class _Lead {
  final String id, company, contact, close;
  final double value;
  final _Stage stage;
  final int probability;
  const _Lead(this.id, this.company, this.contact, this.value, this.stage, this.probability, this.close);
}
