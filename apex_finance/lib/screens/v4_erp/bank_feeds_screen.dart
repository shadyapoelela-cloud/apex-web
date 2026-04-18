/// APEX V4 ERP / Treasury — Bank Feeds screen (Wave 14).
///
/// UI for the Wave 13 bank-feeds backend. Two panes:
/// - Top: connected accounts strip (one card per bank with provider
///   + masked IBAN + last-sync time + status pill + sync/disconnect
///   actions).
/// - Bottom: transactions list for the currently selected connection
///   (or all connections when "all" is selected), color-coded by
///   direction, with a reconcile button on unreconciled rows.
///
/// No screen in the app ever shows decrypted tokens — the backend
/// doesn't expose them by design.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/v4/apex_screen_host.dart';

class BankFeedsScreen extends StatefulWidget {
  const BankFeedsScreen({super.key});

  @override
  State<BankFeedsScreen> createState() => _BankFeedsScreenState();
}

class _BankFeedsScreenState extends State<BankFeedsScreen> {
  ApexScreenState _state = ApexScreenState.loading;
  String? _errorDetail;

  Map<String, int> _stats = const {};
  List<Map<String, dynamic>> _connections = const [];
  List<Map<String, dynamic>> _transactions = const [];
  String _selectedConnection = 'all';
  bool _unreconciledOnly = false;
  List<String> _providers = const [];

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
      final statsRes = await ApiService.bankFeedsStats();
      final connRes = await ApiService.bankFeedsConnections();
      final provRes = await ApiService.bankFeedsProviders();
      if (!statsRes.success || !connRes.success || !provRes.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = statsRes.error ?? connRes.error ?? provRes.error;
        });
        return;
      }

      final statsData = _unwrap(statsRes.data);
      final connData = _unwrap(connRes.data);
      final provData = _unwrap(provRes.data);
      final connections = (connData['rows'] as List? ?? const [])
          .cast<Map>()
          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
          .toList();
      final providers = (provData['providers'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();

      // Transactions for the currently-selected connection filter.
      final txnRes = await ApiService.bankFeedsTransactions(
        connectionId: _selectedConnection == 'all' ? null : _selectedConnection,
        unreconciledOnly: _unreconciledOnly,
      );
      final txns = txnRes.success
          ? (_unwrap(txnRes.data)['rows'] as List? ?? const [])
              .cast<Map>()
              .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _stats = statsData.map((k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0));
        _connections = connections;
        _transactions = txns;
        _providers = providers;
        _state = connections.isEmpty && (_stats['connections_total'] ?? 0) == 0
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

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  Future<void> _sync(String id) async {
    final res = await ApiService.bankFeedsSync(id);
    if (!mounted) return;
    if (res.success) {
      final summary = _unwrap(res.data);
      _toast(
        'تم السحب: ${summary['inserted'] ?? 0} جديد · ${summary['duplicates'] ?? 0} مكرر',
        AC.ok,
      );
    } else {
      _toast(res.error ?? 'تعذّر السحب', AC.err);
    }
    _load();
  }

  Future<void> _disconnect(String id) async {
    final ok = await _confirm(
      context,
      title: 'قطع الاتصال',
      body: 'سيُحذف الـ token المُخزَّن ولن تُسحب معاملات جديدة. البيانات السابقة تبقى كما هي.',
      confirmLabel: 'قطع الاتصال',
      danger: true,
    );
    if (!ok) return;
    final res = await ApiService.bankFeedsDisconnect(id);
    if (!mounted) return;
    _toast(
      res.success ? 'تم القطع' : (res.error ?? 'تعذّر القطع'),
      res.success ? AC.ok : AC.err,
    );
    _load();
  }

  Future<void> _reconcile(String txnId) async {
    final match = await _askReconcileMatch(context);
    if (match == null) return;
    final res = await ApiService.bankFeedsReconcile(
      txnId,
      entityType: match.$1,
      entityId: match.$2,
    );
    if (!mounted) return;
    _toast(
      res.success ? 'تمت المطابقة' : (res.error ?? 'تعذّرت المطابقة'),
      res.success ? AC.ok : AC.err,
    );
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
            ? FilledButton(onPressed: _load, child: const Text('إعادة المحاولة'))
            : null,
      );
    }

    if (_state == ApexScreenState.emptyFirstTime) {
      return ApexScreenHost(
        state: ApexScreenState.emptyFirstTime,
        title: 'لم يتم ربط أي حساب بنكي بعد',
        description:
            'الربط عبر Lean أو Tarabut يجعل فواتير المطابقة البنكية تلقائية. '
            'Providers المتاحة حاليًا: ${_providers.join(", ")}.',
      );
    }

    return Column(
      children: [
        _StatsRow(stats: _stats),
        const Divider(height: 1, thickness: 1),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _AllAccountsChip(
                selected: _selectedConnection == 'all',
                onTap: () {
                  setState(() => _selectedConnection = 'all');
                  _load();
                },
                total: _stats['transactions_total'] ?? 0,
              ),
              for (final c in _connections)
                _ConnectionCard(
                  row: c,
                  selected: _selectedConnection == c['id'],
                  onSelect: () {
                    setState(() =>
                        _selectedConnection = c['id']?.toString() ?? 'all');
                    _load();
                  },
                  onSync: () => _sync(c['id']?.toString() ?? ''),
                  onDisconnect: () =>
                      _disconnect(c['id']?.toString() ?? ''),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        _TxnToolbar(
          unreconciledOnly: _unreconciledOnly,
          onToggle: (v) {
            setState(() => _unreconciledOnly = v);
            _load();
          },
          count: _transactions.length,
        ),
        Expanded(
          child: _transactions.isEmpty
              ? ApexScreenHost(
                  state: ApexScreenState.emptyAfterFilter,
                  description: _unreconciledOnly
                      ? 'لا معاملات غير مطابقة.'
                      : 'لا معاملات للعرض.',
                  primaryAction: _unreconciledOnly
                      ? OutlinedButton(
                          onPressed: () {
                            setState(() => _unreconciledOnly = false);
                            _load();
                          },
                          child: const Text('اعرض الكل'),
                        )
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) => _TxnRow(
                    row: _transactions[i],
                    onReconcile: () =>
                        _reconcile(_transactions[i]['id']?.toString() ?? ''),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: AC.navy2,
        child: Row(
          children: [
            _StatPill(
              label: 'الحسابات',
              value: '${stats['connections_total'] ?? 0}',
              color: AC.tp,
            ),
            const SizedBox(width: AppSpacing.md),
            _StatPill(
              label: 'متصلة',
              value: '${stats['connected'] ?? 0}',
              color: AC.ok,
            ),
            const SizedBox(width: AppSpacing.md),
            _StatPill(
              label: 'يحتاج إعادة ربط',
              value: '${stats['reauth_required'] ?? 0}',
              color: AC.warn,
            ),
            const SizedBox(width: AppSpacing.md),
            _StatPill(
              label: 'معاملات',
              value: '${stats['transactions_total'] ?? 0}',
              color: AC.info,
            ),
            const SizedBox(width: AppSpacing.md),
            _StatPill(
              label: 'غير مطابقة',
              value: '${stats['transactions_unreconciled'] ?? 0}',
              color: AC.warn,
            ),
          ],
        ),
      );
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: AppFontSize.base,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
}

class _AllAccountsChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final int total;

  const _AllAccountsChip({
    required this.selected,
    required this.onTap,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 180,
          margin: const EdgeInsets.only(left: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AC.gold.withValues(alpha: 0.15) : AC.navy2,
            border: Border.all(
              color: selected ? AC.gold : AC.navy3,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.all_inclusive, color: AC.gold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'كل الحسابات',
                    style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.base,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$total معاملة',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
              ),
            ],
          ),
        ),
      );
}

class _ConnectionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  const _ConnectionCard({
    required this.row,
    required this.selected,
    required this.onSelect,
    required this.onSync,
    required this.onDisconnect,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'connected':
        return AC.ok;
      case 'reauth_required':
        return AC.warn;
      case 'error':
        return AC.err;
      default:
        return AC.ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'unknown';
    final provider = row['provider']?.toString() ?? '—';
    final bank = row['bank_name']?.toString() ?? row['account_name']?.toString() ?? provider;
    final iban = row['iban_masked']?.toString() ?? row['account_number_masked']?.toString() ?? '';
    final color = _statusColor(status);
    final canDisconnect = status == 'connected' || status == 'error' || status == 'reauth_required';

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(left: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.1) : AC.navy2,
          border: Border(
            right: BorderSide(color: color, width: 3),
            top: BorderSide(color: selected ? AC.gold : AC.navy3, width: selected ? 2 : 1),
            bottom: BorderSide(color: selected ? AC.gold : AC.navy3, width: selected ? 2 : 1),
            left: BorderSide(color: selected ? AC.gold : AC.navy3, width: selected ? 2 : 1),
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bank,
                    style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.base,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontSize: AppFontSize.xs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$provider · $iban',
              style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.sm,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  tooltip: 'سحب المعاملات الآن',
                  onPressed: onSync,
                  icon: Icon(Icons.sync, color: AC.gold, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                if (canDisconnect)
                  IconButton(
                    tooltip: 'قطع الاتصال',
                    onPressed: onDisconnect,
                    icon: Icon(Icons.link_off, color: AC.err, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                const Spacer(),
                Text(
                  _lastSync(row['last_sync_at']?.toString()),
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'connected':
        return 'متصل';
      case 'reauth_required':
        return 'إعادة ربط';
      case 'disconnected':
        return 'مقطوع';
      case 'error':
        return 'خطأ';
      default:
        return s;
    }
  }

  String _lastSync(String? iso) {
    if (iso == null || iso.isEmpty) return 'لم يُسحب بعد';
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'آخر سحب $h:$m';
    } catch (_) {
      return '';
    }
  }
}

class _TxnToolbar extends StatelessWidget {
  final bool unreconciledOnly;
  final ValueChanged<bool> onToggle;
  final int count;

  const _TxnToolbar({
    required this.unreconciledOnly,
    required this.onToggle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: AC.navy2.withValues(alpha: 0.5),
        child: Row(
          children: [
            Icon(Icons.receipt_long, color: AC.ts, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'المعاملات ($count)',
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.base,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'غير مطابقة فقط',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
            Switch(
              value: unreconciledOnly,
              onChanged: onToggle,
              activeColor: AC.gold,
            ),
          ],
        ),
      );
}

class _TxnRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onReconcile;

  const _TxnRow({required this.row, required this.onReconcile});

  @override
  Widget build(BuildContext context) {
    final direction = row['direction']?.toString() ?? 'debit';
    final isCredit = direction == 'credit';
    final color = isCredit ? AC.ok : AC.warn;
    final amount = row['amount']?.toString() ?? '0';
    final currency = row['currency']?.toString() ?? 'SAR';
    final description = row['description']?.toString() ?? '—';
    final counterparty = row['counterparty']?.toString() ?? '';
    final date = (row['txn_date']?.toString() ?? '').split('T').first;
    final matched = row['matched_entity_id'] != null;
    final categoryHint = row['category_hint']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(right: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (counterparty.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      counterparty,
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: AC.ts, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
                      ),
                      if (categoryHint != null && categoryHint.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AC.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            categoryHint,
                            style: TextStyle(
                              color: AC.info,
                              fontSize: AppFontSize.xs,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? "+" : "−"}$amount $currency',
                style: TextStyle(
                  color: color,
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              if (matched)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AC.ok.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: AC.ok, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        'مطابقة',
                        style: TextStyle(
                          color: AC.ok,
                          fontSize: AppFontSize.xs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: onReconcile,
                  icon: Icon(Icons.link, size: 12, color: AC.gold),
                  label: Text(
                    'مطابقة',
                    style: TextStyle(color: AC.gold, fontSize: AppFontSize.sm),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: AC.gold.withValues(alpha: 0.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AC.navy2,
      title: Text(title, style: TextStyle(color: AC.tp)),
      content: Text(body, style: TextStyle(color: AC.ts, height: 1.7)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('إلغاء', style: TextStyle(color: AC.ts)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AC.err : AC.gold,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<(String, String)?> _askReconcileMatch(BuildContext context) async {
  String entityType = 'journal_entry';
  final entityIdCtl = TextEditingController();

  final result = await showDialog<(String, String)?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('ربط المعاملة', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'نوع الكيان',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final opt in const [
                    ('journal_entry', 'قيد يومية'),
                    ('invoice', 'فاتورة'),
                    ('bill', 'فاتورة واردة'),
                  ])
                    ChoiceChip(
                      label: Text(opt.$2),
                      selected: entityType == opt.$1,
                      onSelected: (_) => setInner(() => entityType = opt.$1),
                      selectedColor: AC.gold.withValues(alpha: 0.3),
                      backgroundColor: AC.navy,
                      labelStyle: TextStyle(
                        color: entityType == opt.$1 ? AC.tp : AC.ts,
                        fontWeight: entityType == opt.$1 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: entityIdCtl,
                autofocus: true,
                style: TextStyle(color: AC.tp),
                cursorColor: AC.gold,
                decoration: InputDecoration(
                  labelText: 'معرّف الكيان (مثلاً: JE-042 / INV-123)',
                  labelStyle: TextStyle(color: AC.ts),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          FilledButton(
            onPressed: () {
              final id = entityIdCtl.text.trim();
              if (id.isEmpty) return;
              Navigator.of(ctx).pop((entityType, id));
            },
            style: FilledButton.styleFrom(backgroundColor: AC.gold),
            child: const Text('تأكيد المطابقة'),
          ),
        ],
      ),
    ),
  );
  entityIdCtl.dispose();
  return result;
}
