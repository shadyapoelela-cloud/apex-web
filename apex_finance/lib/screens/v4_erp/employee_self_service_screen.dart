/// APEX Wave 81 — Employee Self-Service (ESS) Portal.
/// Route: /app/erp/hr/self-service
///
/// Employee-facing self-service: payslips, leave, expenses,
/// certificates, personal data.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class EmployeeSelfServiceScreen extends StatefulWidget {
  const EmployeeSelfServiceScreen({super.key});
  @override
  State<EmployeeSelfServiceScreen> createState() => _EmployeeSelfServiceScreenState();
}

class _EmployeeSelfServiceScreenState extends State<EmployeeSelfServiceScreen> {
  final _employee = const _EmpProfile(
    'EMP-001',
    'أحمد محمد العتيبي',
    'المدير المالي',
    'a.otaibi@apex.sa',
    '+966-50-1234567',
    '2018-03-15',
    22000,
    4500,
    'CFO',
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildProfile(),
        const SizedBox(height: 16),
        _buildQuickActions(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildLeaves()),
            const SizedBox(width: 12),
            Expanded(child: _buildPayslips()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCertificates()),
            const SizedBox(width: 12),
            Expanded(child: _buildTeam()),
          ],
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(
              child: Text(
                _employee.name.substring(0, 1),
                style: const TextStyle(color: Color(0xFF1A237E), fontSize: 36, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً ${_employee.name} 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('${_employee.title} · ${_employee.role}',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniInfo(Icons.badge, _employee.id),
                    const SizedBox(width: 16),
                    _miniInfo(Icons.email, _employee.email),
                    const SizedBox(width: 16),
                    _miniInfo(Icons.phone, _employee.phone),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Color(0xFFFFD700), size: 16),
                    SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تاريخ التعيين', style: TextStyle(color: core_theme.AC.ts, fontSize: 10)),
                        Text('8 سنوات · مارس 2018',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: core_theme.AC.ts),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QA('طلب إجازة', Icons.event_available, core_theme.AC.info),
      _QA('مطالبة مصروفات', Icons.receipt, core_theme.AC.warn),
      _QA('شهادة راتب', Icons.description, core_theme.AC.ok),
      _QA('تعديل بياناتي', Icons.edit, core_theme.AC.purple),
      _QA('قسيمة الراتب', Icons.payments, core_theme.AC.gold),
      _QA('فحص GOSI', Icons.health_and_safety, core_theme.AC.info),
      _QA('تعليمات الشركة', Icons.menu_book, core_theme.AC.purple),
      _QA('قائمة الزملاء', Icons.people, core_theme.AC.err),
    ];
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: a.color.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: a.color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(a.icon, color: a.color, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(a.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLeaves() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: Color(0xFF1A237E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('أرصدة الإجازات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
              TextButton(onPressed: () {}, child: Text('عرض الكل', style: TextStyle(fontSize: 11))),
            ],
          ),
          const SizedBox(height: 10),
          _leaveBalance('سنوية', 22, 6, core_theme.AC.info),
          _leaveBalance('مرضية', 30, 3, core_theme.AC.warn),
          _leaveBalance('اضطرارية', 5, 0, core_theme.AC.purple),
          const SizedBox(height: 10),
          Text('الطلبات المعلّقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _leaveRequest('LVE-2026-012', 'إجازة سنوية', '2026-05-15 إلى 2026-05-25', 'بانتظار الاعتماد', core_theme.AC.warn),
          _leaveRequest('LVE-2026-008', 'إجازة مرضية', '2026-04-20 (يوم واحد)', 'معتمد', core_theme.AC.ok),
        ],
      ),
    );
  }

  Widget _leaveBalance(String type, int entitled, int used, Color color) {
    final remaining = entitled - used;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(type, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: used / entitled,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text('$remaining / $entitled يوم',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveRequest(String id, String type, String dates, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$type · $dates', style: const TextStyle(fontSize: 11)),
                Text(id, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
            child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslips() {
    final slips = const [
      _Payslip('أبريل 2026', 22000, 4500, 1980, 150, 24370, 'متاح'),
      _Payslip('مارس 2026', 22000, 4500, 1980, 500, 24020, 'متاح'),
      _Payslip('فبراير 2026', 22000, 4500, 1980, 0, 24520, 'متاح'),
      _Payslip('يناير 2026', 22000, 4500, 1980, 200, 24320, 'متاح'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments, color: core_theme.AC.gold),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('قسائم الراتب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 14),
                label: Text('كلها', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFE6C200)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صافي راتب أبريل', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                Text('24,370 ر.س',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Text('تحويل مجدول: 2026-05-01',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final s in slips)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.navy3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, size: 14, color: core_theme.AC.ts),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s.month, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Text('${_fmt(s.net.toDouble())} ر.س',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.download, size: 16, color: core_theme.AC.gold),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCertificates() {
    final certs = const [
      _Cert('شهادة راتب', 'آخر إصدار: 2026-04-01', true),
      _Cert('شهادة تعريف', 'آخر إصدار: 2026-03-15', true),
      _Cert('شهادة عدم ممانعة', 'لم تُصدر', false),
      _Cert('بيان إقامة', 'آخر إصدار: 2026-02-20', true),
      _Cert('شهادة نهاية خدمة', 'لم تُطلب', false),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: core_theme.AC.ok),
              SizedBox(width: 8),
              Text('طلب شهادات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in certs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.navy3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(c.hasIssued ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: c.hasIssued ? core_theme.AC.ok : core_theme.AC.td, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(c.lastIssue, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.request_page, size: 12),
                    label: Text('طلب', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: core_theme.AC.ok,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 28),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeam() {
    final team = [
      _Teammate('سارة الدوسري', 'محاسبة أولى', 'متاحة', core_theme.AC.ok),
      _Teammate('محمد القحطاني', 'مدقق داخلي', 'في اجتماع', core_theme.AC.warn),
      _Teammate('نورة الغامدي', 'محللة ضرائب', 'متاحة', core_theme.AC.ok),
      _Teammate('فهد الشمري', 'محاسب', 'في إجازة', core_theme.AC.td),
      _Teammate('لينا البكري', 'مسؤولة موارد بشرية', 'متاحة', core_theme.AC.ok),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: core_theme.AC.err),
              SizedBox(width: 8),
              Text('فريقي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          for (final t in team)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.navy3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: core_theme.AC.err.withOpacity(0.15),
                        child: Text(t.name.substring(0, 1),
                            style: TextStyle(color: core_theme.AC.err, fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: t.statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(t.role, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                  Text(t.status,
                      style: TextStyle(fontSize: 10, color: t.statusColor, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.chat, size: 14, color: core_theme.AC.err),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _EmpProfile {
  final String id;
  final String name;
  final String title;
  final String email;
  final String phone;
  final String joinDate;
  final int salary;
  final int allowances;
  final String role;
  const _EmpProfile(this.id, this.name, this.title, this.email, this.phone, this.joinDate, this.salary, this.allowances, this.role);
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  const _QA(this.label, this.icon, this.color);
}

class _Payslip {
  final String month;
  final int basic;
  final int allowances;
  final int deductions;
  final int other;
  final int net;
  final String status;
  const _Payslip(this.month, this.basic, this.allowances, this.deductions, this.other, this.net, this.status);
}

class _Cert {
  final String name;
  final String lastIssue;
  final bool hasIssued;
  const _Cert(this.name, this.lastIssue, this.hasIssued);
}

class _Teammate {
  final String name;
  final String role;
  final String status;
  final Color statusColor;
  const _Teammate(this.name, this.role, this.status, this.statusColor);
}
