import 'dashboard_screen.dart';
import 'units_screen.dart';
import 'multistage_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ApexApp());
}

// ─── COLORS ───────────────────────────────────────────────────────────────────
class AC {
  static const gold = Color(0xFFC9A84C);
  static const goldDim = Color(0xFF8B6F35);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const textPrimary = Color(0xFFF0EDE6);
  static const textSecondary = Color(0xFF8A8880);
  static const textHint = Color(0xFF4A4845);
  static const success = Color(0xFF2ECC8A);
  static const warning = Color(0xFFF0A500);
  static const danger = Color(0xFFE05050);
  static const border = Color(0x26C9A84C);
}

class ApexApp extends StatelessWidget {
  const ApexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APEX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AC.navy,
        fontFamily: 'Tajawal',
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── SPLASH ───────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OnboardingScreen(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]),
                  boxShadow: [BoxShadow(color: AC.gold.withOpacity(0.4), blurRadius: 30)],
                ),
                child: const Center(child: Text('APEX', style: TextStyle(color: AC.navy, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Arial', letterSpacing: 2))),
              ),
              const SizedBox(height: 24),
              const Text('APEX', style: TextStyle(color: AC.gold, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 8, fontFamily: 'Arial')),
              const SizedBox(height: 10),
              const Text('\u0623\u0628\u064a\u0643\u0633 \u0644\u0644\u0627\u0633\u062a\u0634\u0627\u0631\u0627\u062a \u0627\u0644\u0645\u0627\u0644\u064a\u0629 \u0648\u0627\u0644\u0627\u0633\u062a\u062b\u0645\u0627\u0631\u064a\u0629', textDirection: TextDirection.rtl, style: TextStyle(color: AC.textSecondary, fontSize: 15, fontFamily: 'Tajawal')),
              const SizedBox(height: 4),
              const Text('APEX Finance & Investment Advisory', style: TextStyle(color: AC.textHint, fontSize: 12, fontFamily: 'Arial')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ONBOARDING ───────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _pages = const [
    _OBItem(Icons.analytics_rounded, AC.gold, '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a \u0630\u0643\u064a', '\u0627\u062d\u0635\u0644 \u0639\u0644\u0649 16+ \u0646\u0633\u0628\u0629 \u0645\u0627\u0644\u064a\u0629 \u062e\u0644\u0627\u0644 30 \u062b\u0627\u0646\u064a\u0629'),
    _OBItem(Icons.auto_graph_rounded, AC.cyan, '\u062a\u0648\u0642\u0639\u0627\u062a \u0645\u0633\u062a\u0642\u0628\u0644\u064a\u0629', '\u0646\u0645\u0627\u0630\u062c AI \u0644\u0640 3-5 \u0633\u0646\u0648\u0627\u062a \u0628\u062b\u0644\u0627\u062b\u0629 \u0633\u064a\u0646\u0627\u0631\u064a\u0648\u0647\u0627\u062a'),
    _OBItem(Icons.verified_rounded, AC.success, '\u062c\u0627\u0647\u0632\u064a\u0629 \u0627\u0644\u0627\u0633\u062a\u062b\u0645\u0627\u0631', '\u062f\u0631\u062c\u0629 \u0634\u0627\u0645\u0644\u0629 \u0645\u0646 100 \u0644\u0642\u064a\u0627\u0633 \u062c\u0627\u0647\u0632\u064a\u0629 \u0634\u0631\u0643\u062a\u0643'),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: SafeArea(
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('\u062a\u062e\u0637\u064a', style: TextStyle(color: AC.textSecondary, fontFamily: 'Tajawal')))),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 120, height: 120,
                        decoration: BoxDecoration(color: p.color.withOpacity(0.08), borderRadius: BorderRadius.circular(32), border: Border.all(color: p.color.withOpacity(0.2), width: 1.5)),
                        child: Icon(p.icon, color: p.color, size: 56)),
                      const SizedBox(height: 36),
                      Text(p.title, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AC.textPrimary, fontFamily: 'Tajawal')),
                      const SizedBox(height: 16),
                      Text(p.subtitle, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.7)),
                    ]),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 6, height: 6,
                decoration: BoxDecoration(color: i == _page ? AC.gold : const Color(0xFF2A2A28), borderRadius: BorderRadius.circular(3))))),
            const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _GoldBtn(label: _page == _pages.length - 1 ? '\u0627\u0628\u062f\u0623 \u0627\u0644\u0622\u0646' : '\u0627\u0644\u062a\u0627\u0644\u064a', onTap: _next)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OBItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _OBItem(this.icon, this.color, this.title, this.subtitle);
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('APEX', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3, fontFamily: 'Arial')),
                Text('\u0623\u0628\u064a\u0643\u0633', style: TextStyle(color: AC.textSecondary, fontSize: 11, fontFamily: 'Tajawal')),
              ]),
              const SizedBox(width: 10),
              Container(width: 44, height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AC.gold, AC.goldDim])),
                child: const Center(child: Text('AX', style: TextStyle(color: AC.navy, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Arial')))),
            ]),
            const SizedBox(height: 36),
            const Text('\u0645\u0631\u062d\u0628\u0627\u064b \u0628\u0639\u0648\u062f\u062a\u0643', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AC.textPrimary, fontFamily: 'Tajawal')),
            const SizedBox(height: 6),
            const Text('\u0633\u062c\u0651\u0644 \u062f\u062e\u0648\u0644\u0643 \u0644\u0644\u0648\u0635\u0648\u0644 \u0625\u0644\u0649 \u0644\u0648\u062d\u0629 \u0627\u0644\u062a\u062d\u0643\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', textDirection: TextDirection.rtl,
              style: TextStyle(color: AC.textSecondary, fontSize: 15, fontFamily: 'Tajawal')),
            const SizedBox(height: 32),
            const Text('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            _inputBox(hint: 'example@company.com', icon: Icons.email_outlined),
            const SizedBox(height: 14),
            const Text('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
              child: TextField(obscureText: _obscure, textDirection: TextDirection.ltr,
                style: const TextStyle(color: AC.textPrimary),
                decoration: InputDecoration(
                  hintText: '••••••••', hintStyle: const TextStyle(color: AC.textSecondary),
                  prefixIcon: const Icon(Icons.lock_outline, color: AC.textSecondary),
                  suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AC.textSecondary)),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)))),
            Align(alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () {},
                child: const Text('\u0646\u0633\u064a\u062a \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631\u061f', style: TextStyle(color: AC.gold, fontSize: 13, fontFamily: 'Tajawal')))),
            const SizedBox(height: 16),
            _GoldBtn(label: '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644', isLoading: _loading,
              onTap: () async {
                setState(() => _loading = true);
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) {
                  setState(() => _loading = false);
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const NewDashboardScreen()));
                }
              }),
            const SizedBox(height: 20),
            Row(children: const [Expanded(child: Divider(color: Color(0xFF1A2030))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('\u0623\u0648', style: TextStyle(color: AC.textSecondary, fontFamily: 'Tajawal'))),
              Expanded(child: Divider(color: Color(0xFF1A2030)))]),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 54,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.cyan.withOpacity(0.3), width: 1.5)),
              child: const Center(child: Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0628\u0640 Google', style: TextStyle(color: AC.cyan, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')))),
            const SizedBox(height: 28),
            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Text('\u0644\u064a\u0633 \u0644\u062f\u064a\u0643 \u062d\u0633\u0627\u0628\u061f ', style: TextStyle(color: AC.textSecondary, fontSize: 14, fontFamily: 'Tajawal')),
              Text('\u0625\u0646\u0634\u0627\u0621 \u062d\u0633\u0627\u0628', style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _inputBox({required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: TextField(textDirection: TextDirection.ltr, style: const TextStyle(color: AC.textPrimary),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AC.textSecondary),
          prefixIcon: Icon(icon, color: AC.textSecondary), border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))));
  }
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIdx = 0;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return '\u0635\u0628\u0627\u062d \u0627\u0644\u062e\u064a\u0631';
    if (h < 17) return '\u0645\u0633\u0627\u0621 \u0627\u0644\u062e\u064a\u0631';
    return '\u0645\u0633\u0627\u0621 \u0627\u0644\u0646\u0648\u0631';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        elevation: 0,
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [AC.gold, AC.goldDim])),
            child: const Center(child: Text('AX', style: TextStyle(color: AC.navy, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Arial')))),
          const SizedBox(width: 8),
          const Text('APEX', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Arial')),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AC.textSecondary), onPressed: () {}),
          Padding(padding: const EdgeInsets.only(left: 12),
            child: Container(width: 36, height: 36,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AC.goldDim, Color(0xFF006B7D)])),
              child: const Center(child: Text('\u0634', style: TextStyle(color: AC.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Greeting
          Text('$_greeting\u060c \u0634\u0627\u062f\u064a \u0623\u0628\u0648\u0627\u0644\u0639\u0644\u0627 \ud83d\udc4b', textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
          const SizedBox(height: 4),
          const Text('\u0634\u0631\u0643\u0629 \u0623\u0628\u064a\u0643\u0633 \u2014 \u0627\u0644\u0631\u0628\u0639 \u0627\u0644\u0623\u0648\u0644 2025', textDirection: TextDirection.rtl,
            style: TextStyle(color: AC.textSecondary, fontSize: 14, fontFamily: 'Tajawal')),
          const SizedBox(height: 20),

          // Upload banner
          _UploadBanner(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnitsScreen()))),
          const SizedBox(height: 20),

          // KPIs
          Row(children: [
            Expanded(child: _KpiCard('\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a', '2.4M \u0631\u064a\u0627\u0644', '+18.5%', true, AC.gold)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d', '340K \u0631\u064a\u0627\u0644', '+12.1%', true, AC.cyan)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KpiCard('\u0647\u0627\u0645\u0634 \u0627\u0644\u0631\u0628\u062d', '14.2%', '+2.3 \u0646\u0642\u0637\u0629', true, AC.success)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('\u062f\u0631\u062c\u0629 \u0627\u0644\u062c\u0627\u0647\u0632\u064a\u0629', '87 / 100', '\u062c\u0627\u0647\u0632 \u0644\u0644\u062a\u0645\u0648\u064a\u0644', true, AC.success)),
          ]),
          const SizedBox(height: 24),

          // Chart
          _SectionHeader('\u062a\u0648\u0642\u0639\u0627\u062a \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a 2025-2029'),
          const SizedBox(height: 12),
          _ChartCard(),
          const SizedBox(height: 24),

          // Readiness
          _SectionHeader('\u062c\u0627\u0647\u0632\u064a\u0629 \u0627\u0644\u0627\u0633\u062a\u062b\u0645\u0627\u0631'),
          const SizedBox(height: 12),
          _ReadinessCard(),
          const SizedBox(height: 24),

          // Ratios
          _SectionHeader('\u0627\u0644\u0646\u0633\u0628 \u0627\u0644\u0645\u0627\u0644\u064a\u0629 \u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629'),
          const SizedBox(height: 12),
          _RatiosCard(),
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: AC.navy2, border: Border(top: BorderSide(color: AC.border))),
        child: BottomNavigationBar(
          currentIndex: _navIdx,
          onTap: (i) {
          setState(() => _navIdx = i);
          if (i == 1) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnitsScreen()));
          } else if (i == 3) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }
        },
          backgroundColor: Colors.transparent,
          selectedItemColor: AC.gold,
          unselectedItemColor: AC.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: '\u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629'),
            BottomNavigationBarItem(icon: Icon(Icons.upload_file_outlined), activeIcon: Icon(Icons.upload_file_rounded), label: '\u062a\u062d\u0644\u064a\u0644'),
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description_rounded), label: '\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: '\u0627\u0644\u062d\u0633\u0627\u0628'),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGETS ──────────────────────────────────────────────────────────────────

