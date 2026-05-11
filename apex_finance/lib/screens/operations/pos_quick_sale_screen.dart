/// APEX — POS Quick Sale (retail cash sale)
/// /pos/quick-sale — single-screen flow:
///   1. Add one or more lines (product picker or manual description)
///   2. Choose payment method (Mada/STC/Cash/Card/Apple)
///   3. Submit → JE auto-posted (Dr Cash, Cr Sales, Cr VAT)
///   4. Receipt printable + WhatsApp shareable + ZATCA QR (Phase 1)
///
/// G-POS-MULTILINE-CLEANUP (2026-05-11): refactored from single-line to
/// list of `_PosLineDraft` mirroring sales + purchase. Each line has
/// its own ProductPickerOrCreate so the cashier can ring up multiple
/// SKUs in one sale.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api_service.dart';
import '../../core/apex_saudi_payment_grid.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
// G-POS-ZATCA-QR (2026-05-11): import the pure-Dart TLV helper so the
// success receipt renders a Phase-1-compliant QR alongside the JE link
// + WhatsApp share. Pre-fix POS receipts shipped no QR which meant
// they didn't meet ZATCA Phase 1 requirements for B2C simplified-tax
// invoices.
import '../../core/zatca_tlv.dart';
import '../../widgets/apex_output_chips.dart';
import '../../widgets/forms/product_picker_or_create.dart';

/// Per-line draft for a POS sale. Mirrors `_LineDraft` (sales) and
/// `_PiLineDraft` (purchase) so all three flows share the same shape.
class _PosLineDraft {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController unitPrice;
  final TextEditingController vatRate;
  Map<String, dynamic>? product;

  _PosLineDraft({
    String description = '',
    String quantity = '1',
    String price = '',
    String vat = '15',
  })  : desc = TextEditingController(text: description),
        qty = TextEditingController(text: quantity),
        unitPrice = TextEditingController(text: price),
        vatRate = TextEditingController(text: vat);

  void dispose() {
    desc.dispose();
    qty.dispose();
    unitPrice.dispose();
    vatRate.dispose();
  }

  double get quantityValue => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPriceValue => double.tryParse(unitPrice.text.trim()) ?? 0;
  double get vatRateValue => double.tryParse(vatRate.text.trim()) ?? 0;
  double get subtotal => quantityValue * unitPriceValue;
  double get vatAmount => subtotal * vatRateValue / 100;
  double get lineTotal => subtotal + vatAmount;
}

class PosQuickSaleScreen extends StatefulWidget {
  const PosQuickSaleScreen({super.key});
  @override
  State<PosQuickSaleScreen> createState() => _PosQuickSaleScreenState();
}

class _PosQuickSaleScreenState extends State<PosQuickSaleScreen> {
  final List<_PosLineDraft> _lines = [_PosLineDraft()];
  ApexPaymentMethod _method = ApexPaymentMethod.mada;
  bool _submitting = false;
  Map<String, dynamic>? _lastReceipt;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_PosLineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  double get _grandSubtotal => _lines.fold(0.0, (s, l) => s + l.subtotal);
  double get _grandVat => _lines.fold(0.0, (s, l) => s + l.vatAmount);
  double get _grandTotal => _grandSubtotal + _grandVat;

