/// APEX Pilot — Design System موحّد
///
/// موجات 3.1-3.10: هوية بصرية كاملة (colors + typography + spacing + shadows)
///
/// الاستخدام:
///   import 'package:apex_finance/pilot/design_system.dart';
///   Container(color: AD.navy2, ...)
///   Text('مرحبا', style: AD.h1);
///
/// مطابق للـ CompanySettings.brand_primary_color — يمكن overrideها runtime
/// عبر ThemeExtension لكل tenant (v2).
library;

import 'package:flutter/material.dart';
import '../core/theme.dart' as core_theme;

/// APEX Design tokens
class AD {
  AD._();

  // ══════════════════════════════════════════════════════════════════
  // 3.1 — Color Palette (Brand + Semantic)
  // ══════════════════════════════════════════════════════════════════

  // Brand — ذهبي فاخر + كحلي عميق (هوية APEX الأساسية)
  static Color get gold => core_theme.AC.gold;
  static const goldLight = Color(0xFFE5C459);
  static const goldDark = Color(0xFFA88A2C);

  // Navy scale — 5 مستويات من الأغمق للأفتح
  static Color get navy => core_theme.AC.navy; // background deepest
  static Color get navy2 => core_theme.AC.navy2; // surfaces
  static Color get navy3 => core_theme.AC.navy3; // elevated surfaces
  static const navy4 = Color(0xFF2A3E5E); // borders prominent
  static const navy5 = Color(0xFF3A4E6E); // dividers

  // Text scale — 4 مستويات (primary / secondary / tertiary / disabled)
  static const tp = Color(0xFFFFFFFF); // primary
  static Color get ts => core_theme.AC.ts; // secondary
  static Color get td => core_theme.AC.td; // tertiary
  static const tq = Color(0xFF475266); // quaternary (disabled)

  // Borders
  static Color get bdr => core_theme.AC.bdr; // 20% white — most borders
  static const bdrStrong = Color(0x55FFFFFF); // 33% white
  static const bdrSubtle = Color(0x1AFFFFFF); // 10% white

  // Semantic — success/error/warning/info
  static Color get ok => core_theme.AC.ok; // emerald
  static Color get okLight => core_theme.AC.ok;
  static Color get okDark => core_theme.AC.ok;

  static Color get err => core_theme.AC.err; // red
  static Color get errLight => core_theme.AC.err;
  static Color get errDark => core_theme.AC.err;

  static Color get warn => core_theme.AC.warn; // amber
  static Color get warnLight => core_theme.AC.warn;
  static Color get warnDark => core_theme.AC.warn;

  static Color get info => core_theme.AC.info; // blue
  static Color get infoLight => core_theme.AC.info;
  static Color get infoDark => core_theme.AC.info;

  // Accents — للـ categories / tags / charts
  static Color get indigo => core_theme.AC.purple;
  static Color get purple => core_theme.AC.purple;
  static const pink = Color(0xFFEC4899);
  static const teal = Color(0xFF14B8A6);

  // Category-specific (مطابق لـ CoA)
  static Color get catAsset => core_theme.AC.ok;
  static Color get catLiability => core_theme.AC.warn;
  static Color get catEquity => core_theme.AC.purple;
  static Color get catRevenue => core_theme.AC.info;
  static Color get catExpense => core_theme.AC.err;

  // ══════════════════════════════════════════════════════════════════
  // 3.2 — Typography Scale
  // ══════════════════════════════════════════════════════════════════

