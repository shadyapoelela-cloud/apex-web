/// V5.2 — Enterprise Risk Register using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class RiskRegisterV52Screen extends StatefulWidget {
  const RiskRegisterV52Screen({super.key});

  @override
  State<RiskRegisterV52Screen> createState() => _RiskRegisterV52ScreenState();
}

class _RiskRegisterV52ScreenState extends State<RiskRegisterV52Screen> {
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _risks = <_Risk>[
    _Risk('R-001', 'تقلبات أسعار العملات الأجنبية', 'مالية', 4, 5, _St.open, 'خالد الشمراني', '2026-05-15'),
    _Risk('R-002', 'انقطاع سلسلة التوريد', 'تشغيلية', 5, 4, _St.mitigating, 'سارة علي', '2026-06-01'),
    _Risk('R-003', 'ثغرة في النظام الأمني', 'تقنية', 3, 5, _St.open, 'يوسف عمر', '2026-04-25'),
    _Risk('R-004', 'تغييرات تشريعية (ZATCA)', 'تنظيمية', 4, 3, _St.monitoring, 'أحمد محمد', '2026-07-01'),
    _Risk('R-005', 'فقدان موظفين رئيسيين', 'موارد بشرية', 3, 4, _St.mitigating, 'ليلى أحمد', '2026-06-15'),
    _Risk('R-006', 'تأخير مشروع رئيسي', 'تشغيلية', 4, 4, _St.open, 'محمد الخالد', '2026-05-30'),
    _Risk('R-007', 'احتيال داخلي', 'مالية', 2, 5, _St.mitigating, 'نورة الدوسري', '2026-12-31'),
    _Risk('R-008', 'عدم امتثال GOSI', 'تنظيمية', 2, 3, _St.closed, 'سامي طارق', '2026-04-01'),
    _Risk('R-009', 'تلف بيانات (Data Loss)', 'تقنية', 2, 5, _St.mitigating, 'يوسف عمر', '2026-05-20'),
    _Risk('R-010', 'كساد اقتصادي', 'استراتيجية', 3, 5, _St.monitoring, 'د. محمد الراجحي', '2026-12-31'),
    _Risk('R-011', 'سوء سمعة العلامة التجارية', 'استراتيجية', 2, 4, _St.monitoring, 'دينا حسام', '2026-09-01'),
    _Risk('R-012', 'عدم كفاية التأمين', 'مالية', 2, 3, _St.closed, 'سارة علي', '2026-03-15'),
  ];

