/// APEX Wave 19 — Projects (ERP Sub-Module).
///
/// Fills Projects gap in V5. Third production wave.
///
/// Tabs: Projects · Tasks · Timesheets · Gantt · Billing
/// More ▾: Budgets · Resources · Milestones · Deliverables · Settings
///
/// Route: /app/erp/operations/projects
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'المشاريع', Icons.work),
          _tabBtn(1, 'المهام', Icons.task),
          _tabBtn(2, 'الجداول الزمنية', Icons.schedule),
          _tabBtn(3, 'مخطط جانت', Icons.timeline),
          _tabBtn(4, 'الفوترة', Icons.receipt),
          const Spacer(),
          _moreMenu(),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD4AF37).withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFFD4AF37) : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? const Color(0xFFD4AF37) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreMenu() {
    return PopupMenuButton<String>(
      tooltip: 'المزيد',
      icon: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('المزيد', style: TextStyle(fontSize: 12, color: Colors.black54)),
          Icon(Icons.arrow_drop_down, size: 16, color: Colors.black54),
        ],
      ),
      itemBuilder: (ctx) => [
        _mItem('budgets', 'موازنة المشاريع', Icons.account_balance),
        _mItem('resources', 'تخصيص الموارد', Icons.groups),
        _mItem('milestones', 'المعالم', Icons.flag),
        _mItem('deliverables', 'المخرجات', Icons.inventory),
        _mItem('settings', 'الإعدادات', Icons.settings),
      ],
    );
  }

  PopupMenuItem<String> _mItem(String v, String label, IconData icon) {
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildProjects();
      case 1: return _buildTasks();
      case 2: return _buildTimesheets();
      case 3: return _buildGantt();
      case 4: return _buildBilling();
      default: return const SizedBox();
    }
  }

  // ── Tab 1: Projects ──────────────────────────────────────────────

  Widget _buildProjects() {
    final projects = _mockProjects();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('مشاريع نشطة', '8', Icons.work, const Color(0xFF2563EB)),
            _Stat('متأخرة', '2', Icons.warning, const Color(0xFFB91C1C)),
            _Stat('قيمة إجمالية', '4.2M', Icons.attach_money, const Color(0xFFD4AF37)),
            _Stat('فواتير غير مُصدَرة', '680K', Icons.receipt, const Color(0xFFD97706)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('المشاريع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: const Text('مشروع جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 1100 ? 3 : constraints.maxWidth > 700 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.8,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final p in projects) _ProjectCard(project: p),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Tasks (Kanban by status) ───────────────────────────────

  Widget _buildTasks() {
    final tasks = _mockTasks();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in ['جديد', 'قيد التنفيذ', 'للمراجعة', 'مكتمل']) ...[
            _taskColumn(status, tasks.where((t) => t.status == status).toList()),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _taskColumn(String status, List<_Task> tasks) {
    final color = status == 'جديد'
        ? const Color(0xFF6B7280)
        : status == 'قيد التنفيذ'
            ? const Color(0xFF2563EB)
            : status == 'للمراجعة'
                ? const Color(0xFFD97706)
                : const Color(0xFF059669);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _TaskCard(task: t),
            ),
        ],
      ),
    );
  }

  // ── Tab 3: Timesheets ────────────────────────────────────────────

  Widget _buildTimesheets() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('ساعات هذا الأسبوع', '187', Icons.schedule, const Color(0xFF2563EB)),
            _Stat('قابلة للفوترة', '142', Icons.attach_money, const Color(0xFF059669)),
            _Stat('داخلية', '45', Icons.business_center, const Color(0xFF7C3AED)),
            _Stat('معدل الاستغلال', '78%', Icons.trending_up, const Color(0xFFD4AF37)),
          ]),
          const SizedBox(height: 16),
          const Text('سجلّ الساعات — هذا الأسبوع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _timesheetHeader(),
                _timesheetRow('خالد أحمد', 'محاسبة عملاء', 8, 8, 7, 8, 6, 0, 0, billable: true),
                _timesheetRow('ليلى السعيد', 'مشروع ABC', 8, 7, 8, 8, 6, 0, 0, billable: true),
                _timesheetRow('يوسف الحارثي', 'إدارة داخلية', 4, 4, 3, 4, 4, 0, 0, billable: false),
                _timesheetRow('فاطمة علي', 'SABIC engagement', 8, 8, 8, 8, 4, 0, 0, billable: true),
                _timesheetRow('حمد الدوسري', 'تدريب', 2, 3, 0, 2, 1, 0, 0, billable: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timesheetHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('الموظف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          Expanded(flex: 2, child: Text('المشروع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          Expanded(child: Text('السبت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الأحد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الاثنين', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الثلاثاء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الأربعاء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الخميس', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الجمعة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          Expanded(child: Text('الإجمالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _timesheetRow(String name, String project, int sat, int sun, int mon, int tue, int wed, int thu, int fri, {required bool billable}) {
    final total = sat + sun + mon + tue + wed + thu + fri;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: billable ? const Color(0xFF059669) : Colors.black38,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(project, style: const TextStyle(fontSize: 11))),
              ],
            ),
          ),
          for (final h in [sat, sun, mon, tue, wed, thu, fri])
            Expanded(
              child: Text(
                h > 0 ? '$h' : '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: h > 0 ? Colors.black87 : Colors.black26,
                ),
              ),
            ),
          Expanded(
            child: Text(
              '$total',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                color: billable ? const Color(0xFF059669) : const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Gantt ──────────────────────────────────────────────────

  Widget _buildGantt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('مراحل نشطة', '14', Icons.flag, const Color(0xFF2563EB)),
            _Stat('معالم قادمة', '6', Icons.event, const Color(0xFFD97706)),
            _Stat('Critical Path', '3 مهام', Icons.priority_high, const Color(0xFFB91C1C)),
            _Stat('معدل الإنجاز', '68%', Icons.check_circle, const Color(0xFF059669)),
          ]),
          const SizedBox(height: 16),
          const Text('مخطط جانت — أبريل 2026', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _ganttHeader(),
                _ganttBar('تخطيط المشروع ABC', 1, 7, const Color(0xFF059669), 1.0),
                _ganttBar('تحليل المتطلبات', 3, 12, const Color(0xFF2563EB), 1.0),
                _ganttBar('التصميم المبدئي', 10, 20, const Color(0xFF2563EB), 0.8),
                _ganttBar('التنفيذ — المرحلة 1', 15, 28, const Color(0xFFD97706), 0.5),
                _ganttBar('اختبار القبول', 25, 30, const Color(0xFF7C3AED), 0.0),
                _ganttBar('التسليم للعميل', 28, 30, const Color(0xFFD4AF37), 0.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ganttHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 180),
          Expanded(
            child: Row(
              children: [
                for (int day = 1; day <= 30; day += 5)
                  Expanded(
                    child: Text(
                      '$day',
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ganttBar(String task, int startDay, int endDay, Color color, double progress) {
    final totalDays = 30.0;
    final startFrac = startDay / totalDays;
    final endFrac = endDay / totalDays;
    final durationFrac = endFrac - startFrac;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(task, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final barWidth = constraints.maxWidth * durationFrac;
                final leftOffset = constraints.maxWidth * startFrac;
                return Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Positioned(
                      left: leftOffset,
                      child: Container(
                        height: 20,
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: color),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              width: barWidth * progress,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Center(
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: progress > 0.3 ? Colors.white : color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Billing ───────────────────────────────────────────────

  Widget _buildBilling() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('فواتير غير مُصدَرة', '3', Icons.pending, const Color(0xFFD97706)),
            _Stat('WIP', '380K', Icons.work_outline, const Color(0xFF2563EB)),
            _Stat('مُصدَرة هذا الشهر', '2.4M', Icons.check_circle, const Color(0xFF059669)),
            _Stat('متأخرة', '120K', Icons.warning, const Color(0xFFB91C1C)),
          ]),
          const SizedBox(height: 16),
          const Text('فواتير المشاريع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _billingRow('مشروع SABIC', 'نصف شهري', 280000, 'قابل للإصدار', const Color(0xFFD97706), actionable: true),
                _billingRow('مشروع ABC', 'عند المعالم', 125000, 'WIP', const Color(0xFF2563EB)),
                _billingRow('Al Rajhi Consulting', 'شهري', 87500, 'قابل للإصدار', const Color(0xFFD97706), actionable: true),
                _billingRow('STC Advisory', 'شهري', 45000, 'مُصدَر', const Color(0xFF059669)),
                _billingRow('Marriott Review', 'end of project', 180000, 'WIP', const Color(0xFF2563EB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billingRow(String project, String freq, double amount, String status, Color color, {bool actionable = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          const Icon(Icons.work, size: 16, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('دورة الفوترة: $freq', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} ر.س',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          if (actionable)
            ElevatedButton.icon(
              onPressed: () {
                ApexV5UndoToast.show(
                  context,
                  messageAr: 'تم إنشاء فاتورة $project بقيمة ${amount.toStringAsFixed(0)} ر.س',
                  onUndo: () {},
                );
              },
              icon: const Icon(Icons.receipt, size: 12),
              label: const Text('إصدار فاتورة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statsRow(List<_Stat> stats) {
    return Row(
      children: [
        for (final s in stats) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.color)),
                        Text(s.label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (s != stats.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  List<_Project> _mockProjects() => [
        _Project('PRJ-2026-001', 'SABIC Audit 2026', 'SABIC', 280000, 0.65, 'active', 'HIGH'),
        _Project('PRJ-2026-002', 'ABC Advisory', 'ABC Trading', 125000, 0.40, 'active', 'MEDIUM'),
        _Project('PRJ-2026-003', 'Al Rajhi Consulting', 'Al Rajhi Bank', 350000, 0.80, 'active', 'HIGH'),
        _Project('PRJ-2026-004', 'STC Tax Advisory', 'STC', 87500, 0.90, 'active', 'MEDIUM'),
        _Project('PRJ-2026-005', 'Marriott Review', 'Marriott', 180000, 0.25, 'active', 'LOW'),
        _Project('PRJ-2026-006', 'Aramco Feasibility', 'Aramco', 450000, 0.10, 'active', 'HIGH'),
      ];

  List<_Task> _mockTasks() => [
        _Task('T-001', 'مراجعة TB Q1', 'خالد', 'PRJ-2026-001', 'جديد'),
        _Task('T-002', 'تحليل CoA', 'ليلى', 'PRJ-2026-001', 'قيد التنفيذ'),
        _Task('T-003', 'اختبارات الضوابط', 'يوسف', 'PRJ-2026-002', 'قيد التنفيذ'),
        _Task('T-004', 'توثيق النتائج', 'فاطمة', 'PRJ-2026-001', 'للمراجعة'),
        _Task('T-005', 'اعتماد الشريك', 'أحمد', 'PRJ-2026-003', 'للمراجعة'),
        _Task('T-006', 'إصدار التقرير', 'سارة', 'PRJ-2026-004', 'مكتمل'),
        _Task('T-007', 'اجتماع بدء', 'محمد', 'PRJ-2026-006', 'جديد'),
        _Task('T-008', 'تحليل السوق', 'ليلى', 'PRJ-2026-005', 'قيد التنفيذ'),
        _Task('T-009', 'تدقيق عينات', 'خالد', 'PRJ-2026-002', 'مكتمل'),
      ];
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _Project {
  final String id;
  final String name;
  final String client;
  final double budget;
  final double progress;
  final String status;
  final String priority;
  _Project(this.id, this.name, this.client, this.budget, this.progress, this.status, this.priority);
}

class _Task {
  final String id;
  final String title;
  final String assignee;
  final String project;
  final String status;
  _Task(this.id, this.title, this.assignee, this.project, this.status);
}

class _ProjectCard extends StatelessWidget {
  final _Project project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final color = project.priority == 'HIGH'
        ? const Color(0xFFB91C1C)
        : project.priority == 'MEDIUM'
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(project.id, style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace')),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  project.priority,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            project.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(project.client, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const Spacer(),
          Text(
            '${project.budget.toStringAsFixed(0)} ر.س',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: project.progress,
            backgroundColor: Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
          const SizedBox(height: 4),
          Text(
            '${(project.progress * 100).toInt()}% مكتمل',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _Task task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.id, style: const TextStyle(fontSize: 9, color: Colors.black54, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(task.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                child: Text(
                  task.assignee.substring(0, 1),
                  style: const TextStyle(fontSize: 10, color: Color(0xFFD4AF37), fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 4),
              Text(task.assignee, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const Spacer(),
              Text(
                task.project,
                style: const TextStyle(fontSize: 9, color: Colors.black45, fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
