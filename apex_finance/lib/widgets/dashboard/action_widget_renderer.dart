/// Action renderer — quick CTAs / mini-forms.
///
/// Two payload shapes accepted:
/// ```
/// // Plain CTA   (default)
/// {
///   "action": "open_screen",
///   "target": "/app/erp/sales/invoice-create",
///   "label_ar": "فاتورة سريعة",
///   "icon": "add_circle"
/// }
/// // Mini-form (when configSchema declares fields)
/// def.config_schema = {
///   "fields": [
///     {"key": "amount", "type": "number", "label_ar": "المبلغ"},
///     {"key": "customer_id", "type": "select", "label_ar": "العميل",
///      "options_endpoint": "/customers?limit=5"}
///   ],
///   "submit": {"endpoint": "/pilot/invoices?quick=true"}
/// }
/// ```
///
/// The mini-form is intentionally minimal — heavy data entry should
/// open the full screen via the plain CTA branch.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '_base.dart';

class ActionWidgetRenderer implements DashboardWidgetRenderer {
  const ActionWidgetRenderer();

  @override
  Widget render(
    BuildContext context,
    DashboardCatalogEntry def,
    Map<String, dynamic>? payload, {
    VoidCallback? onRetry,
  }) {
    if (payload == null) {
      return renderErrorState(
        context: context,
        titleAr: 'جارٍ تحضير الإجراء…',
        onRetry: onRetry,
      );
    }
    if (payload.containsKey('error') && payload['error'] != null) {
      return renderErrorState(
        context: context,
        titleAr: def.titleAr,
        message: payload['error']?.toString(),
        onRetry: onRetry,
      );
    }

    final fields = _extractFields(def);
    if (fields.isEmpty) {
      return _ctaCard(context, def, payload);
    }
    return _MiniForm(def: def, payload: payload, fields: fields);
  }

  Widget _ctaCard(
    BuildContext context,
    DashboardCatalogEntry def,
    Map<String, dynamic> payload,
  ) {
    final label = (payload['label_ar'] ?? def.titleAr).toString();
    final target = payload['target'] as String?;
    final iconKey = payload['icon'] as String? ?? 'add_circle';

    return Container(
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: target == null ? null : () => context.go(target),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_resolveIcon(iconKey), size: 32, color: AC.gold),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AC.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _resolveIcon(String key) {
    switch (key) {
      case 'add_circle':
        return Icons.add_circle_outline;
      case 'receipt':
        return Icons.receipt_long;
      case 'payments':
        return Icons.payments_outlined;
      case 'check':
        return Icons.task_alt_outlined;
      default:
        return Icons.bolt;
    }
  }

  List<_FieldSpec> _extractFields(DashboardCatalogEntry def) {
    final schema = def.configSchema;
    if (schema == null) return const [];
    final raw = schema['fields'];
    if (raw is! List) return const [];
    return [
      for (final f in raw.whereType<Map>())
        _FieldSpec(
          key: (f['key'] ?? '') as String,
          type: (f['type'] ?? 'text') as String,
          label: (f['label_ar'] ?? f['key'] ?? '') as String,
          options: (f['options'] as List?)?.cast<dynamic>().toList() ??
              const [],
        ),
    ];
  }
}

class _FieldSpec {
  final String key;
  final String type;
  final String label;
  final List<dynamic> options;
  const _FieldSpec({
    required this.key,
    required this.type,
    required this.label,
    this.options = const [],
  });
}

class _MiniForm extends StatefulWidget {
  final DashboardCatalogEntry def;
  final Map<String, dynamic> payload;
  final List<_FieldSpec> fields;

  const _MiniForm({
    required this.def,
    required this.payload,
    required this.fields,
  });

  @override
  State<_MiniForm> createState() => _MiniFormState();
}

class _MiniFormState extends State<_MiniForm> {
  final _form = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() => _submitting = true);
    try {
      // TODO(DASH-1.1): wire submit endpoint when configSchema['submit']
      // is present. For now we only collect values + show a toast so
      // the form is testable end-to-end without a backend round-trip.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استلام: ${_values.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      padding: const EdgeInsets.all(12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.def.titleAr,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final f in widget.fields) _buildField(f),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AC.gold,
                  foregroundColor: AC.btnFg,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(_submitting ? 'جارٍ الإرسال…' : 'إنشاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(_FieldSpec f) {
    switch (f.type) {
      case 'number':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: TextFormField(
            decoration: InputDecoration(labelText: f.label, isDense: true),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            onSaved: (v) => _values[f.key] = num.tryParse(v ?? ''),
          ),
        );
      case 'select':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: DropdownButtonFormField<dynamic>(
            decoration: InputDecoration(labelText: f.label, isDense: true),
            items: [
              for (final o in f.options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o.toString()),
                ),
            ],
            onChanged: (v) => _values[f.key] = v,
            validator: (v) => v == null ? 'مطلوب' : null,
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: TextFormField(
            decoration: InputDecoration(labelText: f.label, isDense: true),
            validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            onSaved: (v) => _values[f.key] = v,
          ),
        );
    }
  }
}
