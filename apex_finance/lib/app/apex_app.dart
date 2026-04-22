/// APEX Platform — Root Application Widget
/// ═══════════════════════════════════════════════════════════════
/// Extracted from main.dart as part of the Sprint 1 monolith refactor.
/// main.dart should never grow back — put new classes in their own
/// feature folder (`lib/features/<feature>/...`) and import them here
/// if they are app-level (theme, routing, locale, etc.).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/apex_command_palette.dart';
import '../core/apex_commands_registry.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

/// Odoo-style keyboard shortcuts: Alt+1..9 jump directly to a module group.
/// Kept in one place so the list of anchors stays in sync with the sidebar.
final Map<int, String> _altModuleShortcuts = {
  1: '/home',
  2: '/compliance/executive-dashboard',
  3: '/compliance/journal-entries',
  4: '/compliance/zatca-invoice',
  5: '/compliance/vat-return',
  6: '/compliance/bank-rec',
  7: '/copilot',
  8: '/knowledge',
  9: '/whats-new',
};

/// Root widget. Wires theme, locale, RTL direction, and the GoRouter.
class ApexApp extends ConsumerWidget {
  const ApexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isAr = settings.language == 'ar';

    // Apply the selected theme globally (palette + light/dark variant).
    AC.setTheme(settings.themeId);
    final isDark = AC.current.isDark;

    final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();
    final textTheme = _buildTextTheme(baseTheme.textTheme);
    final colorScheme = (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: AC.gold, onPrimary: AC.btnFg,
      secondary: AC.goldLight, onSecondary: AC.btnFg,
      surface: AC.navy2, onSurface: AC.tp,
      error: AC.err, onError: Colors.white,
      outline: AC.bdr,
    );
    final theme = _buildTheme(baseTheme, colorScheme, textTheme);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: MaterialApp.router(
        title: 'APEX',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: theme,
        locale: isAr ? const Locale('ar') : const Locale('en'),
        builder: (context, child) {
          // Wrap every route in a global Cmd+K / Ctrl+K handler so the command
          // palette is reachable from anywhere in the app, plus Alt+1..9 for
          // one-keystroke navigation between the main module groups.
          final digitKeys = <LogicalKeyboardKey>[
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
            LogicalKeyboardKey.digit3,
            LogicalKeyboardKey.digit4,
            LogicalKeyboardKey.digit5,
            LogicalKeyboardKey.digit6,
            LogicalKeyboardKey.digit7,
            LogicalKeyboardKey.digit8,
            LogicalKeyboardKey.digit9,
          ];
          final bindings = <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                () => _openPalette(context),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                () => _openPalette(context),
          };
          for (var i = 0; i < digitKeys.length; i++) {
            final n = i + 1;
            final target = _altModuleShortcuts[n];
            if (target == null) continue;
            bindings[SingleActivator(digitKeys[i], alt: true)] =
                () => GoRouter.of(context).go(target);
          }
          return CallbackShortcuts(
            bindings: bindings,
            child: Focus(autofocus: true, child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }

  void _openPalette(BuildContext context) {
    showApexCommandPalette(
      context,
      commands: buildAppCommands(context),
    );
  }
}

// ── Private theme builders ─────────────────────────────────────────

TextTheme _buildTextTheme(TextTheme base) {
  return GoogleFonts.tajawalTextTheme(base).copyWith(
    displayLarge: GoogleFonts.tajawal(fontSize: 34, fontWeight: FontWeight.w800, color: AC.tp, letterSpacing: -0.5),
    displayMedium: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w700, color: AC.tp),
    displaySmall: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w700, color: AC.tp),
    headlineLarge: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w700, color: AC.tp),
    headlineMedium: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w600, color: AC.tp),
    headlineSmall: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w600, color: AC.tp),
    titleLarge: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w600, color: AC.tp),
    titleMedium: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500, color: AC.tp),
    titleSmall: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500, color: AC.ts),
    bodyLarge: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w400, color: AC.tp, height: 1.6),
    bodyMedium: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w400, color: AC.tp, height: 1.5),
    bodySmall: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w400, color: AC.ts, height: 1.4),
    labelLarge: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: AC.tp),
    labelMedium: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w500, color: AC.ts),
    labelSmall: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w400, color: AC.td),
  );
}

