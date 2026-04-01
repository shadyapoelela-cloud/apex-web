import 'package:flutter/material.dart';
import 'main.dart'; // AC colors
import 'units_screen.dart';

class NewDashboardScreen extends StatelessWidget {
  const NewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'صباح الخير' : h < 17 ? 'مساء الخير' : 'مساء النور';

    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2, elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [AC.gold, AC.goldDim])),
            child: const Center(child: Text('AX', style: TextStyle(color: AC.navy, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Arial')))),
          const SizedBox(width: 8),
          const Text('APEX', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Arial')),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AC.textSecondary), onPressed: () {}),
          Padding(padding: const EdgeInsets.only(left: 12),
            child: Container(width: 36, height: 36, margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AC.goldDim, Color(0xFF006B7D)])),
              child: const Center(child: Text('ش', style: TextStyle(color: AC.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // ─── ترحيب ───
          Text('$greeting، شادي أبوالعلا 👋', textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
          const SizedBox(height: 4),
          const Text('مرحباً بك في منصة أبيكس للاستشارات المالية', textDirection: TextDirection.rtl,
            style: TextStyle(color: AC.textSecondary, fontSize: 14, fontFamily: 'Tajawal')),
          const SizedBox(height: 20),

          // ─── بانر تسويقي رئيسي ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.gold.withOpacity(0.15), AC.navy3], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.gold.withOpacity(0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('حوّل بياناتك المالية إلى قرارات ذكية', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AC.gold, fontFamily: 'Tajawal')),
              const SizedBox(height: 8),
              const Text('تحليل مالي شامل مدعوم بالذكاء الاصطناعي — دقة لا تقل عن 95%\nقوائم مالية + تحليل + توصيات + تقارير احترافية', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.6)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsScreen())),
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AC.gold.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.rocket_launch_rounded, color: AC.navy, size: 18),
                    SizedBox(width: 8),
                    Text('ابدأ الآن مجاناً', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
                  ])))),
            ]),
          ),
          const SizedBox(height: 24),

          // ─── لماذا APEX؟ ───
          const Text('لماذا أبيكس؟', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          const SizedBox(height: 12),
          Row(children: const [
            Expanded(child: _FeatureCard(icon: Icons.auto_awesome_rounded, color: AC.gold, title: 'ذكاء اصطناعي', sub: 'تحليل بـ Claude AI بدقة 95%+')),
            SizedBox(width: 10),
            Expanded(child: _FeatureCard(icon: Icons.speed_rounded, color: AC.cyan, title: 'سرعة فائقة', sub: 'نتائج خلال 30 ثانية')),
            SizedBox(width: 10),
            Expanded(child: _FeatureCard(icon: Icons.verified_rounded, color: AC.success, title: 'دقة مضمونة', sub: 'نظام 4 مراحل للتحقق')),
          ]),
          const SizedBox(height: 24),

          // ─── إحصائيات المنصة ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
            child: Row(children: const [
              Expanded(child: _StatItem(value: '500+', label: 'تقرير مالي')),
              Expanded(child: _StatItem(value: '95%+', label: 'دقة التحليل')),
              Expanded(child: _StatItem(value: '30 ث', label: 'وقت التحليل')),
              Expanded(child: _StatItem(value: '8', label: 'خدمات متكاملة')),
            ]),
          ),
          const SizedBox(height: 24),

          // ─── خطط الاشتراك ───
          const Text('خطط الاشتراك', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          const Text('اختر الخطة المناسبة لاحتياجاتك', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
          const SizedBox(height: 14),

          // مجاني
          _PlanCard(name: 'مجاني', price: '0', color: AC.textSecondary, features: const [
            'إعداد القوائم المالية — 3 مرات/شهر',
            'نتائج الكود فقط بدون AI',
            'بدون تقارير PDF/Excel',
          ], isFree: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsScreen()))),
          const SizedBox(height: 10),

          // 200
          _PlanCard(name: 'الأساسية', price: '200', color: const Color(0xFF1D9E75), features: const [
            '① إعداد القوائم — غير محدود + AI',
            '② إرفاق القوائم المعتمدة — 5 مرات',
            'تقارير PDF + Excel',
          ], onTap: () {}),
          const SizedBox(height: 10),

          // 500 — الأكثر شعبية
          _PlanCard(name: 'الاحترافية', price: '500', color: AC.cyan, popular: true, features: const [
            '① + ② غير محدود',
            '③ تحليل المبيعات — 10 مرات',
            '④ تحليل الجرد — 5 مرات',
            'تحليل AI متعدد المراحل (دقة 95%+)',
          ], onTap: () {}),
          const SizedBox(height: 10),

          // 1500
          _PlanCard(name: 'المتقدمة', price: '1,500', color: const Color(0xFF6C5CE7), features: const [
            '①②③④ غير محدود',
            '⑤ التحليل الائتماني — 5 مرات',
            '⑥ التدفق النقدي والتوقعات',
            'مقارنة بمعايير القطاع',
          ], onTap: () {}),
          const SizedBox(height: 10),

          // 3000
          _PlanCard(name: 'المؤسسية', price: '3,000', color: const Color(0xFFE17055), features: const [
            'كل الوحدات ①-⑧',
            'استشارة مهنية — جلسة/شهر',
            'API مفتوح للربط مع أنظمتك',
          ], onTap: () {}),
          const SizedBox(height: 10),

          // 5000
          _PlanCard(name: 'VIP الشاملة', price: '5,000', color: AC.gold, features: const [
            'كل شيء بلا حدود',
            '4 جلسات استشارية/شهر',
            'مدير حساب مخصص + White Label',
            'دعم أولوية 24/7',
          ], onTap: () {}),
          const SizedBox(height: 24),

          // ─── تعرّف على خدماتنا ───
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsScreen())),
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AC.gold.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]),
              child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.apps_rounded, color: AC.navy, size: 20),
                SizedBox(width: 8),
                Text('تعرّف على خدماتنا', style: TextStyle(color: AC.navy, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
              ])))),
          const SizedBox(height: 24),

          // ─── شهادات عملاء ───
          const Text('ماذا يقول عملاؤنا', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          const SizedBox(height: 12),
          _TestimonialCard(name: 'م. عبدالله الراشد', role: 'مدير مالي — شركة تقنية', text: 'وفّرت لنا المنصة ساعات من العمل اليدوي وأعطتنا تحليلاً أدق مما كنا نحصل عليه من المكاتب الخارجية.'),
          const SizedBox(height: 8),
          _TestimonialCard(name: 'أ. نورة السبيعي', role: 'مؤسسة شركة ناشئة', text: 'ساعدتني أبيكس في فهم وضعي المالي بوضوح وحصلت على تمويل بفضل تقاريرها الاحترافية.'),
          const SizedBox(height: 40),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: AC.navy2, border: Border(top: BorderSide(color: AC.border))),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (i) {
            if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsScreen()));
            else if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: AC.gold,
          unselectedItemColor: AC.textSecondary,
          type: BottomNavigationBarType.fixed, elevation: 0,
          selectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.apps_outlined), activeIcon: Icon(Icons.apps_rounded), label: 'الخدمات'),
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description_rounded), label: 'التقارير'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'الحساب'),
          ],
        ),
      ),
    );
  }
}

