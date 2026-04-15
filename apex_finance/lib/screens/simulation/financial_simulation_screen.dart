import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class FinancialSimulationScreen extends StatefulWidget {
  final String uploadId;
  final String clientId;
  final String clientName;

  const FinancialSimulationScreen({
    super.key,
    required this.uploadId,
    this.clientId = '',
    this.clientName = '',
  });

  @override
  State<FinancialSimulationScreen> createState() => _FinancialSimulationScreenState();
}

class _FinancialSimulationScreenState extends State<FinancialSimulationScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _data = {};
  late AnimationController _animCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _scoreAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final res = await ApiService.getFinancialSimulation(widget.uploadId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = res.success ? (res.data as Map<String, dynamic>? ?? {}) : {};
    });
    _animCtrl.forward();
  }

  double get _score => (_data['readiness_score'] ?? 0).toDouble();

  Color _scoreColor(double s) => s >= 80 ? AC.ok : s >= 60 ? AC.warn : AC.err;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('محاكاة مالية', style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700, fontSize: 18)),
            if (widget.clientName.isNotEmpty) Text(widget.clientName, style: TextStyle(color: AC.ts, fontSize: 12)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(height: 2, color: AC.gold.withValues(alpha: 0.3))),
          iconTheme: IconThemeData(color: AC.tp),
          actions: [
            IconButton(icon: Icon(Icons.refresh_rounded, color: AC.gold), onPressed: () { setState(() => _loading = true); _animCtrl.reset(); _load(); }),
          ],
        ),
        body: _loading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: List.generate(4, (_) => apexShimmerCard(height: 90))),
  );

  Widget _buildContent() {
    final bs = _data['balance_sheet'] as Map<String, dynamic>? ?? {};
    final is_ = _data['income_statement'] as Map<String, dynamic>? ?? {};
    final cf = _data['cash_flow_indicators'] as Map<String, dynamic>? ?? {};
    final gaps = (_data['structural_gaps'] as List? ?? []).cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ApexStaggeredList(children: [
        _buildScoreHero(),
        const SizedBox(height: 8),
        apexSectionHeader('جاهزية القوائم المالية', subtitle: 'تحليل هيكل شجرة الحسابات'),
        _buildStatementCard('الميزانية العمومية', Icons.account_balance_rounded, AC.info, [
          _checkRow('الأصول', bs['total_assets']?['found'] ?? false, '${bs['total_assets']?['count'] ?? 0} حساب'),
          _checkRow('الالتزامات', bs['total_liabilities']?['found'] ?? false, '${bs['total_liabilities']?['count'] ?? 0} حساب'),
          _checkRow('حقوق الملكية', bs['total_equity']?['found'] ?? false, '${bs['total_equity']?['count'] ?? 0} حساب'),
          _checkRow('معادلة التوازن', bs['equation_valid'] ?? false, null),
        ]),
        _buildStatementCard('قائمة الدخل', Icons.trending_up_rounded, AC.ok, [
          _checkRow('الإيرادات', is_['has_revenue'] ?? false, null),
          _checkRow('تكلفة المبيعات', is_['has_cogs'] ?? false, null),
          _checkRow('مجمل الربح', is_['has_gross_profit'] ?? false, null),
          _checkRow('المصاريف التشغيلية', is_['has_operating_expenses'] ?? false, null),
          _checkRow('تكاليف التمويل', is_['has_finance_costs'] ?? false, null),
        ]),
        _buildStatementCard('مؤشرات التدفق النقدي', Icons.water_drop_rounded, AC.purple, [
          _checkRow('حسابات نقدية', cf['has_cash_accounts'] ?? false, null),
          _checkRow('الإهلاك', cf['has_depreciation'] ?? false, null),
          _checkRow('رأس المال العامل', cf['has_working_capital'] ?? false, null),
        ]),
        if (gaps.isNotEmpty) ...[
          const SizedBox(height: 8),
          apexSectionHeader('الثغرات الهيكلية', subtitle: '${gaps.length} ثغرة مكتشفة', trailing: apexPill('${gaps.length}', color: AC.err)),
          ...gaps.map((g) => _buildGapCard(g)),
        ],
      ]),
    );
  }

  Widget _buildScoreHero() {
    return ApexFadeIn(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [_scoreColor(_score).withValues(alpha: 0.08), AC.navy2],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          boxShadow: [BoxShadow(color: _scoreColor(_score).withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          SizedBox(
            width: 120, height: 120,
            child: AnimatedBuilder(
              animation: _scoreAnim,
              builder: (_, __) => CustomPaint(
                painter: _ScoreRingPainter(
                  score: _score * _scoreAnim.value,
                  color: _scoreColor(_score),
                  bgColor: AC.navy3,
                ),
                child: Center(child: Text(
                  '${(_score * _scoreAnim.value).toInt()}',
                  style: TextStyle(color: _scoreColor(_score), fontSize: 36, fontWeight: FontWeight.w900),
                )),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('درجة الجاهزية', style: TextStyle(color: AC.tp, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(_readinessLabel(_score), style: TextStyle(color: _scoreColor(_score), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('تقييم مبني على هيكل شجرة الحسابات', style: TextStyle(color: AC.td, fontSize: 12)),
          ])),
        ]),
      ),
    );
  }

  String _readinessLabel(double s) => s >= 80 ? 'جاهز للإنتاج' : s >= 60 ? 'يحتاج تحسينات' : 'غير جاهز — يتطلب إصلاحات';

  Widget _buildStatementCard(String title, IconData icon, Color color, List<Widget> checks) {
    return apexSoftCard(
      title: title,
      accent: color,
      children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        ...checks,
      ],
    );
  }

  Widget _checkRow(String label, bool found, String? detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: (found ? AC.ok : AC.err).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(found ? Icons.check_rounded : Icons.close_rounded, size: 14, color: found ? AC.ok : AC.err),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: AC.tp, fontSize: 13))),
        if (detail != null) Text(detail, style: TextStyle(color: AC.td, fontSize: 11)),
      ]),
    );
  }

  Widget _buildGapCard(Map<String, dynamic> gap) {
    final severity = (gap['severity'] ?? '').toString();
    final ApexTint tint;
    switch (severity) {
      case 'Critical': tint = ApexTint.red;
      case 'High': tint = ApexTint.amber;
      case 'Medium': tint = ApexTint.blue;
      default: tint = ApexTint.blue;
    }
    return apexTintedCard(
      tint: tint,
      children: [
        Row(children: [
          apexSeverityBadge(severity == 'Critical' ? 'critical' : severity == 'High' ? 'review' : 'info', label: severity),
          const SizedBox(width: 10),
          Expanded(child: Text(gap['message_ar'] ?? gap['gap'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, height: 1.5))),
        ]),
        if (gap['fix'] != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lightbulb_rounded, size: 14, color: AC.warn),
            const SizedBox(width: 6),
            Expanded(child: Text(gap['fix'], style: TextStyle(color: AC.ts, fontSize: 12, fontStyle: FontStyle.italic))),
          ]),
        ],
      ],
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double score;
  final Color color;
  final Color bgColor;

  _ScoreRingPainter({required this.score, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 10.0;

    final bgPaint = Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    final sweepAngle = (score / 100) * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) => old.score != score;
}
