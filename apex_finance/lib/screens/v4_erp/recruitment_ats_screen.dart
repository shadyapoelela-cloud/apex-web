/// APEX Wave 95 — Recruitment / Applicant Tracking System.
/// Route: /app/erp/hr/recruitment
///
/// Open positions, candidate pipeline, interviews, offers.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class RecruitmentAtsScreen extends StatefulWidget {
  const RecruitmentAtsScreen({super.key});
  @override
  State<RecruitmentAtsScreen> createState() => _RecruitmentAtsScreenState();
}

class _RecruitmentAtsScreenState extends State<RecruitmentAtsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _positions = const [
    _Position('JOB-2026-042', 'محاسب أول — مشاريع كبرى', 'المالية', 'full-time', 'published', 18, 4, 'الرياض', 15000),
    _Position('JOB-2026-041', 'محلل أمن سيبراني', 'التقنية', 'full-time', 'published', 24, 6, 'الرياض', 18000),
    _Position('JOB-2026-040', 'مدير تدقيق داخلي', 'المراجعة', 'full-time', 'interviewing', 32, 8, 'جدة', 28000),
    _Position('JOB-2026-039', 'متدرب صيفي — محاسبة', 'المالية', 'internship', 'published', 156, 42, 'الرياض', 3000),
    _Position('JOB-2026-038', 'أخصائي ضرائب', 'الامتثال', 'full-time', 'offer', 12, 3, 'الرياض', 16000),
    _Position('JOB-2026-037', 'مطوّر Flutter', 'التقنية', 'full-time', 'hired', 45, 12, 'Remote', 22000),
    _Position('JOB-2026-036', 'مدير مبيعات إقليمي', 'المبيعات', 'full-time', 'published', 28, 5, 'دبي', 24000),
    _Position('JOB-2026-035', 'مساعد إداري', 'العمليات', 'full-time', 'paused', 8, 2, 'الرياض', 8000),
  ];

  final _candidates = [
    _Candidate('CAN-2026-0284', 'ياسر الحربي', 'JOB-2026-042', 5, 'محاسبة', 4.8, 'offer', '2020', core_theme.AC.ok),
    _Candidate('CAN-2026-0283', 'رنا المطيري', 'JOB-2026-040', 8, 'مراجعة CPA', 4.9, 'final', '2018', core_theme.AC.ok),
    _Candidate('CAN-2026-0282', 'خالد الحربي', 'JOB-2026-040', 6, 'مراجعة', 4.7, 'interview', '2019', core_theme.AC.info),
    _Candidate('CAN-2026-0281', 'نورة الغامدي', 'JOB-2026-041', 3, 'ISC2, CEH', 4.5, 'interview', '2022', core_theme.AC.info),
    _Candidate('CAN-2026-0280', 'فهد القحطاني', 'JOB-2026-041', 4, 'CISSP', 4.6, 'screening', '2021', core_theme.AC.warn),
    _Candidate('CAN-2026-0279', 'سارة البكري', 'JOB-2026-042', 2, 'ACCA Part-qualified', 3.8, 'screening', '2023', core_theme.AC.warn),
    _Candidate('CAN-2026-0278', 'محمد العتيبي', 'JOB-2026-036', 7, 'مبيعات تقنية', 4.4, 'interview', '2019', core_theme.AC.info),
    _Candidate('CAN-2026-0277', 'لينا سالم', 'JOB-2026-042', 4, 'محاسبة', 4.2, 'sourced', '2021', core_theme.AC.td),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.work, size: 16), text: 'الشواغر'),
            Tab(icon: Icon(Icons.person_search, size: 16), text: 'المرشحون'),
            Tab(icon: Icon(Icons.view_kanban, size: 16), text: 'خط الأنابيب'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildPositionsTab(),
              _buildCandidatesTab(),
              _buildPipelineTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التوظيف وتتبع المرشحين',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('ATS — شواغر · مرشحون · مقابلات · عروض · متابعة مع Seek + LinkedIn',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: Text('شاغر جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00695C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final open = _positions.where((p) => p.status == 'published' || p.status == 'interviewing' || p.status == 'offer').length;
    final totalApps = _positions.fold(0, (s, p) => s + p.applications);
    final inProcess = _candidates.where((c) => c.stage != 'sourced' && c.stage != 'hired' && c.stage != 'rejected').length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('شواغر مفتوحة', '$open', core_theme.AC.info, Icons.work),
          _kpi('إجمالي المتقدمين', '$totalApps', core_theme.AC.gold, Icons.people),
          _kpi('قيد المعالجة', '$inProcess', core_theme.AC.warn, Icons.sync),
          _kpi('متوسط زمن التوظيف', '28 يوم', core_theme.AC.ok, Icons.schedule),
          _kpi('نسبة القبول', '68%', core_theme.AC.info, Icons.thumb_up),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _positions.length,
      itemBuilder: (ctx, i) {
        final p = _positions[i];
        final sColor = _posStatusColor(p.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.work, color: sColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: sColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                          child: Text(_posStatusLabel(p.status),
                              style: TextStyle(fontSize: 10, color: sColor, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: core_theme.AC.bdr, borderRadius: BorderRadius.circular(3)),
                          child: Text(_typeLabel(p.type),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Icon(Icons.business, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text(p.department, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        const SizedBox(width: 10),
                        Icon(Icons.place, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text(p.location, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        const SizedBox(width: 10),
                        Icon(Icons.payments, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text('${p.salary} ر.س/شهر', style: TextStyle(fontSize: 11, color: core_theme.AC.gold, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${p.applications}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
                  Text('متقدم', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  const SizedBox(height: 4),
                  Text('${p.shortlisted} في القائمة القصيرة',
                      style: TextStyle(fontSize: 10, color: core_theme.AC.info, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCandidatesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _candidates.length,
      itemBuilder: (ctx, i) {
        final c = _candidates[i];
        final position = _positions.firstWhere((p) => p.id == c.positionId, orElse: () => _positions.first);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.color.withOpacity(0.15),
                child: Text(c.name.substring(0, 1),
                    style: TextStyle(color: c.color, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                        const SizedBox(width: 8),
                        Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text('→ ${position.title}',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    Row(
                      children: [
                        Icon(Icons.school, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text(c.qualifications, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        const SizedBox(width: 10),
                        Icon(Icons.business_center, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text('${c.experience} سنوات خبرة',
                            style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Color(0xFFFFD700)),
                        Text(' ${c.rating}/5', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _stageBadge(c.stage),
                  ],
                ),
              ),
              if (c.stage == 'interview' || c.stage == 'final')
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.event, size: 14),
                  label: Text('حجز مقابلة', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: core_theme.AC.info,
                    foregroundColor: Colors.white,
                  ),
                )
              else if (c.stage == 'offer')
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.email, size: 14),
                  label: Text('إرسال عرض', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: core_theme.AC.gold,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _stageBadge(String stage) {
    final color = _stageColor(stage);
    final label = _stageLabel(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildPipelineTab() {
    final stages = [
      _Stage('sourced', 'مرشّح مستهدف', core_theme.AC.td),
      _Stage('screening', 'فرز أولي', core_theme.AC.warn),
      _Stage('interview', 'مقابلة', core_theme.AC.info),
      _Stage('final', 'مقابلة نهائية', core_theme.AC.purple),
      _Stage('offer', 'عرض توظيف', core_theme.AC.gold),
      _Stage('hired', 'تم التعيين', core_theme.AC.ok),
    ];
    return SizedBox(
      height: 520,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            for (final stage in stages)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: core_theme.AC.navy3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: core_theme.AC.bdr),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: stage.color.withOpacity(0.12),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(stage.name,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: stage.color)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: stage.color, borderRadius: BorderRadius.circular(10)),
                              child: Text('${_candidates.where((c) => c.stage == stage.id).length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(6),
                          children: [
                            for (final c in _candidates.where((c) => c.stage == stage.id))
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: core_theme.AC.bdr),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text('${c.experience}س · ⭐${c.rating}',
                                        style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _posStatusColor(String s) {
    switch (s) {
      case 'published':
        return core_theme.AC.info;
      case 'interviewing':
        return core_theme.AC.warn;
      case 'offer':
        return core_theme.AC.gold;
      case 'hired':
        return core_theme.AC.ok;
      case 'paused':
        return core_theme.AC.td;
      default:
        return core_theme.AC.td;
    }
  }

  String _posStatusLabel(String s) {
    switch (s) {
      case 'published':
        return 'منشور';
      case 'interviewing':
        return 'مقابلات';
      case 'offer':
        return 'عرض نهائي';
      case 'hired':
        return 'تم التعيين';
      case 'paused':
        return 'متوقف';
      default:
        return s;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'full-time':
        return 'دوام كامل';
      case 'part-time':
        return 'جزئي';
      case 'internship':
        return 'تدريب';
      case 'contract':
        return 'عقد';
      default:
        return t;
    }
  }

  Color _stageColor(String s) {
    switch (s) {
      case 'sourced':
        return core_theme.AC.td;
      case 'screening':
        return core_theme.AC.warn;
      case 'interview':
        return core_theme.AC.info;
      case 'final':
        return core_theme.AC.purple;
      case 'offer':
        return core_theme.AC.gold;
      case 'hired':
        return core_theme.AC.ok;
      case 'rejected':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _stageLabel(String s) {
    switch (s) {
      case 'sourced':
        return 'مستهدف';
      case 'screening':
        return 'فرز';
      case 'interview':
        return 'مقابلة';
      case 'final':
        return 'نهائي';
      case 'offer':
        return 'عرض';
      case 'hired':
        return 'عُيّن';
      case 'rejected':
        return 'مرفوض';
      default:
        return s;
    }
  }
}

class _Position {
  final String id;
  final String title;
  final String department;
  final String type;
  final String status;
  final int applications;
  final int shortlisted;
  final String location;
  final int salary;
  const _Position(this.id, this.title, this.department, this.type, this.status, this.applications, this.shortlisted, this.location, this.salary);
}

class _Candidate {
  final String id;
  final String name;
  final String positionId;
  final int experience;
  final String qualifications;
  final double rating;
  final String stage;
  final String graduationYear;
  final Color color;
  const _Candidate(this.id, this.name, this.positionId, this.experience, this.qualifications, this.rating, this.stage, this.graduationYear, this.color);
}

class _Stage {
  final String id;
  final String name;
  final Color color;
  const _Stage(this.id, this.name, this.color);
}
