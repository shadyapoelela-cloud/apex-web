/// APEX — Employee Expense Reports
/// /hr/expense-reports — submitted expenses with approval workflow
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ExpenseReportsScreen extends StatefulWidget {
  const ExpenseReportsScreen({super.key});
  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  String _filter = 'pending';

  final List<Map<String, dynamic>> _reports = [
    {'id': 'EXP-2026-0042', 'employee': 'أحمد العتيبي', 'amount': 1250.0, 'date': '2026-04-22', 'category': 'سفر', 'status': 'pending', 'items': 5},
    {'id': 'EXP-2026-0041', 'employee': 'سارة المطيري', 'amount': 350.0, 'date': '2026-04-20', 'category': 'مكتبية', 'status': 'pending', 'items': 3},
    {'id': 'EXP-2026-0040', 'employee': 'محمد القحطاني', 'amount': 2800.0, 'date': '2026-04-18', 'category': 'سفر', 'status': 'approved', 'items': 8},
    {'id': 'EXP-2026-0039', 'employee': 'Rajesh Kumar', 'amount': 180.0, 'date': '2026-04-15', 'category': 'تواصل', 'status': 'approved', 'items': 1},
    {'id': 'EXP-2026-0038', 'employee': 'أحمد العتيبي', 'amount': 4500.0, 'date': '2026-04-10', 'category': 'تدريب', 'status': 'rejected', 'items': 2},
    {'id': 'EXP-2026-0037', 'employee': 'Maria Santos', 'amount': 95.0, 'date': '2026-04-08', 'category': 'مواصلات', 'status': 'reimbursed', 'items': 4},
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _reports;
    return _reports.where((r) => r['status'] == _filter).toList();
  }

  String _statusAr(String s) => switch (s) {
        'pending' => 'بانتظار الاعتماد',
        'approved' => 'معتمد',
        'rejected' => 'مرفوض',
        'reimbursed' => 'مدفوع',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'pending' => AC.warn,
        'approved' => AC.gold,
        'rejected' => AC.err,
        'reimbursed' => AC.ok,
        _ => AC.ts,
      };

  IconData _statusIcon(String s) => switch (s) {
        'pending' => Icons.pending,
        'approved' => Icons.check_circle,
        'rejected' => Icons.cancel,
        'reimbursed' => Icons.payments,
        _ => Icons.help,
      };

  double get _pendingTotal =>
      _reports.where((r) => r['status'] == 'pending').fold<double>(0, (a, r) => a + (r['amount'] as double));

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'تقارير المصاريف',
      subtitle: 'بانتظار الاعتماد: ${_pendingTotal.toStringAsFixed(0)} SAR',
      primaryCta: ApexCta(
        label: 'تقرير جديد',
        icon: Icons.receipt_long,
        onPressed: () => context.go('/receipt/capture'),
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _reports.length),
        for (final s in [
          ('pending', 'بانتظار', Icons.pending),
          ('approved', 'معتمد', Icons.check_circle),
          ('reimbursed', 'مدفوع', Icons.payments),
          ('rejected', 'مرفوض', Icons.cancel),
        ])
          ApexFilterChip(
            label: s.$2,
            selected: _filter == s.$1,
            onTap: () => setState(() => _filter = s.$1),
            icon: s.$3,
            count: _reports.where((r) => r['status'] == s.$1).length,
          ),
      ],
      items: _filtered,
      onRefresh: () async {},
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
        ApexChipLink('فواتير الموردين', '/app/erp/finance/purchase-bills', Icons.receipt_outlined),
        ApexChipLink('صندوق الموافقات', '/workflow/approvals', Icons.inbox),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.receipt_long,
        title: 'لا توجد تقارير مصاريف',
        description: 'الموظفون يرفعون مصاريفهم وتعتمدها مرة واحدة',
        primaryLabel: 'تقرير جديد',
        primaryIcon: Icons.add,
        onPrimary: () => context.go('/receipt/capture'),
      ),
      itemBuilder: (ctx, r) {
        final color = _statusColor(r['status'] as String);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(_statusIcon(r['status'] as String), color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['id']} — ${r['employee']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Row(children: [
                  Text('${r['category']} · ${r['items']} بنود',
                      style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  const SizedBox(width: 6),
                  Text('· ${r['date']}',
                      style: TextStyle(color: AC.ts, fontSize: 10.5, fontFamily: 'monospace')),
                ]),
                Text(_statusAr(r['status'] as String),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
            Text('${(r['amount'] as double).toStringAsFixed(0)} SAR',
                style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}
