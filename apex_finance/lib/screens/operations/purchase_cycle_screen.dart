/// APEX — Purchase Cycle (PO → GRN → PI → VendorPayment)
/// ═══════════════════════════════════════════════════════════
/// Shows the full AP cycle with status pills per document and
/// action buttons to approve/issue a PO, post a purchase invoice,
/// and see linked downstream documents via ApexDocumentFlowButton.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_document_flow.dart';
import '../../core/theme.dart';

class PurchaseCycleScreen extends StatefulWidget {
  const PurchaseCycleScreen({super.key});
  @override
  State<PurchaseCycleScreen> createState() => _PurchaseCycleScreenState();
}

class _PurchaseCycleScreenState extends State<PurchaseCycleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _entityCtl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _pos = [];
  List<Map<String, dynamic>> _pis = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _entityCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final e = _entityCtl.text.trim();
    if (e.isEmpty) return setState(() => _error = 'أدخل Entity ID');
    setState(() { _loading = true; _error = null; });

    final r1 = await ApiService.pilotListPOs(e);
    final r2 = await ApiService.pilotListPurchaseInvoices(e);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _pos = r1.success && r1.data is List ? (r1.data as List).cast<Map<String, dynamic>>() : [];
      _pis = r2.success && r2.data is List ? (r2.data as List).cast<Map<String, dynamic>>() : [];
      if (!r1.success && !r2.success) _error = r1.error ?? r2.error;
    });
  }

  Future<void> _approvePo(String id) async {
    final r = await ApiService.pilotApprovePO(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.success ? 'اعتُمد' : r.error ?? 'فشل')));
    _load();
  }

  Future<void> _issuePo(String id) async {
    final r = await ApiService.pilotIssuePO(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.success ? 'أُصدر' : r.error ?? 'فشل')));
    _load();
  }

  Future<void> _postPi(String id) async {
    final r = await ApiService.pilotPostPurchaseInvoice(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.success ? 'رُحِّلت' : r.error ?? 'فشل')));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('دورة المشتريات الكاملة',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.ts,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'أوامر الشراء (${_pos.length})'),
              Tab(text: 'فواتير المشتريات (${_pis.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            _toolbar(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [_poList(), _piList()],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: AC.navy2,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _entityCtl,
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Entity ID',
                labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
                filled: true, fillColor: AC.navy3, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('تحميل', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
        ],
      ),
    );
  }

  Color _poStatusColor(String s) => {
    'draft': AC.ts, 'approved': AC.gold, 'issued': AC.info,
    'received': AC.ok, 'closed': AC.td, 'cancelled': AC.err,
  }[s] ?? AC.ts;

  Widget _poList() {
    if (_pos.isEmpty) return _empty('لا أوامر شراء');
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _pos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _pos[i];
        final status = (p['status'] ?? 'draft') as String;
        final color = _poStatusColor(status);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.shopping_cart, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['po_number']}',
                          style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('${p['po_date']} · ${p['vendor_name'] ?? ''}',
                          style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5)),
                ),
                const SizedBox(width: 8),
                Text('${p['total'] ?? 0} ${p['currency'] ?? ''}',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  ApexDocumentFlowButton(
                    sourceType: 'purchase_order', sourceId: p['id'] as String,
                  ),
                  const Spacer(),
                  if (status == 'draft')
                    TextButton.icon(
                      onPressed: () => _approvePo(p['id'] as String),
                      icon: Icon(Icons.check, size: 14, color: AC.gold),
                      label: Text('اعتماد', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal')),
                    ),
                  if (status == 'approved')
                    TextButton.icon(
                      onPressed: () => _issuePo(p['id'] as String),
                      icon: Icon(Icons.send, size: 14, color: AC.info),
                      label: Text('إصدار', style: TextStyle(color: AC.info, fontFamily: 'Tajawal')),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _piList() {
    if (_pis.isEmpty) return _empty('لا فواتير مشتريات');
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _pis.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _pis[i];
        final status = (p['status'] ?? 'draft') as String;
        final color = status == 'posted' ? AC.ok : (status == 'paid' ? AC.gold : AC.ts);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.receipt_long, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['invoice_number']}',
                          style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('${p['invoice_date']} · ${p['vendor_name'] ?? ''}',
                          style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5)),
                ),
                const SizedBox(width: 8),
                Text('${p['total'] ?? 0} ${p['currency'] ?? ''}',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  ApexDocumentFlowButton(
                    sourceType: 'purchase_invoice', sourceId: p['id'] as String,
                  ),
                  const Spacer(),
                  if (status == 'draft')
                    TextButton.icon(
                      onPressed: () => _postPi(p['id'] as String),
                      icon: Icon(Icons.publish, size: 14, color: AC.ok),
                      label: Text('ترحيل', style: TextStyle(color: AC.ok, fontFamily: 'Tajawal')),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, color: AC.ts, size: 48),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}
