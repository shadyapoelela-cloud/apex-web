import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const _api = 'https://apex-api-ootk.onrender.com';
void main() => runApp(const ApexApp());

// ═══════════════════════════════════════════════════
// Design System
// ═══════════════════════════════════════════════════
class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}

class S {
  static String? token, uid, uname, dname, plan, email;
  static List<String> roles = [];
  static Map<String,String> h() => {'Authorization':'Bearer ${token??""}'};
  static Map<String,String> hj() => {'Authorization':'Bearer ${token??""}',' Content-Type':'application/json'};
  static void clear() { token=null; uid=null; uname=null; dname=null; plan=null; email=null; roles=[]; }
  static String planAr() {
    const m = {'free':'\u0645\u062c\u0627\u0646\u064a','pro':'\u0627\u062d\u062a\u0631\u0627\u0641\u064a','business':'\u0623\u0639\u0645\u0627\u0644','expert':'\u062e\u0628\u064a\u0631','enterprise':'\u0645\u0624\u0633\u0633\u064a'};
    return m[plan] ?? plan ?? '\u0645\u062c\u0627\u0646\u064a';
  }
}

Widget _card(String t, List<Widget> c, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    const Divider(color: AC.bdr, height: 18), ...c]));

Widget _kv(String k, String v, {Color? vc}) => Padding(padding: const EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget _badge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
  child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)));

InputDecoration _inp(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)));

// ═══════════════════════════════════════════════════
// App Root
// ═══════════════════════════════════════════════════
class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'APEX', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AC.navy,
      appBarTheme: const AppBarTheme(backgroundColor: AC.navy2, elevation: 0, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AC.gold, foregroundColor: AC.navy,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    home: const LoginScreen());
}

// ═══════════════════════════════════════════════════
// LOGIN
// ═══════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginS();
}
class _LoginS extends State<LoginScreen> {
  final _u=TextEditingController(), _p=TextEditingController();
  bool _l=false; String? _e;
  Future<void> _go() async {
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/login'),
        headers:{'Content-Type':'application/json'},
        body: jsonEncode({'username_or_email':_u.text.trim(),'password':_p.text}));
      final d = jsonDecode(r.body);
      if(r.statusCode==200 && d['success']==true) {
        S.token=d['tokens']['access_token']; S.uid=d['user']['id'];
        S.uname=d['user']['username']; S.dname=d['user']['display_name'];
        S.plan=d['user']['plan']; S.email=d['user']['email'];
        S.roles=List<String>.from(d['user']['roles']??[]);
        if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const MainNav()));
      } else { setState(()=> _e=d['detail']??d['error']??'\u062e\u0637\u0623'); }
    } catch(e){ setState(()=> _e='\u062e\u0637\u0623 \u0641\u064a \u0627\u0644\u0627\u062a\u0635\u0627\u0644 \u0628\u0627\u0644\u062e\u0627\u062f\u0645'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(body: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(32), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AC.gold, AC.gold.withOpacity(0.6)])),
        child: const Icon(Icons.account_balance, color: AC.navy, size: 40)),
      const SizedBox(height: 16),
      const Text('APEX', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AC.gold, letterSpacing: 10)),
      const SizedBox(height: 6),
      const Text('\u0645\u0646\u0635\u0629 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a \u0627\u0644\u0630\u0643\u064a\u0629', style: TextStyle(color: AC.ts, fontSize: 13)),
      const SizedBox(height: 40),
      TextField(controller:_u, decoration:_inp('\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u0623\u0648 \u0627\u0644\u0628\u0631\u064a\u062f', ic: Icons.person_outline)),
      const SizedBox(height: 14),
      TextField(controller:_p, obscureText:true, decoration:_inp('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', ic: Icons.lock_outline), onSubmitted:(_)=>_go()),
      if(_e!=null) Padding(padding:const EdgeInsets.only(top:10), child: Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.err.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [const Icon(Icons.error_outline, color:AC.err, size:18), const SizedBox(width:8),
          Expanded(child: Text(_e!, style:const TextStyle(color:AC.err, fontSize:12)))]))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed:_l?null:_go,
        child: _l ? const SizedBox(height:20,width:20, child:CircularProgressIndicator(strokeWidth:2,color:AC.navy)) : const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644', style: TextStyle(fontWeight: FontWeight.bold)))),
      const SizedBox(height: 8),
      TextButton(onPressed:()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ForgotPasswordScreen())),
        child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AC.warn, fontSize: 13))),
      const SizedBox(height: 4),
      TextButton(onPressed:()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const RegScreen())),
        child: const Text('\u0644\u064a\u0633 \u0644\u062f\u064a\u0643 \u062d\u0633\u0627\u0628\u061f \u0633\u062c\u0651\u0644 \u0627\u0644\u0622\u0646', style: TextStyle(color: AC.gold))),
    ])))));
}

// ═══════════════════════════════════════════════════
// REGISTER
// ═══════════════════════════════════════════════════
class RegScreen extends StatefulWidget {
  const RegScreen({super.key});
  @override State<RegScreen> createState() => _RegS();
}
class _RegS extends State<RegScreen> {
  final _un=TextEditingController(),_em=TextEditingController(),_dn=TextEditingController(),_pw=TextEditingController();
  bool _l=false; String? _e;
  Future<void> _go() async {
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/register'), headers:{'Content-Type':'application/json'},
        body: jsonEncode({'username':_un.text.trim(),'email':_em.text.trim(),'display_name':_dn.text.trim(),'password':_pw.text}));
      final d = jsonDecode(r.body);
      if(r.statusCode==200 && d['success']==true) {
        S.token=d['tokens']['access_token']; S.uid=d['user']['id'];
        S.uname=d['user']['username']; S.dname=d['user']['display_name'];
        S.plan=d['user']['plan']; S.email=d['user']['email'];
        if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const MainNav()));
      } else { setState(()=> _e=d['detail']??d['error']??'\u062e\u0637\u0623'); }
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0625\u0646\u0634\u0627\u0621 \u062d\u0633\u0627\u0628', style: TextStyle(color: AC.gold))),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller:_un, decoration:_inp('\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 *', ic: Icons.alternate_email)),
        const SizedBox(height:12), TextField(controller:_em, decoration:_inp('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a *', ic: Icons.email_outlined)),
        const SizedBox(height:12), TextField(controller:_dn, decoration:_inp('\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0638\u0627\u0647\u0631 *', ic: Icons.badge_outlined)),
        const SizedBox(height:12), TextField(controller:_pw, obscureText:true, decoration:_inp('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 *', ic: Icons.lock_outline)),
        if(_e!=null) Padding(padding:const EdgeInsets.only(top:10), child:Text(_e!, style:const TextStyle(color:AC.err, fontSize:12))),
        const SizedBox(height:22),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed:_l?null:_go,
          child: _l ? const CircularProgressIndicator(strokeWidth:2) : const Text('\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u062d\u0633\u0627\u0628'))),
      ])))));
}

// ═══════════════════════════════════════════════════
// MAIN NAVIGATION — 6 tabs
// ═══════════════════════════════════════════════════
class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override State<MainNav> createState() => _MainNavS();
}
class _MainNavS extends State<MainNav> {
  int _i = 0;
  @override Widget build(BuildContext c) => Scaffold(
    body: [const DashTab(), const ClientsTab(), const AnalysisTab(), const MarketTab(), const ProviderTab(), const AccountTab(), const AdminTab()][_i],
    bottomNavigationBar: BottomNavigationBar(currentIndex:_i, onTap:(i)=>setState(()=>_i=i),
      type: BottomNavigationBarType.fixed, backgroundColor: AC.navy2,
      selectedItemColor: AC.gold, unselectedItemColor: AC.ts, selectedFontSize: 11, unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '\u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629'),
        BottomNavigationBarItem(icon: Icon(Icons.business_rounded), label: '\u0627\u0644\u0639\u0645\u0644\u0627\u0621'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: '\u0627\u0644\u062a\u062d\u0644\u064a\u0644'),
        BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: '\u0627\u0644\u0645\u0639\u0631\u0636'),
        BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: '\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: '\u062d\u0633\u0627\u0628\u064a'),
        BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: '\u0625\u062f\u0627\u0631\u0629'),
      ]));
}

// ═══════════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════════
class DashTab extends StatefulWidget { const DashTab({super.key}); @override State<DashTab> createState()=>_DashS(); }
class _DashS extends State<DashTab> {
  Map<String,dynamic>? _sub; List _plans=[]; bool _ld=true; int _notifCount=0;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/subscriptions/me'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/plans'));
      final r3 = await http.get(Uri.parse('$_api/notifications'), headers: S.h());
      if(mounted) setState(() {
        _sub = jsonDecode(r1.body); _plans = jsonDecode(r2.body);
        try { final nots = jsonDecode(r3.body); if(nots is List) _notifCount = nots.where((n)=>n['is_read']!=true).length; } catch(_){}
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text('\u0645\u0631\u062d\u0628\u0627\u064b ${S.dname??""} \u{1F44B}', style: const TextStyle(color: AC.gold, fontSize: 18)),
      actions: [
        Stack(children: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AC.tp),
            onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const NotificationCenterScreenV2()))),
          if(_notifCount>0) Positioned(right:8,top:8, child: Container(padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AC.err, shape: BoxShape.circle),
            child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 10))))]),
      ]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: const EdgeInsets.all(16), children: [
        // Current Plan Card
        _card('\u062e\u0637\u062a\u0643 \u0627\u0644\u062d\u0627\u0644\u064a\u0629', [
          Row(children: [const Icon(Icons.workspace_premium, color: AC.gold, size: 28), const SizedBox(width: 10),
            Text(_sub?['plan_name_ar'] ?? S.planAr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
            const Spacer(), _badge(_sub?['status']??'active', AC.ok)]),
          const SizedBox(height: 14),
          ...(_sub?['entitlements'] as Map<String,dynamic>? ?? {}).entries.take(6).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              Icon(e.value['value']=='true'||e.value['value']=='unlimited' ? Icons.check_circle : e.value['value']=='false' ? Icons.cancel : Icons.info_outline,
                color: e.value['value']=='true'||e.value['value']=='unlimited' ? AC.ok : e.value['value']=='false' ? AC.err : AC.cyan, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text('${e.key}: ${e.value['value']}', style: const TextStyle(color: AC.ts, fontSize: 11)))]))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>UpgradePlanScreen(plans: _plans, currentPlan: _sub?['plan']))),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)),
            icon: const Icon(Icons.upgrade, color: AC.gold, size: 18),
            label: const Text('\u062a\u0631\u0642\u064a\u0629 \u0627\u0644\u062e\u0637\u0629', style: TextStyle(color: AC.gold)))),
        ]),
        // Plans Grid
        const Text('\u0627\u0644\u062e\u0637\u0637 \u0627\u0644\u0645\u062a\u0627\u062d\u0629', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AC.tp)),
        const SizedBox(height: 8),
        ..._plans.map((p) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p['code']==_sub?['plan'] ? AC.gold : AC.bdr, width: p['code']==_sub?['plan'] ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(p['name_ar']??'', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: p['code']==_sub?['plan'] ? AC.gold : AC.tp)),
                if(p['code']==_sub?['plan']) ...[const SizedBox(width:8), _badge('\u0627\u0644\u062d\u0627\u0644\u064a\u0629', AC.gold)]]),
              const SizedBox(height: 4),
              Text(p['target_user_ar']??'', style: const TextStyle(color: AC.ts, fontSize: 11))])),
            Text(p['price_monthly_sar']==0 ? '\u0645\u062c\u0627\u0646\u064a' : '${p['price_monthly_sar']} \u0631.\u0633/\u0634\u0647\u0631',
              style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold))]))),
      ])));
}

// ═══════════════════════════════════════════════════
// NOTIFICATIONS SCREEN (NEW)
// ═══════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotifS();
}
class _NotifS extends State<NotificationsScreen> {
  List _nots = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await http.get(Uri.parse('$_api/notifications'), headers: S.h());
      if(mounted) setState(() { try { _nots = jsonDecode(r.body); } catch(_) { _nots = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _markAllRead() async {
    await http.post(Uri.parse('$_api/notifications/read-all'), headers: S.h());
    _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a', style: TextStyle(color: AC.gold)),
      actions: [TextButton(onPressed: _markAllRead, child: const Text('\u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0643\u0644', style: TextStyle(color: AC.cyan, fontSize: 12)))]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _nots.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.notifications_off_outlined, color: AC.ts, size: 60),
        const SizedBox(height: 12),
        const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0625\u0634\u0639\u0627\u0631\u0627\u062a', style: TextStyle(color: AC.ts, fontSize: 16))])) :
      ListView.builder(padding: const EdgeInsets.all(12), itemCount: _nots.length, itemBuilder: (_, i) {
        final n = _nots[i];
        final isRead = n['is_read'] == true;
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: isRead ? AC.navy3 : AC.navy4, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isRead ? AC.bdr : AC.gold.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_notifIcon(n['type']??''), color: isRead ? AC.ts : AC.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n['title']??n['message']??'', style: TextStyle(color: isRead ? AC.ts : AC.tp, fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
              if(n['body']!=null) Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(n['body'], style: const TextStyle(color: AC.ts, fontSize: 11))),
              Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(n['created_at']?.toString().substring(0,16)??'', style: const TextStyle(color: AC.ts, fontSize: 10)))])),
            if(!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AC.gold, shape: BoxShape.circle))]));
      }));

  IconData _notifIcon(String t) {
    if(t.contains('task')) return Icons.assignment;
    if(t.contains('plan')||t.contains('subscription')) return Icons.workspace_premium;
    if(t.contains('provider')) return Icons.verified_user;
    if(t.contains('knowledge')) return Icons.psychology;
    return Icons.notifications;
  }
}

