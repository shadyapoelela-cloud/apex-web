/// APEX Wave 62 — Executive Dashboard (C-Suite View).
/// Route: /app/platform/exec/dashboard
///
/// Aggregated KPIs across all services for CEO/CFO.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ExecutiveDashboardV5Screen extends StatefulWidget {
  const ExecutiveDashboardV5Screen({super.key});
  @override
  State<ExecutiveDashboardV5Screen> createState() => _ExecutiveDashboardV5ScreenState();
}

class _ExecutiveDashboardV5ScreenState extends State<ExecutiveDashboardV5Screen> {
  String _period = 'YTD-2026';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 20),
        _buildNorthStarKpis(),
        const SizedBox(height: 20),
        _buildFinanceSummary(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRevenueChart()),
            const SizedBox(width: 12),
            Expanded(child: _buildSegmentMix()),
          ],
        ),
        const SizedBox(height: 20),
        _buildRiskHeatmap(),
        const SizedBox(height: 20),
        _buildStrategicInitiatives(),
        const SizedBox(height: 20),
        _buildKeyAlerts(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0D1B3F), Color(0xFF1E3A8A), core_theme.AC.gold],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.star, color: core_theme.AC.gold, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة التنفيذيين',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                Text('نظرة موحّدة عبر جميع خدمات APEX — للرئيس التنفيذي والمدير المالي',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: const Color(0xFF0D1B3F),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'YTD-2026', child: Text('منذ بداية 2026')),
                DropdownMenuItem(value: 'Q1-2026', child: Text('الربع الأول 2026')),
                DropdownMenuItem(value: 'MONTH', child: Text('أبريل 2026')),
                DropdownMenuItem(value: 'YEAR-2025', child: Text('السنة المالية 2025')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNorthStarKpis() {
    return Row(
      children: [
        _kpiCard('الإيرادات YTD', '18.5M', '+24%', true, Icons.trending_up, core_theme.AC.gold),
        _kpiCard('EBITDA', '4.8M', '+31%', true, Icons.savings, core_theme.AC.ok),
        _kpiCard('هامش الربح', '26.2%', '+2.1pp', true, Icons.donut_large, core_theme.AC.info),
        _kpiCard('السيولة النقدية', '12.4M', '+18%', true, Icons.account_balance, core_theme.AC.info),
      ],
    );
  }

  Widget _kpiCard(String label, String value, String change, bool positive, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (positive ? core_theme.AC.ok : core_theme.AC.err).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(positive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12, color: positive ? core_theme.AC.ok : core_theme.AC.err),
                      const SizedBox(width: 2),
                      Text(change,
                          style: TextStyle(
                            fontSize: 11,
                            color: positive ? core_theme.AC.ok : core_theme.AC.err,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
                Padding(
                  padding: EdgeInsets.only(bottom: 3, right: 2),
                  child: Text('ر.س', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ملخّص الأداء المالي YTD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryStat('إيرادات الخدمات', 8500000, 6200000, true),
              _summaryStat('إيرادات المنتجات', 10000000, 8400000, true),
              _summaryStat('إجمالي المصروفات', 13650000, 11800000, false),
              _summaryStat('صافي الربح', 4850000, 2800000, true),
              _summaryStat('الأصول الإجمالية', 48500000, 42300000, true),
              _summaryStat('حقوق الملكية', 22800000, 18500000, true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, double actual, double prior, bool higherBetter) {
    final change = ((actual - prior) / prior * 100);
    final positive = higherBetter ? change >= 0 : change <= 0;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: core_theme.AC.navy3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            const SizedBox(height: 4),
            Text(_fmtM(actual), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(positive ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 10, color: positive ? core_theme.AC.ok : core_theme.AC.err),
                Text('${change.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: positive ? core_theme.AC.ok : core_theme.AC.err,
                      fontWeight: FontWeight.w700,
                    )),
                Text(' YoY', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final months = const [
      _Bar('يناير', 1.2, 0.9),
      _Bar('فبراير', 1.4, 1.1),
      _Bar('مارس', 1.6, 1.3),
      _Bar('أبريل', 1.85, 1.4),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الإيرادات الشهرية vs السنة السابقة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('(مليون ريال)', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in months)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Container(
                                  height: m.prior * 60,
                                  decoration: BoxDecoration(
                                    color: core_theme.AC.td,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: m.current * 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [core_theme.AC.gold, Color(0xFFE6C200)],
                                    ),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(m.label, style: const TextStyle(fontSize: 10)),
                          Text('${m.current.toStringAsFixed(1)}M',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(core_theme.AC.td, 'السنة السابقة'),
              const SizedBox(width: 20),
              _legendDot(core_theme.AC.gold, 'الحالي'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildSegmentMix() {
    final segments = [
      _Seg('ERP', 8500000, core_theme.AC.gold),
      _Seg('المراجعة', 4200000, Color(0xFF4A148C)),
      _Seg('الاستشارات', 3100000, core_theme.AC.info),
      _Seg('السوق الرقمي', 1850000, core_theme.AC.info),
      _Seg('الامتثال', 850000, core_theme.AC.ok),
    ];
    final total = segments.fold(0.0, (s, x) => s + x.value);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مزيج الإيرادات حسب القطاع',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          for (final seg in segments) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(seg.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                Text('${(seg.value / total * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: seg.color)),
                const SizedBox(width: 10),
                Text(_fmtM(seg.value),
                    style: TextStyle(fontSize: 12, color: core_theme.AC.tp, fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: seg.value / total,
              backgroundColor: core_theme.AC.bdr,
              valueColor: AlwaysStoppedAnimation(seg.color),
              minHeight: 6,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskHeatmap() {
    final risks = const [
      _Risk('الامتثال الضريبي', 'low', 'انخفض بعد أتمتة إقرارات VAT'),
      _Risk('السيولة', 'low', 'هامش آمن 6 أشهر تشغيلية'),
      _Risk('التركّز في العملاء', 'medium', 'أكبر عميل 15% من الإيرادات'),
      _Risk('المخاطر التشغيلية (IT)', 'low', 'نظم احتياطية + SLA 99.95%'),
      _Risk('تقلّبات العملة', 'medium', '30% من الإيرادات بالدولار — تحوّط 65%'),
      _Risk('المواهب والتسرّب', 'medium', 'معدل تسرّب 9% — أعلى من الصناعة'),
      _Risk('الأمن السيبراني', 'low', 'SOC2 معتمد + فحوصات ربعية'),
      _Risk('المنافسة الإقليمية', 'medium', 'دخول منافس جديد في UAE'),
      _Risk('المخاطر الاستراتيجية', 'low', 'خطة 5 سنوات معتمدة'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('خريطة مخاطر المؤسسة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final r in risks)
                Container(
                  width: 320,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _riskColor(r.level).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _riskColor(r.level).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _riskColor(r.level),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_riskIcon(r.level), color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(r.note, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.3)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _riskColor(r.level),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(_riskLabel(r.level),
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategicInitiatives() {
    final initiatives = [
      _Init('التوسع في UAE', 68, 'Q3 2026', const Color(0xFF006C35)),
      _Init('رقمنة إقرارات ZATCA', 92, 'Q2 2026', core_theme.AC.gold),
      _Init('منتج Marketplace الجديد', 45, 'Q4 2026', core_theme.AC.info),
      _Init('حصول على SOC2 Type II', 82, 'Q2 2026', core_theme.AC.purple),
      _Init('استهداف عملاء FT 100', 38, 'Q1 2027', core_theme.AC.info),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المبادرات الاستراتيجية 2026',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          for (final i in initiatives)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(i.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: core_theme.AC.navy3,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: i.progress / 100,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: i.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text('${i.progress}%',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('الهدف: ${i.target}',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyAlerts() {
    final alerts = [
      _Alert('فرصة', 'عميل أرامكو ناقش عقد توسعة 3.2M ر.س',
          'الخطوة: اجتماع CFO الأسبوع القادم', core_theme.AC.ok, Icons.trending_up),
      _Alert('تنبيه', 'عقد SAP License ينتهي بعد 12 يوم',
          'الخطوة: التفاوض على التجديد', core_theme.AC.warn, Icons.schedule),
      _Alert('مخاطر', 'معدل تسرّب الموظفين وصل 9% — فوق معيار الصناعة',
          'الخطوة: مراجعة سياسة المكافآت مع المجلس', core_theme.AC.err, Icons.warning),
      _Alert('تقدم', 'تمّ اعتماد CbCR 2025 من ZATCA',
          'إنجاز: في الموعد بدون تحفظات', core_theme.AC.info, Icons.check_circle),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تنبيهات تنفيذية رئيسية',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final a in alerts)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: a.color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: a.color.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: a.color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Icon(a.icon, color: a.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: a.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(a.type,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.headline, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(a.action, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'high':
        return core_theme.AC.err;
      case 'medium':
        return core_theme.AC.warn;
      case 'low':
        return core_theme.AC.ok;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _riskIcon(String level) {
    switch (level) {
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.error_outline;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _riskLabel(String level) {
    switch (level) {
      case 'high':
        return 'عالٍ';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return level;
    }
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Bar {
  final String label;
  final double current;
  final double prior;
  const _Bar(this.label, this.current, this.prior);
}

class _Seg {
  final String name;
  final double value;
  final Color color;
  const _Seg(this.name, this.value, this.color);
}

class _Risk {
  final String name;
  final String level;
  final String note;
  const _Risk(this.name, this.level, this.note);
}

class _Init {
  final String name;
  final int progress;
  final String target;
  final Color color;
  const _Init(this.name, this.progress, this.target, this.color);
}

class _Alert {
  final String type;
  final String headline;
  final String action;
  final Color color;
  final IconData icon;
  const _Alert(this.type, this.headline, this.action, this.color, this.icon);
}
