/// APEX — Vendor 360 (live, mirror of Customer 360)
/// ═══════════════════════════════════════════════════════════════════════
/// Drill into a single vendor:
///   • Profile (code, name, VAT, contact)
///   • Total bills + paid + outstanding
///   • Quick action: create new purchase invoice
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class Vendor360Screen extends StatefulWidget {
  final String vendorId;
  const Vendor360Screen({super.key, required this.vendorId});

  @override
  State<Vendor360Screen> createState() => _Vendor360ScreenState();
}

class _Vendor360ScreenState extends State<Vendor360Screen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _bills = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.pilotListVendors(tenantId),
      ApiService.pilotListPurchaseInvoices(entityId),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].success && results[0].data is List) {
        final list = (results[0].data as List).cast<Map<String, dynamic>>();
        try {
          _profile = list.firstWhere((v) => v['id'] == widget.vendorId);
        } catch (_) {
          _error = 'لم يتم العثور على المورد';
        }
      }
      if (results[1].success && results[1].data is List) {
        _bills = (results[1].data as List)
            .cast<Map<String, dynamic>>()
            .where((b) => b['vendor_id'] == widget.vendorId)
            .toList();
      }
    });
  }

  double get _totalBilled => _bills.fold<double>(
      0, (a, b) => a + ((b['total'] as num?)?.toDouble() ?? 0));
  double get _totalPaid => _bills.fold<double>(
      0, (a, b) => a + ((b['paid_amount'] as num?)?.toDouble() ?? 0));
  double get _outstanding => _totalBilled - _totalPaid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text(_profile?['name_ar'] ?? 'المورد',
            style: TextStyle(color: AC.gold)),
        actions: [
          if (_profile?['phone'] != null)
            ApexWhatsAppShareButton(
              compact: true,
              phoneNumber: '${_profile!['phone']}',
              message: 'مرحباً ${_profile!['name_ar']}',
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
              ? Center(child: Text(_error ?? 'لم يتم العثور', style: TextStyle(color: AC.err)))
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
                      _billsCard(),
                      const ApexOutputChips(items: [
                        ApexChipLink('فواتير الموردين', '/app/erp/finance/purchase-bills', Icons.receipt_outlined),
                        ApexChipLink('أعمار AP', '/app/erp/purchasing/ap-aging', Icons.timeline),
                        ApexChipLink('استقطاع المصدر WHT', '/app/compliance/tax/wht', Icons.percent),
                        ApexChipLink('قائمة الموردين', '/app/erp/purchasing/suppliers', Icons.business),
                      ]),
                    ]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/purchase'),
        backgroundColor: AC.gold,
        foregroundColor: AC.navy,
        icon: const Icon(Icons.shopping_cart),
        label: const Text('فاتورة شراء جديدة'),
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
            child: Icon(Icons.local_shipping, color: AC.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name_ar'] ?? '-'}',
                  style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${p['code'] ?? ''}',
                  style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
            ]),
          ),
        ]),
        const Divider(),
        if (p['vat_number'] != null) _kv('الرقم الضريبي', '${p['vat_number']}'),
        if (p['phone'] != null) _kv('الهاتف', '${p['phone']}'),
        if (p['email'] != null) _kv('البريد', '${p['email']}'),
        _kv('شروط الدفع', '${p['payment_terms'] ?? '-'}'),
      ]),
    );
  }

  Widget _kpiRow() => Row(children: [
        Expanded(child: _miniCard('إجمالي مفوتر', _totalBilled, AC.gold)),
        const SizedBox(width: 8),
        Expanded(child: _miniCard('إجمالي مدفوع', _totalPaid, AC.ok)),
        const SizedBox(width: 8),
        Expanded(child: _miniCard('متبقٍ', _outstanding, AC.warn)),
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

  Widget _billsCard() => Container(
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
              Text('الفواتير (${_bills.length})',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (_bills.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('لا توجد فواتير من هذا المورد',
                      style: TextStyle(color: AC.ts, fontSize: 12.5))),
            )
          else
            ..._bills.map((b) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
                  child: Row(children: [
                    Icon(Icons.receipt, size: 14, color: AC.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${b['bill_number'] ?? b['invoice_number'] ?? '-'}',
                            style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('${b['issue_date'] ?? ''} — ${b['status'] ?? ''}',
                            style: TextStyle(color: AC.ts, fontSize: 10)),
                      ]),
                    ),
                    Text('${b['total']} SAR',
                        style: TextStyle(
                            color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  ]),
                )),
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
