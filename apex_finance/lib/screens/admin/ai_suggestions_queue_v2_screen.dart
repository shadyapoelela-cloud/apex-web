/// APEX — AI Suggestions Approval Queue v2
/// /admin/ai-suggestions-v2 — Confidence-Gated Autopilot review queue
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AiSuggestionsQueueV2Screen extends StatefulWidget {
  const AiSuggestionsQueueV2Screen({super.key});
  @override
  State<AiSuggestionsQueueV2Screen> createState() =>
      _AiSuggestionsQueueV2ScreenState();
}

class _AiSuggestionsQueueV2ScreenState
    extends State<AiSuggestionsQueueV2Screen> {
  String _filter = 'pending';

  // Demo suggestions
  final List<Map<String, dynamic>> _suggestions = [
    {
      'id': 'sug_001',
      'title': 'تصنيف 12 معاملة بنكية تلقائياً',
      'description': 'الذكاء يقترح تصنيف معاملات بمتجر STC إلى "مصاريف اتصالات"',
      'confidence': 0.97,
      'impact': '4,500 SAR',
      'status': 'pending',
      'kind': 'classify',
    },
    {
      'id': 'sug_002',
      'title': 'إقفال فاتورة قديمة كـ شطب',
      'description': 'فاتورة INV-2024-0089 لم تُحصّل منذ 14 شهراً — اقتراح شطب',
      'confidence': 0.85,
      'impact': '2,300 SAR',
      'status': 'pending',
      'kind': 'writeoff',
    },
    {
      'id': 'sug_003',
      'title': 'دمج عميلين مكررين',
      'description': '"شركة الرياض" و"الرياض ش.م.م" نفس الـ VAT — اقتراح دمج',
      'confidence': 0.92,
      'impact': '—',
      'status': 'pending',
      'kind': 'merge',
    },
    {
      'id': 'sug_004',
      'title': 'تسوية فرق ZATCA 25 هللة',
      'description': 'فرق rounding بسيط — استبعاد تلقائي',
      'confidence': 0.99,
      'impact': '0.25 SAR',
      'status': 'auto_approved',
      'kind': 'adjustment',
    },
    {
      'id': 'sug_005',
      'title': 'إصدار قيد إقفال لحساب نشط منذ 18 شهر',
      'description': 'حساب 5230 — مصاريف متفرقة لم يُستخدم — اقتراح إغلاق',
      'confidence': 0.78,
      'impact': '—',
      'status': 'pending',
      'kind': 'archive',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    return _suggestions.where((s) => s['status'] == _filter).toList();
  }

  IconData _kindIcon(String k) => switch (k) {
        'classify' => Icons.category,
        'writeoff' => Icons.delete_outline,
        'merge' => Icons.merge,
        'adjustment' => Icons.tune,
        'archive' => Icons.archive,
        _ => Icons.lightbulb,
      };

  Color _confidenceColor(double c) =>
      c >= 0.95 ? AC.ok : c >= 0.85 ? AC.gold : AC.warn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('اقتراحات AI', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.bolt, color: AC.gold),
            tooltip: 'اعتمد كل ما فوق 95%',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم اعتماد 1 اقتراح تلقائياً')),
              );
            },
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: AC.navy2,
          child: Row(children: [
            for (final s in [
              ('pending', 'قيد المراجعة', AC.warn),
              ('auto_approved', 'مُعتمد تلقائياً', AC.ok),
              ('rejected', 'مرفوض', AC.err),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(s.$2),
                  selected: _filter == s.$1,
                  onSelected: (_) => setState(() => _filter = s.$1),
                  selectedColor: s.$3,
                  labelStyle: TextStyle(color: _filter == s.$1 ? AC.navy : AC.tp),
                ),
              ),
          ]),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.inbox, color: AC.ts, size: 48),
                      const SizedBox(height: 12),
                      Text('لا توجد اقتراحات في هذه الحالة',
                          style: TextStyle(color: AC.ts)),
                    ]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _suggestionCard(_filtered[i]),
                ),
        ),
      ]),
    );
  }

  Widget _suggestionCard(Map<String, dynamic> s) {
    final conf = s['confidence'] as double;
    final color = _confidenceColor(conf);
    final isAuto = conf >= 0.95;
    final isPending = s['status'] == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Icon(_kindIcon(s['kind'] as String), color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s['title'] as String,
                  style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${(conf * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['description'] as String,
                style: TextStyle(color: AC.tp, fontSize: 12, height: 1.6)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.attach_money, size: 12, color: AC.ts),
              const SizedBox(width: 4),
              Text('الأثر: ${s['impact']}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
              const Spacer(),
              if (isAuto && isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AC.ok.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('AUTO',
                      style: TextStyle(color: AC.ok, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ]),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => s['status'] = 'rejected');
                    },
                    icon: Icon(Icons.close, color: AC.err, size: 14),
                    label: Text('رفض', style: TextStyle(color: AC.err)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AC.err)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => s['status'] = 'auto_approved');
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('اعتمد'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AC.ok, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
