import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme apexTextTheme(TextTheme base) => GoogleFonts.tajawalTextTheme(base);

/// Theme preset definition
class ApexTheme {
  final String id;
  final String nameAr;
  final String nameEn;
  final Color primary;        // main accent color (gold equivalent)
  final Color primaryLight;   // lighter variant of primary
  final Color bg1;            // main background
  final Color bg2;            // card / app bar background
  final Color bg3;            // input / secondary bg
  final Color bg4;            // hover / tertiary bg
  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;        // muted / hint text
  final Color border;
  final bool isDark;
  final Color preview;        // picker circle
  // ── Status / Accent ──
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color purple;
  // ── Button ──
  final Color btnFg;          // button foreground (text on primary)
  // ── Icon Accent ──
  final Color? _iconAccent;   // icon backgrounds (defaults to primary)
  Color get iconAccent => _iconAccent ?? primary;
  // ── Text Accent ──
  final Color? _textAccent;   // text highlight color (defaults to primary)
  Color get textAccent => _textAccent ?? primary;

  const ApexTheme({
    required this.id, required this.nameAr, required this.nameEn,
    required this.primary, required this.primaryLight,
    required this.bg1, required this.bg2, required this.bg3, required this.bg4,
    required this.textPrimary, required this.textSecondary, required this.textDim,
    required this.border, required this.isDark, required this.preview,
    required this.success, required this.error, required this.warning,
    required this.info, required this.purple, required this.btnFg,
    Color? iconAccent,
    Color? textAccent,
  }) : _iconAccent = iconAccent, _textAccent = textAccent;
}

/// Theme family — groups a light + dark pair under one name
class ApexThemeFamily {
  final String id;
  final String nameAr;
  final String nameEn;
  final Color preview;
  const ApexThemeFamily({required this.id, required this.nameAr, required this.nameEn, required this.preview});
}

const List<ApexThemeFamily> apexThemeFamilies = [
  ApexThemeFamily(id: 'original',  nameAr: 'كلاسيك كحلي',    nameEn: 'Classic Navy',    preview: Color(0xFF1E3A5F)),
  ApexThemeFamily(id: 'apex',      nameAr: 'كلاسيك بنفسجي',  nameEn: 'Classic Plum',    preview: Color(0xFF714B67)),
  ApexThemeFamily(id: 'classic',   nameAr: 'كلاسيك ذهبي',    nameEn: 'Classic Gold',    preview: Color(0xFFAE8820)),
  ApexThemeFamily(id: 'blue',      nameAr: 'كلاسيك أزرق',    nameEn: 'Classic Blue',    preview: Color(0xFF1878A8)),
  ApexThemeFamily(id: 'green',     nameAr: 'كلاسيك أخضر',    nameEn: 'Classic Green',   preview: Color(0xFF20744C)),
  ApexThemeFamily(id: 'red',       nameAr: 'كلاسيك أحمر',    nameEn: 'Classic Red',     preview: Color(0xFFA83034)),
];

/// Helper: get family id from theme id
String themeFamilyOf(String themeId) => themeId.replaceAll(RegExp(r'_(light|dark)$'), '');

/// Helper: build theme id from family + dark mode
String themeIdFor(String familyId, bool isDark) => '${familyId}_${isDark ? 'dark' : 'light'}';

