/// APEX — Invoices List (sales invoices)
/// /app/erp/sales/invoices — filters: All / Issued / Paid / Overdue / Draft.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});
  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
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
    final res = await ApiService.pilotListSalesInvoices(entityId, limit: 200);
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

  bool _isOverdue(Map inv) {
    if (inv['status'] != 'issued') return false;
    final dueStr = inv['due_date'];
    if (dueStr == null) return false;
    try {
      final due = DateTime.parse(dueStr.toString());
      return due.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'draft' => _all.where((i) => i['status'] == 'draft').toList(),
      'issued' => _all.where((i) => i['status'] == 'issued' && !_isOverdue(i)).toList(),
      'paid' => _all.where((i) => i['status'] == 'paid').toList(),
      'overdue' => _all.where(_isOverdue).toList(),
      _ => _all,
    };
  }

  int _countWhere(bool Function(Map) test) => _all.where(test).length;

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'الفواتير',
      subtitle: '${_all.length} فاتورة',
      primaryCta: ApexCta(
        label: 'فاتورة جديدة',
        icon: Icons.add,
        onPressed: () => context.go('/sales'),
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
            count: _countWhere((i) => i['status'] == 'draft')),
        ApexFilterChip(
            label: 'صادرة',
            selected: _filter == 'issued',
            onTap: () => setState(() => _filter = 'issued'),
            icon: Icons.send,
            count: _countWhere((i) => i['status'] == 'issued' && !_isOverdue(i))),
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
            count: _countWhere((i) => i['status'] == 'paid')),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('أعمار AR', '/app/erp/sales/ar-aging', Icons.timeline),
        ApexChipLink('VAT Return', '/compliance/vat-return', Icons.receipt_long),
        ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
        ApexChipLink('التقويم الضريبي', '/compliance/tax-calendar', Icons.event),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'لا توجد فواتير',
        description: 'ابدأ بإصدار أول فاتورة من Today أو من دورة المبيعات',
        primaryLabel: 'فاتورة جديدة',
        primaryIcon: Icons.add,
        onPrimary: () => context.go('/sales'),
      ),
      itemBuilder: (ctx, inv) {
        final isDraft = inv['status'] == 'draft';
        final isIssued = inv['status'] == 'issued';
        final isPaid = inv['status'] == 'paid';
        final overdue = _isOverdue(inv);
        final color = isPaid
            ? AC.ok
            : overdue
                ? AC.err
                : isIssued
                    ? AC.gold
                    : AC.warn;
        final iconData = isPaid
            ? Icons.verified
            : overdue
                ? Icons.warning_amber
                : isDraft
                    ? Icons.edit_note
                    : Icons.send;
        return InkWell(
          onTap: () {
            final jeId = inv['journal_entry_id'] as String?;
            if (jeId != null) {
              context.go('/app/erp/finance/je-builder/$jeId');
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text('الفاتورة ${inv['invoice_number']} لم تُصدر بعد'),
              ));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(iconData, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${inv['invoice_number']}',
                      style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                      '${inv['issue_date']} — ${overdue ? "متأخرة" : (inv['status'] ?? '')}',
                      style: TextStyle(color: color, fontSize: 11)),
                ]),
              ),
              Text('${inv['total']} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              if (isIssued)
                ApexWhatsAppShareButton(
                  compact: true,
                  tooltip: 'مشاركة على واتساب',
                  message:
                      'فاتورة ${inv['invoice_number']} بمبلغ ${inv['total']} ريال — '
                      'تاريخ الإصدار ${inv['issue_date']}',
                ),
            ]),
          ),
        );
      },
    );
  }
}
