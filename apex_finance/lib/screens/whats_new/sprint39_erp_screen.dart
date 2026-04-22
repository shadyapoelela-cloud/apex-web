/// Sprint 39-40 — ERP Expansion demo.
///
/// Three mini-modules in tabs:
///   1) HR: employees + leave approval queue
///   2) CRM: drag-drop Kanban pipeline (New → Qualified → Negotiating → Won)
///   3) Workflow: if-then automation rule builder
///
/// Each one mirrors the Odoo module of the same name, adapted to the
/// APEX theme. Data is in-memory for the demo.
library;

import 'package:flutter/material.dart';

import '../../core/apex_data_table.dart';
import '../../core/apex_kanban.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/apex_workflow_rules.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/theme.dart' as core_theme;

class Sprint39ErpScreen extends StatefulWidget {
  const Sprint39ErpScreen({super.key});

  @override
  State<Sprint39ErpScreen> createState() => _Sprint39ErpScreenState();
}

class _Sprint39ErpScreenState extends State<Sprint39ErpScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this, initialIndex: 0);

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
          const ApexStickyToolbar(title: '🏭 Sprint 39-40: توسّع ERP'),
          Container(
            color: AC.navy2,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              tabs: const [
                Tab(icon: Icon(Icons.badge_outlined), text: 'الموارد البشرية'),
                Tab(icon: Icon(Icons.view_kanban_outlined), text: 'مبيعات CRM'),
                Tab(icon: Icon(Icons.auto_mode_outlined), text: 'أتمتة سير العمل'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _HrTab(),
                _CrmTab(),
                _WorkflowTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── HR Tab ───────────────────────────────────────────────

class _HrTab extends StatefulWidget {
  const _HrTab();
  @override
  State<_HrTab> createState() => _HrTabState();
}

class _HrTabState extends State<_HrTab> {
  final List<_Employee> _employees = const [
    _Employee('EMP-001', 'أحمد السالم', 'المالية', 'مدير مالي', 18000, 'active'),
    _Employee('EMP-002', 'فاطمة النور', 'الموارد البشرية', 'مدير HR', 16500, 'active'),
    _Employee('EMP-003', 'خالد العتيبي', 'تقنية المعلومات', 'مطور رئيسي', 14000, 'active'),
    _Employee('EMP-004', 'ريم القحطاني', 'المبيعات', 'تنفيذي مبيعات', 11000, 'active'),
    _Employee('EMP-005', 'يوسف المطيري', 'العمليات', 'مسؤول مشتريات', 9500, 'probation'),
  ];

  final List<_LeaveRequest> _leaves = [
    _LeaveRequest('LV-001', 'EMP-001', 'أحمد السالم', 'سنوية', 5, 'pending'),
    _LeaveRequest('LV-002', 'EMP-003', 'خالد العتيبي', 'مرضية', 2, 'approved'),
    _LeaveRequest('LV-003', 'EMP-004', 'ريم القحطاني', 'أمومة', 60, 'pending'),
    _LeaveRequest('LV-004', 'EMP-005', 'يوسف المطيري', 'سنوية', 7, 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _kpiStrip(),
        const SizedBox(height: AppSpacing.lg),
        _section('الموظفون (${_employees.length})', _employeesTable()),
        const SizedBox(height: AppSpacing.lg),
        _section(
            'طلبات الإجازة المعلّقة (${_leaves.where((l) => l.status == 'pending').length})',
            _leavesTable()),
      ],
    );
  }

  Widget _kpiStrip() => Row(children: [
        Expanded(child: _kpi('إجمالي الموظفين', '5', Icons.groups, AC.gold)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('طلبات معلّقة', '3', Icons.pending_actions, AC.err)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('إجمالي الرواتب', '69,000 ر.س',
                Icons.account_balance_wallet, AC.ok)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi(
                'GOSI المستحق', '6,900 ر.س', Icons.shield_outlined, AC.gold)),
      ]);

  Widget _kpi(String label, String value, IconData icon, Color accent) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style:
                        TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(value,
                style: TextStyle(
                    color: accent,
                    fontSize: AppFontSize.h3,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _section(String title, Widget body) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        ),
      );

  Widget _employeesTable() => ApexDataTable<_Employee>(
        rows: _employees,
        columns: [
          ApexColumn(
              key: 'id',
              label: 'رقم',
              cell: (e) => Text(e.id, style: TextStyle(color: AC.tp)),
              sortValue: (e) => e.id,
              width: 100),
          ApexColumn(
              key: 'name',
              label: 'الاسم',
              cell: (e) => Text(e.name, style: TextStyle(color: AC.tp)),
              sortValue: (e) => e.name,
              flex: 2),
          ApexColumn(
              key: 'dept',
              label: 'القسم',
              cell: (e) => Text(e.department, style: TextStyle(color: AC.ts)),
              sortValue: (e) => e.department),
          ApexColumn(
              key: 'role',
              label: 'المسمى',
              cell: (e) => Text(e.role, style: TextStyle(color: AC.ts)),
              sortValue: (e) => e.role),
          ApexColumn(
              key: 'salary',
              label: 'الراتب',
              numeric: true,
              cell: (e) => Text(e.salary.toStringAsFixed(0),
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w600)),
              sortValue: (e) => e.salary,
              width: 100),
        ],
      );

  Widget _leavesTable() => ApexDataTable<_LeaveRequest>(
        rows: _leaves,
        columns: [
          ApexColumn(
              key: 'id',
              label: 'رقم',
              cell: (l) => Text(l.id, style: TextStyle(color: AC.tp)),
              sortValue: (l) => l.id,
              width: 100),
          ApexColumn(
              key: 'emp',
              label: 'الموظف',
              cell: (l) => Text(l.employeeName, style: TextStyle(color: AC.tp)),
              sortValue: (l) => l.employeeName,
              flex: 2),
          ApexColumn(
              key: 'type',
              label: 'النوع',
              cell: (l) => Text(l.type, style: TextStyle(color: AC.ts)),
              sortValue: (l) => l.type),
          ApexColumn(
              key: 'days',
              label: 'أيام',
              numeric: true,
              cell: (l) => Text('${l.days}',
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w600)),
              sortValue: (l) => l.days,
              width: 70),
          ApexColumn(
              key: 'status',
              label: 'الحالة',
              cell: (l) => _statusPill(l.status),
              sortValue: (l) => l.status,
              width: 140),
          ApexColumn(
              key: 'act',
              label: 'إجراء',
              cell: (l) => l.status == 'pending'
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(Icons.check_circle,
                            color: AC.ok, size: 20),
                        tooltip: 'اعتماد',
                        onPressed: () => _updateLeave(l.id, 'approved'),
                      ),
                      IconButton(
                        icon: Icon(Icons.cancel, color: AC.err, size: 20),
                        tooltip: 'رفض',
                        onPressed: () => _updateLeave(l.id, 'rejected'),
                      ),
                    ])
                  : const SizedBox.shrink(),
              sortable: false,
              width: 100),
        ],
      );

  Widget _statusPill(String s) {
    final (color, label) = switch (s) {
      'approved' => (AC.ok, 'معتمدة'),
      'rejected' => (AC.err, 'مرفوضة'),
      _ => (AC.gold, 'معلّقة'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600)),
    );
  }

  void _updateLeave(String id, String newStatus) {
    setState(() {
      final i = _leaves.indexWhere((l) => l.id == id);
      if (i >= 0) _leaves[i] = _leaves[i].copyWith(status: newStatus);
    });
  }
}

