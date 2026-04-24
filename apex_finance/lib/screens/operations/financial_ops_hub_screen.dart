/// APEX — Financial Operations Hub
/// ═══════════════════════════════════════════════════════════
/// Single-screen command center for the full accounting cycle:
/// عملاء · موردين · أصناف · موظفين · قيود · فواتير بيع · ميزان المراجعة.
/// Each tab uses the existing pilot-module endpoints.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class FinancialOpsHubScreen extends StatefulWidget {
  const FinancialOpsHubScreen({super.key});
  @override
  State<FinancialOpsHubScreen> createState() => _FinancialOpsHubScreenState();
}

class _FinancialOpsHubScreenState extends State<FinancialOpsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _tenantCtl = TextEditingController();
  final _entityCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _tenantCtl.dispose();
    _entityCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('مركز العمليات المالية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.ts,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'عملاء', icon: Icon(Icons.people_outline, size: 16)),
              Tab(text: 'موردين', icon: Icon(Icons.local_shipping_outlined, size: 16)),
              Tab(text: 'أصناف', icon: Icon(Icons.inventory_2_outlined, size: 16)),
              Tab(text: 'موظفين', icon: Icon(Icons.badge_outlined, size: 16)),
              Tab(text: 'قيود يومية', icon: Icon(Icons.receipt_long_outlined, size: 16)),
              Tab(text: 'فاتورة بيع', icon: Icon(Icons.request_quote_outlined, size: 16)),
              Tab(text: 'ميزان المراجعة', icon: Icon(Icons.balance, size: 16)),
            ],
          ),
        ),
        body: Column(
          children: [
            _contextBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _CustomersTab(tenantGetter: () => _tenantCtl.text.trim()),
                  _VendorsTab(tenantGetter: () => _tenantCtl.text.trim()),
                  _ProductsTab(tenantGetter: () => _tenantCtl.text.trim()),
                  const _EmployeesTab(),
                  _JournalsTab(entityGetter: () => _entityCtl.text.trim()),
                  _SalesInvoiceTab(
                    tenantGetter: () => _tenantCtl.text.trim(),
                    entityGetter: () => _entityCtl.text.trim(),
                  ),
                  _TrialBalanceTab(entityGetter: () => _entityCtl.text.trim()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _tenantCtl,
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Tenant ID',
                labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _entityCtl,
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Entity ID',
                labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'تحديث',
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// Customers Tab
// ═══════════════════════════════════════════════════════════

class _CustomersTab extends StatefulWidget {
  final String Function() tenantGetter;
  const _CustomersTab({required this.tenantGetter});
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  Future<void> _load() async {
    final t = widget.tenantGetter();
    if (t.isEmpty) {
      setState(() => _error = 'أدخل Tenant ID في الشريط العلوي');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.pilotListCustomers(t);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data != null) {
        _rows = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error;
      }
    });
  }

  Future<void> _createDialog() async {
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final vatCtl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('عميل جديد', style: TextStyle(fontFamily: 'Tajawal')),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtl, decoration: const InputDecoration(labelText: 'الترميز (مثل CUST-0001)', labelStyle: TextStyle(fontFamily: 'Tajawal'))),
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'الاسم بالعربية', labelStyle: TextStyle(fontFamily: 'Tajawal'))),
                TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'الجوال', labelStyle: TextStyle(fontFamily: 'Tajawal'))),
                TextField(controller: vatCtl, decoration: const InputDecoration(labelText: 'الرقم الضريبي (اختياري)', labelStyle: TextStyle(fontFamily: 'Tajawal'))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal'))),
          ],
        ),
      ),
    );
    if (res == true && codeCtl.text.trim().isNotEmpty && nameCtl.text.trim().isNotEmpty) {
      final r = await ApiService.pilotCreateCustomer(widget.tenantGetter(), {
        'code': codeCtl.text.trim(),
        'name_ar': nameCtl.text.trim(),
        'phone': phoneCtl.text.trim(),
        if (vatCtl.text.trim().isNotEmpty) 'vat_number': vatCtl.text.trim(),
      });
      if (!mounted) return;
      if (r.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'فشل')));
      }
    }
    codeCtl.dispose(); nameCtl.dispose(); phoneCtl.dispose(); vatCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('تحميل', style: TextStyle(fontFamily: 'Tajawal')),
                style: FilledButton.styleFrom(backgroundColor: AC.navy3, foregroundColor: AC.tp),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: widget.tenantGetter().isEmpty ? null : _createDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('عميل جديد', style: TextStyle(fontFamily: 'Tajawal')),
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              ),
              const Spacer(),
              Text('${_rows.length} عميل', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')));
    if (_rows.isEmpty) return Center(child: Text('لا عملاء — أضف الأول', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')));
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = _rows[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: AC.gold.withValues(alpha: 0.2), child: Text('${r['code']?[0] ?? 'C'}', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal'))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['name_ar']}', style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text('${r['code']} · ${r['currency']} · ${r['payment_terms']}', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
                  ],
                ),
              ),
              if ((r['vat_number'] ?? '').toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AC.ok.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('VAT', style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 10)),
                ),
            ],
          ),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════
