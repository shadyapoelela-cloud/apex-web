import 'package:flutter/material.dart';
import 'main.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});
  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _PlanTile extends StatelessWidget {
  final String title, price, duration;
  final List<String> features;
  final Color color;
  final bool popular, selected;
  final VoidCallback onTap;
  const _PlanTile({required this.title, required this.price, required this.duration, required this.features, required this.color, this.popular = false, this.selected = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : AC.navy3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AC.border, width: selected ? 1.5 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            if (selected) Icon(Icons.check_circle_rounded, color: color, size: 22)
            else const Icon(Icons.radio_button_unchecked, color: AC.textHint, size: 22),
            if (popular) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text("الأكثر طلباً", style: TextStyle(fontSize: 9, color: color, fontFamily: "Tajawal", fontWeight: FontWeight.w700)))],
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? color : AC.textPrimary, fontFamily: "Tajawal")),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(" ريال", style: TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: "Tajawal")),
                Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, fontFamily: "Tajawal")),
              ]),
            ]),
          ]),
          const SizedBox(height: 8),
          Text("المدة: $duration", textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: "Tajawal")),
          const SizedBox(height: 6),
          ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(f, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: "Tajawal")),
              const SizedBox(width: 6),
              Icon(Icons.check_rounded, color: color.withOpacity(0.6), size: 14),
            ]))),
        ])));
  }
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedType = '';
  String _selectedPlan = '449';
  bool _submitted = false;

  final _consultTypes = [
    {'icon': Icons.account_balance_rounded, 'title': 'تحليل القوائم المالية', 'desc': 'مراجعة شاملة مع توصيات تحسين', 'color': 0xFFD4A84B},
    {'icon': Icons.trending_up_rounded, 'title': 'تحليل المبيعات والنمو', 'desc': 'استراتيجيات زيادة المبيعات', 'color': 0xFF2ECC8A},
    {'icon': Icons.account_balance_wallet_rounded, 'title': 'الجاهزية الائتمانية', 'desc': 'تأهيل ملفك للحصول على تمويل', 'color': 0xFF6C5CE7},
    {'icon': Icons.assessment_rounded, 'title': 'التقييم ودراسة الجدوى', 'desc': 'تقييم شركتك أو مشروعك الجديد', 'color': 0xFFE17055},
    {'icon': Icons.inventory_2_rounded, 'title': 'إدارة المخزون', 'desc': 'تحسين دوران المخزون وتقليل الهدر', 'color': 0xFFF0A500},
    {'icon': Icons.compare_arrows_rounded, 'title': 'استشارة مالية عامة', 'desc': 'أي سؤال مالي أو محاسبي', 'color': 0xFF0984E3},
  ];

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, elevation: 0,
        title: const Text('استشارة مهنية متخصصة', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: _submitted ? _buildSuccess() : _buildForm()),
    );
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // بانر رئيسي
      Container(width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AC.gold.withOpacity(0.15), AC.navy3], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.gold.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AC.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: const Text('تبدأ من 249 ريال', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal'))),
            const Spacer(),
            Container(width: 56, height: 56,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.support_agent_rounded, color: AC.navy, size: 28)),
          ]),
          const SizedBox(height: 14),
          const Text('فريق من المستشارين الماليين المعتمدين', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          const Text('خبرة تتجاوز 15 عاماً في التحليل المالي والاستشارات المحاسبية. نقدم لك تحليلاً دقيقاً بنسبة 99%+ مع خطة عمل واضحة.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.6)),
        ])),
      const SizedBox(height: 20),

      // مستويات الاستشارة
      const Text('اختر مستوى الاستشارة', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
      const SizedBox(height: 12),
      _PlanTile(title: 'استشارة سريعة', price: '249', duration: '30 دقيقة', features: const ['جلسة فيديو 30 دقيقة','إجابة على استفساراتك','ملخص مكتوب بعد الجلسة'], color: AC.cyan, selected: _selectedPlan == '249', onTap: () => setState(() => _selectedPlan = '249')),
      const SizedBox(height: 10),
      _PlanTile(title: 'استشارة شاملة', price: '449', duration: '60 دقيقة', features: const ['جلسة فيديو 60 دقيقة','تقرير PDF مفصّل','متابعة لمدة أسبوع'], color: AC.gold, popular: true, selected: _selectedPlan == '449', onTap: () => setState(() => _selectedPlan = '449')),
      const SizedBox(height: 10),
      _PlanTile(title: 'استشارة متقدمة', price: '749', duration: '90 دقيقة', features: const ['جلسة فيديو 90 دقيقة','تقرير PDF + خطة عمل مفصلة','متابعة لمدة شهر كامل','جلسة متابعة مجانية'], color: const Color(0xFF6C5CE7), selected: _selectedPlan == '749', onTap: () => setState(() => _selectedPlan = '749')),
      const SizedBox(height: 20),

      // اختيار نوع الاستشارة
      const Text('اختر نوع الاستشارة', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
      const SizedBox(height: 12),
      ..._consultTypes.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedType = t['title'] as String),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _selectedType == t['title'] ? Color(t['color'] as int).withOpacity(0.1) : AC.navy3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selectedType == t['title'] ? Color(t['color'] as int).withOpacity(0.5) : AC.border, width: _selectedType == t['title'] ? 1.5 : 1)),
            child: Row(children: [
              if (_selectedType == t['title'])
                Icon(Icons.check_circle_rounded, color: Color(t['color'] as int), size: 20)
              else
                Icon(Icons.radio_button_unchecked, color: AC.textHint, size: 20),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(t['title'] as String, textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedType == t['title'] ? Color(t['color'] as int) : AC.textPrimary, fontFamily: 'Tajawal')),
                Text(t['desc'] as String, textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ]),
              const SizedBox(width: 10),
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Color(t['color'] as int).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(t['icon'] as IconData, color: Color(t['color'] as int), size: 20)),
            ]))))),
      const SizedBox(height: 20),

      // بيانات التواصل
      const Text('بيانات التواصل', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
      const SizedBox(height: 12),
      _inputField('الاسم الكامل', _nameCtrl, Icons.person_rounded),
      const SizedBox(height: 10),
      _inputField('رقم الجوال', _phoneCtrl, Icons.phone_rounded, keyboard: TextInputType.phone),
      const SizedBox(height: 10),
      _inputField('البريد الإلكتروني', _emailCtrl, Icons.email_rounded, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 10),
      _inputField('وصف المشكلة أو الاستفسار', _descCtrl, Icons.edit_note_rounded, maxLines: 4),
      const SizedBox(height: 20),

      // ملخص الطلب
      if (_selectedType.isNotEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.gold.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.gold.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('ملخص الطلب', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            _summaryRow('نوع الاستشارة', _selectedType),
            _summaryRow('المدة', _selectedPlan == '249' ? '30 دقيقة' : _selectedPlan == '449' ? '60 دقيقة' : '90 دقيقة'),
            _summaryRow('يشمل', _selectedPlan == '749' ? 'تقرير PDF + خطة عمل + متابعة شهر' : _selectedPlan == '449' ? 'تقرير PDF + متابعة أسبوع' : 'ملخص مكتوب'),
            _summaryRow('المستوى', _selectedPlan == '249' ? 'سريعة — 30 دقيقة' : _selectedPlan == '449' ? 'شاملة — 60 دقيقة' : 'متقدمة — 90 دقيقة'),
            _summaryRow('التكلفة', ' ريال'),
            const SizedBox(height: 4),
            const Text('* الدفع عند تأكيد الموعد', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 10, color: AC.textHint, fontFamily: 'Tajawal')),
          ])),
      const SizedBox(height: 16),

      // زر الإرسال
      GestureDetector(
        onTap: _selectedType.isNotEmpty && _nameCtrl.text.isNotEmpty && _phoneCtrl.text.isNotEmpty ? _submit : null,
        child: Container(width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: _selectedType.isNotEmpty ? const LinearGradient(colors: [AC.gold, AC.goldDim]) : null,
            color: _selectedType.isEmpty ? AC.navy3 : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _selectedType.isNotEmpty ? AC.gold.withOpacity(0.5) : AC.border)),
          child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.send_rounded, color: _selectedType.isNotEmpty ? AC.navy : AC.textHint, size: 18),
            const SizedBox(width: 8),
            Text('إرسال طلب الاستشارة',
              style: TextStyle(color: _selectedType.isNotEmpty ? AC.navy : AC.textHint, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
          ])))),
      const SizedBox(height: 40),
    ]);
  }

  Widget _buildSuccess() {
    return Column(children: [
      const SizedBox(height: 60),
      Container(width: 100, height: 100,
        decoration: BoxDecoration(color: AC.success.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_rounded, color: AC.success, size: 60)),
      const SizedBox(height: 24),
      const Text('تم إرسال طلبك بنجاح!', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
      const SizedBox(height: 12),
      const Text('سيتواصل معك أحد مستشارينا خلال 24 ساعة\nلتحديد موعد الجلسة المناسب لك',
        textDirection: TextDirection.rtl, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.6)),
      const SizedBox(height: 30),
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('تفاصيل طلبك', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          const SizedBox(height: 10),
          _summaryRow('نوع الاستشارة', _selectedType),
          _summaryRow('الاسم', _nameCtrl.text),
          _summaryRow('الجوال', _phoneCtrl.text),
          if (_emailCtrl.text.isNotEmpty) _summaryRow('البريد', _emailCtrl.text),
          _summaryRow('رقم الطلب', 'APEX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'),
        ])),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(width: double.infinity, height: 52,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('العودة للخدمات', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
    ]);
  }

  void _submit() {
    setState(() => _submitted = true);
  }

  Widget _featureCard(IconData icon, String title, String sub) {
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Column(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: AC.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AC.gold, size: 20)),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboard, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: TextField(controller: ctrl, keyboardType: keyboard, maxLines: maxLines, textDirection: TextDirection.rtl,
        style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal'),
        decoration: InputDecoration(
          hintText: label, hintStyle: const TextStyle(color: AC.textHint, fontFamily: 'Tajawal'),
          suffixIcon: Icon(icon, color: AC.textHint, size: 20),
          border: InputBorder.none, contentPadding: const EdgeInsets.all(14))));
  }

  Widget _summaryRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Flexible(child: Text(value, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textPrimary, fontFamily: 'Tajawal'))),
        const Spacer(),
        Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }
}




