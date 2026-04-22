import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 138 — Marketplace Provider Ratings & Reviews
class MarketplaceProviderRatingsScreen extends StatefulWidget {
  const MarketplaceProviderRatingsScreen({super.key});
  @override
  State<MarketplaceProviderRatingsScreen> createState() => _MarketplaceProviderRatingsScreenState();
}

class _MarketplaceProviderRatingsScreenState extends State<MarketplaceProviderRatingsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'نظرة عامة'), Tab(text: 'التقييمات'), Tab(text: 'التحليلات'), Tab(text: 'الرد على المراجعات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_overviewTab(), _reviewsTab(), _analyticsTab(), _respondTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFBF8F00)])),
    child: Row(children: [
      CircleAvatar(radius: 30, backgroundColor: Colors.white,
        child: Text('4.9', style: TextStyle(color: core_theme.AC.gold, fontSize: 22, fontWeight: FontWeight.bold))),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التقييمات والمراجعات', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Row(children: [
          Icon(Icons.star, color: Colors.white, size: 18),
          Icon(Icons.star, color: Colors.white, size: 18),
          Icon(Icons.star, color: Colors.white, size: 18),
          Icon(Icons.star, color: Colors.white, size: 18),
          Icon(Icons.star, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('128 تقييم • Top 3% على المنصة', style: TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('متوسط', '4.9/5', Icons.star, core_theme.AC.gold)),
    Expanded(child: _kpi('عدد المراجعات', '128', Icons.reviews, const Color(0xFF1A237E))),
    Expanded(child: _kpi('5 نجوم', '88%', Icons.thumb_up, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('معدل الرد', '100%', Icons.reply, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _overviewTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('توزيع التقييمات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: core_theme.AC.gold)),
      const SizedBox(height: 12),
      _distrBar('5 ★', 113, 128),
      _distrBar('4 ★', 11, 128),
      _distrBar('3 ★', 3, 128),
      _distrBar('2 ★', 1, 128),
      _distrBar('1 ★', 0, 128),
    ]))),
    const SizedBox(height: 14),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('أعلى الكلمات المستخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A148C))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _tag('احترافي', 48),
        _tag('دقيق', 42),
        _tag('سريع', 38),
        _tag('خبير', 35),
        _tag('موثوق', 32),
        _tag('متجاوب', 28),
        _tag('منظم', 22),
        _tag('ودود', 18),
        _tag('شفاف', 15),
      ]),
    ]))),
  ]);

  Widget _distrBar(String stars, int count, int total) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 40, child: Text(stars, style: const TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: count / total, minHeight: 14, backgroundColor: core_theme.AC.bdr,
        valueColor: AlwaysStoppedAnimation(core_theme.AC.gold)))),
      const SizedBox(width: 8),
      SizedBox(width: 40, child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
    ]));

  Widget _tag(String word, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: core_theme.AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(word, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(width: 6),
      Text('×$count', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
    ]),
  );

  Widget _reviewsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _reviews.length, itemBuilder: (_, i) {
    final r = _reviews[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.15),
            child: Text(r.author.substring(0, 1), style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${r.company} • ${r.date}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ])),
          Row(children: List.generate(5, (s) => Icon(Icons.star,
            color: s < r.rating ? core_theme.AC.gold : core_theme.AC.bdr, size: 16))),
        ]),
        const SizedBox(height: 8),
        Text('"${r.text}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 6),
        Text('المشروع: ${r.project}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        if (r.response != null) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.reply, size: 14, color: Color(0xFF2E7D32)),
                SizedBox(width: 6),
                Text('ردنا:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2E7D32))),
              ]),
              const SizedBox(height: 4),
              Text(r.response!, style: const TextStyle(fontSize: 11.5)),
            ]),
          ),
        ],
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📈 اتجاه التقييمات', 'متوسط 4.9/5 مستقر منذ 6 أشهر — لا تراجع', const Color(0xFF2E7D32)),
    _insight('🎯 معدل التوصية (NPS)', '72 نقطة — "Leader" حسب المعيار العالمي', core_theme.AC.gold),
    _insight('💬 معدل الرد', '100% — نرد على كل مراجعة خلال 24 ساعة', const Color(0xFF4A148C)),
    _insight('🌟 Top 3% على المنصة', 'ضمن أعلى 3% من المزوّدين في فئتنا', core_theme.AC.gold),
    _insight('📊 أداء الشهر', '12 مراجعة جديدة — كلها 5★', const Color(0xFF2E7D32)),
    _insight('⚠️ ملاحظات التحسين', 'عميلان طلبا إيصالات أسرع — تم تحسين النظام', const Color(0xFFE65100)),
  ]);

  Widget _respondTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _pendingResponses.length, itemBuilder: (_, i) {
    final r = _pendingResponses[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.author, style: const TextStyle(fontWeight: FontWeight.bold))),
          Row(children: List.generate(5, (s) => Icon(Icons.star,
            color: s < r.rating ? core_theme.AC.gold : core_theme.AC.bdr, size: 14))),
        ]),
        const SizedBox(height: 6),
        Text('"${r.text}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.smart_toy, size: 14),
            label: Text('اقتراح AI')),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.reply, size: 14),
            label: Text('رد'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
          ),
        ]),
      ]),
    ));
  });

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  static const List<_Review> _reviews = [
    _Review('أحمد المطيري', 'أرامكو السعودية', 'منذ 3 أيام', 5,
      'خدمة احترافية وسريعة. أنهوا تطبيق ZATCA قبل الموعد بأسبوع كامل. فريق فني متميز ومدير حساب متجاوب.',
      'تطبيق ZATCA Phase 2', 'شكراً أستاذ أحمد! يسعدنا أن نكون شريكاً موثوقاً لفريق أرامكو. سعدنا بإنجاز المشروع وبرعاية الإشرافية المقدمة.'),
    _Review('فاطمة السبيعي', 'سابك', 'منذ أسبوع', 5,
      'فريق رائع وخبير. قاموا بمراجعة إقرارات VAT للسنة كلها خلال 10 أيام بدقة 100%. ننصح بهم بقوة.',
      'مراجعة ضريبية سنوية', 'شكراً لثقتكم! فخورون بشراكتنا المستمرة مع سابك منذ 2019.'),
    _Review('محمد القحطاني', 'المراعي', 'منذ أسبوعين', 5,
      'دعم استثنائي خلال تطبيق IFRS 16. فريق ملتزم، شفاف في التواصل، وحلّ كل الملاحظات بسرعة.',
      'تطبيق IFRS 16 - Leasing', 'شكراً جزيلاً! خبرتنا مع فريق المراعي كانت غنية ومميزة.'),
    _Review('نورة الشمري', 'stc', 'منذ 3 أسابيع', 4,
      'جودة عالية وجدول زمني مُتبع. الملاحظة الوحيدة: تقارير مرحلية متأخرة بيوم أو اثنين. لكن النتيجة النهائية ممتازة.',
      'مراجعة الاعتراف بالإيرادات', 'شكراً على الملاحظة البناءة. حدّثنا نظام التقارير لتصل في موعدها تماماً.'),
    _Review('خالد الدوسري', 'بنك الراجحي', 'منذ شهر', 5,
      'احترافية + أمانة. هم أفضل مَن عاملنا معهم في آخر 5 سنوات. فريق كامل مؤهل.',
      'تدقيق Q4 2025', null),
    _Review('سارة المهندس', 'البنك الأهلي', 'منذ شهر', 5,
      'الفريق خبير جداً في GOSI + WPS. وفّرنا ساعات عمل كثيرة بفضل حلولهم المنهجية.',
      'تطبيق GOSI + WPS', 'نشكرك! فخورون بخدمة البنك الأهلي.'),
  ];

  static const List<_Review> _pendingResponses = [
    _Review('أحمد الغامدي', 'شركة ناشئة', 'اليوم', 5,
      'ممتازون في شرح المفاهيم للفريق الجديد. تدريب فعّال وعملي.',
      'تدريب IFRS + ZATCA', null),
    _Review('هند العتيبي', 'معرض الجزيرة', 'أمس', 4,
      'عمل جيد، لكن كنا نتوقع سعراً أقل. الجودة تستحق لكن الميزانية كانت مشدودة.',
      'إقرارات VAT Q1', null),
    _Review('فيصل الفهد', 'مجموعة تجارية', 'أمس', 5,
      'سرعة + دقة + شفافية. بالضبط ما نحتاج. سنعود بمشاريع أخرى.',
      'تسجيل فرع جديد', null),
  ];
}

class _Review { final String author, company, date; final int rating; final String text, project; final String? response;
  const _Review(this.author, this.company, this.date, this.rating, this.text, this.project, this.response); }
