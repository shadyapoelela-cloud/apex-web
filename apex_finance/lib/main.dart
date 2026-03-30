import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

const _api = 'https://apex-api-ootk.onrender.com';
void main() => runApp(const ApexApp());

// ═══════ Design System — Luxury Financial Theme ═══════
class C {
  static const bg = Color(0xFF060D18);
  static const surface = Color(0xFF0C1525);
  static const card = Color(0xFF111D30);
  static const cardHover = Color(0xFF162240);
  static const gold = Color(0xFFD4A84B);
  static const goldDim = Color(0xFF8B7332);
  static const accent = Color(0xFF00BCD4);
  static const text = Color(0xFFF2EDE4);
  static const textDim = Color(0xFF8C8577);
  static const ok = Color(0xFF2ECC71);
  static const warn = Color(0xFFE67E22);
  static const err = Color(0xFFE74C3C);
  static const border = Color(0x20D4A84B);
  static const glow = Color(0x12D4A84B);
}

// ═══════ State ═══════
class S {
  static String? token, uid, uname, dname, plan;
  static List<String> roles = [];
  static Map<String, String> h() => {'Authorization': 'Bearer ${token ?? ""}', 'Content-Type': 'application/json'};
  static void clear() { token = null; uid = null; uname = null; dname = null; plan = null; roles = []; }
}

// ═══════ Shared Widgets ═══════
InputDecoration _dec(String label, [IconData? icon]) => InputDecoration(
  labelText: label, labelStyle: const TextStyle(color: C.textDim, fontFamily: 'Tajawal'),
  prefixIcon: icon != null ? Icon(icon, color: C.gold, size: 20) : null,
  filled: true, fillColor: C.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.gold, width: 1.5)));

Widget _card(Widget child, {EdgeInsets? margin, EdgeInsets? padding}) => Container(
  margin: margin ?? const EdgeInsets.only(bottom: 14), padding: padding ?? const EdgeInsets.all(18),
  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16),
    border: Border.all(color: C.border), boxShadow: [BoxShadow(color: C.glow, blurRadius: 20, offset: const Offset(0, 4))]),
  child: child);

Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(padding: const EdgeInsets.only(bottom: 8),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: C.textDim, fontSize: 13, fontFamily: 'Tajawal')),
    Text(v, style: TextStyle(color: vc ?? C.text, fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Tajawal'))]));

Widget _badge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
  child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')));

Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 8),
  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.text, fontFamily: 'Tajawal')));

// ═══════ App ═══════
class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'APEX', debugShowCheckedModeBanner: false,
    locale: const Locale('ar'), builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: C.bg, appBarTheme: const AppBarTheme(backgroundColor: C.surface, elevation: 0, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: C.bg,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal')))),
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
      } else { setState(() => _e = d['detail'] ?? d['error'] ?? 'خطأ في الدخول'); }
    } catch (e) { setState(() => _e = 'خطأ في الاتصال بالخادم'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: Container(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.surface, C.bg])),
    child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 40),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.gold.withOpacity(0.3), width: 2)),
        child: const Icon(Icons.account_balance, color: C.gold, size: 40)),
      const SizedBox(height: 20),
      const Text('APEX', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: C.gold, letterSpacing: 10, fontFamily: 'Tajawal')),
      const SizedBox(height: 6),
      const Text('منصة التحليل المالي الذكية', style: TextStyle(color: C.textDim, fontSize: 14, fontFamily: 'Tajawal')),
      const SizedBox(height: 48),
      TextField(controller: _u, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('البريد أو اسم المستخدم', Icons.person_outline)),
      const SizedBox(height: 14),
      TextField(controller: _p, obscureText: true, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('كلمة المرور', Icons.lock_outline), onSubmitted: (_) => _go()),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 14), child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.err.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [const Icon(Icons.error_outline, color: C.err, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(_e!, style: const TextStyle(color: C.err, fontSize: 13, fontFamily: 'Tajawal')))]))),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _l ? null : _go,
        child: _l ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.bg)) : const Text('تسجيل الدخول'))),
      const SizedBox(height: 18),
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegScreen())),
        child: const Text('ليس لديك حساب؟ سجّل الآن', style: TextStyle(color: C.gold, fontFamily: 'Tajawal'))),
    ]))))));
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
    } catch (e) { setState(() => _e = 'خطأ في الاتصال'); }
    finally { if (mounted) setState(() => _l = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إنشاء حساب جديد', style: TextStyle(fontFamily: 'Tajawal'))),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _un, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('اسم المستخدم *', Icons.alternate_email)),
        const SizedBox(height: 12), TextField(controller: _em, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('البريد الإلكتروني *', Icons.email_outlined)),
        const SizedBox(height: 12), TextField(controller: _dn, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('الاسم الظاهر *', Icons.badge_outlined)),
        const SizedBox(height: 12), TextField(controller: _pw, obscureText: true, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('كلمة المرور *', Icons.lock_outline)),
        if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: C.err, fontSize: 13, fontFamily: 'Tajawal'))),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _l ? null : _go,
          child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('إنشاء الحساب'))),
      ])))));
}

