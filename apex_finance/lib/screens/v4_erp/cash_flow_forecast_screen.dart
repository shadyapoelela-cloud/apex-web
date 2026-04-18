/// APEX Wave 42 — Cash Flow Forecast (Treasury/cashflow).
/// Route: /app/erp/treasury/cashflow
///
/// 13-week rolling cash flow forecast with scenario analysis.
library;

import 'package:flutter/material.dart';

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
      child: const Row(
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
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
        _scenarioChip('pessimistic', 'متحفظ', Colors.red, Icons.trending_down),
        const SizedBox(width: 8),
        _scenarioChip('base', 'أساسي', const Color(0xFFD4AF37), Icons.timeline),
        const SizedBox(width: 8),
        _scenarioChip('optimistic', 'متفائل', Colors.green, Icons.trending_up),
        const Spacer(),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.settings, size: 16),
          label: const Text('تخصيص الافتراضات'),
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
          border: Border.all(color: selected ? color : Colors.black26, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? color : Colors.black54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? color : Colors.black87)),
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
        _kpi('الرصيد الحالي', _fmt(485200), Colors.blue, Icons.account_balance),
        _kpi('إجمالي الوارد', _fmt(totalIn), Colors.green, Icons.arrow_downward),
        _kpi('إجمالي الصادر', _fmt(totalOut), Colors.orange, Icons.arrow_upward),
        _kpi('رصيد آخر أسبوع', _fmt(endBal), const Color(0xFFD4AF37), Icons.flag),
        _kpi('أدنى رصيد', _fmt(minBal), minBal < 300000 ? Colors.red : Colors.teal, Icons.warning_amber),
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
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
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
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرصيد النقدي المتوقع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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
                                style: TextStyle(fontSize: 9, color: _selectedWeek == w ? const Color(0xFFD4AF37) : Colors.black54, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Container(
                              height: (_closingBalance(w) / maxVal) * 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: _selectedWeek == w
                                      ? [const Color(0xFFD4AF37), const Color(0xFFE6C200)]
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
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('الأسبوع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('افتتاحي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('وارد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green))),
                Expanded(flex: 2, child: Text('صادر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.orange))),
                Expanded(flex: 2, child: Text('صافي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('ختامي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
              ],
            ),
          ),
          for (final w in _weeks)
            InkWell(
              onTap: () => setState(() => _selectedWeek = w),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedWeek == w ? const Color(0xFFD4AF37).withOpacity(0.08) : null,
                  border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('أسبوع $w', style: TextStyle(fontSize: 12, fontWeight: _selectedWeek == w ? FontWeight.w800 : FontWeight.w500))),
                    Expanded(flex: 2, child: Text(_fmt(_openingBalance(w)), style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 2, child: Text(_fmt(_inflows(w, _scenario)), style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text(_fmt(_outflows(w, _scenario)), style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w700))),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _fmt(_inflows(w, _scenario) - _outflows(w, _scenario)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _inflows(w, _scenario) > _outflows(w, _scenario) ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(_fmt(_closingBalance(w)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.blue),
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: الرصيد المتوقع أقل من الحد الأدنى الآمن (300,000 ر.س). فكّر في تسريع التحصيل أو تأجيل دفعة.',
                      style: TextStyle(fontSize: 11, color: Colors.red),
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
                Text(hint, style: const TextStyle(fontSize: 10, color: Colors.black54)),
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
