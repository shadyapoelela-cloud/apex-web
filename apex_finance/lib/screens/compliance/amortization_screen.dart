/// APEX Platform — Loan Amortization Schedule
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class AmortizationScreen extends StatefulWidget {
  const AmortizationScreen({super.key});
  @override
  State<AmortizationScreen> createState() => _AmortizationScreenState();
}

class _AmortizationScreenState extends State<AmortizationScreen> {
  final _principalC = TextEditingController();
  final _rateC = TextEditingController(text: '6');
  final _yearsC = TextEditingController(text: '5');
  String _method = 'fixed_payment';
  int _periodsPerYear = 12;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _principalC.dispose();
    _rateC.dispose();
    _yearsC.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final p = double.tryParse(_principalC.text.trim()) ?? 0;
    if (p <= 0) { setState(() => _error = 'قيمة القرض مطلوبة'); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'principal': _principalC.text.trim(),
        'annual_rate_pct': _rateC.text.trim().isEmpty ? '0' : _rateC.text.trim(),
        'years': int.tryParse(_yearsC.text.trim()) ?? 5,
        'periods_per_year': _periodsPerYear,
        'method': _method,
      };
      final r = await ApiService.amortizationCompute(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل الحساب');
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
      appBar: ApexAppBar(title: 'جدول أقساط القرض'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _form(),
          const SizedBox(height: 16),
          _results(),
        ]),
      ),
    );
  }

  Widget _form() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(flex: 2, child: _field(_principalC, 'قيمة القرض *', Icons.attach_money)),
        const SizedBox(width: 10),
        Expanded(child: _field(_rateC, 'الفائدة السنوية %', Icons.percent)),
        const SizedBox(width: 10),
        Expanded(child: _field(_yearsC, 'سنوات', Icons.timelapse, isInt: true)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _method,
          decoration: _inpDec('طريقة السداد', Icons.schedule),
          dropdownColor: AC.navy2,
          style: TextStyle(color: AC.tp, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'fixed_payment',
              child: Text('قسط ثابت (متناقص الفائدة)')),
            DropdownMenuItem(value: 'constant_principal',
              child: Text('أصل ثابت (متناقص القسط)')),
          ],
          onChanged: (v) { if (v != null) setState(() => _method = v); },
        )),
        const SizedBox(width: 10),
        Expanded(child: DropdownButtonFormField<int>(
          value: _periodsPerYear,
          decoration: _inpDec('تكرار الدفع', Icons.repeat),
          dropdownColor: AC.navy2,
          style: TextStyle(color: AC.tp, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 12, child: Text('شهري')),
            DropdownMenuItem(value: 4, child: Text('ربع سنوي')),
            DropdownMenuItem(value: 2, child: Text('نصف سنوي')),
            DropdownMenuItem(value: 1, child: Text('سنوي')),
          ],
          onChanged: (v) { if (v != null) setState(() => _periodsPerYear = v); },
        )),
      ]),
      const SizedBox(height: 12),
      if (_error != null) Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AC.err.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(Icons.error_outline, color: AC.err, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12))),
          ]),
        ),
      ),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.schedule),
        label: const Text('احسب الجدول', style: TextStyle(fontSize: 15)),
      )),
    ]),
  );

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
          Icon(Icons.schedule, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('أدخل بيانات القرض واضغط "احسب"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final schedule = (d['schedule'] ?? []) as List;
    final pmt = d['fixed_payment']?.toString() ?? '0';
    final totalPayments = d['total_payments']?.toString() ?? '0';
    final totalInterest = d['total_interest']?.toString() ?? '0';
    final principal = d['principal']?.toString() ?? '0';
    final periodic = d['periodic_rate_pct']?.toString() ?? '0';
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _summaryCard(pmt, totalPayments, totalInterest, principal, periodic, d['method']),
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
      _scheduleTable(schedule),
    ]);
  }

  Widget _summaryCard(String pmt, String total, String interest, String principal,
                       String periodic, dynamic method) {
    final isFixed = method == 'fixed_payment';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.trending_up, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text(isFixed ? 'قسط ثابت شهري' : 'جدول سداد بأصل ثابت',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AC.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$periodic%/فترة',
              style: TextStyle(color: AC.info, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        Divider(color: AC.gold.withValues(alpha: 0.3), height: 18),
        if (isFixed) ...[
          _kv('القسط الثابت', '$pmt SAR', vc: AC.gold, bold: true),
          Divider(color: AC.bdr, height: 14),
        ],
        _kv('أصل القرض', '$principal SAR'),
        _kv('إجمالي الفائدة', '$interest SAR', vc: AC.warn),
        _kv('إجمالي المدفوعات', '$total SAR', vc: AC.tp, bold: true),
      ]),
    );
  }

  Widget _scheduleTable(List schedule) {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            SizedBox(width: 40, child: Text('#',
              style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800))),
            Expanded(child: Text('البداية',
              style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center)),
            Expanded(child: Text('القسط',
              style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center)),
            Expanded(child: Text('الفائدة',
              style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center)),
            Expanded(child: Text('الأصل',
              style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center)),
            Expanded(child: Text('الرصيد',
              style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w800),
              textAlign: TextAlign.end)),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: schedule.length,
            separatorBuilder: (_, __) => Divider(color: AC.bdr, height: 1),
            itemBuilder: (_, i) {
              final p = schedule[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  SizedBox(width: 40, child: Text('${p['period']}',
                    style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(child: Text('${p['opening_balance']}',
                    style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
                    textAlign: TextAlign.center)),
                  Expanded(child: Text('${p['payment']}',
                    style: TextStyle(color: AC.tp, fontSize: 10,
                      fontFamily: 'monospace', fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center)),
                  Expanded(child: Text('${p['interest']}',
                    style: TextStyle(color: AC.warn, fontSize: 10, fontFamily: 'monospace'),
                    textAlign: TextAlign.center)),
                  Expanded(child: Text('${p['principal']}',
                    style: TextStyle(color: AC.ok, fontSize: 10, fontFamily: 'monospace'),
                    textAlign: TextAlign.center)),
                  Expanded(child: Text('${p['closing_balance']}',
                    style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace'),
                    textAlign: TextAlign.end)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool isInt = false}) =>
    TextField(
      controller: c,
      keyboardType: isInt ? TextInputType.number
        : const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      decoration: _inpDec(label, icon),
    );

  InputDecoration _inpDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AC.goldText, size: 18),
    filled: true,
    fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts, fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AC.goldText)),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp,
        fontSize: bold ? 16 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
