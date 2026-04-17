/// APEX Platform — Consolidation (IFRS 10)
/// ═══════════════════════════════════════════════════════════════
/// Multi-entity consolidation with intercompany elimination and
/// non-controlling interest (NCI).
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class ConsolidationScreen extends StatefulWidget {
  const ConsolidationScreen({super.key});
  @override
  State<ConsolidationScreen> createState() => _ConsolidationScreenState();
}

class _ConsolidationScreenState extends State<ConsolidationScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> _runDemo() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final payload = {
        'group_name': 'مجموعة أبيكس',
        'period_label': 'FY 2026',
        'presentation_currency': 'SAR',
        'entities': [
          {
            'entity_id': 'P', 'entity_name': 'الشركة الأم',
            'ownership_pct': '100', 'is_parent': true,
            'lines': [
              {'account_code': '1100', 'account_name': 'النقد',
               'classification': 'asset', 'amount': '5000'},
              {'account_code': '1200', 'account_name': 'ذمم بينية',
               'classification': 'asset', 'amount': '1000'},
              {'account_code': '2100', 'account_name': 'ذمم دائنة',
               'classification': 'liability', 'amount': '-1500'},
              {'account_code': '3000', 'account_name': 'رأس المال',
               'classification': 'equity', 'amount': '-4000'},
              {'account_code': '4000', 'account_name': 'مبيعات',
               'classification': 'revenue', 'amount': '-3000'},
              {'account_code': '4001', 'account_name': 'مبيعات بينية',
               'classification': 'revenue', 'amount': '-1000'},
              {'account_code': '5000', 'account_name': 'تكاليف',
               'classification': 'expense', 'amount': '1500'},
            ],
          },
          {
            'entity_id': 'S1', 'entity_name': 'شركة تابعة 80%',
            'ownership_pct': '80',
            'lines': [
              {'account_code': '1100', 'account_name': 'النقد',
               'classification': 'asset', 'amount': '2500'},
              {'account_code': '2200', 'account_name': 'ذمم بينية',
               'classification': 'liability', 'amount': '-1000'},
              {'account_code': '3000', 'account_name': 'رأس المال',
               'classification': 'equity', 'amount': '-1000'},
              {'account_code': '4000', 'account_name': 'مبيعات',
               'classification': 'revenue', 'amount': '-2000'},
              {'account_code': '5001', 'account_name': 'مشتريات بينية',
               'classification': 'expense', 'amount': '1000'},
              {'account_code': '5002', 'account_name': 'تكاليف أخرى',
               'classification': 'expense', 'amount': '500'},
            ],
          },
        ],
        'intercompany': [
          {
            'description': 'إلغاء ذمم بينية',
            'from_entity': 'P', 'to_entity': 'S1',
            'amount': '1000',
            'dr_account': '1200', 'cr_account': '2200',
          },
          {
            'description': 'إلغاء مبيعات بينية',
            'from_entity': 'P', 'to_entity': 'S1',
            'amount': '1000',
            'dr_account': '4001', 'cr_account': '5001',
          },
        ],
      };
      final r = await ApiService.consolidate(payload);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل');
      }
    } catch (e) { if (mounted) setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('القوائم الموحّدة (IFRS 10)', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy2,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.business, color: AC.gold, size: 20),
              const SizedBox(width: 8),
              Text('محاكاة توحيد قوائم — أب + شركة تابعة 80%',
                style: TextStyle(color: AC.tp, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            Text('ينفّذ إلغاء المعاملات الداخلية (ذمم بينية + مبيعات بينية) '
              'ويحسب حصة الأقلية NCI من صافي الدخل وحقوق الملكية.',
              style: TextStyle(color: AC.ts, fontSize: 12, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 14),
        if (_error != null) Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6)),
          child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 50, child: ElevatedButton.icon(
          onPressed: _loading ? null : _runDemo,
          icon: _loading ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.merge_type),
          label: const Text('ابنِ القوائم الموحّدة'))),
        const SizedBox(height: 20),
        if (_result != null) ..._renderResult(_result!),
      ]),
    ),
  );

  List<Widget> _renderResult(Map d) {
    final balanced = d['is_balanced'] == true;
    final color = balanced ? AC.ok : AC.err;
    final lines = (d['consolidated_lines'] ?? []) as List;

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(balanced ? Icons.verified : Icons.warning_amber_rounded,
            color: color, size: 30),
          const SizedBox(height: 4),
          Text(balanced ? 'القوائم الموحّدة متوازنة ✓' : 'عدم توازن',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${d['group_name']} — ${d['period_label']}',
            style: TextStyle(color: AC.tp, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 14),
      _totalsGrid(d),
      const SizedBox(height: 14),
      _niSplit(d),
      const SizedBox(height: 14),
      _linesTable(lines),
      const SizedBox(height: 8),
      if ((d['warnings'] as List? ?? []).isNotEmpty) Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
          border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: (d['warnings'] as List).map((w) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('• $w', style: TextStyle(color: AC.warn, fontSize: 12)),
          )).toList(),
        ),
      ),
    ];
  }

  Widget _totalsGrid(Map d) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      _kv('إجمالي الأصول', '${d['total_assets']} ${d['presentation_currency']}', vc: AC.ok),
      _kv('إجمالي الخصوم', '${d['total_liabilities']} ${d['presentation_currency']}', vc: AC.warn),
      _kv('حقوق ملكية الأم', '${d['total_equity_parent']} ${d['presentation_currency']}', vc: AC.info),
      _kv('حقوق الأقلية (NCI)', '${d['total_nci']} ${d['presentation_currency']}', vc: AC.purple),
      Divider(color: AC.bdr),
      _kv('إجمالي المعاملات الداخلية المُلغاة',
        '${d['total_eliminations']} ${d['presentation_currency']}', vc: AC.err),
    ]),
  );

  Widget _niSplit(Map d) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.gold.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.trending_up, color: AC.gold, size: 18),
        const SizedBox(width: 8),
        Text('توزيع صافي الدخل الموحّد',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      _kv('صافي الدخل الموحّد', '${d['consolidated_net_income']}', bold: true),
      _kv('حصة الأم', '${d['net_income_to_parent']}', vc: AC.info),
      _kv('حصة الأقلية (NCI)', '${d['net_income_to_nci']}', vc: AC.purple),
    ]),
  );

  Widget _linesTable(List lines) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('تفصيل البنود',
        style: TextStyle(color: AC.tp, fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(width: 60, child: Text('الكود',
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(flex: 3, child: Text('الاسم',
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        SizedBox(width: 60, child: Text('الأم',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        SizedBox(width: 60, child: Text('التابعة',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        SizedBox(width: 60, child: Text('إلغاء',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        SizedBox(width: 70, child: Text('موحّد',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
      Divider(color: AC.bdr, height: 12),
      ...lines.map((ln) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 60, child: Text('${ln['account_code']}',
            style: TextStyle(color: AC.gold, fontSize: 11, fontFamily: 'monospace'))),
          Expanded(flex: 3, child: Text('${ln['account_name']}',
            style: TextStyle(color: AC.tp, fontSize: 11),
            overflow: TextOverflow.ellipsis)),
          SizedBox(width: 60, child: Text('${ln['parent_amount']}',
            textAlign: TextAlign.right,
            style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'))),
          SizedBox(width: 60, child: Text('${ln['subsidiaries_amount']}',
            textAlign: TextAlign.right,
            style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'))),
          SizedBox(width: 60, child: Text('${ln['eliminations']}',
            textAlign: TextAlign.right,
            style: TextStyle(color: AC.err, fontSize: 10, fontFamily: 'monospace'))),
          SizedBox(width: 70, child: Text('${ln['consolidated']}',
            textAlign: TextAlign.right,
            style: TextStyle(color: AC.gold, fontSize: 11,
              fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
        ]),
      )),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