class _GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  const _GoldBtn({required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AC.gold, AC.goldDim], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AC.gold.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Center(child: isLoading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AC.navy, strokeWidth: 2.5))
          : Text(label, style: const TextStyle(color: AC.navy, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')))));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerRight,
    child: Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')));
}

class _ApexCard extends StatelessWidget {
  final Widget child;
  final bool gold;
  const _ApexCard({required this.child, this.gold = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AC.navy3,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: gold ? AC.gold.withOpacity(0.4) : AC.border, width: gold ? 1.5 : 1)),
    child: child);
}

class _KpiCard extends StatelessWidget {
  final String label, value, delta;
  final bool positive;
  final Color color;
  const _KpiCard(this.label, this.value, this.delta, this.positive, this.color);
  @override
  Widget build(BuildContext context) => _ApexCard(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
    const SizedBox(height: 8),
    Text(value, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
    const SizedBox(height: 4),
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(delta, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: positive ? AC.success : AC.danger, fontFamily: 'Tajawal')),
      const SizedBox(width: 2),
      Icon(positive ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: positive ? AC.success : AC.danger),
    ]),
  ]));
}

class _UploadBanner extends StatelessWidget {
  final VoidCallback? onTap;
  const _UploadBanner({this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AC.navy4, AC.navy3], begin: Alignment.topRight, end: Alignment.bottomLeft),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AC.gold.withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.arrow_forward_ios_rounded, color: AC.gold, size: 16),
      const Spacer(),
      const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('\u0627\u0631\u0641\u0639 \u0642\u0648\u0627\u0626\u0645\u0643 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
        SizedBox(height: 2),
        Text('PDF \u0623\u0648 Excel \u2014 \u0646\u062a\u0627\u0626\u062c \u062e\u0644\u0627\u0644 30 \u062b\u0627\u0646\u064a\u0629', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]),
      const SizedBox(width: 14),
      Container(width: 48, height: 48,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.upload_file_rounded, color: AC.navy, size: 24)),
    ])));
}

