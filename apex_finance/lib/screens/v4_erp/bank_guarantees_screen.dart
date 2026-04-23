/// APEX Wave 69 — Bank Guarantees & Letters of Credit.
/// Route: /app/erp/treasury/guarantees
///
/// Registry of L/Cs, L/Gs, performance bonds, bid bonds.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class BankGuaranteesScreen extends StatefulWidget {
  const BankGuaranteesScreen({super.key});
  @override
  State<BankGuaranteesScreen> createState() => _BankGuaranteesScreenState();
}

class _BankGuaranteesScreenState extends State<BankGuaranteesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _outgoing = const [
    _Instrument('LG-2026-042', 'ضمان حسن تنفيذ', 'NEOM Company', 2400000, 'الراجحي', '2026-03-15', '2027-03-14', 'active', 'performance'),
    _Instrument('LG-2026-038', 'ضمان ابتدائي', 'وزارة المالية — عطاء #4521', 500000, 'البلاد', '2026-04-01', '2026-07-01', 'active', 'bid'),
    _Instrument('LG-2025-087', 'ضمان دفعة مقدمة', 'ARAMCO', 1800000, 'الراجحي', '2025-11-01', '2026-06-30', 'active', 'advance'),
    _Instrument('LC-2026-015', 'اعتماد مستندي استيراد', 'Oracle Middle East', 4500000, 'السعودي الفرنسي', '2026-04-10', '2026-07-10', 'active', 'lc'),
    _Instrument('LG-2025-055', 'ضمان صيانة', 'SABIC', 850000, 'الأهلي', '2024-12-01', '2026-05-31', 'expiring', 'maintenance'),
    _Instrument('LG-2024-128', 'ضمان حسن تنفيذ — سابق', 'وزارة النقل', 1200000, 'البلاد', '2024-06-01', '2025-06-01', 'expired', 'performance'),
  ];

  final _incoming = const [
    _Instrument('LG-IN-2026-012', 'ضمان حسن تنفيذ مستلم', 'النسما للمقاولات', 3200000, 'الراجحي (مصدر)', '2026-02-15', '2027-02-14', 'active', 'performance'),
    _Instrument('LG-IN-2026-008', 'ضمان دفعة مقدمة', 'مكتب هندسي — المكتشف', 680000, 'البلاد (مصدر)', '2026-03-01', '2026-09-01', 'active', 'advance'),
    _Instrument('LC-IN-2026-004', 'اعتماد مستندي تصدير', 'Qatar Gas', 8500000, 'QNB (مصدر)', '2026-04-05', '2026-08-05', 'active', 'lc'),
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
    final outValue = _outgoing.where((i) => i.status == 'active').fold(0.0, (s, i) => s + i.amount);
    final inValue = _incoming.where((i) => i.status == 'active').fold(0.0, (s, i) => s + i.amount);
    final expiring = _outgoing.where((i) => i.status == 'expiring').length;

    return Column(
      children: [
        _buildHero(outValue, inValue),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _kpi('إجمالي الصادرة', _fmtM(outValue), core_theme.AC.warn, Icons.arrow_upward),
              _kpi('إجمالي الواردة', _fmtM(inValue), core_theme.AC.ok, Icons.arrow_downward),
              _kpi('قرب الانتهاء', '$expiring', core_theme.AC.err, Icons.warning),
              _kpi('معدل الاستخدام', '42%', core_theme.AC.info, Icons.donut_large),
            ],
          ),
        ),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF006064),
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: const Color(0xFF006064),
          tabs: const [
            Tab(icon: Icon(Icons.arrow_upward, size: 16), text: 'صادرة (ضدّنا)'),
            Tab(icon: Icon(Icons.arrow_downward, size: 16), text: 'واردة (لصالحنا)'),
            Tab(icon: Icon(Icons.account_balance, size: 16), text: 'حدود البنوك'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildList(_outgoing, 'outgoing'),
              _buildList(_incoming, 'incoming'),
              _buildLimitsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(double out, double inV) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF006064)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الضمانات البنكية والاعتمادات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('L/Gs · L/Cs · Performance Bonds · Advance Payment Guarantees · Bid Bonds',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_Instrument> items, String direction) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final instr = items[i];
        final statusColor = _statusColor(instr.status);
        final typeInfo = _typeInfo(instr.type);
        final daysLeft = DateTime.parse(instr.endDate).difference(DateTime(2026, 4, 19)).inDays;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeInfo.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeInfo.icon, color: typeInfo.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(instr.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeInfo.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(typeInfo.label,
                                  style: TextStyle(fontSize: 10, color: typeInfo.color, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(instr.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(instr.amount),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                      Text('ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: _dl('المستفيد/المقابل', instr.counterparty)),
                    Expanded(child: _dl('البنك', instr.bank)),
                    Expanded(child: _dl('البداية', instr.startDate)),
                    Expanded(child: _dl('النهاية', instr.endDate)),
                    Expanded(
                      child: _dl(
                        'الأيام المتبقية',
                        daysLeft < 0 ? 'منتهي' : '$daysLeft يوم',
                        color: daysLeft < 30 ? core_theme.AC.err : daysLeft < 90 ? core_theme.AC.warn : core_theme.AC.ok,
                      ),
                    ),
                  ],
                ),
              ),
              if (instr.status == 'expiring') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: core_theme.AC.warn,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: core_theme.AC.warn),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: core_theme.AC.warn, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'الضمان ينتهي خلال $daysLeft يوم — ابدأ إجراءات التجديد أو الإلغاء',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.warn),
                        ),
                      ),
                      TextButton(onPressed: () {}, child: Text('إجراء', style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _dl(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? core_theme.AC.tp)),
      ],
    );
  }

  Widget _buildLimitsTab() {
    final banks = const [
      _BankLimit('الراجحي', 15_000_000, 4_700_000, 4),
      _BankLimit('السعودي الفرنسي', 8_000_000, 4_500_000, 2),
      _BankLimit('البنك الأهلي', 6_000_000, 850_000, 1),
      _BankLimit('بنك البلاد', 4_000_000, 1_700_000, 2),
    ];
    final totalLimit = banks.fold(0, (s, b) => s + b.totalLimit);
    final totalUsed = banks.fold(0, (s, b) => s + b.used);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFE6C200)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('إجمالي الحدود الائتمانية الممنوحة',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(_fmt(totalLimit.toDouble()),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Text(' ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('مُستخدم', _fmtM(totalUsed.toDouble()), core_theme.AC.warn, Icons.pie_chart),
            _kpi('متاح', _fmtM((totalLimit - totalUsed).toDouble()), core_theme.AC.ok, Icons.check_circle),
            _kpi('نسبة الاستخدام', '${(totalUsed / totalLimit * 100).toStringAsFixed(0)}%', core_theme.AC.info, Icons.donut_large),
          ],
        ),
        const SizedBox(height: 16),
        for (final b in banks) _bankRow(b),
      ],
    );
  }

  Widget _bankRow(_BankLimit b) {
    final pct = b.used / b.totalLimit;
    final color = pct > 0.8 ? core_theme.AC.err : pct > 0.5 ? core_theme.AC.warn : core_theme.AC.ok;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, size: 18, color: core_theme.AC.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(b.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              Text('${b.instrumentCount} أداة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dl('الحد الكلي', '${_fmt(b.totalLimit.toDouble())} ر.س'),
              const SizedBox(width: 20),
              _dl('مُستخدم', '${_fmt(b.used.toDouble())} ر.س', color: color),
              const SizedBox(width: 20),
              _dl('متاح', '${_fmt((b.totalLimit - b.used).toDouble())} ر.س', color: core_theme.AC.ok),
              const Spacer(),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: core_theme.AC.bdr,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return core_theme.AC.ok;
      case 'expiring':
        return core_theme.AC.warn;
      case 'expired':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  _TypeInfo _typeInfo(String type) {
    switch (type) {
      case 'performance':
        return _TypeInfo('ضمان حسن تنفيذ', Icons.verified, core_theme.AC.info);
      case 'advance':
        return _TypeInfo('ضمان دفعة مقدمة', Icons.payments, core_theme.AC.purple);
      case 'bid':
        return _TypeInfo('ضمان ابتدائي', Icons.gavel, core_theme.AC.warn);
      case 'maintenance':
        return _TypeInfo('ضمان صيانة', Icons.build, core_theme.AC.info);
      case 'lc':
        return _TypeInfo('اعتماد مستندي', Icons.description, core_theme.AC.gold);
      default:
        return _TypeInfo('أخرى', Icons.category, core_theme.AC.td);
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M ر.س';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _Instrument {
  final String id;
  final String title;
  final String counterparty;
  final double amount;
  final String bank;
  final String startDate;
  final String endDate;
  final String status;
  final String type;
  const _Instrument(this.id, this.title, this.counterparty, this.amount, this.bank, this.startDate, this.endDate, this.status, this.type);
}

class _BankLimit {
  final String name;
  final int totalLimit;
  final int used;
  final int instrumentCount;
  const _BankLimit(this.name, this.totalLimit, this.used, this.instrumentCount);
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  _TypeInfo(this.label, this.icon, this.color);
}
