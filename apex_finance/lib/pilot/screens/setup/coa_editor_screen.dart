/// Chart of Accounts Editor — محرر شجرة الحسابات الحقيقي (v2).
///
/// يعتمد على PilotSession.entityId. مكتفٍ ذاتياً.
///
/// الميزات (10):
///   1. شجرة قابلة للطيّ (chevrons + expand-all/collapse-all)
///   2. تعديل inline (double-click) + قائمة سياق (right-click)
///   3. Drill-down → دفتر الأستاذ
///   4. تحديد متعدد + شريط إجراءات عائم
///   5. اختصارات لوحة مفاتيح (/, N, E, Esc, ↑↓, Space, ?, Delete)
///   6. اقتراح ذكي لأرقام الحسابات (بناءً على parent)
///   7. تصدير CSV / Excel / PDF (الطباعة)
///   8. ربط ZATCA VAT code + تحذير عند الفقد
///   9. اختيار الأعمدة المرئية
///  10. أرشفة + سجل تغييرات (drawer)
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../../../core/theme.dart' as core_theme;
import '../../api/pilot_client.dart';
import '../../export_utils.dart';
import '../../num_utils.dart';
import '../../session.dart';
import '../../widgets/import_dialog.dart';

Color get _gold => core_theme.AC.gold;
Color get _navy => core_theme.AC.navy;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _navy4 => core_theme.AC.navy4;
Color get _bdr => core_theme.AC.bdr;
Color get _tp => core_theme.AC.tp;
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;
Color get _warn => core_theme.AC.warn;

final _kCategories = <String, String>{
  'asset': 'الأصول',
  'liability': 'الخصوم',
  'equity': 'حقوق الملكية',
  'revenue': 'الإيرادات',
  'expense': 'المصروفات',
};

Map<String, Color> get _kCategoryColors => <String, Color>{
      'asset': core_theme.AC.ok,
      'liability': core_theme.AC.warn,
      'equity': core_theme.AC.purple,
      'revenue': core_theme.AC.info,
      'expense': core_theme.AC.err,
    };

/// ZATCA VAT codes (مبسّط):
///   STANDARD_15 → 15% قياسي
///   ZERO_RATED  → 0% صفري (صادرات/مناطق خاصة)
///   EXEMPT      → معفى (رسوم حكومية، عقارات)
///   OUT_OF_SCOPE → خارج النطاق
const _kVatCodes = <String, String>{
  'STANDARD_15': 'قياسي 15%',
  'ZERO_RATED': 'صفري 0%',
  'EXEMPT': 'معفى',
  'OUT_OF_SCOPE': 'خارج النطاق',
};

/// الأعمدة القابلة للإظهار/الإخفاء. المفاتيح لا تُترجم.
const _kAllColumns = <String>[
  'select', // دائماً (لا يُخفى)
  'code',
  'name',
  'type',
  'normal',
  'vat',
  'debit',
  'credit',
  'net',
  'status',
  'actions',
];

const _kColumnLabels = <String, String>{
  'select': '',
  'code': 'الرقم',
  'name': 'الاسم',
  'type': 'النوع',
  'normal': 'الطبيعة',
  'vat': 'ضريبة',
  'debit': 'مدين',
  'credit': 'دائن',
  'net': 'الرصيد',
  'status': 'حالة',
  'actions': '',
};

class CoaEditorScreen extends StatefulWidget {
  const CoaEditorScreen({super.key});
  @override
  State<CoaEditorScreen> createState() => _CoaEditorScreenState();
}

class _CoaEditorScreenState extends State<CoaEditorScreen> {
  final PilotClient _client = pilotClient;

  // ── Data ──────────────────────────────────────────────
  List<Map<String, dynamic>> _accounts = [];
  final Map<String, Map<String, dynamic>> _accById = {};
  final Map<String?, List<String>> _childrenOf = {}; // parent_id (or null) -> child_ids
  Map<String, Map<String, dynamic>> _balances = {};

  // ── UI state ─────────────────────────────────────────
  bool _loading = true;
  bool _seeding = false;
  String? _error;
  final Set<String> _expandedIds = {};
  final Set<String> _selectedIds = {};
  String? _focusedId;
  String? _editingId; // id of row in inline-edit mode (name_ar)
  final TextEditingController _editCtrl = TextEditingController();
  final FocusNode _editFocus = FocusNode();

  // ── Filters ──────────────────────────────────────────
  String _categoryFilter = 'all'; // all | asset | liability | equity | revenue | expense
  String _typeFilter = 'all'; // all | header | detail
  String _normalFilter = 'all'; // all | debit | credit
  String _searchQuery = '';
  bool _includeInactive = false;
  bool _showOnlyMissingVat = false;
  bool _onlySystem = false;
  bool _onlyControl = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ── Column visibility ────────────────────────────────
  final Set<String> _visibleColumns = {
    'select', 'code', 'name', 'type', 'normal', 'vat', 'debit', 'credit', 'net', 'status', 'actions',
  };

  // ── Summary sidebar collapse (محفوظ في localStorage) ──
  bool _summaryCollapsed = _loadSummaryCollapsed();

  static bool _loadSummaryCollapsed() {
    try {
      return html.window.localStorage['coa_summary_collapsed'] == '1';
    } catch (_) {
      return false;
    }
  }

  void _toggleSummarySidebar() {
    setState(() {
      _summaryCollapsed = !_summaryCollapsed;
    });
    try {
      html.window.localStorage['coa_summary_collapsed'] =
          _summaryCollapsed ? '1' : '0';
    } catch (_) {}
  }

  // ── Scroll ───────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _hScrollCtrl = ScrollController();

  // ── Keyboard ─────────────────────────────────────────
  late final html.EventListener _kbListener;

  @override
  void initState() {
    super.initState();
    _kbListener = (e) => _handleKeyDown(e as html.KeyboardEvent);
    html.window.addEventListener('keydown', _kbListener, true);
    _load();
  }

  @override
  void dispose() {
    html.window.removeEventListener('keydown', _kbListener, true);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _editCtrl.dispose();
    _editFocus.dispose();
    _scrollCtrl.dispose();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ══════════════════════════════════════════════════════════════════════

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
    final ar = await _client.listAccounts(eid, includeInactive: _includeInactive);
    if (!ar.success) {
      setState(() {
        _loading = false;
        _error = ar.error ?? 'فشل تحميل الحسابات';
      });
      return;
    }
    _accounts = List<Map<String, dynamic>>.from(ar.data);
    _rebuildIndex();

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
    } catch (_) {/* silent */}

