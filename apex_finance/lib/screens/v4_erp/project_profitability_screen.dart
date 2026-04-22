/// APEX Wave 66 — Project Profitability / Project P&L.
/// Route: /app/erp/operations/project-pnl
///
/// Revenue, cost, margin per project with WIP tracking.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ProjectProfitabilityScreen extends StatefulWidget {
  const ProjectProfitabilityScreen({super.key});
  @override
  State<ProjectProfitabilityScreen> createState() => _ProjectProfitabilityScreenState();
}

class _ProjectProfitabilityScreenState extends State<ProjectProfitabilityScreen> {
  String _sort = 'margin';

  final _projects = <_Project>[
    _Project('PRJ-2026-012', 'تنفيذ SAP S/4HANA — أرامكو', 'aramco', 2400000, 1680000, 42, '2025-08-15', '2026-06-30', 'on-track'),
    _Project('PRJ-2026-008', 'تدقيق سنوي — NEOM', 'neom', 2400000, 1450000, 38, '2026-01-05', '2026-05-15', 'on-track'),
    _Project('PRJ-2025-045', 'مراجعة محاسبية — سابك', 'sabic', 1850000, 1625000, 62, '2025-06-01', '2026-04-30', 'risky'),
    _Project('PRJ-2026-003', 'تحوّل رقمي — STC', 'stc', 3200000, 1920000, 48, '2025-11-01', '2026-09-30', 'on-track'),
    _Project('PRJ-2025-072', 'استشارات مالية — دبي القابضة', 'dubai', 1450000, 1320000, 85, '2025-03-15', '2026-05-20', 'delayed'),
    _Project('PRJ-2026-015', 'تنفيذ APEX Match — مجموعة الحبتور', 'habtoor', 680000, 285000, 25, '2026-02-01', '2026-07-30', 'on-track'),
    _Project('PRJ-2026-019', 'Smart City IoT — NEOM', 'neom', 4200000, 2850000, 55, '2025-10-01', '2026-12-31', 'risky'),
    _Project('PRJ-2025-088', 'تدريب موظفين — مصرف الراجحي', 'rajhi', 420000, 380000, 91, '2025-07-01', '2026-04-30', 'on-track'),
  ];

  List<_Project> get _sorted {
    final list = List<_Project>.from(_projects);
    switch (_sort) {
      case 'margin':
        list.sort((a, b) => b.marginPct.compareTo(a.marginPct));
        break;
      case 'revenue':
        list.sort((a, b) => b.revenue.compareTo(a.revenue));
        break;
      case 'progress':
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _projects.fold(0.0, (s, p) => s + p.revenue);
    final totalCost = _projects.fold(0.0, (s, p) => s + p.cost);
    final totalMargin = totalRevenue - totalCost;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('عدد المشاريع النشطة', '${_projects.length}', core_theme.AC.info, Icons.work),
            _kpi('إجمالي الإيرادات', _fmtM(totalRevenue), core_theme.AC.gold, Icons.attach_money),
            _kpi('إجمالي التكلفة', _fmtM(totalCost), core_theme.AC.warn, Icons.trending_down),
            _kpi('صافي الربح', _fmtM(totalMargin), core_theme.AC.ok, Icons.savings),
            _kpi('هامش الربح', '${(totalMargin / totalRevenue * 100).toStringAsFixed(1)}%', core_theme.AC.info, Icons.donut_large),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('ترتيب حسب:', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            const SizedBox(width: 10),
            _sortChip('margin', 'الهامش'),
            const SizedBox(width: 6),
            _sortChip('revenue', 'الإيرادات'),
            const SizedBox(width: 6),
            _sortChip('progress', 'نسبة الإنجاز'),
          ],
        ),
        const SizedBox(height: 16),
        for (final p in _sorted) _projectCard(p),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF006064), Color(0xFF00838F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ربحية المشاريع',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('P&L على مستوى كل مشروع · تتبع الإيرادات، التكلفة، الهامش، وWIP',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String id, String label) {
    final selected = _sort == id;
    return InkWell(
      onTap: () => setState(() => _sort = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00838F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF00838F) : core_theme.AC.td),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : core_theme.AC.tp,
            )),
      ),
    );
  }

  Widget _projectCard(_Project p) {
    final statusColor = _statusColor(p.status);
    final marginColor = p.marginPct >= 40 ? core_theme.AC.ok : p.marginPct >= 20 ? core_theme.AC.warn : core_theme.AC.err;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(p.status), size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(_statusLabel(p.status),
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pl('الإيرادات', p.revenue, core_theme.AC.gold, Icons.trending_up),
              _pl('التكلفة', p.cost, core_theme.AC.warn, Icons.trending_down),
              _pl('الهامش', p.margin, core_theme.AC.ok, Icons.account_balance_wallet),
              _plPct('هامش %', p.marginPct, marginColor),
              _plDate('البداية', p.startDate),
              _plDate('النهاية', p.endDate),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('الإنجاز', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: p.progress / 100,
                  backgroundColor: core_theme.AC.bdr,
                  valueColor: AlwaysStoppedAnimation(p.progress >= 80 ? core_theme.AC.ok : p.progress >= 40 ? core_theme.AC.info : core_theme.AC.warn),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 10),
              Text('${p.progress}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF006064))),
            ],
          ),
          if (p.progress < _expectedProgress(p)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.warn,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: core_theme.AC.warn),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: core_theme.AC.warn, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الإنجاز الفعلي (${p.progress}%) أقل من المتوقّع (${_expectedProgress(p)}%) بناءً على المدة الزمنية',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.tp),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _expectedProgress(_Project p) {
    final start = DateTime.parse(p.startDate);
    final end = DateTime.parse(p.endDate);
    final now = DateTime(2026, 4, 19);
    final total = end.difference(start).inDays;
    final elapsed = now.difference(start).inDays;
    return (elapsed / total * 100).clamp(0, 100).toInt();
  }

  Widget _pl(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
            const SizedBox(height: 2),
            Text(_fmtM(value),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _plPct(String label, double value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            const SizedBox(height: 2),
            Text('${value.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _plDate(String label, String date) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: core_theme.AC.navy3,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            const SizedBox(height: 2),
            Text(date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'on-track':
        return core_theme.AC.ok;
      case 'risky':
        return core_theme.AC.warn;
      case 'delayed':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'on-track':
        return Icons.check_circle;
      case 'risky':
        return Icons.warning;
      case 'delayed':
        return Icons.error;
      default:
        return Icons.circle;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'on-track':
        return 'على المسار';
      case 'risky':
        return 'تحذير';
      case 'delayed':
        return 'متأخر';
      default:
        return s;
    }
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M ر.س';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _Project {
  final String id;
  final String name;
  final String customer;
  final double revenue;
  final double cost;
  final int progress;
  final String startDate;
  final String endDate;
  final String status;
  _Project(this.id, this.name, this.customer, this.revenue, this.cost, this.progress, this.startDate, this.endDate, this.status);

  double get margin => revenue - cost;
  double get marginPct => revenue > 0 ? (margin / revenue * 100) : 0;
}
