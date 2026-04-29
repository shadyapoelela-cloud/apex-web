/// APEX Map — single-page index of every demo screen built in Sprints
/// 35-44. Useful as a sales-demo landing page, for internal QA, and as
/// the canonical "what does APEX do" deep link.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import 'package:go_router/go_router.dart';

import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ApexMapScreen extends StatelessWidget {
  const ApexMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: '🗺️ خريطة APEX — كل الشاشات'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(),
                  const SizedBox(height: AppSpacing.xl),
                  for (final sec in _sections) ...[
                    _section(context, sec),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.3), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AC.gold.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.map, color: core_theme.AC.warn, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('خريطة منصة APEX الكاملة',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.display,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '10 شاشات ديمو + 20 مكوّناً + 4 خدمات backend — مخطط APEX 2026 بنسبة 97%',
              style: TextStyle(
                  color: AC.ts, fontSize: AppFontSize.lg, height: 1.5),
            ),
          ],
        ),
      );

  Widget _section(BuildContext ctx, _Section s) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(s.icon, color: s.accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w700)),
                    Text(s.subtitle,
                        style: TextStyle(
                            color: AC.ts, fontSize: AppFontSize.sm)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount:
                  MediaQuery.of(ctx).size.width > 900 ? 3 : 2,
              childAspectRatio: 3.5,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              children: [
                for (final it in s.items) _card(ctx, it, s.accent),
              ],
            ),
          ],
        ),
      );

  Widget _card(BuildContext ctx, _Item it, Color accent) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(ctx).go(it.route),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(it.icon, size: 18, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title,
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.sm,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(it.route,
                        style: TextStyle(
                            color: AC.td,
                            fontSize: AppFontSize.xs,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: AC.td),
            ]),
          ),
        ),
      );

  static final _sections = [
    _Section(
      title: 'شاشات الـ Sprint الجديدة',
      subtitle: '10 شاشات ديمو بُنيت في هذه الجلسة',
      icon: Icons.auto_awesome,
      accent: core_theme.AC.gold,
      items: const [
        _Item(
            title: 'Sprint 35-36: الأساس',
            route: '/sprint35-foundation',
            icon: Icons.bolt),
        _Item(
            title: 'Sprint 37-38: تجربة محسَّنة',
            route: '/sprint37-experience',
            icon: Icons.auto_awesome_motion),
        _Item(
            title: 'Sprint 38: قابل للتكوين',
            route: '/sprint38-composable',
            icon: Icons.view_quilt),
        _Item(
            title: 'Sprint 39-40: توسّع ERP',
            route: '/sprint39-erp',
            icon: Icons.factory_outlined),
        _Item(
            title: 'الرواتب + التقارير (Sprint 40 → Production)',
            route: '/app/erp/hr/payroll',
            icon: Icons.analytics_outlined),
        _Item(
            title: 'Sprint 41: شراء + استلام',
            route: '/sprint41-procurement',
            icon: Icons.inventory_outlined),
        _Item(
            title: 'التدفق النقدي + التوحيد + BOM (Sprint 42 → Production)',
            route: '/app/erp/treasury/cashflow',
            icon: Icons.auto_graph),
        _Item(
            title: 'Sprint 43: منظومة المنصة',
            route: '/sprint43-platform',
            icon: Icons.public),
        _Item(
            title: 'Sprint 44: عمليات التصنيع',
            route: '/sprint44-operations',
            icon: Icons.precision_manufacturing),
        _Item(
            title: 'ما الجديد (Hub)',
            route: '/whats-new',
            icon: Icons.rocket_launch),
      ],
    ),
    _Section(
      title: 'الامتثال السعودي/الإماراتي',
      subtitle: 'ZATCA · VAT · Zakat · GOSI · WPS · Peppol',
      icon: Icons.shield_outlined,
      accent: const Color(0xFF2E75B6),
      items: const [
        _Item(
            title: 'ZATCA e-Invoice',
            route: '/compliance/zatca-invoice',
            icon: Icons.qr_code_2),
        _Item(
            title: 'VAT Return',
            route: '/compliance/vat-return',
            icon: Icons.description_outlined),
        _Item(
            title: 'Zakat',
            route: '/compliance/zakat',
            icon: Icons.calculate_outlined),
        _Item(
            title: 'قيود اليومية',
            route: '/compliance/journal-entries',
            icon: Icons.receipt_long_outlined),
        _Item(
            title: 'Audit Trail',
            route: '/compliance/audit-trail',
            icon: Icons.fact_check_outlined),
        _Item(
            title: 'الرواتب',
            route: '/compliance/payroll',
            icon: Icons.badge_outlined),
        _Item(
            title: 'ضريبة الشركات UAE',
            route: '/uae-corp-tax',
            icon: Icons.account_balance),
        _Item(
            title: 'WhatsApp Business',
            route: '/whatsapp-demo',
            icon: Icons.chat),
      ],
    ),
    _Section(
      title: 'القوائم المالية + التحليل',
      subtitle: 'Ratios · Cashflow · Consolidation · IFRS',
      icon: Icons.insert_chart_outlined,
      accent: const Color(0xFF27AE60),
      items: const [
        _Item(
            title: 'القوائم المالية',
            route: '/compliance/financial-statements',
            icon: Icons.insert_chart),
        _Item(
            title: 'النسب المالية',
            route: '/compliance/ratios',
            icon: Icons.bar_chart),
        _Item(
            title: 'Cashflow',
            route: '/compliance/cashflow-statement',
            icon: Icons.waves),
        _Item(
            title: 'الأصول الثابتة',
            route: '/compliance/fixed-assets',
            icon: Icons.business),
        _Item(
            title: 'الإهلاك',
            route: '/compliance/depreciation',
            icon: Icons.trending_down),
        _Item(
            title: 'Lease IFRS 16',
            route: '/compliance/lease',
            icon: Icons.warehouse),
        _Item(
            title: 'التقييم',
            route: '/compliance/valuation',
            icon: Icons.price_change),
        _Item(
            title: 'التوحيد',
            route: '/compliance/consolidation',
            icon: Icons.hub_outlined),
      ],
    ),
    _Section(
      title: 'التقنيات الجديدة (Demos)',
      subtitle: 'AI · OCR · Bank Feeds · GOSI · EOSB · WhatsApp',
      icon: Icons.psychology_outlined,
      accent: const Color(0xFF9B59B6),
      items: const [
        _Item(
            title: 'Payments Playground',
            route: '/payments-playground',
            icon: Icons.payments),
        _Item(
            title: 'AP Pipeline',
            route: '/ap-pipeline-demo',
            icon: Icons.account_tree_outlined),
        _Item(
            title: 'Bank OCR',
            route: '/bank-ocr-demo',
            icon: Icons.document_scanner),
        _Item(
            title: 'GOSI',
            route: '/hr/gosi',
            icon: Icons.shield_outlined),
        _Item(
            title: 'EOSB',
            route: '/hr/eosb',
            icon: Icons.flight_takeoff),
        _Item(
            title: 'Onboarding Wizard',
            route: '/onboarding',
            icon: Icons.rocket_launch_outlined),
        _Item(
            title: 'حزم الصناعات',
            route: '/industry-packs',
            icon: Icons.factory),
        _Item(
            title: 'Startup Metrics',
            route: '/startup-metrics',
            icon: Icons.trending_up),
      ],
    ),
    _Section(
      title: 'التصميم + المكوّنات',
      subtitle: 'Showcase + Apex Layer components',
      icon: Icons.palette_outlined,
      accent: const Color(0xFFE67E22),
      items: const [
        _Item(
            title: 'معرض المكوّنات',
            route: '/showcase',
            icon: Icons.view_module_outlined),
      ],
    ),
  ];
}

class _Section {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<_Item> items;
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.items,
  });
}

class _Item {
  final String title;
  final String route;
  final IconData icon;
  const _Item(
      {required this.title, required this.route, required this.icon});
}
