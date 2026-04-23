/// APEX V5.1 — Showcase Gallery.
///
/// Single-page demo hub linking to all 18 enhancements.
/// Perfect for investor pitches, customer demos, internal tours.
///
/// Route: /showcase
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import 'package:go_router/go_router.dart';

class V5ShowcaseScreen extends StatefulWidget {
  const V5ShowcaseScreen({super.key});

  @override
  State<V5ShowcaseScreen> createState() => _V5ShowcaseScreenState();
}

class _V5ShowcaseScreenState extends State<V5ShowcaseScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final items = _items.where((i) {
      if (_filter == 'all') return true;
      if (_filter == 'world_first') return i.worldFirst;
      return i.category == _filter;
    }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHero(),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildFilters(),
                const SizedBox(height: 20),
                _buildStats(),
                const SizedBox(height: 20),
                _buildGrid(items),
                const SizedBox(height: 40),
                _buildReplacementTable(),
                const SizedBox(height: 40),
                _buildFooter(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: core_theme.AC.gold,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.go('/app'),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                core_theme.AC.gold,
                core_theme.AC.purple,
                core_theme.AC.info,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(60, 80, 60, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 36),
                  SizedBox(width: 10),
                  Text(
                    'APEX V5.1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 12),
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      '— معرض التحسينات',
                      style: TextStyle(
                        color: core_theme.AC.ts,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '18 ميزة تستبدل 18 منصّة عالمية · منصّة واحدة لكل العمليات المالية',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'الكل', Icons.grid_view, _items.length),
          _filterChip('world_first', 'World First 🏆', Icons.emoji_events,
              _items.where((i) => i.worldFirst).length),
          _filterChip('accounting', 'المحاسبة', Icons.calculate,
              _items.where((i) => i.category == 'accounting').length),
          _filterChip('audit', 'المراجعة', Icons.fact_check,
              _items.where((i) => i.category == 'audit').length),
          _filterChip('tax', 'الضرائب', Icons.request_quote,
              _items.where((i) => i.category == 'tax').length),
          _filterChip('ux', 'تجربة المستخدم', Icons.star,
              _items.where((i) => i.category == 'ux').length),
          _filterChip('marketplace', 'السوق', Icons.store,
              _items.where((i) => i.category == 'marketplace').length),
          _filterChip('ai', 'الذكاء', Icons.auto_awesome,
              _items.where((i) => i.category == 'ai').length),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, IconData icon, int count) {
    final active = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? core_theme.AC.gold : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? core_theme.AC.gold : core_theme.AC.tp.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : core_theme.AC.ts),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : core_theme.AC.tp,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.25) : core_theme.AC.tp.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : core_theme.AC.ts,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            core_theme.AC.ok.withValues(alpha: 0.08),
            core_theme.AC.info.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _statBlock('18', 'تحسين جاهز', core_theme.AC.info),
          _statBlock('18', 'منصّة مُستبدَلة', core_theme.AC.purple),
          _statBlock('7', 'Wave backend مدمج', core_theme.AC.ok),
          _statBlock('70', 'chip في V5', core_theme.AC.warn),
          _statBlock('~\$400K', 'قيمة سنوية', core_theme.AC.gold),
          _statBlock('0', 'errors', core_theme.AC.ok),
        ],
      ),
    );
  }

  Widget _statBlock(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<_ShowcaseItem> items) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 800
                ? 2
                : 1;
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: cols,
          childAspectRatio: 1.2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final item in items) _ShowcaseCard(item: item),
          ],
        );
      },
    );
  }

  Widget _buildReplacementTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: core_theme.AC.purple, size: 20),
              SizedBox(width: 8),
              Text(
                'المنصّات المُستبدَلة — قيمة سنوية مُدمجة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in _items.where((i) => i.replaces != null).toList())
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(item.icon, color: item.color, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.nameAr,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.arrow_back, size: 14, color: core_theme.AC.td),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.replaces!,
                      style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                    ),
                  ),
                  Text(
                    item.value ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: core_theme.AC.ok,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [core_theme.AC.gold, Color(0xFFE6C200)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.attach_money, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الإجمالي المُستبدَل: ~\$400K/سنة — أقل بكثير من تكلفة APEX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.bolt, size: 32, color: core_theme.AC.gold),
          const SizedBox(height: 8),
          Text(
            'APEX V5.1 POC · أفضل منصّة مالية عربية في العالم',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Branch: poc/v5-1-shell · 18/20 enhancements · 0 errors',
            style: TextStyle(
              fontSize: 11,
              color: core_theme.AC.ts,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseItem {
  final int number;
  final String nameAr;
  final String nameEn;
  final String descAr;
  final IconData icon;
  final Color color;
  final String route;
  final String category;
  final bool worldFirst;
  final String? replaces;
  final String? value;

  _ShowcaseItem({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.descAr,
    required this.icon,
    required this.color,
    required this.route,
    required this.category,
    this.worldFirst = false,
    this.replaces,
    this.value,
  });
}

final _items = <_ShowcaseItem>[
  _ShowcaseItem(
    number: 1,
    nameAr: 'بيئات العمل (Workspaces)',
    nameEn: 'Workspaces',
    descAr: 'تجميع اختصارات بالدور — CFO / محاسب / مراجع / مستشار',
    icon: Icons.person_pin,
    color: core_theme.AC.gold,
    route: '/workspace/cfo',
    category: 'ux',
    replaces: 'SAP Fiori Spaces',
    value: '\$100K/yr',
  ),
  _ShowcaseItem(
    number: 3,
    nameAr: 'لوحات عمل تفاعلية',
    nameEn: 'Action Dashboards',
    descAr: '"5 فواتير متأخرة [أرسل تذكير]" بدل KPIs ساكنة',
    icon: Icons.dashboard,
    color: core_theme.AC.gold,
    route: '/app/erp/finance/dashboard',
    category: 'ux',
    replaces: 'QuickBooks + Xero',
    value: '\$60/mo',
  ),
  _ShowcaseItem(
    number: 4,
    nameAr: 'عروض متعدّدة',
    nameEn: 'Multiple Views',
    descAr: 'قائمة / Kanban / تقويم / معرض / محوري — لنفس البيانات',
    icon: Icons.view_quilt,
    color: core_theme.AC.purple,
    route: '/app/erp/finance/invoices',
    category: 'ux',
    replaces: 'Notion + Odoo',
    value: '\$10/mo',
  ),
  _ShowcaseItem(
    number: 5,
    nameAr: 'بحث وإعادة تصنيف',
    nameEn: 'Find & Recode',
    descAr: 'اختر 100 قيد — عدّلهم جماعياً بعملية واحدة',
    icon: Icons.swap_horiz,
    color: core_theme.AC.gold,
    route: '/app/erp/finance/invoices',
    category: 'accounting',
    replaces: 'Xero Find & Recode',
    value: '\$60/mo',
  ),
  _ShowcaseItem(
    number: 6,
    nameAr: 'كتابة بالذكاء',
    nameEn: 'Draft with AI',
    descAr: 'زر "✨" في كل textarea يكتب المحتوى تلقائياً',
    icon: Icons.auto_awesome,
    color: const Color(0xFFEC4899),
    route: '/app/erp/finance/dashboard',
    category: 'ai',
    replaces: 'Microsoft Copilot',
    value: '\$30/mo',
  ),
  _ShowcaseItem(
    number: 7,
    nameAr: 'تراجع في كل مكان',
    nameEn: 'Undo Everywhere',
    descAr: 'Cmd+Z عالمي + toast "تم · [تراجع]" لكل عملية',
    icon: Icons.undo,
    color: core_theme.AC.info,
    route: '/app/erp/treasury/recon',
    category: 'ux',
    replaces: 'Superhuman + Linear',
    value: '\$40/mo',
  ),
  _ShowcaseItem(
    number: 8,
    nameAr: 'رحلة الإعداد الأولي',
    nameEn: 'Onboarding Journey',
    descAr: '10 خطوات مع progress bar + شهر مجاني 🎁 عند الاكتمال',
    icon: Icons.rocket_launch,
    color: core_theme.AC.purple,
    route: '/app/erp/finance/onboarding',
    category: 'ux',
    replaces: 'QuickBooks onboarding',
    value: 'conversion',
  ),
  _ShowcaseItem(
    number: 9,
    nameAr: 'تقييم مخاطر المعاملات',
    nameEn: 'Risk Scoring',
    descAr: 'كل معاملة لها score 0-100 مع شرح تفصيلي',
    icon: Icons.shield,
    color: const Color(0xFFB91C1C),
    route: '/app/audit/fieldwork/workpapers',
    category: 'audit',
    replaces: 'MindBridge',
    value: '\$20K/yr',
  ),
  _ShowcaseItem(
    number: 10,
    nameAr: '🏆 حاسبة ضرائب الخليج الفورية',
    nameEn: 'Real-time GCC Tax',
    descAr: '6 دول · VAT + WHT + Zakat + الطوابع + البلدية · شرح عربي',
    icon: Icons.calculate,
    color: core_theme.AC.ok,
    route: '/app/compliance/tax/vat',
    category: 'tax',
    worldFirst: true,
    replaces: 'Avalara + Vertex',
    value: '\$50K/yr',
  ),
  _ShowcaseItem(
    number: 11,
    nameAr: 'APEX Studio',
    nameEn: 'APEX Studio',
    descAr: 'مصمّم بدون كود — حقول + Workflow + Approvals',
    icon: Icons.architecture,
    color: core_theme.AC.purple,
    route: '/app/erp/finance/gl',
    category: 'ux',
    replaces: 'Odoo Studio + SF LAB',
    value: '\$75K/yr',
  ),
  _ShowcaseItem(
    number: 12,
    nameAr: 'بوابة العميل',
    nameEn: 'Client Portal',
    descAr: 'عميلك يرى فواتيره + يدفع مباشرة — 70% أقل emails',
    icon: Icons.account_circle,
    color: core_theme.AC.gold,
    route: '/app/erp/finance/reports',
    category: 'accounting',
    replaces: 'Freshbooks portal',
    value: '\$25/mo',
  ),
  _ShowcaseItem(
    number: 13,
    nameAr: 'شريط التحديثات التنظيمية',
    nameEn: 'News Ticker',
    descAr: 'ZATCA + FTA + GOSI + SAMA — تحديثات حيّة في التوبار',
    icon: Icons.campaign,
    color: core_theme.AC.info,
    route: '/app/erp/finance/dashboard',
    category: 'ux',
    replaces: 'Bloomberg Terminal',
    value: '\$25K/yr',
  ),
  _ShowcaseItem(
    number: 15,
    nameAr: 'APEX Match (مطابقة ذكية)',
    nameEn: 'APEX Match AI',
    descAr: 'اكتب احتياجك — AI تختار أفضل 3 مزوّدين في 0.8 ثانية',
    icon: Icons.psychology,
    color: const Color(0xFFE65100),
    route: '/app/marketplace/client/browse',
    category: 'marketplace',
    replaces: 'Toptal matching',
    value: '20% fees',
  ),
  _ShowcaseItem(
    number: 16,
    nameAr: 'التخطيط المتّصل',
    nameEn: 'Connected Planning',
    descAr: 'غيّر driver — كل السيناريوهات تتحسب فوراً · بديل Anaplan',
    icon: Icons.tune,
    color: const Color(0xFF1565C0),
    route: '/app/erp/finance/budgets',
    category: 'accounting',
    replaces: 'Anaplan',
    value: '\$100K/yr',
  ),
  _ShowcaseItem(
    number: 17,
    nameAr: 'تحليلات المراجعة التلقائية',
    nameEn: 'Audit Analytics',
    descAr: '8 اختبارات تلقائية على TB — Benford + ازدواج + ...',
    icon: Icons.analytics,
    color: const Color(0xFF4A148C),
    route: '/app/audit/fieldwork/workpapers',
    category: 'audit',
    replaces: 'Inflo + MindBridge',
    value: '£20K/yr',
  ),
  _ShowcaseItem(
    number: 18,
    nameAr: 'اختصارات لوحة المفاتيح',
    nameEn: 'Keyboard Shortcuts',
    descAr: 'Alt+1..5 للخدمات · Ctrl+Z عالمي · Ctrl+K للبحث',
    icon: Icons.keyboard,
    color: core_theme.AC.info,
    route: '/app',
    category: 'ux',
    replaces: 'Linear + Vim',
    value: '(UX)',
  ),
  _ShowcaseItem(
    number: 20,
    nameAr: 'التقاط الإيصال بالذكاء',
    nameEn: 'Mobile Receipt',
    descAr: 'صوّر → AI تستخرج كل شيء في 3 ثواني',
    icon: Icons.camera_alt,
    color: core_theme.AC.ok,
    route: '/app/erp/finance/consolidation',
    category: 'ai',
    replaces: 'Expensify',
    value: '\$5/user/mo',
  ),
  _ShowcaseItem(
    number: 16,
    nameAr: 'Wave 16 — مطابقة بنكية ذكية',
    nameEn: 'AI Bank Reconciliation',
    descAr: 'اقتراحات مع confidence % + approve/reject + Undo',
    icon: Icons.compare_arrows,
    color: core_theme.AC.gold,
    route: '/app/erp/treasury/recon',
    category: 'ai',
    replaces: 'Xero Auto-Match',
    value: 'native',
  ),
];

class _ShowcaseCard extends StatefulWidget {
  final _ShowcaseItem item;

  const _ShowcaseCard({required this.item});

  @override
  State<_ShowcaseCard> createState() => _ShowcaseCardState();
}

class _ShowcaseCardState extends State<_ShowcaseCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(widget.item.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.item.color.withValues(alpha: _hover ? 0.4 : 0.12),
              width: _hover ? 2 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.item.color.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: core_theme.AC.tp.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.item.icon, color: widget.item.color, size: 22),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: core_theme.AC.tp.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${widget.item.number}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: core_theme.AC.ts,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (widget.item.worldFirst) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: core_theme.AC.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.emoji_events, size: 11, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            'World First',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.item.nameAr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.descAr,
                style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (widget.item.replaces != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: core_theme.AC.ok.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, size: 11, color: core_theme.AC.ok),
                      const SizedBox(width: 4),
                      Text(
                        'يستبدل ${widget.item.replaces}',
                        style: TextStyle(
                          fontSize: 10,
                          color: core_theme.AC.ok,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.item.value != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: core_theme.AC.ok,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            widget.item.value!,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    widget.item.route,
                    style: TextStyle(
                      fontSize: 10,
                      color: core_theme.AC.td,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_back,
                      size: 14,
                      color: _hover ? widget.item.color : core_theme.AC.td),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
