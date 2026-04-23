/// APEX Wave 56 — Audit Engagement Acceptance.
/// Route: /app/audit/engagement/acceptance
///
/// ISA 220, ISA 210 + SOCPA — client acceptance,
/// independence, conflict of interest, engagement letter.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class AuditAcceptanceScreen extends StatefulWidget {
  const AuditAcceptanceScreen({super.key});
  @override
  State<AuditAcceptanceScreen> createState() => _AuditAcceptanceScreenState();
}

class _AuditAcceptanceScreenState extends State<AuditAcceptanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _integrityChecks = <_Check>[
    _Check('1', 'خلفية إدارة الشركة وسمعتها', 'pass', 'لم تُسجّل أي دعاوى قضائية أو عقوبات تنظيمية'),
    _Check('2', 'الالتزامات المصرفية والضريبية', 'pass', 'لا توجد متأخرات لدى البنوك أو ZATCA أو GOSI'),
    _Check('3', 'عمليات غير اعتيادية', 'review', 'لوحظت معاملات ذات علاقة بحجم كبير — تحتاج مراجعة'),
    _Check('4', 'تاريخ التغيير في المراجعين', 'pass', 'المراجع السابق غادر لأسباب تقنية — تواصلنا مكتوب'),
    _Check('5', 'جودة التقارير المالية السابقة', 'pass', 'القوائم لعام 2024 نظيفة بدون تحفظات'),
  ];

  final _independenceChecks = <_IndCheck>[
    _IndCheck('المصالح المالية', 'لا يمتلك أي شريك أو موظف في الارتباط أسهماً أو التزامات مع العميل', true),
    _IndCheck('الروابط الوظيفية', 'لم يعمل أي شريك لدى العميل في السنوات الخمس الماضية', true),
    _IndCheck('الخدمات غير التوكيدية', 'لا نقدّم خدمات مسك دفاتر أو تقييمات ضخمة تتعارض مع المراجعة', true),
    _IndCheck('العلاقات الشخصية', 'لا علاقات قرابة من الدرجة الأولى مع الإدارة العليا', true),
    _IndCheck('الرسوم المشروطة', 'لا رسوم قائمة على نتائج الاعتماد', true),
    _IndCheck('تركّز العميل', 'العميل يمثّل 6.2% من إيراداتنا — تحت حد 10% الحرج', true),
  ];

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
        _buildStatusBanner(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF4A148C),
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.verified_user, size: 16), text: 'الاستقلالية'),
            Tab(icon: Icon(Icons.fact_check, size: 16), text: 'قبول العميل'),
            Tab(icon: Icon(Icons.description, size: 16), text: 'خطاب الارتباط'),
            Tab(icon: Icon(Icons.check_circle, size: 16), text: 'القرار النهائي'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildIndependenceTab(),
              _buildAcceptanceTab(),
              _buildEngagementLetterTab(),
              _buildDecisionTab(),
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
      child: Row(
        children: [
          Icon(Icons.handshake, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('قبول الارتباط — NEOM Company',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('ISA 220 · ISA 210 · SOCPA — فحص استقلالية وقبول عميل جديد',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _pill('عميل جديد', core_theme.AC.info, Icons.new_releases),
          _pill('شركة مساهمة مدرجة', core_theme.AC.purple, Icons.business),
          _pill('القيمة المتوقعة: 2.4M ر.س', core_theme.AC.gold, Icons.attach_money),
          const Spacer(),
          _pill('فترة المراجعة: 2025', core_theme.AC.info, Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildIndependenceTab() {
    final passed = _independenceChecks.where((c) => c.passed).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [core_theme.AC.ok, core_theme.AC.ok]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('فحص الاستقلالية',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    Text('$passed / ${_independenceChecks.length} بنود مجتازة',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('مستقل ✓',
                    style: TextStyle(color: core_theme.AC.ok, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('المعايير وفق ميثاق الأخلاقيات (IESBA Code)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final c in _independenceChecks)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.bdr),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: core_theme.AC.ok.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, color: core_theme.AC.ok, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(c.description, style: TextStyle(fontSize: 12, color: core_theme.AC.ts, height: 1.5)),
                    ],
                  ),
                ),
                Switch(
                  value: c.passed,
                  activeColor: core_theme.AC.ok,
                  onChanged: (v) => setState(() => c.passed = v),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: core_theme.AC.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إن تبيّنت أي مخاوف، يجب توثيقها في سجل الاستقلالية وتطبيق إجراءات حماية (Safeguards) قبل قبول الارتباط.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptanceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('فحص نزاهة الإدارة والمخاطر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final c in _integrityChecks)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _checkColor(c.status).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _checkColor(c.status).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(c.number,
                        style: TextStyle(color: _checkColor(c.status), fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(c.description, style: TextStyle(fontSize: 12, color: core_theme.AC.ts, height: 1.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _checkColor(c.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_statusLabel(c.status),
                      style: TextStyle(fontSize: 11, color: _checkColor(c.status), fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الاستفسار من المراجع السابق', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _kv('اسم المكتب السابق', 'PwC الشرق الأوسط'),
              _kv('تاريخ آخر مراجعة', '2023-12-31'),
              _kv('نوع التقرير', 'رأي غير متحفظ (Unqualified)'),
              _kv('سبب التغيير', 'تغيير استراتيجي في قائمة المكاتب المعتمدة من هيئة السوق المالية'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: core_theme.AC.ok,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: core_theme.AC.ok),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: core_theme.AC.ok, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تمّ الحصول على موافقة كتابية من PwC على عدم وجود أي أمور جوهرية',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Icon(Icons.attach_file, size: 18, color: core_theme.AC.ok),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementLetterTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.description, color: Color(0xFF4A148C)),
                  SizedBox(width: 8),
                  Text('خطاب الارتباط (ISA 210)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 14),
              Text('البنود المطلوبة للإدراج:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _letterItem('هدف ونطاق المراجعة', 'مراجعة القوائم المالية للسنة المنتهية في 31/12/2025 وفق المعايير الدولية'),
              _letterItem('مسؤوليات المراجع', 'إبداء رأي محايد على القوائم بموجب ISA'),
              _letterItem('مسؤوليات الإدارة', 'إعداد القوائم، الرقابة الداخلية، الإفصاح الكامل'),
              _letterItem('الإطار المحاسبي المعتمد', 'المعايير الدولية (IFRS) كما اعتمدتها المملكة'),
              _letterItem('الأتعاب وشروط الدفع', '2,400,000 ر.س · 40% عند التوقيع، 30% عند البدء، 30% عند التسليم'),
              _letterItem('تشكيل فريق المراجعة', 'شريك، مدير، 4 مراجعين، 2 متخصص IT، متخصص ضرائب'),
              _letterItem('حدود المسؤولية', 'طبقاً للمادة 32 من نظام المحاسبين القانونيين'),
              _letterItem('سرية المعلومات', 'جميع المعلومات سرية ولا تُفشى إلا بإذن كتابي'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.preview, size: 16),
                      label: Text('معاينة الخطاب'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.send, size: 16),
                      label: Text('إرسال للعميل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _letterItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_box, size: 16, color: Color(0xFF4A148C)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(detail, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF3D0F73)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, color: Colors.white, size: 30),
                  SizedBox(width: 10),
                  Text('قرار الشريك المسؤول',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              SizedBox(height: 20),
              Text('الشريك: د. عبدالله السهلي',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('تاريخ: 2026-04-19',
                  style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              SizedBox(height: 16),
              Text('ملخّص الفحص:',
                  style: TextStyle(color: core_theme.AC.ts, fontSize: 12, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('✓ الاستقلالية: 6/6 بنود متحققة',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.8)),
              Text('✓ قبول العميل: 4/5 بنود متحققة (1 يحتاج متابعة)',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.8)),
              Text('✓ استفسار من المراجع السابق: مكتمل بدون تحفظات',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.8)),
              Text('✓ خطاب الارتباط: جاهز للإرسال',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.8)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: core_theme.AC.ok,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: core_theme.AC.ok, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: core_theme.AC.ok, size: 48),
                    const SizedBox(height: 10),
                    Text('القبول مع إجراءات حماية',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.ok)),
                    const SizedBox(height: 8),
                    Text(
                      'تم فحص جميع المتطلبات — نوصي بالقبول مع متابعة المعاملات ذات العلاقة بشكل مفصل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمّ قبول الارتباط — ينتقل تلقائياً إلى مرحلة التخطيط'),
                              backgroundColor: core_theme.AC.ok,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: core_theme.AC.ok,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('قبول الارتباط'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: core_theme.AC.err,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: core_theme.AC.err),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cancel, color: core_theme.AC.err, size: 48),
                    const SizedBox(height: 10),
                    Text('رفض الارتباط',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.err)),
                    const SizedBox(height: 8),
                    Text(
                      'في حال وجود مخاوف جوهرية على الاستقلالية أو نزاهة العميل — يجب التوثيق الكامل للأسباب.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: core_theme.AC.err,
                          side: BorderSide(color: core_theme.AC.err),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('رفض مع التوثيق'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(k, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.5))),
        ],
      ),
    );
  }

  Color _checkColor(String status) {
    switch (status) {
      case 'pass':
        return core_theme.AC.ok;
      case 'review':
        return core_theme.AC.warn;
      case 'fail':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pass':
        return 'مجتاز';
      case 'review':
        return 'قيد المراجعة';
      case 'fail':
        return 'فشل';
      default:
        return status;
    }
  }
}

class _Check {
  final String number;
  final String title;
  final String status;
  final String description;
  const _Check(this.number, this.title, this.status, this.description);
}

class _IndCheck {
  final String category;
  final String description;
  bool passed;
  _IndCheck(this.category, this.description, this.passed);
}