// ═══════════════════════════════════════════════════
// UPGRADE PLAN SCREEN (NEW)
// ═══════════════════════════════════════════════════
class UpgradePlanScreen extends StatelessWidget {
  final List plans; final String? currentPlan;
  const UpgradePlanScreen({super.key, required this.plans, this.currentPlan});
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u062a\u0631\u0642\u064a\u0629 \u0627\u0644\u062e\u0637\u0629', style: TextStyle(color: AC.gold))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('\u0627\u062e\u062a\u0631 \u0627\u0644\u062e\u0637\u0629 \u0627\u0644\u0645\u0646\u0627\u0633\u0628\u0629', style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      ...plans.map((p) {
        final isCurrent = p['code'] == currentPlan;
        final features = (p['features'] as Map<String,dynamic>?)?.entries.toList() ?? [];
        return Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCurrent ? AC.gold : AC.bdr, width: isCurrent ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(p['name_ar']??'', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCurrent ? AC.gold : AC.tp)),
              const Spacer(),
              if(isCurrent) _badge('\u0627\u0644\u062d\u0627\u0644\u064a\u0629', AC.gold)
              else _badge(p['price_monthly_sar']==0?'\u0645\u062c\u0627\u0646\u064a':'${p['price_monthly_sar']} \u0631.\u0633', AC.cyan)]),
            const SizedBox(height: 6),
            Text(p['target_user_ar']??'', style: const TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 12),
            ...features.take(8).map((f) => Padding(padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Icon(f.value['value']=='true'||f.value['value']=='unlimited'?Icons.check_circle:Icons.cancel,
                  color: f.value['value']=='true'||f.value['value']=='unlimited'?AC.ok:AC.err.withOpacity(0.5), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(f.value['name_ar']??f.key, style: const TextStyle(color: AC.ts, fontSize: 11)))]))),
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

// ═══════════════════════════════════════════════════
// CLIENTS TAB
// ═══════════════════════════════════════════════════
class ClientsTab extends StatefulWidget { const ClientsTab({super.key}); @override State<ClientsTab> createState()=>_ClientsS(); }
class _ClientsS extends State<ClientsTab> {
  List _cl=[]; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await http.get(Uri.parse('$_api/clients'), headers: S.h());
      if(mounted) setState((){  _cl=jsonDecode(r.body); _ld=false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton(backgroundColor: AC.gold, child: const Icon(Icons.add, color: AC.navy),
      onPressed: () async { await Navigator.push(c, MaterialPageRoute(builder:(_)=>const NewClientScreen())); _load(); }),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _cl.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.business_outlined, color: AC.ts, size: 60), const SizedBox(height: 12),
        const Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0639\u0645\u0644\u0627\u0621 \u0628\u0639\u062f', style: TextStyle(color: AC.ts))])) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
        padding: const EdgeInsets.all(14), itemCount: _cl.length, itemBuilder: (_, i) {
          final c2 = _cl[i];
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
            child: Row(children: [
              CircleAvatar(backgroundColor: AC.navy4, radius: 22, child: Text((c2['name_ar']??'?')[0], style: const TextStyle(color: AC.gold, fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c2['name_ar']??'', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.tp, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${c2['client_type']??''} \u2022 ${c2['your_role']??''}', style: const TextStyle(color: AC.ts, fontSize: 11))])),
              if(c2['knowledge_mode']==true) const Icon(Icons.psychology, color: AC.cyan, size: 22)]));
        })));
}

class NewClientScreen extends StatefulWidget { const NewClientScreen({super.key}); @override State<NewClientScreen> createState()=>_NewCS(); }
class _NewCS extends State<NewClientScreen> {
  final _n=TextEditingController(); List _types=[]; String? _t; bool _l=false; String? _e;
  @override void initState() { super.initState(); http.get(Uri.parse('$_api/client-types')).then((r){ if(mounted) setState(()=> _types=jsonDecode(r.body)); }); }
  Future<void> _go() async {
    if(_n.text.trim().isEmpty||_t==null){ setState(()=> _e='\u0627\u0644\u0627\u0633\u0645 \u0648\u0627\u0644\u0646\u0648\u0639 \u0645\u0637\u0644\u0648\u0628\u0627\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/clients'), headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
        body: jsonEncode({'name_ar':_n.text.trim(),'client_type_code':_t}));
      if(jsonDecode(r.body)['success']==true) { if(mounted) Navigator.pop(context); }
      else { setState(()=> _e=jsonDecode(r.body)['detail']); }
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0639\u0645\u064a\u0644 \u062c\u062f\u064a\u062f', style: TextStyle(color: AC.gold))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller:_n, decoration:_inp('\u0627\u0633\u0645 \u0627\u0644\u0634\u0631\u0643\u0629 *', ic: Icons.business)),
      const SizedBox(height: 18), const Text('\u0646\u0648\u0639 \u0627\u0644\u0639\u0645\u064a\u0644 *', style: TextStyle(color: AC.ts, fontSize: 14)),
      const SizedBox(height: 8),
      ..._types.map((t) => GestureDetector(onTap: ()=>setState(()=>_t=t['code']),
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _t==t['code'] ? AC.gold.withOpacity(0.1) : AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _t==t['code'] ? AC.gold : AC.bdr)),
          child: Row(children: [
            Icon(_t==t['code'] ? Icons.radio_button_checked : Icons.radio_button_off, color: _t==t['code'] ? AC.gold : AC.ts, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['name_ar']??'', style: TextStyle(color: _t==t['code'] ? AC.gold : AC.tp, fontWeight: FontWeight.w600, fontSize: 13)),
              if(t['knowledge_mode_eligible']==true) const Text('\u0648\u0636\u0639 \u0627\u0644\u0645\u0639\u0631\u0641\u0629', style: TextStyle(color: AC.cyan, fontSize: 10))]))]))))  ,
      if(_e!=null) Padding(padding:const EdgeInsets.only(top:10), child:Text(_e!, style:const TextStyle(color:AC.err))),
      const SizedBox(height: 20),
      SizedBox(width:double.infinity, child: ElevatedButton(onPressed:_l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth:2) : const Text('\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0639\u0645\u064a\u0644')))])));
}

// ═══════════════════════════════════════════════════
// ANALYSIS TAB — with Result Details Panel (!)
// ═══════════════════════════════════════════════════
class AnalysisTab extends StatefulWidget { const AnalysisTab({super.key}); @override State<AnalysisTab> createState()=>_AnalysisS(); }
class _AnalysisS extends State<AnalysisTab> {
  PlatformFile? _f; List<int>? _fb; bool _a=false; Map<String,dynamic>? _r; String? _e;
  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions:['xlsx','xls'], withData:true);
    if(r!=null && r.files.isNotEmpty) setState((){  _f=r.files.first; _fb=r.files.first.bytes?.toList(); _r=null; _e=null; });
  }
  Future<void> _run() async {
    if(_fb==null) return; setState((){ _a=true; _e=null; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_api/analyze?industry=retail'));
      req.headers['Authorization']='Bearer ${S.token}';
      req.files.add(http.MultipartFile.fromBytes('file', _fb!, filename:'tb.xlsx'));
      final res = await req.send(); final body = await res.stream.bytesToString();
      setState((){ _r=jsonDecode(body); _a=false; });
    } catch(e){ setState((){ _e='$e'; _a=false; }); }
  }
  String _fmt(dynamic v) { if(v==null) return '-'; final d=(v is int)?v.toDouble():(v is double)?v:0.0;
    if(d.abs()>=1e6) return '${(d/1e6).toStringAsFixed(2)}M'; if(d.abs()>=1e3) return '${(d/1e3).toStringAsFixed(1)}K'; return d.toStringAsFixed(2); }

  void _showDetail(BuildContext c, String title, Map<String,dynamic> data) {
    showModalBottomSheet(context: c, backgroundColor: AC.navy2, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AC.ts, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(color: AC.bdr, height: 24),
          ...data.entries.map((e) => _kv(e.key, '${e.value}')),
          if(_r?['knowledge_brain']?['rules_applied']!=null) ...[
            const SizedBox(height: 12),
            const Text('\u0627\u0644\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0645\u0637\u0628\u0642\u0629', style: TextStyle(color: AC.cyan, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...(_r!['knowledge_brain']['rules_applied'] as List? ?? []).map((r) =>
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                const Icon(Icons.rule, color: AC.cyan, size: 14), const SizedBox(width: 8),
                Expanded(child: Text('$r', style: const TextStyle(color: AC.ts, fontSize: 11)))])))],
          if(_r?['warnings']!=null && (_r!['warnings'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('\u062a\u062d\u0630\u064a\u0631\u0627\u062a', style: TextStyle(color: AC.warn, fontWeight: FontWeight.bold)),
            ...(_r!['warnings'] as List).map((w) => Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [const Icon(Icons.warning_amber, color: AC.warn, size: 14), const SizedBox(width: 8),
                Expanded(child: Text('$w', style: const TextStyle(color: AC.ts, fontSize: 11)))])))],
        ])));
  }

  Widget _resultRow(BuildContext c, String label, String value, Map<String,dynamic> detailData) =>
    InkWell(onTap: ()=> _showDetail(c, label, detailData),
      child: Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: AC.ts, fontSize: 13))),
        Text(value, style: const TextStyle(color: AC.tp, fontSize: 14)),
        const SizedBox(width: 6),
        Container(width: 22, height: 22, decoration: BoxDecoration(color: AC.gold.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.info_outline, color: AC.gold, size: 14))])));

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a', style: TextStyle(color: AC.gold))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      GestureDetector(onTap: _pick, child: Container(width: double.infinity, height: 110,
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _f!=null ? AC.gold : AC.bdr)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_f!=null ? Icons.check_circle : Icons.cloud_upload_outlined, color: _f!=null ? AC.ok : AC.gold, size: 34),
          const SizedBox(height: 6),
          Text(_f?.name ?? '\u0627\u0636\u063a\u0637 \u0644\u0631\u0641\u0639 \u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: _f!=null?AC.tp:AC.ts, fontSize: 13))]))),
      const SizedBox(height: 14),
      if(_f!=null && _r==null) SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _a?null:_run, icon: _a ? const SizedBox(height:18,width:18, child: CircularProgressIndicator(strokeWidth:2,color:AC.navy)) : const Icon(Icons.play_arrow),
        label: Text(_a ? '\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0644\u064a\u0644...' : '\u0628\u062f\u0621 \u0627\u0644\u062a\u062d\u0644\u064a\u0644'))),
      if(_e!=null) Padding(padding:const EdgeInsets.only(top:10), child:Text(_e!, style:const TextStyle(color:AC.err))),
      // RESULTS with ! icon
      if(_r!=null && _r!['success']==true) ...[
        const SizedBox(height: 18),
        _card('\u0627\u0644\u062b\u0642\u0629', [
          _resultRow(c, '\u0627\u0644\u0646\u0633\u0628\u0629', '${((_r!['confidence']?['overall']??0)*100).toStringAsFixed(1)}%',
            _r!['confidence'] is Map ? Map<String,dynamic>.from(_r!['confidence']) : {}),
          _resultRow(c, '\u0627\u0644\u062a\u0642\u064a\u064a\u0645', _r!['confidence']?['label']??'',
            {'overall': _r!['confidence']?['overall'], 'label': _r!['confidence']?['label']}),
        ], accent: _getConfidenceColor(_r!['confidence']?['overall'])),
        _card('\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u062f\u062e\u0644', [
          _resultRow(c, '\u0635\u0627\u0641\u064a \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a', _fmt(_r!['income_statement']?['net_revenue']),
            _r!['income_statement'] is Map ? Map<String,dynamic>.from(_r!['income_statement']) : {}),
          _resultRow(c, '\u062a\u0643\u0644\u0641\u0629 \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a', _fmt(_r!['income_statement']?['cogs']),
            {'cogs': _r!['income_statement']?['cogs'], 'method': _r!['income_statement']?['cogs_method']??'N/A'}),
          _resultRow(c, '\u0645\u062c\u0645\u0644 \u0627\u0644\u0631\u0628\u062d', _fmt(_r!['income_statement']?['gross_profit']),
            {'gross_profit': _r!['income_statement']?['gross_profit'], 'margin': _r!['income_statement']?['gross_margin']}),
          _resultRow(c, '\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d', _fmt(_r!['income_statement']?['net_profit']),
            {'net_profit': _r!['income_statement']?['net_profit'], 'margin': _r!['income_statement']?['net_margin']}),
        ]),
        _card('\u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0627\u0644\u0639\u0645\u0648\u0645\u064a\u0629', [
          _resultRow(c, '\u0627\u0644\u0623\u0635\u0648\u0644', _fmt(_r!['balance_sheet']?['total_assets']),
            _r!['balance_sheet'] is Map ? Map<String,dynamic>.from(_r!['balance_sheet']) : {}),
          _resultRow(c, '\u0627\u0644\u0627\u0644\u062a\u0632\u0627\u0645\u0627\u062a', _fmt(_r!['balance_sheet']?['total_liabilities']),
            {'total_liabilities': _r!['balance_sheet']?['total_liabilities']}),
          _resultRow(c, '\u0645\u062a\u0648\u0627\u0632\u0646\u0629', _r!['balance_sheet']?['is_balanced']==true?'\u0646\u0639\u0645 \u2713':'\u0644\u0627 \u2717',
            {'is_balanced': _r!['balance_sheet']?['is_balanced'], 'difference': _r!['balance_sheet']?['difference']}),
        ]),
        if(_r!['knowledge_brain']!=null) _card('\u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', [
          _resultRow(c, '\u0627\u0644\u0642\u0648\u0627\u0639\u062f', '${_r!['knowledge_brain']?['rules_triggered']??0}/${_r!['knowledge_brain']?['rules_evaluated']??0}',
            _r!['knowledge_brain'] is Map ? Map<String,dynamic>.from(_r!['knowledge_brain']) : {}),
        ], accent: AC.cyan),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: ()=>setState((){ _f=null; _fb=null; _r=null; }),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)),
            icon: const Icon(Icons.refresh, color: AC.gold, size: 18),
            label: const Text('\u062a\u062d\u0644\u064a\u0644 \u0622\u062e\u0631', style: TextStyle(color: AC.gold)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>KnowledgeFeedbackScreen(resultId: _r?['result_id']))),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.cyan)),
            icon: const Icon(Icons.feedback_outlined, color: AC.cyan, size: 18),
            label: const Text('\u0645\u0644\u0627\u062d\u0638\u0629 \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.cyan)))),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () async {
            try {
              final req = http.MultipartRequest('POST', Uri.parse('$_api/analyze/report?industry=retail'));
              // auth removed for CORS
              req.files.add(http.MultipartFile.fromBytes('file', _fb!, filename: 'tb.xlsx'));
              final res = await req.send();
              final bytes = await res.stream.toBytes();
              if (res.statusCode == 200) {
                // PDF downloaded - show success
                ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم تحميل التقرير بنجاح'), backgroundColor: Color(0xFF2ECC8A)));
              }
            } catch (e) {
              ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('\u062e\u0637\u0623: $e'), backgroundColor: AC.navy3));
            }
          },
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          label: const Text('\u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0642\u0631\u064a\u0631 PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]])));

  Color _getConfidenceColor(dynamic v) {
    if(v==null) return AC.ts; final d = (v is num) ? v.toDouble() : 0.0;
    if(d >= 0.85) return AC.ok; if(d >= 0.65) return AC.warn; return AC.err;
  }
}

