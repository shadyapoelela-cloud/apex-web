/// V5.2 — AI Financial Analyst using ObjectPageTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/object_page_template.dart';

class AiAnalystV52Screen extends StatelessWidget {
  const AiAnalystV52Screen({super.key});

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  static final _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: '🎉 المحلل المالي الذكي',
      subtitleAr: 'Claude 4 Opus · تحليل مستمر لبياناتك المالية · 24 رؤية جديدة هذا الأسبوع',
      statusLabelAr: 'نشط · AI',
      statusColor: _gold,
      smartButtons: [
        SmartButton(icon: Icons.psychology, labelAr: 'رؤية', count: 24, color: _gold),
        SmartButton(icon: Icons.warning, labelAr: 'تنبيه حرج', count: 3, color: core_theme.AC.err),
        SmartButton(icon: Icons.trending_up, labelAr: 'فرصة', count: 8, color: core_theme.AC.ok),
        SmartButton(icon: Icons.lightbulb, labelAr: 'توصية', count: 12, color: _navy),
        SmartButton(icon: Icons.chat, labelAr: 'محادثة', count: 45, color: _purple),
      ],
      primaryActions: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.refresh, size: 16), label: Text('تحليل جديد')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text('اسأل المحلل'),
        ),
      ],
      tabs: [
        ObjectPageTab(id: 'insights', labelAr: 'الرؤى الذكية', icon: Icons.auto_awesome, builder: (_) => _insights()),
        ObjectPageTab(id: 'alerts', labelAr: 'التنبيهات الحرجة', icon: Icons.warning, builder: (_) => _alerts()),
        ObjectPageTab(id: 'opportunities', labelAr: 'الفرص', icon: Icons.trending_up, builder: (_) => _opportunities()),
        ObjectPageTab(id: 'forecast', labelAr: 'التوقعات', icon: Icons.timeline, builder: (_) => _forecast()),
        ObjectPageTab(id: 'chat', labelAr: 'محادثة AI', icon: Icons.chat, builder: (_) => _chat()),
      ],
      chatterEntries: [
        ChatterEntry(authorAr: 'AI Analyst', contentAr: 'تم إصدار تقرير تحليلي شامل للربع الأول — 24 رؤية، 3 تنبيهات حرجة', timestamp: DateTime.now().subtract(const Duration(minutes: 30)), kind: ChatterKind.logNote),
        ChatterEntry(authorAr: 'د. محمد الراجحي', contentAr: 'طلب تحليل إضافي لقسم العملاء VIP', timestamp: DateTime.now().subtract(const Duration(hours: 3)), kind: ChatterKind.message),
        ChatterEntry(authorAr: 'AI Analyst', contentAr: 'تم إضافة نموذج توقّعات محدَّث — دقة 94.2%', timestamp: DateTime.now().subtract(const Duration(days: 1)), kind: ChatterKind.statusChange),
      ],
    );
  }

  Widget _insights() {
    final insights = [
      (
        '📈',
        'نموّ إيرادات غير عادي في قطاع التجزئة',
        'زادت إيرادات قطاع التجزئة بنسبة 34% خلال آخر 90 يوم، مقارنة بالمتوسط التاريخي 12%. الأسباب الرئيسية: حملة WhatsApp Business + افتتاح فرعين جديدين.',
        'high',
        _gold,
      ),
      (
        '💰',
        'تحسين كبير في دورة التحصيل',
        'متوسط DSO انخفض من 42 يوم إلى 28 يوم — تحسّن 33%. يعزى للتذكيرات الآلية وبرنامج الخصم المبكر 2%.',
        'medium',
        core_theme.AC.ok,
      ),
      (
        '⚠️',
        'تركّز مخاطر في قطاع الإنشاءات',
        '3 عملاء يمثلون 68% من الذمم المدينة >90 يوم في قطاع الإنشاءات. ينصح بإعادة تقييم حدود الائتمان.',
        'high',
        core_theme.AC.warn,
      ),
      (
        '🎯',
        'توصية: تحسين هامش الربح',
        'بمقارنة مع 15 شركة في نفس القطاع، هامش الربح لديك 18.2% (متوسط القطاع 22.5%). الفرصة الأكبر: تقليل مصروفات التوزيع (-2.8pp).',
        'medium',
        _purple,
      ),
      (
        '📊',
        'تباين في أداء الفروع',
        'فرع الرياض يولّد 58% من الإيرادات ولكن 43% من الأرباح. ينصح بمراجعة هيكل التكاليف في الفروع الأخرى.',
        'medium',
        _navy,
      ),
      (
        '🔄',
        'نمط موسمي مكتشَف',
        'AI اكتشف نمطاً موسمياً قوياً: انخفاض 22% في يوليو-أغسطس (بسبب الإجازات). ينصح بتخطيط الكاش فلو وفقاً لذلك.',
        'low',
        core_theme.AC.info,
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: insights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final (emoji, title, body, priority, color) = insights[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(_priority(priority), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
            ]),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(fontSize: 12, height: 1.5, color: core_theme.AC.tp)),
            const SizedBox(height: 10),
            Row(children: [
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.arrow_forward, size: 14), label: Text('استكشاف', style: TextStyle(fontSize: 11))),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.share, size: 14), label: Text('مشاركة', style: TextStyle(fontSize: 11))),
              const Spacer(),
              Text('قبل 2 ساعة', style: TextStyle(fontSize: 10, color: core_theme.AC.td)),
            ]),
          ]),
        );
      },
    );
  }

  String _priority(String p) => p == 'high' ? 'عالية' : (p == 'medium' ? 'متوسطة' : 'منخفضة');

  Widget _alerts() {
    const alerts = [
      ('🚨', 'عميل رئيسي تأخّر 62 يوم في الدفع', 'شركة البناء الحديث · مبلغ 340,000 ر.س · آخر تواصل منذ 18 يوم', 'critical'),
      ('⚠️', 'انخفاض حاد في الهامش التشغيلي', 'انخفض الهامش من 22% إلى 14% خلال 3 شهور · الأسباب تحت التحقيق', 'high'),
      ('🔍', 'معاملات شاذة اكتشفها AI Guardrails', '4 قيود تتجاوز 3 انحرافات معيارية من المتوسط · تحتاج مراجعة يدوية', 'high'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: alerts[i].$4 == 'critical' ? core_theme.AC.err.withValues(alpha: 0.05) : core_theme.AC.warn.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: alerts[i].$4 == 'critical' ? core_theme.AC.err : core_theme.AC.warn, width: 1.5)),
        child: Row(children: [
          Text(alerts[i].$1, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alerts[i].$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(alerts[i].$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.4)),
          ])),
          OutlinedButton(onPressed: () {}, child: Text('معالجة', style: TextStyle(fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _opportunities() {
    const ops = [
      ('💎', 'فرصة تحسين هامش الربح +2.8pp', 'تقليل مصروفات التوزيع بنسبة 18%', '1.4M ر.س/سنة'),
      ('🚀', 'توسّع إلى قطاع الضيافة', 'مقترح AI: فرصة في 14 عميل محتمل', '6.2M ر.س محتملة'),
      ('💳', 'تحسين سياسة الائتمان', 'رفع حدود 23 عميل ذهبي', '890K ر.س كاش فلو'),
      ('📉', 'خفض مخزون راكد', '18 صنف لم يتحرك منذ 180 يوم', '420K ر.س'),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: ops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.ok.withValues(alpha: 0.3))),
        child: Row(children: [
          Text(ops[i].$1, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ops[i].$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            Text(ops[i].$3, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('القيمة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            Text(ops[i].$4, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.ok)),
          ]),
          const SizedBox(width: 12),
          FilledButton(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: core_theme.AC.ok, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)), child: Text('تطبيق', style: TextStyle(fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _forecast() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_purple.withValues(alpha: 0.08), _gold.withValues(alpha: 0.06)]), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple)),
          child: Row(children: [
            Icon(Icons.timeline, color: _purple, size: 28),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نموذج التوقّعات AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _purple)),
              Text('دقة النموذج 94.2% · تحديث يومي · يعتمد على LSTM + Transformer', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        Text('توقّعات الإيرادات — الربع القادم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 12),
        ...[
          ('مايو 2026', 5.2, 6.1, 5.6, core_theme.AC.ok),
          ('يونيو 2026', 4.8, 5.9, 5.4, _gold),
          ('يوليو 2026', 4.2, 5.1, 4.6, core_theme.AC.warn),
        ].map((m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(m.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                  Text('${m.$4}M ر.س', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.$5)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(width: 100, child: Text('الحد الأدنى ${m.$2}M', style: TextStyle(fontSize: 10, color: core_theme.AC.ts))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (m.$4 - m.$2) / (m.$3 - m.$2), minHeight: 8, backgroundColor: core_theme.AC.bdr, color: m.$5))),
                  SizedBox(width: 100, child: Text('الحد الأعلى ${m.$3}M', style: TextStyle(fontSize: 10, color: core_theme.AC.ts), textAlign: TextAlign.end)),
                ]),
              ]),
            )),
      ]),
    );
  }

  Widget _chat() {
    return Column(children: [
      Expanded(child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _chatBubble(false, 'AI Analyst', 'مرحباً! أنا محللك المالي الذكي. كيف يمكنني مساعدتك اليوم؟ يمكنك سؤالي عن الإيرادات، الهوامش، التوقعات، أو أي تحليل تحتاجه.'),
          _chatBubble(true, 'أنت', 'ما سبب انخفاض هامش الربح في فرع جدة؟'),
          _chatBubble(false, 'AI Analyst', '🔍 حلّلت بيانات فرع جدة خلال آخر 90 يوم. ثلاثة أسباب رئيسية:\n\n1️⃣ ارتفاع تكلفة الإيجار (+22%) بعد التجديد\n2️⃣ زيادة الموظفين (+3) دون نمو مقابل في المبيعات\n3️⃣ خصومات ترويجية تجاوزت السياسة المعتمدة (12% متوسط بدل 8%)\n\n💡 التوصية: إعادة التفاوض على عقد الإيجار + مراجعة خطة التوسّع.'),
          _chatBubble(true, 'أنت', 'اعرض لي رسم بياني للمصروفات التشغيلية'),
          _chatBubble(false, 'AI Analyst', '📊 تم إنشاء الرسم البياني. التفاصيل متاحة في تبويب "التوقعات". هل تريد تصديره PDF أو مشاركته مع الفريق؟'),
        ],
      )),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: core_theme.AC.bdr))),
        child: Row(children: [
          IconButton(icon: Icon(Icons.attach_file, color: _gold), onPressed: () {}),
          Expanded(child: TextField(
            decoration: InputDecoration(
              hintText: 'اسأل المحلل الذكي...',
              filled: true,
              fillColor: core_theme.AC.navy3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          )),
          const SizedBox(width: 6),
          FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.send, size: 16), label: Text('إرسال')),
        ]),
      ),
    ]);
  }

  Widget _chatBubble(bool isMe, String name, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isMe) CircleAvatar(radius: 16, backgroundColor: _gold.withValues(alpha: 0.15), child: Icon(Icons.auto_awesome, color: _gold, size: 16)),
        if (!isMe) const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? _navy.withValues(alpha: 0.08) : core_theme.AC.navy3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isMe ? _navy.withValues(alpha: 0.2) : core_theme.AC.bdr),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.ts)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
            ]),
          ),
        ),
        if (isMe) const SizedBox(width: 8),
        if (isMe) CircleAvatar(radius: 16, backgroundColor: _navy.withValues(alpha: 0.15), child: Icon(Icons.person, color: _navy, size: 16)),
      ]),
    );
  }
}
