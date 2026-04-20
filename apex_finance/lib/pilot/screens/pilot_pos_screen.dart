/// Pilot POS Live — شاشة نقطة البيع الفعلية مع مسح باركود + دفع.
/// ═════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_session_provider.dart';

class PilotPosScreen extends ConsumerStatefulWidget {
  const PilotPosScreen({super.key});
  @override
  ConsumerState<PilotPosScreen> createState() => _PilotPosScreenState();
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

class _PilotPosScreenState extends ConsumerState<PilotPosScreen> {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _tenderedCtrl = TextEditingController();
  final List<_CartLine> _cart = [];
  Map<String, dynamic>? _activeSession;
  bool _loading = false;
  String? _lastReceipt;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _tenderedCtrl.dispose();
    super.dispose();
  }

  double get _grandTotal =>
      _cart.fold(0.0, (s, l) => s + l.lineTotal);

  Future<void> _openSession() async {
    final selection = ref.read(pilotSessionProvider);
    if (!selection.hasBranch) {
      _showError('اختر فرعاً أولاً من شريط العنوان');
      return;
    }
    // استعلام المستودع الافتراضي
    final client = ref.read(pilotClientProvider);
    final whs = await client.listWarehouses(selection.branchId!);
    if (!whs.success || (whs.data as List).isEmpty) {
      _showError('لا يوجد مستودع لهذا الفرع');
      return;
    }
    final defaultWh = (whs.data as List).firstWhere(
      (w) => w['is_default'] == true,
      orElse: () => (whs.data as List).first,
    );

    setState(() => _loading = true);
    final r = await client.openPosSession(selection.branchId!, {
      'branch_id': selection.branchId,
      'warehouse_id': defaultWh['id'],
      'opened_by_user_id': 'cashier-web',
      'opening_cash': '0',
      'station_id': 'WEB-01',
      'station_label': 'متصفح',
    });
    setState(() => _loading = false);
    if (r.success) {
      setState(() => _activeSession = Map<String, dynamic>.from(r.data));
    } else {
      _showError(r.error ?? 'فشل فتح الوردية');
    }
  }

  Future<void> _scan(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;
    final selection = ref.read(pilotSessionProvider);
    if (!selection.hasTenant) return;

    final client = ref.read(pilotClientProvider);
    final scan = await client.scanBarcode(selection.tenantId!, trimmed);
    if (!scan.success) {
      _showError('باركود غير معروف: $trimmed');
      return;
    }
    final body = scan.data as Map;
    final variant = body['variant'] as Map;
    final product = body['product'] as Map;

    // price-lookup
    final priceRes = await client.priceLookup(
      tenantId: selection.tenantId!,
      variantId: variant['id'],
      branchId: selection.branchId,
    );
    if (!priceRes.success) {
      _showError('فشل حساب السعر');
      return;
    }
    final price = priceRes.data as Map;
    final unitPrice = double.tryParse('${price['unit_price']}') ?? 0;

    setState(() {
      // إن كان موجوداً، زد الكمية
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
    final tendered = double.tryParse(_tenderedCtrl.text) ?? 0;
    if (tendered < _grandTotal) {
      _showError('المبلغ المدفوع أقل من المطلوب');
      return;
    }

    final client = ref.read(pilotClientProvider);
    setState(() => _loading = true);
    final r = await client.createPosTransaction({
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
      // ترحيل تلقائي إلى GL + ZATCA (simulate)
      await client.postPosToGl(txn['id']);
      final selection = ref.read(pilotSessionProvider);
      if (selection.entityCountry == 'SA') {
        await client.submitPosToZatca(txn['id'], simulate: true);
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
            content: Text('تم البيع: ${txn['receipt_number']} — المجموع ${txn['grand_total']}',
                style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } else {
      _showError(r.error ?? 'فشل البيع');
    }
  }

  Future<void> _closeSession() async {
    if (_activeSession == null) return;
    final client = ref.read(pilotClientProvider);
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
              hintStyle: TextStyle(color: AC.td),
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
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إقفال'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final r = await client.closePosSession(_activeSession!['id'], {
      'closed_by_user_id': 'cashier-web',
      'closing_cash': closingCashCtrl.text.trim().isEmpty ? '0' : closingCashCtrl.text,
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
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _zr('المتوقّع', '${zr['expected_cash']}'),
              _zr('العدّ الفعلي', '${zr['closing_cash']}'),
              _zr('الفرق', '${zr['variance']}'),
              _zr('عدد المعاملات', '${zr['transaction_count']}'),
              _zr('المبيعات', '${zr['total_sales_gross']}'),
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
          Text(v, style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
        ]),
      );

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AC.err, content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(pilotSessionProvider);
    if (!selection.hasBranch) {
      return Center(
        child: Text('اختر فرعاً من الأعلى لبدء البيع',
            style: TextStyle(color: AC.ts)),
      );
    }

    return Row(children: [
      // ── Left: scanner + cart ──
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
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z-]'))],
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
                ? Center(child: Text('السلة فارغة — ابدأ بالمسح',
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

      // ── Right: totals + payment ──
      Expanded(
        flex: 2,
        child: Container(
          color: AC.navy2,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('الإجمالي',
                style: TextStyle(color: AC.ts, fontSize: 16)),
            const SizedBox(height: 8),
            Text('${_grandTotal.toStringAsFixed(2)} ${_cart.isEmpty ? "" : _cart.first.currency}',
                style: TextStyle(color: AC.gold, fontSize: 42, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_cart.length} صنف / ${_cart.fold(0, (s, l) => s + l.qty)} قطعة',
                style: TextStyle(color: AC.ts)),
            const SizedBox(height: 24),
            Text('المبلغ المستلم (نقد):',
                style: TextStyle(color: AC.ts)),
            const SizedBox(height: 8),
            TextField(
              controller: _tenderedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AC.tp, fontSize: 18),
              decoration: InputDecoration(
                hintText: '${_grandTotal.toStringAsFixed(2)}',
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
              onPressed: _loading || _activeSession == null || _cart.isEmpty ? null : _checkout,
              icon: const Icon(Icons.check_circle),
              label: Text(_loading ? 'يعالج...' : 'إتمام البيع',
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr)),
              onPressed: _cart.isEmpty ? null : () => setState(() => _cart.clear()),
              icon: Icon(Icons.close, color: AC.err),
              label: Text('إلغاء السلة', style: TextStyle(color: AC.err)),
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
    ]);
  }

  Widget _sessionBar() => Container(
        padding: const EdgeInsets.all(12),
        color: AC.navy3,
        child: _activeSession == null
            ? Row(children: [
                Icon(Icons.power_settings_new, color: AC.err),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('لا توجد وردية مفتوحة',
                        style: TextStyle(color: AC.tp))),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
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
      );

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
                  style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(children: [
                Text(l.sku, style: TextStyle(color: AC.td, fontSize: 12)),
                if (l.promoBadge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: AC.gold),
          onPressed: () => setState(() => l.qty++),
        ),
        SizedBox(
          width: 100,
          child: Text('${l.lineTotal.toStringAsFixed(2)} ${l.currency}',
              textAlign: TextAlign.end,
              style: TextStyle(color: AC.gold, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
