/// APEX Wave 103 — Warranty & Service Management.
/// Route: /app/erp/operations/warranty
///
/// Product warranties, service contracts, RMAs, field service.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class WarrantyServiceScreen extends StatefulWidget {
  const WarrantyServiceScreen({super.key});
  @override
  State<WarrantyServiceScreen> createState() => _WarrantyServiceScreenState();
}

class _WarrantyServiceScreenState extends State<WarrantyServiceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _warranties = const [
    _Warranty('WRN-2026-0042', 'أرامكو السعودية', 'SKU-004', 'SAP تنفيذ كامل', '2024-03-15', '2027-03-14', 'active', '24/7 SLA', 'gold', 99.8),
    _Warranty('WRN-2026-0038', 'سابك', 'SKU-011', 'حزمة صيانة ERP سنوية', '2025-09-01', '2026-08-31', 'active', 'Business hours', 'standard', 99.2),
    _Warranty('WRN-2026-0035', 'STC', 'SKU-004', 'SAP تنفيذ', '2024-11-01', '2026-10-31', 'expiring', '24/7 SLA', 'gold', 98.5),
    _Warranty('WRN-2026-0028', 'مجموعة الحبتور', 'SKU-001', 'تدقيق سنوي', '2025-05-01', '2026-04-30', 'expired', 'Next-day', 'standard', 97.1),
    _Warranty('WRN-2026-0021', 'دبي القابضة', 'SKU-012', 'Premium Support', '2025-12-15', '2026-12-14', 'active', '4h response', 'platinum', 99.9),
  ];

  final _tickets = const [
    _ServiceTicket('SRV-2026-0184', 'WRN-2026-0042', 'تعديل على تقرير مالي في SAP', 'open', 'medium', '2026-04-19', 2, 'محمد القحطاني'),
    _ServiceTicket('SRV-2026-0183', 'WRN-2026-0038', 'خطأ في حساب التكاليف الدقيقة', 'in-progress', 'high', '2026-04-18', 12, 'راشد العنزي'),
    _ServiceTicket('SRV-2026-0182', 'WRN-2026-0042', 'تدريب فريق جديد على التقارير', 'resolved', 'low', '2026-04-15', 48, 'سارة الدوسري'),
    _ServiceTicket('SRV-2026-0181', 'WRN-2026-0021', 'طلب تخصيص Dashboard', 'open', 'medium', '2026-04-17', 28, 'فهد الشمري'),
    _ServiceTicket('SRV-2026-0180', 'WRN-2026-0035', 'بطء في النظام — ساعات الذروة', 'in-progress', 'critical', '2026-04-16', 6, 'فريق الطوارئ'),
  ];

  final _rmas = const [
    _RMA('RMA-2026-0015', 'SKU-008', 'بولي بروبلين — دفعة معيبة', 'approved', '2026-04-10', 12000, '15 طن'),
    _RMA('RMA-2026-0014', 'SKU-008', 'فرق في المواصفات', 'investigating', '2026-04-05', 8500, '10 طن'),
    _RMA('RMA-2026-0013', 'SKU-011', 'عيب في التوصيل', 'refunded', '2026-03-28', 4200, '—'),
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
            Tab(icon: Icon(Icons.verified, size: 16), text: 'الضمانات'),
            Tab(icon: Icon(Icons.build, size: 16), text: 'طلبات الخدمة'),
            Tab(icon: Icon(Icons.assignment_return, size: 16), text: 'الإرجاعات RMA'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildWarrantiesTab(),
              _buildTicketsTab(),
              _buildRmaTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الضمانات وخدمة ما بعد البيع',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Warranty & Service — عقود الضمان · SLAs · طلبات الخدمة · الإرجاعات',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final active = _warranties.where((w) => w.status == 'active').length;
    final expiring = _warranties.where((w) => w.status == 'expiring').length;
    final openTickets = _tickets.where((t) => t.status == 'open' || t.status == 'in-progress').length;
    final openRmas = _rmas.where((r) => r.status != 'refunded').length;
    final avgSla = _warranties.where((w) => w.status == 'active').fold(0.0, (s, w) => s + w.slaAchieved) / active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('ضمانات نشطة', '$active', core_theme.AC.ok, Icons.check_circle),
          _kpi('قرب الانتهاء', '$expiring', core_theme.AC.warn, Icons.schedule),
          _kpi('طلبات خدمة مفتوحة', '$openTickets', core_theme.AC.info, Icons.build),
          _kpi('إرجاعات قيد المعالجة', '$openRmas', core_theme.AC.err, Icons.assignment_return),
          _kpi('متوسط SLA', '${avgSla.toStringAsFixed(1)}%', core_theme.AC.gold, Icons.speed),
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
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarrantiesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _warranties.length,
      itemBuilder: (ctx, i) {
        final w = _warranties[i];
        final tierColor = _tierColor(w.tier);
        final statusColor = _statusColor(w.status);
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
                decoration: BoxDecoration(color: tierColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.verified, color: tierColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(w.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(3)),
                          child: Text(w.tier.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(w.product, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('العميل: ${w.customer}',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
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
                        Icon(Icons.schedule, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text('${w.startDate} → ${w.endDate}',
                            style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text(w.sla, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.gold)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${w.slaAchieved}%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: w.slaAchieved >= 99 ? core_theme.AC.ok : core_theme.AC.warn)),
                  Text('SLA تحقق', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                    child: Text(_statusLabel(w.status),
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTicketsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _tickets.length,
      itemBuilder: (ctx, i) {
        final t = _tickets[i];
        final pColor = _priorityColor(t.priority);
        final sColor = _ticketStatusColor(t.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pColor.withOpacity(0.3), width: t.priority == 'critical' ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(width: 6, height: 50, color: pColor),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: pColor, borderRadius: BorderRadius.circular(3)),
                          child: Text(_priorityLabel(t.priority),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Text(t.warrantyId, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(t.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.createdAt,
                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                    Text('${t.hoursOpen} ساعة',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.tp, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.person, size: 12, color: core_theme.AC.ts),
                    const SizedBox(width: 4),
                    Text(t.assignee, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(_ticketStatusLabel(t.status),
                    style: TextStyle(fontSize: 11, color: sColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRmaTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _rmas.length,
      itemBuilder: (ctx, i) {
        final r = _rmas[i];
        final color = r.status == 'approved' ? core_theme.AC.info : r.status == 'investigating' ? core_theme.AC.warn : core_theme.AC.ok;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.assignment_return, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                    Text(r.reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: core_theme.AC.info.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(r.sku,
                              style: TextStyle(fontSize: 10, color: core_theme.AC.info, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text(r.quantity, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
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
                    Text('${_fmt(r.value.toDouble())} ر.س',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                      child: Text(_rmaStatusLabel(r.status),
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _tierColor(String t) {
    switch (t) {
      case 'platinum':
        return const Color(0xFF455A64);
      case 'gold':
        return core_theme.AC.gold;
      case 'silver':
        return core_theme.AC.td;
      default:
        return core_theme.AC.info;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return core_theme.AC.ok;
      case 'expiring':
        return core_theme.AC.warn;
      case 'expired':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'نشط';
      case 'expiring':
        return 'قرب الانتهاء';
      case 'expired':
        return 'منتهي';
      default:
        return s;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical':
        return core_theme.AC.err;
      case 'high':
        return core_theme.AC.warn;
      case 'medium':
        return core_theme.AC.info;
      case 'low':
        return core_theme.AC.td;
      default:
        return core_theme.AC.td;
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'critical':
        return 'حرج';
      case 'high':
        return 'عالٍ';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return p;
    }
  }

  Color _ticketStatusColor(String s) {
    switch (s) {
      case 'open':
        return core_theme.AC.info;
      case 'in-progress':
        return core_theme.AC.warn;
      case 'resolved':
        return core_theme.AC.ok;
      default:
        return core_theme.AC.td;
    }
  }

  String _ticketStatusLabel(String s) {
    switch (s) {
      case 'open':
        return 'جديد';
      case 'in-progress':
        return 'قيد التنفيذ';
      case 'resolved':
        return 'محلول';
      default:
        return s;
    }
  }

  String _rmaStatusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'موافق عليه';
      case 'investigating':
        return 'قيد التحقيق';
      case 'refunded':
        return 'تم الاسترداد';
      default:
        return s;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Warranty {
  final String id;
  final String customer;
  final String sku;
  final String product;
  final String startDate;
  final String endDate;
  final String status;
  final String sla;
  final String tier;
  final double slaAchieved;
  const _Warranty(this.id, this.customer, this.sku, this.product, this.startDate, this.endDate, this.status, this.sla, this.tier, this.slaAchieved);
}

class _ServiceTicket {
  final String id;
  final String warrantyId;
  final String description;
  final String status;
  final String priority;
  final String createdAt;
  final int hoursOpen;
  final String assignee;
  const _ServiceTicket(this.id, this.warrantyId, this.description, this.status, this.priority, this.createdAt, this.hoursOpen, this.assignee);
}

class _RMA {
  final String id;
  final String sku;
  final String reason;
  final String status;
  final String date;
  final int value;
  final String quantity;
  const _RMA(this.id, this.sku, this.reason, this.status, this.date, this.value, this.quantity);
}
