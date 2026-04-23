/// V5.2 — Accounting Dimensions using TreeView pattern.
///
/// Multi-dimensional analysis tags applied to journal entries for cross-cutting
/// reporting: Region × Product × Channel × Project, etc.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class DimensionsV52Screen extends StatefulWidget {
  const DimensionsV52Screen({super.key});

  @override
  State<DimensionsV52Screen> createState() => _DimensionsV52ScreenState();
}

class _DimensionsV52ScreenState extends State<DimensionsV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _selectedDim = 'region';
  final Set<String> _expanded = {'region', 'product', 'channel', 'project', 'region.ksa', 'region.uae', 'product.food', 'product.electronics'};

  late final Map<String, _Dim> _dims;

  @override
  void initState() {
    super.initState();
    _dims = _buildDims();
  }

  Map<String, _Dim> _buildDims() {
    return {
      'region': _Dim('region', 'المنطقة الجغرافية', 'Geographic Region', Icons.public, core_theme.AC.info, 140, [
        _Dim('region.ksa', '🇸🇦 المملكة العربية السعودية', null, Icons.flag, core_theme.AC.ok, 68, [
          _Dim('region.ksa.riyadh', 'الرياض', null, Icons.location_city, core_theme.AC.ok, 32, []),
          _Dim('region.ksa.jeddah', 'جدة', null, Icons.location_city, core_theme.AC.ok, 22, []),
          _Dim('region.ksa.dammam', 'الدمام', null, Icons.location_city, core_theme.AC.ok, 10, []),
          _Dim('region.ksa.other', 'أخرى', null, Icons.location_city, core_theme.AC.td, 4, []),
        ]),
        _Dim('region.uae', '🇦🇪 الإمارات العربية المتحدة', null, Icons.flag, core_theme.AC.info, 38, [
          _Dim('region.uae.dubai', 'دبي', null, Icons.location_city, core_theme.AC.info, 24, []),
          _Dim('region.uae.abu-dhabi', 'أبوظبي', null, Icons.location_city, core_theme.AC.info, 14, []),
        ]),
        _Dim('region.egypt', '🇪🇬 مصر', null, Icons.flag, core_theme.AC.warn, 18, []),
        _Dim('region.kuwait', '🇰🇼 الكويت', null, Icons.flag, core_theme.AC.purple, 8, []),
        _Dim('region.others', '🌍 أخرى', null, Icons.public, core_theme.AC.td, 8, []),
      ]),
      'product': _Dim('product', 'خط المنتج', 'Product Line', Icons.category, core_theme.AC.purple, 240, [
        _Dim('product.food', 'المواد الغذائية', null, Icons.restaurant, _gold, 95, [
          _Dim('product.food.fresh', 'طازج', null, Icons.eco, core_theme.AC.ok, 42, []),
          _Dim('product.food.frozen', 'مُجمّد', null, Icons.ac_unit, core_theme.AC.info, 28, []),
          _Dim('product.food.packaged', 'مُعبّأ', null, Icons.inventory_2, _gold, 25, []),
        ]),
        _Dim('product.electronics', 'الإلكترونيات', null, Icons.devices, core_theme.AC.info, 78, [
          _Dim('product.electronics.mobile', 'جوالات', null, Icons.phone_iphone, core_theme.AC.info, 34, []),
          _Dim('product.electronics.computers', 'حواسيب', null, Icons.computer, core_theme.AC.info, 26, []),
          _Dim('product.electronics.accessories', 'ملحقات', null, Icons.headphones, core_theme.AC.purple, 18, []),
        ]),
        _Dim('product.clothing', 'الملابس', null, Icons.checkroom, core_theme.AC.err, 42, []),
        _Dim('product.services', 'الخدمات', null, Icons.room_service, core_theme.AC.ok, 25, []),
      ]),
      'channel': _Dim('channel', 'قناة البيع', 'Sales Channel', Icons.sync_alt, core_theme.AC.info, 8, [
        _Dim('channel.retail', 'البيع المباشر', null, Icons.store, _gold, 180, []),
        _Dim('channel.wholesale', 'الجملة', null, Icons.warehouse, core_theme.AC.info, 42, []),
        _Dim('channel.online', 'المتجر الإلكتروني', null, Icons.laptop, core_theme.AC.purple, 28, []),
        _Dim('channel.b2b', 'B2B', null, Icons.business, _navy, 16, []),
      ]),
      'project': _Dim('project', 'المشروع', 'Project', Icons.work, core_theme.AC.warn, 38, [
        _Dim('project.erp-impl', 'تطبيق ERP', null, Icons.computer, _gold, 18, []),
        _Dim('project.expansion', 'التوسّع الجغرافي', null, Icons.trending_up, core_theme.AC.ok, 12, []),
        _Dim('project.branding', 'تجديد العلامة', null, Icons.style, core_theme.AC.purple, 8, []),
      ]),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(children: [
                _dimensionList(),
                const VerticalDivider(width: 1),
                Expanded(child: _dimensionTree()),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.view_in_ar, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الأبعاد المحاسبية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('Multi-dimensional analysis tags — التحليل متعدد الأبعاد', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.import_export, size: 16), label: Text('استيراد من Excel')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.add, size: 16),
          label: Text('بُعد جديد'),
        ),
      ]),
    );
  }

  Widget _dimensionList() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(14), color: _navy.withValues(alpha: 0.04), child: Row(children: [
          Icon(Icons.list_alt, color: _navy, size: 16),
          const SizedBox(width: 8),
          Text('الأبعاد المُعرّفة (${_dims.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        ])),
        const Divider(height: 1),
        Expanded(child: ListView(children: _dims.values.map((d) {
          final active = d.id == _selectedDim;
          return InkWell(
            onTap: () => setState(() => _selectedDim = d.id),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active ? d.color.withValues(alpha: 0.06) : null,
                border: BorderDirectional(end: BorderSide(color: active ? d.color : Colors.transparent, width: 3)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: d.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(d.icon, color: d.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? _navy : core_theme.AC.tp)),
                  Text('${_countLeaves(d)} قيمة · ${d.postingsCount} قيد', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                ])),
                if (active) Icon(Icons.chevron_left, size: 16, color: d.color),
              ]),
            ),
          );
        }).toList())),
      ]),
    );
  }

  int _countLeaves(_Dim d) {
    if (d.children.isEmpty) return 1;
    return d.children.fold<int>(0, (s, c) => s + _countLeaves(c));
  }

  Widget _dimensionTree() {
    final d = _dims[_selectedDim];
    if (d == null) return Center(child: Text('اختر بُعداً', style: TextStyle(color: core_theme.AC.ts)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: core_theme.AC.bdr))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: d.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(d.icon, color: d.color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.labelAr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
            if (d.labelEn != null) Text(d.labelEn!, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          _statBadge('${_countLeaves(d)} قيمة', d.color),
          const SizedBox(width: 8),
          _statBadge('${d.postingsCount} قيد', core_theme.AC.ts),
        ]),
      ),
      Expanded(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final child in d.children) ..._renderNode(child, 0),
            ],
          ),
        ),
      ),
    ]);
  }

  List<Widget> _renderNode(_Dim node, int depth) {
    final isExpanded = _expanded.contains(node.id);
    final hasChildren = node.children.isNotEmpty;
    return [
      InkWell(
        onTap: hasChildren
            ? () => setState(() {
                  if (isExpanded) {
                    _expanded.remove(node.id);
                  } else {
                    _expanded.add(node.id);
                  }
                })
            : null,
        child: Container(
          padding: EdgeInsetsDirectional.only(start: 12 + depth * 24, end: 12, top: 10, bottom: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.navy3))),
          child: Row(children: [
            SizedBox(
              width: 20,
              child: hasChildren
                  ? Icon(isExpanded ? Icons.expand_more : Icons.chevron_left, size: 18, color: core_theme.AC.ts)
                  : Icon(Icons.fiber_manual_record, size: 6, color: core_theme.AC.td),
            ),
            const SizedBox(width: 6),
            Icon(node.icon, size: 16, color: node.color),
            const SizedBox(width: 10),
            Expanded(child: Text(node.labelAr, style: TextStyle(fontSize: 13, fontWeight: hasChildren ? FontWeight.w800 : FontWeight.w500))),
            const SizedBox(width: 8),
            Text('${node.postingsCount} قيد', style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.edit, size: 14), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 6),
            IconButton(icon: Icon(Icons.add, size: 14, color: core_theme.AC.ok), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      ),
      if (isExpanded)
        for (final child in node.children) ..._renderNode(child, depth + 1),
    ];
  }

  Widget _statBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _Dim {
  final String id, labelAr;
  final String? labelEn;
  final IconData icon;
  final Color color;
  final int postingsCount;
  final List<_Dim> children;
  const _Dim(this.id, this.labelAr, this.labelEn, this.icon, this.color, this.postingsCount, this.children);
}

