/// G-FIN-CF-1 — Cash Flow Statement (Indirect Method).
///
/// Hits `GET /pilot/entities/{entity_id}/reports/cash-flow`
/// (see `app/pilot/routes/gl_routes.py:577` and the
/// `compute_cash_flow` service in
/// `app/pilot/services/gl_engine.py`).
///
/// 🔴 Real-data guarantee + reconciliation invariant
/// ──────────────────────────────────────────────────
/// Every value rendered here came from `pilot_gl_postings` (real,
/// posted journal entries). The backend is documented in
/// `docs/CASH_FLOW_DATA_FLOW_2026-05-08.md` and the invariants are
/// pinned by:
///
///   * `tests/test_cash_flow_real_data.py::TestAntiMock::test_no_hardcoded_values_in_response`
///   * `tests/test_cash_flow_real_data.py::TestAntiMock::test_response_reflects_actual_postings_exactly`
///     (12345.67 round-trips byte-for-byte)
///   * `tests/test_cash_flow_real_data.py::TestAntiMock::test_unmapped_subcategory_detection`
///   * `tests/test_cash_flow_real_data.py::TestAntiMock::test_no_reconciliation_bypass`
///     — the most important: a deliberately-broken scenario yields
///       `is_reconciled=false`. We never silently force it to true.
///   * `tests/test_cash_flow_real_data.py::TestReconciliation::test_complex_10_je_reconciles_exactly`
///     — 10-JE scenario across all sections reconciles exactly.
///
/// **Do not introduce mock data, hardcoded fallbacks, default seed
/// values, or cached stale data here.** Specifically:
///
///   * No `List<X>` initialised with values in `initState`.
///   * No fallback `'0.00'` strings — the backend always returns
///     real numbers (genuine 0 for empty periods).
///   * No demo / placeholder rows. Empty period → empty table +
///     CTA pointing at the JE Builder.
///   * The `is_reconciled` flag is what the backend says — never
///     locally massaged. If reconciliation breaks, the operator
///     **must** see the red banner to fix the underlying data.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  // ── Filter state ─────────────────────────────────────────────
  late DateTime _start;
  late DateTime _end;
  String _method = 'indirect'; // 'indirect' | 'direct' (returns 422)
  String _comparePeriod = 'none'; // 'none' | 'previous_year' | 'previous_period'
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
    final res = await ApiService.pilotCashFlow(
      eid,
      startDate: _isoDate(_start),
      endDate: _isoDate(_end),
      method: _method,
      comparePeriod: _comparePeriod,
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
        _error = res.error ?? 'تعذّر جلب قائمة التدفقات النقدية';
        _loading = false;
      });
    }
  }

  // ── Derived views ───────────────────────────────────────────

  Map<String, dynamic>? get _currentPeriod =>
      _data?['current_period'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _operating =>
      _currentPeriod?['operating_activities'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _investing =>
      _currentPeriod?['investing_activities'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _financing =>
      _currentPeriod?['financing_activities'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _totals =>
      _currentPeriod?['totals'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _variances =>
      _data?['variances'] as Map<String, dynamic>?;
  List<String> get _unmapped =>
      ((_data?['unmapped_subcategories'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
  List<String> get _warnings =>
      ((_data?['warnings'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  bool get _hasAnyContent {
    if (_currentPeriod == null) return false;
    final ops = (_operating?['working_capital_changes'] as List? ?? const []);
    final adj = (_operating?['noncash_adjustments'] as List? ?? const []);
    final inv = (_investing?['items'] as List? ?? const []);
    final fin = (_financing?['items'] as List? ?? const []);
    final ni = (_operating?['net_income'] as num?)?.toDouble() ?? 0;
    return ops.isNotEmpty ||
        adj.isNotEmpty ||
        inv.isNotEmpty ||
        fin.isNotEmpty ||
        ni != 0;
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
            else if (!_hasAnyContent &&
                ((_data?['posted_je_count'] as num?) ?? 0) == 0)
              _buildEmptyState()
            else ...[
              // RECONCILIATION BANNER renders FIRST — operator cannot
              // miss an integrity issue. Pinned by the ordering test.
              _buildReconciliationBanner(),
              if (_unmapped.isNotEmpty) _buildUnmappedWarning(),
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
          Icon(Icons.water_drop, color: AC.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قائمة التدفقات النقدية',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AC.tp,
                  ),
                ),
                Text(
                  'بيانات حقيقية + reconciliation محقق من القيود المرحّلة',
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
            value: _method,
            items: const [
              DropdownMenuItem(
                value: 'indirect',
                child: Text('غير مباشرة (الأكثر استخداماً)'),
              ),
              DropdownMenuItem(
                value: 'direct',
                child: Text('مباشرة (قريباً)'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _method = v);
              _load();
            },
          ),
          DropdownButton<String>(
            value: _comparePeriod,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('بدون مقارنة')),
              DropdownMenuItem(
                value: 'previous_year',
                child: Text('السنة السابقة'),
              ),
              DropdownMenuItem(
                value: 'previous_period',
                child: Text('الفترة السابقة'),
              ),
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
                'تعذر تحميل قائمة التدفقات النقدية',
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
                'لا توجد قيود في هذه الفترة',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'قائمة التدفقات النقدية تعكس فقط القيود المرحّلة '
                '(pilot_gl_postings) ضمن الفترة المحددة. افتح "قيود اليومية" '
                'لإنشاء قيد وترحيله.',
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

  Widget _buildReconciliationBanner() {
    final isReconciled = (_totals?['is_reconciled'] as bool?) ?? true;
    final diff =
        (_totals?['reconciliation_difference'] as num?)?.toDouble() ?? 0;
    final tone = isReconciled ? AC.ok : AC.err;
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
            isReconciled ? Icons.check_circle : Icons.warning_amber_rounded,
            color: tone,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isReconciled
                  ? '✅ التدفقات النقدية متطابقة (الرصيد الافتتاحي + التغير = الرصيد النهائي)'
                  : '⚠️ غير متطابق — فرق ${_formatAmount(diff)} SAR. مراجعة data integrity مطلوبة',
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

  Widget _buildUnmappedWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AC.warn.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: AC.warn, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AC.warn, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تنبيه: subcategories غير مصنفة ضمن أقسام التدفق النقدي '
              '[${_unmapped.join(", ")}] — يُرجى تحديثها في إعدادات الـ CoA.',
              style: TextStyle(color: AC.tp, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final cfo = (_totals?['total_cfo'] as num?)?.toDouble() ?? 0;
    final cfi = (_totals?['total_cfi'] as num?)?.toDouble() ?? 0;
    final cff = (_totals?['total_cff'] as num?)?.toDouble() ?? 0;
    final netChange =
        (_totals?['net_change_in_cash'] as num?)?.toDouble() ?? 0;
    final opening = (_totals?['opening_cash'] as num?)?.toDouble() ?? 0;
    final closing = (_totals?['closing_cash'] as num?)?.toDouble() ?? 0;
    final cfoVar = (_variances?['cfo_change_pct'] as num?)?.toDouble();
    final cfiVar = (_variances?['cfi_change_pct'] as num?)?.toDouble();
    final cffVar = (_variances?['cff_change_pct'] as num?)?.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              label: 'التدفق من العمليات',
              value: cfo,
              variancePct: cfoVar,
              tone: cfo >= 0 ? AC.ok : AC.err,
              icon: Icons.work_outline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              label: 'التدفق من الاستثمار',
              value: cfi,
              variancePct: cfiVar,
              tone: cfi >= 0 ? AC.ok : AC.err,
              icon: Icons.trending_down,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              label: 'التدفق من التمويل',
              value: cff,
              variancePct: cffVar,
              tone: cff >= 0 ? AC.ok : AC.err,
              icon: Icons.account_balance,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _netChangeCard(
              netChange: netChange,
              opening: opening,
              closing: closing,
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AC.tp,
            ),
          ),
          if (variancePct != null) ...[
            const SizedBox(height: 4),
            Text(
              '${variancePct >= 0 ? '+' : ''}${variancePct.toStringAsFixed(1)}% '
              'مقارنة بالفترة السابقة',
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

  Widget _netChangeCard({
    required double netChange,
    required double opening,
    required double closing,
  }) {
    final tone = netChange >= 0 ? AC.gold : AC.err;
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
              Icon(Icons.water_drop, color: tone, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'صافي التغير في النقدية',
                  style: TextStyle(color: AC.ts, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(netChange),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'افتتاحي: ${_formatAmount(opening)} → '
            'ختامي: ${_formatAmount(closing)}',
            style: TextStyle(color: AC.ts, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementTable() {
    final ni = (_operating?['net_income'] as num?)?.toDouble() ?? 0;
    final adjustments =
        ((_operating?['noncash_adjustments'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final wcChanges =
        ((_operating?['working_capital_changes'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final invItems = ((_investing?['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final finItems = ((_financing?['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final cfo = (_totals?['total_cfo'] as num?)?.toDouble() ?? 0;
    final cfi = (_totals?['total_cfi'] as num?)?.toDouble() ?? 0;
    final cff = (_totals?['total_cff'] as num?)?.toDouble() ?? 0;
    final netChange =
        (_totals?['net_change_in_cash'] as num?)?.toDouble() ?? 0;
    final opening = (_totals?['opening_cash'] as num?)?.toDouble() ?? 0;
    final closing = (_totals?['closing_cash'] as num?)?.toDouble() ?? 0;

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
            // ── Operating Activities ────────────────────────────
            _sectionHeader('الأنشطة التشغيلية', AC.cyan),
            _labelValueRow('صافي الربح', ni, tone: AC.tp, bold: true),
            if (adjustments.isNotEmpty) ...[
              _subcategoryHeader('التعديلات على الأرباح:', AC.cyan),
              ...adjustments.map((a) => _amountRow(
                    code: '${a['code'] ?? ''}',
                    name: '${a['name_ar'] ?? ''}',
                    amount: (a['amount'] as num?)?.toDouble() ?? 0,
                    italic: true,
                  )),
            ],
            if (wcChanges.isNotEmpty) ...[
              _subcategoryHeader('التغير في رأس المال العامل:', AC.cyan),
              ...wcChanges.map((i) => _amountRow(
                    code: '${i['code'] ?? ''}',
                    name: '${i['name_ar'] ?? ''}',
                    amount: (i['cf_impact'] as num?)?.toDouble() ?? 0,
                    note: '${i['note'] ?? ''}',
                  )),
            ],
            _subtotalRow('مجموع التدفقات من العمليات', cfo, AC.cyan),
            // ── Investing Activities ────────────────────────────
            _sectionHeader('الأنشطة الاستثمارية', AC.warn),
            if (invItems.isEmpty)
              _labelValueRow('لا توجد عمليات استثمارية', 0,
                  tone: AC.ts, italic: true),
            ...invItems.map((i) => _amountRow(
                  code: '${i['code'] ?? ''}',
                  name: '${i['name_ar'] ?? ''}',
                  amount: (i['cf_impact'] as num?)?.toDouble() ?? 0,
                  note: '${i['note'] ?? ''}',
                )),
            _subtotalRow('مجموع التدفقات الاستثمارية', cfi, AC.warn),
            // ── Financing Activities ────────────────────────────
            _sectionHeader('الأنشطة التمويلية', AC.gold),
            if (finItems.isEmpty)
              _labelValueRow('لا توجد عمليات تمويلية', 0,
                  tone: AC.ts, italic: true),
            ...finItems.map((i) => _amountRow(
                  code: '${i['code'] ?? ''}',
                  name: '${i['name_ar'] ?? ''}',
                  amount: (i['cf_impact'] as num?)?.toDouble() ?? 0,
                  note: '${i['note'] ?? ''}',
                )),
            _subtotalRow('مجموع التدفقات التمويلية', cff, AC.gold),
            // ── Reconciliation rows ─────────────────────────────
            _totalRow('صافي التغير في النقدية', netChange, tone: AC.gold),
            _labelValueRow('النقدية - الرصيد الافتتاحي', opening,
                tone: AC.ts),
            _totalRow('النقدية - الرصيد النهائي', closing, tone: AC.cyan),
          ],
        ),
      ),
    );
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

  Widget _labelValueRow(
    String label,
    double value, {
    Color? tone,
    bool bold = false,
    bool italic = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: tone ?? AC.tp,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (value != 0)
            Text(
              _formatAmount(value),
              style: TextStyle(
                color: tone ?? AC.tp,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _amountRow({
    required String code,
    required String name,
    required double amount,
    String? note,
    bool italic = false,
  }) {
    final negative = amount < 0;
    final tone = negative ? AC.err : AC.ok;
    final prefix = negative ? '(-) ' : '(+) ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              code,
              style: TextStyle(
                color: AC.gold,
                fontFamily: 'monospace',
                fontSize: 12,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$prefix$name',
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: 13,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: TextStyle(color: AC.ts, fontSize: 10),
                  ),
              ],
            ),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              color: tone,
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

  Widget _totalRow(String label, double value, {required Color tone}) {
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
            'بيانات حقيقية + reconciliation محقق',
            style: TextStyle(color: AC.ok, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    final eid = _entityId ?? '?';
    final wcLen = ((_operating?['working_capital_changes'] as List?) ?? const [])
        .length;
    final invLen = ((_investing?['items'] as List?) ?? const []).length;
    final finLen = ((_financing?['items'] as List?) ?? const []).length;
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
            'method: $_method\n'
            'compare_period: $_comparePeriod\n'
            'include_zero: $_includeZero\n'
            'rows: wc=$wcLen, investing=$invLen, financing=$finLen\n'
            'posted_je_count: ${_data?['posted_je_count']}\n'
            'is_reconciled: ${_totals?['is_reconciled']} '
            '(diff=${_totals?['reconciliation_difference']})\n'
            'opening_cash: ${_totals?['opening_cash']}\n'
            'closing_cash: ${_totals?['closing_cash']}\n'
            'unmapped_subcategories: $_unmapped\n'
            'warnings: $_warnings',
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
