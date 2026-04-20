/// Excel/CSV Import utilities.
///
/// Phase 5 Wave L — استيراد بيانات من Excel/CSV للـ bulk onboarding.
///
/// المصدر الأساسي: مكاتب محاسبة تُهاجر عملاءها من نظام قديم.
/// بدون import ممتاز، كل عميل جديد = 1000 منتج يدوي = يوم كامل.
library;

import 'dart:convert';
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// بنية نتيجة parse
class ParsedSheet {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;
  final List<String> warnings;

  ParsedSheet({
    required this.headers,
    required this.rows,
    this.warnings = const [],
  });

  int get rowCount => rows.length;
  bool get isEmpty => rows.isEmpty;
}

/// اختيار ملف من المتصفح (Flutter Web).
Future<List<int>?> pickFileBytes(
    {List<String> accept = const ['.csv', '.xlsx', '.xls']}) async {
  final input = html.FileUploadInputElement()..accept = accept.join(',');
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  return (reader.result as List<int>);
}

/// Parse CSV bytes.
ParsedSheet parseCsv(List<int> bytes) {
  // تعامل مع BOM
  var content = utf8.decode(bytes, allowMalformed: true);
  if (content.startsWith('\uFEFF')) {
    content = content.substring(1);
  }
  // جرّب delimiters المختلفة
  List<List<dynamic>> data;
  try {
    data = const CsvToListConverter(shouldParseNumbers: false)
        .convert(content);
  } catch (_) {
    // Fallback لـ tab-separated
    data = const CsvToListConverter(fieldDelimiter: '\t', shouldParseNumbers: false)
        .convert(content);
  }
  if (data.isEmpty) {
    return ParsedSheet(headers: [], rows: []);
  }
  final headers = data.first.map((e) => e.toString().trim()).toList();
  final rows = <Map<String, dynamic>>[];
  for (int i = 1; i < data.length; i++) {
    final row = data[i];
    if (row.every((c) => c == null || c.toString().trim().isEmpty)) continue;
    final map = <String, dynamic>{};
    for (int j = 0; j < headers.length && j < row.length; j++) {
      map[headers[j]] = row[j]?.toString().trim();
    }
    rows.add(map);
  }
  return ParsedSheet(headers: headers, rows: rows);
}

/// Parse XLSX bytes.
ParsedSheet parseXlsx(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    return ParsedSheet(headers: [], rows: [], warnings: ['ملف Excel فارغ']);
  }
  final sheetName = excel.tables.keys.first;
  final sheet = excel.tables[sheetName];
  if (sheet == null || sheet.rows.isEmpty) {
    return ParsedSheet(headers: [], rows: []);
  }
  // الصف الأول = headers
  final headerRow = sheet.rows.first;
  final headers = headerRow
      .map((c) => (c?.value?.toString() ?? '').trim())
      .toList();
  final rows = <Map<String, dynamic>>[];
  for (int i = 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    if (row.every((c) => c?.value == null ||
        c!.value.toString().trim().isEmpty)) {
      continue;
    }
    final map = <String, dynamic>{};
    for (int j = 0; j < headers.length && j < row.length; j++) {
      final cellValue = row[j]?.value;
      if (cellValue == null) {
        map[headers[j]] = null;
      } else if (cellValue is DoubleCellValue) {
        map[headers[j]] = cellValue.value;
      } else if (cellValue is IntCellValue) {
        map[headers[j]] = cellValue.value;
      } else if (cellValue is BoolCellValue) {
        map[headers[j]] = cellValue.value;
      } else {
        map[headers[j]] = cellValue.toString().trim();
      }
    }
    rows.add(map);
  }
  return ParsedSheet(
      headers: headers, rows: rows,
      warnings: ['استُخدم sheet: "$sheetName"']);
}

/// Auto-detect format from filename/bytes.
ParsedSheet autoParse(List<int> bytes, String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.csv')) return parseCsv(bytes);
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
    return parseXlsx(bytes);
  }
  // حاول CSV كافتراضي
  return parseCsv(bytes);
}

/// Column mapping — header name → field key on backend.
class ImportMapping {
  final Map<String, String> columnMap;
  const ImportMapping(this.columnMap);

