/// Chart of Accounts Editor — محرر شجرة الحسابات الحقيقي.
///
/// يعتمد على PilotSession.entityId. مكتفٍ ذاتياً — لا bridge.
///
/// يعرض الحسابات كشجرة مجمّعة حسب الفئة (asset/liability/equity/revenue/expense)،
/// مع قيم الميزان في الأعمدة (مدين/دائن). يدعم:
///   • بذر شجرة SOCPA الافتراضية (37 حساباً)
///   • إضافة حساب جديد (مع parent_account_id + currency + is_control ...)
///   • بحث + فلترة category/type
///   • عرض مباشر لقيم الأرصدة من /reports/trial-balance
library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
import '../../num_utils.dart';
import '../../session.dart';

const _gold = Color(0xFFD4AF37);
const _navy = Color(0xFF0A1628);
const _navy2 = Color(0xFF132339);
const _navy3 = Color(0xFF1D3150);
const _bdr = Color(0x33FFFFFF);
const _tp = Color(0xFFFFFFFF);
const _ts = Color(0xFFBCC5D3);
const _td = Color(0xFF6B7A90);
const _ok = Color(0xFF10B981);
const _err = Color(0xFFEF4444);
const _warn = Color(0xFFF59E0B);

const _kCategories = <String, String>{
  'asset': 'الأصول',
  'liability': 'الخصوم',
  'equity': 'حقوق الملكية',
  'revenue': 'الإيرادات',
  'expense': 'المصروفات',
};

const _kCategoryColors = <String, Color>{
  'asset': Color(0xFF10B981),
  'liability': Color(0xFFF59E0B),
  'equity': Color(0xFF8B5CF6),
  'revenue': Color(0xFF3B82F6),
  'expense': Color(0xFFEF4444),
};

class CoaEditorScreen extends StatefulWidget {
  const CoaEditorScreen({super.key});
  @override
  State<CoaEditorScreen> createState() => _CoaEditorScreenState();
}

class _CoaEditorScreenState extends State<CoaEditorScreen> {
  final PilotClient _client = pilotClient;

  List<Map<String, dynamic>> _accounts = [];
  Map<String, Map<String, dynamic>> _balances = {}; // accountId -> {debit,credit,net}
  bool _loading = true;
  bool _seeding = false;
  String? _error;

