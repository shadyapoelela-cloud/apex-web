/// Purchasing — دورة المشتريات الكاملة (PO → GRN → PI → Payment).
///
/// مستقلة — تعتمد على PilotSession.entityId + PilotSession.tenantId.
///
/// التبويبات:
///   1) أوامر الشراء — قائمة + إنشاء + اعتماد + إصدار
///   2) فواتير المشتريات — قائمة + إنشاء + ترحيل إلى GL
///   3) مدفوعات الموردين — قائمة + تسجيل دفعة
library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
import '../../export_utils.dart';
import '../../num_utils.dart';
import '../../session.dart';

const _gold = Color(0xFFD4AF37);
const _navy = Color(0xFF0A1628);
const _navy2 = Color(0xFF132339);
const _navy3 = Color(0xFF1D3150);
const _bdr = Color(0x33FFFFFF);
const _tp = Color(0xFFFFFFFF);
const _ts = Color(0xFFBCC5D3);
const _td = Color(0xFF6B7A90);
const _ok = Color(0xFF10B981);
const _err = Color(0xFFEF4444);
const _warn = Color(0xFFF59E0B);
const _blue = Color(0xFF3B82F6);
const _indigo = Color(0xFF6366F1);

const _kPoStatuses = <String, Map<String, dynamic>>{
  'draft': {'ar': 'مسودّة', 'color': _td},
  'submitted': {'ar': 'مُقدَّم', 'color': _warn},
  'approved': {'ar': 'معتمد', 'color': _blue},
  'issued': {'ar': 'صادر', 'color': _indigo},
  'partially_received': {'ar': 'استلام جزئي', 'color': _warn},
  'received': {'ar': 'مُستلَم', 'color': _ok},
  'closed': {'ar': 'مُغلَق', 'color': _td},
  'cancelled': {'ar': 'ملغى', 'color': _err},
};

const _kPiStatuses = <String, Map<String, dynamic>>{
  'draft': {'ar': 'مسودّة', 'color': _td},
  'submitted': {'ar': 'مُقدَّم', 'color': _warn},
  'posted': {'ar': 'مُرحَّل', 'color': _blue},
  'partially_paid': {'ar': 'مدفوع جزئياً', 'color': _warn},
  'paid': {'ar': 'مدفوع', 'color': _ok},
  'cancelled': {'ar': 'ملغى', 'color': _err},
};

const _kPaymentMethods = <String, String>{
  'cash': 'نقدي',
  'bank_transfer': 'تحويل بنكي',
  'cheque': 'شيك',
  'credit_card': 'بطاقة ائتمان',
  'other': 'أخرى',
};

class PurchasingScreen extends StatefulWidget {
  const PurchasingScreen({super.key});
  @override
  State<PurchasingScreen> createState() => _PurchasingScreenState();
}

