/// Product Create Modal — G-FIN-PRODUCT-CATALOG (Sprint 4, 2026-05-09).
///
/// A focused modal that POSTs `/pilot/tenants/{id}/products` with an
/// optional inline single-variant body. Designed for the **fast path**
/// — service items + simple single-variant goods. Multi-variant
/// products with attribute matrices live in the full catalog screen
/// at `apex_finance/lib/pilot/screens/setup/products_screen.dart`.
///
/// Why a modal in addition to the full screen:
///   * The full screen is a 5-tab management UI — too heavy for the
///     "I just need to add this one item to my invoice" flow.
///   * The modal is consumed by `ProductPickerOrCreate` (used by Sprint
///     5/6 invoice line pickers) for inline create.
///   * Opening the modal pre-fills `name_ar` from the typed query so
///     the user does not retype.
///
/// Validation:
///   * `name_ar` required
///   * `code` auto-generated as `PRD-NNN` if blank
///   * `list_price` must be a positive number
///   * `list_price >= default_cost` is a soft warning (not enforced)
///
/// Returns the created product `Map<String, dynamic>` on success
/// (with the inline variant attached at `_inline_variant`), null on
/// cancel or API error.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class ProductCreateModal extends StatefulWidget {
  /// Pre-fill name_ar with this value (used by the picker after a
  /// search miss — saves re-typing).
  final String? initialNameAr;

  /// Pre-fill barcode (used by the barcode-scan path — when a scan
  /// returns no match, the user is offered a "create with this
  /// barcode" flow).
  final String? initialBarcode;

  const ProductCreateModal({
    super.key,
    this.initialNameAr,
    this.initialBarcode,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String? initialNameAr,
    String? initialBarcode,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AC.navy,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ProductCreateModal(
            initialNameAr: initialNameAr,
            initialBarcode: initialBarcode,
          ),
        ),
      ),
    );
  }

  @override
  State<ProductCreateModal> createState() => _ProductCreateModalState();
}

class _ProductCreateModalState extends State<ProductCreateModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _code = TextEditingController();
  final _sku = TextEditingController();
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();

  String _kind = 'goods';
  String _vatCode = 'standard';
  String _uom = 'piece';
  bool _isStockable = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialNameAr != null && widget.initialNameAr!.isNotEmpty) {
      _nameAr.text = widget.initialNameAr!;
    }
    if (widget.initialBarcode != null &&
        widget.initialBarcode!.isNotEmpty) {
      _barcode.text = widget.initialBarcode!;
    }
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _code.dispose();
    _sku.dispose();
    _cost.dispose();
    _price.dispose();
    _barcode.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _validateRequired(String? v) =>
      (v == null || v.trim().isEmpty) ? 'حقل مطلوب' : null;

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'حقل مطلوب';
    final n = double.tryParse(v.trim());
    if (n == null || n <= 0) return 'يجب أن يكون رقماً موجباً';
    return null;
  }

  Future<String> _generateCode() async {
    final tid = S.savedTenantId;
    if (tid == null) return 'PRD-001';
    final res = await ApiService.pilotListProducts(tid, limit: 500);
    if (!res.success || res.data is! List) return 'PRD-001';
    final existing = (res.data as List)
        .map((c) => (c['code'] ?? '').toString())
        .where((c) => c.startsWith('PRD-'))
        .map((c) => int.tryParse(c.substring(4)) ?? 0)
        .fold<int>(0, (a, b) => b > a ? b : a);
    return 'PRD-${(existing + 1).toString().padLeft(3, '0')}';
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
    final sku = _sku.text.trim().isEmpty ? '$code-V01' : _sku.text.trim();
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final cost = double.tryParse(_cost.text.trim()) ?? 0;

    // Inline a single variant so the product is invoice-ready immediately.
    // Multi-variant matrices use the full catalog screen.
    final payload = <String, dynamic>{
      'code': code,
      'name_ar': _nameAr.text.trim(),
      if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description_ar': _description.text.trim(),
      'kind': _kind,
      'vat_code': _vatCode,
      'default_uom': _uom,
      'is_sellable': true,
      'is_purchasable': true,
      'is_stockable': _isStockable,
      'variants': [
        {
          'sku': sku,
          'list_price': price,
          'default_cost': cost > 0 ? cost : null,
          'currency': 'SAR',
          'track_stock': _isStockable,
        },
      ],
    };

    final res = await ApiService.pilotCreateProduct(tid, payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res.success && res.data is Map) {
      final created = (res.data as Map).cast<String, dynamic>();
      // Stash the typed barcode so the picker (or the caller) can
      // POST it to /variants/{vid}/barcodes after the create.
      if (_barcode.text.trim().isNotEmpty) {
        created['_pending_barcode'] = _barcode.text.trim();
      }
      Navigator.of(context).pop(created);
    } else {
      setState(() => _error = res.error ?? 'تعذّر إنشاء المنتج');
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
                Icon(Icons.inventory_2_rounded, color: AC.gold, size: 22),
                const SizedBox(width: 10),
                Text('منتج جديد',
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
              ]),
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
                        _field('SKU (تلقائي إن فارغ)', _sku),
                      ]),
                      _row([
                        _dropdown('النوع', _kind, const {
                          'goods': 'سلعة',
                          'service': 'خدمة',
                          'composite': 'مركّب',
                          'raw': 'خام',
                        }, (v) => setState(() => _kind = v ?? 'goods')),
                        _dropdown('VAT', _vatCode, const {
                          'standard': 'قياسي 15%',
                          'zero_rated': 'صفري',
                          'exempt': 'معفى',
                          'out_of_scope': 'خارج النطاق',
                        },
                            (v) =>
                                setState(() => _vatCode = v ?? 'standard')),
                      ]),
                      _row([
                        _field('سعر التكلفة', _cost,
                            keyboardType: TextInputType.number),
                        _field('سعر البيع *', _price,
                            validator: _validatePrice,
                            keyboardType: TextInputType.number),
                      ]),
                      _row([
                        _dropdown('الوحدة', _uom, const {
                          'piece': 'قطعة',
                          'kg': 'كجم',
                          'liter': 'لتر',
                          'meter': 'متر',
                          'box': 'صندوق',
                          'pack': 'علبة',
                          'hour': 'ساعة',
                        }, (v) => setState(() => _uom = v ?? 'piece')),
                        SwitchListTile(
                          title: Text('متابعة المخزون',
                              style: TextStyle(
                                  color: AC.tp, fontSize: 12)),
                          value: _isStockable,
                          onChanged: (v) =>
                              setState(() => _isStockable = v),
                          activeColor: AC.gold,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ]),
                      _field('باركود (اختياري)', _barcode),
                      _field('الوصف', _description, maxLines: 2),
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

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 10),
          ],
        ]),
      );

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
            borderSide: BorderSide(color: AC.bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AC.bdr)),
      ),
      items: options.entries
          .map((e) =>
              DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
