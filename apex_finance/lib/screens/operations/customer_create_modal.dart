/// Customer Create Modal — G-FIN-CUSTOMERS-COMPLETE (Sprint 2, 2026-05-09).
///
/// A reusable modal that POSTs `/pilot/tenants/{id}/customers` and
/// returns the created customer Map on success. Used by:
///   * `CustomersListScreen` toolbar `+ عميل جديد` action
///   * `CustomerPickerOrCreate` widget (Sales Invoice line picker)
///
/// Validation rules:
///   * `name_ar` required
///   * `code` auto-generated as `CUST-001` if blank, with collision
///     avoidance via the seed pattern in `auto_seed_demo_data.py`
///   * `vat_number` 15 digits if provided
///   * `email` simple `@` + `.` check if provided
///
/// Returns the created `Map<String, dynamic>` on success, null if the
/// user cancels or the API errors.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class CustomerCreateModal extends StatefulWidget {
  /// If non-null, the modal pre-fills `name_ar` with this string —
  /// useful when opened from `CustomerPickerOrCreate` after the user
  /// typed a search query that didn't match any existing customer.
  final String? initialNameAr;

  const CustomerCreateModal({super.key, this.initialNameAr});

  /// Convenience: shows as a Material dialog with a max-width of 560px.
  /// Returns the created customer Map, or null if cancelled.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String? initialNameAr,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AC.navy,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: CustomerCreateModal(initialNameAr: initialNameAr),
        ),
      ),
    );
  }

  @override
  State<CustomerCreateModal> createState() => _CustomerCreateModalState();
}

class _CustomerCreateModalState extends State<CustomerCreateModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _code = TextEditingController();
  final _vat = TextEditingController();
  final _cr = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _street = TextEditingController();
  final _creditLimit = TextEditingController();
  final _notes = TextEditingController();
  String _paymentTerms = 'net_30';
  String _kind = 'company';
  String _currency = 'SAR';

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialNameAr != null && widget.initialNameAr!.isNotEmpty) {
      _nameAr.text = widget.initialNameAr!;
    }
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _code.dispose();
    _vat.dispose();
    _cr.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _street.dispose();
    _creditLimit.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _validateRequired(String? v) =>
      (v == null || v.trim().isEmpty) ? 'حقل مطلوب' : null;

  String? _validateVat(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final digits = v.trim();
    if (digits.length != 15 || int.tryParse(digits) == null) {
      return 'الرقم الضريبي 15 رقماً';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final t = v.trim();
    if (!t.contains('@') || !t.contains('.')) return 'بريد غير صالح';
    return null;
  }

  Future<String> _generateCode() async {
    final tid = S.savedTenantId;
    if (tid == null) return 'CUST-001';
    final res = await ApiService.pilotListCustomers(tid, limit: 500);
    if (!res.success || res.data is! List) return 'CUST-001';
    final existing = (res.data as List)
        .map((c) => (c['code'] ?? '').toString())
        .where((c) => c.startsWith('CUST-'))
        .map((c) {
      final n = int.tryParse(c.substring(5));
      return n ?? 0;
    }).fold<int>(0, (a, b) => b > a ? b : a);
    final next = (existing + 1).toString().padLeft(3, '0');
    return 'CUST-$next';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final tid = S.savedTenantId;
    if (tid == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final code = _code.text.trim().isEmpty
        ? await _generateCode()
        : _code.text.trim();

    final payload = <String, dynamic>{
      'code': code,
      'name_ar': _nameAr.text.trim(),
      if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
      'kind': _kind,
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_vat.text.trim().isNotEmpty) 'vat_number': _vat.text.trim(),
      if (_cr.text.trim().isNotEmpty) 'cr_number': _cr.text.trim(),
      if (_street.text.trim().isNotEmpty)
        'address_street': _street.text.trim(),
      if (_city.text.trim().isNotEmpty) 'address_city': _city.text.trim(),
      'currency': _currency,
      'payment_terms': _paymentTerms,
      if (_creditLimit.text.trim().isNotEmpty)
        'credit_limit': double.tryParse(_creditLimit.text.trim()),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };

    final res = await ApiService.pilotCreateCustomer(tid, payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res.success && res.data is Map) {
      Navigator.of(context).pop(res.data as Map<String, dynamic>);
    } else {
      setState(() => _error = res.error ?? 'تعذّر إنشاء العميل');
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
              Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: AC.gold, size: 22),
                  const SizedBox(width: 10),
                  Text('عميل جديد',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AC.td),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _row([
                        _field('الاسم العربي *', _nameAr,
                            validator: _validateRequired),
                        _field('الاسم الإنجليزي', _nameEn),
                      ]),
                      _row([
                        _field('الكود (تلقائي إن فارغ)', _code),
                        _dropdown('النوع', _kind, const {
                          'company': 'شركة',
                          'individual': 'فرد',
                        }, (v) => setState(() => _kind = v ?? 'company')),
                      ]),
                      _row([
                        _field('الرقم الضريبي (15 رقماً)', _vat,
                            validator: _validateVat,
                            keyboardType: TextInputType.number),
                        _field('رقم السجل التجاري', _cr,
                            keyboardType: TextInputType.number),
                      ]),
                      _row([
                        _field('البريد', _email,
                            validator: _validateEmail,
                            keyboardType: TextInputType.emailAddress),
                        _field('الهاتف', _phone,
                            keyboardType: TextInputType.phone),
                      ]),
                      _row([
                        _field('المدينة', _city),
                        _field('الشارع / العنوان', _street),
                      ]),
                      _row([
                        _dropdown('شروط الدفع', _paymentTerms, const {
                          'net_15': 'صافي 15 يوماً',
                          'net_30': 'صافي 30 يوماً',
                          'net_60': 'صافي 60 يوماً',
                          'net_90': 'صافي 90 يوماً',
                          'cash': 'نقداً',
                        }, (v) => setState(() => _paymentTerms = v ?? 'net_30')),
                        _dropdown('العملة', _currency, const {
                          'SAR': 'ر.س',
                          'USD': 'USD',
                          'EUR': 'EUR',
                          'AED': 'د.إ',
                        }, (v) => setState(() => _currency = v ?? 'SAR')),
                      ]),
                      _row([
                        _field('حد الائتمان', _creditLimit,
                            keyboardType: TextInputType.number),
                        const SizedBox(),
                      ]),
                      _field('ملاحظات', _notes, maxLines: 2),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AC.err.withValues(alpha: 0.10),
                    border: Border.all(color: AC.err.withValues(alpha: 0.4)),
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
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AC.gold,
                      foregroundColor: AC.navy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('حفظ',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 10),
          ],
        ],
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
    return TextFormField(
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
          borderSide: BorderSide(color: AC.bdr),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AC.bdr),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AC.gold, width: 1.4),
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
    return DropdownButtonFormField<String>(
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
          borderSide: BorderSide(color: AC.bdr),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AC.bdr),
        ),
      ),
      items: options.entries
          .map((e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