// ═══════════════════════════════════════════════════
// KNOWLEDGE FEEDBACK (NEW)
// ═══════════════════════════════════════════════════
class KnowledgeFeedbackScreen extends StatefulWidget {
  final String? resultId;
  const KnowledgeFeedbackScreen({super.key, this.resultId});
  @override State<KnowledgeFeedbackScreen> createState() => _KFS();
}
class _KFS extends State<KnowledgeFeedbackScreen> {
  final _title = TextEditingController(), _desc = TextEditingController();
  String _type = 'classification_correction'; bool _l = false; String? _e; bool _done = false;
  final _types = [
    {'code':'classification_correction','ar':'\u062a\u0635\u062d\u064a\u062d \u062a\u0628\u0648\u064a\u0628'},
    {'code':'new_rule_suggestion','ar':'\u0627\u0642\u062a\u0631\u0627\u062d \u0642\u0627\u0639\u062f\u0629 \u062c\u062f\u064a\u062f\u0629'},
    {'code':'data_quality_issue','ar':'\u0645\u0634\u0643\u0644\u0629 \u062c\u0648\u062f\u0629 \u0628\u064a\u0627\u0646\u0627\u062a'},
    {'code':'explanation_improvement','ar':'\u062a\u062d\u0633\u064a\u0646 \u0627\u0644\u0634\u0631\u062d'},
  ];
  Future<void> _submit() async {
    if(_title.text.trim().isEmpty) { setState(()=> _e='\u0627\u0644\u0639\u0646\u0648\u0627\u0646 \u0645\u0637\u0644\u0648\u0628'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/knowledge-feedback'),
        headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
        body: jsonEncode({'feedback_type':_type,'title':_title.text.trim(),'description':_desc.text.trim()}));
      if(jsonDecode(r.body)['success']==true) setState(()=> _done=true);
      else setState(()=> _e=jsonDecode(r.body)['detail']);
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0645\u0644\u0627\u062d\u0638\u0629 \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, color: AC.ok, size: 60), const SizedBox(height: 16),
      const Text('\u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0629 \u0628\u0646\u062c\u0627\u062d', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 8),
      const Text('\u0633\u062a\u062e\u0636\u0639 \u0644\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: AC.ts)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: const Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('\u0646\u0648\u0639 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0629', style: TextStyle(color: AC.ts, fontSize: 14)),
      const SizedBox(height: 8),
      ..._types.map((t) => GestureDetector(onTap: ()=>setState(()=>_type=t['code']!),
        child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _type==t['code'] ? AC.gold.withOpacity(0.1) : AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _type==t['code'] ? AC.gold : AC.bdr)),
          child: Row(children: [
            Icon(_type==t['code'] ? Icons.radio_button_checked : Icons.radio_button_off, color: _type==t['code'] ? AC.gold : AC.ts, size: 18),
            const SizedBox(width: 10), Text(t['ar']!, style: TextStyle(color: _type==t['code'] ? AC.gold : AC.tp, fontSize: 13))])))),
      const SizedBox(height: 16),
      TextField(controller: _title, decoration: _inp('\u0627\u0644\u0639\u0646\u0648\u0627\u0646 *', ic: Icons.title)),
      const SizedBox(height: 12),
      TextField(controller: _desc, maxLines: 4, decoration: _inp('\u0627\u0644\u0648\u0635\u0641 \u0627\u0644\u062a\u0641\u0635\u064a\u0644\u064a')),
      if(_e!=null) Padding(padding:const EdgeInsets.only(top:10), child:Text(_e!, style:const TextStyle(color:AC.err))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _l?null:_submit,
        icon: _l ? const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2,color:AC.navy)) : const Icon(Icons.send),
        label: Text(_l ? '\u062c\u0627\u0631\u064a \u0627\u0644\u0625\u0631\u0633\u0627\u0644...' : '\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0629')))])));
}

// ═══════════════════════════════════════════════════
// MARKETPLACE TAB
// ═══════════════════════════════════════════════════
class MarketTab extends StatefulWidget { const MarketTab({super.key}); @override State<MarketTab> createState()=>_MarketS(); }
class _MarketS extends State<MarketTab> {
  List _provs=[], _reqs=[]; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/marketplace/providers'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/marketplace/my-requests'), headers: S.h());
      if(mounted) setState(() {
        try { _provs = jsonDecode(r1.body); } catch(_) { _provs = []; }
        try { _reqs = jsonDecode(r2.body); } catch(_) { _reqs = []; }
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0627\u0644\u0645\u0639\u0631\u0636', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: AC.gold,
      onPressed: ()=> Navigator.push(c, MaterialPageRoute(builder: (_) => const NewServiceRequestScreen())),
      icon: const Icon(Icons.add, color: AC.navy), label: const Text('\u0637\u0644\u0628 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.navy))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      ListView(padding: const EdgeInsets.all(14), children: [
        _card('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a \u0627\u0644\u0645\u0639\u062a\u0645\u062f\u0648\u0646', [
          if(_provs.isEmpty) const Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u0642\u062f\u0645\u0648 \u062e\u062f\u0645\u0627\u062a \u0628\u0639\u062f', style: TextStyle(color: AC.ts, fontSize: 13))
          else ..._provs.take(5).map((p) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [CircleAvatar(backgroundColor: AC.navy4, radius: 18,
              child: Text((p['display_name']??'?')[0], style: const TextStyle(color: AC.gold))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['display_name']??'', style: const TextStyle(color: AC.tp, fontSize: 13)),
                Text(p['category']??'', style: const TextStyle(color: AC.ts, fontSize: 11))])),
              if(p['rating']!=null) Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, color: AC.gold, size: 14),
                Text('${p['rating']}', style: const TextStyle(color: AC.gold, fontSize: 12))])]))),
        ]),
        _card('\u0637\u0644\u0628\u0627\u062a \u0627\u0644\u062e\u062f\u0645\u0629', [
          if(_reqs.isEmpty) const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0628\u0639\u062f', style: TextStyle(color: AC.ts, fontSize: 13))
          else ..._reqs.take(5).map((r) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['title']??'', style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${r['urgency']??''} \u2022 ${r['budget_sar']??0} \u0631.\u0633', style: const TextStyle(color: AC.ts, fontSize: 11))])),
              _badge(r['status']??'open', r['status']=='completed'?AC.ok:r['status']=='matched'?AC.cyan:AC.warn)]))),
        ]),
      ]));
}

// ═══════════════════════════════════════════════════
// NEW SERVICE REQUEST (NEW)
// ═══════════════════════════════════════════════════
class NewServiceRequestScreen extends StatefulWidget {
  const NewServiceRequestScreen({super.key});
  @override State<NewServiceRequestScreen> createState() => _NSRS();
}
class _NSRS extends State<NewServiceRequestScreen> {
  final _title=TextEditingController(), _desc=TextEditingController(), _budget=TextEditingController();
  String _urgency='medium'; List _clients=[]; String? _clientId, _e; bool _l=false, _done=false;
  @override void initState() { super.initState();
    http.get(Uri.parse('$_api/clients'), headers: S.h()).then((r){ if(mounted) setState(()=> _clients=jsonDecode(r.body)); }); }
  Future<void> _go() async {
    if(_title.text.isEmpty||_clientId==null) { setState(()=> _e='\u0627\u0644\u0639\u0646\u0648\u0627\u0646 \u0648\u0627\u0644\u0639\u0645\u064a\u0644 \u0645\u0637\u0644\u0648\u0628\u0627\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/marketplace/requests'),
        headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
        body: jsonEncode({'client_id':_clientId,'title':_title.text.trim(),'description':_desc.text.trim(),
          'urgency':_urgency,'budget_sar':double.tryParse(_budget.text)??0,'deadline_days':14}));
      if(jsonDecode(r.body)['success']==true) setState(()=> _done=true);
      else setState(()=> _e=jsonDecode(r.body)['detail']);
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0637\u0644\u0628 \u062e\u062f\u0645\u0629 \u062c\u062f\u064a\u062f', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, color: AC.ok, size: 60), const SizedBox(height: 16),
      const Text('\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0637\u0644\u0628 \u0627\u0644\u062e\u062f\u0645\u0629', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: const Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if(_clients.isNotEmpty) ...[
        const Text('\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0645\u064a\u0644', style: TextStyle(color: AC.ts, fontSize: 13)),
        const SizedBox(height: 6),
        ..._clients.map((cl) => GestureDetector(onTap: ()=>setState(()=>_clientId=cl['id']),
          child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _clientId==cl['id']?AC.gold.withOpacity(0.1):AC.navy3,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _clientId==cl['id']?AC.gold:AC.bdr)),
            child: Text(cl['name_ar']??'', style: TextStyle(color: _clientId==cl['id']?AC.gold:AC.tp, fontSize: 13))))),
        const SizedBox(height: 12)],
      TextField(controller: _title, decoration: _inp('\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0637\u0644\u0628 *')),
      const SizedBox(height: 12),
      TextField(controller: _desc, maxLines: 3, decoration: _inp('\u0648\u0635\u0641 \u0627\u0644\u0637\u0644\u0628')),
      const SizedBox(height: 12),
      TextField(controller: _budget, keyboardType: TextInputType.number, decoration: _inp('\u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 (\u0631.\u0633)', ic: Icons.attach_money)),
      const SizedBox(height: 12),
      const Text('\u0627\u0644\u0623\u0648\u0644\u0648\u064a\u0629', style: TextStyle(color: AC.ts, fontSize: 13)),
      const SizedBox(height: 6),
      Row(children: ['low','medium','high'].map((u) => Expanded(child: GestureDetector(onTap: ()=>setState(()=>_urgency=u),
        child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: _urgency==u ? (u=='high'?AC.err:u=='medium'?AC.warn:AC.ok).withOpacity(0.15) : AC.navy3,
            borderRadius: BorderRadius.circular(8), border: Border.all(color: _urgency==u ? (u=='high'?AC.err:u=='medium'?AC.warn:AC.ok) : AC.bdr)),
          child: Center(child: Text(u=='high'?'\u0639\u0627\u0644\u064a\u0629':u=='medium'?'\u0645\u062a\u0648\u0633\u0637\u0629':'\u0645\u0646\u062e\u0641\u0636\u0629',
            style: TextStyle(color: _urgency==u ? AC.tp : AC.ts, fontSize: 12))))))).toList()),
      if(_e!=null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_e!, style: const TextStyle(color: AC.err))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0637\u0644\u0628')))])));
}

// ═══════════════════════════════════════════════════
// PROVIDER TAB
// ═══════════════════════════════════════════════════
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
    try { final r = await http.get(Uri.parse('$_api/service-providers/me'), headers: S.h());
      if(r.statusCode==200) { if(mounted) setState((){ _p=jsonDecode(r.body); _ld=false; }); }
      else { if(mounted) setState((){ _notProvider=true; _ld=false; }); }
    } catch(_) { if(mounted) setState((){ _notProvider=true; _ld=false; }); }
  }
  String? _sel;
  Future<void> _register() async {
    if(_sel==null) return;
    final r = await http.post(Uri.parse('$_api/service-providers/register'),
      headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
      body: jsonEncode({'category':_sel}));
    if(r.statusCode==200) _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _notProvider ? SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.verified_user_outlined, color: AC.gold, size: 60), const SizedBox(height: 16),
        const Text('\u0643\u0646 \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629 \u0645\u0639\u062a\u0645\u062f', style: TextStyle(color: AC.tp, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ..._cats.map((cat) => GestureDetector(onTap: ()=>setState(()=>_sel=cat['code']),
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _sel==cat['code']?AC.gold.withOpacity(0.1):AC.navy3,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: _sel==cat['code']?AC.gold:AC.bdr)),
            child: Row(children: [
              Icon(_sel==cat['code']?Icons.radio_button_checked:Icons.radio_button_off, color: _sel==cat['code']?AC.gold:AC.ts, size: 18),
              const SizedBox(width: 10), Text(cat['ar']!, style: TextStyle(color: _sel==cat['code']?AC.gold:AC.tp, fontSize: 13))])))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sel!=null?_register:null,
          child: const Text('\u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0643\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629')))])) :
      ListView(padding: const EdgeInsets.all(16), children: [
        _card('\u0645\u0644\u0641 \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629', [
          _kv('\u0627\u0644\u062a\u062e\u0635\u0635', _p?['category']??''),
          _kv('\u0627\u0644\u062d\u0627\u0644\u0629', _p?['verification_status']??'',
            vc: _p?['verification_status']=='approved'?AC.ok:AC.warn),
          _kv('\u0627\u0644\u0639\u0645\u0648\u0644\u0629', '20% \u0645\u0646\u0635\u0629 / 80% \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629'),
        ]),
        if(_p?['service_scopes']!=null) _card('\u0646\u0637\u0627\u0642\u0627\u062a \u0627\u0644\u062e\u062f\u0645\u0629', [
          ...(_p!['service_scopes'] as List).map((s) => Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [const Icon(Icons.check, color: AC.ok, size: 14), const SizedBox(width: 8),
              Text(s['name_ar']??s['code']??'', style: const TextStyle(color: AC.tp, fontSize: 12))])))]),
        if(_p?['required_documents']!=null) _card('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a', [
          ...(_p!['required_documents'] as List).map((d) => Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [const Icon(Icons.description_outlined, color: AC.warn, size: 14), const SizedBox(width: 8),
              Text('$d', style: const TextStyle(color: AC.tp, fontSize: 12)),
              const Spacer(), _badge('\u0645\u0637\u0644\u0648\u0628', AC.warn)])))]),
      ]));
}

