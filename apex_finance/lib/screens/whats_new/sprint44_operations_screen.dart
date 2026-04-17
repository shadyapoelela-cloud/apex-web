/// Sprint 44 — Manufacturing Operations + Responsive Audit.
///
/// Three tabs:
///   1) Work Orders — production planning board with 6 WOs across 5
///      stages (planned → done); filter chips per stage.
///   2) Gantt — timeline view of all active WOs.
///   3) Responsive Audit — side-by-side preview of the dashboard at
///      4 standard device widths (mobile / tablet / desktop / wide).
library;

import 'package:flutter/material.dart';

import '../../core/apex_breakpoint_audit.dart';
import '../../core/apex_kanban.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/apex_work_orders.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class Sprint44OperationsScreen extends StatefulWidget {
  const Sprint44OperationsScreen({super.key});

  @override
  State<Sprint44OperationsScreen> createState() =>
      _Sprint44OperationsScreenState();
}

class _Sprint44OperationsScreenState extends State<Sprint44OperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: '🏗️ Sprint 44: عمليات التصنيع'),
          Container(
            color: AC.navy2,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              tabs: const [
                Tab(
                    icon: Icon(Icons.view_kanban),
                    text: 'أوامر العمل Kanban'),
                Tab(icon: Icon(Icons.timeline), text: 'الجدول الزمني Gantt'),
                Tab(
                    icon: Icon(Icons.devices),
                    text: 'فحص الاستجابة Responsive'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _WorkOrdersTab(),
                _GanttTab(),
                _ResponsiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Work Orders Tab ──────────────────────────────────────

class _WorkOrdersTab extends StatefulWidget {
  const _WorkOrdersTab();
  @override
  State<_WorkOrdersTab> createState() => _WorkOrdersTabState();
}

class _WorkOrdersTabState extends State<_WorkOrdersTab> {
  late List<WorkOrder> _orders = [
    WorkOrder(
      id: 'WO-2026-001',
      productSku: 'FP-001',
      productName: 'مكتب خشبي — LG Model',
      quantity: 25,
      startDate: DateTime(2026, 4, 15),
      dueDate: DateTime(2026, 4, 28),
      completed: 18,
      stage: WorkOrderStage.inProgress,
      materialsReady: true,
      assignedTo: 'فريق الإنتاج A',
    ),
    WorkOrder(
      id: 'WO-2026-002',
      productSku: 'FP-002',
      productName: 'خزانة مكتبية 3 أدراج',
      quantity: 10,
      startDate: DateTime(2026, 4, 20),
      dueDate: DateTime(2026, 5, 5),
      completed: 0,
      stage: WorkOrderStage.planned,
      materialsReady: false,
    ),
    WorkOrder(
      id: 'WO-2026-003',
      productSku: 'FP-003',
      productName: 'كرسي مكتبي دوّار',
      quantity: 50,
      startDate: DateTime(2026, 4, 10),
      dueDate: DateTime(2026, 4, 22),
      completed: 50,
      stage: WorkOrderStage.qualityCheck,
      materialsReady: true,
      assignedTo: 'مراقبة الجودة',
    ),
    WorkOrder(
      id: 'WO-2026-004',
      productSku: 'FP-001',
      productName: 'مكتب خشبي — Compact',
      quantity: 15,
      startDate: DateTime(2026, 4, 1),
      dueDate: DateTime(2026, 4, 14),
      completed: 15,
      stage: WorkOrderStage.done,
      materialsReady: true,
      assignedTo: 'فريق الإنتاج B',
    ),
    WorkOrder(
      id: 'WO-2026-005',
      productSku: 'FP-004',
      productName: 'مكتبة رفوف 5 طوابق',
      quantity: 8,
      startDate: DateTime(2026, 4, 18),
      dueDate: DateTime(2026, 4, 30),
      completed: 3,
      stage: WorkOrderStage.released,
      materialsReady: true,
      assignedTo: 'فريق الإنتاج A',
    ),
    WorkOrder(
      id: 'WO-2026-006',
      productSku: 'FP-005',
      productName: 'طاولة اجتماعات 6 أشخاص',
      quantity: 4,
      startDate: DateTime(2026, 3, 20),
      dueDate: DateTime(2026, 4, 10), // overdue
      completed: 2,
      stage: WorkOrderStage.inProgress,
      materialsReady: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: ApexKanban<WorkOrder>(
            columns: const [
              ApexKanbanColumn(
                  status: 'planned',
                  title: 'مُخطَّط',
                  icon: Icons.fact_check_outlined),
              ApexKanbanColumn(
                  status: 'released',
                  title: 'مُفعَّل',
                  icon: Icons.play_arrow),
              ApexKanbanColumn(
                  status: 'inProgress',
                  title: 'قيد التصنيع',
                  icon: Icons.engineering),
              ApexKanbanColumn(
                  status: 'qualityCheck',
                  title: 'فحص الجودة',
                  icon: Icons.verified),
              ApexKanbanColumn(
                  status: 'done',
                  title: 'منتهي',
                  icon: Icons.check_circle),
            ],
            cards: _orders,
            statusOf: (w) => w.stage.name,
            cardBuilder: (ctx, wo) => ApexWorkOrderCard(wo: wo),
            onMove: (card, newStatus) {
              setState(() {
                final i = _orders.indexWhere((w) => w.id == card.id);
                _orders[i] = card.copyWith(
                    stage: WorkOrderStage.values
                        .firstWhere((s) => s.name == newStatus));
              });
              return true;
            },
          ),
        ),
      ),
    ]);
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.withValues(alpha: 0.18), AC.navy2],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: Colors.orange.shade300.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(Icons.precision_manufacturing,
                color: Colors.orange.shade200, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لوحة أوامر العمل — 5 مراحل',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${_orders.length} أمر نشط — اسحب الكرت لنقله بين المراحل. التنبيهات الحمراء = متأخر أو نقص مواد.',
                      style: TextStyle(
                          color: AC.ts, fontSize: AppFontSize.sm)),
                ],
              ),
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statKpi(
                      'متأخر',
                      _orders.where((w) => w.overdue).length.toString(),
                      AC.err),
                  const SizedBox(height: 4),
                  _statKpi(
                      'نقص مواد',
                      _orders.where((w) => !w.materialsReady).length.toString(),
                      Colors.amber.shade700),
                ]),
          ]),
        ),
      );

  Widget _statKpi(String label, String value, Color color) => Row(children: [
        Text(label,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w800)),
        ),
      ]);
}

