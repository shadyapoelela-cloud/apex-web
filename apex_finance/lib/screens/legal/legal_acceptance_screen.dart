import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class LegalAcceptanceLogger extends StatefulWidget {
  const LegalAcceptanceLogger({super.key});
  @override State<LegalAcceptanceLogger> createState() => _LALState();
}

class _LALState extends State<LegalAcceptanceLogger> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  final _policies = [
    {'type': 'terms', 'version': '2.1', 'title': '\u0634\u0631\u0648\u0637 \u0627\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645', 'date': '2026-01-15', 'accepted': true},
    {'type': 'privacy', 'version': '1.8', 'title': '\u0633\u064a\u0627\u0633\u0629 \u0627\u0644\u062e\u0635\u0648\u0635\u064a\u0629', 'date': '2026-01-15', 'accepted': true},
    {'type': 'ai_disclaimer', 'version': '1.0', 'title': '\u062d\u062f\u0648\u062f \u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a', 'date': '2026-03-01', 'accepted': true},
    {'type': 'provider_obligations', 'version': '1.2', 'title': '\u0627\u0644\u062a\u0632\u0627\u0645\u0627\u062a \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629', 'date': '2026-02-01', 'accepted': false},
  ];

  @override
  void initState() { super.initState(); setState(() => _loading = false); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, title: Text('\u0627\u0644\u0634\u0631\u0648\u0637 \u0648\u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(
          padding: EdgeInsets.all(14),
          margin: EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AC.cyan.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.cyan.withValues(alpha: 0.3))),
          child: Row(children: [
            Icon(Icons.info_outline, color: AC.cyan, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('\u0643\u0644 \u0642\u0628\u0648\u0644 \u0645\u0633\u062c\u0644 \u0628\u0627\u0644\u0646\u0633\u062e\u0629 \u0648\u0627\u0644\u062a\u0627\u0631\u064a\u062e \u0648\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u0642\u0628\u0648\u0644', style: TextStyle(color: AC.cyan, fontSize: 12))),
          ]),
        ),
        ..._policies.map((p) => Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: p['accepted'] == true ? AC.ok.withValues(alpha: 0.3) : AC.warn.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(p['accepted'] == true ? Icons.check_circle : Icons.pending, color: p['accepted'] == true ? AC.ok : AC.warn, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text(p['title'] as String, style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AC.navy4, borderRadius: BorderRadius.circular(6)),
                child: Text('v', style: TextStyle(color: AC.gold, fontSize: 10)),
              ),
            ]),
            SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('\u0627\u0644\u0646\u0648\u0639: ', style: TextStyle(color: AC.ts, fontSize: 11)),
              Text('\u0627\u0644\u062a\u0627\u0631\u064a\u062e: ', style: TextStyle(color: AC.ts, fontSize: 11)),
            ]),
            if (p['accepted'] != true) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  await ApiService.acceptLegal(documentType: p['type'] as String, version: p['version'] as String);
                  setState(() => p['accepted'] = true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AC.gold),
                child: Text('\u0642\u0628\u0648\u0644', style: TextStyle(color: AC.navy)),
              )),
            ],
          ]),
        )),
      ]),
    );
  }
}
