/// APEX — Knowledge Brain Search v2
/// /knowledge/search — semantic search over docs + workpapers + history
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class KnowledgeSearchV2Screen extends StatefulWidget {
  const KnowledgeSearchV2Screen({super.key});
  @override
  State<KnowledgeSearchV2Screen> createState() => _KnowledgeSearchV2ScreenState();
}

class _KnowledgeSearchV2ScreenState extends State<KnowledgeSearchV2Screen> {
  final _searchCtl = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // Sample knowledge entries
  final List<Map<String, dynamic>> _entries = [
    {
      'title': 'كيف أُسجّل قيد إقفال الفترة؟',
      'category': 'guide',
      'snippet': 'لإقفال الفترة بشكل صحيح، اتبع 12 خطوة من شاشة Period Close...',
      'source': 'دليل APEX',
      'icon': Icons.menu_book,
    },
    {
      'title': 'ZATCA Phase 2 — متطلبات CSID',
      'category': 'compliance',
      'snippet': 'CSID صالح لمدة سنة. يُجدد عبر بوابة ZATCA باستخدام UUID الكيان...',
      'source': 'وثائق ZATCA',
      'icon': Icons.verified_user,
    },
    {
      'title': 'IFRS 16 — معالجة الإيجارات',
      'category': 'standard',
      'snippet': 'IFRS 16 يُلزم بإثبات حق الاستخدام (ROU) والتزام الإيجار في الميزانية...',
      'source': 'IFRS Foundation',
      'icon': Icons.description,
    },
    {
      'title': 'حساب الزكاة — الوعاء الزكوي',
      'category': 'compliance',
      'snippet': 'الوعاء الزكوي = الأصول الزكوية - المطلوبات قصيرة الأجل. النسبة 2.5% سنوياً...',
      'source': 'ZATCA',
      'icon': Icons.account_balance_wallet,
    },
    {
      'title': 'GOSI — اشتراكات التأمينات الاجتماعية',
      'category': 'hr',
      'snippet': 'العامل السعودي: 22% (10% الموظف + 12% صاحب العمل). المقيم: 2% أخطار العمل...',
      'source': 'GOSI',
      'icon': Icons.shield,
    },
    {
      'title': 'كيف أربط بنك الراجحي؟',
      'category': 'guide',
      'snippet': 'انتقل إلى /settings/bank-feeds واختر مصرف الراجحي ثم Lean...',
      'source': 'دليل APEX',
      'icon': Icons.account_balance,
    },
  ];

  IconData _categoryIcon(String c) => switch (c) {
        'guide' => Icons.menu_book,
        'compliance' => Icons.gavel,
        'standard' => Icons.description,
        'hr' => Icons.people,
        _ => Icons.article,
      };

  String _categoryAr(String c) => switch (c) {
        'guide' => 'دليل',
        'compliance' => 'امتثال',
        'standard' => 'معيار',
        'hr' => 'موارد بشرية',
        _ => c,
      };

  Color _categoryColor(String c) => switch (c) {
        'guide' => AC.info,
        'compliance' => AC.warn,
        'standard' => AC.gold,
        'hr' => AC.ok,
        _ => AC.ts,
      };

  List<Map<String, dynamic>> get _filtered {
    var list = _entries.toList();
    if (_filter != 'all') {
      list = list.where((e) => e['category'] == _filter).toList();
    }
    final q = _searchCtl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((e) =>
              (e['title'] as String).toLowerCase().contains(q) ||
              (e['snippet'] as String).toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('قاعدة المعرفة', style: TextStyle(color: AC.gold)),
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: AC.navy2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _searchCtl,
              autofocus: true,
              style: TextStyle(color: AC.tp, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث في الأدلة والمعايير والقواعد...',
                hintStyle: TextStyle(color: AC.ts),
                prefixIcon: Icon(Icons.search, color: AC.gold),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              for (final c in [
                ('all', 'الكل', Icons.apps),
                ('guide', 'أدلة', Icons.menu_book),
                ('compliance', 'امتثال', Icons.gavel),
                ('standard', 'معايير', Icons.description),
                ('hr', 'HR', Icons.people),
              ])
                ChoiceChip(
                  avatar: Icon(c.$3, size: 14, color: _filter == c.$1 ? AC.navy : AC.tp),
                  label: Text(c.$2),
                  selected: _filter == c.$1,
                  onSelected: (_) => setState(() => _filter = c.$1),
                  selectedColor: AC.gold,
                  labelStyle: TextStyle(color: _filter == c.$1 ? AC.navy : AC.tp, fontSize: 11.5),
                ),
            ]),
          ]),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off, color: AC.ts, size: 48),
                      const SizedBox(height: 12),
                      Text('لا توجد نتائج لـ "${_searchCtl.text}"',
                          style: TextStyle(color: AC.ts)),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _resultCard(_filtered[i]),
                ),
        ),
      ]),
    );
  }

  Widget _resultCard(Map<String, dynamic> e) {
    final color = _categoryColor(e['category'] as String);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(e['icon'] as IconData, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e['title'] as String,
                style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_categoryAr(e['category'] as String),
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(e['snippet'] as String,
            style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.bookmark_outline, color: AC.ts, size: 12),
          const SizedBox(width: 4),
          Text('${e['source']}',
              style: TextStyle(color: AC.ts, fontSize: 11)),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: Text('اقرأ المزيد', style: TextStyle(color: color, fontSize: 11)),
          ),
        ]),
      ]),
    );
  }
}
