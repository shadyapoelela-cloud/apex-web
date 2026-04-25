/// APEX — CSID Expiry Warning (#1 ZATCA pain point)
/// ═══════════════════════════════════════════════════════════════════════
/// Per gap analysis P3 #23: ZATCA Phase 2 customers lose CSID every year.
/// This is the #1 ticket category in Wafeq support.
///
/// Banner triggers when CSID is within 30 days of expiry.
/// Shows: days remaining + "Renew Now" button (deep-link to ZATCA portal).
library;

import 'package:flutter/material.dart';
import 'theme.dart';

class ApexCsidWarningBanner extends StatelessWidget {
  /// Days until CSID expiry. Negative means already expired.
  final int daysUntilExpiry;
  final VoidCallback? onRenew;
  final VoidCallback? onDismiss;

  const ApexCsidWarningBanner({
    super.key,
    required this.daysUntilExpiry,
    this.onRenew,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (daysUntilExpiry > 30) return const SizedBox.shrink();

    final isExpired = daysUntilExpiry < 0;
    final isCritical = daysUntilExpiry <= 7;
    final color = isExpired
        ? AC.err
        : isCritical
            ? AC.err
            : AC.warn;
    final icon = isExpired
        ? Icons.error
        : isCritical
            ? Icons.error
            : Icons.warning_amber;
    final title = isExpired
        ? 'انتهت صلاحية CSID — لا يمكن إصدار فواتير ZATCA'
        : isCritical
            ? 'CSID ينتهي خلال $daysUntilExpiry أيام — جدد الآن'
            : 'CSID ينتهي خلال $daysUntilExpiry يوماً';
    final subtitle = isExpired
        ? 'يجب التجديد قبل إصدار أي فاتورة جديدة'
        : 'تجنّب توقف إصدار الفواتير بالتجديد المبكر';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(subtitle, style: TextStyle(color: AC.tp, fontSize: 11)),
          ]),
        ),
        ElevatedButton(
          onPressed: onRenew,
          style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white),
          child: const Text('جدد الآن'),
        ),
        if (onDismiss != null) IconButton(
          icon: Icon(Icons.close, color: AC.ts, size: 16),
          onPressed: onDismiss,
        ),
      ]),
    );
  }
}