/// ══════════════════════════════════════════════════════════════════
/// All available themes — 4 classic families × 2 modes (light + dark)
///
/// 30 waves of color refinement:
///  W1–W10   Foundation (layers, temperature, harmony, luminosity, borders,
///           purple, warning, info, contrast, pair cohesion)
///  W11–W20  Refinement (richness, micro-tint, gradation, dark depth,
///           saturation parity, spread, border finesse, cross-parity,
///           dark legibility, luxury polish)
///  W21–W30  Mastery (micro-contrast, chromatic borders, dark glow,
///           status temperature, error distinctiveness, text hue-hint,
///           bg purity, dark elevation, hover primaryLight, final balance)
/// ══════════════════════════════════════════════════════════════════
/// ══════════════════════════════════════════════════════════════════
/// Design philosophy:
///  • Backgrounds are near-neutral with whisper-level tinting.
///  • Every theme carries 3 distinct accent families for visual depth.
///  • Dark variants share the same temperature as their light sibling.
///  • Apex AI is the signature identity — cyan/violet fusion, futuristic.
/// ══════════════════════════════════════════════════════════════════
const List<ApexTheme> apexThemes = [

  // ╔═══════════════════════════════════════════════════════════════╗
  // ║  ★  CLASSIC FUSION — The founding theme, refined              ║
  // ║  Deep navy backgrounds · Warm gold primary · Cyan accent      ║
  // ╚═══════════════════════════════════════════════════════════════╝

  ApexTheme(  // ── Classic Fusion Light ──
    id: 'original_light', nameAr: 'كلاسيك كحلي', nameEn: 'Classic Navy',
    primary: Color(0xFF1E3A5F),       // navy — base structure
    primaryLight: Color(0xFF2A4D78),
    bg1: Color(0xFFF4F6F9),   // cool blue-white
    bg2: Color(0xFFFAFBFD),   // card — icy white
    bg3: Color(0xFFE8ECF2),   // steel mist input
    bg4: Color(0xFFDAE0EA),   // cool hover
    textPrimary: Color(0xFF1A2030), textSecondary: Color(0xFF4A5468), textDim: Color(0xFF7A8498),
    border: Color(0x1C1E3A5F), isDark: false, preview: Color(0xFF1E3A5F),
    success: Color(0xFF2ECC8A),
    error: Color(0xFFE05050),
    warning: Color(0xFFF0A500),
    info: Color(0xFF00C2E0),
    purple: Color(0xFF1E3A5F),
    btnFg: Color(0xFFFFFFFF),
    textAccent: Color(0xFFC9A84C),  // gold for text only
  ),

  ApexTheme(  // ── Classic Fusion Dark ──
    id: 'original_dark', nameAr: 'كلاسيك كحلي', nameEn: 'Classic Navy',
    primary: Color(0xFFD4A030),       // warm honey gold — cleaner
    primaryLight: Color(0xFFE8BA4A),
    bg1: Color(0xFF050D1A),   // original deep navy
    bg2: Color(0xFF080F1F),   // original card navy
    bg3: Color(0xFF0D1829),   // original input navy
    bg4: Color(0xFF0F2040),   // original hover
    textPrimary: Color(0xFFF0EDE6), textSecondary: Color(0xFF8A8880), textDim: Color(0xFF666058),
    border: Color(0x26D4A030), isDark: true, preview: Color(0xFFD4A030),
    success: Color(0xFF2ECC8A),
    error: Color(0xFFE05050),
    warning: Color(0xFFF0A500),
    info: Color(0xFF00C2E0),     // original cyan
    purple: Color(0xFF8B5CF6),
    btnFg: Color(0xFF050D1A),
  ),

  // ╔═══════════════════════════════════════════════════════════════╗
  // ║  ★  ODOO VIOLET — Inspired by Odoo's brand identity          ║
  // ║  Warm plum/mauve primary · Rose accent · Sage green contrast  ║
  // ║  Light: soft blush bg · Dark: deep plum bg                    ║
  // ╚═══════════════════════════════════════════════════════════════╝

  ApexTheme(  // ── Odoo Violet Light ──
    id: 'apex_light', nameAr: 'كلاسيك بنفسجي', nameEn: 'Classic Plum',
    primary: Color(0xFF714B67),       // Odoo primary plum
    primaryLight: Color(0xFF8C6484),
    bg1: Color(0xFFF6F2F5),   // soft blush-white
    bg2: Color(0xFFFCFAFB),   // card — near-white rose
    bg3: Color(0xFFEDE7EB),   // input — mauve mist
    bg4: Color(0xFFE0D8DD),   // hover — dusty rose
    textPrimary: Color(0xFF2D1F2A), textSecondary: Color(0xFF5C4A58), textDim: Color(0xFF8A7A86),
    border: Color(0x1C714B67), isDark: false, preview: Color(0xFF714B67),
    success: Color(0xFF21A366),
    error: Color(0xFFD93E4C),
    warning: Color(0xFFE8920C),
    info: Color(0xFF0E7C93),
    purple: Color(0xFFA83279),
    btnFg: Color(0xFFFFFFFF),
  ),

  ApexTheme(  // ── Odoo Violet Dark ──
    id: 'apex_dark', nameAr: 'كلاسيك بنفسجي', nameEn: 'Classic Plum',
    primary: Color(0xFFA87C9E),       // luminous mauve
    primaryLight: Color(0xFFC4A0BA),  // bright mauve
    bg1: Color(0xFF120C14),   // deep plum-black
    bg2: Color(0xFF1A1220),   // card — dark plum
    bg3: Color(0xFF261A2C),   // input — deep mauve
    bg4: Color(0xFF322438),   // hover — plum
    textPrimary: Color(0xFFF2ECF0), textSecondary: Color(0xFFB0A0AC), textDim: Color(0xFF786878),
    border: Color(0x30A87C9E), isDark: true, preview: Color(0xFFA87C9E),
    success: Color(0xFF4ADE80),   // mint
    error: Color(0xFFFB7185),     // rose
    warning: Color(0xFFFBBF24),   // golden
    info: Color(0xFF22D3EE),      // cyan
    purple: Color(0xFFF472B6),    // pink
    btnFg: Color(0xFF120C14),
  ),

  // ╔═══════════════════════════════════════════════════════════════╗
  // ║  1. CLASSIC GOLD                                             ║
  // ║  Warm amber primary · Teal contrast · Berry accent            ║
  // ║  Light: warm ivory · Dark: espresso warmth                   ║
  // ╚═══════════════════════════════════════════════════════════════╝

  ApexTheme(  // ── Gold Light ──
    id: 'classic_light', nameAr: 'كلاسيك ذهبي', nameEn: 'Classic Gold',
    primary: Color(0xFFB8860B), primaryLight: Color(0xFFD4A830),
    bg1: Color(0xFFF8F6F0),   // warm ivory — whisper warmth
    bg2: Color(0xFFFDFCF8),   // card — warm white
    bg3: Color(0xFFEBE6DA),   // input — warm pearl
    bg4: Color(0xFFE0DACC),   // hover
    textPrimary: Color(0xFF1C1A12), textSecondary: Color(0xFF58523E), textDim: Color(0xFF8E8670),
    border: Color(0x1C907028), isDark: false, preview: Color(0xFFAE8820),
    success: Color(0xFF16A34A), error: Color(0xFFBE2E2E), warning: Color(0xFFC48010),
    info: Color(0xFF0E7490),    // teal — strong contrast to gold
    purple: Color(0xFF7E22CE),  // berry violet
    btnFg: Color(0xFFFFFFFF),
  ),

  ApexTheme(  // ── Gold Dark ──
    id: 'classic_dark', nameAr: 'كلاسيك ذهبي', nameEn: 'Classic Gold',
    primary: Color(0xFFDAA520), primaryLight: Color(0xFFF0C850),
    bg1: Color(0xFF0C0A06),   // warm black — amber undertone
    bg2: Color(0xFF16130C),   // card — warm charcoal
    bg3: Color(0xFF201C12),   // input — espresso
    bg4: Color(0xFF2A2418),   // hover — warm brown
    textPrimary: Color(0xFFF0EADA), textSecondary: Color(0xFFACA28A), textDim: Color(0xFF7A7058),
    border: Color(0x28D4AC30), isDark: true, preview: Color(0xFFD4AC30),
    success: Color(0xFF4ADE80), error: Color(0xFFFF6E6A), warning: Color(0xFFFFCC3C),
    info: Color(0xFF22D3EE),    // bright cyan glow
    purple: Color(0xFFC084FC),  // bright lavender
    btnFg: Color(0xFF0C0A06),
  ),

  // ╔═══════════════════════════════════════════════════════════════╗
  // ║  2. CLASSIC BLUE                                             ║
  // ║  Ocean blue primary · Amber warmth · Violet depth             ║
  // ║  Light: cool pearl · Dark: deep ocean                        ║
  // ╚═══════════════════════════════════════════════════════════════╝

  ApexTheme(  // ── Blue Light ──
    id: 'blue_light', nameAr: 'كلاسيك أزرق', nameEn: 'Classic Blue',
    primary: Color(0xFF0369A1), primaryLight: Color(0xFF0284C7),
    bg1: Color(0xFFF1F3F6),   // cool pearl — neutral
    bg2: Color(0xFFF9FAFE),   // card — snow
    bg3: Color(0xFFE2E6EC),   // input
    bg4: Color(0xFFD4D8E2),   // hover
    textPrimary: Color(0xFF101820), textSecondary: Color(0xFF3E4E60), textDim: Color(0xFF708494),
    border: Color(0x1C1878A8), isDark: false, preview: Color(0xFF1878A8),
    success: Color(0xFF15803D), error: Color(0xFFC83434),
    warning: Color(0xFFD89420),  // amber — warm complement
    info: Color(0xFF0891B2),
    purple: Color(0xFF7C3AED),   // vivid violet — contrast
    btnFg: Color(0xFFFFFFFF),
  ),

  ApexTheme(  // ── Blue Dark ──
    id: 'blue_dark', nameAr: 'كلاسيك أزرق', nameEn: 'Classic Blue',
    primary: Color(0xFF38BDF8), primaryLight: Color(0xFF7DD3FC),
    bg1: Color(0xFF060A12),   // deep ocean
    bg2: Color(0xFF0C121C),   // card — midnight
    bg3: Color(0xFF161E2C),   // input
    bg4: Color(0xFF1E2838),   // hover
    textPrimary: Color(0xFFE4EAF2), textSecondary: Color(0xFF8898AC), textDim: Color(0xFF5C6E80),
    border: Color(0x2850A0E0), isDark: true, preview: Color(0xFF50A0E0),
    success: Color(0xFF4ADE80), error: Color(0xFFFF7474),
    warning: Color(0xFFFFC444),  // golden glow — warm counterpart
    info: Color(0xFF67E8F9),
    purple: Color(0xFFA78BFA),   // lavender
    btnFg: Color(0xFF060A12),
  ),

  // ╔═══════════════════════════════════════════════════════════════╗
  // ║  3. CLASSIC GREEN                                            ║
  // ║  Forest emerald primary · Amber warmth · Indigo depth         ║
  // ║  Light: sage frost · Dark: deep forest                       ║
  // ╚═══════════════════════════════════════════════════════════════╝

  ApexTheme(  // ── Green Light ──
    id: 'green_light', nameAr: 'كلاسيك أخضر', nameEn: 'Classic Green',
    primary: Color(0xFF15803D), primaryLight: Color(0xFF16A34A),
    bg1: Color(0xFFF1F4F2),   // sage frost — neutral
    bg2: Color(0xFFF9FBF9),   // card — snow
    bg3: Color(0xFFE0E8E2),   // input
    bg4: Color(0xFFD0DAD2),   // hover
    textPrimary: Color(0xFF101812), textSecondary: Color(0xFF3C4E42), textDim: Color(0xFF6C7E70),
    border: Color(0x1C1E7848), isDark: false, preview: Color(0xFF1E7848),
    success: Color(0xFF1C9048), error: Color(0xFFC03434),
    warning: Color(0xFFCC9010),  // amber
    info: Color(0xFF0E7490),     // teal contrast
    purple: Color(0xFF7E22CE),   // indigo
    btnFg: Color(0xFFFFFFFF),
  ),

  ApexTheme(  // ── Green Dark ──
    id: 'green_dark', nameAr: 'كلاسيك أخضر', nameEn: 'Classic Green',
    primary: Color(0xFF4ADE80), primaryLight: Color(0xFF86EFAC),
    bg1: Color(0xFF060C0A),   // deep forest
    bg2: Color(0xFF0C1612),   // card
    bg3: Color(0xFF16221C),   // input
    bg4: Color(0xFF1E2E26),   // hover
    textPrimary: Color(0xFFE2EEE6), textSecondary: Color(0xFF88A294), textDim: Color(0xFF5C7468),
    border: Color(0x2840C080), isDark: true, preview: Color(0xFF40C080),
    success: Color(0xFF50E89C), error: Color(0xFFFF7474),
    warning: Color(0xFFFFC840),  // golden glow
    info: Color(0xFF22D3EE),     // bright cyan
    purple: Color(0xFFC084FC),   // violet
    btnFg: Color(0xFF060C0A),
  ),

  // ╔═══════════════════════════════════════════════════════════════╗
  // ║  4. CLASSIC RED                                              ║
  // ║  Wine crimson primary · Teal coolness · Gold warmth           ║
  // ║  Light: warm pearl · Dark: deep burgundy                     ║
  // ╚═══════════════════════════════════════════════════════════════╝

  ApexTheme(  // ── Red Light ──
    id: 'red_light', nameAr: 'كلاسيك أحمر', nameEn: 'Classic Red',
    primary: Color(0xFFB91C1C), primaryLight: Color(0xFFDC2626),
    bg1: Color(0xFFF5F2F2),   // warm pearl — subtle blush
    bg2: Color(0xFFFCF9F9),   // card — warm white
    bg3: Color(0xFFEADEDE),   // input
    bg4: Color(0xFFDED0D0),   // hover
    textPrimary: Color(0xFF1A1214), textSecondary: Color(0xFF524244), textDim: Color(0xFF8A6E72),
    border: Color(0x1CA83438), isDark: false, preview: Color(0xFFA83438),
    success: Color(0xFF168048),
    error: Color(0xFFCC2C2C),
    warning: Color(0xFFCC8C14),  // warm gold
    info: Color(0xFF0E7490),     // teal — cool contrast
    purple: Color(0xFF7E22CE),   // violet
    btnFg: Color(0xFFFFFFFF),
  ),

  ApexTheme(  // ── Red Dark ──
    id: 'red_dark', nameAr: 'كلاسيك أحمر', nameEn: 'Classic Red',
    primary: Color(0xFFFB7185), primaryLight: Color(0xFFFDA4AF),
    bg1: Color(0xFF0C0808),   // deep burgundy black
    bg2: Color(0xFF160E10),   // card
    bg3: Color(0xFF22161A),   // input
    bg4: Color(0xFF2E1E22),   // hover
    textPrimary: Color(0xFFF0E6E8), textSecondary: Color(0xFFA88E90), textDim: Color(0xFF726060),
    border: Color(0x28DC6064), isDark: true, preview: Color(0xFFDC6064),
    success: Color(0xFF3CD890),
    error: Color(0xFFFF6868),
    warning: Color(0xFFFFC844),  // gold glow
    info: Color(0xFF22D3EE),     // cyan glow
    purple: Color(0xFFC084FC),   // lavender
    btnFg: Color(0xFF0C0808),
  ),
];

