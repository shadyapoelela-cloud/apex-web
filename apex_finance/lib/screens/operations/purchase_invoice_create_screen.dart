/// APEX — Dedicated "Create Purchase Invoice" form.
///
/// G-FIN-PURCHASE-INVOICE-JE-AUTOPOST (Sprint 6, 2026-05-09).
///
/// Mirror of [SalesInvoiceCreateScreen] for the inbound side. The
/// backend JE auto-post for purchases lives at
/// `app/pilot/services/purchasing_engine.py:post_purchase_invoice_to_gl`
/// and is triggered by `POST /pilot/purchase-invoices/{id}/post`. The
/// JE shape is the standard 3-leg purchase entry:
///
///   DR Inventory (1140) or Expense  subtotal
///   DR VAT Input Receivable (1150)  vat
///   CR Vendor Payable (subcategory='payables')  total
///
/// Two save buttons:
///   * **حفظ كمسودة** — POST `/purchase-invoices` only, no auto-post
///   * **حفظ وترحيل** — POST then POST `/post`, triggering the JE
///
/// Success snackbar surfaces the `journal_entry_id` from the post
/// response with an action link to `/app/erp/finance/je-builder`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/forms/vendor_picker_or_create.dart';

class PurchaseInvoiceCreateScreen extends StatefulWidget {
  const PurchaseInvoiceCreateScreen({super.key});
  @override
  State<PurchaseInvoiceCreateScreen> createState() =>
      _PurchaseInvoiceCreateScreenState();
}

class _PurchaseInvoiceCreateScreenState
    extends State<PurchaseInvoiceCreateScreen> {
  final _vendorInvoiceNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _vatRateCtrl = TextEditingController(text: '15');
  final _descCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController(text: '0');

  Map<String, dynamic>? _selectedVendor;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 60));

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      _error = 'لا يوجد كيان نشط — أكمل التسجيل أولاً';
    }
  }

  @override
  void dispose() {
    _vendorInvoiceNumberCtrl.dispose();
    _amountCtrl.dispose();
    _vatRateCtrl.dispose();
    _descCtrl.dispose();
    _shippingCtrl.dispose();
    super.dispose();
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
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'المبلغ غير صحيح');
      return null;
    }
    final vatRate = double.tryParse(_vatRateCtrl.text.trim()) ?? 15;
    final shipping = double.tryParse(_shippingCtrl.text.trim()) ?? 0;
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'الوصف مطلوب');
      return null;
    }
    return {
      'entity_id': entityId,
      'vendor_id': _selectedVendorId,
      'invoice_date': _fmtDate(_invoiceDate),
      'due_date': _fmtDate(_dueDate),
      if (_vendorInvoiceNumberCtrl.text.trim().isNotEmpty)
        'vendor_invoice_number': _vendorInvoiceNumberCtrl.text.trim(),
      'shipping': shipping,
      'lines': [
        {
          'description': desc,
          'qty': 1,
          'unit_cost': amount,
          'vat_rate_pct': vatRate,
          'vat_code': 'standard',
        }
      ],
    };
  }

  /// Save without posting — invoice stays in `draft` status, no JE.
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
      content:
          Text('تم حفظ المسودة #$invNum — لم يُرحَّل القيد بعد'),
    ));
    context.go('/app/erp/finance/purchase-bills');
  }

  /// Create + post. Posting triggers `post_purchase_invoice_to_gl`
  /// (purchasing_engine.py) which auto-builds the 3-leg purchase JE.
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
              onPressed: () => context.go('/app/erp/finance/je-builder'),
            ),
    ));
    context.go('/app/erp/finance/purchase-bills');
  }

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
          title: Text('فاتورة شراء جديدة',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _input(_vendorInvoiceNumberCtrl,
                              'رقم فاتورة المورد (اختياري)',
                              Icons.numbers_rounded),
                          const SizedBox(height: 10),
                          _input(_descCtrl, 'الوصف (الخدمة/المنتج)',
                              Icons.description),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: _input(
                                    _amountCtrl,
                                    'المبلغ (قبل VAT)',
                                    Icons.attach_money,
                                    keyboard: TextInputType.number)),
                            const SizedBox(width: 10),
                            SizedBox(
                                width: 120,
                                child: _input(_vatRateCtrl, 'VAT %',
                                    Icons.percent,
                                    keyboard: TextInputType.number)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: _input(
                                    _shippingCtrl,
                                    'الشحن',
                                    Icons.local_shipping_outlined,
                                    keyboard: TextInputType.number)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: _datePicker('تاريخ الفاتورة',
                                    _invoiceDate, () => _pickDate(true))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _datePicker('تاريخ الاستحقاق',
                                    _dueDate, () => _pickDate(false))),
                          ]),
                        ],
                      )),
                  const SizedBox(height: 24),
                  // G-FIN-PURCHASE-INVOICE-JE-AUTOPOST: two-button row.
                  // Save Draft creates without posting (no JE). Save+Post
                  // creates + posts → triggers post_purchase_invoice_to_gl
                  // which auto-builds the standard 3-leg purchase JE
                  // (DR Inventory or Expense / DR VAT Input / CR Payable).
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _saveDraft,
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
                    onPressed: () =>
                        context.go('/app/erp/finance/purchase-bills'),
                    child: Text('إلغاء',
                        style: TextStyle(color: AC.ts, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
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
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: TextStyle(color: AC.tp, fontSize: 13.5),
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
