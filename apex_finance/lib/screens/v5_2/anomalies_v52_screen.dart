/// V5.2 — AI Anomaly Detector using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class AnomaliesV52Screen extends StatefulWidget {
  const AnomaliesV52Screen({super.key});

  @override
  State<AnomaliesV52Screen> createState() => _AnomaliesV52ScreenState();
}

class _AnomaliesV52ScreenState extends State<AnomaliesV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);
  String _filter = '';

  static const _items = <_An>[
    _An('A-001', 'قيد ليلي JE-2026-4218', 'معاملة بعد ساعات العمل — 23:47', 45000, 'سارة علي', '2026-04-19', _Sev.high, _Kind.unusualTime, 0.94),
    _An('A-002', 'مبلغ مربّع رقمياً (round number)', 'مبلغ 500,000 بالضبط — نادر', 500000, 'أحمد محمد', '2026-04-18', _Sev.medium, _Kind.roundAmount, 0.82),
    _An('A-003', 'تكرار قيد متشابه', '3 قيود بنفس المبلغ في يوم واحد', 22000, 'النظام', '2026-04-18', _Sev.high, _Kind.duplicate, 0.97),
    _An('A-004', 'معاملة خارج النطاق المعتاد', 'مبلغ أعلى من المتوسط بـ 5 انحرافات', 1200000, 'خالد إبراهيم', '2026-04-17', _Sev.critical, _Kind.outlier, 0.99),
    _An('A-005', 'موظف جديد ينشئ قيود كبيرة', '3 قيود >100K من موظف عُيّن منذ شهر', 340000, 'محمد السعيد', '2026-04-17', _Sev.high, _Kind.newUser, 0.88),
    _An('A-006', 'تسلسل كسور غير معتادة', 'مبلغ 19,999.97 — مشبوه', 19999.97, 'ليلى أحمد', '2026-04-16', _Sev.medium, _Kind.oddPattern, 0.76),
    _An('A-007', 'عكس قيد تلقائي', 'قيد ثم عكسه خلال 5 دقائق', 85000, 'النظام', '2026-04-16', _Sev.medium, _Kind.autoReverse, 0.85),
    _An('A-008', 'مرجع متكرّر لـ 3 فواتير', 'نفس المرجع BANK-8845 ظهر 3 مرات', 68000, 'سارة علي', '2026-04-15', _Sev.high, _Kind.duplicate, 0.93),
    _An('A-009', 'معاملة نهاية الأسبوع', 'دفعة كبيرة يوم الجمعة', 420000, 'عمر حسن', '2026-04-15', _Sev.low, _Kind.weekend, 0.68),
    _An('A-010', 'تغيير سريع في الحد', 'حد ائتمان زاد 300% خلال ساعة', 1500000, 'يوسف عمر', '2026-04-14', _Sev.critical, _Kind.suddenChange, 0.96),
    _An('A-011', 'حساب غير مستخدم فجأة ينشط', 'حساب 1510 (استثمارات) لم يُستخدم 6 أشهر', 890000, 'د. محمد', '2026-04-13', _Sev.medium, _Kind.dormantAccount, 0.81),
    _An('A-012', 'نمط دفع غير مألوف', 'مورد جديد — أول دفعة 5x المتوسط', 280000, 'ليلى أحمد', '2026-04-12', _Sev.medium, _Kind.unusualVendor, 0.79),
  ];

  @override
  Widget build(BuildContext context) {
    final critical = _items.where((i) => i.severity == _Sev.critical).length;
    final total = _items.fold<double>(0, (s, i) => s + i.amount);
    return MultiViewTemplate(
      titleAr: 'كاشف الشذوذ بالذكاء الاصطناعي',
      subtitleAr: 'Claude Opus · ${_items.length} تنبيه · $critical حرج · قيمة إجمالية ${(total / 1e6).toStringAsFixed(1)}M ر.س',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'critical', labelAr: 'الحرجة فقط', icon: Icons.priority_high, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'today', labelAr: 'اليوم', icon: Icons.today, defaultViewMode: ViewMode.list),
        SavedView(id: 'high-conf', labelAr: 'ثقة >90%', icon: Icons.verified, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'critical', labelAr: 'حرج', color: core_theme.AC.err, count: _cnt(_Sev.critical), active: _filter == 'critical'),
        FilterChipDef(id: 'high', labelAr: 'عالٍ', color: core_theme.AC.warn, count: _cnt(_Sev.high), active: _filter == 'high'),
        FilterChipDef(id: 'medium', labelAr: 'متوسط', color: _gold, count: _cnt(_Sev.medium), active: _filter == 'medium'),
        FilterChipDef(id: 'low', labelAr: 'منخفض', color: core_theme.AC.info, count: _cnt(_Sev.low), active: _filter == 'low'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'قاعدة كشف جديدة',
      headerActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.settings, size: 14), label: Text('إعدادات AI')),
      ],
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_Sev s) => _items.where((i) => i.severity == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _items : _items.where((i) => i.severity.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: a.severity.color.withOpacity(0.3), width: a.severity == _Sev.critical ? 2 : 1)),
          child: Row(children: [
            Container(width: 4, height: 60, color: a.severity.color),
            const SizedBox(width: 12),
            Container(width: 44, height: 44, decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.psychology, color: _purple)),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(a.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _purple.withOpacity(0.08), borderRadius: BorderRadius.circular(4)), child: Text(a.kind.labelAr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _purple))),
              ]),
              Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              Text(a.description, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.4)),
              const SizedBox(height: 4),
              Text('الفاعل: ${a.actor} · ${a.date}', style: TextStyle(fontSize: 10, color: core_theme.AC.td)),
            ])),
            Text('${a.amount >= 1 ? a.amount.toStringAsFixed(0) : a.amount.toStringAsFixed(2)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('ثقة AI', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${(a.confidence * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: a.confidence >= 0.9 ? core_theme.AC.err : a.confidence >= 0.8 ? core_theme.AC.warn : core_theme.AC.info)),
            ]),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: a.severity.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(a.severity.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: a.severity.color))),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero), child: Text('تجاهل', style: TextStyle(fontSize: 11))),
            const SizedBox(width: 6),
            FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 10)), icon: const Icon(Icons.search, size: 14), label: Text('تحقيق', style: TextStyle(fontSize: 11))),
          ]),
        );
      },
    );
  }

  Widget _kanban() {
    final cols = [_Sev.critical, _Sev.high, _Sev.medium, _Sev.low];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols.map((s) {
        final items = _items.where((i) => i.severity == s).toList();
        return Container(
          width: 280,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Icon(Icons.warning_amber, color: s.color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${s.labelAr} (${items.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color))),
            ])),
            ...items.map((a) => Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(a.id, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
                  const Spacer(),
                  Text('${(a.confidence * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: s.color)),
                ]),
                Text(a.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(a.description, style: TextStyle(fontSize: 9, color: core_theme.AC.ts), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            )),
            const SizedBox(height: 8),
          ]),
        );
      }).toList()),
    );
  }

  Widget _chart() {
    final byKind = <_Kind, int>{};
    for (final a in _items) {
      byKind[a.kind] = (byKind[a.kind] ?? 0) + 1;
    }
    final max = byKind.values.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('توزيع الشذوذات حسب النوع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...byKind.entries.map((e) {
          final pct = e.value / max;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            SizedBox(width: 160, child: Text(e.key.labelAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 20, backgroundColor: core_theme.AC.navy3, color: _purple))),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: Text('${e.value} تنبيه', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _purple), textAlign: TextAlign.end)),
          ]));
        }),
      ]),
    );
  }
}

