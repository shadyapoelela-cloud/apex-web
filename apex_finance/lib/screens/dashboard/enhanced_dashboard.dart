import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../copilot/copilot_screen.dart';
import '../financial/financial_ops_screen.dart';
import '../audit/audit_workflow_screen.dart';
import '../knowledge/knowledge_brain_screen.dart';

class EnhancedDashboard extends StatefulWidget {
  const EnhancedDashboard({super.key});
  @override State<EnhancedDashboard> createState() => _EDashState();
}

class _EDashState extends State<EnhancedDashboard> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _sub = {};
  List _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final subRes = await ApiService.getCurrentPlan();
      final clientsRes = await ApiService.listClients();
      final notifsRes = await ApiService.getNotifications();
      setState(() {
        _sub = subRes.success ? (subRes.data is Map ? subRes.data : {}) : {};
        final clients = clientsRes.success && clientsRes.data is List ? clientsRes.data : [];
        final notifs = notifsRes.success && notifsRes.data is List ? notifsRes.data : [];
        _stats = {
          'clients': (clients as List).length,
          'services': 56,
          'analyses': 1834,
          'revenue': 184500,
          'unread_notifs': (notifs as List).where((n) => n['is_read'] != true).length,
        };
        _recentActivity = (notifs as List).take(5).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Row(children: [
          const Text('APEX', style: TextStyle(color: AC.gold, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AC.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: const Text('v2.0', style: TextStyle(color: AC.gold, fontSize: 9)),
          ),
          const Spacer(),
          const Text('\u0644\u0648\u062d\u0629 \u0627\u0644\u0642\u064a\u0627\u062f\u0629', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.smart_toy, color: AC.gold, size: 22), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CopilotScreen()))),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : RefreshIndicator(
            onRefresh: _loadAll,
            color: AC.gold,
            child: ListView(padding: const EdgeInsets.all(14), children: [
              // KPI Cards Row
              _buildKpiRow(),
              const SizedBox(height: 16),
              // Copilot Card
              _buildCopilotCard(),
              const SizedBox(height: 16),
              // Quick Navigation Grid
              _buildQuickNav(),
              const SizedBox(height: 16),
              // Service Distribution + Revenue Chart placeholder
              _buildChartsRow(),
              const SizedBox(height: 16),
              // Recent Activity
              _buildRecentActivity(),
            ]),
          ),
    );
  }

  Widget _buildKpiRow() {
    return Row(children: [
      _kpiCard('\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0639\u0645\u0644\u0627\u0621', '', Icons.business, AC.cyan, '+12%'),
      const SizedBox(width: 10),
      _kpiCard('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a', '', Icons.analytics, AC.ok, '+8%'),
      const SizedBox(width: 10),
      _kpiCard('\u0627\u0644\u062e\u062f\u0645\u0627\u062a', '', Icons.work, AC.gold, '+23%'),
      const SizedBox(width: 10),
      _kpiCard('\u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a', 'K', Icons.payments, AC.warn, '+15%'),
    ].map((w) => Expanded(child: w)).toList());
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, String change) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: AC.ok.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(change, style: const TextStyle(color: AC.ok, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: AC.ts, fontSize: 10)),
      ]),
    );
  }

  Widget _buildCopilotCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CopilotScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AC.gold.withOpacity(0.12), AC.navy3], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AC.gold.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AC.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smart_toy, color: AC.gold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AC.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('AI', style: TextStyle(color: AC.gold, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 3),
            const Text('\u0627\u0633\u0623\u0644 \u0639\u0646 \u0627\u0644\u062a\u062d\u0644\u064a\u0644\u060c \u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644\u060c \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: AC.ts, fontSize: 11)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: AC.gold, size: 16),
        ]),
      ),
    );
  }

  Widget _buildQuickNav() {
    final items = [
      {'\u0646': '\u0627\u0644\u0639\u0645\u0644\u064a\u0627\u062a \u0627\u0644\u0645\u0627\u0644\u064a\u0629', 'i': Icons.account_balance_wallet, 'c': AC.cyan, 's': const FinancialOpsScreen()},
      {'\u0646': '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', 'i': Icons.checklist, 'c': AC.gold, 's': const AuditWorkflowScreen()},
      {'\u0646': '\u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', 'i': Icons.psychology, 'c': const Color(0xFFE91E63), 's': const KnowledgeBrainScreen()},
      {'\u0646': 'Copilot', 'i': Icons.smart_toy, 'c': AC.gold, 's': const CopilotScreen()},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('\u0648\u0635\u0648\u0644 \u0633\u0631\u064a\u0639', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 10),
      Row(children: items.map((item) => Expanded(child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['s'] as Widget)),
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(children: [
            Icon(item['i'] as IconData, color: item['c'] as Color, size: 24),
            const SizedBox(height: 6),
            Text(item['\u0646'] as String, style: const TextStyle(color: AC.tp, fontSize: 10), textAlign: TextAlign.center),
          ]),
        ),
      ))).toList()),
    ]);
  }

  Widget _buildChartsRow() {
    final services = [
      {'\u0646': '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', 'v': 32, 'c': AC.cyan},
      {'\u0646': '\u062c\u0627\u0647\u0632\u064a\u0629 \u062a\u0645\u0648\u064a\u0644\u064a\u0629', 'v': 22, 'c': AC.gold},
      {'\u0646': '\u0645\u0631\u0627\u062c\u0639\u0629', 'v': 16, 'c': AC.ok},
      {'\u0646': '\u0636\u0631\u0627\u0626\u0628 \u0648\u0632\u0643\u0627\u0629', 'v': 12, 'c': AC.warn},
      {'\u0646': '\u062f\u0639\u0645 \u0648\u062a\u0631\u0627\u062e\u064a\u0635', 'v': 18, 'c': const Color(0xFFE91E63)},
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('\u062a\u0648\u0632\u064a\u0639 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        ...services.map((s) {
          final pct = (s['v'] as int) / 100;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            SizedBox(width: 90, child: Text(s['\u0646'] as String, style: const TextStyle(color: AC.ts, fontSize: 11))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: AC.navy4, color: s['c'] as Color, minHeight: 8))),
            const SizedBox(width: 8),
            Text('%', style: TextStyle(color: s['c'] as Color, fontSize: 11, fontWeight: FontWeight.bold)),
          ]));
        }),
      ]),
    );
  }

  Widget _buildRecentActivity() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('\u0622\u062e\u0631 \u0627\u0644\u0623\u0646\u0634\u0637\u0629', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 10),
      if (_recentActivity.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u0646\u0634\u0637\u0629 \u062d\u062f\u064a\u062b\u0629', style: TextStyle(color: AC.ts))),
        )
      else
        ..._recentActivity.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AC.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.notifications_outlined, color: AC.cyan, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(a['message'] ?? a['title'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        )),
    ]);
  }
}
