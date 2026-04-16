import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../../api_service.dart';

class ServiceCatalogScreen extends StatefulWidget {
  final String? clientId;
  final String? token;
  const ServiceCatalogScreen({super.key, this.clientId, this.token});
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

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getServiceCatalog(category: _selectedCategory);
    if (res.success) {
      setState(() { _services = res.data['data'] ?? []; _loading = false; });
    } else { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('كتالوج الخدمات', style: TextStyle(color: AC.gold)), backgroundColor: AC.navy2),
    body: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(children: _categories.entries.map((e) => Padding(
          padding: EdgeInsets.only(left: 8),
          child: ChoiceChip(
            label: Text(e.value),
            selected: _selectedCategory == e.key,
            selectedColor: AC.gold.withValues(alpha: 0.2),
            labelStyle: TextStyle(color: _selectedCategory == e.key ? AC.gold : AC.ts),
            backgroundColor: AC.navy2,
            side: BorderSide(color: _selectedCategory == e.key ? AC.gold : AC.bdr.withValues(alpha: 0.5)),
            onSelected: (_) { setState(() => _selectedCategory = e.key); _load(); },
          ))).toList())),
      Expanded(child: _loading
        ? Center(child: CircularProgressIndicator(color: AC.gold))
        : _services.isEmpty
          ? Center(child: Text('لا توجد خدمات', style: TextStyle(color: AC.ts)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _services.length,
              itemBuilder: (_, i) {
                final s = _services[i];
                final stagesCount = (s['stages_count'] ?? 0).toString();
                final minPlan = (s['min_plan'] ?? 'pro').toString();
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s['title_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.bold))),
                      Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AC.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(stagesCount + ' مراحل', style: TextStyle(color: AC.cyan, fontSize: 11))),
                    ]),
                    SizedBox(height: 6),
                    Row(children: [
                      if (s['requires_coa'] == true) _tag('يتطلب COA', AC.warn),
                      if (s['requires_tb'] == true) _tag('يتطلب TB', AC.warn),
                      _tag(s['category'] ?? '', AC.gold),
                      Spacer(),
                      _tag('الحد الأدنى: ' + minPlan, AC.ts),
                    ]),
                    SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: apexPrimaryButton('بدء الخدمة', () => _startService(s['service_code']))),
                  ]),
                );
              })),
    ]),
  );

  Widget _tag(String text, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10)));

  Future<void> _startService(String code) async {
    if (widget.clientId == null || widget.clientId!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('يرجى اختيار عميل أولاً من تبويب العملاء'),
        backgroundColor: AC.warn));
      return;
    }
    final res = await ApiService.createServiceCase(clientId: widget.clientId!, serviceCode: code);
    if (res.success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم بدء الخدمة بنجاح'), backgroundColor: AC.ok));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? 'فشل'), backgroundColor: AC.err));
    }
  }
}
