/// APEX Wave 48 — Audit Engagement Planning.
/// Route: /app/audit/engagement/planning
///
/// ISA 300 / SOCPA-aligned audit planning with risk
/// assessment, materiality setting, and audit strategy.
library;

import 'package:flutter/material.dart';

class AuditPlanningScreen extends StatefulWidget {
  const AuditPlanningScreen({super.key});
  @override
  State<AuditPlanningScreen> createState() => _AuditPlanningScreenState();
}

class _AuditPlanningScreenState extends State<AuditPlanningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  double _materialityPct = 5.0;
  double _performanceThreshold = 75.0;
  String _engagementType = 'financial';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildProgressRow(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF4A148C),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.business, size: 16), text: 'فهم المنشأة'),
            Tab(icon: Icon(Icons.warning, size: 16), text: 'تقييم المخاطر'),
            Tab(icon: Icon(Icons.straighten, size: 16), text: 'الأهمية النسبية'),
            Tab(icon: Icon(Icons.timeline, size: 16), text: 'استراتيجية المراجعة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildUnderstandingTab(),
              _buildRisksTab(),
              _buildMaterialityTab(),
              _buildStrategyTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_calendar, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تخطيط الارتباط — SABIC Ltd.',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('ISA 300 · SOCPA معيار (315) · للسنة المنتهية 2025-12-31',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('فترة التخطيط: 2026-01', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _progressCard('فهم المنشأة', 1.0, Colors.green, Icons.check_circle),
          _progressCard('تقييم المخاطر', 0.70, Colors.orange, Icons.sync),
          _progressCard('الأهمية النسبية', 0.40, Colors.blue, Icons.sync),
          _progressCard('الاستراتيجية', 0.10, Colors.grey, Icons.pending),
        ],
      ),
    );
  }

  Widget _progressCard(String label, double progress, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderstandingTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _section(
          'معلومات عامة عن العميل',
          Icons.info,
          Colors.blue,
          [
            _kv('الاسم التجاري', 'الشركة السعودية للصناعات الأساسية (سابك)'),
            _kv('السجل التجاري', '1010004000'),
            _kv('الرقم الضريبي', '300001234500003'),
            _kv('القطاع', 'البتروكيماويات'),
            _kv('نوع المنشأة', 'شركة مساهمة مدرجة — تداول'),
            _kv('عدد الفروع', '14 فرع داخل المملكة + 8 دول'),
          ],
        ),
        const SizedBox(height: 12),
        _section(
          'البيئة التشغيلية',
          Icons.factory,
          Colors.teal,
          [
            _kv('المجال', 'إنتاج وتسويق المنتجات البتروكيماوية والأسمدة والمعادن'),
            _kv('المنتجات الرئيسية', 'إيثيلين، بروبيلين، ميثانول، MEG، البولي بروبلين'),
            _kv('العملاء الرئيسيون', 'شركات صناعية محلية ودولية — 45% صادرات'),
            _kv('المنافسة', 'سوق عالمي — ضغط من آسيا والمنافسين المحليين'),
            _kv('اللوائح الرقابية', 'هيئة السوق المالية، البيئة، الدفاع المدني'),
          ],
        ),
        const SizedBox(height: 12),
        _section(
          'نظام الرقابة الداخلية',
          Icons.security,
          Colors.purple,
          [
            _kv('إطار الحوكمة', 'مجلس إدارة + 5 لجان (مراجعة، مخاطر، مكافآت، حوكمة، استثمار)'),
            _kv('لجنة المراجعة', '5 أعضاء — 3 مستقلين — 4 مالي معتمد'),
            _kv('المراجعة الداخلية', 'قسم مستقل — 28 موظف — يرفع للجنة المراجعة'),
            _kv('نظام تقنية المعلومات', 'SAP S/4HANA + Oracle EPM — منفصل عن بيئة الإنتاج'),
            _kv('تقييم الضوابط', 'COSO 2013 — اختبار سنوي مستقل'),
          ],
        ),
      ],
    );
  }

  Widget _buildRisksTab() {
    final risks = const [
      _Risk('R-001', 'خطر الاحتيال في الإيرادات', 'جوهري', 'عالٍ', 'عالٍ', 'اختبارات تحليلية مفصّلة + عيّنات موسّعة من عقود طويلة'),
      _Risk('R-002', 'تقييم المخزون', 'جوهري', 'متوسط', 'عالٍ', 'حضور الجرد المادي + اختبار معدلات الدوران والإهلاك'),
      _Risk('R-003', 'الالتزامات الضريبية (ZATCA)', 'مهم', 'متوسط', 'متوسط', 'فحص الإقرارات + مراجعة مستشار ضريبي'),
      _Risk('R-004', 'ترجمة العملات الأجنبية', 'مهم', 'منخفض', 'متوسط', 'إعادة احتساب + تأكيد الأسعار من بلومبيرغ'),
      _Risk('R-005', 'تقييم الأصول المستهلكة', 'عادي', 'منخفض', 'منخفض', 'فحص عينة من جداول الإهلاك + التحقق من العمر الإنتاجي'),
      _Risk('R-006', 'اعتراف الإيرادات من عقود طويلة الأجل', 'جوهري', 'عالٍ', 'عالٍ', 'IFRS 15 — فحص 100% من العقود > 50 مليون'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: risks.length,
      itemBuilder: (ctx, i) {
        final r = risks[i];
        final severity = r.severity == 'جوهري' ? Colors.red : r.severity == 'مهم' ? Colors.orange : Colors.green;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: severity.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: severity.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(r.id, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: severity, fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: severity,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(r.severity, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _riskMetric('احتمال الحدوث', r.likelihood),
                  const SizedBox(width: 10),
                  _riskMetric('الأثر', r.impact),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 6),
                    const Text('الاستجابة المخططة: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    Expanded(child: Text(r.response, style: const TextStyle(fontSize: 12, height: 1.4))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _riskMetric(String label, String level) {
    final color = level == 'عالٍ' ? Colors.red : level == 'متوسط' ? Colors.orange : Colors.green;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const Spacer(),
            Text(level, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialityTab() {
    const revenue = 185000000.0;
    final planning = revenue * (_materialityPct / 100);
    final performance = planning * (_performanceThreshold / 100);
    final clearlyTrivial = planning * 0.05;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طبقاً لـ ISA 320، الأهمية النسبية للتخطيط تُحسب كنسبة من رقم مرجعي (عادةً الإيرادات أو مجمل الربح). لا تتجاوز 5% من الإيرادات للشركات المدرجة.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('القيم المرجعية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _kv('إيرادات الشركة للسنة المالية', '${_fmt(revenue)} ر.س'),
              _kv('مجمل الربح', '${_fmt(revenue * 0.28)} ر.س'),
              _kv('صافي الربح', '${_fmt(revenue * 0.12)} ر.س'),
              _kv('إجمالي الأصول', '${_fmt(revenue * 2.8)} ر.س'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نسبة الأهمية النسبية المختارة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _materialityPct,
                      min: 1,
                      max: 10,
                      divisions: 18,
                      label: '${_materialityPct.toStringAsFixed(1)}%',
                      onChanged: (v) => setState(() => _materialityPct = v),
                      activeColor: const Color(0xFF4A148C),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${_materialityPct.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('عتبة الأداء (Performance)', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _performanceThreshold,
                      min: 50,
                      max: 90,
                      divisions: 8,
                      label: '${_performanceThreshold.toStringAsFixed(0)}%',
                      onChanged: (v) => setState(() => _performanceThreshold = v),
                      activeColor: const Color(0xFFD4AF37),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${_performanceThreshold.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF3D0F73)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Text('النتائج المحسوبة', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              _resultLine('الأهمية النسبية للتخطيط', planning, const Color(0xFFFFD700)),
              const Divider(color: Colors.white24),
              _resultLine('عتبة الأداء', performance, Colors.white),
              const Divider(color: Colors.white24),
              _resultLine('الخطأ التافه الواضح', clearlyTrivial, Colors.white70),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultLine(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          Row(
            children: [
              Text(_fmt(value), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'monospace')),
              const SizedBox(width: 4),
              const Text('ر.س', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyTab() {
    final phases = const [
      _Phase(1, 'المرحلة الأولى — الارتباط والقبول', '2026-01-05', '2026-01-15', 40, 'مكتمل'),
      _Phase(2, 'المرحلة الثانية — التخطيط والتقييم', '2026-01-16', '2026-02-05', 120, 'قيد التنفيذ'),
      _Phase(3, 'المرحلة الثالثة — الإجراءات التحليلية الأولية', '2026-02-06', '2026-02-20', 80, 'قادم'),
      _Phase(4, 'المرحلة الرابعة — اختبار الضوابط', '2026-02-21', '2026-03-10', 160, 'قادم'),
      _Phase(5, 'المرحلة الخامسة — الفحوصات الجوهرية', '2026-03-11', '2026-04-20', 240, 'قادم'),
      _Phase(6, 'المرحلة السادسة — الإغلاق والتقرير', '2026-04-21', '2026-05-15', 80, 'قادم'),
    ];
    final totalHours = phases.fold(0, (s, p) => s + p.hours);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              _strategyStat('إجمالي الساعات', '$totalHours', const Color(0xFFD4AF37)),
              _strategyStat('عدد المراحل', '${phases.length}', Colors.blue),
              _strategyStat('تاريخ البدء', '2026-01-05', Colors.green),
              _strategyStat('تاريخ الإنتهاء', '2026-05-15', Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('الجدول الزمني للارتباط', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (final p in phases)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _phaseColor(p.status).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _phaseColor(p.status).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text('${p.number}', style: TextStyle(color: _phaseColor(p.status), fontWeight: FontWeight.w900, fontSize: 18))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${p.fromDate} → ${p.toDate}',
                          style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.hours} ساعة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _phaseColor(p.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(p.status, style: TextStyle(fontSize: 11, color: _phaseColor(p.status), fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _phaseColor(String status) {
    switch (status) {
      case 'مكتمل':
        return Colors.green;
      case 'قيد التنفيذ':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _strategyStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color, List<Widget> children) {
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
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(k, style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.5))),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Risk {
  final String id;
  final String title;
  final String severity;
  final String likelihood;
  final String impact;
  final String response;
  const _Risk(this.id, this.title, this.severity, this.likelihood, this.impact, this.response);
}

class _Phase {
  final int number;
  final String title;
  final String fromDate;
  final String toDate;
  final int hours;
  final String status;
  const _Phase(this.number, this.title, this.fromDate, this.toDate, this.hours, this.status);
}