// ═══════ MAIN NAV — 6 تابات ═══════
class MainNav extends StatefulWidget { const MainNav({super.key}); @override State<MainNav> createState() => _MainNavS(); }
class _MainNavS extends State<MainNav> {
  int _i = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: [const DashTab(), const ClientsTab(), const AnalysisTab(), const MarketTab(), const ProviderTab(), const AccountTab()][_i],
    bottomNavigationBar: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.border))),
      child: BottomNavigationBar(currentIndex: _i, onTap: (i) => setState(() => _i = i),
        type: BottomNavigationBarType.fixed, backgroundColor: C.surface, selectedItemColor: C.gold, unselectedItemColor: C.textDim,
        selectedFontSize: 11, unselectedFontSize: 10, selectedLabelStyle: const TextStyle(fontFamily: 'Tajawal'), unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal'),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.business_rounded), label: 'العملاء'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'التحليل'),
          BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'المعرض'),
          BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: 'مقدم خدمة'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ])));
}

// ═══════ الرئيسية ═══════
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
    appBar: AppBar(title: Text('مرحباً ${S.dname ?? ""}', style: const TextStyle(color: C.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: C.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.workspace_premium, color: C.gold, size: 24)), const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('خطتك الحالية', style: TextStyle(color: C.textDim, fontSize: 12, fontFamily: 'Tajawal')),
            Text(_sub?['plan_name_ar'] ?? 'مجاني', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gold, fontFamily: 'Tajawal'))])]),
        const SizedBox(height: 16), const Divider(color: C.border),
        ...(_sub?['entitlements'] as Map<String, dynamic>? ?? {}).entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [Icon(e.value['value'] == 'true' || e.value['value'] == 'unlimited' ? Icons.check_circle_rounded : e.value['value'] == 'false' ? Icons.cancel_rounded : Icons.info_rounded,
            color: e.value['value'] == 'true' || e.value['value'] == 'unlimited' ? C.ok : e.value['value'] == 'false' ? C.err : C.accent, size: 16),
            const SizedBox(width: 10), Expanded(child: Text('${e.key}: ${e.value["value"]}', style: const TextStyle(color: C.textDim, fontSize: 12, fontFamily: 'Tajawal')))]))),
      ])),
      _sectionTitle('الخطط المتاحة'),
      ..._plans.map((p) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p['code'] == _sub?['plan'] ? C.gold : C.border, width: p['code'] == _sub?['plan'] ? 1.5 : 1)),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['name_ar'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p['code'] == _sub?['plan'] ? C.gold : C.text, fontFamily: 'Tajawal')),
          const SizedBox(height: 2),
          Text(p['target_user_ar'] ?? '', style: const TextStyle(color: C.textDim, fontSize: 11, fontFamily: 'Tajawal'))])),
          _badge(p['price_monthly_sar'] == 0 ? 'مجاني' : '${p["price_monthly_sar"]} ر.س', p['code'] == _sub?['plan'] ? C.gold : C.accent)]))),
    ]));
}

