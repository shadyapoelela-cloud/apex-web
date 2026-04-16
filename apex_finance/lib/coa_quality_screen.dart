import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';

// ─────────────────────────────────────────────
// COA Quality Dashboard — World-Class Redesign v4.3
// Full results: Executive Summary, 5 Tabs, Knowledge Graph, Recommendations
// ─────────────────────────────────────────────

class CoaQualityScreen extends StatefulWidget {
  final String uploadId, clientId, clientName;
  final Map<String, dynamic> assessData;
  const CoaQualityScreen({super.key, required this.uploadId, required this.clientId, required this.clientName, required this.assessData});
  @override State<CoaQualityScreen> createState() => _CoaQualityScreenState();
}

class _CoaQualityScreenState extends State<CoaQualityScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _progress;
  int _tabIndex = 0;

  // ── Colors ──
  static Color get _bg => AC.navy;
  static Color get _surface1 => AC.navy2;
  static Color get _surface2 => AC.navy3;
  static Color get _gold => AC.gold;
  static Color get _textPri => AC.tp;
  static Color get _textSec => AC.ts;
  static Color get _border => AC.bdr;
  static Color get _positive => AC.ok;
  static Color get _danger => AC.err;
  static Color get _warning => AC.warn;
  static Color get _cyan => AC.cyan;
  // ignore: unused_field
  static Color get _info => AC.info;
  static Color get _purple => AC.purple;

  // ── Data accessors ──
  Map<String, dynamic> get _d => widget.assessData;
  double get _overall => ((_d['overall_score'] ?? 0.0) as num).toDouble();
  double _score(String key) => ((_d[key] ?? 0.0) as num).toDouble();
  int get _totalAccounts => (_d['total_accounts'] ?? 0) as int;

  String get _grade {
    final s = _overall * 100;
    if (s >= 90) return 'A';
    if (s >= 80) return 'A-';
    if (s >= 75) return 'B+';
    if (s >= 65) return 'B';
    if (s >= 50) return 'C';
    return 'D';
  }

  String get _gradeLabel {
    if (_overall >= 0.75) return 'جودة مرتفعة — جاهز للتحليل';
    if (_overall >= 0.50) return 'جودة متوسطة — يُنصح بالمراجعة';
    return 'جودة منخفضة — مراجعة مطلوبة';
  }

  Color _scoreColor(double v) {
    if (v >= 0.75) return _positive;
    if (v >= 0.50) return _warning;
    return _danger;
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _progress = Tween<double>(begin: 0, end: _overall).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () => _anim.forward());
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final recs = (_d['recommendations'] as List? ?? []).cast<String>();
    final reviewCount = (_d['accounts_needing_review'] ?? _d['review_count'] ?? 0) as int;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            const SizedBox(height: 12),
            _buildStepper(),
            const SizedBox(height: 16),
            _buildExecSummary(),
            const SizedBox(height: 12),
            _buildHeadlineCard(),
            const SizedBox(height: 12),
            _buildStatsStrip(),
            const SizedBox(height: 8),
            _buildSessionHealth(),
            const SizedBox(height: 12),
            _buildSectorCard(),
            _buildSectorComparison(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 12),
            _buildTabContent(),
            const SizedBox(height: 16),
            _buildKnowledgeGraph(),
            const SizedBox(height: 16),
            _buildReviewQueuePreview(),
            const SizedBox(height: 16),
            if (recs.isNotEmpty) _buildRecommendations(recs),
            const SizedBox(height: 16),
            _buildShareBar(),
            const SizedBox(height: 16),
            _buildSimulationCards(),
            const SizedBox(height: 90),
          ]),
        )),
        _buildFooterCTA(reviewCount),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _surface1, elevation: 0,
    leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 20), color: _textSec, onPressed: () => context.pop()),
    title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('تحليل شجرة الحسابات', style: TextStyle(fontFamily: 'Tajawal', color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
      Text(widget.clientName, style: TextStyle(fontFamily: 'Tajawal', color: _textSec, fontSize: 12)),
    ]),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold.withValues(alpha: 0.15))),
        child: Text('v4.3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _gold)),
      ),
    ],
    bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: _border, height: 1)),
  );

  // ── Stepper ──
  Widget _buildStepper() {
    final steps = ['رفع وتحليل', 'المراجعة', 'الاعتماد'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = i ~/ 2 < 1;
          return Expanded(child: Container(
            height: 2, margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: done ? LinearGradient(colors: [_positive, _cyan]) : null,
              color: done ? null : _border,
            ),
          ));
        }
        final idx = i ~/ 2;
        final done = idx < 1; // step 0 done
        final active = idx == 1; // step 1 active
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _positive.withValues(alpha: 0.12) : active ? _gold.withValues(alpha: 0.12) : _surface1,
              border: Border.all(color: done ? _positive : active ? _gold : _border, width: 2),
            ),
            child: Center(child: done
              ? Icon(Icons.check_rounded, size: 14, color: _positive)
              : Text('${idx + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? _gold : _textSec))),
          ),
          const SizedBox(height: 5),
          Text(steps[idx], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: done ? _positive : active ? _gold : _textSec, fontFamily: 'Tajawal')),
        ]);
      })),
    );
  }

  // ═══════════════════════════════════════════
  // EXECUTIVE SUMMARY
  // ═══════════════════════════════════════════
  Widget _buildExecSummary() {
    final color = _scoreColor(_overall);
    final erp = _d['erp_system'] as String? ?? '';
    final pattern = _d['file_pattern'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_surface2, _surface1]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.12)),
      ),
      child: Column(children: [
        Row(children: [
          // Info (right side in RTL)
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('درجة جودة شجرة الحسابات', style: TextStyle(fontSize: 11, color: _textSec, fontFamily: 'Tajawal')),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _progress,
              builder: (_, __) => Text(
                '${(_progress.value * 100).toInt()}',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color, fontFamily: 'Consolas', height: 1.1),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text('$_grade $_gradeLabel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal')),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
              if (erp.isNotEmpty) _metaChip(erp),
              if (pattern.isNotEmpty && pattern != 'UNKNOWN') _metaChip(pattern),
              _metaChip('$_totalAccounts حساب'),
            ]),
          ])),
          const SizedBox(width: 20),
          // Ring
          SizedBox(
            width: 104, height: 104,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (_, __) => CustomPaint(
                painter: _SegmentedRingPainter(_progress.value, color),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(_progress.value * 100).toInt()}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color, fontFamily: 'Consolas')),
                  Text(_grade, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                ])),
              ),
            ),
          ),
        ]),
        // Confidence distribution
        const SizedBox(height: 12),
        Container(height: 1, color: _border),
        const SizedBox(height: 8),
        _buildConfidenceHist(),
      ]),
    );
  }

  Widget _metaChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _textSec)),
  );

  Widget _buildConfidenceHist() {
    final dist = _d['confidence_distribution'] as List? ?? [2, 5, 8, 12, 28, 35, 22, 15, 10, 5];
    final maxVal = dist.fold<num>(0, (a, b) => math.max(a, (b as num)));
    return Column(children: [
      SizedBox(
        height: 32,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(dist.length, (i) {
          final v = (dist[i] as num).toDouble();
          final pct = maxVal > 0 ? v / maxVal : 0.0;
          Color color;
          if (i < 3) color = _danger;
          else if (i < 5) color = _warning;
          else if (i < 7) color = _cyan;
          else color = _positive;
          return Expanded(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: 32 * pct,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ));
        })),
      ),
      const SizedBox(height: 2),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('50%', style: TextStyle(fontSize: 8, color: _textSec)),
        Text('60%', style: TextStyle(fontSize: 8, color: _textSec)),
        Text('70%', style: TextStyle(fontSize: 8, color: _textSec)),
        Text('80%', style: TextStyle(fontSize: 8, color: _textSec)),
        Text('90%', style: TextStyle(fontSize: 8, color: _textSec)),
        Text('100%', style: TextStyle(fontSize: 8, color: _textSec)),
      ]),
    ]);
  }

  // ── Headline Card (Report Card) ──
  Widget _buildHeadlineCard() {
    final headline = _d['headline_ar'] as String? ?? '';
    if (headline.isEmpty) return const SizedBox.shrink();
    final encoding = _d['encoding_detected'] as String? ?? '';
    final erp = _d['erp_system'] as String? ?? '';
    final pattern = _d['file_pattern'] as String? ?? '';
    final sector = _d['sector_detected'] ?? _d['sector_name'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface1, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(headline, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _gold, fontFamily: 'Tajawal', height: 1.6)),
        if (sector.toString().isNotEmpty || erp.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'تم تحليل $_totalAccounts حساب عبر 7 محاور${sector.toString().isNotEmpty ? ' — القطاع: $sector' : ''}${pattern.isNotEmpty ? ' — النمط: $pattern' : ''}${encoding.isNotEmpty ? ' — التشفير: $encoding' : ''}',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 11, color: _textSec, fontFamily: 'Tajawal', height: 1.5),
          ),
        ],
      ]),
    );
  }

  // ── Session Health ──
  Widget _buildSessionHealth() {
    final health = _d['session_health'] as Map? ?? {};
    if (health.isEmpty) return const SizedBox.shrink();
    final passOne = ((health['pass_one_rate'] ?? 0) as num).toDouble();
    final passTwo = ((health['pass_two_rate'] ?? 0) as num).toDouble();
    final llmRate = ((health['llm_rate'] ?? 0) as num).toDouble();
    final autoFix = (health['auto_fix_count'] ?? 0) as int;

    return Row(children: [
      _healthItem('${(passOne * 100).round()}%', 'كود مباشر', _positive),
      const SizedBox(width: 6),
      _healthItem('${((passTwo) * 100).round()}%', 'معجم', _cyan),
      const SizedBox(width: 6),
      _healthItem('${(llmRate * 100).round()}%', 'AI / LLM', _warning),
      const SizedBox(width: 6),
      _healthItem('$autoFix', 'إصلاحات تلقائية', _positive),
    ]);
  }

  Widget _healthItem(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, fontFamily: 'Consolas')),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 8, color: _textSec, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      ]),
    ),
  );

  // ── Sector Comparison ──
  Widget _buildSectorComparison() {
    final cmp = _d['sector_comparison'] as Map? ?? {};
    if (cmp.isEmpty) return const SizedBox.shrink();
    final yourScore = ((cmp['your_score'] ?? _overall * 100) as num).toDouble();
    final avgScore = ((cmp['sector_avg'] ?? 68) as num).toDouble();
    final rankText = cmp['rank_text'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('0', style: TextStyle(fontSize: 10, color: _textSec)),
          Text('مقارنة بالقطاع', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textPri, fontFamily: 'Tajawal')),
          Text('100', style: TextStyle(fontSize: 10, color: _textSec)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 6,
          child: Stack(children: [
            Container(
              decoration: BoxDecoration(color: AC.tp.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(3)),
            ),
            FractionallySizedBox(
              widthFactor: (yourScore / 100).clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: _cyan, borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              left: (avgScore / 100).clamp(0.0, 1.0) * (MediaQuery.of(context).size.width - 64),
              top: -4, child: Container(width: 2, height: 14, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(1))),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('متوسط القطاع: ${avgScore.round()}', style: TextStyle(fontSize: 9, color: _textSec)),
          Text('درجتك: ${yourScore.round()}', style: TextStyle(fontSize: 9, color: _textSec)),
        ]),
        if (rankText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(rankText, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: _positive, fontFamily: 'Tajawal')),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // STATS STRIP (auto-approved, review, rejected)
  // ═══════════════════════════════════════════
  Widget _buildStatsStrip() {
    final autoApproved = (_d['auto_approved_count'] ?? (_totalAccounts * 0.83).round()) as int;
    final reviewCount = (_d['review_count'] ?? (_totalAccounts * 0.13).round()) as int;
    final rejected = (_d['rejected_count'] ?? (_totalAccounts * 0.04).round()) as int;
    final total = autoApproved + reviewCount + rejected;
    String pct(int v) => total > 0 ? '${(v / total * 100).round()}%' : '0%';

    return Row(children: [
      _statCard(autoApproved, 'معتمد تلقائياً', '▲ ${pct(autoApproved)}', _positive),
      const SizedBox(width: 8),
      _statCard(reviewCount, 'بانتظار المراجعة', pct(reviewCount), _warning),
      const SizedBox(width: 8),
      _statCard(rejected, 'مرفوض', pct(rejected), _danger),
    ]);
  }

  Widget _statCard(int value, String label, String delta, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        // Right accent border
      ),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color, fontFamily: 'Consolas')),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(delta, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color, fontFamily: 'Consolas')),
        ),
      ]),
    ),
  );

  // ═══════════════════════════════════════════
  // SECTOR CARD
  // ═══════════════════════════════════════════
  Widget _buildSectorCard() {
    final sector = _d['sector_name'] as String? ?? _d['detected_sector'] as String? ?? '';
    final confidence = ((_d['sector_confidence'] ?? 0.0) as num).toDouble();
    final refAccounts = (_d['sector_reference_accounts'] ?? 180) as int;
    if (sector.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cyan.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [_cyan.withValues(alpha: 0.12), _cyan.withValues(alpha: 0.05)]),
          ),
          child: Icon(Icons.domain_rounded, color: _cyan, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('تم تحديد القطاع تلقائياً بدقة ${(confidence * 100).round()}%',
            style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal')),
          const SizedBox(height: 2),
          Text(sector, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _cyan, fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          Wrap(spacing: 6, alignment: WrapAlignment.end, children: [
            _sectorTag('$refAccounts حساب مرجعي', _cyan),
          ]),
        ])),
      ]),
    );
  }

  Widget _sectorTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal')),
  );

  // ═══════════════════════════════════════════
  // TAB BAR
  // ═══════════════════════════════════════════
  Widget _buildTabBar() {
    final errCount = (_d['total_errors'] ?? _d['error_count'] ?? 0) as int;
    final tabs = ['الجودة', 'المحاكاة', 'الامتثال', 'الأخطاء', 'خارطة الطريق'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(tabs.length, (i) {
          final on = _tabIndex == i;
          return _AnimTabBtn(
            label: tabs[i],
            isActive: on,
            gold: _gold,
            textSec: _textSec,
            badge: i == 3 && errCount > 0 ? errCount : null,
            badgeColor: _danger,
            onTap: () => setState(() => _tabIndex = i),
          );
        })),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 0: return _buildQualityTab();
      case 1: return _buildSimulationTab();
      case 2: return _buildComplianceTab();
      case 3: return _buildErrorsTab();
      case 4: return _buildRoadmapTab();
      default: return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════
  // TAB 0: QUALITY
  // ═══════════════════════════════════════════
  Widget _buildQualityTab() {
    final qd = _d['quality_dimensions'] as Map? ?? {};
    final dims = [
      ('classification_accuracy', 'دقة التصنيف', (qd['classification_accuracy'] as num?)?.toDouble()),
      ('error_severity', 'حدة الأخطاء', (qd['error_severity'] as num?)?.toDouble()),
      ('completeness', 'الاكتمال', (qd['completeness'] as num?)?.toDouble()),
      ('naming_quality', 'جودة الأسماء', (qd['naming_quality'] as num?)?.toDouble()),
      ('code_consistency', 'اتساق الترميز', (qd['code_consistency'] as num?)?.toDouble()),
    ];
    final readiness = _d['reporting_readiness']?['readiness'] as Map? ?? {};
    final strengths = (_d['strengths'] as List?)?.cast<String>() ?? [];
    final weaknesses = (_d['weaknesses'] as List?)?.cast<String>() ?? [];

    return Column(children: [
      // Dimension Grid (uses quality_dimensions percentages 0-100)
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: dims.take(4).map((d) {
          final val = d.$3 != null ? d.$3! / 100 : _score(d.$1);
          return _dimCard(d.$2, val);
        }).toList(),
      ),
      const SizedBox(height: 8),
      _dimCard(dims[4].$2, dims[4].$3 != null ? dims[4].$3! / 100 : _score(dims[4].$1), full: true),
      // Strengths / Weaknesses
      if (strengths.isNotEmpty || weaknesses.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (weaknesses.isNotEmpty) Expanded(child: _swCard('نقاط ضعف', weaknesses, _danger, Icons.warning_rounded)),
          if (weaknesses.isNotEmpty && strengths.isNotEmpty) const SizedBox(width: 8),
          if (strengths.isNotEmpty) Expanded(child: _swCard('نقاط قوة', strengths, _positive, Icons.check_circle_rounded)),
        ]),
      ],
      const SizedBox(height: 16),
      // Classification Donut
      _buildClassificationDonut(),
      const SizedBox(height: 16),
      // Readiness Grid
      _sectionTitle('جاهزية القوائم المالية'),
      const SizedBox(height: 8),
      _buildReadinessGrid(readiness),
    ]);
  }

  Widget _dimCard(String name, double val, {bool full = false}) {
    final color = _scoreColor(val);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(val * 100).toInt()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color, fontFamily: 'Consolas')),
          Text(name, style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal', fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: val.clamp(0.0, 1.0), minHeight: 4,
            backgroundColor: AC.tp.withValues(alpha: 0.04),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }

  Widget _buildClassificationDonut() {
    final classification = _d['classification_breakdown'] as Map? ?? {
      'أصول': 45, 'خصوم': 22, 'إيرادات': 18, 'مصروفات': 10, 'حقوق ملكية': 5,
    };
    final colors = [_positive, _cyan, _gold, _warning, _purple];
    final entries = classification.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Row(children: [
        // Legend
        Expanded(child: Column(children: List.generate(entries.length, (i) {
          final e = entries[i];
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${e.value}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'Consolas')),
              const SizedBox(width: 4),
              Text('${e.key}', style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal')),
              const SizedBox(width: 4),
              Container(width: 8, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: color)),
            ]),
          );
        }))),
        const SizedBox(width: 16),
        // Donut
        SizedBox(
          width: 64, height: 64,
          child: CustomPaint(painter: _DonutPainter(
            entries.map((e) => (e.value as num).toDouble()).toList(),
            colors,
          )),
        ),
      ]),
    );
  }

  Widget _buildReadinessGrid(Map readiness) {
    final items = [
      ('income_statement', 'قائمة الدخل', Icons.show_chart_rounded),
      ('balance_sheet', 'الميزانية', Icons.account_balance_rounded),
      ('cash_flow', 'التدفقات', Icons.attach_money_rounded),
      ('ratio_analysis', 'النسب المالية', Icons.bar_chart_rounded),
    ];
    return Row(children: items.map((item) {
      final ready = readiness[item.$1] == true;
      final partial = readiness[item.$1] == 'partial';
      final color = ready ? _positive : partial ? _warning : _danger;
      final status = ready ? '✓' : partial ? '⚠' : '✗';
      return Expanded(child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: _surface1, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(item.$3, color: color, size: 22),
          const SizedBox(height: 4),
          Text(item.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      ));
    }).toList());
  }

  // ── Strengths/Weaknesses Card ──
  Widget _swCard(String title, List<String> items, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
        const SizedBox(width: 4),
        Icon(icon, color: color, size: 14),
      ]),
      const SizedBox(height: 8),
      ...items.take(4).map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(child: Text(item, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal', height: 1.5))),
          const SizedBox(width: 4),
          Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        ]),
      )),
    ]),
  );

  // ═══════════════════════════════════════════
  // TAB 1: SIMULATION
  // ═══════════════════════════════════════════
  Widget _buildSimulationTab() {
    final sim = _d['simulation'] as Map? ?? {};
    final simScore = ((sim['simulation_score'] ?? _score('simulation_score')) as num?) ?? 0.0;
    final bs = sim['balance_sheet'] as Map? ?? {};
    final is_ = sim['income_statement'] as Map? ?? {};
    final cf = sim['cash_flow'] as Map? ?? {};
    final gaps = (_d['structural_gaps'] ?? sim['gaps'] ?? []) as List;

    return Column(children: [
      // Sim panel
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: _positive.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('${(simScore.toDouble() * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _positive, fontFamily: 'Consolas')),
            ),
            Text('المحاكاة المالية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _simCol('الميزانية', bs['status'] ?? 'متوازنة', Icons.grid_view_rounded, _positive),
            const SizedBox(width: 8),
            _simCol('قائمة الدخل', is_['status'] ?? 'ناقصة', Icons.show_chart_rounded, _warning),
            const SizedBox(width: 8),
            _simCol('التدفقات النقدية', cf['status'] ?? 'مؤشرات', Icons.attach_money_rounded, _cyan),
          ]),
        ]),
      ),
      if (gaps.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('الفجوات الهيكلية', dotColor: _warning),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: gaps.take(6).map((g) {
            final gap = g as Map;
            final severity = gap['severity'] ?? 'warning';
            final color = severity == 'critical' ? _danger : severity == 'ok' ? _positive : _warning;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surface1, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withValues(alpha: 0.1)),
                  child: Icon(severity == 'ok' ? Icons.check_rounded : Icons.warning_rounded, color: color, size: 14),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Text(gap['name'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
                  Text(gap['code'] ?? '', style: TextStyle(fontSize: 9, color: _textSec, fontFamily: 'Consolas')),
                ]),
              ]),
            );
          }).toList(),
        ),
      ],
    ]);
  }

  Widget _simCol(String name, String status, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(name, style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
      ]),
    ),
  );

  // ═══════════════════════════════════════════
  // TAB 2: COMPLIANCE
  // ═══════════════════════════════════════════
  Widget _buildComplianceTab() {
    final checks = (_d['compliance_checks'] ?? []) as List;
    final compScore = _score('compliance_score');

    final compliance = _d['compliance'] as Map? ?? {};
    final authorities = compliance['authorities'] as Map? ?? {};
    final totalRules = (compliance['total_rules'] ?? checks.length) as int;
    final passedRules = (compliance['compliance_score'] as num?)?.toInt() ?? (compScore * totalRules).round();

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${(compScore * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _positive, fontFamily: 'Consolas')),
        Text('نسبة الامتثال الكلية — $passedRules/$totalRules قواعد', style: TextStyle(fontSize: 11, color: _textSec, fontFamily: 'Tajawal')),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: compScore.clamp(0.0, 1.0), minHeight: 6,
          backgroundColor: AC.tp.withValues(alpha: 0.04),
          valueColor: AlwaysStoppedAnimation(_positive),
        ),
      ),
      // Authority Breakdown
      if (authorities.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: authorities.entries.take(4).map((e) {
          final auth = e.value as Map? ?? {};
          final passed = auth['passed'] ?? 0;
          final failed = auth['failed'] ?? 0;
          return Expanded(child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
            child: Column(children: [
              Text(e.key, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _gold)),
              const SizedBox(height: 4),
              RichText(text: TextSpan(style: const TextStyle(fontSize: 10), children: [
                TextSpan(text: '$passed', style: TextStyle(color: _positive)),
                TextSpan(text: ' / ', style: TextStyle(color: _textSec)),
                TextSpan(text: '$failed', style: TextStyle(color: _danger)),
              ])),
            ]),
          ));
        }).toList()),
      ],
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        childAspectRatio: 2.4,
        children: checks.take(8).map((c) {
          final check = c as Map;
          final pass = check['status'] == 'pass' || check['status'] == true;
          final warn = check['status'] == 'warning';
          final color = pass ? _positive : warn ? _warning : _danger;
          final statusText = pass ? '✓ مستوفى' : warn ? '⚠ تحذير' : '✗ مفقود';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface1, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(check['framework'] ?? '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Text(check['name'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPri, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(statusText, style: TextStyle(fontSize: 10, color: color, fontFamily: 'Tajawal')),
              ]),
            ]),
          );
        }).toList(),
      ),
    ]);
  }

  // ═══════════════════════════════════════════
  // TAB 3: ERRORS
  // ═══════════════════════════════════════════
  Widget _buildErrorsTab() {
    final errSummary = _d['errors_summary'] as Map? ?? _d['errors'] as Map? ?? {};
    final critical = (errSummary['critical'] ?? 0) as int;
    final high = (errSummary['high'] ?? 0) as int;
    final medium = (errSummary['medium'] ?? 0) as int;
    final low = (errSummary['low'] ?? 0) as int;
    final errorList = (_d['errors'] is List ? _d['errors'] as List : []);
    final fraudAlerts = (_d['fraud_alerts'] ?? []) as List;

    return Column(children: [
      // Error summary strip
      Row(children: [
        _errBox(critical, 'حرجة', _danger),
        const SizedBox(width: 8),
        _errBox(high, 'مرتفعة', _warning),
        const SizedBox(width: 8),
        _errBox(medium, 'متوسطة', _cyan),
        const SizedBox(width: 8),
        _errBox(low, 'منخفضة', _textSec),
      ]),
      // Error Detail List
      if (errorList.isNotEmpty) ...[
        const SizedBox(height: 12),
        ...errorList.take(8).map((e) {
          final err = e as Map;
          final sev = err['severity']?.toString().toLowerCase() ?? 'medium';
          final color = sev == 'critical' ? _danger : sev == 'high' ? _warning : sev == 'medium' ? _cyan : _textSec;
          final autoFix = err['auto_fixable'] == true;
          final autoFixed = err['auto_fix_applied'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(err['error_code'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(err['description_ar'] ?? '', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: color, fontFamily: 'Tajawal', height: 1.5)),
                if (err['suggestion_ar'] != null) ...[
                  const SizedBox(height: 2),
                  Text(err['suggestion_ar'], textDirection: TextDirection.rtl, style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal', height: 1.4)),
                ],
                if (autoFix || autoFixed) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _positive.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(autoFixed ? '✓ تم الإصلاح تلقائياً' : '✓ إصلاح تلقائي متاح',
                      style: TextStyle(fontSize: 9, color: _positive)),
                  ),
                ],
                if (err['references'] != null && (err['references'] as List).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text((err['references'] as List).join(' • '), style: TextStyle(fontSize: 9, color: _textSec)),
                ],
              ])),
            ]),
          );
        }),
      ],
      if (fraudAlerts.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('تنبيهات الاحتيال', dotColor: _danger),
        const SizedBox(height: 8),
        ...fraudAlerts.take(5).map((alert) {
          final a = alert as Map;
          final severity = a['severity'] ?? 'warning';
          final color = severity == 'critical' || severity == 'high' ? _danger : severity == 'clean' || severity == 'ok' ? _positive : _warning;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface1, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withValues(alpha: 0.1)),
                child: Icon(
                  severity == 'clean' || severity == 'ok' ? Icons.verified_rounded : Icons.warning_rounded,
                  color: color, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(a['title'] ?? a['code'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal')),
                const SizedBox(height: 2),
                Text(a['description'] ?? '', style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal', height: 1.5), textDirection: TextDirection.rtl),
              ])),
            ]),
          );
        }),
      ],
    ]);
  }

  Widget _errBox(int value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _surface1, borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 3), left: BorderSide(color: _border), right: BorderSide(color: _border), bottom: BorderSide(color: _border)),
      ),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFamily: 'Consolas')),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, color: _textSec, fontFamily: 'Tajawal')),
      ]),
    ),
  );

  // ═══════════════════════════════════════════
  // TAB 4: ROADMAP
  // ═══════════════════════════════════════════
  Widget _buildRoadmapTab() {
    final items = (_d['roadmap'] ?? []) as List;
    final completed = items.where((r) => (r as Map)['done'] == true).length;

    return Column(children: [
      Row(children: [
        Text('مقدّر: ${_d['roadmap_time_estimate'] ?? '145'} د', style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal')),
        const Spacer(),
        Expanded(flex: 3, child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: items.isNotEmpty ? completed / items.length : 0,
            minHeight: 6,
            backgroundColor: AC.tp.withValues(alpha: 0.04),
            valueColor: AlwaysStoppedAnimation(_positive),
          ),
        )),
        const SizedBox(width: 8),
        Text('$completed/${items.length}', style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Consolas')),
      ]),
      const SizedBox(height: 12),
      ...items.take(8).map((r) {
        final road = r as Map;
        final priority = road['priority'] ?? 'medium';
        final color = priority == 'urgent' ? _danger : priority == 'high' ? _warning : priority == 'low' ? _positive : _cyan;
        final priorityLabel = priority == 'urgent' ? 'عاجل' : priority == 'high' ? 'مهم' : priority == 'low' ? 'اختياري' : 'تحسين';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface1, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(priorityLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
              ),
              const Spacer(),
              Expanded(flex: 3, child: Text(road['title'] ?? '', textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPri, fontFamily: 'Tajawal', height: 1.5))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 4, alignment: WrapAlignment.end, children: [
              if (road['effort'] != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (road['effort'] == 'سهل' ? _positive : road['effort'] == 'صعب' ? _danger : _warning).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(road['effort'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                  color: road['effort'] == 'سهل' ? _positive : road['effort'] == 'صعب' ? _danger : _warning)),
              ),
              if (road['estimated_minutes'] != null) Text('${road['estimated_minutes']} د', style: TextStyle(fontSize: 10, color: _textSec)),
              if (road['time'] != null && road['estimated_minutes'] == null) Text('${road['time']}', style: TextStyle(fontSize: 10, color: _textSec)),
              if (road['score_impact'] != null) Text(road['score_impact'], style: TextStyle(fontSize: 10, color: _positive, fontFamily: 'Consolas')),
              if (road['points'] != null && road['score_impact'] == null) Text('+${road['points']} نقاط', style: TextStyle(fontSize: 10, color: _positive, fontFamily: 'Consolas')),
              if (road['compliance_ref'] != null) Text(road['compliance_ref'], style: TextStyle(fontSize: 10, color: _cyan)),
              if (road['tag'] != null && road['compliance_ref'] == null) Text(road['tag'], style: TextStyle(fontSize: 10, color: _cyan)),
            ]),
          ]),
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════
  // KNOWLEDGE GRAPH
  // ═══════════════════════════════════════════
  Widget _buildKnowledgeGraph() {
    final nodes = (_d['knowledge_graph']?['nodes'] as List? ?? []).take(12).map((n) {
      if (n is String) return n;
      if (n is Map) return n['name']?.toString() ?? '';
      return '';
    }).where((s) => s.isNotEmpty).toList();
    final totalConcepts = (_d['knowledge_graph']?['total_concepts'] ?? nodes.length) as int;
    if (nodes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface1, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withValues(alpha: 0.12)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('$totalConcepts مفهوم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _purple)),
          ),
          Text('الشبكة المعرفية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: nodes.map((n) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _surface2, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border),
          ),
          child: Text(n, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _textSec, fontFamily: 'Tajawal')),
        )).toList()),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // REVIEW QUEUE PREVIEW
  // ═══════════════════════════════════════════
  Widget _buildReviewQueuePreview() {
    final queue = (_d['review_queue'] ?? []) as List;
    if (queue.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      _sectionTitle('حسابات بانتظار المراجعة', dotColor: _warning),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
        child: Column(children: queue.take(5).map((q) {
          final item = q as Map;
          final conf = ((item['confidence'] ?? 0) as num).toDouble();
          final confColor = conf < 0.4 ? _danger : conf < 0.65 ? _warning : _positive;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
            child: Row(children: [
              Text('${(conf * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: confColor, fontFamily: 'Consolas')),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${item['account_code'] ?? ''} — ${item['account_name'] ?? ''}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPri, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
                if (item['reason'] != null) Text(item['reason'], style: TextStyle(fontSize: 9, color: _textSec, fontFamily: 'Tajawal')),
              ])),
            ]),
          );
        }).toList()),
      ),
    ]);
  }

  // ═══════════════════════════════════════════
  // RECOMMENDATIONS
  // ═══════════════════════════════════════════
  Widget _buildRecommendations(List<String> recs) => Column(children: [
    _sectionTitle('توصيات التحسين', dotColor: _warning),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface1, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warning.withValues(alpha: 0.12)),
      ),
      child: Column(children: recs.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(width: 8),
          Expanded(child: Text(r, textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12, color: _textPri, fontFamily: 'Tajawal', height: 1.6))),
          const SizedBox(width: 6),
          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: _warning)),
        ]),
      )).toList()),
    ),
  ]);

  // ═══════════════════════════════════════════
  // SHARE BAR
  // ═══════════════════════════════════════════
  Widget _buildShareBar() => Row(children: [
    _shareBtn(Icons.download_rounded, 'تصدير PDF'),
    const SizedBox(width: 8),
    _shareBtn(Icons.share_rounded, 'مشاركة التقرير'),
    const SizedBox(width: 8),
    _shareBtn(Icons.copy_rounded, 'نسخ الملخص'),
  ]);

  Widget _shareBtn(IconData icon, String label) => Expanded(
    child: _AnimShareBtn(icon: icon, label: label, surface: _surface1, border: _border, textSec: _textSec, gold: _gold),
  );

  // ═══════════════════════════════════════════
  // SIMULATION CARDS — 4 simulation tools
  // ═══════════════════════════════════════════
  Widget _buildSimulationCards() {
    final extras = {'uploadId': widget.uploadId, 'clientId': widget.clientId, 'clientName': widget.clientName};
    final sims = [
      ('محاكاة مالية', Icons.account_balance_rounded, _cyan, '/coa/financial-simulation'),
      ('فحص الامتثال', Icons.verified_user_rounded, _positive, '/coa/compliance-check'),
      ('خارطة الإصلاح', Icons.map_rounded, _purple, '/coa/roadmap'),
      ('فحص الميزان', Icons.balance_rounded, _warning, '/coa/trial-balance-check'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('أدوات المحاكاة والتحليل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
          const SizedBox(width: 8),
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _gold)),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: sims.map((s) => _simCard(s.$1, s.$2, s.$3, s.$4, extras)).toList(),
        ),
      ]),
    );
  }

  Widget _simCard(String label, IconData icon, Color color, String route, Map<String, dynamic> extras) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(route, extra: extras),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.20)),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.06), _surface1],
              begin: Alignment.topRight, end: Alignment.bottomLeft,
            ),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.5), size: 14),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // FOOTER CTA
  // ═══════════════════════════════════════════
  Widget _buildFooterCTA(int reviewCount) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_bg.withValues(alpha: 0), _bg],
        stops: const [0, 0.3],
      ),
    ),
    child: GestureDetector(
      onTap: () => context.push('/coa/review', extra: {
        'uploadId': widget.uploadId,
        'clientId': widget.clientId,
        'clientName': widget.clientName,
      }),
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_positive, _positive.withValues(alpha: 0.7)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _positive.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.arrow_forward_rounded, color: AC.btnFg, size: 18),
          const SizedBox(width: 8),
          Text('متابعة لمراجعة التبويب', style: TextStyle(color: AC.btnFg, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
          if (reviewCount > 0) ...[
            const SizedBox(width: 8),
            Text('($reviewCount حساب)', style: TextStyle(color: AC.btnFg.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'Consolas')),
          ],
        ]),
      ),
    ),
  );

  // ── Helpers ──
  Widget _sectionTitle(String text, {Color? dotColor}) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
    const SizedBox(width: 8),
    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor ?? _gold)),
  ]);
}

