import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

const _api = 'https://apex-api-ootk.onrender.com';
void main() => runApp(const ApexApp());

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const textPrimary = Color(0xFFF0EDE6);
  static const textSecondary = Color(0xFF8A8880);
  static const success = Color(0xFF2ECC8A);
  static const warning = Color(0xFFF0A500);
  static const danger = Color(0xFFE05050);
  static const border = Color(0x26C9A84C);
}

class AppState {
  static String? token, userId, username, displayName, plan;
  static List<String> roles = [];
  static Map<String, String> authHeaders() => {'Authorization': 'Bearer ${token ?? ""}', 'Content-Type': 'application/json'};
  static void clear() { token = null; userId = null; username = null; displayName = null; plan = null; roles = []; }
}

class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'APEX', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AC.navy,
      appBarTheme: const AppBarTheme(backgroundColor: AC.navy2, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AC.gold, foregroundColor: AC.navy,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    home: const LoginScreen());
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}
class _LoginState extends State<LoginScreen> {
  final _u = TextEditingController(), _p = TextEditingController();
  bool _l = false; String? _e;
  Future<void> _login() async {
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/login'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username_or_email': _u.text.trim(), 'password': _p.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        AppState.token = d['tokens']['access_token']; AppState.userId = d['user']['id'];
        AppState.username = d['user']['username']; AppState.displayName = d['user']['display_name'];
        AppState.plan = d['user']['plan']; AppState.roles = List<String>.from(d['user']['roles'] ?? []);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNav()));
      } else { setState(() => _e = d['detail'] ?? d['error'] ?? 'error'); }
    } catch (e) { setState(() => _e = '$e'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('APEX', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AC.gold, letterSpacing: 8)),
      const SizedBox(height: 8), const Text('Financial Analysis Platform', style: TextStyle(color: AC.textSecondary, fontSize: 14)),
      const SizedBox(height: 48),
      TextField(controller: _u, decoration: InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person_outline, color: AC.gold),
        filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 16),
      TextField(controller: _p, obscureText: true, decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: AC.gold),
        filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onSubmitted: (_) => _login()),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.danger, fontSize: 13))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l ? null : _login,
        child: _l ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy)) : const Text('Login'))),
      const SizedBox(height: 16),
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegScreen())),
        child: const Text('Create Account', style: TextStyle(color: AC.gold))),
    ])))));
}

class RegScreen extends StatefulWidget {
  const RegScreen({super.key});
  @override State<RegScreen> createState() => _RegState();
}
class _RegState extends State<RegScreen> {
  final _un = TextEditingController(), _em = TextEditingController(), _dn = TextEditingController(), _pw = TextEditingController();
  bool _l = false; String? _e;
  Future<void> _reg() async {
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/register'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _un.text.trim(), 'email': _em.text.trim(), 'display_name': _dn.text.trim(), 'password': _pw.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        AppState.token = d['tokens']['access_token']; AppState.userId = d['user']['id'];
        AppState.username = d['user']['username']; AppState.displayName = d['user']['display_name']; AppState.plan = d['user']['plan'];
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNav()));
      } else { setState(() => _e = d['detail'] ?? d['error'] ?? 'error'); }
    } catch (e) { setState(() => _e = '$e'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Register')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _un, decoration: InputDecoration(labelText: 'Username *', filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12), TextField(controller: _em, decoration: InputDecoration(labelText: 'Email *', filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12), TextField(controller: _dn, decoration: InputDecoration(labelText: 'Display Name *', filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12), TextField(controller: _pw, obscureText: true, decoration: InputDecoration(labelText: 'Password *', filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.danger, fontSize: 13))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l ? null : _reg, child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Create Account'))),
      ])))));
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override State<MainNav> createState() => _MainNavState();
}
class _MainNavState extends State<MainNav> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: [const DashTab(), const ClientsTab(), const AnalysisTab(), const AccountTab()][_i],
    bottomNavigationBar: BottomNavigationBar(currentIndex: _i, onTap: (i) => setState(() => _i = i),
      type: BottomNavigationBarType.fixed, backgroundColor: AC.navy2, selectedItemColor: AC.gold, unselectedItemColor: AC.textSecondary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.business_rounded), label: 'Clients'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Analysis'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Account'),
      ]));
}

