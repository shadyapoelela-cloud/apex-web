/// V5.2 — Projects using MultiViewTemplate (List / Kanban / Calendar).
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class ProjectsV52Screen extends StatefulWidget {
  const ProjectsV52Screen({super.key});

  @override
  State<ProjectsV52Screen> createState() => _ProjectsV52ScreenState();
}

class _ProjectsV52ScreenState extends State<ProjectsV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _projects = <_Proj>[
    _Proj('P-2026-042', 'مجمّع أبراج الرياض السكنية', 'شركة الإسكان الوطنية', 45000000, 0.62, _St.onTrack, '2026-11-30', 'محمد الخالد', 12),
    _Proj('P-2026-051', 'مركز طبي تخصصي', 'مجموعة الصحة المتكاملة', 18500000, 0.35, _St.atRisk, '2026-08-15', 'سارة المطيري', 8),
    _Proj('P-2026-018', 'تطبيق ERP للجامعة', 'جامعة الملك عبدالعزيز', 3400000, 0.80, _St.onTrack, '2026-06-30', 'أحمد العمري', 5),
    _Proj('P-2026-068', 'تجديد الفندق الملكي', 'فنادق روتانا', 12000000, 0.15, _St.planning, '2026-12-20', 'نورة الدوسري', 6),
    _Proj('P-2026-035', 'نظام إدارة المستودعات', 'شركة الأسطول', 2800000, 0.95, _St.onTrack, '2026-05-10', 'خالد الشمراني', 4),
    _Proj('P-2026-022', 'بناء مدرسة أهلية', 'مجموعة التعليم الحديث', 8500000, 0.45, _St.delayed, '2026-09-01', 'ريم القحطاني', 15),
    _Proj('P-2026-047', 'تحديث البنية التحتية', 'شركة النخيل', 5600000, 0.60, _St.onTrack, '2026-07-31', 'طلال الغامدي', 9),
    _Proj('P-2026-055', 'مصنع للمواد الغذائية', 'مجموعة الخير', 24000000, 0.25, _St.planning, '2027-03-15', 'ياسر الحربي', 18),
    _Proj('P-2026-063', 'تركيب أنظمة طاقة شمسية', 'شركة الطاقة النظيفة', 6800000, 0.70, _St.onTrack, '2026-08-20', 'سعاد الشمراني', 7),
    _Proj('P-2026-029', 'استشارات تحسين العمليات', 'شركة أرامكو للخدمات', 1200000, 1.0, _St.completed, '2026-04-01', 'محمد الخالد', 0),
    _Proj('P-2026-013', 'تطبيق نظام CRM', 'بنك الرياض', 4200000, 1.0, _St.completed, '2026-03-15', 'سارة المطيري', 0),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'المشاريع',
      subtitleAr: '${_projects.length} مشروع · إجمالي ${(_projects.fold<double>(0, (s, p) => s + p.value) / 1e6).toStringAsFixed(0)}M ر.س',
      enabledViews: const {ViewMode.kanban, ViewMode.list, ViewMode.calendar, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'active', labelAr: 'نشطة فقط', icon: Icons.play_circle, defaultViewMode: ViewMode.kanban, isShared: true),
        SavedView(id: 'mine', labelAr: 'مشاريعي', icon: Icons.person, defaultViewMode: ViewMode.list),
        SavedView(id: 'risk', labelAr: 'متأخرة أو بخطر', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'huge', labelAr: 'مشاريع كبرى >10M', icon: Icons.star, defaultViewMode: ViewMode.kanban, isShared: true),
      ],
      filterChips: [
        FilterChipDef(id: 'planning', labelAr: 'تخطيط', color: Colors.grey, count: _cnt(_St.planning), active: _filter == 'planning'),
        FilterChipDef(id: 'onTrack', labelAr: 'على المسار', color: Colors.green, count: _cnt(_St.onTrack), active: _filter == 'onTrack'),
        FilterChipDef(id: 'atRisk', labelAr: 'بخطر', color: Colors.orange, count: _cnt(_St.atRisk), active: _filter == 'atRisk'),
        FilterChipDef(id: 'delayed', labelAr: 'متأخّر', color: Colors.red, count: _cnt(_St.delayed), active: _filter == 'delayed'),
        FilterChipDef(id: 'completed', labelAr: 'مكتمل', color: Colors.blue, count: _cnt(_St.completed), active: _filter == 'completed'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'مشروع جديد',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      calendarBuilder: (_) => _gantt(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_St s) => _projects.where((p) => p.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _projects : _projects.where((p) => p.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 40, color: p.status.color),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: p.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text(p.status.labelAr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: p.status.color))),
                  ]),
                  Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(p.client, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${(p.value / 1e6).toStringAsFixed(1)}M ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                  Text(p.due, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ]),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 4, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: p.progress, minHeight: 10, backgroundColor: Colors.grey.shade200, color: p.status.color))),
                const SizedBox(width: 10),
                Text('${(p.progress * 100).toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const Spacer(),
                Row(children: [
                  CircleAvatar(radius: 10, backgroundColor: _gold.withOpacity(0.15), child: Text(p.pm[0], style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 4),
                  Text(p.pm, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
                const SizedBox(width: 10),
                Row(children: [const Icon(Icons.group, size: 14, color: Colors.black45), const SizedBox(width: 2), Text('${p.team}', style: const TextStyle(fontSize: 11, color: Colors.black54))]),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _kanban() {
    final statuses = [_St.planning, _St.onTrack, _St.atRisk, _St.delayed, _St.completed];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: statuses.map((s) {
          final items = _projects.where((p) => p.status == s).toList();
          final total = items.fold<double>(0, (sum, p) => sum + p.value);
          return Container(
            width: 300,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                child: Row(children: [
                  Icon(s.icon, size: 16, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color)),
                    Text('${(total / 1e6).toStringAsFixed(1)}M ر.س', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
                ]),
              ),
              ...items.map((p) => Container(
                    margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                      Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(p.client, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: p.progress, minHeight: 6, backgroundColor: Colors.grey.shade200, color: s.color)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${(p.value / 1e6).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _gold)),
                        const Spacer(),
                        Text('${(p.progress * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.black54)),
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

  Widget _gantt() {
    // Simple Gantt-like timeline
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الجدول الزمني (Gantt)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: _projects.where((p) => p.status != _St.completed).map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('استحقاق ${p.due}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
                const SizedBox(height: 6),
                Stack(children: [
                  Container(height: 22, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: p.progress,
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.status.color, p.status.color.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(child: Text('${(p.progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                    ),
                  ),
                ]),
              ]),
            );
          }).toList()),
        ),
      ]),
    );
  }

  Widget _chart() {
    final statuses = [_St.planning, _St.onTrack, _St.atRisk, _St.delayed, _St.completed];
    final totals = {for (final s in statuses) s: _projects.where((p) => p.status == s).fold<double>(0, (sum, p) => sum + p.value)};
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('توزيع المشاريع حسب الحالة (بالقيمة)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...statuses.map((s) {
          final value = totals[s]!;
          final pct = max > 0 ? value / max : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(s.icon, color: s.color, size: 16),
                const SizedBox(width: 8),
                Text(s.labelAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${(value / 1e6).toStringAsFixed(1)}M ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 20, backgroundColor: Colors.grey.shade100, color: s.color)),
            ]),
          );
        }),
      ]),
    );
  }
}

enum _St { planning, onTrack, atRisk, delayed, completed }

extension _StX on _St {
  String get labelAr => switch (this) {
        _St.planning => 'تخطيط',
        _St.onTrack => 'على المسار ✓',
        _St.atRisk => 'بخطر',
        _St.delayed => 'متأخّر',
        _St.completed => 'مكتمل',
      };
  Color get color => switch (this) {
        _St.planning => Colors.grey,
        _St.onTrack => Colors.green,
        _St.atRisk => Colors.orange,
        _St.delayed => Colors.red,
        _St.completed => Colors.blue,
      };
  IconData get icon => switch (this) {
        _St.planning => Icons.edit_calendar,
        _St.onTrack => Icons.check_circle,
        _St.atRisk => Icons.warning,
        _St.delayed => Icons.error,
        _St.completed => Icons.task_alt,
      };
}

class _Proj {
  final String id, name, client, due, pm;
  final double value, progress;
  final _St status;
  final int team;
  const _Proj(this.id, this.name, this.client, this.value, this.progress, this.status, this.due, this.pm, this.team);
}
