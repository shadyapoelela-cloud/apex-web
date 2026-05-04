/// APEX — Bills List (purchase invoices)
/// /purchase/bills — mirror of Invoices List
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});
  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListPurchaseInvoices(entityId, limit: 200);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error;
      }
    });
  }

  bool _isOverdue(Map b) {
    if (b['status'] != 'posted' && b['status'] != 'issued') return false;
    final dueStr = b['due_date'];
    if (dueStr == null) return false;
    try {
      return DateTime.parse(dueStr.toString()).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'draft' => _all.where((b) => b['status'] == 'draft').toList(),
      'posted' => _all.where((b) => b['status'] == 'posted' && !_isOverdue(b)).toList(),
      'paid' => _all.where((b) => b['status'] == 'paid').toList(),
      'overdue' => _all.where(_isOverdue).toList(),
      _ => _all,
    };
  }

  int _countWhere(bool Function(Map) test) => _all.where(test).length;

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'فواتير الموردين',
      subtitle: '${_all.length} فاتورة',
      primaryCta: ApexCta(
        label: 'فاتورة جديدة',
        icon: Icons.add,
        onPressed: () => context.go('/purchase'),
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _all.length),
        ApexFilterChip(
            label: 'مسودة',
            selected: _filter == 'draft',
            onTap: () => setState(() => _filter = 'draft'),
            icon: Icons.edit_note,
            count: _countWhere((b) => b['status'] == 'draft')),
        ApexFilterChip(
            label: 'مرحّلة',
            selected: _filter == 'posted',
            onTap: () => setState(() => _filter = 'posted'),
            icon: Icons.check,
            count: _countWhere((b) => b['status'] == 'posted' && !_isOverdue(b))),
        ApexFilterChip(
            label: 'متأخرة',
            selected: _filter == 'overdue',
            onTap: () => setState(() => _filter = 'overdue'),
            icon: Icons.warning_amber_outlined,
            count: _countWhere(_isOverdue)),
        ApexFilterChip(
            label: 'مدفوعة',
            selected: _filter == 'paid',
            onTap: () => setState(() => _filter = 'paid'),
            icon: Icons.verified,
            count: _countWhere((b) => b['status'] == 'paid')),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('أعمار AP', '/purchase/aging', Icons.timeline),
        ApexChipLink('استقطاع المصدر WHT', '/compliance/wht-v2', Icons.percent),
        ApexChipLink('VAT Return', '/compliance/vat-return', Icons.receipt_long),
        ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.receipt_outlined,
        title: 'لا توجد فواتير شراء',
        description: 'سجّل فاتورة الشراء الأولى من دورة المشتريات',
        primaryLabel: 'فاتورة شراء جديدة',
        primaryIcon: Icons.add,
        onPrimary: () => context.go('/purchase'),
      ),
      itemBuilder: (ctx, b) {
        final isDraft = b['status'] == 'draft';
        final isPosted = b['status'] == 'posted';
        final isPaid = b['status'] == 'paid';
        final overdue = _isOverdue(b);
        final color = isPaid
            ? AC.ok
            : overdue
                ? AC.err
                : isPosted
                    ? AC.gold
                    : AC.warn;
        final iconData = isPaid
            ? Icons.verified
            : overdue
                ? Icons.warning_amber
                : isDraft
                    ? Icons.edit_note
                    : Icons.check;
        return InkWell(
          onTap: () {
            final jeId = b['journal_entry_id'] as String?;
            if (jeId != null) context.go('/app/erp/finance/je-builder/$jeId');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(iconData, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b['bill_number'] ?? b['invoice_number'] ?? '-'}',
                      style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${b['issue_date'] ?? ''} — ${overdue ? "متأخرة" : (b['status'] ?? '')}',
                      style: TextStyle(color: color, fontSize: 11)),
                ]),
              ),
              Text('${b['total']} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    );
  }
}
