/// APEX Wave 67 — Financial Close Checklist.
/// Route: /app/erp/finance/close-checklist
///
/// Monthly close workflow with per-task owner, status, SLA.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class CloseChecklistScreen extends StatefulWidget {
  const CloseChecklistScreen({super.key});
  @override
  State<CloseChecklistScreen> createState() => _CloseChecklistScreenState();
}

class _CloseChecklistScreenState extends State<CloseChecklistScreen> {
  String _period = 'April 2026';

  final _tasks = <_Task>[
    // Day 1-2: Revenue & AR
    _Task('CLOSE-01', 'revenue', 'ترحيل جميع فواتير المبيعات للشهر', 'فريق المبيعات', 'فهد الشمري', 1, 'done', '2026-05-01', '2026-05-01'),
    _Task('CLOSE-02', 'revenue', 'مراجعة الإيرادات المؤجلة (Deferred Revenue)', 'المحاسبة', 'سارة الدوسري', 2, 'done', '2026-05-02', '2026-05-02'),
    _Task('CLOSE-03', 'revenue', 'تسوية حسابات العملاء (AR reconciliation)', 'المحاسبة', 'نورة الغامدي', 2, 'in-progress', '2026-05-02', null),
    // Day 2-3: Expenses & AP
    _Task('CLOSE-04', 'expenses', 'ترحيل فواتير الموردين للشهر', 'المشتريات', 'لينا البكري', 2, 'done', '2026-05-02', '2026-05-02'),
    _Task('CLOSE-05', 'expenses', 'تسوية حسابات الموردين (AP reconciliation)', 'المحاسبة', 'محمد القحطاني', 3, 'pending', '2026-05-03', null),
    _Task('CLOSE-06', 'expenses', 'استحقاقات مصروفات (Accruals)', 'المحاسبة', 'سارة الدوسري', 3, 'pending', '2026-05-03', null),
    // Day 3-4: Cash & Bank
    _Task('CLOSE-07', 'cash', 'المطابقة البنكية (3 حسابات)', 'الخزينة', 'أحمد العتيبي', 3, 'in-progress', '2026-05-03', null),
    _Task('CLOSE-08', 'cash', 'تسوية النقدية والشيكات', 'الخزينة', 'أحمد العتيبي', 3, 'pending', '2026-05-03', null),
    // Day 4-5: Inventory
    _Task('CLOSE-09', 'inventory', 'جرد المخزون (Physical count)', 'العمليات', 'خالد العتيبي', 4, 'pending', '2026-05-04', null),
    _Task('CLOSE-10', 'inventory', 'تحديث تكلفة المبيعات (COGS)', 'المحاسبة', 'نورة الغامدي', 5, 'pending', '2026-05-05', null),
    // Day 5-6: Fixed Assets
    _Task('CLOSE-11', 'assets', 'احتساب إهلاك الشهر', 'المحاسبة', 'فهد الشمري', 5, 'pending', '2026-05-05', null),
    _Task('CLOSE-12', 'assets', 'تسوية الأصول الجديدة / المستبعدة', 'المحاسبة', 'محمد القحطاني', 5, 'pending', '2026-05-05', null),
    // Day 6-7: Payroll & HR
    _Task('CLOSE-13', 'payroll', 'ترحيل مسير الرواتب', 'الموارد البشرية', 'لينا البكري', 6, 'pending', '2026-05-06', null),
    _Task('CLOSE-14', 'payroll', 'استحقاق مكافأة نهاية الخدمة', 'المحاسبة', 'سارة الدوسري', 6, 'pending', '2026-05-06', null),
    // Day 7-8: Tax & Compliance
    _Task('CLOSE-15', 'tax', 'احتساب VAT المستحق', 'الضرائب', 'راشد العنزي', 7, 'pending', '2026-05-07', null),
    _Task('CLOSE-16', 'tax', 'احتساب WHT للدفعات الدولية', 'الضرائب', 'راشد العنزي', 7, 'pending', '2026-05-07', null),
    // Day 8-9: FX & Consolidation
    _Task('CLOSE-17', 'fx', 'إعادة تقييم الأرصدة بالعملات الأجنبية', 'الخزينة', 'أحمد العتيبي', 8, 'pending', '2026-05-08', null),
    _Task('CLOSE-18', 'fx', 'توحيد الفروع (Consolidation)', 'المحاسبة', 'محمد القحطاني', 8, 'pending', '2026-05-08', null),
    // Day 9-10: Reviews & Close
    _Task('CLOSE-19', 'review', 'مراجعة ميزان المراجعة', 'المدير المالي', 'أحمد العتيبي', 9, 'pending', '2026-05-09', null),
    _Task('CLOSE-20', 'review', 'إعداد تقارير الإدارة', 'المحاسبة', 'سارة الدوسري', 9, 'pending', '2026-05-09', null),
    _Task('CLOSE-21', 'review', 'اعتماد القوائم المالية', 'المدير المالي', 'أحمد العتيبي', 10, 'pending', '2026-05-10', null),
    _Task('CLOSE-22', 'review', 'إقفال الفترة في النظام (Period Lock)', 'المدير المالي', 'أحمد العتيبي', 10, 'pending', '2026-05-10', null),
  ];

