/// V5.2 — Supplier 360 using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class Supplier360V52Screen extends StatelessWidget {
  const Supplier360V52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'مجموعة الخليج للتوريدات',
      subtitleAr: 'مورد استراتيجي · منذ 2017 · تصنيف A · 2.8M ر.س/سنة',
      statusLabelAr: 'نشط · Tier 1',
      statusColor: _purple,
      processStages: const [
        ProcessStage(labelAr: 'Prospect'),
        ProcessStage(labelAr: 'Evaluation'),
        ProcessStage(labelAr: 'Onboarded'),
        ProcessStage(labelAr: 'Strategic'),
      ],
      processCurrentIndex: 3,
      smartButtons: [
        SmartButton(icon: Icons.receipt_long, labelAr: 'فاتورة مورد', count: 86, color: _gold),
        SmartButton(icon: Icons.shopping_cart, labelAr: 'أمر شراء', count: 124, color: core_theme.AC.info),
        SmartButton(icon: Icons.verified, labelAr: 'شهادة', count: 6, color: core_theme.AC.ok),
        SmartButton(icon: Icons.gavel, labelAr: 'عقد', count: 3, color: _navy),
        SmartButton(icon: Icons.star, labelAr: 'تقييم', count: 4, color: _gold),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.request_quote, size: 16), label: Text('طلب عرض سعر')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.add_shopping_cart, size: 16),
          label: Text('أمر شراء جديد'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'overview', labelAr: 'نظرة عامة', icon: Icons.dashboard, builder: (ctx) => _overview()),
        ObjectPageTab(id: 'purchases', labelAr: 'المشتريات', icon: Icons.shopping_cart, builder: (ctx) => _purchases()),
        ObjectPageTab(id: 'payments', labelAr: 'المدفوعات', icon: Icons.payments, builder: (ctx) => _payments()),
        ObjectPageTab(id: 'contracts', labelAr: 'العقود', icon: Icons.gavel, builder: (ctx) => _contracts()),
        ObjectPageTab(id: 'performance', labelAr: 'الأداء', icon: Icons.trending_up, builder: (ctx) => _performance()),
        ObjectPageTab(id: 'docs', labelAr: 'الشهادات', icon: Icons.verified, builder: (ctx) => _docs()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Copilot', contentAr: 'تنبيه: شهادة ISO 9001 تنتهي خلال 28 يوم — يجب التجديد.', timestamp: DateTime.now().subtract(const Duration(hours: 5)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'خالد إبراهيم', contentAr: 'تأخّر التسليم في PO-2026-087 بـ 3 أيام — تم التواصل.', timestamp: DateTime.now().subtract(const Duration(days: 2)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'سارة علي', contentAr: 'تم تجديد العقد الإطاري لسنة 2026 بقيمة 2.8 مليون', timestamp: DateTime.now().subtract(const Duration(days: 14)), kind: ChatterKind.statusChange),
      ],
    );
  }

  Widget _overview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Kpi(label: 'مشتريات السنة', value: '2.8M', unit: 'ر.س', color: _gold, icon: Icons.shopping_cart)),
              SizedBox(width: 10),
              Expanded(child: _Kpi(label: 'مدفوعات مستحقة', value: '184K', unit: 'ر.س', color: core_theme.AC.warn, icon: Icons.payments)),
              SizedBox(width: 10),
              Expanded(child: _Kpi(label: 'متوسط الالتزام', value: '94%', unit: 'OTD', color: core_theme.AC.ok, icon: Icons.schedule)),
              SizedBox(width: 10),
              Expanded(child: _Kpi(label: 'تقييم الجودة', value: '4.6', unit: '/5', color: _purple, icon: Icons.star)),
            ],
          ),
          const SizedBox(height: 20),
          _card('المعلومات الأساسية', Wrap(spacing: 28, runSpacing: 14, children: [
            _kv('الاسم القانوني', 'مجموعة الخليج للتوريدات ذ.م.م'),
            _kv('السجل التجاري', '1010456789'),
            _kv('الرقم الضريبي', '300345678900003'),
            _kv('فئة الموردين', 'Tier 1 — استراتيجي'),
            _kv('المنتجات/الخدمات', 'مواد مكتبية · معدات IT'),
            _kv('مدة الدفع', '30 يوم صافي'),
            _kv('الحساب المصرفي', 'بنك الرياض · SA03...4578'),
            _kv('منسق العلاقة', 'خالد إبراهيم'),
          ])),
          const SizedBox(height: 16),
          _card('أداء التسليم (آخر 12 شهر)', Column(children: [
            _progRow('الالتزام بالمواعيد (OTD)', 100, 94, '%', core_theme.AC.ok),
            const SizedBox(height: 10),
            _progRow('جودة المنتجات', 100, 92, '%', _gold),
            const SizedBox(height: 10),
            _progRow('دقة الفواتير', 100, 98, '%', core_theme.AC.info),
            const SizedBox(height: 10),
            _progRow('الاستجابة للطلبات', 100, 89, '%', core_theme.AC.warn),
          ])),
        ],
      ),
    );
  }

  Widget _purchases() {
    final pos = [
      ('PO-2026-124', '2026-04-12', 140000.0, 'مُسلَّم', core_theme.AC.ok),
      ('PO-2026-118', '2026-04-03', 87000.0, 'مُسلَّم', core_theme.AC.ok),
      ('PO-2026-087', '2026-03-28', 210000.0, 'قيد التسليم', core_theme.AC.info),
      ('PO-2026-062', '2026-03-14', 45000.0, 'مُسلَّم', core_theme.AC.ok),
      ('PO-2026-041', '2026-02-28', 68000.0, 'مُسلَّم', core_theme.AC.ok),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: pos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Icon(Icons.shopping_cart, color: _gold),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pos[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
            Text('تاريخ الأمر: ${pos[i].$2}', style: const TextStyle(fontSize: 12)),
          ])),
          Text('${pos[i].$3.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: pos[i].$5.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(pos[i].$4, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: pos[i].$5))),
        ]),
      ),
    );
  }

  Widget _payments() {
    const pays = [
      ('PAY-2026-142', '2026-04-15', 140000.0, 'تحويل بنكي', 'مُرسَل'),
      ('PAY-2026-128', '2026-04-08', 87000.0, 'شيك', 'مُستلم'),
      ('PAY-2026-097', '2026-03-30', 210000.0, 'تحويل بنكي', 'معلّق'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: pays.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Icon(Icons.payments, color: pays[i].$5 == 'معلّق' ? core_theme.AC.warn : core_theme.AC.ok),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pays[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
            Text('${pays[i].$2} · ${pays[i].$4}', style: const TextStyle(fontSize: 12)),
          ])),
          Text('${pays[i].$3.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(width: 12),
          Chip(label: Text(pays[i].$5, style: const TextStyle(fontSize: 10)), backgroundColor: (pays[i].$5 == 'معلّق' ? core_theme.AC.warn : core_theme.AC.ok).withValues(alpha: 0.12)),
        ]),
      ),
    );
  }

  Widget _contracts() {
    final contracts = [
      ('عقد إطاري 2026', '2026-01-01 → 2026-12-31', 2800000.0, 'نشط', core_theme.AC.ok),
      ('عقد صيانة معدات IT', '2025-07-01 → 2026-06-30', 340000.0, 'نشط', core_theme.AC.ok),
      ('عقد توريد مواد مكتبية', '2025-03-15 → 2026-03-14', 145000.0, 'منتهي', core_theme.AC.td),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: contracts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: contracts[i].$4 == 'نشط' ? core_theme.AC.ok.withValues(alpha: 0.3) : core_theme.AC.bdr)),
        child: Row(children: [
          Icon(Icons.gavel, color: contracts[i].$5),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contracts[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(contracts[i].$2, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${contracts[i].$3.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            Chip(label: Text(contracts[i].$4, style: const TextStyle(fontSize: 10)), backgroundColor: contracts[i].$5.withValues(alpha: 0.12)),
          ]),
        ]),
      ),
    );
  }

  Widget _performance() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أداء المورد عبر 12 شهر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
            child: Column(
              children: [
                for (final m in const [('ينا', 0.92), ('فبر', 0.89), ('مارس', 0.96), ('أبريل', 0.94)])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text(m.$1, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: m.$2, minHeight: 16, backgroundColor: core_theme.AC.navy3, color: _gold))),
                        const SizedBox(width: 10),
                        SizedBox(width: 50, child: Text('${(m.$2 * 100).toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docs() {
    const docs = [
      ('ISO 9001:2015', '2025-05-01 → 2026-05-18', true, 28),
      ('ZATCA Certificate', '2024-12-01 → 2026-12-01', true, 220),
      ('Commercial Registration', '2023-03-10 → 2028-03-10', true, 688),
      ('ISO 14001', '2024-08-15 → 2027-08-15', true, 850),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final daysLeft = docs[i].$4;
        final urgent = daysLeft < 30;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: urgent ? core_theme.AC.err.withValues(alpha: 0.4) : core_theme.AC.bdr)),
          child: Row(children: [
            Icon(Icons.verified, color: urgent ? core_theme.AC.err : core_theme.AC.ok),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(docs[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text(docs[i].$2, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (urgent ? core_theme.AC.err : core_theme.AC.ok).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text('${daysLeft > 0 ? daysLeft : "منتهية"} يوم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: urgent ? core_theme.AC.err : core_theme.AC.ok))),
          ]),
        );
      },
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]),
    );
  }

  Widget _kv(String k, String v) => SizedBox(width: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))]));

  Widget _progRow(String label, double total, double used, String unit, Color color) {
    final pct = used / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const Spacer(), Text('${used.toStringAsFixed(0)}$unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: core_theme.AC.bdr, color: color)),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _Kpi({required this.label, required this.value, required this.unit, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 4), Text(unit, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)))]),
        ])),
      ]),
    );
  }
}
