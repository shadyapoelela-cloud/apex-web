import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 117 — Recurring Subscription Billing (Stripe-like)
class SubscriptionBillingScreen extends StatefulWidget {
  const SubscriptionBillingScreen({super.key});
  @override
  State<SubscriptionBillingScreen> createState() => _SubscriptionBillingScreenState();
}

class _SubscriptionBillingScreenState extends State<SubscriptionBillingScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'الاشتراكات'), Tab(text: 'الخطط'), Tab(text: 'دفعات فاشلة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_subsTab(), _plansTab(), _dunningTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.autorenew, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('فوترة الاشتراكات المتكررة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('MRR، ARR، Churn، Dunning — Stripe-class billing', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final mrr = _subs.where((s)=>s.status.contains('نشط')).fold<double>(0, (s, sub) => s + sub.monthlyAmount);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('MRR', '${(mrr/1000).toStringAsFixed(0)}K', Icons.calendar_month, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('ARR', '${(mrr*12/1000000).toStringAsFixed(1)}M', Icons.trending_up, core_theme.AC.gold)),
      Expanded(child: _kpi('اشتراكات', '${_subs.length}', Icons.people, const Color(0xFF4A148C))),
      Expanded(child: _kpi('Churn', '2.8%', Icons.trending_down, const Color(0xFFC62828))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _subsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _subs.length, itemBuilder: (_, i) {
    final s = _subs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(s.status).withValues(alpha: 0.15), child: Icon(Icons.autorenew, color: _statusColor(s.status))),
      title: Text(s.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s.plan} • منذ ${s.startedDate}', style: const TextStyle(fontSize: 11)),
        Text('تجديد: ${s.nextBilling}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${s.monthlyAmount.toStringAsFixed(0)} ر.س/شهر', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 11)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _statusColor(s.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(s.status, style: TextStyle(color: _statusColor(s.status), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _plansTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _plans.length, itemBuilder: (_, i) {
    final p = _plans[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _planColor(p.tier).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(_planIcon(p.tier), color: _planColor(p.tier))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${p.subscribers} مشترك', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${p.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _planColor(p.tier))),
            Text('ر.س/${p.cycle}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ]),
        ]),
        const SizedBox(height: 10),
        ...p.features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
        ]))),
      ]),
    ));
  });

  Widget _dunningTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _failed.length, itemBuilder: (_, i) {
    final f = _failed[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFC62828).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.credit_card_off, color: Color(0xFFC62828))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('السبب: ${f.reason}', style: const TextStyle(fontSize: 11)),
          Text('محاولة ${f.attempts}/4 • ${f.lastAttempt}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${f.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
          Text(f.nextRetry, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ]),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('💎 MRR', '428K ر.س شهرياً — نمو 12% MoM', const Color(0xFF2E7D32)),
    _insight('📈 ARR', '5.14M ر.س سنوياً متوقع', core_theme.AC.gold),
    _insight('📉 Churn Rate', '2.8% شهرياً — أقل من معدل SaaS (5%)', const Color(0xFF1A237E)),
    _insight('🎯 LTV', 'متوسط 42,000 ر.س لكل عميل', const Color(0xFF4A148C)),
    _insight('💳 Dunning Success', '76% استرداد دفعات فاشلة', const Color(0xFF2E7D32)),
    _insight('⬆️ Upgrade Rate', '18% من Starter → Pro', const Color(0xFFE65100)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('ملغى')) return const Color(0xFFC62828);
    if (s.contains('معلق')) return const Color(0xFFE65100);
    if (s.contains('تجربة')) return core_theme.AC.gold;
    return core_theme.AC.ts;
  }

  Color _planColor(String t) {
    if (t.contains('Enterprise')) return const Color(0xFF4A148C);
    if (t.contains('Pro')) return core_theme.AC.gold;
    if (t.contains('Starter')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  IconData _planIcon(String t) {
    if (t.contains('Enterprise')) return Icons.diamond;
    if (t.contains('Pro')) return Icons.star;
    if (t.contains('Starter')) return Icons.rocket_launch;
    return Icons.grade;
  }

  static const List<_Sub> _subs = [
    _Sub('شركة الأفق التقني', 'Enterprise', '2023-05-12', '2026-05-12', 12_000, 'نشط'),
    _Sub('مؤسسة الابتكار', 'Pro', '2024-08-20', '2026-05-20', 4_500, 'نشط'),
    _Sub('متجر السلام', 'Starter', '2025-01-15', '2026-05-15', 890, 'نشط'),
    _Sub('شركة الحلول الذكية', 'Pro', '2024-03-08', '2026-05-08', 4_500, 'نشط'),
    _Sub('مؤسسة الخبرة', 'Enterprise', '2022-11-22', '2026-05-22', 18_000, 'نشط'),
    _Sub('أستوديو الإبداع', 'Starter', '2026-03-01', '2026-06-01', 890, 'تجربة مجانية'),
    _Sub('شركة القمة', 'Pro', '2025-06-12', '2026-05-12', 4_500, 'معلق'),
    _Sub('مؤسسة المستقبل', 'Enterprise', '2023-01-05', '2026-05-01', 12_000, 'ملغى'),
  ];

  static const List<_Plan> _plans = [
    _Plan('Starter', 'Starter', 890, 'شهر', 485, [
      'حتى 3 مستخدمين', 'وحدة المالية الأساسية', 'دعم عبر البريد', 'تحديثات مجانية',
    ]),
    _Plan('Professional', 'Pro', 4_500, 'شهر', 182, [
      'حتى 25 مستخدم', 'جميع وحدات ERP', 'دعم أولوية 24/7', 'تخصيص التقارير', 'API access',
    ]),
    _Plan('Enterprise', 'Enterprise', 12_000, 'شهر', 48, [
      'مستخدمون غير محدودين', 'جميع الوحدات + AI', 'مدير حساب مخصص', 'تدريب مجاني', 'SLA 99.9%', 'On-premise option',
    ]),
  ];

  static const List<_Failed> _failed = [
    _Failed('شركة القمة', 4_500, 'بطاقة منتهية الصلاحية', 2, '2026-04-17 09:30', '2026-04-20'),
    _Failed('مطعم الطيبات', 890, 'رصيد غير كافٍ', 3, '2026-04-16 14:15', '2026-04-19'),
    _Failed('استوديو الفن', 4_500, 'رفض البنك', 1, '2026-04-18 08:45', '2026-04-21'),
  ];
}

class _Sub { final String customer, plan, startedDate, nextBilling; final double monthlyAmount; final String status;
  const _Sub(this.customer, this.plan, this.startedDate, this.nextBilling, this.monthlyAmount, this.status); }
class _Plan { final String name, tier; final double price; final String cycle; final int subscribers; final List<String> features;
  const _Plan(this.name, this.tier, this.price, this.cycle, this.subscribers, this.features); }
class _Failed { final String customer; final double amount; final String reason; final int attempts; final String lastAttempt, nextRetry;
  const _Failed(this.customer, this.amount, this.reason, this.attempts, this.lastAttempt, this.nextRetry); }
