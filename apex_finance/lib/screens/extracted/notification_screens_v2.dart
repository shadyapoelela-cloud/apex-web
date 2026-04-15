import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/shared_constants.dart';
import '../../core/ui_components.dart';

// Phase 10 Notification System §13
// ═══════════════════════════════════════════════════════════
class NotificationCenterScreenV2 extends StatefulWidget {
  const NotificationCenterScreenV2({super.key});
  @override State<NotificationCenterScreenV2> createState() => _NotifCenterV2State();
}
class _NotifCenterV2State extends State<NotificationCenterScreenV2> {
  List<dynamic> _notifs = [];
  bool _loading = true;
  int _unread = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getNotificationsPaged(pageSize: 50);
      final c = await ApiService.getNotificationCount();
      if (r.success) {
        setState(() => _notifs = r.data['notifications'] ?? []);
      }
      if (c.success) {
        setState(() => _unread = c.data['unread'] ?? 0);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    await ApiService.markNotificationsRead();
    _load();
  }

  Future<void> _markOneRead(String id) async {
    await ApiService.markNotificationRead(id);
    _load();
  }

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'person_add': return Icons.person_add;
      case 'verified': return Icons.verified;
      case 'upgrade': return Icons.upgrade;
      case 'timer': return Icons.timer;
      case 'assignment': return Icons.assignment;
      case 'folder_off': return Icons.folder_off;
      case 'alarm': return Icons.alarm;
      case 'block': return Icons.block;
      case 'check_circle': return Icons.check_circle;
      case 'thumb_up': return Icons.thumb_up;
      case 'thumb_down': return Icons.thumb_down;
      case 'policy': return Icons.policy;
      case 'delete_outline': return Icons.delete_outline;
      default: return Icons.notifications;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'registration': return AC.ok;
      case 'verification': return AC.cyan;
      case 'plan_upgrade': return AC.gold;
      case 'plan_expiry_warning': return AC.warn;
      case 'task_assigned': return AC.cyan;
      case 'documents_missing': return AC.err;
      case 'deadline_approaching': return AC.warn;
      case 'account_suspended': return AC.err;
      case 'account_unsuspended': return AC.ok;
      case 'feedback_accepted': return AC.ok;
      case 'feedback_rejected': return AC.err;
      case 'terms_changed': return AC.warn;
      case 'closure_requested': return AC.err;
      default: return AC.ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('الإشعارات${_unread > 0 ? " ($_unread)" : ""}'),
        backgroundColor: AC.navy2,
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('قراءة الكل', style: TextStyle(color: AC.gold, fontSize: 12)),
            ),
          ApexIconButton(
            icon: Icons.settings,
            color: AC.ts,
            size: 20,
            onPressed: () => context.push('/notifications/prefs'),
          ),
        ],
      ),
      body: _loading
        ? Center(child: CircularProgressIndicator(color: AC.gold))
        : _notifs.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_off, color: AC.ts, size: 48),
              SizedBox(height: 12),
              Text('لا توجد إشعارات', style: TextStyle(color: AC.ts)),
            ]))
          : RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _notifs.length,
              itemBuilder: (_, i) {
                final n = _notifs[i];
                final isRead = n['is_read'] == true;
                return GestureDetector(
                  onTap: () { if (!isRead) _markOneRead(n['id']); },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? AC.navy2 : AC.navy3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isRead ? Colors.transparent : AC.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _colorFor(n['type']).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(n['icon']), color: _colorFor(n['type']), size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title_ar'] ?? '', style: TextStyle(
                          color: AC.tp, fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                        if (n['body_ar'] != null)
                          Text(n['body_ar'], style: TextStyle(color: AC.ts, fontSize: 12),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                      SizedBox(width: 8),
                      Column(children: [
                        Text(n['created_at']?.toString().substring(11, 16) ?? '',
                          style: TextStyle(color: AC.ts, fontSize: 11)),
                        if (!isRead) Container(
                          margin: EdgeInsets.only(top: 6),
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: AC.gold, shape: BoxShape.circle),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            )),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// NotificationPrefsScreen — تفضيلات الإشعارات
// ═══════════════════════════════════════════════════════════
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});
  @override State<NotificationPrefsScreen> createState() => _NotifPrefsState();
}
class _NotifPrefsState extends State<NotificationPrefsScreen> {
  List<dynamic> _prefs = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getNotificationPreferences();
      if (r.success) {
        setState(() => _prefs = r.data['preferences'] ?? []);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggle(String type, String channel, bool val) async {
    final pref = _prefs.firstWhere((p) => p['type'] == type, orElse: () => null);
    if (pref == null) return;
    await ApiService.updateNotificationPreferences(
      notificationType: type,
      inApp: channel == 'in_app' ? val : (pref['in_app'] == true),
      email: channel == 'email' ? val : (pref['email'] == true),
      sms: channel == 'sms' ? val : (pref['sms'] == true),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: Text('تفضيلات الإشعارات'), backgroundColor: AC.navy2),
      body: _loading
        ? Center(child: CircularProgressIndicator(color: AC.gold))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _prefs.length,
            itemBuilder: (_, i) {
              final p = _prefs[i];
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['title_ar'] ?? p['type'], style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _chip('داخل التطبيق', p['in_app'] == true, () => _toggle(p['type'], 'in_app', !(p['in_app'] == true))),
                    const SizedBox(width: 8),
                    _chip('بريد إلكتروني', p['email'] == true, () => _toggle(p['type'], 'email', !(p['email'] == true))),
                    const SizedBox(width: 8),
                    _chip('رسالة SMS', p['sms'] == true, () => _toggle(p['type'], 'sms', !(p['sms'] == true))),
                  ]),
                ]),
              );
            },
          ),
    ));
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AC.gold.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AC.gold : AC.ts.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(color: active ? AC.gold : AC.ts, fontSize: 11)),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// LegalDocumentsScreen — الشروط والأحكام والسياسات
// Phase 11 Legal Acceptance §12
// ═══════════════════════════════════════════════════════════
