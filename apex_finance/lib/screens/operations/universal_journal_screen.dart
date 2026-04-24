/// APEX — Universal Journal (SAP ACDOCA pattern + Odoo multi-view)
/// ═══════════════════════════════════════════════════════════
/// One unified view of every financial posting in the system — manual
/// JE + sales invoice auto-JE + purchase invoice auto-JE + POS auto-JE
/// + customer payment auto-JE — sliced by any dimension (project /
/// department / cost center), any account, any partner, any ledger.
///
/// Multi-view toggle switches between:
///   • List   (apex_data_table semantics — sortable, dense)
///   • Kanban (grouped by account category)
///   • Pivot  (sum by dimension)
///
/// Smart buttons on top show live counts of related documents.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_multi_view_host.dart';
import '../../core/theme.dart';

class UniversalJournalScreen extends StatefulWidget {
  const UniversalJournalScreen({super.key});
  @override
  State<UniversalJournalScreen> createState() => _UniversalJournalScreenState();
}

class _UniversalJournalScreenState extends State<UniversalJournalScreen> {
  final _entityCtl = TextEditingController();
  final _fromCtl = TextEditingController();
  final _toCtl = TextEditingController();
  String _ledger = 'L1';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void dispose() {
    _entityCtl.dispose();
    _fromCtl.dispose();
    _toCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final payload = <String, dynamic>{
      'status': 'posted',
      'ledger_id': _ledger,
      'limit': 500,
    };
    if (_entityCtl.text.trim().isNotEmpty) payload['entity_id'] = _entityCtl.text.trim();
    if (_fromCtl.text.trim().isNotEmpty) payload['start_date'] = _fromCtl.text.trim();
    if (_toCtl.text.trim().isNotEmpty) payload['end_date'] = _toCtl.text.trim();

    final res = await ApiService.universalJournalQuery(payload);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _rows = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = res.error; });
    }
  }

  // Smart-button counts derived from loaded rows.
  Map<String, int> _summary() {
    int postings = _rows.length;
    final uniqueJEs = <String>{};
    double debitSum = 0, creditSum = 0;
    final bySource = <String, int>{};
    for (final r in _rows) {
      uniqueJEs.add('${r['journal_entry_id']}');
      debitSum += (r['debit_amount'] ?? 0) as num;
      creditSum += (r['credit_amount'] ?? 0) as num;
      final s = (r['source_type'] ?? 'manual') as String;
      bySource[s] = (bySource[s] ?? 0) + 1;
    }
    return {
      'postings': postings,
      'je_count': uniqueJEs.length,
      'debit': debitSum.round(),
      'credit': creditSum.round(),
      'sources': bySource.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('السجل الموحّد — Universal Journal (ACDOCA)',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            _filterBar(),
            if (!_loading && _error == null && _rows.isNotEmpty) _smartButtons(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')))
                      : _rows.isEmpty
                          ? _empty()
                          : ApexMultiViewHost<Map<String, dynamic>>(
                              screenKey: 'universal_journal',
                              items: _rows,
                              modes: const [ApexViewMode.list, ApexViewMode.kanban, ApexViewMode.pivot],
                              initialMode: ApexViewMode.list,
                              listBuilder: (items) => _ListView(rows: items),
                              kanbanBuilder: (items) => _KanbanView(rows: items),
                              pivotBuilder: (items) => _PivotView(rows: items),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: AC.navy2,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _f(_entityCtl, 'Entity ID')),
              const SizedBox(width: 8),
              Expanded(child: _f(_fromCtl, 'من (YYYY-MM-DD)')),
              const SizedBox(width: 8),
              Expanded(child: _f(_toCtl, 'إلى')),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  value: _ledger,
                  dropdownColor: AC.navy2,
                  style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'الدفتر',
                    labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11),
                    filled: true, fillColor: AC.navy3, isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'L1', child: Text('L1 — IFRS')),
                    DropdownMenuItem(value: 'L2', child: Text('L2 — محلي')),
                    DropdownMenuItem(value: 'L3', child: Text('L3 — ضريبي')),
                  ],
                  onChanged: (v) => setState(() => _ledger = v ?? 'L1'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('استعلم', style: TextStyle(fontFamily: 'Tajawal')),
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smartButtons() {
    final s = _summary();
    return ApexSmartButtons(buttons: [
      ApexSmartButton(
        icon: Icons.list_alt, labelAr: 'إجمالي الأسطر',
        countText: '${s['postings']}', onTap: () {},
      ),
      ApexSmartButton(
        icon: Icons.receipt_long_outlined, labelAr: 'قيود',
        countText: '${s['je_count']}', onTap: () {},
      ),
      ApexSmartButton(
        icon: Icons.trending_up, labelAr: 'إجمالي مدين',
        countText: '${s['debit']}', accent: AC.ok, onTap: () {},
      ),
      ApexSmartButton(
        icon: Icons.trending_down, labelAr: 'إجمالي دائن',
        countText: '${s['credit']}', accent: AC.err, onTap: () {},
      ),
      ApexSmartButton(
        icon: Icons.hub_outlined, labelAr: 'مصادر مختلفة',
        countText: '${s['sources']}', onTap: () {},
      ),
    ]);
  }

  Widget _f(TextEditingController c, String label) => TextField(
    controller: c,
    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5),
    decoration: InputDecoration(
      labelText: label, labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11),
      filled: true, fillColor: AC.navy3, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    ),
  );

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hub_outlined, color: AC.ts, size: 48),
        const SizedBox(height: 10),
        Text('اضغط "استعلم" لعرض كل الحركات المالية كعرض موحّد',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
      ],
    ),
  );
}


