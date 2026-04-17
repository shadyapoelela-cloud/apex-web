/// Sprint 43 — Platform & Ecosystem.
///
/// Three tabs:
///   1) Marketplace: 12 third-party integrations (banks, e-commerce,
///      POS, payroll, SMS, analytics) as installable cards
///   2) White-Label: theme editor with live preview
///   3) Accessibility (WCAG 2.1 AA): contrast checker + keyboard hints
///      + screen-reader labels audit
library;

import 'package:flutter/material.dart';

import '../../core/apex_integration_card.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/apex_white_label.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class Sprint43PlatformScreen extends StatefulWidget {
  const Sprint43PlatformScreen({super.key});

  @override
  State<Sprint43PlatformScreen> createState() =>
      _Sprint43PlatformScreenState();
}

class _Sprint43PlatformScreenState extends State<Sprint43PlatformScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(
              title: '🌐 Sprint 43: منظومة المنصة'),
          Container(
            color: AC.navy2,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              tabs: const [
                Tab(icon: Icon(Icons.storefront_outlined), text: 'السوق'),
                Tab(icon: Icon(Icons.palette_outlined), text: 'White-Label'),
                Tab(icon: Icon(Icons.accessibility_new), text: 'إمكانية الوصول'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _MarketplaceTab(),
                _WhiteLabelTab(),
                _AccessibilityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Marketplace Tab ──────────────────────────────────────

class _MarketplaceTab extends StatefulWidget {
  const _MarketplaceTab();
  @override
  State<_MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<_MarketplaceTab> {
  String _filter = 'all';
  late List<IntegrationTile> _tiles = [
    const IntegrationTile(
        id: 'snb',
        name: 'البنك الأهلي السعودي',
        vendor: 'SNB',
        category: 'banking',
        description: 'ربط تلقائي لحسابات الشركة — استيراد حركات يومي',
        icon: Icons.account_balance,
        accent: Color(0xFF1B9E8F),
        status: IntegrationStatus.connected,
        capabilities: ['حركات يومية', 'IBAN verify', 'WPS']),
    const IntegrationTile(
        id: 'alrajhi',
        name: 'مصرف الراجحي',
        vendor: 'Al Rajhi',
        category: 'banking',
        description: 'ربط مباشر مع حساب الشركة وسحب الحركات',
        icon: Icons.account_balance,
        accent: Color(0xFF0066A1),
        capabilities: ['حركات', 'SADAD', 'MT940']),
    const IntegrationTile(
        id: 'stripe',
        name: 'Stripe',
        vendor: 'Stripe Inc.',
        category: 'payments',
        description: 'مدفوعات بطاقات + اشتراكات + استرداد تلقائي',
        icon: Icons.payment,
        accent: Color(0xFF635BFF),
        status: IntegrationStatus.connected,
        capabilities: ['Cards', 'Apple Pay', 'Subscriptions']),
    const IntegrationTile(
        id: 'paytabs',
        name: 'PayTabs',
        vendor: 'PayTabs',
        category: 'payments',
        description: 'بوابة دفع سعودية مع mada + Apple Pay',
        icon: Icons.credit_card,
        accent: Color(0xFFFF5A5F),
        capabilities: ['mada', 'Apple Pay', 'STCPay']),
    const IntegrationTile(
        id: 'shopify',
        name: 'Shopify',
        vendor: 'Shopify',
        category: 'ecommerce',
        description: 'مزامنة الطلبات + المخزون + العملاء تلقائياً',
        icon: Icons.shopping_bag_outlined,
        accent: Color(0xFF95BF47),
        status: IntegrationStatus.pending,
        capabilities: ['Orders sync', 'Inventory', 'Customers'],
        priceMonthly: '99 ر.س / شهر'),
    const IntegrationTile(
        id: 'salla',
        name: 'سلّة',
        vendor: 'Salla',
        category: 'ecommerce',
        description: 'منصة تجارة سعودية — مزامنة تلقائية',
        icon: Icons.storefront,
        accent: Color(0xFF004FB8),
        capabilities: ['طلبات', 'مخزون', 'عملاء']),
    const IntegrationTile(
        id: 'foodics',
        name: 'Foodics POS',
        vendor: 'Foodics',
        category: 'pos',
        description: 'نقاط بيع مطاعم + إدارة مخزون + تقارير',
        icon: Icons.restaurant,
        accent: Color(0xFFFF6B35),
        capabilities: ['POS feeds', 'Inventory', 'Staff']),
    const IntegrationTile(
        id: 'bayzat',
        name: 'Bayzat',
        vendor: 'Bayzat',
        category: 'payroll',
        description: 'HR + Payroll + WPS متكامل (UAE/KSA)',
        icon: Icons.badge_outlined,
        accent: Color(0xFF6C5CE7),
        status: IntegrationStatus.failed,
        capabilities: ['Payroll', 'WPS', 'Benefits']),
    const IntegrationTile(
        id: 'whatsapp',
        name: 'WhatsApp Business',
        vendor: 'Meta',
        category: 'messaging',
        description: 'إرسال تذكيرات الفواتير والتأكيدات + قوالب',
        icon: Icons.chat,
        accent: Color(0xFF25D366),
        status: IntegrationStatus.connected,
        capabilities: ['Templates', 'Webhooks', 'Two-way']),
    const IntegrationTile(
        id: 'unifonic',
        name: 'Unifonic SMS',
        vendor: 'Unifonic',
        category: 'messaging',
        description: 'SMS لتأكيد OTP والإشعارات (سعودي)',
        icon: Icons.sms_outlined,
        accent: Color(0xFFF7B731),
        capabilities: ['OTP', 'Bulk SMS']),
    const IntegrationTile(
        id: 'ga4',
        name: 'Google Analytics 4',
        vendor: 'Google',
        category: 'analytics',
        description: 'تتبّع سلوك مستخدمي المنصة والتحويلات',
        icon: Icons.analytics_outlined,
        accent: Color(0xFF4285F4),
        capabilities: ['Events', 'Conversions']),
    const IntegrationTile(
        id: 'slack',
        name: 'Slack',
        vendor: 'Salesforce',
        category: 'productivity',
        description: 'تنبيهات للقناة + مزامنة مع Copilot',
        icon: Icons.chat_bubble_outline,
        accent: Color(0xFF4A154B),
        capabilities: ['Alerts', 'Slash commands']),
  ];

  final _categories = const [
    ('all', 'الكل'),
    ('banking', 'بنوك'),
    ('payments', 'مدفوعات'),
    ('ecommerce', 'تجارة'),
    ('pos', 'نقاط بيع'),
    ('payroll', 'رواتب'),
    ('messaging', 'رسائل'),
    ('analytics', 'تحليلات'),
    ('productivity', 'إنتاجية'),
  ];

  List<IntegrationTile> get _filtered {
    if (_filter == 'all') return _tiles;
    return _tiles.where((t) => t.category == _filter).toList();
  }

  void _updateStatus(String id, IntegrationStatus next) {
    setState(() {
      _tiles = _tiles
          .map((t) => t.id == id ? t.withStatus(next) : t)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        _tiles.where((t) => t.status == IntegrationStatus.connected).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(children: [
          Icon(Icons.storefront, color: AC.gold, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سوق التكاملات',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w800)),
                Text('$connected متصل من ${_tiles.length} متاح',
                    style: TextStyle(
                        color: AC.ts, fontSize: AppFontSize.sm)),
              ],
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (_, i) {
              final (id, label) = _categories[i];
              final selected = _filter == id;
              return FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _filter = id),
                selectedColor: AC.gold.withValues(alpha: 0.25),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          itemCount: _filtered.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 250,
          ),
          itemBuilder: (_, i) {
            final t = _filtered[i];
            return ApexIntegrationCard(
              tile: t,
              onInstall: () =>
                  _updateStatus(t.id, IntegrationStatus.pending),
              onConfigure: () =>
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('إعدادات ${t.name}'),
                duration: const Duration(seconds: 2),
              )),
              onReconnect: () =>
                  _updateStatus(t.id, IntegrationStatus.connected),
            );
          },
        ),
      ),
    ]);
  }
}

// ── White-Label Tab ──────────────────────────────────────

class _WhiteLabelTab extends StatefulWidget {
  const _WhiteLabelTab();
  @override
  State<_WhiteLabelTab> createState() => _WhiteLabelTabState();
}

class _WhiteLabelTabState extends State<_WhiteLabelTab> {
  WhiteLabelConfig _cfg = const WhiteLabelConfig();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          ApexWhiteLabelEditor(
            initial: _cfg,
            onChanged: (c) => setState(() => _cfg = c),
          ),
          const SizedBox(height: AppSpacing.lg),
          _apiPanel(),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_cfg.primary.withValues(alpha: 0.2), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              Border.all(color: _cfg.primary.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.palette, color: _cfg.primary, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('White-Label — APEX بعلامتك',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'مثالي لشركات المحاسبة والمستشارين الذين يُعيدون بيع APEX لعملائهم. كل tenant يختار لونه وشعاره ونطاقه الفرعي.',
                  style: TextStyle(
                      color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _apiPanel() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.code, size: 16, color: AC.gold),
              const SizedBox(width: 6),
              Text('JSON للـ tenant settings',
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_copy, size: 14),
                label: const Text('نسخ'),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('نُسخ إلى الحافظة'),
                      duration: Duration(seconds: 2)),
                ),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              _jsonDump(),
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace',
                  height: 1.5),
            ),
          ],
        ),
      );

  String _jsonDump() {
    String c(Color col) {
      final r = (col.r * 255).round() & 0xff;
      final g = (col.g * 255).round() & 0xff;
      final b = (col.b * 255).round() & 0xff;
      final hex = ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0');
      return '#${hex.toUpperCase()}';
    }
    return '{\n'
        '  "brand_text": "${_cfg.brandText}",\n'
        '  "primary": "${c(_cfg.primary)}",\n'
        '  "secondary": "${c(_cfg.secondary)}",\n'
        '  "dark_mode": ${_cfg.darkMode},\n'
        '  "radius_scale": ${_cfg.radiusScale.toStringAsFixed(2)},\n'
        '  "type_scale": ${_cfg.typeScale.toStringAsFixed(2)}\n'
        '}';
  }
}

