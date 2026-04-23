/// APEX Wave 94 — API & Integrations Hub.
/// Route: /app/erp/finance/integrations
///
/// Connected services, API keys, webhooks, observability.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class IntegrationsHubScreen extends StatefulWidget {
  const IntegrationsHubScreen({super.key});
  @override
  State<IntegrationsHubScreen> createState() => _IntegrationsHubScreenState();
}

class _IntegrationsHubScreenState extends State<IntegrationsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _integrations = [
    _Integration('ZATCA E-Invoicing API', 'compliance', 'active', 99.98, 'Real-time', '2024-03-15', Color(0xFF0A5F38)),
    _Integration('SAMA Open Banking', 'banking', 'active', 99.95, 'Hourly', '2024-06-01', core_theme.AC.info),
    _Integration('GOSI (التأمينات)', 'government', 'active', 99.90, 'Daily', '2023-11-10', core_theme.AC.info),
    _Integration('WPS (نظام حماية الأجور)', 'banking', 'active', 99.85, 'Monthly', '2023-08-20', core_theme.AC.warn),
    _Integration('Anthropic Claude API', 'ai', 'active', 99.99, 'On-demand', '2024-09-01', core_theme.AC.purple),
    _Integration('Stripe Payments', 'payments', 'active', 99.92, 'Real-time', '2024-11-05', core_theme.AC.err),
    _Integration('SendGrid Email', 'comms', 'active', 99.87, 'Real-time', '2024-02-14', core_theme.AC.ok),
    _Integration('Twilio SMS/OTP', 'comms', 'active', 99.88, 'Real-time', '2024-04-22', core_theme.AC.err),
    _Integration('Slack Notifications', 'comms', 'active', 100.0, 'Real-time', '2025-01-10', core_theme.AC.purple),
    _Integration('Microsoft Teams', 'comms', 'degraded', 98.12, 'Real-time', '2025-03-05', core_theme.AC.info),
    _Integration('Salesforce CRM', 'crm', 'active', 99.80, '15 min', '2024-07-18', core_theme.AC.info),
    _Integration('HubSpot Marketing', 'crm', 'paused', 0, 'Disabled', '2024-05-03', core_theme.AC.warn),
    _Integration('AWS S3 — Documents', 'storage', 'active', 99.99, 'Real-time', '2023-09-14', Color(0xFFFF9900)),
    _Integration('DocuSign eSignature', 'docs', 'active', 99.96, 'Real-time', '2024-08-22', core_theme.AC.warn),
  ];

  final _apiKeys = const [
    _ApiKey('PROD-abcd***f7e2', 'Production Main', '2024-01-15', 'admin@apex.sa', '2026-01-15', true, 2_400_000),
    _ApiKey('PROD-9e4d***1a8c', 'Production — Webhook', '2024-06-20', 'integrations@apex.sa', '2026-06-20', true, 850_000),
    _ApiKey('STAGE-f3a2***9d7e', 'Staging Environment', '2025-01-10', 'dev@apex.sa', 'لا ينتهي', true, 45_000),
    _ApiKey('DEV-x1b8***4f3e', 'Dev — Sarah\'s machine', '2025-09-22', 'sarah@apex.sa', '2026-09-22', true, 2_400),
    _ApiKey('PROD-OLD***REV', 'Legacy (Revoked)', '2023-06-01', 'old@apex.sa', 'ملغى', false, 0),
  ];

  final _webhooks = const [
    _Webhook('invoice.created', 'https://api.partner.com/webhooks/invoice', 'active', 12_450, 99.8),
    _Webhook('payment.received', 'https://api.partner.com/webhooks/payment', 'active', 8_230, 99.9),
    _Webhook('customer.updated', 'https://crm.partner.com/sync', 'active', 4_180, 99.5),
    _Webhook('user.created', 'https://idp.partner.com/hooks/user', 'active', 892, 100.0),
    _Webhook('alert.triggered', 'https://slack.com/hooks/apex-alerts', 'active', 3_240, 99.98),
    _Webhook('subscription.renewed', 'https://billing.external.com/hook', 'failing', 340, 78.4),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.api, size: 16), text: 'التكاملات'),
            Tab(icon: Icon(Icons.vpn_key, size: 16), text: 'مفاتيح API'),
            Tab(icon: Icon(Icons.webhook, size: 16), text: 'Webhooks'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildIntegrationsTab(),
              _buildApiKeysTab(),
              _buildWebhooksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.hub, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مركز التكاملات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('API Hub · 14 تكامل نشط · 6 webhooks · مفاتيح آمنة · مراقبة وقت التشغيل',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final active = _integrations.where((i) => i.status == 'active').length;
    final degraded = _integrations.where((i) => i.status == 'degraded').length;
    final avgUptime = _integrations.where((i) => i.status != 'paused').fold(0.0, (s, i) => s + i.uptime) / (active + degraded);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('إجمالي التكاملات', '${_integrations.length}', core_theme.AC.info, Icons.hub),
          _kpi('نشطة', '$active', core_theme.AC.ok, Icons.check_circle),
          _kpi('مُخفَّضة الأداء', '$degraded', core_theme.AC.warn, Icons.warning),
          _kpi('متوسط الـ Uptime', '${avgUptime.toStringAsFixed(2)}%', core_theme.AC.gold, Icons.trending_up),
          _kpi('طلبات API/شهر', '3.3M', core_theme.AC.purple, Icons.analytics),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final i in _integrations) _integrationCard(i),
          ],
        ),
      ],
    );
  }

  Widget _integrationCard(_Integration i) {
    final statusColor = _statusColor(i.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: i.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(_categoryIcon(i.category), color: i.color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(_statusLabel(i.status),
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(i.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.trending_up, size: 12, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text('Uptime: ${i.uptime}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: i.uptime >= 99.9 ? core_theme.AC.ok : i.uptime >= 99 ? core_theme.AC.warn : core_theme.AC.err)),
            ],
          ),
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text('تزامن: ${i.syncFrequency}',
                  style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ],
          ),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 11, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text('منذ ${i.connectedSince}',
                  style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeysTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.err,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.err),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: core_theme.AC.err),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ مفاتيح API سرّية — يتم عرضها بشكل مقنّع (***). لا تشارك المفاتيح في البريد أو Slack.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: Text('مفتاح جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: core_theme.AC.gold,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('المفتاح', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('أُنشئ في', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('المالك', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('ينتهي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الطلبات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final k in _apiKeys) _apiKeyRow(k),
            ],
          ),
        ),
      ],
    );
  }

  Widget _apiKeyRow(_ApiKey k) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
        color: k.active ? null : core_theme.AC.err,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.vpn_key, size: 14, color: core_theme.AC.gold),
                const SizedBox(width: 6),
                Text(k.key, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(k.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(child: Text(k.createdAt, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'))),
          Expanded(flex: 2, child: Text(k.owner, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
          Expanded(child: Text(k.expiresAt, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'))),
          Expanded(
            child: Text(_fmt(k.requests.toDouble()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (k.active ? core_theme.AC.ok : core_theme.AC.err).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(k.active ? 'نشط' : 'ملغى',
                  style: TextStyle(fontSize: 10, color: k.active ? core_theme.AC.ok : core_theme.AC.err, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebhooksTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final w in _webhooks) _webhookCard(w),
      ],
    );
  }

  Widget _webhookCard(_Webhook w) {
    final isActive = w.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (isActive ? core_theme.AC.ok : core_theme.AC.err).withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isActive ? core_theme.AC.ok : core_theme.AC.err).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.webhook, color: isActive ? core_theme.AC.ok : core_theme.AC.err),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.event, style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
                const SizedBox(height: 2),
                Text(w.url,
                    style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(w.deliveriesToday.toDouble()),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Text('طلبات اليوم', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${w.successRate}%',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: w.successRate >= 99 ? core_theme.AC.ok : w.successRate >= 90 ? core_theme.AC.warn : core_theme.AC.err)),
              Text('معدل النجاح', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? core_theme.AC.ok : core_theme.AC.err).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isActive ? 'نشط' : 'فاشل',
                style: TextStyle(
                    fontSize: 11,
                    color: isActive ? core_theme.AC.ok : core_theme.AC.err,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return core_theme.AC.ok;
      case 'degraded':
        return core_theme.AC.warn;
      case 'paused':
        return core_theme.AC.td;
      case 'failing':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'نشط';
      case 'degraded':
        return 'مخفض';
      case 'paused':
        return 'متوقف';
      case 'failing':
        return 'فاشل';
      default:
        return s;
    }
  }

  IconData _categoryIcon(String c) {
    switch (c) {
      case 'compliance':
        return Icons.gavel;
      case 'banking':
        return Icons.account_balance;
      case 'government':
        return Icons.flag;
      case 'ai':
        return Icons.auto_awesome;
      case 'payments':
        return Icons.payments;
      case 'comms':
        return Icons.chat;
      case 'crm':
        return Icons.people;
      case 'storage':
        return Icons.cloud;
      case 'docs':
        return Icons.description;
      default:
        return Icons.extension;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Integration {
  final String name;
  final String category;
  final String status;
  final double uptime;
  final String syncFrequency;
  final String connectedSince;
  final Color color;
  const _Integration(this.name, this.category, this.status, this.uptime, this.syncFrequency, this.connectedSince, this.color);
}

class _ApiKey {
  final String key;
  final String name;
  final String createdAt;
  final String owner;
  final String expiresAt;
  final bool active;
  final int requests;
  const _ApiKey(this.key, this.name, this.createdAt, this.owner, this.expiresAt, this.active, this.requests);
}

class _Webhook {
  final String event;
  final String url;
  final String status;
  final int deliveriesToday;
  final double successRate;
  const _Webhook(this.event, this.url, this.status, this.deliveriesToday, this.successRate);
}
