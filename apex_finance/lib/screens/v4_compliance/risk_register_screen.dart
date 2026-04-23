/// APEX Wave 90 — Enterprise Risk Register.
/// Route: /app/compliance/regulatory/risk-register
///
/// ERM per COSO — risk heatmap, treatment plans, KRIs.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class RiskRegisterScreen extends StatefulWidget {
  const RiskRegisterScreen({super.key});
  @override
  State<RiskRegisterScreen> createState() => _RiskRegisterScreenState();
}

class _RiskRegisterScreenState extends State<RiskRegisterScreen> {
  String _viewMode = 'list';
  String _categoryFilter = 'all';

  final _risks = [
    _Risk('RSK-001', 'تعرّض لأسعار العملات الأجنبية', 'financial', 4, 4, 'treating', 'تحوّط 65% + مراقبة أسبوعية', 'أحمد العتيبي', core_theme.AC.err),
    _Risk('RSK-002', 'هجوم سيبراني يستهدف بيانات العملاء', 'cyber', 3, 5, 'treating', 'SOC 24/7 + Penetration Testing ربعي + Cyber Insurance', 'راشد العنزي', core_theme.AC.err),
    _Risk('RSK-003', 'تغيّر تنظيمي في أنظمة ZATCA', 'regulatory', 3, 3, 'accepting', 'فريق امتثال متابع للتحديثات + مستشار ضريبي', 'محمد القحطاني', core_theme.AC.warn),
    _Risk('RSK-004', 'تركّز في عميل رئيسي واحد', 'strategic', 3, 4, 'treating', 'خطة تنويع العملاء Q1-Q4 — هدف أقل من 15%', 'سارة الدوسري', core_theme.AC.warn),
    _Risk('RSK-005', 'فقدان موظف مفتاح', 'operational', 3, 3, 'treating', 'خطط التعاقب، شراكات مع 3 بدائل، مكافآت احتفاظ', 'لينا البكري', core_theme.AC.warn),
    _Risk('RSK-006', 'انقطاع خدمة نظام SAP', 'operational', 2, 4, 'treating', 'DR Site في AWS + RTO 4 ساعات + Hot Standby', 'راشد العنزي', core_theme.AC.warn),
    _Risk('RSK-007', 'عدم الالتزام بشروط العقود مع العملاء', 'operational', 2, 3, 'treating', 'SLA Monitoring + Penalty Clauses', 'محمد القحطاني', core_theme.AC.warn),
    _Risk('RSK-008', 'تأخر المدفوعات من العملاء > 90 يوم', 'financial', 3, 3, 'treating', 'Credit Scoring + Automated Follow-up + Collection Agency', 'نورة الغامدي', core_theme.AC.warn),
    _Risk('RSK-009', 'تغيّر في السياسة الضريبية (VAT/CT)', 'regulatory', 2, 3, 'monitoring', 'متابعة بيانات ZATCA + تحديث السياسات', 'راشد العنزي', core_theme.AC.warn),
    _Risk('RSK-010', 'فقدان بيانات حساسة بسبب خطأ بشري', 'operational', 2, 4, 'treating', 'DLP + Training + Access Controls', 'راشد العنزي', core_theme.AC.warn),
    _Risk('RSK-011', 'احتيال مالي داخلي', 'fraud', 1, 5, 'treating', 'SoD + Automated Controls + Whistleblower Hotline', 'محمد القحطاني', core_theme.AC.warn),
    _Risk('RSK-012', 'تقلّب أسعار المواد الخام', 'financial', 3, 2, 'accepting', 'عقود طويلة الأجل + مخزون استراتيجي', 'فهد الشمري', core_theme.AC.warn),
    _Risk('RSK-013', 'انخفاض رضا العملاء وفقدانهم', 'strategic', 2, 3, 'treating', 'NPS شهري + فريق Customer Success مخصّص', 'سارة الدوسري', core_theme.AC.warn),
    _Risk('RSK-014', 'عدم الالتزام بمعايير الأمن السيبراني NCA', 'regulatory', 2, 4, 'treating', 'برنامج امتثال ECC كامل + مراجعة سنوية', 'راشد العنزي', core_theme.AC.warn),
    _Risk('RSK-015', 'كارثة طبيعية (زلزال/فيضان)', 'operational', 1, 4, 'accepting', 'تأمين شامل + DR Site', 'لينا البكري', core_theme.AC.ok),
  ];

