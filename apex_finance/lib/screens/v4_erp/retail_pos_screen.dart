/// Retail POS — شاشة نقاط بيع تجزئة حيّة بالكامل.
///
/// ذاتية الاكتفاء (بدون bridge) — تقرأ tenant/entity/branch من localStorage
/// عبر PilotSession وتعمل مع الباك-إند مباشرة.
///
/// المميزات:
///   - شبكة أصناف مُقسَّمة حسب التصنيف (تصفية + بحث)
///   - نقرة على صنف → إضافة للسلة مع اختيار الكمية
///   - تعديل الكمية والخصم لكل بند
///   - ماسح باركود (للدعم الحقيقي للـ USB scanner)
///   - شريط إجمالي مباشر (subtotal + VAT + total)
///   - زر دفع → حوار اختيار طريقة الدفع (نقد/مدى/بطاقة/تقسيم)
///   - بعد الدفع: ترحيل GL + ZATCA QR تلقائياً
///   - إدارة الوردية (فتح/إقفال مع Z-report)

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../pilot/api/pilot_client.dart';
import '../../pilot/session.dart';

class RetailPosScreen extends StatefulWidget {
  const RetailPosScreen({super.key});
  @override
  State<RetailPosScreen> createState() => _RetailPosScreenState();
}

// ═══════════════════════════════════════════════════════════════════
// Model
// ═══════════════════════════════════════════════════════════════════

class _Variant {
  final String id;
  final String sku;
  final String productNameAr;
  final String? productNameEn;
  final String? category;
  final double listPrice;
  final String currency;
  final IconData icon;
  final double onHand;
  final List<String> barcodes;

  _Variant({
    required this.id,
    required this.sku,
    required this.productNameAr,
    this.productNameEn,
    this.category,
    required this.listPrice,
    required this.currency,
    required this.icon,
    required this.onHand,
    required this.barcodes,
  });
}

class _CartLine {
  final _Variant variant;
  int qty;
  double unitPrice;
  double discountPct;
  String? promoBadge;

  _CartLine({
    required this.variant,
    this.qty = 1,
    required this.unitPrice,
    this.discountPct = 0,
    this.promoBadge,
  });

  double get subtotal => qty * unitPrice;
  double get discountAmount => subtotal * discountPct / 100;
  double get taxable => subtotal - discountAmount;
  double get vat => taxable * 15 / 115; // prices include VAT
  double get total => taxable;
}

// ═══════════════════════════════════════════════════════════════════
// Theme colors (independent of AC)
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════════

class _RetailPosScreenState extends State<RetailPosScreen> {
  final PilotClient _client = pilotClient;
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _searchCtrl = TextEditingController();

  // data
  List<_Variant> _allVariants = [];
  List<String> _categories = ['الكل'];
  String _selectedCategory = 'الكل';
  String _search = '';

  // cart
  final List<_CartLine> _cart = [];

  // session
  Map<String, dynamic>? _activeSession;
  Map<String, dynamic>? _entityInfo;
  Map<String, dynamic>? _branchInfo;
  String? _warehouseId;
  String _currency = 'SAR';

