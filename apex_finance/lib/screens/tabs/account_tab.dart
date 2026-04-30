import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../../widgets/apex_widgets.dart';

class AccountTab extends ConsumerStatefulWidget { const AccountTab({super.key}); @override ConsumerState<AccountTab> createState()=>_AccS(); }
class _AccS extends ConsumerState<AccountTab> {
  Map<String,dynamic>? _p, _s; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.getProfile();
      final r2 = await ApiService.getSecuritySettings();
      if(mounted) setState((){ _p=r1.data is Map ? r1.data : null; _s=r2.data is Map ? r2.data : null; _ld=false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  void _logout() { ApiService.logout(); S.clear();
    ApiService.clearToken(); context.go('/login'); }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u062d\u0633\u0627\u0628\u064a', style: TextStyle(color: AC.gold)),
      actions: [ApexIconButton(onPressed: _logout, icon: Icons.logout, color: AC.err, tooltip: 'تسجيل الخروج')]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(16), children: [
        // Profile Card
        Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(color: AC.navy3,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
          child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: AC.navy4,
              child: Text((_p?['user']?['display_name']??'?')[0], style: TextStyle(fontSize: 28, color: AC.gold))),
            SizedBox(height: 12),
            Text(_p?['user']?['display_name']??'', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
            Text('@${_p?['user']?['username']??''}', style: TextStyle(color: AC.ts)),
            SizedBox(height: 4),
            Text(_p?['user']?['email']??'', style: TextStyle(color: AC.ts, fontSize: 12)),
            SizedBox(height: 12),
            OutlinedButton.icon(onPressed: ()=> context.push('/profile/edit', extra: _p),
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
              icon: Icon(Icons.edit, color: AC.gold, size: 16),
              label: Text('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', style: TextStyle(color: AC.gold, fontSize: 12)))])),
        SizedBox(height: 14),
        // Security
        compactCard('\u0627\u0644\u0623\u0645\u0627\u0646', [
          InkWell(onTap:(){context.push('/account/sessions');},child:compactKv('\u0627\u0644\u062c\u0644\u0633\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629', '${_s?['active_sessions']??0}')),
          compactKv('\u0639\u062f\u062f \u0645\u0631\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644', '${_s?['login_count']??0}'),
          compactKv('\u0622\u062e\u0631 \u062f\u062e\u0648\u0644', _s?['last_login']?.toString().substring(0,16)??'-'),
        ]),
        // Menu Items
                _mi(Icons.account_tree, 'شجرة الحسابات COA', AC.cyan,
          ()=>context.go('/clients')),
        _mi(Icons.workspace_premium, '\u062e\u0637\u062a\u064a \u0648\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643', AC.gold,
          ()=>context.go('/subscription')),
        _mi(Icons.notifications_outlined, '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a', AC.cyan,
          ()=>context.go('/notifications')),
        _mi(Icons.lock_outlined, '\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', AC.warn,
          ()=>context.go('/password/change')),
        _mi(Icons.delete_outline, '\u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', AC.err,
          ()=>context.go('/account/close')),
          _mi(Icons.archive, 'الأرشيف', AC.cyan, () => context.push('/archive')),
            _mi(Icons.history, 'سجل النشاط', AC.purple,
            ()=>context.go('/account/activity')),
          _mi(Icons.compare_arrows, 'مقارنة الخطط', AC.cyan,
            ()=>context.go('/plans/compare')),
          _mi(Icons.assignment, 'أنواع المهام', AC.cyan,
            ()=>context.go('/tasks/types')),
          _mi(Icons.description, 'الشروط والأحكام', AC.ts,
            ()=>context.go('/legal')),
          _mi(Icons.devices, 'الجلسات النشطة', AC.cyan,
            ()=>context.go('/account/sessions')),
      ])));
  Widget _mi(IconData i, String l, Color cl, VoidCallback onTap) =>
    ApexMenuItem(icon: i, label: l, color: cl, onTap: onTap);
}
