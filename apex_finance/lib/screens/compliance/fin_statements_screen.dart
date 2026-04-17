/// APEX Platform — Financial Statements Generator
/// ═══════════════════════════════════════════════════════════════
/// Enter a trial balance once, generate in tabs:
///   • Trial Balance (validated)
///   • Income Statement (Revenue − Expenses)
///   • Balance Sheet (Assets = Liabilities + Equity)
///   • Closing Entries (period close to Retained Earnings)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class FinStatementsScreen extends StatefulWidget {
  const FinStatementsScreen({super.key});
  @override
  State<FinStatementsScreen> createState() => _FinStatementsScreenState();
}

class _TBRowCtl {
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController debit;
  final TextEditingController credit;
  String classification;
  _TBRowCtl({String c = '', String n = '', String d = '0', String cr = '0',
    this.classification = 'asset'})
    : code = TextEditingController(text: c),
      name = TextEditingController(text: n),
      debit = TextEditingController(text: d),
      credit = TextEditingController(text: cr);
  void dispose() {
    code.dispose(); name.dispose();
    debit.dispose(); credit.dispose();
  }
}

class _FinStatementsScreenState extends State<FinStatementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _entityName = TextEditingController(text: 'شركة تجريبية');
  final _period = TextEditingController(text: 'Q1 2026');
  final _openingRe = TextEditingController(text: '0');
  final List<_TBRowCtl> _rows = [];

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _tbResult;
  Map<String, dynamic>? _isResult;
  Map<String, dynamic>? _bsResult;
  Map<String, dynamic>? _closeResult;

  final List<String> _classes = const [
    'asset', 'liability', 'equity', 'revenue', 'expense',
    'contra_asset', 'contra_equity',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    // Seed with a balanced sample
    _rows.addAll([
      _TBRowCtl(c: '1100', n: 'النقد', d: '5000', classification: 'asset'),
      _TBRowCtl(c: '1200', n: 'الذمم المدينة', d: '3000', classification: 'asset'),
      _TBRowCtl(c: '2100', n: 'الذمم الدائنة', cr: '2500', classification: 'liability'),
      _TBRowCtl(c: '3100', n: 'رأس المال', cr: '5000', classification: 'equity'),
      _TBRowCtl(c: '4000', n: 'المبيعات', cr: '8000', classification: 'revenue'),
      _TBRowCtl(c: '5000', n: 'المشتريات', d: '7500', classification: 'expense'),
    ]);
  }

  @override
  void dispose() {
    _tab.dispose();
    _entityName.dispose(); _period.dispose(); _openingRe.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Map _payload() => {
    'entity_name': _entityName.text.trim().isEmpty ? 'Entity' : _entityName.text.trim(),
    'period_label': _period.text.trim().isEmpty ? 'Period' : _period.text.trim(),
    'currency': 'SAR',
    'opening_retained_earnings': _openingRe.text.trim().isEmpty ? '0' : _openingRe.text.trim(),
    'lines': _rows.map((r) => {
      'account_code': r.code.text.trim().isEmpty ? '0' : r.code.text.trim(),
      'account_name': r.name.text.trim().isEmpty ? '-' : r.name.text.trim(),
      'classification': r.classification,
      'debit': r.debit.text.trim().isEmpty ? '0' : r.debit.text.trim(),
      'credit': r.credit.text.trim().isEmpty ? '0' : r.credit.text.trim(),
    }).toList(),
  };

  Future<void> _generate() async {
    setState(() {
      _loading = true; _error = null;
      _tbResult = null; _isResult = null; _bsResult = null; _closeResult = null;
    });
    try {
      final p = _payload();
      // Run all four in parallel
      final results = await Future.wait([
        ApiService.fsTrialBalance(p),
        ApiService.fsIncomeStatement(p),
        ApiService.fsBalanceSheet(p),
        ApiService.fsClosingEntries(p),
      ]);
      if (!mounted) return;
      for (final r in results) {
        if (!r.success) {
          setState(() => _error = r.error ?? 'فشل');
          break;
        }
      }
      setState(() {
        if (results[0].success) {
          _tbResult = (results[0].data['data'] ?? results[0].data) as Map<String, dynamic>;
        }
        if (results[1].success) {
          _isResult = (results[1].data['data'] ?? results[1].data) as Map<String, dynamic>;
        }
        if (results[2].success) {
          _bsResult = (results[2].data['data'] ?? results[2].data) as Map<String, dynamic>;
        }
        if (results[3].success) {
          _closeResult = (results[3].data['data'] ?? results[3].data) as Map<String, dynamic>;
        }
      });
    } catch (e) { if (mounted) setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('القوائم المالية', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
      bottom: TabBar(
        controller: _tab,
        indicatorColor: AC.gold,
        labelColor: AC.gold,
        unselectedLabelColor: AC.ts,
        tabs: const [
          Tab(icon: Icon(Icons.edit_note), text: 'ميزان المراجعة'),
          Tab(icon: Icon(Icons.trending_up), text: 'قائمة الدخل'),
          Tab(icon: Icon(Icons.account_balance), text: 'المركز المالي'),
          Tab(icon: Icon(Icons.lock_clock), text: 'قيود الإقفال'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: [
      _tbInputTab(),
      _isResultsTab(),
      _bsResultsTab(),
      _closingTab(),
    ]),
  );

  // ── Tab 1: TB Input + results
  Widget _tbInputTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('معلومات المنشأة'),
      Row(children: [
        Expanded(child: _strField(_entityName, 'الاسم', Icons.business)),
        const SizedBox(width: 8),
        Expanded(child: _strField(_period, 'الفترة', Icons.date_range)),
      ]),
      _numField(_openingRe, 'الأرباح المرحّلة الافتتاحية', Icons.history),
      _sectionTitle('ميزان المراجعة'),
      ..._rows.asMap().entries.map((e) => _tbRow(e.key, e.value)),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: Icon(Icons.add, color: AC.gold),
        label: Text('إضافة حساب', style: TextStyle(color: AC.gold)),
        onPressed: () => setState(() => _rows.add(_TBRowCtl())),
        style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
      ),
      const SizedBox(height: 14),
      if (_error != null) Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6)),
        child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
      ),
      const SizedBox(height: 8),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _generate,
        icon: _loading ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_graph),
        label: const Text('توليد القوائم المالية'))),
      const SizedBox(height: 16),
      if (_tbResult != null) _tbSummaryCard(_tbResult!),
    ]),
  );

  Widget _tbRow(int i, _TBRowCtl r) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Row(children: [
        SizedBox(width: 70, child: TextField(
          controller: r.code,
          style: TextStyle(color: AC.gold, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'كود', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
        )),
        Expanded(child: TextField(
          controller: r.name,
          style: TextStyle(color: AC.tp, fontSize: 12),
          decoration: InputDecoration(hintText: 'الاسم', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
        )),
        SizedBox(width: 120, child: DropdownButton<String>(
          value: r.classification,
          isDense: true,
          isExpanded: true,
          dropdownColor: AC.navy2,
          underline: const SizedBox(),
          style: TextStyle(color: AC.info, fontSize: 11, fontWeight: FontWeight.w700),
          items: _classes.map((c) =>
            DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => r.classification = v!),
        )),
        IconButton(
          icon: Icon(Icons.close, color: AC.err, size: 16),
          onPressed: _rows.length > 1 ? () {
            setState(() { r.dispose(); _rows.removeAt(i); });
          } : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
      Row(children: [
        Expanded(child: TextField(
          controller: r.debit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.ok, fontSize: 12, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'مدين', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
          onChanged: (v) {
            if (v.isNotEmpty && v != '0') {
              r.credit.text = '0';
            }
          },
        )),
        Container(width: 1, height: 16, color: AC.bdr),
        Expanded(child: TextField(
          controller: r.credit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.err, fontSize: 12, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'دائن', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
          onChanged: (v) {
            if (v.isNotEmpty && v != '0') {
              r.debit.text = '0';
            }
          },
        )),
      ]),
    ]),
  );

  Widget _tbSummaryCard(Map d) {
    final balanced = d['is_balanced'] == true;
    final color = balanced ? AC.ok : AC.err;
    final warnings = (d['warnings'] ?? []) as List;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(balanced ? Icons.verified : Icons.warning_amber_rounded,
            color: color),
          const SizedBox(width: 8),
          Text(balanced ? 'متوازن ✓' : 'غير متوازن',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        _kv('إجمالي المدين', '${d['total_debits']} SAR'),
        _kv('إجمالي الدائن', '${d['total_credits']} SAR'),
        if (!balanced) _kv('الفرق', '${d['difference']}', vc: AC.err),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...warnings.map((w) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $w', style: TextStyle(color: AC.warn, fontSize: 11)),
          )),
        ],
      ]),
    );
  }

  // ── Tab 2: IS
  Widget _isResultsTab() {
    if (_isResult == null) return _placeholder(Icons.trending_up,
      'اضغط "توليد القوائم المالية" أولاً');
    final d = _isResult!;
    final revs = (d['revenue_lines'] ?? []) as List;
    final exps = (d['expense_lines'] ?? []) as List;
    final ni = _parseDec(d['net_income']);
    final niColor = ni >= 0 ? AC.ok : AC.err;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              niColor.withValues(alpha: 0.14), AC.navy3],
              begin: Alignment.topRight, end: Alignment.bottomLeft),
            border: Border.all(color: niColor.withValues(alpha: 0.4), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Text('صافي الدخل', style: TextStyle(color: AC.ts, fontSize: 12)),
            Text('${d['net_income']} ${d['currency']}',
              style: TextStyle(color: niColor, fontSize: 28,
                fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            Text('هامش صافي: ${d['margin_pct']}%',
              style: TextStyle(color: niColor, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        _sectionTitle('الإيرادات'),
        ...revs.map((r) => _lineRow(r['account_name'], r['amount'], AC.ok)),
        Divider(color: AC.bdr),
        _lineRow('إجمالي الإيرادات', '${d['total_revenue']}', AC.ok, bold: true),
        const SizedBox(height: 16),
        _sectionTitle('المصروفات'),
        ...exps.map((r) => _lineRow(r['account_name'], r['amount'], AC.err)),
        Divider(color: AC.bdr),
        _lineRow('إجمالي المصروفات', '${d['total_expenses']}', AC.err, bold: true),
      ]),
    );
  }

  // ── Tab 3: BS
  Widget _bsResultsTab() {
    if (_bsResult == null) return _placeholder(Icons.account_balance,
      'اضغط "توليد القوائم المالية" أولاً');
    final d = _bsResult!;
    final assets = (d['assets'] ?? []) as List;
    final liab = (d['liabilities'] ?? []) as List;
    final eq = (d['equity'] ?? []) as List;
    final balanced = d['is_balanced'] == true;
    final color = balanced ? AC.ok : AC.err;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.14), AC.navy3],
              begin: Alignment.topRight, end: Alignment.bottomLeft),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Icon(balanced ? Icons.verified : Icons.warning_amber_rounded,
              color: color, size: 30),
            const SizedBox(height: 6),
            Text(balanced ? 'الميزانية متوازنة ✓' : 'غير متوازنة',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('الأصول = ${d['total_assets']} ${d['currency']}',
              style: TextStyle(color: AC.tp, fontFamily: 'monospace')),
            Text('الخصوم + حقوق الملكية = '
                '${_parseDec(d['total_liabilities']) + _parseDec(d['total_equity'])} ${d['currency']}',
              style: TextStyle(color: AC.tp, fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        _sectionTitle('الأصول'),
        ...assets.map((a) => _lineRow(a['account_name'], a['amount'], AC.ok)),
        Divider(color: AC.bdr),
        _lineRow('إجمالي الأصول', '${d['total_assets']}', AC.ok, bold: true),
        const SizedBox(height: 16),
        _sectionTitle('الخصوم'),
        ...liab.map((l) => _lineRow(l['account_name'], l['amount'], AC.warn)),
        Divider(color: AC.bdr),
        _lineRow('إجمالي الخصوم', '${d['total_liabilities']}', AC.warn, bold: true),
        const SizedBox(height: 16),
        _sectionTitle('حقوق الملكية'),
        ...eq.map((e) => _lineRow(e['account_name'], e['amount'], AC.info)),
        Divider(color: AC.bdr),
        _lineRow('إجمالي حقوق الملكية', '${d['total_equity']}', AC.info, bold: true),
      ]),
    );
  }

  // ── Tab 4: Closing
  Widget _closingTab() {
    if (_closeResult == null) return _placeholder(Icons.lock_clock,
      'اضغط "توليد القوائم المالية" أولاً');
    final d = _closeResult!;
    final rev = (d['close_revenue_entry'] ?? []) as List;
    final exp = (d['close_expense_entry'] ?? []) as List;
    final isum = (d['close_income_summary'] ?? []) as List;
    final ni = _parseDec(d['net_income']);
    final color = ni >= 0 ? AC.ok : AC.err;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy2,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(children: [
            _kv('إجمالي إيرادات تم إقفالها', '${d['total_revenue_closed']}'),
            _kv('إجمالي مصروفات تم إقفالها', '${d['total_expense_closed']}'),
            Divider(color: AC.bdr),
            _kv('صافي الدخل', '${d['net_income']}', vc: color, bold: true),
            _kv('الأرباح المرحّلة نهاية الفترة',
              '${d['retained_earnings_end']}', vc: AC.gold, bold: true),
          ]),
        ),
        const SizedBox(height: 16),
        if (rev.isNotEmpty) _closingEntryCard('قيد إقفال الإيرادات', rev),
        if (exp.isNotEmpty) const SizedBox(height: 12),
        if (exp.isNotEmpty) _closingEntryCard('قيد إقفال المصروفات', exp),
        if (isum.isNotEmpty) const SizedBox(height: 12),
        if (isum.isNotEmpty) _closingEntryCard('قيد إقفال ملخص الدخل', isum),
      ]),
    );
  }

  Widget _closingEntryCard(String title, List lines) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.purple.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.receipt_long, color: AC.purple, size: 16),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: AC.purple,
          fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      ...lines.map((l) {
        final d = _parseDec(l['debit']);
        final c = _parseDec(l['credit']);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 60, child: Text('${l['account_code']}',
              style: TextStyle(color: AC.gold, fontSize: 11, fontFamily: 'monospace'))),
            Expanded(child: Text('${l['account_name']}',
              style: TextStyle(color: AC.tp, fontSize: 12))),
            if (d > 0) Text('${l['debit']}',
              style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 12))
            else if (c > 0) Text('     ${l['credit']}',
              style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 12)),
          ]),
        );
      }),
    ]),
  );

  // ── helpers

  double _parseDec(dynamic v) {
    if (v == null) return 0.0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _lineRow(String name, String amount, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(name, style: TextStyle(color: AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
      Text(amount, style: TextStyle(color: color,
        fontSize: bold ? 14 : 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    ]),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _strField(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      style: TextStyle(color: AC.tp),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
        filled: true, fillColor: AC.navy3, isDense: true,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _numField(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
        filled: true, fillColor: AC.navy3, isDense: true,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );

  Widget _placeholder(IconData icon, String msg) => Container(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: AC.ts, size: 64),
      const SizedBox(height: 14),
      Text(msg, style: TextStyle(color: AC.ts, fontSize: 14),
        textAlign: TextAlign.center),
    ]),
  );
}
