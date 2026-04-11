import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ResultDetailPanel extends StatelessWidget {
  final Map<String, dynamic> result;
  const ResultDetailPanel({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.65, maxChildSize: 0.92,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AC.ts, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          // Title
          Row(children: [
            Icon(Icons.info_outline, color: AC.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(result['title'] ?? '\u062a\u0641\u0627\u0635\u064a\u0644 \u0627\u0644\u0646\u062a\u064a\u062c\u0629', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          Divider(color: AC.bdr, height: 24),
          // Summary
          _section('\u0627\u0644\u0645\u0644\u062e\u0635', Icons.summarize, result['summary'] ?? '\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u0644\u062e\u0635'),
          // Confidence + Risk
          Row(children: [
            Expanded(child: _metricCard('\u0627\u0644\u062b\u0642\u0629', '%',
              (result['confidence'] ?? 0.0) > 0.7 ? AC.ok : (result['confidence'] ?? 0.0) > 0.5 ? AC.warn : AC.err)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('\u0627\u0644\u062e\u0637\u0631', result['risk_level'] ?? 'low',
              result['risk_level'] == 'high' ? AC.err : result['risk_level'] == 'medium' ? AC.warn : AC.ok)),
          ]),
          const SizedBox(height: 14),
          // Evidence
          _sectionHeader('\u0627\u0644\u0623\u062f\u0644\u0629 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u0629', Icons.source),
          ...(result['evidence'] as List? ?? []).map((e) => _evidenceCard(e)),
          // Rules Applied
          _sectionHeader('\u0627\u0644\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0645\u0637\u0628\u0642\u0629', Icons.rule),
          ...(result['rules_applied'] as List? ?? []).map((r) => _ruleChip(r)),
          // References
          _sectionHeader('\u0627\u0644\u0645\u0631\u0627\u062c\u0639', Icons.menu_book),
          ...(result['references'] as List? ?? []).map((ref) => _refCard(ref)),
          // Warnings
          if ((result['warnings'] as List? ?? []).isNotEmpty) ...[
            _sectionHeader('\u062a\u062d\u0630\u064a\u0631\u0627\u062a', Icons.warning_amber),
            ...(result['warnings'] as List? ?? []).map((w) => _warningCard(w)),
          ],
          // Human Review Status
          if (result['review_status'] != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.warn.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.person_search, color: AC.warn, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('\u062d\u0627\u0644\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629: ', style: TextStyle(color: AC.warn, fontSize: 12))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _section(String title, IconData icon, String content) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: AC.cyan, size: 16), SizedBox(width: 6), Text(title, style: TextStyle(color: AC.cyan, fontWeight: FontWeight.bold, fontSize: 13))]),
      const SizedBox(height: 8),
      Text(content, style: TextStyle(color: AC.tp, fontSize: 13, height: 1.5), textDirection: TextDirection.rtl),
    ]),
  );

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Row(children: [Icon(icon, color: AC.gold, size: 18), SizedBox(width: 6), Text(title, style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14))]),
  );

  Widget _metricCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: AC.ts, fontSize: 11)),
    ]),
  );

  Widget _evidenceCard(dynamic e) => Container(
    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
    child: Row(children: [
      Icon(Icons.description_outlined, color: AC.ts, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text('', style: TextStyle(color: AC.tp, fontSize: 12))),
    ]),
  );

  Widget _ruleChip(dynamic r) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(Icons.check_circle_outline, color: AC.cyan, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text('', style: TextStyle(color: AC.tp, fontSize: 12))),
    ]),
  );

  Widget _refCard(dynamic ref) => Container(
    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AC.navy4, borderRadius: BorderRadius.circular(8)),
    child: Text(ref is Map ? ' - ' : '', style: TextStyle(color: AC.tp, fontSize: 11)),
  );

  Widget _warningCard(dynamic w) => Container(
    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Icon(Icons.warning_amber, color: AC.warn, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text('', style: TextStyle(color: AC.warn, fontSize: 11))),
    ]),
  );
}

void showResultDetail(BuildContext context, Map<String, dynamic> result) {
  showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (_) => ResultDetailPanel(result: result));
}
