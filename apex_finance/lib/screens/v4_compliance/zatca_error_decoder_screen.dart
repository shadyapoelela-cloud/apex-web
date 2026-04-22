import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 140 — ZATCA Error Decoder + Arabic translations
class ZatcaErrorDecoderScreen extends StatefulWidget {
  const ZatcaErrorDecoderScreen({super.key});
  @override
  State<ZatcaErrorDecoderScreen> createState() => _ZatcaErrorDecoderScreenState();
}

class _ZatcaErrorDecoderScreenState extends State<ZatcaErrorDecoderScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'الأخطاء الشائعة'), Tab(text: 'أخطائي الأخيرة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_commonTab(), _myErrorsTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC62828), Color(0xFFB71C1C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.bug_report, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مفكّك أخطاء ZATCA', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('ترجمة عربية + شرح + حل لكل رمز خطأ من ZATCA', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('رموز مفهرسة', '182', Icons.library_books, const Color(0xFFC62828))),
    Expanded(child: _kpi('أخطاء اليوم', '3', Icons.error, const Color(0xFFE65100))),
    Expanded(child: _kpi('معدل الحل', '94%', Icons.check_circle, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('زمن الحل', '4 دقائق', Icons.speed, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _commonTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _errors.length, itemBuilder: (_, i) {
    final e = _errors[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ExpansionTile(
      title: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _severityColor(e.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(e.code, style: TextStyle(color: _severityColor(e.severity), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Expanded(child: Text(e.titleAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ]),
      subtitle: Text(e.category, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      children: [
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('📜 الرسالة الأصلية (EN)', e.messageEn),
          _section('🗨️ الترجمة العربية', e.messageAr),
          _section('💡 السبب', e.reason),
          _section('✅ الحل', e.solution),
          if (e.example.isNotEmpty) _section('📝 مثال', e.example, mono: true),
        ])),
      ],
    ));
  });

  Widget _section(String title, String body, {bool mono = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4A148C))),
      const SizedBox(height: 2),
      Text(body, style: TextStyle(fontSize: 12, fontFamily: mono ? 'monospace' : null)),
    ]));

  Widget _myErrorsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _myErrors.length, itemBuilder: (_, i) {
    final e = _myErrors[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _severityColor(e.severity).withValues(alpha: 0.15),
        child: Text(e.code.substring(0, 3), style: TextStyle(color: _severityColor(e.severity), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      subtitle: Text('${e.invoice} • ${e.date}', style: const TextStyle(fontSize: 10)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: _resStatusColor(e.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(e.status, style: TextStyle(color: _resStatusColor(e.status), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏆 أكثر الأخطاء تكراراً', 'KSA-IN-BR-51 (VAT rounding) — 28 حالة هذا الشهر', const Color(0xFFC62828)),
    _insight('⚡ زمن الحل المتوسط', '4 دقائق — أسرع من متوسط القطاع (25 دقيقة)', const Color(0xFF2E7D32)),
    _insight('📊 توزيع الأخطاء', 'Validation 52% • Cryptography 22% • Network 18% • أخرى 8%', const Color(0xFF1A237E)),
    _insight('🎯 معدل النجاح الآلي', '94% من الأخطاء تحل تلقائياً عبر AI fix', core_theme.AC.gold),
    _insight('📉 اتجاه الشهر', '-32% انخفاض في الأخطاء بعد تفعيل Auto-Fix', const Color(0xFF2E7D32)),
    _insight('✅ الأخطاء الحرجة', '0 أخطاء حرجة غير محلولة حالياً', const Color(0xFF4A148C)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _severityColor(String s) {
    if (s.contains('حرج')) return const Color(0xFFC62828);
    if (s.contains('عالي')) return const Color(0xFFE65100);
    if (s.contains('متوسط')) return core_theme.AC.gold;
    return const Color(0xFF1A237E);
  }

  Color _resStatusColor(String s) {
    if (s.contains('محلول')) return const Color(0xFF2E7D32);
    if (s.contains('معلق')) return const Color(0xFFE65100);
    if (s.contains('فشل')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  static const List<_ErrCode> _errors = [
    _ErrCode('KSA-IN-BR-51', 'خطأ في تقريب VAT', 'Validation / VAT',
      'Sum of VAT amount at document level should equal total at line level',
      'مجموع ضريبة القيمة المضافة على مستوى المستند يجب أن يساوي إجمالي مستوى البنود',
      'عادةً بسبب اختلاف في تقريب الأرقام بين حساب VAT لكل بند والإجمالي',
      'استخدم banker rounding (ROUND_HALF_EVEN) أو احسب VAT على مستوى المستند بدلاً من البنود',
      'Line1: 100 * 0.15 = 15.00\nLine2: 200 * 0.15 = 30.00\nExpected total: 45.00 (not 44.99)', 'حرج'),
    _ErrCode('KSA-2', 'PIH غير صحيح', 'Cryptography',
      'Previous Invoice Hash (PIH) does not match expected chain',
      'هاش الفاتورة السابقة (PIH) لا يطابق السلسلة المتوقعة',
      'ICV التسلسلي للفاتورة السابقة مختلف عن المُرسل في current invoice',
      'تأكد من:\n1. ترتيب الفواتير حسب الوقت\n2. استخدام hash الفاتورة السابقة الحقيقي\n3. عدم وجود فجوات في ICV',
      'Previous hash (Base64): NWQyMWE4ZDc0...\nExpected in current: NWQyMWE4ZDc0...', 'حرج'),
    _ErrCode('KSA-3', 'توقيع رقمي غير صحيح', 'Cryptography',
      'Digital signature verification failed',
      'فشل التحقق من التوقيع الرقمي',
      'المفتاح الخاص المستخدم للتوقيع لا يطابق شهادة CSID النشطة',
      '1. تحقق من صحة CSID النشط\n2. تأكد من استخدام المفتاح الخاص الصحيح\n3. أعد تجديد CSID إذا كانت الشهادة منتهية',
      '', 'حرج'),
    _ErrCode('BR-KSA-01', 'رقم VAT غير صحيح', 'Validation',
      'VAT registration number format invalid',
      'صيغة رقم التسجيل الضريبي غير صحيحة',
      'يجب أن يكون 15 رقماً، يبدأ بـ 3، وينتهي بـ 3',
      'تحقق من صيغة VAT: 3xxxxxxxxxxxx03 (15 رقماً)',
      'الصحيح: 310175494400003\nالخطأ: 31017549440000 (14 رقم)', 'عالي'),
    _ErrCode('BR-KSA-09', 'QR غير صحيح', 'Validation / QR',
      'TLV QR code is missing required fields',
      'QR code بصيغة TLV ينقصه حقول مطلوبة',
      'QR يجب أن يحتوي على 5 حقول على الأقل: Seller, VAT, Timestamp, Total, VAT Total',
      'أعد توليد QR مع كل الحقول + Phase 2 zatca format',
      'T=1, V=1, XML hash, Digital sig, Public key ← Phase 2', 'عالي'),
    _ErrCode('BR-KSA-EN16931', 'فرع غير مطابق EN16931', 'Standards',
      'Invoice does not conform to EN16931 European standard',
      'الفاتورة غير مطابقة للمعيار الأوروبي EN16931',
      'ZATCA تبنّت EN16931 كأساس، بعض الحقول المطلوبة ناقصة',
      'أضف: Purchase order ref, Contract ref, Supplier address (structured)',
      '', 'متوسط'),
    _ErrCode('EMRG-HTTP-500', 'Fatoora API غير متاح', 'Network',
      'ZATCA Fatoora endpoint returned 500',
      'بوابة Fatoora لدى ZATCA أرجعت خطأ 500',
      'مشكلة مؤقتة في خدمة ZATCA',
      'استخدم retry queue — سيعاد الإرسال تلقائياً خلال 5 دقائق',
      '', 'متوسط'),
    _ErrCode('KSA-52', 'Timestamp في المستقبل', 'Validation',
      'Invoice issue date/time is in the future',
      'تاريخ/وقت إصدار الفاتورة في المستقبل',
      'الساعة على الجهاز غير متزامنة مع UTC',
      'زامن الساعة مع NTP server. استخدم UTC دائماً',
      '2026-04-20 03:00:00+00:00 ← خطأ إذا الوقت الحالي 04-19', 'متوسط'),
  ];

  static const List<_MyError> _myErrors = [
    _MyError('KSA-IN-BR-51', 'خطأ في تقريب VAT', 'INV-2026-4821', '2026-04-19 09:42', 'محلول', 'عالي'),
    _MyError('BR-KSA-01', 'رقم VAT غير صحيح', 'INV-2026-4820', '2026-04-19 09:30', 'محلول', 'عالي'),
    _MyError('EMRG-HTTP-500', 'Fatoora API غير متاح', 'INV-2026-4818', '2026-04-19 08:15', 'محلول', 'متوسط'),
    _MyError('KSA-IN-BR-51', 'خطأ في تقريب VAT', 'INV-2026-4810', '2026-04-18 16:22', 'محلول', 'عالي'),
    _MyError('BR-KSA-EN16931', 'فرع غير مطابق EN16931', 'INV-2026-4802', '2026-04-18 11:45', 'معلق', 'متوسط'),
  ];
}

class _ErrCode { final String code, titleAr, category, messageEn, messageAr, reason, solution, example, severity;
  const _ErrCode(this.code, this.titleAr, this.category, this.messageEn, this.messageAr, this.reason, this.solution, this.example, this.severity); }
class _MyError { final String code, title, invoice, date, status, severity;
  const _MyError(this.code, this.title, this.invoice, this.date, this.status, this.severity); }
