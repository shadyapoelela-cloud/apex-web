import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart' show AC, S, MainNav;

const _api = 'https://apex-api-ootk.onrender.com';

class SlideAuthScreen extends StatefulWidget {
  const SlideAuthScreen({super.key});
  @override State<SlideAuthScreen> createState() => _SlideAuthState();
}

class _SlideAuthState extends State<SlideAuthScreen> {
  final _pc = PageController();
  int _pg = 0;
  final _lu = TextEditingController(), _lp = TextEditingController();
  bool _ll = false, _lo = true;
  String? _le;
  final _rn = TextEditingController(), _ru = TextEditingController();
  final _re2 = TextEditingController(), _rp = TextEditingController();
  final _rp2 = TextEditingController(), _rph = TextEditingController();
  String _countryCode = '+966';
  bool _rl = false, _ro = true;
  String? _rerr;

  static const _codes = [
    {'c': '+966', 'n': 'ط§ظ„ط³ط¹ظˆط¯ظٹط©'},
    {'c': '+20', 'n': 'ظ…طµط±'},
    {'c': '+971', 'n': 'ط§ظ„ط¥ظ…ط§ط±ط§طھ'},
    {'c': '+973', 'n': 'ط§ظ„ط¨ط­ط±ظٹظ†'},
    {'c': '+965', 'n': 'ط§ظ„ظƒظˆظٹطھ'},
    {'c': '+974', 'n': 'ظ‚ط·ط±'},
    {'c': '+968', 'n': 'ط¹ظ…ط§ظ†'},
  ];

