import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart' show AC, S;

const _api = 'https://apex-api-ootk.onrender.com';

class SlideAuthScreen extends StatefulWidget {
  const SlideAuthScreen({super.key});
  @override State<SlideAuthScreen> createState() => _SlideAuthState();
}

class _SlideAuthState extends State<SlideAuthScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  final _lu = TextEditingController(), _lp = TextEditingController();
  bool _ll = false, _lo = true;
  String? _le;
  final _rn = TextEditingController(), _ru = TextEditingController();
  final _re = TextEditingController(), _rp = TextEditingController();
  final _rp2 = TextEditingController();
  bool _rl = false, _ro = true;
  String? _rerr;

  void _slide(int p) => _pageCtrl.animateToPage(p, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);

  Future<void> _login() async {
    setState(() { _ll = true; _le = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username_or_email': _lu.text.trim(), 'password': _lp.text}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        S.token = d['tokens']['access_token']; S.uid = d['user']['id'];
        S.uname = d['user']['username']; S.dname = d['user']['display_name'];
        S.plan = d['user']['plan']; S.email = d['user']['email'];
        S.roles = List<String>.from(d['user']['roles'] ?? []);
        if (mounted) context.go('/home');
      } else { setState(() { _le = d['detail'] ?? 'ط®ط·ط£'; _ll = false; }); }
    } catch (e) { setState(() { _le = e.toString(); _ll = false; }); }
  }

  Future<void> _register() async {
    if (_rp.text != _rp2.text) { setState(() => _rerr = 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± ظ…طھط·ط§ط¨ظ‚ط©'); return; }
    setState(() { _rl = true; _rerr = null; });
    try {
      final r = await http.post(Uri.parse('$_api/auth/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': _ru.text.trim(), 'email': _re.text.trim(), 'password': _rp.text, 'display_name': _rn.text.trim()}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        setState(() => _rl = false); _slide(0);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨!'), backgroundColor: Color(0xFF2ECC8A)));
      } else { setState(() { _rerr = d['detail'] ?? 'ط®ط·ط£'; _rl = false; }); }
    } catch (e) { setState(() { _rerr = e.toString(); _rl = false; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    body: SafeArea(child: Column(children: [
      const SizedBox(height: 40),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(22), border: Border.all(color: AC.gold.withOpacity(0.2))),
        child: const Column(children: [Icon(Icons.account_balance, color: AC.gold, size: 42), SizedBox(height: 6), Text('APEX', style: TextStyle(color: AC.gold, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4))])),
      const SizedBox(height: 24),
      Container(margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [_tab('طھط³ط¬ظٹظ„ ط¯ط®ظˆظ„', 0), _tab('ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨', 1)])),
      const SizedBox(height: 20),
      Expanded(child: PageView(controller: _pageCtrl, onPageChanged: (i) => setState(() => _page = i), children: [_loginSlide(), _registerSlide()])),
    ])),
  );

  Widget _tab(String l, int i) => Expanded(child: GestureDetector(onTap: () => _slide(i),
    child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(color: _page == i ? AC.gold : Colors.transparent, borderRadius: BorderRadius.circular(11)),
      child: Center(child: Text(l, style: TextStyle(color: _page == i ? AC.navy : AC.ts, fontSize: 13, fontWeight: FontWeight.bold))))));

  Widget _loginSlide() => SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 32), child: Column(children: [
    if (_le != null) _err(_le!),
    _inp(_lu, 'ط§ظ„ط¨ط±ظٹط¯ ط£ظˆ ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ…', Icons.email_outlined, ltr: true),
    const SizedBox(height: 14),
    _pw(_lp, 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', _lo, () => setState(() => _lo = !_lo), sub: _login),
    Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go('/forgot-password'), child: const Text('ظ†ط³ظٹطھ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±طں', style: TextStyle(color: AC.gold, fontSize: 12)))),
    const SizedBox(height: 10),
    _bt('طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„', _ll, _login),
    const SizedBox(height: 20), _or(), const SizedBox(height: 14), _soc(),
  ]));

  Widget _registerSlide() => SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 32), child: Column(children: [
    if (_rerr != null) _err(_rerr!),
    _inp(_rn, 'ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„', Icons.person_outline),
    const SizedBox(height: 12),
    _inp(_ru, 'ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ…', Icons.alternate_email, ltr: true),
    const SizedBox(height: 12),
    _inp(_re, 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ', Icons.email_outlined, ltr: true),
    const SizedBox(height: 12),
    _pw(_rp, 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', _ro, () => setState(() => _ro = !_ro)),
    const SizedBox(height: 12),
    _pw(_rp2, 'طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', _ro, () => setState(() => _ro = !_ro)),
    const SizedBox(height: 16),
    _bt('ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨', _rl, _register),
    const SizedBox(height: 20), _or(), const SizedBox(height: 14), _soc(),
  ]));

  Widget _inp(TextEditingController c, String l, IconData ic, {bool ltr = false}) => TextField(controller: c, style: const TextStyle(color: AC.tp), textDirection: ltr ? TextDirection.ltr : null,
    decoration: InputDecoration(labelText: l, prefixIcon: Icon(ic, color: AC.gold, size: 20), filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold))));

  Widget _pw(TextEditingController c, String l, bool o, VoidCallback t, {VoidCallback? sub}) => TextField(controller: c, obscureText: o, style: const TextStyle(color: AC.tp),
    decoration: InputDecoration(labelText: l, prefixIcon: const Icon(Icons.lock_outlined, color: AC.gold, size: 20),
      suffixIcon: IconButton(icon: Icon(o ? Icons.visibility_off : Icons.visibility, color: AC.ts, size: 20), onPressed: t),
      filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold))),
    onSubmitted: sub != null ? (_) => sub() : null);

  Widget _bt(String l, bool ld, VoidCallback fn) => SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: ld ? null : fn,
    style: ElevatedButton.styleFrom(backgroundColor: AC.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), disabledBackgroundColor: AC.gold.withOpacity(0.5)),
    child: ld ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy)) : Text(l, style: const TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.bold))));

  Widget _err(String m) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.err.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.err.withOpacity(0.3))),
    child: Row(children: [const Icon(Icons.error_outline, color: AC.err, size: 18), const SizedBox(width: 8), Expanded(child: Text(m, style: const TextStyle(color: AC.err, fontSize: 12)))]));

  Widget _or() => Row(children: [Expanded(child: Divider(color: AC.bdr)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('ط£ظˆ', style: TextStyle(color: AC.ts, fontSize: 11))), Expanded(child: Divider(color: AC.bdr))]);

  Widget _soc() => Row(children: [
    Expanded(child: OutlinedButton.icon(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 24), label: const Text('Google', style: TextStyle(color: AC.tp, fontSize: 12)))),
    const SizedBox(width: 10),
    Expanded(child: OutlinedButton.icon(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.apple, color: AC.tp, size: 22), label: const Text('Apple', style: TextStyle(color: AC.tp, fontSize: 12)))),
  ]);

  @override
  void dispose() { _pageCtrl.dispose(); _lu.dispose(); _lp.dispose(); _rn.dispose(); _ru.dispose(); _re.dispose(); _rp.dispose(); _rp2.dispose(); super.dispose(); }
}
