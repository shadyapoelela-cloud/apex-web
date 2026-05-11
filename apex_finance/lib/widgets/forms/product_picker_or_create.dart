/// ProductPickerOrCreate — G-FIN-PRODUCT-CATALOG (Sprint 4, 2026-05-09).
///
/// Picker for product/variant references in invoice line tables.
/// Supports three input modes:
///   1. Type-to-search across `code`, `name_ar`, `name_en`.
///   2. Barcode entry → looks up via `GET /pilot/tenants/{tid}/barcode/{value}`,
///      auto-selects on hit, opens `ProductCreateModal` pre-filled with
///      the typed barcode on miss.
///   3. Inline `+ منتج جديد` opens the modal pre-filled with the typed
///      query.
///
/// Returns the selected product's first-variant info bundled with the
/// product (so the caller can read `list_price`, `default_cost`, `sku`
/// directly).
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../screens/inventory/product_create_modal.dart';

class ProductPickerOrCreate extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final String? labelText;

  const ProductPickerOrCreate({
    super.key,
    required this.onSelected,
    this.initial,
    this.labelText,
  });

  @override
  State<ProductPickerOrCreate> createState() => _ProductPickerOrCreateState();
}

class _ProductPickerOrCreateState extends State<ProductPickerOrCreate> {
  final _ctl = TextEditingController();
  Map<String, dynamic>? _selected;
  // Suggestions shown in the dropdown.
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  bool _scanLookupInFlight = false;
  // G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): debounce token —
  // when the user types fast, only the last `Future` after the 300ms
  // pause runs against the server. Pre-fix the picker held all 500
  // products client-side; that broke for tenants with thousands of
  // SKUs.
  String _lastQuery = '';
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    if (_selected != null) {
      _ctl.text = (_selected!['name_ar'] ?? '').toString();
    }
    // Initial fetch — top 20 by code so the dropdown is non-empty
    // when the user clicks the field without typing.
    _search('');
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11): debounced
  /// server-side search. Each keystroke schedules a 300ms timer; if
  /// another keystroke arrives before it fires, the previous request
  /// is cancelled by sequence-number comparison.
  Future<void> _search(String query) async {
    final tid = S.savedTenantId;
    if (tid == null) return;
    _lastQuery = query;
    final mySeq = ++_searchSeq;
    // 300ms debounce
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || mySeq != _searchSeq) return;
    setState(() => _loading = true);
    final res = await ApiService.pilotListProducts(
      tid,
      limit: 20,
      q: query.isEmpty ? null : query,
    );
    if (!mounted || mySeq != _searchSeq) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _suggestions = (res.data as List).cast<Map<String, dynamic>>();
      }
    });
  }

  /// Looks up a barcode against `/pilot/tenants/{tid}/barcode/{value}`.
  /// On hit, auto-selects the product. On miss, opens the modal with
  /// the barcode pre-filled.
  Future<void> _lookupBarcode(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final tid = S.savedTenantId;
    if (tid == null) return;
    setState(() => _scanLookupInFlight = true);
    final res = await ApiService.pilotBarcodeLookup(tid, v);
    if (!mounted) return;
    setState(() => _scanLookupInFlight = false);

    if (res.success && res.data is Map) {
      final hit = (res.data as Map).cast<String, dynamic>();
      final productMap =
          (hit['product'] as Map?)?.cast<String, dynamic>() ?? hit;
      setState(() {
        _selected = productMap;
        _ctl.text = (productMap['name_ar'] ?? '').toString();
      });
      widget.onSelected(productMap);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.ok,
        content: Text(
            'تم العثور على المنتج: ${productMap['name_ar'] ?? ''}'),
      ));
    } else {
      // Miss → offer to create with barcode pre-filled.
      final created = await ProductCreateModal.show(context,
          initialBarcode: v);
      if (created == null || !mounted) return;
      setState(() {
        _suggestions = [..._suggestions, created];
        _selected = created;
        _ctl.text = (created['name_ar'] ?? '').toString();
      });
      widget.onSelected(created);
    }
  }

  Future<void> _openCreateModal({String? prefilledName}) async {
    final created =
        await ProductCreateModal.show(context, initialNameAr: prefilledName);
    if (created == null || !mounted) return;
    setState(() {
      _suggestions = [..._suggestions, created];
      _selected = created;
      _ctl.text = (created['name_ar'] ?? '').toString();
    });
    widget.onSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Autocomplete<Map<String, dynamic>>(
        initialValue: TextEditingValue(text: _ctl.text),
        displayStringForOption: (p) => (p['name_ar'] ?? '').toString(),
        // G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11):
        // optionsBuilder is sync and runs on every keystroke. We
        // schedule a debounced server fetch as a side-effect and
        // return whatever suggestions we already have. The Autocomplete
        // re-runs optionsBuilder when _suggestions changes (via
        // setState), so the dropdown updates ~300ms after typing.
        optionsBuilder: (textValue) {
          final q = textValue.text;
          if (q != _lastQuery) {
            _search(q);
          }
          return _suggestions;
        },
        onSelected: (p) {
          setState(() {
            _selected = p;
            _ctl.text = (p['name_ar'] ?? '').toString();
          });
          widget.onSelected(p);
        },
        fieldViewBuilder: (ctx, ctl, fn, onSubmit) {
          return TextField(
            controller: ctl,
            focusNode: fn,
            style: TextStyle(color: AC.tp, fontSize: 13),
            // Pressing Enter on a numeric-looking value triggers the
            // barcode-lookup path. Useful for hand-entry from a printed
            // shipping doc.
            onSubmitted: (v) {
              final isNumeric = v.trim().isNotEmpty &&
                  int.tryParse(v.trim()) != null;
              if (isNumeric) _lookupBarcode(v);
            },
            decoration: InputDecoration(
              labelText: widget.labelText ?? 'المنتج / الباركود',
              labelStyle: TextStyle(color: AC.td, fontSize: 12),
              hintText: 'اكتب الاسم أو امسح الباركود…',
              hintStyle: TextStyle(color: AC.td, fontSize: 12),
              filled: true,
              fillColor: AC.navy2,
              prefixIcon: (_loading || _scanLookupInFlight)
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Icon(Icons.qr_code_scanner_rounded,
                      color: AC.td, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.qr_code_2_rounded,
                        color: AC.gold, size: 20),
                    onPressed: () => _lookupBarcode(ctl.text),
                    tooltip: 'بحث بالباركود',
                  ),
                  IconButton(
                    icon: Icon(Icons.add_box_rounded,
                        color: AC.gold, size: 20),
                    onPressed: () =>
                        _openCreateModal(prefilledName: ctl.text),
                    tooltip: 'منتج جديد',
                  ),
                ],
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AC.bdr)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AC.bdr)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AC.gold, width: 1.4)),
            ),
          );
        },
        optionsViewBuilder: (ctx, onSelected, options) {
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: Material(
              elevation: 6,
              color: AC.navy2,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 280, maxWidth: 480),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    // G-SALES-INVOICE-MULTILINE-PREFILL (2026-05-11):
                    // dropdown row now shows a stock badge.
                    // total_stock_on_hand comes from ProductRead.
                    // Color: green when stock>0, red when 0, grey for
                    // services (is_stockable=false).
                    ...options.map((p) {
                      final stock = double.tryParse('${p['total_stock_on_hand'] ?? 0}') ?? 0;
                      final stockable = p['is_stockable'] != false;
                      final stockColor = !stockable
                          ? AC.td
                          : (stock > 0 ? AC.ok : AC.err);
                      final stockLabel = !stockable
                          ? 'خدمة'
                          : (stock > 0 ? '${stock.toStringAsFixed(0)} متوفر' : 'نفد');
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.inventory_2_rounded,
                            color: AC.gold, size: 18),
                        title: Text((p['name_ar'] ?? '').toString(),
                            style: TextStyle(
                                color: AC.tp, fontSize: 13)),
                        subtitle: Text(
                            '${p['code'] ?? ''}  •  ${p['default_uom'] ?? ''}',
                            style: TextStyle(
                                color: AC.td, fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: stockColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: stockColor.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(stockLabel,
                              style: TextStyle(
                                  color: stockColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                        onTap: () => onSelected(p),
                      );
                    }),
                    Divider(color: AC.bdr, height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.add_circle_outline,
                          color: AC.gold, size: 18),
                      title: Text('منتج جديد',
                          style: TextStyle(
                              color: AC.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      onTap: () =>
                          _openCreateModal(prefilledName: _ctl.text),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
