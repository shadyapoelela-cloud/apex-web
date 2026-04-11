import 'package:flutter/material.dart';
import 'api_service.dart';
import 'core/theme.dart';

class ClientCreateScreen2 extends StatefulWidget {
  const ClientCreateScreen2({super.key});
  @override
  State<ClientCreateScreen2> createState() => _CCS2();
}

class _CCS2 extends State<ClientCreateScreen2> {
  String? _sel;
  final _nameC = TextEditingController();
  bool _ld = false;
  String? _err;

  Future<void> _create() async {
    if (_nameC.text.trim().isEmpty || _sel == null) {
      setState(() => _err = 'ادخل اسم العميل واختر النوع');
      return;
    }
    setState(() { _ld = true; _err = null; });
    try {
      final r = await ApiService.createClient(clientCode: '', name: _nameC.text.trim(), clientType: _sel!, nameAr: _nameC.text.trim());
      if (r.success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() { _err = r.error ?? 'فشل'; _ld = false; });
      }
    } catch (e) { setState(() { _err = e.toString(); _ld = false; }); }
  }

  @override
  void dispose() { _nameC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: Text('عميل جديد', style: TextStyle(color: AC.gold)), backgroundColor: AC.navy),
      body: Column(children: [
        Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: SizedBox(height: 56, child: TextField(
          controller: _nameC, style: TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: 'اسم الشركة *', labelStyle: TextStyle(color: Colors.white54),
            prefixIcon: Icon(Icons.business, color: AC.gold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.gold), borderRadius: BorderRadius.circular(8)))))),
        if (_err != null) Padding(padding: EdgeInsets.all(12), child: Text(_err!, style: const TextStyle(color: Colors.redAccent))),
        Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('* نوع العميل', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold))),
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
        Padding(padding: EdgeInsets.all(16), child: SizedBox(height: 52, width: double.infinity, child: ElevatedButton(
          onPressed: _ld ? null : _create,
          style: ElevatedButton.styleFrom(backgroundColor: AC.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _ld ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('انشاء العميل', style: TextStyle(color: AC.navy, fontWeight: FontWeight.bold, fontSize: 16))))),
      ]),
    );
  }

  Widget _tc(String code, String label, bool isKm) {
    final sel = _sel == code;
    return GestureDetector(onTap: () => setState(() => _sel = code),
      child: Container(height: 52, margin: EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: sel ? AC.gold.withValues(alpha: 0.15) : AC.navy3,
          border: Border.all(color: sel ? AC.gold : Colors.white12, width: sel ? 1.5 : 1), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AC.gold : AC.ts, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: sel ? AC.gold : AC.tp, fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
          if (isKm) Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text('معرفي', style: TextStyle(color: AC.gold, fontSize: 10)))])));
  }
}
