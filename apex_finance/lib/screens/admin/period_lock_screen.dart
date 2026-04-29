/// APEX — Period Lock Manager
/// /admin/period-locks — accounting close enforcement with auditable overrides.
///
/// Wired to Wave 1Q Phase XX backend:
///   GET    /admin/period-locks?tenant_id=&only_active=
///   GET    /admin/period-locks/stats
///   GET    /admin/period-locks/overrides?...
///   POST   /admin/period-locks                  — lock
///   POST   /admin/period-locks/unlock            — unlock (reason required)
///   POST   /admin/period-locks/check             — simulate posting check
///
/// 3 tabs: Active locks / All history / Override audit log.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class PeriodLockScreen extends StatefulWidget {
  const PeriodLockScreen({super.key});
  @override
  State<PeriodLockScreen> createState() => _PeriodLockScreenState();
}

class _PeriodLockScreenState extends State<PeriodLockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _activeLocks = [];
  List<Map<String, dynamic>> _allLocks = [];
  List<Map<String, dynamic>> _overrides = [];
  String? _filterTenant;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _tabs.dispose();
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
    final r = await Future.wait([
      ApiService.periodLocksStats(),
      ApiService.periodLocksList(tenantId: _filterTenant, onlyActive: true),
      ApiService.periodLocksList(tenantId: _filterTenant, onlyActive: false),
      ApiService.periodLocksOverrides(tenantId: _filterTenant, limit: 200),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) _stats = Map<String, dynamic>.from(r[0].data as Map);
    if (r[1].success && r[1].data is Map) {
      _activeLocks = ((r[1].data['locks'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (r[2].success && r[2].data is Map) {
      _allLocks = ((r[2].data['locks'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (r[3].success && r[3].data is Map) {
      _overrides = ((r[3].data['overrides'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    final anyFail = r.any((x) => !x.success);
    if (anyFail && _allLocks.isEmpty && _stats.isEmpty) {
      _error = 'تعذّر التحميل — تحقّق من X-Admin-Secret';
    }
    setState(() => _loading = false);
  }

  Future<void> _lockNew() async {
    final tenantCtrl = TextEditingController();
    final periodCtrl = TextEditingController(text: _suggestPeriod());
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إقفال فترة محاسبية', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: tenantCtrl,
              style: TextStyle(color: AC.tp),
              decoration: _input('tenant_id'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: periodCtrl,
              style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
              decoration: _input('period_code (مثلاً 2026-03)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: TextStyle(color: AC.tp),
              decoration: _input('ملاحظات (اختياري)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إقفال'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (tenantCtrl.text.trim().isEmpty || periodCtrl.text.trim().isEmpty) {
      _snack('tenant_id + period_code مطلوبان', err: true);
      return;
    }
    final r = await ApiService.periodLockCreate({
      'tenant_id': tenantCtrl.text.trim(),
      'period_code': periodCtrl.text.trim(),
      'locked_by': 'admin',
      if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
    });
    if (!mounted) return;
    if (r.success) {
      _snack('تم إقفال ${periodCtrl.text.trim()} لـ ${tenantCtrl.text.trim()}');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  Future<void> _unlock(Map<String, dynamic> lock) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إعادة فتح الفترة', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'إعادة فتح ${lock['period_code']} لـ ${lock['tenant_id']}.\nالسبب مطلوب وسيُسجَّل في سجلّ التدقيق.',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(color: AC.tp),
              decoration: _input('السبب (مطلوب)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.warn),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فتح'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (reasonCtrl.text.trim().length < 3) {
      _snack('السبب يجب أن يكون 3 أحرف على الأقل', err: true);
      return;
    }
    final r = await ApiService.periodLockUnlock({
      'tenant_id': lock['tenant_id'],
      'period_code': lock['period_code'],
      'unlocked_by': 'admin',
      'reason': reasonCtrl.text.trim(),
    });
    if (!mounted) return;
    if (r.success) {
      _snack('تم إعادة فتح ${lock['period_code']}');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  Future<void> _testCheck() async {
    final tenantCtrl = TextEditingController();
    final periodCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool hasPerm = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          backgroundColor: AC.navy2,
          title: Text('اختبار قاعدة الإقفال', style: TextStyle(color: AC.tp)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('محاكاة محاولة قيد على فترة. النتيجة تُسجَّل في سجلّ التدقيق.',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
              const SizedBox(height: 10),
              TextField(controller: tenantCtrl, style: TextStyle(color: AC.tp), decoration: _input('tenant_id')),
              const SizedBox(height: 8),
              TextField(controller: periodCtrl,
                  style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
                  decoration: _input('period_code')),
              const SizedBox(height: 8),
              TextField(controller: reasonCtrl, maxLines: 2,
                  style: TextStyle(color: AC.tp),
                  decoration: _input('override_reason (اختياري)')),
              const SizedBox(height: 8),
              Row(children: [
                Switch(
                  value: hasPerm,
                  activeColor: AC.gold,
                  onChanged: (v) => setSt(() => hasPerm = v),
                ),
                Text('has_override_permission', style: TextStyle(color: AC.ts, fontSize: 12)),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2, false),
              child: Text('إلغاء', style: TextStyle(color: AC.ts)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx2, true),
              child: const Text('اختبار'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final r = await ApiService.periodLockCheck({
      'tenant_id': tenantCtrl.text.trim(),
      'period_code': periodCtrl.text.trim(),
      'actor_user_id': 'demo_test',
      'object_type': 'je',
      'object_id': 'JE-TEST',
      if (reasonCtrl.text.trim().isNotEmpty) 'override_reason': reasonCtrl.text.trim(),
      'has_override_permission': hasPerm,
    });
    if (!mounted) return;
    if (r.success && r.data is Map) {
      final allowed = r.data['allowed'] == true;
      _snack(
        allowed ? 'مسموح: ${r.data['reason']}' : 'مرفوض: ${r.data['reason']}',
        err: !allowed,
      );
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  String _suggestPeriod() {
    final now = DateTime.now();
    final m = now.month - 1;
    final ym = m == 0 ? '${now.year - 1}-12' : '${now.year}-${m.toString().padLeft(2, '0')}';
    return ym;
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
          title: 'إقفال الفترات المحاسبية',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'إقفال جديد',
              icon: Icons.lock,
              onPressed: _lockNew,
            ),
            ApexToolbarAction(
              label: 'اختبار قاعدة',
              icon: Icons.science,
              onPressed: _testCheck,
            ),
          ],
        ),
        TabBar(
          controller: _tabs,
          labelColor: AC.gold,
          unselectedLabelColor: AC.ts,
          indicatorColor: AC.gold,
          tabs: [
            Tab(text: 'الإقفالات النشطة (${_activeLocks.length})'),
            Tab(text: 'كل التاريخ (${_allLocks.length})'),
            Tab(text: 'سجلّ التدقيق (${_overrides.length})'),
          ],
        ),
        if (!_loading) _statsBar(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _statsBar() {
    final byAction = (_stats['overrides_by_action'] as Map?) ?? const {};
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AC.navy2,
      child: Wrap(spacing: 12, runSpacing: 8, children: [
        _stat('نشطة', _stats['active_locks']?.toString() ?? '0', AC.warn),
        _stat('تاريخ', _stats['unlocked_history']?.toString() ?? '0', AC.ts),
        _stat('محاولات تخطّي', _stats['overrides_total']?.toString() ?? '0', AC.tp),
        _stat('محظورة', byAction['blocked']?.toString() ?? '0', AC.err),
        _stat('مسموح بمبرّر', byAction['allowed_with_override']?.toString() ?? '0', AC.cyan),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      children: [
        _locksList(_activeLocks, showUnlock: true),
        _locksList(_allLocks, showUnlock: false),
        _overridesList(),
      ],
    );
  }

  Widget _locksList(List<Map<String, dynamic>> rows, {required bool showUnlock}) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_open_outlined, size: 56, color: AC.ts),
            const SizedBox(height: 12),
            Text('لا يوجد إقفالات', style: TextStyle(color: AC.ts, fontSize: 13)),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: rows.length,
        itemBuilder: (ctx, i) => _lockCard(rows[i], showUnlock: showUnlock),
      ),
    );
  }

  Widget _lockCard(Map<String, dynamic> lock, {required bool showUnlock}) {
    final isUnlocked = lock['unlocked_at'] != null;
    final color = isUnlocked ? AC.ts : AC.warn;
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
          Icon(isUnlocked ? Icons.lock_open : Icons.lock, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                lock['period_code']?.toString() ?? '—',
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.md,
                ),
              ),
              Text(
                'tenant: ${lock['tenant_id']}',
                style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace'),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              isUnlocked ? 'مفتوحة' : 'مُقفَلة',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _meta('قُفلت: ${(lock['locked_at'] ?? '').toString().substring(0, 16)}', AC.warn),
          if (lock['locked_by'] != null) _meta('بواسطة: ${lock['locked_by']}', AC.cyan),
          if (isUnlocked)
            _meta('فُتحت: ${lock['unlocked_at'].toString().substring(0, 16)}', AC.ts),
          if (lock['unlocked_by'] != null) _meta('فاتح: ${lock['unlocked_by']}', AC.tp),
        ]),
        if ((lock['notes'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(lock['notes'].toString(), style: TextStyle(color: AC.ts, fontSize: 12)),
        ],
        if ((lock['unlock_reason'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AC.warn.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 14, color: AC.warn),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'سبب الفتح: ${lock['unlock_reason']}',
                  style: TextStyle(color: AC.tp, fontSize: 11),
                ),
              ),
            ]),
          ),
        ],
        if (showUnlock && !isUnlocked) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _unlock(lock),
            icon: const Icon(Icons.lock_open, size: 14),
            label: const Text('إعادة فتح (يحتاج سبب)'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.err),
              foregroundColor: AC.err,
            ),
          ),
        ],
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

  Widget _overridesList() {
    if (_overrides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_outlined, size: 56, color: AC.ts),
            const SizedBox(height: 12),
            Text('لا توجد محاولات تخطّي بعد', style: TextStyle(color: AC.ts, fontSize: 13)),
          ]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _overrides.length,
      itemBuilder: (ctx, i) {
        final o = _overrides[i];
        final blocked = o['action'] == 'blocked';
        final color = blocked ? AC.err : AC.cyan;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(blocked ? Icons.block : Icons.check_circle, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                o['action'].toString().toUpperCase(),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const Spacer(),
              Text(
                (o['occurred_at'] ?? '').toString().substring(0, 19),
                style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
              ),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _meta('${o['tenant_id']} / ${o['period_code']}', AC.gold),
              if (o['actor_user_id'] != null) _meta('by ${o['actor_user_id']}', AC.tp),
              if (o['object_type'] != null) _meta('${o['object_type']}/${o['object_id']}', AC.cyan),
            ]),
            if ((o['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(o['reason'].toString(), style: TextStyle(color: AC.ts, fontSize: 11)),
            ],
          ]),
        );
      },
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
