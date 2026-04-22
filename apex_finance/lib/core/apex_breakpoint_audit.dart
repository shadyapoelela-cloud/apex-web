/// APEX Breakpoint Audit — live responsive-design preview tool.
///
/// Lets a designer QA any route at every standard viewport width side by
/// side. Great for proving that Mobile / Tablet / Desktop / Wide all
/// render without overflow or illegible density.
///
/// Each preview is rendered inside a MediaQuery override so the hosted
/// widget thinks it's running at that size. We wrap in a FittedBox to
/// scale it down if the preview pane is narrower than the target width.
library;

import 'package:flutter/material.dart';

import 'apex_responsive.dart';
import 'design_tokens.dart';
import 'theme.dart';

class Breakpoint {
  final String label;
  final String deviceClass;
  final double width;
  final double height;
  final IconData icon;
  final ApexBreakpoint bp;

  const Breakpoint({
    required this.label,
    required this.deviceClass,
    required this.width,
    required this.height,
    required this.icon,
    required this.bp,
  });
}

final List<Breakpoint> kBreakpoints = [
  Breakpoint(
      label: '375 × 812',
      deviceClass: 'Mobile — iPhone 13',
      width: 375,
      height: 812,
      icon: Icons.phone_iphone,
      bp: ApexBreakpoint.mobile),
  Breakpoint(
      label: '768 × 1024',
      deviceClass: 'Tablet — iPad mini',
      width: 768,
      height: 1024,
      icon: Icons.tablet_mac,
      bp: ApexBreakpoint.tablet),
  Breakpoint(
      label: '1366 × 768',
      deviceClass: 'Desktop — laptop',
      width: 1366,
      height: 768,
      icon: Icons.laptop,
      bp: ApexBreakpoint.desktop),
  Breakpoint(
      label: '1920 × 1080',
      deviceClass: 'Wide — external monitor',
      width: 1920,
      height: 1080,
      icon: Icons.desktop_windows,
      bp: ApexBreakpoint.wide),
];

class ApexBreakpointPreview extends StatelessWidget {
  final Breakpoint breakpoint;
  final Widget child;

  const ApexBreakpointPreview({
    super.key,
    required this.breakpoint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(breakpoint.icon, size: 16, color: AC.gold),
          const SizedBox(width: 6),
          Text(breakpoint.deviceClass,
              style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AC.bdr),
            ),
            child: Text(breakpoint.label,
                style: TextStyle(
                    color: AC.gold,
                    fontSize: AppFontSize.xs,
                    fontFamily: 'monospace')),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AC.bdr),
          ),
          clipBehavior: Clip.antiAlias,
          height: 360,
          child: LayoutBuilder(builder: (ctx, cons) {
            // Scale so the virtual device width fits our pane width.
            final scale = cons.maxWidth / breakpoint.width;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: breakpoint.width,
                height: 360 / scale,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(breakpoint.width, 360 / scale),
                    devicePixelRatio: 1,
                  ),
                  child: child,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
