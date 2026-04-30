import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

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
      } else { setState(() { _e = res.error ?? 'خطأ في الدخول'; _l = false; }); }
    } catch (e) { setState(() { _e = 'خطأ الاتصال: $e'; _l = false; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AC.navy, AC.navy2, AC.navy],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AC.gold.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: -8),
              BoxShadow(color: AC.gold.withValues(alpha: 0.06), blurRadius: 60, spreadRadius: -4),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Logo with glow
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AC.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AC.gold.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: AC.gold.withValues(alpha: 0.08), blurRadius: 32, spreadRadius: 2),
              BoxShadow(color: AC.gold.withValues(alpha: 0.04), blurRadius: 60, spreadRadius: 8),
            ],
          ),
          child: Column(children: [
            Icon(Icons.account_balance, color: AC.goldText, size: 56),
            const SizedBox(height: 10),
            ApexLogo(fontSize: 36),
            const SizedBox(height: 6),
            Text('منصة التحليل المالي والخدمات المهنية',
              style: TextStyle(color: AC.ts, fontSize: 11)),
            const SizedBox(height: 4),
            Text('منصة الذكاء المالي',
              style: TextStyle(color: AC.goldText.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          ]),
        ),
        const SizedBox(height: 32),
        // Title
        Text('تسجيل الدخول', style: TextStyle(color: AC.tp, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('أدخل بياناتك للمتابعة', style: TextStyle(color: AC.ts, fontSize: 13)),
        const SizedBox(height: 24),
        // Error
        if (_e != null) Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.err.withValues(alpha: 0.3))),
          child: Row(children: [Icon(Icons.error_outline, color: AC.err, size: 18), const SizedBox(width: 8),
            Expanded(child: Text(_e!, style: TextStyle(color: AC.err, fontSize: 12)))]),
        ),
        // Email field
        TextField(controller: _u, style: TextStyle(color: AC.tp),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'البريد أو اسم المستخدم',
            prefixIcon: Icon(Icons.email_outlined, color: AC.goldText, size: 20),
            filled: true, fillColor: AC.navy3.withValues(alpha: 0.5), labelStyle: TextStyle(color: AC.ts),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.bdr.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.bdr.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.goldText, width: 1.5)),
          )),
        const SizedBox(height: 16),
        // Password field
        TextField(controller: _p, obscureText: _obscure, style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: Icon(Icons.lock_outlined, color: AC.goldText, size: 20),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AC.ts, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure)),
            filled: true, fillColor: AC.navy3.withValues(alpha: 0.5), labelStyle: TextStyle(color: AC.ts),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.bdr.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.bdr.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.goldText, width: 1.5)),
          ),
          onSubmitted: (_) => _go()),
        // Forgot password
        Align(alignment: AlignmentDirectional.centerStart, child: TextButton(
          onPressed: () => context.go('/forgot-password'),
          child: Text('نسيت كلمة المرور؟', style: TextStyle(color: AC.goldText, fontSize: 12)))),
        const SizedBox(height: 8),
        // Login button with gradient
        SizedBox(width: double.infinity, height: 50, child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: _l ? null : LinearGradient(colors: [AC.gold, AC.goldLight]),
            color: _l ? AC.gold.withValues(alpha: 0.5) : null,
            boxShadow: _l ? null : [BoxShadow(color: AC.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: _l ? null : _go,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: AC.gold.withValues(alpha: 0.5),
            ),
            child: _l ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AC.navy))
              : Text('تسجيل الدخول', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        )),
        const SizedBox(height: 24),
        // Divider with "or" pill
        Row(children: [
          Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AC.bdr])))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AC.navy3.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AC.bdr.withValues(alpha: 0.3))),
              child: Text('أو', style: TextStyle(color: AC.ts, fontSize: 12, fontWeight: FontWeight.w500)),
            )),
          Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.bdr, Colors.transparent])))),
        ]),
        const SizedBox(height: 20),
        // Social Login Buttons (UI only - not functional yet)
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('قريباً - Google Sign-In'), backgroundColor: AC.navy3)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: Icon(Icons.g_mobiledata, color: AC.err, size: 24),
            label: Text('Google', style: TextStyle(color: AC.tp, fontSize: 12)),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('قريباً - Apple Sign-In'), backgroundColor: AC.navy3)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: Icon(Icons.apple, color: AC.tp, size: 22),
            label: Text('Apple', style: TextStyle(color: AC.tp, fontSize: 12)),
          )),
        ]),
        const SizedBox(height: 24),
        // Subtle divider before register
        Row(children: [
          Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AC.bdr.withValues(alpha: 0.3)])))),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.bdr.withValues(alpha: 0.3), Colors.transparent])))),
        ]),
        const SizedBox(height: 8),
        // Register link
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('ليس لديك حساب؟', style: TextStyle(color: AC.ts, fontSize: 13)),
          TextButton(onPressed: () => context.go('/register'),
            child: Text('إنشاء حساب', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.bold))),
        ]),
      ]),
    ),
  ),
    )),
    ),
  );
}
