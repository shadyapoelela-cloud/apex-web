/// V5.2 — Documents Vault using MultiViewTemplate + Preview.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class DocumentsV52Screen extends StatefulWidget {
  const DocumentsV52Screen({super.key});

  @override
  State<DocumentsV52Screen> createState() => _DocumentsV52ScreenState();
}

class _DocumentsV52ScreenState extends State<DocumentsV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _docs = <_Doc>[
    _Doc('D-2026-142', 'القوائم المالية Q1 2026 — موقّعة.pdf', 'pdf', 2.4, _Cat.statements, 'محمد العمري', '2026-04-19', true),
    _Doc('D-2026-141', 'اتفاقية خدمة مجموعة الخليج.pdf', 'pdf', 1.8, _Cat.contracts, 'سارة علي', '2026-04-17', true),
    _Doc('D-2026-140', 'شهادة الزكاة لعام 2025.pdf', 'pdf', 420, _Cat.tax, 'أحمد محمد', '2026-04-15', true),
    _Doc('D-2026-139', 'شهادة ISO 9001 - 2025-2026.pdf', 'pdf', 340, _Cat.certifications, 'ليلى أحمد', '2026-04-12', true),
    _Doc('D-2026-138', 'تقرير المراجعة السنوي 2025.pdf', 'pdf', 5.8, _Cat.audit, 'EY', '2026-04-10', true),
    _Doc('D-2026-137', 'رسالة المدير التنفيذي للمساهمين.docx', 'docx', 180, _Cat.corporate, 'محمد العمري', '2026-04-08', true),
    _Doc('D-2026-136', 'دراسة جدوى مشروع الإمارات.xlsx', 'xlsx', 2.2, _Cat.projects, 'د. محمد الراجحي', '2026-04-05', false),
    _Doc('D-2026-135', 'محضر اجتماع مجلس الإدارة Q1.pdf', 'pdf', 380, _Cat.corporate, 'سكرتير المجلس', '2026-04-03', true),
    _Doc('D-2026-134', 'الميزانية السنوية 2026.xlsx', 'xlsx', 4.8, _Cat.statements, 'أحمد محمد', '2026-01-15', true),
    _Doc('D-2026-133', 'عقد مقاولات البناء - مجمّع الرياض.pdf', 'pdf', 12.4, _Cat.contracts, 'ليلى الفارس', '2026-01-10', true),
    _Doc('D-2026-132', 'تقرير VAT Q4 2025.pdf', 'pdf', 680, _Cat.tax, 'سارة علي', '2026-01-23', true),
    _Doc('D-2026-131', 'سياسة المصروفات للشركة.docx', 'docx', 420, _Cat.policies, 'ليلى أحمد', '2025-12-01', true),
    _Doc('D-2026-130', 'شهادة GOSI 2025.pdf', 'pdf', 320, _Cat.certifications, 'GOSI', '2025-12-31', true),
    _Doc('D-2026-129', 'محضر اجتماع السنوي للمساهمين.pdf', 'pdf', 1.2, _Cat.corporate, 'المحامي', '2025-11-15', true),
    _Doc('D-2026-128', 'فاتورة INV-2025-1042 — AWS Cloud.pdf', 'pdf', 240, _Cat.invoices, 'AWS', '2025-11-10', true),
    _Doc('D-2026-127', 'الخطة الاستراتيجية 2026-2030.pptx', 'pptx', 8.4, _Cat.corporate, 'الإدارة', '2025-11-01', false),
  ];

  @override
  Widget build(BuildContext context) {
    final totalSize = _docs.fold<double>(0, (s, d) => s + d.sizeMB);
    return MultiViewTemplate(
      titleAr: 'خزانة الوثائق',
      subtitleAr: '${_docs.length} وثيقة · ${totalSize.toStringAsFixed(1)} MB · AI Search + ZATCA signed',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'recent', labelAr: 'الأحدث', icon: Icons.history, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'signed', labelAr: 'موقّعة فقط', icon: Icons.verified, defaultViewMode: ViewMode.list),
        SavedView(id: 'contracts', labelAr: 'عقود', icon: Icons.gavel, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'statements', labelAr: 'قوائم مالية', icon: Icons.insert_chart, color: core_theme.AC.info, count: _cnt(_Cat.statements), active: _filter == 'statements'),
        FilterChipDef(id: 'contracts', labelAr: 'عقود', icon: Icons.gavel, color: core_theme.AC.purple, count: _cnt(_Cat.contracts), active: _filter == 'contracts'),
        FilterChipDef(id: 'tax', labelAr: 'ضرائب', icon: Icons.receipt_long, color: _gold, count: _cnt(_Cat.tax), active: _filter == 'tax'),
        FilterChipDef(id: 'audit', labelAr: 'مراجعة', icon: Icons.fact_check, color: core_theme.AC.purple, count: _cnt(_Cat.audit), active: _filter == 'audit'),
        FilterChipDef(id: 'certifications', labelAr: 'شهادات', icon: Icons.verified, color: core_theme.AC.ok, count: _cnt(_Cat.certifications), active: _filter == 'certifications'),
        FilterChipDef(id: 'corporate', labelAr: 'شؤون الشركة', icon: Icons.business, color: _navy, count: _cnt(_Cat.corporate), active: _filter == 'corporate'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'رفع ملف',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_Cat c) => _docs.where((d) => d.category == c).length;

  Widget _list() {
    final items = _filter.isEmpty ? _docs : _docs.where((d) => d.category.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final d = items[i];
        return Card(
          elevation: 0.5,
          child: ListTile(
            onTap: () {},
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: d.type.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(d.type.icon, color: d.type.color)),
            title: Row(children: [
              Expanded(child: Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (d.signed) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: core_theme.AC.ok.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 10, color: core_theme.AC.ok), SizedBox(width: 2), Text('موقّع', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: core_theme.AC.ok))])),
            ]),
            subtitle: Row(children: [
              Text(d.id, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: d.category.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(d.category.labelAr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: d.category.color))),
              const SizedBox(width: 8),
              Text('${d.sizeMB >= 1 ? d.sizeMB.toStringAsFixed(1) + ' MB' : (d.sizeMB * 1000).toStringAsFixed(0) + ' KB'}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              const SizedBox(width: 8),
              Text('${d.uploader} · ${d.date}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.visibility, size: 18), onPressed: () {}, tooltip: 'معاينة'),
              IconButton(icon: const Icon(Icons.download, size: 18), onPressed: () {}, tooltip: 'تحميل'),
              IconButton(icon: const Icon(Icons.share, size: 18), onPressed: () {}, tooltip: 'مشاركة'),
              IconButton(icon: const Icon(Icons.more_vert, size: 18), onPressed: () {}),
            ]),
          ),
        );
      },
    );
  }

  Widget _kanban() {
    final cats = [_Cat.contracts, _Cat.statements, _Cat.tax, _Cat.audit, _Cat.certifications, _Cat.corporate, _Cat.policies, _Cat.invoices, _Cat.projects];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cats.map((c) {
        final items = _docs.where((d) => d.category == c).toList();
        if (items.isEmpty) return const SizedBox();
        final totalSize = items.fold<double>(0, (s, d) => s + d.sizeMB);
        return Container(
          width: 280,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Icon(c.icon, color: c.color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.color)),
                Text('${totalSize.toStringAsFixed(1)} MB', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.color))),
            ])),
            ...items.take(4).map((d) => Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
              child: Row(children: [
                Icon(d.type.icon, color: d.type.color, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(d.date, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
                ])),
                if (d.signed) Icon(Icons.verified, size: 10, color: core_theme.AC.ok),
              ]),
            )),
            if (items.length > 4)
              Padding(padding: const EdgeInsets.all(8), child: Center(child: Text('+ ${items.length - 4} أخرى', style: TextStyle(fontSize: 11, color: c.color, fontWeight: FontWeight.w700)))),
          ]),
        );
      }).toList()),
    );
  }

  Widget _chart() {
    final byCat = <_Cat, int>{};
    for (final d in _docs) {
      byCat[d.category] = (byCat[d.category] ?? 0) + 1;
    }
    final max = byCat.values.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('توزيع الوثائق حسب الفئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...byCat.entries.map((e) {
          final pct = e.value / max;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            Icon(e.key.icon, color: e.key.color, size: 16),
            const SizedBox(width: 8),
            SizedBox(width: 140, child: Text(e.key.labelAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 22, backgroundColor: core_theme.AC.navy3, color: e.key.color))),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: Text('${e.value} وثيقة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: e.key.color), textAlign: TextAlign.end)),
          ]));
        }),
      ]),
    );
  }
}

