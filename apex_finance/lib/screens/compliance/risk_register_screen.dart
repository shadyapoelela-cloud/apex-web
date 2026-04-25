/// APEX — Risk Register
/// /compliance/risk-register — enterprise risk + impact × probability
library;

import 'package:flutter/material.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class RiskRegisterScreen extends StatefulWidget {
  const RiskRegisterScreen({super.key});
  @override
  State<RiskRegisterScreen> createState() => _RiskRegisterScreenState();
}

class _RiskRegisterScreenState extends State<RiskRegisterScreen> {
  String _filter = 'all';

  final List<Map<String, dynamic>> _risks = [
    {'id': 'R-001', 'title': 'تأخر تحصيل ذمم كبيرة', 'category': 'مالي', 'impact': 4, 'probability': 3, 'owner': 'مدير مالي', 'status': 'open'},
    {'id': 'R-002', 'title': 'انتهاء CSID دون تجديد', 'category': 'امتثال', 'impact': 5, 'probability': 2, 'owner': 'مدير الامتثال', 'status': 'mitigated'},
    {'id': 'R-003', 'title': 'تقلبات سعر الصرف EGP', 'category': 'سوق', 'impact': 3, 'probability': 4, 'owner': 'الخزينة', 'status': 'open'},
    {'id': 'R-004', 'title': 'فقدان موظف رئيسي', 'category': 'تشغيلي', 'impact': 4, 'probability': 2, 'owner': 'HR', 'status': 'mitigated'},
    {'id': 'R-005', 'title': 'هجوم سيبراني', 'category': 'أمن سيبراني', 'impact': 5, 'probability': 3, 'owner': 'IT', 'status': 'open'},
    {'id': 'R-006', 'title': 'تغيّر في قوانين الزكاة', 'category': 'تنظيمي', 'impact': 3, 'probability': 2, 'owner': 'مدير الامتثال', 'status': 'closed'},
  ];

  int _score(Map r) => (r['impact'] as int) * (r['probability'] as int);
  Color _scoreColor(int s) =>
      s >= 16 ? AC.err : s >= 9 ? AC.warn : s >= 4 ? AC.gold : AC.ok;

  String _scoreLabel(int s) =>
      s >= 16 ? 'حرج' : s >= 9 ? 'عالي' : s >= 4 ? 'متوسط' : 'منخفض';

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _risks;
    return _risks.where((r) => r['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'سجل المخاطر',
      subtitle: '${_risks.length} خطر',
      primaryCta: ApexCta(
        label: 'خطر جديد',
        icon: Icons.add,
        onPressed: () {},
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _risks.length),
        ApexFilterChip(
            label: 'مفتوح',
            selected: _filter == 'open',
            onTap: () => setState(() => _filter = 'open'),
            icon: Icons.error_outline,
            count: _risks.where((r) => r['status'] == 'open').length),
        ApexFilterChip(
            label: 'مُخفّف',
            selected: _filter == 'mitigated',
            onTap: () => setState(() => _filter = 'mitigated'),
            icon: Icons.shield,
            count: _risks.where((r) => r['status'] == 'mitigated').length),
        ApexFilterChip(
            label: 'مُغلق',
            selected: _filter == 'closed',
            onTap: () => setState(() => _filter = 'closed'),
            icon: Icons.check_circle,
            count: _risks.where((r) => r['status'] == 'closed').length),
      ],
      items: _filtered,
      onRefresh: () async {},
      listHeader: _heatmapCard(),
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('KYC/AML', '/compliance/kyc-aml', Icons.fact_check),
        ApexChipLink('Engagement Workspace', '/audit/engagements', Icons.folder),
        ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.shield,
        title: 'لا توجد مخاطر مسجّلة',
        description: 'سجل المخاطر يساعدك على تقييم Impact × Probability',
        primaryLabel: 'خطر جديد',
        primaryIcon: Icons.add,
        onPrimary: () {},
      ),
      itemBuilder: (ctx, r) {
        final score = _score(r);
        final color = _scoreColor(score);
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
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['id']} — ${r['title']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Row(children: [
                  Text('${r['category']} · أثر ${r['impact']} × احتمال ${r['probability']}',
                      style: TextStyle(color: AC.ts, fontSize: 10.5)),
                ]),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_scoreLabel(score),
                        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Text('${r['owner']}',
                      style: TextStyle(color: AC.ts, fontSize: 10)),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _heatmapCard() {
    final critical = _risks.where((r) => _score(r) >= 16).length;
    final high = _risks.where((r) => _score(r) >= 9 && _score(r) < 16).length;
    final medium = _risks.where((r) => _score(r) >= 4 && _score(r) < 9).length;
    final low = _risks.where((r) => _score(r) < 4).length;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Risk Heatmap',
            style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _heatBox('حرج', critical, AC.err)),
          const SizedBox(width: 6),
          Expanded(child: _heatBox('عالي', high, AC.warn)),
          const SizedBox(width: 6),
          Expanded(child: _heatBox('متوسط', medium, AC.gold)),
          const SizedBox(width: 6),
          Expanded(child: _heatBox('منخفض', low, AC.ok)),
        ]),
      ]),
    );
  }

  Widget _heatBox(String label, int count, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}
