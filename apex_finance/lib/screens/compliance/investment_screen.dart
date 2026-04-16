/// APEX Platform — Investment Appraisal (NPV / IRR / Payback)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});
  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final List<TextEditingController> _cashFlowCtrls = [
    TextEditingController(),  // Period 0 (initial investment)
    TextEditingController(),  // Period 1
    TextEditingController(),  // Period 2
  ];
  final _rateC = TextEditingController(text: '10');
  final _labelC = TextEditingController(text: 'Project');

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in _cashFlowCtrls) {
      c.dispose();
    }
    _rateC.dispose();
    _labelC.dispose();
    super.dispose();
  }

  void _addPeriod() {
    setState(() => _cashFlowCtrls.add(TextEditingController()));
  }

  void _removePeriod(int idx) {
    if (_cashFlowCtrls.length <= 2) return;
    setState(() {
      _cashFlowCtrls[idx].dispose();
      _cashFlowCtrls.removeAt(idx);
    });
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final cfs = _cashFlowCtrls.map((c) =>
        c.text.trim().isEmpty ? '0' : c.text.trim()).toList();
      final rate = (double.tryParse(_rateC.text.trim()) ?? 10) / 100;
      final body = {
        'period_label': _labelC.text.trim().isEmpty ? 'Project' : _labelC.text.trim(),
        'cash_flows': cfs,
        'discount_rate': rate.toString(),
      };
      final r = await ApiService.investmentAnalyze(body);
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
      appBar: AppBar(
        title: Text('تقييم الاستثمار (NPV / IRR)', style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
      ),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 960;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [_form(), const SizedBox(height: 16), _results()]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: _form())),
          Container(width: 1, color: AC.bdr),
          Expanded(flex: 6, child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: _results())),
        ]);
      }),
    );
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('بيانات المشروع'),
    _textField(_labelC, 'اسم المشروع', Icons.label),
    Row(children: [
      Expanded(child: _numField(_rateC, 'معدل الخصم (%)', Icons.percent)),
    ]),
    const SizedBox(height: 12),
    _section('التدفقات النقدية'),
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: AC.info, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(
          'الفترة 0 = الاستثمار الأولي (قيمة سالبة). الفترات اللاحقة = التدفقات الداخلة.',
          style: TextStyle(color: AC.tp, fontSize: 11))),
      ]),
    ),
    const SizedBox(height: 10),
    ..._cashFlowCtrls.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 80, child: Text(
          e.key == 0 ? 'الفترة 0 (أولي)' : 'الفترة ${e.key}',
          style: TextStyle(color: e.key == 0 ? AC.err : AC.ts, fontSize: 12,
            fontWeight: FontWeight.w700))),
        Expanded(child: TextField(
          controller: e.value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: e.key == 0 ? '-100000' : '30000',
            hintStyle: TextStyle(color: AC.td, fontFamily: 'monospace'),
            filled: true, fillColor: AC.navy3,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AC.goldText)),
          ),
        )),
        if (_cashFlowCtrls.length > 2)
          IconButton(
            icon: Icon(Icons.delete_outline, color: AC.err, size: 18),
            onPressed: () => _removePeriod(e.key),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
      ]),
    )),
    TextButton.icon(
      onPressed: _addPeriod,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('إضافة فترة'),
    ),
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
        : const Icon(Icons.insights),
      label: const Text('حلّل الاستثمار', style: TextStyle(fontSize: 16)),
    )),
  ]);

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
          Icon(Icons.insights, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('أدخل التدفقات النقدية ثم اضغط "حلّل"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final decision = d['decision'] ?? 'marginal';
    final npv = double.tryParse((d['npv'] ?? '0').toString()) ?? 0;
    final rows = (d['rows'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;

    Color decisionColor = decision == 'accept' ? AC.ok
      : (decision == 'reject' ? AC.err : AC.warn);
    IconData decisionIcon = decision == 'accept' ? Icons.check_circle
      : (decision == 'reject' ? Icons.cancel : Icons.info_outline);
    String decisionLabel = decision == 'accept' ? 'قبول المشروع'
      : (decision == 'reject' ? 'رفض المشروع' : 'قرار حدّي');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Hero — decision + NPV
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [decisionColor.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: decisionColor.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(decisionIcon, color: decisionColor, size: 28),
            const SizedBox(width: 10),
            Text(decisionLabel, style: TextStyle(
              color: decisionColor, fontSize: 18, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          Text('صافي القيمة الحالية (NPV)',
            style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['npv']} SAR',
            style: TextStyle(
              color: npv >= 0 ? AC.ok : AC.err,
              fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      // Metrics grid
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8,
        children: [
          _metric('IRR', d['irr_pct'] == null ? '—' : '${d['irr_pct']}%',
            AC.gold, Icons.trending_up),
          _metric('مؤشر الربحية', d['profitability_index']?.toString() ?? '—',
            AC.info, Icons.bar_chart),
          _metric('فترة الاسترداد', d['simple_payback']?.toString() == null
            ? '—' : '${d['simple_payback']} سنة',
            AC.purple, Icons.schedule),
          _metric('المخصومة', d['discounted_payback']?.toString() == null
            ? '—' : '${d['discounted_payback']} سنة',
            AC.warn, Icons.update),
        ],
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      _rowsTable(rows),
    ]);
  }

  Widget _metric(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: AC.ts, fontSize: 11)),
      ]),
      const Spacer(),
      Text(value, style: TextStyle(
        color: color, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
    ]),
  );

  Widget _rowsTable(List rows) => Container(
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(children: [
          SizedBox(width: 40, child: Text('الفترة',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('التدفق',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('معامل الخصم',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('القيمة الحالية',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.end)),
        ]),
      ),
      ...rows.asMap().entries.map((e) {
        final r = e.value as Map;
        final cf = double.tryParse(r['cash_flow'].toString()) ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            SizedBox(width: 40, child: Text('${r['period']}',
              style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(child: Text('${r['cash_flow']}',
              style: TextStyle(
                color: cf >= 0 ? AC.ok : AC.err,
                fontSize: 11, fontFamily: 'monospace'),
              textAlign: TextAlign.center)),
            Expanded(child: Text('${r['discount_factor']}',
              style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
              textAlign: TextAlign.center)),
            Expanded(child: Text('${r['present_value']}',
              style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace',
                fontWeight: FontWeight.w600),
              textAlign: TextAlign.end)),
          ]),
        );
      }),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _textField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c, style: TextStyle(color: AC.tp),
        decoration: _inpDec(label, icon),
      ),
    );

  Widget _numField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        decoration: _inpDec(label, icon),
      ),
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

  Widget _warnCard(List warnings) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AC.warn.withValues(alpha: 0.08),
      border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: warnings.map<Widget>((w) => Text('• $w',
        style: TextStyle(color: AC.tp, fontSize: 11))).toList()),
  );
}
