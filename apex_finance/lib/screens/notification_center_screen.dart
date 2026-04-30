/// APEX — Notification Center (Unified Inbox)
/// /inbox — aggregates 4 user-facing sources into a single timeline:
///   1. Activity Feed (Wave 1P) — mentions, role changes, decided approvals
///   2. Pending Approvals (Wave 1B) — where the user is approver
///   3. Proactive Suggestions (Wave 1G) — admin-only, gated by role
///   4. System notifications (Phase 10 if available)
///
/// Wired to Wave 1X Phase EEE backend:
///   GET  /api/v1/inbox?user_id=&tenant_id=&sources=&only_unread=
///   POST /api/v1/inbox/mark-all-read?user_id=&tenant_id=
///
/// Visible to ALL roles. Source filter chips + unread toggle + "تحديد
/// الكل كمقروء" sync the activity feed cursor too.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_service.dart';
import '../core/apex_sticky_toolbar.dart';
import '../core/design_tokens.dart';
import '../core/session.dart';
import '../core/theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _bySource = const {};
  int _unreadCount = 0;
  bool _onlyUnread = false;
  String _filterSource = 'all';

  static const _sourceLabels = {
    'all': 'الكل',
    'activity': 'النشاط',
    'approval': 'الموافقات',
    'suggestion': 'الاقتراحات',
    'system': 'النظام',
  };

  static const _sourceIcons = {
    'activity': Icons.timeline,
    'approval': Icons.task_alt,
    'suggestion': Icons.lightbulb,
    'system': Icons.notifications,
  };

  String? get _userId => S.uid;
  String? get _tenantId => S.tenantId ?? S.savedTenantId;
  List<String> get _userRoles => S.roles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'سجّل الدخول أوّلاً لرؤية الإشعارات';
      });
      return;
    }
    final sources = _filterSource == 'all' ? null : [_filterSource];
    final r = await ApiService.inboxList(
      userId: _userId!,
      tenantId: _tenantId,
      sources: sources,
      onlyUnread: _onlyUnread,
      limit: 300,
      userRoles: _userRoles,
    );
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _items = ((r.data['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _bySource = Map<String, dynamic>.from(r.data['by_source'] as Map? ?? {});
      _unreadCount = (r.data['unread_count'] as int?) ?? 0;
    } else {
      _error = r.error ?? 'تعذّر التحميل';
    }
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    if (_userId == null) return;
    final r = await ApiService.inboxMarkAllRead(
      userId: _userId!,
      tenantId: _tenantId,
    );
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text('تمّت قراءة الكل', style: TextStyle(color: AC.tp)),
      ));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'صندوق الإشعارات',
          actions: [
            ApexToolbarAction(
              label: _onlyUnread ? 'الكل' : 'الجديد فقط',
              icon: _onlyUnread ? Icons.list : Icons.fiber_new,
              onPressed: () {
                setState(() => _onlyUnread = !_onlyUnread);
                _load();
              },
            ),
            if (_unreadCount > 0)
              ApexToolbarAction(
                label: 'تحديد الكل كمقروء',
                icon: Icons.mark_email_read,
                onPressed: _markAllRead,
              ),
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
          ],
        ),
        _hero(),
        _filterBar(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _hero() {
    final color = _unreadCount > 0 ? AC.gold : AC.ok;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), AC.navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(
          _unreadCount > 0
              ? Icons.notifications_active
              : Icons.notifications_none,
          color: color,
          size: 36,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _unreadCount > 0
                  ? '$_unreadCount عنصر جديد بانتظارك'
                  : 'لا توجد عناصر جديدة',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: AppFontSize.xl,
              ),
            ),
            Text(
              'إجمالي: ${_items.length} · ${_bySourceSummary()}',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }

  String _bySourceSummary() {
    if (_bySource.isEmpty) return 'لا مصادر نشطة';
    return _bySource.entries
        .map((e) => '${_sourceLabels[e.key] ?? e.key}: ${e.value}')
        .join(' · ');
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      child: Wrap(spacing: 6, children: [
        for (final s in const ['all', 'activity', 'approval', 'suggestion', 'system'])
          ChoiceChip(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              if (s != 'all') ...[
                Icon(_sourceIcons[s], size: 14,
                    color: _filterSource == s ? AC.gold : AC.ts),
                const SizedBox(width: 4),
              ],
              Text(_sourceLabels[s]!),
            ]),
            selected: _filterSource == s,
            selectedColor: AC.gold.withValues(alpha: 0.3),
            backgroundColor: AC.navy3,
            labelStyle: TextStyle(
              color: _filterSource == s ? AC.gold : AC.ts,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() => _filterSource = s);
              _load();
            },
          ),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.warn)),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, color: AC.ts, size: 56),
            const SizedBox(height: 12),
            Text(
              _onlyUnread ? 'لا توجد عناصر جديدة' : 'صندوق الإشعارات فارغ',
              style: TextStyle(color: AC.ts, fontSize: 13),
            ),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        itemCount: _items.length,
        itemBuilder: (ctx, i) => _itemCard(_items[i]),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final source = (item['source'] ?? '').toString();
    final sev = (item['severity'] ?? 'info').toString();
    final isUnread = item['is_unread'] == true;
    final color = switch (sev) {
      'success' => AC.ok,
      'warning' => AC.warn,
      'error' => AC.err,
      _ => AC.cyan,
    };
    final actionUrl = item['action_url']?.toString();
    final clickable = actionUrl != null && actionUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isUnread ? color.withValues(alpha: 0.55) : AC.bdr,
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: clickable ? () => GoRouter.of(context).go(actionUrl) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(source, item['icon']?.toString()),
                  color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _sourceLabels[source] ?? source,
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['title_ar']?.toString() ?? '',
                      style: TextStyle(
                        color: AC.tp,
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ]),
                if ((item['body_ar'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['body_ar'].toString(),
                    style: TextStyle(color: AC.ts, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _meta(_relTime(item['ts']?.toString() ?? ''), AC.ts),
                  if (item['actor_user_id'] != null)
                    _meta('من: ${item['actor_user_id']}', AC.gold),
                  if (clickable)
                    _meta('▸ ${item['action_url']}', AC.cyan),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _meta(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(label,
            style: TextStyle(color: c, fontSize: 10, fontFamily: 'monospace')),
      );

  IconData _iconFor(String source, String? raw) {
    return switch (raw) {
      'task_alt' => Icons.task_alt,
      'lightbulb' => Icons.lightbulb,
      'alternate_email' => Icons.alternate_email,
      'check_circle' => Icons.check_circle,
      'cancel' => Icons.cancel,
      'shield' => Icons.shield,
      'remove_circle' => Icons.remove_circle,
      _ => _sourceIcons[source] ?? Icons.info_outline,
    };
  }

  String _relTime(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes}د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours}س';
      return 'منذ ${diff.inDays}ي';
    } catch (_) {
      return iso;
    }
  }
}
