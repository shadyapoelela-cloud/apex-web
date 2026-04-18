/// APEX Wave 79 — Break-Even Analysis.
/// Route: /app/erp/finance/breakeven
///
/// Unit economics: fixed + variable costs, contribution margin,
/// break-even point, margin of safety.
library;

import 'package:flutter/material.dart';

class BreakEvenScreen extends StatefulWidget {
  const BreakEvenScreen({super.key});
  @override
  State<BreakEvenScreen> createState() => _BreakEvenScreenState();
}

class _BreakEvenScreenState extends State<BreakEvenScreen> {
  // Product-level unit economics
  double _pricePerUnit = 1200;
  double _variableCostPerUnit = 720;
  double _fixedCostsMonthly = 680_000;
  double _expectedUnitsMonthly = 2_500;

  double get _contributionMargin => _pricePerUnit - _variableCostPerUnit;
  double get _contributionMarginPct => _pricePerUnit > 0 ? _contributionMargin / _pricePerUnit * 100 : 0;
  double get _breakEvenUnits => _contributionMargin > 0 ? _fixedCostsMonthly / _contributionMargin : 0;
  double get _breakEvenRevenue => _breakEvenUnits * _pricePerUnit;
  double get _expectedRevenue => _expectedUnitsMonthly * _pricePerUnit;
  double get _expectedProfit => _expectedRevenue - (_expectedUnitsMonthly * _variableCostPerUnit) - _fixedCostsMonthly;
  double get _marginOfSafety => _expectedUnitsMonthly > _breakEvenUnits
      ? (_expectedUnitsMonthly - _breakEvenUnits) / _expectedUnitsMonthly * 100
      : 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildInputs()),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _buildResults()),
          ],
        ),
        const SizedBox(height: 16),
        _buildChart(),
        const SizedBox(height: 16),
        _buildPerProduct(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF006064), Color(0xFF00838F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.balance, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تحليل نقطة التعادل',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Break-Even Analysis · احتساب الوحدات والإيرادات اللازمة لتغطية التكاليف',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المدخلات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _numField('سعر الوحدة', _pricePerUnit, 'ر.س', (v) => setState(() => _pricePerUnit = v)),
          _numField('التكلفة المتغيرة للوحدة', _variableCostPerUnit, 'ر.س',
              (v) => setState(() => _variableCostPerUnit = v)),
          _numField('التكاليف الثابتة الشهرية', _fixedCostsMonthly, 'ر.س',
              (v) => setState(() => _fixedCostsMonthly = v)),
          const Divider(),
          _numField('الوحدات المتوقّعة شهرياً', _expectedUnitsMonthly, 'وحدة',
              (v) => setState(() => _expectedUnitsMonthly = v)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'التكاليف المتغيرة تنمو مع الوحدات، والثابتة لا تتغير (إيجار، رواتب، تأمين).',
                    style: TextStyle(fontSize: 10, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, double value, String unit, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value.toStringAsFixed(0)),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
            decoration: InputDecoration(
              suffixText: ' $unit',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
            ),
            onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final profitable = _expectedUnitsMonthly > _breakEvenUnits;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.teal.shade700, Colors.teal.shade500]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _resultCard('نقطة التعادل (وحدات)', _fmt(_breakEvenUnits), 'وحدة/شهر', Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _resultCard('نقطة التعادل (إيرادات)', _fmtM(_breakEvenRevenue), 'ر.س/شهر', const Color(0xFFFFD700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _resultCard('هامش المساهمة', _fmt(_contributionMargin), 'ر.س/وحدة', Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _resultCard('% هامش المساهمة', '${_contributionMarginPct.toStringAsFixed(1)}%', '', Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: profitable ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: profitable ? Colors.green.shade300 : Colors.red.shade300, width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(profitable ? Icons.check_circle : Icons.error,
                      color: profitable ? Colors.green : Colors.red, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profitable ? 'المشروع مربح عند الحجم المتوقع' : '⚠️ المشروع دون نقطة التعادل',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: profitable ? Colors.green.shade700 : Colors.red.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _kpi('الربح المتوقّع', _fmt(_expectedProfit), profitable ? Colors.green : Colors.red)),
                  Expanded(child: _kpi('هامش الأمان', '${_marginOfSafety.toStringAsFixed(1)}%', Colors.teal)),
                  Expanded(
                    child: _kpi(
                      'فوق التعادل',
                      _fmt(_expectedUnitsMonthly - _breakEvenUnits) + ' وحدة',
                      profitable ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildChart() {
    final maxUnits = (_breakEvenUnits * 2.5).clamp(100, 10000).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المخطط البياني (Break-Even Chart)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BreakEvenPainter(
                breakEvenUnits: _breakEvenUnits.toInt(),
                fixedCosts: _fixedCostsMonthly,
                pricePerUnit: _pricePerUnit,
                variableCostPerUnit: _variableCostPerUnit,
                expectedUnits: _expectedUnitsMonthly.toInt(),
                maxUnits: maxUnits,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            children: [
              _legend('إيرادات', Colors.green),
              _legend('إجمالي التكاليف', Colors.red),
              _legend('تكاليف ثابتة', Colors.orange),
              _legend('نقطة التعادل', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 4, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildPerProduct() {
    final products = <_Product>[
      _Product('خدمة التدقيق', 45000, 18000, 95, 95),
      _Product('خدمة استشارات ضريبية', 28000, 11500, 58, 42),
      _Product('تراخيص SAP', 185000, 82000, 55, 18),
      _Product('دورات تدريبية', 4500, 1200, 162, 240),
      _Product('خدمات استشارية', 62000, 28000, 78, 58),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تحليل التعادل حسب المنتج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('المنتج / الخدمة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('السعر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('متغيرة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('هامش المساهمة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('نقطة التعادل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('المبيعات الفعلية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          for (final p in products) _productRow(p),
        ],
      ),
    );
  }

  Widget _productRow(_Product p) {
    final margin = p.price - p.cost;
    final profitable = p.actualUnits > p.breakEvenUnits;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text(_fmt(p.price.toDouble()), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(_fmt(p.cost.toDouble()), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.orange))),
          Expanded(
            child: Text(_fmt(margin.toDouble()),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFD4AF37), fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text('${p.breakEvenUnits} وحدة', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text('${p.actualUnits} وحدة', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (profitable ? Colors.green : Colors.red).withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                profitable ? '✓ مربح' : '× خسارة',
                style: TextStyle(
                  fontSize: 10,
                  color: profitable ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _BreakEvenPainter extends CustomPainter {
  final int breakEvenUnits;
  final double fixedCosts;
  final double pricePerUnit;
  final double variableCostPerUnit;
  final int expectedUnits;
  final int maxUnits;

  _BreakEvenPainter({
    required this.breakEvenUnits,
    required this.fixedCosts,
    required this.pricePerUnit,
    required this.variableCostPerUnit,
    required this.expectedUnits,
    required this.maxUnits,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRevenue = maxUnits * pricePerUnit;

    double xFor(int units) => units / maxUnits * size.width;
    double yFor(double money) => size.height - (money / maxRevenue * size.height);

    // Axes
    final axis = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axis);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axis);

    // Fixed costs (horizontal line)
    final fcPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, yFor(fixedCosts)), Offset(size.width, yFor(fixedCosts)), fcPaint);

    // Total costs (diagonal from fixedCosts)
    final tcPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(0, yFor(fixedCosts)),
      Offset(size.width, yFor(fixedCosts + maxUnits * variableCostPerUnit)),
      tcPaint,
    );

    // Revenue line
    final revPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, yFor(0)), Offset(size.width, yFor(maxRevenue)), revPaint);

    // Break-even marker
    final beXY = Offset(xFor(breakEvenUnits), yFor(breakEvenUnits * pricePerUnit));
    final bePaint = Paint()..color = Colors.blue;
    canvas.drawCircle(beXY, 7, bePaint);
    canvas.drawLine(beXY, Offset(beXY.dx, size.height),
        Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..strokeWidth = 1.5);

    // Expected units marker
    final expXY = Offset(xFor(expectedUnits), yFor(expectedUnits * pricePerUnit));
    final expPaint = Paint()..color = const Color(0xFFD4AF37);
    canvas.drawCircle(expXY, 7, expPaint);
  }

  @override
  bool shouldRepaint(covariant _BreakEvenPainter oldDelegate) => true;
}

class _Product {
  final String name;
  final int price;
  final int cost;
  final int breakEvenUnits;
  final int actualUnits;
  const _Product(this.name, this.price, this.cost, this.breakEvenUnits, this.actualUnits);
}
