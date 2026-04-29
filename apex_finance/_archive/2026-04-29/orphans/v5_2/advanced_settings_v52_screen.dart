/// V5.2 — Advanced Settings — Category navigator.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class AdvancedSettingsV52Screen extends StatefulWidget {
  const AdvancedSettingsV52Screen({super.key});

  @override
  State<AdvancedSettingsV52Screen> createState() => _AdvancedSettingsV52ScreenState();
}

class _AdvancedSettingsV52ScreenState extends State<AdvancedSettingsV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _selectedCat = 'fiscal';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(children: [
          _header(),
          Expanded(child: Row(children: [
            _sidebar(),
            const VerticalDivider(width: 1),
            Expanded(child: _content()),
          ])),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.settings_applications, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إعدادات متقدّمة — المحاسبة المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('تهيئة تخصّص المعاملات والضرائب والعملات والأمن · للمسؤولين فقط', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.history, size: 16), label: Text('سجل التغييرات')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.save, size: 16), label: Text('حفظ كل التغييرات')),
      ]),
    );
  }

  Widget _sidebar() {
    final cats = [
      ('fiscal', 'السنة المالية والفترات', Icons.calendar_month, core_theme.AC.info),
      ('currency', 'العملات والصرف', Icons.currency_exchange, core_theme.AC.ok),
      ('tax', 'الضرائب والزكاة', Icons.receipt_long, _gold),
      ('approvals', 'حدود الاعتماد', Icons.approval, core_theme.AC.purple),
      ('numbering', 'ترقيم المستندات', Icons.pin, core_theme.AC.warn),
      ('security', 'الأمن والصلاحيات', Icons.security, core_theme.AC.err),
      ('audit', 'تدقيق السجلات', Icons.history_edu, core_theme.AC.purple),
      ('ai', 'إعدادات AI', Icons.smart_toy, core_theme.AC.err),
      ('backup', 'النسخ الاحتياطي', Icons.backup, core_theme.AC.info),
      ('regional', 'الإعدادات الإقليمية', Icons.public, _navy),
    ];
    return Container(
      width: 280,
      color: Colors.white,
      child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: cats.map((c) {
        final selected = c.$1 == _selectedCat;
        return InkWell(
          onTap: () => setState(() => _selectedCat = c.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? c.$4.withValues(alpha: 0.06) : null,
              border: BorderDirectional(end: BorderSide(color: selected ? c.$4 : Colors.transparent, width: 3)),
            ),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: c.$4.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(c.$3, color: c.$4, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(c.$2, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? _navy : core_theme.AC.tp))),
              if (selected) Icon(Icons.chevron_left, color: c.$4, size: 16),
            ]),
          ),
        );
      }).toList()),
    );
  }

  Widget _content() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: switch (_selectedCat) {
        'fiscal' => _fiscal(),
        'currency' => _currency(),
        'tax' => _tax(),
        'approvals' => _approvals(),
        'numbering' => _numbering(),
        'security' => _security(),
        'audit' => _audit(),
        'ai' => _ai(),
        'backup' => _backup(),
        _ => _regional(),
      },
    );
  }

  Widget _fiscal() {
    return ListView(children: [
      _sectionHeader('السنة المالية', Icons.calendar_month, core_theme.AC.info),
      _settingRow('بداية السنة المالية', 'يناير', 'يتغيّر إلى هجري عند اختيار التقويم الهجري'),
      _settingRow('عدد الفترات', '12 فترة شهرية', 'يمكن اختيار 13 فترة (4+4+4+1)'),
      _settingRow('قفل تلقائي بعد الإقفال', 'نعم — قفل دائم', 'لا يسمح بتعديل الفترة بعد قفلها'),
      _settingRow('فترات سمحاء (Lenient)', '2 فترات', 'مسموح بالتعديل خلالها لكن يُسجّل'),
      const SizedBox(height: 20),
      _sectionHeader('الفترات الحالية', Icons.event, core_theme.AC.info),
      ..._periods(),
    ]);
  }

  List<Widget> _periods() {
    final periods = [
      ('أبريل 2026', 'مفتوحة', core_theme.AC.ok),
      ('مارس 2026', 'قيد الإقفال', core_theme.AC.warn),
      ('فبراير 2026', 'مُقفلة', core_theme.AC.td),
      ('يناير 2026', 'مُقفلة', core_theme.AC.td),
    ];
    return periods.map((p) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
      child: Row(children: [
        Icon(p.$3 == core_theme.AC.ok ? Icons.lock_open : p.$3 == core_theme.AC.warn ? Icons.lock_clock : Icons.lock, size: 16, color: p.$3),
        const SizedBox(width: 8),
        Expanded(child: Text(p.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: p.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(p.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.$3))),
      ]),
    )).toList();
  }

  Widget _currency() {
    return ListView(children: [
      _sectionHeader('العملة الأساسية', Icons.currency_exchange, core_theme.AC.ok),
      _settingRow('العملة', 'SAR — الريال السعودي', 'العملة الرئيسية لجميع القيود'),
      _settingRow('الخانات العشرية', '2', 'حالياً: 1,234.56'),
      const SizedBox(height: 20),
      _sectionHeader('العملات المُفعّلة', Icons.language, core_theme.AC.ok),
      _currencyRow('USD', 'دولار أمريكي', '3.7500', true),
      _currencyRow('AED', 'درهم إماراتي', '1.0206', true),
      _currencyRow('EUR', 'يورو', '4.1234', true),
      _currencyRow('GBP', 'جنيه استرليني', '4.7890', true),
      _currencyRow('EGP', 'جنيه مصري', '0.0743', true),
      _currencyRow('KWD', 'دينار كويتي', '12.2315', false),
      const SizedBox(height: 20),
      _sectionHeader('تحديث الأسعار', Icons.refresh, core_theme.AC.ok),
      _settingRow('مصدر الأسعار', 'SAMA (البنك المركزي)', 'تحديث تلقائي يومياً 10:00 صباحاً'),
      _settingRow('تحديث تلقائي', 'مُفعَّل', 'يُحدّث ACDOCA بالقيمة الجديدة'),
    ]);
  }

  Widget _currencyRow(String code, String name, String rate, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(code, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: core_theme.AC.ok))),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
        Text('1 $code = $rate SAR', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.ts)),
        const SizedBox(width: 16),
        Switch(value: active, onChanged: (_) {}, activeColor: _gold),
      ]),
    );
  }

  Widget _tax() {
    return ListView(children: [
      _sectionHeader('ضريبة القيمة المضافة (VAT)', Icons.percent, _gold),
      _settingRow('النسبة الأساسية', '15%', 'المملكة العربية السعودية 2026'),
      _settingRow('VAT Number', '300987654300003', 'رقم ضريبي نشط'),
      _settingRow('ZATCA Phase', 'Phase 2 (Integration)', 'API + CSID نشط'),
      _settingRow('عملة الإقرار', 'SAR — موحّدة', 'يُفضّل ZATCA'),
      const SizedBox(height: 20),
      _sectionHeader('الزكاة', Icons.star, _gold),
      _settingRow('النسبة', '2.5%', 'من الوعاء الزكوي'),
      _settingRow('القاعدة الزكوية', 'الأصول الزكوية', 'وفق SOCPA'),
      _settingRow('التقويم', 'هجري', 'حسب الخيار الحكومي'),
      const SizedBox(height: 20),
      _sectionHeader('ضريبة الاستقطاع (WHT)', Icons.money_off, _gold),
      _settingRow('خدمات فنية', '5%', 'من غير المقيمين'),
      _settingRow('إيجار', '5%', 'من غير المقيمين'),
      _settingRow('عمولات', '15%', 'من غير المقيمين'),
      _settingRow('أخرى', '20%', 'الافتراضية'),
    ]);
  }

  Widget _approvals() {
    return ListView(children: [
      _sectionHeader('حدود الاعتماد لقيود اليومية', Icons.approval, core_theme.AC.purple),
      _approvalRow('<50,000 ر.س', 'محاسب', 'مستوى 1'),
      _approvalRow('50,000 - 500,000 ر.س', 'مدير محاسبة', 'مستوى 2'),
      _approvalRow('500,000 - 5M ر.س', 'المدير المالي', 'مستوى 3'),
      _approvalRow('> 5M ر.س', 'المجلس التنفيذي', 'مستوى 4 — اعتماد مزدوج'),
      const SizedBox(height: 20),
      _sectionHeader('حدود الاعتماد لأوامر الشراء', Icons.shopping_cart, core_theme.AC.purple),
      _approvalRow('<25,000 ر.س', 'مدير القسم', 'مستوى 1'),
      _approvalRow('25,000 - 250,000 ر.س', 'مدير العمليات', 'مستوى 2'),
      _approvalRow('> 250,000 ر.س', 'المدير التنفيذي', 'مستوى 3'),
    ]);
  }

  Widget _approvalRow(String limit, String approver, String level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: core_theme.AC.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.purple))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Text(limit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        Expanded(flex: 2, child: Text(approver, style: TextStyle(fontSize: 12, color: core_theme.AC.tp))),
        IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
    );
  }

  Widget _numbering() {
    return ListView(children: [
      _sectionHeader('ترقيم المستندات', Icons.pin, core_theme.AC.warn),
      _numberRow('قيود اليومية', 'JE-YYYY-####', '4218', core_theme.AC.warn),
      _numberRow('فواتير المبيعات', 'INV-YYYY-####', '1042', core_theme.AC.ok),
      _numberRow('فواتير المشتريات', 'VB-YYYY-####', '142', core_theme.AC.info),
      _numberRow('أوامر الشراء', 'PO-YYYY-####', '124', core_theme.AC.info),
      _numberRow('إشعارات الدائن', 'CN-YYYY-####', '28', core_theme.AC.purple),
      _numberRow('التحويلات البنكية', 'BT-YYYY-####', '85', _navy),
    ]);
  }

  Widget _numberRow(String name, String pattern, String current, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.numbers, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(pattern, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('الرقم الحالي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          Text(current, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(width: 12),
        IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () {}),
      ]),
    );
  }

  Widget _security() {
    return ListView(children: [
      _sectionHeader('المصادقة الثنائية', Icons.security, core_theme.AC.err),
      _toggleRow('تفعيل 2FA لكل المستخدمين', true),
      _toggleRow('دعم Biometric (Touch/Face ID)', true),
      _toggleRow('دعم Hardware Key (FIDO2)', false),
      const SizedBox(height: 20),
      _sectionHeader('سياسة كلمات المرور', Icons.password, core_theme.AC.err),
      _settingRow('الحد الأدنى للطول', '12 حرف', null),
      _settingRow('تعقيد', 'كبير + صغير + رقم + رمز', null),
      _settingRow('مدة الصلاحية', '90 يوم', null),
      _settingRow('عدم تكرار آخر', '12 كلمة مرور', null),
      const SizedBox(height: 20),
      _sectionHeader('الجلسات', Icons.timer, core_theme.AC.err),
      _settingRow('انتهاء الجلسة عند الخمول', '30 دقيقة', null),
      _settingRow('حد الجلسات المتزامنة', '3 جلسات', null),
    ]);
  }

  Widget _audit() {
    return ListView(children: [
      _sectionHeader('مستوى تفصيل السجل', Icons.history_edu, core_theme.AC.purple),
      _toggleRow('تسجيل كل قراءة للبيانات', false),
      _toggleRow('تسجيل التعديلات (قبل/بعد)', true),
      _toggleRow('تسجيل محاولات الوصول الفاشلة', true),
      _toggleRow('تسجيل النسخ إلى الحافظة', false),
      const SizedBox(height: 20),
      _sectionHeader('الاحتفاظ بالسجلات', Icons.archive, core_theme.AC.purple),
      _settingRow('مدة الاحتفاظ الرقمية', '7 سنوات', 'وفق ZATCA'),
      _settingRow('أرشفة خارجية', 'AWS Glacier', 'بعد 2 سنة'),
      _settingRow('سجل دائم (WORM)', 'مفعّل', 'لا يمكن تعديله'),
    ]);
  }

  Widget _ai() {
    return ListView(children: [
      _sectionHeader('نموذج AI المستخدم', Icons.smart_toy, core_theme.AC.err),
      _settingRow('النموذج الافتراضي', 'Claude Opus 4.7 (1M)', 'الأعلى دقة وذاكرة'),
      _settingRow('اللغة المُفضَّلة', 'عربي + إنجليزي', 'كلاهما بدعم كامل'),
      _settingRow('مستوى الثقة المطلوب', '85%', 'للمطابقات التلقائية'),
      const SizedBox(height: 20),
      _sectionHeader('تفعيل المزايا', Icons.toggle_on, core_theme.AC.err),
      _toggleRow('كاشف الشذوذ في القيود', true),
      _toggleRow('المطابقات الذكية (Bank/AR/AP)', true),
      _toggleRow('المحلل المالي (رؤى أسبوعية)', true),
      _toggleRow('Copilot في كل شاشة', true),
      _toggleRow('اقتراح قيود تلقائية', false),
    ]);
  }

  Widget _backup() {
    return ListView(children: [
      _sectionHeader('النسخ الاحتياطي', Icons.backup, core_theme.AC.info),
      _settingRow('التكرار', 'كل 4 ساعات', 'آخر نسخة قبل 2 ساعة'),
      _settingRow('الاحتفاظ', '90 يوم نشط + أرشيف دائم', null),
      _settingRow('الموقع', 'AWS S3 Riyadh + Ireland', 'نسختان جغرافيتان'),
      _settingRow('التشفير', 'AES-256 end-to-end', null),
      const SizedBox(height: 20),
      _sectionHeader('الاختبار الدوري', Icons.verified, core_theme.AC.info),
      _settingRow('اختبار الاستعادة', 'شهري', 'آخر اختبار: 2026-04-01 · ✓ ناجح'),
    ]);
  }

  Widget _regional() {
    return ListView(children: [
      _sectionHeader('المنطقة الزمنية والتاريخ', Icons.public, _navy),
      _settingRow('المنطقة الزمنية', 'Asia/Riyadh (UTC+3)', null),
      _settingRow('تقويم العمل', 'سبت - أربعاء', 'إجازات: خميس + جمعة'),
      _settingRow('تنسيق التاريخ', 'YYYY-MM-DD (ISO)', 'قابل للتخصيص'),
      _settingRow('تنسيق الأرقام', '1,234,567.89', 'فاصلة عشرية = نقطة'),
      const SizedBox(height: 20),
      _sectionHeader('اللغة', Icons.language, _navy),
      _toggleRow('واجهة عربية', true),
      _toggleRow('واجهة إنجليزية (اختيارية)', true),
      _toggleRow('RTL (من اليمين لليسار)', true),
    ]);
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(children: [
        Container(width: 4, height: 20, color: color),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  Widget _settingRow(String label, String value, String? hint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          if (hint != null) Text(hint, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ])),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy))),
        IconButton(icon: const Icon(Icons.edit, size: 14), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
    );
  }

  Widget _toggleRow(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        Switch(value: value, onChanged: (_) {}, activeColor: _gold),
      ]),
    );
  }
}
