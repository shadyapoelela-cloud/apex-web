import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 124 — Transport & Logistics (TMS)
class TransportLogisticsScreen extends StatefulWidget {
  const TransportLogisticsScreen({super.key});
  @override
  State<TransportLogisticsScreen> createState() => _TransportLogisticsScreenState();
}

class _TransportLogisticsScreenState extends State<TransportLogisticsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'الشحنات'), Tab(text: 'الأسطول'), Tab(text: 'السائقون'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_shipmentsTab(), _fleetTab(), _driversTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00251A)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.local_shipping, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نظام النقل واللوجستيات TMS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('شحنات، مسارات AI، GPS Real-time، توصيل آخر ميل', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('شحنات اليوم', '${_shipments.length}', Icons.local_shipping, const Color(0xFF004D40))),
    Expanded(child: _kpi('قيد التوصيل', '${_shipments.where((s)=>s.status.contains('الطريق')).length}', Icons.route, const Color(0xFFE65100))),
    Expanded(child: _kpi('On-Time', '92%', Icons.schedule, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('الأسطول', '${_vehicles.length} مركبة', Icons.directions_car, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _shipmentsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _shipments.length, itemBuilder: (_, i) {
    final s = _shipments[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _shipmentStatus(s.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.inventory_2, color: Color(0xFF004D40))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.trackingNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${s.from} → ${s.to}', style: const TextStyle(fontSize: 11)),
            Text('العميل: ${s.customer} • ${s.weight}kg', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${s.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _shipmentStatus(s.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(s.status, style: TextStyle(color: _shipmentStatus(s.status), fontSize: 9, fontWeight: FontWeight.bold))),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.person, size: 12, color: core_theme.AC.ts),
          const SizedBox(width: 4),
          Expanded(child: Text('السائق: ${s.driver} • ${s.vehicle}', style: const TextStyle(fontSize: 10))),
          Text('ETA: ${s.eta}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ]),
    ));
  });

  Widget _fleetTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _vehicles.length, itemBuilder: (_, i) {
    final v = _vehicles[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _vehicleStatus(v.status).withValues(alpha: 0.15),
        child: Icon(_vehicleIcon(v.type), color: _vehicleStatus(v.status))),
      title: Text('${v.plate} — ${v.model}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${v.type} • سعة ${v.capacity}', style: const TextStyle(fontSize: 11)),
        Text('وقود: ${v.fuelLevel}% • عداد ${v.odometer}km', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: _vehicleStatus(v.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(v.status, style: TextStyle(color: _vehicleStatus(v.status), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _driversTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _drivers.length, itemBuilder: (_, i) {
    final d = _drivers[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: Stack(children: [
        CircleAvatar(backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.15),
          child: Text(d.name.substring(0, 1), style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold))),
        Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(
          color: _driverStatus(d.status), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
      ]),
      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رخصة: ${d.licenseType} • ${d.experience} سنة', style: const TextStyle(fontSize: 11)),
        Row(children: [
          Icon(Icons.star, color: core_theme.AC.gold, size: 12),
          Text(' ${d.rating}', style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 8),
          Text('${d.tripsToday} رحلة اليوم', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ]),
      ]),
      trailing: Text(d.status, style: TextStyle(color: _driverStatus(d.status), fontSize: 11, fontWeight: FontWeight.bold)),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📦 حجم الشحنات', '2,840 شحنة شهرياً — نمو 28% YoY', const Color(0xFF004D40)),
    _insight('⏱️ Delivery Time', 'متوسط 6.4 ساعة داخل المدينة، 18.2 ساعة بين المدن', const Color(0xFF2E7D32)),
    _insight('💰 تكلفة الكيلومتر', '1.85 ر.س/كم — توفير 12% بأتمتة المسارات', core_theme.AC.gold),
    _insight('🚗 استخدام الأسطول', '87% معدل استخدام — أعلى من الصناعة (72%)', const Color(0xFF4A148C)),
    _insight('🌿 بصمة الكربون', '182 gCO₂/km — تحسن 22% بعد اعتماد EV', const Color(0xFF1B5E20)),
    _insight('📱 تكامل SPL/TABADUL', '100% شحنات موثقة عبر المنصة الوطنية', const Color(0xFF1A237E)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _shipmentStatus(String s) {
    if (s.contains('مسلم')) return const Color(0xFF2E7D32);
    if (s.contains('الطريق')) return const Color(0xFFE65100);
    if (s.contains('التجهيز')) return core_theme.AC.gold;
    if (s.contains('ملغى')) return const Color(0xFFC62828);
    return const Color(0xFF1A237E);
  }

  Color _vehicleStatus(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('صيانة')) return const Color(0xFFE65100);
    if (s.contains('خارج الخدمة')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  IconData _vehicleIcon(String t) {
    if (t.contains('شاحنة')) return Icons.local_shipping;
    if (t.contains('فان')) return Icons.airport_shuttle;
    if (t.contains('دراجة')) return Icons.motorcycle;
    return Icons.directions_car;
  }

  Color _driverStatus(String s) {
    if (s.contains('في رحلة')) return const Color(0xFFE65100);
    if (s.contains('متاح')) return const Color(0xFF2E7D32);
    if (s.contains('استراحة')) return core_theme.AC.gold;
    return core_theme.AC.ts;
  }

  static const List<_Shipment> _shipments = [
    _Shipment('SPL-2026-0001', 'مستودع الرياض', 'جدة - الأندلس', 'شركة النخبة', 85, 420, 'أحمد العتيبي', 'شاحنة ACT-001', '18:30', 'في الطريق'),
    _Shipment('SPL-2026-0002', 'مصنع الخبر', 'الدمام', 'مصنع الأمل', 2400, 1_850, 'محمد الدوسري', 'شاحنة ACT-003', '14:15', 'مسلم'),
    _Shipment('SPL-2026-0003', 'مستودع جدة', 'الرياض', 'معرض الجزيرة', 120, 680, 'خالد الفهد', 'فان VN-005', '20:00', 'في الطريق'),
    _Shipment('SPL-2026-0004', 'مستودع الرياض', 'المدينة المنورة', 'شركة الحرم', 45, 520, 'سعد الغامدي', 'فان VN-007', 'غداً 10:00', 'قيد التجهيز'),
    _Shipment('SPL-2026-0005', 'مصنع الرياض', 'الكويت - السالمية', 'الشريك الكويتي', 8500, 12_400, 'عبدالله الشمري', 'شاحنة ACT-002', '2026-04-22 08:00', 'قيد التجهيز'),
    _Shipment('SPL-2026-0006', 'مستودع الدمام', 'أبها', 'شركة الجنوب', 320, 840, 'فيصل القحطاني', 'شاحنة ACT-004', '22:45', 'في الطريق'),
    _Shipment('SPL-2026-0007', 'مستودع الرياض', 'الخرج', 'متجر محلي', 15, 120, 'أحمد الفهد', 'دراجة MB-012', '11:30', 'مسلم'),
    _Shipment('SPL-2026-0008', 'مستودع جدة', 'الطائف', 'فندق الرفاهية', 48, 380, '-', '-', '-', 'قيد التجهيز'),
  ];

  static const List<_Vehicle> _vehicles = [
    _Vehicle('ACT-001', 'مرسيدس أكتروس 2020', 'شاحنة ثقيلة', '20 طن', 78, 245_800, 'نشط'),
    _Vehicle('ACT-002', 'فولفو FH16', 'شاحنة ثقيلة', '25 طن', 45, 185_200, 'نشط'),
    _Vehicle('ACT-003', 'سكانيا R-series', 'شاحنة ثقيلة', '18 طن', 85, 312_400, 'نشط'),
    _Vehicle('ACT-004', 'مان TGX', 'شاحنة ثقيلة', '22 طن', 62, 198_500, 'صيانة'),
    _Vehicle('VN-005', 'مرسيدس سبرنتر', 'فان متوسط', '3 طن', 92, 98_200, 'نشط'),
    _Vehicle('VN-006', 'فورد ترانزت', 'فان متوسط', '2.5 طن', 38, 124_800, 'نشط'),
    _Vehicle('VN-007', 'إيفيكو ديلي', 'فان متوسط', '3 طن', 74, 82_400, 'نشط'),
    _Vehicle('MB-012', 'هوندا CG125', 'دراجة توصيل', '40 كغ', 88, 45_200, 'نشط'),
    _Vehicle('MB-013', 'ياماها YB125', 'دراجة توصيل', '40 كغ', 0, 52_800, 'خارج الخدمة'),
  ];

  static const List<_Driver> _drivers = [
    _Driver('أحمد العتيبي', 'رخصة ثقيل', 8, 4.8, 3, 'في رحلة'),
    _Driver('محمد الدوسري', 'رخصة ثقيل', 12, 4.9, 2, 'متاح'),
    _Driver('خالد الفهد', 'رخصة عامة', 5, 4.6, 4, 'في رحلة'),
    _Driver('سعد الغامدي', 'رخصة عامة', 3, 4.4, 2, 'استراحة'),
    _Driver('عبدالله الشمري', 'رخصة ثقيل دولي', 15, 4.9, 1, 'متاح'),
    _Driver('فيصل القحطاني', 'رخصة ثقيل', 10, 4.7, 3, 'في رحلة'),
    _Driver('أحمد الفهد', 'رخصة دراجة', 2, 4.5, 8, 'في رحلة'),
  ];
}

class _Shipment { final String trackingNumber, from, to, customer; final double weight, amount; final String driver, vehicle, eta, status;
  const _Shipment(this.trackingNumber, this.from, this.to, this.customer, this.weight, this.amount, this.driver, this.vehicle, this.eta, this.status); }
class _Vehicle { final String plate, model, type, capacity; final int fuelLevel, odometer; final String status;
  const _Vehicle(this.plate, this.model, this.type, this.capacity, this.fuelLevel, this.odometer, this.status); }
class _Driver { final String name, licenseType; final int experience; final double rating; final int tripsToday; final String status;
  const _Driver(this.name, this.licenseType, this.experience, this.rating, this.tripsToday, this.status); }
