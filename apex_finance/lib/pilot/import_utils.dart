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

/// نسخة محسَّنة: ترجع bytes + اسم الملف الحقيقي.
Future<({List<int> bytes, String name})?> pickFileWithName(
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
  return (
    bytes: (reader.result as List<int>),
    name: file.name,
  );
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

/// Parse XLSX bytes — متين ضد أوراق متعددة، صفوف فارغة في البداية،
/// خلايا مدمجة، sheets بأسماء غريبة.
ParsedSheet parseXlsx(List<int> bytes) {
  Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (e) {
    return ParsedSheet(
        headers: [],
        rows: [],
        warnings: ['تعذّر قراءة الملف: $e — تأكّد أنه xlsx صحيح']);
  }
  if (excel.tables.isEmpty) {
    return ParsedSheet(
        headers: [], rows: [], warnings: ['الملف لا يحتوي أوراقاً']);
  }

  // اختر أول ورقة بها بيانات حقيقية (وليست مجرد أول ورقة بحسب الترتيب)
  String? bestSheetName;
  for (final entry in excel.tables.entries) {
    final s = entry.value;
    if (s.rows.length >= 2) {
      // فيها صفّ headers وعلى الأقل صف بيانات
      bestSheetName = entry.key;
      break;
    }
  }
  bestSheetName ??= excel.tables.keys.first;
  final sheet = excel.tables[bestSheetName]!;

  if (sheet.rows.isEmpty) {
    return ParsedSheet(
        headers: [],
        rows: [],
        warnings: ['الورقة "$bestSheetName" فارغة']);
  }

  // ابحث عن صفّ الـ headers الحقيقي.
  // الاستراتيجية: في أول 15 صف، اختر الصفّ ذو أكثر عدد خلايا غير فارغة.
  // (صفوف title و meta عادة تحتوي 1-2 خلية فقط، بينما headers تحتوي 3+).
  int headerRowIdx = 0;
  int maxNonEmpty = 0;
  final scanLimit = sheet.rows.length < 15 ? sheet.rows.length : 15;
  for (int i = 0; i < scanLimit; i++) {
    final row = sheet.rows[i];
    final nonEmpty = row.where((c) =>
        c?.value != null && c!.value.toString().trim().isNotEmpty).length;
    if (nonEmpty > maxNonEmpty) {
      maxNonEmpty = nonEmpty;
      headerRowIdx = i;
    }
  }
  // إذا أقصى عدد خلايا أقل من 2، اعتبره فارغاً
  if (maxNonEmpty < 2) {
    return ParsedSheet(
        headers: [],
        rows: [],
        warnings: [
          'لم يُعثر على صفّ headers صالح في الورقة "$bestSheetName".'
        ]);
  }

  final headerRow = sheet.rows[headerRowIdx];
  final headers = <String>[];
  for (final c in headerRow) {
    final v = (c?.value?.toString() ?? '').trim();
    headers.add(v);
  }
  // أزل الـ trailing empty headers
  while (headers.isNotEmpty && headers.last.isEmpty) {
    headers.removeLast();
  }

  if (headers.isEmpty) {
    return ParsedSheet(
        headers: [],
        rows: [],
        warnings: [
          'لم يُعثر على صفّ headers صالح في الورقة "$bestSheetName". '
              'ضع أسماء الأعمدة في الصف الأول.'
        ]);
  }

  final rows = <Map<String, dynamic>>[];
  for (int i = headerRowIdx + 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    if (row.every((c) =>
        c?.value == null || c!.value.toString().trim().isEmpty)) {
      continue;
    }
    final map = <String, dynamic>{};
    for (int j = 0; j < headers.length && j < row.length; j++) {
      if (headers[j].isEmpty) continue; // skip unnamed columns
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

  final warnings = <String>['استُخدم sheet: "$bestSheetName"'];
  if (headerRowIdx > 0) {
    warnings.add('تم تخطي $headerRowIdx صف فارغ قبل الـ headers');
  }
  return ParsedSheet(headers: headers, rows: rows, warnings: warnings);
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
///
/// [valueMap] (اختياري): يترجم قيم محددة لكل field من العربي/البديل إلى
/// القيمة الـ canonical التي يقبلها الـ backend.
/// مثال: {'category': {'الأصول': 'asset', 'asset': 'asset'}}
class ImportMapping {
  final Map<String, String> columnMap;
  final Map<String, Map<String, String>> valueMap;
  const ImportMapping(this.columnMap, {this.valueMap = const {}});

  /// يُطبّق الـ mapping على صف — case-insensitive + trim للمفاتيح والقيم.
  Map<String, dynamic> apply(Map<String, dynamic> row) {
    final normalizedRow = <String, dynamic>{};
    row.forEach((k, v) {
      normalizedRow[k.toString().toLowerCase().trim()] = v;
    });
    final out = <String, dynamic>{};
    columnMap.forEach((header, field) {
      final key = header.toLowerCase().trim();
      if (normalizedRow.containsKey(key) && normalizedRow[key] != null) {
        var v = normalizedRow[key];
        if (v is String && v.trim().isEmpty) return;
        if (v is String) v = v.trim();
        // ترجمة القيم (مثلاً "الأصول" → "asset")
        if (v is String && valueMap.containsKey(field)) {
          final lookup = valueMap[field]!;
          // case-insensitive lookup
          final lowerV = v.toLowerCase();
          final translated = lookup[v] ??
              lookup[lowerV] ??
              lookup.entries
                  .firstWhere(
                    (e) => e.key.toLowerCase() == lowerV,
                    orElse: () => MapEntry('', v),
                  )
                  .value;
          if (translated.isNotEmpty) v = translated;
        }
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
const ImportMapping coaMapping = ImportMapping(
  {
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
  },
  valueMap: {
    'category': {
      'الأصول': 'asset',
      'الخصوم': 'liability',
      'الالتزامات': 'liability',
      'حقوق الملكية': 'equity',
      'الإيرادات': 'revenue',
      'المصروفات': 'expense',
      // pass-through للقيم الإنجليزية
      'asset': 'asset',
      'liability': 'liability',
      'equity': 'equity',
      'revenue': 'revenue',
      'expense': 'expense',
    },
    'type': {
      'رئيسي': 'header',
      'فرعي': 'detail',
      'header': 'header',
      'detail': 'detail',
    },
    'normal_balance': {
      'مدين': 'debit',
      'دائن': 'credit',
      'debit': 'debit',
      'credit': 'credit',
    },
  },
);

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

  // 1. فحص headers: هل الأعمدة المطلوبة موجودة فعلاً في الملف؟
  // نقارن headers الملف مع المفاتيح المُعرَّفة في الـ mapping (case-insensitive)
  final parsedHeadersLower =
      sheet.headers.map((h) => h.toLowerCase().trim()).toSet();
  final missingHeaders = <String>[];
  for (final req in requiredFields) {
    final possibleSources = mapping.columnMap.entries
        .where((e) => e.value == req)
        .map((e) => e.key.toLowerCase())
        .toSet();
    final found = parsedHeadersLower.any((h) => possibleSources.contains(h));
    if (!found) {
      missingHeaders.add(req);
      errors.add(
          '❌ الحقل المطلوب "$req" لم يُربط بأي عمود — الأعمدة المقبولة: ${possibleSources.join(" / ")}');
    }
  }

  // لو أي header مطلوب غير موجود، لا فائدة من فحص الصفوف (كلها ستفشل).
  if (missingHeaders.isNotEmpty) {
    errors.add(
        '💡 أعد تسمية الأعمدة في ملف Excel ثم أعد المحاولة — أو نزّل القالب من زر "استيراد Excel".');
    return errors;
  }

  // 2. فحص كل صف (case-insensitive matching)
  // أنشئ نسخة normalized من row keys لمطابقة حالة الأحرف
  for (int i = 0; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    final normalizedRow = <String, dynamic>{};
    row.forEach((k, v) {
      normalizedRow[k.toLowerCase().trim()] = v;
    });
    // طبّق الـ mapping مع تطبيع المفاتيح
    final mapped = <String, dynamic>{};
    mapping.columnMap.forEach((header, field) {
      final key = header.toLowerCase().trim();
      if (normalizedRow.containsKey(key) && normalizedRow[key] != null) {
        final v = normalizedRow[key];
        if (v is String && v.isEmpty) return;
        mapped[field] = v;
      }
    });

    for (final req in requiredFields) {
      if (!mapped.containsKey(req) ||
          mapped[req] == null ||
          mapped[req].toString().trim().isEmpty) {
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
