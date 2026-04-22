/// APEX Notification Bell — app-bar icon with unread count + dropdown.
///
/// Source: Mercury / Linear notification UX. Click the bell → list of
/// recent notifications with mark-as-read + "view all" link.
///
/// Usage:
/// ```dart
/// AppBar(actions: [
///   ApexNotificationBell(
///     notifications: _notifications,
///     onMarkRead: _markAsRead,
///     onSeeAll: () => context.go('/notifications'),
///   ),
/// ])
/// ```
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';
import 'theme.dart' as core_theme;

class ApexNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final String severity;   // 'info' | 'success' | 'warning' | 'error'
  final VoidCallback? onTap;

  const ApexNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.severity = 'info',
    this.onTap,
  });
}

class ApexNotificationBell extends StatefulWidget {
  final List<ApexNotification> notifications;
  final void Function(String id)? onMarkRead;
  final VoidCallback? onMarkAllRead;
  final VoidCallback? onSeeAll;

  const ApexNotificationBell({
    super.key,
    required this.notifications,
    this.onMarkRead,
    this.onMarkAllRead,
    this.onSeeAll,
  });

  @override
  State<ApexNotificationBell> createState() => _ApexNotificationBellState();
}

class _ApexNotificationBellState extends State<ApexNotificationBell> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  int get _unreadCount => widget.notifications.where((n) => !n.read).length;

  void _toggle() {
    if (_overlay != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _overlay = OverlayEntry(builder: _buildDropdown);
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: AC.ts),
            tooltip: 'الإشعارات${unread > 0 ? ' ($unread)' : ''}',
            onPressed: _toggle,
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: AC.err,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  unread > 99 ? '99+' : unread.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext overlayContext) {
    return Stack(
      children: [
        // Dismiss overlay by tapping outside.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(-340, 48),
          showWhenUnlinked: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 380,
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                color: AC.navy2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AC.navy4),
                boxShadow: [
                  BoxShadow(
                    color: core_theme.AC.tp.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  const Divider(height: 1),
                  Flexible(
                    child: widget.notifications.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.notifications.length,
                            itemBuilder: (_, i) => _row(widget.notifications[i]),
                          ),
                  ),
                  if (widget.onSeeAll != null) _footer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Text(
            'الإشعارات',
            style: TextStyle(
              color: AC.tp,
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_unreadCount > 0 && widget.onMarkAllRead != null)
            TextButton(
              onPressed: widget.onMarkAllRead,
              child: Text(
                'تعليم الكل كمقروءة',
                style: TextStyle(color: AC.gold, fontSize: AppFontSize.sm),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AC.td),
          const SizedBox(height: AppSpacing.md),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.lg),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String s) => switch (s) {
        'success' => AC.ok,
        'warning' => AC.warn,
        'error' => AC.err,
        _ => AC.cyan,
      };

  Widget _row(ApexNotification n) {
    final sevColor = _severityColor(n.severity);
    return InkWell(
      onTap: () {
        widget.onMarkRead?.call(n.id);
        n.onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: n.read ? null : AC.gold.withValues(alpha: 0.05),
          border: Border(bottom: BorderSide(color: AC.navy4.withValues(alpha: 0.3))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: sevColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            color: AC.tp,
                            fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _fmtRelative(n.timestamp),
                        style: TextStyle(color: AC.td, fontSize: AppFontSize.sm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return InkWell(
      onTap: () {
        _close();
        widget.onSeeAll!();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
          ),
        ),
        child: Center(
          child: Text(
            'عرض الكل',
            style: TextStyle(
              color: AC.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _fmtRelative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} د';
    if (diff.inHours < 24) return '${diff.inHours} س';
    return '${diff.inDays} يوم';
  }
}
