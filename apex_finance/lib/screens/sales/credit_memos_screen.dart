/// APEX — Credit & Debit Memos
/// /sales/memos — credit notes (returns/refunds) and debit notes
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';

class CreditMemosScreen extends StatefulWidget {
  const CreditMemosScreen({super.key});
  @override
  State<CreditMemosScreen> createState() => _CreditMemosScreenState();
}

class _CreditMemosScreenState extends State<CreditMemosScreen> {
  String _filter = 'all';

  final List<Map<String, dynamic>> _memos = [
    {'id': 'CM-2026-0012', 'type': 'credit', 'customer': 'شركة الرياض', 'amount': -2500.0, 'date': '2026-04-20', 'reason': 'مرتجع بضاعة', 'invoice_ref': 'INV-2026-0042'},
    {'id': 'DM-2026-0005', 'type': 'debit', 'customer': 'شركة الدمام', 'amount': 850.0, 'date': '2026-04-18', 'reason': 'رسوم نقل إضافية', 'invoice_ref': 'INV-2026-0041'},
    {'id': 'CM-2026-0011', 'type': 'credit', 'customer': 'شركة جدة', 'amount': -1200.0, 'date': '2026-04-15', 'reason': 'تخفيض سعر', 'invoice_ref': 'INV-2026-0038'},
    {'id': 'CM-2026-0010', 'type': 'credit', 'customer': 'شركة المدينة', 'amount': -5500.0, 'date': '2026-04-10', 'reason': 'إلغاء جزء من العقد', 'invoice_ref': 'INV-2026-0036'},
  ];

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'credit' => _memos.where((m) => m['type'] == 'credit').toList(),
      'debit' => _memos.where((m) => m['type'] == 'debit').toList(),
      _ => _memos,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'الإشعارات الدائنة/المدينة',
      subtitle: '${_memos.length} إشعار',
      primaryCta: ApexCta(
        label: 'إشعار جديد',
        icon: Icons.add,
        onPressed: () {},
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _memos.length),
        ApexFilterChip(
            label: 'دائنة (Credit)',
            selected: _filter == 'credit',
            onTap: () => setState(() => _filter = 'credit'),
            icon: Icons.remove_circle_outline,
            count: _memos.where((m) => m['type'] == 'credit').length),
        ApexFilterChip(
            label: 'مدينة (Debit)',
            selected: _filter == 'debit',
            onTap: () => setState(() => _filter = 'debit'),
            icon: Icons.add_circle_outline,
            count: _memos.where((m) => m['type'] == 'debit').length),
      ],
      items: _filtered,
      onRefresh: () async {},
      emptyState: ApexEmptyState(
        icon: Icons.note,
        title: 'لا توجد إشعارات',
        description: 'الإشعارات الدائنة للمرتجعات والإشعارات المدينة للرسوم الإضافية',
      ),
      itemBuilder: (ctx, m) {
        final isCredit = m['type'] == 'credit';
        final color = isCredit ? AC.warn : AC.ok;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(isCredit ? Icons.remove_circle_outline : Icons.add_circle_outline,
                  color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['id']} — ${m['customer']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${m['reason']} · مرتبط بـ ${m['invoice_ref']}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ]),
            ),
            Text('${(m['amount'] as double).toStringAsFixed(0)} SAR',
                style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );
  }
}
