/// APEX — Live Sales Cycle Screen
/// ═══════════════════════════════════════════════════════════════════════
/// Demonstrates the full sales cycle against the user's active entity:
///   1. List customers (under active tenant)
///   2. Create a new customer (optional)
///   3. Create a draft sales invoice
///   4. Issue the invoice → auto-posts JE → creates GLPostings
///   5. Verify by jumping to the Trial Balance.
///
/// Wired to:
///   - GET    /api/v1/pilot/tenants/{tenant_id}/customers
///   - POST   /api/v1/pilot/tenants/{tenant_id}/customers
///   - POST   /api/v1/pilot/sales-invoices
///   - POST   /api/v1/pilot/sales-invoices/{id}/issue
///   - GET    /api/v1/pilot/entities/{entity_id}/sales-invoices
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class LiveSalesCycleScreen extends StatefulWidget {
  const LiveSalesCycleScreen({super.key});
  @override
  State<LiveSalesCycleScreen> createState() => _LiveSalesCycleScreenState();
}

class _LiveSalesCycleScreenState extends State<LiveSalesCycleScreen> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _invoices = [];
  bool _loadingCustomers = false;
  bool _loadingInvoices = false;
  String? _error;
  String? _selectedCustomerId;
  String? _lastIssuedInvoiceId;
  String? _lastJeId;

  // New invoice form
  final _amountCtrl = TextEditingController(text: '10000');
  final _vatRateCtrl = TextEditingController(text: '15');
  final _descCtrl = TextEditingController(text: 'خدمة استشارية شهرية');

  // New customer form
  final _newCustNameCtrl = TextEditingController();
  final _newCustVatCtrl = TextEditingController();
  bool _showAddCustomer = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _vatRateCtrl.dispose();
    _descCtrl.dispose();
    _newCustNameCtrl.dispose();
    _newCustVatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      setState(() => _error = 'لا يوجد كيان نشط — أكمل التسجيل أولاً');
      return;
    }
    setState(() {
      _loadingCustomers = true;
      _loadingInvoices = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.pilotListCustomers(tenantId),
      ApiService.pilotListSalesInvoices(entityId),
    ]);
    if (!mounted) return;
    setState(() {
      _loadingCustomers = false;
      _loadingInvoices = false;
      if (results[0].success && results[0].data is List) {
        _customers = (results[0].data as List).cast<Map<String, dynamic>>();
        if (_selectedCustomerId == null && _customers.isNotEmpty) {
          _selectedCustomerId = _customers.first['id'] as String?;
        }
      }
      if (results[1].success && results[1].data is List) {
        _invoices = (results[1].data as List).cast<Map<String, dynamic>>();
      }
    });
  }

  Future<void> _addCustomer() async {
    final tenantId = S.savedTenantId;
    if (tenantId == null) return;
    final name = _newCustNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اسم العميل مطلوب');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await ApiService.pilotCreateCustomer(tenantId, {
      'name_ar': name,
      'kind': 'company',
      if (_newCustVatCtrl.text.trim().isNotEmpty) 'vat_number': _newCustVatCtrl.text.trim(),
      'currency': 'SAR',
      'payment_terms': 'net_30',
    });
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!res.success) {
        _error = res.error ?? 'فشل إضافة العميل';
        return;
      }
      _newCustNameCtrl.clear();
      _newCustVatCtrl.clear();
      _showAddCustomer = false;
    });
    await _loadAll();
  }

  Future<void> _createAndIssueInvoice() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null || _selectedCustomerId == null) {
      setState(() => _error = 'اختر عميلاً أولاً');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    final vatRate = double.tryParse(_vatRateCtrl.text.trim()) ?? 15;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'المبلغ غير صحيح');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _lastIssuedInvoiceId = null;
      _lastJeId = null;
    });
    final today = DateTime.now();
    final dueDate = today.add(const Duration(days: 30));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // Step 1: create draft.
    final create = await ApiService.pilotCreateSalesInvoice({
      'tenant_id': tenantId,
      'entity_id': entityId,
      'customer_id': _selectedCustomerId,
      'issue_date': fmt(today),
      'due_date': fmt(dueDate),
      'currency': 'SAR',
      'lines': [
        {
          'description': _descCtrl.text.trim(),
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
    // Step 2: issue → auto-post JE → create GLPostings.
    final issue = await ApiService.pilotIssueSalesInvoice(invId);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!issue.success) {
        _error = 'فشل إصدار الفاتورة: ${issue.error ?? '-'}';
        return;
      }
      _lastIssuedInvoiceId = invId;
      _lastJeId = (issue.data as Map?)?['journal_entry_id'] as String?;
    });
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text('تم إصدار الفاتورة وترحيل القيد ${_lastJeId ?? ''}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('دورة المبيعات الحية', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loadingCustomers || _loadingInvoices ? null : _loadAll,
          ),
          IconButton(
            icon: Icon(Icons.assessment, color: AC.gold),
            tooltip: 'الذهاب لميزان المراجعة',
            onPressed: () => context.go('/compliance/financial-statements'),
          ),
        ],
      ),
      body: tenantId == null || entityId == null
          ? _emptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _scopeBanner(tenantId, entityId),
                if (_error != null) _errorBox(_error!),
                const SizedBox(height: 12),
                _customersCard(),
                const SizedBox(height: 12),
                _newInvoiceCard(),
                const SizedBox(height: 12),
                _invoicesListCard(),
                if (_lastIssuedInvoiceId != null) ...[
                  const SizedBox(height: 12),
                  _successCard(),
                ],
              ]),
            ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.business_center_outlined, color: AC.ts, size: 64),
            const SizedBox(height: 12),
            Text('لا يوجد كيان نشط', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('أكمل التسجيل أولاً لإنشاء كيانك المحاسبي',
                textAlign: TextAlign.center, style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch),
              label: const Text('بدء التسجيل'),
              onPressed: () => context.go('/onboarding'),
              style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ]),
        ),
      );

  Widget _scopeBanner(String tenantId, String entityId) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.08),
          border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.business, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الكيان النشط',
                  style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700)),
              Text('${entityId.substring(0, 8)}…',
                  style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace')),
            ]),
          ),
        ]),
      );

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.err.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AC.err.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: AC.err, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(color: AC.err, fontSize: 12))),
        ]),
      );

  Widget _customersCard() => _card(
        title: 'العملاء (${_customers.length})',
        icon: Icons.people,
        action: TextButton.icon(
          onPressed: () => setState(() => _showAddCustomer = !_showAddCustomer),
          icon: Icon(_showAddCustomer ? Icons.close : Icons.add, color: AC.gold, size: 16),
          label: Text(_showAddCustomer ? 'إلغاء' : 'إضافة',
              style: TextStyle(color: AC.gold, fontSize: 12)),
        ),
        child: Column(children: [
          if (_showAddCustomer) ...[
            _input(_newCustNameCtrl, 'اسم العميل بالعربية', Icons.person),
            const SizedBox(height: 8),
            _input(_newCustVatCtrl, 'رقم VAT (اختياري)', Icons.numbers),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _addCustomer,
              icon: _submitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: const Text('حفظ العميل'),
            ),
            const Divider(),
          ],
          if (_loadingCustomers) const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ) else if (_customers.isEmpty) Padding(
            padding: const EdgeInsets.all(12),
            child: Text('لا يوجد عملاء — أضف أول عميل',
                style: TextStyle(color: AC.ts, fontSize: 12)),
          ) else ..._customers.map((c) {
            final isSelected = c['id'] == _selectedCustomerId;
            return InkWell(
              onTap: () => setState(() => _selectedCustomerId = c['id'] as String?),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AC.gold.withValues(alpha: 0.10) : Colors.transparent,
                  border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
                ),
                child: Row(children: [
                  Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 14, color: isSelected ? AC.gold : AC.ts),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${c['code'] ?? ''} — ${c['name_ar'] ?? '-'}',
                      style: TextStyle(color: AC.tp, fontSize: 12.5))),
                  if (c['vat_number'] != null)
                    Text('${c['vat_number']}',
                        style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace')),
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: AC.gold, size: 14),
                    tooltip: 'ملف العميل (Customer 360)',
                    onPressed: () => context.go('/operations/customer-360/${c['id']}'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ]),
              ),
            );
          }),
        ]),
      );

  Widget _newInvoiceCard() => _card(
        title: 'فاتورة جديدة',
        icon: Icons.receipt_long,
        child: Column(children: [
          if (_selectedCustomerId == null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('اختر عميلاً من القائمة أعلاه',
                  style: TextStyle(color: AC.warn, fontSize: 12)),
            ),
          _input(_descCtrl, 'وصف الخدمة/المنتج', Icons.description),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _input(_amountCtrl, 'المبلغ (قبل VAT)', Icons.attach_money)),
            const SizedBox(width: 8),
            SizedBox(width: 100, child: _input(_vatRateCtrl, 'VAT %', Icons.percent)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitting || _selectedCustomerId == null ? null : _createAndIssueInvoice,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'جارٍ الإصدار…' : 'أنشئ وأصدر — يقيد تلقائياً'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy,
              ),
            ),
          ),
        ]),
      );

  Widget _invoicesListCard() => _card(
        title: 'الفواتير (${_invoices.length})',
        icon: Icons.list_alt,
        child: _loadingInvoices
            ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('لا توجد فواتير بعد',
                        style: TextStyle(color: AC.ts, fontSize: 12)))
                : Column(
                    children: _invoices.take(10).map((inv) {
                      final isIssued = inv['status'] == 'issued';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
                        ),
                        child: Row(children: [
                          Icon(isIssued ? Icons.check_circle : Icons.edit_note,
                              size: 14, color: isIssued ? AC.ok : AC.warn),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${inv['invoice_number']}',
                                  style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('${inv['issue_date']} — ${inv['status']}',
                                  style: TextStyle(color: AC.ts, fontSize: 10)),
                            ]),
                          ),
                          Text('${inv['total']} SAR',
                              style: TextStyle(
                                  color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }).toList(),
                  ),
      );

  Widget _successCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.ok.withValues(alpha: 0.10),
          border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.celebration, color: AC.ok),
            const SizedBox(width: 8),
            Text('تم بنجاح',
                style: TextStyle(color: AC.ok, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text('تم إنشاء الفاتورة وإصدارها وترحيل القيد إلى الأستاذ العام.',
              style: TextStyle(color: AC.tp, fontSize: 12)),
          if (_lastJeId != null) Text('JE: ${_lastJeId!.substring(0, 8)}…',
              style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/compliance/financial-statements'),
                icon: Icon(Icons.assessment, color: AC.gold, size: 16),
                label: Text('ميزان المراجعة',
                    style: TextStyle(color: AC.gold, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
              ),
            ),
            const SizedBox(width: 8),
            if (_lastJeId != null)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/compliance/journal-entry/$_lastJeId'),
                  icon: const Icon(Icons.receipt, size: 16),
                  label: const Text('عرض القيد', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
                ),
              ),
          ]),
        ]),
      );

  // ── helpers ──
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(icon, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              if (action != null) action,
            ]),
          ),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ]),
      );

  Widget _input(TextEditingController c, String label, IconData icon) => TextField(
        controller: c,
        style: TextStyle(color: AC.tp, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AC.ts, fontSize: 11.5),
          prefixIcon: Icon(icon, color: AC.ts, size: 16),
          isDense: true,
          filled: true,
          fillColor: AC.navy3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
