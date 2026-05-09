/// POS Daily Report — G-FIN-POS-JE-AUTOPOST (Sprint 7, 2026-05-09).
///
/// Route: `/app/erp/finance/pos-report`.
///
/// Lists POS sessions for the active branch and, for the selected
/// session, shows the Z-report breakdown — gross sales, refunds, VAT,
/// net, payment-method breakdown, transaction count, and the
/// list of auto-posted journal entries (sales JE + COGS JE per sale).
///
/// The backend `auto_post_pos_sale` (gl_engine.py:578) creates the
/// JEs on every completed POS transaction:
///
///   Sales JE (always):
///     DR Cash (1110) or Bank (1120)   grand_total
///     CR Sales Revenue (4100)         taxable_amount
///     CR VAT Output Payable (2120)    vat_total
///
///   COGS JE (only when product_id with cost is present):
///     DR Cost of Sales (5100)         Σ(qty × unit_cost)
///     CR Inventory (1140)             Σ(qty × unit_cost)
///
/// This screen is the verification surface — pilots can confirm in
/// one place that "I rang up 5 sales today, the trial balance moved
/// the way I expected."
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/theme.dart';
import '../../pilot/session.dart' as pilot_session;

class PosDailyReportScreen extends StatefulWidget {
  const PosDailyReportScreen({super.key});

  @override
  State<PosDailyReportScreen> createState() => _PosDailyReportScreenState();
}

