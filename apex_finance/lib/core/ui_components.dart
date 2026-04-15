import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

// ═══════════════════════════════════════════════════════════
// APEX UI Components — Shared design system widgets
// ═══════════════════════════════════════════════════════════

// ── 1. Soft Card ──────────────────────────────────────────

Widget apexSoftCard({
  String? title,
  required List<Widget> children,
  Color? accent,
  EdgeInsets? padding,
  EdgeInsets? margin,
  VoidCallback? onTap,
}) {
  final content = Container(
    margin: margin ?? const EdgeInsets.only(bottom: 14),
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AC.navy2.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AC.bdr.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(color: AC.bdr.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        Text(title, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
        Divider(color: AC.bdr, height: 18),
      ],
      ...children,
    ]),
  );
  if (onTap != null) {
    return GestureDetector(onTap: onTap, child: content);
  }
  return content;
}

// ── 2. Hero Section ───────────────────────────────────────

class ApexHeroSection extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget>? actions;
  final Color? accentColor;

  const ApexHeroSection({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.actions,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AC.gold;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.10), AC.navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AC.tp, fontSize: 20, fontWeight: FontWeight.w700)),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, style: TextStyle(color: AC.ts, fontSize: 13, height: 1.5)),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8, children: actions!),
          ],
        ])),
      ]),
    );
  }
}

// ── 3. Metric Card ────────────────────────────────────────

class ApexMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const ApexMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(color: AC.tp, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AC.ts, fontSize: 12)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(color: AC.td, fontSize: 11)),
        ],
      ]),
    );
  }
}

Widget apexMetricRow(List<ApexMetricCard> cards) => LayoutBuilder(
  builder: (context, constraints) {
    final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
    return GridView.count(
      crossAxisCount: crossCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.7,
      children: cards,
    );
  },
);

// ── 4. Buttons ────────────────────────────────────────────

Widget apexPrimaryButton(String label, VoidCallback? onPressed, {IconData? icon}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: AC.iconAccent,
      foregroundColor: AC.btnFg,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: icon != null
      ? Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ])
      : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

Widget apexSecondaryButton(String label, VoidCallback? onPressed, {IconData? icon, Color? color}) {
  final c = color ?? AC.gold;
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: c,
      side: BorderSide(color: c.withValues(alpha: 0.45)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: icon != null
      ? Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ])
      : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

// ── 5. Next Step Card ─────────────────────────────────────

class ApexNextStepCard extends StatelessWidget {
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final IconData? icon;

  const ApexNextStepCard({
    super.key,
    this.title = 'الخطوة التالية',
    required this.description,
    required this.buttonLabel,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AC.iconAccent.withValues(alpha: 0.10), AC.navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(color: AC.iconAccent.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AC.iconAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon ?? Icons.arrow_forward_rounded, color: AC.gold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: AC.ts, fontSize: 12, height: 1.4)),
        ])),
        const SizedBox(width: 12),
        apexPrimaryButton(buttonLabel, onPressed),
      ]),
    );
  }
}

// ── 6. Table Legend ───────────────────────────────────────

class ApexTableLegend extends StatelessWidget {
  final List<MapEntry<String, Color>> items;

  const ApexTableLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 18, runSpacing: 6, children: items.map((e) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(e.key, style: TextStyle(color: AC.ts, fontSize: 11)),
        ],
      )).toList()),
    );
  }
}

// ── 7. Selectable Decoration ──────────────────────────────

BoxDecoration apexSelectableDecoration({
  required bool isSelected,
  Color? activeColor,
  double borderRadius = 14,
}) {
  final color = activeColor ?? AC.gold;
  return BoxDecoration(
    color: isSelected ? color.withValues(alpha: 0.10) : AC.navy2,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: isSelected ? color : AC.bdr.withValues(alpha: 0.5),
      width: isSelected ? 1.5 : 1,
    ),
    boxShadow: isSelected
      ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]
      : [BoxShadow(color: AC.bdr.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 1))],
  );
}

// ── 8. Animated Fade-In Wrapper ───────────────────────────

class ApexFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset? slideFrom;

  const ApexFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.slideFrom,
  });

  @override
  State<ApexFadeIn> createState() => _ApexFadeInState();
}

class _ApexFadeInState extends State<ApexFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: widget.slideFrom ?? const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── 9. Staggered List Builder ─────────────────────────────

class ApexStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;

  const ApexStaggeredList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 350),
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: List.generate(children.length, (i) => ApexFadeIn(
      delay: Duration(milliseconds: itemDelay.inMilliseconds * i),
      duration: itemDuration,
      child: children[i],
    )),
  );
}

// ── 10. Hover Card ────────────────────────────────────────

class ApexHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ApexHoverCard({super.key, required this.child, this.onTap, this.padding, this.margin});

  @override
  State<ApexHoverCard> createState() => _ApexHoverCardState();
}

class _ApexHoverCardState extends State<ApexHoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovering = true),
    onExit: (_) => setState(() => _hovering = false),
    cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
        padding: widget.padding ?? const EdgeInsets.all(18),
        transform: _hovering
            ? (Matrix4.identity()..translate(0.0, -3.0)..scale(1.005))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _hovering ? AC.navy3 : AC.navy2.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hovering ? AC.iconAccent.withValues(alpha: 0.35) : AC.bdr.withValues(alpha: 0.15),
            width: _hovering ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering ? AC.iconAccent.withValues(alpha: 0.10) : AC.bdr.withValues(alpha: 0.10),
              blurRadius: _hovering ? 24 : 8,
              spreadRadius: _hovering ? 1 : 0,
              offset: Offset(0, _hovering ? 8 : 2),
            ),
            if (_hovering) BoxShadow(
              color: AC.iconAccent.withValues(alpha: 0.04),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: widget.child,
      ),
    ),
  );
}

// ── 11. Status Indicator Dot ──────────────────────────────

class ApexStatusDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool pulse;

  const ApexStatusDot({super.key, required this.color, this.size = 8, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
      ),
    );
    if (!pulse) return dot;
    return _PulsingDot(color: color, size: size);
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({required this.color, required this.size});
  @override State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.2 + _ctrl.value * 0.4), blurRadius: 4 + _ctrl.value * 6)],
      ),
    ),
  );
}

// ── 12. Section Header ────────────────────────────────────

Widget apexSectionHeader(String title, {String? subtitle, Widget? trailing}) => Padding(
  padding: const EdgeInsets.only(bottom: 14, top: 6),
  child: Row(children: [
    Container(width: 3, height: 20,
      decoration: BoxDecoration(color: AC.iconAccent, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: AC.tp)),
      if (subtitle != null) Text(subtitle, style: TextStyle(color: AC.ts, fontSize: 12)),
    ])),
    if (trailing != null) trailing,
  ]),
);

// ── 13. Empty State ───────────────────────────────────────

Widget apexEmptyState({required IconData icon, required String title, String? subtitle, Widget? action}) => Center(
  child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: AC.iconAccent.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: Icon(icon, color: AC.iconAccent.withValues(alpha: 0.5), size: 32),
      ),
      const SizedBox(height: 18),
      Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w600, color: AC.ts), textAlign: TextAlign.center),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: AC.td, fontSize: 13), textAlign: TextAlign.center),
      ],
      if (action != null) ...[const SizedBox(height: 20), action],
    ]),
  ),
);

// ── 14. Shimmer Loading ───────────────────────────────────

class ApexShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ApexShimmer({super.key, this.width = double.infinity, this.height = 16, this.borderRadius = 8});

  @override
  State<ApexShimmer> createState() => _ApexShimmerState();
}

class _ApexShimmerState extends State<ApexShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          colors: [AC.navy3, AC.navy4, AC.navy3],
          stops: [0.0, _ctrl.value, 1.0],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
    ),
  );
}

Widget apexShimmerCard({double height = 80}) => Container(
  height: height,
  margin: const EdgeInsets.only(bottom: 12),
  child: Row(children: [
    ApexShimmer(width: 48, height: 48, borderRadius: 14),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      ApexShimmer(height: 14, width: 160),
      const SizedBox(height: 8),
      ApexShimmer(height: 10, width: 100),
    ])),
  ]),
);

// ═══════════════════════════════════════════════════════════
// PHASE 2 — Inspired by Apex Intelligence OS Premium Design
// ═══════════════════════════════════════════════════════════

// ── 15. Tinted Card — gradient-tinted card by semantic color ──

enum ApexTint { green, blue, amber, red, violet }

