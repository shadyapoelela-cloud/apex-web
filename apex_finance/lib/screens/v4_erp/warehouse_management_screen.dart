/// APEX Wave 104 — Warehouse Management System (WMS).
/// Route: /app/erp/operations/warehouse
///
/// Multi-warehouse stock, receipts, picks, putaway, transfers.
library;

import 'package:flutter/material.dart';

class WarehouseManagementScreen extends StatefulWidget {
  const WarehouseManagementScreen({super.key});
  @override
  State<WarehouseManagementScreen> createState() => _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState extends State<WarehouseManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _warehouses = const [
    _Warehouse('WH-01', 'المستودع الرئيسي — الرياض', 'الرياض', 12500, 8200, 72, Color(0xFFD4AF37)),
    _Warehouse('WH-02', 'مستودع جدة', 'جدة', 6800, 4500, 58, Colors.blue),
    _Warehouse('WH-03', 'مستودع الدمام', 'الدمام', 4200, 3100, 82, Colors.green),
    _Warehouse('WH-04', 'مستودع دبي — حرة', 'الإمارات', 3500, 2800, 65, Colors.purple),
  ];

  final _movements = const [
    _Movement('MVT-2026-0892', 'استلام بضاعة', 'inbound', 'WH-01', null, 'بولي بروبلين 20 طن', '2026-04-19 08:42', 'completed'),
    _Movement('MVT-2026-0891', 'تحويل داخلي', 'transfer', 'WH-01', 'WH-02', 'مواد تعبئة 3 طن', '2026-04-19 09:15', 'in-transit'),
    _Movement('MVT-2026-0890', 'صرف للعميل', 'outbound', 'WH-01', null, 'شحنة SABIC — طلب SO-8942', '2026-04-18 14:20', 'completed'),
    _Movement('MVT-2026-0889', 'إعادة من عميل', 'return', 'WH-02', null, 'إرجاع RMA-015 — 2 طن', '2026-04-18 11:05', 'inspecting'),
    _Movement('MVT-2026-0888', 'استلام بضاعة', 'inbound', 'WH-03', null, 'مواد خام من الهند', '2026-04-17 16:30', 'completed'),
    _Movement('MVT-2026-0887', 'تحويل داخلي', 'transfer', 'WH-01', 'WH-04', 'معدات IT — 12 قطعة', '2026-04-17 10:18', 'completed'),
    _Movement('MVT-2026-0886', 'صرف للعميل', 'outbound', 'WH-02', null, 'STC — شحنة شهرية', '2026-04-16 09:00', 'completed'),
    _Movement('MVT-2026-0885', 'فقد/تلف', 'adjustment', 'WH-01', null, 'تلف 50 كرتون أثناء النقل', '2026-04-15 13:45', 'completed'),
  ];

