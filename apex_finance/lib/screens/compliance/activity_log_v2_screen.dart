/// APEX — Activity Log v2 (timeline + ZATCA hash chain)
/// /compliance/activity-log-v2 — full audit trail
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';

class ActivityLogV2Screen extends StatefulWidget {
  const ActivityLogV2Screen({super.key});
  @override
  State<ActivityLogV2Screen> createState() => _ActivityLogV2ScreenState();
}

class _ActivityLogV2ScreenState extends State<ActivityLogV2Screen> {
  String _filter = 'all';

  // Demo events
  final List<Map<String, dynamic>> _events = [
    {'time': '2026-04-25 14:32:18', 'user': 'أحمد', 'action': 'إصدار فاتورة', 'object': 'INV-2026-0042', 'kind': 'invoice', 'severity': 'info'},
    {'time': '2026-04-25 14:30:00', 'user': 'أحمد', 'action': 'إنشاء فاتورة مسوّدة', 'object': 'INV-2026-0042', 'kind': 'invoice', 'severity': 'info'},
    {'time': '2026-04-25 12:15:42', 'user': 'AI Copilot', 'action': 'تصنيف 12 معاملة بنكية تلقائياً', 'object': 'AUTO-MATCH', 'kind': 'ai', 'severity': 'success'},
    {'time': '2026-04-25 09:45:00', 'user': 'سارة', 'action': 'موافقة على JE', 'object': 'JE-2026-0091', 'kind': 'je', 'severity': 'info'},
    {'time': '2026-04-25 09:00:00', 'user': 'النظام', 'action': 'مزامنة بنكية تلقائية', 'object': 'SNB Bank', 'kind': 'sync', 'severity': 'info'},
    {'time': '2026-04-25 08:30:00', 'user': 'AI Copilot', 'action': 'كشف معاملة غير عادية', 'object': 'TRANS-9921', 'kind': 'anomaly', 'severity': 'warn'},
    {'time': '2026-04-24 23:01:43', 'user': 'النظام', 'action': 'ZATCA cleared invoice', 'object': 'INV-2026-0041', 'kind': 'zatca', 'severity': 'success'},
    {'time': '2026-04-24 17:30:00', 'user': 'محمد', 'action': 'تسجيل دخول من جهاز جديد', 'object': 'iPhone 15', 'kind': 'security', 'severity': 'warn'},
    {'time': '2026-04-24 14:00:00', 'user': 'أحمد', 'action': 'تعديل CoA', 'object': 'حساب 4100', 'kind': 'config', 'severity': 'info'},
    {'time': '2026-04-24 09:15:00', 'user': 'AI Copilot', 'action': 'حذف فاتورة مكررة', 'object': 'INV-2026-0038', 'kind': 'ai', 'severity': 'success'},
  ];

  IconData _kindIcon(String k) => switch (k) {
        'invoice' => Icons.receipt_long,
        'je' => Icons.book,
        'ai' => Icons.psychology,
        'sync' => Icons.sync,
        'anomaly' => Icons.warning_amber,
        'zatca' => Icons.verified,
        'security' => Icons.security,
        'config' => Icons.settings,
        _ => Icons.event,
      };

  Color _severityColor(String s) => switch (s) {
        'success' => AC.ok,
        'warn' => AC.warn,
        'error' => AC.err,
        _ => AC.info,
      };

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _events;
    return _events.where((e) => e['kind'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'سجل النشاط (Hash-Chain)',
      subtitle: '${_events.length} حدث · موقّع رقمياً',
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _events.length),
        for (final f in [
          ('invoice', 'فواتير', Icons.receipt_long),
          ('je', 'قيود', Icons.book),
          ('ai', 'ذكاء', Icons.psychology),
          ('zatca', 'ZATCA', Icons.verified),
          ('anomaly', 'شذوذ', Icons.warning_amber),
          ('security', 'أمن', Icons.security),
        ])
          ApexFilterChip(
            label: f.$2,
            selected: _filter == f.$1,
            onTap: () => setState(() => _filter = f.$1),
            icon: f.$3,
            count: _events.where((e) => e['kind'] == f.$1).length,
          ),
      ],
      items: _filtered,
      onRefresh: () async {},
      emptyState: ApexEmptyState(
        icon: Icons.history,
        title: 'لا توجد أحداث',
        description: 'سجل النشاط فارغ في هذا التصنيف',
      ),
      itemBuilder: (ctx, e) {
        final color = _severityColor(e['severity'] as String);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(_kindIcon(e['kind'] as String), color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e['action']} — ${e['object']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.person_outline, size: 10, color: AC.ts),
                  const SizedBox(width: 3),
                  Text('${e['user']}',
                      style: TextStyle(color: AC.ts, fontSize: 11)),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 10, color: AC.ts),
                  const SizedBox(width: 3),
                  Text('${e['time']}',
                      style: TextStyle(color: AC.ts, fontSize: 10.5, fontFamily: 'monospace')),
                ]),
              ]),
            ),
            Icon(Icons.fingerprint, color: color, size: 14),
          ]),
        );
      },
    );
  }
}
