/// APEX Wave 45 — Leave Management.
/// Route: /app/erp/hr/leaves
///
/// Request, approve, track employee leaves.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});
  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _leaves = <_LeaveReq>[
    _LeaveReq('LVE-2026-042', 'أحمد محمد العتيبي', 'سنوية', '2026-05-15', '2026-05-25', 11, 'قيد الاعتماد', 'رحلة عائلية مقررة'),
    _LeaveReq('LVE-2026-041', 'سارة خالد الدوسري', 'مرضية', '2026-04-18', '2026-04-20', 3, 'معتمدة', 'إنفلونزا موسمية — مع إرفاق تقرير طبي'),
    _LeaveReq('LVE-2026-040', 'محمد عبدالله القحطاني', 'اضطرارية', '2026-04-16', '2026-04-16', 1, 'معتمدة', 'وفاة أحد الأقارب'),
    _LeaveReq('LVE-2026-039', 'نورة سعد الغامدي', 'أمومة', '2026-06-01', '2026-08-23', 84, 'قيد الاعتماد', 'إجازة وضع 12 أسبوع نظامية'),
    _LeaveReq('LVE-2026-038', 'فهد ناصر الشمري', 'سنوية', '2026-04-01', '2026-04-07', 7, 'مرفوضة', 'تعارض مع إقفال الربع'),
    _LeaveReq('LVE-2026-037', 'لينا عادل البكري', 'بدون راتب', '2026-05-01', '2026-05-31', 31, 'قيد الاعتماد', 'ظروف شخصية'),
  ];

  final _balances = const [
    _Balance('EMP-001', 'أحمد محمد العتيبي', 30, 5, 25, 22, 6, 16),
    _Balance('EMP-002', 'سارة خالد الدوسري', 22, 3, 19, 18, 2, 16),
    _Balance('EMP-003', 'محمد عبدالله القحطاني', 26, 1, 25, 20, 4, 16),
    _Balance('EMP-004', 'نورة سعد الغامدي', 22, 0, 22, 18, 0, 18),
    _Balance('EMP-005', 'فهد ناصر الشمري', 22, 0, 22, 18, 3, 15),
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
        _buildStatsRow(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.pending, size: 16), text: 'طلبات معلّقة'),
            Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'أرصدة الإجازات'),
            Tab(icon: Icon(Icons.calendar_month, size: 16), text: 'التقويم'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildRequestsTab(),
              _buildBalancesTab(),
              _buildCalendarTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة الإجازات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('طلبات، اعتمادات، أرصدة — موافقة نظام العمل السعودي',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: Text('طلب إجازة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00695C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final pending = _leaves.where((l) => l.status == 'قيد الاعتماد').length;
    final approved = _leaves.where((l) => l.status == 'معتمدة').length;
    final rejected = _leaves.where((l) => l.status == 'مرفوضة').length;
    final total = _leaves.fold(0, (s, l) => s + l.days);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _stat('قيد الاعتماد', '$pending', core_theme.AC.warn, Icons.schedule),
          _stat('معتمدة', '$approved', core_theme.AC.ok, Icons.check_circle),
          _stat('مرفوضة', '$rejected', core_theme.AC.err, Icons.cancel),
          _stat('إجمالي الأيام', '$total يوم', core_theme.AC.info, Icons.today),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _leaves.length,
      itemBuilder: (ctx, i) {
        final l = _leaves[i];
        final sc = _statusColor(l.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _typeColor(l.type).withValues(alpha: 0.15),
                child: Icon(_typeIcon(l.type), color: _typeColor(l.type), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l.employee, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor(l.type).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(l.type, style: TextStyle(fontSize: 10, color: _typeColor(l.type), fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${l.fromDate} → ${l.toDate} (${l.days} ${l.days == 1 ? 'يوم' : 'أيام'})',
                        style: TextStyle(fontSize: 12, color: core_theme.AC.ts, fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    Text(l.reason, style: const TextStyle(fontSize: 12)),
                    Text(l.id, style: TextStyle(fontSize: 10, color: core_theme.AC.td, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(l.status, style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w800)),
                  ),
                  if (l.status == 'قيد الاعتماد') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() => l.status = 'معتمدة');
                          },
                          icon: const Icon(Icons.check, size: 14),
                          label: Text('اعتماد', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(foregroundColor: core_theme.AC.ok),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => l.status = 'مرفوضة');
                          },
                          icon: const Icon(Icons.close, size: 14),
                          label: Text('رفض', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(foregroundColor: core_theme.AC.err),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: core_theme.AC.bdr),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('الموظف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('السنوية المستحقة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المستخدمة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المتبقية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                    Expanded(child: Text('مرضية مستحقة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('مستخدمة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المتبقية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.info))),
                  ],
                ),
              ),
              for (final b in _balances)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(b.id, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                          ],
                        ),
                      ),
                      Expanded(child: Text('${b.annualEntitled} يوم', style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text('${b.annualUsed} يوم', style: TextStyle(fontSize: 12, color: core_theme.AC.warn))),
                      Expanded(
                        child: Text('${b.annualRemaining} يوم',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                      ),
                      Expanded(child: Text('${b.sickEntitled} يوم', style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text('${b.sickUsed} يوم', style: TextStyle(fontSize: 12, color: core_theme.AC.warn))),
                      Expanded(
                        child: Text('${b.sickRemaining} يوم',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: core_theme.AC.info, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طبقاً لنظام العمل السعودي: السنوية 21 يوم/سنة (22 بعد 5 سنوات)، المرضية 30 يوم بأجر كامل + 60 يوم بثلاثة أرباع + 30 يوم بدون أجر.',
                  style: TextStyle(fontSize: 11, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    const days = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('أبريل 2026', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [for (final d in days) Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))],
              ),
              const SizedBox(height: 10),
              for (var week = 0; week < 5; week++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(child: _calendarCell(week * 7 + d + 1, week, d)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('المفتاح', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, children: [
          _legend('سنوية', core_theme.AC.gold),
          _legend('مرضية', core_theme.AC.info),
          _legend('اضطرارية', core_theme.AC.purple),
          _legend('أمومة', core_theme.AC.err),
          _legend('عطلة رسمية', core_theme.AC.ok),
        ]),
      ],
    );
  }

  Widget _calendarCell(int day, int week, int dayOfWeek) {
    if (day < 1 || day > 30) {
      return const SizedBox(height: 50);
    }
    // simulate some leaves on specific days
    Color? bg;
    if (day == 16) {
      bg = core_theme.AC.purple;
    } else if (day >= 18 && day <= 20) {
      bg = core_theme.AC.info;
    } else if (dayOfWeek == 5 || dayOfWeek == 6) {
      bg = core_theme.AC.ok;
    }
    return Container(
      height: 50,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Text('$day', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'معتمدة':
        return core_theme.AC.ok;
      case 'قيد الاعتماد':
        return core_theme.AC.warn;
      case 'مرفوضة':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'سنوية':
        return core_theme.AC.gold;
      case 'مرضية':
        return core_theme.AC.info;
      case 'اضطرارية':
        return core_theme.AC.purple;
      case 'أمومة':
        return core_theme.AC.err;
      case 'بدون راتب':
        return core_theme.AC.td;
      default:
        return core_theme.AC.info;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'سنوية':
        return Icons.beach_access;
      case 'مرضية':
        return Icons.sick;
      case 'اضطرارية':
        return Icons.warning;
      case 'أمومة':
        return Icons.child_care;
      case 'بدون راتب':
        return Icons.money_off;
      default:
        return Icons.event;
    }
  }
}

class _LeaveReq {
  final String id;
  final String employee;
  final String type;
  final String fromDate;
  final String toDate;
  final int days;
  String status;
  final String reason;
  _LeaveReq(this.id, this.employee, this.type, this.fromDate, this.toDate, this.days, this.status, this.reason);
}

class _Balance {
  final String id;
  final String name;
  final int annualEntitled;
  final int annualUsed;
  final int annualRemaining;
  final int sickEntitled;
  final int sickUsed;
  final int sickRemaining;
  const _Balance(this.id, this.name, this.annualEntitled, this.annualUsed, this.annualRemaining, this.sickEntitled, this.sickUsed, this.sickRemaining);
}
