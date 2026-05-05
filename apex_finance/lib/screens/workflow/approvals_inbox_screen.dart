/// APEX — Workflow Approvals Inbox
/// /workflow/approvals — multi-step approval queue per user.
///
/// Wired to the live Approval Chains backend (Wave 1B Phase J) at
/// /api/v1/approvals/inbox + approve/reject endpoints. Replaces the
/// hardcoded sample data that was here for the Sprint 41 demo.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ApprovalsInboxScreen extends StatefulWidget {
  const ApprovalsInboxScreen({super.key});
  @override
  State<ApprovalsInboxScreen> createState() => _ApprovalsInboxScreenState();
}

class _ApprovalsInboxScreenState extends State<ApprovalsInboxScreen> {
  String _filter = 'pending';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = S.uid;
    if (uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'يجب تسجيل الدخول لعرض صندوق الموافقات';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.approvalsInbox(uid);
    if (!mounted) return;
    if (res.success) {
      final data = res.data;
      final raw = data is Map ? (data['approvals'] ?? const []) : const [];
      _items = (raw as List)
          .cast<Map<String, dynamic>>()
          .map(_normalize)
          .toList(growable: false);
      _loading = false;
    } else {
      _loading = false;
      _error = res.error ?? 'فشل تحميل صندوق الموافقات';
    }
    setState(() {});
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> a) {
    // Adapt the backend payload (id, title_ar, stages[], state, meta) to
    // the shape the existing card UI expects (title, object, amount,
    // step, kind, status). Lossless: original kept under "_raw".
    final stages = (a['stages'] as List?) ?? const [];
    final currentStage = a['current_stage'] is int ? a['current_stage'] as int : 0;
    final totalStages = stages.length;
    final meta = a['meta'] is Map ? a['meta'] as Map : const {};
    final triggerPayload = meta['trigger_payload'] is Map ? meta['trigger_payload'] as Map : const {};

    final amount = (triggerPayload['total_amount'] ??
        triggerPayload['amount'] ??
        triggerPayload['total'] ??
        0)
        .toDouble();

    final state = (a['state'] ?? 'pending').toString();
    final filterStatus = state == 'pending' ? 'pending'
        : state == 'approved' ? 'approved'
        : state == 'rejected' ? 'rejected'
        : 'pending';

    return {
      'id': a['id'],
      'title': a['title_ar'] ?? a['title_en'] ?? 'موافقة',
      'object': a['object_id']?.toString() ?? '',
      'amount': amount is double ? amount : (amount as num).toDouble(),
      'requester': a['requested_by']?.toString() ?? 'النظام',
      'submitted_at': a['created_at']?.toString().substring(0, 10) ?? '',
      'step': totalStages > 0
          ? '${currentStage + 1} من $totalStages'
          : '—',
      'kind': a['object_type']?.toString() ?? 'task',
      'status': filterStatus,
      '_raw': a,
    };
  }

  Future<void> _decide(Map<String, dynamic> i, bool approve) async {
    final id = (i['id'] ?? '').toString();
    if (id.isEmpty) return;
    final res = approve
        ? await ApiService.approvalsApprove(id, S.uid ?? '')
        : await ApiService.approvalsReject(id, S.uid ?? '');
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: approve ? AC.ok : AC.warn,
          content: Text(approve ? 'تمت الموافقة' : 'تم الرفض'),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.err,
          content: Text(res.error ?? 'حدث خطأ'),
        ),
      );
    }
  }

  IconData _kindIcon(String k) => switch (k) {
        'bill' => Icons.receipt,
        'budget' => Icons.attach_money,
        'je' => Icons.book,
        'expense' => Icons.receipt_long,
        'vat' => Icons.percent,
        _ => Icons.assignment,
      };

  Color _kindColor(String k) => switch (k) {
        'bill' => AC.warn,
        'budget' => AC.err,
        'je' => AC.gold,
        'expense' => AC.info,
        'vat' => AC.warn,
        _ => AC.ts,
      };

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((i) => i['status'] == _filter).toList();
  }

  double get _pendingTotal =>
      _items.where((i) => i['status'] == 'pending').fold<double>(0, (a, i) => a + (i['amount'] as double));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AC.navy,
        body: Center(child: CircularProgressIndicator(color: AC.gold)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AC.navy,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AC.err, size: 48),
                const SizedBox(height: 16),
                Text(_error!,
                    style: TextStyle(color: AC.tp, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ApexListShell<Map<String, dynamic>>(
      title: 'صندوق الموافقات',
      subtitle: 'بانتظار قرارك: ${_pendingTotal.toStringAsFixed(0)} SAR',
      filterChips: [
        ApexFilterChip(
            label: 'بانتظار',
            selected: _filter == 'pending',
            onTap: () => setState(() => _filter = 'pending'),
            icon: Icons.pending,
            count: _items.where((i) => i['status'] == 'pending').length),
        ApexFilterChip(
            label: 'مُعتمد',
            selected: _filter == 'approved',
            onTap: () => setState(() => _filter = 'approved'),
            icon: Icons.check_circle,
            count: _items.where((i) => i['status'] == 'approved').length),
        ApexFilterChip(
            label: 'مرفوض',
            selected: _filter == 'rejected',
            onTap: () => setState(() => _filter = 'rejected'),
            icon: Icons.cancel,
            count: _items.where((i) => i['status'] == 'rejected').length),
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _items.length),
      ],
      items: _filtered,
      onRefresh: _load,
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
        ApexChipLink('فواتير الموردين', '/app/erp/finance/purchase-bills', Icons.receipt_outlined),
        ApexChipLink('تقارير المصاريف', '/hr/expense-reports', Icons.receipt_long),
        ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.inbox,
        title: 'لا توجد طلبات اعتماد',
        description: 'كل ما يصل إليك سيظهر هنا',
      ),
      itemBuilder: (ctx, i) {
        final color = _kindColor(i['kind'] as String);
        final isPending = i['status'] == 'pending';
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AC.navy2,
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_kindIcon(i['kind'] as String), color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${i['title']}',
                    style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Text('${(i['amount'] as double).toStringAsFixed(0)} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline, size: 11, color: AC.ts),
              const SizedBox(width: 4),
              Text('${i['requester']}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 11, color: AC.ts),
              const SizedBox(width: 4),
              Text('${i['submitted_at']}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${i['step']}',
                  style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decide(i, false),
                    icon: Icon(Icons.close, color: AC.err, size: 14),
                    label: Text('رفض', style: TextStyle(color: AC.err)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AC.err)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _decide(i, true),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('اعتمد'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AC.ok, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}