Widget apexTintedCard({
  required ApexTint tint,
  required List<Widget> children,
  String? title,
  EdgeInsets? padding,
  EdgeInsets? margin,
  VoidCallback? onTap,
}) {
  Color tintColor;
  switch (tint) {
    case ApexTint.green: tintColor = AC.ok;
    case ApexTint.blue: tintColor = AC.info;
    case ApexTint.amber: tintColor = AC.warn;
    case ApexTint.red: tintColor = AC.err;
    case ApexTint.violet: tintColor = AC.purple;
  }
  final card = Container(
    margin: margin ?? const EdgeInsets.only(bottom: 12),
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        colors: [tintColor.withValues(alpha: 0.10), AC.navy2],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      border: Border.all(color: tintColor.withValues(alpha: 0.18)),
      boxShadow: [BoxShadow(color: tintColor.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        Text(title, style: TextStyle(color: tintColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
      ],
      ...children,
    ]),
  );
  if (onTap != null) return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  return card;
}

// ── 16. Pill Badge — small colored status indicator ──

Widget apexPill(String text, {Color? color, Color? textColor, bool filled = false}) {
  final c = color ?? AC.gold;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: filled ? c : c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: filled ? null : Border.all(color: c.withValues(alpha: 0.25)),
    ),
    child: Text(text, style: TextStyle(
      color: filled ? (textColor ?? AC.btnFg) : c,
      fontSize: 11, fontWeight: FontWeight.w600,
    )),
  );
}

// ── 17. Severity Badge — critical/review/knowledge with icons ──

Widget apexSeverityBadge(String severity, {String? label}) {
  Color c; IconData icon; String text;
  switch (severity.toLowerCase()) {
    case 'critical':
      c = AC.err; icon = Icons.error_rounded; text = label ?? 'حرج';
    case 'review':
      c = AC.warn; icon = Icons.rate_review_rounded; text = label ?? 'مراجعة';
    case 'knowledge':
      c = AC.purple; icon = Icons.psychology_rounded; text = label ?? 'معرفي';
    case 'success' || 'ok':
      c = AC.ok; icon = Icons.check_circle_rounded; text = label ?? 'تم';
    case 'info':
      c = AC.info; icon = Icons.info_rounded; text = label ?? 'معلومة';
    default:
      c = AC.ts; icon = Icons.circle; text = label ?? severity;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: c.withValues(alpha: 0.20)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: c, size: 14),
      const SizedBox(width: 5),
      Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── 18. Gradient Progress Bar ──

Widget apexGradientProgress({
  required double value,
  double height = 8,
  Color? startColor,
  Color? endColor,
  String? label,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (label != null) ...[
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AC.ts, fontSize: 12)),
        Text('${(value * 100).toInt()}%', style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
    ],
    Container(
      height: height,
      decoration: BoxDecoration(
        color: AC.navy4,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(colors: [
              startColor ?? AC.goldLight,
              endColor ?? AC.gold,
            ]),
            boxShadow: [BoxShadow(color: (endColor ?? AC.gold).withValues(alpha: 0.3), blurRadius: 6)],
          ),
        ),
      ),
    ),
  ]);
}

// ── 19. Execution Checklist ──

class ApexChecklist extends StatelessWidget {
  final List<ApexCheckItem> items;
  const ApexChecklist({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildItem(items[i], i),
          if (i < items.length - 1) Divider(color: AC.bdr.withValues(alpha: 0.4), height: 1),
        ],
      ]),
    );
  }

  Widget _buildItem(ApexCheckItem item, int index) {
    Color statusColor; IconData statusIcon;
    switch (item.status) {
      case CheckStatus.done:
        statusColor = AC.ok; statusIcon = Icons.check_circle_rounded;
      case CheckStatus.pending:
        statusColor = AC.warn; statusIcon = Icons.hourglass_top_rounded;
      case CheckStatus.blocked:
        statusColor = AC.err; statusIcon = Icons.cancel_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(item.label, style: TextStyle(
          color: item.status == CheckStatus.done ? AC.ts : AC.tp,
          fontSize: 13,
          decoration: item.status == CheckStatus.done ? TextDecoration.lineThrough : null,
          decorationColor: AC.ts,
        ))),
        Icon(statusIcon, color: statusColor, size: 18),
      ]),
    );
  }
}

enum CheckStatus { done, pending, blocked }

class ApexCheckItem {
  final String label;
  final CheckStatus status;
  const ApexCheckItem(this.label, this.status);
}

// ── 20. Context Bar — top bar with status pills ──

