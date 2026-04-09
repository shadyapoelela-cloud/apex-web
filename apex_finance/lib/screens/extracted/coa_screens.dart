import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart' as intl;
import 'dart:html' as html;




// === v7.5 ApiRetry helper (cold-start tolerance for Render free tier) ===
class ApiRetry {
  static Future<http.Response> _attempt(
    Future<http.Response> Function() call,
    String method,
    String url,
  ) async {
    Object? lastErr;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final timeout = Duration(seconds: attempt == 1 ? 10 : 20);
        final r = await call().timeout(timeout);
        // Treat 502/503/504 as retriable (cold start gateway errors)
        if (attempt < 3 && (r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504)) {
          await Future.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        return r;
      } catch (e) {
        lastErr = e;
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }
    }
    throw Exception('ApiRetry $method $url failed after 3 attempts: $lastErr');
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    _attempt(() => http.get(url, headers: headers), 'GET', url.toString());

  static Future<http.Response> post(Uri url,
    {Map<String, String>? headers, Object? body}) =>
    _attempt(() => http.post(url, headers: headers, body: body), 'POST', url.toString());

  static Future<http.Response> put(Uri url,
    {Map<String, String>? headers, Object? body}) =>
    _attempt(() => http.put(url, headers: headers, body: body), 'PUT', url.toString());
}
// === end ApiRetry ===

// ═══════════════════════════════════════════════════════════════
// APEX Phase 1 — COA Qualification v5.0
// Redesigned: No ERP selection, 3-column auto-detect, smart analysis
// ═══════════════════════════════════════════════════════════════

class AppColors {
  static const navy = Color(0xFF050D1A);
  static const navyLight = Color(0xFF0A1628);
  static const navyMid = Color(0xFF111D2E);
  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFD4B96A);
  static const textColor = Color(0xFFE8E0D0);
  static const textMid = Color(0xFF9A917F);
  static const textDim = Color(0xFF6B6355);
  static const cardBg = Color(0xFF0D1825);
  static const borderColor = Color(0x1FC9A84C);
  static const greenC = Color(0xFF34D399);
  static const redC = Color(0xFFF87171);
  static const blueC = Color(0xFF60A5FA);
  static const orangeC = Color(0xFFFBBF24);
  static const purpleC = Color(0xFFA78BFA);
}

// ─── Data Models ──────────────────────────────────────────────

class CoaAccount {
  String code;
  String uniqueId;       // code + rowIndex for uniqueness
  String name;
  int level;
  int rowIndex;          // original row number in file
  String rootClass;      // أصول، التزامات، حقوق ملكية، إيرادات، مصروفات
  String accountType;    // حساب رئيسي، حساب فرعي، حساب تفصيلي
  String nature;         // مدين، دائن
  String reportType;     // ميزانية، دخل
  bool isClosable;       // مؤقت (يُقفل نهاية الفترة)
  bool isBankReconcilable; // قابل للتسوية البنكية
  bool isDuplicateCode;  // true if code appears more than once
  String parentCode;
  String parentUniqueId; // parent's uniqueId for duplicate-aware tree
  String suggestedCode;  // suggested fix for duplicate codes
  String suggestedParent; // suggested correct parent
  double acceptanceScore; // 0-100
  List<String> flags;    // قائمة الملاحظات والأخطاء
  String status;         // approved, review, flagged
  List<CoaAccount> children = [];

  CoaAccount({
    required this.code,
    this.uniqueId = '',
    required this.name,
    this.level = 0,
    this.rowIndex = 0,
    this.rootClass = '',
    this.accountType = '',
    this.nature = '',
    this.reportType = '',
    this.isClosable = false,
    this.isBankReconcilable = false,
    this.isDuplicateCode = false,
    this.parentCode = '',
    this.parentUniqueId = '',
    this.suggestedCode = '',
    this.suggestedParent = '',
    this.acceptanceScore = 0,
    this.flags = const [],
    this.status = 'approved',
    this.children = const [],
  });
}

/// Suggest a correct code for duplicate accounts based on name analysis
String _suggestCodeFix(String code, String name, int rowIndex, List<CoaAccount> allAccounts) {
  // Find all accounts with same code
  final dupes = allAccounts.where((a) => a.code == code).toList();
  if (dupes.length <= 1) return '';

  // The first occurrence keeps the code, later ones get a suffix suggestion
  final firstOccurrence = dupes.first;
  if (firstOccurrence.rowIndex == rowIndex) return ''; // First one is fine

  // Find the parent's code to suggest a sequential code
  // Look at siblings under same parent to find next available code
  final parentCode = _findParentCodeByPrefix(code, allAccounts);
  if (parentCode.isNotEmpty) {
    // Find all siblings
    final siblingCodes = allAccounts
        .where((a) => a.code.startsWith(parentCode) && a.code.length == code.length && a.code != code)
        .map((a) => a.code)
        .toSet();
    // Find next available code
    final codeNum = int.tryParse(code) ?? 0;
    for (int i = 1; i <= 9; i++) {
      final candidate = '${codeNum + i}';
      if (!siblingCodes.contains(candidate) && !allAccounts.any((a) => a.code == candidate)) {
        return candidate;
      }
    }
  }
  return '${code}_${rowIndex}';
}

String _findParentCodeByPrefix(String code, List<CoaAccount> allAccounts) {
  final cleaned = code.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.length <= 1) return '';
  // Try progressively shorter prefixes
  for (int len = cleaned.length - 1; len >= 1; len--) {
    final prefix = cleaned.substring(0, len);
    if (allAccounts.any((a) => a.code == prefix)) return prefix;
  }
  return '';
}

/// Classify account category by analyzing the name (Arabic NLP)
String _classifyByName(String name) {
  final n = name.trim();
  // Bank/Cash accounts
  if (RegExp(r'بنك|بنوك|مصرف|نقد|صندوق|خزينة|كاش|cash|bank').hasMatch(n)) return 'نقدية وبنوك';
  // Inventory
  if (RegExp(r'مخزون|بضاعة|سلع|مواد خام|منتج').hasMatch(n)) return 'مخزون';
  // Receivables
  if (RegExp(r'مدين|ذمم مدينة|عملاء|receivable').hasMatch(n)) return 'ذمم مدينة';
  // Payables
  if (RegExp(r'دائن|ذمم دائنة|موردين|payable').hasMatch(n)) return 'ذمم دائنة';
  // Fixed assets
  if (RegExp(r'أصول ثابتة|أراضي|مباني|سيارات|آلات|أثاث|معدات|عقار').hasMatch(n)) return 'أصول ثابتة';
  // Revenue
  if (RegExp(r'إيراد|مبيعات|دخل|revenue|sales|income').hasMatch(n)) return 'إيرادات';
  // Expenses
  if (RegExp(r'مصروف|رواتب|إيجار|صيانة|expense|salary').hasMatch(n)) return 'مصروفات';
  // Equity
  if (RegExp(r'رأس مال|أرباح|احتياطي|ملكية|capital|equity').hasMatch(n)) return 'حقوق ملكية';
  // Loans
  if (RegExp(r'قرض|تمويل|loan').hasMatch(n)) return 'قروض';
  return '';
}

// ─── Windows-1256 Decoder ─────────────────────────────────────

const Map<int, int> _win1256 = {
  0x80:0x20AC,0x81:0x067E,0x82:0x201A,0x83:0x0192,0x84:0x201E,
  0x85:0x2026,0x86:0x2020,0x87:0x2021,0x88:0x02C6,0x89:0x2030,
  0x8A:0x0679,0x8B:0x2039,0x8C:0x0152,0x8D:0x0686,0x8E:0x0698,
  0x8F:0x0688,0x90:0x06AF,0x91:0x2018,0x92:0x2019,0x93:0x201C,
  0x94:0x201D,0x95:0x2022,0x96:0x2013,0x97:0x2014,0x98:0x06A9,
  0x99:0x2122,0x9A:0x0691,0x9B:0x203A,0x9C:0x0153,0x9D:0x200C,
  0x9E:0x200D,0x9F:0x06BA,0xA0:0x00A0,0xA1:0x060C,0xA2:0x00A2,
  0xA3:0x00A3,0xA4:0x00A4,0xA5:0x00A5,0xA6:0x00A6,0xA7:0x00A7,
  0xA8:0x00A8,0xA9:0x00A9,0xAA:0x06BE,0xAB:0x00AB,0xAC:0x00AC,
  0xAD:0x00AD,0xAE:0x00AE,0xAF:0x00AF,0xB0:0x00B0,0xB1:0x00B1,
  0xB2:0x00B2,0xB3:0x00B3,0xB4:0x00B4,0xB5:0x00B5,0xB6:0x00B6,
  0xB7:0x00B7,0xB8:0x00B8,0xB9:0x00B9,0xBA:0x061B,0xBB:0x00BB,
  0xBC:0x00BC,0xBD:0x00BD,0xBE:0x00BE,0xBF:0x061F,0xC0:0x06C1,
  0xC1:0x0621,0xC2:0x0622,0xC3:0x0623,0xC4:0x0624,0xC5:0x0625,
  0xC6:0x0626,0xC7:0x0627,0xC8:0x0628,0xC9:0x0629,0xCA:0x062A,
  0xCB:0x062B,0xCC:0x062C,0xCD:0x062D,0xCE:0x062E,0xCF:0x062F,
  0xD0:0x0630,0xD1:0x0631,0xD2:0x0632,0xD3:0x0633,0xD4:0x0634,
  0xD5:0x0635,0xD6:0x0636,0xD7:0x00D7,0xD8:0x0637,0xD9:0x0638,
  0xDA:0x0639,0xDB:0x063A,0xDC:0x0640,0xDD:0x0641,0xDE:0x0642,
  0xDF:0x0643,0xE0:0x00E0,0xE1:0x0644,0xE2:0x00E2,0xE3:0x0645,
  0xE4:0x0646,0xE5:0x0647,0xE6:0x0648,0xE7:0x00E7,0xE8:0x00E8,
  0xE9:0x00E9,0xEA:0x00EA,0xEB:0x00EB,0xEC:0x0649,0xED:0x064A,
  0xEE:0x00EE,0xEF:0x00EF,0xF0:0x064B,0xF1:0x064C,0xF2:0x064D,
  0xF3:0x064E,0xF4:0x00F4,0xF5:0x064F,0xF6:0x0650,0xF7:0x00F7,
  0xF8:0x0651,0xF9:0x00F9,0xFA:0x0652,0xFB:0x00FB,0xFC:0x00FC,
  0xFD:0x200E,0xFE:0x200F,0xFF:0x06D2,
};

