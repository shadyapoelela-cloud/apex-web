/// APEX Platform — Shared UI helpers
/// Extracted from main.dart to reduce monolith size
library;

import 'package:flutter/material.dart';
import 'theme.dart';

Widget apexCard(String t, List<Widget> c, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    Divider(color: AC.bdr, height: 18), ...c]));

Widget apexKv(String k, String v, {Color? vc}) => Padding(padding: const EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget apexBadge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
  child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)));

InputDecoration apexInput(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.goldText, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.goldText)));
