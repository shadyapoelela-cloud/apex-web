/// APEX — POS Quick Sale (retail cash sale)
/// /pos/quick-sale — single-screen flow:
///   1. Add one or more lines (product picker or manual description)
///   2. Choose payment method (Mada/STC/Cash/Card/Apple)
///   3. Submit → JE auto-posted (Dr Cash, Cr Sales, Cr VAT)
///   4. Receipt printable + WhatsApp shareable + ZATCA QR (Phase 1)
///
/// G-POS-MULTILINE-CLEANUP (2026-05-11): refactored from single-line to
/// list of `_PosLineDraft` mirroring sales + purchase. Each line has
/// its own ProductPickerOrCreate so the cashier can ring up multiple
/// SKUs in one sale.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api_service.dart';
import '../../core/apex_saudi_payment_grid.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
// G-POS-ZATCA-QR (2026-05-11): import the pure-Dart TLV helper so the
// success receipt renders a Phase-1-compliant QR alongside the JE link
// + WhatsApp share. Pre-fix POS receipts shipped no QR which meant
// they didn't meet ZATCA Phase 1 requirements for B2C simplified-tax
// invoices.
import '../../core/zatca_tlv.dart';
import '../../widgets/apex_output_chips.dart';
import '../../widgets/forms/product_picker_or_create.dart';

/// Per-line draft for a POS sale. Mirrors `_LineDraft` (sales) and
/// `_PiLineDraft` (purchase) so all three flows share the same shape.
class _PosLineDraft {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController unitPrice;
  final TextEditingController vatRate;
  Map<String, dynamic>? product;

  _PosLineDraft({
    String description = '',
    String quantity = '1',
    String price = '',
    String vat = '15',
  })  : desc = TextEditingController(text: description),
        qty = TextEditingController(text: quantity),
        unitPrice = TextEditingController(text: price),
        vatRate = TextEditingController(text: vat);

  void dispose() {
    desc.dispose();
    qty.dispose();
    unitPrice.dispose();
    vatRate.dispose();
  }

  double get quantityValue => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPriceValue => double.tryParse(unitPrice.text.trim()) ?? 0;
  double get vatRateValue => double.tryParse(vatRate.text.trim()) ?? 0;
  double get subtotal => quantityValue * unitPriceValue;
  double get vatAmount => subtotal * vatRateValue / 100;
  double get lineTotal => subtotal + vatAmount;
}

class PosQuickSaleScreen extends StatefulWidget {
  const PosQuickSaleScreen({super.key});
  @override
  State<PosQuickSaleScreen> createState() => _PosQuickSaleScreenState();
}

class _PosQuickSaleScreenState extends State<PosQuickSaleScreen> {
  final List<_PosLineDraft> _lines = [_PosLineDraft()];
  ApexPaymentMethod _method = ApexPaymentMethod.mada;
  bool _submitting = false;
  Map<String, dynamic>? _lastReceipt;