String _decodeWin1256(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80) {
      sb.writeCharCode(b);
    } else {
      sb.writeCharCode(_win1256[b] ?? b);
    }
  }
  return sb.toString();
}

// ─── Column Auto-Detection Helpers ────────────────────────────

/// Checks if value looks like an account code (numeric, with optional separators)
bool _isCodeLike(String v) {
  final cleaned = v.replaceAll(RegExp(r'[\s\-\./]'), '');
  if (cleaned.isEmpty) return false;
  return RegExp(r'^[0-9]+$').hasMatch(cleaned);
}

/// Checks if value is Arabic text
bool _isArabicText(String v) {
  if (v.trim().isEmpty) return false;
  return RegExp(r'[\u0600-\u06FF]').hasMatch(v);
}

/// Checks if value is a small integer (level-like)
bool _isLevelLike(String v) {
  final n = int.tryParse(v.trim());
  return n != null && n >= 1 && n <= 20;
}

/// Score a column as code column (higher = more likely)
double _scoreAsCode(List<String> values) {
  if (values.isEmpty) return 0;
  int codeCount = 0;
  int uniqueCount = 0;
  final seen = <String>{};
  for (final v in values) {
    if (v.trim().isEmpty) continue;
    if (_isCodeLike(v)) codeCount++;
    if (seen.add(v.trim())) uniqueCount++;
  }
  final nonEmpty = values.where((v) => v.trim().isNotEmpty).length;
  if (nonEmpty == 0) return 0;
  double score = (codeCount / nonEmpty) * 60;
  // Uniqueness bonus — codes should be unique
  score += (uniqueCount / nonEmpty) * 30;
  // Codes shouldn't be too long (>15 chars unlikely)
  final avgLen = values.where((v) => v.trim().isNotEmpty)
      .map((v) => v.trim().length).reduce((a, b) => a + b) / nonEmpty;
  if (avgLen <= 12) score += 10;
  return score;
}

/// Score a column as name column (higher = more likely)
double _scoreAsName(List<String> values) {
  if (values.isEmpty) return 0;
  int arabicCount = 0;
  int textCount = 0;
  double totalLen = 0;
  final nonEmpty = values.where((v) => v.trim().isNotEmpty).length;
  if (nonEmpty == 0) return 0;
  for (final v in values) {
    if (v.trim().isEmpty) continue;
    if (_isArabicText(v)) arabicCount++;
    if (v.trim().length > 2 && !_isCodeLike(v)) textCount++;
    totalLen += v.trim().length;
  }
  double score = (arabicCount / nonEmpty) * 40;
  score += (textCount / nonEmpty) * 30;
  // Names should be longer than codes
  final avgLen = totalLen / nonEmpty;
  if (avgLen > 4) score += 20;
  if (avgLen > 8) score += 10;
  return score;
}

/// Score a column as level column (higher = more likely)
double _scoreAsLevel(List<String> values) {
  if (values.isEmpty) return 0;
  int levelCount = 0;
  final nonEmpty = values.where((v) => v.trim().isNotEmpty).length;
  if (nonEmpty == 0) return 0;
  Set<int> distinctLevels = {};
  for (final v in values) {
    if (v.trim().isEmpty) continue;
    if (_isLevelLike(v)) {
      levelCount++;
      distinctLevels.add(int.parse(v.trim()));
    }
  }
  double score = (levelCount / nonEmpty) * 60;
  // Levels should have few distinct values (typically 3-7)
  if (distinctLevels.length >= 2 && distinctLevels.length <= 10) score += 30;
  // Max value should be reasonable
  if (distinctLevels.isNotEmpty && distinctLevels.reduce((a, b) => a > b ? a : b) <= 15) score += 10;
  return score;
}

/// Header name matching for code columns
int _findColByHeader(List<String> headers, List<String> patterns) {
  for (int i = 0; i < headers.length; i++) {
    final h = headers[i].replaceAll(RegExp(r'[\u00A0\s]+'), ' ').trim().toLowerCase();
    for (final p in patterns) {
      if (h == p || h.contains(p)) return i;
    }
  }
  return -1;
}

// ─── Smart Analysis Engine ────────────────────────────────────

/// Detect level from account code pattern
int _detectLevelFromCode(String code, List<CoaAccount> allAccounts) {
  final cleaned = code.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) return 1;

  // Strategy 1: Find this code's position in the hierarchy by prefix matching
  int maxParentLen = 0;
  for (final acc in allAccounts) {
    final otherCleaned = acc.code.replaceAll(RegExp(r'[^0-9]'), '');
    if (otherCleaned.isEmpty || otherCleaned == cleaned) continue;
    if (cleaned.startsWith(otherCleaned) && otherCleaned.length < cleaned.length) {
      if (otherCleaned.length > maxParentLen) maxParentLen = otherCleaned.length;
    }
  }

  // Strategy 2: Code length based classification
  final len = cleaned.length;
  if (len <= 1) return 1;
  if (len <= 2) return 2;
  if (len <= 3) return 3;
  if (len <= 5) return 4;
  return 5;
}

/// Find parent code by longest prefix match
String _findParentCode(String code, List<CoaAccount> allAccounts) {
  final cleaned = code.replaceAll(RegExp(r'[^0-9]'), '');
  String bestParent = '';
  int bestLen = 0;
  for (final acc in allAccounts) {
    final otherCleaned = acc.code.replaceAll(RegExp(r'[^0-9]'), '');
    if (otherCleaned.isEmpty || otherCleaned == cleaned) continue;
    if (cleaned.startsWith(otherCleaned) && otherCleaned.length < cleaned.length) {
      if (otherCleaned.length > bestLen) {
        bestLen = otherCleaned.length;
        bestParent = acc.code;
      }
    }
  }
  return bestParent;
}

/// Root classification by first digit of code
String _classifyRoot(String code) {
  final cleaned = code.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) return 'غير محدد';
  switch (cleaned[0]) {
    case '1': return 'أصول';
    case '2': return 'التزامات';
    case '3': return 'حقوق ملكية';
    case '4': return 'إيرادات';
    case '5': return 'مصروفات';
    case '6': return 'مصروفات';  // Some systems use 6 for expenses
    case '7': return 'مصروفات';  // Some systems use 7
    case '8': return 'حسابات نظامية';
    case '9': return 'حسابات نظامية';
    default: return 'غير محدد';
  }
}

/// Determine account nature (debit/credit) from root classification
String _determineNature(String rootClass) {
  switch (rootClass) {
    case 'أصول': return 'مدين';
    case 'مصروفات': return 'مدين';
    case 'التزامات': return 'دائن';
    case 'حقوق ملكية': return 'دائن';
    case 'إيرادات': return 'دائن';
    default: return 'مدين';
  }
}

/// Determine report type (BS/IS) from root classification
String _determineReportType(String rootClass) {
  switch (rootClass) {
    case 'أصول': return 'ميزانية';
    case 'التزامات': return 'ميزانية';
    case 'حقوق ملكية': return 'ميزانية';
    case 'إيرادات': return 'دخل';
    case 'مصروفات': return 'دخل';
    default: return 'ميزانية';
  }
}

/// Check if account is closable (temporary account)
bool _isClosable(String rootClass) {
  return rootClass == 'إيرادات' || rootClass == 'مصروفات';
}

/// Check if account is bank reconcilable (by name analysis)
bool _detectBankReconcilable(String name) {
  final lower = name.toLowerCase();
  final keywords = [
    'بنك', 'مصرف', 'bank', 'cash', 'نقد', 'صندوق', 'خزينة',
    'نقدية', 'كاش', 'شيك', 'حوالة', 'جاري لدى البنك',
  ];
  for (final kw in keywords) {
    if (lower.contains(kw)) return true;
  }
  return false;
}

/// Calculate acceptance score for an account
double _calculateAcceptanceScore(CoaAccount acc, List<CoaAccount> allAccounts) {
  double score = 100;
  List<String> flags = [];

  // Check 1: Code format (20 points)
  final cleanCode = acc.code.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanCode.isEmpty) {
    score -= 20;
    flags.add('كود الحساب فارغ أو غير رقمي');
  } else if (cleanCode.length > 12) {
    score -= 5;
    flags.add('كود الحساب طويل بشكل غير معتاد');
  }

  // Check 2: Name quality (20 points)
  if (acc.name.trim().isEmpty) {
    score -= 20;
    flags.add('اسم الحساب فارغ');
  } else if (acc.name.trim().length < 3) {
    score -= 10;
    flags.add('اسم الحساب قصير جداً');
  }

  // Check 3: Level consistency (20 points)
  if (acc.level <= 0) {
    score -= 10;
    flags.add('لم يتم تحديد مستوى الحساب');
  }
  // Check if level matches code length pattern
  if (cleanCode.isNotEmpty && acc.level > 0) {
    final expectedLevel = _detectLevelFromCode(acc.code, []);
    if ((expectedLevel - acc.level).abs() > 2) {
      score -= 10;
      flags.add('المستوى لا يتوافق مع نمط الكود');
    }
  }

  // Check 4: Hierarchy integrity (20 points)
  if (acc.level > 1 && acc.parentCode.isEmpty) {
    score -= 10;
    flags.add('حساب فرعي بدون حساب رئيسي');
  }
  if (acc.parentCode.isNotEmpty) {
    final parentExists = allAccounts.any((a) => a.code == acc.parentCode);
    if (!parentExists) {
      score -= 15;
      flags.add('الحساب الرئيسي (${acc.parentCode}) غير موجود في الشجرة');
    }
  }

  // Check 5: Classification validity (10 points)
  if (acc.rootClass == 'غير محدد') {
    score -= 10;
    flags.add('لم يتم تحديد التصنيف الجذري');
  }

  // Check 6: Duplicate codes (20 points — severe issue)
  final duplicates = allAccounts.where((a) => a.code == acc.code).length;
  if (duplicates > 1) {
    score -= 20;
    flags.add('كود مكرر (${duplicates} حسابات بنفس الكود ${acc.code})');
    final nameCategory = _classifyByName(acc.name);
    if (nameCategory.isNotEmpty) {
      flags.add('التصنيف بالاسم: $nameCategory');
    }
    if (acc.suggestedCode.isNotEmpty) {
      flags.add('الكود المقترح: ${acc.suggestedCode}');
    }
    if (acc.suggestedParent.isNotEmpty) {
      flags.add('التبويب المقترح تحت: ${acc.suggestedParent}');
    }
  }

  acc.flags = flags;
  if (score < 0) score = 0;

  // Determine status
  if (score >= 85) {
    acc.status = 'approved';
  } else if (score >= 60) {
    acc.status = 'review';
  } else {
    acc.status = 'flagged';
  }

  return score;
}

