/// V5.2 — Period Close using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class PeriodCloseV52Screen extends StatelessWidget {
  const PeriodCloseV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'إقفال الفترة — أبريل 2026',
      subtitleAr: 'عمليات الإقفال الشهري · 18 من 26 مهمة مكتملة · متبقي 3 أيام',
      statusLabelAr: 'قيد الإقفال',
      statusColor: core_theme.AC.warn,
      processStages: const [
        ProcessStage(labelAr: 'Pre-Close'),
        ProcessStage(labelAr: 'Accruals'),
        ProcessStage(labelAr: 'Review'),
        ProcessStage(labelAr: 'Post-Close'),
        ProcessStage(labelAr: 'Reports'),
      ],
      processCurrentIndex: 2,
      smartButtons: [
        SmartButton(icon: Icons.checklist, labelAr: 'مهمة', count: 26, color: _gold),
        SmartButton(icon: Icons.check_circle, labelAr: 'مكتملة', count: 18, color: core_theme.AC.ok),
        SmartButton(icon: Icons.pending, labelAr: 'قيد التنفيذ', count: 5, color: core_theme.AC.warn),
        SmartButton(icon: Icons.error, labelAr: 'متأخرة', count: 3, color: core_theme.AC.err),
        SmartButton(icon: Icons.edit_note, labelAr: 'قيد تسوية', count: 12, color: _navy),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.share, size: 16), label: Text('مشاركة التقدّم')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.lock, size: 16),
          label: Text('إقفال الفترة'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'progress', labelAr: 'تقدّم الإقفال', icon: Icons.dashboard, builder: (_) => _progress()),
        ObjectPageTab(id: 'tasks', labelAr: 'المهام', icon: Icons.checklist, builder: (_) => _tasks()),
        ObjectPageTab(id: 'journals', labelAr: 'قيود التسوية', icon: Icons.edit_note, builder: (_) => _journals()),
        ObjectPageTab(id: 'recon', labelAr: 'المطابقات', icon: Icons.compare_arrows, builder: (_) => _recon()),
        ObjectPageTab(id: 'reports', labelAr: 'التقارير', icon: Icons.assessment, builder: (_) => _reports()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'سارة علي', contentAr: 'اكتمل الفحص البنكي لجميع الحسابات · جاهزة للمطابقة', timestamp: DateTime.now().subtract(const Duration(hours: 1)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'AI Guardrails', contentAr: '⚠️ 3 قيود كبيرة فوق 100K تحتاج موافقة إضافية', timestamp: DateTime.now().subtract(const Duration(hours: 4)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'أحمد محمد', contentAr: '@سارة — رجاءً راجعي قيد الاستحقاق رقم JE-4218', timestamp: DateTime.now().subtract(const Duration(hours: 6)), kind: ChatterKind.message),
      ],
    );
  }

  Widget _progress() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card('الخط الزمني للإقفال', Column(children: [
          _timelineRow('1. إقفال الأنظمة الفرعية', true, '2026-04-20', '14 مهمة'),
          _timelineRow('2. قيود الاستحقاق والتسوية', true, '2026-04-21', '6 قيود'),
          _timelineRow('3. مطابقة الحسابات', false, '2026-04-22', '8 حسابات (5 من 8)'),
          _timelineRow('4. مراجعة المدير المالي', false, '2026-04-23', 'قيد الانتظار'),
          _timelineRow('5. إقفال الفترة وترحيل', false, '2026-04-24', 'قيد الانتظار'),
          _timelineRow('6. إصدار القوائم المالية', false, '2026-04-25', 'قيد الانتظار'),
        ])),
        const SizedBox(height: 16),
        _card('إحصائيات الإقفال', Row(children: [
          Expanded(child: _stat('مكتمل', '18', core_theme.AC.ok, Icons.check_circle)),
          const SizedBox(width: 10),
          Expanded(child: _stat('قيد التنفيذ', '5', core_theme.AC.warn, Icons.pending)),
          const SizedBox(width: 10),
          Expanded(child: _stat('متأخّر', '3', core_theme.AC.err, Icons.warning)),
          const SizedBox(width: 10),
          Expanded(child: _stat('لم يبدأ', '0', core_theme.AC.td, Icons.schedule)),
        ])),
        const SizedBox(height: 16),
        _card('تقدّم الإقفال العام', Column(children: [
          Row(children: [Text('النسبة العامة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Text('69%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _gold))]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 0.69, minHeight: 16, backgroundColor: core_theme.AC.bdr, color: _gold)),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.schedule, size: 14, color: core_theme.AC.ts),
            SizedBox(width: 6),
            Text('الوقت المتبقي: 3 أيام 8 ساعات', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            Spacer(),
            Icon(Icons.verified, size: 14, color: core_theme.AC.ok),
            SizedBox(width: 6),
            Text('على المسار الصحيح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: core_theme.AC.ok)),
          ]),
        ])),
      ]),
    );
  }

  Widget _timelineRow(String title, bool done, String date, String note) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.bdr))),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? core_theme.AC.ok : core_theme.AC.td, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: done ? core_theme.AC.tp : core_theme.AC.ts)),
          Text('$date · $note', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        if (done) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text('✓ مكتمل', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.ok))),
      ]),
    );
  }

  Widget _tasks() {
    const tasks = [
      ('1.1', 'إقفال المبيعات', 'سارة علي', true, 'Pre-Close'),
      ('1.2', 'إقفال المشتريات', 'أحمد محمد', true, 'Pre-Close'),
      ('1.3', 'إقفال المخزون', 'خالد إبراهيم', true, 'Pre-Close'),
      ('1.4', 'إقفال الرواتب', 'ليلى أحمد', true, 'Pre-Close'),
      ('2.1', 'قيد استحقاق الإيجارات', 'أحمد محمد', true, 'Accruals'),
      ('2.2', 'قيد استحقاق الفوائد', 'أحمد محمد', true, 'Accruals'),
      ('2.3', 'قيد الإهلاك الشهري', 'سارة علي', true, 'Accruals'),
      ('2.4', 'قيد الضريبة المؤجلة', 'أحمد محمد', false, 'Accruals'),
      ('3.1', 'مطابقة النقدية والبنوك', 'سارة علي', false, 'Review'),
      ('3.2', 'مطابقة الذمم المدينة', 'خالد إبراهيم', false, 'Review'),
      ('3.3', 'مطابقة الذمم الدائنة', 'ليلى أحمد', false, 'Review'),
      ('3.4', 'فحص القيود الشاذة بـ AI', 'AI Guardrails', false, 'Review'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Checkbox(value: tasks[i].$4, onChanged: (_) {}, activeColor: _gold, visualDensity: VisualDensity.compact),
          SizedBox(width: 40, child: Text(tasks[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts))),
          Expanded(flex: 3, child: Text(tasks[i].$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, decoration: tasks[i].$4 ? TextDecoration.lineThrough : null, color: tasks[i].$4 ? core_theme.AC.ts : core_theme.AC.tp))),
          Text(tasks[i].$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Text(tasks[i].$5, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
        ]),
      ),
    );
  }

  Widget _journals() {
    const jes = [
      ('JE-4218', 'استحقاق فواتير خدمات مستحقة', 45000, false),
      ('JE-4219', 'استحقاق إيجار مكتب الرياض', 28000, true),
      ('JE-4220', 'إهلاك شهر أبريل', 120000, true),
      ('JE-4221', 'احتياطي ديون مشكوك فيها', 15000, true),
      ('JE-4222', 'استحقاق مكافآت الموظفين', 85000, false),
      ('JE-4223', 'الضريبة المؤجلة الشهرية', 22000, false),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: jes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: jes[i].$4 ? core_theme.AC.ok.withValues(alpha: 0.3) : core_theme.AC.warn.withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(jes[i].$4 ? Icons.check_circle : Icons.pending, color: jes[i].$4 ? core_theme.AC.ok : core_theme.AC.warn),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(jes[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
            Text(jes[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
          Text('${jes[i].$3.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _gold)),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (jes[i].$4 ? core_theme.AC.ok : core_theme.AC.warn).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(jes[i].$4 ? 'مرحّل' : 'قيد الاعتماد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: jes[i].$4 ? core_theme.AC.ok : core_theme.AC.warn))),
        ]),
      ),
    );
  }

  Widget _recon() {
    const recs = [
      ('بنك الرياض', 1240000.0, 1240000.0, 0, true),
      ('بنك الراجحي', 890000.0, 890000.0, 0, true),
      ('بنك الأهلي', 820000.0, 820000.0, 0, true),
      ('بنك HSBC', 290000.0, 335000.0, -45000, false),
      ('ذمم مدينة', 4580000.0, 4580000.0, 0, true),
      ('ذمم دائنة', 2840000.0, 2860000.0, -20000, false),
      ('مخزون', 2890000.0, 2890000.0, 0, true),
      ('ضرائب مستحقة', 680000.0, 680000.0, 0, true),
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(10), color: _navy, child: const Row(children: [
            Expanded(flex: 2, child: Text('الحساب', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
            Expanded(child: Text('الميزان', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            Expanded(child: Text('المصدر', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            Expanded(child: Text('الفرق', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            SizedBox(width: 100, child: Text('الحالة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          ])),
          ...recs.map((r) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.bdr))),
                child: Row(children: [
                  Expanded(flex: 2, child: Text(r.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Expanded(child: Text(r.$2.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                  Expanded(child: Text(r.$3.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                  Expanded(child: Text(r.$4 == 0 ? '0' : r.$4.toString(), style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: r.$4 == 0 ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.end)),
                  SizedBox(width: 100, child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (r.$5 ? core_theme.AC.ok : core_theme.AC.warn).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(r.$5 ? '✓ مطابق' : 'تسوية', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: r.$5 ? core_theme.AC.ok : core_theme.AC.warn))))),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _reports() {
    const reports = [
      ('ميزان المراجعة', 'Trial Balance', true, Icons.table_chart),
      ('قائمة المركز المالي', 'Balance Sheet', true, Icons.balance),
      ('قائمة الأرباح والخسائر', 'Income Statement', true, Icons.trending_up),
      ('قائمة التدفقات النقدية', 'Cash Flow', false, Icons.water_drop),
      ('تقرير الذمم المدينة', 'AR Aging', false, Icons.receipt),
      ('تقرير الذمم الدائنة', 'AP Aging', false, Icons.receipt_long),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Icon(reports[i].$4, color: _navy),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reports[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(reports[i].$2, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          if (reports[i].$3) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text('جاهز', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ok)))
          else OutlinedButton(onPressed: () {}, child: Text('توليد', style: TextStyle(fontSize: 11))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.download, size: 18), onPressed: () {}),
        ]),
      ),
    );
  }

  Widget _card(String title, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]));

  Widget _stat(String label, String value, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
        ]),
      );
}
