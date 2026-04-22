/// V5.2 — What-If Scenarios playground (interactive).
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ScenariosV52Screen extends StatefulWidget {
  const ScenariosV52Screen({super.key});

  @override
  State<ScenariosV52Screen> createState() => _ScenariosV52ScreenState();
}

class _ScenariosV52ScreenState extends State<ScenariosV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  // Scenario drivers (baselines)
  double _revenueGrowth = 22;
  double _priceIncrease = 5;
  double _cogsInflation = 8;
  double _opexGrowth = 12;
  double _headcountChange = 5;

  // Baseline financials (YTD Q1 2026 annualized)
  static const _baseRevenue = 84000000.0;
  static const _baseCOGS = 40000000.0;
  static const _baseOpex = 18000000.0;
  static const _baseSalaries = 22000000.0;

  String _scenario = 'realistic';

  double get _projectedRevenue => _baseRevenue * (1 + (_revenueGrowth + _priceIncrease) / 100);
  double get _projectedCOGS => _baseCOGS * (1 + _cogsInflation / 100);
  double get _projectedOpex => _baseOpex * (1 + _opexGrowth / 100);
  double get _projectedSalaries => _baseSalaries * (1 + _headcountChange / 100);
  double get _projectedProfit => _projectedRevenue - _projectedCOGS - _projectedOpex - _projectedSalaries;
  double get _baseProfit => _baseRevenue - _baseCOGS - _baseOpex - _baseSalaries;
  double get _projectedMargin => _projectedRevenue > 0 ? _projectedProfit / _projectedRevenue * 100 : 0;
  double get _baseMargin => _baseRevenue > 0 ? _baseProfit / _baseRevenue * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(children: [
          _header(),
          _presets(),
          Expanded(child: Row(children: [
            SizedBox(width: 380, child: _sliders()),
            const VerticalDivider(width: 1),
            Expanded(child: _results()),
          ])),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.insights, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سيناريوهات What-If', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('محاكي مالي تفاعلي — غيّر المحركات وشاهد الأثر الفوري', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () => _applyPreset('realistic'), icon: const Icon(Icons.refresh, size: 16), label: Text('إعادة التعيين')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.save, size: 16), label: Text('حفظ السيناريو')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.compare, size: 16), label: Text('مقارنة 3 سيناريوهات')),
      ]),
    );
  }

  Widget _presets() {
    final presets = [
      ('conservative', 'محافظ', '📉', core_theme.AC.err),
      ('realistic', 'واقعي', '⚖️', core_theme.AC.info),
      ('optimistic', 'متفائل', '📈', core_theme.AC.ok),
      ('crisis', 'أزمة', '🔴', core_theme.AC.warn),
      ('aggressive', 'توسّع', '🚀', _gold),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: presets.map((p) {
        final selected = p.$1 == _scenario;
        return Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: InkWell(
          onTap: () => _applyPreset(p.$1),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: selected ? p.$4.withOpacity(0.12) : core_theme.AC.navy3, borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? p.$4 : core_theme.AC.bdr, width: selected ? 2 : 1)),
            child: Column(children: [
              Text(p.$3, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(p.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? _navy : core_theme.AC.tp)),
            ]),
          ),
        )));
      }).toList()),
    );
  }

  void _applyPreset(String id) {
    setState(() {
      _scenario = id;
      switch (id) {
        case 'conservative':
          _revenueGrowth = 8;
          _priceIncrease = 2;
          _cogsInflation = 5;
          _opexGrowth = 3;
          _headcountChange = 0;
          break;
        case 'realistic':
          _revenueGrowth = 22;
          _priceIncrease = 5;
          _cogsInflation = 8;
          _opexGrowth = 12;
          _headcountChange = 5;
          break;
        case 'optimistic':
          _revenueGrowth = 35;
          _priceIncrease = 8;
          _cogsInflation = 6;
          _opexGrowth = 15;
          _headcountChange = 10;
          break;
        case 'crisis':
          _revenueGrowth = -15;
          _priceIncrease = -3;
          _cogsInflation = 12;
          _opexGrowth = 5;
          _headcountChange = -10;
          break;
        case 'aggressive':
          _revenueGrowth = 60;
          _priceIncrease = 10;
          _cogsInflation = 10;
          _opexGrowth = 40;
          _headcountChange = 30;
          break;
      }
    });
  }

  Widget _sliders() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: ListView(children: [
        Text('🎛️ المحرّكات (Drivers)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        Text('غيّر القيم لمشاهدة الأثر الفوري', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 20),
        _slider('نموّ الإيرادات', _revenueGrowth, -30, 80, '%', Icons.trending_up, core_theme.AC.ok, (v) => setState(() => _revenueGrowth = v)),
        _slider('زيادة الأسعار', _priceIncrease, -10, 20, '%', Icons.attach_money, _gold, (v) => setState(() => _priceIncrease = v)),
        _slider('تضخّم تكلفة المبيعات', _cogsInflation, -5, 25, '%', Icons.inventory, core_theme.AC.warn, (v) => setState(() => _cogsInflation = v)),
        _slider('نموّ المصروفات التشغيلية', _opexGrowth, -10, 50, '%', Icons.business_center, core_theme.AC.err, (v) => setState(() => _opexGrowth = v)),
        _slider('تغيّر الموظفين', _headcountChange, -30, 40, '%', Icons.people, _navy, (v) => setState(() => _headcountChange = v)),
      ]),
    );
  }

  Widget _slider(String label, double value, double min, double max, String unit, IconData icon, Color color, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text('${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}$unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
        ]),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: color, thumbColor: color, inactiveTrackColor: color.withOpacity(0.2)),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        Row(children: [Text('${min.toStringAsFixed(0)}$unit', style: TextStyle(fontSize: 10, color: core_theme.AC.td)), const Spacer(), Text('${max.toStringAsFixed(0)}$unit', style: TextStyle(fontSize: 10, color: core_theme.AC.td))]),
      ]),
    );
  }

  Widget _results() {
    final profitChange = _projectedProfit - _baseProfit;
    final marginChange = _projectedMargin - _baseMargin;
    return Container(
      color: const Color(0xFFF6F6F5),
      padding: const EdgeInsets.all(16),
      child: ListView(children: [
        Text('📊 النتائج المحاكاة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _bigStat('صافي الربح المتوقَّع', '${(_projectedProfit / 1e6).toStringAsFixed(2)}M', 'ر.س', profitChange >= 0 ? core_theme.AC.ok : core_theme.AC.err, '${profitChange >= 0 ? '+' : ''}${(profitChange / 1e6).toStringAsFixed(2)}M')),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('هامش الربح', '${_projectedMargin.toStringAsFixed(1)}', '%', _projectedMargin >= 20 ? core_theme.AC.ok : _projectedMargin >= 10 ? _gold : core_theme.AC.err, '${marginChange >= 0 ? '+' : ''}${marginChange.toStringAsFixed(1)}pp')),
        ]),

        const SizedBox(height: 20),
        Text('📋 مقارنة البنود (Baseline vs Scenario)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 10),
        _comparisonCard('الإيرادات', _baseRevenue, _projectedRevenue, true),
        _comparisonCard('تكلفة المبيعات', _baseCOGS, _projectedCOGS, false),
        _comparisonCard('المصروفات التشغيلية', _baseOpex, _projectedOpex, false),
        _comparisonCard('الرواتب', _baseSalaries, _projectedSalaries, false),

        const SizedBox(height: 20),
        Text('💡 رؤى AI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 10),
        ..._generateInsights(),
      ]),
    );
  }

  Widget _comparisonCard(String label, double base, double projected, bool higherIsBetter) {
    final change = projected - base;
    final changePct = base != 0 ? change / base * 100 : 0.0;
    final isFavorable = higherIsBetter ? change > 0 : change < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
      child: Row(children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        SizedBox(width: 100, child: Text('${(base / 1e6).toStringAsFixed(2)}M', style: TextStyle(fontSize: 12, color: core_theme.AC.ts, fontFamily: 'monospace'), textAlign: TextAlign.end)),
        const SizedBox(width: 8),
        Icon(Icons.arrow_back, size: 14, color: core_theme.AC.td),
        const SizedBox(width: 8),
        SizedBox(width: 100, child: Text('${(projected / 1e6).toStringAsFixed(2)}M', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace'), textAlign: TextAlign.end)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isFavorable ? core_theme.AC.ok : core_theme.AC.err).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text('${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isFavorable ? core_theme.AC.ok : core_theme.AC.err))),
      ]),
    );
  }

  List<Widget> _generateInsights() {
    final insights = <(IconData, String, Color)>[];
    if (_projectedMargin < 10) {
      insights.add((Icons.warning, 'تحذير: هامش الربح أقل من 10% — يُنصح بمراجعة الأسعار', core_theme.AC.err));
    }
    if (_projectedMargin > 30) {
      insights.add((Icons.star, 'ممتاز! هامش فوق 30% — مستوى نخبة', core_theme.AC.ok));
    }
    if (_cogsInflation > _priceIncrease + 5) {
      insights.add((Icons.info, 'زيادة الأسعار لا تواكب تضخّم التكلفة — الهامش يُضغط', core_theme.AC.warn));
    }
    if (_revenueGrowth > 40) {
      insights.add((Icons.rocket, 'نمو طموح — تأكد من قدرة العمليات على الاستيعاب', _gold));
    }
    if (_opexGrowth > _revenueGrowth + 5) {
      insights.add((Icons.trending_down, 'المصروفات تنمو أسرع من الإيرادات — خطر تآكل الربحية', core_theme.AC.err));
    }
    if (_projectedProfit < 0) {
      insights.add((Icons.dangerous, 'خسارة متوقّعة — السيناريو غير مربح', core_theme.AC.err));
    }
    if (insights.isEmpty) {
      insights.add((Icons.check_circle, 'السيناريو متوازن — الأساسيات قوية', core_theme.AC.ok));
    }
    return insights.map((i) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: i.$3.withOpacity(0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: i.$3.withOpacity(0.3))),
      child: Row(children: [
        Icon(i.$1, color: i.$3, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(i.$2, style: const TextStyle(fontSize: 12, height: 1.4))),
      ]),
    )).toList();
  }

  Widget _bigStat(String label, String value, String unit, Color color, String delta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color.withOpacity(0.9))),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(unit, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ]),
        const SizedBox(height: 4),
        Text(delta + ' مقابل الأساس', style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
      ]),
    );
  }
}
