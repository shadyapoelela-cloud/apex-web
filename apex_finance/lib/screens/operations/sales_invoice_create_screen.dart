/// APEX — Dedicated "Create Sales Invoice" form.
///
/// Path: `/app/erp/sales/invoice-create`.
///
/// G-FIN-SALES-INVOICE-JE-AUTOPOST (Sprint 5, 2026-05-09):
///   * customer picker upgraded to `CustomerPickerOrCreate` so users
///     can create a customer inline without leaving the invoice form
///     (the #1 friction point — most invoices are typed before the
///     customer record exists)
///   * `Save as Draft` button added alongside the existing `Issue`
///     button so users can park a half-finished invoice without
///     immediately auto-posting a JE
///   * success snackbar surfaces the `je_id` returned by
///     `/sales-invoices/{id}/issue` and links to the journal-entries
///     list so the auto-post is verifiable in one click
///
/// The backend JE auto-post (`_post_sales_invoice_je` in
/// app/pilot/routes/customer_routes.py:364) was implemented before
/// this sprint — issuing a draft invoice triggers the standard
/// 3-leg JE: DR Customer Receivable / CR Sales Revenue / CR VAT
/// Output, balanced to the cent.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/forms/customer_picker_or_create.dart';
// G-SALES-INVOICE-UX-COMPLETE (2026-05-10): product picker (search +
// barcode) integrated as the primary line input. Selecting a product
// auto-fills description / unit_price / vat_rate. Closes UX issue #2:
// the line was a free-text box with no link to the product catalogue.
import '../../widgets/forms/product_picker_or_create.dart';

class SalesInvoiceCreateScreen extends StatefulWidget {
  const SalesInvoiceCreateScreen({super.key});
  @override
  State<SalesInvoiceCreateScreen> createState() =>
      _SalesInvoiceCreateScreenState();
}

class _SalesInvoiceCreateScreenState extends State<SalesInvoiceCreateScreen> {
  final _amountCtrl = TextEditingController();
  final _vatRateCtrl = TextEditingController(text: '15');
  final _descCtrl = TextEditingController();

  Map<String, dynamic>? _selectedCustomer;
  // G-SALES-INVOICE-UX-COMPLETE (2026-05-10): selected product/variant
  // for the (single) invoice line. Persisted onto the payload as
  // `product_id` + `variant_id` so the backend can later run the COGS
  // JE leg when product cost is known.
  Map<String, dynamic>? _selectedProduct;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  // CustomerPickerOrCreate handles its own loading now, so the previous
  // tenant-wide _loading guard is no longer needed.
  final bool _loading = false;
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

  String? get _selectedCustomerId =>
      (_selectedCustomer?['id'] ?? '').toString().isEmpty
          ? null
          : _selectedCustomer!['id'].toString();

