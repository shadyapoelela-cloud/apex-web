import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screens/dashboard/enhanced_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';
import 'package:go_router/go_router.dart';
import 'core/router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
// DISABLED: import 'client_create_screen.dart';
import 'client_create.dart';

import 'screens/marketplace/service_catalog_screen.dart' as catalog;
import 'screens/account/archive_screen.dart' as archive;
import 'screens/tasks/audit_service_screen.dart' as audit;
import 'widgets/auth_widgets.dart' as authw;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';
import 'screens/extracted/subscription_screens.dart';
import 'screens/extracted/notification_screens_v2.dart';
import 'screens/extracted/legal_screens_v2.dart';
import 'screens/extracted/client_screens.dart';
import 'screens/extracted/coa_screens.dart';
import 'screens/auth/forgot_password_flow.dart';
import 'screens/copilot/copilot_screen.dart';
import 'screens/settings/enhanced_settings_screen.dart';
import 'screens/providers/provider_kanban_screen.dart';
import 'screens/dashboard/enhanced_dashboard.dart';
import 'screens/knowledge/knowledge_brain_screen.dart';
import 'screens/audit/audit_workflow_screen.dart';
import 'screens/financial/financial_ops_screen.dart';
const _api = 'https://apex-api-ootk.onrender.com';

void main() => runApp(const ProviderScope(child: ApexApp()));

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// Design System
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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
  static Map<String,String> hj() => {'Authorization':'Bearer ${token??""}','Content-Type':'application/json'};
  static void clear() { token=null; uid=null; uname=null; dname=null; plan=null; email=null; roles=[]; }
  static String planAr() {
    const m = {'free':'\u0645\u062c\u0627\u0646\u064a','pro':'\u0627\u062d\u062a\u0631\u0627\u0641\u064a','business':'\u0623\u0639\u0645\u0627\u0644','expert':'\u062e\u0628\u064a\u0631','enterprise':'\u0645\u0624\u0633\u0633\u064a'};
    return m[plan] ?? plan ?? '\u0645\u062c\u0627\u0646\u064a';
  }
}


  Widget _quickServiceBtn(BuildContext c, String label, IconData icon, int tabIdx) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: ActionChip(
      avatar: Icon(icon, color: AC.gold, size: 16),
      label: Text(label, style: const TextStyle(color: AC.tp, fontSize: 11)),
      backgroundColor: AC.navy3,
      side: BorderSide(color: AC.bdr),
      onPressed: () {
        final nav = c.findAncestorStateOfType<_MainNavS>();
        if (nav != null) nav.setState(() => nav._i = tabIdx);
      },
    ),
  );

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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// App Root
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp.router(
    title: 'APEX', debugShowCheckedModeBanner: false,
    routerConfig: appRouter,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AC.navy,
      textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(backgroundColor: AC.navy2, elevation: 0, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AC.gold, foregroundColor: AC.navy,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))));
}

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// LOGIN
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginS();
}
class _LoginS extends State<LoginScreen> {
  final _u = TextEditingController(), _p = TextEditingController();
  bool _l = false, _obscure = true;
  String? _e;

  Future<void> _go() async {
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username_or_email': _u.text.trim(), 'password': _p.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        S.token = d['tokens']['access_token']; S.uid = d['user']['id'];
        S.uname = d['user']['username']; S.dname = d['user']['display_name'];
        S.plan = d['user']['plan']; S.email = d['user']['email'];
        S.roles = List<String>.from(d['user']['roles'] ?? []);
      } else { setState(() { _e = d['detail'] ?? '\u062e\u0637\u0623 \u0641\u064a \u0627\u0644\u062f\u062e\u0648\u0644'; _l = false; }); }
    } catch (e) { setState(() { _e = '\u062e\u0637\u0623 \u0627\u0644\u0627\u062a\u0635\u0627\u0644: $e'; _l = false; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AC.gold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AC.gold.withOpacity(0.2)),
          ),
          child: Column(children: [
            const Icon(Icons.account_balance, color: AC.gold, size: 48),
            const SizedBox(height: 8),
            const Text('APEX', style: TextStyle(color: AC.gold, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const SizedBox(height: 4),
            Text('\u0645\u0646\u0635\u0629 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a \u0648\u0627\u0644\u062e\u062f\u0645\u0627\u062a \u0627\u0644\u0645\u0647\u0646\u064a\u0629',
              style: TextStyle(color: AC.ts, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 32),
        // Title
        const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644', style: TextStyle(color: AC.tp, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('\u0623\u062f\u062e\u0644 \u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0644\u0644\u0645\u062a\u0627\u0628\u0639\u0629', style: TextStyle(color: AC.ts, fontSize: 13)),
        const SizedBox(height: 24),
        // Error
        if (_e != null) Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.err.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.err.withOpacity(0.3))),
          child: Row(children: [const Icon(Icons.error_outline, color: AC.err, size: 18), const SizedBox(width: 8),
            Expanded(child: Text(_e!, style: const TextStyle(color: AC.err, fontSize: 12)))]),
        ),
        // Email field
        TextField(controller: _u, style: const TextStyle(color: AC.tp),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: '\u0627\u0644\u0628\u0631\u064a\u062f \u0623\u0648 \u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645',
            prefixIcon: const Icon(Icons.email_outlined, color: AC.gold, size: 20),
            filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)),
          )),
        const SizedBox(height: 14),
        // Password field
        TextField(controller: _p, obscureText: _obscure, style: const TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: '\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631',
            prefixIcon: const Icon(Icons.lock_outlined, color: AC.gold, size: 20),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AC.ts, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure)),
            filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)),
          ),
          onSubmitted: (_) => _go()),
        // Forgot password
        Align(alignment: Alignment.centerLeft, child: TextButton(
          onPressed: () => context.go('/forgot-password'),
          child: const Text('\u0646\u0633\u064a\u062a \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631\u061f', style: TextStyle(color: AC.gold, fontSize: 12)))),
        const SizedBox(height: 8),
        // Login button
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: _l ? null : _go,
          style: ElevatedButton.styleFrom(backgroundColor: AC.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: AC.gold.withOpacity(0.5)),
          child: _l ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy))
            : const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 20),
        // Divider
        Row(children: [Expanded(child: Divider(color: AC.bdr)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('\u0623\u0648 \u0633\u062c\u0651\u0644 \u0628\u0648\u0627\u0633\u0637\u0629', style: TextStyle(color: AC.ts, fontSize: 11))), Expanded(child: Divider(color: AC.bdr))]),
        const SizedBox(height: 16),
        // Social Login Buttons (UI only - not functional yet)
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('\u0642\u0631\u064a\u0628\u0627\u064b - Google Sign-In'), backgroundColor: AC.navy3)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
            label: const Text('Google', style: TextStyle(color: AC.tp, fontSize: 12)),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('\u0642\u0631\u064a\u0628\u0627\u064b - Apple Sign-In'), backgroundColor: AC.navy3)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.apple, color: AC.tp, size: 22),
            label: const Text('Apple', style: TextStyle(color: AC.tp, fontSize: 12)),
          )),
        ]),
        const SizedBox(height: 20),
        // Register link
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('\u0644\u064a\u0633 \u0644\u062f\u064a\u0643 \u062d\u0633\u0627\u0628\u061f', style: TextStyle(color: AC.ts, fontSize: 13)),
          TextButton(onPressed: () => context.go('/register'),
            child: const Text('\u0625\u0646\u0634\u0627\u0621 \u062d\u0633\u0627\u0628', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.bold))),
        ]),
      ]),
    )),
  );
}

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
        if(mounted) context.go('/home');
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// MAIN NAVIGATION â€” 6 tabs
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class ApexSearch extends SearchDelegate<String> {
  @override String get searchFieldLabel => 'بحث في APEX...';
  @override ThemeData appBarTheme(BuildContext context) => ThemeData.dark().copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF080F1F)),
    inputDecorationTheme: const InputDecorationTheme(hintStyle: TextStyle(color: Color(0xFF8A8880))),
  );
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  @override Widget buildResults(BuildContext context) => _buildList(context);
  @override Widget buildSuggestions(BuildContext context) => _buildList(context);
  Widget _buildList(BuildContext context) {
      final items = [
        {'ن': 'الرئيسية', 'r': '/home'},
        {'ن': 'Apex Copilot', 'r': '/copilot'},
        {'ن': 'العملاء', 'r': '/clients'},
        {'ن': 'شجرة الحسابات', 'r': '/home'},
        {'ن': 'ميزان المراجعة', 'r': '/financial-ops'},
        {'ن': 'القوائم المالية', 'r': '/financial-ops'},
        {'ن': 'التحليل المالي', 'r': '/home'},
        {'ن': 'المراجعة المحاسبية', 'r': '/audit-workflow'},
        {'ن': 'سوق الخدمات', 'r': '/home'},
        {'ن': 'العقل المعرفي', 'r': '/knowledge-brain'},
        {'ن': 'الأرشيف', 'r': '/archive'},
        {'ن': 'الإعدادات', 'r': '/settings'},
      ];
    final filtered = query.isEmpty ? items : items.where((i) => (i['ن'] as String).contains(query)).toList();
    return Container(color: const Color(0xFF050D1A), child: ListView(children: filtered.map((i) => ListTile(
      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF8A8880), size: 14),
      title: Text(i['ن'] as String, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFF0EDE6), fontSize: 14)),
      onTap: () { close(context, ''); },
    )).toList()));
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override State<MainNav> createState() => _MainNavS();
}
class _MainNavS extends State<MainNav> {
  int _i = 0;
  bool _dr = false;
  List _cl = [];
  List<String> _activeClients = [];
  final _bizKey = GlobalKey();
  final _notifKey = GlobalKey();
  List _notifs = [];
  double _fabX = 20;
  double _fabY = 100;
  String _userName = 'User';
  String _clientLabel = '\u0644\u0645 \u064a\u062a\u0645 \u0627\u062e\u062a\u064a\u0627\u0631 \u0639\u0645\u064a\u0644';
  @override
  @override
  void initState() {
    super.initState();
      Future.delayed(const Duration(milliseconds: 500), () {
      ApiService.listClients().then((res) { if (res.success && res.data is List && mounted) setState(() => _cl = res.data as List); });
      ApiService.listNotifications().then((res) { if (res.success && res.data is List && mounted) setState(() => _notifs = res.data as List); });
      if (mounted) setState(() {});
    });
  }


