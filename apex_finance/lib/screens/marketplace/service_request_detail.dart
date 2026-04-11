import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ServiceRequestDetail extends StatelessWidget {
  final Map<String, dynamic> request;
  const ServiceRequestDetail({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, title: Text('\u062a\u0641\u0627\u0635\u064a\u0644 \u0627\u0644\u0637\u0644\u0628', style: TextStyle(color: AC.tp))),
      body: ListView(padding: EdgeInsets.all(14), children: [
        Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request['title'] ?? '\u0637\u0644\u0628 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _row('\u0627\u0644\u062e\u062f\u0645\u0629', request['service_code'] ?? '-'),
            _row('\u0627\u0644\u0639\u0645\u064a\u0644', request['client_name'] ?? '-'),
            _row('\u0627\u0644\u062d\u0627\u0644\u0629', request['status'] ?? 'pending'),
            _row('\u0627\u0644\u0623\u0648\u0644\u0648\u064a\u0629', request['priority'] ?? 'medium'),
            _row('\u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629', request['budget'] ?? '-'),
          ])),
        const SizedBox(height: 14),
        _timeline(),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(padding: EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: TextStyle(color: AC.ts, fontSize: 12)), Text(v, style: TextStyle(color: AC.tp, fontSize: 12))]));

  Widget _timeline() => Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('\u0645\u0633\u0627\u0631 \u0627\u0644\u0637\u0644\u0628', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _step('\u062a\u0645 \u0627\u0644\u0625\u0646\u0634\u0627\u0621', true), _step('\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', true),
      _step('\u062a\u0645 \u0627\u0644\u0625\u0633\u0646\u0627\u062f', false), _step('\u0642\u064a\u062f \u0627\u0644\u062a\u0646\u0641\u064a\u0630', false), _step('\u0645\u0643\u062a\u0645\u0644', false),
    ]));

  Widget _step(String label, bool done) => Padding(padding: EdgeInsets.only(bottom: 8), child: Row(children: [
    Container(width: 24, height: 24, decoration: BoxDecoration(color: done ? AC.ok.withValues(alpha: 0.15) : AC.navy4, shape: BoxShape.circle, border: Border.all(color: done ? AC.ok : AC.ts)),
      child: done ? Icon(Icons.check, color: AC.ok, size: 14) : null),
    SizedBox(width: 10), Text(label, style: TextStyle(color: done ? AC.ok : AC.ts, fontSize: 12))]));
}
