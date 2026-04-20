/// V5.2 — Approval Workflows using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/v5/templates/multi_view_template.dart';

class WorkflowsV52Screen extends StatefulWidget {
  const WorkflowsV52Screen({super.key});

  @override
  State<WorkflowsV52Screen> createState() => _WorkflowsV52ScreenState();
}

class _WorkflowsV52ScreenState extends State<WorkflowsV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _items = <_WF>[
    _WF('WF-142', 'قيد يومية JE-2026-4218 — تسويات', 'JE', 450000, 'سارة علي', '2026-04-19', _St.pending, 2, 4),
    _WF('WF-141', 'أمر شراء PO-2026-124 — معدات', 'PO', 140000, 'أحمد محمد', '2026-04-18', _St.inReview, 1, 3),
    _WF('WF-140', 'مطالبة EC-2026-142 — ضيافة عميل', 'EC', 380, 'عمر حسن', '2026-04-18', _St.approved, 3, 3),
    _WF('WF-139', 'قيد عكسي JE-2026-4215 — تسوية', 'JE', 12800, 'ليلى أحمد', '2026-04-17', _St.pending, 1, 4),
    _WF('WF-138', 'أمر شراء PO-2026-118 — AWS', 'PO', 4200, 'سامي طارق', '2026-04-17', _St.approved, 2, 2),
    _WF('WF-137', 'فاتورة مورد VB-2026-142 — جمع', 'VB', 140000, 'سارة علي', '2026-04-16', _St.rejected, 2, 4),
    _WF('WF-136', 'قيد استحقاق JE-2026-4220', 'JE', 85000, 'أحمد محمد', '2026-04-16', _St.inReview, 2, 4),
    _WF('WF-135', 'طلب صرف ميزانية IO-2026-142', 'IO', 420000, 'دينا حسام', '2026-04-15', _St.approved, 4, 4),
    _WF('WF-134', 'عقد توريد CTR-2026-042', 'CT', 2800000, 'د. محمد', '2026-04-14', _St.inReview, 3, 5),
    _WF('WF-133', 'رفع حد ائتمان لعميل', 'CL', 500000, 'يوسف عمر', '2026-04-12', _St.pending, 1, 3),
  ];

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((i) => i.status == _St.pending).length;
    final totalValue = _items.fold<double>(0, (s, i) => s + i.amount);
    return MultiViewTemplate(
      titleAr: 'مسارات الاعتماد',
      subtitleAr: '${_items.length} طلب · $pending بانتظار الاعتماد · قيمة إجمالية ${(totalValue / 1e6).toStringAsFixed(1)}M ر.س',
      enabledViews: const {ViewMode.kanban, ViewMode.list, ViewMode.chart},
      initialView: ViewMode.kanban,
      savedViews: const [
        SavedView(id: 'mine', labelAr: 'بانتظار اعتمادي', icon: Icons.pending_actions, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'urgent', labelAr: 'عاجل (>500K)', icon: Icons.priority_high, defaultViewMode: ViewMode.list),
        SavedView(id: 'today', labelAr: 'اليوم', icon: Icons.today, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'pending', labelAr: 'بانتظار', color: Colors.orange, count: _cnt(_St.pending), active: _filter == 'pending'),
        FilterChipDef(id: 'inReview', labelAr: 'قيد المراجعة', color: Colors.blue, count: _cnt(_St.inReview), active: _filter == 'inReview'),
        FilterChipDef(id: 'approved', labelAr: 'معتمدة', color: Colors.green, count: _cnt(_St.approved), active: _filter == 'approved'),
        FilterChipDef(id: 'rejected', labelAr: 'مرفوضة', color: Colors.red, count: _cnt(_St.rejected), active: _filter == 'rejected'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'قاعدة اعتماد جديدة',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_St s) => _items.where((i) => i.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _items : _items.where((i) => i.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final w = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 4, height: 56, color: w.status.color),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Text(w.docType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _navy, fontFamily: 'monospace'))),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54)),
              Text(w.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('${w.requester} · ${w.date}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ])),
            Text('${w.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _gold)),
            const SizedBox(width: 20),
            SizedBox(width: 120, child: Column(children: [
              Row(children: [Text('المستوى', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)), const Spacer(), Text('${w.currentLevel}/${w.totalLevels}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 2),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: w.currentLevel / w.totalLevels, minHeight: 6, backgroundColor: Colors.grey.shade200, color: w.status.color)),
            ])),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: w.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(w.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: w.status.color))),
            if (w.status == _St.pending || w.status == _St.inReview) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.close, size: 14, color: Colors.red), label: const Text('رفض', style: TextStyle(fontSize: 11, color: Colors.red))),
              const SizedBox(width: 6),
              FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: Colors.green), icon: const Icon(Icons.check, size: 14), label: const Text('اعتماد', style: TextStyle(fontSize: 11))),
            ],
          ])),
        );
      },
    );
  }

  Widget _kanban() {
    final cols = [_St.pending, _St.inReview, _St.approved, _St.rejected];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols.map((s) {
        final items = _items.where((i) => i.status == s).toList();
        final total = items.fold<double>(0, (sum, i) => sum + i.amount);
        return Container(
          width: 300,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.labelAr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color)),
                Text('${(total / 1000).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
            ])),
            ...items.map((w) => Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(3)), child: Text(w.docType, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                  const SizedBox(width: 6),
                  Text(w.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black54)),
                  const Spacer(),
                  if (w.amount > 500000) const Icon(Icons.priority_high, size: 12, color: Colors.red),
                ]),
                const SizedBox(height: 4),
                Text(w.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${(w.amount / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                  const Spacer(),
                  Text('${w.currentLevel}/${w.totalLevels}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.color)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: w.currentLevel / w.totalLevels, minHeight: 4, backgroundColor: Colors.grey.shade200, color: s.color)),
              ]),
            )),
            const SizedBox(height: 8),
          ]),
        );
      }).toList()),
    );
  }

  Widget _chart() {
    final byType = <String, double>{};
    for (final w in _items) {
      byType[w.docType] = (byType[w.docType] ?? 0) + w.amount;
    }
    final max = byType.values.reduce((a, b) => a > b ? a : b);
    final labels = {'JE': 'قيود', 'PO': 'أوامر شراء', 'EC': 'مطالبات', 'VB': 'فواتير', 'IO': 'أوامر داخلية', 'CT': 'عقود', 'CL': 'حدود ائتمان'};
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('قيمة الاعتمادات حسب نوع المستند', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...byType.entries.map((e) {
          final pct = e.value / max;
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [
            SizedBox(width: 140, child: Text('${labels[e.key] ?? e.key} (${e.key})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 22, backgroundColor: Colors.grey.shade100, color: _gold))),
            const SizedBox(width: 10),
            SizedBox(width: 140, child: Text('${(e.value / 1000).toStringAsFixed(0)}K ر.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold), textAlign: TextAlign.end)),
          ]));
        }),
      ]),
    );
  }
}

enum _St { pending, inReview, approved, rejected }

extension _StX on _St {
  String get labelAr => switch (this) {
        _St.pending => 'بانتظار',
        _St.inReview => 'قيد المراجعة',
        _St.approved => 'معتمدة ✓',
        _St.rejected => 'مرفوضة',
      };
  Color get color => switch (this) {
        _St.pending => Colors.orange,
        _St.inReview => Colors.blue,
        _St.approved => Colors.green,
        _St.rejected => Colors.red,
      };
}

class _WF {
  final String id, title, docType, requester, date;
  final double amount;
  final _St status;
  final int currentLevel, totalLevels;
  const _WF(this.id, this.title, this.docType, this.amount, this.requester, this.date, this.status, this.currentLevel, this.totalLevels);
}
