/// APEX — Financial Ratios Dashboard
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class FinancialAnalysisScreen extends StatefulWidget {
  const FinancialAnalysisScreen({super.key});
  @override
  State<FinancialAnalysisScreen> createState() => _FinancialAnalysisScreenState();
}

class _FinancialAnalysisScreenState extends State<FinancialAnalysisScreen> {
  final _entityCtl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, double> _balances = {};   // classification totals

  Future<void> _load() async {
    final e = _entityCtl.text.trim();
    if (e.isEmpty) return setState(() => _error = 'أدخل Entity ID');
    setState(() { _loading = true; _error = null; });

    final tb = await ApiService.pilotTrialBalance(e);
    if (!mounted) return;
    if (!tb.success || tb.data == null) {
      setState(() { _loading = false; _error = tb.error ?? 'تعذّر تحميل الميزان'; });
      return;
    }

    final b = {'asset': 0.0, 'liability': 0.0, 'equity': 0.0, 'revenue': 0.0, 'expense': 0.0,
               'cash': 0.0, 'receivables': 0.0, 'inventory': 0.0, 'payables': 0.0};
    for (final r in ((tb.data['lines'] as List?) ?? [])) {
      final row = r as Map;
      final code = (row['account_code'] ?? '') as String;
      final d = double.tryParse('${row['debit'] ?? 0}') ?? 0;
      final c = double.tryParse('${row['credit'] ?? 0}') ?? 0;
      final net = d - c;
      if (code.startsWith('1')) b['asset'] = b['asset']! + net;
      else if (code.startsWith('2')) b['liability'] = b['liability']! + (-net);
      else if (code.startsWith('3')) b['equity'] = b['equity']! + (-net);
      else if (code.startsWith('4')) b['revenue'] = b['revenue']! + (-net);
      else if (code.startsWith('5')) b['expense'] = b['expense']! + net;

      // Subcategory buckets
      if (code == '1110' || code == '1120') b['cash'] = b['cash']! + net;
      else if (code == '1130') b['receivables'] = b['receivables']! + net;
      else if (code == '1140') b['inventory'] = b['inventory']! + net;
      else if (code == '2110' || code == '2130') b['payables'] = b['payables']! + (-net);
    }

    if (!mounted) return;
    setState(() { _loading = false; _balances = b; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('التحليل المالي — النسب الرئيسية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            _toolbar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')))
                      : _balances.isEmpty
                          ? _empty()
                          : _ratiosGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: AC.navy2,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _entityCtl,
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Entity ID',
                labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
                filled: true, fillColor: AC.navy3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.analytics, size: 16),
            label: const Text('احسب', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, color: AC.ts, size: 48),
          const SizedBox(height: 8),
          Text('أدخل Entity ID ثم اضغط احسب',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _ratiosGrid() {
    final a = _balances['asset']!;
    final l = _balances['liability']!;
    final eq = _balances['equity']!;
    final rev = _balances['revenue']!;
    final exp = _balances['expense']!;
    final cash = _balances['cash']!;
    final ar = _balances['receivables']!;
    final inv = _balances['inventory']!;
    final ap = _balances['payables']!;
    final net = rev - exp;
    final ca = cash + ar + inv;    // approximate current assets
    final cl = ap;                  // approximate current liabilities

    double _safe(double n, double d) => d == 0 ? 0 : (n / d);

    final ratios = <_Ratio>[
      _Ratio('نسبة التداول (Current)', _safe(ca, cl).toStringAsFixed(2),
             'الأصول المتداولة ÷ الالتزامات المتداولة', _safe(ca, cl) >= 1.5 ? AC.ok : AC.err, 'سيولة'),
      _Ratio('السيولة السريعة (Quick)', _safe(ca - inv, cl).toStringAsFixed(2),
             '(النقد + الذمم) ÷ الالتزامات', _safe(ca - inv, cl) >= 1.0 ? AC.ok : AC.err, 'سيولة'),
      _Ratio('النقدية / الالتزامات', _safe(cash, cl).toStringAsFixed(2),
             'نسبة التغطية النقدية', _safe(cash, cl) >= 0.2 ? AC.ok : AC.err, 'سيولة'),
      _Ratio('الرفع المالي (Debt-to-Equity)', _safe(l, eq).toStringAsFixed(2),
             'الالتزامات ÷ حقوق الملكية', _safe(l, eq) <= 1.0 ? AC.ok : AC.gold, 'رافعة'),
      _Ratio('الديون / الأصول', _safe(l, a).toStringAsFixed(2),
             'نسبة التمويل بالديون', _safe(l, a) <= 0.6 ? AC.ok : AC.err, 'رافعة'),
      _Ratio('هامش الربح الصافي', '${(_safe(net, rev) * 100).toStringAsFixed(1)}%',
             'صافي الدخل ÷ الإيرادات', net > 0 && _safe(net, rev) >= 0.1 ? AC.ok : AC.gold, 'ربحية'),
      _Ratio('العائد على الأصول (ROA)', '${(_safe(net, a) * 100).toStringAsFixed(1)}%',
             'صافي الدخل ÷ الأصول', _safe(net, a) >= 0.05 ? AC.ok : AC.gold, 'ربحية'),
      _Ratio('العائد على حقوق الملكية (ROE)', '${(_safe(net, eq) * 100).toStringAsFixed(1)}%',
             'صافي الدخل ÷ حقوق الملكية', _safe(net, eq) >= 0.1 ? AC.ok : AC.gold, 'ربحية'),
      _Ratio('دوران الذمم', _safe(rev, ar).toStringAsFixed(2),
             'الإيرادات ÷ الذمم المدينة', _safe(rev, ar) >= 6 ? AC.ok : AC.gold, 'كفاءة'),
    ];

    final grouped = <String, List<_Ratio>>{};
    for (final r in ratios) grouped.putIfAbsent(r.group, () => []).add(r);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _snapshot(a, l, eq, rev, exp, net),
          const SizedBox(height: 14),
          ...grouped.entries.map((e) => _groupCard(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _snapshot(double a, double l, double eq, double rev, double exp, double net) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.15), AC.gold.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisExtent: 60, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        children: [
          _snap('أصول', a, AC.ok),
          _snap('التزامات', l, AC.err),
          _snap('حقوق ملكية', eq, AC.gold),
          _snap('إيرادات', rev, AC.ok),
          _snap('مصروفات', exp, AC.err),
          _snap('صافي الدخل', net, net >= 0 ? AC.ok : AC.err),
        ],
      ),
    );
  }

  Widget _snap(String label, double v, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
        Text(v.toStringAsFixed(0),
            style: TextStyle(color: c, fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _groupCard(String title, List<_Ratio> ratios) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...ratios.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(width: 4, height: 28, color: r.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text(r.formula,
                          style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
                    ],
                  ),
                ),
                Text(r.value,
                    style: TextStyle(color: r.color, fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _Ratio {
  final String name;
  final String value;
  final String formula;
  final Color color;
  final String group;
  const _Ratio(this.name, this.value, this.formula, this.color, this.group);
}
