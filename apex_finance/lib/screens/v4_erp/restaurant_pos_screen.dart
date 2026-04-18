import 'package:flutter/material.dart';

/// 🎉 Wave 120 — Restaurant POS (Foodics-killer) MILESTONE
class RestaurantPosScreen extends StatefulWidget {
  const RestaurantPosScreen({super.key});
  @override
  State<RestaurantPosScreen> createState() => _RestaurantPosScreenState();
}

class _RestaurantPosScreenState extends State<RestaurantPosScreen> with SingleTickerProviderStateMixin {
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
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37), indicatorWeight: 3,
          tabs: const [Tab(text: 'الطاولات'), Tab(text: 'القائمة'), Tab(text: 'الطلبات'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_tablesTab(), _menuTab(), _ordersTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD84315), Color(0xFFBF360C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.restaurant, color: Color(0xFFBF360C), size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نظام نقاط بيع المطاعم 🎉 Wave 120', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('طاولات، طلبات، مطبخ، توصيل — متعدد الفروع', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final sales = _orders.where((o)=>o.status.contains('مدفوع')).fold<double>(0, (s, o) => s + o.total);
    final occupied = _tables.where((t)=>t.status.contains('مشغول')).length;
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('مبيعات اليوم', '${(sales/1000).toStringAsFixed(1)}K', Icons.attach_money, const Color(0xFFBF360C))),
      Expanded(child: _kpi('طاولات مشغولة', '$occupied/${_tables.length}', Icons.table_restaurant, const Color(0xFFD4AF37))),
      Expanded(child: _kpi('طلبات نشطة', '${_orders.where((o)=>o.status.contains('قيد')).length}', Icons.kitchen, const Color(0xFF4A148C))),
      Expanded(child: _kpi('متوسط الفاتورة', '185 ر.س', Icons.receipt, const Color(0xFF2E7D32))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _tablesTab() => Padding(padding: const EdgeInsets.all(12),
    child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _tables.length, itemBuilder: (_, i) {
      final t = _tables[i]; final color = _tableColor(t.status);
      return Card(color: color.withValues(alpha: 0.1), child: Padding(padding: const EdgeInsets.all(10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_restaurant, color: color, size: 32),
          Text('T-${t.number}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          Text('${t.seats} مقعد', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(t.status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
          if (t.currentOrder > 0) Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('${t.currentOrder.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        ]),
      ));
    }),
  );

  Widget _menuTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _menu.length, itemBuilder: (_, i) {
    final m = _menu[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _categoryColor(m.category).withValues(alpha: 0.15),
        child: Icon(_categoryIcon(m.category), color: _categoryColor(m.category))),
      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('${m.category} • بيع اليوم: ${m.soldToday}', style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${m.price.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBF360C))),
        if (m.available) const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 14)
        else const Icon(Icons.cancel, color: Color(0xFFC62828), size: 14),
      ]),
    ));
  });

  Widget _ordersTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _orders.length, itemBuilder: (_, i) {
    final o = _orders[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_orderIcon(o.type), color: const Color(0xFFBF360C)),
          const SizedBox(width: 8),
          Expanded(child: Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text('${o.total.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        ]),
        Text('${o.type} • ${o.table} • ${o.items} صنف', style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _orderStatus(o.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(o.status, style: TextStyle(color: _orderStatus(o.status), fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🍽️ أوقات الذروة', 'الغداء 12-14 • العشاء 20-22 — 68% من المبيعات', const Color(0xFFBF360C)),
    _insight('🥇 الأكثر مبيعاً', 'كبسة لحم 18% • شاورما دجاج 14% • برياني 12%', const Color(0xFFD4AF37)),
    _insight('⏱️ زمن التحضير', 'متوسط 14 دقيقة (الهدف 15)', const Color(0xFF2E7D32)),
    _insight('💰 نمو سنوي', '+24% YoY على مستوى الفروع', const Color(0xFF4A148C)),
    _insight('📱 طلبات التوصيل', '42% عبر Jahez + HungerStation + Keeta', const Color(0xFF1A237E)),
    _insight('🎉 Milestone', 'وصلنا Wave 120 — 120 شاشة إنتاجية!', const Color(0xFFD4AF37)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _tableColor(String s) {
    if (s.contains('متاح')) return const Color(0xFF2E7D32);
    if (s.contains('مشغول')) return const Color(0xFFBF360C);
    if (s.contains('محجوز')) return const Color(0xFFD4AF37);
    if (s.contains('تنظيف')) return const Color(0xFF1A237E);
    return Colors.black54;
  }

  Color _categoryColor(String c) {
    if (c.contains('رئيسية')) return const Color(0xFFBF360C);
    if (c.contains('مقبلات')) return const Color(0xFFD4AF37);
    if (c.contains('حلويات')) return const Color(0xFF4A148C);
    if (c.contains('مشروبات')) return const Color(0xFF1A237E);
    return const Color(0xFF2E7D32);
  }

  IconData _categoryIcon(String c) {
    if (c.contains('رئيسية')) return Icons.dinner_dining;
    if (c.contains('مقبلات')) return Icons.lunch_dining;
    if (c.contains('حلويات')) return Icons.cake;
    if (c.contains('مشروبات')) return Icons.local_drink;
    return Icons.restaurant_menu;
  }

  IconData _orderIcon(String t) {
    if (t.contains('صالة')) return Icons.dinner_dining;
    if (t.contains('توصيل')) return Icons.delivery_dining;
    if (t.contains('سفري')) return Icons.takeout_dining;
    return Icons.receipt;
  }

  Color _orderStatus(String s) {
    if (s.contains('مدفوع')) return const Color(0xFF2E7D32);
    if (s.contains('قيد التحضير')) return const Color(0xFFE65100);
    if (s.contains('جاهز')) return const Color(0xFFD4AF37);
    return const Color(0xFF1A237E);
  }

  static const List<_Table> _tables = [
    _Table(1, 4, 285, 'مشغول'),
    _Table(2, 2, 0, 'متاح'),
    _Table(3, 6, 842, 'مشغول'),
    _Table(4, 4, 0, 'تنظيف'),
    _Table(5, 8, 0, 'محجوز'),
    _Table(6, 2, 145, 'مشغول'),
    _Table(7, 4, 0, 'متاح'),
    _Table(8, 6, 520, 'مشغول'),
    _Table(9, 2, 0, 'متاح'),
    _Table(10, 10, 1250, 'مشغول'),
    _Table(11, 4, 0, 'متاح'),
    _Table(12, 4, 0, 'محجوز'),
  ];

  static const List<_MenuItem> _menu = [
    _MenuItem('كبسة لحم', 'وجبة رئيسية', 85, 42, true),
    _MenuItem('شاورما دجاج', 'وجبة رئيسية', 35, 68, true),
    _MenuItem('برياني سعودي', 'وجبة رئيسية', 75, 38, true),
    _MenuItem('تبولة', 'مقبلات', 25, 24, true),
    _MenuItem('حمص', 'مقبلات', 20, 32, true),
    _MenuItem('كنافة بالقشطة', 'حلويات', 35, 28, true),
    _MenuItem('أم علي', 'حلويات', 30, 18, false),
    _MenuItem('ليمون بالنعناع', 'مشروبات', 15, 82, true),
    _MenuItem('قهوة عربية', 'مشروبات', 12, 120, true),
    _MenuItem('كوكاكولا', 'مشروبات', 8, 145, true),
  ];

  static const List<_PosOrder> _orders = [
    _PosOrder('#2045', 'صالة', 'طاولة 1', 4, 285, 'مدفوع'),
    _PosOrder('#2046', 'صالة', 'طاولة 3', 8, 842, 'قيد التحضير'),
    _PosOrder('#2047', 'توصيل', 'Jahez', 3, 145, 'جاهز للتوصيل'),
    _PosOrder('#2048', 'صالة', 'طاولة 8', 6, 520, 'مدفوع'),
    _PosOrder('#2049', 'سفري', 'كاشير', 2, 85, 'قيد التحضير'),
    _PosOrder('#2050', 'صالة', 'طاولة 10', 12, 1250, 'قيد التحضير'),
    _PosOrder('#2051', 'توصيل', 'HungerStation', 4, 180, 'مدفوع'),
    _PosOrder('#2052', 'صالة', 'طاولة 6', 2, 145, 'جاهز'),
  ];
}

class _Table { final int number, seats; final double currentOrder; final String status;
  const _Table(this.number, this.seats, this.currentOrder, this.status); }
class _MenuItem { final String name, category; final double price; final int soldToday; final bool available;
  const _MenuItem(this.name, this.category, this.price, this.soldToday, this.available); }
class _PosOrder { final String id, type, table; final int items; final double total; final String status;
  const _PosOrder(this.id, this.type, this.table, this.items, this.total, this.status); }
