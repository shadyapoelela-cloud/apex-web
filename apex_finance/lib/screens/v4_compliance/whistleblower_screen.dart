/// APEX Wave 92 — Whistleblower / Ethics Hotline.
/// Route: /app/compliance/regulatory/whistleblower
///
/// Confidential reporting channel for ethics violations.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class WhistleblowerScreen extends StatefulWidget {
  const WhistleblowerScreen({super.key});
  @override
  State<WhistleblowerScreen> createState() => _WhistleblowerScreenState();
}

class _WhistleblowerScreenState extends State<WhistleblowerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _reports = const [
    _Report('WB-2026-018', 'محتوى سرّي — تلاعب محتمل بفواتير', 'fraud', 'investigating', 'anonymous', '2026-04-15', 'critical', '2026-04-16', 'فريق الامتثال'),
    _Report('WB-2026-017', 'تحرش في بيئة العمل', 'harassment', 'investigating', 'anonymous', '2026-04-10', 'high', '2026-04-11', 'لجنة التحقيق'),
    _Report('WB-2026-016', 'تعارض مصالح محتمل — مدير قسم', 'conflict', 'substantiated', 'identified', '2026-03-22', 'high', '2026-03-23', 'الموارد البشرية'),
    _Report('WB-2026-015', 'سوء استخدام موارد الشركة', 'misuse', 'closed', 'anonymous', '2026-03-15', 'medium', '2026-03-16', 'فريق التحقيق'),
    _Report('WB-2026-014', 'معاملة غير مكتملة مع ZATCA', 'compliance', 'unsubstantiated', 'identified', '2026-03-01', 'medium', '2026-03-02', 'الامتثال'),
    _Report('WB-2026-013', 'انتهاك سياسة الأمن السيبراني', 'security', 'substantiated', 'anonymous', '2026-02-18', 'high', '2026-02-19', 'الأمن السيبراني'),
    _Report('WB-2026-012', 'ضغط غير أخلاقي على مورد', 'procurement', 'investigating', 'identified', '2026-02-05', 'medium', '2026-02-06', 'المشتريات'),
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
          labelColor: const Color(0xFF4A148C),
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.inbox, size: 16), text: 'البلاغات'),
            Tab(icon: Icon(Icons.phone, size: 16), text: 'قنوات الإبلاغ'),
            Tab(icon: Icon(Icons.gavel, size: 16), text: 'السياسة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildReportsTab(),
              _buildChannelsTab(),
              _buildPolicyTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_moon, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('خط البلاغات الأخلاقية',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Whistleblower Hotline · حماية المبلّغين · تحقيق محايد · سرّي 100%',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final active = _reports.where((r) => r.status == 'investigating').length;
    final substantiated = _reports.where((r) => r.status == 'substantiated').length;
    final unsubstantiated = _reports.where((r) => r.status == 'unsubstantiated').length;
    final anonymous = _reports.where((r) => r.reporter == 'anonymous').length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('بلاغات مستلمة YTD', '${_reports.length}', core_theme.AC.info, Icons.mail),
          _kpi('قيد التحقيق', '$active', core_theme.AC.warn, Icons.search),
          _kpi('ثبتت صحتها', '$substantiated', core_theme.AC.err, Icons.check_circle),
          _kpi('لم تثبت', '$unsubstantiated', core_theme.AC.ok, Icons.cancel),
          _kpi('مجهولة الهوية', '$anonymous / ${_reports.length}', const Color(0xFF4A148C), Icons.visibility_off),
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
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reports.length,
      itemBuilder: (ctx, i) {
        final r = _reports[i];
        final severityColor = _severityColor(r.severity);
        final statusColor = _statusColor(r.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: severityColor.withValues(alpha: 0.3), width: r.severity == 'critical' ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_categoryIcon(r.category), color: severityColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(r.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: core_theme.AC.ts)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: severityColor, borderRadius: BorderRadius.circular(3)),
                              child: Text(_severityLabel(r.severity),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: core_theme.AC.bdr, borderRadius: BorderRadius.circular(3)),
                              child: Text(_categoryLabel(r.category),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                            if (r.reporter == 'anonymous') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_off, size: 10, color: Color(0xFF4A148C)),
                                    SizedBox(width: 3),
                                    Text('مجهول', style: TextStyle(fontSize: 10, color: Color(0xFF4A148C), fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 11, color: core_theme.AC.ts),
                            const SizedBox(width: 3),
                            Text('استُلم: ${r.receivedAt}',
                                style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                            const SizedBox(width: 14),
                            Icon(Icons.fact_check, size: 11, color: core_theme.AC.ts),
                            const SizedBox(width: 3),
                            Text('أُسند: ${r.assignedAt}',
                                style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                            const SizedBox(width: 14),
                            Icon(Icons.group, size: 11, color: core_theme.AC.ts),
                            const SizedBox(width: 3),
                            Text(r.assignee, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(r.status), size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(_statusLabel(r.status),
                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelsTab() {
    final channels = [
      _Channel('خط ساخن سرّي 24/7', '+966-800-APEX-ETH', 'phone', core_theme.AC.info, 'متاح 24 ساعة · مكالمة مشفّرة · دون تسجيل رقم'),
      _Channel('بريد إلكتروني آمن', 'ethics@apex-secure.sa', 'email', core_theme.AC.ok, 'تشفير PGP · فتح فقط بيد فريق الامتثال المستقل'),
      _Channel('بوابة ويب سرّية', 'ethics.apex.sa', 'web', core_theme.AC.purple, 'بدون تسجيل دخول · IP غير مُسجّل · نموذج مشفّر'),
      _Channel('صندوق بريدي فعلي', 'ص.ب 99123 · الرياض', 'mail', core_theme.AC.warn, 'بريد ورقي · لا فتح إلا بواسطة رئيس لجنة الأخلاقيات'),
      _Channel('طرف ثالث مستقل', 'EthicsPoint by NAVEX', 'third-party', core_theme.AC.err, 'خدمة مستقلة · لا اتصال مباشر بالشركة'),
      _Channel('شخصي لرئيس اللجنة', 'موعد سرّي عند الطلب', 'in-person', core_theme.AC.info, 'في مكان خارج المنشأة · موعد مشفّر'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: core_theme.AC.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '6 قنوات مستقلة للإبلاغ — اختر الأنسب لك. كل القنوات مشفّرة وتضمن السرّية التامة وحماية هوية المبلّغ.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final c in channels)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.color.withValues(alpha: 0.3), width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_channelIcon(c.type), color: c.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(c.identifier,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: c.color, fontFamily: 'monospace')),
                      const SizedBox(height: 6),
                      Text(c.description, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.5)),
                    ],
                  ),
                ),
                Icon(Icons.lock, color: core_theme.AC.ok, size: 24),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPolicyTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.policy, color: Color(0xFF4A148C)),
                  SizedBox(width: 8),
                  Text('سياسة حماية المبلّغين', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 16),
              _policyItem('🛡️ سرّية تامة',
                  'هوية المبلّغ محمية بموجب القانون والسياسة الداخلية. لا يُفصح عنها إلا بقرار قضائي.'),
              _policyItem('🚫 عدم الانتقام',
                  'أي فعل انتقامي ضد المبلّغ (فصل/تخفيض/تهميش) يُعتبر مخالفة خطيرة تستوجب عقوبات فورية.'),
              _policyItem('⚖️ تحقيق محايد',
                  'التحقيق بلجنة مستقلة من إدارة الامتثال، المراجعة الداخلية، والموارد البشرية.'),
              _policyItem('⏱️ مهل زمنية',
                  'إفادة استلام البلاغ خلال 48 ساعة. خطة تحقيق خلال 7 أيام. نتيجة أولية خلال 30 يوم.'),
              _policyItem('📝 توثيق كامل',
                  'كل البلاغات توثّق في نظام آمن (immutable log) ويرفع تقرير ربعي للجنة المراجعة.'),
              _policyItem('🎁 حوافز إيجابية',
                  'البلاغات الصحيحة التي تؤدي لاستكشاف فساد كبير قد تستحق مكافأة مالية وفق قرار اللجنة.'),
              _policyItem('❌ سوء استخدام',
                  'البلاغات الكيدية أو غير الصحيحة عن عمد قد تؤدي إلى عقوبات تأديبية.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: core_theme.AC.ok,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.ok),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: core_theme.AC.ok),
                  SizedBox(width: 8),
                  Text('معتمد من', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              _approver('مجلس الإدارة', '2026-01-28', true),
              _approver('لجنة المراجعة', '2026-01-15', true),
              _approver('لجنة الحوكمة', '2026-01-10', true),
              _approver('هيئة السوق المالية — إبلاغ', '2026-02-01', true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _policyItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(fontSize: 12, height: 1.6, color: core_theme.AC.ts)),
        ],
      ),
    );
  }

  Widget _approver(String name, String date, bool approved) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(approved ? Icons.check_circle : Icons.warning, size: 16, color: approved ? core_theme.AC.ok : core_theme.AC.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
          Text(date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  IconData _categoryIcon(String c) {
    switch (c) {
      case 'fraud':
        return Icons.gpp_bad;
      case 'harassment':
        return Icons.report;
      case 'conflict':
        return Icons.compare_arrows;
      case 'misuse':
        return Icons.money_off;
      case 'compliance':
        return Icons.gavel;
      case 'security':
        return Icons.security;
      case 'procurement':
        return Icons.shopping_cart;
      default:
        return Icons.flag;
    }
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'fraud':
        return 'احتيال';
      case 'harassment':
        return 'تحرّش';
      case 'conflict':
        return 'تعارض';
      case 'misuse':
        return 'سوء استخدام';
      case 'compliance':
        return 'امتثال';
      case 'security':
        return 'أمن';
      case 'procurement':
        return 'مشتريات';
      default:
        return c;
    }
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return core_theme.AC.err;
      case 'high':
        return core_theme.AC.warn;
      case 'medium':
        return core_theme.AC.warn;
      case 'low':
        return core_theme.AC.info;
      default:
        return core_theme.AC.td;
    }
  }

  String _severityLabel(String s) {
    switch (s) {
      case 'critical':
        return 'حرج';
      case 'high':
        return 'عالٍ';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'investigating':
        return core_theme.AC.warn;
      case 'substantiated':
        return core_theme.AC.err;
      case 'unsubstantiated':
        return core_theme.AC.ok;
      case 'closed':
        return core_theme.AC.td;
      default:
        return core_theme.AC.info;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'investigating':
        return Icons.search;
      case 'substantiated':
        return Icons.gavel;
      case 'unsubstantiated':
        return Icons.do_not_disturb;
      case 'closed':
        return Icons.archive;
      default:
        return Icons.circle;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'investigating':
        return 'قيد التحقيق';
      case 'substantiated':
        return 'ثبتت';
      case 'unsubstantiated':
        return 'لم تثبت';
      case 'closed':
        return 'مغلق';
      default:
        return s;
    }
  }

  IconData _channelIcon(String t) {
    switch (t) {
      case 'phone':
        return Icons.phone;
      case 'email':
        return Icons.email;
      case 'web':
        return Icons.web;
      case 'mail':
        return Icons.mail;
      case 'third-party':
        return Icons.business;
      case 'in-person':
        return Icons.meeting_room;
      default:
        return Icons.forum;
    }
  }
}

class _Report {
  final String id;
  final String title;
  final String category;
  final String status;
  final String reporter; // 'anonymous' or 'identified'
  final String receivedAt;
  final String severity;
  final String assignedAt;
  final String assignee;
  const _Report(this.id, this.title, this.category, this.status, this.reporter, this.receivedAt, this.severity, this.assignedAt, this.assignee);
}

class _Channel {
  final String name;
  final String identifier;
  final String type;
  final Color color;
  final String description;
  const _Channel(this.name, this.identifier, this.type, this.color, this.description);
}
