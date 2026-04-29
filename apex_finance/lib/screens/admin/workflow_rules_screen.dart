/// APEX — Workflow Rules Console
/// /admin/workflow/rules — see + toggle + delete rules created from templates
///
/// Wired to the Workflow Engine backend (Wave 1A Phase G):
///   GET    /admin/workflow/rules
///   PATCH  /admin/workflow/rules/{id}   (toggle enabled)
///   DELETE /admin/workflow/rules/{id}
///   POST   /admin/workflow/rules/{id}/run (dry-run testing)
///
/// Admin-secret-gated.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class WorkflowRulesScreen extends StatefulWidget {
  const WorkflowRulesScreen({super.key});

  @override
  State<WorkflowRulesScreen> createState() => _WorkflowRulesScreenState();
}

class _WorkflowRulesScreenState extends State<WorkflowRulesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rules = [];
  Map<String, dynamic>? _stats;

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
    final res = await ApiService.workflowListRules();
    if (!mounted) return;
    if (res.success) {
      final raw = (res.data is Map ? res.data['rules'] : null) ?? const [];
      _rules = (raw as List).cast<Map<String, dynamic>>();
      _loading = false;
    } else {
      _loading = false;
      _error = res.error ?? 'فشل تحميل القواعد';
    }
    final s = await ApiService.workflowStats();
    if (s.success) _stats = s.data is Map<String, dynamic> ? s.data as Map<String, dynamic> : null;
    setState(() {});
  }

  Future<void> _toggle(Map<String, dynamic> rule) async {
    final newEnabled = !(rule['enabled'] == true);
    final res = await ApiService.workflowUpdateRule(
      rule['id'] as String,
      {'enabled': newEnabled},
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: newEnabled ? AC.ok : AC.ts,
          content: Text(newEnabled ? '✅ القاعدة مُفعّلة' : '⏸ القاعدة مُعطّلة'),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف القاعدة', style: TextStyle(color: AC.tp)),
        content: Text(
          'هل تريد حذف "${rule['name']}" نهائياً؟',
          style: TextStyle(color: AC.ts),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.workflowDeleteRule(rule['id'] as String);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('🗑 حُذفت القاعدة')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _testRun(Map<String, dynamic> rule) async {
    final ctrl = TextEditingController(text: '{}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('اختبار القاعدة', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الحدث: ${rule['event_pattern']}',
                style: TextStyle(color: AC.cyan, fontFamily: 'monospace', fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 8,
                style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11),
                decoration: InputDecoration(
                  labelText: 'حمولة JSON',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dry Run'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    Map<String, dynamic> payload;
    try {
      final t = ctrl.text.trim();
      if (t.isEmpty) {
        payload = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(t);
        payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      }
    } catch (_) {
      payload = <String, dynamic>{};
    }
    final res = await ApiService.workflowRunRule(
      rule['id'] as String,
      payload,
      dryRun: true,
    );
    if (!mounted) return;
    final matched = res.success && res.data is Map && (res.data as Map)['matched'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: matched ? AC.ok : AC.warn,
        content: Text(
          matched
              ? '✅ مطابقة شروط القاعدة'
              : '⚠️ الشروط لم تتطابق مع الحمولة',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'محرّك أتمتة سير العمل',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'القوالب',
                icon: Icons.auto_awesome,
                onPressed: () =>
                    GoRouter.of(context).go('/admin/workflow/templates'),
              ),
            ],
          ),
          if (_stats != null) _statsBar(_stats!),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _statsBar(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AC.navy2,
      child: Row(
        children: [
          _statChip('الإجمالي', s['rules_total'].toString(), AC.tp),
          const SizedBox(width: 8),
          _statChip('مُفعّلة', s['rules_enabled'].toString(), AC.ok),
          const SizedBox(width: 8),
          _statChip('مُعطّلة', s['rules_disabled'].toString(), AC.warn),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
        Text(value,
            style: TextStyle(
                color: c, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AC.err, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: AC.tp)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined, color: AC.ts, size: 64),
            const SizedBox(height: 12),
            Text('لا توجد قواعد بعد',
                style: TextStyle(color: AC.tp, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () =>
                  GoRouter.of(context).go('/admin/workflow/templates'),
              icon: const Icon(Icons.add),
              label: const Text('تثبيت قاعدة من القوالب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _rules.length,
        itemBuilder: (ctx, i) => _card(_rules[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final enabled = r['enabled'] == true;
    final runCount = r['run_count'] ?? 0;
    final lastRun = r['last_run_at']?.toString().split('T').first ?? '—';
    final lastError = r['last_error']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: enabled ? AC.ok.withValues(alpha: 0.5) : AC.bdr,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                r['name']?.toString() ?? '',
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.lg,
                ),
              ),
            ),
            Switch(
              value: enabled,
              activeColor: AC.ok,
              onChanged: (_) => _toggle(r),
            ),
          ]),
          if ((r['description_ar'] ?? '').toString().isNotEmpty)
            Text(
              r['description_ar'].toString(),
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.bolt, color: AC.warn, size: 14),
            const SizedBox(width: 4),
            Text(
              r['event_pattern']?.toString() ?? '',
              style: TextStyle(
                  color: AC.warn,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(width: 12),
            Icon(Icons.repeat, color: AC.cyan, size: 14),
            const SizedBox(width: 4),
            Text('شغّلت $runCount مرة',
                style: TextStyle(color: AC.cyan, fontSize: AppFontSize.xs)),
            const Spacer(),
            Text('آخر تشغيل: $lastRun',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
          ]),
          if (lastError != null && lastError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'آخر خطأ: $lastError',
                style: TextStyle(color: AC.err, fontSize: 10.5),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => _testRun(r),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('اختبار'),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.cyan),
                  foregroundColor: AC.cyan),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _delete(r),
              icon: Icon(Icons.delete_outline, color: AC.err, size: 16),
              label: Text('حذف', style: TextStyle(color: AC.err)),
              style:
                  OutlinedButton.styleFrom(side: BorderSide(color: AC.err)),
            ),
          ]),
        ],
      ),
    );
  }
}
