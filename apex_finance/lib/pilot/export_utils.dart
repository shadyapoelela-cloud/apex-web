/// Export utilities — CSV/Excel/Print for financial reports.
///
/// Flutter Web: يستخدم dart:html لتحميل الملفات مباشرة للمتصفح.
/// لا حاجة لخادم — كل التحويل client-side.
library;

import 'dart:convert';
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// تحميل ملف إلى المتصفح (Flutter Web only).
void downloadBytes(List<int> bytes, String filename, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// تصدير قائمة صفوف إلى CSV وتحميلها.
///
/// [headers]: أسماء الأعمدة بالعربية (السطر الأول)
/// [rows]: قائمة السجلات
/// [filename]: اسم الملف بدون extension
void exportCsv({
  required List<String> headers,
  required List<List<dynamic>> rows,
  required String filename,
}) {
  final data = <List<dynamic>>[headers, ...rows];
  // CRLF (\r\n) مطلوب لفتح Excel على Windows بشكل نظيف، وإلا الكل في صف واحد
  final csvString = const ListToCsvConverter(eol: '\r\n').convert(data);
  // أضف BOM للـ UTF-8 حتى يفتح Excel العربية بشكل صحيح
  final bom = [0xEF, 0xBB, 0xBF];
  final bytes = [...bom, ...utf8.encode(csvString)];
  downloadBytes(bytes, '$filename.csv', 'text/csv;charset=utf-8');
}

/// تصدير قائمة صفوف إلى Excel XLSX مع تنسيق أساسي وتحميلها.
void exportXlsx({
  required List<String> headers,
  required List<List<dynamic>> rows,
  required String filename,
  String sheetName = 'Sheet1',
  String? title,
  Map<String, dynamic>? meta,
}) {
  final excel = Excel.createExcel();
  // ملاحظة لحزمة excel-4.0.6:
  //   rename() → ينسخ ثم يحذف، لكن الحذف يتطلب length>1 في وقت الحذف
  //   (بالفعل 2 بعد النسخ)، لكن XML metadata لا تُحدَّث دائماً
  //   فيَنتج ملف بـ ورقتين (الأصلية فارغة + الجديدة).
  //   الحل الموثوق: استخدام الورقة الافتراضية مباشرة + إعادة تسميتها لاحقاً
  //   بعد كتابة البيانات.
  final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
  final sheet = excel[defaultSheetName];

  int rowIdx = 0;

  // العنوان
  if (title != null) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
    cell.value = TextCellValue(title);
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );
    rowIdx += 2;
  }

  // metadata rows
  if (meta != null && meta.isNotEmpty) {
    for (final entry in meta.entries) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          .value = TextCellValue(entry.key);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
          .value = TextCellValue(entry.value.toString());
      rowIdx++;
    }
    rowIdx++;
  }

  // Header row
  for (int i = 0; i < headers.length; i++) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIdx));
    cell.value = TextCellValue(headers[i]);
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#D4AF37'),
    );
  }
  rowIdx++;

  // Data rows
  for (final row in rows) {
    for (int i = 0; i < row.length; i++) {
      final value = row[i];
      CellValue? cellValue;
      if (value == null) {
        cellValue = TextCellValue('');
      } else if (value is num) {
        cellValue = DoubleCellValue(value.toDouble());
      } else if (value is bool) {
        cellValue = BoolCellValue(value);
      } else if (value is DateTime) {
        cellValue = DateTimeCellValue.fromDateTime(value);
      } else {
        // جرّب تحويل String إلى رقم لو ممكن
        final s = value.toString();
        final asNum = double.tryParse(s);
        if (asNum != null) {
          cellValue = DoubleCellValue(asNum);
        } else {
          cellValue = TextCellValue(s);
        }
      }
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIdx))
          .value = cellValue;
    }
    rowIdx++;
  }

  // بعد كتابة البيانات: أعد تسمية الورقة الافتراضية إلى sheetName
  // (إن اختلف). rename() سيعمل الآن لأن البيانات موجودة فعلاً.
  if (defaultSheetName != sheetName) {
    try {
      excel.rename(defaultSheetName, sheetName);
      excel.setDefaultSheet(sheetName);
    } catch (_) {/* لو فشل، تبقى الورقة باسم Sheet1 — لا مشكلة */}
  }

  final bytes = excel.save(fileName: '$filename.xlsx');
  if (bytes != null) {
    downloadBytes(
      bytes,
      '$filename.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}

/// طباعة/حفظ PDF — يستخدم window.print() في Flutter Web.
/// المستخدم يختار "Save as PDF" من printer dialog للمتصفح.
void printCurrentPage() {
  html.window.print();
}

/// فتح نافذة طباعة بمحتوى HTML مخصص (رأس شركة + table).
void printHtmlTable({
  required String title,
  required String companyName,
  String? companyMeta,
  required List<String> headers,
  required List<List<String>> rows,
  String? footer,
  String? logoUrl,
  String primaryColor = '#D4AF37',
}) {
  final buffer = StringBuffer();
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html dir="rtl" lang="ar">');
  buffer.writeln('<head>');
  buffer.writeln('<meta charset="UTF-8">');
  buffer.writeln('<title>$title</title>');
  buffer.writeln('<style>');
  buffer.writeln('''
    @media print { @page { size: A4; margin: 1cm; } }
    body { font-family: 'Arial', 'Tahoma', sans-serif; color: #333; margin: 0; padding: 20px; }
    .header { display: flex; align-items: center; justify-content: space-between;
              border-bottom: 3px solid $primaryColor; padding-bottom: 10px; margin-bottom: 20px; }
    .logo { max-height: 60px; max-width: 180px; }
    .company { font-size: 18px; font-weight: bold; color: $primaryColor; }
    .meta { font-size: 11px; color: #666; }
    .title { text-align: center; font-size: 22px; font-weight: bold; color: $primaryColor;
             margin: 20px 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
    th { background: ${primaryColor}15; color: $primaryColor; padding: 10px 8px;
         border-bottom: 2px solid $primaryColor; text-align: right; font-weight: bold; }
    td { padding: 8px; border-bottom: 1px solid #eee; text-align: right; }
    tr:nth-child(even) td { background: #fafafa; }
    .num { font-family: 'Courier New', monospace; text-align: left; }
    .footer { margin-top: 30px; padding-top: 10px; border-top: 1px solid #ddd;
              font-size: 10px; color: #888; text-align: center; }
    .print-btn { background: $primaryColor; color: white; border: none; padding: 10px 20px;
                 border-radius: 6px; cursor: pointer; margin: 10px; }
    @media print { .print-btn { display: none; } }
  ''');
  buffer.writeln('</style>');
  buffer.writeln('</head><body>');
  buffer.writeln(
      '<button class="print-btn" onclick="window.print()">🖨️ طباعة / حفظ PDF</button>');

  // Header
  buffer.writeln('<div class="header">');
  buffer.writeln('<div>');
  buffer.writeln('<div class="company">${_escape(companyName)}</div>');
  if (companyMeta != null && companyMeta.isNotEmpty) {
    buffer.writeln('<div class="meta">${_escape(companyMeta)}</div>');
  }
  buffer.writeln('</div>');
  if (logoUrl != null && logoUrl.isNotEmpty) {
    buffer.writeln('<img src="${_escape(logoUrl)}" class="logo" alt="logo">');
  }
  buffer.writeln('</div>');

  // Title
  buffer.writeln('<div class="title">${_escape(title)}</div>');

  // Table
  buffer.writeln('<table>');
  buffer.writeln('<thead><tr>');
  for (final h in headers) {
    buffer.writeln('<th>${_escape(h)}</th>');
  }
  buffer.writeln('</tr></thead>');
  buffer.writeln('<tbody>');
  for (final row in rows) {
    buffer.writeln('<tr>');
    for (int i = 0; i < row.length; i++) {
      final isNum = i > 0 &&
          RegExp(r'^-?\d+([.,]\d+)?$').hasMatch(row[i].replaceAll(',', ''));
      buffer.writeln(
          '<td${isNum ? " class=\"num\"" : ""}>${_escape(row[i])}</td>');
    }
    buffer.writeln('</tr>');
  }
  buffer.writeln('</tbody>');
  buffer.writeln('</table>');

  // Footer
  if (footer != null && footer.isNotEmpty) {
    buffer.writeln('<div class="footer">${_escape(footer)}</div>');
  }
  buffer.writeln(
      '<div class="footer">تم الإنشاء: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll("T", " ")}</div>');

  // Auto-trigger print dialog when window opens
  buffer.writeln('<script>window.addEventListener("load", function(){ setTimeout(function(){ window.print(); }, 300); });</script>');
  buffer.writeln('</body></html>');

  // استخدم Blob URL بدل data: URI — موثوق أكثر مع المتصفحات الحديثة
  // (data: URIs قد تُحجب أو تتجاوز حدود الطول، و popup blockers تعاملها
  // بصرامة أكثر من Blob URLs).
  final htmlContent = buffer.toString();
  final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final popup = html.window.open(url, '_blank', 'width=900,height=700');
  // في حال حُجبت popup: أعطِ المستخدم تنبيهاً + رابط بديل
  // ignore: unnecessary_null_comparison
  if (popup == null) {
    // بدّل إلى تنزيل HTML كملف للمستخدم ليفتحه يدوياً ويطبعه
    downloadBytes(
      utf8.encode(htmlContent),
      'print_${DateTime.now().millisecondsSinceEpoch}.html',
      'text/html;charset=utf-8',
    );
  }
  // حرّر الـ URL بعد 60 ثانية (وقت يكفي لفتح النافذة وتحميل المحتوى)
  Future.delayed(const Duration(seconds: 60), () {
    html.Url.revokeObjectUrl(url);
  });
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// تنسيق رقم للعرض في التقارير — فواصل آلاف + منزلتين عشريتين.
String formatNumber(double v) {
  if (v == 0) return '—';
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0]
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '$intPart.${parts[1]}';
}
