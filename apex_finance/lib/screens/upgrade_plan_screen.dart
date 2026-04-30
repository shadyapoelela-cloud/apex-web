import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/apex_widgets.dart';

class UpgradePlanScreen extends StatelessWidget {
  final List plans; final String? currentPlan;
  UpgradePlanScreen({super.key, required this.plans, this.currentPlan});
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u062a\u0631\u0642\u064a\u0629 \u0627\u0644\u062e\u0637\u0629', style: TextStyle(color: AC.gold))),
    body: ListView(padding: EdgeInsets.all(16), children: [
      Text('\u0627\u062e\u062a\u0631 \u0627\u0644\u062e\u0637\u0629 \u0627\u0644\u0645\u0646\u0627\u0633\u0628\u0629', style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      ...plans.map((p) {
        final isCurrent = p['code'] == currentPlan;
        final features = (p['features'] as Map<String,dynamic>?)?.entries.toList() ?? [];
        return Container(margin: EdgeInsets.only(bottom: 14), padding: EdgeInsets.all(18),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCurrent ? AC.gold : AC.bdr, width: isCurrent ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(p['name_ar']??'', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCurrent ? AC.gold : AC.tp)),
              Spacer(),
              if(isCurrent) compactBadge('\u0627\u0644\u062d\u0627\u0644\u064a\u0629', AC.gold)
              else compactBadge(p['price_monthly_sar']==0?'\u0645\u062c\u0627\u0646\u064a':'${p['price_monthly_sar']} \u0631.\u0633', AC.cyan)]),
            SizedBox(height: 6),
            Text(p['target_user_ar']??'', style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 12),
            ...features.take(8).map((f) => Padding(padding: EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Icon(f.value['value']=='true'||f.value['value']=='unlimited'?Icons.check_circle:Icons.cancel,
                  color: f.value['value']=='true'||f.value['value']=='unlimited'?AC.ok:AC.err.withValues(alpha: 0.5), size: 14),
                SizedBox(width: 8),
                Expanded(child: Text(f.value['name_ar']??f.key, style: TextStyle(color: AC.ts, fontSize: 11)))]))),
            if(!isCurrent) ...[const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () { ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                  content: Text('\u0633\u064a\u062a\u0645 \u062a\u0641\u0639\u064a\u0644 \u0628\u0648\u0627\u0628\u0629 \u0627\u0644\u062f\u0641\u0639 \u0642\u0631\u064a\u0628\u0627\u064b'),
                  backgroundColor: AC.navy3)); },
                child: const Text('\u062a\u0631\u0642\u064a\u0629')))],
          ]));
      }),
    ]));
}
