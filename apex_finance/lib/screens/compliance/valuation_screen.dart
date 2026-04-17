/// APEX Platform — Business Valuation (WACC + DCF)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class ValuationScreen extends StatefulWidget {
  const ValuationScreen({super.key});
  @override
  State<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen> {
  // Inputs
  final _companyC = TextEditingController();
  final _waccC = TextEditingController(text: '10');
  final _growthC = TextEditingController(text: '2.5');
  final _netDebtC = TextEditingController(text: '0');
  final _sharesC = TextEditingController();
  final List<TextEditingController> _fcfCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_companyC, _waccC, _growthC, _netDebtC, _sharesC]) { c.dispose(); }
    for (final c in _fcfCtrls) { c.dispose(); }
    super.dispose();
  }

  void _addYear() => setState(() => _fcfCtrls.add(TextEditingController()));
  void _removeYear(int i) {
    if (_fcfCtrls.length <= 1) return;
    _fcfCtrls[i].dispose();
    setState(() => _fcfCtrls.removeAt(i));
  }

  Future<void> _analyze() async {
    final cfs = _fcfCtrls.where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim()).toList();
    if (cfs.isEmpty) { setState(() => _error = 'أدخل تدفقاً نقدياً واحداً على الأقل'); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'company_name': _companyC.text.trim(),
        'free_cash_flows': cfs,
        'wacc_pct': _waccC.text.trim().isEmpty ? '10' : _waccC.text.trim(),
        'terminal_growth_pct': _growthC.text.trim().isEmpty ? '2.5' : _growthC.text.trim(),
        'net_debt': _netDebtC.text.trim().isEmpty ? '0' : _netDebtC.text.trim(),
        if (_sharesC.text.trim().isNotEmpty) 'shares_outstanding': _sharesC.text.trim(),
      };
      final r = await ApiService.dcfAnalyze(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل');
      }
    } catch (e) { if (mounted) setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('تقييم الأعمال (DCF)', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2),
    body: LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 900;
      if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _form())),
        Container(width: 1, color: AC.bdr),
        Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _results())),
      ]);
    }),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(
      controller: _companyC,
      style: TextStyle(color: AC.tp),
      decoration: _inp('اسم الشركة', Icons.business),
    ),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _field(_waccC, 'WACC %', Icons.percent)),
      const SizedBox(width: 8),
      Expanded(child: _field(_growthC, 'نمو نهائي %', Icons.trending_up)),
    ]),
    Row(children: [
      Expanded(child: _field(_netDebtC, 'صافي الدين', Icons.account_balance)),
      const SizedBox(width: 8),
      Expanded(child: _field(_sharesC, 'عدد الأسهم (اختياري)', Icons.pie_chart)),
    ]),
    const SizedBox(height: 10),
    _section('التدفقات النقدية الحرة (FCF)'),
    ..._fcfCtrls.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 60, child: Text('السنة ${e.key + 1}',
          style: TextStyle(color: AC.ts, fontSize: 11))),
        Expanded(child: TextField(
          controller: e.value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '10000000',
            hintStyle: TextStyle(color: AC.td, fontFamily: 'monospace'),
            filled: true, fillColor: AC.navy3, isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none),
          ),
        )),
        if (_fcfCtrls.length > 1)
          IconButton(
            icon: Icon(Icons.close, color: AC.err, size: 16),
            onPressed: () => _removeYear(e.key),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
      ]),
    )),
    TextButton.icon(
      onPressed: _addYear,
      icon: const Icon(Icons.add, size: 14),
      label: const Text('سنة إضافية'),
    ),
    const SizedBox(height: 10),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _analyze,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.query_stats),
      label: const Text('احسب قيمة الشركة'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.query_stats, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل FCF التوقّعية لحساب قيمة الأعمال',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final years = (d['years'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Hero
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('القيمة المؤسسية (EV)', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['enterprise_value']} SAR',
            style: TextStyle(color: AC.gold, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Divider(color: AC.bdr, height: 16),
          _kv('PV الصريح', '${d['pv_explicit_sum']}'),
          _kv('PV القيمة النهائية', '${d['terminal_pv']}'),
          Divider(color: AC.bdr),
          _kv('صافي الدين', '${d['net_debt']}', vc: AC.warn),
          _kv('قيمة حقوق الملكية', '${d['equity_value']}', vc: AC.ok, bold: true),
          if (d['value_per_share'] != null)
            _kv('قيمة السهم', '${d['value_per_share']} SAR',
              vc: AC.gold, bold: true),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
            border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map<Widget>((w) => Text('• $w',
              style: TextStyle(color: AC.tp, fontSize: 11))).toList()),
        ),
      ],
      const SizedBox(height: 12),
      _yearsTable(years),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الافتراضات', style: TextStyle(
            color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          _kv('WACC', '${d['wacc_pct']}%'),
          _kv('النمو النهائي', '${d['terminal_growth_pct']}%'),
          _kv('FCF السنة التالية (افتراضي)', '${d['terminal_fcf']}'),
        ]),
      ),
    ]);
  }

  Widget _yearsTable(List years) => Container(
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(children: [
          SizedBox(width: 50, child: Text('السنة',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('FCF',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('معامل الخصم',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('القيمة الحالية',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.end)),
        ])),
      ...years.map((y) {
        final m = y as Map;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            SizedBox(width: 50, child: Text('${m['year']}',
              style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700))),
            Expanded(child: Text('${m['fcf']}',
              style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
              textAlign: TextAlign.center)),
            Expanded(child: Text('${m['discount_factor']}',
              style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
              textAlign: TextAlign.center)),
            Expanded(child: Text('${m['present_value']}',
              style: TextStyle(color: AC.ok, fontSize: 11,
                fontFamily: 'monospace', fontWeight: FontWeight.w700),
              textAlign: TextAlign.end)),
          ]),
        );
      }),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _field(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      decoration: _inp(label, icon),
    ),
  );

  InputDecoration _inp(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AC.goldText, size: 18),
    filled: true, fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts, fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AC.goldText)),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
