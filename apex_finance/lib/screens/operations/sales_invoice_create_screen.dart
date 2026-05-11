/// APEX — Dedicated "Create / Edit Sales Invoice" form.
///
/// Path: `/app/erp/sales/invoice-create` (create) OR
///       `/app/erp/sales/invoice-create?invoice_id={id}` (edit a draft).
///
/// History:
///
///   * G-FIN-SALES-INVOICE-JE-AUTOPOST (Sprint 5, 2026-05-09): created
///     as a single-line form with `CustomerPickerOrCreate` + Save Draft
///     + Issue (auto-posts JE).
///   * G-SALES-INVOICE-UX-COMPLETE (2026-05-10): added
///     `ProductPickerOrCreate` above the description field with
///     auto-fill on selection.
///   * G-SALES-INVOICE-UX-FOLLOWUP (2026-05-11): made `_onProductSelected`
///     fetch `ProductDetail` when `variants` are missing from the
///     list-payload (Bug B).
///   * **G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11)** — this rewrite:
///     - Multi-line invoice: a list of line drafts, "+ بند" button,
///       remove-line button per row, computed totals footer.
///     - Edit pre-fill: when the route has `?invoice_id=X`, the screen
///       fetches `GET /sales-invoices/{id}` on init and hydrates the
///       form. Draft invoices stay editable; issued/paid invoices show
///       a read-only banner directing the user back to the details
///       screen.
///
/// The backend `_post_sales_invoice_je` (customer_routes.py) handles
/// the JE auto-post on issue — DR Receivable / CR Revenue / CR VAT
/// Output, balanced to the cent. Multi-line invoices produce the same
/// 3-leg JE but with `subtotal = Σ(line.subtotal)` and
/// `vat = Σ(line.vat_amount)`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/forms/customer_picker_or_create.dart';
import '../../widgets/forms/product_picker_or_create.dart';

class SalesInvoiceCreateScreen extends StatefulWidget {
  /// G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): when provided,
  /// the screen enters edit mode — fetches the invoice on init and
  /// hydrates the form. Comes from the `?invoice_id=` query param via
  /// the router.
  final String? prefillInvoiceId;

  const SalesInvoiceCreateScreen({super.key, this.prefillInvoiceId});

  @override
  State<SalesInvoiceCreateScreen> createState() =>
      _SalesInvoiceCreateScreenState();
}

/// G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): per-line draft.
/// Each invoice line has its own controllers + selected product. The
/// `dispose()` helper is called when the line is removed or the screen
/// is disposed.
class _LineDraft {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController unitPrice;
  final TextEditingController vatRate;
  Map<String, dynamic>? product;

  _LineDraft({
    String description = '',
    String quantity = '1',
    String unit = '',
    String vat = '15',
    this.product,
  })  : desc = TextEditingController(text: description),
        qty = TextEditingController(text: quantity),
        unitPrice = TextEditingController(text: unit),
        vatRate = TextEditingController(text: vat);

  void dispose() {
    desc.dispose();
    qty.dispose();
    unitPrice.dispose();
    vatRate.dispose();
  }

  double get quantityValue =>
      double.tryParse(qty.text.trim()) ?? 0;
  double get unitPriceValue =>
      double.tryParse(unitPrice.text.trim()) ?? 0;
  double get vatRateValue =>
      double.tryParse(vatRate.text.trim()) ?? 0;
  double get subtotal => quantityValue * unitPriceValue;
  double get vatAmount => subtotal * vatRateValue / 100;
  double get lineTotal => subtotal + vatAmount;
}