/// Detect ERP silently for Knowledge Brain
String _detectErpSilently(List<String> headers) {
  final hLower = headers.map((h) => h.replaceAll(RegExp(r'[\u00A0\s]+'), ' ').trim().toLowerCase()).toList();

  // ONYX detection
  if (hLower.any((h) => h.contains('الحساب الرئيسي') || h.contains('الرتبة') || h.contains('نوع التقرير'))) {
    return 'ONYX';
  }
  // SAP
  if (hLower.any((h) => h.contains('company code') || h.contains('chart of accounts'))) {
    return 'SAP';
  }
  // Oracle
  if (hLower.any((h) => h.contains('segment') || h.contains('flex_value'))) {
    return 'Oracle';
  }
  // Odoo
  if (hLower.any((h) => h.contains('internal type') || h.contains('user type'))) {
    return 'Odoo';
  }
  // Qoyod
  if (hLower.any((h) => h.contains('قيود') || h.contains('qoyod'))) {
    return 'Qoyod';
  }
  // Daftra
  if (hLower.any((h) => h.contains('دفترة') || h.contains('daftra'))) {
    return 'Daftra';
  }
  // ERPNext
  if (hLower.any((h) => h.contains('is_group') || h.contains('root_type'))) {
    return 'ERPNext';
  }
  return 'غير معروف';
}

/// Store ERP knowledge in localStorage
void _storeErpKnowledge(String erpName, int accountCount, List<String> headers) {
  try {
    final existing = html.window.localStorage['apex_erp_knowledge'] ?? '{}';
    final Map<String, dynamic> knowledge = jsonDecode(existing);
    knowledge['detected_erp'] = erpName;
    knowledge['account_count'] = accountCount;
    knowledge['headers'] = headers;
    knowledge['detected_at'] = DateTime.now().toIso8601String();
    html.window.localStorage['apex_erp_knowledge'] = jsonEncode(knowledge);
  } catch (_) {}
}


// ═══════════════════════════════════════════════════════════════
// Main COA Journey Screen
// ═══════════════════════════════════════════════════════════════

class CoaJourneyScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const CoaJourneyScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<CoaJourneyScreen> createState() => _CoaJourneyScreenState();
}

