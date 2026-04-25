/// APEX — Tax Calendar (Saudi-aware: VAT + Zakat + Corp Tax + ZATCA)
/// /compliance/tax-calendar — upcoming obligations with Hijri context
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/hijri_date.dart';
import '../../core/theme.dart';

class TaxCalendarScreen extends StatelessWidget {
  const TaxCalendarScreen({super.key});

  static List<_TaxObligation> _build() {
    final now = DateTime.now();
    return [
      _TaxObligation(
        title: 'إقرار VAT — أبريل 2026',
        type: 'VAT',
        dueDate: DateTime(now.year, now.month, 28),
        regulator: 'ZATCA',
        amount: '~ 1,725 ريال',
        action: 'قدّم الآن',
        actionRoute: '/compliance/vat-return',
      ),
      _TaxObligation(
        title: 'تجديد CSID — ZATCA',
        type: 'CSID',
        dueDate: now.add(const Duration(days: 25)),
        regulator: 'ZATCA',
        amount: 'مجاني',
        action: 'جدّد',
        actionRoute: '/compliance/zatca-csid',
      ),
      _TaxObligation(
        title: 'الزكاة السنوية',
        type: 'زكاة',
        dueDate: DateTime(now.year, 4, 30),
        regulator: 'ZATCA',
        amount: '2.5% من الوعاء',
        action: 'احسب',
        actionRoute: '/compliance/zakat',
      ),
      _TaxObligation(
        title: 'الإقرار الضريبي السنوي للشركات',
        type: 'ضريبة شركات',
        dueDate: DateTime(now.year, 4, 30),
        regulator: 'ZATCA',
        amount: '20% من صافي الدخل',
        action: 'قدّم',
        actionRoute: '/compliance/wht',
      ),
      _TaxObligation(
        title: 'WHT للموردين الأجانب',
        type: 'استقطاع',
        dueDate: DateTime(now.year, now.month, 10),
        regulator: 'ZATCA',
        amount: 'حسب العقود',
        action: 'احسب',
        actionRoute: '/compliance/wht',
      ),
      _TaxObligation(
        title: 'إيداع GOSI الشهري',
        type: 'GOSI',
        dueDate: DateTime(now.year, now.month, 15),
        regulator: 'GOSI',
        amount: '~ 22% من الرواتب',
        action: 'حضّر',
        actionRoute: '/compliance/payroll',
      ),
      _TaxObligation(
        title: 'تقرير Saudization (نطاقات)',
        type: 'سعودة',
        dueDate: DateTime(now.year, 4, 1),
        regulator: 'وزارة الموارد',
        amount: 'تقرير امتثال',
        action: 'راجع',
        actionRoute: '/compliance/payroll',
      ),
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Widget build(BuildContext context) {
    final items = _build();
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('التقويم الضريبي السعودي', style: TextStyle(color: AC.gold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final daysAway = item.dueDate.difference(now).inDays;
          final hijri = HijriDate.fromGregorian(item.dueDate);
          final color = daysAway < 0
              ? AC.err
              : daysAway <= 7
                  ? AC.err
                  : daysAway <= 30
                      ? AC.warn
                      : AC.ts;
          final urgency = daysAway < 0
              ? 'متأخر ${daysAway.abs()} أيام'
              : daysAway == 0
                  ? 'اليوم'
                  : 'بعد $daysAway يوماً';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AC.navy2,
              border: Border.all(color: color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.type,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(urgency,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text(item.title,
                    style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: AC.ts),
                  const SizedBox(width: 4),
                  Text(
                    '${item.dueDate.year}/${item.dueDate.month.toString().padLeft(2, '0')}/${item.dueDate.day.toString().padLeft(2, '0')} م · ${hijri.formatLong()}',
                    style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.attach_money, size: 12, color: AC.ts),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('${item.regulator} · ${item.amount}',
                        style: TextStyle(color: AC.ts, fontSize: 11)),
                  ),
                  ElevatedButton(
                    onPressed: () => context.go(item.actionRoute),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: color, foregroundColor: Colors.white),
                    child: Text(item.action),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _TaxObligation {
  final String title;
  final String type;
  final DateTime dueDate;
  final String regulator;
  final String amount;
  final String action;
  final String actionRoute;
  _TaxObligation({
    required this.title,
    required this.type,
    required this.dueDate,
    required this.regulator,
    required this.amount,
    required this.action,
    required this.actionRoute,
  });
}
