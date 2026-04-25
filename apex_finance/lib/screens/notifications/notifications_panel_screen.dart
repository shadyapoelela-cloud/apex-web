/// APEX — Notifications Panel (Workday split-pattern)
/// /notifications/panel — split into:
///   • Inbox (actionable) — pending approvals, late items
///   • Notifications (info) — done events, FYI
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class NotificationsPanelScreen extends StatefulWidget {
  const NotificationsPanelScreen({super.key});
  @override
  State<NotificationsPanelScreen> createState() => _NotificationsPanelScreenState();
}

class _NotificationsPanelScreenState extends State<NotificationsPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('الإشعارات', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: AC.gold),
            tooltip: 'تعليم الكل كمقروء',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تعليم الكل كمقروء')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AC.gold,
          labelColor: AC.gold,
          unselectedLabelColor: AC.ts,
          tabs: const [
            Tab(icon: Icon(Icons.inbox, size: 16), text: 'صندوق الوارد · 3'),
            Tab(icon: Icon(Icons.notifications_outlined, size: 16), text: 'إشعارات · 8'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_inboxTab(), _notificationsTab()],
      ),
    );
  }

  Widget _inboxTab() {
    final inbox = [
      _Item(
        icon: Icons.assignment_late,
        color: AC.warn,
        title: 'JE-2026-0042 يحتاج موافقتك',
        subtitle: 'قيد إغلاق المخزون · 50,000 ريال',
        actions: ['اعتمد', 'ارفض'],
        timestamp: 'منذ ساعتين',
      ),
      _Item(
        icon: Icons.warning_amber,
        color: AC.err,
        title: 'فاتورة INV-2026-0123 تأخرت 7 أيام',
        subtitle: 'شركة الرياض للمقاولات · 11,500 ريال',
        actions: ['ذكّر العميل', 'اعرض'],
        timestamp: 'منذ يوم',
      ),
      _Item(
        icon: Icons.security_update_warning,
        color: AC.gold,
        title: 'ZATCA CSID ينتهي خلال 30 يوم',
        subtitle: 'يجب التجديد قبل 2026-05-25',
        actions: ['جدّد الآن'],
        timestamp: 'منذ 3 أيام',
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: inbox.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _itemCard(inbox[i]),
    );
  }

  Widget _notificationsTab() {
    final items = [
      _Item(
        icon: Icons.check_circle_outline,
        color: AC.ok,
        title: 'تم إصدار الفاتورة INV-2026-0042',
        subtitle: 'القيد ${"adcfa6b9".substring(0, 8)}... — 11,500 ريال',
        timestamp: 'منذ 5 دقائق',
      ),
      _Item(
        icon: Icons.payment,
        color: AC.ok,
        title: 'استلمت دفعة من شركة الدمام',
        subtitle: '5,000 ريال — تم تحديث AR',
        timestamp: 'منذ ساعة',
      ),
      _Item(
        icon: Icons.psychology,
        color: AC.gold,
        title: 'الذكاء وجد 3 معاملات غير عادية',
        subtitle: 'يُنصح بالمراجعة من شاشة المراجعة',
        timestamp: 'منذ 4 ساعات',
      ),
      _Item(
        icon: Icons.lock_clock,
        color: AC.info,
        title: 'تم إقفال فترة مارس 2026',
        subtitle: 'تم إنجاز 11 من 12 مهمة',
        timestamp: 'منذ يومين',
      ),
      _Item(
        icon: Icons.bar_chart,
        color: AC.gold,
        title: 'تقرير شهر أبريل جاهز',
        subtitle: 'صافي الدخل: 35,000 ريال (+12%)',
        timestamp: 'منذ 3 أيام',
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _itemCard(items[i]),
    );
  }

  Widget _itemCard(_Item item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: item.color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(item.icon, color: item.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(item.subtitle, style: TextStyle(color: AC.ts, fontSize: 11)),
            ]),
          ),
          Text(item.timestamp, style: TextStyle(color: AC.ts, fontSize: 10)),
        ]),
        if (item.actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            for (final a in item.actions.reversed) ...[
              if (item.actions.indexOf(a) > 0)
                TextButton(
                  onPressed: () => context.go('/today'),
                  child: Text(a, style: TextStyle(color: AC.gold)),
                )
              else
                ElevatedButton(
                  onPressed: () => context.go('/today'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AC.gold, foregroundColor: AC.navy),
                  child: Text(a),
                ),
              const SizedBox(width: 6),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _Item {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> actions;
  final String timestamp;
  const _Item({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.actions = const [],
  });
}
