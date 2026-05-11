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

  Future<void> _submit() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد كيان نشط')),
      );
      return;
    }
    // Validate every line up-front so the cashier gets clear feedback
    // per line rather than a single backend 400.
    final linesPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final desc = l.desc.text.trim();
      // Description is the only required text — qty defaults to 1,
      // price must be positive. A line with no description AND no
      // product was intentionally left empty (the cashier added a
      // line then changed their mind); silently skip those.
      final emptyLine = desc.isEmpty &&
          l.product == null &&
          l.unitPriceValue <= 0;
      if (emptyLine && _lines.length > 1) continue;
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
        'description': desc.isEmpty ? 'بيع نقدي' : desc,
        'quantity': l.quantityValue,
        'unit_price': l.unitPriceValue,
        'vat_rate': l.vatRateValue,
        if (l.product != null && l.product!['default_variant_id'] != null)
          'product_id': l.product!['default_variant_id'],
        if (l.product != null && l.product!['code'] != null)
          'sku': l.product!['code'],
      });
    }
    if (linesPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بنداً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _submitting = true);
    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // Find/create the cash customer; for now, use first customer.
    final custRes = await ApiService.pilotListCustomers(tenantId, limit: 1);
    if (!mounted) return;
    String? custId;
    if (custRes.success && custRes.data is List &&
        (custRes.data as List).isNotEmpty) {
      custId = ((custRes.data as List).first as Map)['id'] as String?;
    }
    if (custId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'أنشئ عميلاً أولاً (سيكون هو "العميل النقدي")')),
      );
      return;
    }
    final create = await ApiService.pilotCreateSalesInvoice({
      'tenant_id': tenantId,
      'entity_id': entityId,
      'customer_id': custId,
      'issue_date': fmt(today),
      'due_date': fmt(today),
      'currency': 'SAR',
      'memo': 'POS — ${_paymentLabel(_method)}',
      'lines': linesPayload,
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
    final invId = (create.data as Map?)?['id'] as String?;
    if (invId == null) {
      setState(() => _submitting = false);
      return;
    }
    final issue = await ApiService.pilotIssueSalesInvoice(invId);
    if (!mounted) return;
    if (!issue.success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل الإصدار: ${issue.error ?? '-'}'),
      ));
      return;
    }
    // G-POS-ZATCA-QR (2026-05-11) + G-POS-MULTILINE-CLEANUP
    // (2026-05-11): capture totals from the per-line state BEFORE
    // resetting the form so the receipt card can pass them into
    // zatcaQrBase64. After capture, reset _lines to a single empty
    // draft for the next sale.
    final capturedSubtotal = _grandSubtotal;
    final capturedVat = _grandVat;
    final capturedTotal = _grandTotal;
    setState(() {
      _submitting = false;
      _lastReceipt = {
        'invoice_id': invId,
        'invoice_number': (issue.data as Map?)?['invoice_number'],
        'je_id': (issue.data as Map?)?['journal_entry_id'],
        'amount': capturedSubtotal,
        'vat': capturedVat,
        'total': capturedTotal,
        'method': _paymentLabel(_method),
        'issued_at_utc': DateTime.now().toUtc().toIso8601String(),
        // Phase 1 ZATCA QR requires seller VAT + name. These don't
        // live in client session storage yet (entity_setup_screen
        // doesn't persist them locally) so we fall back to the same
        // placeholders the sales-details screen uses. When the entity
        // settings API exposes VAT/name fields, swap these for the
        // real values via a future sprint.
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
        Text(
            '${r['invoice_number']} · ${r['method']} · ${r['total']?.toStringAsFixed(2) ?? r['total']} SAR · ${r['line_count'] ?? 1} بند',
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
                        'إيصال بيع ${r['invoice_number']} — ${r['total']} ريال (${r['method']})',
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
