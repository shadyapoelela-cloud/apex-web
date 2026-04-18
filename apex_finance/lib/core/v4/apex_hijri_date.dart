/// APEX V4 — Hijri / Gregorian dual date utilities (Wave 2 PR#2).
///
/// Pattern #134 from APEX_GLOBAL_RESEARCH_210: "Hijri date picker عبر
/// كل حقول التاريخ + Umm al-Qura — الحد الأدنى، لا أحد يتقنه".
///
/// Storage is always ISO 8601 UTC (Gregorian). Hijri is a DISPLAY
/// format on top. That keeps the back-end untouched — no column
/// changes — and lets us swap calendars per-user later via
/// SharedPreferences without data migrations.
///
/// Depends on the `hijri` package (Umm al-Qura calendar 1356-1500 AH).
library;

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' as intl;

import '../design_tokens.dart';
import '../theme.dart';
import 'apex_numerals.dart';

enum CalendarMode { gregorian, hijri }

class ApexHijriDate {
  /// Format a DateTime as "14 شوال 1447 هـ" (Hijri) or "2026-04-18"
  /// (Gregorian), respecting the numeral mode of the nearest
  /// ApexNumerals host for digits.
  static String format(
    BuildContext ctx,
    DateTime dt, {
    CalendarMode? mode,
    String gregorianPattern = 'yyyy-MM-dd',
  }) {
    final effective = mode ?? CalendarMode.gregorian;
    if (effective == CalendarMode.hijri) {
      final h = HijriCalendar.fromDate(dt);
      final raw = '${h.hDay} ${_hijriMonthAr(h.hMonth)} '
          '${h.hYear} هـ';
      return ApexNumeral.format(ctx, raw);
    }
    final raw = intl.DateFormat(gregorianPattern).format(dt);
    return ApexNumeral.format(ctx, raw);
  }

  /// Side-by-side string "2026-04-18 · 1 شوال 1447 هـ" for invoices,
  /// audit reports, and anywhere dual-display matters.
  static String bothInline(
    BuildContext ctx,
    DateTime dt, {
    String separator = ' · ',
  }) {
    final g = format(ctx, dt, mode: CalendarMode.gregorian);
    final h = format(ctx, dt, mode: CalendarMode.hijri);
    return '$g$separator$h';
  }

  static String _hijriMonthAr(int m) {
    const names = [
      '', // index 0 unused
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    if (m < 1 || m > 12) return '';
    return names[m];
  }
}

/// Renders a date as a column of two labels: large = active calendar,
/// small muted = the other. Tapping swaps which one is primary.
/// Drop into form fields, timeline headers, invoice headers, etc.
class ApexDualDateLabel extends StatefulWidget {
  final DateTime date;
  final CalendarMode initial;

  const ApexDualDateLabel({
    super.key,
    required this.date,
    this.initial = CalendarMode.gregorian,
  });

  @override
  State<ApexDualDateLabel> createState() => _ApexDualDateLabelState();
}

class _ApexDualDateLabelState extends State<ApexDualDateLabel> {
  late CalendarMode _mode = widget.initial;

  void _swap() => setState(
        () => _mode = _mode == CalendarMode.gregorian
            ? CalendarMode.hijri
            : CalendarMode.gregorian,
      );

  @override
  Widget build(BuildContext context) {
    final primary =
        ApexHijriDate.format(context, widget.date, mode: _mode);
    final secondary = ApexHijriDate.format(
      context,
      widget.date,
      mode: _mode == CalendarMode.gregorian
          ? CalendarMode.hijri
          : CalendarMode.gregorian,
    );

    return InkWell(
      onTap: _swap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              primary,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.base,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              secondary,
              style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.xs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