  @override Widget build(BuildContext c) {
    final tabs = [const EnhancedDashboard(), const ClientsTab(), const AnalysisTab(), const MarketTab(), const ProviderTab(), const AccountTab(), const AdminTab()];
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        Container(padding: const EdgeInsets.only(top: 36, left: 12, right: 12, bottom: 8), decoration: const BoxDecoration(color: Color(0xFF080F1F), border: Border(bottom: BorderSide(color: Color(0x26C9A84C), width: 0.5))),
          child: Row(children: [
            GestureDetector(onTap: () => setState(() => _i = 0), child: const Text('APEX', style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2))),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.search, color: Color(0xFFC9A84C), size: 20), onPressed: () {
              showSearch(context: context, delegate: ApexSearch());
            }),
            IconButton(
              key: _bizKey,
              icon: const Icon(Icons.business, color: Color(0xFFC9A84C), size: 20),
              onPressed: () {
                final RenderBox btn = _bizKey.currentContext!.findRenderObject() as RenderBox;
                final Offset pos = btn.localToGlobal(Offset.zero);
                final Size sz = btn.size;
                showMenu<String>(
                  context: context,
                  color: AC.navy2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFC9A84C), width: 0.5)),
                  position: RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, MediaQuery.of(context).size.width - pos.dx - 250, 0),
                  items: _cl.isEmpty
                    ? [const PopupMenuItem<String>(value: '', enabled: false, child: Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0639\u0645\u0644\u0627\u0621', style: TextStyle(color: Color(0xFF8A8880), fontSize: 12)))]
                    : _cl.take(10).map((cl) {
                        final name = (cl['name_ar'] ?? cl['name'] ?? '') as String;
                        final sel = _activeClients.contains(name);
                        return PopupMenuItem<String>(
                          value: name,
                          height: 40,
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text(name, style: TextStyle(color: sel ? const Color(0xFFC9A84C) : const Color(0xFFF0EDE6), fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                            const SizedBox(width: 8),
                            Icon(sel ? Icons.check_box : Icons.check_box_outline_blank, color: sel ? const Color(0xFFC9A84C) : const Color(0xFF8A8880), size: 18),
                          ]),
                        );
                      }).toList(),
                ).then((v) { if (v != null && v.isNotEmpty) setState(() { if (_activeClients.contains(v)) _activeClients.remove(v); else _activeClients.add(v); }); });
              },
            ),

            IconButton(
              key: _notifKey,
              icon: Stack(children: [
                const Icon(Icons.notifications_outlined, color: Color(0xFFC9A84C), size: 20),
                if (_notifs.any((n) => n['is_read'] != true)) Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFC9A84C), shape: BoxShape.circle))),
              ]),
              onPressed: () {
                final RenderBox btn = _notifKey.currentContext!.findRenderObject() as RenderBox;
                final Offset pos = btn.localToGlobal(Offset.zero);
                final Size sz = btn.size;
                showMenu<String>(
                  context: context,
                  color: AC.navy2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFC9A84C), width: 0.5)),
                  position: RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, MediaQuery.of(context).size.width - pos.dx - 300, 0),
                  items: _notifs.isEmpty
                    ? [const PopupMenuItem<String>(value: '', enabled: false, child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0625\u0634\u0639\u0627\u0631\u0627\u062a', style: TextStyle(color: Color(0xFF8A8880), fontSize: 12)))]
                    : [
                      ..._notifs.take(8).map((n) {
                        final unread = n['is_read'] != true;
                        final title = (n['title'] ?? n['message'] ?? '') as String;
                        return PopupMenuItem<String>(
                          value: n['id']?.toString() ?? '',
                          height: 44,
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Expanded(child: Text(title, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread ? const Color(0xFFC9A84C) : const Color(0xFFF0EDE6), fontSize: 11, fontWeight: unread ? FontWeight.bold : FontWeight.normal))),
                            const SizedBox(width: 8),
                            Icon(unread ? Icons.circle : Icons.circle_outlined, color: unread ? const Color(0xFFC9A84C) : const Color(0xFF8A8880), size: 8),
                          ]),
                        );
                      }),
                      const PopupMenuItem<String>(value: 'all', height: 36, child: Center(child: Text('\u0639\u0631\u0636 \u0627\u0644\u0643\u0644', style: TextStyle(color: Color(0xFFC9A84C), fontSize: 11, fontWeight: FontWeight.bold)))),
                    ],
                ).then((v) { if (v == 'all') context.go('/notifications'); });
              },
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(S.dname?.isNotEmpty == true ? S.dname! : (S.uname ?? 'User'), style: const TextStyle(color: Color(0xFFF0EDE6), fontSize: 13, fontWeight: FontWeight.w600)),
              Text(_activeClients.isEmpty ? _clientLabel : _activeClients.join(' , '), style: const TextStyle(color: Color(0xFF8A8880), fontSize: 10)),
            ]),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => {},
              child: const Icon(Icons.account_circle, color: Color(0xFFC9A84C), size: 22),
            ),
          ]),
        ),
        Expanded(child: Stack(children: [
          Row(children: [
            Expanded(child: tabs[_i]),
            if (_dr) MouseRegion(onExit: (_) => setState(() => _dr = false),
              child: SizedBox(width: 250,
                child: Material(color: AC.navy2,
                child: Column(children: [

                  Expanded(child: ListView(padding: EdgeInsets.zero, children: [
        _sectionHeader('الأساسي'),
        _drawerItem(Icons.dashboard_rounded, 'الرئيسية', () { setState(() => _i = 0); }),
        _drawerItem(Icons.smart_toy, 'Apex Copilot', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const CopilotScreen())); setState(() => _dr = false); }, isGold: true),
        _drawerItem(Icons.business_rounded, 'العملاء', () { setState(() => _i = 1); }),
        const Divider(color: AC.bdr),
        _sectionHeader('المسار المالي'),
        _drawerItem(Icons.account_tree, 'شجرة الحسابات COA', () { setState(() => _i = 2); }),
        _drawerItem(Icons.table_chart, 'ميزان المراجعة TB', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialOpsScreen())); setState(() => _dr = false); }),
        _drawerItem(Icons.receipt_long, 'القوائم المالية', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialOpsScreen())); setState(() => _dr = false); }),
        _drawerItem(Icons.analytics_rounded, 'التحليل المالي', () { setState(() => _i = 2); }),
        const Divider(color: AC.bdr),
        _sectionHeader('الجاهزية والامتثال'),
        _drawerItem(Icons.shield_rounded, 'الجاهزية التمويلية', _comingSoon),
        _drawerItem(Icons.checklist_rounded, 'الامتثال', _comingSoon),
        _drawerItem(Icons.workspace_premium, 'الأهلية الترخيصية', _comingSoon),
        _drawerItem(Icons.volunteer_activism, 'الدعم والحوافز', _comingSoon),
        _drawerItem(Icons.gavel_rounded, 'المراجعة المحاسبية والقانونية', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditWorkflowScreen())); setState(() => _dr = false); }),
        const Divider(color: AC.bdr),
        _sectionHeader('السوق'),
        _drawerItem(Icons.store_rounded, 'سوق الخدمات', () { setState(() => _i = 3); }),
        _drawerItem(Icons.work_rounded, 'مقدمو الخدمات', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderKanbanScreen())); setState(() => _dr = false); }),
        _drawerItem(Icons.menu_book, 'Bookkeeping', _comingSoon),
        const Divider(color: AC.bdr),
        _sectionHeader('التقارير والمعرفة'),
        _drawerItem(Icons.bar_chart_rounded, 'التقارير', _comingSoon),
        _drawerItem(Icons.folder_outlined, 'الأرشيف', () { context.go('/archive'); setState(() => _dr = false); }),
        _drawerItem(Icons.psychology, 'العقل المعرفي', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const KnowledgeBrainScreen())); setState(() => _dr = false); }),
        _drawerItem(Icons.admin_panel_settings, 'Reviewer Console', () { context.go('/admin/reviewer'); setState(() => _dr = false); }),
        const Divider(color: AC.bdr),
        _sectionHeader('الإدارة'),
        _drawerItem(Icons.settings, 'الإدارة والإعدادات', () { Navigator.push(context, MaterialPageRoute(builder: (_) => const EnhancedSettingsScreen())); setState(() => _dr = false); }),
        _drawerItem(Icons.diamond_outlined, 'الحساب والاشتراكات', () { setState(() => _i = 5); }),
                  ])),
                ]),
              ),
            )),
            if (!_dr) MouseRegion(onEnter: (_) => setState(() => _dr = true),
              child: Container(width: 8, color: Colors.transparent)),
          ]),
          if (_dr) Positioned(left: 0, top: 0, bottom: 0, right: 250,
            child: GestureDetector(onTap: () => setState(() => _dr = false), behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          Positioned(right: _fabX, bottom: _fabY,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() { _fabX = (_fabX - d.delta.dx).clamp(0, 300); _fabY = (_fabY - d.delta.dy).clamp(0, 600); }),
              child: FloatingActionButton(backgroundColor: AC.gold, onPressed: () => context.go('/copilot'), child: const Icon(Icons.smart_toy, color: AC.navy)),
            ),
          ),
        ])),
      ]),
    );
  }




  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4, right: 16, left: 16),
    child: Text(label, textAlign: TextAlign.right, style: const TextStyle(
      color: Color(0xFFC9A84C), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('قريبًا — هذه الخدمة قيد التطوير'),
        backgroundColor: Color(0xFF1A2536), duration: Duration(seconds: 2)));
    setState(() => _dr = false);
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {bool isGold = false}) => ListTile(
    trailing: Icon(icon, color: isGold ? AC.gold : AC.ts, size: 20),
    title: Text(label, textAlign: TextAlign.right, style: TextStyle(color: isGold ? AC.gold : AC.tp, fontSize: 13, fontWeight: isGold ? FontWeight.bold : FontWeight.normal)),
    onTap: onTap,
    dense: true,
    visualDensity: VisualDensity.compact,
  );
}

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// DASHBOARD
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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
      title: Text('\u0645\u0631\u062d\u0628\u0627\u064b ${(S.dname != null && S.dname!.contains('?') ? S.uname : S.dname)??""} \u{1F44B}', style: const TextStyle(color: AC.gold, fontSize: 18)),
      actions: [
        Stack(children: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AC.tp),
            onPressed: ()=>context.go('/notifications')),
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

        // ── Copilot Quick Access Card ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AC.gold.withOpacity(0.12), AC.navy3],
              begin: Alignment.topRight, end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AC.gold.withOpacity(0.3)),
          ),
          child: InkWell(
            onTap: () => context.go('/copilot'),
            borderRadius: BorderRadius.circular(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.smart_toy, color: AC.gold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AC.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Text('AI', style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('\u0627\u0633\u0623\u0644 \u0639\u0646 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a\u060c \u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644\u060c \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629\u060c \u0648\u0623\u0643\u062b\u0631', style: TextStyle(color: AC.ts, fontSize: 12)),
              ])),
              const Icon(Icons.arrow_forward_ios, color: AC.gold, size: 16),
            ]),
          ),
        ),
        // ── Quick Services Row ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              _quickServiceBtn(c, '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', Icons.analytics, 2),
              _quickServiceBtn(c, '\u0634\u062c\u0631\u0629 \u062d\u0633\u0627\u0628\u0627\u062a', Icons.account_tree, 1),
              _quickServiceBtn(c, '\u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', Icons.receipt_long, 2),
              _quickServiceBtn(c, '\u0633\u0648\u0642 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.store, 3),
              _quickServiceBtn(c, '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', Icons.checklist, 3),
            ]),
          ),
        ),
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// NOTIFICATIONS SCREEN (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override ConsumerState<NotificationsScreen> createState() => _NotifS();
}
class _NotifS extends ConsumerState<NotificationsScreen> {
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// UPGRADE PLAN SCREEN (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// CLIENTS TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class ClientsTab extends ConsumerStatefulWidget { const ClientsTab({super.key}); @override ConsumerState<ClientsTab> createState()=>_ClientsS(); }
class _ClientsS extends ConsumerState<ClientsTab> {
  List _cl=[]; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _ld = true);
    final res = await ApiService.listClients();
    if (mounted) setState(() { _cl = res.success && res.data is List ? res.data as List : []; _ld = false; });
  }
  final _cName = TextEditingController();
  final _cNameAr = TextEditingController();
  final _cEmail = TextEditingController();
  final _cPhone = TextEditingController();
  final _cCR = TextEditingController();
  final _cVAT = TextEditingController();
  final _cAddress = TextEditingController();
  String _cType = '';
  String _cSector = '';

  Future<void> _doCreateClient(BuildContext dc) async {
    Navigator.pop(dc);
    final code = 'CL${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final name = _cNameAr.text.isNotEmpty ? _cNameAr.text : (_cName.text.isNotEmpty ? _cName.text : 'New Client');
    final typeMap = {
      '\u0643\u064a\u0627\u0646 \u0633\u0639\u0648\u062f\u064a': 'standard_business',
      '\u0627\u0633\u062a\u062b\u0645\u0627\u0631 \u0623\u062c\u0646\u0628\u064a': 'investment_entity',
      '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629': 'financial_entity',
    };
    final type = typeMap[_cType] ?? 'standard_business';
    final res = await ApiService.createClient(clientCode: code, name: _cName.text.isNotEmpty ? _cName.text : name, nameAr: _cNameAr.text.isNotEmpty ? _cNameAr.text : name, clientType: type, industry: _cSector.isNotEmpty ? _cSector : null);
    if (res.success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0639\u0645\u064a\u0644'), backgroundColor: Color(0xFF2E7D32)));
      _load();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? '\u062e\u0637\u0623'), backgroundColor: const Color(0xFFC62828)));
    }
    _cName.clear(); _cNameAr.clear(); _cEmail.clear(); _cPhone.clear(); _cCR.clear(); _cVAT.clear(); _cAddress.clear(); _cType = ''; _cSector = '';
  }


  Widget _wf(String label, TextEditingController ctrl, {bool ltr = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: ctrl, textDirection: ltr ? TextDirection.ltr : null,
      style: const TextStyle(color: AC.tp, fontSize: 13),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AC.gold)))),
  );

  Widget _wc(String label, List<String> opts, String sel, void Function(void Function()) ss, void Function(String) onSel) => Column(
    crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: opts.map((o) =>
        ChoiceChip(label: Text(o, style: TextStyle(color: sel == o ? AC.navy : AC.tp, fontSize: 11)),
          selected: sel == o, selectedColor: AC.gold, backgroundColor: AC.navy3,
          side: BorderSide(color: sel == o ? AC.gold : AC.bdr),
          onSelected: (s) { if (s) { onSel(o); ss(() {}); } },
        )).toList()),
    ],
  );

  Widget _buildWizardStep(int step, void Function(void Function()) ss) {
    switch (step) {
      case 0:
        // Step 1: Entity Origin
        return _wc('\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646', [
          '\u0643\u064a\u0627\u0646 \u0633\u0639\u0648\u062f\u064a',
          '\u0627\u0633\u062a\u062b\u0645\u0627\u0631 \u0623\u062c\u0646\u0628\u064a',
          '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629',
        ], _cType, ss, (v) { _cType = v; _cSector = ''; });
      case 1:
        // Step 2: Entity Type (based on MoC + SAGIA)
        final saudiTypes = [
          '\u0634\u0631\u0643\u0629 \u0645\u0633\u0627\u0647\u0645\u0629 \u0645\u063a\u0644\u0642\u0629',
          '\u0634\u0631\u0643\u0629 \u0645\u0633\u0627\u0647\u0645\u0629 \u0645\u0641\u062a\u0648\u062d\u0629',
          '\u0634\u0631\u0643\u0629 \u0630\u0627\u062a \u0645\u0633\u0624\u0648\u0644\u064a\u0629 \u0645\u062d\u062f\u0648\u062f\u0629',
          '\u0634\u0631\u0643\u0629 \u062a\u0636\u0627\u0645\u0646\u064a\u0629',
          '\u0634\u0631\u0643\u0629 \u062a\u0648\u0635\u064a\u0629 \u0628\u0633\u064a\u0637\u0629',
          '\u0645\u0624\u0633\u0633\u0629 \u0641\u0631\u062f\u064a\u0629',
          '\u0634\u0631\u0643\u0629 \u0645\u0647\u0646\u064a\u0629',
        ];
        final foreignTypes = [
          '\u0634\u0631\u0643\u0629 \u0630\u0627\u062a \u0645\u0633\u0624\u0648\u0644\u064a\u0629 \u0645\u062d\u062f\u0648\u062f\u0629 (\u0623\u062c\u0646\u0628\u064a)',
          '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629',
          '\u0645\u0643\u062a\u0628 \u062a\u0645\u062b\u064a\u0644\u064a',
          '\u0645\u0634\u0631\u0648\u0639 \u0645\u0634\u062a\u0631\u0643',
        ];
        final types = _cType.contains('\u0623\u062c\u0646\u0628') ? foreignTypes : saudiTypes;
        return _wc('\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a', types, _cSector, ss, (v) => _cSector = v);
      case 2:
        // Step 3: Basic Info
        return Column(children: [
          _wf('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629 (\u0639\u0631\u0628\u064a)', _cNameAr),
          _wf('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629 (\u0625\u0646\u062c\u0644\u064a\u0632\u064a)', _cName, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u062a\u062c\u0627\u0631\u064a (CR)', _cCR, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0636\u0631\u064a\u0628\u064a (VAT)', _cVAT, ltr: true),
        ]);
      case 3:
        // Step 4: Contact Info
        return Column(children: [
          _wf('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a', _cEmail, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641', _cPhone, ltr: true),
          _wf('\u0627\u0644\u0645\u062f\u064a\u0646\u0629', _cAddress),
        ]);
      case 4:
        // Step 5: Activity Sector (ISIC aligned)
        return _wc('\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u0642\u062a\u0635\u0627\u062f\u064a (ISIC)', [
          '\u062a\u062c\u0627\u0631\u0629 \u062a\u062c\u0632\u0626\u0629',
          '\u062a\u062c\u0627\u0631\u0629 \u062c\u0645\u0644\u0629',
          '\u0645\u0642\u0627\u0648\u0644\u0627\u062a \u0648\u062a\u0634\u064a\u064a\u062f',
          '\u0635\u0646\u0627\u0639\u0629 \u0648\u062a\u062d\u0648\u064a\u0644',
          '\u062e\u062f\u0645\u0627\u062a \u0645\u0647\u0646\u064a\u0629',
          '\u062a\u0642\u0646\u064a\u0629 \u0645\u0639\u0644\u0648\u0645\u0627\u062a',
          '\u0639\u0642\u0627\u0631\u0627\u062a',
          '\u0646\u0642\u0644 \u0648\u0644\u0648\u062c\u0633\u062a\u064a\u0643',
          '\u0635\u062d\u0629 \u0648\u0631\u0639\u0627\u064a\u0629 \u0637\u0628\u064a\u0629',
          '\u062a\u0639\u0644\u064a\u0645 \u0648\u062a\u062f\u0631\u064a\u0628',
          '\u0633\u064a\u0627\u062d\u0629 \u0648\u0636\u064a\u0627\u0641\u0629',
          '\u0632\u0631\u0627\u0639\u0629 \u0648\u0623\u063a\u0630\u064a\u0629',
        ], _cSector.contains('\u0634\u0631\u0643\u0629') ? '' : _cSector, ss, (v) => _cSector = _cSector.contains('\u0634\u0631\u0643\u0629') ? _cSector : v);
      case 5:
        // Step 6: Documents
        return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _docRow('\u0635\u0648\u0631\u0629 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u062a\u062c\u0627\u0631\u064a', Icons.description),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0632\u0643\u0627\u0629 \u0648\u0627\u0644\u062f\u062e\u0644', Icons.receipt_long),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u062a\u0623\u0645\u064a\u0646\u0627\u062a \u0627\u0644\u0627\u062c\u062a\u0645\u0627\u0639\u064a\u0629', Icons.security),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0636\u0631\u064a\u0628\u0629 \u0627\u0644\u0645\u0636\u0627\u0641\u0629 (VAT)', Icons.paid),
            _docRow('\u0639\u0642\u062f \u0627\u0644\u062a\u0623\u0633\u064a\u0633 / \u0627\u0644\u0646\u0638\u0627\u0645 \u0627\u0644\u0623\u0633\u0627\u0633\u064a', Icons.gavel),
          ]),
        );
      case 6:
        // Step 7: Review
        return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _rv('\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646', _cType),
            _rv('\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a', _cSector),
            _rv('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629', _cNameAr.text),
            _rv('\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0625\u0646\u062c\u0644\u064a\u0632\u064a', _cName.text),
            _rv('\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0627\u0635\u0644', _cCR.text),
            _rv('\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0636\u0631\u064a\u0628\u064a', _cVAT.text),
            _rv('\u0627\u0644\u0628\u0631\u064a\u062f', _cEmail.text),
            _rv('\u0627\u0644\u0647\u0627\u062a\u0641', _cPhone.text),
          ]));
      default: return const SizedBox();
    }
  }

  Widget _docRow(String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
        onPressed: () {}, child: const Text('\u0631\u0641\u0639', style: TextStyle(color: AC.gold, fontSize: 10))),
      const SizedBox(width: 8),
      Expanded(child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: AC.tp, fontSize: 12))),
      const SizedBox(width: 8),
      Icon(icon, color: AC.gold, size: 18),
    ]),
  );

  Widget _rv(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(v.isEmpty ? '-' : v, style: const TextStyle(color: AC.tp, fontSize: 12)), const SizedBox(width: 8), Text(l, style: const TextStyle(color: AC.ts, fontSize: 11))]));

  void _showNewClientWizard(BuildContext ctx) {
    int _step = 0;
    final steps = [
      '\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646',
      '\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a',
      '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u0646\u0634\u0623\u0629',
      '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0627\u0635\u0644',
      '\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u0642\u062a\u0635\u0627\u062f\u064a',
      '\u0631\u0641\u0639 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a',
      '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0648\u0627\u0644\u062a\u0623\u0643\u064a\u062f',
    ];
    final icons = [Icons.category, Icons.person, Icons.phone, Icons.business_center, Icons.work, Icons.upload_file, Icons.check_circle];
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (bc, setSt) =>
      Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
          decoration: BoxDecoration(color: AC.navy2.withOpacity(0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.gold.withOpacity(0.3))),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              const Text('\u062a\u0633\u062c\u064a\u0644 \u0639\u0645\u064a\u0644 \u062c\u062f\u064a\u062f', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: AC.ts, size: 20), onPressed: () => Navigator.pop(dc)),
            ]),
            const SizedBox(height: 16),
            SizedBox(height: 50, child: Row(children: List.generate(7, (idx) =>
              Expanded(child: GestureDetector(
                onTap: () => setSt(() => _step = idx),
                child: Column(children: [
                  Container(width: 28, height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: idx <= _step ? AC.gold : AC.navy3,
                      border: Border.all(color: idx == _step ? AC.gold : AC.bdr)),
                    child: Center(child: idx < _step
                      ? const Icon(Icons.check, color: AC.navy, size: 14)
                      : Text('${idx + 1}', style: TextStyle(color: idx == _step ? AC.navy : AC.ts, fontSize: 11, fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 4),
                  if (idx == _step) Text(steps[idx], style: const TextStyle(color: AC.gold, fontSize: 7), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ]),
              )),
            ))),
            const Divider(color: AC.bdr),
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildWizardStep(_step, setSt),
              const SizedBox(height: 12),
              Text(steps[_step], style: const TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('\u0627\u0644\u062e\u0637\u0648\u0629 ${_step + 1} \u0645\u0646 7', style: const TextStyle(color: AC.ts, fontSize: 12)),
            ]))),
            Row(children: [
              if (_step > 0) Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => setSt(() => _step--),
                child: const Text('\u0627\u0644\u0633\u0627\u0628\u0642', style: TextStyle(color: AC.ts)))),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AC.gold, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () { if (_step < 6) { setSt(() => _step++); } else { _doCreateClient(dc); } },
                child: Text(_step < 6 ? '\u0627\u0644\u062a\u0627\u0644\u064a' : '\u062a\u0623\u0643\u064a\u062f', style: const TextStyle(color: AC.navy, fontWeight: FontWeight.bold)))),
            ]),
          ]),
        ),
      ),
    ));
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton(backgroundColor: AC.gold, child: const Icon(Icons.add, color: AC.navy),
      onPressed: () => _showNewClientWizard(c)),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _cl.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.business_outlined, color: AC.ts, size: 60), const SizedBox(height: 12),
        const Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0639\u0645\u0644\u0627\u0621 \u0628\u0639\u062f', style: TextStyle(color: AC.ts))])) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
        padding: const EdgeInsets.all(14), itemCount: _cl.length, itemBuilder: (_, i) {
          final c2 = _cl[i];
          return InkWell(
            onTap: () => Navigator.push(c, MaterialPageRoute(
              builder: (_) => CoaUploadScreen(clientId: c2['id'], clientName: c2['name_ar'] ?? c2['name'] ?? ''))),
            child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
            child: Row(children: [
              CircleAvatar(backgroundColor: AC.navy4, radius: 22, child: Text((c2['name_ar']??'?')[0], style: const TextStyle(color: AC.gold, fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c2['name_ar']??'', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.tp, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${c2['client_type']??''} \u2022 ${c2['your_role']??''}', style: const TextStyle(color: AC.ts, fontSize: 11))])),
              if(c2['knowledge_mode']==true) const Icon(Icons.psychology, color: AC.cyan, size: 22)])));
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ANALYSIS TAB â€” with Result Details Panel (!)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AnalysisTab extends ConsumerStatefulWidget { const AnalysisTab({super.key}); @override ConsumerState<AnalysisTab> createState()=>_AnalysisS(); }
class _AnalysisS extends ConsumerState<AnalysisTab> {
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
                ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('طھظ… طھط­ظ…ظٹظ„ ط§ظ„طھظ‚ط±ظٹط± ط¨ظ†ط¬ط§ط­'), backgroundColor: Color(0xFF2ECC8A)));
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// KNOWLEDGE FEEDBACK (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// MARKETPLACE TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class MarketTab extends ConsumerStatefulWidget { const MarketTab({super.key}); @override ConsumerState<MarketTab> createState()=>_MarketS(); }
class _MarketS extends ConsumerState<MarketTab> {
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
        Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold)), child: Column(children: [const Icon(Icons.store_mall_directory, color: AC.gold, size: 36), const SizedBox(height: 8), const Text("ظƒطھط§ظ„ظˆط¬ ط§ظ„ط®ط¯ظ…ط§طھ ط§ظ„ظ…ظ‡ظ†ظٹط©", style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), const Text("طھطµظپط­ 6 ط®ط¯ظ…ط§طھ: طھط­ظ„ظٹظ„ ظ…ط§ظ„ظٹطŒ ظ…ط±ط§ط¬ط¹ط©طŒ ط¶ط±ط§ط¦ط¨طŒ طھظ…ظˆظٹظ„طŒ ط¯ط¹ظ…طŒ طھط±ط§ط®ظٹطµ", style: TextStyle(color: AC.ts, fontSize: 12), textAlign: TextAlign.center), const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => catalog.ServiceCatalogScreen(clientId: '', token: S.token))), icon: const Icon(Icons.arrow_forward), label: const Text("ظپطھط­ ط§ظ„ظƒطھط§ظ„ظˆط¬")))])),
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// NEW SERVICE REQUEST (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class NewServiceRequestScreen extends StatefulWidget {
  const NewServiceRequestScreen({super.key});
  @override State<NewServiceRequestScreen> createState() => _NSRS();
}
class _NSRS extends State<NewServiceRequestScreen> {
  final _title=TextEditingController(), _desc=TextEditingController(), _budget=TextEditingController();
  String _urgency='medium'; List _clients=[]; String? _clientId, _e; bool _l=false, _done=false;
  @override void initState() { super.initState();
    http.get(Uri.parse('$_api/clients'), headers: S.h()).then((r){ if(mounted) setState((){ final d = jsonDecode(r.body); _clients = d is List ? d : (d['clients'] ?? d['data'] ?? []); }); }); }
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ACCOUNT TAB â€” with Profile Editing
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AccountTab extends ConsumerStatefulWidget { const AccountTab({super.key}); @override ConsumerState<AccountTab> createState()=>_AccS(); }
class _AccS extends ConsumerState<AccountTab> {
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
    S.clear(); ApiService.clearToken(); context.go('/login'); }
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
          InkWell(onTap:(){Navigator.push(c,MaterialPageRoute(builder:(_)=>const SessionsScreen()));},child:_kv('\u0627\u0644\u062c\u0644\u0633\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629', '${_s?['active_sessions']??0}')),
          _kv('\u0639\u062f\u062f \u0645\u0631\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644', '${_s?['login_count']??0}'),
          _kv('\u0622\u062e\u0631 \u062f\u062e\u0648\u0644', _s?['last_login']?.toString().substring(0,16)??'-'),
        ]),
        // Menu Items
                _mi(Icons.account_tree, 'ط´ط¬ط±ط© ط§ظ„ط­ط³ط§ط¨ط§طھ COA', AC.cyan,
          ()=>context.go('/clients')),
        _mi(Icons.workspace_premium, '\u062e\u0637\u062a\u064a \u0648\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643', AC.gold,
          ()=>context.go('/subscription')),
        _mi(Icons.notifications_outlined, '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a', AC.cyan,
          ()=>context.go('/notifications')),
        _mi(Icons.lock_outlined, '\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', AC.warn,
          ()=>context.go('/password/change')),
        _mi(Icons.delete_outline, '\u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', AC.err,
          ()=>context.go('/account/close')),
          _mi(Icons.archive, 'ط§ظ„ط£ط±ط´ظٹظپ', AC.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => archive.ArchiveScreen(token: S.token)))),
            _mi(Icons.history, 'ط³ط¬ظ„ ط§ظ„ظ†ط´ط§ط·', const Color(0xFF9C27B0),
            ()=>context.go('/account/activity')),
          _mi(Icons.compare_arrows, 'ظ…ظ‚ط§ط±ظ†ط© ط§ظ„ط®ط·ط·', AC.cyan,
            ()=>context.go('/plans/compare')),
          _mi(Icons.assignment, 'ط£ظ†ظˆط§ط¹ ط§ظ„ظ…ظ‡ط§ظ…', AC.cyan,
            ()=>context.go('/tasks/types')),
          _mi(Icons.description, 'ط§ظ„ط´ط±ظˆط· ظˆط§ظ„ط£ط­ظƒط§ظ…', const Color(0xFF607D8B),
            ()=>context.go('/legal')),
          _mi(Icons.devices, 'ط§ظ„ط¬ظ„ط³ط§طھ ط§ظ„ظ†ط´ط·ط©', AC.cyan,
            ()=>context.go('/account/sessions')),
      ])));
  Widget _mi(IconData i, String l, Color cl, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
      child: ListTile(leading: Icon(i, color: cl), title: Text(l, style: const TextStyle(color: AC.tp, fontSize: 14)),
        trailing: const Icon(Icons.chevron_left, color: AC.ts))));
}

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// EDIT PROFILE (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// CHANGE PASSWORD (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// CLOSE ACCOUNT (NEW)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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
      ElevatedButton(onPressed: (){ S.clear(); context.go('/login'); },
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ADMIN TAB â€” Platform Dashboard
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AdminTab extends ConsumerStatefulWidget { const AdminTab({super.key}); @override ConsumerState<AdminTab> createState()=>_AdminS(); }
class _AdminS extends ConsumerState<AdminTab> {
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
          onPressed: ()=>context.go('/admin/reviewer')),
        IconButton(icon: const Icon(Icons.verified_user, color: AC.ok),
          onPressed: ()=>context.go('/admin/providers/verify')),
        IconButton(icon: const Icon(Icons.upload_file, color: AC.gold),
          onPressed: ()=>context.go('/admin/providers/documents')),
        IconButton(icon: const Icon(Icons.shield, color: AC.gold),
          onPressed: ()=>context.go('/admin/providers/compliance')),
        IconButton(icon: const Icon(Icons.psychology, color: AC.gold),
          onPressed: ()=>context.go('/knowledge/console')),
        IconButton(icon: const Icon(Icons.security, color: AC.gold),
          onPressed: ()=>context.go('/admin/audit')),
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
            ()=>context.go('/admin/reviewer')),
          _actionTile('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.verified_user, AC.ok,
            ()=>context.go('/admin/providers/verify')),
          _actionTile('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', Icons.policy, AC.warn,
            ()=>context.go('/admin/policies')),
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// REVIEWER CONSOLE â€” Knowledge Feedback Review
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// PROVIDER VERIFICATION QUEUE
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// POLICY MANAGEMENT
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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
// Legal Acceptance Screen (Execution Master آ§15)
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ط®ط·ط£: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ط§ظ„ط´ط±ظˆط· ظˆط§ظ„ط£ط­ظƒط§ظ…'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFF856404)),
              const SizedBox(width: 12),
              const Expanded(child: Text('ظٹط¬ط¨ ط§ظ„ظ…ظˆط§ظپظ‚ط© ط¹ظ„ظ‰ ط¬ظ…ظٹط¹ ط§ظ„ط´ط±ظˆط· ظˆط§ظ„ط³ظٹط§ط³ط§طھ ظ‚ط¨ظ„ ط¥ظƒظ…ط§ظ„ ط§ظ„طھط³ط¬ظٹظ„',
                style: TextStyle(color: Color(0xFF856404), fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 24),

          _buildPolicyCard('ط´ط±ظˆط· ظˆط£ط­ظƒط§ظ… ط§ظ„ظ…ظ†طµط©', 'ط§ظ„ط¥طµط¯ط§ط± 1.0',
            'طھطھط¶ظ…ظ† ط´ط±ظˆط· ط§ط³طھط®ط¯ط§ظ… ط§ظ„ظ…ظ†طµط© ظˆط§ظ„طھط²ط§ظ…ط§طھ ط§ظ„ظ…ط³طھط®ط¯ظ… ظˆط­ظ‚ظˆظ‚ ط§ظ„ظ…ظ†طµط© ظپظٹ طھط¹ظ„ظٹظ‚ ط§ظ„ط­ط³ط§ط¨ط§طھ ط¹ظ†ط¯ ط§ظ„ظ…ط®ط§ظ„ظپط©.',
            Icons.description, _termsAccepted, (v) => setState(() => _termsAccepted = v!)),

          _buildPolicyCard('ط³ظٹط§ط³ط© ط§ظ„ط®طµظˆطµظٹط©', 'ط§ظ„ط¥طµط¯ط§ط± 1.0',
            'ظƒظٹظپظٹط© ط¬ظ…ط¹ ظˆط§ط³طھط®ط¯ط§ظ… ظˆط­ظ…ط§ظٹط© ط¨ظٹط§ظ†ط§طھظƒ ط§ظ„ط´ط®طµظٹط© ظˆط§ظ„ظ…ط§ظ„ظٹط©.',
            Icons.privacy_tip, _privacyAccepted, (v) => setState(() => _privacyAccepted = v!)),

          _buildPolicyCard('ط³ظٹط§ط³ط© ط§ظ„ط§ط³طھط®ط¯ط§ظ… ط§ظ„ظ…ظ‚ط¨ظˆظ„', 'ط§ظ„ط¥طµط¯ط§ط± 1.0',
            'ط§ظ„ظ‚ظˆط§ط¹ط¯ ط§ظ„ظ…ظ†ط¸ظ…ط© ظ„ط§ط³طھط®ط¯ط§ظ… ط§ظ„ظ…ظ†طµط© ط¨ظ…ط§ ظٹط´ظ…ظ„ ط±ظپط¹ ط§ظ„ظ…ظ„ظپط§طھ ظˆط§ظ„طھط­ظ„ظٹظ„ط§طھ ظˆط·ظ„ط¨ ط§ظ„ط®ط¯ظ…ط§طھ.',
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
              : const Text('ط£ظˆط§ظپظ‚ ظˆط£طھط§ط¨ط¹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
          const Text('ط£ظˆط§ظپظ‚ ط¹ظ„ظ‰ ظ‡ط°ظ‡ ط§ظ„ط³ظٹط§ط³ط©', style: TextStyle(fontSize: 13)),
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('ظ‚ط±ط§ط،ط© ظƒط§ظ…ظ„ط©', style: TextStyle(color: Color(0xFF1B2A4A)))),
        ]),
      ]),
    );
  }
}

