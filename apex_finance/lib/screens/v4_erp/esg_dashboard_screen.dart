/// APEX Wave 77 — ESG / Sustainability Dashboard.
/// Route: /app/erp/finance/esg
///
/// Environment, Social, Governance metrics aligned with
/// Saudi Vision 2030 + GRI + SASB standards.
library;

import 'package:flutter/material.dart';

class EsgDashboardScreen extends StatefulWidget {
  const EsgDashboardScreen({super.key});
  @override
  State<EsgDashboardScreen> createState() => _EsgDashboardScreenState();
}

class _EsgDashboardScreenState extends State<EsgDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

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
        _buildOverallScore(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF2E7D32),
          tabs: const [
            Tab(icon: Icon(Icons.eco, size: 16), text: 'البيئة'),
            Tab(icon: Icon(Icons.people, size: 16), text: 'الاجتماعية'),
            Tab(icon: Icon(Icons.account_balance, size: 16), text: 'الحوكمة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildEnvironmentTab(),
              _buildSocialTab(),
              _buildGovernanceTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF388E3C)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.eco, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الاستدامة والحوكمة (ESG) 🌱',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('متوافق مع رؤية 2030 · GRI Standards · SASB · CDP',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScore() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _scoreCard('النتيجة الإجمالية', 'A-', 78, const Color(0xFFD4AF37), 'من أفضل 15%'),
          _scoreCard('البيئة (E)', 'B+', 72, Colors.green, '+5pt YoY'),
          _scoreCard('الاجتماعية (S)', 'A', 85, Colors.blue, 'ممتاز'),
          _scoreCard('الحوكمة (G)', 'A', 82, Colors.purple, '+8pt YoY'),
        ],
      ),
    );
  }

  Widget _scoreCard(String label, String grade, int score, Color color, String note) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(grade,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$score', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                      const Text('/100', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                  Text(note, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('🌍 الأثر البيئي',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric('انبعاثات CO₂', '1,240', 'طن/سنة', '-12% YoY', Colors.green, Icons.cloud),
            _metric('الطاقة المتجددة', '42%', 'من الاستهلاك', '+8pt YoY', Colors.amber, Icons.solar_power),
            _metric('استهلاك المياه', '8,450', 'm³/سنة', '-18% YoY', Colors.blue, Icons.water_drop),
            _metric('نسبة التدوير', '68%', 'من النفايات', '+5pt YoY', Colors.teal, Icons.recycling),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          'أهداف بيئية 2030',
          Colors.green,
          Icons.flag,
          [
            _goal('صفر انبعاثات صافية (Net Zero)', 32, 2030),
            _goal('100% طاقة متجددة', 42, 2028),
            _goal('تقليل استهلاك المياه 50%', 61, 2027),
            _goal('صفر نفايات للمكب (Zero Waste)', 68, 2029),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          'مبادرات جارية',
          Colors.blue,
          Icons.check_circle,
          [
            _initiative('تركيب ألواح شمسية على المقر الرئيسي', 'مكتمل', Colors.green, 'إنتاج 1.2 MW — يوفّر 185K ر.س/سنة'),
            _initiative('برنامج Work From Home 2 أيام/أسبوع', 'مكتمل', Colors.green, 'تقليل انبعاثات النقل 24%'),
            _initiative('استبدال الأسطول بسيارات كهربائية', 'قيد التنفيذ', Colors.orange, '8 من 15 — يكتمل Q3 2026'),
            _initiative('نظام جمع مياه الأمطار', 'مخطّط', Colors.blue, 'ميزانية معتمدة 320K ر.س'),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('👥 الأثر الاجتماعي',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric('نسبة السعودة', '72%', 'من الموظفين', '+6pt YoY', Colors.green, Icons.flag),
            _metric('تمثيل المرأة', '38%', 'من القوى العاملة', '+4pt YoY', Colors.purple, Icons.female),
            _metric('رضا الموظفين', '4.6/5', 'eNPS: 62', '+0.3 YoY', Colors.blue, Icons.thumb_up),
            _metric('حوادث السلامة', '0', 'LTIR', '12 شهر بدون حوادث', Colors.teal, Icons.shield),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          'التنوع والمساواة (D&I)',
          Colors.purple,
          Icons.diversity_3,
          [
            _diversityRow('الجنسيات', '24 جنسية', '+3'),
            _diversityRow('أعضاء مجلس الإدارة — تمثيل نسائي', '40%', '+12pt'),
            _diversityRow('فرص توظيف لذوي الاحتياجات الخاصة', '6% من الموظفين', '+2pt'),
            _diversityRow('فجوة الأجور بين الجنسين', '< 3%', 'هدف < 5%'),
            _diversityRow('ساعات التدريب السنوية', '48 ساعة/موظف', '+8 ساعات'),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          'الاستثمار المجتمعي',
          Colors.orange,
          Icons.volunteer_activism,
          [
            _initiative('برنامج تدريب خريجي الجامعات', 'سنوي', Colors.green, '85 خريج/سنة + فرص توظيف'),
            _initiative('رعاية مدارس التقنية للبنات', 'مستمر', Colors.green, '2.4M ر.س/سنة + أجهزة'),
            _initiative('تطوع الموظفين — 40 ساعة/سنة', 'مستمر', Colors.green, 'المشاركة 68% من الموظفين'),
            _initiative('زكاة الشركة والعطاء', 'سنوي', Colors.green, '3.8M ر.س لعام 2025'),
          ],
        ),
      ],
    );
  }

  Widget _buildGovernanceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('🏛️ الحوكمة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric('أعضاء المجلس المستقلون', '5 من 9', '56%', '+12pt YoY', Colors.purple, Icons.gavel),
            _metric('اجتماعات المجلس', '12/سنة', 'حضور 96%', 'أعلى من المتطلب', Colors.blue, Icons.meeting_room),
            _metric('حالات عدم الامتثال', '0', 'في 18 شهر', 'سجل نظيف', Colors.green, Icons.verified),
            _metric('درجة Simah Corporate', 'AA-', 'تصنيف ائتماني', '+1 رتبة', Colors.teal, Icons.star),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          'هيكل الحوكمة',
          Colors.purple,
          Icons.account_tree,
          [
            _govRow('مجلس الإدارة', '9 أعضاء — 5 مستقلون'),
            _govRow('لجنة المراجعة', '3 أعضاء — كلّهم مستقلون — مالي معتمد'),
            _govRow('لجنة المخاطر', '3 أعضاء — أغلبية مستقلة'),
            _govRow('لجنة الحوكمة', '3 أعضاء'),
            _govRow('لجنة المكافآت والترشيحات', '3 أعضاء — كلّهم مستقلون'),
            _govRow('لجنة الاستثمار', '4 أعضاء'),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          'السياسات المعتمدة',
          Colors.indigo,
          Icons.policy,
          [
            _policyRow('ميثاق السلوك الأخلاقي', true, '2026-01'),
            _policyRow('سياسة مكافحة الفساد', true, '2026-01'),
            _policyRow('سياسة تضارب المصالح', true, '2026-01'),
            _policyRow('سياسة الإفصاح والشفافية', true, '2026-01'),
            _policyRow('برنامج المبلّغ عن المخالفات (Whistleblower)', true, '2025-12'),
            _policyRow('سياسة خصوصية البيانات', true, '2026-03'),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          'إفصاحات وتقارير',
          const Color(0xFFD4AF37),
          Icons.description,
          [
            _initiative('التقرير السنوي ESG 2025', 'منشور', Colors.green, 'GRI Core + SASB — 84 صفحة'),
            _initiative('إفصاح TCFD', 'منشور', Colors.green, 'مخاطر المناخ — معيار FSB'),
            _initiative('تقرير CDP Climate', 'قيد الإعداد', Colors.orange, 'تقديم 2026-07'),
            _initiative('مؤشر MSCI ESG', 'BBB', Colors.blue, 'هدف A خلال 2026'),
          ],
        ),
      ],
    );
  }

  Widget _metric(String label, String value, String unit, String trend, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(unit, style: const TextStyle(fontSize: 10, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(trend,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: trend.startsWith('+') || trend.startsWith('-') && trend.contains('YoY')
                        ? Colors.green
                        : color)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, Color color, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _goal(String name, int progress, int year) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('هدف $year', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                        progress >= 70 ? Colors.green : progress >= 40 ? Colors.orange : Colors.red),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Text('$progress%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: progress >= 70 ? Colors.green : progress >= 40 ? Colors.orange : Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initiative(String name, String status, Color color, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
            child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(detail, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diversityRow(String label, String value, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(note, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _govRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.purple),
          const SizedBox(width: 8),
          SizedBox(width: 200, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _policyRow(String name, bool approved, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(approved ? Icons.check_circle : Icons.warning,
              size: 16, color: approved ? Colors.green : Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
          Text('معتمد $date',
              style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
