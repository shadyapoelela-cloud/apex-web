/// APEX V4 Compliance / ZATCA — Certificates screen (Wave 12).
///
/// UI for the Wave 11 CSID lifecycle backend. Shows every Fatoora
/// CSID the tenant has registered, color-codes them by expiry
/// proximity, and lets authorized users revoke a stale cert or
/// trigger a sweep that flips past-due rows to expired.
///
/// No endpoint in the system returns decrypted cert/key material, so
/// this screen NEVER displays PEM blobs. Metadata only.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/v4/apex_screen_host.dart';

class ZatcaCsidScreen extends StatefulWidget {
  const ZatcaCsidScreen({super.key});

  @override
  State<ZatcaCsidScreen> createState() => _ZatcaCsidScreenState();
}

class _ZatcaCsidScreenState extends State<ZatcaCsidScreen> {
  ApexScreenState _state = ApexScreenState.loading;
  String? _errorDetail;

  Map<String, int> _stats = const {};
  List<Map<String, dynamic>> _rows = const [];
  String _filterStatus = 'all';
  String _filterEnv = 'all';

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
      final statsRes = await ApiService.zatcaCsidStats();
      if (!statsRes.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = statsRes.error;
        });
        return;
      }
      final listRes = await ApiService.zatcaCsidList(
        status: _filterStatus == 'all' ? null : _filterStatus,
        environment: _filterEnv == 'all' ? null : _filterEnv,
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

  void _changeStatusFilter(String s) {
    setState(() => _filterStatus = s);
    _load();
  }

  void _changeEnvFilter(String e) {
    setState(() => _filterEnv = e);
    _load();
  }

  Future<void> _revoke(String id) async {
    final reason = await _askReason(context);
    if (reason == null) return;
    final res = await ApiService.zatcaCsidRevoke(
      id,
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    _toast(
      res.success ? 'تم الإلغاء' : (res.error ?? 'تعذّر الإلغاء'),
      res.success ? AC.ok : AC.err,
    );
    _load();
  }

  Future<void> _sweep() async {
    final ok = await _confirmSweep(context);
    if (!ok) return;
    final res = await ApiService.zatcaCsidSweepExpired();
    if (!mounted) return;
    if (res.success) {
      final n = (res.data is Map && (res.data as Map)['data'] is Map)
          ? ((res.data as Map)['data'] as Map)['swept'] ?? 0
          : 0;
      _toast('تم تحويل $n شهادة إلى حالة "منتهية"', AC.ok);
    } else {
      _toast(res.error ?? 'تعذّر التنفيذ', AC.err);
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
        title: 'لا شهادات ZATCA مسجّلة بعد',
        description:
            'شهادة CSID (Cryptographic Stamp Identifier) مطلوبة للتخليص الفوري '
            'مع فاتورة. ابدأ بتسجيل شهادة sandbox للاختبار.',
      );
    }

    final soonExpire = _rows.where((r) {
      final d = r['days_to_expiry'];
      final status = r['status']?.toString();
      return status == 'active' && d is num && d <= 30;
    }).length;

    return Column(
      children: [
        if (soonExpire > 0) _ExpiryBanner(count: soonExpire),
        _FilterRow(
          stats: _stats,
          activeStatus: _filterStatus,
          activeEnv: _filterEnv,
          onStatus: _changeStatusFilter,
          onEnv: _changeEnvFilter,
          onSweep: _sweep,
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _rows.isEmpty
              ? ApexScreenHost(
                  state: ApexScreenState.emptyAfterFilter,
                  description: 'لا شهادات مطابقة للفلاتر الحالية.',
                  primaryAction: OutlinedButton(
                    onPressed: () {
                      _changeStatusFilter('all');
                      _changeEnvFilter('all');
                    },
                    child: const Text('مسح الفلاتر'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (ctx, i) => _CsidCard(
                    row: _rows[i],
                    onRevoke: () => _revoke(_rows[i]['id']?.toString() ?? ''),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  final int count;
  const _ExpiryBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: AC.warn.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AC.warn, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$count شهادة ستنتهي خلال 30 يومًا أو أقل — ابدأ إجراءات التجديد قبل فواتها.',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _FilterRow extends StatelessWidget {
  final Map<String, int> stats;
  final String activeStatus;
  final String activeEnv;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onEnv;
  final VoidCallback onSweep;

  const _FilterRow({
    required this.stats,
    required this.activeStatus,
    required this.activeEnv,
    required this.onStatus,
    required this.onEnv,
    required this.onSweep,
  });

  @override
  Widget build(BuildContext context) {
    final statusEntries = [
      _StatEntry('all', 'الكل', stats['total'] ?? 0, AC.ts),
      _StatEntry('active', 'سارية', stats['active'] ?? 0, AC.ok),
      _StatEntry('renewing', 'قيد التجديد', stats['renewing'] ?? 0, AC.info),
      _StatEntry('expired', 'منتهية', stats['expired'] ?? 0, AC.warn),
      _StatEntry('revoked', 'ملغاة', stats['revoked'] ?? 0, AC.err),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AC.navy2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final e in statusEntries)
                _Chip(entry: e, active: activeStatus == e.key, onTap: () => onStatus(e.key)),
              _EnvChipGroup(active: activeEnv, onChange: onEnv),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onSweep,
                icon: Icon(Icons.autorenew, color: AC.warn, size: 16),
                label: Text(
                  'مسح المنتهية',
                  style: TextStyle(color: AC.warn),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.warn.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
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

class _Chip extends StatelessWidget {
  final _StatEntry entry;
  final bool active;
  final VoidCallback onTap;

  const _Chip({required this.entry, required this.active, required this.onTap});

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

class _EnvChipGroup extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;

  const _EnvChipGroup({required this.active, required this.onChange});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AC.navy,
          border: Border.all(color: AC.navy3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EnvButton(label: 'الكل', value: 'all', active: active, onTap: onChange),
            _EnvButton(label: 'Sandbox', value: 'sandbox', active: active, onTap: onChange),
            _EnvButton(label: 'Production', value: 'production', active: active, onTap: onChange),
          ],
        ),
      );
}

class _EnvButton extends StatelessWidget {
  final String label;
  final String value;
  final String active;
  final ValueChanged<String> onTap;

  const _EnvButton({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = active == value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isActive ? AC.gold.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AC.tp : AC.ts,
            fontSize: AppFontSize.sm,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CsidCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onRevoke;

  const _CsidCard({required this.row, required this.onRevoke});

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return AC.ok;
      case 'renewing':
        return AC.info;
      case 'expired':
        return AC.warn;
      case 'revoked':
        return AC.err;
      default:
        return AC.ts;
    }
  }

  Color _expiryColor(int? days, String status) {
    if (status != 'active' || days == null) return AC.ts;
    if (days <= 7) return AC.err;
    if (days <= 30) return AC.warn;
    return AC.ok;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'سارية';
      case 'renewing':
        return 'قيد التجديد';
      case 'expired':
        return 'منتهية';
      case 'revoked':
        return 'ملغاة';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'unknown';
    final env = row['environment']?.toString() ?? '—';
    final subject = row['cert_subject']?.toString() ?? '—';
    final serial = row['cert_serial']?.toString() ?? '';
    final daysRaw = row['days_to_expiry'];
    final days = daysRaw is num ? daysRaw.toInt() : null;
    final expiresAt = row['expires_at']?.toString() ?? '';
    final color = _statusColor(status);
    final expiryColor = _expiryColor(days, status);
    final canRevoke = status == 'active' || status == 'renewing';

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
              Icon(Icons.verified_user, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  subject,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _SmallBadge(label: env, color: AC.info),
              const SizedBox(width: 6),
              _SmallBadge(label: _statusLabel(status), color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (serial.isNotEmpty) ...[
                Icon(Icons.tag, color: AC.ts, size: 14),
                const SizedBox(width: 4),
                Text(
                  serial,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (expiresAt.isNotEmpty) ...[
                Icon(Icons.event, color: AC.ts, size: 14),
                const SizedBox(width: 4),
                Text(
                  expiresAt.split('T').first,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ],
              const Spacer(),
              if (days != null && status == 'active')
                _ExpiryBadge(days: days, color: expiryColor),
            ],
          ),
          if (status == 'revoked' && row['revocation_reason'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: AC.err, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سبب الإلغاء: ${row['revocation_reason']}',
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canRevoke) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onRevoke,
                  icon: Icon(Icons.block, size: 14, color: AC.err),
                  label: Text('إلغاء', style: TextStyle(color: AC.err)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AC.err.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: AppFontSize.xs,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _ExpiryBadge extends StatelessWidget {
  final int days;
  final Color color;
  const _ExpiryBadge({required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = days <= 0
        ? 'منتهية'
        : days == 1
            ? 'يوم واحد'
            : 'خلال $days يومًا';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askReason(BuildContext context) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AC.navy2,
      title: Text('سبب الإلغاء (اختياري)', style: TextStyle(color: AC.tp)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: AC.tp),
          cursorColor: AC.gold,
          decoration: InputDecoration(
            hintText: 'مثلاً: سُرّب المفتاح الخاص، إعادة إصدار مجدولة...',
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
          child: const Text('تأكيد الإلغاء'),
        ),
      ],
    ),
  );
  controller.dispose();
  return reason;
}

Future<bool> _confirmSweep(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AC.navy2,
      title: Text('مسح الشهادات المنتهية', style: TextStyle(color: AC.tp)),
      content: Text(
        'سيتم تحويل حالة كل شهادة سارية تجاوزت تاريخ انتهائها إلى "منتهية". '
        'هذه العملية آمنة ولا تحذف أي بيانات.',
        style: TextStyle(color: AC.ts, height: 1.7),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('إلغاء', style: TextStyle(color: AC.ts)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AC.warn),
          child: const Text('متابعة'),
        ),
      ],
    ),
  );
  return ok == true;
}