// ═══════════════════════════════════════════════════
// ACCOUNT TAB — with Profile Editing
// ═══════════════════════════════════════════════════
class AccountTab extends StatefulWidget { const AccountTab({super.key}); @override State<AccountTab> createState()=>_AccS(); }
class _AccS extends State<AccountTab> {
  Map<String,dynamic>? _p, _s; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/users/me'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/users/me/security'), headers: S.h());
      if(mounted) setState((){ _p=jsonDecode(r1.body); _s=jsonDecode(r2.body); _ld=false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  void _logout() { http.post(Uri.parse('$_api/auth/logout'), headers: S.h()); S.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const LoginScreen())); }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u062d\u0633\u0627\u0628\u064a', style: TextStyle(color: AC.gold)),
      actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: AC.err))]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: const EdgeInsets.all(16), children: [
        // Profile Card
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AC.navy3,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
          child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: AC.navy4,
              child: Text((_p?['user']?['display_name']??'?')[0], style: const TextStyle(fontSize: 28, color: AC.gold))),
            const SizedBox(height: 12),
            Text(_p?['user']?['display_name']??'', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
            Text('@${_p?['user']?['username']??''}', style: const TextStyle(color: AC.ts)),
            const SizedBox(height: 4),
            Text(_p?['user']?['email']??'', style: const TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: ()=> Navigator.push(c, MaterialPageRoute(builder:(_)=>EditProfileScreen(profile: _p))),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)),
              icon: const Icon(Icons.edit, color: AC.gold, size: 16),
              label: const Text('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', style: TextStyle(color: AC.gold, fontSize: 12)))])),
        const SizedBox(height: 14),
        // Security
        _card('\u0627\u0644\u0623\u0645\u0627\u0646', [
          _kv('\u0627\u0644\u062c\u0644\u0633\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629', '${_s?['active_sessions']??0}'),
          _kv('\u0639\u062f\u062f \u0645\u0631\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644', '${_s?['login_count']??0}'),
          _kv('\u0622\u062e\u0631 \u062f\u062e\u0648\u0644', _s?['last_login']?.toString().substring(0,16)??'-'),
        ]),
        // Menu Items
        _mi(Icons.workspace_premium, '\u062e\u0637\u062a\u064a \u0648\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643', AC.gold,
          ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const SubscriptionScreen()))),
        _mi(Icons.notifications_outlined, '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a', AC.cyan,
          ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const NotificationCenterScreenV2()))),
        _mi(Icons.lock_outlined, '\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', AC.warn,
          ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ChangePasswordScreen()))),
        _mi(Icons.delete_outline, '\u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', AC.err,
          ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const CloseAccountScreen()))),
          _mi(Icons.history, 'سجل النشاط', const Color(0xFF9C27B0),
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ActivityHistoryScreen()))),
          _mi(Icons.compare_arrows, 'مقارنة الخطط', AC.cyan,
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const PlanComparisonScreen()))),
          _mi(Icons.assignment, 'أنواع المهام', AC.cyan,
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const TaskTypesBrowserScreen()))),
          _mi(Icons.description, 'الشروط والأحكام', const Color(0xFF607D8B),
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>LegalAcceptanceScreen(onAccepted: ()=>Navigator.pop(c))))),
      ])));
  Widget _mi(IconData i, String l, Color c, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
      child: ListTile(leading: Icon(i, color: c), title: Text(l, style: const TextStyle(color: AC.tp, fontSize: 14)),
        trailing: const Icon(Icons.chevron_left, color: AC.ts))));
}

// ═══════════════════════════════════════════════════
// EDIT PROFILE (NEW)
// ═══════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  final Map<String,dynamic>? profile;
  const EditProfileScreen({super.key, this.profile});
  @override State<EditProfileScreen> createState() => _EditPS();
}
class _EditPS extends State<EditProfileScreen> {
  late TextEditingController _dn, _org, _job, _city;
  bool _l=false; String? _e; bool _done=false;
  @override void initState() { super.initState();
    _dn=TextEditingController(text: widget.profile?['user']?['display_name']??'');
    _org=TextEditingController(text: widget.profile?['profile']?['organization_name']??'');
    _job=TextEditingController(text: widget.profile?['profile']?['job_title']??'');
    _city=TextEditingController(text: widget.profile?['profile']?['city']??'');
  }
  Future<void> _save() async {
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.put(Uri.parse('$_api/users/me'),
        headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
        body: jsonEncode({'display_name':_dn.text.trim(),'organization_name':_org.text.trim(),'job_title':_job.text.trim(),'city':_city.text.trim()}));
      if(r.statusCode==200) { S.dname=_dn.text.trim(); setState(()=> _done=true); }
      else { setState(()=> _e=jsonDecode(r.body)['detail']); }
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, color: AC.ok, size: 60), const SizedBox(height: 16),
      const Text('\u062a\u0645 \u0627\u0644\u062d\u0641\u0638 \u0628\u0646\u062c\u0627\u062d', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: const Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: _dn, decoration: _inp('\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0638\u0627\u0647\u0631', ic: Icons.person)),
      const SizedBox(height: 14),
      TextField(controller: _org, decoration: _inp('\u0627\u0644\u0645\u0646\u0638\u0645\u0629', ic: Icons.business)),
      const SizedBox(height: 14),
      TextField(controller: _job, decoration: _inp('\u0627\u0644\u0645\u0633\u0645\u0649 \u0627\u0644\u0648\u0638\u064a\u0641\u064a', ic: Icons.work)),
      const SizedBox(height: 14),
      TextField(controller: _city, decoration: _inp('\u0627\u0644\u0645\u062f\u064a\u0646\u0629', ic: Icons.location_city)),
      if(_e!=null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_e!, style: const TextStyle(color: AC.err))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l?null:_save,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('\u062d\u0641\u0638 \u0627\u0644\u062a\u063a\u064a\u064a\u0631\u0627\u062a')))])));
}

// ═══════════════════════════════════════════════════
// CHANGE PASSWORD (NEW)
// ═══════════════════════════════════════════════════
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override State<ChangePasswordScreen> createState() => _ChPwS();
}
class _ChPwS extends State<ChangePasswordScreen> {
  final _cur=TextEditingController(), _new1=TextEditingController(), _new2=TextEditingController();
  bool _l=false; String? _e; bool _done=false;
  Future<void> _go() async {
    if(_new1.text!=_new2.text) { setState(()=> _e='\u0643\u0644\u0645\u062a\u0627 \u0627\u0644\u0645\u0631\u0648\u0631 \u063a\u064a\u0631 \u0645\u062a\u0637\u0627\u0628\u0642\u062a\u064a\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/change-password'),
        headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
        body: jsonEncode({'current_password':_cur.text,'new_password':_new1.text}));
      if(r.statusCode==200) setState(()=> _done=true);
      else setState(()=> _e=jsonDecode(r.body)['detail']);
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, color: AC.ok, size: 60), const SizedBox(height: 16),
      const Text('\u062a\u0645 \u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: const Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: _cur, obscureText: true, decoration: _inp('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u0627\u0644\u062d\u0627\u0644\u064a\u0629', ic: Icons.lock)),
      const SizedBox(height: 14),
      TextField(controller: _new1, obscureText: true, decoration: _inp('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u0627\u0644\u062c\u062f\u064a\u062f\u0629', ic: Icons.lock_outline)),
      const SizedBox(height: 14),
      TextField(controller: _new2, obscureText: true, decoration: _inp('\u062a\u0623\u0643\u064a\u062f \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', ic: Icons.lock_outline)),
      if(_e!=null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_e!, style: const TextStyle(color: AC.err))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('\u062a\u063a\u064a\u064a\u0631')))])));
}

// ═══════════════════════════════════════════════════
// CLOSE ACCOUNT (NEW)
// ═══════════════════════════════════════════════════
class CloseAccountScreen extends StatefulWidget {
  const CloseAccountScreen({super.key});
  @override State<CloseAccountScreen> createState() => _CloseAS();
}
class _CloseAS extends State<CloseAccountScreen> {
  String _type = 'temporary'; String? _e; bool _l=false, _done=false;
  Future<void> _go() async {
    setState((){ _l=true; _e=null; });
    try {
      final r = await http.post(Uri.parse('$_api/account/closure'),
        headers:{'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
        body: jsonEncode({'closure_type':_type}));
      if(r.statusCode==200) setState(()=> _done=true);
      else setState(()=> _e=jsonDecode(r.body)['detail']??'\u062e\u0637\u0623');
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', style: TextStyle(color: AC.err))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, color: AC.ok, size: 60), const SizedBox(height: 16),
      const Text('\u062a\u0645 \u062a\u0642\u062f\u064a\u0645 \u0637\u0644\u0628 \u0627\u0644\u0625\u063a\u0644\u0627\u0642', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: (){ S.clear(); Navigator.pushReplacement(c, MaterialPageRoute(builder:(_)=>const LoginScreen())); },
        child: const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.err.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [Icon(Icons.warning, color: AC.err), SizedBox(width: 10),
          Expanded(child: Text('\u0647\u0630\u0627 \u0627\u0644\u0625\u062c\u0631\u0627\u0621 \u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0644\u062a\u0631\u0627\u062c\u0639 \u0639\u0646\u0647 \u0628\u0633\u0647\u0648\u0644\u0629', style: TextStyle(color: AC.err, fontSize: 13)))])),
      const SizedBox(height: 20),
      const Text('\u0646\u0648\u0639 \u0627\u0644\u0625\u063a\u0644\u0627\u0642', style: TextStyle(color: AC.ts, fontSize: 14)),
      const SizedBox(height: 10),
      GestureDetector(onTap: ()=>setState(()=>_type='temporary'),
        child: Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _type=='temporary'?AC.warn.withOpacity(0.1):AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _type=='temporary'?AC.warn:AC.bdr)),
          child: Row(children: [Icon(_type=='temporary'?Icons.radio_button_checked:Icons.radio_button_off,
            color: _type=='temporary'?AC.warn:AC.ts, size: 18), const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\u0645\u0624\u0642\u062a', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
              Text('\u064a\u0645\u0643\u0646\u0643 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062a\u0641\u0639\u064a\u0644 \u0644\u0627\u062d\u0642\u0627\u064b', style: TextStyle(color: AC.ts, fontSize: 11))]))]))),
      GestureDetector(onTap: ()=>setState(()=>_type='permanent'),
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _type=='permanent'?AC.err.withOpacity(0.1):AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _type=='permanent'?AC.err:AC.bdr)),
          child: Row(children: [Icon(_type=='permanent'?Icons.radio_button_checked:Icons.radio_button_off,
            color: _type=='permanent'?AC.err:AC.ts, size: 18), const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\u062f\u0627\u0626\u0645', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
              Text('\u0633\u064a\u062a\u0645 \u062d\u0630\u0641 \u062d\u0633\u0627\u0628\u0643 \u0646\u0647\u0627\u0626\u064a\u0627\u064b', style: TextStyle(color: AC.ts, fontSize: 11))]))]))),
      if(_e!=null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_e!, style: const TextStyle(color: AC.err))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AC.err),
        onPressed: _l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) :
          const Text('\u062a\u0623\u0643\u064a\u062f \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', style: TextStyle(color: Colors.white))))])));
}


// ═══════════════════════════════════════════════════
// ADMIN TAB — Platform Dashboard
// ═══════════════════════════════════════════════════
class AdminTab extends StatefulWidget { const AdminTab({super.key}); @override State<AdminTab> createState()=>_AdminS(); }
class _AdminS extends State<AdminTab> {
  Map<String,dynamic> _stats = {}; List _users = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/admin/stats'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/admin/users'), headers: S.h());
      if(mounted) setState(() {
        try { _stats = jsonDecode(r1.body); } catch(_) {}
        try { _users = jsonDecode(r2.body); } catch(_) { _users = []; }
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0644\u0648\u062d\u0629 \u0627\u0644\u0625\u062f\u0627\u0631\u0629', style: TextStyle(color: AC.gold)),
      actions: [
        IconButton(icon: const Icon(Icons.rate_review, color: AC.cyan),
          onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ReviewerConsoleScreen()))),
        IconButton(icon: const Icon(Icons.verified_user, color: AC.ok),
          onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ProviderVerificationScreen()))),
        IconButton(icon: const Icon(Icons.upload_file, color: AC.gold),
          onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ProviderDocumentUploadScreen()))),
        IconButton(icon: const Icon(Icons.shield, color: AC.gold),
          onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ProviderComplianceScreen()))),
        IconButton(icon: const Icon(Icons.psychology, color: AC.gold),
          onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const KnowledgeDeveloperConsole()))),
        IconButton(icon: const Icon(Icons.security, color: AC.gold),
          onPressed: ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const AuditLogScreen()))),
      ]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: const EdgeInsets.all(14), children: [
        // Stats Grid
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
          children: [
            _statCard('\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u0648\u0646', '${_stats['total_users']??_users.length}', Icons.people, AC.gold),
            _statCard('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', '${_stats['total_clients']??0}', Icons.business, AC.cyan),
            _statCard('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', '${_stats['total_providers']??0}', Icons.work, AC.ok),
            _statCard('\u0627\u0644\u0637\u0644\u0628\u0627\u062a', '${_stats['total_requests']??0}', Icons.assignment, AC.warn),
            _statCard('\u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a', '${_stats['total_feedback']??0}', Icons.feedback, Colors.purple),
            _statCard('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a', '${_stats['total_analyses']??0}', Icons.analytics, Colors.teal),
          ]),
        const SizedBox(height: 16),
        // Quick Actions
        _card('\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0633\u0631\u064a\u0639\u0629', [
          _actionTile('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', Icons.rate_review, AC.cyan,
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ReviewerConsoleScreen()))),
          _actionTile('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.verified_user, AC.ok,
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const ProviderVerificationScreen()))),
          _actionTile('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', Icons.policy, AC.warn,
            ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>const PolicyManagementScreen()))),
        ]),
        const SizedBox(height: 16),
        // Users List
        _card('\u0622\u062e\u0631 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u064a\u0646', [
          if(_users.isEmpty) const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.ts))
          else ..._users.take(10).map((u) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(backgroundColor: AC.navy4, radius: 16,
                child: Text((u['display_name']??u['username']??'?')[0], style: const TextStyle(color: AC.gold, fontSize: 12))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['display_name']??u['username']??'', style: const TextStyle(color: AC.tp, fontSize: 13)),
                Text('${u['email']??''} \u2022 ${u['plan']??'free'}', style: const TextStyle(color: AC.ts, fontSize: 10))])),
              _badge(u['status']??'active', u['status']=='active'?AC.ok:AC.err)])))
        ]),
      ])));

  Widget _statCard(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [Icon(icon, color: color, size: 22), const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 11))]));

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AC.tp, fontSize: 14))),
        const Icon(Icons.chevron_left, color: AC.ts, size: 20)])));
}

