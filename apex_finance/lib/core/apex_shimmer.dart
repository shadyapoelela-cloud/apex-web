/// APEX Shimmer — skeleton loaders for tables, cards, and forms.
///
/// Pattern: pulsing gradient on a block-shaped placeholder.
/// Prefer these over CircularProgressIndicator in all FutureBuilder states.
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'theme.dart';

class ApexShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const ApexShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  @override
  State<ApexShimmerBox> createState() => _ApexShimmerBoxState();
}

class _ApexShimmerBoxState extends State<ApexShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AC.navy3.withValues(alpha: 0.3 + _ctrl.value * 0.4),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class ApexShimmerCard extends StatelessWidget {
  const ApexShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.navy4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ApexShimmerBox(width: 120, height: 14),
          SizedBox(height: AppSpacing.md),
          ApexShimmerBox(height: 12),
          SizedBox(height: AppSpacing.sm),
          ApexShimmerBox(width: 200, height: 12),
        ],
      ),
    );
  }
}

class ApexShimmerForm extends StatelessWidget {
  final int fieldCount;

  const ApexShimmerForm({super.key, this.fieldCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: fieldCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ApexShimmerBox(width: 80, height: 10),
          SizedBox(height: AppSpacing.sm),
          ApexShimmerBox(height: 44, radius: AppRadius.md),
        ],
      ),
    );
  }
}
