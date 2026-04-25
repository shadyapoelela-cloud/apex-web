/// APEX — Service Hub (one shell for all 11 services)
/// Takes a service ID and renders that service's tile grid.
///
/// Routes:
///   /sales       → SalesHub
///   /purchase    → PurchaseHub
///   /accounting  → AccountingHub
///   /operations  → OperationsHub
///   /compliance-hub  → ComplianceHub
///   /audit-hub   → AuditHub
///   /analytics   → AnalyticsHub
///   /hr-hub      → HRHub
///   /workflow-hub → WorkflowHub
///   /settings-hub → SettingsHub
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class _Tile {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final bool featured;
  const _Tile(this.title, this.subtitle, this.route, this.icon, {this.featured = false});
}

class _ServiceConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final int color;
  final List<_Tile> tiles;
  final String? heroRoute;
  final String? heroLabel;
  final String? heroIcon;
  const _ServiceConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tiles,
    this.heroRoute,
    this.heroLabel,
    this.heroIcon,
  });
}

class ApexServiceHubScreen extends StatelessWidget {
  final String serviceId;
  const ApexServiceHubScreen({super.key, required this.serviceId});

  static final Map<String, _ServiceConfig> _services = {
    'sales': _ServiceConfig(
      title: 'المبيعات',
      subtitle: 'العملاء · الفواتير · الذمم · المتكررة',
      icon: Icons.receipt_long,
      color: 0xFF4CAF50,
      heroRoute: '/operations/live-sales-cycle',
      heroLabel: 'افتح دورة المبيعات الكاملة',
      tiles: [
        _Tile('العملاء', 'قائمة + Customer 360', '/sales/customers', Icons.people, featured: true),
        _Tile('الفواتير', '5 filters + WhatsApp', '/sales/invoices', Icons.receipt, featured: true),
        _Tile('عروض الأسعار', 'Pipeline + Win %', '/sales/quotes', Icons.description),
        _Tile('فواتير متكررة', 'MRR + ARR tracking', '/sales/recurring', Icons.repeat),
        _Tile('الإشعارات الدائنة/المدينة', 'Credit/Debit notes', '/sales/memos', Icons.note),
        _Tile('أعمار AR', '5 buckets ملوّنة', '/sales/aging', Icons.timeline, featured: true),
        _Tile('بيع سريع POS', 'Mada/STC/Apple', '/pos/quick-sale', Icons.point_of_sale),
      ],
    ),
    'purchase': _ServiceConfig(
      title: 'المشتريات',
      subtitle: 'الموردون · فواتير · أعمار · مدفوعات',
      icon: Icons.local_shipping,
      color: 0xFF2196F3,
      heroRoute: '/operations/purchase-cycle',
      heroLabel: 'افتح دورة الشراء الكاملة',
      tiles: [
        _Tile('الموردون', 'قائمة + Vendor 360', '/purchase/vendors', Icons.business, featured: true),
        _Tile('فواتير الموردين', 'Bills List + filters', '/purchase/bills', Icons.receipt_outlined, featured: true),
        _Tile('أعمار AP', 'AP Aging buckets', '/purchase/aging', Icons.timeline, featured: true),
      ],
    ),
    'accounting': _ServiceConfig(
      title: 'المحاسبة',
      subtitle: 'القيود · شجرة الحسابات · ميزان المراجعة',
      icon: Icons.account_balance,
      color: 0xFF9C27B0,
      heroRoute: '/compliance/financial-statements',
      heroLabel: 'افتح ميزان المراجعة (Live)',
      tiles: [
        _Tile('قائمة القيود', 'JE List canonical', '/accounting/je-list', Icons.book, featured: true),
        _Tile('شجرة الحسابات', 'CoA Tree (SOCPA)', '/accounting/coa-v2', Icons.account_tree, featured: true),
        _Tile('محرر الحسابات', 'CoA Editor', '/accounting/coa/edit', Icons.edit_note),
        _Tile('ميزان المراجعة', 'TB + drill chain', '/compliance/financial-statements', Icons.assessment, featured: true),
        _Tile('التسوية البنكية AI', 'Auto-match >95%', '/accounting/bank-rec-v2', Icons.account_balance_wallet),
        _Tile('إقفال الفترة', 'NetSuite checklist', '/operations/period-close', Icons.lock_clock),
      ],
    ),
    'operations': _ServiceConfig(
      title: 'العمليات',
      subtitle: 'POS · إيصالات · مخزون · أصول · عهدة',
      icon: Icons.precision_manufacturing,
      color: 0xFFFF5722,
      tiles: [
        _Tile('بيع سريع POS', 'Mada/STC/Apple Pay', '/pos/quick-sale', Icons.point_of_sale, featured: true),
        _Tile('التقاط إيصال', 'OCR scaffold', '/receipt/capture', Icons.receipt, featured: true),
        _Tile('المخزون', 'FIFO/LIFO/WAC', '/operations/inventory-v2', Icons.inventory_2, featured: true),
        _Tile('بطاقة الصنف', 'Stock card timeline', '/operations/stock-card', Icons.timeline),
        _Tile('الأصول الثابتة', 'IAS 16 register', '/operations/fixed-assets-v2', Icons.business),
        _Tile('العهدة النقدية', 'Petty Cash + low-balance', '/operations/petty-cash', Icons.savings),
      ],
    ),
    'compliance-hub': _ServiceConfig(
      title: 'الامتثال',
      subtitle: 'ZATCA · VAT · زكاة · IFRS · KYC · مخاطر',
      icon: Icons.gavel,
      color: 0xFFE91E63,
      heroRoute: '/compliance/tax-calendar',
      heroLabel: 'افتح التقويم الضريبي السعودي',
      tiles: [
        _Tile('التقويم الضريبي', '7 obligations', '/compliance/tax-calendar', Icons.event, featured: true),
        _Tile('ZATCA Status Center', 'CSID + Queue + Errors', '/compliance/zatca-status', Icons.verified, featured: true),
        _Tile('VAT Return', 'إقرار شهري', '/compliance/vat-return', Icons.receipt_long),
        _Tile('الزكاة', 'الوعاء الزكوي 2.5%', '/compliance/zakat', Icons.account_balance_wallet),
        _Tile('استقطاع المصدر WHT', '5/15/20%', '/compliance/wht-v2', Icons.percent),
        _Tile('IFRS 16 — الإيجارات', 'ROU + جدول إهلاك', '/compliance/lease-v2', Icons.apartment),
        _Tile('IFRS 10 — التوحيد', 'Multi-entity', '/compliance/consolidation-v2', Icons.layers),
        _Tile('KYC/AML', 'Sanctions + PEP', '/compliance/kyc-aml', Icons.fact_check, featured: true),
        _Tile('سجل المخاطر', 'Heatmap matrix', '/compliance/risk-register', Icons.shield),
        _Tile('سجل النشاط', 'Hash-Chain timeline', '/compliance/activity-log-v2', Icons.history),
      ],
    ),
    'audit-hub': _ServiceConfig(
      title: 'المراجعة الداخلية',
      subtitle: 'Workpapers · Benford · Sampling · Sign-off',
      icon: Icons.verified_user,
      color: 0xFF607D8B,
      heroRoute: '/audit/engagements',
      heroLabel: 'افتح Engagement Workspace',
      tiles: [
        _Tile('Engagement Workspace', '5 tabs + Evidence Chain', '/audit/engagements', Icons.folder, featured: true),
        _Tile('Benford Analysis', 'تحليل الرقم الأول', '/audit/benford', Icons.bar_chart, featured: true),
        _Tile('JE Sampling', 'عينة deterministic', '/audit/sampling', Icons.shuffle),
        _Tile('Workpapers', 'PBC list + sign-off', '/audit/workpapers', Icons.description),
      ],
    ),
    'analytics': _ServiceConfig(
      title: 'التحليلات',
      subtitle: 'تدفقات · موازنات · صحة · عملات · ربحية',
      icon: Icons.analytics,
      color: 0xFF00BCD4,
      tiles: [
        _Tile('توقع التدفق النقدي', '90 يوم + شهور التشغيل', '/analytics/cash-flow-forecast', Icons.show_chart, featured: true),
        _Tile('Health Score', 'Radial gauge — 6 أبعاد', '/analytics/health-score-v2', Icons.health_and_safety, featured: true),
        _Tile('بناء الموازنة', '12 شهر + AI', '/analytics/budget-builder', Icons.calculate),
        _Tile('انحراف الموازنة', 'IBCS variance bars', '/analytics/budget-variance-v2', Icons.trending_up),
        _Tile('متابعة العملات', 'FX exposure', '/analytics/multi-currency-v2', Icons.currency_exchange),
        _Tile('المحفظة الاستثمارية', 'Donut chart', '/analytics/investment-portfolio-v2', Icons.savings),
        _Tile('ربحية المشاريع', 'P&L per project', '/analytics/project-profitability', Icons.engineering),
        _Tile('انحراف التكاليف', 'Material/Labour/OH', '/analytics/cost-variance-v2', Icons.precision_manufacturing),
      ],
    ),
    'hr-hub': _ServiceConfig(
      title: 'الموارد البشرية',
      subtitle: 'الموظفون · الرواتب · GOSI · سعودة',
      icon: Icons.people,
      color: 0xFF8BC34A,
      heroRoute: '/hr/employees',
      heroLabel: 'افتح قائمة الموظفين + Saudization',
      tiles: [
        _Tile('الموظفون', 'مع Saudization tier', '/hr/employees', Icons.badge, featured: true),
        _Tile('تشغيل الرواتب', 'GOSI + Saudization', '/hr/payroll-run', Icons.payments, featured: true),
        _Tile('سجل ساعات العمل', 'Weekly timesheet', '/hr/timesheet', Icons.access_time),
        _Tile('تقارير المصاريف', 'Expense workflow', '/hr/expense-reports', Icons.receipt_long),
      ],
    ),
    'workflow-hub': _ServiceConfig(
      title: 'سير العمل والمعرفة',
      subtitle: 'الموافقات · AI · المعرفة · Copilot',
      icon: Icons.account_tree,
      color: 0xFF673AB7,
      tiles: [
        _Tile('صندوق الموافقات', 'Multi-step queue', '/workflow/approvals', Icons.inbox, featured: true),
        _Tile('اقتراحات AI', 'Confidence-Gated', '/admin/ai-suggestions-v2', Icons.lightbulb_outline, featured: true),
        _Tile('قاعدة المعرفة', 'بحث في الأدلة', '/knowledge/search', Icons.menu_book),
        _Tile('Copilot', 'Ask APEX بالعربي', '/copilot', Icons.smart_toy, featured: true),
      ],
    ),
    'settings-hub': _ServiceConfig(
      title: 'الإعدادات',
      subtitle: 'الحساب · الكيان · التكاملات · البنوك',
      icon: Icons.settings,
      color: 0xFF795548,
      tiles: [
        _Tile('الإعدادات الموحّدة', '5 sections', '/settings/unified', Icons.tune, featured: true),
        _Tile('ربط البنوك', '11 بنك سعودي', '/settings/bank-feeds', Icons.account_balance, featured: true),
        _Tile('إعداد الكيان', 'Onboarding wizard', '/onboarding', Icons.business_center),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final config = _services[serviceId];
    if (config == null) {
      return Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Text('خدمة غير معروفة', style: TextStyle(color: AC.gold)),
        ),
        body: Center(child: Text('Service "$serviceId" not found',
            style: TextStyle(color: AC.err))),
      );
    }
    final color = Color(config.color);
    final featured = config.tiles.where((t) => t.featured).toList();
    final others = config.tiles.where((t) => !t.featured).toList();
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text(config.title, style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.apps, color: AC.gold),
            tooltip: 'Launchpad',
            onPressed: () => context.go('/launchpad'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _heroCard(context, config, color),
          if (featured.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('الأكثر استخداماً',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _tilesGrid(context, featured, color),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('الأدوات الإضافية',
                style: TextStyle(color: AC.ts, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _tilesGrid(context, others, color),
          ],
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context, _ServiceConfig config, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(config.title,
                  style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(config.subtitle,
                  style: TextStyle(color: AC.ts, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${config.tiles.length}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ),
        ]),
        if (config.heroRoute != null) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.go(config.heroRoute!),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(config.heroLabel ?? 'افتح'),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
          ),
        ],
      ]),
    );
  }

  Widget _tilesGrid(BuildContext context, List<_Tile> tiles, Color color) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: tiles.map((t) => _tileCard(context, t, color)).toList(),
    );
  }

  Widget _tileCard(BuildContext context, _Tile tile, Color color) {
    return InkWell(
      onTap: () => context.go(tile.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(
              color: tile.featured ? color.withValues(alpha: 0.5) : AC.bdr,
              width: tile.featured ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(tile.icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tile.title,
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(tile.subtitle,
                    style: TextStyle(color: AC.ts, fontSize: 10.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: AC.ts, size: 14),
        ]),
      ),
    );
  }
}
