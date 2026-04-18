import 'package:flutter/material.dart';

/// Wave 122 — Marketing Automation (HubSpot-class)
class MarketingAutomationScreen extends StatefulWidget {
  const MarketingAutomationScreen({super.key});
  @override
  State<MarketingAutomationScreen> createState() => _MarketingAutomationScreenState();
}

class _MarketingAutomationScreenState extends State<MarketingAutomationScreen> with SingleTickerProviderStateMixin {
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
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37), indicatorWeight: 3,
          tabs: const [Tab(text: 'الحملات'), Tab(text: 'خطوط التسويق'), Tab(text: 'تقييم العملاء'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_campsTab(), _funnelsTab(), _leadsTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE65100), Color(0xFFBF360C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.campaign, color: Color(0xFFBF360C), size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('أتمتة التسويق', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('حملات متعددة القنوات، Lead Scoring، Nurturing Automation', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('حملات نشطة', '${_camps.where((c)=>c.status.contains('نشط')).length}', Icons.campaign, const Color(0xFFE65100))),
    Expanded(child: _kpi('Leads', '${_leads.length}', Icons.person_add, const Color(0xFF4A148C))),
    Expanded(child: _kpi('MQL → SQL', '28%', Icons.trending_up, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('CAC', '485 ر.س', Icons.attach_money, const Color(0xFF1A237E))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _campsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _camps.length, itemBuilder: (_, i) {
    final c = _camps[i]; final ctr = c.clicks / c.impressions;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _channelColor(c.channel).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(_channelIcon(c.channel), color: _channelColor(c.channel))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(c.channel, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _statusColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(c.status, style: TextStyle(color: _statusColor(c.status), fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('ميزانية', '${(c.budget/1000).toStringAsFixed(0)}K'),
          _mini('مشاهدات', '${(c.impressions/1000).toStringAsFixed(0)}K'),
          _mini('نقرات', '${c.clicks}'),
          _mini('CTR', '${(ctr * 100).toStringAsFixed(1)}%'),
          _mini('تحويلات', '${c.conversions}'),
        ]),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 9, color: Colors.black54)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _funnelsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _funnel.length, itemBuilder: (_, i) {
    final f = _funnel[i]; final ratio = f.count / _funnel.first.count;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
            child: Text('${i+1}', style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Text(f.stage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Text('${f.count}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: Colors.black12, valueColor: const AlwaysStoppedAnimation(Color(0xFFE65100)))),
        const SizedBox(height: 4),
        Text('${(ratio * 100).toStringAsFixed(1)}% من البداية', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _leadsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _leads.length, itemBuilder: (_, i) {
    final l = _leads[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _scoreColor(l.score).withValues(alpha: 0.15),
        child: Text('${l.score}', style: TextStyle(color: _scoreColor(l.score), fontWeight: FontWeight.bold, fontSize: 14))),
      title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l.company} • ${l.source}', style: const TextStyle(fontSize: 11)),
        Text('${l.stage} • ${l.lastActivity}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: _scoreColor(l.score).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(l.temperature, style: TextStyle(color: _scoreColor(l.score), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🎯 ROI الحملات', '8.4x — كل ريال إنفاق يعود 8.4 ر.س', const Color(0xFF2E7D32)),
    _insight('📈 أفضل القنوات', 'LinkedIn 24% • Google 28% • WhatsApp 18% • البريد 12%', const Color(0xFFE65100)),
    _insight('⭐ Lead Score متوسط', '65/100 — Hot Leads 22%', const Color(0xFFD4AF37)),
    _insight('🔄 Nurturing Workflows', '14 تلقائي نشط — معدل فتح 42%', const Color(0xFF4A148C)),
    _insight('💌 A/B Testing', 'النسخة B تفوز في 68% من الاختبارات', const Color(0xFF1A237E)),
    _insight('📊 Attribution Model', 'Multi-touch — أعلى من Last-click بـ 34%', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('مجدول')) return const Color(0xFFD4AF37);
    if (s.contains('منتهي')) return Colors.black54;
    if (s.contains('متوقف')) return const Color(0xFFC62828);
    return const Color(0xFF1A237E);
  }

  Color _channelColor(String c) {
    if (c.contains('LinkedIn')) return const Color(0xFF0277BD);
    if (c.contains('Google')) return const Color(0xFFE65100);
    if (c.contains('بريد')) return const Color(0xFF4A148C);
    if (c.contains('WhatsApp')) return const Color(0xFF25D366);
    return const Color(0xFF1A237E);
  }

  IconData _channelIcon(String c) {
    if (c.contains('LinkedIn') || c.contains('Twitter')) return Icons.share;
    if (c.contains('Google')) return Icons.search;
    if (c.contains('بريد')) return Icons.email;
    if (c.contains('WhatsApp')) return Icons.chat;
    return Icons.campaign;
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFFC62828);
    if (s >= 60) return const Color(0xFFE65100);
    if (s >= 40) return const Color(0xFFD4AF37);
    return const Color(0xFF1A237E);
  }

  static const List<_Camp> _camps = [
    _Camp('حملة إطلاق APEX V5', 'LinkedIn Ads', 120_000, 842_000, 12_420, 145, 'نشط'),
    _Camp('Google Ads - ERP', 'Google Ads', 80_000, 1_240_000, 18_420, 248, 'نشط'),
    _Camp('Webinar المحاسبة الذكية', 'البريد الإلكتروني', 15_000, 24_800, 4_820, 320, 'نشط'),
    _Camp('SEO Campaign', 'Google Organic', 0, 428_000, 8_240, 82, 'نشط'),
    _Camp('WhatsApp Broadcast', 'WhatsApp', 5_000, 18_200, 6_820, 185, 'نشط'),
    _Camp('حملة Q1 السنوية', 'Twitter Ads', 45_000, 248_000, 3_420, 42, 'منتهي'),
    _Camp('إعادة Targeting', 'Google Display', 25_000, 520_000, 4_820, 62, 'مجدول'),
  ];

  static const List<_Stage> _funnel = [
    _Stage('زوار الموقع', 42_400),
    _Stage('Leads مولدة', 3_240),
    _Stage('MQL مؤهلة تسويقياً', 1_820),
    _Stage('SQL مؤهلة للمبيعات', 510),
    _Stage('فرص نشطة', 184),
    _Stage('عقود موقعة', 48),
  ];

  static const List<_Lead> _leads = [
    _Lead('أحمد المنصور', 'شركة الأفق', 'LinkedIn Form', 92, 'فرصة', 'Hot', 'حضر Webinar أمس'),
    _Lead('فاطمة السبيعي', 'مؤسسة الابتكار', 'Google Ads', 78, 'SQL', 'Hot', 'طلب Demo'),
    _Lead('Mike Johnson', 'شركة دولية', 'البريد الإلكتروني', 65, 'MQL', 'Warm', 'فتح 5 رسائل'),
    _Lead('نورة الشمري', 'معرض الجزيرة', 'WhatsApp', 48, 'Lead', 'Warm', 'رد على رسالة'),
    _Lead('خالد العتيبي', 'متجر صغير', 'Google Organic', 32, 'Lead', 'Cold', 'زار الموقع مرتين'),
    _Lead('شركة مجهولة', 'غير محدد', 'Twitter Ads', 18, 'Lead', 'Cold', 'نقرة واحدة'),
  ];
}

class _Camp { final String name, channel; final double budget; final int impressions, clicks, conversions; final String status;
  const _Camp(this.name, this.channel, this.budget, this.impressions, this.clicks, this.conversions, this.status); }
class _Stage { final String stage; final int count;
  const _Stage(this.stage, this.count); }
class _Lead { final String name, company, source; final int score; final String stage, temperature, lastActivity;
  const _Lead(this.name, this.company, this.source, this.score, this.stage, this.temperature, this.lastActivity); }