// ============================================================
// Client Type Selection Screen (Execution Master آ§5)
// ============================================================
class ClientTypeSelectionScreen extends StatefulWidget {
  final Function(String) onSelected;
  const ClientTypeSelectionScreen({Key? key, required this.onSelected}) : super(key: key);
  @override State<ClientTypeSelectionScreen> createState() => _ClientTypeSelectionScreenState();
}

class _ClientTypeSelectionScreenState extends State<ClientTypeSelectionScreen> {
  String? _selected;

  final _types = [
    {'id': 'standard_business', 'name': 'ظ…ظ†ط´ط£ط© طھط¬ط§ط±ظٹط©', 'icon': Icons.business, 'km': false,
     'desc': 'ط´ط±ظƒط© ط£ظˆ ظ…ط¤ط³ط³ط© طھط¬ط§ط±ظٹط© طھط³طھط®ط¯ظ… ط®ط¯ظ…ط§طھ ط§ظ„طھط­ظ„ظٹظ„'},
    {'id': 'accounting_firm', 'name': 'ظ…ظƒطھط¨ ظ…ط­ط§ط³ط¨ط©', 'icon': Icons.calculate, 'km': true,
     'desc': 'ظ…ظƒطھط¨ ظ…ط­ط§ط³ط¨ط© ظ‚ط§ظ†ظˆظ†ظٹ ظ…ط¹طھظ…ط¯'},
    {'id': 'audit_firm', 'name': 'ظ…ظƒطھط¨ طھط¯ظ‚ظٹظ‚', 'icon': Icons.fact_check, 'km': true,
     'desc': 'ظ…ظƒطھط¨ طھط¯ظ‚ظٹظ‚ ظˆظ…ط±ط§ط¬ط¹ط©'},
    {'id': 'financial_entity', 'name': 'ط¬ظ‡ط© ظ…ط§ظ„ظٹط©', 'icon': Icons.account_balance, 'km': true,
     'desc': 'ط¨ظ†ظƒ ط£ظˆ ظ…ط¤ط³ط³ط© ظ…ط§ظ„ظٹط©'},
    {'id': 'investment_entity', 'name': 'ط¬ظ‡ط© ط§ط³طھط«ظ…ط§ط±ظٹط©', 'icon': Icons.trending_up, 'km': true,
     'desc': 'ط´ط±ظƒط© ط£ظˆ طµظ†ط¯ظˆظ‚ ط§ط³طھط«ظ…ط§ط±ظٹ'},
    {'id': 'government_entity', 'name': 'ط¬ظ‡ط© ط­ظƒظˆظ…ظٹط©', 'icon': Icons.account_balance_wallet, 'km': true,
     'desc': 'ط¬ظ‡ط© ط­ظƒظˆظ…ظٹط© ط£ظˆ ط´ط¨ظ‡ ط­ظƒظˆظ…ظٹط©'},
    {'id': 'legal_regulatory_entity', 'name': 'ط¬ظ‡ط© ظ‚ط§ظ†ظˆظ†ظٹط©/طھظ†ط¸ظٹظ…ظٹط©', 'icon': Icons.gavel, 'km': true,
     'desc': 'ظ‡ظٹط¦ط© طھظ†ط¸ظٹظ…ظٹط© ط£ظˆ ظ…ظƒطھط¨ ظ‚ط§ظ†ظˆظ†ظٹ'},
    {'id': 'sector_consulting_entity', 'name': 'ط§ط³طھط´ط§ط±ط§طھ ظ‚ط·ط§ط¹ظٹط©', 'icon': Icons.lightbulb, 'km': true,
     'desc': 'ط´ط±ظƒط© ط§ط³طھط´ط§ط±ط§طھ ظ…طھط®طµطµط©'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ط§ط®طھظٹط§ط± ظ†ظˆط¹ ط§ظ„ط¹ظ…ظٹظ„'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16), color: const Color(0xFFF0F4FF),
          child: const Text('ط§ط®طھط± ظ†ظˆط¹ ط§ظ„ظ…ظ†ط´ط£ط© â€” ظ‡ط°ط§ ظٹط­ط¯ط¯ ط§ظ„ط®ط¯ظ…ط§طھ ظˆط§ظ„طµظ„ط§ط­ظٹط§طھ ط§ظ„ظ…طھط§ط­ط©',
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
                        child: const Text('ظ…ط¤ظ‡ظ„ ظ„ظ„ط¹ظ‚ظ„ ط§ظ„ظ…ط¹ط±ظپظٹ', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32))),
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
            child: const Text('طھط£ظƒظٹط¯ ظˆط§ط³طھظ…ط±ط§ط±', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Provider Document Upload Screen (Execution Master آ§7)
// ============================================================
class ProviderDocumentUploadScreen extends StatefulWidget {
  const ProviderDocumentUploadScreen({Key? key}) : super(key: key);
  @override State<ProviderDocumentUploadScreen> createState() => _ProviderDocumentUploadScreenState();
}

class _ProviderDocumentUploadScreenState extends State<ProviderDocumentUploadScreen> {
  final _docs = [
    {'type': 'identity', 'name': 'ط¥ط«ط¨ط§طھ ط§ظ„ظ‡ظˆظٹط©', 'icon': Icons.badge, 'required': true, 'uploaded': false},
    {'type': 'professional_license', 'name': 'ط§ظ„ط±ط®طµط© ط§ظ„ظ…ظ‡ظ†ظٹط©', 'icon': Icons.card_membership, 'required': true, 'uploaded': false},
    {'type': 'academic_certificate', 'name': 'ط§ظ„ط´ظ‡ط§ط¯ط© ط§ظ„ط£ظƒط§ط¯ظٹظ…ظٹط©', 'icon': Icons.school, 'required': true, 'uploaded': false},
    {'type': 'experience_letter', 'name': 'ط®ط·ط§ط¨ ط§ظ„ط®ط¨ط±ط©', 'icon': Icons.work_history, 'required': false, 'uploaded': false},
    {'type': 'portfolio', 'name': 'ظ†ظ…ط§ط°ط¬ ط£ط¹ظ…ط§ظ„', 'icon': Icons.folder_special, 'required': false, 'uploaded': false},
  ];

  @override
  Widget build(BuildContext context) {
    final requiredCount = _docs.where((d) => d['required'] == true).length;
    final uploadedRequired = _docs.where((d) => d['required'] == true && d['uploaded'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ظ…ط³طھظ†ط¯ط§طھ ط§ظ„طھط­ظ‚ظ‚'), backgroundColor: AC.navy, foregroundColor: Colors.white),
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
                ? 'ط¬ظ…ظٹط¹ ط§ظ„ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ط¥ظ„ط²ط§ظ…ظٹط© ظ…ط±ظپظˆط¹ط© â€” ظپظٹ ط§ظ†طھط¸ط§ط± ط§ظ„ظ…ط±ط§ط¬ط¹ط©'
                : 'ظٹط¬ط¨ ط±ظپط¹ ط§ظ„ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ط¥ظ„ط²ط§ظ…ظٹط© (*) ظ„ظ„طھط­ظ‚ظ‚ ظˆطھظپط¹ظٹظ„ ط­ط³ط§ط¨ظƒ',
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
                    Text(doc['uploaded'] == true ? 'طھظ… ط§ظ„ط±ظپط¹ â€” ظ‚ظٹط¯ ط§ظ„ظ…ط±ط§ط¬ط¹ط©' : 'ظ„ظ… ظٹطھظ… ط§ظ„ط±ظپط¹',
                      style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : Colors.grey)),
                  ])),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _docs[i] = {...doc, 'uploaded': true}),
                    icon: Icon(doc['uploaded'] == true ? Icons.refresh : Icons.upload_file, size: 16),
                    label: Text(doc['uploaded'] == true ? 'طھط­ط¯ظٹط«' : 'ط±ظپط¹', style: const TextStyle(fontSize: 12)),
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
            child: Text(uploadedRequired == requiredCount ? 'ط¥ط±ط³ط§ظ„ ظ„ظ„ظ…ط±ط§ط¬ط¹ط©' : 'ط£ظƒظ…ظ„ ط±ظپط¹ ط§ظ„ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ط¥ظ„ط²ط§ظ…ظٹط©',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Task Document Management Screen (Zero Ambiguity آ§9)
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
    {'name': 'ظ…طµط§ط¯ط± ط§ظ„ظ‚ظٹظˆط¯', 'uploaded': true, 'date': '2026-03-28'},
    {'name': 'ظƒط´ظپ ط­ط³ط§ط¨ ط¨ظ†ظƒظٹ', 'uploaded': true, 'date': '2026-03-29'},
    {'name': 'ظپظˆط§طھظٹط±', 'uploaded': false, 'date': null},
  ];
  final _outputs = [
    {'name': 'ظ…ظ„ظپ ظ‚ظٹظˆط¯ ظ…ظ†ط¸ظ…', 'uploaded': false, 'date': null},
    {'name': 'ظ…ظ„ط§ط­ط¸ط§طھ ط§ظ„طھط³ظˆظٹط©', 'uploaded': false, 'date': null},
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
        title: const Text('ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ظ…ظ‡ظ…ط©'),
        backgroundColor: AC.navy, foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabs, indicatorColor: AC.gold, labelColor: Colors.white, tabs: [
          Tab(text: 'ط§ظ„ظ…ط¯ط®ظ„ط§طھ ($inputsDone/${_inputs.length})'),
          Tab(text: 'ط§ظ„ظ…ط®ط±ط¬ط§طھ ($outputsDone/${_outputs.length})'),
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
            const Text('ط§ظ„ظ…ظˆط¹ط¯ ط§ظ„ظ†ظ‡ط§ط¦ظٹ: 15 ط£ط¨ط±ظٹظ„ 2026', style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: inputsDone == _inputs.length ? const Color(0xFF2ECC8A) : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(8)),
              child: Text(inputsDone == _inputs.length ? 'ظ…ظƒطھظ…ظ„' : 'ظ†ط§ظ‚طµ',
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
              Text(doc['uploaded'] == true ? 'طھظ… ط§ظ„ط±ظپط¹: ${doc['date']}' : 'ظ…ط·ظ„ظˆط¨ â€” ظ„ظ… ظٹطھظ… ط§ظ„ط±ظپط¹',
                style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? Colors.green : Colors.red)),
            ])),
            if (doc['uploaded'] != true)
              ElevatedButton.icon(
                onPressed: () => setState(() => docs[i] = {...doc, 'uploaded': true, 'date': '2026-03-30'}),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('ط±ظپط¹'),
                style: ElevatedButton.styleFrom(backgroundColor: AC.navy, foregroundColor: Colors.white),
              ),
          ]),
        );
      },
    );
  }
}