ThemeData _buildTheme(ThemeData base, ColorScheme colorScheme, TextTheme textTheme) {
  return base.copyWith(
    colorScheme: colorScheme,
    splashFactory: InkSparkle.splashFactory,
    splashColor: AC.gold.withValues(alpha: 0.10),
    highlightColor: AC.gold.withValues(alpha: 0.05),
    hoverColor: AC.gold.withValues(alpha: 0.04),
    focusColor: AC.gold.withValues(alpha: 0.08),
    scaffoldBackgroundColor: AC.navy,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AC.navy2, elevation: 0, scrolledUnderElevation: 2, centerTitle: true,
      foregroundColor: AC.tp, iconTheme: IconThemeData(color: AC.gold),
      surfaceTintColor: Colors.transparent,
      shadowColor: AC.bdr.withValues(alpha: 0.3),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return AC.gold.withValues(alpha: 0.4);
        if (s.contains(WidgetState.pressed)) return AC.goldLight;
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.88);
        return AC.gold;
      }),
      foregroundColor: WidgetStateProperty.all(AC.btnFg),
      elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? 4 : 0),
      shadowColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.3)),
      overlayColor: WidgetStateProperty.all(AC.goldLight.withValues(alpha: 0.2)),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      textStyle: WidgetStateProperty.all(GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600)),
      animationDuration: const Duration(milliseconds: 200),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return AC.gold;
        if (s.contains(WidgetState.hovered)) return AC.goldLight;
        return AC.gold;
      }),
      side: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return BorderSide(color: AC.gold.withValues(alpha: 0.8), width: 1.5);
        if (s.contains(WidgetState.hovered)) return BorderSide(color: AC.gold.withValues(alpha: 0.7), width: 1.5);
        return BorderSide(color: AC.gold.withValues(alpha: 0.35));
      }),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return AC.gold.withValues(alpha: 0.10);
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.06);
        return Colors.transparent;
      }),
      elevation: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return 0;
        if (s.contains(WidgetState.hovered)) return 3;
        return 0;
      }),
      shadowColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.25)),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.1)),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      textStyle: WidgetStateProperty.all(GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600)),
      animationDuration: const Duration(milliseconds: 200),
    )),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.hovered)) return AC.goldLight;
        return AC.gold;
      }),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.08)),
      textStyle: WidgetStateProperty.all(GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500)),
      animationDuration: const Duration(milliseconds: 150),
    )),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(
      iconColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return AC.gold;
        if (s.contains(WidgetState.hovered)) return AC.goldLight;
        return AC.ts;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return AC.gold.withValues(alpha: 0.15);
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.08);
        return Colors.transparent;
      }),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.12)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      animationDuration: const Duration(milliseconds: 180),
    )),
    iconTheme: IconThemeData(color: AC.ts, size: 20),
    primaryIconTheme: IconThemeData(color: AC.gold, size: 20),
    cardTheme: CardThemeData(
      color: AC.navy2, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      shadowColor: AC.bdr.withValues(alpha: 0.2),
    ),
    dividerColor: AC.bdr,
    dividerTheme: DividerThemeData(color: AC.bdr, thickness: 0.8, space: 20),
    dialogTheme: DialogThemeData(
      backgroundColor: AC.navy2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      shadowColor: Colors.black26,
      titleTextStyle: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700, color: AC.tp),
      contentTextStyle: GoogleFonts.tajawal(fontSize: 14, color: AC.ts),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AC.navy2, elevation: 8, shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.tajawal(fontSize: 13, color: AC.tp),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AC.navy2,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AC.gold.withValues(alpha: 0.3)),
      ),
      behavior: SnackBarBehavior.floating,
      contentTextStyle: GoogleFonts.tajawal(
        fontSize: 13,
        color: AC.tp,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: AC.gold,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AC.navy3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AC.bdr),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AC.navy2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AC.bdr),
        )),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AC.gold.withValues(alpha: 0.15);
          return AC.navy3;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AC.gold;
          return AC.ts;
        }),
        side: WidgetStateProperty.all(BorderSide(color: AC.bdr)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AC.navy3,
      labelStyle: TextStyle(color: AC.ts, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: AC.td),
      helperStyle: TextStyle(color: AC.td, fontSize: 11),
      errorStyle: TextStyle(color: AC.err, fontSize: 11, fontWeight: FontWeight.w600),
      prefixIconColor: AC.ts,
      suffixIconColor: AC.ts,
      iconColor: AC.ts,
      floatingLabelStyle: TextStyle(color: AC.gold, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AC.bdr),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AC.bdr),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AC.gold, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AC.bdr.withValues(alpha: 0.3)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AC.err, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AC.err, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AC.navy3,
      labelStyle: TextStyle(color: AC.tp, fontSize: 12),
      side: BorderSide(color: AC.bdr),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selectedColor: AC.gold.withValues(alpha: 0.15),
      secondarySelectedColor: AC.goldLight.withValues(alpha: 0.12),
      checkmarkColor: AC.gold,
      deleteIconColor: AC.err,
      selectedShadowColor: AC.gold.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AC.gold, unselectedLabelColor: AC.ts, indicatorColor: AC.gold,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w400),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.08)),
      splashFactory: InkSparkle.splashFactory,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AC.navy4, borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
      textStyle: GoogleFonts.tajawal(fontSize: 12, color: AC.tp),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected) && s.contains(WidgetState.hovered)) return AC.goldLight;
        if (s.contains(WidgetState.selected)) return AC.gold;
        if (s.contains(WidgetState.hovered)) return AC.tp.withValues(alpha: 0.7);
        return AC.ts;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return AC.gold.withValues(alpha: 0.35);
        return AC.navy4;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.3);
        return Colors.transparent;
      }),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.1)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected) && s.contains(WidgetState.hovered)) return AC.goldLight;
        if (s.contains(WidgetState.selected)) return AC.gold;
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.08);
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AC.btnFg),
      side: BorderSide(color: AC.ts, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.1)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected) && s.contains(WidgetState.hovered)) return AC.goldLight;
        if (s.contains(WidgetState.selected)) return AC.gold;
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.6);
        return AC.ts;
      }),
      overlayColor: WidgetStateProperty.all(AC.gold.withValues(alpha: 0.1)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: AC.tp, iconColor: AC.gold,
      titleTextStyle: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500, color: AC.tp),
      subtitleTextStyle: GoogleFonts.tajawal(fontSize: 12, color: AC.ts),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedTileColor: AC.gold.withValues(alpha: 0.06),
      selectedColor: AC.gold,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AC.navy3),
      dataRowColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? AC.navy4 : AC.navy2),
      headingTextStyle: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: AC.gold),
      dataTextStyle: GoogleFonts.tajawal(fontSize: 12, color: AC.tp),
      dividerThickness: 0.5,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.dragged)) return AC.gold.withValues(alpha: 0.6);
        if (s.contains(WidgetState.hovered)) return AC.gold.withValues(alpha: 0.45);
        return AC.gold.withValues(alpha: 0.18);
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.hovered)) return AC.navy3.withValues(alpha: 0.5);
        return Colors.transparent;
      }),
      radius: const Radius.circular(10),
      thickness: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? 8.0 : 4.0),
      thumbVisibility: WidgetStateProperty.all(false),
      interactive: true,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AC.gold, linearTrackColor: AC.navy3),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AC.gold, foregroundColor: AC.btnFg,
      elevation: 4, highlightElevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      splashColor: AC.goldLight.withValues(alpha: 0.3),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AC.navy2, elevation: 12,
      shadowColor: Colors.black38,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      dragHandleColor: AC.gold.withValues(alpha: 0.4),
      dragHandleSize: const Size(40, 4),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AC.gold,
      selectionColor: AC.gold.withValues(alpha: 0.25),
      selectionHandleColor: AC.gold,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: AC.err,
      textColor: Colors.white,
      textStyle: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 5),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: AC.navy2,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(20))),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AC.navy2,
      selectedIconTheme: IconThemeData(color: AC.gold, size: 24),
      unselectedIconTheme: IconThemeData(color: AC.ts, size: 22),
      indicatorColor: AC.gold.withValues(alpha: 0.12),
    ),
  );
}
