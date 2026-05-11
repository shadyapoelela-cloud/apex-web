/// Purchase Invoice Details — G-PURCHASE-MULTILINE-PARITY (2026-05-11).
///
/// Route: `/app/erp/finance/purchase-bills/:billId`.
///
/// Mirror of [SalesInvoiceDetailsScreen]. Replaces the previous flow
/// where there was no details screen at all (clicking a bill row went
/// nowhere or jumped to the JE builder). Now the row opens this
/// screen, which shows:
///
///   * Header with PI number + status badge + vendor + dates.
///   * Lines table.
///   * Totals footer (subtotal / VAT / shipping / total / paid /
///     remaining).
///   * Linked JE banner with "عرض القيد" → `/je-builder/{jeId}`.
///   * Action row: Edit (draft) / Cancel / Print.
///
/// The JE-builder is reachable ONLY via the explicit "عرض القيد"
/// button — the row click never opens it directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
// G-CLEANUP-FINAL (2026-05-11): conditional-import-by-library pattern
// replaces the previous unconditional `import 'dart:html'` which
// failed to compile on non-web targets. See `core/browser_print.dart`
// for the rationale and the matching change in sales details.
import '../../core/browser_print.dart'
    if (dart.library.html) '../../core/browser_print_web.dart';
import '../../core/theme.dart';
import 'vendor_payment_modal.dart';

class PurchaseInvoiceDetailsScreen extends StatefulWidget {
  final String billId;
  const PurchaseInvoiceDetailsScreen({super.key, required this.billId});

  @override
  State<PurchaseInvoiceDetailsScreen> createState() =>
      _PurchaseInvoiceDetailsScreenState();
}

