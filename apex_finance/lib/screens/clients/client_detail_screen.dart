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

class _CDState extends State<ClientDetailScreen> {
  Map<String, dynamic>? _client;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final res = await ApiService.getClient(widget.clientId);
    if (res.success) {
      final d = res.data is Map ? res.data : (res.data?['data']);
      setState(() { _client = d is Map<String,dynamic> ? d : {}; _loading = false; });
    } else { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, title: Text(widget.clientName, style: const TextStyle(color: AC.tp, fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.smart_toy, color: AC.gold), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopilotScreen(clientId: widget.clientId))))]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
        RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: const EdgeInsets.all(14), children: [
          _infoCard(),
          const SizedBox(height: 12),
          _actionsGrid(),
          const SizedBox(height: 12),
          _statusCard(),
        ])),
    );
  }

  Widget _infoCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.business, color: AC.gold, size: 28), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.clientName, style: const TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('ID: ', style: const TextStyle(color: AC.ts, fontSize: 11)),
        ]))]),
      const Divider(color: AC.bdr, height: 20),
      _kv('\u0627\u0644\u0646\u0648\u0639', _client?['client_type'] ?? '-'),
      _kv('\u0627\u0644\u0642\u0637\u0627\u0639', _client?['industry'] ?? '-'),
      _kv('\u0627\u0644\u062f\u0648\u0644\u0629', _client?['country'] ?? 'SA'),
      _kv('\u0627\u0644\u0639\u0645\u0644\u0629', _client?['currency'] ?? 'SAR'),
      _kv('\u0627\u0644\u062d\u0627\u0644\u0629', _client?['status'] ?? 'active'),
    ]));

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.ts, fontSize: 12)), Text(v, style: const TextStyle(color: AC.tp, fontSize: 12))]));

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

  Widget _statusCard() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('\u0627\u0644\u062d\u0627\u0644\u0629', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      _statusRow('\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', 'pending'),
      _statusRow('\u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', 'pending'),
      _statusRow('\u0627\u0644\u062a\u062d\u0644\u064a\u0644', 'pending'),
    ]));

  Widget _statusRow(String label, String status) {
    final color = status == 'done' ? AC.ok : status == 'in_progress' ? AC.gold : AC.ts;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
      Icon(status == 'done' ? Icons.check_circle : Icons.radio_button_unchecked, color: color, size: 16),
      const SizedBox(width: 8), Text(label, style: const TextStyle(color: AC.tp, fontSize: 12)),
    ]));
  }
}