Widget apexContextBar({
  required List<String> pills,
  List<Widget>? actions,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AC.navy2.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AC.bdr.withValues(alpha: 0.3)),
      boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.10), blurRadius: 10)],
    ),
    child: Row(children: [
      Expanded(child: Wrap(spacing: 8, runSpacing: 6, children: [
        for (final p in pills) apexPill(p),
      ])),
      if (actions != null) ...actions,
    ]),
  );
}

// ── 21. Activity Feed Item ──

Widget apexFeedItem({
  required String title,
  String? subtitle,
  IconData? icon,
  Color? accentColor,
  String? time,
  VoidCallback? onTap,
}) {
  final c = accentColor ?? AC.gold;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.05), AC.navy2],
          begin: Alignment.centerRight, end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.bdr.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon ?? Icons.circle, color: c, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AC.ts, fontSize: 11)),
          ],
        ])),
        if (time != null) Text(time, style: TextStyle(color: AC.td, fontSize: 10)),
      ]),
    ),
  );
}

// ── 22. Score Card — large number with label and subtitle ──

Widget apexScoreCard({
  required String label,
  required String value,
  String? subtitle,
  Color? valueColor,
  Color? tintColor,
  String? infoTip,
}) {
  final c = tintColor ?? AC.gold;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AC.navy2.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: c.withValues(alpha: 0.10)),
      boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.08), blurRadius: 14)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      infoTip != null
          ? apexLabelWithTip(label, infoTip)
          : Text(label, style: TextStyle(color: AC.ts, fontSize: 11)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(
        color: valueColor ?? c,
        fontSize: 28, fontWeight: FontWeight.w800,
      )),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: AC.td, fontSize: 11)),
      ],
    ]),
  );
}

// ── 23. Step Flow — horizontal step indicator ──

Widget apexStepFlow({
  required List<String> steps,
  required int currentStep,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.12), blurRadius: 10)],
    ),
    child: Row(children: [
      for (int i = 0; i < steps.length; i++) ...[
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < currentStep ? AC.ok.withValues(alpha: 0.15)
                   : i == currentStep ? AC.gold.withValues(alpha: 0.15)
                   : AC.navy4,
              border: Border.all(
                color: i < currentStep ? AC.ok
                     : i == currentStep ? AC.gold
                     : AC.bdr,
                width: i == currentStep ? 2 : 1,
              ),
            ),
            child: Center(child: i < currentStep
              ? Icon(Icons.check, color: AC.ok, size: 16)
              : Text('${i + 1}', style: TextStyle(
                  color: i == currentStep ? AC.gold : AC.ts,
                  fontSize: 12, fontWeight: FontWeight.bold,
                ))),
          ),
          const SizedBox(height: 6),
          Text(steps[i], style: TextStyle(
            color: i == currentStep ? AC.gold : AC.ts,
            fontSize: 10, fontWeight: i == currentStep ? FontWeight.w600 : FontWeight.normal,
          ), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        if (i < steps.length - 1) Expanded(
          flex: 0,
          child: Container(
            width: 24, height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: i < currentStep ? AC.ok.withValues(alpha: 0.4) : AC.bdr,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    ]),
  );
}

// ── 24. Notice Banner — important alert with gradient tint ──

Widget apexNoticeBanner({
  required String text,
  String? title,
  ApexTint tint = ApexTint.amber,
  IconData? icon,
  VoidCallback? onAction,
  String? actionLabel,
}) {
  Color c;
  IconData defaultIcon;
  switch (tint) {
    case ApexTint.green: c = AC.ok; defaultIcon = Icons.check_circle_rounded;
    case ApexTint.blue: c = AC.info; defaultIcon = Icons.info_rounded;
    case ApexTint.amber: c = AC.warn; defaultIcon = Icons.warning_amber_rounded;
    case ApexTint.red: c = AC.err; defaultIcon = Icons.error_rounded;
    case ApexTint.violet: c = AC.purple; defaultIcon = Icons.psychology_rounded;
  }
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: [c.withValues(alpha: 0.12), AC.navy2],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      border: Border.all(color: c.withValues(alpha: 0.22)),
    ),
    child: Row(children: [
      Icon(icon ?? defaultIcon, color: c, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) Text(title, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(text, style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
      ])),
      if (onAction != null && actionLabel != null) ...[
        const SizedBox(width: 8),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    ]),
  );
}