// ═══════ العملاء ═══════
class ClientsTab extends StatefulWidget { const ClientsTab({super.key}); @override State<ClientsTab> createState() => _ClientsS(); }
class _ClientsS extends State<ClientsTab> {
  List _cl = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await http.get(Uri.parse('$_api/clients'), headers: S.h()); if (mounted) setState(() { _cl = jsonDecode(r.body); _ld = false; }); }
    catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('العملاء', style: TextStyle(color: C.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
    floatingActionButton: FloatingActionButton(backgroundColor: C.gold, elevation: 4, onPressed: () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewClientScreen())); _load(); },
      child: const Icon(Icons.add, color: C.bg)),
    body: _ld ? const Center(child: CircularProgressIndicator(color: C.gold)) :
      _cl.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.business_outlined, color: C.textDim.withOpacity(0.3), size: 64), const SizedBox(height: 16),
        const Text('لا يوجد عملاء بعد', style: TextStyle(color: C.textDim, fontSize: 16, fontFamily: 'Tajawal')),
        const SizedBox(height: 8), const Text('اضغط + لإنشاء عميل جديد', style: TextStyle(color: C.textDim, fontSize: 13, fontFamily: 'Tajawal'))])) :
      ListView.builder(padding: const EdgeInsets.all(16), itemCount: _cl.length, itemBuilder: (_, i) { final c = _cl[i];
        return _card(Row(children: [CircleAvatar(backgroundColor: C.surface, radius: 22,
          child: Text((c['name_ar'] ?? '?')[0], style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'))),
          const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['name_ar'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text, fontSize: 15, fontFamily: 'Tajawal')),
            const SizedBox(height: 2),
            Text('${c["client_type"] ?? ""} • ${c["your_role"] ?? ""}', style: const TextStyle(color: C.textDim, fontSize: 12, fontFamily: 'Tajawal'))])),
          if (c['knowledge_mode'] == true) Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: C.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.psychology, color: C.accent, size: 18))])); }));
}

class NewClientScreen extends StatefulWidget { const NewClientScreen({super.key}); @override State<NewClientScreen> createState() => _NewCS(); }
class _NewCS extends State<NewClientScreen> {
  final _n = TextEditingController(); List _types = []; String? _t; bool _l = false; String? _e;
  @override void initState() { super.initState(); http.get(Uri.parse('$_api/client-types')).then((r) { if (mounted) setState(() => _types = jsonDecode(r.body)); }); }
  Future<void> _go() async {
    if (_n.text.trim().isEmpty || _t == null) { setState(() => _e = 'الاسم ونوع العميل مطلوبان'); return; }
    setState(() { _l = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/clients'), headers: S.h(), body: jsonEncode({'name_ar': _n.text.trim(), 'client_type_code': _t}));
      if (jsonDecode(r.body)['success'] == true) { if (mounted) Navigator.pop(context); } else { setState(() => _e = jsonDecode(r.body)['detail']); }
    } catch (e) { setState(() => _e = '$e'); } finally { if (mounted) setState(() => _l = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إنشاء عميل جديد', style: TextStyle(fontFamily: 'Tajawal'))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _n, style: const TextStyle(fontFamily: 'Tajawal'), decoration: _dec('اسم المنشأة *', Icons.business)),
      const SizedBox(height: 20), const Text('نوع العميل *', style: TextStyle(color: C.textDim, fontFamily: 'Tajawal')), const SizedBox(height: 8),
      ..._types.map((t) => GestureDetector(onTap: () => setState(() => _t = t['code']),
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _t == t['code'] ? C.gold.withOpacity(0.08) : C.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _t == t['code'] ? C.gold : C.border)),
          child: Row(children: [Icon(_t == t['code'] ? Icons.radio_button_checked : Icons.radio_button_off, color: _t == t['code'] ? C.gold : C.textDim, size: 20),
            const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['name_ar'] ?? '', style: TextStyle(color: _t == t['code'] ? C.gold : C.text, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
              if (t['knowledge_mode_eligible'] == true) Row(children: [const Icon(Icons.psychology, color: C.accent, size: 14), const SizedBox(width: 4),
                const Text('وضع المعرفة', style: TextStyle(color: C.accent, fontSize: 11, fontFamily: 'Tajawal'))])
              else Text(t['name_en'] ?? '', style: const TextStyle(color: C.textDim, fontSize: 11))]))])))),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: C.err, fontFamily: 'Tajawal'))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _l ? null : _go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('إنشاء العميل')))])));
}

