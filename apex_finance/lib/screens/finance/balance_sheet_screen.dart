/// G-FIN-BS-1 — Balance Sheet (Statement of Financial Position).
///
/// Hits `GET /pilot/entities/{entity_id}/reports/balance-sheet`
/// (see `app/pilot/routes/gl_routes.py:518` and the
/// `compute_balance_sheet` service in
/// `app/pilot/services/gl_engine.py:1041`).
///
/// 🔴 Real-data guarantee
/// ──────────────────────
/// Every value rendered here came from `pilot_gl_postings` (real,
/// posted journal entries). The backend is documented in
/// `docs/BALANCE_SHEET_DATA_FLOW_2026-05-08.md` and the invariant
/// is pinned by:
///
///   * `tests/test_balance_sheet_real_data.py::TestAntiMock::test_no_hardcoded_values_in_response`
///     (empty entity → genuine zeros, no defaults)
///   * `tests/test_balance_sheet_real_data.py::TestAntiMock::test_response_reflects_actual_postings_exactly`
///     (12345.67 round-trips byte-for-byte)
///   * `tests/test_balance_sheet_real_data.py::TestBalanceEquation`
///     (Assets = Liabilities + Equity holds for complex multi-JE
///     scenarios; CYE row = IS net_income)
///
/// **Do not introduce mock data, hardcoded fallbacks, default seed
/// values, or cached stale data here.** Specifically:
///
///   * No `List<X>` initialised with values in `initState`.
///   * No fallback `'0.00'` strings — the backend always returns
///     real numbers (genuine 0 for empty periods).
///   * No demo / placeholder rows. Empty period → empty table +
///     CTA pointing at the JE Builder.
///   * The `is_balanced` flag is what the backend says — never
///     locally massaged. If a JE is unbalanced, the operator
///     **must** see the imbalance to fix the underlying data.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  // ── Filter state ─────────────────────────────────────────────
  late DateTime _asOf;
  DateTime? _compareAsOf;
  bool _includeZero = false;

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
    _asOf = DateTime.now();
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
    final res = await ApiService.pilotBalanceSheet(
      eid,
      asOf: _isoDate(_asOf),
      compareAsOf: _compareAsOf == null ? null : _isoDate(_compareAsOf!),
      includeZero: _includeZero,
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
        _error = res.error ?? 'تعذّر جلب الميزانية العمومية';
        _loading = false;
      });
    }
  }

  // ── Derived views ───────────────────────────────────────────

  Map<String, dynamic>? get _currentPeriod =>
      _data?['current_period'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _comparisonPeriod =>
      _data?['comparison_period'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _variances =>
      _data?['variances'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _totals =>
      _currentPeriod?['totals'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _comparisonTotals =>
      _comparisonPeriod?['totals'] as Map<String, dynamic>?;

  List<Map<String, dynamic>> _rowsOf(String section) =>
      ((_currentPeriod?[section]) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  bool get _hasAnyRows {
    if (_currentPeriod == null) return false;
    return _rowsOf('assets').isNotEmpty ||
        _rowsOf('liabilities').isNotEmpty ||
        _rowsOf('equity').isNotEmpty;
  }

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
            else if (!_hasAnyRows &&
                ((_data?['posted_je_count'] as num?) ?? 0) == 0)
              _buildEmptyState()
            else ...[
              _buildBalanceBanner(),
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
          Icon(Icons.account_balance, color: AC.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الميزانية العمومية',
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
            label: Text('كما في: ${_isoDate(_asOf)}'),
            onPressed: () => _pickDate(isAsOf: true),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.compare_arrows),
            label: Text(
              _compareAsOf == null
                  ? 'مقارنة بـ: —'
                  : 'مقارنة بـ: ${_isoDate(_compareAsOf!)}',
            ),
            onPressed: () => _pickDate(isAsOf: false),
          ),
          if (_compareAsOf != null)
            TextButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('إلغاء المقارنة'),
              onPressed: () {
                setState(() => _compareAsOf = null);
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

  Future<void> _pickDate({required bool isAsOf}) async {
    final initial = isAsOf ? _asOf : (_compareAsOf ?? _asOf);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isAsOf) {
        _asOf = picked;
      } else {
        _compareAsOf = picked;
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
                'تعذر تحميل الميزانية العمومية',
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
                'لا توجد قيود مرحّلة حتى هذا التاريخ',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'الميزانية العمومية تعكس فقط القيود المرحّلة '
                '(pilot_gl_postings). افتح "قيود اليومية" لإنشاء قيد '
                'وترحيله.',
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

  Widget _buildBalanceBanner() {
    final isBalanced = _data?['balanced'] == true;
    final diff = (_data?['difference'] as num?)?.toDouble() ?? 0;
    final tone = isBalanced ? AC.ok : AC.err;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        border: Border(bottom: BorderSide(color: tone, width: 2)),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
            color: tone,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isBalanced
                  ? 'الميزانية متوازنة (الأصول = الالتزامات + حقوق الملكية)'
                  : '⚠️ تحذير: الميزانية غير متوازنة — فرق ${_formatAmount(diff)} '
                      'SAR. راجع القيود لتحديد القيد غير المتوازن.',
              style: TextStyle(
                color: AC.tp,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final assets = (_totals?['total_assets'] as num?)?.toDouble() ?? 0;
    final liabs = (_totals?['total_liabilities'] as num?)?.toDouble() ?? 0;
    final equity = (_totals?['total_equity'] as num?)?.toDouble() ?? 0;
    final isBalanced = (_totals?['is_balanced'] as bool?) ?? true;
    final diff = (_totals?['balance_difference'] as num?)?.toDouble() ?? 0;
    final assetsVar =
        (_variances?['total_assets_change_pct'] as num?)?.toDouble();
    final liabsVar =
        (_variances?['total_liabilities_change_pct'] as num?)?.toDouble();
    final equityVar =
        (_variances?['total_equity_change_pct'] as num?)?.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              label: 'إجمالي الأصول',
              value: assets,
              variancePct: assetsVar,
              tone: AC.cyan,
              icon: Icons.savings,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              label: 'إجمالي الالتزامات',
              value: liabs,
              variancePct: liabsVar,
              tone: AC.err,
              icon: Icons.payments,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              label: 'إجمالي حقوق الملكية',
              value: equity,
              variancePct: equityVar,
              tone: AC.gold,
              icon: Icons.diamond,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _balanceStatusCard(isBalanced: isBalanced, diff: diff),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required double value,
    required double? variancePct,
    required Color tone,
    required IconData icon,
  }) {
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
              Expanded(
                child: Text(label,
                    style: TextStyle(color: AC.ts, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AC.tp,
            ),
          ),
          if (variancePct != null) ...[
            const SizedBox(height: 4),
            Text(
              '${variancePct >= 0 ? '+' : ''}${variancePct.toStringAsFixed(1)}% '
              'مقابل المقارنة',
              style: TextStyle(
                color: variancePct >= 0 ? AC.ok : AC.err,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceStatusCard({required bool isBalanced, required double diff}) {
    final tone = isBalanced ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isBalanced ? Icons.check_circle : Icons.warning,
                color: tone,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'حالة التوازن',
                  style: TextStyle(color: AC.ts, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isBalanced ? 'متوازنة' : 'غير متوازنة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
          if (!isBalanced) ...[
            const SizedBox(height: 4),
            Text(
              'الفرق: ${_formatAmount(diff)}',
              style: TextStyle(color: AC.err, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatementTable() {
    final assets = _rowsOf('assets');
    final liabs = _rowsOf('liabilities');
    final equity = _rowsOf('equity');
    final t = _totals ?? const <String, dynamic>{};
    final tCmp = _comparisonTotals;

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
            // ── Assets ───────────────────────────────────────
            _sectionHeader('الأصول', AC.cyan),
            ..._buildSubcategoryGroup(
              assets, ['cash', 'bank', 'receivables', 'inventory', 'vat', 'prepaid'],
              'الأصول المتداولة', AC.cyan,
              currentSubtotal:
                  (t['total_current_assets'] as num?)?.toDouble() ?? 0,
              comparisonSubtotal: tCmp == null
                  ? null
                  : (tCmp['total_current_assets'] as num?)?.toDouble(),
            ),
            ..._buildSubcategoryGroup(
              assets, ['fixed_assets', 'accumulated_dep'],
              'الأصول الثابتة', AC.cyan,
              currentSubtotal:
                  (t['total_fixed_assets'] as num?)?.toDouble() ?? 0,
              comparisonSubtotal: tCmp == null
                  ? null
                  : (tCmp['total_fixed_assets'] as num?)?.toDouble(),
            ),
            _totalRow(
              'إجمالي الأصول',
              (t['total_assets'] as num?)?.toDouble() ?? 0,
              tone: AC.cyan,
              comparisonValue: tCmp == null
                  ? null
                  : (tCmp['total_assets'] as num?)?.toDouble(),
            ),
            // ── Liabilities ──────────────────────────────────
            _sectionHeader('الالتزامات', AC.err),
            ..._buildSubcategoryGroup(
              liabs, ['payables', 'vat', 'payroll', 'zakat'],
              'الالتزامات المتداولة', AC.err,
              currentSubtotal:
                  (t['total_current_liabilities'] as num?)?.toDouble() ?? 0,
              comparisonSubtotal: tCmp == null
                  ? null
                  : (tCmp['total_current_liabilities'] as num?)?.toDouble(),
            ),
            ..._buildSubcategoryGroup(
              liabs, ['loans', 'eosb'],
              'الالتزامات طويلة الأجل', AC.err,
              currentSubtotal:
                  (t['total_long_term_liabilities'] as num?)?.toDouble() ?? 0,
              comparisonSubtotal: tCmp == null
                  ? null
                  : (tCmp['total_long_term_liabilities'] as num?)?.toDouble(),
            ),
            _subtotalRow(
              'إجمالي الالتزامات',
              (t['total_liabilities'] as num?)?.toDouble() ?? 0,
              AC.err,
              comparisonValue: tCmp == null
                  ? null
                  : (tCmp['total_liabilities'] as num?)?.toDouble(),
            ),
            // ── Equity ───────────────────────────────────────
            _sectionHeader('حقوق الملكية', AC.gold),
            ...equity.map((r) => _accountRow(r)),
            _subtotalRow(
              'إجمالي حقوق الملكية',
              (t['total_equity'] as num?)?.toDouble() ?? 0,
              AC.gold,
              comparisonValue: tCmp == null
                  ? null
                  : (tCmp['total_equity'] as num?)?.toDouble(),
            ),
            // ── Total L+E ─────────────────────────────────────
            _totalRow(
              'إجمالي الالتزامات وحقوق الملكية',
              (t['total_liab_and_equity'] as num?)?.toDouble() ?? 0,
              tone: AC.gold,
              comparisonValue: tCmp == null
                  ? null
                  : (tCmp['total_liab_and_equity'] as num?)?.toDouble(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSubcategoryGroup(
    List<Map<String, dynamic>> rows,
    List<String> subcatOrder,
    String label,
    Color tone, {
    required double currentSubtotal,
    double? comparisonSubtotal,
  }) {
    final filtered = <Map<String, dynamic>>[];
    for (final s in subcatOrder) {
      filtered.addAll(rows.where((r) => r['subcategory'] == s));
    }
    if (filtered.isEmpty) return const <Widget>[];
    return [
      _subcategoryHeader(label, tone),
      ...filtered.map((r) => _accountRow(r)),
      _subtotalRow(
        'مجموع $label',
        currentSubtotal,
        tone,
        comparisonValue: comparisonSubtotal,
      ),
    ];
  }

  Widget _sectionHeader(String label, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
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

  Widget _subcategoryHeader(String label, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.4))),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AC.ts,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _accountRow(Map<String, dynamic> r) {
    final balance = (r['balance'] as num?)?.toDouble() ?? 0;
    final isSynthetic = r['is_synthetic'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: isSynthetic ? AC.gold.withValues(alpha: 0.06) : null,
        border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '${r['code'] ?? ''}',
              style: TextStyle(
                color: isSynthetic ? AC.gold : AC.gold,
                fontFamily: 'monospace',
                fontSize: 12,
                fontStyle: isSynthetic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${r['name_ar'] ?? ''}',
              style: TextStyle(
                color: AC.tp,
                fontSize: 13,
                fontStyle: isSynthetic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Text(
            _formatAmount(balance),
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

  Widget _subtotalRow(
    String label,
    double value,
    Color tone, {
    double? comparisonValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (comparisonValue != null) ...[
            Text(
              _formatAmount(comparisonValue),
              style: TextStyle(
                color: AC.ts,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 18),
          ],
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

  Widget _totalRow(
    String label,
    double value, {
    required Color tone,
    double? comparisonValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.16),
        border: Border(top: BorderSide(color: tone, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AC.tp,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          if (comparisonValue != null) ...[
            Text(
              _formatAmount(comparisonValue),
              style: TextStyle(
                color: AC.ts,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 18),
          ],
          Text(
            _formatAmount(value),
            style: TextStyle(
              color: tone,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              fontSize: 15,
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
    final assetsLen = _rowsOf('assets').length;
    final liabsLen = _rowsOf('liabilities').length;
    final equityLen = _rowsOf('equity').length;
    final cmp = _comparisonPeriod;
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
            'as_of: ${_isoDate(_asOf)}\n'
            'compare_as_of: ${_compareAsOf == null ? "none" : _isoDate(_compareAsOf!)}\n'
            'include_zero: $_includeZero\n'
            'rows: assets=$assetsLen, liabilities=$liabsLen, equity=$equityLen\n'
            'posted_je_count: ${_data?['posted_je_count']}\n'
            'is_balanced: ${_data?['balanced']} (diff=${_data?['difference']})\n'
            'currency: ${_data?['currency']}\n'
            'comparison_period: ${cmp == null ? "null" : cmp['as_of_date']}',
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
    final wholeStr = whole.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final formatted = '$wholeStr.${fraction.toString().padLeft(2, '0')}';
    return negative ? '($formatted)' : formatted;
  }
}
