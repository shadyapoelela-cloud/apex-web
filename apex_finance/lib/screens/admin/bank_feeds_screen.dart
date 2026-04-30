/// APEX — Bank Feeds Console
/// /admin/bank-feeds — manage connections + view transactions + reconcile.
///
/// Wired to the existing Wave 13 bank-feeds backend in
/// `app/core/bank_feeds_routes.py`. The backend abstracts over Lean /
/// Tarabut / Salt Edge with a Mock provider available out-of-the-box
/// for local testing.
///
/// Endpoints used:
///   GET  /bank-feeds/providers
///   GET  /bank-feeds/connections
///   POST /bank-feeds/connections
///   GET  /bank-feeds/connections/{id}
///   POST /bank-feeds/connections/{id}/sync
///   POST /bank-feeds/connections/{id}/disconnect
///   GET  /bank-feeds/transactions
///   POST /bank-feeds/transactions/{id}/reconcile
///   GET  /bank-feeds/stats
///
/// Auth: bearer JWT (uses S.token via ApiService.setToken).
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class BankFeedsScreen extends StatefulWidget {
  const BankFeedsScreen({super.key});
  @override
  State<BankFeedsScreen> createState() => _BankFeedsScreenState();
}

class _BankFeedsScreenState extends State<BankFeedsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const {};
  List<String> _providers = [];
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _transactions = [];
  String? _filterConnId;
  bool _onlyUnreconciled = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await Future.wait([
      ApiService.bankFeedsStats(),
      ApiService.bankFeedsProviders(),
      ApiService.bankFeedsConnections(limit: 100),
      ApiService.bankFeedsTransactions(
        connectionId: _filterConnId,
        unreconciledOnly: _onlyUnreconciled,
        limit: 200,
      ),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) {
      _stats = (r[0].data['data'] as Map?)?.cast<String, dynamic>() ?? {};
    }
    if (r[1].success && r[1].data is Map) {
      final providers = (r[1].data['data'] as Map?)?['providers'] as List?;
      _providers = (providers ?? const []).map((e) => e.toString()).toList();
    }
    if (r[2].success && r[2].data is Map) {
      final rows = (r[2].data['data'] as Map?)?['rows'] as List?;
      _connections = (rows ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r[2].error ?? 'تعذّر تحميل الاتصالات';
    }
    if (r[3].success && r[3].data is Map) {
      final rows = (r[3].data['data'] as Map?)?['rows'] as List?;
      _transactions = (rows ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _connect() async {
    if (_providers.isEmpty) return;
    final providerCtrl =
        ValueNotifier<String>(_providers.contains('mock') ? 'mock' : _providers.first);
    final tenantCtrl = TextEditingController();
    final acctNameCtrl = TextEditingController();
    final ibanCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: 'SAR');
    final tokenCtrl = TextEditingController(text: 'mock-token-${DateTime.now().millisecondsSinceEpoch}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('ربط حساب بنكي', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<String>(
                valueListenable: providerCtrl,
                builder: (ctx2, val, _) => DropdownButtonFormField<String>(
                  value: val,
                  dropdownColor: AC.navy2,
                  isDense: true,
                  style: TextStyle(color: AC.tp, fontSize: 12),
                  decoration: _input('Provider'),
                  items: [
                    for (final p in _providers)
                      DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  onChanged: (v) => providerCtrl.value = v ?? val,
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: tenantCtrl, style: TextStyle(color: AC.tp), decoration: _input('tenant_id')),
              const SizedBox(height: 8),
              TextField(controller: acctNameCtrl, style: TextStyle(color: AC.tp), decoration: _input('account_name')),
              const SizedBox(height: 8),
              TextField(controller: ibanCtrl, style: TextStyle(color: AC.tp), decoration: _input('iban_masked (اختياري)')),
              const SizedBox(height: 8),
              TextField(controller: currencyCtrl, style: TextStyle(color: AC.tp), decoration: _input('currency')),
              const SizedBox(height: 8),
              TextField(controller: tokenCtrl, style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
                  decoration: _input('access_token (mock للتجربة)')),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ربط'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final body = {
      'tenant_id': tenantCtrl.text.trim(),
      'provider': providerCtrl.value,
      'account': {
        'external_account_id': 'ext-${DateTime.now().millisecondsSinceEpoch}',
        'bank_name': 'Mock Bank',
        'account_name': acctNameCtrl.text.trim(),
        'iban_masked': ibanCtrl.text.trim().isEmpty ? null : ibanCtrl.text.trim(),
        'currency': currencyCtrl.text.trim().toUpperCase(),
      },
      'tokens': {
        'access_token': tokenCtrl.text.trim(),
      },
    };
    final r = await ApiService.bankFeedsConnect(body);
    if (!mounted) return;
    if (r.success) {
      _snack('تم ربط الحساب');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  Future<void> _sync(Map<String, dynamic> conn) async {
    final r = await ApiService.bankFeedsSync(conn['id'].toString());
    if (!mounted) return;
    if (r.success) {
      _snack('تمّت مزامنة ${conn['account_name']}');
      await _load();
    } else {
      _snack(r.error ?? 'فشل المزامنة', err: true);
    }
  }

  Future<void> _disconnect(Map<String, dynamic> conn) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('فصل ${conn['account_name']}', style: TextStyle(color: AC.tp)),
        content: TextField(
          controller: reasonCtrl,
          style: TextStyle(color: AC.tp),
          decoration: _input('السبب (اختياري)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.warn),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فصل'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.bankFeedsDisconnect(
      conn['id'].toString(),
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    if (r.success) {
      _snack('تم فصل الحساب');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  Future<void> _reconcile(Map<String, dynamic> txn) async {
    final entityTypeCtrl = TextEditingController(text: 'invoice');
    final entityIdCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('مطابقة المعاملة', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '${txn['posting_date']} · ${txn['amount']} ${txn['currency']}\n${txn['description']}',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: entityTypeCtrl,
              style: TextStyle(color: AC.tp),
              decoration: _input('entity_type (مثلاً invoice/bill/je)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: entityIdCtrl,
              style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
              decoration: _input('entity_id'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مطابقة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.bankFeedsReconcile(
      txn['id'].toString(),
      entityType: entityTypeCtrl.text.trim(),
      entityId: entityIdCtrl.text.trim(),
    );
    if (!mounted) return;
    if (r.success) {
      _snack('تمّت المطابقة');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: err ? AC.err : AC.ok,
      content: Text(msg, style: TextStyle(color: AC.tp)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'التغذية البنكية (Bank Feeds)',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'ربط حساب',
              icon: Icons.add_link,
              onPressed: _connect,
            ),
          ],
        ),
        if (!_loading) _statsBar(),
        TabBar(
          controller: _tabs,
          labelColor: AC.gold,
          unselectedLabelColor: AC.ts,
          indicatorColor: AC.gold,
          tabs: [
            Tab(text: 'الاتصالات (${_connections.length})'),
            Tab(text: 'المعاملات (${_transactions.length})'),
          ],
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _statsBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AC.navy2,
      child: Wrap(spacing: 12, runSpacing: 8, children: [
        _stat('الاتصالات', _stats['total']?.toString() ?? '0', AC.cyan),
        _stat('متّصلة', _stats['connected']?.toString() ?? '0', AC.ok),
        _stat('فصلت', _stats['disconnected']?.toString() ?? '0', AC.ts),
        _stat('معاملات', _stats['transactions_total']?.toString() ?? '0', AC.tp),
        _stat('مطابَقة', _stats['transactions_reconciled']?.toString() ?? '0', AC.gold),
        if (_providers.isNotEmpty) _stat('Providers', _providers.length.toString(), AC.warn),
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

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    return TabBarView(
      controller: _tabs,
      children: [_connectionsList(), _transactionsList()],
    );
  }

  Widget _connectionsList() {
    if (_connections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.account_balance_outlined, size: 56, color: AC.ts),
            const SizedBox(height: 12),
            Text('لا توجد اتصالات بنكية بعد',
                style: TextStyle(color: AC.ts, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.add_link, size: 14),
              label: const Text('ربط أوّل حساب'),
            ),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _connections.length,
        itemBuilder: (ctx, i) => _connectionCard(_connections[i]),
      ),
    );
  }

  Widget _connectionCard(Map<String, dynamic> c) {
    final status = (c['status'] ?? 'connected').toString();
    final color = switch (status) {
      'connected' => AC.ok,
      'disconnected' => AC.ts,
      'reauth' => AC.warn,
      'error' => AC.err,
      _ => AC.tp,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                c['account_name']?.toString() ?? '—',
                style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold),
              ),
              Text(
                '${c['bank_name'] ?? ''} · ${c['provider']} · ${c['currency']}',
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (c['iban_masked'] != null) _meta(c['iban_masked'].toString(), AC.cyan),
          if (c['tenant_id'] != null) _meta('tenant: ${c['tenant_id']}', AC.gold),
          if (c['last_synced_at'] != null)
            _meta('آخر مزامنة: ${c['last_synced_at'].toString().substring(0, 16)}', AC.ts),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (status == 'connected')
            OutlinedButton.icon(
              onPressed: () => _sync(c),
              icon: const Icon(Icons.sync, size: 14),
              label: const Text('مزامنة'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.cyan),
                foregroundColor: AC.cyan,
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _filterConnId = c['id'].toString();
                _tabs.animateTo(1);
              });
              _load();
            },
            icon: const Icon(Icons.list_alt, size: 14),
            label: const Text('المعاملات'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.tp),
              foregroundColor: AC.tp,
            ),
          ),
          if (status == 'connected')
            OutlinedButton.icon(
              onPressed: () => _disconnect(c),
              icon: const Icon(Icons.link_off, size: 14),
              label: const Text('فصل'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.warn),
                foregroundColor: AC.warn,
              ),
            ),
        ]),
      ]),
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

  Widget _transactionsList() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        color: AC.navy2,
        child: Row(children: [
          if (_filterConnId != null)
            Chip(
              backgroundColor: AC.cyan.withValues(alpha: 0.18),
              label: Text(
                'connection: ${_filterConnId!.substring(0, 8)}...',
                style: TextStyle(color: AC.cyan, fontSize: 11),
              ),
              onDeleted: () {
                setState(() => _filterConnId = null);
                _load();
              },
            ),
          const SizedBox(width: 12),
          Switch(
            value: _onlyUnreconciled,
            activeColor: AC.gold,
            onChanged: (v) {
              setState(() => _onlyUnreconciled = v);
              _load();
            },
          ),
          Text('غير المطابقة فقط', style: TextStyle(color: AC.ts, fontSize: 12)),
        ]),
      ),
      Expanded(
        child: _transactions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined, size: 56, color: AC.ts),
                    const SizedBox(height: 12),
                    Text('لا توجد معاملات',
                        style: TextStyle(color: AC.ts, fontSize: 13)),
                  ]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _transactions.length,
                itemBuilder: (ctx, i) => _txnRow(_transactions[i]),
              ),
      ),
    ]);
  }

  Widget _txnRow(Map<String, dynamic> t) {
    final reconciled = t['matched_entity_id'] != null;
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
    final isCredit = amount >= 0;
    final color = isCredit ? AC.ok : AC.err;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: reconciled ? AC.ok.withValues(alpha: 0.4) : AC.bdr,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                amount.toStringAsFixed(2),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                t['currency']?.toString() ?? '',
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
              const Spacer(),
              Text(
                t['posting_date']?.toString() ?? '',
                style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              t['description']?.toString() ?? '—',
              style: TextStyle(color: AC.tp, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (t['reference'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'ref: ${t['reference']}',
                style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
            if (reconciled) ...[
              const SizedBox(height: 4),
              Text(
                '✓ ${t['matched_entity_type']}/${t['matched_entity_id']?.toString().substring(0, 12)}...',
                style: TextStyle(color: AC.ok, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        if (!reconciled)
          IconButton(
            tooltip: 'مطابقة',
            onPressed: () => _reconcile(t),
            icon: Icon(Icons.link, color: AC.gold, size: 18),
          )
        else
          Icon(Icons.check_circle, color: AC.ok, size: 18),
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
}
