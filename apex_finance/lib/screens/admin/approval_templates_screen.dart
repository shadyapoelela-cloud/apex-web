/// APEX — Approval Chain Templates
/// /admin/approval-templates — browse, apply, and customize multi-stage
/// approval patterns.
///
/// Wired to Wave 1V Phase CCC backend:
///   GET    /api/v1/approval-templates?category=
///   POST   /admin/approval-templates                — create custom
///   DELETE /admin/approval-templates/{id}           — delete custom
///   POST   /admin/approval-templates/{id}/apply     — instantiate
///
/// Ships with 7 built-in templates: CFO sign-off, vendor onboarding,
/// material change, period close sign-off, budget variance review,
/// high-risk transaction, document amendment.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ApprovalTemplatesScreen extends StatefulWidget {
  const ApprovalTemplatesScreen({super.key});
  @override
  State<ApprovalTemplatesScreen> createState() =>
      _ApprovalTemplatesScreenState();
}

class _ApprovalTemplatesScreenState extends State<ApprovalTemplatesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic> _stats = const {};
  String _filterCategory = 'all';

  static const _categories = ['all', 'finance', 'procurement', 'compliance', 'hr', 'ops'];
  static const _categoryLabels = {
    'all': 'الكل',
    'finance': 'مالية',
    'procurement': 'مشتريات',
    'compliance': 'امتثال',
    'hr': 'موارد بشرية',
    'ops': 'عمليات',
  };

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
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
      ApiService.approvalTemplatesList(
        category: _filterCategory == 'all' ? null : _filterCategory,
      ),
      ApiService.approvalTemplatesStats(),
    ]);
    if (!mounted) return;
    if (r[0].success && r[0].data is Map) {
      _templates = ((r[0].data['templates'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _error = r[0].error ?? 'تعذّر تحميل القوالب';
    }
    if (r[1].success && r[1].data is Map) {
      _stats = Map<String, dynamic>.from(r[1].data as Map);
    }
    setState(() => _loading = false);
  }

  Future<void> _apply(Map<String, dynamic> tpl) async {
    final stages = ((tpl['stages'] as List?) ?? const [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    // Collect unique placeholders.
    final placeholders = <String>{};
    for (final s in stages) {
      for (final uid in (s['approver_user_ids'] as List? ?? const [])) {
        final str = uid.toString();
        if (str.startsWith('{') && str.endsWith('}')) {
          placeholders.add(str.substring(1, str.length - 1));
        }
      }
    }
    final titleCtrl = TextEditingController();
    final tenantCtrl = TextEditingController();
    final objIdCtrl = TextEditingController();
    final paramCtrls = {for (final p in placeholders) p: TextEditingController()};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('تطبيق: ${tpl['name_ar']}',
            style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tpl['description_ar']?.toString() ?? '',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: AC.tp),
                decoration: _input('عنوان الموافقة (مطلوب)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tenantCtrl,
                style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
                decoration: _input('tenant_id'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: objIdCtrl,
                style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
                decoration: _input('object_id (اختياري)'),
              ),
              if (placeholders.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AC.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('قيم المتغيّرات (placeholders):',
                        style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final p in placeholders) ...[
                      TextField(
                        controller: paramCtrls[p],
                        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
                        decoration: _input('{$p}'),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ]),
                ),
              ],
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
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty) {
      _snack('العنوان مطلوب', err: true);
      return;
    }
    final params = <String, String>{};
    for (final e in paramCtrls.entries) {
      if (e.value.text.trim().isNotEmpty) params[e.key] = e.value.text.trim();
    }
    final r = await ApiService.approvalTemplateApply(tpl['id'].toString(), {
      'title_ar': titleCtrl.text.trim(),
      if (tenantCtrl.text.trim().isNotEmpty) 'tenant_id': tenantCtrl.text.trim(),
      if (objIdCtrl.text.trim().isNotEmpty) 'object_id': objIdCtrl.text.trim(),
      'parameters': params,
      'requested_by': 'admin',
    });
    if (!mounted) return;
    if (r.success) {
      _snack('تم إنشاء سلسلة موافقة بـ ${r.data['stages_total']} مرحلة');
      await _load();
    } else {
      _snack(r.error ?? 'فشل', err: true);
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> tpl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف القالب', style: TextStyle(color: AC.tp)),
        content: Text(
          'سيتم حذف "${tpl['name_ar']}". لا يمكن التراجع.',
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.approvalTemplateDelete(tpl['id'].toString());
    if (!mounted) return;
    if (r.success) {
      _snack('تم الحذف');
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
          title: 'قوالب سلاسل الموافقات',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: _load,
            ),
            ApexToolbarAction(
              label: 'الموافقات',
              icon: Icons.task_alt,
              onPressed: () => GoRouter.of(context).go('/admin/approvals'),
            ),
          ],
        ),
        if (!_loading) _statsBar(),
        _filterRow(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _statsBar() {
    final byCat = (_stats['by_category'] as Map?) ?? const {};
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AC.navy2,
      child: Wrap(spacing: 12, runSpacing: 8, children: [
        _stat('الإجمالي', _stats['total']?.toString() ?? '0', AC.tp),
        _stat('مدمجة', _stats['builtin']?.toString() ?? '0', AC.gold),
        _stat('مخصّصة', _stats['custom']?.toString() ?? '0', AC.cyan),
        _stat('استخدامات', _stats['total_uses']?.toString() ?? '0', AC.ok),
        for (final e in byCat.entries)
          _stat(_categoryLabels[e.key.toString()] ?? e.key.toString(),
              e.value.toString(), AC.warn),
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

  Widget _filterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(spacing: 6, children: [
        for (final c in _categories)
          ChoiceChip(
            label: Text(_categoryLabels[c]!),
            selected: _filterCategory == c,
            selectedColor: AC.gold.withValues(alpha: 0.3),
            backgroundColor: AC.navy3,
            labelStyle: TextStyle(
              color: _filterCategory == c ? AC.gold : AC.ts,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() => _filterCategory = c);
              _load();
            },
          ),
      ]),
    );
  }

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
    if (_templates.isEmpty) {
      return Center(
        child: Text('لا توجد قوالب في هذه الفئة',
            style: TextStyle(color: AC.ts)),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _templates.length,
        itemBuilder: (ctx, i) => _templateCard(_templates[i]),
      ),
    );
  }

  Widget _templateCard(Map<String, dynamic> t) {
    final isBuiltin = t['is_builtin'] == true;
    final stages = ((t['stages'] as List?) ?? const []).cast<dynamic>();
    final useCount = (t['use_count'] as num?)?.toInt() ?? 0;
    final iconName = (t['icon'] ?? 'task_alt').toString();
    final icon = _iconFor(iconName);
    final categoryColor = switch (t['category']) {
      'finance' => AC.gold,
      'procurement' => AC.cyan,
      'compliance' => AC.warn,
      'hr' => AC.ok,
      'ops' => AC.tp,
      _ => AC.ts,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: categoryColor.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: categoryColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                t['name_ar']?.toString() ?? '',
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.md,
                ),
              ),
              Text(
                t['name_en']?.toString() ?? '',
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
            ]),
          ),
          if (isBuiltin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('مدمج', style: TextStyle(color: AC.gold, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          t['description_ar']?.toString() ?? '',
          style: TextStyle(color: AC.ts, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _meta('${stages.length} مرحلة', AC.cyan),
          _meta(_categoryLabels[t['category']] ?? t['category'].toString(), categoryColor),
          if (t['object_type'] != null)
            _meta('${t['object_type']}', AC.tp),
          if (useCount > 0) _meta('استُخدم $useCount مرّة', AC.ok),
        ]),
        const SizedBox(height: 10),
        // Stage timeline preview
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < stages.length; i++) _stageRow(i, stages[i] as Map),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          ElevatedButton.icon(
            onPressed: () => _apply(t),
            icon: const Icon(Icons.play_arrow, size: 14),
            label: const Text('تطبيق'),
            style: ElevatedButton.styleFrom(backgroundColor: categoryColor),
          ),
          if (!isBuiltin)
            OutlinedButton.icon(
              onPressed: () => _deleteTemplate(t),
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('حذف'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.err),
                foregroundColor: AC.err,
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _stageRow(int i, Map stage) {
    final approvers = ((stage['approver_user_ids'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final kindLabel = switch (stage['kind']) {
      'all_required' => 'كل المعتمدين',
      'any_one' => 'أيّ واحد',
      'majority' => 'الأغلبية',
      _ => stage['kind'].toString(),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AC.gold.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: AC.gold),
          ),
          child: Center(
            child: Text(
              '${stage['sequence']}',
              style: TextStyle(
                color: AC.gold,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              stage['title_ar']?.toString() ?? '',
              style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Wrap(spacing: 4, runSpacing: 2, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AC.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  kindLabel,
                  style: TextStyle(color: AC.cyan, fontSize: 9, fontFamily: 'monospace'),
                ),
              ),
              for (final a in approvers.take(4))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AC.tp.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(color: AC.ts, fontSize: 9, fontFamily: 'monospace'),
                  ),
                ),
              if (approvers.length > 4)
                Text('+${approvers.length - 4}',
                    style: TextStyle(color: AC.ts, fontSize: 9)),
            ]),
          ]),
        ),
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
            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  IconData _iconFor(String name) {
    return switch (name) {
      'account_balance' => Icons.account_balance,
      'business_center' => Icons.business_center,
      'edit_note' => Icons.edit_note,
      'event_note' => Icons.event_note,
      'trending_up' => Icons.trending_up,
      'warning' => Icons.warning,
      'description' => Icons.description,
      _ => Icons.task_alt,
    };
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
