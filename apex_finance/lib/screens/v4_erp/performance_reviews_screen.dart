/// APEX Wave 93 — Performance Reviews (360°).
/// Route: /app/erp/hr/performance
///
/// Annual performance cycles with OKRs, competencies, 360 feedback.
library;

import 'package:flutter/material.dart';

class PerformanceReviewsScreen extends StatefulWidget {
  const PerformanceReviewsScreen({super.key});
  @override
  State<PerformanceReviewsScreen> createState() => _PerformanceReviewsScreenState();
}

class _PerformanceReviewsScreenState extends State<PerformanceReviewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _selectedEmp = 'EMP-002';

  final _employees = const [
    _EmpReview('EMP-001', 'أحمد محمد العتيبي', 'CFO', 4.8, 5, 'exceeds', '2025', Colors.green),
    _EmpReview('EMP-002', 'سارة الدوسري', 'مدير مراجعة داخلية', 4.6, 5, 'exceeds', '2025', Colors.green),
    _EmpReview('EMP-003', 'محمد القحطاني', 'مدير مشاريع', 4.2, 4, 'meets', '2025', Colors.blue),
    _EmpReview('EMP-004', 'نورة الغامدي', 'محللة ضرائب', 4.5, 4, 'meets', '2025', Colors.blue),
    _EmpReview('EMP-005', 'فهد الشمري', 'محاسب', 3.2, 3, 'needs-improvement', '2025', Colors.orange),
    _EmpReview('EMP-006', 'لينا البكري', 'مدير HR', 4.7, 5, 'exceeds', '2025', Colors.green),
    _EmpReview('EMP-007', 'راشد العنزي', 'مدير تقنية', 4.4, 4, 'meets', '2025', Colors.blue),
    _EmpReview('EMP-008', 'ياسر العنزي', 'مسؤول مشتريات', 3.8, 4, 'meets', '2025', Colors.blue),
  ];

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

  _EmpReview get _selected => _employees.firstWhere((e) => e.id == _selectedEmp);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 320, child: _buildSidebar()),
        Expanded(
          child: Column(
            children: [
              _buildHero(),
              TabBar(
                controller: _tab,
                labelColor: const Color(0xFFD4AF37),
                unselectedLabelColor: Colors.black54,
                indicatorColor: const Color(0xFFD4AF37),
                tabs: const [
                  Tab(icon: Icon(Icons.star, size: 16), text: 'التقييم الشامل'),
                  Tab(icon: Icon(Icons.flag, size: 16), text: 'الأهداف'),
                  Tab(icon: Icon(Icons.groups, size: 16), text: 'تقييم 360°'),
                  Tab(icon: Icon(Icons.trending_up, size: 16), text: 'التطوير'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildOverallTab(),
                    _buildGoalsTab(),
                    _build360Tab(),
                    _buildDevelopmentTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 20, bottom: 20, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.grey.shade50,
            child: const Row(
              children: [
                Icon(Icons.people, color: Color(0xFFD4AF37), size: 18),
                SizedBox(width: 8),
                Text('الموظفون', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _employees.length,
              itemBuilder: (ctx, i) {
                final e = _employees[i];
                final selected = e.id == _selectedEmp;
                return InkWell(
                  onTap: () => setState(() => _selectedEmp = e.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFD4AF37).withOpacity(0.12) : null,
                      border: Border(
                        bottom: BorderSide(color: Colors.black12.withOpacity(0.5)),
                        right: BorderSide(
                          color: selected ? const Color(0xFFD4AF37) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: e.color.withOpacity(0.12),
                          radius: 16,
                          child: Text(e.name.substring(0, 1),
                              style: TextStyle(color: e.color, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(e.title, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, size: 12, color: Color(0xFFFFD700)),
                                Text(e.rating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: e.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                              child: Text(_tierLabel(e.tier),
                                  style: TextStyle(fontSize: 9, color: e.color, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final e = _selected;
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 20, right: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [e.color, e.color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Text(e.name.substring(0, 2),
                style: TextStyle(color: e.color, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('${e.title} · ${e.id} · تقييم ${e.cycleYear}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 24),
                  Text(e.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: Text(_tierLabel(e.tier),
                    style: TextStyle(color: e.color, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallTab() {
    final competencies = const [
      _Competency('التميّز التقني', 4.8, 'خبرة عميقة ومؤثرة في المجال'),
      _Competency('القيادة والتأثير', 4.6, 'قدوة للفريق وملهِم'),
      _Competency('التواصل والتعاون', 4.7, 'تواصل فعّال مع جميع المستويات'),
      _Competency('التفكير الاستراتيجي', 4.5, 'يربط الأنشطة برؤية الشركة'),
      _Competency('التنفيذ وتحقيق النتائج', 4.8, 'ينجز المهام بجودة وسرعة'),
      _Competency('الابتكار وحلّ المشكلات', 4.4, 'يقترح حلولاً إبداعية'),
      _Competency('التطوير المهني', 4.6, 'يستثمر في تعلّم مستمر'),
    ];
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تقييم الكفاءات الأساسية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              for (final c in competencies)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= c.rating.floor()
                                  ? Icons.star
                                  : i == c.rating.ceil() && c.rating % 1 != 0
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: const Color(0xFFFFD700),
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Text(c.rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(c.comment, style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsTab() {
    final goals = const [
      _Goal('أتمتة 80% من إقرارات VAT', 85, 80, 'completed', Colors.green),
      _Goal('تطوير 3 أعضاء فريق إلى ترقيات', 3, 3, 'completed', Colors.green),
      _Goal('اعتماد شهادة CMA قبل Q3', 100, 100, 'completed', Colors.green),
      _Goal('تقليل زمن إقفال الشهر إلى 5 أيام', 7, 5, 'partial', Colors.orange),
      _Goal('تنفيذ 5 مشاريع تحسين عمليات', 4, 5, 'partial', Colors.orange),
      _Goal('حضور 48 ساعة تدريبية', 42, 48, 'partial', Colors.orange),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      itemCount: goals.length,
      itemBuilder: (ctx, i) {
        final g = goals[i];
        final pct = g.target > 0 ? (g.actual / g.target).clamp(0.0, 1.0) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: g.color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_goalIcon(g.status), color: g.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(g.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: g.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(_goalLabel(g.status),
                        style: TextStyle(fontSize: 11, color: g.color, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(g.color),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${g.actual} / ${g.target}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: g.color)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build360Tab() {
    final reviewers = const [
      _Reviewer('أحمد العتيبي', 'المدير المباشر', 4.7, 'أداء متميز ومساهمة ملحوظة في تحسين العمليات'),
      _Reviewer('سارة الدوسري', 'زميلة', 4.8, 'تعاون ممتاز وقيادة فريق نموذجية'),
      _Reviewer('فهد الشمري', 'تابع مباشر', 4.9, 'أفضل مدير أعمل معه — داعم ومُلهِم'),
      _Reviewer('نورة الغامدي', 'زميلة', 4.5, 'قوية تقنياً ومتعاونة'),
      _Reviewer('محمد القحطاني', 'فريق متقاطع', 4.6, 'تواصل فعّال وتنفيذ دقيق'),
      _Reviewer('تقييم ذاتي', '—', 4.3, 'حققت معظم الأهداف، أطمح لتطوير مهارات قيادية أكثر'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      itemCount: reviewers.length,
      itemBuilder: (ctx, i) {
        final r = reviewers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.12),
                child: Text(r.name.substring(0, 1),
                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(r.relationship, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(r.comment,
                        style: const TextStyle(fontSize: 12, height: 1.6, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= r.rating.floor()
                              ? Icons.star
                              : i == r.rating.ceil() && r.rating % 1 != 0
                                  ? Icons.star_half
                                  : Icons.star_border,
                          color: const Color(0xFFFFD700),
                          size: 16,
                        ),
                    ],
                  ),
                  Text(r.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDevelopmentTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        _section(
          '✨ نقاط القوة',
          Colors.green,
          const [
            'خبرة تقنية عميقة ومعرفة متنوعة',
            'مهارات قيادية قوية وقدرة على الإلهام',
            'التزام بالجودة والتميّز في التنفيذ',
            'تواصل فعّال على جميع المستويات',
            'تعلّم مستمر وتطوير ذاتي',
          ],
        ),
        const SizedBox(height: 12),
        _section(
          '🎯 مجالات التطوير',
          Colors.orange,
          const [
            'التفويض للفريق — تقليل التفاصيل الدقيقة',
            'استراتيجية بعيدة المدى (5+ سنوات)',
            'مهارات التفاوض التجاري العالي',
            'توسيع الشبكة الصناعية خارج المنشأة',
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, color: Color(0xFFD4AF37)),
                  SizedBox(width: 8),
                  Text('خطة التطوير الفردية — 2026',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 14),
              _devItem('تدريب قيادي', 'Harvard Executive Leadership Program (4 أسابيع)', 'Q2 2026'),
              _devItem('مهارة جديدة', 'شهادة PMP', 'Q3 2026'),
              _devItem('إرشاد (Mentoring)', 'جلسات أسبوعية مع مدير تنفيذي خارجي', 'مستمر'),
              _devItem('تعيين ممتد', 'قيادة مشروع تحوّل رقمي عابر للإدارات', 'Q3-Q4 2026'),
              _devItem('مؤتمر صناعي', 'حضور 2 مؤتمر دولي في المجال المالي', '2026'),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.celebration, color: Colors.pink),
                  SizedBox(width: 8),
                  Text('المسار الوظيفي المقترح',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('الترشيح للترقية إلى "Senior Director" خلال 2026-Q4 بناءً على الأداء الاستثنائي وخطة التطوير.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, Color color, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 12, height: 1.6))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _devItem(String category, String detail, String timeline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(category,
                style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37), fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(detail, style: const TextStyle(fontSize: 12))),
          Text(timeline, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 5:
        return 'متميّز';
      case 4:
        return 'يلبّي';
      case 3:
        return 'مقبول';
      case 2:
        return 'تحت التوقّعات';
      case 1:
        return 'غير مقبول';
      default:
        return '—';
    }
  }

  IconData _goalIcon(String s) {
    switch (s) {
      case 'completed':
        return Icons.check_circle;
      case 'partial':
        return Icons.hourglass_empty;
      case 'missed':
        return Icons.cancel;
      default:
        return Icons.flag;
    }
  }

  String _goalLabel(String s) {
    switch (s) {
      case 'completed':
        return 'مكتمل';
      case 'partial':
        return 'جزئي';
      case 'missed':
        return 'غير محقق';
      default:
        return s;
    }
  }
}

class _EmpReview {
  final String id;
  final String name;
  final String title;
  final double rating;
  final int tier;
  final String status;
  final String cycleYear;
  final Color color;
  const _EmpReview(this.id, this.name, this.title, this.rating, this.tier, this.status, this.cycleYear, this.color);
}

class _Competency {
  final String name;
  final double rating;
  final String comment;
  const _Competency(this.name, this.rating, this.comment);
}

class _Goal {
  final String title;
  final int actual;
  final int target;
  final String status;
  final Color color;
  const _Goal(this.title, this.actual, this.target, this.status, this.color);
}

class _Reviewer {
  final String name;
  final String relationship;
  final double rating;
  final String comment;
  const _Reviewer(this.name, this.relationship, this.rating, this.comment);
}
