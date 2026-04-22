import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 145 — Legal Document Automation
class LegalDocsAutomationScreen extends StatefulWidget {
  const LegalDocsAutomationScreen({super.key});
  @override
  State<LegalDocsAutomationScreen> createState() => _LegalDocsAutomationScreenState();
}

class _LegalDocsAutomationScreenState extends State<LegalDocsAutomationScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'القوالب'), Tab(text: 'المنشأة'), Tab(text: 'الموافقات'), Tab(text: 'E-Signature')])),
        Expanded(child: TabBarView(controller: _tc, children: [_templatesTab(), _createdTab(), _approvalsTab(), _signatureTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.auto_stories, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('أتمتة المستندات القانونية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('قوالب ذكية + توقيع إلكتروني + workflows', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('قوالب جاهزة', '${_templates.length}', Icons.description, const Color(0xFF1A237E))),
    Expanded(child: _kpi('مستندات هذا الشهر', '142', Icons.insert_drive_file, const Color(0xFF4A148C))),
    Expanded(child: _kpi('موقّعة', '128', Icons.verified, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('زمن التوقيع', '2.4 ساعة', Icons.speed, core_theme.AC.gold)),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _templatesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _templates.length, itemBuilder: (_, i) {
    final t = _templates[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _categoryColor(t.category).withValues(alpha: 0.15),
        child: Icon(_categoryIcon(t.category), color: _categoryColor(t.category))),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('${t.category} • ${t.fields} حقل متغير • استُخدم ${t.uses} مرة', style: const TextStyle(fontSize: 11)),
      trailing: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 14),
        label: Text('إنشاء'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
      ),
    ));
  });

  Widget _createdTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _created.length, itemBuilder: (_, i) {
    final d = _created[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: Icon(Icons.description, color: _statusColor(d.status)),
      title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      subtitle: Text('${d.counterparty} • ${d.date}', style: const TextStyle(fontSize: 10)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: _statusColor(d.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(d.status, style: TextStyle(color: _statusColor(d.status), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _approvalsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _approvals.length, itemBuilder: (_, i) {
    final a = _approvals[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.document, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text('قيمة العقد: ${a.value}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 10),
        Row(children: a.workflow.asMap().entries.map((e) {
          final step = e.value;
          final isLast = e.key == a.workflow.length - 1;
          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              CircleAvatar(radius: 14, backgroundColor: _stepColor(step.status),
                child: Icon(_stepIcon(step.status), color: Colors.white, size: 14)),
              const SizedBox(height: 4),
              Text(step.role, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(step.status, style: TextStyle(fontSize: 8, color: _stepColor(step.status))),
            ])),
            if (!isLast) Container(height: 2, width: 20, color: core_theme.AC.td),
          ]));
        }).toList()),
      ]),
    ));
  });

  Widget _signatureTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('📝 E-Signature Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A148C))),
      const SizedBox(height: 12),
      _provider('DocuSign', 'تكامل API', 'نشط', true),
      _provider('Tawqie (سعودي)', 'ZATCA-approved', 'نشط', true),
      _provider('Adobe Sign', 'Enterprise', 'متاح', false),
    ]))),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إحصائيات التوقيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const Divider(),
      _stat('مستندات وقّعت', '1,842 (كل الفترات)'),
      _stat('متوسط زمن التوقيع', '2.4 ساعة'),
      _stat('معدل الإنجاز', '98%'),
      _stat('معتمدة أمنياً', 'UETA + ESIGN + Saudi PKI'),
      _stat('أطراف متعددة', 'حتى 12 طرف/مستند'),
    ]))),
    const SizedBox(height: 12),
    _insight('🔐 أمان', 'توقيع رقمي بـ PKI + chain of custody + tamper-evident', const Color(0xFF2E7D32)),
    _insight('⚡ سرعة', 'متوسط 2.4 ساعة vs 5 أيام للتوقيع الورقي', core_theme.AC.gold),
    _insight('📱 متعدد المنصات', 'موبايل + ويب + WhatsApp + بريد إلكتروني', const Color(0xFF4A148C)),
  ]);

  Widget _provider(String name, String type, String status, bool connected) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(connected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: connected ? const Color(0xFF2E7D32) : core_theme.AC.td, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(type, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: connected ? const Color(0xFF2E7D32).withValues(alpha: 0.15) : core_theme.AC.bdr, borderRadius: BorderRadius.circular(8)),
        child: Text(status, style: TextStyle(color: connected ? const Color(0xFF2E7D32) : core_theme.AC.ts, fontSize: 10, fontWeight: FontWeight.bold))),
    ]));

  Widget _stat(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(fontSize: 12))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    ]));

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13)),
      const SizedBox(height: 4),
      Text(txt, style: const TextStyle(fontSize: 12)),
    ])));

  Color _categoryColor(String c) {
    if (c.contains('توظيف')) return const Color(0xFF2E7D32);
    if (c.contains('توريد')) return core_theme.AC.gold;
    if (c.contains('شراكة')) return const Color(0xFF4A148C);
    if (c.contains('NDA')) return const Color(0xFFC62828);
    if (c.contains('إيجار')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  IconData _categoryIcon(String c) {
    if (c.contains('توظيف')) return Icons.badge;
    if (c.contains('توريد')) return Icons.local_shipping;
    if (c.contains('شراكة')) return Icons.handshake;
    if (c.contains('NDA')) return Icons.lock;
    if (c.contains('إيجار')) return Icons.home;
    return Icons.description;
  }

  Color _statusColor(String s) {
    if (s.contains('موقع')) return const Color(0xFF2E7D32);
    if (s.contains('انتظار')) return core_theme.AC.gold;
    if (s.contains('مسودة')) return core_theme.AC.ts;
    if (s.contains('مرفوض')) return const Color(0xFFC62828);
    return const Color(0xFF1A237E);
  }

  Color _stepColor(String s) {
    if (s.contains('موافق')) return const Color(0xFF2E7D32);
    if (s.contains('قيد')) return core_theme.AC.gold;
    if (s.contains('رفض')) return const Color(0xFFC62828);
    return core_theme.AC.td;
  }

  IconData _stepIcon(String s) {
    if (s.contains('موافق')) return Icons.check;
    if (s.contains('قيد')) return Icons.hourglass_bottom;
    if (s.contains('رفض')) return Icons.close;
    return Icons.radio_button_unchecked;
  }

  static const List<_Template> _templates = [
    _Template('عقد توظيف - متوافق GOSI', 'توظيف', 22, 185),
    _Template('عقد توريد بضاعة', 'توريد', 18, 248),
    _Template('اتفاقية شراكة استراتيجية', 'شراكة', 34, 42),
    _Template('NDA - اتفاقية سرية', 'NDA', 12, 420),
    _Template('عقد إيجار تجاري', 'إيجار', 26, 58),
    _Template('اتفاقية خدمات SaaS', 'خدمات', 28, 140),
    _Template('عقد استشارات قانونية', 'استشارات', 20, 82),
    _Template('وكالة تجارية حصرية', 'وكالة', 32, 15),
  ];

  static const List<_Doc> _created = [
    _Doc('عقد توظيف - محمد الأحمد', 'محمد الأحمد', '2026-04-18', 'موقع'),
    _Doc('اتفاقية شراكة مع ABC Corp', 'ABC Corporation', '2026-04-17', 'انتظار'),
    _Doc('NDA - مفاوضات مع شركة التقنية', 'شركة التقنية المتقدمة', '2026-04-16', 'موقع'),
    _Doc('عقد توريد أجهزة', 'Al-Falak Computing', '2026-04-15', 'انتظار'),
    _Doc('عقد إيجار فرع الرياض', 'الشركة العقارية', '2026-04-14', 'مسودة'),
    _Doc('اتفاقية خدمات SaaS', 'stc Enterprise', '2026-04-12', 'موقع'),
  ];

  static const List<_Approval> _approvals = [
    _Approval('اتفاقية شراكة مع ABC Corp', '2.4M ر.س', [
      _Step('المدير المباشر', 'موافق'),
      _Step('قانوني', 'موافق'),
      _Step('مالي', 'قيد المراجعة'),
      _Step('الرئيس التنفيذي', 'معلق'),
    ]),
    _Approval('عقد توريد أجهزة', '925K ر.س', [
      _Step('المشتريات', 'موافق'),
      _Step('قانوني', 'موافق'),
      _Step('مالي', 'قيد المراجعة'),
      _Step('المدير التشغيلي', 'معلق'),
    ]),
    _Approval('عقد إيجار فرع الرياض', '480K ر.س', [
      _Step('الموارد', 'موافق'),
      _Step('قانوني', 'موافق'),
      _Step('مالي', 'موافق'),
      _Step('الرئيس التنفيذي', 'قيد المراجعة'),
    ]),
  ];
}

class _Template { final String name, category; final int fields, uses;
  const _Template(this.name, this.category, this.fields, this.uses); }
class _Doc { final String title, counterparty, date, status;
  const _Doc(this.title, this.counterparty, this.date, this.status); }
class _Approval { final String document, value; final List<_Step> workflow;
  const _Approval(this.document, this.value, this.workflow); }
class _Step { final String role, status;
  const _Step(this.role, this.status); }
