/// APEX Wave 46 — Manufacturing & BOM.
/// Route: /app/erp/operations/manufacturing
///
/// Bill of Materials, Production Orders, Work Centers.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ManufacturingScreen extends StatefulWidget {
  const ManufacturingScreen({super.key});
  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _selectedBom = 'BOM-001';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildStatsRow(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 16), text: 'قائمة المواد (BOM)'),
            Tab(icon: Icon(Icons.construction, size: 16), text: 'أوامر الإنتاج'),
            Tab(icon: Icon(Icons.factory, size: 16), text: 'مراكز العمل'),
            Tab(icon: Icon(Icons.checklist, size: 16), text: 'مراقبة الجودة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildBomTab(),
              _buildOrdersTab(),
              _buildWorkCentersTab(),
              _buildQualityTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF78909C)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.precision_manufacturing, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التصنيع',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('هياكل مواد متعددة المستويات، أوامر إنتاج، وجدولة ذكية لمراكز العمل',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _stat('أوامر مفتوحة', '12', core_theme.AC.info, Icons.pending_actions),
          _stat('قيد التنفيذ', '7', core_theme.AC.warn, Icons.sync),
          _stat('مكتملة هذا الشهر', '34', core_theme.AC.ok, Icons.check_circle),
          _stat('كفاءة المصنع', '87%', core_theme.AC.gold, Icons.speed),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBomTab() {
    final boms = const [
      _Bom('BOM-001', 'مشروب غازي 330مل', 4, 2.15, 'نشط'),
      _Bom('BOM-002', 'عصير فواكه 250مل', 5, 1.85, 'نشط'),
      _Bom('BOM-003', 'وجبة سريعة — برجر كلاسيكي', 8, 7.40, 'نشط'),
      _Bom('BOM-004', 'عبوة مياه 500مل', 3, 0.65, 'نشط'),
    ];

    final components = const [
      _BomLine('علبة ألمنيوم 330مل', 'قطعة', 1, 0.65),
      _BomLine('مكثّف مشروب', 'لتر', 0.022, 0.48),
      _BomLine('سكر نقي', 'كجم', 0.035, 0.12),
      _BomLine('ثاني أكسيد الكربون', 'جرام', 4.5, 0.18),
      _BomLine('ملصق تعريفي', 'قطعة', 1, 0.12),
      _BomLine('كرتون تعبئة (×24)', 'قطعة', 0.042, 0.35),
      _BomLine('تكلفة العمالة المباشرة', 'دقيقة', 0.8, 0.25),
    ];

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Container(
            margin: const EdgeInsets.only(right: 10, bottom: 20, left: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: core_theme.AC.bdr),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: core_theme.AC.navy3,
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: core_theme.AC.gold, size: 16),
                      SizedBox(width: 6),
                      Text('قوائم المواد المسجّلة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: boms.length,
                    itemBuilder: (ctx, i) {
                      final b = boms[i];
                      final selected = b.code == _selectedBom;
                      return InkWell(
                        onTap: () => setState(() => _selectedBom = b.code),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? core_theme.AC.gold.withValues(alpha: 0.12) : null,
                            border: Border(
                              bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5)),
                              right: BorderSide(color: selected ? core_theme.AC.gold : Colors.transparent, width: 3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(b.code, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: core_theme.AC.ok.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(b.status, style: TextStyle(fontSize: 10, color: core_theme.AC.ok, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(b.product, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.widgets, size: 12, color: core_theme.AC.ts),
                                  const SizedBox(width: 4),
                                  Text('${b.componentCount} مكوّن', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                                  const Spacer(),
                                  Text('${b.cost.toStringAsFixed(2)} ر.س/وحدة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 10, bottom: 20, right: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: core_theme.AC.bdr),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  color: core_theme.AC.navy3,
                  child: Row(
                    children: [
                      Icon(Icons.account_tree, color: core_theme.AC.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مكوّنات $_selectedBom', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            Text('الكميات لكل وحدة إنتاج واحدة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.content_copy, size: 14),
                        label: Text('نسخ'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.play_arrow, size: 14),
                        label: Text('أمر إنتاج'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: core_theme.AC.gold,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: core_theme.AC.navy3,
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('المكوّن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('الوحدة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('التكلفة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: components.length,
                    itemBuilder: (ctx, i) {
                      final c = components[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(c.name, style: const TextStyle(fontSize: 12))),
                            Expanded(child: Text(c.unit, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                            Expanded(child: Text(c.qty.toStringAsFixed(3), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            Expanded(
                              child: Text('${c.cost.toStringAsFixed(2)} ر.س',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: core_theme.AC.navy3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('التكلفة الكلية للوحدة', style: TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                        '${components.fold(0.0, (s, c) => s + c.cost).toStringAsFixed(2)} ر.س',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    final orders = const [
      _Order('MO-2026-0142', 'مشروب غازي 330مل', 5000, 3200, '2026-04-28', 'قيد التنفيذ'),
      _Order('MO-2026-0141', 'عصير فواكه 250مل', 3000, 3000, '2026-04-27', 'مكتمل'),
      _Order('MO-2026-0143', 'وجبة سريعة — برجر كلاسيكي', 1200, 450, '2026-04-29', 'قيد التنفيذ'),
      _Order('MO-2026-0144', 'عبوة مياه 500مل', 10000, 0, '2026-04-30', 'معلّق'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final o = orders[i];
        final progress = o.planned > 0 ? o.produced / o.planned : 0.0;
        final statusColor = o.status == 'مكتمل'
            ? core_theme.AC.ok
            : o.status == 'قيد التنفيذ'
                ? core_theme.AC.warn
                : core_theme.AC.td;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(o.code, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(o.product, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(o.status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${o.produced} / ${o.planned} وحدة', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                  Text('(${(progress * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor)),
                  const Spacer(),
                  Text('الموعد: ${o.deadline}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: core_theme.AC.bdr,
                valueColor: AlwaysStoppedAnimation(statusColor),
                minHeight: 6,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkCentersTab() {
    final centers = const [
      _WC('WC-001', 'خط التعبئة 1', 92, 86, 'عمل', 'مشرف: خالد العتيبي'),
      _WC('WC-002', 'خط التعبئة 2', 88, 74, 'عمل', 'مشرف: فهد القحطاني'),
      _WC('WC-003', 'قسم التغليف', 95, 91, 'عمل', 'مشرف: محمد الدوسري'),
      _WC('WC-004', 'مختبر الجودة', 78, 65, 'صيانة', 'قيد الصيانة الوقائية'),
      _WC('WC-005', 'خط التعقيم', 90, 82, 'عمل', 'مشرف: سعد الغامدي'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: centers.length,
      itemBuilder: (ctx, i) {
        final w = centers[i];
        final statusColor = w.status == 'عمل' ? core_theme.AC.ok : core_theme.AC.warn;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.factory, color: statusColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(w.code, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text(w.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text(w.supervisor, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  ],
                ),
              ),
              _kpiPill('التوفر', '${w.availability}%', core_theme.AC.info),
              const SizedBox(width: 6),
              _kpiPill('الكفاءة', '${w.efficiency}%', core_theme.AC.gold),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(w.status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildQualityTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            _qcStat('نسبة الجودة', '97.3%', core_theme.AC.ok),
            _qcStat('عدد العينات', '284', core_theme.AC.info),
            _qcStat('عينات مرفوضة', '8', core_theme.AC.err),
            _qcStat('FPY', '94.5%', core_theme.AC.gold),
          ],
        ),
        const SizedBox(height: 20),
        Text('نتائج الفحص الأخيرة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _qcRow('MO-2026-0141', 'عصير فواكه 250مل', 'مطابق', core_theme.AC.ok, '2026-04-27 16:30'),
        _qcRow('MO-2026-0142', 'مشروب غازي 330مل', 'مطابق مع ملاحظات', core_theme.AC.warn, '2026-04-28 09:15'),
        _qcRow('MO-2026-0139', 'عبوة مياه 500مل', 'مطابق', core_theme.AC.ok, '2026-04-26 14:20'),
        _qcRow('MO-2026-0138', 'وجبة سريعة', 'غير مطابق — صدّرت', core_theme.AC.err, '2026-04-25 11:00'),
      ],
    );
  }

  Widget _qcStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _qcRow(String order, String product, String result, Color color, String timestamp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Row(
        children: [
          Icon(Icons.science, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(order, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(product, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(timestamp, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(result, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Bom {
  final String code;
  final String product;
  final int componentCount;
  final double cost;
  final String status;
  const _Bom(this.code, this.product, this.componentCount, this.cost, this.status);
}

class _BomLine {
  final String name;
  final String unit;
  final double qty;
  final double cost;
  const _BomLine(this.name, this.unit, this.qty, this.cost);
}

class _Order {
  final String code;
  final String product;
  final int planned;
  final int produced;
  final String deadline;
  final String status;
  const _Order(this.code, this.product, this.planned, this.produced, this.deadline, this.status);
}

class _WC {
  final String code;
  final String name;
  final int availability;
  final int efficiency;
  final String status;
  final String supervisor;
  const _WC(this.code, this.name, this.availability, this.efficiency, this.status, this.supervisor);
}
