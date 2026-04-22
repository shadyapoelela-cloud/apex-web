import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 135 — Marketplace Client Requests (RFP)
class MarketplaceClientRequestsScreen extends StatefulWidget {
  const MarketplaceClientRequestsScreen({super.key});
  @override
  State<MarketplaceClientRequestsScreen> createState() => _MarketplaceClientRequestsScreenState();
}

class _MarketplaceClientRequestsScreenState extends State<MarketplaceClientRequestsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'طلباتي'), Tab(text: 'عروض مُقدّمة'), Tab(text: 'طلب جديد'), Tab(text: 'السجل')])),
        Expanded(child: TabBarView(controller: _tc, children: [_requestsTab(), _proposalsTab(), _newRequestTab(), _historyTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE65100), Color(0xFFBF360C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.request_page, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('طلبات الخدمات (RFP)', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('قدّم طلب خدمة، قارن العروض، اختر المزوّد المناسب', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('طلبات نشطة', '${_requests.where((r)=>r.status.contains('نشط')).length}', Icons.work_outline, const Color(0xFFBF360C))),
    Expanded(child: _kpi('عروض واردة', '${_proposals.length}', Icons.inbox, const Color(0xFF1A237E))),
    Expanded(child: _kpi('مكتمل', '${_requests.where((r)=>r.status.contains('مكتمل')).length}', Icons.check_circle, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('إجمالي الإنفاق', '148K ر.س', Icons.payments, core_theme.AC.gold)),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _requestsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _requests.length, itemBuilder: (_, i) {
    final r = _requests[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _statusColor(r.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.request_page, color: _statusColor(r.status))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${r.category} • ${r.id}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(r.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(r.status, style: TextStyle(color: _statusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('الميزانية', r.budget),
          _mini('الموعد', r.deadline),
          _mini('عروض', '${r.proposalsCount}'),
        ]),
        const SizedBox(height: 8),
        Text(r.description, style: TextStyle(fontSize: 12, color: core_theme.AC.tp)),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  ]));

  Widget _proposalsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _proposals.length, itemBuilder: (_, i) {
    final p = _proposals[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
            child: Text(p.provider.substring(0, 1), style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.provider, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(p.requestTitle, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [Icon(Icons.star, color: core_theme.AC.gold, size: 14), Text(' ${p.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
            Text('${p.reviews} تقييم', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('السعر', p.price),
          _mini('المدة', p.duration),
          _mini('خبرة', '${p.yearsExperience} سنة'),
        ]),
        const SizedBox(height: 8),
        Text(p.proposal, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton(onPressed: () {}, child: Text('تفاصيل أكثر')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: Text('قبول العرض'),
          ),
        ]),
      ]),
    ));
  });

  Widget _newRequestTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إنشاء طلب خدمة جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFBF360C))),
      const SizedBox(height: 14),
      _field('عنوان الطلب', 'مثال: مراجعة ضريبية للسنة المالية 2025'),
      _field('الفئة', 'اختر: محاسبة / ضرائب / مراجعة / استشارات'),
      _field('وصف تفصيلي', 'اشرح المطلوب بالتفصيل...'),
      _field('الميزانية', 'من - إلى (ر.س)'),
      _field('الموعد النهائي', 'DD/MM/YYYY'),
      _field('عدد العروض المطلوبة', 'افتراضي: 5'),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.send),
        label: Text('نشر الطلب'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBF360C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    ]))),
  ]);

  Widget _field(String label, String hint) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      const SizedBox(height: 4),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
        child: Text(hint, style: TextStyle(color: core_theme.AC.td, fontSize: 11))),
    ]));

  Widget _historyTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _history.length, itemBuilder: (_, i) {
    final h = _history[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: Icon(Icons.history, color: _statusColor(h.$3)),
      title: Text(h.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      subtitle: Text('${h.$2} • ${h.$3}', style: const TextStyle(fontSize: 10)),
      trailing: Text(h.$4, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
    ));
  });

  Color _statusColor(String s) {
    if (s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('نشط')) return core_theme.AC.gold;
    if (s.contains('مراجعة')) return const Color(0xFFE65100);
    if (s.contains('ملغى')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  static const List<_Request> _requests = [
    _Request('RFP-2026-0012', 'مراجعة ضريبية - FY2025', 'مراجعة', '15,000 - 25,000 ر.س', '2026-05-10', 7, 'نشط - 3 عروض', 'نحتاج مراجعة شاملة لإقرارات VAT و Zakat للسنة المالية 2025 مع تدقيق المستندات الداعمة'),
    _Request('RFP-2026-0011', 'تطبيق ZATCA Phase 2', 'تقنية', '40,000 - 60,000 ر.س', '2026-06-01', 5, 'مراجعة العروض', 'تطوير وتكامل فوترة إلكترونية مع نظام ZATCA Fatoora مع شهادة CSID'),
    _Request('RFP-2026-0010', 'إعداد ميزانية 2026', 'استشارات', '20,000 - 30,000 ر.س', '2026-04-30', 4, 'نشط - 4 عروض', 'إعداد ميزانية شاملة للسنة القادمة مع تحليل سيناريوهات متعددة'),
    _Request('RFP-2026-0009', 'تدقيق الأنظمة الداخلية', 'مراجعة', '18,000 ر.س', '2026-03-15', 6, 'مكتمل', 'تدقيق ضوابط الأنظمة الداخلية ومراجعة السياسات'),
    _Request('RFP-2026-0008', 'تسجيل شركة جديدة', 'قانونية', '8,000 - 12,000 ر.س', '2026-03-01', 3, 'مكتمل', 'تسجيل فرع جديد في المنطقة الاقتصادية الخاصة + GOSI + CR'),
  ];

  static const List<_Proposal> _proposals = [
    _Proposal('مكتب الراجحي للاستشارات', 'مراجعة ضريبية - FY2025', '18,000 ر.س', '10 أيام عمل', 12, 4.9, 128,
      'نقدم مراجعة شاملة تشمل VAT + Zakat + WHT مع تقرير مفصل وتوصيات تحسينية. فريق معتمد من SOCPA'),
    _Proposal('شركة النخبة للمحاسبة', 'مراجعة ضريبية - FY2025', '22,500 ر.س', '7 أيام عمل', 18, 4.8, 245,
      'خدمة VIP مع مدير حساب مخصص + اجتماع أسبوعي + تقارير ربع سنوية للعام القادم'),
    _Proposal('أحمد السبيعي CPA', 'مراجعة ضريبية - FY2025', '14,500 ر.س', '12 يوم عمل', 8, 4.7, 45,
      'خبرة مباشرة مع هيئة الزكاة + ZATCA. حلول عملية مع تدريب فريقك'),
    _Proposal('KPMG السعودية', 'تطبيق ZATCA Phase 2', '58,000 ر.س', '8 أسابيع', 25, 5.0, 512,
      'حل enterprise-grade مع تدريب + دعم 12 شهر + SLA 99.9%. أكبر شبكة عملاء ZATCA'),
    _Proposal('Alnefaee Tech', 'تطبيق ZATCA Phase 2', '42,000 ر.س', '6 أسابيع', 8, 4.6, 32,
      'تكامل سريع مع ERP الحالي عبر API. شهادة CSID + QR code + اختبار UAT'),
    _Proposal('شركة الخبير', 'إعداد ميزانية 2026', '25,000 ر.س', '15 يوم عمل', 20, 4.9, 186,
      'نموذج مالي ديناميكي 5 سنوات + تحليل حساسية + عرض تقديمي للمجلس'),
  ];

  static const List<(String, String, String, String)> _history = [
    ('RFP-2026-0009 تدقيق الأنظمة', 'قبول عرض', 'مكتمل', '10:30'),
    ('RFP-2026-0012 مراجعة ضريبية', 'عرض جديد', 'مراجعة', '09:15'),
    ('RFP-2026-0011 ZATCA Phase 2', 'تحديث', 'مراجعة', '08:45'),
    ('RFP-2026-0008 تسجيل شركة', 'دفعة نهائية', 'مكتمل', 'أمس'),
    ('RFP-2026-0010 ميزانية 2026', 'نشر', 'نشط', 'منذ يومين'),
  ];
}

class _Request { final String id, title, category, budget, deadline; final int proposalsCount; final String status, description;
  const _Request(this.id, this.title, this.category, this.budget, this.deadline, this.proposalsCount, this.status, this.description); }
class _Proposal { final String provider, requestTitle, price, duration; final int yearsExperience; final double rating; final int reviews; final String proposal;
  const _Proposal(this.provider, this.requestTitle, this.price, this.duration, this.yearsExperience, this.rating, this.reviews, this.proposal); }
