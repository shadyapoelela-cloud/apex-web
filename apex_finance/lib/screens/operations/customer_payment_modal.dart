/// Customer Payment Modal — G-SALES-INVOICE-UX-COMPLETE (2026-05-10).
///
/// Modal that records a payment against a sales invoice. POSTs to
/// `/api/v1/pilot/sales-invoices/{id}/payment` — the backend now
/// auto-posts the corresponding JE (DR Cash/Bank / CR AR) on the
/// same call (see `_post_customer_payment_je` in customer_routes.py).
///
/// Returns the payment payload Map on success (includes `journal_entry_id`).
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class CustomerPaymentModal extends StatefulWidget {
  final String invoiceId;
  final String invoiceNumber;
  final double remainingBalance;
  final String currency;

  const CustomerPaymentModal({
    super.key,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.remainingBalance,
    this.currency = 'SAR',
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String invoiceId,
    required String invoiceNumber,
    required double remainingBalance,
    String currency = 'SAR',
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AC.navy,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: CustomerPaymentModal(
            invoiceId: invoiceId,
            invoiceNumber: invoiceNumber,
            remainingBalance: remainingBalance,
            currency: currency,
          ),
        ),
      ),
    );
  }

  @override
  State<CustomerPaymentModal> createState() => _CustomerPaymentModalState();
}

class _CustomerPaymentModalState extends State<CustomerPaymentModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _method = 'cash';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.remainingBalance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'حقل مطلوب';
    final n = double.tryParse(v.trim());
    if (n == null || n <= 0) return 'يجب أن يكون رقماً موجباً';
    if (n > widget.remainingBalance + 0.001) {
      return 'المبلغ يتجاوز المتبقي (${widget.remainingBalance.toStringAsFixed(2)})';
    }
    return null;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'invoice_id': widget.invoiceId,
      'payment_date': _fmtDate(_paymentDate),
      'amount': double.parse(_amount.text.trim()),
      'method': _method,
      if (_reference.text.trim().isNotEmpty)
        'reference': _reference.text.trim(),
    };

    final res = await ApiService.pilotRecordCustomerPayment(
        widget.invoiceId, payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res.success && res.data is Map) {
      Navigator.of(context).pop((res.data as Map).cast<String, dynamic>());
    } else {
      setState(() => _error = res.error ?? 'تعذّر تسجيل الدفع');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.payments_rounded, color: AC.gold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تسجيل دفع — ${widget.invoiceNumber}',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AC.td),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'المتبقي: ${widget.remainingBalance.toStringAsFixed(2)} ${widget.currency}',
                style: TextStyle(color: AC.td, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _field('المبلغ *', _amount,
                  validator: _validateAmount,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true)),
              _datePickerField(),
              _dropdown('طريقة الدفع', _method, const {
                'cash': 'نقداً',
                'bank_transfer': 'تحويل بنكي',
                'cheque': 'شيك',
                'card': 'بطاقة',
                'mada': 'مدى',
              }, (v) => setState(() => _method = v ?? 'cash')),
              _field('رقم المرجع (شيك/معاملة)', _reference),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AC.err.withValues(alpha: 0.10),
                    border:
                        Border.all(color: AC.err.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: AC.err, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: AC.err, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AC.bdr),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text('إلغاء', style: TextStyle(color: AC.td)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(_saving
                        ? 'جارٍ التسجيل…'
                        : 'حفظ — يرحَّل القيد تلقائياً'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AC.gold,
                        foregroundColor: AC.navy,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctl, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctl,
        validator: validator,
        keyboardType: keyboardType,
        style: TextStyle(color: AC.tp, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AC.td, fontSize: 12),
          filled: true,
          fillColor: AC.navy2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AC.bdr)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AC.bdr)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AC.gold, width: 1.4)),
        ),
      ),
    );
  }

  Widget _datePickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(6),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'تاريخ الدفع',
            labelStyle: TextStyle(color: AC.td, fontSize: 12),
            prefixIcon:
                Icon(Icons.calendar_month, color: AC.gold, size: 18),
            filled: true,
            fillColor: AC.navy2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AC.bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AC.bdr)),
          ),
          child: Text(_fmtDate(_paymentDate),
              style: TextStyle(color: AC.tp, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        style: TextStyle(color: AC.tp, fontSize: 13),
        dropdownColor: AC.navy2,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AC.td, fontSize: 12),
          filled: true,
          fillColor: AC.navy2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AC.bdr)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AC.bdr)),
        ),
        items: options.entries
            .map((e) => DropdownMenuItem<String>(
                value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