  /// G-SALES-INVOICE-UX-COMPLETE (2026-05-10): on product pick, fill
  /// the description + unit_price + VAT-rate fields. The user can still
  /// override any of them after selection. Reads variant fields when
  /// the product was created via the modal's inline-variant flow.
  void _onProductSelected(Map<String, dynamic> p) {
    setState(() {
      _selectedProduct = p;
      // description: prefer name_ar, fall back to name_en or code.
      final desc = (p['name_ar'] ?? p['name_en'] ?? p['code'] ?? '').toString();
      if (desc.isNotEmpty) _descCtrl.text = desc;
      // unit price: read from first variant.list_price if present.
      final variants = (p['variants'] as List?) ?? const [];
      if (variants.isNotEmpty) {
        final v0 = variants.first as Map?;
        final price = v0?['list_price'];
        if (price != null) _amountCtrl.text = '$price';
      }
      // vat_rate: backend uses vat_code at the product level — UI keeps
      // the existing 15% default unless code says zero/exempt.
      final vatCode = (p['vat_code'] ?? '').toString();
      if (vatCode == 'zero_rated' || vatCode == 'exempt') {
        _vatRateCtrl.text = '0';
      } else {
        _vatRateCtrl.text = '15';
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _vatRateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isIssue) async {
    final initial = isIssue ? _issueDate : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isIssue) {
          _issueDate = picked;
          if (_dueDate.isBefore(_issueDate)) {
            _dueDate = _issueDate.add(const Duration(days: 30));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  /// Validates the form and returns a `(tenantId, entityId, payload)` tuple,
  /// or null on validation failure (with `_error` set).
  Map<String, dynamic>? _buildPayload() {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return null;
    }
    if (_selectedCustomerId == null) {
      setState(() => _error = 'اختر عميلاً أولاً');
      return null;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'المبلغ غير صحيح');
      return null;
    }
    final vatRate = double.tryParse(_vatRateCtrl.text.trim()) ?? 15;
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'الوصف مطلوب');
      return null;
    }
    final productId = _selectedProduct?['id']?.toString();
    final variants = (_selectedProduct?['variants'] as List?) ?? const [];
    String? variantId;
    if (variants.isNotEmpty) {
      final v0 = variants.first;
      if (v0 is Map) variantId = v0['id']?.toString();
    }
    return {
      'tenant_id': tenantId,
      'entity_id': entityId,
      'customer_id': _selectedCustomerId,
      'issue_date': _fmtDate(_issueDate),
      'due_date': _fmtDate(_dueDate),
      'currency': 'SAR',
      'lines': [
        {
          if (productId != null) 'product_id': productId,
          if (variantId != null) 'variant_id': variantId,
          'description': desc,
          'quantity': 1,
          'unit_price': amount,
          'vat_rate': vatRate,
        }
      ],
    };
  }

  /// Save without issuing — leaves the invoice as a draft so the user
  /// can come back and edit. No JE auto-post happens until `/issue`.
  Future<void> _saveDraft() async {
    final payload = _buildPayload();
    if (payload == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final create = await ApiService.pilotCreateSalesInvoice(payload);
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
    context.go('/app/erp/finance/sales-invoices');
  }

  /// Create + immediately issue. Issuing triggers the backend
  /// `_post_sales_invoice_je` (customer_routes.py:364) which auto-posts
  /// the standard 3-leg JE: DR Receivable / CR Revenue / CR VAT Output.
  Future<void> _submit() async {
    final payload = _buildPayload();
    if (payload == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final create = await ApiService.pilotCreateSalesInvoice(payload);
    if (!mounted) return;
    if (!create.success) {
      setState(() {
        _submitting = false;
        _error = 'فشل إنشاء الفاتورة: ${create.error ?? '-'}';
      });
      return;
    }
    final invId = (create.data as Map?)?['id'] as String?;
    if (invId == null) {
      setState(() {
        _submitting = false;
        _error = 'استجابة غير متوقعة';
      });
      return;
    }
    final issue = await ApiService.pilotIssueSalesInvoice(invId);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!issue.success) {
      setState(() => _error = 'فشل إصدار الفاتورة: ${issue.error ?? '-'}');
      return;
    }
    final issueData = (issue.data as Map?) ?? const {};
    final jeId = issueData['journal_entry_id']?.toString();
    final invNum = issueData['invoice_number']?.toString() ?? '';
    // G-FIN-SALES-INVOICE-JE-AUTOPOST: surface the JE id so the user
    // can verify the auto-post in one click. Action button takes the
    // user straight to the journal-entries list.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      duration: const Duration(seconds: 6),
      content: Text(jeId == null
          ? 'تم إصدار الفاتورة #$invNum (بدون رقم قيد)'
          : 'تم إصدار الفاتورة #$invNum — قيد اليومية #$jeId'),
      action: jeId == null
          ? null
          : SnackBarAction(
              label: 'عرض القيد',
              textColor: AC.navy,
              onPressed: () =>
                  context.go('/app/erp/finance/je-builder'),
            ),
    ));
    context.go('/app/erp/finance/sales-invoices');
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AC.gold),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/app/erp/finance/sales-invoices'),
        ),
        title: Text('فاتورة مبيعات جديدة',
            style: TextStyle(
                color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AC.gold))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) _errorBanner(_error!),
                      _section('العميل', Icons.person_outline,
                          child: _customerPicker()),
                      const SizedBox(height: 16),
                      _section('تفاصيل الفاتورة', Icons.receipt_long, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // G-SALES-INVOICE-UX-COMPLETE (2026-05-10):
                          // Product picker first — selecting a product
                          // auto-fills description + unit_price + VAT.
                          // The picker also handles barcode lookup
                          // (numeric input on Enter or via the dedicated
                          // QR icon button) and inline product-create.
                          ProductPickerOrCreate(
                            initial: _selectedProduct,
                            labelText: 'المنتج (اختياري — أو اكتب وصفاً يدوياً)',
                            onSelected: _onProductSelected,
                          ),
                          const SizedBox(height: 10),
                          _input(_descCtrl, 'الوصف (الخدمة/المنتج)',
                              Icons.description),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: _input(_amountCtrl,
                                    'المبلغ (قبل VAT)', Icons.attach_money,
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
                            Expanded(child: _datePicker('تاريخ الإصدار',
                                _issueDate, () => _pickDate(true))),
                            const SizedBox(width: 10),
                            Expanded(child: _datePicker('تاريخ الاستحقاق',
                                _dueDate, () => _pickDate(false))),
                          ]),
                        ],
                      )),
                      const SizedBox(height: 24),
                      // G-FIN-SALES-INVOICE-JE-AUTOPOST (Sprint 5):
                      // Two-button layout. Save Draft creates the
                      // invoice in `draft` status without triggering
                      // the JE auto-post. Issue creates + immediately
                      // posts the standard 3-leg JE
                      // (DR AR / CR Revenue / CR VAT Output).
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
                                  ? 'جارٍ الإصدار…'
                                  : 'إنشاء وإصدار — يرحَّل القيد تلقائياً'),
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
                            context.go('/app/erp/finance/sales-invoices'),
                        child: Text('إلغاء',
                            style: TextStyle(color: AC.ts, fontSize: 12)),
                      ),
                    ],
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
              child:
                  Text(msg, style: TextStyle(color: AC.err, fontSize: 12.5))),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  // G-FIN-SALES-INVOICE-JE-AUTOPOST (Sprint 5, 2026-05-09):
  // CustomerPickerOrCreate replaces the previous DropdownButtonFormField.
  // The old dropdown forced users to leave the invoice form to create
  // a customer that didn't exist yet — the most-asked UX nit. The
  // picker autocompletes the existing roster AND offers an inline
  // "+ عميل جديد" that opens CustomerCreateModal with the typed query
  // pre-filled, then auto-selects the new customer on save.
  Widget _customerPicker() {
    return CustomerPickerOrCreate(
      initial: _selectedCustomer,
      onSelected: (c) => setState(() => _selectedCustomer = c),
    );
  }

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
              style: TextStyle(
                  color: AC.tp, fontSize: 13, fontFamily: 'monospace')),
        ),
      );
}
