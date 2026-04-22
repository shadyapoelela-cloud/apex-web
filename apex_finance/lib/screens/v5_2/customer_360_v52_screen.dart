/// V5.2 — Customer 360 using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class Customer360V52Screen extends StatelessWidget {
  const Customer360V52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'شركة الراجحي للتجارة',
      subtitleAr: 'عميل ذهبي · منذ 2019 · إجمالي التعاملات 8.4 مليون ر.س',
      statusLabelAr: 'نشط VIP',
      statusColor: _gold,
      processStages: const [
        ProcessStage(labelAr: 'Lead'),
        ProcessStage(labelAr: 'Qualified'),
        ProcessStage(labelAr: 'Active'),
        ProcessStage(labelAr: 'Loyal'),
      ],
      processCurrentIndex: 3,
      smartButtons: [
        SmartButton(icon: Icons.receipt, labelAr: 'فاتورة', count: 142, color: _gold),
        SmartButton(icon: Icons.payments, labelAr: 'دفعة', count: 138, color: core_theme.AC.ok),
        SmartButton(icon: Icons.work, labelAr: 'مشروع', count: 8, color: _navy),
        SmartButton(icon: Icons.contact_phone, labelAr: 'تواصل', count: 45, color: core_theme.AC.info),
        SmartButton(icon: Icons.warning, labelAr: 'شكوى', count: 2, color: core_theme.AC.err),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.send, size: 16), label: Text('إرسال رسالة')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.add, size: 16),
          label: Text('فاتورة جديدة'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'overview', labelAr: 'نظرة عامة', icon: Icons.dashboard, builder: (ctx) => _overview()),
        ObjectPageTab(id: 'transactions', labelAr: 'المعاملات', icon: Icons.swap_horiz, builder: (ctx) => _transactions()),
        ObjectPageTab(id: 'contacts', labelAr: 'جهات الاتصال', icon: Icons.contacts, builder: (ctx) => _contacts()),
        ObjectPageTab(id: 'projects', labelAr: 'المشاريع', icon: Icons.work, builder: (ctx) => _projects()),
        ObjectPageTab(id: 'notes', labelAr: 'ملاحظات', icon: Icons.note, builder: (ctx) => _notes()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Copilot', contentAr: 'تنبيه: فاتورة INV-2026-1044 متأخرة 31 يوم — ينصح بإرسال تذكير.', timestamp: DateTime.now().subtract(const Duration(hours: 3)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'أحمد محمد', contentAr: 'اجتماع Q2 مجدول 25 أبريل الساعة 11:00', timestamp: DateTime.now().subtract(const Duration(days: 1)), kind: ChatterKind.activity),
        ChatterEntry(authorAr: 'سارة علي', contentAr: 'تمت إضافة عقد جديد بقيمة 340K ر.س', timestamp: DateTime.now().subtract(const Duration(days: 3)), kind: ChatterKind.statusChange),
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
              Expanded(child: _Kpi(label: 'إجمالي التعاملات', value: '8.4M', unit: 'ر.س', color: _gold, icon: Icons.trending_up)),
              SizedBox(width: 10),
              Expanded(child: _Kpi(label: 'المتبقي', value: '125K', unit: 'ر.س', color: core_theme.AC.warn, icon: Icons.pending)),
              SizedBox(width: 10),
              Expanded(child: _Kpi(label: 'DSO', value: '28', unit: 'يوم', color: core_theme.AC.info, icon: Icons.schedule)),
              SizedBox(width: 10),
              Expanded(child: _Kpi(label: 'درجة الائتمان', value: '872', unit: 'A+', color: core_theme.AC.ok, icon: Icons.credit_score)),
            ],
          ),
          const SizedBox(height: 20),
          _card('المعلومات الأساسية', Wrap(spacing: 28, runSpacing: 14, children: [
            _kv('الاسم القانوني', 'شركة الراجحي للتجارة المحدودة'),
            _kv('السجل التجاري', '1010234567'),
            _kv('الرقم الضريبي', '300987654300003'),
            _kv('النوع', 'عميل B2B · ذهبي'),
            _kv('القطاع', 'تجارة التجزئة'),
            _kv('المدينة', 'الرياض'),
            _kv('المدير المسؤول', 'أحمد محمد'),
            _kv('طريقة الدفع المفضلة', 'تحويل بنكي'),
          ])),
          const SizedBox(height: 16),
          _card('حدود الائتمان', Column(children: [
            _progRow('الحد الكلي', 500000, 125000, 'ر.س'),
            const SizedBox(height: 10),
            _progRow('أيام الدفع', 30, 28, 'يوم'),
          ])),
        ],
      ),
    );
  }

  Widget _transactions() {
    const txns = [
      ('INV-2026-1142', 'فاتورة', '2026-04-15', 145000.0, 'مدفوعة'),
      ('PAY-2026-428', 'دفعة', '2026-04-14', 145000.0, 'مستلم'),
      ('INV-2026-1098', 'فاتورة', '2026-03-28', 89000.0, 'مدفوعة'),
      ('INV-2026-1074', 'فاتورة', '2026-03-10', 67000.0, 'مدفوعة'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: txns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(
          children: [
            Icon(txns[i].$2 == 'فاتورة' ? Icons.receipt : Icons.payments, color: _gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txns[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                  Text('${txns[i].$2} · ${txns[i].$3}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Text('${txns[i].$4.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(width: 12),
            Chip(label: Text(txns[i].$5, style: const TextStyle(fontSize: 10)), backgroundColor: core_theme.AC.ok.withOpacity(0.1)),
          ],
        ),
      ),
    );
  }

  Widget _contacts() {
    const contacts = [
      ('محمد الراجحي', 'مدير عام', '📧 m.r@company.com', '📱 +966-50-1234567', true),
      ('فاطمة السعيد', 'مدير مالي', '📧 f.s@company.com', '📱 +966-55-2345678', false),
      ('عبدالله الشمراني', 'مشتريات', '📧 a.s@company.com', '📱 +966-54-3456789', false),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: contacts[i].$5 ? _gold : core_theme.AC.bdr)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: _gold.withOpacity(0.15), child: Text(contacts[i].$1[0], style: TextStyle(color: _gold, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(contacts[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    if (contacts[i].$5) Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.star, color: _gold, size: 14)),
                  ]),
                  Text(contacts[i].$2, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text('${contacts[i].$3} · ${contacts[i].$4}', style: TextStyle(fontSize: 10, color: core_theme.AC.tp)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.phone, size: 18), onPressed: () {}),
            IconButton(icon: const Icon(Icons.email, size: 18), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _projects() {
    const projects = [
      ('P-2026-042', 'تطوير النظام المحاسبي', 0.62, 340000.0, 'قيد التنفيذ'),
      ('P-2025-181', 'تدريب الموظفين', 1.0, 85000.0, 'منتهي'),
      ('P-2026-008', 'استشارات تحسين العمليات', 0.35, 120000.0, 'قيد التنفيذ'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: _gold),
                const SizedBox(width: 8),
                Text(projects[i].$1, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const Spacer(),
                Chip(label: Text(projects[i].$5, style: const TextStyle(fontSize: 10)), backgroundColor: projects[i].$3 == 1.0 ? core_theme.AC.ok.withOpacity(0.1) : core_theme.AC.info.withOpacity(0.1)),
              ],
            ),
            const SizedBox(height: 4),
            Text(projects[i].$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: projects[i].$3, minHeight: 8, backgroundColor: core_theme.AC.bdr, color: _gold))),
              const SizedBox(width: 10),
              Text('${(projects[i].$3 * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('قيمة العقد: ${projects[i].$4.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _notes() => Center(child: Padding(padding: EdgeInsets.all(48), child: Text('لا توجد ملاحظات — أضف واحدة من Chatter', style: TextStyle(color: core_theme.AC.ts))));

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 12), child]),
    );
  }

  Widget _kv(String k, String v) => SizedBox(width: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))]));

  Widget _progRow(String label, double total, double used, String unit) {
    final pct = used / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const Spacer(), Text('${used.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: core_theme.AC.bdr, color: pct > 0.8 ? core_theme.AC.err : (pct > 0.5 ? core_theme.AC.warn : core_theme.AC.ok))),
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
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.9))),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)), const SizedBox(width: 4), Text(unit, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)))]),
        ])),
      ]),
    );
  }
}
