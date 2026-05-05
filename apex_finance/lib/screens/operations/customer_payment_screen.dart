/// APEX — Customer Payment recording
/// /app/erp/sales/payment/:invoiceId — record a payment against an invoice.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_dual_date_picker.dart';
import '../../core/apex_saudi_payment_grid.dart';
import '../../core/theme.dart';

class CustomerPaymentScreen extends StatefulWidget {
  final String invoiceId;
  const CustomerPaymentScreen({super.key, required this.invoiceId});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  final _amountCtl = TextEditingController();
  final _refCtl = TextEditingController();
  DateTime _date = DateTime.now();
  ApexPaymentMethod _method = ApexPaymentMethod.bankTransfer;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtl.dispose();
    _refCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await ApiService.pilotRecordCustomerPayment(widget.invoiceId, {
      'amount': amount,
      'payment_date': fmt(_date),
      'method': _methodCode(_method),
      if (_refCtl.text.trim().isNotEmpty) 'reference': _refCtl.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!res.success) _error = res.error ?? 'فشل تسجيل الدفعة';
    });
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text('تم تسجيل دفعة بقيمة ${amount.toStringAsFixed(2)} ريال'),
      ));
      context.go('/app/erp/sales/invoices');
    }
  }

  String _methodCode(ApexPaymentMethod m) => switch (m) {
        ApexPaymentMethod.mada => 'mada',
        ApexPaymentMethod.stcPay => 'stc_pay',
        ApexPaymentMethod.applePay => 'apple_pay',
        ApexPaymentMethod.card => 'card',
        ApexPaymentMethod.cash => 'cash',
        ApexPaymentMethod.bankTransfer => 'bank_transfer',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('تسجيل دفعة عميل', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null) Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6)),
            child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
          ),
          if (_error != null) const SizedBox(height: 12),
          _card('المبلغ', [
            TextField(
              controller: _amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: AC.navy3,
                suffixText: 'SAR',
                suffixStyle: TextStyle(color: AC.ts, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _card('طريقة الدفع', [
            ApexSaudiPaymentGrid(
              selected: _method,
              onSelected: (m) => setState(() => _method = m),
            ),
          ]),
          const SizedBox(height: 12),
          _card('التاريخ', [
            ApexDualDatePicker(
              label: 'تاريخ الدفعة',
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
          ]),
          const SizedBox(height: 12),
          _card('المرجع (اختياري)', [
            TextField(
              controller: _refCtl,
              style: TextStyle(color: AC.tp, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'رقم المرجع البنكي أو الإيصال',
                hintStyle: TextStyle(color: AC.ts, fontSize: 12),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'جارٍ التسجيل…' : 'تأكيد الدفعة'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
}
