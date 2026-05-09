/// CustomerPickerOrCreate — G-FIN-CUSTOMERS-COMPLETE (Sprint 2, 2026-05-09).
///
/// A reusable form-field widget that:
///   1. Autocompletes against `GET /pilot/tenants/{tid}/customers`
///   2. Shows a "+ عميل جديد" inline option when no match exists
///   3. On the inline-create path, opens `CustomerCreateModal` and
///      auto-selects the new customer once it's saved.
///
/// Designed for Sales Invoice line picker (Sprint 5) but also useful in
/// the dunning, AR-aging drill-in, and "send to customer" paths.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../screens/operations/customer_create_modal.dart';

class CustomerPickerOrCreate extends StatefulWidget {
  /// Initial selected customer (for edit flows). null = nothing selected.
  final Map<String, dynamic>? initial;

  /// Fired when the user selects a customer (existing or newly created).
  final ValueChanged<Map<String, dynamic>> onSelected;

  /// Optional decoration override.
  final String? labelText;

  const CustomerPickerOrCreate({
    super.key,
    required this.onSelected,
    this.initial,
    this.labelText,
  });

  @override
  State<CustomerPickerOrCreate> createState() => _CustomerPickerOrCreateState();
}

class _CustomerPickerOrCreateState extends State<CustomerPickerOrCreate> {
  final _ctl = TextEditingController();
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _all = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    if (_selected != null) {
      _ctl.text = (_selected!['name_ar'] ?? '').toString();
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
    final res = await ApiService.pilotListCustomers(tid, limit: 500);
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
    return _all.where((c) {
      final hay = [
        c['code'],
        c['name_ar'],
        c['name_en'],
        c['phone'],
        c['vat_number'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
      return hay.contains(query);
    }).take(10).toList();
  }

  Future<void> _openCreateModal({String? prefilledName}) async {
    final created = await CustomerCreateModal.show(
      context,
      initialNameAr: prefilledName,
    );
    if (created == null || !mounted) return;
    setState(() {
      _all = [..._all, created];
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
        displayStringForOption: (c) => (c['name_ar'] ?? '').toString(),
        optionsBuilder: (textValue) => _filter(textValue.text),
        onSelected: (c) {
          setState(() {
            _selected = c;
            _ctl.text = (c['name_ar'] ?? '').toString();
          });
          widget.onSelected(c);
        },
        fieldViewBuilder: (ctx, ctl, fn, onSubmit) {
          return TextField(
            controller: ctl,
            focusNode: fn,
            style: TextStyle(color: AC.tp, fontSize: 13),
            decoration: InputDecoration(
              labelText: widget.labelText ?? 'العميل',
              labelStyle: TextStyle(color: AC.td, fontSize: 12),
              hintText: 'اكتب اسم العميل أو الكود…',
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
                icon: Icon(Icons.person_add_alt_1_rounded,
                    color: AC.gold, size: 20),
                onPressed: () => _openCreateModal(prefilledName: ctl.text),
                tooltip: 'عميل جديد',
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
                constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    ...options.map((c) => ListTile(
                          dense: true,
                          leading: Icon(Icons.business_rounded,
                              color: AC.gold, size: 18),
                          title: Text((c['name_ar'] ?? '').toString(),
                              style: TextStyle(
                                  color: AC.tp, fontSize: 13)),
                          subtitle: Text(
                              '${c['code'] ?? ''}  •  ${c['phone'] ?? ''}',
                              style: TextStyle(
                                  color: AC.td, fontSize: 11)),
                          onTap: () => onSelected(c),
                        )),
                    Divider(color: AC.bdr, height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.add_circle_outline,
                          color: AC.gold, size: 18),
                      title: Text('عميل جديد',
                          style: TextStyle(
                              color: AC.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      onTap: () => _openCreateModal(prefilledName: _ctl.text),
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
