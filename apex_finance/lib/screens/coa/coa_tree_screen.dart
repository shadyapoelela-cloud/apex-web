import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class CoaTreeScreen extends StatefulWidget {
  final String? uploadId;
  final String? clientName;
  const CoaTreeScreen({super.key, this.uploadId, this.clientName});
  @override State<CoaTreeScreen> createState() => _CoaTreeState();
}

class _CoaTreeState extends State<CoaTreeScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String _filter = '';
  final _searchCtrl = TextEditingController();
  Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (widget.uploadId == null) { setState(() => _loading = false); return; }
    final res = await ApiService.getCoaAccounts(uploadId: widget.uploadId!, pageSize: 500);
    if (res.success) {
      final data = res.data is Map ? (res.data['data'] ?? res.data['accounts'] ?? []) : (res.data ?? []);
      setState(() {
        _accounts = List<Map<String, dynamic>>.from(data is List ? data : []);
        _loading = false;
      });
    } else { setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _roots => _accounts.where((a) {
    final parent = a['parent_code'] ?? a['parent_name'];
    final matchFilter = _filter.isEmpty || (a['account_name'] ?? '').toString().contains(_filter) || (a['account_code'] ?? '').toString().contains(_filter);
    return (parent == null || parent == '') && matchFilter;
  }).toList();

  List<Map<String, dynamic>> _children(String code) => _accounts.where((a) => a['parent_code'] == code).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
          if (widget.clientName != null) Text(widget.clientName!, style: TextStyle(color: AC.ts, fontSize: 11)),
        ]),
        actions: [
          ApexIconButton(icon: _expanded.isEmpty ? Icons.unfold_more : Icons.unfold_less, color: AC.ts, tooltip: 'توسيع/طي الشجرة', onPressed: () {
            setState(() { if (_expanded.isEmpty) { _expanded = _accounts.map((a) => a['account_code']?.toString() ?? '').toSet(); } else { _expanded.clear(); } });
          }),
        ],
      ),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(12), child: TextField(
          controller: _searchCtrl, style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            hintText: '\u0628\u062d\u062b \u0641\u064a \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a...', hintStyle: TextStyle(color: AC.ts),
            prefixIcon: Icon(Icons.search, color: AC.gold), filled: true, fillColor: AC.navy3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _filter = v),
        )),
        Expanded(child: _loading
          ? Center(child: CircularProgressIndicator(color: AC.gold))
          : _accounts.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_tree, color: AC.ts, size: 48),
                SizedBox(height: 12),
                Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u062d\u0633\u0627\u0628\u0627\u062a', style: TextStyle(color: AC.ts)),
              ]))
            : ListView(padding: EdgeInsets.symmetric(horizontal: 12), children: _roots.map((a) => _buildNode(a, 0)).toList()),
        ),
        Container(padding: EdgeInsets.all(10), color: AC.navy2, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('\u0625\u062c\u0645\u0627\u0644\u064a:  \u062d\u0633\u0627\u0628', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('\u062c\u0630\u0631\u064a: ', style: TextStyle(color: AC.gold, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildNode(Map<String, dynamic> account, int depth) {
    final code = account['account_code']?.toString() ?? '';
    final name = account['account_name'] ?? '';
    final type = account['account_type'] ?? '';
    final children = _children(code);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expanded.contains(code);
    final typeColor = type == 'asset' ? AC.cyan : type == 'liability' ? AC.err : type == 'equity' ? AC.gold : type == 'revenue' ? AC.ok : type == 'expense' ? AC.warn : AC.ts;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: hasChildren ? () => setState(() { if (isExpanded) _expanded.remove(code); else _expanded.add(code); }) : null,
        child: Container(
          margin: EdgeInsets.only(right: depth * 16.0, bottom: 4),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
          child: Row(children: [
            if (hasChildren) Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, color: AC.ts, size: 18) else SizedBox(width: 18),
            const SizedBox(width: 4),
            Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(code, style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold))),
            SizedBox(width: 8),
            Expanded(child: Text(name, style: TextStyle(color: AC.tp, fontSize: 12), textDirection: TextDirection.rtl)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(type, style: TextStyle(color: typeColor, fontSize: 9))),
          ]),
        ),
      ),
      if (isExpanded) ...children.map((c) => _buildNode(c, depth + 1)),
    ]);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }
}
