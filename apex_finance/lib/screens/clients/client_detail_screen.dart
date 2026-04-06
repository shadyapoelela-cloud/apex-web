import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../copilot/copilot_screen.dart';
import '../financial/financial_ops_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  const ClientDetailScreen({super.key, required this.clientId, required this.clientName});
  @override State<ClientDetailScreen> createState() => _CDState();
}

class _CDState extends State<ClientDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _client;
  Map<String, dynamic>? _readiness;
  Map<String, dynamic>? _docsData;
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getClient(widget.clientId),
      ApiService.getClientReadiness(widget.clientId),
      ApiService.getClientDocuments(widget.clientId),
    ]);
    setState(() {
      _client = results[0].success ? (results[0].data is Map ? results[0].data : {}) : {};
      _readiness = results[1].success ? (results[1].data is Map ? results[1].data : {}) : {};
      _docsData = results[2].success ? (results[2].data is Map ? results[2].data : {}) : {};
      _loading = false;
    });
  }

  Color _readinessColor(String? s) {
    switch (s) {
      case 'ready_for_tb': return AC.ok;
      case 'coa_in_progress': return AC.gold;
      case 'ready_for_coa': return AC.cyan;
      case 'documents_pending': return Colors.orange;
      default: return AC.ts;
    }
  }

  String _readinessLabel(String? s) {
    switch (s) {
      case 'ready_for_tb': return '\u062c\u0627\u0647\u0632 \u0644\u0640 TB';
      case 'coa_in_progress': return 'COA \u0642\u064a\u062f \u0627\u0644\u062a\u0646\u0641\u064a\u0630';
      case 'ready_for_coa': return '\u062c\u0627\u0647\u0632 \u0644\u0640 COA';
      case 'documents_pending': return '\u0646\u0648\u0627\u0642\u0635 \u0645\u0633\u062a\u0646\u062f\u0627\u062a';
      default: return '\u063a\u064a\u0631 \u062c\u0627\u0647\u0632';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = _readiness?['readiness_status'] as String?;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2,
        title: Text(widget.clientName, style: const TextStyle(color: AC.tp, fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.smart_toy, color: AC.gold),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopilotScreen(clientId: widget.clientId))))],
        bottom: TabBar(controller: _tabCtrl, indicatorColor: AC.gold, labelColor: AC.gold, unselectedLabelColor: AC.ts, tabs: const [
          Tab(text: '\u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a', icon: Icon(Icons.info_outline, size: 18)),
          Tab(text: '\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a', icon: Icon(Icons.folder_outlined, size: 18)),
          Tab(text: '\u0627\u0644\u062e\u062f\u0645\u0627\u062a', icon: Icon(Icons.layers_outlined, size: 18)),
        ])),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
        Column(children: [
          _readinessBanner(rs),
          Expanded(child: TabBarView(controller: _tabCtrl, children: [
            _infoTab(),
            _documentsTab(),
            _servicesTab(),
          ])),
        ]),
    );
  }

  Widget _readinessBanner(String? rs) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: _readinessColor(rs).withAlpha(25),
    child: Row(children: [
      Icon(rs == 'ready_for_tb' ? Icons.check_circle : Icons.info_outline, color: _readinessColor(rs), size: 20),
      const SizedBox(width: 10),
      Text(_readinessLabel(rs), style: TextStyle(color: _readinessColor(rs), fontWeight: FontWeight.bold, fontSize: 13)),
      const Spacer(),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(
        color: _readinessColor(rs).withAlpha(30), borderRadius: BorderRadius.circular(20), border: Border.all(color: _readinessColor(rs).withAlpha(80))),
        child: Text(rs ?? 'not_ready', style: TextStyle(color: _readinessColor(rs), fontSize: 11, fontWeight: FontWeight.w600))),
    ]));

  Widget _infoTab() => RefreshIndicator(onRefresh: _loadAll, color: AC.gold, child: ListView(padding: const EdgeInsets.all(14), children: [
    _infoCard(),
    const SizedBox(height: 12),
    _actionsGrid(),
    if ((_readiness?['blockers'] as List?)?.isNotEmpty ?? false) ...[
      const SizedBox(height: 12),
      _blockersCard(),
    ],
  ]));

  Widget _infoCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.business, color: AC.gold, size: 28), const SizedBox(width: 12),
        Expanded(child: Text(widget.clientName, style: const TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)))]),
      const Divider(color: AC.bdr, height: 20),
      _kv('\u0627\u0644\u0646\u0648\u0639', _client?['client_type'] ?? '-'),
      _kv('\u0627\u0644\u0642\u0637\u0627\u0639', _client?['industry'] ?? _client?['sector'] ?? '-'),
      _kv('\u0627\u0644\u0645\u062f\u064a\u0646\u0629', _client?['city'] ?? '-'),
      _kv('\u0627\u0644\u062d\u0627\u0644\u0629', _client?['status'] ?? 'active'),
    ]));

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.ts, fontSize: 12)), Text(v, style: const TextStyle(color: AC.tp, fontSize: 12))]));

  Widget _blockersCard() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.orange.withAlpha(15), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.withAlpha(60))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.warning_amber, color: Colors.orange, size: 20), const SizedBox(width: 8),
        const Text('\u0645\u062a\u0637\u0644\u0628\u0627\u062a \u0646\u0627\u0642\u0635\u0629', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))]),
      const SizedBox(height: 8),
      ...(_readiness?['blockers'] as List? ?? []).map((b) => Padding(padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [const Icon(Icons.close, color: Colors.orange, size: 14), const SizedBox(width: 6),
          Expanded(child: Text(b.toString(), style: const TextStyle(color: AC.tp, fontSize: 12)))]))),
    ]));

  Widget _actionsGrid() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('\u0625\u062c\u0631\u0627\u0621\u0627\u062a', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
    const SizedBox(height: 8),
    Row(children: [
      _actionBtn('\u0627\u0644\u0639\u0645\u0644\u064a\u0627\u062a \u0627\u0644\u0645\u0627\u0644\u064a\u0629', Icons.account_balance_wallet, AC.cyan,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinancialOpsScreen(clientId: widget.clientId, clientName: widget.clientName)))),
      const SizedBox(width: 8),
      _actionBtn('Copilot', Icons.smart_toy, AC.gold,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopilotScreen(clientId: widget.clientId)))),
    ].map((w) => Expanded(child: w)).toList()),
  ]);

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
      child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 6), Text(label, style: const TextStyle(color: AC.tp, fontSize: 11), textAlign: TextAlign.center)])));

  // ??? Documents Tab ???
  Widget _documentsTab() {
    final docs = (_docsData?['documents'] as List?) ?? [];
    if (docs.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.folder_open, color: AC.ts, size: 48), const SizedBox(height: 12),
      const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0633\u062a\u0646\u062f\u0627\u062a', style: TextStyle(color: AC.ts, fontSize: 14))]));
    return RefreshIndicator(onRefresh: _loadAll, color: AC.gold, child: ListView.builder(
      padding: const EdgeInsets.all(14), itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final doc = docs[i] as Map<String, dynamic>;
        final status = doc['status'] as String? ?? 'missing';
        final required_ = doc['required'] == true;
        final color = status == 'accepted' ? AC.ok : status == 'missing' ? AC.ts : status == 'rejected' ? Colors.red : AC.gold;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Row(children: [
            Icon(status == 'accepted' ? Icons.check_circle : status == 'missing' ? Icons.cancel_outlined : Icons.hourglass_top, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(doc['name_ar'] ?? doc['type'] ?? '-', style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                if (required_) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 2),
              Text(status, style: TextStyle(color: color, fontSize: 11)),
            ])),
            if (status == 'missing')
              _docActionBtn('\u0631\u0641\u0639', Icons.upload, AC.cyan, () => _updateDocStatus(doc['type'], 'uploaded')),
            if (status == 'uploaded')
              _docActionBtn('\u0627\u0639\u062a\u0645\u0627\u062f', Icons.check, AC.ok, () => _updateDocStatus(doc['type'], 'accepted')),
          ]));
      }));
  }

  Widget _docActionBtn(String label, IconData icon, Color color, VoidCallback onTap) => TextButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 16, color: color),
    label: Text(label, style: TextStyle(color: color, fontSize: 11)),
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      side: BorderSide(color: color.withAlpha(60)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));

  Future<void> _updateDocStatus(String? docType, String newStatus) async {
    if (docType == null) return;
    final res = await ApiService.updateDocumentStatus(widget.clientId, docType, newStatus);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\u062a\u0645 \u0627\u0644\u062a\u062d\u062f\u064a\u062b'), backgroundColor: AC.ok));
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? '\u062e\u0637\u0623'), backgroundColor: Colors.red));
    }
  }

  // ??? Services Tab ???
  Widget _servicesTab() {
    final rs = _readiness?['readiness_status'] as String?;
    return ListView(padding: const EdgeInsets.all(14), children: [
      _serviceCard('\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', 'COA', Icons.account_tree, rs == 'coa_in_progress' || rs == 'ready_for_tb' ? 'active' : rs == 'ready_for_coa' ? 'ready' : 'pending'),
      _serviceCard('\u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', 'TB', Icons.table_chart, rs == 'ready_for_tb' ? 'ready' : 'pending'),
      _serviceCard('\u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a', 'Analysis', Icons.analytics, 'pending'),
      _serviceCard('\u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644', 'Compliance', Icons.shield, 'pending'),
    ]);
  }

  Widget _serviceCard(String name, String nameEn, IconData icon, String status) {
    final color = status == 'active' ? AC.gold : status == 'ready' ? AC.cyan : AC.ts;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
      child: Row(children: [
        Icon(icon, color: color, size: 24), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(nameEn, style: const TextStyle(color: AC.ts, fontSize: 11)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(
          color: color.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(60))),
          child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
      ]));
  }
}