  @override
  Widget build(BuildContext context) {
    final high = _risks.where((r) => r.score >= 15).length;
    final open = _risks.where((r) => r.status == _St.open).length;
    return MultiViewTemplate(
      titleAr: 'سجل المخاطر المؤسسي',
      subtitleAr: '${_risks.length} مخاطرة · $high عالية · $open مفتوحة',
      enabledViews: const {ViewMode.list, ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.pivot,
      savedViews: const [
        SavedView(id: 'high', labelAr: 'مخاطر عالية فقط', icon: Icons.priority_high, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'mine', labelAr: 'مخاطري المسؤول عنها', icon: Icons.person, defaultViewMode: ViewMode.list),
        SavedView(id: 'tech', labelAr: 'مخاطر تقنية', icon: Icons.computer, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'open', labelAr: 'مفتوحة', color: core_theme.AC.err, count: _count(_St.open), active: _filter == 'open'),
        FilterChipDef(id: 'mitigating', labelAr: 'قيد المعالجة', color: core_theme.AC.warn, count: _count(_St.mitigating), active: _filter == 'mitigating'),
        FilterChipDef(id: 'monitoring', labelAr: 'قيد المراقبة', color: core_theme.AC.info, count: _count(_St.monitoring), active: _filter == 'monitoring'),
        FilterChipDef(id: 'closed', labelAr: 'مغلقة', color: core_theme.AC.ok, count: _count(_St.closed), active: _filter == 'closed'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'مخاطرة جديدة',
      listBuilder: (_) => _list(),
      pivotBuilder: (_) => _matrix(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _count(_St s) => _risks.where((r) => r.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _risks : _risks.where((r) => r.status.name == _filter).toList();
    items.sort((a, b) => b.score.compareTo(a.score));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = items[i];
        final scoreColor = _scoreColor(r.score);
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: scoreColor, width: 2)), child: Center(child: Text('${r.score}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor)))),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(r.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(4)), child: Text(r.category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: core_theme.AC.ts))),
              ]),
              Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text('المسؤول: ${r.owner} · مراجعة ${r.reviewDate}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('الاحتمال ', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)), ..._dots(r.likelihood, core_theme.AC.warn)]),
              Row(children: [Text('الأثر    ', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)), ..._dots(r.impact, core_theme.AC.err)]),
            ])),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: r.status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Text(r.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: r.status.color))),
          ])),
        );
      },
    );
  }

  List<Widget> _dots(int count, Color color) => List.generate(5, (i) => Padding(padding: const EdgeInsets.only(right: 1), child: Icon(Icons.circle, size: 8, color: i < count ? color : core_theme.AC.bdr)));

  Widget _matrix() {
    // 5x5 risk heatmap (Likelihood × Impact)
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مصفوفة المخاطر (Heatmap)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        Text('الاحتمال (Likelihood) × الأثر (Impact)', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 20),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Y-axis label (Likelihood)
            RotatedBox(quarterTurns: 1, child: Padding(padding: EdgeInsets.all(8), child: Text('الاحتمال ←', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.ts)))),
            const SizedBox(width: 8),
            Expanded(child: Column(children: [
              // Rows: Likelihood 5 down to 1
              for (int l = 5; l >= 1; l--)
                Expanded(child: Row(children: [
                  SizedBox(width: 20, child: Text('$l', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.ts), textAlign: TextAlign.center)),
                  for (int imp = 1; imp <= 5; imp++)
                    Expanded(child: _matrixCell(l, imp)),
                ])),
              // X-axis labels
              Row(children: [
                const SizedBox(width: 20),
                for (int imp = 1; imp <= 5; imp++)
                  Expanded(child: Center(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('$imp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.ts))))),
              ]),
              const SizedBox(height: 4),
              Text('الأثر (Impact) →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.ts)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendDot(core_theme.AC.ok, 'منخفضة (1-6)'),
          const SizedBox(width: 16),
          _legendDot(core_theme.AC.warn, 'متوسطة (7-14)'),
          const SizedBox(width: 16),
          _legendDot(core_theme.AC.err, 'عالية (15-25)'),
        ]),
      ]),
    );
  }

  Widget _matrixCell(int likelihood, int impact) {
    final risksHere = _risks.where((r) => r.likelihood == likelihood && r.impact == impact).toList();
    final score = likelihood * impact;
    final cellColor = _scoreColor(score);
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: cellColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: cellColor.withValues(alpha: 0.4))),
      child: risksHere.isEmpty
          ? Center(child: Text('$score', style: TextStyle(fontSize: 9, color: cellColor.withValues(alpha: 0.6))))
          : Tooltip(
              message: risksHere.map((r) => r.title).join('\n'),
              child: Center(child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: cellColor, shape: BoxShape.circle),
                child: Text('${risksHere.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              )),
            ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 11))]);

  Color _scoreColor(int score) {
    if (score >= 15) return core_theme.AC.err;
    if (score >= 7) return core_theme.AC.warn;
    return core_theme.AC.ok;
  }

  Widget _chart() {
    final categories = <String, int>{};
    for (final r in _risks) {
      categories[r.category] = (categories[r.category] ?? 0) + 1;
    }
    final max = categories.values.reduce((a, b) => a > b ? a : b);
    final colors = [core_theme.AC.err, core_theme.AC.warn, core_theme.AC.info, core_theme.AC.purple, _navy];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('المخاطر حسب الفئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...categories.entries.toList().asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          final pct = max > 0 ? entry.value / max : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Text('${entry.value} مخاطرة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors[idx % colors.length]))]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 20, backgroundColor: core_theme.AC.navy3, color: colors[idx % colors.length])),
          ]));
        }),
      ]),
    );
  }
}

enum _St { open, mitigating, monitoring, closed }

extension _StX on _St {
  String get labelAr => switch (this) {
        _St.open => 'مفتوحة',
        _St.mitigating => 'قيد المعالجة',
        _St.monitoring => 'قيد المراقبة',
        _St.closed => 'مغلقة',
      };
  Color get color => switch (this) {
        _St.open => core_theme.AC.err,
        _St.mitigating => core_theme.AC.warn,
        _St.monitoring => core_theme.AC.info,
        _St.closed => core_theme.AC.ok,
      };
}

class _Risk {
  final String id, title, category, owner, reviewDate;
  final int likelihood, impact;
  final _St status;
  const _Risk(this.id, this.title, this.category, this.likelihood, this.impact, this.status, this.owner, this.reviewDate);

  int get score => likelihood * impact;
}
