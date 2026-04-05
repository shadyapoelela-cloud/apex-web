import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  List _recentActivity = [];

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    try {
      final clientsRes = await ApiService.listClients();
      final notifsRes = await ApiService.getNotifications();
      final st = <String,dynamic>{}; try { final sr = await ApiService.adminStats(); if (sr.success && sr.data is Map) { st.addAll(sr.data as Map<String,dynamic>); } } catch(_) {}
      setState(() {
        final clients = clientsRes.success && clientsRes.data is List ? clientsRes.data : [];
        final notifs = notifsRes.success && notifsRes.data is List ? notifsRes.data : [];
        _stats = {
          'clients': (clients as List).length,
          'services': (st['total_services'] ?? st['services'] ?? 56) as num, 'analyses': (st['total_analyses'] ?? st['analyses'] ?? 1834) as num, 'revenue': (st['total_revenue'] ?? st['revenue'] ?? 184500) as num,
          'unread': (notifs as List).where((n) => n['is_read'] != true).length,
        };
        _recentActivity = (notifs as List).take(5).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : RefreshIndicator(onRefresh: _loadAll, color: AC.gold,
          child: ListView(padding: const EdgeInsets.all(14), children: [
            _buildKpiRow(),
            const SizedBox(height: 16),
            _buildCopilotCard(),
            const SizedBox(height: 16),
            _buildQuickNav(),
            const SizedBox(height: 16),
            _buildRevenueChart(),
            const SizedBox(height: 16),
            _buildServiceDonut(),
            const SizedBox(height: 16),
            _buildRecentActivity(),
          ]));
  }

  Widget _buildKpiRow() => Column(children: [
    Row(children: [
      Expanded(child: _kpi('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', '${_stats["clients"] ?? 0}', Icons.business, AC.cyan, '+12%')),
      const SizedBox(width: 8),
      Expanded(child: _kpi('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a', '${_stats["analyses"] ?? 0}', Icons.analytics, AC.ok, '+8%')),
      const SizedBox(width: 8),
      Expanded(child: _kpi('\u0627\u0644\u062e\u062f\u0645\u0627\u062a', '${_stats["services"] ?? 0}', Icons.work, AC.gold, '+23%')),
    ]),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _kpi('\u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a', '${_stats["revenue"] ?? 0}K', Icons.payments, AC.warn, '+15%')),
      const SizedBox(width: 8),
      Expanded(child: _kpi('\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0627\u062a', '${_stats["audits"] ?? 0}', Icons.checklist, const Color(0xFF9C27B0), '+5%')),
      const SizedBox(width: 8),
      Expanded(child: _kpi('\u0627\u0644\u0645\u0632\u0648\u062f\u064a\u0646', '${_stats["providers"] ?? 0}', Icons.people, const Color(0xFF00BCD4), '+10%')),
    ]),
  ]);

  Widget _kpi(String t, String v, IconData i, Color c, String ch) => Container(
    padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(i, color: c, size: 16), const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AC.ok.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
          child: Text(ch, style: const TextStyle(color: AC.ok, fontSize: 8, fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 6),
      Text(v, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
      Text(t, style: const TextStyle(color: AC.ts, fontSize: 9)),
    ]));

  Widget _buildCopilotCard() => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CopilotScreen())),
    child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.gold.withOpacity(0.12), AC.navy3], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AC.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.smart_toy, color: AC.gold, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: AC.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text('AI', style: TextStyle(color: AC.gold, fontSize: 9, fontWeight: FontWeight.w700)))]),
          const Text('\u0627\u0633\u0623\u0644 \u0639\u0646 \u0627\u0644\u062a\u062d\u0644\u064a\u0644\u060c \u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644\u060c \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: AC.ts, fontSize: 11))])),
        const Icon(Icons.arrow_forward_ios, color: AC.gold, size: 14)])));

  Widget _buildQuickNav() {
    final items = [
      {'\u0646': '\u0627\u0644\u0639\u0645\u0644\u064a\u0627\u062a', 'i': Icons.account_balance_wallet, 'c': AC.cyan, 's': const FinancialOpsScreen()},
      {'\u0646': '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', 'i': Icons.checklist, 'c': AC.gold, 's': const AuditWorkflowScreen()},
      {'\u0646': '\u0627\u0644\u0645\u0639\u0631\u0641\u064a', 'i': Icons.psychology, 'c': const Color(0xFFE91E63), 's': const KnowledgeBrainScreen()},
      {'\u0646': 'Copilot', 'i': Icons.smart_toy, 'c': AC.gold, 's': const CopilotScreen()},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('\u0648\u0635\u0648\u0644 \u0633\u0631\u064a\u0639', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      Row(children: items.map((m) => Expanded(child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m['s'] as Widget)),
        child: Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(children: [Icon(m['i'] as IconData, color: m['c'] as Color, size: 22), const SizedBox(height: 4),
            Text(m['\u0646'] as String, style: const TextStyle(color: AC.tp, fontSize: 10), textAlign: TextAlign.center)]))))).toList())]);
  }

  // ===== MONTHLY REVENUE BAR CHART =====
  Widget _buildRevenueChart() {
    final months = ['\u064a\u0646\u0627', '\u0641\u0628\u0631', '\u0645\u0627\u0631', '\u0623\u0628\u0631', '\u0645\u0627\u064a', '\u064a\u0648\u0646'];
    final values = [45.0, 62.0, 78.0, 55.0, 90.0, 72.0];
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a \u0627\u0644\u0634\u0647\u0631\u064a\u0629', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          const Text('\u0623\u0644\u0641 \u0631.\u0633', style: TextStyle(color: AC.ts, fontSize: 10)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 180, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, r, ri) => BarTooltipItem('K', const TextStyle(color: AC.gold, fontSize: 12)),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) =>
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(months[v.toInt()], style: const TextStyle(color: AC.ts, fontSize: 10))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
              getTitlesWidget: (v, m) => Text('', style: const TextStyle(color: AC.ts, fontSize: 9)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: AC.bdr, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: values[i], color: i == 4 ? AC.gold : AC.gold.withOpacity(0.5),
              width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: AC.navy4)),
          ])),
        ))),
      ]));
  }

  // ===== SERVICE DISTRIBUTION DONUT CHART =====
  Widget _buildServiceDonut() {
    final data = [
      {'\u0646': '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', 'v': 32.0, 'c': AC.cyan},
      {'\u0646': '\u062c\u0627\u0647\u0632\u064a\u0629 \u062a\u0645\u0648\u064a\u0644', 'v': 22.0, 'c': AC.gold},
      {'\u0646': '\u0645\u0631\u0627\u062c\u0639\u0629', 'v': 16.0, 'c': AC.ok},
      {'\u0646': '\u0636\u0631\u0627\u0626\u0628', 'v': 12.0, 'c': AC.warn},
      {'\u0646': '\u062f\u0639\u0645 \u0648\u062a\u0631\u0627\u062e\u064a\u0635', 'v': 18.0, 'c': const Color(0xFFE91E63)},
    ];
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('\u062a\u0648\u0632\u064a\u0639 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(width: 140, height: 140, child: PieChart(PieChartData(
            sectionsSpace: 2, centerSpaceRadius: 35,
            sections: data.map((d) => PieChartSectionData(
              value: d['v'] as double, color: d['c'] as Color,
              radius: 30, title: '%',
              titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            )).toList(),
          ))),
          const SizedBox(width: 16),
          Expanded(child: Column(children: data.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: d['c'] as Color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Expanded(child: Text(d['\u0646'] as String, style: const TextStyle(color: AC.ts, fontSize: 11))),
              Text('%', style: TextStyle(color: d['c'] as Color, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          )).toList())),
        ]),
      ]));
  }

  Widget _buildRecentActivity() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('\u0622\u062e\u0631 \u0627\u0644\u0623\u0646\u0634\u0637\u0629', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
    const SizedBox(height: 8),
    if (_recentActivity.isEmpty) Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
      child: const Center(child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u0646\u0634\u0637\u0629', style: TextStyle(color: AC.ts))))
    else ..._recentActivity.map((a) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AC.cyan.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.notifications_outlined, color: AC.cyan, size: 14)),
        const SizedBox(width: 8),
        Expanded(child: Text(a['message'] ?? a['title'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis))])))]);
}
