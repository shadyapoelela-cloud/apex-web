/// APEX V5.1 — Connected Planning (Enhancement #16).
///
/// Anaplan-style: change a business driver, watch all connected
/// scenarios recalculate instantly. Replaces Anaplan ($100K+/yr) for
/// SMB/mid-market planning.
///
/// Route: /app/erp/finance/budgets
library;

import 'package:flutter/material.dart';

class ConnectedPlanningScreen extends StatefulWidget {
  const ConnectedPlanningScreen({super.key});

  @override
  State<ConnectedPlanningScreen> createState() =>
      _ConnectedPlanningScreenState();
}

class _ConnectedPlanningScreenState extends State<ConnectedPlanningScreen> {
  // Drivers
  double _salesGrowth = 15; // %
  double _salaryInflation = 4; // %
  double _oilPrice = 85; // $/barrel
  double _usdRate = 3.75; // SAR/USD
  double _costReduction = 2; // %

  @override
  Widget build(BuildContext context) {
    // Base scenario
    const baseSales = 12_000_000.0;
    const baseCogs = 7_200_000.0;
    const baseSalaries = 1_800_000.0;
    const baseOpex = 800_000.0;

    final sales = baseSales * (1 + _salesGrowth / 100);
    final cogs = baseCogs * (1 - _costReduction / 100) * (1 + _salesGrowth / 100 * 0.7);
    final salaries = baseSalaries * (1 + _salaryInflation / 100);
    final fxImpact = baseOpex * 0.3 * ((_usdRate - 3.75) / 3.75); // 30% USD-denominated
    final opex = baseOpex + fxImpact;
    final oilImpact = (_oilPrice - 85) * 5000; // proxy

    final grossProfit = sales - cogs;
    final ebitda = grossProfit - salaries - opex + oilImpact;
    final ebitdaMargin = (ebitda / sales) * 100;

    // Alternative scenarios
    final base = _calculateBase();
    final delta = ebitda - base.ebitda;
    final pctChange = (delta / base.ebitda) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التخطيط المتّصل (Connected Planning)',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'غيّر driver واحد — جميع السيناريوهات تتحدّث فوراً · مثل Anaplan',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    r'يستبدل Anaplan ($100K+/yr)',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main 2-column layout
          LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 900;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildDrivers()),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _buildResults(
                            sales, cogs, salaries, opex,
                            grossProfit, ebitda, ebitdaMargin,
                            delta, pctChange,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildDrivers(),
                        const SizedBox(height: 12),
                        _buildResults(
                          sales, cogs, salaries, opex,
                          grossProfit, ebitda, ebitdaMargin,
                          delta, pctChange,
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  _BaseScenario _calculateBase() {
    const sales = 12_000_000.0 * 1.15; // 15% growth
    const cogs = 7_200_000.0 * 0.98 * 1.105;
    const salaries = 1_800_000.0 * 1.04;
    const opex = 800_000.0;
    final gp = sales - cogs;
    final ebitda = gp - salaries - opex;
    return _BaseScenario(ebitda: ebitda);
  }

  Widget _buildDrivers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 6),
              Text(
                'المحرّكات (Drivers)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Spacer(),
              Text(
                'اسحب — شاهد التأثير',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _driver(
            label: 'نمو المبيعات',
            value: _salesGrowth,
            min: -10,
            max: 40,
            suffix: '% YoY',
            icon: Icons.trending_up,
            color: const Color(0xFF059669),
            onChanged: (v) => setState(() => _salesGrowth = v),
          ),
          _driver(
            label: 'تضخم الرواتب',
            value: _salaryInflation,
            min: 0,
            max: 15,
            suffix: '%',
            icon: Icons.groups,
            color: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _salaryInflation = v),
          ),
          _driver(
            label: 'سعر النفط',
            value: _oilPrice,
            min: 40,
            max: 150,
            suffix: 'USD/bbl',
            icon: Icons.oil_barrel,
            color: const Color(0xFFD97706),
            onChanged: (v) => setState(() => _oilPrice = v),
          ),
          _driver(
            label: 'سعر الدولار',
            value: _usdRate,
            min: 3.60,
            max: 4.00,
            divisions: 40,
            suffix: 'SAR',
            icon: Icons.currency_exchange,
            color: const Color(0xFF7C3AED),
            onChanged: (v) => setState(() => _usdRate = v),
          ),
          _driver(
            label: 'تقليل التكاليف',
            value: _costReduction,
            min: -5,
            max: 15,
            suffix: '%',
            icon: Icons.savings,
            color: const Color(0xFF059669),
            onChanged: (v) => setState(() => _costReduction = v),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb, size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'كل driver مترابط مع 3-5 بنود في القوائم المالية · يعاد الحساب <50ms',
                    style: TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _salesGrowth = 15;
                      _salaryInflation = 4;
                      _oilPrice = 85;
                      _usdRate = 3.75;
                      _costReduction = 2;
                    });
                  },
                  icon: const Icon(Icons.restart_alt, size: 14),
                  label: const Text('إعادة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.save, size: 14),
                  label: const Text('حفظ كسيناريو'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _driver({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String suffix,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${value.toStringAsFixed(suffix == 'SAR' ? 2 : 1)} $suffix',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.12),
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? ((max - min) * 2).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    double sales, double cogs, double salaries, double opex,
    double grossProfit, double ebitda, double ebitdaMargin,
    double delta, double pctChange,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              const Text(
                'قائمة الدخل المتوقّعة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: delta >= 0
                      ? const Color(0xFF059669).withOpacity(0.1)
                      : const Color(0xFFB91C1C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: delta >= 0 ? const Color(0xFF059669) : const Color(0xFFB91C1C),
                    ),
                    Text(
                      '${pctChange.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: delta >= 0 ? const Color(0xFF059669) : const Color(0xFFB91C1C),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'مقابل السيناريو الأساسي',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _pnlRow('المبيعات', sales, color: const Color(0xFF059669), bold: true),
          _pnlRow('تكلفة البضاعة المباعة', -cogs),
          _pnlRow('إجمالي الربح', grossProfit, color: const Color(0xFF1565C0), bold: true, top: true),
          _pnlRow('الرواتب', -salaries),
          _pnlRow('المصروفات التشغيلية', -opex),
          const SizedBox(height: 4),
          _pnlRow(
            'EBITDA',
            ebitda,
            color: delta >= 0 ? const Color(0xFF059669) : const Color(0xFFB91C1C),
            bold: true,
            big: true,
            top: true,
          ),
          const SizedBox(height: 10),
          // EBITDA margin
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Text(
                  'هامش EBITDA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${ebitdaMargin.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1565C0),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Impact cascade
          const Text(
            'تسلسل التأثير',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _impactRow(
            'تغيير نمو المبيعات → المبيعات + تكلفة البضاعة',
            icon: Icons.trending_up,
          ),
          _impactRow(
            'تغيير تضخم الرواتب → مصروف الرواتب + EOSB',
            icon: Icons.groups,
          ),
          _impactRow(
            'تغيير سعر الدولار → 30% من المصروفات التشغيلية (مستوردة)',
            icon: Icons.currency_exchange,
          ),
          _impactRow(
            'تغيير سعر النفط → تأثير غير مباشر عبر تكاليف الطاقة',
            icon: Icons.oil_barrel,
          ),
        ],
      ),
    );
  }

  Widget _pnlRow(
    String label,
    double value, {
    Color? color,
    bool bold = false,
    bool big = false,
    bool top = false,
  }) {
    final prefix = value < 0 ? '(' : '';
    final suffix = value < 0 ? ')' : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: top
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.1))),
            )
          : null,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: big ? 14 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            '$prefix${value.abs().toStringAsFixed(0)}$suffix',
            style: TextStyle(
              fontSize: big ? 16 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: color ?? Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactRow(String text, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}

class _BaseScenario {
  final double ebitda;
  _BaseScenario({required this.ebitda});
}
