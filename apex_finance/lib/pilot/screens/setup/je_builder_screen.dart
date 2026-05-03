/// Journal Entries — بناء وإدارة قيود اليومية.
///
/// مستقلة — تعتمد على PilotSession.entityId.
///
/// الميزات:
///   • قائمة القيود (Draft/Submitted/Approved/Posted/Reversed)
///   • إنشاء قيد جديد (multi-line debit/credit — يجب أن يتساوى المجموع)
///   • ترحيل القيد (post) — يُسجَّل في GL Postings
///   • عكس القيد (reverse) — يُنشِئ قيداً مقابلاً
///   • عرض تفاصيل القيد مع السطور
library;

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart' as core_theme;
import '../../../widgets/apex_list_toolbar.dart';

import '../../api/pilot_client.dart';
import '../../num_utils.dart';
import '../../services/entity_resolver.dart';
import '../../session.dart';
import '../../widgets/attachments_panel.dart';

// Wave R — CSV download helpers (dart:html wrappers)
dynamic _makeBlob(List<int> bytes, String type) =>
    html.Blob([bytes], type);
String _createObjectUrl(dynamic blob) =>
    html.Url.createObjectUrlFromBlob(blob as html.Blob);
void _downloadUrl(String url, String filename) {
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
}
void _revokeObjectUrl(String url) => html.Url.revokeObjectUrl(url);

// All colors resolved as getters so the screen reacts to theme changes
// (light ↔ dark) at build-time. Previously `_tp`/`_blue`/`_indigo` were
// captured as `final` constants which kept a stale color when the user
// switched modes — causing white text on a light background.
Color get _gold => core_theme.AC.gold;
Color get _navy => core_theme.AC.navy;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
Color get _tp => core_theme.AC.tp;       // primary text — dark on light, light on dark
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;
Color get _warn => core_theme.AC.warn;
Color get _blue => core_theme.AC.info;
Color get _indigo => core_theme.AC.purple;

Map<String, Map<String, dynamic>> get _kStatuses => <String, Map<String, dynamic>>{
  'draft': {'ar': 'مسودّة', 'color': _td},
  'submitted': {'ar': 'مُقدَّم', 'color': _warn},
  'approved': {'ar': 'معتمد', 'color': _blue},
  'posted': {'ar': 'مُرحَّل', 'color': _ok},
  'reversed': {'ar': 'معكوس', 'color': _err},
  'cancelled': {'ar': 'ملغى', 'color': _td},
};

const _kKinds = <String, String>{
  'manual': 'يدوي',
  'auto_pos': 'تلقائي (POS)',
  'auto_po': 'تلقائي (مشتريات)',
  'auto_payroll': 'تلقائي (رواتب)',
  'auto_depreciation': 'تلقائي (إهلاك)',
  'auto_fx_reval': 'تلقائي (تقييم عملات)',
  'adjusting': 'تسوية',
  'closing': 'إقفال',
  'reversal': 'عكس',
  'opening': 'افتتاحي',
};

class JeBuilderScreen extends StatefulWidget {
  const JeBuilderScreen({super.key});
  @override
  State<JeBuilderScreen> createState() => _JeBuilderScreenState();
}

// ═══════════════════════════════════════════════════════════════════
// Journal Entries list — 100-wave modernization.
//
// Research basis (global accounting platform UX):
//   SAP S/4HANA Fiori, Oracle Fusion Cloud, Odoo 17 Accounting,
//   NetSuite SuiteCloud, QuickBooks Online, Xero, Zoho Books,
//   Sage Intacct, FreshBooks, Wave.
//
// Waves applied:
//   K — Visual tokens + palette (20)
//   L — Header: gradient, stats, live totals, actions (20)
//   M — Toolbar: smart search + date range + multi-select filters +
//       view/density/sort/export (20)
//   N — List: sticky header, density, select all, group headers,
//       row hover, inline actions, status pills (20)
//   O — Empty state + animations + a11y (20)
// ═══════════════════════════════════════════════════════════════════

// Density modes (Zoho / SAP Fiori convention).
enum _Density { compact, comfortable, spacious }

// View mode (Odoo / NetSuite convention).
enum _ViewMode { list, cards }

// Sort fields.
enum _SortKey { dateDesc, dateAsc, numberAsc, debitDesc, creditDesc }

// Date preset (QuickBooks / Xero pattern).
enum _DatePreset { all, today, week, month, quarter, year, custom }

// ─── Inline create modes — يستبدلان الفولسكرين بلوحة داخل نفس الشاشة ───
enum _InlineMode { list, createManual, createAi }

class _JeBuilderScreenState extends State<JeBuilderScreen> {
  final PilotClient _client = pilotClient;

  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  // Legacy single-select (kept for API compatibility).
  String _statusFilter = 'all';
  String _kindFilter = 'all';

  // ── Inline panel state (replaces list area with manual/ai editor inline)
  _InlineMode _inlineMode = _InlineMode.list;

  // ── Wave M: advanced filters ────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _search = '';
  final Set<String> _statusMulti = <String>{}; // empty = all
  final Set<String> _kindMulti = <String>{}; // empty = all
  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _SortKey _sort = _SortKey.dateDesc;
  _Density _density = _Density.comfortable;
  _ViewMode _viewMode = _ViewMode.list;
  final Set<String> _selectedIds = <String>{}; // bulk selection
  bool _showAdvanced = false;