class DashTab extends StatefulWidget { const DashTab({super.key}); @override State<DashTab> createState() => _DashState(); }
class _DashState extends State<DashTab> {
  Map<String, dynamic>? _sub; List _plans = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/subscriptions/me'), headers: AppState.authHeaders());
      final r2 = await http.get(Uri.parse('$_api/plans'));
      if (mounted) setState(() { _sub = jsonDecode(r1.body); _plans = jsonDecode(r2.body); _ld = false; });
    } catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Welcome ${AppState.displayName ?? ""}', style: const TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.workspace_premium, color: AC.gold, size: 28), const SizedBox(width: 12),
            Text('Plan: ${_sub?['plan_name_ar'] ?? 'Free'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.textPrimary))]),
          const SizedBox(height: 12),
          ...(_sub?['entitlements'] as Map<String, dynamic>? ?? {}).entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(e.value['value'] == 'true' || e.value['value'] == 'unlimited' ? Icons.check_circle : e.value['value'] == 'false' ? Icons.cancel : Icons.info_outline,
                color: e.value['value'] == 'true' || e.value['value'] == 'unlimited' ? AC.success : e.value['value'] == 'false' ? AC.danger : AC.cyan, size: 16),
              const SizedBox(width: 8), Expanded(child: Text('${e.key}: ${e.value['value']}', style: const TextStyle(color: AC.textSecondary, fontSize: 12)))]))),
        ])),
      const SizedBox(height: 20), const Text('Available Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.textPrimary)),
      ..._plans.map((p) => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: p['code'] == _sub?['plan'] ? AC.gold : AC.border)),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['name_ar'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p['code'] == _sub?['plan'] ? AC.gold : AC.textPrimary)),
          Text(p['target_user_ar'] ?? '', style: const TextStyle(color: AC.textSecondary, fontSize: 12))])),
          Text(p['price_monthly_sar'] == 0 ? 'Free' : '${p['price_monthly_sar']} SAR/mo', style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold))]))),
    ]));
}

class ClientsTab extends StatefulWidget { const ClientsTab({super.key}); @override State<ClientsTab> createState() => _ClientsState(); }
class _ClientsState extends State<ClientsTab> {
  List _cl = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await http.get(Uri.parse('$_api/clients'), headers: AppState.authHeaders()); if (mounted) setState(() { _cl = jsonDecode(r.body); _ld = false; }); }
    catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Clients', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton(backgroundColor: AC.gold, onPressed: () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewClientScreen())); _load();
    }, child: const Icon(Icons.add, color: AC.navy)),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _cl.isEmpty ? const Center(child: Text('No clients yet', style: TextStyle(color: AC.textSecondary))) :
      ListView.builder(padding: const EdgeInsets.all(16), itemCount: _cl.length, itemBuilder: (_, i) {
        final c = _cl[i];
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
          child: Row(children: [
            CircleAvatar(backgroundColor: AC.navy4, child: Text((c['name_ar'] ?? '?')[0], style: const TextStyle(color: AC.gold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['name_ar'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.textPrimary)),
              Text('${c['client_type'] ?? ''} | ${c['your_role'] ?? ''}', style: const TextStyle(color: AC.textSecondary, fontSize: 12))])),
            if (c['knowledge_mode'] == true) const Icon(Icons.psychology, color: AC.cyan, size: 20)]));
      }));
}

