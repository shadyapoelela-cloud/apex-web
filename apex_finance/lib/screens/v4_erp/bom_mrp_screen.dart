/// Wave 152 — BOM (Bill of Materials) + MRP (Material Requirements Planning).
///
/// Odoo Manufacturing / SAP PP / Fishbowl-class BOM/MRP platform.
/// Features:
///   - Multi-level BOM tree (parent → sub-assemblies → raw materials)
///   - MRP explosion: forecast demand → material requirements
///   - Lead-time tracking per component
///   - Work center capacity planning
///   - Component substitution rules
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class BomMrpScreen extends StatefulWidget {
  const BomMrpScreen({super.key});

  @override
  State<BomMrpScreen> createState() => _BomMrpScreenState();
}

class _BomMrpScreenState extends State<BomMrpScreen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  int _tab = 0;
  String _selectedProduct = 'أريكة ثلاثية فاخرة';

  static const _boms = <_BomNode>[
    _BomNode(code: 'FG-100', name: 'أريكة ثلاثية فاخرة', qty: 1, unit: 'قطعة', level: 0, leadTime: 14, available: 12),
    _BomNode(code: 'SA-201', name: 'هيكل خشبي', qty: 1, unit: 'مجمّعة', level: 1, leadTime: 7, available: 28),
    _BomNode(code: 'RM-301', name: 'خشب زان معالج', qty: 6, unit: 'متر', level: 2, leadTime: 5, available: 340),
    _BomNode(code: 'RM-302', name: 'براغي 10 سم', qty: 32, unit: 'قطعة', level: 2, leadTime: 2, available: 1200),
    _BomNode(code: 'SA-202', name: 'وسادات إسفنجية', qty: 6, unit: 'قطعة', level: 1, leadTime: 5, available: 45),
    _BomNode(code: 'RM-303', name: 'إسفنج عالي الكثافة', qty: 12, unit: 'كجم', level: 2, leadTime: 3, available: 180),
    _BomNode(code: 'SA-203', name: 'تنجيد خارجي', qty: 1, unit: 'مجمّعة', level: 1, leadTime: 3, available: 20),
    _BomNode(code: 'RM-304', name: 'قماش مخمل', qty: 8, unit: 'متر', level: 2, leadTime: 4, available: 95),
    _BomNode(code: 'RM-305', name: 'خيوط تنجيد', qty: 2, unit: 'بكرة', level: 2, leadTime: 1, available: 48),
  ];

  static const _mrpDemand = <_DemandLine>[
    _DemandLine(product: 'أريكة ثلاثية فاخرة', required: 20, available: 12, toMake: 8, by: '2026-05-15', priority: _Priority.high),
    _DemandLine(product: 'طاولة طعام 6 مقاعد', required: 15, available: 10, toMake: 5, by: '2026-05-20', priority: _Priority.medium),
    _DemandLine(product: 'خزانة ملابس 4 أبواب', required: 12, available: 4, toMake: 8, by: '2026-05-12', priority: _Priority.high),
    _DemandLine(product: 'كرسي مكتب تنفيذي', required: 30, available: 22, toMake: 8, by: '2026-05-25', priority: _Priority.low),
    _DemandLine(product: 'طاولة قهوة رخامية', required: 10, available: 5, toMake: 5, by: '2026-05-18', priority: _Priority.medium),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.account_tree, color: _gold),
                  const SizedBox(width: 8),
                  Text('قائمة المواد BOM / تخطيط المواد MRP',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow),
                    label: Text('تشغيل MRP'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: _gold),
                    icon: const Icon(Icons.add),
                    label: Text('منتج جديد'),
                  ),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.inventory, label: 'BOMs نشطة', value: '142', color: core_theme.AC.info)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.warning, label: 'مواد تنقص', value: '8', color: core_theme.AC.err)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.local_shipping, label: 'طلبيات معلقة', value: '14', color: core_theme.AC.warn)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.factory, label: 'استغلال المحطات', value: '84%', color: core_theme.AC.gold)),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _Tab(label: 'شجرة BOM', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  _Tab(label: 'خطة MRP', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _tab == 0 ? _buildBomView() : _buildMrpView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBomView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.search, color: core_theme.AC.ts),
              const SizedBox(width: 8),
              Expanded(
                child: Text('المنتج: $_selectedProduct',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: Text('تغيير'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _boms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final b = _boms[i];
              final isParent = b.level == 0;
              final shortage = b.available < b.qty * 10;
              return Container(
                color: isParent ? _gold.withValues(alpha: 0.05) : null,
                padding: EdgeInsetsDirectional.only(
                  start: 16 + (b.level * 32.0),
                  end: 16,
                  top: 10,
                  bottom: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      isParent ? Icons.inventory_2 : (b.level == 1 ? Icons.construction : Icons.category),
                      size: 18,
                      color: isParent ? _gold : core_theme.AC.ts,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              style: TextStyle(
                                  fontSize: isParent ? 14 : 13,
                                  fontWeight: isParent ? FontWeight.w800 : FontWeight.w600)),
                          Text(b.code, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('${b.qty} ${b.unit}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('${b.leadTime} يوم',
                          style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(
                      width: 100,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shortage ? core_theme.AC.err.withValues(alpha: 0.1) : core_theme.AC.ok.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('متوفر: ${b.available}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: shortage ? core_theme.AC.err : core_theme.AC.ok),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMrpView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _mrpDemand.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final d = _mrpDemand[i];
        final (color, label) = switch (d.priority) {
          _Priority.high => (core_theme.AC.err, 'عاجل'),
          _Priority.medium => (core_theme.AC.warn, 'متوسط'),
          _Priority.low => (core_theme.AC.ok, 'منخفض'),
        };
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory_2, color: _gold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.product,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('مطلوب بحلول: ${d.by}',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    ],
                  ),
                ),
                _MRPCol(label: 'مطلوب', value: '${d.required}', color: core_theme.AC.tp),
                const SizedBox(width: 16),
                _MRPCol(label: 'متوفر', value: '${d.available}', color: core_theme.AC.info),
                const SizedBox(width: 16),
                _MRPCol(label: 'للتصنيع', value: '${d.toMake}', color: _gold),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(backgroundColor: _navy, padding: const EdgeInsets.symmetric(horizontal: 10)),
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: Text('إنشاء أمر إنتاج', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _Priority { high, medium, low }

class _BomNode {
  final String code;
  final String name;
  final int qty;
  final String unit;
  final int level;
  final int leadTime;
  final int available;
  const _BomNode({
    required this.code,
    required this.name,
    required this.qty,
    required this.unit,
    required this.level,
    required this.leadTime,
    required this.available,
  });
}

class _DemandLine {
  final String product;
  final int required;
  final int available;
  final int toMake;
  final String by;
  final _Priority priority;
  const _DemandLine({
    required this.product,
    required this.required,
    required this.available,
    required this.toMake,
    required this.by,
    required this.priority,
  });
}

class _MRPCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MRPCol({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
                Text(value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? core_theme.AC.gold : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? core_theme.AC.gold : core_theme.AC.ts,
          ),
        ),
      ),
    );
  }
}
