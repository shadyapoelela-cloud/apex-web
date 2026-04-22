/// APEX Wave 84 — Training / Learning Management System.
/// Route: /app/erp/hr/training
///
/// Employee training catalog, enrollment, and compliance tracking.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class TrainingLmsScreen extends StatefulWidget {
  const TrainingLmsScreen({super.key});
  @override
  State<TrainingLmsScreen> createState() => _TrainingLmsScreenState();
}

class _TrainingLmsScreenState extends State<TrainingLmsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _courses = const [
    _Course('CRS-001', 'مكافحة غسل الأموال — تدريب إلزامي', 'الامتثال', 120, 'إلزامي', 4.8, 285, true),
    _Course('CRS-002', 'IFRS 15 — الاعتراف بالإيرادات', 'المحاسبة', 180, 'اختياري', 4.9, 142, false),
    _Course('CRS-003', 'ZATCA Phase 2 — الفوترة الإلكترونية', 'الضرائب', 90, 'إلزامي', 4.7, 198, true),
    _Course('CRS-004', 'سياسات الأمن السيبراني', 'التقنية', 60, 'إلزامي', 4.6, 320, true),
    _Course('CRS-005', 'مهارات القيادة للمديرين', 'القيادة', 480, 'اختياري', 4.8, 45, false),
    _Course('CRS-006', 'التميّز في خدمة العملاء', 'مهارات شخصية', 150, 'اختياري', 4.7, 156, false),
    _Course('CRS-007', 'تحليل البيانات بـ Excel', 'تقني', 240, 'اختياري', 4.5, 198, false),
    _Course('CRS-008', 'أسس إدارة المخاطر (COSO)', 'الحوكمة', 180, 'موصى به', 4.8, 68, false),
    _Course('CRS-009', 'التفكير التصميمي للابتكار', 'ابتكار', 360, 'اختياري', 4.9, 38, false),
    _Course('CRS-010', 'الإسعافات الأوّلية والسلامة', 'سلامة', 120, 'إلزامي', 4.6, 340, true),
    _Course('CRS-011', 'نظام العمل السعودي', 'الموارد البشرية', 150, 'إلزامي', 4.7, 285, true),
    _Course('CRS-012', 'مهارات العرض والتقديم', 'مهارات شخصية', 180, 'اختياري', 4.8, 92, false),
  ];

  final _myTraining = const [
    _MyTraining('CRS-001', 'مكافحة غسل الأموال', 100, 'مكتمل', '2026-01-15', 'A+', true),
    _MyTraining('CRS-003', 'ZATCA Phase 2', 100, 'مكتمل', '2026-02-20', 'A', true),
    _MyTraining('CRS-004', 'الأمن السيبراني', 75, 'قيد التقدّم', null, null, false),
    _MyTraining('CRS-002', 'IFRS 15', 45, 'قيد التقدّم', null, null, false),
    _MyTraining('CRS-008', 'إدارة المخاطر', 20, 'بدء جديد', null, null, false),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildMyStats(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.school, size: 16), text: 'تدريبي'),
            Tab(icon: Icon(Icons.library_books, size: 16), text: 'كتالوج الدورات'),
            Tab(icon: Icon(Icons.assignment, size: 16), text: 'إلزامية'),
            Tab(icon: Icon(Icons.card_membership, size: 16), text: 'الشهادات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildMyTrainingTab(),
              _buildCatalogTab(),
              _buildMandatoryTab(),
              _buildCertificatesTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00838F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.school, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الأكاديمية',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('نظام التعلّم والتطوير · 128 دورة · شهادات معتمدة · متابعة الإلزامي',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard('ساعات تدريبي السنوية', '42h', 'من 48h المستهدفة', 0.88, core_theme.AC.info),
          _statCard('دورات مكتملة', '12', 'آخرها: ZATCA Phase 2', null, core_theme.AC.ok),
          _statCard('قيد التقدّم', '3', 'نسبة الإنجاز 47%', 0.47, core_theme.AC.warn),
          _statCard('الشهادات النشطة', '8', 'منها 3 معتمدة دولياً', null, core_theme.AC.gold),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String note, double? progress, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(note, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            if (progress != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: core_theme.AC.bdr,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyTrainingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myTraining.length,
      itemBuilder: (ctx, i) {
        final t = _myTraining[i];
        final course = _courses.firstWhere((c) => c.id == t.courseId, orElse: () => _courses.first);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.completed ? core_theme.AC.ok.withOpacity(0.3) : core_theme.AC.info.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (t.completed ? core_theme.AC.ok : core_theme.AC.info).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(t.completed ? Icons.emoji_events : Icons.play_circle,
                    color: t.completed ? core_theme.AC.ok : core_theme.AC.info, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('${course.category} · ${course.minutes} دقيقة',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: t.progress / 100,
                      backgroundColor: core_theme.AC.bdr,
                      valueColor: AlwaysStoppedAnimation(
                          t.progress == 100 ? core_theme.AC.ok : core_theme.AC.info),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 4),
                    Text('${t.progress}% — ${t.status}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (t.grade != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: core_theme.AC.ok, borderRadius: BorderRadius.circular(8)),
                  child: Text(t.grade!,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 8),
                Text(t.completedAt ?? '',
                    style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
              ] else
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: Text('متابعة', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: core_theme.AC.info,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in _courses) _courseCard(c),
          ],
        ),
      ],
    );
  }

  Widget _courseCard(_Course c) {
    final catColor = _catColor(c.category);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(c.category,
                    style: TextStyle(fontSize: 9, color: catColor, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (c.mandatory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: core_theme.AC.err.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                  child: Text('إلزامي',
                      style: TextStyle(fontSize: 9, color: core_theme.AC.err, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text('${c.minutes} دقيقة',
                  style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              const Spacer(),
              const Icon(Icons.star, size: 12, color: Color(0xFFFFD700)),
              Text(' ${c.rating}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.people, size: 12, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text('${c.enrolled} مسجّل', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: core_theme.AC.gold,
                  side: BorderSide(color: core_theme.AC.gold),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                child: Text('التسجيل', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMandatoryTab() {
    final mandatory = _courses.where((c) => c.mandatory).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.err,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.err),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: core_theme.AC.err),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'هذه الدورات إلزامية لجميع الموظفين حسب السياسات الداخلية وأنظمة الامتثال. يجب إكمالها خلال 30 يوم من الانضمام أو خلال فترة التجديد السنوي.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final c in mandatory)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.err),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: core_theme.AC.err.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.priority_high, color: core_theme.AC.err),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      Text('${c.category} · ${c.minutes} دقيقة',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('آخر موعد', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    Text('2026-05-31',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.err, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: core_theme.AC.err,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('ابدأ الآن'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCertificatesTab() {
    final certs = const [
      _Cert('CPA — محاسب قانوني معتمد', 'AICPA', '2022-06', '2028-06', true, 'ساري'),
      _Cert('CMA — محاسب إداري معتمد', 'IMA', '2020-09', '2026-09', true, 'ساري'),
      _Cert('CFA Level II', 'CFA Institute', '2023-08', 'غير متطلّب', true, 'ساري'),
      _Cert('PMP — إدارة المشاريع', 'PMI', '2021-03', '2027-03', true, 'ساري'),
      _Cert('ITIL Foundation', 'AXELOS', '2019-11', 'مدى الحياة', true, 'ساري'),
      _Cert('COSO ERM', 'COSO', '2023-04', '2028-04', true, 'ساري'),
      _Cert('CISA — مراجع نظم', 'ISACA', '2020-02', '2026-02', false, 'منتهٍ'),
      _Cert('Six Sigma Green Belt', 'ASQ', '2021-07', 'مدى الحياة', true, 'ساري'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in certs)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: c.active
                        ? [core_theme.AC.gold.withOpacity(0.1), const Color(0xFFE6C200).withOpacity(0.05)]
                        : [core_theme.AC.navy3, core_theme.AC.navy3],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.active ? core_theme.AC.gold : core_theme.AC.td, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: c.active ? core_theme.AC.gold : core_theme.AC.td,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(c.issuer, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (c.active ? core_theme.AC.ok : core_theme.AC.err).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(c.status,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: c.active ? core_theme.AC.ok : core_theme.AC.err,
                                        fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 6),
                              Text('ينتهي ${c.expiresAt}',
                                  style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'الامتثال':
        return core_theme.AC.err;
      case 'المحاسبة':
        return core_theme.AC.gold;
      case 'الضرائب':
        return core_theme.AC.ok;
      case 'التقنية':
        return core_theme.AC.info;
      case 'القيادة':
        return core_theme.AC.purple;
      case 'مهارات شخصية':
        return core_theme.AC.err;
      case 'تقني':
        return core_theme.AC.info;
      case 'الحوكمة':
        return core_theme.AC.purple;
      case 'ابتكار':
        return core_theme.AC.warn;
      case 'سلامة':
        return Colors.deepOrange;
      case 'الموارد البشرية':
        return Colors.brown;
      default:
        return core_theme.AC.td;
    }
  }
}

class _Course {
  final String id;
  final String title;
  final String category;
  final int minutes;
  final String type;
  final double rating;
  final int enrolled;
  final bool mandatory;
  const _Course(this.id, this.title, this.category, this.minutes, this.type, this.rating, this.enrolled, this.mandatory);
}

class _MyTraining {
  final String courseId;
  final String title;
  final int progress;
  final String status;
  final String? completedAt;
  final String? grade;
  final bool completed;
  const _MyTraining(this.courseId, this.title, this.progress, this.status, this.completedAt, this.grade, this.completed);
}

class _Cert {
  final String name;
  final String issuer;
  final String issuedAt;
  final String expiresAt;
  final bool active;
  final String status;
  const _Cert(this.name, this.issuer, this.issuedAt, this.expiresAt, this.active, this.status);
}
