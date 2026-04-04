import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme apexTextTheme(TextTheme base) => GoogleFonts.tajawalTextTheme(base);

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}

InputDecoration apexInput(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  prefixIcon: icon != null ? Icon(icon, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3,
  labelStyle: const TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)),
);

Widget apexCard(String title, List<Widget> children, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    const Divider(color: AC.bdr, height: 18), ...children]));

Widget apexKV(String key, String value, {Color? valueColor}) => Padding(
  padding: const EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(key, style: const TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(value, style: TextStyle(color: valueColor ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget apexBadge(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
  child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
