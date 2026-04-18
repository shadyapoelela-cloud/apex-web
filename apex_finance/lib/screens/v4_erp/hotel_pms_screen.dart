import 'package:flutter/material.dart';

/// Wave 121 — Hotel PMS (Opera-class)
class HotelPmsScreen extends StatefulWidget {
  const HotelPmsScreen({super.key});
  @override
  State<HotelPmsScreen> createState() => _HotelPmsScreenState();
}

class _HotelPmsScreenState extends State<HotelPmsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'الحجوزات'), Tab(text: 'الغرف'), Tab(text: 'الضيوف'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_bookingsTab(), _roomsTab(), _guestsTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.hotel, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نظام إدارة الفنادق PMS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('حجوزات، غرف، ضيوف، إيرادات — Opera/Oracle-class', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final occupied = _rooms.where((r)=>r.status.contains('مشغول')).length;
    final revenue = _bookings.fold<double>(0, (s, b) => s + b.totalAmount);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('الغرف', '${_rooms.length}', Icons.bed, const Color(0xFF4A148C))),
      Expanded(child: _kpi('الإشغال', '${((occupied/_rooms.length)*100).toStringAsFixed(0)}%', Icons.people, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('إيراد الشهر', '${(revenue/1000).toStringAsFixed(0)}K', Icons.attach_money, const Color(0xFFD4AF37))),
      Expanded(child: _kpi('ADR', '485 ر.س', Icons.trending_up, const Color(0xFF1A237E))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _bookingsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _bookings.length, itemBuilder: (_, i) {
    final b = _bookings[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _bookingStatus(b.status).withValues(alpha: 0.15), child: Icon(Icons.event, color: _bookingStatus(b.status))),
      title: Text('${b.id} — ${b.guest}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('غرفة ${b.room} • ${b.roomType}', style: const TextStyle(fontSize: 11)),
        Text('${b.checkIn} → ${b.checkOut} (${b.nights} ليلة)', style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${b.totalAmount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _bookingStatus(b.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(b.status, style: TextStyle(color: _bookingStatus(b.status), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _roomsTab() => Padding(padding: const EdgeInsets.all(12),
    child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.9, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _rooms.length, itemBuilder: (_, i) {
      final r = _rooms[i]; final color = _roomColor(r.status);
      return Card(color: color.withValues(alpha: 0.1), child: Padding(padding: const EdgeInsets.all(8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bed, color: color, size: 28),
          Text('#${r.number}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Text(r.type, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(r.status, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold))),
        ]),
      ));
    }),
  );

  Widget _guestsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _guests.length, itemBuilder: (_, i) {
    final g = _guests[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
        child: Text(g.tier, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold))),
      title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${g.country} • ${g.stays} إقامة', style: const TextStyle(fontSize: 11)),
        Text('آخر إقامة: ${g.lastStay}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${(g.totalSpent/1000).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        const Icon(Icons.loyalty, color: Color(0xFFD4AF37), size: 16),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏨 معدل الإشغال', '78% — أعلى من متوسط السوق (68%)', const Color(0xFF2E7D32)),
    _insight('💰 RevPAR', '378 ر.س (ADR × Occupancy) — نمو 15% YoY', const Color(0xFFD4AF37)),
    _insight('🌍 أسواق المصدر', 'السعودية 45% • الخليج 28% • دولي 27%', const Color(0xFF1A237E)),
    _insight('⭐ تقييمات الضيوف', '4.6/5 على Booking.com • 4.7 على TripAdvisor', const Color(0xFF4A148C)),
    _insight('📅 الحجوزات المباشرة', '38% من الموقع مباشرة (يوفر عمولة OTA)', const Color(0xFF2E7D32)),
    _insight('🎯 Upsell الغرف', '22% من الضيوف رقّوا الغرفة عند الوصول', const Color(0xFFE65100)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _bookingStatus(String s) {
    if (s.contains('وصل')) return const Color(0xFF2E7D32);
    if (s.contains('مغادر')) return const Color(0xFF1A237E);
    if (s.contains('محجوز')) return const Color(0xFFD4AF37);
    if (s.contains('ملغى')) return const Color(0xFFC62828);
    return Colors.black54;
  }

  Color _roomColor(String s) {
    if (s.contains('مشغول')) return const Color(0xFFC62828);
    if (s.contains('متاح')) return const Color(0xFF2E7D32);
    if (s.contains('تنظيف')) return const Color(0xFFE65100);
    if (s.contains('صيانة')) return const Color(0xFF1A237E);
    return Colors.black54;
  }

  static const List<_Booking> _bookings = [
    _Booking('RSV-45821', 'أحمد المطيري', '301', 'جناح', '2026-04-18', '2026-04-22', 4, 6_400, 'وصل'),
    _Booking('RSV-45822', 'فاطمة الزهراني', '205', 'ديلوكس', '2026-04-19', '2026-04-21', 2, 1_680, 'وصل'),
    _Booking('RSV-45823', 'شركة النخبة', '402', 'رئاسي', '2026-04-25', '2026-04-27', 2, 9_800, 'محجوز'),
    _Booking('RSV-45824', 'Mark Anderson', '108', 'قياسي', '2026-04-20', '2026-04-25', 5, 2_400, 'محجوز'),
    _Booking('RSV-45825', 'سارة العتيبي', '312', 'جناح', '2026-04-15', '2026-04-18', 3, 4_800, 'مغادر'),
    _Booking('RSV-45826', 'محمد القحطاني', '201', 'ديلوكس', '2026-04-22', '2026-04-24', 2, 1_680, 'ملغى'),
  ];

  static const List<_Room> _rooms = [
    _Room('101', 'قياسي', 'متاح'), _Room('102', 'قياسي', 'مشغول'), _Room('103', 'قياسي', 'تنظيف'), _Room('104', 'قياسي', 'متاح'),
    _Room('201', 'ديلوكس', 'مشغول'), _Room('202', 'ديلوكس', 'متاح'), _Room('203', 'ديلوكس', 'مشغول'), _Room('204', 'ديلوكس', 'صيانة'),
    _Room('301', 'جناح', 'مشغول'), _Room('302', 'جناح', 'متاح'), _Room('303', 'جناح', 'مشغول'), _Room('304', 'جناح', 'مشغول'),
    _Room('401', 'رئاسي', 'متاح'), _Room('402', 'رئاسي', 'محجوز'), _Room('403', 'رئاسي', 'متاح'), _Room('404', 'رئاسي', 'مشغول'),
  ];

  static const List<_Guest> _guests = [
    _Guest('أحمد المطيري', 'السعودية', 'VIP', 28, 145_800, '2026-04-18'),
    _Guest('فاطمة الزهراني', 'السعودية', 'ذهبي', 14, 68_200, '2026-04-19'),
    _Guest('Mark Anderson', 'أمريكا', 'فضي', 6, 24_500, '2024-11-20'),
    _Guest('شركة النخبة', 'السعودية', 'VIP', 48, 285_600, '2026-03-15'),
    _Guest('نورة الشمري', 'السعودية', 'فضي', 8, 18_400, '2026-02-28'),
  ];
}

class _Booking { final String id, guest, room, roomType, checkIn, checkOut; final int nights; final double totalAmount; final String status;
  const _Booking(this.id, this.guest, this.room, this.roomType, this.checkIn, this.checkOut, this.nights, this.totalAmount, this.status); }
class _Room { final String number, type, status;
  const _Room(this.number, this.type, this.status); }
class _Guest { final String name, country, tier; final int stays; final double totalSpent; final String lastStay;
  const _Guest(this.name, this.country, this.tier, this.stays, this.totalSpent, this.lastStay); }