class _ChartCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ApexCard(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      _legendDot(AC.textHint, '\u0645\u062a\u062d\u0641\u0638'),
      const SizedBox(width: 12),
      _legendDot(AC.cyan, '\u0645\u062d\u0627\u064a\u062f'),
      const SizedBox(width: 12),
      _legendDot(AC.gold, '\u0645\u062a\u0641\u0627\u0626\u0644'),
    ]),
    const SizedBox(height: 16),
    SizedBox(height: 120, child: CustomPaint(size: const Size(double.infinity, 120), painter: _ChartPainter())),
    const SizedBox(height: 8),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['2025','2026','2027','2028','2029']
      .map((y) => Text(y, style: const TextStyle(fontSize: 10, color: AC.textHint, fontFamily: 'Arial'))).toList()),
  ]));

  Widget _legendDot(Color c, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(l, style: TextStyle(fontSize: 11, color: c, fontFamily: 'Tajawal')),
    const SizedBox(width: 4),
    Container(width: 16, height: 3, color: c),
  ]);
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width; final H = size.height;
    final grid = Paint()..color = AC.gold.withOpacity(0.05)..strokeWidth = 1;
    for (int i = 1; i < 4; i++) canvas.drawLine(Offset(0, H * i / 4), Offset(W, H * i / 4), grid);

    void drawLine(List<Offset> pts, Color c, double w, {bool dashed = false}) {
      final p = Paint()..color = c..strokeWidth = w..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        final mid = Offset((pts[i-1].dx + pts[i].dx)/2, (pts[i-1].dy + pts[i].dy)/2);
        path.quadraticBezierTo(pts[i-1].dx, pts[i-1].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, p);
    }

    final p1 = [Offset(0,H*.8), Offset(W*.25,H*.65), Offset(W*.5,H*.45), Offset(W*.75,H*.28), Offset(W,H*.1)];
    final p2 = [Offset(0,H*.85), Offset(W*.25,H*.73), Offset(W*.5,H*.60), Offset(W*.75,H*.48), Offset(W,H*.38)];
    final p3 = [Offset(0,H*.90), Offset(W*.25,H*.82), Offset(W*.5,H*.74), Offset(W*.75,H*.68), Offset(W,H*.62)];

    final area = Paint()..shader = LinearGradient(colors: [AC.gold.withOpacity(0.2), AC.gold.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0,0,W,H));
    final aPath = Path()..moveTo(p1[0].dx,p1[0].dy);
    for (int i=1;i<p1.length;i++){final m=Offset((p1[i-1].dx+p1[i].dx)/2,(p1[i-1].dy+p1[i].dy)/2);aPath.quadraticBezierTo(p1[i-1].dx,p1[i-1].dy,m.dx,m.dy);}
    aPath.lineTo(p1.last.dx,H);aPath.lineTo(p1.first.dx,H);aPath.close();
    canvas.drawPath(aPath,area);

    drawLine(p1, AC.gold, 2.5);
    drawLine(p2, AC.cyan, 1.8);
    drawLine(p3, AC.textHint, 1.2);

    final dot = Paint()..color = AC.gold;
    for (final pt in p1) canvas.drawCircle(pt, 3, dot);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _ReadinessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ApexCard(gold: true, child: Column(children: [
    Row(children: [
      SizedBox(width: 80, height: 80, child: CustomPaint(painter: _RingPainter(0.87),
        child: const Center(child: Text('87', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.w900))))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('87 / 100', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AC.gold, height: 1, fontFamily: 'Tajawal')),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AC.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.success.withOpacity(0.3))),
          child: const Text('\u062c\u0627\u0647\u0632 \u0644\u0644\u062a\u0645\u0648\u064a\u0644 Series A', style: TextStyle(fontSize: 12, color: AC.success, fontFamily: 'Tajawal'))),
      ])),
    ]),
    const SizedBox(height: 16),
    const Divider(color: AC.border),
    const SizedBox(height: 12),
    Row(children: [
      _subScore('\u0645\u0644\u0627\u0621\u0645\u0629 \u0627\u0644\u0633\u0648\u0642', 83, AC.gold),
      _subScore('\u0627\u0644\u0646\u0645\u0648', 88, AC.success),
      _subScore('\u0627\u0644\u062d\u0648\u0643\u0645\u0629', 85, AC.cyan),
      _subScore('\u0627\u0644\u0623\u062f\u0627\u0621', 92, AC.gold),
    ]),
  ]));

  Widget _subScore(String l, int s, Color c) => Expanded(child: Column(children: [
    Text('$s', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c, fontFamily: 'Tajawal')),
    Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
  ]));
}