// ── CRM Tab ──────────────────────────────────────────────

class _CrmTab extends StatefulWidget {
  const _CrmTab();
  @override
  State<_CrmTab> createState() => _CrmTabState();
}

class _CrmTabState extends State<_CrmTab> {
  List<_Lead> _leads = [
    _Lead('L1', 'شركة الرياض للتجارة', 85000, 'new', 'أحمد'),
    _Lead('L2', 'مؤسسة النجم الذهبي', 42000, 'new', 'أحمد'),
    _Lead('L3', 'المتحدة للمقاولات', 150000, 'qualified', 'فاطمة'),
    _Lead('L4', 'آفاق التقنية', 28000, 'qualified', 'أحمد'),
    _Lead('L5', 'الأبحاث الطبية', 92000, 'negotiating', 'فاطمة'),
    _Lead('L6', 'المدرسة النموذجية', 18000, 'negotiating', 'خالد'),
    _Lead('L7', 'صناعات البتروكيماويات', 320000, 'won', 'فاطمة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(children: [
            Text('خطّ المبيعات',
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              'إجمالي: ${_total().toStringAsFixed(0)} ر.س — ضغطة مطوّلة على بطاقة لسحبها',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ApexKanban<_Lead>(
            columns: [
              ApexKanbanColumn(
                  status: 'new',
                  title: 'جديد',
                  icon: Icons.fiber_new,
                  accent: AC.ts),
              ApexKanbanColumn(
                  status: 'qualified',
                  title: 'مؤهّل',
                  icon: Icons.verified_outlined,
                  accent: AC.gold),
              ApexKanbanColumn(
                  status: 'negotiating',
                  title: 'قيد التفاوض',
                  icon: Icons.forum_outlined,
                  accent: core_theme.AC.warn),
              ApexKanbanColumn(
                  status: 'won',
                  title: 'مكسب',
                  icon: Icons.emoji_events_outlined,
                  accent: AC.ok),
            ],
            cards: _leads,
            statusOf: (l) => l.status,
            cardBuilder: _leadCard,
            onMove: (card, newStatus) {
              setState(() {
                final i = _leads.indexWhere((l) => l.id == card.id);
                _leads[i] = card.copyWith(status: newStatus);
              });
              return true;
            },
          ),
        ),
      ]),
    );
  }

  double _total() => _leads.fold(0.0, (s, l) => s + l.value);

  Widget _leadCard(BuildContext ctx, _Lead l) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
          boxShadow: [
            BoxShadow(
                color: core_theme.AC.tp.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.company,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${l.value.toStringAsFixed(0)} ر.س',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.person_outline, size: 12, color: AC.td),
              const SizedBox(width: 4),
              Text(l.owner,
                  style:
                      TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
              const Spacer(),
              Text('#${l.id}',
                  style:
                      TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
            ]),
          ],
        ),
      );
}

