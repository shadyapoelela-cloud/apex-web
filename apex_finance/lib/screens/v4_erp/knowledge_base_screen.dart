/// APEX Wave 82 — Knowledge Base / Internal Wiki.
/// Route: /app/erp/finance/knowledge
///
/// Searchable internal knowledge repository.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});
  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  String _query = '';
  String _selectedCategory = 'all';
  _Article? _selectedArticle;

  final _categories = [
    _Category('all', 'الكل', Icons.apps, core_theme.AC.td, 84),
    _Category('finance', 'المحاسبة والمالية', Icons.account_balance, core_theme.AC.gold, 24),
    _Category('tax', 'الضرائب', Icons.percent, core_theme.AC.ok, 18),
    _Category('hr', 'الموارد البشرية', Icons.people, core_theme.AC.info, 14),
    _Category('audit', 'المراجعة', Icons.fact_check, Color(0xFF4A148C), 11),
    _Category('it', 'التقنية', Icons.computer, core_theme.AC.info, 9),
    _Category('compliance', 'الامتثال', Icons.shield, core_theme.AC.err, 8),
  ];

  final _articles = const [
    _Article(
      'KB-001',
      'كيفية إنشاء فاتورة ZATCA Phase 2 خطوة بخطوة',
      'finance',
      'كيفية',
      1248,
      4.8,
      '2026-04-15',
      'فاطمة الحربي',
      '''## الخطوة 1: الذهاب إلى وحدة الفواتير
من القائمة الرئيسية، اختر ERP → الإدارة المالية → الفواتير.

## الخطوة 2: إنشاء فاتورة جديدة
اضغط زر "فاتورة جديدة" في الأعلى على اليمين.

## الخطوة 3: اختيار العميل
ابحث عن العميل بالاسم أو الرقم الضريبي. إذا كان العميل مسجّلاً في ZATCA سيُعرض تلقائياً "VAT مُسجَّل".

## الخطوة 4: إضافة البنود
أضف كل سلعة/خدمة مع الكمية والسعر. VAT 15% محسوبة تلقائياً.

## الخطوة 5: المعاينة والإصدار
راجع البيانات، اضغط "إصدار". سيتم:
1. توليد XML بصيغة UBL 2.1
2. توقيعه رقمياً بشهادة CSID
3. إرسال نسخة إلى ZATCA
4. استقبال IRN و QR Code

## ملاحظات مهمة
- الفواتير > 1,000 ر.س تتطلب Cryptographic Stamp
- يجب الإصدار خلال 24 ساعة من البيع
- لا يمكن تعديل فاتورة بعد إرسالها — استخدم Credit Note
''',
    ),
    _Article(
      'KB-002',
      'شرح IFRS 15 — الاعتراف بالإيرادات',
      'finance',
      'دليل',
      892,
      4.6,
      '2026-03-22',
      'محمد القحطاني',
      '''المعيار IFRS 15 (Revenue from Contracts with Customers) يحدد متى وكم نعترف بالإيرادات.

## النموذج الخماسي:
1. **تحديد العقد** مع العميل
2. **تحديد التزامات الأداء** (Performance Obligations)
3. **تحديد ثمن المعاملة** (Transaction Price)
4. **توزيع الثمن** على التزامات الأداء
5. **الاعتراف بالإيراد** عند (أو كلما) الإيفاء بالالتزام

## متى يتم الاعتراف؟
- **عند نقطة زمنية** (Point in Time): عند تسليم سلعة
- **على مدار الوقت** (Over Time): خدمات، مشاريع طويلة، عقود إيجار

## أمثلة:
- بيع منتج = Point in time
- عقد تنفيذ SAP لـ 6 أشهر = Over time (% of completion)
- ترخيص SaaS سنوي = Over time (Straight line)
''',
    ),
    _Article(
      'KB-003',
      'حاسبة الزكاة — دليل الاستخدام',
      'tax',
      'كيفية',
      567,
      4.9,
      '2026-04-10',
      'راشد العنزي',
      'دليل تفصيلي لاستخدام حاسبة الزكاة في APEX...',
    ),
    _Article(
      'KB-004',
      'سياسة الإجازات — نظام العمل السعودي',
      'hr',
      'سياسة',
      1580,
      4.7,
      '2026-01-01',
      'لينا البكري',
      '''إجازات الموظفين وفق نظام العمل السعودي (المواد 109-120):

## السنوية
- 21 يوم للموظف الذي قضى سنة
- 30 يوم بعد 5 سنوات
- يجب الحصول عليها خلال سنة الاستحقاق
- قابلة للتأجيل بموافقة كتابية

## المرضية
- 30 يوم بأجر كامل
- + 60 يوم بـ 3/4 الأجر
- + 30 يوم بدون أجر
- (إجمالي 120 يوم)
- يُشترط تقرير طبي معتمد

## الاضطرارية (العرضية)
- 5 أيام/سنة
- حالات وفاة (أقارب من الدرجة الأولى)
- زواج الموظف (5 أيام)
- ولادة طفل (3 أيام)

## الأمومة
- 10 أسابيع: 4 قبل، 6 بعد الولادة
- بأجر كامل إذا الخدمة > سنة
- بنصف الأجر إذا < سنة
''',
    ),
    _Article(
      'KB-005',
      'منهجية مراجعة العمل الميداني',
      'audit',
      'دليل',
      423,
      4.5,
      '2026-02-18',
      'د. عبدالله السهلي',
      'منهجية شاملة للعمل الميداني في المراجعة وفق ISA...',
    ),
    _Article(
      'KB-006',
      'إعادة تعيين كلمة المرور',
      'it',
      'كيفية',
      2340,
      4.9,
      '2026-01-05',
      'فريق التقنية',
      'خطوات إعادة تعيين كلمة المرور في APEX...',
    ),
    _Article(
      'KB-007',
      'سياسة مكافحة الفساد',
      'compliance',
      'سياسة',
      756,
      4.8,
      '2025-12-15',
      'قسم القانونية',
      'السياسة المعتمدة من مجلس الإدارة لمكافحة الفساد...',
    ),
    _Article(
      'KB-008',
      'دليل إقفال الشهر — خطوات السلسلة',
      'finance',
      'دليل',
      892,
      4.7,
      '2026-04-01',
      'أحمد العتيبي',
      'الخطوات الكاملة لإقفال الشهر في 10 أيام...',
    ),
  ];

  List<_Article> get _filtered {
    return _articles.where((a) {
      if (_selectedCategory != 'all' && a.category != _selectedCategory) return false;
      if (_query.isNotEmpty && !a.title.contains(_query) && !a.content.contains(_query)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 260, child: _buildSidebar()),
        Expanded(
          child: _selectedArticle == null ? _buildList() : _buildArticleView(),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 20, bottom: 20, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: core_theme.AC.bdr),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: core_theme.AC.gold,
            child: const Row(
              children: [
                Icon(Icons.menu_book, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('قاعدة المعرفة',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final c in _categories) _categoryTile(c),
                const Divider(),
                _quickLink(Icons.star, 'المفضلة', core_theme.AC.warn),
                _quickLink(Icons.access_time, 'المقالات الأخيرة', core_theme.AC.info),
                _quickLink(Icons.trending_up, 'الأكثر قراءة', core_theme.AC.ok),
                _quickLink(Icons.edit, 'كتابة مقال', core_theme.AC.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(_Category c) {
    final selected = _selectedCategory == c.id;
    return InkWell(
      onTap: () => setState(() {
        _selectedCategory = c.id;
        _selectedArticle = null;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(c.icon, color: c.color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? c.color : core_theme.AC.tp)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('${c.count}',
                  style: TextStyle(fontSize: 10, color: c.color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickLink(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 20, right: 20, bottom: 20),
      children: [
        _buildHero(),
        const SizedBox(height: 12),
        _buildSearch(),
        const SizedBox(height: 16),
        for (final a in _filtered) _articleCard(a),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_stories, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('قاعدة المعرفة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('84 مقال · 7 فئات · بحث ذكي عبر النصّ الكامل',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'ابحث في 84 مقال...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _query = ''))
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (v) => setState(() => _query = v),
    );
  }

  Widget _articleCard(_Article a) {
    final cat = _categories.firstWhere((c) => c.id == a.category, orElse: () => _categories.first);
    return InkWell(
      onTap: () => setState(() => _selectedArticle = a),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: core_theme.AC.bdr),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(cat.icon, color: cat.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(a.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                        child: Text(cat.name,
                            style: TextStyle(fontSize: 10, color: cat.color, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: core_theme.AC.bdr, borderRadius: BorderRadius.circular(3)),
                        child: Text(a.kind, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Row(
                    children: [
                      Icon(Icons.person, size: 11, color: core_theme.AC.td),
                      const SizedBox(width: 3),
                      Text(a.author, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      const SizedBox(width: 10),
                      Icon(Icons.calendar_today, size: 11, color: core_theme.AC.td),
                      const SizedBox(width: 3),
                      Text(a.updatedAt, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                      const SizedBox(width: 10),
                      Icon(Icons.remove_red_eye, size: 11, color: core_theme.AC.td),
                      const SizedBox(width: 3),
                      Text('${a.views} قراءة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                    Text(a.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
                  ],
                ),
                const SizedBox(height: 4),
                Icon(Icons.arrow_forward, color: core_theme.AC.td, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleView() {
    final a = _selectedArticle!;
    final cat = _categories.firstWhere((c) => c.id == a.category, orElse: () => _categories.first);
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 20, right: 20, bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: ListView(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedArticle = null),
                icon: const Icon(Icons.arrow_back, size: 14),
                label: Text('رجوع'),
              ),
              const Spacer(),
              IconButton(onPressed: () {}, icon: const Icon(Icons.share, size: 18)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.star_border, color: Color(0xFFFFD700), size: 18)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.print, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(cat.name, style: TextStyle(fontSize: 11, color: cat.color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Text(a.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
            ],
          ),
          const SizedBox(height: 10),
          Text(a.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 13, color: core_theme.AC.td),
              const SizedBox(width: 4),
              Text(a.author, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
              const SizedBox(width: 10),
              Icon(Icons.calendar_today, size: 13, color: core_theme.AC.td),
              const SizedBox(width: 4),
              Text('آخر تحديث ${a.updatedAt}',
                  style: TextStyle(fontSize: 12, color: core_theme.AC.ts, fontFamily: 'monospace')),
              const SizedBox(width: 10),
              const Icon(Icons.star, size: 14, color: Color(0xFFFFD700)),
              Text(' ${a.rating}/5 · ${a.views} قراءة', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
            ],
          ),
          const Divider(height: 32),
          SelectableText(
            a.content,
            style: const TextStyle(fontSize: 13, height: 1.9),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: core_theme.AC.info,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.info),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: core_theme.AC.info),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هل وجدت المقال مفيداً؟ ساعدنا على تحسين المحتوى بتقييمك وملاحظاتك.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.thumb_up, size: 14),
                label: Text('مفيد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: core_theme.AC.ok,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.thumb_down, size: 14),
                label: Text('غير مفيد'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.flag, size: 14),
                label: Text('الإبلاغ عن مشكلة', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int count;
  const _Category(this.id, this.name, this.icon, this.color, this.count);
}

class _Article {
  final String id;
  final String title;
  final String category;
  final String kind;
  final int views;
  final double rating;
  final String updatedAt;
  final String author;
  final String content;
  const _Article(this.id, this.title, this.category, this.kind, this.views, this.rating, this.updatedAt, this.author, this.content);
}
