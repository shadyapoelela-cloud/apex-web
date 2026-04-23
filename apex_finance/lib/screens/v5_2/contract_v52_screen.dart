/// V5.2 — Contract Management using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class ContractV52Screen extends StatelessWidget {
  const ContractV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'عقد CTR-2026-042',
      subtitleAr: 'توريد وصيانة معدات IT · مجموعة الخليج للتوريدات · 2.8M ر.س',
      statusLabelAr: 'نشط',
      statusColor: core_theme.AC.ok,
      processStages: const [
        ProcessStage(labelAr: 'مسودة'),
        ProcessStage(labelAr: 'قيد التفاوض'),
        ProcessStage(labelAr: 'موقّع'),
        ProcessStage(labelAr: 'نشط'),
        ProcessStage(labelAr: 'منتهي'),
      ],
      processCurrentIndex: 3,
      smartButtons: [
        SmartButton(icon: Icons.description, labelAr: 'ملاحق', count: 3, color: _navy),
        SmartButton(icon: Icons.shopping_cart, labelAr: 'أوامر شراء', count: 12, color: _gold),
        SmartButton(icon: Icons.payments, labelAr: 'مدفوعات', count: 8, color: core_theme.AC.ok),
        SmartButton(icon: Icons.verified, labelAr: 'موافقات', count: 5, color: core_theme.AC.info),
        SmartButton(icon: Icons.gavel, labelAr: 'نزاعات', count: 0, color: core_theme.AC.err),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf, size: 16), label: Text('PDF')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.add_circle, size: 16),
          label: Text('إضافة ملحق'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'overview', labelAr: 'نظرة عامة', icon: Icons.dashboard, builder: (_) => _overview()),
        ObjectPageTab(id: 'terms', labelAr: 'البنود', icon: Icons.article, builder: (_) => _terms()),
        ObjectPageTab(id: 'timeline', labelAr: 'الجدول الزمني', icon: Icons.timeline, builder: (_) => _timeline()),
        ObjectPageTab(id: 'renewal', labelAr: 'التجديد', icon: Icons.autorenew, builder: (_) => _renewal()),
        ObjectPageTab(id: 'signatures', labelAr: 'التوقيعات', icon: Icons.draw, builder: (_) => _signatures()),
        ObjectPageTab(id: 'docs', labelAr: 'المرفقات', icon: Icons.attach_file, builder: (_) => _docs()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Legal Review', contentAr: 'ملاحظة: بند التجديد التلقائي غير موجود — يُنصح بإضافته في الملحق القادم.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'أحمد محمد', contentAr: 'تم توقيع الملحق الثاني بقيمة 340K ر.س', timestamp: DateTime.now().subtract(const Duration(days: 5)), kind: ChatterKind.statusChange),
        ChatterEntry(authorAr: 'سارة علي', contentAr: '@ليلى — راجعي بنود الغرامات، المورد طلب تعديلاً.', timestamp: DateTime.now().subtract(const Duration(days: 10)), kind: ChatterKind.message),
      ],
    );
  }

  Widget _overview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _Kpi(label: 'قيمة العقد', value: '2.8M', unit: 'ر.س', color: _gold, icon: Icons.attach_money)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'المنفذ حتى الآن', value: '62%', unit: '', color: core_theme.AC.ok, icon: Icons.check_circle)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'تبقّى', value: '240', unit: 'يوم', color: core_theme.AC.info, icon: Icons.schedule)),
          SizedBox(width: 10),
          Expanded(child: _Kpi(label: 'درجة الأداء', value: '4.7', unit: '/5', color: _navy, icon: Icons.star)),
        ]),
        const SizedBox(height: 20),
        _card('البيانات الأساسية', Wrap(spacing: 28, runSpacing: 14, children: [
          _kv('نوع العقد', 'عقد إطاري سنوي'),
          _kv('الطرف الأول', 'شركة أبكس المملكة'),
          _kv('الطرف الثاني', 'مجموعة الخليج للتوريدات'),
          _kv('تاريخ التوقيع', '2026-01-15'),
          _kv('تاريخ البدء', '2026-02-01'),
          _kv('تاريخ الانتهاء', '2026-12-31'),
          _kv('القيمة الإجمالية', '2,800,000 ر.س'),
          _kv('العملة', 'ر.س SAR'),
          _kv('طريقة الدفع', 'نصف شهرياً — 30 يوم'),
          _kv('قانون الولاية', 'المملكة العربية السعودية'),
        ])),
        const SizedBox(height: 16),
        _card('بنود محورية', Column(children: [
          _bullet('مدة العقد', '12 شهراً مع إمكانية التجديد'),
          _bullet('الدفعة المقدمة', '10% من قيمة العقد (280K)'),
          _bullet('الغرامات', '0.5% لكل يوم تأخير'),
          _bullet('ضمان الجودة', 'سنة واحدة بعد التسليم'),
          _bullet('السرية', 'NDA ساري 5 سنوات بعد الانتهاء'),
        ])),
      ]),
    );
  }

  Widget _terms() {
    const sections = [
      ('القسم 1 — الأطراف والتعريفات', ['الطرف الأول: شركة أبكس المملكة (المشتري)', 'الطرف الثاني: مجموعة الخليج للتوريدات (البائع)', 'التعريفات القانونية والفنية']),
      ('القسم 2 — نطاق العمل', ['توريد 500 جهاز كمبيوتر', 'خدمات التركيب والإعداد', 'الصيانة الدورية لمدة 12 شهراً', 'التدريب الأولي للموظفين']),
      ('القسم 3 — التزامات الأطراف', ['التزامات الطرف الأول (الدفع، التسهيلات)', 'التزامات الطرف الثاني (التسليم، الجودة)', 'المواعيد والجداول الزمنية']),
      ('القسم 4 — القيمة والدفع', ['قيمة العقد: 2,800,000 ر.س', 'دفعة مقدمة: 10% (280K)', 'دفعات شهرية: 210K × 12', 'دفعات عند التسليم: حسب المراحل']),
      ('القسم 5 — الغرامات والتعويضات', ['غرامة التأخير: 0.5%/يوم', 'حد أقصى للغرامة: 5% من قيمة البند', 'شروط الإعفاء (قوة قاهرة)']),
      ('القسم 6 — فض النزاعات', ['محاولة التسوية الودية', 'اللجوء للتحكيم التجاري', 'الاختصاص القضائي']),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sections[i].$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          ...sections[i].$2.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 5, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 12, height: 1.5))),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _timeline() {
    const milestones = [
      ('2026-01-15', 'توقيع العقد', true, Icons.draw),
      ('2026-02-01', 'الدفعة المقدمة (280K)', true, Icons.payments),
      ('2026-02-15', 'تسليم أول 100 جهاز', true, Icons.local_shipping),
      ('2026-04-01', 'تسليم أول 200 جهاز', true, Icons.local_shipping),
      ('2026-06-30', 'نصف المدة - مراجعة', false, Icons.event),
      ('2026-08-15', 'تسليم باقي الأجهزة', false, Icons.local_shipping),
      ('2026-12-31', 'انتهاء العقد', false, Icons.event_available),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: milestones.length,
      itemBuilder: (ctx, i) {
        final m = milestones[i];
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: m.$3 ? _gold : core_theme.AC.bdr, shape: BoxShape.circle),
                child: Icon(m.$4, color: m.$3 ? Colors.white : core_theme.AC.td, size: 16),
              ),
              if (i < milestones.length - 1)
                Expanded(child: Container(width: 2, color: m.$3 ? _gold.withValues(alpha: 0.3) : core_theme.AC.bdr, margin: const EdgeInsets.symmetric(vertical: 4))),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: m.$3 ? _gold.withValues(alpha: 0.06) : core_theme.AC.navy3, borderRadius: BorderRadius.circular(8), border: Border.all(color: m.$3 ? _gold.withValues(alpha: 0.3) : core_theme.AC.bdr)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(m.$1, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    ])),
                    if (m.$3) Icon(Icons.check_circle, color: core_theme.AC.ok, size: 18),
                  ]),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _renewal() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: core_theme.AC.warn.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.warn.withValues(alpha: 0.3))),
          child: Row(children: [
            Icon(Icons.autorenew, color: core_theme.AC.warn, size: 28),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تاريخ انتهاء العقد: 2026-12-31', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              Text('تبقى 240 يوم — يُنصح بالتقييم قبل 90 يوم من الانتهاء', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.autorenew), label: Text('تجديد العقد لسنة'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit), label: Text('إعادة التفاوض'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.close), label: Text('عدم التجديد'))),
        ]),
        const SizedBox(height: 20),
        Text('مؤشرات التقييم:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 10),
        _metric('التزام المواعيد', 0.94, core_theme.AC.ok, '94%'),
        _metric('جودة المنتجات', 0.88, _gold, '88%'),
        _metric('جودة الخدمة', 0.96, core_theme.AC.ok, '96%'),
        _metric('دقة الفواتير', 0.98, core_theme.AC.info, '98%'),
      ]),
    );
  }

  Widget _metric(String label, double value, Color color, String pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(label, style: const TextStyle(fontSize: 12)), const Spacer(), Text(pct, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))]),
        const SizedBox(height: 3),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: core_theme.AC.bdr, color: color)),
      ]),
    );
  }

  Widget _signatures() {
    const sigs = [
      ('المدير التنفيذي', 'محمد بن عبدالرحمن', 'أبكس المملكة', '2026-01-15', true),
      ('المدير المالي', 'أحمد الشمراني', 'أبكس المملكة', '2026-01-15', true),
      ('الشاهد القانوني', 'د. ليلى الفارس', 'المستشار القانوني', '2026-01-15', true),
      ('المدير العام', 'سعود الخليج', 'مجموعة الخليج', '2026-01-15', true),
      ('الشاهد', 'عبدالله العمري', 'مجموعة الخليج', '2026-01-15', true),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: sigs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final s = sigs[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: s.$5 ? core_theme.AC.ok.withValues(alpha: 0.3) : core_theme.AC.bdr)),
          child: Row(children: [
            CircleAvatar(backgroundColor: _gold.withValues(alpha: 0.15), child: Text(s.$2[0], style: TextStyle(color: _gold, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text('${s.$1} · ${s.$3}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              Text('تاريخ التوقيع: ${s.$4}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ])),
            if (s.$5) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.check_circle, size: 12, color: core_theme.AC.ok), SizedBox(width: 4), Text('موقّع', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.ok))])),
          ]),
        );
      },
    );
  }

  Widget _docs() {
    final docs = [
      ('العقد الأصلي.pdf', '2.4 MB', '2026-01-15', Icons.picture_as_pdf, core_theme.AC.err),
      ('الملحق رقم 1 - توسع النطاق.pdf', '840 KB', '2026-03-10', Icons.picture_as_pdf, core_theme.AC.err),
      ('الملحق رقم 2 - تعديل الأسعار.pdf', '640 KB', '2026-04-05', Icons.picture_as_pdf, core_theme.AC.err),
      ('ضمان الأداء البنكي.pdf', '320 KB', '2026-01-20', Icons.picture_as_pdf, core_theme.AC.err),
      ('شهادة التأمين.pdf', '480 KB', '2026-01-22', Icons.picture_as_pdf, core_theme.AC.err),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
        child: Row(children: [
          Icon(docs[i].$4, color: docs[i].$5, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(docs[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${docs[i].$2} · رُفع ${docs[i].$3}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          IconButton(icon: const Icon(Icons.visibility), onPressed: () {}),
          IconButton(icon: const Icon(Icons.download), onPressed: () {}),
        ]),
      ),
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

  Widget _bullet(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(Icons.circle, size: 6, color: _gold),
          const SizedBox(width: 8),
          SizedBox(width: 140, child: Text(k, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );
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