// ── Gantt Tab ────────────────────────────────────────────

class _GanttTab extends StatelessWidget {
  const _GanttTab();

  static final _orders = <({String id, String name, DateTime s, DateTime e, double pct, Color c})>[
    (
      id: 'WO-001',
      name: 'مكتب LG × 25',
      s: DateTime(2026, 4, 15),
      e: DateTime(2026, 4, 28),
      pct: 0.72,
      c: Colors.orange,
    ),
    (
      id: 'WO-002',
      name: 'خزانة 3 أدراج × 10',
      s: DateTime(2026, 4, 20),
      e: DateTime(2026, 5, 5),
      pct: 0.0,
      c: Colors.grey,
    ),
    (
      id: 'WO-003',
      name: 'كرسي دوّار × 50',
      s: DateTime(2026, 4, 10),
      e: DateTime(2026, 4, 22),
      pct: 1.0,
      c: Colors.purple,
    ),
    (
      id: 'WO-004',
      name: 'مكتب Compact × 15',
      s: DateTime(2026, 4, 1),
      e: DateTime(2026, 4, 14),
      pct: 1.0,
      c: Colors.green,
    ),
    (
      id: 'WO-005',
      name: 'مكتبة × 8',
      s: DateTime(2026, 4, 18),
      e: DateTime(2026, 4, 30),
      pct: 0.38,
      c: Colors.amber,
    ),
    (
      id: 'WO-006',
      name: 'طاولة اجتماع × 4',
      s: DateTime(2026, 3, 20),
      e: DateTime(2026, 4, 10),
      pct: 0.5,
      c: Colors.red,
    ),
  ];

