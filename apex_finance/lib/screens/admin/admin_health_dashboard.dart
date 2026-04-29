/// APEX — Admin Health Dashboard
/// /admin/dashboard-health — combined view of every Wave 1A-1H subsystem.
///
/// Aggregates:
///   • Workflow Engine stats   (rules total/enabled/disabled)
///   • Approvals stats          (by_state)
///   • Webhooks stats           (subscriptions + delivery counts)
///   • API Keys stats           (active / revoked)
///   • Modules stats            (tenants_with_overrides + adoption)
///   • Comments stats           (by_object_type)
///   • Suggestions stats        (by_status)
///   • Recent events            (live tick rate)
///
/// Single screen for the admin to know "is APEX healthy?" at a glance.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class AdminHealthDashboard extends StatefulWidget {
  const AdminHealthDashboard({super.key});
  @override
  State<AdminHealthDashboard> createState() => _AdminHealthDashboardState();
}

class _AdminHealthDashboardState extends State<AdminHealthDashboard> {
  bool _loading = true;
  String? _error;

  // Subsystem stats payloads
  Map<String, dynamic>? _workflow;
  Map<String, dynamic>? _webhooks;
  Map<String, dynamic>? _apiKeys;
  Map<String, dynamic>? _modules;
  Map<String, dynamic>? _suggestions;
  int _recentEventsCount = 0;

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  Future<void> _ensureSecretThenLoad() async {
    if (!ApiService.hasAdminSecret) {
      await _promptSecret();
    }
    await _load();
  }