// ── Three view builders ──────────────────────────────────

class _ListView extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _ListView({required this.rows});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final r = rows[i];
        final d = (r['debit_amount'] ?? 0) as num;
        final c = (r['credit_amount'] ?? 0) as num;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AC.navy2, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.gold.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text('${r['je_number']}',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11))),
              SizedBox(width: 80, child: Text('${r['account_code']}',
                  style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['account_name']}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5)),
                    Text('${r['je_date']} · ${r['source_type'] ?? 'manual'} · ${r['ledger_id']}',
                        style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5)),
                  ],
                ),
              ),
              SizedBox(width: 90, child: Text(d > 0 ? '${d.toStringAsFixed(2)}' : '—',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 12))),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: Text(c > 0 ? '${c.toStringAsFixed(2)}' : '—',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanView extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _KanbanView({required this.rows});
  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final cat = (r['category'] ?? 'أخرى') as String;
      grouped.putIfAbsent(cat, () => []).add(r);
    }
    final colors = {
      'asset': AC.ok, 'liability': AC.err,
      'equity': AC.gold, 'revenue': AC.ok, 'expense': AC.err,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((e) {
          final color = colors[e.key] ?? AC.ts;
          return Container(
            width: 260,
            margin: const EdgeInsetsDirectional.only(end: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AC.navy2, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 20, color: color),
                    const SizedBox(width: 8),
                    Text(e.key,
                        style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${e.value.length}',
                        style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ...e.value.take(15).map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(6)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['je_number']} — ${r['account_code']}',
                          style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 10.5)),
                      Text('${r['account_name']}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 11.5)),
                      Text('Dr ${r['debit_amount']} / Cr ${r['credit_amount']}',
                          style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 10)),
                    ],
                  ),
                )),
                if (e.value.length > 15)
                  Text('+ ${e.value.length - 15} أخرى...',
                      style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PivotView extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _PivotView({required this.rows});
  @override
  Widget build(BuildContext context) {
    // Pivot by account_code × category summing debit/credit.
    final pivot = <String, Map<String, num>>{};
    for (final r in rows) {
      final key = '${r['account_code']} - ${r['account_name']}';
      final cat = (r['category'] ?? '—') as String;
      pivot.putIfAbsent(key, () => {'asset': 0, 'liability': 0, 'equity': 0, 'revenue': 0, 'expense': 0, 'total_debit': 0, 'total_credit': 0});
      pivot[key]![cat] = (pivot[key]![cat] ?? 0) + (r['debit_amount'] as num) - (r['credit_amount'] as num);
      pivot[key]!['total_debit'] = (pivot[key]!['total_debit'] ?? 0) + (r['debit_amount'] as num);
      pivot[key]!['total_credit'] = (pivot[key]!['total_credit'] ?? 0) + (r['credit_amount'] as num);
    }
    final sorted = pivot.entries.toList()
      ..sort((a, b) => ((b.value['total_debit'] ?? 0) + (b.value['total_credit'] ?? 0))
          .compareTo((a.value['total_debit'] ?? 0) + (a.value['total_credit'] ?? 0)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AC.navy2),
          dataRowColor: WidgetStateProperty.all(AC.navy),
          columns: [
            DataColumn(label: Text('الحساب', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('إجمالي مدين', style: TextStyle(color: AC.ok, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)), numeric: true),
            DataColumn(label: Text('إجمالي دائن', style: TextStyle(color: AC.err, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)), numeric: true),
            DataColumn(label: Text('صافي', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)), numeric: true),
          ],
          rows: sorted.map((e) {
            final d = e.value['total_debit'] ?? 0;
            final c = e.value['total_credit'] ?? 0;
            final net = d - c;
            return DataRow(cells: [
              DataCell(Text(e.key, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 11.5))),
              DataCell(Text('${d.toStringAsFixed(2)}', style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 11.5))),
              DataCell(Text('${c.toStringAsFixed(2)}', style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 11.5))),
              DataCell(Text('${net.toStringAsFixed(2)}', style: TextStyle(color: net >= 0 ? AC.ok : AC.err, fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w700))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
