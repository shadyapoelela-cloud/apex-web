/// APEX Wave 20 — CRM (ERP Sub-Module).
///
/// Fills CRM gap in V5. Fourth production wave.
///
/// Tabs: Leads · Opportunities · Pipeline · Activities · Contacts
/// More ▾: Campaigns · Email Sync · Lead Scoring AI · Win/Loss · Settings
///
/// Route: /app/erp/operations/crm
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_undo_toast.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'العملاء المحتملون', Icons.person_search),
          _tabBtn(1, 'الفرص', Icons.attach_money),
          _tabBtn(2, 'خط البيع', Icons.view_kanban),
          _tabBtn(3, 'الأنشطة', Icons.event_note),
          _tabBtn(4, 'جهات الاتصال', Icons.contacts),
          const Spacer(),
          _moreMenu(),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? core_theme.AC.gold.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: core_theme.AC.gold.withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? core_theme.AC.gold : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? core_theme.AC.gold : core_theme.AC.ts,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreMenu() {
    return PopupMenuButton<String>(
      tooltip: 'المزيد',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('المزيد', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          Icon(Icons.arrow_drop_down, size: 16, color: core_theme.AC.ts),
        ],
      ),
      itemBuilder: (ctx) => [
        _mItem('campaigns', 'الحملات', Icons.campaign),
        _mItem('email', 'مزامنة البريد', Icons.email),
        _mItem('ai', 'تقييم العملاء بالذكاء', Icons.psychology),
        _mItem('winloss', 'تحليل الربح/الخسارة', Icons.analytics),
        _mItem('settings', 'الإعدادات', Icons.settings),
      ],
    );
  }

  PopupMenuItem<String> _mItem(String v, String label, IconData icon) {
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 14, color: core_theme.AC.ts),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildLeads();
      case 1: return _buildOpportunities();
      case 2: return _buildPipeline();
      case 3: return _buildActivities();
      case 4: return _buildContacts();
      default: return const SizedBox();
    }
  }

  // ── Tab 1: Leads ─────────────────────────────────────────────────

  Widget _buildLeads() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('عملاء محتملون جدد', '23', Icons.person_add, core_theme.AC.info),
            _Stat('قيد التواصل', '12', Icons.phone, core_theme.AC.warn),
            _Stat('مؤهّلون', '8', Icons.verified, core_theme.AC.ok),
            _Stat('معدّل التحويل', '34%', Icons.trending_up, core_theme.AC.gold),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('العملاء المحتملون', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload, size: 14),
                label: Text('استيراد CSV'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: Text('عميل محتمل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: core_theme.AC.gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                for (final l in _mockLeads()) _leadRow(l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadRow(_Lead lead) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: core_theme.AC.gold.withOpacity(0.2),
            child: Text(
              lead.company.substring(0, 1),
              style: TextStyle(color: core_theme.AC.gold, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.company, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text('${lead.contact} — ${lead.title}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          // AI Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _scoreColor(lead.aiScore).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _scoreColor(lead.aiScore).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, size: 11, color: _scoreColor(lead.aiScore)),
                const SizedBox(width: 3),
                Text(
                  '${lead.aiScore}/100',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor(lead.aiScore),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Source
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: core_theme.AC.tp.withOpacity(0.06),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(lead.source, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(lead.status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              lead.status,
              style: TextStyle(fontSize: 11, color: _statusColor(lead.status), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.phone, size: 14, color: core_theme.AC.info),
            onPressed: () {},
            tooltip: 'اتصال',
          ),
          IconButton(
            icon: Icon(Icons.email, size: 14, color: core_theme.AC.purple),
            onPressed: () {},
            tooltip: 'بريد',
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return core_theme.AC.ok;
    if (score >= 50) return core_theme.AC.warn;
    return const Color(0xFFB91C1C);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'جديد': return core_theme.AC.info;
      case 'قيد التواصل': return core_theme.AC.warn;
      case 'مؤهّل': return core_theme.AC.ok;
      case 'غير مؤهّل': return const Color(0xFFB91C1C);
      default: return core_theme.AC.ts;
    }
  }

  // ── Tab 2: Opportunities ─────────────────────────────────────────

  Widget _buildOpportunities() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('الفرص النشطة', '18', Icons.attach_money, core_theme.AC.info),
            _Stat('قيمة خط البيع', '8.4M', Icons.account_balance_wallet, core_theme.AC.gold),
            _Stat('معدّل الفوز', '42%', Icons.emoji_events, core_theme.AC.ok),
            _Stat('متوسط الصفقة', '467K', Icons.trending_up, core_theme.AC.purple),
          ]),
          const SizedBox(height: 16),
          Text('الفرص البيعية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 1000 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.8,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final o in _mockOpportunities()) _OpportunityCard(opp: o),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Pipeline (Kanban) ─────────────────────────────────────

  Widget _buildPipeline() {
    final stages = ['تواصل أولي', 'تأهّل', 'عرض سعر', 'تفاوض', 'إغلاق'];
    final opps = _mockOpportunities();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in stages) ...[
            _pipelineColumn(stage, opps.where((o) => o.stage == stage).toList()),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _pipelineColumn(String stage, List<_Opportunity> items) {
    final total = items.fold(0.0, (s, o) => s + o.amount);
    final color = _stageColor(stage);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(stage, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                Text(
                  '${total.toStringAsFixed(0)} ر.س',
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          for (final o in items)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _pipelineCard(o, color),
            ),
        ],
      ),
    );
  }

  Widget _pipelineCard(_Opportunity opp, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opp.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: 2,
          ),
          Text(opp.company, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${opp.amount.toStringAsFixed(0)} ر.س',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${opp.probability}%',
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event, size: 10, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text(
                opp.closeDate,
                style: TextStyle(fontSize: 10, color: core_theme.AC.ts),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 8,
                backgroundColor: core_theme.AC.gold.withOpacity(0.2),
                child: Text(
                  opp.owner.substring(0, 1),
                  style: TextStyle(fontSize: 9, color: core_theme.AC.gold, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'تواصل أولي': return const Color(0xFF6B7280);
      case 'تأهّل': return core_theme.AC.info;
      case 'عرض سعر': return core_theme.AC.warn;
      case 'تفاوض': return core_theme.AC.purple;
      case 'إغلاق': return core_theme.AC.ok;
      default: return core_theme.AC.ts;
    }
  }

  // ── Tab 4: Activities ────────────────────────────────────────────

  Widget _buildActivities() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('أنشطة اليوم', '12', Icons.today, core_theme.AC.info),
            _Stat('مكالمات', '23 هذا الأسبوع', Icons.phone, core_theme.AC.ok),
            _Stat('اجتماعات', '8 مجدولة', Icons.event, core_theme.AC.warn),
            _Stat('بريد إلكتروني', '47 مُرسَل', Icons.email, core_theme.AC.purple),
          ]),
          const SizedBox(height: 16),
          Text('الأنشطة الأخيرة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _activityRow(Icons.phone, core_theme.AC.ok, 'مكالمة مع SABIC Procurement', 'أحمد — قبل ساعتين', 'اتفق على اجتماع الأسبوع القادم'),
                _activityRow(Icons.email, core_theme.AC.purple, 'بريد إلى Marriott Hotels', 'سارة — قبل 3 ساعات', 'إرسال عرض السعر النهائي'),
                _activityRow(Icons.event, core_theme.AC.warn, 'اجتماع ABC Trading', 'محمد — اليوم 14:00', 'عرض تقديمي + استعراض الخدمات'),
                _activityRow(Icons.note, core_theme.AC.info, 'ملاحظة: Al Rajhi Bank', 'فاطمة — قبل يوم', 'يفضّلون دفعات ربع سنوية'),
                _activityRow(Icons.handshake, core_theme.AC.gold, 'توقيع عقد STC', 'خالد — قبل يومين', 'قيمة العقد: 185,000 ر.س'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(IconData icon, Color color, String title, String meta, String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.04))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(meta, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                const SizedBox(height: 4),
                Text(note, style: TextStyle(fontSize: 12, color: core_theme.AC.tp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Contacts ──────────────────────────────────────────────

  Widget _buildContacts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('جهات الاتصال', '234', Icons.contacts, core_theme.AC.info),
            _Stat('حسابات فعّالة', '47', Icons.business, core_theme.AC.ok),
            _Stat('ترشيحات AI', '12', Icons.auto_awesome, const Color(0xFFEC4899)),
            _Stat('تحتاج متابعة', '8', Icons.schedule, core_theme.AC.warn),
          ]),
          const SizedBox(height: 16),
          Text('جهات الاتصال', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final c in _mockContacts()) _contactCard(c),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _contactCard(_Contact contact) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: core_theme.AC.gold.withOpacity(0.2),
            child: Text(
              contact.name.substring(0, 1),
              style: TextStyle(color: core_theme.AC.gold, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            contact.title,
            style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            contact.company,
            style: TextStyle(fontSize: 10, color: core_theme.AC.td, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.phone, size: 14, color: core_theme.AC.ok),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(Icons.email, size: 14, color: core_theme.AC.info),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const Spacer(),
              Text(
                '#${contact.dealsCount} صفقات',
                style: TextStyle(fontSize: 9, color: core_theme.AC.td),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsRow(List<_Stat> stats) {
    return Row(
      children: [
        for (final s in stats) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.color)),
                        Text(s.label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (s != stats.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  List<_Lead> _mockLeads() => [
        _Lead('SABIC Procurement', 'عبدالرحمن الشهري', 'مدير المشتريات', 'قيد التواصل', 'LinkedIn', 87),
        _Lead('Marriott Hotels KSA', 'Sarah Mitchell', 'CFO', 'مؤهّل', 'Referral', 92),
        _Lead('ABC Trading Co', 'محمد علي', 'المدير العام', 'جديد', 'Website', 56),
        _Lead('Al Rajhi Bank', 'خالد الدوسري', 'مدير المشاريع', 'قيد التواصل', 'Event', 78),
        _Lead('ARAMCO Procurement', 'Anas Al-Harbi', 'Deputy GM', 'مؤهّل', 'Direct', 95),
        _Lead('STC Enterprise', 'Fatma Al-Otaibi', 'Head of Finance', 'غير مؤهّل', 'Cold Call', 28),
      ];

  List<_Opportunity> _mockOpportunities() => [
        _Opportunity('SABIC Audit 2026', 'SABIC', 450000, 'تفاوض', 75, '2026-05-15', 'أحمد'),
        _Opportunity('ABC Advisory Contract', 'ABC Trading', 125000, 'عرض سعر', 50, '2026-05-22', 'سارة'),
        _Opportunity('Al Rajhi IT Consulting', 'Al Rajhi Bank', 280000, 'تأهّل', 30, '2026-06-10', 'محمد'),
        _Opportunity('Marriott Review', 'Marriott', 180000, 'إغلاق', 90, '2026-04-30', 'خالد'),
        _Opportunity('ARAMCO Feasibility', 'ARAMCO', 750000, 'تواصل أولي', 15, '2026-07-01', 'ليلى'),
        _Opportunity('STC Tax Advisory', 'STC', 87500, 'تفاوض', 65, '2026-05-28', 'فاطمة'),
      ];

  List<_Contact> _mockContacts() => [
        _Contact('عبدالرحمن الشهري', 'مدير المشتريات', 'SABIC', 3),
        _Contact('Sarah Mitchell', 'CFO', 'Marriott', 5),
        _Contact('محمد علي', 'المدير العام', 'ABC Trading', 2),
        _Contact('خالد الدوسري', 'مدير المشاريع', 'Al Rajhi Bank', 4),
        _Contact('Anas Al-Harbi', 'Deputy GM', 'ARAMCO', 1),
        _Contact('Fatma Al-Otaibi', 'Head of Finance', 'STC', 2),
        _Contact('د. أحمد الحربي', 'شريك', 'مكتب الدليل', 8),
        _Contact('Lisa Chen', 'Procurement Lead', 'Saudi Electricity', 6),
      ];
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _Lead {
  final String company;
  final String contact;
  final String title;
  final String status;
  final String source;
  final int aiScore;
  _Lead(this.company, this.contact, this.title, this.status, this.source, this.aiScore);
}

class _Opportunity {
  final String name;
  final String company;
  final double amount;
  final String stage;
  final int probability;
  final String closeDate;
  final String owner;
  _Opportunity(this.name, this.company, this.amount, this.stage, this.probability, this.closeDate, this.owner);
}

class _Contact {
  final String name;
  final String title;
  final String company;
  final int dealsCount;
  _Contact(this.name, this.title, this.company, this.dealsCount);
}

class _OpportunityCard extends StatelessWidget {
  final _Opportunity opp;

  const _OpportunityCard({required this.opp});

  @override
  Widget build(BuildContext context) {
    final stageColor = {
      'تواصل أولي': const Color(0xFF6B7280),
      'تأهّل': core_theme.AC.info,
      'عرض سعر': core_theme.AC.warn,
      'تفاوض': core_theme.AC.purple,
      'إغلاق': core_theme.AC.ok,
    }[opp.stage] ?? core_theme.AC.ts;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stageColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  opp.stage,
                  style: TextStyle(fontSize: 10, color: stageColor, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              Text(
                '${opp.probability}%',
                style: TextStyle(fontSize: 13, color: stageColor, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(opp.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(opp.company, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const Spacer(),
          Text(
            '${opp.amount.toStringAsFixed(0)} ر.س',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: stageColor,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event, size: 11, color: core_theme.AC.ts),
              const SizedBox(width: 3),
              Text(opp.closeDate, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              const Spacer(),
              Text('@ ${opp.owner}', style: TextStyle(fontSize: 10, color: core_theme.AC.td)),
            ],
          ),
        ],
      ),
    );
  }
}
