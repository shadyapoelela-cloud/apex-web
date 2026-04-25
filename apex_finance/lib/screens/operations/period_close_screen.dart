/// APEX — Period Close Checklist (NetSuite pattern)
/// ═══════════════════════════════════════════════════════════
/// Sequenced 12-task close workflow with hard dependencies: no task
/// moves forward until its predecessor is signed off. Progress bar
/// + completion %, per-task status chips, inline notes.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class PeriodCloseScreen extends StatefulWidget {
  const PeriodCloseScreen({super.key});
  @override
  State<PeriodCloseScreen> createState() => _PeriodCloseScreenState();
}

class _PeriodCloseScreenState extends State<PeriodCloseScreen> {
  final _tenantCtl = TextEditingController();
  final _entityCtl = TextEditingController();
  final _periodCtl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 7));
  final _fpCtl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _closes = [];
  Map<String, dynamic>? _active;

  @override
  void initState() {
    super.initState();
    // Auto-fill scope from active session.
    if (S.savedTenantId != null) _tenantCtl.text = S.savedTenantId!;
    if (S.savedEntityId != null) _entityCtl.text = S.savedEntityId!;
    if (S.savedTenantId != null || S.savedEntityId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadList());
    }
  }

  @override
  void dispose() {
    _tenantCtl.dispose(); _entityCtl.dispose(); _periodCtl.dispose(); _fpCtl.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.periodCloseList(
      tenantId: _tenantCtl.text.trim().isEmpty ? null : _tenantCtl.text.trim(),
      entityId: _entityCtl.text.trim().isEmpty ? null : _entityCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) {
        _closes = ((r.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      } else {
        _error = r.error;
      }
    });
  }

  Future<void> _start() async {
    if (_tenantCtl.text.trim().isEmpty ||
        _entityCtl.text.trim().isEmpty ||
        _fpCtl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل Tenant + Entity + Fiscal Period IDs');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.periodCloseStart({
      'tenant_id': _tenantCtl.text.trim(),
      'entity_id': _entityCtl.text.trim(),
      'fiscal_period_id': _fpCtl.text.trim(),
      'period_code': _periodCtl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.success && r.data != null) {
      final id = r.data['data']?['close_id'] as String?;
      if (id != null) _openClose(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'فشل')));
    }
  }

  Future<void> _openClose(String id) async {
    final r = await ApiService.periodCloseGet(id);
    if (!mounted) return;
    if (r.success && r.data != null) {
      setState(() => _active = (r.data['data'] as Map).cast<String, dynamic>());
    }
  }

  Future<void> _completeTask(String taskId) async {
    final r = await ApiService.periodCloseCompleteTask(taskId, userId: 'demo-user');
    if (!mounted) return;
    if (r.success && _active != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنجاز المهمة')));
      _openClose(_active!['id'] as String);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'فشل')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('إقفال الفترة المحاسبية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        ),
        body: _active != null ? _detailView() : _listView(),
      ),
    );
  }

  Widget _listView() {
    return Column(
      children: [
        _startForm(),
        if (_error != null) Padding(
          padding: const EdgeInsets.all(10),
          child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _closes.isEmpty
                  ? Center(child: Text('لا توجد عمليات إقفال — ابدأ واحدة',
                      style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _closes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _closeCard(_closes[i]),
                    ),
        ),
      ],
    );
  }

  Widget _startForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AC.navy2,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _f(_tenantCtl, 'Tenant ID')),
            const SizedBox(width: 8),
            Expanded(child: _f(_entityCtl, 'Entity ID')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _f(_fpCtl, 'Fiscal Period ID')),
            const SizedBox(width: 8),
            Expanded(child: _f(_periodCtl, 'رمز الفترة (2026-04)')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            FilledButton.icon(
              onPressed: _loading ? null : _loadList,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('تحميل', style: TextStyle(fontFamily: 'Tajawal')),
              style: FilledButton.styleFrom(backgroundColor: AC.navy3, foregroundColor: AC.tp),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _start,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('بدء إقفال جديد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _closeCard(Map<String, dynamic> c) {
    final pct = (c['progress_pct'] ?? 0) as num;
    final status = c['status'] as String;
    final color = status == 'completed' ? AC.ok : (status == 'in_progress' ? AC.gold : AC.ts);
    return InkWell(
      onTap: () => _openClose(c['id'] as String),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.lock_clock, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text('فترة ${c['period_code']}',
                  style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5)),
              ),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1).toDouble(),
              backgroundColor: AC.navy3,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Text('${c['completed_tasks']}/${c['total_tasks']} — ${pct.toStringAsFixed(0)}%',
                style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _detailView() {
    final c = _active!;
    final tasks = ((c['tasks'] as List?) ?? []).cast<Map<String, dynamic>>();
    final pct = (c['completed_tasks'] as int) / ((c['total_tasks'] as int).clamp(1, 9999)) * 100;
    return Column(
      children: [
        _detailHeader(c, pct),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _taskCard(tasks[i]),
          ),
        ),
      ],
    );
  }

  Widget _detailHeader(Map<String, dynamic> c, double pct) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.15), AC.gold.withValues(alpha: 0.05)]),
        border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward), onPressed: () => setState(() => _active = null),
            ),
            Text('إقفال الفترة ${c['period_code']}',
                style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${c['completed_tasks']}/${c['total_tasks']}',
                style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1).toDouble(),
            backgroundColor: AC.navy3,
            valueColor: AlwaysStoppedAnimation(AC.gold),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Text('تقدم الإقفال: ${pct.toStringAsFixed(0)}%',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12)),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> t) {
    final status = t['status'] as String;
    final colors = <String, Color>{
      'completed': AC.ok, 'pending': AC.gold,
      'blocked': AC.ts, 'in_progress': AC.info,
      'skipped': AC.td,
    };
    final color = colors[status] ?? AC.ts;
    final canComplete = status == 'pending' || status == 'in_progress';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('${t['sequence']}',
                style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t['name_ar']}',
                    style: TextStyle(
                      color: AC.tp, fontFamily: 'Tajawal', fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                    )),
                if (t['description_ar'] != null)
                  Text('${t['description_ar']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
                if (t['completed_at'] != null)
                  Text('أُنجزت ${t['completed_at']}',
                      style: TextStyle(color: AC.ok, fontFamily: 'Tajawal', fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(_statusLabel(status), style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5)),
          ),
          const SizedBox(width: 8),
          if (canComplete)
            FilledButton.icon(
              onPressed: () => _completeTask(t['id'] as String),
              icon: const Icon(Icons.check, size: 14),
              label: const Text('إنجاز', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
              style: FilledButton.styleFrom(
                backgroundColor: AC.ok,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(String s) => {
    'completed': 'مُنجز', 'pending': 'جاهز',
    'blocked': 'محجوب', 'in_progress': 'قيد التنفيذ',
    'skipped': 'تخطّى',
  }[s] ?? s;

  Widget _f(TextEditingController c, String label) => TextField(
    controller: c,
    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11),
      filled: true, fillColor: AC.navy3, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    ),
  );
}
