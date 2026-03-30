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
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}

class S {
  static String? token, uid, uname, dname, plan;
  static List<String> roles = [];
  static Map<String, String> h() => {'Authorization': 'Bearer ${token ?? ""}', 'Content-Type': 'application/json'};
  static void clear() { token = null; uid = null; uname = null; dname = null; plan = null; roles = []; }
}

InputDecoration _dec(String l, [IconData? ic]) => InputDecoration(labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.gold) : null,
  filled: true, fillColor: AC.navy3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.bdr)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)));

Widget _box(Widget c) => Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)), child: c);

Widget _kv(String k, String v, {Color? vc}) => Padding(padding: const EdgeInsets.only(bottom: 6),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.ts, fontSize: 13)), Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 14))]));

class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(title: 'APEX', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AC.navy, appBarTheme: const AppBarTheme(backgroundColor: AC.navy2, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    home: const LoginScreen());
}

// ═══════ LOGIN ═══════
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginS(); }
class _LoginS extends State<LoginScreen> {
  final _u = TextEditingController(), _p = TextEditingController();
  bool _l = false; String? _e;
  Future<void> _go() async {
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/login'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username_or_email': _u.text.trim(), 'password': _p.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        S.token = d['tokens']['access_token']; S.uid = d['user']['id']; S.uname = d['user']['username'];
        S.dname = d['user']['display_name']; S.plan = d['user']['plan']; S.roles = List<String>.from(d['user']['roles'] ?? []);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNav()));
      } else { setState(() => _e = d['detail'] ?? d['error'] ?? 'خطأ'); }
    } catch (e) { setState(() => _e = '$e'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('APEX', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AC.gold, letterSpacing: 8)),
      const SizedBox(height: 8), const Text('Financial Analysis Platform', style: TextStyle(color: AC.ts, fontSize: 14)),
      const SizedBox(height: 48),
      TextField(controller: _u, decoration: _dec('Username or Email', Icons.person_outline)),
      const SizedBox(height: 16),
      TextField(controller: _p, obscureText: true, decoration: _dec('Password', Icons.lock_outline), onSubmitted: (_) => _go()),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.err, fontSize: 13))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l ? null : _go,
        child: _l ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy)) : const Text('Login'))),
      const SizedBox(height: 16),
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegScreen())),
        child: const Text('Create Account', style: TextStyle(color: AC.gold))),
    ])))));
}

// ═══════ REGISTER ═══════
class RegScreen extends StatefulWidget { const RegScreen({super.key}); @override State<RegScreen> createState() => _RegS(); }
class _RegS extends State<RegScreen> {
  final _un = TextEditingController(), _em = TextEditingController(), _dn = TextEditingController(), _pw = TextEditingController();
  bool _l = false; String? _e;
  Future<void> _go() async {
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/register'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _un.text.trim(), 'email': _em.text.trim(), 'display_name': _dn.text.trim(), 'password': _pw.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        S.token = d['tokens']['access_token']; S.uid = d['user']['id']; S.uname = d['user']['username'];
        S.dname = d['user']['display_name']; S.plan = d['user']['plan'];
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNav()));
      } else { setState(() => _e = d['detail'] ?? d['error'] ?? 'خطأ'); }
    } catch (e) { setState(() => _e = '$e'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Register')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _un, decoration: _dec('Username *', Icons.alternate_email)),
        const SizedBox(height: 12), TextField(controller: _em, decoration: _dec('Email *', Icons.email_outlined)),
        const SizedBox(height: 12), TextField(controller: _dn, decoration: _dec('Display Name *', Icons.badge_outlined)),
        const SizedBox(height: 12), TextField(controller: _pw, obscureText: true, decoration: _dec('Password *', Icons.lock_outline)),
        if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.err, fontSize: 13))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l ? null : _go, child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Create Account'))),
      ])))));
}

// ═══════ MAIN NAV — 6 tabs ═══════
class MainNav extends StatefulWidget { const MainNav({super.key}); @override State<MainNav> createState() => _MainNavS(); }
class _MainNavS extends State<MainNav> {
  int _i = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: [const DashTab(), const ClientsTab(), const AnalysisTab(), const MarketTab(), const ProviderTab(), const AccountTab()][_i],
    bottomNavigationBar: BottomNavigationBar(currentIndex: _i, onTap: (i) => setState(() => _i = i),
      type: BottomNavigationBarType.fixed, backgroundColor: AC.navy2, selectedItemColor: AC.gold, unselectedItemColor: AC.ts, selectedFontSize: 11, unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.business_rounded), label: 'Clients'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Analysis'),
        BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'Market'),
        BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: 'Provider'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Account'),
      ]));
}

