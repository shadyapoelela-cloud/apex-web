import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import 'package:go_router/go_router.dart';

class FinancialOpsScreen extends StatefulWidget {
  final String? clientId;
  final String? clientName;
  const FinancialOpsScreen({super.key, this.clientId, this.clientName});
  @override State<FinancialOpsScreen> createState() => _FinOpsState();
}

class _FinOpsState extends State<FinancialOpsScreen> {
  int _selectedSection = 0;
  Map<String, dynamic>? _clientData;
  List<Map<String, dynamic>> _coaUploads = [];
  bool _loading = true;

  final _sections = [
    {
      'title': '\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a',
      'icon': Icons.account_tree_rounded,
      'color': 0xFF00C2E0,
    },
    {
      'title': '\u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629',
      'icon': Icons.balance_rounded,
      'color': 0xFFC9A84C,
    },
    {
      'title': '\u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a',
      'icon': Icons.analytics_rounded,
      'color': 0xFF2ECC8A,
    },
    {
      'title': '\u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629',
      'icon': Icons.receipt_long_rounded,
      'color': 0xFFF0A500,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.clientId != null) {
      final res = await ApiService.getClient(widget.clientId!);
      if (res.success) {
        setState(() {
          _clientData = res.data is Map ? res.data as Map<String, dynamic> : (res.data?['data'] as Map<String, dynamic>?);
          _loading = false;
        });
        return;
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('\u0627\u0644\u0639\u0645\u0644\u064a\u0627\u062a \u0627\u0644\u0645\u0627\u0644\u064a\u0629', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
          if (widget.clientName != null)
            Text(widget.clientName!, style: TextStyle(color: AC.ts, fontSize: 12)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.smart_toy, color: AC.gold),
            tooltip: 'Apex Copilot',
            onPressed: () => context.push('/copilot'),
          ),
        ],
      ),
      body: Column(children: [
        // Section Tabs
        Container(
          height: 100,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _sections.length,
            itemBuilder: (ctx, i) => _buildSectionTab(i),
          ),
        ),
        Divider(color: AC.bdr, height: 1),
        // Content
        Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildSectionTab(int index) {
    final section = _sections[index];
    final isSelected = _selectedSection == index;
    final color = Color(section['color'] as int);
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = index),
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AC.navy3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : AC.bdr, width: isSelected ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(section['icon'] as IconData, color: isSelected ? color : AC.ts, size: 26),
          const SizedBox(height: 6),
          Text(
            section['title'] as String,
            style: TextStyle(color: isSelected ? color : AC.ts, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case 0: return _buildCoaSection();
      case 1: return _buildTbSection();
      case 2: return _buildAnalysisSection();
      case 3: return _buildStatementsSection();
      default: return const SizedBox();
    }
  }

  Widget _buildCoaSection() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _infoCard(
        '\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a',
        '\u0627\u0644\u0645\u0633\u0627\u0631 \u0627\u0644\u0645\u0647\u0646\u064a: \u0631\u0641\u0639 \u2192 \u062a\u062d\u0644\u064a\u0644 \u2192 \u062a\u0635\u0646\u064a\u0641 \u2192 \u062c\u0648\u062f\u0629 \u2192 \u0627\u0639\u062a\u0645\u0627\u062f',
        Icons.info_outline, AC.cyan,
      ),
      const SizedBox(height: 12),
      _stepCard(1, '\u0631\u0641\u0639 \u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', '\u0631\u0641\u0639 \u0645\u0644\u0641 CSV \u0623\u0648 Excel', Icons.upload_file, AC.cyan, () {
        if (widget.clientId != null) context.push('/coa/upload', extra: {'clientId': widget.clientId!, 'clientName': widget.clientName ?? ''});
      }),
      _stepCard(2, '\u0645\u0639\u0627\u064a\u0646\u0629 \u0627\u0644\u062a\u0628\u0648\u064a\u0628', '\u0645\u0631\u0627\u062c\u0639\u0629 \u062a\u0635\u0646\u064a\u0641 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', Icons.map, AC.gold, () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u064a\u0631\u062c\u0649 \u0631\u0641\u0639 \u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a \u0623\u0648\u0644\u0627\u064b', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Color(0xFFF0A500)));
      }),
      _stepCard(3, '\u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u062c\u0648\u062f\u0629', '\u0641\u062d\u0635 \u0627\u0643\u062a\u0645\u0627\u0644 \u0648\u0627\u062a\u0633\u0627\u0642 \u0627\u0644\u0634\u062c\u0631\u0629', Icons.assessment, AC.ok, () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u064a\u0631\u062c\u0649 \u0631\u0641\u0639 \u0648\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0634\u062c\u0631\u0629 \u0623\u0648\u0644\u0627\u064b', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Color(0xFFF0A500)));
      }),
      _stepCard(4, '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0648\u0627\u0644\u0627\u0639\u062a\u0645\u0627\u062f', '\u0627\u0639\u062a\u0645\u0627\u062f \u0627\u0644\u0634\u062c\u0631\u0629 \u0644\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645', Icons.verified, AC.warn, () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u064a\u0631\u062c\u0649 \u0625\u0643\u0645\u0627\u0644 \u0645\u0631\u062d\u0644\u0629 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0623\u0648\u0644\u0627\u064b', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Color(0xFFF0A500)));
      }),
    ]);
  }

  Widget _buildTbSection() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _infoCard(
        '\u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629',
        '\u064a\u0631\u0628\u0637 \u0628\u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0639\u062a\u0645\u062f\u0629 \u0644\u0625\u0646\u062a\u0627\u062c \u0627\u0644\u062a\u062d\u0644\u064a\u0644',
        Icons.info_outline, AC.gold,
      ),
      const SizedBox(height: 12),
      _stepCard(1, '\u0631\u0641\u0639 \u0627\u0644\u0645\u064a\u0632\u0627\u0646', '\u0631\u0641\u0639 \u0645\u0644\u0641 \u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', Icons.upload_file, AC.gold, () {}),
      _stepCard(2, '\u0631\u0628\u0637 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a', '\u0645\u0637\u0627\u0628\u0642\u0629 \u0627\u0644\u0645\u064a\u0632\u0627\u0646 \u0628\u0627\u0644\u0634\u062c\u0631\u0629', Icons.link, AC.cyan, () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u064a\u0631\u062c\u0649 \u0631\u0641\u0639 \u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0623\u0648\u0644\u0627\u064b', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Color(0xFFF0A500)));
      }),
      _stepCard(3, '\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0631\u0628\u0637', '\u062a\u0623\u0643\u064a\u062f \u0627\u0644\u0645\u0637\u0627\u0628\u0642\u0629 \u0648\u062d\u0644 \u0627\u0644\u062a\u0639\u0627\u0631\u0636\u0627\u062a', Icons.checklist, AC.ok, () {}),
    ]);
  }

  Widget _buildAnalysisSection() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _infoCard(
        '\u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a',
        '\u0646\u0633\u0628 \u0645\u0627\u0644\u064a\u0629\u060c \u062a\u0648\u0635\u064a\u0627\u062a\u060c \u0645\u062e\u0627\u0637\u0631\u060c \u0648\u062a\u0641\u0633\u064a\u0631 \u0630\u0643\u064a',
        Icons.info_outline, AC.ok,
      ),
      const SizedBox(height: 12),
      _actionCard('\u062a\u062d\u0644\u064a\u0644 \u0633\u0631\u064a\u0639', '\u0631\u0641\u0639 \u0645\u064a\u0632\u0627\u0646 \u0648\u062a\u062d\u0644\u064a\u0644 \u0641\u0648\u0631\u064a', Icons.flash_on, AC.gold, () {
        context.push('/analysis/full');
      }),
      _actionCard('\u0627\u0644\u0646\u0633\u0628 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', '\u0633\u064a\u0648\u0644\u0629\u060c \u0631\u0628\u062d\u064a\u0629\u060c \u0643\u0641\u0627\u0621\u0629\u060c \u0631\u0627\u0641\u0639\u0629', Icons.pie_chart, AC.cyan, () {}),
      _actionCard('\u0627\u0644\u0645\u0642\u0627\u0631\u0646\u0629 \u0627\u0644\u062f\u0648\u0631\u064a\u0629', '\u0645\u0642\u0627\u0631\u0646\u0629 \u0628\u064a\u0646 \u0627\u0644\u0641\u062a\u0631\u0627\u062a', Icons.compare_arrows, AC.warn, () {}),
    ]);
  }

  Widget _buildStatementsSection() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _infoCard(
        '\u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629',
        '\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u062f\u062e\u0644\u060c \u0627\u0644\u0645\u0631\u0643\u0632 \u0627\u0644\u0645\u0627\u0644\u064a\u060c \u0627\u0644\u062a\u062f\u0641\u0642\u0627\u062a\u060c \u062d\u0642\u0648\u0642 \u0627\u0644\u0645\u0644\u0643\u064a\u0629',
        Icons.info_outline, AC.warn,
      ),
      const SizedBox(height: 12),
      _actionCard('\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0631\u0643\u0632 \u0627\u0644\u0645\u0627\u0644\u064a', 'Balance Sheet', Icons.account_balance_wallet, AC.gold, () {
        context.push('/financial-statements');
      }),
      _actionCard('\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u062f\u062e\u0644', 'Income Statement', Icons.trending_up, AC.ok, () {
        context.push('/financial-statements');
      }),
      _actionCard('\u0627\u0644\u062a\u062f\u0641\u0642\u0627\u062a \u0627\u0644\u0646\u0642\u062f\u064a\u0629', 'Cash Flow', Icons.water_drop, AC.cyan, () {
        context.push('/financial-statements');
      }),
      _actionCard('\u062a\u0635\u062f\u064a\u0631 PDF', '\u062a\u0635\u062f\u064a\u0631 \u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0643\u0645\u0644\u0641 PDF', Icons.picture_as_pdf, AC.err, () {}),
    ]);
  }

  Widget _infoCard(String title, String desc, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(desc, style: TextStyle(color: AC.ts, fontSize: 11)),
      ])),
    ]),
  );

  Widget _stepCard(int step, String title, String desc, IconData icon, Color color, VoidCallback onTap) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(desc, style: TextStyle(color: AC.ts, fontSize: 11)),
          ])),
          Icon(icon, color: color, size: 22),
        ]),
      ),
    ),
  );

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: TextStyle(color: AC.ts, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right, color: AC.ts, size: 20),
        ]),
      ),
    ),
  );
}
