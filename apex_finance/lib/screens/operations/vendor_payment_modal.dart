/// Vendor Payment Modal — G-PURCHASE-PAYMENT-COMPLETION (2026-05-11).
///
/// Mirror of [CustomerPaymentModal]. Records a payment against a
/// purchase invoice via `POST /pilot/purchase-invoices/{id}/payment`.
/// The backend routes the cash/bank/cheque GL account based on
/// `method` and auto-posts the corresponding JE (DR 2110 AP / CR
/// 1110 [cash] or CR 1120 [bank, cheque, card, mada, etc.]) — the
/// modal stays slim. Outgoing vendor cheques settle through Bank,
/// NOT through "Cheques on Hand" (1310 = customer-side asset).
///
/// Returns the payment payload Map on success (includes
/// `journal_entry_id`).
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class VendorPaymentModal extends StatefulWidget {
  final String billId;
  final String invoiceNumber;
  final double remainingBalance;
  final String currency;

  const VendorPaymentModal({
    super.key,
    required this.billId,
    required this.invoiceNumber,
    required this.remainingBalance,
    this.currency = 'SAR',
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String billId,
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
          child: VendorPaymentModal(
            billId: billId,
            invoiceNumber: invoiceNumber,
            remainingBalance: remainingBalance,
            currency: currency,
          ),
        ),
      ),
    );
  }

  @override
  State<VendorPaymentModal> createState() => _VendorPaymentModalState();
}

class _VendorPaymentModalState extends State<VendorPaymentModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  // Bank account name — visible only when method=bank_transfer. Merged
  // into the server `reference` field so the audit trail captures
  // which bank wired the funds, mirroring the customer modal.
  final _bankAccount = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  // Backend pattern: ^(cash|bank_transfer|cheque|credit_card|other)$
  // Default to bank_transfer since vendor payments are usually wired.
  String _method = 'bank_transfer';
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
    _bankAccount.dispose();
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

    // Merge bank account name + free-text notes into the reference
    // field — same pattern as the customer modal so the JE memo + AP
    // ledger stay readable.
    final notes = _notes.text.trim();
    final bank = _bankAccount.text.trim();
    final ref = _reference.text.trim();
    final combinedReference = [
      if (ref.isNotEmpty) ref,
      if (bank.isNotEmpty) 'بنك: $bank',
      if (notes.isNotEmpty) 'ملاحظات: $notes',
    ].join(' · ');
    final payload = <String, dynamic>{
      'payment_date': _fmtDate(_paymentDate),
      'amount': double.parse(_amount.text.trim()),
      'method': _method,
      if (combinedReference.isNotEmpty) 'reference': combinedReference,
      if (notes.isNotEmpty) 'notes': notes,
    };

    final res =
        await ApiService.pilotRecordVendorPayment(widget.billId, payload);
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
                    'تسجيل دفع للمورد — ${widget.invoiceNumber}',
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
              // G-VENDOR-PAYMENT-LABEL-DEDUP (2026-05-11): `card` is the
              // canonical Saudi-vocabulary key shipped in PR #198.
              // `credit_card` is the legacy back-compat entry —
              // relabeled with "(قديم)" so the cashier sees two
              // distinct rows. Backend regex still accepts both for
              // existing records. New payments should use `card`.
              _dropdown('طريقة الدفع', _method, const {
                'cash': 'نقداً',
                'bank_transfer': 'تحويل بنكي',
                'cheque': 'شيك',
                'card': 'بطاقة',
                'mada': 'مدى',
                'credit_card': 'بطاقة ائتمان (قديم)',
                'other': 'أخرى',
              }, (v) => setState(() => _method = v ?? 'bank_transfer')),
              _field('رقم المرجع (شيك/معاملة)', _reference),
              // Bank-account field visible only for bank_transfer —
              // keeps cash/cheque/card flows uncluttered.
              if (_method == 'bank_transfer')
                _field('الحساب البنكي المُرسِل', _bankAccount),
              _field('ملاحظات', _notes, maxLines: 2),
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
                            style:
                                TextStyle(color: AC.err, fontSize: 13))),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
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
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctl,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
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
