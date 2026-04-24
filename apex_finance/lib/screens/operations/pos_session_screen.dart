/// APEX — POS Sessions
/// ═══════════════════════════════════════════════════════════
/// Lists POS sessions for a branch, opens Z-report, lets user close
/// a session and post-to-GL the resulting transactions.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class PosSessionScreen extends StatefulWidget {
  const PosSessionScreen({super.key});
  @override
  State<PosSessionScreen> createState() => _PosSessionScreenState();
}

class _PosSessionScreenState extends State<PosSessionScreen> {
  final _branchCtl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _zReport;

  @override
  void dispose() {
    _branchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_branchCtl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل Branch ID');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.pilotListPosSessions(_branchCtl.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) {
        final list = r.data is List ? r.data : (r.data['data'] as List? ?? []);
        _sessions = (list as List).cast<Map<String, dynamic>>();
      } else {
        _error = r.error;
      }
    });
  }

  Future<void> _openSession() async {
    final r = await ApiService.pilotCreatePosSession(
      _branchCtl.text.trim(),
      {'opening_cash': 0},
    );
    if (!mounted) return;
    final msg = r.success ? 'تم فتح جلسة جديدة' : (r.error ?? 'فشل');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _load();
  }

  Future<void> _viewZReport(String sessionId) async {
    final r = await ApiService.pilotZReport(sessionId);
    if (!mounted) return;
    if (r.success) {
      setState(() => _zReport = (r.data as Map).cast<String, dynamic>());
    }
  }

  Future<void> _closeSession(String sessionId) async {
    final r = await ApiService.pilotClosePosSession(sessionId, {'closing_cash': 0});
    if (!mounted) return;
    final msg = r.success ? 'تم قفل الجلسة' : (r.error ?? 'فشل القفل');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('جلسات نقاط البيع',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            _toolbar(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(flex: 2, child: _sessionList()),
                        if (_zReport != null)
                          Expanded(
                            flex: 3,
                            child: _zReportPanel(),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: AC.navy2,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _branchCtl,
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Branch ID',
                labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
                filled: true, fillColor: AC.navy3, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('تحميل', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.navy3, foregroundColor: AC.tp),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _branchCtl.text.trim().isEmpty ? null : _openSession,
            icon: const Icon(Icons.add_shopping_cart, size: 16),
            label: const Text('جلسة جديدة', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
        ],
      ),
    );
  }

  Widget _sessionList() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.point_of_sale, color: AC.ts, size: 48),
            const SizedBox(height: 10),
            Text('لا توجد جلسات', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = _sessions[i];
        final status = (s['status'] ?? '') as String;
        final color = status == 'open' ? AC.ok : (status == 'closed' ? AC.ts : AC.gold);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.point_of_sale, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جلسة ${s['id']?.toString().substring(0, 8)}',
                        style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text('افتُتحت ${s['opened_at'] ?? ''}',
                        style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(status, style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.summarize_outlined, color: AC.gold, size: 18),
                tooltip: 'Z-report',
                onPressed: () => _viewZReport(s['id'] as String),
              ),
              if (status == 'open')
                IconButton(
                  icon: Icon(Icons.lock_outline, color: AC.err, size: 18),
                  tooltip: 'قفل الجلسة',
                  onPressed: () => _closeSession(s['id'] as String),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _zReportPanel() {
    final r = _zReport!;
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.summarize, color: AC.gold),
            const SizedBox(width: 8),
            Text('تقرير Z', style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _zReport = null)),
          ]),
          Divider(color: AC.gold.withValues(alpha: 0.2)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: r.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${e.key}',
                          style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12))),
                      Text('${e.value}',
                          style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
