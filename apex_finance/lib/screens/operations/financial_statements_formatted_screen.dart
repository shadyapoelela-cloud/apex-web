/// APEX — Formatted P&L + Balance Sheet from a live TB
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class FinancialStatementsFormattedScreen extends StatefulWidget {
  const FinancialStatementsFormattedScreen({super.key});
  @override
  State<FinancialStatementsFormattedScreen> createState() => _FSFormattedScreenState();
}

class _FSFormattedScreenState extends State<FinancialStatementsFormattedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _entityCtl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _pnl;
  Map<String, dynamic>? _bs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _entityCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final e = _entityCtl.text.trim();
    if (e.isEmpty) {
      setState(() => _error = 'أدخل Entity ID');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // 1) Get TB from pilot
    final tb = await ApiService.pilotTrialBalance(e);
    if (!mounted) return;
    if (!tb.success || tb.data == null) {
      setState(() { _loading = false; _error = tb.error ?? 'تعذر تحميل الميزان'; });
      return;
    }

    // Map pilot TB shape → fin_statements_service TBInput
    final tbData = tb.data as Map<String, dynamic>;
    final lines = ((tbData['lines'] as List?) ?? []).map((r) {
      final row = r as Map;
      return {
        'account_code': row['account_code'],
        'account_name': row['account_name'],
        'classification': _classifyAccount(row['account_code'] as String?),
        'debit': row['debit'],
        'credit': row['credit'],
      };
    }).toList();

    final tbInput = {
      'entity_name': 'APEX',
      'period_label': tbData['period_label'] ?? DateTime.now().toIso8601String().split('T').first,
      'currency': tbData['currency'] ?? 'SAR',
      'lines': lines,
      'opening_retained_earnings': 0,
    };

    final pnl = await ApiService.fsIncomeStatement(tbInput);
    final bs = await ApiService.fsBalanceSheet(tbInput);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _pnl = pnl.success ? (pnl.data as Map).cast<String, dynamic>() : null;
      _bs = bs.success ? (bs.data as Map).cast<String, dynamic>() : null;
      if (_pnl == null && _bs == null) _error = 'تعذّر بناء القوائم';
    });
  }

  // Simple code-range classifier — 1xxx asset, 2xxx liability, 3xxx equity,
  // 4xxx revenue, 5xxx expense. Override via real CoA metadata when wired.
  String _classifyAccount(String? code) {
    if (code == null || code.isEmpty) return 'asset';
    final first = code.trim()[0];
    switch (first) {
      case '1': return 'asset';
      case '2': return 'liability';
      case '3': return 'equity';
      case '4': return 'revenue';
      case '5': return 'expense';
      default: return 'asset';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('القوائم المالية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.ts,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'قائمة الدخل', icon: Icon(Icons.trending_up, size: 16)),
              Tab(text: 'قائمة المركز المالي', icon: Icon(Icons.balance, size: 16)),
            ],
          ),
        ),
        body: Column(
          children: [
            _toolbar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')))
                      : TabBarView(
                          controller: _tabs,
                          children: [_pnlTab(), _bsTab()],
                        ),
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
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('تحميل', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
        ],
      ),
    );
  }

  Widget _pnlTab() {
    if (_pnl == null) return _emptyHint();
    final rev = ((_pnl!['revenue_lines'] ?? _pnl!['revenues'] ?? []) as List).cast<Map>();
    final exp = ((_pnl!['expense_lines'] ?? _pnl!['expenses'] ?? []) as List).cast<Map>();
    final totalRev = _pnl!['total_revenue'] ?? _pnl!['revenue_total'] ?? 0;
    final totalExp = _pnl!['total_expenses'] ?? _pnl!['expense_total'] ?? 0;
    final net = _pnl!['net_income'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pnlHeaderCard(totalRev, totalExp, net),
          const SizedBox(height: 14),
          _section('الإيرادات', rev, AC.ok),
          const SizedBox(height: 10),
          _section('المصروفات', exp, AC.err),
        ],
      ),
    );
  }

  Widget _bsTab() {
    if (_bs == null) return _emptyHint();
    final assets = ((_bs!['asset_lines'] ?? _bs!['assets'] ?? []) as List).cast<Map>();
    final liabs = ((_bs!['liability_lines'] ?? _bs!['liabilities'] ?? []) as List).cast<Map>();
    final eqty = ((_bs!['equity_lines'] ?? _bs!['equity'] ?? []) as List).cast<Map>();

    final ta = _bs!['total_assets'] ?? 0;
    final tl = _bs!['total_liabilities'] ?? 0;
    final te = _bs!['total_equity'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.15), AC.gold.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(child: _kpi('إجمالي الأصول', ta, AC.ok)),
                Expanded(child: _kpi('إجمالي الالتزامات', tl, AC.err)),
                Expanded(child: _kpi('إجمالي حقوق الملكية', te, AC.gold)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section('الأصول', assets, AC.ok),
          const SizedBox(height: 10),
          _section('الالتزامات', liabs, AC.err),
          const SizedBox(height: 10),
          _section('حقوق الملكية', eqty, AC.gold),
        ],
      ),
    );
  }

  Widget _pnlHeaderCard(dynamic rev, dynamic exp, dynamic net) {
    final isPositive = (net is num) && net >= 0;
    final color = isPositive ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _kpi('إيرادات', rev, AC.ok)),
              Expanded(child: _kpi('مصروفات', exp, AC.err)),
            ],
          ),
          const SizedBox(height: 10),
          Text('صافي الدخل',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12)),
          Text('$net',
              style: TextStyle(
                color: color, fontFamily: 'Tajawal', fontSize: 28, fontWeight: FontWeight.w900,
              )),
          Text(isPositive ? 'ربح' : 'خسارة',
              style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _kpi(String label, dynamic value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5)),
        const SizedBox(height: 4),
        Text('$value',
            style: TextStyle(
              color: color, fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800,
            )),
      ],
    );
  }

  Widget _section(String title, List<Map> rows, Color color) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text('${r['account_code'] ?? ''}',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11))),
                Expanded(child: Text('${r['account_name'] ?? ''}',
                    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12))),
                Text('${r['net_balance'] ?? r['balance'] ?? r['amount'] ?? 0}',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _emptyHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_chart_outlined, color: AC.ts, size: 48),
          const SizedBox(height: 8),
          Text('أدخل Entity ID ثم اضغط تحميل',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          Text('نحصل على الميزان → نبني القوائم',
              style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 11)),
        ],
      ),
    );
  }
}