class _SalesInvoiceCreateScreenState extends State<SalesInvoiceCreateScreen> {
  final List<_LineDraft> _lines = [_LineDraft()];
  Map<String, dynamic>? _selectedCustomer;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  bool _loading = false;
  bool _submitting = false;
  bool _isEditMode = false;
  bool _editLocked = false; // true when invoice is not draft (read-only)
  String? _existingInvoiceNumber;
  String? _existingInvoiceStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      _error = 'لا يوجد كيان نشط — أكمل التسجيل أولاً';
    }
    if ((widget.prefillInvoiceId ?? '').isNotEmpty) {
      _isEditMode = true;
      _prefillFromInvoice(widget.prefillInvoiceId!);
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String? get _selectedCustomerId =>
      (_selectedCustomer?['id'] ?? '').toString().isEmpty
          ? null
          : _selectedCustomer!['id'].toString();

  /// G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): hydrate the form
  /// from an existing invoice. Only draft invoices are editable; for
  /// any other status the form locks itself and shows a banner so the
  /// user can navigate back to the details screen for the available
  /// actions.
  Future<void> _prefillFromInvoice(String id) async {
    setState(() => _loading = true);
    final res = await ApiService.pilotGetSalesInvoice(id);
    if (!mounted) return;
    if (!res.success || res.data is! Map) {
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الفاتورة: ${res.error ?? '-'}';
      });
      return;
    }
    final inv = (res.data as Map).cast<String, dynamic>();
    _existingInvoiceNumber = inv['invoice_number']?.toString();
    _existingInvoiceStatus = inv['status']?.toString();
    final isDraft = _existingInvoiceStatus == 'draft';
    _editLocked = !isDraft;

    // Customer: minimal payload — picker will fetch the full record
    // when the user interacts. Display name only.
    _selectedCustomer = {
      'id': inv['customer_id'],
      'name_ar': inv['customer_name_ar'] ?? '',
    };

    // Dates
    final issue = DateTime.tryParse(inv['issue_date']?.toString() ?? '');
    final due = DateTime.tryParse(inv['due_date']?.toString() ?? '');
    if (issue != null) _issueDate = issue;
    if (due != null) _dueDate = due;

    // Lines — replace the default first line with the invoice's lines.
    final invLines = (inv['lines'] as List?) ?? const [];
    if (invLines.isNotEmpty) {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      for (final raw in invLines) {
        if (raw is! Map) continue;
        final ln = raw.cast<String, dynamic>();
        _lines.add(_LineDraft(
          description: ln['description']?.toString() ?? '',
          quantity: ln['quantity']?.toString() ?? '1',
          unit: ln['unit_price']?.toString() ?? '',
          vat: ln['vat_rate']?.toString() ?? '15',
          product: ln['product_id'] != null
              ? {'id': ln['product_id'], 'variants': []}
              : null,
        ));
      }
    }

    setState(() => _loading = false);
  }

  void _addLine() {
    setState(() => _lines.add(_LineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _onProductSelected(int lineIndex, Map<String, dynamic> p) async {
    final line = _lines[lineIndex];
    setState(() {
      line.product = p;
      final desc = (p['name_ar'] ?? p['name_en'] ?? p['code'] ?? '').toString();
      if (desc.isNotEmpty) line.desc.text = desc;
      final vatCode = (p['vat_code'] ?? '').toString();
      line.vatRate.text =
          (vatCode == 'zero_rated' || vatCode == 'exempt') ? '0' : '15';
    });

    // Bug B fallback (from G-SALES-INVOICE-UX-FOLLOWUP): list endpoint
    // doesn't include variants — fetch ProductDetail for list_price.
    final inlineVariants = (p['variants'] as List?) ?? const [];
    if (inlineVariants.isNotEmpty) {
      final v0 = inlineVariants.first;
      if (v0 is Map && v0['list_price'] != null) {
        line.unitPrice.text = '${v0['list_price']}';
        setState(() {});
        return;
      }
    }
    final pid = p['id']?.toString();
    if (pid == null || pid.isEmpty) return;
    final detailRes = await ApiService.pilotGetProduct(pid);
    if (!mounted || !detailRes.success || detailRes.data is! Map) return;
    final detail = (detailRes.data as Map).cast<String, dynamic>();
    line.product = detail;
    final variants = (detail['variants'] as List?) ?? const [];
    if (variants.isEmpty) {
      setState(() {});
      return;
    }
    final v0 = variants.first;
    if (v0 is Map && v0['list_price'] != null) {
      line.unitPrice.text = '${v0['list_price']}';
    }
    setState(() {});
  }

  // ── Stock warning ────────────────────────────────────────────
  /// G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): returns a warning
  /// label when the qty entered on a stockable product line exceeds
  /// `total_stock_on_hand`. Returns null for services or when stock is
  /// sufficient. Non-blocking — the user can still submit (the
  /// backend handles negative-stock policy per warehouse).
  String? _stockWarning(_LineDraft line) {
    final p = line.product;
    if (p == null) return null;
    if (p['is_stockable'] == false) return null;
    final stock = double.tryParse('${p['total_stock_on_hand'] ?? 0}') ?? 0;
    final qty = line.quantityValue;
    if (qty <= stock) return null;
    return 'الكمية (${qty.toStringAsFixed(0)}) تتجاوز المخزون المتوفر (${stock.toStringAsFixed(0)})';
  }

  // ── Totals ───────────────────────────────────────────────────
  double get _subtotal =>
      _lines.fold<double>(0, (s, l) => s + l.subtotal);
  double get _vatTotal =>
      _lines.fold<double>(0, (s, l) => s + l.vatAmount);
  double get _grandTotal => _subtotal + _vatTotal;

  // ── Payload ──────────────────────────────────────────────────
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
    if (_lines.isEmpty) {
      setState(() => _error = 'أضف بنداً واحداً على الأقل');
      return null;
    }
    // Validate every line
    final linesPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final desc = l.desc.text.trim();
      if (desc.isEmpty) {
        setState(() => _error = 'الوصف مطلوب في البند ${i + 1}');
        return null;
      }
      if (l.quantityValue <= 0) {
        setState(() => _error = 'الكمية في البند ${i + 1} يجب أن تكون أكبر من صفر');
        return null;
      }
      if (l.unitPriceValue <= 0) {
        setState(() => _error = 'السعر في البند ${i + 1} غير صحيح');
        return null;
      }
      final productId = l.product?['id']?.toString();
      final variants = (l.product?['variants'] as List?) ?? const [];
      String? variantId;
      if (variants.isNotEmpty) {
        final v0 = variants.first;
        if (v0 is Map) variantId = v0['id']?.toString();
      }
      linesPayload.add({
        if (productId != null) 'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        'description': desc,
        'quantity': l.quantityValue,
        'unit_price': l.unitPriceValue,
        'vat_rate': l.vatRateValue,
      });
    }
    return {
      'tenant_id': tenantId,
      'entity_id': entityId,
      'customer_id': _selectedCustomerId,
      'issue_date': _fmtDate(_issueDate),
      'due_date': _fmtDate(_dueDate),
      'currency': 'SAR',
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
    // G-SALES-INVOICE-UPDATE (2026-05-11): branch on edit-mode — PATCH
    // when prefilled, POST otherwise. Pre-fix this always POSTed and
    // produced a duplicate draft from the Edit flow.
    final editId = widget.prefillInvoiceId;
    final ApiResult res;
    if (editId != null && editId.isNotEmpty) {
      res = await ApiService.pilotUpdateSalesInvoice(editId, payload);
    } else {
      res = await ApiService.pilotCreateSalesInvoice(payload);
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.success) {
      setState(() => _error = (editId != null && editId.isNotEmpty)
          ? 'فشل تحديث المسودة: ${res.error ?? '-'}'
          : 'فشل حفظ المسودة: ${res.error ?? '-'}');
      return;
    }
    final invNum = (res.data as Map?)?['invoice_number'] ?? '';
    final invId = (res.data as Map?)?['id']?.toString();
    if (editId != null && editId.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text('تم تحديث الفاتورة #$invNum'),
      ));
      // Navigate to details, not list — keeps the user in context.
      context.go('/app/erp/finance/sales-invoices/${invId ?? editId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.info,
        content: Text('تم حفظ المسودة #$invNum — لم يُرحَّل القيد بعد'),
      ));
      context.go('/app/erp/finance/sales-invoices');
    }
  }

  Future<void> _submit() async {
    final payload = _buildPayload();
    if (payload == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    // G-SALES-INVOICE-UPDATE (2026-05-11): in edit-mode (prefilled
    // from a draft), PATCH the existing invoice instead of creating a
    // duplicate. Pre-fix this always POSTed — the visible symptom was
    // a second INV-XXX appearing in the list every time the user
    // clicked Save on the Edit screen.
    final editId = widget.prefillInvoiceId;
    if (editId != null && editId.isNotEmpty) {
      final upd = await ApiService.pilotUpdateSalesInvoice(editId, payload);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!upd.success) {
        // No fallback to create — falling back would re-introduce the
        // duplicate-draft bug we are fixing here.
        setState(() => _error = 'فشل تحديث الفاتورة: ${upd.error ?? '-'}');
        return;
      }
      final updData = (upd.data as Map?) ?? const {};
      final invNum = updData['invoice_number']?.toString() ?? '';
      final invId = updData['id']?.toString() ?? editId;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text('تم تحديث الفاتورة #$invNum'),
      ));
      context.go('/app/erp/finance/sales-invoices/$invId');
      return;
    }

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
              onPressed: () => context.go('/app/erp/finance/je-builder'),
            ),
    ));
    context.go('/app/erp/finance/sales-invoices');
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

  // ── UI ──────────────────────────────────────────────────────
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
        title: Text(
            _isEditMode
                ? 'تعديل فاتورة ${_existingInvoiceNumber ?? ''}'
                : 'فاتورة مبيعات جديدة',
            style: TextStyle(
                color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AC.gold))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) _errorBanner(_error!),
                      if (_editLocked) _readOnlyBanner(),
                      _section('العميل', Icons.person_outline,
                          child: _customerPicker()),
                      const SizedBox(height: 16),
                      _section('البنود (${_lines.length})', Icons.list_alt,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0; i < _lines.length; i++)
                                _lineCard(i),
                              if (!_editLocked) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _addLine,
                                  icon: Icon(Icons.add, color: AC.gold),
                                  label: Text('+ إضافة بند',
                                      style: TextStyle(
                                          color: AC.gold,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          )),
                      const SizedBox(height: 16),
                      _section('التواريخ', Icons.calendar_month, child: Row(
                        children: [
                          Expanded(
                              child: _datePicker('تاريخ الإصدار', _issueDate,
                                  () => _pickDate(true))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _datePicker('تاريخ الاستحقاق', _dueDate,
                                  () => _pickDate(false))),
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
              child: Text(msg,
                  style: TextStyle(color: AC.err, fontSize: 12.5))),
        ]),
      );

  Widget _readOnlyBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.08),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.lock_outline, color: AC.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذه الفاتورة في حالة "${_existingInvoiceStatus ?? '?'}" — لا يمكن تعديلها. '
              'استخدم شاشة التفاصيل لإجراءات الدفع/الإلغاء.',
              style: TextStyle(color: AC.tp, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => context.go(
                '/app/erp/finance/sales-invoices/${widget.prefillInvoiceId}'),
            child: Text('فتح التفاصيل',
                style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
          ),
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

  Widget _customerPicker() {
    return AbsorbPointer(
      absorbing: _editLocked,
      child: Opacity(
        opacity: _editLocked ? 0.6 : 1,
        child: CustomerPickerOrCreate(
          initial: _selectedCustomer,
          onSelected: (c) => setState(() => _selectedCustomer = c),
        ),
      ),
    );
  }

  Widget _lineCard(int index) {
    final line = _lines[index];
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
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AbsorbPointer(
                absorbing: _editLocked,
                child: Opacity(
                  opacity: _editLocked ? 0.6 : 1,
                  child: ProductPickerOrCreate(
                    initial: line.product,
                    labelText: 'المنتج (اختياري — أو اكتب وصفاً يدوياً)',
                    onSelected: (p) => _onProductSelected(index, p),
                  ),
                ),
              ),
            ),
            if (!_editLocked && _lines.length > 1)
              IconButton(
                tooltip: 'حذف البند',
                icon: Icon(Icons.delete_outline, color: AC.err, size: 20),
                onPressed: () => _removeLine(index),
              ),
          ]),
          const SizedBox(height: 10),
          _input(line.desc, 'الوصف', Icons.description),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _input(line.qty, 'الكمية', Icons.straighten,
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _input(line.unitPrice, 'السعر (قبل VAT)',
                    Icons.attach_money,
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _input(line.vatRate, 'VAT %', Icons.percent,
                  keyboard:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {})),
            ),
          ]),
          const SizedBox(height: 8),
          // G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): stock
          // warning when qty exceeds available stock for the picked
          // product. Hidden for services (is_stockable=false).
          if (_stockWarning(line) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: AC.warn, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_stockWarning(line)!,
                      style: TextStyle(
                          color: AC.warn,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          Row(children: [
            Text('الإجمالي:',
                style: TextStyle(color: AC.td, fontSize: 11)),
            const Spacer(),
            Text(line.lineTotal.toStringAsFixed(2),
                style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 4),
            Text('SAR', style: TextStyle(color: AC.td, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _totalsFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        _totalRow('المجموع الفرعي', _subtotal),
        _totalRow('إجمالي VAT', _vatTotal),
        Divider(color: AC.bdr, height: 16),
        _totalRow('الإجمالي النهائي', _grandTotal, emphasize: true),
      ]),
    );
  }

  Widget _totalRow(String label, double value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: emphasize ? AC.gold : AC.td,
                fontSize: emphasize ? 13 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400)),
        const Spacer(),
        Text(value.toStringAsFixed(2),
            style: TextStyle(
                color: emphasize ? AC.gold : AC.tp,
                fontSize: emphasize ? 14 : 12,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 4),
        Text('SAR', style: TextStyle(color: AC.td, fontSize: 11)),
      ]),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      enabled: !_editLocked,
      onChanged: onChanged,
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
        onTap: _editLocked ? null : onTap,
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
