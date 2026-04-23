/// APEX Wave 99 — Intercompany Reconciliation.
/// Route: /app/erp/finance/intercompany
///
/// Multi-entity balances, matched transactions, eliminations.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class IntercompanyScreen extends StatefulWidget {
  const IntercompanyScreen({super.key});
  @override
  State<IntercompanyScreen> createState() => _IntercompanyScreenState();
}

class _IntercompanyScreenState extends State<IntercompanyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _entities = [
    _Entity('APEX-KSA', 'APEX Holding KSA', 'المملكة العربية السعودية', core_theme.AC.gold),
    _Entity('APEX-UAE', 'APEX Dubai LLC', 'الإمارات العربية المتحدة', core_theme.AC.info),
    _Entity('APEX-IND', 'APEX Manufacturing India', 'الهند', core_theme.AC.warn),
    _Entity('APEX-SG', 'APEX Singapore Pte', 'سنغافورة', core_theme.AC.ok),
    _Entity('APEX-BH', 'APEX Logistics Bahrain', 'البحرين', core_theme.AC.info),
    _Entity('APEX-UK', 'APEX Technology UK', 'المملكة المتحدة', core_theme.AC.purple),
  ];

  final _balances = const [
    _ICBalance('APEX-KSA', 'APEX-UAE', 2_450_000, 2_420_000, 30_000, 'reconciling'),
    _ICBalance('APEX-KSA', 'APEX-IND', 1_850_000, 1_850_000, 0, 'matched'),
    _ICBalance('APEX-KSA', 'APEX-SG', 680_000, 680_000, 0, 'matched'),
    _ICBalance('APEX-UAE', 'APEX-SG', 1_200_000, 1_185_000, 15_000, 'reconciling'),
    _ICBalance('APEX-UAE', 'APEX-UK', 450_000, 450_000, 0, 'matched'),
    _ICBalance('APEX-KSA', 'APEX-BH', 320_000, 328_500, 8_500, 'investigating'),
    _ICBalance('APEX-IND', 'APEX-SG', 780_000, 780_000, 0, 'matched'),
    _ICBalance('APEX-KSA', 'APEX-UK', 920_000, 920_000, 0, 'matched'),
  ];

  final _txns = const [
    _ICTxn('ICT-2026-0245', 'APEX-KSA', 'APEX-UAE', 'خدمات إدارية ربعية', 850_000, '2026-04-15', 'pending-match'),
    _ICTxn('ICT-2026-0244', 'APEX-UAE', 'APEX-KSA', 'توزيع أرباح', 1_200_000, '2026-04-12', 'matched'),
    _ICTxn('ICT-2026-0243', 'APEX-IND', 'APEX-KSA', 'شحنة مواد نهائية', 480_000, '2026-04-10', 'matched'),
    _ICTxn('ICT-2026-0242', 'APEX-KSA', 'APEX-IND', 'دفعة للموردين', 480_000, '2026-04-10', 'matched'),
    _ICTxn('ICT-2026-0241', 'APEX-UK', 'APEX-UAE', 'رسوم ترخيص تقنية', 245_000, '2026-04-05', 'matched'),
    _ICTxn('ICT-2026-0240', 'APEX-BH', 'APEX-KSA', 'خدمات لوجستية', 125_000, '2026-04-02', 'discrepancy'),
    _ICTxn('ICT-2026-0239', 'APEX-SG', 'APEX-UAE', 'إتاوات علامة تجارية', 380_000, '2026-04-01', 'matched'),
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
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.compare_arrows, size: 16), text: 'مصفوفة الأرصدة'),
            Tab(icon: Icon(Icons.list, size: 16), text: 'المعاملات'),
            Tab(icon: Icon(Icons.merge, size: 16), text: 'الاستبعادات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildMatrixTab(),
              _buildTxnsTab(),
              _buildEliminationsTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.business, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تسوية المعاملات بين الشركات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Intercompany Reconciliation — 6 كيانات · تطابق تلقائي · استبعادات التوحيد',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final matched = _balances.where((b) => b.status == 'matched').length;
    final reconciling = _balances.where((b) => b.status == 'reconciling').length;
    final investigating = _balances.where((b) => b.status == 'investigating').length;
    final totalDiff = _balances.fold(0.0, (s, b) => s + b.difference.abs());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('إجمالي الكيانات', '${_entities.length}', core_theme.AC.info, Icons.business),
          _kpi('أزواج متطابقة', '$matched / ${_balances.length}', core_theme.AC.ok, Icons.check_circle),
          _kpi('قيد التسوية', '$reconciling', core_theme.AC.warn, Icons.sync),
          _kpi('قيد التحقيق', '$investigating', core_theme.AC.err, Icons.warning),
          _kpi('إجمالي الفروقات', _fmtM(totalDiff), core_theme.AC.gold, Icons.calculate),
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
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final b in _balances) _balanceCard(b),
      ],
    );
  }

  Widget _balanceCard(_ICBalance b) {
    final entityA = _entities.firstWhere((e) => e.code == b.entityA, orElse: () => _entities.first);
    final entityB = _entities.firstWhere((e) => e.code == b.entityB, orElse: () => _entities.first);
    final statusColor = _statusColor(b.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 24, color: entityA.color),
                    const SizedBox(width: 6),
                    Text(entityA.code, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                  ],
                ),
                Text(entityA.name, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Icon(Icons.sync_alt, color: core_theme.AC.td),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 24, color: entityB.color),
                      const SizedBox(width: 6),
                      Text(entityB.code, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Text(entityB.name, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مدين لدى A', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text(_fmtM(b.aBalance),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.gold, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('دائن لدى B', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text(_fmtM(b.bBalance),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.warn, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الفرق', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text(_fmt(b.difference),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: b.difference == 0 ? core_theme.AC.ok : core_theme.AC.err,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(b.status), size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(_statusLabel(b.status),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _txns.length,
      itemBuilder: (ctx, i) {
        final t = _txns[i];
        final fromEntity = _entities.firstWhere((e) => e.code == t.fromEntity, orElse: () => _entities.first);
        final toEntity = _entities.firstWhere((e) => e.code == t.toEntity, orElse: () => _entities.first);
        final statusColor = _txnStatusColor(t.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(t.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: fromEntity.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(t.fromEntity,
                    style: TextStyle(fontSize: 10, color: fromEntity.color, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14, color: core_theme.AC.td),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: toEntity.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(t.toEntity,
                    style: TextStyle(fontSize: 10, color: toEntity.color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(t.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Text(t.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Text(_fmt(t.amount),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.gold, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(_txnStatusLabel(t.status),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEliminationsTab() {
    final eliminations = const [
      _Elimination('استبعاد المبيعات والمشتريات الداخلية', 8_450_000, 'revenue-cogs'),
      _Elimination('استبعاد الأرباح غير المحققة في المخزون', 420_000, 'inventory'),
      _Elimination('استبعاد القروض والفوائد الداخلية', 3_200_000, 'intra-debt'),
      _Elimination('استبعاد توزيعات الأرباح الداخلية', 1_200_000, 'dividends'),
      _Elimination('استبعاد الإتاوات والترخيص', 625_000, 'royalties'),
      _Elimination('استبعاد الخدمات الإدارية المشتركة', 1_850_000, 'services'),
    ];
    final total = eliminations.fold(0.0, (s, e) => s + e.amount);
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
              Text('قيود الاستبعاد عند التوحيد (Consolidation Eliminations)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Q1 2026 — وفقاً لـ IFRS 10',
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              const SizedBox(height: 16),
              for (final e in eliminations)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: core_theme.AC.navy3,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _catColor(e.category).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Icon(_catIcon(e.category), color: _catColor(e.category), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(_catLabel(e.category),
                                style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                          ],
                        ),
                      ),
                      Text(_fmt(e.amount),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                      Text(' ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    ],
                  ),
                ),
              const Divider(height: 30),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: core_theme.AC.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: core_theme.AC.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('إجمالي الاستبعادات',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                    Text(_fmt(total),
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                    const SizedBox(width: 4),
                    Text('ر.س', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
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
                  'وفقاً لـ IFRS 10 — يجب استبعاد كل المعاملات بين الشركات التابعة قبل إصدار القوائم الموحّدة. أي فرق في الأرصدة الثنائية يجب تسويته قبل الاستبعاد.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'matched':
        return core_theme.AC.ok;
      case 'reconciling':
        return core_theme.AC.warn;
      case 'investigating':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'matched':
        return Icons.check_circle;
      case 'reconciling':
        return Icons.sync;
      case 'investigating':
        return Icons.warning;
      default:
        return Icons.circle;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'matched':
        return 'مطابق';
      case 'reconciling':
        return 'قيد التسوية';
      case 'investigating':
        return 'قيد التحقيق';
      default:
        return s;
    }
  }

  Color _txnStatusColor(String s) {
    switch (s) {
      case 'matched':
        return core_theme.AC.ok;
      case 'pending-match':
        return core_theme.AC.warn;
      case 'discrepancy':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _txnStatusLabel(String s) {
    switch (s) {
      case 'matched':
        return 'مطابق';
      case 'pending-match':
        return 'بانتظار';
      case 'discrepancy':
        return 'فرق';
      default:
        return s;
    }
  }

  Color _catColor(String c) {
    switch (c) {
      case 'revenue-cogs':
        return core_theme.AC.gold;
      case 'inventory':
        return core_theme.AC.info;
      case 'intra-debt':
        return core_theme.AC.warn;
      case 'dividends':
        return core_theme.AC.purple;
      case 'royalties':
        return core_theme.AC.info;
      case 'services':
        return core_theme.AC.ok;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _catIcon(String c) {
    switch (c) {
      case 'revenue-cogs':
        return Icons.swap_horiz;
      case 'inventory':
        return Icons.inventory;
      case 'intra-debt':
        return Icons.account_balance;
      case 'dividends':
        return Icons.star;
      case 'royalties':
        return Icons.copyright;
      case 'services':
        return Icons.business_center;
      default:
        return Icons.circle;
    }
  }

  String _catLabel(String c) {
    switch (c) {
      case 'revenue-cogs':
        return 'إيرادات ومشتريات';
      case 'inventory':
        return 'مخزون';
      case 'intra-debt':
        return 'قروض داخلية';
      case 'dividends':
        return 'توزيعات أرباح';
      case 'royalties':
        return 'إتاوات';
      case 'services':
        return 'خدمات داخلية';
      default:
        return c;
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

class _Entity {
  final String code;
  final String name;
  final String country;
  final Color color;
  const _Entity(this.code, this.name, this.country, this.color);
}

class _ICBalance {
  final String entityA;
  final String entityB;
  final double aBalance;
  final double bBalance;
  final double difference;
  final String status;
  const _ICBalance(this.entityA, this.entityB, this.aBalance, this.bBalance, this.difference, this.status);
}

class _ICTxn {
  final String id;
  final String fromEntity;
  final String toEntity;
  final String description;
  final double amount;
  final String date;
  final String status;
  const _ICTxn(this.id, this.fromEntity, this.toEntity, this.description, this.amount, this.date, this.status);
}

class _Elimination {
  final String description;
  final double amount;
  final String category;
  const _Elimination(this.description, this.amount, this.category);
}
