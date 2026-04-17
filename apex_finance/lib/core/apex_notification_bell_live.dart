/// Live-updating wrapper around ApexNotificationBell.
///
/// Subscribes to the current user's WS channel (`user:{uid}`) and
/// prepends each incoming activity event to the bell. New arrivals
/// bump the unread count and show the usual dot on the icon.
///
/// Usage (drop into an AppBar actions slot):
/// ```dart
/// ApexNotificationBellLive(userId: S.uid)
/// ```
library;

import 'package:flutter/material.dart';

import 'apex_notification_bell.dart';
import 'apex_ws_client.dart';

class ApexNotificationBellLive extends StatefulWidget {
  /// If null, we fall back to `S.uid` at build time. Passing it in
  /// explicitly is nicer for tests.
  final String? userId;

  /// Seed notifications shown the instant the widget mounts (e.g. from
  /// an earlier HTTP fetch).
  final List<ApexNotification> initial;

  final VoidCallback? onSeeAll;

  const ApexNotificationBellLive({
    super.key,
    this.userId,
    this.initial = const [],
    this.onSeeAll,
  });

  @override
  State<ApexNotificationBellLive> createState() =>
      _ApexNotificationBellLiveState();
}

class _ApexNotificationBellLiveState extends State<ApexNotificationBellLive> {
  late List<ApexNotification> _items = List.of(widget.initial);
  ApexWsSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final uid = widget.userId;
    if (uid != null && uid.isNotEmpty) {
      _sub = ApexWsClient.instance.subscribe('user:$uid');
      _sub!.events.listen(_onEvent);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> msg) {
    if (!mounted) return;
    final id = msg['activity_id'] as String? ?? UniqueKey().toString();
    final type = msg['type'] as String? ?? 'activity';
    final summary = msg['summary'] as String? ?? '';
    final action = msg['action'] as String? ?? '';
    final ts = DateTime.tryParse(msg['timestamp'] as String? ?? '') ??
        DateTime.now();

    final severity = _severityFor(type, action);
    final notif = ApexNotification(
      id: id,
      title: _titleFor(action),
      body: summary,
      timestamp: ts,
      severity: severity,
    );
    // Dedupe by id
    if (_items.any((n) => n.id == id)) return;
    setState(() => _items = [notif, ..._items]);
  }

  String _severityFor(String type, String action) {
    if (type.contains('error') || action.contains('dead') ||
        action.contains('rejected')) {
      return 'error';
    }
    if (type.contains('success') || action.contains('reported') ||
        action.contains('cleared') || action.contains('paid')) {
      return 'success';
    }
    if (action.contains('overdue') || action.contains('late')) {
      return 'warning';
    }
    return 'info';
  }

  String _titleFor(String action) {
    return switch (action) {
      'commented' => 'تعليق جديد',
      'note' => 'ملاحظة جديدة',
      'status_changed' => 'تغيّر الحالة',
      'attachment_added' => 'مرفق جديد',
      'created' => 'تم الإنشاء',
      'paid' => 'تم الدفع',
      'deleted' => 'تم الحذف',
      _ => 'نشاط جديد',
    };
  }

  void _markRead(String id) {
    setState(() {
      _items = _items
          .map((n) => n.id == id
              ? ApexNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  timestamp: n.timestamp,
                  severity: n.severity,
                  read: true,
                )
              : n)
          .toList();
    });
  }

  void _markAllRead() {
    setState(() {
      _items = _items
          .map((n) => ApexNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                timestamp: n.timestamp,
                severity: n.severity,
                read: true,
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ApexNotificationBell(
      notifications: _items,
      onMarkRead: _markRead,
      onMarkAllRead: _markAllRead,
      onSeeAll: widget.onSeeAll,
    );
  }
}
