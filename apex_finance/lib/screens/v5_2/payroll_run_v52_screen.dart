/// V5.2 — Payroll Run using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class PayrollRunV52Screen extends StatelessWidget {
  const PayrollRunV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'تشغيل الرواتب — أبريل 2026',
      subtitleAr: '142 موظف · إجمالي 1,842,500 ر.س · GOSI 138K · WPS جاهز',
      statusLabelAr: 'قيد الاعتماد',
      statusColor: core_theme.AC.warn,
      processStages: const [
        ProcessStage(labelAr: 'جمع البيانات'),
        ProcessStage(labelAr: 'حساب الرواتب'),
        ProcessStage(labelAr: 'الاعتماد'),
        ProcessStage(labelAr: 'WPS + GOSI'),
        ProcessStage(labelAr: 'الصرف'),
      ],
      processCurrentIndex: 2,
      smartButtons: [
        SmartButton(icon: Icons.people, labelAr: 'موظف', count: 142, color: _navy),
        SmartButton(icon: Icons.event_available, labelAr: 'إجازة', count: 28, color: core_theme.AC.info),
        SmartButton(icon: Icons.emoji_events, labelAr: 'مكافأة', count: 12, color: _gold),
        SmartButton(icon: Icons.money_off, labelAr: 'خصم', count: 6, color: core_theme.AC.err),
        SmartButton(icon: Icons.warning, labelAr: 'استثناء', count: 3, color: core_theme.AC.warn),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.visibility, size: 16), label: Text('معاينة قسائم')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.send, size: 16),
          label: Text('اعتماد وإرسال WPS'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'summary', labelAr: 'ملخّص الرواتب', icon: Icons.dashboard, builder: (_) => _summary()),
        ObjectPageTab(id: 'employees', labelAr: 'الموظفون', icon: Icons.people, builder: (_) => _employees()),
        ObjectPageTab(id: 'components', labelAr: 'المكوّنات', icon: Icons.view_list, builder: (_) => _components()),
        ObjectPageTab(id: 'gosi', labelAr: 'GOSI + WPS', icon: Icons.shield, builder: (_) => _gosiWps()),
        ObjectPageTab(id: 'exceptions', labelAr: 'الاستثناءات', icon: Icons.warning, builder: (_) => _exceptions()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Guardrails', contentAr: '⚠️ راتب خالد الشمراني زاد 40% هذا الشهر (ترقية من يناير) · تم التحقق من نظام HR', timestamp: DateTime.now().subtract(const Duration(hours: 2)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'ليلى أحمد', contentAr: 'تم إضافة مكافآت Q1 لـ 12 موظف · إجمالي 85,000 ر.س', timestamp: DateTime.now().subtract(const Duration(hours: 4)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'مدير الموارد البشرية', contentAr: 'جاهز للاعتماد · كل الفحوصات مرّت', timestamp: DateTime.now().subtract(const Duration(hours: 6)), kind: ChatterKind.statusChange),
      ],
    );
  }

  Widget _summary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _bigStat('إجمالي الرواتب', '1,842,500', 'ر.س', _gold, Icons.payments)),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('صافي الصرف', '1,704,200', 'ر.س', core_theme.AC.ok, Icons.account_balance_wallet)),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('GOSI', '138,300', 'ر.س', core_theme.AC.info, Icons.shield)),
        ]),
        const SizedBox(height: 16),
        _card('توزيع الرواتب حسب القسم', Column(children: [
          _depRow('الإدارة العامة', 12, 340000, _gold),
          _depRow('المبيعات', 38, 520000, core_theme.AC.info),
          _depRow('العمليات', 42, 480000, core_theme.AC.ok),
          _depRow('التقنية', 28, 380000, _navy),
          _depRow('الموارد البشرية', 12, 95000, core_theme.AC.purple),
          _depRow('المحاسبة', 10, 100000, core_theme.AC.warn),
        ])),
        const SizedBox(height: 16),
        _card('بنود الراتب الإجمالية', Column(children: [
          _compRow('الأجور الأساسية', 1420000, '77%', _gold),
          _compRow('بدلات (سكن + نقل)', 320000, '17%', core_theme.AC.info),
          _compRow('مكافآت وعمولات', 85000, '5%', core_theme.AC.ok),
          _compRow('ساعات إضافية', 17500, '1%', core_theme.AC.warn),
        ])),
      ]),
    );
  }

  Widget _employees() {
    final emps = [
      ('EMP-001', 'أحمد محمد', 'مدير تسويق', 18500, 2400, 1200, _navy),
      ('EMP-002', 'سارة علي', 'مدير عمليات', 22000, 2800, 1500, _navy),
      ('EMP-003', 'خالد إبراهيم', 'مهندس أول', 15200, 2000, 900, core_theme.AC.info),
      ('EMP-004', 'ليلى أحمد', 'محلل مالي', 12800, 1700, 750, core_theme.AC.info),
      ('EMP-005', 'عمر حسن', 'مندوب مبيعات', 8400, 1100, 500, core_theme.AC.ok),
      ('EMP-006', 'نورة الدوسري', 'محاسب', 9800, 1300, 580, core_theme.AC.ok),
      ('EMP-007', 'يوسف عمر', 'فني صيانة', 6200, 800, 370, core_theme.AC.warn),
      ('EMP-008', 'دينا حسام', 'موظفة خدمة', 5400, 700, 320, core_theme.AC.warn),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: emps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final total = emps[i].$4 + emps[i].$5;
        final net = total - emps[i].$6;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
          child: Row(children: [
            CircleAvatar(backgroundColor: emps[i].$7.withOpacity(0.15), child: Text(emps[i].$2[0], style: TextStyle(color: emps[i].$7, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emps[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
              Text(emps[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(emps[i].$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            _psCol('أساسي', emps[i].$4),
            const SizedBox(width: 16),
            _psCol('بدلات', emps[i].$5),
            const SizedBox(width: 16),
            _psCol('خصومات', emps[i].$6, neg: true),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('صافي الراتب', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${net.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _gold)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _psCol(String label, int value, {bool neg = false}) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text('${neg ? '-' : ''}${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: neg ? core_theme.AC.err : core_theme.AC.tp)),
      ]);

  Widget _components() {
    const comps = [
      ('الراتب الأساسي', 1420000.0, true, 'مُعتمد في نظام HR'),
      ('بدل سكن (25%)', 355000.0, true, 'حسب السياسة'),
      ('بدل نقل', 85000.0, true, 'ثابت لكل موظف'),
      ('بدل طبيعة العمل', 42000.0, true, 'لـ 38 موظف عملياتي'),
      ('مكافآت Q1 2026', 85000.0, true, '12 موظف ذو أداء متميّز'),
      ('عمولات المبيعات', 35000.0, true, '8 مندوبين'),
      ('ساعات إضافية', 17500.0, true, '42 ساعة'),
      ('GOSI موظف (9.75%)', 81000.0, true, 'خصم تلقائي'),
      ('GOSI شركة (11.75%)', 97500.0, true, 'مستحق على الشركة'),
      ('ضريبة الدخل', 0.0, true, 'غير مطبّقة في السعودية'),
      ('التأمين الصحي', 38000.0, true, 'خصم 25%'),
      ('سلفة مسترجعة', 12000.0, true, '4 موظفين'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: comps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Icon(comps[i].$3 ? Icons.check_circle : Icons.radio_button_unchecked, color: comps[i].$3 ? core_theme.AC.ok : core_theme.AC.td, size: 18),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(comps[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(comps[i].$4, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ])),
          Text('${comps[i].$2.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        ]),
      ),
    );
  }

  Widget _gosiWps() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card('📋 تقرير GOSI', Column(children: [
          _kvRow('عدد الموشتركين', '142 موظف', null),
          _kvRow('مجموع الأجور الخاضعة', '1,395,000 ر.س', null),
          _kvRow('حصة الموظف (9.75%)', '136,013 ر.س', core_theme.AC.err),
          _kvRow('حصة الشركة (11.75%)', '163,913 ر.س', core_theme.AC.warn),
          _kvRow('الإجمالي المستحق', '299,926 ر.س', _gold, bold: true),
          const Divider(height: 20),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: core_theme.AC.info), icon: const Icon(Icons.upload, size: 16), label: Text('رفع إلى GOSI'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 16), label: Text('تحميل ملف SIMPLE'))),
          ]),
        ])),
        const SizedBox(height: 16),
        _card('💳 تقرير WPS (نظام حماية الأجور)', Column(children: [
          _kvRow('عدد الموظفين', '142 موظف', null),
          _kvRow('صافي الصرف', '1,704,200 ر.س', _gold, bold: true),
          _kvRow('بنوك الصرف', '3 بنوك (الرياض، الراجحي، الأهلي)', null),
          _kvRow('تاريخ الصرف المستهدف', '2026-04-28', null),
          _kvRow('SIF File', 'جاهز للإرسال', core_theme.AC.ok),
          const Divider(height: 20),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: core_theme.AC.ok), icon: const Icon(Icons.send, size: 16), label: Text('إرسال SIF إلى البنك'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.preview, size: 16), label: Text('معاينة SIF'))),
          ]),
        ])),
      ]),
    );
  }

  Widget _exceptions() {
    final exc = [
      ('عمر حسن', 'انقطاع 3 أيام غير مبرّر', 'خصم 1,200 ر.س', core_theme.AC.warn),
      ('يوسف عمر', 'ساعات إضافية فوق الحد المسموح', 'يحتاج موافقة مدير', core_theme.AC.err),
      ('نورة الدوسري', 'تغيير في الراتب (ترقية)', 'زيادة 800 ر.س - موثّقة', core_theme.AC.ok),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: exc.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: exc[i].$4.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: exc[i].$4, width: 1.5)),
        child: Row(children: [
          Icon(Icons.warning_amber, color: exc[i].$4, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exc[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(exc[i].$2, style: const TextStyle(fontSize: 12)),
            Text(exc[i].$3, style: TextStyle(fontSize: 11, color: exc[i].$4, fontWeight: FontWeight.w700)),
          ])),
          OutlinedButton(onPressed: () {}, child: Text('معالجة', style: TextStyle(fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _card(String title, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]));

  Widget _kvRow(String k, String v, Color? color, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        Expanded(child: Text(k, style: TextStyle(fontSize: 12, color: core_theme.AC.tp))),
        Text(v, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: FontWeight.w800, color: color ?? core_theme.AC.tp)),
      ]));

  Widget _bigStat(String label, String value, String unit, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.9)))]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 4), Text(unit, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)))]),
        ]),
      );

  Widget _depRow(String dept, int headcount, double total, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        Container(width: 8, height: 20, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(dept, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        Text('$headcount موظف', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(width: 16),
        Text('${total.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ]));

  Widget _compRow(String name, double value, String pct, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(name, style: const TextStyle(fontSize: 12)), const Spacer(), Text('${value.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 8), SizedBox(width: 40, child: Text(pct, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.8))))]),
        const SizedBox(height: 2),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: double.parse(pct.replaceAll('%', '')) / 100, minHeight: 4, backgroundColor: core_theme.AC.bdr, color: color)),
      ]));
}