class _PurchasingScreenState extends State<PurchasingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final PilotClient _client = pilotClient;

  List<Map<String, dynamic>> _pos = [];
  List<Map<String, dynamic>> _pis = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _products = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasTenant || !PilotSession.hasEntity) {
      setState(() {
        _loading = false;
        _error = 'يجب اختيار الشركة والكيان من شريط العنوان أولاً.';
      });
      return;
    }
    final tid = PilotSession.tenantId!;
    final eid = PilotSession.entityId!;
    try {
      final results = await Future.wait([
        _client.listPurchaseOrders(eid, limit: 200),
        _client.listPurchaseInvoices(eid, limit: 200),
        _client.listVendorPayments(eid, limit: 200),
        _client.listVendors(tid, activeOnly: true),
        _client.listBranches(eid),
        _client.listProducts(tid, status: 'active'),
      ]);
      _pos = results[0].success
          ? List<Map<String, dynamic>>.from(results[0].data)
          : [];
      _pis = results[1].success
          ? List<Map<String, dynamic>>.from(results[1].data)
          : [];
      _payments = results[2].success
          ? List<Map<String, dynamic>>.from(results[2].data)
          : [];
      _vendors = results[3].success
          ? List<Map<String, dynamic>>.from(results[3].data)
          : [];
      _branches = results[4].success
          ? List<Map<String, dynamic>>.from(results[4].data)
          : [];
      _products = results[5].success
          ? List<Map<String, dynamic>>.from(results[5].data)
          : [];
      _warehouses = [];
      for (final b in _branches) {
        final wR = await _client.listWarehouses(b['id']);
        if (wR.success) {
          for (final w in List<Map<String, dynamic>>.from(wR.data)) {
            _warehouses.add(
                {...w, '_branch_code': b['code'], '_branch_id': b['id']});
          }
        }
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _variantsFor(String productId) async {
    final r = await _client.listVariants(productId);
    return r.success ? List<Map<String, dynamic>>.from(r.data) : [];
  }

  String _vendorName(String? id) {
    if (id == null) return '—';
    return _vendors.firstWhere((v) => v['id'] == id,
            orElse: () => {'legal_name_ar': '—'})['legal_name_ar'] ??
        '—';
  }

  double _sum(List<Map<String, dynamic>> list, String field) {
    double t = 0;
    for (final v in list) {
      final x = v[field];
      if (x is num) t += x.toDouble();
      if (x is String) t += double.tryParse(x) ?? 0;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(children: [
          _header(),
          Container(
            color: _navy2,
            child: TabBar(
              controller: _tab,
              indicatorColor: _gold,
              labelColor: _gold,
              unselectedLabelColor: _ts,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: [
                Tab(
                    icon: const Icon(Icons.receipt_long, size: 16),
                    text: 'أوامر الشراء (${_pos.length})'),
                Tab(
                    icon: const Icon(Icons.receipt, size: 16),
                    text: 'فواتير المشتريات (${_pis.length})'),
                Tab(
                    icon: const Icon(Icons.payments, size: 16),
                    text: 'المدفوعات (${_payments.length})'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : TabBarView(controller: _tab, children: [
                        _posTab(),
                        _pisTab(),
                        _paymentsTab(),
                      ]),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
          color: _navy2, border: Border(bottom: BorderSide(color: _bdr))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.shopping_bag, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('المشتريات',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('PO → GRN → Purchase Invoice → Vendor Payment',
                style: TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: const BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
      ]),
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _ts)),
        ]),
      );

  // ════════════════════════════════════════════════════════════════════
  // Tab 1: Purchase Orders
  // ════════════════════════════════════════════════════════════════════

  Widget _posTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          _kpi('إجمالي الأوامر', '${_pos.length}', _gold),
          const SizedBox(width: 10),
          _kpi(
              'قيمة الأوامر',
              _fmt(_sum(_pos, 'grand_total')),
              _blue),
          const SizedBox(width: 10),
          _kpi(
              'غير صادرة',
              '${_pos.where((p) => p['status'] == 'draft' || p['status'] == 'submitted' || p['status'] == 'approved').length}',
              _warn),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _createPo,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('أمر شراء جديد'),
          ),
        ]),
      ),
      Expanded(
        child: _pos.isEmpty
            ? _emptyTab(
                'لا توجد أوامر شراء',
                'ابدأ بإنشاء أمر الشراء الأول',
                Icons.receipt_long_outlined,
                'أمر شراء جديد',
                _createPo)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _poTableHeader(),
                  ..._pos.map(_poRow),
                ],
              ),
      ),
    ]);
  }

  Widget _poTableHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _navy3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _bdr),
        ),
        child: Row(children: const [
          SizedBox(width: 130, child: Text('رقم الأمر', style: _th)),
          SizedBox(width: 95, child: Text('التاريخ', style: _th)),
          Expanded(flex: 2, child: Text('المورد', style: _th)),
          SizedBox(width: 120, child: Text('الحالة', style: _th)),
          SizedBox(
              width: 120,
              child: Text('القيمة', style: _th, textAlign: TextAlign.end)),
          SizedBox(width: 120, child: Text('إجراءات', style: _th)),
        ]),
      );

  Widget _poRow(Map<String, dynamic> p) {
    final total = asDouble(p['grand_total']);
    final status = p['status'] ?? 'draft';
    final info = _kPoStatuses[status] ?? {'ar': status, 'color': _td};
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(p['po_number'] ?? '',
              style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        SizedBox(
          width: 95,
          child: Text(p['order_date'] ?? '',
              style: const TextStyle(
                  color: _ts, fontSize: 11, fontFamily: 'monospace')),
        ),
        Expanded(
          flex: 2,
          child: Text(_vendorName(p['vendor_id']),
              style: const TextStyle(color: _tp, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        SizedBox(
          width: 120,
          child: _tag(info['ar'] as String, info['color'] as Color),
        ),
        SizedBox(
          width: 120,
          child: Text(_fmt(total),
              style: const TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 120,
          child: Row(children: [
            if (status == 'draft' || status == 'submitted')
              IconButton(
                tooltip: 'اعتماد',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.check_circle, color: _ok, size: 16),
                onPressed: () => _approvePo(p['id']),
              ),
            if (status == 'approved')
              IconButton(
                tooltip: 'إصدار',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.send, color: _blue, size: 16),
                onPressed: () => _issuePo(p['id']),
              ),
            if (status == 'issued' || status == 'partially_received')
              IconButton(
                tooltip: 'استلام بضاعة (GRN)',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.call_received, color: _gold, size: 16),
                onPressed: () => _createGrn(p),
              ),
            IconButton(
              tooltip: 'طباعة / PDF',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.print, color: _indigo, size: 16),
              onPressed: () => _printPo(p['id']),
            ),
            IconButton(
              tooltip: 'عرض',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.visibility, color: _ts, size: 16),
              onPressed: () => _showPoDetail(p['id']),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _createPo() async {
    if (_vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _warn, content: Text('أضف مورداً أولاً')));
      return;
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _PoDialog(
        vendors: _vendors,
        products: _products,
        warehouses: _warehouses,
        variantsLoader: _variantsFor,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _approvePo(String id) async {
    final r = await _client.approvePurchaseOrder(id, 'system');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.success ? _ok : _err,
        content: Text(r.success ? 'تم الاعتماد ✓' : r.error ?? 'فشل الاعتماد')));
    if (r.success) _load();
  }

  Future<void> _issuePo(String id) async {
    final r = await _client.issuePurchaseOrder(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.success ? _ok : _err,
        content: Text(r.success ? 'تم الإصدار ✓' : r.error ?? 'فشل الإصدار')));
    if (r.success) _load();
  }

  Future<void> _createGrn(Map<String, dynamic> po) async {
    final detail = await _client.getPurchaseOrder(po['id']);
    if (!mounted) return;
    if (!detail.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _err,
          content: Text(detail.error ?? 'فشل تحميل الأمر')));
      return;
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _GrnDialog(
        poDetail: Map<String, dynamic>.from(detail.data),
        warehouses: _warehouses,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _printPo(String id) async {
    final r = await _client.getPurchaseOrder(id);
    if (!r.success || !mounted) return;
    final po = Map<String, dynamic>.from(r.data);
    final vendor = _vendors.firstWhere((v) => v['id'] == po['vendor_id'],
        orElse: () => {'legal_name_ar': '—', 'code': ''});
    final lines = (po['lines'] as List?) ?? [];
    final stringRows = lines.map<List<String>>((l) {
      final ln = Map<String, dynamic>.from(l);
      return [
        '${ln['line_number'] ?? ''}',
        ln['description'] ?? '',
        asDouble(ln['qty_ordered']).toStringAsFixed(2),
        asDouble(ln['unit_price']).toStringAsFixed(2),
        '${asDouble(ln['vat_rate_pct']).toStringAsFixed(0)}%',
        asDouble(ln['line_total']).toStringAsFixed(2),
      ];
    }).toList();

    // Totals row
    stringRows.add(['', '', '', '', 'المجموع:',
        asDouble(po['subtotal']).toStringAsFixed(2)]);
    stringRows.add(['', '', '', '', 'VAT:',
        asDouble(po['vat_total']).toStringAsFixed(2)]);
    stringRows.add(['', '', '', '', 'الإجمالي:',
        asDouble(po['grand_total']).toStringAsFixed(2)]);

    printHtmlTable(
      title: 'أمر شراء ${po['po_number'] ?? ""}',
      companyName: 'APEX Pilot',
      companyMeta:
          'المورد: ${vendor['legal_name_ar']} · التاريخ: ${po['order_date'] ?? ""} · العملة: ${po['currency'] ?? "SAR"}',
      headers: ['#', 'الوصف', 'الكمية', 'السعر', 'VAT', 'الإجمالي'],
      rows: stringRows,
      footer: 'تاريخ التسليم المتوقع: ${po['expected_delivery_date'] ?? "—"} · '
          'شروط الدفع: ${po['payment_terms'] ?? "—"}',
    );
  }

  Future<void> _printPi(String id) async {
    final r = await _client.getPurchaseInvoice(id);
    if (!r.success || !mounted) return;
    final pi = Map<String, dynamic>.from(r.data);
    final vendor = _vendors.firstWhere((v) => v['id'] == pi['vendor_id'],
        orElse: () => {'legal_name_ar': '—'});
    final lines = (pi['lines'] as List?) ?? [];
    final stringRows = lines.map<List<String>>((l) {
      final ln = Map<String, dynamic>.from(l);
      return [
        '${ln['line_number'] ?? ''}',
        ln['description'] ?? '',
        asDouble(ln['qty']).toStringAsFixed(2),
        asDouble(ln['unit_cost']).toStringAsFixed(2),
        '${asDouble(ln['vat_rate_pct']).toStringAsFixed(0)}%',
        asDouble(ln['line_total']).toStringAsFixed(2),
      ];
    }).toList();
    stringRows.add(['', '', '', '', 'المجموع:',
        asDouble(pi['subtotal']).toStringAsFixed(2)]);
    stringRows.add(['', '', '', '', 'VAT:',
        asDouble(pi['vat_total']).toStringAsFixed(2)]);
    if (asDouble(pi['shipping']) > 0) {
      stringRows.add(['', '', '', '', 'شحن:',
          asDouble(pi['shipping']).toStringAsFixed(2)]);
    }
    stringRows.add(['', '', '', '', 'الإجمالي:',
        asDouble(pi['grand_total']).toStringAsFixed(2)]);
    stringRows.add(['', '', '', '', 'المدفوع:',
        asDouble(pi['amount_paid']).toStringAsFixed(2)]);
    stringRows.add(['', '', '', '', 'المستحق:',
        asDouble(pi['amount_due']).toStringAsFixed(2)]);

    printHtmlTable(
      title: 'فاتورة شراء ${pi['invoice_number'] ?? ""}',
      companyName: 'APEX Pilot',
      companyMeta:
          'المورد: ${vendor['legal_name_ar']} · رقم فاتورة المورد: ${pi['vendor_invoice_number'] ?? "—"} · التاريخ: ${pi['invoice_date'] ?? ""}',
      headers: ['#', 'الوصف', 'الكمية', 'التكلفة', 'VAT', 'الإجمالي'],
      rows: stringRows,
      footer:
          'تاريخ الاستحقاق: ${pi['due_date'] ?? "—"} · الحالة: ${pi['status'] ?? ""}',
    );
  }

  Future<void> _showPoDetail(String id) async {
    final r = await _client.getPurchaseOrder(id);
    if (!r.success) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _DetailDialog(
        title: 'تفاصيل أمر الشراء',
        icon: Icons.receipt_long,
        data: Map<String, dynamic>.from(r.data),
        vendorName: _vendorName,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 2: Purchase Invoices
  // ════════════════════════════════════════════════════════════════════

  Widget _pisTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          _kpi('إجمالي الفواتير', '${_pis.length}', _gold),
          const SizedBox(width: 10),
          _kpi('إجمالي القيمة',
              _fmt(_sum(_pis, 'grand_total')), _blue),
          const SizedBox(width: 10),
          _kpi('المستحق',
              _fmt(_sum(_pis, 'amount_due')), _err),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _createPi,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('فاتورة شراء جديدة'),
          ),
        ]),
      ),
      Expanded(
        child: _pis.isEmpty
            ? _emptyTab(
                'لا توجد فواتير شراء',
                'أنشئ فاتورة شراء (من أمر شراء أو قائمة بذاتها)',
                Icons.receipt,
                'فاتورة جديدة',
                _createPi)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _piTableHeader(),
                  ..._pis.map(_piRow),
                ],
              ),
      ),
    ]);
  }

  Widget _piTableHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _navy3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _bdr),
        ),
        child: Row(children: const [
          SizedBox(width: 130, child: Text('رقم الفاتورة', style: _th)),
          SizedBox(width: 95, child: Text('التاريخ', style: _th)),
          Expanded(flex: 2, child: Text('المورد', style: _th)),
          SizedBox(width: 100, child: Text('الحالة', style: _th)),
          SizedBox(
              width: 110,
              child: Text('الإجمالي', style: _th, textAlign: TextAlign.end)),
          SizedBox(
              width: 110,
              child: Text('المستحق', style: _th, textAlign: TextAlign.end)),
          SizedBox(width: 90, child: Text('إجراءات', style: _th)),
        ]),
      );

  Widget _piRow(Map<String, dynamic> p) {
    final total = asDouble(p['grand_total']);
    final due = asDouble(p['amount_due']);
    final status = p['status'] ?? 'draft';
    final info = _kPiStatuses[status] ?? {'ar': status, 'color': _td};
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(p['invoice_number'] ?? '',
              style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        SizedBox(
          width: 95,
          child: Text(p['invoice_date'] ?? '',
              style: const TextStyle(
                  color: _ts, fontSize: 11, fontFamily: 'monospace')),
        ),
        Expanded(
          flex: 2,
          child: Text(_vendorName(p['vendor_id']),
              style: const TextStyle(color: _tp, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        SizedBox(
            width: 100,
            child: _tag(info['ar'] as String, info['color'] as Color)),
        SizedBox(
          width: 110,
          child: Text(_fmt(total),
              style: const TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 110,
          child: Text(_fmt(due),
              style: TextStyle(
                  color: due > 0 ? _err : _ok,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 90,
          child: Row(children: [
            if (status == 'draft')
              IconButton(
                tooltip: 'ترحيل إلى GL',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.check_circle, color: _ok, size: 16),
                onPressed: () => _postPi(p['id']),
              ),
            if ((status == 'posted' || status == 'partially_paid') && due > 0)
              IconButton(
                tooltip: 'تسديد',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.payments, color: _gold, size: 16),
                onPressed: () => _payInvoice(p),
              ),
            IconButton(
              tooltip: 'طباعة / PDF',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.print, color: _indigo, size: 16),
              onPressed: () => _printPi(p['id']),
            ),
            IconButton(
              tooltip: 'عرض',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.visibility, color: _ts, size: 16),
              onPressed: () => _showPiDetail(p['id']),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _createPi() async {
    if (_vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _warn, content: Text('أضف مورداً أولاً')));
      return;
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _PiDialog(
        vendors: _vendors,
        products: _products,
        variantsLoader: _variantsFor,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _postPi(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title:
              const Text('ترحيل الفاتورة إلى GL', style: TextStyle(color: _tp)),
          content: const Text(
              'سيتم إنشاء قيد يومية بقيد مدين (مصاريف/مخزون + VAT) ودائن (ذمم الموردين).\n\nلا يمكن التراجع بعد الترحيل.',
              style: TextStyle(color: _ts, height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ترحيل')),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final r = await _client.postPurchaseInvoice(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.success ? _ok : _err,
        content: Text(r.success ? 'تم الترحيل ✓' : r.error ?? 'فشل الترحيل')));
    if (r.success) _load();
  }

  Future<void> _payInvoice(Map<String, dynamic> pi) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentDialog(
        vendorId: pi['vendor_id'],
        invoice: pi,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _showPiDetail(String id) async {
    final r = await _client.getPurchaseInvoice(id);
    if (!r.success) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _DetailDialog(
        title: 'تفاصيل فاتورة الشراء',
        icon: Icons.receipt,
        data: Map<String, dynamic>.from(r.data),
        vendorName: _vendorName,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 3: Payments
  // ════════════════════════════════════════════════════════════════════

  Widget _paymentsTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          _kpi('عدد المدفوعات', '${_payments.length}', _gold),
          const SizedBox(width: 10),
          _kpi('إجمالي المدفوع',
              _fmt(_sum(_payments, 'amount')), _ok),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _createStandalonePayment,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('دفعة جديدة'),
          ),
        ]),
      ),
      Expanded(
        child: _payments.isEmpty
            ? _emptyTab(
                'لا توجد مدفوعات',
                'سجّل دفعة من فاتورة أو بشكل مستقل',
                Icons.payments_outlined,
                'دفعة جديدة',
                _createStandalonePayment)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _bdr),
                    ),
                    child: Row(children: const [
                      SizedBox(
                          width: 130, child: Text('رقم الدفعة', style: _th)),
                      SizedBox(width: 95, child: Text('التاريخ', style: _th)),
                      Expanded(flex: 2, child: Text('المورد', style: _th)),
                      SizedBox(width: 110, child: Text('الطريقة', style: _th)),
                      SizedBox(
                          width: 120,
                          child: Text('المبلغ',
                              style: _th, textAlign: TextAlign.end)),
                      SizedBox(
                          width: 120, child: Text('مرجع', style: _th)),
                    ]),
                  ),
                  ..._payments.map((p) {
                    final amt = asDouble(p['amount']);
                    return Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _navy2.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _bdr),
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 130,
                          child: Text(p['payment_number'] ?? '',
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 95,
                          child: Text(p['payment_date'] ?? '',
                              style: const TextStyle(
                                  color: _ts,
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_vendorName(p['vendor_id']),
                              style: const TextStyle(
                                  color: _tp, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: 110,
                          child: _tag(
                              _kPaymentMethods[p['method']] ??
                                  p['method'] ??
                                  '',
                              _blue),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(_fmt(amt),
                              style: const TextStyle(
                                  color: _ok,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace'),
                              textAlign: TextAlign.end),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(p['reference_number'] ?? '—',
                              style: const TextStyle(
                                  color: _td,
                                  fontSize: 10,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    );
                  }),
                ],
              ),
      ),
    ]);
  }

  Future<void> _createStandalonePayment() async {
    if (_vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _warn, content: Text('أضف مورداً أولاً')));
      return;
    }
    final vendor = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('اختر المورد', style: TextStyle(color: _tp)),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: _vendors
                  .map((v) => ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(v['code'] ?? '',
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700)),
                        ),
                        title: Text(v['legal_name_ar'] ?? '',
                            style:
                                const TextStyle(color: _tp, fontSize: 13)),
                        subtitle: Text(
                            'رصيد مستحق: ${_fmt(asDouble(v['outstanding_balance']))}',
                            style:
                                const TextStyle(color: _td, fontSize: 11)),
                        onTap: () => Navigator.pop(context, v),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (vendor == null) return;
    if (!mounted) return;
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentDialog(
          vendorId: vendor['id'], invoice: null),
    );
    if (r == true) _load();
  }

  // ════════════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════════════

  Widget _emptyTab(String title, String subtitle, IconData icon,
      String cta, VoidCallback onCta) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _gold.withValues(alpha: 0.4), size: 72),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(color: _tp, fontSize: 16)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: _ts, fontSize: 12)),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _gold, foregroundColor: Colors.black),
          onPressed: onCta,
          icon: const Icon(Icons.add, size: 14),
          label: Text(cta),
        ),
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _td, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ],
        ),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      );

  String _fmt(double v) {
    if (v == 0) return '0';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

const _th = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════════
// PO Dialog
// ══════════════════════════════════════════════════════════════════════════

class _PoLine {
  String? variantId;
  String? sku;
  String description = '';
  double qty = 1;
  double unitPrice = 0;
  double vatRate = 15;
  _PoLine();
}

class _PoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vendors;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> warehouses;
  final Future<List<Map<String, dynamic>>> Function(String) variantsLoader;
  const _PoDialog(
      {required this.vendors,
      required this.products,
      required this.warehouses,
      required this.variantsLoader});
  @override
  State<_PoDialog> createState() => _PoDialogState();
}

