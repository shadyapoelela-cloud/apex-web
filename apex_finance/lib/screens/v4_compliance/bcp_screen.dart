/// APEX Wave 97 — Business Continuity & Disaster Recovery.
/// Route: /app/compliance/regulatory/bcp
///
/// BCP/DR plans, RTOs, RPOs, scenarios, test history.
library;

import 'package:flutter/material.dart';

class BcpScreen extends StatefulWidget {
  const BcpScreen({super.key});
  @override
  State<BcpScreen> createState() => _BcpScreenState();
}

class _BcpScreenState extends State<BcpScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _scenarios = const [
    _Scenario('SCN-001', 'انقطاع كامل لمركز البيانات الرئيسي', 'IT', 'high', 4, 1, 'Hot standby في AWS + DNS failover تلقائي', 'مكتمل — آخر اختبار 2026-02-15', Colors.red),
    _Scenario('SCN-002', 'هجوم Ransomware', 'Cyber', 'critical', 8, 2, 'عزل الشبكات + نسخ احتياطي غير متصل + استعادة من snapshot', 'اختبار سنوي — 2025-11-20', Colors.red),
    _Scenario('SCN-003', 'فقدان الكهرباء في المبنى', 'Facility', 'medium', 2, 0, 'UPS + مولّد احتياطي 48 ساعة', 'اختبار نصف سنوي', Colors.orange),
    _Scenario('SCN-004', 'جائحة / وباء', 'People', 'high', 24, 0, 'خطة عمل عن بُعد لـ 100% من الموظفين', 'تم التفعيل 2020 — مستمر', Colors.orange),
    _Scenario('SCN-005', 'انقطاع الإنترنت', 'Network', 'medium', 1, 0, 'مزوّدين اثنين + 5G failover', 'اختبار شهري', Colors.blue),
    _Scenario('SCN-006', 'كارثة طبيعية (زلزال/فيضان)', 'Facility', 'low', 72, 24, 'موقع احتياطي في جدة + نسخ عن بُعد', 'محاكاة سنوية', Colors.green),
    _Scenario('SCN-007', 'فقدان موظف مفتاح مفاجئ', 'People', 'medium', 48, 0, 'خطط التعاقب Succession Plan موثقة', 'مراجعة ربعية', Colors.orange),
    _Scenario('SCN-008', 'عطل رئيسي في مزود ERP (SAP)', 'Vendor', 'high', 6, 2, 'عقد SLA + مستشار SAP مستقل + نسخة محلية', 'اختبار سنوي', Colors.red),
  ];

  final _sites = const [
    _Site('المركز الرئيسي — الرياض', 'primary', 'active', '99.98%', 'تشغيل كامل · 380 موظف', Colors.green),
    _Site('موقع DR — جدة', 'dr', 'hot-standby', '99.95%', 'جاهز للتفعيل · تزامن مستمر', Colors.blue),
    _Site('سحابة AWS — الفرنكفورت', 'cloud-dr', 'active', '99.99%', 'تشغيل جزئي · DB replica', Colors.orange),
    _Site('منازل الموظفين (VDI)', 'remote', 'active', '99.5%', '285 مستخدم متصل', Colors.purple),
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
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.event, size: 16), text: 'السيناريوهات'),
            Tab(icon: Icon(Icons.location_on, size: 16), text: 'المواقع البديلة'),
            Tab(icon: Icon(Icons.history, size: 16), text: 'سجل الاختبارات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildScenariosTab(),
              _buildSitesTab(),
              _buildTestsTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.health_and_safety, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('استمرارية الأعمال والتعافي من الكوارث',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('BCP / DR — ISO 22301 · سيناريوهات · RTO/RPO · اختبارات دورية',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final critical = _scenarios.where((s) => s.severity == 'critical').length;
    final high = _scenarios.where((s) => s.severity == 'high').length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('سيناريوهات موثّقة', '${_scenarios.length}', Colors.blue, Icons.list),
          _kpi('حرجة', '$critical', Colors.red, Icons.error),
          _kpi('عالية', '$high', Colors.orange, Icons.warning),
          _kpi('Max RTO', '72 ساعة', const Color(0xFFD4AF37), Icons.schedule),
          _kpi('جاهزية BCP', '96%', Colors.green, Icons.verified),
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenariosTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _scenarios.length,
      itemBuilder: (ctx, i) {
        final s = _scenarios[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: s.color.withOpacity(0.3), width: s.severity == 'critical' ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(_categoryIcon(s.category), color: s.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(s.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                              child: Text(_severityLabel(s.severity),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
                              child: Text(_categoryLabel(s.category),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          children: [
                            const Text('RTO', style: TextStyle(fontSize: 9, color: Colors.black54)),
                            Text('${s.rto}h',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          children: [
                            const Text('RPO', style: TextStyle(fontSize: 9, color: Colors.black54)),
                            Text('${s.rpo}h',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 6),
                    const Text('خطة التعافي: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    Expanded(child: Text(s.recoveryPlan, style: const TextStyle(fontSize: 12, height: 1.5))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.verified, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(s.testStatus,
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSitesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _sites.length,
      itemBuilder: (ctx, i) {
        final s = _sites[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: s.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(_siteIcon(s.type), color: s.color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(_siteTypeLabel(s.type),
                              style: TextStyle(fontSize: 10, color: s.color, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(s.availability,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: s.color, fontFamily: 'monospace')),
                  const Text('Availability', style: TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestsTab() {
    final tests = const [
      _Test('TST-2026-004', 'محاكاة انقطاع Data Center', '2026-02-15', 'passed', 'RTO محقق في 3.5h (الهدف 4h)', 96),
      _Test('TST-2026-003', 'اختبار استعادة النسخ الاحتياطية', '2026-01-28', 'passed', '100% من البيانات تعافت بنجاح', 100),
      _Test('TST-2026-002', 'محاكاة Ransomware', '2026-01-12', 'passed-with-notes', 'استغرق 7.5h (الهدف 8h) — بعض النسخ تطلبت إعادة', 88),
      _Test('TST-2026-001', 'اختبار المولد الاحتياطي', '2026-01-05', 'passed', '48 ساعة تشغيل متواصل', 100),
      _Test('TST-2025-012', 'اختبار Work From Home للجميع', '2025-12-18', 'passed', '100% من الموظفين نجحوا في الاتصال', 100),
      _Test('TST-2025-011', 'محاكاة فشل SAP', '2025-11-20', 'failed', 'تعذّرت الاستعادة في 6 ساعات — تم التحسين', 55),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tests.length,
      itemBuilder: (ctx, i) {
        final t = tests[i];
        final color = _testResultColor(t.result);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(_testResultIcon(t.result), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
                        const SizedBox(width: 8),
                        Text(t.date, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                      ],
                    ),
                    Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(t.notes, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('${t.score}%',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                    child: Text(_testResultLabel(t.result),
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String c) {
    switch (c) {
      case 'IT':
        return Icons.computer;
      case 'Cyber':
        return Icons.security;
      case 'Facility':
        return Icons.home_work;
      case 'People':
        return Icons.people;
      case 'Network':
        return Icons.wifi;
      case 'Vendor':
        return Icons.business;
      default:
        return Icons.warning;
    }
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'IT':
        return 'تقنية';
      case 'Cyber':
        return 'سيبراني';
      case 'Facility':
        return 'منشأة';
      case 'People':
        return 'بشري';
      case 'Network':
        return 'شبكة';
      case 'Vendor':
        return 'مزود';
      default:
        return c;
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

  IconData _siteIcon(String t) {
    switch (t) {
      case 'primary':
        return Icons.home_work;
      case 'dr':
        return Icons.location_city;
      case 'cloud-dr':
        return Icons.cloud;
      case 'remote':
        return Icons.home;
      default:
        return Icons.location_on;
    }
  }

  String _siteTypeLabel(String t) {
    switch (t) {
      case 'primary':
        return 'رئيسي';
      case 'dr':
        return 'احتياطي بارد';
      case 'cloud-dr':
        return 'سحابي';
      case 'remote':
        return 'عن بُعد';
      default:
        return t;
    }
  }

  Color _testResultColor(String r) {
    switch (r) {
      case 'passed':
        return Colors.green;
      case 'passed-with-notes':
        return Colors.amber.shade700;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _testResultIcon(String r) {
    switch (r) {
      case 'passed':
        return Icons.check_circle;
      case 'passed-with-notes':
        return Icons.warning;
      case 'failed':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _testResultLabel(String r) {
    switch (r) {
      case 'passed':
        return 'نجح';
      case 'passed-with-notes':
        return 'نجح مع ملاحظات';
      case 'failed':
        return 'فشل';
      default:
        return r;
    }
  }
}

class _Scenario {
  final String id;
  final String title;
  final String category;
  final String severity;
  final int rto;
  final int rpo;
  final String recoveryPlan;
  final String testStatus;
  final Color color;
  const _Scenario(this.id, this.title, this.category, this.severity, this.rto, this.rpo, this.recoveryPlan, this.testStatus, this.color);
}

class _Site {
  final String name;
  final String type;
  final String status;
  final String availability;
  final String description;
  final Color color;
  const _Site(this.name, this.type, this.status, this.availability, this.description, this.color);
}

class _Test {
  final String id;
  final String name;
  final String date;
  final String result;
  final String notes;
  final int score;
  const _Test(this.id, this.name, this.date, this.result, this.notes, this.score);
}
