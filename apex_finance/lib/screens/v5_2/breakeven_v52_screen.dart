/// V5.2 — Break-Even Analysis Calculator.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class BreakEvenV52Screen extends StatefulWidget {
  const BreakEvenV52Screen({super.key});

  @override
  State<BreakEvenV52Screen> createState() => _BreakEvenV52ScreenState();
}

class _BreakEvenV52ScreenState extends State<BreakEvenV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  // Inputs
  double _fixedCosts = 1800000;
  double _pricePerUnit = 450;
  double _variableCostPerUnit = 280;
  double _targetProfit = 600000;
  String _mode = 'units'; // units | revenue | multi

  double get _contributionMargin => _pricePerUnit - _variableCostPerUnit;
  double get _contributionMarginRatio => _pricePerUnit > 0 ? _contributionMargin / _pricePerUnit : 0;
  double get _breakEvenUnits => _contributionMargin > 0 ? _fixedCosts / _contributionMargin : 0;
  double get _breakEvenRevenue => _contributionMarginRatio > 0 ? _fixedCosts / _contributionMarginRatio : 0;
  double get _targetUnits => _contributionMargin > 0 ? (_fixedCosts + _targetProfit) / _contributionMargin : 0;
  double get _targetRevenue => _contributionMarginRatio > 0 ? (_fixedCosts + _targetProfit) / _contributionMarginRatio : 0;
  double get _marginOfSafety => _targetUnits > _breakEvenUnits ? ((_targetUnits - _breakEvenUnits) / _targetUnits * 100) : 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(children: [
          _header(),
          _modeSelector(),
          Expanded(child: Row(children: [
            SizedBox(width: 380, child: _inputs()),
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
        Icon(Icons.balance, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('نقطة التعادل — Break-Even Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('حاسبة تفاعلية — أدخل البيانات وشاهد النقطة فوراً', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.bookmark_border, size: 16), label: Text('حفظ الحساب')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.download, size: 16), label: Text('تصدير PDF')),
      ]),
    );
  }

  Widget _modeSelector() {
    final modes = [
      ('units', 'منتج واحد', Icons.inventory_2, core_theme.AC.info),
      ('multi', 'متعدد المنتجات', Icons.category, core_theme.AC.purple),
      ('revenue', 'بناءً على الإيراد', Icons.trending_up, core_theme.AC.ok),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: modes.map((m) {
        final selected = m.$1 == _mode;
        return Padding(padding: const EdgeInsets.only(left: 8), child: InkWell(
          onTap: () => setState(() => _mode = m.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: selected ? m.$4.withOpacity(0.12) : core_theme.AC.navy3, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? m.$4 : core_theme.AC.bdr)),
            child: Row(children: [
              Icon(m.$3, size: 14, color: selected ? m.$4 : core_theme.AC.ts),
              const SizedBox(width: 6),
              Text(m.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? m.$4 : core_theme.AC.tp)),
            ]),
          ),
        ));
      }).toList()),
    );
  }

  Widget _inputs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: ListView(children: [
        Text('📝 المدخلات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        _card('التكاليف الثابتة', 'Fixed Costs', Icons.account_balance, core_theme.AC.warn, Column(children: [
          _numberField('إجمالي التكاليف الثابتة السنوية', _fixedCosts, 'ر.س', (v) => setState(() => _fixedCosts = v)),
          const SizedBox(height: 6),
          Text('تشمل: الإيجار، الرواتب الأساسية، الإهلاك، التأمين', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ])),
        const SizedBox(height: 14),
        _card('السعر والتكلفة المتغيّرة', 'Unit Economics', Icons.attach_money, _gold, Column(children: [
          _numberField('سعر البيع للوحدة', _pricePerUnit, 'ر.س', (v) => setState(() => _pricePerUnit = v)),
          const SizedBox(height: 10),
          _numberField('التكلفة المتغيّرة للوحدة', _variableCostPerUnit, 'ر.س', (v) => setState(() => _variableCostPerUnit = v)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: core_theme.AC.ok.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.calculate, size: 14, color: core_theme.AC.ok), const SizedBox(width: 6), Text('هامش المساهمة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ok)), const Spacer(), Text('${_contributionMargin.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.ok))]),
            const SizedBox(height: 4),
            Row(children: [Text('النسبة (CMR)', style: TextStyle(fontSize: 10, color: core_theme.AC.ok.withOpacity(0.8))), const Spacer(), Text('${(_contributionMarginRatio * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.ok))]),
          ])),
        ])),
        const SizedBox(height: 14),
        _card('الربح المستهدَف (اختياري)', 'Target Profit', Icons.flag, core_theme.AC.info, Column(children: [
          _numberField('الربح الذي تريده بعد التعادل', _targetProfit, 'ر.س', (v) => setState(() => _targetProfit = v)),
        ])),
      ]),
    );
  }

  Widget _card(String title, String subtitle, IconData icon, Color color, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Icon(icon, color: color, size: 14)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
          ]),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _numberField(String label, double value, String unit, ValueChanged<double> onChanged) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
      const SizedBox(width: 8),
      SizedBox(
        width: 120,
        child: TextField(
          controller: TextEditingController(text: value.toStringAsFixed(0))..selection = TextSelection.collapsed(offset: value.toStringAsFixed(0).length),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.end,
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) onChanged(parsed);
          },
          decoration: InputDecoration(
            suffixText: unit,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }

  Widget _results() {
    return Container(
      color: const Color(0xFFF6F6F5),
      padding: const EdgeInsets.all(16),
      child: ListView(children: [
        Text('📊 النتائج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),

        // Big result — Break-even point
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_gold.withOpacity(0.12), core_theme.AC.ok.withOpacity(0.08)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold, width: 2),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.flag, color: _gold, size: 32)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نقطة التعادل (Break-Even Point)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('${_breakEvenUnits.toStringAsFixed(0)}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _gold, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                Text('وحدة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
              ]),
              Text('= ${(_breakEvenRevenue / 1000).toStringAsFixed(0)}K ر.س إيراد', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: core_theme.AC.ts)),
            ])),
          ]),
        ),

        const SizedBox(height: 16),

        // Target profit section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: core_theme.AC.info.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.info.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.flag, color: core_theme.AC.info),
              SizedBox(width: 8),
              Text('للوصول إلى ربحك المستهدف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _smallStat('وحدات مطلوبة', '${_targetUnits.toStringAsFixed(0)}', 'وحدة', core_theme.AC.info)),
              const SizedBox(width: 10),
              Expanded(child: _smallStat('إيراد مطلوب', '${(_targetRevenue / 1000).toStringAsFixed(0)}K', 'ر.س', core_theme.AC.info)),
              const SizedBox(width: 10),
              Expanded(child: _smallStat('هامش الأمان', '${_marginOfSafety.toStringAsFixed(1)}', '%', _marginOfSafety >= 20 ? core_theme.AC.ok : core_theme.AC.warn)),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        // Chart-style visualization
        Text('📈 الرسم البياني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 10),
        _chart(),

        const SizedBox(height: 20),

        // Sensitivity analysis
        Text('🔬 تحليل الحساسية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 10),
        _sensitivity(),
      ]),
    );
  }

  Widget _chart() {
    // Simple visualization: Revenue line, Fixed Cost line, Total Cost line at 1.5x break-even units
    final maxUnits = (_breakEvenUnits * 1.5).ceil();
    return Container(
      height: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
      child: Column(children: [
        Row(children: [
          _chartLegend(core_theme.AC.info, 'الإيراد'),
          const SizedBox(width: 16),
          _chartLegend(core_theme.AC.err, 'التكاليف الكلّية'),
          const SizedBox(width: 16),
          _chartLegend(core_theme.AC.warn, 'التكاليف الثابتة'),
          const Spacer(),
          Text('الكمية المُباعة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ]),
        const SizedBox(height: 10),
        Expanded(child: CustomPaint(
          size: Size.infinite,
          painter: _BreakEvenPainter(
            fixedCosts: _fixedCosts,
            pricePerUnit: _pricePerUnit,
            variableCostPerUnit: _variableCostPerUnit,
            breakEvenUnits: _breakEvenUnits,
            maxUnits: maxUnits.toDouble(),
          ),
        )),
      ]),
    );
  }

  Widget _chartLegend(Color color, String label) {
    return Row(children: [
      Container(width: 16, height: 3, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _sensitivity() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(10), color: _navy, child: const Row(children: [
          Expanded(flex: 2, child: Text('السيناريو', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('نقطة التعادل', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          Expanded(child: Text('التأثير', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
        ])),
        ..._sensitivityRows(),
      ]),
    );
  }

  List<Widget> _sensitivityRows() {
    final base = _breakEvenUnits;
    final rows = [
      ('رفع السعر +10%', _calc(fixed: _fixedCosts, price: _pricePerUnit * 1.10, vc: _variableCostPerUnit)),
      ('خفض السعر -10%', _calc(fixed: _fixedCosts, price: _pricePerUnit * 0.90, vc: _variableCostPerUnit)),
      ('زيادة تكلفة متغيّرة +15%', _calc(fixed: _fixedCosts, price: _pricePerUnit, vc: _variableCostPerUnit * 1.15)),
      ('خفض تكاليف ثابتة -20%', _calc(fixed: _fixedCosts * 0.80, price: _pricePerUnit, vc: _variableCostPerUnit)),
      ('خفض تكلفة متغيّرة -10%', _calc(fixed: _fixedCosts, price: _pricePerUnit, vc: _variableCostPerUnit * 0.90)),
    ];
    return rows.map((r) {
      final change = r.$2 - base;
      final changePct = base != 0 ? (change / base * 100) : 0.0;
      final isFav = change < 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.bdr))),
        child: Row(children: [
          Expanded(flex: 2, child: Text(r.$1, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text('${r.$2.toStringAsFixed(0)} وحدة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace'), textAlign: TextAlign.end)),
          Expanded(child: Container(
            margin: const EdgeInsets.only(right: 60),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: (isFav ? core_theme.AC.ok : core_theme.AC.err).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isFav ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.center),
          )),
        ]),
      );
    }).toList();
  }

  double _calc({required double fixed, required double price, required double vc}) {
    final cm = price - vc;
    return cm > 0 ? fixed / cm : 0;
  }

  Widget _smallStat(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 2),
          Text(unit, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ]),
      ]),
    );
  }
}

