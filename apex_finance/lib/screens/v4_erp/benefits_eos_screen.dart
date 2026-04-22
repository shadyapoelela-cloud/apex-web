/// APEX Wave 53 — Employee Benefits & End-of-Service.
/// Route: /app/erp/hr/benefits
///
/// Health insurance, EOS gratuity, provident fund, loans.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class BenefitsEosScreen extends StatefulWidget {
  const BenefitsEosScreen({super.key});
  @override
  State<BenefitsEosScreen> createState() => _BenefitsEosScreenState();
}

class _BenefitsEosScreenState extends State<BenefitsEosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _selectedEmp = 'EMP-001';

  final _employees = const [
    _Emp('EMP-001', 'أحمد محمد العتيبي', 'سعودي', 22000, '2018-03-15', 'مدير مالي'),
    _Emp('EMP-002', 'سارة خالد الدوسري', 'سعودي', 14500, '2021-06-01', 'محاسبة أولى'),
    _Emp('EMP-003', 'محمد عبدالله القحطاني', 'سعودي', 17000, '2019-09-10', 'مدقق داخلي'),
    _Emp('EMP-004', 'راج كومار شارما', 'هندي', 12000, '2016-11-20', 'محلل ضرائب'),
    _Emp('EMP-005', 'فهد ناصر الشمري', 'سعودي', 9500, '2023-02-15', 'محاسب'),
    _Emp('EMP-006', 'لينا عادل البكري', 'سعودي', 11300, '2020-05-12', 'مسؤولة موارد بشرية'),
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

  _Emp get _emp => _employees.firstWhere((e) => e.id == _selectedEmp);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.medical_services, size: 16), text: 'التأمين الطبي'),
            Tab(icon: Icon(Icons.account_balance_wallet, size: 16), text: 'مكافأة نهاية الخدمة'),
            Tab(icon: Icon(Icons.savings, size: 16), text: 'صندوق الادخار'),
            Tab(icon: Icon(Icons.request_page, size: 16), text: 'السلف والقروض'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildInsuranceTab(),
              _buildEosTab(),
              _buildProvidentTab(),
              _buildLoansTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المزايا ونهاية الخدمة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('تأمين طبي، مكافأة نهاية الخدمة، صندوق ادخار، قروض — وفق نظام العمل السعودي',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedEmp,
              dropdownColor: const Color(0xFFE91E63),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: _employees
                  .map((e) => DropdownMenuItem(value: e.id, child: Text('${e.id} - ${e.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _selectedEmp = v ?? _selectedEmp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _empBanner(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _insuranceCard()),
            const SizedBox(width: 12),
            Expanded(child: _dependentsCard()),
          ],
        ),
        const SizedBox(height: 16),
        _claimsHistory(),
      ],
    );
  }

  Widget _empBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: core_theme.AC.gold.withOpacity(0.15),
            radius: 22,
            child: Icon(Icons.person, color: core_theme.AC.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_emp.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text('${_emp.id} · ${_emp.title} · ${_emp.nationality} · انضم ${_emp.joinDate}',
                    style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('الراتب الأساسي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${_fmt(_emp.salary.toDouble())} ر.س',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insuranceCard() {
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
              Icon(Icons.medical_services, color: core_theme.AC.err, size: 20),
              SizedBox(width: 8),
              Text('البوليصة الطبية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          _kv('شركة التأمين', 'بوبا العربية'),
          _kv('رقم البوليصة', 'BUPA-2026-${_emp.id.substring(4)}'),
          _kv('الفئة', 'VIP · تغطية شاملة'),
          _kv('الحد السنوي', '500,000 ر.س'),
          _kv('تاريخ البداية', '2026-01-01'),
          _kv('تاريخ الانتهاء', '2026-12-31'),
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
                Icon(Icons.check_circle, color: core_theme.AC.ok, size: 16),
                SizedBox(width: 6),
                Expanded(child: Text('البوليصة سارية — 258 يوم متبقي', style: TextStyle(fontSize: 11))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dependentsCard() {
    final deps = const [
      _Dep('زوجة', 'فاطمة سعد العتيبي', '1985', 'VIP'),
      _Dep('ابن', 'محمد أحمد العتيبي', '2012', 'VIP'),
      _Dep('ابنة', 'نورة أحمد العتيبي', '2015', 'VIP'),
      _Dep('ابن', 'سعد أحمد العتيبي', '2019', 'VIP'),
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
              Icon(Icons.family_restroom, color: core_theme.AC.info, size: 20),
              const SizedBox(width: 8),
              Text('المعالون (${4})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'إضافة',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final d in deps)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.navy3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: core_theme.AC.info.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(d.relation,
                        style: TextStyle(fontSize: 10, color: core_theme.AC.info, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Text('${DateTime.now().year - int.parse(d.birthYear)} سنة',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: core_theme.AC.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(d.class_,
                        style: TextStyle(fontSize: 10, color: core_theme.AC.gold, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _claimsHistory() {
    final claims = const [
      _Claim('2026-03-15', 'مستشفى الحبيب', 'علاج طبي', 4500, 'موافق'),
      _Claim('2026-02-28', 'مختبرات البرج', 'فحوصات مخبرية', 850, 'موافق'),
      _Claim('2026-02-10', 'مركز الأسنان المتخصص', 'علاج أسنان', 2300, 'قيد المراجعة'),
      _Claim('2026-01-20', 'صيدلية النهدي', 'أدوية', 450, 'موافق'),
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
          Text('سجل المطالبات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final c in claims)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.navy3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(c.date, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.provider, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Expanded(child: Text(c.type, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                  Text('${_fmt(c.amount.toDouble())} ر.س',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (c.status == 'موافق' ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(c.status,
                        style: TextStyle(
                          fontSize: 10,
                          color: c.status == 'موافق' ? core_theme.AC.ok : core_theme.AC.warn,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEosTab() {
    // Saudi Labor Law EOS calculation:
    // 1-5 years: 0.5 month for each year
    // 5+ years: full month for each additional year
    // If resignation and < 2 years: no EOS
    // If resignation 2-5: 1/3 of entitlement
    // If resignation 5-10: 2/3 of entitlement
    // If resignation 10+: full entitlement
    final joinDate = DateTime.parse(_emp.joinDate);
    final yearsOfService = DateTime.now().difference(joinDate).inDays / 365;
    double gratuity;
    if (yearsOfService <= 5) {
      gratuity = yearsOfService * 0.5 * _emp.salary;
    } else {
      gratuity = 5 * 0.5 * _emp.salary + (yearsOfService - 5) * 1.0 * _emp.salary;
    }
    final accrued = gratuity;
    final monthlyAccrual = accrued / (yearsOfService * 12);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _empBanner(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المكافأة المستحقة',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
                    Text(_fmt(accrued),
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('ر.س · إذا انتهت الخدمة اليوم (انتهاء عقد)',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              Text('تفاصيل الحساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _kv('تاريخ الانضمام', _emp.joinDate),
              _kv('سنوات الخدمة', '${yearsOfService.toStringAsFixed(2)} سنة'),
              _kv('الراتب الأساسي الشهري', '${_fmt(_emp.salary.toDouble())} ر.س'),
              const Divider(),
              _kv('أول 5 سنوات × نصف شهر',
                  '${_fmt((yearsOfService.clamp(0, 5)).toDouble() * 0.5 * _emp.salary)} ر.س'),
              _kv('ما بعد 5 سنوات × شهر كامل',
                  '${_fmt((yearsOfService - 5).clamp(0.0, double.infinity).toDouble() * _emp.salary)} ر.س'),
              const Divider(),
              _kv('المكافأة الشهرية المحتسبة', '${_fmt(monthlyAccrual)} ر.س/شهر'),
              _kv('المخصّص المتراكم (قيد محاسبي)', '${_fmt(accrued)} ر.س'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, color: core_theme.AC.info),
                  SizedBox(width: 8),
                  Text('أحكام نظام العمل السعودي — مادة 84 و85',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
                ],
              ),
              const SizedBox(height: 10),
              Text('• للخمس سنوات الأولى: نصف راتب شهر عن كل سنة',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• ما زاد على خمس سنوات: راتب شهر كامل عن كل سنة',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• في حالة الاستقالة: 2 > س ≥ 5 → الثلث، 5 > س ≥ 10 → الثلثان، 10+ → الكامل',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• تُحتسب على الراتب الأخير قبل انتهاء العقد',
                  style: TextStyle(fontSize: 12, height: 1.7)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProvidentTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _empBanner(),
        const SizedBox(height: 16),
        Row(
          children: [
            _pfStat('مساهمة الموظف (6%)', _emp.salary * 0.06 * 12, core_theme.AC.info, Icons.person),
            _pfStat('مساهمة الشركة (9%)', _emp.salary * 0.09 * 12, core_theme.AC.ok, Icons.business),
            _pfStat('الرصيد التراكمي', 324580, core_theme.AC.gold, Icons.savings),
          ],
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
              Text('الاستثمارات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _invRow('محفظة الأسهم السعودية', 40, 144000, 8.2),
              _invRow('صندوق السيولة الإسلامي', 30, 108000, 3.1),
              _invRow('الصكوك الحكومية', 20, 72000, 4.5),
              _invRow('العقارات (REIT)', 10, 36000, 6.8),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إجمالي العائد السنوي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('+ ${_fmt(324580 * 0.057)} ر.س (5.7%)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: core_theme.AC.ok, fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pfStat(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
              ],
            ),
            const SizedBox(height: 8),
            Text(_fmt(value),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
            Text('ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _invRow(String name, int pct, double value, double ytd) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('$pct% من المحفظة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${_fmt(value)} ر.س',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: core_theme.AC.ok.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('+${ytd.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ok, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab() {
    final loans = const [
      _Loan('LN-2024-012', 'سلفة راتب', 15000, 15000, 3000, 'مستحق 2 قسط'),
      _Loan('LN-2023-004', 'قرض سكني', 150000, 85000, 2500, 'مستحق 26 قسط'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _empBanner(),
        const SizedBox(height: 16),
        for (final l in loans)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
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
                    Text(l.id, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Text(l.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(l.remaining, style: TextStyle(fontSize: 11, color: core_theme.AC.warn, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _loanMetric('المبلغ', '${_fmt(l.amount.toDouble())} ر.س'),
                    _loanMetric('المتبقي', '${_fmt(l.remaining_amount.toDouble())} ر.س'),
                    _loanMetric('القسط', '${_fmt(l.installment.toDouble())} ر.س/شهر'),
                    _loanMetric('النسبة', '${((l.amount - l.remaining_amount) / l.amount * 100).toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (l.amount - l.remaining_amount) / l.amount,
                  backgroundColor: core_theme.AC.bdr,
                  valueColor: AlwaysStoppedAnimation(core_theme.AC.gold),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: Text('تقديم طلب سلفة أو قرض جديد'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: core_theme.AC.gold),
              foregroundColor: core_theme.AC.gold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _loanMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(k, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Emp {
  final String id;
  final String name;
  final String nationality;
  final int salary;
  final String joinDate;
  final String title;
  const _Emp(this.id, this.name, this.nationality, this.salary, this.joinDate, this.title);
}

class _Dep {
  final String relation;
  final String name;
  final String birthYear;
  final String class_;
  const _Dep(this.relation, this.name, this.birthYear, this.class_);
}

class _Claim {
  final String date;
  final String provider;
  final String type;
  final int amount;
  final String status;
  const _Claim(this.date, this.provider, this.type, this.amount, this.status);
}

class _Loan {
  final String id;
  final String type;
  final int amount;
  final int remaining_amount;
  final int installment;
  final String remaining;
  const _Loan(this.id, this.type, this.amount, this.remaining_amount, this.installment, this.remaining);
}