class NewClientScreen extends StatefulWidget { const NewClientScreen({super.key}); @override State<NewClientScreen> createState() => _NewClientState(); }
class _NewClientState extends State<NewClientScreen> {
  final _n = TextEditingController(); List _types = []; String? _t; bool _l = false; String? _e;
  @override void initState() { super.initState(); http.get(Uri.parse('$_api/client-types')).then((r) { if (mounted) setState(() => _types = jsonDecode(r.body)); }); }
  Future<void> _create() async {
    if (_n.text.trim().isEmpty || _t == null) { setState(() => _e = 'Name and type required'); return; }
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/clients'), headers: AppState.authHeaders(),
        body: jsonEncode({'name_ar': _n.text.trim(), 'client_type_code': _t}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) { if (mounted) Navigator.pop(context); }
      else { setState(() => _e = d['detail'] ?? d['error']); }
    } catch (e) { setState(() => _e = '$e'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('New Client')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _n, decoration: InputDecoration(labelText: 'Company Name *', filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 16), const Text('Client Type *', style: TextStyle(color: AC.textSecondary)),
      ..._types.map((t) => RadioListTile<String>(value: t['code'], groupValue: _t, onChanged: (v) => setState(() => _t = v),
        title: Text(t['name_ar'] ?? '', style: const TextStyle(color: AC.textPrimary)),
        subtitle: t['knowledge_mode_eligible'] == true ? const Text('Knowledge Mode', style: TextStyle(color: AC.cyan, fontSize: 11)) :
          Text(t['name_en'] ?? '', style: const TextStyle(color: AC.textSecondary, fontSize: 11)),
        activeColor: AC.gold, dense: true)),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.danger))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l ? null : _create, child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Create Client')))])));
}

class AnalysisTab extends StatefulWidget { const AnalysisTab({super.key}); @override State<AnalysisTab> createState() => _AnalysisState(); }
class _AnalysisState extends State<AnalysisTab> {
  PlatformFile? _f; List<int>? _fb; bool _a = false; Map<String, dynamic>? _r; String? _e;
  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
    if (r != null && r.files.isNotEmpty) setState(() { _f = r.files.first; _fb = r.files.first.bytes?.toList(); _r = null; _e = null; });
  }
  Future<void> _run() async {
    if (_fb == null) return; setState(() { _a = true; _e = null; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_api/analyze?industry=retail'));
      req.headers['Authorization'] = 'Bearer ${AppState.token}';
      req.files.add(http.MultipartFile.fromBytes('file', _fb!, filename: 'tb.xlsx'));
      final res = await req.send(); final body = await res.stream.bytesToString();
      setState(() { _r = jsonDecode(body); _a = false; });
    } catch (e) { setState(() { _e = '$e'; _a = false; }); }
  }
  String _fmt(dynamic v) { if (v == null) return '-'; final d = (v is int) ? v.toDouble() : (v is double) ? v : 0.0; if (d.abs() >= 1e6) return '${(d/1e6).toStringAsFixed(2)}M'; if (d.abs() >= 1e3) return '${(d/1e3).toStringAsFixed(1)}K'; return d.toStringAsFixed(2); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Financial Analysis', style: TextStyle(color: AC.gold))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      GestureDetector(onTap: _pick, child: Container(width: double.infinity, height: 120,
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: _f != null ? AC.gold : AC.border)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_f != null ? Icons.check_circle : Icons.cloud_upload_outlined, color: _f != null ? AC.success : AC.gold, size: 36),
          const SizedBox(height: 8), Text(_f?.name ?? 'Upload Trial Balance', style: TextStyle(color: _f != null ? AC.textPrimary : AC.textSecondary))]))),
      const SizedBox(height: 16),
      if (_f != null && _r == null) SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _a ? null : _run,
        child: _a ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy)), SizedBox(width: 12), Text('Analyzing...')]) : const Text('Start Analysis'))),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.danger))),
      if (_r != null && _r!['success'] == true) ...[
        const SizedBox(height: 20),
        _card('Confidence', [_kv('Score', '${((_r!['confidence']?['overall'] ?? 0) * 100).toStringAsFixed(1)}%'), _kv('Label', _r!['confidence']?['label'] ?? '')]),
        _card('Income Statement', [_kv('Net Revenue', _fmt(_r!['income_statement']?['net_revenue'])), _kv('COGS', _fmt(_r!['income_statement']?['cogs'])),
          _kv('Gross Profit', _fmt(_r!['income_statement']?['gross_profit'])), _kv('Net Profit', _fmt(_r!['income_statement']?['net_profit']))]),
        _card('Balance Sheet', [_kv('Assets', _fmt(_r!['balance_sheet']?['total_assets'])), _kv('Liabilities', _fmt(_r!['balance_sheet']?['total_liabilities'])),
          _kv('Balanced', _r!['balance_sheet']?['is_balanced'] == true ? 'Yes' : 'No')]),
        if (_r!['knowledge_brain'] != null) _card('Knowledge Brain', [_kv('Rules', '${_r!['knowledge_brain']?['rules_triggered'] ?? 0}/${_r!['knowledge_brain']?['rules_evaluated'] ?? 0}')]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => setState(() { _f = null; _fb = null; _r = null; }),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)), child: const Text('Analyze Another', style: TextStyle(color: AC.gold)))),
      ]])));
  Widget _card(String t, List<Widget> c) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16)), const Divider(color: AC.border, height: 20), ...c]));
  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.textSecondary, fontSize: 13)), Text(v, style: const TextStyle(color: AC.textPrimary, fontSize: 14))]));
}