// ═══════ TAB 1: DASHBOARD ═══════
class DashTab extends StatefulWidget { const DashTab({super.key}); @override State<DashTab> createState() => _DashS(); }
class _DashS extends State<DashTab> {
  Map<String, dynamic>? _sub; List _plans = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/subscriptions/me'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/plans'));
      if (mounted) setState(() { _sub = jsonDecode(r1.body); _plans = jsonDecode(r2.body); _ld = false; });
    } catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Welcome ${S.dname ?? ""}', style: const TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.workspace_premium, color: AC.gold, size: 28), const SizedBox(width: 12),
          Text('Plan: ${_sub?["plan_name_ar"] ?? "Free"}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.tp))]),
        const SizedBox(height: 12),
        ...(_sub?['entitlements'] as Map<String, dynamic>? ?? {}).entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [Icon(e.value['value'] == 'true' || e.value['value'] == 'unlimited' ? Icons.check_circle : e.value['value'] == 'false' ? Icons.cancel : Icons.info_outline,
            color: e.value['value'] == 'true' || e.value['value'] == 'unlimited' ? AC.ok : e.value['value'] == 'false' ? AC.err : AC.cyan, size: 16),
            const SizedBox(width: 8), Expanded(child: Text('${e.key}: ${e.value["value"]}', style: const TextStyle(color: AC.ts, fontSize: 12)))]))),
      ])),
      const Text('Available Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.tp)),
      ..._plans.map((p) => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: p['code'] == _sub?['plan'] ? AC.gold : AC.bdr)),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['name_ar'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p['code'] == _sub?['plan'] ? AC.gold : AC.tp)),
          Text(p['target_user_ar'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 12))])),
          Text(p['price_monthly_sar'] == 0 ? 'Free' : '${p["price_monthly_sar"]} SAR/mo', style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold))]))),
    ]));
}

// ═══════ TAB 2: CLIENTS ═══════
class ClientsTab extends StatefulWidget { const ClientsTab({super.key}); @override State<ClientsTab> createState() => _ClientsS(); }
class _ClientsS extends State<ClientsTab> {
  List _cl = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await http.get(Uri.parse('$_api/clients'), headers: S.h()); if (mounted) setState(() { _cl = jsonDecode(r.body); _ld = false; }); }
    catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Clients', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton(backgroundColor: AC.gold, onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewClientScreen())); _load(); },
      child: const Icon(Icons.add, color: AC.navy)),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _cl.isEmpty ? const Center(child: Text('No clients yet', style: TextStyle(color: AC.ts))) :
      ListView.builder(padding: const EdgeInsets.all(16), itemCount: _cl.length, itemBuilder: (_, i) { final c = _cl[i];
        return _box(Row(children: [CircleAvatar(backgroundColor: AC.navy4, child: Text((c['name_ar'] ?? '?')[0], style: const TextStyle(color: AC.gold))),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['name_ar'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.tp)),
            Text('${c["client_type"] ?? ""} | ${c["your_role"] ?? ""}', style: const TextStyle(color: AC.ts, fontSize: 12))])),
          if (c['knowledge_mode'] == true) const Icon(Icons.psychology, color: AC.cyan, size: 20)])); }));
}

