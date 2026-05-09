import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/apex_trust_signals.dart';
import '../../core/auth_guard.dart' show resolvePostLoginDestination;
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/ui_components.dart';
// G-AUTH-TENANT-PERSIST (2026-05-09): see app_providers.dart.
import '../../pilot/session.dart';

class SlideAuthScreen extends StatefulWidget {
  const SlideAuthScreen({super.key});
  @override State<SlideAuthScreen> createState() => _SAS();
}

class _SAS extends State<SlideAuthScreen> {
  int _pg = 0;
  final _lu = TextEditingController();
  final _lp = TextEditingController();
  bool _ll = false, _lo = true;
  String? _le;
  final _rn = TextEditingController();
  final _ru = TextEditingController();
  final _rem = TextEditingController();
  final _rp = TextEditingController();
  final _rp2 = TextEditingController();
  final _rph = TextEditingController();
  String _cc = '+966';
  bool _rl = false, _ro = true;
  String? _re;
  final _codes = const ['+966','+20','+971','+973','+965','+974','+968'];

  Future<void> _login() async {
    if (_lu.text.trim().isEmpty || _lp.text.isEmpty) {
      setState(() => _le = 'يرجى ملء جميع الحقول');
      return;
    }
    setState(() { _ll = true; _le = null; });
    final res = await ApiService.login(_lu.text.trim(), _lp.text);
    if (res.success) {
      final d = res.data;
      S.token = d['tokens']['access_token'];
      ApiService.setToken(S.token!);
      S.uid = d['user']['id'];
      S.uname = d['user']['username'];
      S.dname = d['user']['display_name'];
      S.plan = d['user']['plan'];
      S.email = d['user']['email'];
      S.roles = List<String>.from(d['user']['roles'] ?? []);
      // G-AUTH-TENANT-PERSIST (2026-05-09): persist tenant_id from
      // ERR-2 auto-tenant so the wizard's hasTenant branch fires.
      // The slide-auth `_register()` method below is snackbar-only
      // (no S.* writes) — the user logs in afterwards, which hits
      // this same code path.
      final tenantId = d['user']['tenant_id'];
      if (tenantId is String && tenantId.isNotEmpty) {
        PilotSession.tenantId = tenantId;
      }
      // ERR-1 (2026-05-07): if we got bounced here by the 401
      // interceptor, the original path is in `?return_to=…`. Honor it
      // (after sanity-checking it's a safe in-app path) so the user
      // lands back where they were before the session expired.
      if (mounted) {
        final returnTo = GoRouterState.of(context)
            .uri
            .queryParameters['return_to'];
        context.go(resolvePostLoginDestination(returnTo));
      }
    } else {
      setState(() { _le = res.error ?? 'خطأ في الدخول'; _ll = false; });
    }
  }

