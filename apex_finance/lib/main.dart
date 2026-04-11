import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screens/dashboard/enhanced_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';
import 'package:go_router/go_router.dart';
import 'core/router.dart';
import 'core/session.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';

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
  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
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

  @override
  void initState() {
    super.initState();
    // DEMO MODE: auto-login if ?demo=1 in URL
    final search = html.window.location.search ?? '';
    final hash = html.window.location.hash;
    if (search.contains('demo=1') || hash.contains('demo=1')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _u.text = 'shady';
        _p.text = 'Aa@123456';
        _go();
      });
    }
  }

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() { _l = true; _e = null; });
    try {
      final res = await ApiService.login(_u.text.trim(), _p.text);
      if (res.success) {
        final d = res.data;
        S.token = d['tokens']['access_token']; S.uid = d['user']['id'];
        S.uname = d['user']['username']; S.dname = d['user']['display_name'];
        S.plan = d['user']['plan']; S.email = d['user']['email'];
        S.roles = List<String>.from(d['user']['roles'] ?? []);
        ApiService.setToken(S.token!);
        S.save();
      } else { setState(() { _e = res.error ?? '\u062e\u0637\u0623 \u0641\u064a \u0627\u0644\u062f\u062e\u0648\u0644'; _l = false; }); }
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
            color: AC.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AC.gold.withValues(alpha: 0.2)),
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
          decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.err.withValues(alpha: 0.3))),
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
            disabledBackgroundColor: AC.gold.withValues(alpha: 0.5)),
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
  @override
  void dispose() {
    _un.dispose();
    _em.dispose();
    _dn.dispose();
    _pw.dispose();
    super.dispose();
  }
  Future<void> _go() async {
    setState((){ _l=true; _e=null; });
    try {
      final res = await ApiService.register(username: _un.text.trim(), email: _em.text.trim(), displayName: _dn.text.trim(), password: _pw.text);
      if(res.success) {
        final d = res.data;
        S.token=d['tokens']['access_token']; S.uid=d['user']['id'];
        S.uname=d['user']['username']; S.dname=d['user']['display_name'];
        S.plan=d['user']['plan']; S.email=d['user']['email'];
        ApiService.setToken(S.token!);
        S.save();
        if(mounted) context.go('/home');
      } else { setState(()=> _e=res.error??'\u062e\u0637\u0623'); }
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
  String _userName = S.dname ?? 'User';
  String _clientLabel = '\u0644\u0645 \u064a\u062a\u0645 \u0627\u062e\u062a\u064a\u0627\u0631 \u0639\u0645\u064a\u0644';
  @override
  void initState() {
    super.initState();
      Future.delayed(const Duration(milliseconds: 500), () {
      if(S.token!=null) ApiService.setToken(S.token!);
      ApiService.listClients().then((r) { if (r.success && mounted) { final d = r.data; setState(() => _cl = d is List ? d : []); } });
      ApiService.getNotifications().then((r) { if (r.success && mounted) { final d = r.data; setState(() => _notifs = d is List ? d : []); } });
      if (mounted) setState(() {});
    });
  }


  @override Widget build(BuildContext c) {
    final tabs = [EnhancedDashboard(
          onSwitchToClients: () => setState(() => _i = 1),
          onCreateClient: () {
            setState(() => _i = 1);
            // Trigger create wizard after tab switch
          },
          onNavigateToCoa: _goToCoa,
        ), const ClientsTab(), const AnalysisTab(), const MarketTab(), const ProviderTab(), const AccountTab(), const AdminTab()];
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
        ExpansionTile(
          trailing: const Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('الأساسي', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.w700)),
          initiallyExpanded: true,
          children: [
          _drawerItem(Icons.dashboard_rounded, 'الرئيسية', () { setState(() { _i = 0; _dr = false; }); }),
          _drawerItem(Icons.smart_toy, 'Apex Copilot', () { context.push('/copilot'); setState(() => _dr = false); }, isGold: true),
          _drawerItem(Icons.business_rounded, 'العملاء', () { setState(() { _i = 1; _dr = false; }); }),
          ],
        ),
        ExpansionTile(
          trailing: const Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('المسار المالي', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.w700)),
          initiallyExpanded: true,
          children: [
          _drawerItem(Icons.account_tree, 'شجرة الحسابات COA', () => _goToCoa(), isGold: true),
          _drawerItem(Icons.table_chart, 'ميزان المراجعة TB', () { context.push('/financial-ops'); setState(() => _dr = false); }),
          _drawerItem(Icons.receipt_long, 'القوائم المالية', () { context.push('/financial-ops'); setState(() => _dr = false); }),
          _drawerItem(Icons.analytics_rounded, 'التحليل المالي', () { setState(() { _i = 2; _dr = false; }); }),
          ],
        ),
        ExpansionTile(
          trailing: const Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('الجاهزية والامتثال', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.shield_rounded, 'الجاهزية التمويلية', () { _comingSoon(); }),
          _drawerItem(Icons.checklist_rounded, 'الامتثال', () { _comingSoon(); }),
          _drawerItem(Icons.workspace_premium, 'الأهلية الترخيصية', () { _comingSoon(); }),
          _drawerItem(Icons.volunteer_activism, 'الدعم والحوافز', () { _comingSoon(); }),
          _drawerItem(Icons.gavel_rounded, 'المراجعة المحاسبية والقانونية', () { context.push('/audit-workflow'); setState(() => _dr = false); }),
          ],
        ),
        ExpansionTile(
          trailing: const Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('السوق', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.store_rounded, 'سوق الخدمات', () { setState(() { _i = 3; _dr = false; }); }),
          _drawerItem(Icons.work_rounded, 'مقدمو الخدمات', () { context.push('/provider-kanban'); setState(() => _dr = false); }),
          _drawerItem(Icons.menu_book, 'Bookkeeping', () { _comingSoon(); }),
          ],
        ),
        ExpansionTile(
          trailing: const Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('التقارير والمعرفة', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.bar_chart_rounded, 'التقارير', () { _comingSoon(); }),
          _drawerItem(Icons.folder_outlined, 'الأرشيف', () { context.go('/archive'); setState(() => _dr = false); }),
          _drawerItem(Icons.psychology, 'العقل المعرفي', () { context.push('/knowledge-brain'); setState(() => _dr = false); }),
          _drawerItem(Icons.admin_panel_settings, 'Reviewer Console', () { context.go('/admin/reviewer'); setState(() => _dr = false); }),
          ],
        ),
        ExpansionTile(
          trailing: const Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('الإدارة', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.settings, 'الإدارة والإعدادات', () { context.push('/settings'); setState(() => _dr = false); }),
          _drawerItem(Icons.diamond_outlined, 'الحساب والاشتراكات', () { setState(() { _i = 5; _dr = false; }); }),
          ],
        ),
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


  /// Smart COA navigation — checks top-bar client selection (v6.7)
  void _goToCoa() {
    setState(() => _dr = false);
    if (_activeClients.isEmpty) {
      _showCoaDialog(
        '\u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644',
        '\u0628\u0631\u062c\u0627\u0621 \u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644 \u0645\u0646 \u0627\u0644\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0639\u0644\u0648\u064a\u0629 \u0623\u0648\u0644\u0627\u064b',
        Icons.person_search,
      );
      return;
    }
    if (_activeClients.length > 1) {
      _showCoaDialog(
        '\u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644 \u0648\u0627\u062d\u062f',
        '\u0628\u0631\u062c\u0627\u0621 \u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644 \u0648\u0627\u062d\u062f \u0641\u0642\u0637 \u0644\u0641\u062a\u062d \u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a',
        Icons.warning_amber_rounded,
      );
      return;
    }
    final selectedName = _activeClients.first;
    final client = _cl.firstWhere(
      (c) => (c['name_ar'] ?? c['name'] ?? '') == selectedName,
      orElse: () => null,
    );
    if (client != null) {
      context.push('/coa/journey', extra: {
        'clientId': (client['id'] ?? client['client_code'] ?? '1').toString(),
        'clientName': client['name_ar'] ?? client['name'] ?? '',
      });
    } else {
      _showCoaDialog(
        '\u062e\u0637\u0623',
        '\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0639\u0645\u064a\u0644',
        Icons.error_outline,
      );
    }
  }

  void _showCoaDialog(String title, String message, IconData icon) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D1825),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x33C9A84C), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: const Color(0xFFC9A84C), size: 48),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE8E0D0), fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A84C),
                foregroundColor: const Color(0xFF050D1A),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('\u062d\u0633\u0646\u0627\u064b', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }


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
            onPressed: ()=>context.push('/upgrade-plan', extra: {'plans': _plans, 'currentPlan': _sub?['plan']}),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.smart_toy, color: AC.gold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
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
    try { final r = await ApiService.getNotifications();
      if(mounted) setState(() { final d = r.data; _nots = d is List ? d : []; _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _markAllRead() async {
    await ApiService.markNotificationsReadAll();
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
            border: Border.all(color: isRead ? AC.bdr : AC.gold.withValues(alpha: 0.3))),
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
                  color: f.value['value']=='true'||f.value['value']=='unlimited'?AC.ok:AC.err.withValues(alpha: 0.5), size: 14),
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
  List _cl=[]; bool _ld=true; String _search='';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _ld = true);
    try {
      final r = await ApiService.listClients();
      if (mounted) setState(() { final d = r.data; _cl = d is List ? d : []; _ld = false; });
    } catch(e) {
      if (mounted) setState(() { _cl = []; _ld = false; });
    }
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
  @override void dispose() {
    _cName.dispose(); _cNameAr.dispose(); _cEmail.dispose();
    _cPhone.dispose(); _cCR.dispose(); _cVAT.dispose(); _cAddress.dispose();
    super.dispose();
  }

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
          decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.gold.withValues(alpha: 0.3))),
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
  @override Widget build(BuildContext c) {
    final filtered = _search.isEmpty ? _cl : _cl.where((c2) {
      final name = (c2['name_ar'] ?? c2['name'] ?? '').toString().toLowerCase();
      final type = (c2['client_type'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) || type.contains(_search.toLowerCase());
    }).toList();
    return Scaffold(
      backgroundColor: AC.navy,
      floatingActionButton: FloatingActionButton(backgroundColor: AC.gold, child: const Icon(Icons.add, color: AC.navy),
        onPressed: () => _showNewClientWizard(c)),
      body: Column(children: [
        // Header with title + search
        Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('العملاء', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Text('${_cl.length} عميل', style: const TextStyle(color: AC.ts, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: AC.tp, fontSize: 13),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'بحث عن عميل...',
                hintStyle: const TextStyle(color: AC.ts, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AC.ts, size: 20),
                filled: true, fillColor: AC.navy3, isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AC.gold)),
              ),
            ),
          ]),
        ),
        // Client list
        Expanded(child: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
          filtered.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.business_outlined, color: AC.ts, size: 60), const SizedBox(height: 12),
            Text(_cl.isEmpty ? 'لا يوجد عملاء بعد' : 'لا نتائج', style: const TextStyle(color: AC.ts, fontSize: 14)),
          ])) :
          RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), itemCount: filtered.length, itemBuilder: (_, i) {
              final c2 = filtered[i];
              final name = c2['name_ar'] ?? c2['name'] ?? '';
              final type = c2['client_type'] ?? '';
              final role = c2['your_role'] ?? '';
              return InkWell(
                onTap: () => context.push('/client-detail', extra: {'id': (c2['id'] ?? '').toString(), 'name': name}),
                child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.bdr)),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: const Color(0xFFC9A84C).withValues(alpha: 0.15), radius: 24,
                      child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AC.tp, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (type.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(type, style: const TextStyle(color: AC.gold, fontSize: 10))),
                        if (type.isNotEmpty && role.isNotEmpty) const SizedBox(width: 8),
                        if (role.isNotEmpty) Text(role, style: const TextStyle(color: AC.ts, fontSize: 11)),
                      ]),
                    ])),
                    const Icon(Icons.chevron_left, color: AC.ts, size: 20),
                  ])));
            }))),
      ]),
    );
  }
}