    _applyDefaultExpansion();
    setState(() => _loading = false);
  }

  void _rebuildIndex() {
    _accById.clear();
    _childrenOf.clear();
    for (final a in _accounts) {
      final id = a['id'] as String?;
      if (id == null) continue;
      _accById[id] = a;
    }
    for (final a in _accounts) {
      final id = a['id'] as String?;
      if (id == null) continue;
      final pid = a['parent_account_id'] as String?;
      _childrenOf.putIfAbsent(pid, () => []).add(id);
    }
    for (final list in _childrenOf.values) {
      list.sort((x, y) {
        final ax = (_accById[x]?['code'] ?? '').toString();
        final ay = (_accById[y]?['code'] ?? '').toString();
        return ax.compareTo(ay);
      });
    }
  }

  void _applyDefaultExpansion() {
    // الافتراضي: توسيع الكل — كل الحسابات التي لها أبناء مفتوحة.
    _expandedIds.clear();
    for (final a in _accounts) {
      final id = a['id'] as String?;
      if (id == null) continue;
      if ((_childrenOf[id] ?? []).isNotEmpty) {
        _expandedIds.add(id);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TREE NAVIGATION
  // ══════════════════════════════════════════════════════════════════════

  List<_TreeRow> _flatten() {
    // يبني قائمة مسطّحة من الشجرة مع الأخذ بعين الاعتبار:
    //   • حالة التوسّع
    //   • الفلاتر
    //   • البحث (مع توسيع الآباء تلقائياً عندما يطابق الابن)
    final q = _searchQuery.trim().toLowerCase();

    bool matchesFilters(Map<String, dynamic> a) {
      if (_categoryFilter != 'all' && a['category'] != _categoryFilter) return false;
      if (_typeFilter != 'all' && a['type'] != _typeFilter) return false;
      if (_normalFilter != 'all' && a['normal_balance'] != _normalFilter) return false;
      if (_onlySystem && a['is_system'] != true) return false;
      if (_onlyControl && a['is_control'] != true) return false;
      if (_showOnlyMissingVat) {
        final cat = a['category'];
        final isRevExp = cat == 'revenue' || cat == 'expense';
        final hasVat = (a['vat_code'] ?? '').toString().isNotEmpty;
        if (!isRevExp || hasVat) return false;
      }
      if (q.isNotEmpty) {
        final code = (a['code'] ?? '').toString().toLowerCase();
        final ar = (a['name_ar'] ?? '').toString().toLowerCase();
        final en = (a['name_en'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !ar.contains(q) && !en.contains(q)) return false;
      }
      return true;
    }

    // عند وجود بحث: نريد إظهار الحساب المطابق + كل آبائه.
    // نبني مجموعة "visibleIds" أولاً، ثم نسطّح.
    Set<String>? visibleIds;
    if (q.isNotEmpty || _searchQuery.isNotEmpty || _showOnlyMissingVat ||
        _categoryFilter != 'all' || _typeFilter != 'all' ||
        _normalFilter != 'all' || _onlySystem || _onlyControl) {
      visibleIds = <String>{};
      for (final a in _accounts) {
        if (matchesFilters(a)) {
          var cur = a['id'] as String?;
          while (cur != null && !visibleIds.contains(cur)) {
            visibleIds.add(cur);
            cur = _accById[cur]?['parent_account_id'] as String?;
          }
        }
      }
    }

    final rows = <_TreeRow>[];
    final roots = _childrenOf[null] ?? [];

    void walk(String id, int depth) {
      final a = _accById[id];
      if (a == null) return;
      if (visibleIds != null && !visibleIds.contains(id)) return;
      final kids = _childrenOf[id] ?? [];
      final hasKids = kids.isNotEmpty;
      // عند البحث، افتح الآباء تلقائياً
      final isExpanded =
          (visibleIds != null && hasKids) ? true : _expandedIds.contains(id);
      rows.add(_TreeRow(
        id: id,
        account: a,
        depth: depth,
        hasChildren: hasKids,
        isExpanded: isExpanded,
      ));
      if (isExpanded) {
        for (final k in kids) {
          walk(k, depth + 1);
        }
      }
    }

    for (final r in roots) {
      walk(r, 0);
    }
    return rows;
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _expandAll() {
    setState(() {
      for (final a in _accounts) {
        _expandedIds.add(a['id'] as String);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedIds.clear();
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // KEYBOARD
  // ══════════════════════════════════════════════════════════════════════

  void _handleKeyDown(html.KeyboardEvent e) {
    // تجاهل عند الكتابة في حقل (لكن نحترم بعض الاختصارات العامة).
    final active = html.document.activeElement;
    final tag = (active?.tagName ?? '').toUpperCase();
    final inTextField = tag == 'INPUT' || tag == 'TEXTAREA' ||
        (active?.getAttribute('contenteditable') == 'true');

    // Escape — يُعامَل دائماً
    if (e.key == 'Escape') {
      if (_editingId != null) {
        setState(() => _editingId = null);
        e.preventDefault();
        return;
      }
      if (_selectedIds.isNotEmpty) {
        setState(() => _selectedIds.clear());
        e.preventDefault();
        return;
      }
      if (_searchQuery.isNotEmpty) {
        _searchCtrl.clear();
        setState(() => _searchQuery = '');
        e.preventDefault();
        return;
      }
      _searchFocus.unfocus();
      return;
    }

    if (inTextField) return;

    final k = e.key;

    // "/" ركّز على البحث
    if (k == '/' || k == '？' || k == '؟') {
      if (k == '؟' || k == '？' || (e.shiftKey && k == '/')) {
        _showHelp();
      } else {
        _searchFocus.requestFocus();
      }
      e.preventDefault();
      return;
    }

    if (k == 'n' || k == 'N' || k == 'ن') {
      _addAccount();
      e.preventDefault();
      return;
    }

    if (k == 'e' || k == 'E' || k == 'ث') {
      if (_focusedId != null) _startInlineEdit(_focusedId!);
      e.preventDefault();
      return;
    }

    if (k == 'Delete' && _selectedIds.isNotEmpty) {
      _bulkArchive();
      e.preventDefault();
      return;
    }

    if (k == ' ' || k == 'Spacebar') {
      if (_focusedId != null) {
        final id = _focusedId!;
        if ((_childrenOf[id] ?? []).isNotEmpty) {
          _toggleExpand(id);
        } else {
          // toggle selection
          setState(() {
            if (_selectedIds.contains(id)) {
              _selectedIds.remove(id);
            } else {
              _selectedIds.add(id);
            }
          });
        }
        e.preventDefault();
      }
      return;
    }

    if (k == 'ArrowDown' || k == 'ArrowUp') {
      final rows = _flatten();
      if (rows.isEmpty) return;
      int idx = _focusedId == null
          ? -1
          : rows.indexWhere((r) => r.id == _focusedId);
      if (k == 'ArrowDown') {
        idx = (idx + 1).clamp(0, rows.length - 1);
      } else {
        idx = idx <= 0 ? 0 : idx - 1;
      }
      setState(() => _focusedId = rows[idx].id);
      e.preventDefault();
      return;
    }

    if (k == 'ArrowRight') {
      // في RTL: يمين = يدخل/يوسّع
      if (_focusedId != null && (_childrenOf[_focusedId!] ?? []).isNotEmpty) {
        if (!_expandedIds.contains(_focusedId!)) {
          _toggleExpand(_focusedId!);
          e.preventDefault();
        }
      }
      return;
    }

    if (k == 'ArrowLeft') {
      // RTL: يسار = يطوي/يرجع للأب
      if (_focusedId != null) {
        if (_expandedIds.contains(_focusedId!) &&
            (_childrenOf[_focusedId!] ?? []).isNotEmpty) {
          _toggleExpand(_focusedId!);
        } else {
          final pid = _accById[_focusedId!]?['parent_account_id'] as String?;
          if (pid != null) {
            setState(() => _focusedId = pid);
          }
        }
        e.preventDefault();
      }
      return;
    }

    // Ctrl+A — select all visible detail accounts
    if (e.ctrlKey && (k == 'a' || k == 'A')) {
      final rows = _flatten();
      setState(() {
        _selectedIds.clear();
        for (final r in rows) {
          if (r.account['type'] != 'header') {
            _selectedIds.add(r.id);
          }
        }
      });
      e.preventDefault();
      return;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _seedDefault() async {
    if (!PilotSession.hasEntity) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text('بذر الشجرة الافتراضية', style: TextStyle(color: _tp)),
          content: Text(
              '37 حساباً حسب SOCPA (جمعية المحاسبين السعوديين)، منظّمة في 5 فئات.\n\nلا يمكن التراجع بعد البذر.',
              style: TextStyle(color: _ts, height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: _tp),
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
      _snack('تم بذر ${(r.data as Map)['created_count'] ?? 37} حساب ✓', _ok);
      _load();
    } else {
      _snack(r.error ?? 'فشل البذر', _err);
    }
  }

  Future<void> _importExcel() async {
    if (!PilotSession.hasEntity) return;
    final eid = PilotSession.entityId!;
    await showDialog(
      context: context,
      builder: (_) => ImportDialog(
        title: 'استيراد شجرة الحسابات',
        mapping: coaMapping,
        requiredFields: const ['code', 'name_ar', 'category', 'normal_balance'],
        onImport: (row) async {
          final body = <String, dynamic>{
            'code': row['code'].toString(),
            'name_ar': row['name_ar'].toString(),
            if (row['name_en'] != null) 'name_en': row['name_en'].toString(),
            'category': row['category'].toString().toLowerCase(),
            'normal_balance': row['normal_balance'].toString().toLowerCase(),
            'type': (row['type']?.toString() ?? 'detail').toLowerCase(),
          };
          return pilotClient.createAccount(eid, body);
        },
      ),
    );
    _load();
  }

  Future<void> _addAccount({String? parentId}) async {
    if (!PilotSession.hasEntity) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddAccountDialog(
        entityId: PilotSession.entityId!,
        allAccounts: _accounts,
        initialParentId: parentId,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _duplicateAccount(Map<String, dynamic> a) async {
    if (!PilotSession.hasEntity) return;
    final eid = PilotSession.entityId!;
    final suggestedCode = _nextCodeForParent(a['parent_account_id']);
    final body = <String, dynamic>{
      'code': suggestedCode,
      'name_ar': '${a['name_ar']} (نسخة)',
      if (a['name_en'] != null) 'name_en': '${a['name_en']} (copy)',
      if (a['parent_account_id'] != null) 'parent_account_id': a['parent_account_id'],
      'category': a['category'],
      'type': a['type'],
      'normal_balance': a['normal_balance'],
      'currency': a['currency'] ?? 'SAR',
      'is_control': a['is_control'] ?? false,
      if (a['vat_code'] != null) 'vat_code': a['vat_code'],
    };
    final r = await _client.createAccount(eid, body);
    if (!mounted) return;
    if (r.success) {
      _snack('تم تكرار الحساب ✓', _ok);
      _load();
    } else {
      _snack(r.error ?? 'فشل التكرار', _err);
    }
  }

  Future<void> _archiveAccount(Map<String, dynamic> a, {bool activate = false}) async {
    final id = a['id'] as String;
    final r = await _client.updateAccount(id, {'is_active': activate});
    if (!mounted) return;
    if (r.success) {
      _snack(activate ? 'تم التفعيل ✓' : 'تم الأرشفة ✓', _ok);
      _load();
    } else {
      _snack(r.error ?? (activate ? 'فشل التفعيل' : 'فشل الأرشفة'), _err);
    }
  }

  Future<void> _bulkArchive() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text('أرشفة ${_selectedIds.length} حساب',
              style: TextStyle(color: _tp)),
          content: Text(
              'سيتم تعطيل الحسابات المختارة. يمكن إعادة تفعيلها لاحقاً من فلتر "إظهار المُعطَّل".',
              style: TextStyle(color: _ts, height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _err),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('أرشفة')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    int ok = 0, fail = 0;
    for (final id in _selectedIds.toList()) {
      final r = await _client.updateAccount(id, {'is_active': false});
      if (r.success) {
        ok++;
      } else {
        fail++;
      }
    }
    if (!mounted) return;
    _snack('تم أرشفة $ok حساب${fail > 0 ? " — فشل $fail" : ""}', fail > 0 ? _warn : _ok);
    setState(() => _selectedIds.clear());
    _load();
  }

  Future<void> _bulkActivate() async {
    if (_selectedIds.isEmpty) return;
    int ok = 0, fail = 0;
    for (final id in _selectedIds.toList()) {
      final r = await _client.updateAccount(id, {'is_active': true});
      if (r.success) {
        ok++;
      } else {
        fail++;
      }
    }
    if (!mounted) return;
    _snack('تم تفعيل $ok حساب${fail > 0 ? " — فشل $fail" : ""}', fail > 0 ? _warn : _ok);
    setState(() => _selectedIds.clear());
    _load();
  }

  void _startInlineEdit(String id) {
    final a = _accById[id];
    if (a == null) return;
    _editCtrl.text = (a['name_ar'] ?? '').toString();
    setState(() => _editingId = id);
    Future.microtask(() {
      _editFocus.requestFocus();
      _editCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _editCtrl.text.length);
    });
  }

  Future<void> _commitInlineEdit() async {
    final id = _editingId;
    if (id == null) return;
    final newName = _editCtrl.text.trim();
    if (newName.isEmpty) {
      setState(() => _editingId = null);
      return;
    }
    final old = _accById[id]?['name_ar'];
    if (newName == old) {
      setState(() => _editingId = null);
      return;
    }
    final r = await _client.updateAccount(id, {'name_ar': newName});
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _accById[id]?['name_ar'] = newName;
        _editingId = null;
      });
      _snack('تم الحفظ ✓', _ok);
    } else {
      _snack(r.error ?? 'فشل الحفظ', _err);
      setState(() => _editingId = null);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // SMART CODE SUGGESTION
  // ══════════════════════════════════════════════════════════════════════

  String _nextCodeForParent(String? parentId) {
    if (parentId == null) {
      // جذور: ابحث عن أعلى code في المستوى 0 + 1000
      final roots = _accounts.where((a) => a['parent_account_id'] == null);
      int maxCode = 0;
      for (final r in roots) {
        final c = int.tryParse((r['code'] ?? '').toString());
        if (c != null && c > maxCode) maxCode = c;
      }
      return maxCode == 0 ? '1000' : (((maxCode ~/ 1000) + 1) * 1000).toString();
    }
    final parent = _accById[parentId];
    if (parent == null) return '';
    final parentCode = (parent['code'] ?? '').toString();
    final children = (_childrenOf[parentId] ?? [])
        .map((id) => _accById[id])
        .where((a) => a != null)
        .cast<Map<String, dynamic>>()
        .toList();
    if (children.isEmpty) {
      // اقترح parentCode + 10 (مثلاً 1000 → 1010)
      final pc = int.tryParse(parentCode);
      if (pc != null) return (pc + 10).toString();
      return '${parentCode}1';
    }
    // ابحث عن أعلى code للأبناء + 10
    int maxChild = 0;
    for (final c in children) {
      final cc = int.tryParse((c['code'] ?? '').toString());
      if (cc != null && cc > maxChild) maxChild = cc;
    }
    if (maxChild > 0) return (maxChild + 10).toString();
    return '${parentCode}1';
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXPORT
  // ══════════════════════════════════════════════════════════════════════

  List<List<dynamic>> _exportRows() {
    final rows = _flatten();
    return rows.map((r) {
      final a = r.account;
      final bal = _balances[r.id] ?? {};
      return <dynamic>[
        a['code'] ?? '',
        ('    ' * r.depth) + (a['name_ar'] ?? ''),
        a['name_en'] ?? '',
        _kCategories[a['category']] ?? a['category'] ?? '',
        a['type'] == 'header' ? 'رئيسي' : 'فرعي',
        a['normal_balance'] == 'debit' ? 'مدين' : 'دائن',
        a['vat_code'] ?? '',
        a['currency'] ?? '',
        (bal['debit'] ?? 0.0).toDouble(),
        (bal['credit'] ?? 0.0).toDouble(),
        (bal['net'] ?? 0.0).toDouble(),
        a['is_active'] == true ? 'مفعّل' : 'مؤرشف',
      ];
    }).toList();
  }

  List<String> get _exportHeaders => const [
        'الرقم',
        'الاسم العربي',
        'الاسم الإنجليزي',
        'الفئة',
        'النوع',
        'الطبيعة',
        'كود ضريبة',
        'العملة',
        'مدين',
        'دائن',
        'الرصيد',
        'الحالة',
      ];

  void _exportCsv() {
    exportCsv(
      headers: _exportHeaders,
      rows: _exportRows(),
      filename: 'chart_of_accounts_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _exportXlsx() {
    exportXlsx(
      headers: _exportHeaders,
      rows: _exportRows(),
      filename: 'chart_of_accounts_${DateTime.now().millisecondsSinceEpoch}',
      sheetName: 'CoA',
      title: 'شجرة الحسابات',
      meta: {
        'تاريخ التصدير': DateTime.now().toIso8601String().substring(0, 10),
        'عدد الحسابات': _accounts.length,
      },
    );
  }

  void _exportPdf() {
    printHtmlTable(
      title: 'شجرة الحسابات',
      companyName: 'APEX',
      companyMeta: 'تاريخ: ${DateTime.now().toIso8601String().substring(0, 10)}',
      headers: _exportHeaders,
      rows: _exportRows().map((r) => r.map((v) => v.toString()).toList()).toList(),
      footer: '© APEX — تم إنشاؤه بواسطة نظام شجرة الحسابات',
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Stack(children: [
          Column(
            children: [
              _buildHeader(),
              _buildFilterBar(),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_selectedIds.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: _buildBulkBar()),
            ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: _navy2,
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.account_tree, color: _gold, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('شجرة الحسابات',
                  style: TextStyle(
                      color: _tp,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(
                _accounts.isEmpty
                    ? 'لم تبذَر بعد'
                    : '${_accounts.length} • ${_flatten().length} مرئي',
                style: TextStyle(color: _ts, fontSize: 11, height: 1.1),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (_accounts.isNotEmpty) ...[
          const SizedBox(width: 14),
          // Compact search field (200px)
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(color: _tp, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'بحث (/)',
                hintStyle: TextStyle(color: _td, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: _td, size: 16),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : InkWell(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close, color: _td, size: 14),
                      ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _bdr)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _bdr)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _gold, width: 1.2)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 6),
          _buildFilterButton(_countActiveFilters()),
          const SizedBox(width: 4),
          _headerIconBtn(
            icon: Icons.unfold_more,
            tooltip: 'توسّع الكل',
            onPressed: _expandAll,
          ),
          _headerIconBtn(
            icon: Icons.unfold_less,
            tooltip: 'طيّ الكل',
            onPressed: _collapseAll,
          ),
        ],
        const Spacer(),
        if (_accounts.isEmpty && !_loading && PilotSession.hasEntity)
          _primaryBtn(
            label: 'بذر الشجرة الافتراضية (SOCPA)',
            icon: Icons.auto_awesome,
            onPressed: _seeding ? null : _seedDefault,
            loading: _seeding,
          ),
        if (_accounts.isNotEmpty) ...[
          _headerIconBtn(
            icon: Icons.help_outline,
            tooltip: 'مساعدة (؟ أو Shift+/)',
            onPressed: _showHelp,
          ),
          _headerIconBtn(
            icon: Icons.history,
            tooltip: 'سجل التغييرات',
            onPressed: _showAuditDrawer,
          ),
          _buildMenuButton(
            tooltip: 'تصدير',
            icon: Icons.download,
            color: _ok,
            items: [
              _MenuOption('CSV', Icons.description, _exportCsv),
              _MenuOption('Excel', Icons.table_chart, _exportXlsx),
              _MenuOption('طباعة / PDF', Icons.picture_as_pdf, _exportPdf),
            ],
          ),
          _headerIconBtn(
            icon: Icons.refresh,
            tooltip: 'تحديث',
            onPressed: _load,
          ),
          _headerIconBtn(
            icon: Icons.upload_file,
            tooltip: 'استيراد Excel',
            onPressed: _importExcel,
            color: _ok,
          ),
          const SizedBox(width: 6),
          _primaryBtn(
            label: 'إضافة حساب',
            icon: Icons.add,
            onPressed: () => _addAccount(),
            shortcut: 'N',
          ),
        ],
      ]),
    );
  }

  Widget _buildMenuButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required List<_MenuOption> items,
  }) {
    return PopupMenuButton<int>(
      tooltip: tooltip,
      color: _navy2,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _bdr),
      ),
      offset: const Offset(0, 38),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      itemBuilder: (_) => [
        for (int i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(items[i].icon, size: 15, color: color),
              const SizedBox(width: 10),
              Text(items[i].label,
                  style: TextStyle(
                      color: _ts, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
      ],
      onSelected: (i) => items[i].onTap(),
    );
  }

  int _countActiveFilters() {
    int n = 0;
    if (_categoryFilter != 'all') n++;
    if (_typeFilter != 'all') n++;
    if (_normalFilter != 'all') n++;
    if (_showOnlyMissingVat) n++;
    if (_includeInactive) n++;
    if (_onlySystem) n++;
    if (_onlyControl) n++;
    return n;
  }

  void _clearAllFilters() {
    setState(() {
      _categoryFilter = 'all';
      _typeFilter = 'all';
      _normalFilter = 'all';
      _showOnlyMissingVat = false;
      _onlySystem = false;
      _onlyControl = false;
      if (_includeInactive) {
        _includeInactive = false;
        _load(); // re-load without archived
      }
    });
  }

  Widget _buildFilterButton(int activeCount) {
    final hasFilters = activeCount > 0;
    final bg = hasFilters ? _gold : _navy3;
    final fg = hasFilters ? core_theme.AC.bestOn(bg) : _ts;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _showFilterMenu,
        hoverColor: _gold.withValues(alpha: 0.12),
        splashColor: _gold.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: hasFilters ? _gold : _bdr.withValues(alpha: 0.9)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_list, color: fg, size: 15),
            const SizedBox(width: 6),
            Text('فلتر',
                style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (hasFilters) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$activeCount',
                  style: TextStyle(
                    color: fg,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: fg, size: 16),
          ]),
        ),
      ),
    );
  }

  Future<void> _showFilterMenu() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void apply(VoidCallback fn) {
            fn();
            setState(() {});
            setDialogState(() {});
          }

          // Build filter icon entries — each shows current state + popup on tap
          final entries = <_FilterIconEntry>[
            _FilterIconEntry(
              icon: Icons.category,
              label: 'الفئة',
              activeValue: _categoryFilter == 'all'
                  ? null
                  : _kCategories[_categoryFilter],
              activeColor: _categoryFilter == 'all'
                  ? null
                  : _kCategoryColors[_categoryFilter],
              build: (close) => _popupColumn([
                _popupItem('الكل', _categoryFilter == 'all', () {
                  apply(() => _categoryFilter = 'all');
                  close();
                }),
                ..._kCategories.entries.map((e) => _popupItem(
                      e.value,
                      _categoryFilter == e.key,
                      () {
                        apply(() => _categoryFilter = e.key);
                        close();
                      },
                      color: _kCategoryColors[e.key],
                    )),
              ]),
            ),
            _FilterIconEntry(
              icon: Icons.account_tree_outlined,
              label: 'النوع',
              activeValue: _typeFilter == 'all'
                  ? null
                  : (_typeFilter == 'header' ? 'رئيسي' : 'فرعي'),
              activeColor: _typeFilter == 'all'
                  ? null
                  : (_typeFilter == 'header' ? _warn : core_theme.AC.purple),
              build: (close) => _popupColumn([
                _popupItem('الكل', _typeFilter == 'all', () {
                  apply(() => _typeFilter = 'all');
                  close();
                }),
                _popupItem('رئيسي', _typeFilter == 'header', () {
                  apply(() => _typeFilter = 'header');
                  close();
                }, color: _warn),
                _popupItem('فرعي', _typeFilter == 'detail', () {
                  apply(() => _typeFilter = 'detail');
                  close();
                }, color: core_theme.AC.purple),
              ]),
            ),
            _FilterIconEntry(
              icon: Icons.swap_vert,
              label: 'الطبيعة',
              activeValue: _normalFilter == 'all'
                  ? null
                  : (_normalFilter == 'debit' ? 'مدين' : 'دائن'),
              activeColor: _normalFilter == 'all'
                  ? null
                  : (_normalFilter == 'debit' ? _ok : _err),
              build: (close) => _popupColumn([
                _popupItem('الكل', _normalFilter == 'all', () {
                  apply(() => _normalFilter = 'all');
                  close();
                }),
                _popupItem('مدين', _normalFilter == 'debit', () {
                  apply(() => _normalFilter = 'debit');
                  close();
                }, color: _ok),
                _popupItem('دائن', _normalFilter == 'credit', () {
                  apply(() => _normalFilter = 'credit');
                  close();
                }, color: _err),
              ]),
            ),
            _FilterIconEntry(
              icon: Icons.warning_amber,
              label: 'ZATCA',
              activeValue: _showOnlyMissingVat ? 'بدون ربط' : null,
              activeColor: _warn,
              build: (close) => _popupColumn([
                _popupItem('الكل', !_showOnlyMissingVat, () {
                  apply(() => _showOnlyMissingVat = false);
                  close();
                }),
                _popupItem('بدون ربط فقط', _showOnlyMissingVat, () {
                  apply(() => _showOnlyMissingVat = true);
                  close();
                }, color: _warn, icon: Icons.warning_amber),
              ]),
            ),
            _FilterIconEntry(
              icon: Icons.tune,
              label: 'الخصائص',
              activeValue: () {
                final parts = <String>[];
                if (_onlyControl) parts.add('تحكم');
                if (_onlySystem) parts.add('نظام');
                return parts.isEmpty ? null : parts.join(' • ');
              }(),
              activeColor: _onlyControl || _onlySystem ? _warn : null,
              build: (close) => _popupColumn([
                _popupCheckItem('حسابات التحكم فقط', _onlyControl,
                    (v) => apply(() => _onlyControl = v),
                    color: _warn, icon: Icons.lock),
                _popupCheckItem('حسابات النظام فقط', _onlySystem,
                    (v) => apply(() => _onlySystem = v),
                    color: core_theme.AC.purple, icon: Icons.shield),
              ]),
            ),
            _FilterIconEntry(
              icon: Icons.visibility,
              label: 'الحالة',
              activeValue: _includeInactive ? 'يشمل المؤرشف' : null,
              activeColor: _td,
              build: (close) => _popupColumn([
                _popupItem('مفعّلة فقط', !_includeInactive, () {
                  apply(() => _includeInactive = false);
                  _load();
                  close();
                }),
                _popupItem('يشمل المؤرشفة', _includeInactive, () {
                  apply(() => _includeInactive = true);
                  _load();
                  close();
                }, color: _td, icon: Icons.visibility_off),
              ]),
            ),
            _FilterIconEntry(
              icon: Icons.view_column,
              label: 'الأعمدة',
              activeValue:
                  '${_visibleColumns.where((c) => c != "select" && c != "actions").length}/${_kAllColumns.where((c) => c != "select" && c != "actions").length}',
              activeColor: _gold,
              build: (close) => _popupColumn([
                for (final c in _kAllColumns
                    .where((c) => c != 'select' && c != 'actions'))
                  _popupCheckItem(
                    _kColumnLabels[c] ?? c,
                    _visibleColumns.contains(c),
                    (v) => apply(() {
                      if (v) {
                        _visibleColumns.add(c);
                      } else {
                        _visibleColumns.remove(c);
                      }
                    }),
                    color: _gold,
                  ),
              ]),
            ),
          ];

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              alignment: Alignment.topCenter,
              insetPadding: const EdgeInsets.only(top: 130, left: 40, right: 40),
              backgroundColor: Colors.transparent,
              child: Container(
                width: 540,
                decoration: BoxDecoration(
                  color: _navy2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _bdr),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                      child: Row(children: [
                        Icon(Icons.filter_list, color: _gold, size: 18),
                        const SizedBox(width: 8),
                        Text('فلاتر',
                            style: TextStyle(
                                color: _tp,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (_countActiveFilters() > 0)
                          TextButton.icon(
                            onPressed: () => apply(() => _clearAllFilters()),
                            icon: Icon(Icons.clear_all, size: 14, color: _err),
                            label: Text('مسح الكل',
                                style:
                                    TextStyle(color: _err, fontSize: 12)),
                          ),
                        IconButton(
                          icon: Icon(Icons.close, color: _ts, size: 18),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ]),
                    ),
                    Divider(color: _bdr, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final e in entries) _filterIconButton(e),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterIconButton(_FilterIconEntry e) {
    final hasValue = e.activeValue != null;
    final c = e.activeColor ?? _gold;
    final bg = hasValue ? c.withValues(alpha: 0.15) : _navy3.withValues(alpha: 0.5);
    final fg = hasValue ? c : _ts;
    final borderC = hasValue ? c : _bdr;
    return Builder(builder: (ctx) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showFilterPopup(ctx, e),
          hoverColor: c.withValues(alpha: 0.10),
          splashColor: c.withValues(alpha: 0.18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: borderC.withValues(alpha: hasValue ? 0.7 : 0.4),
                  width: hasValue ? 1.5 : 1),
              boxShadow: hasValue
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.18),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: hasValue ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(e.icon, color: fg, size: 18),
                ),
                const SizedBox(height: 6),
                Text(e.label,
                    style: TextStyle(
                        color: _tp,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 14,
                  child: Text(
                    e.activeValue ?? '—',
                    style: TextStyle(
                        color: hasValue ? c : _td,
                        fontSize: 10,
                        fontWeight: hasValue
                            ? FontWeight.w700
                            : FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showFilterPopup(BuildContext anchorCtx, _FilterIconEntry e) {
    final box = anchorCtx.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(anchorCtx).context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(0, box.size.height + 4),
            ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<void>(
      context: anchorCtx,
      position: pos,
      color: _navy2,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _bdr),
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 220,
            child: e.build(() => Navigator.pop(anchorCtx)),
          ),
        ),
      ],
    );
  }

  Widget _popupColumn(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _popupItem(String label, bool selected, VoidCallback onTap,
      {Color? color, IconData? icon}) {
    final c = color ?? _gold;
    return InkWell(
      onTap: onTap,
      hoverColor: c.withValues(alpha: 0.10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: selected ? c : _ts, size: 14),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: selected ? c : _ts,
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500)),
          ),
          if (selected) Icon(Icons.check, color: c, size: 14),
        ]),
      ),
    );
  }

  Widget _popupCheckItem(String label, bool value, ValueChanged<bool> onChanged,
      {Color? color, IconData? icon}) {
    final c = color ?? _gold;
    return InkWell(
      onTap: () => onChanged(!value),
      hoverColor: c.withValues(alpha: 0.10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            color: value ? c : _ts,
            size: 16,
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, color: value ? c : _ts, size: 13),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: value ? c : _ts,
                    fontSize: 12.5,
                    fontWeight: value ? FontWeight.w700 : FontWeight.w500)),
          ),
        ]),
      ),
    );
  }

  // ── Active filters row ───────────────────────────────
  Widget _buildFilterBar() {
    final chips = <Widget>[];

    if (_categoryFilter != 'all') {
      final c = _kCategoryColors[_categoryFilter] ?? _gold;
      chips.add(_activeFilterChip(
        'الفئة: ${_kCategories[_categoryFilter]}',
        c,
        () => setState(() => _categoryFilter = 'all'),
      ));
    }
    if (_typeFilter != 'all') {
      chips.add(_activeFilterChip(
        'النوع: ${_typeFilter == 'header' ? 'رئيسي' : 'فرعي'}',
        _typeFilter == 'header' ? _warn : core_theme.AC.purple,
        () => setState(() => _typeFilter = 'all'),
      ));
    }
    if (_normalFilter != 'all') {
      chips.add(_activeFilterChip(
        'الطبيعة: ${_normalFilter == 'debit' ? 'مدين' : 'دائن'}',
        _normalFilter == 'debit' ? _ok : _err,
        () => setState(() => _normalFilter = 'all'),
      ));
    }
    if (_showOnlyMissingVat) {
      chips.add(_activeFilterChip(
        'بدون ربط ZATCA',
        _warn,
        () => setState(() => _showOnlyMissingVat = false),
      ));
    }
    if (_onlyControl) {
      chips.add(_activeFilterChip(
        'حسابات التحكم فقط',
        _warn,
        () => setState(() => _onlyControl = false),
      ));
    }
    if (_onlySystem) {
      chips.add(_activeFilterChip(
        'حسابات النظام فقط',
        core_theme.AC.purple,
        () => setState(() => _onlySystem = false),
      ));
    }
    if (_includeInactive) {
      chips.add(_activeFilterChip(
        'يشمل المؤرشف',
        _td,
        () {
          setState(() => _includeInactive = false);
          _load();
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 10),
      color: _navy2.withValues(alpha: 0.6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          _clearAllChip(),
        ],
      ),
    );
  }

  Widget _activeFilterChip(String label, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.close, color: color, size: 11),
          ),
        ),
      ]),
    );
  }

  Widget _clearAllChip() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _clearAllFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _err.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.clear_all, color: _err, size: 12),
          const SizedBox(width: 4),
          Text('مسح الكل',
              style: TextStyle(
                  color: _err,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: _ts, fontSize: 14)),
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
    }
    if (_accounts.isEmpty) {
      return _buildEmpty();
    }
    final rows = _flatten();
    return Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: _summaryCollapsed ? 36 : 260,
        decoration: BoxDecoration(
          color: _navy2,
          border: Border(
            left: BorderSide(color: _bdr, width: 1),
          ),
        ),
        child: _summaryCollapsed
            ? _buildCollapsedSummaryRail()
            : _buildSummarySidebar(),
      ),
      Expanded(child: _buildTree(rows)),
    ]);
  }

  Widget _buildCollapsedSummaryRail() {
    return Column(children: [
      const SizedBox(height: 14),
      Tooltip(
        message: 'إظهار الملخّص',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _toggleSummarySidebar,
            hoverColor: _gold.withValues(alpha: 0.12),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.keyboard_double_arrow_right,
                  color: _gold, size: 16),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Vertical "Summary" label
      RotatedBox(
        quarterTurns: 3,
        child: Text(
          'الملخّص',
          style: TextStyle(
            color: _td,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      const SizedBox(height: 14),
      // Compact total badge
      Tooltip(
        message: 'كل الحسابات: ${_accounts.length}',
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_accounts.length}',
            style: TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ]);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_tree_outlined,
            color: _gold.withValues(alpha: 0.4), size: 72),
        const SizedBox(height: 16),
        Text('لا توجد حسابات بعد',
            style: TextStyle(color: _tp, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
            'يمكنك بذر شجرة SOCPA الافتراضية (37 حساباً)\nأو إضافة حساب يدوياً',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ts, fontSize: 13, height: 1.6)),
        const SizedBox(height: 24),
        Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _tp,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _seeding ? null : _seedDefault,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('بذر الشجرة الافتراضية'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp,
                side: BorderSide(color: _bdr),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: () => _addAccount(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة حساب يدوي'),
          ),
        ]),
      ]),
    );
  }

  // ── Sidebar ─────────────────────────────────────────
  Widget _buildSummarySidebar() {
    final byCat = <String, int>{};
    int missingVat = 0;
    for (final a in _accounts) {
      byCat[a['category']] = (byCat[a['category']] ?? 0) + 1;
      final cat = a['category'];
      if ((cat == 'revenue' || cat == 'expense') &&
          (a['vat_code'] ?? '').toString().isEmpty) {
        missingVat++;
      }
    }
    final total = _accounts.length;
    final activeCount = _accounts.where((a) => a['is_active'] == true).length;
    final controlCount = _accounts.where((a) => a['is_control'] == true).length;
    final systemCount = _accounts.where((a) => a['is_system'] == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(children: [
          Expanded(child: _sectionLabel('ملخص الشجرة')),
          Tooltip(
            message: 'طيّ الملخّص',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _toggleSummarySidebar,
                hoverColor: _gold.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.keyboard_double_arrow_left,
                      color: _td, size: 14),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _summaryTileV2(
          label: 'كل الحسابات',
          count: total,
          icon: Icons.account_tree,
          color: _gold,
          onTap: () => setState(() => _categoryFilter = 'all'),
          selected: _categoryFilter == 'all',
        ),
        const SizedBox(height: 8),
        ..._kCategories.entries.map((e) {
          final count = byCat[e.key] ?? 0;
          final c = _kCategoryColors[e.key]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _summaryTileV2(
              label: e.value,
              count: count,
              total: total,
              icon: _iconForCategory(e.key),
              color: c,
              onTap: () => setState(() => _categoryFilter = e.key),
              selected: _categoryFilter == e.key,
            ),
          );
        }),
        const SizedBox(height: 14),
        _sectionLabel('الحالة'),
        const SizedBox(height: 10),
        _summaryTileV2(
          label: 'مفعّلة',
          count: activeCount,
          total: total,
          icon: Icons.check_circle,
          color: _ok,
        ),
        const SizedBox(height: 8),
        _summaryTileV2(
          label: 'تحكم',
          count: controlCount,
          total: total,
          icon: Icons.lock,
          color: _warn,
        ),
        const SizedBox(height: 8),
        _summaryTileV2(
          label: 'نظام',
          count: systemCount,
          total: total,
          icon: Icons.shield,
          color: core_theme.AC.purple,
        ),
        if (missingVat > 0) ...[
          const SizedBox(height: 14),
          _sectionLabel('تنبيهات ZATCA'),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              hoverColor: _warn.withValues(alpha: 0.12),
              splashColor: _warn.withValues(alpha: 0.2),
              onTap: () => setState(() => _showOnlyMissingVat = true),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _warn.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _warn.withValues(alpha: 0.45)),
                ),
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _warn.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.warning_amber, color: _warn, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$missingVat حساب بدون ربط',
                          style: TextStyle(
                              color: _warn,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'اضغط للتصفية وإصلاحها',
                          style: TextStyle(
                              color: _warn.withValues(alpha: 0.8),
                              fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_back_ios, color: _warn, size: 10),
                ]),
              ),
            ),
          ),
        ],
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

  /// Enhanced summary tile — typography hierarchy, progress bar, hover, selected glow.
  Widget _summaryTileV2({
    required String label,
    required int count,
    int? total,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    final pct = (total != null && total > 0) ? (count / total).clamp(0.0, 1.0) : null;
    final isEmpty = count == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.28),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: color.withValues(alpha: 0.10),
          splashColor: color.withValues(alpha: 0.15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.16 : 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? _gold
                    : color.withValues(alpha: isEmpty ? 0.15 : 0.28),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isEmpty ? 0.12 : 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: _ts,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: isEmpty ? _td : color,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ]),
                if (pct != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 4,
                          color: color.withValues(alpha: 0.12),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight,
                            widthFactor: pct,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${(pct * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: _td,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Key badge like `[N]` — styled keyboard shortcut chip.
  Widget _keyBadge(String key, {Color? fg}) {
    final c = fg ?? _tp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        key,
        style: TextStyle(
          color: c,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          height: 1.0,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Primary gradient button with optional keyboard shortcut badge.
  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    String? shortcut,
    bool loading = false,
    Color? bgColor,
  }) {
    final bg = bgColor ?? _gold;
    final fg = core_theme.AC.bestOn(bg);
    final disabled = onPressed == null || loading;
    return Opacity(
      opacity: disabled && !loading ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: disabled ? 0 : 2,
        shadowColor: bg.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: disabled ? null : onPressed,
          hoverColor: fg.withValues(alpha: 0.08),
          splashColor: fg.withValues(alpha: 0.16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg, Color.alphaBlend(fg.withValues(alpha: 0.08), bg)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  else
                    Icon(icon, color: fg, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                  if (shortcut != null) ...[
                    const SizedBox(width: 10),
                    _keyBadge(shortcut, fg: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Rounded icon button with hover tint.
  Widget _headerIconBtn({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    final c = color ?? _ts;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          hoverColor: c.withValues(alpha: 0.12),
          splashColor: c.withValues(alpha: 0.22),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: c, size: 18),
          ),
        ),
      ),
    );
  }

  /// Section label divider — "ملخص" style header.
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _td,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_bdr, _bdr.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tree table ───────────────────────────────────────
  double get _rowMinWidth {
    // ListView padding (40) + Container padding (28) + slack (32) = 100
    double w = 100;
    if (_visibleColumns.contains('select')) w += 36;
    if (_visibleColumns.contains('code')) w += 160;
    if (_visibleColumns.contains('name')) w += 360;
    if (_visibleColumns.contains('type')) w += 72;
    if (_visibleColumns.contains('normal')) w += 72;
    if (_visibleColumns.contains('vat')) w += 100;
    if (_visibleColumns.contains('debit')) w += 100;
    if (_visibleColumns.contains('credit')) w += 100;
    if (_visibleColumns.contains('net')) w += 120;
    if (_visibleColumns.contains('status')) w += 60;
    if (_visibleColumns.contains('actions')) w += 40;
    return w;
  }

  Widget _buildTree(List<_TreeRow> rows) {
    return LayoutBuilder(builder: (ctx, cons) {
      final tw = _rowMinWidth;
      final needsScroll = tw > cons.maxWidth;
      final effectiveWidth = needsScroll ? tw : cons.maxWidth;

      final body = SizedBox(
        width: effectiveWidth,
        height: cons.maxHeight,
        child: Column(children: [
          _buildTableHeader(rows),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, color: _td, size: 40),
                        const SizedBox(height: 8),
                        Text('لا توجد نتائج تطابق التصفية',
                            style: TextStyle(color: _ts, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _treeRow(rows[i]),
                  ),
          ),
        ]),
      );

      if (!needsScroll) return body;
      return Scrollbar(
        controller: _hScrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScrollCtrl,
          scrollDirection: Axis.horizontal,
          child: body,
        ),
      );
    });
  }

  Widget _buildTableHeader(List<_TreeRow> rows) {
    final allSelected = rows.isNotEmpty &&
        rows
            .where((r) => r.account['type'] != 'header')
            .every((r) => _selectedIds.contains(r.id));
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        if (_visibleColumns.contains('select'))
          SizedBox(
            width: 36,
            child: Checkbox(
              value: allSelected,
              tristate: true,
              onChanged: (_) {
                setState(() {
                  if (allSelected) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.clear();
                    for (final r in rows) {
                      if (r.account['type'] != 'header') _selectedIds.add(r.id);
                    }
                  }
                });
              },
              checkColor: _tp,
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (s) => s.contains(WidgetState.selected) ? _gold : _navy4),
            ),
          ),
        if (_visibleColumns.contains('code'))
          SizedBox(width: 160, child: Text('الرقم', style: _thStyle)),
        if (_visibleColumns.contains('name'))
          SizedBox(width: 360, child: Text('الاسم', style: _thStyle)),
        if (_visibleColumns.contains('type'))
          SizedBox(width: 72, child: Text('النوع', style: _thStyle)),
        if (_visibleColumns.contains('normal'))
          SizedBox(width: 72, child: Text('الطبيعة', style: _thStyle)),
        if (_visibleColumns.contains('vat'))
          SizedBox(width: 100, child: Text('ضريبة', style: _thStyle)),
        if (_visibleColumns.contains('debit'))
          SizedBox(width: 100, child: Text('مدين', style: _thStyle, textAlign: TextAlign.end)),
        if (_visibleColumns.contains('credit'))
          SizedBox(width: 100, child: Text('دائن', style: _thStyle, textAlign: TextAlign.end)),
        if (_visibleColumns.contains('net'))
          SizedBox(width: 120, child: Text('الرصيد', style: _thStyle, textAlign: TextAlign.end)),
        if (_visibleColumns.contains('status'))
          SizedBox(width: 60, child: Text('حالة', style: _thStyle)),
        if (_visibleColumns.contains('actions')) const SizedBox(width: 40),
      ]),
    );
  }

  Widget _treeRow(_TreeRow r) {
    final a = r.account;
    final id = r.id;
    final isHeader = a['type'] == 'header';
    final isActive = a['is_active'] == true;
    final isSystem = a['is_system'] == true;
    final isControl = a['is_control'] == true;
    final cat = a['category'] as String? ?? '';
    final catColor = _kCategoryColors[cat] ?? _gold;
    final bal = _balances[id];
    final debit = (bal?['debit'] ?? 0.0) as double;
    final credit = (bal?['credit'] ?? 0.0) as double;
    final net = (bal?['net'] ?? 0.0) as double;
    final selected = _selectedIds.contains(id);
    final focused = _focusedId == id;
    final editing = _editingId == id;
    final indent = r.depth * 20.0;
    final vatCode = (a['vat_code'] ?? '').toString();
    final needsVat = (cat == 'revenue' || cat == 'expense') && vatCode.isEmpty;

    Color bg;
    if (selected) {
      bg = _gold.withValues(alpha: 0.15);
    } else if (focused) {
      bg = _navy3.withValues(alpha: 0.7);
    } else if (isHeader) {
      bg = catColor.withValues(alpha: 0.05);
    } else {
      bg = _navy2.withValues(alpha: 0.4);
    }

    return GestureDetector(
      onSecondaryTapDown: (d) => _showContextMenu(d.globalPosition, a),
      child: Listener(
        onPointerDown: (event) {
          setState(() => _focusedId = id);
        },
        child: InkWell(
          onTap: () {
            if (r.hasChildren) {
              _toggleExpand(id);
            } else {
              setState(() => _focusedId = id);
            }
          },
          onDoubleTap: () => _startInlineEdit(id),
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? _gold
                    : (focused ? _gold.withValues(alpha: 0.5)
                        : (isActive ? _bdr : _err.withValues(alpha: 0.4))),
                width: selected || focused ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              if (_visibleColumns.contains('select'))
                SizedBox(
                  width: 36,
                  child: isHeader
                      ? const SizedBox.shrink()
                      : Checkbox(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                          checkColor: _tp,
                          fillColor: WidgetStateProperty.resolveWith<Color?>(
                              (s) => s.contains(WidgetState.selected) ? _gold : _navy4),
                        ),
                ),
              if (_visibleColumns.contains('code'))
                SizedBox(
                  width: 160,
                  child: Padding(
                    padding: EdgeInsets.only(right: indent),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 20,
                        child: r.hasChildren
                            ? InkWell(
                                onTap: () => _toggleExpand(id),
                                borderRadius: BorderRadius.circular(4),
                                child: Icon(
                                  r.isExpanded
                                      ? Icons.expand_more
                                      : Icons.chevron_left,
                                  color: _ts,
                                  size: 18,
                                ),
                              )
                            : Icon(Icons.circle, size: 4, color: _td.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(a['code'] ?? '',
                            style: TextStyle(
                                color: isHeader ? catColor : _tp,
                                fontSize: 13,
                                fontWeight:
                                    isHeader ? FontWeight.w800 : FontWeight.w600,
                                fontFamily: 'monospace')),
                      ),
                    ]),
                  ),
                ),
              if (_visibleColumns.contains('name'))
                SizedBox(
                  width: 360,
                  child: editing
                      ? TextField(
                          controller: _editCtrl,
                          focusNode: _editFocus,
                          style: TextStyle(color: _tp, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: _navy3,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: _gold, width: 1.5)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: _gold, width: 1.5)),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.check, color: _ok, size: 16),
                                  onPressed: _commitInlineEdit,
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(minWidth: 26, minHeight: 26),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: _err, size: 16),
                                  onPressed: () => setState(() => _editingId = null),
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(minWidth: 26, minHeight: 26),
                                ),
                              ],
                            ),
                          ),
                          onSubmitted: (_) => _commitInlineEdit(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['name_ar'] ?? '',
                              style: TextStyle(
                                  color: isHeader ? catColor : _tp,
                                  fontSize: 13,
                                  fontWeight: isHeader
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  decoration:
                                      isActive ? null : TextDecoration.lineThrough),
                            ),
                            if ((a['name_en'] ?? '').toString().isNotEmpty)
                              Text(a['name_en'],
                                  style: TextStyle(color: _td, fontSize: 10)),
                          ],
                        ),
                ),
              if (_visibleColumns.contains('type'))
                SizedBox(
                  width: 72,
                  child: _miniBadge(isHeader ? 'رئيسي' : 'فرعي',
                      isHeader ? _warn : core_theme.AC.purple),
                ),
              if (_visibleColumns.contains('normal'))
                SizedBox(
                  width: 72,
                  child: _miniBadge(a['normal_balance'] == 'debit' ? 'مدين' : 'دائن',
                      a['normal_balance'] == 'debit' ? _ok : _err),
                ),
              if (_visibleColumns.contains('vat'))
                SizedBox(
                  width: 100,
                  child: _vatCell(vatCode, needsVat),
                ),
              if (_visibleColumns.contains('debit'))
                SizedBox(
                  width: 100,
                  child: _balanceCell(debit, _tp),
                ),
              if (_visibleColumns.contains('credit'))
                SizedBox(
                  width: 100,
                  child: _balanceCell(credit, _tp),
                ),
              if (_visibleColumns.contains('net'))
                SizedBox(
                  width: 120,
                  child: InkWell(
                    onTap: () => _showAccountLedger(a),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(_fmt(net.abs()),
                              style: TextStyle(
                                  color:
                                      net == 0 ? _td : (net > 0 ? _ok : _err),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  decoration: net != 0 ? TextDecoration.underline : null,
                                  decorationColor: net > 0 ? _ok : _err)),
                          if (net != 0) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new,
                                size: 10, color: net > 0 ? _ok : _err),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              if (_visibleColumns.contains('status'))
                SizedBox(
                  width: 60,
                  child: Row(children: [
                    if (isSystem) ...[
                      Tooltip(
                        message: 'حساب نظام',
                        child: Icon(Icons.shield, color: core_theme.AC.purple, size: 12),
                      ),
                      const SizedBox(width: 3),
                    ],
                    if (isControl) ...[
                      Tooltip(
                        message: 'حساب تحكم',
                        child: Icon(Icons.lock, color: _warn, size: 12),
                      ),
                      const SizedBox(width: 3),
                    ],
                    if (!isActive)
                      Tooltip(
                        message: 'مؤرشف',
                        child: Icon(Icons.visibility_off, color: _err, size: 12),
                      ),
                  ]),
                ),
              if (_visibleColumns.contains('actions'))
                SizedBox(
                  width: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.more_vert, color: _ts, size: 16),
                    onPressed: () => _showContextMenuAtButton(a),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _balanceCell(double v, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(_fmt(v),
          style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
          textAlign: TextAlign.end),
    );
  }

  Widget _vatCell(String code, bool missingWarning) {
    if (code.isEmpty) {
      if (missingWarning) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _warn.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _warn.withValues(alpha: 0.6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber, color: _warn, size: 11),
            const SizedBox(width: 3),
            Text('غير مربوط',
                style: TextStyle(color: _warn, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        );
      }
      return Text('—', style: TextStyle(color: _td, fontSize: 11));
    }
    Color c;
    switch (code) {
      case 'STANDARD_15':
        c = _ok;
        break;
      case 'ZERO_RATED':
        c = core_theme.AC.info;
        break;
      case 'EXEMPT':
        c = _warn;
        break;
      default:
        c = _td;
    }
    return _miniBadge(_kVatCodes[code] ?? code, c);
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
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intPart.${parts[1]}';
  }

  // ══════════════════════════════════════════════════════════════════════
  // BULK ACTION BAR
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildBulkBar() {
    final count = _selectedIds.length;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: _navy3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navy3, _navy2],
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count مختار',
                style: TextStyle(
                    color: _tp, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          _bulkBtn(Icons.check_circle, 'تفعيل', _ok, _bulkActivate),
          const SizedBox(width: 6),
          _bulkBtn(Icons.archive, 'أرشفة', _err, _bulkArchive),
          const SizedBox(width: 6),
          _bulkBtn(Icons.file_download, 'تصدير', core_theme.AC.info, () {
            // export only selected
            final rows = _selectedIds
                .map((id) => _accById[id])
                .where((a) => a != null)
                .cast<Map<String, dynamic>>()
                .toList();
            final data = rows.map((a) {
              final bal = _balances[a['id']] ?? {};
              return <dynamic>[
                a['code'] ?? '',
                a['name_ar'] ?? '',
                a['name_en'] ?? '',
                _kCategories[a['category']] ?? '',
                a['type'] == 'header' ? 'رئيسي' : 'فرعي',
                a['normal_balance'] == 'debit' ? 'مدين' : 'دائن',
                a['vat_code'] ?? '',
                a['currency'] ?? '',
                (bal['debit'] ?? 0.0).toDouble(),
                (bal['credit'] ?? 0.0).toDouble(),
                (bal['net'] ?? 0.0).toDouble(),
                a['is_active'] == true ? 'مفعّل' : 'مؤرشف',
              ];
            }).toList();
            exportXlsx(
              headers: _exportHeaders,
              rows: data,
              filename: 'selected_accounts_${DateTime.now().millisecondsSinceEpoch}',
              sheetName: 'Selected',
              title: 'حسابات مختارة (${rows.length})',
            );
          }),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'إلغاء التحديد',
            icon: Icon(Icons.close, color: _ts, size: 18),
            onPressed: () => setState(() => _selectedIds.clear()),
          ),
        ]),
      ),
    );
  }

  Widget _bulkBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTEXT MENU
  // ══════════════════════════════════════════════════════════════════════

  void _showContextMenu(Offset pos, Map<String, dynamic> a) {
    final isActive = a['is_active'] == true;
    showMenu<String>(
      context: context,
      color: _navy2,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        _menuItem('edit', 'تعديل الاسم (E)', Icons.edit, _ts),
        _menuItem('editCode', 'تعديل الكود (C)', Icons.tag, _ts,
            disabled: a['is_system'] == true),
        _menuItem('details', 'عرض التفاصيل', Icons.info_outline, _ts),
        _menuItem('ledger', 'دفتر الأستاذ', Icons.receipt_long, core_theme.AC.info),
        _menuItem('addChild', 'إضافة حساب فرعي', Icons.add_circle, _ok),
        _menuItem('duplicate', 'تكرار', Icons.content_copy, core_theme.AC.purple),
        const PopupMenuDivider(),
        _menuItem(
            isActive ? 'archive' : 'activate',
            isActive ? 'أرشفة' : 'تفعيل',
            isActive ? Icons.archive : Icons.check_circle,
            isActive ? _err : _ok),
        _menuItem('history', 'سجل التغييرات', Icons.history, _td),
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 'edit':
          _startInlineEdit(a['id'] as String);
          break;
        case 'editCode':
          _editAccountCode(a);
          break;
        case 'details':
          _showAccountDetail(a);
          break;
        case 'ledger':
          _showAccountLedger(a);
          break;
        case 'addChild':
          _addAccount(parentId: a['id'] as String);
          break;
        case 'duplicate':
          _duplicateAccount(a);
          break;
        case 'archive':
          _archiveAccount(a);
          break;
        case 'activate':
          _archiveAccount(a, activate: true);
          break;
        case 'history':
          _showAuditDrawer(account: a);
          break;
      }
    });
  }

  Future<void> _editAccountCode(Map<String, dynamic> a) async {
    if (a['is_system'] == true) {
      _snack('لا يمكن تعديل كود حساب النظام', _warn);
      return;
    }
    final ctrl = TextEditingController(text: (a['code'] ?? '').toString());
    final focus = FocusNode();
    String? errorMsg;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _navy2,
            title: Row(children: [
              Icon(Icons.tag, color: _gold, size: 18),
              const SizedBox(width: 8),
              Text('تعديل كود الحساب',
                  style: TextStyle(color: _tp, fontSize: 15)),
            ]),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الحساب: ${a['name_ar'] ?? ''}',
                      style: TextStyle(color: _ts, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('الكود الحالي: ${a['code'] ?? ''}',
                      style: TextStyle(
                          color: _td,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 14),
                  Text('الكود الجديد *',
                      style: TextStyle(color: _td, fontSize: 11)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: ctrl,
                    focusNode: focus,
                    autofocus: true,
                    style: TextStyle(
                        color: _tp, fontSize: 14, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'مثال: 1115',
                      hintStyle: TextStyle(color: _td),
                      isDense: true,
                      filled: true,
                      fillColor: _navy3,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: _bdr)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: _bdr)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _err.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _err.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: _err, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(errorMsg!,
                              style: TextStyle(color: _err, fontSize: 11)),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('إلغاء', style: TextStyle(color: _ts)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () {
                  final newCode = ctrl.text.trim();
                  if (newCode.isEmpty) {
                    setLocal(() => errorMsg = 'الكود مطلوب');
                    return;
                  }
                  if (newCode == (a['code'] ?? '').toString()) {
                    Navigator.pop(ctx, null);
                    return;
                  }
                  final clash = _accounts.any((x) =>
                      x['id'] != a['id'] &&
                      (x['code'] ?? '').toString() == newCode);
                  if (clash) {
                    setLocal(() =>
                        errorMsg = 'الكود "$newCode" مستخدم بالفعل في حساب آخر');
                    return;
                  }
                  Navigator.pop(ctx, newCode);
                },
                child: Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    focus.dispose();
    if (result == null || result.isEmpty) return;
    final r = await _client.updateAccount(a['id'] as String, {'code': result});
    if (!mounted) return;
    if (r.success) {
      setState(() => _accById[a['id']]?['code'] = result);
      _snack('تم تحديث الكود إلى "$result" ✓', _ok);
      _load();
    } else {
      _snack(r.error ?? 'فشل تحديث الكود', _err);
    }
  }

  void _showContextMenuAtButton(Map<String, dynamic> a) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero) +
        Offset(box.size.width - 100, box.size.height / 2);
    _showContextMenu(pos, a);
  }

  PopupMenuItem<String> _menuItem(String v, String label, IconData icon, Color color,
      {bool disabled = false}) {
    final iconColor = disabled ? _td : color;
    final textColor = disabled ? _td : _ts;
    return PopupMenuItem<String>(
      value: v,
      enabled: !disabled,
      child: Row(children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: textColor, fontSize: 13)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════════════════════

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
                  style: TextStyle(color: _tp, fontSize: 15)),
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
                _kv('الطبيعة',
                    a['normal_balance'] == 'debit' ? 'مدين' : 'دائن'),
                _kv('المستوى', '${a['level']}'),
                _kv('العملة', a['currency'] ?? '—'),
                _kv('كود ZATCA',
                    _kVatCodes[a['vat_code']] ?? (a['vat_code'] ?? '—')),
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
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAccountLedger(a);
              },
              icon: Icon(Icons.receipt_long, size: 16, color: core_theme.AC.info),
              label: Text('دفتر الأستاذ',
                  style: TextStyle(color: core_theme.AC.info)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: _tp),
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
          child: Text(k, style: TextStyle(color: _td, fontSize: 12)),
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

  Future<void> _showAccountLedger(Map<String, dynamic> a) async {
    await showDialog(
      context: context,
      builder: (_) => _LedgerDialog(account: a),
    );
  }

  void _showAuditDrawer({Map<String, dynamic>? account}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _navy2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scroll) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.history, color: _gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                      account == null
                          ? 'سجل التغييرات — كامل الشجرة'
                          : 'سجل: ${account['code']} ${account['name_ar']}',
                      style: TextStyle(
                          color: _tp, fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: _ts),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: _AuditTimeline(
                    scrollController: scroll,
                    account: account,
                    accounts: _accounts,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Row(children: [
            Icon(Icons.keyboard, color: _gold, size: 20),
            const SizedBox(width: 8),
            Text('اختصارات لوحة المفاتيح',
                style: TextStyle(color: _tp, fontSize: 15)),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _shortcut('/', 'تركيز حقل البحث'),
                _shortcut('N', 'حساب جديد'),
                _shortcut('E', 'تعديل الاسم (للصف المُركَّز)'),
                _shortcut('Space', 'توسّع/طيّ (للصف المُركَّز)'),
                _shortcut('Esc', 'إلغاء التحرير / البحث / التحديد'),
                _shortcut('↑ / ↓', 'تنقل بين الصفوف'),
                _shortcut('← / →', 'طيّ / توسّع (RTL)'),
                _shortcut('Ctrl+A', 'تحديد جميع الحسابات الفرعية المرئية'),
                _shortcut('Delete', 'أرشفة المُحدَّد'),
                _shortcut('؟ أو Shift+/', 'عرض هذا الدليل'),
                _shortcut('Double-click', 'تعديل الاسم inline'),
                _shortcut('Right-click', 'قائمة السياق'),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: _tp),
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcut(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _bdr),
          ),
          child: Text(key,
              style: TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(desc, style: TextStyle(color: _ts, fontSize: 12))),
      ]),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      content: Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════
