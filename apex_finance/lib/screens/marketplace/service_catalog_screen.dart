import 'package:flutter/material.dart';
import '../../core/theme.dart';
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
    null: 'ط§ظ„ظƒظ„', 'financial': 'ظ…ط§ظ„ظٹط©', 'audit': 'ط±ظ‚ط§ط¨ظٹط©',
    'compliance': 'ط§ظ…طھط«ط§ظ„', 'readiness': 'ط¬ط§ظ‡ط²ظٹط©', 'advisory': 'ط§ط³طھط´ط§ط±ظٹط©',
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
    appBar: AppBar(title: const Text('ظƒطھط§ظ„ظˆط¬ ط§ظ„ط®ط¯ظ…ط§طھ', style: TextStyle(color: AC.gold)), backgroundColor: const Color(0xFF080F1F)),
    body: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(children: _categories.entries.map((e) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ChoiceChip(
            label: Text(e.value),
            selected: _selectedCategory == e.key,
            selectedColor: AC.gold.withValues(alpha: 0.2),
            labelStyle: TextStyle(color: _selectedCategory == e.key ? AC.gold : AC.ts),
            backgroundColor: AC.navy3,
            side: BorderSide(color: _selectedCategory == e.key ? AC.gold : Colors.white12),
            onSelected: (_) { setState(() => _selectedCategory = e.key); _load(); },
          ))).toList())),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _services.isEmpty
          ? const Center(child: Text('ظ„ط§ طھظˆط¬ط¯ ط®ط¯ظ…ط§طھ', style: TextStyle(color: AC.ts)))
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
                        decoration: BoxDecoration(color: AC.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(stagesCount + ' ظ…ط±ط§ط­ظ„', style: const TextStyle(color: AC.cyan, fontSize: 11))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (s['requires_coa'] == true) _tag('ظٹطھط·ظ„ط¨ COA', AC.warn),
                      if (s['requires_tb'] == true) _tag('ظٹطھط·ظ„ط¨ TB', AC.warn),
                      _tag(s['category'] ?? '', AC.gold),
                      const Spacer(),
                      _tag('ط§ظ„ط­ط¯ ط§ظ„ط£ط¯ظ†ظ‰: ' + minPlan, AC.ts),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => _startService(s['service_code']),
                      style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
                      child: const Text('ط¨ط¯ط، ط§ظ„ط®ط¯ظ…ط©'))),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ظٹط±ط¬ظ‰ ط§ط®طھظٹط§ط± ط¹ظ…ظٹظ„ ط£ظˆظ„ط§ظ‹ ظ…ظ† طھط¨ظˆظٹط¨ ط§ظ„ط¹ظ…ظ„ط§ط،'),
        backgroundColor: Colors.orange));
      return;
    }
    final res = await ApiService.createServiceCase(clientId: widget.clientId!, serviceCode: code);
    if (res.success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('طھظ… ط¨ط¯ط، ط§ظ„ط®ط¯ظ…ط© ط¨ظ†ط¬ط§ط­'), backgroundColor: Colors.green));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? 'ظپط´ظ„'), backgroundColor: Colors.red));
    }
  }
}
