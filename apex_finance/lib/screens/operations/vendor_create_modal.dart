/// Vendor Create Modal — G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09).
///
/// A reusable modal that POSTs `/pilot/tenants/{id}/vendors` and
/// returns the created vendor Map on success. Used by:
///   * `VendorsListScreen` toolbar `+ مورد جديد` action
///   * `VendorPickerOrCreate` widget (Purchase Invoice line picker)
///
/// Validation rules:
///   * `legal_name_ar` required
///   * `code` auto-generated as `VEND-001` if blank
///   * `vat_number` 15 digits if provided
///   * `bank_iban` (KSA) starts with SA + 22 digits = 24 chars total
///     when provided; non-KSA IBANs accepted as-is (validated server-side)
///   * `email` simple `@` + `.` check if provided
///
/// Returns the created `Map<String, dynamic>` on success, null if the
/// user cancels or the API errors.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class VendorCreateModal extends StatefulWidget {
  /// If non-null, the modal pre-fills `legal_name_ar` with this string.
  final String? initialNameAr;

  const VendorCreateModal({super.key, this.initialNameAr});

  /// Convenience: shows as a Material dialog with a max-width of 580px.
  /// Returns the created vendor Map, or null if cancelled.
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
          constraints: const BoxConstraints(maxWidth: 580),
          child: VendorCreateModal(initialNameAr: initialNameAr),
        ),
      ),
    );
  }

  @override
  State<VendorCreateModal> createState() => _VendorCreateModalState();
}

