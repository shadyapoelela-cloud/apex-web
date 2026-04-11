import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme apexTextTheme(TextTheme base) => GoogleFonts.tajawalTextTheme(base);

/// AC — Apex Colors. Supports dark/light mode switching.
/// Call AC.setLight(true/false) from the theme provider.
class AC {
  static bool _isLight = false;

  static void setLight(bool v) => _isLight = v;
  static bool get isLight => _isLight;

  // ── Primary ──
  static Color get gold => const Color(0xFFC9A84C);

  // ── Backgrounds ──
  static Color get navy => _isLight ? const Color(0xFFF5F3EE) : const Color(0xFF050D1A);
  static Color get navy2 => _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF080F1F);
  static Color get navy3 => _isLight ? const Color(0xFFFAF9F6) : const Color(0xFF0D1829);
  static Color get navy4 => _isLight ? const Color(0xFFEFEDE8) : const Color(0xFF0F2040);

  // ── Accent ──
  static Color get cyan => const Color(0xFF00C2E0);

  // ── Text ──
  static Color get tp => _isLight ? const Color(0xFF1A1A2E) : const Color(0xFFF0EDE6);
  static Color get ts => _isLight ? const Color(0xFF6B6860) : const Color(0xFF8A8880);

  // ── Status ──
  static Color get ok => const Color(0xFF2ECC8A);
  static Color get warn => const Color(0xFFF0A500);
  static Color get err => const Color(0xFFE05050);

  // ── Border ──
  static Color get bdr => _isLight ? const Color(0x33C9A84C) : const Color(0x26C9A84C);
}

InputDecoration apexInput(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  prefixIcon: icon != null ? Icon(icon, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3,
  labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.gold)),
);

Widget apexCard(String title, List<Widget> children, {Color? accent}) => Container(
  margin: EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    Divider(color: AC.bdr, height: 18), ...children]));

Widget apexKV(String key, String value, {Color? valueColor}) => Padding(
  padding: EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(key, style: TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(value, style: TextStyle(color: valueColor ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget apexBadge(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
  child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