/// AC — Apex Colors. Supports multiple theme presets.
class AC {
  static ApexTheme _current = apexThemes.firstWhere((t) => t.id == 'original_light'); // default: classic fusion light

  static void setTheme(String id) {
    _current = apexThemes.firstWhere((t) => t.id == id, orElse: () => apexThemes[0]);
  }

  static void setLight(bool v) {
    if (v && _current.isDark) setTheme('classic_light');
    if (!v && !_current.isDark) setTheme('classic_dark');
  }

  static bool get isLight => !_current.isDark;
  static ApexTheme get current => _current;

  // ── Primary ──
  static Color get gold => _current.primary;
  static Color get goldLight => _current.primaryLight;
  static Color get iconAccent => _current.iconAccent;
  static Color get goldText => _current.textAccent;

  // ── Backgrounds ──
  static Color get navy => _current.bg1;
  static Color get navy2 => _current.bg2;
  static Color get navy3 => _current.bg3;
  static Color get navy4 => _current.bg4;

  // ── Accent ──
  static Color get cyan => _current.info;

  // ── Text ──
  static Color get tp => _current.textPrimary;
  static Color get ts => _current.textSecondary;
  static Color get td => _current.textDim;

  // ── Status ──
  static Color get ok => _current.success;
  static Color get warn => _current.warning;
  static Color get err => _current.error;
  static Color get info => _current.info;
  static Color get purple => _current.purple;

  // ── Button ──
  static Color get btnFg => _current.btnFg;

  // ── Border ──
  static Color get bdr => _current.border;
}

InputDecoration apexInput(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  prefixIcon: icon != null ? Icon(icon, color: AC.goldText, size: 20) : null,
  filled: true, fillColor: AC.navy3,
  labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.goldText)),
);

Widget apexCard(String title, List<Widget> children, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(24),
    border: Border.all(color: AC.bdr.withValues(alpha: 0.06)),
    boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 4))]),
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
