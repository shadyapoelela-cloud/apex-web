/// APEX Platform — Budget vs Actual Dashboard
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class BudgetActualScreen extends StatefulWidget {
  const BudgetActualScreen({super.key});
  @override
  State<BudgetActualScreen> createState() => _BudgetActualScreenState();
}

class _LineRow {
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController budget;
  final TextEditingController actual;
  final TextEditingController prior;
  String category;
  _LineRow({String c = '', String n = '', String b = '0',
    String a = '0', String p = '', this.category = 'opex'})
    : code = TextEditingController(text: c),
      name = TextEditingController(text: n),
      budget = TextEditingController(text: b),
      actual = TextEditingController(text: a),
      prior = TextEditingController(text: p);
  void dispose() { code.dispose(); name.dispose(); budget.dispose(); actual.dispose(); prior.dispose(); }
}

class _BudgetActualScreenState extends State<BudgetActualScreen> {
  final _entity = TextEditingController(text: 'أبيكس السعودية');
  final _period = TextEditingController(text: '2026-Q1');
  String _periodType = 'quarterly';
  final List<_LineRow> _rows = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _cats = const ['revenue', 'cogs', 'opex', 'capex'];
  final _periods = const ['monthly', 'quarterly', 'annual'];

  @override
  void initState() {
    super.initState();
    _rows.addAll([
      _LineRow(c: '4000', n: 'إيرادات مبيعات', b: '10000000', a: '10500000', p: '9200000', category: 'revenue'),
      _LineRow(c: '5000', n: 'تكلفة بضاعة مباعة', b: '6000000', a: '5800000', p: '5500000', category: 'cogs'),
      _LineRow(c: '5100', n: 'رواتب وأجور', b: '2000000', a: '2100000', p: '1900000', category: 'opex'),
      _LineRow(c: '5200', n: 'إيجارات', b: '500000', a: '490000', p: '480000', category: 'opex'),
    ]);
  }