  Future<void> _promptSecret() async {
    final ctrl = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('سرّ المسؤول مطلوب', style: TextStyle(color: AC.tp)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'X-Admin-Secret',
            labelStyle: TextStyle(color: AC.ts),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (secret != null && secret.isNotEmpty) {
      ApiService.adminSecret = secret;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.workflowStats(),
      ApiService.webhooksStats(),
      ApiService.apiKeysStats(),
      ApiService.modulesStats(),
      ApiService.suggestionsStats(),
      ApiService.eventsRecent(limit: 100),
    ]);
    if (!mounted) return;
    if (results[0].success) _workflow = _asMap(results[0].data);
    if (results[1].success) _webhooks = _asMap(results[1].data);
    if (results[2].success) _apiKeys = _asMap(results[2].data);
    if (results[3].success) _modules = _asMap(results[3].data);
    if (results[4].success) _suggestions = _asMap(results[4].data);
    if (results[5].success) {
      final raw = (results[5].data is Map ? results[5].data['events'] : null) ?? const [];
      _recentEventsCount = (raw as List).length;
    }
    final anyFailed = results.any((r) => !r.success);
    if (anyFailed && _workflow == null && _webhooks == null) {
      _error = 'فشل تحميل بعض الإحصائيات — تحقق من X-Admin-Secret';
    }
    setState(() => _loading = false);
  }

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : (data is Map ? Map<String, dynamic>.from(data) : null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'لوحة صحة المنصة',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroBanner(),
            const SizedBox(height: AppSpacing.lg),
            _row([
              _workflowCard(),
              _approvalsCard(),
              _webhooksCard(),
            ]),
            const SizedBox(height: AppSpacing.md),
            _row([
              _apiKeysCard(),
              _modulesCard(),
              _suggestionsCard(),
            ]),
            const SizedBox(height: AppSpacing.md),
            _row([_eventsCard()]),
            const SizedBox(height: AppSpacing.lg),
            _quickLinks(),
          ],
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 720;
      if (wide) {
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    });
  }

  Widget _heroBanner() {
    final activeRules = _workflow?['rules_enabled'] ?? 0;
    final liveSubs = _webhooks?['subscriptions_enabled'] ?? 0;
    final pendingSugg = (_suggestions?['by_status'] as Map?)?['proposed'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AC.gold.withValues(alpha: 0.18), AC.navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.health_and_safety, color: AC.gold, size: 28),
            const SizedBox(width: 10),
            Text(
              'صحة المنصة',
              style: TextStyle(
                color: AC.gold,
                fontWeight: FontWeight.w900,
                fontSize: AppFontSize.xl,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _heroFact('قواعد أتمتة فعّالة', activeRules.toString(), AC.cyan),
            _heroFact('اشتراكات Webhooks', liveSubs.toString(), AC.warn),
            _heroFact('اقتراحات جديدة', pendingSugg.toString(), AC.ok),
            _heroFact('أحداث في الذاكرة', '$_recentEventsCount / 200', AC.tp),
          ]),
        ],
      ),
    );
  }

  Widget _heroFact(String label, String value, Color c) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$label:',
        style: TextStyle(color: AC.ts, fontSize: 11),
      ),
      const SizedBox(width: 4),
      Text(
        value,
        style: TextStyle(
          color: c,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    ]);
  }

  Widget _kpiCard({
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required Widget body,
  }) {
    return InkWell(
      onTap: () => GoRouter.of(context).go(route),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.md,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_left, color: AC.ts, size: 16),
            ]),
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        ),
      ),
    );
  }

  Widget _workflowCard() {
    final s = _workflow ?? const {};
    return _kpiCard(
      title: 'محرّك الأتمتة',
      icon: Icons.auto_awesome_motion,
      color: AC.cyan,
      route: '/admin/workflow/rules',
      body: Wrap(spacing: 6, runSpacing: 6, children: [
        _stat('إجمالي', s['rules_total']?.toString() ?? '–', AC.tp),
        _stat('فعّالة', s['rules_enabled']?.toString() ?? '–', AC.ok),
        _stat('متوقّفة', s['rules_disabled']?.toString() ?? '–', AC.warn),
      ]),
    );
  }

  Widget _approvalsCard() {
    return _kpiCard(
      title: 'سلاسل الموافقات',
      icon: Icons.task_alt,
      color: AC.gold,
      route: '/admin/approvals',
      body: Text(
        'إدارة + إحصائيات حسب الحالة',
        style: TextStyle(color: AC.ts, fontSize: 12),
      ),
    );
  }

  Widget _webhooksCard() {
    final s = _webhooks ?? const {};
    return _kpiCard(
      title: 'اشتراكات Webhooks',
      icon: Icons.webhook,
      color: AC.warn,
      route: '/admin/webhooks',
      body: Wrap(spacing: 6, runSpacing: 6, children: [
        _stat('إجمالي', s['subscriptions_total']?.toString() ?? '–', AC.tp),
        _stat('فعّال', s['subscriptions_enabled']?.toString() ?? '–', AC.ok),
        _stat('إيقاف', s['subscriptions_paused']?.toString() ?? '–', AC.warn),
        _stat('تسليمات', s['deliveries_total']?.toString() ?? '–', AC.cyan),
        _stat('فشل', s['deliveries_failed']?.toString() ?? '–', AC.err),
      ]),
    );
  }

  Widget _apiKeysCard() {
    final s = _apiKeys ?? const {};
    return _kpiCard(
      title: 'مفاتيح API',
      icon: Icons.vpn_key,
      color: AC.gold,
      route: '/admin/api-keys',
      body: Wrap(spacing: 6, runSpacing: 6, children: [
        _stat('إجمالي', s['keys_total']?.toString() ?? '–', AC.tp),
        _stat('فعّال', s['keys_active']?.toString() ?? '–', AC.ok),
        _stat('مُلغى', s['keys_revoked']?.toString() ?? '–', AC.err),
      ]),
    );
  }

  Widget _modulesCard() {
    final s = _modules ?? const {};
    return _kpiCard(
      title: 'الوحدات',
      icon: Icons.extension,
      color: AC.cyan,
      route: '/admin/modules',
      body: Wrap(spacing: 6, runSpacing: 6, children: [
        _stat('إجمالي', s['modules_total']?.toString() ?? '–', AC.tp),
        _stat(
          'مستأجرون مُخصّصون',
          s['tenants_with_overrides']?.toString() ?? '–',
          AC.cyan,
        ),
      ]),
    );
  }

  Widget _suggestionsCard() {
    final s = _suggestions ?? const {};
    final by = (s['by_status'] as Map?) ?? const {};
    return _kpiCard(
      title: 'اقتراحات المنصة',
      icon: Icons.tips_and_updates,
      color: AC.ok,
      route: '/admin/suggestions',
      body: Wrap(spacing: 6, runSpacing: 6, children: [
        _stat('مقترحة', by['proposed']?.toString() ?? '–', AC.ok),
        _stat('مُطبَّقة', by['applied']?.toString() ?? '–', AC.cyan),
        _stat('مُتجاهَلة', by['dismissed']?.toString() ?? '–', AC.ts),
      ]),
    );
  }

  Widget _eventsCard() {
    return _kpiCard(
      title: 'مراقب الأحداث (Live)',
      icon: Icons.timeline,
      color: AC.tp,
      route: '/admin/events',
      body: Row(children: [
        Icon(Icons.bolt, color: AC.warn, size: 14),
        const SizedBox(width: 4),
        Text(
          '$_recentEventsCount حدث في آخر 200 — انقر للمراقبة الحيّة',
          style: TextStyle(color: AC.ts, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
        Text(value,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            )),
      ]),
    );
  }

  Widget _quickLinks() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('روابط سريعة',
            style: TextStyle(
                color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _link('قوالب الأتمتة', Icons.auto_awesome, '/admin/workflow/templates'),
          _link('إدارة الوحدات', Icons.extension, '/admin/modules'),
          _link('Webhooks', Icons.webhook, '/admin/webhooks'),
          _link('مفاتيح API', Icons.vpn_key, '/admin/api-keys'),
          _link('الأدوار', Icons.shield, '/admin/roles'),
          _link('الاقتراحات', Icons.tips_and_updates, '/admin/suggestions'),
          _link('الأحداث', Icons.timeline, '/admin/events'),
          _link('الموافقات', Icons.task_alt, '/admin/approvals'),
          _link('الشذوذ الحيّ', Icons.radar, '/admin/anomaly'),
          _link('بريد الفواتير', Icons.mark_email_unread, '/admin/email-inbox'),
          _link('حزم القطاعات', Icons.business_center, '/admin/industry-packs'),
        ]),
      ]),
    );
  }

  Widget _link(String label, IconData icon, String route) {
    return OutlinedButton.icon(
      onPressed: () => GoRouter.of(context).go(route),
      icon: Icon(icon, size: 14, color: AC.cyan),
      label: Text(label, style: TextStyle(color: AC.tp, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AC.bdr),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
