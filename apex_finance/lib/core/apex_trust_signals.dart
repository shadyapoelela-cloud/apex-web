/// APEX Trust Signals Widget
/// ═══════════════════════════════════════════════════════════════════════
/// FinTech UX best practice: trust must be visible at every entry point.
/// This widget renders a row of compliance/security badges + social proof
/// that appears below auth forms and on landing pages.
///
/// Reference: Wave 6 SaaS B2B Onboarding 2026 — "Trust-First in FinTech".
/// See architecture/diagrams/03-research-findings.md for source materials.
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'theme.dart';

/// Compact horizontal row of trust badges. Use below an auth form or hero CTA.
class ApexTrustSignals extends StatelessWidget {
  final bool showSocialProof;
  final bool compact;

  const ApexTrustSignals({
    super.key,
    this.showSocialProof = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSocialProof) ...[
          Text(
            '🇸🇦 منصة سعودية معتمدة — ZATCA Phase 2 + SOCPA + IFRS',
            style: TextStyle(
              color: AC.gold,
              fontSize: compact ? AppFontSize.xs : AppFontSize.sm,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.center,
          children: [
            _Badge(
              icon: Icons.verified_user_outlined,
              label: 'ZATCA Phase 2',
              compact: compact,
            ),
            _Badge(
              icon: Icons.lock_outline,
              label: 'تشفير AES-256',
              compact: compact,
            ),
            _Badge(
              icon: Icons.cloud_done_outlined,
              label: 'استضافة سعودية',
              compact: compact,
            ),
            _Badge(
              icon: Icons.gavel_outlined,
              label: 'SOCPA + IFRS',
              compact: compact,
            ),
            _Badge(
              icon: Icons.shield_outlined,
              label: 'SOC 2 Type II قيد الاعتماد',
              compact: compact,
            ),
          ],
        ),
        if (showSocialProof) ...[
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, color: AC.ts, size: 14),
              const SizedBox(width: 6),
              Text(
                '+1,200 شركة تستخدم APEX',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.star_outline, color: AC.ts, size: 14),
              const SizedBox(width: 6),
              Text(
                '4.8/5 على Trustpilot',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  const _Badge({required this.icon, required this.label, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AC.gold, size: compact ? 11 : 13),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: AC.tp,
              fontSize: compact ? 9 : AppFontSize.xs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gamified onboarding progress bar.
/// Shows a horizontal bar with X of N steps complete + a small reward icon.
/// Reference: Wave 6 SaaS Onboarding 2026 — gamification + milestones.
class ApexGamifiedProgress extends StatelessWidget {
  final int current;
  final int total;
  final String? milestoneLabel;
  final bool showReward;

  const ApexGamifiedProgress({
    super.key,
    required this.current,
    required this.total,
    this.milestoneLabel,
    this.showReward = true,
  });

  double get _percent =>
      total <= 0 ? 0.0 : (current / total).clamp(0.0, 1.0).toDouble();

  bool get _complete => current >= total && total > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showReward && _complete) ...[
              const Text('🎉 ', style: TextStyle(fontSize: 14)),
            ],
            Text(
              milestoneLabel ?? 'الخطوة $current من $total',
              style: TextStyle(
                color: _complete ? AC.ok : AC.tp,
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(_percent * 100).round()}%',
              style: TextStyle(
                color: AC.gold,
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: AC.navy3,
              ),
              FractionallySizedBox(
                widthFactor: _percent,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AC.gold.withValues(alpha: 0.7), AC.gold],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
