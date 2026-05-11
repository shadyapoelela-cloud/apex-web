/// APEX — Create / Edit Purchase Invoice (multi-line).
///
/// G-PURCHASE-MULTILINE-PARITY (2026-05-11). Mirrors the sales-invoice
/// pattern shipped in PR #189 — `_PiLineDraft` per line with its own
/// controllers + product picker, `?bill_id=` prefill on the route,
/// lock-on-non-draft, qty>stock warning.
///
/// Backend route: `POST /pilot/purchase-invoices` then
/// `POST /pilot/purchase-invoices/{id}/post` to trigger the JE
/// auto-post via `app/pilot/services/purchasing_engine.py:
/// post_purchase_invoice_to_gl`. The JE is the standard 3-leg purchase
/// entry:
///
///   DR Inventory (1140) or Expense  subtotal
///   DR VAT Input Receivable (1150)  vat
///   CR Vendor Payable                total
///
/// Two save buttons (only when not in edit-lock mode):
///   * **حفظ كمسودة** — POST `/purchase-invoices` only, no auto-post.
///   * **حفظ وترحيل** — POST then POST `/post`, triggering the JE.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/forms/product_picker_or_create.dart';
import '../../widgets/forms/vendor_picker_or_create.dart';

/// Per-line draft. Owns its 4 controllers so each line can be edited
/// independently without one row overwriting another.
class _PiLineDraft {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController unitCost;
  final TextEditingController vatRate;
  Map<String, dynamic>? product;

  _PiLineDraft({
    String description = '',
    String quantity = '1',
    String cost = '',
    String vat = '15',
  })  : desc = TextEditingController(text: description),
        qty = TextEditingController(text: quantity),
        unitCost = TextEditingController(text: cost),
        vatRate = TextEditingController(text: vat);

  void dispose() {
    desc.dispose();
    qty.dispose();
    unitCost.dispose();
    vatRate.dispose();
  }

  double get quantityValue => double.tryParse(qty.text.trim()) ?? 0;
  double get unitCostValue => double.tryParse(unitCost.text.trim()) ?? 0;
  double get vatRateValue => double.tryParse(vatRate.text.trim()) ?? 0;
  double get subtotal => quantityValue * unitCostValue;
  double get vatAmount => subtotal * vatRateValue / 100;
  double get lineTotal => subtotal + vatAmount;
}

class PurchaseInvoiceCreateScreen extends StatefulWidget {
  /// When set, the form fetches the existing bill and hydrates the
  /// fields for editing. Routed via `?bill_id=` query param.
  final String? prefillBillId;

  const PurchaseInvoiceCreateScreen({super.key, this.prefillBillId});
  @override
  State<PurchaseInvoiceCreateScreen> createState() =>
      _PurchaseInvoiceCreateScreenState();
}

