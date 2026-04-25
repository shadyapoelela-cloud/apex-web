/// APEX — Investment Portfolio v2
/// /analytics/investment-portfolio-v2 — securities, stakes, real estate
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme.dart';

class InvestmentPortfolioV2Screen extends StatefulWidget {
  const InvestmentPortfolioV2Screen({super.key});
  @override
  State<InvestmentPortfolioV2Screen> createState() =>
      _InvestmentPortfolioV2ScreenState();
}

class _InvestmentPortfolioV2ScreenState
    extends State<InvestmentPortfolioV2Screen> {
  final List<Map<String, dynamic>> _holdings = [
    {'name': 'أسهم تداول السعودية', 'category': 'equity', 'cost': 250000.0, 'fair_value': 287500.0, 'icon': Icons.show_chart, 'color': 0xFF4CAF50},
    {'name': 'صناديق مرابحة', 'category': 'fund', 'cost': 500000.0, 'fair_value': 537500.0, 'icon': Icons.account_balance_wallet, 'color': 0xFF2196F3},
    {'name': 'سندات حكومية SAR', 'category': 'bond', 'cost': 750000.0, 'fair_value': 762500.0, 'icon': Icons.receipt_long, 'color': 0xFF9C27B0},
    {'name': 'عقار تجاري — الرياض', 'category': 'real_estate', 'cost': 2000000.0, 'fair_value': 2400000.0, 'icon': Icons.business, 'color': 0xFFFF9800},
    {'name': 'حصة في شركة زميلة', 'category': 'associate', 'cost': 800000.0, 'fair_value': 950000.0, 'icon': Icons.handshake, 'color': 0xFFE91E63},
  ];

  double get _totalCost => _holdings.fold<double>(0, (a, h) => a + (h['cost'] as double));
  double get _totalFairValue => _holdings.fold<double>(0, (a, h) => a + (h['fair_value'] as double));
  double get _unrealizedGain => _totalFairValue - _totalCost;
  double get _gainPct => _totalCost == 0 ? 0 : _unrealizedGain / _totalCost * 100;

  String _categoryAr(String c) => switch (c) {
        'equity' => 'أسهم',
        'fund' => 'صناديق',
        'bond' => 'سندات',
        'real_estate' => 'عقارات',
        'associate' => 'حصص',
        _ => c,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('المحفظة الاستثمارية', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _allocationCard(),
          const SizedBox(height: 12),
          _holdingsCard(),
        ]),
      ),
    );
  }

  Widget _heroCard() {
    final positive = _unrealizedGain >= 0;
    final color = positive ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('القيمة العادلة الإجمالية',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(height: 6),
        Text('${_totalFairValue.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: AC.gold,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
        const SizedBox(height: 8),
        Row(children: [
          Icon(positive ? Icons.trending_up : Icons.trending_down, color: color, size: 18),
          const SizedBox(width: 6),
          Text('${positive ? "+" : ""}${_unrealizedGain.toStringAsFixed(0)} SAR (${_gainPct.toStringAsFixed(2)}%)',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 6),
        Text('التكلفة: ${_totalCost.toStringAsFixed(0)} SAR',
            style: TextStyle(color: AC.ts, fontSize: 11)),
      ]),
    );
  }

  Widget _allocationCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('التوزيع',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _DonutPainter(_holdings),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${(_totalFairValue / 1000000).toStringAsFixed(2)}M',
                        style: TextStyle(color: AC.gold, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('SAR', style: TextStyle(color: AC.ts, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: _holdings.map((h) {
              final pct = (h['fair_value'] as double) / _totalFairValue * 100;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: Color(h['color'] as int),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('${_categoryAr(h['category'] as String)} ${pct.toStringAsFixed(1)}%',
                    style: TextStyle(color: AC.tp, fontSize: 11)),
              ]);
            }).toList(),
          ),
        ]),
      );

  Widget _holdingsCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.account_balance, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('الحيازات (${_holdings.length})',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
          ..._holdings.map((h) {
            final cost = h['cost'] as double;
            final fv = h['fair_value'] as double;
            final gain = fv - cost;
            final pct = cost == 0 ? 0 : gain / cost * 100;
            final positive = gain >= 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(h['color'] as int).withValues(alpha: 0.20),
                  child: Icon(h['icon'] as IconData, color: Color(h['color'] as int), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${h['name']}',
                        style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text('${_categoryAr(h['category'] as String)} · تكلفة ${cost.toStringAsFixed(0)}',
                        style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fv.toStringAsFixed(0),
                      style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('${positive ? "+" : ""}${pct.toStringAsFixed(1)}%',
                      style: TextStyle(color: positive ? AC.ok : AC.err, fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                ]),
              ]),
            );
          }),
        ]),
      );
}

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> holdings;
  _DonutPainter(this.holdings);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final total = holdings.fold<double>(0, (a, h) => a + (h['fair_value'] as double));
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final h in holdings) {
      final value = h['fair_value'] as double;
      final sweep = (value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = Color(h['color'] as int)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - 0.02,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
