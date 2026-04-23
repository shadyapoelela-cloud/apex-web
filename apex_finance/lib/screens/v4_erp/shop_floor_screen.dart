/// Wave 153 — Shop Floor Control.
///
/// MES (Manufacturing Execution System) — Plex / SAP ME / Tulip-class.
/// Features:
///   - Live work-order board (Kanban by status)
///   - Machine status: running / idle / down
///   - OEE (Overall Equipment Effectiveness) gauge
///   - Quality checks at each station
///   - Operator labor tracking
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ShopFloorScreen extends StatefulWidget {
  const ShopFloorScreen({super.key});

  @override
  State<ShopFloorScreen> createState() => _ShopFloorScreenState();
}

class _ShopFloorScreenState extends State<ShopFloorScreen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  static const _stations = <_Station>[
    _Station(name: 'محطة القطع 1', product: 'أريكة فاخرة', operator: 'أحمد', progress: 0.62, oee: 91, status: _MStatus.running),
    _Station(name: 'محطة القطع 2', product: 'طاولة طعام', operator: 'خالد', progress: 0.34, oee: 88, status: _MStatus.running),
    _Station(name: 'محطة التجميع A', product: 'خزانة ملابس', operator: 'يوسف', progress: 0.85, oee: 84, status: _MStatus.running),
    _Station(name: 'محطة التجميع B', product: '—', operator: '—', progress: 0, oee: 0, status: _MStatus.idle),
    _Station(name: 'محطة التنجيد', product: 'أريكة فاخرة', operator: 'سامي', progress: 0.41, oee: 92, status: _MStatus.running),
    _Station(name: 'محطة الدهان', product: 'طاولة قهوة', operator: 'محمود', progress: 0.75, oee: 79, status: _MStatus.running),
    _Station(name: 'محطة الجودة', product: 'كرسي مكتبي', operator: 'ليلى', progress: 0.50, oee: 96, status: _MStatus.running),
    _Station(name: 'محطة التغليف', product: '—', operator: '—', progress: 0, oee: 0, status: _MStatus.down),
  ];

  static const _workOrders = <_WO>[
    _WO(id: 'WO-2026-1124', product: 'أريكة ثلاثية فاخرة', qty: 8, progress: 0.62, priority: _Prio.high, dueIn: 3),
    _WO(id: 'WO-2026-1125', product: 'طاولة طعام 6 مقاعد', qty: 5, progress: 0.34, priority: _Prio.medium, dueIn: 7),
    _WO(id: 'WO-2026-1126', product: 'خزانة ملابس 4 أبواب', qty: 8, progress: 0.85, priority: _Prio.high, dueIn: 1),
    _WO(id: 'WO-2026-1127', product: 'كرسي مكتب تنفيذي', qty: 8, progress: 0.50, priority: _Prio.low, dueIn: 12),
    _WO(id: 'WO-2026-1128', product: 'طاولة قهوة رخامية', qty: 5, progress: 0.75, priority: _Prio.medium, dueIn: 5),
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
                  Icon(Icons.factory, color: _gold),
                  const SizedBox(width: 8),
                  Text('إدارة خط الإنتاج (Shop Floor)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: core_theme.AC.ok.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: core_theme.AC.ok),
                        SizedBox(width: 6),
                        Text('6 محطات نشطة · 1 متوقفة',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: core_theme.AC.ok)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.precision_manufacturing, label: 'OEE الإجمالي', value: '87%', color: core_theme.AC.gold)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.done_all, label: 'منتج اليوم', value: '142 قطعة', color: core_theme.AC.ok)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.report_problem, label: 'عيوب اليوم', value: '3', color: core_theme.AC.err)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.schedule, label: 'زمن التوقف', value: '42 د', color: core_theme.AC.warn)),
                ],
              ),
            ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: Stations grid
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المحطات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1.1,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                              itemCount: _stations.length,
                              itemBuilder: (ctx, i) => _StationCard(station: _stations[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right: Work orders
                  Container(
                    width: 380,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: core_theme.AC.bdr)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أوامر الإنتاج',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _workOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) => _WOCard(wo: _workOrders[i]),
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

enum _MStatus { running, idle, down }
enum _Prio { high, medium, low }

class _Station {
  final String name;
  final String product;
  final String operator;
  final double progress;
  final int oee;
  final _MStatus status;
  const _Station({
    required this.name,
    required this.product,
    required this.operator,
    required this.progress,
    required this.oee,
    required this.status,
  });
}

class _WO {
  final String id;
  final String product;
  final int qty;
  final double progress;
  final _Prio priority;
  final int dueIn;
  const _WO({
    required this.id,
    required this.product,
    required this.qty,
    required this.progress,
    required this.priority,
    required this.dueIn,
  });
}

class _StationCard extends StatelessWidget {
  final _Station station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (station.status) {
      _MStatus.running => (core_theme.AC.ok, 'يعمل', Icons.play_arrow),
      _MStatus.idle => (core_theme.AC.td, 'متوقفة', Icons.pause),
      _MStatus.down => (core_theme.AC.err, 'عطل', Icons.error),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(color: core_theme.AC.tp.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (station.oee > 0)
                Text('${station.oee}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: station.oee > 90 ? core_theme.AC.ok : (station.oee > 80 ? core_theme.AC.warn : core_theme.AC.err))),
            ],
          ),
          const SizedBox(height: 8),
          Text(station.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(station.product,
              style: TextStyle(fontSize: 11, color: core_theme.AC.ts), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('المشغل: ${station.operator}',
              style: TextStyle(fontSize: 10, color: core_theme.AC.td), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          if (station.progress > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: station.progress,
                minHeight: 6,
                backgroundColor: core_theme.AC.bdr,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _WOCard extends StatelessWidget {
  final _WO wo;
  const _WOCard({required this.wo});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (wo.priority) {
      _Prio.high => (core_theme.AC.err, 'عاجل'),
      _Prio.medium => (core_theme.AC.warn, 'متوسط'),
      _Prio.low => (core_theme.AC.ok, 'منخفض'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(wo.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(wo.product, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text('الكمية: ${wo.qty} · متبقي ${wo.dueIn} يوم',
              style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: wo.progress,
                    minHeight: 6,
                    backgroundColor: core_theme.AC.bdr,
                    color: core_theme.AC.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(wo.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
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