class NewClientScreen extends StatefulWidget { const NewClientScreen({super.key}); @override State<NewClientScreen> createState() => _NewCS(); }
class _NewCS extends State<NewClientScreen> {
  final _n = TextEditingController(); List _types = []; String? _t; bool _l = false; String? _e;
  @override void initState() { super.initState(); http.get(Uri.parse('$_api/client-types')).then((r) { if (mounted) setState(() => _types = jsonDecode(r.body)); }); }
  Future<void> _go() async {
    if (_n.text.trim().isEmpty || _t == null) { setState(() => _e = 'Name and type required'); return; }
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/clients'), headers: S.h(), body: jsonEncode({'name_ar': _n.text.trim(), 'client_type_code': _t}));
      if (jsonDecode(r.body)['success'] == true) { if (mounted) Navigator.pop(context); } else { setState(() => _e = jsonDecode(r.body)['detail']); }
    } catch (e) { setState(() => _e = '$e'); } finally { if (mounted) setState(() => _l = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('New Client')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _n, decoration: _dec('Company Name *')),
      const SizedBox(height: 16), const Text('Client Type *', style: TextStyle(color: AC.ts)),
      ..._types.map((t) => RadioListTile<String>(value: t['code'], groupValue: _t, onChanged: (v) => setState(() => _t = v),
        title: Text(t['name_ar'] ?? '', style: const TextStyle(color: AC.tp)),
        subtitle: t['knowledge_mode_eligible'] == true ? const Text('Knowledge Mode', style: TextStyle(color: AC.cyan, fontSize: 11)) :
          Text(t['name_en'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 11)), activeColor: AC.gold, dense: true)),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.err))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l ? null : _go, child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Create Client')))])));
}

// ═══════ TAB 3: ANALYSIS ═══════
class AnalysisTab extends StatefulWidget { const AnalysisTab({super.key}); @override State<AnalysisTab> createState() => _AnalysisS(); }
class _AnalysisS extends State<AnalysisTab> {
  PlatformFile? _f; List<int>? _fb; bool _a = false; Map<String, dynamic>? _r; String? _e;
  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
    if (r != null && r.files.isNotEmpty) setState(() { _f = r.files.first; _fb = r.files.first.bytes?.toList(); _r = null; _e = null; });
  }
  Future<void> _run() async {
    if (_fb == null) return; setState(() { _a = true; _e = null; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_api/analyze?industry=retail'));
      req.headers['Authorization'] = 'Bearer ${S.token}';
      req.files.add(http.MultipartFile.fromBytes('file', _fb!, filename: 'tb.xlsx'));
      final res = await req.send(); final body = await res.stream.bytesToString();
      setState(() { _r = jsonDecode(body); _a = false; });
    } catch (e) { setState(() { _e = '$e'; _a = false; }); }
  }
  String _fmt(dynamic v) { if (v == null) return '-'; final d = (v is int) ? v.toDouble() : (v is double) ? v : 0.0;
    if (d.abs() >= 1e6) return '${(d/1e6).toStringAsFixed(2)}M'; if (d.abs() >= 1e3) return '${(d/1e3).toStringAsFixed(1)}K'; return d.toStringAsFixed(2); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Financial Analysis', style: TextStyle(color: AC.gold))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      GestureDetector(onTap: _pick, child: Container(width: double.infinity, height: 120,
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: _f != null ? AC.gold : AC.bdr)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_f != null ? Icons.check_circle : Icons.cloud_upload_outlined, color: _f != null ? AC.ok : AC.gold, size: 36),
          const SizedBox(height: 8), Text(_f?.name ?? 'Upload Trial Balance', style: TextStyle(color: _f != null ? AC.tp : AC.ts))]))),
      const SizedBox(height: 16),
      if (_f != null && _r == null) SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _a ? null : _run,
        child: _a ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy)), SizedBox(width: 12), Text('Analyzing...')]) : const Text('Start Analysis'))),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.err))),
      if (_r != null && _r!['success'] == true) ...[
        const SizedBox(height: 20),
        _box(Column(children: [const Text('Confidence', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const Divider(color: AC.bdr),
          _kv('Score', '${((_r!['confidence']?['overall'] ?? 0) * 100).toStringAsFixed(1)}%'), _kv('Label', _r!['confidence']?['label'] ?? '')])),
        _box(Column(children: [const Text('Income Statement', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const Divider(color: AC.bdr),
          _kv('Net Revenue', _fmt(_r!['income_statement']?['net_revenue'])), _kv('COGS', _fmt(_r!['income_statement']?['cogs'])),
          _kv('Gross Profit', _fmt(_r!['income_statement']?['gross_profit'])), _kv('Net Profit', _fmt(_r!['income_statement']?['net_profit']), vc: AC.gold)])),
        _box(Column(children: [const Text('Balance Sheet', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const Divider(color: AC.bdr),
          _kv('Assets', _fmt(_r!['balance_sheet']?['total_assets'])), _kv('Liabilities', _fmt(_r!['balance_sheet']?['total_liabilities'])),
          _kv('Balanced', _r!['balance_sheet']?['is_balanced'] == true ? 'Yes' : 'No', vc: _r!['balance_sheet']?['is_balanced'] == true ? AC.ok : AC.err)])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => setState(() { _f = null; _fb = null; _r = null; }),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)), child: const Text('Analyze Another', style: TextStyle(color: AC.gold)))),
      ]])));
}

