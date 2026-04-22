import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 119 — Field Service Management
class FieldServiceScreen extends StatefulWidget {
  const FieldServiceScreen({super.key});
  @override
  State<FieldServiceScreen> createState() => _FieldServiceScreenState();
}

class _FieldServiceScreenState extends State<FieldServiceScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'أوامر العمل'), Tab(text: 'الفنيون'), Tab(text: 'الجدولة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_ordersTab(), _techsTab(), _scheduleTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.engineering, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إدارة الخدمة الميدانية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('إرسال الفنيين، جدولة، GPS، OTP توقيع إلكتروني', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('أوامر اليوم', '${_orders.length}', Icons.assignment, const Color(0xFF1A237E))),
    Expanded(child: _kpi('قيد التنفيذ', '${_orders.where((o)=>o.status.contains('قيد')).length}', Icons.engineering, const Color(0xFFE65100))),
    Expanded(child: _kpi('الفنيون', '${_techs.length}', Icons.group, const Color(0xFF4A148C))),
    Expanded(child: _kpi('SLA Met', '94%', Icons.schedule, const Color(0xFF2E7D32))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _ordersTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _orders.length, itemBuilder: (_, i) {
    final o = _orders[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _priorityColor(o.priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.build_circle, color: Color(0xFF4A148C))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${o.customer} • ${o.service}', style: const TextStyle(fontSize: 11)),
            Text('📍 ${o.location}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _priorityColor(o.priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(o.priority, style: TextStyle(color: _priorityColor(o.priority), fontSize: 9, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Text(o.status, style: TextStyle(color: _statusColor(o.status), fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.person, size: 14, color: core_theme.AC.ts),
          const SizedBox(width: 4),
          Expanded(child: Text('الفني: ${o.technician}', style: const TextStyle(fontSize: 11))),
          Icon(Icons.schedule, size: 14, color: core_theme.AC.ts),
          const SizedBox(width: 4),
          Text(o.scheduledTime, style: const TextStyle(fontSize: 11)),
        ]),
      ]),
    ));
  });

  Widget _techsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _techs.length, itemBuilder: (_, i) {
    final t = _techs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: Stack(children: [
        CircleAvatar(backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
          child: Text(t.name.substring(0, 1), style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold))),
        Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(
          color: _availColor(t.availability), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
      ]),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${t.specialty} • ${t.city}', style: const TextStyle(fontSize: 11)),
        Row(children: [
          Icon(Icons.star, color: core_theme.AC.gold, size: 12),
          Text(' ${t.rating}', style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 8),
          Text('${t.completedToday} اليوم', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ]),
      ]),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: _availColor(t.availability).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(t.availability, style: TextStyle(color: _availColor(t.availability), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _scheduleTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _techs.length, itemBuilder: (_, i) {
    final t = _techs[i]; final tasks = _orders.where((o)=>o.technician==t.name).toList();
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
            child: Text(t.name.substring(0, 1), style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text('${tasks.length} مهام', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ]),
        if (tasks.isEmpty) Padding(padding: EdgeInsets.all(8), child: Text('لا مهام اليوم', style: TextStyle(fontSize: 11, color: core_theme.AC.td))),
        ...tasks.map((o) => Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
          Container(width: 4, height: 32, decoration: BoxDecoration(color: _priorityColor(o.priority), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            Text('${o.scheduledTime} • ${o.service}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ])),
        ]))),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('⏱️ زمن الاستجابة', 'متوسط 42 دقيقة للطلبات العاجلة', const Color(0xFF2E7D32)),
    _insight('✅ Fix-First-Visit', '87% من الطلبات تُحل في الزيارة الأولى', const Color(0xFF1A237E)),
    _insight('📍 كفاءة المسار', 'خوارزمية AI توفر 24% من الوقود', core_theme.AC.gold),
    _insight('⭐ رضا العملاء', '4.7/5 متوسط التقييمات', const Color(0xFF4A148C)),
    _insight('💰 إيرادات الخدمات', '2.8M ر.س شهرياً — نمو 18%', const Color(0xFF2E7D32)),
    _insight('🚨 SLA Breaches', '6% فقط — تحسن 40% YoY', const Color(0xFFE65100)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _priorityColor(String p) {
    if (p.contains('عاجل')) return const Color(0xFFC62828);
    if (p.contains('عالي')) return const Color(0xFFE65100);
    if (p.contains('عادي')) return const Color(0xFF1A237E);
    return const Color(0xFF2E7D32);
  }

  Color _statusColor(String s) {
    if (s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('قيد')) return const Color(0xFFE65100);
    if (s.contains('مجدول')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  Color _availColor(String a) {
    if (a.contains('متاح')) return const Color(0xFF2E7D32);
    if (a.contains('في المسار')) return const Color(0xFFE65100);
    if (a.contains('مشغول')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  static const List<_Order> _orders = [
    _Order('WO-2026-0145', 'شركة الأفق', 'صيانة مكيفات', 'الرياض - العليا', 'عاجل', 'أحمد الفني', '10:00 - 12:00', 'قيد التنفيذ'),
    _Order('WO-2026-0146', 'مطعم السلطان', 'إصلاح معدات مطبخ', 'جدة - الحمراء', 'عاجل', 'محمد المهندس', '09:30 - 11:30', 'قيد التنفيذ'),
    _Order('WO-2026-0147', 'بنك الرياض - فرع', 'فحص دوري ATM', 'الدمام - الشاطئ', 'عادي', 'خالد الفني', '14:00 - 15:00', 'مجدول'),
    _Order('WO-2026-0148', 'مستشفى الحبيب', 'صيانة أجهزة طبية', 'الرياض - السليمانية', 'عالي', 'فيصل المهندس', '11:00 - 13:00', 'قيد التنفيذ'),
    _Order('WO-2026-0149', 'فندق الفيصلية', 'إصلاح مصعد', 'الرياض - العليا', 'عالي', 'أحمد الفني', '15:00 - 17:00', 'مجدول'),
    _Order('WO-2026-0150', 'مكتب خاص', 'تركيب نظام شبكة', 'الخبر - الراكة', 'عادي', 'محمد المهندس', 'غداً 09:00', 'مجدول'),
    _Order('WO-2026-0151', 'مصنع الأمل', 'فحص خط إنتاج', 'القصيم', 'منخفض', 'سعد الفني', 'غداً 11:00', 'مجدول'),
    _Order('WO-2026-0152', 'مول الأندلس', 'صيانة شاملة HVAC', 'الرياض - الأندلس', 'عادي', 'خالد الفني', '08:00', 'مكتمل'),
  ];

  static const List<_Tech> _techs = [
    _Tech('أحمد الفني', 'تكييف وتبريد', 'الرياض', 4.9, 3, 'في المسار'),
    _Tech('محمد المهندس', 'معدات صناعية', 'جدة', 4.7, 2, 'في المسار'),
    _Tech('خالد الفني', 'شبكات وATM', 'الشرقية', 4.8, 1, 'متاح'),
    _Tech('فيصل المهندس', 'أجهزة طبية', 'الرياض', 4.9, 1, 'مشغول'),
    _Tech('سعد الفني', 'معدات ميكانيكية', 'القصيم', 4.6, 0, 'متاح'),
    _Tech('عبدالله الفني', 'كهرباء منازل', 'الرياض', 4.5, 4, 'استراحة'),
  ];
}

class _Order { final String id, customer, service, location, priority, technician, scheduledTime, status;
  const _Order(this.id, this.customer, this.service, this.location, this.priority, this.technician, this.scheduledTime, this.status); }
class _Tech { final String name, specialty, city; final double rating; final int completedToday; final String availability;
  const _Tech(this.name, this.specialty, this.city, this.rating, this.completedToday, this.availability); }