  static final _rangeStart = DateTime(2026, 3, 15);
  static final _rangeEnd = DateTime(2026, 5, 10);
  static int get _totalDays => _rangeEnd.difference(_rangeStart).inDays;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AC.navy2,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AC.bdr),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Gantt — مارس 15 → مايو 10 2026',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                _timeline(),
                const SizedBox(height: AppSpacing.md),
                for (final o in _orders) ...[
                  _row(o),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _todayLegend(),
        ],
      ),
    );
  }

  Widget _timeline() => Row(children: [
        const SizedBox(width: 160),
        Expanded(
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AC.bdr),
            ),
            child: Row(children: [
              _tick('15/03'),
              _tick('29/03'),
              _tick('12/04'),
              _tick('26/04'),
              _tick('10/05'),
            ]),
          ),
        ),
      ]);

  Widget _tick(String s) => Expanded(
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: AC.bdr, width: 0.5)),
          ),
          child: Text(s,
              style: TextStyle(
                  color: AC.td,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace')),
        ),
      );

  Widget _row(({String id, String name, DateTime s, DateTime e, double pct, Color c}) o) {
    final startOffset =
        o.s.difference(_rangeStart).inDays / _totalDays;
    final span = o.e.difference(o.s).inDays / _totalDays;
    return Row(children: [
      SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.name,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text(o.id,
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
      Expanded(
        child: SizedBox(
          height: 24,
          child: LayoutBuilder(builder: (ctx, cons) {
            final total = cons.maxWidth;
            final left = startOffset * total;
            final width = (span * total).clamp(14.0, total - left);
            final todayPct = DateTime.now().difference(_rangeStart).inDays /
                _totalDays;
            final todayX = (todayPct * total).clamp(0.0, total);
            return Stack(children: [
              // Bar background
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AC.navy3,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // The WO bar
              Positioned(
                left: left,
                width: width,
                top: 4,
                bottom: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: o.c.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: o.c.withValues(alpha: 0.7)),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: o.pct.clamp(0.0, 1.0),
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      decoration: BoxDecoration(
                        color: o.c,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              // Today marker
              Positioned(
                left: todayX,
                top: 0,
                bottom: 0,
                width: 2,
                child: Container(color: AC.err),
              ),
            ]);
          }),
        ),
      ),
    ]);
  }

  Widget _todayLegend() => Row(children: [
        Container(width: 14, height: 3, color: AC.err),
        const SizedBox(width: 4),
        Text('اليوم',
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
        const SizedBox(width: 16),
        Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
                color: AC.gold,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('نسبة الإنجاز',
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
      ]);
}

// ── Responsive Tab ───────────────────────────────────────

class _ResponsiveTab extends StatelessWidget {
  const _ResponsiveTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.withValues(alpha: 0.18), AC.navy2],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: Colors.blue.shade300.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Icon(Icons.devices, color: Colors.blue.shade200, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('فحص استجابة التصميم',
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.w700)),
                    Text(
                      'نفس المحتوى مُعاين على 4 أحجام معيارية — Mobile 375 / Tablet 768 / Desktop 1366 / Wide 1920.',
                      style: TextStyle(
                          color: AC.ts, fontSize: AppFontSize.sm),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 0.9,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            children: [
              for (final bp in kBreakpoints)
                ApexBreakpointPreview(
                  breakpoint: bp,
                  child: _sampleDashboard(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sampleDashboard() {
    return Scaffold(
      backgroundColor: AC.navy,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.dashboard, color: AC.gold, size: 18),
              const SizedBox(width: 6),
              Text('لوحة التحكم',
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.notifications_outlined,
                  color: AC.ts, size: 16),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in const [
                  ('الإيرادات', '124k', Color(0xFFD4AF37)),
                  ('السيولة', '89k', Color(0xFF27AE60)),
                  ('AR', '42k', Color(0xFFE74C3C)),
                  ('Burn', '15k', Color(0xFFFF9800)),
                ])
                  Container(
                    width: 100,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AC.navy2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: k.$3.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.$1,
                              style:
                                  TextStyle(color: AC.ts, fontSize: 10)),
                          Text(k.$2,
                              style: TextStyle(
                                  color: k.$3,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AC.navy2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AC.bdr),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.show_chart, color: AC.gold, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}
