/// Stock Movements & Transfers — حركات المخزون والتحويلات.
///
/// مستقلة — تقرأ PilotSession.entityId. تعرض لكل مستودع حركاته وترصيده،
/// وتسمح بتسجيل:
///   • تسوية (adjustment_plus / adjustment_minus)
///   • جرد (stocktake)
///   • تلف (damage)
///   • رصيد افتتاحي (initial)
///   • تحويل بين مستودعين (transfer_out + transfer_in)
library;

import 'package:flutter/material.dart';
import '../../../core/theme.dart' as core_theme;

import '../../api/pilot_client.dart';
import '../../num_utils.dart';
import '../../session.dart';

Color get _gold => core_theme.AC.gold;
Color get _navy => core_theme.AC.navy;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
final _tp = Color(0xFFFFFFFF);
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;
Color get _warn => core_theme.AC.warn;

final _kReasons = <String, Map<String, dynamic>>{
  'po_receipt': {'ar': 'استلام مشتريات', 'color': _ok, 'icon': Icons.call_received, 'sign': 1},
  'pos_sale': {'ar': 'بيع', 'color': _err, 'icon': Icons.shopping_cart, 'sign': -1},
  'pos_return': {'ar': 'إرجاع', 'color': _warn, 'icon': Icons.reply, 'sign': 1},
  'transfer_in': {'ar': 'تحويل وارد', 'color': _ok, 'icon': Icons.call_received, 'sign': 1},
  'transfer_out': {'ar': 'تحويل صادر', 'color': _err, 'icon': Icons.call_made, 'sign': -1},
  'adjustment_plus': {'ar': 'تسوية زيادة', 'color': _ok, 'icon': Icons.add_circle, 'sign': 1},
  'adjustment_minus': {'ar': 'تسوية نقص', 'color': _err, 'icon': Icons.remove_circle, 'sign': -1},
  'stocktake': {'ar': 'جرد', 'color': core_theme.AC.purple, 'icon': Icons.fact_check, 'sign': 0},
  'damage': {'ar': 'تلف', 'color': _err, 'icon': Icons.broken_image, 'sign': -1},
  'theft': {'ar': 'سرقة', 'color': _err, 'icon': Icons.security, 'sign': -1},
  'expiry': {'ar': 'انتهاء صلاحية', 'color': _err, 'icon': Icons.hourglass_empty, 'sign': -1},
  'initial': {'ar': 'رصيد افتتاحي', 'color': _gold, 'icon': Icons.play_circle, 'sign': 1},
  'reservation': {'ar': 'حجز', 'color': _warn, 'icon': Icons.lock_clock, 'sign': 0},
  'release': {'ar': 'إفراج عن حجز', 'color': _ok, 'icon': Icons.lock_open, 'sign': 0},
};

