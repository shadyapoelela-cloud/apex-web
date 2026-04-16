/// Shared visual helpers used across the main-nav tabs.
/// These were originally module-private functions inside main.dart; they
/// are now public (prefixed `mh` for Main Helpers) so they can be reused
/// after further extraction of tabs into feature folders.
library;

import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Title + bordered container with a coloured heading.
Widget mhCard(String title, List<Widget> children, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AC.navy3,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: accent ?? AC.bdr),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(
        color: accent ?? AC.gold,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      )),
      Divider(color: AC.bdr, height: 18),
      ...children,
    ],
  ),
);

/// Label / value row with space-between alignment.
Widget mhKv(String key, String value, {Color? valueColor}) => Padding(
  padding: const EdgeInsets.only(bottom: 5),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(key, style: TextStyle(color: AC.ts, fontSize: 13)),
      Flexible(
        child: Text(value,
          style: TextStyle(color: valueColor ?? AC.tp, fontSize: 13),
          textAlign: TextAlign.end,
        ),
      ),
    ],
  ),
);

/// Small coloured pill.
Widget mhBadge(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(text, style: TextStyle(
    color: color,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  )),
);

/// Navy-filled input decoration with gold focus ring and optional icon.
InputDecoration mhInput(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  prefixIcon: icon != null ? Icon(icon, color: AC.goldText, size: 20) : null,
  filled: true,
  fillColor: AC.navy3,
  labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AC.goldText),
  ),
);
