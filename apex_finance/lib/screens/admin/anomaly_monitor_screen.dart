/// APEX — Anomaly Live Monitor
/// /admin/anomaly — buffer state + on-demand scans + findings.
///
/// Wired to Wave 1B Phase K backend:
///   GET  /admin/anomaly/buffer?tenant_id=
///   POST /admin/anomaly/scan?tenant_id=&emit_events=
///   POST /admin/anomaly/scan-all
///   POST /admin/anomaly/clear-buffer?tenant_id=
///
/// The detector is hooked to event_bus listeners on je.posted /
/// payment.received / bill.approved / invoice.posted. Each fired event
/// records the txn into a tenant ring buffer (cap 500). Admin clicks
/// "Scan" → backend runs the pure-function pattern detector on the
/// buffer, emits anomaly.detected for medium+ findings, and returns a
/// findings list rendered here color-coded by severity.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class AnomalyMonitorScreen extends StatefulWidget {
  const AnomalyMonitorScreen({super.key});
  @override
  State<AnomalyMonitorScreen> createState() => _AnomalyMonitorScreenState();
}

class _AnomalyMonitorScreenState extends State<AnomalyMonitorScreen> {
  bool _loading = true;
  bool _scanning = false;
  String? _error;
  int _bufferSize = 0;
  String? _scannedTenant;
  int _scannedTxnCount = 0;
  Map<String, int> _bySeverity = {};
  List<Map<String, dynamic>> _findings = [];
  String? _scannedAt;
  final _tenantCtrl = TextEditingController();
  bool _emitEvents = true;

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _tenantCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureSecretThenLoad() async {
    if (!ApiService.hasAdminSecret) {
      await _promptSecret();
    }
    await _loadBuffer();
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

  Future<void> _loadBuffer() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final tenantId = _tenantCtrl.text.trim().isEmpty ? null : _tenantCtrl.text.trim();
    final r = await ApiService.anomalyBuffer(tenantId: tenantId);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _bufferSize = (r.data['size'] ?? 0) as int;
    } else {
      _error = r.error ?? 'تعذّر جلب حجم الذاكرة';
    }
    setState(() => _loading = false);
  }

  Future<void> _runScan({bool all = false}) async {
    final tenantId = _tenantCtrl.text.trim();
    if (!all && tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أدخل tenant_id أولاً', style: TextStyle(color: AC.tp))),
      );
      return;
    }
    setState(() {
      _scanning = true;
      _error = null;
    });
    final r = all
        ? await ApiService.anomalyScanAll(emitEvents: _emitEvents)
        : await ApiService.anomalyScan(tenantId, emitEvents: _emitEvents);
    if (!mounted) return;
    if (!r.success) {
      _error = r.error ?? 'فشل المسح';
      setState(() => _scanning = false);
      return;
    }
    if (all) {
      // scan-all returns aggregated results — show first non-empty + total counts
      _scannedTenant = '(جميع المستأجرين)';
      _scannedTxnCount = (r.data['total_txns'] ?? 0) as int;
      _findings = [];
      _bySeverity = {};
      final results = (r.data['results'] as List?) ?? const [];
      for (final res in results) {
        final m = Map<String, dynamic>.from(res as Map);
        final findings = (m['findings'] as List?) ?? const [];
        for (final f in findings) {
          final fm = Map<String, dynamic>.from(f as Map);
          fm['_tenant'] = m['tenant_id'];
          _findings.add(fm);
        }
        final by = (m['by_severity'] as Map?) ?? const {};
        for (final e in by.entries) {
          _bySeverity[e.key.toString()] = (_bySeverity[e.key.toString()] ?? 0) + (e.value as int);
        }
      }
      _scannedAt = DateTime.now().toIso8601String();
    } else {
      _scannedTenant = tenantId;
      _scannedTxnCount = (r.data['txn_count'] ?? 0) as int;
      _findings = ((r.data['findings'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _bySeverity = {};
      final by = (r.data['by_severity'] as Map?) ?? const {};
      for (final e in by.entries) {
        _bySeverity[e.key.toString()] = (e.value as int);
      }
      _scannedAt = (r.data['scanned_at'] ?? DateTime.now().toIso8601String()) as String;
    }
    setState(() => _scanning = false);
    await _loadBuffer();
  }

  Future<void> _clearBuffer() async {
    final tenantId = _tenantCtrl.text.trim().isEmpty ? null : _tenantCtrl.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('مسح الذاكرة المؤقّتة',
            style: TextStyle(color: AC.tp)),
        content: Text(
          tenantId == null
              ? 'سيتم مسح ذاكرة جميع المستأجرين. هل أنت متأكد؟'
              : 'سيتم مسح ذاكرة المستأجر $tenantId. هل أنت متأكد؟',
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
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.anomalyClearBuffer(tenantId: tenantId);
    if (!mounted) return;
    if (r.success) {
      _findings = [];
      _bySeverity = {};
      _scannedTxnCount = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم المسح', style: TextStyle(color: AC.tp))),
      );
      await _loadBuffer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(r.error ?? 'فشل المسح')),
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
            title: 'مراقب الشذوذ الحيّ',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _loadBuffer,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(),
          const SizedBox(height: AppSpacing.md),
          _controls(),
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
          if (_scannedAt != null) _findingsBlock(),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AC.warn.withValues(alpha: 0.18), AC.navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AC.warn.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.radar, color: AC.warn, size: 28),
          const SizedBox(width: 10),
          Text(
            'الذاكرة المؤقّتة الحيّة',
            style: TextStyle(
              color: AC.warn,
              fontWeight: FontWeight.w900,
              fontSize: AppFontSize.xl,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _heroFact('معاملات في الذاكرة',
              _bufferSize.toString() + (_tenantCtrl.text.trim().isEmpty ? ' (جميع المستأجرين)' : ' (${_tenantCtrl.text.trim()})'),
              AC.cyan),
          _heroFact('السقف لكل مستأجر', '500', AC.tp),
          _heroFact('الأحداث المراقَبة', 'je.posted, payment.received, bill.approved, invoice.posted', AC.gold),
        ]),
      ]),
    );
  }

  Widget _heroFact(String label, String value, Color c) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
      Flexible(
        child: Text(
          value,
          style: TextStyle(
            color: c,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    ]);
  }

  Widget _controls() {
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
          Row(children: [
            Expanded(
              child: TextField(
                controller: _tenantCtrl,
                style: TextStyle(color: AC.tp, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'tenant_id (اتركه فارغاً للجميع)',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _loadBuffer(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loadBuffer,
              icon: Icon(Icons.search, color: AC.cyan),
              tooltip: 'فحص الذاكرة',
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Switch(
              value: _emitEvents,
              activeColor: AC.gold,
              onChanged: (v) => setState(() => _emitEvents = v),
            ),
            Text(
              'إصدار أحداث anomaly.detected',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: _scanning ? null : () => _runScan(),
              icon: _scanning
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AC.tp,
                      ),
                    )
                  : const Icon(Icons.policy, size: 16),
              label: const Text('مسح المستأجر'),
            ),
            OutlinedButton.icon(
              onPressed: _scanning ? null : () => _runScan(all: true),
              icon: const Icon(Icons.public, size: 16),
              label: const Text('مسح الجميع'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.cyan),
                foregroundColor: AC.cyan,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _clearBuffer,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('مسح الذاكرة'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.err),
                foregroundColor: AC.err,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _findingsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AC.bdr),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'نتائج المسح — $_scannedTenant ($_scannedTxnCount معاملة)',
              style: TextStyle(
                color: AC.gold,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _sevChip('low', _bySeverity['low'] ?? 0, AC.ts),
              _sevChip('medium', _bySeverity['medium'] ?? 0, AC.warn),
              _sevChip('high', _bySeverity['high'] ?? 0, Colors.orange),
              _sevChip('critical', _bySeverity['critical'] ?? 0, AC.err),
            ]),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_findings.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '✓ لم يتم اكتشاف أي شذوذ',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.ok, fontSize: 14),
            ),
          )
        else
          ..._findings.map(_findingCard),
      ],
    );
  }

  Widget _sevChip(String label, int count, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: c),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
          Text(
            count.toString(),
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ]),
      );

  Widget _findingCard(Map<String, dynamic> f) {
    final sev = (f['severity'] ?? 'low').toString();
    final color = switch (sev) {
      'critical' => AC.err,
      'high' => Colors.orange,
      'medium' => AC.warn,
      _ => AC.ts,
    };
    final txnIds = ((f['transaction_ids'] as List?) ?? const [])
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
                sev.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (f['type'] ?? '—').toString(),
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            if (f['_tenant'] != null)
              Text(
                'tenant: ${f['_tenant']}',
                style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace'),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
            (f['message_ar'] ?? '').toString(),
            style: TextStyle(color: AC.ts, fontSize: 12),
          ),
          if (txnIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final id in txnIds.take(8))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AC.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    id,
                    style: TextStyle(
                      color: AC.cyan,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              if (txnIds.length > 8)
                Text('+${txnIds.length - 8}',
                    style: TextStyle(color: AC.ts, fontSize: 10)),
            ]),
          ],
        ],
      ),
    );
  }
}
