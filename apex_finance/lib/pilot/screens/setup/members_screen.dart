/// Members & Permissions — إدارة الأعضاء والأدوار والصلاحيات.
///
/// مستقلة — تعتمد على PilotSession.tenantId.
///
/// التبويبات:
///   1) الأعضاء — قائمة + دعوة + عرض تفاصيل الصلاحيات
///   2) الأدوار — قائمة + إنشاء دور جديد (مع صلاحيات)
///   3) الصلاحيات — عرض المرجع الكامل للصلاحيات
library;

import 'package:flutter/material.dart';
import '../../../core/theme.dart' as core_theme;

import '../../api/pilot_client.dart';
import '../../session.dart';

Color get _gold => core_theme.AC.gold;
Color get _navy => core_theme.AC.navy;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
final _tp = Color(0xFFFFFFFF);
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;
Color get _warn => core_theme.AC.warn;
final _indigo = core_theme.AC.purple;

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final PilotClient _client = pilotClient;

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _entities = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasTenant) {
      setState(() {
        _loading = false;
        _error = 'يجب اختيار الشركة من شريط العنوان أولاً.';
      });
      return;
    }
    final tid = PilotSession.tenantId!;
    try {
      final results = await Future.wait([
        _client.listMembers(tid, activeOnly: false),
        _client.listRoles(tid),
        _client.listPermissions(),
        _client.listEntities(tid),
      ]);
      _members = results[0].success
          ? List<Map<String, dynamic>>.from(results[0].data)
          : [];
      _roles = results[1].success
          ? List<Map<String, dynamic>>.from(results[1].data)
          : [];
      _permissions = results[2].success
          ? List<Map<String, dynamic>>.from(results[2].data)
          : [];
      _entities = results[3].success
          ? List<Map<String, dynamic>>.from(results[3].data)
          : [];
      _branches = [];
      for (final e in _entities) {
        final b = await _client.listBranches(e['id']);
        if (b.success) {
          for (final br in List<Map<String, dynamic>>.from(b.data)) {
            _branches.add({...br, '_entity_code': e['code']});
          }
        }
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _inviteMember() async {
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _warn, content: Text('أنشئ دوراً أولاً')));
      return;
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _InviteDialog(
        roles: _roles,
        entities: _entities,
        branches: _branches,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _createRole() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _RoleDialog(permissions: _permissions),
    );
    if (r == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(children: [
          _header(),
          Container(
            color: _navy2,
            child: TabBar(
              controller: _tab,
              indicatorColor: _gold,
              labelColor: _gold,
              unselectedLabelColor: _ts,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: [
                Tab(
                    icon: const Icon(Icons.people, size: 16),
                    text: 'الأعضاء (${_members.length})'),
                Tab(
                    icon: const Icon(Icons.badge, size: 16),
                    text: 'الأدوار (${_roles.length})'),
                Tab(
                    icon: const Icon(Icons.key, size: 16),
                    text: 'الصلاحيات (${_permissions.length})'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : TabBarView(controller: _tab, children: [
                        _membersTab(),
                        _rolesTab(),
                        _permissionsTab(),
                      ]),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
          color: _navy2, border: Border(bottom: BorderSide(color: _bdr))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.admin_panel_settings, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الأعضاء والصلاحيات',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('أعضاء الشركة · الأدوار (RBAC) · مرجع الصلاحيات',
                style: TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
      ]),
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: _ts)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: BorderSide(color: _bdr)),
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );

  // ════════════════════════════════════════════════════════════════════
  // Tab 1: Members
  // ════════════════════════════════════════════════════════════════════

  Widget _membersTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          Text(
              'إجمالي: ${_members.length} · نشط: ${_members.where((m) => m['status'] == 'active').length}',
              style: TextStyle(color: _ts, fontSize: 12)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
            onPressed: _inviteMember,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('دعوة عضو'),
          ),
        ]),
      ),
      Expanded(
        child: _members.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline,
                      color: _gold.withValues(alpha: 0.4), size: 72),
                  const SizedBox(height: 14),
                  Text('لا يوجد أعضاء بعد',
                      style: TextStyle(color: _tp, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('ادعُ أعضاء فريقك للعمل على الشركة',
                      style: TextStyle(color: _ts, fontSize: 12)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
                    onPressed: _inviteMember,
                    icon: const Icon(Icons.person_add, size: 14),
                    label: const Text('دعوة أول عضو'),
                  ),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: _members.map(_memberTile).toList(),
              ),
      ),
    ]);
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final active = m['status'] == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
                (m['display_name'] ?? '?').toString().isNotEmpty
                    ? (m['display_name'] as String)[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: _gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m['display_name'] ?? '',
                  style: TextStyle(
                      color: _tp,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(m['email'] ?? '',
                  style: TextStyle(color: _ts, fontSize: 11)),
              if ((m['mobile'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(m['mobile'],
                    style: TextStyle(
                        color: _td,
                        fontSize: 10,
                        fontFamily: 'monospace')),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if ((m['primary_role_code'] ?? '').toString().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _indigo.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _indigo.withValues(alpha: 0.4))),
                  child: Text(m['primary_role_code'],
                      style: TextStyle(
                          color: _indigo,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: active
                        ? _ok.withValues(alpha: 0.14)
                        : _td.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: active
                            ? _ok.withValues(alpha: 0.4)
                            : _td.withValues(alpha: 0.4))),
                child: Text(active ? 'نشط' : m['status'] ?? '—',
                    style: TextStyle(
                        color: active ? _ok : _td,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.business, color: _td, size: 11),
              const SizedBox(width: 2),
              Text('${m['entity_grants'] ?? 0}',
                  style: TextStyle(color: _ts, fontSize: 10)),
              const SizedBox(width: 8),
              Icon(Icons.store, color: _td, size: 11),
              const SizedBox(width: 2),
              Text('${m['branch_grants'] ?? 0}',
                  style: TextStyle(color: _ts, fontSize: 10)),
            ]),
          ],
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 2: Roles
  // ════════════════════════════════════════════════════════════════════

  Widget _rolesTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          Text('${_roles.length} دور',
              style: TextStyle(color: _ts, fontSize: 12)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
            onPressed: _createRole,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('دور جديد'),
          ),
        ]),
      ),
      Expanded(
        child: _roles.isEmpty
            ? Center(
                child: Text('لا توجد أدوار بعد',
                    style: TextStyle(color: _ts, fontSize: 13)))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _roles.length,
                itemBuilder: (_, i) {
                  final r = _roles[i];
                  final color = _parseHex(r['color_hex']) ?? _indigo;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(Icons.badge, color: color, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['name_ar'] ?? '',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800),
                                    overflow: TextOverflow.ellipsis),
                                Text(r['code'] ?? '',
                                    style: TextStyle(
                                        color: _td,
                                        fontSize: 10,
                                        fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          if (r['is_system'] == true)
                            Icon(Icons.shield,
                                color: _warn, size: 14),
                        ]),
                        const SizedBox(height: 8),
                        if ((r['description_ar'] ?? '').toString().isNotEmpty)
                          Text(r['description_ar'],
                              style: TextStyle(
                                  color: _ts, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(_scopeAr(r['scope']),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Spacer(),
                          if (r['is_active'] == true)
                            Icon(Icons.check_circle,
                                color: _ok, size: 12)
                          else
                            Icon(Icons.cancel, color: _err, size: 12),
                        ]),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  String _scopeAr(String? s) {
    switch (s) {
      case 'tenant':
        return 'المستأجر';
      case 'entity':
        return 'الكيان';
      case 'branch':
        return 'الفرع';
    }
    return s ?? '—';
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 3: Permissions
  // ════════════════════════════════════════════════════════════════════

  Widget _permissionsTab() {
    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in _permissions) {
      final cat = (p['category'] ?? 'other').toString();
      grouped.putIfAbsent(cat, () => []).add(p);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((e) {
        final perms = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _navy2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5)),
                  child: Icon(Icons.folder, color: _gold, size: 14),
                ),
                const SizedBox(width: 8),
                Text(e.key,
                    style: TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${perms.length}',
                      style: TextStyle(
                          color: _gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: perms.map((p) {
                  final critical = p['severity'] == 'critical';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (critical ? _err : _indigo).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: (critical ? _err : _indigo)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(p['code'] ?? '',
                              style: TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace')),
                          if (critical) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.warning, color: _err, size: 10),
                          ],
                        ]),
                        Text(p['description_ar'] ?? '',
                            style:
                                TextStyle(color: _ts, fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Invite Dialog
// ══════════════════════════════════════════════════════════════════════════

class _InviteDialog extends StatefulWidget {
  final List<Map<String, dynamic>> roles;
  final List<Map<String, dynamic>> entities;
  final List<Map<String, dynamic>> branches;
  const _InviteDialog(
      {required this.roles,
      required this.entities,
      required this.branches});
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  String _language = 'ar';
  String? _roleId;
  String _scope = 'entity';
  String? _entityId;
  String? _branchId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _name, _mobile]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _name.text.trim().isEmpty) {
      setState(() => _error = 'البريد والاسم مطلوبان');
      return;
    }
    if (_roleId == null) {
      setState(() => _error = 'اختر دوراً');
      return;
    }
    if (_scope == 'entity' && _entityId == null) {
      setState(() => _error = 'اختر كياناً');
      return;
    }
    if (_scope == 'branch' && _branchId == null) {
      setState(() => _error = 'اختر فرعاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'email': _email.text.trim(),
      'display_name': _name.text.trim(),
      if (_mobile.text.trim().isNotEmpty) 'mobile': _mobile.text.trim(),
      'language': _language,
      'role_id': _roleId,
      'scope': _scope,
      if (_scope == 'entity') 'entity_id': _entityId,
      if (_scope == 'branch') 'branch_id': _branchId,
    };
    final r =
        await pilotClient.inviteMember(PilotSession.tenantId!, body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok, content: Text('تم إرسال الدعوة ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الدعوة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Icon(Icons.person_add, color: _gold),
          SizedBox(width: 8),
          Text('دعوة عضو جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('البريد الإلكتروني *', _email, mono: true),
                const SizedBox(height: 8),
                _field('الاسم *', _name),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _field('رقم الجوال', _mobile, mono: true)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dd('اللغة', _language, const [
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ], (v) => setState(() => _language = v!)),
                  ),
                ]),
                const SizedBox(height: 14),
                _dd<String?>(
                    'الدور *',
                    _roleId,
                    [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('— اختر دوراً —')),
                      ...widget.roles.map((r) => DropdownMenuItem<String?>(
                          value: r['id'] as String,
                          child: Text('${r['code']} — ${r['name_ar']}',
                              overflow: TextOverflow.ellipsis))),
                    ],
                    (v) => setState(() => _roleId = v)),
                const SizedBox(height: 8),
                _dd('النطاق', _scope, const [
                  DropdownMenuItem(value: 'entity', child: Text('الكيان')),
                  DropdownMenuItem(value: 'branch', child: Text('الفرع')),
                ], (v) => setState(() {
                      _scope = v!;
                      _entityId = null;
                      _branchId = null;
                    })),
                const SizedBox(height: 8),
                if (_scope == 'entity')
                  _dd<String?>(
                      'الكيان *',
                      _entityId,
                      [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('— اختر —')),
                        ...widget.entities.map((e) => DropdownMenuItem<String?>(
                            value: e['id'] as String,
                            child: Text('${e['code']} — ${e['name_ar']}',
                                overflow: TextOverflow.ellipsis))),
                      ],
                      (v) => setState(() => _entityId = v))
                else
                  _dd<String?>(
                      'الفرع *',
                      _branchId,
                      [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('— اختر —')),
                        ...widget.branches.map((b) => DropdownMenuItem<String?>(
                            value: b['id'] as String,
                            child: Text(
                                '${b['_entity_code']} / ${b['code']} — ${b['city'] ?? ""}',
                                overflow: TextOverflow.ellipsis))),
                      ],
                      (v) => setState(() => _branchId = v)),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(color: _err, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إرسال الدعوة'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: TextStyle(
              color: _tp,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _dd<T>(String label, T value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _navy2,
              style: TextStyle(color: _tp, fontSize: 12),
              icon: Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Role Dialog
// ══════════════════════════════════════════════════════════════════════════

class _RoleDialog extends StatefulWidget {
  final List<Map<String, dynamic>> permissions;
  const _RoleDialog({required this.permissions});
  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  final _code = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _desc = TextEditingController();
  String _scope = 'branch';
  final Set<String> _selectedPerms = {};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _nameAr, _nameEn, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _nameAr.text.trim().isEmpty) {
      setState(() => _error = 'الكود والاسم العربي مطلوبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'code': _code.text.trim(),
      'name_ar': _nameAr.text.trim(),
      if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
      if (_desc.text.trim().isNotEmpty) 'description_ar': _desc.text.trim(),
      'scope': _scope,
      'permission_ids': _selectedPerms.toList(),
    };
    final r = await pilotClient.createRole(PilotSession.tenantId!, body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء الدور ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group permissions by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in widget.permissions) {
      final cat = (p['category'] ?? 'other').toString();
      grouped.putIfAbsent(cat, () => []).add(p);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Icon(Icons.badge, color: _gold),
          SizedBox(width: 8),
          Text('دور جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 620,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: _field('الكود *', _code, mono: true)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2, child: _field('الاسم العربي *', _nameAr)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2, child: _field('الاسم الإنجليزي', _nameEn)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      flex: 3, child: _field('الوصف', _desc)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dd('النطاق', _scope, const [
                      DropdownMenuItem(
                          value: 'tenant', child: Text('المستأجر')),
                      DropdownMenuItem(
                          value: 'entity', child: Text('الكيان')),
                      DropdownMenuItem(
                          value: 'branch', child: Text('الفرع')),
                    ], (v) => setState(() => _scope = v!)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Text('الصلاحيات',
                      style: TextStyle(
                          color: _tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        '${_selectedPerms.length} / ${widget.permissions.length}',
                        style: TextStyle(
                            color: _gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _ts),
                    onPressed: () => setState(() => _selectedPerms.clear()),
                    child: const Text('مسح الكل',
                        style: TextStyle(fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 6),
                ...grouped.entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _navy3,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _bdr)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(e.key,
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: _gold,
                                  padding: EdgeInsets.zero),
                              onPressed: () {
                                setState(() {
                                  final allIds = e.value
                                      .map((p) => p['id'] as String)
                                      .toSet();
                                  if (allIds.every(_selectedPerms.contains)) {
                                    _selectedPerms.removeAll(allIds);
                                  } else {
                                    _selectedPerms.addAll(allIds);
                                  }
                                });
                              },
                              child: const Text('الكل',
                                  style: TextStyle(fontSize: 10)),
                            ),
                          ]),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: e.value.map((p) {
                              final id = p['id'] as String;
                              final sel = _selectedPerms.contains(id);
                              return InkWell(
                                onTap: () => setState(() {
                                  if (sel) {
                                    _selectedPerms.remove(id);
                                  } else {
                                    _selectedPerms.add(id);
                                  }
                                }),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? _gold.withValues(alpha: 0.18)
                                        : _navy2,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: sel ? _gold : _bdr),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            sel
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: sel ? _gold : _td,
                                            size: 10),
                                        const SizedBox(width: 3),
                                        Text(p['code'] ?? '',
                                            style: TextStyle(
                                                color: sel ? _gold : _ts,
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    )),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(color: _err, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: TextStyle(
              color: _tp,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _dd<T>(String label, T value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _navy2,
              style: TextStyle(color: _tp, fontSize: 12),
              icon: Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