class NewClientScreen extends StatefulWidget { const NewClientScreen({super.key}); @override State<NewClientScreen> createState()=>_NewCS(); }
class _NewCS extends State<NewClientScreen> {
  final _n=TextEditingController(); List _types=[]; String? _t; bool _l=false; String? _e;
  @override void initState() { super.initState(); ApiService.getClientTypes().then((r){ if(r.success && mounted) { final d = r.data; setState(()=> _types = d is List ? d : []); } }); }
  @override
  void dispose() {
    _n.dispose();
    super.dispose();
  }
  Future<void> _go() async {
    if(_n.text.trim().isEmpty||_t==null){ setState(()=> _e='\u0627\u0644\u0627\u0633\u0645 \u0648\u0627\u0644\u0646\u0648\u0639 \u0645\u0637\u0644\u0648\u0628\u0627\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final res = await ApiService.createClient(clientCode: _n.text.trim().replaceAll(' ', '_'), name: _n.text.trim(), nameAr: _n.text.trim(), clientType: _t!);
      if(res.success) { if(mounted) Navigator.pop(context); }
      else { setState(()=> _e=res.error); }
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
          decoration: BoxDecoration(color: _t==t['code'] ? AC.gold.withValues(alpha: 0.1) : AC.navy3,
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
      final result = await ApiService.analyzeQuick(bytes: _fb!, fileName: 'tb.xlsx');
      setState((){ _r = result.data; _a=false; if(!result.success) _e = result.error; });
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
        Container(width: 22, height: 22, decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
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
          Expanded(child: OutlinedButton.icon(onPressed: ()=>context.push('/knowledge/feedback-form', extra: {'resultId': _r?['result_id']}),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.cyan)),
            icon: const Icon(Icons.feedback_outlined, color: AC.cyan, size: 18),
            label: const Text('\u0645\u0644\u0627\u062d\u0638\u0629 \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.cyan)))),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () async {
            try {
              final result = await ApiService.analyzeReport(bytes: _fb!, fileName: 'tb.xlsx');
              if (result.success) {
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
  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }
  Future<void> _submit() async {
    if(_title.text.trim().isEmpty) { setState(()=> _e='\u0627\u0644\u0639\u0646\u0648\u0627\u0646 \u0645\u0637\u0644\u0648\u0628'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await ApiService.submitKnowledgeFeedback({'feedback_type':_type,'title':_title.text.trim(),'description':_desc.text.trim()});
      if(r.success) setState(()=> _done=true);
      else setState(()=> _e=r.error);
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
          decoration: BoxDecoration(color: _type==t['code'] ? AC.gold.withValues(alpha: 0.1) : AC.navy3,
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
    appBar: AppBar(title: const Text('\u0627\u0644\u0645\u0639\u0631\u0636', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: AC.gold,
      onPressed: ()=> context.push('/marketplace/new-request'),
      icon: const Icon(Icons.add, color: AC.navy), label: const Text('\u0637\u0644\u0628 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.navy))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      ListView(padding: const EdgeInsets.all(14), children: [
        Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold)), child: Column(children: [const Icon(Icons.store_mall_directory, color: AC.gold, size: 36), const SizedBox(height: 8), const Text("ظƒطھط§ظ„ظˆط¬ ط§ظ„ط®ط¯ظ…ط§طھ ط§ظ„ظ…ظ‡ظ†ظٹط©", style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), const Text("طھطµظپط­ 6 ط®ط¯ظ…ط§طھ: طھط­ظ„ظٹظ„ ظ…ط§ظ„ظٹطŒ ظ…ط±ط§ط¬ط¹ط©طŒ ط¶ط±ط§ط¦ط¨طŒ طھظ…ظˆظٹظ„طŒ ط¯ط¹ظ…طŒ طھط±ط§ط®ظٹطµ", style: TextStyle(color: AC.ts, fontSize: 12), textAlign: TextAlign.center), const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => context.push('/service-catalog', extra: {'clientId': '', 'token': S.token}), icon: const Icon(Icons.arrow_forward), label: const Text("ظپطھط­ ط§ظ„ظƒطھط§ظ„ظˆط¬")))])),
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
    ApiService.listClients().then((r){ if(r.success && mounted) { final d = r.data; setState((){ _clients = d is List ? d : []; }); } }); }
  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _budget.dispose();
    super.dispose();
  }
  Future<void> _go() async {
    if(_title.text.isEmpty||_clientId==null) { setState(()=> _e='\u0627\u0644\u0639\u0646\u0648\u0627\u0646 \u0648\u0627\u0644\u0639\u0645\u064a\u0644 \u0645\u0637\u0644\u0648\u0628\u0627\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await ApiService.createServiceRequest({'client_id':_clientId,'title':_title.text.trim(),'description':_desc.text.trim(),
        'urgency':_urgency,'budget_sar':double.tryParse(_budget.text)??0,'deadline_days':14});
      if(r.success) setState(()=> _done=true);
      else setState(()=> _e=r.error);
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
            decoration: BoxDecoration(color: _clientId==cl['id']?AC.gold.withValues(alpha: 0.1):AC.navy3,
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
          decoration: BoxDecoration(color: _urgency==u ? (u=='high'?AC.err:u=='medium'?AC.warn:AC.ok).withValues(alpha: 0.15) : AC.navy3,
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
    appBar: AppBar(title: const Text('\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _notProvider ? SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.verified_user_outlined, color: AC.gold, size: 60), const SizedBox(height: 16),
        const Text('\u0643\u0646 \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629 \u0645\u0639\u062a\u0645\u062f', style: TextStyle(color: AC.tp, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ..._cats.map((cat) => GestureDetector(onTap: ()=>setState(()=>_sel=cat['code']),
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _sel==cat['code']?AC.gold.withValues(alpha: 0.1):AC.navy3,
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
      final r1 = await ApiService.getProfile();
      final r2 = await ApiService.getSecuritySettings();
      if(mounted) setState((){ _p=r1.data is Map ? r1.data : null; _s=r2.data is Map ? r2.data : null; _ld=false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  void _logout() { ApiService.logout(); S.clear();
    ApiService.clearToken(); context.go('/login'); }
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
            OutlinedButton.icon(onPressed: ()=> context.push('/profile/edit', extra: _p),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)),
              icon: const Icon(Icons.edit, color: AC.gold, size: 16),
              label: const Text('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', style: TextStyle(color: AC.gold, fontSize: 12)))])),
        const SizedBox(height: 14),
        // Security
        _card('\u0627\u0644\u0623\u0645\u0627\u0646', [
          InkWell(onTap:(){context.push('/account/sessions');},child:_kv('\u0627\u0644\u062c\u0644\u0633\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629', '${_s?['active_sessions']??0}')),
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
          _mi(Icons.archive, 'ط§ظ„ط£ط±ط´ظٹظپ', AC.cyan, () => context.push('/archive')),
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
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [Icon(icon, color: color, size: 22), const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 11))]));

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AC.tp, fontSize: 14))),
        const Icon(Icons.chevron_left, color: AC.ts, size: 20)])));
}