// ═══════ التحليل المالي ═══════
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
    } catch (e) { setState(() { _e = 'خطأ في التحليل: $e'; _a = false; }); }
  }
  String _fmt(dynamic v) { if (v == null) return '—'; final d = (v is int) ? v.toDouble() : (v is double) ? v : 0.0;
    if (d.abs() >= 1e6) return '${(d/1e6).toStringAsFixed(2)}M'; if (d.abs() >= 1e3) return '${(d/1e3).toStringAsFixed(1)}K'; return d.toStringAsFixed(2); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التحليل المالي', style: TextStyle(color: C.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      GestureDetector(onTap: _pick, child: Container(width: double.infinity, height: 130,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _f != null ? C.gold : C.border, width: _f != null ? 2 : 1),
          boxShadow: _f != null ? [BoxShadow(color: C.gold.withOpacity(0.1), blurRadius: 20)] : null),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_f != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded, color: _f != null ? C.ok : C.gold, size: 40),
          const SizedBox(height: 10), Text(_f?.name ?? 'اضغط لرفع ميزان المراجعة', style: TextStyle(color: _f != null ? C.text : C.textDim, fontFamily: 'Tajawal', fontSize: 14))]))),
      const SizedBox(height: 16),
      if (_f != null && _r == null) SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _a ? null : _run,
        child: _a ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.bg)),
          const SizedBox(width: 12), const Text('جاري التحليل...')]) : const Text('بدء التحليل'))),
      if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: C.err, fontFamily: 'Tajawal'))),
      if (_r != null && _r!['success'] == true) ...[
        const SizedBox(height: 20),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('الثقة', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal')), const Spacer(),
            _badge('${((_r!['confidence']?['overall'] ?? 0) * 100).toStringAsFixed(1)}%', C.ok)]),
          const SizedBox(height: 8), _kv('التقييم', _r!['confidence']?['label'] ?? '')])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('قائمة الدخل', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal')),
          const SizedBox(height: 10), const Divider(color: C.border),
          _kv('صافي الإيرادات', _fmt(_r!['income_statement']?['net_revenue'])),
          _kv('تكلفة المبيعات', _fmt(_r!['income_statement']?['cogs'])),
          _kv('مجمل الربح', _fmt(_r!['income_statement']?['gross_profit'])),
          _kv('صافي الربح', _fmt(_r!['income_statement']?['net_profit']), vc: C.gold, bold: true)])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الميزانية العمومية', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal')),
          const SizedBox(height: 10), const Divider(color: C.border),
          _kv('إجمالي الأصول', _fmt(_r!['balance_sheet']?['total_assets'])),
          _kv('إجمالي الالتزامات', _fmt(_r!['balance_sheet']?['total_liabilities'])),
          _kv('متوازنة', _r!['balance_sheet']?['is_balanced'] == true ? 'نعم ✓' : 'لا ✗', vc: _r!['balance_sheet']?['is_balanced'] == true ? C.ok : C.err)])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => setState(() { _f = null; _fb = null; _r = null; }),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: C.gold), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('تحليل ملف آخر', style: TextStyle(color: C.gold, fontFamily: 'Tajawal')))),
      ]])));
}

// ═══════ المعرض ═══════
class MarketTab extends StatefulWidget { const MarketTab({super.key}); @override State<MarketTab> createState() => _MarketS(); }
class _MarketS extends State<MarketTab> {
  List _prov = []; List _reqs = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await http.get(Uri.parse('$_api/marketplace/providers'));
      final r2 = await http.get(Uri.parse('$_api/marketplace/requests'), headers: S.h());
      if (mounted) setState(() { _prov = jsonDecode(r1.body); _reqs = jsonDecode(r2.body); _ld = false; });
    } catch (_) { if (mounted) setState(() => _ld = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المعرض', style: TextStyle(color: C.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: C.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      _sectionTitle('مقدمو الخدمات المعتمدون'),
      if (_prov.isEmpty) _card(Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline, color: C.textDim.withOpacity(0.3), size: 40), const SizedBox(height: 8),
        const Text('لا يوجد مقدمو خدمات معتمدون بعد', style: TextStyle(color: C.textDim, fontFamily: 'Tajawal'))])))
      else ..._prov.map((p) => _card(Row(children: [
        CircleAvatar(backgroundColor: p['is_premium'] == true ? C.gold.withOpacity(0.15) : C.surface, child: Icon(Icons.person, color: p['is_premium'] == true ? C.gold : C.textDim)),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(p['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text, fontFamily: 'Tajawal')),
            if (p['badge'] != null) ...[const SizedBox(width: 6), const Icon(Icons.verified, color: C.gold, size: 16)]]),
          Text(p['category'] ?? '', style: const TextStyle(color: C.textDim, fontSize: 12, fontFamily: 'Tajawal')),
          if (p['scopes'] != null) Text((p['scopes'] as List).join(' • '), style: const TextStyle(color: C.accent, fontSize: 11, fontFamily: 'Tajawal'))])),
        if (p['rating'] != null) Column(children: [const Icon(Icons.star_rounded, color: C.gold, size: 20), Text('${p["rating"]}', style: const TextStyle(color: C.gold, fontSize: 13))])]))),
      const SizedBox(height: 16), _sectionTitle('طلبات الخدمة'),
      if (_reqs.isEmpty) _card(Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, color: C.textDim.withOpacity(0.3), size: 40), const SizedBox(height: 8),
        const Text('لا توجد طلبات خدمة بعد', style: TextStyle(color: C.textDim, fontFamily: 'Tajawal'))])))
      else ..._reqs.map((r) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text, fontFamily: 'Tajawal'))),
          _badge(r['status'] ?? '', r['status'] == 'completed' ? C.ok : r['status'] == 'open' ? C.accent : C.warn)]),
        const SizedBox(height: 10),
        if (r['budget'] != null) _kv('الميزانية', '${r["budget"]} ر.س'),
        if (r['deadline'] != null) _kv('الموعد النهائي', (r['deadline'] as String).substring(0, 10))]))),
    ]));
}

