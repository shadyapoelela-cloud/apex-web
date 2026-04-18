import 'package:flutter/material.dart';

/// 🎉 Wave 125 — AI Financial Analyst (Capstone MILESTONE)
class AiFinancialAnalystScreen extends StatefulWidget {
  const AiFinancialAnalystScreen({super.key});
  @override
  State<AiFinancialAnalystScreen> createState() => _AiFinancialAnalystScreenState();
}

class _AiFinancialAnalystScreenState extends State<AiFinancialAnalystScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37), indicatorWeight: 3,
          tabs: const [Tab(text: 'الرؤى الذكية'), Tab(text: 'التنبؤات'), Tab(text: 'المخاطر'), Tab(text: 'محادثة AI')])),
        Expanded(child: TabBarView(controller: _tc, children: [_insightsTab(), _forecastsTab(), _risksTab(), _chatTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFFD700)]),
        borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🎉 المحلل المالي AI — Wave 125', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('ذكاء اصطناعي يفهم أعمالك ويقدم توصيات استراتيجية', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 16), SizedBox(width: 4),
          Text('Claude 4', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('رؤى اليوم', '42', Icons.lightbulb, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('دقة التنبؤ', '94%', Icons.trending_up, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('مخاطر مكتشفة', '${_risks.length}', Icons.warning, const Color(0xFFE65100))),
    Expanded(child: _kpi('محادثات', '1,248', Icons.chat, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _insightsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _insights.length, itemBuilder: (_, i) {
    final ins = _insights[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
            gradient: LinearGradient(colors: [ins.color, ins.color.withValues(alpha: 0.6)]),
            borderRadius: BorderRadius.circular(8)),
            child: Icon(ins.icon, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(ins.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ins.color))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: ins.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(ins.priority, style: TextStyle(color: ins.color, fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Text(ins.description, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.recommend, color: Color(0xFFD4AF37), size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text('التوصية: ${ins.recommendation}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500))),
          ])),
      ]),
    ));
  });

  Widget _forecastsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _forecasts.length, itemBuilder: (_, i) {
    final f = _forecasts[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(f.metric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Text('${f.confidence}%', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _forecastCard('الحالي', f.current, const Color(0xFF1A237E))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.black54)),
          Expanded(child: _forecastCard('90 يوم', f.forecast90, const Color(0xFFD4AF37))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.black54)),
          Expanded(child: _forecastCard('سنة', f.forecastYear, const Color(0xFF2E7D32))),
        ]),
        const SizedBox(height: 8),
        Text(f.narrative, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
      ]),
    ));
  });

  Widget _forecastCard(String l, String v, Color c) => Container(padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
    ]),
  );

  Widget _risksTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _risks.length, itemBuilder: (_, i) {
    final r = _risks[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
            color: _severityColor(r.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.warning_amber, color: _severityColor(r.severity), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _severityColor(r.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(r.severity, style: TextStyle(color: _severityColor(r.severity), fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        Text(r.description, style: const TextStyle(fontSize: 11.5)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.timeline, size: 12, color: Colors.black54),
          const SizedBox(width: 4),
          Text('احتمالية: ${r.probability}%', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(width: 12),
          const Icon(Icons.attach_money, size: 12, color: Colors.black54),
          const SizedBox(width: 4),
          Text('أثر مالي: ${r.impact}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
      ]),
    ));
  });

  Widget _chatTab() => Column(children: [
    Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _chat.length, itemBuilder: (_, i) {
      final m = _chat[i];
      return Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: m.isAi ? MainAxisAlignment.start : MainAxisAlignment.end, children: [
          if (m.isAi) Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFFD4AF37)]), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16)),
          if (m.isAi) const SizedBox(width: 8),
          Flexible(child: Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: m.isAi ? Colors.white : const Color(0xFF4A148C),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
            ),
            child: Text(m.message, style: TextStyle(fontSize: 13, color: m.isAi ? Colors.black87 : Colors.white)))),
          if (!m.isAi) const SizedBox(width: 8),
          if (!m.isAi) const CircleAvatar(radius: 16, backgroundColor: Color(0xFF1A237E), child: Icon(Icons.person, color: Colors.white, size: 16)),
        ]),
      );
    })),
    Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(
      color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: Row(children: [
        Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(24)),
          child: const Text('اسألني أي شيء عن أعمالك...', style: TextStyle(color: Colors.black45)))),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFFD4AF37)]), shape: BoxShape.circle),
          child: const Icon(Icons.send, color: Colors.white, size: 20)),
      ])),
  ]);

  Color _severityColor(String s) {
    if (s.contains('حرج')) return const Color(0xFFC62828);
    if (s.contains('عالي')) return const Color(0xFFE65100);
    if (s.contains('متوسط')) return const Color(0xFFD4AF37);
    return const Color(0xFF2E7D32);
  }

  static const List<_Insight> _insights = [
    _Insight('نمو غير مستدام في التكاليف التشغيلية', 'تكاليف الموظفين ارتفعت 28% مقابل 14% نمو إيرادات. الفجوة مقلقة وتستدعي مراجعة الهيكل الوظيفي.', 'راجع خطة التوظيف Q3 — 4 مناصب يمكن تأجيلها أو دمجها. توفير متوقع: 1.8M ر.س سنوياً.', 'حرج',
      Icons.trending_up, Color(0xFFC62828)),
    _Insight('فرصة توفير في الضرائب', 'اكتشفنا 480K ر.س مصاريف لم تُستخدم كأوعية خصم VAT قابلة للاسترداد.', 'قدّم طلب تعديل عبر VAT Return Builder قبل نهاية Q2 — المهلة 30 يوم.', 'عالي',
      Icons.savings, Color(0xFFD4AF37)),
    _Insight('تركّز خطر في قاعدة العملاء', 'أعلى 3 عملاء يمثلون 58% من الإيرادات. فقدان أحدهم = كارثة سيولة.', 'فعّل برنامج تنويع العملاء — الهدف: لا عميل > 15% من الإيرادات خلال 18 شهر.', 'عالي',
      Icons.group, Color(0xFFE65100)),
    _Insight('تحسين دورة التحصيل', 'DSO متوسط 68 يوم (الصناعة 45). السيولة الحبيسة: 4.2M ر.س.', 'طبّق خصم مبكر 2% للدفع خلال 15 يوم + أتمتة التذكيرات. تحسن متوقع: -18 يوم.', 'متوسط',
      Icons.account_balance_wallet, Color(0xFF1A237E)),
    _Insight('أداء استثنائي في قطاع التجزئة', 'قسم التجزئة حقق 142% من الهدف Q1 — نمو 45% YoY.', 'ضاعف الاستثمار في فريق التجزئة + افتح 3 فروع جديدة. ROI متوقع 4.2x خلال 24 شهر.', 'معلوماتي',
      Icons.star, Color(0xFF2E7D32)),
    _Insight('إشارات بكتابة القوائم المالية', 'لاحظت نمطاً غير معتاد في قيود نهاية الشهر — قيود يدوية كبيرة في اللحظات الأخيرة.', 'راجع 12 قيد يدوي بقيمة > 50K ر.س في آخر 3 أيام من الشهر — احتمال تحفظات الإدارة.', 'عالي',
      Icons.search, Color(0xFF4A148C)),
  ];

  static const List<_Forecast> _forecasts = [
    _Forecast('الإيرادات الشهرية', '2.84M', '3.12M (+9.8%)', '38.4M (+12.4%)', 92, 'نمو مستقر مدفوع بتوسع قاعدة العملاء والتسعير الجديد لـ Enterprise'),
    _Forecast('التدفق النقدي الحر', '580K', '1.24M (+113%)', '9.8M', 88, 'تحسن كبير متوقع بعد تحصيل متأخرات Q1 + فوترة العقود السنوية'),
    _Forecast('صافي الربح', '420K', '520K (+23.8%)', '6.2M (+18.4%)', 94, 'هامش ربح صافي يرتفع من 14.8% إلى 16.1% بفضل كفاءة التشغيل'),
    _Forecast('عدد الموظفين', '128', '142 (+11%)', '165 (+29%)', 95, 'توسع مخطط في Sales + Engineering لدعم النمو المتوقع'),
  ];

  static const List<_Risk> _risks = [
    _Risk('تقلبات سعر الصرف', 'الريال مرتبط بالدولار — لكن 22% من المبيعات باليورو/ين. التذبذب الحالي يؤثر.', 'متوسط', 68, '380K ر.س/شهر'),
    _Risk('ارتفاع تكلفة الاستيراد', 'رسوم جمركية جديدة متوقعة على القطاع. 15% من COGS في خطر.', 'عالي', 82, '1.2M ر.س/ربع'),
    _Risk('نقص الكفاءات التقنية', '5 مطورين مناصب مفتوحة منذ 4 أشهر. يؤثر على خارطة طريق المنتج.', 'عالي', 90, 'تأخر إيرادات 2.4M'),
    _Risk('ضغط أسعار المنافسين', 'منافس دولي نزل أسعاره 18% — ضغط على هامش الربح.', 'متوسط', 55, '4-6% من الهامش'),
    _Risk('تغيرات تنظيمية ZATCA', 'تحديث قادم لمتطلبات فاتورة — تكلفة امتثال متوقعة 480K ر.س.', 'حرج', 95, '480K ر.س لمرة واحدة'),
  ];

  static const List<_Msg> _chat = [
    _Msg('مرحباً! أنا المحلل المالي الذكي لـ APEX. يمكنني تحليل بياناتك، التنبؤ بالأداء، واكتشاف الفرص والمخاطر. كيف أساعدك اليوم؟', true),
    _Msg('كيف أداء الربع الأول مقارنة بالموازنة؟', false),
    _Msg('تحليل Q1 2026:\n\n✅ الإيرادات: 8.52M ر.س (تجاوز الهدف بـ 4.8%)\n⚠️ التكاليف التشغيلية: 6.12M ر.س (أعلى من المخطط بـ 8%)\n✅ صافي الربح: 1.28M ر.س (+12% عن المخطط)\n\nالملاحظة الأبرز: كفاءة الإيرادات ممتازة لكن ضبط التكاليف يحتاج مراجعة — خاصة البنود التسويقية التي تجاوزت الموازنة بـ 34%.', true),
    _Msg('ما أكبر 3 مخاطر حالية؟', false),
    _Msg('أكبر 3 مخاطر (بناءً على تحليل البيانات):\n\n1️⃣ تركز العملاء: أعلى 3 عملاء = 58% من الإيرادات\n2️⃣ التقلب في سعر الصرف: 22% مبيعات باليورو/ين\n3️⃣ ارتفاع رواتب المطورين: نقص الكفاءات يدفع الرواتب +28% YoY\n\nأيها تريد خطة معالجة تفصيلية؟', true),
  ];
}

class _Insight { final String title, description, recommendation, priority; final IconData icon; final Color color;
  const _Insight(this.title, this.description, this.recommendation, this.priority, this.icon, this.color); }
class _Forecast { final String metric, current, forecast90, forecastYear; final int confidence; final String narrative;
  const _Forecast(this.metric, this.current, this.forecast90, this.forecastYear, this.confidence, this.narrative); }
class _Risk { final String title, description, severity; final int probability; final String impact;
  const _Risk(this.title, this.description, this.severity, this.probability, this.impact); }
class _Msg { final String message; final bool isAi;
  const _Msg(this.message, this.isAi); }
