/// APEX — Dedicated "Create Sales Invoice" form
/// /sales/invoices/new — focused single-purpose screen.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

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

  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _vatRateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final tenantId = S.savedTenantId;
    if (tenantId == null) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد كيان نشط — أكمل التسجيل أولاً';
      });
      return;
    }
    final res = await ApiService.pilotListCustomers(tenantId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _customers = (res.data as List).cast<Map<String, dynamic>>();
        if (_customers.isNotEmpty) {
          _selectedCustomerId = _customers.first['id'] as String?;
        }
      } else {
        _error = res.error ?? 'تعذّر تحميل العملاء';
      }
    });
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

  Future<void> _submit() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return;
    }
    if (_selectedCustomerId == null) {
      setState(() => _error = 'اختر عميلاً أولاً');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'المبلغ غير صحيح');
      return;
    }
    final vatRate = double.tryParse(_vatRateCtrl.text.trim()) ?? 15;
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'الوصف مطلوب');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final create = await ApiService.pilotCreateSalesInvoice({
      'tenant_id': tenantId,
      'entity_id': entityId,
      'customer_id': _selectedCustomerId,
      'issue_date': _fmtDate(_issueDate),
      'due_date': _fmtDate(_dueDate),
      'currency': 'SAR',
      'lines': [
        {
          'description': desc,
          'quantity': 1,
          'unit_price': amount,
          'vat_rate': vatRate,
        }
      ],
    });
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
    final jeId = (issue.data as Map?)?['journal_entry_id'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      content: Text('تم إصدار الفاتورة وترحيل القيد ${jeId ?? ''}'),
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
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send),
                          label: Text(_submitting
                              ? 'جارٍ الإصدار…'
                              : 'إنشاء وإصدار — يرحَّل القيد تلقائياً'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AC.gold,
                              foregroundColor: AC.navy,
                              textStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ),
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

  Widget _customerPicker() {
    if (_customers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(Icons.warning_amber, color: AC.warn, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text('لا يوجد عملاء — أضف عميلاً أولاً',
                  style: TextStyle(color: AC.warn, fontSize: 12.5))),
          TextButton(
            onPressed: () => context.go('/sales/customers'),
            child: Text('إدارة العملاء',
                style: TextStyle(color: AC.gold, fontSize: 11.5)),
          ),
        ]),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedCustomerId,
      isExpanded: true,
      dropdownColor: AC.navy3,
      style: TextStyle(color: AC.tp, fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.person, color: AC.gold, size: 18),
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
      items: _customers
          .map((c) => DropdownMenuItem<String>(
                value: c['id'] as String?,
                child: Text(
                    '${c['code'] ?? ''} — ${c['name_ar'] ?? c['name'] ?? '—'}',
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedCustomerId = v),
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
