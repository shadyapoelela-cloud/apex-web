/// APEX — AI Anomaly Feed (Brex Empower / Pilot pattern)
/// ═══════════════════════════════════════════════════════════════════════
/// Inline widget for the Today dashboard showing AI-detected anomalies.
/// Displays the top-3 most-impactful items with action buttons.
///
/// Wires GET /api/v1/ai/anomalies (proactive scanner from app/ai/proactive.py).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

class ApexAnomalyFeedCard extends StatelessWidget {
  final List<Map<String, dynamic>> anomalies;
  final bool loading;
  final VoidCallback? onSeeAll;

  const ApexAnomalyFeedCard({
    super.key,
    this.anomalies = const [],
    this.loading = false,
    this.onSeeAll,
  });

  // Sample/static anomalies for demo when backend isn't reachable.
  static const List<Map<String, dynamic>> _samples = [
    {
      'severity': 'high',
      'title': 'فاتورة مكررة محتملة',
      'description': 'فاتورة بنفس المبلغ والمورد خلال 48 ساعة',
      'action': 'راجع',
      'route': '/app/erp/sales/invoices',
    },
    {
      'severity': 'medium',
      'title': '3 معاملات أعلى من المعتاد',
      'description': 'انحراف >2σ عن متوسط الإنفاق الشهري',
      'action': 'استكشف',
      'route': '/audit/sampling',
    },
    {
      'severity': 'low',
      'title': 'حساب البنوك يحتاج تسوية',
      'description': '12 معاملة لم تُسوّى منذ 7 أيام',
      'action': 'سوّ',
      'route': '/compliance/bank-rec-ai',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final items = anomalies.isEmpty ? _samples : anomalies;
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AC.warn.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber, color: AC.warn, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('🔍 الذكاء وجد ${items.length} ملاحظات',
                  style: TextStyle(
                      color: AC.warn, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: Text('الكل', style: TextStyle(color: AC.warn, fontSize: 11)),
              ),
          ]),
        ),
        if (loading) const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ) else
          ...items.take(3).map((a) {
            final sev = (a['severity'] as String?) ?? 'medium';
            final color = switch (sev) {
              'high' => AC.err,
              'low' => AC.info,
              _ => AC.warn,
            };
            return InkWell(
              onTap: () {
                final route = a['route'] as String?;
                if (route != null) context.go(route);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
                ),
                child: Row(children: [
                  Container(
                    width: 4, height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['title'] ?? '-',
                          style: TextStyle(
                              color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text(a['description'] ?? '',
                          style: TextStyle(color: AC.ts, fontSize: 11)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () {
                      final route = a['route'] as String?;
                      if (route != null) context.go(route);
                    },
                    child: Text(a['action'] ?? 'افتح',
                        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}