  // ui state
  bool _loading = true;
  String? _error;
  String? _lastReceipt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════
  // Bootstrap
  // ═════════════════════════════════════════════════════════════

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!PilotSession.hasTenant) {
      setState(() {
        _loading = false;
        _error = 'لم يتم تحديد الشركة. الرجاء الذهاب إلى رحلة الإعداد أولاً.';
      });
      return;
    }

    try {
      // 1. load entity info
      if (PilotSession.hasEntity) {
        final e = await _client.getEntity(PilotSession.entityId!);
        if (e.success) {
          _entityInfo = Map<String, dynamic>.from(e.data);
          _currency = _entityInfo!['functional_currency'] ?? 'SAR';
        }
      }

      // 2. load/pick branch
      if (!PilotSession.hasBranch && PilotSession.hasEntity) {
        final b = await _client.listBranches(PilotSession.entityId!);
        if (b.success && (b.data as List).isNotEmpty) {
          final first = (b.data as List).first;
          PilotSession.branchId = first['id'];
        }
      }
      if (PilotSession.hasBranch) {
        final b = await _client.getBranch(PilotSession.branchId!);
        if (b.success) _branchInfo = Map<String, dynamic>.from(b.data);

        // load default warehouse
        final whs = await _client.listWarehouses(PilotSession.branchId!);
        if (whs.success && (whs.data as List).isNotEmpty) {
          final List list = whs.data;
          final def = list.firstWhere((w) => w['is_default'] == true,
              orElse: () => list.first);
          _warehouseId = def['id'];
        }
      }

      // 3. load products + variants
      await _loadProducts();

      // 4. check for open session
      if (PilotSession.hasBranch) {
        final s = await _client.listPosSessions(PilotSession.branchId!,
            status: 'open');
        if (s.success && (s.data as List).isNotEmpty) {
          _activeSession = Map<String, dynamic>.from((s.data as List).first);
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'خطأ تحميل: $e';
      });
    }
  }

  Future<void> _loadProducts() async {
    final r =
        await _client.listProducts(PilotSession.tenantId!, status: 'active', limit: 500);
    if (!r.success) return;
    final List products = r.data;

    final List<_Variant> out = [];
    final Set<String> cats = {'الكل'};

    // collect category names
    final categoryMap = <String, String>{};
    final catR =
        await _client.listCategories(PilotSession.tenantId!, includeInactive: true);
    if (catR.success) {
      for (final c in catR.data as List) {
        categoryMap[c['id']] = c['name_ar'] as String;
      }
    }

    // for each product, fetch its variants
    for (final p in products) {
      final catName =
          p['category_id'] != null ? categoryMap[p['category_id']] : null;
      if (catName != null) cats.add(catName);

      final vR = await _client.listVariants(p['id']);
      if (!vR.success) continue;
      for (final v in vR.data as List) {
        // skip inactive
        if (v['is_active'] != true) continue;

        final bR = await _client.listBarcodes(v['id']);
        final barcodes = bR.success
            ? (bR.data as List).map((b) => b['value'] as String).toList()
            : <String>[];

        out.add(_Variant(
          id: v['id'] as String,
          sku: v['sku'] as String,
          productNameAr: p['name_ar'] ?? v['sku'],
          productNameEn: p['name_en'],
          category: catName,
          listPrice: double.tryParse('${v['list_price'] ?? 0}') ?? 0,
          currency: v['currency'] ?? _currency,
          icon: _iconFor(catName),
          onHand: double.tryParse('${v['total_on_hand'] ?? 0}') ?? 0,
          barcodes: barcodes,
        ));
      }
    }

    setState(() {
      _allVariants = out;
      _categories = cats.toList();
    });
  }

  IconData _iconFor(String? cat) {
    final c = (cat ?? '').toLowerCase();
    if (c.contains('قميص') || c.contains('shirt')) return Icons.checkroom;
    if (c.contains('حذاء') || c.contains('shoe')) return Icons.directions_run;
    if (c.contains('حقيب') || c.contains('bag')) return Icons.work;
    if (c.contains('عطر') || c.contains('perfume')) return Icons.spa;
    if (c.contains('إلكترون') || c.contains('electron')) return Icons.devices;
    if (c.contains('أثاث') || c.contains('furniture')) return Icons.chair;
    return Icons.inventory_2;
  }

  List<_Variant> get _filteredVariants {
    var list = _allVariants;
    if (_selectedCategory != 'الكل') {
      list = list.where((v) => v.category == _selectedCategory).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((v) {
        return v.sku.toLowerCase().contains(q) ||
            v.productNameAr.contains(_search) ||
            (v.productNameEn?.toLowerCase().contains(q) ?? false) ||
            v.barcodes.any((b) => b.contains(q));
      }).toList();
    }
    return list;
  }

  // ═════════════════════════════════════════════════════════════
  // Session
  // ═════════════════════════════════════════════════════════════

  Future<void> _openSession() async {
    if (_warehouseId == null || PilotSession.branchId == null) return;
    final openingCtrl = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('فتح وردية جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('أدخل الرصيد الافتتاحي للنقد في الدرج:'),
            const SizedBox(height: 12),
            TextField(
              controller: openingCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments), hintText: '0.00'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('فتح')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final r = await _client.openPosSession(PilotSession.branchId!, {
      'branch_id': PilotSession.branchId,
      'warehouse_id': _warehouseId,
      'opened_by_user_id': 'cashier-web',
      'opening_cash': openingCtrl.text.trim().isEmpty
          ? '0'
          : openingCtrl.text.trim(),
      'station_id': 'WEB-POS',
    });
    if (r.success) {
      setState(() => _activeSession = Map<String, dynamic>.from(r.data));
      _showMsg('تم فتح الوردية: ${r.data['code']}', _ok);
    } else {
      _showMsg(r.error ?? 'فشل', _err);
    }
  }

  Future<void> _closeSession() async {
    if (_activeSession == null) return;
    final countCtrl = TextEditingController();
    final r = await showDialog<String?>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إقفال الوردية'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('أدخل العدّ الفعلي للنقد:'),
            const SizedBox(height: 12),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments), hintText: '0.00'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, countCtrl.text.trim()),
                child: const Text('إقفال')),
          ],
        ),
      ),
    );
    if (r == null) return;

    final res = await _client.closePosSession(_activeSession!['id'], {
      'closed_by_user_id': 'cashier-web',
      'closing_cash': r.isEmpty ? '0' : r,
    });
    if (res.success) {
      _showZReport(res.data as Map);
      setState(() => _activeSession = null);
    } else {
      _showMsg(res.error ?? 'فشل', _err);
    }
  }

  void _showZReport(Map zr) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('Z-Report'),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _zrRow('المتوقّع', '${zr['expected_cash']}'),
                _zrRow('المُحسّى', '${zr['closing_cash']}'),
                _zrRow('الفرق', '${zr['variance']}'),
                _zrRow('المعاملات', '${zr['transaction_count']}'),
                _zrRow('إجمالي المبيعات', '${zr['total_sales_gross']}'),
                _zrRow('VAT', '${zr['total_vat']}'),
                _zrRow('الصافي', '${zr['total_net']}'),
              ]),
          actions: [
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تم')),
          ],
        ),
      ),
    );
  }

  Widget _zrRow(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 120, child: Text(k)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]));

  // ═════════════════════════════════════════════════════════════
  // Cart
  // ═════════════════════════════════════════════════════════════

  void _addToCart(_Variant v) {
    setState(() {
      final existing = _cart.indexWhere((l) => l.variant.id == v.id);
      if (existing >= 0) {
        _cart[existing].qty++;
      } else {
        _cart.add(_CartLine(variant: v, unitPrice: v.listPrice));
      }
    });
  }

  Future<void> _scanBarcode(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;
    // try local match first
    final local = _allVariants.firstWhere(
      (v) => v.barcodes.contains(code),
      orElse: () =>
          _allVariants.firstWhere((v) => v.sku == code, orElse: () => _empty),
    );
    if (local != _empty) {
      _addToCart(local);
    } else {
      // call API
      final r = await _client.scanBarcode(PilotSession.tenantId!, code);
      if (r.success) {
        final body = r.data as Map;
        final vId = body['variant']['id'];
        final match = _allVariants.firstWhere((v) => v.id == vId,
            orElse: () => _empty);
        if (match != _empty) _addToCart(match);
      } else {
        _showMsg('باركود غير موجود: $code', _err);
      }
    }
    _barcodeCtrl.clear();
    _barcodeFocus.requestFocus();
  }

  final _Variant _empty = _Variant(
      id: '',
      sku: '',
      productNameAr: '',
      listPrice: 0,
      currency: 'SAR',
      icon: Icons.error,
      onHand: 0,
      barcodes: []);

  double get _subtotal => _cart.fold(0, (s, l) => s + l.subtotal);
  double get _discount => _cart.fold(0, (s, l) => s + l.discountAmount);
  double get _taxable => _subtotal - _discount;
  double get _vat => _taxable * 15 / 115;
  double get _grandTotal => _taxable;
  int get _itemCount => _cart.fold(0, (s, l) => s + l.qty);

  // ═════════════════════════════════════════════════════════════
  // Payment
  // ═════════════════════════════════════════════════════════════

  /// معالجة مرتجع — يُنشأ PosTransaction بنوع 'return'.
  /// الباك اند يعكس الحركة: يُعيد المخزون، ينشئ JE عكسي، يصدر إيصال مرتجع.
  Future<void> _processReturn() async {
    if (_cart.isEmpty || _activeSession == null) return;
    // تأكيد قبل معالجة المرتجع
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Row(children: [
            Icon(Icons.undo, color: _err),
            SizedBox(width: 8),
            Text('تأكيد المرتجع', style: TextStyle(color: _tp)),
          ]),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'هل تريد معالجة مرتجع بقيمة ${_grandTotal.toStringAsFixed(2)} $_currency؟',
                    style: const TextStyle(color: _tp, fontSize: 14)),
                const SizedBox(height: 10),
                const Text(
                    'سيتم:\n'
                    '• إعادة الأصناف للمخزون\n'
                    '• إنشاء قيد يومية عكسي\n'
                    '• إعادة المبلغ للعميل (نقداً)\n'
                    '• إصدار إيصال مرتجع',
                    style: TextStyle(color: _ts, fontSize: 12, height: 1.6)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _err, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.undo),
              label: const Text('معالجة المرتجع'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final body = {
      'session_id': _activeSession!['id'],
      'kind': 'return',
      'cashier_user_id': 'cashier-web',
      'lines': _cart
          .map((l) => {
                'variant_id': l.variant.id,
                'qty': l.qty.toString(),
                if (l.discountPct > 0)
                  'discount_pct': l.discountPct.toString(),
              })
          .toList(),
      'payments': [
        {'method': 'cash', 'amount': _grandTotal.toString()},
      ],
    };

    final r = await _client.createPosTransaction(body);
    if (!mounted) return;
    if (!r.success) {
      _showMsg(r.error ?? 'فشل المرتجع', _err);
      return;
    }
    final txn = r.data as Map;
    await _client.postPosToGl(txn['id']);

    setState(() {
      _lastReceipt = txn['receipt_number'];
      _cart.clear();
    });
    _showMsg(
        'تم معالجة المرتجع — إيصال ${txn['receipt_number']} ✓',
        _ok);
    await _loadProducts();
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _activeSession == null) return;
    final payments = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentDialog(total: _grandTotal, currency: _currency),
    );
    if (payments == null || payments.isEmpty) return;

    final body = {
      'session_id': _activeSession!['id'],
      'kind': 'sale',
      'cashier_user_id': 'cashier-web',
      'lines': _cart
          .map((l) => {
                'variant_id': l.variant.id,
                'qty': l.qty.toString(),
                if (l.discountPct > 0)
                  'discount_pct': l.discountPct.toString(),
              })
          .toList(),
      'payments': payments,
    };

    final r = await _client.createPosTransaction(body);
    if (!r.success) {
      _showMsg(r.error ?? 'فشل البيع', _err);
      return;
    }
    final txn = r.data as Map;

    // auto-post GL
    await _client.postPosToGl(txn['id']);
    // ZATCA (SA only)
    if (_entityInfo?['country'] == 'SA') {
      await _client.submitPosToZatca(txn['id'], simulate: true);
    }

    setState(() {
      _lastReceipt = txn['receipt_number'];
      _cart.clear();
    });
    _showReceipt(txn);
    await _loadProducts(); // refresh stock
  }

  void _showReceipt(Map txn) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: const [
            Icon(Icons.receipt_long, color: _ok),
            SizedBox(width: 8),
            Text('تم البيع ✓'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _zrRow('رقم الإيصال', txn['receipt_number']),
              _zrRow('الإجمالي', '${txn['grand_total']} ${_currency}'),
              _zrRow('VAT', '${txn['vat_total']}'),
              _zrRow('المستلم', '${txn['tendered_total']}'),
              _zrRow('الباقي', '${txn['change_given']}'),
            ],
          ),
          actions: [
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تم')),
          ],
        ),
      ),
    );
  }

  void _showMsg(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: c,
    ));
  }

  // ═════════════════════════════════════════════════════════════
  // Build
  // ═════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: _navy,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _gold),
              )
            : _error != null
                ? _errorState()
                : Row(children: [
                    // Left (first in RTL): products grid
                    Expanded(flex: 3, child: _productsSide()),
                    Container(width: 1, color: _bdr),
                    // Right: cart + total + payment
                    Expanded(flex: 2, child: _cartSide()),
                  ]),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _navy2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _err.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning, color: _err, size: 64),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _tp, fontSize: 15)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );

  // ── Products side ──────────────────────────────────────────
  Widget _productsSide() => Column(children: [
        _topBar(),
        _categoryStrip(),
        Expanded(child: _productsGrid()),
      ]);

  Widget _topBar() => Container(
        padding: const EdgeInsets.all(10),
        decoration:
            BoxDecoration(color: _navy2, border: Border(bottom: BorderSide(color: _bdr))),
        child: Row(children: [
          // Session status
          if (_activeSession == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: _openSession,
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('فتح وردية'),
            )
          else
            Row(children: [
              const Icon(Icons.lock_open, color: _ok, size: 16),
              const SizedBox(width: 4),
              Text('وردية ${_activeSession!['code']}',
                  style: const TextStyle(color: _tp, fontSize: 12)),
              const SizedBox(width: 6),
              InkWell(
                  onTap: _closeSession,
                  child: Icon(Icons.lock, color: _err, size: 16)),
            ]),
          const SizedBox(width: 16),
          // Barcode scanner
          Expanded(
            child: TextField(
              controller: _barcodeCtrl,
              focusNode: _barcodeFocus,
              style: const TextStyle(color: _tp),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\-]')),
              ],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.qr_code_scanner, color: _gold),
                hintText: 'امسح باركود أو اكتب SKU ثم Enter',
                hintStyle: const TextStyle(color: _td),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _bdr)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _bdr)),
              ),
              onSubmitted: _scanBarcode,
            ),
          ),
          const SizedBox(width: 8),
          // Search
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: _tp),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: _ts, size: 18),
                hintText: 'بحث',
                hintStyle: const TextStyle(color: _td),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _bdr)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _bdr)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ]),
      );

  Widget _categoryStrip() => Container(
        height: 48,
        color: _navy2,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = _categories[i];
            final sel = c == _selectedCategory;
            return InkWell(
              onTap: () => setState(() => _selectedCategory = c),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: sel ? _gold.withValues(alpha: 0.2) : _navy3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _gold : _bdr),
                ),
                child: Text(c,
                    style: TextStyle(
                        color: sel ? _gold : _ts,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          },
        ),
      );

  Widget _productsGrid() {
    final items = _filteredVariants;
    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد أصناف — أضف منتجات من شاشة الأصناف أولاً',
            style: TextStyle(color: _td, fontSize: 14)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _productTile(items[i]),
    );
  }

  Widget _productTile(_Variant v) => InkWell(
        onTap: _activeSession == null ? null : () => _addToCart(v),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _navy2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _navy3,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(v.icon, color: _gold, size: 48),
                ),
              ),
              const SizedBox(height: 8),
              Text(v.productNameAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _tp, fontWeight: FontWeight.w600, fontSize: 13)),
              Text('SKU: ${v.sku}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _td, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Row(children: [
                Text('${v.listPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(width: 4),
                Text(v.currency,
                    style: const TextStyle(color: _gold, fontSize: 10)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: v.onHand > 0
                        ? _ok.withValues(alpha: 0.2)
                        : _err.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(v.onHand > 0 ? '${v.onHand.toStringAsFixed(0)}' : '0',
                      style: TextStyle(
                          color: v.onHand > 0 ? _ok : _err,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ),
      );

  // ── Cart side ──────────────────────────────────────────────
  Widget _cartSide() => Container(
        color: _navy2,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _navy3,
            child: Row(children: [
              const Icon(Icons.shopping_cart, color: _gold, size: 22),
              const SizedBox(width: 8),
              const Text('السلة',
                  style: TextStyle(
                      color: _tp,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_cart.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, color: _err, size: 20),
                  onPressed: () => setState(() => _cart.clear()),
                ),
            ]),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 64, color: _td),
                        SizedBox(height: 12),
                        Text('السلة فارغة',
                            style: TextStyle(color: _td, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('انقر على صنف أو امسح باركود',
                            style: TextStyle(color: _td, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) => _cartLineTile(i),
                  ),
          ),
          _totalsPanel(),
        ]),
      );

  Widget _cartLineTile(int i) {
    final l = _cart[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.variant.productNameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _tp,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(l.variant.sku,
                    style: const TextStyle(
                        color: _td, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _err, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _cart.removeAt(i)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          // qty stepper
          Row(children: [
            InkWell(
              onTap: () => setState(() {
                if (l.qty > 1) {
                  l.qty--;
                } else {
                  _cart.removeAt(i);
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _navy2,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _bdr),
                ),
                child: const Icon(Icons.remove, color: _ts, size: 14),
              ),
            ),
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text('${l.qty}',
                  style: const TextStyle(
                      color: _tp,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
            InkWell(
              onTap: () => setState(() => l.qty++),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _gold),
                ),
                child: const Icon(Icons.add, color: _gold, size: 14),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          // discount
          SizedBox(
            width: 70,
            child: TextField(
              textAlign: TextAlign.center,
              style: const TextStyle(color: _warn, fontSize: 12),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                hintText: 'خصم%',
                hintStyle: const TextStyle(color: _td, fontSize: 11),
                filled: true,
                fillColor: _navy2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: _bdr)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: _bdr)),
              ),
              controller: TextEditingController(
                  text: l.discountPct > 0 ? l.discountPct.toStringAsFixed(0) : ''),
              onChanged: (v) => setState(() =>
                  l.discountPct = double.tryParse(v)?.clamp(0, 100) ?? 0),
            ),
          ),
          const Spacer(),
          Text('${l.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: _gold, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ]),
    );
  }

  Widget _totalsPanel() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _navy3, border: Border(top: BorderSide(color: _bdr))),
        child: Column(children: [
          _totalRow('الإجمالي قبل الضريبة', _taxable, _ts),
          _totalRow('ضريبة (15%)', _vat, _ts),
          if (_discount > 0) _totalRow('الخصم', _discount, _warn),
          const Divider(color: _bdr),
          _totalRow('الإجمالي', _grandTotal, _gold, big: true),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _ok,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _cart.isEmpty || _activeSession == null
                    ? null
                    : _checkout,
                icon: const Icon(Icons.credit_card),
                label: Text(_activeSession == null ? 'افتح وردية أولاً' : 'الدفع',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _err,
                  side: BorderSide(color: _err.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _cart.isEmpty || _activeSession == null
                    ? null
                    : _processReturn,
                icon: const Icon(Icons.undo),
                label: const Text('مرتجع', style: TextStyle(fontSize: 14)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(_itemCount == 0 ? ' ' : '$_itemCount قطعة في ${_cart.length} صنف',
              style: const TextStyle(color: _td, fontSize: 11)),
          if (_lastReceipt != null) ...[
            const SizedBox(height: 4),
            Text('آخر إيصال: $_lastReceipt',
                style: const TextStyle(color: _ok, fontSize: 11)),
          ],
        ]),
      );

  Widget _totalRow(String k, double v, Color c, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(k,
                style: TextStyle(
                    color: c, fontSize: big ? 16 : 13,
                    fontWeight: big ? FontWeight.bold : FontWeight.normal))),
        Text('${v.toStringAsFixed(2)} $_currency',
            style: TextStyle(
                color: c,
                fontSize: big ? 20 : 14,
                fontWeight: big ? FontWeight.bold : FontWeight.w600)),
      ]));
}

