/// APEX Wave 96 — Fleet Management.
/// Route: /app/erp/operations/fleet
///
/// Vehicles, drivers, maintenance, fuel tracking, GPS.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key});
  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _vehicles = [
    _Vehicle('FL-001', 'لكزس LX 600 2024', 'SUV', 'خالد العتيبي', 'active', 18500, 45000, '2026-05-15', '2026-08-30', 380000, core_theme.AC.info),
    _Vehicle('FL-002', 'تويوتا هايلكس 2023', 'Pickup', 'محمد القحطاني', 'active', 62000, 120000, '2026-04-28', '2026-07-10', 145000, core_theme.AC.warn),
    _Vehicle('FL-003', 'مرسيدس G-Class 2025', 'SUV', 'الرئيس التنفيذي', 'active', 4200, 10000, '2026-09-01', '2027-01-15', 720000, core_theme.AC.err),
    _Vehicle('FL-004', 'إيسوزو شاحنة 2022', 'Truck', 'فهد الشمري', 'maintenance', 125000, 45000, '2026-05-08', '2026-06-20', 195000, core_theme.AC.warn),
    _Vehicle('FL-005', 'نيسان ألتيما 2024', 'Sedan', 'سارة الدوسري', 'active', 28500, 48000, '2026-07-22', '2026-09-30', 95000, core_theme.AC.ok),
    _Vehicle('FL-006', 'تويوتا كامري 2023', 'Sedan', 'نورة الغامدي', 'active', 42000, 56000, '2026-06-15', '2026-08-22', 92000, core_theme.AC.info),
    _Vehicle('FL-007', 'إيسوزو ميني فان 2022', 'Van', 'سائق توصيل', 'active', 98000, 95000, '2026-05-02', '2026-07-18', 125000, core_theme.AC.purple),
    _Vehicle('FL-008', 'هيونداي إلنترا 2021', 'Sedan', 'لينا البكري', 'active', 68000, 72000, '2026-05-20', '2026-08-05', 68000, core_theme.AC.err),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car, size: 16), text: 'المركبات'),
            Tab(icon: Icon(Icons.build, size: 16), text: 'الصيانة'),
            Tab(icon: Icon(Icons.local_gas_station, size: 16), text: 'الوقود والمصاريف'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildVehiclesTab(),
              _buildMaintenanceTab(),
              _buildFuelTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة الأسطول',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('8 مركبات · استهلاك · صيانة · تراخيص · تأمينات · GPS',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final active = _vehicles.where((v) => v.status == 'active').length;
    final inMaint = _vehicles.where((v) => v.status == 'maintenance').length;
    final totalValue = _vehicles.fold(0.0, (s, v) => s + v.value);
    final upcomingRenewals = _vehicles.where((v) {
      final regDate = DateTime.parse(v.registrationExpiry);
      return regDate.difference(DateTime(2026, 4, 19)).inDays <= 60;
    }).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('إجمالي الأسطول', '${_vehicles.length}', core_theme.AC.info, Icons.directions_car),
          _kpi('نشطة', '$active', core_theme.AC.ok, Icons.check_circle),
          _kpi('قيد الصيانة', '$inMaint', core_theme.AC.warn, Icons.build),
          _kpi('تراخيص قرب انتهاء', '$upcomingRenewals', core_theme.AC.err, Icons.warning),
          _kpi('قيمة الأسطول', '${_fmtM(totalValue)} ر.س', core_theme.AC.gold, Icons.attach_money),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _vehicles.length,
      itemBuilder: (ctx, i) {
        final v = _vehicles[i];
        final regDate = DateTime.parse(v.registrationExpiry);
        final daysLeft = regDate.difference(DateTime(2026, 4, 19)).inDays;
        final statusColor = _statusColor(v.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: v.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_typeIcon(v.type), color: v.color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(v.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                          child: Text(_statusLabel(v.status),
                              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    Text(v.model, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Icon(Icons.person, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text(v.driver, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, size: 12, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text('${_fmt(v.km.toDouble())} كم',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.local_gas_station, size: 12, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text('${v.fuelMonthly} ل/شهر', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    Text('قيمة: ${_fmt(v.value)} ر.س',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.gold, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 11, color: daysLeft < 60 ? core_theme.AC.err : core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text('استمارة: ${v.registrationExpiry}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: daysLeft < 60 ? core_theme.AC.err : core_theme.AC.ts,
                                  fontFamily: 'monospace',
                                  fontWeight: daysLeft < 60 ? FontWeight.w700 : FontWeight.w400)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.shield, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text('تأمين: ${v.insuranceExpiry}',
                              style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                        ),
                      ],
                    ),
                    if (daysLeft < 60 && daysLeft > 0)
                      Text('⚠️ تجديد خلال $daysLeft يوم',
                          style: TextStyle(fontSize: 10, color: core_theme.AC.err, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceTab() {
    final records = const [
      _MaintRecord('MNT-2026-0042', 'FL-004', 'صيانة كبرى 120K كم', 'قيد التنفيذ', '2026-04-18', 8500, 'التوكيلات العالمية'),
      _MaintRecord('MNT-2026-0041', 'FL-002', 'تغيير زيت + فلاتر', 'مجدول', '2026-04-28', 850, 'مركز تويوتا'),
      _MaintRecord('MNT-2026-0040', 'FL-007', 'فحص سنوي دوري', 'مجدول', '2026-05-02', 650, 'المعرض المعتمد'),
      _MaintRecord('MNT-2026-0039', 'FL-001', 'تغيير إطارات', 'مكتمل', '2026-04-08', 4200, 'محطة الخدمة'),
      _MaintRecord('MNT-2026-0038', 'FL-003', 'صيانة دورية 10K', 'مكتمل', '2026-03-28', 2800, 'مرسيدس الجميح'),
      _MaintRecord('MNT-2026-0037', 'FL-006', 'فحص كامل', 'مكتمل', '2026-03-15', 450, 'مركز تويوتا'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: core_theme.AC.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الصيانة الدورية مجدولة تلقائياً حسب كل (5,000) كم أو (6) أشهر — أيهما أقرب.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final r in records) _maintRow(r),
      ],
    );
  }

  Widget _maintRow(_MaintRecord r) {
    final statusColor = r.status == 'مكتمل' ? core_theme.AC.ok : r.status == 'قيد التنفيذ' ? core_theme.AC.warn : core_theme.AC.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.build, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: core_theme.AC.info.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                      child: Text(r.vehicleId,
                          style: TextStyle(fontSize: 10, color: core_theme.AC.info, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                Text(r.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(r.provider, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التاريخ', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text(r.date, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_fmt(r.cost.toDouble())} ر.س',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                  child: Text(r.status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelTab() {
    final monthly = const [
      _FuelMonth('أكتوبر 2025', 14250, 1280, 92),
      _FuelMonth('نوفمبر 2025', 15800, 1420, 94),
      _FuelMonth('ديسمبر 2025', 18200, 1620, 98),
      _FuelMonth('يناير 2026', 16500, 1480, 91),
      _FuelMonth('فبراير 2026', 14800, 1320, 88),
      _FuelMonth('مارس 2026', 17200, 1540, 95),
      _FuelMonth('أبريل 2026', 18500, 1650, 102),
    ];
    final maxCost = monthly.fold(0.0, (m, f) => f.cost > m ? f.cost.toDouble() : m);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            _fuelStat('استهلاك أبريل', '1,650 لتر', '+7% MoM', core_theme.AC.warn, Icons.local_gas_station),
            _fuelStat('تكلفة أبريل', '18,500 ر.س', '+7% MoM', core_theme.AC.gold, Icons.attach_money),
            _fuelStat('متوسط كم/لتر', '14.2', 'تحسّن +0.3', core_theme.AC.ok, Icons.speed),
            _fuelStat('إجمالي YTD', '6,490 لتر', '73K ر.س', core_theme.AC.info, Icons.timeline),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('استهلاك الوقود الشهري', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final m in monthly)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(_fmt(m.cost.toDouble()),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                              const SizedBox(height: 2),
                              Container(
                                height: (m.cost / maxCost) * 130,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [core_theme.AC.gold, Color(0xFFE6C200)],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(m.month.split(' ')[0], style: const TextStyle(fontSize: 10)),
                              Text('${m.liters}L', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fuelStat(String label, String value, String note, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(note, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return core_theme.AC.ok;
      case 'maintenance':
        return core_theme.AC.warn;
      case 'idle':
        return core_theme.AC.td;
      case 'retired':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'نشطة';
      case 'maintenance':
        return 'صيانة';
      case 'idle':
        return 'خاملة';
      case 'retired':
        return 'مستبعدة';
      default:
        return s;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'SUV':
        return Icons.directions_car;
      case 'Sedan':
        return Icons.directions_car;
      case 'Pickup':
        return Icons.directions_car;
      case 'Truck':
        return Icons.local_shipping;
      case 'Van':
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Vehicle {
  final String id;
  final String model;
  final String type;
  final String driver;
  final String status;
  final int km;
  final int fuelMonthly;
  final String registrationExpiry;
  final String insuranceExpiry;
  final double value;
  final Color color;
  const _Vehicle(this.id, this.model, this.type, this.driver, this.status, this.km, this.fuelMonthly, this.registrationExpiry, this.insuranceExpiry, this.value, this.color);
}

class _MaintRecord {
  final String id;
  final String vehicleId;
  final String description;
  final String status;
  final String date;
  final int cost;
  final String provider;
  const _MaintRecord(this.id, this.vehicleId, this.description, this.status, this.date, this.cost, this.provider);
}

class _FuelMonth {
  final String month;
  final int cost;
  final int liters;
  final int fills;
  const _FuelMonth(this.month, this.cost, this.liters, this.fills);
}
