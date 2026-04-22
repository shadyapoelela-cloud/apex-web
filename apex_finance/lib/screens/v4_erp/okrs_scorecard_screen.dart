/// APEX Wave 68 — KPI Scorecard / OKRs.
/// Route: /app/erp/finance/okrs
///
/// Objectives & Key Results tracking aligned with strategy.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class OkrsScorecardScreen extends StatefulWidget {
  const OkrsScorecardScreen({super.key});
  @override
  State<OkrsScorecardScreen> createState() => _OkrsScorecardScreenState();
}

class _OkrsScorecardScreenState extends State<OkrsScorecardScreen> {
  String _level = 'company';
  String _quarter = 'Q2-2026';

  final _objectives = [
    _Objective(
      'OBJ-2026-01',
      '📈 نمو الإيرادات 30% YoY',
      'company',
      'النمو المستدام',
      core_theme.AC.gold,
      'أحمد العتيبي',
      [
        _KeyResult('KR-01.1', 'تحقيق 25M ر.س من الإيرادات Q2', 18.5, 25, 'ر.س (M)'),
        _KeyResult('KR-01.2', 'إضافة 12 عميل استراتيجي جديد', 8, 12, 'عميل'),
        _KeyResult('KR-01.3', 'زيادة متوسط قيمة الصفقة 20%', 18, 20, '%'),
      ],
    ),
    _Objective(
      'OBJ-2026-02',
      '🌍 التوسع الإقليمي للإمارات',
      'company',
      'النمو الدولي',
      Color(0xFF006C35),
      'سارة الدوسري',
      [
        _KeyResult('KR-02.1', 'فتح مكتب تمثيلي في دبي', 80, 100, '%'),
        _KeyResult('KR-02.2', 'تسجيل في السوق المالي الإماراتي', 45, 100, '%'),
        _KeyResult('KR-02.3', 'توقيع أول 3 عقود محلية', 1, 3, 'عقد'),
      ],
    ),
    _Objective(
      'OBJ-2026-03',
      '🤖 التحوّل إلى AI-first company',
      'company',
      'الابتكار',
      Color(0xFF4A148C),
      'راشد العنزي',
      [
        _KeyResult('KR-03.1', 'إطلاق 8 وكلاء ذكاء اصطناعي للعمليات', 6, 8, 'وكيل'),
        _KeyResult('KR-03.2', 'زيادة أتمتة العمليات 60%', 42, 60, '%'),
        _KeyResult('KR-03.3', 'تدريب 40% من الفريق على AI', 28, 40, '%'),
      ],
    ),
    _Objective(
      'OBJ-2026-04',
      '⭐ رفع رضا العملاء إلى NPS 80+',
      'department',
      'العميل',
      core_theme.AC.info,
      'لينا البكري',
      [
        _KeyResult('KR-04.1', 'Net Promoter Score', 76, 80, 'NPS'),
        _KeyResult('KR-04.2', 'تقليل معدل التسرّب إلى < 5%', 7, 5, '% (عكسي)'),
        _KeyResult('KR-04.3', 'متوسط زمن الاستجابة < 4 ساعات', 3.2, 4, 'ساعة (عكسي)'),
      ],
    ),
    _Objective(
      'OBJ-2026-05',
      '🛡️ الامتثال الكامل لمتطلبات ZATCA',
      'department',
      'الامتثال',
      core_theme.AC.ok,
      'محمد القحطاني',
      [
        _KeyResult('KR-05.1', 'نسبة الفواتير الموقّعة تلقائياً', 98.5, 99, '%'),
        _KeyResult('KR-05.2', 'صفر مخالفات ZATCA', 0, 0, 'مخالفة'),
        _KeyResult('KR-05.3', 'تقديم جميع الإقرارات في الموعد', 100, 100, '%'),
      ],
    ),
    _Objective(
      'OBJ-2026-06',
      '💰 تحسين الكفاءة التشغيلية',
      'department',
      'الكفاءة',
      core_theme.AC.warn,
      'فهد الشمري',
      [
        _KeyResult('KR-06.1', 'خفض DSO إلى 32 يوم', 35, 32, 'يوم (عكسي)'),
        _KeyResult('KR-06.2', 'تقليل مدة إقفال الشهر إلى 5 أيام', 7, 5, 'يوم (عكسي)'),
        _KeyResult('KR-06.3', 'خفض تكلفة كل فاتورة 30%', 18, 30, '%'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _objectives.where((o) => _level == 'all' || o.level == _level).toList();
    final avgProgress = filtered.isEmpty
        ? 0.0
        : filtered.map((o) => o.progress).fold(0.0, (s, v) => s + v) / filtered.length;
    final onTrack = filtered.where((o) => o.progress >= 70).length;
    final atRisk = filtered.where((o) => o.progress >= 40 && o.progress < 70).length;
    final offTrack = filtered.where((o) => o.progress < 40).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(avgProgress),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('الأهداف', '${filtered.length}', core_theme.AC.gold, Icons.flag),
            _kpi('على المسار', '$onTrack', core_theme.AC.ok, Icons.check_circle),
            _kpi('تحت المتابعة', '$atRisk', core_theme.AC.warn, Icons.warning),
            _kpi('متأخّرة', '$offTrack', core_theme.AC.err, Icons.error),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _levelChip('all', 'الكل'),
            const SizedBox(width: 8),
            _levelChip('company', '🏢 مستوى الشركة'),
            const SizedBox(width: 8),
            _levelChip('department', '👥 مستوى القسم'),
            const Spacer(),
            _quarterDropdown(),
          ],
        ),
        const SizedBox(height: 16),
        for (final o in filtered) _objectiveCard(o),
      ],
    );
  }

  Widget _buildHero(double avgProgress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.track_changes, color: Color(0xFF1A237E), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الأهداف والنتائج الرئيسية (OKRs)',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                Text('منهجية OKR — تتبع الأهداف الاستراتيجية ومقاييس الأداء',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('متوسط التقدّم', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
              Text('${avgProgress.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelChip(String id, String label) {
    final selected = _level == id;
    return InkWell(
      onTap: () => setState(() => _level = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A237E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF1A237E) : core_theme.AC.td),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : core_theme.AC.tp,
            )),
      ),
    );
  }

  Widget _quarterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.td),
      ),
      child: DropdownButton<String>(
        value: _quarter,
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: core_theme.AC.tp),
        items: const [
          DropdownMenuItem(value: 'Q1-2026', child: Text('الربع الأول 2026')),
          DropdownMenuItem(value: 'Q2-2026', child: Text('الربع الثاني 2026')),
          DropdownMenuItem(value: 'Q3-2026', child: Text('الربع الثالث 2026')),
          DropdownMenuItem(value: 'Q4-2026', child: Text('الربع الرابع 2026')),
          DropdownMenuItem(value: 'YEAR-2026', child: Text('السنة الكاملة 2026')),
        ],
        onChanged: (v) => setState(() => _quarter = v ?? _quarter),
      ),
    );
  }

  Widget _objectiveCard(_Objective o) {
    final color = o.color;
    final health = o.progress >= 70 ? core_theme.AC.ok : o.progress >= 40 ? core_theme.AC.warn : core_theme.AC.err;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(o.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(o.category,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (o.level == 'company' ? core_theme.AC.purple : core_theme.AC.info).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(o.level == 'company' ? '🏢 شركة' : '👥 قسم',
                    style: TextStyle(
                      fontSize: 11,
                      color: o.level == 'company' ? core_theme.AC.purple : core_theme.AC.info,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(o.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: core_theme.AC.ts),
              const SizedBox(width: 4),
              Text('المسؤول: ${o.owner}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ],
          ),
          const SizedBox(height: 14),
          // Overall progress bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: health.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: health, size: 18),
                const SizedBox(width: 8),
                Text('التقدّم الكلي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 16),
                Expanded(
                  child: LinearProgressIndicator(
                    value: o.progress / 100,
                    backgroundColor: core_theme.AC.bdr,
                    valueColor: AlwaysStoppedAnimation(health),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(width: 12),
                Text('${o.progress.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: health)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('النتائج الرئيسية (Key Results)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.ts)),
          const SizedBox(height: 8),
          for (final kr in o.keyResults) _krRow(kr, color),
        ],
      ),
    );
  }

  Widget _krRow(_KeyResult kr, Color color) {
    final isInverse = kr.unit.contains('عكسي');
    final pct = isInverse
        ? (kr.target > 0 ? ((kr.target / kr.current) * 100).clamp(0.0, 100.0) : 0.0)
        : (kr.target > 0 ? (kr.current / kr.target * 100).clamp(0.0, 100.0) : 0.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: core_theme.AC.navy3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(kr.id,
                style: TextStyle(fontSize: 10, color: color, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(kr.description, style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 90,
            child: Text(
              '${_fmt(kr.current)} / ${_fmt(kr.target)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(kr.unit.replaceAll(' (عكسي)', ''),
                style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: core_theme.AC.bdr,
                    valueColor: AlwaysStoppedAnimation(
                        pct >= 70 ? core_theme.AC.ok : pct >= 40 ? core_theme.AC.warn : core_theme.AC.err),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: pct >= 70 ? core_theme.AC.ok : pct >= 40 ? core_theme.AC.warn : core_theme.AC.err)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _Objective {
  final String id;
  final String title;
  final String level;
  final String category;
  final Color color;
  final String owner;
  final List<_KeyResult> keyResults;
  const _Objective(this.id, this.title, this.level, this.category, this.color, this.owner, this.keyResults);

  double get progress {
    if (keyResults.isEmpty) return 0;
    double sum = 0;
    for (final kr in keyResults) {
      final isInverse = kr.unit.contains('عكسي');
      final pct = isInverse
          ? (kr.target > 0 ? ((kr.target / (kr.current == 0 ? 0.001 : kr.current)) * 100).clamp(0.0, 100.0) : 100.0)
          : (kr.target > 0 ? (kr.current / kr.target * 100).clamp(0.0, 100.0) : 0.0);
      sum += pct;
    }
    return sum / keyResults.length;
  }
}

class _KeyResult {
  final String id;
  final String description;
  final double current;
  final double target;
  final String unit;
  const _KeyResult(this.id, this.description, this.current, this.target, this.unit);
}
