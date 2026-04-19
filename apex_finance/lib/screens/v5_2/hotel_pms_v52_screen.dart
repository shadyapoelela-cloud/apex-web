/// V5.2 — Hotel PMS using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class HotelPmsV52Screen extends StatefulWidget {
  const HotelPmsV52Screen({super.key});

  @override
  State<HotelPmsV52Screen> createState() => _HotelPmsV52ScreenState();
}

class _HotelPmsV52ScreenState extends State<HotelPmsV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _bookings = <_Booking>[
    _Booking('R-2026-142', 'أحمد الراجحي', '2026-04-18', '2026-04-22', 'Junior Suite 301', 4800, 4, _S.checkedIn, 'VIP Gold'),
    _Booking('R-2026-141', 'Sarah Williams', '2026-04-19', '2026-04-21', 'Deluxe 205', 2800, 2, _S.checkedIn, 'Silver'),
    _Booking('R-2026-140', 'سعود العنزي', '2026-04-20', '2026-04-25', 'Presidential 501', 18000, 1, _S.reserved, 'VIP Platinum'),
    _Booking('R-2026-139', 'Marco Rossi', '2026-04-22', '2026-04-26', 'Deluxe 208', 5200, 2, _S.reserved, 'Gold'),
    _Booking('R-2026-138', 'نورة الدوسري', '2026-04-17', '2026-04-19', 'Standard 102', 1800, 1, _S.checkedOut, 'Bronze'),
    _Booking('R-2026-137', 'James Chen', '2026-04-23', '2026-04-24', 'Deluxe 210', 1400, 1, _S.reserved, 'Silver'),
    _Booking('R-2026-136', 'فاطمة السعيد', '2026-04-21', '2026-04-28', 'Family Suite 405', 9800, 4, _S.reserved, 'Gold'),
    _Booking('R-2026-135', 'Ahmed Hossam', '2026-04-16', '2026-04-17', 'Standard 108', 900, 1, _S.checkedOut, 'Bronze'),
    _Booking('R-2026-134', 'د. محمد القحطاني', '2026-04-19', '2026-04-23', 'Junior Suite 303', 5600, 2, _S.checkedIn, 'VIP Gold'),
    _Booking('R-2026-133', 'Laura Smith', '2026-04-24', '2026-04-27', 'Deluxe 212', 4200, 2, _S.reserved, 'Silver'),
    _Booking('R-2026-132', 'خالد الشمراني', '2026-04-20', '2026-04-22', 'Standard 115', 1800, 2, _S.noShow, 'Bronze'),
    _Booking('R-2026-131', 'Pedro Garcia', '2026-04-15', '2026-04-18', 'Deluxe 206', 4200, 2, _S.checkedOut, 'Silver'),
  ];

  @override
  Widget build(BuildContext context) {
    final totalRev = _bookings.fold<double>(0, (s, b) => s + b.amount);
    final occupancy = ((_bookings.where((b) => b.status == _S.checkedIn || b.status == _S.reserved).length / 60) * 100).toInt();
    return MultiViewTemplate(
      titleAr: 'إدارة الفندق PMS',
      subtitleAr: 'الحجوزات · الإشغال $occupancy% · الإيراد ${(totalRev / 1e3).toStringAsFixed(0)}K ر.س',
      enabledViews: const {ViewMode.kanban, ViewMode.list, ViewMode.calendar, ViewMode.chart},
      initialView: ViewMode.kanban,
      savedViews: const [
        SavedView(id: 'today', labelAr: 'الوصول اليوم', icon: Icons.login, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'leaving', labelAr: 'المغادرة اليوم', icon: Icons.logout, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'vip', labelAr: 'VIP فقط', icon: Icons.star, defaultViewMode: ViewMode.kanban),
        SavedView(id: 'noshow', labelAr: 'No Show', icon: Icons.warning, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'reserved', labelAr: 'محجوز', color: Colors.blue, count: _count(_S.reserved), active: _filter == 'reserved'),
        FilterChipDef(id: 'checkedIn', labelAr: 'داخل', color: Colors.green, count: _count(_S.checkedIn), active: _filter == 'checkedIn'),
        FilterChipDef(id: 'checkedOut', labelAr: 'مغادر', color: Colors.grey, count: _count(_S.checkedOut), active: _filter == 'checkedOut'),
        FilterChipDef(id: 'noShow', labelAr: 'No Show', color: Colors.red, count: _count(_S.noShow), active: _filter == 'noShow'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'حجز جديد',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      calendarBuilder: (_) => _calendar(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _count(_S s) => _bookings.where((b) => b.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _bookings : _bookings.where((b) => b.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final b = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 4, height: 56, color: b.status.color),
            const SizedBox(width: 12),
            CircleAvatar(radius: 16, backgroundColor: _vipColor(b.tier).withOpacity(0.15), child: Icon(Icons.person, color: _vipColor(b.tier), size: 16)),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(b.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _vipColor(b.tier).withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(b.tier, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _vipColor(b.tier)))),
              ]),
              Text(b.guest, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(b.room, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الوصول', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Text(b.checkIn, style: const TextStyle(fontSize: 12)),
              Text('المغادرة: ${b.checkOut}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ]),
            const SizedBox(width: 20),
            Column(children: [
              const Icon(Icons.people, size: 14, color: Colors.black54),
              Text('${b.guests}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(width: 20),
            Text('${b.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: b.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(b.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.status.color))),
          ])),
        );
      },
    );
  }

  Widget _kanban() {
    final statuses = [_S.reserved, _S.checkedIn, _S.checkedOut, _S.noShow];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: statuses.map((s) {
        final items = _bookings.where((b) => b.status == s).toList();
        final total = items.fold<double>(0, (sum, b) => sum + b.amount);
        return Container(
          width: 300,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Icon(s.icon, size: 16, color: s.color),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color)),
                Text('${(total / 1000).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
            ])),
            ...items.map((b) => Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(b.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                  const Spacer(),
                  if (b.tier.startsWith('VIP')) const Icon(Icons.star, color: _gold, size: 12),
                ]),
                Text(b.guest, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(b.room, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 10, color: Colors.black54),
                  const SizedBox(width: 2),
                  Text('${b.checkIn.substring(5)} → ${b.checkOut.substring(5)}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  const Spacer(),
                  Text('${b.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _gold)),
                ]),
              ]),
            )),
            const SizedBox(height: 8),
          ]),
        );
      }).toList()),
    );
  }

  Widget _calendar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('شاشة الإشغال — أبريل 2026', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(10), color: _navy, child: Row(children: [
                const SizedBox(width: 100, child: Text('الغرفة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                for (int d = 15; d <= 25; d++) Expanded(child: Text('$d', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
              ])),
              ..._roomsOccupancy().map((row) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                    child: Row(children: [
                      SizedBox(width: 100, child: Text(row.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      for (int d = 15; d <= 25; d++)
                        Expanded(child: Container(
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: row.$2[d - 15], borderRadius: BorderRadius.circular(3)),
                        )),
                    ]),
                  )),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendDot(Colors.green, 'مشغولة'),
          const SizedBox(width: 20),
          _legendDot(Colors.blue, 'محجوزة'),
          const SizedBox(width: 20),
          _legendDot(Colors.orange, 'تنظيف'),
          const SizedBox(width: 20),
          _legendDot(Colors.grey.shade300, 'شاغرة'),
        ]),
      ]),
    );
  }

  List<(String, List<Color>)> _roomsOccupancy() {
    final occ = Colors.green;
    final res = Colors.blue;
    final clean = Colors.orange;
    final empty = Colors.grey.shade300;
    return [
      ('Junior Suite 301', [occ, occ, occ, occ, occ, clean, empty, empty, empty, empty, empty]),
      ('Junior Suite 303', [empty, empty, empty, empty, occ, occ, occ, occ, occ, empty, empty]),
      ('Presidential 501', [empty, empty, empty, empty, empty, res, res, res, res, res, res]),
      ('Deluxe 205', [empty, empty, empty, empty, occ, occ, clean, empty, empty, empty, empty]),
      ('Deluxe 208', [empty, empty, empty, empty, empty, empty, empty, res, res, res, res]),
      ('Deluxe 210', [empty, empty, empty, empty, empty, empty, empty, empty, res, clean, empty]),
      ('Family Suite 405', [empty, empty, empty, empty, empty, empty, res, res, res, res, res]),
      ('Standard 102', [empty, empty, occ, occ, clean, empty, empty, empty, empty, empty, empty]),
      ('Standard 108', [occ, occ, clean, empty, empty, empty, empty, empty, empty, empty, empty]),
      ('Standard 115', [empty, empty, empty, empty, empty, res, res, empty, empty, empty, empty]),
    ];
  }

  Widget _legendDot(Color c, String label) => Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 11))]);

  Widget _chart() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _chartCard('ADR', '1,240', 'ر.س', Colors.green, 'متوسط السعر للغرفة')),
          const SizedBox(width: 10),
          Expanded(child: _chartCard('Occupancy', '72', '%', _gold, 'نسبة الإشغال')),
          const SizedBox(width: 10),
          Expanded(child: _chartCard('RevPAR', '892', 'ر.س', _navy, 'الإيراد/غرفة متاحة')),
          const SizedBox(width: 10),
          Expanded(child: _chartCard('GOP', '58', '%', Colors.blue, 'هامش الربح الإجمالي')),
        ]),
        const SizedBox(height: 24),
        const Text('الإيرادات الأسبوعية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        ...[
          ('الأسبوع 15', 64000),
          ('الأسبوع 16', 72000),
          ('الأسبوع 17', 84000),
          ('الأسبوع 18', 92000),
        ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
              SizedBox(width: 100, child: Text(w.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: w.$2 / 100000, minHeight: 20, backgroundColor: Colors.grey.shade100, color: _gold))),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: Text('${(w.$2 / 1000).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold), textAlign: TextAlign.end)),
            ]))),
      ]),
    );
  }

  Widget _chartCard(String label, String value, String unit, Color color, String sub) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color.withOpacity(0.9))),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ]),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
      );

  Color _vipColor(String tier) {
    if (tier.startsWith('VIP Platinum')) return Colors.purple;
    if (tier.startsWith('VIP Gold')) return _gold;
    if (tier == 'Gold') return Colors.amber;
    if (tier == 'Silver') return Colors.blueGrey;
    return Colors.brown;
  }
}

enum _S { reserved, checkedIn, checkedOut, noShow }

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.reserved => 'محجوز',
        _S.checkedIn => 'داخل الفندق',
        _S.checkedOut => 'غادر',
        _S.noShow => 'لم يحضر',
      };
  Color get color => switch (this) {
        _S.reserved => Colors.blue,
        _S.checkedIn => Colors.green,
        _S.checkedOut => Colors.grey,
        _S.noShow => Colors.red,
      };
  IconData get icon => switch (this) {
        _S.reserved => Icons.event,
        _S.checkedIn => Icons.login,
        _S.checkedOut => Icons.logout,
        _S.noShow => Icons.person_off,
      };
}

class _Booking {
  final String id, guest, checkIn, checkOut, room, tier;
  final double amount;
  final int guests;
  final _S status;
  const _Booking(this.id, this.guest, this.checkIn, this.checkOut, this.room, this.amount, this.guests, this.status, this.tier);
}