  String _categoryFilter = 'all'; // all | asset | liability | equity | revenue | expense
  String _typeFilter = 'all';     // all | header | detail
  String _searchQuery = '';
  bool _includeInactive = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasEntity) {
      setState(() {
        _loading = false;
        _error = 'يجب اختيار الكيان من شريط العنوان أولاً.';
      });
      return;
    }
    final eid = PilotSession.entityId!;
    // 1) Accounts
    final ar = await _client.listAccounts(eid, includeInactive: _includeInactive);
    if (!ar.success) {
      setState(() {
        _loading = false;
        _error = ar.error ?? 'فشل تحميل الحسابات';
      });
      return;
    }
    _accounts = List<Map<String, dynamic>>.from(ar.data);
    // 2) Trial balance (silent — اختياري)
    _balances = {};
    try {
      final tr = await _client.trialBalance(eid, includeZero: true);
      if (tr.success && tr.data is Map) {
        final rows = (tr.data as Map)['rows'];
        if (rows is List) {
          for (final r in rows) {
            if (r is Map && r['account_id'] != null) {
              _balances[r['account_id']] = {
                'debit': asDouble(r['debit_balance']),
                'credit': asDouble(r['credit_balance']),
                'net': asDouble(r['net_balance']),
              };
            }
          }
        }
      }
    } catch (_) {/* صامت — لا نمنع عرض الشجرة */}

    setState(() => _loading = false);
  }

  Future<void> _seedDefault() async {
    if (!PilotSession.hasEntity) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('بذر الشجرة الافتراضية',
              style: TextStyle(color: _tp)),
          content: const Text(
              '37 حساباً حسب SOCPA (جمعية المحاسبين السعوديين)، منظّمة في 5 فئات.\n\nلا يمكن التراجع بعد البذر.',
              style: TextStyle(color: _ts, height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('بذر الآن')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _seeding = true);
    final r = await _client.seedCoa(PilotSession.entityId!);
    setState(() => _seeding = false);
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok,
          content: Text('تم بذر ${(r.data as Map)['created_count'] ?? 37} حساب ✓')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _err, content: Text(r.error ?? 'فشل البذر')));
    }
  }

  Future<void> _addAccount() async {
    if (!PilotSession.hasEntity) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddAccountDialog(
        entityId: PilotSession.entityId!,
        allAccounts: _accounts,
      ),
    );
    if (result == true) _load();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _accounts;
    if (_categoryFilter != 'all') {
      list = list.where((a) => a['category'] == _categoryFilter).toList();
    }
    if (_typeFilter != 'all') {
      list = list.where((a) => a['type'] == _typeFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((a) {
        final code = (a['code'] ?? '').toString().toLowerCase();
        final ar = (a['name_ar'] ?? '').toString().toLowerCase();
        final en = (a['name_en'] ?? '').toString().toLowerCase();
        return code.contains(q) || ar.contains(q) || en.contains(q);
      }).toList();
    }
    return list;
  }

  Map<String, List<Map<String, dynamic>>> get _byCategory {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final a in _filtered) {
      final c = (a['category'] ?? '').toString();
      m.putIfAbsent(c, () => []).add(a);
    }
    for (final list in m.values) {
      list.sort((x, y) =>
          (x['code'] ?? '').toString().compareTo((y['code'] ?? '').toString()));
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(
          children: [
            _buildHeader(),
            _buildToolbar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: _navy2,
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.account_tree, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('شجرة الحسابات',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
              _accounts.isEmpty
                  ? 'لم تبذَر بعد — اضغط "بذر الشجرة الافتراضية"'
                  : '${_accounts.length} حساب — ${_filtered.length} مرئي بعد التصفية',
              style: const TextStyle(color: _ts, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        if (_accounts.isEmpty && !_loading && PilotSession.hasEntity)
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _seeding ? null : _seedDefault,
            icon: _seeding
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 16),
            label: const Text('بذر الشجرة الافتراضية (SOCPA)'),
          ),
        if (_accounts.isNotEmpty) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: const BorderSide(color: _bdr)),
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('تحديث'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _addAccount,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة حساب'),
          ),
        ],
      ]),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: _navy2.withValues(alpha: 0.6),
      child: Row(children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _tp, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'بحث بالرقم أو الاسم...',
              hintStyle: const TextStyle(color: _td),
              prefixIcon: const Icon(Icons.search, color: _td, size: 18),
              isDense: true,
              filled: true,
              fillColor: _navy3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _bdr)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _bdr)),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(width: 12),
        _buildFilterChip(
            'all', 'الكل', _categoryFilter == 'all', () => setState(() => _categoryFilter = 'all')),
        const SizedBox(width: 6),
        ..._kCategories.entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildFilterChip(
                  e.key,
                  e.value,
                  _categoryFilter == e.key,
                  () => setState(() => _categoryFilter = e.key)),
            )),
        const SizedBox(width: 16),
        const Text('النوع:', style: TextStyle(color: _td, fontSize: 12)),
        const SizedBox(width: 6),
        _buildFilterChip(
            'all-t', 'الكل', _typeFilter == 'all', () => setState(() => _typeFilter = 'all')),
        const SizedBox(width: 6),
        _buildFilterChip('header-t', 'رئيسي', _typeFilter == 'header',
            () => setState(() => _typeFilter = 'header')),
        const SizedBox(width: 6),
        _buildFilterChip('detail-t', 'فرعي', _typeFilter == 'detail',
            () => setState(() => _typeFilter = 'detail')),
        const Spacer(),
        Row(children: [
          Checkbox(
            value: _includeInactive,
            onChanged: (v) {
              setState(() => _includeInactive = v ?? false);
              _load();
            },
            checkColor: Colors.black,
            fillColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.selected) ? _gold : _navy3),
          ),
          const Text('إظهار المُعطَّل', style: TextStyle(color: _ts, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildFilterChip(String key, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _gold : _navy3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? _gold : _bdr, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.black : _ts,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _ts, fontSize: 14)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: const BorderSide(color: _bdr)),
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }
    if (_accounts.isEmpty) {
      return _buildEmpty();
    }
    final grouped = _byCategory;
    return Row(children: [
      // Summary sidebar (left in RTL = visually right)
      Container(
        width: 240,
        color: _navy2,
        child: _buildSummarySidebar(grouped),
      ),
      // Accounts table
      Expanded(child: _buildAccountsTable(grouped)),
    ]);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_tree_outlined,
            color: _gold.withValues(alpha: 0.4), size: 72),
        const SizedBox(height: 16),
        const Text('لا توجد حسابات بعد',
            style: TextStyle(
                color: _tp, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'يمكنك بذر شجرة SOCPA الافتراضية (37 حساباً)\nأو إضافة حساب يدوياً',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ts, fontSize: 13, height: 1.6)),
        const SizedBox(height: 24),
        Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _seeding ? null : _seedDefault,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('بذر الشجرة الافتراضية'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp,
                side: const BorderSide(color: _bdr),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _addAccount,
            icon: const Icon(Icons.add),
            label: const Text('إضافة حساب يدوي'),
          ),
        ]),
      ]),
    );
  }

  Widget _buildSummarySidebar(Map<String, List<Map<String, dynamic>>> grouped) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ملخص',
            style: TextStyle(
                color: _td,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
        const SizedBox(height: 12),
        _summaryTile('كل الحسابات', '${_accounts.length}',
            Icons.account_tree, _gold),
        const SizedBox(height: 8),
        ..._kCategories.entries.map((e) {
          final count = grouped[e.key]?.length ?? 0;
          final c = _kCategoryColors[e.key]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _summaryTile(e.value, '$count', _iconForCategory(e.key), c),
          );
        }),
        const SizedBox(height: 20),
        const Divider(color: _bdr, height: 1),
        const SizedBox(height: 20),
        const Text('الحالة',
            style: TextStyle(
                color: _td,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        _summaryTile('مفعّلة',
            '${_accounts.where((a) => a['is_active'] == true).length}',
            Icons.check_circle, _ok),
        const SizedBox(height: 8),
        _summaryTile('تحكم',
            '${_accounts.where((a) => a['is_control'] == true).length}',
            Icons.lock, _warn),
        const SizedBox(height: 8),
        _summaryTile('نظام',
            '${_accounts.where((a) => a['is_system'] == true).length}',
            Icons.shield, const Color(0xFF6366F1)),
      ],
    );
  }

  IconData _iconForCategory(String c) {
    switch (c) {
      case 'asset':
        return Icons.trending_up;
      case 'liability':
        return Icons.trending_down;
      case 'equity':
        return Icons.person;
      case 'revenue':
        return Icons.attach_money;
      case 'expense':
        return Icons.money_off;
    }
    return Icons.circle;
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: _ts, fontSize: 12)),
        ),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildAccountsTable(Map<String, List<Map<String, dynamic>>> grouped) {
    final orderedCats = _categoryFilter == 'all'
        ? _kCategories.keys.toList()
        : [_categoryFilter];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: const [
            SizedBox(width: 80, child: Text('الرقم', style: _thStyle)),
            Expanded(flex: 3, child: Text('الاسم', style: _thStyle)),
            SizedBox(width: 90, child: Text('النوع', style: _thStyle)),
            SizedBox(width: 90, child: Text('الطبيعة', style: _thStyle)),
            SizedBox(
                width: 120,
                child: Text('مدين', style: _thStyle, textAlign: TextAlign.end)),
            SizedBox(
                width: 120,
                child: Text('دائن', style: _thStyle, textAlign: TextAlign.end)),
            SizedBox(
                width: 120,
                child: Text('الرصيد', style: _thStyle, textAlign: TextAlign.end)),
            SizedBox(width: 60, child: Text('حالة', style: _thStyle)),
          ]),
        ),
        const SizedBox(height: 10),
        ...orderedCats.where((c) => grouped.containsKey(c)).map((c) {
          final list = grouped[c]!;
          final color = _kCategoryColors[c]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_iconForCategory(c), color: color, size: 14),
                    const SizedBox(width: 6),
                    Text('${_kCategories[c]} (${list.length})',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 6),
                ...list.map((a) => _accountRow(a, color)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _accountRow(Map<String, dynamic> a, Color catColor) {
    final isHeader = a['type'] == 'header';
    final bal = _balances[a['id']];
    final debit = (bal?['debit'] ?? 0.0) as double;
    final credit = (bal?['credit'] ?? 0.0) as double;
    final net = (bal?['net'] ?? 0.0) as double;
    final isActive = a['is_active'] == true;
    final isSystem = a['is_system'] == true;
    final isControl = a['is_control'] == true;
    final level = (a['level'] ?? 1) as int;
    final indent = (level - 1) * 14.0;

    return InkWell(
      onTap: () => _showAccountDetail(a),
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isHeader
              ? catColor.withValues(alpha: 0.06)
              : _navy2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isActive ? _bdr : _err.withValues(alpha: 0.4),
              width: 1),
        ),
        child: Row(children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: EdgeInsets.only(right: indent),
              child: Text(a['code'] ?? '',
                  style: TextStyle(
                      color: isHeader ? catColor : _tp,
                      fontSize: 13,
                      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
                      fontFamily: 'monospace')),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(right: indent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a['name_ar'] ?? '',
                    style: TextStyle(
                        color: isHeader ? catColor : _tp,
                        fontSize: 13,
                        fontWeight:
                            isHeader ? FontWeight.w700 : FontWeight.w500),
                  ),
                  if ((a['name_en'] ?? '').toString().isNotEmpty)
                    Text(
                      a['name_en'],
                      style: const TextStyle(color: _td, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
              width: 90,
              child: _miniBadge(
                  isHeader ? 'رئيسي' : 'فرعي',
                  isHeader ? _warn : const Color(0xFF6366F1))),
          SizedBox(
            width: 90,
            child: _miniBadge(
                a['normal_balance'] == 'debit' ? 'مدين' : 'دائن',
                a['normal_balance'] == 'debit' ? _ok : _err),
          ),
          SizedBox(
            width: 120,
            child: Text(_fmt(debit),
                style: const TextStyle(
                    color: _tp, fontSize: 12, fontFamily: 'monospace'),
                textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 120,
            child: Text(_fmt(credit),
                style: const TextStyle(
                    color: _tp, fontSize: 12, fontFamily: 'monospace'),
                textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 120,
            child: Text(_fmt(net.abs()),
                style: TextStyle(
                    color: net == 0 ? _td : (net > 0 ? _ok : _err),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 60,
            child: Row(children: [
              if (isSystem) ...[
                const Icon(Icons.shield, color: Color(0xFF6366F1), size: 12),
                const SizedBox(width: 3),
              ],
              if (isControl) ...[
                const Icon(Icons.lock, color: _warn, size: 12),
                const SizedBox(width: 3),
              ],
              if (!isActive)
                const Icon(Icons.visibility_off, color: _err, size: 12),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intPart.${parts[1]}';
  }

  void _showAccountDetail(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kCategoryColors[a['category']]!.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(a['code'] ?? '',
                  style: TextStyle(
                      color: _kCategoryColors[a['category']],
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(a['name_ar'] ?? '',
                  style: const TextStyle(color: _tp, fontSize: 15)),
            ),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('الاسم EN', a['name_en'] ?? '—'),
                _kv('الفئة', _kCategories[a['category']] ?? a['category']),
                _kv('النوع', a['type'] == 'header' ? 'رئيسي' : 'فرعي'),
                _kv('الطبيعة', a['normal_balance'] == 'debit' ? 'مدين' : 'دائن'),
                _kv('المستوى', '${a['level']}'),
                _kv('العملة', a['currency'] ?? '—'),
                _kv('حساب تحكم', a['is_control'] == true ? 'نعم' : 'لا'),
                _kv('مركز تكلفة مطلوب',
                    a['require_cost_center'] == true ? 'نعم' : 'لا'),
                _kv('حساب نظام', a['is_system'] == true ? 'نعم' : 'لا'),
                _kv('مفعّل', a['is_active'] == true ? 'نعم' : 'لا'),
                _kv('المعرف (UUID)', a['id'] ?? '—', mono: true),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(k, style: const TextStyle(color: _td, fontSize: 12)),
        ),
        Expanded(
          child: Text(v,
              style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null)),
        ),
      ]),
    );
  }
}

const _thStyle = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════════
// Add Account Dialog
// ══════════════════════════════════════════════════════════════════════════

class _AddAccountDialog extends StatefulWidget {
  final String entityId;
  final List<Map<String, dynamic>> allAccounts;
  const _AddAccountDialog({required this.entityId, required this.allAccounts});
  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _codeCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _subcategoryCtrl = TextEditingController();
  String _category = 'asset';
  String _type = 'detail';
  String _normalBalance = 'debit';
  String? _parentId;
  String _currency = 'SAR';
  bool _isControl = false;
  bool _requireCostCenter = false;
  bool _requireProfitCenter = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _normalBalance = _defaultNormalFor(_category);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _subcategoryCtrl.dispose();
    super.dispose();
  }

  String _defaultNormalFor(String c) {
    // debit-normal: asset + expense. credit-normal: liability + equity + revenue
    return (c == 'asset' || c == 'expense') ? 'debit' : 'credit';
  }

  Future<void> _submit() async {
    if (_codeCtrl.text.trim().isEmpty || _nameArCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرقم والاسم العربي مطلوبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'code': _codeCtrl.text.trim(),
      'name_ar': _nameArCtrl.text.trim(),
      if (_nameEnCtrl.text.trim().isNotEmpty) 'name_en': _nameEnCtrl.text.trim(),
      if (_parentId != null) 'parent_account_id': _parentId,
      'category': _category,
      if (_subcategoryCtrl.text.trim().isNotEmpty)
        'subcategory': _subcategoryCtrl.text.trim(),
      'type': _type,
      'normal_balance': _normalBalance,
      'currency': _currency,
      'is_control': _isControl,
      'require_cost_center': _requireCostCenter,
      'require_profit_center': _requireProfitCenter,
    };
    final r = await pilotClient.createAccount(widget.entityId, body);
    setState(() => _loading = false);
    if (r.success) {
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء الحساب ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parent candidates — same category, header type
    final parents = widget.allAccounts
        .where((a) => a['category'] == _category && a['type'] == 'header')
        .toList()
      ..sort((a, b) => (a['code'] ?? '').toString().compareTo((b['code'] ?? '').toString()));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: const [
          Icon(Icons.add_circle, color: _gold),
          SizedBox(width: 8),
          Text('إضافة حساب جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: code + name_ar
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: _field('الرقم *', _codeCtrl,
                        hint: 'مثال: 1115', mono: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 5, child: _field('الاسم العربي *', _nameArCtrl)),
                ]),
                const SizedBox(height: 10),
                _field('الاسم الإنجليزي', _nameEnCtrl),
                const SizedBox(height: 10),
                // Row 2: category + subcategory
                Row(children: [
                  Expanded(
                    child: _dropdown(
                      'الفئة',
                      _category,
                      _kCategories.entries
                          .map((e) =>
                              DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      (v) => setState(() {
                        _category = v!;
                        _normalBalance = _defaultNormalFor(v);
                        _parentId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _field('التصنيف الفرعي', _subcategoryCtrl)),
                ]),
                const SizedBox(height: 10),
                // Row 3: type + normal_balance
                Row(children: [
                  Expanded(
                    child: _dropdown(
                      'النوع',
                      _type,
                      const [
                        DropdownMenuItem(
                            value: 'detail', child: Text('فرعي (Detail)')),
                        DropdownMenuItem(
                            value: 'header', child: Text('رئيسي (Header)')),
                      ],
                      (v) => setState(() => _type = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown(
                      'الطبيعة',
                      _normalBalance,
                      const [
                        DropdownMenuItem(
                            value: 'debit', child: Text('مدين (Debit)')),
                        DropdownMenuItem(
                            value: 'credit', child: Text('دائن (Credit)')),
                      ],
                      (v) => setState(() => _normalBalance = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // Row 4: parent + currency
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: _dropdown(
                      'الحساب الأب (اختياري)',
                      _parentId,
                      [
                        const DropdownMenuItem(value: null, child: Text('— جذر —')),
                        ...parents.map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                  '${p['code']} — ${p['name_ar']}',
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      (v) => setState(() => _parentId = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown(
                      'العملة',
                      _currency,
                      const [
                        DropdownMenuItem(value: 'SAR', child: Text('SAR — ريال')),
                        DropdownMenuItem(value: 'USD', child: Text('USD — دولار')),
                        DropdownMenuItem(value: 'AED', child: Text('AED — درهم')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR — يورو')),
                      ],
                      (v) => setState(() => _currency = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Flags
                Row(children: [
                  _checkTile(
                      'حساب تحكم',
                      _isControl,
                      (v) => setState(() => _isControl = v)),
                  _checkTile(
                      'مركز تكلفة مطلوب',
                      _requireCostCenter,
                      (v) => setState(() => _requireCostCenter = v)),
                  _checkTile(
                      'مركز ربحية مطلوب',
                      _requireProfitCenter,
                      (v) => setState(() => _requireProfitCenter = v)),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _err.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _err.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: _err, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: _err, fontSize: 12)),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: _ts)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: TextStyle(
              color: _tp, fontSize: 13, fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _td),
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>(String label, T? value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _navy2,
              style: const TextStyle(color: _tp, fontSize: 13),
              icon: const Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              checkColor: Colors.black,
              fillColor: WidgetStateProperty.resolveWith<Color?>((states) =>
                  states.contains(WidgetState.selected) ? _gold : _navy3),
            ),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _ts, fontSize: 11)),
            ),
          ]),
        ),
      ),
    );
  }
}
