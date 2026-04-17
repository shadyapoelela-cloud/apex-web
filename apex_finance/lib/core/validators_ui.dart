/// APEX validators — pure functions for Saudi/MENA input validation.
///
/// Each validator returns `null` on success, or an Arabic error string on
/// failure (compatible with Flutter FormFieldValidator).
library;

/// Validates Saudi IBAN: "SA" + 22 alphanumeric chars.
/// Format: SAXX followed by 2-digit bank code + 18-char account number.
String? validateSaudiIban(String? raw) {
  if (raw == null || raw.isEmpty) return 'رقم IBAN مطلوب';
  final v = raw.replaceAll(' ', '').toUpperCase();
  if (!v.startsWith('SA')) return 'يجب أن يبدأ IBAN بـ SA';
  if (v.length != 24) return 'IBAN السعودي يجب أن يكون 24 حرفاً';
  if (!RegExp(r'^SA\d{22}$').hasMatch(v)) {
    return 'IBAN يحتوي على أحرف غير مسموحة';
  }
  if (!_mod97Check(v)) return 'رقم IBAN غير صحيح (فشل التحقق المرجعي)';
  return null;
}

/// Formats IBAN with spaces every 4 characters: "SA12 3456 7890 …".
String formatIban(String raw) {
  final clean = raw.replaceAll(' ', '').toUpperCase();
  final buf = StringBuffer();
  for (var i = 0; i < clean.length; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' ');
    buf.write(clean[i]);
  }
  return buf.toString();
}

/// Validates Saudi Commercial Registration (CR) number.
/// Format: 10-digit number starting with "10".
String? validateSaudiCR(String? raw) {
  if (raw == null || raw.isEmpty) return 'السجل التجاري مطلوب';
  final v = raw.trim();
  if (!RegExp(r'^\d{10}$').hasMatch(v)) {
    return 'السجل التجاري يجب أن يكون 10 أرقام';
  }
  if (!v.startsWith('10')) {
    return 'السجل التجاري يبدأ عادة بـ 10';
  }
  return null;
}

/// Validates Saudi VAT registration number (ZATCA format).
/// Format: 15 digits starting with 3 and ending with 3.
String? validateSaudiVatNumber(String? raw) {
  if (raw == null || raw.isEmpty) return 'الرقم الضريبي مطلوب';
  final v = raw.replaceAll(' ', '').replaceAll('-', '');
  if (!RegExp(r'^\d{15}$').hasMatch(v)) {
    return 'الرقم الضريبي يجب أن يكون 15 رقماً';
  }
  if (!v.startsWith('3') || !v.endsWith('3')) {
    return 'الرقم الضريبي يبدأ وينتهي بـ 3';
  }
  return null;
}

/// Validates SAR amount: non-negative, up to 2 decimals, ≤ 999,999,999.99.
String? validateSarAmount(String? raw) {
  if (raw == null || raw.isEmpty) return 'المبلغ مطلوب';
  final clean = raw.replaceAll(',', '').replaceAll(' ', '').replaceAll('ر.س', '').trim();
  final n = double.tryParse(clean);
  if (n == null) return 'قيمة رقمية غير صالحة';
  if (n < 0) return 'لا يُسمح بقيمة سالبة';
  if (n > 999999999.99) return 'المبلغ يتجاوز الحد الأعلى';
  // Max 2 decimals
  final decIdx = clean.indexOf('.');
  if (decIdx >= 0 && clean.length - decIdx - 1 > 2) {
    return 'حتى منزلتين عشريتين كحد أقصى';
  }
  return null;
}

/// Formats SAR amount with thousand separators. Example:
///   formatSarAmount(1234567.5) → "1,234,567.50"
String formatSarAmount(double value, {int decimals = 2}) {
  if (value.isNaN || value.isInfinite) return '0.00';
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final rev = whole.split('').reversed.toList();
  final buf = StringBuffer();
  for (var i = 0; i < rev.length; i++) {
    if (i > 0 && i % 3 == 0) buf.write(',');
    buf.write(rev[i]);
  }
  final wholeFmt = buf.toString().split('').reversed.join();
  return decimals > 0 ? '$wholeFmt.${parts[1]}' : wholeFmt;
}

/// Validates Saudi mobile number: +966 5XXXXXXXX (9 digits after country code).
String? validateSaudiMobile(String? raw) {
  if (raw == null || raw.isEmpty) return 'رقم الجوال مطلوب';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  // Accept: 9665XXXXXXXX, 05XXXXXXXX, 5XXXXXXXX
  String normalized;
  if (digits.startsWith('966')) {
    normalized = digits.substring(3);
  } else if (digits.startsWith('0')) {
    normalized = digits.substring(1);
  } else {
    normalized = digits;
  }
  if (normalized.length != 9 || !normalized.startsWith('5')) {
    return 'رقم جوال غير صحيح';
  }
  return null;
}

/// Generic required-field validator.
String? validateRequired(String? raw, {String fieldName = 'الحقل'}) {
  if (raw == null || raw.trim().isEmpty) return '$fieldName مطلوب';
  return null;
}

/// Validates email format (basic — server must re-validate).
String? validateEmail(String? raw) {
  if (raw == null || raw.isEmpty) return 'البريد الإلكتروني مطلوب';
  final v = raw.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
    return 'بريد إلكتروني غير صحيح';
  }
  return null;
}

// ── Internal helpers ──────────────────────────────────────────

/// ISO 13616 IBAN mod-97 check.
bool _mod97Check(String iban) {
  // Move first 4 chars to end.
  final rearranged = iban.substring(4) + iban.substring(0, 4);
  // Replace letters with digits: A=10, B=11, …, Z=35.
  final buf = StringBuffer();
  for (final ch in rearranged.codeUnits) {
    if (ch >= 0x30 && ch <= 0x39) {
      buf.writeCharCode(ch);
    } else if (ch >= 0x41 && ch <= 0x5A) {
      buf.write((ch - 0x41 + 10).toString());
    } else {
      return false;
    }
  }
  // Perform mod 97 on the potentially very long number by chunking.
  final s = buf.toString();
  var rem = 0;
  for (var i = 0; i < s.length; i += 9) {
    final end = (i + 9 < s.length) ? i + 9 : s.length;
    final chunk = '$rem${s.substring(i, end)}';
    rem = int.parse(chunk) % 97;
  }
  return rem == 1;
}
