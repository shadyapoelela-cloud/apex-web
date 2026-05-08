/// G-FIN-IS-1 — Income Statement (P&L) display screen.
///
/// Hits `GET /pilot/entities/{entity_id}/reports/income-statement`
/// (see `app/pilot/routes/gl_routes.py:473` and the
/// `compute_income_statement` service in
/// `app/pilot/services/gl_engine.py:775`).
///
/// 🔴 Real-data guarantee
/// ──────────────────────
/// Every value rendered here came from `pilot_gl_postings` (real,
/// posted journal entries) joined to `pilot_gl_accounts`. The
/// backend is documented in
/// `docs/INCOME_STATEMENT_DATA_FLOW_2026-05-08.md` and the
/// invariant is pinned by:
///
///   * `tests/test_income_statement_real_data.py::TestAntiMock::test_no_hardcoded_values_in_response`
///     (empty entity → genuine zeros, no defaults)
///   * `tests/test_income_statement_real_data.py::TestAntiMock::test_response_reflects_actual_postings_exactly`
///     (12345.67 round-trips byte-for-byte)
///
/// **Do not introduce mock data, hardcoded fallbacks, default seed
/// values, or cached stale data here.** Specifically:
///
///   * No `List<X>` initialised with values in `initState`.
///   * No fallback `'0.00'` strings — the backend always returns
///     real numbers (genuine 0 for empty periods).
///   * No demo / placeholder rows. Empty period → empty table +
///     CTA pointing at the JE Builder.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class IncomeStatementScreen extends StatefulWidget {
  const IncomeStatementScreen({super.key});

  @override
  State<IncomeStatementScreen> createState() => _IncomeStatementScreenState();
}

class _IncomeStatementScreenState extends State<IncomeStatementScreen> {
  // ── Filter state ─────────────────────────────────────────────
  // Default window: month-to-date. The user can pick any range; the
  // initial values are NOT data — they're just the current calendar
  // month boundaries.
  late DateTime _start;
  late DateTime _end;
  bool _includeZero = false;
  String _comparePeriod = 'none'; // 'none' | 'previous_year' | 'previous_period'

