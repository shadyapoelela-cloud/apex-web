import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class AuditWorkflowScreen extends StatefulWidget {
  final String? clientId;
  final String? clientName;
  const AuditWorkflowScreen({super.key, this.clientId, this.clientName});
  @override State<AuditWorkflowScreen> createState() => _AuditWFState();
}

class _AuditWFState extends State<AuditWorkflowScreen> {
  int _currentStage = 0;
  final List<Map<String, dynamic>> _stages = [
    {
      'title': '\u0627\u0644\u062a\u062e\u0637\u064a\u0637',
      'subtitle': 'Planning',
      'icon': Icons.map_outlined,
      'status': 'completed',
      'procedures': [
        {'\u0646\u0648\u0639': '\u0641\u0647\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629', 'status': 'done'},
        {'\u0646\u0648\u0639': '\u062a\u062d\u062f\u064a\u062f \u0627\u0644\u0645\u062e\u0627\u0637\u0631', 'status': 'done'},
        {'\u0646\u0648\u0639': '\u062e\u0637\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', 'status': 'done'},
      ],
    },
    {
      'title': '\u0641\u0647\u0645 \u0627\u0644\u0628\u064a\u0626\u0629',
      'subtitle': 'Environment',
      'icon': Icons.business_outlined,
      'status': 'completed',
      'procedures': [
        {'\u0646\u0648\u0639': '\u0627\u0644\u0631\u0642\u0627\u0628\u0629 \u0627\u0644\u062f\u0627\u062e\u0644\u064a\u0629', 'status': 'done'},
        {'\u0646\u0648\u0639': '\u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0629', 'status': 'done'},
      ],
    },
    {
      'title': '\u062a\u0642\u064a\u064a\u0645 \u0627\u0644\u0645\u062e\u0627\u0637\u0631',
      'subtitle': 'Risk Assessment',
      'icon': Icons.warning_amber_outlined,
      'status': 'completed',
      'procedures': [
        {'\u0646\u0648\u0639': '\u0645\u062e\u0627\u0637\u0631 \u062c\u0648\u0647\u0631\u064a\u0629', 'status': 'done'},
        {'\u0646\u0648\u0639': '\u0623\u0647\u0645\u064a\u0629 \u0646\u0633\u0628\u064a\u0629', 'status': 'done'},
      ],
    },
    {
      'title': '\u0627\u0644\u0641\u062d\u0635 \u0627\u0644\u062a\u0641\u0635\u064a\u0644\u064a',
      'subtitle': 'Detailed Testing',
      'icon': Icons.search_outlined,
      'status': 'in_progress',
      'procedures': [
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0646\u0642\u062f \u0648\u0627\u0644\u0628\u0646\u0648\u0643 \u2014 Cash & Bank', 'status': 'done'},
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0630\u0645\u0645 \u0627\u0644\u0645\u062f\u064a\u0646\u0629 \u2014 Receivables', 'status': 'done'},
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0645\u062e\u0632\u0648\u0646 \u2014 Inventory', 'status': 'in_progress'},
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0630\u0645\u0645 \u0627\u0644\u062f\u0627\u0626\u0646\u0629 \u2014 Payables', 'status': 'pending'},
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0623\u0635\u0648\u0644 \u0627\u0644\u062b\u0627\u0628\u062a\u0629 \u2014 Fixed Assets', 'status': 'pending'},
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a \u2014 Revenue', 'status': 'pending'},
        {'\u0646\u0648\u0639': '\u0641\u062d\u0635 \u0627\u0644\u0645\u0635\u0631\u0648\u0641\u0627\u062a \u2014 Expenses', 'status': 'pending'},
      ],
    },
    {
      'title': '\u0627\u0644\u0639\u064a\u0646\u0627\u062a',
      'subtitle': 'Sampling',
      'icon': Icons.filter_list_outlined,
      'status': 'pending',
      'procedures': [
        {'\u0646\u0648\u0639': '\u0639\u064a\u0646\u0627\u062a \u0639\u0634\u0648\u0627\u0626\u064a\u0629', 'status': 'pending'},
        {'\u0646\u0648\u0639': '\u0639\u064a\u0646\u0627\u062a \u0645\u0648\u062c\u0647\u0629', 'status': 'pending'},
      ],
    },
    {
      'title': '\u0623\u0648\u0631\u0627\u0642 \u0627\u0644\u0639\u0645\u0644',
      'subtitle': 'Workpapers',
      'icon': Icons.description_outlined,
      'status': 'pending',
      'procedures': [
        {'\u0646\u0648\u0639': '\u062a\u062c\u0645\u064a\u0639 \u0627\u0644\u0623\u062f\u0644\u0629', 'status': 'pending'},
        {'\u0646\u0648\u0639': '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a', 'status': 'pending'},
      ],
    },
    {
      'title': '\u0627\u0644\u062a\u0642\u0631\u064a\u0631',
      'subtitle': 'Report',
      'icon': Icons.assignment_outlined,
      'status': 'pending',
      'procedures': [
        {'\u0646\u0648\u0639': '\u0645\u0633\u0648\u062f\u0629 \u0627\u0644\u062a\u0642\u0631\u064a\u0631', 'status': 'pending'},
        {'\u0646\u0648\u0639': '\u0627\u0644\u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u0646\u0647\u0627\u0626\u064a', 'status': 'pending'},
      ],
    },
  ];

