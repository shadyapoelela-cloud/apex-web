/// APEX — Audit Chain Viewer
/// ═══════════════════════════════════════════════════════════
/// Shows the tamper-evident audit trail: every recent event + its
/// prev_hash → this_hash linkage. The "التحقق من السلامة" button runs
/// the server-side verifier that walks the chain and reports whether
/// any hash was tampered with.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class AuditChainViewerScreen extends StatefulWidget {
  const AuditChainViewerScreen({super.key});
  @override
  State<AuditChainViewerScreen> createState() => _AuditChainViewerScreenState();
}

class _AuditChainViewerScreenState extends State<AuditChainViewerScreen> {
  bool _loading = true;
  bool _verifying = false;
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _verifyResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.aiListAuditEvents(limit: 100);
    if (!mounted) return;
    setState(() {
      _events = ((res.data?['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final res = await ApiService.aiVerifyAuditChain();
    if (!mounted) return;
    setState(() {
      _verifyResult = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      _verifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('سجل التدقيق — السلسلة المشفّرة',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: Column(
          children: [
            _verifyBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _events.isEmpty
                      ? _empty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) => _EventTile(event: _events[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifyBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AC.navy2,
      child: Row(
        children: [
          Expanded(
            child: _verifyResult == null
                ? Text(
                    'اضغط "التحقق من السلامة" لفحص كل سجل ومقارنته بالهاش السابق',
                    style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12.5),
                  )
                : _renderVerifyResult(),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _verifying ? null : _verify,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(_verifying ? '...جاري' : 'التحقق من السلامة',
                style: const TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderVerifyResult() {
    final ok = _verifyResult!['ok'] == true;
    final verified = _verifyResult!['verified'] ?? 0;
    final mismatch = _verifyResult!['first_mismatch'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (ok ? AC.ok : AC.err).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: ok ? AC.ok : AC.err, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'السلسلة سليمة — تم التحقق من $verified سجل'
                  : 'تم اكتشاف عدم تطابق بعد $verified سجل — تحقق فوراً',
              style: TextStyle(
                color: ok ? AC.ok : AC.err,
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (mismatch != null)
            Text(
              ' (id: ${mismatch["id"]})',
              style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, color: AC.ts, size: 48),
          const SizedBox(height: 8),
          Text('لا توجد أحداث مسجّلة بعد',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final action = (event['action'] ?? '') as String;
    final created = (event['created_at'] ?? '') as String;
    final hash = (event['this_hash'] ?? '') as String;
    final prev = (event['prev_hash'] ?? '') as String?;
    final entityType = (event['entity_type'] ?? '') as String?;
    final entityId = (event['entity_id'] ?? '') as String?;
    final seq = event['chain_seq'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AC.gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('#$seq',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action,
                  style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _shortTime(created),
                style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5),
              ),
            ],
          ),
          if (entityType != null && entityType.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$entityType: $entityId',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11),
            ),
          ],
          const SizedBox(height: 6),
          if (prev != null && prev.isNotEmpty)
            _hashRow('prev', prev, AC.td),
          _hashRow('this', hash, AC.ok),
        ],
      ),
    );
  }

  Widget _hashRow(String label, String hash, Color color) {
    final short = hash.length > 16 ? '${hash.substring(0, 8)}…${hash.substring(hash.length - 8)}' : hash;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text(label,
              style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 10))),
          const SizedBox(width: 6),
          Text(short,
              style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 10.5)),
        ],
      ),
    );
  }

  static String _shortTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.split('T').first;
    }
  }
}
