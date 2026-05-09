/// Vendor Details — G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09).
///
/// Route: `/app/erp/finance/vendors/:vendorId`
///
/// Three tabs:
///   1. تفاصيل — basic info pulled from `GET /pilot/vendors/{id}`.
///   2. السجل المالي — ledger from `GET /pilot/vendors/{id}/ledger`.
///   3. فواتير المشتريات — purchase invoices filtered by `vendor_id`,
///      pulled from `GET /pilot/entities/{eid}/purchase-invoices`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class VendorDetailsScreen extends StatefulWidget {
  final String vendorId;
  const VendorDetailsScreen({super.key, required this.vendorId});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _vendor;
  List<Map<String, dynamic>> _ledger = [];
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final v = await ApiService.pilotGetVendor(widget.vendorId);
    if (!mounted) return;
    if (!v.success || v.data is! Map) {
      setState(() {
        _loading = false;
        _error = v.error ?? 'تعذّر تحميل المورد';
      });
      return;
    }
    final ledger = await ApiService.pilotVendorLedger(widget.vendorId);
    final entityId = S.savedEntityId;
    final invoicesRes = entityId == null
        ? null
        : await ApiService.pilotListPurchaseInvoices(entityId, limit: 200);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _vendor = (v.data as Map).cast<String, dynamic>();
      _ledger = (ledger.success && ledger.data is List)
          ? (ledger.data as List).cast<Map<String, dynamic>>()
          : [];
      if (invoicesRes != null &&
          invoicesRes.success &&
          invoicesRes.data is List) {
        _invoices = (invoicesRes.data as List)
            .cast<Map<String, dynamic>>()
            .where((inv) =>
                (inv['vendor_id'] ?? '').toString() == widget.vendorId)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          foregroundColor: AC.tp,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/app/erp/finance/purchase-vendors'),
          ),
          title: Text(_vendor?['legal_name_ar']?.toString() ?? 'المورد',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _load),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.td,
            tabs: const [
              Tab(text: 'تفاصيل', icon: Icon(Icons.factory_outlined)),
              Tab(
                  text: 'السجل المالي',
                  icon: Icon(Icons.account_balance_outlined)),
              Tab(
                  text: 'فواتير المشتريات',
                  icon: Icon(Icons.receipt_long_outlined)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, color: AC.err, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: AC.err)),
                    ]),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _buildDetailsTab(),
                      _buildLedgerTab(),
                      _buildInvoicesTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final v = _vendor!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiRow([
            _kpi('الكود', (v['code'] ?? '—').toString(), Icons.tag),
            _kpi('الحالة', (v['is_active'] == true) ? 'نشط' : 'غير نشط',
                Icons.check_circle_outline,
                color: (v['is_active'] == true) ? AC.ok : AC.td),
            _kpi(
                'مفضّل',
                (v['is_preferred'] == true) ? 'نعم' : 'لا',
                Icons.star_outline,
                color: (v['is_preferred'] == true) ? AC.gold : AC.td),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('معلومات أساسية'),
          _detailGrid([
            _detail('الاسم القانوني العربي', v['legal_name_ar']),
            _detail('الاسم القانوني الإنجليزي', v['legal_name_en']),
            _detail('الاسم التجاري', v['trade_name']),
            _detail('النوع', _kindLabel(v['kind'])),
            _detail('الدولة', v['country']),
            _detail('الفئة', v['category']),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('ضريبة وسجل تجاري'),
          _detailGrid([
            _detail('الرقم الضريبي', v['vat_number']),
            _detail('السجل التجاري', v['cr_number']),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('شروط مالية'),
          _detailGrid([
            _detail('العملة', v['default_currency']),
            _detail('شروط الدفع', _paymentTermsLabel(v['payment_terms'])),
            _detail(
                'حد الائتمان',
                (v['credit_limit'] != null)
                    ? '${v['credit_limit']}'
                    : '—'),
            _detail('مشتريات السنة',
                (v['total_purchases_ytd'] ?? 0).toString()),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('بنك ودفع'),
          _detailGrid([
            _detail('اسم البنك', v['bank_name']),
            _detail('IBAN', v['bank_iban']),
            _detail('SWIFT', v['bank_swift']),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('جهة اتصال'),
          _detailGrid([
            _detail('جهة الاتصال', v['contact_name']),
            _detail('البريد', v['email']),
            _detail('الهاتف', v['phone']),
          ]),
        ],
      ),
    );
  }

  Widget _buildLedgerTab() {
    if (_ledger.isEmpty) {
      return Center(
        child: Text('لا توجد حركات في السجل بعد',
            style: TextStyle(color: AC.td)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ledger.length,
      itemBuilder: (_, i) {
        final m = _ledger[i];
        final amount =
            (m['amount'] ?? m['debit'] ?? m['credit'] ?? 0).toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.bdr),
          ),
          child: Row(children: [
            Icon(Icons.swap_horiz_rounded, color: AC.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((m['memo'] ?? m['description'] ?? '—').toString(),
                      style: TextStyle(color: AC.tp, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text((m['date'] ?? m['created_at'] ?? '').toString(),
                      style: TextStyle(color: AC.td, fontSize: 11)),
                ],
              ),
            ),
            Text(amount,
                style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );
      },
    );
  }

  Widget _buildInvoicesTab() {
    if (_invoices.isEmpty) {
      return Center(
        child: Text('لا توجد فواتير شراء لهذا المورد',
            style: TextStyle(color: AC.td)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        final status = (inv['status'] ?? '').toString();
        final color = switch (status) {
          'paid' => AC.ok,
          'posted' => AC.gold,
          'cancelled' => AC.err,
          _ => AC.td,
        };
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.bdr),
          ),
          child: Row(children: [
            Icon(Icons.receipt_long_rounded, color: AC.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      (inv['invoice_number'] ?? inv['number'] ?? '—')
                          .toString(),
                      style: TextStyle(color: AC.tp, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text((inv['issue_date'] ?? '').toString(),
                      style: TextStyle(color: AC.td, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_statusLabel(status),
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Text((inv['total'] ?? 0).toString(),
                style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );
      },
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'مسودة';
      case 'posted':
        return 'مرحَّلة';
      case 'paid':
        return 'مدفوعة';
      case 'cancelled':
        return 'ملغاة';
    }
    return s;
  }

  String _kindLabel(dynamic v) {
    switch ((v ?? '').toString()) {
      case 'goods':
        return 'سلع';
      case 'services':
        return 'خدمات';
      case 'both':
        return 'سلع وخدمات';
      case 'employee':
        return 'موظف';
      case 'government':
        return 'جهة حكومية';
    }
    return '—';
  }

  String _paymentTermsLabel(dynamic v) {
    switch ((v ?? '').toString()) {
      case 'cash':
        return 'نقداً';
      case 'net_0':
        return 'فوري';
      case 'net_15':
        return 'صافي 15 يوماً';
      case 'net_30':
        return 'صافي 30 يوماً';
      case 'net_45':
        return 'صافي 45 يوماً';
      case 'net_60':
        return 'صافي 60 يوماً';
      case 'net_90':
        return 'صافي 90 يوماً';
      case 'advance':
        return 'دفعة مقدمة';
    }
    return '—';
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                color: AC.gold,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  Widget _detailGrid(List<Widget> items) => Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final item in items)
            ConstrainedBox(
              constraints:
                  const BoxConstraints(minWidth: 240, maxWidth: 320),
              child: item,
            ),
        ],
      );

  Widget _detail(String label, dynamic value) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AC.td, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
                (value == null || value.toString().isEmpty)
                    ? '—'
                    : value.toString(),
                style: TextStyle(color: AC.tp, fontSize: 13)),
          ],
        ),
      );

  Widget _kpiRow(List<Widget> children) => Row(children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 10),
        ],
      ]);

  Widget _kpi(String label, String value, IconData icon, {Color? color}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          Icon(icon, color: color ?? AC.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AC.td, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: color ?? AC.tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ]),
      );
}
