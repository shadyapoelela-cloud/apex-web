/// APEX Wave 59 — Audit Engagement Kickoff.
/// Route: /app/audit/engagement/kickoff
///
/// Team assignment, kickoff meeting, entrance conference.
library;

import 'package:flutter/material.dart';

class AuditKickoffScreen extends StatefulWidget {
  const AuditKickoffScreen({super.key});
  @override
  State<AuditKickoffScreen> createState() => _AuditKickoffScreenState();
}

class _AuditKickoffScreenState extends State<AuditKickoffScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
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
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF4A148C),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.groups, size: 16), text: 'فريق الارتباط'),
            Tab(icon: Icon(Icons.event, size: 16), text: 'اجتماع البدء'),
            Tab(icon: Icon(Icons.list_alt, size: 16), text: 'قائمة المطلوبات'),
            Tab(icon: Icon(Icons.folder_shared, size: 16), text: 'وصول وصلاحيات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildTeamTab(),
              _buildMeetingTab(),
              _buildPblTab(),
              _buildAccessTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.rocket_launch, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('بدء الارتباط — NEOM Company',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('تشكيل الفريق · اجتماع البدء · قائمة مطلوبات أوّلية · توزيع صلاحيات النظام',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    final team = const [
      _Member('PTR-003', 'د. عبدالله السهلي', 'الشريك المسؤول (Engagement Partner)', 5, 40),
      _Member('PTR-008', 'أ. نايف الحارثي', 'شريك المراجعة الفنية (EQR)', 3, 30),
      _Member('MGR-012', 'محمد القحطاني', 'مدير المراجعة', 8, 120),
      _Member('SMR-024', 'سارة الدوسري', 'مراجع أول', 5, 180),
      _Member('AUD-055', 'فهد الشمري', 'مراجع', 2, 160),
      _Member('AUD-078', 'نورة الغامدي', 'مراجع', 2, 160),
      _Member('SPC-005', 'لينا البكري', 'أخصائي ضرائب', 6, 40),
      _Member('SPC-011', 'راشد العنزي', 'أخصائي تقنية معلومات', 7, 60),
      _Member('TRN-025', 'أحمد الصالح', 'متدرب (Internship)', 0, 80),
    ];
    final totalHours = team.fold(0, (s, m) => s + m.hours);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFE6C200)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('فريق متخصص ومتنوع', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('9 أعضاء · 4 مستويات · 2 تخصص نوعي',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Text('$totalHours',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const Text(' ساعة', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final m in team)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _roleColor(m.role).withOpacity(0.15),
                  radius: 22,
                  child: Icon(_roleIcon(m.role), color: _roleColor(m.role)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m.id, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black54)),
                          const SizedBox(width: 8),
                          Text(m.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Text(m.role, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                _metric('الخبرة', '${m.experience} سنة', Colors.blue),
                const SizedBox(width: 8),
                _metric('الساعات', '${m.hours}', const Color(0xFFD4AF37)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildMeetingTab() {
    final agenda = const [
      _Item('09:00', 'استقبال وترحيب', 'فريق APEX + إدارة NEOM العليا', 15),
      _Item('09:15', 'تعارف واستعراض الفريق', 'تقديم الأدوار وجهات الاتصال', 15),
      _Item('09:30', 'استراتيجية الارتباط', 'الشريك يستعرض منهجية المراجعة وأبرز المخاطر', 30),
      _Item('10:00', 'الإطار الزمني والمراحل', 'المدير يستعرض الجدول الزمني والمعالم', 20),
      _Item('10:20', 'قائمة المطلوبات الأوّلية', 'PBL — ما نحتاجه من إدارة NEOM قبل بدء العمل', 25),
      _Item('10:45', 'استراحة قهوة', '', 15),
      _Item('11:00', 'بروتوكول التواصل', 'قنوات التواصل، تكرار الاجتماعات، بروتوكول الأمور العاجلة', 20),
      _Item('11:20', 'وصول للنظم', 'التقنية تناقش صلاحيات SAP، SharePoint، CCH Axcess', 20),
      _Item('11:40', 'تأكيد التوقعات', 'تأكيد متبادل لسقف الأمور، التقارير، الجلسات', 15),
      _Item('11:55', 'الأسئلة والأجوبة', 'مناقشة مفتوحة', 15),
      _Item('12:10', 'الخطوات التالية', 'توزيع المحاضر ومسؤوليات المتابعة', 5),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event, color: Color(0xFF4A148C)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('اجتماع البدء الرسمي (Entrance Conference)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('قادم بعد 3 أيام',
                        style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _meetingKpi(Icons.calendar_today, 'التاريخ', '2026-04-22'),
                  _meetingKpi(Icons.schedule, 'الوقت', '09:00 - 12:15'),
                  _meetingKpi(Icons.place, 'المكان', 'مقر NEOM — قاعة A'),
                  _meetingKpi(Icons.video_call, 'الرابط', 'Teams (مختلط)'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('جدول الأعمال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final a in agenda)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(a.time,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      if (a.detail.isNotEmpty)
                        Text(a.detail, style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4)),
                    ],
                  ),
                ),
                Text('${a.mins} د',
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _meetingKpi(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4A148C)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPblTab() {
    final items = const [
      _Pbl('قوائم مالية مقارنة للسنوات 2024 و2025', 'عام', '2026-04-25', 'مطلوب'),
      _Pbl('دليل سياسات المحاسبة المعتمد', 'عام', '2026-04-25', 'مطلوب'),
      _Pbl('هيكل تنظيمي وصلاحيات التوقيع', 'عام', '2026-04-25', 'مطلوب'),
      _Pbl('محاضر اجتماعات مجلس الإدارة ولجنة المراجعة', 'حوكمة', '2026-04-28', 'مطلوب'),
      _Pbl('تقرير المراجعة الداخلية عن 2025', 'حوكمة', '2026-04-28', 'مطلوب'),
      _Pbl('كشوف حسابات بنكية ومصادقات البنوك', 'أصول', '2026-05-05', 'مطلوب'),
      _Pbl('قائمة جرد المخزون مع كشف عيني', 'أصول', '2026-05-05', 'مستلم'),
      _Pbl('تقارير الأعمار للذمم المدينة والدائنة', 'ذمم', '2026-05-05', 'مطلوب'),
      _Pbl('عقود القروض وجداول السداد', 'تمويل', '2026-05-05', 'مستلم'),
      _Pbl('إقرارات ضريبية (VAT, WHT, Zakat) للسنة', 'ضرائب', '2026-05-08', 'مطلوب'),
      _Pbl('عقود ضمان واتفاقيات بيع كبيرة (> 5M ر.س)', 'إيرادات', '2026-05-08', 'مستلم'),
      _Pbl('تقرير تقييم مستقل للعقارات', 'أصول', '2026-05-12', 'قيد الإعداد'),
    ];
    final received = items.where((i) => i.status == 'مستلم').length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('قائمة المطلوبات (Provided By Client)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  ),
                  Text('$received / ${items.length} مستلم',
                      style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: received / items.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                minHeight: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final i in items)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Icon(_pblStatusIcon(i.status), color: _pblStatusColor(i.status), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(i.item, style: const TextStyle(fontSize: 12))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(i.category, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                ),
                const SizedBox(width: 10),
                Text(i.dueDate, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pblStatusColor(i.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(i.status,
                      style: TextStyle(
                        fontSize: 10,
                        color: _pblStatusColor(i.status),
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سيتم إرسال قائمة المطلوبات مع جدول زمني عبر البريد الإلكتروني لـ OHAm@NEOM.com فور اعتماد محضر الاجتماع',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccessTab() {
    final systems = const [
      _Sys('SAP S/4HANA', 'نظام تخطيط الموارد', 'read-only للعمليات والحسابات', true),
      _Sys('Oracle EPM', 'نظام إدارة الأداء المؤسسي', 'read-only للقوائم المالية', true),
      _Sys('SharePoint — NEOM', 'وثائق مجلس الإدارة', 'مجلد المراجعة الخارجية فقط', true),
      _Sys('Trade Finance System', 'الاعتمادات المستندية والضمانات', 'read-only', false),
      _Sys('HR System (SuccessFactors)', 'بيانات الموظفين والرواتب', 'read-only', false),
      _Sys('نظام نقاط البيع', 'حركات الفروع اليومية', 'read-only للعيّنات', false),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لا نطلب أي صلاحية كتابة — جميع الصلاحيات للقراءة فقط. يتم توثيق الوصول في سجل التدقيق داخل كل نظام.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in systems)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (s.granted ? Colors.green : Colors.orange).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s.granted ? Icons.lock_open : Icons.lock_outline,
                      color: s.granted ? Colors.green : Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text(s.description, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      Text(s.scope, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.4)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (s.granted ? Colors.green : Colors.orange).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s.granted ? 'ممنوح' : 'قيد المعالجة',
                      style: TextStyle(
                        fontSize: 11,
                        color: s.granted ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _roleColor(String role) {
    if (role.contains('الشريك')) return const Color(0xFF4A148C);
    if (role.contains('مدير')) return Colors.blue;
    if (role.contains('مراجع أول')) return Colors.teal;
    if (role.contains('أخصائي')) return Colors.orange;
    if (role.contains('متدرب')) return Colors.grey;
    return Colors.indigo;
  }

  IconData _roleIcon(String role) {
    if (role.contains('الشريك')) return Icons.star;
    if (role.contains('مدير')) return Icons.supervised_user_circle;
    if (role.contains('أول')) return Icons.badge;
    if (role.contains('أخصائي')) return Icons.science;
    if (role.contains('متدرب')) return Icons.school;
    return Icons.person;
  }

  IconData _pblStatusIcon(String s) {
    switch (s) {
      case 'مستلم':
        return Icons.check_circle;
      case 'قيد الإعداد':
        return Icons.hourglass_bottom;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _pblStatusColor(String s) {
    switch (s) {
      case 'مستلم':
        return Colors.green;
      case 'قيد الإعداد':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

class _Member {
  final String id;
  final String name;
  final String role;
  final int experience;
  final int hours;
  const _Member(this.id, this.name, this.role, this.experience, this.hours);
}

class _Item {
  final String time;
  final String title;
  final String detail;
  final int mins;
  const _Item(this.time, this.title, this.detail, this.mins);
}

class _Pbl {
  final String item;
  final String category;
  final String dueDate;
  final String status;
  const _Pbl(this.item, this.category, this.dueDate, this.status);
}

class _Sys {
  final String name;
  final String description;
  final String scope;
  final bool granted;
  const _Sys(this.name, this.description, this.scope, this.granted);
}