class _RingPainter extends CustomPainter {
  final double v;
  const _RingPainter(this.v);
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width/2, s.height/2);
    final r = s.width/2 - 6;
    c.drawCircle(center, r, Paint()..color=AC.gold.withOpacity(0.1)..strokeWidth=8..style=PaintingStyle.stroke);
    c.drawArc(Rect.fromCircle(center: center, radius: r), -1.5707963, 2*3.14159*v, false,
      Paint()..color=AC.gold..strokeWidth=8..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _RatiosCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ApexCard(child: Column(children: [
    _ratio('\u0627\u0644\u0639\u0627\u0626\u062f \u0639\u0644\u0649 \u062d\u0642\u0648\u0642 \u0627\u0644\u0645\u0644\u0643\u064a\u0629 (ROE)', '18.4%', 0.73, AC.gold),
    const SizedBox(height: 12),
    _ratio('\u0646\u0633\u0628\u0629 \u0627\u0644\u0633\u064a\u0648\u0644\u0629 \u0627\u0644\u062c\u0627\u0631\u064a\u0629', '1.82', 0.61, AC.cyan),
    const SizedBox(height: 12),
    _ratio('\u0647\u0627\u0645\u0634 \u0627\u0644\u0631\u0628\u062d \u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a', '42.5%', 0.85, AC.success),
    const SizedBox(height: 12),
    _ratio('\u0647\u0627\u0645\u0634 EBITDA', '22.8%', 0.76, AC.gold),
    const SizedBox(height: 12),
    _ratio('\u0646\u0633\u0628\u0629 \u0627\u0644\u062f\u064a\u0646 / \u062d\u0642\u0648\u0642 \u0627\u0644\u0645\u0644\u0643\u064a\u0629', '0.68', 0.34, AC.success),
  ]));

  Widget _ratio(String l, String v, double pct, Color c) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(v, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
      Text(l, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
    ]),
    const SizedBox(height: 6),
    ClipRRect(borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: Colors.white.withOpacity(0.06), valueColor: AlwaysStoppedAnimation(c))),
  ]);
}

