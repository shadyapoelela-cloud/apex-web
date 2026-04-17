/// Live preview of ApexThemeGenerator — pick a base + accent colour,
/// a contrast scalar, toggle dark/light, and see the generated 14
/// palette slots render immediately. Useful for white-label tenants
/// building their brand without touching code.
library;

import 'package:flutter/material.dart';

import '../../core/apex_app_bar.dart';
import '../../core/apex_theme_generator.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ThemeGeneratorScreen extends StatefulWidget {
  const ThemeGeneratorScreen({super.key});

  @override
  State<ThemeGeneratorScreen> createState() => _ThemeGeneratorScreenState();
}

class _ThemeGeneratorScreenState extends State<ThemeGeneratorScreen> {
  Color _base = const Color(0xFF1E3A5F);
  Color _accent = const Color(0xFFD4AF37);
  double _contrast = 1.0;
  bool _isDark = true;

  ApexTheme get _generated => ApexThemeGenerator.generate(
        id: 'preview',
        nameAr: 'معاينة',
        nameEn: 'Preview',
        base: _base,
        accent: _accent,
        contrast: _contrast,
        isDark: _isDark,
      );

  @override
  Widget build(BuildContext context) {
    final t = _generated;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: const ApexAppBar(title: '🎨 مولّد السمات (Linear-style)'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _banner(),
            const SizedBox(height: AppSpacing.xl),
            _controls(),
            const SizedBox(height: AppSpacing.xl),
            _paletteGrid(t),
            const SizedBox(height: AppSpacing.xl),
            _mockup(t),
            const SizedBox(height: AppSpacing.xl),
            _json(t),
          ],
        ),
      ),
    );
  }

  Widget _banner() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent.withValues(alpha: 0.25), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.palette, color: _accent, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3-Variable Theme Generator',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'اختر Base + Accent + Contrast → يُوَلِّد 14 لوناً تلقائياً. بديل عن 12 سمة يدوية.',
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _controls() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اللون الأساسي (Base)',
                style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            _swatchRow([
              const Color(0xFF1E3A5F),
              const Color(0xFF714B67),
              const Color(0xFF0F172A),
              const Color(0xFF1A1A2E),
              const Color(0xFF2D3748),
              const Color(0xFF0B3954),
              const Color(0xFF2B1A4D),
            ], _base, (c) => setState(() => _base = c)),
            const SizedBox(height: AppSpacing.lg),
            Text('لون التمييز (Accent)',
                style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            _swatchRow([
              const Color(0xFFD4AF37),
              const Color(0xFF2563EB),
              const Color(0xFF9333EA),
              const Color(0xFFE11D48),
              const Color(0xFF10B981),
              const Color(0xFFF59E0B),
              const Color(0xFF0EA5E9),
              const Color(0xFFEC4899),
            ], _accent, (c) => setState(() => _accent = c)),
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              Text('التباين: ${(_contrast * 100).round()}%',
                  style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  min: 0.7,
                  max: 1.3,
                  divisions: 12,
                  value: _contrast,
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _contrast = v),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              value: _isDark,
              onChanged: (v) => setState(() => _isDark = v),
              activeColor: _accent,
              title: Text('الوضع المظلم',
                  style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm)),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      );

  Widget _swatchRow(List<Color> options, Color current,
          ValueChanged<Color> onTap) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in options)
          InkWell(
            onTap: () => onTap(c),
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == current ? AC.tp : AC.bdr,
                  width: c == current ? 3 : 1,
                ),
              ),
              child: c == current
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
      ]);

  Widget _paletteGrid(ApexTheme t) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الـ 14 لوناً المُولَّدة',
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _swatchTile('primary', t.primary),
                _swatchTile('primaryLight', t.primaryLight),
                _swatchTile('bg1', t.bg1),
                _swatchTile('bg2', t.bg2),
                _swatchTile('bg3', t.bg3),
                _swatchTile('bg4', t.bg4),
                _swatchTile('textPrimary', t.textPrimary),
                _swatchTile('textSecondary', t.textSecondary),
                _swatchTile('textDim', t.textDim),
                _swatchTile('border', t.border),
                _swatchTile('success', t.success),
                _swatchTile('error', t.error),
                _swatchTile('warning', t.warning),
                _swatchTile('info', t.info),
              ],
            ),
          ],
        ),
      );

  Widget _swatchTile(String label, Color color) => Container(
        width: 120,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AC.bdr),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w600)),
            Text(_hex(color),
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontFamily: 'monospace')),
          ],
        ),
      );

  Widget _mockup(ApexTheme t) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: t.bg1,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: t.border),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.dashboard,
                      color: t.btnFg, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('لوحة التحكم',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.w800)),
                      Text('معاينة مباشرة على الـ theme المُولَّد',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: AppFontSize.sm)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primary,
                    foregroundColor: t.btnFg,
                  ),
                  child: const Text('إجراء'),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              _kpi(t, 'الإيرادات', '124,500', t.success),
              const SizedBox(width: AppSpacing.md),
              _kpi(t, 'الحرق', '15,000', t.error),
              const SizedBox(width: AppSpacing.md),
              _kpi(t, 'المدينون', '42,800', t.warning),
            ]),
          ],
        ),
      );

  Widget _kpi(ApexTheme t, String label, String value, Color accent) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: t.bg3,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: AppFontSize.xs)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: accent,
                      fontSize: AppFontSize.h3,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _json(ApexTheme t) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تعريف الـ Theme (JSON)',
                style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              _themeJson(t),
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace',
                  height: 1.5),
            ),
          ],
        ),
      );

  String _hex(Color c) {
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    final hex = ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0');
    return '#${hex.toUpperCase()}';
  }

  String _themeJson(ApexTheme t) {
    return '{\n'
        '  "mode": "${t.isDark ? 'dark' : 'light'}",\n'
        '  "primary": "${_hex(t.primary)}",\n'
        '  "bg": {\n'
        '    "1": "${_hex(t.bg1)}",\n'
        '    "2": "${_hex(t.bg2)}",\n'
        '    "3": "${_hex(t.bg3)}",\n'
        '    "4": "${_hex(t.bg4)}"\n'
        '  },\n'
        '  "text": {\n'
        '    "primary": "${_hex(t.textPrimary)}",\n'
        '    "secondary": "${_hex(t.textSecondary)}",\n'
        '    "dim": "${_hex(t.textDim)}"\n'
        '  },\n'
        '  "status": {\n'
        '    "success": "${_hex(t.success)}",\n'
        '    "error": "${_hex(t.error)}",\n'
        '    "warning": "${_hex(t.warning)}",\n'
        '    "info": "${_hex(t.info)}"\n'
        '  }\n'
        '}';
  }
}
