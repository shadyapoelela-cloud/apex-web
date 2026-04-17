/// APEX responsive utilities — mobile/tablet/desktop breakpoints.
///
/// Used everywhere we switch layout based on viewport width. Matches the
/// breakpoints in Master Blueprint §13 and design_tokens.
///
/// Usage:
/// ```dart
/// if (ApexResponsive.isMobile(context)) {
///   return _mobileLayout();
/// }
/// return _desktopLayout();
/// ```
///
/// Or use the convenience ResponsiveBuilder widget:
/// ```dart
/// ResponsiveBuilder(
///   mobile: _mobileLayout(),
///   tablet: _tabletLayout(),
///   desktop: _desktopLayout(),
/// )
/// ```
library;

import 'package:flutter/material.dart';

enum ApexBreakpoint { mobile, tablet, desktop, wide }

class ApexResponsive {
  static const double mobileMax = 768;
  static const double tabletMax = 1024;
  static const double desktopMax = 1440;

  static ApexBreakpoint of(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < mobileMax) return ApexBreakpoint.mobile;
    if (w < tabletMax) return ApexBreakpoint.tablet;
    if (w < desktopMax) return ApexBreakpoint.desktop;
    return ApexBreakpoint.wide;
  }

  static bool isMobile(BuildContext context) =>
      of(context) == ApexBreakpoint.mobile;

  static bool isTablet(BuildContext context) =>
      of(context) == ApexBreakpoint.tablet;

  static bool isDesktop(BuildContext context) {
    final bp = of(context);
    return bp == ApexBreakpoint.desktop || bp == ApexBreakpoint.wide;
  }

  static bool isWide(BuildContext context) =>
      of(context) == ApexBreakpoint.wide;

  /// Return one of three values based on the current breakpoint.
  /// Useful for inline layout decisions.
  static T select<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final bp = of(context);
    return switch (bp) {
      ApexBreakpoint.mobile => mobile,
      ApexBreakpoint.tablet => tablet ?? mobile,
      ApexBreakpoint.desktop => desktop,
      ApexBreakpoint.wide => desktop,
    };
  }
}

/// Render the right child based on the current breakpoint.
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final bp = ApexResponsive.of(context);
    return switch (bp) {
      ApexBreakpoint.mobile => mobile,
      ApexBreakpoint.tablet => tablet ?? mobile,
      ApexBreakpoint.desktop || ApexBreakpoint.wide => desktop,
    };
  }
}

/// Hide a child on specific breakpoints.
class HideOn extends StatelessWidget {
  final Widget child;
  final bool mobile;
  final bool tablet;
  final bool desktop;

  const HideOn({
    super.key,
    required this.child,
    this.mobile = false,
    this.tablet = false,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final bp = ApexResponsive.of(context);
    final hidden = switch (bp) {
      ApexBreakpoint.mobile => mobile,
      ApexBreakpoint.tablet => tablet,
      ApexBreakpoint.desktop || ApexBreakpoint.wide => desktop,
    };
    return hidden ? const SizedBox.shrink() : child;
  }
}
