/// Wave 151 — Travel & Per Diem Management.
///
/// Concur / TravelPerk / Navan-class business travel platform.
/// Features:
///   - Trip request wizard with policy check
///   - Multi-city itinerary (flight + hotel + ground)
///   - Per-diem calculator by city
///   - Expense reconciliation at return
///   - Carbon footprint tracking
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class TravelPerDiemScreen extends StatefulWidget {
  const TravelPerDiemScreen({super.key});

  @override
  State<TravelPerDiemScreen> createState() => _TravelPerDiemScreenState();
}

class _TravelPerDiemScreenState extends State<TravelPerDiemScreen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  int _tab = 0;

  static const _trips = <_Trip>[
    _Trip(
      employee: 'أحمد محمد',
      destination: 'دبي، الإمارات',
      purpose: 'مؤتمر تقني',
      startDate: '2026-05-10',
      endDate: '2026-05-13',
      total: 12400,
      status: _TripStatus.approved,
    ),
    _Trip(
      employee: 'سارة علي',
      destination: 'لندن، بريطانيا',
      purpose: 'اجتماع عميل',
      startDate: '2026-04-25',
      endDate: '2026-04-28',
      total: 28500,
      status: _TripStatus.inProgress,
    ),
    _Trip(
      employee: 'عمر حسن',
      destination: 'القاهرة، مصر',
      purpose: 'تدريب',
      startDate: '2026-05-01',
      endDate: '2026-05-05',
      total: 8900,
      status: _TripStatus.pending,
    ),
    _Trip(
      employee: 'ليلى أحمد',
      destination: 'إسطنبول، تركيا',
      purpose: 'معرض تجاري',
      startDate: '2026-04-14',
      endDate: '2026-04-18',
      total: 15600,
      status: _TripStatus.completed,
    ),
  ];

  static const _perDiems = <_PerDiem>[
    _PerDiem(city: 'دبي', country: 'الإمارات', meals: 250, lodging: 800, transport: 150, currency: 'AED'),
    _PerDiem(city: 'لندن', country: 'بريطانيا', meals: 120, lodging: 350, transport: 60, currency: 'GBP'),
    _PerDiem(city: 'القاهرة', country: 'مصر', meals: 1200, lodging: 3500, transport: 500, currency: 'EGP'),
    _PerDiem(city: 'إسطنبول', country: 'تركيا', meals: 800, lodging: 2500, transport: 300, currency: 'TRY'),
    _PerDiem(city: 'نيويورك', country: 'الولايات المتحدة', meals: 120, lodging: 380, transport: 70, currency: 'USD'),
    _PerDiem(city: 'سنغافورة', country: 'سنغافورة', meals: 160, lodging: 420, transport: 80, currency: 'SGD'),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.flight, color: _gold),
                  const SizedBox(width: 8),
                  Text('السفر والإقامة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: _gold),
                    icon: const Icon(Icons.add_location),
                    label: Text('طلب رحلة جديدة'),
                  ),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.flight_takeoff, label: 'رحلات نشطة', value: '2', color: core_theme.AC.info)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.hourglass_empty, label: 'بانتظار الاعتماد', value: '1', color: core_theme.AC.warn)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.attach_money, label: 'إنفاق السنة', value: '65,400 ر.س', color: core_theme.AC.gold)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.eco, label: 'بصمة الكربون', value: '2.4 طن', color: core_theme.AC.ok)),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _Tab(label: 'الرحلات', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  _Tab(label: 'معدلات البدل اليومي', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  _Tab(label: 'السياسات', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _tab == 0
                  ? _buildTripsView()
                  : (_tab == 1 ? _buildPerDiemsView() : _buildPoliciesView()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final t = _trips[i];
        final (color, label, icon) = switch (t.status) {
          _TripStatus.approved => (core_theme.AC.ok, 'معتمدة', Icons.check_circle),
          _TripStatus.inProgress => (core_theme.AC.info, 'قيد التنفيذ', Icons.flight),
          _TripStatus.pending => (core_theme.AC.warn, 'بانتظار الاعتماد', Icons.schedule),
          _TripStatus.completed => (core_theme.AC.td, 'مكتملة', Icons.done_all),
        };
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: core_theme.AC.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.flight, color: _gold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.destination,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('${t.employee} · ${t.purpose}',
                          style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: core_theme.AC.ts),
                          const SizedBox(width: 4),
                          Text('${t.startDate} → ${t.endDate}',
                              style: TextStyle(fontSize: 11, color: core_theme.AC.tp)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${t.total.toStringAsFixed(0)} ر.س',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerDiemsView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _perDiems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = _perDiems[i];
        final daily = p.meals + p.lodging + p.transport;
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: core_theme.AC.gold.withValues(alpha: 0.15),
                  child: Icon(Icons.public, color: _gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.city,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('${p.country} · ${p.currency}',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    ],
                  ),
                ),
                _PD('وجبات', '${p.meals.toStringAsFixed(0)}'),
                const SizedBox(width: 12),
                _PD('إقامة', '${p.lodging.toStringAsFixed(0)}'),
                const SizedBox(width: 12),
                _PD('نقل', '${p.transport.toStringAsFixed(0)}'),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('إجمالي اليوم', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text('${daily.toStringAsFixed(0)} ${p.currency}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPoliciesView() {
    final policies = [
      ('درجة سفر', 'الاقتصادية للرحلات < 6 ساعات', Icons.airline_seat_recline_extra, core_theme.AC.info),
      ('فئة الفندق', 'حتى 4 نجوم كحد أقصى', Icons.hotel, core_theme.AC.warn),
      ('حجز مسبق', 'قبل 14 يوم من تاريخ الرحلة', Icons.schedule, core_theme.AC.purple),
      ('التأمين الصحي', 'إلزامي لكل رحلة دولية', Icons.health_and_safety, core_theme.AC.ok),
      ('مرافقون', 'عائلة على حساب الموظف فقط', Icons.family_restroom, core_theme.AC.err),
      ('استخدام الكيلومترات', 'لا تُصرف للموظف', Icons.flight, core_theme.AC.info),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: policies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final (name, rule, icon, color) = policies[i];
        return Card(
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            subtitle: Text(rule, style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_left),
          ),
        );
      },
    );
  }
}

enum _TripStatus { approved, inProgress, pending, completed }

class _Trip {
  final String employee;
  final String destination;
  final String purpose;
  final String startDate;
  final String endDate;
  final double total;
  final _TripStatus status;
  const _Trip({
    required this.employee,
    required this.destination,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    required this.total,
    required this.status,
  });
}

class _PerDiem {
  final String city;
  final String country;
  final double meals;
  final double lodging;
  final double transport;
  final String currency;
  const _PerDiem({
    required this.city,
    required this.country,
    required this.meals,
    required this.lodging,
    required this.transport,
    required this.currency,
  });
}

class _PD extends StatelessWidget {
  final String label;
  final String value;
  const _PD(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
                Text(value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? core_theme.AC.gold : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? core_theme.AC.gold : core_theme.AC.ts,
          ),
        ),
      ),
    );
  }
}
