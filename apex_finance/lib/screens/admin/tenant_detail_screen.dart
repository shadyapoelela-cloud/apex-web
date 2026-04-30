/// APEX — Tenant Detail Page
/// /admin/tenants/{tenant_id} — comprehensive overview of a single tenant
/// pulling from every per-tenant subsystem: industry pack assignment,
/// workflow rules + recent runs, approvals breakdown, period locks,
/// period close cycles, bank feeds, anomaly buffer, custom roles, and
/// recent event-bus traffic filtered to this tenant.
///
/// Wired to Wave 1Y Phase FFF backend:
///   GET /admin/tenants/{tenant_id}/overview
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class TenantDetailScreen extends StatefulWidget {
  final String tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});
  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;

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
          controller: ctrl, obscureText: true, autofocus: true,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'X-Admin-Secret',
            labelStyle: TextStyle(color: AC.ts),
            filled: true, fillColor: AC.navy3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null),
              child: Text('إلغاء', style: TextStyle(color: AC.ts))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (secret != null && secret.isNotEmpty) ApiService.adminSecret = secret;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ApiService.tenantOverview(widget.tenantId);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _overview = Map<String, dynamic>.from(r.data as Map);
    } else {
      _error = r.error ?? 'تعذّر التحميل';
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'تفاصيل المستأجر · ${widget.tenantId}',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'الدليل',
              icon: Icons.list_alt,
              onPressed: () => GoRouter.of(context).go('/admin/tenants'),
            ),
          ],
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, color: AC.err, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AC.err)),
          ]),
        ),
      );
    }
    if (_overview == null) return const SizedBox.shrink();
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
            _kpiGrid(),
            const SizedBox(height: AppSpacing.md),
            _industryPackCard(),
            const SizedBox(height: AppSpacing.md),
            _eventsCard(),
            const SizedBox(height: AppSpacing.md),
            _runsCard(),
            const SizedBox(height: AppSpacing.md),
            _quickLinks(),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final tenant = (_overview!['tenant'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = tenant['display_name']?.toString() ?? '—';
    final status = tenant['status']?.toString() ?? 'active';
    final color = status == 'active' ? AC.ok : AC.ts;
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.business, color: AC.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: AppFontSize.xl,
                  )),
              Text('tenant_id: ${widget.tenantId}',
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  )),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              status == 'active' ? 'فعّال' : 'متوقّف',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        if ((tenant['notes'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(tenant['notes'].toString(), style: TextStyle(color: AC.ts, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _meta('أُنشئ: ${(tenant['created_at'] ?? '').toString().substring(0, 10)}', AC.ts),
          if (tenant['created_by'] != null) _meta('بواسطة: ${tenant['created_by']}', AC.cyan),
          if (tenant['industry_pack_id'] != null)
            _meta('pack: ${tenant['industry_pack_id']}', AC.warn),
        ]),
      ]),
    );
  }

  Widget _kpiGrid() {
    final wf = (_overview!['workflow'] as Map?) ?? {};
    final ap = (_overview!['approvals'] as Map?) ?? {};
    final apState = (ap['by_state'] as Map?) ?? {};
    final pl = (_overview!['period_locks'] as Map?) ?? {};
    final pc = (_overview!['period_close'] as Map?) ?? {};
    final pcState = (pc['by_status'] as Map?) ?? {};
    final bf = (_overview!['bank_feeds'] as Map?) ?? {};
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 600 ? 2 : 1);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: [
          _kpiCard(
            title: 'قواعد الأتمتة',
            icon: Icons.auto_awesome_motion,
            color: AC.cyan,
            stats: [
              ('إجمالي', wf['rules_total']?.toString() ?? '0', AC.tp),
              ('فعّالة', wf['rules_enabled']?.toString() ?? '0', AC.ok),
              ('تشغيلات', wf['total_runs']?.toString() ?? '0', AC.warn),
              if ((wf['rules_with_errors'] ?? 0) > 0)
                ('بأخطاء', wf['rules_with_errors'].toString(), AC.err),
            ],
            route: '/admin/workflow/rules?tenant_id=${widget.tenantId}',
          ),
          _kpiCard(
            title: 'الموافقات',
            icon: Icons.task_alt,
            color: AC.gold,
            stats: [
              ('إجمالي', ap['total']?.toString() ?? '0', AC.tp),
              ('انتظار', apState['pending']?.toString() ?? '0', AC.warn),
              ('مُعتمدة', apState['approved']?.toString() ?? '0', AC.ok),
              ('مرفوضة', apState['rejected']?.toString() ?? '0', AC.err),
            ],
            route: '/admin/approvals?tenant_id=${widget.tenantId}',
          ),
          _kpiCard(
            title: 'إقفال الفترات',
            icon: Icons.lock,
            color: AC.warn,
            stats: [
              ('إقفالات', pl['total']?.toString() ?? '0', AC.tp),
              ('نشطة', pl['active']?.toString() ?? '0', AC.warn),
              ('دورات', pc['total']?.toString() ?? '0', AC.cyan),
              ('مكتملة', pcState['completed']?.toString() ?? '0', AC.ok),
            ],
            route: '/admin/period-locks',
          ),
          _kpiCard(
            title: 'البنك',
            icon: Icons.account_balance,
            color: AC.tp,
            stats: [
              ('اتصالات', bf['connections']?.toString() ?? '0', AC.cyan),
              ('معاملات', bf['transactions']?.toString() ?? '0', AC.tp),
              ('مطابَقة', bf['reconciled']?.toString() ?? '0', AC.ok),
              ('شذوذ buf',
                  (_overview!['anomaly_buffer_size'] ?? 0).toString(), AC.warn),
            ],
            route: '/admin/bank-feeds',
          ),
        ],
      );
    });
  }

  Widget _kpiCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<(String, String, Color)> stats,
    required String route,
  }) {
    return InkWell(
      onTap: () => GoRouter.of(context).go(route),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    color: AC.tp,
                    fontWeight: FontWeight.bold,
                    fontSize: AppFontSize.md,
                  )),
            ),
            Icon(Icons.chevron_left, color: AC.ts, size: 14),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (label, value, c) in stats) _statChip(label, value, c),
          ]),
        ]),
      ),
    );
  }

  Widget _statChip(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 10)),
          Text(value,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 11,
              )),
        ]),
      );

  Widget _industryPackCard() {
    final pack = _overview!['industry_pack'] as Map?;
    if (pack == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          Icon(Icons.business_center, color: AC.ts, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('لم يُطبَّق أيّ pack بعد',
                style: TextStyle(color: AC.ts, fontSize: 12)),
          ),
          OutlinedButton(
            onPressed: () => GoRouter.of(context).go('/admin/industry-packs'),
            child: const Text('تطبيق الآن'),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.business_center, color: AC.gold, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              pack['pack_name_ar']?.toString() ?? pack['pack_id']?.toString() ?? '',
              style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (pack['coa_seeded'] == true) _meta('COA ✓', AC.ok),
              if (pack['widgets_provisioned'] == true) _meta('widgets ✓', AC.ok),
              if (pack['applied_at'] != null)
                _meta(pack['applied_at'].toString().substring(0, 10), AC.ts),
            ]),
          ]),
        ),
        OutlinedButton(
          onPressed: () => GoRouter.of(context).go('/admin/industry-packs'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AC.gold),
            foregroundColor: AC.gold,
          ),
          child: const Text('إدارة'),
        ),
      ]),
    );
  }

  Widget _eventsCard() {
    final events =
        ((_overview!['recent_events'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timeline, color: AC.cyan, size: 18),
          const SizedBox(width: 6),
          Text('أحدث ${events.length} حدث',
              style: TextStyle(
                  color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => GoRouter.of(context).go('/admin/events'),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('كل الأحداث'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.bdr),
              foregroundColor: AC.tp,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('لا أحداث لهذا المستأجر بعد',
                style: TextStyle(color: AC.ts, fontSize: 12)),
          )
        else
          ...events.take(15).map(_eventRow),
      ]),
    );
  }

  Widget _eventRow(Map<String, dynamic> e) {
    final name = e['name']?.toString() ?? '';
    final ts = e['ts']?.toString() ?? '';
    final ns = name.split('.').first;
    final color = switch (ns) {
      'tenant' => AC.gold,
      'industry_pack' => AC.warn,
      'workflow' => AC.cyan,
      'approval' => AC.tp,
      'comment' => AC.ok,
      'anomaly' => AC.err,
      _ => AC.ts,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 11,
              )),
        ),
        Text(ts.length >= 19 ? ts.substring(11, 19) : ts,
            style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _runsCard() {
    final runs =
        ((_overview!['recent_runs'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    if (runs.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history, color: AC.cyan, size: 18),
          const SizedBox(width: 6),
          Text('أحدث ${runs.length} تنفيذ',
              style: TextStyle(
                  color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => GoRouter.of(context).go('/admin/workflow/runs'),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('السجلّ الكامل'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.bdr),
              foregroundColor: AC.tp,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ...runs.take(10).map(_runRow),
      ]),
    );
  }

  Widget _runRow(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    final color = switch (status) {
      'success' => AC.ok,
      'partial' => AC.warn,
      'failed' => AC.err,
      _ => AC.tp,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            status,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            r['rule_name']?.toString() ?? '',
            style: TextStyle(color: AC.tp, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text('${r['duration_ms'] ?? 0}ms',
            style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace')),
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
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _link('قواعده', Icons.auto_awesome_motion,
              '/admin/workflow/rules?tenant_id=${widget.tenantId}'),
          _link('موافقاته', Icons.task_alt,
              '/admin/approvals?tenant_id=${widget.tenantId}'),
          _link('قواعده على Run History', Icons.history, '/admin/workflow/runs'),
          _link('إقفال الفترات', Icons.lock, '/admin/period-locks'),
          _link('دورات الإقفال', Icons.event_note, '/admin/period-close'),
          _link('الأدوار', Icons.shield, '/admin/roles'),
          _link('Bank Feeds', Icons.account_balance, '/admin/bank-feeds'),
          _link('قوالب الموافقات', Icons.task, '/admin/approval-templates'),
        ]),
      ]),
    );
  }

  Widget _link(String label, IconData icon, String route) {
    return OutlinedButton.icon(
      onPressed: () => GoRouter.of(context).go(route),
      icon: Icon(icon, size: 14, color: AC.cyan),
      label: Text(label, style: TextStyle(color: AC.tp, fontSize: 11)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AC.bdr),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
}
