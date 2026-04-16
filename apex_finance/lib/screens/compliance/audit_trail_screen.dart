/// APEX Platform — Audit Trail Screen
/// ═══════════════════════════════════════════════════════════════
/// Verifies the integrity of the immutable audit chain maintained
/// by the backend. Any tampering (row mutation or deletion) makes
/// the SHA-256 chain break, and this screen surfaces the first
/// mismatch with the offending row id.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});
  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  bool _loading = false;
  bool? _ok;
  int? _verified;
  Map<String, dynamic>? _mismatch;
  String? _error;
  int _limit = 1000;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; _mismatch = null; });
    try {
      final r = await ApiService.auditVerify(limit: _limit);
      if (r.success && r.data is Map) {
        final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
        setState(() {
          _ok = d['ok'] == true;
          _verified = d['verified'] as int?;
          final m = d['first_mismatch'];
          _mismatch = m is Map ? m.cast<String, dynamic>() : null;
        });
      } else {
        setState(() => _error = r.error ?? 'فشل التحقق');
      }
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addTestEvent() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.auditLog(
        action: 'test.ui.event',
        entityType: 'test',
        entityId: 'ui-${DateTime.now().millisecondsSinceEpoch}',
        after: {'source': 'audit_trail_screen'},
      );
      if (r.success) {
        final h = (r.data['hash'] ?? '').toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AC.ok,
              content: Text('تم إضافة حدث ·  hash ${h.substring(0, 16)}…',
                style: const TextStyle(color: Colors.white)),
            ),
          );
        }
        await _verify();
      } else {
        setState(() => _error = r.error ?? 'فشل الإضافة');
      }
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('سجل التدقيق (Audit Trail)', style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            tooltip: 'إعادة التحقق',
            onPressed: _loading ? null : _verify,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoBanner(),
            const SizedBox(height: 16),
            if (_loading) const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (!_loading && _ok != null) _statusCard(),
            if (_mismatch != null) ...[
              const SizedBox(height: 16),
              _mismatchCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _errorBanner(_error!),
            ],
            const SizedBox(height: 16),
            _limitSelector(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _addTestEvent,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('إضافة حدث اختبار + إعادة تحقق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.gold.withValues(alpha: 0.06),
      border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.lock_outline, color: AC.gold, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'كل حدث يحمل SHA-256 مربوطاً بالحدث السابق (hash chain). '
            'أي تلاعب بأي صف يكسر السلسلة ويظهر هنا.',
            style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _statusCard() {
    final ok = _ok == true;
    final color = ok ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.verified : Icons.warning_amber_rounded, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'السلسلة سليمة ✓' : 'تحذير: انكسار في السلسلة',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? 'تم التحقق من ${_verified ?? 0} حدث. لا يوجد تلاعب.'
                      : 'تم العثور على عدم تطابق — راجع التفاصيل أدناه',
                  style: TextStyle(color: AC.tp, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mismatchCard() {
    final m = _mismatch!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.err.withValues(alpha: 0.06),
        border: Border.all(color: AC.err.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('تفاصيل عدم التطابق:',
            style: TextStyle(color: AC.err, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...m.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text('${e.key}:',
                    style: TextStyle(color: AC.ts, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text('${e.value}',
                    style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace')),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _limitSelector() => Row(
    children: [
      Text('نطاق التحقق:', style: TextStyle(color: AC.ts, fontSize: 13)),
      const SizedBox(width: 12),
      ...[100, 1000, 5000].map((n) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ChoiceChip(
          label: Text(n.toString()),
          selected: _limit == n,
          onSelected: (_) {
            setState(() => _limit = n);
            _verify();
          },
        ),
      )),
    ],
  );

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.err.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AC.err.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: AC.err, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: AC.err, fontSize: 13))),
      ],
    ),
  );
}
