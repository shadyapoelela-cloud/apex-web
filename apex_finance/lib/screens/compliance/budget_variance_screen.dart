/// APEX Platform — Budget vs Actual variance analysis
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class _BudgetLine {
  final nameC = TextEditingController();
  final budgetC = TextEditingController();
  final actualC = TextEditingController();
  String kind = 'revenue';
  void dispose() {
    nameC.dispose();
    budgetC.dispose();
    actualC.dispose();
  }
}

class BudgetVarianceScreen extends StatefulWidget {
  const BudgetVarianceScreen({super.key});
  @override
  State<BudgetVarianceScreen> createState() => _BudgetVarianceScreenState();
}

class _BudgetVarianceScreenState extends State<BudgetVarianceScreen> {
  final _periodC = TextEditingController(text: '${DateTime.now().year}-Q1');
  final List<_BudgetLine> _lines = [
    _BudgetLine()..kind = 'revenue',
    _BudgetLine()..kind = 'expense',
  ];

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _periodC.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine(String kind) {
    setState(() => _lines.add(_BudgetLine()..kind = kind));
  }

  void _removeLine(int idx) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[idx].dispose();
      _lines.removeAt(idx);
    });
  }

  Future<void> _analyze() async {
    final valid = _lines.where((l) =>
      l.nameC.text.trim().isNotEmpty &&
      l.budgetC.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      setState(() => _error = 'أدخل بنداً واحداً على الأقل مع الاسم والميزانية');
      return;
    }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'period_label': _periodC.text.trim().isEmpty ? 'FY' : _periodC.text.trim(),
        'lines': _lines.where((l) => l.nameC.text.trim().isNotEmpty).map((l) => {
          'name': l.nameC.text.trim(),
          'kind': l.kind,
          'budget': l.budgetC.text.trim().isEmpty ? '0' : l.budgetC.text.trim(),
          'actual': l.actualC.text.trim().isEmpty ? '0' : l.actualC.text.trim(),
        }).toList(),
      };
      final r = await ApiService.budgetVariance(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل التحليل');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: ApexAppBar(title: 'الميزانية مقابل الفعلي'),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 960;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [_form(), const SizedBox(height: 16), _results()]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: _form())),
          Container(width: 1, color: AC.bdr),
          Expanded(flex: 5, child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: _results())),
        ]);
      }),
    );
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('الفترة'),
    TextField(
      controller: _periodC,
      style: TextStyle(color: AC.tp),
      decoration: _inpDec('مسمى الفترة', Icons.calendar_today),
    ),
    const SizedBox(height: 14),
    _section('بنود الميزانية'),
    ..._lines.asMap().entries.map((e) => _lineCard(e.key, e.value)),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _addLine('revenue'),
        icon: Icon(Icons.add, color: AC.ok, size: 16),
        label: Text('إيراد', style: TextStyle(color: AC.ok)),
      )),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _addLine('expense'),
        icon: Icon(Icons.add, color: AC.warn, size: 16),
        label: Text('مصروف', style: TextStyle(color: AC.warn)),
      )),
    ]),
    const SizedBox(height: 12),
    if (_error != null) Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 54, child: ElevatedButton.icon(
      onPressed: _loading ? null : _analyze,
      icon: _loading
        ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.compare_arrows),
      label: const Text('حلّل الانحراف', style: TextStyle(fontSize: 16)),
    )),
  ]);

  Widget _lineCard(int idx, _BudgetLine line) {
    final color = line.kind == 'revenue' ? AC.ok : AC.warn;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(line.kind == 'revenue' ? 'إيراد' : 'مصروف',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: line.nameC,
            style: TextStyle(color: AC.tp, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'اسم البند',
              hintStyle: TextStyle(color: AC.td, fontSize: 12),
              filled: true, fillColor: AC.navy3,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none),
            ),
          )),
          if (_lines.length > 1)
            IconButton(
              icon: Icon(Icons.close, color: AC.err, size: 16),
              onPressed: () => _removeLine(idx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(
            controller: line.budgetC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'الميزانية',
              hintStyle: TextStyle(color: AC.td, fontSize: 11),
              filled: true, fillColor: AC.navy3,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none),
            ),
          )),
          const SizedBox(width: 6),
          Expanded(child: TextField(
            controller: line.actualC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'الفعلي',
              hintStyle: TextStyle(color: AC.td, fontSize: 11),
              filled: true, fillColor: AC.navy3,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _results() {
    if (_result == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AC.navy2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.compare_arrows, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('أضف بنود الميزانية والفعلي ثم اضغط "حلّل"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final totals = (d['totals'] ?? {}) as Map;
    final lines = (d['lines'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;

    final netVar = double.tryParse((totals['net_variance'] ?? '0').toString()) ?? 0;
    final netColor = netVar >= 0 ? AC.ok : AC.err;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Hero net variance
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [netColor.withValues(alpha: 0.12), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: netColor.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('صافي الانحراف',
            style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${netVar >= 0 ? '+' : ''}${totals['net_variance']}',
            style: TextStyle(
              color: netColor, fontSize: 30,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          if (totals['net_variance_pct'] != null)
            Text('(${totals['net_variance_pct']}% عن الميزانية)',
              style: TextStyle(color: AC.ts, fontSize: 12)),
          Divider(color: AC.bdr, height: 16),
          _kv('ميزانية الإيرادات', '${totals['revenue_budget']}'),
          _kv('الإيرادات الفعلية', '${totals['revenue_actual']}', vc: AC.ok),
          Divider(color: AC.bdr, height: 14),
          _kv('ميزانية المصروفات', '${totals['expense_budget']}'),
          _kv('المصروفات الفعلية', '${totals['expense_actual']}', vc: AC.warn),
          Divider(color: AC.bdr, height: 14),
          _kv('صافي الفترة (ميزانية)', '${totals['net_budget']}'),
          _kv('صافي الفترة (فعلي)', '${totals['net_actual']}',
            vc: AC.gold, bold: true),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AC.warn.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map<Widget>((w) => Text('• $w',
              style: TextStyle(color: AC.tp, fontSize: 11))).toList()),
        ),
      ],
      const SizedBox(height: 14),
      // Line-by-line table
      Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              Text('التفصيل بحسب البند',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
          ...lines.asMap().entries.map((e) {
            final ln = e.value as Map;
            final isLast = e.key == lines.length - 1;
            final isFav = ln['favourable'] == true;
            final sev = ln['severity'] as String? ?? 'ok';
            final color = sev == 'risk' ? AC.err
              : (sev == 'watch' ? AC.warn : AC.ok);
            final kind = ln['kind'] as String;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (kind == 'revenue' ? AC.ok : AC.warn).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(kind == 'revenue' ? 'إيراد' : 'مصروف',
                        style: TextStyle(
                          color: kind == 'revenue' ? AC.ok : AC.warn,
                          fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ln['name']?.toString() ?? '',
                      style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700))),
                    Icon(isFav ? Icons.trending_up : Icons.trending_down,
                      color: color, size: 14),
                    const SizedBox(width: 4),
                    if (ln['variance_pct'] != null)
                      Text('${ln['variance_pct']}%',
                        style: TextStyle(color: color, fontSize: 12,
                          fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('ميزانية: ${ln['budget']}',
                      style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace'))),
                    Expanded(child: Text('فعلي: ${ln['actual']}',
                      style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'))),
                    Expanded(child: Text(
                      'فرق: ${ln['variance_amount']}',
                      style: TextStyle(
                        color: color, fontSize: 11, fontFamily: 'monospace',
                        fontWeight: FontWeight.w700),
                      textAlign: TextAlign.end)),
                  ]),
                ]),
              ),
              if (!isLast) Divider(color: AC.bdr, height: 1),
            ]);
          }),
        ]),
      ),
    ]);
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  InputDecoration _inpDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AC.goldText, size: 18),
    filled: true, fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts, fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AC.goldText)),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