  @override
  void dispose() {
    _entity.dispose(); _period.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'entity_name': _entity.text.trim(),
        'period': _period.text.trim(),
        'period_type': _periodType,
        'line_items': _rows.map((r) => {
          'account_code': r.code.text.trim(),
          'account_name': r.name.text.trim(),
          'category': r.category,
          'budget_amount': r.budget.text.trim(),
          'actual_amount': r.actual.text.trim(),
          if (r.prior.text.trim().isNotEmpty) 'prior_year_amount': r.prior.text.trim(),
        }).toList(),
      };
      final res = await ApiService.budgetAnalyse(body);
      if (!mounted) return;
      if (res.success && res.data is Map) {
        setState(() => _result = (res.data['data'] ?? res.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = res.error ?? 'فشل التحليل');
      }
    } catch (e) { if (mounted) setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('الميزانية مقابل الفعلي', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _sf(_entity, 'المنشأة', Icons.business)),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: _sf(_period, 'الفترة', Icons.date_range)),
          const SizedBox(width: 8),
          SizedBox(width: 130, child: DropdownButtonFormField<String>(
            value: _periodType, isDense: true, isExpanded: true,
            dropdownColor: AC.navy2,
            style: TextStyle(color: AC.gold, fontSize: 12),
            decoration: InputDecoration(
              labelText: 'النوع', labelStyle: TextStyle(color: AC.ts, fontSize: 11),
              filled: true, fillColor: AC.navy3, isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _periodType = v!),
          )),
        ]),
        const SizedBox(height: 8),
        ..._rows.asMap().entries.map((e) => _row(e.key, e.value)),
        OutlinedButton.icon(
          icon: Icon(Icons.add, color: AC.gold),
          label: Text('إضافة بند', style: TextStyle(color: AC.gold)),
          onPressed: () => setState(() => _rows.add(_LineRow())),
          style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
        ),
        const SizedBox(height: 14),
        if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
        SizedBox(height: 50, child: ElevatedButton.icon(
          onPressed: _loading ? null : _run,
          icon: _loading ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.analytics),
          label: const Text('تحليل الانحرافات'),
        )),
        if (_result != null) ..._renderResult(_result!),
      ]),
    ),
  );

  Widget _row(int i, _LineRow r) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Row(children: [
        SizedBox(width: 70, child: TextField(
          controller: r.code,
          style: TextStyle(color: AC.info, fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'الكود', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Expanded(child: TextField(
          controller: r.name,
          style: TextStyle(color: AC.tp, fontSize: 12),
          decoration: InputDecoration(hintText: 'اسم الحساب', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
        )),
        SizedBox(width: 90, child: DropdownButton<String>(
          value: r.category, isDense: true, isExpanded: true,
          dropdownColor: AC.navy2, underline: const SizedBox(),
          style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700),
          items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => r.category = v!),
        )),
        IconButton(
          icon: Icon(Icons.close, color: AC.err, size: 14),
          onPressed: _rows.length > 1 ? () {
            setState(() { r.dispose(); _rows.removeAt(i); });
          } : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
      Row(children: [
        Expanded(child: _nf(r.budget, 'الميزانية')),
        const SizedBox(width: 6),
        Expanded(child: _nf(r.actual, 'الفعلي')),
        const SizedBox(width: 6),
        Expanded(child: _nf(r.prior, 'السابق')),
      ]),
    ]),
  );

  List<Widget> _renderResult(Map d) {
    final status = d['overall_status'] as String;
    final color = status == 'favorable' ? AC.ok : status == 'unfavorable' ? AC.err : AC.info;
    final statusAr = status == 'favorable' ? 'إيجابي ✓' : status == 'unfavorable' ? 'سلبي ✗' : 'متوازن';
    final ni = d['net_income'] as Map?;
    final kpis = d['kpis'] as Map?;

    return [
      const SizedBox(height: 14),
      // Status banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(status == 'favorable' ? Icons.trending_up :
            status == 'unfavorable' ? Icons.trending_down : Icons.horizontal_rule,
            color: color, size: 28),
          Text(statusAr,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('صافي الدخل: ${ni?['actual'] ?? '-'}  (ميزانية: ${ni?['budget'] ?? '-'})',
            style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      // KPIs
      if (kpis != null) Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kvRow('نسبة الاستخدام', '${kpis['budget_utilization_pct']}%'),
          _kvRow('بنود فوق الميزانية', '${kpis['items_over_budget']}'),
          _kvRow('بنود تحت الميزانية', '${kpis['items_under_budget']}'),
          _kvRow('انحرافات جوهرية', '${kpis['critical_variances']}'),
        ]),
      ),
      // Category summaries
      if (d['category_summaries'] is List) ...[
        const SizedBox(height: 12),
        ...(d['category_summaries'] as List).map((c) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.navy3,
            borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Text(c['category'] ?? '',
              style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700))),
            Text('${c['variance']} (${c['variance_pct']}%)',
              style: TextStyle(
                color: c['type'] == 'favorable' ? AC.ok : c['type'] == 'unfavorable' ? AC.err : AC.ts,
                fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          ]),
        )),
      ],
      // Warnings
      if (d['warnings'] is List && (d['warnings'] as List).isNotEmpty) ...[
        const SizedBox(height: 10),
        ...((d['warnings'] as List).map((w) => Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AC.err.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AC.err.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber, color: AC.err, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(w.toString(),
              style: TextStyle(color: AC.err, fontSize: 11))),
          ]),
        ))),
      ],
    ];
  }

  Widget _kvRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: AC.tp, fontSize: 12,
        fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    ]),
  );

  Widget _sf(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
        filled: true, fillColor: AC.navy3, isDense: true,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _nf(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
    decoration: InputDecoration(hintText: hint, isDense: true,
      hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
  );
}
