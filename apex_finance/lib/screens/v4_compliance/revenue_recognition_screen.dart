import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 105 — Revenue Recognition (IFRS 15)
/// 5-step revenue recognition model with contract management
class RevenueRecognitionScreen extends StatefulWidget {
  const RevenueRecognitionScreen({super.key});

  @override
  State<RevenueRecognitionScreen> createState() => _RevenueRecognitionScreenState();
}

class _RevenueRecognitionScreenState extends State<RevenueRecognitionScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: Column(
            children: [
              _buildHero(),
              _buildKpis(),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tc,
                  labelColor: const Color(0xFF4A148C),
                  unselectedLabelColor: core_theme.AC.ts,
                  indicatorColor: core_theme.AC.gold,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'العقود'),
                    Tab(text: 'الخطوات الخمس'),
                    Tab(text: 'الاعتراف بالإيراد'),
                    Tab(text: 'التحليلات'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tc,
                  children: [
                    _buildContractsTab(),
                    _buildFiveStepsTab(),
                    _buildRecognitionTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: core_theme.AC.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الاعتراف بالإيراد — IFRS 15',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'نموذج الخطوات الخمس للاعتراف بالإيرادات من العقود مع العملاء',
                  style: TextStyle(color: core_theme.AC.ts, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: core_theme.AC.gold, size: 16),
                SizedBox(width: 4),
                Text('متوافق IFRS 15', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final totalContracts = _contracts.length;
    final totalValue = _contracts.fold<double>(0, (s, c) => s + c.totalValue);
    final recognized = _contracts.fold<double>(0, (s, c) => s + c.recognized);
    final deferred = totalValue - recognized;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _kpi('العقود النشطة', '$totalContracts', Icons.description, const Color(0xFF1A237E))),
          Expanded(child: _kpi('إجمالي القيمة', _fmtM(totalValue), Icons.attach_money, core_theme.AC.gold)),
          Expanded(child: _kpi('معترف به', _fmtM(recognized), Icons.check_circle, const Color(0xFF2E7D32))),
          Expanded(child: _kpi('مؤجل', _fmtM(deferred), Icons.schedule, const Color(0xFFE65100))),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _contracts.length,
      itemBuilder: (context, i) {
        final c = _contracts[i];
        final progress = c.recognized / c.totalValue;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Color(0xFF4A148C)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(c.id, style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(c.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c.status,
                        style: TextStyle(color: _statusColor(c.status), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(c.description, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat('القيمة', _fmt(c.totalValue)),
                    _miniStat('معترف', _fmt(c.recognized)),
                    _miniStat('التزامات', '${c.obligations}'),
                    _miniStat('النوع', c.recognitionType),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: core_theme.AC.bdr,
                    valueColor: AlwaysStoppedAnimation(core_theme.AC.gold),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${(progress * 100).toStringAsFixed(1)}% معترف به',
                    style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFiveStepsTab() {
    final steps = [
      ('1', 'تحديد العقد', 'تحديد وجود عقد قابل للتنفيذ مع العميل',
          'العقد المعتمد + الحقوق والالتزامات واضحة + شروط الدفع محددة', const Color(0xFF1A237E)),
      ('2', 'تحديد التزامات الأداء', 'تحديد السلع/الخدمات المميزة في العقد',
          'التمييز بين الالتزامات المنفصلة والمجمعة', const Color(0xFF4A148C)),
      ('3', 'تحديد سعر المعاملة', 'حساب المبلغ المتوقع استلامه مقابل نقل السلع',
          'يشمل المقابل المتغير + قيمة الوقت + المقابل غير النقدي', core_theme.AC.gold),
      ('4', 'توزيع السعر', 'توزيع سعر المعاملة على التزامات الأداء',
          'بناءً على أسعار البيع المستقلة (SSP)', const Color(0xFF2E7D32)),
      ('5', 'الاعتراف بالإيراد', 'الاعتراف عند/خلال الوفاء بالتزامات الأداء',
          'نقطة زمنية أو على مدى الوقت حسب نقل السيطرة', const Color(0xFFE65100)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: steps.length,
      itemBuilder: (context, i) {
        final (num, title, desc, detail, color) = steps[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(num,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(height: 4),
                      Text(desc, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(detail, style: TextStyle(fontSize: 11.5, color: core_theme.AC.tp)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecognitionTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              child: const Icon(Icons.trending_up, color: Color(0xFF2E7D32)),
            ),
            title: Text(e.contract, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.period} • ${e.method}', style: const TextStyle(fontSize: 12)),
                Text('التزام: ${e.obligation}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(e.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                Text(e.date, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _insight('📈 معدل النمو', '18.4% نمو سنوي في الإيرادات المعترف بها', const Color(0xFF2E7D32)),
        _insight('⏰ تحت الاعتراف', '2.8M ريال مؤجلة للفترات القادمة', const Color(0xFFE65100)),
        _insight('🎯 الدقة', '99.2% دقة في تطبيق IFRS 15 (نقطة زمنية vs على مدى)', const Color(0xFF1A237E)),
        _insight('📊 توزيع الأنواع', '65% على مدى الوقت • 35% نقطة زمنية', const Color(0xFF4A148C)),
        _insight('⚠️ تنبيه', '3 عقود تحتاج إعادة تقييم لالتزامات الأداء', const Color(0xFFC62828)),
        _insight('✅ الامتثال', 'مراجعة سنوية IFRS 15 مكتملة — لا ملاحظات', const Color(0xFF2E7D32)),
      ],
    );
  }

  Widget _insight(String title, String text, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 6),
            Text(text, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('معلق')) return const Color(0xFFE65100);
    if (s.contains('مكتمل')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  String _fmt(double v) => '${v.toStringAsFixed(0)} ر.س';
  String _fmtM(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  static const List<_Contract> _contracts = [
    _Contract('CNT-2026-001', 'شركة الاتصالات السعودية', 'عقد خدمات SaaS سنوي — منصة متكاملة',
        5_400_000, 3_200_000, 4, 'على مدى الوقت', 'نشط'),
    _Contract('CNT-2026-002', 'بنك الراجحي', 'تطوير + صيانة نظام مصرفي',
        12_800_000, 8_100_000, 3, 'على مدى الوقت', 'نشط'),
    _Contract('CNT-2026-003', 'أرامكو السعودية', 'ترخيص برنامج + خدمات استشارية',
        8_900_000, 8_900_000, 2, 'نقطة زمنية', 'مكتمل'),
    _Contract('CNT-2026-004', 'سابك', 'تنفيذ ERP — 18 شهر',
        15_600_000, 6_240_000, 5, 'على مدى الوقت', 'نشط'),
    _Contract('CNT-2026-005', 'stc', 'خدمات سحابية + دعم 24/7',
        3_200_000, 1_600_000, 2, 'على مدى الوقت', 'نشط'),
    _Contract('CNT-2026-006', 'مجموعة سامبا', 'ترخيص + تدريب — إعادة تقييم',
        2_100_000, 0, 3, 'نقطة زمنية', 'معلق'),
  ];

  static const List<_RecognitionEntry> _entries = [
    _RecognitionEntry('CNT-2026-001', 'يناير 2026', 'خدمات SaaS شهرية', 450_000, 'على مدى الوقت', '2026-01-31'),
    _RecognitionEntry('CNT-2026-002', 'يناير 2026', 'تطوير مرحلة 2', 2_700_000, 'على مدى الوقت', '2026-01-31'),
    _RecognitionEntry('CNT-2026-003', 'فبراير 2026', 'تسليم ترخيص نهائي', 6_400_000, 'نقطة زمنية', '2026-02-15'),
    _RecognitionEntry('CNT-2026-004', 'فبراير 2026', 'تنفيذ وحدة المالية', 2_080_000, 'على مدى الوقت', '2026-02-28'),
    _RecognitionEntry('CNT-2026-001', 'فبراير 2026', 'خدمات SaaS شهرية', 450_000, 'على مدى الوقت', '2026-02-28'),
    _RecognitionEntry('CNT-2026-005', 'مارس 2026', 'خدمات سحابية', 320_000, 'على مدى الوقت', '2026-03-31'),
    _RecognitionEntry('CNT-2026-004', 'مارس 2026', 'تنفيذ وحدة الموارد البشرية', 1_560_000, 'على مدى الوقت', '2026-03-31'),
    _RecognitionEntry('CNT-2026-002', 'مارس 2026', 'صيانة ودعم', 1_350_000, 'على مدى الوقت', '2026-03-31'),
  ];
}

class _Contract {
  final String id;
  final String customer;
  final String description;
  final double totalValue;
  final double recognized;
  final int obligations;
  final String recognitionType;
  final String status;
  const _Contract(this.id, this.customer, this.description, this.totalValue, this.recognized,
      this.obligations, this.recognitionType, this.status);
}

class _RecognitionEntry {
  final String contract;
  final String period;
  final String obligation;
  final double amount;
  final String method;
  final String date;
  const _RecognitionEntry(this.contract, this.period, this.obligation, this.amount, this.method, this.date);
}
