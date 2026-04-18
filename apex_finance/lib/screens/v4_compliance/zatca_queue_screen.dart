/// APEX V4 Compliance / ZATCA — Clearance Log screen (Wave 6 PR#1).
///
/// UI for the Wave 5 offline retry queue backend. Shows the current
/// submission status (KPI strip + filterable list) so accountants can
/// see which invoices are stuck, why, and when the next retry fires.
///
/// Drill-through to the detail drawer pulls the full row including
/// last_error_code + last_error_message — both rendered via the
/// Wave 2 ApexZatcaErrorCard so Arabic accountants get an actionable
/// explanation instead of the raw XSD rule id.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/v4/apex_screen_host.dart';

class ZatcaQueueScreen extends StatefulWidget {
  const ZatcaQueueScreen({super.key});

  @override
  State<ZatcaQueueScreen> createState() => _ZatcaQueueScreenState();
}

class _ZatcaQueueScreenState extends State<ZatcaQueueScreen> {
  ApexScreenState _state = ApexScreenState.loading;
  String? _errorDetail;

  Map<String, int> _stats = const {};
  List<Map<String, dynamic>> _rows = const [];
  String _filterStatus = 'all'; // all|pending|cleared|giveup|draft

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
      final statsRes = await ApiService.zatcaQueueStats();
      if (!statsRes.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = statsRes.error;
        });
        return;
      }

      final listRes = await ApiService.zatcaQueueList(
        status: _filterStatus == 'all' ? null : _filterStatus,
      );
      if (!listRes.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = listRes.error;
        });
        return;
      }

      final statsData = statsRes.get<Map>('data') ?? const {};
      final listData = listRes.get<Map>('data') ?? const {};
      final rowsRaw = (listData['rows'] as List? ?? const [])
          .cast<Map>()
          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
          .toList();

      setState(() {
        _stats = statsData.map((k, v) => MapEntry(k.toString(), v is int ? v : int.tryParse('$v') ?? 0));
        _rows = rowsRaw;
        _state = rowsRaw.isEmpty && (_stats['total'] ?? 0) == 0
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

  @override
  Widget build(BuildContext context) {
    if (_state == ApexScreenState.loading ||
        _state == ApexScreenState.error) {
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
        title: 'لا توجد فواتير في قائمة الإرسال',
        description:
            'عند إرسال فاتورة لـ ZATCA، إذا تأخّر أو فشل التخليص فستظهر هنا '
            'مع جدول إعادة المحاولة التلقائية (1د → 5د → 30د → 2س → 12س → 24س).',
        secondaryAction: OutlinedButton(
          onPressed: _load,
          child: const Text('تحديث'),
        ),
      );
    }

    return Column(
      children: [
        _StatsStrip(stats: _stats, onChipTap: _changeFilter, active: _filterStatus),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _rows.isEmpty
              ? ApexScreenHost(
                  state: ApexScreenState.emptyAfterFilter,
                  description: 'لا فواتير بحالة "$_filterStatus". جرّب فلترًا آخر.',
                  primaryAction: OutlinedButton(
                    onPressed: () => _changeFilter('all'),
                    child: const Text('الكل'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color: AC.navy3.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (ctx, i) => _QueueRow(
                    row: _rows[i],
                    onTap: () => _showDetail(ctx, _rows[i]['id']?.toString() ?? ''),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _showDetail(BuildContext ctx, String id) async {
    if (id.isEmpty) return;
    await showDialog<void>(
      context: ctx,
      builder: (_) => _DetailDialog(id: id),
    );
    _load();
  }
}

class _StatsStrip extends StatelessWidget {
  final Map<String, int> stats;
  final String active;
  final ValueChanged<String> onChipTap;

  const _StatsStrip({
    required this.stats,
    required this.active,
    required this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      _StatEntry('all', 'الكل', stats['total'] ?? 0, AC.ts),
      _StatEntry('pending', 'معلّقة', stats['pending'] ?? 0, AC.warn),
      _StatEntry('cleared', 'مقبولة', stats['cleared'] ?? 0, AC.ok),
      _StatEntry('giveup', 'فشل نهائي', stats['giveup'] ?? 0, AC.err),
      _StatEntry('draft', 'مسودات', stats['draft'] ?? 0, AC.info),
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
                  onTap: () => onChipTap(e.key),
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

  const _StatChip({
    required this.entry,
    required this.active,
    required this.onTap,
  });

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
            color: active
                ? entry.color.withValues(alpha: 0.16)
                : AC.navy,
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
                decoration: BoxDecoration(
                  color: entry.color,
                  shape: BoxShape.circle,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
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

class _QueueRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _QueueRow({required this.row, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'cleared':
        return AC.ok;
      case 'pending':
        return AC.warn;
      case 'giveup':
        return AC.err;
      case 'draft':
        return AC.info;
      default:
        return AC.ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'unknown';
    final color = _statusColor(status);
    final invoiceId = row['invoice_id']?.toString() ?? '—';
    final attempts = row['attempts'] ?? 0;
    final errorCode = row['last_error_code']?.toString();
    final nextRetry = row['next_retry_at']?.toString();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        invoiceId,
                        style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.base,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _AttemptBadge(attempts: attempts is int ? attempts : int.tryParse('$attempts') ?? 0),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    errorCode != null && errorCode.isNotEmpty
                        ? 'آخر خطأ: $errorCode'
                        : (nextRetry != null
                            ? 'المحاولة القادمة: ${_shortTime(nextRetry)}'
                            : 'مقبولة'),
                    style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: AC.ts, size: 20),
          ],
        ),
      ),
    );
  }

  /// "2026-04-18T13:45:12" → "13:45".
  String _shortTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso;
    }
  }
}

class _AttemptBadge extends StatelessWidget {
  final int attempts;
  const _AttemptBadge({required this.attempts});

  @override
  Widget build(BuildContext context) {
    if (attempts == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        'محاولة $attempts',
        style: TextStyle(
          color: AC.ts,
          fontSize: AppFontSize.xs,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _DetailDialog extends StatefulWidget {
  final String id;
  const _DetailDialog({required this.id});

  @override
  State<_DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends State<_DetailDialog> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.zatcaQueueDetail(widget.id);
      if (!mounted) return;
      if (!res.success) {
        setState(() => _error = res.error);
        return;
      }
      final d = res.get<Map>('data');
      setState(() =>
          _data = d == null ? null : Map<String, dynamic>.from(d));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AC.navy2,
      title: Text(
        'تفاصيل الإرسال',
        style: TextStyle(color: AC.tp),
      ),
      content: SizedBox(
        width: 460,
        child: _data == null && _error == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? _DetailError(error: _error!, onRetry: _fetch)
                : _DetailBody(data: _data!),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إغلاق', style: TextStyle(color: AC.gold)),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _DetailError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AC.err, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <_Kv>[
      _Kv('رقم الفاتورة', data['invoice_id']),
      _Kv('الحالة', data['status']),
      _Kv('عدد المحاولات', '${data['attempts']} / ${data['max_attempts']}'),
      _Kv('المحاولة القادمة', data['next_retry_at']),
      _Kv('آخر محاولة', data['last_attempt_at']),
      _Kv('رمز الخطأ', data['last_error_code']),
      _Kv('رسالة الخطأ', data['last_error_message']),
      if (data['cleared_uuid'] != null) _Kv('ZATCA UUID', data['cleared_uuid']),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .where((r) => r.value != null && r.value.toString().isNotEmpty)
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        r.label,
                        style: TextStyle(
                          color: AC.ts,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${r.value}',
                        style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.sm,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Kv {
  final String label;
  final Object? value;
  const _Kv(this.label, this.value);
}
