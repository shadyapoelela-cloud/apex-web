/// Products — إدارة الأصناف (Products + Variants + Barcodes + Categories + Brands).
///
/// مستقلة — تعتمد على PilotSession.tenantId فقط.
///
/// التبويبات:
///   1) الأصناف — قائمة + تفاصيل (variants + barcodes)
///   2) الفئات — إدارة ProductCategory
///   3) العلامات التجارية — إدارة Brand
library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
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

const _kKinds = <String, String>{
  'goods': 'سلعة',
  'service': 'خدمة',
  'composite': 'مركّب',
  'raw': 'خام',
};

const _kVatCodes = <String, String>{
  'standard': 'قياسي (15%)',
  'zero_rated': 'معدّل صفري',
  'exempt': 'معفى',
  'out_of_scope': 'خارج النطاق',
};

const _kStatuses = <String, String>{
  'draft': 'مسودّة',
  'active': 'نشط',
  'discontinued': 'متوقّف',
  'archived': 'مؤرشف',
};

const _kBarcodeTypes = <String, String>{
  'ean13': 'EAN-13',
  'upc_a': 'UPC-A',
  'ean8': 'EAN-8',
  'gtin14': 'GTIN-14',
  'code128': 'Code 128',
  'qr': 'QR',
  'custom': 'مخصّص',
};

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final PilotClient _client = pilotClient;

  // Data
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _barcodes = [];

  String? _selectedProductId;
  String? _selectedVariantId;

  bool _loading = true;
  String? _error;
  String _search = '';
  String _catFilter = 'all';
  String _kindFilter = 'all';
  String _statusFilter = 'active';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasTenant) {
      setState(() {
        _loading = false;
        _error = 'يجب اختيار الشركة من شريط العنوان أولاً.';
      });
      return;
    }
    final tid = PilotSession.tenantId!;
    final results = await Future.wait([
      _client.listProducts(tid, status: _statusFilter == 'all' ? null : _statusFilter),
      _client.listCategories(tid),
      _client.listBrands(tid),
    ]);
    if (!results[0].success) {
      setState(() {
        _loading = false;
        _error = results[0].error ?? 'فشل تحميل الأصناف';
      });
      return;
    }
    setState(() {
      _products = List<Map<String, dynamic>>.from(results[0].data);
      _categories = results[1].success
          ? List<Map<String, dynamic>>.from(results[1].data)
          : [];
      _brands = results[2].success
          ? List<Map<String, dynamic>>.from(results[2].data)
          : [];
      _loading = false;
    });
  }

  Future<void> _loadVariants(String productId) async {
    setState(() {
      _selectedProductId = productId;
      _selectedVariantId = null;
      _variants = [];
      _barcodes = [];
    });
    final r = await _client.listVariants(productId);
    if (r.success) {
      setState(() => _variants = List<Map<String, dynamic>>.from(r.data));
    }
  }

  Future<void> _loadBarcodes(String variantId) async {
    setState(() {
      _selectedVariantId = variantId;
      _barcodes = [];
    });
    final r = await _client.listBarcodes(variantId);
    if (r.success) {
      setState(() => _barcodes = List<Map<String, dynamic>>.from(r.data));
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = _products;
    if (_catFilter != 'all') {
      list = list.where((p) => p['category_id'] == _catFilter).toList();
    }
    if (_kindFilter != 'all') {
      list = list.where((p) => p['kind'] == _kindFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((p) {
        final code = (p['code'] ?? '').toString().toLowerCase();
        final ar = (p['name_ar'] ?? '').toString().toLowerCase();
        final en = (p['name_en'] ?? '').toString().toLowerCase();
        return code.contains(q) || ar.contains(q) || en.contains(q);
      }).toList();
    }
    return list;
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
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(icon: Icon(Icons.inventory_2, size: 16), text: 'الأصناف'),
                Tab(icon: Icon(Icons.category, size: 16), text: 'الفئات'),
                Tab(icon: Icon(Icons.label, size: 16), text: 'العلامات التجارية'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : TabBarView(controller: _tab, children: [
                        _productsTab(),
                        _categoriesTab(),
                        _brandsTab(),
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
        color: _navy2,
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.inventory, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الأصناف والكتالوج',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
                '${_products.length} صنف · ${_categories.length} فئة · ${_brands.length} علامة',
                style: const TextStyle(color: _ts, fontSize: 12)),
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

  Widget _errorView() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: _err, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: _ts)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: const BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('إعادة المحاولة'),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 1: Products
  // ════════════════════════════════════════════════════════════════════

  Widget _productsTab() {
    return Column(children: [
      _productsToolbar(),
      Expanded(
        child: Row(children: [
          SizedBox(width: 420, child: _productsList()),
          Container(width: 1, color: _bdr),
          Expanded(child: _productDetailPanel()),
        ]),
      ),
    ]);
  }

  Widget _productsToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: _navy2.withValues(alpha: 0.5),
      child: Row(children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _tp, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'بحث...',
              hintStyle: const TextStyle(color: _td),
              prefixIcon: const Icon(Icons.search, color: _td, size: 16),
              isDense: true,
              filled: true,
              fillColor: _navy3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _bdr)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _bdr)),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(width: 10),
        _miniDropdown('الفئة', _catFilter, [
          const DropdownMenuItem(value: 'all', child: Text('كل الفئات')),
          ..._categories.map((c) => DropdownMenuItem(
              value: c['id'] as String,
              child: Text('${c['code']} — ${c['name_ar']}',
                  overflow: TextOverflow.ellipsis))),
        ], (v) => setState(() => _catFilter = v ?? 'all')),
        const SizedBox(width: 8),
        _miniDropdown('النوع', _kindFilter, [
          const DropdownMenuItem(value: 'all', child: Text('الكل')),
          ..._kKinds.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value))),
        ], (v) => setState(() => _kindFilter = v ?? 'all')),
        const SizedBox(width: 8),
        _miniDropdown('الحالة', _statusFilter, [
          const DropdownMenuItem(value: 'all', child: Text('الكل')),
          ..._kStatuses.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value))),
        ], (v) {
          setState(() => _statusFilter = v ?? 'active');
          _load();
        }),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _gold, foregroundColor: Colors.black),
          onPressed: _addProduct,
          icon: const Icon(Icons.add, size: 14),
          label: const Text('صنف جديد'),
        ),
      ]),
    );
  }

  Widget _miniDropdown<T>(
      String label, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      constraints: const BoxConstraints(minHeight: 34, minWidth: 140),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: _navy2,
          style: const TextStyle(color: _tp, fontSize: 12),
          icon: const Icon(Icons.arrow_drop_down, color: _ts, size: 18),
          hint: Text(label, style: const TextStyle(color: _td, fontSize: 12)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _productsList() {
    final list = _filteredProducts;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined,
              color: _gold.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 10),
          const Text('لا توجد أصناف',
              style: TextStyle(color: _ts, fontSize: 14)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _addProduct,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('صنف جديد'),
          ),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => _productTile(list[i]),
    );
  }

  Widget _productTile(Map<String, dynamic> p) {
    final sel = _selectedProductId == p['id'];
    final catName = _categories
            .firstWhere((c) => c['id'] == p['category_id'],
                orElse: () => {'name_ar': '—'})['name_ar'] ??
        '—';
    final brandName = _brands
            .firstWhere((b) => b['id'] == p['brand_id'],
                orElse: () => {'name_ar': '—'})['name_ar'] ??
        '—';
    final stock = (p['total_stock_on_hand'] ?? 0).toDouble();
    return InkWell(
      onTap: () => _loadVariants(p['id']),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? _gold.withValues(alpha: 0.14) : _navy2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? _gold : _bdr, width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              p['kind'] == 'service'
                  ? Icons.build_circle_outlined
                  : p['kind'] == 'composite'
                      ? Icons.widgets_outlined
                      : Icons.inventory_2_outlined,
              color: _gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text(p['code'] ?? '',
                          style: const TextStyle(
                              color: _gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace'))),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(p['name_ar'] ?? '',
                        style: const TextStyle(
                            color: _tp,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Text('$catName · $brandName',
                      style: const TextStyle(color: _td, fontSize: 10)),
                  const SizedBox(width: 6),
                  _dot(_statusColor(p['status'])),
                  const SizedBox(width: 3),
                  Text(_kStatuses[p['status']] ?? p['status'] ?? '',
                      style: TextStyle(
                          color: _statusColor(p['status']),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${p['active_variant_count'] ?? 0} متغيّر',
                  style:
                      const TextStyle(color: _ts, fontSize: 10)),
              const SizedBox(height: 2),
              Text(_fmt(stock),
                  style: TextStyle(
                      color: stock > 0 ? _ok : _td,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace')),
            ],
          ),
        ]),
      ),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'active':
        return _ok;
      case 'draft':
        return _warn;
      case 'discontinued':
        return _err;
      case 'archived':
        return _td;
    }
    return _td;
  }

  Widget _dot(Color color) => Container(
      width: 6,
      height: 6,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));

  Widget _productDetailPanel() {
    if (_selectedProductId == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.touch_app,
              color: _gold.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 10),
          const Text('اختر صنفاً لعرض تفاصيله',
              style: TextStyle(color: _ts, fontSize: 13)),
        ]),
      );
    }
    final p =
        _products.firstWhere((pp) => pp['id'] == _selectedProductId, orElse: () => {});
    if (p.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header + actions
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(p['code'] ?? '',
                style: const TextStyle(
                    color: _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p['name_ar'] ?? '',
                style: const TextStyle(
                    color: _tp, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: const BorderSide(color: _bdr)),
            onPressed: () => _editProduct(p),
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('تعديل'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kv('الاسم EN', p['name_en'] ?? '—')),
          Expanded(child: _kv('النوع', _kKinds[p['kind']] ?? p['kind'] ?? '—')),
          Expanded(
              child: _kv(
                  'ضريبة القيمة المضافة', _kVatCodes[p['vat_code']] ?? p['vat_code'] ?? '—')),
        ]),
        Row(children: [
          Expanded(child: _kv('وحدة القياس', p['default_uom'] ?? '—')),
          Expanded(
              child: _kv('الحد الأدنى للطلب',
                  (p['min_order_qty'] ?? 1).toString())),
          Expanded(child: _kv('HS Code', p['hs_code'] ?? '—', mono: true)),
        ]),
        Row(children: [
          Expanded(child: _flagKv('يُباع', p['is_sellable'] == true)),
          Expanded(child: _flagKv('يُشترى', p['is_purchasable'] == true)),
          Expanded(child: _flagKv('مخزّن', p['is_stockable'] == true)),
        ]),
        if ((p['description_ar'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: Text(p['description_ar'],
                style: const TextStyle(color: _ts, fontSize: 12, height: 1.5)),
          ),
        ],
        const SizedBox(height: 18),
        // Variants section
        Row(children: [
          const Icon(Icons.style, color: _gold, size: 16),
          const SizedBox(width: 6),
          const Text('المتغيّرات (Variants)',
              style: TextStyle(
                  color: _tp, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3)),
            child: Text('${_variants.length}',
                style: const TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            onPressed: () => _addVariant(p['id']),
            icon: const Icon(Icons.add, size: 12),
            label: const Text('متغيّر جديد', style: TextStyle(fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 8),
        if (_variants.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _navy2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _bdr)),
            child: const Text('لا توجد متغيّرات — اضغط "متغيّر جديد"',
                style: TextStyle(color: _td, fontSize: 11),
                textAlign: TextAlign.center),
          )
        else
          ..._variants.map(_variantTile),
      ]),
    );
  }

  Widget _variantTile(Map<String, dynamic> v) {
    final sel = _selectedVariantId == v['id'];
    final onHand = (v['total_on_hand'] ?? 0).toDouble();
    final price = (v['list_price'] ?? 0).toDouble();
    final cost = (v['standard_cost'] ?? v['default_cost'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(children: [
        InkWell(
          onTap: () => _loadBarcodes(v['id']),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sel ? _gold.withValues(alpha: 0.1) : _navy2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: sel ? _gold : _bdr, width: sel ? 1.5 : 1),
            ),
            child: Row(children: [
              Icon(sel ? Icons.expand_less : Icons.expand_more,
                  color: _ts, size: 16),
              const SizedBox(width: 4),
              SizedBox(
                width: 100,
                child: Text(v['sku'] ?? '',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Text(
                    v['display_name_ar'] ?? (v['attribute_values'] as Map?)?.values.join(' / ') ?? '',
                    style: const TextStyle(color: _tp, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 80,
                child: Text('تكلفة: ${_fmt(cost)}',
                    style: const TextStyle(
                        color: _td,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.end),
              ),
              SizedBox(
                width: 80,
                child: Text('سعر: ${_fmt(price)}',
                    style: const TextStyle(
                        color: _warn,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.end),
              ),
              SizedBox(
                width: 60,
                child: Text(_fmt(onHand),
                    style: TextStyle(
                        color: onHand > 0 ? _ok : _err,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.end),
              ),
            ]),
          ),
        ),
        if (sel) _barcodesPanel(v['id']),
      ]),
    );
  }

  Widget _barcodesPanel(String variantId) {
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 20),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.qr_code, color: _gold, size: 14),
            const SizedBox(width: 4),
            Text('الباركود (${_barcodes.length})',
                style: const TextStyle(
                    color: _tp, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: _gold,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => _addBarcode(variantId),
              icon: const Icon(Icons.add, size: 12),
              label:
                  const Text('إضافة باركود', style: TextStyle(fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 6),
          if (_barcodes.isEmpty)
            const Text('لا توجد باركودات',
                style: TextStyle(color: _td, fontSize: 11))
          else
            ..._barcodes.map((b) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: _navy2,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(children: [
                    Text(b['value'] ?? '',
                        style: const TextStyle(
                            color: _tp,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 10),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(3)),
                        child: Text(_kBarcodeTypes[b['type']] ?? b['type'],
                            style: const TextStyle(
                                color: Color(0xFF8B97FF),
                                fontSize: 9,
                                fontWeight: FontWeight.w700))),
                    const Spacer(),
                    Text(b['scope'] ?? '',
                        style: const TextStyle(color: _td, fontSize: 10)),
                  ]),
                )),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 2: Categories
  // ════════════════════════════════════════════════════════════════════

  Widget _categoriesTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          Text('${_categories.length} فئة',
              style: const TextStyle(color: _ts, fontSize: 12)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _addCategory,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('فئة جديدة'),
          ),
        ]),
      ),
      Expanded(
        child: _categories.isEmpty
            ? const Center(
                child: Text('لا توجد فئات بعد',
                    style: TextStyle(color: _ts, fontSize: 13)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  final color =
                      _parseHex(c['color_hex']) ?? const Color(0xFF6366F1);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _navy2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _bdr),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Icon(Icons.category, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(c['code'] ?? '',
                                    style: const TextStyle(
                                        color: _gold,
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 6),
                              Text(c['name_ar'] ?? '',
                                  style: const TextStyle(
                                      color: _tp,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            if ((c['name_en'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(c['name_en'],
                                  style: const TextStyle(
                                      color: _td, fontSize: 10)),
                            ],
                          ],
                        ),
                      ),
                      if ((c['default_vat_code'] ?? '').toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3)),
                          child: Text(
                              _kVatCodes[c['default_vat_code']] ??
                                  c['default_vat_code'],
                              style: const TextStyle(
                                  color: Color(0xFFA78BFA),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 3: Brands
  // ════════════════════════════════════════════════════════════════════

  Widget _brandsTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          Text('${_brands.length} علامة تجارية',
              style: const TextStyle(color: _ts, fontSize: 12)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _addBrand,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('علامة جديدة'),
          ),
        ]),
      ),
      Expanded(
        child: _brands.isEmpty
            ? const Center(
                child: Text('لا توجد علامات تجارية',
                    style: TextStyle(color: _ts, fontSize: 13)))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 100,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _brands.length,
                itemBuilder: (_, i) {
                  final b = _brands[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _navy2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _bdr),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3)),
                              child: Text(b['code'] ?? '',
                                  style: const TextStyle(
                                      color: _gold,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700))),
                          const Spacer(),
                          if ((b['country_of_origin'] ?? '').toString().isNotEmpty)
                            Text(b['country_of_origin'],
                                style: const TextStyle(
                                    color: _ts,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        Text(b['name_ar'] ?? '',
                            style: const TextStyle(
                                color: _tp,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        if ((b['name_en'] ?? '').toString().isNotEmpty)
                          Text(b['name_en'],
                              style: const TextStyle(color: _td, fontSize: 10),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════
  // Dialogs
  // ════════════════════════════════════════════════════════════════════

  Future<void> _addProduct() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductDialog(
        existing: null,
        categories: _categories,
        brands: _brands,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _editProduct(Map<String, dynamic> p) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductDialog(
        existing: p,
        categories: _categories,
        brands: _brands,
      ),
    );
    if (r == true) _load();
  }

  Future<void> _addVariant(String productId) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _VariantDialog(productId: productId),
    );
    if (r == true) _loadVariants(productId);
  }

  Future<void> _addBarcode(String variantId) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _BarcodeDialog(variantId: variantId),
    );
    if (r == true) _loadBarcodes(variantId);
  }

  Future<void> _addCategory() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
    if (r == true) _load();
  }

  Future<void> _addBrand() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => const _BrandDialog(),
    );
    if (r == true) _load();
  }

  // ════════════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════════════

  Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: _td, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _flagKv(String label, bool on) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(on ? Icons.check_circle : Icons.cancel,
            color: on ? _ok : _err, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(color: on ? _tp : _td, fontSize: 12)),
      ]),
    );
  }

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return parts.length == 2 ? '$intP.${parts[1]}' : intP;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Product Dialog
// ══════════════════════════════════════════════════════════════════════════

