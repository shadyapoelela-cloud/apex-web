/// Admin screen — list of role-default layouts + edit / lock controls.
///
/// Gated on `manage:dashboard_role`. Lock toggle additionally requires
/// `lock:dashboard` (backend re-checks regardless).
///
/// Selecting a row pushes [CustomizableDashboard] in
/// `DashboardEditTarget.role` mode so saves go to PUT /role-layouts/.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'customizable_dashboard.dart';
import 'dashboard_hooks_default.dart';

class RoleLayoutsAdminScreen extends StatefulWidget {
  const RoleLayoutsAdminScreen({super.key});

  @override
  State<RoleLayoutsAdminScreen> createState() =>
      _RoleLayoutsAdminScreenState();
}

class _RoleLayoutsAdminScreenState extends State<RoleLayoutsAdminScreen> {
  bool _loading = true;
  String? _error;
  List<_RoleLayoutRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.dashboardRoleLayouts();
      if (!res.success) {
        setState(() {
          _loading = false;
          _error = res.error ?? 'فشل التحميل';
        });
        return;
      }
      final raw = res.data;
      if (raw is! List) {
        setState(() {
          _loading = false;
          _rows = const [];
        });
        return;
      }
      _rows = raw
          .whereType<Map>()
          .map((m) => _RoleLayoutRow.fromJson(m.cast<String, dynamic>()))
          .toList();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggleLock(_RoleLayoutRow row) async {
    if (!S.hasPerm('lock:dashboard')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تحتاج صلاحية lock:dashboard')),
      );
      return;
    }
    try {
      final res = await ApiService.dashboardLockRoleLayout(
          row.ownerId, !row.isLocked);
      if (res.success) {
        await _load();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: ${res.error ?? "غير معروف"}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
      );
    }
  }

  void _openEditor(_RoleLayoutRow row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomizableDashboard(
          target: DashboardEditTarget.role,
          roleId: row.ownerId,
          title: 'تخطيط دور ${_roleLabel(row.ownerId)}',
          hooks: defaultDashboardHooks(
            target: DashboardEditTarget.role,
            roleId: row.ownerId,
          ),
        ),
      ),
    ).then((_) => _load());
  }

  static String _roleLabel(String id) {
    const m = {
      'cfo': 'المدير المالي',
      'accountant': 'المحاسب',
      'cashier': 'الكاشير',
      'branch_manager': 'مدير الفرع',
      'hr': 'الموارد البشرية',
    };
    return m[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    if (!S.hasPerm('manage:dashboard_role')) {
      return Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('تخطيطات الأدوار'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AC.warn),
                const SizedBox(height: 12),
                Text(
                  'تحتاج صلاحية manage:dashboard_role للوصول لهذه الشاشة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AC.tp),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('العودة للوحة التحكم'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: const Text('تخطيطات الأدوار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AC.err, size: 36),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AC.tp)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('إعادة')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'لا توجد تخطيطات أدوار بعد',
          style: TextStyle(color: AC.ts),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length,
      separatorBuilder: (_, __) =>
          Divider(color: AC.bdr.withValues(alpha: 0.4), height: 1),
      itemBuilder: (context, i) {
        final r = _rows[i];
        return ListTile(
          tileColor: AC.navy3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          leading: Icon(
            r.isLocked ? Icons.lock : Icons.lock_open,
            color: r.isLocked ? AC.warn : AC.ok,
          ),
          title: Text(
            _roleLabel(r.ownerId),
            style: TextStyle(color: AC.tp, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'كتل: ${r.blockCount}  ·  إصدار: ${r.version}',
            style: TextStyle(color: AC.ts, fontSize: 12),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: r.isLocked ? 'فك القفل' : 'قفل',
                icon: Icon(r.isLocked ? Icons.lock_open : Icons.lock),
                onPressed: () => _toggleLock(r),
              ),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit),
                onPressed: () => _openEditor(r),
              ),
            ],
          ),
          onTap: () => _openEditor(r),
        );
      },
    );
  }
}

class _RoleLayoutRow {
  final String? id;
  final String ownerId;
  final String name;
  final bool isLocked;
  final int version;
  final int blockCount;

  const _RoleLayoutRow({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.isLocked,
    required this.version,
    required this.blockCount,
  });

  factory _RoleLayoutRow.fromJson(Map<String, dynamic> j) {
    final blocks = (j['blocks'] as List?) ?? const [];
    return _RoleLayoutRow(
      id: j['id'] as String?,
      ownerId: (j['owner_id'] ?? '') as String,
      name: (j['name'] ?? 'default') as String,
      isLocked: (j['is_locked'] ?? false) as bool,
      version: (j['version'] ?? 1) as int,
      blockCount: blocks.length,
    );
  }
}