enum _Sev { critical, high, medium, low }
enum _Kind { unusualTime, roundAmount, duplicate, outlier, newUser, oddPattern, autoReverse, weekend, suddenChange, dormantAccount, unusualVendor }

extension _SevX on _Sev {
  String get labelAr => switch (this) {
        _Sev.critical => 'حرج',
        _Sev.high => 'عالٍ',
        _Sev.medium => 'متوسط',
        _Sev.low => 'منخفض',
      };
  Color get color => switch (this) {
        _Sev.critical => core_theme.AC.err,
        _Sev.high => core_theme.AC.warn,
        _Sev.medium => core_theme.AC.gold,
        _Sev.low => core_theme.AC.info,
      };
}

extension _KindX on _Kind {
  String get labelAr => switch (this) {
        _Kind.unusualTime => 'وقت غير معتاد',
        _Kind.roundAmount => 'مبلغ مُكتمل',
        _Kind.duplicate => 'تكرار',
        _Kind.outlier => 'قيمة شاذة',
        _Kind.newUser => 'مستخدم جديد',
        _Kind.oddPattern => 'نمط غريب',
        _Kind.autoReverse => 'عكس تلقائي',
        _Kind.weekend => 'نهاية أسبوع',
        _Kind.suddenChange => 'تغيير فجائي',
        _Kind.dormantAccount => 'حساب خامل',
        _Kind.unusualVendor => 'مورد غير مألوف',
      };
}

class _An {
  final String id, title, description, actor, date;
  final double amount, confidence;
  final _Sev severity;
  final _Kind kind;
  const _An(this.id, this.title, this.description, this.amount, this.actor, this.date, this.severity, this.kind, this.confidence);
}