  @override
  void initState() {
    super.initState();
    // G-ENTITY-SELLER-INFO (2026-05-11): fire-and-forget refresh of
    // the active entity's seller identity (VAT number + Arabic legal
    // name + address). Fire-and-forget by design — the cashier shouldn't
    // wait for the network before opening the POS, and the next sale
    // picks up the real values once the response lands. Silent on
    // failure (placeholder fallback keeps the QR rendering).
    S.fetchEntitySellerInfo();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_PosLineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  double get _grandSubtotal => _lines.fold(0.0, (s, l) => s + l.subtotal);
  double get _grandVat => _lines.fold(0.0, (s, l) => s + l.vatAmount);
  double get _grandTotal => _grandSubtotal + _grandVat;

  /// Map the UI's `ApexPaymentMethod` enum onto the backend's
  /// PosPaymentInput.method string. The backend regex accepts
  /// cash|mada|visa|mastercard|amex|stc_pay|apple_pay|google_pay|
  /// samsung_pay|tamara|tabby|gift_card|store_credit|bank_transfer|other —
  /// keep this in sync with `PosPaymentInput` in app/pilot/schemas/pos.py.
  String _methodCode(ApexPaymentMethod m) => switch (m) {
        ApexPaymentMethod.cash => 'cash',
        ApexPaymentMethod.mada => 'mada',
        ApexPaymentMethod.stcPay => 'stc_pay',
        ApexPaymentMethod.applePay => 'apple_pay',
        ApexPaymentMethod.card => 'visa', // generic card → visa scheme
        ApexPaymentMethod.bankTransfer => 'bank_transfer',
      };

  /// G-POS-BACKEND-INTEGRATION-V2 (2026-05-11): resolve the active
  /// POS branch. First check `S.savedBranchId`; on miss, fetch the
  /// entity's branches and persist the first active one for future
  /// sales. Returns null on hard failure.
  Future<String?> _resolveBranchId(String entityId) async {
    final cached = S.savedBranchId;
    if (cached != null && cached.isNotEmpty) return cached;
    final res = await ApiService.pilotListBranchesForEntity(entityId);
    if (!res.success || res.data is! List) return null;
    final list = res.data as List;
    if (list.isEmpty) return null;
    for (final b in list) {
      if (b is Map) {
        final id = b['id'] as String?;
        final isActive = b['is_active'] != false; // missing ⇒ active
        if (id != null && id.isNotEmpty && isActive) {
          S.savedBranchId = id;
          return id;
        }
      }
    }
    // Fallback: first branch even if `is_active` flag missing.
    final first = list.first;
    if (first is Map) {
      final id = first['id'] as String?;
      if (id != null && id.isNotEmpty) {
        S.savedBranchId = id;
        return id;
      }
    }
    return null;
  }

  /// G-POS-BACKEND-INTEGRATION-V2 + G-POS-V2-HOTFIX: ensure there's an
  /// open POS session for this branch before submitting. Lists the
  /// latest open session; if none, opens a new one with the resolved
  /// warehouse_id + cashier user_id.
  ///
  /// HOTFIX: pre-hotfix payload was `{'opening_cash': 0}` only, which
  /// 422'd on first sale because PosSessionOpen requires `branch_id`,
  /// `warehouse_id`, AND `opened_by_user_id`. The backend can't default
  /// these from the branch (warehouse is 1:N per branch; user comes
  /// from the JWT but the schema still validates the body). We now:
  ///   1. fetch warehouses for the branch
  ///   2. pick the first active one (or the first one period)
  ///   3. pass S.uid as opened_by_user_id (early-return if null)
  Future<String?> _ensureOpenSession(String branchId) async {
    final list = await ApiService.pilotListOpenPosSessions(branchId);
    if (list.success && list.data is List && (list.data as List).isNotEmpty) {
      final first = (list.data as List).first;
      if (first is Map) {
        final id = first['id'] as String?;
        if (id != null && id.isNotEmpty) return id;
      }
    }
    // No open session — open one. Resolve warehouse_id first.
    final whRes = await ApiService.pilotListBranchWarehouses(branchId);
    if (!whRes.success || whRes.data is! List) return null;
    final whList = whRes.data as List;
    if (whList.isEmpty) return null;
    String? warehouseId;
    for (final w in whList) {
      if (w is Map) {
        final id = w['id'] as String?;
        final isActive = w['is_active'] != false;
        if (id != null && id.isNotEmpty && isActive) {
          warehouseId = id;
          break;
        }
      }
    }
    // Fallback to the first warehouse if none flagged active.
    if (warehouseId == null) {
      final first = whList.first;
      if (first is Map) {
        warehouseId = first['id'] as String?;
      }
    }
    if (warehouseId == null || warehouseId.isEmpty) return null;
    // Resolve cashier user id (HOTFIX bug #1): caller already gated on
    // S.uid being non-empty before invoking this method, so the lookup
    // here is purely a re-read for the payload field. We still null-
    // guard so the bug surfaces as a returned-null (caller shows the
    // snackbar) instead of a silent partial payload.
    final cashierUid = S.uid;
    if (cashierUid == null || cashierUid.isEmpty) return null;
    final open = await ApiService.pilotCreatePosSession(branchId, {
      'branch_id': branchId,
      'warehouse_id': warehouseId,
      'opened_by_user_id': cashierUid,
      'opening_cash': 0,
    });
    if (open.success && open.data is Map) {
      return (open.data as Map)['id'] as String?;
    }
    return null;
  }

  /// G-POS-V2-HOTFIX: stable canonical code for the auto-provisioned
  /// cash customer. Pre-hotfix the code was `CASH-${timestamp}` which
  /// re-created a new customer on every retry/refresh, polluting the
  /// AR ledger with hundreds of one-off "cash customer" rows that all
  /// referred to the same conceptual party. Switching to a stable code
  /// + GET-by-code lookup makes the helper idempotent.
  static const _kCashCustomerCode = 'CASH-DEFAULT';

  /// G-POS-BACKEND-INTEGRATION-V2 + G-POS-V2-HOTFIX: auto-provision
  /// the cash customer idempotently.
  ///
  /// Flow:
  ///   1. GET by code (`CASH-DEFAULT`) — return id if found.
  ///   2. POST create with the canonical code + Arabic name.
  ///   3. If POST returns 409 (Customer already exists), retry the
  ///      GET-by-code so two concurrent cashiers don't both create.
  Future<String?> _ensureCashCustomer(String tenantId) async {
    // (1) GET by canonical code first. customer_routes.py's list
    // endpoint supports `search=` which ILIKE-matches across code +
    // name_ar + name_en + vat_number, so we filter client-side to
    // exact-match on code to avoid picking up a `CASH-DEFAULT-X` twin.
    final lookup = await ApiService.pilotGetCustomerByCode(
        tenantId, _kCashCustomerCode);
    if (lookup.success && lookup.data is List) {
      for (final c in (lookup.data as List)) {
        if (c is Map && c['code'] == _kCashCustomerCode) {
          final id = c['id'] as String?;
          if (id != null && id.isNotEmpty) return id;
        }
      }
    }
    // (2) Not found — POST create with the canonical code.
    final create = await ApiService.pilotCreateCustomer(tenantId, {
      'code': _kCashCustomerCode,
      'name_ar': 'العميل النقدي',
      'kind': 'individual',
      'currency': 'SAR',
      'payment_terms': 'cod',
    });
    if (create.success && create.data is Map) {
      final id = (create.data as Map)['id'] as String?;
      if (id != null && id.isNotEmpty) return id;
    }
    // (3) Race-loser path: a concurrent cashier raced us to the create
    // and the backend returned 409. Re-run the GET-by-code lookup so
    // the second cashier picks up the row the first one wrote. We
    // detect 409 by sniffing the error text since ApiResult flattens
    // status codes — the message contains "already exists" per
    // customer_routes.py:268. Be liberal in what we accept (any error
    // string containing the literal) since the wrapper may prefix.
    final err = (create.error ?? '').toLowerCase();
    if (!create.success && err.contains('already exists')) {
      final retry = await ApiService.pilotGetCustomerByCode(
          tenantId, _kCashCustomerCode);
      if (retry.success && retry.data is List) {
        for (final c in (retry.data as List)) {
          if (c is Map && c['code'] == _kCashCustomerCode) {
            final id = c['id'] as String?;
            if (id != null && id.isNotEmpty) return id;
          }
        }
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد كيان نشط')),
      );
      return;
    }
    // G-POS-V2-HOTFIX bug #1 + #2: PosSessionOpen.opened_by_user_id
    // AND PosTransactionCreate.cashier_user_id both require a real
    // user id. Pre-hotfix the session payload silently omitted it
    // (→ 422) and the transaction payload used S.savedTenantId as
    // cashier_user_id (→ tenant.id leaking into the audit trail).
    // Hard-gate the submit on S.uid before touching the backend so
    // the cashier sees a single, clear Arabic snackbar instead of two
    // mysterious 4xx errors back-to-back.
    final cashierUid = S.uid;
    if (cashierUid == null || cashierUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مستخدم مسجّل دخول')),
      );
      return;
    }
    // G-POS-BACKEND-INTEGRATION-V2 (2026-05-11): route POS sales
    // through `POST /pilot/pos-transactions` (not the B2B sales-invoice
    // path). Per-line discriminator:
    //   * product picked  → catalogued: send variant_id, is_misc=false
    //   * no product      → misc:       send description+unit_price_override,
    //                                   is_misc=true (no stock movement,
    //                                   no price-lookup)
    // Validate every line up-front so the cashier gets clear feedback
    // per line rather than a single backend 400.
    final linesPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final desc = l.desc.text.trim();
      final emptyLine = desc.isEmpty &&
          l.product == null &&
          l.unitPriceValue <= 0;
      if (emptyLine && _lines.length > 1) continue;
      if (l.quantityValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AC.err,
          content: Text('البند ${i + 1}: الكمية غير صحيحة'),
        ));
        return;
      }
      if (l.unitPriceValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AC.err,
          content: Text('البند ${i + 1}: السعر غير صحيح'),
        ));
        return;
      }
      final variantId = l.product?['default_variant_id'] as String?;
      final hasVariant = variantId != null && variantId.isNotEmpty;
      if (hasVariant) {
        // Catalogued line — variant_id, qty, unit_price_override,
        // vat_rate_override, is_misc=false. Backend will run
        // price-lookup if unit_price_override is null but we always
        // pass the cashier's price so POS overrides win.
        linesPayload.add({
          'variant_id': variantId,
          'qty': l.quantityValue,
          'unit_price_override': l.unitPriceValue,
          'vat_rate_override': l.vatRateValue,
          'is_misc': false,
        });
      } else {
        // Misc line — description, unit_price_override, qty,
        // vat_rate_override, is_misc=true. Backend skips StockMovement.
        linesPayload.add({
          'description': desc.isEmpty ? 'بيع نقدي' : desc,
          'qty': l.quantityValue,
          'unit_price_override': l.unitPriceValue,
          'vat_rate_override': l.vatRateValue,
          'is_misc': true,
        });
      }
    }
    if (linesPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بنداً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _submitting = true);
    // Resolve the active branch (cached or fetched from entity).
    final branchId = await _resolveBranchId(entityId);
    if (!mounted) return;
    if (branchId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إيجاد فرع نشط للبيع')),
      );
      return;
    }
    // Ensure there's an open POS session.
    final sessionId = await _ensureOpenSession(branchId);
    if (!mounted) return;
    if (sessionId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح وردية POS')),
      );
      return;
    }
    // Auto-provision the cash customer (created on first run).
    final custId = await _ensureCashCustomer(tenantId);
    if (!mounted) return;
    if (custId == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذّر إنشاء العميل النقدي')),
      );
      return;
    }
    // Capture totals BEFORE submit so the receipt + the payment line
    // match exactly. The backend recomputes them from lines but we
    // need the same number for the payments[] amount.
    final capturedSubtotal = _grandSubtotal;
    final capturedVat = _grandVat;
    final capturedTotal = _grandTotal;
    final create = await ApiService.pilotCreatePosTransaction({
      'session_id': sessionId,
      'kind': 'sale',
      // G-POS-V2-HOTFIX bug #2: cashier_user_id is required by
      // PosTransactionCreate and represents the user who rang up the
      // sale. Pre-hotfix this was `S.savedTenantId ?? custId`, which
      // wrote the TENANT id (not a user id) into the audit row — the
      // backend would either reject it (FK to users) or pin sales to
      // a meaningless id forever. We gate the whole _submit on S.uid
      // above so this read is guaranteed non-null here.
      'cashier_user_id': cashierUid,
      'customer_id': custId,
      'lines': linesPayload,
      'payments': [
        {
          'method': _methodCode(_method),
          'amount': capturedTotal,
        },
      ],
    });
    if (!mounted) return;
    if (!create.success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل: ${create.error ?? '-'}'),
      ));
      return;
    }
    final posTxnId = (create.data as Map?)?['id'] as String?;
    final receiptNumber = (create.data as Map?)?['receipt_number'] as String?;
    final jeIdFromCreate = (create.data as Map?)?['journal_entry_id'] as String?;
    if (posTxnId == null) {
      setState(() => _submitting = false);
      return;
    }
    // Chain post-to-gl so the JE is guaranteed to land even if the
    // create path skipped auto-post (env-dependent). Idempotent on
    // the backend.
    final post = await ApiService.pilotPostPosTransactionToGl(posTxnId);
    if (!mounted) return;
    final jeId = jeIdFromCreate ??
        (post.success ? ((post.data as Map?)?['id'] as String?) : null);
    setState(() {
      _submitting = false;
      _lastReceipt = {
        'pos_txn_id': posTxnId,
        // G-POS-BACKEND-INTEGRATION-V2: B2C receipts use
        // `receipt_number` (RCT-…), not B2B `invoice_number` (INV-…).
        'receipt_number': receiptNumber,
        'je_id': jeId,
        'amount': capturedSubtotal,
        'vat': capturedVat,
        'total': capturedTotal,
        'method': _paymentLabel(_method),
        'issued_at_utc': DateTime.now().toUtc().toIso8601String(),
        'seller_vat_number': S.savedSellerVatNumber ?? '300000000000003',
        'seller_name': S.savedSellerNameAr ?? 'APEX',
        'line_count': linesPayload.length,
      };
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..add(_PosLineDraft());
    });
  }

  String _paymentLabel(ApexPaymentMethod m) => switch (m) {
        ApexPaymentMethod.mada => 'مدى',
        ApexPaymentMethod.stcPay => 'STC Pay',
        ApexPaymentMethod.applePay => 'Apple Pay',
        ApexPaymentMethod.card => 'بطاقة ائتمان',
        ApexPaymentMethod.cash => 'نقد',
        ApexPaymentMethod.bankTransfer => 'تحويل بنكي',
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Text('بيع سريع — POS', style: TextStyle(color: AC.gold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_lastReceipt != null) ...[
                _receiptCard(),
                const SizedBox(height: 14),
              ],
              _linesCard(),
              const SizedBox(height: 12),
              _totalsCard(),
              const SizedBox(height: 12),
              _paymentCard(),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _submitting || _grandTotal <= 0
                      ? null
                      : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.point_of_sale),
                  label: Text(_submitting ? 'جارٍ التسجيل…' : 'سجّل البيع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AC.gold,
                    foregroundColor: AC.navy,
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const ApexOutputChips(items: [
                ApexChipLink(
                    'الفواتير', '/app/erp/sales/invoices', Icons.receipt),
                ApexChipLink('المخزون', '/operations/inventory-v2',
                    Icons.inventory_2),
                ApexChipLink('بطاقة الصنف', '/operations/stock-card',
                    Icons.timeline),
                ApexChipLink('VAT Return',
                    '/app/compliance/tax/vat-return', Icons.receipt_long),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linesCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.shopping_cart_outlined,
                  color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('البنود (${_lines.length})',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            for (int i = 0; i < _lines.length; i++) _lineCard(i),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _addLine,
              icon: Icon(Icons.add, color: AC.gold, size: 18),
              label: Text('+ إضافة بند',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.gold.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ],
        ),
      );

  Widget _lineCard(int index) {
    final l = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('بند ${index + 1}',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: _lines.length <= 1
                      ? AC.td
                      : AC.err.withValues(alpha: 0.8),
                  size: 18),
              onPressed:
                  _lines.length <= 1 ? null : () => _removeLine(index),
              tooltip: 'حذف البند',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 6),
          ProductPickerOrCreate(
            initial: l.product,
            labelText: 'المنتج / الباركود (اختياري)',
            onSelected: (p) {
              setState(() {
                l.product = p;
                l.desc.text = (p['name_ar'] ?? '').toString();
                final price = p['list_price'] ?? p['default_price'];
                if (price != null && l.unitPrice.text.trim().isEmpty) {
                  l.unitPrice.text = price.toString();
                }
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: l.desc,
            style: TextStyle(color: AC.tp, fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'الوصف',
              labelStyle: TextStyle(color: AC.ts, fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: AC.navy2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: l.qty,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AC.tp, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'الكمية',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: l.unitPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'السعر',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  suffixText: 'SAR',
                  suffixStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 70,
              child: TextField(
                controller: l.vatRate,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AC.tp, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'VAT %',
                  labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: AC.navy2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text('الإجمالي', style: TextStyle(color: AC.td, fontSize: 11)),
            const Spacer(),
            Text('${l.lineTotal.toStringAsFixed(2)} SAR',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ],
      ),
    );
  }

  Widget _totalsCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          _totalRow('المجموع الفرعي', _grandSubtotal),
          _totalRow('VAT', _grandVat),
          Divider(color: AC.bdr, height: 14),
          _totalRow('الإجمالي', _grandTotal, emphasize: true),
        ]),
      );

  Widget _totalRow(String label, double v, {bool emphasize = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: emphasize ? AC.gold : AC.td,
                  fontSize: emphasize ? 14 : 12,
                  fontWeight: emphasize
                      ? FontWeight.w700
                      : FontWeight.w400)),
          const Spacer(),
          Text('${v.toStringAsFixed(2)} SAR',
              style: TextStyle(
                  color: emphasize ? AC.gold : AC.tp,
                  fontSize: emphasize ? 16 : 12,
                  fontWeight:
                      emphasize ? FontWeight.w800 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );

  Widget _paymentCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('طريقة الدفع',
              style: TextStyle(
                  color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ApexSaudiPaymentGrid(
            selected: _method,
            onSelected: (m) => setState(() => _method = m),
          ),
        ]),
      );

  Widget _receiptCard() {
    final r = _lastReceipt!;
    // G-POS-ZATCA-QR (2026-05-11): build the Phase-1 TLV QR data
    // lazily here so the receipt card always reflects the latest
    // capture. zatcaQrBase64 throws if any TLV field exceeds 255
    // bytes — wrap defensively so a malformed seller name doesn't
    // hide the rest of the receipt.
    String? qrData;
    try {
      qrData = zatcaQrBase64(
        sellerName: r['seller_name']?.toString() ?? 'APEX',
        vatNumber:
            r['seller_vat_number']?.toString() ?? '300000000000003',
        invoiceTimestampUtc: DateTime.tryParse(
                r['issued_at_utc']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        invoiceTotal:
            (r['total'] as num?)?.toStringAsFixed(2) ?? '0.00',
        vatTotal: (r['vat'] as num?)?.toStringAsFixed(2) ?? '0.00',
      );
    } catch (_) {
      qrData = null;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.ok.withValues(alpha: 0.10),
        border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.celebration, color: AC.ok),
          const SizedBox(width: 8),
          Text('تم البيع بنجاح',
              style: TextStyle(
                  color: AC.ok,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        // G-POS-BACKEND-INTEGRATION-V2 (2026-05-11): POS Quick Sale
        // now produces a B2C *receipt* (RCT-…) via the POS endpoint —
        // not a B2B *invoice* (INV-…). The label changes from "فاتورة"
        // to "إيصال" to match the ZATCA simplified-tax-invoice document
        // type that the QR encodes.
        Text(
            'إيصال #${r['receipt_number'] ?? '-'} · ${r['method']} · ${r['total']?.toStringAsFixed(2) ?? r['total']} SAR · ${r['line_count'] ?? 1} بند',
            style: TextStyle(color: AC.tp, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (qrData != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 96,
                  backgroundColor: Colors.white,
                ),
              ),
            if (qrData != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (qrData != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('ZATCA QR (Phase 1)',
                          style:
                              TextStyle(color: AC.td, fontSize: 10)),
                    ),
                  ApexWhatsAppShareButton(
                    message:
                        'إيصال بيع ${r['receipt_number'] ?? '-'} — ${r['total']} ريال (${r['method']})',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context
                        .go('/app/erp/finance/je-builder/${r['je_id']}'),
                    icon: Icon(Icons.receipt, color: AC.gold),
                    label: Text('عرض القيد',
                        style: TextStyle(color: AC.gold)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AC.gold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
