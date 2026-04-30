import 'package:flutter/material.dart';
import '../core/theme.dart';

InputDecoration apexInputDecoration(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.goldText, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.goldText)));
