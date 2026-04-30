/// APEX — Period Close Interactive Checklist
/// /admin/period-close — drives the 12-task period close cycle defined in
/// `app/core/period_close.py`.
///
/// Wired to Wave 1T Phase AAA backend:
///   POST   /admin/period-close/start
///   POST   /admin/period-close/tasks/{id}/complete
///   GET    /admin/period-close/{close_id}
///   GET    /admin/period-close
///   GET    /admin/period-close/templates/default
///
/// Layout: master-detail. Left: list of close cycles per tenant. Right:
/// task-by-task checklist for the selected cycle. Tasks gate each other
/// via depends_on_ids — blocked tasks render disabled until their deps
/// complete. The 12 default tasks include: TB review, FX revaluation,
/// accruals, intercompany, inventory, payroll accrual, ZATCA filing,
/// period lock, reports, final sign-off.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class AdminPeriodCloseScreen extends StatefulWidget {
  const AdminPeriodCloseScreen({super.key});
  @override
  State<AdminPeriodCloseScreen> createState() => _AdminPeriodCloseScreenState();
}

class _AdminPeriodCloseScreenState extends State<AdminPeriodCloseScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _closes = [];
  Map<String, dynamic>? _selectedClose;
  final _tenantFilterCtrl = TextEditingController();
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _tenantFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureSecretThenLoad() async {
    if (!ApiService.hasAdminSecret) {
      await _promptSecret();
    }
    await _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ApiService.adminPeriodCloseList(
      tenantId: _tenantFilterCtrl.text.trim().isEmpty
          ? null
          : _tenantFilterCtrl.text.trim(),
    );
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _closes = ((r.data['closes'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r.error ?? 'تعذّر التحميل';
    }
    // Refresh selected close
    if (_selectedClose != null) {
      final cid = _selectedClose!['id']?.toString();
      if (cid != null) {
        final r2 = await ApiService.adminPeriodCloseGet(cid);
        if (r2.success && r2.data is Map) {
          _selectedClose = Map<String, dynamic>.from(r2.data['close'] as Map);
        }
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _startNew() async {
    final tenantCtrl = TextEditingController();
    final entityCtrl = TextEditingController();
    final fpCtrl = TextEditingController();
    final periodCtrl = TextEditingController(text: _suggestPeriod());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('بدء دورة إقفال جديدة', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('سيُنشئ النظام ١٢ مهمّة افتراضية مرتّبة حسب التبعيّات.',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(controller: tenantCtrl, style: TextStyle(color: AC.tp), decoration: _input('tenant_id')),
            const SizedBox(height: 8),
            TextField(controller: entityCtrl, style: TextStyle(color: AC.tp), decoration: _input('entity_id')),
            const SizedBox(height: 8),
            TextField(controller: fpCtrl, style: TextStyle(color: AC.tp), decoration: _input('fiscal_period_id')),
            const SizedBox(height: 8),
            TextField(controller: periodCtrl,
                style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
                decoration: _input('period_code (مثلاً 2026-03)')),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بدء'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _starting = true);
    final r = await ApiService.adminPeriodCloseStart({
      'tenant_id': tenantCtrl.text.trim(),
      'entity_id': entityCtrl.text.trim(),
      'fiscal_period_id': fpCtrl.text.trim(),
      'period_code': periodCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _starting = false);
    if (r.success) {
      _snack('تم إنشاء دورة الإقفال بـ ١٢ مهمّة');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  Future<void> _completeTask(Map<String, dynamic> task) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إنهاء: ${task['name_ar']}', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (task['description_ar'] != null)
              Text(task['description_ar'].toString(),
                  style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              style: TextStyle(color: AC.tp),
              decoration: _input('ملاحظات (اختياري)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.ok),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إنهاء المهمّة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.adminPeriodCloseCompleteTask(task['id'].toString(), {
      'user_id': 'admin',
      if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
    });
    if (!mounted) return;
    if (r.success) {
      _snack('تم إنهاء "${task['name_ar']}"');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  String _suggestPeriod() {
    final now = DateTime.now();
    final m = now.month - 1;
    return m == 0
        ? '${now.year - 1}-12'
        : '${now.year}-${m.toString().padLeft(2, '0')}';
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
          title: 'دورة الإقفال المحاسبي',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'دورة جديدة',
              icon: Icons.add_task,
              onPressed: _starting ? () {} : _startNew,
            ),
            ApexToolbarAction(
              label: 'قفل الفترة',
              icon: Icons.lock,
              onPressed: () =>
                  GoRouter.of(context).go('/admin/period-locks'),
            ),
          ],
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 900;
      if (wide) {
        return Row(children: [
          SizedBox(width: 360, child: _closesList()),
          Container(width: 1, color: AC.bdr),
          Expanded(child: _detail()),
        ]);
      }
      return _selectedClose != null ? _detail() : _closesList();
    });
  }

  Widget _closesList() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: TextField(
          controller: _tenantFilterCtrl,
          style: TextStyle(color: AC.tp, fontSize: 13),
          decoration: _input('tenant_id (فلتر)').copyWith(
            suffixIcon: IconButton(
              icon: Icon(Icons.search, color: AC.cyan, size: 18),
              onPressed: _load,
            ),
          ),
          onSubmitted: (_) => _load(),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      Expanded(
        child: _closes.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_busy, size: 56, color: AC.ts),
                  const SizedBox(height: 12),
                  Text('لا توجد دورات إقفال نشطة',
                      style: TextStyle(color: AC.ts, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _startNew,
                    icon: const Icon(Icons.add_task, size: 14),
                    label: const Text('بدء أوّل دورة'),
                  ),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _closes.length,
                itemBuilder: (ctx, i) => _closeListItem(_closes[i]),
              ),
      ),
    ]);
  }

  Widget _closeListItem(Map<String, dynamic> c) {
    final isSelected = _selectedClose?['id'] == c['id'];
    final status = (c['status'] ?? 'in_progress').toString();
    final color = switch (status) {
      'completed' => AC.ok,
      'cancelled' => AC.ts,
      _ => AC.warn,
    };
    final tasks = ((c['tasks'] as List?) ?? const []).cast<dynamic>();
    final completed = tasks
        .where((t) => (t as Map)['status'] == 'completed')
        .length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return InkWell(
      onTap: () async {
        final r = await ApiService.adminPeriodCloseGet(c['id'].toString());
        if (!mounted) return;
        if (r.success && r.data is Map) {
          setState(() => _selectedClose = Map<String, dynamic>.from(r.data['close'] as Map));
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : AC.bdr,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_note, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              c['period_code']?.toString() ?? '—',
              style: TextStyle(
                color: AC.tp,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                status,
                style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('tenant: ${c['tenant_id']}',
              style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AC.navy3,
              color: color,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completed / $total مهمّة',
            style: TextStyle(color: AC.ts, fontSize: 10),
          ),
        ]),
      ),
    );
  }

  Widget _detail() {
    if (_selectedClose == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_note, size: 56, color: AC.ts),
            const SizedBox(height: 12),
            Text(
              'اختر دورة إقفال من القائمة لرؤية المهام',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.ts),
            ),
          ]),
        ),
      );
    }
    final close = _selectedClose!;
    final tasks = ((close['tasks'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    tasks.sort((a, b) =>
        ((a['sequence'] ?? 0) as num).compareTo((b['sequence'] ?? 0) as num));
    final completed =
        tasks.where((t) => t['status'] == 'completed').length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.18), AC.navy2],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.event_note, color: AC.gold, size: 28),
              const SizedBox(width: 10),
              Text(
                close['period_code']?.toString() ?? '',
                style: TextStyle(
                  color: AC.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: AppFontSize.xl,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$completed / ${tasks.length} مكتمل',
                  style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'tenant: ${close['tenant_id']} · entity: ${close['entity_id']}',
              style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace'),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < tasks.length; i++) _taskCard(tasks[i], i, tasks),
      ]),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, int index, List<Map<String, dynamic>> all) {
    final status = (task['status'] ?? 'pending').toString();
    final color = switch (status) {
      'completed' => AC.ok,
      'blocked' => AC.ts,
      'in_progress' => AC.cyan,
      _ => AC.warn,
    };
    final isBlocked = status == 'blocked';
    final isDone = status == 'completed';
    final canComplete = status == 'pending' || status == 'in_progress';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: isBlocked ? 0.2 : 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check, color: color, size: 16)
                : Text(
                    '${task['sequence'] ?? (index + 1)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              task['name_ar']?.toString() ?? '',
              style: TextStyle(
                color: AC.tp,
                fontWeight: FontWeight.bold,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: AC.ok,
              ),
            ),
            if (task['description_ar'] != null) ...[
              const SizedBox(height: 4),
              Text(
                task['description_ar'].toString(),
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (task['completed_at'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AC.ts.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    task['completed_at'].toString().substring(0, 16),
                    style: TextStyle(color: AC.ts, fontSize: 9, fontFamily: 'monospace'),
                  ),
                ),
              if (task['completed_by'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AC.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'by: ${task['completed_by']}',
                    style: TextStyle(color: AC.cyan, fontSize: 9, fontFamily: 'monospace'),
                  ),
                ),
            ]),
            if (task['notes'] != null && task['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AC.navy3,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  task['notes'].toString(),
                  style: TextStyle(color: AC.ts, fontSize: 11),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        if (canComplete)
          ElevatedButton.icon(
            onPressed: () => _completeTask(task),
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إنهاء'),
            style: ElevatedButton.styleFrom(backgroundColor: AC.ok),
          )
        else if (isBlocked)
          Tooltip(
            message: 'بانتظار إنهاء المهام السابقة',
            child: Icon(Icons.lock_outline, color: AC.ts, size: 18),
          ),
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
