/// APEX — Workflow Approvals Inbox
/// /workflow/approvals — multi-step approval queue per user
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ApprovalsInboxScreen extends StatefulWidget {
  const ApprovalsInboxScreen({super.key});
  @override
  State<ApprovalsInboxScreen> createState() => _ApprovalsInboxScreenState();
}

class _ApprovalsInboxScreenState extends State<ApprovalsInboxScreen> {
  String _filter = 'pending';

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'APR-001', 'title': 'فاتورة شراء كبيرة',
      'object': 'BILL-2026-0142', 'amount': 95000.0,
      'requester': 'أحمد العتيبي', 'submitted_at': 'منذ 2 ساعة',
      'step': '2 من 3 — مدير مالي',
      'kind': 'bill', 'status': 'pending',
    },
    {
      'id': 'APR-002', 'title': 'تجاوز الموازنة — قسم التسويق',
      'object': 'BUDGET-MKT-04', 'amount': 12500.0,
      'requester': 'سارة المطيري', 'submitted_at': 'منذ 4 ساعات',
      'step': '1 من 2 — مدير العمليات',
      'kind': 'budget', 'status': 'pending',
    },
    {
      'id': 'APR-003', 'title': 'قيد جردي يدوي',
      'object': 'JE-2026-0142', 'amount': 50000.0,
      'requester': 'محمد القحطاني', 'submitted_at': 'منذ يوم',
      'step': '3 من 3 — الشريك',
      'kind': 'je', 'status': 'pending',
    },
    {
      'id': 'APR-004', 'title': 'مصروف سفر',
      'object': 'EXP-2026-0042', 'amount': 1250.0,
      'requester': 'أحمد العتيبي', 'submitted_at': 'منذ 3 أيام',
      'step': '2 من 2 — مدير مالي',
      'kind': 'expense', 'status': 'approved',
    },
    {
      'id': 'APR-005', 'title': 'إقرار VAT — أبريل',
      'object': 'VAT-2026-04', 'amount': 1725.0,
      'requester': 'النظام', 'submitted_at': 'منذ ساعة',
      'step': '1 من 1 — مالك',
      'kind': 'vat', 'status': 'pending',
    },
  ];

  IconData _kindIcon(String k) => switch (k) {
        'bill' => Icons.receipt,
        'budget' => Icons.attach_money,
        'je' => Icons.book,
        'expense' => Icons.receipt_long,
        'vat' => Icons.percent,
        _ => Icons.assignment,
      };

  Color _kindColor(String k) => switch (k) {
        'bill' => AC.warn,
        'budget' => AC.err,
        'je' => AC.gold,
        'expense' => AC.info,
        'vat' => AC.warn,
        _ => AC.ts,
      };

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((i) => i['status'] == _filter).toList();
  }

  double get _pendingTotal =>
      _items.where((i) => i['status'] == 'pending').fold<double>(0, (a, i) => a + (i['amount'] as double));

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'صندوق الموافقات',
      subtitle: 'بانتظار قرارك: ${_pendingTotal.toStringAsFixed(0)} SAR',
      filterChips: [
        ApexFilterChip(
            label: 'بانتظار',
            selected: _filter == 'pending',
            onTap: () => setState(() => _filter = 'pending'),
            icon: Icons.pending,
            count: _items.where((i) => i['status'] == 'pending').length),
        ApexFilterChip(
            label: 'مُعتمد',
            selected: _filter == 'approved',
            onTap: () => setState(() => _filter = 'approved'),
            icon: Icons.check_circle,
            count: _items.where((i) => i['status'] == 'approved').length),
        ApexFilterChip(
            label: 'مرفوض',
            selected: _filter == 'rejected',
            onTap: () => setState(() => _filter = 'rejected'),
            icon: Icons.cancel,
            count: _items.where((i) => i['status'] == 'rejected').length),
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _items.length),
      ],
      items: _filtered,
      onRefresh: () async {},
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('قائمة القيود', '/accounting/je-list', Icons.book),
        ApexChipLink('فواتير الموردين', '/purchase/bills', Icons.receipt_outlined),
        ApexChipLink('تقارير المصاريف', '/hr/expense-reports', Icons.receipt_long),
        ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.inbox,
        title: 'لا توجد طلبات اعتماد',
        description: 'كل ما يصل إليك سيظهر هنا',
      ),
      itemBuilder: (ctx, i) {
        final color = _kindColor(i['kind'] as String);
        final isPending = i['status'] == 'pending';
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AC.navy2,
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_kindIcon(i['kind'] as String), color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${i['title']}',
                    style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Text('${(i['amount'] as double).toStringAsFixed(0)} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline, size: 11, color: AC.ts),
              const SizedBox(width: 4),
              Text('${i['requester']}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 11, color: AC.ts),
              const SizedBox(width: 4),
              Text('${i['submitted_at']}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${i['step']}',
                  style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.close, color: AC.err, size: 14),
                    label: Text('رفض', style: TextStyle(color: AC.err)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AC.err)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('اعتمد'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AC.ok, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}