class _CoaJourneyScreenState extends State<CoaJourneyScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentStage = 0; // 0=upload, 1=analyze, 2=review, 3=tree, 4=approve

  // Parsed data
  List<List<dynamic>> _rawRows = [];
  List<String> _headers = [];
  Uint8List? _fileBytes;
  String _fileName = '';
  bool _isLoading = false;
  String _statusMsg = '';

  // Column indices (auto-detected)
  int _colCode = -1;
  int _colName = -1;
  int _colLevel = -1;

  // Analyzed accounts
  List<CoaAccount> _accounts = [];
  bool _hasUnsavedChanges = false;

  // Filter state
  String _filterStatus = 'all'; // all, approved, review, flagged
  String _searchQuery = '';
  String _detectedErp = '';

  // Tree state
  Map<String, bool> _treeExpanded = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── File Upload & Parse ──────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() {
        _isLoading = true;
        _statusMsg = 'جاري قراءة الملف...';
        _fileBytes = file.bytes;
        _fileName = file.name;
      });

      if (file.name.endsWith('.csv')) {
        _parseCsv(file.bytes!);
      } else {
        _parseExcel(file.bytes!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMsg = 'خطأ في قراءة الملف: $e';
      });
    }
  }

  void _parseCsv(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
      // Check if Arabic text decoded properly
      if (!RegExp(r'[\u0600-\u06FF]').hasMatch(content) && bytes.length > 100) {
        content = _decodeWin1256(bytes);
      }
    } catch (_) {
      content = _decodeWin1256(bytes);
    }

    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content);
    if (rows.isEmpty) {
      setState(() { _isLoading = false; _statusMsg = 'الملف فارغ'; });
      return;
    }

    _processRawData(rows);
  }

  void _parseExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        setState(() { _isLoading = false; _statusMsg = 'الملف فارغ'; });
        return;
      }

      final rows = sheet.rows.map((row) =>
        row.map((cell) => cell?.value?.toString() ?? '').toList()
      ).toList();

      _processRawData(rows);
    } catch (e) {
      setState(() { _isLoading = false; _statusMsg = 'خطأ في قراءة Excel: $e'; });
    }
  }

  void _processRawData(List<List<dynamic>> rows) {
    if (rows.isEmpty) return;

    // First row is headers
    _headers = rows[0].map((c) => c.toString().trim()).toList();
    _rawRows = rows.sublist(1);

    // Remove empty rows
    _rawRows.removeWhere((row) => row.every((c) => c.toString().trim().isEmpty));

    setState(() { _statusMsg = 'جاري اكتشاف الأعمدة تلقائياً...'; });

    // Auto-detect columns
    _autoDetectColumns();

    // Detect ERP silently
    _detectedErp = _detectErpSilently(_headers);
    _storeErpKnowledge(_detectedErp, _rawRows.length, _headers);

    // Show column confirmation dialog
    _showColumnConfirmDialog();
  }

  void _autoDetectColumns() {
    // Collect sample values for each column (up to 50 rows)
    final sampleSize = _rawRows.length > 50 ? 50 : _rawRows.length;
    final colCount = _headers.length;

    // Score each column for code, name, level
    double bestCodeScore = 0;
    double bestNameScore = 0;
    double bestLevelScore = 0;
    _colCode = -1;
    _colName = -1;
    _colLevel = -1;

    for (int c = 0; c < colCount; c++) {
      final values = <String>[];
      for (int r = 0; r < sampleSize; r++) {
        if (c < _rawRows[r].length) {
          values.add(_rawRows[r][c].toString());
        }
      }

      // Score by header name first
      final hLower = _headers[c].replaceAll(RegExp(r'[\u00A0\s]+'), ' ').trim().toLowerCase();

      // Code column detection
      double codeScore = _scoreAsCode(values);
      if (hLower.contains('رقم') || hLower.contains('كود') || hLower.contains('code') ||
          hLower.contains('رمز') || hLower.contains('account') || hLower.contains('حساب')) {
        if (_isCodeLike(values.isNotEmpty ? values[0] : '')) codeScore += 30;
      }
      if (hLower == 'رقم الحساب' || hLower == 'account code' || hLower == 'الرمز') codeScore += 40;

      // Name column detection
      double nameScore = _scoreAsName(values);
      if (hLower.contains('اسم') || hLower.contains('name') || hLower.contains('وصف') ||
          hLower.contains('description') || hLower.contains('بيان')) {
        nameScore += 40;
      }
      if (hLower == 'اسم الحساب' || hLower == 'account name') nameScore += 40;

      // Level column detection
      double levelScore = _scoreAsLevel(values);
      if (hLower.contains('رتبة') || hLower.contains('مستوى') || hLower.contains('level') ||
          hLower.contains('depth') || hLower.contains('النوع')) {
        levelScore += 40;
      }
      if (hLower == 'الرتبة' || hLower == 'المستوى' || hLower == 'level') levelScore += 40;

      if (codeScore > bestCodeScore) { bestCodeScore = codeScore; _colCode = c; }
      if (nameScore > bestNameScore) { bestNameScore = nameScore; _colName = c; }
      if (levelScore > bestLevelScore) { bestLevelScore = levelScore; _colLevel = c; }
    }

    // Make sure code, name, level don't point to same column
    if (_colCode == _colName) {
      // Re-pick name: find next best
      double nextBest = 0;
      int nextIdx = -1;
      for (int c = 0; c < colCount; c++) {
        if (c == _colCode) continue;
        final values = <String>[];
        for (int r = 0; r < sampleSize && r < _rawRows.length; r++) {
          if (c < _rawRows[r].length) values.add(_rawRows[r][c].toString());
        }
        final s = _scoreAsName(values);
        if (s > nextBest) { nextBest = s; nextIdx = c; }
      }
      _colName = nextIdx;
    }
    if (_colLevel == _colCode || _colLevel == _colName) {
      _colLevel = -1; // Will derive from code
    }

    // Level is optional — if score is too low, set to -1
    if (bestLevelScore < 30) _colLevel = -1;
  }

  void _showColumnConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int tmpCode = _colCode;
        int tmpName = _colName;
        int tmpLevel = _colLevel;

        return StatefulBuilder(
          builder: (ctx, setDState) {
            // Build dropdown items
            final items = <DropdownMenuItem<int>>[
              const DropdownMenuItem(value: -1, child: Text('- غير موجود -')),
              ...List.generate(_headers.length, (i) =>
                DropdownMenuItem(value: i, child: Text(_headers[i].isEmpty ? 'عمود ${i + 1}' : _headers[i]))),
            ];

            // Preview first 3 rows
            Widget previewRow(int colIdx, String label) {
              if (colIdx < 0) return const SizedBox();
              final values = <String>[];
              for (int r = 0; r < 3 && r < _rawRows.length; r++) {
                if (colIdx < _rawRows[r].length) {
                  values.add(_rawRows[r][colIdx].toString());
                }
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$label: ${values.join(" ، ")}',
                  style: TextStyle(fontSize: 11, color: AppColors.textMid),
                  textDirection: TextDirection.rtl,
                ),
              );
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.navyLight,
                title: Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: AppColors.gold, size: 24),
                    const SizedBox(width: 8),
                    Text('تأكيد الأعمدة', style: TextStyle(color: AppColors.gold, fontSize: 18)),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // File info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_fileName, style: TextStyle(color: AppColors.goldLight, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${_rawRows.length} حساب • ${_headers.length} عمود',
                                  style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                              if (_detectedErp.isNotEmpty && _detectedErp != 'غير معروف') ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: AppColors.greenC, size: 14),
                                    const SizedBox(width: 4),
                                    Text('تم التعرف على: $_detectedErp',
                                        style: TextStyle(color: AppColors.greenC, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Code column
                        Text('عمود الكود / الرمز *', style: TextStyle(color: AppColors.textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                          ),
                          child: DropdownButton<int>(
                            value: tmpCode,
                            isExpanded: true,
                            dropdownColor: AppColors.navyMid,
                            style: TextStyle(color: AppColors.textColor, fontSize: 13),
                            underline: const SizedBox(),
                            items: items.where((i) => i.value == tmpCode || i.value == -1 || (i.value != tmpName && i.value != tmpLevel)).toList(),
                            onChanged: (v) => setDState(() => tmpCode = v ?? -1),
                          ),
                        ),
                        previewRow(tmpCode, 'معاينة'),
                        const SizedBox(height: 16),

                        // Name column
                        Text('عمود اسم الحساب *', style: TextStyle(color: AppColors.textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                          ),
                          child: DropdownButton<int>(
                            value: tmpName,
                            isExpanded: true,
                            dropdownColor: AppColors.navyMid,
                            style: TextStyle(color: AppColors.textColor, fontSize: 13),
                            underline: const SizedBox(),
                            items: items.where((i) => i.value == tmpName || i.value == -1 || (i.value != tmpCode && i.value != tmpLevel)).toList(),
                            onChanged: (v) => setDState(() => tmpName = v ?? -1),
                          ),
                        ),
                        previewRow(tmpName, 'معاينة'),
                        const SizedBox(height: 16),

                        // Level column (optional)
                        Row(
                          children: [
                            Text('عمود المستوى / الرتبة', style: TextStyle(color: AppColors.textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.blueC.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('اختياري', style: TextStyle(color: AppColors.blueC, fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('في حالة عدم وجوده سيتم اكتشاف المستوى من الكود',
                            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: DropdownButton<int>(
                            value: tmpLevel,
                            isExpanded: true,
                            dropdownColor: AppColors.navyMid,
                            style: TextStyle(color: AppColors.textColor, fontSize: 13),
                            underline: const SizedBox(),
                            items: items.where((i) => i.value == tmpLevel || i.value == -1 || (i.value != tmpCode && i.value != tmpName)).toList(),
                            onChanged: (v) => setDState(() => tmpLevel = v ?? -1),
                          ),
                        ),
                        previewRow(tmpLevel, 'معاينة'),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () { Navigator.pop(ctx); setState(() { _isLoading = false; _statusMsg = ''; }); },
                    child: Text('إلغاء', style: TextStyle(color: AppColors.textMid)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: tmpCode >= 0 && tmpName >= 0 ? () {
                      Navigator.pop(ctx);
                      _colCode = tmpCode;
                      _colName = tmpName;
                      _colLevel = tmpLevel;
                      _analyzeAccounts();
                    } : null,
                    child: Text('تأهيل الحسابات', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Analysis Engine ──────────────────────────────────────

  void _analyzeAccounts() {
    setState(() { _statusMsg = 'جاري تحليل وتأهيل الحسابات...'; });

    // Step 1: Extract raw accounts with row indices
    _accounts = [];
    int rowIdx = 0;
    for (final row in _rawRows) {
      final code = _colCode < row.length ? row[_colCode].toString().trim() : '';
      final name = _colName < row.length ? row[_colName].toString().trim() : '';
      final levelStr = _colLevel >= 0 && _colLevel < row.length ? row[_colLevel].toString().trim() : '';
      final level = int.tryParse(levelStr) ?? 0;

      rowIdx++;
      if (code.isEmpty && name.isEmpty) continue;

      _accounts.add(CoaAccount(
        code: code,
        name: name,
        level: level,
        rowIndex: rowIdx,
      ));
    }

    // Step 2: Assign uniqueId and detect duplicates
    final codeCount = <String, int>{};
    for (final acc in _accounts) {
      codeCount[acc.code] = (codeCount[acc.code] ?? 0) + 1;
    }
    for (final acc in _accounts) {
      acc.uniqueId = '${acc.code}_${acc.rowIndex}';
      acc.isDuplicateCode = (codeCount[acc.code] ?? 1) > 1;
    }

    // Step 3: Detect levels if not provided
    if (_colLevel < 0 || _accounts.every((a) => a.level == 0)) {
      for (final acc in _accounts) {
        acc.level = _detectLevelFromCode(acc.code, _accounts);
      }
    }

    // Step 4: Find parent codes — use name classification for duplicates
    for (final acc in _accounts) {
      acc.parentCode = _findParentCode(acc.code, _accounts);
      // For duplicate-aware tree, find parent's uniqueId
      if (acc.parentCode.isNotEmpty) {
        final potentialParents = _accounts.where((a) => a.code == acc.parentCode).toList();
        if (potentialParents.length == 1) {
          acc.parentUniqueId = potentialParents.first.uniqueId;
        } else if (potentialParents.length > 1) {
          // Multiple parents share same code — use name classification to pick correct one
          final myCategory = _classifyByName(acc.name);
          CoaAccount? bestParent;
          for (final p in potentialParents) {
            final pCategory = _classifyByName(p.name);
            if (myCategory.isNotEmpty && pCategory == myCategory) {
              bestParent = p;
              break;
            }
          }
          if (bestParent != null) {
            acc.parentUniqueId = bestParent.uniqueId;
          } else {
            // Fallback: use the first occurrence
            acc.parentUniqueId = potentialParents.first.uniqueId;
          }
        }
      }
    }

    // Step 5: Classify — use name for disambiguation when codes are duplicated
    for (final acc in _accounts) {
      acc.rootClass = _classifyRoot(acc.code);
      acc.nature = _determineNature(acc.rootClass);
      acc.reportType = _determineReportType(acc.rootClass);
      acc.isClosable = _isClosable(acc.rootClass);
      acc.isBankReconcilable = _detectBankReconcilable(acc.name);

      // If duplicate code, enhance classification with name analysis
      if (acc.isDuplicateCode) {
        final nameCategory = _classifyByName(acc.name);
        if (nameCategory.isNotEmpty) {
          acc.flags = [...acc.flags, 'كود مكرر — التصنيف بناءً على الاسم: $nameCategory'];
        }
        // Generate suggested code fix
        acc.suggestedCode = _suggestCodeFix(acc.code, acc.name, acc.rowIndex, _accounts);
        if (acc.suggestedCode.isNotEmpty) {
          acc.flags = [...acc.flags, 'الكود المقترح: ${acc.suggestedCode}'];
        }
        // Suggest correct parent based on name
        final nameClass = _classifyByName(acc.name);
        if (nameClass.isNotEmpty) {
          // Find a parent whose name matches the same category
          final matchingParents = _accounts.where((a) =>
            a.level < acc.level &&
            _classifyByName(a.name) == nameClass &&
            a.code != acc.code
          ).toList();
          if (matchingParents.isNotEmpty) {
            // Pick the closest level parent
            matchingParents.sort((a, b) => b.level.compareTo(a.level));
            acc.suggestedParent = matchingParents.first.code;
          }
        }
      }

      // Account type by level
      if (acc.level <= 2) {
        acc.accountType = 'حساب رئيسي';
      } else if (acc.level == 3) {
        acc.accountType = 'حساب فرعي';
      } else {
        acc.accountType = 'حساب تفصيلي';
      }
    }

    // Step 6: Validate parent-child name consistency
    // Detect accounts placed under wrong parent due to misleading code prefixes
    for (final acc in _accounts) {
      if (acc.parentCode.isEmpty) continue;
      final myCategory = _classifyByName(acc.name);
      if (myCategory.isEmpty) continue; // Can't validate without name classification

      final parent = _accounts.where((a) => a.code == acc.parentCode).toList();
      if (parent.isEmpty) continue;

      // Check each potential parent
      for (final p in parent) {
        final parentCategory = _classifyByName(p.name);
        if (parentCategory.isEmpty) continue; // Parent has no clear category

        if (myCategory != parentCategory) {
          // MISMATCH: child's name category differs from parent's
          acc.flags = [...acc.flags, 'تحذير: "${ acc.name}" ($myCategory) مصنف تحت "${p.name}" ($parentCategory)'];

          // Try to find a better parent with matching category
          final betterParents = _accounts.where((a) =>
            a.level < acc.level &&
            a.level >= (acc.level - 2) &&
            _classifyByName(a.name) == myCategory &&
            a.code != acc.code
          ).toList();
          if (betterParents.isNotEmpty) {
            betterParents.sort((a, b) => b.level.compareTo(a.level));
            acc.suggestedParent = betterParents.first.code;
            acc.flags = [...acc.flags, 'التبويب المقترح تحت: ${betterParents.first.code} — ${betterParents.first.name}'];
          }
        }
      }
    }

    // Step 7: Calculate acceptance scores
    for (final acc in _accounts) {
      acc.acceptanceScore = _calculateAcceptanceScore(acc, _accounts);
    }

    setState(() {
      _isLoading = false;
      _statusMsg = '';
      _currentStage = 1;
      _tabController.animateTo(0);
    });
  }

  // ─── Build UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges || _accounts.isEmpty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.navy,
          body: Column(
            children: [
              _buildHeader(),
              _buildStagePipeline(),
              if (_accounts.isEmpty)
                _buildUploadSection()
              else ...[
                _buildTabBar(),
                Expanded(child: _buildTabContent()),
              ],
            ],
          ),
        ),
      ),
    );
  }


  // ─── Save & Submit COA to API (v6.9) ─────────────

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _accounts.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1825),
        title: Text('تغييرات غير محفوظة', style: TextStyle(color: AppColors.gold)),
        content: Text('لديك تعديلات لم تُحفظ. هل تريد الخروج بدون حفظ؟',
          style: TextStyle(color: AppColors.textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: AppColors.textMid))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.redC),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج بدون حفظ')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submitCoa() async {
    // v7.6: route through real 6-step COA pipeline (upload→parse→classify→assess→bulk-approve→approve-coa)
    if (_fileBytes == null || _fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('يجب رفع ملف الدليل المحاسبي أولاً قبل الحفظ'),
          backgroundColor: AppColors.redC));
      return;
    }

    final approved = _accounts.where((a) => a.status == 'approved').length;
    final total = _accounts.length;

    if (total > 0 && approved < total) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1825),
          title: Text('تأكيد الإرسال', style: TextStyle(color: AppColors.gold)),
          content: Text('تم اعتماد $approved من $total حساب. هل تريد إرسال الملف للسيرفر للمعالجة الكاملة؟',
            style: TextStyle(color: AppColors.textColor)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: AppColors.textMid))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() { _isLoading = true; _statusMsg = 'بدء الرفع للسيرفر...'; });

    final base = 'https://apex-api-ootk.onrender.com';
    final token = html.window.localStorage['apex_token'] ?? '';
    final authOnly = {'Authorization': 'Bearer $token'};
    final authJson = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

    try {
      // ── Step 1: Upload file (multipart) ─────────────────────
      if (mounted) setState(() => _statusMsg = '1/6 رفع الملف...');
      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('$base/clients/${widget.clientId}/coa/upload'),
      );
      uploadReq.headers.addAll(authOnly);
      uploadReq.files.add(http.MultipartFile.fromBytes(
        'file',
        _fileBytes!,
        filename: _fileName,
      ));
      final uploadStreamed = await uploadReq.send().timeout(const Duration(seconds: 60));
      final uploadResp = await http.Response.fromStream(uploadStreamed);
      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 201) {
        throw Exception('فشل الرفع (${uploadResp.statusCode}): ${uploadResp.body}');
      }
      final uploadData = jsonDecode(uploadResp.body) as Map<String, dynamic>;
      final uploadId = (uploadData['upload_id'] ?? uploadData['id'] ?? uploadData['uploadId'] ?? '').toString();
      if (uploadId.isEmpty) {
        throw Exception('لم يتم استلام upload_id من السيرفر');
      }
      if (mounted) setState(() => _currentStage = 1);

      // ── Step 2: Parse ───────────────────────────────────────
      if (mounted) setState(() => _statusMsg = '2/6 تحليل الملف على السيرفر...');
      final parseResp = await ApiRetry.post(
        Uri.parse('$base/coa/uploads/$uploadId/parse'),
        headers: authJson,
        body: '{}',
      );
      if (parseResp.statusCode != 200 && parseResp.statusCode != 201) {
        throw Exception('فشل التحليل (${parseResp.statusCode}): ${parseResp.body}');
      }
      if (mounted) setState(() => _currentStage = 2);

      // ── Step 3: Classify ────────────────────────────────────
      if (mounted) setState(() => _statusMsg = '3/6 تصنيف الحسابات تلقائياً...');
      final classifyResp = await ApiRetry.post(
        Uri.parse('$base/coa/classify/$uploadId'),
        headers: authOnly,
      );
      if (classifyResp.statusCode != 200 && classifyResp.statusCode != 201) {
        throw Exception('فشل التصنيف (${classifyResp.statusCode}): ${classifyResp.body}');
      }
      if (mounted) setState(() => _currentStage = 3);

      // ── Step 4: Assess quality ──────────────────────────────
      if (mounted) setState(() => _statusMsg = '4/6 تقييم الجودة...');
      final assessResp = await ApiRetry.post(
        Uri.parse('$base/coa/uploads/$uploadId/assess'),
        headers: authJson,
        body: '{}',
      );
      if (assessResp.statusCode != 200 && assessResp.statusCode != 201) {
        throw Exception('فشل تقييم الجودة (${assessResp.statusCode}): ${assessResp.body}');
      }
      if (mounted) setState(() => _currentStage = 4);

      // ── Step 5: Bulk approve ────────────────────────────────
      if (mounted) setState(() => _statusMsg = '5/6 اعتماد الحسابات جماعياً...');
      final bulkResp = await ApiRetry.post(
        Uri.parse('$base/coa/bulk-approve/$uploadId'),
        headers: authJson,
        body: '{}',
      );
      if (bulkResp.statusCode != 200 && bulkResp.statusCode != 201) {
        throw Exception('فشل الاعتماد الجماعي (${bulkResp.statusCode}): ${bulkResp.body}');
      }
      if (mounted) setState(() => _currentStage = 5);

      // ── Step 6: Final approve ──────────────────────────────
      if (mounted) setState(() => _statusMsg = '6/6 الحفظ النهائي...');
      final finalResp = await ApiRetry.post(
        Uri.parse('$base/coa/uploads/$uploadId/approve-coa'),
        headers: authJson,
        body: '{}',
      );
      if (finalResp.statusCode != 200 && finalResp.statusCode != 201) {
        throw Exception('فشل الحفظ النهائي (${finalResp.statusCode}): ${finalResp.body}');
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isLoading = false;
          _statusMsg = '';
          _currentStage = 6;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ شجرة الحسابات بنجاح ($total حساب)'),
            backgroundColor: AppColors.greenC,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _statusMsg = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: AppColors.redC,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      color: AppColors.navyMid,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رحلة تأهيل الدليل المحاسبي',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold)),
                const SizedBox(height: 4),
                Text('${widget.clientName} • معرف: ${widget.clientId}',
                    style: TextStyle(fontSize: 13, color: AppColors.textMid)),
              ],
            ),
          ),
          if (_accounts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.greenC.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.greenC.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.greenC, size: 16),
                  const SizedBox(width: 6),
                  Text('${_accounts.length} حساب',
                      style: TextStyle(color: AppColors.greenC, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (_accounts.isNotEmpty) const SizedBox(width: 12),
          if (_accounts.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _submitCoa(),
              icon: Icon(Icons.save_outlined, size: 18, color: AppColors.navy),
              label: Text('حفظ شجرة الحسابات',
                  style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStagePipeline() {
    final stages = [
      ('رفع الملف', Icons.cloud_upload),
      ('القراءة', Icons.document_scanner),
      ('التصنيف', Icons.category),
      ('الجودة', Icons.speed),
      ('المراجعة', Icons.rate_review),
      ('الاعتماد', Icons.verified),
      ('جاهز لـ TB', Icons.check_circle),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppColors.navyLight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: List.generate(stages.length * 2 - 1, (index) {
            if (index.isOdd) {
              final ci = index ~/ 2;
              return Container(
                width: 32, height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                color: ci < _currentStage ? AppColors.greenC : AppColors.textDim.withOpacity(0.3),
              );
            }
            final si = index ~/ 2;
            final isComplete = si < _currentStage;
            final isCurrent = si == _currentStage;
            final bgColor = isComplete ? AppColors.greenC : (isCurrent ? AppColors.gold : AppColors.navyMid);
            final textCol = isComplete || isCurrent ? (isComplete ? Colors.white : AppColors.navy) : AppColors.textDim;

            return Column(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: bgColor,
                    boxShadow: isCurrent ? [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 10)] : [],
                  ),
                  child: Center(child: isComplete
                      ? Icon(Icons.check, color: textCol, size: 22)
                      : Icon(stages[si].$2, color: textCol, size: 22)),
                ),
                const SizedBox(height: 8),
                Text(stages[si].$1,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isCurrent ? AppColors.gold : AppColors.textMid)),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Upload card
              GestureDetector(
                onTap: _isLoading ? null : _pickFile,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 2),
                    boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.05), blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withOpacity(0.1),
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3))
                            : Icon(Icons.cloud_upload_outlined, color: AppColors.gold, size: 40),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isLoading ? _statusMsg : 'ارفع الدليل المحاسبي',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: _isLoading ? AppColors.textMid : AppColors.gold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CSV أو Excel — سيتم اكتشاف الأعمدة تلقائياً',
                        style: TextStyle(fontSize: 12, color: AppColors.textDim),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.navyLight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navyMid,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMid,
          indicator: BoxDecoration(
            color: AppColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart, size: 16), text: 'النظرة العامة'),
            Tab(icon: Icon(Icons.table_chart, size: 16), text: 'الحسابات'),
            Tab(icon: Icon(Icons.speed, size: 16), text: 'الجودة'),
            Tab(icon: Icon(Icons.visibility, size: 16), text: 'المراجعة'),
            Tab(icon: Icon(Icons.account_tree, size: 16), text: 'الشجرة'),
          ],
          onTap: (i) {
            setState(() {
              if (i == 0) _currentStage = 1;
              if (i == 1) _currentStage = 2;
              if (i == 2) _currentStage = 3;
              if (i == 3) _currentStage = 4;
              if (i == 4) _currentStage = 4;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildAccountsTab(),
        _buildQualityTab(),
        _buildReviewTab(),
        _buildTreeTab(),
      ],
    );
  }

  // ─── Overview Tab ──────────────────────────────────────────

  Widget _buildOverviewTab() {
    final approved = _accounts.where((a) => a.status == 'approved').length;
    final review = _accounts.where((a) => a.status == 'review').length;
    final flagged = _accounts.where((a) => a.status == 'flagged').length;
    final avgScore = _accounts.isEmpty ? 0.0 :
        _accounts.map((a) => a.acceptanceScore).reduce((a, b) => a + b) / _accounts.length;

    // Classification distribution
    final rootDist = <String, int>{};
    for (final a in _accounts) {
      rootDist[a.rootClass] = (rootDist[a.rootClass] ?? 0) + 1;
    }

    // Level distribution
    final levelDist = <int, int>{};
    for (final a in _accounts) {
      levelDist[a.level] = (levelDist[a.level] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats row
          Row(
            children: [
              Expanded(child: _statCard('إجمالي', '${_accounts.length}', AppColors.blueC, Icons.account_balance)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('معتمد', '$approved', AppColors.greenC, Icons.check_circle)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('مراجعة', '$review', AppColors.orangeC, Icons.visibility)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('معلّم', '$flagged', AppColors.redC, Icons.flag)),
            ],
          ),
          const SizedBox(height: 20),

          // Acceptance score
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100, height: 100,
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 100, height: 100,
                          child: CircularProgressIndicator(
                            value: avgScore / 100,
                            strokeWidth: 8,
                            backgroundColor: AppColors.navyMid,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              avgScore >= 85 ? AppColors.greenC : (avgScore >= 60 ? AppColors.orangeC : AppColors.redC)),
                          ),
                        ),
                      ),
                      Center(
                        child: Text('${avgScore.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('درجة القبول الإجمالية',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
                      const SizedBox(height: 8),
                      Text(
                        avgScore >= 85 ? 'جودة الدليل المحاسبي ممتازة' :
                        avgScore >= 60 ? 'يحتاج بعض التعديلات' : 'يحتاج مراجعة شاملة',
                        style: TextStyle(fontSize: 12, color: AppColors.textMid),
                      ),
                      if (_detectedErp.isNotEmpty && _detectedErp != 'غير معروف') ...[
                        const SizedBox(height: 4),
                        Text('البرنامج: $_detectedErp', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Root classification distribution
          Text('توزيع التصنيفات الجذرية',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: rootDist.entries.map((e) {
                final pct = _accounts.isEmpty ? 0.0 : e.value / _accounts.length;
                final color = _rootColor(e.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: TextStyle(fontSize: 12, color: AppColors.textColor))),
                          Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct, minHeight: 4,
                          backgroundColor: AppColors.navyMid,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Level distribution
          Text('توزيع المستويات',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: (levelDist.keys.toList()..sort()).map((lvl) {
                final count = levelDist[lvl]!;
                final pct = _accounts.isEmpty ? 0.0 : count / _accounts.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('المستوى $lvl', style: TextStyle(fontSize: 12, color: AppColors.textColor)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct, minHeight: 6,
                            backgroundColor: AppColors.navyMid,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold.withOpacity(0.4 + 0.15 * lvl)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 30,
                        child: Text('$count', textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Smart analysis insights
          const SizedBox(height: 20),
          Text('التحليل الذكي',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
          const SizedBox(height: 12),
          _buildInsightsCard(),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: AppColors.textMid)),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    final closableCount = _accounts.where((a) => a.isClosable).length;
    final bankCount = _accounts.where((a) => a.isBankReconcilable).length;
    final bsCount = _accounts.where((a) => a.reportType == 'ميزانية').length;
    final isCount = _accounts.where((a) => a.reportType == 'دخل').length;
    final debitCount = _accounts.where((a) => a.nature == 'مدين').length;
    final creditCount = _accounts.where((a) => a.nature == 'دائن').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _insightRow(Icons.swap_horiz, 'الطبيعة', 'مدين: $debitCount — دائن: $creditCount', AppColors.blueC),
          _insightRow(Icons.description, 'نوع التقرير', 'ميزانية: $bsCount — دخل: $isCount', AppColors.purpleC),
          _insightRow(Icons.lock_clock, 'حسابات مؤقتة (قابلة للإقفال)', '$closableCount حساب', AppColors.orangeC),
          _insightRow(Icons.account_balance, 'حسابات بنكية (قابلة للتسوية)', '$bankCount حساب', AppColors.greenC),
        ],
      ),
    );
  }

  Widget _insightRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMid)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textColor)),
        ],
      ),
    );
  }

  Color _rootColor(String root) {
    switch (root) {
      case 'أصول': return AppColors.blueC;
      case 'التزامات': return AppColors.redC;
      case 'حقوق ملكية': return AppColors.purpleC;
      case 'إيرادات': return AppColors.greenC;
      case 'مصروفات': return AppColors.orangeC;
      default: return AppColors.textDim;
    }
  }

  // ─── Accounts Tab (جدول الحسابات المصنفة) ──────────────────

  Widget _buildAccountsTab() {
    // Filter
    List<CoaAccount> filtered = _accounts;
    if (_filterStatus == 'duplicate') {
      filtered = _accounts.where((a) => a.isDuplicateCode).toList();
    } else if (_filterStatus != 'all') {
      filtered = _accounts.where((a) => a.status == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) =>
          a.code.contains(_searchQuery) ||
          a.name.contains(_searchQuery)).toList();
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.navyLight,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: TextField(
                        style: TextStyle(color: AppColors.textColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث بالكود أو الاسم...',
                          hintStyle: TextStyle(color: AppColors.textDim, fontSize: 13),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: AppColors.textDim, size: 20),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${filtered.length} حساب',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    _filterChip('الكل', 'all', _accounts.length),
                    const SizedBox(width: 6),
                    _filterChip('معتمد', 'approved', _accounts.where((a) => a.status == 'approved').length),
                    const SizedBox(width: 6),
                    _filterChip('مراجعة', 'review', _accounts.where((a) => a.status == 'review').length),
                    const SizedBox(width: 6),
                    _filterChip('معلّم', 'flagged', _accounts.where((a) => a.status == 'flagged').length),
                    const SizedBox(width: 6),
                    _filterChip('مكرر', 'duplicate', _accounts.where((a) => a.isDuplicateCode).length),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: AppColors.navyMid,
          child: Row(
            children: [
              SizedBox(width: 60, child: Text('الكود', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDim))),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDim))),
              SizedBox(width: 60, child: Text('الفئة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDim))),
              SizedBox(width: 50, child: Text('الطبيعة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDim))),
              SizedBox(width: 60, child: Text('القبول', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDim))),
              SizedBox(width: 50, child: Text('الحالة', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDim))),
            ],
          ),
        ),
        // Table rows
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final a = filtered[i];
              final scoreColor = a.acceptanceScore >= 85 ? AppColors.greenC :
                                 a.acceptanceScore >= 60 ? AppColors.orangeC : AppColors.redC;
              final statusText = a.status == 'approved' ? 'معتمد' :
                                 a.status == 'review' ? 'مراجعة' : 'معلّم';
              final statusColor = a.status == 'approved' ? AppColors.greenC :
                                  a.status == 'review' ? AppColors.orangeC : AppColors.redC;
              return GestureDetector(
                onTap: () => _showEditDialog(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.borderColor.withOpacity(0.3))),
                    color: i.isEven ? AppColors.cardBg : AppColors.navy,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(a.code,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: a.isDuplicateCode ? AppColors.redC : AppColors.goldLight,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(a.name, style: TextStyle(fontSize: 12, color: AppColors.textColor),
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(a.rootClass.length > 6 ? a.rootClass.substring(0, 6) : a.rootClass,
                            style: TextStyle(fontSize: 10, color: _rootColor(a.rootClass))),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(a.nature, style: TextStyle(fontSize: 10, color: AppColors.textMid)),
                      ),
                      // Confidence meter
                      SizedBox(
                        width: 60,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: a.acceptanceScore / 100, minHeight: 6,
                                  backgroundColor: AppColors.navyMid,
                                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('${a.acceptanceScore.toInt()}',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: scoreColor)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(statusText,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Quality Tab (6 أبعاد الجودة) ──────────────────────────

  Widget _buildQualityTab() {
    final total = _accounts.length;
    if (total == 0) {
      return Center(child: Text('لا توجد حسابات', style: TextStyle(color: AppColors.textMid)));
    }

    // Calculate quality dimensions
    final avgScore = _accounts.map((a) => a.acceptanceScore).reduce((a, b) => a + b) / total;

    // Completeness: accounts with non-empty code, name, and rootClass
    final complete = _accounts.where((a) =>
        a.code.isNotEmpty && a.name.trim().length >= 3 && a.rootClass != 'غير محدد').length;
    final completeness = (complete / total * 100).round();

    // Consistency: accounts where level matches code pattern
    final consistent = _accounts.where((a) => a.parentCode.isNotEmpty || a.level <= 1).length;
    final consistency = (consistent / total * 100).round();

    // Naming clarity: accounts with name length > 5
    final clearNames = _accounts.where((a) => a.name.trim().length > 5).length;
    final naming = (clearNames / total * 100).round();

    // Duplication risk: inverse of duplicate ratio
    final dupeCount = _accounts.where((a) => a.isDuplicateCode).length;
    final duplication = ((1 - dupeCount / total) * 100).round();

    // Reporting readiness: accounts with valid reportType
    final reportReady = _accounts.where((a) =>
        a.reportType == 'ميزانية' || a.reportType == 'دخل').length;
    final reporting = (reportReady / total * 100).round();

    // Mapping confidence: accounts with score >= 75
    final highConf = _accounts.where((a) => a.acceptanceScore >= 75).length;
    final mapping = (highConf / total * 100).round();

    final overall = (completeness * 0.25 + consistency * 0.20 + naming * 0.15 +
        duplication * 0.15 + reporting * 0.15 + mapping * 0.10).round();

    final overallColor = overall >= 80 ? AppColors.greenC : (overall >= 60 ? AppColors.orangeC : AppColors.redC);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall score card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('درجة الجودة الإجمالية — Overall COA Quality Score',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textColor)),
                    ),
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: overallColor, width: 5),
                      ),
                      child: Center(
                        child: Text('$overall',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: overallColor)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 6 dimensions grid
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _qualityDimension('الاكتمال', 'Completeness', completeness, '25%', AppColors.blueC),
                    _qualityDimension('الاتساق', 'Consistency', consistency, '20%', AppColors.greenC),
                    _qualityDimension('وضوح التسمية', 'Naming', naming, '15%', AppColors.purpleC),
                    _qualityDimension('خطر التكرار', 'Duplication', duplication, '15%', AppColors.orangeC),
                    _qualityDimension('جاهزية التقارير', 'Reporting', reporting, '15%', AppColors.goldLight),
                    _qualityDimension('ثقة الربط', 'Mapping', mapping, '10%', AppColors.blueC),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Warnings
          Text('التحذيرات والملاحظات',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
          const SizedBox(height: 12),
          if (completeness < 80) _warningCard('الاكتمال منخفض', 'بعض الحسابات بدون تصنيف واضح أو اسم قصير', AppColors.orangeC),
          if (duplication < 90) _warningCard('يوجد أكواد مكررة', '$dupeCount حساب بأكواد مكررة — يحتاج مراجعة', AppColors.redC),
          if (naming < 70) _warningCard('أسماء غامضة', 'بعض الحسابات بأسماء قصيرة أو غير واضحة', AppColors.orangeC),
          if (reporting < 70) _warningCard('جاهزية التقارير', 'بعض الحسابات بدون نوع تقرير محدد', AppColors.blueC),
          if (completeness >= 80 && duplication >= 90 && naming >= 70 && reporting >= 70)
            _warningCard('لا توجد تحذيرات', 'الجودة ممتازة — جاهز للاعتماد', AppColors.greenC),

          const SizedBox(height: 20),

          // Readiness for approval
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: overall >= 70 ? AppColors.greenC.withOpacity(0.08) : AppColors.redC.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (overall >= 70 ? AppColors.greenC : AppColors.redC).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(overall >= 70 ? Icons.check_circle : Icons.cancel,
                    color: overall >= 70 ? AppColors.greenC : AppColors.redC, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(overall >= 70 ? 'جاهز للاعتماد' : 'غير جاهز للاعتماد',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: overall >= 70 ? AppColors.greenC : AppColors.redC)),
                      Text(overall >= 70
                          ? 'الدليل يستوفي الحد الأدنى من الجودة للانتقال إلى ميزان المراجعة'
                          : 'يحتاج تحسين الجودة — راجع التحذيرات أعلاه',
                          style: TextStyle(fontSize: 11, color: AppColors.textMid)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qualityDimension(String label, String labelEn, int value, String weight, Color color) {
    final dimColor = value >= 80 ? AppColors.greenC : (value >= 60 ? AppColors.orangeC : AppColors.redC);
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.navyMid,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.textColor))),
                Text('وزن $weight', style: TextStyle(fontSize: 9, color: AppColors.textDim)),
              ],
            ),
            const SizedBox(height: 4),
            Text(labelEn, style: TextStyle(fontSize: 9, color: AppColors.textDim)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: value / 100, minHeight: 8,
                      backgroundColor: AppColors.navy,
                      valueColor: AlwaysStoppedAnimation<Color>(dimColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: dimColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningCard(String title, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(color == AppColors.greenC ? Icons.check_circle : Icons.warning_amber,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                Text(desc, style: TextStyle(fontSize: 11, color: AppColors.textMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Review Tab ────────────────────────────────────────────

  Widget _buildReviewTab() {
    // Filter accounts
    List<CoaAccount> filtered = _accounts;
    if (_filterStatus == 'duplicate') {
      filtered = _accounts.where((a) => a.isDuplicateCode).toList();
    } else if (_filterStatus != 'all') {
      filtered = _accounts.where((a) => a.status == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) =>
          a.code.contains(_searchQuery) ||
          a.name.contains(_searchQuery)).toList();
    }

    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.navyLight,
          child: Column(
            children: [
              // Search
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: TextField(
                  style: TextStyle(color: AppColors.textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث بالكود أو الاسم...',
                    hintStyle: TextStyle(color: AppColors.textDim, fontSize: 13),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: AppColors.textDim, size: 20),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    _filterChip('الكل', 'all', filtered.length == _accounts.length ? _accounts.length : null),
                    const SizedBox(width: 6),
                    _filterChip('معتمد', 'approved', _accounts.where((a) => a.status == 'approved').length),
                    const SizedBox(width: 6),
                    _filterChip('مراجعة', 'review', _accounts.where((a) => a.status == 'review').length),
                    const SizedBox(width: 6),
                    _filterChip('معلّم', 'flagged', _accounts.where((a) => a.status == 'flagged').length),
                    const SizedBox(width: 6),
                    _filterChip('مكرر', 'duplicate', _accounts.where((a) => a.isDuplicateCode).length),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Accounts list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _buildAccountCard(filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String status, int? count) {
    final isActive = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold.withOpacity(0.2) : AppColors.navy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.gold : AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.gold : AppColors.textMid,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.gold : AppColors.textDim).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count', style: TextStyle(fontSize: 10, color: isActive ? AppColors.gold : AppColors.textDim)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(CoaAccount acc) {
    final scoreColor = acc.acceptanceScore >= 85 ? AppColors.greenC :
                       acc.acceptanceScore >= 60 ? AppColors.orangeC : AppColors.redC;
    final statusColor = acc.status == 'approved' ? AppColors.greenC :
                        acc.status == 'review' ? AppColors.orangeC : AppColors.redC;
    final statusText = acc.status == 'approved' ? 'معتمد' :
                       acc.status == 'review' ? 'مراجعة' : 'معلّم';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: AppColors.textMid,
        collapsedIconColor: AppColors.textMid,
        title: Row(
          children: [
            // Score badge
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withOpacity(0.15),
                border: Border.all(color: scoreColor, width: 2),
              ),
              child: Center(
                child: Text('${acc.acceptanceScore.toInt()}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(acc.code, style: TextStyle(fontSize: 12, color: acc.isDuplicateCode ? AppColors.redC : AppColors.goldLight, fontWeight: FontWeight.bold)),
                      if (acc.isDuplicateCode) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.redC.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('مكرر', style: TextStyle(fontSize: 9, color: AppColors.redC, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(acc.name, style: TextStyle(fontSize: 13, color: AppColors.textColor), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(statusText, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        children: [
          // Details grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _detailRow('المستوى', 'المستوى ${acc.level} — ${acc.accountType}'),
                _detailRow('التصنيف الجذري', acc.rootClass),
                _detailRow('الطبيعة', acc.nature),
                _detailRow('نوع التقرير', acc.reportType),
                _detailRow('الحساب الرئيسي', acc.parentCode.isEmpty ? 'جذر' : acc.parentCode),
                if (acc.isClosable) _detailRow('الإقفال', 'حساب مؤقت — يُقفل نهاية الفترة'),
                if (acc.isBankReconcilable) _detailRow('التسوية البنكية', 'قابل للتسوية'),
              ],
            ),
          ),
          // Flags
          if (acc.flags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.redC.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.redC.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.orangeC, size: 16),
                      const SizedBox(width: 6),
                      Text('ملاحظات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.orangeC)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...acc.flags.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: AppColors.redC, fontSize: 12)),
                        Expanded(child: Text(f, style: TextStyle(fontSize: 11, color: AppColors.textColor))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          // Action buttons
          if (acc.status != 'approved' || acc.isDuplicateCode) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(acc),
                  icon: Icon(Icons.edit, size: 16, color: AppColors.gold),
                  label: Text('تعديل', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                ),
                if (acc.isDuplicateCode) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showReassignDialog(acc),
                    icon: Icon(Icons.swap_horiz, size: 16, color: AppColors.orangeC),
                    label: Text('نقل / إعادة تبويب', style: TextStyle(color: AppColors.orangeC, fontSize: 12)),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      acc.status = 'approved';
                      acc.acceptanceScore = 100;
                      acc.flags = [];
                     _hasUnsavedChanges = true; });
                  },
                  icon: Icon(Icons.check_circle, size: 16, color: AppColors.greenC),
                  label: Text('قبول على الوضع الحالي', style: TextStyle(color: AppColors.greenC, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.textDim))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.textColor))),
        ],
      ),
    );
  }

  void _showEditDialog(CoaAccount acc) {
    final codeCtrl = TextEditingController(text: acc.code);
    final nameCtrl = TextEditingController(text: acc.name);
    final levelCtrl = TextEditingController(text: '${acc.level}');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.navyLight,
          title: Text('تعديل حساب', style: TextStyle(color: AppColors.gold, fontSize: 16)),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (acc.isDuplicateCode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.redC.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.redC.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.redC, size: 16),
                            const SizedBox(width: 6),
                            Text('كود مكرر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.redC)),
                          ],
                        ),
                        if (acc.suggestedCode.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('الكود المقترح: ${acc.suggestedCode}', style: TextStyle(fontSize: 11, color: AppColors.orangeC)),
                        ],
                        if (_classifyByName(acc.name).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('التصنيف بالاسم: ${_classifyByName(acc.name)}', style: TextStyle(fontSize: 11, color: AppColors.blueC)),
                        ],
                      ],
                    ),
                  ),
                _editField('الكود', codeCtrl),
                const SizedBox(height: 12),
                _editField('اسم الحساب', nameCtrl),
                const SizedBox(height: 12),
                _editField('المستوى', levelCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: AppColors.textMid)),
            ),
            if (acc.isDuplicateCode && acc.suggestedCode.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeC),
                onPressed: () {
                  codeCtrl.text = acc.suggestedCode;
                },
                child: Text('تطبيق المقترح', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () {
                setState(() {
                  final oldCode = acc.code;
                  final newEditCode = codeCtrl.text.trim();
                  acc.name = nameCtrl.text.trim();
                  acc.level = int.tryParse(levelCtrl.text.trim()) ?? acc.level;

                  // If code changed, cascade to descendants
                  if (oldCode != newEditCode) {
                    // Find descendants BEFORE changing the code
                    final editDescendants = _accounts
                        .where((a) => a.code.startsWith(oldCode) && a.code != oldCode)
                        .toList()
                      ..sort((a, b) => a.code.length.compareTo(b.code.length));

                    acc.code = newEditCode;
                    acc.uniqueId = '${newEditCode}_${acc.rowIndex}';

                    // Cascade code changes to descendants
                    for (final desc in editDescendants) {
                      final newDescCode = newEditCode + desc.code.substring(oldCode.length);
                      desc.code = newDescCode;
                      desc.uniqueId = '${newDescCode}_${desc.rowIndex}';
                    }

                    // Update parent references
                    for (final child in _accounts) {
                      if (child.parentCode == oldCode) {
                        child.parentCode = newEditCode;
                        child.parentUniqueId = acc.uniqueId;
                      } else if (child.parentCode.startsWith(oldCode) && child.parentCode.length > oldCode.length) {
                        child.parentCode = newEditCode + child.parentCode.substring(oldCode.length);
                        final np = _accounts.where((a) => a.code == child.parentCode).toList();
                        if (np.isNotEmpty) child.parentUniqueId = np.first.uniqueId;
                      }
                    }

                    // Check if old code duplication resolved
                    final oldDupes = _accounts.where((a) => a.code == oldCode).toList();
                    if (oldDupes.length == 1) {
                      oldDupes.first.isDuplicateCode = false;
                      oldDupes.first.suggestedCode = '';
                      oldDupes.first.flags = oldDupes.first.flags
                          .where((f) => !f.contains('كود مكرر') && !f.contains('الكود المقترح') && !f.contains('التصنيف بالاسم'))
                          .toList();
                    }
                  } else {
                    acc.code = newEditCode;
                    acc.uniqueId = '${newEditCode}_${acc.rowIndex}';
                  }

                  // Re-check duplicate status
                  final dupeCount = _accounts.where((a) => a.code == acc.code).length;
                  acc.isDuplicateCode = dupeCount > 1;
                  // Re-classify
                  acc.rootClass = _classifyRoot(acc.code);
                  acc.nature = _determineNature(acc.rootClass);
                  acc.reportType = _determineReportType(acc.rootClass);
                  acc.isClosable = _isClosable(acc.rootClass);
                  acc.isBankReconcilable = _detectBankReconcilable(acc.name);
                  acc.parentCode = _findParentCode(acc.code, _accounts);
                  if (acc.level <= 2) acc.accountType = 'حساب رئيسي';
                  else if (acc.level == 3) acc.accountType = 'حساب فرعي';
                  else acc.accountType = 'حساب تفصيلي';
                  // Recalculate scores for all accounts
                  for (final a in _accounts) {
                    a.acceptanceScore = _calculateAcceptanceScore(a, _accounts);
                  }
                });
                Navigator.pop(ctx);
              },
              child: Text('حفظ وإعادة تقييم', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReassignDialog(CoaAccount acc) {
    final newCodeCtrl = TextEditingController(text: acc.suggestedCode.isNotEmpty ? acc.suggestedCode : acc.code);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.navyLight,
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: AppColors.orangeC, size: 20),
              const SizedBox(width: 8),
              Text('نقل / إعادة تبويب', style: TextStyle(color: AppColors.orangeC, fontSize: 15)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحساب الحالي:', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                      const SizedBox(height: 4),
                      Text('${acc.code} — ${acc.name}', style: TextStyle(fontSize: 13, color: AppColors.textColor)),
                      Text('التصنيف بالاسم: ${_classifyByName(acc.name).isNotEmpty ? _classifyByName(acc.name) : "غير محدد"}',
                          style: TextStyle(fontSize: 11, color: AppColors.blueC)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Suggested fix
                if (acc.suggestedCode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.greenC.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.greenC.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الاقتراح:', style: TextStyle(fontSize: 11, color: AppColors.greenC)),
                        const SizedBox(height: 4),
                        Text('تغيير الكود إلى: ${acc.suggestedCode}', style: TextStyle(fontSize: 13, color: AppColors.greenC)),
                        if (acc.suggestedParent.isNotEmpty)
                          Text('نقل تحت الحساب: ${acc.suggestedParent}', style: TextStyle(fontSize: 11, color: AppColors.greenC)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Manual code entry
                _editField('الكود الجديد', newCodeCtrl),
                const SizedBox(height: 8),
                Text('سيتم نقل جميع الحسابات الفرعية والتفصيلية تلقائياً',
                    style: TextStyle(fontSize: 10, color: AppColors.textDim)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: AppColors.textMid)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeC),
              onPressed: () {
                final newCode = newCodeCtrl.text.trim();
                if (newCode.isEmpty || newCode == acc.code) {
                  Navigator.pop(ctx);
                  return;
                }
                setState(() {
                  final oldCode = acc.code;

                  // === CASCADING CODE UPDATE ===
                  // Find ALL descendants whose code starts with oldCode
                  // Sort by code length (shortest first = parents before children)
                  final descendants = _accounts
                      .where((a) => a.code.startsWith(oldCode) && a.code != oldCode)
                      .toList()
                    ..sort((a, b) => a.code.length.compareTo(b.code.length));

                  // Update the account's own code first
                  acc.code = newCode;
                  acc.uniqueId = '${newCode}_${acc.rowIndex}';
                  acc.isDuplicateCode = false;
                  acc.suggestedCode = '';
                  acc.flags = acc.flags
                      .where((f) => !f.contains('كود مكرر') && !f.contains('الكود المقترح') && !f.contains('التصنيف بالاسم') && !f.contains('التبويب المقترح'))
                      .toList();

                  // Now cascade: update all descendants' codes
                  // e.g., oldCode=122, newCode=129 → child 12201 becomes 12901, 12201001 becomes 12901001
                  for (final desc in descendants) {
                    final oldDescCode = desc.code;
                    final newDescCode = newCode + oldDescCode.substring(oldCode.length);
                    desc.code = newDescCode;
                    desc.uniqueId = '${newDescCode}_${desc.rowIndex}';
                    // Clear duplicate flags on descendants too
                    final dupeCount = _accounts.where((a) => a.code == newDescCode).length;
                    desc.isDuplicateCode = dupeCount > 1;
                    if (!desc.isDuplicateCode) {
                      desc.suggestedCode = '';
                      desc.flags = desc.flags
                          .where((f) => !f.contains('كود مكرر') && !f.contains('الكود المقترح') && !f.contains('التصنيف بالاسم') && !f.contains('التبويب المقترح'))
                          .toList();
                    }
                  }

                  // Update parentCode references for all descendants
                  // Direct children: parentCode was oldCode → now newCode
                  // Deeper descendants: parentCode started with oldCode → replace prefix
                  for (final child in _accounts) {
                    if (child.parentCode == oldCode) {
                      child.parentCode = newCode;
                      child.parentUniqueId = acc.uniqueId;
                    } else if (child.parentCode.startsWith(oldCode)) {
                      child.parentCode = newCode + child.parentCode.substring(oldCode.length);
                      // Find the actual parent account with the new code
                      final newParent = _accounts.where((a) => a.code == child.parentCode).toList();
                      if (newParent.isNotEmpty) {
                        child.parentUniqueId = newParent.first.uniqueId;
                      }
                    }
                  }

                  // Check if old code duplication is resolved
                  final remaining = _accounts.where((a) => a.code == oldCode).toList();
                  if (remaining.length == 1) {
                    remaining.first.isDuplicateCode = false;
                    remaining.first.suggestedCode = '';
                    remaining.first.flags = remaining.first.flags
                        .where((f) => !f.contains('كود مكرر') && !f.contains('الكود المقترح') && !f.contains('التصنيف بالاسم') && !f.contains('التبويب المقترح'))
                        .toList();
                  }

                  // Collect all affected uniqueIds (the account + its descendants)
                  final affectedIds = <String>{acc.uniqueId};
                  for (final d in descendants) affectedIds.add(d.uniqueId);

                  // Re-classify and rescore ALL accounts
                  for (final a in _accounts) {
                    a.rootClass = _classifyRoot(a.code);
                    a.nature = _determineNature(a.rootClass);
                    a.reportType = _determineReportType(a.rootClass);
                    a.isClosable = _isClosable(a.rootClass);
                    // Only re-find parent for accounts NOT in the cascade
                    // (cascade already set correct parentCode)
                    if (!affectedIds.contains(a.uniqueId)) {
                      a.parentCode = _findParentCode(a.code, _accounts);
                    }
                    a.acceptanceScore = _calculateAcceptanceScore(a, _accounts);
                  }
                });
                Navigator.pop(ctx);
              },
              child: Text('تطبيق النقل', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMid)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: TextField(
            controller: ctrl,
            style: TextStyle(color: AppColors.textColor, fontSize: 13),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  // ─── Tree Tab (Unlimited Nesting) ──────────────────────────

  Widget _buildTreeTab() {
    // Build tree structure
    final roots = _buildTreeStructure();

    return Column(
      children: [
        // Tree toolbar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.navyLight,
          child: Row(
            children: [
              Icon(Icons.account_tree, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('الشجرة المحاسبية',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
              const Spacer(),
              // Expand all button
              GestureDetector(
                onTap: () => setState(() {
                  for (final a in _accounts) _treeExpanded[a.uniqueId] = true;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Text('فتح الكل', style: TextStyle(fontSize: 11, color: AppColors.textMid)),
                ),
              ),
              const SizedBox(width: 8),
              // Collapse all button
              GestureDetector(
                onTap: () => setState(() => _treeExpanded.clear()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Text('إغلاق الكل', style: TextStyle(fontSize: 11, color: AppColors.textMid)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: roots.isEmpty
              ? Center(child: Text('لا توجد حسابات', style: TextStyle(color: AppColors.textMid)))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: roots.map((root) => _buildTreeNode(root, 0)).toList(),
                ),
        ),
      ],
    );
  }

  List<CoaAccount> _buildTreeStructure() {
    // Create a map using uniqueId for duplicate-safe lookup
    final uidMap = <String, CoaAccount>{};
    final codeMap = <String, List<CoaAccount>>{};
    for (final acc in _accounts) {
      acc.children = [];
      uidMap[acc.uniqueId] = acc;
      codeMap.putIfAbsent(acc.code, () => []);
      codeMap[acc.code]!.add(acc);
    }

    // Build parent-child relationships using uniqueId when available
    final roots = <CoaAccount>[];
    for (final acc in _accounts) {
      bool attached = false;

      // Try uniqueId-based parent first (duplicate-aware)
      if (acc.parentUniqueId.isNotEmpty && uidMap.containsKey(acc.parentUniqueId)) {
        final parent = uidMap[acc.parentUniqueId]!;
        parent.children = [...parent.children, acc];
        attached = true;
      }
      // Fallback to code-based parent (non-duplicate case)
      else if (acc.parentCode.isNotEmpty && codeMap.containsKey(acc.parentCode)) {
        final candidates = codeMap[acc.parentCode]!;
        if (candidates.length == 1) {
          candidates.first.children = [...candidates.first.children, acc];
          attached = true;
        } else {
          // Multiple parents with same code — use name classification
          final myCategory = _classifyByName(acc.name);
          CoaAccount? bestParent;
          for (final p in candidates) {
            if (myCategory.isNotEmpty && _classifyByName(p.name) == myCategory) {
              bestParent = p;
              break;
            }
          }
          bestParent ??= candidates.first;
          bestParent.children = [...bestParent.children, acc];
          attached = true;
        }
      }

      if (!attached) {
        roots.add(acc);
      }
    }

    return roots;
  }

  Widget _buildTreeNode(CoaAccount acc, int depth) {
    final hasChildren = acc.children.isNotEmpty;
    final isExpanded = _treeExpanded[acc.uniqueId] ?? false;
    final indent = depth * 20.0;

    // Colors per depth
    final depthColors = [
      AppColors.gold, AppColors.blueC, AppColors.greenC,
      AppColors.purpleC, AppColors.orangeC, AppColors.goldLight,
    ];
    final nodeColor = depthColors[depth % depthColors.length];
    final scoreColor = acc.acceptanceScore >= 85 ? AppColors.greenC :
                       acc.acceptanceScore >= 60 ? AppColors.orangeC : AppColors.redC;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: hasChildren ? () => setState(() => _treeExpanded[acc.uniqueId] = !isExpanded) : null,
          child: Container(
            margin: EdgeInsets.only(right: indent, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: acc.isDuplicateCode
                  ? AppColors.redC.withOpacity(0.08)
                  : (depth == 0 ? AppColors.navyMid : AppColors.cardBg),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: acc.isDuplicateCode
                    ? AppColors.redC.withOpacity(0.6)
                    : (acc.flags.isNotEmpty ? AppColors.redC.withOpacity(0.4) : nodeColor.withOpacity(0.15)),
                width: acc.isDuplicateCode ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Expand/collapse icon
                    if (hasChildren)
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_left,
                        color: nodeColor, size: 20,
                      )
                    else
                      SizedBox(width: 20, child: Icon(Icons.circle, color: nodeColor.withOpacity(0.4), size: 6)),
                    const SizedBox(width: 8),
                    // Level indicator
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nodeColor.withOpacity(0.15),
                      ),
                      child: Center(
                        child: Text('${acc.level}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: nodeColor)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Code (with duplicate indicator)
                    if (acc.isDuplicateCode) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.redC.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.redC.withOpacity(0.4)),
                        ),
                        child: Text(acc.code,
                            style: TextStyle(fontSize: 12, color: AppColors.redC, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      Text(acc.code,
                          style: TextStyle(fontSize: 12, color: AppColors.goldLight, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(width: 10),
                    // Name
                    Expanded(
                      child: Text(acc.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textColor,
                            fontWeight: hasChildren ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ),
                    // Children count
                    if (hasChildren) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: nodeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${acc.children.length}',
                            style: TextStyle(fontSize: 10, color: nodeColor)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Score
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withOpacity(0.1),
                        border: Border.all(color: scoreColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text('${acc.acceptanceScore.toInt()}',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: scoreColor)),
                      ),
                    ),
                    // Flag indicator
                    if (acc.flags.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.warning_amber, color: AppColors.redC, size: 16),
                    ],
                    // Edit button
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showEditDialog(acc),
                      child: Icon(Icons.edit, color: AppColors.textDim, size: 14),
                    ),
                  ],
                ),
                // Duplicate warning banner
                if (acc.isDuplicateCode) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.redC.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.redC, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'كود مكرر — التصنيف: ${_classifyByName(acc.name).isNotEmpty ? _classifyByName(acc.name) : "غير محدد"}'
                            '${acc.suggestedCode.isNotEmpty ? " • الكود المقترح: ${acc.suggestedCode}" : ""}',
                            style: TextStyle(fontSize: 10, color: AppColors.redC),
                          ),
                        ),
                        if (acc.suggestedCode.isNotEmpty || acc.suggestedParent.isNotEmpty)
                          GestureDetector(
                            onTap: () => _showReassignDialog(acc),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.orangeC.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.orangeC.withOpacity(0.5)),
                              ),
                              child: Text('نقل / إعادة تبويب',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.orangeC)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Children
        if (isExpanded && hasChildren)
          ...acc.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  // ─── Report Tab ────────────────────────────────────────────

}