// ═══════ TAB 4: MARKETPLACE ═══════
class MarketTab extends StatefulWidget { const MarketTab({super.key}); @override State<MarketTab> createState() => _MarketS(); }
class _MarketS extends State<MarketTab> {
  List _providers = []; List _requests = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/marketplace/providers'));
      final r2 = await http.get(Uri.parse('$_api/marketplace/requests'), headers: S.h());
      if (mounted) setState(() { _providers = jsonDecode(r1.body); _requests = jsonDecode(r2.body); _ld = false; });
    } catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Marketplace', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Verified Providers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.tp)),
      const SizedBox(height: 12),
      if (_providers.isEmpty) _box(const Center(child: Text('No verified providers yet', style: TextStyle(color: AC.ts))))
      else ..._providers.map((p) => _box(Row(children: [
        CircleAvatar(backgroundColor: AC.navy4, child: Icon(Icons.person, color: p['is_premium'] == true ? AC.gold : AC.ts)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(p['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.tp)),
            if (p['badge'] != null) ...[const SizedBox(width: 6), Icon(Icons.verified, color: AC.gold, size: 16)]]),
          Text(p['category'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 12)),
          if (p['scopes'] != null) Text((p['scopes'] as List).join(' • '), style: const TextStyle(color: AC.cyan, fontSize: 11))])),
        if (p['rating'] != null) Column(children: [const Icon(Icons.star, color: AC.gold, size: 18), Text('${p["rating"]}', style: const TextStyle(color: AC.gold, fontSize: 12))])]))),

      const SizedBox(height: 24),
      const Text('My Service Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.tp)),
      const SizedBox(height: 12),
      if (_requests.isEmpty) _box(const Center(child: Text('No requests yet', style: TextStyle(color: AC.ts))))
      else ..._requests.map((r) => _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.tp))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: r['status'] == 'completed' ? AC.ok.withOpacity(0.2) : r['status'] == 'open' ? AC.cyan.withOpacity(0.2) : AC.warn.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
            child: Text(r['status'] ?? '', style: TextStyle(fontSize: 11,
              color: r['status'] == 'completed' ? AC.ok : r['status'] == 'open' ? AC.cyan : AC.warn)))]),
        const SizedBox(height: 8),
        if (r['budget'] != null) _kv('Budget', '${r["budget"]} SAR'),
        if (r['deadline'] != null) _kv('Deadline', (r['deadline'] as String).substring(0, 10)),
      ]))),
    ]));
}