  final _items = const [
    _StockItem('SKU-100', 'بولي بروبلين — بلاستيك', 'WH-01', 4800, 'طن', 45000, 1500, 'in-stock'),
    _StockItem('SKU-101', 'إيثيلين — مادة خام', 'WH-01', 2100, 'طن', 38000, 800, 'in-stock'),
    _StockItem('SKU-102', 'ميثانول — كيماويات', 'WH-02', 850, 'طن', 52000, 300, 'in-stock'),
    _StockItem('SKU-103', 'كراتين تعبئة', 'WH-03', 12500, 'كرتون', 120, 3000, 'in-stock'),
    _StockItem('SKU-104', 'عبوات زجاجية', 'WH-01', 48, 'كرتون', 850, 200, 'low'),
    _StockItem('SKU-105', 'ملصقات', 'WH-02', 0, 'لفة', 125, 500, 'out-of-stock'),
    _StockItem('SKU-106', 'أحبار طباعة', 'WH-03', 240, 'لتر', 420, 180, 'in-stock'),
    _StockItem('SKU-107', 'قطع غيار — محركات', 'WH-04', 85, 'قطعة', 8500, 50, 'in-stock'),
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
        _buildKpis(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.warehouse, size: 16), text: 'المستودعات'),
            Tab(icon: Icon(Icons.inventory_2, size: 16), text: 'المخزون'),
            Tab(icon: Icon(Icons.swap_horiz, size: 16), text: 'الحركات'),
            Tab(icon: Icon(Icons.analytics, size: 16), text: 'تحليلات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildWarehousesTab(),
              _buildStockTab(),
              _buildMovementsTab(),
              _buildAnalyticsTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF795548)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.warehouse, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة المستودعات (WMS)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Warehouse Management — 4 مستودعات · استلام · صرف · تحويلات · تسويات',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final totalCapacity = _warehouses.fold(0, (s, w) => s + w.capacity);
    final totalUsed = _warehouses.fold(0, (s, w) => s + w.used);
    final lowStock = _items.where((i) => i.status == 'low').length;
    final outOfStock = _items.where((i) => i.status == 'out-of-stock').length;
    final totalValue = _items.fold(0.0, (s, i) => s + i.qty * i.unitCost);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('المستودعات', '${_warehouses.length}', Colors.blue, Icons.warehouse),
          _kpi('السعة المستخدمة', '${(totalUsed / totalCapacity * 100).toStringAsFixed(0)}%', const Color(0xFFD4AF37), Icons.inventory_2),
          _kpi('قيمة المخزون', _fmtM(totalValue), Colors.green, Icons.attach_money),
          _kpi('منخفض المخزون', '$lowStock', Colors.orange, Icons.warning),
          _kpi('نافد', '$outOfStock', Colors.red, Icons.error),
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
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehousesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _warehouses.length,
      itemBuilder: (ctx, i) {
        final w = _warehouses[i];
        final utilization = w.used / w.capacity;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: w.color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: w.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.warehouse, color: w.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(w.id, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black54)),
                        const SizedBox(width: 10),
                        Text(w.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(w.location, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(width: 14),
                        const Icon(Icons.category, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text('${w.skuCount} SKU', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${w.used} / ${w.capacity} m³',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                        const Spacer(),
                        Text('${(utilization * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: utilization > 0.9 ? Colors.red : utilization > 0.75 ? Colors.orange : w.color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: utilization,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(utilization > 0.9 ? Colors.red : utilization > 0.75 ? Colors.orange : w.color),
                      minHeight: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                    Expanded(flex: 3, child: Text('الصنف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المستودع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الوحدة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('تكلفة الوحدة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('القيمة الإجمالية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
                    Expanded(child: Text('نقطة الطلب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final i in _items) _itemRow(i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemRow(_StockItem i) {
    final statusColor = _stockStatusColor(i.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(i.sku, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text(i.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(i.warehouse, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            child: Text(_fmt(i.qty.toDouble()),
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: i.qty == 0 ? Colors.red : i.qty < i.reorderPoint ? Colors.orange : Colors.black87)),
          ),
          Expanded(child: Text(i.unit, style: const TextStyle(fontSize: 11, color: Colors.black54))),
          Expanded(child: Text(_fmt(i.unitCost.toDouble()), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(
            flex: 2,
            child: Text(_fmt(i.qty * i.unitCost.toDouble()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
          ),
          Expanded(child: Text(_fmt(i.reorderPoint.toDouble()), style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'))),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
              child: Text(_stockStatusLabel(i.status),
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _movements.length,
      itemBuilder: (ctx, i) {
        final m = _movements[i];
        final typeColor = _moveTypeColor(m.type);
        final statusColor = _moveStatusColor(m.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: typeColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: typeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_moveIcon(m.type), color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(m.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: typeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(m.typeLabel,
                              style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(m.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(m.warehouse,
                              style: const TextStyle(fontSize: 10, color: Colors.blue, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                        ),
                        if (m.toWarehouse != null) ...[
                          const Icon(Icons.arrow_forward, size: 12, color: Colors.black45),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                            child: Text(m.toWarehouse!,
                                style: const TextStyle(fontSize: 10, color: Colors.green, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    Text(m.timestamp, style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(_moveStatusLabel(m.status),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            _statCard('معدل دوران المخزون', '6.4x', '+0.8 YoY', Colors.green, Icons.sync),
            _statCard('أيام المخزون (DIO)', '57 يوم', '-6 يوم', Colors.blue, Icons.schedule),
            _statCard('دقة الجرد', '99.3%', 'ممتاز', const Color(0xFFD4AF37), Icons.check_circle),
            _statCard('المخزون الراكد', '3.8%', '-1.2pp', Colors.orange, Icons.warning),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights, color: Color(0xFFD4AF37)),
                  SizedBox(width: 8),
                  Text('أهم تحليلات المخزون', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              _insight('🔥 أسرع الأصناف حركة', 'بولي بروبلين (SKU-100) — معدل دوران 12x/سنة', Colors.red),
              _insight('🐢 أبطأ الأصناف', 'قطع غيار المحركات (SKU-107) — دوران 1.2x/سنة', Colors.orange),
              _insight('⚠️ تنبيه إعادة طلب', '3 أصناف بحاجة إعادة طلب عاجلة', Colors.amber),
              _insight('🎯 توصية AI', 'نقل 15% من مخزون WH-03 إلى WH-02 لتحسين التوزيع', Colors.blue),
              _insight('💰 الأعلى قيمة', 'ميثانول (SKU-102) — 44.2M ر.س (43% من إجمالي القيمة)', const Color(0xFFD4AF37)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, String note, Color color, IconData icon) {
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
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(note, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _insight(String title, String detail, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                Text(detail, style: const TextStyle(fontSize: 11, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _stockStatusColor(String s) {
    switch (s) {
      case 'in-stock':
        return Colors.green;
      case 'low':
        return Colors.orange;
      case 'out-of-stock':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _stockStatusLabel(String s) {
    switch (s) {
      case 'in-stock':
        return 'متوفر';
      case 'low':
        return 'منخفض';
      case 'out-of-stock':
        return 'نافد';
      default:
        return s;
    }
  }

  Color _moveTypeColor(String t) {
    switch (t) {
      case 'inbound':
        return Colors.green;
      case 'outbound':
        return Colors.orange;
      case 'transfer':
        return Colors.blue;
      case 'return':
        return Colors.purple;
      case 'adjustment':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _moveIcon(String t) {
    switch (t) {
      case 'inbound':
        return Icons.arrow_downward;
      case 'outbound':
        return Icons.arrow_upward;
      case 'transfer':
        return Icons.swap_horiz;
      case 'return':
        return Icons.assignment_return;
      case 'adjustment':
        return Icons.edit;
      default:
        return Icons.circle;
    }
  }

  Color _moveStatusColor(String s) {
    switch (s) {
      case 'completed':
        return Colors.green;
      case 'in-transit':
        return Colors.orange;
      case 'inspecting':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _moveStatusLabel(String s) {
    switch (s) {
      case 'completed':
        return 'مكتمل';
      case 'in-transit':
        return 'في الطريق';
      case 'inspecting':
        return 'قيد الفحص';
      default:
        return s;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M ر.س';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _Warehouse {
  final String id;
  final String name;
  final String location;
  final int capacity;
  final int used;
  final int skuCount;
  final Color color;
  const _Warehouse(this.id, this.name, this.location, this.capacity, this.used, this.skuCount, this.color);
}

class _Movement {
  final String id;
  final String typeLabel;
  final String type;
  final String warehouse;
  final String? toWarehouse;
  final String description;
  final String timestamp;
  final String status;
  const _Movement(this.id, this.typeLabel, this.type, this.warehouse, this.toWarehouse, this.description, this.timestamp, this.status);
}

class _StockItem {
  final String sku;
  final String name;
  final String warehouse;
  final int qty;
  final String unit;
  final int unitCost;
  final int reorderPoint;
  final String status;
  const _StockItem(this.sku, this.name, this.warehouse, this.qty, this.unit, this.unitCost, this.reorderPoint, this.status);
}
