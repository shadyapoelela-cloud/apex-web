import 'package:flutter/material.dart';

/// Wave 134 — Advanced Financial Ratios Dashboard (18+ ratios)
class AdvancedRatiosScreen extends StatefulWidget {
  const AdvancedRatiosScreen({super.key});
  @override
  State<AdvancedRatiosScreen> createState() => _AdvancedRatiosScreenState();
}

class _AdvancedRatiosScreenState extends State<AdvancedRatiosScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 5, vsync: this); }
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'السيولة'),
            Tab(text: 'المديونية'),
            Tab(text: 'الربحية'),
            Tab(text: 'الكفاءة'),
            Tab(text: 'التقييم'),
          ])),
        Expanded(child: TabBarView(controller: _tc, children: [
          _ratioList(_liquidity, const Color(0xFF1565C0)),
          _ratioList(_leverage, const Color(0xFFE65100)),
          _ratioList(_profitability, const Color(0xFF2E7D32)),
          _ratioList(_efficiency, const Color(0xFFD4AF37)),
          _ratioList(_valuation, const Color(0xFF4A148C)),
        ])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.analytics, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('النسب المالية المتقدمة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('25 نسبة مالية عبر 5 فئات + مقارنة مرجعية بالقطاع', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('الصحة المالية', 'A-', Icons.health_and_safety, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('Altman Z', '3.42', Icons.shield, const Color(0xFF1565C0))),
    Expanded(child: _kpi('نسبة مقارنة', '68% أعلى', Icons.compare_arrows, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('Red Flags', '2', Icons.flag, const Color(0xFFE65100))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _ratioList(List<_Ratio> ratios, Color accent) => ListView.builder(padding: const EdgeInsets.all(12), itemCount: ratios.length, itemBuilder: (_, i) {
    final r = ratios[i];
    final betterThanPeers = _isBetter(r.company, r.peer, r.higherIsBetter);
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (betterThanPeers ? const Color(0xFF2E7D32) : const Color(0xFFE65100)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(betterThanPeers ? 'أفضل من القطاع' : 'أقل من القطاع',
              style: TextStyle(color: betterThanPeers ? const Color(0xFF2E7D32) : const Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 6),
        Text(r.formula, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _valueBox('الشركة', r.company, accent)),
          const SizedBox(width: 8),
          Expanded(child: _valueBox('متوسط القطاع', r.peer, Colors.grey.shade700)),
          const SizedBox(width: 8),
          Expanded(child: _valueBox('المستهدف', r.target, Colors.black87)),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(6)),
          child: Text('💡 ${r.interpretation}', style: const TextStyle(fontSize: 11))),
      ]),
    ));
  });

  Widget _valueBox(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  bool _isBetter(String co, String peer, bool higherIsBetter) {
    double _parse(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
    final c = _parse(co), p = _parse(peer);
    return higherIsBetter ? c > p : c < p;
  }

  static const List<_Ratio> _liquidity = [
    _Ratio('النسبة الجارية', 'الأصول المتداولة / الالتزامات المتداولة', '2.8', '1.9', '> 2.0', true,
      'وضع سيولة ممتاز — قدرة كبيرة على سداد الالتزامات قصيرة الأجل'),
    _Ratio('النسبة السريعة (Quick)', '(الأصول المتداولة - المخزون) / الالتزامات المتداولة', '1.9', '1.2', '> 1.0', true,
      'مؤشر قوي للسيولة الفورية حتى بدون تصريف المخزون'),
    _Ratio('نسبة النقدية', 'النقدية / الالتزامات المتداولة', '0.85', '0.45', '> 0.20', true,
      'احتياطي نقدي قوي'),
    _Ratio('رأس المال العامل', 'الأصول المتداولة - الالتزامات المتداولة', '5.8M', '2.1M', '> 1.5M', true,
      'فائض كبير يدعم النمو العضوي'),
    _Ratio('CCC (دورة التحويل النقدي)', 'DSO + DIO - DPO', '28 يوم', '45 يوم', '< 40', false,
      'دورة نقدية سريعة — كفاءة في إدارة رأس المال العامل'),
  ];

  static const List<_Ratio> _leverage = [
    _Ratio('الدين إلى حقوق الملكية (D/E)', 'إجمالي الديون / حقوق الملكية', '0.35', '0.75', '< 1.0', false,
      'مستوى ديون محافظ — مخاطر مالية منخفضة'),
    _Ratio('نسبة الديون', 'إجمالي الديون / إجمالي الأصول', '0.22', '0.42', '< 0.4', false,
      'هيكل تمويل سليم'),
    _Ratio('تغطية الفوائد', 'EBIT / مصاريف الفوائد', '8.4x', '4.2x', '> 3x', true,
      'قدرة ممتازة على خدمة الديون'),
    _Ratio('DSCR', '(EBITDA - ضرائب) / (فوائد + أقساط)', '2.8x', '1.8x', '> 1.5x', true,
      'قدرة فائضة على خدمة الديون مع مرونة عالية'),
    _Ratio('Equity Multiplier', 'إجمالي الأصول / حقوق الملكية', '1.28', '1.75', '1.0-2.0', false,
      'توازن جيد بين المخاطر والعوائد'),
  ];

  static const List<_Ratio> _profitability = [
    _Ratio('هامش الربح الإجمالي', '(الإيرادات - تكلفة البضاعة) / الإيرادات', '52%', '38%', '> 40%', true,
      'تسعير قوي وكفاءة في الإنتاج'),
    _Ratio('هامش EBITDA', 'EBITDA / الإيرادات', '28%', '18%', '> 20%', true,
      'قوة تشغيلية استثنائية'),
    _Ratio('هامش صافي الربح', 'صافي الربح / الإيرادات', '17%', '9%', '> 12%', true,
      'الأرباح الفعلية تحوّل جيداً'),
    _Ratio('ROE (العائد على حقوق الملكية)', 'صافي الربح / حقوق الملكية', '22%', '14%', '> 15%', true,
      'عائد ممتاز للمساهمين'),
    _Ratio('ROA (العائد على الأصول)', 'صافي الربح / إجمالي الأصول', '15%', '7%', '> 8%', true,
      'كفاءة عالية في استخدام الأصول'),
    _Ratio('ROIC (العائد على رأس المال المستثمر)', 'NOPAT / رأس المال المستثمر', '18%', '11%', '> WACC', true,
      'يخلق قيمة تفوق تكلفة رأس المال'),
  ];

  static const List<_Ratio> _efficiency = [
    _Ratio('دوران الأصول', 'الإيرادات / إجمالي الأصول', '1.42', '1.05', '> 1.0', true,
      'استخدام فعال للأصول في توليد الإيرادات'),
    _Ratio('DSO (فترة التحصيل)', 'الذمم المدينة × 365 / الإيرادات', '32 يوم', '52 يوم', '< 45', false,
      'تحصيل سريع — ائتمان عملاء مُدار جيداً'),
    _Ratio('DIO (دوران المخزون)', 'المخزون × 365 / تكلفة البضاعة', '48 يوم', '85 يوم', '< 60', false,
      'دوران سريع للمخزون'),
    _Ratio('DPO (فترة السداد)', 'الذمم الدائنة × 365 / تكلفة البضاعة', '52 يوم', '42 يوم', '~ 45', true,
      'استفادة ممتازة من الائتمان التجاري'),
    _Ratio('دوران المخزون (مرات)', 'تكلفة البضاعة / المخزون', '7.6x', '4.3x', '> 5x', true,
      'إدارة فعالة للمخزون'),
  ];

  static const List<_Ratio> _valuation = [
    _Ratio('P/E (مكرر الأرباح)', 'سعر السهم / EPS', '14.2x', '18.5x', '8-20x', false,
      'تقييم معقول — فرصة شراء محتملة'),
    _Ratio('P/B (مكرر القيمة الدفترية)', 'سعر السهم / القيمة الدفترية', '2.8x', '2.1x', '1-3x', false,
      'علاوة على القيمة الدفترية مبررة بالعائدات'),
    _Ratio('EV/EBITDA', 'قيمة المنشأة / EBITDA', '9.5x', '11.2x', '6-12x', false,
      'أقل من متوسط القطاع'),
    _Ratio('EV/Revenue', 'قيمة المنشأة / الإيرادات', '1.9x', '2.4x', '1-3x', false,
      'تقييم عادل'),
    _Ratio('ربح السهم EPS', 'صافي الربح / عدد الأسهم', '38.5', '22.4', 'نمو ≥ 10%', true,
      'نمو قوي في ربحية السهم'),
  ];
}

class _Ratio { final String name, formula, company, peer, target; final bool higherIsBetter; final String interpretation;
  const _Ratio(this.name, this.formula, this.company, this.peer, this.target, this.higherIsBetter, this.interpretation); }
