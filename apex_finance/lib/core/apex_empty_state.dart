/// APEX — Unified Empty State (4-component formula)
/// ═══════════════════════════════════════════════════════════════════════
/// Per the gap analysis (PatternFly + NN/g convergence):
///   1. Icon/illustration (96dp)
///   2. Headline (H2)
///   3. Description (1 sentence)
///   4. Primary CTA + optional secondary
library;

import 'package:flutter/material.dart';
import 'theme.dart';

class ApexEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ApexEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AC.gold, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AC.tp, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.ts, fontSize: 13, height: 1.5),
            ),
          ],
          if (primaryLabel != null) ...[
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (secondaryLabel != null) ...[
                OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AC.gold),
                      foregroundColor: AC.gold),
                  child: Text(secondaryLabel!),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: onPrimary,
                icon: Icon(primaryIcon ?? Icons.add, size: 16),
                label: Text(primaryLabel!),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AC.gold, foregroundColor: AC.navy),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
