import 'package:flutter/material.dart';
void main() => runApp(const MyApp());
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0D1230)),
    home: const TestCreate(),
  );
}
class TestCreate extends StatefulWidget {
  const TestCreate({super.key});
  @override
  State<TestCreate> createState() => _TestCreateState();
}
class _TestCreateState extends State<TestCreate> {
  String? _sel;
  final _nameC = TextEditingController();
  static const Color gold = Color(0xFFC8A951);
  static const Color navy3 = Color(0xFF1A1F3D);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1230),
      appBar: AppBar(title: const Text('عميل جديد - TEST', style: TextStyle(color: gold)), backgroundColor: const Color(0xFF0D1230)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: SizedBox(height: 56, child: TextField(
          controller: _nameC, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: 'اسم الشركة *', labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.business, color: gold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: gold), borderRadius: BorderRadius.circular(8)))))),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('* نوع العميل', style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _tc('standard_business', 'شركة تجارية عادية', false),
          _tc('financial_entity', 'جهة مالية', true),
          _tc('financing_entity', 'جهة تمويلية', true),
          _tc('accounting_firm', 'مكتب محاسبة', true),
          _tc('audit_firm', 'مكتب مراجعة', true),
          _tc('investment_entity', 'جهة استثمارية', true),
          _tc('sector_consulting_entity', 'جهة استشارية', true),
          _tc('government_entity', 'جهة حكومية', true),
          _tc('legal_regulatory_entity', 'جهة قانونية أو تنظيمية', true)])),
        Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 52, width: double.infinity, child: ElevatedButton(
          onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_nameC.text} - $_sel'))); },
          style: ElevatedButton.styleFrom(backgroundColor: gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('انشاء العميل', style: TextStyle(color: Color(0xFF0D1230), fontWeight: FontWeight.bold, fontSize: 16))))),
      ]),
    );
  }
  Widget _tc(String code, String label, bool isKm) {
    final sel = _sel == code;
    return GestureDetector(onTap: () => setState(() => _sel = code),
      child: Container(height: 52, margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: sel ? gold.withOpacity(0.15) : navy3,
          border: Border.all(color: sel ? gold : Colors.white12, width: sel ? 1.5 : 1), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? gold : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: sel ? gold : Colors.white70, fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
          if (isKm) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: gold.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: const Text('معرفي', style: TextStyle(color: gold, fontSize: 10)))])));
  }
}
