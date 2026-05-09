/// VendorPickerOrCreate — G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09).
///
/// Mirror of CustomerPickerOrCreate for vendors. Used by Sprint 6's
/// Purchase Invoice line picker. Searches `legal_name_ar`, `trade_name`,
/// `code`, `vat_number` against the cached vendor list and offers an
/// inline "+ مورد جديد" that opens VendorCreateModal pre-filled with
/// the typed query.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../screens/operations/vendor_create_modal.dart';

class VendorPickerOrCreate extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final String? labelText;

  const VendorPickerOrCreate({
    super.key,
    required this.onSelected,
    this.initial,
    this.labelText,
  });

  @override
  State<VendorPickerOrCreate> createState() => _VendorPickerOrCreateState();
}

class _VendorPickerOrCreateState extends State<VendorPickerOrCreate> {
  final _ctl = TextEditingController();
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _all = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    if (_selected != null) {
      _ctl.text = (_selected!['legal_name_ar'] ?? '').toString();
    }
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tid = S.savedTenantId;
    if (tid == null) return;
    setState(() => _loading = true);
    final res = await ApiService.pilotListVendors(tid, limit: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      }
    });
  }

  List<Map<String, dynamic>> _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return _all.take(10).toList();
    return _all.where((v) {
      final hay = [
        v['code'],
        v['legal_name_ar'],
        v['legal_name_en'],
        v['trade_name'],
        v['vat_number'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
      return hay.contains(query);
    }).take(10).toList();
  }

  Future<void> _openCreateModal({String? prefilledName}) async {
    final created = await VendorCreateModal.show(
      context,
      initialNameAr: prefilledName,
    );
    if (created == null || !mounted) return;
    setState(() {
      _all = [..._all, created];
      _selected = created;
      _ctl.text = (created['legal_name_ar'] ?? '').toString();
    });
    widget.onSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Autocomplete<Map<String, dynamic>>(
        initialValue: TextEditingValue(text: _ctl.text),
        displayStringForOption: (v) => (v['legal_name_ar'] ?? '').toString(),
        optionsBuilder: (textValue) => _filter(textValue.text),
        onSelected: (v) {
          setState(() {
            _selected = v;
            _ctl.text = (v['legal_name_ar'] ?? '').toString();
          });
          widget.onSelected(v);
        },
        fieldViewBuilder: (ctx, ctl, fn, onSubmit) {
          return TextField(
            controller: ctl,
            focusNode: fn,
            style: TextStyle(color: AC.tp, fontSize: 13),
            decoration: InputDecoration(
              labelText: widget.labelText ?? 'المورد',
              labelStyle: TextStyle(color: AC.td, fontSize: 12),
              hintText: 'اكتب اسم المورد أو الكود…',
              hintStyle: TextStyle(color: AC.td, fontSize: 12),
              filled: true,
              fillColor: AC.navy2,
              prefixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Icon(Icons.search, color: AC.td, size: 18),
              suffixIcon: IconButton(
                icon: Icon(Icons.add_business_rounded,
                    color: AC.gold, size: 20),
                onPressed: () => _openCreateModal(prefilledName: ctl.text),
                tooltip: 'مورد جديد',
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AC.bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AC.bdr),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AC.gold, width: 1.4),
              ),
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
                    ...options.map((v) => ListTile(
                          dense: true,
                          leading: Icon(Icons.factory_rounded,
                              color: AC.gold, size: 18),
                          title: Text(
                              (v['legal_name_ar'] ?? '').toString(),
                              style: TextStyle(
                                  color: AC.tp, fontSize: 13)),
                          subtitle: Text(
                              '${v['code'] ?? ''}  •  ${v['vat_number'] ?? ''}',
                              style: TextStyle(
                                  color: AC.td, fontSize: 11)),
                          onTap: () => onSelected(v),
                        )),
                    Divider(color: AC.bdr, height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.add_circle_outline,
                          color: AC.gold, size: 18),
                      title: Text('مورد جديد',
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
