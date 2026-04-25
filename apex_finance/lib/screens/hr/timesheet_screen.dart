/// APEX — Timesheet (employee hours tracking)
/// /hr/timesheet — daily/weekly hour entry + approval
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});
  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  final List<String> _days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

  // Demo: per-day hours per project
  final Map<String, List<double>> _entries = {
    'مشروع الرياض': [8, 7, 8, 8, 8, 0, 0],
    'مشروع ERP داخلي': [0, 1, 0, 0, 0, 0, 0],
    'تدريب داخلي': [0, 0, 0, 0, 0, 0, 0],
  };

  double _projectTotal(String project) =>
      _entries[project]!.fold<double>(0, (a, h) => a + h);
  double _dayTotal(int day) =>
      _entries.values.fold<double>(0, (a, hrs) => a + hrs[day]);
  double get _weekTotal =>
      _entries.values.fold<double>(0, (a, hrs) => a + hrs.fold<double>(0, (b, h) => b + h));

  static const _expectedWeek = 40.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('سجل ساعات العمل', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _timesheetCard(),
          const SizedBox(height: 12),
          _summaryCard(),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AC.gold,
        foregroundColor: AC.navy,
        icon: const Icon(Icons.add),
        label: const Text('مشروع جديد'),
      ),
    );
  }

  Widget _heroCard() {
    final pct = _weekTotal / _expectedWeek;
    final color = pct >= 1 ? AC.ok : pct >= 0.9 ? AC.gold : AC.warn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('هذا الأسبوع',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${_weekTotal.toStringAsFixed(1)}',
              style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
          Text(' / 40 ساعة',
              style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: AC.navy3,
            color: color,
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  Widget _timesheetCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Text('المشروع', style: _hdr())),
              for (final d in _days)
                Expanded(child: Text(d, style: _hdr(), textAlign: TextAlign.center)),
              SizedBox(width: 50, child: Text('إجمالي', style: _hdr(), textAlign: TextAlign.left)),
            ]),
          ),
          ..._entries.entries.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Text(e.key, style: TextStyle(color: AC.tp, fontSize: 11.5)),
                  ),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Text(e.value[i] == 0 ? '—' : e.value[i].toStringAsFixed(0),
                          style: TextStyle(
                              color: e.value[i] == 0 ? AC.ts : AC.tp,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                          textAlign: TextAlign.center),
                    ),
                  SizedBox(
                    width: 50,
                    child: Text(_projectTotal(e.key).toStringAsFixed(0),
                        style: TextStyle(
                            color: AC.gold,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800),
                        textAlign: TextAlign.left),
                  ),
                ]),
              )),
          // Totals row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(color: AC.navy3),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Text('الإجمالي اليومي',
                    style: TextStyle(color: AC.gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(_dayTotal(i).toStringAsFixed(0),
                      style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center),
                ),
              SizedBox(
                width: 50,
                child: Text(_weekTotal.toStringAsFixed(0),
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.left),
              ),
            ]),
          ),
        ]),
      );

  Widget _summaryCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.06),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.send, color: AC.gold),
            const SizedBox(width: 8),
            Text('قدّم الكشف للاعتماد',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AC.ok,
                  content: const Text('تم تقديم الكشف للمدير المباشر'),
                ),
              );
            },
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('قدّم الأسبوع'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
        ]),
      );

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 10.5, fontWeight: FontWeight.w800);
}