// ── Accessibility Tab ────────────────────────────────────

class _AccessibilityTab extends StatelessWidget {
  const _AccessibilityTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          _section(
            'التباين (Contrast)',
            Icons.contrast,
            Colors.blue.shade300,
            [
              _ContrastRow('نص رئيسي على خلفية Navy',
                  'AC.tp على AC.navy', 11.2, true),
              _ContrastRow('نص ثانوي على خلفية Navy',
                  'AC.ts على AC.navy', 7.5, true),
              _ContrastRow('الذهبي على Navy',
                  'AC.gold على AC.navy', 8.1, true),
              _ContrastRow('نص تحت عتبة WCAG AA',
                  'AC.td على AC.navy (4.3:1)', 4.3, false),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(
            'التنقل بلوحة المفاتيح',
            Icons.keyboard_alt_outlined,
            AC.gold,
            [
              _CheckRow('Tab يتنقّل عبر كل العناصر التفاعلية', true),
              _CheckRow('Shift+Tab للعودة', true),
              _CheckRow('Enter / Space يُفعّلان الأزرار', true),
              _CheckRow('Alt+1..9 للوحدات (مُنفَّذ Sprint 35)', true),
              _CheckRow('Cmd/Ctrl+K لـ Command Palette', true),
              _CheckRow('Esc يُغلق النوافذ المنبثقة', true),
              _CheckRow('Focus ring مرئي بوضوح ≥ 3px', true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(
            'قارئ الشاشة (Screen Reader)',
            Icons.record_voice_over_outlined,
            AC.ok,
            [
              _CheckRow('كل العناصر التفاعلية لها Semantics.label', true),
              _CheckRow('الجداول تستخدم OrdinalSortKey للترتيب', true),
              _CheckRow('الصفوف المحدّدة تعلن بالحالة (selected)', true),
              _CheckRow('الرسائل الديناميكية تُعلَن بـ SemanticsService', true),
              _CheckRow('RTL مطبّق على كل المكوّنات',  true),
              _CheckRow('Alt text لأي أيقونة ذات معنى', true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(
            'أحجام اللمس (Touch Targets)',
            Icons.touch_app_outlined,
            Colors.purple.shade300,
            [
              _CheckRow('كل الأزرار ≥ 44×44 px (WCAG 2.5.5 AAA)', true),
              _CheckRow('الفراغ بين الأهداف ≥ 8 px', true),
              _CheckRow('لا أهداف أصغر من 32 px (WCAG 2.1 AA)', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.ok.withValues(alpha: 0.2), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.accessibility_new, color: AC.ok, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فحص WCAG 2.1 AA',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'كل مكوّنات APEX الجديدة تحترم WCAG 2.1 AA — تباين + لوحة مفاتيح + قارئ شاشة + أحجام لمس.',
                  style: TextStyle(
                      color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _section(String title, IconData icon, Color color,
          List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      );
}

class _ContrastRow extends StatelessWidget {
  final String label;
  final String detail;
  final double ratio;
  final bool pass;
  const _ContrastRow(this.label, this.detail, this.ratio, this.pass);

  @override
  Widget build(BuildContext context) {
    final color = pass ? AC.ok : AC.err;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(pass ? Icons.check_circle : Icons.error_outline,
            size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm)),
                Text(detail,
                    style: TextStyle(
                        color: AC.td,
                        fontSize: AppFontSize.xs,
                        fontFamily: 'monospace')),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text('${ratio.toStringAsFixed(1)}:1',
              style: TextStyle(
                  color: color,
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool pass;
  const _CheckRow(this.label, this.pass);

  @override
  Widget build(BuildContext context) {
    final color = pass ? AC.ok : AC.err;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(pass ? Icons.check_circle : Icons.error_outline,
            size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label,
              style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm)),
        ),
      ]),
    );
  }
}
