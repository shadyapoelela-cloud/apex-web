/// Wave 154 — Resource Allocation (project staffing).
///
/// Float / Resource Guru / Runn-class resource planner.
/// Features:
///   - Weekly calendar grid (Gantt-style)
///   - Utilization heatmap per person
///   - Over-allocation warnings
///   - Skills-based matching
///   - Capacity vs. demand forecast
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ResourceAllocationScreen extends StatefulWidget {
  const ResourceAllocationScreen({super.key});

  @override
  State<ResourceAllocationScreen> createState() => _ResourceAllocationScreenState();
}

class _ResourceAllocationScreenState extends State<ResourceAllocationScreen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  static const _people = <_Person>[
    _Person(name: 'أحمد محمد', role: 'مهندس كبير', capacity: 40, allocated: 38, skills: ['Flutter', 'Dart', 'Firebase']),
    _Person(name: 'سارة علي', role: 'محللة أعمال', capacity: 40, allocated: 32, skills: ['BA', 'SQL', 'Power BI']),
    _Person(name: 'عمر حسن', role: 'مصمم UX', capacity: 40, allocated: 45, skills: ['Figma', 'Design Systems']),
    _Person(name: 'ليلى أحمد', role: 'مدير مشروع', capacity: 40, allocated: 35, skills: ['PMP', 'Agile', 'Scrum']),
    _Person(name: 'خالد إبراهيم', role: 'مطور خلفية', capacity: 40, allocated: 40, skills: ['Python', 'FastAPI', 'PostgreSQL']),
    _Person(name: 'يوسف عمر', role: 'محاسب مالي', capacity: 40, allocated: 28, skills: ['IFRS', 'Audit', 'Excel']),
    _Person(name: 'دينا حسام', role: 'مسوّقة رقمية', capacity: 40, allocated: 42, skills: ['SEO', 'Ads', 'Analytics']),
    _Person(name: 'سامي طارق', role: 'مهندس DevOps', capacity: 40, allocated: 36, skills: ['AWS', 'Docker', 'Kubernetes']),
  ];

  static const _projects = <_ProjAlloc>[
    _ProjAlloc(project: 'مشروع أبكس V5.2', person: 'أحمد محمد', hours: 24, week: 'W16'),
    _ProjAlloc(project: 'مشروع أبكس V5.2', person: 'خالد إبراهيم', hours: 32, week: 'W16'),
    _ProjAlloc(project: 'تطبيق البنك الرقمي', person: 'سارة علي', hours: 20, week: 'W16'),
    _ProjAlloc(project: 'تطبيق البنك الرقمي', person: 'عمر حسن', hours: 28, week: 'W16'),
    _ProjAlloc(project: 'تدقيق سنوي', person: 'يوسف عمر', hours: 24, week: 'W16'),
    _ProjAlloc(project: 'حملة تسويقية Q2', person: 'دينا حسام', hours: 36, week: 'W16'),
    _ProjAlloc(project: 'إدارة المشاريع', person: 'ليلى أحمد', hours: 30, week: 'W16'),
    _ProjAlloc(project: 'ترحيل البنية التحتية', person: 'سامي طارق', hours: 36, week: 'W16'),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.group_work, color: _gold),
                  const SizedBox(width: 8),
                  Text('تخصيص الموارد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.event),
                    label: Text('الأسبوع الحالي W16'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: _gold),
                    icon: const Icon(Icons.assignment_ind),
                    label: Text('تخصيص جديد'),
                  ),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.group, label: 'الموارد النشطة', value: '8', color: core_theme.AC.info)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.analytics, label: 'الاستغلال المتوسط', value: '90%', color: core_theme.AC.gold)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.warning, label: 'فائض تحميل', value: '2', color: core_theme.AC.err)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.event_available, label: 'سعة متاحة', value: '40 ساعة', color: core_theme.AC.ok)),
                ],
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  // People utilization
                  Expanded(
                    flex: 3,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _people.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = _people[i];
                        final pct = (p.allocated / p.capacity * 100).clamp(0, 200);
                        final over = pct > 100;
                        final (barColor, labelColor, statusText) = over
                            ? (core_theme.AC.err, core_theme.AC.err, 'زيادة تحميل')
                            : pct > 95
                                ? (core_theme.AC.warn, core_theme.AC.warn, 'مكتمل')
                                : pct > 75
                                    ? (core_theme.AC.ok, core_theme.AC.ok, 'متوازن')
                                    : (core_theme.AC.info, core_theme.AC.info, 'سعة متاحة');
                        return Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _navy.withValues(alpha: 0.1),
                                  child: Text(p.name.substring(0, 1),
                                      style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                      Text(p.role,
                                          style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('${p.allocated}/${p.capacity} ساعة',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            const Spacer(),
                                            Text('${pct.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: labelColor)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (pct / 100).clamp(0, 1.0).toDouble(),
                                            minHeight: 8,
                                            backgroundColor: core_theme.AC.bdr,
                                            color: barColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: barColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(statusText,
                                      style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w800, color: barColor)),
                                ),
                                const SizedBox(width: 8),
                                Wrap(
                                  spacing: 4,
                                  children: p.skills.take(2).map((s) => Chip(
                                    label: Text(s, style: const TextStyle(fontSize: 10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: core_theme.AC.navy3,
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Upcoming allocations
                  Container(
                    width: 340,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: core_theme.AC.bdr)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تخصيصات الأسبوع',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _projects.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (ctx, i) {
                              final a = _projects[i];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: core_theme.AC.navy3,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: core_theme.AC.bdr),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.project,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 12, color: core_theme.AC.ts),
                                        const SizedBox(width: 4),
                                        Text(a.person,
                                            style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                                        const Spacer(),
                                        Text('${a.hours} س',
                                            style: TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.w700, color: _gold)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Person {
  final String name;
  final String role;
  final int capacity;
  final int allocated;
  final List<String> skills;
  const _Person({
    required this.name,
    required this.role,
    required this.capacity,
    required this.allocated,
    required this.skills,
  });
}

class _ProjAlloc {
  final String project;
  final String person;
  final int hours;
  final String week;
  const _ProjAlloc({
    required this.project,
    required this.person,
    required this.hours,
    required this.week,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
                Text(value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