  Map<String, dynamic> apply(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    columnMap.forEach((header, field) {
      if (row.containsKey(header) && row[header] != null) {
        final v = row[header];
        if (v is String && v.isEmpty) return;
        out[field] = v;
      }
    });
    return out;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Predefined mappings — تدعم العربية والإنجليزية في الـ headers
// ══════════════════════════════════════════════════════════════════════════

/// CoA (Chart of Accounts) import — SOCPA format
const ImportMapping coaMapping = ImportMapping({
  'code': 'code',
  'الرقم': 'code',
  'الكود': 'code',
  'Account Code': 'code',
  'name_ar': 'name_ar',
  'الاسم العربي': 'name_ar',
  'الاسم': 'name_ar',
  'name_en': 'name_en',
  'الاسم الإنجليزي': 'name_en',
  'Name English': 'name_en',
  'category': 'category',
  'الفئة': 'category',
  'Category': 'category',
  'type': 'type',
  'النوع': 'type',
  'Type': 'type',
  'normal_balance': 'normal_balance',
  'الطبيعة': 'normal_balance',
  'Normal Balance': 'normal_balance',
  'parent_code': '_parent_code',
  'parent_account_code': '_parent_code',
  'كود الأب': '_parent_code',
  'Parent Code': '_parent_code',
});

/// Product import
const ImportMapping productMapping = ImportMapping({
  'code': 'code',
  'الكود': 'code',
  'SKU': 'code',
  'name_ar': 'name_ar',
  'الاسم العربي': 'name_ar',
  'الاسم': 'name_ar',
  'name_en': 'name_en',
  'الاسم الإنجليزي': 'name_en',
  'kind': 'kind',
  'النوع': 'kind',
  'vat_code': 'vat_code',
  'VAT': 'vat_code',
  'default_uom': 'default_uom',
  'وحدة القياس': 'default_uom',
  'UOM': 'default_uom',
  'category_code': '_category_code',
  'فئة': '_category_code',
  'brand_code': '_brand_code',
  'علامة': '_brand_code',
  'list_price': '_list_price',
  'السعر': '_list_price',
  'Price': '_list_price',
  'cost': '_cost',
  'التكلفة': '_cost',
  'Cost': '_cost',
  'barcode': '_barcode',
  'الباركود': '_barcode',
  'Barcode': '_barcode',
});

/// Vendor import
const ImportMapping vendorMapping = ImportMapping({
  'code': 'code',
  'الكود': 'code',
  'Vendor Code': 'code',
  'legal_name_ar': 'legal_name_ar',
  'الاسم القانوني': 'legal_name_ar',
  'الاسم': 'legal_name_ar',
  'legal_name_en': 'legal_name_en',
  'Name English': 'legal_name_en',
  'kind': 'kind',
  'النوع': 'kind',
  'country': 'country',
  'الدولة': 'country',
  'cr_number': 'cr_number',
  'السجل التجاري': 'cr_number',
  'CR': 'cr_number',
  'vat_number': 'vat_number',
  'الرقم الضريبي': 'vat_number',
  'VAT': 'vat_number',
  'payment_terms': 'payment_terms',
  'شروط الدفع': 'payment_terms',
  'email': 'email',
  'البريد': 'email',
  'Email': 'email',
  'phone': 'phone',
  'الجوال': 'phone',
  'Phone': 'phone',
  'bank_iban': 'bank_iban',
  'IBAN': 'bank_iban',
  'contact_name': 'contact_name',
  'المسؤول': 'contact_name',
});

/// Validation: يرجع قائمة الأخطاء قبل الإرسال.
List<String> validateRows({
  required ParsedSheet sheet,
  required ImportMapping mapping,
  required List<String> requiredFields,
}) {
  final errors = <String>[];
  // فحص: كل الـ required fields mapped؟
  final mappedFields = mapping.columnMap.values.toSet();
  for (final req in requiredFields) {
    if (!mappedFields.contains(req)) {
      errors.add('❌ حقل مطلوب "$req" غير موجود في الـ headers');
    }
  }
  // فحص كل صف
  for (int i = 0; i < sheet.rows.length; i++) {
    final mapped = mapping.apply(sheet.rows[i]);
    for (final req in requiredFields) {
      if (!mapped.containsKey(req) ||
          mapped[req] == null ||
          mapped[req].toString().isEmpty) {
        errors.add('❌ الصف ${i + 2}: حقل "$req" فارغ');
      }
    }
    if (errors.length > 50) {
      errors.add('... (توقّفت عند 50 خطأ — أصلحها أولاً)');
      break;
    }
  }
  return errors;
}
