/// APEX Wave 44 — Fixed Assets Register.
/// Route: /app/erp/finance/fixed-assets
///
/// Tracks fixed assets with depreciation, maintenance, disposals.
library;

import 'package:flutter/material.dart';

class FixedAssetsRegisterScreen extends StatefulWidget {
  const FixedAssetsRegisterScreen({super.key});
  @override
  State<FixedAssetsRegisterScreen> createState() => _FixedAssetsRegisterScreenState();
}

class _FixedAssetsRegisterScreenState extends State<FixedAssetsRegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _filter = 'all';

  final _assets = <_Asset>[
    _Asset('FA-001', 'عقار — مقر الشركة الرئيسي', 'عقارات', 2500000, '2022-01-15', 30, 0, 'نشط', 2333333),
    _Asset('FA-002', 'آلة إنتاج رقم 1', 'معدات', 450000, '2023-03-20', 10, 0, 'نشط', 360000),
    _Asset('FA-003', 'سيارة مدير عام — لكزس', 'مركبات', 380000, '2024-06-10', 5, 0, 'نشط', 266000),
    _Asset('FA-004', 'أثاث مكتبي — طابق 3', 'أثاث', 85000, '2023-08-05', 7, 0, 'نشط', 61428),
    _Asset('FA-005', 'خوادم تقنية معلومات', 'أجهزة', 125000, '2024-11-12', 4, 0, 'نشط', 87500),
    _Asset('FA-006', 'شاحنة توصيل — إيسوزو', 'مركبات', 195000, '2021-09-22', 6, 0, 'متوقف', 32500),
    _Asset('FA-007', 'معدات مختبر الجودة', 'معدات', 320000, '2023-12-01', 8, 0, 'نشط', 253333),
    _Asset('FA-008', 'خط إنتاج إضافي', 'معدات', 780000, '2025-02-14', 10, 0, 'قيد الإنشاء', 780000),
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

  List<_Asset> get _filteredAssets {
    if (_filter == 'all') return _assets;
    return _assets.where((a) => a.category == _filter).toList();
  }

  double get _totalCost => _assets.fold(0.0, (s, a) => s + a.cost);
  double get _totalNetBV => _assets.fold(0.0, (s, a) => s + a.netBookValue);
  double get _totalDepreciation => _totalCost - _totalNetBV;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildStatsRow(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.list, size: 16), text: 'السجل'),
            Tab(icon: Icon(Icons.trending_down, size: 16), text: 'الإهلاك'),
            Tab(icon: Icon(Icons.build, size: 16), text: 'الصيانة'),
            Tab(icon: Icon(Icons.delete, size: 16), text: 'الاستبعادات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildRegisterTab(),
              _buildDepreciationTab(),
              _buildMaintenanceTab(),
              _buildDisposalsTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.business, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجل الأصول الثابتة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('تتبع كامل لدورة حياة الأصل: الاقتناء، الإهلاك، الصيانة، الاستبعاد',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _stat('عدد الأصول', '${_assets.length}', Colors.blue, Icons.inventory),
          _stat('التكلفة الأصلية', _fmt(_totalCost), const Color(0xFF7B1FA2), Icons.shopping_cart),
          _stat('مجمع الإهلاك', _fmt(_totalDepreciation), Colors.orange, Icons.trending_down),
          _stat('القيمة الدفترية', _fmt(_totalNetBV), const Color(0xFFD4AF37), Icons.account_balance),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          children: [
            _filterChip('all', 'الكل'),
            _filterChip('عقارات', 'عقارات'),
            _filterChip('معدات', 'معدات'),
            _filterChip('مركبات', 'مركبات'),
            _filterChip('أثاث', 'أثاث'),
            _filterChip('أجهزة', 'أجهزة'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    Expanded(child: Text('الرقم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الفئة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('تاريخ الشراء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('التكلفة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('العمر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('القيمة الدفترية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
                    Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final a in _filteredAssets)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(a.code,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                      ),
                      Expanded(flex: 3, child: Text(a.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: _catColor(a.category).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(a.category, style: TextStyle(fontSize: 10, color: _catColor(a.category), fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                        ),
                      ),
                      Expanded(child: Text(a.purchaseDate, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      Expanded(child: Text(_fmt(a.cost), style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text('${a.lifeYears} سنة', style: const TextStyle(fontSize: 11))),
                      Expanded(
                        child: Text(_fmt(a.netBookValue),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37))),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(a.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(a.status, style: TextStyle(fontSize: 10, color: _statusColor(a.status), fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String id, String label) {
    final selected = _filter == id;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4AF37) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            )),
      ),
    );
  }

  Widget _buildDepreciationTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                  'طريقة الإهلاك المتّبعة: القسط الثابت (Straight-Line) — معدل الإهلاك = التكلفة ÷ العمر الإنتاجي',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('إهلاك الشهر الحالي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final a in _assets.where((a) => a.status == 'نشط'))
          _depreciationRow(a),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي إهلاك الشهر',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              Text(_fmt(_monthlyDepreciation), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إنشاء قيد الإهلاك — ${_fmt(_monthlyDepreciation)} ر.س'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.book),
            label: const Text('ترحيل قيد الإهلاك للشهر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  double get _monthlyDepreciation => _assets
      .where((a) => a.status == 'نشط')
      .fold(0.0, (s, a) => s + (a.cost / a.lifeYears / 12));

  Widget _depreciationRow(_Asset a) {
    final monthly = a.cost / a.lifeYears / 12;
    final annualRate = (100 / a.lifeYears).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${a.code} · عمر ${a.lifeYears} سنوات · $annualRate% سنوياً',
                    style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          Expanded(
            child: Text(_fmt(a.cost), style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: Text(_fmt(a.netBookValue), style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(_fmt(monthly), style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    final maintenance = [
      _Maint('FA-002', 'صيانة دورية — كل 3 أشهر', '2026-04-20', 'قادم', 2500),
      _Maint('FA-007', 'معايرة أجهزة مختبر', '2026-05-01', 'قادم', 4500),
      _Maint('FA-003', 'فحص دوري — المركبات', '2026-03-10', 'مكتمل', 850),
      _Maint('FA-001', 'صيانة تكييف مركزي', '2026-02-15', 'مكتمل', 12000),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: maintenance.length,
      itemBuilder: (ctx, i) {
        final m = maintenance[i];
        final isDone = m.status == 'مكتمل';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDone ? Colors.green.shade200 : Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(isDone ? Icons.check_circle : Icons.schedule,
                  color: isDone ? Colors.green : Colors.amber.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('${m.assetCode} · ${m.date}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              Text(_fmt(m.cost), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              const Text(' ر.س', style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisposalsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('الأصول المرشّحة للاستبعاد',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'أي أصل بحالة "متوقف" أو بلغت قيمته الدفترية < 10% من التكلفة الأصلية.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final a in _assets.where((x) => x.status == 'متوقف' || x.netBookValue < x.cost * 0.1))
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(10),
              color: Colors.red.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text('${a.code} · ${a.category} · القيمة الدفترية: ${_fmt(a.netBookValue)} ر.س',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.sell, size: 14),
                      label: const Text('استبعاد بالبيع'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_forever, size: 14),
                      label: const Text('استبعاد بالشطب'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _catColor(String c) {
    switch (c) {
      case 'عقارات':
        return Colors.teal;
      case 'معدات':
        return Colors.blue;
      case 'مركبات':
        return Colors.orange;
      case 'أثاث':
        return Colors.brown;
      case 'أجهزة':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'نشط':
        return Colors.green;
      case 'متوقف':
        return Colors.red;
      case 'قيد الإنشاء':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Asset {
  final String code;
  final String name;
  final String category;
  final double cost;
  final String purchaseDate;
  final int lifeYears;
  final double salvage;
  final String status;
  final double netBookValue;
  const _Asset(this.code, this.name, this.category, this.cost, this.purchaseDate, this.lifeYears, this.salvage, this.status, this.netBookValue);
}

class _Maint {
  final String assetCode;
  final String description;
  final String date;
  final String status;
  final double cost;
  const _Maint(this.assetCode, this.description, this.date, this.status, this.cost);
}
