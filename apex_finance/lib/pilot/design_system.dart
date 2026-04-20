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

/// APEX Design tokens
class AD {
  AD._();

  // ══════════════════════════════════════════════════════════════════
  // 3.1 — Color Palette (Brand + Semantic)
  // ══════════════════════════════════════════════════════════════════

  // Brand — ذهبي فاخر + كحلي عميق (هوية APEX الأساسية)
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFE5C459);
  static const goldDark = Color(0xFFA88A2C);

  // Navy scale — 5 مستويات من الأغمق للأفتح
  static const navy = Color(0xFF0A1628); // background deepest
  static const navy2 = Color(0xFF132339); // surfaces
  static const navy3 = Color(0xFF1D3150); // elevated surfaces
  static const navy4 = Color(0xFF2A3E5E); // borders prominent
  static const navy5 = Color(0xFF3A4E6E); // dividers

  // Text scale — 4 مستويات (primary / secondary / tertiary / disabled)
  static const tp = Color(0xFFFFFFFF); // primary
  static const ts = Color(0xFFBCC5D3); // secondary
  static const td = Color(0xFF6B7A90); // tertiary
  static const tq = Color(0xFF475266); // quaternary (disabled)

  // Borders
  static const bdr = Color(0x33FFFFFF); // 20% white — most borders
  static const bdrStrong = Color(0x55FFFFFF); // 33% white
  static const bdrSubtle = Color(0x1AFFFFFF); // 10% white

  // Semantic — success/error/warning/info
  static const ok = Color(0xFF10B981); // emerald
  static const okLight = Color(0xFF34D399);
  static const okDark = Color(0xFF059669);

  static const err = Color(0xFFEF4444); // red
  static const errLight = Color(0xFFF87171);
  static const errDark = Color(0xFFDC2626);

  static const warn = Color(0xFFF59E0B); // amber
  static const warnLight = Color(0xFFFBBF24);
  static const warnDark = Color(0xFFD97706);

  static const info = Color(0xFF3B82F6); // blue
  static const infoLight = Color(0xFF60A5FA);
  static const infoDark = Color(0xFF2563EB);

  // Accents — للـ categories / tags / charts
  static const indigo = Color(0xFF6366F1);
  static const purple = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const teal = Color(0xFF14B8A6);

  // Category-specific (مطابق لـ CoA)
  static const catAsset = Color(0xFF10B981);
  static const catLiability = Color(0xFFF59E0B);
  static const catEquity = Color(0xFF8B5CF6);
  static const catRevenue = Color(0xFF3B82F6);
  static const catExpense = Color(0xFFEF4444);

  // ══════════════════════════════════════════════════════════════════
  // 3.2 — Typography Scale
  // ══════════════════════════════════════════════════════════════════

  // العناوين (Display)
  static const TextStyle display = TextStyle(
    color: tp, fontSize: 28, fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );
  static const TextStyle h1 = TextStyle(
    color: tp, fontSize: 22, fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  static const TextStyle h2 = TextStyle(
    color: tp, fontSize: 18, fontWeight: FontWeight.w800,
  );
  static const TextStyle h3 = TextStyle(
    color: tp, fontSize: 15, fontWeight: FontWeight.w700,
  );
  static const TextStyle h4 = TextStyle(
    color: tp, fontSize: 13, fontWeight: FontWeight.w700,
  );

  // النصوص (Body)
  static const TextStyle bodyLg = TextStyle(
    color: tp, fontSize: 14, height: 1.5,
  );
  static const TextStyle body = TextStyle(
    color: tp, fontSize: 13, height: 1.5,
  );
  static const TextStyle bodySm = TextStyle(
    color: ts, fontSize: 12, height: 1.4,
  );
  static const TextStyle bodyXs = TextStyle(
    color: td, fontSize: 11, height: 1.4,
  );

  // Labels (forms / captions)
  static const TextStyle label = TextStyle(
    color: td, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static const TextStyle labelStrong = TextStyle(
    color: tp, fontSize: 12, fontWeight: FontWeight.w700,
  );

  // Numbers — monospace for tables
  static const TextStyle mono = TextStyle(
    color: tp, fontSize: 12, fontFamily: 'monospace',
  );
  static const TextStyle monoBold = TextStyle(
    color: tp, fontSize: 13, fontWeight: FontWeight.w800,
    fontFamily: 'monospace',
  );

  // Tables
  static const TextStyle th = TextStyle(
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
        foregroundColor: Colors.black,
        padding: padButton,
        shape: RoundedRectangleBorder(borderRadius: brSm),
      );

  static ButtonStyle get btnSecondary => OutlinedButton.styleFrom(
        foregroundColor: tp,
        side: const BorderSide(color: bdr),
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
        borderSide: const BorderSide(color: bdr),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: const BorderSide(color: bdr),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: BorderSide(color: gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: brSm,
        borderSide: const BorderSide(color: err),
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
            color: selected ? Colors.black : ts,
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
  static const TextStyle label_ = label;

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
