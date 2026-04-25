/// APEX — Bank Feed Setup (Lean / Tarabut integration UX)
/// /settings/bank-feeds — Saudi banks one-click connect
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class BankFeedSetupScreen extends StatefulWidget {
  const BankFeedSetupScreen({super.key});
  @override
  State<BankFeedSetupScreen> createState() => _BankFeedSetupScreenState();
}

class _BankFeedSetupScreenState extends State<BankFeedSetupScreen> {
  // Saudi banks list
  final List<Map<String, dynamic>> _banks = [
    {'code': 'snb', 'name': 'البنك الأهلي السعودي', 'logo': '🏦', 'connected': true, 'last_sync': 'منذ 2 ساعة'},
    {'code': 'rajhi', 'name': 'مصرف الراجحي', 'logo': '🏦', 'connected': true, 'last_sync': 'منذ 5 ساعات'},
    {'code': 'sab', 'name': 'البنك السعودي البريطاني (SAB)', 'logo': '🏦', 'connected': false},
    {'code': 'riyad', 'name': 'بنك الرياض', 'logo': '🏦', 'connected': false},
    {'code': 'anb', 'name': 'البنك العربي الوطني', 'logo': '🏦', 'connected': false},
    {'code': 'bsf', 'name': 'البنك السعودي الفرنسي', 'logo': '🏦', 'connected': false},
    {'code': 'albilad', 'name': 'بنك البلاد', 'logo': '🏦', 'connected': false},
    {'code': 'aljazira', 'name': 'بنك الجزيرة', 'logo': '🏦', 'connected': false},
    {'code': 'inma', 'name': 'مصرف الإنماء', 'logo': '🏦', 'connected': false},
    {'code': 'sib', 'name': 'البنك السعودي للاستثمار', 'logo': '🏦', 'connected': false},
    {'code': 'gulf', 'name': 'بنك الخليج الدولي', 'logo': '🏦', 'connected': false},
  ];

  int get _connectedCount => _banks.where((b) => b['connected'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('ربط البنوك (SAMA Open Banking)',
            style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _providersCard(),
          const SizedBox(height: 12),
          _banksCard(),
        ]),
      ),
    );
  }

  Widget _heroCard() => Container(
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
            Icon(Icons.account_balance, color: AC.gold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text('ربط حساباتك البنكية',
                  style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AC.ok.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('متصل: $_connectedCount من 11',
                  style: TextStyle(color: AC.ok, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'استورد المعاملات البنكية تلقائياً عبر SAMA Open Banking. تعمل كل 6 ساعات وتطابق المعاملات بـ AI تلقائياً (دقة >95%).',
            style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6),
          ),
        ]),
      );

  Widget _providersCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مزوّد الخدمة',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _providerOption('Lean', 'مرخّص SAMA', true)),
            const SizedBox(width: 8),
            Expanded(child: _providerOption('Tarabut', 'مرخّص SAMA', false)),
            const SizedBox(width: 8),
            Expanded(child: _providerOption('Salt Edge', 'دولي', false)),
          ]),
        ]),
      );

  Widget _providerOption(String name, String tag, bool selected) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.15) : AC.navy3,
          border: Border.all(
              color: selected ? AC.gold : AC.bdr,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(name,
              style: TextStyle(
                  color: selected ? AC.gold : AC.tp,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AC.ok.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tag,
                style: TextStyle(color: AC.ok, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _banksCard() => Container(
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
              Icon(Icons.business, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('البنوك السعودية (${_banks.length})',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
          ..._banks.map((b) {
            final connected = b['connected'] == true;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                Text('${b['logo']}', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b['name']}',
                        style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    if (connected)
                      Row(children: [
                        Icon(Icons.check_circle, color: AC.ok, size: 11),
                        const SizedBox(width: 4),
                        Text('متصل · آخر مزامنة ${b['last_sync']}',
                            style: TextStyle(color: AC.ok, fontSize: 10.5)),
                      ])
                    else
                      Text('غير متصل',
                          style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  ]),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => b['connected'] = !connected);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: connected ? AC.navy3 : AC.gold,
                      foregroundColor: connected ? AC.tp : AC.navy),
                  child: Text(connected ? 'إعدادات' : 'اربط'),
                ),
              ]),
            );
          }),
        ]),
      );
}
