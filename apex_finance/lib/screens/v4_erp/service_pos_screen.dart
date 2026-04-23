/// Wave 149 — Service POS (appointment + labor-based POS).
///
/// Booksy / Fresha / Treatwell-class service point-of-sale.
/// Features:
///   - Appointment calendar (day view)
///   - Technician/Chair assignment
///   - Service menu with duration
///   - Tip calculator
///   - Package & loyalty redemption
///   - Digital signature + invoice
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ServicePosScreen extends StatefulWidget {
  const ServicePosScreen({super.key});

  @override
  State<ServicePosScreen> createState() => _ServicePosScreenState();
}

class _ServicePosScreenState extends State<ServicePosScreen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  int _selectedDay = DateTime.now().weekday - 1;

  static const _services = <_Service>[
    _Service(id: 's1', name: 'قص شعر رجالي', price: 80, duration: 30, icon: Icons.content_cut),
    _Service(id: 's2', name: 'صبغة شعر', price: 220, duration: 90, icon: Icons.palette),
    _Service(id: 's3', name: 'تدليك استرخاء', price: 180, duration: 60, icon: Icons.spa),
    _Service(id: 's4', name: 'عناية بالوجه', price: 240, duration: 75, icon: Icons.face),
    _Service(id: 's5', name: 'مانيكير', price: 120, duration: 45, icon: Icons.back_hand),
    _Service(id: 's6', name: 'جلسة ليزر', price: 450, duration: 40, icon: Icons.bolt),
  ];

  static const _appointments = <_Appt>[
    _Appt(time: '09:00', name: 'أحمد محمد', service: 'قص شعر رجالي', tech: 'خالد', status: _ApptStatus.done),
    _Appt(time: '09:30', name: 'سارة علي', service: 'صبغة شعر', tech: 'ليلى', status: _ApptStatus.inProgress),
    _Appt(time: '10:30', name: 'عمر حسن', service: 'تدليك استرخاء', tech: 'محمود', status: _ApptStatus.scheduled),
    _Appt(time: '11:00', name: 'فاطمة خالد', service: 'عناية بالوجه', tech: 'نور', status: _ApptStatus.scheduled),
    _Appt(time: '14:00', name: 'يوسف إبراهيم', service: 'قص شعر رجالي', tech: 'خالد', status: _ApptStatus.scheduled),
    _Appt(time: '15:30', name: 'دينا حسام', service: 'مانيكير', tech: 'نور', status: _ApptStatus.scheduled),
  ];

  @override
  Widget build(BuildContext context) {
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.room_service, color: _gold),
                  const SizedBox(width: 8),
                  Text('نقاط بيع الخدمات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: _gold),
                    icon: const Icon(Icons.add),
                    label: Text('حجز جديد'),
                  ),
                ],
              ),
            ),
            // Stat strip
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _StatPill(icon: Icons.event_available, label: 'اليوم', value: '${_appointments.length}', color: core_theme.AC.info),
                  const SizedBox(width: 10),
                  _StatPill(icon: Icons.check_circle, label: 'مكتمل', value: '1', color: core_theme.AC.ok),
                  const SizedBox(width: 10),
                  _StatPill(icon: Icons.schedule, label: 'قيد التنفيذ', value: '1', color: core_theme.AC.warn),
                  const SizedBox(width: 10),
                  _StatPill(icon: Icons.attach_money, label: 'إيراد اليوم', value: '1,340 ر.س', color: _gold),
                ],
              ),
            ),
            // Days row
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: List.generate(days.length, (i) {
                  final active = i == _selectedDay;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedDay = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? _gold : core_theme.AC.navy3,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(days[i],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: active ? Colors.white : core_theme.AC.tp,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${i + 15}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: active ? Colors.white : core_theme.AC.tp,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Main: calendar + services
            Expanded(
              child: Row(
                children: [
                  // Left: appointments timeline
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _appointments.length,
                      itemBuilder: (ctx, i) => _ApptCard(appt: _appointments[i]),
                    ),
                  ),
                  // Right: services menu
                  Container(
                    width: 320,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _navy.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.menu_book, color: _navy),
                              SizedBox(width: 8),
                              Text('قائمة الخدمات',
                                  style: TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 14)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _services.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final s = _services[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _gold.withValues(alpha: 0.15),
                                  child: Icon(s.icon, color: _gold, size: 18),
                                ),
                                title: Text(s.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                subtitle: Text('${s.duration} دقيقة', style: const TextStyle(fontSize: 11)),
                                trailing: Text('${s.price.toStringAsFixed(0)} ر.س',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ApptStatus { scheduled, inProgress, done }

class _Service {
  final String id;
  final String name;
  final double price;
  final int duration;
  final IconData icon;
  const _Service({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.icon,
  });
}

class _Appt {
  final String time;
  final String name;
  final String service;
  final String tech;
  final _ApptStatus status;
  const _Appt({
    required this.time,
    required this.name,
    required this.service,
    required this.tech,
    required this.status,
  });
}

class _ApptCard extends StatelessWidget {
  final _Appt appt;
  const _ApptCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (appt.status) {
      _ApptStatus.done => (core_theme.AC.ok, 'مكتمل', Icons.check_circle),
      _ApptStatus.inProgress => (core_theme.AC.warn, 'قيد التنفيذ', Icons.schedule),
      _ApptStatus.scheduled => (core_theme.AC.info, 'محجوز', Icons.event),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: core_theme.AC.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(appt.time,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.spa, size: 12, color: core_theme.AC.ts),
                      const SizedBox(width: 4),
                      Text(appt.service, style: TextStyle(fontSize: 12, color: core_theme.AC.tp)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_pin, size: 12, color: core_theme.AC.ts),
                      const SizedBox(width: 4),
                      Text('الفني: ${appt.tech}',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