// ═══ بطاقة ميزة ═══
class _FeatureCard extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub;
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
    child: Column(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
      const SizedBox(height: 2),
      Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
    ]));
}

// ═══ إحصائية ═══
class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
  ]);
}

// ═══ بطاقة خطة اشتراك ═══
class _PlanCard extends StatelessWidget {
  final String name, price;
  final Color color;
  final List<String> features;
  final bool popular, isFree;
  final VoidCallback onTap;
  const _PlanCard({required this.name, required this.price, required this.color, required this.features, required this.onTap, this.popular = false, this.isFree = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.navy3,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: popular ? color : AC.border, width: popular ? 1.5 : 1)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [
        if (popular) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Text('الأكثر شعبية', style: TextStyle(fontSize: 9, color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700))),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text(' ريال/شهر', style: TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal')),
            Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, fontFamily: 'Tajawal')),
          ]),
        ]),
      ]),
      const SizedBox(height: 10),
      ...features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(child: Text(f, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
          const SizedBox(width: 6),
          Icon(Icons.check_circle_rounded, color: color.withOpacity(0.6), size: 14),
        ]))),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, height: 40,
          decoration: BoxDecoration(
            color: isFree ? color.withOpacity(0.1) : color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4))),
          child: Center(child: Text(isFree ? 'ابدأ مجاناً' : 'اشترك الآن',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))))),
    ]));
}

// ═══ شهادة عميل ═══
class _TestimonialCard extends StatelessWidget {
  final String name, role, text;
  const _TestimonialCard({required this.name, required this.role, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          Text(role, style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(width: 10),
        Container(width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AC.gold.withOpacity(0.1)),
          child: const Icon(Icons.format_quote_rounded, color: AC.gold, size: 18)),
      ]),
      const SizedBox(height: 8),
      Text('"$text"', textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5, fontStyle: FontStyle.italic)),
    ]));
}
