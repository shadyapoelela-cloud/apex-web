import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 116 — E-Commerce Store Management (Shopify/Salla replacement)
class EcommerceStoreScreen extends StatefulWidget {
  const EcommerceStoreScreen({super.key});
  @override
  State<EcommerceStoreScreen> createState() => _EcommerceStoreScreenState();
}

class _EcommerceStoreScreenState extends State<EcommerceStoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'الطلبات'), Tab(text: 'المنتجات'), Tab(text: 'العملاء'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_ordersTab(), _productsTab(), _customersTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF00796B), Color(0xFF004D40)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.shopping_bag, color: Color(0xFF004D40), size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('المتجر الإلكتروني', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('إدارة الطلبات، المنتجات، العملاء — تكامل مع Salla وZid', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final totalSales = _orders.fold<double>(0, (s, o) => s + o.amount);
    final pending = _orders.where((o)=>o.status.contains('قيد')).length;
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('طلبات اليوم', '${_orders.length}', Icons.shopping_cart, const Color(0xFF00796B))),
      Expanded(child: _kpi('مبيعات اليوم', '${(totalSales/1000).toStringAsFixed(0)}K', Icons.attach_money, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('قيد التجهيز', '$pending', Icons.inventory, const Color(0xFFE65100))),
      Expanded(child: _kpi('عملاء نشطون', '2,840', Icons.people, const Color(0xFF4A148C))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _ordersTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _orders.length, itemBuilder: (_, i) {
    final o = _orders[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(o.status).withValues(alpha: 0.15), child: Icon(Icons.receipt, color: _statusColor(o.status))),
      title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${o.customer} • ${o.items} قطعة', style: const TextStyle(fontSize: 11)),
        Text('${o.paymentMethod} • ${o.shipping}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${o.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _statusColor(o.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(o.status, style: TextStyle(color: _statusColor(o.status), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _productsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _products.length, itemBuilder: (_, i) {
    final p = _products[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF00796B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.inventory_2, color: Color(0xFF00796B))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('SKU: ${p.sku} • ${p.category}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          Row(children: [
            _mini('السعر', '${p.price.toStringAsFixed(0)} ر.س'),
            _mini('مخزون', '${p.stock}'),
            _mini('مبيع', '${p.sold}'),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Icon(Icons.star, color: core_theme.AC.gold, size: 14),
          Text('${p.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${p.reviews} تقييم', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
        ]),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _customersTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _customers.length, itemBuilder: (_, i) {
    final c = _customers[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.1),
        child: Text(c.name.substring(0, 1), style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold))),
      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${c.email} • ${c.city}', style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${c.ordersCount} طلب', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        Text('${(c.lifetimeValue/1000).toStringAsFixed(1)}K ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🛒 قيمة السلة', 'متوسط 485 ر.س (+18% YoY)', const Color(0xFF2E7D32)),
    _insight('🚀 معدل التحويل', '4.2% من الزوار — أعلى من الصناعة (2.8%)', const Color(0xFF00796B)),
    _insight('📦 أسرع منتجات', 'عطور 18% • إلكترونيات 22% • أزياء 32% • أخرى 28%', core_theme.AC.gold),
    _insight('🎯 إعادة الشراء', '34% من العملاء متكررين', const Color(0xFF4A148C)),
    _insight('💳 طرق الدفع', 'مدى 52% • Apple Pay 18% • بطاقة 22% • تحويل 8%', const Color(0xFF1A237E)),
    _insight('📱 الأجهزة', 'جوال 78% • حاسوب 18% • لوحي 4%', const Color(0xFFE65100)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('مسلم') || s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('شحن')) return const Color(0xFF1A237E);
    if (s.contains('قيد')) return const Color(0xFFE65100);
    if (s.contains('ملغى')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  static const List<_Order> _orders = [
    _Order('#ORD-18452', 'أحمد العتيبي', 3, 485, 'مدى', 'أرامكس', 'مسلم'),
    _Order('#ORD-18453', 'فاطمة السبيعي', 1, 1_240, 'Apple Pay', 'SMSA', 'قيد الشحن'),
    _Order('#ORD-18454', 'محمد القحطاني', 5, 680, 'تحويل بنكي', 'SMSA', 'قيد التجهيز'),
    _Order('#ORD-18455', 'نورة الشمري', 2, 320, 'مدى', 'أرامكس', 'مسلم'),
    _Order('#ORD-18456', 'خالد الزهراني', 4, 890, 'بطاقة ائتمان', 'DHL', 'قيد الشحن'),
    _Order('#ORD-18457', 'سارة المهندس', 1, 245, 'مدى', 'SMSA', 'ملغى'),
    _Order('#ORD-18458', 'أحمد الغامدي', 8, 1_480, 'بطاقة ائتمان', 'أرامكس', 'مكتمل'),
    _Order('#ORD-18459', 'هند العتيبي', 2, 560, 'Apple Pay', 'SMSA', 'قيد التجهيز'),
  ];

  static const List<_Product> _products = [
    _Product('عطر الأصالة الملكي 100مل', 'PROD-001', 'عطور', 485, 128, 342, 4.8, 245),
    _Product('ساعة ذكية بريميوم', 'PROD-002', 'إلكترونيات', 1_240, 45, 180, 4.6, 112),
    _Product('قميص رجالي كلاسيكي', 'PROD-003', 'أزياء رجالية', 180, 320, 1_240, 4.5, 420),
    _Product('عباية حريرية', 'PROD-004', 'أزياء نسائية', 850, 85, 245, 4.9, 189),
    _Product('سماعات لاسلكية', 'PROD-005', 'إلكترونيات', 320, 156, 680, 4.4, 320),
    _Product('حقيبة جلدية فاخرة', 'PROD-006', 'إكسسوارات', 640, 72, 124, 4.7, 98),
    _Product('مبخرة كهربائية', 'PROD-007', 'منزل وديكور', 240, 240, 560, 4.6, 234),
  ];

  static const List<_Customer> _customers = [
    _Customer('أحمد العتيبي', 'ahmed@example.com', 'الرياض', 12, 8_450),
    _Customer('فاطمة السبيعي', 'fatma@example.com', 'جدة', 8, 6_820),
    _Customer('محمد القحطاني', 'mohammed@example.com', 'الدمام', 18, 12_340),
    _Customer('نورة الشمري', 'nourah@example.com', 'الرياض', 5, 2_450),
    _Customer('خالد الزهراني', 'khaled@example.com', 'مكة', 14, 9_820),
    _Customer('سارة المهندس', 'sarah@example.com', 'المدينة', 6, 3_680),
  ];
}

class _Order { final String id, customer; final int items; final double amount; final String paymentMethod, shipping, status;
  const _Order(this.id, this.customer, this.items, this.amount, this.paymentMethod, this.shipping, this.status); }
class _Product { final String name, sku, category; final double price; final int stock, sold; final double rating; final int reviews;
  const _Product(this.name, this.sku, this.category, this.price, this.stock, this.sold, this.rating, this.reviews); }
class _Customer { final String name, email, city; final int ordersCount; final double lifetimeValue;
  const _Customer(this.name, this.email, this.city, this.ordersCount, this.lifetimeValue); }