class _ProductDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> brands;
  const _ProductDialog(
      {required this.existing, required this.categories, required this.brands});
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _code = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _descAr = TextEditingController();
  final _hsCode = TextEditingController();
  final _uom = TextEditingController(text: 'piece');
  final _moq = TextEditingController(text: '1');
  String _kind = 'goods';
  String _vatCode = 'standard';
  String _status = 'active';
  String? _categoryId;
  String? _brandId;
  bool _sellable = true;
  bool _purchasable = true;
  bool _stockable = true;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _code.text = e['code'] ?? '';
      _nameAr.text = e['name_ar'] ?? '';
      _nameEn.text = e['name_en'] ?? '';
      _descAr.text = e['description_ar'] ?? '';
      _hsCode.text = e['hs_code'] ?? '';
      _uom.text = e['default_uom'] ?? 'piece';
      _moq.text = (e['min_order_qty'] ?? 1).toString();
      _kind = e['kind'] ?? 'goods';
      _vatCode = e['vat_code'] ?? 'standard';
      _status = e['status'] ?? 'active';
      _categoryId = e['category_id'];
      _brandId = e['brand_id'];
      _sellable = e['is_sellable'] == true;
      _purchasable = e['is_purchasable'] == true;
      _stockable = e['is_stockable'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _nameAr, _nameEn, _descAr, _hsCode, _uom, _moq]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _nameAr.text.trim().isEmpty) {
      setState(() => _error = 'الكود والاسم العربي مطلوبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isEdit) {
      final body = <String, dynamic>{
        'name_ar': _nameAr.text.trim(),
        if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
        if (_descAr.text.trim().isNotEmpty)
          'description_ar': _descAr.text.trim(),
        if (_categoryId != null) 'category_id': _categoryId,
        if (_brandId != null) 'brand_id': _brandId,
        'vat_code': _vatCode,
        if (_hsCode.text.trim().isNotEmpty) 'hs_code': _hsCode.text.trim(),
        'status': _status,
        'default_uom': _uom.text.trim(),
        'is_sellable': _sellable,
        'is_purchasable': _purchasable,
        'is_stockable': _stockable,
      };
      final r = await pilotClient.updateProduct(widget.existing!['id'], body);
      setState(() => _loading = false);
      if (!mounted) return;
      if (r.success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: _ok, content: Text('تم التحديث ✓')));
      } else {
        setState(() => _error = r.error ?? 'فشل التحديث');
      }
    } else {
      final body = <String, dynamic>{
        'code': _code.text.trim(),
        'name_ar': _nameAr.text.trim(),
        if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
        if (_descAr.text.trim().isNotEmpty)
          'description_ar': _descAr.text.trim(),
        if (_categoryId != null) 'category_id': _categoryId,
        if (_brandId != null) 'brand_id': _brandId,
        'kind': _kind,
        'vat_code': _vatCode,
        if (_hsCode.text.trim().isNotEmpty) 'hs_code': _hsCode.text.trim(),
        'default_uom': _uom.text.trim(),
        'min_order_qty': double.tryParse(_moq.text.trim()) ?? 1,
        'is_sellable': _sellable,
        'is_purchasable': _purchasable,
        'is_stockable': _stockable,
      };
      final r =
          await pilotClient.createProduct(PilotSession.tenantId!, body);
      setState(() => _loading = false);
      if (!mounted) return;
      if (r.success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: _ok, content: Text('تم إنشاء الصنف ✓')));
      } else {
        setState(() => _error = r.error ?? 'فشل الإنشاء');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          const Icon(Icons.inventory_2, color: _gold),
          const SizedBox(width: 8),
          Text(_isEdit ? 'تعديل صنف' : 'صنف جديد',
              style: const TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: _f('الكود *', _code,
                          mono: true, enabled: !_isEdit)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _f('الاسم العربي *', _nameAr)),
                ]),
                const SizedBox(height: 8),
                _f('الاسم الإنجليزي', _nameEn),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _dd('النوع', _kind,
                          _kKinds.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          (v) => setState(() => _kind = v!),
                          enabled: !_isEdit)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _dd('VAT', _vatCode,
                          _kVatCodes.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          (v) => setState(() => _vatCode = v!))),
                  const SizedBox(width: 8),
                  if (_isEdit)
                    Expanded(
                        child: _dd('الحالة', _status,
                            _kStatuses.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key, child: Text(e.value)))
                                .toList(),
                            (v) => setState(() => _status = v!))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _dd<String?>(
                        'الفئة',
                        _categoryId,
                        [
                          const DropdownMenuItem(
                              value: null, child: Text('— بدون —')),
                          ...widget.categories.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text('${c['code']} — ${c['name_ar']}',
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        (v) => setState(() => _categoryId = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dd<String?>(
                        'العلامة التجارية',
                        _brandId,
                        [
                          const DropdownMenuItem(
                              value: null, child: Text('— بدون —')),
                          ...widget.brands.map((b) => DropdownMenuItem(
                              value: b['id'] as String,
                              child: Text('${b['code']} — ${b['name_ar']}',
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        (v) => setState(() => _brandId = v)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _f('وحدة القياس', _uom)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _f('الحد الأدنى للطلب', _moq, mono: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _f('HS Code', _hsCode, mono: true)),
                ]),
                const SizedBox(height: 8),
                _f('الوصف (عربي)', _descAr, maxLines: 3),
                const SizedBox(height: 12),
                Row(children: [
                  _chk('يُباع', _sellable,
                      (v) => setState(() => _sellable = v)),
                  _chk('يُشترى', _purchasable,
                      (v) => setState(() => _purchasable = v)),
                  _chk('مخزّن', _stockable,
                      (v) => setState(() => _stockable = v)),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _err.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _err.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: _err, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: _err, fontSize: 12))),
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
                : Text(_isEdit ? 'حفظ' : 'إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _f(String label, TextEditingController ctrl,
      {bool mono = false, bool enabled = true, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(
              color: enabled ? _tp : _td,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _dd<T>(String label, T value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged,
      {bool enabled = true}) {
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
              style: TextStyle(color: enabled ? _tp : _td, fontSize: 12),
              icon: const Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chk(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Row(children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            checkColor: Colors.black,
            fillColor: WidgetStateProperty.resolveWith<Color?>(
                (s) => s.contains(WidgetState.selected) ? _gold : _navy3),
          ),
          Text(label, style: const TextStyle(color: _ts, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Variant Dialog
// ══════════════════════════════════════════════════════════════════════════

class _VariantDialog extends StatefulWidget {
  final String productId;
  const _VariantDialog({required this.productId});
  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  final _sku = TextEditingController();
  final _nameAr = TextEditingController();
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _reorder = TextEditingController();
  String _currency = 'SAR';
  bool _trackStock = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_sku, _nameAr, _cost, _price, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sku.text.trim().isEmpty) {
      setState(() => _error = 'SKU مطلوب');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'sku': _sku.text.trim(),
      if (_nameAr.text.trim().isNotEmpty)
        'display_name_ar': _nameAr.text.trim(),
      if (_cost.text.trim().isNotEmpty)
        'standard_cost': _cost.text.trim(),
      if (_price.text.trim().isNotEmpty) 'list_price': _price.text.trim(),
      'currency': _currency,
      'track_stock': _trackStock,
      if (_reorder.text.trim().isNotEmpty)
        'reorder_point': _reorder.text.trim(),
    };
    final r = await pilotClient.createVariant(widget.productId, body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء المتغيّر ✓')));
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
          Icon(Icons.style, color: _gold),
          SizedBox(width: 8),
          Text('متغيّر جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field('SKU *', _sku, mono: true),
            const SizedBox(height: 8),
            _field('الاسم المعروض (عربي)', _nameAr),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field('التكلفة', _cost, mono: true)),
              const SizedBox(width: 8),
              Expanded(child: _field('سعر البيع', _price, mono: true)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _ddown('العملة', _currency, const [
                  DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'AED', child: Text('AED')),
                ], (v) => setState(() => _currency = v!)),
              ),
              const SizedBox(width: 8),
              Expanded(child: _field('نقطة إعادة الطلب', _reorder, mono: true)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(
                value: _trackStock,
                onChanged: (v) => setState(() => _trackStock = v ?? true),
                checkColor: Colors.black,
                fillColor: WidgetStateProperty.resolveWith<Color?>(
                    (s) => s.contains(WidgetState.selected) ? _gold : _navy3),
              ),
              const Text('تتبّع المخزون',
                  style: TextStyle(color: _ts, fontSize: 12)),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: _err, fontSize: 12)),
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
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: TextStyle(
              color: _tp,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _ddown<T>(String label, T value, List<DropdownMenuItem<T>> items,
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
// Barcode Dialog
// ══════════════════════════════════════════════════════════════════════════

class _BarcodeDialog extends StatefulWidget {
  final String variantId;
  const _BarcodeDialog({required this.variantId});
  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _value = TextEditingController();
  String _type = 'ean13';
  String _scope = 'primary';
  int _unitsPerScan = 1;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_value.text.trim().isEmpty) {
      setState(() => _error = 'القيمة مطلوبة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'value': _value.text.trim(),
      'type': _type,
      'scope': _scope,
      'units_per_scan': _unitsPerScan,
    };
    final r = await pilotClient.createBarcode(widget.variantId, body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم إضافة الباركود ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإضافة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: const Row(children: [
          Icon(Icons.qr_code, color: _gold),
          SizedBox(width: 8),
          Text('باركود جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _value,
              style: const TextStyle(color: _tp, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'القيمة *',
                labelStyle: const TextStyle(color: _td),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _bdr)),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _bdr)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _type,
                      isExpanded: true,
                      dropdownColor: _navy2,
                      style: const TextStyle(color: _tp, fontSize: 12),
                      icon: const Icon(Icons.arrow_drop_down, color: _ts),
                      items: _kBarcodeTypes.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _bdr)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _scope,
                      isExpanded: true,
                      dropdownColor: _navy2,
                      style: const TextStyle(color: _tp, fontSize: 12),
                      icon: const Icon(Icons.arrow_drop_down, color: _ts),
                      items: const [
                        DropdownMenuItem(value: 'primary', child: Text('رئيسي')),
                        DropdownMenuItem(value: 'carton', child: Text('كرتون')),
                        DropdownMenuItem(value: 'inner', child: Text('داخلي')),
                        DropdownMenuItem(value: 'legacy', child: Text('قديم')),
                        DropdownMenuItem(
                            value: 'promotional', child: Text('ترويجي')),
                      ],
                      onChanged: (v) => setState(() => _scope = v!),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'وحدات لكل مسح',
                labelStyle: const TextStyle(color: _td),
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _bdr)),
              ),
              style: const TextStyle(color: _tp, fontFamily: 'monospace'),
              controller: TextEditingController(text: '$_unitsPerScan'),
              onChanged: (v) => _unitsPerScan = int.tryParse(v) ?? 1,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: _err, fontSize: 12)),
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
                : const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Category Dialog
// ══════════════════════════════════════════════════════════════════════════

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _code = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _colorHex = TextEditingController(text: '#3B82F6');
  String _vatCode = 'standard';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _nameAr, _nameEn, _colorHex]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _nameAr.text.trim().isEmpty) {
      setState(() => _error = 'الكود والاسم مطلوبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'code': _code.text.trim(),
      'name_ar': _nameAr.text.trim(),
      if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
      'default_vat_code': _vatCode,
      if (_colorHex.text.trim().isNotEmpty)
        'color_hex': _colorHex.text.trim(),
    };
    final r = await pilotClient.createCategory(PilotSession.tenantId!, body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء الفئة ✓')));
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
          Icon(Icons.category, color: _gold),
          SizedBox(width: 8),
          Text('فئة جديدة', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _code,
              decoration: _inputDec('الكود *', mono: true),
              style: const TextStyle(
                  color: _tp, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameAr,
              decoration: _inputDec('الاسم العربي *'),
              style: const TextStyle(color: _tp, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameEn,
              decoration: _inputDec('الاسم الإنجليزي'),
              style: const TextStyle(color: _tp, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: _navy3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _bdr)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vatCode,
                  isExpanded: true,
                  dropdownColor: _navy2,
                  style: const TextStyle(color: _tp, fontSize: 12),
                  icon: const Icon(Icons.arrow_drop_down, color: _ts),
                  items: _kVatCodes.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _vatCode = v!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _colorHex,
              decoration: _inputDec('لون (Hex) — #RRGGBB', mono: true),
              style: const TextStyle(
                  color: _tp, fontSize: 12, fontFamily: 'monospace'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: _err, fontSize: 12)),
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
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, {bool mono = false}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _td),
        isDense: true,
        filled: true,
        fillColor: _navy3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _bdr)),
      );
}

// ══════════════════════════════════════════════════════════════════════════
// Brand Dialog
// ══════════════════════════════════════════════════════════════════════════

class _BrandDialog extends StatefulWidget {
  const _BrandDialog();
  @override
  State<_BrandDialog> createState() => _BrandDialogState();
}

class _BrandDialogState extends State<_BrandDialog> {
  final _code = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _country = TextEditingController(text: 'SA');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _nameAr, _nameEn, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _nameAr.text.trim().isEmpty) {
      setState(() => _error = 'الكود والاسم مطلوبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'code': _code.text.trim(),
      'name_ar': _nameAr.text.trim(),
      if (_nameEn.text.trim().isNotEmpty) 'name_en': _nameEn.text.trim(),
      if (_country.text.trim().length == 2)
        'country_of_origin': _country.text.trim().toUpperCase(),
    };
    final r = await pilotClient.createBrand(PilotSession.tenantId!, body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم إنشاء العلامة ✓')));
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
          Icon(Icons.label, color: _gold),
          SizedBox(width: 8),
          Text('علامة تجارية جديدة', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _code,
              decoration: _dec('الكود *', mono: true),
              style: const TextStyle(
                  color: _tp, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameAr,
              decoration: _dec('الاسم العربي *'),
              style: const TextStyle(color: _tp, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameEn,
              decoration: _dec('الاسم الإنجليزي'),
              style: const TextStyle(color: _tp, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _country,
              decoration: _dec('بلد المنشأ (ISO 2 حرف)', mono: true),
              style: const TextStyle(
                  color: _tp, fontSize: 12, fontFamily: 'monospace'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: _err, fontSize: 12)),
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
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, {bool mono = false}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _td),
        isDense: true,
        filled: true,
        fillColor: _navy3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _bdr)),
      );
}
