/// APEX Wave 100 — Customer Loyalty & Rewards 🎉
/// Route: /app/erp/operations/loyalty
///
/// Points, tiers, redemption, cohort engagement.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class CustomerLoyaltyScreen extends StatefulWidget {
  const CustomerLoyaltyScreen({super.key});
  @override
  State<CustomerLoyaltyScreen> createState() => _CustomerLoyaltyScreenState();
}

class _CustomerLoyaltyScreenState extends State<CustomerLoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _tiers = [
    _Tier('البلاتيني', 'Platinum', 10_000_000, 82, 15, Color(0xFF455A64), '🏆'),
    _Tier('الذهبي', 'Gold', 3_000_000, 245, 10, core_theme.AC.gold, '🥇'),
    _Tier('الفضي', 'Silver', 500_000, 680, 6, Color(0xFF9E9E9E), '🥈'),
    _Tier('البرونزي', 'Bronze', 0, 1_850, 3, Color(0xFFCD7F32), '🥉'),
  ];

  final _topCustomers = [
    _LoyalCust('CUS-0089', 'سابك', 18_500_000, 285_000, 'Platinum', 145_000, Color(0xFF455A64)),
    _LoyalCust('CUS-0145', 'أرامكو السعودية', 24_500_000, 245_000, 'Platinum', 98_000, Color(0xFF455A64)),
    _LoyalCust('CUS-0213', 'شركة الاتصالات السعودية', 14_500_000, 185_000, 'Platinum', 62_000, Color(0xFF455A64)),
    _LoyalCust('CUS-0178', 'مجموعة بن لادن السعودية', 8_200_000, 125_000, 'Gold', 48_000, core_theme.AC.gold),
    _LoyalCust('CUS-0298', 'دبي القابضة', 5_600_000, 98_000, 'Gold', 32_000, core_theme.AC.gold),
    _LoyalCust('CUS-0342', 'معهد الإدارة العامة', 1_800_000, 45_000, 'Gold', 12_000, core_theme.AC.gold),
    _LoyalCust('CUS-0412', 'مركز التدريب الوطني', 680_000, 22_000, 'Silver', 8_500, Color(0xFF9E9E9E)),
  ];

  final _rewards = [
    _Reward('خصم 5% على الفاتورة التالية', 'discount', 1_000, 842, true, core_theme.AC.ok),
    _Reward('ترقية خدمة مجانية لـ 3 أشهر', 'upgrade', 5_000, 128, true, core_theme.AC.info),
    _Reward('استشارة مجانية 4 ساعات', 'consultation', 2_500, 245, true, core_theme.AC.purple),
    _Reward('دعوة حدث VIP سنوي', 'event', 15_000, 45, true, core_theme.AC.gold),
    _Reward('اشتراك شهري مجاني', 'subscription', 3_000, 168, true, core_theme.AC.info),
    _Reward('كتيب أداء مخصّص', 'whitepaper', 500, 1_240, true, core_theme.AC.warn),
    _Reward('دعوة منتدى القمّة الخليجية', 'event', 25_000, 8, true, core_theme.AC.err),
    _Reward('Apple iPad Pro 2026', 'gift', 50_000, 2, false, core_theme.AC.purple),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events, size: 16), text: 'المستويات'),
            Tab(icon: Icon(Icons.stars, size: 16), text: 'العملاء الأعلى'),
            Tab(icon: Icon(Icons.card_giftcard, size: 16), text: 'كتالوج المكافآت'),
            Tab(icon: Icon(Icons.analytics, size: 16), text: 'التفاعل والتحليلات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildTiersTab(),
              _buildTopCustomersTab(),
              _buildRewardsTab(),
              _buildAnalyticsTab(),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [core_theme.AC.gold, Color(0xFFE6C200), Color(0xFFFFD700)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.loyalty, color: Colors.white, size: 40),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎉 برنامج الولاء — APEX Rewards',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                Text('4 مستويات · نقاط لكل 1 ر.س = نقطة · مكافآت حصرية · شراكات VIP',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text('WAVE 100', style: TextStyle(color: core_theme.AC.gold, fontSize: 16, fontWeight: FontWeight.w900)),
                Text('🎊 MILESTONE', style: TextStyle(color: core_theme.AC.ts, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final totalMembers = _tiers.fold(0, (s, t) => s + t.memberCount);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('إجمالي الأعضاء', '$totalMembers', core_theme.AC.info, Icons.people),
          _kpi('نقاط مصدرة YTD', '4.2M', core_theme.AC.gold, Icons.stars),
          _kpi('نقاط مستبدلة', '1.8M (43%)', core_theme.AC.purple, Icons.redeem),
          _kpi('معدل التفاعل', '68%', core_theme.AC.ok, Icons.trending_up),
          _kpi('Net Retention', '+24%', core_theme.AC.info, Icons.repeat),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiersTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final t in _tiers) _tierCard(t),
      ],
    );
  }

  Widget _tierCard(_Tier t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.color, t.color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(t.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text(t.nameEn, style: TextStyle(color: core_theme.AC.ts, fontSize: 14)),
                const SizedBox(height: 8),
                Text('الحد الأدنى: ${_fmtM(t.minSpend.toDouble())} ر.س/سنة',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          Column(
            children: [
              Text('${t.memberCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              Text('عضو', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('${t.pointsMultiplier}%',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900)),
                Text('نقاط إضافية', style: TextStyle(color: core_theme.AC.ts, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _topCustomers.length,
      itemBuilder: (ctx, i) {
        final c = _topCustomers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.tierColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: i < 3 ? const Color(0xFFFFD700) : core_theme.AC.bdr,
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: i < 3 ? Colors.white : core_theme.AC.tp, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(c.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي الإنفاق', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    Text(_fmtM(c.totalSpend),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.gold, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('النقاط', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    Text(_fmt(c.totalPoints.toDouble()),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.info, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('متاح', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    Text(_fmt(c.availablePoints.toDouble()),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: core_theme.AC.ok, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: c.tierColor, borderRadius: BorderRadius.circular(6)),
                child: Text(c.tier,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final r in _rewards) _rewardCard(r),
          ],
        ),
      ],
    );
  }

  Widget _rewardCard(_Reward r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: r.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(_catIcon(r.category), color: r.color, size: 20),
              ),
              const Spacer(),
              if (!r.available)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: core_theme.AC.err.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                  child: Text('نفد', style: TextStyle(color: core_theme.AC.err, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.stars, color: core_theme.AC.gold, size: 16),
              const SizedBox(width: 4),
              Text('${_fmt(r.pointsCost.toDouble())} نقطة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('استُبدل ${r.redeemed}× هذا الربع',
                    style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ),
              if (r.available)
                Icon(Icons.arrow_forward, size: 14, color: core_theme.AC.info),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final months = const [
      _MonthStat('أكتوبر', 384, 162, 42),
      _MonthStat('نوفمبر', 425, 178, 42),
      _MonthStat('ديسمبر', 488, 215, 44),
      _MonthStat('يناير', 512, 235, 46),
      _MonthStat('فبراير', 548, 258, 47),
      _MonthStat('مارس', 612, 285, 47),
      _MonthStat('أبريل', 675, 312, 46),
    ];
    final maxPoints = months.fold(0.0, (m, s) => s.pointsEarned > m ? s.pointsEarned.toDouble() : m);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نمو النقاط المكتسبة vs المستبدلة (آخر 7 أشهر)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              Text('(بالآلاف)', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
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
                              Text('${m.redemptionRate}%',
                                  style: TextStyle(fontSize: 9, color: core_theme.AC.ts, fontWeight: FontWeight.w700)),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: (m.pointsEarned / maxPoints) * 140,
                                      decoration: BoxDecoration(
                                        color: core_theme.AC.gold,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                      child: Center(
                                        child: Text('${m.pointsEarned}',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Container(
                                      height: (m.pointsRedeemed / maxPoints) * 140,
                                      decoration: BoxDecoration(
                                        color: core_theme.AC.purple,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                      child: Center(
                                        child: Text('${m.pointsRedeemed}',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(m.month, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(core_theme.AC.gold, 'النقاط المكتسبة'),
                  SizedBox(width: 20),
                  _Legend(core_theme.AC.purple, 'النقاط المستبدلة'),
                  SizedBox(width: 20),
                  Text('نسبة الاستبدال ↑', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFE6C200)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.white, size: 40),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎉 Wave 100 — Milestone Reached',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    Text('منصّة APEX V5.1 تضم الآن 100 شاشة إنتاجية كاملة تغطي كل الجوانب المحاسبية والإدارية والاستراتيجية',
                        style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _catIcon(String c) {
    switch (c) {
      case 'discount':
        return Icons.local_offer;
      case 'upgrade':
        return Icons.arrow_upward;
      case 'consultation':
        return Icons.headset_mic;
      case 'event':
        return Icons.event;
      case 'subscription':
        return Icons.subscriptions;
      case 'whitepaper':
        return Icons.article;
      case 'gift':
        return Icons.card_giftcard;
      default:
        return Icons.star;
    }
  }

  String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _Tier {
  final String name;
  final String nameEn;
  final int minSpend;
  final int memberCount;
  final int pointsMultiplier;
  final Color color;
  final String emoji;
  const _Tier(this.name, this.nameEn, this.minSpend, this.memberCount, this.pointsMultiplier, this.color, this.emoji);
}

class _LoyalCust {
  final String id;
  final String name;
  final double totalSpend;
  final int totalPoints;
  final String tier;
  final int availablePoints;
  final Color tierColor;
  const _LoyalCust(this.id, this.name, this.totalSpend, this.totalPoints, this.tier, this.availablePoints, this.tierColor);
}

class _Reward {
  final String title;
  final String category;
  final int pointsCost;
  final int redeemed;
  final bool available;
  final Color color;
  const _Reward(this.title, this.category, this.pointsCost, this.redeemed, this.available, this.color);
}

class _MonthStat {
  final String month;
  final int pointsEarned;
  final int pointsRedeemed;
  final int redemptionRate;
  const _MonthStat(this.month, this.pointsEarned, this.pointsRedeemed, this.redemptionRate);
}
