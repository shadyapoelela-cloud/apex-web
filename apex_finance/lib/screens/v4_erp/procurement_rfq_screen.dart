import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 143 — Procurement / RFQ Workflow
class ProcurementRfqScreen extends StatefulWidget {
  const ProcurementRfqScreen({super.key});
  @override
  State<ProcurementRfqScreen> createState() => _ProcurementRfqScreenState();
}

class _ProcurementRfqScreenState extends State<ProcurementRfqScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'RFQ نشطة'), Tab(text: 'مقارنة العروض'), Tab(text: 'الموردون'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_rfqTab(), _compareTab(), _suppliersTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.shopping_cart, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('المشتريات RFQ', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Request for Quotation — مقارنة عروض الموردين تلقائياً', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('RFQ نشطة', '${_rfqs.length}', Icons.assignment, const Color(0xFF4A148C))),
    Expanded(child: _kpi('موردون نشطون', '48', Icons.business, const Color(0xFF1A237E))),
    Expanded(child: _kpi('توفير محقق', '18.4%', Icons.savings, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('زمن الدورة', '8 أيام', Icons.speed, core_theme.AC.gold)),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _rfqTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _rfqs.length, itemBuilder: (_, i) {
    final r = _rfqs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(r.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(r.status, style: TextStyle(color: _statusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        Text('${r.id} • ${r.category}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 10),
        Row(children: [
          _mini('الميزانية', r.budget),
          _mini('الكمية', r.quantity),
          _mini('الموعد', r.deadline),
          _mini('عروض', '${r.bidsCount}'),
        ]),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _compareTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Text('RFQ-2026-0042: توريد أجهزة كمبيوتر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A148C))),
    const SizedBox(height: 12),
    ..._bids.map((b) => Card(margin: const EdgeInsets.only(bottom: 8), color: b.recommended ? core_theme.AC.gold.withValues(alpha: 0.05) : null,
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
              child: Text(b.supplier.substring(0, 1), style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.supplier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Row(children: [
                Icon(Icons.star, color: core_theme.AC.gold, size: 12),
                Text(' ${b.rating}', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                Text('${b.historyDeals} صفقة سابقة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ]),
            ])),
            if (b.recommended) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(8)),
              child: Text('موصى به AI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _mini('السعر', b.price),
            _mini('التسليم', b.delivery),
            _mini('الضمان', b.warranty),
            _mini('الدفع', b.paymentTerms),
          ]),
          const SizedBox(height: 8),
          Text(b.notes, style: TextStyle(fontSize: 11, color: core_theme.AC.tp)),
        ]),
      ),
    )),
  ]);

  Widget _suppliersTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _suppliers.length, itemBuilder: (_, i) {
    final s = _suppliers[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _tierColor(s.tier).withValues(alpha: 0.2), child: Icon(Icons.business, color: _tierColor(s.tier))),
      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${s.category} • آخر تعامل: ${s.lastDeal}', style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _tierColor(s.tier).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(s.tier, style: TextStyle(color: _tierColor(s.tier), fontSize: 9, fontWeight: FontWeight.bold))),
        const SizedBox(height: 2),
        Row(children: [Icon(Icons.star, color: core_theme.AC.gold, size: 12), Text(' ${s.rating}', style: const TextStyle(fontSize: 11))]),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('💰 توفير سنوي', '2.8M ر.س توفير من مقارنة RFQ (+14% YoY)', const Color(0xFF2E7D32)),
    _insight('⏱️ زمن الدورة', '8 أيام متوسط من RFQ للـ PO (انخفاض 42% بعد الأتمتة)', core_theme.AC.gold),
    _insight('🎯 معدل الفوز للموردين', 'مورد "أ" 38% • مورد "ب" 28% • مورد "ج" 18% • أخرى 16%', const Color(0xFF4A148C)),
    _insight('📊 توزيع الإنفاق', 'تقنية 42% • مواد خام 28% • خدمات 18% • أخرى 12%', const Color(0xFF1A237E)),
    _insight('⚠️ تركيز الموردين', 'Top 3 موردين = 62% من الإنفاق — مخاطر تركّز', const Color(0xFFE65100)),
    _insight('✅ نسبة العقود الإلكترونية', '94% من RFQs تُدار رقمياً — حفظ 8 ساعات/RFQ', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('تقييم')) return core_theme.AC.gold;
    if (s.contains('ترسية')) return const Color(0xFF4A148C);
    if (s.contains('ملغى')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  Color _tierColor(String t) {
    if (t.contains('Gold')) return core_theme.AC.gold;
    if (t.contains('Silver')) return core_theme.AC.td;
    if (t.contains('Bronze')) return const Color(0xFF6D4C41);
    return core_theme.AC.ts;
  }

  static const List<_Rfq> _rfqs = [
    _Rfq('RFQ-2026-0042', 'توريد 100 جهاز كمبيوتر', 'تقنية', '850,000 - 1,200,000 ر.س', '100 جهاز', '2026-05-15', 8, 'نشط - مفتوح'),
    _Rfq('RFQ-2026-0041', 'خدمات أمن سيبراني سنوية', 'خدمات تقنية', '450,000 ر.س', '12 شهر', '2026-05-01', 5, 'تقييم العروض'),
    _Rfq('RFQ-2026-0040', 'مواد تعبئة وتغليف', 'مواد خام', '220,000 - 280,000 ر.س', '50,000 قطعة', '2026-04-25', 12, 'تقييم العروض'),
    _Rfq('RFQ-2026-0039', 'خدمات نظافة للمكتب الرئيسي', 'خدمات', '180,000 ر.س سنوي', 'خدمة سنوية', '2026-04-20', 6, 'ترسية'),
    _Rfq('RFQ-2026-0038', 'تطوير تطبيق iOS', 'تقنية', '380,000 - 480,000 ر.س', 'مشروع كامل', '2026-04-30', 9, 'نشط - مفتوح'),
  ];

  static const List<_Bid> _bids = [
    _Bid('شركة التقنية المتقدمة', '925,000 ر.س', '14 يوم', '3 سنوات', 'Net 30', 4.8, 18, true,
      'سعر تنافسي + ضمان موسّع + دعم فني 24/7. تجربة سابقة ممتازة مع عقود مماثلة.'),
    _Bid('Al-Falak Computing', '980,000 ر.س', '7 أيام', '3 سنوات', 'Net 45', 4.6, 12, false,
      'تسليم سريع + سعر أعلى قليلاً. تاريخ جيد لكن أقل من الموصى به'),
    _Bid('مجموعة النخبة للتقنية', '880,000 ر.س', '21 يوم', '2 سنوات', 'Net 60', 4.2, 5, false,
      'السعر الأقل لكن تاريخ قصير + ضمان أقل. مخاطر متوسطة'),
    _Bid('شركة الحلول الذكية', '1,050,000 ر.س', '10 أيام', '4 سنوات', '50% مقدم', 4.9, 22, false,
      'أعلى سعر لكن ضمان ممتاز + تاريخ طويل. شروط دفع صعبة'),
  ];

  static const List<_Supplier> _suppliers = [
    _Supplier('شركة التقنية المتقدمة', 'تقنية وأجهزة', 'Gold', 4.8, '2026-03-15'),
    _Supplier('مجموعة الإمداد العربية', 'مواد خام', 'Gold', 4.7, '2026-04-01'),
    _Supplier('Al-Falak Computing', 'تقنية', 'Silver', 4.6, '2026-02-20'),
    _Supplier('شركة النخبة للخدمات', 'خدمات عامة', 'Silver', 4.5, '2026-01-10'),
    _Supplier('مؤسسة الابتكار', 'استشارات', 'Silver', 4.4, '2025-12-05'),
    _Supplier('TechSource Global', 'استيراد', 'Bronze', 4.2, '2025-11-20'),
    _Supplier('شركة الحلول الذكية', 'تطوير برمجي', 'Gold', 4.9, '2026-04-10'),
    _Supplier('مجموعة الإنجاز', 'لوجستيات', 'Silver', 4.3, '2026-03-01'),
  ];
}

class _Rfq { final String id, title, category, budget, quantity, deadline; final int bidsCount; final String status;
  const _Rfq(this.id, this.title, this.category, this.budget, this.quantity, this.deadline, this.bidsCount, this.status); }
class _Bid { final String supplier, price, delivery, warranty, paymentTerms; final double rating; final int historyDeals; final bool recommended; final String notes;
  const _Bid(this.supplier, this.price, this.delivery, this.warranty, this.paymentTerms, this.rating, this.historyDeals, this.recommended, this.notes); }
class _Supplier { final String name, category, tier; final double rating; final String lastDeal;
  const _Supplier(this.name, this.category, this.tier, this.rating, this.lastDeal); }
