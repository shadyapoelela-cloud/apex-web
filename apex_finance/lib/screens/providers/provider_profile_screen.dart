import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ProviderProfileScreen extends StatelessWidget {
  final Map<String, dynamic> provider;
  const ProviderProfileScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, title: const Text('\u0645\u0644\u0641 \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629', style: TextStyle(color: AC.tp))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
          child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: AC.gold.withOpacity(0.15), child: Text((provider['name'] ?? 'P')[0], style: const TextStyle(color: AC.gold, fontSize: 28, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            Text(provider['name'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(provider['category'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star, color: AC.gold, size: 18), const SizedBox(width: 4),
              Text('', style: const TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AC.ok.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(provider['status'] ?? 'active', style: const TextStyle(color: AC.ok, fontSize: 11))),
            ]),
          ])),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('\u0627\u0644\u0625\u062d\u0635\u0627\u0626\u064a\u0627\u062a', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(children: [
              _stat('\u0645\u0647\u0627\u0645 \u0645\u0643\u062a\u0645\u0644\u0629', '', AC.ok),
              const SizedBox(width: 8), _stat('\u0642\u064a\u062f \u0627\u0644\u062a\u0646\u0641\u064a\u0630', '', AC.gold),
              const SizedBox(width: 8), _stat('\u0627\u0644\u062a\u0642\u064a\u064a\u0645', '', AC.cyan),
            ].map((w) => Expanded(child: w)).toList()),
          ])),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Container(padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: AC.ts, fontSize: 9))]));
}
