/// V5.2 Reference Implementation — JE Builder using ObjectPageTemplate.
///
/// Demonstrates T2 (Object Page) with:
///   - Header with back + status pill + actions menu
///   - Process Flow: Draft → Pending → Approved → Posted
///   - Smart Buttons linking to related entities
///   - Left tabs: Overview / Lines / Accounting / Attachments / Audit
///   - Right Chatter rail with 4 activity entries
library;

import 'package:flutter/material.dart';

import '../../core/v5/templates/object_page_template.dart';

class JeBuilderV52Screen extends StatefulWidget {
  const JeBuilderV52Screen({super.key});

  @override
  State<JeBuilderV52Screen> createState() => _JeBuilderV52ScreenState();
}

class _JeBuilderV52ScreenState extends State<JeBuilderV52Screen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return ObjectPageTemplate(
      titleAr: 'قيد يومية JE-2026-4218',
      subtitleAr: 'تسوية نهاية الفترة · 45,000 ر.س',
      statusLabelAr: 'قيد الاعتماد',
      statusColor: Colors.orange,
      processStages: const [
        ProcessStage(labelAr: 'مسودة'),
        ProcessStage(labelAr: 'قيد الاعتماد'),
        ProcessStage(labelAr: 'معتمد'),
        ProcessStage(labelAr: 'مرحّل'),
      ],
      processCurrentIndex: 1,
      smartButtons: [
        SmartButton(icon: Icons.receipt, labelAr: 'فواتير مرتبطة', count: 3, color: _gold, onTap: () {}),
        SmartButton(icon: Icons.attach_file, labelAr: 'مرفقات', count: 2, color: _navy, onTap: () {}),
        SmartButton(icon: Icons.link, labelAr: 'معاملات بين شركات', count: 1, color: Colors.purple, onTap: () {}),
        SmartButton(icon: Icons.history, labelAr: 'قيود عكسية', count: 0, color: Colors.red, onTap: () {}),
      ],
      primaryActions: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.close, size: 16),
          label: const Text('رفض'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: _gold),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('اعتماد وترحيل'),
        ),
      ],
      tabs: [
        ObjectPageTab(
          id: 'overview',
          labelAr: 'نظرة عامة',
          icon: Icons.dashboard,
          builder: (ctx) => _buildOverviewTab(),
        ),
        ObjectPageTab(
          id: 'lines',
          labelAr: 'البنود (4)',
          icon: Icons.list_alt,
          builder: (ctx) => _buildLinesTab(),
        ),
        ObjectPageTab(
          id: 'accounting',
          labelAr: 'المحاسبة',
          icon: Icons.account_balance,
          builder: (ctx) => _buildAccountingTab(),
        ),
        ObjectPageTab(
          id: 'attachments',
          labelAr: 'مرفقات',
          icon: Icons.attach_file,
          builder: (ctx) => _buildAttachmentsTab(),
        ),
        ObjectPageTab(
          id: 'audit',
          labelAr: 'سجل التدقيق',
          icon: Icons.shield,
          builder: (ctx) => _buildAuditTab(),
        ),
      ],
      chatterEntries: [
        ChatterEntry(
          authorAr: 'سارة علي',
          contentAr: '@أحمد — قيّد يومية تسوية نهاية الشهر، رجاءً راجع بنود الاستحقاقات.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          kind: ChatterKind.message,
        ),
        ChatterEntry(
          authorAr: 'أحمد محمد',
          contentAr: 'مُكلّف بمراجعة القيد',
          timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
          kind: ChatterKind.activity,
        ),
        ChatterEntry(
          authorAr: 'سارة علي',
          contentAr: 'تم تغيير الحالة من "مسودة" إلى "قيد الاعتماد"',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          kind: ChatterKind.statusChange,
        ),
        ChatterEntry(
          authorAr: 'AI Copilot',
          contentAr: 'ملاحظة: هذا القيد أكبر بنسبة 35% من متوسط قيود نهاية الفترة السابقة. قد يحتاج للمراجعة.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          kind: ChatterKind.logNote,
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('البيانات الأساسية', _basicInfo()),
          const SizedBox(height: 20),
          _section('ملخّص القيد', _summaryRow()),
          const SizedBox(height: 20),
          _section('الترحيل المحاسبي', _postingInfo()),
        ],
      ),
    );
  }

  Widget _section(String titleAr, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleAr,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _basicInfo() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _kv('رقم القيد', 'JE-2026-4218'),
        _kv('التاريخ', '2026-04-19'),
        _kv('الفترة', 'أبريل 2026'),
        _kv('النوع', 'تسوية (Adjusting)'),
        _kv('الكيان', 'أبكس السعودية'),
        _kv('العملة', 'ر.س SAR'),
        _kv('المنشئ', 'سارة علي'),
        _kv('المكلّف بالمراجعة', 'أحمد محمد'),
        _kv('المرجع', 'PR-2026-412'),
      ],
    );
  }

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(
          child: _summaryPill(
            label: 'إجمالي المدين',
            value: '45,000.00',
            color: const Color(0xFF2E7D5B),
            icon: Icons.arrow_circle_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryPill(
            label: 'إجمالي الدائن',
            value: '45,000.00',
            color: const Color(0xFFD4AF37),
            icon: Icons.arrow_circle_down,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryPill(
            label: 'الفرق',
            value: '0.00',
            color: Colors.green,
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _summaryPill({required String label, required String value, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.9))),
                Text('$value ر.س',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postingInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kvRow(Icons.event, 'تاريخ الترحيل المقترح', '2026-04-19'),
        _kvRow(Icons.account_tree, 'الفرع', 'الرياض — فرع رئيسي'),
        _kvRow(Icons.check_circle, 'الميزان متوازن', 'نعم ✓', color: Colors.green),
        _kvRow(Icons.warning, 'تنبيه AI', 'قيم كبيرة — يحتاج مراجعة إضافية', color: Colors.orange),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _kvRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.black54),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildLinesTab() {
    const lines = [
      ('1', '1110 — النقدية والبنوك', 'تحصيل من عميل', 45000.0, 0.0),
      ('2', '1210 — الذمم المدينة', 'إنقاص رصيد العميل', 0.0, 30000.0),
      ('3', '4100 — إيراد المبيعات', 'إيراد مستحق', 0.0, 10000.0),
      ('4', '2300 — VAT Output', 'ضريبة القيمة المضافة', 0.0, 5000.0),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 40, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('الحساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('الوصف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    SizedBox(width: 120, child: Text('مدين', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                    SizedBox(width: 120, child: Text('دائن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                  ],
                ),
              ),
              ...lines.map((l) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text(l.$1, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 3, child: Text(l.$2, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(flex: 3, child: Text(l.$3, style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 120, child: Text(l.$4 > 0 ? l.$4.toStringAsFixed(2) : '—', style: TextStyle(fontSize: 12, fontWeight: l.$4 > 0 ? FontWeight.w800 : FontWeight.w400, color: l.$4 > 0 ? const Color(0xFF2E7D5B) : Colors.black38), textAlign: TextAlign.end)),
                        SizedBox(width: 120, child: Text(l.$5 > 0 ? l.$5.toStringAsFixed(2) : '—', style: TextStyle(fontSize: 12, fontWeight: l.$5 > 0 ? FontWeight.w800 : FontWeight.w400, color: l.$5 > 0 ? const Color(0xFFD4AF37) : Colors.black38), textAlign: TextAlign.end)),
                      ],
                    ),
                  )),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: const Row(
                  children: [
                    Expanded(child: Text('الإجمالي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy))),
                    SizedBox(width: 120, child: Text('45,000.00', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy), textAlign: TextAlign.end)),
                    SizedBox(width: 120, child: Text('45,000.00', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy), textAlign: TextAlign.end)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountingTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance, size: 56, color: Colors.black26),
            SizedBox(height: 12),
            Text('تبويب المحاسبة — يعرض COA IDs وأسماء الحسابات بالإنجليزي',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        ListTile(
          leading: Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text('إثبات التحصيل - بنك الرياض.pdf'),
          subtitle: Text('1.4 MB · رُفع 2026-04-19'),
          trailing: Icon(Icons.download),
        ),
        Divider(height: 1),
        ListTile(
          leading: Icon(Icons.image, color: Colors.blue),
          title: Text('صورة الإيداع.jpg'),
          subtitle: Text('840 KB · رُفع 2026-04-19'),
          trailing: Icon(Icons.download),
        ),
      ],
    );
  }

  Widget _buildAuditTab() {
    const trail = [
      ('2026-04-19 14:22', 'سارة علي', 'أنشأ القيد', Icons.add_circle),
      ('2026-04-19 14:28', 'سارة علي', 'أضاف البند #4 (VAT Output 5,000)', Icons.edit),
      ('2026-04-19 14:30', 'سارة علي', 'غيّر الحالة إلى "قيد الاعتماد"', Icons.send),
      ('2026-04-19 14:31', 'النظام', 'فحص AI: مرّ بدون ملاحظات جوهرية', Icons.verified),
      ('2026-04-19 14:35', 'أحمد محمد', 'تم تعيينه كمراجع', Icons.person_add),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: trail.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _gold.withOpacity(0.15),
              child: Icon(trail[i].$4, color: _gold, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trail[i].$3, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('${trail[i].$1} · ${trail[i].$2}',
                      style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
