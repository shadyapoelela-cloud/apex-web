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
            // quick nav removed
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _buildRevenueChart()), const SizedBox(width: 8), Expanded(child: _buildServiceDonut()), const SizedBox(width: 8), Expanded(child: _buildSectorChart())]),
            const SizedBox(height: 12),
            _buildPerformanceCard(),
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
    final months = ['\u064a\u0646\u0627', '\u0641\u0628\u0631', '\u0645\u0627\u0631', '\u0623\u0628\u0631', '\u0645\u0627\u064a', '\u064a\u0648\u0646', '\u064a\u0648\u0644', '\u0623\u063a\u0633', '\u0633\u0628\u062a', '\u0623\u0643\u062a', '\u0646\u0648\u0641', '\u062f\u064a\u0633'];
    final thisYear = [45.0, 62.0, 78.0, 55.0, 90.0, 72.0, 85.0, 68.0, 95.0, 80.0, 88.0, 92.0];
    final lastYear = [38.0, 50.0, 65.0, 48.0, 75.0, 60.0, 70.0, 55.0, 78.0, 66.0, 72.0, 80.0];
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a \u0627\u0644\u0633\u0646\u0648\u064a\u0629', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AC.gold, shape: BoxShape.circle)),
          const Text(' 2026 ', style: TextStyle(color: AC.ts, fontSize: 8)),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AC.cyan, shape: BoxShape.circle)),
          const Text(' 2025', style: TextStyle(color: AC.ts, fontSize: 8)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 180, child: LineChart(LineChartData(
          minY: 0, maxY: 100,
          lineTouchData: const LineTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
              final idx = v.toInt(); if (idx < 0 || idx >= months.length) return const SizedBox(); return Padding(padding: const EdgeInsets.only(top: 6), child: Text(months[idx], style: const TextStyle(color: AC.ts, fontSize: 10)));
            })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(color: AC.ts, fontSize: 8)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (v) => FlLine(color: AC.bdr, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(spots: thisYear.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(), isCurved: true, color: AC.gold, barWidth: 2.5, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: AC.gold.withOpacity(0.1))),
            LineChartBarData(spots: lastYear.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(), isCurved: true, color: AC.cyan, barWidth: 2, dashArray: [5, 3], dotData: const FlDotData(show: false)),
          ],
        ))),
      ]));
  }

  // ===== SERVICE DISTRIBUTION DONUT CHART =====
  Widget _buildServiceDonut() {
    final data = [
      {'\u0646': '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', 'v': 32.0, 'c': AC.cyan},
      {'\u0646': '\u062c\u0627\u0647\u0632\u064a\u0629 \u062a\u0645\u0648\u064a\u0644', 'v': 24.0, 'c': AC.gold},
      {'\u0646': '\u0645\u0631\u0627\u062c\u0639\u0629', 'v': 16.0, 'c': AC.ok},
      {'\u0646': '\u0636\u0631\u0627\u0626\u0628', 'v': 12.0, 'c': AC.warn},
      {'\u0646': '\u062f\u0639\u0645', 'v': 16.0, 'c': const Color(0xFF9C27B0)},
    ];
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('\u062a\u0648\u0632\u064a\u0639 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        SizedBox(height: 180, child: Row(textDirection: TextDirection.rtl, children: [
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: data.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(textDirection: TextDirection.rtl, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: d['c'] as Color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${(d["v"] as num).toInt()}%', style: TextStyle(color: d['c'] as Color, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Expanded(child: Text(d['\u0646'] as String, textDirection: TextDirection.rtl, style: const TextStyle(color: AC.ts, fontSize: 9), overflow: TextOverflow.ellipsis)),
            ]),
          )).toList())),
          SizedBox(width: 130, height: 130, child: PieChart(PieChartData(
            sectionsSpace: 2, centerSpaceRadius: 28,
            sections: data.map((d) => PieChartSectionData(
              value: (d['v'] as num).toDouble(), color: d['c'] as Color,
              radius: 28, showTitle: false,
            )).toList(),
          ))),
        ])),
      ]));
  }


  Widget _buildPerformanceCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.speed, color: AC.gold, size: 18),
        const SizedBox(width: 8),
        const Text('\u0645\u0624\u0634\u0631\u0627\u062a \u0627\u0644\u0623\u062f\u0627\u0621', style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _perfItem('\u0645\u0639\u062f\u0644 \u0627\u0644\u0625\u0646\u062c\u0627\u0632', '87%', Icons.trending_up, AC.ok)),
        const SizedBox(width: 8),
        Expanded(child: _perfItem('\u0631\u0636\u0627 \u0627\u0644\u0639\u0645\u0644\u0627\u0621', '92%', Icons.thumb_up, AC.cyan)),
        const SizedBox(width: 8),
        Expanded(child: _perfItem('\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u0648\u0642\u062a', '3.2\u064a', Icons.timer, AC.warn)),
        const SizedBox(width: 8),
        Expanded(child: _perfItem('\u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644', '95%', Icons.verified, AC.gold)),
      ]),
    ]),
  );

  Widget _perfItem(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.navy.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 9), textAlign: TextAlign.center),
    ]),
  );


  Widget _buildSectorChart() {
    final sectors = [
      {'\u0646': '\u062a\u062c\u0632\u0626\u0629', 'v': 28.0, 'c': AC.gold},
      {'\u0646': '\u0645\u0642\u0627\u0648\u0644\u0627\u062a', 'v': 22.0, 'c': AC.cyan},
      {'\u0646': '\u0635\u0646\u0627\u0639\u0629', 'v': 18.0, 'c': AC.ok},
      {'\u0646': '\u062e\u062f\u0645\u0627\u062a', 'v': 15.0, 'c': AC.warn},
      {'\u0646': '\u0639\u0642\u0627\u0631\u0627\u062a', 'v': 10.0, 'c': const Color(0xFF9C27B0)},
      {'\u0646': '\u0623\u062e\u0631\u0649', 'v': 7.0, 'c': AC.ts},
    ];
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('\u0627\u0644\u0639\u0645\u0644\u0627\u0621 \u0628\u0627\u0644\u0642\u0637\u0627\u0639', style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 35,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
              final idx = v.toInt();
              if (idx >= 0 && idx < sectors.length) return Text(sectors[idx]['\u0646'] as String, style: const TextStyle(color: AC.ts, fontSize: 7));
              return const Text('');
            })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25, getTitlesWidget: (v, m) =>
              Text('${v.toInt()}', style: const TextStyle(color: AC.ts, fontSize: 8)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10,
            getDrawingHorizontalLine: (v) => FlLine(color: AC.bdr, strokeWidth: 0.5)),
          barGroups: sectors.asMap().entries.map((e) => BarChartGroupData(x: e.key,
            barRods: [BarChartRodData(toY: (e.value['v'] as num).toDouble(), color: e.value['c'] as Color, width: 12, borderRadius: BorderRadius.circular(3))])).toList(),
        ))),
      ]),
    );
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