// ── 25. Global Snackbar Helpers ──

void apexSnackSuccess(BuildContext context, String msg) =>
    _showApexSnack(context, msg, AC.ok, Icons.check_circle_rounded);

void apexSnackError(BuildContext context, String msg) =>
    _showApexSnack(context, msg, AC.err, Icons.error_rounded);

void apexSnackWarning(BuildContext context, String msg) =>
    _showApexSnack(context, msg, AC.warn, Icons.warning_rounded);

void apexSnackInfo(BuildContext context, String msg) =>
    _showApexSnack(context, msg, AC.info, Icons.info_rounded);

void _showApexSnack(BuildContext context, String msg, Color color, IconData icon) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    backgroundColor: AC.navy2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    ),
    content: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(msg, style: TextStyle(color: AC.tp, fontSize: 13))),
    ]),
    duration: const Duration(seconds: 3),
  ));
}

// ── 26. Animated Section Header ──

Widget apexAnimatedSectionHeader(String title, {IconData? icon, VoidCallback? onAction, String? actionLabel}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      if (icon != null) ...[
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: AC.iconAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AC.gold, size: 16),
        ),
        const SizedBox(width: 10),
      ],
      Text(title, style: TextStyle(color: AC.gold, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      const Spacer(),
      if (onAction != null && actionLabel != null)
        TextButton.icon(
          onPressed: onAction,
          icon: Icon(Icons.arrow_forward_rounded, size: 14, color: AC.gold.withValues(alpha: 0.7)),
          label: Text(actionLabel, style: TextStyle(color: AC.gold.withValues(alpha: 0.7), fontSize: 11)),
        ),
    ]),
  );
}

// ── 27. Loading Skeleton ──

class ApexSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const ApexSkeleton({super.key, this.width = double.infinity, this.height = 16, this.borderRadius = 8});

  @override
  State<ApexSkeleton> createState() => _ApexSkeletonState();
}

class _ApexSkeletonState extends State<ApexSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final v = (1 + _ctrl.value * 2).clamp(0.0, 3.0);
      return Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + v, 0),
            end: Alignment(-0.5 + v, 0),
            colors: [AC.navy3, AC.navy4, AC.navy3],
          ),
        ),
      );
    },
  );
}

// ── 28. Divider with label ──

Widget apexDividerLabel(String label) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Row(children: [
    Expanded(child: Divider(color: AC.bdr, thickness: 0.5)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label, style: TextStyle(color: AC.td, fontSize: 11, fontWeight: FontWeight.w500)),
    ),
    Expanded(child: Divider(color: AC.bdr, thickness: 0.5)),
  ]),
);

// ── 29. Info Tip — contextual (!) tooltip icon ──

/// World-class contextual help: small (!) icon that shows a tooltip on hover/tap.
/// Use next to labels, KPI titles, section headers, or any element needing explanation.
Widget apexInfoTip(String message, {Color? color, double size = 15}) {
  return Tooltip(
    message: message,
    preferBelow: false,
    verticalOffset: 14,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AC.iconAccent.withValues(alpha: 0.3)),
      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
    ),
    textStyle: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'Tajawal', height: 1.5),
    waitDuration: const Duration(milliseconds: 300),
    showDuration: const Duration(seconds: 4),
    child: MouseRegion(
      cursor: SystemMouseCursors.help,
      child: Icon(Icons.info_outline_rounded, size: size, color: color ?? AC.td.withValues(alpha: 0.6)),
    ),
  );
}

/// Inline label + info tip — e.g. "العملاء النشطون (?)"
Widget apexLabelWithTip(String label, String tip, {TextStyle? style, Color? tipColor}) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: style ?? TextStyle(color: AC.ts, fontSize: 11)),
    const SizedBox(width: 4),
    apexInfoTip(tip, color: tipColor, size: 13),
  ]);
}

// ── 30. Action Card — world-class interactive quick action ──