// ═══════════════════════════════════════════════════
// REVIEWER CONSOLE — Knowledge Feedback Review
// ═══════════════════════════════════════════════════
class ReviewerConsoleScreen extends StatefulWidget {
  const ReviewerConsoleScreen({super.key});
  @override State<ReviewerConsoleScreen> createState() => _RevCS();
}
class _RevCS extends State<ReviewerConsoleScreen> {
  List _items = []; bool _ld = true; String _filter = 'all';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/admin/knowledge-feedback'), headers: S.h());
      if(mounted) setState(() { try { _items = jsonDecode(r.body); } catch(_) { _items = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _review(String id, String decision) async {
    await http.post(Uri.parse('$_api/admin/knowledge-feedback/$id/review'),
      headers: {'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
      body: jsonEncode({'decision': decision}));
    _load();
  }
  List get _filtered => _filter == 'all' ? _items : _items.where((i) => i['status'] == _filter).toList();
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      Column(children: [
        // Filter chips
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12),
          child: Row(children: ['all','submitted','under_review','accepted','rejected'].map((f) =>
            Padding(padding: const EdgeInsets.only(left: 6), child: FilterChip(
              selected: _filter == f, onSelected: (_) => setState(()=> _filter = f),
              label: Text(f == 'all' ? '\u0627\u0644\u0643\u0644' : f == 'submitted' ? '\u0645\u0642\u062f\u0645\u0629' : f == 'under_review' ? '\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629' : f == 'accepted' ? '\u0645\u0642\u0628\u0648\u0644\u0629' : '\u0645\u0631\u0641\u0648\u0636\u0629',
                style: TextStyle(color: _filter == f ? AC.navy : AC.tp, fontSize: 12)),
              selectedColor: AC.gold, backgroundColor: AC.navy3,
              side: BorderSide(color: _filter == f ? AC.gold : AC.bdr)))).toList())),
        // Items list
        Expanded(child: _filtered.isEmpty ?
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, color: AC.ts, size: 50), const SizedBox(height: 10),
            const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0644\u0627\u062d\u0638\u0627\u062a', style: TextStyle(color: AC.ts))])) :
          RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final item = _filtered[i];
              final status = item['status'] ?? 'submitted';
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(item['title']??'', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14))),
                    _badge(status == 'submitted' ? '\u0645\u0642\u062f\u0645\u0629' : status == 'accepted' ? '\u0645\u0642\u0628\u0648\u0644\u0629' : status == 'rejected' ? '\u0645\u0631\u0641\u0648\u0636\u0629' : status,
                      status == 'accepted' ? AC.ok : status == 'rejected' ? AC.err : AC.warn)]),
                  const SizedBox(height: 6),
                  Text(item['feedback_type']??'', style: const TextStyle(color: AC.cyan, fontSize: 11)),
                  if(item['description']!=null && item['description'].toString().isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(item['description'], style: const TextStyle(color: AC.ts, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)),
                  Text('\u0628\u0648\u0627\u0633\u0637\u0629: ${item['submitted_by_name']??item['submitted_by']??''}', style: const TextStyle(color: AC.ts, fontSize: 10)),
                  if(status == 'submitted') ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: const EdgeInsets.symmetric(vertical: 8)),
                        onPressed: ()=> _review(item['id']??item['feedback_id']??'', 'accepted'),
                        icon: const Icon(Icons.check, size: 16), label: const Text('\u0642\u0628\u0648\u0644', style: TextStyle(fontSize: 12)))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AC.err, padding: const EdgeInsets.symmetric(vertical: 8)),
                        onPressed: ()=> _review(item['id']??item['feedback_id']??'', 'rejected'),
                        icon: const Icon(Icons.close, size: 16), label: const Text('\u0631\u0641\u0636', style: TextStyle(fontSize: 12)))),
                    ])],
                ]));
            })))
      ]));
}

// ═══════════════════════════════════════════════════
// PROVIDER VERIFICATION QUEUE
// ═══════════════════════════════════════════════════
class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({super.key});
  @override State<ProviderVerificationScreen> createState() => _PVS();
}
class _PVS extends State<ProviderVerificationScreen> {
  List _provs = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/admin/providers'), headers: S.h());
      if(mounted) setState(() { try { _provs = jsonDecode(r.body); } catch(_) { _provs = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _action(String id, String action) async {
    await http.post(Uri.parse('$_api/admin/providers/$id/$action'), headers: S.h());
    _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _provs.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.verified_user_outlined, color: AC.ts, size: 50), const SizedBox(height: 10),
        const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u062a\u062d\u0642\u0642', style: TextStyle(color: AC.ts))])) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: _provs.length,
        itemBuilder: (_, i) {
          final p = _provs[i];
          final vStatus = p['verification_status'] ?? 'pending';
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: AC.navy4, radius: 20,
                  child: Text((p['display_name']??p['username']??'?')[0], style: const TextStyle(color: AC.gold, fontSize: 16))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['display_name']??p['username']??'', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(p['category']??'', style: const TextStyle(color: AC.cyan, fontSize: 11))])),
                _badge(vStatus == 'approved' ? '\u0645\u0639\u062a\u0645\u062f' : vStatus == 'pending' ? '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631' : vStatus,
                  vStatus == 'approved' ? AC.ok : vStatus == 'rejected' ? AC.err : AC.warn)]),
              if(p['service_scopes']!=null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: (p['service_scopes'] as List).map((s) =>
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(s['name_ar']??s['code']??'', style: const TextStyle(color: AC.cyan, fontSize: 10)))).toList())],
              if(p['required_documents']!=null) ...[
                const SizedBox(height: 6),
                Text('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a: ${(p['required_documents'] as List).join(", ")}', style: const TextStyle(color: AC.ts, fontSize: 10))],
              if(vStatus == 'pending') ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: ()=> _action(p['provider_id']??p['id']??'', 'approve'),
                    icon: const Icon(Icons.check, size: 16), label: const Text('\u0627\u0639\u062a\u0645\u0627\u062f', style: TextStyle(fontSize: 12)))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AC.err, padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: ()=> _action(p['provider_id']??p['id']??'', 'reject'),
                    icon: const Icon(Icons.close, size: 16), label: const Text('\u0631\u0641\u0636', style: TextStyle(fontSize: 12)))),
                ])],
            ]));
        })));
}

// ═══════════════════════════════════════════════════
// POLICY MANAGEMENT
// ═══════════════════════════════════════════════════
class PolicyManagementScreen extends StatefulWidget {
  const PolicyManagementScreen({super.key});
  @override State<PolicyManagementScreen> createState() => _PMS();
}
class _PMS extends State<PolicyManagementScreen> {
  List _policies = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/legal/policies'), headers: S.h());
      if(mounted) setState(() { try { _policies = jsonDecode(r.body); } catch(_) { _policies = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _policies.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.policy_outlined, color: AC.ts, size: 50), const SizedBox(height: 10),
        const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.ts))])) :
      ListView.builder(padding: const EdgeInsets.all(14), itemCount: _policies.length,
        itemBuilder: (_, i) {
          final p = _policies[i];
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_policyIcon(p['policy_type']??''), color: AC.gold, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['title_ar']??p['title']??p['policy_type']??'', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('\u0627\u0644\u0625\u0635\u062f\u0627\u0631: ${p['version']??'1.0'}', style: const TextStyle(color: AC.ts, fontSize: 11))])),
                _badge(p['is_active']==true?'\u0641\u0639\u0627\u0644':'\u063a\u064a\u0631 \u0641\u0639\u0627\u0644', p['is_active']==true?AC.ok:AC.ts)]),
              if(p['summary_ar']!=null || p['content_preview']!=null) ...[
                const SizedBox(height: 8),
                Text(p['summary_ar']??p['content_preview']??'', style: const TextStyle(color: AC.ts, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)],
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today, color: AC.ts, size: 12), const SizedBox(width: 4),
                Text(p['effective_date']?.toString().substring(0,10)??p['created_at']?.toString().substring(0,10)??'', style: const TextStyle(color: AC.ts, fontSize: 10)),
                const Spacer(),
                if(p['acceptance_count']!=null) Text('\u0645\u0648\u0627\u0641\u0642\u0627\u062a: ${p['acceptance_count']}', style: const TextStyle(color: AC.ts, fontSize: 10)),
              ]),
            ]));
        }));

  IconData _policyIcon(String t) {
    if(t.contains('terms')) return Icons.description;
    if(t.contains('privacy')) return Icons.privacy_tip;
    if(t.contains('provider')) return Icons.work;
    if(t.contains('acceptable')) return Icons.rule;
    return Icons.policy;
  }
}


