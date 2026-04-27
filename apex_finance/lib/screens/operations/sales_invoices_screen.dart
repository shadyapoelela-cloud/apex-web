/// APEX — Sales Invoices (V5 chip body for /app/erp/finance/sales-invoices)
///
/// Uses the shared `ApexListToolbar` (Odoo-style) so the visual layout
/// matches قيود اليومية and فواتير المشتريات. Sales-specific behavior:
///
///   • Filter groups: date / status / customer / amount
///   • Group-by:      none / status / customer / month / quarter / due-week
///   • Sort:          date↓↑ · number · total↓↑ · due-date↑
///   • View modes:    list, cards
///   • CTAs:          + جديد → /sales/invoices/new
///                    ✨ ذكاء → /sales/invoices/new?ai=1
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_saved_views_v2.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_copilot_drawer.dart';
import '../../widgets/apex_list_toolbar.dart';

const String _kScreenKey = '/sales/invoices';

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});
  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  // ── Data ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _all = [];
  bool _loading = false;
  String? _error;

  // ── Toolbar state ────────────────────────────────────────────────────
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Multi-select filter sets (keyed to filter-option `key`)
  final Set<String> _statusMulti = <String>{};
  final Set<String> _customerMulti = <String>{};

  // Single-select radio values
  String _datePreset = 'all'; // all|today|week|month|quarter|year|custom
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _amountBucket = 'all'; // all|lt1k|1k_10k|10k_100k|gt100k

  // Group-by + sort + view (string keys, matching toolbar API)
  String _groupBy = 'none';
  String _sortKey = 'date_desc';
  String _viewMode = 'list';

  // Bulk-select state — invoice IDs the user has ticked.
  final Set<String> _selectedIds = <String>{};

  bool _isSelected(Map inv) =>
      _selectedIds.contains(inv['id']?.toString());

  void _toggleSelected(Map inv) {
    final id = inv['id']?.toString();
    if (id == null) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  // Helper retained for future "select-all-visible" UI (header checkbox)
  // — unreferenced for now while bulk-select uses long-press to enter
  // selection mode. Suppress unused warning until the header lands.
  // ignore: unused_element
  void _selectAllVisible() {
    setState(() {
      for (final inv in _visible) {
        final id = inv['id']?.toString();
        if (id != null) _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  // ── Status palette (drives row icons + group headers) ─────────────────
  static const _statusColors = {
    'draft': 'warn',
    'issued': 'gold',
    'overdue': 'err',
    'paid': 'ok',
  };
  static const _statusLabels = {
    'draft': 'مسودة',
    'issued': 'صادرة',
    'overdue': 'متأخرة',
    'paid': 'مدفوعة',
  };
  static const _statusIcons = {
    'draft': Icons.edit_note,
    'issued': Icons.send,
    'overdue': Icons.warning_amber,
    'paid': Icons.verified,
  };

  Color _statusColor(String key) {
    switch (_statusColors[key]) {
      case 'warn':
        return AC.warn;
      case 'gold':
        return AC.gold;
      case 'err':
        return AC.err;
      case 'ok':
        return AC.ok;
      default:
        return AC.ts;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) {
      setState(() => _error = 'لم يتم اختيار شركة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListSalesInvoices(entityId, limit: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error ?? 'تعذّر تحميل الفواتير';
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Per-row helpers
  // ─────────────────────────────────────────────────────────────────────
  bool _isOverdue(Map inv) {
    if (inv['status'] != 'issued') return false;
    final dueStr = inv['due_date'];
    if (dueStr == null) return false;
    try {
      return DateTime.parse(dueStr.toString()).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _statusKey(Map inv) {
    if (_isOverdue(inv)) return 'overdue';
    return inv['status']?.toString() ?? 'draft';
  }

  String _statusLabel(Map inv) =>
      _statusLabels[_statusKey(inv)] ?? _statusKey(inv);

  num _totalOf(Map inv) {
    final t = inv['total'];
    if (t is num) return t;
    return num.tryParse(t?.toString() ?? '0') ?? 0;
  }

  DateTime? _issueDateOf(Map inv) {
    final v = inv['issue_date'];
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime? _dueDateOf(Map inv) {
    final v = inv['due_date'];
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Filter / sort derivation
  // ─────────────────────────────────────────────────────────────────────
  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      switch (preset) {
        case 'all':
          _dateFrom = null;
          _dateTo = null;
          break;
        case 'today':
          _dateFrom = DateTime(now.year, now.month, now.day);
          _dateTo = _dateFrom!.add(const Duration(days: 1));
          break;
        case 'week':
          final wd = now.weekday;
          _dateFrom = DateTime(now.year, now.month, now.day - (wd - 1));
          _dateTo = _dateFrom!.add(const Duration(days: 7));
          break;
        case 'month':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = DateTime(now.year, now.month + 1, 1);
          break;
        case 'quarter':
          final q = ((now.month - 1) ~/ 3);
          _dateFrom = DateTime(now.year, q * 3 + 1, 1);
          _dateTo = DateTime(now.year, q * 3 + 4, 1);
          break;
        case 'year':
          _dateFrom = DateTime(now.year, 1, 1);
          _dateTo = DateTime(now.year + 1, 1, 1);
          break;
      }
    });
  }

  List<Map<String, dynamic>> get _visible {
    final q = _searchCtl.text.trim().toLowerCase();
    var list = _all.where((inv) {
      if (_statusMulti.isNotEmpty &&
          !_statusMulti.contains(_statusKey(inv))) {
        return false;
      }
      if (_customerMulti.isNotEmpty) {
        final cid = inv['customer_id']?.toString() ?? '';
        if (!_customerMulti.contains(cid)) return false;
      }
      if (_datePreset != 'all' && _dateFrom != null && _dateTo != null) {
        final d = _issueDateOf(inv);
        if (d == null) return false;
        if (d.isBefore(_dateFrom!) || !d.isBefore(_dateTo!)) return false;
      }
      final amt = _totalOf(inv);
      switch (_amountBucket) {
        case 'lt1k':
          if (amt >= 1000) return false;
          break;
        case '1k_10k':
          if (amt < 1000 || amt >= 10000) return false;
          break;
        case '10k_100k':
          if (amt < 10000 || amt >= 100000) return false;
          break;
        case 'gt100k':
          if (amt < 100000) return false;
          break;
      }
      if (q.isNotEmpty) {
        final hay = [
          inv['invoice_number'],
          inv['customer_name'],
          inv['customer_id'],
          inv['issue_date'],
          inv['due_date'],
          inv['total'],
          inv['status'],
        ]
            .whereType<Object>()
            .map((e) => e.toString().toLowerCase())
            .join(' ');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    int byDate(Map a, Map b, {bool desc = true}) {
      final da = _issueDateOf(a);
      final db = _issueDateOf(b);
      if (da == null && db == null) return 0;
      if (da == null) return desc ? 1 : -1;
      if (db == null) return desc ? -1 : 1;
      return desc ? db.compareTo(da) : da.compareTo(db);
    }

    list.sort((a, b) {
      switch (_sortKey) {
        case 'date_desc':
          return byDate(a, b, desc: true);
        case 'date_asc':
          return byDate(a, b, desc: false);
        case 'number_asc':
          return (a['invoice_number']?.toString() ?? '')
              .compareTo(b['invoice_number']?.toString() ?? '');
        case 'total_desc':
          return _totalOf(b).compareTo(_totalOf(a));
        case 'total_asc':
          return _totalOf(a).compareTo(_totalOf(b));
        case 'due_asc':
          final da = _dueDateOf(a);
          final db = _dueDateOf(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
      }
      return 0;
    });
    return list;
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final list = _visible;
    if (_groupBy == 'none') return {'__all__': list};
    final out = <String, List<Map<String, dynamic>>>{};
    for (final inv in list) {
      final key = switch (_groupBy) {
        'status' => _statusLabel(inv),
        'customer' => (inv['customer_name'] ??
                inv['customer_id'] ??
                'بدون عميل')
            .toString(),
        'month' => _monthKey(inv['issue_date']),
        'quarter' => _quarterKey(inv['issue_date']),
        'due_week' => _dueWeekKey(inv),
        _ => '__all__',
      };
      out.putIfAbsent(key, () => []).add(inv);
    }
    return out;
  }

  String _monthKey(dynamic dateStr) {
    if (dateStr == null) return 'بدون تاريخ';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'بدون تاريخ';
    }
  }

  String _quarterKey(dynamic dateStr) {
    if (dateStr == null) return 'بدون تاريخ';
    try {
      final d = DateTime.parse(dateStr.toString());
      final q = ((d.month - 1) ~/ 3) + 1;
      return '${d.year} · Q$q';
    } catch (_) {
      return 'بدون تاريخ';
    }
  }

  String _dueWeekKey(Map inv) {
    final due = _dueDateOf(inv);
    if (due == null) return 'بدون استحقاق';
    final now = DateTime.now();
    final diff = due.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff < 0) return 'متأخرة';
    if (diff == 0) return 'تستحق اليوم';
    if (diff <= 7) return 'هذا الأسبوع';
    if (diff <= 30) return 'هذا الشهر';
    return 'لاحقاً';
  }

  void _clearAllFilters() {
    setState(() {
      _searchCtl.clear();
      _statusMulti.clear();
      _customerMulti.clear();
      _datePreset = 'all';
      _dateFrom = null;
      _dateTo = null;
      _amountBucket = 'all';
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Saved views (favorites) — persisted to localStorage via
  //  `ApexSavedViewsRepo`. Each view stores the full filter/group/sort/
  //  view-mode state for this screen so the user can recall a named
  //  combination ("My overdue VIP customers") with one click.
  // ─────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _captureFiltersAsMap() => {
        'search': _searchCtl.text,
        'status': _statusMulti.toList(),
        'customer': _customerMulti.toList(),
        'date_preset': _datePreset,
        'date_from': _dateFrom?.toIso8601String(),
        'date_to': _dateTo?.toIso8601String(),
        'amount_bucket': _amountBucket,
        'group_by': _groupBy,
        'sort_key': _sortKey,
        'view_mode': _viewMode,
      };

  void _restoreFiltersFromMap(Map<String, dynamic> m) {
    setState(() {
      _searchCtl.text = (m['search'] as String?) ?? '';
      _statusMulti
        ..clear()
        ..addAll(((m['status'] as List?) ?? []).cast<String>());
      _customerMulti
        ..clear()
        ..addAll(((m['customer'] as List?) ?? []).cast<String>());
      _datePreset = (m['date_preset'] as String?) ?? 'all';
      _dateFrom = m['date_from'] is String
          ? DateTime.tryParse(m['date_from'])
          : null;
      _dateTo =
          m['date_to'] is String ? DateTime.tryParse(m['date_to']) : null;
      _amountBucket = (m['amount_bucket'] as String?) ?? 'all';
      _groupBy = (m['group_by'] as String?) ?? 'none';
      _sortKey = (m['sort_key'] as String?) ?? 'date_desc';
      _viewMode = (m['view_mode'] as String?) ?? 'list';
    });
  }

  Future<void> _onSaveCurrentView() async {
    final name = await _promptForViewName();
    if (name == null || name.trim().isEmpty) return;
    ApexSavedViewsRepo.add(ApexSavedView(
      id: 'view_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      screen: _kScreenKey,
      filters: _captureFiltersAsMap(),
      createdAt: DateTime.now(),
      icon: Icons.bookmark_rounded,
    ));
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.navy3,
        content: Text('تم حفظ البحث "$name"',
            style: TextStyle(color: AC.tp), textAlign: TextAlign.right),
      ));
    }
  }

  Future<String?> _promptForViewName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AC.bdr),
        ),
        title: Row(children: [
          Icon(Icons.bookmark_add_rounded, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text('حفظ البحث الحالي',
              style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            hintText: 'اسم البحث (مثال: فواتير VIP المتأخرة)',
            hintStyle: TextStyle(color: AC.td),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.gold)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: AC.td))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  List<ApexFavorite> _loadFavorites() {
    return ApexSavedViewsRepo.all()
        .where((v) => v.screen == _kScreenKey)
        .map((v) => ApexFavorite(
              key: v.id,
              labelAr: v.name,
              onApply: () => _restoreFiltersFromMap(v.filters),
              onDelete: () {
                ApexSavedViewsRepo.remove(v.id);
                setState(() {});
              },
            ))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  //  CTA actions
  // ─────────────────────────────────────────────────────────────────────
  void _onCreate() => context.go('/sales/invoices/new');

  /// "ذكاء" button — opens an inline AI Copilot drawer grounded in the
  /// current screen state. Replaces the old `?ai=1` create-route fallback;
  /// the user explicitly asked the AI button to surface Ask APEX, not a
  /// new-with-AI flow.
  void _onAiCreate() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  /// Endpoint snapshot the drawer can use to ground its responses.
  Map<String, dynamic> _buildScreenContext() => {
        'totalCount': _all.length,
        'visibleCount': _visible.length,
        'filters': _captureFiltersAsMap(),
        'groupBy': _groupBy,
        'sortKey': _sortKey,
        'viewMode': _viewMode,
      };

  // ─────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────
  // GlobalKey lets `_onAiCreate` reach the Scaffold's openEndDrawer
  // without scaffolding a Builder around the body.
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AC.navy,
      // RTL endDrawer slides in from the visual LEFT — matches the
      // "ذكاء" button position in the toolbar.
      endDrawer: ApexCopilotDrawer(
        screenName: 'فواتير المبيعات',
        screenContext: _buildScreenContext(),
      ),
      body: Column(children: [
        _buildToolbar(),
        if (_error != null) _buildErrorBanner(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildToolbar() {
    // Build date filter group
    final dateGroup = ApexFilterGroup(
      labelAr: 'التاريخ',
      icon: Icons.calendar_month_rounded,
      multi: false,
      selected: {_datePreset},
      onToggle: _applyDatePreset,
      options: const [
        ApexFilterOption(key: 'all', labelAr: 'كل التواريخ'),
        ApexFilterOption(key: 'today', labelAr: 'اليوم'),
        ApexFilterOption(key: 'week', labelAr: 'هذا الأسبوع'),
        ApexFilterOption(key: 'month', labelAr: 'هذا الشهر'),
        ApexFilterOption(key: 'quarter', labelAr: 'هذا الربع'),
        ApexFilterOption(key: 'year', labelAr: 'هذه السنة'),
      ],
    );

    final statusGroup = ApexFilterGroup(
      labelAr: 'الحالة',
      icon: Icons.task_alt_rounded,
      multi: true,
      selected: _statusMulti,
      onToggle: (k) => setState(() {
        if (!_statusMulti.add(k)) _statusMulti.remove(k);
      }),
      options: [
        for (final e in _statusLabels.entries)
          ApexFilterOption(
            key: e.key,
            labelAr: e.value,
            icon: _statusIcons[e.key],
            color: _statusColor(e.key),
          ),
      ],
    );

    // Build customer choices from currently-loaded invoices
    final customerMap = <String, String>{};
    for (final inv in _all) {
      final id = inv['customer_id']?.toString() ?? '';
      final name = inv['customer_name']?.toString() ?? id;
      if (id.isNotEmpty) customerMap[id] = name;
    }
    final customerGroup = ApexFilterGroup(
      labelAr: 'العميل',
      icon: Icons.person_outline_rounded,
      multi: true,
      selected: _customerMulti,
      onToggle: (k) => setState(() {
        if (!_customerMulti.add(k)) _customerMulti.remove(k);
      }),
      options: [
        for (final e in customerMap.entries)
          ApexFilterOption(key: e.key, labelAr: e.value),
      ],
    );

    final amountGroup = ApexFilterGroup(
      labelAr: 'المبلغ',
      icon: Icons.payments_rounded,
      multi: false,
      selected: {_amountBucket},
      onToggle: (k) => setState(() => _amountBucket = k),
      options: const [
        ApexFilterOption(key: 'all', labelAr: 'كل المبالغ'),
        ApexFilterOption(key: 'lt1k', labelAr: '< 1,000'),
        ApexFilterOption(key: '1k_10k', labelAr: '1,000 – 10,000'),
        ApexFilterOption(key: '10k_100k', labelAr: '10,000 – 100,000'),
        ApexFilterOption(key: 'gt100k', labelAr: '> 100,000'),
      ],
    );

    return ApexListToolbar(
      titleAr: 'فواتير المبيعات',
      titleIcon: Icons.receipt_long_rounded,
      itemNounAr: 'فاتورة',
      totalCount: _all.length,
      visibleCount: _visible.length,
      searchCtl: _searchCtl,
      searchFocus: _searchFocus,
      searchHint: 'بحث برقم الفاتورة أو العميل…',
      onSearchChanged: () => setState(() {}),
      filterGroups: [
        dateGroup,
        statusGroup,
        if (customerMap.isNotEmpty) customerGroup,
        amountGroup,
      ],
      groupOptions: const [
        ApexGroupOption(
            key: 'none', labelAr: 'بلا تجميع', icon: Icons.view_list_rounded),
        ApexGroupOption(
            key: 'status', labelAr: 'الحالة', icon: Icons.task_alt_rounded),
        ApexGroupOption(
            key: 'customer',
            labelAr: 'العميل',
            icon: Icons.person_outline_rounded),
        ApexGroupOption(
            key: 'month',
            labelAr: 'الشهر',
            icon: Icons.calendar_month_rounded),
        ApexGroupOption(
            key: 'quarter',
            labelAr: 'الربع',
            icon: Icons.view_quilt_rounded),
        ApexGroupOption(
            key: 'due_week',
            labelAr: 'الاستحقاق',
            icon: Icons.event_busy_rounded),
      ],
      activeGroupKey: _groupBy,
      onChangeGroup: (k) => setState(() => _groupBy = k),
      sortOptions: const [
        ApexFilterOption(key: 'date_desc', labelAr: 'تاريخ الإصدار (الأحدث)'),
        ApexFilterOption(key: 'date_asc', labelAr: 'تاريخ الإصدار (الأقدم)'),
        ApexFilterOption(key: 'number_asc', labelAr: 'رقم الفاتورة'),
        ApexFilterOption(key: 'total_desc', labelAr: 'الإجمالي (الأكبر)'),
        ApexFilterOption(key: 'total_asc', labelAr: 'الإجمالي (الأصغر)'),
        ApexFilterOption(key: 'due_asc', labelAr: 'تاريخ الاستحقاق'),
      ],
      activeSortKey: _sortKey,
      onChangeSort: (k) => setState(() => _sortKey = k),
      onClearAllFilters: _statusMulti.isNotEmpty ||
              _customerMulti.isNotEmpty ||
              _datePreset != 'all' ||
              _amountBucket != 'all' ||
              _searchCtl.text.isNotEmpty
          ? _clearAllFilters
          : null,
      viewModes: const [
        ApexViewMode(
            key: 'list', labelAr: 'قائمة', icon: Icons.view_list_rounded),
        ApexViewMode(
            key: 'cards',
            labelAr: 'بطاقات',
            icon: Icons.grid_view_rounded),
      ],
      activeViewKey: _viewMode,
      onChangeView: (k) => setState(() => _viewMode = k),
      onCreate: _onCreate,
      createLabelAr: 'جديد',
      onAiCreate: _onAiCreate,
      aiCreateLabelAr: 'ذكاء',
      favorites: _loadFavorites(),
      onSaveFavorite: _onSaveCurrentView,
      // Bulk-select: when N rows ticked, toolbar swaps to a selection
      // bar with these actions on the LEFT.
      selectedCount: _selectedIds.length,
      onClearSelection: _clearSelection,
      bulkActions: [
        ApexBulkAction(
          labelAr: 'تصدير المحدّد',
          icon: Icons.file_download_outlined,
          onTap: () => _bulkExport(),
        ),
        ApexBulkAction(
          labelAr: 'طباعة',
          icon: Icons.print_outlined,
          onTap: () => _bulkPrint(),
        ),
        ApexBulkAction(
          labelAr: 'حذف',
          icon: Icons.delete_outline_rounded,
          onTap: () => _bulkDelete(),
          destructive: true,
        ),
      ],
      shortcuts: const [
        ApexShortcut('N', 'فاتورة جديدة'),
        ApexShortcut('A', 'فاتورة بالذكاء'),
        ApexShortcut('/', 'بحث'),
        ApexShortcut('F', 'فلتر'),
        ApexShortcut('G', 'تجميع'),
        ApexShortcut('R', 'تحديث'),
        ApexShortcut('S', 'حفظ البحث الحالي'),
        ApexShortcut('Ctrl+A', 'تحديد الكل'),
        ApexShortcut('Esc', 'مسح الفلتر / التحديد / إغلاق'),
      ],
      tips: const [
        ApexTip(
          titleAr: 'بحث متقدّم بالـ chips',
          bodyAr:
              'اضغط على ▼ بجانب البحث ثم افتح أي قسم فلتر. اختياراتك تظهر كـ chips داخل شريط البحث، اضغط ✕ على أي chip لإزالته.',
          icon: Icons.filter_list_rounded,
        ),
        ApexTip(
          titleAr: 'تحديد متعدّد',
          bodyAr:
              'اضغط مطوّلاً (long-press) على أي فاتورة لدخول وضع التحديد. شريط الأدوات يتحوّل إلى شريط إجراءات يحوي تصدير، طباعة، حذف.',
          icon: Icons.check_box_rounded,
        ),
        ApexTip(
          titleAr: 'حفظ البحث الحالي',
          bodyAr:
              'بعد ضبط الفلاتر/التجميع/الترتيب، افتح ▼ ← المفضلات ← "حفظ البحث الحالي". يُحفظ في متصفحك ويظهر في القائمة لاحقاً للاستدعاء بضغطة.',
          icon: Icons.bookmark_add_rounded,
        ),
        ApexTip(
          titleAr: 'مساعد ذكاء سياقي',
          bodyAr:
              'زر "ذكاء" البنفسجي يفتح مساعد AI في الجانب يعرف ما تنظر إليه (عدد السجلات، الفلاتر النشطة، التجميع الحالي) — اسأله عن ملخّص أو اقتراح.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }

  // ─── Bulk action implementations (wave 1: snackbar placeholders;
  //     wave 4 wires real export/print/delete via API) ─────────────
  void _bulkExport() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.navy3,
      content: Text(
          'تصدير ${_selectedIds.length} فاتورة — قيد التطوير (الموجة ٤)',
          style: TextStyle(color: AC.tp),
          textAlign: TextAlign.right),
    ));
  }

  void _bulkPrint() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.navy3,
      content: Text(
          'طباعة ${_selectedIds.length} فاتورة — قيد التطوير (الموجة ٤)',
          style: TextStyle(color: AC.tp),
          textAlign: TextAlign.right),
    ));
  }

  Future<void> _bulkDelete() async {
    final n = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AC.err),
        ),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AC.err, size: 22),
          const SizedBox(width: 8),
          Text('حذف $n فاتورة؟',
              style: TextStyle(
                  color: AC.err, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          'سيتم حذف الفواتير المحدّدة. لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: AC.tp),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.td)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AC.err, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // TODO(wave-4): wire to real DELETE endpoint when available.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.navy3,
        content: Text('حذف $n فاتورة — endpoint قيد التطوير (الموجة ٤)',
            style: TextStyle(color: AC.tp),
            textAlign: TextAlign.right),
      ));
      _clearSelection();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Body
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: AC.errSoft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(Icons.error_outline, color: AC.err, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(_error ?? '',
                style: TextStyle(color: AC.err, fontSize: 12))),
        TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading && _all.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: AC.gold, strokeWidth: 2));
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: AC.ts, size: 48),
            const SizedBox(height: 12),
            Text('لا توجد فواتير مطابقة',
                style: TextStyle(color: AC.tp, fontSize: 14)),
            const SizedBox(height: 6),
            Text('جرّب إزالة الفلتر أو ابدأ بإصدار فاتورة جديدة',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إنشاء فاتورة'),
              style: FilledButton.styleFrom(
                  backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ],
        ),
      );
    }
    final groups = _grouped;
    return RefreshIndicator(
      onRefresh: _load,
      color: AC.gold,
      child: _viewMode == 'list'
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final entry in groups.entries) ...[
                  if (_groupBy != 'none')
                    _groupHeader(entry.key, entry.value.length),
                  ...entry.value.map(_invoiceRow),
                ],
              ],
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 130,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visible.length,
              itemBuilder: (_, i) => _invoiceCard(visible[i]),
            ),
    );
  }

  Widget _groupHeader(String key, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border(right: BorderSide(color: AC.gold, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Text(key,
            style: TextStyle(
                color: AC.gold, fontSize: 12.5, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Text('($count)',
            style: TextStyle(
                color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _invoiceRow(Map<String, dynamic> inv) {
    final k = _statusKey(inv);
    final color = _statusColor(k);
    final iconData = _statusIcons[k] ?? Icons.receipt_long;
    final selected = _isSelected(inv);
    final inSelectionMode = _selectedIds.isNotEmpty;
    return InkWell(
      // Tap behavior: in selection mode → toggle; otherwise → open invoice.
      onTap: () =>
          inSelectionMode ? _toggleSelected(inv) : _openInvoice(inv),
      // Long-press → enter selection mode.
      onLongPress: () => _toggleSelected(inv),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AC.gold.withValues(alpha: 0.10)
              : AC.navy2,
          border: Border.all(
              color: selected ? AC.gold.withValues(alpha: 0.6) : AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          // Checkbox (visible in selection mode, or always — here we show
          // it only when selection mode is active, to keep the row clean).
          if (inSelectionMode) ...[
            InkWell(
              onTap: () => _toggleSelected(inv),
              child: Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? AC.gold : AC.td,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Icon(iconData, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${inv['invoice_number'] ?? '—'}',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      '${inv['issue_date'] ?? ''} · ${inv['customer_name'] ?? inv['customer_id'] ?? ''}',
                      style: TextStyle(color: AC.ts, fontSize: 11)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_statusLabel(inv),
                style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Text('${inv['total'] ?? 0} SAR',
              style: TextStyle(
                  color: AC.gold,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv) {
    final k = _statusKey(inv);
    final color = _statusColor(k);
    final iconData = _statusIcons[k] ?? Icons.receipt_long;
    final selected = _isSelected(inv);
    final inSelectionMode = _selectedIds.isNotEmpty;
    return InkWell(
      onTap: () =>
          inSelectionMode ? _toggleSelected(inv) : _openInvoice(inv),
      onLongPress: () => _toggleSelected(inv),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.10) : AC.navy2,
          border: Border.all(
              color: selected ? AC.gold.withValues(alpha: 0.6) : AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (inSelectionMode) ...[
                InkWell(
                  onTap: () => _toggleSelected(inv),
                  child: Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: selected ? AC.gold : AC.td,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(iconData, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${inv['invoice_number'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(inv),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                inv['customer_name']?.toString() ??
                    inv['customer_id']?.toString() ??
                    'بدون عميل',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AC.tp, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text('${inv['issue_date'] ?? ''}',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            const Spacer(),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text('${inv['total'] ?? 0} SAR',
                  style: TextStyle(
                      color: AC.gold,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _openInvoice(Map<String, dynamic> inv) {
    final jeId = inv['journal_entry_id'] as String?;
    if (jeId != null) {
      context.go('/compliance/journal-entry/$jeId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('الفاتورة ${inv['invoice_number']} لم تُصدر بعد'),
      ));
    }
  }
}