// ═══════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════

class _SegmentedRingPainter extends CustomPainter {
  final double value;
  final Color color;
  const _SegmentedRingPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    final bgPaint = Paint()..color = AC.tp.withValues(alpha: 0.03)..strokeWidth = 8..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, bgPaint);

    // Multi-segment arc
    final segments = [
      (0.35, color, 0.9),
      (0.25, AC.cyan, 0.75),
      (0.22, AC.warn, 0.6),
      (0.18, AC.gold, 0.5),
    ];
    double offset = -math.pi / 2;
    for (final seg in segments) {
      final sweep = 2 * math.pi * value * seg.$1;
      final paint = Paint()
        ..color = seg.$2.withValues(alpha: seg.$3)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), offset, sweep, false, paint);
      offset += sweep + 0.04;
    }
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter old) => old.value != value;
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _DonutPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, sweep - 0.04, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

class _AnimTabBtn extends StatefulWidget {
  final String label;
  final bool isActive;
  final Color gold;
  final Color textSec;
  final int? badge;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _AnimTabBtn({required this.label, required this.isActive, required this.gold, required this.textSec, this.badge, this.badgeColor, required this.onTap});
  @override
  State<_AnimTabBtn> createState() => _AnimTabBtnState();
}

class _AnimTabBtnState extends State<_AnimTabBtn> {
  bool _hov = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.isActive;
    final highlighted = on || _hov;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() { _hov = false; _press = false; }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _press = true),
        onTapUp: (_) { setState(() => _press = false); widget.onTap(); },
        onTapCancel: () => setState(() => _press = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          transform: _press
              ? (Matrix4.identity()..scale(0.93))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted ? widget.gold.withValues(alpha: on ? 0.12 : 0.06) : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? [
              BoxShadow(color: widget.gold.withValues(alpha: 0.08), blurRadius: 6),
            ] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label, style: TextStyle(
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
              color: highlighted ? widget.gold : widget.textSec,
              fontFamily: 'Tajawal',
            )),
            if (widget.badge != null) ...[
              const SizedBox(width: 4),
              AnimatedScale(
                scale: _hov ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: widget.badgeColor, borderRadius: BorderRadius.circular(7)),
                  child: Text('${widget.badge}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AC.btnFg)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _AnimShareBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color surface;
  final Color border;
  final Color textSec;
  final Color gold;
  final VoidCallback? onTap;
  const _AnimShareBtn({required this.icon, required this.label, required this.surface, required this.border, required this.textSec, required this.gold, this.onTap});
  @override
  State<_AnimShareBtn> createState() => _AnimShareBtnState();
}

class _AnimShareBtnState extends State<_AnimShareBtn> {
  bool _hov = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() { _hov = false; _press = false; }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _press = true),
        onTapUp: (_) { setState(() => _press = false); widget.onTap?.call(); },
        onTapCancel: () => setState(() => _press = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          transform: _press
              ? (Matrix4.identity()..scale(0.94))
              : _hov
                  ? (Matrix4.identity()..scale(1.03))
                  : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hov ? widget.gold.withValues(alpha: 0.06) : widget.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hov ? widget.gold.withValues(alpha: 0.3) : widget.border,
            ),
            boxShadow: _hov ? [
              BoxShadow(color: widget.gold.withValues(alpha: 0.08), blurRadius: 8),
            ] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(widget.label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: _hov ? widget.gold : widget.textSec,
              fontFamily: 'Tajawal',
            )),
            const SizedBox(width: 6),
            AnimatedScale(
              scale: _hov ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(widget.icon, color: _hov ? widget.gold : widget.textSec, size: 14),
            ),
          ]),
        ),
      ),
    );
  }
}