// ============================================================
// Legal Acceptance Screen (Execution Master §15)
// ============================================================
class LegalAcceptanceScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const LegalAcceptanceScreen({Key? key, required this.onAccepted}) : super(key: key);
  @override State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _usageAccepted = false;
  bool _loading = false;

  bool get _allAccepted => _termsAccepted && _privacyAccepted && _usageAccepted;

  Future<void> _submit() async {
    if (!_allAccepted) return;
    setState(() => _loading = true);
    try {
      await http.post(Uri.parse('https://apex-api-ootk.onrender.com/legal/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'document_type': 'terms', 'version': '1.0'}));
      await http.post(Uri.parse('https://apex-api-ootk.onrender.com/legal/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'document_type': 'privacy', 'version': '1.0'}));
      await http.post(Uri.parse('https://apex-api-ootk.onrender.com/legal/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'document_type': 'acceptable_use', 'version': '1.0'}));
      widget.onAccepted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('الشروط والأحكام'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFF856404)),
              const SizedBox(width: 12),
              const Expanded(child: Text('يجب الموافقة على جميع الشروط والسياسات قبل إكمال التسجيل',
                style: TextStyle(color: Color(0xFF856404), fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 24),

          _buildPolicyCard('شروط وأحكام المنصة', 'الإصدار 1.0',
            'تتضمن شروط استخدام المنصة والتزامات المستخدم وحقوق المنصة في تعليق الحسابات عند المخالفة.',
            Icons.description, _termsAccepted, (v) => setState(() => _termsAccepted = v!)),

          _buildPolicyCard('سياسة الخصوصية', 'الإصدار 1.0',
            'كيفية جمع واستخدام وحماية بياناتك الشخصية والمالية.',
            Icons.privacy_tip, _privacyAccepted, (v) => setState(() => _privacyAccepted = v!)),

          _buildPolicyCard('سياسة الاستخدام المقبول', 'الإصدار 1.0',
            'القواعد المنظمة لاستخدام المنصة بما يشمل رفع الملفات والتحليلات وطلب الخدمات.',
            Icons.verified_user, _usageAccepted, (v) => setState(() => _usageAccepted = v!)),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _allAccepted && !_loading ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _allAccepted ? AC.gold : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('أوافق وأتابع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  Widget _buildPolicyCard(String title, String version, String desc, IconData icon, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? AC.gold : const Color(0xFFE0E0E0), width: value ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AC.navy, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B2A4A))),
            Text(version, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Checkbox(value: value, onChanged: onChanged, activeColor: AC.gold),
          const Text('أوافق على هذه السياسة', style: TextStyle(fontSize: 13)),
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('قراءة كاملة', style: TextStyle(color: Color(0xFF1B2A4A)))),
        ]),
      ]),
    );
  }
}

// ============================================================
// Client Type Selection Screen (Execution Master §5)
// ============================================================
class ClientTypeSelectionScreen extends StatefulWidget {
  final Function(String) onSelected;
  const ClientTypeSelectionScreen({Key? key, required this.onSelected}) : super(key: key);
  @override State<ClientTypeSelectionScreen> createState() => _ClientTypeSelectionScreenState();
}

class _ClientTypeSelectionScreenState extends State<ClientTypeSelectionScreen> {
  String? _selected;

  final _types = [
    {'id': 'standard_business', 'name': 'منشأة تجارية', 'icon': Icons.business, 'km': false,
     'desc': 'شركة أو مؤسسة تجارية تستخدم خدمات التحليل'},
    {'id': 'accounting_firm', 'name': 'مكتب محاسبة', 'icon': Icons.calculate, 'km': true,
     'desc': 'مكتب محاسبة قانوني معتمد'},
    {'id': 'audit_firm', 'name': 'مكتب تدقيق', 'icon': Icons.fact_check, 'km': true,
     'desc': 'مكتب تدقيق ومراجعة'},
    {'id': 'financial_entity', 'name': 'جهة مالية', 'icon': Icons.account_balance, 'km': true,
     'desc': 'بنك أو مؤسسة مالية'},
    {'id': 'investment_entity', 'name': 'جهة استثمارية', 'icon': Icons.trending_up, 'km': true,
     'desc': 'شركة أو صندوق استثماري'},
    {'id': 'government_entity', 'name': 'جهة حكومية', 'icon': Icons.account_balance_wallet, 'km': true,
     'desc': 'جهة حكومية أو شبه حكومية'},
    {'id': 'legal_regulatory_entity', 'name': 'جهة قانونية/تنظيمية', 'icon': Icons.gavel, 'km': true,
     'desc': 'هيئة تنظيمية أو مكتب قانوني'},
    {'id': 'sector_consulting_entity', 'name': 'استشارات قطاعية', 'icon': Icons.lightbulb, 'km': true,
     'desc': 'شركة استشارات متخصصة'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('اختيار نوع العميل'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16), color: const Color(0xFFF0F4FF),
          child: const Text('اختر نوع المنشأة — هذا يحدد الخدمات والصلاحيات المتاحة',
            style: TextStyle(color: Color(0xFF1B2A4A), fontSize: 13), textAlign: TextAlign.center),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _types.length,
            itemBuilder: (ctx, i) {
              final t = _types[i];
              final selected = _selected == t['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AC.gold : const Color(0xFFE0E0E0), width: selected ? 2 : 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: selected ? AC.gold.withOpacity(0.15) : const Color(0xFFF5F5F5),
                    child: Icon(t['icon'] as IconData, color: selected ? AC.gold : AC.navy, size: 24),
                  ),
                  title: Text(t['name'] as String, style: TextStyle(
                    fontWeight: FontWeight.bold, color: selected ? AC.navy : Colors.black87)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Text(t['desc'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (t['km'] == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                        child: const Text('مؤهل للعقل المعرفي', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32))),
                      ),
                    ],
                  ]),
                  trailing: selected
                    ? const Icon(Icons.check_circle, color: Color(0xFFD4A843))
                    : const Icon(Icons.radio_button_unchecked, color: Color(0xFFBDBDBD)),
                  onTap: () => setState(() => _selected = t['id'] as String),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _selected != null ? () => widget.onSelected(_selected!) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selected != null ? AC.gold : Colors.grey,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد واستمرار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Provider Document Upload Screen (Execution Master §7)
// ============================================================
class ProviderDocumentUploadScreen extends StatefulWidget {
  const ProviderDocumentUploadScreen({Key? key}) : super(key: key);
  @override State<ProviderDocumentUploadScreen> createState() => _ProviderDocumentUploadScreenState();
}

class _ProviderDocumentUploadScreenState extends State<ProviderDocumentUploadScreen> {
  final _docs = [
    {'type': 'identity', 'name': 'إثبات الهوية', 'icon': Icons.badge, 'required': true, 'uploaded': false},
    {'type': 'professional_license', 'name': 'الرخصة المهنية', 'icon': Icons.card_membership, 'required': true, 'uploaded': false},
    {'type': 'academic_certificate', 'name': 'الشهادة الأكاديمية', 'icon': Icons.school, 'required': true, 'uploaded': false},
    {'type': 'experience_letter', 'name': 'خطاب الخبرة', 'icon': Icons.work_history, 'required': false, 'uploaded': false},
    {'type': 'portfolio', 'name': 'نماذج أعمال', 'icon': Icons.folder_special, 'required': false, 'uploaded': false},
  ];

  @override
  Widget build(BuildContext context) {
    final requiredCount = _docs.where((d) => d['required'] == true).length;
    final uploadedRequired = _docs.where((d) => d['required'] == true && d['uploaded'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('مستندات التحقق'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          color: uploadedRequired == requiredCount ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3CD),
          child: Row(children: [
            Icon(uploadedRequired == requiredCount ? Icons.check_circle : Icons.warning,
              color: uploadedRequired == requiredCount ? const Color(0xFF2E7D32) : const Color(0xFF856404)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              uploadedRequired == requiredCount
                ? 'جميع المستندات الإلزامية مرفوعة — في انتظار المراجعة'
                : 'يجب رفع المستندات الإلزامية (*) للتحقق وتفعيل حسابك',
              style: TextStyle(fontSize: 13, color: uploadedRequired == requiredCount ? const Color(0xFF2E7D32) : const Color(0xFF856404)))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _docs.length,
            itemBuilder: (ctx, i) {
              final doc = _docs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : const Color(0xFFE0E0E0)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: doc['uploaded'] == true ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                    child: Icon(doc['icon'] as IconData,
                      color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : AC.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(doc['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (doc['required'] == true) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ]),
                    Text(doc['uploaded'] == true ? 'تم الرفع — قيد المراجعة' : 'لم يتم الرفع',
                      style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : Colors.grey)),
                  ])),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _docs[i] = {...doc, 'uploaded': true}),
                    icon: Icon(doc['uploaded'] == true ? Icons.refresh : Icons.upload_file, size: 16),
                    label: Text(doc['uploaded'] == true ? 'تحديث' : 'رفع', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doc['uploaded'] == true ? Colors.grey[200] : AC.navy,
                      foregroundColor: doc['uploaded'] == true ? Colors.black87 : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: uploadedRequired == requiredCount ? () => Navigator.pop(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: uploadedRequired == requiredCount ? AC.gold : Colors.grey,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(uploadedRequired == requiredCount ? 'إرسال للمراجعة' : 'أكمل رفع المستندات الإلزامية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Task Document Management Screen (Zero Ambiguity §9)
// ============================================================
class TaskDocumentScreen extends StatefulWidget {
  final String requestId;
  final String taskType;
  const TaskDocumentScreen({Key? key, required this.requestId, this.taskType = 'bookkeeping'}) : super(key: key);
  @override State<TaskDocumentScreen> createState() => _TaskDocumentScreenState();
}

class _TaskDocumentScreenState extends State<TaskDocumentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _inputs = [
    {'name': 'مصادر القيود', 'uploaded': true, 'date': '2026-03-28'},
    {'name': 'كشف حساب بنكي', 'uploaded': true, 'date': '2026-03-29'},
    {'name': 'فواتير', 'uploaded': false, 'date': null},
  ];
  final _outputs = [
    {'name': 'ملف قيود منظم', 'uploaded': false, 'date': null},
    {'name': 'ملاحظات التسوية', 'uploaded': false, 'date': null},
  ];

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inputsDone = _inputs.where((d) => d['uploaded'] == true).length;
    final outputsDone = _outputs.where((d) => d['uploaded'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('مستندات المهمة'),
        backgroundColor: AC.navy, foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabs, indicatorColor: AC.gold, labelColor: Colors.white, tabs: [
          Tab(text: 'المدخلات ($inputsDone/${_inputs.length})'),
          Tab(text: 'المخرجات ($outputsDone/${_outputs.length})'),
        ]),
      ),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          color: inputsDone == _inputs.length && outputsDone == _outputs.length
            ? const Color(0xFFE8F5E9) : const Color(0xFFFCE4EC),
          child: Row(children: [
            const Icon(Icons.timer, size: 16, color: Color(0xFFD32F2F)),
            const SizedBox(width: 8),
            const Text('الموعد النهائي: 15 أبريل 2026', style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: inputsDone == _inputs.length ? const Color(0xFF2ECC8A) : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(8)),
              child: Text(inputsDone == _inputs.length ? 'مكتمل' : 'ناقص',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _buildDocList(_inputs, 'input'),
            _buildDocList(_outputs, 'output'),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDocList(List<Map<String, dynamic>> docs, String category) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : const Color(0xFFFFCDD2)),
          ),
          child: Row(children: [
            Icon(doc['uploaded'] == true ? Icons.check_circle : Icons.error_outline,
              color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : const Color(0xFFD32F2F)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(doc['uploaded'] == true ? 'تم الرفع: ${doc['date']}' : 'مطلوب — لم يتم الرفع',
                style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? Colors.green : Colors.red)),
            ])),
            if (doc['uploaded'] != true)
              ElevatedButton.icon(
                onPressed: () => setState(() => docs[i] = {...doc, 'uploaded': true, 'date': '2026-03-30'}),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('رفع'),
                style: ElevatedButton.styleFrom(backgroundColor: AC.navy, foregroundColor: Colors.white),
              ),
          ]),
        );
      },
    );
  }
}

// ============================================================
// Provider Compliance Status Screen (Zero Ambiguity §9)
// ============================================================
class ProviderComplianceScreen extends StatelessWidget {
  const ProviderComplianceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('حالة الامتثال'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B2A4A), Color(0xFF2C3E6B)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Icon(Icons.verified, color: Color(0xFF2ECC8A), size: 48),
              const SizedBox(height: 12),
              const Text('حالة الحساب: نشط', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF2ECC8A), borderRadius: BorderRadius.circular(20)),
                child: const Text('لا توجد مخالفات', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Compliance Metrics
          const Text('مؤشرات الامتثال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _metricCard('المهام المكتملة', '12', Icons.task_alt, const Color(0xFF2ECC8A)),
          _metricCard('المستندات المرفوعة', '8/8', Icons.description, const Color(0xFF2ECC8A)),
          _metricCard('المخالفات', '0', Icons.warning, const Color(0xFF2ECC8A)),
          _metricCard('التعليقات السابقة', '0', Icons.block, const Color(0xFF2ECC8A)),
          _metricCard('تقييم الأداء', '4.8/5', Icons.star, const Color(0xFFD4A843)),

          const SizedBox(height: 20),
          const Text('سجل الامتثال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Icon(Icons.check_circle, color: Color(0xFF2ECC8A), size: 40),
              const SizedBox(height: 8),
              const Text('سجل نظيف', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const Text('لا توجد مخالفات أو تعليقات سابقة', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ]),
    );
  }
}

// ============================================================
// Activity History Screen (Execution Master §9)
// ============================================================
class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activities = [
      {'action': 'تحليل مالي', 'detail': 'رفع ميزان مراجعة - retail', 'time': 'اليوم 11:30', 'icon': Icons.analytics, 'color': const Color(0xFF1B2A4A)},
      {'action': 'تحميل تقرير PDF', 'detail': 'تقرير التحليل المالي', 'time': 'اليوم 11:45', 'icon': Icons.picture_as_pdf, 'color': const Color(0xFF2ECC8A)},
      {'action': 'إنشاء عميل', 'detail': 'شركة التقنية المتقدمة', 'time': 'أمس 14:00', 'icon': Icons.person_add, 'color': const Color(0xFFD4A843)},
      {'action': 'طلب خدمة', 'detail': 'مسك دفاتر - شهري', 'time': 'أمس 15:30', 'icon': Icons.shopping_cart, 'color': const Color(0xFF9C27B0)},
      {'action': 'ملاحظة معرفية', 'detail': 'تحسين تبويب الإيرادات', 'time': '28 مارس', 'icon': Icons.lightbulb, 'color': const Color(0xFFFF9800)},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('سجل النشاط'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        itemBuilder: (ctx, i) {
          final a = activities[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: (a['color'] as Color).withOpacity(0.1),
                radius: 20,
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['action'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(a['detail'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])),
              Text(a['time'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          );
        },
      ),
    );
  }
}




// ═══════════════════════════════════════════════════════
// Result Detail Panel — ! icon explanation (Execution §6)
// ═══════════════════════════════════════════════════════
class ResultDetailPanel extends StatefulWidget {
  final String analysisId;
  final String resultKey;
  const ResultDetailPanel({super.key, required this.analysisId, required this.resultKey});
  @override State<ResultDetailPanel> createState() => _ResultDetailPanelS();
}
class _ResultDetailPanelS extends State<ResultDetailPanel> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/results/${widget.analysisId}/details'),
        headers: S.h());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final details = data['details'] as List? ?? [];
        for (var d in details) {
          if (d['result_key'] == widget.resultKey) {
            setState(() { _detail = d; _loading = false; });
            return;
          }
        }
      }
      setState(() => _loading = false);
    } catch (e) { setState(() => _loading = false); }
  }
  
  @override Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(12)),
    child: _loading 
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _detail == null 
        ? const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0641\u0627\u0635\u064a\u0644 \u0645\u062a\u0627\u062d\u0629', style: TextStyle(color: AC.tp))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.info_outline, color: AC.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_detail!['summary_ar'] ?? _detail!['result_key'] ?? '',
                style: const TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 12),
            if (_detail!['source_rows'] != null) ...[
              const Text('\u0627\u0644\u0635\u0641\u0648\u0641 \u0627\u0644\u0645\u0635\u062f\u0631\u064a\u0629:', style: TextStyle(color: AC.cyan, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_detail!['source_rows'], style: const TextStyle(color: AC.tp, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            if (_detail!['applied_rules'] != null) ...[
              const Text('\u0627\u0644\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0645\u0637\u0628\u0642\u0629:', style: TextStyle(color: AC.cyan, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_detail!['applied_rules'], style: const TextStyle(color: AC.tp, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            Row(children: [
              _chip('\u0627\u0644\u062b\u0642\u0629: ${((_detail!['confidence'] ?? 0) * 100).toStringAsFixed(0)}%', AC.ok),
              const SizedBox(width: 8),
              if (_detail!['feedback_count'] != null && _detail!['feedback_count'] > 0)
                _chip('\u0645\u0644\u0627\u062d\u0638\u0627\u062a: ${_detail!['feedback_count']}', AC.cyan),
            ]),
            if (_detail!['warnings'] != null) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: const Color(0x33F39C12), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFF39C12), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_detail!['warnings'], style: const TextStyle(color: Color(0xFFF39C12), fontSize: 12))),
                ])),
            ],
          ]),
  );
  
  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
    child: Text(t, style: TextStyle(color: c, fontSize: 11)));
}

// Result Detail Dialog — triggered by ! icon
void showResultDetail(BuildContext context, String analysisId, String resultKey) {
  showModalBottomSheet(
    context: context, backgroundColor: AC.navy2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (c) => Padding(
      padding: const EdgeInsets.all(16),
      child: ResultDetailPanel(analysisId: analysisId, resultKey: resultKey),
    ),
  );
}


// ═══════════════════════════════════════════════════════
// Task Document Management (Execution §8)
// ═══════════════════════════════════════════════════════
class TaskDocumentManagementScreen extends StatefulWidget {
  final String taskId;
  final String taskTypeCode;
  const TaskDocumentManagementScreen({super.key, required this.taskId, required this.taskTypeCode});
  @override State<TaskDocumentManagementScreen> createState() => _TaskDocMgmtS();
}
class _TaskDocMgmtS extends State<TaskDocumentManagementScreen> {
  Map<String, dynamic>? _taskType;
  List<dynamic> _submissions = [];
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load task type requirements
      final r1 = await http.get(Uri.parse('$_api/task-types/${widget.taskTypeCode}'));
      if (r1.statusCode == 200) _taskType = jsonDecode(r1.body);
      
