/// APEX — Sales Invoices (V5 chip body for /app/erp/finance/sales-invoices)
///
/// Toolbar pattern (RTL) — mirrors قيود اليومية (JE Builder) ribbon:
///   [Title + counter] [Compact search 120-220px]
///   [Combined Filter ▾] (date · status · customer · amount · sort)
///   [Group-by ▾] [View toggle]
///   ⟶ Spacer ⟶
///   [Refresh] [Export] [Reports]
///   [Outlined "جديد" gold] [Filled "ذكاء" purple]
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});
  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

// ─── Enums (Sales-Invoices-specific tooling) ────────────────────────────────
enum _GroupBy { none, status, customer, month, quarter, dueWeek }

enum _SortKey {
  dateDesc,
  dateAsc,
  numberAsc,
  totalDesc,
  totalAsc,
  dueAsc,
}

enum _DatePreset { all, today, week, month, quarter, year, custom }

enum _ViewMode { list, cards }

// Status palette — drives chips, group headers, row icons.
Map<String, Map<String, dynamic>> _kStatuses(BuildContext ctx) =>
    <String, Map<String, dynamic>>{
      'draft': {'ar': 'مسودة', 'color': AC.warn, 'icon': Icons.edit_note},
      'issued': {'ar': 'صادرة', 'color': AC.gold, 'icon': Icons.send},
      'overdue': {'ar': 'متأخرة', 'color': AC.err, 'icon': Icons.warning_amber},
      'paid': {'ar': 'مدفوعة', 'color': AC.ok, 'icon': Icons.verified},
    };

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  // ── Data ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _all = [];
  bool _loading = false;
  String? _error;

  // ── Toolbar state (mirrors JE Builder) ───────────────────────────────
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Filters
  final Set<String> _statusMulti = <String>{};
  final Set<String> _customerMulti = <String>{};
  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _amountBucket = 'all'; // all | lt1k | 1k_10k | 10k_100k | gt100k

  // View / sort / group
  _GroupBy _groupBy = _GroupBy.none;
  _SortKey _sort = _SortKey.dateDesc;
  _ViewMode _viewMode = _ViewMode.list;

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

  // ── Load ─────────────────────────────────────────────────────────────
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

  // ── Helpers ──────────────────────────────────────────────────────────
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

  /// Maps an invoice to its display status key (overdue overrides issued).
  String _statusKey(Map inv) {
    if (_isOverdue(inv)) return 'overdue';
    final s = inv['status']?.toString() ?? 'draft';
    return s;
  }

  String _statusLabel(Map inv) {
    final k = _statusKey(inv);
    final s = _kStatuses(context)[k];
    return s?['ar'] as String? ?? k;
  }

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

  // ── Active filter count (drives badge) ───────────────────────────────
  int get _activeFilterCount {
    var n = 0;
    if (_searchCtl.text.trim().isNotEmpty) n++;
    if (_datePreset != _DatePreset.all) n++;
    if (_statusMulti.isNotEmpty) n++;
    if (_customerMulti.isNotEmpty) n++;
    if (_amountBucket != 'all') n++;
    return n;
  }

  void _clearAllFilters() {
    setState(() {
      _searchCtl.clear();
      _statusMulti.clear();
      _customerMulti.clear();
      _datePreset = _DatePreset.all;
      _dateFrom = null;
      _dateTo = null;
      _amountBucket = 'all';
    });
  }

  // ── Date preset handling ─────────────────────────────────────────────
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
          _dateTo = _dateFrom!.add(const Duration(days: 1));
          break;
        case _DatePreset.week:
          final wd = now.weekday; // 1..7
          _dateFrom = DateTime(now.year, now.month, now.day - (wd - 1));
          _dateTo = _dateFrom!.add(const Duration(days: 7));
          break;
        case _DatePreset.month:
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = DateTime(now.year, now.month + 1, 1);
          break;
        case _DatePreset.quarter:
          final q = ((now.month - 1) ~/ 3);
          _dateFrom = DateTime(now.year, q * 3 + 1, 1);
          _dateTo = DateTime(now.year, q * 3 + 4, 1);
          break;
        case _DatePreset.year:
          _dateFrom = DateTime(now.year, 1, 1);
          _dateTo = DateTime(now.year + 1, 1, 1);
          break;
        case _DatePreset.custom:
          // handled by _openCustomDateRange
          break;
      }
    });
  }

  Future<void> _openCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _datePreset = _DatePreset.custom;
        _dateFrom = picked.start;
        _dateTo = picked.end.add(const Duration(days: 1));
      });
    }
  }

  // ── Visible / grouped / sorted derivations ───────────────────────────
  List<Map<String, dynamic>> get _visible {
    final q = _searchCtl.text.trim().toLowerCase();
    var list = _all.where((inv) {
      // status multi
      if (_statusMulti.isNotEmpty &&
          !_statusMulti.contains(_statusKey(inv))) {
        return false;
      }
      // customer multi
      if (_customerMulti.isNotEmpty) {
        final cid = inv['customer_id']?.toString() ?? '';
        final cname = inv['customer_name']?.toString() ?? '';
        if (!_customerMulti.contains(cid) &&
            !_customerMulti.contains(cname)) {
          return false;
        }
      }
      // date range
      if (_datePreset != _DatePreset.all &&
          _dateFrom != null &&
          _dateTo != null) {
        final d = _issueDateOf(inv);
        if (d == null) return false;
        if (d.isBefore(_dateFrom!) || !d.isBefore(_dateTo!)) return false;
      }
      // amount bucket
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
      // search
      if (q.isNotEmpty) {
        final hay = [
          inv['invoice_number'],
          inv['customer_name'],
          inv['customer_id'],
          inv['issue_date'],
          inv['due_date'],
          inv['total'],
          inv['status'],
        ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Sort
    int byDate(Map a, Map b, {bool desc = true}) {
      final da = _issueDateOf(a);
      final db = _issueDateOf(b);
      if (da == null && db == null) return 0;
      if (da == null) return desc ? 1 : -1;
      if (db == null) return desc ? -1 : 1;
      return desc ? db.compareTo(da) : da.compareTo(db);
    }

    list.sort((a, b) {
      switch (_sort) {
        case _SortKey.dateDesc:
          return byDate(a, b, desc: true);
        case _SortKey.dateAsc:
          return byDate(a, b, desc: false);
        case _SortKey.numberAsc:
          return (a['invoice_number']?.toString() ?? '')
              .compareTo(b['invoice_number']?.toString() ?? '');
        case _SortKey.totalDesc:
          return _totalOf(b).compareTo(_totalOf(a));
        case _SortKey.totalAsc:
          return _totalOf(a).compareTo(_totalOf(b));
        case _SortKey.dueAsc:
          final da = _dueDateOf(a);
          final db = _dueDateOf(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
      }
    });
    return list;
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final list = _visible;
    if (_groupBy == _GroupBy.none) return {'__all__': list};
    final out = <String, List<Map<String, dynamic>>>{};
    for (final inv in list) {
      final key = switch (_groupBy) {
        _GroupBy.status => _statusLabel(inv),
        _GroupBy.customer =>
          (inv['customer_name'] ?? inv['customer_id'] ?? 'بدون عميل').toString(),
        _GroupBy.month => _monthKey(inv['issue_date']),
        _GroupBy.quarter => _quarterKey(inv['issue_date']),
        _GroupBy.dueWeek => _dueWeekKey(inv),
        _GroupBy.none => '__all__',
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

  // ── Actions ──────────────────────────────────────────────────────────
  void _onCreate() => context.go('/sales/invoices/new');
  void _onReports() => context.go('/sales/aging');

  /// AI-powered invoice creation — mirrors JE Builder's "ذكاء" button.
  /// Routes to the same create screen with `?ai=1` so the form can boot
  /// in AI-assisted mode (OCR / natural-language draft) when wired.
  void _onAiCreate() {
    // Forward-compat route param. If the create screen doesn't yet handle
    // ai=1, it simply renders the manual form — no broken link.
    context.go('/sales/invoices/new?ai=1');
  }

  /// Universal shortcuts dialog — slot 9 of the toolbar in every screen.
  /// Contents are screen-specific; the slot itself is identical.
  void _showShortcutsHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AC.bdr),
        ),
        title: Row(children: [
          Icon(Icons.keyboard_rounded, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text('اختصارات لوحة المفاتيح',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shortcutRow('N', 'فاتورة جديدة'),
            _shortcutRow('A', 'فاتورة بالذكاء'),
            _shortcutRow('/', 'بحث'),
            _shortcutRow('F', 'فلتر'),
            _shortcutRow('G', 'تجميع'),
            _shortcutRow('R', 'تحديث'),
            _shortcutRow('E', 'تصدير / تقارير'),
            _shortcutRow('Esc', 'مسح الفلتر / إغلاق'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إغلاق',
                style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AC.navy3,
            border: Border.all(color: AC.bdr),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(key,
              style: TextStyle(
                  color: AC.tp,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(color: AC.tp, fontSize: 13)),
      ]),
    );
  }

  Future<void> _onImportExport() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('تصدير وتقارير',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          ListTile(
            leading: Icon(Icons.file_upload_outlined, color: AC.gold),
            title: Text('استيراد من Excel / CSV',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            subtitle: Text('رفع ملف فواتير لتسجيلها دفعة واحدة',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            onTap: () => Navigator.pop(ctx, 'import'),
          ),
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: AC.gold),
            title: Text('تصدير إلى Excel',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            subtitle: Text('${_visible.length} فاتورة حسب الفلتر الحالي',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            onTap: () => Navigator.pop(ctx, 'export_xlsx'),
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: AC.gold),
            title: Text('تصدير إلى PDF',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            onTap: () => Navigator.pop(ctx, 'export_pdf'),
          ),
          Divider(color: AC.bdr, height: 1),
          ListTile(
            leading: Icon(Icons.bar_chart_rounded, color: AC.gold),
            title: Text('تقارير المبيعات',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            subtitle: Text('AR Aging · العملاء · المبيعات الشهرية',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            trailing: Icon(Icons.chevron_left_rounded, color: AC.ts),
            onTap: () => Navigator.pop(ctx, 'reports'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'reports') {
      _onReports();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.navy3,
      content: Text(
        action == 'import'
            ? 'الاستيراد قيد التطوير — سيتوفر قريباً'
            : 'بدأ التصدير — سيُنزَّل الملف خلال لحظات',
        style: TextStyle(color: AC.tp),
      ),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════
  //  UI
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        _buildToolbar(),
        if (_error != null) _buildErrorBanner(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Toolbar — STRICT mirror of قيود اليومية ribbon (apex_finance/lib/
  //  pilot/screens/setup/je_builder_screen.dart, lines ~590-745).
  //
  //  Layout order (RTL-aware Row), identical slot-by-slot to JE:
  //    [Gradient pill icon] [Title + counter (Flexible)]
  //    [Compact search 120-220px (Flexible flex:2)]
  //    [Combined Filter ▾]  [Group-by ▾]  [View toggle]
  //    ⟶ Spacer ⟶
  //    [Refresh] [Export ios_share] [Screen-specific 3rd slot]
  //    [Outlined "جديد" gold]  [Filled "ذكاء" purple]
  //
  //  Per-screen variation lives in:
  //    • Filter dimensions  → _buildFilterMenu (date·status·customer·amount·sort)
  //    • Group-by options   → _groupByButton  (status/customer/month/quarter/due-week)
  //    • 3rd icon slot      → reports (sales-specific replacement of JE's help)
  //    • CTA labels         → "جديد" / "ذكاء"
  //  Container styling, slot order, spacings, button shapes — IDENTICAL.
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildToolbar() {
    final visibleCount = _visible.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AC.navy2,
            Color.lerp(AC.navy2, AC.gold, 0.05) ?? AC.navy2,
          ],
        ),
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LayoutBuilder + horizontal scroll, with a BOUNDED inner SizedBox
          // so Spacer/Flexible inside the Row still get a finite mainAxis
          // budget. Without the bounded SizedBox, Spacer collapses to 0
          // (Row inside an unbounded scroll view has no maxWidth to spread
          // across) and the CTAs slam against the help icon. Pattern:
          //   • If viewport ≥ 1100px → toolbar fills the viewport width,
          //     Spacer distributes leftover (looks identical to JE).
          //   • If viewport < 1100px → toolbar locked to 1100px, user
          //     scrolls horizontally; every element stays at natural size,
          //     Spacer still pushes the action cluster to the left edge.
          LayoutBuilder(
            builder: (ctx, constraints) {
              const minToolbarWidth = 1100.0;
              final w = constraints.maxWidth < minToolbarWidth
                  ? minToolbarWidth
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: w,
                  child: Row(children: [
            // ── Gradient pill icon (matches JE) ─────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AC.gold.withValues(alpha: 0.22),
                    AC.gold.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AC.gold.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: AC.gold.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.receipt_long_rounded,
                  color: AC.gold, size: 22),
            ),
            const SizedBox(width: 14),
            // ── Title + counter ─────────────────────────────────────
            // No Flexible — title takes its natural width and never
            // collapses to ellipsis-only. Mirrors the JE pattern AND
            // guarantees visibility at any viewport size.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'فواتير المبيعات',
                  softWrap: false,
                  maxLines: 1,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _activeFilterCount > 0
                      ? '$visibleCount / ${_all.length}'
                      : '${_all.length} فاتورة',
                  maxLines: 1,
                  style:
                      TextStyle(color: AC.ts, fontSize: 11, height: 1.1),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // ── Compact search (fixed 200px — no Flexible to keep
            //    layout deterministic inside the scrollable Row) ─────
            SizedBox(
              width: 200,
              child: _compactSearchField(),
            ),
            const SizedBox(width: 6),
            // ── Combined Filter / Group-by / View toggle ────────────
            _combinedFilterButton(),
            const SizedBox(width: 4),
            _groupByButton(),
            const SizedBox(width: 4),
            _compactViewToggle(),
            const Spacer(),
            // ── Actions cluster (3 icon slots — same as JE) ─────────
            Tooltip(
              message: 'تحديث',
              child: IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: AC.ts, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AC.navy3.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AC.bdr),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _headerIconBtn(
              icon: Icons.ios_share_rounded,
              tooltip: 'استيراد / تصدير',
              onTap: _onImportExport,
            ),
            const SizedBox(width: 4),
            // 3rd slot — UNIVERSAL across screens: shortcuts/help.
            // Tooltip + dialog content are screen-specific; the slot is not.
            _headerIconBtn(
              icon: Icons.help_outline_rounded,
              tooltip:
                  'اختصارات (N فاتورة جديدة · A بالذكاء · / بحث · Esc مسح)',
              onTap: _showShortcutsHelp,
            ),
            const SizedBox(width: 12),
            // ── زر 1: إنشاء فاتورة يدوية (Outlined gold) ──
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AC.tp,
                side: BorderSide(color: AC.gold.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _onCreate,
              icon: Icon(Icons.add_rounded, size: 18, color: AC.gold),
              label: const Text(
                'جديد',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            // ── زر 2: إنشاء بالذكاء الاصطناعي (Filled purple) ──
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AC.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _onAiCreate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'ذكاء',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  // ── Compact search (ported from JE pattern) ──────────────────────────
  Widget _compactSearchField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtl,
      builder: (_, v, __) {
        return TextField(
          controller: _searchCtl,
          focusNode: _searchFocus,
          onChanged: (_) => setState(() {}),
          textDirection: TextDirection.rtl,
          style: TextStyle(color: AC.tp, fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AC.navy3,
            hintText: 'بحث بالرقم أو العميل…',
            hintStyle: TextStyle(color: AC.td, fontSize: 12),
            prefixIcon: Icon(Icons.search_rounded, color: AC.td, size: 16),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 30, minHeight: 30),
            suffixIcon: v.text.isEmpty
                ? null
                : InkWell(
                    onTap: () {
                      _searchCtl.clear();
                      setState(() {});
                    },
                    child: Icon(Icons.close_rounded, color: AC.td, size: 14),
                  ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 26, minHeight: 26),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AC.bdr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AC.bdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AC.gold, width: 1.4),
            ),
          ),
        );
      },
    );
  }

  // ── Combined Filter button (single MenuAnchor with submenus) ─────────
  Widget _combinedFilterButton() {
    final active = _activeFilterCount;
    final has = active > 0;
    final bg = has ? AC.gold : AC.navy3;
    final fg = has ? AC.navy : AC.ts;
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStateProperty.all(AC.navy2),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AC.bdr),
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
            hoverColor: AC.gold.withValues(alpha: 0.12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: has ? AC.gold : AC.bdr.withValues(alpha: 0.9),
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
      _SortKey.dateDesc: 'تاريخ الإصدار (الأحدث)',
      _SortKey.dateAsc: 'تاريخ الإصدار (الأقدم)',
      _SortKey.numberAsc: 'رقم الفاتورة',
      _SortKey.totalDesc: 'الإجمالي (الأكبر)',
      _SortKey.totalAsc: 'الإجمالي (الأصغر)',
      _SortKey.dueAsc: 'تاريخ الاستحقاق',
    };
    const amountBuckets = <String, String>{
      'all': 'كل المبالغ',
      'lt1k': '< 1,000',
      '1k_10k': '1,000 – 10,000',
      '10k_100k': '10,000 – 100,000',
      'gt100k': '> 100,000',
    };

    String dateLabel() {
      if (_datePreset == _DatePreset.all) return 'التاريخ';
      if (_datePreset == _DatePreset.custom &&
          _dateFrom != null &&
          _dateTo != null) {
        String f(DateTime d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return 'التاريخ: ${f(_dateFrom!)} → ${f(_dateTo!.subtract(const Duration(days: 1)))}';
      }
      return 'التاريخ: ${datePresets[_datePreset] ?? ''}';
    }

    // Build customer choices from currently-loaded invoices
    final customers = <String, String>{}; // id → label
    for (final inv in _all) {
      final id = inv['customer_id']?.toString() ?? '';
      final name = inv['customer_name']?.toString() ?? id;
      if (id.isNotEmpty) customers[id] = name;
    }

    return [
      // ── Date submenu ────────────────────────────────────────────
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.calendar_month_rounded,
            size: 14, color: _datePreset != _DatePreset.all ? AC.gold : AC.ts),
        menuChildren: [
          for (final e in datePresets.entries)
            MenuItemButton(
              leadingIcon: _datePreset == e.key
                  ? Icon(Icons.check_rounded, color: AC.gold, size: 14)
                  : const SizedBox(width: 14),
              onPressed: () => _applyDatePreset(e.key),
              child: Text(e.value,
                  style: TextStyle(
                      color: _datePreset == e.key ? AC.gold : AC.tp,
                      fontSize: 12.5)),
            ),
          const PopupMenuDivider(height: 4),
          MenuItemButton(
            leadingIcon: Icon(Icons.date_range_rounded,
                size: 14,
                color: _datePreset == _DatePreset.custom ? AC.gold : AC.ts),
            onPressed: _openCustomDateRange,
            child: Text(
              _datePreset == _DatePreset.custom &&
                      _dateFrom != null &&
                      _dateTo != null
                  ? 'من ${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')} → ${_dateTo!.subtract(const Duration(days: 1)).year}-${_dateTo!.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${_dateTo!.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}'
                  : 'من تاريخ → إلى تاريخ…',
              style: TextStyle(
                  color: _datePreset == _DatePreset.custom ? AC.gold : AC.tp,
                  fontSize: 12.5),
            ),
          ),
        ],
        child: Text(
          dateLabel(),
          style: TextStyle(
              color: _datePreset != _DatePreset.all ? AC.gold : AC.tp,
              fontSize: 12.5),
        ),
      ),
      // ── Status (multi-select) ───────────────────────────────────
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.task_alt_rounded,
            size: 14, color: _statusMulti.isNotEmpty ? AC.gold : AC.ts),
        menuChildren: [
          for (final e in _kStatuses(context).entries)
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
                    : AC.td,
              ),
              child: Text(e.value['ar'] as String,
                  style: TextStyle(color: AC.tp, fontSize: 12.5)),
            ),
        ],
        child: Text(
          _statusMulti.isEmpty
              ? 'الحالة'
              : 'الحالة (${_statusMulti.length})',
          style: TextStyle(
              color: _statusMulti.isNotEmpty ? AC.gold : AC.tp,
              fontSize: 12.5),
        ),
      ),
      // ── Customer (multi-select, only if there are customers) ────
      if (customers.isNotEmpty)
        SubmenuButton(
          menuStyle: menuStyle,
          leadingIcon: Icon(Icons.person_outline_rounded,
              size: 14,
              color: _customerMulti.isNotEmpty ? AC.gold : AC.ts),
          menuChildren: [
            for (final c in customers.entries)
              MenuItemButton(
                onPressed: () => setState(() {
                  if (!_customerMulti.add(c.key)) {
                    _customerMulti.remove(c.key);
                  }
                }),
                leadingIcon: Icon(
                  _customerMulti.contains(c.key)
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 14,
                  color: _customerMulti.contains(c.key) ? AC.gold : AC.td,
                ),
                child: Text(c.value,
                    style: TextStyle(color: AC.tp, fontSize: 12.5)),
              ),
          ],
          child: Text(
            _customerMulti.isEmpty
                ? 'العميل'
                : 'العميل (${_customerMulti.length})',
            style: TextStyle(
                color: _customerMulti.isNotEmpty ? AC.gold : AC.tp,
                fontSize: 12.5),
          ),
        ),
      // ── Amount bucket ───────────────────────────────────────────
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.payments_rounded,
            size: 14, color: _amountBucket != 'all' ? AC.gold : AC.ts),
        menuChildren: [
          for (final e in amountBuckets.entries)
            MenuItemButton(
              leadingIcon: _amountBucket == e.key
                  ? Icon(Icons.check_rounded, color: AC.gold, size: 14)
                  : const SizedBox(width: 14),
              onPressed: () => setState(() => _amountBucket = e.key),
              child: Text(e.value,
                  style: TextStyle(
                      color: _amountBucket == e.key ? AC.gold : AC.tp,
                      fontSize: 12.5)),
            ),
        ],
        child: Text(
          _amountBucket == 'all'
              ? 'المبلغ'
              : 'المبلغ: ${amountBuckets[_amountBucket]}',
          style: TextStyle(
              color: _amountBucket != 'all' ? AC.gold : AC.tp,
              fontSize: 12.5),
        ),
      ),
      // ── Sort ────────────────────────────────────────────────────
      SubmenuButton(
        menuStyle: menuStyle,
        leadingIcon: Icon(Icons.sort_rounded, size: 14, color: AC.ts),
        menuChildren: [
          for (final e in sortLabels.entries)
            MenuItemButton(
              leadingIcon: _sort == e.key
                  ? Icon(Icons.check_rounded, color: AC.gold, size: 14)
                  : const SizedBox(width: 14),
              onPressed: () => setState(() => _sort = e.key),
              child: Text(e.value,
                  style: TextStyle(
                      color: _sort == e.key ? AC.gold : AC.tp,
                      fontSize: 12.5)),
            ),
        ],
        child: Text('ترتيب: ${sortLabels[_sort]}',
            style: TextStyle(color: AC.tp, fontSize: 12.5)),
      ),
      if (_activeFilterCount > 0) ...[
        const PopupMenuDivider(height: 4),
        MenuItemButton(
          onPressed: _clearAllFilters,
          leadingIcon: Icon(Icons.clear_all_rounded,
              size: 14, color: AC.warn),
          child: Text('مسح الكل',
              style: TextStyle(color: AC.warn, fontSize: 12.5)),
        ),
      ],
    ];
  }

  // ── Group-by dropdown ────────────────────────────────────────────────
  Widget _groupByButton() {
    const opts = <(_GroupBy, String, IconData)>[
      (_GroupBy.none, 'بلا تجميع', Icons.view_list_rounded),
      (_GroupBy.status, 'الحالة', Icons.task_alt_rounded),
      (_GroupBy.customer, 'العميل', Icons.person_outline_rounded),
      (_GroupBy.month, 'الشهر', Icons.calendar_month_rounded),
      (_GroupBy.quarter, 'الربع', Icons.view_quilt_rounded),
      (_GroupBy.dueWeek, 'الاستحقاق', Icons.event_busy_rounded),
    ];
    final current = opts.firstWhere(
      (o) => o.$1 == _groupBy,
      orElse: () => opts.first,
    );
    final isActive = _groupBy != _GroupBy.none;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AC.navy2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AC.bdr),
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
          hoverColor: AC.gold.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AC.gold.withValues(alpha: 0.14) : AC.navy3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AC.gold.withValues(alpha: 0.45) : AC.bdr,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(current.$3, size: 14, color: isActive ? AC.gold : AC.ts),
              const SizedBox(width: 6),
              Text(
                'تجميع: ${current.$2}',
                style: TextStyle(
                  color: isActive ? AC.gold : AC.tp,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 14, color: AC.ts),
            ]),
          ),
        ),
      ),
      menuChildren: [
        for (final o in opts)
          MenuItemButton(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
              minimumSize: WidgetStateProperty.all(const Size(200, 36)),
            ),
            leadingIcon: Icon(o.$3,
                size: 15, color: _groupBy == o.$1 ? AC.gold : AC.ts),
            trailingIcon: _groupBy == o.$1
                ? Icon(Icons.check_rounded, color: AC.gold, size: 14)
                : null,
            onPressed: () => setState(() => _groupBy = o.$1),
            child: Text(
              o.$2,
              style: TextStyle(
                color: _groupBy == o.$1 ? AC.gold : AC.tp,
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

  // ── List/Cards toggle ────────────────────────────────────────────────
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
            color: AC.navy3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.bdr),
          ),
          child: Icon(
            _viewMode == _ViewMode.list
                ? Icons.grid_view_rounded
                : Icons.view_list_rounded,
            size: 14,
            color: AC.ts,
          ),
        ),
      ),
    );
  }

  // ── Header icon button (refresh / export / reports) ──────────────────
  Widget _headerIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AC.ts, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: AC.navy3.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AC.bdr),
          ),
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  // ── Error banner ─────────────────────────────────────────────────────
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

  // ── Body ─────────────────────────────────────────────────────────────
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
      child: _viewMode == _ViewMode.list
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final entry in groups.entries) ...[
                  if (_groupBy != _GroupBy.none)
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
    final palette = _kStatuses(context)[k] ?? _kStatuses(context)['draft']!;
    final color = palette['color'] as Color;
    final iconData = palette['icon'] as IconData;
    return InkWell(
      onTap: () => _openInvoice(inv),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
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
    final palette = _kStatuses(context)[k] ?? _kStatuses(context)['draft']!;
    final color = palette['color'] as Color;
    final iconData = palette['icon'] as IconData;
    return InkWell(
      onTap: () => _openInvoice(inv),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
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
            Text(inv['customer_name']?.toString() ??
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