enum _Cat { statements, contracts, tax, audit, certifications, corporate, policies, invoices, projects }
enum _FileType { pdf, docx, xlsx, pptx }

extension _CatX on _Cat {
  String get labelAr => switch (this) {
        _Cat.statements => 'قوائم مالية',
        _Cat.contracts => 'عقود',
        _Cat.tax => 'ضرائب',
        _Cat.audit => 'مراجعة',
        _Cat.certifications => 'شهادات',
        _Cat.corporate => 'شؤون الشركة',
        _Cat.policies => 'سياسات',
        _Cat.invoices => 'فواتير',
        _Cat.projects => 'مشاريع',
      };
  Color get color => switch (this) {
        _Cat.statements => core_theme.AC.info,
        _Cat.contracts => core_theme.AC.purple,
        _Cat.tax => core_theme.AC.gold,
        _Cat.audit => core_theme.AC.purple,
        _Cat.certifications => core_theme.AC.ok,
        _Cat.corporate => const Color(0xFF1A237E),
        _Cat.policies => core_theme.AC.info,
        _Cat.invoices => core_theme.AC.warn,
        _Cat.projects => core_theme.AC.err,
      };
  IconData get icon => switch (this) {
        _Cat.statements => Icons.insert_chart,
        _Cat.contracts => Icons.gavel,
        _Cat.tax => Icons.receipt_long,
        _Cat.audit => Icons.fact_check,
        _Cat.certifications => Icons.verified,
        _Cat.corporate => Icons.business,
        _Cat.policies => Icons.policy,
        _Cat.invoices => Icons.receipt,
        _Cat.projects => Icons.work,
      };
}

extension _FTX on String {
  _FileType get type {
    if (this == 'pdf') return _FileType.pdf;
    if (this == 'docx') return _FileType.docx;
    if (this == 'xlsx') return _FileType.xlsx;
    return _FileType.pptx;
  }
}

extension _FileTypeX on _FileType {
  Color get color => switch (this) {
        _FileType.pdf => core_theme.AC.err,
        _FileType.docx => core_theme.AC.info,
        _FileType.xlsx => core_theme.AC.ok,
        _FileType.pptx => core_theme.AC.warn,
      };
  IconData get icon => switch (this) {
        _FileType.pdf => Icons.picture_as_pdf,
        _FileType.docx => Icons.description,
        _FileType.xlsx => Icons.table_chart,
        _FileType.pptx => Icons.slideshow,
      };
}

class _Doc {
  final String id, name, uploader, date;
  final String _typeStr;
  final double sizeMB;
  final _Cat category;
  final bool signed;
  _FileType get type => _typeStr.type;
  const _Doc(this.id, this.name, this._typeStr, this.sizeMB, this.category, this.uploader, this.date, this.signed);
}
