import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 108 — Asset Tracking / Barcode & RFID
class AssetTrackingScreen extends StatefulWidget {
  const AssetTrackingScreen({super.key});
  @override
  State<AssetTrackingScreen> createState() => _AssetTrackingScreenState();
}

class _AssetTrackingScreenState extends State<AssetTrackingScreen> with SingleTickerProviderStateMixin {
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
            controller: _tc, labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
            indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
            tabs: const [
              Tab(text: 'الأصول'), Tab(text: 'المسح والتتبع'), Tab(text: 'الصيانة'), Tab(text: 'التحليلات'),
            ],
          )),
          Expanded(child: TabBarView(controller: _tc, children: [
            _assetsTab(), _scansTab(), _maintTab(), _analyticsTab(),
          ])),
        ])),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تتبع الأصول — Barcode & RFID', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('تتبع لحظي لدورة حياة الأصول باستخدام الباركود وRFID', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.nfc, color: core_theme.AC.gold, size: 16), SizedBox(width: 4),
          Text('RFID Enabled', style: TextStyle(color: Colors.white, fontSize: 12)),
        ])),
    ]),
  );

  Widget _kpis() {
    final total = _assets.length;
    final active = _assets.where((a)=>a.status.contains('نشط')).length;
    final maint = _assets.where((a)=>a.status.contains('صيانة')).length;
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('إجمالي الأصول', '$total', Icons.devices, const Color(0xFF1A237E))),
      Expanded(child: _kpi('نشط', '$active', Icons.check_circle, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('قيد الصيانة', '$maint', Icons.build, const Color(0xFFE65100))),
      Expanded(child: _kpi('مسح اليوم', '148', Icons.qr_code_2, core_theme.AC.gold)),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 24), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _assetsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _assets.length, itemBuilder: (_, i) {
    final a = _assets[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(_assetIcon(a.category), color: const Color(0xFF4A148C))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('${a.barcode} • ${a.category}', style: const TextStyle(fontSize: 12)),
          Text('📍 ${a.location}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${a.value.toStringAsFixed(0)} ر.س', style: TextStyle(fontWeight: FontWeight.bold, color: core_theme.AC.gold)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(a.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(a.status, style: TextStyle(color: _statusColor(a.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
      ]),
    ));
  });

  Widget _scansTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _scans.length, itemBuilder: (_, i) {
    final s = _scans[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        child: Icon(s.type.contains('RFID') ? Icons.nfc : Icons.qr_code, color: const Color(0xFF2E7D32))),
      title: Text(s.assetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s.action} • ${s.type}', style: const TextStyle(fontSize: 12)),
        Text('بواسطة: ${s.user} • ${s.location}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
      trailing: Text(s.time, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
    ));
  });

  Widget _maintTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _maint.length, itemBuilder: (_, i) {
    final m = _maint[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFFE65100).withValues(alpha: 0.1), child: const Icon(Icons.build_circle, color: Color(0xFFE65100))),
      title: Text(m.asset, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.workOrder, style: const TextStyle(fontSize: 12)),
        Text('الفني: ${m.technician} • ${m.type}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(m.scheduledDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Text(m.status, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📦 معدل الاستخدام', '87% من الأصول في حالة نشطة', const Color(0xFF2E7D32)),
    _insight('🔧 الصيانة الوقائية', '94% تنفيذ — توفير 1.2M ر.س سنوياً', const Color(0xFF1A237E)),
    _insight('📍 دقة الموقع', '99.2% دقة تتبع مع RFID', const Color(0xFF4A148C)),
    _insight('⚠️ تنبيه', '5 أصول لم تُمسح منذ 90 يوم — قد تكون مفقودة', const Color(0xFFC62828)),
    _insight('💰 قيمة المحفظة', '18.7M ر.س إجمالي قيمة الأصول المتتبعة', core_theme.AC.gold),
    _insight('📊 عمر الأصول', 'متوسط 3.4 سنة — 22% تحتاج تجديد', const Color(0xFFE65100)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  IconData _assetIcon(String c) {
    if (c.contains('كمبيوتر')) return Icons.computer;
    if (c.contains('آلة')) return Icons.precision_manufacturing;
    if (c.contains('مركبة')) return Icons.directions_car;
    if (c.contains('أثاث')) return Icons.chair;
    if (c.contains('أدوات')) return Icons.handyman;
    return Icons.devices;
  }

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('صيانة')) return const Color(0xFFE65100);
    if (s.contains('مفقود')) return const Color(0xFFC62828);
    if (s.contains('مخزن')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  static const List<_Asset> _assets = [
    _Asset('AST-001', 'خادم Dell PowerEdge R750', 'BAR-448291', 'كمبيوتر وخوادم', 'غرفة السيرفرات — الرياض', 85_000, 'نشط'),
    _Asset('AST-002', 'طابعة HP LaserJet Pro', 'BAR-448292', 'كمبيوتر وخوادم', 'مكتب المحاسبة', 4_500, 'نشط'),
    _Asset('AST-003', 'آلة تعبئة Bosch', 'BAR-448293', 'آلة إنتاج', 'مصنع الرياض', 245_000, 'قيد الصيانة'),
    _Asset('AST-004', 'شاحنة مرسيدس أكتروس', 'BAR-448294', 'مركبة', 'أسطول جدة', 580_000, 'نشط'),
    _Asset('AST-005', 'مكاتب تنفيذية — 12 قطعة', 'BAR-448295', 'أثاث', 'الطابق التنفيذي', 38_000, 'نشط'),
    _Asset('AST-006', 'رافعة شوكية Toyota', 'BAR-448296', 'أدوات مستودع', 'مستودع الدمام', 95_000, 'نشط'),
    _Asset('AST-007', 'كاميرا فحص جودة', 'BAR-448297', 'أدوات', 'خط الإنتاج 3', 22_000, 'قيد الصيانة'),
    _Asset('AST-008', 'لابتوبات MacBook Pro — 8', 'BAR-448298', 'كمبيوتر وخوادم', 'قسم التصميم', 120_000, 'نشط'),
    _Asset('AST-009', 'نظام HVAC مركزي', 'BAR-448299', 'آلة إنتاج', 'المقر الرئيسي', 380_000, 'نشط'),
    _Asset('AST-010', 'معدات IT قديمة', 'BAR-448300', 'كمبيوتر وخوادم', 'مخزن الأرشيف', 0, 'مفقود'),
  ];

  static const List<_Scan> _scans = [
    _Scan('خادم Dell PowerEdge R750', 'مسح دخول', 'RFID', 'أحمد الغامدي', 'غرفة السيرفرات', '10:32'),
    _Scan('شاحنة مرسيدس أكتروس', 'خروج من المرآب', 'RFID', 'محمد العتيبي', 'بوابة جدة', '09:45'),
    _Scan('آلة تعبئة Bosch', 'بدء صيانة', 'Barcode', 'فني صيانة', 'مصنع الرياض', '09:15'),
    _Scan('طابعة HP LaserJet Pro', 'نقل موقع', 'Barcode', 'نورة الشمري', 'مكتب المحاسبة', '08:50'),
    _Scan('رافعة شوكية Toyota', 'فحص يومي', 'RFID', 'سعد الدوسري', 'مستودع الدمام', '08:30'),
    _Scan('لابتوبات MacBook Pro', 'تسليم موظف جديد', 'Barcode', 'مدير IT', 'قسم التصميم', '08:15'),
  ];

  static const List<_Maintenance> _maint = [
    _Maintenance('آلة تعبئة Bosch', 'WO-2026-0045', 'أحمد الميكانيكي', 'صيانة وقائية', '2026-04-20', 'قيد التنفيذ'),
    _Maintenance('كاميرا فحص جودة', 'WO-2026-0046', 'فريق IT', 'إصلاح', '2026-04-19', 'قيد التنفيذ'),
    _Maintenance('شاحنة مرسيدس أكتروس', 'WO-2026-0047', 'ورشة الأسطول', 'تغيير زيت', '2026-04-25', 'مجدول'),
    _Maintenance('نظام HVAC مركزي', 'WO-2026-0048', 'شركة الصيانة الخارجية', 'صيانة ربعية', '2026-05-01', 'مجدول'),
  ];
}

class _Asset { final String id, name, barcode, category, location; final double value; final String status;
  const _Asset(this.id, this.name, this.barcode, this.category, this.location, this.value, this.status); }
class _Scan { final String assetName, action, type, user, location, time;
  const _Scan(this.assetName, this.action, this.type, this.user, this.location, this.time); }
class _Maintenance { final String asset, workOrder, technician, type, scheduledDate, status;
  const _Maintenance(this.asset, this.workOrder, this.technician, this.type, this.scheduledDate, this.status); }