// ─── UPLOAD SCREEN ────────────────────────────────────────────────────────────
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _fileSelected = false;
  bool _analyzing = false;
  bool _done = false;
  double _progress = 0;
  String _fileName = '';

  Future<void> _simulateUpload() async {
    setState(() { _fileSelected = true; _fileName = '\u0627\u0644\u0642\u0648\u0627\u0626\u0645_\u0627\u0644\u0645\u0627\u0644\u064a\u0629_2024.pdf'; });
  }

  Future<void> _startAnalysis() async {
    setState(() { _analyzing = true; _progress = 0; });
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _progress = i / 10);
    }
    if (mounted) setState(() { _analyzing = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        elevation: 0,
        title: const Text('\u0631\u0641\u0639 \u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Upload zone
          GestureDetector(
            onTap: _fileSelected || _analyzing ? null : _simulateUpload,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity, height: 200,
              decoration: BoxDecoration(
                color: _done ? AC.success.withOpacity(0.05) : _fileSelected ? AC.gold.withOpacity(0.05) : AC.navy3,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _done ? AC.success.withOpacity(0.4) : _fileSelected ? AC.gold.withOpacity(0.4) : AC.border,
                  width: 1.5)),
              child: _done ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded, color: AC.success, size: 52),
                const SizedBox(height: 12),
                const Text('\u0627\u0643\u062a\u0645\u0644 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0628\u0646\u062c\u0627\u062d!', style: TextStyle(color: AC.success, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
                const SizedBox(height: 4),
                Text(_fileName, style: const TextStyle(color: AC.textSecondary, fontSize: 13, fontFamily: 'Tajawal')),
              ]) : _fileSelected ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.description_rounded, color: AC.gold, size: 52),
                const SizedBox(height: 12),
                Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                const SizedBox(height: 6),
                const Text('\u062a\u0645 \u0631\u0641\u0639 \u0627\u0644\u0645\u0644\u0641 \u0628\u0646\u062c\u0627\u062d', style: TextStyle(color: AC.gold, fontSize: 13, fontFamily: 'Tajawal')),
              ]) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.cloud_upload_outlined, color: AC.gold, size: 32)),
                const SizedBox(height: 14),
                const Text('\u0627\u0636\u063a\u0637 \u0644\u0631\u0641\u0639 \u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
                const SizedBox(height: 6),
                const Text('PDF, XLSX, XLS \u2014 \u062d\u062c\u0645 \u0623\u0642\u0635\u0649 20MB', style: TextStyle(color: AC.textSecondary, fontSize: 13, fontFamily: 'Tajawal')),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // File types
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _fileChip(Icons.picture_as_pdf, 'PDF', AC.danger),
            const SizedBox(width: 10),
            _fileChip(Icons.table_chart_outlined, 'Excel', AC.success),
            const SizedBox(width: 10),
            _fileChip(Icons.description_outlined, 'CSV', AC.cyan),
          ]),
          const SizedBox(height: 28),

          // What we extract
          const Align(alignment: Alignment.centerRight,
            child: Text('\u0645\u0627 \u0633\u064a\u062a\u0645 \u0627\u0633\u062a\u062e\u0631\u0627\u062c\u0647\u061f', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal'))),
          const SizedBox(height: 12),
          _extractItem(Icons.analytics_rounded, '16+ \u0646\u0633\u0628\u0629 \u0645\u0627\u0644\u064a\u0629', '\u0645\u062d\u0633\u0648\u0628\u0629 \u062a\u0644\u0642\u0627\u0626\u064a\u0627\u064b \u0648\u0645\u0642\u0627\u0631\u0646\u0629 \u0628\u0627\u0644\u0642\u0637\u0627\u0639'),
          _extractItem(Icons.auto_graph_rounded, '\u0627\u0644\u0646\u0645\u0630\u062c\u0629 \u0627\u0644\u062a\u0646\u0628\u0624\u064a\u0629', '\u062a\u0648\u0642\u0639\u0627\u062a 3-5 \u0633\u0646\u0648\u0627\u062a \u0628\u062b\u0644\u0627\u062b\u0629 \u0633\u064a\u0646\u0627\u0631\u064a\u0648\u0647\u0627\u062a'),
          _extractItem(Icons.verified_rounded, '\u062c\u0627\u0647\u0632\u064a\u0629 \u0627\u0644\u0627\u0633\u062a\u062b\u0645\u0627\u0631', '\u062f\u0631\u062c\u0629 \u0634\u0627\u0645\u0644\u0629 \u0645\u0646 100 \u0646\u0642\u0637\u0629'),
          _extractItem(Icons.description_rounded, '\u062a\u0642\u0631\u064a\u0631 \u0627\u062d\u062a\u0631\u0627\u0641\u064a', '\u0642\u0627\u0628\u0644 \u0644\u0644\u062a\u0635\u062f\u064a\u0631 PDF \u0648 Excel'),
          const SizedBox(height: 28),

          // Progress or button
          if (_analyzing) ...[
            const Text('\u062c\u0627\u0631\u064a \u062a\u062d\u0644\u064a\u0644 \u0642\u0648\u0627\u0626\u0645\u0643 \u0628\u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a...', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal', color: AC.textPrimary)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _progress, minHeight: 8, backgroundColor: AC.navy3, valueColor: const AlwaysStoppedAnimation<Color>(AC.gold))),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toInt()}% \u0627\u0643\u062a\u0645\u0644', style: const TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 13)),
          ] else if (_done) ...[
            // Success banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AC.success.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.success.withOpacity(0.3))),
              child: const Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\u0627\u0643\u062a\u0645\u0644 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0628\u0646\u062c\u0627\u062d!', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
                  SizedBox(height: 4),
                  Text('\u062a\u0645\u062a \u0627\u0644\u0645\u0639\u0627\u0644\u062c\u0629 \u0641\u064a 28 \u062b\u0627\u0646\u064a\u0629', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
                ])),
                SizedBox(width: 12),
                Icon(Icons.check_circle_rounded, color: AC.success, size: 32),
              ])),
            const SizedBox(height: 16),
            _GoldBtn(label: '\u0639\u0631\u0636 \u0627\u0644\u0646\u062a\u0627\u0626\u062c', onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalysisResultScreen()));
            }),
          ] else
            _GoldBtn(
              label: _fileSelected ? '\u0628\u062f\u0621 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0628\u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a' : '\u0627\u062e\u062a\u0631 \u0645\u0644\u0641\u0627\u064b \u0623\u0648\u0644\u0627\u064b',
              onTap: _fileSelected ? _startAnalysis : _simulateUpload),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _fileChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Arial')),
    ]));

  Widget _extractItem(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal', color: AC.textPrimary)),
          Text(sub, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ])),
        const SizedBox(width: 12),
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AC.gold, size: 18)),
      ])));
}