class AccountTab extends StatefulWidget { const AccountTab({super.key}); @override State<AccountTab> createState() => _AccountState(); }
class _AccountState extends State<AccountTab> {
  Map<String, dynamic>? _p, _s; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/users/me'), headers: AppState.authHeaders());
      final r2 = await http.get(Uri.parse('$_api/users/me/security'), headers: AppState.authHeaders());
      if (mounted) setState(() { _p = jsonDecode(r1.body); _s = jsonDecode(r2.body); _ld = false; });
    } catch (_) { if (mounted) setState(() => _ld = false); }
  }
  void _logout() { http.post(Uri.parse('$_api/auth/logout'), headers: AppState.authHeaders()); AppState.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Account', style: TextStyle(color: AC.gold)), actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: AC.danger))]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.border)),
        child: Column(children: [
          CircleAvatar(radius: 36, backgroundColor: AC.navy4, child: Text((_p?['user']?['display_name'] ?? '?')[0], style: const TextStyle(fontSize: 28, color: AC.gold))),
          const SizedBox(height: 12), Text(_p?['user']?['display_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.textPrimary)),
          Text('@${_p?['user']?['username'] ?? ''}', style: const TextStyle(color: AC.textSecondary)),
          const SizedBox(height: 8), Text(_p?['user']?['email'] ?? '', style: const TextStyle(color: AC.textSecondary, fontSize: 13))])),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Security', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
          _ir('Active Sessions', '${_s?['active_sessions'] ?? 0}'), _ir('Login Count', '${_s?['login_count'] ?? 0}'), _ir('Last Login', _s?['last_login'] ?? '-')])),
      const SizedBox(height: 16),
      _mi(Icons.workspace_premium, 'Plan: ${AppState.plan ?? "free"}', AC.gold),
      _mi(Icons.notifications_outlined, 'Notifications', AC.cyan),
      _mi(Icons.shield_outlined, 'Change Password', AC.warning),
    ]));
  Widget _ir(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: const TextStyle(color: AC.textSecondary, fontSize: 13)), Text(v, style: const TextStyle(color: AC.textPrimary, fontSize: 13))]));
  Widget _mi(IconData i, String l, Color c) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
    child: ListTile(leading: Icon(i, color: c), title: Text(l, style: const TextStyle(color: AC.textPrimary)), trailing: const Icon(Icons.chevron_right, color: AC.textSecondary)));
}