  // Ported from CoA: Group-by + Column visibility + Collapse
  String _groupBy = 'none'; // none | day | month | status | kind
  final Set<String> _collapsedGroups = <String>{};
  final Set<String> _visibleColumns = <String>{
    'number',
    'date',
    'kind',
    'status',
    'memo',
    'debit',
    'credit',
    'actions',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // Apply client-side search + multi-select filters + date range + sort.
  List<Map<String, dynamic>> get _visibleEntries {
    final q = _search.toLowerCase();
    var out = _entries.where((e) {
      if (q.isNotEmpty) {
        final n = (e['je_number'] ?? '').toString().toLowerCase();
        final m = (e['memo_ar'] ?? '').toString().toLowerCase();
        final k = (e['kind'] ?? '').toString().toLowerCase();
        if (!(n.contains(q) || m.contains(q) || k.contains(q))) return false;
      }
      if (_statusMulti.isNotEmpty && !_statusMulti.contains(e['status'])) {
        return false;
      }
      if (_kindMulti.isNotEmpty && !_kindMulti.contains(e['kind'])) {
        return false;
      }
      if (_dateFrom != null || _dateTo != null) {
        final ds = (e['je_date'] ?? '').toString();
        if (ds.isEmpty) return false;
        try {
          final dt = DateTime.parse(ds);
          if (_dateFrom != null && dt.isBefore(_dateFrom!)) return false;
          if (_dateTo != null && dt.isAfter(_dateTo!)) return false;
        } catch (_) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort
    switch (_sort) {
      case _SortKey.dateDesc:
        out.sort((a, b) =>
            (b['je_date'] ?? '').toString().compareTo((a['je_date'] ?? '').toString()));
        break;
      case _SortKey.dateAsc:
        out.sort((a, b) =>
            (a['je_date'] ?? '').toString().compareTo((b['je_date'] ?? '').toString()));
        break;
      case _SortKey.numberAsc:
        out.sort((a, b) =>
            (a['je_number'] ?? '').toString().compareTo((b['je_number'] ?? '').toString()));
        break;
      case _SortKey.debitDesc:
        out.sort((a, b) => asDouble(b['total_debit']).compareTo(asDouble(a['total_debit'])));
        break;
      case _SortKey.creditDesc:
        out.sort((a, b) => asDouble(b['total_credit']).compareTo(asDouble(a['total_credit'])));
        break;
    }
    return out;
  }

  int get _activeFilterCount {
    var n = 0;
    if (_search.isNotEmpty) n++;
    if (_statusMulti.isNotEmpty) n++;
    if (_kindMulti.isNotEmpty) n++;
    if (_datePreset != _DatePreset.all) n++;
    return n;
  }

  void _clearAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _search = '';
      _statusMulti.clear();
      _kindMulti.clear();
      _datePreset = _DatePreset.all;
      _dateFrom = null;
      _dateTo = null;
      _sort = _SortKey.dateDesc;
    });
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  void _applyDatePreset(_DatePreset p) {
    final now = DateTime.now();
    setState(() {
      _datePreset = p;
      switch (p) {
        case _DatePreset.all:
          _dateFrom = null;
          _dateTo = null;
          break;
        case _DatePreset.today:
          _dateFrom = DateTime(now.year, now.month, now.day);
          _dateTo = _dateFrom;
          break;
        case _DatePreset.week:
          _dateFrom = now.subtract(Duration(days: now.weekday - 1));
          _dateTo = now;
          break;
        case _DatePreset.month:
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = now;
          break;
        case _DatePreset.quarter:
          final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
          _dateFrom = DateTime(now.year, qStart, 1);
          _dateTo = now;
          break;
        case _DatePreset.year:
          _dateFrom = DateTime(now.year, 1, 1);
          _dateTo = now;
          break;
        case _DatePreset.custom:
          // caller should open picker
          break;
      }
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // G-UX-2 (Sprint 13): replace dead-end error with smart resolver
    // (auto-select singleton entity / picker for multi / onboarding for none).
    // See lib/pilot/services/entity_resolver.dart.
    if (!PilotSession.hasEntity) {
      final resolved = await EntityResolver.ensureEntitySelected(context);
      if (!resolved) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
    }
    final eid = PilotSession.entityId!;
    try {
      final results = await Future.wait([
        _client.listJournalEntries(eid,
            status: _statusFilter == 'all' ? null : _statusFilter,
            kind: _kindFilter == 'all' ? null : _kindFilter,
            limit: 200),
        _client.listAccounts(eid),
      ]);
      // ignore: avoid_print
      print('[JeBuilder] API results: entries.success=${results[0].success}, accounts.success=${results[1].success}');
      if (!mounted) return;
      // Defensive: handle null/non-list data gracefully
      try {
        _entries = results[0].success && results[0].data is List
            ? List<Map<String, dynamic>>.from(results[0].data as List)
            : [];
      } catch (e) {
        // ignore: avoid_print
        print('[JeBuilder] entries parse error: $e');
        _entries = [];
      }
      try {
        _accounts = results[1].success && results[1].data is List
            ? List<Map<String, dynamic>>.from(results[1].data as List)
            : [];
      } catch (e) {
        // ignore: avoid_print
        print('[JeBuilder] accounts parse error: $e');
        _accounts = [];
      }
      setState(() => _loading = false);
    } catch (e, st) {
      // ignore: avoid_print
      print('[JeBuilder] _load caught exception: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // Create flow — يفتح V5.2 ObjectPage screen (JeBuilderLiveV52Screen)
  // كصفحة فرعية. هذه الصفحة فيها: stepper + chatter + tabs + smart
  // buttons + AI integrations (قراءة مستند + اكتب بياناً) + real backend.
  // ───────────────────────────────────────────────────────────────────
  Future<void> _openInline(_InlineMode mode) async {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _warn,
          content: Text('ابذر شجرة الحسابات أولاً')));
      return;
    }
    // Push via go_router so the V5.2 builder is wrapped by
    // ApexV5ServiceShell — the unified top bar (logo + breadcrumb +
    // Cmd+K + actions) stays visible. JeBuilderLiveV52Screen still pops
    // with Navigator.pop(true) on save; go_router's PageRoute returns it.
    final saved = await context.push<bool>('/app/erp/finance/je-builder/new');
    if (!mounted) return;
    if (saved == true) _load();
  }

  void _closeInline({bool reload = false}) {
    if (reload && mounted) _load();
  }

  void _create() => _openInline(_InlineMode.createManual);

  Future<void> _post(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text('ترحيل القيد', style: TextStyle(color: _tp)),
          content: Text(
              'سيتم ترحيل القيد إلى GL Postings. هذا الإجراء لا يمكن التراجع عنه — يمكن فقط عكس القيد.',
              style: TextStyle(color: _ts, height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: core_theme.AC.btnFg),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ترحيل')),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final r = await _client.postJournalEntry(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.success ? _ok : _err,
        content: Text(r.success ? 'تم الترحيل ✓' : r.error ?? 'فشل الترحيل')));
    if (r.success) _load();
  }

  Future<void> _reverse(Map<String, dynamic> je) async {
    final memoCtrl = TextEditingController(text: 'عكس قيد ${je['je_number']}');
    DateTime date = DateTime.now();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _navy2,
            title: Text('عكس القيد', style: TextStyle(color: _tp)),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setSt(() => date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _navy3,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _bdr)),
                    child: Row(children: [
                      Icon(Icons.calendar_today,
                          color: _td, size: 14),
                      const SizedBox(width: 6),
                      Text(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              color: _tp,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: memoCtrl,
                  style: TextStyle(color: _tp),
                  decoration: InputDecoration(
                    labelText: 'سبب العكس',
                    labelStyle: TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: _bdr)),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('إلغاء', style: TextStyle(color: _ts))),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _err, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('عكس'),
              ),
            ],
          ),
        ),
      ),
    );
    if (r != true) return;
    final resp = await _client.reverseJournalEntry(je['id'], {
      'reversal_date': date.toIso8601String().substring(0, 10),
      'memo_ar': memoCtrl.text.trim(),
    });
    memoCtrl.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: resp.success ? _ok : _err,
        content:
            Text(resp.success ? 'تم إنشاء القيد العكسي ✓' : resp.error ?? 'فشل')));
    if (resp.success) _load();
  }

  Future<void> _showDetail(String id) async {
    // Used to open the legacy _JeDetailDialog modal. Now navigates to
    // the v5.2 live builder so clicking a row opens the same screen
    // used for create/edit, with the entry preloaded via jeId.
    final saved = await context.push<bool>(
        '/app/erp/finance/je-builder/$id');
    if (saved == true && mounted) _load();
  }

  // ──────────────────────────────────────────────────────────────────
  // Filter glue for ApexListToolbar (matches sales-invoices_screen).
  // ──────────────────────────────────────────────────────────────────
  ApexFilterGroup _buildStatusFilterGroup() {
    return ApexFilterGroup(
      labelAr: 'الحالة',
      icon: Icons.task_alt_rounded,
      options: const [
        ApexFilterOption(key: 'posted', labelAr: 'مرحّل'),
        ApexFilterOption(key: 'pending_review', labelAr: 'قيد المراجعة'),
        ApexFilterOption(key: 'draft', labelAr: 'مسودة'),
        ApexFilterOption(key: 'reversed', labelAr: 'معكوس'),
      ],
      selected: _statusMulti,
      onToggle: (k) => setState(() {
        if (_statusMulti.contains(k)) {
          _statusMulti.remove(k);
        } else {
          _statusMulti.add(k);
        }
      }),
    );
  }

  ApexFilterGroup _buildKindFilterGroup() {
    return ApexFilterGroup(
      labelAr: 'النوع',
      icon: Icons.category_rounded,
      options: const [
        ApexFilterOption(key: 'manual', labelAr: 'يدوي'),
        ApexFilterOption(key: 'auto', labelAr: 'آلي'),
        ApexFilterOption(key: 'reversal', labelAr: 'عكسي'),
        ApexFilterOption(key: 'closing', labelAr: 'إقفال'),
      ],
      selected: _kindMulti,
      onToggle: (k) => setState(() {
        if (_kindMulti.contains(k)) {
          _kindMulti.remove(k);
        } else {
          _kindMulti.add(k);
        }
      }),
    );
  }

  String _sortKeyForToolbar() {
    switch (_sort) {
      case _SortKey.dateDesc:
        return 'date_desc';
      case _SortKey.dateAsc:
        return 'date_asc';
      case _SortKey.numberAsc:
        return 'number_asc';
      case _SortKey.debitDesc:
        return 'debit_desc';
      case _SortKey.creditDesc:
        return 'credit_desc';
    }
  }

  void _setSortFromToolbar(String key) {
    setState(() {
      _sort = switch (key) {
        'date_desc' => _SortKey.dateDesc,
        'date_asc' => _SortKey.dateAsc,
        'number_asc' => _SortKey.numberAsc,
        'debit_desc' => _SortKey.debitDesc,
        'credit_desc' => _SortKey.creditDesc,
        _ => _SortKey.dateDesc,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;
    final hasNoEntries = _entries.isEmpty;
    final hasNoResults = !hasNoEntries && visible.isEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Shortcuts(
        // Wave O: keyboard shortcuts — N=new, /=search, Esc=clear filters
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyN): _NewEntryIntent(),
          SingleActivator(LogicalKeyboardKey.slash): _FocusSearchIntent(),
          SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _FocusSearchIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _ClearFiltersIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _NewEntryIntent:
                CallbackAction<_NewEntryIntent>(onInvoke: (_) => _create()),
            _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
                onInvoke: (_) {
              _searchFocus.requestFocus();
              _searchCtrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchCtrl.text.length,
              );
              return null;
            }),
            _ClearFiltersIntent: CallbackAction<_ClearFiltersIntent>(
                onInvoke: (_) {
              if (_activeFilterCount > 0) _clearAllFilters();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: _navy,
              body: Column(children: [
                // ── Unified ApexListToolbar (same as sales-invoices) ────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: ApexListToolbar(
                    titleAr: 'القيود اليومية',
                    titleIcon: Icons.menu_book_rounded,
                    itemNounAr: 'قيد',
                    totalCount: _entries.length,
                    visibleCount: visible.length,
                    searchCtl: _searchCtrl,
                    searchFocus: _searchFocus,
                    searchHint: 'بحث برقم القيد أو البيان…',
                    onSearchChanged: () =>
                        setState(() => _search = _searchCtrl.text),
                    filterGroups: [
                      _buildStatusFilterGroup(),
                      _buildKindFilterGroup(),
                    ],
                    groupOptions: const [
                      ApexGroupOption(
                          key: 'none',
                          labelAr: 'بلا تجميع',
                          icon: Icons.view_list_rounded),
                      ApexGroupOption(
                          key: 'day',
                          labelAr: 'اليوم',
                          icon: Icons.today_rounded),
                      ApexGroupOption(
                          key: 'month',
                          labelAr: 'الشهر',
                          icon: Icons.calendar_month_rounded),
                      ApexGroupOption(
                          key: 'status',
                          labelAr: 'الحالة',
                          icon: Icons.task_alt_rounded),
                      ApexGroupOption(
                          key: 'kind',
                          labelAr: 'النوع',
                          icon: Icons.category_rounded),
                    ],
                    activeGroupKey: _groupBy,
                    onChangeGroup: (k) => setState(() => _groupBy = k),
                    sortOptions: const [
                      ApexFilterOption(
                          key: 'date_desc',
                          labelAr: 'التاريخ (الأحدث)'),
                      ApexFilterOption(
                          key: 'date_asc',
                          labelAr: 'التاريخ (الأقدم)'),
                      ApexFilterOption(
                          key: 'number_asc', labelAr: 'رقم القيد'),
                      ApexFilterOption(
                          key: 'debit_desc',
                          labelAr: 'المدين (الأكبر)'),
                      ApexFilterOption(
                          key: 'credit_desc',
                          labelAr: 'الدائن (الأكبر)'),
                    ],
                    activeSortKey: _sortKeyForToolbar(),
                    onChangeSort: _setSortFromToolbar,
                    onClearAllFilters:
                        _activeFilterCount > 0 ? _clearAllFilters : null,
                    viewModes: const [
                      ApexViewMode(
                          key: 'list',
                          labelAr: 'قائمة',
                          icon: Icons.view_list_rounded),
                      ApexViewMode(
                          key: 'cards',
                          labelAr: 'بطاقات',
                          icon: Icons.grid_view_rounded),
                    ],
                    activeViewKey: _viewMode == _ViewMode.cards
                        ? 'cards'
                        : 'list',
                    onChangeView: (k) => setState(() => _viewMode =
                        k == 'cards' ? _ViewMode.cards : _ViewMode.list),
                    onCreate: _create,
                    createLabelAr: 'قيد جديد',
                    onAiCreate: _create,
                    aiCreateLabelAr: 'ذكاء',
                    // Selection mode is handled by the screen's existing
                    // _bulkActionBar() rendered just below this toolbar,
                    // not by ApexListToolbar's built-in selection swap.
                    // Passing selectedCount here would render an empty
                    // duplicate "X محدّد" bar with no actions.
                    // Half the previous full-row width. Active filter /
                    // group chips flow downward inside the pill (Wrap
                    // with runSpacing) so the box grows in height when
                    // needed without consuming horizontal space.
                    searchPillMaxWidth: 380,
                  ),
                ),
                if (_selectedIds.isNotEmpty) _bulkActionBar(),
                // Active filters are now rendered inside the toolbar pill
                // (ApexListToolbar's chips Wrap), so the legacy strip
                // below is suppressed to avoid duplicate / overflowing
                // chip rows under the search box.
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _loading
                        ? _loadingSkeleton()
                        : _error != null
                            ? _errorView()
                            : hasNoEntries
                                ? _emptyView()
                                : hasNoResults
                                    ? _noResultsView()
                                    : _list(visible),
                  ),
                ),
                if (!_loading &&
                    _error == null &&
                    !hasNoEntries &&
                    !hasNoResults)
                  _totalsFooter(visible),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Wave L — Header: gradient backdrop, live stats cards, actions row.
  // Inspired by SAP Fiori Object Page header + NetSuite hero band.
  // ══════════════════════════════════════════════════════════════════
  Widget _header(List<Map<String, dynamic>> visible) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _navy2,
            Color.lerp(_navy2, _gold, 0.05) ?? _navy2,
          ],
        ),
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: icon + title + actions
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_gold.withValues(alpha: 0.22), _gold.withValues(alpha: 0.10)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.menu_book_rounded, color: _gold, size: 22),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'قيود اليومية',
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _tp,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeFilterCount > 0
                        ? '${visible.length} / ${_entries.length}'
                        : '${_entries.length} قيد',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: _ts, fontSize: 11, height: 1.1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── Compact search (RTL, 200px flex) ──────────────────
            Flexible(
              flex: 2,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 220, minWidth: 120),
                child: _compactSearchField(),
              ),
            ),
            const SizedBox(width: 6),
            // ── Combined Filter (date + status + kind + sort) ─────
            _combinedFilterButton(),
            const SizedBox(width: 4),
            _groupByButton(),
            const SizedBox(width: 4),
            _compactViewToggle(),
            const Spacer(),
            // ── Actions cluster ──────────────────────────────────
            Tooltip(
              message: 'تحديث',
              child: IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: _ts, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: _navy3.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: _bdr),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _HeaderIconBtn(
              icon: Icons.ios_share_rounded,
              tooltip: 'تصدير CSV',
              onTap: _exportMenu,
            ),
            const SizedBox(width: 4),
            _HeaderIconBtn(
              icon: Icons.help_outline_rounded,
              tooltip: 'اختصارات (N قيد جديد · / بحث · Esc مسح)',
              onTap: _showShortcutsHelp,
            ),
            const SizedBox(width: 12),
            // ── زر 1: إنشاء قيد يدوي ──
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _tp,
                side: BorderSide(color: _gold.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openInline(_InlineMode.createManual),
              icon: Icon(Icons.add_rounded, size: 18, color: _gold),
              label: const Text(
                'جديد',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            // ── زر 2: قراءة مستند بالذكاء الاصطناعي ──
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: core_theme.AC.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => _openInline(_InlineMode.createAi),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'ذكاء',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          // Removed: live stats cards (إجمالي مدين / إجمالي دائن / متوازن).
          // The same totals already appear inside the JE detail/builder
          // pane footer when a single entry is open — the top row was
          // redundant noise on the list view.
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Wave P — Quick filter presets
  // Inspired by Linear's "Views" + NetSuite "Saved Searches" + GitHub filter bar.
  // ══════════════════════════════════════════════════════════════════
  String _activePreset = 'all';

  Widget _quickPresetsRow() {
    final presets = <Map<String, dynamic>>[
      {'id': 'all', 'label': 'الكل', 'icon': Icons.list_alt_rounded, 'color': _ts},
      {'id': 'drafts', 'label': 'مسوّدات', 'icon': Icons.edit_note_rounded, 'color': _td},
      {'id': 'pending', 'label': 'تحتاج اعتماد', 'icon': Icons.hourglass_top_rounded, 'color': _warn},
      {'id': 'posted', 'label': 'مُرحَّلة', 'icon': Icons.check_circle_rounded, 'color': _ok},
      {'id': 'today', 'label': 'اليوم', 'icon': Icons.today_rounded, 'color': _blue},
      {'id': 'week', 'label': 'هذا الأسبوع', 'icon': Icons.view_week_rounded, 'color': _blue},
      {'id': 'reversed', 'label': 'معكوسة', 'icon': Icons.undo_rounded, 'color': _err},
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: _bdr.withValues(alpha: 0.3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final p in presets) ...[
            _presetChip(
              id: p['id'] as String,
              label: p['label'] as String,
              icon: p['icon'] as IconData,
              color: p['color'] as Color,
              active: _activePreset == p['id'],
              count: _countForPreset(p['id'] as String),
            ),
            const SizedBox(width: 8),
          ],
        ]),
      ),
    );
  }

  int _countForPreset(String id) {
    return _entries.where((e) {
      switch (id) {
        case 'all':
          return true;
        case 'drafts':
          return e['status'] == 'draft';
        case 'pending':
          return e['status'] == 'submitted' || e['status'] == 'approved';
        case 'posted':
          return e['status'] == 'posted';
        case 'reversed':
          return e['status'] == 'reversed';
        case 'today':
          final ds = (e['je_date'] ?? '').toString();
          if (ds.isEmpty) return false;
          final today = DateTime.now();
          final todayStr =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          return ds == todayStr;
        case 'week':
          final ds = (e['je_date'] ?? '').toString();
          if (ds.isEmpty) return false;
          try {
            final dt = DateTime.parse(ds);
            final weekStart = DateTime.now()
                .subtract(Duration(days: DateTime.now().weekday - 1));
            return dt.isAfter(weekStart.subtract(const Duration(days: 1)));
          } catch (_) {
            return false;
          }
      }
      return false;
    }).length;
  }

  void _applyPreset(String id) {
    setState(() {
      _activePreset = id;
      _statusMulti.clear();
      _kindMulti.clear();
      _datePreset = _DatePreset.all;
      _dateFrom = null;
      _dateTo = null;
      switch (id) {
        case 'all':
          break;
        case 'drafts':
          _statusMulti.add('draft');
          break;
        case 'pending':
          _statusMulti.addAll(['submitted', 'approved']);
          break;
        case 'posted':
          _statusMulti.add('posted');
          break;
        case 'reversed':
          _statusMulti.add('reversed');
          break;
        case 'today':
          _applyDatePreset(_DatePreset.today);
          break;
        case 'week':
          _applyDatePreset(_DatePreset.week);
          break;
      }
    });
  }

  Widget _presetChip({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required bool active,
    required int count,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _applyPreset(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.14),
                  ],
                )
              : null,
          color: active ? null : _navy3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : _bdr,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? color : _ts),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? color : _tp,
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active ? color : _bdr.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: active ? Colors.white : _ts,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Wave Q — Totals footer with balance indicator
  // Inspired by Excel "Status Bar", QuickBooks totals row, SAP footer.
  // ══════════════════════════════════════════════════════════════════
  Widget _totalsFooter(List<Map<String, dynamic>> visible) {
    // Only sum rows in filter; if selection exists, sum selection only.
    final rows = _selectedIds.isNotEmpty
        ? visible.where((e) => _selectedIds.contains(e['id'])).toList()
        : visible;
    final debit = rows.fold(0.0, (t, e) => t + asDouble(e['total_debit']));
    final credit = rows.fold(0.0, (t, e) => t + asDouble(e['total_credit']));
    final diff = (debit - credit).abs();
    final balanced = diff < 0.005;
    final scopeLabel = _selectedIds.isEmpty
        ? '${rows.length} قيد ظاهر'
        : '${rows.length} قيد محدَّد';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _navy2,
        border: Border(top: BorderSide(color: _bdr)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(children: [
        Icon(Icons.functions_rounded, size: 16, color: _gold),
        const SizedBox(width: 8),
        Text('الإجماليات:',
            style: TextStyle(
                color: _td,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
        const SizedBox(width: 8),
        Text(scopeLabel,
            style: TextStyle(
                color: _ts, fontSize: 11, fontWeight: FontWeight.w600)),
        const Spacer(),
        _totalPill(
          icon: Icons.trending_up_rounded,
          label: 'مدين',
          value: _fmt(debit),
          color: _ok,
        ),
        const SizedBox(width: 8),
        _totalPill(
          icon: Icons.trending_down_rounded,
          label: 'دائن',
          value: _fmt(credit),
          color: _indigo,
        ),
        const SizedBox(width: 8),
        _totalPill(
          icon: balanced
              ? Icons.balance_rounded
              : Icons.warning_amber_rounded,
          label: balanced ? 'متوازن' : 'فرق',
          value: balanced ? '✓' : _fmt(diff),
          color: balanced ? _ok : _warn,
          emphasized: true,
        ),
      ]),
    );
  }

  Widget _totalPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool emphasized = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: emphasized ? 0.55 : 0.30),
          width: emphasized ? 1.5 : 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Wave R — CSV export (real implementation)
  // ══════════════════════════════════════════════════════════════════
  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String _exportCsv(List<Map<String, dynamic>> rows) {
    final buf = StringBuffer();
    // BOM for Excel to recognize UTF-8
    buf.writeCharCode(0xFEFF);
    buf.writeln('رقم القيد,التاريخ,النوع,الحالة,البيان,مدين,دائن');
    for (final e in rows) {
      buf.writeln([
        _csvEscape((e['je_number'] ?? '').toString()),
        _csvEscape((e['je_date'] ?? '').toString()),
        _csvEscape(_kKinds[e['kind']] ?? (e['kind'] ?? '').toString()),
        _csvEscape(
            (_kStatuses[e['status']]?['ar'] as String?) ?? (e['status'] ?? '').toString()),
        _csvEscape((e['memo_ar'] ?? '').toString()),
        asDouble(e['total_debit']).toStringAsFixed(2),
        asDouble(e['total_credit']).toStringAsFixed(2),
      ].join(','));
    }
    return buf.toString();
  }

  Future<void> _showShortcutsHelp() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text('اختصارات لوحة المفاتيح',
              style: TextStyle(color: _tp, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _ShortcutRow(shortcut: 'N', desc: 'قيد جديد'),
              _ShortcutRow(shortcut: '/', desc: 'تركيز البحث'),
              _ShortcutRow(shortcut: 'Ctrl+F', desc: 'تركيز البحث'),
              _ShortcutRow(shortcut: 'Esc', desc: 'مسح جميع الفلاتر'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Compact header controls (ported pattern from CoA _buildHeader)
  // ══════════════════════════════════════════════════════════════════

  // Slim search for header — takes 120-220px
  Widget _compactSearchField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (_, v, __) {
        return TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: _tp, fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            hintText: 'بحث (/)',
            hintStyle: TextStyle(color: _td, fontSize: 12),
            prefixIcon: Icon(Icons.search_rounded, color: _td, size: 16),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 30, minHeight: 30),
            suffixIcon: v.text.isEmpty
                ? null
                : InkWell(
                    onTap: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                    child: Icon(Icons.close_rounded, color: _td, size: 14),
                  ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 26, minHeight: 26),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _bdr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _bdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _gold, width: 1.4),
            ),
          ),
        );
      },
    );
  }

  // Single Filter button with badge — combines date + status + kind + sort
  // into one MenuAnchor with submenus (CoA pattern).
  Widget _combinedFilterButton() {
    final active = _activeFilterCount;
    final has = active > 0;
    final bg = has ? _gold : _navy3;
    final fg = has ? core_theme.AC.btnFg : _ts;
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStateProperty.all(_navy2),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _bdr),
      )),
      padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 4)),
    );
    return MenuAnchor(
      style: menuStyle,
      alignmentOffset: const Offset(0, 4),
      builder: (ctx, ctrl, _) {
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
            hoverColor: _gold.withValues(alpha: 0.12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: has ? _gold : _bdr.withValues(alpha: 0.9),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.filter_list_rounded, color: fg, size: 14),
                const SizedBox(width: 6),
                Text('فلتر',
                    style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                if (has) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('$active',
                        style: TextStyle(
                            color: fg,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, color: fg, size: 14),
              ]),
            ),
          ),
        );
      },
      menuChildren: _buildFilterMenu(menuStyle),
    );
  }

  List<Widget> _buildFilterMenu(MenuStyle menuStyle) {
    const datePresets = <_DatePreset, String>{
      _DatePreset.all: 'كل التواريخ',
      _DatePreset.today: 'اليوم',
      _DatePreset.week: 'هذا الأسبوع',
      _DatePreset.month: 'هذا الشهر',
      _DatePreset.quarter: 'هذا الربع',
      _DatePreset.year: 'هذه السنة',
    };
    const sortLabels = <_SortKey, String>{
      _SortKey.dateDesc: 'التاريخ (الأحدث)',
      _SortKey.dateAsc: 'التاريخ (الأقدم)',
      _SortKey.numberAsc: 'رقم القيد',
      _SortKey.debitDesc: 'المدين (الأكبر)',
      _SortKey.creditDesc: 'الدائن (الأكبر)',
    };
    final thisYear = DateTime.now().year;
    final years = [thisYear, thisYear - 1, thisYear - 2]; // last 3 years
    String _dateRangeLabel() {
      if (_datePreset == _DatePreset.all) return 'التاريخ';
      if (_datePreset == _DatePreset.custom &&
          _dateFrom != null &&
          _dateTo != null) {
        String f(DateTime d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return 'التاريخ: ${f(_dateFrom!)} → ${f(_dateTo!)}';
      }
      return 'التاريخ: ${datePresets[_datePreset] ?? ''}';
    }

    return [
      // Date
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.calendar_month_rounded,
            size: 14, color: _datePreset != _DatePreset.all ? _gold : _ts),
        menuChildren: [
          // Quick presets
          for (final e in datePresets.entries)
            MenuItemButton(
              leadingIcon: _datePreset == e.key
                  ? Icon(Icons.check_rounded, color: _gold, size: 14)
                  : const SizedBox(width: 14),
              onPressed: () => _applyDatePreset(e.key),
              child: Text(e.value,
                  style: TextStyle(
                      color: _datePreset == e.key ? _gold : _tp,
                      fontSize: 12.5)),
            ),
          const PopupMenuDivider(height: 4),
          // ── Specific quarter (nested submenu) ───────────────
          SubmenuButton(
            menuStyle: menuStyle,
            leadingIcon: Icon(Icons.view_quilt_rounded, size: 14, color: _ts),
            menuChildren: [
              for (final y in years) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: Text('$y',
                      style: TextStyle(
                          color: _td,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                ),
                for (int q = 1; q <= 4; q++)
                  MenuItemButton(
                    onPressed: () => _applyQuarter(y, q),
                    leadingIcon:
                        Icon(Icons.bookmark_outline_rounded,
                            size: 12, color: _ts),
                    child: Text(_quarterLabel(y, q),
                        style: TextStyle(color: _tp, fontSize: 12.5)),
                  ),
                if (y != years.last) const PopupMenuDivider(height: 4),
              ],
            ],
            child: Text('ربع محدّد',
                style: TextStyle(color: _tp, fontSize: 12.5)),
          ),
          // ── Specific year (nested submenu) ──────────────────
          SubmenuButton(
            menuStyle: menuStyle,
            leadingIcon: Icon(Icons.calendar_view_week_rounded,
                size: 14, color: _ts),
            menuChildren: [
              for (final y in years)
                MenuItemButton(
                  onPressed: () => _applyYear(y),
                  leadingIcon: Icon(Icons.event_rounded, size: 12, color: _ts),
                  child: Text('سنة $y',
                      style: TextStyle(color: _tp, fontSize: 12.5)),
                ),
            ],
            child: Text('سنة محدّدة',
                style: TextStyle(color: _tp, fontSize: 12.5)),
          ),
          const PopupMenuDivider(height: 4),
          // ── Custom "من - إلى" ───────────────────────────────
          MenuItemButton(
            leadingIcon: Icon(Icons.date_range_rounded,
                size: 14,
                color: _datePreset == _DatePreset.custom ? _gold : _ts),
            onPressed: () => _openCustomDateRange(),
            child: Text(
              _datePreset == _DatePreset.custom &&
                      _dateFrom != null &&
                      _dateTo != null
                  ? 'من ${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')} → ${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
                  : 'من تاريخ → إلى تاريخ…',
              style: TextStyle(
                  color: _datePreset == _DatePreset.custom ? _gold : _tp,
                  fontSize: 12.5),
            ),
          ),
        ],
        child: Text(
          _dateRangeLabel(),
          style: TextStyle(
              color: _datePreset != _DatePreset.all ? _gold : _tp,
              fontSize: 12.5),
        ),
      ),
      // Status multi-select
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.task_alt_rounded,
            size: 14, color: _statusMulti.isNotEmpty ? _gold : _ts),
        menuChildren: [
          for (final e in _kStatuses.entries)
            MenuItemButton(
              onPressed: () => setState(() {
                if (!_statusMulti.add(e.key)) {
                  _statusMulti.remove(e.key);
                }
              }),
              leadingIcon: Icon(
                _statusMulti.contains(e.key)
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 14,
                color: _statusMulti.contains(e.key)
                    ? (e.value['color'] as Color)
                    : _td,
              ),
              child: Text(e.value['ar'] as String,
                  style: TextStyle(color: _tp, fontSize: 12.5)),
            ),
        ],
        child: Text(
          _statusMulti.isEmpty
              ? 'الحالة'
              : 'الحالة (${_statusMulti.length})',
          style: TextStyle(
              color: _statusMulti.isNotEmpty ? _gold : _tp,
              fontSize: 12.5),
        ),
      ),
      // Kind multi-select
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.category_rounded,
            size: 14, color: _kindMulti.isNotEmpty ? _gold : _ts),
        menuChildren: [
          for (final e in _kKinds.entries)
            MenuItemButton(
              onPressed: () => setState(() {
                if (!_kindMulti.add(e.key)) {
                  _kindMulti.remove(e.key);
                }
              }),
              leadingIcon: Icon(
                _kindMulti.contains(e.key)
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 14,
                color: _kindMulti.contains(e.key) ? _gold : _td,
              ),
              child: Text(e.value,
                  style: TextStyle(color: _tp, fontSize: 12.5)),
            ),
        ],
        child: Text(
          _kindMulti.isEmpty ? 'النوع' : 'النوع (${_kindMulti.length})',
          style: TextStyle(
              color: _kindMulti.isNotEmpty ? _gold : _tp, fontSize: 12.5),
        ),
      ),
      // Sort
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.sort_rounded, size: 14, color: _ts),
        menuChildren: [
          for (final e in sortLabels.entries)
            MenuItemButton(
              leadingIcon: _sort == e.key
                  ? Icon(Icons.check_rounded, color: _gold, size: 14)
                  : const SizedBox(width: 14),
              onPressed: () => setState(() => _sort = e.key),
              child: Text(e.value,
                  style: TextStyle(
                      color: _sort == e.key ? _gold : _tp,
                      fontSize: 12.5)),
            ),
        ],
        child: Text('ترتيب: ${sortLabels[_sort]}',
            style: TextStyle(color: _tp, fontSize: 12.5)),
      ),
      if (_activeFilterCount > 0) ...[
        const PopupMenuDivider(height: 4),
        MenuItemButton(
          onPressed: _clearAllFilters,
          leadingIcon: Icon(Icons.clear_all_rounded,
              size: 14, color: _warn),
          child: Text('مسح الكل',
              style: TextStyle(color: _warn, fontSize: 12.5)),
        ),
      ],
    ];
  }

  // Compact list/cards toggle + density in one button (icon-only)
  Widget _compactViewToggle() {
    return Tooltip(
      message: _viewMode == _ViewMode.list ? 'عرض شبكة' : 'عرض قائمة',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() {
          _viewMode = _viewMode == _ViewMode.list
              ? _ViewMode.cards
              : _ViewMode.list;
        }),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr),
          ),
          child: Icon(
            _viewMode == _ViewMode.list
                ? Icons.grid_view_rounded
                : Icons.view_list_rounded,
            size: 14,
            color: _ts,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Ported from شجرة الحسابات (CoA) — Group-by + Columns toggle
  // ══════════════════════════════════════════════════════════════════

  static const _kGroupByOptions =
      <(String, String, IconData)>[
    ('none', 'بلا تجميع', Icons.view_list_rounded),
    ('day', 'اليوم', Icons.today_rounded),
    ('month', 'الشهر', Icons.calendar_month_rounded),
    ('quarter', 'الربع', Icons.view_quilt_rounded),
    ('year', 'السنة', Icons.calendar_view_week_rounded),
    ('status', 'الحالة', Icons.task_alt_rounded),
    ('kind', 'النوع', Icons.category_rounded),
  ];

  static const _kAllJeColumns = <String>[
    'number',
    'date',
    'kind',
    'status',
    'memo',
    'debit',
    'credit',
    'actions',
  ];
  static const _kJeColumnLabels = <String, String>{
    'number': 'رقم القيد',
    'date': 'التاريخ',
    'kind': 'النوع',
    'status': 'الحالة',
    'memo': 'البيان',
    'debit': 'مدين',
    'credit': 'دائن',
    'actions': 'الإجراءات',
  };

  Widget _groupByButton() {
    final current = _kGroupByOptions.firstWhere(
      (o) => o.$1 == _groupBy,
      orElse: () => _kGroupByOptions[0],
    );
    final isActive = _groupBy != 'none';
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(_navy2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _bdr),
        )),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 4)),
      ),
      alignmentOffset: const Offset(0, 4),
      builder: (ctx, ctrl, _) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
          hoverColor: _gold.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? _gold.withValues(alpha: 0.14) : _navy3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? _gold.withValues(alpha: 0.45) : _bdr,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(current.$3,
                  size: 14, color: isActive ? _gold : _ts),
              const SizedBox(width: 6),
              Text(
                'تجميع: ${current.$2}',
                style: TextStyle(
                  color: isActive ? _gold : _tp,
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 14, color: _ts),
            ]),
          ),
        ),
      ),
      menuChildren: [
        for (final o in _kGroupByOptions)
          MenuItemButton(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
              minimumSize:
                  WidgetStateProperty.all(const Size(200, 36)),
            ),
            leadingIcon: Icon(o.$3,
                size: 15, color: _groupBy == o.$1 ? _gold : _ts),
            trailingIcon: _groupBy == o.$1
                ? Icon(Icons.check_rounded, color: _gold, size: 14)
                : null,
            onPressed: () {
              setState(() {
                _groupBy = o.$1;
                _collapsedGroups.clear();
              });
            },
            child: Text(
              o.$2,
              style: TextStyle(
                color: _groupBy == o.$1 ? _gold : _tp,
                fontSize: 12.5,
                fontWeight: _groupBy == o.$1
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // Icon-only compact version — placed inside the table column header
  // (actions cell), exactly like شجرة الحسابات pattern.
  Widget _columnsToggleButton() {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(_navy2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _bdr),
        )),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 4)),
      ),
      alignmentOffset: const Offset(0, 4),
      builder: (ctx, ctrl, _) => Tooltip(
        message: 'إظهار/إخفاء الأعمدة',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
          hoverColor: _gold.withValues(alpha: 0.12),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Icon(Icons.view_column_rounded, size: 16, color: _ts),
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('الأعمدة المرئية',
              style: TextStyle(
                  color: _td,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
        ),
        const PopupMenuDivider(height: 4),
        for (final c in _kAllJeColumns.where(
            (c) => c != 'actions' && c != 'status'))
          MenuItemButton(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
              minimumSize:
                  WidgetStateProperty.all(const Size(220, 34)),
            ),
            onPressed: () {
              setState(() {
                if (_visibleColumns.contains(c)) {
                  _visibleColumns.remove(c);
                } else {
                  _visibleColumns.add(c);
                }
              });
            },
            leadingIcon: Icon(
              _visibleColumns.contains(c)
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 15,
              color: _visibleColumns.contains(c) ? _gold : _td,
            ),
            child: Text(
              _kJeColumnLabels[c] ?? c,
              style: TextStyle(color: _tp, fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  // Group entries by the selected key; returns ordered list of
  // (groupKey, displayLabel, rows).
  List<({String key, String label, List<Map<String, dynamic>> rows})>
      _groupedEntries(List<Map<String, dynamic>> visible) {
    if (_groupBy == 'none') {
      return [(key: '_all', label: '', rows: visible)];
    }
    final buckets = <String, List<Map<String, dynamic>>>{};
    final labels = <String, String>{};
    for (final e in visible) {
      String? k;
      String? l;
      final d = (e['je_date'] ?? '').toString();
      DateTime? dt;
      if (d.isNotEmpty) {
        try { dt = DateTime.parse(d); } catch (_) {}
      }
      switch (_groupBy) {
        case 'day':
          k = d;
          l = _relativeDate(k);
          break;
        case 'month':
          if (d.length >= 7) {
            k = d.substring(0, 7); // yyyy-MM
            l = _monthLabel(k);
          }
          break;
        case 'quarter':
          if (dt != null) {
            final q = ((dt.month - 1) ~/ 3) + 1;
            k = '${dt.year}-Q$q';
            l = _quarterLabel(dt.year, q);
          }
          break;
        case 'year':
          if (dt != null) {
            k = '${dt.year}';
            l = 'سنة ${dt.year}';
          }
          break;
        case 'status':
          final s = (e['status'] ?? 'draft').toString();
          k = s;
          l = (_kStatuses[s]?['ar'] as String?) ?? s;
          break;
        case 'kind':
          final kn = (e['kind'] ?? '').toString();
          k = kn;
          l = _kKinds[kn] ?? kn;
          break;
      }
      k ??= '—';
      l ??= '—';
      labels[k] = l;
      (buckets[k] ??= []).add(e);
    }
    // Sort buckets by natural key order (dates desc, others by label)
    final sortedKeys = buckets.keys.toList()
      ..sort((a, b) {
        if (_groupBy == 'day' ||
            _groupBy == 'month' ||
            _groupBy == 'quarter' ||
            _groupBy == 'year') {
          return b.compareTo(a); // newest first
        }
        return (labels[a] ?? a).compareTo(labels[b] ?? b);
      });
    return [
      for (final k in sortedKeys)
        (key: k, label: labels[k] ?? k, rows: buckets[k]!),
    ];
  }

  String _monthLabel(String yyyymm) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    try {
      final p = yyyymm.split('-');
      final y = int.parse(p[0]);
      final m = int.parse(p[1]);
      return '${months[m - 1]} $y';
    } catch (_) {
      return yyyymm;
    }
  }

  String _quarterLabel(int year, int q) {
    const names = ['', 'الربع الأول', 'الربع الثاني', 'الربع الثالث', 'الربع الرابع'];
    return '${names[q]} $year';
  }

  // Return (start, end) DateTime range for a quarter.
  (DateTime, DateTime) _quarterRange(int year, int q) {
    final startMonth = (q - 1) * 3 + 1;
    final start = DateTime(year, startMonth, 1);
    final endMonth = startMonth + 2;
    final endMonthLastDay = DateTime(year, endMonth + 1, 0).day;
    final end = DateTime(year, endMonth, endMonthLastDay);
    return (start, end);
  }

  void _applyQuarter(int year, int q) {
    final (s, e) = _quarterRange(year, q);
    setState(() {
      _datePreset = _DatePreset.custom;
      _dateFrom = s;
      _dateTo = e;
    });
  }

  void _applyYear(int year) {
    setState(() {
      _datePreset = _DatePreset.custom;
      _dateFrom = DateTime(year, 1, 1);
      _dateTo = DateTime(year, 12, 31);
    });
  }

  Future<void> _openCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      helpText: 'اختر الفترة',
      saveText: 'تطبيق',
      cancelText: 'إلغاء',
    );
    if (picked != null && mounted) {
      setState(() {
        _datePreset = _DatePreset.custom;
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  Widget _groupHeaderRow({
    required String label,
    required List<Map<String, dynamic>> rows,
    required bool collapsed,
    required VoidCallback onToggle,
  }) {
    final debit = rows.fold(0.0, (t, e) => t + asDouble(e['total_debit']));
    final credit = rows.fold(0.0, (t, e) => t + asDouble(e['total_credit']));
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          AnimatedRotation(
            duration: const Duration(milliseconds: 160),
            turns: collapsed ? -0.25 : 0,
            child: Icon(Icons.expand_more_rounded, color: _gold, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: _tp,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${rows.length}',
                style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          Icon(Icons.trending_up_rounded, color: _ok, size: 12),
          const SizedBox(width: 4),
          Text(_fmt(debit),
              style: TextStyle(
                  color: _ok,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Icon(Icons.trending_down_rounded, color: _indigo, size: 12),
          const SizedBox(width: 4),
          Text(_fmt(credit),
              style: TextStyle(
                  color: _indigo,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
        ]),
      ),
    );
  }

  void _exportMenu() async {
    final rows = _selectedIds.isNotEmpty
        ? _visibleEntries.where((e) => _selectedIds.contains(e['id'])).toList()
        : _visibleEntries;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _warn,
          content: Text('لا توجد قيود للتصدير',
              style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }
    final csv = _exportCsv(rows);
    // Trigger browser download (dart:html)
    try {
      // ignore: avoid_web_libraries_in_flutter
      // Inline import via import at top: we use dart:html from the shell
      // path. For this file, reuse the dynamic approach to keep deps minimal.
      final bytes = csv.codeUnits;
      final blob = _makeBlob(bytes, 'text/csv;charset=utf-8');
      final url = _createObjectUrl(blob);
      final now = DateTime.now();
      final fname =
          'journal_entries_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      _downloadUrl(url, fname);
      _revokeObjectUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _ok,
          content: Text('تم تصدير ${rows.length} قيد إلى CSV ✓',
              style: TextStyle(color: Colors.white)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _err,
          content: Text('فشل التصدير: $e',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // Wave M — Toolbar: smart search + date presets + status + view
  // ══════════════════════════════════════════════════════════════════
  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.55),
        border: Border(bottom: BorderSide(color: _bdr.withValues(alpha: 0.5))),
      ),
      child: LayoutBuilder(builder: (ctx, c) {
        final narrow = c.maxWidth < 900;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Smart search
            SizedBox(
              width: narrow ? c.maxWidth : 320,
              child: _smartSearchField(),
            ),
            // Date preset picker
            _datePresetMenu(),
            // Status multi-select
            _multiSelectMenu<String>(
              icon: Icons.task_alt_rounded,
              label: _statusMulti.isEmpty
                  ? 'الحالة'
                  : 'الحالة (${_statusMulti.length})',
              entries: _kStatuses.entries
                  .map((e) => MapEntry(e.key, e.value['ar'] as String))
                  .toList(),
              selected: _statusMulti,
              iconColorFor: (id) =>
                  _kStatuses[id]?['color'] as Color? ?? _td,
              onToggle: (id) {
                setState(() {
                  if (!_statusMulti.add(id)) _statusMulti.remove(id);
                });
              },
              onClear: () => setState(() => _statusMulti.clear()),
            ),
            // Kind multi-select
            _multiSelectMenu<String>(
              icon: Icons.category_rounded,
              label: _kindMulti.isEmpty
                  ? 'النوع'
                  : 'النوع (${_kindMulti.length})',
              entries: _kKinds.entries.toList(),
              selected: _kindMulti,
              iconColorFor: (_) => _ts,
              onToggle: (id) {
                setState(() {
                  if (!_kindMulti.add(id)) _kindMulti.remove(id);
                });
              },
              onClear: () => setState(() => _kindMulti.clear()),
            ),
            const SizedBox(width: 6),
            _sortMenu(),
            _groupByButton(), // Ported from CoA
            _columnsToggleButton(), // Ported from CoA
            _densityMenu(),
            _viewModeToggle(),
            if (_activeFilterCount > 0)
              TextButton.icon(
                onPressed: _clearAllFilters,
                icon: Icon(Icons.clear_rounded, size: 14, color: _warn),
                label: Text('مسح الفلاتر',
                    style: TextStyle(color: _warn, fontSize: 11)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _smartSearchField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (_, v, __) {
        return TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: _tp, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            hintText: 'ابحث برقم القيد، البيان، النوع…  (/)',
            hintStyle: TextStyle(color: _td, fontSize: 12),
            prefixIcon: Icon(Icons.search_rounded, color: _ts, size: 18),
            suffixIcon: v.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح (Esc)',
                    icon: Icon(Icons.close_rounded,
                        color: _ts, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _bdr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _bdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _gold, width: 1.5),
            ),
          ),
        );
      },
    );
  }

  Widget _datePresetMenu() {
    const labels = <_DatePreset, String>{
      _DatePreset.all: 'كل التواريخ',
      _DatePreset.today: 'اليوم',
      _DatePreset.week: 'هذا الأسبوع',
      _DatePreset.month: 'هذا الشهر',
      _DatePreset.quarter: 'هذا الربع',
      _DatePreset.year: 'هذه السنة',
      _DatePreset.custom: 'مخصّص…',
    };
    return PopupMenuButton<_DatePreset>(
      tooltip: 'نطاق التاريخ',
      initialValue: _datePreset,
      onSelected: (p) async {
        if (p == _DatePreset.custom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: (_dateFrom != null && _dateTo != null)
                ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
                : null,
          );
          if (picked != null) {
            setState(() {
              _datePreset = _DatePreset.custom;
              _dateFrom = picked.start;
              _dateTo = picked.end;
            });
          }
        } else {
          _applyDatePreset(p);
        }
      },
      color: _navy2,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => labels.entries.map((e) {
        return CheckedPopupMenuItem<_DatePreset>(
          value: e.key,
          checked: e.key == _datePreset,
          child: Text(e.value, style: TextStyle(color: _tp, fontSize: 13)),
        );
      }).toList(),
      child: _toolbarChip(
        icon: Icons.calendar_month_rounded,
        label: labels[_datePreset] ?? 'التاريخ',
        highlight: _datePreset != _DatePreset.all,
      ),
    );
  }

  Widget _multiSelectMenu<T>({
    required IconData icon,
    required String label,
    required List<MapEntry<T, String>> entries,
    required Set<T> selected,
    required Color Function(T) iconColorFor,
    required void Function(T) onToggle,
    required VoidCallback onClear,
  }) {
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: (v) => onToggle(v),
      color: _navy2,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        ...entries.map((e) {
          final isSel = selected.contains(e.key);
          return PopupMenuItem<T>(
            value: e.key,
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 14, vertical: 8),
              child: Row(children: [
                Icon(
                  isSel
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: isSel ? _gold : _td,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 6,
                  height: 16,
                  decoration: BoxDecoration(
                    color: iconColorFor(e.key),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(e.value, style: TextStyle(color: _tp, fontSize: 13)),
              ]),
            ),
          );
        }),
        if (selected.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<T>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () {
                onClear();
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  Icon(Icons.clear_all_rounded, color: _warn, size: 16),
                  const SizedBox(width: 8),
                  Text('مسح الاختيار',
                      style: TextStyle(color: _warn, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ],
      ],
      child: _toolbarChip(
        icon: icon,
        label: label,
        highlight: selected.isNotEmpty,
      ),
    );
  }

  Widget _sortMenu() {
    const labels = <_SortKey, String>{
      _SortKey.dateDesc: 'التاريخ (الأحدث)',
      _SortKey.dateAsc: 'التاريخ (الأقدم)',
      _SortKey.numberAsc: 'رقم القيد',
      _SortKey.debitDesc: 'المدين (الأكبر)',
      _SortKey.creditDesc: 'الدائن (الأكبر)',
    };
    return PopupMenuButton<_SortKey>(
      tooltip: 'ترتيب',
      initialValue: _sort,
      onSelected: (s) => setState(() => _sort = s),
      color: _navy2,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => labels.entries.map((e) {
        return CheckedPopupMenuItem<_SortKey>(
          value: e.key,
          checked: e.key == _sort,
          child: Text(e.value, style: TextStyle(color: _tp, fontSize: 13)),
        );
      }).toList(),
      child: _toolbarChip(
        icon: Icons.sort_rounded,
        label: labels[_sort] ?? 'ترتيب',
      ),
    );
  }

  Widget _densityMenu() {
    const labels = <_Density, String>{
      _Density.compact: 'متراصّ',
      _Density.comfortable: 'مريح',
      _Density.spacious: 'متّسع',
    };
    const icons = <_Density, IconData>{
      _Density.compact: Icons.density_small_rounded,
      _Density.comfortable: Icons.density_medium_rounded,
      _Density.spacious: Icons.density_large_rounded,
    };
    return PopupMenuButton<_Density>(
      tooltip: 'الكثافة',
      initialValue: _density,
      onSelected: (d) => setState(() => _density = d),
      color: _navy2,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => labels.entries.map((e) {
        return CheckedPopupMenuItem<_Density>(
          value: e.key,
          checked: e.key == _density,
          child: Row(children: [
            Icon(icons[e.key], color: _ts, size: 14),
            const SizedBox(width: 8),
            Text(e.value, style: TextStyle(color: _tp, fontSize: 13)),
          ]),
        );
      }).toList(),
      child: _toolbarChip(
        icon: icons[_density]!,
        label: labels[_density]!,
      ),
    );
  }

  Widget _viewModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _viewModeBtn(_ViewMode.list, Icons.view_list_rounded),
        Container(width: 1, height: 18, color: _bdr),
        _viewModeBtn(_ViewMode.cards, Icons.grid_view_rounded),
      ]),
    );
  }

  Widget _viewModeBtn(_ViewMode m, IconData ic) {
    final active = _viewMode == m;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _viewMode = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _gold.withValues(alpha: 0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(ic, size: 16, color: active ? _gold : _ts),
      ),
    );
  }

  Widget _toolbarChip({
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? _gold.withValues(alpha: 0.14) : _navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? _gold.withValues(alpha: 0.45) : _bdr,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: highlight ? _gold : _ts),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: highlight ? _gold : _tp,
            fontSize: 12,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.expand_more_rounded, size: 14, color: _ts),
      ]),
    );
  }

  // Active filters strip — shows chips with × to remove individually
  Widget _activeFiltersStrip() {
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(_filterChipRemovable(
        label: 'البحث: "$_search"',
        onRemove: () {
          _searchCtrl.clear();
          _onSearchChanged('');
        },
      ));
    }
    if (_datePreset != _DatePreset.all) {
      chips.add(_filterChipRemovable(
        label: 'التاريخ',
        onRemove: () => _applyDatePreset(_DatePreset.all),
      ));
    }
    for (final s in _statusMulti) {
      chips.add(_filterChipRemovable(
        label: _kStatuses[s]?['ar'] as String? ?? s,
        color: _kStatuses[s]?['color'] as Color?,
        onRemove: () => setState(() => _statusMulti.remove(s)),
      ));
    }
    for (final k in _kindMulti) {
      chips.add(_filterChipRemovable(
        label: _kKinds[k] ?? k,
        onRemove: () => setState(() => _kindMulti.remove(k)),
      ));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: _navy2.withValues(alpha: 0.35),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _filterChipRemovable({
    required String label,
    Color? color,
    required VoidCallback onRemove,
  }) {
    final c = color ?? _gold;
    return InputChip(
      label: Text(label, style: TextStyle(color: c, fontSize: 11)),
      backgroundColor: c.withValues(alpha: 0.12),
      side: BorderSide(color: c.withValues(alpha: 0.4)),
      deleteIcon: Icon(Icons.close_rounded, color: c, size: 14),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _bulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: _gold.withValues(alpha: 0.35))),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: _gold, size: 18),
        const SizedBox(width: 8),
        Text('${_selectedIds.length} قيد مُحدَّد',
            style: TextStyle(color: _tp, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            for (final id in _selectedIds.toList()) {
              _post(id);
            }
            setState(_selectedIds.clear);
          },
          icon: Icon(Icons.check_rounded, color: _ok, size: 16),
          label: Text('ترحيل الكل', style: TextStyle(color: _ok)),
        ),
        TextButton.icon(
          onPressed: _exportMenu,
          icon: Icon(Icons.download_rounded, color: _ts, size: 16),
          label: Text('تصدير', style: TextStyle(color: _ts)),
        ),
        TextButton.icon(
          onPressed: () => setState(_selectedIds.clear),
          icon: Icon(Icons.close_rounded, color: _ts, size: 16),
          label: Text('إلغاء', style: TextStyle(color: _ts)),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Wave N — List / Rows: sticky header, select-all, row hover, group
  // ══════════════════════════════════════════════════════════════════
  Widget _list(List<Map<String, dynamic>> visible) {
    final rowPad = switch (_density) {
      _Density.compact => const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      _Density.comfortable => const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      _Density.spacious => const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    };
    final rowFs = _density == _Density.compact ? 11.5 : 12.5;
    final rowGap = _density == _Density.spacious ? 6.0 : 2.0;

    if (_viewMode == _ViewMode.cards) {
      return _cardsView(visible);
    }

    final allSelected = visible.isNotEmpty &&
        visible.every((e) => _selectedIds.contains(e['id']));
    final someSelected = !allSelected && visible.any((e) => _selectedIds.contains(e['id']));

    // Build flat list of items (header + group headers + rows)
    final groups = _groupedEntries(visible);
    final isGrouped = _groupBy != 'none';
    final items = <_ListItem>[];
    items.add(const _ListItem.columnHeader());
    if (!isGrouped) {
      for (final e in visible) {
        items.add(_ListItem.row(e));
      }
    } else {
      for (final g in groups) {
        items.add(_ListItem.groupHeader(g.key, g.label, g.rows));
        if (!_collapsedGroups.contains(g.key)) {
          for (final e in g.rows) {
            items.add(_ListItem.row(e));
          }
        }
      }
    }

    // Horizontal scroll wrapper — when the Quick-Access rail expands,
    // the available width shrinks; rows need to scroll sideways instead
    // of overflowing with a yellow/black warning.
    return Scrollbar(
      thumbVisibility: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 40,
          ),
          child: SizedBox(
            width: 1100, // fixed inner width — accommodates all columns
            child: _buildInnerList(
              items,
              visible: visible,
              allSelected: allSelected,
              someSelected: someSelected,
              rowPad: rowPad,
              rowFs: rowFs,
              rowGap: rowGap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerList(
    List<_ListItem> items, {
    required List<Map<String, dynamic>> visible,
    required bool allSelected,
    required bool someSelected,
    required EdgeInsets rowPad,
    required double rowFs,
    required double rowGap,
  }) {
    return ListView.builder(
      key: const ValueKey('list-view'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item.isGroupHeader) {
          return _groupHeaderRow(
            label: item.groupLabel!,
            rows: item.groupRows!,
            collapsed: _collapsedGroups.contains(item.groupKey),
            onToggle: () => setState(() {
              if (!_collapsedGroups.add(item.groupKey!)) {
                _collapsedGroups.remove(item.groupKey);
              }
            }),
          );
        }
        if (item.isColumnHeader) {
          // Sticky column header
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: rowPad,
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _bdr),
            ),
            child: Row(children: [
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: allSelected,
                  tristate: true,
                  activeColor: _gold,
                  side: BorderSide(color: _bdr),
                  onChanged: (v) {
                    setState(() {
                      if (v == true || someSelected) {
                        for (final e in visible) {
                          _selectedIds.add(e['id'] as String);
                        }
                      } else {
                        _selectedIds.clear();
                      }
                    });
                  },
                ),
              ),
              // Wave R — clickable sortable column headers
              SizedBox(
                width: 130,
                child: _sortableHeader('رقم القيد', _SortKey.numberAsc),
              ),
              SizedBox(
                width: 95,
                child: _sortableHeader('التاريخ', _SortKey.dateDesc,
                    alt: _SortKey.dateAsc),
              ),
              SizedBox(width: 110, child: Text('النوع', style: _th)),
              SizedBox(width: 110, child: Text('الحالة', style: _th)),
              Expanded(child: Text('البيان', style: _th)),
              SizedBox(
                width: 120,
                child: _sortableHeader('مدين', _SortKey.debitDesc,
                    align: TextAlign.end),
              ),
              SizedBox(
                width: 120,
                child: _sortableHeader('دائن', _SortKey.creditDesc,
                    align: TextAlign.end),
              ),
              // Actions column header with the columns toggle (CoA pattern)
              SizedBox(
                width: 130,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('الإجراءات', style: _th),
                    const Spacer(),
                    _columnsToggleButton(),
                  ],
                ),
              ),
            ]),
          );
        }
        // Regular row
        return AnimatedOpacity(
          duration: Duration(milliseconds: 220 + (i * 18).clamp(0, 300)),
          opacity: 1.0,
          child: _row(item.row!, rowPad, rowFs, rowGap),
        );
      },
    );
  }

  Widget _row(Map<String, dynamic> e, EdgeInsets pad, double fs, double gap) {
    final status = (e['status'] ?? 'draft').toString();
    final info = _kStatuses[status] ?? {'ar': status, 'color': _td};
    final debit = asDouble(e['total_debit']);
    final credit = asDouble(e['total_credit']);
    final id = e['id'] as String? ?? '';
    final isSelected = _selectedIds.contains(id);

    return _HoverRow(
      isSelected: isSelected,
      statusColor: info['color'] as Color,
      onTap: () => _showDetail(id),
      onSecondaryTapDown: (details) =>
          _showRowContextMenu(context, details.globalPosition, e),
      child: Padding(
        padding: EdgeInsets.only(top: gap),
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: isSelected
                ? _gold.withValues(alpha: 0.08)
                : _navy2.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _gold.withValues(alpha: 0.45) : _bdr,
            ),
          ),
          child: Row(children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                activeColor: _gold,
                side: BorderSide(color: _bdr),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedIds.add(id);
                    } else {
                      _selectedIds.remove(id);
                    }
                  });
                },
              ),
            ),
            SizedBox(
              width: 130,
              child: _highlightedText(
                (e['je_number'] ?? '').toString(),
                _search,
                TextStyle(
                    color: _gold,
                    fontSize: fs,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace'),
              ),
            ),
            SizedBox(
              width: 95,
              child: Tooltip(
                message: (e['je_date'] ?? '').toString(),
                child: Text(_relativeDate((e['je_date'] ?? '').toString()),
                    style: TextStyle(
                        color: _ts,
                        fontSize: fs - 0.5,
                        fontFamily: 'monospace')),
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(_kKinds[e['kind']] ?? e['kind'] ?? '—',
                  style: TextStyle(color: _ts, fontSize: fs - 0.5),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
                width: 110,
                child: _tag(info['ar'] as String, info['color'] as Color)),
            Expanded(
              child: _highlightedText(
                (e['memo_ar'] ?? '').toString(),
                _search,
                TextStyle(color: _tp, fontSize: fs),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(_fmt(debit),
                  style: TextStyle(
                      color: debit > 0 ? _ok : _td,
                      fontSize: fs,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.end),
            ),
            SizedBox(
              width: 120,
              child: Text(_fmt(credit),
                  style: TextStyle(
                      color: credit > 0 ? _indigo : _td,
                      fontSize: fs,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.end),
            ),
            SizedBox(
              width: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'draft' ||
                      status == 'submitted' ||
                      status == 'approved')
                    _rowIconBtn(
                      tooltip: 'ترحيل',
                      icon: Icons.check_circle_rounded,
                      color: _ok,
                      onTap: () => _post(id),
                    ),
                  if (status == 'posted')
                    _rowIconBtn(
                      tooltip: 'عكس',
                      icon: Icons.undo_rounded,
                      color: _err,
                      onTap: () => _reverse(e),
                    ),
                  _rowIconBtn(
                    tooltip: 'عرض',
                    icon: Icons.visibility_rounded,
                    color: _ts,
                    onTap: () => _showDetail(id),
                  ),
                  _rowIconBtn(
                    tooltip: 'المزيد',
                    icon: Icons.more_horiz_rounded,
                    color: _ts,
                    onTap: () => _showDetail(id),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // Wave R — sortable header cell
  Widget _sortableHeader(String label, _SortKey primary,
      {_SortKey? alt, TextAlign align = TextAlign.start}) {
    final isActivePrimary = _sort == primary;
    final isActiveAlt = alt != null && _sort == alt;
    final isActive = isActivePrimary || isActiveAlt;
    final ascending = alt != null && _sort == alt;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        setState(() {
          if (alt != null && isActivePrimary) {
            _sort = alt;
          } else {
            _sort = primary;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: align == TextAlign.end
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(label,
                style: _th.copyWith(
                  color: isActive ? _gold : _td,
                )),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: _gold,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Wave T — relative date formatting (today / yesterday / N days ago)
  String _relativeDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff == 0) return 'اليوم';
      if (diff == 1) return 'أمس';
      if (diff > 0 && diff < 7) return 'منذ $diff أيام';
      if (diff < 0 && diff > -7) return 'بعد ${-diff} أيام';
      return iso;
    } catch (_) {
      return iso;
    }
  }

  // Wave S — row context menu (right-click / long-press)
  void _showRowContextMenu(BuildContext ctx, Offset pos, Map<String, dynamic> e) async {
    final id = e['id'] as String;
    final status = (e['status'] ?? 'draft').toString();
    final selected = await showMenu<String>(
      context: ctx,
      color: _navy2,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        PopupMenuItem<String>(
          value: 'view',
          child: _ctxMenuRow(Icons.visibility_rounded, 'عرض التفاصيل', _ts),
        ),
        if (status == 'draft' || status == 'submitted' || status == 'approved')
          PopupMenuItem<String>(
            value: 'post',
            child: _ctxMenuRow(Icons.check_circle_rounded, 'ترحيل', _ok),
          ),
        if (status == 'posted')
          PopupMenuItem<String>(
            value: 'reverse',
            child: _ctxMenuRow(Icons.undo_rounded, 'عكس القيد', _err),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'copy-number',
          child: _ctxMenuRow(
              Icons.content_copy_rounded, 'نسخ رقم القيد', _ts),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          child:
              _ctxMenuRow(Icons.copy_all_rounded, 'تكرار (قريباً)', _td),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case 'view':
        _showDetail(id);
        break;
      case 'post':
        _post(id);
        break;
      case 'reverse':
        _reverse(e);
        break;
      case 'copy-number':
        await Clipboard.setData(
            ClipboardData(text: (e['je_number'] ?? '').toString()));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok,
          content: Text('تم نسخ رقم القيد ✓',
              style: TextStyle(color: Colors.white)),
        ));
        break;
    }
  }

  Widget _ctxMenuRow(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: _tp, fontSize: 13)),
    ]);
  }

  // Wave T — search highlight helper (RichText for matching substring)
  Widget _highlightedText(String text, String query, TextStyle base) {
    if (query.isEmpty) {
      return Text(text,
          style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(text,
          style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: [
        TextSpan(text: text.substring(0, idx)),
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: base.copyWith(
            backgroundColor: _gold.withValues(alpha: 0.30),
            color: _gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextSpan(text: text.substring(idx + query.length)),
      ]),
    );
  }

  Widget _rowIconBtn({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  // Odoo-style Kanban card grid view
  Widget _cardsView(List<Map<String, dynamic>> visible) {
    return GridView.builder(
      key: const ValueKey('cards-view'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        childAspectRatio: 2.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final e = visible[i];
        final status = (e['status'] ?? 'draft').toString();
        final info = _kStatuses[status] ?? {'ar': status, 'color': _td};
        final c = info['color'] as Color;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetail(e['id'] as String),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _navy2.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bdr),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _tag(info['ar'] as String, c),
                  const Spacer(),
                  Text(e['je_number'] ?? '',
                      style: TextStyle(
                          color: _gold,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(e['memo_ar'] ?? '—',
                    style: TextStyle(color: _tp, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: _td),
                  const SizedBox(width: 4),
                  Text(e['je_date'] ?? '',
                      style: TextStyle(
                          color: _ts, fontSize: 11, fontFamily: 'monospace')),
                  const Spacer(),
                  Text('مدين ${_fmt(asDouble(e['total_debit']))}',
                      style: TextStyle(
                          color: _ok,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace')),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2)),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════
  // Wave O — Empty / Loading / Error states + animations
  // ══════════════════════════════════════════════════════════════════

  Widget _loadingSkeleton() {
    return ListView.builder(
      key: const ValueKey('skeleton'),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 52,
        decoration: BoxDecoration(
          color: _navy2.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr.withValues(alpha: 0.5)),
        ),
        child: _Shimmer(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Inline panels — لوحة إنشاء قيد يدوي / قراءة مستند ذكاء اصطناعي
  // تحلّ محل قائمة القيود عند الضغط على زر "جديد" أو "ذكاء".
  // ─────────────────────────────────────────────────────────────────────
  Widget _inlinePanelShell({
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      key: ValueKey('inline-${title.hashCode}'),
      color: _navy,
      child: Column(
        children: [
          // Top strip: back button + title
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _navy2,
              border: Border(bottom: BorderSide(color: _bdr)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'رجوع للقائمة',
                  icon: Icon(Icons.arrow_forward_rounded,
                      color: _tp, size: 20),
                  onPressed: () => _closeInline(),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: accent, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: _tp,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _inlineManualPanel() {
    // مهم: لا نُغلّف _JeDialog داخل SingleChildScrollView — فهو يحتوي
    // بالفعل على Expanded ويحتاج bounded height (من Expanded في shell).
    // مُجرَّد Align + ConstrainedBox يوفّر عرض مناسب ويترك الارتفاع للـ shell.
    return _inlinePanelShell(
      title: 'قيد يومية يدوي',
      icon: Icons.edit_note_rounded,
      accent: _gold,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: _JeDialog(
            accounts: _accounts,
            fullScreen: true,
            onSaved: () => _closeInline(reload: true),
            onCancel: () => _closeInline(),
          ),
        ),
      ),
    );
  }

  Widget _inlineAiPanel() {
    return _inlinePanelShell(
      title: 'قراءة مستند بالذكاء الاصطناعي',
      icon: Icons.auto_awesome_rounded,
      accent: core_theme.AC.purple,
      child: _JeAiReader(
        onDone: (ok) => _closeInline(reload: ok),
      ),
    );
  }

  Widget _errorView() => Center(
        key: const ValueKey('error'),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: _err.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _err.withValues(alpha: 0.35)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _err.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: _err, size: 40),
            ),
            const SizedBox(height: 16),
            Text('حدث خطأ',
                style: TextStyle(
                    color: _tp, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ts, fontSize: 12, height: 1.5)),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _err,
                foregroundColor: Colors.white,
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );

  Widget _noResultsView() => Center(
        key: const ValueKey('no-results'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, color: _td, size: 64),
          const SizedBox(height: 14),
          Text('لا توجد نتائج مطابقة',
              style: TextStyle(color: _tp, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('جرّب تعديل الفلاتر أو البحث',
              style: TextStyle(color: _ts, fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _clearAllFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: _tp,
              side: BorderSide(color: _bdr),
            ),
            icon: const Icon(Icons.clear_all_rounded, size: 16),
            label: const Text('مسح الفلاتر'),
          ),
        ]),
      );

  Widget _emptyView() => SingleChildScrollView(
        key: const ValueKey('empty'),
        child: Center(
          child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          tween: Tween(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 12),
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Decorative illustration
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _gold.withValues(alpha: 0.18),
                      _gold.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _gold.withValues(alpha: 0.35), width: 2),
                ),
                child: Icon(Icons.auto_stories_rounded,
                    color: _gold.withValues(alpha: 0.85), size: 46),
              ),
              const SizedBox(height: 16),
              Text('دفتر قيود اليومية فارغ',
                  style: TextStyle(
                      color: _tp,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
              const SizedBox(height: 8),
              Text(
                'ابدأ بتسجيل أول قيد يومي. يمكنك إنشاء قيد يدوي الآن أو\nاستيراد قيود جاهزة من ملف Excel لاحقاً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ts, fontSize: 13, height: 1.7),
              ),
              const SizedBox(height: 22),
              Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: core_theme.AC.btnFg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openInline(_InlineMode.createManual),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('قيد يدوي جديد',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: core_theme.AC.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openInline(_InlineMode.createAi),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('قراءة مستند بالذكاء',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _tp,
                    side: BorderSide(color: _bdr),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _navy3,
                        content: Text('استيراد Excel قيد التطوير',
                            style: TextStyle(color: _tp)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('استيراد'),
                ),
              ]),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: _gold.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text('نصيحة: اضغط N لإنشاء قيد جديد سريعاً',
                      style: TextStyle(
                          color: _gold.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ]),
          ),
        ),
        ),
      );

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

final _th = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ═══════════════════════════════════════════════════════════════════
// Journal-entry create page — full-screen sub-page (not a dialog).
// Offers two flows:
//   1. إنشاء يدوي (Manual) — existing JE builder in full-screen
//   2. قراءة مستند بالذكاء الاصطناعي (AI) — upload a PDF/image, OCR
//      extracts lines, AI proposes debit/credit splits.
// ═══════════════════════════════════════════════════════════════════

enum _CreateMode { choose, manual, ai }

class _JeCreatePage extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  // Optional initial mode — skip the "choose" step and open directly in the
  // selected mode. Used by the list screen's "جديد" and "ذكاء" buttons.
  final _CreateMode initialMode;
  const _JeCreatePage({
    required this.accounts,
    this.initialMode = _CreateMode.choose,
  });
  @override
  State<_JeCreatePage> createState() => _JeCreatePageState();
}

class _JeCreatePageState extends State<_JeCreatePage> {
  late _CreateMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _navy2,
          foregroundColor: _tp,
          elevation: 0,
          leading: IconButton(
            tooltip: 'عودة',
            icon: Icon(Icons.arrow_forward_rounded, color: _tp),
            onPressed: () {
              if (_mode != _CreateMode.choose) {
                setState(() => _mode = _CreateMode.choose);
              } else {
                Navigator.of(context).pop(false);
              }
            },
          ),
          title: Text(
            switch (_mode) {
              _CreateMode.choose => 'إنشاء قيد جديد',
              _CreateMode.manual => 'إنشاء قيد يدوي',
              _CreateMode.ai => 'قراءة مستند بالذكاء الاصطناعي',
            },
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: _bdr, height: 1),
          ),
        ),
        body: switch (_mode) {
          _CreateMode.choose => _buildChoice(),
          _CreateMode.manual => _JeDialog(
              accounts: widget.accounts,
              fullScreen: true,
              onSaved: () => Navigator.of(context).pop(true),
            ),
          _CreateMode.ai => _JeAiReader(
              onDone: (ok) {
                if (ok) {
                  Navigator.of(context).pop(true);
                } else {
                  setState(() => _mode = _CreateMode.choose);
                }
              },
            ),
        },
      ),
    );
  }

  // Choice screen — two large cards side-by-side
  Widget _buildChoice() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'كيف تريد إنشاء القيد؟',
                style: TextStyle(
                  color: _tp,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر طريقة الإنشاء المناسبة',
                style: TextStyle(color: _ts, fontSize: 13),
              ),
              const SizedBox(height: 36),
              LayoutBuilder(builder: (ctx, c) {
                final narrow = c.maxWidth < 680;
                final cards = [
                  _optionCard(
                    icon: Icons.edit_note_rounded,
                    title: 'إنشاء قيد يدوي',
                    subtitle:
                        'أدخل أسطر القيد (مدين/دائن) يدوياً — الطريقة الكلاسيكية',
                    features: const [
                      'تحكم كامل بكل سطر',
                      'تحقّق فوري من التوازن',
                      'حفظ كمسوّدة أو ترحيل مباشر',
                    ],
                    color: _gold,
                    onTap: () => setState(() => _mode = _CreateMode.manual),
                  ),
                  _optionCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'قراءة مستند بالذكاء الاصطناعي',
                    subtitle:
                        'ارفع فاتورة أو إيصالاً — الذكاء الاصطناعي يستخرج الحسابات والمبالغ تلقائياً',
                    features: const [
                      'OCR للفواتير PDF / صور',
                      'اقتراح ذكي للحسابات',
                      'مراجعة قبل الحفظ',
                    ],
                    color: core_theme.AC.purple,
                    badge: 'جديد',
                    onTap: () => setState(() => _mode = _CreateMode.ai),
                  ),
                ];
                return narrow
                    ? Column(
                        children: [
                          for (final card in cards) ...[
                            card,
                            const SizedBox(height: 14),
                          ]
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 18),
                          Expanded(child: cards[1]),
                        ],
                      );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> features,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return _HoverCard(
      onTap: onTap,
      child: (hover) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: hover ? 0.18 : 0.10),
              color.withValues(alpha: hover ? 0.06 : 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hover ? color : color.withValues(alpha: 0.35),
            width: hover ? 1.6 : 1,
          ),
          boxShadow: hover
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: _tp,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: TextStyle(color: _ts, fontSize: 13, height: 1.55),
            ),
            const SizedBox(height: 16),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(color: _tp, fontSize: 12),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 14),
            Row(children: [
              const Spacer(),
              Row(children: [
                Text(
                  'اختر',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_back_rounded, color: color, size: 16),
              ]),
            ]),
          ],
        ),
      ),
    );
  }
}

// Hover detection wrapper — provides a bool `hover` to child builder
class _HoverCard extends StatefulWidget {
  final Widget Function(bool hover) child;
  final VoidCallback onTap;
  const _HoverCard({required this.child, required this.onTap});
  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: widget.child(_hover),
        ),
      ),
    );
  }
}

