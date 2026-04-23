/// Wave 155 — Milestone Billing (project-based invoicing).
///
/// Percentage-of-completion / milestone-triggered billing engine.
/// Essential for construction, consulting, engineering projects.
/// Features:
///   - Project milestone schedule
///   - % Complete tracking
///   - Auto-trigger invoice on milestone completion
///   - Retention (held-back) tracking for construction
///   - Cost-to-complete forecasting (IFRS 15 compliant)
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class MilestoneBillingScreen extends StatefulWidget {
  const MilestoneBillingScreen({super.key});

  @override
  State<MilestoneBillingScreen> createState() => _MilestoneBillingScreenState();
}

class _MilestoneBillingScreenState extends State<MilestoneBillingScreen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _selected = 'P-2026-042';

  static const _projects = <_Proj>[
    _Proj(code: 'P-2026-042', name: 'مجمّع أبراج الرياض السكنية', client: 'شركة الإسكان الوطنية', contractValue: 45000000, billedPct: 0.62),
    _Proj(code: 'P-2026-051', name: 'مركز طبي تخصصي', client: 'مجموعة الصحة المتكاملة', contractValue: 18500000, billedPct: 0.35),
    _Proj(code: 'P-2026-018', name: 'تطبيق ERP للجامعة', client: 'جامعة الملك عبدالعزيز', contractValue: 3400000, billedPct: 0.80),
  ];

  static const _milestones = <_Milestone>[
    _Milestone(name: 'التوقيع والدفعة المقدمة', amount: 4500000, pct: 10, dueDate: '2025-10-15', status: _MStatus.billed, invoice: 'INV-2025-1042'),
    _Milestone(name: 'اعتماد التصاميم النهائية', amount: 6750000, pct: 15, dueDate: '2025-12-01', status: _MStatus.billed, invoice: 'INV-2025-1188'),
    _Milestone(name: 'إكمال الحفريات والأساسات', amount: 9000000, pct: 20, dueDate: '2026-02-20', status: _MStatus.billed, invoice: 'INV-2026-0142'),
    _Milestone(name: 'الهيكل الإنشائي — الدور الثالث', amount: 7650000, pct: 17, dueDate: '2026-04-15', status: _MStatus.readyToBill, invoice: null),
    _Milestone(name: 'التشطيبات الداخلية', amount: 8100000, pct: 18, dueDate: '2026-07-30', status: _MStatus.inProgress, invoice: null),
    _Milestone(name: 'الأنظمة الكهروميكانيكية', amount: 4950000, pct: 11, dueDate: '2026-09-15', status: _MStatus.scheduled, invoice: null),
    _Milestone(name: 'الاستلام النهائي والتسليم', amount: 4050000, pct: 9, dueDate: '2026-11-30', status: _MStatus.scheduled, invoice: null),
  ];

  @override
  Widget build(BuildContext context) {
    final currentProj = _projects.firstWhere((p) => p.code == _selected, orElse: () => _projects.first);
    final totalBilled = _milestones
        .where((m) => m.status == _MStatus.billed)
        .fold<double>(0, (s, m) => s + m.amount);
    final retention = totalBilled * 0.05;

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
                  Icon(Icons.flag, color: _gold),
                  const SizedBox(width: 8),
                  Text('فوترة المراحل',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: core_theme.AC.ok.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: core_theme.AC.ok.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 12, color: core_theme.AC.ok),
                        SizedBox(width: 4),
                        Text('IFRS 15 — منهج نسبة الإنجاز',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.ok)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Project selector
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _projects.map((p) {
                    final active = p.code == _selected;
                    return Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selected = p.code),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 280,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: active ? _gold.withValues(alpha: 0.08) : core_theme.AC.navy3,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: active ? _gold : core_theme.AC.bdr,
                                width: active ? 2 : 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.work, size: 14, color: active ? _gold : core_theme.AC.ts),
                                  const SizedBox(width: 6),
                                  Text(p.code,
                                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                                  const Spacer(),
                                  Text('${(p.billedPct * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: active ? _gold : core_theme.AC.tp)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(p.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(p.client,
                                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: p.billedPct,
                                  minHeight: 4,
                                  backgroundColor: core_theme.AC.bdr,
                                  color: _gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                      child: _StatCard(
                          icon: Icons.attach_money,
                          label: 'قيمة العقد',
                          value: '${(currentProj.contractValue / 1e6).toStringAsFixed(1)}م ر.س',
                          color: _navy)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          icon: Icons.done_all,
                          label: 'مفوتر حتى الآن',
                          value: '${(totalBilled / 1e6).toStringAsFixed(1)}م ر.س',
                          color: core_theme.AC.ok)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          icon: Icons.account_balance_wallet,
                          label: 'محتجز (5%)',
                          value: '${(retention / 1e6).toStringAsFixed(2)}م ر.س',
                          color: core_theme.AC.warn)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          icon: Icons.pending_actions,
                          label: 'جاهز للفوترة',
                          value: '${(_milestones.firstWhere((m) => m.status == _MStatus.readyToBill, orElse: () => _milestones.first).amount / 1e6).toStringAsFixed(2)}م ر.س',
                          color: _gold)),
                ],
              ),
            ),

            // Milestone timeline
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _milestones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final m = _milestones[i];
                  final (color, label, icon) = switch (m.status) {
                    _MStatus.billed => (core_theme.AC.ok, 'تم الفوترة', Icons.check_circle),
                    _MStatus.readyToBill => (core_theme.AC.warn, 'جاهز للفوترة', Icons.receipt_long),
                    _MStatus.inProgress => (core_theme.AC.info, 'قيد التنفيذ', Icons.construction),
                    _MStatus.scheduled => (core_theme.AC.td, 'مجدول', Icons.schedule),
                  };

                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 11, color: core_theme.AC.ts),
                                    const SizedBox(width: 4),
                                    Text('استحقاق: ${m.dueDate}',
                                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                                    if (m.invoice != null) ...[
                                      const SizedBox(width: 10),
                                      Icon(Icons.receipt, size: 11, color: core_theme.AC.ts),
                                      const SizedBox(width: 4),
                                      Text(m.invoice!,
                                          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${m.pct}%',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
                              Text('${(m.amount / 1e6).toStringAsFixed(2)}م ر.س',
                                  style: TextStyle(fontSize: 12, color: core_theme.AC.tp)),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                          ),
                          if (m.status == _MStatus.readyToBill) ...[
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: () {},
                              style: FilledButton.styleFrom(backgroundColor: _gold),
                              icon: const Icon(Icons.send, size: 14),
                              label: Text('فوترة الآن'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MStatus { billed, readyToBill, inProgress, scheduled }

class _Proj {
  final String code;
  final String name;
  final String client;
  final double contractValue;
  final double billedPct;
  const _Proj({
    required this.code,
    required this.name,
    required this.client,
    required this.contractValue,
    required this.billedPct,
  });
}

class _Milestone {
  final String name;
  final double amount;
  final int pct;
  final String dueDate;
  final _MStatus status;
  final String? invoice;
  const _Milestone({
    required this.name,
    required this.amount,
    required this.pct,
    required this.dueDate,
    required this.status,
    required this.invoice,
  });
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
