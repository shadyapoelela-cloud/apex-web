import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 133 — Financial Statements Upload + OCR
class FinancialUploadScreen extends StatefulWidget {
  const FinancialUploadScreen({super.key});
  @override
  State<FinancialUploadScreen> createState() => _FinancialUploadScreenState();
}

class _FinancialUploadScreenState extends State<FinancialUploadScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'رفع ملفات'), Tab(text: 'قوالب جاهزة'), Tab(text: 'نتائج OCR'), Tab(text: 'السجل')])),
        Expanded(child: TabBarView(controller: _tc, children: [_uploadTab(), _templatesTab(), _ocrTab(), _historyTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.cloud_upload, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رفع القوائم المالية + OCR', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('قراءة ذكية لـ PDF/Excel/صور — AI يستخرج البيانات تلقائياً', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('ملفات مرفوعة', '${_files.length}', Icons.folder, const Color(0xFF1B5E20))),
    Expanded(child: _kpi('دقة OCR', '96.8%', Icons.verified, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('قوالب', '${_templates.length}', Icons.description, core_theme.AC.gold)),
    Expanded(child: _kpi('معالجة تلقائية', '89%', Icons.auto_awesome, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _uploadTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E7D32), width: 2, style: BorderStyle.solid),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_upload, color: Color(0xFF2E7D32), size: 64),
        const SizedBox(height: 12),
        Text('اسحب ملفاتك هنا أو اضغط للاختيار',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text('PDF • Excel • Word • صور JPG/PNG', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.folder_open),
          label: Text('اختر ملفاً'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ]),
    )),
    const SizedBox(height: 14),
    Text('📤 ملفات قيد المعالجة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 8),
    ..._files.where((f) => f.status.contains('معالجة')).map((f) => _fileCard(f)),
    const SizedBox(height: 14),
    Text('✅ ملفات مكتملة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 8),
    ..._files.where((f) => f.status.contains('مكتمل')).map((f) => _fileCard(f)),
  ]);

  Widget _fileCard(_FileRec f) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
    leading: CircleAvatar(backgroundColor: _statusColor(f.status).withValues(alpha: 0.15),
      child: Icon(_fileIcon(f.type), color: _statusColor(f.status))),
    title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    subtitle: Text('${f.type} • ${f.size} • ${f.uploadDate}', style: const TextStyle(fontSize: 11)),
    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: _statusColor(f.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(f.status, style: TextStyle(color: _statusColor(f.status), fontSize: 10, fontWeight: FontWeight.bold))),
      Text('${f.confidence}%', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
    ]),
  ));

  Widget _templatesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _templates.length, itemBuilder: (_, i) {
    final t = _templates[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: core_theme.AC.gold, child: Icon(Icons.description, color: Colors.white)),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(t.description, style: const TextStyle(fontSize: 11)),
      trailing: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.download, size: 14),
        label: Text(t.format),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    ));
  });

  Widget _ocrTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _extractions.length, itemBuilder: (_, i) {
    final e = _extractions[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(e.source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _confColor(e.confidence).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('${e.confidence}%', style: TextStyle(color: _confColor(e.confidence), fontWeight: FontWeight.bold, fontSize: 11))),
        ]),
        const SizedBox(height: 8),
        ...e.fields.map((f) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
          Expanded(child: Text('• ${f.$1}', style: const TextStyle(fontSize: 11.5))),
          Text(f.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
        ]))),
      ]),
    ));
  });

  Widget _historyTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _history.length, itemBuilder: (_, i) {
    final h = _history[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: Icon(Icons.history, color: _statusColor(h.$3)),
      title: Text(h.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text('${h.$2} • ${h.$3}', style: const TextStyle(fontSize: 10)),
      trailing: Text(h.$4, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
    ));
  });

  Color _statusColor(String s) {
    if (s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('معالجة')) return const Color(0xFFE65100);
    if (s.contains('فشل')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  Color _confColor(int c) {
    if (c >= 90) return const Color(0xFF2E7D32);
    if (c >= 75) return core_theme.AC.gold;
    return const Color(0xFFC62828);
  }

  IconData _fileIcon(String t) {
    if (t.contains('PDF')) return Icons.picture_as_pdf;
    if (t.contains('Excel')) return Icons.grid_on;
    if (t.contains('صورة')) return Icons.image;
    if (t.contains('Word')) return Icons.description;
    return Icons.insert_drive_file;
  }

  static const List<_FileRec> _files = [
    _FileRec('ميزان مراجعة 2025.xlsx', 'Excel', '2.4 MB', '2026-04-18 14:22', 'مكتمل', 98),
    _FileRec('قائمة الدخل Q4.pdf', 'PDF', '480 KB', '2026-04-18 14:15', 'مكتمل', 96),
    _FileRec('القوائم المالية 2024.pdf', 'PDF', '8.2 MB', '2026-04-18 14:10', 'مكتمل', 94),
    _FileRec('ميزانية عمومية.jpg', 'صورة', '3.1 MB', '2026-04-19 09:05', 'قيد المعالجة', 0),
    _FileRec('كشف بنك مايو.pdf', 'PDF', '1.2 MB', '2026-04-19 09:10', 'قيد المعالجة', 0),
    _FileRec('قائمة AR aging.xlsx', 'Excel', '680 KB', '2026-04-17 10:30', 'مكتمل', 99),
  ];

  static const List<_Template> _templates = [
    _Template('قالب قائمة الدخل - IFRS', 'تنسيق معتمد من هيئة المحاسبة السعودية', 'Excel'),
    _Template('قالب الميزانية العمومية', 'مع توزيع Long-term/Current تلقائي', 'Excel'),
    _Template('قالب قائمة التدفقات النقدية', 'طريقة غير مباشرة (IAS 7)', 'Excel'),
    _Template('قالب ميزان المراجعة', 'مع مجموعات IFRS + Zakat', 'Excel'),
    _Template('قالب التسوية البنكية', 'مطابق لمعايير ZATCA', 'Excel'),
    _Template('قالب Aging AR/AP', 'تقسيم مرن للفترات العمرية', 'Excel'),
    _Template('قالب الأصول الثابتة', 'مع حساب الإهلاك الآلي', 'Excel'),
  ];

  static const List<_Extraction> _extractions = [
    _Extraction('ميزان مراجعة 2025.xlsx', 98, [
      ('إجمالي الأصول', '18.4M ر.س'),
      ('إجمالي الالتزامات', '6.2M ر.س'),
      ('حقوق الملكية', '12.2M ر.س'),
      ('الإيرادات السنوية', '24.5M ر.س'),
      ('صافي الربح', '3.8M ر.س'),
    ]),
    _Extraction('قائمة الدخل Q4.pdf', 96, [
      ('الإيرادات الربع الرابع', '6.8M ر.س'),
      ('تكلفة المبيعات', '3.4M ر.س'),
      ('إجمالي الربح', '3.4M ر.س'),
      ('المصاريف التشغيلية', '1.2M ر.س'),
      ('صافي الربح الربع الرابع', '1.9M ر.س'),
    ]),
  ];

  static const List<(String, String, String, String)> _history = [
    ('ميزان مراجعة 2025.xlsx', 'تحليل NLP', 'مكتمل', '14:24'),
    ('ميزان مراجعة 2025.xlsx', 'استخراج بيانات', 'مكتمل', '14:22'),
    ('قائمة الدخل Q4.pdf', 'OCR + تحليل', 'مكتمل', '14:17'),
    ('القوائم المالية 2024.pdf', 'تصنيف تلقائي', 'مكتمل', '14:12'),
    ('قائمة الدخل 2023.xlsx', 'استخراج نسب', 'مكتمل', '10:32'),
  ];
}

class _FileRec { final String name, type, size, uploadDate, status; final int confidence;
  const _FileRec(this.name, this.type, this.size, this.uploadDate, this.status, this.confidence); }
class _Template { final String name, description, format;
  const _Template(this.name, this.description, this.format); }
class _Extraction { final String source; final int confidence; final List<(String, String)> fields;
  const _Extraction(this.source, this.confidence, this.fields); }