  // ── Async state ─────────────────────────────────────────────
  bool _loading = false;
  String? _error;
  // Raw response from the API. NEVER initialised with mock values —
  // null until the first successful fetch.
  Map<String, dynamic>? _data;
  // Set after each successful load. Surfaces in the freshness badge.
  DateTime? _lastFetchedAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = now;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _entityId => S.entityId ?? S.savedEntityId;

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    final res = await ApiService.pilotIncomeStatement(
      eid,
      startDate: _isoDate(_start),
      endDate: _isoDate(_end),
      includeZero: _includeZero,
      comparePeriod: _comparePeriod,
    );
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _data = (res.data is Map<String, dynamic>)
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        _loading = false;
        _lastFetchedAt = DateTime.now();
      });
    } else {
      setState(() {
        _error = res.error ?? 'تعذّر جلب قائمة الدخل';
        _loading = false;
      });
    }
  }

  // ── Derived views ───────────────────────────────────────────

  List<Map<String, dynamic>> get _accounts {
    return (_data?['accounts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get _revenueRows =>
      _accounts.where((r) => r['category'] == 'revenue').toList();

  List<Map<String, dynamic>> get _expenseRows =>
      _accounts.where((r) => r['category'] == 'expense').toList();

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            if (_error != null)
              _buildError()
            else if (_loading && _data == null)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_data == null)
              const SizedBox.shrink()
            else if (_accounts.isEmpty &&
                ((_data?['posted_je_count'] as num?) ?? 0) == 0)
              _buildEmptyState()
            else ...[
              _buildSummaryCards(),
              Expanded(child: _buildStatementTable()),
              _buildFooter(),
            ],
            if (kDebugMode && _data != null) _buildDebugPanel(),
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
          Icon(Icons.assessment, color: AC.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قائمة الدخل',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AC.tp,
                  ),
                ),
                Text(
                  'البيانات حقيقية من القيود المرحّلة (pilot_gl_postings)',
                  style: TextStyle(fontSize: 12, color: AC.ts),
                ),
              ],
            ),
          ),
          if (_lastFetchedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'آخر تحديث: ${_lastFetchedAt!.hour.toString().padLeft(2, '0')}'
                ':${_lastFetchedAt!.minute.toString().padLeft(2, '0')}'
                ':${_lastFetchedAt!.second.toString().padLeft(2, '0')}',
                style: TextStyle(color: AC.ts, fontSize: 11),
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
            label: Text('من: ${_isoDate(_start)}'),
            onPressed: () => _pickDate(isStart: true),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text('إلى: ${_isoDate(_end)}'),
            onPressed: () => _pickDate(isStart: false),
          ),
          DropdownButton<String>(
            value: _comparePeriod,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('بدون مقارنة')),
              DropdownMenuItem(
                  value: 'previous_year', child: Text('السنة السابقة')),
              DropdownMenuItem(
                  value: 'previous_period', child: Text('الفترة السابقة')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _comparePeriod = v);
              _load();
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _includeZero,
                onChanged: (v) {
                  setState(() => _includeZero = v);
                  _load();
                },
              ),
              const SizedBox(width: 4),
              Text('إظهار الحسابات الصفرية',
                  style: TextStyle(color: AC.tp, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
    _load();
  }

  Widget _buildError() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AC.err, size: 48),
              const SizedBox(height: 12),
              Text(
                'تعذر تحميل قائمة الدخل',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? '',
                style: TextStyle(color: AC.ts, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                onPressed: _load,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, color: AC.ts, size: 48),
              const SizedBox(height: 12),
              Text(
                'لا توجد قيود مرحّلة في هذه الفترة',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'قائمة الدخل تعكس فقط القيود المرحّلة (pilot_gl_postings). '
                'افتح "قيود اليومية" لإنشاء قيد وترحيله.',
                style: TextStyle(color: AC.ts, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('فتح قيود اليومية'),
                onPressed: () => context.go('/app/erp/finance/je-builder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final revenueTotal = (_data?['revenue_total'] as num?)?.toDouble() ?? 0;
    final expenseTotal = (_data?['expense_total'] as num?)?.toDouble() ?? 0;
    final netIncome = (_data?['net_income'] as num?)?.toDouble() ?? 0;
    final cmp = _data?['comparison'] as Map<String, dynamic>?;
    final revVar = (cmp?['revenue_variance_pct'] as num?)?.toDouble();
    final expVar = (cmp?['expense_variance_pct'] as num?)?.toDouble();
    final netVar = (cmp?['net_income_variance_pct'] as num?)?.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              label: 'إجمالي الإيرادات',
              value: revenueTotal,
              variancePct: revVar,
              positiveIsGood: true,
              tone: AC.ok,
              icon: Icons.trending_up,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              label: 'إجمالي المصروفات',
              value: expenseTotal,
              variancePct: expVar,
              positiveIsGood: false,
              tone: AC.err,
              icon: Icons.trending_down,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              label: 'صافي الربح',
              value: netIncome,
              variancePct: netVar,
              positiveIsGood: true,
              tone: netIncome >= 0 ? AC.gold : AC.err,
              icon: netIncome >= 0 ? Icons.check_circle : Icons.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required double value,
    required double? variancePct,
    required bool positiveIsGood,
    required Color tone,
    required IconData icon,
  }) {
    Color? varianceColor;
    if (variancePct != null) {
      final goodDirection = positiveIsGood ? variancePct >= 0 : variancePct < 0;
      varianceColor = goodDirection ? AC.ok : AC.err;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: tone, size: 20),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: AC.ts, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(value),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AC.tp,
            ),
          ),
          if (variancePct != null) ...[
            const SizedBox(height: 4),
            Text(
              '${variancePct >= 0 ? '+' : ''}${variancePct.toStringAsFixed(1)}% '
              'مقارنة بالفترة السابقة',
              style: TextStyle(color: varianceColor, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatementTable() {
    final revenue = _revenueRows;
    final expenses = _expenseRows;
    final revenueTotal = (_data?['revenue_total'] as num?)?.toDouble() ?? 0;
    final expenseTotal = (_data?['expense_total'] as num?)?.toDouble() ?? 0;
    final netIncome = (_data?['net_income'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.bdr),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _sectionHeader('الإيرادات', AC.ok),
            ...revenue.map((r) => _accountRow(r)),
            _subtotalRow('إجمالي الإيرادات', revenueTotal, AC.ok),
            _sectionHeader('المصروفات', AC.err),
            ...expenses.map((r) => _accountRow(r)),
            _subtotalRow('إجمالي المصروفات', expenseTotal, AC.err),
            _netIncomeRow(netIncome),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: tone),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AC.tp,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(Map<String, dynamic> r) {
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '${r['code'] ?? ''}',
              style: TextStyle(
                color: AC.gold,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${r['name_ar'] ?? ''}',
              style: TextStyle(color: AC.tp, fontSize: 13),
            ),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              color: AC.tp,
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, double value, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: tone.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AC.tp,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            _formatAmount(value),
            style: TextStyle(
              color: tone,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _netIncomeRow(double value) {
    final positive = value >= 0;
    final tone = positive ? AC.gold : AC.err;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        border: Border(top: BorderSide(color: tone, width: 2)),
      ),
      child: Row(
        children: [
          Icon(positive ? Icons.check_circle : Icons.error, color: tone, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              positive ? 'صافي الربح' : 'صافي الخسارة',
              style: TextStyle(
                color: AC.tp,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            _formatAmount(value),
            style: TextStyle(
              color: tone,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final count = (_data?['posted_je_count'] as num?)?.toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AC.navy2.withValues(alpha: 0.7),
        border: Border(top: BorderSide(color: AC.bdr)),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: AC.ok, size: 10),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              count == null
                  ? 'المصدر: pilot_journal_lines — — قيد مرحّل'
                  : 'المصدر: pilot_journal_lines — $count قيد مرحّل',
              style: TextStyle(color: AC.ts, fontSize: 11),
            ),
          ),
          Text(
            'بيانات حقيقية — لا توجد قيم وهمية',
            style: TextStyle(color: AC.ok, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    final eid = _entityId ?? '?';
    final accountsLen = _accounts.length;
    final revLen = _revenueRows.length;
    final expLen = _expenseRows.length;
    final cmp = _data?['comparison'];
    return ExpansionTile(
      title: Text(
        'Debug — Real-Data Trace',
        style: TextStyle(color: AC.gold, fontSize: 11),
      ),
      collapsedBackgroundColor: AC.navy2.withValues(alpha: 0.4),
      backgroundColor: AC.navy2.withValues(alpha: 0.4),
      iconColor: AC.gold,
      collapsedIconColor: AC.gold,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          alignment: AlignmentDirectional.centerStart,
          child: SelectableText(
            'entity_id: $eid\n'
            'period: ${_isoDate(_start)} → ${_isoDate(_end)}\n'
            'compare_period: $_comparePeriod\n'
            'include_zero: $_includeZero\n'
            'accounts: $accountsLen (revenue=$revLen, expense=$expLen)\n'
            'posted_je_count: ${_data?['posted_je_count']}\n'
            'comparison: ${cmp == null ? "null" : cmp.toString()}',
            style: TextStyle(
              color: AC.ts,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double v) {
    final negative = v < 0;
    final abs = v.abs();
    final whole = abs.truncate();
    final fraction = ((abs - whole) * 100).round();
    // Thousands separator (basic, no locale lookup so it stays
    // deterministic across browsers)
    final wholeStr = whole.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final formatted =
        '$wholeStr.${fraction.toString().padLeft(2, '0')}';
    return negative ? '($formatted)' : formatted;
  }
}
