/// APEX — Account Ledger (drill-down from Trial Balance)
/// ═══════════════════════════════════════════════════════════════════════
/// Click any account in the TB → land here → see every posting that hits
/// this account, with running balance.
///
/// Wires `GET /pilot/accounts/{account_id}/ledger`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class AccountLedgerScreen extends StatefulWidget {
  final String accountId;
  final String? accountCode;
  final String? accountName;
  const AccountLedgerScreen({
    super.key,
    required this.accountId,
    this.accountCode,
    this.accountName,
  });

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await ApiService.pilotAccountLedger(
      widget.accountId,
      startDate: '${today.year}-01-01',
      endDate: fmt(today),
      limit: 500,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is Map) {
        _data = res.data as Map<String, dynamic>;
      } else {
        _error = res.error ?? 'فشل التحميل';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.accountCode ?? '';
    final name = widget.accountName ?? '';
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('دفتر الأستاذ — $code $name',
            style: TextStyle(color: AC.gold, fontSize: 14)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AC.err)))
              : _data == null
                  ? Center(
                      child: Text('لا توجد حركات',
                          style: TextStyle(color: AC.ts)))
                  : _ledgerView(_data!),
    );
  }

  Widget _ledgerView(Map<String, dynamic> d) {
    final rows = (d['rows'] as List?) ?? [];
    final opening = (d['opening_balance'] as num?)?.toDouble() ?? 0;
    final closing = (d['closing_balance'] as num?)?.toDouble() ?? 0;
    final totalDr = (d['total_debit'] as num?)?.toDouble() ?? 0;
    final totalCr = (d['total_credit'] as num?)?.toDouble() ?? 0;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        color: AC.navy2,
        child: Row(children: [
          Expanded(child: _summaryItem('رصيد افتتاحي', opening)),
          Expanded(child: _summaryItem('إجمالي مدين', totalDr, color: AC.ok)),
          Expanded(child: _summaryItem('إجمالي دائن', totalCr, color: AC.warn)),
          Expanded(child: _summaryItem('رصيد ختامي', closing, color: AC.gold)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: AC.navy3,
        child: Row(children: [
          SizedBox(width: 90, child: Text('التاريخ', style: _hdr())),
          SizedBox(width: 100, child: Text('JE', style: _hdr())),
          Expanded(child: Text('الوصف', style: _hdr())),
          SizedBox(width: 100, child: Text('مدين', style: _hdr(), textAlign: TextAlign.left)),
          SizedBox(width: 100, child: Text('دائن', style: _hdr(), textAlign: TextAlign.left)),
          SizedBox(width: 110, child: Text('الرصيد', style: _hdr(), textAlign: TextAlign.left)),
        ]),
      ),
      Expanded(
        child: rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('لا توجد حركات في هذه الفترة',
                      style: TextStyle(color: AC.ts, fontSize: 13)),
                ),
              )
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    Divider(color: AC.bdr.withValues(alpha: 0.5), height: 1),
                itemBuilder: (_, i) {
                  final r = rows[i] as Map;
                  final jeId = r['journal_entry_id'] as String?;
                  return InkWell(
                    onTap: jeId == null
                        ? null
                        : () => context.go('/app/erp/finance/je-builder/$jeId'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(children: [
                        SizedBox(
                            width: 90,
                            child: Text('${r['posting_date'] ?? '-'}',
                                style: _cell())),
                        SizedBox(
                            width: 100,
                            child: Text('${r['je_number'] ?? '-'}',
                                style: _cell(color: AC.gold))),
                        Expanded(
                            child: Text('${r['description'] ?? r['memo'] ?? '-'}',
                                style: _cell(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        SizedBox(
                            width: 100,
                            child: Text(_fmt(r['debit_amount']),
                                style: _cell(color: AC.ok),
                                textAlign: TextAlign.left)),
                        SizedBox(
                            width: 100,
                            child: Text(_fmt(r['credit_amount']),
                                style: _cell(color: AC.warn),
                                textAlign: TextAlign.left)),
                        SizedBox(
                            width: 110,
                            child: Text(_fmt(r['running_balance']),
                                style: _cell(
                                    color: AC.gold, weight: FontWeight.w700),
                                textAlign: TextAlign.left)),
                        if (jeId != null) Icon(Icons.chevron_left, color: AC.ts, size: 12),
                      ]),
                    ),
                  );
                },
              ),
      ),
      const ApexOutputChips(items: [
        ApexChipLink('شجرة الحسابات', '/accounting/coa-v2', Icons.account_tree),
        ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
        ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
        ApexChipLink('إقفال الفترة', '/operations/period-close', Icons.lock_clock),
      ]),
    ]);
  }

  Widget _summaryItem(String label, double v, {Color? color}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: AC.ts, fontSize: 11)),
        Text(v.toStringAsFixed(2),
            style: TextStyle(
                color: color ?? AC.tp,
                fontSize: 16,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700)),
      ]);

  TextStyle _hdr() => TextStyle(
      color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700);

  TextStyle _cell({Color? color, FontWeight? weight}) => TextStyle(
      color: color ?? AC.tp,
      fontSize: 11.5,
      fontFamily: 'monospace',
      fontWeight: weight);

  String _fmt(dynamic v) {
    if (v == null) return '-';
    if (v is num) return v == 0 ? '-' : v.toStringAsFixed(2);
    final n = double.tryParse(v.toString()) ?? 0;
    return n == 0 ? '-' : n.toStringAsFixed(2);
  }
}
