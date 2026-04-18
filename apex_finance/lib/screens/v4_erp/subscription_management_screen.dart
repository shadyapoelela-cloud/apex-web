/// APEX Wave 91 — Subscription Management (SaaS Billing).
/// Route: /app/marketplace/billing/subscriptions
///
/// Recurring revenue — MRR, ARR, churn, cohorts, plan management.
library;

import 'package:flutter/material.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});
  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _plans = const [
    _Plan('Starter', 299, 'monthly', 45, 'للمنشآت الصغيرة — 5 مستخدمين + وحدات أساسية', Colors.blue),
    _Plan('Professional', 899, 'monthly', 128, 'للمنشآت المتوسطة — 25 مستخدم + كل الوحدات', Color(0xFFD4AF37)),
    _Plan('Enterprise', 2499, 'monthly', 62, 'للشركات الكبرى — مستخدمين غير محدود + SLA', Colors.purple),
    _Plan('Industry Pack — مقاولات', 1499, 'monthly', 24, 'مخصص لقطاع المقاولات', Colors.orange),
    _Plan('Industry Pack — مطاعم', 799, 'monthly', 38, 'مخصص لقطاع المطاعم والأغذية', Colors.green),
  ];

  final _subscriptions = const [
    _Sub('SUB-2024-0042', 'أرامكو السعودية', 'Enterprise', 'active', '2024-03-15', '2027-03-14', 2499, 3, 90, 98),
    _Sub('SUB-2025-0158', 'شركة سابك', 'Enterprise', 'active', '2025-01-10', '2026-01-09', 2499, 12, 365, 95),
    _Sub('SUB-2024-0085', 'مصرف الراجحي', 'Professional', 'active', '2024-07-20', '2025-07-19', 899, 12, 300, 88),
    _Sub('SUB-2025-0245', 'مجموعة الحبتور', 'Professional', 'at-risk', '2025-04-01', '2026-04-01', 899, 12, 12, 42),
    _Sub('SUB-2025-0312', 'معهد الإدارة', 'Starter', 'active', '2025-09-15', '2026-09-14', 299, 12, 180, 75),
    _Sub('SUB-2024-0128', 'شركة النسما', 'Industry Pack — مقاولات', 'active', '2024-11-01', '2025-11-01', 1499, 12, 195, 82),
    _Sub('SUB-2025-0058', 'طلبات', 'Industry Pack — مطاعم', 'active', '2025-02-20', '2026-02-19', 799, 12, 300, 91),
    _Sub('SUB-2024-0192', 'شركة الاتحاد للطيران', 'Enterprise', 'paused', '2024-05-10', '2025-05-10', 2499, 12, 0, 0),
    _Sub('SUB-2025-0301', 'شركة ABC', 'Starter', 'cancelled', '2025-08-01', '2025-11-01', 299, 3, 0, 0),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  double get _mrr {
    return _subscriptions.where((s) => s.status == 'active').fold(0.0, (sum, s) => sum + s.monthlyPrice);
  }

  double get _arr => _mrr * 12;

  @override
  Widget build(BuildContext context) {
    final active = _subscriptions.where((s) => s.status == 'active').length;
    final atRisk = _subscriptions.where((s) => s.status == 'at-risk').length;

    return Column(
      children: [
        _buildHero(),
        _buildKpiRow(active, atRisk),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.list, size: 16), text: 'الاشتراكات'),
            Tab(icon: Icon(Icons.tag, size: 16), text: 'الباقات'),
            Tab(icon: Icon(Icons.analytics, size: 16), text: 'تحليلات MRR'),
            Tab(icon: Icon(Icons.group_work, size: 16), text: 'Cohorts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildSubsTab(),
              _buildPlansTab(),
              _buildAnalyticsTab(),
              _buildCohortsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.subscriptions, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة الاشتراكات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Subscription Billing · MRR · ARR · Churn · Cohort Analysis',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(int active, int atRisk) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('الإيرادات الشهرية (MRR)', '${_fmtM(_mrr)} ر.س', '+18% MoM', const Color(0xFFD4AF37), Icons.calendar_month),
          _kpi('الإيرادات السنوية (ARR)', '${_fmtM(_arr)} ر.س', '+24% YoY', Colors.green, Icons.trending_up),
          _kpi('اشتراكات نشطة', '$active', '+3 هذا الشهر', Colors.blue, Icons.people),
          _kpi('Net Retention', '112%', 'نمو من الحاليين', Colors.teal, Icons.repeat),
          _kpi('Churn Rate', '2.8%', '< 3% المستهدف', Colors.orange, Icons.trending_down),
          _kpi('في خطر', '$atRisk', 'يحتاج متابعة', Colors.red, Icons.warning),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, String note, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                  Text(note, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _subscriptions.length,
      itemBuilder: (ctx, i) {
        final s = _subscriptions[i];
        final statusColor = _statusColor(s.status);
        final plan = _plans.firstWhere((p) => p.name == s.plan, orElse: () => _plans.first);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withOpacity(0.3), width: s.status == 'at-risk' ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(width: 6, height: 60, color: plan.color),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.id, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black54)),
                    Text(s.customer, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: plan.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(s.plan,
                              style: TextStyle(fontSize: 10, color: plan.color, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                          child: Text(_statusLabel(s.status),
                              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('السعر الشهري', style: TextStyle(fontSize: 10, color: Colors.black54)),
                    Text(_fmt(s.monthlyPrice.toDouble()),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                    const Text('ر.س/شهر', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بداية: ${s.startDate}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                    Text('تجديد: ${s.renewalDate}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                  ],
                ),
              ),
              if (s.status == 'active' || s.status == 'at-risk')
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_heart, size: 13),
                        const SizedBox(width: 4),
                        Text('Health: ${s.health}%',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: s.health >= 70 ? Colors.green : s.health >= 40 ? Colors.orange : Colors.red)),
                      ],
                    ),
                    Text('${s.daysActive} يوم نشط', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
                  child: Text(s.status == 'cancelled' ? 'ملغى' : 'متوقف',
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlansTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 1.3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final p in _plans) _planCard(p),
          ],
        ),
      ],
    );
  }

  Widget _planCard(_Plan p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.color, p.color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(p.description, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(p.price.toDouble()),
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const Padding(
                padding: EdgeInsets.only(bottom: 3, right: 3),
                child: Text('ر.س/شهر', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text('${p.subscribers} مشترك',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_fmtM(p.price * p.subscribers.toDouble())} ر.س/شهر',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final months = const [
      _MonthData('أكتوبر 2025', 98000, 132),
      _MonthData('نوفمبر 2025', 108500, 142),
      _MonthData('ديسمبر 2025', 124000, 156),
      _MonthData('يناير 2026', 142000, 171),
      _MonthData('فبراير 2026', 158500, 185),
      _MonthData('مارس 2026', 175000, 198),
      _MonthData('أبريل 2026', 194500, 212),
    ];
    final maxMrr = months.fold(0.0, (m, d) => d.mrr > m ? d.mrr.toDouble() : m);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نمو الإيرادات الشهرية MRR (آخر 7 أشهر)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final m in months)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(_fmtM(m.mrr.toDouble()),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37))),
                              const SizedBox(height: 2),
                              Container(
                                height: (m.mrr / maxMrr) * 140,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFFD4AF37), Color(0xFFE6C200)],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(m.month.split(' ')[0],
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                              Text('${m.subs}',
                                  style: const TextStyle(fontSize: 9, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildMovements()),
            const SizedBox(width: 12),
            Expanded(child: _buildTopCustomers()),
          ],
        ),
      ],
    );
  }

  Widget _buildMovements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('حركة MRR — أبريل 2026', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _mrrMove('MRR بداية الشهر', 175000, Colors.grey, Icons.timeline),
          _mrrMove('+ New MRR (اشتراكات جديدة)', 18500, Colors.green, Icons.add_circle),
          _mrrMove('+ Expansion MRR (ترقيات)', 7800, Colors.blue, Icons.trending_up),
          _mrrMove('- Contraction MRR (تخفيضات)', -2100, Colors.orange, Icons.trending_down),
          _mrrMove('- Churned MRR (إلغاءات)', -4700, Colors.red, Icons.remove_circle),
          const Divider(),
          _mrrMove('MRR نهاية الشهر', 194500, const Color(0xFFD4AF37), Icons.star, bold: true),
        ],
      ),
    );
  }

  Widget _mrrMove(String label, int amount, Color color, IconData icon, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          ),
          Text(
            amount >= 0 ? '+${_fmt(amount.toDouble())}' : _fmt(amount.toDouble()),
            style: TextStyle(
                fontSize: bold ? 15 : 12,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomers() {
    final top = _subscriptions.where((s) => s.status == 'active').toList()
      ..sort((a, b) => b.monthlyPrice.compareTo(a.monthlyPrice));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أعلى 5 عملاء — MRR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          for (var i = 0; i < top.take(5).length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: i == 0
                        ? const Color(0xFFFFD700)
                        : i == 1
                            ? Colors.grey.shade400
                            : Colors.orange.shade300,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(top[i].customer, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Text('${_fmt(top[i].monthlyPrice.toDouble())} ر.س',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCohortsTab() {
    final cohorts = const [
      _Cohort('Q1 2024', 24, [100, 96, 92, 88, 85, 83, 80]),
      _Cohort('Q2 2024', 32, [100, 94, 90, 87, 85, 82, 80]),
      _Cohort('Q3 2024', 28, [100, 97, 93, 90, 88, 86, 0]),
      _Cohort('Q4 2024', 36, [100, 98, 95, 92, 90, 0, 0]),
      _Cohort('Q1 2025', 42, [100, 96, 93, 91, 0, 0, 0]),
      _Cohort('Q2 2025', 38, [100, 97, 94, 0, 0, 0, 0]),
      _Cohort('Q3 2025', 45, [100, 98, 0, 0, 0, 0, 0]),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cohort Analysis يقيس نسبة بقاء العملاء بمرور الوقت من تاريخ اشتراكهم. الأرقام % احتفاظ.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Retention Cohort Table', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    const SizedBox(width: 100, child: Text('Cohort', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 60, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Text('M${i == 0 ? '0' : i * 3}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
              for (final c in cohorts) _cohortRow(c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cohortRow(_Cohort c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5)))),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(c.period, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          SizedBox(width: 60, child: Text('${c.size}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          for (final v in c.retention)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: v == 0
                      ? Colors.transparent
                      : Color.lerp(Colors.red.shade100, Colors.green.shade300, v / 100),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  v == 0 ? '—' : '$v%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: v == 0 ? Colors.black38 : (v >= 85 ? Colors.green.shade800 : v >= 70 ? Colors.black87 : Colors.red.shade800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return Colors.green;
      case 'at-risk':
        return Colors.red;
      case 'paused':
        return Colors.amber;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'نشط';
      case 'at-risk':
        return 'في خطر';
      case 'paused':
        return 'متوقف';
      case 'cancelled':
        return 'ملغى';
      default:
        return s;
    }
  }

  String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    final formatted = s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return v < 0 ? '-$formatted' : formatted;
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Plan {
  final String name;
  final int price;
  final String cadence;
  final int subscribers;
  final String description;
  final Color color;
  const _Plan(this.name, this.price, this.cadence, this.subscribers, this.description, this.color);
}

class _Sub {
  final String id;
  final String customer;
  final String plan;
  final String status;
  final String startDate;
  final String renewalDate;
  final int monthlyPrice;
  final int months;
  final int daysActive;
  final int health;
  const _Sub(this.id, this.customer, this.plan, this.status, this.startDate, this.renewalDate, this.monthlyPrice, this.months, this.daysActive, this.health);
}

class _MonthData {
  final String month;
  final int mrr;
  final int subs;
  const _MonthData(this.month, this.mrr, this.subs);
}

class _Cohort {
  final String period;
  final int size;
  final List<int> retention;
  const _Cohort(this.period, this.size, this.retention);
}
