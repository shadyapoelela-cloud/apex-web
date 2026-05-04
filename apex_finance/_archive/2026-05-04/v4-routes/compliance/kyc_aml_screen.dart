/// APEX — KYC/AML Compliance
/// /compliance/kyc-aml — customer/vendor KYC + AML screening
library;

import 'package:flutter/material.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class KycAmlScreen extends StatefulWidget {
  const KycAmlScreen({super.key});
  @override
  State<KycAmlScreen> createState() => _KycAmlScreenState();
}

class _KycAmlScreenState extends State<KycAmlScreen> {
  String _filter = 'pending';

  final List<Map<String, dynamic>> _checks = [
    {'id': 'KYC-001', 'entity': 'شركة الرياض للمقاولات', 'kind': 'customer', 'risk_score': 25, 'status': 'pending', 'sanctions_match': false, 'pep_match': false},
    {'id': 'KYC-002', 'entity': 'مورد دولي (مصر)', 'kind': 'vendor', 'risk_score': 65, 'status': 'pending', 'sanctions_match': false, 'pep_match': false},
    {'id': 'KYC-003', 'entity': 'شركة الدمام للصناعة', 'kind': 'customer', 'risk_score': 15, 'status': 'approved', 'sanctions_match': false, 'pep_match': false},
    {'id': 'KYC-004', 'entity': 'مكتب محاماة دولي', 'kind': 'vendor', 'risk_score': 85, 'status': 'flagged', 'sanctions_match': false, 'pep_match': true},
    {'id': 'KYC-005', 'entity': 'شركة جدة العقارية', 'kind': 'customer', 'risk_score': 30, 'status': 'approved', 'sanctions_match': false, 'pep_match': false},
  ];

  Color _riskColor(int score) =>
      score >= 80 ? AC.err : score >= 60 ? AC.warn : score >= 30 ? AC.gold : AC.ok;

  String _riskLabel(int score) =>
      score >= 80 ? 'عالي جداً' : score >= 60 ? 'عالي' : score >= 30 ? 'متوسط' : 'منخفض';

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _checks;
    return _checks.where((c) => c['status'] == _filter).toList();
  }

  int _flagged() => _checks.where((c) => c['status'] == 'flagged').length;

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'KYC/AML — اعرف عميلك',
      subtitle: '${_checks.length} فحص · ${_flagged()} مع علامة',
      primaryCta: ApexCta(
        label: 'فحص جديد',
        icon: Icons.add,
        onPressed: () {},
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _checks.length),
        ApexFilterChip(
            label: 'بانتظار',
            selected: _filter == 'pending',
            onTap: () => setState(() => _filter = 'pending'),
            icon: Icons.pending,
            count: _checks.where((c) => c['status'] == 'pending').length),
        ApexFilterChip(
            label: 'مُعتمد',
            selected: _filter == 'approved',
            onTap: () => setState(() => _filter = 'approved'),
            icon: Icons.verified,
            count: _checks.where((c) => c['status'] == 'approved').length),
        ApexFilterChip(
            label: 'علامة',
            selected: _filter == 'flagged',
            onTap: () => setState(() => _filter = 'flagged'),
            icon: Icons.flag,
            count: _flagged()),
      ],
      items: _filtered,
      onRefresh: () async {},
      listHeader: _summaryCard(),
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('سجل المخاطر', '/compliance/risk-register', Icons.shield),
        ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
        ApexChipLink('Engagement Workspace', '/audit/engagements', Icons.folder),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.shield,
        title: 'لا توجد فحوصات KYC',
        description: 'فحص العملاء/الموردين قبل التعامل التزام تنظيمي',
      ),
      itemBuilder: (ctx, c) {
        final score = c['risk_score'] as int;
        final color = _riskColor(score);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.20),
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text('$score',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['id']} — ${c['entity']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Row(children: [
                  Text(c['kind'] == 'customer' ? 'عميل' : 'مورد',
                      style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_riskLabel(score),
                        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
                if (c['sanctions_match'] == true || c['pep_match'] == true)
                  Row(children: [
                    if (c['sanctions_match'] == true) ...[
                      Icon(Icons.block, color: AC.err, size: 11),
                      const SizedBox(width: 3),
                      Text('Sanctions', style: TextStyle(color: AC.err, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                    ],
                    if (c['pep_match'] == true) ...[
                      Icon(Icons.warning_amber, color: AC.warn, size: 11),
                      const SizedBox(width: 3),
                      Text('PEP — Politically Exposed Person',
                          style: TextStyle(color: AC.warn, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ],
                  ]),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _summaryCard() {
    final flagged = _flagged();
    final hasIssues = flagged > 0;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: hasIssues ? AC.warn.withValues(alpha: 0.4) : AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(hasIssues ? Icons.warning_amber : Icons.shield_outlined,
              color: hasIssues ? AC.warn : AC.gold),
          const SizedBox(width: 8),
          Text('AML Screening Summary',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryItem('Sanctions Hits', '0', AC.ok)),
          Expanded(child: _summaryItem('PEP Matches', '1', AC.warn)),
          Expanded(child: _summaryItem('High-Risk Checks', '$flagged', AC.err)),
        ]),
      ]),
    );
  }

  Widget _summaryItem(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900)),
        ],
      );
}
