import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _api = 'https://apex-api-ootk.onrender.com';

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy3 = Color(0xFF0D1829);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const bdr = Color(0x26C9A84C);
}

class ServiceCatalogScreen extends StatefulWidget {
  final String clientId;
  final String? token;
  const ServiceCatalogScreen({super.key, required this.clientId, this.token});
  @override State<ServiceCatalogScreen> createState() => _ServiceCatalogS();
}

class _ServiceCatalogS extends State<ServiceCatalogScreen> {
  List<dynamic> _services = [];
  bool _loading = true;
  String? _selectedCategory;

  static const _categories = <String?, String>{
    null: 'الكل', 'financial': 'مالية', 'audit': 'رقابية',
    'compliance': 'امتثال', 'readiness': 'جاهزية', 'advisory': 'استشارية',
  };

  Map<String, String> get _h => {'Authorization': 'Bearer ${widget.token ?? ""}', 'Content-Type': 'application/json'};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String url = '$_api/api/v1/services/catalog';
      if (_selectedCategory != null) url += '?category=$_selectedCategory';
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        setState(() { _services = d['data'] ?? []; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('كتالوج الخدمات', style: TextStyle(color: AC.gold)), backgroundColor: const Color(0xFF080F1F)),
    body: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(children: _categories.entries.map((e) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ChoiceChip(
            label: Text(e.value),
            selected: _selectedCategory == e.key,
            selectedColor: AC.gold.withOpacity(0.2),
            labelStyle: TextStyle(color: _selectedCategory == e.key ? AC.gold : AC.ts),
            backgroundColor: AC.navy3,
            side: BorderSide(color: _selectedCategory == e.key ? AC.gold : Colors.white12),
            onSelected: (_) { setState(() => _selectedCategory = e.key); _load(); },
          ))).toList())),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _services.isEmpty
          ? const Center(child: Text('لا توجد خدمات', style: TextStyle(color: AC.ts)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _services.length,
              itemBuilder: (_, i) {
                final s = _services[i];
                final stagesCount = (s['stages_count'] ?? 0).toString();
                final minPlan = (s['min_plan'] ?? 'pro').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s['title_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.bold))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(stagesCount + ' مراحل', style: const TextStyle(color: AC.cyan, fontSize: 11))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (s['requires_coa'] == true) _tag('يتطلب COA', AC.warn),
                      if (s['requires_tb'] == true) _tag('يتطلب TB', AC.warn),
                      _tag(s['category'] ?? '', AC.gold),
                      const Spacer(),
                      _tag('الحد الأدنى: ' + minPlan, AC.ts),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => _startService(s['service_code']),
                      style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
                      child: const Text('بدء الخدمة'))),
                  ]),
                );
              })),
    ]),
  );

  Widget _tag(String text, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10)));

  Future<void> _startService(String code) async {
    try {
      final r = await http.post(Uri.parse('$_api/api/v1/services/cases'), headers: _h,
        body: jsonEncode({'client_id': widget.clientId, 'service_code': code}));
      if (r.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم بدء الخدمة بنجاح'), backgroundColor: Colors.green));
      } else {
        final d = jsonDecode(r.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['detail'] ?? 'فشل'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }
}
