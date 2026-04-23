/// V5.2 — Integrations Hub (Card Grid pattern — new template).
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class IntegrationsHubV52Screen extends StatefulWidget {
  const IntegrationsHubV52Screen({super.key});

  @override
  State<IntegrationsHubV52Screen> createState() => _IntegrationsHubV52ScreenState();
}

class _IntegrationsHubV52ScreenState extends State<IntegrationsHubV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _category = 'all';
  String _search = '';

  static const _integrations = <_Int>[
    _Int('zatca', 'ZATCA E-Invoicing', 'الفوترة الإلكترونية الحكومية', '🇸🇦', 'banking', _Status.connected, 'ZATCA', '2026-04-18'),
    _Int('gosi', 'GOSI', 'التأمينات الاجتماعية', '🇸🇦', 'banking', _Status.connected, 'GOSI', '2026-04-15'),
    _Int('wps', 'WPS (مدد)', 'نظام حماية الأجور', '🇸🇦', 'banking', _Status.connected, 'WPS Madd', '2026-04-28'),
    _Int('mol', 'وزارة العمل', 'نقل الموظفين والتوطين', '🇸🇦', 'government', _Status.connected, 'MOL', '2026-04-10'),
    _Int('sama', 'SAMA Open Banking', 'البنك المركزي السعودي', '🏛️', 'banking', _Status.connected, 'SAMA', 'realtime'),
    _Int('riyad-bank', 'بنك الرياض', 'ربط الحساب + كشوفات', '🏦', 'banking', _Status.connected, 'Riyad Bank', 'realtime'),
    _Int('alrajhi', 'بنك الراجحي', 'ربط الحساب + تحويلات', '🏦', 'banking', _Status.connected, 'Al Rajhi', 'realtime'),
    _Int('ncb', 'البنك الأهلي', 'ربط الحساب + POS', '🏦', 'banking', _Status.connected, 'NCB', 'realtime'),
    _Int('hsbc', 'HSBC', 'معاملات دولية', '🏦', 'banking', _Status.error, 'HSBC', '2026-04-12'),
    _Int('stc', 'STC Pay', 'مدفوعات رقمية', '💳', 'payment', _Status.connected, 'STC Pay', 'realtime'),
    _Int('mada', 'مدى', 'شبكة المدفوعات', '💳', 'payment', _Status.connected, 'Mada', 'realtime'),
    _Int('stripe', 'Stripe', 'مدفوعات دولية', '💳', 'payment', _Status.connected, 'Stripe', 'realtime'),
    _Int('paytabs', 'PayTabs', 'بوابة دفع عربية', '💳', 'payment', _Status.available, 'PayTabs', null),
    _Int('salla', 'سلة', 'متجر إلكتروني سعودي', '🛍️', 'ecommerce', _Status.connected, 'Salla', '2026-04-17'),
    _Int('zid', 'زد', 'متجر إلكتروني', '🛍️', 'ecommerce', _Status.available, 'Zid', null),
    _Int('shopify', 'Shopify', 'منصة التجارة', '🛍️', 'ecommerce', _Status.available, 'Shopify', null),
    _Int('foodics', 'Foodics', 'نقاط بيع المطاعم', '🍽️', 'pos', _Status.connected, 'Foodics', '2026-04-18'),
    _Int('rain', 'Rain POS', 'نقاط بيع التجزئة', '🛒', 'pos', _Status.available, 'Rain', null),
    _Int('aramex', 'أرامكس', 'الشحن والتوصيل', '📦', 'logistics', _Status.connected, 'Aramex', '2026-04-16'),
    _Int('smsa', 'SMSA Express', 'الشحن السريع', '📦', 'logistics', _Status.available, 'SMSA', null),
    _Int('msoffice', 'Microsoft 365', 'البريد والتقويم', '📧', 'productivity', _Status.connected, 'Microsoft', '2026-04-19'),
    _Int('google', 'Google Workspace', 'البريد والمستندات', '📧', 'productivity', _Status.available, 'Google', null),
    _Int('slack', 'Slack', 'مراسلات الفريق', '💬', 'productivity', _Status.connected, 'Slack', '2026-04-19'),
    _Int('teams', 'MS Teams', 'اجتماعات ومراسلات', '💬', 'productivity', _Status.available, 'Microsoft', null),
    _Int('hubspot', 'HubSpot', 'CRM ومبيعات', '📊', 'crm', _Status.available, 'HubSpot', null),
    _Int('salesforce', 'Salesforce', 'CRM كلاسيكي', '☁️', 'crm', _Status.available, 'Salesforce', null),
    _Int('openai', 'OpenAI GPT-4', 'AI للنصوص', '🤖', 'ai', _Status.connected, 'OpenAI', 'realtime'),
    _Int('anthropic', 'Claude Opus', 'AI متقدّم', '🤖', 'ai', _Status.connected, 'Anthropic', 'realtime'),
    _Int('webhook-generic', 'Webhook Generic', 'أي نظام خارجي', '🔗', 'custom', _Status.connected, 'Custom', '2026-04-18'),
    _Int('api-key', 'REST API', 'تكامل مخصّص', '🔗', 'custom', _Status.connected, 'Custom', 'realtime'),
  ];

  List<_Int> get _filtered {
    return _integrations.where((i) {
      if (_category != 'all' && i.category != _category) return false;
      if (_search.isNotEmpty && !i.nameAr.contains(_search) && !i.id.contains(_search)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(children: [
          _header(),
          _statsBar(),
          _searchAndCategories(),
          const Divider(height: 1),
          Expanded(child: _grid()),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.hub, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مركز التكاملات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('اربط APEX بـ 30+ نظام — بنوك، ZATCA، GOSI، متاجر إلكترونية، AI', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.api, size: 16), label: Text('REST API Docs')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.add, size: 16), label: Text('تكامل مخصّص')),
      ]),
    );
  }

  Widget _statsBar() {
    final connected = _integrations.where((i) => i.status == _Status.connected).length;
    final errors = _integrations.where((i) => i.status == _Status.error).length;
    final available = _integrations.where((i) => i.status == _Status.available).length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        Expanded(child: _statCard('متصل', '$connected', core_theme.AC.ok, Icons.check_circle)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('خطأ', '$errors', core_theme.AC.err, Icons.error)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('متاح', '$available', core_theme.AC.info, Icons.cloud_download)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('المكالمات اليومية', '142K', _gold, Icons.sync_alt)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('وقت التشغيل', '99.97%', _navy, Icons.verified)),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ])),
      ]),
    );
  }

  Widget _searchAndCategories() {
    final cats = [
      ('all', 'الكل', Icons.apps, _navy),
      ('banking', 'البنوك والحكومة', Icons.account_balance, core_theme.AC.info),
      ('payment', 'مدفوعات', Icons.credit_card, core_theme.AC.ok),
      ('ecommerce', 'متاجر إلكترونية', Icons.shopping_bag, core_theme.AC.purple),
      ('pos', 'نقاط بيع', Icons.point_of_sale, core_theme.AC.warn),
      ('logistics', 'لوجستيات', Icons.local_shipping, core_theme.AC.info),
      ('productivity', 'إنتاجية', Icons.work, core_theme.AC.gold),
      ('crm', 'CRM', Icons.people, core_theme.AC.purple),
      ('ai', 'ذكاء اصطناعي', Icons.smart_toy, core_theme.AC.err),
      ('custom', 'مخصّص', Icons.code, core_theme.AC.td),
      ('government', 'حكومي', Icons.flag, Color(0xFF4A148C)),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 300,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'بحث في التكاملات...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: cats.map((c) {
          final selected = c.$1 == _category;
          return Padding(padding: const EdgeInsets.only(left: 8), child: InkWell(
            onTap: () => setState(() => _category = c.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: selected ? c.$4.withValues(alpha: 0.12) : core_theme.AC.navy3, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? c.$4 : core_theme.AC.bdr)),
              child: Row(children: [
                Icon(c.$3, size: 14, color: selected ? c.$4 : core_theme.AC.ts),
                const SizedBox(width: 6),
                Text(c.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? c.$4 : core_theme.AC.tp)),
              ]),
            ),
          ));
        }).toList())),
      ]),
    );
  }

  Widget _grid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off, size: 64, color: core_theme.AC.td),
        SizedBox(height: 12),
        Text('لا توجد تكاملات تطابق البحث', style: TextStyle(color: core_theme.AC.ts)),
      ])));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        childAspectRatio: 2.2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _integrationCard(items[i]),
    );
  }

  Widget _integrationCard(_Int i) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: i.status.color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: core_theme.AC.tp.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(i.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.nameAr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(i.vendor, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: i.status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [Icon(i.status.icon, size: 10, color: i.status.color), const SizedBox(width: 3), Text(i.status.labelAr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: i.status.color))]),
            ),
          ]),
          const SizedBox(height: 8),
          Text(i.description, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(children: [
            if (i.lastSync != null) ...[
              Icon(Icons.sync, size: 11, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text(i.lastSync == 'realtime' ? 'آني (Realtime)' : 'آخر مزامنة ${i.lastSync}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ],
            const Spacer(),
            if (i.status == _Status.available)
              OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), minimumSize: Size.zero), child: Text('تفعيل', style: TextStyle(fontSize: 11)))
            else if (i.status == _Status.error)
              FilledButton(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: core_theme.AC.err, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), minimumSize: Size.zero), child: Text('إصلاح', style: TextStyle(fontSize: 11)))
            else
              TextButton(onPressed: () {}, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), minimumSize: Size.zero), child: Text('إدارة', style: TextStyle(fontSize: 11))),
          ]),
        ]),
      ),
    );
  }
}

enum _Status { connected, error, available }

extension _StatusX on _Status {
  String get labelAr => switch (this) {
        _Status.connected => 'متصل',
        _Status.error => 'خطأ',
        _Status.available => 'متاح',
      };
  Color get color => switch (this) {
        _Status.connected => core_theme.AC.ok,
        _Status.error => core_theme.AC.err,
        _Status.available => core_theme.AC.info,
      };
  IconData get icon => switch (this) {
        _Status.connected => Icons.check_circle,
        _Status.error => Icons.error,
        _Status.available => Icons.cloud_download,
      };
}

class _Int {
  final String id, nameAr, description, emoji, category, vendor;
  final _Status status;
  final String? lastSync;
  const _Int(this.id, this.nameAr, this.description, this.emoji, this.category, this.status, this.vendor, this.lastSync);
}
