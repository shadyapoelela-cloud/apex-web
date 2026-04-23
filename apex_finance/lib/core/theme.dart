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
  ApexThemeFamily(id: 'red',       nameAr: 'كلاسيك نبيتي',   nameEn: 'Classic Wine',    preview: Color(0xFF722F37)),
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
    textPrimary: Color(0xFFF0EDE6), textSecondary: Color(0xFF9A9890), textDim: Color(0xFF7A7570),
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
    textPrimary: Color(0xFFF2ECF0), textSecondary: Color(0xFFB0A0AC), textDim: Color(0xFF8A7E88),
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
    textPrimary: Color(0xFFF0EADA), textSecondary: Color(0xFFACA28A), textDim: Color(0xFF8A8068),
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
    textPrimary: Color(0xFFE4EAF2), textSecondary: Color(0xFF8898AC), textDim: Color(0xFF728494),
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
    textPrimary: Color(0xFFE2EEE6), textSecondary: Color(0xFF88A294), textDim: Color(0xFF728A7C),
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

  ApexTheme(  // ── Wine / Burgundy Light (نبيتي) ──
    id: 'red_light', nameAr: 'كلاسيك نبيتي', nameEn: 'Classic Wine',
    primary: Color(0xFF722F37),       // deep wine
    primaryLight: Color(0xFF8B3A48),   // slightly brighter wine
    bg1: Color(0xFFF7F2F3),           // pearl with wine hint
    bg2: Color(0xFFFDF9FA),           // card — warm white
    bg3: Color(0xFFEBDFE1),           // input
    bg4: Color(0xFFDED0D4),           // hover
    textPrimary: Color(0xFF1E1012), textSecondary: Color(0xFF5A424A), textDim: Color(0xFF8C6B74),
    border: Color(0x24722F37), isDark: false, preview: Color(0xFF722F37),
    success: Color(0xFF168048),
    error: Color(0xFFA61E2A),
    warning: Color(0xFFB8860B),       // antique gold pairs with wine
    info: Color(0xFF0E7490),
    purple: Color(0xFF7E22CE),
    btnFg: Color(0xFFFFFFFF),
  ),

  ApexTheme(  // ── Wine / Burgundy Dark (نبيتي غامق) ──
    id: 'red_dark', nameAr: 'كلاسيك نبيتي', nameEn: 'Classic Wine',
    primary: Color(0xFFBA5560),        // rosé-wine glow
    primaryLight: Color(0xFFD17A86),
    bg1: Color(0xFF0E0709),            // burgundy-black
    bg2: Color(0xFF1A0F12),            // card
    bg3: Color(0xFF281519),            // input
    bg4: Color(0xFF351C22),            // hover
    textPrimary: Color(0xFFF1E3E5), textSecondary: Color(0xFFAE8E94), textDim: Color(0xFF8A707A),
    border: Color(0x38BA5560), isDark: true, preview: Color(0xFFBA5560),
    success: Color(0xFF3CD890),
    error: Color(0xFFFF6868),
    warning: Color(0xFFE8B84E),
    info: Color(0xFF22D3EE),
    purple: Color(0xFFC084FC),
    btnFg: Color(0xFF0E0709),
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

  // ── Top Bar (medium-dark branded shade) ──
  // الشريط العلوي: درجة أفتح من الخلفية الداكنة مرة واحدة — مثل كحلي فاتح
  // مش داكن قاتم. يعطي احساس "branded header" كـ Microsoft 365 / Fiori Horizon.

  // Find matching DARK theme of same family — base for computing medium shade.
  static ApexTheme get _darkFamily {
    if (_current.isDark) return _current;
    final family = themeFamilyOf(_current.id);
    return apexThemes.firstWhere(
      (t) => t.id == '${family}_dark',
      orElse: () => _current,
    );
  }

  /// Top bar background — "one step lighter than deep dark" of the current palette.
  /// Takes the dark variant's bg4 (its lightest dark tone) and adds a subtle
  /// primary tint (~15%) so the palette personality shows through.
  static Color get topBarBg {
    final dv = _darkFamily;
    // dv.bg4 is the lightest dark bg; mix in primary hint for tint
    return Color.alphaBlend(dv.primary.withValues(alpha: 0.14), dv.bg4);
  }

  /// Slightly deeper variant for hover/active states in the top bar.
  static Color get topBarBgDeep {
    final dv = _darkFamily;
    return Color.alphaBlend(dv.primary.withValues(alpha: 0.08), dv.bg3);
  }

  /// Text color — light, readable on medium-dark bg.
  static Color get topBarFg => const Color(0xFFF1F5F9);  // near-white, theme-neutral

  /// Secondary/dim text in top bar.
  static Color get topBarFgDim => const Color(0xFFCBD5E1);

  /// Accent — brighter primary variant for logo/breadcrumbs/badges.
  /// Always visible on the medium-dark bg regardless of mode.
  static Color get topBarAccent => _darkFamily.primaryLight;

  /// Border/divider — slightly visible, branded.
  static Color get topBarBorder {
    final dv = _darkFamily;
    return Color.alphaBlend(dv.primary.withValues(alpha: 0.25), const Color(0x22FFFFFF));
  }

  /// Hover overlay for icons in top bar.
  static Color get topBarHover => _darkFamily.primary.withValues(alpha: 0.18);

  // ═══════════════════════════════════════════════════════════════════
  // Extended semantic tokens (Rounds 1-10)
  // ═══════════════════════════════════════════════════════════════════

  /// Soft status tints (for badges, backgrounds of status chips)
  static Color get okSoft => _current.success.withValues(alpha: 0.15);
  static Color get warnSoft => _current.warning.withValues(alpha: 0.15);
  static Color get errSoft => _current.error.withValues(alpha: 0.15);
  static Color get infoSoft => _current.info.withValues(alpha: 0.15);
  static Color get purpleSoft => _current.purple.withValues(alpha: 0.15);
  static Color get goldSoft => _current.primary.withValues(alpha: 0.12);

  /// Elevation surfaces (cards that pop on any background)
  static Color get surface => _current.bg2;
  static Color get surfaceElevated => _current.bg3;
  static Color get surfaceHighest => _current.bg4;

  /// Focus ring — visible on both light/dark bg
  static Color get focusRing => _current.primary.withValues(alpha: 0.35);

  /// Divider variants
  static Color get dividerSubtle => _current.border.withValues(alpha: 0.5);
  static Color get dividerStrong => _current.border.withValues(alpha: 1.0);

  /// Overlay (modal backdrops, skeleton, etc.)
  static Color get overlay => Colors.black.withValues(alpha: 0.45);
  static Color get overlaySubtle => Colors.black.withValues(alpha: 0.18);

  /// Brand gradient — primary → primaryLight (for hero areas)
  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [_current.primary, _current.primaryLight],
      );

  /// Text emphasis levels
  static Color get textStrong => _current.textPrimary;
  static Color get textMedium => _current.textSecondary;
  static Color get textWeak => _current.textDim;
  static Color get textOnPrimary => _current.btnFg;

  /// Ripple/splash colors
  static Color get splash => _current.primary.withValues(alpha: 0.10);
  static Color get highlight => _current.primary.withValues(alpha: 0.05);
  static Color get hover => _current.primary.withValues(alpha: 0.08);

  /// Disabled state
  static Color get disabled => _current.textDim.withValues(alpha: 0.4);
  static Color get disabledBg => _current.bg3.withValues(alpha: 0.6);

  /// Best-contrast foreground for any given background color.
  /// Uses WCAG-style luminance to pick dark or light text.
  static Color bestOn(Color bg) {
    final luma = 0.299 * bg.r * 255 + 0.587 * bg.g * 255 + 0.114 * bg.b * 255;
    return luma > 140 ? const Color(0xFF0A1628) : const Color(0xFFFFFFFF);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Interaction state tokens — F-10 (SAP Fiori 3 / Fluent / Material 3)
  // ═══════════════════════════════════════════════════════════════════

  /// Neutral hover overlay — white on dark / black on light, low alpha.
  static Color get stateHover => _current.isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.035);

  /// Neutral pressed overlay — deeper than hover.
  static Color get statePressed => _current.isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.06);

  /// Selected state — primary tint at low alpha (like Fiori 3 selection).
  static Color get stateSelectedBg => _current.primary.withValues(alpha: 0.10);

  /// Selected accent — primary at medium alpha (Linear/Notion style).
  static Color get stateSelectedFg => _current.primary.withValues(alpha: 0.90);

  /// Active indicator bar — used as 3px-wide leading stripe.
  static Color get stateActiveIndicator => _current.primary;

  /// Stronger focus ring for keyboard navigation (WCAG 2.2 compliant).
  static Color get focusRingStrong => _current.primary.withValues(alpha: 0.55);

  // ═══════════════════════════════════════════════════════════════════
  // Sidebar tokens — theme-harmonized across all 12 themes
  // Derived from primary + surfaces so each family has matching accents.
  // Research synthesis: SAP Fiori 3 · Linear · Notion · Fluent 2 · Material 3
  // ═══════════════════════════════════════════════════════════════════

  /// Sidebar base background — one step deeper than card surface,
  /// tinted with a PERCEPTIBLE layer of primary so each theme feels
  /// distinctly different. Boosted after user feedback: "I don't see
  /// the change" on light navy (where primary is too close to bg).
  static Color get sidebarBg => Color.alphaBlend(
        _current.primary.withValues(alpha: _current.isDark ? 0.10 : 0.06),
        _current.bg2,
      );

  /// Elevated sidebar surface (expanded panels, active groups).
  static Color get sidebarBgElevated => Color.alphaBlend(
        _current.primary.withValues(alpha: _current.isDark ? 0.14 : 0.09),
        _current.bg3,
      );

  /// Sidebar header — branded gradient top-strip (Linear / Notion style).
  /// Alpha boosted so the theme personality is clearly visible.
  static LinearGradient get sidebarHeaderGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _current.primary.withValues(alpha: _current.isDark ? 0.22 : 0.18),
          _current.primary.withValues(alpha: _current.isDark ? 0.06 : 0.04),
        ],
      );

  /// Selected item bg — clear primary tint (Fiori 3 / Linear pattern).
  static Color get sidebarItemSelectedBg =>
      _current.primary.withValues(alpha: _current.isDark ? 0.22 : 0.16);

  /// Hover state — soft neutral overlay.
  static Color get sidebarItemHoverBg => _current.isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.05);

  /// 3px leading stripe — marks the active route (SAP Fiori / Linear).
  static Color get sidebarActiveStripe => _current.primary;

  /// Vertical accent strip on the leading edge of the whole sidebar —
  /// makes theme identity unmistakable at a glance.
  static Color get sidebarAccentEdge => _current.primary;

  /// Group header color — primary-tinted but softer than item text.
  static Color get sidebarGroupFg => _current.primary;

  /// Item label color (default).
  static Color get sidebarItemFg => _current.textPrimary;

  /// Item label color (dim).
  static Color get sidebarItemDim => _current.textSecondary;

  /// Border / divider for the sidebar column — bolder so it's visible
  /// even on low-contrast light themes.
  static Color get sidebarBorder =>
      _current.primary.withValues(alpha: _current.isDark ? 0.22 : 0.16);

  /// Scrim for overlay sidebar on narrow screens.
  static Color get sidebarScrim => _current.isDark
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.black.withValues(alpha: 0.35);
}