// ═══════ TAB 5: PROVIDER ═══════
class ProviderTab extends StatefulWidget { const ProviderTab({super.key}); @override State<ProviderTab> createState() => _ProviderS(); }
class _ProviderS extends State<ProviderTab> {
  Map<String, dynamic>? _profile; bool _ld = true; bool _notProvider = false;
  String? _selCat; bool _reg = false; String? _e;
  final _cats = ['accountant','senior_accountant','tax_consultant','zakat_vat_consultant','audit_consultant','bookkeeping_specialist','hr_consultant','legal_consultant'];

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/service-providers/me'), headers: S.h());
      final d = jsonDecode(r.body);
      if (d['success'] == true) { if (mounted) setState(() { _profile = d; _ld = false; }); }
      else { if (mounted) setState(() { _notProvider = true; _ld = false; }); }
    } catch (_) { if (mounted) setState(() { _notProvider = true; _ld = false; }); }
  }

  Future<void> _register() async {
    if (_selCat == null) { setState(() => _e = 'Select category'); return; }
    setState(() { _reg = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/service-providers/register'), headers: S.h(),
        body: jsonEncode({'category': _selCat}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) { _load(); } else { setState(() => _e = d['detail'] ?? d['error']); }
    } catch (e) { setState(() => _e = '$e'); }
    finally { if (mounted) setState(() => _reg = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Provider', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _notProvider ? _registerView() : _profileView());

  Widget _registerView() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.work_outline, color: AC.gold, size: 48), const SizedBox(height: 16),
    const Text('Become a Service Provider', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AC.tp)),
    const SizedBox(height: 8), const Text('Register to offer professional services on APEX marketplace', style: TextStyle(color: AC.ts)),
    const SizedBox(height: 24), const Text('Select Category *', style: TextStyle(color: AC.ts)),
    ..._cats.map((c) => RadioListTile<String>(value: c, groupValue: _selCat, onChanged: (v) => setState(() => _selCat = v),
      title: Text(c.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: AC.tp, fontSize: 14)), activeColor: AC.gold, dense: true)),
    if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: AC.err))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _reg ? null : _register,
      child: _reg ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Register as Provider')))]));

  Widget _profileView() {
    final p = _profile?['provider'] ?? {};
    final docs = _profile?['documents'] as List? ?? [];
    final scopes = _profile?['scopes'] as List? ?? [];
    final reqDocs = _profile?['required_documents'] as List? ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.verified_user, color: AC.gold, size: 28), const SizedBox(width: 12),
          Text(p['category'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AC.tp))]),
        const SizedBox(height: 12),
        _kv('Status', p['verification_status'] ?? '', vc: p['verification_status'] == 'approved' ? AC.ok : AC.warn),
        _kv('Commission', '${p["commission_rate"] ?? 20}% platform'),
        _kv('Completed Tasks', '${p["completed_tasks"] ?? 0}'),
        if (p['rating_average'] != null) _kv('Rating', '${p["rating_average"]} / 5'),
      ])),
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Service Scopes', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        ...scopes.map((s) => Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [Icon(s['is_approved'] == true ? Icons.check_circle : Icons.pending, color: s['is_approved'] == true ? AC.ok : AC.warn, size: 16),
            const SizedBox(width: 8), Text(s['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13))])))
      ])),
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Documents', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        ...reqDocs.map((d) { final uploaded = docs.any((doc) => doc['type'] == d);
          return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Icon(uploaded ? Icons.check_circle : Icons.upload_file, color: uploaded ? AC.ok : AC.ts, size: 16),
            const SizedBox(width: 8), Text('$d', style: TextStyle(color: uploaded ? AC.tp : AC.ts, fontSize: 13))])); }),
      ])),
    ]);
  }
}

// ═══════ TAB 6: ACCOUNT ═══════
class AccountTab extends StatefulWidget { const AccountTab({super.key}); @override State<AccountTab> createState() => _AccountS(); }
class _AccountS extends State<AccountTab> {
  Map<String, dynamic>? _p, _s; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/users/me'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/users/me/security'), headers: S.h());
      if (mounted) setState(() { _p = jsonDecode(r1.body); _s = jsonDecode(r2.body); _ld = false; });
    } catch (_) { if (mounted) setState(() => _ld = false); }
  }
  void _logout() { http.post(Uri.parse('$_api/auth/logout'), headers: S.h()); S.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Account', style: TextStyle(color: AC.gold)), actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: AC.err))]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      _box(Column(children: [
        CircleAvatar(radius: 36, backgroundColor: AC.navy4, child: Text((_p?['user']?['display_name'] ?? '?')[0], style: const TextStyle(fontSize: 28, color: AC.gold))),
        const SizedBox(height: 12), Text(_p?['user']?['display_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
        Text('@${_p?["user"]?["username"] ?? ""}', style: const TextStyle(color: AC.ts)),
        const SizedBox(height: 8), Text(_p?['user']?['email'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 13))])),
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Security', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
        _kv('Active Sessions', '${_s?["active_sessions"] ?? 0}'),
        _kv('Login Count', '${_s?["login_count"] ?? 0}'),
        _kv('Last Login', _s?['last_login'] ?? '-')])),
      _mi(Icons.workspace_premium, 'Plan: ${S.plan ?? "free"}', AC.gold),
      _mi(Icons.notifications_outlined, 'Notifications', AC.cyan),
      _mi(Icons.shield_outlined, 'Change Password', AC.warn),
    ]));
  Widget _mi(IconData i, String l, Color c) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
    child: ListTile(leading: Icon(i, color: c), title: Text(l, style: const TextStyle(color: AC.tp)), trailing: const Icon(Icons.chevron_right, color: AC.ts)));
}
