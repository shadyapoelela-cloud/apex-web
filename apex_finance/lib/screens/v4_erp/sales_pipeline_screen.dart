/// APEX Wave 60 — Sales Pipeline (Kanban).
/// Route: /app/erp/operations/pipeline
///
/// Drag-friendly deals pipeline with forecast analytics.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class SalesPipelineScreen extends StatefulWidget {
  const SalesPipelineScreen({super.key});
  @override
  State<SalesPipelineScreen> createState() => _SalesPipelineScreenState();
}

class _SalesPipelineScreenState extends State<SalesPipelineScreen> {
  final _stages = <_Stage>[
    _Stage('lead', 'عملاء محتملون', 10, const Color(0xFF78909C)),
    _Stage('qualified', 'مؤهّل', 25, const Color(0xFF42A5F5)),
    _Stage('proposal', 'عرض مقدَّم', 50, const Color(0xFFAB47BC)),
    _Stage('negotiation', 'تفاوض', 75, const Color(0xFFFF7043)),
    _Stage('won', 'مربوح', 100, const Color(0xFF66BB6A)),
  ];

  final _deals = <_Deal>[
    _Deal('DL-2026-0042', 'مشروع SAP Integration — أرامكو', 1800000, 'aramco', 'proposal', '2026-05-28', 0.6, 'محمد القحطاني'),
    _Deal('DL-2026-0041', 'تدقيق سنوي — NEOM', 2400000, 'neom', 'negotiation', '2026-04-30', 0.85, 'سارة الدوسري'),
    _Deal('DL-2026-0040', 'عقد صيانة تقنية — STC', 680000, 'stc', 'proposal', '2026-05-15', 0.55, 'فهد الشمري'),
    _Deal('DL-2026-0039', 'استشارات مالية — دبي القابضة', 420000, 'dubai', 'qualified', '2026-06-10', 0.40, 'نورة الغامدي'),
    _Deal('DL-2026-0038', 'تنفيذ SAP — Saudi Airlines', 3200000, 'airlines', 'lead', '2026-07-01', 0.20, 'محمد القحطاني'),
    _Deal('DL-2026-0037', 'مراجعة محاسبية — مجموعة الحبتور', 185000, 'habtoor', 'won', '2026-04-18', 1.0, 'أحمد العتيبي'),
    _Deal('DL-2026-0036', 'تطوير تطبيق جوال — مصرف الراجحي', 950000, 'rajhi', 'negotiation', '2026-05-05', 0.80, 'لينا البكري'),
    _Deal('DL-2026-0035', 'Smart City IoT — NEOM', 4200000, 'neom', 'qualified', '2026-08-15', 0.30, 'سارة الدوسري'),
    _Deal('DL-2026-0034', 'تحول رقمي — سابك', 5800000, 'sabic', 'lead', '2026-09-20', 0.15, 'محمد القحطاني'),
    _Deal('DL-2026-0033', 'محاسبة سحابية — طلبات', 285000, 'talabat', 'proposal', '2026-05-20', 0.65, 'نورة الغامدي'),
  ];

  _Stage? _getStage(String id) {
    for (final s in _stages) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _deals.fold(0.0, (s, d) => s + d.amount);
    final weightedValue = _deals.fold(0.0, (s, d) => s + d.amount * d.probability);
    final wonValue = _deals.where((d) => d.stage == 'won').fold(0.0, (s, d) => s + d.amount);

    return Column(
      children: [
        _buildHero(totalValue, weightedValue, wonValue),
        Expanded(
          child: Row(
            children: [
              for (final stage in _stages)
                Expanded(child: _buildColumn(stage)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(double total, double weighted, double won) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أنبوب المبيعات',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('10 صفقات · 5 مراحل · توقع قابل للتعديل حسب الاحتمالية',
                          style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('صفقة جديدة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroKpi('إجمالي الأنبوب', _fmtM(total), core_theme.AC.info, Icons.account_balance),
              _heroKpi('القيمة المرجّحة (توقع)', _fmtM(weighted), core_theme.AC.gold, Icons.analytics),
              _heroKpi('مربوح YTD', _fmtM(won), core_theme.AC.ok, Icons.emoji_events),
              _heroKpi('معدل الربح', '34%', core_theme.AC.info, Icons.trending_up),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroKpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(_Stage stage) {
    final deals = _deals.where((d) => d.stage == stage.id).toList();
    final stageValue = deals.fold(0.0, (s, d) => s + d.amount);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: core_theme.AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stage.color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: stage.color.withOpacity(0.3))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(stage.name,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: stage.color)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stage.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${deals.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_fmtM(stageValue),
                    style: TextStyle(fontSize: 11, color: stage.color, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: deals.length,
              itemBuilder: (ctx, i) => _dealCard(deals[i], stage.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dealCard(_Deal d, Color stageColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.bdr),
        boxShadow: [BoxShadow(color: core_theme.AC.bdr.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          Text(d.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: core_theme.AC.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.attach_money, size: 12, color: core_theme.AC.gold),
                Text(_fmtM(d.amount),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: stageColor.withOpacity(0.15),
                child: Text(d.owner.substring(0, 1),
                    style: TextStyle(color: stageColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(d.owner, style: TextStyle(fontSize: 10, color: core_theme.AC.ts))),
              Icon(Icons.calendar_today, size: 10, color: core_theme.AC.td),
              const SizedBox(width: 3),
              Text(d.closeDate.substring(5),
                  style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: d.probability,
                  backgroundColor: core_theme.AC.bdr,
                  valueColor: AlwaysStoppedAnimation(stageColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 4),
              Text('${(d.probability * 100).toInt()}%',
                  style: TextStyle(fontSize: 10, color: stageColor, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M ر.س';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _Stage {
  final String id;
  final String name;
  final int probability;
  final Color color;
  const _Stage(this.id, this.name, this.probability, this.color);
}

class _Deal {
  final String id;
  final String title;
  final double amount;
  final String customer;
  final String stage;
  final String closeDate;
  final double probability;
  final String owner;
  const _Deal(this.id, this.title, this.amount, this.customer, this.stage, this.closeDate, this.probability, this.owner);
}