// Vendors / Products / Employees / JEs / SI / TB — simpler list tabs
// ═══════════════════════════════════════════════════════════

class _VendorsTab extends StatefulWidget {
  final String Function() tenantGetter;
  const _VendorsTab({required this.tenantGetter});
  @override State<_VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<_VendorsTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false; String? _error;
  Future<void> _load() async {
    final t = widget.tenantGetter();
    if (t.isEmpty) return setState(() => _error = 'أدخل Tenant ID');
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.pilotListVendors(t);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) _rows = (r.data as List).cast<Map<String, dynamic>>();
      else _error = r.error;
    });
  }
  @override
  Widget build(BuildContext context) {
    return _SimpleListTab(
      title: 'موردين', count: _rows.length, loading: _loading, error: _error,
      onLoad: _load,
      rows: _rows,
      rowBuilder: (r) => _simpleRow(r['name_ar'] ?? r['name'] ?? '', '${r['code'] ?? ''} · ${r['currency'] ?? ''}'),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  final String Function() tenantGetter;
  const _ProductsTab({required this.tenantGetter});
  @override State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false; String? _error;
  Future<void> _load() async {
    final t = widget.tenantGetter();
    if (t.isEmpty) return setState(() => _error = 'أدخل Tenant ID');
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.pilotListProducts(t);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) _rows = (r.data as List).cast<Map<String, dynamic>>();
      else _error = r.error;
    });
  }
  @override
  Widget build(BuildContext context) {
    return _SimpleListTab(
      title: 'أصناف', count: _rows.length, loading: _loading, error: _error,
      onLoad: _load,
      rows: _rows,
      rowBuilder: (r) => _simpleRow(r['name_ar'] ?? '', 'SKU ${r['sku'] ?? r['id'] ?? ''}'),
    );
  }
}

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();
  @override State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false; String? _error;
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.hrListEmployees();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) {
        final raw = r.data['data'] ?? r.data;
        _rows = (raw is List ? raw : <dynamic>[]).cast<Map<String, dynamic>>();
      } else _error = r.error;
    });
  }
  @override
  Widget build(BuildContext context) {
    return _SimpleListTab(
      title: 'موظفين', count: _rows.length, loading: _loading, error: _error,
      onLoad: _load,
      rows: _rows,
      rowBuilder: (r) => _simpleRow(r['name_ar'] ?? r['name'] ?? '', '${r['position'] ?? ''} · ${r['iqama_number'] ?? ''}'),
    );
  }
}

class _JournalsTab extends StatefulWidget {
  final String Function() entityGetter;
  const _JournalsTab({required this.entityGetter});
  @override State<_JournalsTab> createState() => _JournalsTabState();
}

class _JournalsTabState extends State<_JournalsTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false; String? _error;
  Future<void> _load() async {
    final e = widget.entityGetter();
    if (e.isEmpty) return setState(() => _error = 'أدخل Entity ID');
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.pilotListJournalEntries(e);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) _rows = (r.data as List).cast<Map<String, dynamic>>();
      else _error = r.error;
    });
  }
  @override
  Widget build(BuildContext context) {
    return _SimpleListTab(
      title: 'قيود يومية', count: _rows.length, loading: _loading, error: _error,
      onLoad: _load,
      rows: _rows,
      rowBuilder: (r) {
        final status = (r['status'] ?? '') as String;
        final statusColor = status == 'posted' ? AC.ok : (status == 'draft' ? AC.ts : AC.gold);
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['je_number']} — ${r['memo_ar'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${r['je_date']}'.split('T').first + ' · ${r['total_debit']} ${r['currency']}',
                      style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(status, style: TextStyle(color: statusColor, fontFamily: 'Tajawal', fontSize: 10.5)),
            ),
          ],
        );
      },
    );
  }
}

class _SalesInvoiceTab extends StatefulWidget {
  final String Function() tenantGetter;
  final String Function() entityGetter;
  const _SalesInvoiceTab({required this.tenantGetter, required this.entityGetter});
  @override State<_SalesInvoiceTab> createState() => _SalesInvoiceTabState();
}

