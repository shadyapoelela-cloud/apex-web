/// APEX — Hijri ↔ Gregorian conversion (lightweight)
/// ═══════════════════════════════════════════════════════════════════════
/// Pure Dart, no plugins. Uses the Umm al-Qura algorithm approximation
/// (Kuwaiti method, accurate within ±1 day vs official KSA tables).
///
/// One of the gap analysis P2 differentiators (#12): no Saudi competitor
/// renders Hijri natively across the UI. We start by displaying it on
/// the Today dashboard header next to the Gregorian date.
library;

class HijriDate {
  final int year;
  final int month;
  final int day;
  const HijriDate({required this.year, required this.month, required this.day});

  static const _months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  /// Approximate Gregorian → Hijri (Kuwaiti method).
  /// Reference: Fliegel and Van Flandern (1968) + tabular adjustments.
  static HijriDate fromGregorian(DateTime g) {
    int jd;
    if (g.year > 1582 ||
        (g.year == 1582 && g.month > 10) ||
        (g.year == 1582 && g.month == 10 && g.day > 14)) {
      jd = ((1461 * (g.year + 4800 + ((g.month - 14) ~/ 12))) ~/ 4) +
          ((367 * (g.month - 2 - 12 * (((g.month - 14) ~/ 12)))) ~/ 12) -
          ((3 * (((g.year + 4900 + ((g.month - 14) ~/ 12)) ~/ 100))) ~/ 4) +
          g.day - 32075;
    } else {
      jd = 367 * g.year -
          ((7 * (g.year + 5001 + ((g.month - 9) ~/ 7))) ~/ 4) +
          ((275 * g.month) ~/ 9) +
          g.day +
          1729777;
    }
    final l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    final l2 = l - 10631 * n + 354;
    final j = ((10985 - l2) ~/ 5316) * ((50 * l2) ~/ 17719) +
        (l2 ~/ 5670) * ((43 * l2) ~/ 15238);
    final l3 = l2 - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final m = (24 * l3) ~/ 709;
    final d = l3 - (709 * m) ~/ 24;
    final y = 30 * n + j - 30;
    return HijriDate(year: y, month: m, day: d);
  }

  String get monthName => _months[(month - 1).clamp(0, 11)];

  /// Renders as "د شهر سنة هـ" in Arabic, e.g. "15 رمضان 1447 هـ".
  String formatLong() => '$day $monthName $year هـ';

  /// Renders as "yyyy/mm/dd هـ" — compact form for invoices/PDFs.
  String formatShort() =>
      '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')} هـ';

  @override
  String toString() => formatLong();
}