// ─── ANALYSIS RESULT SCREEN ───────────────────────────────────────────────────
class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key});
  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  int _tab = 0;
  final _tabs = ['\u0627\u0644\u0633\u064a\u0648\u0644\u0629', '\u0627\u0644\u0631\u0628\u062d\u064a\u0629', '\u0627\u0644\u0643\u0641\u0627\u0621\u0629', '\u0627\u0644\u0631\u0641\u0639 \u0627\u0644\u0645\u0627\u0644\u064a'];

  final _ratios = {
    0: [('\u0646\u0633\u0628\u0629 \u0627\u0644\u0633\u064a\u0648\u0644\u0629 \u0627\u0644\u062c\u0627\u0631\u064a\u0629', '1.82', 0.61),
        ('\u0646\u0633\u0628\u0629 \u0627\u0644\u0633\u064a\u0648\u0644\u0629 \u0627\u0644\u0633\u0631\u064a\u0639\u0629', '1.45', 0.48),
        ('\u0646\u0633\u0628\u0629 \u0627\u0644\u0646\u0642\u062f\u064a\u0629', '0.92', 0.31)],
    1: [('\u0647\u0627\u0645\u0634 \u0627\u0644\u0631\u0628\u062d \u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a', '42.5%', 0.85),
        ('\u0647\u0627\u0645\u0634 \u0627\u0644\u0631\u0628\u062d \u0627\u0644\u0635\u0627\u0641\u064a', '14.2%', 0.57),
        ('\u0647\u0627\u0645\u0634 EBITDA', '22.8%', 0.76),
        ('\u0627\u0644\u0639\u0627\u0626\u062f \u0639\u0644\u0649 \u062d\u0642\u0648\u0642 \u0627\u0644\u0645\u0644\u0643\u064a\u0629 ROE', '18.4%', 0.73),
        ('\u0627\u0644\u0639\u0627\u0626\u062f \u0639\u0644\u0649 \u0627\u0644\u0623\u0635\u0648\u0644 ROA', '11.2%', 0.56)],
    2: [('\u0645\u0639\u062f\u0644 \u062f\u0648\u0631\u0627\u0646 \u0627\u0644\u0623\u0635\u0648\u0644', '1.24', 0.62),
        ('\u0645\u0639\u062f\u0644 \u062f\u0648\u0631\u0627\u0646 \u0627\u0644\u0645\u062e\u0632\u0648\u0646', '8.3', 0.70),
        ('\u062f\u0648\u0631\u0629 \u062a\u062d\u0635\u064a\u0644 \u0627\u0644\u0645\u062f\u064a\u0646\u064a\u0646', '42 \u064a\u0648\u0645', 0.55)],
    3: [('\u0646\u0633\u0628\u0629 \u0627\u0644\u062f\u064a\u0646 / \u0627\u0644\u0623\u0635\u0648\u0644', '0.40', 0.40),
        ('\u0646\u0633\u0628\u0629 \u0627\u0644\u062f\u064a\u0646 / \u062d\u0642\u0648\u0642 \u0627\u0644\u0645\u0644\u0643\u064a\u0629', '0.68', 0.34),
        ('\u062a\u063a\u0637\u064a\u0629 \u0627\u0644\u0641\u0648\u0627\u0626\u062f', '4.2x', 0.84)],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        elevation: 0,
        title: const Text('\u0646\u062a\u0627\u0626\u062c \u0627\u0644\u062a\u062d\u0644\u064a\u0644',
            style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary)),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_rounded, color: AC.gold, size: 18),
            label: const Text('\u062a\u0635\u062f\u064a\u0631', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal')),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Success banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.success.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.success.withOpacity(0.3))),
            child: const Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\u0627\u0643\u062a\u0645\u0644 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0628\u0646\u062c\u0627\u062d!', textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
                SizedBox(height: 4),
                Text('\u0627\u0644\u0642\u0648\u0627\u0626\u0645_\u0627\u0644\u0645\u0627\u0644\u064a\u0629_2024.pdf \u2014 \u062a\u0645\u062a \u0627\u0644\u0645\u0639\u0627\u0644\u062c\u0629 \u0641\u064a 28 \u062b\u0627\u0646\u064a\u0629', textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ])),
              SizedBox(width: 12),
              Icon(Icons.check_circle_rounded, color: AC.success, size: 32),
            ])),
          const SizedBox(height: 20),

          // Readiness score
          _ApexCard(gold: true, child: Row(children: [
            SizedBox(width: 90, height: 90,
              child: CustomPaint(painter: _RingPainter(0.87),
                child: const Center(child: Text('87', style: TextStyle(color: AC.gold, fontSize: 20, fontWeight: FontWeight.w900))))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('\u062f\u0631\u062c\u0629 \u062c\u0627\u0647\u0632\u064a\u0629 \u0627\u0644\u0627\u0633\u062a\u062b\u0645\u0627\u0631', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
              const Text('87 / 100', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AC.gold, height: 1, fontFamily: 'Tajawal')),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AC.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.success.withOpacity(0.3))),
                child: const Text('\u062c\u0627\u0647\u0632 \u0644\u0644\u062a\u0645\u0648\u064a\u0644 Series A',
                  style: TextStyle(fontSize: 12, color: AC.success, fontFamily: 'Tajawal'))),
            ])),
          ])),
          const SizedBox(height: 20),

          // AI Insights
          const Align(alignment: Alignment.centerRight,
            child: Text('\u062a\u0648\u0635\u064a\u0627\u062a \u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal'))),
          const SizedBox(height: 10),
          _insightCard(Icons.trending_up_rounded, AC.success, '\u0646\u0642\u0637\u0629 \u0642\u0648\u0629',
            '\u0647\u0627\u0645\u0634 \u0627\u0644\u0631\u0628\u062d \u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a (42.5%) \u0623\u0639\u0644\u0649 \u0645\u0646 \u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u0642\u0637\u0627\u0639 \u0628\u0640 8 \u0646\u0642\u0627\u0637 \u0645\u0626\u0648\u064a\u0629\u060c \u0645\u0645\u0627 \u064a\u0634\u064a\u0631 \u0625\u0644\u0649 \u0643\u0641\u0627\u0621\u0629 \u062a\u0634\u063a\u064a\u0644\u064a\u0629 \u0645\u0645\u062a\u0627\u0632\u0629.'),
          _insightCard(Icons.warning_amber_rounded, AC.warning, '\u062a\u0646\u0628\u064a\u0647',
            '\u0646\u0633\u0628\u0629 \u0627\u0644\u0633\u064a\u0648\u0644\u0629 \u0627\u0644\u0633\u0631\u064a\u0639\u0629 (1.45) \u0642\u0631\u064a\u0628\u0629 \u0645\u0646 \u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649. \u064a\u064f\u0646\u0635\u062d \u0628\u062a\u062d\u0633\u064a\u0646 \u0625\u062f\u0627\u0631\u0629 \u0631\u0623\u0633 \u0627\u0644\u0645\u0627\u0644 \u0627\u0644\u0639\u0627\u0645\u0644.'),
          _insightCard(Icons.auto_graph_rounded, AC.cyan, '\u0641\u0631\u0635\u0629',
            '\u0628\u0645\u0639\u062f\u0644 \u0646\u0645\u0648 18.5%\u060c \u062a\u062a\u0648\u0642\u0639 \u0646\u0645\u0627\u0630\u062c\u0646\u0627 \u0648\u0635\u0648\u0644 \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a \u0625\u0644\u0649 4.2M \u0631\u064a\u0627\u0644 \u0628\u062d\u0644\u0648\u0644 2028.'),
          const SizedBox(height: 20),

          // Ratios tabs
          const Align(alignment: Alignment.centerRight,
            child: Text('\u0627\u0644\u0646\u0633\u0628 \u0627\u0644\u0645\u0627\u0644\u064a\u0629 \u0627\u0644\u0645\u062d\u0633\u0648\u0628\u0629', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal'))),
          const SizedBox(height: 10),

          // Tab bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(_tabs.length, (i) => GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _tab == i ? AC.gold.withOpacity(0.1) : AC.navy3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _tab == i ? AC.gold : AC.border)),
                child: Text(_tabs[i], style: TextStyle(fontSize: 13, color: _tab == i ? AC.gold : AC.textSecondary, fontFamily: 'Tajawal', fontWeight: _tab == i ? FontWeight.w600 : FontWeight.w400)),
              )))),
          ),
          const SizedBox(height: 12),

          // Ratio bars
          _ApexCard(child: Column(children: _ratios[_tab]!.asMap().entries.map((e) => Padding(
            padding: EdgeInsets.only(bottom: e.key < _ratios[_tab]!.length - 1 ? 14 : 0),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.value.$2, style: const TextStyle(fontSize: 13, color: AC.gold, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                Text(e.value.$1, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: e.value.$3, minHeight: 4, backgroundColor: Colors.white.withOpacity(0.06), valueColor: const AlwaysStoppedAnimation<Color>(AC.gold))),
            ]))).toList())),
          const SizedBox(height: 20),

          // Export buttons
          Row(children: [
            Expanded(child: _GoldBtn(label: '\u062a\u062d\u0645\u064a\u0644 PDF', onTap: () {})),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 54,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.cyan.withOpacity(0.3), width: 1.5)),
              child: const Center(child: Text('\u062a\u062d\u0645\u064a\u0644 Excel', style: TextStyle(color: AC.cyan, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))))),
          ]),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _insightCard(IconData icon, Color color, String type, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _ApexCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(type, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        Text(text, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5)),
      ])),
      const SizedBox(width: 12),
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18)),
    ])));
}

