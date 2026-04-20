/// أدوات تحويل الأرقام الواردة من JSON بأمان.
///
/// المشكلة: Pydantic/FastAPI يُسلسل `Decimal` كـ String في JSON (مثل "100.00")،
/// بينما Dart `.toDouble()` يتطلب `num`. استخدام `.toDouble()` مباشرةً على
/// حقل Decimal يسبب TypeError في runtime ويُسقط الشاشة.
///
/// الحل: `asDouble(x)` يتعامل مع: null, num, String, bool.
/// ـ `asInt(x)` نسخة للأعداد الصحيحة (عدد السجلات، الكميات، إلخ).
library;

/// Converts any JSON-decoded value to double safely.
/// - null → 0.0
/// - num (int/double) → .toDouble()
/// - String → double.tryParse() or 0.0
/// - bool → 1.0 / 0.0
/// - anything else → 0.0
double asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return 0.0;
    return double.tryParse(trimmed) ?? 0.0;
  }
  if (v is bool) return v ? 1.0 : 0.0;
  return 0.0;
}

/// Converts any JSON-decoded value to int safely.
int asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return 0;
    return int.tryParse(trimmed) ?? (double.tryParse(trimmed)?.toInt() ?? 0);
  }
  if (v is bool) return v ? 1 : 0;
  return 0;
}

/// Returns a string representation safe for display.
/// null → fallback, anything else → toString().
String asString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  return v.toString();
}
