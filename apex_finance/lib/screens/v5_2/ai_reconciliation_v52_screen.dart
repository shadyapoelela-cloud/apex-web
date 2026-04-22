/// V5.2 — AI Reconciliation using ObjectPageTemplate.
///
/// Intelligent matching engine for bank transactions, intercompany balances,
/// and customer/vendor reconciliation. Uses AI to propose matches.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class AiReconciliationV52Screen extends StatelessWidget {
  const AiReconciliationV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'المطابقات الذكية بالـ AI',
      subtitleAr: 'Claude Opus · مطابقة تلقائية لـ 96.2% من المعاملات · 1,240 عملية مطابَقة · 47 تحتاج مراجعة',
      statusLabelAr: 'نشط · AI',
      statusColor: _purple,
      smartButtons: [
        SmartButton(icon: Icons.auto_awesome, labelAr: 'مطابَق تلقائياً', count: 1193, color: core_theme.AC.ok),
        SmartButton(icon: Icons.pending, labelAr: 'يحتاج مراجعة', count: 47, color: core_theme.AC.warn),
        SmartButton(icon: Icons.error, labelAr: 'غير متطابق', count: 8, color: core_theme.AC.err),
        SmartButton(icon: Icons.rule, labelAr: 'قاعدة نشطة', count: 34, color: _navy),
        SmartButton(icon: Icons.speed, labelAr: 'معدّل الدقة', count: 96, color: _gold),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.refresh, size: 16), label: Text('إعادة تشغيل AI')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.check, size: 16),
          label: Text('قبول كل المطابقات'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'overview', labelAr: 'النظرة العامة', icon: Icons.dashboard, builder: (_) => _overview()),
        ObjectPageTab(id: 'pending', labelAr: 'يحتاج مراجعة (47)', icon: Icons.pending_actions, builder: (_) => _pending()),
        ObjectPageTab(id: 'matched', labelAr: 'مطابَق تلقائياً', icon: Icons.check_circle, builder: (_) => _matched()),
        ObjectPageTab(id: 'unmatched', labelAr: 'غير متطابق (8)', icon: Icons.error_outline, builder: (_) => _unmatched()),
        ObjectPageTab(id: 'rules', labelAr: 'قواعد المطابقة', icon: Icons.rule, builder: (_) => _rules()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Matcher', contentAr: 'اكتشفت 3 معاملات مشبوهة: نفس المبلغ + نفس التاريخ + موردين مختلفين — ينصح بالتحقق.', timestamp: DateTime.now().subtract(const Duration(hours: 1)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'سارة علي', contentAr: 'تم قبول 28 مطابقة يدوياً', timestamp: DateTime.now().subtract(const Duration(hours: 3)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'AI Matcher', contentAr: 'تحديث النموذج — دقة ارتفعت من 94.1% إلى 96.2%', timestamp: DateTime.now().subtract(const Duration(days: 2)), kind: ChatterKind.statusChange),
      ],
    );
  }

  Widget _overview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _bigStat('الدقة الكلية', '96.2', '%', core_theme.AC.ok, Icons.speed)),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('معاملات اليوم', '1,240', '', _gold, Icons.sync)),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('توفير الوقت', '16', 'ساعة', _navy, Icons.schedule)),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('الأموال المطابَقة', '8.4M', 'ر.س', _purple, Icons.account_balance)),
        ]),
        const SizedBox(height: 20),
        _card('أنواع المطابقات النشطة', Column(children: [
          _typeRow('مطابقة بنكية', 'Bank Reconciliation', 840, 96.8, Icons.account_balance, core_theme.AC.info),
          _typeRow('مطابقة الذمم المدينة', 'Customer Aging', 280, 94.2, Icons.person, core_theme.AC.ok),
          _typeRow('مطابقة الذمم الدائنة', 'Vendor Statements', 82, 98.1, Icons.store, core_theme.AC.warn),
          _typeRow('مطابقة المعاملات البينية', 'Intercompany', 38, 92.5, Icons.sync_alt, _purple),
        ])),
        const SizedBox(height: 16),
        _card('أداء AI عبر 7 أيام', Column(children: [
          for (final d in const [('السبت', 0.942), ('الأحد', 0.951), ('الاثنين', 0.948), ('الثلاثاء', 0.963), ('الأربعاء', 0.959), ('الخميس', 0.962), ('الجمعة', 0.962)])
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              SizedBox(width: 80, child: Text(d.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: d.$2, minHeight: 12, backgroundColor: core_theme.AC.navy3, color: _gold))),
              const SizedBox(width: 10),
              Text('${(d.$2 * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
            ])),
        ])),
      ]),
    );
  }

  Widget _typeRow(String nameAr, String nameEn, int count, double accuracy, IconData icon, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nameAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        Text('$nameEn · $count عملية', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text('${accuracy.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
    ]));
  }

  Widget _pending() {
    const items = [
      ('P-001', 'دفعة من عميل بنك HSBC', '2026-04-18', 45000.0, 'شركة الراجحي', 'تعدد مطابقات محتملة (3)', 0.72),
      ('P-002', 'تحويل داخلي بين فروع', '2026-04-17', 28000.0, 'فرع جدة → الرياض', 'فرق في التاريخ (3 أيام)', 0.85),
      ('P-003', 'رسوم بنكية غير معروفة', '2026-04-17', 180.0, 'بنك الرياض', 'لا توجد قاعدة مطابقة', 0.45),
      ('P-004', 'فاتورة مورد مرجع مكسور', '2026-04-16', 12400.0, 'مؤسسة الخليج', 'فرق في المبلغ 200 ر.س', 0.78),
      ('P-005', 'استقبال نقدي متعدد', '2026-04-16', 8500.0, 'نقاط البيع', 'يجب توزيعه على 3 فواتير', 0.68),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final confidenceColor = items[i].$7 >= 0.8 ? core_theme.AC.ok : items[i].$7 >= 0.6 ? core_theme.AC.warn : core_theme.AC.err;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.warn.withOpacity(0.3))),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.auto_awesome, color: _purple),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(items[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 8),
                Text(items[i].$3, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ]),
              Text(items[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text('${items[i].$5} · ${items[i].$6}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            Text('${items[i].$4.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('ثقة AI', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${(items[i].$7 * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: confidenceColor)),
            ]),
            const SizedBox(width: 16),
            OutlinedButton.icon(onPressed: () {}, icon: Icon(Icons.close, size: 14, color: core_theme.AC.err), label: Text('رفض', style: TextStyle(fontSize: 11, color: core_theme.AC.err))),
            const SizedBox(width: 6),
            FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: core_theme.AC.ok), icon: const Icon(Icons.check, size: 14), label: Text('قبول', style: TextStyle(fontSize: 11))),
          ]),
        );
      },
    );
  }

  Widget _matched() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 64, color: core_theme.AC.ok.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text('1,193 مطابقة تلقائية ناجحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
        Text('تم قبولها بثقة >95% بدون تدخل بشري', style: TextStyle(color: core_theme.AC.ts)),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.list), label: Text('عرض القائمة الكاملة')),
      ]),
    );
  }

  Widget _unmatched() {
    const items = [
      ('U-001', 'تحويل بنكي غير معروف', '2026-04-17', 12500.0, 'لا يوجد مصدر مقابل'),
      ('U-002', 'رسوم معاملة', '2026-04-17', 85.0, 'رسوم بنكية غير مسجّلة'),
      ('U-003', 'تحويل SWIFT قديم', '2026-04-14', 340000.0, 'يحتاج تحقيق يدوي'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: core_theme.AC.err.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.err, width: 1.5)),
        child: Row(children: [
          Icon(Icons.error, color: core_theme.AC.err, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(items[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
            Text(items[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text('${items[i].$3} · ${items[i].$5}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Text('${items[i].$4.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.err)),
          const SizedBox(width: 16),
          FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _purple), icon: const Icon(Icons.search, size: 14), label: Text('تحقيق', style: TextStyle(fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _rules() {
    const rules = [
      ('R-001', 'مطابقة بنك الرياض → ذمم مدينة', 'عند: مبلغ = مبلغ الفاتورة (±1%) ومرجع يتضمّن رقم الفاتورة', 0.98, 420),
      ('R-002', 'رسوم بنكية شهرية', 'عند: تعليق يحتوي "fee" أو "رسوم" + مبلغ < 500', 1.0, 28),
      ('R-003', 'تحويلات داخلية بين فروع', 'عند: مبلغ خروج = مبلغ دخول بين حسابات نفس الشركة خلال 72 ساعة', 0.96, 52),
      ('R-004', 'دفعات Mada', 'عند: مرجع يبدأ بـ MADA + انقضى 2-3 أيام على الفاتورة', 0.99, 280),
      ('R-005', 'مطابقة بيان مورد', 'عند: رقم فاتورة متطابق + مبلغ متطابق + عملة متطابقة', 0.97, 96),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.rule, color: _gold),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(rules[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
              const SizedBox(width: 8),
              Text(rules[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text(rules[i].$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.4)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('دقة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            Text('${(rules[i].$4 * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.ok)),
          ]),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('تشغيل', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            Text('${rules[i].$5}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
          ]),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
        ]),
      ),
    );
  }

  Widget _card(String title, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]));

  Widget _bigStat(String label, String value, String unit, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.9)))]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 4), Text(unit, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)))]),
        ]),
      );
}