  List<_Risk> get _filtered {
    if (_categoryFilter == 'all') return _risks;
    return _risks.where((r) => r.category == _categoryFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final critical = _risks.where((r) => r.likelihood * r.impact >= 12).length;
    final high = _risks.where((r) => r.likelihood * r.impact >= 8 && r.likelihood * r.impact < 12).length;
    final medium = _risks.where((r) => r.likelihood * r.impact >= 4 && r.likelihood * r.impact < 8).length;
    final low = _risks.where((r) => r.likelihood * r.impact < 4).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('مخاطر مسجّلة', '${_risks.length}', core_theme.AC.info, Icons.security),
            _kpi('حرجة', '$critical', core_theme.AC.err, Icons.error),
            _kpi('عالية', '$high', core_theme.AC.warn, Icons.warning),
            _kpi('متوسطة', '$medium', core_theme.AC.warn, Icons.info),
            _kpi('منخفضة', '$low', core_theme.AC.ok, Icons.check_circle),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _viewBtn('list', 'قائمة', Icons.list),
            const SizedBox(width: 8),
            _viewBtn('heatmap', 'خريطة المخاطر', Icons.grid_view),
            const Spacer(),
            _filter('الفئة', _categoryFilter, const [
              _FOpt('all', 'الكل'),
              _FOpt('financial', 'مالية'),
              _FOpt('operational', 'تشغيلية'),
              _FOpt('strategic', 'استراتيجية'),
              _FOpt('regulatory', 'تنظيمية'),
              _FOpt('cyber', 'سيبرانية'),
              _FOpt('fraud', 'احتيال'),
            ], (v) => setState(() => _categoryFilter = v)),
          ],
        ),
        const SizedBox(height: 16),
        if (_viewMode == 'list') _buildListView() else _buildHeatmap(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجل المخاطر المؤسسية',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Enterprise Risk Management · COSO ERM · ISO 31000 · خريطة حرارية + خطط معالجة',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewBtn(String id, String label, IconData icon) {
    final selected = _viewMode == id;
    return InkWell(
      onTap: () => setState(() => _viewMode = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? core_theme.AC.err : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? core_theme.AC.err : core_theme.AC.td),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : core_theme.AC.tp)),
          ],
        ),
      ),
    );
  }

  Widget _filter(String label, String value, List<_FOpt> opts, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.td),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: core_theme.AC.tp),
            items: opts.map((o) => DropdownMenuItem(value: o.id, child: Text(o.label))).toList(),
            onChanged: (v) => onChanged(v ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        for (final r in _filtered) _riskCard(r),
      ],
    );
  }

  Widget _riskCard(_Risk r) {
    final score = r.likelihood * r.impact;
    final scoreColor = score >= 12 ? core_theme.AC.err : score >= 8 ? core_theme.AC.warn : score >= 4 ? core_theme.AC.warn : core_theme.AC.ok;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('خطر', style: TextStyle(color: core_theme.AC.ts, fontSize: 9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _catColor(r.category).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(_catLabel(r.category),
                              style: TextStyle(fontSize: 10, color: _catColor(r.category), fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _strategyColor(r.strategy).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(_strategyLabel(r.strategy),
                              style: TextStyle(fontSize: 10, color: _strategyColor(r.strategy), fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Icon(Icons.person, size: 11, color: core_theme.AC.ts),
                        const SizedBox(width: 3),
                        Text('صاحب المخاطرة: ${r.owner}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _scoreBox('احتمال', r.likelihood),
                  const SizedBox(height: 4),
                  _scoreBox('أثر', r.impact),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: core_theme.AC.info, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 14, color: core_theme.AC.info),
                const SizedBox(width: 6),
                Text('خطة المعالجة: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
                Expanded(child: Text(r.treatment, style: const TextStyle(fontSize: 11, height: 1.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, int value) {
    final color = value >= 4 ? core_theme.AC.err : value >= 3 ? core_theme.AC.warn : value >= 2 ? core_theme.AC.warn : core_theme.AC.ok;
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts))),
        Container(
          width: 28,
          height: 22,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Center(
            child: Text('$value',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmap() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        children: [
          Text('خريطة المخاطر (5×5 Heatmap)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          Text('الأثر → (الأعلى أسوأ) × الاحتمال ↑',
              style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 16),
          // 5x5 grid
          for (var likelihood = 5; likelihood >= 1; likelihood--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text('احتمال $likelihood',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  for (var impact = 1; impact <= 5; impact++)
                    Expanded(
                      child: _heatmapCell(likelihood, impact),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 50),
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: Center(
                    child: Text('أثر $i',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            children: [
              _legend(core_theme.AC.err, 'حرج (≥12)'),
              _legend(core_theme.AC.warn, 'عالٍ (8-11)'),
              _legend(core_theme.AC.warn, 'متوسط (4-7)'),
              _legend(core_theme.AC.ok, 'منخفض (<4)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heatmapCell(int likelihood, int impact) {
    final score = likelihood * impact;
    final risksInCell = _risks.where((r) => r.likelihood == likelihood && r.impact == impact).toList();
    final cellColor = score >= 12
        ? core_theme.AC.err
        : score >= 8
            ? core_theme.AC.warn
            : score >= 4
                ? core_theme.AC.warn
                : core_theme.AC.ok;
    return Container(
      height: 60,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cellColor.withValues(alpha: 0.3 + (score / 25 * 0.5)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cellColor, width: risksInCell.isNotEmpty ? 2 : 0),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$score', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            if (risksInCell.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text('${risksInCell.length}',
                    style: TextStyle(fontSize: 10, color: cellColor, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Color _catColor(String c) {
    switch (c) {
      case 'financial':
        return core_theme.AC.gold;
      case 'operational':
        return core_theme.AC.info;
      case 'strategic':
        return core_theme.AC.purple;
      case 'regulatory':
        return core_theme.AC.ok;
      case 'cyber':
        return core_theme.AC.err;
      case 'fraud':
        return Colors.deepOrange;
      default:
        return core_theme.AC.td;
    }
  }

  String _catLabel(String c) {
    switch (c) {
      case 'financial':
        return 'مالية';
      case 'operational':
        return 'تشغيلية';
      case 'strategic':
        return 'استراتيجية';
      case 'regulatory':
        return 'تنظيمية';
      case 'cyber':
        return 'سيبرانية';
      case 'fraud':
        return 'احتيال';
      default:
        return c;
    }
  }

  Color _strategyColor(String s) {
    switch (s) {
      case 'treating':
        return core_theme.AC.info;
      case 'accepting':
        return core_theme.AC.ok;
      case 'monitoring':
        return core_theme.AC.warn;
      case 'transferring':
        return core_theme.AC.purple;
      default:
        return core_theme.AC.td;
    }
  }

  String _strategyLabel(String s) {
    switch (s) {
      case 'treating':
        return 'معالجة';
      case 'accepting':
        return 'قبول';
      case 'monitoring':
        return 'متابعة';
      case 'transferring':
        return 'نقل';
      default:
        return s;
    }
  }
}

class _Risk {
  final String id;
  final String title;
  final String category;
  final int likelihood;
  final int impact;
  final String strategy;
  final String treatment;
  final String owner;
  final Color color;
  const _Risk(this.id, this.title, this.category, this.likelihood, this.impact, this.strategy, this.treatment, this.owner, this.color);
}

class _FOpt {
  final String id;
  final String label;
  const _FOpt(this.id, this.label);
}