  // العناوين (Display)
  static TextStyle get display => TextStyle(
    color: tp, fontSize: 28, fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );
  static TextStyle get h1 => TextStyle(
    color: tp, fontSize: 22, fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  static TextStyle get h2 => TextStyle(
    color: tp, fontSize: 18, fontWeight: FontWeight.w800,
  );
  static TextStyle get h3 => TextStyle(
    color: tp, fontSize: 15, fontWeight: FontWeight.w700,
  );
  static TextStyle get h4 => TextStyle(
    color: tp, fontSize: 13, fontWeight: FontWeight.w700,
  );

  // النصوص (Body)
  static TextStyle get bodyLg => TextStyle(
    color: tp, fontSize: 14, height: 1.5,
  );
  static TextStyle get body => TextStyle(
    color: tp, fontSize: 13, height: 1.5,
  );
  static TextStyle get bodySm => TextStyle(
    color: ts, fontSize: 12, height: 1.4,
  );
  static TextStyle get bodyXs => TextStyle(
    color: td, fontSize: 11, height: 1.4,
  );

  // Labels (forms / captions)
  static TextStyle get label => TextStyle(
    color: td, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static TextStyle get labelStrong => TextStyle(
    color: tp, fontSize: 12, fontWeight: FontWeight.w700,
  );

  // Numbers — monospace for tables
  static TextStyle get mono => TextStyle(
    color: tp, fontSize: 12, fontFamily: 'monospace',
  );
  static TextStyle get monoBold => TextStyle(
    color: tp, fontSize: 13, fontWeight: FontWeight.w800,
    fontFamily: 'monospace',
  );

  // Tables
  static TextStyle get th => TextStyle(
    color: td, fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // ══════════════════════════════════════════════════════════════════
  // 3.3 — Spacing Scale (4px base)
  // ══════════════════════════════════════════════════════════════════

  static const double s0 = 0;
  static const double s1 = 4;    // micro
  static const double s2 = 8;    // xs
  static const double s3 = 12;   // sm
  static const double s4 = 16;   // md (default)
  static const double s5 = 20;   // lg
  static const double s6 = 24;   // xl
  static const double s8 = 32;   // 2xl
  static const double s10 = 40;  // 3xl
  static const double s12 = 48;  // 4xl
  static const double s16 = 64;  // 5xl

  // Common paddings
  static const EdgeInsets padCard = EdgeInsets.all(s4);
  static const EdgeInsets padCardSm = EdgeInsets.all(s3);
  static const EdgeInsets padDialog = EdgeInsets.all(s5);
  static const EdgeInsets padFieldH = EdgeInsets.symmetric(horizontal: s3, vertical: s2);
  static const EdgeInsets padButton =
      EdgeInsets.symmetric(horizontal: s4, vertical: s3);

  // ══════════════════════════════════════════════════════════════════
  // 3.4 — Radius
  // ══════════════════════════════════════════════════════════════════

  static const double r1 = 4;    // tiny — badges
  static const double r2 = 6;    // small — buttons/inputs
  static const double r3 = 8;    // medium — cards
  static const double r4 = 12;   // large — dialogs
  static const double r5 = 16;   // xl — bottom sheets
  static const double rRound = 999; // pill

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(r2));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(r3));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(rRound));

  // ══════════════════════════════════════════════════════════════════
  // 3.5 — Shadows & Elevation
  // ══════════════════════════════════════════════════════════════════

