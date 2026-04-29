/// APEX Wave 78 — Scenario Planning / What-If Analysis.
/// Route: /app/erp/finance/scenarios
///
/// Sensitivity analysis and multi-scenario P&L forecasting.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ScenarioPlanningScreen extends StatefulWidget {
  const ScenarioPlanningScreen({super.key});
  @override
  State<ScenarioPlanningScreen> createState() => _ScenarioPlanningScreenState();
}

class _ScenarioPlanningScreenState extends State<ScenarioPlanningScreen> {
  // Base case values
  double _revenueGrowth = 15;
  double _priceIncrease = 5;
  double _volumeGrowth = 10;
  double _cogsInflation = 8;
  double _opexInflation = 6;
  double _headcountGrowth = 12;
  double _fxShock = 0;

  final double _baseRevenue = 18_500_000;
  final double _baseCogs = 10_800_000;
  final double _baseOpex = 4_200_000;
  final double _baseHeadcount = 2_800_000;

  String _activeScenario = 'base';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        _buildScenarioButtons(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildDrivers()),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _buildResults()),
          ],
        ),
        const SizedBox(height: 16),
        _buildSensitivityMatrix(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF283593), Color(0xFF5E35B1)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التخطيط بالسيناريوهات (What-If)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('نمذجة مالية ديناميكية — حرّك المحركات وشاهد أثرها الفوري على الربحية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioButtons() {
    return Row(
      children: [
        _scenarioBtn('pessimistic', 'السيناريو المتحفظ', core_theme.AC.err, Icons.trending_down),
        const SizedBox(width: 10),
        _scenarioBtn('base', 'الخط الأساسي', core_theme.AC.gold, Icons.timeline),
        const SizedBox(width: 10),
        _scenarioBtn('optimistic', 'السيناريو المتفائل', core_theme.AC.ok, Icons.trending_up),
        const SizedBox(width: 10),
        _scenarioBtn('stress', 'Stress Test', Colors.deepOrange, Icons.warning),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _revenueGrowth = 15;
              _priceIncrease = 5;
              _volumeGrowth = 10;
              _cogsInflation = 8;
              _opexInflation = 6;
              _headcountGrowth = 12;
              _fxShock = 0;
              _activeScenario = 'base';
            });
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: Text('إعادة ضبط'),
        ),
      ],
    );
  }

  Widget _scenarioBtn(String id, String label, Color color, IconData icon) {
    final selected = _activeScenario == id;
    return InkWell(
      onTap: () {
        setState(() {
          _activeScenario = id;
          // Apply scenario defaults
          switch (id) {
            case 'pessimistic':
              _revenueGrowth = 5;
              _priceIncrease = 2;
              _volumeGrowth = 3;
              _cogsInflation = 12;
              _opexInflation = 10;
              _headcountGrowth = 8;
              _fxShock = -8;
              break;
            case 'base':
              _revenueGrowth = 15;
              _priceIncrease = 5;
              _volumeGrowth = 10;
              _cogsInflation = 8;
              _opexInflation = 6;
              _headcountGrowth = 12;
              _fxShock = 0;
              break;
            case 'optimistic':
              _revenueGrowth = 28;
              _priceIncrease = 8;
              _volumeGrowth = 20;
              _cogsInflation = 6;
              _opexInflation = 4;
              _headcountGrowth = 18;
              _fxShock = 3;
              break;
            case 'stress':
              _revenueGrowth = -12;
              _priceIncrease = 0;
              _volumeGrowth = -15;
              _cogsInflation = 18;
              _opexInflation = 15;
              _headcountGrowth = 0;
              _fxShock = -15;
              break;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrivers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('محركات النموذج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _driver('نمو الإيرادات (YoY)', _revenueGrowth, -30, 50, core_theme.AC.ok,
              (v) => setState(() => _revenueGrowth = v)),
          _driver('زيادة الأسعار', _priceIncrease, -10, 20, core_theme.AC.info,
              (v) => setState(() => _priceIncrease = v)),
          _driver('نمو الحجم (Volume)', _volumeGrowth, -20, 40, core_theme.AC.info,
              (v) => setState(() => _volumeGrowth = v)),
          const Divider(),
          _driver('تضخم تكلفة المبيعات', _cogsInflation, 0, 25, core_theme.AC.warn,
              (v) => setState(() => _cogsInflation = v)),
          _driver('تضخم المصروفات التشغيلية', _opexInflation, 0, 20, Colors.deepOrange,
              (v) => setState(() => _opexInflation = v)),
          _driver('نمو الموظفين', _headcountGrowth, -10, 30, core_theme.AC.purple,
              (v) => setState(() => _headcountGrowth = v)),
          const Divider(),
          _driver('صدمة سعر الصرف', _fxShock, -25, 10, core_theme.AC.err,
              (v) => setState(() => _fxShock = v)),
        ],
      ),
    );
  }

  Widget _driver(String label, double value, double min, double max, Color color, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text('${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {
                onChanged(v);
                setState(() => _activeScenario = 'custom');
              },
            ),
          ),
        ],
      ),
    );
  }

  double get _projRevenue => _baseRevenue * (1 + _revenueGrowth / 100) * (1 + _fxShock / 100);
  double get _projCogs => _baseCogs * (1 + _cogsInflation / 100) * (1 + _volumeGrowth / 100);
  double get _projOpex => _baseOpex * (1 + _opexInflation / 100);
  double get _projHeadcount => _baseHeadcount * (1 + _headcountGrowth / 100);
  double get _projGross => _projRevenue - _projCogs;
  double get _projEbitda => _projGross - _projOpex - _projHeadcount;
  double get _projMargin => _projRevenue > 0 ? _projEbitda / _projRevenue * 100 : 0;
  double get _baseMargin => (_baseRevenue - _baseCogs - _baseOpex - _baseHeadcount) / _baseRevenue * 100;

  Widget _buildResults() {
    final ebitdaDelta = _projEbitda - (_baseRevenue - _baseCogs - _baseOpex - _baseHeadcount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ebitdaDelta >= 0
              ? [core_theme.AC.ok, core_theme.AC.ok]
              : [core_theme.AC.err, core_theme.AC.err],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.white),
              SizedBox(width: 8),
              Text('نتائج التوقع',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          _plRow('الإيرادات', _baseRevenue, _projRevenue),
          _plRow('تكلفة المبيعات', _baseCogs, _projCogs, isCost: true),
          _plRow('إجمالي الربح', _baseRevenue - _baseCogs, _projGross, highlight: true),
          _plRow('المصروفات التشغيلية', _baseOpex, _projOpex, isCost: true),
          _plRow('الرواتب والمزايا', _baseHeadcount, _projHeadcount, isCost: true),
          Divider(color: core_theme.AC.td),
          _plRow('EBITDA', _baseRevenue - _baseCogs - _baseOpex - _baseHeadcount, _projEbitda, highlight: true, big: true),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text('هامش EBITDA', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                const Spacer(),
                Text('${_baseMargin.toStringAsFixed(1)}%',
                    style: TextStyle(color: core_theme.AC.td, fontSize: 14, fontWeight: FontWeight.w700)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, color: core_theme.AC.ts, size: 14),
                ),
                Text('${_projMargin.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plRow(String label, double base, double proj, {bool highlight = false, bool big = false, bool isCost = false}) {
    final delta = proj - base;
    final deltaFavorable = isCost ? delta < 0 : delta > 0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: big ? 8 : 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: big ? 14 : 12,
                    fontWeight: highlight ? FontWeight.w900 : FontWeight.w500)),
          ),
          Expanded(
            child: Text(_fmt(base),
                style: TextStyle(color: core_theme.AC.ts, fontSize: 11, fontFamily: 'monospace')),
          ),
          Icon(Icons.arrow_forward, color: core_theme.AC.td, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_fmt(proj),
                style: TextStyle(
                    color: highlight ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: big ? 14 : 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${deltaFavorable ? '+' : ''}${(delta / base * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: deltaFavorable ? const Color(0xFFFFD700) : core_theme.AC.err,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensitivityMatrix() {
    // Sensitivity of EBITDA to each driver ±5%
    final drivers = [
      ('نمو الإيرادات', _revenueGrowth, 1.0),
      ('تضخم COGS', _cogsInflation, -0.58),
      ('نمو الحجم', _volumeGrowth, 0.42),
      ('زيادة الأسعار', _priceIncrease, 0.95),
      ('تضخم OPEX', _opexInflation, -0.23),
      ('نمو الموظفين', _headcountGrowth, -0.15),
      ('صدمة العملة', _fxShock, 0.72),
    ];
    drivers.sort((a, b) => b.$3.abs().compareTo(a.$3.abs()));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF5E35B1)),
              SizedBox(width: 8),
              Text('تحليل الحساسية (Tornado Chart)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text('مدى تأثير كل محرّك على EBITDA عند تحريكه ±5 نقاط',
              style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 14),
          for (final d in drivers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(d.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 28, color: core_theme.AC.navy3),
                        Container(
                          alignment: d.$3 >= 0 ? Alignment.centerRight : Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: d.$3.abs().clamp(0.0, 1.0),
                            alignment: d.$3 >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                            heightFactor: 1,
                            child: Container(
                              margin: EdgeInsets.only(
                                left: d.$3 >= 0 ? MediaQuery.of(context).size.width * 0.15 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: d.$3 >= 0 ? core_theme.AC.ok : core_theme.AC.err,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(d.$3 >= 0 ? 4 : 0),
                                  bottomRight: Radius.circular(d.$3 >= 0 ? 4 : 0),
                                  topLeft: Radius.circular(d.$3 < 0 ? 4 : 0),
                                  bottomLeft: Radius.circular(d.$3 < 0 ? 4 : 0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${d.$3 > 0 ? '+' : ''}${(d.$3 * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: core_theme.AC.info,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: core_theme.AC.info),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: core_theme.AC.info, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أعلى محرّكين تأثيراً على الربحية: نمو الإيرادات وزيادة الأسعار. ركّز جهود التحسين عليهما.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