// ═══════ مقدم خدمة ═══════
class ProviderTab extends StatefulWidget { const ProviderTab({super.key}); @override State<ProviderTab> createState() => _ProviderS(); }
class _ProviderS extends State<ProviderTab> {
  Map<String, dynamic>? _profile; bool _ld = true; bool _notProv = false;
  String? _cat; bool _reg = false; String? _e;
  final _cats = [('accountant','محاسب'),('senior_accountant','محاسب أول'),('tax_consultant','مستشار ضرائب'),('zakat_vat_consultant','مستشار زكاة وض.ق.م'),
    ('audit_consultant','مستشار تدقيق'),('bookkeeping_specialist','متخصص مسك دفاتر'),('hr_consultant','مستشار موارد بشرية'),('legal_consultant','مستشار قانوني')];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/service-providers/me'), headers: S.h());
      final d = jsonDecode(r.body);
      if (d['success'] == true) { if (mounted) setState(() { _profile = d; _ld = false; }); }
      else { if (mounted) setState(() { _notProv = true; _ld = false; }); }
    } catch (_) { if (mounted) setState(() { _notProv = true; _ld = false; }); }
  }
  Future<void> _doReg() async {
    if (_cat == null) { setState(() => _e = 'اختر التخصص'); return; }
    setState(() { _reg = true; _e = null; });
    try {
      final r = await http.post(Uri.parse('$_api/service-providers/register'), headers: S.h(), body: jsonEncode({'category': _cat}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) { setState(() { _notProv = false; }); _load(); } else { setState(() => _e = d['detail'] ?? d['error']); }
    } catch (e) { setState(() => _e = '$e'); } finally { if (mounted) setState(() => _reg = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مقدم خدمة', style: TextStyle(color: C.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: C.gold)) : _notProv ? _regView() : _profView());

  Widget _regView() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.work_outline_rounded, color: C.gold, size: 40)),
    const SizedBox(height: 18),
    const Text('كن مقدم خدمة معتمد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.text, fontFamily: 'Tajawal')),
    const SizedBox(height: 6), const Text('سجّل لتقديم خدماتك المهنية في معرض APEX', style: TextStyle(color: C.textDim, fontFamily: 'Tajawal')),
    const SizedBox(height: 24), const Text('اختر التخصص *', style: TextStyle(color: C.textDim, fontFamily: 'Tajawal')), const SizedBox(height: 10),
    ..._cats.map((c) => GestureDetector(onTap: () => setState(() => _cat = c.$1),
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _cat == c.$1 ? C.gold.withOpacity(0.08) : C.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cat == c.$1 ? C.gold : C.border)),
        child: Row(children: [Icon(_cat == c.$1 ? Icons.radio_button_checked : Icons.radio_button_off, color: _cat == c.$1 ? C.gold : C.textDim, size: 20),
          const SizedBox(width: 12), Text(c.$2, style: TextStyle(color: _cat == c.$1 ? C.gold : C.text, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))])))),
    if (_e != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_e!, style: const TextStyle(color: C.err, fontFamily: 'Tajawal'))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _reg ? null : _doReg,
      child: _reg ? const CircularProgressIndicator(strokeWidth: 2) : const Text('التسجيل كمقدم خدمة')))]));

  Widget _profView() {
    final p = _profile?['provider'] ?? {}; final docs = _profile?['documents'] as List? ?? [];
    final scopes = _profile?['scopes'] as List? ?? []; final reqDocs = _profile?['required_documents'] as List? ?? [];
    final catAr = _cats.firstWhere((c) => c.$1 == p['category'], orElse: () => ('','غير محدد')).$2;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.verified_user_rounded, color: C.gold, size: 24)), const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(catAr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.text, fontFamily: 'Tajawal')),
            const SizedBox(height: 2), _badge(p['verification_status'] ?? 'pending', p['verification_status'] == 'approved' ? C.ok : C.warn)])]),
        const SizedBox(height: 16), const Divider(color: C.border),
        _kv('العمولة', '${p["commission_rate"] ?? 20}% للمنصة'),
        _kv('المهام المكتملة', '${p["completed_tasks"] ?? 0}'),
        if (p['rating_average'] != null) _kv('التقييم', '${p["rating_average"]} / 5', vc: C.gold)])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نطاقات الخدمة', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')), const SizedBox(height: 10),
        ...scopes.map((s) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [Icon(s['is_approved'] == true ? Icons.check_circle_rounded : Icons.pending_rounded, color: s['is_approved'] == true ? C.ok : C.warn, size: 16),
            const SizedBox(width: 10), Text(s['name_ar'] ?? '', style: const TextStyle(color: C.text, fontSize: 13, fontFamily: 'Tajawal'))])))])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('المستندات المطلوبة', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')), const SizedBox(height: 10),
        ...reqDocs.map((d) { final ok = docs.any((doc) => doc['type'] == d);
          return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: ok ? C.ok : C.textDim, size: 16),
            const SizedBox(width: 10), Text('$d', style: TextStyle(color: ok ? C.text : C.textDim, fontSize: 13, fontFamily: 'Tajawal'))])); })])),
    ]);
  }
}

