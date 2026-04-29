/// APEX — Unified Loading & Error States
/// ═══════════════════════════════════════════════════════════════════════
/// Replace ad-hoc CircularProgressIndicator + Container.error patterns
/// across 200+ screens with these 3 components:
///   • ApexLoadingShimmer — for list/card placeholders
///   • ApexInlineSpinner — small inline loader (next to a label)
///   • ApexErrorBanner — recoverable error with retry button
library;

import 'package:flutter/material.dart';
import 'theme.dart';

/// Shimmer placeholder card. Use when loading list/grid data.
class ApexLoadingShimmer extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  const ApexLoadingShimmer({
    super.key,
    this.height = 60,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ApexLoadingShimmer> createState() => _ApexLoadingShimmerState();
}

class _ApexLoadingShimmerState extends State<ApexLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment(_animation.value - 1, 0),
            end: Alignment(_animation.value, 0),
            colors: [
              AC.navy2,
              AC.navy3.withValues(alpha: 0.6),
              AC.navy2,
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton list with N rows of shimmer.
class ApexLoadingList extends StatelessWidget {
  final int count;
  final double rowHeight;
  const ApexLoadingList({super.key, this.count = 6, this.rowHeight = 60});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => ApexLoadingShimmer(height: rowHeight),
    );
  }
}

/// Small inline loader — use next to a label or in a button.
class ApexInlineSpinner extends StatelessWidget {
  final double size;
  final Color? color;
  const ApexInlineSpinner({super.key, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: color ?? AC.gold),
      );
}

/// Recoverable error banner with retry button. Place above content.
class ApexErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ApexErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: AC.err.withValues(alpha: 0.10),
      child: Row(children: [
        Icon(Icons.error_outline, color: AC.err, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message, style: TextStyle(color: AC.err, fontSize: 12))),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: Text(retryLabel, style: TextStyle(color: AC.err)),
          ),
      ]),
    );
  }
}

// ApexErrorPage removed — never instantiated anywhere in the codebase
// (Stage 5d-3 cleanup, 2026-04-29). Restore from git history if needed.
