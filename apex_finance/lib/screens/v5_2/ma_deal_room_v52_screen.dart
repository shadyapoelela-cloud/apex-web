/// V5.2 — M&A Deal Room using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class MaDealRoomV52Screen extends StatelessWidget {
  const MaDealRoomV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'صفقة استحواذ: شركة التقنية المتقدمة',
      subtitleAr: 'Target company · قيمة 48M ر.س · Due Diligence قيد التنفيذ',
      statusLabelAr: 'فحص نافٍ للجهالة',
      statusColor: _purple,
      processStages: const [
        ProcessStage(labelAr: 'Initial'),
        ProcessStage(labelAr: 'LOI'),
        ProcessStage(labelAr: 'Due Diligence'),
        ProcessStage(labelAr: 'Negotiation'),
        ProcessStage(labelAr: 'Closing'),
      ],
      processCurrentIndex: 2,
      smartButtons: [
        SmartButton(icon: Icons.folder, labelAr: 'وثيقة', count: 142, color: _gold),
        SmartButton(icon: Icons.group, labelAr: 'استشاري', count: 8, color: _navy),
        SmartButton(icon: Icons.warning_amber, labelAr: 'ملاحظة Red Flag', count: 3, color: core_theme.AC.err),
        SmartButton(icon: Icons.chat, labelAr: 'سؤال Q&A', count: 26, color: core_theme.AC.info),
        SmartButton(icon: Icons.trending_up, labelAr: 'نموذج تقييم', count: 4, color: core_theme.AC.ok),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.pause, size: 16), label: Text('تعليق الصفقة')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _purple),
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: Text('الانتقال للتفاوض'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'overview', labelAr: 'نظرة عامة', icon: Icons.dashboard, builder: (_) => _overview()),
        ObjectPageTab(id: 'financials', labelAr: 'المالية', icon: Icons.attach_money, builder: (_) => _financials()),
        ObjectPageTab(id: 'dd', labelAr: 'Due Diligence', icon: Icons.fact_check, builder: (_) => _dd()),
        ObjectPageTab(id: 'vdr', labelAr: 'غرفة الوثائق', icon: Icons.folder_special, builder: (_) => _vdr()),
        ObjectPageTab(id: 'qa', labelAr: 'Q&A', icon: Icons.quiz, builder: (_) => _qa()),
        ObjectPageTab(id: 'redflags', labelAr: 'Red Flags', icon: Icons.flag, builder: (_) => _redFlags()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Deal Analyst', contentAr: '⚠️ Red Flag جديدة: نسبة الديون إلى حقوق الملكية 3.2x — أعلى من المتوسط القطاعي.', timestamp: DateTime.now().subtract(const Duration(hours: 4)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'د. محمد الراجحي', contentAr: 'تم رفع 15 وثيقة جديدة في قسم العقود', timestamp: DateTime.now().subtract(const Duration(days: 1)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'المستشار المالي', contentAr: 'نموذج DCF المُحدَّث يُقدّر القيمة العادلة 52M ر.س (أعلى 8%)', timestamp: DateTime.now().subtract(const Duration(days: 3)), kind: ChatterKind.statusChange),
      ],
    );
  }

  Widget _overview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _Kpi(label: 'القيمة المعروضة', value: '48', unit: 'M ر.س', color: _gold, icon: Icons.handshake)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'القيمة العادلة (DCF)', value: '52', unit: 'M ر.س', color: core_theme.AC.ok, icon: Icons.trending_up)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'EBITDA Multiple', value: '6.4', unit: 'x', color: _navy, icon: Icons.calculate)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'تقدم DD', value: '68', unit: '%', color: _purple, icon: Icons.pie_chart)),
        ]),
        const SizedBox(height: 20),
        _card('بيانات الشركة المستهدفة', Wrap(spacing: 28, runSpacing: 14, children: [
          _kv('الاسم القانوني', 'شركة التقنية المتقدمة ذ.م.م'),
          _kv('تأسست', '2014'),
          _kv('القطاع', 'تكنولوجيا — SaaS'),
          _kv('المقر', 'الرياض، المملكة العربية السعودية'),
          _kv('عدد الموظفين', '124 موظف'),
          _kv('الإيرادات السنوية', '18.5M ر.س'),
          _kv('الأرباح (EBITDA)', '7.5M ر.س'),
          _kv('نوع الصفقة', '100% استحواذ (Acquisition)'),
          _kv('التمويل', 'نقد 60% + أسهم 40%'),
          _kv('الإغلاق المستهدف', 'Q3 2026'),
        ])),
        const SizedBox(height: 16),
        _card('الفريق المشارك', Column(children: [
          _personRow('د. محمد الراجحي', 'رئيس فريق الصفقة', _navy),
          _personRow('أحمد العمري', 'محلل مالي أول', _gold),
          _personRow('McKinsey & Co.', 'مستشار استراتيجي', core_theme.AC.info),
          _personRow('Ernst & Young', 'مدقق مالي', core_theme.AC.ok),
          _personRow('مكتب المحاماة المتحد', 'مستشار قانوني', _purple),
        ])),
      ]),
    );
  }

  Widget _financials() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('القوائم المالية للسنوات الثلاث الماضية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(children: [
            _finRow('البند', '2023', '2024', '2025', isHeader: true),
            _finRow('الإيرادات', '12.4M', '15.2M', '18.5M'),
            _finRow('تكلفة المبيعات', '(6.8M)', '(8.1M)', '(9.6M)'),
            _finRow('إجمالي الربح', '5.6M', '7.1M', '8.9M'),
            _finRow('مصروفات تشغيلية', '(1.2M)', '(1.4M)', '(1.4M)'),
            _finRow('EBITDA', '4.4M', '5.7M', '7.5M', bold: true),
            _finRow('الإهلاك', '(0.8M)', '(0.9M)', '(1.0M)'),
            _finRow('صافي الربح', '3.6M', '4.8M', '6.5M', bold: true, color: core_theme.AC.ok),
          ]),
        ),
        const SizedBox(height: 20),
        Text('مؤشرات الأداء الرئيسية (KPIs)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Kpi(label: 'نمو الإيرادات (CAGR)', value: '22', unit: '%', color: core_theme.AC.ok, icon: Icons.trending_up)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'هامش EBITDA', value: '40.5', unit: '%', color: _gold, icon: Icons.bar_chart)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'معدل الاحتفاظ', value: '96', unit: '%', color: core_theme.AC.info, icon: Icons.favorite)),
        ]),
      ]),
    );
  }

  Widget _dd() {
    final areas = [
      ('الفحص المالي (Financial DD)', 0.85, 'EY', core_theme.AC.ok),
      ('الفحص القانوني (Legal DD)', 0.72, 'المستشار القانوني', core_theme.AC.info),
      ('الفحص التجاري (Commercial DD)', 0.60, 'McKinsey', _gold),
      ('الفحص التقني (Tech DD)', 0.45, 'فريق داخلي', core_theme.AC.warn),
      ('الفحص الضريبي (Tax DD)', 0.90, 'EY Tax', core_theme.AC.ok),
      ('فحص الموارد البشرية (HR DD)', 0.55, 'الفريق الداخلي', core_theme.AC.warn),
      ('الفحص التنظيمي (Regulatory DD)', 0.80, 'المستشار القانوني', core_theme.AC.info),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: areas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(areas[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            Text('${(areas[i].$2 * 100).toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: areas[i].$4)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: areas[i].$2, minHeight: 8, backgroundColor: core_theme.AC.bdr, color: areas[i].$4)),
          const SizedBox(height: 6),
          Text('المنفذ: ${areas[i].$3}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ]),
      ),
    );
  }

  Widget _vdr() {
    final folders = [
      ('01. العقود والاتفاقيات', 48, Icons.gavel, core_theme.AC.info),
      ('02. القوائم المالية', 22, Icons.attach_money, _gold),
      ('03. الشؤون القانونية', 18, Icons.description, _purple),
      ('04. الموارد البشرية', 15, Icons.people, core_theme.AC.warn),
      ('05. العمليات التشغيلية', 12, Icons.factory, core_theme.AC.info),
      ('06. التقنية والـ IT', 14, Icons.computer, core_theme.AC.purple),
      ('07. العملاء والمبيعات', 13, Icons.handshake, core_theme.AC.ok),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: folders[i].$4.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Icon(folders[i].$3, color: folders[i].$4)),
          const SizedBox(width: 12),
          Expanded(child: Text(folders[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(10)), child: Text('${folders[i].$2} ملف', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Icon(Icons.chevron_left, size: 18, color: core_theme.AC.ts),
        ]),
      ),
    );
  }

  Widget _qa() {
    const questions = [
      ('س 26', 'ما هي نسبة العملاء المتجددين آخر 3 سنوات؟', 'أحمد العمري', true, '96.2%'),
      ('س 25', 'هل هناك التزامات خارج القوائم المالية؟', 'د. ليلى الفارس', true, 'لا توجد التزامات جوهرية'),
      ('س 24', 'ما خطة الشركة للمخاطر التقنية؟', 'فريق Tech DD', false, null),
      ('س 23', 'تفاصيل عقد الترخيص الأكبر (5M+)', 'مكتب المحاماة', true, 'تمت المراجعة'),
      ('س 22', 'معدل دوران الموظفين والأسباب', 'HR DD', false, null),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final q = questions[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: q.$4 ? core_theme.AC.ok.withOpacity(0.3) : core_theme.AC.warn.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Text(q.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _navy))),
              const Spacer(),
              if (q.$4) Row(children: [Icon(Icons.check_circle, color: core_theme.AC.ok, size: 16), SizedBox(width: 4), Text('مُجاب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ok))])
              else Row(children: [Icon(Icons.pending, color: core_theme.AC.warn, size: 16), SizedBox(width: 4), Text('قيد الإجابة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.warn))]),
            ]),
            const SizedBox(height: 8),
            Text(q.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (q.$5 != null) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: core_theme.AC.ok.withOpacity(0.05), borderRadius: BorderRadius.circular(6)), child: Text('الجواب: ${q.$5}', style: TextStyle(fontSize: 12, color: core_theme.AC.tp))),
            ],
            const SizedBox(height: 4),
            Text('مُوجّهة إلى: ${q.$3}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ]),
        );
      },
    );
  }

  Widget _redFlags() {
    final flags = [
      ('RF-003', 'نسبة الديون إلى حقوق الملكية 3.2x أعلى من المتوسط', 'عالية', core_theme.AC.err),
      ('RF-002', 'عقد مع أكبر عميل ينتهي في 6 أشهر', 'متوسطة', core_theme.AC.warn),
      ('RF-001', 'نزاع قضائي معلّق بقيمة 2M ر.س', 'متوسطة', core_theme.AC.warn),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: flags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: flags[i].$4.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: flags[i].$4, width: 1.5)),
        child: Row(children: [
          Icon(Icons.flag, color: flags[i].$4, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(flags[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: flags[i].$4, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: flags[i].$4.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text('خطورة ${flags[i].$3}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: flags[i].$4))),
            ]),
            const SizedBox(height: 4),
            Text(flags[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
    );
  }

  Widget _card(String title, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]));

  Widget _kv(String k, String v) => SizedBox(width: 220, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))]));

  Widget _personRow(String name, String role, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.15), child: Text(name[0], style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        Text(role, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]));

  Widget _finRow(String label, String y1, String y2, String y3, {bool isHeader = false, bool bold = false, Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: isHeader ? core_theme.AC.navy3 : null, border: Border(top: BorderSide(color: core_theme.AC.bdr))),
        child: Row(children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isHeader || bold ? FontWeight.w800 : FontWeight.w500, color: color))),
          Expanded(child: Text(y1, style: TextStyle(fontSize: 12, fontWeight: isHeader || bold ? FontWeight.w800 : FontWeight.w500, color: color), textAlign: TextAlign.end)),
          Expanded(child: Text(y2, style: TextStyle(fontSize: 12, fontWeight: isHeader || bold ? FontWeight.w800 : FontWeight.w500, color: color), textAlign: TextAlign.end)),
          Expanded(child: Text(y3, style: TextStyle(fontSize: 12, fontWeight: isHeader || bold ? FontWeight.w800 : FontWeight.w500, color: color), textAlign: TextAlign.end)),
        ]),
      );
}

class _Kpi extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _Kpi({required this.label, required this.value, required this.unit, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.9))),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 4), Text(unit, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)))]),
          ])),
        ]),
      );
}