// ─── PROFILE SCREEN ───────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        elevation: 0,
        title: const Text('\u0627\u0644\u062d\u0633\u0627\u0628',
            style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Profile header
          _ApexCard(gold: true, child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('\u0634\u0627\u062f\u064a \u0623\u0628\u0648\u0627\u0644\u0639\u0644\u0627', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
              const SizedBox(height: 2),
              const Text('contact@apexsmeai.com',
                style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Arial')),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AC.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.gold.withOpacity(0.3))),
                child: const Text('Professional Plan', style: TextStyle(fontSize: 11, color: AC.gold, fontFamily: 'Arial', fontWeight: FontWeight.w600))),
            ])),
            const SizedBox(width: 16),
            Container(width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AC.goldDim, Color(0xFF006B7D)]),
                border: Border.all(color: AC.gold.withOpacity(0.4), width: 2)),
              child: const Center(child: Text('\u0634', style: TextStyle(color: AC.textPrimary, fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')))),
          ])),
          const SizedBox(height: 16),

          // Subscription
          _ApexCard(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AC.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.success.withOpacity(0.3))),
                child: const Text('\u0646\u0634\u0637', style: TextStyle(fontSize: 11, color: AC.success, fontFamily: 'Tajawal'))),
              const Text('\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643 \u0627\u0644\u062d\u0627\u0644\u064a', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, color: AC.textSecondary, fontFamily: 'Tajawal')),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: const [
              Text('\u0631\u064a\u0627\u0644 / \u0634\u0647\u0631', style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
              SizedBox(width: 4),
              Text('1,999', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AC.gold, fontFamily: 'Tajawal')),
            ]),
            const SizedBox(height: 12),
            const Divider(color: AC.border),
            const SizedBox(height: 10),
            _usageRow('\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u0629', '12 / \u063a\u064a\u0631 \u0645\u062d\u062f\u0648\u062f'),
            const SizedBox(height: 6),
            _usageRow('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a \u0647\u0630\u0627 \u0627\u0644\u0634\u0647\u0631', '5 / \u063a\u064a\u0631 \u0645\u062d\u062f\u0648\u062f'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Container(height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
                child: const Center(child: Text('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631', style: TextStyle(color: AC.textSecondary, fontSize: 13, fontFamily: 'Tajawal'))))),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 44,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('\u062a\u0631\u0642\u064a\u0629 \u0627\u0644\u062e\u0637\u0629', style: TextStyle(color: AC.navy, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
            ]),
          ])),
          const SizedBox(height: 16),

          // Settings sections
          _settingsSection('\u0627\u0644\u062a\u0637\u0628\u064a\u0642', [
            _SettingTile(icon: Icons.notifications_outlined, label: '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a',
              trailing: Switch(value: _notifications, onChanged: (v) => setState(() => _notifications = v),
                activeColor: AC.gold, trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.gold.withOpacity(0.3) : AC.navy3))),
            _SettingTile(icon: Icons.language_rounded, label: '\u0627\u0644\u0644\u063a\u0629',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _langBtn('\u0639\u0631', true), const SizedBox(width: 6), _langBtn('EN', false),
              ])),
          ]),
          const SizedBox(height: 12),

          _settingsSection('\u0627\u0644\u062d\u0633\u0627\u0628 \u0648\u0627\u0644\u0623\u0645\u0627\u0646', [
            _SettingTile(icon: Icons.business_outlined, label: '\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0627\u0644\u0634\u0631\u0643\u0629', onTap: () {}),
            _SettingTile(icon: Icons.lock_outline_rounded, label: '\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', onTap: () {}),
            _SettingTile(icon: Icons.security_rounded, label: '\u0627\u0644\u0645\u0635\u0627\u062f\u0642\u0629 \u0627\u0644\u062b\u0646\u0627\u0626\u064a\u0629',
              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AC.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.warning.withOpacity(0.3))),
                child: const Text('\u063a\u064a\u0631 \u0645\u0641\u0639\u0651\u0644', style: TextStyle(fontSize: 10, color: AC.warning, fontFamily: 'Tajawal')))),
          ]),
          const SizedBox(height: 12),

          _settingsSection('\u0627\u0644\u062f\u0639\u0645 \u0648\u0627\u0644\u0645\u0633\u0627\u0639\u062f\u0629', [
            _SettingTile(icon: Icons.help_outline_rounded, label: '\u0645\u0631\u0643\u0632 \u0627\u0644\u0645\u0633\u0627\u0639\u062f\u0629', onTap: () {}),
            _SettingTile(icon: Icons.chat_outlined, label: '\u062a\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062f\u0639\u0645', onTap: () {}),
            _SettingTile(icon: Icons.star_outline_rounded, label: '\u0642\u064a\u0651\u0645 \u0627\u0644\u062a\u0637\u0628\u064a\u0642', onTap: () {}),
          ]),
          const SizedBox(height: 12),

          _settingsSection('\u0642\u0627\u0646\u0648\u0646\u064a', [
            _SettingTile(icon: Icons.privacy_tip_outlined, label: '\u0633\u064a\u0627\u0633\u0629 \u0627\u0644\u062e\u0635\u0648\u0635\u064a\u0629', onTap: () {}),
            _SettingTile(icon: Icons.description_outlined, label: '\u0634\u0631\u0648\u0637 \u0627\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645', onTap: () {}),
          ]),
          const SizedBox(height: 16),

          // Version
          const Text('\u0623\u0628\u064a\u0643\u0633 v1.0.0 \u2014 \u0623\u0628\u064a\u0643\u0633 \u0644\u0644\u0627\u0633\u062a\u0634\u0627\u0631\u0627\u062a \u0627\u0644\u0645\u0627\u0644\u064a\u0629 \u0648\u0627\u0644\u0627\u0633\u062a\u062b\u0645\u0627\u0631\u064a\u0629',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AC.textHint, fontFamily: 'Tajawal')),
          const SizedBox(height: 12),

          // Logout
          GestureDetector(
            onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
              backgroundColor: AC.navy3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AC.border)),
              title: const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary)),
              content: const Text('\u0647\u0644 \u0623\u0646\u062a \u0645\u062a\u0623\u0643\u062f \u0623\u0646\u0643 \u062a\u0631\u064a\u062f \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c\u061f', textDirection: TextDirection.rtl, style: TextStyle(color: AC.textSecondary, fontFamily: 'Tajawal')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('\u0625\u0644\u063a\u0627\u0621', style: TextStyle(color: AC.textSecondary, fontFamily: 'Tajawal'))),
                TextButton(onPressed: () { Navigator.pop(context); Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); },
                  child: const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c', style: TextStyle(color: AC.danger, fontFamily: 'Tajawal'))),
              ])),
            child: Container(width: double.infinity, height: 50,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.danger.withOpacity(0.3))),
              child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: AC.danger, size: 18),
                SizedBox(width: 8),
                Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c', style: TextStyle(color: AC.danger, fontSize: 15, fontFamily: 'Tajawal')),
              ])))),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _usageRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(value, style: const TextStyle(fontSize: 12, color: AC.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
      Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
    ]);

  Widget _langBtn(String label, bool active) => GestureDetector(
    onTap: () {},
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: active ? AC.gold.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: active ? AC.gold : AC.border)),
      child: Text(label, style: TextStyle(fontSize: 12, color: active ? AC.gold : AC.textSecondary, fontWeight: active ? FontWeight.w700 : FontWeight.w400, fontFamily: 'Tajawal'))));

  Widget _settingsSection(String title, List<_SettingTile> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Padding(padding: const EdgeInsets.only(right: 4, bottom: 8),
        child: Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', letterSpacing: 0.5))),
      _ApexCard(child: Column(children: items.asMap().entries.map((e) => Column(children: [
        ListTile(
          onTap: e.value.onTap,
          leading: e.value.trailing ?? (e.value.onTap != null ? const Icon(Icons.arrow_back_ios_rounded, color: AC.textHint, size: 14) : null),
          title: Text(e.value.label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal', color: AC.textPrimary)),
          trailing: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: AC.gold.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
            child: Icon(e.value.icon, color: AC.gold, size: 17)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
        if (e.key < items.length - 1) const Divider(height: 1, indent: 12, endIndent: 12, color: AC.border),
      ])).toList())),
    ]);
}

class _SettingTile {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingTile({required this.icon, required this.label, this.trailing, this.onTap});
}