class _PurchaseInvoiceCreateScreenState
    extends State<PurchaseInvoiceCreateScreen> {
  final _vendorInvoiceNumberCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController(text: '0');
  final List<_PiLineDraft> _lines = [_PiLineDraft()];

  Map<String, dynamic>? _selectedVendor;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 60));

  bool _submitting = false;
  bool _loadingPrefill = false;
  // Locked when editing a non-draft PI (status != draft). Backend would
  // reject the change anyway and reversing a posted PI is destructive,
  // so the UI gates this upfront with a banner.
  bool _editLocked = false;
  String? _prefillStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      _error = 'لا يوجد كيان نشط — أكمل التسجيل أولاً';
    }
    if (widget.prefillBillId != null) {
      _loadingPrefill = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillFromBill(widget.prefillBillId!);
      });
    }
  }

  @override
  void dispose() {
    _vendorInvoiceNumberCtrl.dispose();
    _shippingCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _prefillFromBill(String id) async {
    final res = await ApiService.pilotGetPurchaseInvoice(id);
    if (!mounted) return;
    if (!res.success || res.data is! Map) {
      setState(() {
        _loadingPrefill = false;
        _error = 'تعذّر تحميل الفاتورة: ${res.error ?? '-'}';
      });
      return;
    }
    final inv = (res.data as Map).cast<String, dynamic>();
    final status = (inv['status'] ?? '').toString();
    final isDraft = status == 'draft';
    setState(() {
      _prefillStatus = status;
      _editLocked = !isDraft;
      _vendorInvoiceNumberCtrl.text =
          inv['vendor_invoice_number']?.toString() ?? '';
      _shippingCtrl.text = (inv['shipping'] ?? 0).toString();
      final dt = DateTime.tryParse(inv['invoice_date']?.toString() ?? '');
      if (dt != null) _invoiceDate = dt;
      final du = DateTime.tryParse(inv['due_date']?.toString() ?? '');
      if (du != null) _dueDate = du;
      _selectedVendor = {
        'id': inv['vendor_id'],
        'name_ar': inv['vendor_name_ar'] ?? inv['vendor_name'] ?? '',
      };
      // Replace single empty line with the actual lines from server.
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      final lns = (inv['lines'] as List?) ?? const [];
      for (final ln in lns) {
        if (ln is Map) {
          _lines.add(_PiLineDraft(
            description: ln['description']?.toString() ?? '',
            quantity: (ln['qty'] ?? '1').toString(),
            cost: (ln['unit_cost'] ?? '').toString(),
            vat: (ln['vat_rate_pct'] ?? '15').toString(),
          ));
        }
      }
      if (_lines.isEmpty) _lines.add(_PiLineDraft());
      _loadingPrefill = false;
    });
  }

  void _addLine() {
    setState(() => _lines.add(_PiLineDraft()));
  }

  void _removeLine(int index) {
    // Guard: never empty the list — the validator below would refuse
    // it anyway, but emptying the UI then re-creating an invisible
    // empty line is jarring.
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  /// Non-blocking informational warning when qty > total_stock_on_hand
  /// for a stockable product on this line. Submit is NOT gated on
  /// this — the backend is the source of truth for negative-stock
  /// policy. Note: on the *purchase* side this warning is rare (we're
  /// adding stock, not consuming it) — kept here only to mirror the
  /// sales pattern for products bought-then-immediately-consumed.
  String? _stockWarning(_PiLineDraft line) {
    final p = line.product;
    if (p == null) return null;
    if (p['is_stockable'] == false) return null;
    final stock = double.tryParse('${p['total_stock_on_hand'] ?? 0}') ?? 0;
    final q = line.quantityValue;
    if (q <= 0) return null;
    if (q <= stock) return null;
    return 'الكمية ($q) تتجاوز المخزون المتوفر (${stock.toStringAsFixed(0)})';
  }

  String? get _selectedVendorId =>
      (_selectedVendor?['id'] ?? '').toString().isEmpty
          ? null
          : _selectedVendor!['id'].toString();

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isInvoice) async {
    final initial = isInvoice ? _invoiceDate : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isInvoice) {
          _invoiceDate = picked;
          if (_dueDate.isBefore(_invoiceDate)) {
            _dueDate = _invoiceDate.add(const Duration(days: 60));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Map<String, dynamic>? _buildPayload() {
    final entityId = S.savedEntityId;
    if (entityId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return null;
    }
    if (_selectedVendorId == null) {
      setState(() => _error = 'اختر مورّداً أولاً');
      return null;
    }
    // Validate every line — empty desc, zero qty, zero cost are
    // rejected up-front so the user gets clear feedback per line
    // rather than a single backend 400.
    final linesPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final desc = l.desc.text.trim();
      if (desc.isEmpty) {
        setState(() => _error = 'البند ${i + 1}: الوصف مطلوب');
        return null;
      }
      if (l.quantityValue <= 0) {
        setState(() => _error = 'البند ${i + 1}: الكمية غير صحيحة');
        return null;
      }
      if (l.unitCostValue <= 0) {
        setState(() => _error = 'البند ${i + 1}: السعر غير صحيح');
        return null;
      }
      linesPayload.add({
        'description': desc,
        'qty': l.quantityValue,
        'unit_cost': l.unitCostValue,
        'vat_rate_pct': l.vatRateValue,
        'vat_code': 'standard',
        if (l.product != null && l.product!['default_variant_id'] != null)
          'variant_id': l.product!['default_variant_id'],
        if (l.product != null && l.product!['code'] != null)
          'sku': l.product!['code'],
      });
    }
    final shipping = double.tryParse(_shippingCtrl.text.trim()) ?? 0;
    return {
      'entity_id': entityId,
      'vendor_id': _selectedVendorId,
      'invoice_date': _fmtDate(_invoiceDate),
      'due_date': _fmtDate(_dueDate),
      if (_vendorInvoiceNumberCtrl.text.trim().isNotEmpty)
        'vendor_invoice_number': _vendorInvoiceNumberCtrl.text.trim(),
      'shipping': shipping,
      'lines': linesPayload,
    };
  }

  Future<void> _saveDraft() async {
    final payload = _buildPayload();
    if (payload == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final create = await ApiService.pilotCreatePurchaseInvoice(payload);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!create.success) {
      setState(() => _error = 'فشل حفظ المسودة: ${create.error ?? '-'}');
      return;
    }
    final invNum = (create.data as Map?)?['invoice_number'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.info,
      content: Text('تم حفظ المسودة #$invNum — لم يُرحَّل القيد بعد'),
    ));
    context.go('/app/erp/finance/purchase-bills');
  }

  Future<void> _submit() async {
    final payload = _buildPayload();
    if (payload == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final create = await ApiService.pilotCreatePurchaseInvoice(payload);
    if (!mounted) return;
    if (!create.success) {
      setState(() {
        _submitting = false;
        _error = 'فشل إنشاء الفاتورة: ${create.error ?? '-'}';
      });
      return;
    }
    final piId = (create.data as Map?)?['id'] as String?;
    if (piId == null) {
      setState(() {
        _submitting = false;
        _error = 'استجابة غير متوقعة';
      });
      return;
    }
    final post = await ApiService.pilotPostPurchaseInvoice(piId);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!post.success) {
      setState(() => _error = 'فشل ترحيل الفاتورة: ${post.error ?? '-'}');
      return;
    }
    final postData = (post.data as Map?) ?? const {};
    final jeId = postData['journal_entry_id']?.toString();
    final invNum = postData['invoice_number']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      duration: const Duration(seconds: 6),
      content: Text(jeId == null
          ? 'تم ترحيل الفاتورة #$invNum (بدون رقم قيد)'
          : 'تم ترحيل الفاتورة #$invNum — قيد اليومية #$jeId'),
      action: jeId == null
          ? null
          : SnackBarAction(
              label: 'عرض القيد',
              textColor: AC.navy,
              onPressed: () => context.go('/app/erp/finance/je-builder/$jeId'),
            ),
    ));
    context.go('/app/erp/finance/purchase-bills');
  }

  double get _grandSubtotal => _lines.fold(0.0, (s, l) => s + l.subtotal);
  double get _grandVat => _lines.fold(0.0, (s, l) => s + l.vatAmount);
  double get _grandTotal =>
      _grandSubtotal +
      _grandVat +
      (double.tryParse(_shippingCtrl.text.trim()) ?? 0);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AC.gold),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/app/erp/finance/purchase-bills'),
          ),
          title: Text(
              widget.prefillBillId != null
                  ? 'تعديل فاتورة شراء'
                  : 'فاتورة شراء جديدة',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
        body: _loadingPrefill
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AbsorbPointer(
                      absorbing: _editLocked,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_editLocked) _readOnlyBanner(),
                          if (_error != null) _errorBanner(_error!),
                          _section('المورد', Icons.factory_outlined,
                              child: VendorPickerOrCreate(
                                initial: _selectedVendor,
                                onSelected: (v) =>
                                    setState(() => _selectedVendor = v),
                              )),
                          const SizedBox(height: 16),
                          _section('تفاصيل الفاتورة', Icons.receipt_long,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  _input(_vendorInvoiceNumberCtrl,
                                      'رقم فاتورة المورد (اختياري)',
                                      Icons.numbers_rounded),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                        child: _datePicker('تاريخ الفاتورة',
                                            _invoiceDate,
                                            () => _pickDate(true))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: _datePicker(
                                            'تاريخ الاستحقاق',
                                            _dueDate,
                                            () => _pickDate(false))),
                                  ]),
                                  const SizedBox(height: 10),
                                  _input(_shippingCtrl, 'الشحن (إن وُجد)',
                                      Icons.local_shipping_outlined,
                                      keyboard: TextInputType.number),
                                ],
                              )),
                          const SizedBox(height: 16),
                          _section('البنود', Icons.list_alt,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  for (int i = 0; i < _lines.length; i++)
                                    _lineCard(i),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _addLine,
                                    icon: Icon(Icons.add,
                                        color: AC.gold, size: 18),
                                    label: Text('+ إضافة بند',
                                        style: TextStyle(
                                            color: AC.gold,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                    style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: AC.gold
                                                .withValues(alpha: 0.4)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12)),
                                  ),
                                ],
                              )),
                          const SizedBox(height: 16),
                          _totalsFooter(),
                          const SizedBox(height: 24),
                          if (!_editLocked)
                            Row(children: [
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _submitting ? null : _saveDraft,
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('حفظ كمسودة'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: AC.tp,
                                        side: BorderSide(color: AC.bdr),
                                        textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitting ? null : _submit,
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(Icons.send),
                                    label: Text(_submitting
                                        ? 'جارٍ الترحيل…'
                                        : 'حفظ وترحيل — يرحَّل القيد تلقائياً'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AC.gold,
                                        foregroundColor: AC.navy,
                                        textStyle: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ),
                            ]),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context
                                .go('/app/erp/finance/purchase-bills'),
                            child: Text('إلغاء',
                                style:
                                    TextStyle(color: AC.ts, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _lineCard(int index) {
    final l = _lines[index];
    final warn = _stockWarning(l);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
                    fontSize: 12,
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
            ),
          ]),
          const SizedBox(height: 8),
          ProductPickerOrCreate(
            initial: l.product,
            labelText: 'المنتج / الباركود (اختياري)',
            onSelected: (p) {
              setState(() {
                l.product = p;
                l.desc.text = (p['name_ar'] ?? '').toString();
                final cost = (p['default_cost'] ?? p['list_price']);
                if (cost != null && l.unitCost.text.trim().isEmpty) {
                  l.unitCost.text = cost.toString();
                }
              });
            },
          ),
          const SizedBox(height: 10),
          _input(l.desc, 'الوصف', Icons.description),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _input(l.qty, 'الكمية', Icons.numbers,
                    keyboard: TextInputType.number, onChange: () {
              setState(() {});
            })),
            const SizedBox(width: 10),
            Expanded(
                child: _input(l.unitCost, 'سعر التكلفة', Icons.attach_money,
                    keyboard: TextInputType.number, onChange: () {
              setState(() {});
            })),
            const SizedBox(width: 10),
            SizedBox(
                width: 100,
                child: _input(l.vatRate, 'VAT %', Icons.percent,
                    keyboard: TextInputType.number, onChange: () {
              setState(() {});
            })),
          ]),
          const SizedBox(height: 10),
          if (warn != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AC.warn.withValues(alpha: 0.12),
                border: Border.all(color: AC.warn.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: AC.warn, size: 14),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(warn,
                        style: TextStyle(color: AC.warn, fontSize: 11))),
              ]),
            ),
          Row(children: [
            Text('الإجمالي',
                style: TextStyle(color: AC.td, fontSize: 11)),
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

  Widget _totalsFooter() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          _totalRow('المجموع الفرعي', _grandSubtotal),
          _totalRow('VAT', _grandVat),
          _totalRow('الشحن',
              double.tryParse(_shippingCtrl.text.trim()) ?? 0),
          Divider(color: AC.bdr, height: 16),
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
                  fontSize: emphasize ? 13 : 12,
                  fontWeight: emphasize
                      ? FontWeight.w700
                      : FontWeight.w400)),
          const Spacer(),
          Text('${v.toStringAsFixed(2)} SAR',
              style: TextStyle(
                  color: emphasize ? AC.gold : AC.tp,
                  fontSize: emphasize ? 14 : 12,
                  fontWeight:
                      emphasize ? FontWeight.w800 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );

  Widget _readOnlyBanner() {
    final st = _prefillStatus ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.warn.withValues(alpha: 0.12),
        border: Border.all(color: AC.warn.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline, color: AC.warn, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              "هذه الفاتورة في حالة '$st' — لا يمكن تعديلها.",
              style: TextStyle(color: AC.warn, fontSize: 12.5)),
        ),
        TextButton(
          onPressed: () => context.go(
              '/app/erp/finance/purchase-bills/${widget.prefillBillId}'),
          child: Text('فتح التفاصيل',
              style: TextStyle(
                  color: AC.gold, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _errorBanner(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.errSoft,
          border: Border.all(color: AC.err.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: AC.err, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: AC.err, fontSize: 12.5))),
        ]),
      );

  Widget _section(String title, IconData icon, {required Widget child}) =>
      Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AC.navy3,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10)),
                ),
                child: Row(children: [
                  Icon(icon, color: AC.gold, size: 16),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          color: AC.gold,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(12), child: child),
            ]),
      );

  Widget _input(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard, VoidCallback? onChange}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: TextStyle(color: AC.tp, fontSize: 13.5),
      onChanged: onChange == null ? null : (_) => onChange(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        prefixIcon: Icon(icon, color: AC.gold, size: 18),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AC.bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AC.bdr)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AC.gold)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }

  Widget _datePicker(String label, DateTime value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AC.ts, fontSize: 12),
            prefixIcon:
                Icon(Icons.calendar_month, color: AC.gold, size: 18),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          child: Text(_fmtDate(value),
              style: TextStyle(color: AC.tp, fontSize: 13)),
        ),
      );
}
