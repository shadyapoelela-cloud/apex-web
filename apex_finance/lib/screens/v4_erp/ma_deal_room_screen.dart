import 'package:flutter/material.dart';

/// Wave 128 — M&A Deal Room / Due Diligence
class MaDealRoomScreen extends StatefulWidget {
  const MaDealRoomScreen({super.key});
  @override
  State<MaDealRoomScreen> createState() => _MaDealRoomScreenState();
}

class _MaDealRoomScreenState extends State<MaDealRoomScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'الصفقات'), Tab(text: 'غرفة البيانات'), Tab(text: 'العناية الواجبة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_dealsTab(), _docsTab(), _ddTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.handshake, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('غرفة صفقات M&A', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('عمليات الاستحواذ، Virtual Data Room، العناية الواجبة', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final totalValue = _deals.fold<double>(0, (s, d) => s + d.dealValue);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('صفقات نشطة', '${_deals.where((d)=>d.status.contains('نشط') || d.status.contains('مفاوضة')).length}', Icons.handshake, const Color(0xFF0D47A1))),
      Expanded(child: _kpi('قيمة الصفقات', '${(totalValue/1000000).toStringAsFixed(0)}M', Icons.attach_money, const Color(0xFFD4AF37))),
      Expanded(child: _kpi('وثائق', '${_docs.length}', Icons.folder, const Color(0xFF4A148C))),
      Expanded(child: _kpi('مستخدمون', '28', Icons.people, const Color(0xFF2E7D32))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _dealsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _deals.length, itemBuilder: (_, i) {
    final d = _deals[i]; final progress = d.progress / 100;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _dealStatus(d.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(_dealIcon(d.type), color: _dealStatus(d.status))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.target, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${d.type} • ${d.advisor}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          Text('${(d.dealValue/1000000).toStringAsFixed(0)}M', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37), fontSize: 16)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _dealStatus(d.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(d.status, style: TextStyle(color: _dealStatus(d.status), fontSize: 10, fontWeight: FontWeight.bold))),
          const Spacer(),
          Text('Close: ${d.expectedClose}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.black12, valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)))),
        const SizedBox(height: 4),
        Text('${d.progress}% مكتمل', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _docsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _docs.length, itemBuilder: (_, i) {
    final d = _docs[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: CircleAvatar(backgroundColor: _folderColor(d.folder).withValues(alpha: 0.15), child: Icon(Icons.insert_drive_file, color: _folderColor(d.folder))),
      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      subtitle: Text('${d.folder} • ${d.size} • ${d.views} مشاهدة', style: const TextStyle(fontSize: 10)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: _accessColor(d.access).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(d.access, style: TextStyle(color: _accessColor(d.access), fontSize: 9, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _ddTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _dd.length, itemBuilder: (_, i) {
    final d = _dd[i]; final progress = d.itemsCompleted / d.totalItems;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(d.icon, color: const Color(0xFF4A148C), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(d.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Text('${d.itemsCompleted}/${d.totalItems}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.black12, valueColor: AlwaysStoppedAnimation(d.status.contains('مكتمل') ? const Color(0xFF2E7D32) : const Color(0xFFD4AF37)))),
        const SizedBox(height: 4),
        Text(d.notes, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('💼 Pipeline', '4 صفقات نشطة بقيمة إجمالية 485M ر.س', const Color(0xFF0D47A1)),
    _insight('⏱️ متوسط الإغلاق', '6.4 شهر من التوقيع لإقفال الصفقة', const Color(0xFFD4AF37)),
    _insight('📄 DD Efficiency', '92% وثائق مراجعة — السرعة 3x أعلى مع AI', const Color(0xFF4A148C)),
    _insight('🔐 الأمان', 'تشفير AES-256 + MFA إلزامي • 0 اختراقات', const Color(0xFF2E7D32)),
    _insight('📊 Valuation Multiples', 'قطاع ERP: 4-6x ARR • النظراء الإقليميون 4.2x', const Color(0xFF1A237E)),
    _insight('🎯 نجاح الصفقات', '73% من الصفقات المُوقّعة تُغلق بنجاح', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _dealStatus(String s) {
    if (s.contains('مغلق')) return const Color(0xFF2E7D32);
    if (s.contains('مفاوضة')) return const Color(0xFFE65100);
    if (s.contains('نشط')) return const Color(0xFFD4AF37);
    if (s.contains('معلق')) return const Color(0xFFC62828);
    return const Color(0xFF1A237E);
  }

  IconData _dealIcon(String t) {
    if (t.contains('استحواذ')) return Icons.merge_type;
    if (t.contains('استثمار')) return Icons.trending_up;
    if (t.contains('اندماج')) return Icons.call_merge;
    if (t.contains('تخارج')) return Icons.call_split;
    return Icons.handshake;
  }

  Color _folderColor(String f) {
    if (f.contains('مالية')) return const Color(0xFF2E7D32);
    if (f.contains('قانونية')) return const Color(0xFF4A148C);
    if (f.contains('تجارية')) return const Color(0xFFD4AF37);
    if (f.contains('تقنية')) return const Color(0xFF1A237E);
    return Colors.black54;
  }

  Color _accessColor(String a) {
    if (a.contains('كامل')) return const Color(0xFF2E7D32);
    if (a.contains('Q&A')) return const Color(0xFFD4AF37);
    if (a.contains('عرض')) return const Color(0xFF1A237E);
    if (a.contains('محظور')) return const Color(0xFFC62828);
    return Colors.black54;
  }

  static const List<_Deal> _deals = [
    _Deal('شركة التقنية المتقدمة', 'استحواذ', 285_000_000, 'Morgan Stanley', 68, '2026-09-30', 'مفاوضة نشطة'),
    _Deal('مجموعة الحلول الذكية', 'استثمار حصة 35%', 85_000_000, 'JP Morgan', 42, '2026-07-15', 'DD قيد التنفيذ'),
    _Deal('Apex Tech Lab (منافس)', 'استحواذ كامل', 115_000_000, 'Goldman Sachs', 88, '2026-05-20', 'مفاوضة نهائية'),
    _Deal('SaaS Startup مصر', 'استحواذ جزئي', 28_000_000, 'EFG Hermes', 15, '2026-11-30', 'نشط'),
    _Deal('قسم الاستشارات - خروج', 'تخارج جزئي', 48_000_000, 'HSBC', 0, 'معلق', 'معلق'),
    _Deal('Tech Partner UAE', 'اندماج استراتيجي', 182_000_000, 'Rothschild', 95, '2026-04-30', 'مغلق'),
  ];

  static const List<_Doc> _docs = [
    _Doc('القوائم المالية المدققة 2023-2025', 'مالية', '12.4 MB', 128, 'كامل'),
    _Doc('تقرير المراجع الخارجي', 'مالية', '8.2 MB', 95, 'كامل'),
    _Doc('جميع العقود الفعّالة', 'قانونية', '45.8 MB', 62, 'Q&A فقط'),
    _Doc('تقارير التسعير التحويلي', 'مالية', '6.8 MB', 42, 'Q&A فقط'),
    _Doc('براءات الاختراع والملكية الفكرية', 'قانونية', '2.4 MB', 38, 'عرض فقط'),
    _Doc('خطة الأعمال 2026-2030', 'تجارية', '18.2 MB', 85, 'كامل'),
    _Doc('تحليل التنافسية السوقية', 'تجارية', '4.8 MB', 72, 'كامل'),
    _Doc('الهندسة المعمارية التقنية', 'تقنية', '3.2 MB', 28, 'محظور'),
    _Doc('كود المصدر (قراءة فقط)', 'تقنية', '245 MB', 12, 'محظور'),
    _Doc('قائمة الموظفين الرئيسيين', 'قانونية', '1.8 MB', 42, 'عرض فقط'),
  ];

  static const List<_DD> _dd = [
    _DD('العناية المالية', Icons.account_balance, 42, 48, 'مكتمل تقريباً', 'القوائم المدققة نظيفة — ملاحظة على التسعير التحويلي'),
    _DD('العناية القانونية', Icons.gavel, 28, 35, 'جيد', '3 دعاوى نشطة — تقدير مخاطر 2.8M ر.س'),
    _DD('العناية التجارية', Icons.business, 18, 22, 'جيد', 'Pipeline قوي، تركز العملاء مقلق (40% أعلى 3)'),
    _DD('العناية التقنية', Icons.computer, 12, 18, 'قيد التنفيذ', 'الكود نظيف، الديون التقنية مقبولة'),
    _DD('العناية التنظيمية', Icons.shield, 15, 18, 'مكتمل', 'ZATCA + SDAIA + CMA — لا مخالفات'),
    _DD('العناية البشرية', Icons.people, 8, 20, 'قيد التنفيذ', 'معدل دوران 18% — أعلى من الصناعة'),
  ];
}

class _Deal { final String target, type; final double dealValue; final String advisor; final int progress; final String expectedClose, status;
  const _Deal(this.target, this.type, this.dealValue, this.advisor, this.progress, this.expectedClose, this.status); }
class _Doc { final String name, folder, size; final int views; final String access;
  const _Doc(this.name, this.folder, this.size, this.views, this.access); }
class _DD { final String category; final IconData icon; final int itemsCompleted, totalItems; final String status, notes;
  const _DD(this.category, this.icon, this.itemsCompleted, this.totalItems, this.status, this.notes); }