// ═══════ حسابي ═══════
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
    appBar: AppBar(title: const Text('حسابي', style: TextStyle(color: C.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: C.err))]),
    body: _ld ? const Center(child: CircularProgressIndicator(color: C.gold)) : ListView(padding: const EdgeInsets.all(16), children: [
      _card(Column(children: [
        Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.gold.withOpacity(0.4), width: 2)),
          child: CircleAvatar(radius: 36, backgroundColor: C.surface, child: Text((_p?['user']?['display_name'] ?? '?')[0],
            style: const TextStyle(fontSize: 30, color: C.gold, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')))),
        const SizedBox(height: 14), Text(_p?['user']?['display_name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.text, fontFamily: 'Tajawal')),
        const SizedBox(height: 4), Text('@${_p?["user"]?["username"] ?? ""}', style: const TextStyle(color: C.textDim, fontFamily: 'Tajawal')),
        const SizedBox(height: 6), Text(_p?['user']?['email'] ?? '', style: const TextStyle(color: C.textDim, fontSize: 13, fontFamily: 'Tajawal'))])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.shield_rounded, color: C.gold, size: 20), const SizedBox(width: 8),
          const Text('الأمان', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'))]),
        const SizedBox(height: 12),
        _kv('الجلسات النشطة', '${_s?["active_sessions"] ?? 0}'),
        _kv('عدد مرات الدخول', '${_s?["login_count"] ?? 0}'),
        _kv('آخر دخول', _s?['last_login'] ?? '—')])),
      _menuItem(Icons.workspace_premium_rounded, 'خطتي: ${S.plan ?? "مجاني"}', C.gold),
      _menuItem(Icons.notifications_rounded, 'الإشعارات', C.accent),
      _menuItem(Icons.lock_rounded, 'تغيير كلمة المرور', C.warn),
    ]));
  Widget _menuItem(IconData i, String l, Color c) => Container(margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(i, color: c, size: 20)), title: Text(l, style: const TextStyle(color: C.text, fontFamily: 'Tajawal')),
      trailing: const Icon(Icons.chevron_left_rounded, color: C.textDim)));
}
