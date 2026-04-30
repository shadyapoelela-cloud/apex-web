import 'package:flutter/material.dart';
import 'api_service.dart';
import 'core/theme.dart';
import 'core/ui_components.dart';
import 'core/session.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Sprint-1 refactor: the root widget now lives in app/apex_app.dart.
// Re-exported so existing imports of `package:apex_finance/main.dart`
// that rely on `ApexApp` still resolve without source-level churn.
export 'app/apex_app.dart' show ApexApp;
import 'app/apex_app.dart' show ApexApp;
import 'widgets/apex_widgets.dart';

void main() {
  // Restore session from localStorage
  if (S.token == null) {
    final restored = S.restore();
    if (restored && S.token != null) {
      ApiService.setToken(S.token!);
    }
  }
  runApp(const ProviderScope(child: ApexApp()));
}

// AC imported from core/theme.dart
// S imported from core/session.dart










// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// MARKETPLACE TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// PROVIDER TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class ProviderTab extends StatefulWidget { const ProviderTab({super.key}); @override State<ProviderTab> createState()=>_ProvS(); }
class _ProvS extends State<ProviderTab> {
  Map<String,dynamic>? _p; bool _ld=true; bool _notProvider=false;
  final _cats = [
    {'code':'accountant','ar':'\u0645\u062d\u0627\u0633\u0628'},{'code':'tax_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u0636\u0631\u0627\u0626\u0628'},
    {'code':'auditor','ar':'\u0645\u062f\u0642\u0642'},{'code':'financial_controller','ar':'\u0645\u0631\u0627\u0642\u0628 \u0645\u0627\u0644\u064a'},
    {'code':'bookkeeping_specialist','ar':'\u0623\u062e\u0635\u0627\u0626\u064a \u0645\u0633\u0643 \u062f\u0641\u0627\u062a\u0631'},
    {'code':'hr_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u0645\u0648\u0627\u0631\u062f \u0628\u0634\u0631\u064a\u0629'},
    {'code':'legal_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u0642\u0627\u0646\u0648\u0646\u064a'},
    {'code':'marketing_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u062a\u0633\u0648\u064a\u0642'},
  ];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await ApiService.getProviderMe();
      if(r.success) { if(mounted) setState((){ _p=r.data; _ld=false; }); }
      else { if(mounted) setState((){ _notProvider=true; _ld=false; }); }
    } catch(_) { if(mounted) setState((){ _notProvider=true; _ld=false; }); }
  }
  String? _sel;
  Future<void> _register() async {
    if(_sel==null) return;
    final r = await ApiService.registerProvider({'category':_sel});
    if(r.success) _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      _notProvider ? SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(children: [
        Icon(Icons.verified_user_outlined, color: AC.gold, size: 60), SizedBox(height: 16),
        Text('\u0643\u0646 \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629 \u0645\u0639\u062a\u0645\u062f', style: TextStyle(color: AC.tp, fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        ..._cats.map((cat) => GestureDetector(onTap: ()=>setState(()=>_sel=cat['code']),
          child: Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: _sel==cat['code']?AC.gold.withValues(alpha: 0.1):AC.navy3,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: _sel==cat['code']?AC.gold:AC.bdr)),
            child: Row(children: [
              Icon(_sel==cat['code']?Icons.radio_button_checked:Icons.radio_button_off, color: _sel==cat['code']?AC.gold:AC.ts, size: 18),
              SizedBox(width: 10), Text(cat['ar']!, style: TextStyle(color: _sel==cat['code']?AC.gold:AC.tp, fontSize: 13))])))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sel!=null?_register:null,
          child: Text('\u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0643\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629')))])) :
      ListView(padding: EdgeInsets.all(16), children: [
        compactCard('\u0645\u0644\u0641 \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629', [
          compactKv('\u0627\u0644\u062a\u062e\u0635\u0635', _p?['category']??''),
          compactKv('\u0627\u0644\u062d\u0627\u0644\u0629', _p?['verification_status']??'',
            vc: _p?['verification_status']=='approved'?AC.ok:AC.warn),
          compactKv('\u0627\u0644\u0639\u0645\u0648\u0644\u0629', '20% \u0645\u0646\u0635\u0629 / 80% \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629'),
        ]),
        if(_p?['service_scopes']!=null) compactCard('\u0646\u0637\u0627\u0642\u0627\u062a \u0627\u0644\u062e\u062f\u0645\u0629', [
          ...(_p!['service_scopes'] as List).map((s) => Padding(padding: EdgeInsets.only(bottom: 4),
            child: Row(children: [Icon(Icons.check, color: AC.ok, size: 14), SizedBox(width: 8),
              Text(s['name_ar']??s['code']??'', style: TextStyle(color: AC.tp, fontSize: 12))])))]),
        if(_p?['required_documents']!=null) compactCard('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a', [
          ...(_p!['required_documents'] as List).map((d) => Padding(padding: EdgeInsets.only(bottom: 4),
            child: Row(children: [Icon(Icons.description_outlined, color: AC.warn, size: 14), SizedBox(width: 8),
              Text('$d', style: TextStyle(color: AC.tp, fontSize: 12)),
              Spacer(), compactBadge('\u0645\u0637\u0644\u0648\u0628', AC.warn)])))]),
      ]));
}

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ACCOUNT TAB â€” with Profile Editing
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ADMIN TAB â€” Platform Dashboard
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AdminTab extends ConsumerStatefulWidget { const AdminTab({super.key}); @override ConsumerState<AdminTab> createState()=>_AdminS(); }
class _AdminS extends ConsumerState<AdminTab> {
  Map<String,dynamic> _stats = {}; List _users = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.adminStats();
      final r2 = await ApiService.adminUsers();
      if(mounted) setState(() {
        _stats = r1.data is Map ? Map<String,dynamic>.from(r1.data) : {};
        final d2 = r2.data; _users = d2 is List ? d2 : [];
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0644\u0648\u062d\u0629 \u0627\u0644\u0625\u062f\u0627\u0631\u0629', style: TextStyle(color: AC.gold)),
      actions: [
        ApexIconButton(icon: Icons.rate_review, color: AC.cyan,
          tooltip: 'المراجع', onPressed: ()=>context.go('/admin/reviewer')),
        ApexIconButton(icon: Icons.verified_user, color: AC.ok,
          tooltip: 'التحقق من مقدمي الخدمات', onPressed: ()=>context.go('/admin/providers/verify')),
        ApexIconButton(icon: Icons.upload_file, color: AC.gold,
          tooltip: 'مستندات مقدمي الخدمات', onPressed: ()=>context.go('/admin/providers/documents')),
        ApexIconButton(icon: Icons.shield, color: AC.gold,
          tooltip: 'الامتثال', onPressed: ()=>context.go('/admin/providers/compliance')),
        ApexIconButton(icon: Icons.psychology, color: AC.gold,
          tooltip: 'قاعدة المعرفة', onPressed: ()=>context.go('/knowledge/console')),
        ApexIconButton(icon: Icons.security, color: AC.gold,
          tooltip: 'سجل التدقيق', onPressed: ()=>context.go('/admin/audit')),
      ]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(14), children: [
        // Stats Grid
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
          children: [
            _statCard('\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u0648\u0646', '${_stats['total_users']??_users.length}', Icons.people, AC.gold),
            _statCard('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', '${_stats['total_clients']??0}', Icons.business, AC.cyan),
            _statCard('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', '${_stats['total_providers']??0}', Icons.work, AC.ok),
            _statCard('\u0627\u0644\u0637\u0644\u0628\u0627\u062a', '${_stats['total_requests']??0}', Icons.assignment, AC.warn),
            _statCard('\u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a', '${_stats['total_feedback']??0}', Icons.feedback, AC.purple),
            _statCard('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a', '${_stats['total_analyses']??0}', Icons.analytics, AC.info),
          ]),
        SizedBox(height: 16),
        // Quick Actions
        compactCard('\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0633\u0631\u064a\u0639\u0629', [
          _actionTile('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', Icons.rate_review, AC.cyan,
            ()=>context.go('/admin/reviewer')),
          _actionTile('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.verified_user, AC.ok,
            ()=>context.go('/admin/providers/verify')),
          _actionTile('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', Icons.policy, AC.warn,
            ()=>context.go('/admin/policies')),
        ]),
        SizedBox(height: 16),
        // Users List
        compactCard('\u0622\u062e\u0631 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u064a\u0646', [
          if(_users.isEmpty) Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.ts))
          else ..._users.take(10).map((u) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(backgroundColor: AC.navy4, radius: 16,
                child: Text((u['display_name']??u['username']??'?')[0], style: TextStyle(color: AC.gold, fontSize: 12))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['display_name']??u['username']??'', style: TextStyle(color: AC.tp, fontSize: 13)),
                Text('${u['email']??''} \u2022 ${u['plan']??'free'}', style: TextStyle(color: AC.ts, fontSize: 10))])),
              compactBadge(u['status']??'active', u['status']=='active'?AC.ok:AC.err)])))
        ]),
      ])));

  Widget _statCard(String label, String value, IconData icon, Color color) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [Icon(icon, color: color, size: 22), Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]),
      SizedBox(height: 6),
      Text(label, style: TextStyle(color: AC.ts, fontSize: 11))]));

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) =>
    ApexActionTile(label: label, icon: icon, color: color, onTap: onTap);
}

