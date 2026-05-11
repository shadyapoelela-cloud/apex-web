/// Sales Invoice Details — G-SALES-INVOICE-UX-COMPLETE (2026-05-10).
///
/// Route: `/app/erp/finance/sales-invoices/:invoiceId`.
///
/// Replaces the previous list-row behaviour where tapping an invoice
/// jumped straight to the JE-builder. Now the row opens this screen,
/// which shows:
///
///   * Header with invoice number + status badge + customer + dates +
///     ZATCA QR code (Phase 1 TLV → base64 → QR).
///   * Lines table.
///   * Totals footer (subtotal / VAT / total / paid / remaining).
///   * Linked JE banner with "عرض القيد" → `/je-builder/{jeId}`.
///   * Payments history with each payment's JE link.
///   * Action row: Issue (draft) / + تسجيل دفع (issued + balance > 0).
///
/// The JE-builder is reachable ONLY via the explicit "عرض القيد"
/// button — the row click never opens it directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
// G-SALES-INVOICE-UX-FOLLOWUP (2026-05-11): web-only browser print.
// Conditionally imported — on non-web platforms the `html` symbol is
// a stub. The print button is shown only in the browser bundle, so
// the `avoid_web_libraries_in_flutter` lint is a false positive here.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/zatca_tlv.dart';
import 'customer_payment_modal.dart';

class SalesInvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;
  const SalesInvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  State<SalesInvoiceDetailsScreen> createState() =>
      _SalesInvoiceDetailsScreenState();
}