class _PoDialogState extends State<_PoDialog> {
  String? _vendorId;
  String? _warehouseId;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDate;
  String _terms = 'net_30';
  final _notes = TextEditingController();
  final List<_PoLine> _lines = [_PoLine()];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (t, l) => t + l.qty * l.unitPrice);
  double get _vat =>
      _lines.fold(0.0, (t, l) => t + (l.qty * l.unitPrice) * (l.vatRate / 100));
  double get _total => _subtotal + _vat;

  Future<void> _pickVariant(int i) async {
    final productId = await showDialog<String>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('اختر صنفاً', style: TextStyle(color: _tp)),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView(
              children: widget.products
                  .map((p) => ListTile(
                        dense: true,
                        title: Text(
                            '${p['code']} — ${p['name_ar']}',
                            style: const TextStyle(color: _tp, fontSize: 12)),
                        onTap: () => Navigator.pop(context, p['id'] as String),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (productId == null) return;
    final vs = await widget.variantsLoader(productId);
    if (vs.isEmpty || !mounted) return;
    final variant = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('اختر متغيّراً', style: TextStyle(color: _tp)),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView(
              children: vs
                  .map((v) => ListTile(
                        dense: true,
                        title: Text(v['sku'] ?? '',
                            style: const TextStyle(
                                color: _gold,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                        subtitle: Text(v['display_name_ar'] ?? '',
                            style: const TextStyle(color: _ts, fontSize: 11)),
                        trailing: Text(
                            'تكلفة: ${(v['default_cost'] ?? 0)}',
                            style: const TextStyle(color: _td, fontSize: 10)),
                        onTap: () => Navigator.pop(context, v),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (variant == null) return;
    setState(() {
      _lines[i].variantId = variant['id'];
      _lines[i].sku = variant['sku'];
      _lines[i].description =
          '${variant['sku']} — ${variant['display_name_ar'] ?? ''}';
      _lines[i].unitPrice =
          asDouble(variant['default_cost'] ?? variant['standard_cost']);
    });
  }

  Future<void> _pickDate(bool expected) async {
    final d = await showDatePicker(
      context: context,
      initialDate: expected ? (_expectedDate ?? DateTime.now()) : _orderDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        if (expected) {
          _expectedDate = d;
        } else {
          _orderDate = d;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_vendorId == null) {
      setState(() => _error = 'اختر المورد');
      return;
    }
    if (_lines.isEmpty || _lines.every((l) => l.description.trim().isEmpty)) {
      setState(() => _error = 'أضف سطراً واحداً على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'vendor_id': _vendorId,
      'order_date': _orderDate.toIso8601String().substring(0, 10),
      if (_expectedDate != null)
        'expected_delivery_date':
            _expectedDate!.toIso8601String().substring(0, 10),
      if (_warehouseId != null) 'destination_warehouse_id': _warehouseId,
      'payment_terms': _terms,
      if (_notes.text.trim().isNotEmpty)
        'notes_to_vendor': _notes.text.trim(),
      'lines': _lines
          .where((l) => l.description.trim().isNotEmpty)
          .map((l) => {
                if (l.variantId != null) 'variant_id': l.variantId,
                if (l.sku != null) 'sku': l.sku,
                'description': l.description,
                'qty_ordered': l.qty.toString(),
                'unit_price': l.unitPrice.toString(),
                'vat_rate_pct': l.vatRate.toString(),
              })
          .toList(),
    };
    final r = await pilotClient.createPurchaseOrder(body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء أمر الشراء ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: const Row(children: [
          Icon(Icons.receipt_long, color: _gold),
          SizedBox(width: 8),
          Text('أمر شراء جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 780,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: _dd<String?>(
                        'المورد *',
                        _vendorId,
                        [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('— اختر —')),
                          ...widget.vendors.map((v) => DropdownMenuItem<String?>(
                              value: v['id'] as String,
                              child: Text(
                                  '${v['code']} — ${v['legal_name_ar']}',
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        (v) => setState(() => _vendorId = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _datePicker('تاريخ الأمر', _orderDate, false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _datePicker(
                        'تاريخ التسليم المتوقع', _expectedDate, true),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _dd<String?>(
                        'مستودع الوجهة',
                        _warehouseId,
                        [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('— بدون تحديد —')),
                          ...widget.warehouses.map((w) => DropdownMenuItem<String?>(
                              value: w['id'] as String,
                              child: Text('${w['code']} — ${w['name_ar']}',
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        (v) => setState(() => _warehouseId = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dd<String>(
                        'شروط الدفع',
                        _terms,
                        const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                          DropdownMenuItem(
                              value: 'net_0', child: Text('حال الدفع')),
                          DropdownMenuItem(
                              value: 'net_15', child: Text('15 يوم')),
                          DropdownMenuItem(
                              value: 'net_30', child: Text('30 يوم')),
                          DropdownMenuItem(
                              value: 'net_45', child: Text('45 يوم')),
                          DropdownMenuItem(
                              value: 'net_60', child: Text('60 يوم')),
                          DropdownMenuItem(
                              value: 'net_90', child: Text('90 يوم')),
                        ],
                        (v) => setState(() => _terms = v!)),
                  ),
                ]),
                const SizedBox(height: 14),
                // Lines
                Row(children: [
                  const Icon(Icons.list, color: _gold, size: 16),
                  const SizedBox(width: 6),
                  const Text('السطور',
                      style: TextStyle(
                          color: _tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _gold),
                    onPressed: () => setState(() => _lines.add(_PoLine())),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('سطر جديد'),
                  ),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(children: const [
                    SizedBox(width: 40, child: Text('#', style: _th)),
                    Expanded(flex: 3, child: Text('الوصف', style: _th)),
                    SizedBox(width: 70, child: Text('الكمية', style: _th)),
                    SizedBox(width: 80, child: Text('السعر', style: _th)),
                    SizedBox(width: 60, child: Text('VAT%', style: _th)),
                    SizedBox(
                        width: 80,
                        child: Text('الإجمالي',
                            style: _th, textAlign: TextAlign.end)),
                    SizedBox(width: 30, child: Text('', style: _th)),
                  ]),
                ),
                ..._lines.asMap().entries.map((e) => _lineRow(e.key, e.value)),
                const SizedBox(height: 12),
                // Totals
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Expanded(
                        child:
                            _totalCell('المجموع', _subtotal, _tp)),
                    Expanded(child: _totalCell('VAT', _vat, _warn)),
                    Expanded(
                        child: _totalCell(
                            'الإجمالي النهائي', _total, _gold, big: true)),
                  ]),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  style: const TextStyle(color: _tp, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات للمورد',
                    labelStyle: const TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _bdr)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _err.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: _err, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: _err, fontSize: 12))),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(int i, _PoLine l) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: _navy3.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _bdr)),
      child: Row(children: [
        SizedBox(
            width: 40,
            child: Text('${i + 1}',
                style: const TextStyle(color: _ts, fontSize: 11))),
        Expanded(
          flex: 3,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: l.description)
                  ..selection = TextSelection.collapsed(
                      offset: l.description.length),
                onChanged: (v) => l.description = v,
                style: const TextStyle(color: _tp, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'الوصف',
                  hintStyle: TextStyle(color: _td),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: 'اختيار صنف',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.search, color: _gold, size: 14),
              onPressed: () => _pickVariant(i),
            ),
          ]),
        ),
        SizedBox(
          width: 70,
          child: TextField(
            controller: TextEditingController(text: '${l.qty}'),
            keyboardType: TextInputType.number,
            onChanged: (v) => l.qty = double.tryParse(v) ?? 0,
            style: const TextStyle(
                color: _tp, fontSize: 11, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: InputBorder.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            controller: TextEditingController(text: '${l.unitPrice}'),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => l.unitPrice = double.tryParse(v) ?? 0),
            style: const TextStyle(
                color: _tp, fontSize: 11, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: InputBorder.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 60,
          child: TextField(
            controller: TextEditingController(text: '${l.vatRate}'),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => l.vatRate = double.tryParse(v) ?? 15),
            style: const TextStyle(
                color: _tp, fontSize: 11, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: InputBorder.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
              (l.qty * l.unitPrice * (1 + l.vatRate / 100))
                  .toStringAsFixed(2),
              style: const TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete, color: _err, size: 14),
            onPressed: _lines.length > 1
                ? () => setState(() => _lines.removeAt(i))
                : null,
          ),
        ),
      ]),
    );
  }

  Widget _totalCell(String label, double value, Color color,
      {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value.toStringAsFixed(2),
            style: TextStyle(
                color: color,
                fontSize: big ? 16 : 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
      ],
    );
  }

  Widget _datePicker(String label, DateTime? date, bool expected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pickDate(expected),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: _td, size: 14),
              const SizedBox(width: 6),
              Text(
                date == null
                    ? '—'
                    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                    color: date == null ? _td : _tp,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _dd<T>(String label, T value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _navy2,
              style: const TextStyle(color: _tp, fontSize: 12),
              icon: const Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// GRN Dialog
// ══════════════════════════════════════════════════════════════════════════

class _GrnDialog extends StatefulWidget {
  final Map<String, dynamic> poDetail;
  final List<Map<String, dynamic>> warehouses;
  const _GrnDialog({required this.poDetail, required this.warehouses});
  @override
  State<_GrnDialog> createState() => _GrnDialogState();
}

class _GrnDialogState extends State<_GrnDialog> {
  String? _warehouseId;
  DateTime _receivedAt = DateTime.now();
  final _deliveryNote = TextEditingController();
  final _notes = TextEditingController();
  late Map<String, TextEditingController> _qtyCtrls;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final lines = (widget.poDetail['lines'] as List?) ?? [];
    _qtyCtrls = {
      for (final l in lines)
        l['id'] as String: TextEditingController(
            text: asDouble(l['qty_ordered']).toStringAsFixed(2))
    };
    _warehouseId = widget.poDetail['destination_warehouse_id'] ??
        (widget.warehouses.isNotEmpty ? widget.warehouses.first['id'] : null);
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    _deliveryNote.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_warehouseId == null) {
      setState(() => _error = 'اختر المستودع');
      return;
    }
    final lines = (widget.poDetail['lines'] as List?) ?? [];
    final glines = <Map<String, dynamic>>[];
    for (final l in lines) {
      final q = double.tryParse(_qtyCtrls[l['id']]?.text ?? '') ?? 0;
      if (q > 0) {
        glines.add({
          'po_line_id': l['id'],
          'qty_received': q.toString(),
        });
      }
    }
    if (glines.isEmpty) {
      setState(() => _error = 'أدخل كمية مستلمة واحدة على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'po_id': widget.poDetail['id'],
      'warehouse_id': _warehouseId,
      'received_at': _receivedAt.toIso8601String().substring(0, 10),
      if (_deliveryNote.text.trim().isNotEmpty)
        'delivery_note_number': _deliveryNote.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      'lines': glines,
    };
    final r = await pilotClient.createGoodsReceipt(body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok,
          content: Text('تم استلام البضاعة وتحديث المخزون ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الاستلام');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = (widget.poDetail['lines'] as List?) ?? [];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          const Icon(Icons.call_received, color: _gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'استلام بضاعة — ${widget.poDetail['po_number'] ?? ""}',
                style: const TextStyle(color: _tp)),
          ),
        ]),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المستودع *',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                              color: _navy3,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _bdr)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _warehouseId,
                              isExpanded: true,
                              dropdownColor: _navy2,
                              style: const TextStyle(
                                  color: _tp, fontSize: 12),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: _ts),
                              items: widget.warehouses
                                  .map((w) => DropdownMenuItem(
                                      value: w['id'] as String,
                                      child: Text(
                                          '${w['code']} — ${w['name_ar']}',
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _warehouseId = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تاريخ الاستلام',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _receivedAt,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 90)),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) {
                              setState(() => _receivedAt = d);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                                color: _navy3,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _bdr)),
                            child: Row(children: [
                              const Icon(Icons.calendar_today,
                                  color: _td, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_receivedAt.year}-${_receivedAt.month.toString().padLeft(2, '0')}-${_receivedAt.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: _tp,
                                    fontSize: 12,
                                    fontFamily: 'monospace'),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _deliveryNote,
                  style: const TextStyle(
                      color: _tp, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'رقم بوليصة التسليم',
                    labelStyle: const TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _bdr)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('السطور:',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(children: const [
                    Expanded(flex: 3, child: Text('الوصف', style: _th)),
                    SizedBox(width: 80, child: Text('مطلوب', style: _th)),
                    SizedBox(width: 80, child: Text('مُستلَم', style: _th)),
                    SizedBox(width: 100, child: Text('المستلم الآن *', style: _th)),
                  ]),
                ),
                ...lines.map((l) {
                  final ordered = asDouble(l['qty_ordered']);
                  final received = asDouble(l['qty_received']);
                  final remaining = ordered - received;
                  return Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                        color: _navy3.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _bdr)),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Text(l['description'] ?? '',
                            style:
                                const TextStyle(color: _tp, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(ordered.toStringAsFixed(2),
                            style: const TextStyle(
                                color: _ts,
                                fontSize: 11,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.center),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(received.toStringAsFixed(2),
                            style: TextStyle(
                                color: received > 0 ? _warn : _td,
                                fontSize: 11,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.center),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _qtyCtrls[l['id']]
                            ?..text = remaining.toStringAsFixed(2),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              color: _gold,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: _navy2,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: _bdr)),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  style: const TextStyle(color: _tp, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    labelStyle: const TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _bdr)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: _err, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('استلام'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PI Dialog (simplified — uses same _PoLine model)
// ══════════════════════════════════════════════════════════════════════════

class _PiDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vendors;
  final List<Map<String, dynamic>> products;
  final Future<List<Map<String, dynamic>>> Function(String) variantsLoader;
  const _PiDialog(
      {required this.vendors,
      required this.products,
      required this.variantsLoader});
  @override
  State<_PiDialog> createState() => _PiDialogState();
}

class _PiDialogState extends State<_PiDialog> {
  String? _vendorId;
  DateTime _invoiceDate = DateTime.now();
  final _vendorInvNum = TextEditingController();
  final _shipping = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final List<_PoLine> _lines = [_PoLine()];
  bool _loading = false;
  String? _error;
  // ترحيل مباشر للـ GL بعد الإنشاء (بدون زر post منفصل) — افتراضي true
  // حتى يظهر المستحق للمورد + VAT في القوائم المالية فوراً.
  bool _autoPost = true;

  @override
  void dispose() {
    for (final c in [_vendorInvNum, _shipping, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (t, l) => t + l.qty * l.unitPrice);
  double get _vat =>
      _lines.fold(0.0, (t, l) => t + (l.qty * l.unitPrice) * (l.vatRate / 100));
  double get _total =>
      _subtotal + _vat + (double.tryParse(_shipping.text) ?? 0);

  Future<void> _submit() async {
    if (_vendorId == null) {
      setState(() => _error = 'اختر المورد');
      return;
    }
    if (_lines.isEmpty || _lines.every((l) => l.description.trim().isEmpty)) {
      setState(() => _error = 'أضف سطراً واحداً على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'vendor_id': _vendorId,
      'invoice_date': _invoiceDate.toIso8601String().substring(0, 10),
      if (_vendorInvNum.text.trim().isNotEmpty)
        'vendor_invoice_number': _vendorInvNum.text.trim(),
      'shipping':
          (double.tryParse(_shipping.text.trim()) ?? 0).toString(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      'lines': _lines
          .where((l) => l.description.trim().isNotEmpty)
          .map((l) => {
                if (l.variantId != null) 'variant_id': l.variantId,
                if (l.sku != null) 'sku': l.sku,
                'description': l.description,
                'qty': l.qty.toString(),
                'unit_cost': l.unitPrice.toString(),
                'vat_rate_pct': l.vatRate.toString(),
              })
          .toList(),
    };
    final r = await pilotClient.createPurchaseInvoice(body);
    if (!mounted) return;
    if (r.success) {
      final piId = (r.data as Map)['id'];
      // ترحيل فوري إذا auto_post مُفعَّل — تسجيل JE تلقائياً
      if (_autoPost && piId != null) {
        final postR = await pilotClient.postPurchaseInvoice(piId);
        if (!mounted) return;
        if (!postR.success) {
          // الفاتورة أُنشئت لكن الترحيل فشل — نخبر المستخدم بوضوح
          setState(() {
            _loading = false;
            _error = 'أُنشئت الفاتورة لكن فشل الترحيل: ${postR.error}';
          });
          return;
        }
      }
      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok,
          content: Text(_autoPost
              ? 'تم إنشاء الفاتورة وترحيلها إلى GL ✓ (ستظهر في التقارير)'
              : 'تم إنشاء الفاتورة كمسودّة — اضغط ✓ للترحيل لاحقاً')));
    } else {
      setState(() => _loading = false);
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: const Row(children: [
          Icon(Icons.receipt, color: _gold),
          SizedBox(width: 8),
          Text('فاتورة شراء جديدة', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 720,
          height: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المورد *',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                              color: _navy3,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _bdr)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _vendorId,
                              isExpanded: true,
                              dropdownColor: _navy2,
                              style: const TextStyle(
                                  color: _tp, fontSize: 12),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: _ts),
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('— اختر —')),
                                ...widget.vendors.map((v) =>
                                    DropdownMenuItem<String?>(
                                        value: v['id'] as String,
                                        child: Text(
                                            '${v['code']} — ${v['legal_name_ar']}',
                                            overflow:
                                                TextOverflow.ellipsis))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _vendorId = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تاريخ الفاتورة',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _invoiceDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) {
                              setState(() => _invoiceDate = d);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                                color: _navy3,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _bdr)),
                            child: Row(children: [
                              const Icon(Icons.calendar_today,
                                  color: _td, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: _tp,
                                    fontSize: 12,
                                    fontFamily: 'monospace'),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('رقم فاتورة المورد',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _vendorInvNum,
                          style: const TextStyle(
                              color: _tp,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: _navy3,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: _bdr)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Lines (reuse PoLine row logic — simplified)
                Row(children: [
                  const Icon(Icons.list, color: _gold, size: 16),
                  const SizedBox(width: 6),
                  const Text('السطور',
                      style: TextStyle(
                          color: _tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _gold),
                    onPressed: () => setState(() => _lines.add(_PoLine())),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('سطر جديد'),
                  ),
                ]),
                ..._lines.asMap().entries.map((e) {
                  final i = e.key;
                  final l = e.value;
                  return Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                        color: _navy3.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _bdr)),
                    child: Row(children: [
                      SizedBox(
                          width: 30,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: _ts, fontSize: 11))),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          onChanged: (v) => l.description = v,
                          style: const TextStyle(color: _tp, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'الوصف',
                            hintStyle: TextStyle(color: _td),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              setState(() => l.qty = double.tryParse(v) ?? 0),
                          style: const TextStyle(
                              color: _tp,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'كمية',
                            hintStyle: TextStyle(color: _td),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(
                              () => l.unitPrice = double.tryParse(v) ?? 0),
                          style: const TextStyle(
                              color: _tp,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'تكلفة',
                            hintStyle: TextStyle(color: _td),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: TextEditingController(text: '${l.vatRate}'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() =>
                              l.vatRate = double.tryParse(v) ?? 15),
                          style: const TextStyle(
                              color: _tp,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'VAT%',
                            hintStyle: TextStyle(color: _td),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                            (l.qty * l.unitPrice * (1 + l.vatRate / 100))
                                .toStringAsFixed(2),
                            style: const TextStyle(
                                color: _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end),
                      ),
                      SizedBox(
                        width: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete,
                              color: _err, size: 14),
                          onPressed: _lines.length > 1
                              ? () => setState(() => _lines.removeAt(i))
                              : null,
                        ),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الشحن',
                          style: TextStyle(color: _td, fontSize: 11)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _shipping,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            color: _tp,
                            fontSize: 12,
                            fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: _navy3,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: _bdr)),
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('المجموع',
                                  style: TextStyle(
                                      color: _td, fontSize: 10)),
                              Text(_subtotal.toStringAsFixed(2),
                                  style: const TextStyle(
                                      color: _tp,
                                      fontSize: 13,
                                      fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('VAT',
                                  style: TextStyle(
                                      color: _td, fontSize: 10)),
                              Text(_vat.toStringAsFixed(2),
                                  style: const TextStyle(
                                      color: _warn,
                                      fontSize: 13,
                                      fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الإجمالي',
                                  style: TextStyle(
                                      color: _td, fontSize: 10)),
                              Text(_total.toStringAsFixed(2),
                                  style: const TextStyle(
                                      color: _gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Banner auto_post — مطابق لنمط JE Builder
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _autoPost
                        ? _ok.withValues(alpha: 0.08)
                        : _warn.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: (_autoPost ? _ok : _warn).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Checkbox(
                      value: _autoPost,
                      onChanged: (v) => setState(() => _autoPost = v ?? false),
                      checkColor: Colors.black,
                      fillColor: WidgetStateProperty.resolveWith<Color?>((s) =>
                          s.contains(WidgetState.selected) ? _gold : _navy3),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _autoPost
                                  ? '✓ ترحيل مباشر إلى GL'
                                  : '⚠ حفظ كمسودّة فقط',
                              style: TextStyle(
                                  color: _autoPost ? _ok : _warn,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              _autoPost
                                  ? 'مدين: مصروفات/مخزون + VAT مدخلات. دائن: ذمم الموردين. تظهر في التقارير فوراً.'
                                  : 'الفاتورة لن تؤثر على الحسابات حتى تضغط ✓ يدوياً من قائمة الفواتير.',
                              style: const TextStyle(
                                  color: _ts, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: _err, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_autoPost ? 'إنشاء + ترحيل' : 'إنشاء (مسودّة)'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Payment Dialog
// ══════════════════════════════════════════════════════════════════════════

class _PaymentDialog extends StatefulWidget {
  final String vendorId;
  final Map<String, dynamic>? invoice;
  const _PaymentDialog({required this.vendorId, this.invoice});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amount;
  final _refNumber = TextEditingController();
  final _notes = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _method = 'bank_transfer';
  String _paidFromAccount = '1120'; // bank by default
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final due = widget.invoice == null
        ? '0'
        : (asDouble(widget.invoice!['amount_due']).toStringAsFixed(2));
    _amount = TextEditingController(text: due);
  }

  @override
  void dispose() {
    _amount.dispose();
    _refNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'أدخل مبلغاً موجباً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'vendor_id': widget.vendorId,
      'amount': amt.toString(),
      'payment_date':
          _paymentDate.toIso8601String().substring(0, 10),
      'method': _method,
      if (widget.invoice != null) 'invoice_id': widget.invoice!['id'],
      'paid_from_account_code': _paidFromAccount,
      if (_refNumber.text.trim().isNotEmpty)
        'reference_number': _refNumber.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };
    final r = await pilotClient.createVendorPayment(body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم تسجيل الدفعة ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final invLabel = widget.invoice == null
        ? 'دفعة مستقلة'
        : 'ضد فاتورة ${widget.invoice!['invoice_number'] ?? ""}';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          const Icon(Icons.payments, color: _gold),
          const SizedBox(width: 8),
          Expanded(
              child: Text('دفعة — $invLabel',
                  style: const TextStyle(color: _tp))),
        ]),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المبلغ *',
                        style: TextStyle(color: _td, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: _navy3,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: _bdr)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('التاريخ',
                        style: TextStyle(color: _td, fontSize: 11)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 90)),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _paymentDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                            color: _navy3,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _bdr)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today,
                              color: _td, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${_paymentDate.year}-${_paymentDate.month.toString().padLeft(2, '0')}-${_paymentDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: _tp,
                                fontSize: 12,
                                fontFamily: 'monospace'),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('طريقة الدفع',
                        style: TextStyle(color: _td, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: _navy3,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _bdr)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _method,
                          isExpanded: true,
                          dropdownColor: _navy2,
                          style: const TextStyle(color: _tp, fontSize: 12),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: _ts),
                          items: _kPaymentMethods.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _method = v!;
                              _paidFromAccount =
                                  v == 'cash' ? '1110' : '1120';
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('من حساب',
                        style: TextStyle(color: _td, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: _navy3,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _bdr)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paidFromAccount,
                          isExpanded: true,
                          dropdownColor: _navy2,
                          style: const TextStyle(color: _tp, fontSize: 12),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: _ts),
                          items: const [
                            DropdownMenuItem(
                                value: '1110',
                                child: Text('1110 — النقدية')),
                            DropdownMenuItem(
                                value: '1120', child: Text('1120 — البنك')),
                          ],
                          onChanged: (v) => setState(() =>
                              _paidFromAccount = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _refNumber,
              style: const TextStyle(
                  color: _tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'رقم المرجع (شيك/تحويل)',
                labelStyle: const TextStyle(color: _td),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _bdr)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              style: const TextStyle(color: _tp, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'ملاحظات',
                labelStyle: const TextStyle(color: _td),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _bdr)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: _err, fontSize: 12)),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تسجيل'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Shared Detail Dialog
// ══════════════════════════════════════════════════════════════════════════

class _DetailDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, dynamic> data;
  final String Function(String?) vendorName;
  const _DetailDialog({
    required this.title,
    required this.icon,
    required this.data,
    required this.vendorName,
  });

  @override
  Widget build(BuildContext context) {
    final lines = (data['lines'] as List?) ?? [];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Icon(icon, color: _gold),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: _tp)),
          const Spacer(),
          Text(
              data['po_number'] ??
                  data['invoice_number'] ??
                  data['grn_number'] ??
                  '',
              style: const TextStyle(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
        ]),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: _kv('المورد', vendorName(data['vendor_id']))),
                  Expanded(
                      child: _kv('التاريخ',
                          data['order_date'] ?? data['invoice_date'] ?? '—')),
                  Expanded(
                      child: _kv('العملة', data['currency'] ?? 'SAR')),
                ]),
                Row(children: [
                  Expanded(
                      child: _kv('الحالة', data['status'] ?? '—')),
                  Expanded(
                      child: _kv(
                          'المجموع',
                          (data['subtotal'] ?? 0).toString(),
                          mono: true)),
                  Expanded(
                      child: _kv(
                          'VAT',
                          (data['vat_total'] ?? 0).toString(),
                          mono: true)),
                  Expanded(
                      child: _kv(
                          'الإجمالي',
                          (data['grand_total'] ?? 0).toString(),
                          mono: true,
                          bold: true)),
                ]),
                const SizedBox(height: 12),
                const Text('السطور:',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...lines.map((l) => Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _navy3,
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(children: [
                        SizedBox(
                            width: 30,
                            child: Text('${l['line_number']}',
                                style: const TextStyle(
                                    color: _ts, fontSize: 11))),
                        Expanded(
                          flex: 3,
                          child: Text(l['description'] ?? '',
                              style: const TextStyle(
                                  color: _tp, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                              (l['qty_ordered'] ?? l['qty'] ?? 0).toString(),
                              style: const TextStyle(
                                  color: _ts,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                              (l['unit_price'] ?? l['unit_cost'] ?? 0)
                                  .toString(),
                              style: const TextStyle(
                                  color: _tp,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                              (l['line_total'] ?? 0).toString(),
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace'),
                              textAlign: TextAlign.end),
                        ),
                      ]),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _kv(String k, String v,
      {bool mono = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: _td, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: bold ? _gold : _tp,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
