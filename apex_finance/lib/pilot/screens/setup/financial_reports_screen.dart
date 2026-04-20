/// Financial Reports — الأستاذ العام والقوائم المالية.
///
/// مستقلة — تعتمد على PilotSession.entityId.
///
/// التبويبات:
///   1) ميزان المراجعة (Trial Balance) — as_of date
///   2) قائمة الدخل (Income Statement) — period range
///   3) قائمة المركز المالي (Balance Sheet) — as_of date
library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
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
const _indigo = Color(0xFF6366F1);

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});
  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final PilotClient _client = pilotClient;

  Map<String, dynamic>? _trialBalance;
  Map<String, dynamic>? _incomeStatement;
  Map<String, dynamic>? _balanceSheet;
  bool _loading = true;
  String? _error;

  DateTime _asOfDate = DateTime.now();
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTabChange);
    _load();
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChange);
    _tab.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (_tab.indexIsChanging) return;
    _load();
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
    try {
      if (_tab.index == 0) {
        final r = await _client.trialBalance(eid,
            asOf: _asOfDate.toIso8601String().substring(0, 10),
            includeZero: false);
        if (r.success && r.data is Map) {
          _trialBalance = Map<String, dynamic>.from(r.data);
        } else {
          _error = r.error;
        }
      } else if (_tab.index == 1) {
        final r = await _client.incomeStatement(
            eid,
            _startDate.toIso8601String().substring(0, 10),
            _endDate.toIso8601String().substring(0, 10));
        if (r.success && r.data is Map) {
          _incomeStatement = Map<String, dynamic>.from(r.data);
        } else {
          _error = r.error;
        }
      } else {
        final r = await _client.balanceSheet(eid,
            asOf: _asOfDate.toIso8601String().substring(0, 10));
        if (r.success && r.data is Map) {
          _balanceSheet = Map<String, dynamic>.from(r.data);
        } else {
          _error = r.error;
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
              tabs: const [
                Tab(icon: Icon(Icons.balance, size: 16), text: 'ميزان المراجعة'),
                Tab(icon: Icon(Icons.trending_up, size: 16), text: 'قائمة الدخل'),
                Tab(icon: Icon(Icons.account_balance, size: 16), text: 'المركز المالي'),
              ],
            ),
          ),
          _dateControls(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : TabBarView(controller: _tab, children: [
                        _trialBalanceTab(),
                        _incomeStatementTab(),
                        _balanceSheetTab(),
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
          child: const Icon(Icons.assessment, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('التقارير المالية',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('ميزان المراجعة · قائمة الدخل · قائمة المركز المالي',
                style: TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: const BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
      ]),
    );
  }

  Widget _dateControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: _navy2.withValues(alpha: 0.5),
      child: Row(children: [
        if (_tab.index == 1) ...[
          const Text('من:', style: TextStyle(color: _td, fontSize: 12)),
          const SizedBox(width: 6),
          _datePill(_startDate, (d) {
            setState(() => _startDate = d);
            _load();
          }),
          const SizedBox(width: 10),
          const Text('إلى:', style: TextStyle(color: _td, fontSize: 12)),
          const SizedBox(width: 6),
          _datePill(_endDate, (d) {
            setState(() => _endDate = d);
            _load();
          }),
          const SizedBox(width: 16),
          _quickPeriod('هذا الشهر', () {
            final now = DateTime.now();
            setState(() {
              _startDate = DateTime(now.year, now.month, 1);
              _endDate = now;
            });
            _load();
          }),
          const SizedBox(width: 6),
          _quickPeriod('YTD', () {
            final now = DateTime.now();
            setState(() {
              _startDate = DateTime(now.year, 1, 1);
              _endDate = now;
            });
            _load();
          }),
        ] else ...[
          const Text('كما في:', style: TextStyle(color: _td, fontSize: 12)),
          const SizedBox(width: 6),
          _datePill(_asOfDate, (d) {
            setState(() => _asOfDate = d);
            _load();
          }),
          const SizedBox(width: 16),
          _quickPeriod('اليوم', () {
            setState(() => _asOfDate = DateTime.now());
            _load();
          }),
          const SizedBox(width: 6),
          _quickPeriod('نهاية الشهر', () {
            final now = DateTime.now();
            setState(() => _asOfDate = DateTime(now.year, now.month + 1, 0));
            _load();
          }),
        ],
      ]),
    );
  }

  Widget _datePill(DateTime date, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onChanged(d);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today, color: _gold, size: 12),
          const SizedBox(width: 4),
          Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  color: _tp, fontSize: 11, fontFamily: 'monospace')),
        ]),
      ),
    );
  }

  Widget _quickPeriod(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.3))),
        child: Text(label,
            style: const TextStyle(
                color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 1: Trial Balance
  // ════════════════════════════════════════════════════════════════════

  Widget _trialBalanceTab() {
    final tb = _trialBalance;
    if (tb == null) {
      return const Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    final rows = (tb['rows'] as List?) ?? [];
    final totalDebit = (tb['total_debits'] ?? 0).toDouble();
    final totalCredit = (tb['total_credits'] ?? 0).toDouble();
    final balanced = (totalDebit - totalCredit).abs() < 0.01;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance check banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (balanced ? _ok : _err).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (balanced ? _ok : _err).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(balanced ? Icons.check_circle : Icons.warning,
                color: balanced ? _ok : _err, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  balanced
                      ? 'الميزان متوازن ✓ مجموع المدين = مجموع الدائن'
                      : 'الميزان غير متوازن! الفرق: ${_fmt((totalDebit - totalCredit).abs())}',
                  style: TextStyle(
                      color: balanced ? _ok : _err,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('مدين: ${_fmt(totalDebit)}',
                    style: const TextStyle(
                        color: _ok,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
                Text('دائن: ${_fmt(totalCredit)}',
                    style: const TextStyle(
                        color: _indigo,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: const [
            SizedBox(width: 90, child: Text('الكود', style: _th)),
            Expanded(flex: 3, child: Text('اسم الحساب', style: _th)),
            SizedBox(width: 90, child: Text('الفئة', style: _th)),
            SizedBox(
                width: 140,
                child: Text('مدين', style: _th, textAlign: TextAlign.end)),
            SizedBox(
                width: 140,
                child: Text('دائن', style: _th, textAlign: TextAlign.end)),
            SizedBox(
                width: 140,
                child: Text('الرصيد', style: _th, textAlign: TextAlign.end)),
          ]),
        ),
        const SizedBox(height: 6),
        ...rows.map((r) => _tbRow(Map<String, dynamic>.from(r))),
      ],
    );
  }

  Widget _tbRow(Map<String, dynamic> r) {
    final debit = (r['total_debit'] ?? 0).toDouble();
    final credit = (r['total_credit'] ?? 0).toDouble();
    final balance = (r['balance'] ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(r['code'] ?? '',
              style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['name_ar'] ?? '',
                  style: const TextStyle(color: _tp, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              if ((r['name_en'] ?? '').toString().isNotEmpty)
                Text(r['name_en'],
                    style: const TextStyle(color: _td, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(_categoryAr(r['category']),
              style: const TextStyle(color: _ts, fontSize: 11)),
        ),
        SizedBox(
          width: 140,
          child: Text(debit > 0 ? _fmt(debit) : '—',
              style: TextStyle(
                  color: debit > 0 ? _ok : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 140,
          child: Text(credit > 0 ? _fmt(credit) : '—',
              style: TextStyle(
                  color: credit > 0 ? _indigo : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 140,
          child: Text(_fmt(balance.abs()),
              style: TextStyle(
                  color: balance > 0 ? _ok : balance < 0 ? _err : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 2: Income Statement
  // ════════════════════════════════════════════════════════════════════

  Widget _incomeStatementTab() {
    final is_ = _incomeStatement;
    if (is_ == null) {
      return const Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    final revenue = (is_['total_revenue'] ?? 0).toDouble();
    final expenses = (is_['total_expenses'] ?? 0).toDouble();
    final netIncome = (is_['net_income'] ?? (revenue - expenses)).toDouble();
    final revenueAccts = (is_['revenue_accounts'] as List?) ?? [];
    final expenseAccts = (is_['expense_accounts'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top summary
        Row(children: [
          Expanded(child: _summaryCard('الإيرادات', revenue, _ok)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('المصروفات', expenses, _err)),
          const SizedBox(width: 10),
          Expanded(
              child: _summaryCard(
                  netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                  netIncome.abs(),
                  netIncome >= 0 ? _gold : _err)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader('الإيرادات', Icons.trending_up, _ok),
        const SizedBox(height: 6),
        ...revenueAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _ok)),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _ok.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _ok.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Text('إجمالي الإيرادات',
                style: TextStyle(
                    color: _ok,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(revenue),
                style: const TextStyle(
                    color: _ok,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        _sectionHeader('المصروفات', Icons.trending_down, _err),
        const SizedBox(height: 6),
        ...expenseAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _err)),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _err.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _err.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Text('إجمالي المصروفات',
                style: TextStyle(
                    color: _err,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(expenses),
                style: const TextStyle(
                    color: _err,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        // Net income bold box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Row(children: [
            Icon(netIncome >= 0 ? Icons.celebration : Icons.warning,
                color: netIncome >= 0 ? _gold : _err, size: 28),
            const SizedBox(width: 12),
            Text(netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                style: const TextStyle(
                    color: _tp,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(netIncome.abs()),
                style: TextStyle(
                    color: netIncome >= 0 ? _gold : _err,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
          ]),
        ),
      ],
    );
  }

  Widget _isRow(Map<String, dynamic> a, Color color) {
    final bal = (a['balance'] ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(a['code'] ?? '',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        Expanded(
          child: Text(a['name_ar'] ?? '',
              style: const TextStyle(color: _tp, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        Text(_fmt(bal.abs()),
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 3: Balance Sheet
  // ════════════════════════════════════════════════════════════════════

  Widget _balanceSheetTab() {
    final bs = _balanceSheet;
    if (bs == null) {
      return const Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    final assets = (bs['total_assets'] ?? 0).toDouble();
    final liabs = (bs['total_liabilities'] ?? 0).toDouble();
    final equity = (bs['total_equity'] ?? 0).toDouble();
    final balanced = ((assets - (liabs + equity)).abs() < 0.01);

    final assetAccts = (bs['asset_accounts'] as List?) ?? [];
    final liabAccts = (bs['liability_accounts'] as List?) ?? [];
    final equityAccts = (bs['equity_accounts'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Equation banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (balanced ? _ok : _err).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (balanced ? _ok : _err).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(balanced ? Icons.check_circle : Icons.warning,
                color: balanced ? _ok : _err, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  balanced
                      ? 'المعادلة المحاسبية متوازنة ✓ (أصول = خصوم + حقوق ملكية)'
                      : 'غير متوازنة! الفرق: ${_fmt((assets - (liabs + equity)).abs())}',
                  style: TextStyle(
                      color: balanced ? _ok : _err,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _summaryCard('الأصول', assets, _ok)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('الخصوم', liabs, _warn)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('حقوق الملكية', equity, _indigo)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader('الأصول', Icons.account_balance_wallet, _ok),
        ...assetAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _ok)),
        _totalLine('إجمالي الأصول', assets, _ok),
        const SizedBox(height: 16),
        _sectionHeader('الخصوم', Icons.credit_card, _warn),
        ...liabAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _warn)),
        _totalLine('إجمالي الخصوم', liabs, _warn),
        const SizedBox(height: 16),
        _sectionHeader('حقوق الملكية', Icons.person, _indigo),
        ...equityAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _indigo)),
        _totalLine('إجمالي حقوق الملكية', equity, _indigo),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance, color: _gold, size: 24),
            const SizedBox(width: 10),
            const Text('إجمالي الخصوم + حقوق الملكية',
                style: TextStyle(
                    color: _tp,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(liabs + equity),
                style: const TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
          ]),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════════════

  Widget _summaryCard(String label, double value, Color color) {
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
          Text(label, style: const TextStyle(color: _td, fontSize: 11)),
          const SizedBox(height: 6),
          Text(_fmt(value),
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _totalLine(String label, double value, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const Spacer(),
        Text(_fmt(value),
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _ts)),
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

  String _categoryAr(String? c) {
    switch (c) {
      case 'asset':
        return 'أصول';
      case 'liability':
        return 'خصوم';
      case 'equity':
        return 'حقوق ملكية';
      case 'revenue':
        return 'إيرادات';
      case 'expense':
        return 'مصروفات';
    }
    return c ?? '—';
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

const _th = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);
