/// V5.2 — Audit Engagement Planning using FormWizardTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/form_wizard_template.dart';

class AuditPlanningV52Screen extends StatefulWidget {
  const AuditPlanningV52Screen({super.key});

  @override
  State<AuditPlanningV52Screen> createState() => _AuditPlanningV52ScreenState();
}

class _AuditPlanningV52ScreenState extends State<AuditPlanningV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  static const _purple = Color(0xFF4A148C);

  String _clientName = '';
  bool _independenceOK = false;
  String _riskLevel = 'medium';
  bool _teamAssigned = false;
  bool _reviewedPlan = false;

  @override
  Widget build(BuildContext context) {
    return FormWizardTemplate(
      titleAr: 'تخطيط ارتباط المراجعة',
      subtitleAr: 'ISA 300 + ISA 315 · إعداد الارتباط السنوي',
      onSaveDraft: () {},
      onSubmit: () async {
        await Future.delayed(const Duration(seconds: 2));
        return true;
      },
      steps: [
        WizardStep(
          labelAr: 'بيانات العميل',
          descriptionAr: 'معلومات الشركة المراجَعة',
          icon: Icons.business,
          validate: () => _clientName.trim().isEmpty ? 'اسم العميل مطلوب' : null,
          builder: (_) => _step1(),
        ),
        WizardStep(
          labelAr: 'قبول الارتباط والاستقلالية',
          descriptionAr: 'فحص التعارض + تأكيد الاستقلالية',
          icon: Icons.verified_user,
          validate: () => _independenceOK ? null : 'يجب تأكيد الاستقلالية',
          builder: (_) => _step2(),
        ),
        WizardStep(
          labelAr: 'تقييم المخاطر',
          descriptionAr: 'تحديد مستوى المخاطرة العام',
          icon: Icons.warning_amber,
          builder: (_) => _step3(),
        ),
        WizardStep(
          labelAr: 'تحديد الأهمية النسبية',
          descriptionAr: 'Materiality (Overall + Performance + Trivial)',
          icon: Icons.straighten,
          builder: (_) => _step4(),
        ),
        WizardStep(
          labelAr: 'فريق المراجعة',
          descriptionAr: 'تعيين الشركاء والمراجعين',
          icon: Icons.group,
          validate: () => _teamAssigned ? null : 'يجب تعيين الفريق',
          builder: (_) => _step5(),
        ),
        WizardStep(
          labelAr: 'مراجعة وإقرار الخطة',
          descriptionAr: 'إرسال الخطة للشريك لاعتمادها',
          icon: Icons.check_circle,
          validate: () => _reviewedPlan ? null : 'يجب مراجعة الخطة',
          builder: (_) => _step6(),
        ),
      ],
    );
  }

  Widget _step1() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('بيانات الشركة المراجَعة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _clientName = v),
          decoration: InputDecoration(labelText: 'اسم الشركة *', hintText: 'مثال: شركة الراجحي للتجارة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'السجل التجاري', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'القطاع', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
          const SizedBox(width: 12),
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'الإيرادات السنوية (ر.س)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'تاريخ نهاية السنة المالية', hintText: '2025-12-31', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
          const SizedBox(width: 12),
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'نوع المراجعة', hintText: 'سنوية / نصف سنوية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
        ]),
      ]),
    );
  }

  Widget _step2() {
    final checks = [
      ('فحص تعارض المصالح', 'لا يوجد تعارض مع عملاء آخرين', true),
      ('استقلالية الشريك', 'لم يعمل الشريك مع العميل خلال آخر 5 سنوات', true),
      ('الاستقلالية المالية', 'لا توجد علاقات مالية مع العميل', true),
      ('العلاقات العائلية', 'لا توجد علاقات قرابة مع إدارة العميل', true),
      ('الاستقلالية المهنية', 'لا توجد خدمات محظورة مقدّمة', true),
      ('الرسوم المعلّقة', 'لا رسوم غير مسددة من السنة السابقة', true),
    ];
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _purple.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: _purple.withOpacity(0.3))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: _purple),
            SizedBox(width: 10),
            Expanded(child: Text('وفقاً لـ ISA 220 — يجب التأكد من استقلالية الفريق قبل قبول الارتباط', style: TextStyle(fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 16),
        ...checks.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(c.$2, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ])),
              ]),
            )),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _independenceOK,
          onChanged: (v) => setState(() => _independenceOK = v ?? false),
          title: const Text('أقرّ باستقلالية الفريق والالتزام بمعايير ISA 220', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          activeColor: _purple,
          dense: true,
        ),
      ]),
    );
  }

  Widget _step3() {
    final risks = [
      ('low', 'منخفضة', 'الصناعة مستقرة، ضوابط قوية، تاريخ نظيف', Colors.green),
      ('medium', 'متوسطة', 'بعض مخاطر الصناعة، ضوابط مقبولة', Colors.orange),
      ('high', 'مرتفعة', 'مخاطر كبيرة في الإيراد، تاريخ معدّلات سابقة', Colors.red),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('قيّم مستوى المخاطر العام للارتباط', style: TextStyle(fontSize: 13, color: Colors.black54)),
      const SizedBox(height: 12),
      ...risks.map((r) => InkWell(
            onTap: () => setState(() => _riskLevel = r.$1),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _riskLevel == r.$1 ? r.$4.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _riskLevel == r.$1 ? r.$4 : Colors.grey.shade300, width: _riskLevel == r.$1 ? 2 : 1)),
              child: Row(children: [
                Icon(_riskLevel == r.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _riskLevel == r.$1 ? r.$4 : Colors.black38),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مخاطرة ${r.$2}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _riskLevel == r.$1 ? r.$4 : Colors.black87)),
                  Text(r.$3, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: r.$4.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text(r.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: r.$4))),
              ]),
            ),
          )),
    ]);
  }

  Widget _step4() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _gold.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: _gold)),
          child: const Row(children: [
            Icon(Icons.calculate, color: _gold),
            SizedBox(width: 10),
            Expanded(child: Text('الأهمية النسبية تُحسب تلقائياً كنسبة من إجمالي الأصول / الإيراد', style: TextStyle(fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 16),
        _kvBig('إجمالي الإيراد السنوي', '84,500,000 ر.س'),
        const Divider(),
        _kvBig('Overall Materiality (1%)', '845,000 ر.س', color: _gold),
        _kvBig('Performance Materiality (75%)', '633,750 ر.س', color: _navy),
        _kvBig('Trivial Threshold (5%)', '42,250 ر.س', color: Colors.green),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'تعديل Overall (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
          const SizedBox(width: 12),
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'تعديل Performance (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
        ]),
      ]),
    );
  }

  Widget _kvBig(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color ?? Colors.black87)),
      ]),
    );
  }

  Widget _step5() {
    const team = [
      ('د. محمد الراجحي', 'الشريك المسؤول', 'partner', _gold),
      ('أحمد العمري', 'مدير المراجعة', 'manager', Colors.blue),
      ('سارة المطيري', 'مراجع أول', 'senior', Colors.green),
      ('نورة الدوسري', 'مراجع', 'staff', Colors.grey),
      ('خالد الشمراني', 'مراجع متدرب', 'junior', Colors.grey),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('فريق المراجعة المقترح:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        OutlinedButton.icon(onPressed: () => setState(() => _teamAssigned = true), icon: const Icon(Icons.person_add, size: 16), label: const Text('تعيين الكل')),
      ]),
      const SizedBox(height: 12),
      ...team.map((m) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _teamAssigned ? Colors.green.withOpacity(0.3) : Colors.grey.shade200)),
            child: Row(children: [
              CircleAvatar(backgroundColor: m.$4.withOpacity(0.15), child: Text(m.$1[0], style: TextStyle(color: m.$4, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(m.$2, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ])),
              if (_teamAssigned) const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ]),
          )),
    ]);
  }

  Widget _step6() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_purple.withOpacity(0.08), _gold.withOpacity(0.06)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.check_circle, color: _purple, size: 28),
              SizedBox(width: 10),
              Text('ملخّص خطة الارتباط', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _purple)),
            ]),
            const SizedBox(height: 12),
            _summary('العميل', _clientName.isEmpty ? '—' : _clientName),
            _summary('الاستقلالية', _independenceOK ? 'مؤكّدة ✓' : 'لم تؤكّد'),
            _summary('مستوى المخاطر', _riskLevel == 'low' ? 'منخفضة' : (_riskLevel == 'medium' ? 'متوسطة' : 'مرتفعة')),
            _summary('Overall Materiality', '845,000 ر.س'),
            _summary('الفريق', _teamAssigned ? '5 أعضاء ✓' : 'لم يُعيّن'),
            _summary('عدد ساعات العمل المقدّرة', '1,240 ساعة'),
            _summary('الميزانية', '280,000 ر.س'),
          ]),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _reviewedPlan,
          onChanged: (v) => setState(() => _reviewedPlan = v ?? false),
          title: const Text('راجعت الخطة وجاهزة لإرسالها للشريك', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          activeColor: _purple,
          dense: true,
        ),
      ]),
    );
  }

  Widget _summary(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
