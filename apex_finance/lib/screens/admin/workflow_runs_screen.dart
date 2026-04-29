/// APEX — Workflow Run History
/// /admin/workflow/runs — every rule firing with payload + per-action results.
///
/// Wired to Wave 1O Phase VV backend:
///   GET    /admin/workflow/runs?rule_id=&tenant_id=&event_name=&status=&limit=&offset=
///   GET    /admin/workflow/runs/{run_id}
///   GET    /admin/workflow/runs/stats
///   DELETE /admin/workflow/runs?rule_id=
///
/// Until this screen, admins could see "rule X fired 47 times" but not
/// "what payload, when, with what result." Production debugging now
/// works end-to-end.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class WorkflowRunsScreen extends StatefulWidget {
  const WorkflowRunsScreen({super.key});
  @override
  State<WorkflowRunsScreen> createState() => _WorkflowRunsScreenState();
}

class _WorkflowRunsScreenState extends State<WorkflowRunsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _runs = [];
  Map<String, dynamic> _stats = const {};
  String _statusFilter = 'all';
  final _ruleIdCtrl = TextEditingController();
  final _eventCtrl = TextEditingController();
  final _tenantCtrl = TextEditingController();
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _ruleIdCtrl.dispose();
    _eventCtrl.dispose();
    _tenantCtrl.dispose();
    super.dispose();
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
      ApiService.workflowRunsList(
        ruleId: _ruleIdCtrl.text.trim().isEmpty ? null : _ruleIdCtrl.text.trim(),
        eventName: _eventCtrl.text.trim().isEmpty ? null : _eventCtrl.text.trim(),
        tenantId: _tenantCtrl.text.trim().isEmpty ? null : _tenantCtrl.text.trim(),
        status: _statusFilter == 'all' ? null : _statusFilter,
        limit: 200,
      ),
      ApiService.workflowRunsStats(),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) {
      _runs = ((r[0].data['runs'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r[0].error ?? 'تعذّر تحميل السجلات';
    }
    if (r[1].success && r[1].data is Map) {
      _stats = Map<String, dynamic>.from(r[1].data as Map);
    }
    setState(() => _loading = false);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف كل السجلات', style: TextStyle(color: AC.tp)),
        content: Text(
          'سيتم حذف كل سجلات تنفيذ القواعد. القواعد نفسها لن تُلمس.',
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
    final r = await ApiService.workflowRunsClear();
    if (!mounted) return;
    if (r.success) {
      _expandedIds.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'سجلّ تنفيذ القواعد',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'حذف الكل',
              icon: Icons.delete_sweep,
              onPressed: _clearAll,
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
            if (_runs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.receipt_long_outlined, color: AC.ts, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد سجلات بعد — انتظر اشتعال قاعدة',
                    style: TextStyle(color: AC.ts, fontSize: 13),
                  ),
                ]),
              )
            else
              ..._runs.map(_runCard),
          ],
        ),
      ),
    );
  }

  Widget _statsBar() {
    final total = _stats['total'] ?? 0;
    final cap = _stats['cap'] ?? 5000;
    final byStatus = (_stats['by_status'] as Map?) ?? const {};
    final avg = _stats['avg_duration_ms'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Wrap(spacing: 12, runSpacing: 8, children: [
        _stat('سجلات', '$total / $cap', AC.tp),
        _stat('نجاح', byStatus['success']?.toString() ?? '0', AC.ok),
        _stat('جزئي', byStatus['partial']?.toString() ?? '0', AC.warn),
        _stat('فشل', byStatus['failed']?.toString() ?? '0', AC.err),
        _stat('متوسط زمن', '$avg ms', AC.cyan),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontFamily: 'monospace',
                fontSize: 13,
              )),
        ]),
      );

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in const ['all', 'success', 'partial', 'failed'])
            ChoiceChip(
              label: Text(switch (s) {
                'all' => 'الكل',
                'success' => 'نجاح',
                'partial' => 'جزئي',
                _ => 'فشل',
              }),
              selected: _statusFilter == s,
              selectedColor: AC.gold.withValues(alpha: 0.3),
              backgroundColor: AC.navy3,
              labelStyle: TextStyle(
                color: _statusFilter == s ? AC.gold : AC.ts,
                fontSize: 12,
              ),
              onSelected: (_) {
                setState(() => _statusFilter = s);
                _load();
              },
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ruleIdCtrl,
              style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: _input('rule_id'),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _eventCtrl,
              style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: _input('event_name'),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _tenantCtrl,
              style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: _input('tenant_id'),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.search, size: 14),
            label: const Text('بحث'),
          ),
        ]),
      ]),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      );

  Widget _runCard(Map<String, dynamic> r) {
    final id = r['id'].toString();
    final status = (r['status'] ?? 'success').toString();
    final color = switch (status) {
      'success' => AC.ok,
      'partial' => AC.warn,
      'failed' => AC.err,
      _ => AC.tp,
    };
    final isExpanded = _expandedIds.contains(id);
    final actions = ((r['action_results'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedIds.remove(id);
            } else {
              _expandedIds.add(id);
            }
          }),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r['rule_name']?.toString() ?? '',
                      style: TextStyle(
                        color: AC.tp,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${r['duration_ms'] ?? 0} ms',
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AC.ts,
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _meta(r['event_name']?.toString() ?? '—', AC.cyan),
                  if (r['tenant_id'] != null)
                    _meta('tenant: ${r['tenant_id']}', AC.gold),
                  _meta(_relTime(r['started_at']?.toString() ?? ''), AC.ts),
                  _meta('${actions.length} action(s)', AC.tp),
                ]),
                if (r['error_summary'] != null && (r['error_summary'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    r['error_summary'].toString(),
                    style: TextStyle(color: AC.err, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isExpanded) _expandedBody(r, actions),
      ]),
    );
  }

  Widget _expandedBody(Map<String, dynamic> r, List<Map<String, dynamic>> actions) {
    String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(r['payload']);
    } catch (_) {
      pretty = r['payload']?.toString() ?? '{}';
    }
    return Container(
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الإجراءات (${actions.length}):',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        for (var i = 0; i < actions.length; i++) _actionRow(i, actions[i]),
        const SizedBox(height: 12),
        Text('الحمولة:',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AC.navy,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AC.bdr),
          ),
          child: SelectableText(
            pretty,
            style: TextStyle(
              color: AC.ts,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _meta('id: ${(r['id'] ?? '').toString().substring(0, 8)}', AC.ts),
          _meta('rule_id: ${(r['rule_id'] ?? '').toString().substring(0, 8)}', AC.cyan),
          _meta('${r['started_at']?.toString().substring(11, 19)} → ${r['ended_at']?.toString().substring(11, 19)}', AC.tp),
        ]),
      ]),
    );
  }

  Widget _actionRow(int i, Map<String, dynamic> a) {
    final ok = a['ok'] == true;
    final color = ok ? AC.ok : AC.err;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              ok ? Icons.check : Icons.close,
              color: color,
              size: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AC.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '#${i + 1} ${a['action'] ?? '?'}',
            style: TextStyle(
              color: AC.gold,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            a['error']?.toString() ?? a['status']?.toString() ?? 'ok',
            style: TextStyle(
              color: ok ? AC.ts : AC.err,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
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
