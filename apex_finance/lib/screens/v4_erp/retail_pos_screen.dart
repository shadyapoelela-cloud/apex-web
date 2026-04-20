/// Retail POS — LIVE backed by Pilot backend.
///
/// Auto-detects:
///  - If PilotBridge is bound AND the current V5 entity is a pilot SA entity:
///    renders the LIVE PilotRetailPosWidget (real barcode scan, cart, payment,
///    auto-GL posting, ZATCA QR).
///  - Otherwise: renders a lightweight empty-state prompting the user to
///    select a tenant first (the mock demo is deprecated).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/v5/entity_scope_selector.dart' as v5scope;
import '../../pilot/api/pilot_client.dart';
import '../../pilot/bridge/pilot_bridge.dart';

class RetailPosScreen extends StatefulWidget {
  const RetailPosScreen({super.key});

  @override
  State<RetailPosScreen> createState() => _RetailPosScreenState();
}

class _CartLine {
  final String variantId;
  final String sku;
  final String description;
  int qty;
  double unitPrice;
  String currency;
  String? promoBadge;
  String? barcodeScanned;

  _CartLine({
    required this.variantId,
    required this.sku,
    required this.description,
    this.qty = 1,
    required this.unitPrice,
    required this.currency,
    this.promoBadge,
    this.barcodeScanned,
  });

  double get lineTotal => qty * unitPrice;
}

class _RetailPosScreenState extends State<RetailPosScreen> {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _tenderedCtrl = TextEditingController();
  final List<_CartLine> _cart = [];

