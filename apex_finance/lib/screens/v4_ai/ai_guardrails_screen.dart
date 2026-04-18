/// APEX V4 — AI Guardrails / Suggestion Queue (Wave 8).
///
/// UI for the Wave 7 confidence-gated autopilot backend. Accountants
/// and controllers see every AI decision that landed in the gate —
/// auto_applied rows to retroactively reject, needs_approval rows to
/// approve/reject inline, rejected rows for the audit binder.
///
/// Design mirrors the Wave 6 ZATCA queue screen so users get a single
/// visual language for "work-to-review" across AI + compliance.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/v4/apex_screen_host.dart';

class AiGuardrailsScreen extends StatefulWidget {
  const AiGuardrailsScreen({super.key});

  @override
  State<AiGuardrailsScreen> createState() => _AiGuardrailsScreenState();
}

class _AiGuardrailsScreenState extends State<AiGuardrailsScreen> {
  ApexScreenState _state = ApexScreenState.loading;
  String? _errorDetail;

  Map<String, int> _stats = const {};
  List<Map<String, dynamic>> _rows = const [];
  String _filterStatus = 'needs_approval'; // default to the action queue

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = ApexScreenState.loading;
      _errorDetail = null;
    });
    try {
      final statsRes = await ApiService.aiGuardrailsStats();
      if (!statsRes.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = statsRes.error;
        });
        return;
      }
      final listRes = await ApiService.aiGuardrailsList(
        status: _filterStatus == 'all' ? null : _filterStatus,
      );
      if (!listRes.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = listRes.error;
        });
        return;
      }
      final statsData = (statsRes.data is Map && (statsRes.data as Map)['data'] is Map)
          ? Map<String, dynamic>.from((statsRes.data as Map)['data'] as Map)
          : <String, dynamic>{};
      final listData = (listRes.data is Map && (listRes.data as Map)['data'] is Map)
          ? Map<String, dynamic>.from((listRes.data as Map)['data'] as Map)
          : <String, dynamic>{};
      final rows = (listData['rows'] as List? ?? const [])
          .cast<Map>()
          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
          .toList();
      setState(() {
        _stats = statsData.map(
          (k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0),
        );
        _rows = rows;
        _state = rows.isEmpty && (_stats['total'] ?? 0) == 0
            ? ApexScreenState.emptyFirstTime
            : ApexScreenState.ready;
      });
    } catch (e) {
      setState(() {
        _state = ApexScreenState.error;
        _errorDetail = e.toString();
      });
    }
  }

  void _changeFilter(String status) {
    setState(() => _filterStatus = status);
    _load();
  }

  Future<void> _approve(String id) async {
    final res = await ApiService.aiGuardrailsApprove(id);
    if (!mounted) return;
    if (res.success) {
      _toast('تمت الموافقة', AC.ok);
    } else {
      _toast(res.error ?? 'تعذّر تنفيذ الموافقة', AC.err);
    }
    _load();
  }

  Future<void> _reject(String id) async {
    final reason = await _askRejectReason(context);
    if (reason == null) return; // user cancelled
    final res = await ApiService.aiGuardrailsReject(id, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    if (res.success) {
      _toast('تم الرفض', AC.ok);
    } else {
      _toast(res.error ?? 'تعذّر تنفيذ الرفض', AC.err);
    }
    _load();
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == ApexScreenState.loading || _state == ApexScreenState.error) {
      return ApexScreenHost(
        state: _state,
        errorDetail: _errorDetail,
        primaryAction: _state == ApexScreenState.error
            ? FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              )
            : null,
      );
    }

    if (_state == ApexScreenState.emptyFirstTime) {
      return ApexScreenHost(
        state: ApexScreenState.emptyFirstTime,
        title: 'لا اقتراحات AI بعد',
        description:
            'أي اقتراح من Copilot أو مُصنِّف COA أو OCR سيمرّ من هنا أولاً. '
            'اقتراحات ثقتها ≥ 95% تُطبَّق تلقائيًا؛ الباقي يحتاج موافقتك.',
        secondaryAction: OutlinedButton(
          onPressed: _load,
          child: const Text('تحديث'),
        ),
      );
    }

    return Column(
      children: [
        _StatsStrip(stats: _stats, active: _filterStatus, onTap: _changeFilter),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _rows.isEmpty
              ? ApexScreenHost(
                  state: ApexScreenState.emptyAfterFilter,
                  description: 'لا اقتراحات بحالة "$_filterStatus".',
                  primaryAction: OutlinedButton(
                    onPressed: () => _changeFilter('all'),
                    child: const Text('الكل'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (ctx, i) => _SuggestionCard(
                    row: _rows[i],
                    onApprove: () => _approve(_rows[i]['id']?.toString() ?? ''),
                    onReject: () => _reject(_rows[i]['id']?.toString() ?? ''),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final Map<String, int> stats;
  final String active;
  final ValueChanged<String> onTap;

  const _StatsStrip({required this.stats, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entries = <_StatEntry>[
      _StatEntry('all', 'الكل', stats['total'] ?? 0, AC.ts),
      _StatEntry('needs_approval', 'بانتظار الموافقة', stats['needs_approval'] ?? 0, AC.warn),
      _StatEntry('auto_applied', 'تطبيق تلقائي', stats['auto_applied'] ?? 0, AC.ok),
      _StatEntry('approved', 'موافَق عليها', stats['approved'] ?? 0, AC.info),
      _StatEntry('rejected', 'مرفوضة', stats['rejected'] ?? 0, AC.err),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AC.navy2,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: entries
            .map((e) => _StatChip(
                  entry: e,
                  active: active == e.key,
                  onTap: () => onTap(e.key),
                ))
            .toList(),
      ),
    );
  }
}

class _StatEntry {
  final String key;
  final String label;
  final int count;
  final Color color;
  const _StatEntry(this.key, this.label, this.count, this.color);
}

class _StatChip extends StatelessWidget {
  final _StatEntry entry;
  final bool active;
  final VoidCallback onTap;

  const _StatChip({required this.entry, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: active ? entry.color.withValues(alpha: 0.16) : AC.navy,
            border: Border.all(
              color: active ? entry.color : AC.navy3,
              width: active ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                entry.label,
                style: TextStyle(
                  color: active ? AC.tp : AC.ts,
                  fontSize: AppFontSize.sm,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '${entry.count}',
                  style: TextStyle(
                    color: entry.color,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SuggestionCard({
    required this.row,
    required this.onApprove,
    required this.onReject,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'needs_approval':
        return AC.warn;
      case 'auto_applied':
        return AC.ok;
      case 'approved':
        return AC.info;
      case 'rejected':
        return AC.err;
      default:
        return AC.ts;
    }
  }

  IconData _sourceIcon(String src) {
    switch (src) {
      case 'copilot':
        return Icons.smart_toy;
      case 'coa':
        return Icons.account_tree;
      case 'ocr':
        return Icons.document_scanner;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _confidenceColor(double conf) {
    if (conf >= 0.95) return AC.ok;
    if (conf >= 0.80) return AC.warn;
    return AC.err;
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'unknown';
    final source = row['source']?.toString() ?? 'unknown';
    final action = row['action_type']?.toString() ?? '—';
    final target = row['target_id']?.toString() ?? '';
    final reasoning = row['reasoning']?.toString() ?? '';
    final confRaw = row['confidence'];
    final conf = confRaw is num ? confRaw.toDouble() : 0.0;
    final destructive = row['destructive'] == true;
    final gateReason = row['gate_reason']?.toString() ?? '';
    final color = _statusColor(status);
    final isActionable = status == 'needs_approval';

    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(right: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_sourceIcon(source), color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                source,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '  ·  ',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.base),
              ),
              Text(
                action,
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.base),
              ),
              const Spacer(),
              _ConfidenceBadge(value: conf, color: _confidenceColor(conf)),
              if (destructive) ...[
                const SizedBox(width: 6),
                const _DestructiveBadge(),
              ],
            ],
          ),
          if (target.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'الهدف: $target',
              style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.sm,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (reasoning.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              reasoning,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.base,
                height: 1.7,
              ),
            ),
          ],
          if (gateReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              gateReason,
              style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.sm,
              ),
            ),
          ],
          if (isActionable) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: Icon(Icons.close, size: 16, color: AC.err),
                  label: Text('رفض', style: TextStyle(color: AC.err)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AC.err.withValues(alpha: 0.5)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('موافقة'),
                  style: FilledButton.styleFrom(backgroundColor: AC.ok),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double value;
  final Color color;
  const _ConfidenceBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        '$pct٪',
        style: TextStyle(
          color: color,
          fontSize: AppFontSize.xs,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _DestructiveBadge extends StatelessWidget {
  const _DestructiveBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AC.err.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, color: AC.err, size: 10),
            const SizedBox(width: 3),
            Text(
              'تدميري',
              style: TextStyle(
                color: AC.err,
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

Future<String?> _askRejectReason(BuildContext context) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AC.navy2,
      title: Text('سبب الرفض (اختياري)', style: TextStyle(color: AC.tp)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: AC.tp),
          cursorColor: AC.gold,
          decoration: InputDecoration(
            hintText: 'مثلاً: التصنيف خاطئ، المورد غير صحيح...',
            hintStyle: TextStyle(color: AC.ts),
            filled: true,
            fillColor: AC.navy,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AC.navy3),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AC.navy3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AC.gold),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text('إلغاء', style: TextStyle(color: AC.ts)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AC.err),
          child: const Text('تأكيد الرفض'),
        ),
      ],
    ),
  );
  controller.dispose();
  return reason;
}
