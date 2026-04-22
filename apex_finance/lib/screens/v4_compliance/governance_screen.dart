/// APEX Wave 31 — Governance & Board (Compliance > Regulatory).
///
/// Board Pack · Meetings · Minutes · Resolutions · Policies · Committees.
///
/// Route: /app/compliance/regulatory/governance (overrides eligibility alias)
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_undo_toast.dart';

class GovernanceScreen extends StatefulWidget {
  const GovernanceScreen({super.key});

  @override
  State<GovernanceScreen> createState() => _GovernanceScreenState();
}

class _GovernanceScreenState extends State<GovernanceScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.08)))),
          child: Row(
            children: [
              _tabBtn(0, 'حزمة المجلس', Icons.folder_special),
              _tabBtn(1, 'الاجتماعات', Icons.event),
              _tabBtn(2, 'المحاضر', Icons.description),
              _tabBtn(3, 'القرارات', Icons.gavel),
              _tabBtn(4, 'السياسات', Icons.policy),
              _tabBtn(5, 'اللجان', Icons.groups),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
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
          color: active ? const Color(0xFF2E7D5B).withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF2E7D5B).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF2E7D5B) : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFF2E7D5B) : core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _boardPack();
      case 1: return _meetings();
      case 2: return _minutes();
      case 3: return _resolutions();
      case 4: return _policies();
      case 5: return _committees();
      default: return const SizedBox();
    }
  }

  Widget _boardPack() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF2E7D5B), core_theme.AC.ok]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_special, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حزمة اجتماع المجلس — Q1 2026', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('اجتماع 2026-04-28 · الرياض · 9 أعضاء', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('محتويات الحزمة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final item in [
            _PackItem('01', 'جدول الأعمال', 'Agenda', 'agenda.pdf', 2),
            _PackItem('02', 'محضر الاجتماع السابق', 'Previous Minutes', 'prev-minutes.pdf', 8),
            _PackItem('03', 'القوائم المالية Q1', 'Financial Statements', 'fs-q1-2026.pdf', 24),
            _PackItem('04', 'تقرير المدير المالي', 'CFO Report', 'cfo-report.pdf', 12),
            _PackItem('05', 'تقرير الامتثال', 'Compliance Report', 'compliance.pdf', 6),
            _PackItem('06', 'تقرير المراجع الخارجي', 'Auditor Report', 'auditor.pdf', 32),
            _PackItem('07', 'مؤشرات الأداء (KPIs)', 'KPIs Dashboard', 'kpis.pdf', 4),
            _PackItem('08', 'القضايا المطروحة للتصويت', 'Voting Items', 'voting.pdf', 3),
          ])
            _packRow(item),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.email, size: 14), label: Text('إرسال للأعضاء')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 14),
                label: Text('تحميل الحزمة كاملة (ZIP)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D5B), foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _packRow(_PackItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF2E7D5B).withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(item.number, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D5B), fontFamily: 'monospace')),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.titleAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(item.titleEn, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Expanded(child: Text(item.file, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts))),
          Text('${item.pages} صفحة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.visibility, size: 14), onPressed: () {}, tooltip: 'عرض'),
          IconButton(icon: const Icon(Icons.download, size: 14), onPressed: () {}, tooltip: 'تحميل'),
        ],
      ),
    );
  }

  Widget _meetings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('اجتماعات المجلس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: Text('جدولة اجتماع'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D5B), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final m in [
            _Meeting('2026-04-28', 'اجتماع المجلس الأول 2026', 'مجلس الإدارة', '09:00', 'الرياض', 9, 9, 'قادم', core_theme.AC.info),
            _Meeting('2026-01-15', 'اجتماع المجلس الرابع 2025', 'مجلس الإدارة', '10:00', 'جدّة', 9, 8, 'مكتمل', core_theme.AC.ok),
            _Meeting('2026-02-10', 'لجنة المراجعة Q1 2026', 'لجنة المراجعة', '11:00', 'Zoom', 5, 5, 'مكتمل', core_theme.AC.ok),
            _Meeting('2026-03-20', 'لجنة المكافآت', 'المكافآت', '14:00', 'الرياض', 4, 4, 'مكتمل', core_theme.AC.ok),
          ])
            _meetingRow(m),
        ],
      ),
    );
  }

  Widget _meetingRow(_Meeting m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: m.color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Column(
              children: [
                Text(m.date.substring(8, 10), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: m.color)),
                Text(m.date.substring(0, 7), style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text('${m.committee} · ${m.time} · ${m.location}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الحضور', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${m.attended}/${m.total}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: m.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(m.status, style: TextStyle(fontSize: 11, color: m.color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _minutes() {
    return _comingSection('المحاضر', 'محاضر تفصيلية + التصويتات + المرفقات لكل قرار');
  }

  Widget _resolutions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('قرارات المجلس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final r in [
            _Resolution('RES-2026-008', 'اعتماد القوائم المالية Q1 2026', 'مُعتمد', 9, 9, 0, core_theme.AC.ok),
            _Resolution('RES-2026-007', 'توزيع أرباح 0.85 ر.س/سهم', 'مُعتمد', 8, 8, 0, core_theme.AC.ok),
            _Resolution('RES-2026-006', 'ترقية المدير المالي', 'قيد التصويت', 5, 3, 1, core_theme.AC.warn),
            _Resolution('RES-2026-005', 'استحواذ 30% من شركة XYZ', 'مرفوض', 9, 4, 5, const Color(0xFFB91C1C)),
          ])
            _resolutionCard(r),
        ],
      ),
    );
  }

  Widget _resolutionCard(_Resolution r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: r.color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: r.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(r.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: r.color)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: r.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(r.status, style: TextStyle(fontSize: 11, color: r.color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _voteBar('موافق', r.yes, r.total, core_theme.AC.ok),
              const SizedBox(width: 8),
              _voteBar('معارض', r.no, r.total, const Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              _voteBar('ممتنع', r.total - r.yes - r.no, r.total, core_theme.AC.td),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voteBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              const Spacer(),
              Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: pct, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color), minHeight: 4),
        ],
      ),
    );
  }

  Widget _policies() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السياسات المعتمدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final p in [
            _Policy('POL-001', 'سياسة مكافحة غسل الأموال', 'AML Policy', '2025-06-15', 'سارية', core_theme.AC.ok),
            _Policy('POL-002', 'سياسة تضارب المصالح', 'Conflicts of Interest', '2025-06-15', 'سارية', core_theme.AC.ok),
            _Policy('POL-003', 'سياسة الحوكمة', 'Corporate Governance', '2025-09-20', 'سارية', core_theme.AC.ok),
            _Policy('POL-004', 'سياسة خصوصية البيانات', 'Data Privacy', '2024-12-01', 'تحتاج تحديث', core_theme.AC.warn),
            _Policy('POL-005', 'سياسة المشتريات', 'Procurement', '2025-03-10', 'سارية', core_theme.AC.ok),
            _Policy('POL-006', 'مدوّنة السلوك', 'Code of Conduct', '2024-08-15', 'تحتاج تحديث', core_theme.AC.warn),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
              child: Row(
                children: [
                  const Icon(Icons.policy, size: 18, color: Color(0xFF2E7D5B)),
                  const SizedBox(width: 10),
                  Text(p.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.titleAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(p.titleEn, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                  Expanded(child: Text('اعتماد: ${p.approvedDate}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: p.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(p.status, style: TextStyle(fontSize: 11, color: p.color, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _committees() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اللجان المنبثقة من المجلس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _committeeCard('لجنة المراجعة', 'Audit Committee', 5, 4, ['د. عبدالله السالم', 'سارة محمود', 'خالد أحمد'], const Color(0xFF4A148C)),
                  _committeeCard('لجنة المكافآت', 'Compensation', 4, 3, ['نورا القحطاني', 'محمد الراشد'], core_theme.AC.gold),
                  _committeeCard('لجنة الحوكمة', 'Governance', 3, 3, ['أحمد السالم', 'ليلى السعيد'], const Color(0xFF2E7D5B)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _committeeCard(String ar, String en, int members, int meetings, List<String> names, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.groups, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(en, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat('الأعضاء', '$members', color),
              const SizedBox(width: 8),
              _miniStat('اجتماعات هذا العام', '$meetings', color),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final n in names)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(3)),
                  child: Text(n, style: const TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _comingSection(String title, String desc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 56, color: core_theme.AC.td),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(desc, style: TextStyle(fontSize: 12, color: core_theme.AC.ts), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PackItem {
  final String number, titleAr, titleEn, file;
  final int pages;
  _PackItem(this.number, this.titleAr, this.titleEn, this.file, this.pages);
}

class _Meeting {
  final String date, title, committee, time, location, status;
  final int total, attended;
  final Color color;
  _Meeting(this.date, this.title, this.committee, this.time, this.location, this.total, this.attended, this.status, this.color);
}

class _Resolution {
  final String id, title, status;
  final int total, yes, no;
  final Color color;
  _Resolution(this.id, this.title, this.status, this.total, this.yes, this.no, this.color);
}

class _Policy {
  final String id, titleAr, titleEn, approvedDate, status;
  final Color color;
  _Policy(this.id, this.titleAr, this.titleEn, this.approvedDate, this.status, this.color);
}

/// Wave 32 — Notifications Center + Activity Feed.
class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.08)))),
          child: Row(
            children: [
              Icon(Icons.notifications_active, size: 22, color: core_theme.AC.purple),
              const SizedBox(width: 8),
              Text('مركز التنبيهات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFB91C1C), borderRadius: BorderRadius.circular(12)),
                child: Text('12 جديد', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ApexV5UndoToast.show(context, messageAr: 'تم تعليم الكل كمقروءة', onUndo: () {});
                },
                icon: const Icon(Icons.done_all, size: 14),
                label: Text('تعليم الكل كمقروءة'),
              ),
              IconButton(icon: const Icon(Icons.settings), onPressed: () {}, tooltip: 'إعدادات'),
            ],
          ),
        ),
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 6,
            children: [
              _filterChip('all', 'الكل', 47),
              _filterChip('zatca', 'ZATCA', 8),
              _filterChip('audit', 'المراجعة', 6),
              _filterChip('finance', 'المالية', 12),
              _filterChip('compliance', 'الامتثال', 5),
              _filterChip('ai', 'الذكاء', 9),
              _filterChip('system', 'النظام', 7),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _notifRow('🚨', 'زاتكا — فاتورة رُفضت', 'INV-2026-187 — BR-KSA-16: VAT amount mismatch', 'قبل 5 دقائق', const Color(0xFFB91C1C), action: 'عرض التفاصيل'),
              _notifRow('⚡', 'AI Guardrail — يحتاج اعتماد', 'تصنيف 3 قيود بثقة 88% — أقل من الحد 95%', 'قبل 15 دقيقة', core_theme.AC.warn, action: 'راجع'),
              _notifRow('📅', 'موعد نهائي قريب', 'إقرار VAT Q1 2026 يستحق خلال 3 أيام', 'قبل ساعة', core_theme.AC.warn, action: 'ابدأ الآن'),
              _notifRow('✅', 'مصاريف تمت الموافقة', '5 طلبات سفر لمدير العمليات', 'قبل ساعتين', core_theme.AC.ok),
              _notifRow('💸', 'فواتير متأخرة', 'ABC Trading — 45,000 ر.س متأخرة 12 يوم', 'قبل 3 ساعات', const Color(0xFFB91C1C), action: 'أرسل تذكير'),
              _notifRow('🎯', 'APEX Match — تطابق جديد', 'عميل Marriott يبحث عن مراجع SOCPA', 'قبل 4 ساعات', const Color(0xFFE65100), action: 'عرض الفرصة'),
              _notifRow('🏦', 'مطابقة بنكية تلقائية', 'AI طابقت 18 معاملة — 100% ثقة', 'قبل 6 ساعات', core_theme.AC.ok),
              _notifRow('📊', 'تقرير جديد جاهز', 'تقرير المبيعات الأسبوعي — Q1 W17', 'قبل يوم', core_theme.AC.info),
              _notifRow('⚠️', 'CSID سينتهي', 'شهادة Fatoora تنتهي خلال 15 يوم', 'قبل يوم', core_theme.AC.warn, action: 'جدّد'),
              _notifRow('📋', 'اجتماع المجلس — تذكير', 'اجتماع 2026-04-28 — حزمة الاجتماع جاهزة', 'قبل يومين', const Color(0xFF2E7D5B)),
              _notifRow('🔒', 'محاولة دخول مشبوهة', 'من IP: 185.220.101.45 — تم الحظر', 'قبل يومين', const Color(0xFFB91C1C), action: 'تفاصيل الأمان'),
              _notifRow('🎓', 'تدريب متاح', 'دورة ZATCA Phase 2 — 2026-05-15', 'قبل 3 أيام', core_theme.AC.purple, action: 'سجّل'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label, int count) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? core_theme.AC.purple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? core_theme.AC.purple : core_theme.AC.tp.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : core_theme.AC.tp)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: (active ? Colors.white : core_theme.AC.purple).withOpacity(active ? 0.25 : 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : core_theme.AC.purple)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifRow(String emoji, String title, String detail, String time, Color color, {String? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withOpacity(0.06))),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(detail, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                Text(time, style: TextStyle(fontSize: 10, color: core_theme.AC.td)),
              ],
            ),
          ),
          if (action != null)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(action),
            ),
        ],
      ),
    );
  }
}
