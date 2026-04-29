/// APEX — Industry Pack Selector
/// /admin/industry-packs — sector packs admin can assign to tenants.
///
/// Wired to Wave 1K Phase PP backend:
///   GET    /api/v1/industry-packs
///   GET    /api/v1/industry-packs/{id}            (preview COA)
///   GET    /api/v1/industry-packs/applied?tenant_id
///   POST   /admin/industry-packs/{id}/apply?tenant_id
///   DELETE /admin/industry-packs/applied/{tenant_id}
///   GET    /admin/industry-packs/assignments
///   GET    /admin/industry-packs/stats
///
/// 5 packs ship in the registry (F&B, Construction, Medical, Logistics,
/// Services) — each carries a curated COA + dashboard widget set +
/// recommended workflow ids. This screen lets the platform admin pick a
/// sector for any tenant; subsequent provisioning hooks into
/// `industry_pack.applied` events.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class AdminIndustryPacksScreen extends StatefulWidget {
  const AdminIndustryPacksScreen({super.key});
  @override
  State<AdminIndustryPacksScreen> createState() => _AdminIndustryPacksScreenState();
}

class _AdminIndustryPacksScreenState extends State<AdminIndustryPacksScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic> _stats = const {};
  final _tenantCtrl = TextEditingController();
  String? _expandedPackId;
  Map<String, dynamic>? _expandedDetail;

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _tenantCtrl.dispose();
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
      ApiService.industryPacksList(),
      ApiService.industryPackAssignments(),
      ApiService.industryPackStats(),
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
      _assignments = ((r[1].data['assignments'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (r[2].success && r[2].data is Map) {
      _stats = Map<String, dynamic>.from(r[2].data as Map);
    }
    setState(() => _loading = false);
  }

  Future<void> _expand(String packId) async {
    if (_expandedPackId == packId) {
      setState(() {
        _expandedPackId = null;
        _expandedDetail = null;
      });
      return;
    }
    setState(() {
      _expandedPackId = packId;
      _expandedDetail = null;
    });
    final r = await ApiService.industryPackDetail(packId);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      setState(() => _expandedDetail = Map<String, dynamic>.from(r.data['pack'] as Map));
    }
  }

  Future<void> _applyPack(Map<String, dynamic> pack) async {
    final tenantId = _tenantCtrl.text.trim();
    if (tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أدخل tenant_id أولاً', style: TextStyle(color: AC.tp))),
      );
      return;
    }
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('تطبيق ${pack['name_ar']}',
            style: TextStyle(color: AC.tp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيُسجَّل المستأجر $tenantId على هذه الحزمة وسيُصدَر حدث industry_pack.applied. هل تريد المتابعة؟',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: TextStyle(color: AC.tp, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.industryPackApply(
      pack['id'].toString(),
      tenantId,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.ok,
          content: Text('تم تطبيق الحزمة على $tenantId',
              style: TextStyle(color: AC.tp)),
        ),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(r.error ?? 'فشل التطبيق')),
      );
    }
  }

  Future<void> _removeAssignment(String tenantId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إلغاء التخصيص', style: TextStyle(color: AC.tp)),
        content: Text(
          'سيتم إزالة الحزمة من المستأجر $tenantId.',
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
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.industryPackRemove(tenantId);
    if (!mounted) return;
    if (r.success) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(r.error ?? 'فشل')),
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
            title: 'حزم القطاعات',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroBanner(),
            const SizedBox(height: AppSpacing.md),
            _tenantInput(),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AC.err.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AC.err),
                ),
                child: Text(_error!, style: TextStyle(color: AC.err)),
              ),
            ..._packs.map(_packCard),
            const SizedBox(height: AppSpacing.lg),
            _assignmentsBlock(),
          ],
        ),
      ),
    );
  }

  Widget _heroBanner() {
    final assigned = _stats['tenants_assigned'] ?? 0;
    final total = _stats['packs_total'] ?? _packs.length;
    final byPack = (_stats['by_pack'] as Map?) ?? const {};
    return Container(
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
          Icon(Icons.business_center, color: AC.gold, size: 28),
          const SizedBox(width: 10),
          Text(
            'حزم القطاعات الجاهزة',
            style: TextStyle(
              color: AC.gold,
              fontWeight: FontWeight.w900,
              fontSize: AppFontSize.xl,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          'كل حزمة تحوي شجرة حسابات + لوحة قيادة + قواعد أتمتة موصى بها لقطاع معيّن.',
          style: TextStyle(color: AC.ts, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 6, children: [
          _stat('الحزم المتاحة', total.toString(), AC.tp),
          _stat('مستأجرون مُكوَّنون', assigned.toString(), AC.cyan),
          for (final e in byPack.entries)
            _stat(e.key.toString(), e.value.toString(), AC.gold),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
      Text(
        value,
        style: TextStyle(
          color: c,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    ]);
  }

  Widget _tenantInput() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(children: [
        Icon(Icons.business, color: AC.cyan, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _tenantCtrl,
            style: TextStyle(color: AC.tp, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'tenant_id الذي ستُطبَّق عليه الحزمة',
              labelStyle: TextStyle(color: AC.ts, fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: AC.navy3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _packCard(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final isExpanded = _expandedPackId == id;
    final coaCount = p['coa_account_count'] ?? 0;
    final widgetCount = p['dashboard_widget_count'] ?? 0;
    final wfCount = p['workflow_count'] ?? 0;
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(iconForPack, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name_ar']?.toString() ?? id,
                    style: TextStyle(
                      color: AC.tp,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.md,
                    ),
                  ),
                  Text(
                    p['name_en']?.toString() ?? '',
                    style: TextStyle(color: AC.ts, fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _applyPack(p),
              icon: const Icon(Icons.check, size: 14),
              label: const Text('تطبيق'),
              style: ElevatedButton.styleFrom(backgroundColor: color),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            p['description']?.toString() ?? '',
            style: TextStyle(color: AC.ts, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _meta('$coaCount حساب', AC.cyan),
            _meta('$widgetCount widget', AC.gold),
            _meta('$wfCount workflow', AC.ok),
          ]),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _expand(id),
            icon: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: AC.cyan,
            ),
            label: Text(
              isExpanded ? 'إخفاء التفاصيل' : 'عرض شجرة الحسابات',
              style: TextStyle(color: AC.cyan, fontSize: 12),
            ),
          ),
          if (isExpanded) _expandedBody(),
        ],
      ),
    );
  }

  Widget _expandedBody() {
    if (_expandedDetail == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(color: AC.gold, strokeWidth: 2)),
      );
    }
    final coa = ((_expandedDetail!['coa_accounts'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final widgets = ((_expandedDetail!['dashboard_widgets'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('شجرة الحسابات (${coa.length})',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        for (final a in coa) _coaRow(a),
        const SizedBox(height: 12),
        Text('Widgets (${widgets.length})',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final w in widgets) _meta('${w['title_ar']} · ${w['kind']}', AC.cyan),
        ]),
      ]),
    );
  }

  Widget _coaRow(Map<String, dynamic> a) {
    final t = (a['account_type'] ?? '').toString();
    final tColor = switch (t) {
      'asset' => AC.cyan,
      'liability' => AC.warn,
      'equity' => AC.gold,
      'revenue' => AC.ok,
      'expense' => AC.err,
      _ => AC.tp,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Text(
            a['code']?.toString() ?? '',
            style: TextStyle(
              color: AC.ts,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            a['name_ar']?.toString() ?? '',
            style: TextStyle(color: AC.tp, fontSize: 12),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            t,
            style: TextStyle(color: tColor, fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
      ]),
    );
  }

  Widget _meta(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _assignmentsBlock() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التخصيصات الحالية (${_assignments.length})',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        if (_assignments.isEmpty)
          Text('لم تُطبَّق أي حزمة على أي مستأجر بعد',
              style: TextStyle(color: AC.ts, fontSize: 12))
        else
          ..._assignments.map(_assignmentRow),
      ]),
    );
  }

  Widget _assignmentRow(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        Icon(Icons.business, color: AC.cyan, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tenant: ${a['tenant_id']}',
                style: TextStyle(
                  color: AC.tp,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              Text(
                '${a['pack_name_ar'] ?? a['pack_id']} · ${(a['applied_at'] ?? '').toString().substring(0, 10)}',
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
            ],
          ),
        ),
        if (a['coa_seeded'] == true)
          Tooltip(
            message: 'COA seeded',
            child: Icon(Icons.check_circle, color: AC.ok, size: 16),
          ),
        IconButton(
          tooltip: 'إزالة',
          onPressed: () => _removeAssignment(a['tenant_id'].toString()),
          icon: Icon(Icons.delete_outline, color: AC.err, size: 18),
        ),
      ]),
    );
  }
}