class _BreakEvenPainter extends CustomPainter {
  final double fixedCosts, pricePerUnit, variableCostPerUnit, breakEvenUnits, maxUnits;
  _BreakEvenPainter({required this.fixedCosts, required this.pricePerUnit, required this.variableCostPerUnit, required this.breakEvenUnits, required this.maxUnits});

  @override
  void paint(Canvas canvas, Size size) {
    final maxRevenue = pricePerUnit * maxUnits;
    final yScale = size.height / maxRevenue;
    final xScale = size.width / maxUnits;

    // Revenue line (blue)
    final revPaint = Paint()..color = core_theme.AC.info..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - (maxUnits * xScale), size.height - (maxRevenue * yScale)), revPaint);

    // Total cost line (red)
    final tcPaint = Paint()..color = core_theme.AC.err..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final tcAtZero = fixedCosts;
    final tcAtMax = fixedCosts + (variableCostPerUnit * maxUnits);
    canvas.drawLine(Offset(size.width, size.height - (tcAtZero * yScale)), Offset(size.width - (maxUnits * xScale), size.height - (tcAtMax * yScale)), tcPaint);

    // Fixed cost line (orange, horizontal)
    final fcPaint = Paint()..color = core_theme.AC.warn..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width, size.height - (fixedCosts * yScale)), Offset(0, size.height - (fixedCosts * yScale)), fcPaint);

    // Break-even point marker (gold circle)
    final bep = Offset(size.width - (breakEvenUnits * xScale), size.height - ((pricePerUnit * breakEvenUnits) * yScale));
    canvas.drawCircle(bep, 8, Paint()..color = core_theme.AC.gold);
    canvas.drawCircle(bep, 8, Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke);

    // Axis lines
    final axisPaint = Paint()..color = core_theme.AC.td..strokeWidth = 1;
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
  }

  @override
  bool shouldRepaint(covariant _BreakEvenPainter old) => old.breakEvenUnits != breakEvenUnits || old.fixedCosts != fixedCosts || old.pricePerUnit != pricePerUnit || old.variableCostPerUnit != variableCostPerUnit;
}
