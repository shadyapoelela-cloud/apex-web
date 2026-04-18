/// APEX Wave 75 — Sales Commission Engine.
/// Route: /app/erp/hr/commissions
///
/// Salesperson quota tracking + multi-tier commission rules.
library;

import 'package:flutter/material.dart';

class CommissionEngineScreen extends StatefulWidget {
  const CommissionEngineScreen({super.key});
  @override
  State<CommissionEngineScreen> createState() => _CommissionEngineScreenState();
}

class _CommissionEngineScreenState extends State<CommissionEngineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _reps = <_Rep>[
    _Rep('SR-001', 'محمد القحطاني', 'Senior Sales Manager', 600000, 780000, 5, 12),
    _Rep('SR-002', 'سارة الدوسري', 'Sales Manager', 450000, 612000, 4, 9),
    _Rep('SR-003', 'نورة الغامدي', 'Senior AE', 380000, 395000, 3, 7),
    _Rep('SR-004', 'فهد الشمري', 'AE', 280000, 245000, 2, 5),
    _Rep('SR-005', 'لينا البكري', 'AE', 280000, 342000, 3, 8),
    _Rep('SR-006', 'أحمد العنزي', 'Junior AE', 180000, 98000, 1, 3),
  ];

  final _tiers = const [
    _Tier('أقل من 70%', 0, 70, 0, Colors.red),
    _Tier('عند التحقيق 70-100%', 70, 100, 3, Colors.amber),
    _Tier('التحقيق الكامل 100-120%', 100, 120, 5, Colors.green),
    _Tier('متفوّق 120-150%', 120, 150, 8, Colors.teal),
    _Tier('فوق التوقع > 150%', 150, 1000, 12, Color(0xFFD4AF37)),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard, size: 16), text: 'أداء مندوبي المبيعات'),
            Tab(icon: Icon(Icons.tune, size: 16), text: 'قواعد العمولة'),
            Tab(icon: Icon(Icons.calculate, size: 16), text: 'حسابات الدفع'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildLeaderboardTab(),
              _buildRulesTab(),
              _buildPayoutsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    final totalSold = _reps.fold(0.0, (s, r) => s + r.actual);
    final totalCommission = _reps.fold(0.0, (s, r) => s + _calcCommission(r));
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محرّك العمولات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('حوافز المبيعات — قواعد متدرّجة · تحقيق الحصص · حسابات تلقائية',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          _heroStat('المبيعات Q2', _fmtM(totalSold), Icons.trending_up),
          const SizedBox(width: 10),
          _heroStat('العمولات المستحقة', _fmtM(totalCommission), Icons.payments),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final sorted = List<_Rep>.from(_reps)..sort((a, b) => b.actual.compareTo(a.actual));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final r = sorted[i];
        final pct = r.actual / r.quota * 100;
        final commission = _calcCommission(r);
        final tier = _tiers.firstWhere((t) => pct >= t.minPct && pct < t.maxPct, orElse: () => _tiers.last);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tier.color.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: i == 0
                      ? const Color(0xFFFFD700)
                      : i == 1
                          ? Colors.grey.shade400
                          : i == 2
                              ? Colors.orange.shade300
                              : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: i < 3 ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.id,
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black54)),
                        const SizedBox(width: 6),
                        Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text(r.title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text('${r.deals} صفقة · ${r.activeCustomers} عميل نشط',
                        style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_fmtM(r.actual),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                        Text(' / ${_fmtM(r.quota)}',
                            style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 2.0),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(tier.color),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${pct.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: tier.color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${tier.rate}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('العمولة', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(_fmt(commission),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                  const Text('ر.س', style: TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
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
                  'القاعدة: العمولة = (الإيرادات المحقّقة − الحصة) × معدل الشريحة. الأداء أقل من 70% = بدون عمولة. الشرائح تتصاعد مع التفوق في التحقيق.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('شرائح العمولة 2026', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (final t in _tiers)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: t.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('${t.rate}%',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      Text(
                        'النطاق: ${t.minPct}% — ${t.maxPct >= 1000 ? '∞' : '${t.maxPct}%'} من تحقيق الحصة',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.rate == 0 ? 'لا عمولة' : 'نسبة: ${t.rate}% من المتجاوز',
                    style: TextStyle(fontSize: 11, color: t.color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFFD4AF37)),
                  SizedBox(width: 8),
                  Text('مكافآت إضافية (Accelerators)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              _accRow('🏆', 'أعلى مندوب في الربع', '10,000 ر.س إضافية'),
              _accRow('🎯', 'تجاوز 150% في 3 أرباع متتالية', '25,000 ر.س + ترقية للنطاق الأعلى'),
              _accRow('🌟', 'عميل جديد استراتيجي (> 1M ر.س)', '2% إضافية على الصفقة'),
              _accRow('🚀', 'تصفيق صفقة في الوقت (Early close)', '0.5% إضافية'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accRow(String emoji, String condition, String reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(condition, style: const TextStyle(fontSize: 12))),
          Text(reward, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37))),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab() {
    final payouts = _reps.map((r) => _Payout(r, _calcCommission(r))).where((p) => p.commission > 0).toList();
    payouts.sort((a, b) => b.commission.compareTo(a.commission));
    final totalPayout = payouts.fold(0.0, (s, p) => s + p.commission);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFE6C200)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.payments, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مسير العمولات — أبريل 2026',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${6} مندوب مستحق',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(_fmt(totalPayout),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const Text(' ر.س', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('المندوب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('المبيعات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('التحقيق', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الشريحة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('العمولة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
                    SizedBox(width: 120),
                  ],
                ),
              ),
              for (final p in payouts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15),
                              child: Text(p.rep.name.substring(0, 1),
                                  style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p.rep.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(_fmtM(p.rep.actual), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                      Expanded(child: Text('${(p.rep.actual / p.rep.quota * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('${_getTier(p.rep).rate}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _getTier(p.rep).color))),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt(p.commission),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD4AF37),
                                fontFamily: 'monospace')),
                      ),
                      SizedBox(
                        width: 120,
                        child: Row(
                          children: [
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                              ),
                              child: const Text('مراجعة', style: TextStyle(fontSize: 10)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                              ),
                              child: const Text('اعتماد', style: TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  _Tier _getTier(_Rep r) {
    final pct = r.actual / r.quota * 100;
    return _tiers.firstWhere((t) => pct >= t.minPct && pct < t.maxPct, orElse: () => _tiers.last);
  }

  double _calcCommission(_Rep r) {
    final tier = _getTier(r);
    if (tier.rate == 0) return 0;
    final excess = (r.actual - r.quota).clamp(0.0, double.infinity);
    return excess * tier.rate / 100 + (r.actual * 0.01); // 1% base + tier bonus
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Rep {
  final String id;
  final String name;
  final String title;
  final double quota;
  final double actual;
  final int deals;
  final int activeCustomers;
  const _Rep(this.id, this.name, this.title, this.quota, this.actual, this.deals, this.activeCustomers);
}

class _Tier {
  final String name;
  final double minPct;
  final double maxPct;
  final int rate;
  final Color color;
  const _Tier(this.name, this.minPct, this.maxPct, this.rate, this.color);
}

class _Payout {
  final _Rep rep;
  final double commission;
  const _Payout(this.rep, this.commission);
}
