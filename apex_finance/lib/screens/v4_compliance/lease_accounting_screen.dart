/// APEX Wave 98 — Lease Accounting (IFRS 16).
/// Route: /app/compliance/tax/leases
///
/// Right-of-use assets + lease liabilities per IFRS 16.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class LeaseAccountingScreen extends StatefulWidget {
  const LeaseAccountingScreen({super.key});
  @override
  State<LeaseAccountingScreen> createState() => _LeaseAccountingScreenState();
}

class _LeaseAccountingScreenState extends State<LeaseAccountingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _leases = const [
    _Lease('LSE-001', 'مقر رئيسي — طريق الملك فهد', 'real-estate', 3600000, '2022-07-01', '2027-06-30', 60, 5.5, 3240000, 720000, 'active'),
    _Lease('LSE-002', 'فرع جدة — طريق الكورنيش', 'real-estate', 1800000, '2023-04-01', '2028-03-31', 60, 5.5, 1620000, 360000, 'active'),
    _Lease('LSE-003', '4 سيارات — أسطول المبيعات', 'vehicle', 480000, '2024-01-15', '2027-01-14', 36, 6.0, 320000, 160000, 'active'),
    _Lease('LSE-004', 'خوادم وأجهزة IT', 'equipment', 720000, '2024-09-01', '2027-08-31', 36, 5.8, 540000, 240000, 'active'),
    _Lease('LSE-005', 'مستودع إضافي — الرياض', 'real-estate', 850000, '2025-01-01', '2028-12-31', 48, 5.2, 720000, 170000, 'active'),
    _Lease('LSE-006', 'آلة طباعة صناعية', 'equipment', 240000, '2023-06-01', '2026-05-31', 36, 6.5, 96000, 80000, 'active'),
    _Lease('LSE-007', 'فرع الدمام (انتهى)', 'real-estate', 1200000, '2020-01-01', '2025-12-31', 72, 5.0, 0, 240000, 'expired'),
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

  double get _totalROU => _leases.where((l) => l.status == 'active').fold(0.0, (s, l) => s + l.rouCarrying);
  double get _totalLiability => _leases.where((l) => l.status == 'active').fold(0.0, (s, l) => s + l.liabilityOutstanding);
  double get _totalAnnualPayment => _leases.where((l) => l.status == 'active').fold(0.0, (s, l) => s + l.annualPayment);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.list, size: 16), text: 'عقود الإيجار'),
            Tab(icon: Icon(Icons.calculate, size: 16), text: 'الإهلاك والفائدة'),
            Tab(icon: Icon(Icons.article, size: 16), text: 'الإفصاحات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildLeasesTab(),
              _buildAmortTab(),
              _buildDisclosureTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.home_work, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المحاسبة عن عقود الإيجار — IFRS 16',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Right-of-Use Assets · Lease Liabilities · حساب الفائدة · جداول السداد',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final active = _leases.where((l) => l.status == 'active').length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('العقود النشطة', '$active', core_theme.AC.info, Icons.description),
          _kpi('أصول حق الاستخدام', '${_fmtM(_totalROU)} ر.س', core_theme.AC.gold, Icons.home_work),
          _kpi('الالتزام القائم', '${_fmtM(_totalLiability)} ر.س', core_theme.AC.warn, Icons.trending_down),
          _kpi('دفعات سنوية', '${_fmtM(_totalAnnualPayment)} ر.س', core_theme.AC.ok, Icons.payments),
          _kpi('متوسط مدة الإيجار', '48 شهر', core_theme.AC.purple, Icons.schedule),
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
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeasesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: Row(
                  children: [
                    Expanded(child: Text('الرقم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('الوصف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('إجمالي العقد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المدة (شهر)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('IBR %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('ROU Asset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                    Expanded(flex: 2, child: Text('الالتزام', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final l in _leases) _leaseRow(l),
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
                  'IBR = Incremental Borrowing Rate — معدل الإقراض المتزايد للمنشأة، يُستخدم لخصم التزام الإيجار. ROU Asset يتناقص بالإهلاك الخطّي والالتزام يتناقص بالدفعات + الفائدة.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leaseRow(_Lease l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
        color: l.status == 'expired' ? core_theme.AC.navy3 : null,
      ),
      child: Row(
        children: [
          Expanded(child: Text(l.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${l.startDate} → ${l.endDate}',
                    style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _typeColor(l.type).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(_typeLabel(l.type),
                  style: TextStyle(fontSize: 10, color: _typeColor(l.type), fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmt(l.totalValue),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ),
          Expanded(child: Text('${l.months}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(child: Text('${l.ibr}%', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(
            flex: 2,
            child: Text(_fmt(l.rouCarrying),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.gold, fontFamily: 'monospace')),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmt(l.liabilityOutstanding),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.warn, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _buildAmortTab() {
    // Sample amortization schedule for first lease
    final lease = _leases.first;
    final monthlyPayment = lease.annualPayment / 12;
    final periods = List.generate(12, (i) {
      final opening = lease.rouCarrying - (lease.rouCarrying / 60) * i;
      final interest = (lease.liabilityOutstanding - monthlyPayment * i * 0.7) * lease.ibr / 100 / 12;
      return _PeriodRow(i + 1, opening, monthlyPayment, interest, monthlyPayment - interest, opening - (lease.rouCarrying / 60));
    });
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
              Row(
                children: [
                  Icon(Icons.description, color: core_theme.AC.gold),
                  const SizedBox(width: 8),
                  Text('جدول الإهلاك — ${lease.description}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: core_theme.AC.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('أول 12 شهر · مدة كلية ${lease.months}',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.info, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                color: core_theme.AC.navy3,
                child: Row(
                  children: [
                    Expanded(child: Text('الشهر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('ROU الافتتاحي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الدفعة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الفائدة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.warn))),
                    Expanded(flex: 2, child: Text('الأصل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                    Expanded(flex: 2, child: Text('ROU الختامي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final p in periods)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('${p.month}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text(_fmt(p.opening), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text(_fmt(p.payment), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt(p.interest),
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.warn, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt(p.principal),
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.gold, fontWeight: FontWeight.w800)),
                      ),
                      Expanded(flex: 2, child: Text(_fmt(p.closing), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.warn,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.warn),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.functions, color: core_theme.AC.warn),
                  SizedBox(width: 8),
                  Text('الصيغ المستخدمة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
              SizedBox(height: 10),
              Text('• ROU الافتتاحي = القيمة الحالية (PV) للدفعات المستقبلية عند بداية العقد',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• إهلاك ROU = ROU الابتدائي ÷ المدة (بالأشهر) — قسط ثابت',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• الفائدة الشهرية = الالتزام القائم × (IBR ÷ 12)',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• الأصل من الدفعة = إجمالي الدفعة − الفائدة',
                  style: TextStyle(fontSize: 12, height: 1.7)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclosureTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إفصاحات IFRS 16 المطلوبة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              _disclosureSection(
                '1. الأصول: حق الاستخدام (ROU)',
                [
                  _Line('الرصيد الافتتاحي 2026', 5_820_000),
                  _Line('+ إضافات عقود جديدة', 850_000),
                  _Line('- إهلاك السنة', 1_240_000),
                  _Line('- إنهاءات وتصفيات', 0),
                  _Line('الرصيد الختامي', 5_430_000, isTotal: true),
                ],
              ),
              const Divider(height: 32),
              _disclosureSection(
                '2. الالتزامات: التزام الإيجار',
                [
                  _Line('الرصيد الافتتاحي 2026', 6_120_000),
                  _Line('+ عقود جديدة', 850_000),
                  _Line('+ الفائدة المحتسبة', 322_000),
                  _Line('- الدفعات السنوية', 1_722_000),
                  _Line('الرصيد الختامي', 5_570_000, isTotal: true),
                ],
              ),
              const Divider(height: 32),
              _disclosureSection(
                '3. الأعمار الباقية — جدول الاستحقاقات',
                [
                  _Line('خلال سنة واحدة', 1_680_000),
                  _Line('1 — 2 سنة', 1_520_000),
                  _Line('2 — 3 سنوات', 1_240_000),
                  _Line('3 — 5 سنوات', 850_000),
                  _Line('أكثر من 5 سنوات', 280_000),
                  _Line('الإجمالي', 5_570_000, isTotal: true),
                ],
              ),
              const Divider(height: 32),
              _disclosureSection(
                '4. في قائمة الدخل',
                [
                  _Line('مصروف إهلاك ROU', 1_240_000),
                  _Line('مصروف الفائدة على الالتزام', 322_000),
                  _Line('مصروف الإيجار قصير الأجل', 48_000),
                  _Line('إجمالي مصروف الإيجار', 1_610_000, isTotal: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _disclosureSection(String title, List<_Line> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
        const SizedBox(height: 10),
        for (final l in lines)
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: l.isTotal ? 8 : 0),
            decoration: l.isTotal
                ? BoxDecoration(color: core_theme.AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4))
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(l.label,
                      style: TextStyle(
                          fontSize: l.isTotal ? 13 : 12,
                          fontWeight: l.isTotal ? FontWeight.w900 : FontWeight.w500)),
                ),
                Text(
                  '${l.value < 0 ? '(' : ''}${_fmt(l.value.abs())}${l.value < 0 ? ')' : ''}',
                  style: TextStyle(
                      fontSize: l.isTotal ? 14 : 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: l.isTotal ? core_theme.AC.gold : core_theme.AC.tp),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'real-estate':
        return Colors.brown;
      case 'vehicle':
        return core_theme.AC.info;
      case 'equipment':
        return core_theme.AC.warn;
      default:
        return core_theme.AC.td;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'real-estate':
        return 'عقار';
      case 'vehicle':
        return 'مركبة';
      case 'equipment':
        return 'معدات';
      default:
        return t;
    }
  }

  String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Lease {
  final String id;
  final String description;
  final String type;
  final double totalValue;
  final String startDate;
  final String endDate;
  final int months;
  final double ibr;
  final double rouCarrying;
  final double annualPayment;
  final String status;
  const _Lease(this.id, this.description, this.type, this.totalValue, this.startDate, this.endDate, this.months, this.ibr, this.rouCarrying, this.annualPayment, this.status);

  double get liabilityOutstanding => rouCarrying * 1.03; // simplified
}

class _PeriodRow {
  final int month;
  final double opening;
  final double payment;
  final double interest;
  final double principal;
  final double closing;
  const _PeriodRow(this.month, this.opening, this.payment, this.interest, this.principal, this.closing);
}

class _Line {
  final String label;
  final double value;
  final bool isTotal;
  const _Line(this.label, this.value, {this.isTotal = false});
}
