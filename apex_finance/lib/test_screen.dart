import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const TestScreen(),
  );
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String? _selected;
  final _nameC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1230),
      appBar: AppBar(
        title: const Text('عميل جديد', style: TextStyle(color: Color(0xFFC8A951))),
        backgroundColor: const Color(0xFF0D1230),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _nameC,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الشركة *',
                  labelStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFC8A951)), borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('نوع العميل *', style: TextStyle(color: Color(0xFFC8A951), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _tc('standard_business', 'شركة تجارية عادية', false),
                _tc('financial_entity', 'جهة مالية', true),
                _tc('financing_entity', 'جهة تمويلية', true),
                _tc('accounting_firm', 'مكتب محاسبة', true),
                _tc('audit_firm', 'مكتب مراجعة', true),
                _tc('investment_entity', 'جهة استثمارية', true),
                _tc('sector_consulting_entity', 'جهة استشارية', true),
                _tc('government_entity', 'جهة حكومية', true),
                _tc('legal_regulatory_entity', 'جهة قانونية أو تنظيمية', true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameC.text.isEmpty || _selected == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('أدخل الاسم واختر النوع')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم: ${_nameC.text} - $_selected')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8A951),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إنشاء العميل', style: TextStyle(color: Color(0xFF0D1230), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tc(String code, String label, bool isKm) {
    final sel = _selected == code;
    return GestureDetector(
      onTap: () => setState(() => _selected = code),
      child: Container(
        height: 48,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: sel ? const Color(0x33C8A951) : const Color(0xFF1A1F3D),
          border: Border.all(color: sel ? const Color(0xFFC8A951) : Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? const Color(0xFFC8A951) : Colors.white38, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: sel ? const Color(0xFFC8A951) : Colors.white70, fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
            if (isKm) const Text('معرفي', style: TextStyle(color: Color(0xFFC8A951), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
