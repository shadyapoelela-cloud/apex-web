/// V5.2 — VAT Return Builder using FormWizardTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/form_wizard_template.dart';

class VatReturnV52Screen extends StatefulWidget {
  const VatReturnV52Screen({super.key});

  @override
  State<VatReturnV52Screen> createState() => _VatReturnV52ScreenState();
}

class _VatReturnV52ScreenState extends State<VatReturnV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _period = 'Q1 2026';
  bool _confirmedSources = false;
  bool _reviewedAdjustments = false;
  bool _agreeSubmit = false;

  @override
  Widget build(BuildContext context) {
    return FormWizardTemplate(
      titleAr: 'إعداد إقرار ضريبة القيمة المضافة',
      subtitleAr: 'ZATCA VAT Return · دليل إرشادي بالذكاء الاصطناعي',
      onSaveDraft: () {},
      onSubmit: () async {
        await Future.delayed(const Duration(seconds: 2));
        return true;
      },
      steps: [
        WizardStep(
          labelAr: 'اختيار الفترة',
          descriptionAr: 'حدد الفترة الضريبية للإقرار',
          icon: Icons.calendar_month,
          builder: (_) => _step1(),
        ),
        WizardStep(
          labelAr: 'مصادر البيانات',
          descriptionAr: 'تأكيد صحة المصادر (GL + Invoices)',
          icon: Icons.source,
          validate: () => _confirmedSources ? null : 'يجب تأكيد المصادر',
          builder: (_) => _step2(),
        ),
        WizardStep(
          labelAr: 'ملخّص المبيعات (Output VAT)',
          descriptionAr: 'راجع المبيعات الخاضعة للضريبة',
          icon: Icons.arrow_circle_up,
          builder: (_) => _step3(),
        ),
        WizardStep(
          labelAr: 'ملخّص المشتريات (Input VAT)',
          descriptionAr: 'راجع المدخلات القابلة للاسترداد',
          icon: Icons.arrow_circle_down,
          builder: (_) => _step4(),
        ),
        WizardStep(
          labelAr: 'التسويات والتعديلات',
          descriptionAr: 'تعديلات نهاية الفترة والاستحقاقات',
          icon: Icons.tune,
          validate: () => _reviewedAdjustments ? null : 'راجع التسويات أولاً',
          builder: (_) => _step5(),
        ),
        WizardStep(
          labelAr: 'المراجعة والإرسال',
          descriptionAr: 'مراجعة نهائية ثم إرسال إلى ZATCA',
          icon: Icons.send,
          validate: () => _agreeSubmit ? null : 'يجب الموافقة على الإقرار قبل الإرسال',
          builder: (_) => _step6(),
        ),
      ],
    );
  }

  Widget _step1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('اختر الفترة الضريبية:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _periodCard('Q1 2026', 'يناير - مارس', '23 أبريل 2026', true),
        _periodCard('Q4 2025', 'أكتوبر - ديسمبر', '23 يناير 2026', false),
        _periodCard('Q3 2025', 'يوليو - سبتمبر', '23 أكتوبر 2025', false),
        _periodCard('Q2 2025', 'أبريل - يونيو', '23 يوليو 2025', false),
      ]),
    ]);
  }

  Widget _periodCard(String period, String dates, String due, bool current) {
    final selected = period == _period;
    return InkWell(
      onTap: () => setState(() => _period = period),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _gold.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _gold : core_theme.AC.bdr, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event, color: selected ? _gold : core_theme.AC.ts, size: 20),
            const Spacer(),
            if (current) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: core_theme.AC.warn.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text('الحالي', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: core_theme.AC.warn))),
          ]),
          const SizedBox(height: 8),
          Text(period, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: selected ? _navy : core_theme.AC.tp)),
          Text(dates, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule, size: 11, color: core_theme.AC.ts),
            const SizedBox(width: 4),
            Text('استحقاق: $due', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ]),
        ]),
      ),
    );
  }

  Widget _step2() {
    const sources = [
      ('دفتر الأستاذ العام', 'GL · Finance', '4,280 قيد', true),
      ('فواتير المبيعات', 'Sales & AR', '842 فاتورة', true),
      ('فواتير المشتريات', 'Purchasing & AP', '385 فاتورة', true),
      ('إشعارات دائنة', 'Credit Notes', '24 إشعار', true),
      ('نقاط البيع', 'POS (Retail + Restaurant)', '15,240 عملية', true),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: core_theme.AC.ok.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.ok.withOpacity(0.3))),
        child: Row(children: [
          Icon(Icons.check_circle, color: core_theme.AC.ok, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('تم جلب البيانات من كل المصادر بنجاح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: 16),
      Text('المصادر المُدرجة في الإقرار:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ...sources.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
            child: Row(children: [
              Icon(s.$4 ? Icons.check_circle : Icons.radio_button_unchecked, color: s.$4 ? core_theme.AC.ok : core_theme.AC.td),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${s.$2} · ${s.$3}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ])),
            ]),
          )),
      const SizedBox(height: 12),
      CheckboxListTile(
        value: _confirmedSources,
        onChanged: (v) => setState(() => _confirmedSources = v ?? false),
        title: Text('أؤكّد صحة المصادر أعلاه', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        subtitle: Text('سيتم استخدامها لحساب VAT Output / Input', style: TextStyle(fontSize: 10)),
        activeColor: _gold,
        dense: true,
      ),
    ]);
  }

  Widget _step3() {
    const lines = [
      ('1', 'مبيعات بمعدل قياسي 15%', 2180000.0, 327000.0),
      ('2', 'مبيعات بمعدل صفري (تصدير)', 340000.0, 0.0),
      ('3', 'مبيعات معفاة', 85000.0, 0.0),
      ('4', 'صادرات إلى دول مجلس التعاون', 620000.0, 0.0),
    ];
    final totalSales = lines.fold<double>(0, (s, l) => s + l.$3);
    final totalVAT = lines.fold<double>(0, (s, l) => s + l.$4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _gold.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold)),
        child: Row(children: [
          Icon(Icons.arrow_circle_up, color: _gold, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text('ضريبة المخرجات (Output VAT)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${totalVAT.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _gold)),
            Text('من مبيعات ${(totalSales / 1e6).toStringAsFixed(2)} مليون', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _vatTable(lines),
    ]);
  }

  Widget _step4() {
    const lines = [
      ('1', 'مشتريات بمعدل قياسي 15%', 820000.0, 123000.0),
      ('2', 'مشتريات مستوردة (احتساب عكسي)', 140000.0, 21000.0),
      ('3', 'مصروفات إدارية وتشغيلية', 260000.0, 39000.0),
      ('4', 'أصول رأسمالية', 180000.0, 27000.0),
    ];
    final totalPurch = lines.fold<double>(0, (s, l) => s + l.$3);
    final totalVAT = lines.fold<double>(0, (s, l) => s + l.$4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: core_theme.AC.ok.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.ok)),
        child: Row(children: [
          Icon(Icons.arrow_circle_down, color: core_theme.AC.ok, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text('ضريبة المدخلات (Input VAT)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${totalVAT.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: core_theme.AC.ok)),
            Text('من مشتريات ${(totalPurch / 1e6).toStringAsFixed(2)} مليون', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _vatTable(lines),
    ]);
  }

  Widget _step5() {
    const adjustments = [
      ('تسوية ديون معدومة', 5400.0, true),
      ('تعديل فواتير ملغاة (Q4)', -12800.0, true),
      ('إعادة احتساب الأصول الثابتة', 3200.0, false),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('التسويات المقترحة لنهاية الفترة:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
      const SizedBox(height: 12),
      ...adjustments.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
            child: Row(children: [
              Icon(a.$3 ? Icons.check_circle : Icons.radio_button_unchecked, color: a.$3 ? core_theme.AC.ok : core_theme.AC.td),
              const SizedBox(width: 10),
              Expanded(child: Text(a.$1, style: const TextStyle(fontSize: 13))),
              Text('${a.$2 >= 0 ? '+' : ''}${a.$2.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: a.$2 >= 0 ? core_theme.AC.ok : core_theme.AC.err)),
            ]),
          )),
      const SizedBox(height: 12),
      CheckboxListTile(
        value: _reviewedAdjustments,
        onChanged: (v) => setState(() => _reviewedAdjustments = v ?? false),
        title: Text('راجعت التسويات وقمت بتطبيق ما يلزم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        activeColor: _gold,
        dense: true,
      ),
    ]);
  }

  Widget _step6() {
    const outputVat = 327000.0;
    const inputVat = 210000.0;
    const adjustments = -4200.0;
    final netVat = outputVat - inputVat + adjustments;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_gold.withOpacity(0.08), _navy.withOpacity(0.06)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ملخّص الإقرار الضريبي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 4),
            Text('الفترة: $_period · ZATCA VAT Return', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            const Divider(height: 24),
            _kv('ضريبة المخرجات Output VAT', '+${outputVat.toStringAsFixed(0)} ر.س', core_theme.AC.tp),
            _kv('ضريبة المدخلات Input VAT', '-${inputVat.toStringAsFixed(0)} ر.س', core_theme.AC.tp),
            _kv('التسويات', '${adjustments.toStringAsFixed(0)} ر.س', adjustments >= 0 ? core_theme.AC.ok : core_theme.AC.err),
            const Divider(),
            _kv('صافي الضريبة المستحقة', '${netVat.toStringAsFixed(0)} ر.س', _gold, big: true),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: core_theme.AC.warn.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.warn.withOpacity(0.3))),
          child: Row(children: [
            Icon(Icons.info_outline, color: core_theme.AC.warn),
            SizedBox(width: 10),
            Expanded(child: Text('سيتم إرسال الإقرار رقمياً إلى ZATCA وسيُصدر رقم مرجعي فور الاستلام.', style: TextStyle(fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _agreeSubmit,
          onChanged: (v) => setState(() => _agreeSubmit = v ?? false),
          title: Text('أقرّ بصحة البيانات وأوافق على الإرسال لـ ZATCA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          activeColor: _gold,
          dense: true,
        ),
      ]),
    );
  }

  Widget _vatTable(List<(String, String, double, double)> lines) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: core_theme.AC.navy3,
          child: const Row(children: [
            SizedBox(width: 30, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            Expanded(flex: 3, child: Text('البند', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            SizedBox(width: 130, child: Text('المبلغ الخاضع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            SizedBox(width: 130, child: Text('الضريبة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          ]),
        ),
        ...lines.map((l) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.bdr))),
              child: Row(children: [
                SizedBox(width: 30, child: Text(l.$1, style: const TextStyle(fontSize: 12))),
                Expanded(flex: 3, child: Text(l.$2, style: const TextStyle(fontSize: 12))),
                SizedBox(width: 130, child: Text(l.$3.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.end)),
                SizedBox(width: 130, child: Text(l.$4.toStringAsFixed(0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold), textAlign: TextAlign.end)),
              ]),
            )),
      ]),
    );
  }

  Widget _kv(String label, String value, Color color, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: big ? 14 : 12, fontWeight: big ? FontWeight.w800 : FontWeight.w500, color: core_theme.AC.tp))),
        Text(value, style: TextStyle(fontSize: big ? 18 : 13, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}
