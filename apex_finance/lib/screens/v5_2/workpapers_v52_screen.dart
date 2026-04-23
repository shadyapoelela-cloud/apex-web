/// V5.2 — Audit Workpaper using ObjectPageTemplate (CaseWare-class).
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class WorkpapersV52Screen extends StatelessWidget {
  const WorkpapersV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'ورقة عمل A-101: مراجعة النقدية',
      subtitleAr: 'عميل: شركة الراجحي للتجارة · سنة 2025 · المنفذ: أحمد العمري · المراجع: سارة المطيري',
      statusLabelAr: 'قيد المراجعة',
      statusColor: _purple,
      processStages: const [
        ProcessStage(labelAr: 'في الإعداد'),
        ProcessStage(labelAr: 'جاهز للمراجعة'),
        ProcessStage(labelAr: 'قيد المراجعة'),
        ProcessStage(labelAr: 'مُراجع'),
        ProcessStage(labelAr: 'مؤرشف'),
      ],
      processCurrentIndex: 2,
      smartButtons: [
        SmartButton(icon: Icons.description, labelAr: 'إجراء اختبار', count: 8, color: _gold),
        SmartButton(icon: Icons.attach_file, labelAr: 'دليل', count: 14, color: _navy),
        SmartButton(icon: Icons.comment, labelAr: 'ملاحظة', count: 6, color: core_theme.AC.info),
        SmartButton(icon: Icons.warning, labelAr: 'مشكلة', count: 2, color: core_theme.AC.warn),
        SmartButton(icon: Icons.link, labelAr: 'رابط قيد', count: 12, color: core_theme.AC.ok),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.print, size: 16), label: Text('طباعة')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _purple), icon: const Icon(Icons.check, size: 16), label: Text('إنهاء المراجعة')),
      ],
      tabs: [
        ObjectPageTab(id: 'overview', labelAr: 'معلومات الورقة', icon: Icons.dashboard, builder: (_) => _overview()),
        ObjectPageTab(id: 'procedures', labelAr: 'الإجراءات', icon: Icons.list_alt, builder: (_) => _procedures()),
        ObjectPageTab(id: 'tb', labelAr: 'ربط الميزان', icon: Icons.link, builder: (_) => _tb()),
        ObjectPageTab(id: 'evidence', labelAr: 'الأدلة', icon: Icons.folder, builder: (_) => _evidence()),
        ObjectPageTab(id: 'findings', labelAr: 'النتائج', icon: Icons.report, builder: (_) => _findings()),
        ObjectPageTab(id: 'conclusion', labelAr: 'الخلاصة', icon: Icons.done_all, builder: (_) => _conclusion()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'سارة المطيري (مراجع)', contentAr: '@أحمد — المصادقات البنكية الأربع كلها متطابقة، عمل جيد. ملاحظة على المصادقة رقم 3: الرصيد النهائي يحتاج تسوية.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), kind: ChatterKind.message),
        ChatterEntry(authorAr: 'أحمد العمري (منفذ)', contentAr: 'تم إكمال اختبار المصادقات البنكية — 4 مصادقات، 3 مستلمة، 1 قيد المتابعة', timestamp: DateTime.now().subtract(const Duration(days: 1)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'AI Auditor', contentAr: 'كشف شذوذ: قيد بقيمة 45K ر.س في 2025-12-31 في الساعة 23:47 — خارج ساعات العمل. موصى بالتحقق.', timestamp: DateTime.now().subtract(const Duration(days: 2)), kind: ChatterKind.logNote),
      ],
    );
  }

  Widget _overview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card('بيانات الورقة', Wrap(spacing: 28, runSpacing: 14, children: [
          _kv('رقم الورقة', 'A-101'),
          _kv('اسم الورقة', 'مراجعة النقدية والبنوك'),
          _kv('مجال المراجعة', 'النقدية (1110)'),
          _kv('المبلغ الخاضع للفحص', '3,240,000 ر.س'),
          _kv('الأهمية النسبية', '42,250 ر.س'),
          _kv('مستوى المخاطر', 'منخفض'),
          _kv('تاريخ البداية', '2026-04-01'),
          _kv('تاريخ الإكمال المتوقع', '2026-04-22'),
          _kv('الوقت المستهلك', '18 ساعة من 24'),
          _kv('رقم ISA', 'ISA 505 (المصادقات)'),
        ])),
        const SizedBox(height: 16),
        _card('الأهداف (Objectives)', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _bullet('التحقق من وجود الأرصدة البنكية المثبتة في الدفاتر'),
          _bullet('التأكد من اكتمال التسجيل لجميع الحسابات البنكية'),
          _bullet('التحقق من دقة الأرصدة ومطابقتها مع المصادقات البنكية'),
          _bullet('فحص القطع الزمني (Cut-off) للإيداعات والسحوبات قرب نهاية السنة'),
          _bullet('التأكد من الإفصاح السليم في القوائم المالية'),
        ])),
        const SizedBox(height: 16),
        _card('ملخّص النتائج', Column(children: [
          _summaryRow('عدد الإجراءات', '8', '8 مكتمل', core_theme.AC.ok),
          _summaryRow('الأدلة المجمّعة', '14 ملف', 'جميعها مقبولة', core_theme.AC.ok),
          _summaryRow('القضايا المكتشفة', '2 قضية', '1 جوهرية · 1 غير جوهرية', core_theme.AC.warn),
          _summaryRow('التعديلات المقترحة', '1 قيد', '45K ر.س', _gold),
          _summaryRow('مستوى الثقة', '92%', 'يسمح بإبداء الرأي', core_theme.AC.ok),
        ])),
      ]),
    );
  }

  Widget _procedures() {
    const procs = [
      ('A-101.1', 'الحصول على مصادقات بنكية مباشرة', 'ISA 505', true, 'مكتمل'),
      ('A-101.2', 'مطابقة الأرصدة مع القوائم', 'ISA 500', true, 'مكتمل'),
      ('A-101.3', 'فحص تسويات البنك', 'ISA 505', true, 'مكتمل'),
      ('A-101.4', 'اختبار القطع الزمني (Cut-off)', 'ISA 501', true, 'مكتمل'),
      ('A-101.5', 'فحص قيود أواخر الفترة', 'ISA 240', false, 'قيد العمل'),
      ('A-101.6', 'مراجعة معاملات الأطراف ذات العلاقة', 'ISA 550', false, 'قيد العمل'),
      ('A-101.7', 'اختبار الأرصدة المصنّفة بالعملات الأجنبية', 'IAS 21', true, 'مكتمل'),
      ('A-101.8', 'مراجعة الإفصاح في القوائم', 'IAS 1', true, 'مكتمل'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: procs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: procs[i].$4 ? core_theme.AC.ok.withValues(alpha: 0.3) : core_theme.AC.warn.withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(procs[i].$4 ? Icons.check_circle : Icons.pending, color: procs[i].$4 ? core_theme.AC.ok : core_theme.AC.warn),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(procs[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)), child: Text(procs[i].$3, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _purple))),
            ]),
            Text(procs[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (procs[i].$4 ? core_theme.AC.ok : core_theme.AC.warn).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(procs[i].$5, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: procs[i].$4 ? core_theme.AC.ok : core_theme.AC.warn))),
        ]),
      ),
    );
  }

  Widget _tb() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ربط ميزان المراجعة (Trial Balance Tie-Out)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        Text('التحقق من مطابقة الأرصدة بين ورقة العمل والميزان', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(10), color: _navy, child: const Row(children: [
              Expanded(flex: 2, child: Text('الحساب', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
              Expanded(child: Text('ميزان المراجعة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
              Expanded(child: Text('المصادقة البنكية', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
              Expanded(child: Text('الفرق', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
              Expanded(child: Text('الحالة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            ])),
            ..._tieoutRows().map((r) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.bdr))),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(r.$1, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                    Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                    Expanded(child: Text(r.$3, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                    Expanded(child: Text(r.$4, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: r.$4 == '0' ? core_theme.AC.ok : core_theme.AC.err, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (r.$4 == '0' ? core_theme.AC.ok : core_theme.AC.warn).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(r.$4 == '0' ? '✓ متطابق' : 'تسوية مطلوبة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: r.$4 == '0' ? core_theme.AC.ok : core_theme.AC.warn))))),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }

  List<(String, String, String, String)> _tieoutRows() => [
        ('1110.01 بنك الرياض', '1,240,000', '1,240,000', '0'),
        ('1110.02 بنك الراجحي', '890,000', '890,000', '0'),
        ('1110.03 بنك الأهلي', '820,000', '820,000', '0'),
        ('1110.04 بنك HSBC', '290,000', '335,000', '(45,000)'),
        ('الإجمالي', '3,240,000', '3,285,000', '(45,000)'),
      ];

  Widget _evidence() {
    final docs = [
      ('BANK-CONF-001', 'مصادقة بنك الرياض', 'PDF', '4.2 MB', true, core_theme.AC.err),
      ('BANK-CONF-002', 'مصادقة بنك الراجحي', 'PDF', '3.8 MB', true, core_theme.AC.err),
      ('BANK-CONF-003', 'مصادقة بنك الأهلي', 'PDF', '4.1 MB', true, core_theme.AC.err),
      ('BANK-CONF-004', 'مصادقة بنك HSBC', 'PDF', '3.9 MB', true, core_theme.AC.err),
      ('BANK-REC-001', 'تسوية بنكية ديسمبر', 'Excel', '240 KB', true, core_theme.AC.ok),
      ('GL-EXTRACT', 'مستخرج دفتر الأستاذ', 'Excel', '1.8 MB', true, core_theme.AC.ok),
      ('POLICY-CASH', 'سياسة النقدية للعميل', 'PDF', '890 KB', true, core_theme.AC.err),
      ('CUTOFF-TEST', 'نتائج اختبار القطع الزمني', 'Excel', '420 KB', true, core_theme.AC.ok),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Icon(Icons.insert_drive_file, color: docs[i].$6),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(docs[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
            Text(docs[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
          Text('${docs[i].$3} · ${docs[i].$4}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.visibility, size: 18), onPressed: () {}),
          IconButton(icon: const Icon(Icons.download, size: 18), onPressed: () {}),
        ]),
      ),
    );
  }

  Widget _findings() {
    final findings = [
      ('F-001', 'فرق 45,000 ر.س في مصادقة بنك HSBC', 'جوهرية', core_theme.AC.warn, 'يتطلب تسوية عبر قيد تعديلي قبل الإقفال'),
      ('F-002', 'قيد ليلي في 2025-12-31 بقيمة 45K الساعة 23:47', 'غير جوهرية', core_theme.AC.info, 'تم التحقق — معاملة مشروعة لتحويل بنكي'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: findings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: findings[i].$4.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: findings[i].$4, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.report, color: findings[i].$4),
            const SizedBox(width: 8),
            Text(findings[i].$1, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: findings[i].$4.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Text(findings[i].$3, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: findings[i].$4))),
          ]),
          const SizedBox(height: 6),
          Text(findings[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(findings[i].$5, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.5)),
        ]),
      ),
    );
  }

  Widget _conclusion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_purple.withValues(alpha: 0.06), core_theme.AC.ok.withValues(alpha: 0.06)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.done_all, color: _purple), SizedBox(width: 8), Text('خلاصة ورقة العمل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _purple))]),
            SizedBox(height: 12),
            Text(
              'بناءً على الإجراءات المُنفّذة على النقدية والبنوك (1110)، وبعد استلام 4 مصادقات بنكية مباشرة، '
              'وفحص التسويات والقطع الزمني:\n\n'
              '✅ الأرصدة البنكية موجودة ومملوكة للعميل\n'
              '✅ الأرصدة مسجّلة بشكل كامل في الدفاتر\n'
              '⚠️ يوجد فرق 45K ر.س في بنك HSBC يتطلب قيد تسوية (ضمن الأهمية النسبية)\n'
              '✅ القطع الزمني صحيح\n'
              '✅ الإفصاح في القوائم المالية سليم\n\n'
              '📌 التوصية: قبول الأرصدة بعد إجراء قيد التعديل 45K ر.س. مستوى الثقة 92%.',
              style: TextStyle(fontSize: 13, height: 1.8),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit), label: Text('تعديل الخلاصة'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _purple), icon: const Icon(Icons.check_circle), label: Text('اعتماد الخلاصة'))),
        ]),
      ]),
    );
  }

  Widget _card(String title, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]));

  Widget _kv(String k, String v) => SizedBox(width: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))]));

  Widget _bullet(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_outline, size: 14, color: _purple), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5)))]));

  Widget _summaryRow(String label, String value, String sub, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
        const SizedBox(width: 10),
        Text(sub, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]));
}