  @override
  Widget build(BuildContext context) {
    final done = _tasks.where((t) => t.status == 'done').length;
    final inProg = _tasks.where((t) => t.status == 'in-progress').length;
    final pending = _tasks.where((t) => t.status == 'pending').length;
    final progress = done / _tasks.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(progress),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('مكتمل', '$done', core_theme.AC.ok, Icons.check_circle),
            _kpi('قيد التنفيذ', '$inProg', core_theme.AC.info, Icons.sync),
            _kpi('بانتظار', '$pending', core_theme.AC.warn, Icons.pending),
            _kpi('التقدّم العام', '${(progress * 100).toStringAsFixed(0)}%', core_theme.AC.gold, Icons.donut_large),
          ],
        ),
        const SizedBox(height: 20),
        _buildTimeline(),
      ],
    );
  }

  Widget _buildHero(double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFE6C200)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('قائمة إقفال الفترة',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    Text('Month-end close workflow — 22 مهمة · 10 أيام · 8 فرق',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الفترة', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                  Text(_period,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('التقدّم', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 10,
                  ),
                ),
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final byDay = <int, List<_Task>>{};
    for (final t in _tasks) {
      byDay.putIfAbsent(t.day, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort();
    return Column(
      children: [
        for (final day in days) _dayBlock(day, byDay[day]!),
      ],
    );
  }

  Widget _dayBlock(int day, List<_Task> tasks) {
    final allDone = tasks.every((t) => t.status == 'done');
    final color = allDone ? core_theme.AC.ok : core_theme.AC.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.15),
                child: allDone
                    ? Icon(Icons.check, color: color, size: 20)
                    : Text('$day', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Text('اليوم $day',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Text('${tasks.length} مهام',
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              const Spacer(),
              Text(tasks.first.dueDate,
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 10),
          for (final t in tasks)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusColor(t.status).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(t.status), color: _statusColor(t.status), size: 18),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _categoryColor(t.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(_categoryLabel(t.category),
                        style: TextStyle(fontSize: 10, color: _categoryColor(t.category), fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            Icon(Icons.group, size: 11, color: core_theme.AC.td),
                            const SizedBox(width: 3),
                            Text(t.team, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                            const SizedBox(width: 8),
                            Icon(Icons.person, size: 11, color: core_theme.AC.td),
                            const SizedBox(width: 3),
                            Text(t.owner, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (t.completedAt != null) ...[
                    Text('✓ ${t.completedAt}',
                        style: TextStyle(fontSize: 10, color: core_theme.AC.ok, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(t.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_statusLabel(t.status),
                        style: TextStyle(
                          fontSize: 10,
                          color: _statusColor(t.status),
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                  if (t.status != 'done') ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, size: 20, color: core_theme.AC.ok),
                      onPressed: () => setState(() => t.status = 'done'),
                      tooltip: 'وضع كمنجز',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'done':
        return core_theme.AC.ok;
      case 'in-progress':
        return core_theme.AC.info;
      case 'pending':
        return core_theme.AC.warn;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'done':
        return Icons.check_circle;
      case 'in-progress':
        return Icons.sync;
      case 'pending':
        return Icons.radio_button_unchecked;
      default:
        return Icons.circle;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'done':
        return 'مكتمل';
      case 'in-progress':
        return 'قيد التنفيذ';
      case 'pending':
        return 'بانتظار';
      default:
        return s;
    }
  }

  Color _categoryColor(String c) {
    switch (c) {
      case 'revenue':
        return core_theme.AC.ok;
      case 'expenses':
        return core_theme.AC.warn;
      case 'cash':
        return core_theme.AC.info;
      case 'inventory':
        return core_theme.AC.info;
      case 'assets':
        return core_theme.AC.purple;
      case 'payroll':
        return core_theme.AC.err;
      case 'tax':
        return core_theme.AC.err;
      case 'fx':
        return core_theme.AC.purple;
      case 'review':
        return core_theme.AC.gold;
      default:
        return core_theme.AC.td;
    }
  }

  String _categoryLabel(String c) {
    const map = {
      'revenue': 'إيرادات',
      'expenses': 'مصروفات',
      'cash': 'نقدية',
      'inventory': 'مخزون',
      'assets': 'أصول',
      'payroll': 'رواتب',
      'tax': 'ضرائب',
      'fx': 'عملات',
      'review': 'مراجعة',
    };
    return map[c] ?? c;
  }
}

class _Task {
  final String id;
  final String category;
  final String title;
  final String team;
  final String owner;
  final int day;
  String status;
  final String dueDate;
  final String? completedAt;
  _Task(this.id, this.category, this.title, this.team, this.owner, this.day, this.status, this.dueDate, this.completedAt);
}