// ── Workflow Tab ─────────────────────────────────────────

class _WorkflowTab extends StatefulWidget {
  const _WorkflowTab();
  @override
  State<_WorkflowTab> createState() => _WorkflowTabState();
}

class _WorkflowTabState extends State<_WorkflowTab> {
  final _triggers = const [
    WorkflowTrigger(
        id: 'invoice.overdue',
        label: 'فاتورة متأخرة',
        icon: Icons.receipt_long),
    WorkflowTrigger(
        id: 'payment.received',
        label: 'دفعة مستلمة',
        icon: Icons.payments),
    WorkflowTrigger(
        id: 'lead.created', label: 'عميل محتمل جديد', icon: Icons.person_add),
    WorkflowTrigger(
        id: 'leave.submitted',
        label: 'طلب إجازة مقدّم',
        icon: Icons.beach_access),
  ];

  final _actions = const [
    WorkflowAction(
        id: 'send_whatsapp',
        label: 'إرسال رسالة WhatsApp',
        icon: Icons.chat),
    WorkflowAction(
        id: 'send_email', label: 'إرسال بريد إلكتروني', icon: Icons.email),
    WorkflowAction(
        id: 'assign_user',
        label: 'تعيين لمستخدم',
        icon: Icons.assignment_ind),
    WorkflowAction(
        id: 'create_je',
        label: 'إنشاء قيد يومية',
        icon: Icons.auto_graph),
  ];

  late List<WorkflowRule> _rules = [
    WorkflowRule(
      id: 'r1',
      name: 'تذكير الفواتير المتأخرة يومياً',
      enabled: true,
      triggerId: 'invoice.overdue',
      conditions: const [
        WorkflowCondition(field: 'days_overdue', op: '>=', value: '7'),
      ],
      actions: const [
        WorkflowAction(
            id: 'send_whatsapp',
            label: 'إرسال رسالة WhatsApp للعميل',
            icon: Icons.chat),
        WorkflowAction(
            id: 'send_email',
            label: 'إرسال بريد للمحاسب',
            icon: Icons.email),
      ],
    ),
    WorkflowRule(
      id: 'r2',
      name: 'إنشاء قيد عند استلام دفعة',
      enabled: true,
      triggerId: 'payment.received',
      conditions: const [],
      actions: const [
        WorkflowAction(
            id: 'create_je',
            label: 'إنشاء قيد يومية تلقائي',
            icon: Icons.auto_graph),
      ],
    ),
    WorkflowRule(
      id: 'r3',
      name: 'تعيين العملاء الكبار',
      enabled: false,
      triggerId: 'lead.created',
      conditions: const [
        WorkflowCondition(field: 'value', op: '>', value: '100000'),
      ],
      actions: const [
        WorkflowAction(
            id: 'assign_user',
            label: 'تعيين لمدير المبيعات',
            icon: Icons.assignment_ind),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ApexWorkflowBuilder(
        rules: _rules,
        triggers: _triggers,
        actionCatalog: _actions,
        onChanged: (rs) => setState(() => _rules = rs),
      ),
    );
  }
}

// ── Data types ───────────────────────────────────────────

class _Employee {
  final String id, name, department, role, status;
  final double salary;
  const _Employee(
      this.id, this.name, this.department, this.role, this.salary, this.status);
}

class _LeaveRequest {
  final String id, employeeId, employeeName, type, status;
  final int days;
  _LeaveRequest(this.id, this.employeeId, this.employeeName, this.type,
      this.days, this.status);
  _LeaveRequest copyWith({String? status}) => _LeaveRequest(
      id, employeeId, employeeName, type, days, status ?? this.status);
}

class _Lead {
  final String id, company, status, owner;
  final double value;
  const _Lead(this.id, this.company, this.value, this.status, this.owner);
  _Lead copyWith({String? status}) =>
      _Lead(id, company, value, status ?? this.status, owner);
}
