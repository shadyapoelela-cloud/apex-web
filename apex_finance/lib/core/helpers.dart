import 'package:flutter/material.dart';
import 'theme.dart';

/// Show a snackbar message
void showApexSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: isError ? AC.err : AC.ok,
  ));
}

/// Format date string
String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '—';
  try {
    final d = DateTime.parse(dateStr);
    return '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
  } catch (_) {
    return dateStr.length > 16 ? dateStr.substring(0, 16) : dateStr;
  }
}

/// Arabic number formatter
String formatNumber(dynamic value) {
  if (value == null) return '—';
  final n = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
  if (n.abs() >= 1e9) return '${(n / 1e9).toStringAsFixed(1)} مليار';
  if (n.abs() >= 1e6) return '${(n / 1e6).toStringAsFixed(1)} مليون';
  if (n.abs() >= 1e3) return '${(n / 1e3).toStringAsFixed(1)} ألف';
  return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
}