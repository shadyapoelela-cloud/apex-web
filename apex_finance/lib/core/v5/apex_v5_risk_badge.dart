/// APEX V5.1 — Transaction Risk Scoring (Enhancement #9).
///
/// Inspired by MindBridge — every transaction gets an AI risk score
/// with a clear explanation. Not just AI suggestions — ALL transactions.
///
/// Usage:
///   ApexV5RiskBadge(
///     score: 78,
///     factors: ['Posted at 22:47', 'Above SAR 100K', 'First-time vendor'],
///   )
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;

/// Computed risk score (0-100) with factors that contributed to it.
class V5RiskScore {
  final int score; // 0-100
  final List<V5RiskFactor> factors;

  V5RiskScore({required this.score, required this.factors});

  V5RiskLevel get level {
    if (score >= 70) return V5RiskLevel.high;
    if (score >= 40) return V5RiskLevel.medium;
    if (score >= 15) return V5RiskLevel.low;
    return V5RiskLevel.minimal;
  }

  /// Simple rules engine — production replaces with ML model.
  /// Input: transaction dict with amount, hour, vendor, is_new_vendor, etc.
  static V5RiskScore compute({
    required double amount,
    required int hour,
    required bool isNewVendor,
    required bool isRoundNumber,
    required bool isDuplicate,
    required bool isWeekend,
  }) {
    int score = 0;
    final factors = <V5RiskFactor>[];

    if (hour >= 22 || hour < 6) {
      score += 30;
      factors.add(V5RiskFactor(
        labelAr: 'ترحيل خارج ساعات العمل (${hour.toString().padLeft(2, '0')}:00)',
        points: 30,
      ));
    }
    if (amount >= 100000) {
      score += 25;
      factors.add(V5RiskFactor(
        labelAr: 'مبلغ كبير (>${_formatAmount(amount)})',
        points: 25,
      ));
    } else if (amount >= 50000) {
      score += 15;
      factors.add(V5RiskFactor(
        labelAr: 'مبلغ متوسط (${_formatAmount(amount)})',
        points: 15,
      ));
    }
    if (isNewVendor) {
      score += 20;
      factors.add(V5RiskFactor(
        labelAr: 'مورد جديد (أول معاملة)',
        points: 20,
      ));
    }
    if (isRoundNumber) {
      score += 10;
      factors.add(V5RiskFactor(
        labelAr: 'مبلغ مستدير (${_formatAmount(amount)})',
        points: 10,
      ));
    }
    if (isDuplicate) {
      score += 35;
      factors.add(V5RiskFactor(
        labelAr: 'ازدواج محتمل مع معاملة سابقة',
        points: 35,
      ));
    }
    if (isWeekend) {
      score += 15;
      factors.add(V5RiskFactor(
        labelAr: 'ترحيل يوم عطلة',
        points: 15,
      ));
    }

    if (score > 100) score = 100;
    return V5RiskScore(score: score, factors: factors);
  }

  static String _formatAmount(double a) {
    if (a >= 1000000) return '${(a / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '${(a / 1000).toStringAsFixed(0)}K';
    return a.toStringAsFixed(0);
  }
}

enum V5RiskLevel { minimal, low, medium, high }

class V5RiskFactor {
  final String labelAr;
  final int points;

  V5RiskFactor({required this.labelAr, required this.points});
}

/// Compact badge showing score 0-100 with color coding.
/// Click to open explanation popover.
class ApexV5RiskBadge extends StatelessWidget {
  final V5RiskScore riskScore;
  final bool showLabel;
  final double size;

  const ApexV5RiskBadge({
    super.key,
    required this.riskScore,
    this.showLabel = true,
    this.size = 32,
  });

  Color _color() {
    switch (riskScore.level) {
      case V5RiskLevel.minimal: return core_theme.AC.ok;
      case V5RiskLevel.low: return core_theme.AC.info;
      case V5RiskLevel.medium: return core_theme.AC.warn;
      case V5RiskLevel.high: return const Color(0xFFB91C1C);
    }
  }

  String _levelLabel() {
    switch (riskScore.level) {
      case V5RiskLevel.minimal: return 'منخفض جداً';
      case V5RiskLevel.low: return 'منخفض';
      case V5RiskLevel.medium: return 'متوسط';
      case V5RiskLevel.high: return 'مرتفع';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return GestureDetector(
      onTap: () => _showExplanation(context),
      child: Tooltip(
        message: 'درجة المخاطر: ${riskScore.score}/100 — ${_levelLabel()}',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 8 : 4,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                riskScore.level == V5RiskLevel.high
                    ? Icons.warning
                    : riskScore.level == V5RiskLevel.medium
                        ? Icons.info
                        : Icons.shield,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '${riskScore.score}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  _levelLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _color().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.psychology, color: _color(), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تحليل المخاطر',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'درجة الخطر: ${riskScore.score}/100 — ${_levelLabel()}',
                          style: TextStyle(fontSize: 12, color: _color()),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Score visualization
                LinearProgressIndicator(
                  value: riskScore.score / 100,
                  backgroundColor: core_theme.AC.tp.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation(_color()),
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                const Text(
                  'العوامل المساهمة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (riskScore.factors.isEmpty)
                  Text(
                    'لا توجد عوامل خطر ملحوظة',
                    style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                  )
                else
                  for (final f in riskScore.factors)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: core_theme.AC.tp.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _color().withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+${f.points}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _color(),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                f.labelAr,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: core_theme.AC.info.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: core_theme.AC.info.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: core_theme.AC.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هذا تقييم تلقائي مبني على قواعد ثابتة. في الإنتاج — ML model يتعلم من قرارات الفريق.',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
