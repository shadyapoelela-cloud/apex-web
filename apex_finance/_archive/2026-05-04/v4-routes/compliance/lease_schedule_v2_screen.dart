/// APEX — Lease Schedule v2 (IFRS 16)
/// /compliance/lease-v2 — ROU asset + lease liability + amortization
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class LeaseScheduleV2Screen extends StatefulWidget {
  const LeaseScheduleV2Screen({super.key});
  @override
  State<LeaseScheduleV2Screen> createState() => _LeaseScheduleV2ScreenState();
}

class _LeaseScheduleV2ScreenState extends State<LeaseScheduleV2Screen> {
  // Demo lease data
  final double _monthlyPayment = 15000;
  final int _termMonths = 36;
  final double _discountRate = 0.05; // 5% annual
  final DateTime _start = DateTime(2025, 1, 1);

  // Computed
  double get _pv {
    final r = _discountRate / 12;
    return _monthlyPayment * (1 - math.pow(1 + r, -_termMonths).toDouble()) / r;
  }

  List<Map<String, dynamic>> get _schedule {
    final r = _discountRate / 12;
    var balance = _pv;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < _termMonths; i++) {
      final interest = balance * r;
      final principal = _monthlyPayment - interest;
      balance -= principal;
      final period = DateTime(_start.year, _start.month + i + 1, _start.day);
      result.add({
        'period': '${period.year}/${period.month.toString().padLeft(2, '0')}',
        'opening': balance + principal,
        'payment': _monthlyPayment,
        'interest': interest,
        'principal': principal,
        'closing': balance < 0 ? 0.0 : balance,
      });
    }
    return result;
  }

  double get _totalPayments => _monthlyPayment * _termMonths;
  double get _totalInterest => _totalPayments - _pv;
  double get _depreciationMonthly => _pv / _termMonths;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monthsElapsed = (today.year - _start.year) * 12 + today.month - _start.month;
    final accDep = (monthsElapsed * _depreciationMonthly).clamp(0, _pv);
    final nbv = _pv - accDep;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('IFRS 16 — جدول الإيجار', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(nbv.toDouble(), accDep.toDouble()),
          const SizedBox(height: 12),
          _journalEntryCard(),
          const SizedBox(height: 12),
          _scheduleCard(),
          const ApexOutputChips(items: [
            ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
            ApexChipLink('الأصول الثابتة', '/operations/fixed-assets-v2', Icons.business),
            ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard(double nbv, double accDep) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.20), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.apartment, color: AC.gold, size: 24),
            const SizedBox(width: 10),
            Text('عقد إيجار رئيسي',
                style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text('إيجار شهري ${_monthlyPayment.toStringAsFixed(0)} ريال × $_termMonths شهر · معدل الخصم ${(_discountRate * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: AC.tp, fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _miniMetric('ROU Asset (PV)', _pv, AC.gold)),
            Expanded(child: _miniMetric('NBV الحالي', nbv, AC.ok)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _miniMetric('إجمالي الدفعات', _totalPayments, AC.tp)),
            Expanded(child: _miniMetric('إجمالي الفوائد', _totalInterest, AC.warn)),
          ]),
        ]),
      );

  Widget _miniMetric(String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(v.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900)),
          Text('SAR', style: TextStyle(color: AC.ts, fontSize: 9)),
        ],
      );

  Widget _journalEntryCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('قيد الإثبات الافتتاحي (IFRS 16.22)',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _jeRow('Dr', 'حق استخدام أصل (ROU)', _pv, AC.ok),
          _jeRow('Cr', 'التزام إيجار', _pv, AC.warn),
          const SizedBox(height: 10),
          Text('قيد الإهلاك الشهري:',
              style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          _jeRow('Dr', 'مصروف إهلاك ROU', _depreciationMonthly, AC.ok),
          _jeRow('Cr', 'مجمّع إهلاك ROU', _depreciationMonthly, AC.warn),
        ]),
      );

  Widget _jeRow(String drCr, String label, double v, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 30,
              child: Text(drCr,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800))),
          Expanded(child: Text(label, style: TextStyle(color: AC.tp, fontSize: 12))),
          Text(v.toStringAsFixed(2),
              style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5)),
        ]),
      );

  Widget _scheduleCard() => Container(
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
              Expanded(flex: 2, child: Text('الفترة', style: _hdr())),
              Expanded(flex: 2, child: Text('افتتاحي', style: _hdr(), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('دفعة', style: _hdr(), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('فائدة', style: _hdr(), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('أصل', style: _hdr(), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('ختامي', style: _hdr(), textAlign: TextAlign.left)),
            ]),
          ),
          ..._schedule.take(12).map((row) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('${row['period']}',
                      style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11))),
                  Expanded(flex: 2, child: Text((row['opening'] as double).toStringAsFixed(0),
                      style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text((row['payment'] as double).toStringAsFixed(0),
                      style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text((row['interest'] as double).toStringAsFixed(0),
                      style: TextStyle(color: AC.warn, fontFamily: 'monospace', fontSize: 11),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text((row['principal'] as double).toStringAsFixed(0),
                      style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 11),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text((row['closing'] as double).toStringAsFixed(0),
                      style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.left)),
                ]),
              )),
          if (_schedule.length > 12)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text('...و ${_schedule.length - 12} شهر إضافي',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ),
            ),
        ]),
      );

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800);
}

