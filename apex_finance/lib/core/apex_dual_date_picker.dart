/// APEX — Dual Hijri + Gregorian Date Picker
/// ═══════════════════════════════════════════════════════════════════════
/// Saudi accounting needs both calendars side-by-side. This widget shows
/// the standard Material date picker for Gregorian + a live Hijri preview
/// of the selected date.
///
/// Wedge feature (gap analysis P2 #12) — no Saudi competitor offers a
/// fully-functional dual-calendar input.
library;

import 'package:flutter/material.dart';
import 'hijri_date.dart';
import 'theme.dart';

class ApexDualDatePicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final String label;
  final String? hint;
  final bool enabled;

  const ApexDualDatePicker({
    super.key,
    this.value,
    this.onChanged,
    required this.label,
    this.hint,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AC.gold,
            onPrimary: AC.navy,
            surface: AC.navy2,
            onSurface: AC.tp,
          ),
          dialogTheme: DialogTheme(backgroundColor: AC.navy),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged?.call(picked);
  }

  String _fmtGregorian(DateTime? d) {
    if (d == null) return 'اختر التاريخ';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} م';
  }

  @override
  Widget build(BuildContext context) {
    final hijri = value == null ? null : HijriDate.fromGregorian(value!);
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy3,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, color: AC.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: AC.ts, fontSize: 11)),
              const SizedBox(height: 2),
              Text(_fmtGregorian(value),
                  style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
              if (hijri != null) ...[
                const SizedBox(height: 1),
                Text('الموافق ${hijri.formatLong()}',
                    style: TextStyle(color: AC.gold, fontSize: 11)),
              ],
            ]),
          ),
          Icon(Icons.expand_more, color: AC.ts, size: 16),
        ]),
      ),
    );
  }
}