      // Load existing submissions
      final r2 = await http.get(Uri.parse('$_api/task-submissions/${widget.taskId}'),
        headers: S.h());
      if (r2.statusCode == 200) _submissions = jsonDecode(r2.body);
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  bool _isUploaded(String reqId) => _submissions.any((s) => s['requirement_id'] == reqId && s['status'] == 'uploaded');
  
  Future<void> _upload(String reqId, String docName) async {
    // Simulate upload — in production, use file picker
    try {
      final r = await http.post(Uri.parse('$_api/task-submissions'),
        headers: {...S.h(), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_task_id': widget.taskId,
          'requirement_id': reqId,
          'file_name': '$docName.pdf',
        }));
      if (r.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u062a\u0645 \u0631\u0641\u0639 $docName'), backgroundColor: const Color(0xFF2ECC8A)));
        _load();
      }
    } catch (e) { /* handle */ }
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0645\u0647\u0645\u0629', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold)),
    body: _loading 
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _taskType == null
        ? const Center(child: Text('\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0646\u0648\u0639 \u0627\u0644\u0645\u0647\u0645\u0629', style: TextStyle(color: AC.tp)))
        : ListView(padding: const EdgeInsets.all(16), children: [
            // Task type header
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
              color: AC.navy2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_taskType!['name_ar'] ?? '', style: const TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_taskType!['code'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 12)),
              ])),
            const SizedBox(height: 16),
            
            // Input Requirements
            const Text('\u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: AC.cyan, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_taskType!['input_requirements'] as List? ?? []).map((req) => _docTile(req, true)),
            
            const SizedBox(height: 20),
            
            // Output Requirements
            const Text('\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: Color(0xFFF39C12), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_taskType!['output_requirements'] as List? ?? []).map((req) => _docTile(req, false)),
            
            const SizedBox(height: 20),
            
            // Progress
            _progressCard(),
          ]),
  );
  
  Widget _docTile(dynamic req, bool isInput) {
    final uploaded = _isUploaded(req['id']);
    final mandatory = req['is_mandatory'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy3, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: uploaded ? const Color(0xFF2ECC8A) : (mandatory ? const Color(0x33F39C12) : AC.navy4))),
      child: Row(children: [
        Icon(uploaded ? Icons.check_circle : (isInput ? Icons.upload_file : Icons.download),
          color: uploaded ? const Color(0xFF2ECC8A) : AC.gold, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(req['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 14)),
          if (mandatory) const Text('* \u0625\u0644\u0632\u0627\u0645\u064a', style: TextStyle(color: Color(0xFFF39C12), fontSize: 11)),
        ])),
        if (!uploaded)
          ElevatedButton(onPressed: () => _upload(req['id'], req['name_ar'] ?? 'doc'),
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('\u0631\u0641\u0639', style: TextStyle(fontSize: 12)))
        else
          const Text('\u2713 \u062a\u0645', style: TextStyle(color: Color(0xFF2ECC8A), fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
  
  Widget _progressCard() {
    final totalInputs = (_taskType!['input_requirements'] as List? ?? []).where((r) => r['is_mandatory'] == true).length;
    final totalOutputs = (_taskType!['output_requirements'] as List? ?? []).where((r) => r['is_mandatory'] == true).length;
    final uploadedInputs = (_taskType!['input_requirements'] as List? ?? []).where((r) => _isUploaded(r['id']) && r['is_mandatory'] == true).length;
    final uploadedOutputs = (_taskType!['output_requirements'] as List? ?? []).where((r) => _isUploaded(r['id']) && r['is_mandatory'] == true).length;
    final total = totalInputs + totalOutputs;
    final done = uploadedInputs + uploadedOutputs;
    final progress = total > 0 ? done / total : 0.0;
    
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
      color: AC.navy2, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('\u0627\u0644\u062a\u0642\u062f\u0645: $done / $total \u0645\u0633\u062a\u0646\u062f \u0625\u0644\u0632\u0627\u0645\u064a',
          style: const TextStyle(color: AC.tp, fontSize: 14)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, backgroundColor: AC.navy4,
          valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? const Color(0xFF2ECC8A) : AC.gold)),
        const SizedBox(height: 8),
        if (progress >= 1.0)
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('\u062c\u0645\u064a\u0639 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0645\u0643\u062a\u0645\u0644\u0629'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC8A), foregroundColor: Colors.white)),
      ]));
  }
}


// ═══════════════════════════════════════════════════════
// Task Types Browser (shows all task types + requirements)
// ═══════════════════════════════════════════════════════
class TaskTypesBrowserScreen extends StatefulWidget {
  const TaskTypesBrowserScreen({super.key});
  @override State<TaskTypesBrowserScreen> createState() => _TaskTypesBrowserS();
}
class _TaskTypesBrowserS extends State<TaskTypesBrowserScreen> {
  List<dynamic> _types = [];
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/task-types'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data is List) { _types = data; }
        else if (data is Map && data['task_types'] != null) { _types = data['task_types']; }
        else { _types = []; }
      }
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('\u0623\u0646\u0648\u0627\u0639 \u0627\u0644\u0645\u0647\u0627\u0645', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold)),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _types.length,
          itemBuilder: (c, i) {
            final tt = _types[i];
            final inputs = tt['input_requirements'] ?? tt['input_documents'] ?? [] as List? ?? [];
            final outputs = tt['output_requirements'] ?? tt['output_documents'] ?? [] as List? ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                iconColor: AC.gold, collapsedIconColor: AC.ts,
                title: Text(tt['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                subtitle: Text('${inputs.length} \u0645\u062f\u062e\u0644 \u2022 ${outputs.length} \u0645\u062e\u0631\u062c', style: const TextStyle(color: AC.ts, fontSize: 12)),
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (inputs.isNotEmpty) ...[
                      const Text('\u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a:', style: TextStyle(color: AC.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
                      ...inputs.map((r) => Padding(padding: const EdgeInsets.only(right: 16, top: 4),
                        child: Row(children: [
                          Icon(r['is_mandatory'] == true ? Icons.star : Icons.star_border, size: 14,
                            color: r['is_mandatory'] == true ? const Color(0xFFF39C12) : AC.ts),
                          const SizedBox(width: 6),
                          Text(r['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13)),
                        ]))),
                    ],
                    if (outputs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a:', style: TextStyle(color: Color(0xFFF39C12), fontSize: 13, fontWeight: FontWeight.bold)),
                      ...outputs.map((r) => Padding(padding: const EdgeInsets.only(right: 16, top: 4),
                        child: Row(children: [
                          Icon(r['is_mandatory'] == true ? Icons.star : Icons.star_border, size: 14,
                            color: r['is_mandatory'] == true ? const Color(0xFFF39C12) : AC.ts),
                          const SizedBox(width: 6),
                          Text(r['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13)),
                        ]))),
                    ],
                  ])),
                ],
              ),
            );
          }),
  );
}


// ═══════════════════════════════════════════════════════
// Knowledge Developer Console (Zero-Ambiguity §8)
// ═══════════════════════════════════════════════════════
class KnowledgeDeveloperConsole extends StatefulWidget {
  const KnowledgeDeveloperConsole({super.key});
  @override State<KnowledgeDeveloperConsole> createState() => _KnowledgeDevConsoleS();
}
class _KnowledgeDevConsoleS extends State<KnowledgeDeveloperConsole> {
  List<dynamic> _feedbacks = [];
  bool _loading = true;
  String _filter = 'all';
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      String url = '$_api/knowledge-feedback/review-queue?status=$_filter';
      if (_filter == 'all') url = '$_api/knowledge-feedback/review-queue';
      final r = await http.get(Uri.parse(url), headers: S.h());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        _feedbacks = data is List ? data : (data['items'] ?? []);
      }
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: const Text('\u0648\u062d\u062f\u0629 \u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: AC.gold),
          onSelected: (v) { _filter = v; _load(); },
          itemBuilder: (c) => [
            const PopupMenuItem(value: 'all', child: Text('\u0627\u0644\u0643\u0644')),
            const PopupMenuItem(value: 'submitted', child: Text('\u0645\u0631\u0633\u0644\u0629')),
            const PopupMenuItem(value: 'under_review', child: Text('\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629')),
            const PopupMenuItem(value: 'accepted', child: Text('\u0645\u0642\u0628\u0648\u0644\u0629')),
            const PopupMenuItem(value: 'rejected', child: Text('\u0645\u0631\u0641\u0648\u0636\u0629')),
          ],
        ),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _feedbacks.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.psychology, color: AC.ts, size: 64),
            const SizedBox(height: 16),
            const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.ts, fontSize: 16)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _feedbacks.length,
            itemBuilder: (c, i) {
              final fb = _feedbacks[i];
              final status = fb['status'] ?? 'submitted';
              final statusColor = status == 'accepted' ? const Color(0xFF2ECC8A)
                : status == 'rejected' ? const Color(0xFFE74C3C) 
                : status == 'under_review' ? AC.cyan : AC.ts;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(12),
                  border: Border(right: BorderSide(color: statusColor, width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(fb['feedback_type'] ?? '\u0645\u0644\u0627\u062d\u0638\u0629',
                      style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 11))),
                  ]),
                  const SizedBox(height: 8),
                  Text(fb['content'] ?? fb['description'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(fb['created_at'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 11)),
                ]),
              );
            }),
  );
}


// ═══════════════════════════════════════════════════════
// Audit Log Screen (Zero-Ambiguity §3)
// ═══════════════════════════════════════════════════════
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override State<AuditLogScreen> createState() => _AuditLogS();
}
class _AuditLogS extends State<AuditLogScreen> {
  List<dynamic> _events = [];
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/audit/events?limit=100'), headers: S.h());
      if (r.statusCode == 200) _events = jsonDecode(r.body);
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  IconData _actionIcon(String action) {
    if (action.contains('upload')) return Icons.upload_file;
    if (action.contains('login')) return Icons.login;
    if (action.contains('suspend')) return Icons.block;
    if (action.contains('compliance')) return Icons.gavel;
    if (action.contains('promote')) return Icons.arrow_upward;
    return Icons.event_note;
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('\u0633\u062c\u0644 \u0627\u0644\u062a\u062f\u0642\u064a\u0642', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold)),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _events.isEmpty
        ? const Center(child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u062d\u062f\u0627\u062b', style: TextStyle(color: AC.ts)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _events.length,
            itemBuilder: (c, i) {
              final e = _events[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(_actionIcon(e['action'] ?? ''), color: AC.cyan, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['action'] ?? '', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (e['details'] != null) Text(e['details'], style: const TextStyle(color: AC.ts, fontSize: 12), maxLines: 2),
                    Text(e['created_at'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 10)),
                  ])),
                ]),
              );
            }),
  );
}


// ═══════════════════════════════════════════════════════════
// SubscriptionScreen — عرض الخطة الحالية + الترقية
// Per Execution Master §4, §9 + Zero Ambiguity §5, §6
// ═══════════════════════════════════════════════════════════
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}
class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _sub;
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = S.token ?? '';
      final h = {'Authorization': 'Bearer $token'};
      
      // Load current subscription
      final r1 = await http.get(Uri.parse('$_api/subscriptions/me'), headers: {'Authorization': 'Bearer $token'});
      if (r1.statusCode == 200) {
        _sub = jsonDecode(r1.body);
      }
      
      // Load available plans
      final r2 = await http.get(Uri.parse('$_api/subscriptions/plans'));
      if (r2.statusCode == 200) {
        _plans = jsonDecode(r2.body)['plans'] ?? [];
      }
    } catch (e) {
      _error = e.toString();
    }
    setState(() { _loading = false; });
  }

  Future<void> _upgrade(String planName) async {
    final token = S.token ?? '';
    final r = await http.post(
      Uri.parse('$_api/subscriptions/upgrade?plan_name=$planName'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم الترقية إلى $planName بنجاح!'), backgroundColor: AC.ok));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الترقية: ${r.body}'), backgroundColor: AC.err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _sub?['subscription']?['plan_name'] ?? 'Free';
    final features = _sub?['plan_features'] as List<dynamic>? ?? [];
    
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('خطتي والاشتراك'), backgroundColor: const Color(0xFF1E1E2E),
        iconTheme: const IconThemeData(color: AC.gold)),
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AC.err)))
          : RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: const EdgeInsets.all(16), children: [
              // Current Plan Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AC.gold.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.workspace_premium, color: AC.gold, size: 32),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الخطة الحالية', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(currentPlan, style: const TextStyle(color: AC.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text('الميزات المتاحة:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...features.map<Widget>((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Icon(f['is_available'] == true ? Icons.check_circle : Icons.cancel,
                        color: f['is_available'] == true ? AC.ok : AC.err, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f['name_ar'] ?? f['key'], 
                        style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Text(f['display_value'] ?? f['value'], 
                        style: TextStyle(color: f['is_available'] == true ? AC.ok : Colors.grey, fontSize: 12)),
                    ]),
                  )),
                ]),
              ),
              
              const SizedBox(height: 24),
              const Text('ترقية خطتك', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // Available Plans
              ..._plans.map<Widget>((plan) {
                final name = plan['name'];
                final isCurrent = name == currentPlan;
                final price = plan['pricing']?['monthly'] ?? 0;
                final featureCount = plan['feature_count'] ?? 0;
                final note = plan['pricing']?['note'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrent ? AC.gold.withOpacity(0.1) : const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? AC.gold : Colors.white12),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(name, style: TextStyle(
                          color: isCurrent ? AC.gold : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(8)),
                            child: const Text('الحالية', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(price > 0 ? '$price ر.س/شهرياً' : (note ?? 'مجاني'),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('$featureCount ميزة متاحة', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ])),
                    if (!isCurrent)
                      ElevatedButton(
                        onPressed: () => _upgrade(name),
                        style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: Colors.black),
                        child: Text(name == 'Enterprise' ? 'تواصل معنا' : 'ترقية'),
                      ),
                  ]),
                );
              }),
            ])),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// EntitlementGateWidget — يغلق الميزات حسب الخطة