  /// G-POS-BACKEND-INTEGRATION (2026-05-11): resolve a branch_id for
  /// this entity so we can open a POS session against it. POS shifts
  /// are scoped to (branch × station), and the backend rejects POS
  /// transactions that have no session_id. Strategy: take the first
  /// branch returned for the active entity. Multi-branch tenants will
  /// want a picker later, but every entity that exists has at least
  /// one branch by onboarding contract.
  Future<String?> _resolveBranchId(String entityId) async {
    final res = await ApiService.pilotEntityBranches(entityId);
    if (!res.success || res.data is! List) return null;
    final list = res.data as List;
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is Map) return first['id']?.toString();
    return null;
  }

  /// G-POS-BACKEND-INTEGRATION (2026-05-11): get the currently open
  /// POS session for [branchId], creating one on the fly if none is
  /// open. The backend rule is "one open session per (branch, station)
  /// at a time" — listing with `status=open` returns at most one row.
  /// If we need to create, we pick the first sellable warehouse on the
  /// branch (or fall back to the first warehouse if none flagged
  /// sellable — `pilotCreatePosSession` will then surface the
  /// `is_sellable_from=false` 400 with an Arabic-friendly error).
  Future<String?> _ensureOpenSession(String branchId) async {
    final list = await ApiService.pilotListOpenPosSessions(branchId);
    if (list.success && list.data is List && (list.data as List).isNotEmpty) {
      final first = (list.data as List).first;
      if (first is Map) {
        final sid = first['id']?.toString();
        if (sid != null && sid.isNotEmpty) return sid;
      }
    }
    // No open session — pick a warehouse and open one.
    final whRes = await ApiService.pilotListBranchWarehouses(branchId);
    if (!whRes.success || whRes.data is! List ||
        (whRes.data as List).isEmpty) {
      return null;
    }
    final whs = (whRes.data as List).cast<Map>();
    Map? sellable;
    for (final w in whs) {
      if (w['is_sellable_from'] == true) {
        sellable = w;
        break;
      }
    }
    sellable ??= whs.first;
    final whId = sellable['id']?.toString();
    final userId = S.uid;
    if (whId == null || userId == null) return null;
    final create = await ApiService.pilotCreatePosSession(branchId, {
      'branch_id': branchId,
      'warehouse_id': whId,
      'opened_by_user_id': userId,
      'opening_cash': 0,
      'station_label': 'POS-Quick',
    });
    if (!create.success || create.data is! Map) return null;
    return (create.data as Map)['id']?.toString();
  }

  /// Map the UI's payment-method enum to the string POS expects.
  /// PosPaymentInput's pattern is the canonical list; unsupported
  /// values like `card` (generic) fall through to `other` so the
  /// payment is still recorded — the cashier can refine later in the
  /// per-session report.
  String _payloadMethod(ApexPaymentMethod m) => switch (m) {
        ApexPaymentMethod.mada => 'mada',
        ApexPaymentMethod.stcPay => 'stc_pay',
        ApexPaymentMethod.applePay => 'apple_pay',
        ApexPaymentMethod.cash => 'cash',
        ApexPaymentMethod.card => 'visa',
        ApexPaymentMethod.bankTransfer => 'bank_transfer',
      };

  Future<void> _submit() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد كيان نشط')),
      );
      return;
    }
    final cashierId = S.uid;
    if (cashierId == null || cashierId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مستخدم مسجَّل')),
      );
      return;
    }
    // G-POS-BACKEND-INTEGRATION (2026-05-11): the POS endpoint
    // (PosLineInput) requires `variant_id` on every line — there is
    // no ad-hoc / description-only flow. Validate per-line and
    // surface an Arabic error so the cashier knows which line needs
    // a product picker selection.
    final linesPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final desc = l.desc.text.trim();
      final hasProduct = l.product != null &&
          l.product!['default_variant_id'] != null;
      final emptyLine = desc.isEmpty &&
          !hasProduct &&
          l.unitPriceValue <= 0;
      // Skip blank lines if the cashier added an extra row by mistake.
      if (emptyLine && _lines.length > 1) continue;
      if (!hasProduct) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AC.err,
          content: Text(
              'البند ${i + 1}: اختر منتجاً (نقطة البيع تتطلب صنفاً مع باركود/SKU)'),
        ));
        return;
      }
      if (l.quantityValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AC.err,
          content: Text('البند ${i + 1}: الكمية غير صحيحة'),
        ));
        return;
      }
      if (l.unitPriceValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AC.err,
          content: Text('البند ${i + 1}: السعر غير صحيح'),
        ));
        return;
      }
      linesPayload.add({
        'variant_id': l.product!['default_variant_id'],
        'qty': l.quantityValue,
        'unit_price_override': l.unitPriceValue,
        if (l.product != null && l.product!['code'] != null)
          'barcode_scanned': l.product!['code'],
      });
    }
    if (linesPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بنداً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _submitting = true);
    // G-POS-BACKEND-INTEGRATION (2026-05-11): resolve branch +
    // open-session BEFORE building the create payload, because
    // PosTransactionCreate requires `session_id`.
    final branchId = await _resolveBranchId(entityId);
    if (!mounted) return;
    if (branchId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد فرع نشط لهذا الكيان')),
      );
      return;
    }
    final sessionId = await _ensureOpenSession(branchId);
    if (!mounted) return;
    if (sessionId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذّر فتح وردية POS — تحقق من إعداد المستودع')),
      );
      return;
    }
    // Captured before posting so the receipt card has stable
    // amounts even after we reset _lines.
    final capturedSubtotal = _grandSubtotal;
    final capturedVat = _grandVat;
    final capturedTotal = _grandTotal;
    // G-POS-BACKEND-INTEGRATION (2026-05-11): call the dedicated POS
    // endpoint (NOT /sales-invoices). This produces a single POS
    // receipt JE (DR Cash / CR Revenue / CR VAT) instead of the old
    // double-JE flow, deducts stock for every variant, locks against
    // the open session, and uses CompanySettings.default_vat_rate.
    final create = await ApiService.pilotCreatePosTransaction({
      'session_id': sessionId,
      'kind': 'sale',
      'cashier_user_id': cashierId,
      'lines': linesPayload,
      'payments': [
        {
          'method': _payloadMethod(_method),
          'amount': capturedTotal,
        }
      ],
      'notes': 'POS Quick Sale — ${_paymentLabel(_method)}',
    });
    if (!mounted) return;
    if (!create.success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل: ${create.error ?? '-'}'),
      ));
      return;
    }
    final txnData = create.data as Map?;
    final posTxnId = txnData?['id'] as String?;
    final receiptNumber = txnData?['receipt_number'] as String?;
    if (posTxnId == null) {
      setState(() => _submitting = false);
      return;
    }
    // G-POS-BACKEND-INTEGRATION (2026-05-11): post the receipt to
    // GL so the cashier (and downstream TB / Z-Report) sees it
    // immediately. Single JE — no separate customer-payment leg.
    final post = await ApiService.pilotPostPosTransactionToGl(posTxnId);
    if (!mounted) return;
    if (!post.success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل الترحيل: ${post.error ?? '-'}'),
      ));
      return;
    }
    final jeId = (post.data as Map?)?['id'] as String?;
    setState(() {
      _submitting = false;
      _lastReceipt = {
        'pos_txn_id': posTxnId,
        'receipt_number': receiptNumber,
        'je_id': jeId,
        'amount': capturedSubtotal,
        'vat': capturedVat,
        'total': capturedTotal,
        'method': _paymentLabel(_method),
        'issued_at_utc': DateTime.now().toUtc().toIso8601String(),
        // ZATCA Phase-1 QR fields — same placeholders as before until
        // entity-settings exposes seller VAT / name to the client.
        'seller_vat_number': '300000000000003',
        'seller_name': 'APEX',
        'line_count': linesPayload.length,
      };
      // Reset to a single empty line for the next sale.
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..add(_PosLineDraft());
    });
  }

  String _paymentLabel(ApexPaymentMethod m) => switch (m) {
        ApexPaymentMethod.mada => 'مدى',
        ApexPaymentMethod.stcPay => 'STC Pay',
        ApexPaymentMethod.applePay => 'Apple Pay',
        ApexPaymentMethod.card => 'بطاقة ائتمان',
        ApexPaymentMethod.cash => 'نقد',
        ApexPaymentMethod.bankTransfer => 'تحويل بنكي',
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Text('بيع سريع — POS', style: TextStyle(color: AC.gold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_lastReceipt != null) ...[
                _receiptCard(),
                const SizedBox(height: 14),
              ],
              _linesCard(),
              const SizedBox(height: 12),
              _totalsCard(),
              const SizedBox(height: 12),
              _paymentCard(),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _submitting || _grandTotal <= 0
                      ? null
                      : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.point_of_sale),
                  label: Text(_submitting ? 'جارٍ التسجيل…' : 'سجّل البيع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AC.gold,
                    foregroundColor: AC.navy,
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const ApexOutputChips(items: [
                ApexChipLink(
                    'الفواتير', '/app/erp/sales/invoices', Icons.receipt),
                ApexChipLink('المخزون', '/operations/inventory-v2',
                    Icons.inventory_2),
                ApexChipLink('بطاقة الصنف', '/operations/stock-card',
                    Icons.timeline),
                ApexChipLink('VAT Return',
                    '/app/compliance/tax/vat-return', Icons.receipt_long),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linesCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.shopping_cart_outlined,
                  color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('البنود (${_lines.length})',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            for (int i = 0; i < _lines.length; i++) _lineCard(i),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _addLine,
              icon: Icon(Icons.add, color: AC.gold, size: 18),
              label: Text('+ إضافة بند',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.gold.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ],
        ),
      );

  Widget _lineCard(int index) {
    final l = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('بند ${index + 1}',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: _lines.length <= 1
                      ? AC.td
                      : AC.err.withValues(alpha: 0.8),
                  size: 18),
              onPressed:
                  _lines.length <= 1 ? null : () => _removeLine(index),
              tooltip: 'حذف البند',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 6),
          ProductPickerOrCreate(
            initial: l.product,
            labelText: 'المنتج / الباركود (اختياري)',
            onSelected: (p) {
              setState(() {
                l.product = p;
                l.desc.text = (p['name_ar'] ?? '').toString();
                final price = p['list_price'] ?? p['default_price'];
                if (price != null && l.unitPrice.text.trim().isEmpty) {
                  l.unitPrice.text = price.toString();
                }
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: l.desc,
            style: TextStyle(color: AC.tp, fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'الوصف',
              labelStyle: TextStyle(color: AC.ts, fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: AC.navy2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: l.qty,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AC.tp, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'الكمية',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: l.unitPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'السعر',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  suffixText: 'SAR',
                  suffixStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 70,
              child: TextField(
                controller: l.vatRate,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AC.tp, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'VAT %',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text('الإجمالي', style: TextStyle(color: AC.td, fontSize: 11)),
            const Spacer(),
            Text('${l.lineTotal.toStringAsFixed(2)} SAR',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ],
      ),
    );
  }

  Widget _totalsCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          _totalRow('المجموع الفرعي', _grandSubtotal),
          _totalRow('VAT', _grandVat),
          Divider(color: AC.bdr, height: 14),
          _totalRow('الإجمالي', _grandTotal, emphasize: true),
        ]),
      );

  Widget _totalRow(String label, double v, {bool emphasize = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: emphasize ? AC.gold : AC.td,
                  fontSize: emphasize ? 14 : 12,
                  fontWeight: emphasize
                      ? FontWeight.w700
                      : FontWeight.w400)),
          const Spacer(),
          Text('${v.toStringAsFixed(2)} SAR',
              style: TextStyle(
                  color: emphasize ? AC.gold : AC.tp,
                  fontSize: emphasize ? 16 : 12,
                  fontWeight:
                      emphasize ? FontWeight.w800 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );

  Widget _paymentCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('طريقة الدفع',
              style: TextStyle(
                  color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ApexSaudiPaymentGrid(
            selected: _method,
            onSelected: (m) => setState(() => _method = m),
          ),
        ]),
      );

  Widget _receiptCard() {
    final r = _lastReceipt!;
    // G-POS-ZATCA-QR (2026-05-11): build the Phase-1 TLV QR data
    // lazily here so the receipt card always reflects the latest
    // capture. zatcaQrBase64 throws if any TLV field exceeds 255
    // bytes — wrap defensively so a malformed seller name doesn't
    // hide the rest of the receipt.
    String? qrData;
    try {
      qrData = zatcaQrBase64(
        sellerName: r['seller_name']?.toString() ?? 'APEX',
        vatNumber:
            r['seller_vat_number']?.toString() ?? '300000000000003',
        invoiceTimestampUtc: DateTime.tryParse(
                r['issued_at_utc']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        invoiceTotal:
            (r['total'] as num?)?.toStringAsFixed(2) ?? '0.00',
        vatTotal: (r['vat'] as num?)?.toStringAsFixed(2) ?? '0.00',
      );
    } catch (_) {
      qrData = null;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.ok.withValues(alpha: 0.10),
        border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.celebration, color: AC.ok),
          const SizedBox(width: 8),
          Text('تم البيع بنجاح',
              style: TextStyle(
                  color: AC.ok,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        // G-POS-BACKEND-INTEGRATION (2026-05-11): show receipt_number
        // (e.g. RCT-001234) rather than the old sales-invoice
        // invoice_number — POS Quick Sale now creates a POS receipt
        // (B2C simplified-tax invoice), not a B2B sales invoice.
        Text(
            '${r['receipt_number'] ?? '-'} · ${r['method']} · ${r['total']?.toStringAsFixed(2) ?? r['total']} SAR · ${r['line_count'] ?? 1} بند',
            style: TextStyle(color: AC.tp, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (qrData != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 96,
                  backgroundColor: Colors.white,
                ),
              ),
            if (qrData != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (qrData != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('ZATCA QR (Phase 1)',
                          style:
                              TextStyle(color: AC.td, fontSize: 10)),
                    ),
                  ApexWhatsAppShareButton(
                    message:
                        'إيصال بيع ${r['receipt_number'] ?? '-'} — ${r['total']} ريال (${r['method']})',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context
                        .go('/app/erp/finance/je-builder/${r['je_id']}'),
                    icon: Icon(Icons.receipt, color: AC.gold),
                    label: Text('عرض القيد',
                        style: TextStyle(color: AC.gold)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AC.gold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
