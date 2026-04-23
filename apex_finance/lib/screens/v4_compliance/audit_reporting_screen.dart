/// APEX Wave 24 — Audit Reporting (Opinion Builder + Management Letter + QC).
///
/// Route: /app/audit/reporting/opinion
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_draft_with_ai.dart';

class AuditReportingScreen extends StatefulWidget {
  const AuditReportingScreen({super.key});

  @override
  State<AuditReportingScreen> createState() => _AuditReportingScreenState();
}

class _AuditReportingScreenState extends State<AuditReportingScreen> {
  int _tab = 0;
  String _opinionType = 'unqualified';
  final _emphasisCtl = TextEditingController();
  final _mlCtl = TextEditingController();

  @override
  void dispose() {
    _emphasisCtl.dispose();
    _mlCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'منشئ الرأي', Icons.gavel),
          _tabBtn(1, 'رسالة الإدارة', Icons.mail),
          _tabBtn(2, 'ضمان الجودة (QC)', Icons.verified),
          _tabBtn(3, 'الأرشيف', Icons.archive),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A148C).withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF4A148C).withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF4A148C) : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? const Color(0xFF4A148C) : core_theme.AC.ts,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildOpinionBuilder();
      case 1: return _buildManagementLetter();
      case 2: return _buildQc();
      case 3: return _buildArchive();
      default: return const SizedBox();
    }
  }

  Widget _buildOpinionBuilder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Builder
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('منشئ الرأي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                // Opinion type selector
                const Text('نوع الرأي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Column(
                  children: [
                    _opinionOption('unqualified', 'رأي نظيف (Unqualified)', 'القوائم المالية تعرض بصورة عادلة', core_theme.AC.ok),
                    _opinionOption('qualified', 'رأي متحفّظ (Qualified)', 'باستثناء التحفّظات المحدّدة', core_theme.AC.warn),
                    _opinionOption('adverse', 'رأي معاكس (Adverse)', 'القوائم مضلّلة بشكل جوهري', const Color(0xFFB91C1C)),
                    _opinionOption('disclaimer', 'الامتناع عن الرأي (Disclaimer)', 'لم نتمكّن من الحصول على أدلة كافية', core_theme.AC.ts),
                  ],
                ),
                const SizedBox(height: 16),
                // Emphasis of matter
                Row(
                  children: [
                    const Text('فقرة التأكيد على أمر (Emphasis of Matter)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        _emphasisCtl.text = 'نلفت الانتباه إلى الإيضاح رقم (8) بشأن الالتزامات المحتملة الناجمة عن القضايا القانونية المنظورة لدى المحاكم المختصة.';
                      },
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('اكتب بالذكاء'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ApexV5DraftWithAi(
                  controller: _emphasisCtl,
                  contextAr: 'فقرة تأكيد على أمر في تقرير المراجعة',
                  placeholderAr: 'مثال: نلفت الانتباه إلى الإيضاح رقم X بشأن...',
                  minLines: 4,
                ),
                const SizedBox(height: 16),
                // KAMs
                const Text('أمور المراجعة الرئيسية (KAMs)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      _kamItem('KAM-1', 'تقييم المخزون', 'SABIC لديها مخزون ضخم ومتنوّع'),
                      _kamItem('KAM-2', 'الاعتراف بالإيرادات', 'عقود طويلة الأجل ومعقّدة'),
                      _kamItem('KAM-3', 'تقييم الأصول غير الملموسة', 'براءات اختراع وعلامات تجارية'),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('إضافة KAM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Live preview
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('معاينة مباشرة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('PDF'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('إرسال للاعتماد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'تقرير المراجع المستقل',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('إلى المساهمين في شركة SABIC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      const Text('الرأي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        _opinionType == 'unqualified'
                            ? 'في رأينا، تعرض القوائم المالية المرفقة بصورة عادلة، من جميع النواحي الجوهرية، المركز المالي للشركة كما في 31 ديسمبر 2025، وأداءها المالي وتدفقاتها النقدية للسنة المنتهية في ذلك التاريخ، وفقاً للمعايير الدولية لإعداد التقارير المالية (IFRS) المعتمدة في المملكة العربية السعودية.'
                            : 'في رأينا، باستثناء الآثار المذكورة في فقرة أساس الرأي المتحفّظ، تعرض القوائم المالية بصورة عادلة...',
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                      if (_emphasisCtl.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('التأكيد على أمر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(_emphasisCtl.text, style: const TextStyle(fontSize: 12, height: 1.6)),
                      ],
                      const SizedBox(height: 12),
                      const Text('أساس الرأي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(
                        'لقد قمنا بمراجعتنا وفقاً للمعايير الدولية للمراجعة (ISAs) المعتمدة في المملكة العربية السعودية.',
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('د. عبدالله السالم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('الشريك المسؤول', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                              Text('ترخيص SOCPA #4821', style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                            ],
                          ),
                          Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('مكتب السالم وشركاؤه', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('الرياض، المملكة العربية السعودية', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                              Text('2026-04-30', style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
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

  Widget _opinionOption(String value, String name, String desc, Color color) {
    final active = _opinionType == value;
    return GestureDetector(
      onTap: () => setState(() => _opinionType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : core_theme.AC.tp.withValues(alpha: 0.08), width: active ? 2 : 1),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _opinionType,
              onChanged: (v) => setState(() => _opinionType = v!),
              activeColor: color,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? color : core_theme.AC.tp)),
                  Text(desc, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kamItem(String id, String title, String scope) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF4A148C).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4A148C).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF4A148C), borderRadius: BorderRadius.circular(3)),
                child: Text(id, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(scope, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ],
      ),
    );
  }

  Widget _buildManagementLetter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('رسالة الإدارة — Management Letter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'التوصيات للإدارة حول الضوابط الداخلية والعمليات',
            style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
          ),
          const SizedBox(height: 16),
          // Findings
          _mlFinding(
            'ML-001',
            'عدم فصل الواجبات في إدخال ومراجعة القيود',
            'شخص واحد (المحاسب الأول) يدخل ويراجع قيود اليومية — خطر موضوعي على الضوابط.',
            'نوصي بتعيين مراجع مستقل لجميع القيود فوق 50K ر.س',
            'عالية',
            const Color(0xFFB91C1C),
          ),
          _mlFinding(
            'ML-002',
            'ضعف في ضوابط الوصول إلى البيانات المالية',
            'كل الموظفين يملكون صلاحية عرض الرواتب — خرق للخصوصية.',
            'نوصي بتطبيق RBAC على مستوى الحقل لحماية بيانات الرواتب',
            'متوسطة',
            core_theme.AC.warn,
          ),
          _mlFinding(
            'ML-003',
            'عدم وجود سياسة مكتوبة للمصروفات النثرية',
            'الصرف من الصندوق بدون حدود أو مستندات موحّدة.',
            'نوصي بوضع سياسة مفصّلة وحدود يومية لكل موظف',
            'منخفضة',
            core_theme.AC.info,
          ),
          const SizedBox(height: 16),
          // AI Draft button
          ApexV5DraftWithAi(
            controller: _mlCtl,
            contextAr: 'ملاحظة جديدة لرسالة الإدارة — audit finding',
            labelAr: 'اكتب ملاحظة جديدة',
            placeholderAr: 'صف الملاحظة + أثرها + التوصية...',
            minLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _mlFinding(String id, String issue, String detail, String recommendation, String severity, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: color)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(severity, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('تعديل')),
            ],
          ),
          const SizedBox(height: 8),
          Text(issue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('الملاحظة: $detail', style: TextStyle(fontSize: 12, color: core_theme.AC.tp)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: core_theme.AC.ok.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: core_theme.AC.ok.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb, size: 14, color: core_theme.AC.ok),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'التوصية: $recommendation',
                    style: TextStyle(fontSize: 12, color: core_theme.AC.ok, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQc() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ضمان الجودة (Quality Control)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _qcSection(
            'مراجعة المدير',
            'د. عبدالله السالم',
            'مكتمل ✓',
            '2026-04-25',
            core_theme.AC.ok,
            'راجعت جميع أوراق العمل وأوافق على الخلاصة.',
          ),
          _qcSection(
            'مراجعة الشريك',
            'د. محمد الخالدي',
            'مكتمل ✓',
            '2026-04-28',
            core_theme.AC.ok,
            'توصياتي في الرسالة المرفقة. أوافق على الرأي النظيف.',
          ),
          _qcSection(
            'EQCR (مراجعة جودة الارتباط)',
            'د. فاطمة الحربي — شريك مستقل',
            'قيد التنفيذ',
            'متوقّع 2026-05-02',
            core_theme.AC.warn,
            'قيد المراجعة — لم تظهر ملاحظات بعد.',
          ),
          _qcSection(
            'مراجعة التوقيع النهائي',
            'الشريك المسؤول',
            'بحاجة بدء',
            'متوقّع 2026-05-05',
            const Color(0xFF6B7280),
            'سيبدأ بعد اكتمال EQCR.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4A148C).withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xFF4A148C), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'معايير ISA 220 + ISQM 1 مطبّقة — كل مستوى مراجعة موثّق ومؤرشف.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A148C)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qcSection(String level, String reviewer, String status, String date, Color color, String notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.verified_user, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(reviewer, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                  ),
                  Text(date, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                ],
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: core_theme.AC.tp.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(notes, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchive() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الأرشيف — التقارير السابقة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final item in [
            _ArchiveItem('SABIC 2025', 'رأي نظيف', '2025-04-30'),
            _ArchiveItem('ABC Trading 2025', 'رأي نظيف', '2025-03-15'),
            _ArchiveItem('Al Rajhi 2025', 'رأي متحفّظ', '2025-06-20'),
            _ArchiveItem('STC 2025', 'رأي نظيف', '2025-05-10'),
            _ArchiveItem('Marriott 2024', 'رأي نظيف', '2024-12-05'),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_zip, size: 18, color: Color(0xFF4A148C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.client, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('${item.opinion} · ${item.date}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                  TextButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 14), label: const Text('تحميل')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchiveItem {
  final String client, opinion, date;
  _ArchiveItem(this.client, this.opinion, this.date);
}
