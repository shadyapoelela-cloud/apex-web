/// APEX Wave 42 — Cash Flow Forecast (Treasury/cashflow).
/// Route: /app/erp/treasury/cashflow
///
/// 13-week rolling cash flow forecast with scenario analysis.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});
  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  String _scenario = 'base';
  int _selectedWeek = 3;

  // 13 weeks of forecast data
  final _weeks = List.generate(13, (i) => i + 1);

  double _openingBalance(int week) {
    if (week == 1) return 485200;
    return _closingBalance(week - 1);
  }

  double _inflows(int week, String scenario) {
    final base = [245000, 180000, 320000, 290000, 215000, 405000, 378000, 260000, 295000, 342000, 285000, 310000, 398000];
    var v = base[week - 1].toDouble();
    if (scenario == 'optimistic') v *= 1.15;
    if (scenario == 'pessimistic') v *= 0.78;
    return v;
  }

  double _outflows(int week, String scenario) {
    final base = [195000, 142000, 186000, 228000, 167000, 312000, 245000, 189000, 220000, 198000, 205000, 190000, 275000];
    var v = base[week - 1].toDouble();
    if (scenario == 'pessimistic') v *= 1.10;
    return v;
  }

  double _closingBalance(int week) {
    double bal = 485200;
    for (var w = 1; w <= week; w++) {
      bal += _inflows(w, _scenario) - _outflows(w, _scenario);
    }
    return bal;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 20),
        _buildScenarioSelector(),
        const SizedBox(height: 20),
        _buildKPIs(),
        const SizedBox(height: 20),
        _buildChart(),
        const SizedBox(height: 20),
        _buildTable(),
        const SizedBox(height: 20),
        _buildDetailCard(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF006064), Color(0xFF00ACC1)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.waterfall_chart, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التدفق النقدي المتوقع — 13 أسبوع',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('توقع ذكي بناءً على الفواتير المفتوحة، الموردين، الرواتب، وأنماط التحصيل',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector() {
    return Row(
      children: [
        _scenarioChip('pessimistic', 'متحفظ', core_theme.AC.err, Icons.trending_down),
        const SizedBox(width: 8),
        _scenarioChip('base', 'أساسي', core_theme.AC.gold, Icons.timeline),
        const SizedBox(width: 8),
        _scenarioChip('optimistic', 'متفائل', core_theme.AC.ok, Icons.trending_up),
        const Spacer(),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.settings, size: 16),
          label: Text('تخصيص الافتراضات'),
        ),
      ],
    );
  }

  Widget _scenarioChip(String id, String label, Color color, IconData icon) {
    final selected = _scenario == id;
    return InkWell(
      onTap: () => setState(() => _scenario = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : core_theme.AC.td, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? color : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? color : core_theme.AC.tp)),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIs() {
    final totalIn = _weeks.fold(0.0, (s, w) => s + _inflows(w, _scenario));
    final totalOut = _weeks.fold(0.0, (s, w) => s + _outflows(w, _scenario));
    final endBal = _closingBalance(13);
    final minBal = _weeks.map(_closingBalance).reduce((a, b) => a < b ? a : b);

    return Row(
      children: [
        _kpi('الرصيد الحالي', _fmt(485200), core_theme.AC.info, Icons.account_balance),
        _kpi('إجمالي الوارد', _fmt(totalIn), core_theme.AC.ok, Icons.arrow_downward),
        _kpi('إجمالي الصادر', _fmt(totalOut), core_theme.AC.warn, Icons.arrow_upward),
        _kpi('رصيد آخر أسبوع', _fmt(endBal), core_theme.AC.gold, Icons.flag),
        _kpi('أدنى رصيد', _fmt(minBal), minBal < 300000 ? core_theme.AC.err : core_theme.AC.info, Icons.warning_amber),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final maxVal = _weeks.map(_closingBalance).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الرصيد النقدي المتوقع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final w in _weeks)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedWeek = w),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(_fmt(_closingBalance(w)),
                                style: TextStyle(fontSize: 9, color: _selectedWeek == w ? core_theme.AC.gold : core_theme.AC.ts, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Container(
                              height: (_closingBalance(w) / maxVal) * 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: _selectedWeek == w
                                      ? [core_theme.AC.gold, const Color(0xFFE6C200)]
                                      : [const Color(0xFF00ACC1), const Color(0xFF006064)],
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('أسبوع $w', style: const TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: core_theme.AC.navy3,
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('الأسبوع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('افتتاحي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('وارد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.ok))),
                Expanded(flex: 2, child: Text('صادر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.warn))),
                Expanded(flex: 2, child: Text('صافي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('ختامي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
              ],
            ),
          ),
          for (final w in _weeks)
            InkWell(
              onTap: () => setState(() => _selectedWeek = w),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedWeek == w ? core_theme.AC.gold.withOpacity(0.08) : null,
                  border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('أسبوع $w', style: TextStyle(fontSize: 12, fontWeight: _selectedWeek == w ? FontWeight.w800 : FontWeight.w500))),
                    Expanded(flex: 2, child: Text(_fmt(_openingBalance(w)), style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 2, child: Text(_fmt(_inflows(w, _scenario)), style: TextStyle(fontSize: 12, color: core_theme.AC.ok, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text(_fmt(_outflows(w, _scenario)), style: TextStyle(fontSize: 12, color: core_theme.AC.warn, fontWeight: FontWeight.w700))),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _fmt(_inflows(w, _scenario) - _outflows(w, _scenario)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _inflows(w, _scenario) > _outflows(w, _scenario) ? core_theme.AC.ok : core_theme.AC.err,
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(_fmt(_closingBalance(w)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: core_theme.AC.info,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.info),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: core_theme.AC.info),
              const SizedBox(width: 8),
              Text('تفاصيل الأسبوع $_selectedWeek',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('📥 تحصيلات متوقعة من العملاء', _fmt(_inflows(_selectedWeek, _scenario) * 0.75), 'بناءً على فواتير مفتوحة'),
          _detailRow('💵 مبيعات نقدية متوقعة', _fmt(_inflows(_selectedWeek, _scenario) * 0.25), 'بناءً على متوسط آخر 4 أسابيع'),
          _detailRow('💸 دفعات للموردين', _fmt(_outflows(_selectedWeek, _scenario) * 0.50), 'أوامر شراء مستحقة'),
          _detailRow('👥 رواتب وبدلات', _fmt(_outflows(_selectedWeek, _scenario) * 0.30), 'إذا وقع فيه راتب الشهر'),
          _detailRow('🏢 إيجار ومصاريف ثابتة', _fmt(_outflows(_selectedWeek, _scenario) * 0.20), 'التزامات متكررة'),
          if (_closingBalance(_selectedWeek) < 300000) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.err,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: core_theme.AC.err),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: core_theme.AC.err, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: الرصيد المتوقع أقل من الحد الأدنى الآمن (300,000 ر.س). فكّر في تسريع التحصيل أو تأجيل دفعة.',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.err),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(hint, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
