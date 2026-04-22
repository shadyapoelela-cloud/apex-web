/// APEX V5.1 — Find & Recode (Enhancement #5).
///
/// Xero's "killer feature" — select 100 transactions by filter,
/// bulk-change an attribute (account, category, project) in one action.
///
/// Competitive gap:
///   - Xero: has Find & Recode ✓
///   - QuickBooks: partial (reclassify tool)
///   - Wafeq / Qoyod / Odoo: ❌ absent
///   - NetSuite: batch but requires admin
///
/// APEX offers this to every accountant, with Arabic-native UX and
/// global Undo integration.
///
/// Usage:
///   ApexV5FindAndRecodeBar(
///     selectedCount: selectedIds.length,
///     onRecodeTap: () { ... },
///     onExportTap: () { ... },
///     onClear: () => setState(() => selectedIds.clear()),
///   )
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;

import 'apex_v5_undo_toast.dart';

/// Floating bottom bar that appears when items are selected.
class ApexV5FindAndRecodeBar extends StatelessWidget {
  final int selectedCount;
  final String itemTypeLabelAr;
  final VoidCallback? onRecodeTap;
  final VoidCallback? onExportTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback onClear;

  const ApexV5FindAndRecodeBar({
    super.key,
    required this.selectedCount,
    required this.itemTypeLabelAr,
    required this.onClear,
    this.onRecodeTap,
    this.onExportTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: core_theme.AC.tp.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: core_theme.AC.gold,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$selectedCount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'تم تحديد $selectedCount $itemTypeLabelAr',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Container(height: 20, width: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(width: 16),
          // Actions
          _BarAction(
            icon: Icons.swap_horiz,
            labelAr: 'إعادة تصنيف',
            onTap: onRecodeTap,
            primary: true,
          ),
          const SizedBox(width: 8),
          _BarAction(
            icon: Icons.download,
            labelAr: 'تصدير',
            onTap: onExportTap,
          ),
          const SizedBox(width: 8),
          if (onDeleteTap != null)
            _BarAction(
              icon: Icons.delete_outline,
              labelAr: 'حذف',
              onTap: onDeleteTap,
              destructive: true,
            ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: onClear,
            tooltip: 'إلغاء التحديد',
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatefulWidget {
  final IconData icon;
  final String labelAr;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;

  const _BarAction({
    required this.icon,
    required this.labelAr,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
  });

  @override
  State<_BarAction> createState() => _BarActionState();
}

class _BarActionState extends State<_BarAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final bgColor = widget.primary
        ? core_theme.AC.gold
        : widget.destructive
            ? const Color(0xFFB91C1C)
            : Colors.white.withOpacity(_hover ? 0.15 : 0.08);
    final fgColor = widget.primary || widget.destructive
        ? Colors.white
        : Colors.white;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 14, color: fgColor),
                const SizedBox(width: 5),
                Text(
                  widget.labelAr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recode dialog — shows what's changing before confirming.
class ApexV5RecodeDialog extends StatefulWidget {
  final int count;
  final String itemTypeLabelAr;
  final List<V5RecodeField> fields;
  final void Function(Map<String, String> newValues) onConfirm;

  const ApexV5RecodeDialog({
    super.key,
    required this.count,
    required this.itemTypeLabelAr,
    required this.fields,
    required this.onConfirm,
  });

  @override
  State<ApexV5RecodeDialog> createState() => _ApexV5RecodeDialogState();

  static Future<void> show({
    required BuildContext context,
    required int count,
    required String itemTypeLabelAr,
    required List<V5RecodeField> fields,
    required void Function(Map<String, String> newValues) onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ApexV5RecodeDialog(
          count: count,
          itemTypeLabelAr: itemTypeLabelAr,
          fields: fields,
          onConfirm: (vals) {
            Navigator.of(ctx).pop();
            onConfirm(vals);
          },
        ),
      ),
    );
  }
}

class V5RecodeField {
  final String key;
  final String labelAr;
  final List<V5RecodeOption> options;

  V5RecodeField({
    required this.key,
    required this.labelAr,
    required this.options,
  });
}

class V5RecodeOption {
  final String value;
  final String labelAr;
  V5RecodeOption(this.value, this.labelAr);
}

class _ApexV5RecodeDialogState extends State<ApexV5RecodeDialog> {
  final _newValues = <String, String>{};

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: core_theme.AC.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.swap_horiz, color: core_theme.AC.gold, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إعادة تصنيف جماعية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'سيتم تعديل ${widget.count} ${widget.itemTypeLabelAr}',
                      style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر الحقول المطلوب تغييرها:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final field in widget.fields) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: field.labelAr,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('— لا تغيير —')),
                    for (final opt in field.options)
                      DropdownMenuItem(value: opt.value, child: Text(opt.labelAr)),
                  ],
                  value: _newValues[field.key] ?? '',
                  onChanged: (v) {
                    setState(() {
                      if (v == null || v.isEmpty) {
                        _newValues.remove(field.key);
                      } else {
                        _newValues[field.key] = v;
                      }
                    });
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: core_theme.AC.warn.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 14, color: core_theme.AC.warn),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذه العملية قابلة للتراجع باستخدام Cmd+Z خلال 10 ثواني',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _newValues.isEmpty
                      ? null
                      : () => widget.onConfirm(_newValues),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('تطبيق على ${widget.count}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: core_theme.AC.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience: show recode dialog + Undo toast integration.
void showRecodeDialogWithUndo({
  required BuildContext context,
  required int count,
  required String itemTypeLabelAr,
  required List<V5RecodeField> fields,
  required void Function(Map<String, String>) apply,
  required VoidCallback undo,
}) {
  ApexV5RecodeDialog.show(
    context: context,
    count: count,
    itemTypeLabelAr: itemTypeLabelAr,
    fields: fields,
    onConfirm: (newValues) {
      apply(newValues);
      ApexV5UndoToast.show(
        context,
        messageAr: 'تم تعديل $count $itemTypeLabelAr',
        onUndo: undo,
      );
    },
  );
}