  final List<Map<String, dynamic>> _findings = [
    {
      'title': '\u0627\u062e\u062a\u0644\u0627\u0641 \u0641\u064a \u0631\u0635\u064a\u062f \u0627\u0644\u0628\u0646\u0643',
      'desc': '\u0641\u0631\u0642 12,500 \u0631.\u0633 \u0628\u064a\u0646 \u0643\u0634\u0641 \u0627\u0644\u0628\u0646\u0643 \u0648\u0627\u0644\u0633\u062c\u0644\u0627\u062a',
      'severity': 'high',
      'status': 'open',
    },
    {
      'title': '\u0645\u062e\u0632\u0648\u0646 \u0645\u062a\u0642\u0627\u062f\u0645',
      'desc': '\u0628\u0646\u0648\u062f \u0645\u062e\u0632\u0648\u0646 \u0644\u0645 \u062a\u062a\u062d\u0631\u0643 \u0645\u0646\u0630 180+ \u064a\u0648\u0645 \u0628\u0642\u064a\u0645\u0629 45,000 \u0631.\u0633',
      'severity': 'medium',
      'status': 'open',
    },
    {
      'title': '\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0646\u0627\u0642\u0635\u0629',
      'desc': '3 \u0641\u0648\u0627\u062a\u064a\u0631 \u0645\u0628\u064a\u0639\u0627\u062a \u0628\u062f\u0648\u0646 \u0623\u0648\u0627\u0645\u0631 \u0634\u0631\u0627\u0621 \u0645\u0631\u0641\u0642\u0629',
      'severity': 'low',
      'status': 'resolved',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0629', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
          Text('\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0629 \u2014 7 \u0645\u0631\u0627\u062d\u0644', style: TextStyle(color: AC.ts, fontSize: 11)),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.smart_toy, color: AC.gold), onPressed: () => context.push('/copilot')),
        ],
      ),
      body: Column(children: [
        // Stage Timeline
        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _stages.length,
            itemBuilder: (ctx, i) => _buildStageChip(i),
          ),
        ),
        Divider(color: AC.bdr, height: 1),
        // Content
        Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
          _buildStageDetail(_stages[_currentStage]),
          if (_currentStage == 3) ...[
            const SizedBox(height: 16),
            _buildFindingsSection(),
          ],
        ])),
      ]),
    );
  }

  Widget _buildStageChip(int i) {
    final s = _stages[i];
    final isActive = i == _currentStage;
    final isDone = s['status'] == 'completed';
    final isProgress = s['status'] == 'in_progress';
    final color = isDone ? AC.ok : isProgress ? AC.gold : AC.ts;
    return GestureDetector(
      onTap: () => setState(() => _currentStage = i),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : AC.navy3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color : AC.bdr, width: isActive ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isDone ? AC.ok.withValues(alpha: 0.2) : isProgress ? AC.gold.withValues(alpha: 0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(child: isDone
              ? Icon(Icons.check, color: AC.ok, size: 16)
              : Text('', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(height: 4),
          Text(s['title'] as String, style: TextStyle(color: isActive ? color : AC.ts, fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 1),
        ]),
      ),
    );
  }

  Widget _buildStageDetail(Map<String, dynamic> stage) {
    final procedures = stage['procedures'] as List;
    final color = stage['status'] == 'completed' ? AC.ok : stage['status'] == 'in_progress' ? AC.gold : AC.ts;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Stage Header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(stage['icon'] as IconData, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stage['title'] as String, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(stage['subtitle'] as String, style: TextStyle(color: AC.ts, fontSize: 12)),
          ])),
          _statusBadge(stage['status'] as String),
        ]),
      ),
      const SizedBox(height: 14),
      // Procedures
      Text('\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      ...procedures.map((p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Row(children: [
          _procedureIcon(p['status'] as String),
          const SizedBox(width: 10),
          Expanded(child: Text(p['\u0646\u0648\u0639'] as String, style: TextStyle(color: AC.tp, fontSize: 13))),
          _statusBadge(p['status'] as String),
        ]),
      )),
    ]);
  }

  Widget _buildFindingsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.find_in_page, color: AC.warn, size: 20),
        const SizedBox(width: 8),
        Text('\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(' \u0645\u0644\u0627\u062d\u0638\u0627\u062a', style: TextStyle(color: AC.warn, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 10),
      ..._findings.map((f) {
        final sevColor = f['severity'] == 'high' ? AC.err : f['severity'] == 'medium' ? AC.warn : AC.ok;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sevColor.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 30, decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Text(f['title'] as String, style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13))),
              _statusBadge(f['status'] as String),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 6),
              child: Text(f['desc'] as String, style: TextStyle(color: AC.ts, fontSize: 11)),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _procedureIcon(String status) {
    if (status == 'done') return Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: AC.ok.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.check, color: AC.ok, size: 14));
    if (status == 'in_progress') return Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.autorenew, color: AC.gold, size: 14));
    return Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: AC.ts.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.radio_button_unchecked, color: AC.ts, size: 14));
  }

  Widget _statusBadge(String status) {
    final map = {
      'completed': {'text': '\u0645\u0643\u062a\u0645\u0644', 'color': AC.ok},
      'done': {'text': '\u0645\u0643\u062a\u0645\u0644', 'color': AC.ok},
      'in_progress': {'text': '\u0642\u064a\u062f \u0627\u0644\u062a\u0646\u0641\u064a\u0630', 'color': AC.gold},
      'pending': {'text': '\u0644\u0645 \u064a\u0628\u062f\u0623', 'color': AC.ts},
      'open': {'text': '\u0645\u0641\u062a\u0648\u062d', 'color': AC.warn},
      'resolved': {'text': '\u0645\u063a\u0644\u0642', 'color': AC.ok},
    };
    final m = map[status] ?? {'text': status, 'color': AC.ts};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (m['color'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(m['text'] as String, style: TextStyle(color: m['color'] as Color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
