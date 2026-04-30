import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../../providers/app_providers.dart';
import '../../widgets/apex_widgets.dart';
import '../../widgets/main_nav.dart' show quickServiceBtn;

class DashTab extends ConsumerStatefulWidget { const DashTab({super.key}); @override ConsumerState<DashTab> createState()=>_DashS(); }
class _DashS extends ConsumerState<DashTab> {
  Map<String,dynamic>? _sub; List _plans=[]; bool _ld=true; int _notifCount=0;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      ref.invalidate(currentPlanProvider);
      ref.invalidate(plansProvider);
      ref.invalidate(notificationsProvider);
      final sub = await ref.read(currentPlanProvider.future);
      final plans = await ref.read(plansProvider.future);
      final notifs = await ref.read(notificationsProvider.future);
      if(mounted) setState(() {
        _sub = sub; _plans = plans;
        _notifCount = notifs.where((n) => n['is_read'] != true).length;
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text('\u0645\u0631\u062d\u0628\u0627\u064b ${(S.dname != null && S.dname!.contains('?') ? S.uname : S.dname)??""} \u{1F44B}', style: TextStyle(color: AC.gold, fontSize: 18)),
      actions: [
        Stack(children: [
          ApexIconButton(icon: Icons.notifications_outlined, color: AC.tp,
            tooltip: 'الإشعارات', onPressed: ()=>context.go('/notifications')),
          if(_notifCount>0) Positioned(right:8,top:8, child: Container(padding: EdgeInsets.all(4),
            decoration: BoxDecoration(color: AC.err, shape: BoxShape.circle),
            child: Text('$_notifCount', style: TextStyle(color: AC.btnFg, fontSize: 10))))]),
      ]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(16), children: [
        // Current Plan Card
        compactCard('\u062e\u0637\u062a\u0643 \u0627\u0644\u062d\u0627\u0644\u064a\u0629', [
          Row(children: [Icon(Icons.workspace_premium, color: AC.gold, size: 28), SizedBox(width: 10),
            Text(_sub?['plan_name_ar'] ?? S.planAr(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
            Spacer(), compactBadge(_sub?['status']??'active', AC.ok)]),
          const SizedBox(height: 14),
          ...(_sub?['entitlements'] as Map<String,dynamic>? ?? {}).entries.take(6).map((e) => Padding(
            padding: EdgeInsets.only(bottom: 4), child: Row(children: [
              Icon(e.value['value']=='true'||e.value['value']=='unlimited' ? Icons.check_circle : e.value['value']=='false' ? Icons.cancel : Icons.info_outline,
                color: e.value['value']=='true'||e.value['value']=='unlimited' ? AC.ok : e.value['value']=='false' ? AC.err : AC.cyan, size: 15),
              SizedBox(width: 8),
              Expanded(child: Text('${e.key}: ${e.value['value']}', style: TextStyle(color: AC.ts, fontSize: 11)))]))),
          SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: ()=>context.push('/upgrade-plan', extra: {'plans': _plans, 'currentPlan': _sub?['plan']}),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
            icon: Icon(Icons.upgrade, color: AC.gold, size: 18),
            label: Text('\u062a\u0631\u0642\u064a\u0629 \u0627\u0644\u062e\u0637\u0629', style: TextStyle(color: AC.gold)))),
        ]),

        // ── Copilot Quick Access Card ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
              begin: Alignment.topRight, end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
          ),
          child: InkWell(
            onTap: () => context.go('/copilot'),
            borderRadius: BorderRadius.circular(14),
            child: Row(children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.smart_toy, color: AC.gold, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text('AI', style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                SizedBox(height: 4),
                Text('\u0627\u0633\u0623\u0644 \u0639\u0646 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a\u060c \u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644\u060c \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629\u060c \u0648\u0623\u0643\u062b\u0631', style: TextStyle(color: AC.ts, fontSize: 12)),
              ])),
              Icon(Icons.arrow_forward_ios, color: AC.gold, size: 16),
            ]),
          ),
        ),
        // ── Quick Services Row ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              quickServiceBtn(c, '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', Icons.analytics, 2),
              quickServiceBtn(c, '\u0634\u062c\u0631\u0629 \u062d\u0633\u0627\u0628\u0627\u062a', Icons.account_tree, 1),
              quickServiceBtn(c, '\u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', Icons.receipt_long, 2),
              quickServiceBtn(c, '\u0633\u0648\u0642 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.store, 3),
              quickServiceBtn(c, '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', Icons.checklist, 3),
            ]),
          ),
        ),
        // Plans Grid
        Text('\u0627\u0644\u062e\u0637\u0637 \u0627\u0644\u0645\u062a\u0627\u062d\u0629', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AC.tp)),
        SizedBox(height: 8),
        ..._plans.map((p) => Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p['code']==_sub?['plan'] ? AC.gold : AC.bdr, width: p['code']==_sub?['plan'] ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(p['name_ar']??'', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: p['code']==_sub?['plan'] ? AC.gold : AC.tp)),
                if(p['code']==_sub?['plan']) ...[SizedBox(width:8), compactBadge('\u0627\u0644\u062d\u0627\u0644\u064a\u0629', AC.gold)]]),
              SizedBox(height: 4),
              Text(p['target_user_ar']??'', style: TextStyle(color: AC.ts, fontSize: 11))])),
            Text(p['price_monthly_sar']==0 ? '\u0645\u062c\u0627\u0646\u064a' : '${p['price_monthly_sar']} \u0631.\u0633/\u0634\u0647\u0631',
              style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold))]))),
      ])));
}