class ApexActionCard extends StatefulWidget {
  final String label;
  final String? description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  const ApexActionCard({
    super.key,
    required this.label,
    this.description,
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  @override
  State<ApexActionCard> createState() => _ApexActionCardState();
}

class _ApexActionCardState extends State<ApexActionCard> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) { setState(() => _pressing = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressing = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() { _hovering = false; _pressing = false; }),
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          transform: _pressing
              ? (Matrix4.identity()..scale(0.97))
              : _hovering
                  ? (Matrix4.identity()..translate(0.0, -2.0))
                  : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering ? widget.color.withValues(alpha: 0.08) : AC.navy2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovering ? widget.color.withValues(alpha: 0.4) : AC.bdr.withValues(alpha: 0.12),
              width: _hovering ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovering ? widget.color.withValues(alpha: 0.12) : AC.bdr.withValues(alpha: 0.08),
                blurRadius: _hovering ? 16 : 6,
                offset: Offset(0, _hovering ? 4 : 1),
              ),
            ],
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: _hovering ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.label, style: TextStyle(
                  color: _hovering ? widget.color : AC.tp,
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
                if (widget.description != null) ...[
                  const SizedBox(height: 2),
                  Text(widget.description!, style: TextStyle(color: AC.td, fontSize: 10)),
                ],
              ],
            )),
            AnimatedOpacity(
              opacity: _hovering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.arrow_forward_ios, color: widget.color, size: 12),
            ),
          ]),
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        child: card,
      );
    }
    return card;
  }
}

// ── 31. Section Title with Info — header + optional (!) tip ──

Widget apexSectionTitle(String title, {
  IconData? icon,
  String? infoTip,
  Widget? trailing,
  Color? color,
}) {
  return Row(children: [
    if (icon != null) ...[
      Icon(icon, color: color ?? AC.gold, size: 18),
      const SizedBox(width: 8),
    ],
    Text(title, style: TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.w700)),
    if (infoTip != null) ...[
      const SizedBox(width: 6),
      apexInfoTip(infoTip),
    ],
    const Spacer(),
    if (trailing != null) trailing,
  ]);
}

// ── 32. Premium Icon Button — world-class hover/press interactions ──

class ApexIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? hoverColor;
  final bool showBadge;
  final Color? badgeColor;

  const ApexIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 20,
    this.color,
    this.hoverColor,
    this.showBadge = false,
    this.badgeColor,
  });

  @override
  State<ApexIconButton> createState() => _ApexIconButtonState();
}

class _ApexIconButtonState extends State<ApexIconButton> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _pressing = false;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() { _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? AC.ts;
    final activeColor = widget.hoverColor ?? AC.gold;

    final btn = GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) { setState(() => _pressing = false); widget.onPressed?.call(); },
      onTapCancel: () => setState(() => _pressing = false),
      child: MouseRegion(
        onEnter: (_) { setState(() => _hovering = true); _glowCtrl.forward(); },
        onExit: (_) { setState(() { _hovering = false; _pressing = false; }); _glowCtrl.reverse(); },
        cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) {
            final t = _glowAnim.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 38, height: 38,
              transform: _pressing
                  ? (Matrix4.identity()..scale(0.88))
                  : _hovering
                      ? (Matrix4.identity()..scale(1.08))
                      : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressing
                    ? activeColor.withValues(alpha: 0.18)
                    : Color.lerp(Colors.transparent, activeColor.withValues(alpha: 0.10), t),
                borderRadius: BorderRadius.circular(10),
                boxShadow: _hovering ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.20 * t),
                    blurRadius: 12 * t,
                    spreadRadius: 1 * t,
                  ),
                ] : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: widget.size,
                    color: Color.lerp(baseColor, activeColor, t),
                  ),
                  if (widget.showBadge) Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: widget.badgeColor ?? AC.err,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: (widget.badgeColor ?? AC.err).withValues(alpha: 0.5), blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: btn,
      );
    }
    return btn;
  }
}

// ── 33. Pulsing Glow FAB — premium floating action button ──

class ApexGlowFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  const ApexGlowFAB({super.key, required this.icon, this.onPressed, this.tooltip, this.color});

  @override
  State<ApexGlowFAB> createState() => _ApexGlowFABState();
}

class _ApexGlowFABState extends State<ApexGlowFAB> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AC.gold;
    final fab = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          final pulse = _pulseCtrl.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: _hovering ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
            transformAlignment: Alignment.center,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: c.withValues(alpha: 0.3 + pulse * 0.15), blurRadius: 16 + pulse * 8, spreadRadius: pulse * 2),
                  BoxShadow(color: c.withValues(alpha: 0.15), blurRadius: 32, spreadRadius: -2),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.white24,
                  child: Center(child: Icon(widget.icon, color: AC.navy, size: 24)),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, preferBelow: false, child: fab);
    }
    return fab;
  }
}
