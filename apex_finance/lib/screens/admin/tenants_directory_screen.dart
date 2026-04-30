/// APEX — Tenant Directory Screen
/// /admin/tenants — list of onboarded tenants + activate/deactivate
/// + delete + entry to the onboarding wizard.
///
/// Wired to Wave 1N Phase TT backend:
///   GET    /api/v1/tenants?status=
///   GET    /admin/tenants/stats
///   POST   /admin/tenants/{id}/deactivate
///   POST   /admin/tenants/{id}/activate
///   DELETE /admin/tenants/{id}
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class TenantsDirectoryScreen extends StatefulWidget {
  const TenantsDirectoryScreen({super.key});
  @override
  State<TenantsDirectoryScreen> createState() => _TenantsDirectoryScreenState();
}

class _TenantsDirectoryScreenState extends State<TenantsDirectoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tenants = [];
  Map<String, dynamic> _stats = const {};
  String _status = 'all';

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
    final r = await Future.wait([
      ApiService.tenantsList(status: _status == 'all' ? null : _status),
      ApiService.tenantsStats(),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) {
      _tenants = ((r[0].data['tenants'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r[0].error ?? 'تعذّر تحميل القائمة';
    }
    if (r[1].success && r[1].data is Map) {
      _stats = Map<String, dynamic>.from(r[1].data as Map);
    }
    setState(() => _loading = false);
  }

  Future<void> _deactivate(String tenantId) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('تعطيل المستأجر', style: TextStyle(color: AC.tp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم تعطيل $tenantId. بياناته في باقي الأنظمة لن تُلمس.',
              style: TextStyle(color: AC.ts),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: TextStyle(color: AC.tp),
              decoration: InputDecoration(
                labelText: 'السبب (اختياري)',
                labelStyle: TextStyle(color: AC.ts),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.warn),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعطيل'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.tenantDeactivate(
      tenantId,
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    if (r.success) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(r.error ?? 'فشل')),
      );
    }
  }

  Future<void> _activate(String tenantId) async {
    final r = await ApiService.tenantActivate(tenantId);
    if (!mounted) return;
    if (r.success) await _load();
  }

  Future<void> _delete(String tenantId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف من الدليل', style: TextStyle(color: AC.tp)),
        content: Text(
          'سيُحذف $tenantId من الدليل فقط. الحزمة المُطبَّقة + قواعد الأتمتة + بقية البيانات تبقى. للحذف الكامل عطّله أولاً ثم احذف من كل نظام.',
          style: TextStyle(color: AC.ts),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.tenantDelete(tenantId);
    if (!mounted) return;
    if (r.success) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'دليل المستأجرين',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'استقبال جديد',
              icon: Icons.add_circle,
              onPressed: () => GoRouter.of(context).go('/admin/tenant-onboarding'),
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
            _statsBar(),
            const SizedBox(height: AppSpacing.md),
            _filters(),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AC.err.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AC.err),
                ),
                child: Text(_error!, style: TextStyle(color: AC.err)),
              ),
            if (_tenants.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.business_outlined, size: 56, color: AC.ts),
                  const SizedBox(height: 12),
                  Text('لا يوجد مستأجرون مسجَّلون',
                      style: TextStyle(color: AC.ts, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        GoRouter.of(context).go('/admin/tenant-onboarding'),
                    icon: const Icon(Icons.add),
                    label: const Text('استقبال أول مستأجر'),
                  ),
                ]),
              )
            else
              ..._tenants.map(_tenantCard),
          ],
        ),
      ),
    );
  }

  Widget _statsBar() {
    final total = _stats['total'] ?? 0;
    final byStatus = (_stats['by_status'] as Map?) ?? const {};
    final byPack = (_stats['by_pack'] as Map?) ?? const {};
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Wrap(spacing: 12, runSpacing: 8, children: [
        _stat('الإجمالي', total.toString(), AC.tp),
        _stat('فعّال', byStatus['active']?.toString() ?? '0', AC.ok),
        _stat('متوقّف', byStatus['inactive']?.toString() ?? '0', AC.ts),
        for (final e in byPack.entries)
          _stat(e.key.toString(), e.value.toString(), AC.gold),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      ]),
    );
  }

  Widget _filters() {
    return Wrap(spacing: 6, children: [
      for (final s in const ['all', 'active', 'inactive'])
        ChoiceChip(
          label: Text(s == 'all'
              ? 'الكل'
              : (s == 'active' ? 'فعّال' : 'متوقّف')),
          selected: _status == s,
          selectedColor: AC.gold.withValues(alpha: 0.3),
          backgroundColor: AC.navy3,
          labelStyle: TextStyle(
            color: _status == s ? AC.gold : AC.ts,
            fontSize: 12,
          ),
          onSelected: (_) {
            setState(() => _status = s);
            _load();
          },
        ),
    ]);
  }

  Widget _tenantCard(Map<String, dynamic> t) {
    final tid = (t['tenant_id'] ?? '').toString();
    final active = (t['status'] ?? 'active') == 'active';
    final color = active ? AC.ok : AC.ts;
    return InkWell(
      onTap: () => GoRouter.of(context).go('/admin/tenants/$tid'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.business, color: color, size: 18),
              ),
              const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (t['display_name'] ?? '').toString(),
                    style: TextStyle(
                      color: AC.tp,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.md,
                    ),
                  ),
                  Text(
                    tid,
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                active ? 'فعّال' : 'متوقّف',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (t['industry_pack_id'] != null)
              _meta('pack: ${t['industry_pack_id']}', AC.gold),
            _meta((t['created_at'] ?? '').toString().substring(0, 10), AC.ts),
            if (t['created_by'] != null) _meta('by: ${t['created_by']}', AC.cyan),
          ]),
          if ((t['notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t['notes'].toString(),
              style: TextStyle(color: AC.ts, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            OutlinedButton.icon(
              onPressed: () => GoRouter.of(context)
                  .go('/admin/workflow/rules?tenant_id=$tid'),
              icon: const Icon(Icons.auto_awesome_motion, size: 14),
              label: const Text('قواعده'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.cyan),
                foregroundColor: AC.cyan,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => GoRouter.of(context).go('/admin/industry-packs'),
              icon: const Icon(Icons.business_center, size: 14),
              label: const Text('الحزم'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.gold),
                foregroundColor: AC.gold,
              ),
            ),
            if (active)
              OutlinedButton.icon(
                onPressed: () => _deactivate(tid),
                icon: const Icon(Icons.pause, size: 14),
                label: const Text('تعطيل'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.warn),
                  foregroundColor: AC.warn,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _activate(tid),
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('تفعيل'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.ok),
                  foregroundColor: AC.ok,
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _delete(tid),
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('حذف'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.err),
                foregroundColor: AC.err,
              ),
            ),
          ]),
          ],
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
}
