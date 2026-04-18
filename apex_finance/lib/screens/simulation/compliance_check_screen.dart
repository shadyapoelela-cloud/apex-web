import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class ComplianceCheckScreen extends StatefulWidget {
  final String uploadId;
  final String clientId;
  final String clientName;

  const ComplianceCheckScreen({
    super.key,
    required this.uploadId,
    this.clientId = '',
    this.clientName = '',
  });

  @override
  State<ComplianceCheckScreen> createState() => _ComplianceCheckScreenState();
}

class _ComplianceCheckScreenState extends State<ComplianceCheckScreen> with SingleTickerProviderStateMixin {
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
    final res = await ApiService.getComplianceCheck(widget.uploadId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = res.success ? (res.data as Map<String, dynamic>? ?? {}) : {};
    });
    _animCtrl.forward();
  }

  double get _score => (_data['compliance_score'] ?? 0).toDouble();
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
            Text('فحص الامتثال', style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700, fontSize: 18)),
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
    final passed = (_data['passed'] as List? ?? []).cast<Map<String, dynamic>>();
    final failed = (_data['failed'] as List? ?? []).cast<Map<String, dynamic>>();
    final warnings = (_data['warnings'] as List? ?? []).cast<Map<String, dynamic>>();
    final authorities = _data['authorities'] as Map<String, dynamic>? ?? {};
    final totalRules = _data['total_rules'] ?? (passed.length + failed.length);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ApexStaggeredList(children: [
        _buildScoreHero(totalRules),
        const SizedBox(height: 12),
        _buildAuthorityRow(authorities),
        const SizedBox(height: 8),
        if (warnings.isNotEmpty) ...[
          apexSectionHeader('تحذيرات', subtitle: '${warnings.length} تحذير', trailing: apexPill('${warnings.length}', color: AC.warn)),
          ...warnings.map((w) => _buildRuleCard(w, ApexTint.amber)),
          const SizedBox(height: 8),
        ],
        if (failed.isNotEmpty) ...[
          apexSectionHeader('قواعد غير مستوفاة', subtitle: '${failed.length} قاعدة', trailing: apexPill('${failed.length}', color: AC.err)),
          ...failed.map((f) => _buildRuleCard(f, ApexTint.red)),
          const SizedBox(height: 8),
        ],
        if (passed.isNotEmpty) ...[
          apexSectionHeader('قواعد مستوفاة', subtitle: '${passed.length} قاعدة', trailing: apexPill('${passed.length}', color: AC.ok)),
          ...passed.map((p) => _buildRuleCard(p, ApexTint.green)),
        ],
      ]),
    );
  }

  Widget _buildScoreHero(int totalRules) {
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
                painter: _ScoreRingPainter(score: _score * _scoreAnim.value, color: _scoreColor(_score), bgColor: AC.navy3),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(_score * _scoreAnim.value).toInt()}%', style: TextStyle(color: _scoreColor(_score), fontSize: 30, fontWeight: FontWeight.w900)),
                  Text('امتثال', style: TextStyle(color: AC.td, fontSize: 10)),
                ])),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('نتيجة الامتثال التنظيمي', style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$totalRules قاعدة تنظيمية تم فحصها', style: TextStyle(color: AC.ts, fontSize: 13)),
            const SizedBox(height: 4),
            Text('ZATCA • SAMA • SOCPA • IFRS', style: TextStyle(color: AC.td, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildAuthorityRow(Map<String, dynamic> authorities) {
    if (authorities.isEmpty) return const SizedBox.shrink();
    return apexSoftCard(
      title: 'الجهات التنظيمية',
      children: [
        Wrap(spacing: 10, runSpacing: 8, children: authorities.entries.map((e) {
          final auth = e.value as Map<String, dynamic>? ?? {};
          final p = auth['passed'] ?? 0;
          final f = auth['failed'] ?? 0;
          final allPassed = f == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (allPassed ? AC.ok : AC.warn).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (allPassed ? AC.ok : AC.warn).withValues(alpha: 0.20)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(e.key, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, size: 12, color: AC.ok),
                const SizedBox(width: 3),
                Text('$p', style: TextStyle(color: AC.ok, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (f > 0) ...[
                  Icon(Icons.cancel_rounded, size: 12, color: AC.err),
                  const SizedBox(width: 3),
                  Text('$f', style: TextStyle(color: AC.err, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ]),
            ]),
          );
        }).toList()),
      ],
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule, ApexTint tint) {
    final severity = (rule['severity'] ?? 'Medium').toString();
    return apexTintedCard(
      tint: tint,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: (rule['passed'] == true ? AC.ok : AC.err).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              rule['passed'] == true ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: rule['passed'] == true ? AC.ok : AC.err,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              apexPill(rule['authority'] ?? '', color: AC.info),
              const SizedBox(width: 8),
              apexSeverityBadge(severity == 'Critical' ? 'critical' : severity == 'High' ? 'review' : 'info', label: severity),
            ]),
            const SizedBox(height: 8),
            Text(rule['requirement_ar'] ?? rule['id'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, height: 1.5)),
            if (rule['ref'] != null) ...[
              const SizedBox(height: 4),
              Text('المرجع: ${rule['ref']}', style: TextStyle(color: AC.td, fontSize: 11)),
            ],
          ])),
        ]),
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
    canvas.drawCircle(center, radius, Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, (score / 100) * 2 * math.pi, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) => old.score != score;
}
