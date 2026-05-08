/// G-TB-DISPLAY-1 — Trial Balance display screen.
///
/// Hits the existing pilot endpoint
/// `GET /pilot/entities/{entity_id}/reports/trial-balance` (see
/// `app/pilot/routes/gl_routes.py:357` and the `compute_trial_balance`
/// service in `app/pilot/services/gl_engine.py:720`). The endpoint
/// returns a snapshot trial balance up to `as_of` — total debit /
/// total credit / balance per `pilot_gl_accounts` row, plus a top-
/// level `balanced` flag.
///
/// What this screen is NOT
/// -----------------------
///   * The CSV-tie-out / parser tool — that's
///     `screens/simulation/trial_balance_screen.dart` (`TrialBalanceCheckScreen`),
///     a different feature.
///   * A period-split "opening / period movement / closing" report.
///     The pilot endpoint doesn't (yet) split by period; adding that
///     requires a backend extension and is queued separately. The
///     UAT brief asked for the period split but the backend reality
///     is one snapshot column set, so the screen renders that.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  // ── Filter state ─────────────────────────────────────────────
  DateTime _asOf = DateTime.now();
  bool _hideZero = true;
  String _search = '';

  // ── Sorting state ───────────────────────────────────────────
  // Index into `_columns` below. -1 = no explicit sort (server
  // returns rows ordered by code, which is the default).
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  // ── Async state ─────────────────────────────────────────────
  bool _loading = false;
  String? _error;
  // Raw response from the API. Keep the strong typing minimal
  // here — the API schema is documented above and lives in
  // `app/pilot/schemas/gl.py`; we adapt at the call site.
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _entityId => S.entityId ?? S.savedEntityId;

  // The session entity id is set when the user picks an entity
  // (see entity_store.dart). Outside the V5 routing path the user
  // may land here with no entity bound — surface that explicitly
  // rather than 422-ing the API.
  Future<void> _load() async {
    final eid = _entityId;
    if (eid == null || eid.isEmpty) {
      setState(() {
        _error =
            'لا يوجد كيان نشط مرتبط بالجلسة. اختر كيانًا من إعداد الكيانات أولاً.';
        _loading = false;
        _data = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotTrialBalance(
      eid,
      asOf: _asOf.toIso8601String().split('T').first,
      includeZero: !_hideZero,
    );
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _data = (res.data is Map<String, dynamic>)
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.error ?? 'تعذّر جلب ميزان المراجعة';
        _loading = false;
      });
    }
  }

  // ── Filter rows by search box (account code or Arabic name) ─
  List<Map<String, dynamic>> get _visibleRows {
    final rows = (_data?['rows'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (_search.isEmpty) return rows;
    final q = _search.toLowerCase();
    return rows.where((r) {
      final code = '${r['code'] ?? ''}'.toLowerCase();
      final nameAr = '${r['name_ar'] ?? ''}'.toLowerCase();
      return code.contains(q) || nameAr.contains(q);
    }).toList();
  }

  // ── Helpers for rendering ───────────────────────────────────
  Color _categoryColor(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'asset':
        return AC.gold;
      case 'liability':
        return AC.err;
      case 'equity':
        return Colors.purpleAccent.shade100;
      case 'revenue':
        return AC.ok;
      case 'expense':
        return Colors.orangeAccent.shade100;
      default:
        return AC.ts;
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '-';
    final n = (v is num) ? v : double.tryParse(v.toString()) ?? 0;
    if (n == 0) return '-';
    return n.toStringAsFixed(2);
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<Map<String, dynamic>> get _sortedRows {
    final rows = List<Map<String, dynamic>>.from(_visibleRows);
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (_sortColumnIndex) {
        case 0:
          return ('${a['code'] ?? ''}').compareTo('${b['code'] ?? ''}');
        case 1:
          return ('${a['name_ar'] ?? ''}')
              .compareTo('${b['name_ar'] ?? ''}');
        case 2:
          return _num(a['total_debit'])
              .compareTo(_num(b['total_debit']));
        case 3:
          return _num(a['total_credit'])
              .compareTo(_num(b['total_credit']));
        case 4:
          return _num(a['balance']).compareTo(_num(b['balance']));
        default:
          return 0;
      }
    }

    rows.sort((a, b) => _sortAscending ? cmp(a, b) : -cmp(a, b));
    return rows;
  }

  double _num(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _asOf) {
      setState(() => _asOf = picked);
      _load();
    }
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildFilters(),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: _buildErrorState())
            else if (_data == null ||
                ((_data?['rows'] as List?)?.isEmpty ?? true))
              Expanded(child: _buildEmptyState())
            else ...[
              _buildSummaryCards(),
              Expanded(child: _buildTable()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            color: AC.tp,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'رجوع',
          ),
          Icon(Icons.table_chart, color: AC.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ميزان المراجعة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AC.tp,
                  ),
                ),
                Text(
                  'الأرصدة الفعلية للحسابات حتى التاريخ المحدد',
                  style: TextStyle(fontSize: 12, color: AC.ts),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AC.gold,
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Excel'),
            onPressed: _exportTodo,
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
            onPressed: _exportTodo,
          ),
        ],
      ),
    );
  }

  void _exportTodo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('قريبًا — تصدير Excel/PDF قيد التطوير'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AC.navy2.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(
              'كما في: ${_asOf.toIso8601String().split("T").first}',
            ),
            onPressed: _pickDate,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _hideZero,
                onChanged: (v) {
                  setState(() => _hideZero = v);
                  _load();
                },
              ),
              const SizedBox(width: 4),
              Text('إخفاء الحسابات الصفرية',
                  style: TextStyle(color: AC.tp, fontSize: 13)),
            ],
          ),
          SizedBox(
            width: 240,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'بحث: رمز الحساب أو الاسم',
                hintStyle: TextStyle(color: AC.td, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: AC.ts, size: 18),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalDebit = _num(_data?['total_debit']);
    final totalCredit = _num(_data?['total_credit']);
    final balanced = (_data?['balanced'] as bool?) ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              icon: Icons.trending_up,
              labelAr: 'إجمالي مدين',
              value: totalDebit,
              accent: AC.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              icon: Icons.trending_down,
              labelAr: 'إجمالي دائن',
              value: totalCredit,
              accent: AC.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              icon: balanced ? Icons.check_circle : Icons.error,
              labelAr: balanced ? 'متوازن' : 'غير متوازن',
              value: (totalDebit - totalCredit).abs(),
              accent: balanced ? AC.ok : AC.err,
              valuePrefix: balanced ? '0.00' : '∆ ',
              showValue: !balanced,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String labelAr,
    required double value,
    required Color accent,
    String? valuePrefix,
    bool showValue = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 6),
              Text(labelAr, style: TextStyle(color: AC.ts, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            showValue ? '${valuePrefix ?? ''}${value.toStringAsFixed(2)}'
                      : (valuePrefix ?? value.toStringAsFixed(2)),
            style: TextStyle(
              color: AC.tp,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final rows = _sortedRows;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'لا تطابق نتائج البحث',
          style: TextStyle(color: AC.td),
        ),
      );
    }
    final totalDebit = _num(_data?['total_debit']);
    final totalCredit = _num(_data?['total_credit']);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingTextStyle: TextStyle(
              color: AC.gold, fontWeight: FontWeight.w800, fontSize: 12),
          dataTextStyle: TextStyle(color: AC.tp, fontSize: 13),
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columns: [
            DataColumn(
              label: const Text('رمز الحساب'),
              onSort: _onSort,
            ),
            DataColumn(label: const Text('الاسم'), onSort: _onSort),
            DataColumn(
              label: const Text('مدين'),
              numeric: true,
              onSort: _onSort,
            ),
            DataColumn(
              label: const Text('دائن'),
              numeric: true,
              onSort: _onSort,
            ),
            DataColumn(
              label: const Text('الرصيد'),
              numeric: true,
              onSort: _onSort,
            ),
            const DataColumn(label: Text('الفئة')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text('${r['code'] ?? ''}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _categoryColor(r['category'] as String?)))),
                DataCell(SizedBox(
                  width: 280,
                  child: Text(
                    '${r['name_ar'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(Text(_fmt(r['total_debit']))),
                DataCell(Text(_fmt(r['total_credit']))),
                DataCell(Text(_fmt(r['balance']),
                    style: TextStyle(
                        color: AC.tp, fontWeight: FontWeight.w700))),
                DataCell(Text(
                  '${r['category'] ?? ''}',
                  style: TextStyle(
                      color: _categoryColor(r['category'] as String?),
                      fontSize: 11),
                )),
              ]),
            DataRow(
              color: WidgetStateProperty.all(
                  AC.gold.withValues(alpha: 0.08)),
              cells: [
                const DataCell(Text('')),
                DataCell(Text(
                  'الإجماليات',
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w900),
                )),
                DataCell(Text(
                  totalDebit.toStringAsFixed(2),
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w900),
                )),
                DataCell(Text(
                  totalCredit.toStringAsFixed(2),
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w900),
                )),
                const DataCell(Text('')),
                const DataCell(Text('')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AC.err, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'حدث خطأ غير متوقع',
              style: TextStyle(color: AC.tp, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: AC.td, size: 48),
            const SizedBox(height: 12),
            Text(
              'لا توجد قيود مرحّلة لهذه الفترة.',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'افتح شاشة قيود اليومية لإضافة قيد جديد.',
              style: TextStyle(color: AC.ts, fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('فتح قيود اليومية'),
              onPressed: () => context.go('/app/erp/finance/je-builder'),
            ),
          ],
        ),
      ),
    );
  }
}
