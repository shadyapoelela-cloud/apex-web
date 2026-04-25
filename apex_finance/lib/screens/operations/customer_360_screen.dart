/// APEX — Customer 360 (live)
/// ═══════════════════════════════════════════════════════════════════════
/// Drill into a single customer:
///   • Profile (code, name, VAT, contact)
///   • All invoices (issued + paid + outstanding)
///   • AR ledger (running balance)
///   • Quick action: create new invoice for this customer
///
/// Wires:
///   - GET   /api/v1/pilot/customers/{id}                  (profile)
///   - GET   /api/v1/pilot/customers/{id}/ledger           (AR ledger)
///   - GET   /api/v1/pilot/entities/{entity_id}/sales-invoices?customer_id=…
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class Customer360Screen extends StatefulWidget {
  final String customerId;
  const Customer360Screen({super.key, required this.customerId});

  @override
  State<Customer360Screen> createState() => _Customer360ScreenState();
}

class _Customer360ScreenState extends State<Customer360Screen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ledger;
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.pilotGetCustomer(widget.customerId),
      ApiService.pilotCustomerLedger(widget.customerId),
      ApiService.pilotListSalesInvoices(entityId, limit: 200),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].success && results[0].data is Map) _profile = results[0].data as Map<String, dynamic>;
      if (results[1].success && results[1].data is Map) _ledger = results[1].data as Map<String, dynamic>;
      if (results[2].success && results[2].data is List) {
        _invoices = (results[2].data as List)
            .cast<Map<String, dynamic>>()
            .where((i) => i['customer_id'] == widget.customerId)
            .toList();
      } else if (!results[2].success) {
        _error = results[2].error;
      }
    });
  }

  double get _totalIssued => _invoices
      .where((i) => i['status'] == 'issued' || i['status'] == 'paid')
      .fold<double>(0, (a, i) => a + ((i['total'] as num?)?.toDouble() ?? 0));
  double get _totalPaid => _invoices.fold<double>(
      0, (a, i) => a + ((i['paid_amount'] as num?)?.toDouble() ?? 0));
  double get _totalOutstanding => _totalIssued - _totalPaid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text(
          _profile?['name_ar'] ?? 'العميل',
          style: TextStyle(color: AC.gold),
        ),
        actions: [
          if (_profile?['phone'] != null)
            ApexWhatsAppShareButton(
              compact: true,
              phoneNumber: '${_profile!['phone']}',
              message:
                  'مرحباً ${_profile!['name_ar']} — هذه ملاحظة من خلال APEX',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(
                  child: Text(_error ?? 'لم يتم العثور على العميل',
                      style: TextStyle(color: AC.err)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _profileCard(),
                      const SizedBox(height: 12),
                      _kpiRow(),
                      const SizedBox(height: 12),
                      _invoicesCard(),
                      const ApexOutputChips(items: [
                        ApexChipLink('الفواتير', '/sales/invoices', Icons.receipt),
                        ApexChipLink('عروض الأسعار', '/sales/quotes', Icons.description),
                        ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
                        ApexChipLink('قائمة العملاء', '/sales/customers', Icons.people),
                      ]),
                    ]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/operations/live-sales-cycle'),
        backgroundColor: AC.gold,
        foregroundColor: AC.navy,
        icon: const Icon(Icons.receipt_long),
        label: const Text('فاتورة جديدة'),
      ),
    );
  }

  Widget _profileCard() {
    final p = _profile!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: AC.gold.withValues(alpha: 0.20),
            child: Icon(Icons.business, color: AC.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name_ar'] ?? '-'}',
                  style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${p['code'] ?? ''} · ${p['kind'] ?? ''}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
            ]),
          ),
        ]),
        const Divider(),
        if (p['vat_number'] != null) _kv('الرقم الضريبي', '${p['vat_number']}'),
        if (p['phone'] != null) _kv('الهاتف', '${p['phone']}'),
        if (p['email'] != null) _kv('البريد', '${p['email']}'),
        _kv('شروط الدفع', '${p['payment_terms'] ?? '-'}'),
        _kv('العملة', '${p['currency'] ?? '-'}'),
      ]),
    );
  }

  Widget _kpiRow() => Row(children: [
        Expanded(child: _miniCard('إجمالي صادر', _totalIssued, AC.gold)),
        const SizedBox(width: 8),
        Expanded(child: _miniCard('إجمالي محصّل', _totalPaid, AC.ok)),
        const SizedBox(width: 8),
        Expanded(child: _miniCard('متبقي', _totalOutstanding, AC.warn)),
      ]);

  Widget _miniCard(String label, double v, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(v.toStringAsFixed(0),
                style: TextStyle(
                    color: color, fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
          ),
          Text('SAR', style: TextStyle(color: AC.ts, fontSize: 9.5)),
        ]),
      );

  Widget _invoicesCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.list_alt, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('الفواتير (${_invoices.length})',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (_invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد فواتير لهذا العميل',
                    style: TextStyle(color: AC.ts, fontSize: 12.5)),
              ),
            )
          else
            ..._invoices.map((inv) {
              final isIssued = inv['status'] == 'issued';
              final isPaid = inv['status'] == 'paid';
              final color = isPaid ? AC.ok : (isIssued ? AC.gold : AC.warn);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
                ),
                child: Row(children: [
                  Icon(isPaid ? Icons.verified : (isIssued ? Icons.send : Icons.edit_note),
                      size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${inv['invoice_number']}',
                          style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${inv['issue_date']} — ${inv['status']}',
                          style: TextStyle(color: AC.ts, fontSize: 10)),
                    ]),
                  ),
                  Text('${inv['total']} ${inv['currency'] ?? 'SAR'}',
                      style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                ]),
              );
            }),
        ]),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: AC.ts, fontSize: 11.5))),
          Expanded(child: Text(v, style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'))),
        ]),
      );
}
