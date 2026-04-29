/// APEX — Tenant Onboarding Wizard
/// /admin/tenant-onboarding — guided flow that sets up a new tenant
/// end-to-end using every backend Waves 1A-1M built.
///
/// Steps:
///   1. الهوية: tenant_id + display_name + notes
///   2. القطاع: pick one of 5 industry packs (with COA preview + workflow
///      auto-install preview from /api/v1/industry-packs/template-map)
///   3. مراجعة: full plan summary
///   4. تنفيذ: POST /admin/tenants/onboard which atomically:
///        a. registers in tenant_directory (emits tenant.registered)
///        b. applies industry pack (triggers auto-provisioner listener
///           which installs 4 workflow templates + flips coa/widgets
///           flags + emits industry_pack.provisioned)
///   5. النتيجة: success screen with the assignment + workflows installed
///      + links to verify in each subsystem console
///
/// Wave 1N Phase UU.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class TenantOnboardingScreen extends StatefulWidget {
  const TenantOnboardingScreen({super.key});
  @override
  State<TenantOnboardingScreen> createState() => _TenantOnboardingScreenState();
}

class _TenantOnboardingScreenState extends State<TenantOnboardingScreen> {
  int _step = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // Reference data
  List<Map<String, dynamic>> _packs = [];
  Map<String, List<String>> _templateMap = const {};

  // Form state
  final _tenantIdCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _packId;

  // Result
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _tenantIdCtrl.dispose();
    _displayNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureSecretThenLoad() async {
    if (!ApiService.hasAdminSecret) {
      await _promptSecret();
    }
    final r = await Future.wait([
      ApiService.industryPacksList(),
      ApiService.industryPackTemplateMap(),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) {
      _packs = ((r[0].data['packs'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r[0].error ?? 'تعذّر تحميل الحزم';
    }
    if (r[1].success && r[1].data is Map) {
      final raw = (r[1].data['template_map'] as Map?) ?? const {};
      _templateMap = {
        for (final e in raw.entries)
          e.key.toString(): ((e.value as List?) ?? const [])
              .map((x) => x.toString())
              .toList(),
      };
    }
    setState(() => _loading = false);
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

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _tenantIdCtrl.text.trim().isNotEmpty &&
            _displayNameCtrl.text.trim().isNotEmpty;
      case 1:
        return _packId != null;
      case 2:
        return true;
      default:
        return false;
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final r = await ApiService.tenantOnboard({
      'tenant_id': _tenantIdCtrl.text.trim(),
      'display_name': _displayNameCtrl.text.trim(),
      'industry_pack_id': _packId,
      'created_by': 'admin',
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    });
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _result = Map<String, dynamic>.from(r.data as Map);
      _step = 3;
    } else {
      _error = r.error ?? 'فشل التسجيل';
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'استقبال مستأجر جديد',
          actions: [
            ApexToolbarAction(
              label: 'الدليل',
              icon: Icons.list_alt,
              onPressed: () => GoRouter.of(context).go('/admin/tenants'),
            ),
          ],
        ),
        if (_step < 3) _stepIndicator(),
        Expanded(child: _body()),
        if (_step < 3) _actionsBar(),
      ]),
    );
  }

