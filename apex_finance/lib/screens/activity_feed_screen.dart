/// APEX — Activity Feed
/// /activity — per-user "what's happening in my world" timeline.
///
/// Wired to Wave 1P Phase WW backend:
///   GET  /api/v1/activity?user_id=&tenant_id=&only_unread=&limit=&offset=
///   POST /api/v1/activity/mark-read?user_id=&tenant_id=
///
/// Unlike the admin Events Browser (raw events / JSON), this is the
/// user-facing feed: human-readable titles ("ذُكرت في تعليق", "تم
/// منحك دور Reviewer"), action_url click-routing, severity-coded
/// icons, and a read-cursor for unread badging.
///
/// Visible to ALL roles (no _adminOnly gate).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_service.dart';
import '../core/apex_sticky_toolbar.dart';
import '../core/design_tokens.dart';
import '../core/session.dart';
import '../core/theme.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});
  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = [];
  String? _lastReadAt;
  int _totalUnread = 0;
  bool _onlyUnread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _userId => S.uid;
  String? get _tenantId => S.tenantId ?? S.savedTenantId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'سجّل الدخول أولاً لرؤية تيار النشاط';
      });
      return;
    }
    final r = await ApiService.activityList(
      userId: _userId!,
      tenantId: _tenantId,
      onlyUnread: _onlyUnread,
      limit: 100,
    );
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _entries = ((r.data['entries'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _lastReadAt = r.data['last_read_at']?.toString();
      _totalUnread = (r.data['unread_count'] as int?) ?? 0;
    } else {
      _error = r.error ?? 'تعذّر تحميل التيار';
    }
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    if (_userId == null) return;
    final r = await ApiService.activityMarkRead(
      userId: _userId!,
      tenantId: _tenantId,
    );
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.ok,
          content: Text('تمّت قراءة الكل', style: TextStyle(color: AC.tp)),
        ),
      );
      await _load();
    }
  }

  bool _isUnread(Map<String, dynamic> e) {
    if (_lastReadAt == null) return true;
    final created = e['created_at']?.toString() ?? '';
    return created.compareTo(_lastReadAt!) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'تيار نشاطي',
          actions: [
            ApexToolbarAction(
              label: _onlyUnread ? 'الكل' : 'الجديد فقط',
              icon: _onlyUnread ? Icons.list : Icons.fiber_new,
              onPressed: () {
                setState(() => _onlyUnread = !_onlyUnread);
                _load();
              },
            ),
            if (_totalUnread > 0)
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
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AC.warn.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AC.warn),
                ),
                child: Text(_error!, style: TextStyle(color: AC.warn)),
              )
            else if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.inbox_outlined, color: AC.ts, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    _onlyUnread
                        ? 'لا توجد عناصر جديدة'
                        : 'لا يوجد نشاط بعد — ستظهر التنبيهات هنا',
                    style: TextStyle(color: AC.ts, fontSize: 13),
                  ),
                ]),
              )
            else
              ..._groupByDay().entries.map((g) => _daySection(g.key, g.value)),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final color = _totalUnread > 0 ? AC.gold : AC.ok;
    return Container(
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
          _totalUnread > 0 ? Icons.notifications_active : Icons.notifications_none,
          color: color,
          size: 36,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _totalUnread > 0
                  ? '$_totalUnread عنصر جديد'
                  : 'لا توجد عناصر جديدة',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: AppFontSize.xl,
              ),
            ),
            Text(
              'إجمالي: ${_entries.length}${_userId != null ? " · المستخدم: $_userId" : ""}',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDay() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in _entries) {
      final created = e['created_at']?.toString() ?? '';
      final day = created.length >= 10 ? created.substring(0, 10) : '—';
      groups.putIfAbsent(day, () => []).add(e);
    }
    return groups;
  }

  Widget _daySection(String day, List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: AC.gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              _humanDay(day),
              style: TextStyle(
                color: AC.gold,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ]),
        ),
        for (final e in items) _entryCard(e),
      ]),
    );
  }

  String _humanDay(String iso) {
    if (iso == '—') return '—';
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (iso == today) return 'اليوم';
      final date = DateTime.parse(iso);
      final diff = DateTime.now().difference(date).inDays;
      if (diff == 1) return 'أمس';
      if (diff < 7) return 'منذ $diff أيام';
      return iso;
    } catch (_) {
      return iso;
    }
  }

  Widget _entryCard(Map<String, dynamic> e) {
    final unread = _isUnread(e);
    final sev = (e['severity'] ?? 'info').toString();
    final color = switch (sev) {
      'success' => AC.ok,
      'warning' => AC.warn,
      'error' => AC.err,
      _ => AC.cyan,
    };
    final actionUrl = e['action_url']?.toString();
    final clickable = actionUrl != null && actionUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: unread ? color.withValues(alpha: 0.55) : AC.bdr,
          width: unread ? 1.5 : 1,
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
              child: Icon(_iconFor(e['icon']?.toString()), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      e['title_ar']?.toString() ?? '—',
                      style: TextStyle(
                        color: AC.tp,
                        fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ]),
                if ((e['body_ar'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    e['body_ar'].toString(),
                    style: TextStyle(color: AC.ts, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _meta(e['event_name']?.toString() ?? '', AC.cyan),
                  if (e['actor_user_id'] != null)
                    _meta('من: ${e['actor_user_id']}', AC.gold),
                  _meta(_relTime(e['created_at']?.toString() ?? ''), AC.ts),
                  if (clickable)
                    _meta('▸ ${e['action_url']}', AC.warn),
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
        child: Text(
          label,
          style: TextStyle(color: c, fontSize: 10, fontFamily: 'monospace'),
        ),
      );

  IconData _iconFor(String? name) {
    return switch (name) {
      'alternate_email' => Icons.alternate_email,
      'task_alt' => Icons.task_alt,
      'check_circle' => Icons.check_circle,
      'cancel' => Icons.cancel,
      'shield' => Icons.shield,
      'remove_circle' => Icons.remove_circle,
      _ => Icons.info_outline,
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
