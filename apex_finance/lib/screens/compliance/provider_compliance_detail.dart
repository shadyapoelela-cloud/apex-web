import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ProviderComplianceDetailScreen extends StatelessWidget {
  const ProviderComplianceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'task': '\u0631\u0641\u0639 \u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u0623\u0645\u0644', 'due': '2026-04-10', 'status': 'overdue', 'type': 'output'},
      {'task': '\u0631\u0641\u0639 \u0623\u0648\u0631\u0627\u0642 \u0627\u0644\u0639\u0645\u0644 \u2014 \u0645\u0635\u0646\u0639 \u0627\u0644\u062c\u0648\u062f\u0629', 'due': '2026-04-15', 'status': 'pending', 'type': 'output'},
      {'task': '\u0631\u0641\u0639 \u0631\u062e\u0635\u0629 \u0645\u0647\u0646\u064a\u0629 \u0645\u062d\u062f\u062b\u0629', 'due': '2026-05-01', 'status': 'ok', 'type': 'document'},
      {'task': '\u0631\u0641\u0639 \u0634\u0647\u0627\u062f\u0629 SOCPA', 'due': '2026-06-01', 'status': 'ok', 'type': 'document'},
      {'task': '\u062a\u0642\u064a\u064a\u0645 \u0639\u0645\u064a\u0644 \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u0646\u0648\u0631', 'due': '2026-04-08', 'status': 'overdue', 'type': 'review'},
    ];

    final overdue = items.where((i) => i['status'] == 'overdue').length;
    final pending = items.where((i) => i['status'] == 'pending').length;

    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, title: const Text('\u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // Warning banner if overdue
        if (overdue > 0) Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AC.err.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.err.withOpacity(0.4))),
          child: Row(children: [
            const Icon(Icons.error_outline, color: AC.err, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(' \u0645\u0647\u0627\u0645 \u0645\u062a\u0623\u062e\u0631\u0629', style: const TextStyle(color: AC.err, fontWeight: FontWeight.bold, fontSize: 14)),
              const Text('\u0642\u062f \u064a\u062a\u0645 \u062a\u0639\u0644\u064a\u0642 \u062d\u0633\u0627\u0628\u0643 \u0639\u0646\u062f \u0639\u062f\u0645 \u0627\u0644\u0627\u0644\u062a\u0632\u0627\u0645', style: TextStyle(color: AC.ts, fontSize: 11)),
            ])),
          ]),
        ),
        // Stats
        Row(children: [
          _stat('\u0645\u062a\u0623\u062e\u0631', '', AC.err),
          const SizedBox(width: 8),
          _stat('\u0645\u0639\u0644\u0642', '', AC.warn),
          const SizedBox(width: 8),
          _stat('\u0645\u0643\u062a\u0645\u0644', '', AC.ok),
        ].map((w) => Expanded(child: w)).toList()),
        const SizedBox(height: 14),
        // Items
        ...items.map((item) {
          final color = item['status'] == 'overdue' ? AC.err : item['status'] == 'pending' ? AC.warn : AC.ok;
          final icon = item['type'] == 'output' ? Icons.upload_file : item['type'] == 'document' ? Icons.description : Icons.star;
          return Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
            child: Row(children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['task'] as String, style: const TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.bold)),
                Text('\u0627\u0644\u0645\u0648\u0639\u062f: ', style: const TextStyle(color: AC.ts, fontSize: 10)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(item['status'] == 'overdue' ? '\u0645\u062a\u0623\u062e\u0631' : item['status'] == 'pending' ? '\u0645\u0639\u0644\u0642' : '\u0645\u0643\u062a\u0645\u0644',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 11)),
    ]),
  );
}