// ═══════════════════════════════════════════════════════════════════════════
// DS — APEX Design System tokens (Wave F)
//
// Inspired by: SAP Fiori 3 / Microsoft Fluent / Google Material 3 / Linear /
//              Notion / Atlassian Design Tokens / GitHub Primer.
//
// Single source of truth for: spacing, sizing, radii, motion, elevation,
// typography, breakpoints. All magic numbers in the app should reference
// DS.* instead.
// ═══════════════════════════════════════════════════════════════════════════
class DS {
  DS._();

  // ── F-1 Spacing (4px grid — Material 3 / 8pt Apple hybrid) ─────────
  static const double s0 = 0.0;
  static const double s1 = 4.0;    // xs — tight pairings
  static const double s2 = 8.0;    // sm — default inline
  static const double s3 = 12.0;   // md-
  static const double s4 = 16.0;   // md — default container pad
  static const double s5 = 20.0;   // lg-
  static const double s6 = 24.0;   // lg — section pad
  static const double s7 = 32.0;   // xl
  static const double s8 = 48.0;   // 2xl — hero spacing

  // ── F-2 Icon sizes (Fiori 3 tiers) ─────────────────────────────────
  static const double iconXs = 12.0;   // inside badges/dense badges
  static const double iconSm = 14.0;   // compact buttons
  static const double iconMd = 16.0;   // default (topbar, sidebar, chips)
  static const double iconLg = 20.0;   // prominent / primary actions
  static const double iconXl = 24.0;   // hero buttons
  static const double icon2xl = 32.0;  // feature icons

