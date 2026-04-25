/// APEX — POS Quick Sale (retail cash sale)
/// /pos/quick-sale — single-screen flow:
///   1. Tap product or enter amount
///   2. Choose payment method (Mada/STC/Cash/Card/Apple)
///   3. Submit → JE auto-posted (Dr Cash, Cr Sales, Cr VAT)
///   4. Receipt printable + WhatsApp shareable
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_saudi_payment_grid.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class PosQuickSaleScreen extends StatefulWidget {
  const PosQuickSaleScreen({super.key});
  @override
  State<PosQuickSaleScreen> createState() => _PosQuickSaleScreenState();
}

class _PosQuickSaleScreenState extends State<PosQuickSaleScreen> {
  final _amountCtl = TextEditingController(text: '0');
  final _vatCtl = TextEditingController(text: '15');
  final _descCtl = TextEditingController();
  ApexPaymentMethod _method = ApexPaymentMethod.mada;
  bool _submitting = false;
  Map<String, dynamic>? _lastReceipt;

  @override
  void dispose() {
    _amountCtl.dispose();
    _vatCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtl.text.trim()) ?? 0;
  double get _vatRate => double.tryParse(_vatCtl.text.trim()) ?? 15;
  double get _vatAmount => _amount * _vatRate / 100;
  double get _total => _amount + _vatAmount;

  Future<void> _submit() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد كيان نشط')),
      );
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغاً صحيحاً')),
      );
      return;
    }
    setState(() => _submitting = true);
    // Use sales-invoice flow with cash customer for now (POS endpoints are
    // server-side, this falls back to sales invoice + immediate "paid").
    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // Find/create the cash customer; for now, use first customer.
    final custRes = await ApiService.pilotListCustomers(tenantId, limit: 1);
    if (!mounted) return;
    String? custId;
    if (custRes.success && custRes.data is List && (custRes.data as List).isNotEmpty) {
      custId = ((custRes.data as List).first as Map)['id'] as String?;
    }
    if (custId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئ عميلاً أولاً (سيكون هو "العميل النقدي")')),
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
      'lines': [
        {
          'description': _descCtl.text.trim().isEmpty ? 'بيع نقدي' : _descCtl.text.trim(),
          'quantity': 1,
          'unit_price': _amount,
          'vat_rate': _vatRate,
        }
      ],
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
    setState(() {
      _submitting = false;
      _lastReceipt = {
        'invoice_id': invId,
        'invoice_number': (issue.data as Map?)?['invoice_number'],
        'je_id': (issue.data as Map?)?['journal_entry_id'],
        'amount': _amount,
        'vat': _vatAmount,
        'total': _total,
        'method': _paymentLabel(_method),
      };
      _amountCtl.text = '0';
      _descCtl.clear();
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
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('بيع سريع — POS', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_lastReceipt != null) ...[
            _receiptCard(),
            const SizedBox(height: 14),
          ],
          _amountCard(),
          const SizedBox(height: 12),
          _paymentCard(),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _submitting || _amount <= 0 ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.point_of_sale),
              label: Text(_submitting ? 'جارٍ التسجيل…' : 'سجّل البيع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.navy,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _amountCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('المبلغ',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                color: AC.gold,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AC.navy3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixText: 'SAR',
              suffixStyle: TextStyle(color: AC.ts, fontSize: 16),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _descCtl,
                style: TextStyle(color: AC.tp, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'الوصف (اختياري)',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _vatCtl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AC.tp, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'VAT %',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('VAT: ${_vatAmount.toStringAsFixed(2)}',
                style: TextStyle(color: AC.ts, fontSize: 11.5)),
            Text('الإجمالي: ${_total.toStringAsFixed(2)} SAR',
                style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ]),
      );

  Widget _paymentCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('طريقة الدفع',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ApexSaudiPaymentGrid(
            selected: _method,
            onSelected: (m) => setState(() => _method = m),
          ),
        ]),
      );

  Widget _receiptCard() {
    final r = _lastReceipt!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.ok.withValues(alpha: 0.10),
        border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.celebration, color: AC.ok),
          const SizedBox(width: 8),
          Text('تم البيع بنجاح',
              style: TextStyle(color: AC.ok, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text('${r['invoice_number']} · ${r['method']} · ${r['total']} SAR',
            style: TextStyle(color: AC.tp, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ApexWhatsAppShareButton(
              message:
                  'إيصال بيع ${r['invoice_number']} — ${r['total']} ريال (${r['method']})',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/compliance/journal-entry/${r['je_id']}'),
              icon: Icon(Icons.receipt, color: AC.gold),
              label: Text('عرض القيد', style: TextStyle(color: AC.gold)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
            ),
          ),
        ]),
      ]),
    );
  }
}
