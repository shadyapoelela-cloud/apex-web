/// V5.2 — Closing Cockpit with DAG (SAP-killer feature for Middle East).
///
/// Visual dependency graph showing what blocks what during period close.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class ClosingCockpitV52Screen extends StatelessWidget {
  const ClosingCockpitV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'قمرة الإقفال 🎯 (Closing Cockpit)',
      subtitleAr: 'إقفال أبريل 2026 · 18/26 مكتمل · DAG dependency graph · 3 كيانات بالتوازي',
      statusLabelAr: 'قيد الإقفال',
      statusColor: core_theme.AC.warn,
      processStages: const [
        ProcessStage(labelAr: 'Pre-Close'),
        ProcessStage(labelAr: 'Accruals'),
        ProcessStage(labelAr: 'Review'),
        ProcessStage(labelAr: 'Post-Close'),
        ProcessStage(labelAr: 'Reports'),
      ],
      processCurrentIndex: 2,
      smartButtons: [
        SmartButton(icon: Icons.check_circle, labelAr: 'مكتملة', count: 18, color: core_theme.AC.ok),
        SmartButton(icon: Icons.pending, labelAr: 'قيد التنفيذ', count: 5, color: core_theme.AC.warn),
        SmartButton(icon: Icons.block, labelAr: 'محجوزة', count: 3, color: core_theme.AC.err),
        SmartButton(icon: Icons.account_tree, labelAr: 'كيانات', count: 3, color: _navy),
        SmartButton(icon: Icons.rocket_launch, labelAr: 'دقائق تبقّت', count: 480, color: _purple),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.undo, size: 16), label: Text('Rollback')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.fast_forward, size: 16),
          label: Text('تسريع الإقفال AI'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'dag', labelAr: 'مخطط الاعتمادات DAG', icon: Icons.schema, builder: (_) => _dag()),
        ObjectPageTab(id: 'tasks', labelAr: 'قائمة المهام', icon: Icons.checklist, builder: (_) => _tasks()),
        ObjectPageTab(id: 'entities', labelAr: 'الكيانات (3)', icon: Icons.account_tree, builder: (_) => _entities()),
        ObjectPageTab(id: 'bottleneck', labelAr: 'الاختناقات', icon: Icons.warning, builder: (_) => _bottleneck()),
        ObjectPageTab(id: 'audit', labelAr: 'سجل التدقيق', icon: Icons.history, builder: (_) => _audit()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Closing Assistant', contentAr: '⚠️ مهمة "مطابقة بنك HSBC" أخّرت 3 مهام أخرى. ينصح بالبدء بها فوراً.', timestamp: DateTime.now().subtract(const Duration(minutes: 30)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'سارة علي', contentAr: 'أكملت إقفال فرع الرياض · جاهز للمراجعة', timestamp: DateTime.now().subtract(const Duration(hours: 2)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'النظام', contentAr: 'إقفال الكيان الثالث (الدمام) تم تلقائياً بعد إكمال المهام الأساسية', timestamp: DateTime.now().subtract(const Duration(hours: 4)), kind: ChatterKind.statusChange),
      ],
    );
  }

  Widget _dag() {
    // Visual dependency graph (simplified flow)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _purple.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple)),
          child: Row(children: [
            Icon(Icons.schema, color: _purple, size: 24),
            SizedBox(width: 10),
            Expanded(child: Text('مخطط الاعتمادات DAG — يُظهر ما يجب إكماله قبل ما', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          ]),
        ),
        const SizedBox(height: 20),
        // Level 1: Pre-Close
        _dagLevel('المرحلة 1 — Pre-Close (إقفال الأنظمة الفرعية)', core_theme.AC.info, [
          _dagNode('1.1', 'إقفال المبيعات', Icons.point_of_sale, core_theme.AC.ok, true, []),
          _dagNode('1.2', 'إقفال المشتريات', Icons.shopping_cart, core_theme.AC.ok, true, []),
          _dagNode('1.3', 'إقفال المخزون', Icons.inventory, core_theme.AC.ok, true, []),
          _dagNode('1.4', 'إقفال الرواتب', Icons.people, core_theme.AC.ok, true, []),
        ]),
        _dagArrow(),
        // Level 2: Accruals
        _dagLevel('المرحلة 2 — Accruals (قيود الاستحقاق)', _gold, [
          _dagNode('2.1', 'استحقاق الإيجارات', Icons.home, core_theme.AC.ok, true, ['1.2']),
          _dagNode('2.2', 'استحقاق الفوائد', Icons.bolt, core_theme.AC.ok, true, []),
          _dagNode('2.3', 'الإهلاك الشهري', Icons.trending_down, core_theme.AC.ok, true, []),
          _dagNode('2.4', 'الضريبة المؤجلة', Icons.account_balance, core_theme.AC.warn, false, ['2.1', '2.3']),
        ]),
        _dagArrow(),
        // Level 3: Review & Reconciliation
        _dagLevel('المرحلة 3 — Review (مراجعة ومطابقة)', core_theme.AC.warn, [
          _dagNode('3.1', 'مطابقة النقدية', Icons.account_balance, core_theme.AC.warn, false, ['2.2']),
          _dagNode('3.2', 'مطابقة الذمم المدينة', Icons.person, core_theme.AC.warn, false, ['1.1']),
          _dagNode('3.3', 'مطابقة الذمم الدائنة', Icons.store, core_theme.AC.err, false, ['1.2', '2.1'], isBlocker: true),
          _dagNode('3.4', 'فحص AI للشذوذ', Icons.psychology, core_theme.AC.td, false, ['3.1', '3.2', '3.3']),
        ]),
        _dagArrow(),
        // Level 4: Post-Close
        _dagLevel('المرحلة 4 — Post-Close (الإقفال النهائي)', _navy, [
          _dagNode('4.1', 'ترحيل قيود الإقفال', Icons.check_circle, core_theme.AC.td, false, ['3.4']),
          _dagNode('4.2', 'قفل الفترة (Lock)', Icons.lock, core_theme.AC.td, false, ['4.1']),
        ]),
        _dagArrow(),
        // Level 5: Reports
        _dagLevel('المرحلة 5 — Reports (التقارير)', _purple, [
          _dagNode('5.1', 'ميزان المراجعة', Icons.table_chart, core_theme.AC.td, false, ['4.2']),
          _dagNode('5.2', 'القوائم المالية', Icons.insert_chart, core_theme.AC.td, false, ['4.2']),
          _dagNode('5.3', 'تقارير الأداء', Icons.analytics, core_theme.AC.td, false, ['4.2']),
        ]),
        const SizedBox(height: 24),
        _dagLegend(),
      ]),
    );
  }

  Widget _dagLevel(String title, Color color, List<Widget> nodes) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 16, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 12, children: nodes),
    ]);
  }

  Widget _dagNode(String id, String title, IconData icon, Color color, bool done, List<String> deps, {bool isBlocker = false}) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBlocker ? core_theme.AC.err.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isBlocker ? core_theme.AC.err : color.withValues(alpha: 0.4), width: isBlocker ? 2 : 1),
        boxShadow: [BoxShadow(color: core_theme.AC.tp.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Icon(icon, color: color, size: 14)),
          const SizedBox(width: 6),
          Text(id, style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.ts)),
          const Spacer(),
          Icon(done ? Icons.check_circle : (isBlocker ? Icons.error : Icons.schedule), color: done ? core_theme.AC.ok : (isBlocker ? core_theme.AC.err : core_theme.AC.warn), size: 14),
        ]),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (deps.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 3, children: deps.map((d) => Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(3)), child: Text('← $d', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: core_theme.AC.ts)))).toList()),
        ],
      ]),
    );
  }

  Widget _dagArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 2, height: 24, color: core_theme.AC.bdr),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, color: core_theme.AC.td, size: 24),
      ]),
    );
  }

  Widget _dagLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _LegendItem(color: core_theme.AC.ok, icon: Icons.check_circle, label: 'مكتمل'),
        SizedBox(width: 20),
        _LegendItem(color: core_theme.AC.warn, icon: Icons.schedule, label: 'قيد التنفيذ'),
        SizedBox(width: 20),
        _LegendItem(color: core_theme.AC.err, icon: Icons.error, label: 'Blocker (يحجز الآخرين)'),
        SizedBox(width: 20),
        _LegendItem(color: core_theme.AC.td, icon: Icons.circle_outlined, label: 'ينتظر'),
      ]),
    );
  }

  Widget _tasks() {
    const tasks = [
      ('1.1', 'إقفال المبيعات', 'سارة علي', true, 'Pre-Close', []),
      ('1.2', 'إقفال المشتريات', 'أحمد محمد', true, 'Pre-Close', []),
      ('1.3', 'إقفال المخزون', 'خالد إبراهيم', true, 'Pre-Close', []),
      ('1.4', 'إقفال الرواتب', 'ليلى أحمد', true, 'Pre-Close', []),
      ('2.1', 'استحقاق الإيجارات', 'أحمد محمد', true, 'Accruals', ['1.2']),
      ('2.2', 'استحقاق الفوائد', 'أحمد محمد', true, 'Accruals', []),
      ('2.3', 'الإهلاك الشهري', 'سارة علي', true, 'Accruals', []),
      ('2.4', 'الضريبة المؤجلة', 'أحمد محمد', false, 'Accruals', ['2.1', '2.3']),
      ('3.1', 'مطابقة النقدية', 'سارة علي', false, 'Review', ['2.2']),
      ('3.2', 'مطابقة الذمم المدينة', 'خالد', false, 'Review', ['1.1']),
      ('3.3', 'مطابقة الذمم الدائنة ⚠️', 'ليلى', false, 'Review', ['1.2', '2.1']),
      ('3.4', 'فحص AI للشذوذ', 'النظام', false, 'Review', ['3.1', '3.2', '3.3']),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Checkbox(value: tasks[i].$4, onChanged: (_) {}, activeColor: _gold),
          SizedBox(width: 40, child: Text(tasks[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts))),
          Expanded(flex: 2, child: Text(tasks[i].$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, decoration: tasks[i].$4 ? TextDecoration.lineThrough : null))),
          Text(tasks[i].$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Text(tasks[i].$5, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
          const SizedBox(width: 10),
          if (tasks[i].$6.isNotEmpty) ...[
            Icon(Icons.arrow_upward, size: 10, color: core_theme.AC.ts),
            const SizedBox(width: 2),
            Text('${tasks[i].$6.length}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ],
        ]),
      ),
    );
  }

  Widget _entities() {
    const entities = [
      ('أبكس الرياض', 'الكيان الرئيسي', 0.85, 'سارة علي', _ES.active, 22, 26),
      ('أبكس جدة', 'فرع', 1.0, 'سعاد الشمراني', _ES.done, 26, 26),
      ('أبكس الدمام', 'فرع', 0.52, 'طلال الغامدي', _ES.active, 14, 26),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: entities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: entities[i].$5 == _ES.done ? core_theme.AC.ok.withValues(alpha: 0.3) : core_theme.AC.warn.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(entities[i].$5 == _ES.done ? Icons.check_circle : Icons.sync, color: entities[i].$5 == _ES.done ? core_theme.AC.ok : _gold, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entities[i].$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              Text('${entities[i].$2} · مسؤول: ${entities[i].$4}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (entities[i].$5 == _ES.done ? core_theme.AC.ok : _gold).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(entities[i].$5 == _ES.done ? '✓ مكتمل' : 'قيد الإقفال', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: entities[i].$5 == _ES.done ? core_theme.AC.ok : _gold))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: entities[i].$3, minHeight: 14, backgroundColor: core_theme.AC.bdr, color: entities[i].$5 == _ES.done ? core_theme.AC.ok : _gold))),
            const SizedBox(width: 10),
            Text('${entities[i].$6}/${entities[i].$7}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text('(${(entities[i].$3 * 100).toInt()}%)', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ]),
        ]),
      ),
    );
  }

  Widget _bottleneck() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: core_theme.AC.err.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.err, width: 1.5)),
          child: Row(children: [
            Icon(Icons.warning_amber, color: core_theme.AC.err, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الاختناق الرئيسي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.err)),
              Text('مهمة 3.3 "مطابقة الذمم الدائنة" تعوق 4 مهام أخرى — يجب التصعيد', style: TextStyle(fontSize: 12, color: core_theme.AC.tp)),
            ])),
            FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: core_theme.AC.err), icon: const Icon(Icons.priority_high, size: 14), label: Text('تصعيد')),
          ]),
        ),
        const SizedBox(height: 20),
        _bottleneckRow('3.3', 'مطابقة الذمم الدائنة', 'ليلى أحمد', '3 ساعات', '4 مهام تعتمد عليها'),
        _bottleneckRow('2.4', 'الضريبة المؤجلة', 'أحمد محمد', '1 ساعة', '2 مهام تعتمد عليها'),
        _bottleneckRow('3.4', 'فحص AI للشذوذ', 'النظام', '30 دقيقة', 'يحتاج 3.1+3.2+3.3'),
      ]),
    );
  }

  Widget _bottleneckRow(String id, String task, String owner, String eta, String impact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: core_theme.AC.err.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(id, style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.err))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          Text('$owner · متوقع $eta', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        Text(impact, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.err)),
      ]),
    );
  }

  Widget _audit() {
    final entries = [
      ('2026-04-19 14:22', 'سارة علي', 'بدأت إقفال فرع جدة', Icons.play_arrow, core_theme.AC.ok),
      ('2026-04-19 13:45', 'أحمد محمد', 'أكمل مهمة 2.4 (الضريبة المؤجلة)', Icons.check_circle, core_theme.AC.ok),
      ('2026-04-19 13:15', 'النظام', 'تم تلقائياً: ترحيل قيود الاستحقاق الدورية', Icons.auto_awesome, _purple),
      ('2026-04-19 12:30', 'ليلى أحمد', '⚠️ طلبت مساعدة في مهمة 3.3', Icons.help, core_theme.AC.warn),
      ('2026-04-19 11:00', 'AI Assistant', 'اكتشف شذوذاً في بنك HSBC — 45K', Icons.psychology, _purple),
      ('2026-04-19 09:00', 'المدير المالي', 'اعتمد بدء الإقفال', Icons.verified, _gold),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          CircleAvatar(radius: 14, backgroundColor: entries[i].$5.withValues(alpha: 0.15), child: Icon(entries[i].$4, color: entries[i].$5, size: 14)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entries[i].$3, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text('${entries[i].$1} · ${entries[i].$2}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ])),
        ]),
      ),
    );
  }
}

enum _ES { active, done }

class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendItem({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
    ]);
  }
}
