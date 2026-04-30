import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../../widgets/apex_widgets.dart';

class MarketTab extends ConsumerStatefulWidget { const MarketTab({super.key}); @override ConsumerState<MarketTab> createState()=>_MarketS(); }
class _MarketS extends ConsumerState<MarketTab> {
  List _provs=[], _reqs=[]; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.listMarketplaceProviders();
      final r2 = await ApiService.listMyRequests();
      if(mounted) setState(() {
        final d1 = r1.data; _provs = d1 is List ? d1 : [];
        final d2 = r2.data; _reqs = d2 is List ? d2 : [];
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0627\u0644\u0645\u0639\u0631\u0636', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: AC.gold,
      onPressed: ()=> context.push('/marketplace/new-request'),
      icon: Icon(Icons.add, color: AC.navy), label: Text('\u0637\u0644\u0628 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.navy))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      ListView(padding: EdgeInsets.all(14), children: [
        Container(margin: EdgeInsets.only(bottom: 14), padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold)), child: Column(children: [Icon(Icons.store_mall_directory, color: AC.gold, size: 36), SizedBox(height: 8), Text("كتالوج الخدمات المهنية", style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4), Text("تصفح 6 خدمات: تحليل مالي، مراجعة، ضرائب، تمويل، دعم، تراخيص", style: TextStyle(color: AC.ts, fontSize: 12), textAlign: TextAlign.center), SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => context.push('/service-catalog', extra: {'clientId': '', 'token': S.token}), icon: Icon(Icons.arrow_forward), label: Text("فتح الكتالوج")))])),
        compactCard('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a \u0627\u0644\u0645\u0639\u062a\u0645\u062f\u0648\u0646', [
          if(_provs.isEmpty) Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u0642\u062f\u0645\u0648 \u062e\u062f\u0645\u0627\u062a \u0628\u0639\u062f', style: TextStyle(color: AC.ts, fontSize: 13))
          else ..._provs.take(5).map((p) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [CircleAvatar(backgroundColor: AC.navy4, radius: 18,
              child: Text((p['display_name']??'?')[0], style: TextStyle(color: AC.gold))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['display_name']??'', style: TextStyle(color: AC.tp, fontSize: 13)),
                Text(p['category']??'', style: TextStyle(color: AC.ts, fontSize: 11))])),
              if(p['rating']!=null) Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, color: AC.gold, size: 14),
                Text('${p['rating']}', style: TextStyle(color: AC.gold, fontSize: 12))])]))),
        ]),
        compactCard('\u0637\u0644\u0628\u0627\u062a \u0627\u0644\u062e\u062f\u0645\u0629', [
          if(_reqs.isEmpty) Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0628\u0639\u062f', style: TextStyle(color: AC.ts, fontSize: 13))
          else ..._reqs.take(5).map((r) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['title']??'', style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${r['urgency']??''} \u2022 ${r['budget_sar']??0} \u0631.\u0633', style: TextStyle(color: AC.ts, fontSize: 11))])),
              compactBadge(r['status']??'open', r['status']=='completed'?AC.ok:r['status']=='matched'?AC.cyan:AC.warn)]))),
        ]),
      ]));
}