  static const List<BoxShadow> elev1 = [
    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> elev2 = [
    BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elev3 = [
    BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  // ══════════════════════════════════════════════════════════════════
  // 3.6 — Icon Sizes
  // ══════════════════════════════════════════════════════════════════

  static const double iconXs = 12;
  static const double iconSm = 14;
  static const double iconMd = 16;    // default in toolbars
  static const double iconLg = 18;    // in cards/sections
  static const double iconXl = 22;    // in headers
  static const double icon2xl = 28;   // emphasized

  // ══════════════════════════════════════════════════════════════════
  // 3.7 — Buttons (reusable builders)
  // ══════════════════════════════════════════════════════════════════

  static ButtonStyle get btnPrimary => FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: core_theme.AC.tp,
        padding: padButton,
        shape: RoundedRectangleBorder(borderRadius: brSm),
      );

  static ButtonStyle get btnSecondary => OutlinedButton.styleFrom(
        foregroundColor: tp,
        side: BorderSide(color: bdr),
        padding: padButton,
        shape: RoundedRectangleBorder(borderRadius: brSm),
      );

  static ButtonStyle get btnDanger => FilledButton.styleFrom(
        backgroundColor: err,
        foregroundColor: Colors.white,
        padding: padButton,
      );

  static ButtonStyle get btnSuccess => FilledButton.styleFrom(
        backgroundColor: ok,
        foregroundColor: Colors.white,
        padding: padButton,
      );

  static ButtonStyle get btnGhost => TextButton.styleFrom(
        foregroundColor: ts,
        padding: padButton,
      );

  // ══════════════════════════════════════════════════════════════════
  // 3.8 — Input decoration
  // ══════════════════════════════════════════════════════════════════

  static InputDecoration inputDec(String label,
      {String? hint, IconData? prefix, String? helper, bool mono = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: AD.label,
      hintText: hint,
      hintStyle: TextStyle(color: td.withValues(alpha: 0.7)),
      helperText: helper,
      helperStyle: AD.bodyXs,
      prefixIcon: prefix != null ? Icon(prefix, color: td, size: iconMd) : null,
      isDense: true,
      filled: true,
      fillColor: navy3,
      contentPadding: padFieldH,
      border: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: BorderSide(color: bdr),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: BorderSide(color: bdr),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: BorderSide(color: gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: BorderSide(color: err),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 3.9 — Card decoration
  // ══════════════════════════════════════════════════════════════════

  static BoxDecoration card({Color? color, Color? borderColor, double? radius}) {
    return BoxDecoration(
      color: color ?? navy2,
      borderRadius: BorderRadius.circular(radius ?? r3),
      border: Border.all(color: borderColor ?? bdr),
    );
  }

  static BoxDecoration cardAccent(Color accent, {double alpha = 0.08}) {
    return BoxDecoration(
      color: accent.withValues(alpha: alpha),
      borderRadius: brMd,
      border: Border.all(color: accent.withValues(alpha: 0.3)),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 3.10 — Status badges/chips
  // ══════════════════════════════════════════════════════════════════

  static Widget badge(String text, Color color,
      {double size = 10, bool bold = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(r1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  static Widget chip(String text,
      {bool selected = false, VoidCallback? onTap, Color? color}) {
    final c = color ?? gold;
    return InkWell(
      onTap: onTap,
      borderRadius: brPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : navy3,
          borderRadius: brPill,
          border: Border.all(
            color: selected ? c : bdr,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? core_theme.AC.tp : ts,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// KPI card موحّد — يُستخدم في كل الشاشات (dashboard + reports + lists)
  static Widget kpi(String label, String value, Color color,
      {IconData? icon, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(s3),
      decoration: cardAccent(color),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(s2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: brSm,
            ),
            child: Icon(icon, color: color, size: iconLg),
          ),
          const SizedBox(width: s3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: label_.copyWith(color: td)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // Helper — كان متعارضاً مع label constant فاستخدمنا _label
  static TextStyle get label_ => label;

  /// Category color helper
  static Color categoryColor(String? category) {
    switch (category) {
      case 'asset':
        return catAsset;
      case 'liability':
        return catLiability;
      case 'equity':
        return catEquity;
      case 'revenue':
        return catRevenue;
      case 'expense':
        return catExpense;
    }
    return td;
  }

  /// Status color helper
  static Color statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'posted':
      case 'confirmed':
      case 'paid':
      case 'fully_received':
        return ok;
      case 'draft':
      case 'submitted':
      case 'partially_received':
      case 'partially_paid':
        return warn;
      case 'approved':
      case 'issued':
        return info;
      case 'cancelled':
      case 'reversed':
      case 'rejected':
        return err;
      case 'closed':
      case 'archived':
      case 'discontinued':
        return td;
    }
    return td;
  }
}