class _SalesInvoiceTabState extends State<_SalesInvoiceTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false; String? _error;
  Future<void> _load() async {
    final e = widget.entityGetter();
    if (e.isEmpty) return setState(() => _error = 'أدخل Entity ID');
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.pilotListSalesInvoices(e);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) _rows = (r.data as List).cast<Map<String, dynamic>>();
      else _error = r.error;
    });
  }

  Future<void> _issueInvoice(String id) async {
    final r = await ApiService.pilotIssueSalesInvoice(id);
    if (!mounted) return;
    final msg = r.success ? 'تم إصدار الفاتورة + ترحيل القيد' : (r.error ?? 'فشل');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return _SimpleListTab(
      title: 'فواتير بيع', count: _rows.length, loading: _loading, error: _error,
      onLoad: _load,
      rows: _rows,
      rowBuilder: (r) {
        final status = (r['status'] ?? 'draft') as String;
        final color = {
          'draft': AC.ts, 'issued': AC.ok, 'partially_paid': AC.gold, 'paid': AC.ok, 'cancelled': AC.err,
        }[status] ?? AC.ts;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['invoice_number']}',
                      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text('${r['issue_date']} · ${r['total']} ${r['currency']} (مدفوع ${r['paid_amount']})',
                      style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(status, style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5)),
            ),
            if (status == 'draft')
              IconButton(
                tooltip: 'إصدار + ترحيل القيد',
                icon: Icon(Icons.publish, color: AC.gold, size: 18),
                onPressed: () => _issueInvoice(r['id'] as String),
              ),
          ],
        );
      },
    );
  }
}

class _TrialBalanceTab extends StatefulWidget {
  final String Function() entityGetter;
  const _TrialBalanceTab({required this.entityGetter});
  @override State<_TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends State<_TrialBalanceTab> {
  Map<String, dynamic>? _snapshot;
  bool _loading = false; String? _error;

  Future<void> _load() async {
    final e = widget.entityGetter();
    if (e.isEmpty) return setState(() => _error = 'أدخل Entity ID');
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.pilotTrialBalance(e);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data != null) _snapshot = (r.data as Map).cast<String, dynamic>();
      else _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('تحديث', style: TextStyle(fontFamily: 'Tajawal')),
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              ),
              const Spacer(),
              if (_snapshot != null) Text(
                'مدين ${_snapshot!['total_debits']} / دائن ${_snapshot!['total_credits']}',
                style: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
              : _error != null ? Center(child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')))
              : _snapshot == null ? Center(child: Text('اضغط تحديث لعرض الميزان', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')))
              : _renderTB(),
        ),
      ],
    );
  }

  Widget _renderTB() {
    final rows = (_snapshot!['lines'] as List?) ?? [];
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: rows.length,
      separatorBuilder: (_, __) => Divider(color: AC.gold.withValues(alpha: 0.1), height: 1),
      itemBuilder: (_, i) {
        final r = rows[i] as Map;
        return Row(
          children: [
            SizedBox(width: 56, child: Text('${r['account_code']}',
                style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5))),
            Expanded(child: Text('${r['account_name']}',
                style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12))),
            SizedBox(width: 100, child: Text('${r['debit']}',
                textAlign: TextAlign.end,
                style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 11.5))),
            const SizedBox(width: 10),
            SizedBox(width: 100, child: Text('${r['credit']}',
                textAlign: TextAlign.end,
                style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 11.5))),
          ],
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════
// Shared list-tab scaffold
// ═══════════════════════════════════════════════════════════

class _SimpleListTab extends StatelessWidget {
  final String title;
  final int count;
  final bool loading;
  final String? error;
  final VoidCallback onLoad;
  final List<Map<String, dynamic>> rows;
  final Widget Function(Map<String, dynamic>) rowBuilder;
  const _SimpleListTab({
    required this.title, required this.count, required this.loading,
    required this.error, required this.onLoad, required this.rows,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('تحميل', style: TextStyle(fontFamily: 'Tajawal')),
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              ),
              const Spacer(),
              Text('$count', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')))
                  : rows.isEmpty
                      ? Center(child: Text('لا بيانات — اضغط تحميل', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')))
                      : ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) => Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AC.navy2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AC.gold.withValues(alpha: 0.15)),
                            ),
                            child: rowBuilder(rows[i]),
                          ),
                        ),
        ),
      ],
    );
  }
}


Widget _simpleRow(String primary, String secondary) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(primary, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text(secondary, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
          ],
        ),
      ),
    ],
  );
}