class _PosDailyReportScreenState extends State<PosDailyReportScreen> {
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _zReport;
  List<Map<String, dynamic>> _txns = [];
  String? _selectedSessionId;
  bool _loadingSessions = false;
  bool _loadingZ = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final branchId = pilot_session.PilotSession.branchId;
    if (branchId == null || branchId.isEmpty) {
      setState(() => _error = 'لا يوجد فرع نشط — افتح وردية POS أولاً');
      return;
    }
    setState(() {
      _loadingSessions = true;
      _error = null;
    });
    final res = await ApiService.pilotListPosSessions(branchId, limit: 50);
    if (!mounted) return;
    setState(() {
      _loadingSessions = false;
      if (res.success && res.data is List) {
        _sessions = (res.data as List).cast<Map<String, dynamic>>();
        if (_sessions.isNotEmpty) {
          _selectedSessionId = _sessions.first['id'] as String?;
          _loadZReport();
        }
      } else {
        _error = res.error ?? 'تعذّر تحميل الورديات';
      }
    });
  }

  Future<void> _loadZReport() async {
    final sid = _selectedSessionId;
    if (sid == null) return;
    setState(() {
      _loadingZ = true;
      _zReport = null;
      _txns = [];
    });
    final z = await ApiService.pilotZReport(sid);
    if (!mounted) return;
    final t = await ApiService.pilotListPosTransactions(sid);
    if (!mounted) return;
    setState(() {
      _loadingZ = false;
      if (z.success && z.data is Map) {
        _zReport = (z.data as Map).cast<String, dynamic>();
      }
      if (t.success && t.data is List) {
        _txns = (t.data as List).cast<Map<String, dynamic>>();
      }
    });
  }

  String _fmtMoney(dynamic v) {
    if (v == null) return '0.00';
    final n = double.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          foregroundColor: AC.tp,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/app/erp/finance/pos'),
          ),
          title: const Text('تقرير POS اليومي',
              style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadingSessions || _loadingZ
                  ? null
                  : () {
                      _loadSessions();
                      if (_selectedSessionId != null) _loadZReport();
                    },
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, color: AC.err, size: 36),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AC.err)),
                ]),
              )
            : _loadingSessions
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      // Left rail: session list (~280 px on desktop).
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: _buildSessionList(),
                      ),
                      Container(width: 1, color: AC.bdr),
                      Expanded(child: _buildReport()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) {
      return Center(
          child: Text('لا توجد ورديات بعد',
              style: TextStyle(color: AC.td)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _sessions.length,
      itemBuilder: (_, i) {
        final s = _sessions[i];
        final isSelected = _selectedSessionId == s['id'];
        final status = (s['status'] ?? '').toString();
        final color = switch (status) {
          'open' => AC.ok,
          'closed' => AC.td,
          _ => AC.warn,
        };
        return InkWell(
          onTap: () {
            setState(() => _selectedSessionId = s['id'] as String?);
            _loadZReport();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AC.gold.withValues(alpha: 0.10)
                  : AC.navy2,
              border: Border.all(
                  color: isSelected ? AC.gold : AC.bdr,
                  width: isSelected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.point_of_sale_rounded,
                      color: isSelected ? AC.gold : AC.td, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text((s['code'] ?? '—').toString(),
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(_statusLabel(status),
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text((s['opened_at'] ?? '').toString().substring(0, 10),
                    style: TextStyle(color: AC.td, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReport() {
    if (_loadingZ) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_zReport == null) {
      return Center(
          child: Text('اختر وردية لعرض تقريرها',
              style: TextStyle(color: AC.td)));
    }
    final z = _zReport!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiRow([
            _kpi('إجمالي المبيعات',
                _fmtMoney(z['total_sales_gross']), Icons.point_of_sale,
                color: AC.ok),
            _kpi('إجمالي VAT', _fmtMoney(z['total_vat']),
                Icons.account_balance_wallet,
                color: AC.gold),
            _kpi('صافي', _fmtMoney(z['total_net']), Icons.summarize,
                color: AC.info),
            _kpi('عدد الفواتير', '${z['transaction_count'] ?? 0}',
                Icons.receipt_long_rounded),
          ]),
          const SizedBox(height: 20),
          _kpiRow([
            _kpi('الكاش المتوقّع', _fmtMoney(z['expected_cash']),
                Icons.attach_money),
            _kpi('الكاش الفعلي', _fmtMoney(z['closing_cash']),
                Icons.savings),
            _kpi(
                'الفرق',
                _fmtMoney(z['variance']),
                Icons.compare_arrows,
                color: (double.tryParse('${z['variance'] ?? 0}') ?? 0)
                            .abs() <
                        0.01
                    ? AC.ok
                    : AC.warn),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('توزيع طرق الدفع'),
          _paymentBreakdown(z),
          const SizedBox(height: 20),
          _sectionTitle(
              'العمليات المُرحَّلة (${_txns.length}) — قيود يومية تلقائية'),
          _transactionsList(),
        ],
      ),
    );
  }

  Widget _paymentBreakdown(Map<String, dynamic> z) {
    final breakdown = (z['payment_breakdown'] as Map?) ?? const {};
    if (breakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('لا توجد مدفوعات',
            style: TextStyle(color: AC.td, fontSize: 12)),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: breakdown.entries
          .map((e) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AC.navy2,
                  border: Border.all(color: AC.bdr),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.payment, color: AC.gold, size: 14),
                  const SizedBox(width: 6),
                  Text(_paymentMethodLabel(e.key.toString()),
                      style: TextStyle(color: AC.tp, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(_fmtMoney(e.value),
                      style: TextStyle(
                          color: AC.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ]),
              ))
          .toList(),
    );
  }

  Widget _transactionsList() {
    if (_txns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('لا توجد عمليات',
            style: TextStyle(color: AC.td, fontSize: 12)),
      );
    }
    // Each row: receipt + total + journal_entry_id link (if posted).
    return Column(
      children: _txns
          .map((t) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AC.navy2,
                  border: Border.all(color: AC.bdr),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.receipt_long, color: AC.gold, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (t['receipt_number'] ?? t['code'] ?? '—')
                                .toString(),
                            style: TextStyle(
                                color: AC.tp, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text((t['transacted_at'] ?? '').toString(),
                            style:
                                TextStyle(color: AC.td, fontSize: 11)),
                      ],
                    ),
                  ),
                  // JE link — sales JE always; COGS only when products.
                  if ((t['journal_entry_id'] ?? '').toString().isNotEmpty)
                    TextButton.icon(
                      icon: Icon(Icons.account_balance,
                          color: AC.gold, size: 14),
                      label: Text(
                          'JE #${(t['journal_entry_id'] ?? '').toString().substring(0, 8)}',
                          style: TextStyle(
                              color: AC.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      onPressed: () =>
                          context.go('/app/erp/finance/je-builder'),
                    ),
                  const SizedBox(width: 12),
                  Text(_fmtMoney(t['grand_total'] ?? t['total']),
                      style: TextStyle(
                          color: AC.gold,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ]),
              ))
          .toList(),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'مفتوحة';
      case 'closed':
        return 'مغلقة';
      case 'reconciled':
        return 'مُسوّاة';
    }
    return s;
  }

  String _paymentMethodLabel(String m) {
    switch (m) {
      case 'cash':
        return 'نقدي';
      case 'card':
        return 'بطاقة';
      case 'mada':
        return 'مدى';
      case 'visa':
        return 'فيزا';
      case 'mastercard':
        return 'ماستركارد';
      case 'apple_pay':
        return 'Apple Pay';
      case 'stc_pay':
        return 'STC Pay';
      case 'credit':
        return 'آجل';
    }
    return m;
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                color: AC.gold,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  Widget _kpiRow(List<Widget> children) => Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 10),
          ],
        ],
      );

  Widget _kpi(String label, String value, IconData icon,
      {Color? color}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          Icon(icon, color: color ?? AC.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AC.td, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: color ?? AC.tp,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        ]),
      );
}
