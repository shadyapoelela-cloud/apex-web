/// APEX Platform — DSCR + Debt Capacity
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class DscrScreen extends StatefulWidget {
  const DscrScreen({super.key});
  @override
  State<DscrScreen> createState() => _DscrScreenState();
}

class _DscrScreenState extends State<DscrScreen> {
  final _fields = <String, TextEditingController>{
    'ebitda': TextEditingController(),
    'interest_expense': TextEditingController(),
    'current_principal_payments': TextEditingController(),
    'total_debt': TextEditingController(),
    'target_dscr': TextEditingController(text: '1.25'),
    'proposed_rate_pct': TextEditingController(text: '6'),
  };
  int _termYears = 5;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in _fields.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{'proposed_term_years': _termYears};
      _fields.forEach((k, c) { body[k] = c.text.trim().isEmpty ? '0' : c.text.trim(); });
      final r = await ApiService.dscrAnalyze(body);
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
    appBar: ApexAppBar(title: 'تغطية خدمة الدين (DSCR)'),
    body: LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 900;
      if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _form())),
        Container(width: 1, color: AC.bdr),
        Expanded(flex: 6, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _results())),
      ]);
    }),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('البيانات المالية'),
    _field('ebitda', 'EBITDA', Icons.trending_up),
    _field('interest_expense', 'مصروف الفائدة السنوي', Icons.percent),
    _field('current_principal_payments', 'الأصل المستحق سنوياً', Icons.payments),
    _field('total_debt', 'إجمالي الدين الحالي', Icons.account_balance),
    _section('معايير البنك'),
    _field('target_dscr', 'DSCR المطلوب (مثلاً 1.25)', Icons.flag),
    _field('proposed_rate_pct', 'معدل الفائدة المقترح %', Icons.percent),
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text('مدة القرض (سنوات):', style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(width: 10),
        Expanded(child: Slider(
          value: _termYears.toDouble(), min: 1, max: 30, divisions: 29,
          activeColor: AC.gold, label: '$_termYears',
          onChanged: (v) => setState(() => _termYears = v.round()),
        )),
        Text('$_termYears', style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
      ]),
    ),
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
        : const Icon(Icons.analytics),
      label: const Text('حلّل قدرة الاقتراض'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل البيانات لتحليل قدرة الاقتراض',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final decision = d['dscr_decision'] as String? ?? 'decline';
    final color = decision == 'approve' ? AC.ok
      : (decision == 'conditional' ? AC.warn : AC.err);
    final label = decision == 'approve' ? 'موافقة'
      : (decision == 'conditional' ? 'موافقة مشروطة' : 'رفض');
    final recs = (d['recommendations'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Hero
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(decision == 'approve' ? Icons.check_circle
              : (decision == 'conditional' ? Icons.info : Icons.cancel),
              color: color, size: 28),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontSize: 18,
              fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Text('DSCR', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text(d['dscr'] == null ? '—' : '${d['dscr']}',
            style: TextStyle(color: color, fontSize: 32,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6)),
            child: Text((d['dscr_benchmark'] as String).toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('إجمالي خدمة الدين', '${d['total_debt_service']} SAR'),
          if (d['interest_coverage'] != null)
            _kv('تغطية الفائدة', '${d['interest_coverage']}×'),
          if (d['leverage_ratio'] != null)
            _kv('الرفع المالي (Debt/EBITDA)', '${d['leverage_ratio']}×'),
          Divider(color: AC.bdr),
          _kv('الحد المتاح لخدمة دين إضافي',
            '${d['max_additional_annual_ds']} SAR/سنة', vc: AC.info),
          if (d['max_loan_amount'] != null)
            _kv('الحد الأقصى للقرض الإضافي',
              '${d['max_loan_amount']} SAR', vc: AC.gold, bold: true),
        ]),
      ),
      if (recs.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.08),
            border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.lightbulb_outline, color: AC.gold, size: 16),
              const SizedBox(width: 6),
              Text('توصيات', style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ...recs.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• $r', style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _field(String k, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _fields[k],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      decoration: InputDecoration(
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
}