// ═══════════════════════════════════════════════════════════════════
// Payment Dialog — multi-tender
// ═══════════════════════════════════════════════════════════════════

class _PaymentDialog extends StatefulWidget {
  final double total;
  final String currency;
  const _PaymentDialog({required this.total, required this.currency});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final List<_PaymentEntry> _payments = [];
  String _method = 'cash';
  final _amountCtrl = TextEditingController();

  static const _methods = [
    ('cash', 'نقد', Icons.payments),
    ('mada', 'مدى', Icons.credit_card),
    ('visa', 'Visa', Icons.credit_card),
    ('mastercard', 'Mastercard', Icons.credit_card),
    ('stc_pay', 'STC Pay', Icons.phone_iphone),
    ('apple_pay', 'Apple Pay', Icons.phone_iphone),
    ('tamara', 'تمارا', Icons.card_giftcard),
    ('tabby', 'تابي', Icons.card_giftcard),
    ('bank_transfer', 'تحويل', Icons.account_balance),
  ];

  double get _paid => _payments.fold(0, (s, p) => s + p.amount);
  double get _remaining => widget.total - _paid;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final done = _paid >= widget.total - 0.01;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Text('الإجمالي المطلوب',
                    style: TextStyle(fontSize: 14)),
                const Spacer(),
                Text('${widget.total.toStringAsFixed(2)} ${widget.currency}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _gold)),
              ]),
            ),
            const SizedBox(height: 16),

            // paid so far
            if (_payments.isNotEmpty) ...[
              ..._payments.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _ok.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Icon(_iconForMethod(e.value.method),
                          color: _ok, size: 16),
                      const SizedBox(width: 6),
                      Text(_nameForMethod(e.value.method)),
                      const Spacer(),
                      Text('${e.value.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: _ok, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: _err, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            setState(() => _payments.removeAt(e.key)),
                      ),
                    ]),
                  )),
              const SizedBox(height: 8),
              Row(children: [
                const Text('المدفوع'),
                const Spacer(),
                Text('${_paid.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: _ok, fontWeight: FontWeight.bold)),
              ]),
              Row(children: [
                const Text('المتبقي'),
                const Spacer(),
                Text('${_remaining.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: _remaining > 0 ? _warn : _ok,
                        fontWeight: FontWeight.bold)),
              ]),
              const Divider(),
            ],

            if (!done) ...[
              // method picker
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _methods
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: () => setState(() => _method = m.$1),
                              child: Container(
                                width: 80,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _method == m.$1
                                      ? _gold.withValues(alpha: 0.15)
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _method == m.$1 ? _gold : _bdr),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(m.$3,
                                        color: _method == m.$1
                                            ? _gold
                                            : Colors.black54,
                                        size: 28),
                                    const SizedBox(height: 4),
                                    Text(m.$2,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _method == m.$1
                                              ? _gold
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              // amount
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  prefixIcon: const Icon(Icons.payments),
                  suffix: Text(widget.currency),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                for (final pct in [0.25, 0.5, 1.0])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          _amountCtrl.text =
                              (_remaining * pct).toStringAsFixed(2);
                          setState(() {});
                        },
                        child: Text(pct == 1
                            ? 'الباقي'
                            : '${(pct * 100).toStringAsFixed(0)}%'),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final amt = double.tryParse(_amountCtrl.text);
                  if (amt == null || amt <= 0) return;
                  setState(() {
                    _payments.add(_PaymentEntry(method: _method, amount: amt));
                    _amountCtrl.text = (_remaining - amt >= 0.01)
                        ? (_remaining - amt).toStringAsFixed(2)
                        : '';
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('إضافة دفعة', style: TextStyle(fontSize: 15)),
              ),
            ],

            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: done ? _ok : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: done
                      ? () => Navigator.pop(
                          context,
                          _payments
                              .map((p) => {
                                    'method': p.method,
                                    'amount': p.amount.toStringAsFixed(2),
                                  })
                              .toList())
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(done ? 'إتمام الدفع ✓' : 'المبلغ غير مكتمل',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  IconData _iconForMethod(String m) {
    for (final (id, _, icon) in _methods) {
      if (id == m) return icon;
    }
    return Icons.payments;
  }

  String _nameForMethod(String m) {
    for (final (id, name, _) in _methods) {
      if (id == m) return name;
    }
    return m;
  }
}

class _PaymentEntry {
  final String method;
  final double amount;
  _PaymentEntry({required this.method, required this.amount});
}