// ═══════════════════════════════════════════════════════════
class EntitlementGate extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? lockedWidget;
  
  const EntitlementGate({super.key, required this.feature, required this.child, this.lockedWidget});
  
  @override
  Widget build(BuildContext context) {
    // This would check entitlements from cached user data
    // For now, show child always — entitlement check happens on API side
    return child;
  }
}

// ═══════════════════════════════════════════════════════════
// PlanComparisonScreen — مقارنة الخطط
// ═══════════════════════════════════════════════════════════
class PlanComparisonScreen extends StatefulWidget {
  const PlanComparisonScreen({super.key});
  @override State<PlanComparisonScreen> createState() => _PlanComparisonScreenState();
}
class _PlanComparisonScreenState extends State<PlanComparisonScreen> {
  List<dynamic> _comparison = [];
  List<String> _planNames = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await http.get(Uri.parse('$_api/plans/compare'));
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      _comparison = data['comparison'] ?? [];
      _planNames = List<String>.from(data['plans'] ?? []);
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('مقارنة الخطط'), backgroundColor: const Color(0xFF1E1E2E),
        iconTheme: const IconThemeData(color: AC.gold)),
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child:
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E1E2E)),
              columns: [
                const DataColumn(label: Text('الميزة', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold))),
                ..._planNames.map((p) => DataColumn(
                  label: Text(p, style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold)))),
              ],
              rows: _comparison.map<DataRow>((row) => DataRow(cells: [
                DataCell(Text(row['name_ar'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                ..._planNames.map((p) => DataCell(
                  Text(_formatCellValue(row[p] ?? 'N/A'), 
                    style: TextStyle(color: _cellColor(row[p] ?? ''), fontSize: 11)))),
              ])).toList(),
            ),
          )),
    ));
  }

  String _formatCellValue(String v) {
    if (v == 'true') return '✅';
    if (v == 'false') return '❌';
    if (v == 'unlimited') return '♾️';
    if (v == 'none') return '—';
    return v;
  }

  Color _cellColor(String v) {
    if (v == 'true' || v == 'unlimited') return AC.ok;
    if (v == 'false' || v == 'none') return AC.err;
    return Colors.white;
  }
}

// ═══════════════════════════════════════════════════════════
// ForgotPasswordScreen — استعادة كلمة المرور
// Phase 9 Account Center §6
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// NotificationCenterScreen — مركز الإشعارات (API-driven)
// Phase 10 Notification System §13
// ═══════════════════════════════════════════════════════════
class NotificationCenterScreenV2 extends StatefulWidget {
  const NotificationCenterScreenV2({super.key});
  @override State<NotificationCenterScreenV2> createState() => _NotifCenterV2State();
}
class _NotifCenterV2State extends State<NotificationCenterScreenV2> {
  List<dynamic> _notifs = [];
  bool _loading = true;
  int _unread = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final h = {'Authorization': 'Bearer ${S.token}'};
      final r = await http.get(Uri.parse('$_api/notifications?page_size=50'), headers: h);
      final c = await http.get(Uri.parse('$_api/notifications/count'), headers: h);
      if (r.statusCode == 200) {
        setState(() => _notifs = jsonDecode(r.body)['notifications'] ?? []);
      }
      if (c.statusCode == 200) {
        setState(() => _unread = jsonDecode(c.body)['unread'] ?? 0);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    await http.post(
      Uri.parse('$_api/notifications/mark-read'),
      headers: {'Authorization': 'Bearer ${S.token}', 'Content-Type': 'application/json'},
      body: jsonEncode({}),
    );
    _load();
  }

  Future<void> _markOneRead(String id) async {
    await http.post(
      Uri.parse('$_api/notifications/mark-read'),
      headers: {'Authorization': 'Bearer ${S.token}', 'Content-Type': 'application/json'},
      body: jsonEncode({'notification_id': id}),
    );
    _load();
  }

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'person_add': return Icons.person_add;
      case 'verified': return Icons.verified;
      case 'upgrade': return Icons.upgrade;
      case 'timer': return Icons.timer;
      case 'assignment': return Icons.assignment;
      case 'folder_off': return Icons.folder_off;
      case 'alarm': return Icons.alarm;
      case 'block': return Icons.block;
      case 'check_circle': return Icons.check_circle;
      case 'thumb_up': return Icons.thumb_up;
      case 'thumb_down': return Icons.thumb_down;
      case 'policy': return Icons.policy;
      case 'delete_outline': return Icons.delete_outline;
      default: return Icons.notifications;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'registration': return AC.ok;
      case 'verification': return AC.cyan;
      case 'plan_upgrade': return AC.gold;
      case 'plan_expiry_warning': return AC.warn;
      case 'task_assigned': return AC.cyan;
      case 'documents_missing': return AC.err;
      case 'deadline_approaching': return AC.warn;
      case 'account_suspended': return AC.err;
      case 'account_unsuspended': return AC.ok;
      case 'feedback_accepted': return AC.ok;
      case 'feedback_rejected': return AC.err;
      case 'terms_changed': return AC.warn;
      case 'closure_requested': return AC.err;
      default: return AC.ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('الإشعارات${_unread > 0 ? " ($_unread)" : ""}'),
        backgroundColor: AC.navy2,
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('قراءة الكل', style: TextStyle(color: AC.gold, fontSize: 12)),
            ),
          IconButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationPrefsScreen())),
            icon: const Icon(Icons.settings, color: AC.ts, size: 20),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _notifs.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.notifications_off, color: AC.ts, size: 48),
              const SizedBox(height: 12),
              Text('لا توجد إشعارات', style: TextStyle(color: AC.ts)),
            ]))
          : RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _notifs.length,
              itemBuilder: (_, i) {
                final n = _notifs[i];
                final isRead = n['is_read'] == true;
                return GestureDetector(
                  onTap: () { if (!isRead) _markOneRead(n['id']); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? AC.navy2 : AC.navy3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isRead ? Colors.transparent : AC.gold.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _colorFor(n['type']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(n['icon']), color: _colorFor(n['type']), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title_ar'] ?? '', style: TextStyle(
                          color: AC.tp, fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                        if (n['body_ar'] != null)
                          Text(n['body_ar'], style: TextStyle(color: AC.ts, fontSize: 12),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 8),
                      Column(children: [
                        Text(n['created_at']?.toString().substring(11, 16) ?? '',
                          style: TextStyle(color: AC.ts, fontSize: 11)),
                        if (!isRead) Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: AC.gold, shape: BoxShape.circle),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            )),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// NotificationPrefsScreen — تفضيلات الإشعارات
// ═══════════════════════════════════════════════════════════
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});
  @override State<NotificationPrefsScreen> createState() => _NotifPrefsState();
}
class _NotifPrefsState extends State<NotificationPrefsScreen> {
  List<dynamic> _prefs = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(
        Uri.parse('$_api/notifications/preferences'),
        headers: {'Authorization': 'Bearer ${S.token}'},
      );
      if (r.statusCode == 200) {
        setState(() => _prefs = jsonDecode(r.body)['preferences'] ?? []);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggle(String type, String channel, bool val) async {
    final pref = _prefs.firstWhere((p) => p['type'] == type, orElse: () => null);
    if (pref == null) return;
    await http.put(
      Uri.parse('$_api/notifications/preferences'),
      headers: {'Authorization': 'Bearer ${S.token}', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'notification_type': type,
        'in_app': channel == 'in_app' ? val : pref['in_app'],
        'email': channel == 'email' ? val : pref['email'],
        'sms': channel == 'sms' ? val : pref['sms'],
      }),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('تفضيلات الإشعارات'), backgroundColor: AC.navy2),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _prefs.length,
            itemBuilder: (_, i) {
              final p = _prefs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['title_ar'] ?? p['type'], style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _chip('داخل التطبيق', p['in_app'] == true, () => _toggle(p['type'], 'in_app', !(p['in_app'] == true))),
                    const SizedBox(width: 8),
                    _chip('بريد إلكتروني', p['email'] == true, () => _toggle(p['type'], 'email', !(p['email'] == true))),
                    const SizedBox(width: 8),
                    _chip('رسالة SMS', p['sms'] == true, () => _toggle(p['type'], 'sms', !(p['sms'] == true))),
                  ]),
                ]),
              );
            },
          ),
    ));
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AC.gold.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AC.gold : AC.ts.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(color: active ? AC.gold : AC.ts, fontSize: 11)),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailC = TextEditingController();
  String? _msg;
  String? _token;
  bool _loading = false;
  bool _sent = false;

  Future<void> _submit() async {
    if (_emailC.text.trim().isEmpty) {
      setState(() => _msg = 'أدخل البريد الإلكتروني');
      return;
    }
    setState(() { _loading = true; _msg = null; });
    try {
      final r = await http.post(
        Uri.parse('$_api/account/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailC.text.trim()}),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode == 200) {
        setState(() {
          _sent = true;
          _msg = data['message'] ?? 'تم الإرسال';
          _token = data['reset_token'];
        });
      } else {
        setState(() => _msg = data['detail'] ?? 'حدث خطأ');
      }
    } catch (e) {
      setState(() => _msg = 'خطأ في الاتصال');
    }
    setState(() => _loading = false);
  }

  void _goToReset() {
    if (_token != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(token: _token!),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('استعادة كلمة المرور'), backgroundColor: AC.navy2),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.lock_reset, color: AC.gold, size: 64),
          const SizedBox(height: 24),
          Text('أدخل بريدك الإلكتروني لإعادة تعيين كلمة المرور',
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.tp, fontSize: 16)),
          const SizedBox(height: 24),
          TextField(
            controller: _emailC,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني',
              labelStyle: TextStyle(color: AC.ts),
              prefixIcon: const Icon(Icons.email, color: AC.gold),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.bdr)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.gold)),
            ),
          ),
          const SizedBox(height: 20),
          if (_msg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sent ? AC.ok.withOpacity(0.15) : AC.err.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_msg!, style: TextStyle(color: _sent ? AC.ok : AC.err)),
            ),
          const SizedBox(height: 20),
          if (!_sent)
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إرسال رابط إعادة التعيين', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (_sent && _token != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _goToReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.cyan, foregroundColor: AC.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('إعادة تعيين كلمة المرور الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      )),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// ResetPasswordScreen — إعادة تعيين كلمة المرور
// ═══════════════════════════════════════════════════════════
class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});
  @override State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}
class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  String? _msg;
  bool _loading = false;
  bool _success = false;

  Future<void> _submit() async {
    if (_passC.text.length < 6) {
      setState(() => _msg = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_passC.text != _confirmC.text) {
      setState(() => _msg = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() { _loading = true; _msg = null; });
    try {
      final r = await http.post(
        Uri.parse('$_api/account/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': widget.token, 'new_password': _passC.text}),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode == 200) {
        setState(() { _success = true; _msg = data['message'] ?? 'تم التغيير بنجاح'; });
      } else {
        setState(() => _msg = data['detail'] ?? 'حدث خطأ');
      }
    } catch (e) {
      setState(() => _msg = 'خطأ في الاتصال');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('إعادة تعيين كلمة المرور'), backgroundColor: AC.navy2),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          TextField(
            controller: _passC, obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة', labelStyle: TextStyle(color: AC.ts),
              prefixIcon: const Icon(Icons.lock, color: AC.gold),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.bdr)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.gold)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmC, obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور', labelStyle: TextStyle(color: AC.ts),
              prefixIcon: const Icon(Icons.lock_outline, color: AC.gold),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.bdr)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.gold)),
            ),
          ),
          const SizedBox(height: 20),
          if (_msg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _success ? AC.ok.withOpacity(0.15) : AC.err.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_msg!, style: TextStyle(color: _success ? AC.ok : AC.err)),
            ),
          const SizedBox(height: 20),
          if (!_success)
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تعيين كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (_success)
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.ok, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('العودة لتسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      )),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// SessionsScreen — إدارة الجلسات النشطة
// Phase 9 Account Center §6
// ═══════════════════════════════════════════════════════════
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override State<SessionsScreen> createState() => _SessionsScreenState();
}
class _SessionsScreenState extends State<SessionsScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(
        Uri.parse('$_api/account/sessions'),
        headers: {'Authorization': 'Bearer ${S.token}'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() => _sessions = data['sessions'] ?? []);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _logoutAll() async {
    final r = await http.post(
      Uri.parse('$_api/account/sessions/logout-all'),
      headers: {'Authorization': 'Bearer ${S.token}'},
    );
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنهاء جميع الجلسات'), backgroundColor: Colors.green));
      _load();
    }
  }

  Future<void> _logoutOne(String id) async {
    final r = await http.post(
      Uri.parse('$_api/account/sessions/$id/logout'),
      headers: {'Authorization': 'Bearer ${S.token}'},
    );
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنهاء الجلسة'), backgroundColor: Colors.green));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: const Text('الجلسات النشطة'), backgroundColor: AC.navy2,
        actions: [
          TextButton.icon(
            onPressed: _logoutAll,
            icon: const Icon(Icons.logout, color: AC.err, size: 18),
            label: const Text('إنهاء الكل', style: TextStyle(color: AC.err, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _sessions.isEmpty
          ? Center(child: Text('لا توجد جلسات نشطة', style: TextStyle(color: AC.ts)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sessions.length,
              itemBuilder: (_, i) {
                final s = _sessions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AC.navy3, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.bdr),
                  ),
                  child: Row(children: [
                    const Icon(Icons.devices, color: AC.cyan, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['device_info'] ?? 'جهاز غير معروف',
                          style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('IP: ${s['ip_address'] ?? '—'}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                        Text('آخر نشاط: ${s['last_activity']?.toString().substring(0, 16) ?? '—'}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                      ],
                    )),
                    IconButton(
                      onPressed: () => _logoutOne(s['id']),
                      icon: const Icon(Icons.close, color: AC.err),
                      tooltip: 'إنهاء الجلسة',
                    ),
                  ]),
                );
              },
            ),
    ));
  }
}