  Widget _stepIndicator() {
    const labels = ['الهوية', 'القطاع', 'المراجعة'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AC.navy2,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          _stepDot(i, labels[i]),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i < _step ? AC.gold : AC.bdr,
              ),
            ),
        ],
      ]),
    );
  }

  Widget _stepDot(int i, String label) {
    final active = i == _step;
    final done = i < _step;
    final color = done ? AC.ok : (active ? AC.gold : AC.ts);
    return GestureDetector(
      onTap: i <= _step ? () => setState(() => _step = i) : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, color: color, size: 14)
                : Text('${i + 1}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AC.err),
              ),
              child: Text(_error!, style: TextStyle(color: AC.err)),
            ),
          switch (_step) {
            0 => _stepIdentity(),
            1 => _stepPack(),
            2 => _stepReview(),
            _ => _stepResult(),
          },
        ],
      ),
    );
  }

  Widget _actionsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AC.navy2,
      child: Row(children: [
        if (_step > 0)
          OutlinedButton.icon(
            onPressed: _submitting ? null : () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back, size: 14),
            label: const Text('السابق'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.bdr),
              foregroundColor: AC.tp,
            ),
          ),
        const Spacer(),
        if (_step < 2)
          ElevatedButton.icon(
            onPressed: _canAdvance ? () => setState(() => _step++) : null,
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('التالي'),
          )
        else
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AC.btnFg),
                  )
                : const Icon(Icons.rocket_launch, size: 14),
            label: const Text('بدء التشغيل'),
            style: ElevatedButton.styleFrom(backgroundColor: AC.ok),
          ),
      ]),
    );
  }

  // ───── Step 0 — Identity ─────

  Widget _stepIdentity() {
    return _card('هوية المستأجر', [
      TextField(
        controller: _tenantIdCtrl,
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        onChanged: (_) => setState(() {}),
        decoration: _input(
          'tenant_id (مطلوب) — معرّف فريد بدون مسافات',
          helper: 'مثال: acme_restaurant, t_2026_0014',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _displayNameCtrl,
        style: TextStyle(color: AC.tp),
        onChanged: (_) => setState(() {}),
        decoration: _input(
          'الاسم التجاري (مطلوب)',
          helper: 'مثال: مطعم Acme — فرع الرياض',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notesCtrl,
        maxLines: 3,
        style: TextStyle(color: AC.tp),
        decoration: _input('ملاحظات (اختياري)'),
      ),
    ]);
  }

  // ───── Step 1 — Pack ─────

  Widget _stepPack() {
    return _card('اختر القطاع', [
      Text(
        'كل حزمة تشمل شجرة حسابات + قواعد أتمتة + widgets — اختيار واحدة يطلق التهيئة التلقائية:',
        style: TextStyle(color: AC.ts, fontSize: 12),
      ),
      const SizedBox(height: 12),
      ..._packs.map(_packTile),
    ]);
  }

  Widget _packTile(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final selected = _packId == id;
    final coaCount = p['coa_account_count'] ?? 0;
    final widgetCount = p['dashboard_widget_count'] ?? 0;
    final autoInstall = (_templateMap[id] ?? const []).length;
    final iconForPack = switch (id) {
      'fnb_retail' => Icons.restaurant,
      'construction' => Icons.construction,
      'medical' => Icons.medical_services,
      'logistics' => Icons.local_shipping,
      'services' => Icons.engineering,
      _ => Icons.business_center,
    };
    final color = switch (id) {
      'fnb_retail' => AC.warn,
      'construction' => Colors.orange,
      'medical' => AC.cyan,
      'logistics' => AC.gold,
      'services' => AC.ok,
      _ => AC.tp,
    };
    return InkWell(
      onTap: () => setState(() => _packId = id),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : AC.bdr,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(iconForPack, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                p['name_ar']?.toString() ?? id,
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.md,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p['description']?.toString() ?? '',
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _miniMeta('$coaCount حساب', AC.cyan),
                _miniMeta('$widgetCount widget', AC.gold),
                _miniMeta('$autoInstall قاعدة تلقائية', AC.warn),
              ]),
            ]),
          ),
          if (selected)
            Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }

  Widget _miniMeta(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );

  // ───── Step 2 — Review ─────

  Widget _stepReview() {
    final pack = _packs.firstWhere(
      (p) => p['id'].toString() == _packId,
      orElse: () => const {},
    );
    final auto = _templateMap[_packId] ?? const [];
    return _card('مراجعة قبل التنفيذ', [
      Text(
        'سيُنفَّذ ما يلي بشكل ذرّي عند الضغط على "بدء التشغيل":',
        style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13),
      ),
      const SizedBox(height: 12),
      _reviewSection('1. تسجيل في الدليل', [
        _reviewRow('tenant_id', _tenantIdCtrl.text.trim()),
        _reviewRow('الاسم', _displayNameCtrl.text.trim()),
        if (_notesCtrl.text.trim().isNotEmpty)
          _reviewRow('ملاحظات', _notesCtrl.text.trim()),
        _reviewRow('emits', 'tenant.registered'),
      ]),
      const SizedBox(height: 12),
      _reviewSection('2. تطبيق حزمة القطاع', [
        _reviewRow('pack_id', _packId ?? ''),
        _reviewRow('الاسم', pack['name_ar']?.toString() ?? ''),
        _reviewRow('emits', 'industry_pack.applied'),
      ]),
      const SizedBox(height: 12),
      _reviewSection('3. التهيئة التلقائية (مُحفَّزة بالحدث)', [
        _reviewRow('coa_seeded', '✓ flag flipped'),
        _reviewRow('widgets_provisioned', '✓ flag flipped'),
        _reviewRow('قواعد سيُتم تثبيتها', '${auto.length}'),
        for (final tid in auto) _reviewRow('  •', tid),
        _reviewRow('emits', 'industry_pack.provisioned'),
      ]),
    ]);
  }

  Widget _reviewSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: AC.tp, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        ...children,
      ]),
    );
  }

  Widget _reviewRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 160,
          child: Text(k,
              style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
        ),
        Expanded(
          child: Text(
            v.isEmpty ? '—' : v,
            style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ]),
    );
  }

  // ───── Step 3 — Result ─────

  Widget _stepResult() {
    if (_result == null) return const SizedBox.shrink();
    final tenant = (_result!['tenant'] as Map?) ?? const {};
    final assignment = (_result!['assignment'] as Map?) ?? const {};
    final tid = (tenant['tenant_id'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AC.ok.withValues(alpha: 0.18), AC.navy2],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.task_alt, color: AC.ok, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'تم استقبال المستأجر بنجاح',
                    style: TextStyle(
                      color: AC.ok,
                      fontWeight: FontWeight.w900,
                      fontSize: AppFontSize.xl,
                    ),
                  ),
                  Text(
                    '${tenant['display_name']} ($tid)',
                    style: TextStyle(color: AC.tp, fontSize: 12),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          _card('تفاصيل التنفيذ', [
            _reviewRow('tenant_id', tid),
            _reviewRow('display_name', (tenant['display_name'] ?? '').toString()),
            _reviewRow('industry_pack_id',
                (tenant['industry_pack_id'] ?? '').toString()),
            _reviewRow('coa_seeded',
                (assignment['coa_seeded'] == true) ? '✓ نعم' : '✗ لا'),
            _reviewRow('widgets_provisioned',
                (assignment['widgets_provisioned'] == true) ? '✓ نعم' : '✗ لا'),
          ]),
          const SizedBox(height: AppSpacing.md),
          _card('تحقّق في وحدات الإدارة', [
            _link('دليل المستأجرين', Icons.list_alt, '/admin/tenants'),
            _link('حزم القطاعات', Icons.business_center, '/admin/industry-packs'),
            _link('قواعد الأتمتة', Icons.auto_awesome_motion, '/admin/workflow/rules?tenant_id=$tid'),
            _link('الأحداث', Icons.timeline, '/admin/events'),
          ]),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _step = 0;
                  _tenantIdCtrl.clear();
                  _displayNameCtrl.clear();
                  _notesCtrl.clear();
                  _packId = null;
                  _result = null;
                });
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('استقبال مستأجر آخر'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.cyan),
                foregroundColor: AC.cyan,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => GoRouter.of(context).go('/admin/tenants'),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('فتح الدليل'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _link(String label, IconData icon, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton.icon(
        onPressed: () => GoRouter.of(context).go(route),
        icon: Icon(icon, color: AC.cyan, size: 16),
        label: Text(label, style: TextStyle(color: AC.tp, fontSize: 12)),
        style: TextButton.styleFrom(alignment: Alignment.centerRight),
      ),
    );
  }

  // ───── Helpers ─────

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  InputDecoration _input(String label, {String? helper}) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        helperText: helper,
        helperStyle: TextStyle(color: AC.ts.withValues(alpha: 0.7), fontSize: 10),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      );
}
