/// APEX — Module Manager Console
/// /admin/modules — toggle platform modules per tenant.
///
/// Wired to the Module Manager backend (Wave 1E Phase V):
///   GET  /api/v1/modules/catalog
///   GET  /api/v1/modules/effective?tenant_id=...
///   POST /admin/modules/set {tenant_id, module_id, enabled}
///   POST /admin/modules/reset {tenant_id}
///
/// Admin-secret-gated. Group switches by category. Auto-disabled modules
/// (because their `requires` dep is off) are shown faded with a hint.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class ModuleManagerScreen extends StatefulWidget {
  const ModuleManagerScreen({super.key});
  @override
  State<ModuleManagerScreen> createState() => _ModuleManagerScreenState();
}

class _ModuleManagerScreenState extends State<ModuleManagerScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _catalog = [];
  Map<String, bool> _effective = {};
  String _category = 'all';

  static const _categories = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'core', 'label': 'الأساسية'},
    {'id': 'finance', 'label': 'المالية'},
    {'id': 'ops', 'label': 'العمليات'},
    {'id': 'hr', 'label': 'الموارد البشرية'},
    {'id': 'compliance', 'label': 'الامتثال'},
    {'id': 'analytics', 'label': 'التحليلات'},
    {'id': 'ai', 'label': 'الذكاء الاصطناعي'},
    {'id': 'platform', 'label': 'المنصة'},
  ];

  String? get _tenantId => S.tenantId;

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
    final tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لم يتم اختيار مستأجر — افتح إعدادات الكيانات لتحديده';
      });
      return;
    }
    final cat = await ApiService.modulesCatalog(
      category: _category == 'all' ? null : _category,
    );
    final eff = await ApiService.modulesEffective(tenantId);
    if (!mounted) return;
    if (cat.success) {
      final raw = (cat.data is Map ? cat.data['modules'] : null) ?? const [];
      _catalog = (raw as List).cast<Map<String, dynamic>>();
    } else {
      _error = cat.error ?? 'فشل تحميل الوحدات';
    }
    if (eff.success) {
      final m = (eff.data is Map ? eff.data['modules'] : null);
      if (m is Map) {
        _effective = m.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _toggle(String moduleId, bool newValue) async {
    final tenantId = _tenantId ?? '';
    if (tenantId.isEmpty) return;
    final res = await ApiService.modulesSet(tenantId, moduleId, newValue);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: newValue ? AC.ok : AC.ts,
          content: Text(newValue ? '✅ تم التفعيل' : '⏸ تم التعطيل'),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _reset() async {
    final tenantId = _tenantId ?? '';
    if (tenantId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إعادة تعيين الوحدات', style: TextStyle(color: AC.tp)),
        content: Text(
          'سيتم حذف كل التخصيصات والعودة لإعدادات الكتالوج الافتراضية.',
          style: TextStyle(color: AC.ts),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.warn),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.modulesReset(tenantId);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('🔄 تم إعادة التعيين')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
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
            title: 'إدارة الوحدات',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'إعادة تعيين',
                icon: Icons.restart_alt,
                onPressed: _reset,
              ),
            ],
          ),
          _categoryFilter(),
          if (_tenantId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AC.navy2,
              child: Text(
                'مستأجر: ${_tenantId!.substring(0, _tenantId!.length.clamp(0, 12))}…',
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
            ),
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
              Text(_error!, style: TextStyle(color: AC.tp), textAlign: TextAlign.center),
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
    if (_catalog.isEmpty) {
      return Center(child: Text('لا توجد وحدات', style: TextStyle(color: AC.ts)));
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _catalog.length,
        itemBuilder: (ctx, i) => _card(_catalog[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final id = m['id'] as String;
    final isOn = _effective[id] ?? (m['default_enabled'] == true);
    final requires = (m['requires'] as List?)?.cast<String>() ?? const [];
    final unmetReqs =
        requires.where((r) => !(_effective[r] ?? false)).toList();
    final isAutoDisabled = !isOn && unmetReqs.isNotEmpty;
    final minPlan = m['min_plan']?.toString() ?? 'free';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isOn ? AC.ok.withValues(alpha: 0.4) : AC.bdr,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_iconFor(m['icon']?.toString() ?? ''), color: AC.gold, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['name_ar']?.toString() ?? id,
                    style: TextStyle(
                      color: AC.tp,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.md,
                    ),
                  ),
                  if ((m['description_ar'] ?? '').toString().isNotEmpty)
                    Text(
                      m['description_ar'].toString(),
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
                    ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              activeColor: AC.ok,
              onChanged: isAutoDisabled ? null : (v) => _toggle(id, v),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(m['category']?.toString() ?? '', AC.cyan),
            if (minPlan != 'free') _chip('plan: $minPlan', AC.warn),
            for (final r in requires) _chip('يتطلب: $r', AC.ts),
          ]),
          if (unmetReqs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AC.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'مُعطَّلة تلقائياً — فعّل أولاً: ${unmetReqs.join(', ')}',
                style: TextStyle(color: AC.warn, fontSize: 10.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontSize: 10),
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'person':
        return Icons.person;
      case 'account_tree':
        return Icons.account_tree;
      case 'book':
        return Icons.book;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'payments':
        return Icons.payments;
      case 'account_balance':
        return Icons.account_balance;
      case 'trending_up':
        return Icons.trending_up;
      case 'inventory':
        return Icons.inventory;
      case 'domain':
        return Icons.domain;
      case 'point_of_sale':
        return Icons.point_of_sale;
      case 'merge_type':
        return Icons.merge_type;
      case 'badge':
        return Icons.badge;
      case 'calculate':
        return Icons.calculate;
      case 'logout':
        return Icons.logout;
      case 'verified_user':
        return Icons.verified_user;
      case 'savings':
        return Icons.savings;
      case 'receipt':
        return Icons.receipt;
      case 'gavel':
        return Icons.gavel;
      case 'dashboard':
        return Icons.dashboard;
      case 'analytics':
        return Icons.analytics;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'auto_awesome_motion':
        return Icons.auto_awesome_motion;
      case 'report_problem':
        return Icons.report_problem;
      case 'document_scanner':
        return Icons.document_scanner;
      case 'attach_email':
        return Icons.attach_email;
      case 'task_alt':
        return Icons.task_alt;
      case 'webhook':
        return Icons.webhook;
      case 'forum':
        return Icons.forum;
      case 'storefront':
        return Icons.storefront;
      case 'palette':
        return Icons.palette;
      default:
        return Icons.extension;
    }
  }
}
