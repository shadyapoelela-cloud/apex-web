import 'package:flutter/material.dart';

/// Wave 110 — WhatsApp Business / Customer Messaging
class WhatsappBusinessScreen extends StatefulWidget {
  const WhatsappBusinessScreen({super.key});
  @override
  State<WhatsappBusinessScreen> createState() => _WhatsappBusinessScreenState();
}

class _WhatsappBusinessScreenState extends State<WhatsappBusinessScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(child: Column(children: [
          _hero(), _kpis(),
          Container(color: Colors.white, child: TabBar(
            controller: _tc, labelColor: const Color(0xFF4A148C), unselectedLabelColor: Colors.black54,
            indicatorColor: const Color(0xFFD4AF37), indicatorWeight: 3,
            tabs: const [
              Tab(text: 'المحادثات'), Tab(text: 'الحملات'), Tab(text: 'القوالب'), Tab(text: 'التحليلات'),
            ],
          )),
          Expanded(child: TabBarView(controller: _tc, children: [
            _chatsTab(), _campaignsTab(), _templatesTab(), _analyticsTab(),
          ])),
        ])),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WhatsApp Business 🎉 Wave 110', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('خدمة العملاء وإشعارات الحملات عبر WhatsApp Business API', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16), SizedBox(width: 4),
          Text('API موثق', style: TextStyle(color: Colors.white, fontSize: 12)),
        ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('محادثات اليوم', '${_chats.length * 12}', Icons.chat_bubble, const Color(0xFF25D366))),
    Expanded(child: _kpi('معدل الرد', '4.2 دقيقة', Icons.timer, const Color(0xFF1A237E))),
    Expanded(child: _kpi('حملات نشطة', '${_campaigns.where((c)=>c.status.contains('نشط')).length}', Icons.campaign, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('معدل الفتح', '87%', Icons.visibility, const Color(0xFF2E7D32))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 24), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _chatsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _chats.length, itemBuilder: (_, i) {
    final c = _chats[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: Stack(children: [
        CircleAvatar(backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2), child: Text(c.initials, style: const TextStyle(color: Color(0xFF128C7E), fontWeight: FontWeight.bold))),
        if (c.unread > 0) Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle), child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
      ]),
      title: Row(children: [
        Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        Text(c.time, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
      subtitle: Row(children: [
        Icon(c.lastByMe ? Icons.done_all : Icons.chat_bubble_outline, size: 12, color: c.lastByMe ? const Color(0xFF25D366) : Colors.black54),
        const SizedBox(width: 4),
        Expanded(child: Text(c.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
      ]),
    ));
  });

  Widget _campaignsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _campaigns.length, itemBuilder: (_, i) {
    final c = _campaigns[i]; final openRate = c.opens / c.sent;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.campaign, color: Color(0xFF25D366))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(c.segment, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _campStatus(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(c.status, style: TextStyle(color: _campStatus(c.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _miniStat('مرسل', '${c.sent}'),
          _miniStat('فتح', '${c.opens}'),
          _miniStat('رد', '${c.replies}'),
          _miniStat('فتح %', '${(openRate * 100).toStringAsFixed(0)}%'),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: openRate.clamp(0, 1), minHeight: 5, backgroundColor: Colors.black12, valueColor: const AlwaysStoppedAnimation(Color(0xFF25D366)))),
      ]),
    ));
  });

  Widget _miniStat(String l, String v) => Expanded(child: Column(children: [
    Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
  ]));

  Widget _templatesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _templates.length, itemBuilder: (_, i) {
    final t = _templates[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _categoryColor(t.category).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(_categoryIcon(t.category), color: _categoryColor(t.category), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: t.approved ? const Color(0xFF25D366).withValues(alpha: 0.15) : Colors.black12, borderRadius: BorderRadius.circular(10)),
            child: Text(t.approved ? 'موافق WhatsApp' : 'قيد المراجعة',
              style: TextStyle(color: t.approved ? const Color(0xFF128C7E) : Colors.black54, fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFECE5DD), borderRadius: BorderRadius.circular(8)),
          child: Text(t.body, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        const SizedBox(height: 6),
        Text('استُخدم ${t.usageCount} مرة • ${t.category}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📱 قنوات التواصل', '78% WhatsApp • 12% SMS • 8% Email • 2% Call', const Color(0xFF25D366)),
    _insight('⚡ سرعة الرد', 'متوسط 4.2 دقيقة — أقل من الصناعة (12 دقيقة)', const Color(0xFF1A237E)),
    _insight('🎯 حملات مؤتمتة', '87% معدل الفتح — أعلى 6x من البريد الإلكتروني', const Color(0xFFD4AF37)),
    _insight('💬 رضا العملاء', 'CSAT 4.6/5 على محادثات WhatsApp', const Color(0xFF2E7D32)),
    _insight('🔔 إشعارات تلقائية', '1,248 إشعار ZATCA + تذكير دفع هذا الشهر', const Color(0xFF4A148C)),
    _insight('🌟 Wave 110 — إنجاز كبير', 'تجاوزنا 110 شاشة إنتاجية بالكامل! 🎉', const Color(0xFFD4AF37)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _campStatus(String s) {
    if (s.contains('نشط')) return const Color(0xFF25D366);
    if (s.contains('مكتمل')) return const Color(0xFF1A237E);
    if (s.contains('مجدول')) return const Color(0xFFD4AF37);
    return Colors.black54;
  }

  Color _categoryColor(String c) {
    if (c.contains('فاتورة')) return const Color(0xFFD4AF37);
    if (c.contains('تذكير')) return const Color(0xFFE65100);
    if (c.contains('تسويق')) return const Color(0xFF4A148C);
    if (c.contains('خدمة')) return const Color(0xFF25D366);
    return const Color(0xFF1A237E);
  }

  IconData _categoryIcon(String c) {
    if (c.contains('فاتورة')) return Icons.receipt;
    if (c.contains('تذكير')) return Icons.alarm;
    if (c.contains('تسويق')) return Icons.campaign;
    if (c.contains('خدمة')) return Icons.support_agent;
    return Icons.message;
  }

  static const List<_Chat> _chats = [
    _Chat('أ ع', 'أحمد العتيبي', 'شكراً، الفاتورة وصلت', '10:45', 0, true),
    _Chat('ف س', 'فاطمة السبيعي', 'متى موعد التسليم القادم؟', '10:32', 2, false),
    _Chat('م ق', 'شركة الحلول التقنية', 'نحتاج تفاصيل العقد الجديد', '09:55', 1, false),
    _Chat('س م', 'سارة المهندس', 'تم التحويل — يرجى التأكيد', '09:12', 0, true),
    _Chat('خ ز', 'خالد الزهراني', 'هل يوجد خصم للكمية؟', '08:45', 3, false),
    _Chat('ن ش', 'نورة الشمري', 'تم ✓', '08:20', 0, true),
  ];

  static const List<_Campaign> _campaigns = [
    _Campaign('عرض رمضان 2026', 'عملاء VIP', 3420, 2980, 892, 'مكتمل'),
    _Campaign('تذكير تجديد اشتراك', 'مشتركين Q2', 1240, 1108, 456, 'نشط'),
    _Campaign('إطلاق منتج جديد', 'جميع العملاء', 8450, 7340, 1820, 'نشط'),
    _Campaign('استطلاع رضا عملاء', 'عملاء آخر 90 يوم', 2100, 1680, 920, 'مكتمل'),
    _Campaign('دعوة معرض ساينتيفيك', 'صناعة الأدوية', 340, 0, 0, 'مجدول'),
  ];

  static const List<_Template> _templates = [
    _Template('إشعار فاتورة جديدة', 'فواتير ZATCA',
      'مرحباً {اسم_العميل}، فاتورتك رقم {رقم_الفاتورة} بقيمة {المبلغ} ر.س جاهزة. يمكنك الاطلاع على: {رابط}',
      true, 4824),
    _Template('تذكير دفع مستحق', 'تذكير دفع',
      'عزيزنا {اسم_العميل}، نذكرك بفاتورة {رقم_الفاتورة} المستحقة في {تاريخ_الاستحقاق}. المبلغ: {المبلغ} ر.س',
      true, 2140),
    _Template('تأكيد طلب', 'خدمة عملاء',
      'شكراً لطلبك رقم {رقم_الطلب}. سيتم التسليم في {تاريخ_التسليم}. يمكنك تتبع الشحنة عبر: {رابط}',
      true, 3620),
    _Template('عرض خاص ترويجي', 'تسويق',
      '🎉 خصم حصري {نسبة}% على {المنتج} لفترة محدودة حتى {تاريخ_الانتهاء}. اطلب الآن: {رابط}',
      true, 8940),
    _Template('رسالة ترحيب', 'خدمة عملاء',
      'أهلاً بك في {اسم_الشركة}! نحن هنا لمساعدتك. اكتب "قائمة" لرؤية خدماتنا',
      true, 1240),
  ];
}

class _Chat { final String initials, name, lastMessage, time; final int unread; final bool lastByMe;
  const _Chat(this.initials, this.name, this.lastMessage, this.time, this.unread, this.lastByMe); }
class _Campaign { final String name, segment; final int sent, opens, replies; final String status;
  const _Campaign(this.name, this.segment, this.sent, this.opens, this.replies, this.status); }
class _Template { final String name, category, body; final bool approved; final int usageCount;
  const _Template(this.name, this.category, this.body, this.approved, this.usageCount); }