class _PurchaseInvoiceDetailsScreenState
    extends State<PurchaseInvoiceDetailsScreen> {
  Map<String, dynamic>? _bill;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // Detach from outer ApexMagneticShell scroll system, mirroring the
  // sales details fix (Bug A from PR #188).
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotGetPurchaseInvoice(widget.billId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is Map) {
        _bill = (res.data as Map).cast<String, dynamic>();
      } else {
        _error = res.error ?? 'تعذّر تحميل الفاتورة';
      }
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AC.navy2,
          title: Text('إلغاء فاتورة الشراء؟',
              style: TextStyle(color: AC.tp, fontSize: 16)),
          content: Text(
              'سيتم عكس قيد اليومية إن وُجد. لا يمكن إلغاء فاتورة عليها مدفوعات.',
              style: TextStyle(color: AC.td, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('تراجع', style: TextStyle(color: AC.td)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('تأكيد الإلغاء',
                  style: TextStyle(
                      color: AC.err, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final res = await ApiService.pilotCancelPurchaseInvoice(widget.billId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: const Text('تم إلغاء الفاتورة'),
      ));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل الإلغاء: ${res.error ?? '-'}'),
      ));
    }
  }

  void _print() {
    try {
      _invokeBrowserPrint();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.warn,
        content: Text('الطباعة غير متاحة في هذه البيئة: $e'),
      ));
    }
  }

  void _invokeBrowserPrint() {
    if (!kIsWeb) return;
    triggerBrowserPrint();
  }

  // G-PURCHASE-PAYMENT-COMPLETION (2026-05-11): record a vendor
  // payment from the modal. The backend auto-posts the JE (DR 2110
  // AP / CR 1110|1120|1310 depending on method) so we just need to
  // refresh on success and surface the JE link in the snackbar —
  // same UX as the sales side.
  Future<void> _recordPayment() async {
    final inv = _bill;
    if (inv == null) return;
    final remaining =
        double.tryParse('${inv['amount_due'] ?? 0}') ?? 0;
    final result = await VendorPaymentModal.show(
      context,
      billId: widget.billId,
      invoiceNumber: inv['invoice_number']?.toString() ?? '—',
      remainingBalance: remaining,
      currency: inv['currency']?.toString() ?? 'SAR',
    );
    if (result == null || !mounted) return;
    final jeId = result['journal_entry_id'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      duration: const Duration(seconds: 6),
      content: Text(jeId == null
          ? 'تم تسجيل الدفع'
          : 'تم تسجيل الدفع — قيد اليومية #$jeId'),
      action: jeId == null
          ? null
          : SnackBarAction(
              label: 'عرض القيد',
              textColor: AC.navy,
              onPressed: () =>
                  context.go('/app/erp/finance/je-builder/$jeId'),
            ),
    ));
    await _load();
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'cash':
        return 'نقداً';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'cheque':
        return 'شيك';
      case 'credit_card':
        return 'بطاقة ائتمان';
      case 'other':
        return 'أخرى';
    }
    return m;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'مسودة';
      case 'submitted':
        return 'مُرسلة';
      case 'approved':
        return 'معتمدة';
      case 'posted':
        return 'مُرحَّلة';
      case 'partially_paid':
        return 'مدفوعة جزئياً';
      case 'paid':
        return 'مدفوعة';
      case 'cancelled':
        return 'ملغاة';
    }
    return s;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return AC.ok;
      case 'posted':
        return AC.gold;
      case 'partially_paid':
        return AC.info;
      case 'cancelled':
        return AC.err;
    }
    return AC.td;
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
                : context.go('/app/erp/finance/purchase-bills'),
          ),
          title: Text(_bill?['invoice_number']?.toString() ?? 'فاتورة الشراء',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: AC.err, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: AC.err)),
                    ],
                  ))
                : PrimaryScrollController.none(
                    child: Scrollbar(
                      controller: _scrollCtrl,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 20),
                              if (_bill!['journal_entry_id'] != null)
                                _buildJeBanner(
                                    _bill!['journal_entry_id']),
                              if (_bill!['journal_entry_id'] != null)
                                const SizedBox(height: 16),
                              _buildLinesTable(),
                              const SizedBox(height: 20),
                              _buildTotalsFooter(),
                              const SizedBox(height: 20),
                              _buildPayments(),
                              const SizedBox(height: 20),
                              _buildActions(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    final inv = _bill!;
    final status = (inv['status'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(inv['invoice_number']?.toString() ?? '—',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabel(status),
                  style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 16),
          _kv('رقم فاتورة المورد', inv['vendor_invoice_number']),
          _kv('تاريخ الفاتورة', inv['invoice_date']),
          _kv('تاريخ الاستحقاق', inv['due_date']),
          _kv('العملة', inv['currency']),
        ],
      ),
    );
  }

  Widget _buildJeBanner(dynamic jeId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.08),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.account_balance, color: AC.gold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text('قيد اليومية المرتبط: ${jeId.toString()}',
              style: TextStyle(color: AC.tp, fontSize: 12)),
        ),
        TextButton.icon(
          onPressed: () =>
              context.go('/app/erp/finance/je-builder/$jeId'),
          icon: Icon(Icons.open_in_new, color: AC.gold, size: 16),
          label: Text('عرض القيد',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildLinesTable() {
    final lines = (_bill!['lines'] as List?) ?? const [];
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.list_alt, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('البنود (${lines.length})',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد بنود',
                    style: TextStyle(color: AC.td, fontSize: 12)),
              ),
            )
          else
            ...lines.cast<Map<String, dynamic>>().map(_lineRow),
        ],
      ),
    );
  }

  Widget _lineRow(Map<String, dynamic> ln) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AC.bdr)),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('${ln['line_number'] ?? ''}',
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        Expanded(
          child: Text(ln['description']?.toString() ?? '—',
              style: TextStyle(color: AC.tp, fontSize: 13)),
        ),
        SizedBox(
          width: 60,
          child: Text('${ln['qty'] ?? 0}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        SizedBox(
          width: 90,
          child: Text('${ln['unit_cost'] ?? 0}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        SizedBox(
          width: 60,
          child: Text('${ln['vat_rate_pct'] ?? 0}%',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        SizedBox(
          width: 100,
          child: Text('${ln['line_total'] ?? 0}',
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildTotalsFooter() {
    final inv = _bill!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _totalRow('المجموع الفرعي', inv['subtotal']),
          _totalRow('VAT', inv['vat_total']),
          _totalRow('الشحن', inv['shipping']),
          Divider(color: AC.bdr, height: 16),
          _totalRow('الإجمالي', inv['grand_total'], emphasize: true),
          _totalRow('المدفوع', inv['amount_paid']),
          _totalRow('المتبقي', inv['amount_due'], emphasize: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, dynamic value,
      {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: emphasize ? AC.gold : AC.td,
                fontSize: emphasize ? 13 : 12,
                fontWeight:
                    emphasize ? FontWeight.w700 : FontWeight.w400)),
        const Spacer(),
        Text('${value ?? 0}',
            style: TextStyle(
                color: emphasize ? AC.gold : AC.tp,
                fontSize: emphasize ? 14 : 12,
                fontWeight:
                    emphasize ? FontWeight.w800 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  // G-PURCHASE-PAYMENT-COMPLETION (2026-05-11): payments history
  // mirroring the sales-details widget. Each row shows the payment
  // number / date / method + amount + a JE link when posted.
  Widget _buildPayments() {
    final pays = (_bill!['payments'] as List?) ?? const [];
    if (pays.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.payments_outlined, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('سجل المدفوعات (${pays.length})',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          ...pays.cast<Map<String, dynamic>>().map((p) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AC.bdr)),
                ),
                child: Row(children: [
                  Icon(Icons.receipt_outlined,
                      color: AC.gold, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['payment_number']?.toString() ?? '—',
                            style:
                                TextStyle(color: AC.tp, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                            '${p['payment_date'] ?? ''} · ${_methodLabel(p['method']?.toString() ?? '')}',
                            style: TextStyle(
                                color: AC.td, fontSize: 11)),
                      ],
                    ),
                  ),
                  if ((p['journal_entry_id'] ?? '').toString().isNotEmpty)
                    TextButton.icon(
                      onPressed: () => context.go(
                          '/app/erp/finance/je-builder/${p['journal_entry_id']}'),
                      icon: Icon(Icons.account_balance,
                          color: AC.gold, size: 14),
                      label: Text(
                        'JE',
                        style: TextStyle(
                            color: AC.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text('${p['amount'] ?? 0}',
                      style: TextStyle(
                          color: AC.gold,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final inv = _bill!;
    final status = (inv['status'] ?? '').toString();
    final paid = double.tryParse('${inv['amount_paid'] ?? 0}') ?? 0;
    final remaining = double.tryParse('${inv['amount_due'] ?? 0}') ?? 0;
    final isDraft = status == 'draft';
    final isCancelled = status == 'cancelled';
    final isPaid = status == 'paid';
    // G-PURCHASE-FIXES (2026-05-11): align with backend (`amount_paid
    // > 0` → 409). The 0.001 fuzz let the UI offer Cancel for a
    // float-edge amount the backend would reject. Strict `paid <= 0`
    // mirrors the server contract.
    final canCancel = !isCancelled && !isPaid && paid <= 0;
    // G-PURCHASE-PAYMENT-COMPLETION (2026-05-11): payment is allowed
    // once the bill is posted (or partially_paid) AND there's a
    // remaining balance. Backend overpayment guard catches the edge.
    final isPosted =
        status == 'posted' || status == 'partially_paid' ||
            status == 'approved' || status == 'submitted';
    final canPay = isPosted && remaining > 0.001;

    final secondary = <Widget>[
      if (isDraft)
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => context.go(
                  '/app/erp/finance/purchase-invoice-create'
                  '?bill_id=${widget.billId}'),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('تعديل'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AC.tp,
              side: BorderSide(color: AC.bdr),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14)),
        ),
      if (canCancel)
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('إلغاء الفاتورة'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AC.err,
              side:
                  BorderSide(color: AC.err.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14)),
        ),
      // G-PURCHASE-FIXES (2026-05-11): drafts get print preview too —
      // an author may want a draft copy before posting. Only cancelled
      // invoices skip the print button (no reason to print a void).
      if (!isCancelled)
        OutlinedButton.icon(
          onPressed: _busy ? null : _print,
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('طباعة'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AC.tp,
              side: BorderSide(color: AC.bdr),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14)),
        ),
    ];

    // G-PURCHASE-PAYMENT-COMPLETION (2026-05-11): primary "+ تسجيل دفع"
    // button when the invoice is posted and has a remaining balance.
    // Mirrors the sales-details primary action row.
    final primary = <Widget>[
      if (canPay)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _recordPayment,
            icon: const Icon(Icons.add_card),
            label: const Text('+ تسجيل دفع'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.ok,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ),
    ];

    if (secondary.isEmpty && primary.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
            isCancelled
                ? '✗ الفاتورة ملغاة'
                : (isPaid
                    ? '✓ الفاتورة مدفوعة بالكامل'
                    : 'لا توجد إجراءات متاحة'),
            style: TextStyle(color: AC.td, fontSize: 12)),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...secondary,
        if (primary.isNotEmpty)
          SizedBox(
            width: 320,
            child: Row(children: primary),
          ),
      ],
    );
  }

  Widget _kv(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        Expanded(
          child: Text(
              (value == null || value.toString().isEmpty)
                  ? '—'
                  : value.toString(),
              style: TextStyle(color: AC.tp, fontSize: 13)),
        ),
      ]),
    );
  }
}