  Map<String, dynamic>? _activeSession;
  String? _selectedBranchId;
  bool _loading = false;
  String? _lastReceipt;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    PilotBridge.instance.addListener(_onBridgeChanged);
    v5scope.EntityScopeController.instance.addListener(_onBridgeChanged);
  }

  @override
  void dispose() {
    PilotBridge.instance.removeListener(_onBridgeChanged);
    v5scope.EntityScopeController.instance.removeListener(_onBridgeChanged);
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _tenderedCtrl.dispose();
    super.dispose();
  }

  void _onBridgeChanged() {
    if (mounted) {
      setState(() {
        _activeSession = null;
        _cart.clear();
        _selectedBranchId = null;
      });
    }
  }

  double get _grandTotal =>
      _cart.fold(0.0, (s, l) => s + l.lineTotal);

  PilotClient get _client => pilotClient;
  PilotBridge get _bridge => PilotBridge.instance;

  void _showError(String msg) {
    setState(() => _errorMsg = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AC.err, content: Text(msg)),
    );
  }

  Future<void> _ensureBranch() async {
    if (_selectedBranchId != null) return;
    final branches = _bridge.branchesForCurrentEntity();
    if (branches.isEmpty) {
      _showError('لا توجد فروع لهذا الكيان. أنشئ فرعاً أولاً.');
      return;
    }
    setState(() => _selectedBranchId = branches.first['id']);
  }

  Future<void> _openSession() async {
    await _ensureBranch();
    if (_selectedBranchId == null) return;

    final whs = await _client.listWarehouses(_selectedBranchId!);
    if (!whs.success || (whs.data as List).isEmpty) {
      _showError('لا يوجد مستودع لهذا الفرع');
      return;
    }
    final List wh = whs.data as List;
    final Map defaultWh = wh.firstWhere(
      (w) => w['is_default'] == true,
      orElse: () => wh.first,
    );

    setState(() => _loading = true);
    final r = await _client.openPosSession(_selectedBranchId!, {
      'branch_id': _selectedBranchId,
      'warehouse_id': defaultWh['id'],
      'opened_by_user_id': 'cashier-web',
      'opening_cash': '0',
      'station_id': 'WEB-01',
      'station_label': 'متصفح',
    });
    setState(() => _loading = false);

    if (r.success) {
      setState(() {
        _activeSession = Map<String, dynamic>.from(r.data);
        _errorMsg = null;
      });
    } else {
      _showError(r.error ?? 'فشل فتح الوردية');
    }
  }

  Future<void> _scan(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;
    if (!_bridge.isBound) {
      _showError('لم يتم ربط المستأجر');
      return;
    }
    final tid = _bridge.tenantId!;

    final scan = await _client.scanBarcode(tid, trimmed);
    if (!scan.success) {
      _showError('باركود غير معروف: $trimmed');
      return;
    }
    final body = scan.data as Map;
    final variant = body['variant'] as Map;
    final product = body['product'] as Map;

    final priceRes = await _client.priceLookup(
      tenantId: tid,
      variantId: variant['id'],
      branchId: _selectedBranchId,
    );
    if (!priceRes.success) {
      _showError('فشل حساب السعر');
      return;
    }
    final price = priceRes.data as Map;
    final unitPrice = double.tryParse('${price['unit_price']}') ?? 0;

    setState(() {
      final existing = _cart.indexWhere((l) => l.variantId == variant['id']);
      if (existing >= 0) {
        _cart[existing].qty += 1;
      } else {
        _cart.add(_CartLine(
          variantId: variant['id'],
          sku: variant['sku'],
          description: product['name_ar'] ?? product['name_en'] ?? variant['sku'],
          unitPrice: unitPrice,
          currency: price['currency'] ?? 'SAR',
          promoBadge: price['promo_badge_text_ar'],
          barcodeScanned: trimmed,
        ));
      }
      _barcodeCtrl.clear();
    });
    _barcodeFocus.requestFocus();
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      _showError('السلة فارغة');
      return;
    }
    if (_activeSession == null) {
      _showError('افتح وردية أولاً');
      return;
    }
    final tendered = double.tryParse(_tenderedCtrl.text) ?? _grandTotal;
    if (tendered < _grandTotal) {
      _showError('المبلغ المدفوع أقل من المطلوب');
      return;
    }

    setState(() => _loading = true);
    final r = await _client.createPosTransaction({
      'session_id': _activeSession!['id'],
      'kind': 'sale',
      'cashier_user_id': 'cashier-web',
      'lines': _cart
          .map((l) => {
                'variant_id': l.variantId,
                'qty': l.qty.toString(),
                'barcode_scanned': l.barcodeScanned,
              })
          .toList(),
      'payments': [
        {'method': 'cash', 'amount': tendered.toStringAsFixed(2)}
      ],
    });
    setState(() => _loading = false);

    if (r.success) {
      final txn = r.data as Map;
      await _client.postPosToGl(txn['id']);
      final country = _bridge.currentPilotEntity?['country'];
      if (country == 'SA') {
        await _client.submitPosToZatca(txn['id'], simulate: true);
      }
      setState(() {
        _lastReceipt = txn['receipt_number'];
        _cart.clear();
        _tenderedCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AC.ok,
            content: Text(
              'تم البيع: ${txn['receipt_number']} — المجموع ${txn['grand_total']}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } else {
      _showError(r.error ?? 'فشل البيع');
    }
  }

  Future<void> _closeSession() async {
    if (_activeSession == null) return;
    final closingCashCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إقفال الوردية', style: TextStyle(color: AC.tp)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('ادخل العدّ الفعلي للنقد في الدرج:',
              style: TextStyle(color: AC.ts)),
          const SizedBox(height: 12),
          TextField(
            controller: closingCashCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AC.tp),
            decoration: InputDecoration(
              hintText: '0.00',
              filled: true,
              fillColor: AC.navy3,
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إقفال'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final r = await _client.closePosSession(_activeSession!['id'], {
      'closed_by_user_id': 'cashier-web',
      'closing_cash': closingCashCtrl.text.trim().isEmpty
          ? '0'
          : closingCashCtrl.text,
      'closing_notes': 'إقفال من الواجهة',
    });
    if (r.success) {
      final zr = r.data as Map;
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AC.navy2,
            title: Text('Z-Report', style: TextStyle(color: AC.tp)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _zr('المتوقّع', '${zr['expected_cash']}'),
                  _zr('العدّ الفعلي', '${zr['closing_cash']}'),
                  _zr('الفرق', '${zr['variance']}'),
                  _zr('عدد المعاملات', '${zr['transaction_count']}'),
                  _zr('إجمالي المبيعات', '${zr['total_sales_gross']}'),
                  _zr('VAT', '${zr['total_vat']}'),
                  _zr('الصافي', '${zr['total_net']}'),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('تم', style: TextStyle(color: AC.gold))),
            ],
          ),
        );
      }
      setState(() => _activeSession = null);
    } else {
      _showError(r.error ?? 'فشل الإقفال');
    }
  }

  Widget _zr(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 120, child: Text(k, style: TextStyle(color: AC.ts))),
          Text(v,
              style:
                  TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (!_bridge.isBound) {
      return _needsTenantBinding();
    }
    if (_bridge.entities.isEmpty) {
      return _emptyState('لا توجد كيانات لهذا المستأجر.');
    }
    if (_bridge.currentPilotEntity == null) {
      return _emptyState('اختر كياناً من شريط العنوان.');
    }
    return _buildPos();
  }

  Widget _needsTenantBinding() => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: AC.navy,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined, size: 80, color: AC.td),
                const SizedBox(height: 16),
                Text('لم يتم ربط مستأجر بعد',
                    style: TextStyle(color: AC.tp, fontSize: 20)),
                const SizedBox(height: 8),
                Text('هذه الشاشة تعمل مع بيانات حيّة من الباك-إند.',
                    style: TextStyle(color: AC.ts)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AC.gold,
                    foregroundColor: AC.btnFg,
                  ),
                  onPressed: () => _showBindDialog(),
                  icon: const Icon(Icons.link),
                  label: const Text('ربط مستأجر'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _showBindDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('ربط مستأجر', style: TextStyle(color: AC.tp)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            hintText: 'Tenant ID (UUID)',
            hintStyle: TextStyle(color: AC.td),
            filled: true,
            fillColor: AC.navy3,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AC.ts))),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ربط'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final success = await _bridge.bindTenant(ctrl.text.trim());
      if (!success && mounted) _showError('فشل ربط المستأجر');
    }
  }

  Widget _emptyState(String msg) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: AC.navy,
          child: Center(
            child: Text(msg, style: TextStyle(color: AC.ts, fontSize: 16)),
          ),
        ),
      );

  Widget _buildPos() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: AC.navy,
        child: Row(children: [
          // Left (in RTL, shown on right): scanner + cart
          Expanded(
            flex: 3,
            child: Column(children: [
              _sessionBar(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _barcodeCtrl,
                  focusNode: _barcodeFocus,
                  autofocus: true,
                  style: TextStyle(color: AC.tp, fontSize: 18),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z-]'))
                  ],
                  decoration: InputDecoration(
                    hintText: 'امسح الباركود أو اكتبه ثم Enter',
                    hintStyle: TextStyle(color: AC.td),
                    filled: true,
                    fillColor: AC.navy3,
                    prefixIcon: Icon(Icons.qr_code_scanner, color: AC.gold),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AC.bdr)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AC.bdr)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AC.gold, width: 2)),
                  ),
                  onSubmitted: _scan,
                ),
              ),
              Expanded(
                child: _cart.isEmpty
                    ? Center(
                        child: Text('السلة فارغة — ابدأ بالمسح',
                            style: TextStyle(color: AC.td, fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _cart.length,
                        itemBuilder: (_, i) => _cartTile(i),
                      ),
              ),
            ]),
          ),

          Container(width: 1, color: AC.bdr),

          // Right (in RTL, shown on left): totals + payment
          Expanded(
            flex: 2,
            child: Container(
              color: AC.navy2,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('الإجمالي',
                        style: TextStyle(color: AC.ts, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '${_grandTotal.toStringAsFixed(2)} ${_cart.isEmpty ? "" : _cart.first.currency}',
                      style: TextStyle(
                          color: AC.gold,
                          fontSize: 42,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_cart.length} صنف / ${_cart.fold(0, (s, l) => s + l.qty)} قطعة',
                      style: TextStyle(color: AC.ts),
                    ),
                    const SizedBox(height: 24),
                    Text('المبلغ المستلم (نقد):',
                        style: TextStyle(color: AC.ts)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tenderedCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AC.tp, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: _grandTotal.toStringAsFixed(2),
                        hintStyle: TextStyle(color: AC.td),
                        filled: true,
                        fillColor: AC.navy3,
                        prefixIcon: Icon(Icons.payments, color: AC.gold),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AC.bdr)),
                      ),
                      onSubmitted: (_) => _checkout(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AC.ok,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onPressed: _loading ||
                              _activeSession == null ||
                              _cart.isEmpty
                          ? null
                          : _checkout,
                      icon: const Icon(Icons.check_circle),
                      label: Text(_loading ? 'يعالج...' : 'إتمام البيع',
                          style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AC.bdr)),
                      onPressed: _cart.isEmpty
                          ? null
                          : () => setState(() => _cart.clear()),
                      icon: Icon(Icons.close, color: AC.err),
                      label: Text('إلغاء السلة',
                          style: TextStyle(color: AC.err)),
                    ),
                    const Spacer(),
                    if (_lastReceipt != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AC.ok.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.receipt, color: AC.ok, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('آخر إيصال: $_lastReceipt',
                                  style: TextStyle(color: AC.ok))),
                        ]),
                      ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sessionBar() {
    final entity = _bridge.currentPilotEntity;
    final branchName = _bridge
        .branchesForCurrentEntity()
        .firstWhere((b) => b['id'] == _selectedBranchId,
            orElse: () => <String, dynamic>{})['name_ar'];

    return Container(
      padding: const EdgeInsets.all(12),
      color: AC.navy3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.business, color: AC.gold, size: 18),
          const SizedBox(width: 6),
          Text(
            '${entity?['name_ar'] ?? ''} (${entity?['functional_currency'] ?? 'SAR'})',
            style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500),
          ),
          if (branchName != null) ...[
            Text(' • ', style: TextStyle(color: AC.td)),
            Text(branchName,
                style: TextStyle(color: AC.ts, fontSize: 13)),
          ],
        ]),
        const SizedBox(height: 8),
        _activeSession == null
            ? Row(children: [
                Icon(Icons.power_settings_new, color: AC.err),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('لا توجد وردية مفتوحة',
                        style: TextStyle(color: AC.tp))),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AC.gold,
                    foregroundColor: AC.btnFg,
                  ),
                  onPressed: _loading ? null : _openSession,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('فتح وردية'),
                ),
              ])
            : Row(children: [
                Icon(Icons.lock_open, color: AC.ok),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'وردية: ${_activeSession!['code']} — مفتوحة',
                        style: TextStyle(color: AC.tp))),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: AC.err)),
                  onPressed: _closeSession,
                  icon: Icon(Icons.lock, color: AC.err),
                  label: Text('إقفال', style: TextStyle(color: AC.err)),
                ),
              ]),
      ]),
    );
  }

  Widget _cartTile(int i) {
    final l = _cart[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.description,
                  style:
                      TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(children: [
                Text(l.sku,
                    style: TextStyle(color: AC.td, fontSize: 12)),
                if (l.promoBadge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.warn.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(l.promoBadge!,
                        style: TextStyle(color: AC.warn, fontSize: 10)),
                  ),
                ],
              ]),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.remove_circle_outline, color: AC.ts),
          onPressed: () => setState(() {
            if (l.qty > 1) {
              l.qty--;
            } else {
              _cart.removeAt(i);
            }
          }),
        ),
        SizedBox(
          width: 30,
          child: Text('${l.qty}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: AC.gold),
          onPressed: () => setState(() => l.qty++),
        ),
        SizedBox(
          width: 100,
          child: Text('${l.lineTotal.toStringAsFixed(2)} ${l.currency}',
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: AC.gold, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
