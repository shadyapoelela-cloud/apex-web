/// APEX — Services Page (top-level entry, clean)
/// /services — just the 10 services as big colored tiles.
/// Click a service → goes to its hub (apps).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class _Service {
  final String title;
  final String subtitle;
  final IconData icon;
  final int color;
  final String route;
  final int appCount;
  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    required this.appCount,
  });
}

class ApexServicesScreen extends StatelessWidget {
  const ApexServicesScreen({super.key});

  static const _services = [
    _Service(
      title: 'الرئيسية واليوم',
      subtitle: 'لوحة المؤشرات + AI Pulse + التقارير',
      icon: Icons.dashboard,
      color: 0xFFFFC107,
      route: '/today',
      appCount: 3,
    ),
    _Service(
      title: 'المبيعات',
      subtitle: 'العملاء · الفواتير · العروض · المتكررة',
      icon: Icons.receipt_long,
      color: 0xFF4CAF50,
      route: '/sales',
      appCount: 7,
    ),
    _Service(
      title: 'المشتريات',
      subtitle: 'الموردون · فواتير · أعمار · مدفوعات',
      icon: Icons.local_shipping,
      color: 0xFF2196F3,
      route: '/purchase',
      appCount: 3,
    ),
    _Service(
      title: 'المحاسبة',
      subtitle: 'القيود · شجرة الحسابات · ميزان المراجعة',
      icon: Icons.account_balance,
      color: 0xFF9C27B0,
      route: '/accounting',
      appCount: 6,
    ),
    _Service(
      title: 'العمليات',
      subtitle: 'POS · المخزون · الأصول · العهدة',
      icon: Icons.precision_manufacturing,
      color: 0xFFFF5722,
      route: '/operations',
      appCount: 6,
    ),
    _Service(
      title: 'الامتثال والضرائب',
      subtitle: 'ZATCA · VAT · زكاة · IFRS · KYC',
      icon: Icons.gavel,
      color: 0xFFE91E63,
      route: '/compliance-hub',
      appCount: 10,
    ),
    _Service(
      title: 'المراجعة الداخلية',
      subtitle: 'Workpapers · Benford · Sampling',
      icon: Icons.verified_user,
      color: 0xFF607D8B,
      route: '/audit',
      appCount: 4,
    ),
    _Service(
      title: 'التحليلات والتوقعات',
      subtitle: 'تدفقات · موازنات · صحة · عملات',
      icon: Icons.analytics,
      color: 0xFF00BCD4,
      route: '/analytics',
      appCount: 8,
    ),
    _Service(
      title: 'الموارد البشرية',
      subtitle: 'موظفون · رواتب · GOSI · سعودة',
      icon: Icons.people,
      color: 0xFF8BC34A,
      route: '/hr',
      appCount: 4,
    ),
    _Service(
      title: 'الموافقات والمعرفة',
      subtitle: 'موافقات · AI · معرفة · Copilot',
      icon: Icons.account_tree,
      color: 0xFF673AB7,
      route: '/workflow',
      appCount: 4,
    ),
    _Service(
      title: 'الإعدادات',
      subtitle: 'الحساب · الكيان · التكاملات',
      icon: Icons.settings,
      color: 0xFF795548,
      route: '/settings-hub',
      appCount: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.gold, AC.gold.withValues(alpha: 0.6)]),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.bolt, color: AC.navy, size: 20),
          ),
          const SizedBox(width: 8),
          Text('APEX',
              style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.dashboard_outlined, color: AC.gold),
            tooltip: 'اليوم',
            onPressed: () => context.go('/today'),
          ),
          IconButton(
            icon: Icon(Icons.smart_toy_outlined, color: AC.gold),
            tooltip: 'Ask APEX',
            onPressed: () => context.go('/copilot'),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AC.gold),
            tooltip: 'الإعدادات',
            onPressed: () => context.go('/settings/unified'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _welcomeCard(context),
          const SizedBox(height: 20),
          Text('اختر خدمة للبدء',
              style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          Text('كل خدمة تحتوي على عدة تطبيقات. اضغط الخدمة → ترى التطبيقات → اضغط التطبيق → ترى الشاشة.',
              style: TextStyle(color: AC.ts, fontSize: 11.5)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1100
                ? 4
                : MediaQuery.of(context).size.width > 700 ? 3 : 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: _services.map((s) => _serviceTile(context, s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _welcomeCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.18), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.20),
              border: Border.all(color: AC.gold),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bolt, color: AC.gold, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أهلاً بك في APEX',
                  style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${_services.length} خدمة · ${_services.fold<int>(0, (a, s) => a + s.appCount)} تطبيق',
                  style: TextStyle(color: AC.ts, fontSize: 12)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => context.go('/today'),
            icon: const Icon(Icons.dashboard, size: 16),
            label: const Text('لوحة اليوم'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
        ]),
      );

  Widget _serviceTile(BuildContext context, _Service s) {
    final color = Color(s.color);
    return InkWell(
      onTap: () => context.go(s.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.18), AC.navy2],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, color: color, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${s.appCount}',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
              ),
            ]),
            const Spacer(),
            Text(s.title,
                style: TextStyle(
                    color: AC.tp, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(s.subtitle,
                style: TextStyle(color: AC.ts, fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
