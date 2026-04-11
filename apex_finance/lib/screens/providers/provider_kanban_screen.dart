import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class ProviderKanbanScreen extends StatefulWidget {
  const ProviderKanbanScreen({super.key});
  @override State<ProviderKanbanScreen> createState() => _PKState();
}

class _PKState extends State<ProviderKanbanScreen> {
  final _columns = [
    {
      'title': '\u0637\u0644\u0628\u0627\u062a \u062c\u062f\u064a\u062f\u0629',
      'color': AC.cyan,
      'count': 3,
      'items': [
        {'\u0646': '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u0623\u0645\u0644', 'price': '2,500', 'time': '\u0642\u0628\u0644 \u0633\u0627\u0639\u062a\u064a\u0646'},
        {'\u0646': '\u0636\u0631\u0627\u0626\u0628 \u2014 \u0645\u0624\u0633\u0633\u0629 \u0627\u0644\u0628\u0631\u0643\u0629', 'price': '4,200', 'time': '\u0642\u0628\u0644 5 \u0633\u0627\u0639\u0627\u062a'},
        {'\u0646': '\u0645\u0631\u0627\u062c\u0639\u0629 \u2014 \u0645\u0635\u0646\u0639 \u0627\u0644\u062c\u0648\u062f\u0629', 'price': '5,500', 'time': '\u0623\u0645\u0633'},
      ],
    },
    {
      'title': '\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629',
      'color': AC.warn,
      'count': 2,
      'items': [
        {'\u0646': '\u062c\u0627\u0647\u0632\u064a\u0629 \u062a\u0645\u0648\u064a\u0644\u064a\u0629 \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u0646\u0648\u0631', 'price': '3,800', 'time': '\u0645\u0646\u0630 3 \u0623\u064a\u0627\u0645'},
        {'\u0646': '\u062a\u0631\u0627\u062e\u064a\u0635 \u2014 \u0645\u0639\u0647\u062f \u0627\u0644\u062a\u0637\u0648\u064a\u0631', 'price': '2,200', 'time': '\u0645\u0646\u0630 5 \u0623\u064a\u0627\u0645'},
      ],
    },
    {
      'title': '\u0642\u064a\u062f \u0627\u0644\u062a\u0646\u0641\u064a\u0630',
      'color': AC.gold,
      'count': 4,
      'items': [
        {'\u0646': '\u0645\u0631\u0627\u062c\u0639\u0629 \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u0631\u064a\u0627\u0636', 'price': '5,500', 'time': '\u0627\u0644\u0645\u0631\u062d\u0644\u0629 4/7'},
        {'\u0646': '\u062a\u062d\u0644\u064a\u0644 \u2014 \u0645\u0624\u0633\u0633\u0629 \u0627\u0644\u0646\u062c\u0627\u062d', 'price': '2,500', 'time': '\u0627\u0644\u0645\u0631\u062d\u0644\u0629 2/3'},
        {'\u0646': '\u0636\u0631\u0627\u0626\u0628 \u2014 \u0639\u064a\u0627\u062f\u0627\u062a \u0627\u0644\u0628\u0633\u0645\u0629', 'price': '4,200', 'time': '\u0627\u0644\u0645\u0631\u062d\u0644\u0629 1/4'},
        {'\u0646': '\u062f\u0639\u0645 \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u0645\u0633\u062a\u0642\u0628\u0644', 'price': '1,800', 'time': '\u0627\u0644\u0645\u0631\u062d\u0644\u0629 3/3'},
      ],
    },
    {
      'title': '\u0645\u0643\u062a\u0645\u0644',
      'color': AC.ok,
      'count': 8,
      'items': [
        {'\u0646': '\u062a\u062d\u0644\u064a\u0644 \u2014 \u0634\u0631\u0643\u0629 \u0627\u0644\u062a\u0642\u0646\u064a\u0629', 'price': '2,500', 'time': '\u0645\u0643\u062a\u0645\u0644 1 \u0623\u0628\u0631\u064a\u0644', 'rating': 4.8},
        {'\u0646': '\u0645\u0631\u0627\u062c\u0639\u0629 \u2014 \u0645\u0635\u0646\u0639 \u0627\u0644\u062e\u0644\u064a\u062c', 'price': '5,500', 'time': '\u0645\u0643\u062a\u0645\u0644 28 \u0645\u0627\u0631\u0633', 'rating': 4.9},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('\u0645\u0632\u0648\u062f\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.smart_toy, color: AC.gold), onPressed: () => context.push('/copilot')),
        ],
      ),
      body: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: _columns.map((col) => _buildColumn(col)).toList(),
      ),
    );
  }

  Widget _buildColumn(Map<String, dynamic> col) {
    final items = col['items'] as List;
    final color = col['color'] as Color;
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 10),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(children: [
            Text(col['title'] as String, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Text('', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // Items
        Expanded(child: Container(
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)), border: Border(left: BorderSide(color: color.withValues(alpha: 0.3)), right: BorderSide(color: color.withValues(alpha: 0.3)), bottom: BorderSide(color: color.withValues(alpha: 0.3)))),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _buildCard(items[i], color),
          ),
        )),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['\u0646'] as String, style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.payments_outlined, color: AC.gold, size: 14),
          const SizedBox(width: 4),
          Text(' \u0631.\u0633', style: TextStyle(color: AC.gold, fontSize: 11)),
          const Spacer(),
          Text(item['time'] as String, style: TextStyle(color: AC.ts, fontSize: 10)),
        ]),
        if (item.containsKey('rating')) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.star, color: AC.gold, size: 14),
            const SizedBox(width: 2),
            Text('', style: TextStyle(color: AC.gold, fontSize: 11)),
          ]),
        ],
      ]),
    );
  }
}
