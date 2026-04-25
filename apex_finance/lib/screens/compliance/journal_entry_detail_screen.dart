/// APEX — Journal Entry Detail (drill-down terminus)
/// ═══════════════════════════════════════════════════════════════════════
/// The end of the drill-anywhere chain:
///   TB → Account Ledger → JE Detail → Source Document
///
/// Shows header (number, date, status, memo), all journal lines with
/// debit/credit, and a button to jump to the source document if the JE
/// was auto-generated from an invoice / POS / etc.
///
/// Wires: GET /pilot/journal-entries/{je_id}
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class JournalEntryDetailScreen extends StatefulWidget {
  final String jeId;
  const JournalEntryDetailScreen({super.key, required this.jeId});

  @override
  State<JournalEntryDetailScreen> createState() => _JournalEntryDetailScreenState();
}

class _JournalEntryDetailScreenState extends State<JournalEntryDetailScreen> {
  Map<String, dynamic>? _je;
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
    final res = await ApiService.pilotJournalEntryDetail(widget.jeId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is Map) {
        _je = res.data as Map<String, dynamic>;
      } else {
        _error = res.error ?? 'فشل التحميل';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text(_je?['je_number'] ?? 'قيد يومي',
            style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _je == null
              ? Center(child: Text(_error ?? '-', style: TextStyle(color: AC.err)))
              : _detail(_je!),
    );
  }

  Widget _detail(Map<String, dynamic> je) {
    final lines = (je['lines'] as List?) ?? [];
    final status = je['status'] ?? '-';
    final isPosted = status == 'posted';
    final color = isPosted ? AC.ok : AC.warn;
    final source = je['source_type'];
    final sourceId = je['source_id'];
    final sourceRef = je['source_reference'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _headerCard(je, color, isPosted),
        const SizedBox(height: 12),
        if (source != null && sourceId != null) _sourceCard(source, sourceId as String, sourceRef),
        const SizedBox(height: 12),
        _linesCard(lines),
        const SizedBox(height: 12),
        _balanceCard(je),
        const ApexOutputChips(items: [
          ApexChipLink('قائمة القيود', '/accounting/je-list', Icons.book),
          ApexChipLink('شجرة الحسابات', '/accounting/coa-v2', Icons.account_tree),
          ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
          ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
        ]),
      ]),
    );
  }

  Widget _headerCard(Map<String, dynamic> je, Color statusColor, bool isPosted) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isPosted ? Icons.verified : Icons.edit_note, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${je['je_number'] ?? '-'}',
                  style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${je['status'] ?? ''}',
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${je['memo_ar'] ?? je['memo_en'] ?? ''}',
              style: TextStyle(color: AC.tp, fontSize: 13)),
          const Divider(),
          _kv('تاريخ القيد', '${je['je_date'] ?? '-'}'),
          if (je['posting_date'] != null) _kv('تاريخ الترحيل', '${je['posting_date']}'),
          _kv('النوع', '${je['kind'] ?? '-'}'),
          _kv('العملة', '${je['currency'] ?? '-'}'),
        ]),
      );

  Widget _sourceCard(String type, String sourceId, dynamic ref) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.08),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.attach_file, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('المصدر',
                  style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700)),
              Text('${_sourceLabel(type)}${ref != null ? " · $ref" : ""}',
                  style: TextStyle(color: AC.tp, fontSize: 13)),
            ]),
          ),
          if (type == 'sales_invoice')
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('فاتورة مبيعات: $sourceId'),
                ));
              },
              icon: Icon(Icons.open_in_new, color: AC.gold, size: 14),
              label: Text('عرض', style: TextStyle(color: AC.gold)),
            ),
        ]),
      );

  String _sourceLabel(String type) => switch (type) {
        'sales_invoice' => 'فاتورة مبيعات',
        'purchase_invoice' => 'فاتورة شراء',
        'pos_txn' => 'معاملة POS',
        'po_receipt' => 'إيصال شراء',
        'payroll' => 'مسير الرواتب',
        'je_reversal' => 'قيد عكسي',
        _ => type,
      };

  Widget _linesCard(List lines) => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.list, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('سطور القيد (${lines.length})',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr))),
            child: Row(children: [
              SizedBox(width: 28, child: Text('#', style: _hdr())),
              Expanded(child: Text('الوصف', style: _hdr())),
              SizedBox(width: 90, child: Text('مدين', style: _hdr(), textAlign: TextAlign.left)),
              SizedBox(width: 90, child: Text('دائن', style: _hdr(), textAlign: TextAlign.left)),
            ]),
          ),
          ...lines.map((line) {
            final l = line as Map;
            final dr = (l['functional_debit'] as num?)?.toDouble() ?? (l['debit_amount'] as num?)?.toDouble() ?? 0;
            final cr = (l['functional_credit'] as num?)?.toDouble() ?? (l['credit_amount'] as num?)?.toDouble() ?? 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
              ),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${l['line_number'] ?? ''}',
                    style: TextStyle(color: AC.ts, fontSize: 11))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l['description'] ?? ''}',
                      style: TextStyle(color: AC.tp, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (l['partner_name'] != null)
                    Text('${l['partner_name']}',
                        style: TextStyle(color: AC.ts, fontSize: 10)),
                ])),
                SizedBox(width: 90, child: Text(dr == 0 ? '-' : dr.toStringAsFixed(2),
                    style: TextStyle(color: dr > 0 ? AC.ok : AC.ts, fontFamily: 'monospace', fontSize: 11.5),
                    textAlign: TextAlign.left)),
                SizedBox(width: 90, child: Text(cr == 0 ? '-' : cr.toStringAsFixed(2),
                    style: TextStyle(color: cr > 0 ? AC.warn : AC.ts, fontFamily: 'monospace', fontSize: 11.5),
                    textAlign: TextAlign.left)),
              ]),
            );
          }),
        ]),
      );

  Widget _balanceCard(Map<String, dynamic> je) {
    final dr = (je['total_debit'] as num?)?.toDouble() ?? 0;
    final cr = (je['total_credit'] as num?)?.toDouble() ?? 0;
    final balanced = (dr - cr).abs() < 0.01;
    final color = balanced ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(balanced ? Icons.verified : Icons.error_outline, color: color),
        const SizedBox(width: 8),
        Text(balanced ? 'متوازن' : 'غير متوازن',
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('${dr.toStringAsFixed(2)} = ${cr.toStringAsFixed(2)}',
            style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12)),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: AC.ts, fontSize: 11))),
          Expanded(child: Text(v, style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'))),
        ]),
      );

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 10.5, fontWeight: FontWeight.w700);
}
