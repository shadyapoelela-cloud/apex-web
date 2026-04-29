/// APEX — Approvals Admin Console
/// /admin/approvals — system-wide view of every approval request.
///
/// Wired to Wave 1B Phase J backend:
///   GET    /admin/approvals?state=&tenant_id=&user_id=
///   DELETE /admin/approvals/{id}?reason=
///   GET    /admin/approvals/stats
///
/// Differs from the user-facing /workflow/approvals inbox: this is the
/// platform admin's overview — sees ALL approvals across ALL tenants,
/// can cancel any pending request out-of-band, and shows aggregate
/// stats. Useful when a workflow rule misfires and creates approvals
/// nobody asked for.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ApprovalsAdminScreen extends StatefulWidget {
  const ApprovalsAdminScreen({super.key});
  @override
  State<ApprovalsAdminScreen> createState() => _ApprovalsAdminScreenState();
}

class _ApprovalsAdminScreenState extends State<ApprovalsAdminScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _approvals = [];
  Map<String, dynamic> _stats = const {};
  final _tenantCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  String _state = 'all';

  static const _states = ['all', 'pending', 'approved', 'rejected', 'cancelled'];
  static const _stateLabels = {
    'all': 'الكل',
    'pending': 'قيد الانتظار',
    'approved': 'موافقة',
    'rejected': 'مرفوضة',
    'cancelled': 'ملغية',
  };

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _userCtrl.dispose();
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
      ApiService.approvalsAdminList(
        tenantId: _tenantCtrl.text.trim().isEmpty ? null : _tenantCtrl.text.trim(),
        userId: _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
        state: _state == 'all' ? null : _state,
      ),
      ApiService.approvalsAdminStats(),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) {
      _approvals = ((r[0].data['approvals'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r[0].error ?? 'تعذّر تحميل الموافقات';
    }
    if (r[1].success && r[1].data is Map) {
      _stats = Map<String, dynamic>.from(r[1].data as Map);
    }
    setState(() => _loading = false);
  }

  Future<void> _cancel(String id) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إلغاء الموافقة', style: TextStyle(color: AC.tp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيتم إلغاء هذا الطلب. هل أنت متأكد؟',
                style: TextStyle(color: AC.ts)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.approvalsAdminCancel(
      id,
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إلغاء الطلب', style: TextStyle(color: AC.tp))),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.err,
          content: Text(res.error ?? 'تعذّر إلغاء الطلب'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'إدارة الموافقات',
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
            if (_approvals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'لا توجد موافقات تطابق الفلتر الحالي',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AC.ts),
                ),
              )
            else
              ..._approvals.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _statsBar() {
    final total = _stats['total'] ?? 0;
    final byState = (_stats['by_state'] as Map?) ?? const {};
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Wrap(spacing: 12, runSpacing: 8, children: [
        _stat('إجمالي', total.toString(), AC.tp),
        _stat('قيد الانتظار', byState['pending']?.toString() ?? '0', AC.warn),
        _stat('موافقة', byState['approved']?.toString() ?? '0', AC.ok),
        _stat('مرفوضة', byState['rejected']?.toString() ?? '0', AC.err),
        _stat('ملغية', byState['cancelled']?.toString() ?? '0', AC.ts),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in _states)
              ChoiceChip(
                label: Text(_stateLabels[s]!),
                selected: _state == s,
                selectedColor: AC.gold.withValues(alpha: 0.3),
                backgroundColor: AC.navy3,
                labelStyle: TextStyle(
                  color: _state == s ? AC.gold : AC.ts,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() => _state = s);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _tenantCtrl,
                style: TextStyle(color: AC.tp, fontSize: 12),
                decoration: _input('tenant_id'),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _userCtrl,
                style: TextStyle(color: AC.tp, fontSize: 12),
                decoration: _input('user_id'),
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
        ],
      ),
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

  Widget _card(Map<String, dynamic> a) {
    final state = (a['state'] ?? 'pending').toString();
    final color = switch (state) {
      'pending' => AC.warn,
      'approved' => AC.ok,
      'rejected' => AC.err,
      'cancelled' => AC.ts,
      _ => AC.tp,
    };
    final approvers = ((a['approver_user_ids'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
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
                _stateLabels[state] ?? state,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (a['title_ar'] ?? a['title_en'] ?? '—').toString(),
                style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold),
              ),
            ),
            if (state == 'pending')
              IconButton(
                tooltip: 'إلغاء',
                onPressed: () => _cancel(a['id'].toString()),
                icon: Icon(Icons.cancel_outlined, size: 18, color: AC.err),
              ),
          ]),
          const SizedBox(height: 6),
          if (a['body'] != null && (a['body'] as String).isNotEmpty)
            Text(
              a['body'].toString(),
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (a['object_type'] != null)
              _meta('${a['object_type']}/${a['object_id'] ?? '—'}', AC.cyan),
            if (a['tenant_id'] != null) _meta('tenant: ${a['tenant_id']}', AC.gold),
            if (a['requested_by'] != null) _meta('requester: ${a['requested_by']}', AC.tp),
            _meta('${approvers.length} approver(s)', AC.warn),
            _meta('id: ${a['id']}', AC.ts),
          ]),
        ],
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
