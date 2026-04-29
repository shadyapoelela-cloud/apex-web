/// APEX — Custom Roles Console
/// /admin/roles — define tenant-scoped roles with granular permissions.
///
/// Wired to the Custom Roles backend (Wave 1F Phase Y):
///   GET    /api/v1/permissions/catalog
///   GET    /admin/roles?tenant_id=...
///   POST   /admin/roles
///   PATCH  /admin/roles/{id}
///   DELETE /admin/roles/{id}
///   POST   /admin/roles/{id}/assign|revoke {user_id}
///   GET    /admin/roles/effective?user_id=...&tenant_id=...
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class CustomRolesScreen extends StatefulWidget {
  const CustomRolesScreen({super.key});
  @override
  State<CustomRolesScreen> createState() => _CustomRolesScreenState();
}

class _CustomRolesScreenState extends State<CustomRolesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  Map<String, List<Map<String, dynamic>>> _permsByCategory = {};

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
    final tid = _tenantId;
    if (tid == null || tid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لم يتم اختيار مستأجر';
      });
      return;
    }

    final permsRes = await ApiService.permissionsCatalog();
    final rolesRes = await ApiService.rolesList(tid);
    if (!mounted) return;
    if (permsRes.success) {
      final raw = (permsRes.data is Map ? permsRes.data['permissions'] : null) ?? const [];
      _permissions = (raw as List).cast<Map<String, dynamic>>();
      _permsByCategory = {};
      for (final p in _permissions) {
        final c = p['category']?.toString() ?? 'misc';
        _permsByCategory.putIfAbsent(c, () => []).add(p);
      }
    } else {
      _error = permsRes.error ?? 'فشل تحميل صلاحيات';
    }
    if (rolesRes.success) {
      final raw = (rolesRes.data is Map ? rolesRes.data['roles'] : null) ?? const [];
      _roles = (raw as List).cast<Map<String, dynamic>>();
    } else if (_error == null) {
      _error = rolesRes.error ?? 'فشل تحميل الأدوار';
    }
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    await _editorDialog(null);
  }

  Future<void> _edit(Map<String, dynamic> role) async {
    await _editorDialog(role);
  }

  Future<void> _editorDialog(Map<String, dynamic>? existing) async {
    final tid = _tenantId;
    if (tid == null || tid.isEmpty) return;

    final nameCtrl = TextEditingController(text: existing?['name_ar']?.toString() ?? '');
    final nameEnCtrl = TextEditingController(text: existing?['name_en']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final selected = <String>{
      ...((existing?['permissions'] as List?)?.cast<String>() ?? const []),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setStateModal) {
        return AlertDialog(
          backgroundColor: AC.navy2,
          title: Text(
            existing == null ? 'دور جديد' : 'تعديل: ${existing['name_ar']}',
            style: TextStyle(color: AC.tp),
          ),
          content: SizedBox(
            width: 560,
            height: 540,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _formField(nameCtrl, 'الاسم بالعربية', autofocus: true),
              const SizedBox(height: 8),
              _formField(nameEnCtrl, 'Name (EN, optional)'),
              const SizedBox(height: 8),
              _formField(descCtrl, 'الوصف (اختياري)'),
              const SizedBox(height: 12),
              Row(children: [
                Text(
                  'الصلاحيات: ${selected.length}/${_permissions.length}',
                  style: TextStyle(color: AC.ts, fontSize: 11),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setStateModal(() => selected.clear()),
                  child: Text('مسح الكل', style: TextStyle(color: AC.ts, fontSize: 11)),
                ),
                TextButton(
                  onPressed: () => setStateModal(() {
                    selected
                      ..clear()
                      ..addAll(_permissions.map((p) => p['id'].toString()));
                  }),
                  child: Text('اختر الكل', style: TextStyle(color: AC.gold, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final entry in _permsByCategory.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          _categoryLabel(entry.key),
                          style: TextStyle(
                            color: AC.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final p in entry.value) _permChip(p, selected, setStateModal),
                        ],
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AC.ts)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AC.gold),
              child: Text(
                existing == null ? 'إنشاء' : 'حفظ',
                style: TextStyle(color: AC.btnFg),
              ),
            ),
          ],
        );
      }),
    );

    if (result != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.warn, content: const Text('الاسم بالعربية مطلوب')),
      );
      return;
    }

    final body = {
      if (existing == null) 'tenant_id': tid,
      'name_ar': nameCtrl.text.trim(),
      if (nameEnCtrl.text.trim().isNotEmpty) 'name_en': nameEnCtrl.text.trim(),
      if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
      'permissions': selected.toList(),
    };

    final res = existing == null
        ? await ApiService.rolesCreate(body)
        : await ApiService.rolesUpdate(existing['id'] as String, body);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.ok,
          content: Text(existing == null ? '✅ أُنشئ الدور' : '💾 حُفظ'),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _toggleEnabled(Map<String, dynamic> role) async {
    final res = await ApiService.rolesUpdate(
      role['id'] as String,
      {'enabled': !(role['enabled'] == true)},
    );
    if (res.success && mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف الدور', style: TextStyle(color: AC.tp)),
        content: Text(
          'حذف "${role['name_ar']}" نهائياً. كل التعيينات ستُلغى.',
          style: TextStyle(color: AC.ts),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.rolesDelete(role['id'] as String);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('🗑 حُذف')),
      );
      _load();
    }
  }

  Future<void> _assignUser(Map<String, dynamic> role) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('تعيين مستخدم', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'منح "${role['name_ar']}" لمستخدم.',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _formField(ctrl, 'user_id', autofocus: true),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعيين'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    final res = await ApiService.rolesAssign(
      role['id'] as String,
      ctrl.text.trim(),
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('✅ تم التعيين')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _showEffective() async {
    final tid = _tenantId;
    if (tid == null || tid.isEmpty) return;
    final ctrl = TextEditingController(text: S.uid ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('استعلام الصلاحيات', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'ما هي الصلاحيات الفعلية للمستخدم في هذا المستأجر؟',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _formField(ctrl, 'user_id', autofocus: true),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('عرض'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    final res = await ApiService.rolesEffective(ctrl.text.trim(), tid);
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
      return;
    }
    final perms = (res.data is Map ? res.data['permissions'] : null) ?? const [];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text(
          'صلاحيات ${ctrl.text.trim()} — ${(perms as List).length}',
          style: TextStyle(color: AC.tp, fontSize: 14),
        ),
        content: SizedBox(
          width: 420,
          height: 400,
          child: perms.isEmpty
              ? Center(
                  child: Text('لا توجد صلاحيات (عبر الأدوار المخصّصة)',
                      style: TextStyle(color: AC.ts)),
                )
              : ListView.builder(
                  itemCount: perms.length,
                  itemBuilder: (_, i) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: AC.navy3,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      perms[i].toString(),
                      style: TextStyle(
                        color: AC.tp,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إغلاق', style: TextStyle(color: AC.ts)),
          ),
        ],
      ),
    );
  }

  Widget _formField(TextEditingController c, String label, {bool autofocus = false}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _permChip(Map<String, dynamic> p, Set<String> selected, void Function(void Function()) setStateModal) {
    final id = p['id'].toString();
    final on = selected.contains(id);
    return InkWell(
      onTap: () => setStateModal(() {
        if (on) {
          selected.remove(id);
        } else {
          selected.add(id);
        }
      }),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: on ? AC.gold.withValues(alpha: 0.18) : AC.navy3,
          border: Border.all(color: on ? AC.gold : AC.bdr),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            on ? Icons.check_circle : Icons.add_circle_outline,
            color: on ? AC.gold : AC.ts,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            p['label_ar']?.toString() ?? id,
            style: TextStyle(
              color: on ? AC.gold : AC.tp,
              fontSize: 11,
              fontWeight: on ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }

  String _categoryLabel(String k) {
    switch (k) {
      case 'finance':
        return 'المالية';
      case 'hr':
        return 'الموارد البشرية';
      case 'compliance':
        return 'الامتثال';
      case 'analytics':
        return 'التحليلات';
      case 'platform':
        return 'المنصة';
      case 'admin':
        return 'الإدارة';
      default:
        return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'الأدوار المخصّصة',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'استعلام',
                icon: Icons.search,
                onPressed: _showEffective,
              ),
              ApexToolbarAction(
                label: 'دور جديد',
                icon: Icons.add,
                primary: true,
                onPressed: _create,
              ),
            ],
          ),
          Expanded(child: _body()),
        ],
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
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    if (_roles.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.shield_moon_outlined, color: AC.ts, size: 64),
          const SizedBox(height: 12),
          Text('لا توجد أدوار مخصّصة بعد', style: TextStyle(color: AC.tp, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'استخدم الأدوار المخصّصة لتعريف صلاحيات بحدود دقيقة',
            style: TextStyle(color: AC.ts, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء أول دور'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _roles.length,
        itemBuilder: (ctx, i) => _card(_roles[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final enabled = r['enabled'] == true;
    final perms = (r['permissions'] as List?) ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: enabled ? AC.ok.withValues(alpha: 0.4) : AC.bdr,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield, color: AC.gold, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                r['name_ar']?.toString() ?? '',
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.md,
                ),
              ),
              if ((r['name_en'] ?? '').toString().isNotEmpty)
                Text(
                  r['name_en'].toString(),
                  style: TextStyle(color: AC.ts, fontSize: 11),
                ),
            ]),
          ),
          Switch(
            value: enabled,
            activeColor: AC.ok,
            onChanged: (_) => _toggleEnabled(r),
          ),
        ]),
        if ((r['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            r['description'].toString(),
            style: TextStyle(color: AC.ts, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, children: [
          _miniChip('${perms.length} صلاحية', AC.cyan),
          for (final p in perms.take(6))
            _miniChip(
              p.toString(),
              AC.tp,
            ),
          if (perms.length > 6) _miniChip('+${perms.length - 6}', AC.ts),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () => _edit(r),
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('تعديل'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.gold),
              foregroundColor: AC.gold,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _assignUser(r),
            icon: const Icon(Icons.person_add, size: 14),
            label: const Text('تعيين مستخدم'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.cyan),
              foregroundColor: AC.cyan,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _delete(r),
            icon: Icon(Icons.delete_outline, color: AC.err, size: 18),
            tooltip: 'حذف',
          ),
        ]),
      ]),
    );
  }

  Widget _miniChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontFamily: text.contains(':') ? 'monospace' : null,
        ),
      ),
    );
  }
}