  Future<void> _register() async {
    if (_rn.text.trim().isEmpty || _ru.text.trim().isEmpty || _rem.text.trim().isEmpty || _rp.text.isEmpty) {
      setState(() => _re = 'يرجى ملء جميع الحقول المطلوبة');
      return;
    }
    if (_rp.text.length < 6) {
      setState(() => _re = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_rp.text != _rp2.text) {
      setState(() => _re = 'كلمة المرور غير متطابقة');
      return;
    }
    setState(() { _rl = true; _re = null; });
    final ph = _cc + _rph.text.trim();
    final res = await ApiService.register(
      username: _ru.text.trim(),
      email: _rem.text.trim(),
      password: _rp.text,
      displayName: _rn.text.trim(),
      mobile: ph,
    );
    if (res.success) {
      setState(() { _rl = false; _pg = 0; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء الحساب!'), backgroundColor: AC.ok));
    } else {
      setState(() { _re = res.error ?? 'خطأ'; _rl = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ApexLogo(fontSize: 32),
          SizedBox(height: 3),
          Text('منصة التحليل المالي والحوكمة المعرفية — السوق السعودي', style: TextStyle(color: AC.ts, fontSize: 11)),
          SizedBox(height: 16),
          Container(width: 420, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AC.gold.withAlpha(38)),
              boxShadow: [BoxShadow(color: core_theme.AC.tp.withAlpha(77), blurRadius: 30, offset: Offset(0, 10))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: EdgeInsets.all(4),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [_tb('تسجيل دخول', 0), _tb('إنشاء حساب', 1)]),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _pg == 0 ? _loginForm() : _regForm(),
              ),
            ]),
          ),
          // Trust signals — visible at every entry point per FinTech UX best practice.
          // See architecture/diagrams/03-research-findings.md (Wave 6).
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: const ApexTrustSignals(),
          ),
        ]),
      ))),
    );
  }

  Widget _tb(String l, int i) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _pg = i),
    child: AnimatedContainer(duration: Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: _pg == i ? AC.gold : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(l, style: TextStyle(color: _pg == i ? AC.btnFg : AC.goldText, fontSize: 13, fontWeight: FontWeight.bold)))),
  ));

  Widget _loginForm() => Column(key: const ValueKey('login'), children: [
    const SizedBox(height: 10),
    if (_le != null) _errW(_le!),
    _tf(_lu, 'البريد أو اسم المستخدم', Icons.email_outlined, ltr: true),
    const SizedBox(height: 10),
    _pf(_lp, 'كلمة المرور', _lo, () => setState(() => _lo = !_lo), sub: _login),
    Align(alignment: AlignmentDirectional.centerStart, child: TextButton(
      onPressed: () => context.go('/forgot-password'),
      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 30)),
      child: Text('نسيت كلمة المرور؟', style: TextStyle(color: AC.goldText, fontSize: 12)))),
    const SizedBox(height: 4),
    _btn('تسجيل الدخول', _ll, _login),
    const SizedBox(height: 10), _orW(), const SizedBox(height: 8), _socW(),
  ]);

  Widget _regForm() => Column(key: const ValueKey('register'), children: [
    const SizedBox(height: 12),
    if (_re != null) _errW(_re!),
    _tf(_rn, 'الاسم الكامل', Icons.person_outline),
    const SizedBox(height: 10),
    _tf(_ru, 'اسم المستخدم', Icons.alternate_email, ltr: true),
    const SizedBox(height: 10),
    _tf(_rem, 'البريد الإلكتروني', Icons.email_outlined, ltr: true),
    const SizedBox(height: 10),
    _pf(_rp, 'كلمة المرور', _ro, () => setState(() => _ro = !_ro)),
    ApexPasswordStrength(password: _rp.text),
    const SizedBox(height: 10),
    _pf(_rp2, 'تأكيد كلمة المرور', _ro, () => setState(() => _ro = !_ro)),
    SizedBox(height: 10),
    Row(children: [
      Container(width: 100, height: 48, padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _cc, isExpanded: true, dropdownColor: AC.navy3,
          style: TextStyle(color: AC.tp, fontSize: 13),
          items: _codes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _cc = v!),
        )),
      ),
      const SizedBox(width: 8),
      Expanded(child: _tf(_rph, 'رقم الهاتف', Icons.phone, ltr: true)),
    ]),
    const SizedBox(height: 10),
    _btn('إنشاء حساب', _rl, _register),
    const SizedBox(height: 10), _orW(), const SizedBox(height: 8), _socW(),
  ]);

  Widget _tf(TextEditingController c, String l, IconData ic, {bool ltr = false, TextInputAction? action}) => TextField(
    controller: c, style: TextStyle(color: AC.tp), textDirection: ltr ? TextDirection.ltr : null,
    textInputAction: action ?? TextInputAction.next,
    decoration: InputDecoration(labelText: l, prefixIcon: Icon(ic, color: AC.goldText, size: 20),
      filled: true, fillColor: AC.navy3, labelStyle: TextStyle(color: AC.ts),
      isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.goldText))));

  Widget _pf(TextEditingController c, String l, bool o, VoidCallback t, {VoidCallback? sub, TextInputAction? action}) => TextField(
    controller: c, obscureText: o, style: TextStyle(color: AC.tp),
    textInputAction: action ?? (sub != null ? TextInputAction.done : TextInputAction.next),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(labelText: l, prefixIcon: Icon(Icons.lock_outlined, color: AC.goldText, size: 20),
      suffixIcon: IconButton(icon: Icon(o ? Icons.visibility_off : Icons.visibility, color: AC.ts, size: 20), onPressed: t),
      filled: true, fillColor: AC.navy3, labelStyle: TextStyle(color: AC.ts),
      isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.goldText))),
    onSubmitted: sub != null ? (_) => sub() : null);

  Widget _btn(String l, bool ld, VoidCallback fn) => SizedBox(width: double.infinity, height: 46,
    child: ElevatedButton(onPressed: ld ? null : fn,
      style: ElevatedButton.styleFrom(backgroundColor: AC.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: AC.gold.withAlpha(128)),
      child: ld ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy))
        : Text(l, style: TextStyle(color: AC.navy, fontSize: 15, fontWeight: FontWeight.bold))));

  Widget _errW(String m) => Container(width: double.infinity, margin: EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.err.withAlpha(26), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.err.withAlpha(77))),
    child: Row(children: [Icon(Icons.error_outline, color: AC.err, size: 16), SizedBox(width: 6),
      Expanded(child: Text(m, style: TextStyle(color: AC.err, fontSize: 11)))]));

  Widget _orW() => Row(children: [Expanded(child: Divider(color: AC.bdr)),
    Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('أو', style: TextStyle(color: AC.ts, fontSize: 11))),
    Expanded(child: Divider(color: AC.bdr))]);

  void _comingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تسجيل الدخول عبر $provider سيكون متاحاً قريباً', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy3,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _socW() => Column(children: [
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _comingSoon('Google'),
      style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr), padding: EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: Icon(Icons.g_mobiledata, color: AC.err, size: 22),
      label: Text('Google', style: TextStyle(color: AC.tp, fontSize: 12)))),
    SizedBox(height: 8),
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _comingSoon('Apple'),
      style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr), padding: EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: Icon(Icons.apple, color: AC.tp, size: 20),
      label: Text('Apple', style: TextStyle(color: AC.tp, fontSize: 12)))),
  ]);

  @override
  void dispose() { _lu.dispose(); _lp.dispose(); _rn.dispose(); _ru.dispose(); _rem.dispose(); _rp.dispose(); _rp2.dispose(); _rph.dispose(); super.dispose(); }
}