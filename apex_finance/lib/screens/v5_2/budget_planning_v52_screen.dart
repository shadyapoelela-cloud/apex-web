/// V5.2 — Budget Planning using FormWizardTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/form_wizard_template.dart';

class BudgetPlanningV52Screen extends StatefulWidget {
  const BudgetPlanningV52Screen({super.key});

  @override
  State<BudgetPlanningV52Screen> createState() => _BudgetPlanningV52ScreenState();
}

class _BudgetPlanningV52ScreenState extends State<BudgetPlanningV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _period = '2027';
  String _method = 'zero-based';
  double _revGrowth = 20;
  double _costGrowth = 12;
  bool _approved = false;

  @override
  Widget build(BuildContext context) {
    return FormWizardTemplate(
      titleAr: 'تخطيط موازنة السنة المالية',
      subtitleAr: 'Connected Planning · 6 خطوات لإعداد موازنة كاملة',
      onSaveDraft: () {},
      onSubmit: () async {
        await Future.delayed(const Duration(seconds: 2));
        return true;
      },
      steps: [
        WizardStep(labelAr: 'اختيار الفترة', descriptionAr: 'السنة المالية والكيان', icon: Icons.calendar_month, builder: (_) => _step1()),
        WizardStep(labelAr: 'منهجية التخطيط', descriptionAr: 'صفرية / تزايدية / متحرّكة', icon: Icons.account_tree, builder: (_) => _step2()),
        WizardStep(labelAr: 'افتراضات الإيرادات', descriptionAr: 'نمو، خصومات، تسعير', icon: Icons.trending_up, builder: (_) => _step3()),
        WizardStep(labelAr: 'افتراضات المصروفات', descriptionAr: 'تكلفة البضاعة، تشغيلية، رأسمالية', icon: Icons.trending_down, builder: (_) => _step4()),
        WizardStep(labelAr: 'التخصيص على الأقسام', descriptionAr: 'تقسيم الموازنة على 6 أقسام', icon: Icons.pie_chart, builder: (_) => _step5()),
        WizardStep(labelAr: 'المراجعة والاعتماد', descriptionAr: 'ملخّص نهائي قبل الاعتماد', icon: Icons.check_circle, validate: () => _approved ? null : 'يجب الموافقة قبل الاعتماد', builder: (_) => _step6()),
      ],
    );
  }

  Widget _step1() {
    const years = ['2027', '2026 Q2', '2026 Q3', 'Rolling 12M'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('اختر الفترة المراد التخطيط لها:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: years.map((y) {
        final selected = y == _period;
        return InkWell(
          onTap: () => setState(() => _period = y),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: selected ? _gold.withValues(alpha: 0.06) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? _gold : core_theme.AC.bdr, width: selected ? 2 : 1)),
            child: Column(children: [
              Icon(Icons.calendar_month, color: selected ? _gold : core_theme.AC.td, size: 28),
              const SizedBox(height: 8),
              Text(y, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: selected ? _navy : core_theme.AC.tp), textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList()),
      const SizedBox(height: 24),
      _dropdown('الكيان', 'المجموعة بالكامل', const ['المجموعة بالكامل', 'أبكس السعودية', 'أبكس الإمارات', 'أبكس مصر']),
      const SizedBox(height: 16),
      _dropdown('العملة', 'SAR', const ['SAR', 'USD', 'AED', 'EGP']),
    ]);
  }

  Widget _step2() {
    final methods = [
      ('zero-based', 'موازنة صفرية (ZBB)', 'كل بند يُبرَّر من الصفر — دقة عالية', Icons.restart_alt, core_theme.AC.err),
      ('incremental', 'موازنة تزايدية', 'تطبيق نسبة زيادة على السنة السابقة — أسرع', Icons.trending_up, core_theme.AC.info),
      ('rolling', 'موازنة متحرّكة (Rolling)', 'تحديث ربع سنوي بـ 12 شهر قادمة', Icons.refresh, core_theme.AC.ok),
      ('driver-based', 'مبنية على المحرّكات', 'تربط بين المقاييس التشغيلية والمالية', Icons.settings_input_component, _gold),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('اختر منهجية التخطيط:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
      const SizedBox(height: 16),
      ...methods.map((m) => InkWell(
            onTap: () => setState(() => _method = m.$1),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _method == m.$1 ? m.$5.withValues(alpha: 0.06) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _method == m.$1 ? m.$5 : core_theme.AC.bdr, width: _method == m.$1 ? 2 : 1)),
              child: Row(children: [
                Icon(_method == m.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _method == m.$1 ? m.$5 : core_theme.AC.td),
                const SizedBox(width: 12),
                Icon(m.$4, color: m.$5, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _method == m.$1 ? _navy : core_theme.AC.tp)),
                  Text(m.$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ])),
              ]),
            ),
          )),
    ]);
  }

  Widget _step3() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('حدّد افتراضات الإيرادات:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
        const SizedBox(height: 20),
        _sliderRow('نموّ الإيرادات المتوقّع', _revGrowth, 0, 50, '%', (v) => setState(() => _revGrowth = v), _gold),
        const SizedBox(height: 16),
        _card('افتراضات تفصيلية', Column(children: [
          _kvRow('إيراد 2025 الفعلي', '84,500,000 ر.س'),
          _kvRow('نسبة النمو المقترحة', '${_revGrowth.toStringAsFixed(0)}%', color: _gold),
          _kvRow('إيراد 2027 المتوقّع', '${(84500000 * (1 + _revGrowth / 100) / 1e6).toStringAsFixed(1)}M ر.س', color: core_theme.AC.ok, bold: true),
          const Divider(),
          _kvRow('مبيعات المنتجات', '74% من الإجمالي'),
          _kvRow('إيرادات الخدمات', '26% من الإجمالي'),
          _kvRow('متوسط سعر البيع', 'زيادة 5%'),
          _kvRow('خصومات ترويجية', 'حد أقصى 3.5%'),
        ])),
      ]),
    );
  }

  Widget _step4() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('حدّد افتراضات المصروفات:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
        const SizedBox(height: 20),
        _sliderRow('نموّ المصروفات التشغيلية', _costGrowth, 0, 30, '%', (v) => setState(() => _costGrowth = v), core_theme.AC.warn),
        const SizedBox(height: 16),
        _card('بنود المصروفات الرئيسية', Column(children: [
          _expCategoryRow('تكلفة البضاعة المباعة', 42000000, '50%', _gold),
          _expCategoryRow('الرواتب والأجور', 22000000, '26%', core_theme.AC.info),
          _expCategoryRow('الإيجارات والمرافق', 4800000, '6%', core_theme.AC.warn),
          _expCategoryRow('التسويق والإعلان', 3400000, '4%', _navy),
          _expCategoryRow('البحث والتطوير', 2800000, '3%', core_theme.AC.ok),
          _expCategoryRow('الصيانة والدعم', 1800000, '2%', core_theme.AC.info),
          _expCategoryRow('مصروفات أخرى', 7200000, '9%', core_theme.AC.td),
        ])),
        const SizedBox(height: 16),
        _card('المصروفات الرأسمالية (CAPEX)', Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الميزانية المقترحة', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            Text('4,200,000 ر.س', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _gold)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أهم البنود', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            Text('• تطوير النظام (1.8M)\n• توسّع فرع جدة (1.6M)\n• معدات IT (800K)', style: TextStyle(fontSize: 11, height: 1.5)),
          ])),
        ])),
      ]),
    );
  }

  Widget _step5() {
    final depts = [
      ('المبيعات', 0.32, core_theme.AC.info),
      ('العمليات', 0.24, core_theme.AC.ok),
      ('التصنيع', 0.18, _gold),
      ('التقنية', 0.10, _navy),
      ('الموارد البشرية', 0.08, core_theme.AC.purple),
      ('الإدارة العامة', 0.08, core_theme.AC.td),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('تخصيص الموازنة على الأقسام:', style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(children: depts.map((d) {
          final amount = 84000000 * d.$2;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 10, height: 16, color: d.$3),
              const SizedBox(width: 10),
              Expanded(child: Text(d.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Text('${(d.$2 * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: d.$3)),
              const SizedBox(width: 10),
              SizedBox(width: 120, child: Text('${(amount / 1e6).toStringAsFixed(1)}M ر.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: d.$2, minHeight: 8, backgroundColor: core_theme.AC.navy3, color: d.$3)),
          ]));
        }).toList()),
      ),
      const SizedBox(height: 12),
      Text('المجموع: 84,000,000 ر.س (100%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
    ]);
  }

  Widget _step6() {
    final rev = 84500000 * (1 + _revGrowth / 100);
    final cost = 84000000 * (1 + _costGrowth / 100);
    final profit = rev - cost;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_gold.withValues(alpha: 0.1), core_theme.AC.ok.withValues(alpha: 0.08)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ملخّص الموازنة — $_period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 12),
            _summaryRow('الإيرادات المتوقّعة', '${(rev / 1e6).toStringAsFixed(1)}M ر.س', _gold),
            _summaryRow('المصروفات الإجمالية', '${(cost / 1e6).toStringAsFixed(1)}M ر.س', core_theme.AC.warn),
            _summaryRow('CAPEX', '4.2M ر.س', core_theme.AC.info),
            const Divider(),
            _summaryRow('صافي الربح المتوقّع', '${(profit / 1e6).toStringAsFixed(1)}M ر.س', core_theme.AC.ok, big: true),
            _summaryRow('هامش الربح', '${(profit / rev * 100).toStringAsFixed(1)}%', core_theme.AC.ok),
          ]),
        ),
        const SizedBox(height: 16),
        _card('قائمة المراجعين', Column(children: [
          _reviewerRow('محمد العمري', 'المدير التنفيذي', false),
          _reviewerRow('سارة المطيري', 'المدير المالي', true),
          _reviewerRow('د. فهد الزهراني', 'رئيس مجلس الإدارة', false),
        ])),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _approved,
          onChanged: (v) => setState(() => _approved = v ?? false),
          title: Text('أؤكّد صحة الافتراضات وأرسل للاعتماد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: Text('سيتم إرسال الموازنة للمدير التنفيذي والمدير المالي للاعتماد', style: TextStyle(fontSize: 10)),
          activeColor: _gold,
          dense: true,
        ),
      ]),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, String unit, ValueChanged<double> onChanged, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text('${value.toStringAsFixed(1)}$unit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
        ]),
        Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: color),
      ]);

  Widget _card(String title, Widget child) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 10), child]));

  Widget _kvRow(String k, String v, {Color? color, bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(k, style: const TextStyle(fontSize: 12))), Text(v, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: color))]));

  Widget _summaryRow(String k, String v, Color color, {bool big = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(k, style: TextStyle(fontSize: big ? 14 : 12, fontWeight: big ? FontWeight.w800 : FontWeight.w500))), Text(v, style: TextStyle(fontSize: big ? 18 : 13, fontWeight: FontWeight.w800, color: color))]));

  Widget _expCategoryRow(String k, int amount, String pct, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(k, style: const TextStyle(fontSize: 12))), Text('${(amount / 1e6).toStringAsFixed(1)}M ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 8), SizedBox(width: 40, child: Text(pct, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))))]),
        const SizedBox(height: 2),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: double.parse(pct.replaceAll('%', '')) / 100, minHeight: 4, backgroundColor: core_theme.AC.bdr, color: color)),
      ]));

  Widget _reviewerRow(String name, String role, bool signed) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        CircleAvatar(radius: 14, backgroundColor: _navy.withValues(alpha: 0.1), child: Text(name[0], style: TextStyle(color: _navy, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text(role, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ])),
        if (signed) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text('✓ موافق', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.ok)))
        else Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: core_theme.AC.warn.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text('قيد الانتظار', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.warn))),
      ]));

  Widget _dropdown(String label, String value, List<String> options) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(value: value, items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (_) {}, decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ]);
}