// AI document-reader page — file picker + OCR stub (wires to backend later)
class _JeAiReader extends StatefulWidget {
  final ValueChanged<bool> onDone;
  const _JeAiReader({required this.onDone});
  @override
  State<_JeAiReader> createState() => _JeAiReaderState();
}

class _JeAiReaderState extends State<_JeAiReader> {
  String? _fileName;
  html.File? _pickedFile;
  bool _processing = false;
  Map<String, dynamic>? _proposal;
  String? _errorMessage;
  Color get _purple => core_theme.AC.purple;

  void _pickFile() {
    final input = html.FileUploadInputElement()
      ..accept = '.pdf,.png,.jpg,.jpeg,.webp';
    input.click();
    input.onChange.listen((_) {
      if (input.files != null && input.files!.isNotEmpty) {
        setState(() {
          _pickedFile = input.files!.first;
          _fileName = _pickedFile!.name;
          _proposal = null;
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _process() async {
    if (_pickedFile == null) return;
    if (!PilotSession.hasEntity) {
      setState(() => _errorMessage = 'اختر الكيان أولاً من شريط العنوان');
      return;
    }
    setState(() {
      _processing = true;
      _errorMessage = null;
      _proposal = null;
    });
    try {
      final r = await pilotClient.aiReadDocument(
        PilotSession.entityId!,
        _pickedFile!,
      );
      if (!mounted) return;
      if (r.success) {
        setState(() {
          _processing = false;
          _proposal = Map<String, dynamic>.from(r.data['data'] as Map);
        });
      } else {
        setState(() {
          _processing = false;
          _errorMessage = r.error ?? 'فشل التحليل';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorMessage = 'خطأ: $e';
      });
    }
  }

  Future<void> _saveProposal() async {
    if (_proposal == null) return;
    final pje = _proposal!['proposed_je'] as Map?;
    if (pje == null) return;
    final extracted = _proposal!['extracted'] as Map? ?? {};
    final lines = (pje['lines'] as List? ?? [])
        .whereType<Map>()
        .map((l) => Map<String, dynamic>.from(l))
        .toList();
    if (lines.isEmpty) {
      setState(() => _errorMessage = 'لا توجد أسطر في الاقتراح');
      return;
    }
    // Build request body matching createJournalEntry schema
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'je_date': (extracted['date'] ??
              DateTime.now().toIso8601String().substring(0, 10))
          .toString(),
      'kind': (pje['kind'] ?? 'manual').toString(),
      'memo_ar': (pje['memo_ar'] ?? '').toString(),
      'lines': [
        for (final l in lines)
          if (l['account_id'] != null)
            {
              'account_id': l['account_id'],
              'debit': (l['debit'] ?? 0).toString(),
              'credit': (l['credit'] ?? 0).toString(),
              if ((l['description'] ?? '').toString().trim().isNotEmpty)
                'description': l['description'].toString(),
            },
      ],
    };
    if ((body['lines'] as List).isEmpty) {
      setState(() => _errorMessage =
          'لم يتمكّن الذكاء من مطابقة الحسابات مع شجرتك. راجع الاقتراح يدوياً.');
      return;
    }
    setState(() => _processing = true);
    final r = await pilotClient.createJournalEntry(body);
    if (!mounted) return;
    setState(() => _processing = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ok,
        content: Text('تم حفظ القيد المقترح ✓',
            style: TextStyle(color: Colors.white)),
      ));
      widget.onDone(true);
    } else {
      setState(() => _errorMessage = r.error ?? 'فشل الحفظ');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Once a proposal is ready, show review panel instead of the picker.
    if (_proposal != null) return _buildReviewPanel(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _purple.withValues(alpha: 0.22),
                      _purple.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                      color: _purple.withValues(alpha: 0.45), width: 2),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: _purple, size: 48),
              ),
              const SizedBox(height: 18),
              Text(
                'ارفع فاتورة أو إيصالاً',
                style: TextStyle(
                    color: _tp,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'الذكاء الاصطناعي سيقرأ المستند ويقترح قيداً تلقائياً (مدين/دائن)\nيدعم PDF · PNG · JPG',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ts, fontSize: 13, height: 1.7),
              ),
              const SizedBox(height: 24),
              // Drop zone / picker
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: DottedBorder(
                  color: _fileName == null
                      ? _bdr
                      : _purple.withValues(alpha: 0.5),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 28),
                    decoration: BoxDecoration(
                      color: _navy2.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      Icon(
                        _fileName == null
                            ? Icons.cloud_upload_outlined
                            : Icons.description_rounded,
                        color: _fileName == null ? _td : _purple,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _fileName ?? 'اضغط أو اسحب الملف هنا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _fileName == null ? _ts : _purple,
                          fontSize: 13,
                          fontWeight: _fileName == null
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _fileName == null || _processing
                        ? null
                        : _process,
                    icon: _processing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  Colors.white),
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      _processing
                          ? 'جاري التحليل…'
                          : 'تحليل بالذكاء الاصطناعي',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => widget.onDone(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _tp,
                    side: BorderSide(color: _bdr),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                  ),
                  child: const Text('إلغاء'),
                ),
              ]),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _err.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _err.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded,
                        color: _err, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(color: _err, fontSize: 12)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: _td),
                  const SizedBox(width: 4),
                  Text(
                    'يعمل بـ Claude Sonnet 4 (vision) — راجع الاقتراح قبل الحفظ',
                    style: TextStyle(
                        color: _td,
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // Review panel — shows extracted data + proposed JE with editable memo,
  // lets user save directly OR cancel and retry.
  Widget _buildReviewPanel(BuildContext context) {
    final p = _proposal!;
    final extracted = (p['extracted'] as Map?) ?? {};
    final pje = (p['proposed_je'] as Map?) ?? {};
    final lines = (pje['lines'] as List?) ?? [];
    final confidence = (p['confidence'] as num?)?.toDouble() ?? 0.0;
    final isMock = p['_mock'] == true;
    final warnings = (p['warnings'] as List?)?.cast<String>() ?? <String>[];

    double totalDebit = 0;
    double totalCredit = 0;
    for (final l in lines) {
      if (l is Map) {
        totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
        totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
      }
    }
    final balanced = (totalDebit - totalCredit).abs() < 0.005 && totalDebit > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _purple.withValues(alpha: 0.15),
                _purple.withValues(alpha: 0.04),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: _purple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('اقتراح الذكاء الاصطناعي',
                        style: TextStyle(
                            color: _tp,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    Text(
                      'مستند: $_fileName',
                      style: TextStyle(color: _ts, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (confidence > 0.7 ? _ok : _warn)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: (confidence > 0.7 ? _ok : _warn)
                          .withValues(alpha: 0.4)),
                ),
                child: Text(
                  'ثقة ${(confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: confidence > 0.7 ? _ok : _warn,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ),
          if (isMock) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _warn.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _warn, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'وضع تجريبي — عيّن ANTHROPIC_API_KEY في backend للحصول على تحليل حقيقي.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          // Extracted data
          _sectionCard(
            title: 'البيانات المستخرجة',
            icon: Icons.fact_check_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('الطرف', extracted['vendor']?.toString() ?? '—'),
                _kv('التاريخ', extracted['date']?.toString() ?? '—'),
                _kv('رقم المستند',
                    extracted['document_number']?.toString() ?? '—'),
                _kv('الوصف', extracted['description']?.toString() ?? '—'),
                _kv('المبلغ',
                    '${extracted['amount'] ?? 0} ${extracted['currency'] ?? ""}'),
                if ((extracted['tax_amount'] as num?) != null &&
                    (extracted['tax_amount'] as num) > 0)
                  _kv('VAT', '${extracted['tax_amount']}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Proposed JE lines
          _sectionCard(
            title: 'القيد المقترح',
            icon: Icons.edit_note_rounded,
            child: Column(children: [
              _kv('البيان', (pje['memo_ar'] ?? '').toString()),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _bdr),
                ),
                child: Column(children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(flex: 2, child: Text('الحساب', style: _th)),
                      Expanded(child: Text('مدين', style: _th, textAlign: TextAlign.end)),
                      Expanded(child: Text('دائن', style: _th, textAlign: TextAlign.end)),
                    ]),
                  ),
                  for (final l in lines)
                    if (l is Map) _lineReviewRow(l),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: balanced
                          ? _ok.withValues(alpha: 0.08)
                          : _warn.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        balanced
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: balanced ? _ok : _warn,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        balanced
                            ? 'متوازن (مدين = دائن)'
                            : 'غير متوازن — فرق ${(totalDebit - totalCredit).abs().toStringAsFixed(2)}',
                        style: TextStyle(
                            color: balanced ? _ok : _warn,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text('مدين ${totalDebit.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: _ok,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace')),
                      const SizedBox(width: 10),
                      Text('دائن ${totalCredit.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: core_theme.AC.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace')),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionCard(
              title: 'تحذيرات',
              icon: Icons.warning_amber_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $w',
                          style: TextStyle(color: _warn, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _err.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _err.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: _err, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_errorMessage!,
                      style: TextStyle(color: _err, fontSize: 12)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _proposal = null;
                _errorMessage = null;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: _tp,
                side: BorderSide(color: _bdr),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('ارفع مستنداً آخر'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => widget.onDone(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _tp,
                side: BorderSide(color: _bdr),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              child: const Text('إلغاء'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: (_processing || !balanced) ? null : _saveProposal,
              style: FilledButton.styleFrom(
                backgroundColor: _ok,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
              ),
              icon: _processing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: const Text('حفظ القيد',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _sectionCard(
      {required String title,
      required IconData icon,
      required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _gold, size: 15),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: _tp,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(k, style: TextStyle(color: _td, fontSize: 11)),
        ),
        Expanded(
          child: Text(v, style: TextStyle(color: _tp, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _lineReviewRow(Map l) {
    final code = (l['account_code'] ?? '').toString();
    final name = (l['account_name_resolved'] ?? l['account_name'] ?? '—').toString();
    final debit = (l['debit'] as num?)?.toDouble() ?? 0;
    final credit = (l['credit'] as num?)?.toDouble() ?? 0;
    final unmatched = l['account_id'] == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _bdr.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Row(children: [
            if (code.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(code,
                    style: TextStyle(
                        color: _gold,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                    color: unmatched ? _warn : _tp, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unmatched) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'الحساب غير موجود في الشجرة',
                child: Icon(Icons.warning_amber_rounded,
                    size: 12, color: _warn),
              ),
            ],
          ]),
        ),
        Expanded(
          child: Text(
            debit > 0 ? debit.toStringAsFixed(2) : '—',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: debit > 0 ? _ok : _td,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            credit > 0 ? credit.toStringAsFixed(2) : '—',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: credit > 0 ? core_theme.AC.purple : _td,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
    );
  }
}

// Simple dotted border helper (for drag-drop look)
class DottedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  const DottedBorder({super.key, required this.child, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5, style: BorderStyle.solid),
      ),
      child: child,
    );
  }
}

// Unified list item for the grouped list view
class _ListItem {
  final Map<String, dynamic>? row;
  final String? groupKey;
  final String? groupLabel;
  final List<Map<String, dynamic>>? groupRows;
  final bool isColumnHeader;
  const _ListItem._({
    this.row,
    this.groupKey,
    this.groupLabel,
    this.groupRows,
    this.isColumnHeader = false,
  });
  const _ListItem.columnHeader() : this._(isColumnHeader: true);
  const _ListItem.row(Map<String, dynamic> r) : this._(row: r);
  const _ListItem.groupHeader(
      String key, String label, List<Map<String, dynamic>> rows)
      : this._(groupKey: key, groupLabel: label, groupRows: rows);
  bool get isGroupHeader => groupKey != null;
}

// ═══════════════════════════════════════════════════════════════════
// Keyboard shortcut intents
// ═══════════════════════════════════════════════════════════════════
class _NewEntryIntent extends Intent {
  const _NewEntryIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ClearFiltersIntent extends Intent {
  const _ClearFiltersIntent();
}

// ═══════════════════════════════════════════════════════════════════
// Small header icon button with tooltip + elevated style
// ═══════════════════════════════════════════════════════════════════
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _navy3.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bdr),
          ),
          child: Icon(icon, color: _tp, size: 18),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Stat card — live totals in header (Fiori Object Page pattern)
// ═══════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween(begin: 0.9, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _td,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shortcut help row
// ═══════════════════════════════════════════════════════════════════
class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String desc;
  const _ShortcutRow({required this.shortcut, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _bdr.withValues(alpha: 0.7)),
          ),
          child: Text(
            shortcut,
            style: TextStyle(
              color: _tp,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(desc, style: TextStyle(color: _ts, fontSize: 13)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Hover row — adds hover lift + left accent bar colored by status
// ═══════════════════════════════════════════════════════════════════
class _HoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final Color statusColor;
  const _HoverRow({
    required this.child,
    required this.onTap,
    this.onSecondaryTapDown,
    required this.isSelected,
    required this.statusColor,
  });
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Stack(children: [
        // Left accent bar (status color)
        if (_hover || widget.isSelected)
          PositionedDirectional(
            start: 0,
            top: 10,
            bottom: 10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 3,
              decoration: BoxDecoration(
                color: widget.statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: _hover ? 1.002 : 1.0,
            child: widget.child,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shimmer placeholder animation — for loading skeleton rows
// ═══════════════════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return ShaderMask(
          shaderCallback: (r) => LinearGradient(
            begin: Alignment(-1.5 + 3 * t, 0),
            end: Alignment(-0.5 + 3 * t, 0),
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(r),
          child: Container(color: Colors.white),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// JE Create Dialog
// ══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────
// _JeLine — سطر واحد في القيد. يدعم أبعاداً متعدّدة (شريك، مركز تكلفة،
// VAT code) تتفوّق على Odoo/NetSuite.
// استخدام controllers لضمان تزامن الحالة بين UI و state عبر عمليات
// الإعادة (خصوصاً عند الـ auto-clear بين مدين/دائن).
// ─────────────────────────────────────────────────────────────────────
class _JeLine {
  String? accountId;
  double debit = 0;
  double credit = 0;
  String description = '';
  // Enterprise dimensions (اختيارية — تظهر حسب إعدادات عرض الأعمدة)
  String partner = '';      // المورد/العميل المرتبط بالسطر
  String analytic = '';     // مركز التكلفة / المشروع / الفرع
  String taxCode = '';      // رمز ضريبة (VAT15, ZERO, EXEMPT)
  // AI hints (for AI-filled lines)
  String aiHint = '';
  double aiMatchConfidence = 0;
  // Controllers تضمن تزامن النص مع الحالة — لا حاجة لإعادة إنشائها
  final TextEditingController debitCtrl = TextEditingController();
  final TextEditingController creditCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController partnerCtrl = TextEditingController();
  final TextEditingController analyticCtrl = TextEditingController();
  _JeLine();

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
    descCtrl.dispose();
    partnerCtrl.dispose();
    analyticCtrl.dispose();
  }
}

class _JeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  // When true, renders inside a Scaffold page (no Dialog chrome). Used
  // by the full-screen _JeCreatePage.
  final bool fullScreen;
  // Called on successful save when embedded in a full-screen flow.
  final VoidCallback? onSaved;
  // Called when user cancels/backs out while embedded (inline panel mode).
  // When null and fullScreen=true, caller relies on Navigator.pop.
  final VoidCallback? onCancel;
  const _JeDialog({
    required this.accounts,
    this.fullScreen = false,
    this.onSaved,
    this.onCancel,
  });
  @override
  State<_JeDialog> createState() => _JeDialogState();
}

class _JeDialogState extends State<_JeDialog> {
  DateTime _date = DateTime.now();
  final _memo = TextEditingController();
  final _reference = TextEditingController(); // الرقم المرجعي (مثل INV-123)
  final _notes = TextEditingController();     // ملاحظات داخلية
  String _kind = 'manual';
  bool _autoPost = true;  // ترحيل مباشر كافتراضي — حتى يظهر في التقارير المالية فوراً
  bool _autoReverse = false;
  DateTime? _reverseDate;
  final List<_JeLine> _lines = [_JeLine(), _JeLine()];
  bool _loading = false;
  String? _error;

  // ── Odoo-beating features ──────────────────────────────────────
  int _tabIndex = 0; // 0=items, 1=extra info, 2=notes/attachments
  // Column visibility (enterprise dimensions)
  bool _showPartner = false;
  bool _showAnalytic = false;
  bool _showTaxCode = false;
  // Header-level tax mode (Xero-inspired)
  String _taxMode = 'none'; // none | inclusive | exclusive

  // ── AI integrations inside the manual form ──────────────────────
  bool _aiDocLoading = false;      // قراءة مستند جارية
  bool _aiMemoLoading = false;     // اقتراح بيان جارٍ
  String? _aiDocFilename;          // اسم الملف الذي قُرئ
  double? _aiDocConfidence;        // درجة ثقة القراءة
  List<String> _aiWarnings = const [];

  @override
  void dispose() {
    _memo.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _totalDebit => _lines.fold(0.0, (t, l) => t + l.debit);
  double get _totalCredit => _lines.fold(0.0, (t, l) => t + l.credit);
  double get _difference => _totalDebit - _totalCredit;

  Future<void> _pickAccount(int i) async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text('اختر حساباً', style: TextStyle(color: _tp)),
          content: SizedBox(
            width: 500,
            height: 500,
            child: ListView(
              children: widget.accounts
                  .where((a) => a['type'] == 'detail')
                  .map((a) => ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(a['code'] ?? '',
                              style: TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700)),
                        ),
                        title: Text(a['name_ar'] ?? '',
                            style: TextStyle(
                                color: _tp, fontSize: 12)),
                        subtitle: Text(
                            '${a['category']} · ${a['normal_balance']}',
                            style: TextStyle(
                                color: _td, fontSize: 10)),
                        onTap: () => Navigator.pop(context, a),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _lines[i].accountId = selected['id']);
  }

  // ───────────────────────────────────────────────────────────────────
  // AI — قراءة مستند (فاتورة/إيصال) وتعبئة النموذج تلقائياً
  // ───────────────────────────────────────────────────────────────────
  Future<void> _aiReadDocumentIntoForm() async {
    if (!PilotSession.hasEntity) {
      setState(() => _error = 'اختر الكيان أولاً من شريط العنوان');
      return;
    }
    // 1) فتح نافذة اختيار الملف
    final input = html.FileUploadInputElement()
      ..accept = '.pdf,.png,.jpg,.jpeg,.webp';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;

    // 2) استدعاء الـ backend
    setState(() {
      _aiDocLoading = true;
      _aiDocFilename = file.name;
      _error = null;
      _aiWarnings = const [];
    });
    final r = await pilotClient.aiReadDocument(PilotSession.entityId!, file);
    if (!mounted) return;
    setState(() => _aiDocLoading = false);

    if (!r.success) {
      setState(() {
        _error = r.error ?? 'فشل استخراج القيد من المستند';
        _aiDocFilename = null;
      });
      return;
    }

    // 3) استخراج البيانات وتعبئة النموذج
    final Map data = r.data as Map? ?? {};
    final inner = data['data'] as Map? ?? {};
    final extracted = inner['extracted'] as Map? ?? {};
    final pje = inner['proposed_je'] as Map? ?? {};
    final confidence = (inner['confidence'] as num?)?.toDouble() ?? 0.0;
    final warnings = ((inner['warnings'] as List?) ?? const [])
        .map((w) => w.toString())
        .toList();

    // Header fields
    final memo = (pje['memo_ar'] ?? extracted['description'] ?? '').toString();
    if (memo.isNotEmpty) _memo.text = memo;
    final docNum = (extracted['document_number'] ?? '').toString();
    if (docNum.isNotEmpty) _reference.text = docNum;
    final dateStr = (extracted['date'] ?? '').toString();
    final parsedDate = DateTime.tryParse(dateStr);
    if (parsedDate != null) _date = parsedDate;
    final kind = (pje['kind'] ?? 'manual').toString();
    if (['manual', 'adjusting', 'opening', 'closing'].contains(kind)) {
      _kind = kind;
    }

    // Lines — نبني قائمة جديدة من AI
    final aiLines = (pje['lines'] as List?) ?? const [];
    final newLines = <_JeLine>[];
    for (final raw in aiLines) {
      if (raw is! Map) continue;
      final ln = _JeLine();
      final accId = raw['account_id'];
      if (accId is String && accId.isNotEmpty) ln.accountId = accId;
      ln.debit = double.tryParse('${raw['debit'] ?? 0}') ?? 0;
      ln.credit = double.tryParse('${raw['credit'] ?? 0}') ?? 0;
      ln.description = (raw['description'] as String?) ?? '';
      ln.aiHint = (raw['account_name'] as String?) ?? '';
      ln.aiMatchConfidence =
          (raw['match_confidence'] as num?)?.toDouble() ?? 0;
      // Partner suggestion from extracted vendor
      final vendor = (extracted['vendor'] as String?) ?? '';
      if (vendor.isNotEmpty && ln.partner.isEmpty) ln.partner = vendor;
      // Sync controllers so UI shows the AI-filled values
      if (ln.debit > 0) ln.debitCtrl.text = ln.debit.toStringAsFixed(2);
      if (ln.credit > 0) ln.creditCtrl.text = ln.credit.toStringAsFixed(2);
      if (ln.description.isNotEmpty) ln.descCtrl.text = ln.description;
      if (ln.partner.isNotEmpty) ln.partnerCtrl.text = ln.partner;
      newLines.add(ln);
    }
    while (newLines.length < 2) {
      newLines.add(_JeLine());
    }

    // Dispose old line controllers (we replaced with new _JeLine instances)
    for (final oldLn in _lines) {
      oldLn.dispose();
    }

    setState(() {
      _lines
        ..clear()
        ..addAll(newLines);
      _aiDocConfidence = confidence;
      _aiWarnings = warnings;
      // فعّل عمود الشريك تلقائياً إن استخرج AI المورد
      if ((extracted['vendor'] ?? '').toString().isNotEmpty) {
        _showPartner = true;
      }
    });

    // 4) إشعار نجاح
    if (mounted) {
      final pct = (confidence * 100).toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: confidence >= 0.7 ? _ok : _warn,
        content: Text(
          'تم استخراج القيد من "${file.name}" — ثقة $pct% · راجع قبل الحفظ',
        ),
      ));
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // AI — اقتراح بيان (memo) تلقائي من السطور الحالية
  // ───────────────────────────────────────────────────────────────────
  Future<void> _aiSuggestMemo() async {
    // يلزم سطران صالحان على الأقل
    final validLines = _lines
        .where((l) => l.accountId != null && (l.debit > 0 || l.credit > 0))
        .toList();
    if (validLines.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _warn,
        content: const Text(
            'أدخل على الأقل سطرين بحسابات ومبالغ ليقترح AI البيان'),
      ));
      return;
    }
    setState(() {
      _aiMemoLoading = true;
      _error = null;
    });
    // نُرفق code + name للحساب (يساعد AI)
    final linesPayload = validLines.map((l) {
      final acc = widget.accounts.firstWhere(
        (a) => a['id'] == l.accountId,
        orElse: () => {},
      );
      return {
        'account_id': l.accountId,
        if (acc.isNotEmpty) 'account_code': acc['code'],
        if (acc.isNotEmpty) 'account_name': acc['name_ar'],
        'debit': l.debit,
        'credit': l.credit,
        if (l.description.isNotEmpty) 'description': l.description,
      };
    }).toList();

    final r = await pilotClient.aiSuggestMemo(
      lines: linesPayload,
      kind: _kind,
      reference: _reference.text.trim(),
      date: _date.toIso8601String().substring(0, 10),
    );
    if (!mounted) return;
    setState(() => _aiMemoLoading = false);

    if (!r.success) {
      setState(() => _error = r.error ?? 'فشل اقتراح البيان');
      return;
    }
    final data = r.data as Map? ?? {};
    final suggested = (data['suggested_memo'] ?? '').toString().trim();
    if (suggested.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _warn,
        content: const Text('AI لم يُرجع اقتراحاً — حاول مرة أخرى'),
      ));
      return;
    }
    final conf = (data['confidence'] as num?)?.toDouble() ?? 0.7;
    setState(() => _memo.text = suggested);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ok,
        content: Text(
            'تم اقتراح بيان بثقة ${(conf * 100).toStringAsFixed(0)}% — عدّله إن أردت'),
      ));
    }
  }

  Future<void> _submit() async {
    if (_memo.text.trim().isEmpty) {
      setState(() => _error = 'أدخل بياناً للقيد');
      return;
    }
    final validLines = _lines
        .where((l) => l.accountId != null && (l.debit > 0 || l.credit > 0))
        .toList();
    if (validLines.length < 2) {
      setState(() => _error = 'يلزم سطران على الأقل');
      return;
    }
    if ((_difference).abs() > 0.01) {
      setState(() =>
          _error = 'المدين لا يساوي الدائن (الفرق: ${_difference.toStringAsFixed(2)})');
      return;
    }
    for (final l in validLines) {
      if (l.debit > 0 && l.credit > 0) {
        setState(() =>
            _error = 'كل سطر يجب أن يكون إما مدين أو دائن (ليس كلاهما)');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'kind': _kind,
      'je_date': _date.toIso8601String().substring(0, 10),
      'memo_ar': _memo.text.trim(),
      'auto_post': _autoPost,
      if (_reference.text.trim().isNotEmpty)
        'source_reference': _reference.text.trim(),
      'lines': validLines
          .map((l) => {
                'account_id': l.accountId,
                'debit': l.debit.toString(),
                'credit': l.credit.toString(),
                if (l.description.trim().isNotEmpty)
                  'description': l.description.trim(),
                // Enterprise dimensions — تُحفظ كميتاداتا في description إذا لم
                // يكن backend يدعم الحقول بعد (forward-compatible)
                if (l.partner.trim().isNotEmpty) 'partner_hint': l.partner.trim(),
                if (l.analytic.trim().isNotEmpty) 'analytic_hint': l.analytic.trim(),
                if (l.taxCode.trim().isNotEmpty) 'tax_code': l.taxCode.trim(),
              })
          .toList(),
    };
    final r = await pilotClient.createJournalEntry(body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      if (widget.fullScreen) {
        widget.onSaved?.call();
      } else {
        Navigator.pop(context, true);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok,
          content: Text(_autoPost
              ? 'تم إنشاء القيد وترحيله ✓'
              : 'تم إنشاء القيد (مسودّة) ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD — تصميم يتفوق على Odoo/NetSuite/Xero (عربي RTL-first)
  // ────────────────────────────────────────────────────────────────────
  // الميزات الرئيسية:
  //   • 3 tabs: عناصر القيد / معلومات إضافية / ملاحظات
  //   • أعمدة ديناميكية: شريك، مركز تكلفة، رمز ضريبة (toggle)
  //   • Header-level tax mode (Xero-inspired)
  //   • Sticky totals meter مع ألوان حيّة
  //   • Action bar مع زرّين: حفظ مسودّة / حفظ + ترحيل
  //   • Auto-reverse schedule (accruals)
  //   • Status chip واضح
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final balanced = _difference.abs() < 0.01 && _totalDebit > 0;
    final form = _buildFormContent(balanced);
    // Inline (fullScreen) mode: return raw content; parent provides shell
    if (widget.fullScreen) {
      return form;
    }
    // Dialog mode: wrap with AlertDialog
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: _navy2,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
          child: form,
        ),
      ),
    );
  }

  Widget _buildFormContent(bool balanced) {
    // يجب ألا نستخدم MainAxisSize.min مع Expanded — يُسبب render error.
    // Column هنا يتمدّد لملء الأبّ (Dialog height constraint أو Expanded من
    // inline panel shell)، والـ Expanded(child: _bodyScrollable) يأخذ
    // المساحة المتبقية بين الـ status strip والـ action bar.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: _navy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusStripNew(),
            Expanded(child: _bodyScrollable()),
            _footerActionBar(balanced),
          ],
        ),
      ),
    );
  }

  // ─── Status strip — رقم القيد + شارة الحالة ───
  Widget _statusStripNew() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        // Status chip (Draft)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _autoPost
                ? _ok.withValues(alpha: 0.15)
                : _td.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: (_autoPost ? _ok : _td).withValues(alpha: 0.5),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _autoPost
                  ? Icons.check_circle_outline_rounded
                  : Icons.edit_note_rounded,
              size: 12,
              color: _autoPost ? _ok : _td,
            ),
            const SizedBox(width: 4),
            Text(
              _autoPost ? 'سيُرحَّل' : 'مسودّة',
              style: TextStyle(
                color: _autoPost ? _ok : _ts,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // JE number / new indicator
        Expanded(
          child: Row(children: [
            Text(
              'قيد يومية',
              style: TextStyle(
                color: _td,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left_rounded, color: _td, size: 14),
            const SizedBox(width: 6),
            Text(
              'جديد',
              style: TextStyle(
                color: _tp,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            // Tax mode chip (Xero-inspired)
            _taxModeBadge(),
          ]),
        ),
      ]),
    );
  }

  Widget _taxModeBadge() {
    if (_taxMode == 'none') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: core_theme.AC.purple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: core_theme.AC.purple.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        _taxMode == 'inclusive' ? 'شامل VAT' : 'باستثناء VAT',
        style: TextStyle(
          color: core_theme.AC.purple,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── Body (scrollable) — الحقول + التبويبات + السطور ───
  Widget _bodyScrollable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiQuickBar(),
          _aiWarningsStrip(),
          const SizedBox(height: 10),
          _headerFieldsRow(),
          const SizedBox(height: 14),
          _narrationField(),
          const SizedBox(height: 18),
          _tabBarStrip(),
          const SizedBox(height: 10),
          // Tab content
          if (_tabIndex == 0) _itemsTab(),
          if (_tabIndex == 1) _extraInfoTab(),
          if (_tabIndex == 2) _notesTab(),
          const SizedBox(height: 14),
          _totalsMeter(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _errorStrip(),
          ],
        ],
      ),
    );
  }

  // ─── Header fields — journal / date / reference ───
  Widget _headerFieldsRow() {
    return Row(children: [
      Expanded(
        child: _field(
          label: 'دفتر اليومية',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _kind,
                isExpanded: true,
                dropdownColor: _navy2,
                style: TextStyle(color: _tp, fontSize: 12),
                icon: Icon(Icons.expand_more_rounded, color: _ts),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('يدوي عام')),
                  DropdownMenuItem(value: 'adjusting', child: Text('قيد تسوية')),
                  DropdownMenuItem(value: 'opening', child: Text('قيد افتتاحي')),
                  DropdownMenuItem(value: 'closing', child: Text('قيد إقفال')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 'manual'),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _field(
          label: 'تاريخ المحاسبة',
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365 * 3)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _navy3,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _bdr),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, color: _gold, size: 14),
                const SizedBox(width: 8),
                Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: _tp,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _field(
          label: 'الرقم المرجعي',
          child: TextField(
            controller: _reference,
            style: TextStyle(color: _tp, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'INV-123 (اختياري)',
              hintStyle: TextStyle(color: _td, fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: _navy3,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _narrationField() {
    return _field(
      label: 'البيان *',
      child: TextField(
        controller: _memo,
        style: TextStyle(color: _tp, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'مثال: رسوم بنكية شهرية — بنك الراجحي',
          hintStyle: TextStyle(color: _td, fontSize: 12),
          isDense: true,
          filled: true,
          fillColor: _navy3,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          // زر ✨ يقترح البيان من السطور بالذكاء الاصطناعي
          suffixIcon: Tooltip(
            message: 'اقترح بياناً بالذكاء الاصطناعي من السطور',
            child: InkWell(
              onTap: _aiMemoLoading ? null : _aiSuggestMemo,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.all(4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: core_theme.AC.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: core_theme.AC.purple.withValues(alpha: 0.45),
                  ),
                ),
                child: _aiMemoLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            core_theme.AC.purple,
                          ),
                        ),
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 14, color: core_theme.AC.purple),
                        const SizedBox(width: 4),
                        Text(
                          'اكتب',
                          style: TextStyle(
                            color: core_theme.AC.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ]),
              ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _bdr),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _bdr),
          ),
        ),
      ),
    );
  }

  // ─── AI Quick Bar — شريط أعلى النموذج مع زر قراءة المستند ───
  Widget _aiQuickBar() {
    final hasDoc = _aiDocFilename != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            core_theme.AC.purple.withValues(alpha: 0.14),
            _gold.withValues(alpha: 0.06),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.purple.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: core_theme.AC.purple, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasDoc
                    ? 'قُرئ من: $_aiDocFilename · ثقة ${((_aiDocConfidence ?? 0) * 100).toStringAsFixed(0)}%'
                    : 'ابدأ من مستند بالذكاء الاصطناعي',
                style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasDoc
                    ? 'تمّت تعبئة الحقول والسطور — راجع قبل الحفظ'
                    : 'ارفع فاتورة / إيصال / PDF — Claude يستخرج الحقول والسطور تلقائياً',
                style: TextStyle(color: _ts, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: core_theme.AC.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          onPressed: _aiDocLoading ? null : _aiReadDocumentIntoForm,
          icon: _aiDocLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  hasDoc ? Icons.refresh_rounded : Icons.upload_file_rounded,
                  size: 15,
                ),
          label: Text(
            _aiDocLoading
                ? 'جاري القراءة...'
                : (hasDoc ? 'إعادة القراءة' : 'قراءة مستند'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  // ─── AI warnings strip (يظهر تحت toolbar عند وجود تحذيرات) ───
  Widget _aiWarningsStrip() {
    if (_aiWarnings.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warn.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _aiWarnings
            .map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: _warn, size: 12),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w,
                          style: TextStyle(
                              color: _warn, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── Tabs ───
  Widget _tabBarStrip() {
    Widget tab(int idx, String label, IconData icon) {
      final active = _tabIndex == idx;
      return InkWell(
        onTap: () => setState(() => _tabIndex = idx),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _gold.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? _gold.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: active ? _gold : _ts),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? _gold : _ts,
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        tab(0, 'عناصر القيد', Icons.list_alt_rounded),
        const SizedBox(width: 4),
        tab(1, 'معلومات إضافية', Icons.tune_rounded),
        const SizedBox(width: 4),
        tab(2, 'ملاحظات', Icons.sticky_note_2_outlined),
      ]),
    );
  }

  // ─── Tab 1: السطور ───
  Widget _itemsTab() {
    return Column(children: [
      // Toolbar row: column toggles + add line
      Row(children: [
        _colToggle('الشريك', Icons.person_rounded, _showPartner,
            (v) => setState(() => _showPartner = v)),
        const SizedBox(width: 6),
        _colToggle('مركز التكلفة', Icons.account_tree_rounded, _showAnalytic,
            (v) => setState(() => _showAnalytic = v)),
        const SizedBox(width: 6),
        _colToggle('رمز ضريبة', Icons.receipt_long_rounded, _showTaxCode,
            (v) => setState(() => _showTaxCode = v)),
        const Spacer(),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: _gold,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          onPressed: () => setState(() => _lines.add(_JeLine())),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text('إضافة سطر',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      // Grid
      Container(
        decoration: BoxDecoration(
          color: _navy2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr),
        ),
        child: Column(children: [
          _linesHeader(),
          ..._lines.asMap().entries.map((e) => _lineRow(e.key, e.value)),
        ]),
      ),
    ]);
  }

  Widget _colToggle(
      String label, IconData icon, bool active, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!active),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? core_theme.AC.purple.withValues(alpha: 0.12)
              : _navy3.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? core_theme.AC.purple.withValues(alpha: 0.5)
                : _bdr,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? Icons.visibility_rounded : Icons.visibility_off_outlined,
              size: 12, color: active ? core_theme.AC.purple : _td),
          const SizedBox(width: 4),
          Icon(icon, size: 12, color: active ? core_theme.AC.purple : _ts),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? core_theme.AC.purple : _ts,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _linesHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _navy3.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Text('#', style: _th)),
        Expanded(flex: 3, child: Text('الحساب', style: _th)),
        if (_showPartner)
          Expanded(flex: 2, child: Text('الشريك', style: _th)),
        Expanded(flex: 3, child: Text('البيان', style: _th)),
        if (_showAnalytic)
          Expanded(flex: 2, child: Text('مركز التكلفة', style: _th)),
        if (_showTaxCode) SizedBox(width: 80, child: Text('ضريبة', style: _th)),
        SizedBox(
            width: 100, child: Text('مدين', style: _th, textAlign: TextAlign.end)),
        SizedBox(
            width: 100, child: Text('دائن', style: _th, textAlign: TextAlign.end)),
        const SizedBox(width: 32),
      ]),
    );
  }

  // ─── Tab 2: معلومات إضافية ───
  Widget _extraInfoTab() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tax mode (Xero-inspired)
          Text(
            'وضع الضريبة (يُطبَّق على كل السطور)',
            style: TextStyle(
                color: _td, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _taxPill('none', 'بدون ضريبة'),
            _taxPill('exclusive', 'المبالغ قبل VAT'),
            _taxPill('inclusive', 'المبالغ شاملة VAT'),
          ]),
          const SizedBox(height: 16),
          // Auto-reverse (accruals pattern)
          Row(children: [
            Switch.adaptive(
              value: _autoReverse,
              activeColor: _gold,
              onChanged: (v) => setState(() => _autoReverse = v),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'عكس تلقائي (Auto-Reverse)',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _autoReverse
                        ? 'سيُنشأ قيد عكسي في التاريخ المحدَّد تلقائياً'
                        : 'مفيد للاستحقاقات (Accruals) — قيد ثم عكسه في فترة لاحقة',
                    style: TextStyle(color: _ts, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
          if (_autoReverse) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _reverseDate ??
                      _date.add(const Duration(days: 30)),
                  firstDate: _date,
                  lastDate: _date.add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _reverseDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _navy3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _bdr),
                ),
                child: Row(children: [
                  Icon(Icons.event_repeat_rounded, color: _gold, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _reverseDate == null
                        ? 'اختر تاريخ العكس'
                        : 'تاريخ العكس: ${_reverseDate!.year}-${_reverseDate!.month.toString().padLeft(2, '0')}-${_reverseDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(color: _tp, fontSize: 12),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Auto-post toggle (was at bottom originally)
          Row(children: [
            Switch.adaptive(
              value: _autoPost,
              activeColor: _ok,
              onChanged: (v) => setState(() => _autoPost = v),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _autoPost ? 'ترحيل مباشر إلى GL' : 'حفظ كمسودّة فقط',
                    style: TextStyle(
                        color: _autoPost ? _ok : _warn,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _autoPost
                        ? 'القيد سيظهر فوراً في ميزان المراجعة والتقارير المالية.'
                        : 'القيد لن يظهر في التقارير المالية حتى تضغط زر الترحيل يدوياً.',
                    style: TextStyle(color: _ts, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _taxPill(String value, String label) {
    final active = _taxMode == value;
    return InkWell(
      onTap: () => setState(() => _taxMode = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? core_theme.AC.purple.withValues(alpha: 0.18)
              : _navy3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? core_theme.AC.purple
                  : _bdr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? core_theme.AC.purple : _ts,
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── Tab 3: ملاحظات داخلية ───
  Widget _notesTab() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.sticky_note_2_outlined, color: _gold, size: 14),
            const SizedBox(width: 6),
            Text(
              'ملاحظات داخلية للمراجعة',
              style: TextStyle(
                  color: _tp, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              'لا تظهر في التقارير الرسمية',
              style: TextStyle(
                  color: _td, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            minLines: 5,
            maxLines: 10,
            style: TextStyle(color: _tp, fontSize: 12),
            decoration: InputDecoration(
              hintText:
                  'ملاحظات خاصة للمراجع الداخلي — مثلاً: مصدر الرقم، الشخص المعتمد، مستند مساند...',
              hintStyle: TextStyle(color: _td, fontSize: 11, height: 1.5),
              filled: true,
              fillColor: _navy3,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Totals meter — sticky ───
  Widget _totalsMeter() {
    final balanced = _difference.abs() < 0.01 && _totalDebit > 0;
    final color = balanced ? _ok : (_totalDebit == 0 ? _td : _err);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(
          balanced
              ? Icons.check_circle_rounded
              : (_totalDebit == 0
                  ? Icons.info_outline_rounded
                  : Icons.warning_amber_rounded),
          color: color,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                balanced
                    ? 'القيد متوازن — جاهز للحفظ'
                    : (_totalDebit == 0
                        ? 'أدخل المبالغ في السطور'
                        : 'الفرق: ${_fmt(_difference)}'),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Totals stack
        _meterCell('مدين', _totalDebit, _ok),
        const SizedBox(width: 16),
        _meterCell('دائن', _totalCredit, _indigo),
      ]),
    );
  }

  Widget _meterCell(String label, double v, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 10)),
        Text(
          _fmt(v),
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ─── Error strip ───
  Widget _errorStrip() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _err.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _err.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: _err, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: TextStyle(color: _err, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  // ─── Footer action bar (Cancel / Save Draft / Save + Post) ───
  Widget _footerActionBar(bool balanced) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: _navy2,
        border: Border(top: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        // Cancel
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: _ts,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: _loading
              ? null
              : () {
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    Navigator.pop(context, false);
                  }
                },
          child: const Text('إلغاء',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        // Save Draft
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _tp,
            side: BorderSide(color: _bdr),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _loading
              ? null
              : () {
                  setState(() => _autoPost = false);
                  _submit();
                },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('حفظ كمسودّة',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        // Save + Post (primary)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: balanced ? _gold : _navy3,
            foregroundColor: balanced ? core_theme.AC.btnFg : _td,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          onPressed: (_loading || !balanced)
              ? null
              : () {
                  setState(() => _autoPost = true);
                  _submit();
                },
          icon: _loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.rocket_launch_rounded, size: 16),
          label: Text(
            _loading ? 'جاري الحفظ...' : 'حفظ + ترحيل',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  // Helper: field label + widget wrapper
  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: _td, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  // ─── Line row — dynamic columns (partner/analytic/tax) + AI hints ───
  Widget _lineRow(int i, _JeLine l) {
    final acc = widget.accounts.firstWhere(
      (a) => a['id'] == l.accountId,
      orElse: () => {},
    );
    final hasAiHint = l.aiHint.isNotEmpty;
    final aiBorderColor = !hasAiHint
        ? _bdr
        : (l.aiMatchConfidence >= 0.7
            ? _ok.withValues(alpha: 0.5)
            : (l.aiMatchConfidence >= 0.4
                ? _warn.withValues(alpha: 0.5)
                : _err.withValues(alpha: 0.5)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _bdr.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text(
            '${i + 1}',
            style: TextStyle(color: _ts, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        // Account picker
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => _pickAccount(i),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: _navy2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: aiBorderColor),
              ),
              child: Row(children: [
                Icon(
                  acc.isEmpty
                      ? (hasAiHint
                          ? Icons.auto_awesome_rounded
                          : Icons.search_rounded)
                      : Icons.check_circle_rounded,
                  color: acc.isEmpty
                      ? (hasAiHint ? _warn : _gold)
                      : _ok,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    acc.isEmpty
                        ? (hasAiHint
                            ? '⚠ ${l.aiHint}'
                            : 'اختر حساباً')
                        : '${acc['code']} — ${acc['name_ar']}',
                    style: TextStyle(
                      color: acc.isEmpty
                          ? (hasAiHint ? _warn : _td)
                          : _tp,
                      fontSize: 11,
                      fontFamily: acc.isEmpty ? null : 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
        ),
        // Partner column (optional)
        if (_showPartner) ...[
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextField(
              controller: l.partnerCtrl,
              onChanged: (v) => l.partner = v,
              style: TextStyle(color: _tp, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'مورد/عميل',
                hintStyle: TextStyle(color: _td, fontSize: 10),
                isDense: true,
                filled: true,
                fillColor: _navy2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: _bdr),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: _bdr),
                ),
              ),
            ),
          ),
        ],
        // Description
        const SizedBox(width: 4),
        Expanded(
          flex: 3,
          child: TextField(
            controller: l.descCtrl,
            onChanged: (v) => l.description = v,
            style: TextStyle(color: _tp, fontSize: 11),
            decoration: InputDecoration(
              hintText: 'البيان (اختياري)',
              hintStyle: TextStyle(color: _td, fontSize: 10),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ),
        // Analytic column (optional)
        if (_showAnalytic) ...[
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextField(
              controller: l.analyticCtrl,
              onChanged: (v) => l.analytic = v,
              style: TextStyle(color: _tp, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'مركز/مشروع',
                hintStyle: TextStyle(color: _td, fontSize: 10),
                isDense: true,
                filled: true,
                fillColor: _navy2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: _bdr),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: _bdr),
                ),
              ),
            ),
          ),
        ],
        // Tax code column (optional)
        if (_showTaxCode) ...[
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: _navy2,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _bdr),
                ),
                child: DropdownButton<String>(
                  value: l.taxCode.isEmpty ? null : l.taxCode,
                  hint: Text('—',
                      style: TextStyle(color: _td, fontSize: 10)),
                  isExpanded: true,
                  dropdownColor: _navy2,
                  style: TextStyle(color: _tp, fontSize: 10),
                  icon: Icon(Icons.expand_more_rounded, color: _ts, size: 14),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('—')),
                    DropdownMenuItem(value: 'VAT15', child: Text('VAT 15%')),
                    DropdownMenuItem(value: 'ZERO', child: Text('صفري')),
                    DropdownMenuItem(value: 'EXEMPT', child: Text('معفى')),
                  ],
                  onChanged: (v) => setState(() => l.taxCode = v ?? ''),
                ),
              ),
            ),
          ),
        ],
        // Debit
        const SizedBox(width: 4),
        SizedBox(
          width: 100,
          child: TextField(
            controller: l.debitCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0;
              setState(() {
                l.debit = parsed;
                // Auto-clear credit + sync its controller
                if (parsed > 0 && l.credit > 0) {
                  l.credit = 0;
                  l.creditCtrl.text = '';
                }
              });
            },
            style: TextStyle(
              color: _ok,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor:
                  l.debit > 0 ? _ok.withValues(alpha: 0.08) : _navy2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        // Credit
        const SizedBox(width: 4),
        SizedBox(
          width: 100,
          child: TextField(
            controller: l.creditCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0;
              setState(() {
                l.credit = parsed;
                // Auto-clear debit + sync its controller
                if (parsed > 0 && l.debit > 0) {
                  l.debit = 0;
                  l.debitCtrl.text = '';
                }
              });
            },
            style: TextStyle(
              color: _indigo,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor:
                  l.credit > 0 ? _indigo.withValues(alpha: 0.08) : _navy2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        // Delete line
        SizedBox(
          width: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'حذف السطر',
            icon: Icon(Icons.delete_outline_rounded, color: _err, size: 16),
            onPressed: _lines.length > 2
                ? () => setState(() {
                      _lines[i].dispose();
                      _lines.removeAt(i);
                    })
                : null,
          ),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// JE Detail Dialog
// ══════════════════════════════════════════════════════════════════════════

class _JeDetailDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> accounts;
  const _JeDetailDialog({required this.data, required this.accounts});

  String _accountLabel(String? id) {
    if (id == null) return '—';
    final a = accounts.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (a.isEmpty) return id;
    return '${a['code']} — ${a['name_ar']}';
  }

  @override
  Widget build(BuildContext context) {
    final lines = (data['lines'] as List?) ?? [];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Icon(Icons.book, color: _gold),
          const SizedBox(width: 8),
          Text('قيد يومية #${data['je_number'] ?? ""}',
              style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _kv('التاريخ', data['je_date'] ?? '—')),
                  Expanded(
                      child: _kv('النوع',
                          _kKinds[data['kind']] ?? data['kind'] ?? '—')),
                  Expanded(child: _kv('الحالة', data['status'] ?? '—')),
                  Expanded(
                      child: _kv(
                          'تاريخ الترحيل', data['posting_date'] ?? '—')),
                ]),
                _kv('البيان', data['memo_ar'] ?? '—'),
                const SizedBox(height: 14),
                Text('السطور:',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(children: [
                    SizedBox(width: 30, child: Text('#', style: _th)),
                    Expanded(flex: 3, child: Text('الحساب', style: _th)),
                    Expanded(flex: 2, child: Text('البيان', style: _th)),
                    SizedBox(
                        width: 110,
                        child: Text('مدين',
                            style: _th, textAlign: TextAlign.end)),
                    SizedBox(
                        width: 110,
                        child: Text('دائن',
                            style: _th, textAlign: TextAlign.end)),
                  ]),
                ),
                ...lines.map((l) {
                  final dr = asDouble(l['debit_amount']);
                  final cr = asDouble(l['credit_amount']);
                  return Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        color: _navy3.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(children: [
                      SizedBox(
                          width: 30,
                          child: Text('${l['line_number']}',
                              style: TextStyle(
                                  color: _ts, fontSize: 11))),
                      Expanded(
                        flex: 3,
                        child: Text(_accountLabel(l['account_id']),
                            style: TextStyle(
                                color: _tp,
                                fontSize: 11,
                                fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(l['description'] ?? '—',
                            style: TextStyle(
                                color: _ts, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                            dr > 0 ? dr.toStringAsFixed(2) : '—',
                            style: TextStyle(
                                color: dr > 0 ? _ok : _td,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                            cr > 0 ? cr.toStringAsFixed(2) : '—',
                            style: TextStyle(
                                color: cr > 0 ? _indigo : _td,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _gold.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Expanded(
                        child: _kv('إجمالي المدين',
                            (data['total_debit'] ?? 0).toString(), mono: true)),
                    Expanded(
                        child: _kv('إجمالي الدائن',
                            (data['total_credit'] ?? 0).toString(), mono: true)),
                  ]),
                ),
                const SizedBox(height: 14),
                // مستندات القيد — متطلب SOCPA/ZATCA
                AttachmentsPanel(
                  parentType: 'journal_entries',
                  parentId: data['id']?.toString() ?? '',
                  title: 'المستندات المصدر (فاتورة، إيصال، ...)',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.btnFg),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(color: _td, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
