/// APEX — Health Score v2 (radial chart + 6 dimensions)
/// /analytics/health-score-v2 — Saudi-aware company health KPI
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme.dart';

class HealthScoreV2Screen extends StatefulWidget {
  const HealthScoreV2Screen({super.key});
  @override
  State<HealthScoreV2Screen> createState() => _HealthScoreV2ScreenState();
}

class _HealthScoreV2ScreenState extends State<HealthScoreV2Screen> {
  // Demo scores 0-100
  final List<Map<String, dynamic>> _dimensions = [
    {'name': 'السيولة', 'score': 82.0, 'icon': Icons.water_drop, 'narrative': 'CR 2.1 — صحي'},
    {'name': 'الربحية', 'score': 75.0, 'icon': Icons.trending_up, 'narrative': 'هامش صافي 18%'},
    {'name': 'الكفاءة', 'score': 68.0, 'icon': Icons.speed, 'narrative': 'دوران AR 45 يوماً'},
    {'name': 'الرافعة', 'score': 88.0, 'icon': Icons.balance, 'narrative': 'D/E 0.4 — منخفض'},
    {'name': 'النمو', 'score': 92.0, 'icon': Icons.rocket_launch, 'narrative': '+22% YoY'},
    {'name': 'الامتثال', 'score': 95.0, 'icon': Icons.verified, 'narrative': 'ZATCA + VAT متوافق'},
  ];

  double get _composite =>
      _dimensions.fold<double>(0, (a, d) => a + (d['score'] as double)) / _dimensions.length;

  String get _grade {
    if (_composite >= 85) return 'A';
    if (_composite >= 70) return 'B';
    if (_composite >= 55) return 'C';
    if (_composite >= 40) return 'D';
    return 'F';
  }

  Color get _gradeColor {
    if (_composite >= 85) return AC.ok;
    if (_composite >= 70) return AC.gold;
    if (_composite >= 55) return AC.warn;
    return AC.err;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('Health Score', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _dimensionsGrid(),
          const SizedBox(height: 12),
          _aiCommentaryCard(),
        ]),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [_gradeColor.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: _gradeColor.withValues(alpha: 0.5), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _RadialGaugePainter(_composite, _gradeColor),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_composite.toStringAsFixed(0),
                      style: TextStyle(
                          color: _gradeColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace')),
                  Text('من 100',
                      style: TextStyle(color: AC.ts, fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('التقييم العام',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            Text(_grade,
                style: TextStyle(
                    color: _gradeColor,
                    fontSize: 56,
                    fontWeight: FontWeight.w900)),
            Text(_composite >= 85 ? 'صحة ممتازة'
                : _composite >= 70 ? 'صحة جيدة'
                : _composite >= 55 ? 'تحتاج مراجعة'
                : 'تحتاج تدخّل',
                style: TextStyle(color: _gradeColor, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _dimensionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.0,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: _dimensions.map((d) {
        final score = d['score'] as double;
        final color = score >= 85 ? AC.ok : score >= 70 ? AC.gold : score >= 55 ? AC.warn : AC.err;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(d['icon'] as IconData, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(d['name'] as String,
                    style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(score.toStringAsFixed(0),
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(d['narrative'] as String,
                style: TextStyle(color: AC.ts, fontSize: 10)),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: AC.navy3,
                color: color,
                minHeight: 4,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _aiCommentaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.18), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.psychology, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text('تعليق الذكاء الاصطناعي',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(
          'صحة كيانك ${_composite.toStringAsFixed(0)}/100 — تقييم ${_grade}. '
          'النمو والامتثال نقاط قوة (+22% YoY و95/100). '
          'الكفاءة (68) أقل البنود — راجع متوسط دوران AR. '
          'فكّر في تطبيق طلب دفعة مقدمة 30% للعملاء الكبار.',
          style: TextStyle(color: AC.tp, fontSize: 13, height: 1.7),
        ),
      ]),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double value; // 0-100
  final Color color;
  _RadialGaugePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // Background ring
    final bg = Paint()
      ..color = AC.navy3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);

    // Foreground arc
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final sweep = (value / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RadialGaugePainter old) =>
      old.value != value || old.color != color;
}