  void _slide(int p) => _pc.animateToPage(p, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);

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
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNav()), (r) => false);
      } else { setState(() { _le = d['detail'] ?? 'ط®ط·ط£ ظپظٹ ط§ظ„ط¯ط®ظˆظ„'; _ll = false; }); }
    } catch (e) { setState(() { _le = e.toString(); _ll = false; }); }
  }

  Future<void> _register() async {
    if (_rp.text != _rp2.text) { setState(() => _rerr = 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± ظ…طھط·ط§ط¨ظ‚ط©'); return; }
    setState(() { _rl = true; _rerr = null; });
    try {
      final phone = '$_countryCode${_rph.text.trim()}';
      final r = await http.post(Uri.parse('$_api/auth/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': _ru.text.trim(), 'email': _re2.text.trim(), 'password': _rp.text, 'display_name': _rn.text.trim(), 'phone': phone}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        setState(() => _rl = false); _slide(0);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨ ط¨ظ†ط¬ط§ط­!'), backgroundColor: AC.ok));
      } else { setState(() { _rerr = d['detail'] ?? 'ط®ط·ط£'; _rl = false; }); }
    } catch (e) { setState(() { _rerr = e.toString(); _rl = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: SafeArea(child: Center(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Logo ABOVE the card
        const Text('APEX', style: TextStyle(color: AC.gold, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 6)),
        const SizedBox(height: 4),
        Text('ظ…ظ†طµط© ط§ظ„طھط­ظ„ظٹظ„ ط§ظ„ظ…ط§ظ„ظٹ ظˆط§ظ„ط­ظˆظƒظ…ط© ط§ظ„ظ…ط¹ط±ظپظٹط© â€” ط§ظ„ط³ظˆظ‚ ط§ظ„ط³ط¹ظˆط¯ظٹ', style: TextStyle(color: AC.ts, fontSize: 11)),
        const SizedBox(height: 24),
        // Card
        Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AC.gold.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Tab Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [_tab('طھط³ط¬ظٹظ„ ط¯ط®ظˆظ„', 0), _tab('ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨', 1)]),
            ),
            const SizedBox(height: 20),
            // Slides
            AnimatedContainer(duration: const Duration(milliseconds: 300), height: _pg == 0 ? 330 : 540, child: PageView(physics: const NeverScrollableScrollPhysics(),controller: _pc, onPageChanged: (i) => setState(() => _pg = i), children: [_loginSlide(), _registerSlide()]))
          ]),
        ),
      ]))))),
    );
  }

  Widget _tab(String l, int i) => Expanded(child: GestureDetector(onTap: () => _slide(i),
    child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: _pg == i ? AC.gold : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(l, style: TextStyle(color: _pg == i ? AC.navy : AC.ts, fontSize: 13, fontWeight: FontWeight.bold))))));

  Widget _loginSlide() => Column(children: [
    const SizedBox(height: 12),
    if (_le != null) _err(_le!),
    _inp(_lu, 'ط§ظ„ط¨ط±ظٹط¯ ط£ظˆ ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ…', Icons.email_outlined, ltr: true),
    const SizedBox(height: 12),
    _pw(_lp, 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', _lo, () => setState(() => _lo = !_lo), sub: _login),
    Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go('/forgot-password'), child: Text('ظ†ط³ظٹطھ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±طں', style: TextStyle(color: AC.gold, fontSize: 12)))),
    const SizedBox(height: 6),
    _bt('طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„', _ll, _login),
    const SizedBox(height: 14), _or(), const SizedBox(height: 10), _soc(),
  ]);

  Widget _registerSlide() => Column(children: [
    const SizedBox(height: 12),
    if (_rerr != null) _err(_rerr!),
    _inp(_rn, 'ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„', Icons.person_outline),
    const SizedBox(height: 10),
    _inp(_ru, 'ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ…', Icons.alternate_email, ltr: true),
    const SizedBox(height: 10),
    _inp(_re2, 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ', Icons.email_outlined, ltr: true),
    const SizedBox(height: 10),
    _pw(_rp, 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', _ro, () => setState(() => _ro = !_ro)),
    const SizedBox(height: 10),
    _pw(_rp2, 'طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±', _ro, () => setState(() => _ro = !_ro)),
    const SizedBox(height: 10),
    // Phone with country code
    Row(children: [
      Container(width: 110, height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _countryCode, isExpanded: true, dropdownColor: AC.navy3,
          style: const TextStyle(color: AC.tp, fontSize: 13),
          items: _codes.map((e) => DropdownMenuItem<String>(value: e['c'] as String, child: Text(e['c']! + ' ' + e['n']!, style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: (v) => setState(() => _countryCode = v!),
        )),
      ),
      const SizedBox(width: 8),
      Expanded(child: _inp(_rph, 'ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ', Icons.phone, ltr: true)),
    ]),
    const SizedBox(height: 14),
    _bt('ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨', _rl, _register),
    const SizedBox(height: 14), _or(), const SizedBox(height: 10), _soc(),
  ]);

  Widget _inp(TextEditingController c, String l, IconData ic, {bool ltr = false}) => TextField(controller: c, style: const TextStyle(color: AC.tp), textDirection: ltr ? TextDirection.ltr : null,
    decoration: InputDecoration(labelText: l, prefixIcon: Icon(ic, color: AC.gold, size: 20), filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold))));

  Widget _pw(TextEditingController c, String l, bool o, VoidCallback t, {VoidCallback? sub}) => TextField(controller: c, obscureText: o, style: const TextStyle(color: AC.tp),
    decoration: InputDecoration(labelText: l, prefixIcon: const Icon(Icons.lock_outlined, color: AC.gold, size: 20), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      suffixIcon: IconButton(icon: Icon(o ? Icons.visibility_off : Icons.visibility, color: AC.ts, size: 20), onPressed: t),
      filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold))),
    onSubmitted: sub != null ? (_) => sub() : null);

  Widget _bt(String l, bool ld, VoidCallback fn) => SizedBox(width: double.infinity, height: 46, child: ElevatedButton(onPressed: ld ? null : fn,
    style: ElevatedButton.styleFrom(backgroundColor: AC.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: AC.gold.withOpacity(0.5)),
    child: ld ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy)) : Text(l, style: const TextStyle(color: AC.navy, fontSize: 15, fontWeight: FontWeight.bold))));

  Widget _err(String m) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.err.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.err.withOpacity(0.3))),
    child: Row(children: [const Icon(Icons.error_outline, color: AC.err, size: 16), const SizedBox(width: 6), Expanded(child: Text(m, style: const TextStyle(color: AC.err, fontSize: 11)))]));

  Widget _or() => Row(children: [Expanded(child: Divider(color: AC.bdr)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('ط£ظˆ', style: TextStyle(color: AC.ts, fontSize: 11))), Expanded(child: Divider(color: AC.bdr))]);

  Widget _soc() => Row(children: [
    Expanded(child: OutlinedButton.icon(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 22), label: const Text('Google', style: TextStyle(color: AC.tp, fontSize: 11)))),
    const SizedBox(width: 8),
    Expanded(child: OutlinedButton.icon(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.bdr), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.apple, color: AC.tp, size: 20), label: const Text('Apple', style: TextStyle(color: AC.tp, fontSize: 11)))),
  ]);

  @override
  void dispose() { _pc.dispose(); _lu.dispose(); _lp.dispose(); _rn.dispose(); _ru.dispose(); _re2.dispose(); _rp.dispose(); _rp2.dispose(); _rph.dispose(); super.dispose(); }
}