  // ── F-3 Radii (Material 3 expressive) ──────────────────────────────
  static const double rXs = 2.0;
  static const double rSm = 4.0;
  static const double rMd = 8.0;
  static const double rLg = 12.0;
  static const double rXl = 16.0;
  static const double r2xl = 24.0;
  static const double rPill = 999.0;

  // ── F-4 Bar heights (SAP Fiori 3 + Microsoft 365) ──────────────────
  static const double barSystem = 40.0;         // top system layer
  static const double barScreen = 48.0;         // screen-level toolbar
  static const double barTicker = 28.0;         // news ticker
  static const double sidebarRow = 44.0;        // item row height
  static const double sidebarCollapsed = 64.0;  // collapsed sidebar column
  static const double sidebarExpanded = 264.0;  // expanded sidebar column
  static const double rail = 56.0;              // right quick-access rail

  // ── F-5 Motion (Material 3 emphasized curves) ──────────────────────
  static const Duration motionInstant = Duration(milliseconds: 80);
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionMed = Duration(milliseconds: 200);
  static const Duration motionSlow = Duration(milliseconds: 320);
  static const Duration motionSlower = Duration(milliseconds: 480);
  static const Duration tooltipWait = Duration(milliseconds: 500);
  static const Curve easeStandard = Curves.easeOutCubic;
  static const Curve easeEmphasized = Cubic(0.20, 0.0, 0.0, 1.0);

