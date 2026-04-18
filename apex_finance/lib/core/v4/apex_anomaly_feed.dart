/// APEX V4 — Anomaly Feed card (Wave 3 PR#1 UI).
///
/// Renders the output of POST /anomalies/scan as a severity-coded
/// list ready to drop into any dashboard. Patterns #110 and #111
/// from APEX_GLOBAL_RESEARCH_210.
///
/// Each finding gets its own card:
///   [severity ribbon]  [Arabic message]  [impact]  [ids drawer]
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../theme.dart';

/// Matches AnomalyFinding.to_dict() from the backend.
class AnomalyFinding {
  final String type;
  final String severity;       // "high" | "medium" | "low"
  final String messageAr;
  final String impact;         // decimal string from backend
  final List<String> transactionIds;
  final Map<String, dynamic> evidence;

  const AnomalyFinding({
    required this.type,
    required this.severity,
    required this.messageAr,
    required this.impact,
    required this.transactionIds,
    required this.evidence,
  });

  factory AnomalyFinding.fromJson(Map<String, dynamic> j) => AnomalyFinding(
        type: j['type']?.toString() ?? 'unknown',
        severity: j['severity']?.toString() ?? 'low',
        messageAr: j['message_ar']?.toString() ?? '',
        impact: j['impact']?.toString() ?? '0',
        transactionIds: List<String>.from(
            (j['transaction_ids'] as List? ?? []).map((e) => e.toString())),
        evidence: Map<String, dynamic>.from(j['evidence'] as Map? ?? {}),
      );
}

class ApexAnomalyFeed extends StatelessWidget {
  final List<AnomalyFinding> findings;

  /// Callback when the user taps a finding's transaction-ids chip
  /// to drill through. Receives the ids from the tapped card.
  final void Function(AnomalyFinding finding)? onDrill;

  const ApexAnomalyFeed({
    super.key,
    required this.findings,
    this.onDrill,
  });

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const _EmptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: findings.length,
      itemBuilder: (ctx, i) => _FindingCard(
        finding: findings[i],
        onDrill: onDrill,
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final AnomalyFinding finding;
  final void Function(AnomalyFinding finding)? onDrill;

  const _FindingCard({required this.finding, this.onDrill});

  Color _severityColor() {
    switch (finding.severity) {
      case 'high':
        return AC.err;
      case 'medium':
        return AC.warn;
      default:
        return AC.info;
    }
  }

  IconData _typeIcon() {
    switch (finding.type) {
      case 'duplicate_payment':
        return Icons.content_copy;
      case 'round_number':
        return Icons.exposure_zero;
      case 'off_hours_entry':
        return Icons.bedtime;
      case 'new_vendor_large':
        return Icons.person_add_alt_1;
      case 'category_spike':
        return Icons.trending_up;
      default:
        return Icons.warning_amber;
    }
  }

  String _severityLabel() {
    switch (finding.severity) {
      case 'high':
        return 'حرج';
      case 'medium':
        return 'متوسط';
      default:
        return 'منخفض';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(right: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: InkWell(
        onTap: onDrill != null ? () => onDrill!(finding) : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(), color: color, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  _SeverityChip(
                    label: _severityLabel(),
                    color: color,
                  ),
                  const Spacer(),
                  Text(
                    'أثر: ${finding.impact}',
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.sm,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                finding.messageAr,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.base,
                  height: 1.7,
                ),
              ),
              if (finding.transactionIds.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.tag, color: AC.ts, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${finding.transactionIds.length} معاملة',
                        style: TextStyle(
                          color: AC.ts,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                    ),
                    if (onDrill != null)
                      Text(
                        'عرض التفاصيل',
                        style: TextStyle(
                          color: AC.gold,
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SeverityChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: AppFontSize.xs,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: AC.ok, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                'لا شذوذ مكتشَف',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'عمليات اليوم مطابقة لأنماط السلوك المعتاد.',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
              ),
            ],
          ),
        ),
      );
}
