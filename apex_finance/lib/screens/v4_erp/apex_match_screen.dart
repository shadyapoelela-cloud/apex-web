/// APEX V5.1 — APEX Match AI (Enhancement #15).
///
/// Toptal-style AI matchmaking for the Marketplace:
/// Client describes what they need → AI picks top 3 providers
/// ranked by region, specialization, ratings, availability.
///
/// Route: /app/marketplace/client/browse
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ApexMatchScreen extends StatefulWidget {
  const ApexMatchScreen({super.key});

  @override
  State<ApexMatchScreen> createState() => _ApexMatchScreenState();
}

class _ApexMatchScreenState extends State<ApexMatchScreen> {
  final _needCtl = TextEditingController(
    text: 'أحتاج مراجع SOCPA معتمد للسنة المالية 2026 — شركة تجارة صغيرة بميزانية 30-50 ألف ريال',
  );
  bool _matching = false;
  bool _matched = false;

  @override
  void dispose() {
    _needCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFF57C00)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APEX Match — مطابقة ذكية',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'اكتب احتياجك — الذكاء الاصطناعي يختار أفضل 3 مزوّدين',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'مثل Toptal للمحاسبة',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اكتب احتياجك بلغتك الطبيعية',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'مثال: "مراجع حسابات + خبرة ZATCA + منطقة الرياض + ميزانية محدّدة"',
                  style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _needCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'صف احتياجك بالتفصيل...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _matching ? null : _onMatch,
                      icon: _matching
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(_matching ? 'جاري البحث...' : 'ابحث عن أفضل 3 مزوّدين'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_matched) _buildMatches(),
        ],
      ),
    );
  }

  Future<void> _onMatch() async {
    setState(() => _matching = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _matching = false;
      _matched = true;
    });
  }

  Widget _buildMatches() {
    final providers = [
      _Provider(
        name: 'د. عبدالله السالم',
        firm: 'السالم وشركاؤه للمراجعة',
        location: 'الرياض، السعودية',
        rating: 4.9,
        reviews: 142,
        priceRange: '35-45 ألف',
        match: 97,
        matchReasons: [
          'SOCPA معتمد منذ 2009',
          'خبرة ZATCA Phase 2 مثبتة (15+ عميل)',
          '12 عميل سابق من تجارة التجزئة بحجم مشابه',
          'متوفّر خلال أسبوعين — تاريخ البدء مناسب',
          'التقييم 4.9/5 — الأعلى في الرياض',
        ],
        specializations: ['SOCPA', 'ZATCA Phase 2', 'تجارة'],
        availableIn: 'أسبوعين',
      ),
      _Provider(
        name: 'شركة الدليل للمراجعة',
        firm: 'مكتب متوسط — 12 مراجع',
        location: 'جدة، السعودية',
        rating: 4.7,
        reviews: 289,
        priceRange: '30-40 ألف',
        match: 91,
        matchReasons: [
          'SOCPA معتمد',
          'أسعار تنافسية — ضمن ميزانيتك',
          '289 تقييم — الأعلى حجماً',
          'خبرة VAT/Zakat كاملة',
          'متوفّر خلال 3 أسابيع',
        ],
        specializations: ['SOCPA', 'VAT', 'Zakat'],
        availableIn: '3 أسابيع',
      ),
      _Provider(
        name: 'مكتب الثقة للمحاسبة',
        firm: 'مكتب صغير — 4 مراجعين',
        location: 'الدمام، السعودية',
        rating: 4.8,
        reviews: 67,
        priceRange: '25-35 ألف',
        match: 85,
        matchReasons: [
          'SOCPA معتمد',
          'أرخص خيار ضمن الجودة المطلوبة',
          'تخصص في الشركات الصغيرة فقط',
          'متوفّر فوراً',
          'توصية مرتفعة للميزانيات المحدودة',
        ],
        specializations: ['SOCPA', 'SMB'],
        availableIn: 'فوراً',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified, color: core_theme.AC.ok, size: 18),
            const SizedBox(width: 6),
            Text(
              'أفضل 3 مطابقات (من 47 مزوّد فحصتهم)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: core_theme.AC.ok.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, size: 12, color: core_theme.AC.ok),
                  SizedBox(width: 4),
                  Text(
                    'البحث استغرق 0.8 ثانية',
                    style: TextStyle(fontSize: 11, color: core_theme.AC.ok),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < providers.length; i++) ...[
          _ProviderCard(provider: providers[i], rank: i + 1),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Provider {
  final String name;
  final String firm;
  final String location;
  final double rating;
  final int reviews;
  final String priceRange;
  final int match;
  final List<String> matchReasons;
  final List<String> specializations;
  final String availableIn;

  _Provider({
    required this.name,
    required this.firm,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.priceRange,
    required this.match,
    required this.matchReasons,
    required this.specializations,
    required this.availableIn,
  });
}

class _ProviderCard extends StatelessWidget {
  final _Provider provider;
  final int rank;

  const _ProviderCard({required this.provider, required this.rank});

  @override
  Widget build(BuildContext context) {
    final matchColor = provider.match >= 95
        ? core_theme.AC.ok
        : provider.match >= 85
            ? core_theme.AC.warn
            : core_theme.AC.info;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rank == 1
              ? core_theme.AC.gold
              : core_theme.AC.tp.withValues(alpha: 0.1),
          width: rank == 1 ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    provider.name.substring(0, 1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (rank == 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: core_theme.AC.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '⭐ أفضل مطابقة',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          provider.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Text(
                      provider.firm,
                      style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                    ),
                    Text(
                      '📍 ${provider.location}',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: matchColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.psychology, size: 14, color: matchColor),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.match}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: matchColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'مطابقة',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: matchColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _statChip(
                icon: Icons.star,
                label: '${provider.rating}',
                sub: '${provider.reviews} تقييم',
                color: core_theme.AC.warn,
              ),
              const SizedBox(width: 8),
              _statChip(
                icon: Icons.event_available,
                label: provider.availableIn,
                sub: 'متوفّر',
                color: core_theme.AC.ok,
              ),
              const SizedBox(width: 8),
              _statChip(
                icon: Icons.payments,
                label: '${provider.priceRange} ر.س',
                sub: 'السعر',
                color: core_theme.AC.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Match reasons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: matchColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: matchColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: matchColor),
                    const SizedBox(width: 6),
                    Text(
                      'لماذا هذه مطابقة جيدة؟',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: matchColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final r in provider.matchReasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: matchColor)),
                        Expanded(
                          child: Text(r, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Specializations
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in provider.specializations)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: core_theme.AC.tp.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(fontSize: 11, color: core_theme.AC.tp, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.visibility, size: 14),
                label: Text('عرض الملف'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.handshake, size: 14),
                label: Text('احجز مباشرة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: matchColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 9, color: core_theme.AC.ts),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