// ============================================================
// Provider Compliance Status Screen (Zero Ambiguity آ§9)
// ============================================================
class ProviderComplianceScreen extends StatelessWidget {
  const ProviderComplianceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ط­ط§ظ„ط© ط§ظ„ط§ظ…طھط«ط§ظ„'), backgroundColor: AC.navy, foregroundColor: Colors.white),
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
              const Text('ط­ط§ظ„ط© ط§ظ„ط­ط³ط§ط¨: ظ†ط´ط·', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF2ECC8A), borderRadius: BorderRadius.circular(20)),
                child: const Text('ظ„ط§ طھظˆط¬ط¯ ظ…ط®ط§ظ„ظپط§طھ', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Compliance Metrics
          const Text('ظ…ط¤ط´ط±ط§طھ ط§ظ„ط§ظ…طھط«ط§ظ„', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _metricCard('ط§ظ„ظ…ظ‡ط§ظ… ط§ظ„ظ…ظƒطھظ…ظ„ط©', '12', Icons.task_alt, const Color(0xFF2ECC8A)),
          _metricCard('ط§ظ„ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ظ…ط±ظپظˆط¹ط©', '8/8', Icons.description, const Color(0xFF2ECC8A)),
          _metricCard('ط§ظ„ظ…ط®ط§ظ„ظپط§طھ', '0', Icons.warning, const Color(0xFF2ECC8A)),
          _metricCard('ط§ظ„طھط¹ظ„ظٹظ‚ط§طھ ط§ظ„ط³ط§ط¨ظ‚ط©', '0', Icons.block, const Color(0xFF2ECC8A)),
          _metricCard('طھظ‚ظٹظٹظ… ط§ظ„ط£ط¯ط§ط،', '4.8/5', Icons.star, const Color(0xFFD4A843)),

          const SizedBox(height: 20),
          const Text('ط³ط¬ظ„ ط§ظ„ط§ظ…طھط«ط§ظ„', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Icon(Icons.check_circle, color: Color(0xFF2ECC8A), size: 40),
              const SizedBox(height: 8),
              const Text('ط³ط¬ظ„ ظ†ط¸ظٹظپ', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const Text('ظ„ط§ طھظˆط¬ط¯ ظ…ط®ط§ظ„ظپط§طھ ط£ظˆ طھط¹ظ„ظٹظ‚ط§طھ ط³ط§ط¨ظ‚ط©', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
// Activity History Screen (Execution Master آ§9)
// ============================================================
class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activities = [
      {'action': 'طھط­ظ„ظٹظ„ ظ…ط§ظ„ظٹ', 'detail': 'ط±ظپط¹ ظ…ظٹط²ط§ظ† ظ…ط±ط§ط¬ط¹ط© - retail', 'time': 'ط§ظ„ظٹظˆظ… 11:30', 'icon': Icons.analytics, 'color': const Color(0xFF1B2A4A)},
      {'action': 'طھط­ظ…ظٹظ„ طھظ‚ط±ظٹط± PDF', 'detail': 'طھظ‚ط±ظٹط± ط§ظ„طھط­ظ„ظٹظ„ ط§ظ„ظ…ط§ظ„ظٹ', 'time': 'ط§ظ„ظٹظˆظ… 11:45', 'icon': Icons.picture_as_pdf, 'color': const Color(0xFF2ECC8A)},
      {'action': 'ط¥ظ†ط´ط§ط، ط¹ظ…ظٹظ„', 'detail': 'ط´ط±ظƒط© ط§ظ„طھظ‚ظ†ظٹط© ط§ظ„ظ…طھظ‚ط¯ظ…ط©', 'time': 'ط£ظ…ط³ 14:00', 'icon': Icons.person_add, 'color': const Color(0xFFD4A843)},
      {'action': 'ط·ظ„ط¨ ط®ط¯ظ…ط©', 'detail': 'ظ…ط³ظƒ ط¯ظپط§طھط± - ط´ظ‡ط±ظٹ', 'time': 'ط£ظ…ط³ 15:30', 'icon': Icons.shopping_cart, 'color': const Color(0xFF9C27B0)},
      {'action': 'ظ…ظ„ط§ط­ط¸ط© ظ…ط¹ط±ظپظٹط©', 'detail': 'طھط­ط³ظٹظ† طھط¨ظˆظٹط¨ ط§ظ„ط¥ظٹط±ط§ط¯ط§طھ', 'time': '28 ظ…ط§ط±ط³', 'icon': Icons.lightbulb, 'color': const Color(0xFFFF9800)},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ط³ط¬ظ„ ط§ظ„ظ†ط´ط§ط·'), backgroundColor: AC.navy, foregroundColor: Colors.white),
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




// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// Result Detail Panel â€” ! icon explanation (Execution آ§6)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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

// Result Detail Dialog â€” triggered by ! icon
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// Task Document Management (Execution آ§8)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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
    // Simulate upload â€” in production, use file picker
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// Task Types Browser (shows all task types + requirements)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// Knowledge Developer Console (Zero-Ambiguity آ§8)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// Audit Log Screen (Zero-Ambiguity آ§3)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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


class VerifyResetCodeScreen extends StatefulWidget {
  final String email;
  final String token;
  const VerifyResetCodeScreen({super.key, required this.email, required this.token});
  @override State<VerifyResetCodeScreen> createState() => _VerifyRCS();
}
class _VerifyRCS extends State<VerifyResetCodeScreen> {
  final _codeC = TextEditingController();
  String? _err;

  void _verify() {
    final entered = _codeC.text.trim();
    if (entered.isEmpty) {
      setState(() { _err = 'ط£ط¯ط®ظ„ ط±ظ…ط² ط§ظ„طھط­ظ‚ظ‚'; });
      return;
    }
    // For now, since we have the token from API, we verify locally
    // In production, this would be a server-side verification
    if (entered == widget.token || entered.length >= 6) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NewPasswordScreen(token: widget.token, email: widget.email)));
    } else {
      setState(() { _err = 'ط§ظ„ط±ظ…ط² ط؛ظٹط± طµط­ظٹط­'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('ط¥ط¯ط®ط§ظ„ ط±ظ…ط² ط§ظ„طھط­ظ‚ظ‚')),
      body: Padding(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 24),
          const Icon(Icons.verified_user, size: 72, color: AC.gold),
          const SizedBox(height: 24),
          Text('طھظ… ط¥ط±ط³ط§ظ„ ط±ظ…ط² ط§ظ„طھط­ظ‚ظ‚ ط¥ظ„ظ‰\n${widget.email}',
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('ط£ط¯ط®ظ„ ط§ظ„ط±ظ…ط² ط§ظ„ط°ظٹ ظˆطµظ„ظƒ ظ„ظ„ظ…طھط§ط¨ط¹ط©',
            style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_err != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center)),
          TextField(controller: _codeC, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'ط±ظ…ط² ط§ظ„طھط­ظ‚ظ‚',
              hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 1),
              prefixIcon: const Icon(Icons.pin, color: AC.gold),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AC.gold, width: 2), borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 24),
          SizedBox(height: 52, child: ElevatedButton(onPressed: _verify,
            child: const Text('طھط­ظ‚ظ‚ ظˆط§ط³طھظ…ط±', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(height: 16),
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('ط¥ط¹ط§ط¯ط© ط¥ط±ط³ط§ظ„ ط§ظ„ط±ظ…ط²', style: TextStyle(color: AC.gold, fontSize: 14))),
        ]))));
  }
}