  // ── F-6 Typography scale (Atlassian + GitHub Primer) ───────────────
  static const double fs2xs = 9.0;   // micro-caption / legal
  static const double fsXs = 10.0;   // badge/status
  static const double fsSm = 11.0;   // caption/meta
  static const double fsMd = 12.5;   // body small (default in dense UIs)
  static const double fsLg = 14.0;   // body (default read)
  static const double fsXl = 16.0;   // subtitle / emphasized body
  static const double fs2xl = 18.0;  // title
  static const double fs3xl = 22.0;  // hero title

  // ── F-7 Font weights ───────────────────────────────────────────────
  static const FontWeight fwRegular = FontWeight.w400;
  static const FontWeight fwMedium = FontWeight.w500;
  static const FontWeight fwSemibold = FontWeight.w600;
  static const FontWeight fwBold = FontWeight.w700;
  static const FontWeight fwBlack = FontWeight.w800;

  // ── F-8 Elevation (Fluent Design 6-tier) ───────────────────────────
  /// Return a list of BoxShadow for the requested elevation level (0-5).
  /// level 0 = flat; level 5 = dialog/popover.
  static List<BoxShadow> elevation(int level, {Color? tint}) {
    final c = tint ?? const Color(0xFF000000);
    switch (level) {
      case 1:
        return [BoxShadow(color: c.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))];
      case 2:
        return [BoxShadow(color: c.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))];
      case 3:
        return [BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))];
      case 4:
        return [BoxShadow(color: c.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))];
      case 5:
        return [BoxShadow(color: c.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 10))];
      case 0:
      default:
        return const [];
    }
  }

  // ── F-9 Breakpoints (Tailwind/Chakra inspired) ─────────────────────
  static const double bpXs = 480.0;   // phone
  static const double bpSm = 720.0;   // large phone / small tablet
  static const double bpMd = 960.0;   // tablet
  static const double bpLg = 1200.0;  // laptop
  static const double bpXl = 1440.0;  // desktop
  static const double bp2xl = 1920.0; // wide desktop

  // Convenience builders — return (InputBorder for a text field).
  static OutlineInputBorder inputBorder(Color color, {double width = 1.0, double radius = rLg}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// AppIcons — curated icon aliases (Wave I-33..I-40)
// One canonical icon per concept to end the chevron_right / close / add
// mix across the codebase.
// ═══════════════════════════════════════════════════════════════════════════
class AppIcons {
  AppIcons._();
  // Navigation
  static const IconData chevronNext = Icons.chevron_right_rounded;
  static const IconData chevronPrev = Icons.chevron_left_rounded;
  static const IconData chevronDown = Icons.expand_more_rounded;
  static const IconData chevronUp = Icons.expand_less_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  // Actions
  static const IconData add = Icons.add_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_alt_rounded;
  static const IconData sort = Icons.sort_rounded;
  static const IconData more = Icons.more_vert_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  // State
  static const IconData check = Icons.check_rounded;
  static const IconData ok = Icons.check_circle_rounded;
  static const IconData warn = Icons.warning_amber_rounded;
  static const IconData err = Icons.error_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData pin = Icons.push_pin_rounded;
  static const IconData pinOutline = Icons.push_pin_outlined;
  // Shell
  static const IconData apps = Icons.apps_rounded;
  static const IconData bell = Icons.notifications_rounded;
  static const IconData help = Icons.help_outline_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData user = Icons.person_rounded;
  static const IconData logout = Icons.logout_rounded;
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
