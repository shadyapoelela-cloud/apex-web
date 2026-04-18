/// APEX Wave 102 — Price List & Catalog Management.
/// Route: /app/erp/operations/price-list
///
/// Products catalog, price tiers, currency, discounts.
library;

import 'package:flutter/material.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});
  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _filter = 'all';

  final _products = const [
    _Product('SKU-001', 'خدمة تدقيق سنوي — مستوى 1', 'audit', 'SAR', 95000, 85500, 76000, 108000, 'active', true),
    _Product('SKU-002', 'خدمة تدقيق سنوي — مستوى 2', 'audit', 'SAR', 185000, 166500, 148000, 212000, 'active', true),
    _Product('SKU-003', 'استشارات مالية — يومياً', 'advisory', 'SAR', 8500, 7650, 6800, 9750, 'active', true),
    _Product('SKU-004', 'تنفيذ SAP — حزمة أساسية', 'erp', 'SAR', 650000, 585000, 520000, 749000, 'active', true),
    _Product('SKU-005', 'ترخيص APEX Cloud — Enterprise', 'saas', 'SAR', 2499, 2249, 1999, 2874, 'active', false),
    _Product('SKU-006', 'ترخيص APEX Cloud — Professional', 'saas', 'SAR', 899, 809, 719, 1034, 'active', false),
    _Product('SKU-007', 'تدريب ZATCA Phase 2', 'training', 'SAR', 4500, 4050, 3600, 5175, 'active', false),
    _Product('SKU-008', 'خدمة توريد مواد — بولي بروبلين', 'supply', 'SAR', 2050, 1850, 1650, 2370, 'active', true),
    _Product('SKU-009', 'خدمة مراجعة داخلية — شهرياً', 'audit', 'SAR', 28000, 25200, 22400, 32200, 'active', true),
    _Product('SKU-010', 'باقة Starter — SaaS', 'saas', 'SAR', 299, 269, 239, 344, 'active', false),
    _Product('SKU-011', 'حزمة صيانة ERP — سنوية', 'erp', 'SAR', 48000, 43200, 38400, 55200, 'active', true),
    _Product('SKU-012', 'ترقية خدمة — Premium Support', 'saas', 'SAR', 1200, 1080, 960, 1380, 'active', false),
    _Product('SKU-013', 'حزمة تدريب APEX Academy', 'training', 'SAR', 12000, 10800, 9600, 13800, 'planned', false),
    _Product('SKU-014', 'خدمة مواد — قديمة', 'supply', 'SAR', 1200, 1080, 960, 1380, 'discontinued', false),
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

  List<_Product> get _filtered {
    if (_filter == 'all') return _products;
    return _products.where((p) => p.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.list, size: 16), text: 'المنتجات والأسعار'),
            Tab(icon: Icon(Icons.discount, size: 16), text: 'قواعد الخصومات'),
            Tab(icon: Icon(Icons.history, size: 16), text: 'تاريخ التعديلات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildProductsTab(),
              _buildDiscountsTab(),
              _buildHistoryTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF006064), Color(0xFF00838F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('قائمة الأسعار والكتالوج',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Price List Management — مستويات السعر · خصومات · عملات · موافقات',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: const Text('منتج جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF006064),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final active = _products.where((p) => p.status == 'active').length;
    final recurring = _products.where((p) => p.recurring).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('إجمالي المنتجات', '${_products.length}', Colors.blue, Icons.inventory_2),
          _kpi('نشطة', '$active', Colors.green, Icons.check_circle),
          _kpi('متكرّرة', '$recurring', Colors.purple, Icons.repeat),
          _kpi('متوسط السعر', '58K ر.س', const Color(0xFFD4AF37), Icons.attach_money),
          _kpi('هامش الربح المتوسط', '42%', Colors.teal, Icons.trending_up),
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

  Widget _buildProductsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          children: [
            _filterChip('all', 'الكل'),
            _filterChip('audit', 'مراجعة'),
            _filterChip('advisory', 'استشارات'),
            _filterChip('erp', 'ERP'),
            _filterChip('saas', 'SaaS'),
            _filterChip('training', 'تدريب'),
            _filterChip('supply', 'توريد'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    Expanded(child: Text('SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('المنتج', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الفئة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('Silver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey))),
                    Expanded(child: Text('Gold', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
                    Expanded(child: Text('Platinum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF455A64)))),
                    Expanded(child: Text('Retail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blue))),
                    Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final p in _filtered) _productRow(p),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4AF37) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFFD4AF37) : Colors.black26),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _productRow(_Product p) {
    final statusColor = p.status == 'active' ? Colors.green : p.status == 'planned' ? Colors.blue : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
        color: p.status != 'active' ? Colors.grey.shade50 : null,
      ),
      child: Row(
        children: [
          Expanded(child: Text(p.sku, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                if (p.recurring)
                  const Icon(Icons.repeat, size: 14, color: Colors.purple),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _catColor(p.category).withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(_catLabel(p.category),
                  style: TextStyle(fontSize: 10, color: _catColor(p.category), fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          ),
          Expanded(child: Text(_fmt(p.silverPrice.toDouble()), style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'))),
          Expanded(child: Text(_fmt(p.goldPrice.toDouble()), style: const TextStyle(fontSize: 12, color: Color(0xFFD4AF37), fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
          Expanded(child: Text(_fmt(p.platinumPrice.toDouble()), style: const TextStyle(fontSize: 11, color: Color(0xFF455A64), fontFamily: 'monospace'))),
          Expanded(child: Text(_fmt(p.retailPrice.toDouble()), style: const TextStyle(fontSize: 11, color: Colors.blue, fontFamily: 'monospace'))),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
              child: Text(_statusLabel(p.status),
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountsTab() {
    final rules = const [
      _Discount('خصم الحجم', 'volume', '> 1,000,000 ر.س فاتورة واحدة', 10, 'تلقائي', Colors.blue),
      _Discount('خصم الولاء Platinum', 'loyalty', 'عميل > 5 سنوات', 15, 'تلقائي', Color(0xFFD4AF37)),
      _Discount('خصم الدفع المبكر', 'early-payment', 'دفع خلال 10 أيام', 2, 'تلقائي', Colors.green),
      _Discount('خصم موسمي — العيد', 'seasonal', 'العيدين فقط', 8, 'مؤقت', Colors.purple),
      _Discount('خصم اشتراك سنوي', 'annual', 'اشتراك سنوي مقدّم', 17, 'تلقائي', Colors.teal),
      _Discount('خصم جهة حكومية', 'government', 'جهات حكومية معتمدة', 5, 'يدوي', Colors.red),
      _Discount('خصم حجم صفقة استراتيجي', 'strategic', '> 5M ر.س', 20, 'اعتماد مدير المبيعات', Colors.orange),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rules.length,
      itemBuilder: (ctx, i) {
        final d = rules[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: d.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: d.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.local_offer, color: d.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(d.condition, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
                          child: Text(d.application,
                              style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: d.color, borderRadius: BorderRadius.circular(10)),
                child: Text('-${d.percentage}%',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final changes = const [
      _PriceChange('2026-04-15', 'SKU-002', 'زيادة 5% بسبب تحديث المعايير', 176000, 185000, Colors.green),
      _PriceChange('2026-04-01', 'SKU-005', 'خصم ترويجي Q2 — 10%', 2499, 2249, Colors.orange),
      _PriceChange('2026-03-12', 'SKU-008', 'تعديل حسب سعر الخام', 1980, 2050, Colors.green),
      _PriceChange('2026-02-28', 'SKU-001', 'تحديث سعر سنوي', 92000, 95000, Colors.green),
      _PriceChange('2026-02-10', 'SKU-014', 'تخفيض قبل الإيقاف', 1500, 1200, Colors.red),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: changes.length,
      itemBuilder: (ctx, i) {
        final c = changes[i];
        final up = c.newPrice > c.oldPrice;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Icon(up ? Icons.arrow_upward : Icons.arrow_downward, color: c.color, size: 18),
              const SizedBox(width: 10),
              Text(c.date, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(c.sku,
                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(c.reason, style: const TextStyle(fontSize: 12))),
              Text(_fmt(c.oldPrice.toDouble()),
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace', decoration: TextDecoration.lineThrough)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 14),
              ),
              Text(_fmt(c.newPrice.toDouble()),
                  style: TextStyle(fontSize: 14, color: c.color, fontFamily: 'monospace', fontWeight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }

  Color _catColor(String c) {
    switch (c) {
      case 'audit':
        return const Color(0xFF4A148C);
      case 'advisory':
        return Colors.blue;
      case 'erp':
        return const Color(0xFFD4AF37);
      case 'saas':
        return Colors.purple;
      case 'training':
        return Colors.teal;
      case 'supply':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _catLabel(String c) {
    switch (c) {
      case 'audit':
        return 'مراجعة';
      case 'advisory':
        return 'استشارات';
      case 'erp':
        return 'ERP';
      case 'saas':
        return 'SaaS';
      case 'training':
        return 'تدريب';
      case 'supply':
        return 'توريد';
      default:
        return c;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'نشط';
      case 'planned':
        return 'مخطط';
      case 'discontinued':
        return 'موقوف';
      default:
        return s;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Product {
  final String sku;
  final String name;
  final String category;
  final String currency;
  final int retailPrice;
  final int goldPrice;
  final int platinumPrice;
  final int silverPrice;
  final String status;
  final bool recurring;
  const _Product(this.sku, this.name, this.category, this.currency, this.retailPrice, this.goldPrice, this.platinumPrice, this.silverPrice, this.status, this.recurring);
}

class _Discount {
  final String name;
  final String type;
  final String condition;
  final int percentage;
  final String application;
  final Color color;
  const _Discount(this.name, this.type, this.condition, this.percentage, this.application, this.color);
}

class _PriceChange {
  final String date;
  final String sku;
  final String reason;
  final int oldPrice;
  final int newPrice;
  final Color color;
  const _PriceChange(this.date, this.sku, this.reason, this.oldPrice, this.newPrice, this.color);
}
