/// APEX — CSV export helper (A8 of APEX_IMPROVEMENT_PLAN.md).
///
/// Replaces the SnackBar placeholder on bulk-export buttons with a real
/// browser download. Pure Flutter web — uses dart:html to assemble a Blob
/// and trigger a click on a transient anchor.
///
/// Excel and PDF exports follow in a later commit; CSV covers the
/// most-requested 80% case (open in Excel / Google Sheets / Numbers).
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// One column in the exported CSV.
class ApexCsvColumn<T> {
  final String header;
  final String Function(T row) extract;
  const ApexCsvColumn({required this.header, required this.extract});
}

class ApexCsvExport {
  ApexCsvExport._();

  /// Builds and downloads a CSV file from `rows`.
  ///
  /// `filename` should NOT include the extension — `.csv` is appended.
  /// `bom: true` (default) prefixes the file with a UTF-8 BOM so Excel
  /// opens Arabic columns correctly without manual encoding selection.
  static void download<T>({
    required String filename,
    required List<T> rows,
    required List<ApexCsvColumn<T>> columns,
    bool bom = true,
  }) {
    final csv = _build(rows, columns, bom: bom);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.csv')
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  static String _build<T>(
    List<T> rows,
    List<ApexCsvColumn<T>> columns, {
    bool bom = true,
  }) {
    final buf = StringBuffer();
    if (bom) buf.write('\uFEFF'); // UTF-8 BOM for Excel
    // Header row
    buf.writeln(columns.map((c) => _escape(c.header)).join(','));
    // Data rows
    for (final row in rows) {
      buf.writeln(columns.map((c) => _escape(c.extract(row))).join(','));
    }
    return buf.toString();
  }

  /// CSV-escapes a single field per RFC 4180:
  ///   • Wrap in double quotes if it contains comma, double-quote,
  ///     newline, or leading/trailing whitespace.
  ///   • Escape embedded double-quotes by doubling them.
  static String _escape(String s) {
    final needsQuoting = s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r') ||
        s.startsWith(' ') ||
        s.endsWith(' ');
    if (!needsQuoting) return s;
    return '"${s.replaceAll('"', '""')}"';
  }
}