// HELPER CLASSES
// ══════════════════════════════════════════════════════════════════════

class _TreeRow {
  final String id;
  final Map<String, dynamic> account;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  _TreeRow({
    required this.id,
    required this.account,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
  });
}

class _MenuOption {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _MenuOption(this.label, this.icon, this.onTap);
}

/// Entry describing one filter icon button + its popup builder.
class _FilterIconEntry {
  final IconData icon;
  final String label;
  final String? activeValue;
  final Color? activeColor;
  final Widget Function(VoidCallback close) build;
  _FilterIconEntry({
    required this.icon,
    required this.label,
    required this.activeValue,
    required this.activeColor,
    required this.build,
  });
}

TextStyle get _thStyle => TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════
// LEDGER DIALOG (Drill-down)
// ══════════════════════════════════════════════════════════════════════

class _LedgerDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  const _LedgerDialog({required this.account});
  @override
  State<_LedgerDialog> createState() => _LedgerDialogState();
}

class _LedgerDialogState extends State<_LedgerDialog> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _loading = true;
  double _opening = 0;
  double _closing = 0;

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
    final r = await pilotClient.accountLedger(widget.account['id']);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      final data = r.data as Map;
      final rows = data['entries'] ?? data['lines'] ?? data['rows'];
      setState(() {
        _rows = rows is List
            ? List<Map<String, dynamic>>.from(rows)
            : <Map<String, dynamic>>[];
        _opening = asDouble(data['opening_balance']);
        _closing = asDouble(data['closing_balance']);
        _loading = false;
      });
    } else {
      setState(() {
        _error = r.error ?? 'فشل تحميل دفتر الأستاذ';
        _loading = false;
      });
    }
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: _navy2,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: 900,
          height: 600,
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Icon(Icons.receipt_long, color: core_theme.AC.info, size: 22),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(a['code'] ?? '',
                    style: TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'دفتر الأستاذ — ${a['name_ar']}',
                  style: TextStyle(
                      color: _tp, fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: _ts),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _statCard('الرصيد الافتتاحي', _opening, core_theme.AC.info),
              const SizedBox(width: 10),
              _statCard('الرصيد الختامي', _closing, _opening < _closing ? _ok : _warn),
              const SizedBox(width: 10),
              _statCard('عدد الحركات', (_rows?.length ?? 0).toDouble(), _gold,
                  isCount: true),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _gold))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: _err, size: 40),
                              const SizedBox(height: 10),
                              Text(_error!, style: TextStyle(color: _ts)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: _load,
                                  child: const Text('إعادة المحاولة')),
                            ],
                          ),
                        )
                      : _rows == null || _rows!.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox, color: _td, size: 40),
                                  const SizedBox(height: 10),
                                  Text('لا توجد حركات على هذا الحساب بعد',
                                      style: TextStyle(color: _ts, fontSize: 13)),
                                ],
                              ),
                            )
                          : _buildTable(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String label, double value, Color color, {bool isCount = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _td, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              isCount ? value.toInt().toString() : _fmt(value),
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _navy4,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(children: [
            SizedBox(width: 100, child: Text('التاريخ', style: _thStyle)),
            SizedBox(width: 100, child: Text('القيد', style: _thStyle)),
            Expanded(child: Text('الوصف', style: _thStyle)),
            SizedBox(
                width: 110, child: Text('مدين', style: _thStyle, textAlign: TextAlign.end)),
            SizedBox(
                width: 110, child: Text('دائن', style: _thStyle, textAlign: TextAlign.end)),
            SizedBox(
                width: 120,
                child: Text('الرصيد الجاري', style: _thStyle, textAlign: TextAlign.end)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _rows!.length,
            itemBuilder: (_, i) {
              final r = _rows![i];
              final debit = asDouble(r['debit']);
              final credit = asDouble(r['credit']);
              final running = asDouble(r['running_balance'] ?? r['balance'] ?? 0);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _bdr.withValues(alpha: 0.3))),
                ),
                child: Row(children: [
                  SizedBox(
                      width: 100,
                      child: Text(
                          (r['entry_date'] ?? r['date'] ?? '').toString().split('T').first,
                          style: TextStyle(color: _ts, fontSize: 11))),
                  SizedBox(
                      width: 100,
                      child: Text(
                          (r['entry_number'] ?? r['reference'] ?? '—').toString(),
                          style: TextStyle(
                              color: _gold,
                              fontSize: 11,
                              fontFamily: 'monospace'))),
                  Expanded(
                    child: Text(
                      (r['description'] ?? r['memo'] ?? '—').toString(),
                      style: TextStyle(color: _tp, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                      width: 110,
                      child: Text(_fmt(debit),
                          style: TextStyle(
                              color: debit > 0 ? _ok : _td,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                          textAlign: TextAlign.end)),
                  SizedBox(
                      width: 110,
                      child: Text(_fmt(credit),
                          style: TextStyle(
                              color: credit > 0 ? _err : _td,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                          textAlign: TextAlign.end)),
                  SizedBox(
                      width: 120,
                      child: Text(_fmt(running.abs()),
                          style: TextStyle(
                              color: running >= 0 ? _ok : _err,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace'),
                          textAlign: TextAlign.end)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// AUDIT TIMELINE (Drawer)
// ══════════════════════════════════════════════════════════════════════

class _AuditTimeline extends StatelessWidget {
  final ScrollController scrollController;
  final Map<String, dynamic>? account;
  final List<Map<String, dynamic>> accounts;
  const _AuditTimeline(
      {required this.scrollController, required this.account, required this.accounts});

  @override
  Widget build(BuildContext context) {
    // نستخدم createdAt / updatedAt من الحسابات كسجل مبسّط.
    // (backend يدعم SettingsChangeLog للإعدادات، لكن للحسابات نعرض أحدث التغييرات)
    final source = account != null ? [account!] : accounts;
    final events = <_AuditEvent>[];
    for (final a in source) {
      final created = DateTime.tryParse((a['created_at'] ?? '').toString());
      final updated = DateTime.tryParse((a['updated_at'] ?? '').toString());
      if (created != null) {
        events.add(_AuditEvent(
          time: created,
          icon: Icons.add_circle,
          color: _ok,
          title: 'أُنشئ الحساب',
          subtitle: '${a['code']} — ${a['name_ar']}',
        ));
      }
      if (updated != null &&
          created != null &&
          updated.difference(created).inSeconds.abs() > 5) {
        events.add(_AuditEvent(
          time: updated,
          icon: Icons.edit,
          color: core_theme.AC.info,
          title: 'عُدِّل الحساب',
          subtitle: '${a['code']} — ${a['name_ar']}',
        ));
      }
      if (a['is_active'] == false) {
        events.add(_AuditEvent(
          time: updated ?? created ?? DateTime.now(),
          icon: Icons.archive,
          color: _err,
          title: 'تمت الأرشفة',
          subtitle: '${a['code']} — ${a['name_ar']}',
        ));
      }
    }
    events.sort((a, b) => b.time.compareTo(a.time));

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, color: _td, size: 40),
            const SizedBox(height: 10),
            Text('لا توجد تغييرات بعد',
                style: TextStyle(color: _ts, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = events[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _navy3.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: e.color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: e.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(e.icon, color: e.color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: TextStyle(
                          color: _tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(e.subtitle, style: TextStyle(color: _ts, fontSize: 11)),
                ],
              ),
            ),
            Text(
              _relativeTime(e.time),
              style: TextStyle(color: _td, fontSize: 11),
            ),
          ]),
        );
      },
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return t.toIso8601String().substring(0, 10);
  }
}

class _AuditEvent {
  final DateTime time;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  _AuditEvent({
    required this.time,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

// ══════════════════════════════════════════════════════════════════════
// ADD ACCOUNT DIALOG (with smart code suggestion + VAT)
// ══════════════════════════════════════════════════════════════════════

class _AddAccountDialog extends StatefulWidget {
  final String entityId;
  final List<Map<String, dynamic>> allAccounts;
  final String? initialParentId;
  const _AddAccountDialog({
    required this.entityId,
    required this.allAccounts,
    this.initialParentId,
  });
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
  String? _vatCode;
  bool _isControl = false;
  bool _requireCostCenter = false;
  bool _requireProfitCenter = false;
  bool _loading = false;
  String? _error;
  String _suggestedCode = '';

  @override
  void initState() {
    super.initState();
    _parentId = widget.initialParentId;
    if (_parentId != null) {
      final p = widget.allAccounts.firstWhere(
          (a) => a['id'] == _parentId,
          orElse: () => {});
      if (p.isNotEmpty) {
        _category = p['category'] ?? 'asset';
      }
    }
    _normalBalance = _defaultNormalFor(_category);
    _recomputeSuggestion();
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
    return (c == 'asset' || c == 'expense') ? 'debit' : 'credit';
  }

  void _recomputeSuggestion() {
    // اقترح code بناءً على parent + children
    if (_parentId == null) {
      // جذور — base codes: asset=1000, liability=2000, equity=3000, revenue=4000, expense=5000
      final baseCodes = {
        'asset': 1000,
        'liability': 2000,
        'equity': 3000,
        'revenue': 4000,
        'expense': 5000,
      };
      final base = baseCodes[_category] ?? 1000;
      final existing = widget.allAccounts
          .where((a) =>
              a['parent_account_id'] == null && a['category'] == _category)
          .toList();
      if (existing.isEmpty) {
        _suggestedCode = '$base';
      } else {
        int maxCode = base;
        for (final a in existing) {
          final c = int.tryParse((a['code'] ?? '').toString()) ?? 0;
          if (c > maxCode) maxCode = c;
        }
        _suggestedCode = '${maxCode + 100}';
      }
    } else {
      final parent = widget.allAccounts.firstWhere(
          (a) => a['id'] == _parentId,
          orElse: () => {});
      final parentCode = (parent['code'] ?? '').toString();
      final children = widget.allAccounts
          .where((a) => a['parent_account_id'] == _parentId)
          .toList();
      if (children.isEmpty) {
        final pc = int.tryParse(parentCode);
        _suggestedCode = pc != null ? '${pc + 10}' : '${parentCode}1';
      } else {
        int maxCode = 0;
        for (final c in children) {
          final cc = int.tryParse((c['code'] ?? '').toString()) ?? 0;
          if (cc > maxCode) maxCode = cc;
        }
        _suggestedCode = '${maxCode + 10}';
      }
    }
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
      if (_vatCode != null) 'vat_code': _vatCode,
      'is_control': _isControl,
      'require_cost_center': _requireCostCenter,
      'require_profit_center': _requireProfitCenter,
    };
    final r = await pilotClient.createAccount(widget.entityId, body);
    setState(() => _loading = false);
    if (r.success) {
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء الحساب ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.allAccounts
        .where((a) => a['category'] == _category && a['type'] == 'header')
        .toList()
      ..sort((a, b) => (a['code'] ?? '').toString().compareTo((b['code'] ?? '').toString()));
    final isRevOrExp = _category == 'revenue' || _category == 'expense';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _bdr),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.add_circle_outline, color: _gold, size: 18),
          ),
          const SizedBox(width: 10),
          Text('إضافة حساب جديد',
              style: TextStyle(
                  color: _tp, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('الرقم *',
                              style: TextStyle(
                                  color: _td,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                          const Spacer(),
                          if (_suggestedCode.isNotEmpty &&
                              _codeCtrl.text.isEmpty)
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () {
                                  _codeCtrl.text = _suggestedCode;
                                  setState(() {});
                                },
                                hoverColor: _gold.withValues(alpha: 0.18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _gold.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: _gold.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          color: _gold, size: 11),
                                      const SizedBox(width: 4),
                                      Text('اقتراح: $_suggestedCode',
                                          style: TextStyle(
                                              color: _gold,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _codeCtrl,
                          style: TextStyle(
                              color: _tp,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: _suggestedCode.isNotEmpty
                                ? _suggestedCode
                                : 'مثال: 1115',
                            hintStyle:
                                TextStyle(color: _td.withValues(alpha: 0.7)),
                            isDense: true,
                            filled: true,
                            fillColor: _navy3,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: _bdr)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: _bdr.withValues(alpha: 0.7))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: _gold, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 5, child: _field('الاسم العربي *', _nameArCtrl)),
                ]),
                const SizedBox(height: 10),
                _field('الاسم الإنجليزي', _nameEnCtrl),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _dropdown<String>(
                      'الفئة',
                      _category,
                      _kCategories.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      (v) => setState(() {
                        _category = v!;
                        _normalBalance = _defaultNormalFor(v);
                        _parentId = null;
                        _recomputeSuggestion();
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _field('التصنيف الفرعي', _subcategoryCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _dropdown<String>(
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
                    child: _dropdown<String>(
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
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: _dropdown<String?>(
                      'الحساب الأب (اختياري)',
                      _parentId,
                      [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('— جذر —')),
                        ...parents.map((p) => DropdownMenuItem<String?>(
                              value: p['id'] as String,
                              child: Text('${p['code']} — ${p['name_ar']}',
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      (v) => setState(() {
                        _parentId = v;
                        _recomputeSuggestion();
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown<String>(
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
                if (isRevOrExp) ...[
                  const SizedBox(height: 10),
                  _dropdown<String?>(
                    'كود ضريبة ZATCA (مُوصَى به للإيرادات/المصروفات)',
                    _vatCode,
                    [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('— غير مربوط —')),
                      ..._kVatCodes.entries.map((e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text('${e.value} (${e.key})'),
                          )),
                    ],
                    (v) => setState(() => _vatCode = v),
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  _checkTile('حساب تحكم', _isControl,
                      (v) => setState(() => _isControl = v)),
                  _checkTile('مركز تكلفة مطلوب', _requireCostCenter,
                      (v) => setState(() => _requireCostCenter = v)),
                  _checkTile('مركز ربحية مطلوب', _requireProfitCenter,
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
                      Icon(Icons.error_outline, color: _err, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: _err, fontSize: 12)),
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
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              foregroundColor: _ts,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            elevation: _loading ? 0 : 2,
            shadowColor: _gold.withValues(alpha: 0.5),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _loading ? null : _submit,
              hoverColor:
                  core_theme.AC.bestOn(_gold).withValues(alpha: 0.08),
              splashColor:
                  core_theme.AC.bestOn(_gold).withValues(alpha: 0.16),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _gold,
                      Color.alphaBlend(
                          core_theme.AC.bestOn(_gold).withValues(alpha: 0.08),
                          _gold),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 11),
                  child: _loading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: core_theme.AC.bestOn(_gold)))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check,
                                color: core_theme.AC.bestOn(_gold),
                                size: 16),
                            const SizedBox(width: 6),
                            Text('إنشاء',
                                style: TextStyle(
                                    color: core_theme.AC.bestOn(_gold),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
            ),
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
        Text(label,
            style: TextStyle(
                color: _td,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          style: TextStyle(
              color: _tp,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _td.withValues(alpha: 0.7)),
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _bdr.withValues(alpha: 0.7))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _gold, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
        Text(label,
            style: TextStyle(
                color: _td,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr.withValues(alpha: 0.7)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _navy2,
              style: TextStyle(
                  color: _tp, fontSize: 13, fontWeight: FontWeight.w600),
              icon: Icon(Icons.arrow_drop_down, color: _gold),
              items: items,
              onChanged: onChanged,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          hoverColor: _gold.withValues(alpha: 0.10),
          splashColor: _gold.withValues(alpha: 0.18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: value
                  ? _gold.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: value
                      ? _gold.withValues(alpha: 0.5)
                      : _bdr.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                color: value ? _gold : _td,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: value ? _gold : _ts,
                        fontSize: 11,
                        fontWeight:
                            value ? FontWeight.w700 : FontWeight.w500)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
