/// APEX White-Label Theme Editor — for partner/reseller tenants.
///
/// Lets an admin customise the brand identity of their APEX instance:
///   • Primary accent colour
///   • Secondary accent colour
///   • Logo text (or later, an uploaded image)
///   • Dark / light mode preference
///   • Corner radius style (soft / sharp / rounded)
///   • Typography scale (compact / default / comfortable)
///
/// Emits a `WhiteLabelConfig` on every change — the host persists it
/// against the tenant and rebuilds MaterialApp with the new ThemeData.
///
/// This widget does NOT apply the theme itself; it's a designer. Pair
/// with a provider at the root that watches the config.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

class WhiteLabelConfig {
  final Color primary;
  final Color secondary;
  final String brandText;
  final bool darkMode;
  final double radiusScale;
  final double typeScale;

  const WhiteLabelConfig({
    this.primary = const Color(0xFFD4AF37),
    this.secondary = const Color(0xFF2E75B6),
    this.brandText = 'APEX',
    this.darkMode = true,
    this.radiusScale = 1.0,
    this.typeScale = 1.0,
  });

  WhiteLabelConfig copyWith({
    Color? primary,
    Color? secondary,
    String? brandText,
    bool? darkMode,
    double? radiusScale,
    double? typeScale,
  }) =>
      WhiteLabelConfig(
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        brandText: brandText ?? this.brandText,
        darkMode: darkMode ?? this.darkMode,
        radiusScale: radiusScale ?? this.radiusScale,
        typeScale: typeScale ?? this.typeScale,
      );
}

class ApexWhiteLabelEditor extends StatefulWidget {
  final WhiteLabelConfig initial;
  final ValueChanged<WhiteLabelConfig> onChanged;

  const ApexWhiteLabelEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<ApexWhiteLabelEditor> createState() => _ApexWhiteLabelEditorState();
}

class _ApexWhiteLabelEditorState extends State<ApexWhiteLabelEditor> {
  late WhiteLabelConfig _cfg = widget.initial;
  late final TextEditingController _brand =
      TextEditingController(text: widget.initial.brandText);

  @override
  void dispose() {
    _brand.dispose();
    super.dispose();
  }

  void _update(WhiteLabelConfig next) {
    setState(() => _cfg = next);
    widget.onChanged(next);
  }

  static const _palette = [
    Color(0xFFD4AF37), // gold (default)
    Color(0xFF2E75B6), // blue
    Color(0xFF27AE60), // green
    Color(0xFF9B59B6), // purple
    Color(0xFFE67E22), // orange
    Color(0xFFE74C3C), // red
    Color(0xFF1ABC9C), // teal
    Color(0xFFF1C40F), // yellow
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: controls
        Expanded(flex: 5, child: _controls()),
        const SizedBox(width: AppSpacing.lg),
        // Right: preview
        Expanded(flex: 4, child: _preview()),
      ],
    );
  }

  Widget _controls() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('اسم العلامة التجارية'),
            TextField(
              controller: _brand,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _update(_cfg.copyWith(brandText: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('اللون الأساسي'),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _palette)
                  _colorDot(c, _cfg.primary == c,
                      onTap: () => _update(_cfg.copyWith(primary: c))),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _label('اللون الثانوي'),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _palette)
                  _colorDot(c, _cfg.secondary == c,
                      onTap: () => _update(_cfg.copyWith(secondary: c))),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _label('الاستدارة'),
            Slider(
              min: 0.0,
              max: 2.0,
              divisions: 8,
              value: _cfg.radiusScale,
              label: '${(_cfg.radiusScale * 100).round()}%',
              activeColor: _cfg.primary,
              onChanged: (v) => _update(_cfg.copyWith(radiusScale: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('حجم الخط'),
            Slider(
              min: 0.85,
              max: 1.2,
              divisions: 7,
              value: _cfg.typeScale,
              label: '${(_cfg.typeScale * 100).round()}%',
              activeColor: _cfg.primary,
              onChanged: (v) => _update(_cfg.copyWith(typeScale: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _cfg.darkMode,
              onChanged: (v) => _update(_cfg.copyWith(darkMode: v)),
              activeColor: _cfg.primary,
              title: Text('الوضع المظلم',
                  style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm)),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      );

  Widget _preview() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _cfg.darkMode ? const Color(0xFF0F1B2D) : Colors.white,
          borderRadius:
              BorderRadius.circular(AppRadius.lg * _cfg.radiusScale),
          border: Border.all(color: _cfg.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _cfg.primary,
                  borderRadius: BorderRadius.circular(
                      AppRadius.md * _cfg.radiusScale),
                ),
                child: const Icon(Icons.apartment,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(_cfg.brandText,
                  style: TextStyle(
                      color:
                          _cfg.darkMode ? Colors.white : Colors.black87,
                      fontSize: AppFontSize.xl * _cfg.typeScale,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Divider(
                color: _cfg.darkMode
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.08)),
            const SizedBox(height: AppSpacing.sm),
            // Demo button row
            Row(children: [
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: _cfg.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppRadius.md * _cfg.radiusScale),
                  ),
                ),
                child: Text('زر أساسي',
                    style:
                        TextStyle(fontSize: AppFontSize.sm * _cfg.typeScale)),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cfg.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppRadius.md * _cfg.radiusScale),
                  ),
                  side: BorderSide(color: _cfg.secondary),
                ),
                child: Text('زر ثانوي',
                    style:
                        TextStyle(fontSize: AppFontSize.sm * _cfg.typeScale)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _cfg.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                    AppRadius.md * _cfg.radiusScale),
                border: Border.all(
                    color: _cfg.primary.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: _cfg.primary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'معاينة مباشرة — كل التغييرات تُعرض هنا فوراً.',
                    style: TextStyle(
                        color: _cfg.darkMode
                            ? Colors.white70
                            : Colors.black87,
                        fontSize: AppFontSize.xs * _cfg.typeScale),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s,
            style: TextStyle(
                color: AC.ts,
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.w600)),
      );

  Widget _colorDot(Color c, bool selected, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? AC.tp : Colors.white24,
              width: selected ? 3 : 1),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}
