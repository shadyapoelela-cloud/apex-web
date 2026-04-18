/// APEX Wave 90 — Enterprise Risk Register.
/// Route: /app/compliance/regulatory/risk-register
///
/// ERM per COSO — risk heatmap, treatment plans, KRIs.
library;

import 'package:flutter/material.dart';

class RiskRegisterScreen extends StatefulWidget {
  const RiskRegisterScreen({super.key});
  @override
  State<RiskRegisterScreen> createState() => _RiskRegisterScreenState();
}

class _RiskRegisterScreenState extends State<RiskRegisterScreen> {
  String _viewMode = 'list';
  String _categoryFilter = 'all';

  final _risks = const [
    _Risk('RSK-001', 'تعرّض لأسعار العملات الأجنبية', 'financial', 4, 4, 'treating', 'تحوّط 65% + مراقبة أسبوعية', 'أحمد العتيبي', Colors.red),
    _Risk('RSK-002', 'هجوم سيبراني يستهدف بيانات العملاء', 'cyber', 3, 5, 'treating', 'SOC 24/7 + Penetration Testing ربعي + Cyber Insurance', 'راشد العنزي', Colors.red),
    _Risk('RSK-003', 'تغيّر تنظيمي في أنظمة ZATCA', 'regulatory', 3, 3, 'accepting', 'فريق امتثال متابع للتحديثات + مستشار ضريبي', 'محمد القحطاني', Colors.orange),
    _Risk('RSK-004', 'تركّز في عميل رئيسي واحد', 'strategic', 3, 4, 'treating', 'خطة تنويع العملاء Q1-Q4 — هدف أقل من 15%', 'سارة الدوسري', Colors.orange),
    _Risk('RSK-005', 'فقدان موظف مفتاح', 'operational', 3, 3, 'treating', 'خطط التعاقب، شراكات مع 3 بدائل، مكافآت احتفاظ', 'لينا البكري', Colors.orange),
    _Risk('RSK-006', 'انقطاع خدمة نظام SAP', 'operational', 2, 4, 'treating', 'DR Site في AWS + RTO 4 ساعات + Hot Standby', 'راشد العنزي', Colors.orange),
    _Risk('RSK-007', 'عدم الالتزام بشروط العقود مع العملاء', 'operational', 2, 3, 'treating', 'SLA Monitoring + Penalty Clauses', 'محمد القحطاني', Colors.amber),
    _Risk('RSK-008', 'تأخر المدفوعات من العملاء > 90 يوم', 'financial', 3, 3, 'treating', 'Credit Scoring + Automated Follow-up + Collection Agency', 'نورة الغامدي', Colors.amber),
    _Risk('RSK-009', 'تغيّر في السياسة الضريبية (VAT/CT)', 'regulatory', 2, 3, 'monitoring', 'متابعة بيانات ZATCA + تحديث السياسات', 'راشد العنزي', Colors.amber),
    _Risk('RSK-010', 'فقدان بيانات حساسة بسبب خطأ بشري', 'operational', 2, 4, 'treating', 'DLP + Training + Access Controls', 'راشد العنزي', Colors.orange),
    _Risk('RSK-011', 'احتيال مالي داخلي', 'fraud', 1, 5, 'treating', 'SoD + Automated Controls + Whistleblower Hotline', 'محمد القحطاني', Colors.orange),
    _Risk('RSK-012', 'تقلّب أسعار المواد الخام', 'financial', 3, 2, 'accepting', 'عقود طويلة الأجل + مخزون استراتيجي', 'فهد الشمري', Colors.amber),
    _Risk('RSK-013', 'انخفاض رضا العملاء وفقدانهم', 'strategic', 2, 3, 'treating', 'NPS شهري + فريق Customer Success مخصّص', 'سارة الدوسري', Colors.amber),
    _Risk('RSK-014', 'عدم الالتزام بمعايير الأمن السيبراني NCA', 'regulatory', 2, 4, 'treating', 'برنامج امتثال ECC كامل + مراجعة سنوية', 'راشد العنزي', Colors.orange),
    _Risk('RSK-015', 'كارثة طبيعية (زلزال/فيضان)', 'operational', 1, 4, 'accepting', 'تأمين شامل + DR Site', 'لينا البكري', Colors.green),
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
            _kpi('مخاطر مسجّلة', '${_risks.length}', Colors.blue, Icons.security),
            _kpi('حرجة', '$critical', Colors.red, Icons.error),
            _kpi('عالية', '$high', Colors.orange, Icons.warning),
            _kpi('متوسطة', '$medium', Colors.amber, Icons.info),
            _kpi('منخفضة', '$low', Colors.green, Icons.check_circle),
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
      child: const Row(
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
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
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
          color: selected ? Colors.red.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.red.shade700 : Colors.black26),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.black54),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87)),
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
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
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
    final scoreColor = score >= 12 ? Colors.red : score >= 8 ? Colors.orange : score >= 4 ? Colors.amber : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withOpacity(0.3), width: 1.5),
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
                      const Text('خطر', style: TextStyle(color: Colors.white70, fontSize: 9)),
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
                        Text(r.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _catColor(r.category).withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(_catLabel(r.category),
                              style: TextStyle(fontSize: 10, color: _catColor(r.category), fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _strategyColor(r.strategy).withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(_strategyLabel(r.strategy),
                              style: TextStyle(fontSize: 10, color: _strategyColor(r.strategy), fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 11, color: Colors.black54),
                        const SizedBox(width: 3),
                        Text('صاحب المخاطرة: ${r.owner}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                const Text('خطة المعالجة: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blue)),
                Expanded(child: Text(r.treatment, style: const TextStyle(fontSize: 11, height: 1.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, int value) {
    final color = value >= 4 ? Colors.red : value >= 3 ? Colors.orange : value >= 2 ? Colors.amber : Colors.green;
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54))),
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
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const Text('خريطة المخاطر (5×5 Heatmap)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const Text('الأثر → (الأعلى أسوأ) × الاحتمال ↑',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
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
              _legend(Colors.red, 'حرج (≥12)'),
              _legend(Colors.orange, 'عالٍ (8-11)'),
              _legend(Colors.amber, 'متوسط (4-7)'),
              _legend(Colors.green, 'منخفض (<4)'),
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
        ? Colors.red
        : score >= 8
            ? Colors.orange
            : score >= 4
                ? Colors.amber
                : Colors.green;
    return Container(
      height: 60,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cellColor.withOpacity(0.3 + (score / 25 * 0.5)),
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
        return const Color(0xFFD4AF37);
      case 'operational':
        return Colors.blue;
      case 'strategic':
        return Colors.purple;
      case 'regulatory':
        return Colors.green;
      case 'cyber':
        return Colors.red;
      case 'fraud':
        return Colors.deepOrange;
      default:
        return Colors.grey;
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
        return Colors.blue;
      case 'accepting':
        return Colors.green;
      case 'monitoring':
        return Colors.amber;
      case 'transferring':
        return Colors.purple;
      default:
        return Colors.grey;
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