class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});
  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final PilotClient _client = pilotClient;

  // Reference data
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _warehouses = []; // flat list across branches
  List<Map<String, dynamic>> _products = [];
  final Map<String, List<Map<String, dynamic>>> _variantsByProduct = {};

  // Displayed data
  String? _selectedWarehouseId;
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _stockLevels = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasEntity) {
      setState(() {
        _loading = false;
        _error = 'يجب اختيار الكيان من شريط العنوان أولاً.';
      });
      return;
    }
    try {
      // Branches + warehouses
      final bR = await _client.listBranches(PilotSession.entityId!);
      if (!bR.success) throw 'فشل تحميل الفروع';
      _branches = List<Map<String, dynamic>>.from(bR.data);
      _warehouses = [];
      for (final b in _branches) {
        final wR = await _client.listWarehouses(b['id']);
        if (wR.success) {
          for (final w in List<Map<String, dynamic>>.from(wR.data)) {
            _warehouses.add({...w, '_branch_code': b['code'], '_branch_city': b['city']});
          }
        }
      }
      // Products + variants
      if (PilotSession.hasTenant) {
        final pR = await _client.listProducts(PilotSession.tenantId!);
        if (pR.success) {
          _products = List<Map<String, dynamic>>.from(pR.data);
        }
      }
      // Auto-select first warehouse
      if (_warehouses.isNotEmpty && _selectedWarehouseId == null) {
        _selectedWarehouseId = _warehouses.first['id'];
        await _loadWarehouseData(_selectedWarehouseId!);
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadWarehouseData(String wid) async {
    setState(() {
      _selectedWarehouseId = wid;
      _movements = [];
      _stockLevels = [];
    });
    final mR = await _client.listWarehouseMovements(wid, limit: 200);
    final sR = await _client.getWarehouseStock(wid);
    setState(() {
      _movements = mR.success ? List<Map<String, dynamic>>.from(mR.data) : [];
      _stockLevels = sR.success ? List<Map<String, dynamic>>.from(sR.data) : [];
    });
  }

  Future<List<Map<String, dynamic>>> _variantsFor(String productId) async {
    if (_variantsByProduct.containsKey(productId)) {
      return _variantsByProduct[productId]!;
    }
    final r = await _client.listVariants(productId);
    if (r.success) {
      final list = List<Map<String, dynamic>>.from(r.data);
      _variantsByProduct[productId] = list;
      return list;
    }
    return [];
  }

  Future<void> _recordMovement() async {
    if (_selectedWarehouseId == null) return;
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _MovementDialog(
        warehouseId: _selectedWarehouseId!,
        products: _products,
        variantsLoader: _variantsFor,
      ),
    );
    if (r == true) _loadWarehouseData(_selectedWarehouseId!);
  }

  Future<void> _recordTransfer() async {
    if (_warehouses.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _warn,
          content: Text('تحتاج مستودعين على الأقل لإجراء التحويل')));
      return;
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _TransferDialog(
        warehouses: _warehouses,
        products: _products,
        variantsLoader: _variantsFor,
        defaultSourceId: _selectedWarehouseId,
      ),
    );
    if (r == true && _selectedWarehouseId != null) {
      _loadWarehouseData(_selectedWarehouseId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(children: [
          _header(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : _warehouses.isEmpty
                        ? _emptyView()
                        : _content(),
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
          child: Icon(Icons.swap_vert, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حركات المخزون والتحويلات',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
                '${_warehouses.length} مستودع · ${_movements.length} حركة معروضة',
                style: TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: BorderSide(color: _bdr)),
          onPressed: () {
            if (_selectedWarehouseId != null) {
              _loadWarehouseData(_selectedWarehouseId!);
            }
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: BorderSide(color: _gold)),
          onPressed: _recordTransfer,
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: const Text('تحويل'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
          onPressed: _recordMovement,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('تسوية / جرد'),
        ),
      ]),
    );
  }

  Widget _content() {
    return Row(children: [
      // Warehouses sidebar
      SizedBox(
          width: 260, child: _warehousesSidebar()),
      Container(width: 1, color: _bdr),
      // Main content: tabs for stock + movements
      Expanded(child: _warehouseDetail()),
    ]);
  }

  Widget _warehousesSidebar() {
    return Container(
      color: _navy2.withValues(alpha: 0.6),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _bdr))),
          child: Row(children: [
            Icon(Icons.warehouse, color: _gold, size: 16),
            SizedBox(width: 6),
            Text('المستودعات',
                style: TextStyle(
                    color: _tp, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _warehouses.length,
            itemBuilder: (_, i) {
              final w = _warehouses[i];
              final sel = _selectedWarehouseId == w['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => _loadWarehouseData(w['id']),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel ? _gold.withValues(alpha: 0.14) : _navy2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: sel ? _gold : _bdr, width: sel ? 1.5 : 1),
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
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(w['code'] ?? '',
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          if (w['is_default'] == true)
                            Icon(Icons.star, color: _warn, size: 12),
                        ]),
                        const SizedBox(height: 5),
                        Text(w['name_ar'] ?? '',
                            style: TextStyle(
                                color: _tp,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${w['_branch_code']}${(w['_branch_city'] ?? '').toString().isNotEmpty ? " — ${w["_branch_city"]}" : ""}',
                          style: TextStyle(color: _td, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(_typeLabel(w['type']),
                            style: TextStyle(color: _ts, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'main':
        return 'رئيسي';
      case 'stockroom':
        return 'مخزن';
      case 'central_dc':
        return 'مركز توزيع';
      case 'returns':
        return 'مرتجعات';
    }
    return t ?? '—';
  }

  Widget _warehouseDetail() {
    if (_selectedWarehouseId == null) {
      return Center(
        child: Text('اختر مستودعاً',
            style: TextStyle(color: _ts, fontSize: 13)),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: _navy2,
          child: TabBar(
            indicatorColor: _gold,
            labelColor: _gold,
            unselectedLabelColor: _ts,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(icon: Icon(Icons.inventory, size: 16), text: 'الأرصدة'),
              Tab(icon: Icon(Icons.history, size: 16), text: 'الحركات'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [_stockLevelsTab(), _movementsTab()],
          ),
        ),
      ]),
    );
  }

  Widget _stockLevelsTab() {
    if (_stockLevels.isEmpty) {
      return Center(
          child: Text('لا توجد أرصدة في هذا المستودع',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Text('SKU / المتغيّر', style: _th)),
            SizedBox(width: 100, child: Text('الرصيد', style: _th, textAlign: TextAlign.end)),
            SizedBox(width: 100, child: Text('محجوز', style: _th, textAlign: TextAlign.end)),
            SizedBox(width: 100, child: Text('متاح', style: _th, textAlign: TextAlign.end)),
            SizedBox(width: 100, child: Text('سعر متوسط', style: _th, textAlign: TextAlign.end)),
          ]),
        ),
        const SizedBox(height: 6),
        ..._stockLevels.map(_stockRow),
      ],
    );
  }

  Widget _stockRow(Map<String, dynamic> s) {
    final onHand = asDouble(s['on_hand']);
    final reserved = asDouble(s['reserved']);
    final available = asDouble(s['available']);
    final avgCost = asDouble(s['weighted_avg_cost']);
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(s['variant_id'] ?? '',
              style: TextStyle(
                  color: _ts, fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis),
        ),
        SizedBox(
          width: 100,
          child: Text(_fmt(onHand),
              style: TextStyle(
                  color: onHand > 0 ? _ok : _err,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 100,
          child: Text(_fmt(reserved),
              style: TextStyle(
                  color: reserved > 0 ? _warn : _td,
                  fontSize: 12,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 100,
          child: Text(_fmt(available),
              style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 100,
          child: Text(_fmt(avgCost),
              style: TextStyle(
                  color: _ts, fontSize: 11, fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
      ]),
    );
  }

  Widget _movementsTab() {
    if (_movements.isEmpty) {
      return Center(
          child: Text('لا توجد حركات بعد',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _movements.length,
      itemBuilder: (_, i) {
        final m = _movements[i];
        final info = _kReasons[m['reason']] ?? {'ar': m['reason'] ?? '—', 'color': _ts, 'icon': Icons.circle};
        final qty = asDouble(m['qty']);
        final balanceAfter = asDouble(m['balance_after']);
        final performedAt = (m['performed_at'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _navy2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (info['color'] as Color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(info['icon'] as IconData,
                  color: info['color'] as Color, size: 16),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Text(info['ar'] as String,
                  style: TextStyle(
                      color: info['color'] as Color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['variant_id'] ?? '',
                      style: TextStyle(
                          color: _ts,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis),
                  if ((m['reference_number'] ?? '').toString().isNotEmpty)
                    Text('#${m['reference_number']}',
                        style: TextStyle(color: _td, fontSize: 10)),
                  if ((m['notes'] ?? '').toString().isNotEmpty)
                    Text(m['notes'],
                        style: TextStyle(color: _td, fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                '${qty > 0 ? "+" : ""}${_fmt(qty)}',
                style: TextStyle(
                    color: qty > 0 ? _ok : qty < 0 ? _err : _ts,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.end,
              ),
            ),
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('رصيد:',
                      style: TextStyle(color: _td, fontSize: 9)),
                  Text(_fmt(balanceAfter),
                      style: TextStyle(
                          color: _tp,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                  performedAt.length >= 16 ? performedAt.substring(0, 16).replaceAll('T', ' ') : performedAt,
                  style: TextStyle(color: _td, fontSize: 10)),
            ),
          ]),
        );
      },
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: _err, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: _ts)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: BorderSide(color: _bdr)),
          onPressed: _loadInitial,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('إعادة المحاولة'),
        ),
      ]),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warehouse_outlined,
            color: _gold.withValues(alpha: 0.4), size: 72),
        const SizedBox(height: 14),
        Text('لا توجد مستودعات بعد',
            style: TextStyle(color: _tp, fontSize: 16)),
        const SizedBox(height: 8),
        Text('يجب إنشاء مستودع من شاشة "المستودعات" أولاً',
            style: TextStyle(color: _ts, fontSize: 12)),
      ]),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return parts.length == 2 ? '$intP.${parts[1]}' : intP;
  }
}

final _th = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════════
// Movement Dialog (Adjustment / Stocktake / Damage / Initial)
// ══════════════════════════════════════════════════════════════════════════

class _MovementDialog extends StatefulWidget {
  final String warehouseId;
  final List<Map<String, dynamic>> products;
  final Future<List<Map<String, dynamic>>> Function(String) variantsLoader;
  const _MovementDialog({
    required this.warehouseId,
    required this.products,
    required this.variantsLoader,
  });
  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  String? _productId;
  String? _variantId;
  List<Map<String, dynamic>> _variants = [];
  final _qty = TextEditingController();
  final _unitCost = TextEditingController();
  final _refNumber = TextEditingController();
  final _notes = TextEditingController();
  String _reason = 'adjustment_plus';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_qty, _unitCost, _refNumber, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onProductChanged(String? pid) async {
    setState(() {
      _productId = pid;
      _variantId = null;
      _variants = [];
    });
    if (pid != null) {
      final vs = await widget.variantsLoader(pid);
      setState(() {
        _variants = vs;
        if (vs.length == 1) _variantId = vs.first['id'];
      });
    }
  }

  Future<void> _submit() async {
    if (_variantId == null) {
      setState(() => _error = 'اختر متغيّراً');
      return;
    }
    final q = double.tryParse(_qty.text.trim());
    if (q == null || q == 0) {
      setState(() => _error = 'أدخل كمية صحيحة غير صفرية');
      return;
    }
    // Determine sign from reason
    final sign = _kReasons[_reason]?['sign'] ?? 0;
    double signedQty = q;
    if (sign == -1 && q > 0) signedQty = -q;
    if (sign == 1 && q < 0) signedQty = -q;

    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'warehouse_id': widget.warehouseId,
      'variant_id': _variantId,
      'qty': signedQty.toString(),
      if (_unitCost.text.trim().isNotEmpty) 'unit_cost': _unitCost.text.trim(),
      'reason': _reason,
      if (_refNumber.text.trim().isNotEmpty)
        'reference_number': _refNumber.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };
    final r = await pilotClient.recordStockMovement(body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok, content: Text('تم تسجيل الحركة ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Allowed reasons for manual movements
    const allowed = [
      'adjustment_plus',
      'adjustment_minus',
      'stocktake',
      'damage',
      'theft',
      'expiry',
      'initial',
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Icon(Icons.edit_note, color: _gold),
          SizedBox(width: 8),
          Text('تسجيل حركة مخزون', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dd<String?>(
                'الصنف',
                _productId,
                [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— اختر الصنف —')),
                  ...widget.products.map((p) => DropdownMenuItem<String?>(
                      value: p['id'] as String,
                      child: Text('${p['code']} — ${p['name_ar']}',
                          overflow: TextOverflow.ellipsis))),
                ],
                _onProductChanged),
            const SizedBox(height: 8),
            _dd<String?>(
                'المتغيّر',
                _variantId,
                [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— اختر المتغيّر —')),
                  ..._variants.map((v) => DropdownMenuItem<String?>(
                      value: v['id'] as String,
                      child: Text(
                          '${v['sku']} · رصيد ${(v['total_on_hand'] ?? 0)}',
                          overflow: TextOverflow.ellipsis))),
                ],
                (v) => setState(() => _variantId = v)),
            const SizedBox(height: 8),
            _dd<String>(
                'السبب',
                _reason,
                allowed
                    .map((k) => DropdownMenuItem<String>(
                        value: k,
                        child: Text(_kReasons[k]?['ar'] as String? ?? k)))
                    .toList(),
                (v) => setState(() => _reason = v!)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field('الكمية *', _qty, mono: true)),
              const SizedBox(width: 8),
              Expanded(child: _field('تكلفة الوحدة', _unitCost, mono: true)),
            ]),
            const SizedBox(height: 8),
            _field('المرجع (اختياري)', _refNumber, mono: true),
            const SizedBox(height: 8),
            _field('ملاحظات', _notes, maxLines: 2),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _err.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_error!,
                    style: TextStyle(color: _err, fontSize: 12)),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
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

  Widget _field(String label, TextEditingController ctrl,
      {bool mono = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
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
                borderSide: BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
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
              style: TextStyle(color: _tp, fontSize: 12),
              icon: Icon(Icons.arrow_drop_down, color: _ts),
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
// Transfer Dialog — (transfer_out + transfer_in) atomic pair
// ══════════════════════════════════════════════════════════════════════════

class _TransferDialog extends StatefulWidget {
  final List<Map<String, dynamic>> warehouses;
  final List<Map<String, dynamic>> products;
  final Future<List<Map<String, dynamic>>> Function(String) variantsLoader;
  final String? defaultSourceId;
  const _TransferDialog({
    required this.warehouses,
    required this.products,
    required this.variantsLoader,
    this.defaultSourceId,
  });
  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  String? _sourceId;
  String? _destId;
  String? _productId;
  String? _variantId;
  List<Map<String, dynamic>> _variants = [];
  final _qty = TextEditingController();
  final _refNumber = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sourceId = widget.defaultSourceId ??
        (widget.warehouses.isNotEmpty ? widget.warehouses.first['id'] : null);
  }

  @override
  void dispose() {
    for (final c in [_qty, _refNumber, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onProductChanged(String? pid) async {
    setState(() {
      _productId = pid;
      _variantId = null;
      _variants = [];
    });
    if (pid != null) {
      final vs = await widget.variantsLoader(pid);
      setState(() => _variants = vs);
    }
  }

  Future<void> _submit() async {
    if (_sourceId == null || _destId == null) {
      setState(() => _error = 'اختر المستودعين');
      return;
    }
    if (_sourceId == _destId) {
      setState(() => _error = 'المصدر والوجهة يجب أن يكونا مختلفين');
      return;
    }
    if (_variantId == null) {
      setState(() => _error = 'اختر متغيّراً');
      return;
    }
    final q = double.tryParse(_qty.text.trim());
    if (q == null || q <= 0) {
      setState(() => _error = 'أدخل كمية موجبة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final refNum = _refNumber.text.trim().isEmpty
        ? 'TRF-${DateTime.now().millisecondsSinceEpoch}'
        : _refNumber.text.trim();

    // 1) transfer_out from source (negative qty)
    final r1 = await pilotClient.recordStockMovement({
      'warehouse_id': _sourceId,
      'variant_id': _variantId,
      'qty': (-q).toString(),
      'reason': 'transfer_out',
      'reference_type': 'transfer',
      'reference_number': refNum,
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    });
    if (!r1.success) {
      setState(() {
        _loading = false;
        _error = 'فشل الإخراج: ${r1.error}';
      });
      return;
    }

    // 2) transfer_in to dest (positive qty)
    final r2 = await pilotClient.recordStockMovement({
      'warehouse_id': _destId,
      'variant_id': _variantId,
      'qty': q.toString(),
      'reason': 'transfer_in',
      'reference_type': 'transfer',
      'reference_number': refNum,
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    });
    setState(() => _loading = false);
    if (!mounted) return;
    if (r2.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok,
          content: Text('تم التحويل ($refNum) ✓')));
    } else {
      setState(
          () => _error = 'تم الإخراج لكن فشل الإدخال: ${r2.error} — راجع الحركات يدوياً');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Icon(Icons.swap_horiz, color: _gold),
          SizedBox(width: 8),
          Text('تحويل بين المستودعات', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: _dd<String?>(
                    'من (المصدر)',
                    _sourceId,
                    widget.warehouses
                        .map((w) => DropdownMenuItem<String?>(
                            value: w['id'] as String,
                            child: Text('${w['code']} — ${w['name_ar']}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    (v) => setState(() => _sourceId = v)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_back, color: _gold),
              ),
              Expanded(
                child: _dd<String?>(
                    'إلى (الوجهة)',
                    _destId,
                    [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('— اختر —')),
                      ...widget.warehouses
                          .where((w) => w['id'] != _sourceId)
                          .map((w) => DropdownMenuItem<String?>(
                              value: w['id'] as String,
                              child: Text('${w['code']} — ${w['name_ar']}',
                                  overflow: TextOverflow.ellipsis))),
                    ],
                    (v) => setState(() => _destId = v)),
              ),
            ]),
            const SizedBox(height: 8),
            _dd<String?>(
                'الصنف',
                _productId,
                [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— اختر الصنف —')),
                  ...widget.products.map((p) => DropdownMenuItem<String?>(
                      value: p['id'] as String,
                      child: Text('${p['code']} — ${p['name_ar']}',
                          overflow: TextOverflow.ellipsis))),
                ],
                _onProductChanged),
            const SizedBox(height: 8),
            _dd<String?>(
                'المتغيّر',
                _variantId,
                [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— اختر —')),
                  ..._variants.map((v) => DropdownMenuItem<String?>(
                      value: v['id'] as String,
                      child: Text(
                          '${v['sku']} · متاح ${(v['total_available'] ?? 0)}',
                          overflow: TextOverflow.ellipsis))),
                ],
                (v) => setState(() => _variantId = v)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field('الكمية *', _qty, mono: true)),
              const SizedBox(width: 8),
              Expanded(child: _field('مرجع (اختياري)', _refNumber, mono: true)),
            ]),
            const SizedBox(height: 8),
            _field('ملاحظات', _notes, maxLines: 2),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _err.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(_error!,
                    style: TextStyle(color: _err, fontSize: 12)),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تنفيذ التحويل'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool mono = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
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
                borderSide: BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        Text(label, style: TextStyle(color: _td, fontSize: 11)),
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
              style: TextStyle(color: _tp, fontSize: 12),
              icon: Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
