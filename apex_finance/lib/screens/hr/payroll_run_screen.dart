/// APEX — Payroll Run (HR + Accounting unified — Saudi-aware)
/// /hr/payroll-run — process monthly payroll with GOSI + Saudization
library;

import 'package:flutter/material.dart';

import '../../core/apex_dual_date_picker.dart';
import '../../core/theme.dart';

class PayrollRunScreen extends StatefulWidget {
  const PayrollRunScreen({super.key});
  @override
  State<PayrollRunScreen> createState() => _PayrollRunScreenState();
}

class _PayrollRunScreenState extends State<PayrollRunScreen> {
  DateTime _payDate = DateTime.now();
  bool _processing = false;
  Map<String, dynamic>? _result;

  // Demo employees — to be replaced with API fetch
  final List<Map<String, dynamic>> _employees = [
    {'name': 'أحمد العتيبي', 'is_saudi': true, 'gross': 12000.0, 'deductions': 0.0},
    {'name': 'سارة المطيري', 'is_saudi': true, 'gross': 9500.0, 'deductions': 200.0},
    {'name': 'Rajesh Kumar', 'is_saudi': false, 'gross': 6500.0, 'deductions': 0.0},
    {'name': 'Maria Santos', 'is_saudi': false, 'gross': 5500.0, 'deductions': 0.0},
    {'name': 'محمد القحطاني', 'is_saudi': true, 'gross': 15000.0, 'deductions': 500.0},
  ];

  double get _totalGross => _employees.fold<double>(0, (a, e) => a + (e['gross'] as double));
  double get _totalDeductions => _employees.fold<double>(0, (a, e) => a + (e['deductions'] as double));
  double get _gosiSaudi => _employees
      .where((e) => e['is_saudi'] == true)
      .fold<double>(0, (a, e) => a + (e['gross'] as double) * 0.22);
  double get _gosiExpat => _employees
      .where((e) => e['is_saudi'] == false)
      .fold<double>(0, (a, e) => a + (e['gross'] as double) * 0.02);
  double get _totalGosi => _gosiSaudi + _gosiExpat;
  double get _net => _totalGross - _totalDeductions;
  double get _saudizationPct =>
      _employees.isEmpty
          ? 0
          : _employees.where((e) => e['is_saudi'] == true).length / _employees.length * 100;

  Future<void> _runPayroll() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _processing = false;
      _result = {
        'je_number': 'PAY-${_payDate.year}-${_payDate.month.toString().padLeft(2, '0')}',
        'employees': _employees.length,
        'gross': _totalGross,
        'gosi': _totalGosi,
        'net': _net,
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      content: Text('تم تشغيل الرواتب — JE ${_result!['je_number']}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('تشغيل الرواتب', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_result != null) _resultCard(),
          _periodCard(),
          const SizedBox(height: 12),
          _summaryCard(),
          const SizedBox(height: 12),
          _employeesCard(),
          const SizedBox(height: 12),
          _gosiBreakdown(),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _runPayroll,
              icon: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments),
              label: Text(_processing ? 'جارٍ الترحيل…' : 'شغّل الرواتب وأنشئ JE'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _resultCard() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.ok.withValues(alpha: 0.10),
          border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.celebration, color: AC.ok),
            const SizedBox(width: 8),
            Text('تم تشغيل الرواتب',
                style: TextStyle(color: AC.ok, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text('JE: ${_result!['je_number']} · ${_result!['employees']} موظف',
              style: TextStyle(color: AC.tp, fontSize: 12)),
        ]),
      );

  Widget _periodCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('فترة الدفع',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ApexDualDatePicker(
            label: 'تاريخ الدفع',
            value: _payDate,
            onChanged: (d) => setState(() => _payDate = d),
          ),
        ]),
      );

  Widget _summaryCard() => Row(children: [
        Expanded(child: _miniCard('الإجمالي', _totalGross, AC.gold)),
        const SizedBox(width: 8),
        Expanded(child: _miniCard('GOSI', _totalGosi, AC.warn)),
        const SizedBox(width: 8),
        Expanded(child: _miniCard('الصافي', _net, AC.ok)),
      ]);

  Widget _miniCard(String label, double v, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(v.toStringAsFixed(0),
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900)),
          ),
          Text('SAR', style: TextStyle(color: AC.ts, fontSize: 9.5)),
        ]),
      );

  Widget _employeesCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.people, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('الموظفون (${_employees.length})',
                    style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('سعودة ${_saudizationPct.toStringAsFixed(0)}%',
                    style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          ..._employees.map((e) {
            final saudi = e['is_saudi'] == true;
            final gross = e['gross'] as double;
            final ded = e['deductions'] as double;
            final net = gross - ded;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                Icon(saudi ? Icons.flag : Icons.public,
                    color: saudi ? AC.gold : AC.ts, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${e['name']}',
                      style: TextStyle(color: AC.tp, fontSize: 12.5)),
                ),
                Text('${gross.toStringAsFixed(0)}',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11)),
                const SizedBox(width: 8),
                Text('-${ded.toStringAsFixed(0)}',
                    style: TextStyle(color: AC.warn, fontFamily: 'monospace', fontSize: 11)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(net.toStringAsFixed(0),
                      style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12),
                      textAlign: TextAlign.left),
                ),
              ]),
            );
          }),
        ]),
      );

  Widget _gosiBreakdown() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.warn.withValues(alpha: 0.06),
          border: Border.all(color: AC.warn.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.shield_outlined, color: AC.warn),
            const SizedBox(width: 8),
            Text('GOSI Breakdown',
                style: TextStyle(color: AC.warn, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          _gosiRow('سعودي (22%)', _gosiSaudi, AC.gold),
          _gosiRow('مقيم (2%)', _gosiExpat, AC.ts),
          const Divider(),
          _gosiRow('الإجمالي', _totalGosi, AC.warn, bold: true),
        ]),
      );

  Widget _gosiRow(String label, double amount, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
          Text('${amount.toStringAsFixed(2)} SAR',
              style: TextStyle(
                  color: color,
                  fontSize: bold ? 14 : 12,
                  fontFamily: 'monospace',
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
        ]),
      );
}