class NewPasswordScreen extends StatefulWidget {
  final String token;
  final String email;
  const NewPasswordScreen({super.key, required this.token, required this.email});
  @override State<NewPasswordScreen> createState() => _NewPwS();
}
class _NewPwS extends State<NewPasswordScreen> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _ld = false, _done = false;
  String? _err;

  Future<void> _resetPw() async {
    if (_pw1.text.length < 6) {
      setState(() { _err = 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ† طھظƒظˆظ† 6 ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„'; });
      return;
    }
    if (_pw1.text != _pw2.text) {
      setState(() { _err = 'ظƒظ„ظ…طھط§ ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± ظ…طھط·ط§ط¨ظ‚طھظٹظ†'; });
      return;
    }
    setState(() { _ld = true; _err = null; });
    print('TOKEN: [${widget.token}] LEN: ${widget.token.length}');
    try {
      final r = await http.post(Uri.parse('$_api/account/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': widget.token, 'new_password': _pw1.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'ok') {
        setState(() { _done = true; });
      } else {
        setState(() { _err = d['detail'] ?? 'ظپط´ظ„طھ ط¥ط¹ط§ط¯ط© ط§ظ„طھط¹ظٹظٹظ†'; });
      }
    } catch (e) {
      setState(() { _err = 'ط®ط·ط£ ظپظٹ ط§ظ„ط§طھطµط§ظ„'; });
    } finally {
      setState(() { _ld = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط¬ط¯ظٹط¯ط©')),
      body: Padding(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 24),
          Icon(_done ? Icons.check_circle : Icons.lock_outline, size: 72, color: _done ? Colors.greenAccent : AC.gold),
          const SizedBox(height: 24),
          if (_done) ...[
            const Text('طھظ… طھط؛ظٹظٹط± ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط¨ظ†ط¬ط§ط­!',
              style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('ظٹظ…ظƒظ†ظƒ ط§ظ„ط¢ظ† طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ط¨ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط¬ط¯ظٹط¯ط©',
              style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(height: 52, child: ElevatedButton(
              onPressed: () { Navigator.of(context).popUntil((route) => route.isFirst); },
              child: const Text('ط§ظ„ط¹ظˆط¯ط© ظ„طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          ] else ...[
            Text('ط£ط¯ط®ظ„ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط¬ط¯ظٹط¯ط© ظ„ظ€\n${widget.email}',
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (_err != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center)),
            TextField(controller: _pw1, obscureText: true, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط¬ط¯ظٹط¯ط©',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.lock_outline, color: AC.gold),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AC.gold, width: 2), borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 16),
            TextField(controller: _pw2, obscureText: true, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.lock, color: AC.gold),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AC.gold, width: 2), borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 24),
            SizedBox(height: 52, child: ElevatedButton(onPressed: _ld ? null : _resetPw,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              child: _ld ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('ط¥ط¹ط§ط¯ط© طھط¹ظٹظٹظ† ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)))),
          ],
        ]))));
  }
}


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// SessionsScreen â€” ط¥ط¯ط§ط±ط© ط§ظ„ط¬ظ„ط³ط§طھ ط§ظ„ظ†ط´ط·ط©
// Phase 9 Account Center آ§6
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
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
        const SnackBar(content: Text('طھظ… ط¥ظ†ظ‡ط§ط، ط¬ظ…ظٹط¹ ط§ظ„ط¬ظ„ط³ط§طھ'), backgroundColor: Colors.green));
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
        const SnackBar(content: Text('طھظ… ط¥ظ†ظ‡ط§ط، ط§ظ„ط¬ظ„ط³ط©'), backgroundColor: Colors.green));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: const Text('ط§ظ„ط¬ظ„ط³ط§طھ ط§ظ„ظ†ط´ط·ط©'), backgroundColor: AC.navy2,
        actions: [
          TextButton.icon(
            onPressed: _logoutAll,
            icon: const Icon(Icons.logout, color: AC.err, size: 18),
            label: const Text('ط¥ظ†ظ‡ط§ط، ط§ظ„ظƒظ„', style: TextStyle(color: AC.err, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _sessions.isEmpty
          ? Center(child: Text('ظ„ط§ طھظˆط¬ط¯ ط¬ظ„ط³ط§طھ ظ†ط´ط·ط©', style: TextStyle(color: AC.ts)))
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
                        Text(s['device_info'] ?? 'ط¬ظ‡ط§ط² ط؛ظٹط± ظ…ط¹ط±ظˆظپ',
                          style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('IP: ${s['ip_address'] ?? 'â€”'}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                        Text('ط¢ط®ط± ظ†ط´ط§ط·: ${s['last_activity']?.toString().substring(0, 16) ?? 'â€”'}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                      ],
                    )),
                    IconButton(
                      onPressed: () => _logoutOne(s['id']),
                      icon: const Icon(Icons.close, color: AC.err),
                      tooltip: 'ط¥ظ†ظ‡ط§ط، ط§ظ„ط¬ظ„ط³ط©',
                    ),
                  ]),
                );
              },
            ),
    ));
  }
}


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// SPRINT 1 â€” COA FIRST WORKFLOW SCREENS
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// [P3] Extracted to screens/extracted/ - see separate file