class _VendorCreateModalState extends State<VendorCreateModal> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameAr = TextEditingController();
  final _legalNameEn = TextEditingController();
  final _tradeName = TextEditingController();
  final _code = TextEditingController();
  final _vat = TextEditingController();
  final _cr = TextEditingController();
  final _bankName = TextEditingController();
  final _iban = TextEditingController();
  final _swift = TextEditingController();
  final _contactName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _addr = TextEditingController();
  final _creditLimit = TextEditingController();

  String _kind = 'goods';
  String _country = 'SA';
  String _paymentTerms = 'net_60';
  String _currency = 'SAR';
  bool _isPreferred = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialNameAr != null && widget.initialNameAr!.isNotEmpty) {
      _legalNameAr.text = widget.initialNameAr!;
    }
  }

  @override
  void dispose() {
    _legalNameAr.dispose();
    _legalNameEn.dispose();
    _tradeName.dispose();
    _code.dispose();
    _vat.dispose();
    _cr.dispose();
    _bankName.dispose();
    _iban.dispose();
    _swift.dispose();
    _contactName.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _addr.dispose();
    _creditLimit.dispose();
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

  String? _validateIban(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final t = v.replaceAll(' ', '').toUpperCase();
    if (_country == 'SA') {
      // KSA IBAN: SA + 2 check digits + 4 bank + 18 BBAN = 24 chars total.
      if (t.length != 24 || !t.startsWith('SA')) {
        return 'IBAN السعودي يبدأ بـ SA + 22 رقماً (24 خانة)';
      }
      // After "SA" the remaining 22 must be digits.
      if (int.tryParse(t.substring(2)) == null) {
        return 'IBAN يحتوي على خانات غير رقمية';
      }
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
    if (tid == null) return 'VEND-001';
    final res = await ApiService.pilotListVendors(tid, limit: 500);
    if (!res.success || res.data is! List) return 'VEND-001';
    final existing = (res.data as List)
        .map((c) => (c['code'] ?? '').toString())
        .where((c) => c.startsWith('VEND-'))
        .map((c) => int.tryParse(c.substring(5)) ?? 0)
        .fold<int>(0, (a, b) => b > a ? b : a);
    return 'VEND-${(existing + 1).toString().padLeft(3, '0')}';
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
      'legal_name_ar': _legalNameAr.text.trim(),
      if (_legalNameEn.text.trim().isNotEmpty)
        'legal_name_en': _legalNameEn.text.trim(),
      if (_tradeName.text.trim().isNotEmpty)
        'trade_name': _tradeName.text.trim(),
      'kind': _kind,
      'country': _country,
      if (_cr.text.trim().isNotEmpty) 'cr_number': _cr.text.trim(),
      if (_vat.text.trim().isNotEmpty) 'vat_number': _vat.text.trim(),
      'default_currency': _currency,
      'payment_terms': _paymentTerms,
      if (_creditLimit.text.trim().isNotEmpty)
        'credit_limit': double.tryParse(_creditLimit.text.trim()),
      if (_bankName.text.trim().isNotEmpty)
        'bank_name': _bankName.text.trim(),
      if (_iban.text.trim().isNotEmpty)
        'bank_iban': _iban.text.replaceAll(' ', '').toUpperCase(),
      if (_swift.text.trim().isNotEmpty) 'bank_swift': _swift.text.trim(),
      if (_contactName.text.trim().isNotEmpty)
        'contact_name': _contactName.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_addr.text.trim().isNotEmpty) 'address_line1': _addr.text.trim(),
      if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      'is_preferred': _isPreferred,
    };

    final res = await ApiService.pilotCreateVendor(tid, payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res.success && res.data is Map) {
      Navigator.of(context).pop(res.data as Map<String, dynamic>);
    } else {
      setState(() => _error = res.error ?? 'تعذّر إنشاء المورد');
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
                  Icon(Icons.factory_rounded, color: AC.gold, size: 22),
                  const SizedBox(width: 10),
                  Text('مورد جديد',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AC.td),
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
                        _field('الاسم القانوني العربي *', _legalNameAr,
                            validator: _validateRequired),
                        _field('الاسم القانوني الإنجليزي', _legalNameEn),
                      ]),
                      _row([
                        _field('الاسم التجاري', _tradeName),
                        _field('الكود (تلقائي إن فارغ)', _code),
                      ]),
                      _row([
                        _dropdown('النوع', _kind, const {
                          'goods': 'سلع',
                          'services': 'خدمات',
                          'both': 'سلع وخدمات',
                          'employee': 'موظف',
                          'government': 'جهة حكومية',
                        }, (v) => setState(() => _kind = v ?? 'goods')),
                        _dropdown('الدولة', _country, const {
                          'SA': 'السعودية',
                          'AE': 'الإمارات',
                          'EG': 'مصر',
                          'KW': 'الكويت',
                          'BH': 'البحرين',
                          'QA': 'قطر',
                          'OM': 'عُمان',
                          'OT': 'دولة أخرى',
                        }, (v) => setState(() => _country = v ?? 'SA')),
                      ]),
                      _row([
                        _field('الرقم الضريبي (15 رقماً)', _vat,
                            validator: _validateVat,
                            keyboardType: TextInputType.number),
                        _field('السجل التجاري', _cr,
                            keyboardType: TextInputType.number),
                      ]),
                      _row([
                        _dropdown('شروط الدفع', _paymentTerms, const {
                          'cash': 'نقداً',
                          'net_0': 'فوري',
                          'net_15': 'صافي 15 يوماً',
                          'net_30': 'صافي 30 يوماً',
                          'net_45': 'صافي 45 يوماً',
                          'net_60': 'صافي 60 يوماً',
                          'net_90': 'صافي 90 يوماً',
                          'advance': 'دفعة مقدمة',
                        },
                            (v) =>
                                setState(() => _paymentTerms = v ?? 'net_60')),
                        _dropdown('العملة', _currency, const {
                          'SAR': 'ر.س',
                          'USD': 'USD',
                          'EUR': 'EUR',
                          'AED': 'د.إ',
                        }, (v) => setState(() => _currency = v ?? 'SAR')),
                      ]),
                      _row([
                        _field('اسم البنك', _bankName),
                        _field('SWIFT / BIC', _swift),
                      ]),
                      _field('IBAN', _iban,
                          validator: _validateIban,
                          hintAr: _country == 'SA'
                              ? 'SA + 22 رقماً (24 خانة)'
                              : 'IBAN دولي'),
                      _row([
                        _field('جهة الاتصال', _contactName),
                        _field('الهاتف', _phone,
                            keyboardType: TextInputType.phone),
                      ]),
                      _row([
                        _field('البريد', _email,
                            validator: _validateEmail,
                            keyboardType: TextInputType.emailAddress),
                        _field('المدينة', _city),
                      ]),
                      _field('العنوان', _addr),
                      _row([
                        _field('حد الائتمان', _creditLimit,
                            keyboardType: TextInputType.number),
                        SwitchListTile(
                          title: Text('مورد مفضّل',
                              style: TextStyle(
                                  color: AC.tp, fontSize: 12)),
                          value: _isPreferred,
                          onChanged: (v) =>
                              setState(() => _isPreferred = v),
                          activeColor: AC.gold,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ]),
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
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
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
    String? hintAr,
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
          hintText: hintAr,
          labelStyle: TextStyle(color: AC.td, fontSize: 12),
          hintStyle: TextStyle(color: AC.td, fontSize: 11),
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
          .map((e) =>
              DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
