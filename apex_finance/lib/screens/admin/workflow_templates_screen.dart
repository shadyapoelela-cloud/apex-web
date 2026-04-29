/// APEX — Workflow Templates Browser
/// /admin/workflow/templates — install pre-built rules with one click.
///
/// Wired to the Workflow Templates Library backend (Wave 1C Phase M):
///   GET  /admin/workflow/templates
///   POST /admin/workflow/templates/{id}/install
///
/// Admin-secret-gated. The first visit prompts for X-Admin-Secret which
/// gets persisted in localStorage (apex_admin_secret).
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class WorkflowTemplatesScreen extends StatefulWidget {
  const WorkflowTemplatesScreen({super.key});

  @override
  State<WorkflowTemplatesScreen> createState() =>
      _WorkflowTemplatesScreenState();
}

class _WorkflowTemplatesScreenState extends State<WorkflowTemplatesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = [];
  String _category = 'all';

  static const _categories = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'approvals', 'label': 'الموافقات'},
    {'id': 'alerts', 'label': 'التنبيهات'},
    {'id': 'automations', 'label': 'الأتمتة'},
    {'id': 'compliance', 'label': 'الامتثال'},
    {'id': 'ops', 'label': 'العمليات'},
  ];

  @override
  void initState() {
    super.initState();
    _ensureAdminSecret().then((_) => _load());
  }

  Future<void> _ensureAdminSecret() async {
    if (ApiService.hasAdminSecret) return;
    if (!mounted) return;
    final ctrl = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('سرّ المسؤول مطلوب', style: TextStyle(color: AC.tp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هذه الصفحة تتطلب X-Admin-Secret. سيُحفَظ محلياً في المتصفح.',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
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
          ],
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
    final res = await ApiService.workflowListTemplates(
      category: _category == 'all' ? null : _category,
    );
    if (!mounted) return;
    if (res.success) {
      final data = res.data;
      final raw = data is Map ? (data['templates'] ?? const []) : const [];
      _templates = (raw as List).cast<Map<String, dynamic>>();
      _loading = false;
    } else {
      _loading = false;
      _error = res.error ?? 'فشل تحميل القوالب';
    }
    setState(() {});
  }

  Future<void> _install(Map<String, dynamic> tpl) async {
    final params = (tpl['parameters'] as List?) ?? const [];
    final values = <String, dynamic>{};

    if (params.isNotEmpty) {
      final controllers = <String, TextEditingController>{};
      for (final p in params) {
        final m = p as Map<String, dynamic>;
        controllers[m['name'] as String] = TextEditingController(
          text: m['default']?.toString() ?? '',
        );
      }

      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AC.navy2,
          title: Text(
            'تثبيت: ${tpl['name_ar'] ?? tpl['name_en'] ?? ''}',
            style: TextStyle(color: AC.tp),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tpl['description_ar']?.toString() ?? '',
                  style: TextStyle(color: AC.ts, fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (final p in params)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[(p as Map)['name'] as String],
                      style: TextStyle(color: AC.tp),
                      keyboardType: (p['type'] == 'number')
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: p['label_ar']?.toString() ?? p['name'].toString(),
                        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
                        filled: true,
                        fillColor: AC.navy3,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AC.ts)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AC.gold),
              child: Text('تثبيت', style: TextStyle(color: AC.btnFg)),
            ),
          ],
        ),
      );
      if (go != true) return;

      for (final p in params) {
        final m = p as Map;
        final name = m['name'] as String;
        final v = controllers[name]!.text;
        if (m['type'] == 'number') {
          final n = num.tryParse(v);
          if (n != null) values[name] = n;
        } else {
          if (v.isNotEmpty) values[name] = v;
        }
      }
    }

    final res = await ApiService.workflowInstallTemplate(
      tpl['id'] as String,
      parameterValues: values,
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.ok,
          content: Text('✅ تم تثبيت القاعدة "${tpl['name_ar']}"'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.err,
          content: Text(res.error ?? 'فشل التثبيت'),
        ),
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
            title: 'قوالب أتمتة سير العمل',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'إعادة تعيين السرّ',
                icon: Icons.lock_reset,
                onPressed: () async {
                  ApiService.adminSecret = null;
                  await _ensureAdminSecret();
                  await _load();
                },
              ),
            ],
          ),
          _categoryFilter(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _categoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AC.navy2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in _categories)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(c['label']!),
                  selected: _category == c['id'],
                  onSelected: (_) {
                    setState(() => _category = c['id']!);
                    _load();
                  },
                  backgroundColor: AC.navy3,
                  selectedColor: AC.gold,
                  labelStyle: TextStyle(
                    color: _category == c['id'] ? AC.btnFg : AC.tp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AC.err, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: AC.tp), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_templates.isEmpty) {
      return Center(
        child: Text('لا توجد قوالب', style: TextStyle(color: AC.ts)),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _templates.length,
        itemBuilder: (ctx, i) => _card(_templates[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> tpl) {
    final params = (tpl['parameters'] as List?) ?? const [];
    final actions = (tpl['actions'] as List?) ?? const [];
    final actionTypes = actions
        .whereType<Map>()
        .map((a) => a['type'].toString())
        .toSet()
        .join(' + ');
    final iconKey = tpl['icon']?.toString() ?? 'auto_awesome';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(iconKey), color: AC.gold, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tpl['name_ar']?.toString() ??
                      tpl['name_en']?.toString() ??
                      tpl['id'].toString(),
                  style: TextStyle(
                    color: AC.tp,
                    fontWeight: FontWeight.bold,
                    fontSize: AppFontSize.lg,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AC.cyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  tpl['category']?.toString() ?? '',
                  style: TextStyle(color: AC.cyan, fontSize: 10),
                ),
              ),
            ],
          ),
          if ((tpl['description_ar'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              tpl['description_ar'].toString(),
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.bolt, color: AC.warn, size: 14),
              const SizedBox(width: 4),
              Text(
                tpl['event_pattern']?.toString() ?? '',
                style: TextStyle(
                    color: AC.warn,
                    fontSize: AppFontSize.xs,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(width: 12),
              Icon(Icons.alt_route, color: AC.cyan, size: 14),
              const SizedBox(width: 4),
              Text(
                actionTypes,
                style: TextStyle(color: AC.cyan, fontSize: AppFontSize.xs),
              ),
            ],
          ),
          if (params.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${params.length} معاملة قابلة للتخصيص',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ElevatedButton.icon(
              onPressed: () => _install(tpl),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('تثبيت'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'receipt_long':
        return Icons.receipt_long;
      case 'payments':
        return Icons.payments;
      case 'alarm':
        return Icons.alarm;
      case 'report_problem':
        return Icons.report_problem;
      case 'error':
        return Icons.error;
      case 'inventory':
        return Icons.inventory;
      case 'favorite':
        return Icons.favorite;
      case 'celebration':
        return Icons.celebration;
      case 'attach_email':
        return Icons.attach_email;
      case 'event':
        return Icons.event;
      case 'badge':
        return Icons.badge;
      case 'history':
        return Icons.history;
      default:
        return Icons.auto_awesome;
    }
  }
}
