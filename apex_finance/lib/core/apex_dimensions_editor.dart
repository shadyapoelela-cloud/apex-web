/// APEX — Dimensions Editor (SAP Intacct pattern)
/// ═══════════════════════════════════════════════════════════
/// Edits the line-level `dimensions` JSONB field on a journal line.
/// Presents 4 well-known accounting dimensions (project / department /
/// cost center / profit center) as autocomplete inputs PLUS a
/// free-form "custom" section for any tenant-specific tag.
///
/// Keeps everything typeahead + chip-based — no modal explosion of
/// fields. Matches Odoo's "Analytic Tags" density pattern.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Standard dimension keys — extend via the custom section.
const kStandardDimensionKeys = <String>[
  'project',
  'department',
  'cost_center',
  'profit_center',
];

class ApexDimensionsEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final void Function(Map<String, String>) onChanged;
  final bool compact;
  const ApexDimensionsEditor({
    super.key,
    this.initial,
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<ApexDimensionsEditor> createState() => _ApexDimensionsEditorState();
}

class _ApexDimensionsEditorState extends State<ApexDimensionsEditor> {
  late Map<String, String> _values;
  final _customKeyCtl = TextEditingController();
  final _customValCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _values = {
      for (final entry in (widget.initial ?? {}).entries)
        entry.key: '${entry.value}',
    };
  }

  @override
  void dispose() {
    _customKeyCtl.dispose();
    _customValCtl.dispose();
    super.dispose();
  }

  void _set(String key, String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _values.remove(key);
      } else {
        _values[key] = value.trim();
      }
    });
    widget.onChanged(Map.of(_values));
  }

  void _addCustom() {
    final k = _customKeyCtl.text.trim();
    final v = _customValCtl.text.trim();
    if (k.isEmpty || v.isEmpty) return;
    setState(() {
      _values[k] = v;
      _customKeyCtl.clear();
      _customValCtl.clear();
    });
    widget.onChanged(Map.of(_values));
  }

  void _remove(String key) {
    setState(() => _values.remove(key));
    widget.onChanged(Map.of(_values));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AC.gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.compact)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.label_outline, size: 14, color: AC.gold),
                  const SizedBox(width: 6),
                  Text('الأبعاد المحاسبية',
                      style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          // Standard keys
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chipInput('project', 'مشروع'),
              _chipInput('department', 'قسم'),
              _chipInput('cost_center', 'مركز تكلفة'),
              _chipInput('profit_center', 'مركز ربحية'),
            ],
          ),
          // Custom keys (not in the standard list)
          if (_values.keys.any((k) => !kStandardDimensionKeys.contains(k))) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AC.gold.withValues(alpha: 0.12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _values.entries
                  .where((e) => !kStandardDimensionKeys.contains(e.key))
                  .map((e) => _customChip(e.key, e.value))
                  .toList(),
            ),
          ],
          if (!widget.compact) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _customKeyCtl,
                    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: 'المفتاح',
                      hintStyle: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 11),
                      isDense: true, filled: true, fillColor: AC.navy2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _customValCtl,
                    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: 'القيمة',
                      hintStyle: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 11),
                      isDense: true, filled: true, fillColor: AC.navy2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: AC.gold, size: 18),
                  onPressed: _addCustom,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipInput(String key, String labelAr) {
    final hasValue = _values.containsKey(key) && _values[key]!.isNotEmpty;
    final ctl = TextEditingController(text: _values[key] ?? '');
    return SizedBox(
      width: 160,
      child: TextField(
        controller: ctl,
        style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 11.5),
        decoration: InputDecoration(
          labelText: labelAr,
          labelStyle: TextStyle(color: hasValue ? AC.gold : AC.ts, fontFamily: 'Tajawal', fontSize: 10.5),
          isDense: true, filled: true, fillColor: AC.navy2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: hasValue ? AC.gold.withValues(alpha: 0.5) : Colors.transparent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: hasValue ? AC.gold.withValues(alpha: 0.5) : Colors.transparent),
          ),
        ),
        onChanged: (v) => _set(key, v),
      ),
    );
  }

  Widget _customChip(String key, String value) {
    return InputChip(
      label: Text('$key: $value', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
      backgroundColor: AC.gold.withValues(alpha: 0.12),
      side: BorderSide(color: AC.gold.withValues(alpha: 0.4)),
      labelStyle: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
      deleteIcon: Icon(Icons.close, size: 14, color: AC.err),
      onDeleted: () => _remove(key),
    );
  }
}


/// Read-only pill-row for display in lists.
class ApexDimensionsPills extends StatelessWidget {
  final Map<String, dynamic>? dimensions;
  const ApexDimensionsPills({super.key, this.dimensions});

  @override
  Widget build(BuildContext context) {
    final d = dimensions;
    if (d == null || d.isEmpty) {
      return Text('لا أبعاد', style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: d.entries.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${_labelFor(e.key)}: ${e.value}',
          style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 10),
        ),
      )).toList(),
    );
  }

  String _labelFor(String key) {
    const map = {
      'project': 'مشروع',
      'department': 'قسم',
      'cost_center': 'مركز ت',
      'profit_center': 'مركز ر',
    };
    return map[key] ?? key;
  }
}