class _SalesInvoiceDetailsScreenState extends State<SalesInvoiceDetailsScreen> {
  Map<String, dynamic>? _invoice;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // G-SALES-INVOICE-UX-FOLLOWUP (Bug A, 2026-05-11): explicit
  // ScrollController so wheel/touch events don't compete with the
  // outer ApexMagneticShell scroll system. Without this, on the
  // deployed bundle the details page rendered correctly above the
  // fold but the user could not reach the totals / payments history
  // / "+ تسجيل دفع" button — they were below the viewport with no
  // way to scroll to them.
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // G-ENTITY-SELLER-INFO (2026-05-11): fire-and-forget refresh of
    // the active entity's ZATCA seller identity. The QR uses
    // `S.savedSellerNameAr` / `S.savedSellerVatNumber` (falling back
    // to placeholders); this call ensures the values are fresh by
    // the time the user reaches the issued state. Silent on failure.
    S.fetchEntitySellerInfo();
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
    final res = await ApiService.pilotGetSalesInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is Map) {
        _invoice = (res.data as Map).cast<String, dynamic>();
      } else {
        _error = res.error ?? 'تعذّر تحميل الفاتورة';
      }
    });
  }

  Future<void> _issue() async {
    setState(() => _busy = true);
    final res = await ApiService.pilotIssueSalesInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text('تم إصدار الفاتورة وترحيل القيد تلقائياً'),
      ));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل الإصدار: ${res.error ?? '-'}'),
      ));
    }
  }

  // G-SALES-INVOICE-UX-FOLLOWUP (2026-05-11): cancel action.
  // Confirms first because the operation is destructive (reverses
  // the posted JE if issued). Refused server-side when any payment
  // has been applied.
  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AC.navy2,
          title: Text('إلغاء الفاتورة؟',
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
    final res = await ApiService.pilotCancelSalesInvoice(widget.invoiceId);
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

  // G-SALES-INVOICE-UX-FOLLOWUP (2026-05-11): print action.
  // Opens the browser's print dialog — on Flutter web this prints
  // the current viewport. The QR + payment summary are already on
  // the page so the user gets a one-page invoice + ZATCA QR copy.
  void _print() {
    // dart:html's window.print() is the simplest portable path on
    // Flutter web. We import it inline as `dart:html` (web-only) —
    // on non-web platforms this method is never invoked because the
    // button is shown only in the browser bundle.
    try {
      // ignore: avoid_web_libraries_in_flutter
      // ignore: deprecated_member_use
      // Conditional: only execute in browser. The Flutter web shim
      // makes `html.window` always available in the web build.
      _invokeBrowserPrint();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.warn,
        content: Text('الطباعة غير متاحة في هذه البيئة: $e'),
      ));
    }
  }

  // Web-only print invocation. Wrapped so the import lives at the
  // top of the file behind a `kIsWeb` guard.
  void _invokeBrowserPrint() {
    if (!kIsWeb) return;
    // ignore: deprecated_member_use
    html.window.print();
  }

  Future<void> _recordPayment() async {
    final inv = _invoice;
    if (inv == null) return;
    final remaining =
        double.tryParse('${inv['remaining_balance'] ?? 0}') ?? 0;
    final result = await CustomerPaymentModal.show(
      context,
      invoiceId: widget.invoiceId,
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

  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'مسودة';
      case 'issued':
        return 'صادرة';
      case 'paid':
        return 'مدفوعة';
      case 'partially_paid':
        return 'مدفوعة جزئياً';
      case 'cancelled':
        return 'ملغاة';
    }
    return s;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return AC.ok;
      case 'issued':
        return AC.gold;
      case 'partially_paid':
        return AC.info;
      case 'cancelled':
        return AC.err;
    }
    return AC.td;
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'cash':
        return 'نقداً';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'cheque':
        return 'شيك';
      case 'card':
        return 'بطاقة';
      case 'mada':
        return 'مدى';
    }
    return m;
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
                : context.go('/app/erp/finance/sales-invoices'),
          ),
          title: Text(_invoice?['invoice_number']?.toString() ?? 'الفاتورة',
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, color: AC.err, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: AC.err)),
                    ]),
                  )
                // G-SALES-INVOICE-UX-FOLLOWUP (Bug A): Scrollbar +
                // explicit controller + AlwaysScrollableScrollPhysics
                // so the inner scroll never competes with the outer
                // ApexMagneticShell scroll system. Pre-fix the page
                // rendered correctly above the fold but mouse-wheel /
                // Page_Down events never reached this ScrollView, so
                // the user could not reach the totals + payment
                // history + action row at all.
                : PrimaryScrollController.none(
                  child: Scrollbar(
                    controller: _scrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          if (_invoice!['journal_entry_id'] != null)
                            _buildJeBanner(_invoice!['journal_entry_id']),
                          if (_invoice!['journal_entry_id'] != null)
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
    final inv = _invoice!;
    final status = (inv['status'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                _kv('العميل', inv['customer_name_ar']),
                _kv('الرقم الضريبي', inv['customer_vat_number']),
                _kv('تاريخ الإصدار', inv['issue_date']),
                _kv('تاريخ الاستحقاق', inv['due_date']),
                _kv('العملة', inv['currency']),
              ],
            ),
          ),
          // ZATCA QR Code
          _buildQrCode(),
        ],
      ),
    );
  }

  Widget _buildQrCode() {
    final inv = _invoice!;
    final issued = (inv['status'] ?? '') != 'draft';
    if (!issued) {
      // Phase 1 QR is meaningful only after issuance — show a hint.
      return Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: AC.navy3,
          border: Border.all(color: AC.bdr, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('ZATCA QR\n(بعد الإصدار)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.td, fontSize: 11)),
        ),
      );
    }
    // G-ENTITY-SELLER-INFO (2026-05-11): read seller identity from
    // the session cache populated by `S.fetchEntitySellerInfo()` in
    // initState. Falls back to the legacy placeholders so the QR
    // keeps rendering when the entity hasn't filled them in yet.
    // Note: `customer_vat_number` is the *buyer's* VAT (not used by
    // ZATCA Phase-1 tag 2 — that's the SELLER's VAT). Pre-fix this
    // line incorrectly used the customer VAT as the seller VAT.
    final qr = zatcaQrBase64(
      sellerName: S.savedSellerNameAr ?? 'APEX UAT',
      vatNumber: S.savedSellerVatNumber ?? '300000000000003',
      invoiceTimestampUtc: DateTime.tryParse(
              inv['issue_date']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      invoiceTotal: inv['total']?.toString() ?? '0',
      vatTotal: inv['vat_amount']?.toString() ?? '0',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: qr,
            version: QrVersions.auto,
            size: 124,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text('ZATCA QR',
            style: TextStyle(color: AC.td, fontSize: 10)),
      ],
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
          onPressed: () => context.go('/app/erp/finance/je-builder/$jeId'),
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
    final lines = (_invoice!['lines'] as List?) ?? const [];
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
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
          child: Text('${ln['quantity'] ?? 0}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        SizedBox(
          width: 90,
          child: Text('${ln['unit_price'] ?? 0}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.td, fontSize: 12)),
        ),
        SizedBox(
          width: 60,
          child: Text('${ln['vat_rate'] ?? 0}%',
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
    final inv = _invoice!;
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
          _totalRow('VAT', inv['vat_amount']),
          Divider(color: AC.bdr, height: 16),
          _totalRow('الإجمالي', inv['total'], emphasize: true),
          _totalRow('المدفوع', inv['paid_amount']),
          _totalRow('المتبقي', inv['remaining_balance'], emphasize: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, dynamic value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: emphasize ? AC.gold : AC.td,
                fontSize: emphasize ? 13 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400)),
        const Spacer(),
        Text('${value ?? 0}',
            style: TextStyle(
                color: emphasize ? AC.gold : AC.tp,
                fontSize: emphasize ? 14 : 12,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  Widget _buildPayments() {
    final pays = (_invoice!['payments'] as List?) ?? const [];
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
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
                        Text(p['receipt_number']?.toString() ?? '—',
                            style:
                                TextStyle(color: AC.tp, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                            '${p['payment_date'] ?? ''} · ${_methodLabel(p['method']?.toString() ?? '')}',
                            style: TextStyle(
                                color: AC.td, fontSize: 11)),
                        // G-CUSTOMER-PAYMENT-NOTES (2026-05-11): show
                        // internal-audit notes below the date when set.
                        if ((p['notes'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p['notes'].toString(),
                            style: TextStyle(
                                color: AC.ts,
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
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
    final inv = _invoice!;
    final status = (inv['status'] ?? '').toString();
    final remaining =
        double.tryParse('${inv['remaining_balance'] ?? 0}') ?? 0;
    final paid = double.tryParse('${inv['paid_amount'] ?? 0}') ?? 0;
    final isDraft = status == 'draft';
    final isIssued = status == 'issued' || status == 'partially_paid';
    final canPay = isIssued && remaining > 0.001;
    final isCancelled = status == 'cancelled';
    final isPaid = status == 'paid';
    // Cancel is allowed when no payment has been applied AND the
    // invoice isn't already cancelled. Backend enforces this too.
    // G-PURCHASE-FIXES (2026-05-11): align with backend `> 0` guard
    // — the 0.001 fuzz allowed a float-edge case where the UI offered
    // Cancel but the backend rejected. Strict `paid <= 0` matches the
    // server contract.
    final canCancel = !isCancelled && !isPaid && paid <= 0;

    // G-SALES-INVOICE-UX-FOLLOWUP (2026-05-11): action row redesigned
    // with secondary [Edit / Cancel / Print] outline buttons on the
    // right and the primary action (Issue / Pay) on the left. Each
    // button shown only when the invoice state allows it.
    final secondary = <Widget>[
      // Edit: only on draft. Routes to the create-screen with a
      // ?invoice_id query so a future PR can pre-fill the form.
      // Today it just navigates back to the create screen — the
      // pre-fill flow is bookmarked for the next sprint.
      if (isDraft)
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => context.go('/app/erp/sales/invoice-create'
                  '?invoice_id=${widget.invoiceId}'),
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
              side: BorderSide(color: AC.err.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14)),
        ),
      // Print: available whenever the invoice has data — including
      // drafts (an author may want a print preview). Only cancelled
      // invoices skip Print.
      // G-PURCHASE-FIXES (2026-05-11): switched gate from `!isDraft`
      // to `!isCancelled` to match purchase side.
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

    final primary = <Widget>[];
    if (isDraft) {
      primary.add(Expanded(
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _issue,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: const Text('إصدار — يرحَّل القيد تلقائياً'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ));
    }
    if (canPay) {
      primary.add(Expanded(
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
      ));
    }
    if (primary.isEmpty && secondary.isEmpty) {
      primary.add(Expanded(
        child: Container(
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
        ),
      ));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...secondary,
        if (primary.isNotEmpty)
          SizedBox(
            width: 480,
            child: Row(children: [
              for (int i = 0; i < primary.length; i++) ...[
                primary[i],
                if (i < primary.length - 1) const SizedBox(width: 10),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _kv(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: AC.td, fontSize: 12)),
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
